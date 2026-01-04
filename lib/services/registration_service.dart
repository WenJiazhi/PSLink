import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:logger/logger.dart';
import '../models/ps_device.dart';
import '../core/constants.dart';

/// 设备注册服务
/// 处理 PlayStation 设备的注册和 RP-KEY 生成
class RegistrationService {
  final Logger _logger = Logger();

  /// 注册状态
  enum RegistrationState {
    idle,
    connecting,
    waitingForPin,
    registering,
    success,
    failed,
  }

  RegistrationState _state = RegistrationState.idle;
  RegistrationState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  /// 使用 PIN 码注册设备
  ///
  /// [device] - 要注册的设备
  /// [pin] - 在 PlayStation 上显示的 8 位 PIN 码
  /// [accountId] - PSN 账号 ID (Base64 编码)
  Future<PSDevice?> registerWithPin(
    PSDevice device,
    String pin,
    String accountId,
  ) async {
    if (_state != RegistrationState.idle) {
      _logger.w('Registration already in progress');
      return null;
    }

    _state = RegistrationState.connecting;
    _lastError = null;

    try {
      // 验证 PIN 码格式
      if (pin.length != 8 || !RegExp(r'^\d{8}$').hasMatch(pin)) {
        throw RegistrationException('PIN 码必须是 8 位数字');
      }

      // 连接到设备
      _logger.i('Connecting to ${device.ipAddress}:${PSConstants.registrationPort}');

      final socket = await Socket.connect(
        device.ipAddress,
        PSConstants.registrationPort,
        timeout: const Duration(seconds: 10),
      );

      try {
        _state = RegistrationState.registering;

        // 构建注册请求
        final registKey = await _generateRegistKey();
        final rpKey = await _performRegistration(
          socket,
          device,
          pin,
          accountId,
          registKey,
        );

        if (rpKey != null) {
          _state = RegistrationState.success;
          _logger.i('Registration successful');

          return device.copyWith(
            registKey: registKey,
            rpKey: rpKey,
            lastConnected: DateTime.now(),
          );
        } else {
          throw RegistrationException('注册失败：未收到 RP-KEY');
        }
      } finally {
        await socket.close();
      }
    } on SocketException catch (e) {
      _lastError = '无法连接到设备: ${e.message}';
      _logger.e(_lastError!, error: e);
      _state = RegistrationState.failed;
      return null;
    } on RegistrationException catch (e) {
      _lastError = e.message;
      _logger.e(_lastError!, error: e);
      _state = RegistrationState.failed;
      return null;
    } catch (e) {
      _lastError = '注册时发生错误: $e';
      _logger.e(_lastError!, error: e);
      _state = RegistrationState.failed;
      return null;
    } finally {
      if (_state != RegistrationState.success) {
        _state = RegistrationState.idle;
      }
    }
  }

  /// 生成注册密钥
  Future<String> _generateRegistKey() async {
    final random = SecureRandom.fast;
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// 执行注册流程
  Future<String?> _performRegistration(
    Socket socket,
    PSDevice device,
    String pin,
    String accountId,
    String registKey,
  ) async {
    // 确定设备类型的路径
    final path = device.deviceType == PSDeviceType.ps5
        ? '/sie/ps5/rp/sess/regist'
        : '/sie/ps4/rp/sess/regist';

    // 构建 HTTP 请求
    final request = StringBuffer();
    request.writeln('POST $path HTTP/1.1');
    request.writeln('Host: ${device.ipAddress}');
    request.writeln('User-Agent: remoteplay Windows');
    request.writeln('Connection: close');
    request.writeln('Content-Type: application/x-www-form-urlencoded');

    // 构建请求体
    final body = <String, String>{
      'psn-account-id': accountId,
      'rp-registkey': registKey,
      'rp-version': '8.0',
      'rp-key-type': '2',
    };

    // 使用 PIN 码进行加密/认证
    final encryptedData = await _encryptRegistrationData(body, pin);
    final bodyBytes = utf8.encode(encryptedData);

    request.writeln('Content-Length: ${bodyBytes.length}');
    request.writeln();
    request.write(encryptedData);

    // 发送请求
    socket.add(utf8.encode(request.toString()));
    await socket.flush();

    // 读取响应
    final response = await _readResponse(socket);
    _logger.d('Registration response: $response');

    // 解析响应获取 RP-KEY
    return _parseRegistrationResponse(response, pin);
  }

  /// 加密注册数据
  Future<String> _encryptRegistrationData(
    Map<String, String> data,
    String pin,
  ) async {
    // 简化实现：实际需要使用 AES-GCM 加密
    // PIN 码用于派生加密密钥
    final algorithm = AesGcm.with256bits();

    // 从 PIN 派生密钥
    final keyBytes = await _deriveKeyFromPin(pin);
    final secretKey = SecretKey(keyBytes);

    // 生成随机 nonce
    final nonce = algorithm.newNonce();

    // 将数据编码为 JSON
    final plaintext = utf8.encode(jsonEncode(data));

    // 加密
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 组合 nonce + ciphertext + mac
    final combined = Uint8List.fromList([
      ...nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return base64Encode(combined);
  }

  /// 从 PIN 派生密钥
  Future<List<int>> _deriveKeyFromPin(String pin) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 10000,
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: utf8.encode('PlayStation'),
    );

    return secretKey.extractBytes();
  }

  /// 读取 socket 响应
  Future<String> _readResponse(Socket socket) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();

    final subscription = socket.listen(
      (data) {
        buffer.write(utf8.decode(data));
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
    );

    // 超时处理
    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError(
          RegistrationException('响应超时'),
        );
      }
    });

    return completer.future;
  }

  /// 解析注册响应
  String? _parseRegistrationResponse(String response, String pin) {
    // 检查 HTTP 状态码
    final lines = response.split('\n');
    if (lines.isEmpty) return null;

    final statusLine = lines.first;
    if (!statusLine.contains('200')) {
      _logger.e('Registration failed with status: $statusLine');
      return null;
    }

    // 查找响应体中的 RP-KEY
    // 响应体是加密的，需要解密
    final bodyStart = response.indexOf('\r\n\r\n');
    if (bodyStart < 0) return null;

    final body = response.substring(bodyStart + 4);

    // 尝试解密响应
    try {
      // 简化实现：假设响应包含 RP-KEY
      // 实际实现需要完整的解密逻辑
      final decoded = base64Decode(body.trim());

      // RP-KEY 是 16 字节
      if (decoded.length >= 16) {
        return base64Encode(decoded.sublist(0, 16));
      }
    } catch (e) {
      _logger.w('Failed to decrypt response', error: e);
    }

    return null;
  }

  /// 重置状态
  void reset() {
    _state = RegistrationState.idle;
    _lastError = null;
  }
}

/// 注册异常
class RegistrationException implements Exception {
  final String message;
  RegistrationException(this.message);

  @override
  String toString() => 'RegistrationException: $message';
}
