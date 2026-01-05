import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
  late AnimationController _pulseController;
  late AnimationController _gradientController;
  
  // PlayStation brand colors
  static const Color psBlue = Color(0xFF003791);
  static const Color psDarkBlue = Color(0xFF00439C);
  static const Color psBlack = Color(0xFF0D0D0D);
  static const Color psGray = Color(0xFF1A1A2E);
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().startDiscovery();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: psBlack,
        body: Stack(
          children: [
            // Animated gradient background
            _buildAnimatedBackground(),
            // Main content
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(l10n),
                  Expanded(child: _buildHostList(l10n)),
                  _buildBottomBar(l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                psBlack,
                Color.lerp(psBlack, psBlue.withOpacity(0.3), _gradientController.value)!,
                psGray,
              ],
              stops: [0.0, 0.5 + (_gradientController.value * 0.2), 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Row(
        children: [
          // Animated PS Logo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [psBlue, psDarkBlue],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: psBlue.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'PS',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('appName'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.get('appSubtitle'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          // Settings button with glass effect
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                CupertinoIcons.gear,
                color: Colors.white.withOpacity(0.8),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostList(AppLocalizations l10n) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.hosts.isEmpty) {
          return _buildEmptyState(appState.isDiscovering, l10n);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated controller icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: psGray,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: psBlue.withOpacity(0.2 + (_pulseController.value * 0.2)),
                        blurRadius: 30 + (_pulseController.value * 20),
                        spreadRadius: _pulseController.value * 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    CupertinoIcons.gamecontroller_fill,
                    size: 44,
                    color: Colors.white.withOpacity(0.6),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              isDiscovering
                  ? l10n.get('searchingPlayStation')
                  : l10n.get('noPlayStationFound'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.get('noPlayStationHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.5),
                height: 1.5,
              ),
            ),
            if (isDiscovering) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(psBlue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHostCard(PSHost host, AppLocalizations l10n) {
    final isOnline = host.state == HostState.ready;
    final isStandby = host.state == HostState.standby;
    
    final statusColor = isOnline 
        ? const Color(0xFF00D26A) 
        : isStandby 
            ? const Color(0xFFFFB800) 
            : Colors.grey;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _onHostTap(host);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              psGray,
              psGray.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(isOnline ? 0.15 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Console icon with status glow
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isOnline ? psBlue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isOnline ? [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: Center(
                    child: Icon(
                      host.isPS5
                          ? CupertinoIcons.desktopcomputer
                          : CupertinoIcons.gamecontroller_fill,
                      size: 28,
                      color: isOnline ? Colors.white : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                // Status dot
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: psGray, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: psBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          host.isPS5 ? 'PS5' : 'PS4',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  if (host.runningAppName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.play_circle_fill,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            host.runningAppName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Arrow
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.chevron_right,
                color: Colors.white.withOpacity(0.4),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Row(
            children: [
              // Search/Refresh button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (appState.isDiscovering) {
                      appState.stopDiscovery();
                    } else {
                      appState.startDiscovery();
                    }
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: appState.isDiscovering
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [psBlue, psDarkBlue],
                            ),
                      color: appState.isDiscovering ? psGray : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: appState.isDiscovering ? null : [
                        BoxShadow(
                          color: psBlue.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (appState.isDiscovering) ...[
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.get('searchingPlayStation').replaceAll('...', ''),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            CupertinoIcons.arrow_clockwise,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.get('searchDevices'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Manual add button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showManualAddDialog(l10n);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: psGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.plus,
                    color: Colors.white.withOpacity(0.8),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    bool isSearching = false;
    String? errorMessage;

    showCupertinoModalPopup(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: psGray,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.get('addPlayStation'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              CupertinoTextField(
                controller: ipController,
                placeholder: l10n.get('ipAddressHint'),
                placeholderStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: !isSearching,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        color: Colors.red[400],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red[400],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: isSearching ? null : () => Navigator.pop(dialogContext),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            l10n.get('cancel'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: isSearching
                          ? null
                          : () async {
                              final ip = ipController.text.trim();
                              if (ip.isEmpty) {
                                setDialogState(() {
                                  errorMessage = l10n.get('ipAddress');
                                });
                                return;
                              }

                              bool isValidIp(String ip) {
                                final parts = ip.split('.');
                                if (parts.length != 4) return false;
                                for (final part in parts) {
                                  final num = int.tryParse(part);
                                  if (num == null || num < 0 || num > 255) return false;
                                }
                                return true;
                              }

                              if (!isValidIp(ip)) {
                                setDialogState(() {
                                  errorMessage = l10n.get('invalidIpFormat');
                                });
                                return;
                              }

                              setDialogState(() {
                                isSearching = true;
                                errorMessage = null;
                              });

                              try {
                                final appState = this.context.read<AppState>();
                                final host = await appState.discoveryService.probeHost(ip);

                                if (host != null) {
                                  appState.updateHost(host);
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                } else {
                                  setDialogState(() {
                                    isSearching = false;
                                    errorMessage = l10n.get('noPlayStationAtAddress');
                                  });
                                }
                              } catch (e) {
                                setDialogState(() {
                                  isSearching = false;
                                  errorMessage = '${l10n.get('searchFailedPrefix')}: $e';
                                });
                              }
                            },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [psBlue, psDarkBlue],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  l10n.get('add'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    ).then((_) => ipController.dispose());
  }
}
