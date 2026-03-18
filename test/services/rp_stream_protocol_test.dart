import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/models/ps_device.dart';
import 'package:pslink/services/rp_stream_crypto.dart';
import 'package:pslink/services/rp_stream_packets.dart';

void main() {
  group('RP stream protocol', () {
    test('matches upstream secp256k1 handshake material', () {
      final handshakeKey = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final local = RpStreamEcdh(
        handshakeKey: handshakeKey,
        privateKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final remote = RpStreamEcdh(
        handshakeKey: handshakeKey,
        privateKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 33)),
      );

      expect(
        _toHex(local.publicKey),
        '0484bf7562262bbd6940085748f3be6afa52ae317155181ece31b66351ccffa4b08cc43d63b2859d469fee15f31c9edb5324266e6fd0407e87382d60fc4511acd8',
      );
      expect(
        _toHex(local.publicSignature),
        'efdf475e0635be70fde216ca1fefe751f7ddd6b7e21450adc3fa796700069d4b',
      );
      expect(
        _toHex(remote.publicKey),
        '04207bba70bc66309baa582a6ac120fd52d68026c51f6326f8ccedcbd2c1b7eb828c18ff7dbee879a4335a05294dea1e99e251f4b3e3b020b507f87064993fb202',
      );
      expect(
        _toHex(remote.publicSignature),
        'b80a090f345415fcc181bf2eaa0a22f7dbb5e105f0a03f9238475f0ffb595d3b',
      );
      expect(local.setRemote(remote.publicKey, remote.publicSignature), isTrue);
    });

    test('matches upstream control and feedback packet bytes', () {
      final handshakeKey = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final local = RpStreamEcdh(
        handshakeKey: handshakeKey,
        privateKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final remote = RpStreamEcdh(
        handshakeKey: handshakeKey,
        privateKey: Uint8List.fromList(List<int>.generate(32, (i) => i + 33)),
      );
      expect(local.setRemote(remote.publicKey, remote.publicSignature), isTrue);
      final cipher = local.createCipher();

      expect(
        _toHex(
          RpControlPacket.init(tag: 1, tsn: 1).toBytes(),
        ),
        '000000000000000000000000000100001400000001000190000064006400000001',
      );

      expect(
        _toHex(
          RpControlPacket.data(
            tagRemote: 2,
            tsn: 3,
            flag: 1,
            channel: 9,
            data: Uint8List.fromList('abc'.codeUnits),
          ).toBytes(),
        ),
        '0000000002000000000000000000010010000000030009000000616263',
      );

      expect(
        _toHex(
          RpControlPacket.data(
            tagRemote: 2,
            tsn: 3,
            flag: 1,
            channel: 9,
            data: Uint8List.fromList('abc'.codeUnits),
          ).toBytes(
            cipher: cipher,
            encryptPayload: false,
            advanceBy: 12,
          ),
        ),
        '000000000268911f400000000000010010000000030009000000616263',
      );

      expect(
        _toHex(
          RpControlPacket.data(
            tagRemote: 2,
            tsn: 4,
            flag: 1,
            channel: 1,
            data: Uint8List.fromList('xyz'.codeUnits),
          ).toBytes(
            cipher: cipher,
            encryptPayload: true,
            advanceBy: 3,
          ),
        ),
        '0000000002f5cad3ed0000000c00010010e5c07f180c8122ada9f391a1',
      );

      expect(
        _toHex(
          buildFeedbackStatePacket(
            sequence: 5,
            deviceType: PSDeviceType.ps5,
            leftX: 1000,
            leftY: -1000,
            rightX: -500,
            rightY: 500,
            cipher: cipher,
          ),
        ),
        '060005000000000fad763092bcf3ffddd256f417a490881a0c879fccd98e10e15692a979f80c0c05',
      );

      expect(
        _toHex(
          buildFeedbackEventPacket(
            sequence: 6,
            button: RpFeedbackButton.cross,
            active: true,
            cipher: cipher,
          ),
        ),
        '010006000000002bf6927a9e8e09ff',
      );
    });
  });
}

String _toHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
