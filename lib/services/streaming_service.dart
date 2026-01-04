import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:logger/logger.dart';
import '../models/ps_device.dart';
import '../models/stream_settings.dart';
import '../models/controller_state.dart';
import '../core/constants.dart';

/// 串流会话状态
enum SessionState {
  disconnected,
  connecting,
  authenticating,
  streaming,
  paused,
  error,
}

/// 串流统计信息
class StreamStats {
  final int videoBitrate;
  final int audioBitrate;
  final double fps;
  final int latencyMs;
  final int packetLoss;
  final DateTime timestamp;

  const StreamStats({
    this.videoBitrate = 0,
    this.audioBitrate = 0,
    this.fps = 0,
    this.latencyMs = 0,
    this.packetLoss = 0,
    required this.timestamp,
  });

  @override
  String toString() =>
      'StreamStats{bitrate: ${videoBitrate}kbps, fps: ${fps.toStringAsFixed(1)}, latency: ${latencyMs}ms}';
}

/// 串流会话服务
/// 管理与 PlayStation 的视频/音频流连接
class StreamingService {
  final Logger _logger = Logger();

  // 连接相关
  Socket? _ctrlSocket;      // 控制连接
  RawDatagramSocket? _videoSocket;  // 视频 UDP
  RawDatagramSocket? _audioSocket;  // 音频 UDP

  // 状态
  SessionState _state = SessionState.disconnected;
  SessionState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  // 当前连接的设备和设置
  PSDevice? _device;
  StreamSettings _settings = const StreamSettings();

  PSDevice? get device => _device;
  StreamSettings get settings => _settings;

  // 流控制器
  final _stateController = StreamController<SessionState>.broadcast();
  final _videoController = StreamController<Uint8List>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();
  final _statsController = StreamController<StreamStats>.broadcast();

  Stream<SessionState> get stateStream => _stateController.stream;
  Stream<Uint8List> get videoStream => _videoController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<StreamStats> get statsStream => _statsController.stream;

  // 心跳定时器
  Timer? _heartbeatTimer;
  Timer? _statsTimer;

  // 序列号
  int _ctrlSeq = 0;
  int _inputSeq = 0;

  // 加密密钥
  List<int>? _sessionKey;

  /// 开始串流会话
  Future<bool> startSession(PSDevice device, StreamSettings settings) async {
    if (_state != SessionState.disconnected) {
      _logger.w('Session already active');
      return false;
    }

    if (!device.isRegistered) {
      _lastError = '设备未注册';
      return false;
    }

    _device = device;
    _settings = settings;
    _setState(SessionState.connecting);

    try {
      // 1. 建立控制连接
      await _connectCtrl();

      // 2. 进行认证握手
      _setState(SessionState.authenticating);
      await _authenticate();

      // 3. 协商串流参数
      await _negotiateStream();

      // 4. 启动 UDP 视频/音频流
      await _startUdpStreams();

      // 5. 启动心跳和统计
      _startHeartbeat();
      _startStatsCollection();

      _setState(SessionState.streaming);
      _logger.i('Streaming session started successfully');
      return true;
    } catch (e) {
      _lastError = '启动会话失败: $e';
      _logger.e(_lastError!, error: e);
      _setState(SessionState.error);
      await stopSession();
      return false;
    }
  }

  /// 停止会话
  Future<void> stopSession() async {
    _logger.i('Stopping session');

    _heartbeatTimer?.cancel();
    _statsTimer?.cancel();

    // 发送断开消息
    if (_ctrlSocket != null && _state == SessionState.streaming) {
      try {
        await _sendCtrlMessage('BYE');
      } catch (e) {
        _logger.w('Failed to send BYE message', error: e);
      }
    }

    await _ctrlSocket?.close();
    _videoSocket?.close();
    _audioSocket?.close();

    _ctrlSocket = null;
    _videoSocket = null;
    _audioSocket = null;
    _device = null;
    _sessionKey = null;
    _ctrlSeq = 0;
    _inputSeq = 0;

    _setState(SessionState.disconnected);
  }

  /// 发送控制器输入
  void sendControllerInput(ControllerState input) {
    if (_state != SessionState.streaming || _videoSocket == null) return;

    try {
      final packet = _buildInputPacket(input);
      _videoSocket!.send(
        packet,
        InternetAddress(_device!.ipAddress),
        PSConstants.remotePlayPort + 1, // 输入端口
      );
      _inputSeq++;
    } catch (e) {
      _logger.w('Failed to send controller input', error: e);
    }
  }

  /// 更新串流设置
  Future<void> updateSettings(StreamSettings newSettings) async {
    if (_state != SessionState.streaming) {
      _settings = newSettings;
      return;
    }

    // 发送设置更新请求
    try {
      await _sendCtrlMessage('SET_PARAM', {
        'resolution': '${newSettings.resolutionWidth}x${newSettings.resolutionHeight}',
        'framerate': newSettings.frameRate.toString(),
        'bitrate': newSettings.bitrate.toString(),
      });
      _settings = newSettings;
      _logger.i('Settings updated');
    } catch (e) {
      _logger.e('Failed to update settings', error: e);
    }
  }

  // ========== 私有方法 ==========

  void _setState(SessionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// 建立控制连接
  Future<void> _connectCtrl() async {
    _logger.i('Connecting to ${_device!.ipAddress}:${PSConstants.remotePlayPort}');

    _ctrlSocket = await Socket.connect(
      _device!.ipAddress,
      PSConstants.remotePlayPort,
      timeout: Duration(milliseconds: PSConstants.connectionTimeout),
    );

    _ctrlSocket!.listen(
      _handleCtrlData,
      onError: (e) {
        _logger.e('Control socket error', error: e);
        _setState(SessionState.error);
      },
      onDone: () {
        _logger.i('Control socket closed');
        if (_state == SessionState.streaming) {
          _setState(SessionState.disconnected);
        }
      },
    );
  }

  /// 认证握手
  Future<void> _authenticate() async {
    // 发送初始化请求
    final path = _device!.deviceType == PSDeviceType.ps5
        ? '/sie/ps5/rp/sess/init'
        : '/sie/ps4/rp/sess/init';

    final request = 'GET $path HTTP/1.1\r\n'
        'Host: ${_device!.ipAddress}\r\n'
        'User-Agent: remoteplay Windows\r\n'
        'Connection: keep-alive\r\n'
        'RP-Registkey: ${_device!.rpKey}\r\n'
        'RP-Version: 8.0\r\n'
        '\r\n';

    _ctrlSocket!.add(utf8.encode(request));
    await _ctrlSocket!.flush();

    // 等待响应
    await Future.delayed(const Duration(milliseconds: 500));

    // 执行 ECDH 密钥交换
    await _performKeyExchange();
  }

  /// ECDH 密钥交换
  Future<void> _performKeyExchange() async {
    final algorithm = X25519();

    // 生成密钥对
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    // 发送公钥
    // 实际实现需要按照 PS Remote Play 协议格式

    // 模拟接收对方公钥并计算共享密钥
    // 这里简化处理
    _sessionKey = List.generate(32, (i) => i);

    _logger.d('Key exchange completed');
  }

  /// 协商串流参数
  Future<void> _negotiateStream() async {
    final params = {
      'resolution': '${_settings.resolutionWidth}x${_settings.resolutionHeight}',
      'framerate': _settings.frameRate.toString(),
      'bitrate': _settings.bitrate.toString(),
      'codec': 'h264', // 或 hevc
      'audio_codec': 'opus',
    };

    await _sendCtrlMessage('NEGOTIATE', params);
    _logger.d('Stream negotiation completed');
  }

  /// 启动 UDP 流
  Future<void> _startUdpStreams() async {
    // 视频流
    _videoSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _videoSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _videoSocket!.receive();
        if (datagram != null) {
          _handleVideoPacket(datagram.data);
        }
      }
    });

    // 音频流
    _audioSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _audioSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _audioSocket!.receive();
        if (datagram != null) {
          _handleAudioPacket(datagram.data);
        }
      }
    });

    // 发送流启动请求
    await _sendCtrlMessage('START_STREAM', {
      'video_port': _videoSocket!.port.toString(),
      'audio_port': _audioSocket!.port.toString(),
    });

    _logger.d('UDP streams started on ports ${_videoSocket!.port}, ${_audioSocket!.port}');
  }

  /// 处理控制数据
  void _handleCtrlData(Uint8List data) {
    try {
      final message = utf8.decode(data);
      _logger.d('Ctrl message: $message');

      // 解析控制消息
      if (message.contains('HEARTBEAT')) {
        // 心跳响应
      } else if (message.contains('ERROR')) {
        _lastError = message;
        _setState(SessionState.error);
      }
    } catch (e) {
      _logger.w('Failed to handle control data', error: e);
    }
  }

  /// 处理视频包
  void _handleVideoPacket(Uint8List data) {
    // 解密并解析视频数据
    // 实际实现需要处理 RTP 包和 H.264/HEVC NAL 单元
    _videoController.add(data);
  }

  /// 处理音频包
  void _handleAudioPacket(Uint8List data) {
    // 解密并解析音频数据
    // 实际实现需要处理 Opus 编码数据
    _audioController.add(data);
  }

  /// 发送控制消息
  Future<void> _sendCtrlMessage(String command, [Map<String, String>? params]) async {
    if (_ctrlSocket == null) return;

    final buffer = StringBuffer();
    buffer.writeln('$command ${++_ctrlSeq}');

    if (params != null) {
      for (final entry in params.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
    }

    buffer.writeln();

    _ctrlSocket!.add(utf8.encode(buffer.toString()));
    await _ctrlSocket!.flush();
  }

  /// 构建输入数据包
  Uint8List _buildInputPacket(ControllerState input) {
    final bytes = <int>[];

    // 包头
    bytes.addAll([0x00, 0x00]); // 类型标识
    bytes.addAll([
      _inputSeq & 0xFF,
      (_inputSeq >> 8) & 0xFF,
    ]);

    // 时间戳
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 8; i++) {
      bytes.add((timestamp >> (i * 8)) & 0xFF);
    }

    // 控制器状态
    bytes.addAll(input.toBytes());

    return Uint8List.fromList(bytes);
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: PSConstants.heartbeatInterval),
      (_) => _sendCtrlMessage('HEARTBEAT'),
    );
  }

  /// 启动统计收集
  void _startStatsCollection() {
    _statsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        final stats = StreamStats(
          videoBitrate: _settings.bitrate,
          fps: _settings.frameRate.toDouble(),
          latencyMs: 20, // 需要实际测量
          timestamp: DateTime.now(),
        );
        _statsController.add(stats);
      },
    );
  }

  /// 释放资源
  void dispose() {
    stopSession();
    _stateController.close();
    _videoController.close();
    _audioController.close();
    _statsController.close();
  }
}
