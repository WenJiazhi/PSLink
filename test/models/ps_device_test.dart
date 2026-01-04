import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/models/ps_device.dart';

void main() {
  group('PSDevice', () {
    group('创建测试', () {
      test('应该正确创建 PS4 设备', () {
        final device = PSDevice(
          hostId: 'test-host-id-001',
          hostName: 'My PS4',
          ipAddress: '192.168.1.100',
          systemVersion: '09.00',
          deviceTypeValue: 0,
        );

        expect(device.hostId, 'test-host-id-001');
        expect(device.hostName, 'My PS4');
        expect(device.ipAddress, '192.168.1.100');
        expect(device.systemVersion, '09.00');
        expect(device.deviceType, PSDeviceType.ps4);
        expect(device.port, 9295); // 默认端口
        expect(device.state, PSDeviceState.ready); // 默认状态
      });

      test('应该正确创建 PS5 设备', () {
        final device = PSDevice(
          hostId: 'test-host-id-002',
          hostName: 'My PS5',
          ipAddress: '192.168.1.101',
          port: 9296,
          systemVersion: '04.00.00',
          deviceTypeValue: 1,
          stateValue: 1,
        );

        expect(device.deviceType, PSDeviceType.ps5);
        expect(device.port, 9296);
        expect(device.state, PSDeviceState.standby);
      });

      test('应该正确处理可选字段', () {
        final now = DateTime.now();
        final device = PSDevice(
          hostId: 'test-host-id-003',
          hostName: 'Test PS',
          ipAddress: '192.168.1.102',
          systemVersion: '10.00',
          deviceTypeValue: 0,
          registKey: 'test-regist-key',
          rpKey: 'test-rp-key',
          lastConnected: now,
          nickname: 'Gaming Console',
        );

        expect(device.registKey, 'test-regist-key');
        expect(device.rpKey, 'test-rp-key');
        expect(device.lastConnected, now);
        expect(device.nickname, 'Gaming Console');
      });
    });

    group('设备状态和类型转换', () {
      test('deviceType 属性应该正确返回 PS4', () {
        final device = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
        );

        expect(device.deviceType, PSDeviceType.ps4);
        expect(device.deviceTypeString, 'PS4');
      });

      test('deviceType 属性应该正确返回 PS5', () {
        final device = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 1,
        );

        expect(device.deviceType, PSDeviceType.ps5);
        expect(device.deviceTypeString, 'PS5');
      });

      test('state 属性应该正确映射状态值', () {
        final readyDevice = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
          stateValue: 0,
        );
        expect(readyDevice.state, PSDeviceState.ready);
        expect(readyDevice.stateString, '就绪');
        expect(readyDevice.isReady, true);

        final standbyDevice = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
          stateValue: 1,
        );
        expect(standbyDevice.state, PSDeviceState.standby);
        expect(standbyDevice.stateString, '待机');
        expect(standbyDevice.isReady, false);

        final unknownDevice = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
          stateValue: 99,
        );
        expect(unknownDevice.state, PSDeviceState.unknown);
        expect(unknownDevice.stateString, '未知');
      });

      test('isRegistered 应该正确判断注册状态', () {
        final registered = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
          rpKey: 'valid-key',
        );
        expect(registered.isRegistered, true);

        final notRegistered = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
        );
        expect(notRegistered.isRegistered, false);

        final emptyKey = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
          rpKey: '',
        );
        expect(emptyKey.isRegistered, false);
      });

      test('displayName 应该优先显示昵称', () {
        final withNickname = PSDevice(
          hostId: 'id',
          hostName: 'PS5-12345',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 1,
          nickname: 'Gaming Station',
        );
        expect(withNickname.displayName, 'Gaming Station');

        final withoutNickname = PSDevice(
          hostId: 'id',
          hostName: 'PS5-12345',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 1,
        );
        expect(withoutNickname.displayName, 'PS5-12345');
      });
    });

    group('JSON 序列化', () {
      test('toJson 应该正确序列化设备', () {
        final now = DateTime.parse('2024-01-15T10:30:00Z');
        final device = PSDevice(
          hostId: 'host-123',
          hostName: 'Test PS',
          ipAddress: '192.168.1.50',
          port: 9295,
          systemVersion: '10.01',
          deviceTypeValue: 1,
          stateValue: 0,
          registKey: 'regist-key',
          rpKey: 'rp-key',
          lastConnected: now,
          nickname: 'My Console',
        );

        final json = device.toJson();

        expect(json['hostId'], 'host-123');
        expect(json['hostName'], 'Test PS');
        expect(json['ipAddress'], '192.168.1.50');
        expect(json['port'], 9295);
        expect(json['systemVersion'], '10.01');
        expect(json['deviceTypeValue'], 1);
        expect(json['stateValue'], 0);
        expect(json['registKey'], 'regist-key');
        expect(json['rpKey'], 'rp-key');
        expect(json['lastConnected'], '2024-01-15T10:30:00.000Z');
        expect(json['nickname'], 'My Console');
      });

      test('toJson 应该正确处理 null 字段', () {
        final device = PSDevice(
          hostId: 'host-123',
          hostName: 'Test PS',
          ipAddress: '192.168.1.50',
          systemVersion: '10.01',
          deviceTypeValue: 0,
        );

        final json = device.toJson();

        expect(json['registKey'], null);
        expect(json['rpKey'], null);
        expect(json['lastConnected'], null);
        expect(json['nickname'], null);
      });

      test('fromJson 应该正确反序列化设备', () {
        final json = {
          'hostId': 'host-456',
          'hostName': 'Gaming PS',
          'ipAddress': '192.168.1.200',
          'port': 9300,
          'systemVersion': '11.00',
          'deviceTypeValue': 0,
          'stateValue': 1,
          'registKey': 'test-regist',
          'rpKey': 'test-rp',
          'lastConnected': '2024-01-15T10:30:00.000Z',
          'nickname': 'Pro Console',
        };

        final device = PSDevice.fromJson(json);

        expect(device.hostId, 'host-456');
        expect(device.hostName, 'Gaming PS');
        expect(device.ipAddress, '192.168.1.200');
        expect(device.port, 9300);
        expect(device.systemVersion, '11.00');
        expect(device.deviceTypeValue, 0);
        expect(device.stateValue, 1);
        expect(device.registKey, 'test-regist');
        expect(device.rpKey, 'test-rp');
        expect(device.lastConnected, DateTime.parse('2024-01-15T10:30:00.000Z'));
        expect(device.nickname, 'Pro Console');
      });

      test('fromJson 应该使用默认值', () {
        final json = {
          'hostId': 'host-789',
          'hostName': 'Minimal PS',
          'ipAddress': '192.168.1.150',
          'systemVersion': '09.00',
          'deviceTypeValue': 0,
        };

        final device = PSDevice.fromJson(json);

        expect(device.port, 9295);
        expect(device.stateValue, 0);
        expect(device.registKey, null);
        expect(device.rpKey, null);
        expect(device.lastConnected, null);
        expect(device.nickname, null);
      });

      test('JSON 往返转换应该保持一致', () {
        final original = PSDevice(
          hostId: 'test-id',
          hostName: 'Test Device',
          ipAddress: '10.0.0.1',
          port: 9295,
          systemVersion: '10.00',
          deviceTypeValue: 1,
          stateValue: 0,
          rpKey: 'test-key',
        );

        final json = original.toJson();
        final restored = PSDevice.fromJson(json);

        expect(restored.hostId, original.hostId);
        expect(restored.hostName, original.hostName);
        expect(restored.ipAddress, original.ipAddress);
        expect(restored.port, original.port);
        expect(restored.systemVersion, original.systemVersion);
        expect(restored.deviceTypeValue, original.deviceTypeValue);
        expect(restored.stateValue, original.stateValue);
        expect(restored.rpKey, original.rpKey);
      });
    });

    group('fromDiscoveryResponse 解析', () {
      test('应该解析 PS4 就绪状态响应', () {
        final headers = {
          'status-code': '200',
          'host-id': 'ps4-host-001',
          'host-name': 'PlayStation 4',
          'system-version': '09.00.00',
        };

        final device = PSDevice.fromDiscoveryResponse('192.168.1.100', headers);

        expect(device.hostId, 'ps4-host-001');
        expect(device.hostName, 'PlayStation 4');
        expect(device.ipAddress, '192.168.1.100');
        expect(device.systemVersion, '09.00.00');
        expect(device.deviceType, PSDeviceType.ps4);
        expect(device.state, PSDeviceState.ready);
      });

      test('应该解析 PS5 就绪状态响应', () {
        final headers = {
          'status-code': '200',
          'host-id': 'ps5-host-001',
          'host-name': 'PlayStation 5',
          'system-version': '04.03.00',
          'host-type': 'PS5',
        };

        final device = PSDevice.fromDiscoveryResponse('192.168.1.101', headers);

        expect(device.hostId, 'ps5-host-001');
        expect(device.hostName, 'PlayStation 5');
        expect(device.ipAddress, '192.168.1.101');
        expect(device.deviceType, PSDeviceType.ps5);
        expect(device.state, PSDeviceState.ready);
      });

      test('应该解析待机状态响应 (620 状态码)', () {
        final headers = {
          'status-code': '620',
          'host-id': 'standby-host',
          'host-name': 'Standby Console',
          'system-version': '10.00',
        };

        final device = PSDevice.fromDiscoveryResponse('192.168.1.102', headers);

        expect(device.state, PSDeviceState.standby);
      });

      test('应该处理未知状态码', () {
        final headers = {
          'status-code': '999',
          'host-id': 'unknown-host',
          'host-name': 'Unknown Console',
          'system-version': '01.00',
        };

        final device = PSDevice.fromDiscoveryResponse('192.168.1.103', headers);

        expect(device.state, PSDeviceState.unknown);
      });

      test('应该通过系统版本识别 PS5 (0 开头)', () {
        final headers = {
          'status-code': '200',
          'host-id': 'ps5-by-version',
          'host-name': 'PS5',
          'system-version': '04.00.00',
        };

        final device = PSDevice.fromDiscoveryResponse('192.168.1.104', headers);

        expect(device.deviceType, PSDeviceType.ps5);
      });

      test('应该使用默认值处理缺失字段', () {
        final headers = {
          'host-id': 'minimal-host',
        };

        final device = PSDevice.fromDiscoveryResponse('192.168.1.105', headers);

        expect(device.hostId, 'minimal-host');
        expect(device.hostName, 'Unknown PS');
        expect(device.systemVersion, '');
        expect(device.deviceType, PSDeviceType.ps4);
      });
    });

    group('copyWith', () {
      test('应该创建副本并更新指定字段', () {
        final original = PSDevice(
          hostId: 'original-id',
          hostName: 'Original',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
          stateValue: 0,
        );

        final updated = original.copyWith(
          hostName: 'Updated',
          stateValue: 1,
          nickname: 'New Nickname',
        );

        expect(updated.hostId, original.hostId); // 未变
        expect(updated.hostName, 'Updated'); // 已更新
        expect(updated.ipAddress, original.ipAddress); // 未变
        expect(updated.stateValue, 1); // 已更新
        expect(updated.nickname, 'New Nickname'); // 已更新
      });

      test('未指定参数时应该保持原值', () {
        final original = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
          rpKey: 'key-123',
        );

        final copy = original.copyWith();

        expect(copy.hostId, original.hostId);
        expect(copy.hostName, original.hostName);
        expect(copy.ipAddress, original.ipAddress);
        expect(copy.rpKey, original.rpKey);
      });
    });

    group('equals 和 hashCode', () {
      test('相同 hostId 的设备应该相等', () {
        final device1 = PSDevice(
          hostId: 'same-id',
          hostName: 'Device 1',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
        );

        final device2 = PSDevice(
          hostId: 'same-id',
          hostName: 'Device 2',
          ipAddress: '192.168.1.2',
          systemVersion: '2.0',
          deviceTypeValue: 1,
        );

        expect(device1, equals(device2));
        expect(device1.hashCode, device2.hashCode);
      });

      test('不同 hostId 的设备应该不相等', () {
        final device1 = PSDevice(
          hostId: 'id-1',
          hostName: 'Device',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
        );

        final device2 = PSDevice(
          hostId: 'id-2',
          hostName: 'Device',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
        );

        expect(device1, isNot(equals(device2)));
      });

      test('同一实例应该相等', () {
        final device = PSDevice(
          hostId: 'id',
          hostName: 'name',
          ipAddress: '192.168.1.1',
          systemVersion: '1.0',
          deviceTypeValue: 0,
        );

        expect(device, equals(device));
      });
    });

    group('toString', () {
      test('应该返回有意义的字符串表示', () {
        final device = PSDevice(
          hostId: 'test-id',
          hostName: 'Test PS',
          ipAddress: '192.168.1.100',
          systemVersion: '10.00',
          deviceTypeValue: 1,
          stateValue: 0,
          rpKey: 'test-key',
        );

        final str = device.toString();

        expect(str, contains('test-id'));
        expect(str, contains('Test PS'));
        expect(str, contains('192.168.1.100'));
        expect(str, contains('PS5'));
        expect(str, contains('就绪'));
        expect(str, contains('registered: true'));
      });
    });
  });
}
