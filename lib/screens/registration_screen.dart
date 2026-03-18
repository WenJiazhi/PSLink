import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/ps_device.dart';
import '../providers/device_provider.dart';
import '../services/registration_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.device,
  });

  final PSDevice device;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final RegistrationService _registrationService = RegistrationService();
  final TextEditingController _accountIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _isRegistering = false;
  String? _errorMessage;

  @override
  void dispose() {
    _accountIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _pasteAccountId() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    _accountIdController.text = text;
    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _startRegistration() async {
    final accountId = _accountIdController.text.trim();
    final pin = _pinController.text.trim();

    setState(() {
      _errorMessage = null;
    });

    if (accountId.isEmpty) {
      setState(() {
        _errorMessage = 'Enter the Base64 PSN Account ID first.';
      });
      return;
    }

    if (!RegExp(r'^\d{8}$').hasMatch(pin)) {
      setState(() {
        _errorMessage = 'PIN must be exactly 8 digits.';
      });
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      final registeredDevice = await _registrationService.registerWithPin(
        widget.device,
        pin,
        accountId,
      );

      if (!mounted) {
        return;
      }

      if (registeredDevice == null) {
        setState(() {
          _isRegistering = false;
          _errorMessage =
              _registrationService.lastError ?? 'Registration failed.';
        });
        return;
      }

      await context.read<DeviceProvider>().saveDevice(registeredDevice);

      if (!mounted) {
        return;
      }

      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRegistering = false;
        _errorMessage = 'Registration failed: $e';
      });
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registration complete'),
          content: Text(
            '"${widget.device.displayName}" is now registered and can be used for wake/connect flows.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Console'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDeviceCard(theme),
            const SizedBox(height: 24),
            _buildInstructions(theme),
            const SizedBox(height: 24),
            _buildAccountIdField(theme),
            const SizedBox(height: 16),
            _buildPinField(theme),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(theme),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isRegistering ? null : _startRegistration,
              icon: _isRegistering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.app_registration),
              label: Text(
                _isRegistering ? 'Registering...' : 'Register device',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            _buildHelp(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(AppColors.primaryColor).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.device.deviceTypeString,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Color(AppColors.accentColor),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.displayName,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.device.ipAddress,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Color(AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'System version: ${widget.device.systemVersion.isEmpty ? 'Unknown' : widget.device.systemVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Color(AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before registering',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('1. On the PS5 open Settings > System > Remote Play > Link Device.'),
            const SizedBox(height: 8),
            const Text('2. Keep the console on the same LAN as this device.'),
            const SizedBox(height: 8),
            const Text('3. Use the Base64 PSN Account ID. Your online ID will not work here.'),
            const SizedBox(height: 8),
            const Text('4. Enter the 8-digit PIN shown on the console.'),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountIdField(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PSN Account ID (Base64)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountIdController,
              enabled: !_isRegistering,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                setState(() {
                  _errorMessage = null;
                });
              },
              decoration: InputDecoration(
                hintText: 'Paste your Base64 account ID',
                helperText: 'Required by the real PS5 registration protocol.',
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: IconButton(
                  onPressed: _isRegistering ? null : _pasteAccountId,
                  icon: const Icon(Icons.content_paste),
                  tooltip: 'Paste',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinField(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PIN',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              enabled: !_isRegistering,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                setState(() {
                  _errorMessage = null;
                });
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: '00000000',
                counterText: '',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(AppColors.errorColor).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(AppColors.errorColor).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Color(AppColors.errorColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Color(AppColors.errorColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelp(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('The PS5 only accepts registration while the "Link Device" screen is open.'),
            const SizedBox(height: 8),
            const Text('If registration times out, reopen the PIN screen on the console and retry.'),
            const SizedBox(height: 8),
            const Text('For remote wake and streaming later, the app stores the returned RegistKey and RP-Key.'),
          ],
        ),
      ),
    );
  }
}
