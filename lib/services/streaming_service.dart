import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

import '../core/constants.dart';
import '../models/controller_state.dart';
import '../models/ps_device.dart';
import '../models/stream_settings.dart';
import 'streaming_keys.dart';
import 'takion_codec.dart';

enum SessionState {
  disconnected,
  connecting,
  authenticating,
  streaming,
  paused,
  error,
}

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
  String toString() {
    return 'StreamStats{bitrate: ${videoBitrate}kbps, fps: ${fps.toStringAsFixed(1)}, latency: ${latencyMs}ms}';
  }
}

class StreamingService {
  static const _sessionHeaderLength = 8;
  static const _osType = 'Win10.0.0';
  static final Uint8List _didPrefix = Uint8List.fromList([
    0x00,
    0x18,
    0x00,
    0x00,
    0x00,
    0x07,
    0x00,
    0x40,
    0x00,
    0x80,
  ]);
  static final Uint8List _heartbeatResponsePayload = Uint8List.fromList([
    0x00,
    0x00,
    0x00,
    0x00,
    0x01,
    0xFE,
    0x00,
    0x00,
  ]);

  final Logger _logger = Logger();
  final Random _random = Random.secure();

  Socket? _sessionSocket;
  SessionState _state = SessionState.disconnected;
  String? _lastError;
  PSDevice? _device;
  StreamSettings _settings = const StreamSettings();
  _SessionCipher? _sessionCipher;
  final List<int> _sessionBuffer = <int>[];
  Uint8List? _sessionId;
  DateTime? _lastHeartbeatAt;
  Completer<void>? _sessionReadyCompleter;

  SessionState get state => _state;
  String? get lastError => _lastError;
  PSDevice? get device => _device;
  StreamSettings get settings => _settings;

  final _stateController = StreamController<SessionState>.broadcast();
  final _videoController = StreamController<Uint8List>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();
  final _statsController = StreamController<StreamStats>.broadcast();

  Stream<SessionState> get stateStream => _stateController.stream;
  Stream<Uint8List> get videoStream => _videoController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<StreamStats> get statsStream => _statsController.stream;

  Timer? _heartbeatTimer;
  Timer? _statsTimer;

  @visibleForTesting
  Uint8List generateRpNonce(PSDeviceType deviceType, Uint8List nonce) {
    final profile = _HostProfile.forDeviceType(deviceType);
    return _generateRpNonce(profile, nonce);
  }

  @visibleForTesting
  Uint8List generateAesKey(
    PSDeviceType deviceType,
    Uint8List nonce,
    Uint8List rpKey,
  ) {
    final profile = _HostProfile.forDeviceType(deviceType);
    return _generateAesKey(profile, nonce, rpKey);
  }

  @visibleForTesting
  Uint8List buildLaunchSpec(
    PSDeviceType deviceType,
    Uint8List handshakeKey, {
    int rttMs = PSConstants.defaultTakionRttMs,
    int mtu = PSConstants.defaultTakionMtu,
  }) {
    final launchSpec = <String, Object?>{
      'sessionId': 'sessionId4321',
      'streamResolutions': <Map<String, Object?>>[
        <String, Object?>{
          'resolution': <String, int>{
            'width': _settings.resolutionWidth,
            'height': _settings.resolutionHeight,
          },
          'maxFps': _settings.frameRate,
          'score': 10,
        },
      ],
      'network': <String, Object?>{
        'bwKbpsSent': _settings.bitrate,
        'bwLoss': 0.001,
        'mtu': mtu,
        'rtt': rttMs,
        'ports': const <int>[53, 2053],
      },
      'slotId': 1,
      'appSpecification': <String, Object?>{
        'minFps': 30,
        'minBandwidth': 0,
        'extTitleId': 'ps3',
        'version': 1,
        'timeLimit': 1,
        'startTimeout': 100,
        'afkTimeout': 100,
        'afkTimeoutDisconnect': 100,
      },
      'konan': <String, String>{
        'ps3AccessToken': 'accessToken',
        'ps3RefreshToken': 'refreshToken',
      },
      'requestGameSpecification': <String, Object?>{
        'model': 'bravia_tv',
        'platform': 'android',
        'audioChannels': '5.1',
        'language': 'sp',
        'acceptButton': 'X',
        'connectedControllers': const <String>['xinput', 'ds3', 'ds4'],
        'yuvCoefficient': 'bt601',
        'videoEncoderProfile': 'hw4.1',
        'audioEncoderProfile': 'audio1',
        if (deviceType == PSDeviceType.ps5) 'adaptiveStreamMode': 'resize',
      },
      'userProfile': <String, Object?>{
        'onlineId': 'psnId',
        'npId': 'npId',
        'region': 'US',
        'languagesUsed': const <String>['en', 'jp'],
      },
      'videoCodec': _settings.enableHDR && deviceType == PSDeviceType.ps5
          ? 'hevc'
          : 'avc',
      'dynamicRange': _settings.enableHDR && deviceType == PSDeviceType.ps5
          ? 'HDR'
          : 'SDR',
      'handshakeKey': base64Encode(handshakeKey),
    };

    var encoded = jsonEncode(launchSpec);
    encoded = encoded.replaceAll(' ', '');
    encoded = encoded.replaceAll(':0.001,', ':0.001000,');
    return Uint8List.fromList([...utf8.encode(encoded), 0]);
  }

  @visibleForTesting
  TakionControlMessage? handleTakionControlMessage(Uint8List payload) {
    final decoded = TakionCodec.decode(payload);
    if (decoded == null) {
      return null;
    }

    switch (decoded.type) {
      case TakionMessageType.heartbeat:
        return TakionControlMessage(
          type: decoded.type,
          ackPayload: TakionCodec.encodeHeartbeat(),
        );
      case TakionMessageType.streamInfo:
        return TakionControlMessage(
          type: decoded.type,
          ackPayload: TakionCodec.encodeStreamInfoAck(),
          streamInfo: decoded.streamInfoPayload,
        );
      case TakionMessageType.bang:
        return TakionControlMessage(
          type: decoded.type,
          bangPayload: decoded.bangPayload,
        );
      case TakionMessageType.disconnect:
        return TakionControlMessage(
          type: decoded.type,
          disconnectReason: decoded.disconnectPayload?.reason,
        );
      case TakionMessageType.big:
      case TakionMessageType.info:
      case TakionMessageType.streamInfoAck:
        return TakionControlMessage(type: decoded.type);
    }
  }

  Future<bool> startSession(PSDevice device, StreamSettings settings) async {
    if (_state != SessionState.disconnected) {
      _logger.w('Session already active');
      return false;
    }

    if (!device.isRegistered ||
        device.registKey == null ||
        device.rpKey == null) {
      _lastError = 'The console is not registered yet.';
      return false;
    }

    _device = device;
    _settings = settings;
    _lastError = null;
    _setState(SessionState.connecting);

    try {
      _setState(SessionState.authenticating);
      await _initializeRemotePlaySession();
      await _waitForSessionId();
      _startHeartbeat();
      _startStatsCollection();
      _setState(SessionState.streaming);
      _logger.i('Remote Play session authenticated for ${device.hostName}');
      _logger.w(
        'Media transport is still pending; session auth is now using the real protocol.',
      );
      return true;
    } catch (error) {
      _lastError = 'Failed to start session: $error';
      _logger.e(_lastError!, error: error);
      _setState(SessionState.error);
      await stopSession();
      return false;
    }
  }

  Future<void> stopSession() async {
    _heartbeatTimer?.cancel();
    _statsTimer?.cancel();
    _heartbeatTimer = null;
    _statsTimer = null;

    try {
      await _sessionSocket?.close();
    } catch (error) {
      _logger.w('Failed to close session socket cleanly', error: error);
      _sessionSocket?.destroy();
    }

    _sessionSocket = null;
    _sessionCipher = null;
    _sessionBuffer.clear();
    _sessionId = null;
    _lastHeartbeatAt = null;
    _sessionReadyCompleter = null;
    _device = null;

    _setState(SessionState.disconnected);
  }

  void sendControllerInput(ControllerState input) {
    if (_state != SessionState.streaming) {
      return;
    }

    _logger.d(
      'Controller input is deferred until the stream transport is implemented: $input',
    );
  }

  Future<void> updateSettings(StreamSettings newSettings) async {
    _settings = newSettings;
    if (_state == SessionState.streaming) {
      _logger.i(
        'Updated stream settings locally. In-session renegotiation still depends on media transport work.',
      );
    }
  }

  void dispose() {
    stopSession();
    _stateController.close();
    _videoController.close();
    _audioController.close();
    _statsController.close();
  }

  void _setState(SessionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> _initializeRemotePlaySession() async {
    final profile = _HostProfile.forDevice(_device!);
    final nonce = await _requestInitNonce(profile);
    await _authenticateSession(profile, nonce);
  }

  Future<Uint8List> _requestInitNonce(_HostProfile profile) async {
    final socket = await Socket.connect(
      _device!.ipAddress,
      PSConstants.remotePlayPort,
      timeout: Duration(milliseconds: PSConstants.connectionTimeout),
    );
    socket.setOption(SocketOption.tcpNoDelay, true);

    try {
      socket.add(
        ascii.encode(
          'GET ${profile.initPath} HTTP/1.1\r\n'
          'Host: ${_device!.ipAddress}:${PSConstants.remotePlayPort}\r\n'
          'User-Agent: ${PSConstants.remotePlayUserAgent}\r\n'
          'Connection: close\r\n'
          'Content-Length: 0\r\n'
          'RP-Registkey: ${_device!.registKey}\r\n'
          'RP-Version: ${profile.remotePlayVersion}\r\n'
          '\r\n',
        ),
      );
      await socket.flush();

      final response = await _readHttpResponse(socket);
      if (response.statusCode != 200) {
        final reason = response.headers['rp-application-reason'];
        throw SessionException(
          'Console rejected session init (${response.statusCode}${reason == null ? '' : ', reason: $reason'}).',
        );
      }

      final nonceValue = response.headers['rp-nonce'];
      if (nonceValue == null || nonceValue.isEmpty) {
        throw const SessionException(
          'Session init succeeded but RP-Nonce was missing.',
        );
      }
      return Uint8List.fromList(base64Decode(nonceValue));
    } finally {
      await socket.close();
    }
  }

  Future<void> _authenticateSession(
    _HostProfile profile,
    Uint8List nonce,
  ) async {
    final rpKey = _decodeHexField(_device!.rpKey!, fieldName: 'RP-Key');
    final aesKey = _generateAesKey(profile, nonce, rpKey);
    final rpNonce = _generateRpNonce(profile, nonce);
    _sessionCipher = _SessionCipher(
      hostType: profile.hostType,
      key: aesKey,
      nonce: rpNonce,
      hmacKey: profile.hmacKey,
    );

    final socket = await Socket.connect(
      _device!.ipAddress,
      PSConstants.remotePlayPort,
      timeout: Duration(milliseconds: PSConstants.connectionTimeout),
    );
    socket.setOption(SocketOption.tcpNoDelay, true);

    final request = _buildSessionRequest(profile);
    socket.add(ascii.encode(request));
    await socket.flush();

    final response = await _readHttpResponse(socket);
    if (response.statusCode != 200) {
      final reason = response.headers['rp-application-reason'];
      await socket.close();
      throw SessionException(
        'Console rejected session auth (${response.statusCode}${reason == null ? '' : ', reason: $reason'}).',
      );
    }

    final serverTypeValue = response.headers['rp-server-type'];
    if (serverTypeValue == null || serverTypeValue.isEmpty) {
      await socket.close();
      throw const SessionException(
        'Session auth succeeded but RP-Server-Type was missing.',
      );
    }

    final encryptedServerType = Uint8List.fromList(
      base64Decode(serverTypeValue),
    );
    final decryptedServerType = _sessionCipher!.decrypt(encryptedServerType);
    final serverType = _littleEndianInt(decryptedServerType);
    _logger.d('Authenticated against server type $serverType');

    _sessionReadyCompleter = Completer<void>();
    _sessionSocket = socket;
    socket.listen(
      _handleSessionBytes,
      onError: (Object error, StackTrace stackTrace) {
        if (_state != SessionState.disconnected) {
          _lastError = 'Session socket error: $error';
          _logger.e(_lastError!, error: error, stackTrace: stackTrace);
          _setState(SessionState.error);
        }
      },
      onDone: () {
        if (_state == SessionState.streaming ||
            _state == SessionState.authenticating) {
          _lastError = 'Session socket closed unexpectedly.';
          _setState(SessionState.error);
        }
      },
      cancelOnError: true,
    );

    if (response.remainingBody.isNotEmpty) {
      _handleSessionBytes(response.remainingBody);
    }
  }

  Future<void> _waitForSessionId() async {
    final completer = _sessionReadyCompleter;
    if (completer == null) {
      throw const SessionException(
        'Session authentication did not start correctly.',
      );
    }

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw const SessionException('Timed out waiting for the session ID.');
      },
    );
  }

  String _buildSessionRequest(_HostProfile profile) {
    final cipher = _sessionCipher;
    if (cipher == null) {
      throw const SessionException('Session cipher is not initialized.');
    }

    final registKeyBytes = _decodeHexField(
      _device!.registKey!,
      fieldName: 'RegistKey',
    );
    final authBytes = Uint8List.fromList([
      ...registKeyBytes,
      ...List<int>.filled(8, 0),
    ]);
    final didBytes = Uint8List.fromList([
      ..._didPrefix,
      ..._randomBytes(16),
      ...List<int>.filled(6, 0),
    ]);
    final osBytes = _buildOsTypeBytes();
    final bitrateBytes = Uint8List(4);
    final streamTypeBytes = _buildStreamTypeBytes(profile);

    final encryptedAuth = base64Encode(cipher.encrypt(authBytes));
    final encryptedDid = base64Encode(cipher.encrypt(didBytes));
    final encryptedOsType = base64Encode(cipher.encrypt(osBytes));
    final encryptedBitrate = base64Encode(cipher.encrypt(bitrateBytes));

    final buffer = StringBuffer()
      ..write('GET ${profile.sessionPath} HTTP/1.1\r\n')
      ..write('Host: ${_device!.ipAddress}:${PSConstants.remotePlayPort}\r\n')
      ..write('User-Agent: ${PSConstants.remotePlayUserAgent}\r\n')
      ..write('Connection: keep-alive\r\n')
      ..write('Content-Length: 0\r\n')
      ..write('RP-Auth: $encryptedAuth\r\n')
      ..write('RP-Version: ${profile.remotePlayVersion}\r\n')
      ..write('RP-Did: $encryptedDid\r\n')
      ..write('RP-ControllerType: 3\r\n')
      ..write('RP-ClientType: 11\r\n')
      ..write('RP-OSType: $encryptedOsType\r\n')
      ..write('RP-ConPath: 1\r\n')
      ..write('RP-StartBitrate: $encryptedBitrate\r\n');

    if (profile.deviceType == PSDeviceType.ps5) {
      final encryptedStreamType = base64Encode(cipher.encrypt(streamTypeBytes));
      buffer.write('RP-StreamingType: $encryptedStreamType\r\n');
    }

    buffer.write('\r\n');
    return buffer.toString();
  }

  Uint8List _buildStreamTypeBytes(_HostProfile profile) {
    final streamType =
        profile.deviceType == PSDeviceType.ps5 && _settings.enableHDR ? 3 : 1;
    final bytes = ByteData(4)..setUint32(0, streamType, Endian.little);
    return bytes.buffer.asUint8List();
  }

  Uint8List _buildOsTypeBytes() {
    final bytes = ascii.encode(_osType);
    if (bytes.length >= 10) {
      return Uint8List.fromList(bytes.sublist(0, 10));
    }
    return Uint8List.fromList([
      ...bytes,
      ...List<int>.filled(10 - bytes.length, 0),
    ]);
  }

  void _handleSessionBytes(Uint8List data) {
    _sessionBuffer.addAll(data);

    while (_sessionBuffer.length >= _sessionHeaderLength) {
      final header = Uint8List.fromList(
        _sessionBuffer.sublist(0, _sessionHeaderLength),
      );
      final byteData = ByteData.sublistView(header);
      final payloadLength = byteData.getUint32(0, Endian.big);
      final totalLength = _sessionHeaderLength + payloadLength;
      if (_sessionBuffer.length < totalLength) {
        return;
      }

      final packet = Uint8List.fromList(_sessionBuffer.sublist(0, totalLength));
      _sessionBuffer.removeRange(0, totalLength);
      _handleSessionPacket(packet);
    }
  }

  void _handleSessionPacket(Uint8List packet) {
    final header = ByteData.sublistView(packet);
    final messageType = header.getUint16(4, Endian.big);
    final payloadLength = header.getUint32(0, Endian.big);
    var payload = Uint8List(0);
    if (payloadLength > 0) {
      payload = _sessionCipher!.decrypt(packet.sublist(_sessionHeaderLength));
    }

    switch (messageType) {
      case 0xFE:
        _lastHeartbeatAt = DateTime.now();
        _sendHeartbeatResponse();
        break;
      case 0x1FE:
        _lastHeartbeatAt = DateTime.now();
        break;
      case 0x33:
        if (_sessionId == null) {
          _sessionId = payload.length > 2 ? payload.sublist(2) : payload;
          if (!(_sessionReadyCompleter?.isCompleted ?? true)) {
            _sessionReadyCompleter!.complete();
          }
        }
        break;
      default:
        _logger.d('Ignored session message 0x${messageType.toRadixString(16)}');
        break;
    }
  }

  void _sendHeartbeatResponse() {
    _sendSessionMessage(0x1FE, _heartbeatResponsePayload);
  }

  void _sendHeartbeatRequest() {
    _sendSessionMessage(0xFE);
  }

  void _sendSessionMessage(int messageType, [Uint8List? payload]) {
    final socket = _sessionSocket;
    final cipher = _sessionCipher;
    if (socket == null || cipher == null) {
      return;
    }

    final plainPayload = payload ?? Uint8List(0);
    final encryptedPayload = plainPayload.isEmpty
        ? Uint8List(0)
        : cipher.encrypt(plainPayload);
    final message = Uint8List(_sessionHeaderLength + encryptedPayload.length);
    final byteData = ByteData.sublistView(message);
    byteData.setUint32(0, encryptedPayload.length, Endian.big);
    byteData.setUint16(4, messageType, Endian.big);
    if (encryptedPayload.isNotEmpty) {
      message.setRange(_sessionHeaderLength, message.length, encryptedPayload);
    }
    socket.add(message);
  }

  void _startHeartbeat() {
    _lastHeartbeatAt = DateTime.now();
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: PSConstants.heartbeatInterval),
      (_) {
        final lastSeen = _lastHeartbeatAt;
        if (lastSeen == null) {
          return;
        }
        if (DateTime.now().difference(lastSeen) >= const Duration(seconds: 5)) {
          _sendHeartbeatRequest();
        }
      },
    );
  }

  void _startStatsCollection() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _statsController.add(
        StreamStats(
          videoBitrate: _settings.bitrate,
          fps: _settings.frameRate.toDouble(),
          latencyMs: 0,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  Uint8List _generateRpNonce(_HostProfile profile, Uint8List nonce) {
    if (nonce.length < 16) {
      throw const SessionException('RP-Nonce must be 16 bytes.');
    }

    final table = profile.sessionKey0.sublist((nonce[0] >> 3) * 112);
    final rpNonce = Uint8List(16);
    for (var index = 0; index < 16; index++) {
      final shift = profile.deviceType == PSDeviceType.ps5
          ? nonce[index] - 45 - index
          : nonce[index] + 54 + index;
      rpNonce[index] = (shift ^ table[index]) & 0xFF;
    }
    return rpNonce;
  }

  Uint8List _generateAesKey(
    _HostProfile profile,
    Uint8List nonce,
    Uint8List rpKey,
  ) {
    if (nonce.length < 16 || rpKey.length < 16) {
      throw const SessionException('RP-Key and RP-Nonce must be 16 bytes.');
    }

    final table = profile.sessionKey1.sublist((nonce[7] >> 3) * 112);
    final aesKey = Uint8List(16);
    for (var index = 0; index < 16; index++) {
      final shift = profile.deviceType == PSDeviceType.ps5
          ? ((rpKey[index] + 24 + index) ^ nonce[index] ^ table[index])
          : ((((table[index] ^ rpKey[index]) + 33 + index) ^ nonce[index]));
      aesKey[index] = shift & 0xFF;
    }
    return aesKey;
  }

  Uint8List _decodeHexField(String value, {required String fieldName}) {
    final normalized = value.trim();
    if (normalized.length.isOdd) {
      throw SessionException('$fieldName is not valid hex.');
    }

    try {
      final bytes = <int>[];
      for (var index = 0; index < normalized.length; index += 2) {
        bytes.add(int.parse(normalized.substring(index, index + 2), radix: 16));
      }
      return Uint8List.fromList(bytes);
    } on FormatException {
      throw SessionException('$fieldName is not valid hex.');
    }
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  int _littleEndianInt(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    if (bytes.length >= 4) {
      return byteData.getUint32(0, Endian.little);
    }

    var result = 0;
    for (var index = 0; index < bytes.length; index++) {
      result |= bytes[index] << (index * 8);
    }
    return result;
  }

  Future<_HttpResponseData> _readHttpResponse(Socket socket) async {
    final completer = Completer<_HttpResponseData>();
    final buffer = <int>[];
    Timer? timeout;
    StreamSubscription<Uint8List>? subscription;

    subscription = socket.listen(
      (chunk) async {
        buffer.addAll(chunk);
        final headerEndIndex = _indexOfBytes(buffer, const [13, 10, 13, 10]);
        if (headerEndIndex < 0 || completer.isCompleted) {
          return;
        }

        final headerBytes = Uint8List.fromList(
          buffer.sublist(0, headerEndIndex),
        );
        final remainingBytes = Uint8List.fromList(
          buffer.sublist(headerEndIndex + 4),
        );
        final text = ascii.decode(headerBytes, allowInvalid: true);
        final lines = text.split(RegExp(r'\r?\n'));
        final statusLine = lines.first;
        final statusParts = statusLine.split(' ');
        final statusCode = statusParts.length > 1
            ? int.tryParse(statusParts[1]) ?? 0
            : 0;
        final headers = <String, String>{};

        for (final line in lines.skip(1)) {
          final separator = line.indexOf(':');
          if (separator <= 0) {
            continue;
          }

          final name = line.substring(0, separator).trim().toLowerCase();
          final value = line.substring(separator + 1).trim();
          headers[name] = value;
        }

        timeout?.cancel();
        await subscription?.cancel();
        completer.complete(
          _HttpResponseData(
            statusCode: statusCode,
            statusLine: statusLine,
            headers: headers,
            remainingBody: remainingBytes,
          ),
        );
      },
      onDone: () async {
        if (!completer.isCompleted) {
          timeout?.cancel();
          await subscription?.cancel();
          completer.completeError(
            const SessionException(
              'Socket closed before the HTTP response completed.',
            ),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) async {
        if (!completer.isCompleted) {
          timeout?.cancel();
          await subscription?.cancel();
          completer.completeError(error, stackTrace);
        }
      },
      cancelOnError: true,
    );

    timeout = Timer(
      Duration(milliseconds: PSConstants.connectionTimeout),
      () async {
        if (!completer.isCompleted) {
          await subscription?.cancel();
          completer.completeError(
            const SessionException('Timed out waiting for the HTTP response.'),
          );
        }
      },
    );

    return completer.future;
  }

  int _indexOfBytes(List<int> data, List<int> pattern) {
    for (var index = 0; index <= data.length - pattern.length; index++) {
      var matches = true;
      for (
        var patternIndex = 0;
        patternIndex < pattern.length;
        patternIndex++
      ) {
        if (data[index + patternIndex] != pattern[patternIndex]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return index;
      }
    }
    return -1;
  }
}

class SessionException implements Exception {
  const SessionException(this.message);

  final String message;

  @override
  String toString() => 'SessionException: $message';
}

class TakionControlMessage {
  const TakionControlMessage({
    required this.type,
    this.ackPayload,
    this.bangPayload,
    this.streamInfo,
    this.disconnectReason,
  });

  final TakionMessageType type;
  final Uint8List? ackPayload;
  final TakionBangPayload? bangPayload;
  final TakionStreamInfoPayload? streamInfo;
  final String? disconnectReason;
}

class _HttpResponseData {
  const _HttpResponseData({
    required this.statusCode,
    required this.statusLine,
    required this.headers,
    required this.remainingBody,
  });

  final int statusCode;
  final String statusLine;
  final Map<String, String> headers;
  final Uint8List remainingBody;
}

class _HostProfile {
  const _HostProfile({
    required this.deviceType,
    required this.hostType,
    required this.remotePlayVersion,
    required this.initPath,
    required this.sessionPath,
    required this.hmacKey,
    required this.sessionKey0,
    required this.sessionKey1,
  });

  final PSDeviceType deviceType;
  final String hostType;
  final String remotePlayVersion;
  final String initPath;
  final String sessionPath;
  final Uint8List hmacKey;
  final Uint8List sessionKey0;
  final Uint8List sessionKey1;

  static final ps4 = _HostProfile(
    deviceType: PSDeviceType.ps4,
    hostType: 'PS4',
    remotePlayVersion: PSConstants.remotePlayVersionPS4,
    initPath: '/sie/ps4/rp/sess/init',
    sessionPath: '/sie/ps4/rp/sess/ctrl',
    hmacKey: Uint8List.fromList([
      0x20,
      0xD6,
      0x6F,
      0x59,
      0x04,
      0xEA,
      0x7C,
      0x14,
      0xE5,
      0x57,
      0xFF,
      0xC5,
      0x2E,
      0x48,
      0x8A,
      0xC8,
    ]),
    sessionKey0: sessionKey0Ps4,
    sessionKey1: sessionKey1Ps4,
  );

  static final ps5 = _HostProfile(
    deviceType: PSDeviceType.ps5,
    hostType: 'PS5',
    remotePlayVersion: PSConstants.remotePlayVersionPS5,
    initPath: '/sie/ps5/rp/sess/init',
    sessionPath: '/sie/ps5/rp/sess/ctrl',
    hmacKey: Uint8List.fromList([
      0x46,
      0x46,
      0x87,
      0xB3,
      0x49,
      0xCA,
      0x8C,
      0xE8,
      0x59,
      0xC5,
      0x27,
      0x0F,
      0x5D,
      0x7A,
      0x69,
      0xD6,
    ]),
    sessionKey0: sessionKey0Ps5,
    sessionKey1: sessionKey1Ps5,
  );

  static _HostProfile forDevice(PSDevice device) {
    return forDeviceType(device.deviceType);
  }

  static _HostProfile forDeviceType(PSDeviceType type) {
    return type == PSDeviceType.ps5 ? ps5 : ps4;
  }
}

class _SessionCipher {
  _SessionCipher({
    required this.hostType,
    required this.key,
    required this.nonce,
    required this.hmacKey,
  });

  final String hostType;
  final Uint8List key;
  final Uint8List nonce;
  final Uint8List hmacKey;

  int _encryptCounter = 0;
  int _decryptCounter = 0;

  Uint8List encrypt(Uint8List input) {
    final output = _crypt(input, counter: _encryptCounter, encrypt: true);
    _encryptCounter++;
    return output;
  }

  Uint8List decrypt(Uint8List input) {
    final output = _crypt(input, counter: _decryptCounter, encrypt: false);
    _decryptCounter++;
    return output;
  }

  Uint8List _crypt(
    Uint8List input, {
    required int counter,
    required bool encrypt,
  }) {
    final iv = _deriveIv(counter);
    final aes = AESEngine()..init(true, KeyParameter(key));
    var feedback = Uint8List.fromList(iv);
    final output = Uint8List(input.length);

    for (var offset = 0; offset < input.length; offset += 16) {
      final chunkLength = min(16, input.length - offset);
      final keystream = Uint8List(16);
      aes.processBlock(feedback, 0, keystream, 0);

      for (var index = 0; index < chunkLength; index++) {
        output[offset + index] = input[offset + index] ^ keystream[index];
      }

      if (chunkLength == 16) {
        feedback = Uint8List.fromList(
          encrypt
              ? output.sublist(offset, offset + chunkLength)
              : input.sublist(offset, offset + chunkLength),
        );
      }
    }

    return output;
  }

  Uint8List _deriveIv(int counter) {
    final suffix = Uint8List(8);
    for (var index = 0; index < 8; index++) {
      final shift = (7 - index) * 8;
      suffix[index] = (counter >> shift) & 0xFF;
    }

    final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(hmacKey));
    final digest = hmac.process(Uint8List.fromList([...nonce, ...suffix]));
    return Uint8List.fromList(digest.sublist(0, 16));
  }
}
