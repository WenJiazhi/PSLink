import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../models/ps_host.dart';
import 'constants.dart';
import 'ps5_regist_crypto.dart';

/// Registration result
class RegistrationResult {
  final bool success;
  final String? rpRegistKey;
  final List<int>? rpKey;
  final int? rpKeyType;
  final List<int>? serverMac;
  final String? serverNickname;
  final String? errorMessage;

  RegistrationResult({
    required this.success,
    this.rpRegistKey,
    this.rpKey,
    this.rpKeyType,
    this.serverMac,
    this.serverNickname,
    this.errorMessage,
  });
}

/// Registration events
enum RegistrationEventType {
  started,
  awaitingPin,
  connecting,
  authenticating,
  success,
  failed,
  cancelled,
}

class RegistrationEvent {
  final RegistrationEventType type;
  final String? message;

  RegistrationEvent({required this.type, this.message});
}

/// PlayStation console registration service
class RegistrationService {
  final StreamController<RegistrationEvent> _eventController =
      StreamController<RegistrationEvent>.broadcast();

  Socket? _socket;
  bool _isCancelled = false;

  Stream<RegistrationEvent> get eventStream => _eventController.stream;

  /// Register with a PlayStation console
  /// [host] - The discovered PlayStation host
  /// [pin] - The 8-digit PIN displayed on the console
  /// [psnAccountId] - The PSN account ID (8 bytes)
  /// [psnOnlineId] - The PSN online ID (username)
  Future<RegistrationResult> register({
    required PSHost host,
    required String pin,
    required String psnAccountId,
    required String psnOnlineId,
  }) async {
    _isCancelled = false;
    _emitEvent(RegistrationEventType.started);

    try {
      // Validate PIN
      if (pin.length != 8 || int.tryParse(pin) == null) {
        return _fail('Invalid PIN format. Must be 8 digits.');
      }

      _emitEvent(RegistrationEventType.connecting);

      // Connect to registration port
      _socket = await Socket.connect(
        host.hostAddress,
        PSConstants.registrationPort,
        timeout: const Duration(seconds: 10),
      );

      if (_isCancelled) return _fail('Registration cancelled');

      _emitEvent(RegistrationEventType.authenticating);

      // Build registration request
      final request = _buildRegistrationRequest(
        host: host,
        pin: pin,
        psnAccountId: psnAccountId,
        psnOnlineId: psnOnlineId,
      );

      _socket!.add(request);

      // Wait for response
      final responseCompleter = Completer<Uint8List>();
      final subscription = _socket!.listen(
        (data) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(error);
          }
        },
      );

      final response = await responseCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Registration timeout'),
      );

      await subscription.cancel();
      await _socket?.close();
      _socket = null;

      // Parse response
      return _parseRegistrationResponse(response);
    } catch (e) {
      return _fail('Registration error: $e');
    } finally {
      await _socket?.close();
      _socket = null;
    }
  }

  /// Build registration HTTP request
  Uint8List _buildRegistrationRequest({
    required PSHost host,
    required String pin,
    required String psnAccountId,
    required String psnOnlineId,
  }) {
    // PS5 uses different registration protocol than PS4
    if (host.isPS5) {
      return _buildPS5RegistrationRequest(
        host: host,
        pin: pin,
        psnAccountId: psnAccountId,
        psnOnlineId: psnOnlineId,
      );
    } else {
      return _buildPS4RegistrationRequest(
        host: host,
        pin: pin,
        psnAccountId: psnAccountId,
        psnOnlineId: psnOnlineId,
      );
    }
  }

  /// Build PS4 registration HTTP request (legacy protocol)
  /// PS4 uses GET /sce/rp/regist with RP-Auth header
  /// RP-Version: 1.0 for PS4
  Uint8List _buildPS4RegistrationRequest({
    required PSHost host,
    required String pin,
    required String psnAccountId,
    required String psnOnlineId,
  }) {
    // Normalize account ID for PS4
    String normalizedAccountId = _normalizeAccountId(psnAccountId);

    // Build request with correct header format
    final buffer = StringBuffer();
    buffer.write('GET ${PSConstants.registrationEndpointPS4} HTTP/1.1\r\n');
    buffer.write('Host: ${host.hostAddress}:${PSConstants.registrationPort}\r\n');
    buffer.write('User-Agent: remoteplay Windows\r\n'); // Match official client
    buffer.write('Connection: close\r\n');
    buffer.write('RP-Registkey: \r\n');
    buffer.write('RP-Version: 1.0\r\n'); // PS4 uses 1.0
    buffer.write('RP-ClientType: 11\r\n'); // iOS client type
    buffer.write('RP-Auth: $normalizedAccountId\r\n'); // PS4 uses RP-Auth
    buffer.write('RP-PSN-ID: $psnOnlineId\r\n');
    buffer.write('RP-Pin: $pin\r\n');
    buffer.write('\r\n');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Build PS5 registration HTTP request (new protocol)
  /// Based on chiaki implementation: uses POST to /sie/ps5/rp/sess/rgst
  /// with Np-AccountId header instead of RP-Auth
  /// Key differences from PS4:
  /// - User-Agent must be "remoteplay Windows" (official client UA)
  /// - RP-Version must be "2.0" (not 1.0 like PS4)
  /// - Uses Np-AccountId instead of RP-Auth
  /// - Connection: close is required
  /// - Includes encrypted binary payload
  Uint8List _buildPS5RegistrationRequest({
    required PSHost host,
    required String pin,
    required String psnAccountId,
    required String psnOnlineId,
  }) {
    // Validate and normalize PSN Account ID (should be Base64 encoded 8 bytes)
    String accountIdBase64 = _normalizeAccountId(psnAccountId);

    // Build the registration payload using PS5 crypto
    final payload = PS5RegistCrypto.buildMinimalPayload(
      psnAccountId: accountIdBase64,
      psnOnlineId: psnOnlineId,
      pin: pin,
    );

    // Build HTTP headers
    final headerBuffer = StringBuffer();
    headerBuffer.write('POST ${PSConstants.registrationEndpointPS5} HTTP/1.1\r\n');
    headerBuffer.write('Host: ${host.hostAddress}:${PSConstants.registrationPort}\r\n');
    headerBuffer.write('User-Agent: remoteplay Windows\r\n');
    headerBuffer.write('Connection: close\r\n');
    headerBuffer.write('Content-Length: ${payload.length}\r\n');
    headerBuffer.write('Content-Type: application/x-www-form-urlencoded\r\n');
    headerBuffer.write('RP-Registkey: \r\n');
    headerBuffer.write('RP-Version: 2.0\r\n');
    headerBuffer.write('Np-AccountId: $accountIdBase64\r\n');
    headerBuffer.write('RP-ClientType: 11\r\n');
    headerBuffer.write('RP-PSN-ID: $psnOnlineId\r\n');
    headerBuffer.write('RP-Pin: $pin\r\n');
    headerBuffer.write('\r\n');

    // Combine headers and payload
    final headerBytes = utf8.encode(headerBuffer.toString());
    final request = Uint8List(headerBytes.length + payload.length);
    request.setRange(0, headerBytes.length, headerBytes);
    request.setRange(headerBytes.length, request.length, payload);

    return request;
  }

  /// Normalize PSN Account ID to valid Base64 format
  /// Accepts: Base64 encoded 8 bytes, or hex string (16 chars)
  String _normalizeAccountId(String accountId) {
    // First, try to decode as Base64
    try {
      final decoded = base64.decode(accountId);
      if (decoded.length == PSConstants.psnAccountIdSize) {
        return accountId; // Already valid Base64
      }
      // Wrong length, create default
      return base64.encode(List.filled(PSConstants.psnAccountIdSize, 0));
    } catch (e) {
      // Not valid Base64
    }

    // Try to parse as hex string (16 hex chars = 8 bytes)
    if (accountId.length == 16 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(accountId)) {
      try {
        final bytes = <int>[];
        for (int i = 0; i < accountId.length; i += 2) {
          bytes.add(int.parse(accountId.substring(i, i + 2), radix: 16));
        }
        return base64.encode(bytes);
      } catch (e) {
        // Hex parsing failed
      }
    }

    // Fallback to default (8 bytes of zeros)
    return base64.encode(List.filled(PSConstants.psnAccountIdSize, 0));
  }

  /// Parse registration response
  RegistrationResult _parseRegistrationResponse(Uint8List data) {
    try {
      final response = utf8.decode(data);
      final lines = response.split('\n');

      if (lines.isEmpty) {
        return _fail('Empty response');
      }

      final statusLine = lines.first.trim();
      if (!statusLine.contains('200')) {
        if (statusLine.contains('403')) {
          return _fail('Registration denied. Check PIN and try again.');
        }
        return _fail('Registration failed: $statusLine');
      }

      final headers = <String, String>{};
      for (var line in lines.skip(1)) {
        line = line.trim();
        if (line.isEmpty) continue;

        final colonIndex = line.indexOf(':');
        if (colonIndex > 0) {
          final key = line.substring(0, colonIndex).toLowerCase();
          final value = line.substring(colonIndex + 1).trim();
          headers[key] = value;
        }
      }

      final rpRegistKey = headers['rp-registkey'];
      final rpKeyStr = headers['rp-key'];
      final rpKeyTypeStr = headers['rp-keytype'];
      final serverMacStr = headers['rp-mac'];
      final serverNickname = headers['rp-nickname'];

      if (rpRegistKey == null || rpKeyStr == null) {
        return _fail('Missing registration data in response');
      }

      // Decode RP key
      final rpKey = base64.decode(rpKeyStr);
      final rpKeyType = int.tryParse(rpKeyTypeStr ?? '0') ?? 0;

      // Parse MAC address
      List<int>? serverMac;
      if (serverMacStr != null) {
        serverMac = serverMacStr
            .split(':')
            .map((s) => int.tryParse(s, radix: 16) ?? 0)
            .toList();
      }

      _emitEvent(RegistrationEventType.success);

      return RegistrationResult(
        success: true,
        rpRegistKey: rpRegistKey,
        rpKey: rpKey,
        rpKeyType: rpKeyType,
        serverMac: serverMac,
        serverNickname: serverNickname,
      );
    } catch (e) {
      return _fail('Failed to parse response: $e');
    }
  }

  /// Cancel ongoing registration
  void cancel() {
    _isCancelled = true;
    _socket?.close();
    _socket = null;
    _emitEvent(RegistrationEventType.cancelled);
  }

  RegistrationResult _fail(String message) {
    _emitEvent(RegistrationEventType.failed, message: message);
    return RegistrationResult(success: false, errorMessage: message);
  }

  void _emitEvent(RegistrationEventType type, {String? message}) {
    _eventController.add(RegistrationEvent(type: type, message: message));
  }

  void dispose() {
    cancel();
    _eventController.close();
  }
}
