import 'package:flutter/material.dart';
import '../core/constants.dart';

/// 连接状态指示器
class ConnectionIndicator extends StatelessWidget {
  final bool isConnected;
  final int latencyMs;
  final double fps;
  final int bitrate;
  final VoidCallback? onDisconnect;

  const ConnectionIndicator({
    super.key,
    required this.isConnected,
    this.latencyMs = 0,
    this.fps = 0,
    this.bitrate = 0,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 连接状态点
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected
                  ? Color(AppColors.successColor)
                  : Color(AppColors.errorColor),
              boxShadow: [
                BoxShadow(
                  color: (isConnected
                          ? Color(AppColors.successColor)
                          : Color(AppColors.errorColor))
                      .withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 延迟
          if (isConnected) ...[
            _buildStat('${latencyMs}ms', _getLatencyColor(latencyMs)),
            const SizedBox(width: 12),

            // FPS
            _buildStat('${fps.toStringAsFixed(0)} FPS', Colors.white70),
            const SizedBox(width: 12),

            // 码率
            _buildStat('${(bitrate / 1000).toStringAsFixed(1)} Mbps', Colors.white70),
          ] else ...[
            Text(
              '未连接',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],

          // 断开按钮
          if (isConnected && onDisconnect != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDisconnect,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(AppColors.errorColor).withOpacity(0.2),
                ),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Color(AppColors.errorColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String value, Color color) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Color _getLatencyColor(int latency) {
    if (latency < 30) return Color(AppColors.successColor);
    if (latency < 60) return Color(AppColors.warningColor);
    return Color(AppColors.errorColor);
  }
}

/// 加载动画组件
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool showProgress;
  final double? progress;

  const LoadingOverlay({
    super.key,
    this.message,
    this.showProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showProgress && progress != null)
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(AppColors.accentColor),
                  ),
                  backgroundColor: Color(AppColors.surfaceColor),
                ),
              )
            else
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(AppColors.accentColor),
                  ),
                ),
              ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// PIN 码输入框
class PinCodeInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  const PinCodeInput({
    super.key,
    this.length = 8,
    this.onCompleted,
    this.onChanged,
  });

  @override
  State<PinCodeInput> createState() => _PinCodeInputState();
}

class _PinCodeInputState extends State<PinCodeInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentValue {
    return _controllers.map((c) => c.text).join();
  }

  void _handleInput(int index, String value) {
    if (value.isNotEmpty) {
      // 输入数字，跳转到下一个
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // 最后一个，取消焦点
        _focusNodes[index].unfocus();
      }
    }

    widget.onChanged?.call(_currentValue);

    if (_currentValue.length == widget.length) {
      widget.onCompleted?.call(_currentValue);
    }
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        // 在第4位后添加分隔符
        final showSeparator = index == 4;

        return Row(
          children: [
            if (showSeparator)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '-',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 24,
                  ),
                ),
              ),
            SizedBox(
              width: 40,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Color(AppColors.surfaceColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Color(AppColors.primaryColor),
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) => _handleInput(index, value),
                onSubmitted: (_) {
                  if (index < widget.length - 1) {
                    _focusNodes[index + 1].requestFocus();
                  }
                },
              ),
            ),
            if (index < widget.length - 1 && !showSeparator)
              const SizedBox(width: 8),
          ],
        );
      }),
    );
  }
}

/// 设置项组件
class SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon != null
          ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(AppColors.primaryColor).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Color(AppColors.accentColor),
                size: 20,
              ),
            )
          : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}

/// 设置滑块
class SettingsSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? valueLabel;
  final ValueChanged<double>? onChanged;

  const SettingsSlider({
    super.key,
    required this.title,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueLabel,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (valueLabel != null)
                Text(
                  valueLabel!,
                  style: TextStyle(
                    color: Color(AppColors.accentColor),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
