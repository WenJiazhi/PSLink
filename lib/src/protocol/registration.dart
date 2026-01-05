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
  
  // Store crypto state for response decryption
  Uint8List? _bright;

  Stream<RegistrationEvent> get eventStream => _eventController.stream;

  /// Register with a PlayStation console
  /// [host] - The discovered PlayStation host
  /// [pin] - The 8-digit PIN displayed on the console
  /// [psnAccountId] - The PSN account ID (8 bytes, Base64 encoded)
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
      final chunks = <int>[];
      
      final subscription = _socket!.listen(
        (data) {
          chunks.addAll(data);
          // Check if we have complete response (look for double CRLF and content)
          final responseStr = utf8.decode(chunks, allowMalformed: true);
          if (responseStr.contains('\r\n\r\n')) {
            // Check if we have Content-Length and received all data
            final headerEnd = responseStr.indexOf('\r\n\r\n');
            if (headerEnd > 0) {
              final headers = responseStr.substring(0, headerEnd);
              final contentLengthMatch = RegExp(r'Content-Length:\s*(\d+)', caseSensitive: false).firstMatch(headers);
              if (contentLengthMatch != null) {
                final contentLength = int.parse(contentLengthMatch.group(1)!);
                final expectedTotal = headerEnd + 4 + contentLength;
                if (chunks.length >= expectedTotal) {
                  if (!responseCompleter.isCompleted) {
                    responseCompleter.complete(Uint8List.fromList(chunks));
                  }
                }
              } else {
                // No content length, complete on first response
                if (!responseCompleter.isCompleted) {
                  responseCompleter.complete(Uint8List.fromList(chunks));
                }
              }
            }
          }
        },
        onError: (error) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(error);
          }
        },
        onDone: () {
          if (!responseCompleter.isCompleted) {
            if (chunks.isNotEmpty) {
              responseCompleter.complete(Uint8List.fromList(chunks));
            } else {
              responseCompleter.completeError('Connection closed without response');
            }
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
      return _parseRegistrationResponse(response, host.isPS5);
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
    buffer.write('User-Agent: remoteplay Windows\r\n');
    buffer.write('Connection: close\r\n');
    buffer.write('RP-Version: 1.0\r\n');
    buffer.write('RP-Auth: $normalizedAccountId\r\n');
    buffer.write('RP-Pin: $pin\r\n');
    buffer.write('\r\n');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Build PS5 registration HTTP request (new protocol)
  /// Based on chiaki-ng implementation
  /// Key differences from PS4:
  /// - Uses POST to /sie/ps5/rp/sess/rgst
  /// - Includes encrypted binary payload
  /// - PIN is used for encryption, NOT sent in header
  Uint8List _buildPS5RegistrationRequest({
    required PSHost host,
    required String pin,
    required String psnAccountId,
    required String psnOnlineId,
  }) {
    // Parse PIN as integer
    final pinInt = int.parse(pin);
    
    // Validate and normalize PSN Account ID
    String accountIdBase64 = _normalizeAccountId(psnAccountId);

    // Build the registration payload using PS5 crypto
    final payloadResult = PS5RegistCrypto.buildRegistrationPayload(
      psnAccountId: accountIdBase64,
      psnOnlineId: psnOnlineId,
      pin: pinInt,
    );
    
    // Store bright key for response decryption
    _bright = payloadResult.bright;

    final payload = payloadResult.payload;

    // Build HTTP headers - following chiaki format exactly
    // Note: PIN is NOT sent in header for PS5, it's used for encryption
    final headerBuffer = StringBuffer();
    headerBuffer.write('POST ${PSConstants.registrationEndpointPS5} HTTP/1.1\r\n');
    headerBuffer.write('HOST: ${host.hostAddress}\r\n');
    headerBuffer.write('User-Agent: remoteplay Windows\r\n');
    headerBuffer.write('Connection: close\r\n');
    headerBuffer.write('Content-Length: ${payload.length}\r\n');
    headerBuffer.write('RP-Version: 2.0\r\n');
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
  RegistrationResult _parseRegistrationResponse(Uint8List data, bool isPS5) {
    try {
      final responseStr = utf8.decode(data, allowMalformed: true);
      
      // Find header/body split
      final headerEndIndex = responseStr.indexOf('\r\n\r\n');
      if (headerEndIndex < 0) {
        return _fail('Invalid response format');
      }
      
      final headerPart = responseStr.substring(0, headerEndIndex);
      final lines = headerPart.split('\r\n');

      if (lines.isEmpty) {
        return _fail('Empty response');
      }

      final statusLine = lines.first.trim();
      
      // Check status code
      final statusMatch = RegExp(r'HTTP/\d\.\d\s+(\d+)').firstMatch(statusLine);
      if (statusMatch == null) {
        return _fail('Invalid HTTP response: $statusLine');
      }
      
      final statusCode = statusMatch.group(1);
      if (statusCode != '200') {
        if (statusCode == '403') {
          return _fail('Registration denied. Check PIN and try again.');
        }
        // Try to get application reason
        for (var line in lines) {
          if (line.toLowerCase().startsWith('rp-application-reason:')) {
            final reason = line.substring(line.indexOf(':') + 1).trim();
            return _fail('Registration failed: $statusLine (Reason: $reason)');
          }
        }
        return _fail('Registration failed: $statusLine');
      }

      // Note: Content-Length is parsed from response but payload extraction
      // uses actual data length for robustness

      // Extract and decrypt payload for PS5
      Uint8List payloadBytes;
      final payloadStart = headerEndIndex + 4;
      
      if (payloadStart < data.length) {
        payloadBytes = data.sublist(payloadStart);
        
        // Decrypt payload if PS5 and we have bright key
        if (isPS5 && _bright != null && payloadBytes.isNotEmpty) {
          payloadBytes = PS5RegistCrypto.decryptResponse(payloadBytes, _bright!);
        }
      } else {
        payloadBytes = Uint8List(0);
      }

      // Parse decrypted payload as headers
      final payloadStr = utf8.decode(payloadBytes, allowMalformed: true);
      final payloadHeaders = <String, String>{};
      
      for (var line in payloadStr.split(RegExp(r'[\r\n]+'))) {
        line = line.trim();
        if (line.isEmpty) continue;

        final colonIndex = line.indexOf(':');
        if (colonIndex > 0) {
          final key = line.substring(0, colonIndex).trim();
          final value = line.substring(colonIndex + 1).trim();
          payloadHeaders[key] = value;
        }
      }

      // Also parse response headers
      for (var line in lines.skip(1)) {
        line = line.trim();
        if (line.isEmpty) continue;

        final colonIndex = line.indexOf(':');
        if (colonIndex > 0) {
          final key = line.substring(0, colonIndex).trim();
          final value = line.substring(colonIndex + 1).trim();
          payloadHeaders[key] = value;
        }
      }

      // Extract registration data
      final registKeyName = isPS5 ? 'PS5-RegistKey' : 'PS4-RegistKey';
      final macName = isPS5 ? 'PS5-Mac' : 'PS4-Mac';
      final nicknameName = isPS5 ? 'PS5-Nickname' : 'PS4-Nickname';
      
      String? rpRegistKey = payloadHeaders[registKeyName];
      final rpKeyStr = payloadHeaders['RP-Key'];
      final rpKeyTypeStr = payloadHeaders['RP-KeyType'];
      final serverMacStr = payloadHeaders[macName];
      String? serverNickname = payloadHeaders[nicknameName];

      if (rpRegistKey == null || rpKeyStr == null) {
        // Try lowercase keys
        for (var entry in payloadHeaders.entries) {
          if (entry.key.toLowerCase() == registKeyName.toLowerCase()) {
            rpRegistKey = entry.value;
          }
          if (entry.key.toLowerCase() == 'rp-key') {
            // Already handled above
          }
        }
        
        if (rpRegistKey == null) {
          return _fail('Missing registration key in response. Response: ${payloadStr.substring(0, payloadStr.length.clamp(0, 200))}');
        }
        if (rpKeyStr == null) {
          return _fail('Missing RP-Key in response');
        }
      }

      // Decode RP key (hex string to bytes)
      List<int> rpKey;
      try {
        rpKey = _parseHexString(rpKeyStr);
      } catch (e) {
        // Try base64
        try {
          rpKey = base64.decode(rpKeyStr);
        } catch (e2) {
          return _fail('Invalid RP-Key format');
        }
      }
      
      final rpKeyType = int.tryParse(rpKeyTypeStr ?? '0') ?? 0;

      // Parse MAC address
      List<int>? serverMac;
      if (serverMacStr != null) {
        try {
          serverMac = _parseHexString(serverMacStr.replaceAll(':', ''));
        } catch (e) {
          // Ignore MAC parse errors
        }
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

  /// Parse hex string to bytes
  List<int> _parseHexString(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
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
