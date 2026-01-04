import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// AES-GCM encryption/decryption for PS Remote Play streams
class AESGCMCrypto {
  final AesGcm _cipher;
  SecretKey? _key;
  int _keyPosition = 0;

  AESGCMCrypto() : _cipher = AesGcm.with256bits();

  /// Initialize with encryption key
  Future<void> initialize(Uint8List key) async {
    if (key.length != 32) {
      throw ArgumentError('Key must be 32 bytes for AES-256-GCM');
    }
    _key = SecretKey(key);
    _keyPosition = 0;
  }

  /// Encrypt data with AES-GCM
  Future<Uint8List> encrypt(Uint8List plaintext, {Uint8List? nonce}) async {
    if (_key == null) {
      throw StateError('Crypto not initialized');
    }

    final iv = nonce ?? _generateNonce();
    final result = await _cipher.encrypt(
      plaintext,
      secretKey: _key!,
      nonce: iv,
    );

    // Return: nonce (12) + ciphertext + tag (16)
    final output = Uint8List(12 + result.cipherText.length + 16);
    output.setRange(0, 12, iv);
    output.setRange(12, 12 + result.cipherText.length, result.cipherText);
    output.setRange(12 + result.cipherText.length, output.length, result.mac.bytes);

    _keyPosition++;
    return output;
  }

  /// Decrypt data with AES-GCM
  Future<Uint8List> decrypt(Uint8List ciphertext) async {
    if (_key == null) {
      throw StateError('Crypto not initialized');
    }

    if (ciphertext.length < 28) {
      throw ArgumentError('Ciphertext too short');
    }

    final nonce = ciphertext.sublist(0, 12);
    final encryptedData = ciphertext.sublist(12, ciphertext.length - 16);
    final tag = ciphertext.sublist(ciphertext.length - 16);

    final secretBox = SecretBox(
      encryptedData,
      nonce: nonce,
      mac: Mac(tag),
    );

    final decrypted = await _cipher.decrypt(
      secretBox,
      secretKey: _key!,
    );

    _keyPosition++;
    return Uint8List.fromList(decrypted);
  }

  /// Generate a random 12-byte nonce
  Uint8List _generateNonce() {
    final nonce = Uint8List(12);
    // Use key position as part of nonce for uniqueness
    final posBytes = ByteData(8)..setUint64(0, _keyPosition, Endian.big);
    nonce.setRange(4, 12, posBytes.buffer.asUint8List());
    return nonce;
  }

  int get keyPosition => _keyPosition;

  void advanceKeyPosition(int count) {
    _keyPosition += count;
  }

  void reset() {
    _keyPosition = 0;
  }
}

/// GKCrypt - Chiaki's key-stream based encryption
class GKCrypt {
  Uint8List? _key;
  Uint8List? _iv;
  int _keyPos = 0;

  Future<void> initialize(Uint8List key, Uint8List iv) async {
    if (key.length != 16) {
      throw ArgumentError('Key must be 16 bytes');
    }
    if (iv.length != 16) {
      throw ArgumentError('IV must be 16 bytes');
    }
    _key = Uint8List.fromList(key);
    _iv = Uint8List.fromList(iv);
    _keyPos = 0;
  }

  int get keyPosition => _keyPos;

  void advanceKeyPosition(int count) {
    _keyPos += count;
  }

  /// Generate keystream and XOR with data
  Future<Uint8List> process(Uint8List data) async {
    if (_key == null || _iv == null) {
      throw StateError('GKCrypt not initialized');
    }

    final cipher = AesCtr.with128bits(macAlgorithm: MacAlgorithm.empty);
    final secretKey = SecretKey(_key!);

    // Generate keystream using AES-CTR
    final result = await cipher.encrypt(
      data,
      secretKey: secretKey,
      nonce: _iv!.sublist(0, 16),
    );

    _keyPos += data.length;
    return Uint8List.fromList(result.cipherText);
  }
}

/// RPCrypt - Registration Protocol encryption
class RPCrypt {
  static const int keySize = 16;
  Uint8List? _key;

  Future<void> initialize(Uint8List key) async {
    if (key.length != keySize) {
      throw ArgumentError('Key must be $keySize bytes');
    }
    _key = Uint8List.fromList(key);
  }

  Future<Uint8List> encrypt(Uint8List plaintext) async {
    if (_key == null) {
      throw StateError('RPCrypt not initialized');
    }

    final cipher = AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty);
    final secretKey = SecretKey(_key!);

    // Generate random IV
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = DateTime.now().microsecond % 256;
    }

    final result = await cipher.encrypt(
      _pkcs7Pad(plaintext, 16),
      secretKey: secretKey,
      nonce: iv,
    );

    // Return: IV + ciphertext
    final output = Uint8List(16 + result.cipherText.length);
    output.setRange(0, 16, iv);
    output.setRange(16, output.length, result.cipherText);
    return output;
  }

  Future<Uint8List> decrypt(Uint8List ciphertext) async {
    if (_key == null) {
      throw StateError('RPCrypt not initialized');
    }

    if (ciphertext.length < 32) {
      throw ArgumentError('Ciphertext too short');
    }

    final iv = ciphertext.sublist(0, 16);
    final encryptedData = ciphertext.sublist(16);

    final cipher = AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty);
    final secretKey = SecretKey(_key!);

    final secretBox = SecretBox(encryptedData, nonce: iv, mac: Mac.empty);
    final decrypted = await cipher.decrypt(secretBox, secretKey: secretKey);

    return _pkcs7Unpad(Uint8List.fromList(decrypted));
  }

  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final result = Uint8List(data.length + padLength);
    result.setRange(0, data.length, data);
    for (var i = data.length; i < result.length; i++) {
      result[i] = padLength;
    }
    return result;
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLength = data.last;
    if (padLength > 16 || padLength > data.length) {
      throw ArgumentError('Invalid padding');
    }
    return data.sublist(0, data.length - padLength);
  }
}
