import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/models/controller_state.dart';

void main() {
  group('ControllerState', () {
    group('创建和默认值', () {
      test('应该创建空状态的控制器', () {
        const state = ControllerState();

        expect(state.cross, false);
        expect(state.circle, false);
        expect(state.square, false);
        expect(state.triangle, false);
        expect(state.l1, false);
        expect(state.r1, false);
        expect(state.l3, false);
        expect(state.r3, false);
        expect(state.options, false);
        expect(state.share, false);
        expect(state.ps, false);
        expect(state.touchpad, false);
        expect(state.dpadUp, false);
        expect(state.dpadDown, false);
        expect(state.dpadLeft, false);
        expect(state.dpadRight, false);
        expect(state.mute, false);
        expect(state.leftStickX, 0.0);
        expect(state.leftStickY, 0.0);
        expect(state.rightStickX, 0.0);
        expect(state.rightStickY, 0.0);
        expect(state.l2, 0.0);
        expect(state.r2, 0.0);
        expect(state.touchX1, null);
        expect(state.touchY1, null);
        expect(state.touchX2, null);
        expect(state.touchY2, null);
        expect(state.gyroX, null);
        expect(state.gyroY, null);
        expect(state.gyroZ, null);
        expect(state.accelX, null);
        expect(state.accelY, null);
        expect(state.accelZ, null);
      });

      test('empty 常量应该是空状态', () {
        expect(ControllerState.empty.cross, false);
        expect(ControllerState.empty.leftStickX, 0.0);
        expect(ControllerState.empty.l2, 0.0);
      });

      test('应该正确设置按钮状态', () {
        const state = ControllerState(
          cross: true,
          circle: true,
          square: false,
          triangle: true,
          l1: true,
          r1: true,
          dpadUp: true,
          dpadRight: true,
        );

        expect(state.cross, true);
        expect(state.circle, true);
        expect(state.square, false);
        expect(state.triangle, true);
        expect(state.l1, true);
        expect(state.r1, true);
        expect(state.dpadUp, true);
        expect(state.dpadRight, true);
        expect(state.dpadDown, false);
        expect(state.dpadLeft, false);
      });

      test('应该正确设置模拟输入', () {
        const state = ControllerState(
          leftStickX: 0.5,
          leftStickY: -0.8,
          rightStickX: -0.3,
          rightStickY: 0.9,
          l2: 0.75,
          r2: 1.0,
        );

        expect(state.leftStickX, 0.5);
        expect(state.leftStickY, -0.8);
        expect(state.rightStickX, -0.3);
        expect(state.rightStickY, 0.9);
        expect(state.l2, 0.75);
        expect(state.r2, 1.0);
      });

      test('应该正确设置触摸和传感器数据', () {
        const state = ControllerState(
          touchX1: 0.5,
          touchY1: 0.3,
          touchX2: 0.7,
          touchY2: 0.8,
          gyroX: 1.2,
          gyroY: -0.5,
          gyroZ: 0.3,
          accelX: 0.1,
          accelY: 9.8,
          accelZ: 0.0,
        );

        expect(state.touchX1, 0.5);
        expect(state.touchY1, 0.3);
        expect(state.touchX2, 0.7);
        expect(state.touchY2, 0.8);
        expect(state.gyroX, 1.2);
        expect(state.gyroY, -0.5);
        expect(state.gyroZ, 0.3);
        expect(state.accelX, 0.1);
        expect(state.accelY, 9.8);
        expect(state.accelZ, 0.0);
      });
    });

    group('toBytes 序列化', () {
      test('空状态应该生成全零字节', () {
        const state = ControllerState();
        final bytes = state.toBytes();

        // 前4字节是按钮状态 (全0)
        expect(bytes[0], 0x00);
        expect(bytes[1], 0x00);
        expect(bytes[2], 0x00);
        expect(bytes[3], 0x00);

        // 摇杆数据 (4个轴 * 2字节 = 8字节, 全0)
        for (var i = 4; i < 12; i++) {
          expect(bytes[i], 0x00);
        }

        // 触发器数据 (2字节, 全0)
        expect(bytes[12], 0x00);
        expect(bytes[13], 0x00);

        expect(bytes.length, 14);
      });

      test('应该正确编码单个按钮', () {
        // Cross 按钮 (bit 0)
        const crossState = ControllerState(cross: true);
        final crossBytes = crossState.toBytes();
        expect(crossBytes[0] & 0x01, 0x01);

        // Circle 按钮 (bit 1)
        const circleState = ControllerState(circle: true);
        final circleBytes = circleState.toBytes();
        expect(circleBytes[0] & 0x02, 0x02);

        // Square 按钮 (bit 2)
        const squareState = ControllerState(square: true);
        final squareBytes = squareState.toBytes();
        expect(squareBytes[0] & 0x04, 0x04);

        // Triangle 按钮 (bit 3)
        const triangleState = ControllerState(triangle: true);
        final triangleBytes = triangleState.toBytes();
        expect(triangleBytes[0] & 0x08, 0x08);
      });

      test('应该正确编码肩键和触发器按钮', () {
        // L1 (bit 4)
        const l1State = ControllerState(l1: true);
        final l1Bytes = l1State.toBytes();
        expect(l1Bytes[0] & 0x10, 0x10);

        // R1 (bit 5)
        const r1State = ControllerState(r1: true);
        final r1Bytes = r1State.toBytes();
        expect(r1Bytes[0] & 0x20, 0x20);

        // L3 (bit 6)
        const l3State = ControllerState(l3: true);
        final l3Bytes = l3State.toBytes();
        expect(l3Bytes[0] & 0x40, 0x40);

        // R3 (bit 7)
        const r3State = ControllerState(r3: true);
        final r3Bytes = r3State.toBytes();
        expect(r3Bytes[0] & 0x80, 0x80);
      });

      test('应该正确编码功能按钮', () {
        // Options (bit 8)
        const optionsState = ControllerState(options: true);
        final optionsBytes = optionsState.toBytes();
        expect(optionsBytes[1] & 0x01, 0x01);

        // Share (bit 9)
        const shareState = ControllerState(share: true);
        final shareBytes = shareState.toBytes();
        expect(shareBytes[1] & 0x02, 0x02);

        // PS (bit 10)
        const psState = ControllerState(ps: true);
        final psBytes = psState.toBytes();
        expect(psBytes[1] & 0x04, 0x04);

        // Touchpad (bit 11)
        const touchpadState = ControllerState(touchpad: true);
        final touchpadBytes = touchpadState.toBytes();
        expect(touchpadBytes[1] & 0x08, 0x08);
      });

      test('应该正确编码方向键', () {
        // D-Pad Up (bit 12)
        const upState = ControllerState(dpadUp: true);
        final upBytes = upState.toBytes();
        expect(upBytes[1] & 0x10, 0x10);

        // D-Pad Down (bit 13)
        const downState = ControllerState(dpadDown: true);
        final downBytes = downState.toBytes();
        expect(downBytes[1] & 0x20, 0x20);

        // D-Pad Left (bit 14)
        const leftState = ControllerState(dpadLeft: true);
        final leftBytes = leftState.toBytes();
        expect(leftBytes[1] & 0x40, 0x40);

        // D-Pad Right (bit 15)
        const rightState = ControllerState(dpadRight: true);
        final rightBytes = rightState.toBytes();
        expect(rightBytes[1] & 0x80, 0x80);
      });

      test('应该正确编码静音按钮 (bit 16)', () {
        const muteState = ControllerState(mute: true);
        final muteBytes = muteState.toBytes();
        expect(muteBytes[2] & 0x01, 0x01);
      });

      test('应该正确编码多个同时按下的按钮', () {
        const state = ControllerState(
          cross: true,
          circle: true,
          l1: true,
          r1: true,
          dpadUp: true,
        );
        final bytes = state.toBytes();

        // 检查所有按钮位
        expect(bytes[0] & 0x01, 0x01); // cross
        expect(bytes[0] & 0x02, 0x02); // circle
        expect(bytes[0] & 0x10, 0x10); // l1
        expect(bytes[0] & 0x20, 0x20); // r1
        expect(bytes[1] & 0x10, 0x10); // dpadUp
      });

      test('应该正确编码左摇杆中立位置', () {
        const state = ControllerState(
          leftStickX: 0.0,
          leftStickY: 0.0,
        );
        final bytes = state.toBytes();

        // 字节 4-5: leftStickX (0)
        expect(bytes[4], 0x00);
        expect(bytes[5], 0x00);

        // 字节 6-7: leftStickY (0)
        expect(bytes[6], 0x00);
        expect(bytes[7], 0x00);
      });

      test('应该正确编码左摇杆最大正值', () {
        const state = ControllerState(
          leftStickX: 1.0,
          leftStickY: 1.0,
        );
        final bytes = state.toBytes();

        // 1.0 * 32767 = 32767 = 0x7FFF
        expect(bytes[4], 0xFF);
        expect(bytes[5], 0x7F);
        expect(bytes[6], 0xFF);
        expect(bytes[7], 0x7F);
      });

      test('应该正确编码左摇杆最大负值', () {
        const state = ControllerState(
          leftStickX: -1.0,
          leftStickY: -1.0,
        );
        final bytes = state.toBytes();

        // -1.0 * 32767 = -32767 = 0x8001 (补码)
        expect(bytes[4], 0x01);
        expect(bytes[5], 0x80);
        expect(bytes[6], 0x01);
        expect(bytes[7], 0x80);
      });

      test('应该正确编码右摇杆', () {
        const state = ControllerState(
          rightStickX: 0.5,
          rightStickY: -0.5,
        );
        final bytes = state.toBytes();

        // 0.5 * 32767 ≈ 16383 = 0x3FFF
        final rightX = bytes[8] | (bytes[9] << 8);
        expect(rightX, closeTo(16383, 1));

        // -0.5 * 32767 ≈ -16383
        final rightY = (bytes[10] | (bytes[11] << 8)).toSigned(16);
        expect(rightY, closeTo(-16383, 1));
      });

      test('应该正确编码触发器值', () {
        const state = ControllerState(
          l2: 0.0,
          r2: 0.0,
        );
        final bytes = state.toBytes();
        expect(bytes[12], 0);
        expect(bytes[13], 0);

        const halfState = ControllerState(
          l2: 0.5,
          r2: 0.5,
        );
        final halfBytes = halfState.toBytes();
        expect(halfBytes[12], closeTo(127, 1));
        expect(halfBytes[13], closeTo(127, 1));

        const fullState = ControllerState(
          l2: 1.0,
          r2: 1.0,
        );
        final fullBytes = fullState.toBytes();
        expect(fullBytes[12], 255);
        expect(fullBytes[13], 255);
      });

      test('触发器值应该被限制在 0-255 范围内', () {
        const state = ControllerState(
          l2: 1.5, // 超出范围
          r2: -0.5, // 负值
        );
        final bytes = state.toBytes();

        expect(bytes[12], 255); // 被限制为 255
        expect(bytes[13], 0); // 被限制为 0
      });

      test('完整状态序列化', () {
        const state = ControllerState(
          cross: true,
          triangle: true,
          l1: true,
          r2: 0.8,
          leftStickX: 0.3,
          leftStickY: -0.6,
          rightStickX: -0.4,
          rightStickY: 0.7,
        );

        final bytes = state.toBytes();

        expect(bytes.length, 14);

        // 验证按钮
        expect(bytes[0] & 0x01, 0x01); // cross
        expect(bytes[0] & 0x08, 0x08); // triangle
        expect(bytes[0] & 0x10, 0x10); // l1

        // 验证触发器
        expect(bytes[13], closeTo(204, 1)); // 0.8 * 255 ≈ 204
      });
    });

    group('copyWith', () {
      test('应该创建副本并更新指定的按钮', () {
        const original = ControllerState(
          cross: false,
          circle: false,
          l1: false,
        );

        final updated = original.copyWith(
          cross: true,
          circle: true,
        );

        expect(updated.cross, true);
        expect(updated.circle, true);
        expect(updated.l1, false); // 未改变
      });

      test('应该更新摇杆值', () {
        const original = ControllerState(
          leftStickX: 0.0,
          leftStickY: 0.0,
        );

        final updated = original.copyWith(
          leftStickX: 0.5,
          leftStickY: -0.3,
        );

        expect(updated.leftStickX, 0.5);
        expect(updated.leftStickY, -0.3);
        expect(updated.rightStickX, 0.0); // 未改变
      });

      test('应该更新触发器值', () {
        const original = ControllerState(l2: 0.0, r2: 0.0);

        final updated = original.copyWith(
          l2: 0.8,
          r2: 1.0,
        );

        expect(updated.l2, 0.8);
        expect(updated.r2, 1.0);
      });

      test('应该更新触摸和传感器数据', () {
        const original = ControllerState();

        final updated = original.copyWith(
          touchX1: 0.5,
          touchY1: 0.5,
          gyroX: 1.0,
          accelX: 0.5,
        );

        expect(updated.touchX1, 0.5);
        expect(updated.touchY1, 0.5);
        expect(updated.gyroX, 1.0);
        expect(updated.accelX, 0.5);
        expect(updated.touchX2, null); // 未改变
      });

      test('未指定参数时应该保持原值', () {
        const original = ControllerState(
          cross: true,
          leftStickX: 0.5,
          l2: 0.8,
        );

        final copy = original.copyWith();

        expect(copy.cross, true);
        expect(copy.leftStickX, 0.5);
        expect(copy.l2, 0.8);
      });

      test('应该能够更新所有字段', () {
        const original = ControllerState.empty;

        final updated = original.copyWith(
          cross: true,
          circle: true,
          square: true,
          triangle: true,
          l1: true,
          r1: true,
          l3: true,
          r3: true,
          options: true,
          share: true,
          ps: true,
          touchpad: true,
          dpadUp: true,
          dpadDown: true,
          dpadLeft: true,
          dpadRight: true,
          mute: true,
          leftStickX: 0.5,
          leftStickY: -0.5,
          rightStickX: -0.3,
          rightStickY: 0.7,
          l2: 0.8,
          r2: 1.0,
          touchX1: 0.5,
          touchY1: 0.3,
          gyroX: 1.0,
        );

        expect(updated.cross, true);
        expect(updated.circle, true);
        expect(updated.square, true);
        expect(updated.triangle, true);
        expect(updated.l1, true);
        expect(updated.r1, true);
        expect(updated.leftStickX, 0.5);
        expect(updated.l2, 0.8);
        expect(updated.touchX1, 0.5);
        expect(updated.gyroX, 1.0);
      });
    });

    group('toString', () {
      test('空状态应该显示空按钮列表', () {
        const state = ControllerState.empty;
        final str = state.toString();

        expect(str, contains('buttons: []'));
        expect(str, contains('L:(0.00,0.00)'));
        expect(str, contains('R:(0.00,0.00)'));
      });

      test('应该显示按下的按钮', () {
        const state = ControllerState(
          cross: true,
          circle: true,
          square: true,
        );
        final str = state.toString();

        expect(str, contains('X'));
        expect(str, contains('O'));
        expect(str, contains('□'));
      });

      test('应该显示触发器百分比', () {
        const state = ControllerState(
          l2: 0.5,
          r2: 0.85,
        );
        final str = state.toString();

        expect(str, contains('L2:50%'));
        expect(str, contains('R2:85%'));
      });

      test('应该忽略低于阈值的触发器', () {
        const state = ControllerState(
          l2: 0.05, // 小于 0.1
          r2: 0.15, // 大于 0.1
        );
        final str = state.toString();

        expect(str, isNot(contains('L2')));
        expect(str, contains('R2:15%'));
      });

      test('应该显示摇杆位置', () {
        const state = ControllerState(
          leftStickX: 0.5,
          leftStickY: -0.3,
          rightStickX: -0.7,
          rightStickY: 0.9,
        );
        final str = state.toString();

        expect(str, contains('L:(0.50,-0.30)'));
        expect(str, contains('R:(-0.70,0.90)'));
      });

      test('复杂状态的字符串表示', () {
        const state = ControllerState(
          cross: true,
          l1: true,
          r1: true,
          l2: 0.6,
          leftStickX: 0.3,
          leftStickY: -0.4,
          rightStickX: -0.2,
          rightStickY: 0.8,
        );
        final str = state.toString();

        expect(str, contains('X'));
        expect(str, contains('L1'));
        expect(str, contains('R1'));
        expect(str, contains('L2:60%'));
        expect(str, contains('L:(0.30,-0.40)'));
        expect(str, contains('R:(-0.20,0.80)'));
      });
    });
  });
}
