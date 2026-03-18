import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../core/constants.dart';
import '../models/ps_device.dart';

class DiscoveryService {
  DiscoveryService({NetworkInfo? networkInfo})
      : _networkInfo = networkInfo ?? NetworkInfo();

  final Logger _logger = Logger();
  final NetworkInfo _networkInfo;

  RawDatagramSocket? _socket;
  StreamController<PSDevice>? _deviceController;
  Timer? _discoveryTimer;
  bool _isDiscovering = false;

  final Map<String, PSDevice> _discoveredDevices = {};

  List<PSDevice> get devices => _discoveredDevices.values.toList();

  bool get isDiscovering => _isDiscovering;

  Stream<PSDevice>? get deviceStream => _deviceController?.stream;

  Future<void> startDiscovery({
    Duration timeout = const Duration(seconds: 5),
    bool continuous = false,
  }) async {
    if (_isDiscovering) {
      _logger.w('Discovery already in progress');
      return;
    }

    _isDiscovering = true;
    _discoveredDevices.clear();
    _deviceController = StreamController<PSDevice>.broadcast();

    try {
      _socket = await _bindDiscoverySocket();
      _socket!.broadcastEnabled = true;
      _socket!.listen(_handleDatagram);

      await _sendDiscoveryRequests();

      if (continuous) {
        _discoveryTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => _sendDiscoveryRequests(),
        );
      } else {
        Timer(timeout, stopDiscovery);
      }

      _logger.i('Discovery started (continuous: $continuous)');
    } catch (e) {
      _logger.e('Failed to start discovery', error: e);
      _isDiscovering = false;
      rethrow;
    }
  }

  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _socket?.close();
    _socket = null;
    _deviceController?.close();
    _deviceController = null;
    _isDiscovering = false;
    _logger.i('Discovery stopped, found ${_discoveredDevices.length} devices');
  }

  Future<bool> wakeDevice(PSDevice device) async {
    final registKey = device.registKey;
    if (registKey == null || registKey.isEmpty) {
      _logger.e('Cannot wake device: not registered');
      return false;
    }

    try {
      final credential = formatWakeCredential(registKey);
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;

      final request = utf8.encode(buildWakeRequest(credential));
      final port = _ddpPortForDevice(device);

      for (var attempt = 0; attempt < 5; attempt++) {
        socket.send(request, InternetAddress(device.ipAddress), port);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      socket.close();
      _logger.i('Sent wake request to ${device.hostName}');
      return true;
    } catch (e) {
      _logger.e('Failed to wake device', error: e);
      return false;
    }
  }

  void dispose() {
    stopDiscovery();
  }

  @visibleForTesting
  String buildSearchRequest() {
    return _buildDdpMessage('SRCH');
  }

  @visibleForTesting
  String buildWakeRequest(String credential) {
    return _buildDdpMessage('WAKEUP', {
      'user-credential': credential,
      'client-type': 'vr',
      'auth-type': 'R',
      'model': 'w',
      'app-type': 'r',
    });
  }

  @visibleForTesting
  PSDevice? parseDiscoveryResponse(String ipAddress, String response) {
    return _parseDiscoveryResponse(ipAddress, response);
  }

  @visibleForTesting
  String formatWakeCredential(String registKey) {
    final asciiHex = utf8.decode(_decodeHexString(registKey));
    final credentialBytes = _decodeHexString(asciiHex);
    BigInt value = BigInt.zero;
    for (final byte in credentialBytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value.toString();
  }

  Future<RawDatagramSocket> _bindDiscoverySocket() async {
    try {
      return await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        PSConstants.discoveryClientPort,
      );
    } on SocketException catch (e) {
      _logger.w(
        'Failed to bind discovery port ${PSConstants.discoveryClientPort}, using random port',
        error: e,
      );
      return RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    }
  }

  Future<void> _sendDiscoveryRequests() async {
    if (_socket == null) {
      return;
    }

    final request = utf8.encode(buildSearchRequest());
    final targets = await _resolveDiscoveryTargets();

    for (final target in targets) {
      for (final port in PSConstants.discoveryPorts) {
        try {
          _socket!.send(request, InternetAddress(target), port);
        } catch (e) {
          _logger.w(
            'Failed to send discovery request to $target:$port',
            error: e,
          );
        }
      }
    }

    _logger.d('Sent discovery request to ${targets.join(', ')}');
  }

  Future<List<String>> _resolveDiscoveryTargets() async {
    final targets = <String>{PSConstants.broadcastAddress};

    try {
      final wifiBroadcast = await _networkInfo.getWifiBroadcast();
      if (_isValidIpv4(wifiBroadcast)) {
        targets.add(wifiBroadcast!);
      }

      final wifiIp = await _networkInfo.getWifiIP();
      final wifiSubmask = await _networkInfo.getWifiSubmask();
      final computed = _calculateBroadcastAddress(wifiIp, wifiSubmask);
      if (computed != null) {
        targets.add(computed);
      }
    } catch (e) {
      _logger.w('Failed to resolve directed broadcast address', error: e);
    }

    return targets.toList();
  }

  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }

    final datagram = _socket?.receive();
    if (datagram == null) {
      return;
    }

    try {
      final response = utf8.decode(datagram.data);
      final device = _parseDiscoveryResponse(
        datagram.address.address,
        response,
      );

      if (device != null && !_discoveredDevices.containsKey(device.hostId)) {
        _discoveredDevices[device.hostId] = device;
        _deviceController?.add(device);
        _logger.i('Discovered device: ${device.hostName} at ${device.ipAddress}');
      }
    } catch (e) {
      _logger.w('Failed to parse discovery response', error: e);
    }
  }

  PSDevice? _parseDiscoveryResponse(String ipAddress, String response) {
    final lines = response.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) {
      return null;
    }

    final statusLine = lines.first.trim();
    if (!statusLine.startsWith('HTTP/1.1')) {
      return null;
    }

    final headers = <String, String>{};
    final statusMatch = RegExp(r'^HTTP/1\.1\s+(\d+)(?:\s+(.*))?$')
        .firstMatch(statusLine);
    if (statusMatch != null) {
      headers['status-code'] = statusMatch.group(1)!;
      final statusText = statusMatch.group(2);
      if (statusText != null && statusText.isNotEmpty) {
        headers['status'] = statusText;
      }
    }

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        continue;
      }

      final colonIndex = line.indexOf(':');
      if (colonIndex <= 0) {
        continue;
      }

      final key = line.substring(0, colonIndex).trim().toLowerCase();
      final value = line.substring(colonIndex + 1).trim();
      headers[key] = value;
    }

    if (!headers.containsKey('host-id')) {
      return null;
    }

    return PSDevice.fromDiscoveryResponse(ipAddress, headers);
  }

  String _buildDdpMessage(String type, [Map<String, String>? fields]) {
    final buffer = StringBuffer()..write('$type * HTTP/1.1\n');
    fields?.forEach((key, value) {
      buffer.write('$key:$value\n');
    });
    buffer.write(
      'device-discovery-protocol-version:${PSConstants.ddpVersion}\n',
    );
    return buffer.toString();
  }

  int _ddpPortForDevice(PSDevice device) {
    return device.deviceType == PSDeviceType.ps5
        ? PSConstants.discoveryPortPS5
        : PSConstants.discoveryPortPS4;
  }

  bool _isValidIpv4(String? address) {
    if (address == null || address.isEmpty) {
      return false;
    }
    return InternetAddress.tryParse(address)?.type == InternetAddressType.IPv4;
  }

  String? _calculateBroadcastAddress(String? ipAddress, String? submask) {
    if (!_isValidIpv4(ipAddress) || !_isValidIpv4(submask)) {
      return null;
    }

    final ip = _ipv4ToInt(ipAddress!);
    final mask = _ipv4ToInt(submask!);
    final broadcast = ip | (~mask & 0xFFFFFFFF);
    return _intToIpv4(broadcast);
  }

  int _ipv4ToInt(String address) {
    final parts = address.split('.').map(int.parse).toList();
    return (parts[0] << 24) |
        (parts[1] << 16) |
        (parts[2] << 8) |
        parts[3];
  }

  String _intToIpv4(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ].join('.');
  }

  Uint8List _decodeHexString(String value) {
    if (value.length.isOdd) {
      throw const FormatException('Hex string must have an even length');
    }

    return Uint8List.fromList(
      List<int>.generate(
        value.length ~/ 2,
        (index) => int.parse(
          value.substring(index * 2, index * 2 + 2),
          radix: 16,
        ),
      ),
    );
  }
}
