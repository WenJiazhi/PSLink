import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'package:pslink/src/models/ps_host.dart';
import 'package:pslink/src/protocol/registration.dart';
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

  @override
  void dispose() {
    _pinController.dispose();
    _psnIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
              _buildAppBar(l10n),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildHostInfo(l10n),
                      const SizedBox(height: 32),
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
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: const Icon(
                CupertinoIcons.back,
                color: Colors.white70,
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
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostInfo(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2845),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF0072CE).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0072CE).withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Console icon
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0072CE),
                  Color(0xFF00246B),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0072CE).withValues(alpha: 0.5),
                  blurRadius: 25,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.host.isPS5
                    ? CupertinoIcons.device_desktop
                    : CupertinoIcons.game_controller,
                size: 42,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Console name
          Text(
            widget.host.hostName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.host.isPS5
                    ? [const Color(0xFF00246B), const Color(0xFF003791)]
                    : [const Color(0xFF003791), const Color(0xFF0072CE)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.host.isPS5 ? 'PlayStation 5' : 'PlayStation 4',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Details
          _buildInfoRow(l10n.get('ipAddressLabel'), widget.host.hostAddress),
          _buildInfoRow(l10n.get('systemVersion'), widget.host.systemVersion),
          _buildInfoRow(
            l10n.get('status'),
            widget.host.state == HostState.ready
                ? l10n.get('online')
                : widget.host.state == HostState.standby
                    ? l10n.get('standby')
                    : l10n.get('offline'),
          ),
          if (widget.host.runningAppName != null)
            _buildInfoRow(l10n.get('nowPlaying'), widget.host.runningAppName!),
          _buildInfoRow(
            l10n.get('registration'),
            widget.host.isRegistered ? l10n.get('registered') : l10n.get('notRegistered'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                if (_isConnecting)
                  const CupertinoActivityIndicator()
                else
                  const Icon(
                    CupertinoIcons.info_circle,
                    color: Colors.white70,
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Connect button
        _buildActionButton(
          icon: CupertinoIcons.play_fill,
          label: l10n.get('startRemotePlay'),
          onPressed: _isConnecting ? null : () => _connect(l10n),
          isPrimary: true,
        ),
        const SizedBox(height: 16),

        // Wake up button (if standby)
        if (widget.host.state == HostState.standby) ...[
          _buildActionButton(
            icon: CupertinoIcons.power,
            label: l10n.get('wakeUpConsole'),
            onPressed: _isConnecting ? null : () => _wakeUp(l10n),
          ),
          const SizedBox(height: 16),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0072CE).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF0072CE).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0072CE).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.info_circle_fill,
                      color: Color(0xFF0072CE),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.get('registrationRequired'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.getFormatted('registrationStep1', {'console': consoleName}),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.get('registrationStep2'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.get('registrationStep3'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // PSN ID field
        _buildTextField(
          controller: _psnIdController,
          placeholder: l10n.get('psnId'),
          icon: CupertinoIcons.person,
        ),
        const SizedBox(height: 16),

        // PIN field
        _buildTextField(
          controller: _pinController,
          placeholder: l10n.get('pinCode'),
          icon: CupertinoIcons.lock,
          keyboardType: TextInputType.number,
          maxLength: 8,
        ),
        const SizedBox(height: 28),

        if (_statusMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _isRegistering
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFE53935).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isRegistering
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE53935).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                if (_isRegistering)
                  const CupertinoActivityIndicator()
                else
                  const Icon(
                    CupertinoIcons.exclamationmark_circle,
                    color: Color(0xFFE53935),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: Icon(icon, color: Colors.white54),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: isPrimary && onPressed != null
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0072CE), Color(0xFF00246B)],
                )
              : null,
          color: isPrimary
              ? null
              : isDestructive
                  ? const Color(0xFFE53935).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: !isPrimary
              ? Border.all(
                  color: isDestructive
                      ? const Color(0xFFE53935).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                )
              : Border.all(
                  color: const Color(0xFF0072CE).withValues(alpha: 0.5),
                ),
          boxShadow: isPrimary && onPressed != null
              ? [
                  BoxShadow(
                    color: const Color(0xFF0072CE).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
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
                  ? Colors.white38
                  : isDestructive
                      ? const Color(0xFFE53935)
                      : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: onPressed == null
                    ? Colors.white38
                    : isDestructive
                        ? const Color(0xFFE53935)
                        : Colors.white,
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
      await appState.discoveryService.wakeup(
        widget.host,
        widget.host.registrationInfo!.rpRegistKey,
      );

      setState(() {
        _statusMessage = l10n.get('wakeUpSent');
      });

      // Wait and refresh
      await Future.delayed(const Duration(seconds: 5));
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

    setState(() {
      _isRegistering = true;
      _statusMessage = l10n.get('registering');
    });

    try {
      final service = RegistrationService();
      final result = await service.register(
        host: widget.host,
        pin: pin,
        psnAccountId: '0000000000000000', // Placeholder
        psnOnlineId: psnId,
      );

      if (result.success) {
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
