import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'discovery_screen.dart';
import 'settings_screen.dart';
import 'package:pslink/src/models/ps_host.dart';
import 'package:pslink/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late Animation<double> _logoAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _logoAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Start discovery on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().startDiscovery();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1A1F38),
              Color(0xFF0D1B2A),
            ],
            stops: [0.0, 0.5, 1.0],
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
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Animated Logo with glow effect
          Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring effect
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 120 + (_pulseAnimation.value * 30),
                    height: 120 + (_pulseAnimation.value * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0072CE)
                            .withValues(alpha: 0.5 * (1 - _pulseAnimation.value)),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              // Logo
              ScaleTransition(
                scale: _logoAnimation,
                child: Container(
                  width: 110,
                  height: 110,
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
                        color: const Color(0xFF0072CE).withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'PS',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFF0072CE)],
            ).createShader(bounds),
            child: Text(
              l10n.get('appName'),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.get('appSubtitle'),
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostList() {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.hosts.isEmpty) {
          return _buildEmptyState(appState.isDiscovering, l10n);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: appState.hosts.length,
          itemBuilder: (context, index) {
            return _buildHostCard(appState.hosts[index], l10n);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDiscovering, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isDiscovering) ...[
            // Custom animated searching indicator
            Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final delay = index * 0.3;
                      final value = ((_pulseController.value + delay) % 1.0);
                      return Container(
                        width: 60 + (value * 80),
                        height: 60 + (value * 80),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0072CE)
                                .withValues(alpha: 0.6 * (1 - value)),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  );
                }),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0072CE).withValues(alpha: 0.2),
                  ),
                  child: const Icon(
                    CupertinoIcons.wifi,
                    size: 28,
                    color: Color(0xFF0072CE),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              l10n.get('searchingPlayStation'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ] else ...[
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                CupertinoIcons.gamecontroller,
                size: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.get('noPlayStationFound'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.get('noPlayStationHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHostCard(PSHost host, AppLocalizations l10n) {
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
            colors: isOnline
                ? [
                    const Color(0xFF1A2845),
                    const Color(0xFF0F172A),
                  ]
                : [
                    const Color(0xFF252835),
                    const Color(0xFF1A1D28),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOnline
                ? const Color(0xFF0072CE).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: isOnline ? 2 : 1,
          ),
          boxShadow: [
            if (isOnline)
              BoxShadow(
                color: const Color(0xFF0072CE).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Console icon with status indicator
            Stack(
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: isOnline
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0072CE), Color(0xFF00246B)],
                          )
                        : null,
                    color: isOnline ? null : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Icon(
                      host.isPS5
                          ? CupertinoIcons.device_desktop
                          : CupertinoIcons.game_controller,
                      size: 30,
                      color: isOnline ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
                // Status dot
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline
                          ? const Color(0xFF4CAF50)
                          : isStandby
                              ? const Color(0xFFFF9800)
                              : Colors.grey,
                      border: Border.all(
                        color: const Color(0xFF0F172A),
                        width: 2,
                      ),
                      boxShadow: isOnline
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),

            // Console info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          host.hostName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: host.isPS5
                                ? [const Color(0xFF00246B), const Color(0xFF003791)]
                                : [const Color(0xFF003791), const Color(0xFF0072CE)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          host.isPS5 ? 'PS5' : 'PS4',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    host.hostAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  if (host.runningAppName != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.play_fill,
                            size: 10,
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              host.runningAppName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status and arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isOnline
                      ? l10n.get('online')
                      : isStandby
                          ? l10n.get('standby')
                          : l10n.get('offline'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isOnline
                        ? const Color(0xFF4CAF50)
                        : isStandby
                            ? const Color(0xFFFF9800)
                            : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              // Refresh button
              _buildIconButton(
                icon: appState.isDiscovering
                    ? CupertinoIcons.stop_fill
                    : CupertinoIcons.arrow_clockwise,
                isActive: appState.isDiscovering,
                onPressed: () {
                  if (appState.isDiscovering) {
                    appState.stopDiscovery();
                  } else {
                    appState.startDiscovery();
                  }
                },
              ),
              const SizedBox(width: 16),

              // Manual add button
              _buildIconButton(
                icon: CupertinoIcons.plus,
                onPressed: () => _showManualAddDialog(l10n),
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
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0072CE), Color(0xFF00246B)],
                )
              : null,
          color: isActive ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(0xFF0072CE).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white70,
          size: 24,
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

  void _showManualAddDialog(AppLocalizations l10n) {
    final ipController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.get('addPlayStation')),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: ipController,
            placeholder: l10n.get('ipAddressHint'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add manual host
            },
            child: Text(l10n.get('add')),
          ),
        ],
      ),
    );
  }
}
