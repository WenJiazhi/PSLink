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
        _errorMessage = '请先输入 Base64 格式的 PSN Account ID。';
      });
      return;
    }

    if (!RegExp(r'^\d{8}$').hasMatch(pin)) {
      setState(() {
        _errorMessage = 'PIN 码必须正好 8 位数字。';
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
          _errorMessage = _registrationService.lastError ?? '注册失败。';
        });
        return;
      }

      await context.read<DeviceProvider>().saveDevice(registeredDevice);

      if (!mounted) {
        return;
      }

      await _showSuccessDialog();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRegistering = false;
        _errorMessage = '注册失败：$error';
      });
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('注册完成'),
          content: Text('“${widget.device.displayName}”已成功注册，可以直接用于唤醒和连接。'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
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
        title: const Text('注册主机'),
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
              label: Text(_isRegistering ? '正在注册...' : '开始注册'),
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
                color: const Color(AppColors.primaryColor).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.device.deviceTypeString,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(AppColors.accentColor),
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
                      color: const Color(AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '系统版本：${widget.device.systemVersion.isEmpty ? '未知' : widget.device.systemVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(AppColors.textSecondary),
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
              '注册前准备',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('1. 在 PS5 上打开“设定 > 系统 > Remote Play > 连接设备”。'),
            const SizedBox(height: 8),
            const Text('2. 确保主机与当前设备处于同一局域网。'),
            const SizedBox(height: 8),
            const Text('3. 输入 Base64 格式的 PSN Account ID，不能填在线 ID。'),
            const SizedBox(height: 8),
            const Text('4. 输入主机屏幕上显示的 8 位 PIN 码。'),
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
              'PSN Account ID（Base64）',
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
                hintText: '粘贴你的 Base64 Account ID',
                helperText: 'PS5 真正的注册协议需要这个值。',
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: IconButton(
                  onPressed: _isRegistering ? null : _pasteAccountId,
                  icon: const Icon(Icons.content_paste),
                  tooltip: '粘贴',
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
              'PIN 码',
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
        color: const Color(AppColors.errorColor).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(AppColors.errorColor).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(AppColors.errorColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(AppColors.errorColor),
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
              '补充说明',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('PS5 只有在“连接设备”页面打开时才会接受注册请求。'),
            const SizedBox(height: 8),
            const Text('如果注册超时，请重新在主机上打开 PIN 页面后再试一次。'),
            const SizedBox(height: 8),
            const Text('注册成功后，应用会保存 RegistKey 和 RP-Key 供后续唤醒与连接使用。'),
          ],
        ),
      ),
    );
  }
}
