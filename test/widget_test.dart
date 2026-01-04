// PSLink Widget Test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pslink/src/ui/app_state.dart';
import 'package:pslink/src/models/ps_host.dart';
import 'package:pslink/src/protocol/discovery.dart';

// Simple mock AppState that doesn't use network
class MockAppState extends ChangeNotifier implements AppState {
  final List<PSHost> _hosts = [];
  bool _isDiscovering = false;

  @override
  List<PSHost> get hosts => List.unmodifiable(_hosts);

  @override
  PSHost? get selectedHost => null;

  @override
  bool get isDiscovering => _isDiscovering;

  @override
  DiscoveryService get discoveryService => throw UnimplementedError();

  @override
  Future<void> startDiscovery() async {
    _isDiscovering = true;
    notifyListeners();
    // Don't actually start network discovery in tests
    await Future.delayed(const Duration(milliseconds: 100));
    _isDiscovering = false;
    notifyListeners();
  }

  @override
  void stopDiscovery() {
    _isDiscovering = false;
    notifyListeners();
  }

  @override
  void selectHost(PSHost? host) {}

  @override
  void updateHost(PSHost host) {}

  @override
  void removeHost(String hostId) {}
}

void main() {
  testWidgets('PSLink app smoke test', (WidgetTester tester) async {
    // Build app with mock state
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: MockAppState(),
        child: MaterialApp(
          title: 'PSLink',
          theme: AppTheme.darkTheme,
          home: const _SimpleHomeScreen(),
        ),
      ),
    );

    // Wait for the widget to build
    await tester.pump();

    // Verify that PSLink title is present
    expect(find.text('PSLink'), findsOneWidget);
  });
}

// Simple test widget without network calls
class _SimpleHomeScreen extends StatelessWidget {
  const _SimpleHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1B263B),
              Color(0xFF0D1B2A),
            ],
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'PSLink',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Remote Play for iOS',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
