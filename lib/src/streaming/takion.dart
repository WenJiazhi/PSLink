import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/controller_state.dart';
import '../protocol/constants.dart';
import '../crypto/aes_gcm.dart';

/// Takion streaming protocol handler
class TakionStream {
  final GKCrypt _gkCrypt;
  final Function(Uint8List) sendPacket;

  final StreamController<VideoFrame> _videoController = StreamController<VideoFrame>.broadcast();
  final StreamController<AudioFrame> _audioController = StreamController<AudioFrame>.broadcast();
  final StreamController<HapticsData> _hapticsController = StreamController<HapticsData>.broadcast();

  // Frame buffers for reassembly
  final Map<int, FrameBuffer> _videoFrameBuffers = {};
  final Map<int, FrameBuffer> _audioFrameBuffers = {};

  int _lastVideoFrameIndex = -1;
  // ignore: unused_field - reserved for future audio sync
  int _lastAudioFrameIndex = -1;

  bool _isVideo = true;

  TakionStream({
    required GKCrypt gkCrypt,
    required this.sendPacket,
  }) : _gkCrypt = gkCrypt;

  Stream<VideoFrame> get videoStream => _videoController.stream;
  Stream<AudioFrame> get audioStream => _audioController.stream;
  Stream<HapticsData> get hapticsStream => _hapticsController.stream;

  /// Process incoming Takion AV packet
  Future<void> processPacket(Uint8List data) async {
    if (data.length < 8) return;

    try {
      // Decrypt packet
      final decrypted = await _gkCrypt.process(data);
      _parseAVPacket(decrypted);
    } catch (e) {
      debugPrint('Takion packet processing error: $e');
    }
  }

  void _parseAVPacket(Uint8List data) {
    // Parse Takion header
    final flags = data[0];
    _isVideo = (flags & 0x80) != 0;
    final isHaptics = (flags & 0x40) != 0;
    final isKeyFrame = (flags & 0x20) != 0;

    // packetIndex for future use in packet reordering
    final _ = (data[1] << 8) | data[2];
    final frameIndex = (data[3] << 24) | (data[4] << 16) | (data[5] << 8) | data[6];
    final unitIndex = data[7];
    final unitsInFrame = data[8];

    int headerSize;
    if (_isVideo) {
      headerSize = PSConstants.takionV9AvHeaderSizeVideo;
    } else {
      headerSize = PSConstants.takionV12AvHeaderSizeAudio;
    }

    if (data.length <= headerSize) return;

    final payload = data.sublist(headerSize);

    if (isHaptics) {
      _hapticsController.add(HapticsData(data: payload));
      return;
    }

    if (_isVideo) {
      _processVideoPacket(frameIndex, unitIndex, unitsInFrame, isKeyFrame, payload);
    } else {
      _processAudioPacket(frameIndex, unitIndex, unitsInFrame, payload);
    }
  }

  void _processVideoPacket(
    int frameIndex,
    int unitIndex,
    int unitsInFrame,
    bool isKeyFrame,
    Uint8List payload,
  ) {
    // Check for frame sequence
    if (_lastVideoFrameIndex != -1 && frameIndex != _lastVideoFrameIndex + 1) {
      // Frame loss detected, clear old buffers
      _videoFrameBuffers.removeWhere((key, _) => key < frameIndex - 5);
    }
    _lastVideoFrameIndex = frameIndex;

    // Get or create frame buffer
    var buffer = _videoFrameBuffers[frameIndex];
    if (buffer == null) {
      buffer = FrameBuffer(
        frameIndex: frameIndex,
        totalUnits: unitsInFrame,
        isKeyFrame: isKeyFrame,
      );
      _videoFrameBuffers[frameIndex] = buffer;
    }

    // Add unit to buffer
    buffer.addUnit(unitIndex, payload);

    // Check if frame is complete
    if (buffer.isComplete) {
      final frame = buffer.assembleFrame();
      _videoController.add(VideoFrame(
        frameIndex: frameIndex,
        isKeyFrame: isKeyFrame,
        data: frame,
        timestamp: DateTime.now(),
      ));
      _videoFrameBuffers.remove(frameIndex);
    }
  }

  void _processAudioPacket(
    int frameIndex,
    int unitIndex,
    int unitsInFrame,
    Uint8List payload,
  ) {
    _lastAudioFrameIndex = frameIndex;

    // Audio frames are typically single unit
    if (unitsInFrame == 1) {
      _audioController.add(AudioFrame(
        frameIndex: frameIndex,
        data: payload,
        timestamp: DateTime.now(),
      ));
    } else {
      // Multi-unit audio frame (rare)
      var buffer = _audioFrameBuffers[frameIndex];
      if (buffer == null) {
        buffer = FrameBuffer(
          frameIndex: frameIndex,
          totalUnits: unitsInFrame,
          isKeyFrame: false,
        );
        _audioFrameBuffers[frameIndex] = buffer;
      }

      buffer.addUnit(unitIndex, payload);

      if (buffer.isComplete) {
        final frame = buffer.assembleFrame();
        _audioController.add(AudioFrame(
          frameIndex: frameIndex,
          data: frame,
          timestamp: DateTime.now(),
        ));
        _audioFrameBuffers.remove(frameIndex);
      }
    }
  }

  /// Send controller state
  Future<void> sendControllerState(ControllerState state) async {
    final packet = _buildControllerPacket(state);
    final encrypted = await _gkCrypt.process(packet);
    sendPacket(encrypted);
  }

  Uint8List _buildControllerPacket(ControllerState state) {
    // Build Takion controller packet
    final buffer = ByteData(32);
    var offset = 0;

    // Header
    buffer.setUint8(offset++, 0x00); // Type: controller input
    buffer.setUint8(offset++, 0x00); // Flags

    // Button state (4 bytes)
    buffer.setUint32(offset, state.buttons, Endian.little);
    offset += 4;

    // Trigger states
    buffer.setUint8(offset++, state.l2State);
    buffer.setUint8(offset++, state.r2State);

    // Analog sticks
    buffer.setInt16(offset, state.leftX, Endian.little);
    offset += 2;
    buffer.setInt16(offset, state.leftY, Endian.little);
    offset += 2;
    buffer.setInt16(offset, state.rightX, Endian.little);
    offset += 2;
    buffer.setInt16(offset, state.rightY, Endian.little);
    offset += 2;

    // Touch count
    buffer.setUint8(offset++, state.touches.length);

    // Touch data
    for (final touch in state.touches) {
      buffer.setUint8(offset++, touch.id);
      buffer.setUint16(offset, touch.x, Endian.little);
      offset += 2;
      buffer.setUint16(offset, touch.y, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  void dispose() {
    _videoController.close();
    _audioController.close();
    _hapticsController.close();
  }
}

/// Frame buffer for reassembling multi-unit frames
class FrameBuffer {
  final int frameIndex;
  final int totalUnits;
  final bool isKeyFrame;
  final Map<int, Uint8List> _units = {};

  FrameBuffer({
    required this.frameIndex,
    required this.totalUnits,
    required this.isKeyFrame,
  });

  void addUnit(int unitIndex, Uint8List data) {
    _units[unitIndex] = data;
  }

  bool get isComplete => _units.length == totalUnits;

  Uint8List assembleFrame() {
    var totalSize = 0;
    for (var i = 0; i < totalUnits; i++) {
      totalSize += _units[i]?.length ?? 0;
    }

    final result = Uint8List(totalSize);
    var offset = 0;
    for (var i = 0; i < totalUnits; i++) {
      final unit = _units[i];
      if (unit != null) {
        result.setRange(offset, offset + unit.length, unit);
        offset += unit.length;
      }
    }
    return result;
  }
}

/// Video frame data
class VideoFrame {
  final int frameIndex;
  final bool isKeyFrame;
  final Uint8List data;
  final DateTime timestamp;

  VideoFrame({
    required this.frameIndex,
    required this.isKeyFrame,
    required this.data,
    required this.timestamp,
  });
}

/// Audio frame data
class AudioFrame {
  final int frameIndex;
  final Uint8List data;
  final DateTime timestamp;

  AudioFrame({
    required this.frameIndex,
    required this.data,
    required this.timestamp,
  });
}

/// Haptics feedback data
class HapticsData {
  final Uint8List data;

  HapticsData({required this.data});
}
