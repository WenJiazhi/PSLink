import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class RpStreamEcdh {
  RpStreamEcdh({
    required Uint8List handshakeKey,
    Uint8List? privateKey,
  }) : handshakeKey = Uint8List.fromList(handshakeKey) {
    final scalarBytes = privateKey == null
        ? _randomPrivateKey()
        : Uint8List.fromList(privateKey);
    if (scalarBytes.length != 32) {
      throw ArgumentError.value(
        privateKey,
        'privateKey',
        'Expected 32 bytes for secp256k1 private key.',
      );
    }

    _privateScalar = _bigIntFromBytes(scalarBytes);
    if (_privateScalar <= BigInt.zero || _privateScalar >= _domain.n) {
      throw ArgumentError.value(
        privateKey,
        'privateKey',
        'Invalid secp256k1 private key.',
      );
    }

    final publicPoint = (_domain.G * _privateScalar)!;
    publicKey = _encodePoint(publicPoint);
    publicSignature = _hmacSha256(this.handshakeKey, publicKey);
  }

  static final ECDomainParameters _domain = ECDomainParameters('secp256k1');
  static final Random _random = Random.secure();

  final Uint8List handshakeKey;
  late final BigInt _privateScalar;
  late final Uint8List publicKey;
  late final Uint8List publicSignature;
  Uint8List? _sharedSecret;

  bool setRemote(Uint8List remotePublicKey, Uint8List remoteSignature) {
    final expectedSignature = _hmacSha256(handshakeKey, remotePublicKey);
    if (!_bytesEqual(expectedSignature, remoteSignature)) {
      return false;
    }

    final remotePoint = _domain.curve.decodePoint(remotePublicKey);
    if (remotePoint == null || remotePoint.isInfinity) {
      return false;
    }

    final sharedPoint = remotePoint * _privateScalar;
    if (sharedPoint == null || sharedPoint.isInfinity) {
      return false;
    }

    _sharedSecret = _bigIntToBytes(sharedPoint.x!.toBigInteger()!, 32);
    return true;
  }

  RpStreamCipher createCipher() {
    final sharedSecret = _sharedSecret;
    if (sharedSecret == null) {
      throw StateError('Remote ECDH secret has not been established yet.');
    }

    return RpStreamCipher(
      handshakeKey: handshakeKey,
      secret: sharedSecret,
    );
  }

  static Uint8List _randomPrivateKey() {
    while (true) {
      final bytes = Uint8List.fromList(
        List<int>.generate(32, (_) => _random.nextInt(256)),
      );
      final value = _bigIntFromBytes(bytes);
      if (value > BigInt.zero && value < _domain.n) {
        return bytes;
      }
    }
  }
}

class RpStreamCipher {
  RpStreamCipher({
    required Uint8List handshakeKey,
    required Uint8List secret,
  }) : _local = _LocalStreamCipher(handshakeKey, secret),
       _remote = _RemoteStreamCipher(handshakeKey, secret);

  final _LocalStreamCipher _local;
  final _RemoteStreamCipher _remote;

  Uint8List encrypt(Uint8List data) => _local.encrypt(data);

  Uint8List decrypt(Uint8List data, int keyPos) => _remote.decrypt(data, keyPos);

  Uint8List getGmac(Uint8List data) => _local.getGmac(data);

  bool verifyGmac(Uint8List data, int keyPos, Uint8List gmac) {
    return _remote.verifyGmac(data, keyPos, gmac);
  }

  int get keyPos => _local.keyPos;

  void advanceKeyPos(int advanceBy) {
    _local.advanceKeyPos(advanceBy);
  }
}

class _LocalStreamCipher extends _BaseStreamCipher {
  _LocalStreamCipher(super.handshakeKey, super.secret)
    : super(baseIndex: 2);

  int _keyPos = 0;

  Uint8List encrypt(Uint8List data) => crypt(data, _keyPos);

  Uint8List getGmac(Uint8List data) => calculateGmac(data, _keyPos);

  int get keyPos => _keyPos;

  void advanceKeyPos(int advanceBy) {
    _keyPos += advanceBy;
  }
}

class _RemoteStreamCipher extends _BaseStreamCipher {
  _RemoteStreamCipher(super.handshakeKey, super.secret)
    : super(baseIndex: 3);

  Uint8List decrypt(Uint8List data, int keyPos) => crypt(data, keyPos);

  bool verifyGmac(Uint8List data, int keyPos, Uint8List gmac) {
    return _bytesEqual(calculateGmac(data, keyPos), gmac);
  }
}

abstract class _BaseStreamCipher {
  _BaseStreamCipher(
    Uint8List handshakeKey,
    Uint8List secret, {
    required int baseIndex,
  }) {
    final keyAndIv = _getBaseKeyIv(secret, handshakeKey, baseIndex);
    _baseKey = keyAndIv.$1;
    _baseIv = keyAndIv.$2;
    _baseGmacKey = _getGmacKey(0, _baseKey, _baseIv);
  }

  late final Uint8List _baseKey;
  late final Uint8List _baseIv;
  late final Uint8List _baseGmacKey;

  Uint8List crypt(Uint8List data, int keyPos) {
    if (data.isEmpty) {
      return Uint8List(0);
    }

    final padding = keyPos % 16;
    final alignedKeyPos = keyPos - padding;
    final neededLength = padding + data.length;
    final blockCount = (neededLength + 15) ~/ 16;
    final keystream = Uint8List(blockCount * 16);
    final aes = AESEngine()..init(true, KeyParameter(_baseKey));

    for (var blockIndex = 0; blockIndex < blockCount; blockIndex++) {
      final counter = (alignedKeyPos ~/ 16) + blockIndex + 1;
      final block = _counterAdd(_baseIv, counter);
      aes.processBlock(block, 0, keystream, blockIndex * 16);
    }

    final sliced = keystream.sublist(padding, padding + data.length);
    final output = Uint8List(data.length);
    for (var index = 0; index < data.length; index++) {
      output[index] = data[index] ^ sliced[index];
    }
    return output;
  }

  Uint8List calculateGmac(Uint8List data, int keyPos) {
    final gmacIndex = keyPos > 0 ? (keyPos - 1) ~/ _gmacRefreshKeyPos : 0;
    final gmacKey = gmacIndex == 0
        ? _baseGmacKey
        : _getGmacKey(gmacIndex, _baseGmacKey, _baseIv);
    final iv = _counterAdd(_baseIv, keyPos ~/ 16);
    return _getGmacTag(data, gmacKey, iv);
  }
}

const int _gmacRefreshIv = 44910;
const int _gmacRefreshKeyPos = 45000;

(Uint8List, Uint8List) _getBaseKeyIv(
  Uint8List secret,
  Uint8List handshakeKey,
  int index,
) {
  final input = Uint8List.fromList([
    0x01,
    index,
    0x00,
    ...handshakeKey,
    0x01,
    0x00,
  ]);
  final digest = _hmacSha256(secret, input);
  return (
    Uint8List.fromList(digest.sublist(0, 16)),
    Uint8List.fromList(digest.sublist(16, 32)),
  );
}

Uint8List _getGmacKey(int gmacIndex, Uint8List key, Uint8List initVector) {
  final offsetIv = _counterAdd(initVector, gmacIndex * _gmacRefreshIv);
  final digest = SHA256Digest().process(
    Uint8List.fromList([...key, ...offsetIv]),
  );
  final output = Uint8List(16);
  for (var index = 0; index < 16; index++) {
    output[index] = digest[index] ^ digest[index + 16];
  }
  return output;
}

Uint8List _getGmacTag(Uint8List data, Uint8List key, Uint8List iv) {
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    true,
    AEADParameters(KeyParameter(key), 128, iv, data),
  );
  final output = Uint8List(cipher.getOutputSize(0));
  var offset = 0;
  offset += cipher.processBytes(Uint8List(0), 0, 0, output, offset);
  offset += cipher.doFinal(output, offset);
  return Uint8List.fromList(output.sublist(0, 4));
}

Uint8List _counterAdd(Uint8List initVector, int counter) {
  final bytes = Uint8List.fromList(initVector);
  var carry = counter;
  for (var index = 0; index < bytes.length; index++) {
    final sum = bytes[index] + carry;
    bytes[index] = sum & 0xFF;
    carry = sum >> 8;
    if (carry <= 0) {
      break;
    }
  }
  return bytes;
}

Uint8List _hmacSha256(Uint8List key, Uint8List input) {
  final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
  return hmac.process(input);
}

Uint8List _encodePoint(ECPoint point) {
  return Uint8List.fromList(point.getEncoded(false));
}

BigInt _bigIntFromBytes(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final output = Uint8List(length);
  var current = value;
  for (var index = length - 1; index >= 0; index--) {
    output[index] = (current & BigInt.from(0xFF)).toInt();
    current = current >> 8;
  }
  return output;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }

  var diff = 0;
  for (var index = 0; index < a.length; index++) {
    diff |= a[index] ^ b[index];
  }
  return diff == 0;
}
