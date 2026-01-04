import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/ps_device.dart';
import '../services/registration_service.dart';
import '../providers/device_provider.dart';

/// 设备注册页面
/// 引导用户输入 8 位 PIN 码完成设备注册
class RegistrationScreen extends StatefulWidget {
  final PSDevice device;

  const RegistrationScreen({
    super.key,
    required this.device,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final RegistrationService _registrationService = RegistrationService();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isRegistering = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startRegistration() async {
    final pin = _pinController.text.trim();

    // 验证 PIN 码
    if (pin.length != 8) {
      setState(() {
        _errorMessage = 'PIN 码必须是 8 位数字';
      });
      return;
    }

    if (!RegExp(r'^\d{8}$').hasMatch(pin)) {
      setState(() {
        _errorMessage = 'PIN 码只能包含数字';
      });
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      // 使用默认账号 ID (实际应用中应该从用户登录获取)
      const accountId = 'MDAwMDAwMDAwMDAwMDAwMA=='; // Base64 编码的默认账号

      final registeredDevice = await _registrationService.registerWithPin(
        widget.device,
        pin,
        accountId,
      );

      if (!mounted) return;

      if (registeredDevice != null) {
        // 注册成功，保存设备
        final provider = context.read<DeviceProvider>();
        await provider.saveDevice(registeredDevice);

        // 显示成功消息
        if (!mounted) return;
        _showSuccessDialog();
      } else {
        // 注册失败
        setState(() {
          _errorMessage = _registrationService.lastError ?? '注册失败，请重试';
          _isRegistering = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '注册过程中发生错误: $e';
        _isRegistering = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Color(AppColors.successColor),
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text('注册成功'),
          ],
        ),
        content: Text(
          '设备 "${widget.device.displayName}" 已成功注册！\n现在可以开始串流了。',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // 关闭对话框
              Navigator.pop(context); // 返回主页
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备注册'),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 设备信息卡片
              _buildDeviceInfo(),
              const SizedBox(height: 32),

              // 注册指引
              _buildInstructions(),
              const SizedBox(height: 32),

              // PIN 码输入
              _buildPinInput(),
              const SizedBox(height: 24),

              // 错误提示
              if (_errorMessage != null) _buildErrorMessage(),

              // 注册状态或按钮
              if (_isRegistering)
                _buildRegistrationProgress()
              else
                _buildRegisterButton(),

              const SizedBox(height: 24),

              // 帮助信息
              _buildHelpInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 设备图标
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.device.deviceType == PSDeviceType.ps5
                      ? [Colors.white, Colors.grey.shade200]
                      : [Colors.black87, Colors.black54],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.device.deviceTypeString,
                  style: TextStyle(
                    color: widget.device.deviceType == PSDeviceType.ps5
                        ? Colors.black
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // 设备名称和IP
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.device.ipAddress,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Color(AppColors.textSecondary),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Color(AppColors.warningColor).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '未注册',
                      style: TextStyle(
                        color: Color(AppColors.warningColor),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildInstructions() {
    return Card(
      color: Color(AppColors.primaryColor).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(AppColors.accentColor),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '注册步骤',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Color(AppColors.accentColor),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              1,
              '在 PlayStation 上打开',
              '设置 > 远程游玩连接设置 > 添加设备',
            ),
            const SizedBox(height: 8),
            _buildInstructionStep(
              2,
              'PlayStation 会显示 8 位 PIN 码',
              '屏幕上会显示一个 8 位数字的 PIN 码',
            ),
            const SizedBox(height: 8),
            _buildInstructionStep(
              3,
              '在下方输入 PIN 码',
              '输入完成后点击"开始注册"按钮',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int step, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Color(AppColors.accentColor),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Color(AppColors.textSecondary),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PIN 码',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pinController,
          focusNode: _pinFocusNode,
          keyboardType: TextInputType.number,
          maxLength: 8,
          enabled: !_isRegistering,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '00000000',
            counterText: '',
            prefixIcon: Icon(
              Icons.pin,
              color: Color(AppColors.accentColor),
            ),
            suffixIcon: _pinController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _pinController.clear();
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() {
              _errorMessage = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(AppColors.errorColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color(AppColors.errorColor).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Color(AppColors.errorColor),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Color(AppColors.errorColor),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationProgress() {
    return Card(
      color: Color(AppColors.primaryColor).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(AppColors.accentColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '正在注册...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Color(AppColors.accentColor),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '正在与 PlayStation 建立安全连接',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton.icon(
      onPressed: _pinController.text.length == 8 ? _startRegistration : null,
      icon: const Icon(Icons.app_registration),
      label: const Text('开始注册'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildHelpInfo() {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Color(AppColors.textSecondary),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '常见问题',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Color(AppColors.textSecondary),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              '找不到 PIN 码？',
              '确保在 PlayStation 的远程游玩设置中选择了"添加设备"',
            ),
            const SizedBox(height: 8),
            _buildHelpItem(
              '注册失败？',
              '确认 PIN 码正确，并且 PlayStation 和手机在同一网络',
            ),
            const SizedBox(height: 8),
            _buildHelpItem(
              'PIN 码过期？',
              'PIN 码有效期为 5 分钟，过期后需要重新生成',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Color(AppColors.textPrimary),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Color(AppColors.textSecondary),
              ),
        ),
      ],
    );
  }
}
