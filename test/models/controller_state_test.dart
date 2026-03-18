import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/models/controller_state.dart';

void main() {
  group('ControllerState', () {
    test('provides an empty default state', () {
      const state = ControllerState();

      expect(state.cross, isFalse);
      expect(state.circle, isFalse);
      expect(state.square, isFalse);
      expect(state.triangle, isFalse);
      expect(state.leftStickX, 0.0);
      expect(state.leftStickY, 0.0);
      expect(state.rightStickX, 0.0);
      expect(state.rightStickY, 0.0);
      expect(state.l2, 0.0);
      expect(state.r2, 0.0);
      expect(ControllerState.empty.cross, isFalse);
    });

    test('serializes button bits correctly', () {
      const state = ControllerState(
        cross: true,
        circle: true,
        square: true,
        triangle: true,
        l1: true,
        r1: true,
        options: true,
        dpadUp: true,
        mute: true,
      );
      final bytes = state.toBytes();

      expect(bytes.length, 14);
      expect(bytes[0] & 0x01, 0x01);
      expect(bytes[0] & 0x02, 0x02);
      expect(bytes[0] & 0x04, 0x04);
      expect(bytes[0] & 0x08, 0x08);
      expect(bytes[0] & 0x10, 0x10);
      expect(bytes[0] & 0x20, 0x20);
      expect(bytes[1] & 0x01, 0x01);
      expect(bytes[1] & 0x10, 0x10);
      expect(bytes[2] & 0x01, 0x01);
    });

    test('serializes sticks and triggers correctly', () {
      const state = ControllerState(
        leftStickX: 1.0,
        leftStickY: -1.0,
        rightStickX: 0.5,
        rightStickY: -0.5,
        l2: 0.5,
        r2: 1.0,
      );
      final bytes = state.toBytes();

      expect(bytes[4], 0xFF);
      expect(bytes[5], 0x7F);
      expect(bytes[6], 0x01);
      expect(bytes[7], 0x80);
      expect(bytes[8] | (bytes[9] << 8), closeTo(16383, 1));
      expect((bytes[10] | (bytes[11] << 8)).toSigned(16), closeTo(-16383, 1));
      expect(bytes[12], closeTo(127, 1));
      expect(bytes[13], 255);
    });

    test('clamps trigger values into byte range', () {
      const state = ControllerState(
        l2: 1.5,
        r2: -0.5,
      );
      final bytes = state.toBytes();

      expect(bytes[12], 255);
      expect(bytes[13], 0);
    });

    test('copyWith updates only specified values', () {
      const original = ControllerState(
        cross: false,
        l1: false,
        leftStickX: 0.0,
        rightStickY: 0.0,
      );

      final updated = original.copyWith(
        cross: true,
        l1: true,
        leftStickX: 0.5,
      );

      expect(updated.cross, isTrue);
      expect(updated.l1, isTrue);
      expect(updated.leftStickX, 0.5);
      expect(updated.rightStickY, 0.0);
    });

    test('toString contains readable button labels', () {
      const state = ControllerState(
        cross: true,
        circle: true,
        square: true,
        triangle: true,
        l2: 0.5,
        r2: 0.85,
      );
      final str = state.toString();

      expect(str, contains('X'));
      expect(str, contains('O'));
      expect(str, contains('□'));
      expect(str, contains('△'));
      expect(str, contains('L2:50%'));
      expect(str, contains('R2:85%'));
    });

    test('toString omits low trigger values', () {
      const state = ControllerState(
        l2: 0.05,
        r2: 0.15,
      );
      final str = state.toString();

      expect(str, isNot(contains('L2:')));
      expect(str, contains('R2:15%'));
    });
  });
}
