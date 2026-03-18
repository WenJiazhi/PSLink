import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/services/audio_playback_service.dart';

void main() {
  group('AudioStreamConfig', () {
    test('parses Takion audio headers into playback parameters', () {
      final header = Uint8List.fromList([
        0x02, // channels
        0x10, // bits per sample
        0x00, 0x00, 0xBB, 0x80, // 48000 Hz
        0x00, 0x00, 0x03, 0xC0, // 960 frame size
        0x12, 0x34, // reserved
      ]);

      final config = AudioStreamConfig.fromHeader(header);

      expect(config, isNotNull);
      expect(config!.channels, 2);
      expect(config.bitsPerSample, 16);
      expect(config.sampleRate, 48000);
      expect(config.frameSize, 960);
      expect(config.reserved, 0x1234);
    });

    test('returns null when the audio header is incomplete', () {
      final header = Uint8List.fromList([0x02, 0x10, 0x00, 0x00]);
      expect(AudioStreamConfig.fromHeader(header), isNull);
    });
  });
}
