// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ps_host.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PSHostAdapter extends TypeAdapter<PSHost> {
  @override
  final int typeId = 0;

  @override
  PSHost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PSHost(
      hostId: fields[0] as String,
      hostName: fields[1] as String,
      hostAddress: fields[2] as String,
      hostPort: fields[3] as int,
      systemVersion: fields[4] as String,
      isPS5: fields[5] as bool,
      runningAppId: fields[6] as String?,
      runningAppName: fields[7] as String?,
      state: fields[8] as HostState,
      lastSeen: fields[9] as DateTime,
      registrationInfo: fields[10] as RegisteredHostInfo?,
    );
  }

  @override
  void write(BinaryWriter writer, PSHost obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.hostId)
      ..writeByte(1)
      ..write(obj.hostName)
      ..writeByte(2)
      ..write(obj.hostAddress)
      ..writeByte(3)
      ..write(obj.hostPort)
      ..writeByte(4)
      ..write(obj.systemVersion)
      ..writeByte(5)
      ..write(obj.isPS5)
      ..writeByte(6)
      ..write(obj.runningAppId)
      ..writeByte(7)
      ..write(obj.runningAppName)
      ..writeByte(8)
      ..write(obj.state)
      ..writeByte(9)
      ..write(obj.lastSeen)
      ..writeByte(10)
      ..write(obj.registrationInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PSHostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HostStateAdapter extends TypeAdapter<HostState> {
  @override
  final int typeId = 1;

  @override
  HostState read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HostState.ready;
      case 1:
        return HostState.standby;
      case 2:
        return HostState.unknown;
      default:
        return HostState.unknown;
    }
  }

  @override
  void write(BinaryWriter writer, HostState obj) {
    switch (obj) {
      case HostState.ready:
        writer.writeByte(0);
        break;
      case HostState.standby:
        writer.writeByte(1);
        break;
      case HostState.unknown:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RegisteredHostInfoAdapter extends TypeAdapter<RegisteredHostInfo> {
  @override
  final int typeId = 2;

  @override
  RegisteredHostInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegisteredHostInfo(
      rpRegistKey: fields[0] as String,
      rpKey: (fields[1] as List).cast<int>(),
      rpKeyType: fields[2] as int,
      serverMac: (fields[3] as List).cast<int>(),
      serverNickname: fields[4] as String,
      apSsid: fields[5] as String?,
      apBssid: fields[6] as String?,
      apKey: fields[7] as String?,
      registeredAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RegisteredHostInfo obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.rpRegistKey)
      ..writeByte(1)
      ..write(obj.rpKey)
      ..writeByte(2)
      ..write(obj.rpKeyType)
      ..writeByte(3)
      ..write(obj.serverMac)
      ..writeByte(4)
      ..write(obj.serverNickname)
      ..writeByte(5)
      ..write(obj.apSsid)
      ..writeByte(6)
      ..write(obj.apBssid)
      ..writeByte(7)
      ..write(obj.apKey)
      ..writeByte(8)
      ..write(obj.registeredAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisteredHostInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
