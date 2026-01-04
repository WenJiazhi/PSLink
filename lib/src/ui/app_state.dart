import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pslink/src/models/ps_host.dart';
import 'package:pslink/src/protocol/discovery.dart';

/// App-wide state provider
class AppState extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final List<PSHost> _hosts = [];
  PSHost? _selectedHost;
  bool _isDiscovering = false;

  List<PSHost> get hosts => List.unmodifiable(_hosts);
  PSHost? get selectedHost => _selectedHost;
  bool get isDiscovering => _isDiscovering;
  DiscoveryService get discoveryService => _discoveryService;

  StreamSubscription? _hostSubscription;

  AppState() {
    _hostSubscription = _discoveryService.hostStream.listen((host) {
      final existingIndex = _hosts.indexWhere((h) => h.hostId == host.hostId);
      if (existingIndex >= 0) {
        _hosts[existingIndex] = host;
      } else {
        _hosts.add(host);
      }
      notifyListeners();
    });
  }

  Future<void> startDiscovery() async {
    _isDiscovering = true;
    notifyListeners();

    await _discoveryService.startDiscovery(searchPS5: true);
  }

  void stopDiscovery() {
    _discoveryService.stopDiscovery();
    _isDiscovering = false;
    notifyListeners();
  }

  void selectHost(PSHost? host) {
    _selectedHost = host;
    notifyListeners();
  }

  void updateHost(PSHost host) {
    final index = _hosts.indexWhere((h) => h.hostId == host.hostId);
    if (index >= 0) {
      _hosts[index] = host;
    } else {
      _hosts.add(host);
    }
    notifyListeners();
  }

  void removeHost(String hostId) {
    _hosts.removeWhere((h) => h.hostId == hostId);
    if (_selectedHost?.hostId == hostId) {
      _selectedHost = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _hostSubscription?.cancel();
    _discoveryService.dispose();
    super.dispose();
  }
}

/// App theme configuration
class AppTheme {
  static const Color primaryBlue = Color(0xFF0072CE);
  static const Color psBlue = Color(0xFF003791);
  static const Color psDarkBlue = Color(0xFF00246B);
  static const Color psLightBlue = Color(0xFF00439C);
  static const Color accentColor = Color(0xFF00BFFF);

  static const Color ps5White = Color(0xFFF5F5F5);
  static const Color ps5Black = Color(0xFF1A1A1A);
  static const Color ps5Gray = Color(0xFF2D2D2D);

  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFE53935);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: ps5Black,
        colorScheme: const ColorScheme.dark(
          primary: primaryBlue,
          secondary: accentColor,
          surface: ps5Gray,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: ps5Gray,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
      );

  static const LinearGradient psGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [psDarkBlue, psLightBlue],
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: ps5Gray,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
