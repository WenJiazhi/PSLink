import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ps_host.dart';
import 'constants.dart';

/// PlayStation console discovery service
/// Uses UDP broadcast to find PS4/PS5 consoles on the local network
class DiscoveryService {
  RawDatagramSocket? _socket;
  StreamSubscription? _socketSubscription;
  final StreamController<PSHost> _hostController = StreamController<PSHost>.broadcast();
  final Map<String, PSHost> _discoveredHosts = {};
  Timer? _discoveryTimer;
  bool _isDiscovering = false;

  Stream<PSHost> get hostStream => _hostController.stream;
  List<PSHost> get discoveredHosts => _discoveredHosts.values.toList();
  bool get isDiscovering => _isDiscovering;

  /// Start discovery for PlayStation consoles
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    try {
      _isDiscovering = true;

      // Bind to a port in the valid discovery range for receiving responses
      // Try ports in range 9303-9319 until one succeeds
      _socket = await _bindToAvailablePort();

      _socket!.broadcastEnabled = true;

      _socketSubscription = _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleDiscoveryResponse(datagram);
          }
        }
      });

      // Send discovery packets periodically
      await _sendDiscoveryPackets();
      _discoveryTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _sendDiscoveryPackets(),
      );
    } catch (e) {
      _isDiscovering = false;
      rethrow;
    }
  }

  /// Stop discovery
  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
    _isDiscovering = false;
  }

  /// Bind to an available port in the discovery range (9303-9319)
  Future<RawDatagramSocket> _bindToAvailablePort() async {
    for (int port = PSConstants.discoveryPortLocalMin;
        port <= PSConstants.discoveryPortLocalMax;
        port++) {
      try {
        return await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          port,
          reuseAddress: true,
        );
      } catch (e) {
        debugPrint('Discovery: Port $port in use, trying next');
        if (port == PSConstants.discoveryPortLocalMax) {
          // All ports failed, try port 0 as last resort
          return await RawDatagramSocket.bind(
            InternetAddress.anyIPv4,
            0,
            reuseAddress: true,
          );
        }
      }
    }
    // Fallback (should not reach here)
    return await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
  }

  /// Get all broadcast addresses for the local network
  Future<List<InternetAddress>> _getBroadcastAddresses() async {
    final addresses = <InternetAddress>[];

    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Calculate broadcast address (assume /24 subnet)
            final ipBytes = addr.rawAddress;
            final broadcastBytes = Uint8List.fromList([
              ipBytes[0],
              ipBytes[1],
              ipBytes[2],
              255,
            ]);
            addresses.add(InternetAddress.fromRawAddress(broadcastBytes));
          }
        }
      }
    } catch (e) {
      debugPrint('Discovery: Failed to enumerate network interfaces: $e');
      // Fallback to general broadcast
    }

    // Always add general broadcast as fallback
    addresses.add(InternetAddress('255.255.255.255'));

    return addresses;
  }

  /// Send discovery broadcast packets to both PS4 and PS5
  Future<void> _sendDiscoveryPackets() async {
    if (_socket == null) return;

    final broadcastAddresses = await _getBroadcastAddresses();
    final ps4Packet = _buildSearchPacket(PSConstants.protocolVersionPS4);
    final ps5Packet = _buildSearchPacket(PSConstants.protocolVersionPS5);

    for (var addr in broadcastAddresses) {
      try {
        // Send PS4 discovery packet
        _socket!.send(ps4Packet, addr, PSConstants.discoveryPortPS4);
        // Send PS5 discovery packet
        _socket!.send(ps5Packet, addr, PSConstants.discoveryPortPS5);
      } catch (e) {
        debugPrint('Discovery: Failed to send packet to $addr: $e');
        // Ignore send errors for individual addresses
      }
    }
  }

  /// Probe a specific IP address for PlayStation console
  Future<PSHost?> probeHost(String ipAddress) async {
    RawDatagramSocket? probeSocket;

    try {
      probeSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final completer = Completer<PSHost?>();
      Timer? timeout;

      probeSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = probeSocket?.receive();
          if (datagram != null && !completer.isCompleted) {
            final host = _parseDiscoveryResponse(
              utf8.decode(datagram.data, allowMalformed: true),
              datagram.address,
            );
            if (host != null) {
              timeout?.cancel();
              completer.complete(host);
            }
          }
        }
      });

      final targetAddr = InternetAddress(ipAddress);
      final ps4Packet = _buildSearchPacket(PSConstants.protocolVersionPS4);
      final ps5Packet = _buildSearchPacket(PSConstants.protocolVersionPS5);

      // Send packets directly to the target IP
      probeSocket.send(ps4Packet, targetAddr, PSConstants.discoveryPortPS4);
      probeSocket.send(ps5Packet, targetAddr, PSConstants.discoveryPortPS5);

      // Also try with slight delay
      await Future.delayed(const Duration(milliseconds: 100));
      probeSocket.send(ps4Packet, targetAddr, PSConstants.discoveryPortPS4);
      probeSocket.send(ps5Packet, targetAddr, PSConstants.discoveryPortPS5);

      // Set timeout
      timeout = Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      return await completer.future;
    } catch (e) {
      return null;
    } finally {
      probeSocket?.close();
    }
  }

  /// Build a SRCH discovery packet
  Uint8List _buildSearchPacket(String protocolVersion) {
    final buffer = StringBuffer();
    buffer.write('${PSConstants.discoveryCmdSearch} * HTTP/1.1\r\n');
    buffer.write('device-discovery-protocol-version:$protocolVersion\r\n');
    buffer.write('\r\n');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Handle discovery response from a PlayStation console
  void _handleDiscoveryResponse(Datagram datagram) {
    try {
      final response = utf8.decode(datagram.data, allowMalformed: true);
      final host = _parseDiscoveryResponse(response, datagram.address);

      if (host != null) {
        _discoveredHosts[host.hostId] = host;
        _hostController.add(host);
      }
    } catch (e) {
      debugPrint('Discovery: Failed to parse response: $e');
      // Ignore parse errors
    }
  }

  /// Parse the discovery response into a PSHost object
  PSHost? _parseDiscoveryResponse(String response, InternetAddress address) {
    final lines = response.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return null;

    // Check if it's a valid HTTP 200 response
    // Format: "HTTP/1.1 200 Ok" or similar
    final statusLine = lines.first.trim();
    final statusMatch = RegExp(r'HTTP/\d\.\d\s+(\d+)').firstMatch(statusLine);
    if (statusMatch == null) return null;
    final statusCode = statusMatch.group(1);
    if (statusCode != '200') return null;

    final headers = <String, String>{};
    for (var line in lines.skip(1)) {
      line = line.trim();
      if (line.isEmpty) continue;

      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).toLowerCase().trim();
        final value = line.substring(colonIndex + 1).trim();
        headers[key] = value;
      }
    }

    final hostId = headers['host-id'];
    final hostName = headers['host-name'];
    final systemVersion = headers['system-version'];
    final hostType = headers['host-type'];

    if (hostId == null || hostName == null) return null;

    // PS5 detection: prefer host-type header, fallback to protocol version check
    bool isPS5 = false;
    if (hostType != null) {
      isPS5 = hostType.toLowerCase().contains('ps5');
    } else if (systemVersion != null) {
      // PS5 system versions typically don't start with 0
      // PS4 system versions often start with 0 (e.g., "09500001")
      isPS5 = !systemVersion.startsWith('0');
    }

    HostState state;
    final hostStatusCode = headers['status-code'] ?? headers['status'];
    switch (hostStatusCode) {
      case '200':
        state = HostState.ready;
        break;
      case '620':
        state = HostState.standby;
        break;
      default:
        state = HostState.ready; // Assume ready if we got a response
    }

    return PSHost(
      hostId: hostId,
      hostName: hostName,
      hostAddress: address.address,
      hostPort: PSConstants.sessionPort,
      systemVersion: systemVersion ?? 'Unknown',
      isPS5: isPS5,
      runningAppId: headers['running-app-titleid'],
      runningAppName: headers['running-app-name'],
      state: state,
      lastSeen: DateTime.now(),
    );
  }

  /// Add a manually discovered host
  void addHost(PSHost host) {
    _discoveredHosts[host.hostId] = host;
    _hostController.add(host);
  }

  /// Wake up a PlayStation console from standby
  Future<void> wakeup(PSHost host, String userCredential) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    try {
      final port = host.isPS5 ? PSConstants.discoveryPortPS5 : PSConstants.discoveryPortPS4;
      final version = host.isPS5 ? PSConstants.protocolVersionPS5 : PSConstants.protocolVersionPS4;

      final packet = _buildWakeupPacket(version, userCredential);

      // Send wakeup packet multiple times for reliability
      for (var i = 0; i < 5; i++) {
        socket.send(
          packet,
          InternetAddress(host.hostAddress),
          port,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      socket.close();
    }
  }

  /// Build a WAKEUP discovery packet
  Uint8List _buildWakeupPacket(String protocolVersion, String userCredential) {
    final buffer = StringBuffer();
    buffer.write('${PSConstants.discoveryCmdWakeup} * HTTP/1.1\r\n');
    buffer.write('device-discovery-protocol-version:$protocolVersion\r\n');
    buffer.write('user-credential:$userCredential\r\n');
    buffer.write('\r\n');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  void dispose() {
    stopDiscovery();
    _hostController.close();
  }
}
