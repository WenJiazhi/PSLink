import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/models/ps_device.dart';

void main() {
  group('PSDevice', () {
    test('creates PS4 and PS5 devices correctly', () {
      final ps4 = PSDevice(
        hostId: 'ps4-id',
        hostName: 'My PS4',
        ipAddress: '192.168.1.100',
        systemVersion: '09.00.00',
        deviceTypeValue: 0,
      );
      final ps5 = PSDevice(
        hostId: 'ps5-id',
        hostName: 'My PS5',
        ipAddress: '192.168.1.101',
        systemVersion: '04.03.00',
        deviceTypeValue: 1,
        stateValue: 1,
      );

      expect(ps4.deviceType, PSDeviceType.ps4);
      expect(ps4.deviceTypeString, 'PS4');
      expect(ps4.state, PSDeviceState.ready);
      expect(ps5.deviceType, PSDeviceType.ps5);
      expect(ps5.deviceTypeString, 'PS5');
      expect(ps5.state, PSDeviceState.standby);
    });

    test('maps state strings to readable Chinese labels', () {
      final ready = PSDevice(
        hostId: 'ready',
        hostName: 'Ready',
        ipAddress: '192.168.1.2',
        systemVersion: '1.0',
        deviceTypeValue: 0,
        stateValue: 0,
      );
      final standby = ready.copyWith(hostId: 'standby', stateValue: 1);
      final unknown = ready.copyWith(hostId: 'unknown', stateValue: 99);

      expect(ready.stateString, '就绪');
      expect(standby.stateString, '待机');
      expect(unknown.stateString, '未知');
    });

    test('uses nickname for display name when available', () {
      final device = PSDevice(
        hostId: 'id',
        hostName: 'PS5-12345',
        ipAddress: '192.168.1.1',
        systemVersion: '1.0',
        deviceTypeValue: 1,
        nickname: '客厅主机',
      );

      expect(device.displayName, '客厅主机');

      final withoutNickname = PSDevice(
        hostId: 'id-2',
        hostName: 'PS5-12345',
        ipAddress: '192.168.1.2',
        systemVersion: '1.0',
        deviceTypeValue: 1,
      );
      expect(withoutNickname.displayName, 'PS5-12345');
    });

    test('detects registration from RP key', () {
      final registered = PSDevice(
        hostId: 'id',
        hostName: 'name',
        ipAddress: '192.168.1.1',
        systemVersion: '1.0',
        deviceTypeValue: 0,
        rpKey: 'valid-key',
      );
      final notRegistered = registered.copyWith(
        hostId: 'id-2',
        rpKey: '',
      );

      expect(registered.isRegistered, isTrue);
      expect(notRegistered.isRegistered, isFalse);
    });

    test('serializes and deserializes through JSON', () {
      final now = DateTime.parse('2024-01-15T10:30:00.000Z');
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
      final roundTrip = PSDevice.fromJson(json);

      expect(roundTrip.hostId, 'host-123');
      expect(roundTrip.hostName, 'Test PS');
      expect(roundTrip.ipAddress, '192.168.1.50');
      expect(roundTrip.port, 9295);
      expect(roundTrip.systemVersion, '10.01');
      expect(roundTrip.deviceTypeValue, 1);
      expect(roundTrip.stateValue, 0);
      expect(roundTrip.registKey, 'regist-key');
      expect(roundTrip.rpKey, 'rp-key');
      expect(roundTrip.lastConnected, now);
      expect(roundTrip.nickname, 'My Console');
    });

    test('parses PS4 and PS5 discovery responses', () {
      final ps4 = PSDevice.fromDiscoveryResponse('192.168.1.100', {
        'status-code': '200',
        'host-id': 'PS4-HOST-001',
        'host-name': 'My PlayStation 4',
        'host-type': 'PS4',
        'system-version': '09.00.00',
      });
      final ps5 = PSDevice.fromDiscoveryResponse('192.168.1.101', {
        'status-code': '620',
        'host-id': 'PS5-HOST-002',
        'host-name': 'My PlayStation 5',
        'host-type': 'PS5',
        'system-version': '04.03.00',
      });

      expect(ps4.deviceType, PSDeviceType.ps4);
      expect(ps4.state, PSDeviceState.ready);
      expect(ps5.deviceType, PSDeviceType.ps5);
      expect(ps5.state, PSDeviceState.standby);
    });

    test('infers PS5 from system version when host type is missing', () {
      final device = PSDevice.fromDiscoveryResponse('192.168.1.101', {
        'status-code': '200',
        'host-id': 'PS5-HOST-003',
        'host-name': 'PlayStation',
        'system-version': '04.50.00',
      });

      expect(device.deviceType, PSDeviceType.ps5);
    });

    test('copyWith keeps unspecified values', () {
      final now = DateTime.now();
      final original = PSDevice(
        hostId: 'host-1',
        hostName: 'Original',
        ipAddress: '192.168.1.10',
        systemVersion: '1.0',
        deviceTypeValue: 0,
        stateValue: 0,
        registKey: 'reg',
        rpKey: 'rp',
        lastConnected: now,
        nickname: '主机',
      );

      final updated = original.copyWith(
        hostName: 'Updated',
        stateValue: 1,
      );

      expect(updated.hostId, 'host-1');
      expect(updated.hostName, 'Updated');
      expect(updated.ipAddress, '192.168.1.10');
      expect(updated.stateValue, 1);
      expect(updated.registKey, 'reg');
      expect(updated.rpKey, 'rp');
      expect(updated.lastConnected, now);
      expect(updated.nickname, '主机');
    });

    test('equality is based on host id', () {
      final a = PSDevice(
        hostId: 'same-id',
        hostName: 'PS A',
        ipAddress: '192.168.1.2',
        systemVersion: '1.0',
        deviceTypeValue: 0,
      );
      final b = PSDevice(
        hostId: 'same-id',
        hostName: 'PS B',
        ipAddress: '192.168.1.3',
        systemVersion: '2.0',
        deviceTypeValue: 1,
      );
      final c = b.copyWith(hostId: 'different-id');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
