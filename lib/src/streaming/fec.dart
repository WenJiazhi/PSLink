import 'dart:async';
import 'package:flutter/foundation.dart';

/// Forward error correction for video stream
class FECDecoder {
  final int _dataShards;
  final int _parityShards;

  FECDecoder({int dataShards = 4, int parityShards = 2})
      : _dataShards = dataShards,
        _parityShards = parityShards;

  /// Attempt to recover missing packets using FEC
  List<Uint8List>? recover(List<Uint8List?> shards) {
    // Count missing shards
    int missing = 0;
    for (final shard in shards) {
      if (shard == null) missing++;
    }

    // Cannot recover if too many shards are missing
    if (missing > _parityShards) {
      return null;
    }

    // If all data shards are present, no recovery needed
    if (missing == 0) {
      return shards.sublist(0, _dataShards).map((s) => s!).toList();
    }

    // Simple XOR-based FEC recovery (placeholder)
    // Real implementation would use Reed-Solomon or similar
    final recovered = <Uint8List>[];
    for (var i = 0; i < _dataShards; i++) {
      if (shards[i] != null) {
        recovered.add(shards[i]!);
      } else {
        // Attempt XOR recovery using parity shards
        final recoveredShard = _xorRecover(shards, i);
        if (recoveredShard != null) {
          recovered.add(recoveredShard);
        } else {
          return null; // Recovery failed
        }
      }
    }

    return recovered;
  }

  Uint8List? _xorRecover(List<Uint8List?> shards, int missingIndex) {
    // Find the first parity shard
    Uint8List? parityShard;
    for (var i = _dataShards; i < shards.length; i++) {
      if (shards[i] != null) {
        parityShard = shards[i];
        break;
      }
    }

    if (parityShard == null) return null;

    // XOR all available data shards together with parity
    final result = Uint8List(parityShard.length);
    result.setAll(0, parityShard);

    for (var i = 0; i < _dataShards; i++) {
      if (i != missingIndex && shards[i] != null) {
        final shard = shards[i]!;
        for (var j = 0; j < result.length && j < shard.length; j++) {
          result[j] ^= shard[j];
        }
      }
    }

    return result;
  }
}

/// Reorder queue for handling out-of-order packets
class ReorderQueue<T> {
  final int _maxBufferSize;
  final int _maxWaitTimeMs;
  final Map<int, T> _buffer = {};
  int _nextExpectedIndex = 0;
  DateTime _lastEmitTime = DateTime.now();

  final StreamController<T> _outputController = StreamController<T>.broadcast();

  ReorderQueue({
    int maxBufferSize = 64,
    int maxWaitTimeMs = 100,
  })  : _maxBufferSize = maxBufferSize,
        _maxWaitTimeMs = maxWaitTimeMs;

  Stream<T> get output => _outputController.stream;

  void add(int index, T item) {
    _buffer[index] = item;

    // Try to emit in-order items
    _tryEmit();

    // Force emit if buffer is full or timeout
    if (_buffer.length >= _maxBufferSize ||
        DateTime.now().difference(_lastEmitTime).inMilliseconds > _maxWaitTimeMs) {
      _forceEmit();
    }
  }

  void _tryEmit() {
    while (_buffer.containsKey(_nextExpectedIndex)) {
      final item = _buffer.remove(_nextExpectedIndex);
      if (item != null) {
        _outputController.add(item);
        _lastEmitTime = DateTime.now();
      }
      _nextExpectedIndex++;
    }
  }

  void _forceEmit() {
    if (_buffer.isEmpty) return;

    // Find the minimum index in buffer
    final minIndex = _buffer.keys.reduce((a, b) => a < b ? a : b);

    // Skip to minimum index if we're behind
    if (minIndex > _nextExpectedIndex) {
      debugPrint('ReorderQueue: Skipping ${minIndex - _nextExpectedIndex} packets');
      _nextExpectedIndex = minIndex;
    }

    _tryEmit();
  }

  void reset() {
    _buffer.clear();
    _nextExpectedIndex = 0;
    _lastEmitTime = DateTime.now();
  }

  void dispose() {
    _outputController.close();
  }
}

/// Congestion control for adaptive bitrate
class CongestionControl {
  // Statistics
  int _packetsReceived = 0;
  int _packetsLost = 0;
  int _bytesReceived = 0;
  DateTime _startTime = DateTime.now();
  // ignore: unused_field - reserved for timeout detection
  DateTime _lastUpdateTime = DateTime.now();

  // RTT estimation
  final List<int> _rttSamples = [];
  int _smoothedRtt = 0;
  int _rttVariance = 0;

  // Bitrate control
  int _targetBitrate = 10000000; // 10 Mbps default
  final int _minBitrate = 1000000; // 1 Mbps minimum
  final int _maxBitrate = 50000000; // 50 Mbps maximum

  int get packetsReceived => _packetsReceived;
  int get packetsLost => _packetsLost;
  int get bytesReceived => _bytesReceived;
  int get smoothedRtt => _smoothedRtt;
  int get targetBitrate => _targetBitrate;

  double get lossRate {
    final total = _packetsReceived + _packetsLost;
    if (total == 0) return 0;
    return _packetsLost / total;
  }

  double get throughput {
    final elapsed = DateTime.now().difference(_startTime).inSeconds;
    if (elapsed == 0) return 0;
    return (_bytesReceived * 8) / elapsed; // bits per second
  }

  void recordPacketReceived(int size) {
    _packetsReceived++;
    _bytesReceived += size;
    _lastUpdateTime = DateTime.now();
  }

  void recordPacketLost() {
    _packetsLost++;
    _adjustBitrate();
  }

  void recordRtt(int rttUs) {
    _rttSamples.add(rttUs);
    if (_rttSamples.length > 50) {
      _rttSamples.removeAt(0);
    }

    // Calculate smoothed RTT (EWMA)
    if (_smoothedRtt == 0) {
      _smoothedRtt = rttUs;
      _rttVariance = rttUs ~/ 2;
    } else {
      final diff = (rttUs - _smoothedRtt).abs();
      _rttVariance = (3 * _rttVariance + diff) ~/ 4;
      _smoothedRtt = (7 * _smoothedRtt + rttUs) ~/ 8;
    }
  }

  void _adjustBitrate() {
    // Reduce bitrate on packet loss
    if (lossRate > 0.05) {
      // > 5% loss
      _targetBitrate = (_targetBitrate * 0.7).round();
    } else if (lossRate > 0.02) {
      // > 2% loss
      _targetBitrate = (_targetBitrate * 0.85).round();
    } else if (lossRate < 0.01 && _smoothedRtt < 50000) {
      // < 1% loss and RTT < 50ms
      _targetBitrate = (_targetBitrate * 1.1).round();
    }

    _targetBitrate = _targetBitrate.clamp(_minBitrate, _maxBitrate);
  }

  /// Get congestion feedback packet data
  Uint8List buildFeedbackPacket() {
    final buffer = ByteData(16);
    buffer.setUint32(0, _packetsReceived, Endian.little);
    buffer.setUint32(4, _packetsLost, Endian.little);
    buffer.setUint32(8, _smoothedRtt, Endian.little);
    buffer.setUint32(12, _targetBitrate, Endian.little);
    return buffer.buffer.asUint8List();
  }

  void reset() {
    _packetsReceived = 0;
    _packetsLost = 0;
    _bytesReceived = 0;
    _startTime = DateTime.now();
    _lastUpdateTime = DateTime.now();
    _rttSamples.clear();
    _smoothedRtt = 0;
    _rttVariance = 0;
    _targetBitrate = 10000000;
  }
}
