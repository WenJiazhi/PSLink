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
import 'audio_playback_service.dart';
import 'elementary_stream_server.dart';
import 'rp_stream_crypto.dart';
import 'rp_stream_packets.dart';
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
  RawDatagramSocket? _streamSocket;
  SessionState _state = SessionState.disconnected;
  String? _lastError;
  PSDevice? _device;
  StreamSettings _settings = const StreamSettings();
  _SessionCipher? _sessionCipher;
  RpStreamCipher? _streamCipher;
  RpStreamEcdh? _streamEcdh;
  ElementaryStreamServer? _videoServer;
  final List<int> _sessionBuffer = <int>[];
  Uint8List? _sessionId;
  DateTime? _lastHeartbeatAt;
  DateTime? _lastTakionHeartbeatAt;
  Completer<void>? _sessionReadyCompleter;
  Completer<void>? _streamReadyCompleter;
  RpFrameAssembler? _videoAssembler;
  RpFrameAssembler? _audioAssembler;
  AudioPlaybackService? _audioPlayback;
  AudioStreamConfig? _audioConfig;
  ControllerState _lastControllerState = ControllerState.empty;
  int _streamLocalTag = 1;
  int _streamRemoteTag = 0;
  int _streamTsn = 1;
  int _feedbackSequence = 0;
  int _videoBytesThisSecond = 0;
  int _audioBytesThisSecond = 0;
  int _videoFramesThisSecond = 0;
  int _packetLossThisSecond = 0;

  SessionState get state => _state;
  String? get lastError => _lastError;
  PSDevice? get device => _device;
  StreamSettings get settings => _settings;
  String? get videoStreamUrl => _videoServer?.url;

  final _stateController = StreamController<SessionState>.broadcast();
  final _videoController = StreamController<Uint8List>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();
  final _statsController = StreamController<StreamStats>.broadcast();

  Stream<SessionState> get stateStream => _stateController.stream;
  Stream<Uint8List> get videoStream => _videoController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<StreamStats> get statsStream => _statsController.stream;

  Timer? _heartbeatTimer;
  Timer? _streamHeartbeatTimer;
  Timer? _congestionTimer;
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
      await _startVideoServer();
      await _initializeMediaTransport();
      _startTakionHeartbeat();
      _startCongestionReports();
      _startStatsCollection();
      _setState(SessionState.streaming);
      _logger.i('Remote Play stream started for ${device.hostName}');
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
    _streamHeartbeatTimer?.cancel();
    _congestionTimer?.cancel();
    _statsTimer?.cancel();
    _heartbeatTimer = null;
    _streamHeartbeatTimer = null;
    _congestionTimer = null;
    _statsTimer = null;

    try {
      await _sessionSocket?.close();
    } catch (error) {
      _logger.w('Failed to close session socket cleanly', error: error);
      _sessionSocket?.destroy();
    }

    try {
      _streamSocket?.close();
    } catch (error) {
      _logger.w('Failed to close stream socket cleanly', error: error);
    }

    _sessionSocket = null;
    _streamSocket = null;
    _sessionCipher = null;
    _streamCipher = null;
    _streamEcdh = null;
    await _audioPlayback?.dispose();
    _audioPlayback = null;
    _audioConfig = null;
    await _videoServer?.stop();
    _videoServer = null;
    _sessionBuffer.clear();
    _sessionId = null;
    _lastHeartbeatAt = null;
    _lastTakionHeartbeatAt = null;
    _sessionReadyCompleter = null;
    _streamReadyCompleter = null;
    _videoAssembler = null;
    _audioAssembler = null;
    _lastControllerState = ControllerState.empty;
    _streamLocalTag = 1;
    _streamRemoteTag = 0;
    _streamTsn = 1;
    _feedbackSequence = 0;
    _videoBytesThisSecond = 0;
    _audioBytesThisSecond = 0;
    _videoFramesThisSecond = 0;
    _packetLossThisSecond = 0;
    _device = null;

    _setState(SessionState.disconnected);
  }

  void sendControllerInput(ControllerState input) {
    if (_state != SessionState.streaming || _streamCipher == null || _device == null) {
      return;
    }

    _sendButtonDiffs(_lastControllerState, input);
    if (_sticksChanged(_lastControllerState, input)) {
      _sendStateFeedback(input);
    }
    _lastControllerState = input;
  }

  Future<void> updateSettings(StreamSettings newSettings) async {
    _settings = newSettings;
    if (_state == SessionState.streaming) {
      final audioConfig = _audioConfig;
      if (audioConfig != null) {
        await _configureAudioPlayback(audioConfig);
      }
      _logger.i(
        'Updated stream settings locally. Changes apply fully on the next stream session.',
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

    final response = await _promoteAuthenticatedSessionSocket(socket);
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

  Future<void> _startVideoServer() async {
    final device = _device;
    if (device == null) {
      return;
    }

    final codecIsHevc =
        device.deviceType == PSDeviceType.ps5 && _settings.enableHDR;
    final server = ElementaryStreamServer();
    await server.start(
      path: codecIsHevc ? '/stream.h265' : '/stream.h264',
      mimeType: codecIsHevc ? 'video/h265' : 'video/h264',
    );
    _videoServer = server;
  }

  Future<void> _initializeMediaTransport() async {
    final device = _device;
    if (device == null) {
      throw const SessionException('Cannot start media transport without a device.');
    }
    if (_sessionId == null) {
      throw const SessionException('Cannot start media transport without a session ID.');
    }

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.readEventsEnabled = true;
    socket.writeEventsEnabled = false;
    _streamReadyCompleter = Completer<void>();
    _lastTakionHeartbeatAt = DateTime.now();
    _streamSocket = socket;
    socket.listen(_handleStreamEvent, onError: (Object error, StackTrace stackTrace) {
      if (_state != SessionState.disconnected) {
        _lastError = 'Stream socket error: $error';
        _logger.e(_lastError!, error: error, stackTrace: stackTrace);
        _setState(SessionState.error);
      }
    });

    _sendControlPacket(
      RpControlPacket.init(
        tag: _streamLocalTag,
        tsn: _streamTsn,
      ),
    );

    await _streamReadyCompleter!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw const SessionException('Timed out waiting for the Takion stream to become ready.');
      },
    );
  }

  void _handleStreamEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }

    final socket = _streamSocket;
    if (socket == null || _device == null) {
      return;
    }

    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      final data = datagram!.data;
      if (data.isEmpty) {
        continue;
      }

      try {
        if (RpControlPacket.isAv(data)) {
          _handleAvPacket(data);
        } else {
          _handleControlPacket(data);
        }
      } catch (error, stackTrace) {
        _logger.w('Ignored malformed stream packet', error: error, stackTrace: stackTrace);
      }
    }
  }

  void _handleControlPacket(Uint8List data) {
    final packet = RpControlPacket.parse(data);

    if (_streamCipher != null && packet.gmac != 0) {
      final withoutAuth = Uint8List.fromList(data);
      for (var index = 5; index < 13; index++) {
        withoutAuth[index] = 0;
      }
      final valid = _streamCipher!.verifyGmac(
        withoutAuth,
        packet.keyPos,
        (Uint8List(4)
          ..buffer.asByteData().setUint32(0, packet.gmac, Endian.big)),
      );
      if (!valid) {
        _logger.w('Discarded stream control packet with invalid GMAC.');
        return;
      }
    }

    switch (packet.chunkType) {
      case RpStreamChunkType.initAck:
        _streamRemoteTag = packet.tag ?? 0;
        if (packet.data == null) {
          throw const SessionException('Takion INIT_ACK did not include cookie data.');
        }
        _sendControlPacket(
          RpControlPacket.cookie(
            tagLocal: _streamLocalTag,
            tagRemote: _streamRemoteTag,
            data: packet.data!,
          ),
        );
        break;
      case RpStreamChunkType.cookieAck:
        _sendBig();
        break;
      case RpStreamChunkType.data:
        if (packet.tsn != null) {
          _sendControlPacket(
            RpControlPacket.dataAck(
              tagLocal: _streamLocalTag,
              tagRemote: _streamRemoteTag,
              tsn: packet.tsn!,
            ),
            cipher: _streamCipher,
          );
        }
        if (packet.data != null) {
          _handleTakionPayload(packet.data!);
        }
        break;
      case RpStreamChunkType.dataAck:
        break;
      default:
        _logger.d('Ignored stream chunk 0x${packet.chunkType.toRadixString(16)}');
        break;
    }
  }

  void _sendBig() {
    final sessionId = _sessionId;
    final sessionCipher = _sessionCipher;
    final device = _device;
    if (sessionId == null || sessionCipher == null || device == null) {
      throw const SessionException('Cannot send BIG without an active authenticated session.');
    }

    _streamEcdh = RpStreamEcdh(handshakeKey: _randomBytes(16));
    final launchSpec = buildLaunchSpec(
      device.deviceType,
      _streamEcdh!.handshakeKey,
      rttMs: PSConstants.defaultTakionRttMs,
      mtu: PSConstants.defaultTakionMtu,
    );
    final streamMask = sessionCipher.encryptWithCounter(
      Uint8List(launchSpec.length),
      counter: 0,
    );
    final encodedLaunchSpec = Uint8List(launchSpec.length);
    for (var index = 0; index < launchSpec.length; index++) {
      encodedLaunchSpec[index] = streamMask[index] ^ launchSpec[index];
    }

    final sessionKey = ascii.decode(sessionId, allowInvalid: true);
    final bigPayload = TakionCodec.encodeBig(
      TakionBigPayload(
        clientVersion: device.deviceType == PSDeviceType.ps5 ? 12 : 9,
        sessionKey: sessionKey,
        launchSpec: base64Encode(encodedLaunchSpec),
        encryptedKey: Uint8List(4),
        ecdhPublicKey: _streamEcdh!.publicKey,
        ecdhSignature: _streamEcdh!.publicSignature,
      ),
    );

    _sendTakionPayload(
      bigPayload,
      channel: 1,
      encryptPayload: false,
      advanceBy: 0,
    );
  }

  void _handleTakionPayload(Uint8List payload) {
    final message = handleTakionControlMessage(payload);
    if (message == null) {
      return;
    }

    _lastTakionHeartbeatAt = DateTime.now();

    switch (message.type) {
      case TakionMessageType.heartbeat:
        _sendTakionPayload(
          message.ackPayload!,
          channel: 1,
          encryptPayload: true,
          advanceBy: message.ackPayload!.length,
        );
        break;
      case TakionMessageType.streamInfo:
        final streamInfo = message.streamInfo;
        if (streamInfo == null || streamInfo.resolutions.isEmpty) {
          throw const SessionException('Takion STREAMINFO did not include resolution headers.');
        }
        _videoAssembler = RpFrameAssembler.video(
          header: streamInfo.resolutions.first.videoHeader,
        );
        _audioAssembler = RpFrameAssembler.audio(
          header: streamInfo.audioHeader,
        );
        final audioConfig = AudioStreamConfig.fromHeader(streamInfo.audioHeader);
        if (audioConfig != null) {
          _audioConfig = audioConfig;
          unawaited(_configureAudioPlayback(audioConfig));
        }
        _sendTakionPayload(
          message.ackPayload!,
          channel: 9,
          encryptPayload: true,
          advanceBy: message.ackPayload!.length,
        );
        _maybeCompleteStreamReady();
        break;
      case TakionMessageType.bang:
        final bang = message.bangPayload;
        if (bang == null) {
          throw const SessionException('Takion BANG payload was missing.');
        }
        if (!bang.versionAccepted || !bang.encryptedKeyAccepted) {
          throw SessionException(
            'Console rejected BIG payload (versionAccepted=${bang.versionAccepted}, encryptedKeyAccepted=${bang.encryptedKeyAccepted}).',
          );
        }
        if (!_streamEcdh!.setRemote(
          bang.ecdhPublicKey ?? Uint8List(0),
          bang.ecdhSignature ?? Uint8List(0),
        )) {
          throw const SessionException('Failed to verify Takion ECDH response.');
        }
        _streamCipher = _streamEcdh!.createCipher();
        _maybeCompleteStreamReady();
        break;
      case TakionMessageType.disconnect:
        throw SessionException(
          'Console closed the stream${message.disconnectReason == null ? '' : ': ${message.disconnectReason}'}',
        );
      case TakionMessageType.big:
      case TakionMessageType.info:
      case TakionMessageType.streamInfoAck:
        break;
    }
  }

  void _maybeCompleteStreamReady() {
    if (_streamCipher == null || _videoAssembler == null || _audioAssembler == null) {
      return;
    }
    final completer = _streamReadyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _handleAvPacket(Uint8List data) {
    final cipher = _streamCipher;
    final device = _device;
    if (cipher == null || device == null) {
      return;
    }

    final packet = RpAvPacket.parse(
      data,
      deviceType: device.deviceType,
    );
    packet.decrypt(cipher);

    if (packet.isVideo) {
      final frame = _videoAssembler?.addPacket(packet);
      if (frame != null) {
        _videoBytesThisSecond += frame.length;
        _videoFramesThisSecond++;
        _videoServer?.push(frame);
        _videoController.add(frame);
      }
    } else if (packet.isAudio) {
      final frame = _audioAssembler?.addPacket(packet);
      if (frame != null) {
        _audioBytesThisSecond += frame.length;
        _audioPlayback?.pushOpusFrame(frame);
        _audioController.add(frame);
      }
    }
  }

  Future<void> _configureAudioPlayback(AudioStreamConfig config) async {
    final playback = _audioPlayback ??= AudioPlaybackService();
    await playback.configure(
      config,
      latencyMs: _settings.audioLatency,
    );
  }

  void _sendControlPacket(
    RpControlPacket packet, {
    RpStreamCipher? cipher,
    bool encryptPayload = false,
    int? advanceBy,
  }) {
    final socket = _streamSocket;
    final device = _device;
    if (socket == null || device == null) {
      return;
    }

    final message = packet.toBytes(
      cipher: cipher,
      encryptPayload: encryptPayload,
      advanceBy: advanceBy,
    );
    socket.send(
      message,
      InternetAddress(device.ipAddress),
      9296,
    );

    if (packet.chunkType == RpStreamChunkType.data && packet.tsn != null) {
      _streamTsn = max(_streamTsn, packet.tsn!);
    }
  }

  void _sendTakionPayload(
    Uint8List payload, {
    required int channel,
    required bool encryptPayload,
    required int advanceBy,
  }) {
    final packet = RpControlPacket.data(
      tagRemote: _streamRemoteTag,
      tsn: _nextTsn(),
      flag: 1,
      channel: channel,
      data: payload,
    );
    _sendControlPacket(
      packet,
      cipher: _streamCipher,
      encryptPayload: encryptPayload,
      advanceBy: advanceBy == 0 ? null : advanceBy,
    );
  }

  void _startTakionHeartbeat() {
    _streamHeartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_streamCipher == null) {
        return;
      }
      final lastSeen = _lastTakionHeartbeatAt;
      if (lastSeen != null &&
          DateTime.now().difference(lastSeen) > const Duration(seconds: 10)) {
        _lastError = 'Takion stream timed out.';
        _setState(SessionState.error);
        return;
      }
      final heartbeat = TakionCodec.encodeHeartbeat();
      _sendTakionPayload(
        heartbeat,
        channel: 1,
        encryptPayload: true,
        advanceBy: heartbeat.length,
      );
    });
  }

  void _startCongestionReports() {
    _congestionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final socket = _streamSocket;
      final cipher = _streamCipher;
      final device = _device;
      if (socket == null || cipher == null || device == null) {
        return;
      }

      final received = (_videoAssembler?.received ?? 0) + (_audioAssembler?.received ?? 0);
      final lost = (_videoAssembler?.lost ?? 0) + (_audioAssembler?.lost ?? 0);
      _packetLossThisSecond = lost;
      final packet = buildCongestionPacket(
        received: received & 0xFFFF,
        lost: lost & 0xFFFF,
        cipher: cipher,
      );
      socket.send(packet, InternetAddress(device.ipAddress), 9296);
    });
  }

  void _startStatsCollection() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _statsController.add(
        StreamStats(
          videoBitrate: _videoBytesThisSecond * 8,
          audioBitrate: _audioBytesThisSecond * 8,
          fps: _videoFramesThisSecond.toDouble(),
          latencyMs: 0,
          packetLoss: _packetLossThisSecond,
          timestamp: DateTime.now(),
        ),
      );
      _videoBytesThisSecond = 0;
      _audioBytesThisSecond = 0;
      _videoFramesThisSecond = 0;
      _packetLossThisSecond = 0;
    });
  }

  int _nextTsn() {
    _streamTsn += 1;
    return _streamTsn;
  }

  int _nextFeedbackSequence() {
    _feedbackSequence = (_feedbackSequence + 1) & 0xFFFF;
    return _feedbackSequence;
  }

  void _sendStateFeedback(ControllerState state) {
    final socket = _streamSocket;
    final cipher = _streamCipher;
    final device = _device;
    if (socket == null || cipher == null || device == null) {
      return;
    }

    final packet = buildFeedbackStatePacket(
      sequence: _nextFeedbackSequence(),
      deviceType: device.deviceType,
      leftX: _normalizeStickAxis(state.leftStickX),
      leftY: _normalizeStickAxis(state.leftStickY),
      rightX: _normalizeStickAxis(state.rightStickX),
      rightY: _normalizeStickAxis(state.rightStickY),
      cipher: cipher,
    );
    socket.send(packet, InternetAddress(device.ipAddress), 9296);
  }

  void _sendButtonDiffs(ControllerState previous, ControllerState current) {
    final mapping = <({bool before, bool after, int button})>[
      (
        before: previous.cross,
        after: current.cross,
        button: RpFeedbackButton.cross,
      ),
      (
        before: previous.circle,
        after: current.circle,
        button: RpFeedbackButton.circle,
      ),
      (
        before: previous.square,
        after: current.square,
        button: RpFeedbackButton.square,
      ),
      (
        before: previous.triangle,
        after: current.triangle,
        button: RpFeedbackButton.triangle,
      ),
      (
        before: previous.l1,
        after: current.l1,
        button: RpFeedbackButton.l1,
      ),
      (
        before: previous.r1,
        after: current.r1,
        button: RpFeedbackButton.r1,
      ),
      (
        before: previous.l3,
        after: current.l3,
        button: RpFeedbackButton.l3,
      ),
      (
        before: previous.r3,
        after: current.r3,
        button: RpFeedbackButton.r3,
      ),
      (
        before: previous.options,
        after: current.options,
        button: RpFeedbackButton.options,
      ),
      (
        before: previous.share,
        after: current.share,
        button: RpFeedbackButton.share,
      ),
      (
        before: previous.ps,
        after: current.ps,
        button: RpFeedbackButton.ps,
      ),
      (
        before: previous.touchpad,
        after: current.touchpad,
        button: RpFeedbackButton.touchpad,
      ),
      (
        before: previous.dpadUp,
        after: current.dpadUp,
        button: RpFeedbackButton.up,
      ),
      (
        before: previous.dpadDown,
        after: current.dpadDown,
        button: RpFeedbackButton.down,
      ),
      (
        before: previous.dpadLeft,
        after: current.dpadLeft,
        button: RpFeedbackButton.left,
      ),
      (
        before: previous.dpadRight,
        after: current.dpadRight,
        button: RpFeedbackButton.right,
      ),
      (
        before: previous.l2 > 0.1,
        after: current.l2 > 0.1,
        button: RpFeedbackButton.l2,
      ),
      (
        before: previous.r2 > 0.1,
        after: current.r2 > 0.1,
        button: RpFeedbackButton.r2,
      ),
    ];

    for (final item in mapping) {
      if (item.before != item.after) {
        _sendButtonEvent(item.button, item.after);
      }
    }
  }

  void _sendButtonEvent(int button, bool active) {
    final socket = _streamSocket;
    final cipher = _streamCipher;
    final device = _device;
    if (socket == null || cipher == null || device == null) {
      return;
    }

    final packet = buildFeedbackEventPacket(
      sequence: _nextFeedbackSequence(),
      button: button,
      active: active,
      cipher: cipher,
    );
    socket.send(packet, InternetAddress(device.ipAddress), 9296);
  }

  bool _sticksChanged(ControllerState a, ControllerState b) {
    return a.leftStickX != b.leftStickX ||
        a.leftStickY != b.leftStickY ||
        a.rightStickX != b.rightStickX ||
        a.rightStickY != b.rightStickY;
  }

  int _normalizeStickAxis(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    return (clamped * 0x7FFF).round().clamp(-0x7FFF, 0x7FFF);
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

  Future<_HttpResponseData> _promoteAuthenticatedSessionSocket(
    Socket socket,
  ) async {
    final completer = Completer<_HttpResponseData>();
    final buffer = <int>[];
    Timer? timeout;
    var responseParsed = false;

    _sessionReadyCompleter = Completer<void>();
    _sessionSocket = socket;

    socket.listen(
      (chunk) {
        if (responseParsed) {
          _handleSessionBytes(chunk);
          return;
        }

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

        responseParsed = true;
        timeout?.cancel();
        completer.complete(
          _HttpResponseData(
            statusCode: statusCode,
            statusLine: statusLine,
            headers: headers,
            remainingBody: remainingBytes,
          ),
        );

        if (remainingBytes.isNotEmpty) {
          _handleSessionBytes(remainingBytes);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          timeout?.cancel();
          completer.completeError(
            const SessionException(
              'Socket closed before the HTTP response completed.',
            ),
          );
          return;
        }

        if (_state == SessionState.streaming ||
            _state == SessionState.authenticating) {
          _lastError = 'Session socket closed unexpectedly.';
          _setState(SessionState.error);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          timeout?.cancel();
          completer.completeError(error, stackTrace);
          return;
        }

        if (_state != SessionState.disconnected) {
          _lastError = 'Session socket error: $error';
          _logger.e(_lastError!, error: error, stackTrace: stackTrace);
          _setState(SessionState.error);
        }
      },
      cancelOnError: true,
    );

    timeout = Timer(
      Duration(milliseconds: PSConstants.connectionTimeout),
      () {
        if (!completer.isCompleted) {
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

  Uint8List encryptWithCounter(Uint8List input, {required int counter}) {
    return _crypt(input, counter: counter, encrypt: true);
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
