import 'package:flutter/material.dart';
import '../models/ps_device.dart';
import '../core/constants.dart';

/// PlayStation 设备卡片组件
class PSDeviceCard extends StatelessWidget {
  final PSDevice device;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onWake;

  const PSDeviceCard({
    super.key,
    required this.device,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onWake,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: Color(AppColors.accentColor), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 设备图标
              _buildDeviceIcon(),
              const SizedBox(width: 16),

              // 设备信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 设备名称
                    Text(
                      device.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 设备类型和状态
                    Row(
                      children: [
                        _buildChip(
                          device.deviceTypeString,
                          device.deviceType == PSDeviceType.ps5
                              ? Colors.blue
                              : Colors.indigo,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusIndicator(),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // IP 地址
                    Text(
                      device.ipAddress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Color(AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              // 操作按钮
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (device.isRegistered) ...[
                    Icon(
                      Icons.check_circle,
                      color: Color(AppColors.successColor),
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (device.state == PSDeviceState.standby && onWake != null)
                    IconButton(
                      icon: const Icon(Icons.power_settings_new),
                      onPressed: onWake,
                      tooltip: '唤醒',
                      color: Color(AppColors.accentColor),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: device.deviceType == PSDeviceType.ps5
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
          device.deviceType == PSDeviceType.ps5 ? 'PS5' : 'PS4',
          style: TextStyle(
            color: device.deviceType == PSDeviceType.ps5
                ? Colors.black
                : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    String text;

    switch (device.state) {
      case PSDeviceState.ready:
        color = Color(AppColors.successColor);
        text = '就绪';
        break;
      case PSDeviceState.standby:
        color = Color(AppColors.warningColor);
        text = '待机';
        break;
      case PSDeviceState.unknown:
        color = Colors.grey;
        text = '未知';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
