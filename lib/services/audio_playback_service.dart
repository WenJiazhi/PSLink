import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_opus/flutter_opus.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class AudioStreamConfig {
  const AudioStreamConfig({
    required this.channels,
    required this.bitsPerSample,
    required this.sampleRate,
    required this.frameSize,
    this.reserved = 0,
  });

  final int channels;
  final int bitsPerSample;
  final int sampleRate;
  final int frameSize;
  final int reserved;

  static AudioStreamConfig? fromHeader(Uint8List header) {
    if (header.length < 10) {
      return null;
    }

    final byteData = ByteData.sublistView(header);
    return AudioStreamConfig(
      channels: header[0],
      bitsPerSample: header[1],
      sampleRate: byteData.getUint32(2, Endian.big),
      frameSize: byteData.getUint32(6, Endian.big),
      reserved: header.length >= 12 ? byteData.getUint16(10, Endian.big) : 0,
    );
  }
}

class AudioPlaybackService {
  final Queue<int> _bufferedSamples = Queue<int>();
  final bool _platformSupported =
      Platform.isIOS || Platform.isAndroid || Platform.isMacOS;

  AudioStreamConfig? _config;
  OpusDecoder? _decoder;
  bool _started = false;
  bool _feeding = false;
  int _remainingFrames = 0;
  int _feedThresholdFrames = 0;

  AudioStreamConfig? get config => _config;

  Future<void> configure(
    AudioStreamConfig config, {
    required int latencyMs,
  }) async {
    if (!_platformSupported) {
      _config = config;
      return;
    }

    final needsRebuild =
        _config?.sampleRate != config.sampleRate ||
        _config?.channels != config.channels ||
        _config?.frameSize != config.frameSize;

    _config = config;
    _feedThresholdFrames = _computeFeedThreshold(config, latencyMs);

    if (needsRebuild) {
      if (_started) {
        await FlutterPcmSound.release();
        _started = false;
      }
      _decoder?.dispose();
      _decoder = OpusDecoder.create(
        sampleRate: config.sampleRate,
        channels: config.channels,
      );
      _bufferedSamples.clear();

      await FlutterPcmSound.setup(
        sampleRate: config.sampleRate,
        channelCount: config.channels,
      );
      FlutterPcmSound.setFeedCallback(_handleFeedRequest);
      _started = false;
    }

    await FlutterPcmSound.setFeedThreshold(_feedThresholdFrames);
    if (!_started) {
      FlutterPcmSound.start();
      _started = true;
    }
  }

  void pushOpusFrame(Uint8List opusFrame) {
    if (!_platformSupported) {
      return;
    }

    final decoder = _decoder;
    final config = _config;
    if (decoder == null || config == null || opusFrame.isEmpty) {
      return;
    }

    final pcmBytes = decoder.decode(opusFrame, config.frameSize);
    if (pcmBytes == null || pcmBytes.isEmpty) {
      return;
    }

    final byteData = ByteData.sublistView(pcmBytes);
    for (var offset = 0; offset + 1 < pcmBytes.length; offset += 2) {
      _bufferedSamples.add(byteData.getInt16(offset, Endian.little));
    }

    unawaited(_feedIfNeeded());
  }

  Future<void> dispose() async {
    if (!_platformSupported) {
      _config = null;
      return;
    }

    _bufferedSamples.clear();
    _config = null;
    _remainingFrames = 0;
    _feedThresholdFrames = 0;
    _decoder?.dispose();
    _decoder = null;
    if (_started) {
      await FlutterPcmSound.release();
      _started = false;
    }
    FlutterPcmSound.setFeedCallback(_noopFeed);
  }

  void _handleFeedRequest(int remainingFrames) {
    _remainingFrames = remainingFrames;
    unawaited(_feedIfNeeded());
  }

  Future<void> _feedIfNeeded() async {
    final config = _config;
    if (_feeding || !_started || config == null) {
      return;
    }

    final framesAvailable = _bufferedSamples.length ~/ config.channels;
    if (framesAvailable == 0) {
      return;
    }

    _feeding = true;
    try {
      final targetFrames =
          (_feedThresholdFrames * 2 - _remainingFrames).clamp(
                config.frameSize,
                framesAvailable,
              );
      final framesToSend = targetFrames;
      final samplesToSend = framesToSend * config.channels;
      final samples = List<int>.generate(
        samplesToSend,
        (_) => _bufferedSamples.removeFirst(),
      );

      if (samples.isNotEmpty) {
        await FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
      }
    } finally {
      _feeding = false;
    }

    if (_bufferedSamples.isNotEmpty) {
      unawaited(_feedIfNeeded());
    }
  }

  int _computeFeedThreshold(AudioStreamConfig config, int latencyMs) {
    final latencyFrames = (config.sampleRate * latencyMs) ~/ 1000;
    final minimumFrames = config.frameSize * 2;
    return latencyFrames > minimumFrames ? latencyFrames : minimumFrames;
  }

  static void _noopFeed(int _) {}
}
