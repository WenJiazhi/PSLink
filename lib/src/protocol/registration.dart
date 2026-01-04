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
    final headers = <String, String>{
      'Host': '${host.hostAddress}:${PSConstants.registrationPort}',
      'User-Agent': 'PSLink/1.0',
      'RP-Version': host.isPS5 ? '12.0' : '9.0',
      'RP-Registkey': '',
      'RP-ClientType': '11', // iOS
      'RP-Auth': psnAccountId,
      'RP-PSN-ID': psnOnlineId,
      'RP-Pin': pin,
    };

    final buffer = StringBuffer();
    buffer.writeln('GET /sce/rp/regist HTTP/1.1');
    headers.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    buffer.writeln();

    return Uint8List.fromList(utf8.encode(buffer.toString()));
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
