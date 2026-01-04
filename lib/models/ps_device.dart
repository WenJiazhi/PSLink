import 'package:hive/hive.dart';

part 'ps_device.g.dart';

/// PlayStation 设备状态
enum PSDeviceState {
  ready,      // 就绪可连接
  standby,    // 待机模式
  unknown,    // 未知状态
}

/// PlayStation 设备类型
enum PSDeviceType {
  ps4,
  ps5,
}

/// PlayStation 设备模型
@HiveType(typeId: 0)
class PSDevice {
  @HiveField(0)
  final String hostId;

  @HiveField(1)
  final String hostName;

  @HiveField(2)
  final String ipAddress;

  @HiveField(3)
  final int port;

  @HiveField(4)
  final String systemVersion;

  @HiveField(5)
  final int deviceTypeValue;

  @HiveField(6)
  final int stateValue;

  @HiveField(7)
  final String? registKey;

  @HiveField(8)
  final String? rpKey;

  @HiveField(9)
  final DateTime? lastConnected;

  @HiveField(10)
  final String? nickname;

  PSDevice({
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

  /// 从发现响应解析设备
  factory PSDevice.fromDiscoveryResponse(
    String ipAddress,
    Map<String, String> headers,
  ) {
    final statusCode = int.tryParse(headers['status-code'] ?? '') ?? 0;
    int stateValue;
    switch (statusCode) {
      case 200:
        stateValue = 0; // ready
        break;
      case 620:
        stateValue = 1; // standby
        break;
      default:
        stateValue = 2; // unknown
    }

    // 判断设备类型
    final systemVersion = headers['system-version'] ?? '';
    final isPS5 = systemVersion.startsWith('0') ||
                  headers['host-type']?.contains('PS5') == true;

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
    if (identical(this, other)) return true;
    return other is PSDevice && other.hostId == hostId;
  }

  @override
  int get hashCode => hostId.hashCode;
}
