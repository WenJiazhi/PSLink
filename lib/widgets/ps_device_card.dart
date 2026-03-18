import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/ps_device.dart';

class PSDeviceCard extends StatelessWidget {
  const PSDeviceCard({
    super.key,
    required this.device,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onWake,
  });

  final PSDevice device;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onWake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(
                color: Color(AppColors.accentColor),
                width: 2,
              )
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
              _buildDeviceIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildChip(
                          device.deviceTypeString,
                          device.deviceType == PSDeviceType.ps5
                              ? Colors.blue
                              : Colors.indigo,
                        ),
                        _buildStatusIndicator(),
                        if (device.isRegistered)
                          _buildChip(
                            '已注册',
                            const Color(AppColors.successColor),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      device.ipAddress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(AppColors.textSecondary),
                      ),
                    ),
                    if (device.systemVersion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '系统版本 ${device.systemVersion}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (device.state == PSDeviceState.standby && onWake != null)
                IconButton(
                  icon: const Icon(Icons.power_settings_new),
                  onPressed: onWake,
                  tooltip: '唤醒主机',
                  color: const Color(AppColors.accentColor),
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
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          device.deviceTypeString,
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
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    switch (device.state) {
      case PSDeviceState.ready:
        color = const Color(AppColors.successColor);
        break;
      case PSDeviceState.standby:
        color = const Color(AppColors.warningColor);
        break;
      case PSDeviceState.unknown:
        color = Colors.grey;
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
          device.stateString,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
