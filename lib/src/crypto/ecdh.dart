import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' as pc;
import '../protocol/constants.dart';

/// ECDH Key Exchange implementation for PS Remote Play
class ECDHKeyExchange {
  late pc.AsymmetricKeyPair<pc.ECPublicKey, pc.ECPrivateKey> _keyPair;
  late pc.ECDomainParameters _domainParams;
  Uint8List? _sharedSecret;

  ECDHKeyExchange() {
    _domainParams = pc.ECDomainParameters('secp256k1');
    _generateKeyPair();
  }

  void _generateKeyPair() {
    final keyGen = pc.ECKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.ECKeyGeneratorParameters(_domainParams),
        pc.SecureRandom('Fortuna')..seed(pc.KeyParameter(_generateSeed())),
      ));

    _keyPair = keyGen.generateKeyPair() as pc.AsymmetricKeyPair<pc.ECPublicKey, pc.ECPrivateKey>;
  }

  Uint8List _generateSeed() {
    final seed = Uint8List(32);
    final random = pc.SecureRandom('Fortuna');
    for (var i = 0; i < seed.length; i++) {
      seed[i] = random.nextUint8();
    }
    return seed;
  }

  /// Get the local public key bytes
  Uint8List getLocalPublicKey() {
    final point = _keyPair.publicKey.Q!;
    final x = _bigIntToBytes(point.x!.toBigInteger()!, 32);
    final y = _bigIntToBytes(point.y!.toBigInteger()!, 32);

    // Uncompressed format: 0x04 || x || y
    final result = Uint8List(65);
    result[0] = 0x04;
    result.setRange(1, 33, x);
    result.setRange(33, 65, y);
    return result;
  }

  /// Derive shared secret from remote public key
  Future<Uint8List> deriveSecret(Uint8List remotePublicKey) async {
    // Parse remote public key (assuming uncompressed format)
    if (remotePublicKey.length != 65 || remotePublicKey[0] != 0x04) {
      throw ArgumentError('Invalid public key format');
    }

    final x = _bytesToBigInt(remotePublicKey.sublist(1, 33));
    final y = _bytesToBigInt(remotePublicKey.sublist(33, 65));

    final remotePoint = _domainParams.curve.createPoint(x, y);
    final sharedPoint = (remotePoint * _keyPair.privateKey.d)!;

    _sharedSecret = _bigIntToBytes(sharedPoint.x!.toBigInteger()!, PSConstants.ecdhSecretSize);
    return _sharedSecret!;
  }

  /// Generate signature using handshake key
  Future<Uint8List> generateSignature(Uint8List handshakeKey) async {
    final publicKey = getLocalPublicKey();
    final mac = Hmac.sha256();
    final result = await mac.calculateMac(
      publicKey,
      secretKey: SecretKey(handshakeKey),
    );
    return Uint8List.fromList(result.bytes);
  }

  /// Verify remote signature
  Future<bool> verifySignature(
    Uint8List remotePublicKey,
    Uint8List handshakeKey,
    Uint8List remoteSignature,
  ) async {
    final mac = Hmac.sha256();
    final expected = await mac.calculateMac(
      remotePublicKey,
      secretKey: SecretKey(handshakeKey),
    );
    return _constantTimeCompare(Uint8List.fromList(expected.bytes), remoteSignature);
  }

  Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var remaining = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (remaining & BigInt.from(0xFF)).toInt();
      remaining = remaining >> 8;
    }
    return result;
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  bool _constantTimeCompare(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
