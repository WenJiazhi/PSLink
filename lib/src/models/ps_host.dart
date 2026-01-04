import 'package:hive/hive.dart';

part 'ps_host.g.dart';

/// Represents a discovered PlayStation console
@HiveType(typeId: 0)
class PSHost {
  @HiveField(0)
  final String hostId;

  @HiveField(1)
  final String hostName;

  @HiveField(2)
  final String hostAddress;

  @HiveField(3)
  final int hostPort;

  @HiveField(4)
  final String systemVersion;

  @HiveField(5)
  final bool isPS5;

  @HiveField(6)
  final String? runningAppId;

  @HiveField(7)
  final String? runningAppName;

  @HiveField(8)
  final HostState state;

  @HiveField(9)
  final DateTime lastSeen;

  @HiveField(10)
  final RegisteredHostInfo? registrationInfo;

  PSHost({
    required this.hostId,
    required this.hostName,
    required this.hostAddress,
    required this.hostPort,
    required this.systemVersion,
    required this.isPS5,
    this.runningAppId,
    this.runningAppName,
    required this.state,
    required this.lastSeen,
    this.registrationInfo,
  });

  PSHost copyWith({
    String? hostId,
    String? hostName,
    String? hostAddress,
    int? hostPort,
    String? systemVersion,
    bool? isPS5,
    String? runningAppId,
    String? runningAppName,
    HostState? state,
    DateTime? lastSeen,
    RegisteredHostInfo? registrationInfo,
  }) {
    return PSHost(
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAddress: hostAddress ?? this.hostAddress,
      hostPort: hostPort ?? this.hostPort,
      systemVersion: systemVersion ?? this.systemVersion,
      isPS5: isPS5 ?? this.isPS5,
      runningAppId: runningAppId ?? this.runningAppId,
      runningAppName: runningAppName ?? this.runningAppName,
      state: state ?? this.state,
      lastSeen: lastSeen ?? this.lastSeen,
      registrationInfo: registrationInfo ?? this.registrationInfo,
    );
  }

  bool get isRegistered => registrationInfo != null;

  @override
  String toString() {
    return 'PSHost($hostName, $hostAddress, isPS5: $isPS5, state: $state)';
  }
}

@HiveType(typeId: 1)
enum HostState {
  @HiveField(0)
  ready,

  @HiveField(1)
  standby,

  @HiveField(2)
  unknown,
}

/// Registration information for a paired PlayStation console
@HiveType(typeId: 2)
class RegisteredHostInfo {
  @HiveField(0)
  final String rpRegistKey;

  @HiveField(1)
  final List<int> rpKey;

  @HiveField(2)
  final int rpKeyType;

  @HiveField(3)
  final List<int> serverMac;

  @HiveField(4)
  final String serverNickname;

  @HiveField(5)
  final String? apSsid;

  @HiveField(6)
  final String? apBssid;

  @HiveField(7)
  final String? apKey;

  @HiveField(8)
  final DateTime registeredAt;

  RegisteredHostInfo({
    required this.rpRegistKey,
    required this.rpKey,
    required this.rpKeyType,
    required this.serverMac,
    required this.serverNickname,
    this.apSsid,
    this.apBssid,
    this.apKey,
    required this.registeredAt,
  });
}
