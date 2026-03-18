import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pslink/services/takion_codec.dart';

void main() {
  group('TakionCodec', () {
    test('encodes and decodes BIG payloads', () {
      final payload = TakionBigPayload(
        clientVersion: 12,
        sessionKey: 'session-key',
        launchSpec: '{"videoCodec":"avc"}',
        encryptedKey: Uint8List.fromList([1, 2, 3, 4]),
        ecdhPublicKey: Uint8List.fromList([5, 6, 7]),
        ecdhSignature: Uint8List.fromList([8, 9]),
      );

      final encoded = TakionCodec.encodeBig(payload);
      final decoded = TakionCodec.decode(encoded);

      expect(decoded?.type, TakionMessageType.big);
      expect(decoded?.bigPayload?.clientVersion, 12);
      expect(decoded?.bigPayload?.sessionKey, 'session-key');
      expect(decoded?.bigPayload?.launchSpec, '{"videoCodec":"avc"}');
      expect(decoded?.bigPayload?.encryptedKey, [1, 2, 3, 4]);
      expect(decoded?.bigPayload?.ecdhPublicKey, [5, 6, 7]);
      expect(decoded?.bigPayload?.ecdhSignature, [8, 9]);
    });

    test('decodes BANG payloads from wire bytes', () {
      final bangPayload = _message([
        _varintField(1, 1),
        _messageField(
          3,
          _message([
            _varintField(1, 12),
            _varintField(2, 99),
            _varintField(3, 1),
            _varintField(4, 1),
            _stringField(5, 'session'),
            _stringField(7, '12.0'),
            _bytesField(8, [1, 2, 3]),
            _bytesField(9, [4, 5]),
          ]),
        ),
      ]);

      final decoded = TakionCodec.decode(Uint8List.fromList(bangPayload));

      expect(decoded?.type, TakionMessageType.bang);
      expect(decoded?.bangPayload?.serverVersion, 12);
      expect(decoded?.bangPayload?.token, 99);
      expect(decoded?.bangPayload?.encryptedKeyAccepted, isTrue);
      expect(decoded?.bangPayload?.versionAccepted, isTrue);
      expect(decoded?.bangPayload?.sessionKey, 'session');
      expect(decoded?.bangPayload?.serverVersionString, '12.0');
      expect(decoded?.bangPayload?.ecdhPublicKey, [1, 2, 3]);
      expect(decoded?.bangPayload?.ecdhSignature, [4, 5]);
    });

    test('decodes STREAMINFO payloads from wire bytes', () {
      final resolution = _message([
        _varintField(1, 1280),
        _varintField(2, 720),
        _bytesField(3, [9, 9, 9]),
      ]);
      final streamInfo = _message([
        _varintField(1, 13),
        _messageField(
          15,
          _message([
            _messageField(1, resolution),
            _bytesField(2, [7, 7]),
            _varintField(3, 120),
            _varintField(4, 60),
            _varintField(5, 30),
            _varintField(6, 15),
          ]),
        ),
      ]);

      final decoded = TakionCodec.decode(Uint8List.fromList(streamInfo));

      expect(decoded?.type, TakionMessageType.streamInfo);
      expect(decoded?.streamInfoPayload?.resolutions, hasLength(1));
      expect(decoded?.streamInfoPayload?.resolutions.first.width, 1280);
      expect(decoded?.streamInfoPayload?.resolutions.first.height, 720);
      expect(decoded?.streamInfoPayload?.resolutions.first.videoHeader, [
        9,
        9,
        9,
      ]);
      expect(decoded?.streamInfoPayload?.audioHeader, [7, 7]);
      expect(decoded?.streamInfoPayload?.startTimeout, 120);
      expect(decoded?.streamInfoPayload?.afkTimeout, 60);
      expect(decoded?.streamInfoPayload?.afkTimeoutDisconnect, 30);
      expect(decoded?.streamInfoPayload?.congestionControlInterval, 15);
    });

    test('encodes HEARTBEAT and STREAMINFOACK message types', () {
      final heartbeat = TakionCodec.decode(TakionCodec.encodeHeartbeat());
      final streamInfoAck = TakionCodec.decode(
        TakionCodec.encodeStreamInfoAck(),
      );

      expect(heartbeat?.type, TakionMessageType.heartbeat);
      expect(streamInfoAck?.type, TakionMessageType.streamInfoAck);
    });

    test('encodes DISCONNECT payloads', () {
      final decoded = TakionCodec.decode(TakionCodec.encodeDisconnect('bye'));

      expect(decoded?.type, TakionMessageType.disconnect);
      expect(decoded?.disconnectPayload?.reason, 'bye');
    });
  });
}

List<int> _message(List<List<int>> fields) {
  return fields.expand((field) => field).toList();
}

List<int> _varintField(int fieldNumber, int value) {
  return [..._varint((fieldNumber << 3) | 0), ..._varint(value)];
}

List<int> _stringField(int fieldNumber, String value) {
  return _bytesField(fieldNumber, utf8.encode(value));
}

List<int> _bytesField(int fieldNumber, List<int> value) {
  return [
    ..._varint((fieldNumber << 3) | 2),
    ..._varint(value.length),
    ...value,
  ];
}

List<int> _messageField(int fieldNumber, List<int> value) {
  return _bytesField(fieldNumber, value);
}

List<int> _varint(int value) {
  final bytes = <int>[];
  var current = value;
  while (true) {
    if ((current & ~0x7F) == 0) {
      bytes.add(current);
      break;
    }
    bytes.add((current & 0x7F) | 0x80);
    current >>= 7;
  }
  return bytes;
}
