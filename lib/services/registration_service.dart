import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

import '../core/constants.dart';
import '../models/ps_device.dart';

enum RegistrationState {
  idle,
  connecting,
  waitingForPin,
  registering,
  success,
  failed,
}

class RegistrationService {
  final Logger _logger = Logger();
  final Random _random = Random.secure();

  RegistrationState _state = RegistrationState.idle;
  RegistrationState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

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
      _validatePin(pin);
      final normalizedAccountId = _normalizeAccountId(accountId);
      final profile = _HostTypeData.forDevice(device);

      final registerReady = await _sendRegistrationInit(
        device.ipAddress,
        profile,
      );
      if (!registerReady) {
        throw RegistrationException(
          'The console is not accepting registrations. Open "Add Device" on the PlayStation first.',
        );
      }

      _state = RegistrationState.registering;

      final attempt = _buildRegistrationAttempt(
        profile: profile,
        pin: pin,
        accountId: normalizedAccountId,
      );
      final response = await _sendRegistrationRequest(
        host: device.ipAddress,
        payload: attempt.payload,
      );
      final fields = _parseRegistrationResponse(
        cipher: attempt.cipher,
        response: response,
      );

      final registKey = _pickField(fields, profile.hostType, 'RegistKey');
      final rpKey = _pickField(fields, profile.hostType, 'RP-Key');

      if (registKey == null || rpKey == null) {
        throw RegistrationException(
          'Registration succeeded but the response did not include RegistKey / RP-Key.',
        );
      }

      _state = RegistrationState.success;
      _logger.i('Registration successful for ${device.hostName}');

      return device.copyWith(
        registKey: registKey,
        rpKey: rpKey,
        lastConnected: DateTime.now(),
      );
    } on SocketException catch (e) {
      _lastError = 'Unable to reach the console: ${e.message}';
      _logger.e(_lastError!, error: e);
      _state = RegistrationState.failed;
      return null;
    } on RegistrationException catch (e) {
      _lastError = e.message;
      _logger.e(_lastError!, error: e);
      _state = RegistrationState.failed;
      return null;
    } catch (e) {
      _lastError = 'Unexpected registration failure: $e';
      _logger.e(_lastError!, error: e);
      _state = RegistrationState.failed;
      return null;
    } finally {
      if (_state != RegistrationState.success) {
        _state = RegistrationState.idle;
      }
    }
  }

  void reset() {
    _state = RegistrationState.idle;
    _lastError = null;
  }

  @visibleForTesting
  Uint8List generateKey0(PSDeviceType deviceType, String pin) {
    final profile = _HostTypeData.forDeviceType(deviceType);
    return _generateKey0(profile, pin);
  }

  @visibleForTesting
  Uint8List generateKey1(PSDeviceType deviceType, Uint8List nonce) {
    final profile = _HostTypeData.forDeviceType(deviceType);
    return _generateKey1(profile, nonce);
  }

  @visibleForTesting
  Map<String, String> parseRegistrationFields(
    PSDeviceType deviceType,
    Uint8List nonce,
    String pin,
    Uint8List response,
  ) {
    final profile = _HostTypeData.forDeviceType(deviceType);
    final key0 = _generateKey0(profile, pin);
    final cipher = _RegistrationSessionCipher(
      key: key0,
      nonce: nonce,
      hmacKey: profile.hmacKey,
    );
    return _parseRegistrationResponse(cipher: cipher, response: response);
  }

  void _validatePin(String pin) {
    if (pin.length != 8 || !RegExp(r'^\d{8}$').hasMatch(pin)) {
      throw RegistrationException('PIN must be exactly 8 digits.');
    }
  }

  String _normalizeAccountId(String accountId) {
    final trimmed = accountId.trim();
    if (trimmed.isEmpty) {
      throw RegistrationException('PSN Account ID is required.');
    }

    try {
      base64Decode(base64.normalize(trimmed));
    } on FormatException {
      throw RegistrationException(
        'PSN Account ID must be a valid Base64-encoded Account ID, not the online ID.',
      );
    }

    return trimmed;
  }

  Future<bool> _sendRegistrationInit(
    String host,
    _HostTypeData profile,
  ) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.writeEventsEnabled = false;

    final completer = Completer<bool>();
    StreamSubscription<RawSocketEvent>? subscription;
    Timer? timer;

    subscription = socket.listen((event) {
      if (event != RawSocketEvent.read || completer.isCompleted) {
        return;
      }

      final datagram = socket.receive();
      final data = datagram?.data;
      final success =
          data != null &&
          data.length >= profile.registerStart.length &&
          _startsWith(data, profile.registerStart);
      completer.complete(success);
    });

    timer = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    socket.send(
      profile.registerInit,
      InternetAddress(host),
      PSConstants.registrationPort,
    );

    final result = await completer.future;
    timer.cancel();
    await subscription.cancel();
    socket.close();
    return result;
  }

  _RegistrationAttempt _buildRegistrationAttempt({
    required _HostTypeData profile,
    required String pin,
    required String accountId,
  }) {
    final nonce = Uint8List.fromList(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final key0 = _generateKey0(profile, pin);
    final key1 = _generateKey1(profile, nonce);
    final cipher = _RegistrationSessionCipher(
      key: key0,
      nonce: nonce,
      hmacKey: profile.hmacKey,
    );

    final payload = _buildRegistPayload(key1);
    final encryptedBody = cipher.encrypt(
      Uint8List.fromList(
        utf8.encode(
          'Client-Type: ${_HostTypeData.clientType}\r\n'
          'Np-AccountId: $accountId\r\n',
        ),
      ),
    );
    final combinedPayload = Uint8List.fromList([
      ...payload,
      ...encryptedBody,
    ]);

    final headers = utf8.encode(
      'POST ${profile.registPath} HTTP/1.1\r\n'
      ' HTTP/1.1\r\n'
      'HOST: 10.0.2.15\r\n'
      'User-Agent: ${PSConstants.remotePlayUserAgent}\r\n'
      'Connection: close\r\n'
      'Content-Length: ${combinedPayload.length}\r\n'
      'RP-Version: ${profile.remotePlayVersion}\r\n'
      '\r\n',
    );

    return _RegistrationAttempt(
      nonce: nonce,
      cipher: cipher,
      payload: Uint8List.fromList([
        ...headers,
        ...combinedPayload,
      ]),
    );
  }

  Uint8List _generateKey0(_HostTypeData profile, String pin) {
    final key = Uint8List.fromList(profile.key0Seed);
    final pinValue = int.parse(pin);
    for (var index = 12; index < 16; index++) {
      final shift = 24 - ((index - 12) * 8);
      key[index] ^= (pinValue >> shift) & 0xFF;
    }
    return key;
  }

  Uint8List _generateKey1(_HostTypeData profile, Uint8List nonce) {
    final key = Uint8List(16);
    for (var index = 0; index < 16; index++) {
      key[index] =
          ((nonce[index] ^ profile.key1Shift[index]) +
                  profile.key1Offset +
                  index) &
              0xFF;
    }
    return key;
  }

  Uint8List _buildRegistPayload(Uint8List key1) {
    final payload = Uint8List.fromList(List<int>.filled(480, 0x41));
    payload.setRange(199, 207, key1.sublist(8, 16));
    payload.setRange(401, 409, key1.sublist(0, 8));
    return payload;
  }

  Future<Uint8List> _sendRegistrationRequest({
    required String host,
    required Uint8List payload,
  }) async {
    final socket = await Socket.connect(
      host,
      PSConstants.registrationPort,
      timeout: const Duration(seconds: 5),
    );
    socket.setOption(SocketOption.tcpNoDelay, true);

    try {
      socket.add(payload);
      await socket.flush();
      return await _readBinaryResponse(socket);
    } finally {
      await socket.close();
    }
  }

  Future<Uint8List> _readBinaryResponse(Socket socket) async {
    final completer = Completer<Uint8List>();
    final buffer = BytesBuilder(copy: false);

    late final StreamSubscription<Uint8List> subscription;
    late final Timer timer;

    subscription = socket.listen(
      buffer.add,
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(buffer.takeBytes());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      cancelOnError: true,
    );

    timer = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.completeError(
          RegistrationException('Timed out waiting for the registration response.'),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  Map<String, String> _parseRegistrationResponse({
    required _RegistrationSessionCipher cipher,
    required Uint8List response,
  }) {
    final separatorIndex = _indexOfBytes(response, const [13, 10, 13, 10]);
    if (separatorIndex < 0) {
      throw RegistrationException('Invalid registration response from console.');
    }

    final headerBytes = response.sublist(0, separatorIndex);
    final bodyBytes = response.sublist(separatorIndex + 4);
    final headerText = ascii.decode(headerBytes, allowInvalid: true);
    final statusLine = headerText.split(RegExp(r'\r?\n')).first;

    if (!statusLine.contains('200')) {
      throw RegistrationException('Console rejected registration: $statusLine');
    }

    final decrypted = utf8.decode(cipher.decrypt(bodyBytes), allowMalformed: true);
    final fields = <String, String>{};

    for (final line in decrypted.split('\r\n')) {
      if (line.trim().isEmpty) {
        continue;
      }

      final colonIndex = line.indexOf(': ');
      if (colonIndex <= 0) {
        continue;
      }

      final key = line.substring(0, colonIndex).trim();
      final value = line.substring(colonIndex + 2).trim();
      fields[key] = value;
    }

    return fields;
  }

  String? _pickField(Map<String, String> fields, String hostType, String name) {
    final candidates = <String>[
      '$hostType-$name',
      name,
    ];

    for (final candidate in candidates) {
      final lowered = candidate.toLowerCase();
      for (final entry in fields.entries) {
        if (entry.key.toLowerCase() == lowered) {
          return entry.value;
        }
      }
    }
    return null;
  }

  bool _startsWith(Uint8List value, Uint8List prefix) {
    if (value.length < prefix.length) {
      return false;
    }

    for (var index = 0; index < prefix.length; index++) {
      if (value[index] != prefix[index]) {
        return false;
      }
    }
    return true;
  }

  int _indexOfBytes(Uint8List data, List<int> pattern) {
    for (var index = 0; index <= data.length - pattern.length; index++) {
      var matches = true;
      for (var patternIndex = 0; patternIndex < pattern.length; patternIndex++) {
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

class RegistrationException implements Exception {
  const RegistrationException(this.message);

  final String message;

  @override
  String toString() => 'RegistrationException: $message';
}

class _RegistrationAttempt {
  const _RegistrationAttempt({
    required this.nonce,
    required this.cipher,
    required this.payload,
  });

  final Uint8List nonce;
  final _RegistrationSessionCipher cipher;
  final Uint8List payload;
}

class _HostTypeData {
  _HostTypeData({
    required this.hostType,
    required this.registPath,
    required this.remotePlayVersion,
    required this.registerInit,
    required this.registerStart,
    required this.key0Seed,
    required this.key1Shift,
    required this.hmacKey,
    required this.key1Offset,
  });

  static const clientType =
      'dabfa2ec873de5839bee8d3f4c0239c4282c07c25c6077a2931afcf0adc0d34f';

  static final _ps4 = _HostTypeData(
    hostType: 'PS4',
    registPath: '/sie/ps4/rp/sess/rgst',
    remotePlayVersion: PSConstants.remotePlayVersionPS4,
    registerInit: Uint8List.fromList([0x53, 0x52, 0x43, 0x32]),
    registerStart: Uint8List.fromList([0x52, 0x45, 0x53, 0x32]),
    key0Seed: Uint8List.fromList([
      206,
      188,
      182,
      64,
      8,
      7,
      118,
      4,
      123,
      133,
      232,
      91,
      243,
      236,
      148,
      99,
    ]),
    key1Shift: Uint8List.fromList([
      95,
      235,
      254,
      248,
      145,
      176,
      66,
      70,
      166,
      37,
      168,
      122,
      107,
      204,
      73,
      88,
    ]),
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
    key1Offset: 41,
  );

  static final _ps5 = _HostTypeData(
    hostType: 'PS5',
    registPath: '/sie/ps5/rp/sess/rgst',
    remotePlayVersion: PSConstants.remotePlayVersionPS5,
    registerInit: Uint8List.fromList([0x53, 0x52, 0x43, 0x33]),
    registerStart: Uint8List.fromList([0x52, 0x45, 0x53, 0x33]),
    key0Seed: Uint8List.fromList([
      216,
      96,
      225,
      70,
      189,
      176,
      189,
      148,
      180,
      96,
      7,
      11,
      177,
      79,
      231,
      35,
    ]),
    key1Shift: Uint8List.fromList([
      168,
      55,
      97,
      181,
      39,
      252,
      7,
      110,
      98,
      67,
      58,
      167,
      1,
      149,
      138,
      133,
    ]),
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
    key1Offset: -45,
  );

  final String hostType;
  final String registPath;
  final String remotePlayVersion;
  final Uint8List registerInit;
  final Uint8List registerStart;
  final Uint8List key0Seed;
  final Uint8List key1Shift;
  final Uint8List hmacKey;
  final int key1Offset;

  static _HostTypeData forDevice(PSDevice device) {
    return forDeviceType(device.deviceType);
  }

  static _HostTypeData forDeviceType(PSDeviceType deviceType) {
    return deviceType == PSDeviceType.ps5 ? _ps5 : _ps4;
  }
}

class _RegistrationSessionCipher {
  _RegistrationSessionCipher({
    required this.key,
    required this.nonce,
    required this.hmacKey,
  });

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

    final hmac = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(hmacKey));
    final digest = hmac.process(
      Uint8List.fromList([...nonce, ...suffix]),
    );
    return Uint8List.fromList(digest.sublist(0, 16));
  }
}
