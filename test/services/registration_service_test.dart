import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/models/ps_device.dart';
import 'package:pslink/services/registration_service.dart';

void main() {
  group('RegistrationService', () {
    late RegistrationService service;
    late PSDevice device;

    setUp(() {
      service = RegistrationService();
      device = PSDevice(
        hostId: 'ps5-host',
        hostName: 'Living Room PS5',
        ipAddress: '192.168.1.50',
        systemVersion: '04.03.00',
        deviceTypeValue: 1,
      );
    });

    test('rejects invalid PIN values before network work', () async {
      final result = await service.registerWithPin(
        device,
        '1234',
        'dGVzdA==',
      );

      expect(result, isNull);
      expect(service.lastError, contains('8 digits'));
    });

    test('rejects invalid Base64 account ids before network work', () async {
      final result = await service.registerWithPin(
        device,
        '12345678',
        'not-an-account-id',
      );

      expect(result, isNull);
      expect(service.lastError, contains('Base64'));
    });

    test('derives the expected PS5 registration keys', () {
      final key0 = service.generateKey0(PSDeviceType.ps5, '12345678');
      final key1 = service.generateKey1(
        PSDeviceType.ps5,
        Uint8List.fromList(List<int>.generate(16, (index) => index)),
      );

      expect(
        key0,
        equals([
          216,
          96,
          225,
          70,
          189,
          176,
          189,
          148,
          180,
          96,
          7,
          11,
          177,
          243,
          134,
          109,
        ]),
      );
      expect(
        key1,
        equals([
          123,
          10,
          56,
          140,
          250,
          209,
          218,
          67,
          69,
          38,
          13,
          138,
          236,
          120,
          101,
          108,
        ]),
      );
    });
  });
}
