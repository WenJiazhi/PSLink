import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/core/constants.dart';
import 'package:pslink/models/ps_device.dart';
import 'package:pslink/services/discovery_service.dart';

void main() {
  group('DiscoveryService', () {
    late DiscoveryService service;

    setUp(() {
      service = DiscoveryService();
    });

    tearDown(() {
      service.dispose();
    });

    test('starts idle with no devices', () {
      expect(service.isDiscovering, isFalse);
      expect(service.devices, isEmpty);
      expect(service.deviceStream, isNull);
    });

    test('builds the correct DDP search message', () {
      final request = service.buildSearchRequest();

      expect(request, startsWith('SRCH * HTTP/1.1\n'));
      expect(
        request,
        contains(
          'device-discovery-protocol-version:${PSConstants.ddpVersion}',
        ),
      );
    });

    test('builds the correct DDP wake message', () {
      final request = service.buildWakeRequest('123456');

      expect(request, startsWith('WAKEUP * HTTP/1.1\n'));
      expect(request, contains('user-credential:123456'));
      expect(request, contains('client-type:vr'));
      expect(request, contains('auth-type:R'));
      expect(request, contains('model:w'));
      expect(request, contains('app-type:r'));
    });

    test('parses a ready PS4 discovery response', () {
      const response = 'HTTP/1.1 200 Ok\r\n'
          'host-id:PS4-HOST-001\r\n'
          'host-name:My PlayStation 4\r\n'
          'host-type:PS4\r\n'
          'system-version:09.00.00\r\n';

      final device = service.parseDiscoveryResponse('192.168.1.100', response);

      expect(device, isNotNull);
      expect(device!.hostId, 'PS4-HOST-001');
      expect(device.hostName, 'My PlayStation 4');
      expect(device.ipAddress, '192.168.1.100');
      expect(device.deviceType, PSDeviceType.ps4);
      expect(device.state, PSDeviceState.ready);
    });

    test('parses a standby PS5 discovery response', () {
      const response = 'HTTP/1.1 620 Server Standby\r\n'
          'host-id:PS5-HOST-002\r\n'
          'host-name:My PlayStation 5\r\n'
          'host-type:PS5\r\n'
          'system-version:04.03.00\r\n';

      final device = service.parseDiscoveryResponse('192.168.1.101', response);

      expect(device, isNotNull);
      expect(device!.deviceType, PSDeviceType.ps5);
      expect(device.state, PSDeviceState.standby);
    });

    test('returns null for invalid responses', () {
      expect(
        service.parseDiscoveryResponse('192.168.1.1', 'not-http'),
        isNull,
      );
      expect(
        service.parseDiscoveryResponse(
          '192.168.1.1',
          'HTTP/1.1 200 Ok\r\nsystem-version:10.00\r\n',
        ),
        isNull,
      );
    });

    test('formats regist keys into wake credentials', () {
      expect(service.formatWakeCredential('31323334'), '4660');
    });

    test('uses the expected discovery constants', () {
      expect(PSConstants.discoveryPortPS4, 987);
      expect(PSConstants.discoveryPortPS5, 9302);
      expect(PSConstants.discoveryClientPort, 9303);
      expect(PSConstants.discoveryPorts, containsAll([987, 9302]));
    });
  });
}
