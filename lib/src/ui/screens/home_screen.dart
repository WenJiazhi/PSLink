import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'discovery_screen.dart';
import 'settings_screen.dart';
import 'package:pslink/src/models/ps_host.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _logoAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Start discovery on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().startDiscovery();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

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
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildHostList()),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Logo
          ScaleTransition(
            scale: _logoAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0072CE),
                    Color(0xFF00246B),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0072CE).withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'PS',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PSLink',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Remote Play for iOS',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostList() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.hosts.isEmpty) {
          return _buildEmptyState(appState.isDiscovering);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: appState.hosts.length,
          itemBuilder: (context, index) {
            return _buildHostCard(appState.hosts[index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDiscovering) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isDiscovering) ...[
            const CupertinoActivityIndicator(radius: 20),
            const SizedBox(height: 24),
            const Text(
              'Searching for PlayStation...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
          ] else ...[
            Icon(
              CupertinoIcons.gamecontroller,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No PlayStation Found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure your console is on\nand connected to the same network',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHostCard(PSHost host) {
    final isOnline = host.state == HostState.ready;
    final isStandby = host.state == HostState.standby;

    return GestureDetector(
      onTap: () => _onHostTap(host),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2D2D2D),
              const Color(0xFF1A1A1A),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOnline
                ? const Color(0xFF0072CE).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isOnline
                  ? const Color(0xFF0072CE).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Console icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF0072CE).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Icon(
                  host.isPS5
                      ? CupertinoIcons.device_desktop
                      : CupertinoIcons.game_controller,
                  size: 30,
                  color: isOnline ? const Color(0xFF0072CE) : Colors.white54,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Console info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        host.hostName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: host.isPS5
                              ? const Color(0xFF00246B)
                              : const Color(0xFF003791),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          host.isPS5 ? 'PS5' : 'PS4',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    host.hostAddress,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  if (host.runningAppName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.play_fill,
                          size: 10,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          host.runningAppName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Status indicator
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? const Color(0xFF4CAF50)
                        : isStandby
                            ? const Color(0xFFFF9800)
                            : Colors.grey,
                    boxShadow: isOnline
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOnline
                      ? 'Online'
                      : isStandby
                          ? 'Standby'
                          : 'Offline',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Refresh button
              _buildIconButton(
                icon: appState.isDiscovering
                    ? CupertinoIcons.stop_fill
                    : CupertinoIcons.refresh,
                onPressed: () {
                  if (appState.isDiscovering) {
                    appState.stopDiscovery();
                  } else {
                    appState.startDiscovery();
                  }
                },
              ),
              const SizedBox(width: 12),

              // Manual add button
              _buildIconButton(
                icon: CupertinoIcons.plus,
                onPressed: _showManualAddDialog,
              ),

              const Spacer(),

              // Settings button
              _buildIconButton(
                icon: CupertinoIcons.settings,
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          color: Colors.white70,
        ),
      ),
    );
  }

  void _onHostTap(PSHost host) {
    context.read<AppState>().selectHost(host);
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => DiscoveryScreen(host: host),
      ),
    );
  }

  void _showManualAddDialog() {
    final ipController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add PlayStation'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: ipController,
            placeholder: 'IP Address (e.g., 192.168.1.100)',
            keyboardType: TextInputType.number,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add manual host
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
