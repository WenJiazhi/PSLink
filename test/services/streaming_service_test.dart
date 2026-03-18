import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pslink/models/ps_device.dart';
import 'package:pslink/models/stream_settings.dart';
import 'package:pslink/services/streaming_service.dart';
import 'package:pslink/services/takion_codec.dart';

void main() {
  group('StreamingService', () {
    test('derives PS5 RP nonce and AES key from upstream session tables', () {
      final service = StreamingService();
      final nonce = Uint8List.fromList(
        List<int>.generate(16, (index) => index),
      );
      final rpKey = Uint8List.fromList(
        List<int>.generate(16, (index) => index + 16),
      );

      final rpNonce = service.generateRpNonce(PSDeviceType.ps5, nonce);
      final aesKey = service.generateAesKey(PSDeviceType.ps5, nonce, rpKey);

      expect(_toHex(rpNonce), 'ac7d50f394ea6588f0488f76e4170c8a');
      expect(_toHex(aesKey), 'c91f3930c120e8d02bd53a46799b210b');
    });

    test('derives PS4 RP nonce and AES key from upstream session tables', () {
      final service = StreamingService();
      final nonce = Uint8List.fromList(
        List<int>.generate(16, (index) => index),
      );
      final rpKey = Uint8List.fromList(
        List<int>.generate(16, (index) => index + 16),
      );

      final rpNonce = service.generateRpNonce(PSDeviceType.ps4, nonce);
      final aesKey = service.generateAesKey(PSDeviceType.ps4, nonce, rpKey);

      expect(_toHex(rpNonce), 'e978b89a1098296fb32415b9b5713be0');
      expect(_toHex(aesKey), '8797b0180c9a7c379c8c820fb7501758');
    });

    test('builds a PS5 launch spec aligned with upstream defaults', () async {
      final service = StreamingService();
      await service.updateSettings(const StreamSettings(enableHDR: true));
      final handshakeKey = Uint8List.fromList(
        List<int>.generate(16, (index) => 0xA0 + index),
      );

      final launchSpecBytes = service.buildLaunchSpec(
        PSDeviceType.ps5,
        handshakeKey,
        rttMs: 7,
        mtu: 1400,
      );

      expect(launchSpecBytes.last, 0);

      final launchSpec = String.fromCharCodes(
        launchSpecBytes.sublist(0, launchSpecBytes.length - 1),
      );
      final json = launchSpec.contains(':0.001000,')
          ? launchSpec.replaceAll(':0.001000,', ':0.001,')
          : launchSpec;
      final decoded = Map<String, dynamic>.from(
        (jsonDecode(json) as Map).cast<String, dynamic>(),
      );

      expect(decoded['videoCodec'], 'hevc');
      expect(decoded['dynamicRange'], 'HDR');
      expect(decoded['handshakeKey'], 'oKGio6SlpqeoqaqrrK2urw==');
      expect(
        decoded['requestGameSpecification']['adaptiveStreamMode'],
        'resize',
      );
      expect(decoded['network']['mtu'], 1400);
      expect(decoded['network']['rtt'], 7);
      expect(decoded['streamResolutions'][0]['resolution']['width'], 1280);
      expect(decoded['streamResolutions'][0]['resolution']['height'], 720);
      expect(decoded['streamResolutions'][0]['maxFps'], 60);
    });

    test('converts Takion heartbeat and stream info into the expected ACKs', () {
      final service = StreamingService();

      final heartbeat = service.handleTakionControlMessage(
        TakionCodec.encodeHeartbeat(),
      );
      final streamInfo = service.handleTakionControlMessage(
        Uint8List.fromList(_streamInfoMessage()),
      );

      expect(heartbeat?.type, TakionMessageType.heartbeat);
      expect(
        TakionCodec.decode(heartbeat!.ackPayload!)?.type,
        TakionMessageType.heartbeat,
      );
      expect(streamInfo?.type, TakionMessageType.streamInfo);
      expect(streamInfo?.streamInfo?.resolutions, hasLength(1));
      expect(streamInfo?.streamInfo?.resolutions.first.width, 1280);
      expect(
        TakionCodec.decode(streamInfo!.ackPayload!)?.type,
        TakionMessageType.streamInfoAck,
      );
    });
  });
}

String _toHex(Uint8List value) {
  final buffer = StringBuffer();
  for (final byte in value) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

List<int> _streamInfoMessage() {
  return _message(<List<int>>[
    _varintField(1, TakionMessageType.streamInfo.value),
    _messageField(
      15,
      _message(<List<int>>[
        _messageField(
          1,
          _message(<List<int>>[
            _varintField(1, 1280),
            _varintField(2, 720),
            _bytesField(3, <int>[1, 2, 3]),
          ]),
        ),
        _bytesField(2, <int>[4, 5]),
      ]),
    ),
  ]);
}

List<int> _message(List<List<int>> fields) {
  return fields.expand((field) => field).toList();
}

List<int> _varintField(int fieldNumber, int value) {
  return [..._varint((fieldNumber << 3) | 0), ..._varint(value)];
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
