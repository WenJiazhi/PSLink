enum PSDeviceState {
  ready,
  standby,
  unknown,
}

enum PSDeviceType {
  ps4,
  ps5,
}

class PSDevice {
  const PSDevice({
    required this.hostId,
    required this.hostName,
    required this.ipAddress,
    this.port = 9295,
    required this.systemVersion,
    required this.deviceTypeValue,
    this.stateValue = 0,
    this.registKey,
    this.rpKey,
    this.lastConnected,
    this.nickname,
  });

  final String hostId;
  final String hostName;
  final String ipAddress;
  final int port;
  final String systemVersion;
  final int deviceTypeValue;
  final int stateValue;
  final String? registKey;
  final String? rpKey;
  final DateTime? lastConnected;
  final String? nickname;

  PSDeviceType get deviceType =>
      deviceTypeValue == 0 ? PSDeviceType.ps4 : PSDeviceType.ps5;

  PSDeviceState get state {
    switch (stateValue) {
      case 0:
        return PSDeviceState.ready;
      case 1:
        return PSDeviceState.standby;
      default:
        return PSDeviceState.unknown;
    }
  }

  bool get isRegistered => rpKey != null && rpKey!.isNotEmpty;

  bool get isReady => state == PSDeviceState.ready;

  String get displayName => nickname ?? hostName;

  String get deviceTypeString => deviceType == PSDeviceType.ps5 ? 'PS5' : 'PS4';

  String get stateString {
    switch (state) {
      case PSDeviceState.ready:
        return '就绪';
      case PSDeviceState.standby:
        return '待机';
      case PSDeviceState.unknown:
        return '未知';
    }
  }

  PSDevice copyWith({
    String? hostId,
    String? hostName,
    String? ipAddress,
    int? port,
    String? systemVersion,
    int? deviceTypeValue,
    int? stateValue,
    String? registKey,
    String? rpKey,
    DateTime? lastConnected,
    String? nickname,
  }) {
    return PSDevice(
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      systemVersion: systemVersion ?? this.systemVersion,
      deviceTypeValue: deviceTypeValue ?? this.deviceTypeValue,
      stateValue: stateValue ?? this.stateValue,
      registKey: registKey ?? this.registKey,
      rpKey: rpKey ?? this.rpKey,
      lastConnected: lastConnected ?? this.lastConnected,
      nickname: nickname ?? this.nickname,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hostId': hostId,
      'hostName': hostName,
      'ipAddress': ipAddress,
      'port': port,
      'systemVersion': systemVersion,
      'deviceTypeValue': deviceTypeValue,
      'stateValue': stateValue,
      'registKey': registKey,
      'rpKey': rpKey,
      'lastConnected': lastConnected?.toIso8601String(),
      'nickname': nickname,
    };
  }

  factory PSDevice.fromJson(Map<String, dynamic> json) {
    return PSDevice(
      hostId: json['hostId'] as String,
      hostName: json['hostName'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int? ?? 9295,
      systemVersion: json['systemVersion'] as String,
      deviceTypeValue: json['deviceTypeValue'] as int,
      stateValue: json['stateValue'] as int? ?? 0,
      registKey: json['registKey'] as String?,
      rpKey: json['rpKey'] as String?,
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'] as String)
          : null,
      nickname: json['nickname'] as String?,
    );
  }

  factory PSDevice.fromDiscoveryResponse(
    String ipAddress,
    Map<String, String> headers,
  ) {
    final statusCode = int.tryParse(headers['status-code'] ?? '') ?? 0;
    final stateValue = switch (statusCode) {
      200 => 0,
      620 => 1,
      _ => 2,
    };

    final systemVersion = headers['system-version'] ?? '';
    final hostType = (headers['host-type'] ?? '').toUpperCase();
    final isPS5 =
        hostType.contains('PS5') ||
        (hostType.isEmpty && systemVersion.startsWith('04.'));

    return PSDevice(
      hostId: headers['host-id'] ?? '',
      hostName: headers['host-name'] ?? 'Unknown PS',
      ipAddress: ipAddress,
      systemVersion: systemVersion,
      deviceTypeValue: isPS5 ? 1 : 0,
      stateValue: stateValue,
    );
  }

  @override
  String toString() {
    return 'PSDevice{hostId: $hostId, hostName: $hostName, ipAddress: $ipAddress, '
        'deviceType: $deviceTypeString, state: $stateString, registered: $isRegistered}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PSDevice && other.hostId == hostId;
  }

  @override
  int get hashCode => hostId.hashCode;
}
