import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../models/ps_host.dart';
import '../crypto/ecdh.dart';
import '../crypto/aes_gcm.dart';
import 'constants.dart';

/// Session states
enum SessionState {
  disconnected,
  connecting,
  handshaking,
  authenticated,
  streaming,
  disconnecting,
  error,
}

/// Session event types
enum SessionEventType {
  stateChanged,
  videoFrame,
  audioFrame,
  controllerFeedback,
  error,
}

/// Session event
class SessionEvent {
  final SessionEventType type;
  final dynamic data;
  final String? message;

  SessionEvent({required this.type, this.data, this.message});
}

/// PS Remote Play Session Manager
class PSSession {
  final PSHost host;
  final String psnAccountId;
  final String rpKey;

  Socket? _controlSocket;
  RawDatagramSocket? _dataSocket;

  late ECDHKeyExchange _ecdh;
  late AESGCMCrypto _crypto;
  // ignore: unused_field - reserved for future streaming encryption
  late GKCrypt _gkCrypt;

  SessionState _state = SessionState.disconnected;
  final StreamController<SessionEvent> _eventController = StreamController<SessionEvent>.broadcast();

  String? _sessionId;
  Uint8List? _handshakeKey;
  Uint8List? _sharedSecret;

  int _mtuIn = 1454;
  int _mtuOut = 1454;
  int _rttUs = 0;

  PSSession({
    required this.host,
    required this.psnAccountId,
    required this.rpKey,
  }) {
    _ecdh = ECDHKeyExchange();
    _crypto = AESGCMCrypto();
    _gkCrypt = GKCrypt();
  }

  SessionState get state => _state;
  Stream<SessionEvent> get eventStream => _eventController.stream;
  String? get sessionId => _sessionId;
  int get mtuIn => _mtuIn;
  int get mtuOut => _mtuOut;
  int get rttUs => _rttUs;

  /// Connect to the PlayStation console
  Future<void> connect() async {
    if (_state != SessionState.disconnected) {
      throw StateError('Session already in progress');
    }

    _setState(SessionState.connecting);

    try {
      // Connect to control port
      _controlSocket = await Socket.connect(
        host.hostAddress,
        PSConstants.sessionPort,
        timeout: const Duration(seconds: 10),
      );

      _controlSocket!.listen(
        _handleControlData,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      // Start handshake
      await _performHandshake();
    } catch (e) {
      _setState(SessionState.error);
      _emitEvent(SessionEventType.error, message: 'Connection failed: $e');
      rethrow;
    }
  }

  /// Disconnect from the PlayStation console
  Future<void> disconnect() async {
    if (_state == SessionState.disconnected) return;

    _setState(SessionState.disconnecting);

    _dataSocket?.close();
    _dataSocket = null;

    await _controlSocket?.close();
    _controlSocket = null;

    _setState(SessionState.disconnected);
  }

  /// Perform the session handshake
  Future<void> _performHandshake() async {
    _setState(SessionState.handshaking);

    // Generate handshake key from RP key
    _handshakeKey = _deriveHandshakeKey(rpKey);

    // Get local ECDH public key
    final localPubKey = _ecdh.getLocalPublicKey();
    final signature = await _ecdh.generateSignature(_handshakeKey!);

    // Send handshake request
    final request = _buildHandshakeRequest(localPubKey, signature);
    _controlSocket!.add(request);

    // Wait for response (handled in _handleControlData)
  }

  /// Build handshake HTTP request
  Uint8List _buildHandshakeRequest(Uint8List pubKey, Uint8List signature) {
    final pubKeyB64 = base64.encode(pubKey);
    final sigB64 = base64.encode(signature);

    final headers = <String, String>{
      'Host': '${host.hostAddress}:${PSConstants.sessionPort}',
      'User-Agent': 'PSLink/1.0',
      'RP-Version': host.isPS5 ? '12.0' : '9.0',
      'RP-RegistKey': rpKey,
      'RP-ClientType': '11', // iOS
      'RP-Auth': psnAccountId,
      'RP-ECDH-Pub': pubKeyB64,
      'RP-ECDH-Sig': sigB64,
    };

    final buffer = StringBuffer();
    buffer.writeln('GET /sce/rp/session HTTP/1.1');
    headers.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    buffer.writeln();

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Handle incoming control socket data
  void _handleControlData(Uint8List data) async {
    try {
      if (_state == SessionState.handshaking) {
        await _processHandshakeResponse(data);
      } else if (_state == SessionState.authenticated || _state == SessionState.streaming) {
        _processControlMessage(data);
      }
    } catch (e) {
      _handleError(e);
    }
  }

  /// Process handshake response
  Future<void> _processHandshakeResponse(Uint8List data) async {
    final response = utf8.decode(data);
    final lines = response.split('\n');

    if (lines.isEmpty || !lines.first.contains('200')) {
      throw Exception('Handshake failed: ${lines.first}');
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

    // Extract remote ECDH public key and signature
    final remotePubKeyB64 = headers['rp-ecdh-pub'];
    final remoteSigB64 = headers['rp-ecdh-sig'];
    _sessionId = headers['rp-session'];

    if (remotePubKeyB64 == null || remoteSigB64 == null || _sessionId == null) {
      throw Exception('Missing handshake parameters');
    }

    final remotePubKey = base64.decode(remotePubKeyB64);
    final remoteSig = base64.decode(remoteSigB64);

    // Verify signature
    final verified = await _ecdh.verifySignature(
      Uint8List.fromList(remotePubKey),
      _handshakeKey!,
      Uint8List.fromList(remoteSig),
    );

    if (!verified) {
      throw Exception('Remote signature verification failed');
    }

    // Derive shared secret
    _sharedSecret = await _ecdh.deriveSecret(Uint8List.fromList(remotePubKey));

    // Initialize encryption
    await _crypto.initialize(_sharedSecret!);

    // Parse MTU and RTT
    final mtuStr = headers['rp-mtu'];
    if (mtuStr != null) {
      final parts = mtuStr.split('/');
      if (parts.length == 2) {
        _mtuIn = int.tryParse(parts[0]) ?? 1454;
        _mtuOut = int.tryParse(parts[1]) ?? 1454;
      }
    }

    final rttStr = headers['rp-rtt'];
    if (rttStr != null) {
      _rttUs = int.tryParse(rttStr) ?? 0;
    }

    _setState(SessionState.authenticated);

    // Initialize data socket for streaming
    await _initializeDataSocket();
  }

  /// Initialize UDP data socket for streaming
  Future<void> _initializeDataSocket() async {
    _dataSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );

    _dataSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _dataSocket!.receive();
        if (datagram != null) {
          _handleStreamData(datagram.data);
        }
      }
    });

    _setState(SessionState.streaming);
  }

  /// Handle incoming stream data
  void _handleStreamData(Uint8List data) async {
    try {
      // Decrypt and process AV packets
      final decrypted = await _crypto.decrypt(data);
      _processAVPacket(decrypted);
    } catch (e) {
      // Ignore decryption errors for now
    }
  }

  /// Process audio/video packet
  void _processAVPacket(Uint8List data) {
    if (data.length < 4) return;

    // Parse Takion AV header
    final isVideo = (data[0] & 0x80) != 0;
    final packetIndex = (data[1] << 8) | data[2];
    final frameIndex = (data[3] << 8) | data[4];

    // Emit frame event
    _emitEvent(
      isVideo ? SessionEventType.videoFrame : SessionEventType.audioFrame,
      data: {
        'packetIndex': packetIndex,
        'frameIndex': frameIndex,
        'payload': data.sublist(isVideo ? PSConstants.takionV9AvHeaderSizeVideo : PSConstants.takionV12AvHeaderSizeAudio),
      },
    );
  }

  /// Process control message
  void _processControlMessage(Uint8List data) {
    // Handle control messages like feedback
    _emitEvent(SessionEventType.controllerFeedback, data: data);
  }

  /// Derive handshake key from RP key
  Uint8List _deriveHandshakeKey(String rpKey) {
    final keyBytes = utf8.encode(rpKey);
    final result = Uint8List(PSConstants.handshakeKeySize);
    for (var i = 0; i < PSConstants.handshakeKeySize && i < keyBytes.length; i++) {
      result[i] = keyBytes[i];
    }
    return result;
  }

  void _setState(SessionState newState) {
    _state = newState;
    _emitEvent(SessionEventType.stateChanged, data: newState);
  }

  void _emitEvent(SessionEventType type, {dynamic data, String? message}) {
    _eventController.add(SessionEvent(type: type, data: data, message: message));
  }

  void _handleError(dynamic error) {
    _setState(SessionState.error);
    _emitEvent(SessionEventType.error, message: error.toString());
  }

  void _handleDisconnect() {
    if (_state != SessionState.disconnecting) {
      _setState(SessionState.disconnected);
    }
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
