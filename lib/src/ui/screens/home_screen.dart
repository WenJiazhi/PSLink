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

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Start discovery on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(l10n),
            Expanded(child: _buildHostList(l10n)),
            _buildBottomBar(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Simple logo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'PS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('appName'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    l10n.get('appSubtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Settings button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    CupertinoIcons.settings,
                    color: Colors.grey[700],
                    size: 22,
                  ),
                ),
              ),
            ],
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                CupertinoIcons.gamecontroller,
                size: 36,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isDiscovering
                  ? l10n.get('searchingPlayStation')
                  : l10n.get('noPlayStationFound'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.get('noPlayStationHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            if (isDiscovering) ...[
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
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

    return GestureDetector(
      onTap: () => _onHostTap(host),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Console icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF1A1A1A)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  host.isPS5
                      ? CupertinoIcons.desktopcomputer
                      : CupertinoIcons.gamecontroller,
                  size: 24,
                  color: isOnline ? Colors.white : Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(width: 14),

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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          host.isPS5 ? 'PS5' : 'PS4',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    host.hostAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (host.runningAppName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      host.runningAppName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Status and arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? const Color(0xFF4CAF50)
                            : isStandby
                                ? const Color(0xFFFF9800)
                                : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline
                          ? l10n.get('online')
                          : isStandby
                              ? l10n.get('standby')
                              : l10n.get('offline'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: Colors.grey[400],
                  size: 18,
                ),
              ],
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            children: [
              // Refresh button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (appState.isDiscovering) {
                      appState.stopDiscovery();
                    } else {
                      appState.startDiscovery();
                    }
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: appState.isDiscovering
                          ? Colors.grey[300]
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (appState.isDiscovering) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.get('searchingPlayStation').replaceAll('...', ''),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            CupertinoIcons.arrow_clockwise,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.get('searchDevices'),
                            style: const TextStyle(
                              fontSize: 15,
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
                onTap: () => _showManualAddDialog(l10n),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey[300]!,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.plus,
                    color: Colors.grey[700],
                    size: 22,
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

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: Text(l10n.get('addPlayStation')),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: ipController,
                  placeholder: l10n.get('ipAddressHint'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: !isSearching,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (isSearching) ...[
                  const SizedBox(height: 16),
                  const CupertinoActivityIndicator(),
                ],
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: isSearching ? null : () => Navigator.pop(dialogContext),
              child: Text(l10n.get('cancel')),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: isSearching
                  ? null
                  : () async {
                      final ip = ipController.text.trim();
                      if (ip.isEmpty) {
                        setDialogState(() {
                          errorMessage = l10n.get('ipAddress');
                        });
                        return;
                      }

                      // Validate IP format and range
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
              child: Text(isSearching
                  ? l10n.get('searching')
                  : l10n.get('add')),
            ),
          ],
        ),
      ),
    );
  }
}
