import 'dart:convert';
import 'dart:typed_data';

enum TakionMessageType {
  big(0),
  bang(1),
  info(2),
  heartbeat(3),
  disconnect(8),
  streamInfo(13),
  streamInfoAck(14);

  const TakionMessageType(this.value);

  final int value;

  static TakionMessageType? fromValue(int value) {
    for (final type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}

class TakionBigPayload {
  const TakionBigPayload({
    required this.clientVersion,
    required this.sessionKey,
    required this.launchSpec,
    required this.encryptedKey,
    this.ecdhPublicKey,
    this.ecdhSignature,
  });

  final int clientVersion;
  final String sessionKey;
  final String launchSpec;
  final Uint8List encryptedKey;
  final Uint8List? ecdhPublicKey;
  final Uint8List? ecdhSignature;
}

class TakionBangPayload {
  const TakionBangPayload({
    required this.serverVersion,
    required this.token,
    required this.encryptedKeyAccepted,
    required this.versionAccepted,
    required this.sessionKey,
    this.serverVersionString,
    this.ecdhPublicKey,
    this.ecdhSignature,
  });

  final int serverVersion;
  final int token;
  final bool encryptedKeyAccepted;
  final bool versionAccepted;
  final String sessionKey;
  final String? serverVersionString;
  final Uint8List? ecdhPublicKey;
  final Uint8List? ecdhSignature;
}

class TakionResolutionPayload {
  const TakionResolutionPayload({
    required this.width,
    required this.height,
    required this.videoHeader,
  });

  final int width;
  final int height;
  final Uint8List videoHeader;
}

class TakionStreamInfoPayload {
  const TakionStreamInfoPayload({
    required this.resolutions,
    required this.audioHeader,
    this.startTimeout,
    this.afkTimeout,
    this.afkTimeoutDisconnect,
    this.congestionControlInterval,
  });

  final List<TakionResolutionPayload> resolutions;
  final Uint8List audioHeader;
  final int? startTimeout;
  final int? afkTimeout;
  final int? afkTimeoutDisconnect;
  final int? congestionControlInterval;
}

class TakionDisconnectPayload {
  const TakionDisconnectPayload({required this.reason});

  final String reason;
}

class TakionDecodedMessage {
  const TakionDecodedMessage({
    required this.type,
    this.bigPayload,
    this.bangPayload,
    this.streamInfoPayload,
    this.disconnectPayload,
  });

  final TakionMessageType type;
  final TakionBigPayload? bigPayload;
  final TakionBangPayload? bangPayload;
  final TakionStreamInfoPayload? streamInfoPayload;
  final TakionDisconnectPayload? disconnectPayload;
}

class TakionCodec {
  static Uint8List encodeBig(TakionBigPayload payload) {
    final bigPayload = _ProtoWriter()
      ..writeVarintField(1, payload.clientVersion)
      ..writeStringField(2, payload.sessionKey)
      ..writeStringField(3, payload.launchSpec)
      ..writeBytesField(4, payload.encryptedKey);

    if (payload.ecdhPublicKey != null) {
      bigPayload.writeBytesField(5, payload.ecdhPublicKey!);
    }
    if (payload.ecdhSignature != null) {
      bigPayload.writeBytesField(6, payload.ecdhSignature!);
    }

    final writer = _ProtoWriter()
      ..writeVarintField(1, TakionMessageType.big.value)
      ..writeMessageField(2, bigPayload.takeBytes());
    return writer.takeBytes();
  }

  static Uint8List encodeHeartbeat() {
    final writer = _ProtoWriter()
      ..writeVarintField(1, TakionMessageType.heartbeat.value);
    return writer.takeBytes();
  }

  static Uint8List encodeStreamInfoAck() {
    final writer = _ProtoWriter()
      ..writeVarintField(1, TakionMessageType.streamInfoAck.value);
    return writer.takeBytes();
  }

  static Uint8List encodeDisconnect(String reason) {
    final disconnectPayload = _ProtoWriter()..writeStringField(1, reason);
    final writer = _ProtoWriter()
      ..writeVarintField(1, TakionMessageType.disconnect.value)
      ..writeMessageField(10, disconnectPayload.takeBytes());
    return writer.takeBytes();
  }

  static TakionDecodedMessage? decode(Uint8List data) {
    final reader = _ProtoReader(data);
    TakionMessageType? type;
    TakionBigPayload? bigPayload;
    TakionBangPayload? bangPayload;
    TakionStreamInfoPayload? streamInfoPayload;
    TakionDisconnectPayload? disconnectPayload;

    while (!reader.isDone) {
      final field = reader.readField();
      switch (field.number) {
        case 1:
          if (field.wireType == _WireType.varint) {
            type = TakionMessageType.fromValue(field.asInt());
          }
          break;
        case 2:
          if (field.wireType == _WireType.lengthDelimited) {
            bigPayload = _decodeBigPayload(field.asBytes());
          }
          break;
        case 3:
          if (field.wireType == _WireType.lengthDelimited) {
            bangPayload = _decodeBangPayload(field.asBytes());
          }
          break;
        case 10:
          if (field.wireType == _WireType.lengthDelimited) {
            disconnectPayload = _decodeDisconnectPayload(field.asBytes());
          }
          break;
        case 15:
          if (field.wireType == _WireType.lengthDelimited) {
            streamInfoPayload = _decodeStreamInfoPayload(field.asBytes());
          }
          break;
        default:
          break;
      }
    }

    if (type == null) {
      return null;
    }

    return TakionDecodedMessage(
      type: type,
      bigPayload: bigPayload,
      bangPayload: bangPayload,
      streamInfoPayload: streamInfoPayload,
      disconnectPayload: disconnectPayload,
    );
  }

  static TakionBigPayload _decodeBigPayload(Uint8List data) {
    final reader = _ProtoReader(data);
    var clientVersion = 0;
    var sessionKey = '';
    var launchSpec = '';
    var encryptedKey = Uint8List(0);
    Uint8List? ecdhPublicKey;
    Uint8List? ecdhSignature;

    while (!reader.isDone) {
      final field = reader.readField();
      switch (field.number) {
        case 1:
          clientVersion = field.asInt();
          break;
        case 2:
          sessionKey = field.asString();
          break;
        case 3:
          launchSpec = field.asString();
          break;
        case 4:
          encryptedKey = field.asBytes();
          break;
        case 5:
          ecdhPublicKey = field.asBytes();
          break;
        case 6:
          ecdhSignature = field.asBytes();
          break;
        default:
          break;
      }
    }

    return TakionBigPayload(
      clientVersion: clientVersion,
      sessionKey: sessionKey,
      launchSpec: launchSpec,
      encryptedKey: encryptedKey,
      ecdhPublicKey: ecdhPublicKey,
      ecdhSignature: ecdhSignature,
    );
  }

  static TakionBangPayload _decodeBangPayload(Uint8List data) {
    final reader = _ProtoReader(data);
    var serverVersion = 0;
    var token = 0;
    var encryptedKeyAccepted = false;
    var versionAccepted = false;
    var sessionKey = '';
    String? serverVersionString;
    Uint8List? ecdhPublicKey;
    Uint8List? ecdhSignature;

    while (!reader.isDone) {
      final field = reader.readField();
      switch (field.number) {
        case 1:
          serverVersion = field.asInt();
          break;
        case 2:
          token = field.asInt();
          break;
        case 3:
          encryptedKeyAccepted = field.asBool();
          break;
        case 4:
          versionAccepted = field.asBool();
          break;
        case 5:
          sessionKey = field.asString();
          break;
        case 7:
          serverVersionString = field.asString();
          break;
        case 8:
          ecdhPublicKey = field.asBytes();
          break;
        case 9:
          ecdhSignature = field.asBytes();
          break;
        default:
          break;
      }
    }

    return TakionBangPayload(
      serverVersion: serverVersion,
      token: token,
      encryptedKeyAccepted: encryptedKeyAccepted,
      versionAccepted: versionAccepted,
      sessionKey: sessionKey,
      serverVersionString: serverVersionString,
      ecdhPublicKey: ecdhPublicKey,
      ecdhSignature: ecdhSignature,
    );
  }

  static TakionStreamInfoPayload _decodeStreamInfoPayload(Uint8List data) {
    final reader = _ProtoReader(data);
    final resolutions = <TakionResolutionPayload>[];
    var audioHeader = Uint8List(0);
    int? startTimeout;
    int? afkTimeout;
    int? afkTimeoutDisconnect;
    int? congestionControlInterval;

    while (!reader.isDone) {
      final field = reader.readField();
      switch (field.number) {
        case 1:
          resolutions.add(_decodeResolutionPayload(field.asBytes()));
          break;
        case 2:
          audioHeader = field.asBytes();
          break;
        case 3:
          startTimeout = field.asInt();
          break;
        case 4:
          afkTimeout = field.asInt();
          break;
        case 5:
          afkTimeoutDisconnect = field.asInt();
          break;
        case 6:
          congestionControlInterval = field.asInt();
          break;
        default:
          break;
      }
    }

    return TakionStreamInfoPayload(
      resolutions: resolutions,
      audioHeader: audioHeader,
      startTimeout: startTimeout,
      afkTimeout: afkTimeout,
      afkTimeoutDisconnect: afkTimeoutDisconnect,
      congestionControlInterval: congestionControlInterval,
    );
  }

  static TakionResolutionPayload _decodeResolutionPayload(Uint8List data) {
    final reader = _ProtoReader(data);
    var width = 0;
    var height = 0;
    var videoHeader = Uint8List(0);

    while (!reader.isDone) {
      final field = reader.readField();
      switch (field.number) {
        case 1:
          width = field.asInt();
          break;
        case 2:
          height = field.asInt();
          break;
        case 3:
          videoHeader = field.asBytes();
          break;
        default:
          break;
      }
    }

    return TakionResolutionPayload(
      width: width,
      height: height,
      videoHeader: videoHeader,
    );
  }

  static TakionDisconnectPayload _decodeDisconnectPayload(Uint8List data) {
    final reader = _ProtoReader(data);
    var reason = '';

    while (!reader.isDone) {
      final field = reader.readField();
      if (field.number == 1) {
        reason = field.asString();
      }
    }

    return TakionDisconnectPayload(reason: reason);
  }
}

enum _WireType {
  varint(0),
  fixed64(1),
  lengthDelimited(2),
  fixed32(5);

  const _WireType(this.value);

  final int value;

  static _WireType fromValue(int value) {
    return _WireType.values.firstWhere(
      (wireType) => wireType.value == value,
      orElse: () => throw StateError('Unsupported wire type: $value'),
    );
  }
}

class _ProtoWriter {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  void writeVarintField(int fieldNumber, int value) {
    _buffer
      ..add(_encodeVarint((fieldNumber << 3) | _WireType.varint.value))
      ..add(_encodeVarint(value));
  }

  void writeStringField(int fieldNumber, String value) {
    writeBytesField(fieldNumber, Uint8List.fromList(utf8.encode(value)));
  }

  void writeBytesField(int fieldNumber, Uint8List value) {
    _buffer
      ..add(_encodeVarint((fieldNumber << 3) | _WireType.lengthDelimited.value))
      ..add(_encodeVarint(value.length))
      ..add(value);
  }

  void writeMessageField(int fieldNumber, Uint8List message) {
    writeBytesField(fieldNumber, message);
  }

  Uint8List takeBytes() {
    return _buffer.takeBytes();
  }

  Uint8List _encodeVarint(int value) {
    final bytes = <int>[];
    var current = value;
    while (true) {
      if ((current & ~0x7F) == 0) {
        bytes.add(current);
        break;
      }
      bytes.add((current & 0x7F) | 0x80);
      current >>= 7;
    }
    return Uint8List.fromList(bytes);
  }
}

class _ProtoReader {
  _ProtoReader(this._data);

  final Uint8List _data;
  int _offset = 0;

  bool get isDone => _offset >= _data.length;

  _ProtoField readField() {
    final key = _readVarint();
    final number = key >> 3;
    final wireType = _WireType.fromValue(key & 0x07);

    switch (wireType) {
      case _WireType.varint:
        return _ProtoField(
          number: number,
          wireType: wireType,
          intValue: _readVarint(),
        );
      case _WireType.lengthDelimited:
        final length = _readVarint();
        final value = Uint8List.fromList(
          _data.sublist(_offset, _offset + length),
        );
        _offset += length;
        return _ProtoField(
          number: number,
          wireType: wireType,
          bytesValue: value,
        );
      case _WireType.fixed64:
        final value = Uint8List.fromList(_data.sublist(_offset, _offset + 8));
        _offset += 8;
        return _ProtoField(
          number: number,
          wireType: wireType,
          bytesValue: value,
        );
      case _WireType.fixed32:
        final value = Uint8List.fromList(_data.sublist(_offset, _offset + 4));
        _offset += 4;
        return _ProtoField(
          number: number,
          wireType: wireType,
          bytesValue: value,
        );
    }
  }

  int _readVarint() {
    var shift = 0;
    var result = 0;

    while (true) {
      final byte = _data[_offset++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) {
        return result;
      }
      shift += 7;
    }
  }
}

class _ProtoField {
  const _ProtoField({
    required this.number,
    required this.wireType,
    this.intValue,
    this.bytesValue,
  });

  final int number;
  final _WireType wireType;
  final int? intValue;
  final Uint8List? bytesValue;

  int asInt() => intValue ?? 0;
  bool asBool() => (intValue ?? 0) != 0;
  Uint8List asBytes() => bytesValue ?? Uint8List(0);
  String asString() => utf8.decode(asBytes(), allowMalformed: true);
}
