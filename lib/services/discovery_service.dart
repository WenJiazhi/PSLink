import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import '../models/ps_device.dart';
import '../core/constants.dart';

/// PS 设备发现服务
/// 使用 UDP 广播搜索局域网内的 PlayStation 设备
class DiscoveryService {
  final Logger _logger = Logger();
  RawDatagramSocket? _socket;
  StreamController<PSDevice>? _deviceController;
  Timer? _discoveryTimer;
  bool _isDiscovering = false;

  final Map<String, PSDevice> _discoveredDevices = {};

  /// 当前发现的所有设备
  List<PSDevice> get devices => _discoveredDevices.values.toList();

  /// 是否正在发现中
  bool get isDiscovering => _isDiscovering;

  /// 设备发现流
  Stream<PSDevice>? get deviceStream => _deviceController?.stream;

  /// 开始发现设备
  Future<void> startDiscovery({
    Duration timeout = const Duration(seconds: 5),
    bool continuous = false,
  }) async {
    if (_isDiscovering) {
      _logger.w('Discovery already in progress');
      return;
    }

    _isDiscovering = true;
    _discoveredDevices.clear();
    _deviceController = StreamController<PSDevice>.broadcast();

    try {
      // 创建 UDP 套接字
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // 随机端口
      );

      _socket!.broadcastEnabled = true;

      // 监听响应
      _socket!.listen(_handleDatagram);

      // 发送发现请求
      await _sendDiscoveryRequest();

      if (continuous) {
        // 持续发现模式：每 2 秒发送一次请求
        _discoveryTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => _sendDiscoveryRequest(),
        );
      } else {
        // 单次发现模式：超时后停止
        Timer(timeout, stopDiscovery);
      }

      _logger.i('Discovery started (continuous: $continuous)');
    } catch (e) {
      _logger.e('Failed to start discovery', error: e);
      _isDiscovering = false;
      rethrow;
    }
  }

  /// 停止发现
  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _socket?.close();
    _socket = null;
    _deviceController?.close();
    _deviceController = null;
    _isDiscovering = false;
    _logger.i('Discovery stopped, found ${_discoveredDevices.length} devices');
  }

  /// 发送发现请求
  Future<void> _sendDiscoveryRequest() async {
    if (_socket == null) return;

    // Chiaki 格式的发现请求
    // SRCH * HTTP/1.1\ndevice-discovery-protocol-version:00030010\n
    const protocolVersion = '00030010'; // PS4/PS5 通用版本
    final request = 'SRCH * HTTP/1.1\n'
        'device-discovery-protocol-version:$protocolVersion\n';

    final data = utf8.encode(request);

    try {
      // 发送到广播地址
      _socket!.send(
        data,
        InternetAddress(PSConstants.broadcastAddress),
        PSConstants.discoveryPort,
      );
      _logger.d('Sent discovery request');
    } catch (e) {
      _logger.e('Failed to send discovery request', error: e);
    }
  }

  /// 处理收到的数据报
  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket?.receive();
    if (datagram == null) return;

    try {
      final response = utf8.decode(datagram.data);
      final device = _parseDiscoveryResponse(
        datagram.address.address,
        response,
      );

      if (device != null && !_discoveredDevices.containsKey(device.hostId)) {
        _discoveredDevices[device.hostId] = device;
        _deviceController?.add(device);
        _logger.i('Discovered device: ${device.hostName} at ${device.ipAddress}');
      }
    } catch (e) {
      _logger.w('Failed to parse discovery response', error: e);
    }
  }

  /// 解析发现响应
  PSDevice? _parseDiscoveryResponse(String ipAddress, String response) {
    // 响应格式类似 HTTP:
    // HTTP/1.1 200 Ok
    // host-id:XXXXXXXX
    // host-type:PS5
    // host-name:My PS5
    // system-version:XXXXXXXX
    // ...

    final lines = response.split('\n');
    if (lines.isEmpty) return null;

    // 解析状态行
    final statusLine = lines.first.trim();
    if (!statusLine.startsWith('HTTP/1.1')) return null;

    final headers = <String, String>{};

    // 解析状态码
    final statusMatch = RegExp(r'HTTP/1\.1 (\d+)').firstMatch(statusLine);
    if (statusMatch != null) {
      headers['status-code'] = statusMatch.group(1)!;
    }

    // 解析头部
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim().toLowerCase();
        final value = line.substring(colonIndex + 1).trim();
        headers[key] = value;
      }
    }

    // 验证必要字段
    if (!headers.containsKey('host-id')) return null;

    return PSDevice.fromDiscoveryResponse(ipAddress, headers);
  }

  /// 唤醒待机设备
  Future<bool> wakeDevice(PSDevice device) async {
    if (device.registKey == null) {
      _logger.e('Cannot wake device: not registered');
      return false;
    }

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // WAKEUP 请求格式
      final request = 'WAKEUP * HTTP/1.1\n'
          'client-type:i\n'
          'auth-type:R\n'
          'model:w\n'
          'app-type:r\n'
          'user-credential:${device.registKey}\n';

      final data = utf8.encode(request);

      // 发送多次以确保送达
      for (var i = 0; i < 5; i++) {
        socket.send(
          data,
          InternetAddress(device.ipAddress),
          PSConstants.discoveryPort,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }

      socket.close();
      _logger.i('Sent wake request to ${device.hostName}');
      return true;
    } catch (e) {
      _logger.e('Failed to wake device', error: e);
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    stopDiscovery();
  }
}
