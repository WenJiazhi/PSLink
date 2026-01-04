import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'package:pslink/src/models/ps_host.dart';
import 'package:pslink/src/protocol/registration.dart';
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
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildHostInfo(),
                      const SizedBox(height: 32),
                      if (widget.host.isRegistered)
                        _buildConnectSection()
                      else
                        _buildRegisterSection(),
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

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.back,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.host.hostName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D2D2D),
            Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0072CE).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Console icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0072CE),
                  Color(0xFF00246B),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0072CE).withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.host.isPS5
                    ? CupertinoIcons.device_desktop
                    : CupertinoIcons.game_controller,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Console name
          Text(
            widget.host.hostName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: widget.host.isPS5
                  ? const Color(0xFF00246B)
                  : const Color(0xFF003791),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.host.isPS5 ? 'PlayStation 5' : 'PlayStation 4',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Details
          _buildInfoRow('IP Address', widget.host.hostAddress),
          _buildInfoRow('System Version', widget.host.systemVersion),
          _buildInfoRow(
            'Status',
            widget.host.state == HostState.ready
                ? 'Online'
                : widget.host.state == HostState.standby
                    ? 'Standby'
                    : 'Unknown',
          ),
          if (widget.host.runningAppName != null)
            _buildInfoRow('Now Playing', widget.host.runningAppName!),
          _buildInfoRow(
            'Registration',
            widget.host.isRegistered ? 'Registered' : 'Not Registered',
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

  Widget _buildConnectSection() {
    return Column(
      children: [
        if (_statusMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 12),
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
          label: 'Start Remote Play',
          onPressed: _isConnecting ? null : _connect,
          isPrimary: true,
        ),
        const SizedBox(height: 16),

        // Wake up button (if standby)
        if (widget.host.state == HostState.standby) ...[
          _buildActionButton(
            icon: CupertinoIcons.power,
            label: 'Wake Up Console',
            onPressed: _isConnecting ? null : _wakeUp,
          ),
          const SizedBox(height: 16),
        ],

        // Unregister button
        _buildActionButton(
          icon: CupertinoIcons.trash,
          label: 'Unregister',
          onPressed: _isConnecting ? null : _unregister,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildRegisterSection() {
    return Column(
      children: [
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0072CE).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF0072CE).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle_fill,
                    color: Color(0xFF0072CE),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Registration Required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '1. On your ${widget.host.isPS5 ? "PS5" : "PS4"}, go to Settings > System > Remote Play',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '2. Select "Link Device" and note the PIN code',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '3. Enter the PIN below to register',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // PSN ID field
        _buildTextField(
          controller: _psnIdController,
          placeholder: 'PSN ID (Online ID)',
          icon: CupertinoIcons.person,
        ),
        const SizedBox(height: 16),

        // PIN field
        _buildTextField(
          controller: _pinController,
          placeholder: '8-digit PIN',
          icon: CupertinoIcons.lock,
          keyboardType: TextInputType.number,
          maxLength: 8,
        ),
        const SizedBox(height: 24),

        if (_statusMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isRegistering
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFE53935).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 12),
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

        // Register button
        _buildActionButton(
          icon: CupertinoIcons.link,
          label: 'Register Device',
          onPressed: _isRegistering ? null : _register,
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
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
            horizontal: 16,
            vertical: 16,
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary && onPressed != null
              ? const LinearGradient(
                  colors: [Color(0xFF0072CE), Color(0xFF00246B)],
                )
              : null,
          color: isPrimary
              ? null
              : isDestructive
                  ? const Color(0xFFE53935).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: !isPrimary
              ? Border.all(
                  color: isDestructive
                      ? const Color(0xFFE53935).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                )
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
            ),
            const SizedBox(width: 8),
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

  Future<void> _connect() async {
    if (widget.host.state != HostState.ready) {
      setState(() {
        _statusMessage = 'Console is not online. Try waking it up first.';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting...';
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
        _statusMessage = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _wakeUp() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Waking up console...';
    });

    try {
      final appState = context.read<AppState>();
      await appState.discoveryService.wakeup(
        widget.host,
        widget.host.registrationInfo!.rpRegistKey,
      );

      setState(() {
        _statusMessage = 'Wake up signal sent. Please wait...';
      });

      // Wait and refresh
      await Future.delayed(const Duration(seconds: 5));
      await appState.startDiscovery();
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to wake up: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _register() async {
    final pin = _pinController.text.trim();
    final psnId = _psnIdController.text.trim();

    if (psnId.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter your PSN ID';
      });
      return;
    }

    if (pin.length != 8) {
      setState(() {
        _statusMessage = 'PIN must be 8 digits';
      });
      return;
    }

    setState(() {
      _isRegistering = true;
      _statusMessage = 'Registering...';
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
            _statusMessage = 'Registration successful!';
          });
        }
      } else {
        setState(() {
          _statusMessage = result.errorMessage ?? 'Registration failed';
        });
      }

      service.dispose();
    } catch (e) {
      setState(() {
        _statusMessage = 'Registration error: $e';
      });
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }

  void _unregister() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Unregister Device'),
        content: Text(
          'Are you sure you want to unregister from ${widget.host.hostName}?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Unregister'),
          ),
        ],
      ),
    );
  }
}
