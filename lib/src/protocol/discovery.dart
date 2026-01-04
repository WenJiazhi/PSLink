import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../models/ps_host.dart';
import 'constants.dart';

/// PlayStation console discovery service
/// Uses UDP broadcast to find PS4/PS5 consoles on the local network
class DiscoveryService {
  RawDatagramSocket? _socket;
  final StreamController<PSHost> _hostController = StreamController<PSHost>.broadcast();
  final Map<String, PSHost> _discoveredHosts = {};
  Timer? _discoveryTimer;
  bool _isDiscovering = false;

  Stream<PSHost> get hostStream => _hostController.stream;
  List<PSHost> get discoveredHosts => _discoveredHosts.values.toList();
  bool get isDiscovering => _isDiscovering;

  /// Start discovery for PlayStation consoles
  Future<void> startDiscovery({bool searchPS5 = true}) async {
    if (_isDiscovering) return;

    try {
      _isDiscovering = true;
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      _socket!.broadcastEnabled = true;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleDiscoveryResponse(datagram);
          }
        }
      });

      // Send discovery packets periodically
      _sendDiscoveryPacket(searchPS5);
      _discoveryTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _sendDiscoveryPacket(searchPS5),
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
    _socket?.close();
    _socket = null;
    _isDiscovering = false;
  }

  /// Send discovery broadcast packets to both PS4 and PS5
  void _sendDiscoveryPacket(bool searchPS5) {
    if (_socket == null) return;

    // Always search for both PS4 and PS5
    final ps4Packet = _buildSearchPacket(PSConstants.protocolVersionPS4);
    final ps5Packet = _buildSearchPacket(PSConstants.protocolVersionPS5);

    try {
      // Send PS4 discovery packet
      _socket!.send(
        ps4Packet,
        InternetAddress('255.255.255.255'),
        PSConstants.discoveryPortPS4,
      );

      // Send PS5 discovery packet
      _socket!.send(
        ps5Packet,
        InternetAddress('255.255.255.255'),
        PSConstants.discoveryPortPS5,
      );
    } catch (e) {
      // Ignore send errors
    }
  }

  /// Build a SRCH discovery packet
  Uint8List _buildSearchPacket(String protocolVersion) {
    final buffer = StringBuffer();
    buffer.writeln('${PSConstants.discoveryCmdSearch} * HTTP/1.1');
    buffer.writeln('device-discovery-protocol-version:$protocolVersion');
    buffer.writeln();

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Handle discovery response from a PlayStation console
  void _handleDiscoveryResponse(Datagram datagram) {
    try {
      final response = utf8.decode(datagram.data);
      final host = _parseDiscoveryResponse(response, datagram.address);

      if (host != null) {
        _discoveredHosts[host.hostId] = host;
        _hostController.add(host);
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  /// Parse the discovery response into a PSHost object
  PSHost? _parseDiscoveryResponse(String response, InternetAddress address) {
    final lines = response.split('\n');
    if (lines.isEmpty) return null;

    // Check if it's a valid response
    final statusLine = lines.first.trim();
    if (!statusLine.contains('HTTP/1.1 200 Ok')) return null;

    final headers = <String, String>{};
    for (var line in lines.skip(1)) {
      line = line.trim();
      if (line.isEmpty) continue;

      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).toLowerCase();
        final value = line.substring(colonIndex + 1).trim();
        headers[key] = value;
      }
    }

    final hostId = headers['host-id'];
    final hostName = headers['host-name'];
    final systemVersion = headers['system-version'];
    final hostType = headers['host-type'];

    if (hostId == null || hostName == null) return null;

    final isPS5 = hostType?.toLowerCase().contains('ps5') ?? false;

    HostState state;
    switch (headers['status']?.toLowerCase()) {
      case '200':
        state = HostState.ready;
        break;
      case '620':
        state = HostState.standby;
        break;
      default:
        state = HostState.unknown;
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
    buffer.writeln('${PSConstants.discoveryCmdWakeup} * HTTP/1.1');
    buffer.writeln('device-discovery-protocol-version:$protocolVersion');
    buffer.writeln('user-credential:$userCredential');
    buffer.writeln();

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  void dispose() {
    stopDiscovery();
    _hostController.close();
  }
}
