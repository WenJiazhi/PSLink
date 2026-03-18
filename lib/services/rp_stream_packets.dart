import 'dart:math';
import 'dart:typed_data';

import '../models/ps_device.dart';
import 'rp_stream_crypto.dart';

class RpStreamHeaderType {
  static const int control = 0x00;
  static const int feedbackEvent = 0x01;
  static const int video = 0x02;
  static const int audio = 0x03;
  static const int handshake = 0x04;
  static const int congestion = 0x05;
  static const int feedbackState = 0x06;
  static const int rumbleEvent = 0x07;
  static const int clientInfo = 0x08;
  static const int padEvent = 0x09;
}

class RpStreamChunkType {
  static const int data = 0x00;
  static const int init = 0x01;
  static const int initAck = 0x02;
  static const int dataAck = 0x03;
  static const int cookie = 0x0A;
  static const int cookieAck = 0x0B;
}

class RpFeedbackType {
  static const int event = RpStreamHeaderType.feedbackEvent;
  static const int state = RpStreamHeaderType.feedbackState;
}

class RpFeedbackButton {
  static const int up = 0x80;
  static const int down = 0x81;
  static const int left = 0x82;
  static const int right = 0x83;
  static const int l1 = 0x84;
  static const int r1 = 0x85;
  static const int l2 = 0x86;
  static const int r2 = 0x87;
  static const int cross = 0x88;
  static const int circle = 0x89;
  static const int square = 0x8A;
  static const int triangle = 0x8B;
  static const int options = 0x8C;
  static const int share = 0x8D;
  static const int ps = 0x8E;
  static const int l3 = 0x8F;
  static const int r3 = 0x90;
  static const int touchpad = 0x91;
}

class RpControlPacket {
  RpControlPacket({
    required this.headerType,
    required this.tagRemote,
    required this.gmac,
    required this.keyPos,
    required this.chunkType,
    required this.flag,
    required this.payload,
    this.tag,
    this.tsn,
    this.channel,
    this.aRwnd,
    this.outboundStreams,
    this.inboundStreams,
    this.gapAckBlocksCount,
    this.dupTsnsCount,
    this.data,
  });

  static const int headerLength = 13;
  static const int _chunkHeaderLength = 4;
  static const int _aRwnd = 0x019000;
  static const int _outboundStreams = 0x64;
  static const int _inboundStreams = 0x64;

  final int headerType;
  final int tagRemote;
  final int gmac;
  final int keyPos;
  final int chunkType;
  final int flag;
  final Uint8List payload;
  final int? tag;
  final int? tsn;
  final int? channel;
  final int? aRwnd;
  final int? outboundStreams;
  final int? inboundStreams;
  final int? gapAckBlocksCount;
  final int? dupTsnsCount;
  final Uint8List? data;

  static bool isAv(Uint8List packet) {
    if (packet.isEmpty) {
      return false;
    }
    final type = packet[0] & 0x0F;
    return type == RpStreamHeaderType.video || type == RpStreamHeaderType.audio;
  }

  factory RpControlPacket.init({
    required int tag,
    required int tsn,
  }) {
    final payload = Uint8List(16);
    _writeUint32(payload, 0, tag);
    _writeUint32(payload, 4, _aRwnd);
    _writeUint16(payload, 8, _outboundStreams);
    _writeUint16(payload, 10, _inboundStreams);
    _writeUint32(payload, 12, tsn);
    return RpControlPacket(
      headerType: RpStreamHeaderType.control,
      tagRemote: 0,
      gmac: 0,
      keyPos: 0,
      chunkType: RpStreamChunkType.init,
      flag: 0,
      payload: payload,
      tag: tag,
      tsn: tsn,
    );
  }

  factory RpControlPacket.cookie({
    required int tagLocal,
    required int tagRemote,
    required Uint8List data,
  }) {
    return RpControlPacket(
      headerType: RpStreamHeaderType.control,
      tagRemote: tagRemote,
      gmac: 0,
      keyPos: 0,
      chunkType: RpStreamChunkType.cookie,
      flag: 0,
      payload: Uint8List.fromList(data),
      tag: tagLocal,
      data: Uint8List.fromList(data),
    );
  }

  factory RpControlPacket.data({
    required int tagRemote,
    required int tsn,
    required int flag,
    required int channel,
    required Uint8List data,
  }) {
    final payload = Uint8List(9 + data.length);
    _writeUint32(payload, 0, tsn);
    _writeUint16(payload, 4, channel);
    payload.setRange(9, payload.length, data);
    return RpControlPacket(
      headerType: RpStreamHeaderType.control,
      tagRemote: tagRemote,
      gmac: 0,
      keyPos: 0,
      chunkType: RpStreamChunkType.data,
      flag: flag,
      payload: payload,
      tsn: tsn,
      channel: channel,
      data: Uint8List.fromList(data),
    );
  }

  factory RpControlPacket.dataAck({
    required int tagLocal,
    required int tagRemote,
    required int tsn,
    int gapAckBlocksCount = 0,
    int dupTsnsCount = 0,
  }) {
    final payload = Uint8List(12);
    _writeUint32(payload, 0, tsn);
    _writeUint32(payload, 4, _aRwnd);
    _writeUint16(payload, 8, gapAckBlocksCount);
    _writeUint16(payload, 10, dupTsnsCount);
    return RpControlPacket(
      headerType: RpStreamHeaderType.control,
      tagRemote: tagRemote,
      gmac: 0,
      keyPos: 0,
      chunkType: RpStreamChunkType.dataAck,
      flag: 0,
      payload: payload,
      tag: tagLocal,
      tsn: tsn,
      gapAckBlocksCount: gapAckBlocksCount,
      dupTsnsCount: dupTsnsCount,
      aRwnd: _aRwnd,
    );
  }

  factory RpControlPacket.parse(Uint8List packet) {
    if (packet.length < headerLength + _chunkHeaderLength) {
      throw ArgumentError.value(packet, 'packet', 'Packet is too short.');
    }

    final headerType = packet[0];
    final tagRemote = _readUint32(packet, 1);
    final gmac = _readUint32(packet, 5);
    final keyPos = _readUint32(packet, 9);
    final chunkType = packet[13];
    final flag = packet[14];
    final chunkLength = _readUint16(packet, 15);
    final payloadEnd = min(packet.length, headerLength + chunkLength);
    final payload = Uint8List.fromList(packet.sublist(17, payloadEnd));

    int? tag;
    int? tsn;
    int? channel;
    int? aRwnd;
    int? outboundStreams;
    int? inboundStreams;
    int? gapAckBlocksCount;
    int? dupTsnsCount;
    Uint8List? data;

    switch (chunkType) {
      case RpStreamChunkType.data:
        tsn = _readUint32(payload, 0);
        channel = _readUint16(payload, 4);
        data = Uint8List.fromList(payload.sublist(9));
        break;
      case RpStreamChunkType.init:
        tag = _readUint32(payload, 0);
        tsn = _readUint32(payload, 4);
        break;
      case RpStreamChunkType.initAck:
        tag = _readUint32(payload, 0);
        aRwnd = _readUint32(payload, 4);
        outboundStreams = _readUint16(payload, 8);
        inboundStreams = _readUint16(payload, 10);
        tsn = _readUint32(payload, 12);
        data = Uint8List.fromList(payload.sublist(16));
        break;
      case RpStreamChunkType.dataAck:
        tsn = _readUint32(payload, 0);
        aRwnd = _readUint32(payload, 4);
        gapAckBlocksCount = _readUint16(payload, 8);
        dupTsnsCount = _readUint16(payload, 10);
        break;
      case RpStreamChunkType.cookie:
      case RpStreamChunkType.cookieAck:
        data = payload;
        break;
      default:
        break;
    }

    return RpControlPacket(
      headerType: headerType,
      tagRemote: tagRemote,
      gmac: gmac,
      keyPos: keyPos,
      chunkType: chunkType,
      flag: flag,
      payload: payload,
      tag: tag,
      tsn: tsn,
      channel: channel,
      aRwnd: aRwnd,
      outboundStreams: outboundStreams,
      inboundStreams: inboundStreams,
      gapAckBlocksCount: gapAckBlocksCount,
      dupTsnsCount: dupTsnsCount,
      data: data,
    );
  }

  Uint8List toBytes({
    RpStreamCipher? cipher,
    bool encryptPayload = false,
    int? advanceBy,
  }) {
    var payloadBytes = Uint8List.fromList(payload);
    final message = Uint8List(headerLength + _chunkHeaderLength + payloadBytes.length);

    message[0] = headerType;
    _writeUint32(message, 1, tagRemote);
    _writeUint32(message, 5, 0);
    _writeUint32(message, 9, 0);
    message[13] = chunkType;
    message[14] = flag;
    _writeUint16(message, 15, payloadBytes.length + _chunkHeaderLength);

    if (cipher != null && encryptPayload) {
      payloadBytes = cipher.encrypt(payloadBytes);
    }
    message.setRange(17, message.length, payloadBytes);

    if (cipher != null) {
      final currentKeyPos = cipher.keyPos;
      final gmacBytes = cipher.getGmac(message);
      _writeUint32(message, 9, currentKeyPos);
      _writeUint32(message, 5, _readUint32(gmacBytes, 0));
      cipher.advanceKeyPos(advanceBy ?? payload.length);
    }

    return message;
  }
}

class RpAvPacket {
  RpAvPacket._({
    required this.type,
    required this.hasNalu,
    required this.index,
    required this.frameIndex,
    required this.unitIndex,
    required this.frameLength,
    required this.frameLengthSrc,
    required this.frameLengthFec,
    required this.frameSizeAudio,
    required this.codec,
    required this.keyPos,
    required this.adaptiveStreamIndex,
    required Uint8List data,
  }) : _data = data;

  factory RpAvPacket.parse(
    Uint8List packet, {
    required PSDeviceType deviceType,
  }) {
    final type = packet[0] & 0x0F;
    final hasNalu = ((packet[0] >> 4) & 0x01) != 0;
    final index = _readUint16(packet, 1);
    final frameIndex = _readUint16(packet, 3);
    final dword2 = _readUint32(packet, 5);
    final codec = packet[9];
    final keyPos = _readUint32(packet, 14);

    var payloadOffset = 19;
    int? adaptiveStreamIndex;
    late final int unitIndex;
    late final int frameLength;
    late final int frameLengthSrc;
    late final int frameLengthFec;
    late final int frameSizeAudio;

    if (type == RpStreamHeaderType.video) {
      payloadOffset = 21;
      unitIndex = (dword2 >> 21) & 0x7FF;
      adaptiveStreamIndex = packet[20] >> 5;
      frameLength = ((dword2 >> 10) & 0x7FF) + 1;
      frameLengthFec = dword2 & 0x3FF;
      frameLengthSrc = frameLength - frameLengthFec;
      frameSizeAudio = 0;
    } else {
      unitIndex = (dword2 >> 24) & 0xFF;
      frameLength = ((dword2 >> 16) & 0xFF) + 1;
      final lowWord = dword2 & 0xFFFF;
      frameLengthFec = (lowWord >> 4) & 0x0F;
      frameLengthSrc = lowWord & 0x0F;
      frameSizeAudio = lowWord >> 8;
      if (deviceType == PSDeviceType.ps5) {
        payloadOffset += 1;
      }
    }

    if (hasNalu) {
      payloadOffset += 3;
    }

    return RpAvPacket._(
      type: type,
      hasNalu: hasNalu,
      index: index,
      frameIndex: frameIndex,
      unitIndex: unitIndex,
      frameLength: frameLength,
      frameLengthSrc: frameLengthSrc,
      frameLengthFec: frameLengthFec,
      frameSizeAudio: frameSizeAudio,
      codec: codec,
      keyPos: keyPos,
      adaptiveStreamIndex: adaptiveStreamIndex,
      data: Uint8List.fromList(packet.sublist(payloadOffset)),
    );
  }

  final int type;
  final bool hasNalu;
  final int index;
  final int frameIndex;
  final int unitIndex;
  final int frameLength;
  final int frameLengthSrc;
  final int frameLengthFec;
  final int frameSizeAudio;
  final int codec;
  final int keyPos;
  final int? adaptiveStreamIndex;
  Uint8List _data;

  Uint8List get data => _data;

  bool get isVideo => type == RpStreamHeaderType.video;

  bool get isAudio => type == RpStreamHeaderType.audio;

  bool get isLast => unitIndex == frameLength - 1;

  bool get isLastSrc => unitIndex == frameLengthSrc - 1;

  bool get isFec => unitIndex >= frameLengthSrc;

  void decrypt(RpStreamCipher cipher) {
    _data = cipher.decrypt(_data, keyPos);
  }
}

class RpFrameAssembler {
  RpFrameAssembler.video({required Uint8List header})
    : _header = Uint8List.fromList(header),
      _video = true;

  RpFrameAssembler.audio({required Uint8List header})
    : _header = Uint8List.fromList(header),
      _video = false;

  final Uint8List _header;
  final bool _video;

  int _currentFrameIndex = -1;
  int _expectedSourceUnits = 0;
  List<Uint8List?> _packets = <Uint8List?>[];
  int _received = 0;
  int _lost = 0;

  int get received => _received;
  int get lost => _lost;

  Uint8List? addPacket(RpAvPacket packet) {
    if (_currentFrameIndex != packet.frameIndex) {
      if (_currentFrameIndex >= 0 && !_isComplete()) {
        _lost += max(0, _expectedSourceUnits - _packets.whereType<Uint8List>().length);
      }
      _startFrame(packet);
    }

    if (packet.isFec || packet.unitIndex >= _expectedSourceUnits) {
      return null;
    }

    if (_packets[packet.unitIndex] != null) {
      return null;
    }

    _received++;
    _packets[packet.unitIndex] = _video
        ? Uint8List.fromList(packet.data)
        : Uint8List.fromList(
            packet.data.sublist(0, min(packet.frameSizeAudio, packet.data.length)),
          );

    if (!_isComplete()) {
      return null;
    }

    final frame = BytesBuilder(copy: false);
    if (_video) {
      frame.add(_header);
      for (final chunk in _packets.whereType<Uint8List>()) {
        frame.add(chunk.length > 2 ? chunk.sublist(2) : chunk);
      }
    } else {
      for (final chunk in _packets.whereType<Uint8List>()) {
        frame.add(chunk);
      }
    }

    return frame.takeBytes();
  }

  void _startFrame(RpAvPacket packet) {
    _currentFrameIndex = packet.frameIndex;
    _expectedSourceUnits = max(0, packet.frameLengthSrc);
    _packets = List<Uint8List?>.filled(_expectedSourceUnits, null);
  }

  bool _isComplete() {
    return _expectedSourceUnits > 0 &&
        _packets.whereType<Uint8List>().length == _expectedSourceUnits;
  }
}

Uint8List buildFeedbackStatePacket({
  required int sequence,
  required PSDeviceType deviceType,
  required int leftX,
  required int leftY,
  required int rightX,
  required int rightY,
  required RpStreamCipher cipher,
}) {
  const motionIdle = <int>[
    0xA0,
    0xFF,
    0x7F,
    0xFF,
    0x7F,
    0xFF,
    0x7F,
    0xFF,
    0x7F,
    0x99,
    0x99,
    0xFF,
    0x7F,
    0xFE,
    0xF7,
    0xEF,
    0x1F,
  ];

  final payloadLength = deviceType == PSDeviceType.ps5 ? 28 : 25;
  final packet = Uint8List(12 + payloadLength);
  packet[0] = RpFeedbackType.state;
  _writeUint16(packet, 1, sequence);
  _writeUint32(packet, 4, cipher.keyPos);
  _writeUint32(packet, 8, 0);
  packet.setRange(12, 12 + motionIdle.length, motionIdle);
  _writeInt16(packet, 29, leftX);
  _writeInt16(packet, 31, leftY);
  _writeInt16(packet, 33, rightX);
  _writeInt16(packet, 35, rightY);
  if (deviceType == PSDeviceType.ps5) {
    _writeInt16(packet, 25, 0);
    packet[27] = 1;
  }

  final payload = Uint8List.fromList(packet.sublist(12));
  final encryptedPayload = cipher.encrypt(payload);
  packet.setRange(12, packet.length, encryptedPayload);
  final gmac = cipher.getGmac(packet);
  _writeUint32(packet, 8, _readUint32(gmac, 0));
  cipher.advanceKeyPos(payload.length);
  return packet;
}

Uint8List buildFeedbackEventPacket({
  required int sequence,
  required int button,
  required bool active,
  required RpStreamCipher cipher,
}) {
  var buttonId = button;
  if (buttonId >= 0x8C && active) {
    buttonId += 32;
  }

  final payload = Uint8List.fromList([
    0x80,
    buttonId,
    active ? 0xFF : 0x00,
  ]);

  return _buildFeedbackPacket(
    type: RpFeedbackType.event,
    sequence: sequence,
    payload: payload,
    cipher: cipher,
    encryptPayload: true,
    advanceBy: payload.length,
  );
}

Uint8List buildCongestionPacket({
  required int received,
  required int lost,
  required RpStreamCipher cipher,
}) {
  final packet = Uint8List(15);
  packet[0] = RpStreamHeaderType.congestion;
  _writeUint16(packet, 3, received);
  _writeUint16(packet, 5, lost);
  _writeUint32(packet, 7, 0);
  _writeUint32(packet, 11, cipher.keyPos);
  final gmac = cipher.getGmac(packet);
  _writeUint32(packet, 7, _readUint32(gmac, 0));
  cipher.advanceKeyPos(packet.length);
  return packet;
}

Uint8List _buildFeedbackPacket({
  required int type,
  required int sequence,
  required Uint8List payload,
  required RpStreamCipher cipher,
  required bool encryptPayload,
  required int advanceBy,
}) {
  final packet = Uint8List(12 + payload.length);
  packet[0] = type;
  _writeUint16(packet, 1, sequence);
  _writeUint32(packet, 4, cipher.keyPos);
  _writeUint32(packet, 8, 0);

  final encodedPayload = encryptPayload ? cipher.encrypt(payload) : payload;
  packet.setRange(12, packet.length, encodedPayload);

  final gmac = cipher.getGmac(packet);
  _writeUint32(packet, 8, _readUint32(gmac, 0));
  cipher.advanceKeyPos(advanceBy);
  return packet;
}

int _readUint16(Uint8List bytes, int offset) {
  return ByteData.sublistView(bytes, offset, offset + 2).getUint16(0, Endian.big);
}

int _readUint32(Uint8List bytes, int offset) {
  return ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.big);
}

void _writeUint16(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes, offset, offset + 2).setUint16(0, value, Endian.big);
}

void _writeInt16(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes, offset, offset + 2).setInt16(0, value, Endian.big);
}

void _writeUint32(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes, offset, offset + 4).setUint32(0, value, Endian.big);
}
