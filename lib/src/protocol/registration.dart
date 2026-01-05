import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../models/ps_host.dart';
import 'constants.dart';

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
  Uint8List _buildPS4RegistrationRequest({
    required PSHost host,
    required String pin,
    required String psnAccountId,
    required String psnOnlineId,
  }) {
    // Normalize account ID for PS4 as well
    String normalizedAccountId = _normalizeAccountId(psnAccountId);

    final headers = <String, String>{
      'Host': '${host.hostAddress}:${PSConstants.registrationPort}',
      'User-Agent': 'PSLink/1.0',
      'RP-Version': '9.0',
      'RP-Registkey': '',
      'RP-ClientType': '11', // iOS
      'RP-Auth': normalizedAccountId,
      'RP-PSN-ID': psnOnlineId,
      'RP-Pin': pin,
    };

    final buffer = StringBuffer();
    buffer.write('GET ${PSConstants.registrationEndpointPS4} HTTP/1.1\r\n');
    headers.forEach((key, value) {
      buffer.write('$key: $value\r\n');
    });
    buffer.write('\r\n');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Build PS5 registration HTTP request (new protocol)
  /// Based on chiaki implementation: uses POST to /sie/ps5/rp/sess/rgst
  /// with Np-AccountId header instead of RP-Auth
  Uint8List _buildPS5RegistrationRequest({
    required PSHost host,
    required String pin,
    required String psnAccountId,
    required String psnOnlineId,
  }) {
    // Validate and normalize PSN Account ID (should be Base64 encoded 8 bytes)
    String accountIdBase64 = _normalizeAccountId(psnAccountId);

    final headers = <String, String>{
      'Host': '${host.hostAddress}:${PSConstants.registrationPort}',
      'User-Agent': 'PSLink/1.0',
      'RP-Version': '12.0',
      'RP-Registkey': '',
      'RP-ClientType': '11', // iOS
      'Np-AccountId': accountIdBase64, // PS5 uses Np-AccountId instead of RP-Auth
      'RP-PSN-ID': psnOnlineId,
      'RP-Pin': pin,
    };

    final buffer = StringBuffer();
    // PS5 uses POST to /sie/ps5/rp/sess/rgst instead of GET /sce/rp/regist
    buffer.write('POST ${PSConstants.registrationEndpointPS5} HTTP/1.1\r\n');
    headers.forEach((key, value) {
      buffer.write('$key: $value\r\n');
    });
    buffer.write('Content-Length: 0\r\n');
    buffer.write('\r\n');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
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
