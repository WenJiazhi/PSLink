import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import 'package:pslink/src/models/ps_host.dart';
import 'package:pslink/src/protocol/registration.dart';
import 'package:pslink/src/services/psn_account_storage.dart';
import 'package:pslink/l10n/app_localizations.dart';
import 'streaming_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  final PSHost host;

  const DiscoveryScreen({super.key, required this.host});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _isConnecting = false;
  bool _isRegistering = false;
  String? _statusMessage;
  final _pinController = TextEditingController();
  final _psnIdController = TextEditingController();
  final _psnAccountIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedPsnAccountId();
  }

  Future<void> _loadSavedPsnAccountId() async {
    final saved = await PSNAccountStorage.getPSNAccountId();
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _psnAccountIdController.text = saved;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _psnIdController.dispose();
    _psnAccountIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(l10n),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  children: [
                    _buildHostInfo(l10n),
                    const SizedBox(height: 24),
                    if (widget.host.isRegistered)
                      _buildConnectSection(l10n)
                    else
                      _buildRegisterSection(l10n),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
                CupertinoIcons.back,
                color: Colors.grey[700],
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.host.hostName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostInfo(AppLocalizations l10n) {
    final isOnline = widget.host.state == HostState.ready;
    final isStandby = widget.host.state == HostState.standby;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          // Console icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF1A1A1A) : Colors.grey[300],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Icon(
                widget.host.isPS5
                    ? CupertinoIcons.desktopcomputer
                    : CupertinoIcons.gamecontroller,
                size: 32,
                color: isOnline ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Console name
          Text(
            widget.host.hostName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),

          // Console type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.host.isPS5 ? 'PlayStation 5' : 'PlayStation 4',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? const Color(0xFF4CAF50)
                      : isStandby
                          ? const Color(0xFFFF9800)
                          : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOnline
                    ? l10n.get('online')
                    : isStandby
                        ? l10n.get('standby')
                        : l10n.get('offline'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Details
          _buildInfoRow(l10n.get('ipAddressLabel'), widget.host.hostAddress),
          _buildInfoRow(l10n.get('systemVersion'), widget.host.systemVersion),
          if (widget.host.runningAppName != null)
            _buildInfoRow(l10n.get('nowPlaying'), widget.host.runningAppName!),
          _buildInfoRow(
            l10n.get('registration'),
            widget.host.isRegistered
                ? l10n.get('registered')
                : l10n.get('notRegistered'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectSection(AppLocalizations l10n) {
    return Column(
      children: [
        if (_statusMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                if (_isConnecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                    ),
                  )
                else
                  Icon(
                    CupertinoIcons.info_circle,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Connect button
        _buildActionButton(
          icon: CupertinoIcons.play_fill,
          label: l10n.get('startRemotePlay'),
          onPressed: _isConnecting ? null : () => _connect(l10n),
          isPrimary: true,
        ),
        const SizedBox(height: 12),

        // Wake up button (if standby)
        if (widget.host.state == HostState.standby) ...[
          _buildActionButton(
            icon: CupertinoIcons.power,
            label: l10n.get('wakeUpConsole'),
            onPressed: _isConnecting ? null : () => _wakeUp(l10n),
          ),
          const SizedBox(height: 12),
        ],

        // Unregister button
        _buildActionButton(
          icon: CupertinoIcons.trash,
          label: l10n.get('unregister'),
          onPressed: _isConnecting ? null : () => _unregister(l10n),
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildRegisterSection(AppLocalizations l10n) {
    final consoleName = widget.host.isPS5 ? 'PS5' : 'PS4';

    return Column(
      children: [
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle_fill,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.get('registrationRequired'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                l10n.getFormatted('registrationStep1', {'console': consoleName}),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.get('registrationStep2'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.get('registrationStep3'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // PSN ID field
        _buildTextField(
          controller: _psnIdController,
          placeholder: l10n.get('psnId'),
          icon: CupertinoIcons.person,
        ),
        const SizedBox(height: 12),

        // PSN Account ID field with help link
        _buildPSNAccountIdField(l10n),
        const SizedBox(height: 12),

        // PIN field
        _buildTextField(
          controller: _pinController,
          placeholder: l10n.get('pinCode'),
          icon: CupertinoIcons.lock,
          keyboardType: TextInputType.number,
          maxLength: 8,
        ),
        const SizedBox(height: 20),

        if (_statusMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isRegistering
                  ? Colors.white
                  : const Color(0xFFFFF3F3),
              borderRadius: BorderRadius.circular(12),
              border: _isRegistering
                  ? null
                  : Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              children: [
                if (_isRegistering)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                    ),
                  )
                else
                  const Icon(
                    CupertinoIcons.exclamationmark_circle,
                    color: Color(0xFFE53935),
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _isRegistering
                          ? Colors.grey[700]
                          : const Color(0xFFE53935),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Register button
        _buildActionButton(
          icon: CupertinoIcons.link,
          label: l10n.get('registerDevice'),
          onPressed: _isRegistering ? null : () => _register(l10n),
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.grey[500]),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPSNAccountIdField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _psnAccountIdController,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: l10n.get('psnAccountId'),
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(CupertinoIcons.number, color: Colors.grey[500]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.get('psnAccountIdHint'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            GestureDetector(
              onTap: () => _showAccountIdHelp(l10n),
              child: Text(
                l10n.get('psnAccountIdHelp'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0072CE),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showAccountIdHelp(AppLocalizations l10n) async {
    final url = Uri.parse(l10n.get('psnAccountIdHelpUrl'));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary && onPressed != null
              ? const Color(0xFF1A1A1A)
              : isDestructive
                  ? const Color(0xFFFFF3F3)
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: !isPrimary
              ? Border.all(
                  color: isDestructive
                      ? const Color(0xFFFFCDD2)
                      : Colors.grey[300]!,
                )
              : null,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: onPressed == null
                  ? Colors.grey[400]
                  : isPrimary
                      ? Colors.white
                      : isDestructive
                          ? const Color(0xFFE53935)
                          : Colors.grey[700],
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: onPressed == null
                    ? Colors.grey[400]
                    : isPrimary
                        ? Colors.white
                        : isDestructive
                            ? const Color(0xFFE53935)
                            : const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connect(AppLocalizations l10n) async {
    if (widget.host.state != HostState.ready) {
      setState(() {
        _statusMessage = l10n.get('consoleNotOnline');
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = l10n.get('connecting');
    });

    try {
      // Navigate to streaming screen
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => StreamingScreen(host: widget.host),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '${l10n.get('connectionFailed')}: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _wakeUp(AppLocalizations l10n) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = l10n.get('wakingUp');
    });

    try {
      final appState = context.read<AppState>();
      final registKey = widget.host.registrationInfo?.rpRegistKey;
      if (registKey == null) {
        setState(() {
          _statusMessage = l10n.get('registrationRequired');
        });
        return;
      }
      await appState.discoveryService.wakeup(
        widget.host,
        registKey,
      );

      setState(() {
        _statusMessage = l10n.get('wakeUpSent');
      });

      // Wait and refresh
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      await appState.startDiscovery();
    } catch (e) {
      setState(() {
        _statusMessage = '${l10n.get('wakeUpFailed')}: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _register(AppLocalizations l10n) async {
    final pin = _pinController.text.trim();
    final psnId = _psnIdController.text.trim();
    final psnAccountIdInput = _psnAccountIdController.text.trim();

    if (psnId.isEmpty) {
      setState(() {
        _statusMessage = l10n.get('enterPsnId');
      });
      return;
    }

    if (pin.length != 8) {
      setState(() {
        _statusMessage = l10n.get('pinMustBe8Digits');
      });
      return;
    }

    // Determine PSN Account ID to use
    String psnAccountId;
    if (psnAccountIdInput.isNotEmpty) {
      // Validate the input
      if (!PSNAccountStorage.isValidPSNAccountId(psnAccountIdInput)) {
        setState(() {
          _statusMessage = l10n.get('invalidPsnAccountId');
        });
        return;
      }
      psnAccountId = psnAccountIdInput;
    } else {
      // Use default if empty
      psnAccountId = PSNAccountStorage.getDefaultAccountId();
    }

    setState(() {
      _isRegistering = true;
      _statusMessage = l10n.get('registering');
    });

    try {
      final service = RegistrationService();
      final result = await service.register(
        host: widget.host,
        pin: pin,
        psnAccountId: psnAccountId,
        psnOnlineId: psnId,
      );

      if (result.success) {
        // Save PSN Account ID for future use
        if (psnAccountIdInput.isNotEmpty) {
          await PSNAccountStorage.savePSNAccountId(psnAccountId);
        }

        // Update host with registration info
        final updatedHost = widget.host.copyWith(
          registrationInfo: RegisteredHostInfo(
            rpRegistKey: result.rpRegistKey!,
            rpKey: result.rpKey!,
            rpKeyType: result.rpKeyType ?? 0,
            serverMac: result.serverMac ?? [],
            serverNickname: result.serverNickname ?? widget.host.hostName,
            registeredAt: DateTime.now(),
          ),
        );

        if (mounted) {
          context.read<AppState>().updateHost(updatedHost);
          setState(() {
            _statusMessage = l10n.get('registrationSuccess');
          });
        }
      } else {
        setState(() {
          _statusMessage = result.errorMessage ?? l10n.get('registrationFailed');
        });
      }

      service.dispose();
    } catch (e) {
      setState(() {
        _statusMessage = '${l10n.get('registrationError')}: $e';
      });
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }

  void _unregister(AppLocalizations l10n) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.get('unregisterTitle')),
        content: Text(
          l10n.getFormatted('unregisterConfirm', {'host': widget.host.hostName}),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              // Remove registration info
              final updatedHost = widget.host.copyWith(
                registrationInfo: null,
              );
              context.read<AppState>().updateHost(updatedHost);
            },
            child: Text(l10n.get('unregister')),
          ),
        ],
      ),
    );
  }
}
