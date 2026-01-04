import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/stream_provider.dart';
import '../models/stream_settings.dart';
import 'about_screen.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<StreamProvider>(
        builder: (context, provider, child) {
          final settings = provider.settings;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // 视频设置
              _buildSectionHeader('视频设置'),
              _buildVideoSettings(context, provider, settings),

              const SizedBox(height: 24),

              // 控制器设置
              _buildSectionHeader('控制器设置'),
              _buildControllerSettings(context, provider, settings),

              const SizedBox(height: 24),

              // 音频设置
              _buildSectionHeader('音频设置'),
              _buildAudioSettings(context, provider, settings),

              const SizedBox(height: 24),

              // 高级设置
              _buildSectionHeader('高级设置'),
              _buildAdvancedSettings(context, provider, settings),

              const SizedBox(height: 24),

              // 关于
              _buildSectionHeader('关于'),
              _buildAboutSection(context),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(AppColors.accentColor),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVideoSettings(
    BuildContext context,
    StreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 分辨率
          ListTile(
            leading: const Icon(Icons.aspect_ratio),
            title: const Text('分辨率'),
            subtitle: Text(settings.resolution),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showResolutionDialog(context, provider, settings),
          ),
          const Divider(height: 1),

          // 帧率
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('帧率'),
            subtitle: Text('${settings.frameRate} FPS'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFrameRateDialog(context, provider, settings),
          ),
          const Divider(height: 1),

          // 码率
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.signal_cellular_alt, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      '码率',
                      style: TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '${(settings.bitrate / 1000).toStringAsFixed(1)} Mbps',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: settings.bitrate.toDouble(),
                  min: PSConstants.minBitrate.toDouble(),
                  max: PSConstants.maxBitrate.toDouble(),
                  divisions: ((PSConstants.maxBitrate - PSConstants.minBitrate) / 500).round(),
                  onChanged: (value) {
                    provider.setBitrate(value.round());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${PSConstants.minBitrate / 1000} Mbps',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${PSConstants.maxBitrate / 1000} Mbps',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControllerSettings(
    BuildContext context,
    StreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 控制器透明度
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.opacity, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      '控制器透明度',
                      style: TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '${(settings.controllerOpacity * 100).round()}%',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: settings.controllerOpacity,
                  min: 0.2,
                  max: 1.0,
                  divisions: 16,
                  onChanged: (value) {
                    provider.setControllerOpacity(value);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 始终显示控制器
          SwitchListTile(
            secondary: const Icon(Icons.gamepad),
            title: const Text('始终显示控制器'),
            subtitle: const Text('禁用时可通过三指手势显示/隐藏'),
            value: settings.showControllerAlways,
            onChanged: (value) {
              provider.updateSettings(
                settings.copyWith(showControllerAlways: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSettings(
    BuildContext context,
    StreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 音频延迟
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      '音频延迟补偿',
                      style: TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '${settings.audioLatency} ms',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: settings.audioLatency.toDouble(),
                  min: 0,
                  max: 200,
                  divisions: 20,
                  onChanged: (value) {
                    provider.updateSettings(
                      settings.copyWith(audioLatency: value.round()),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 启用麦克风
          SwitchListTile(
            secondary: const Icon(Icons.mic),
            title: const Text('启用麦克风'),
            subtitle: const Text('允许通过麦克风与PlayStation通话'),
            value: settings.enableMicrophone,
            onChanged: (value) {
              provider.updateSettings(
                settings.copyWith(enableMicrophone: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings(
    BuildContext context,
    StreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // HDR
          SwitchListTile(
            secondary: const Icon(Icons.hdr_on),
            title: const Text('启用 HDR'),
            subtitle: const Text('需要设备支持 (PS5)'),
            value: settings.enableHDR,
            onChanged: (value) {
              provider.updateSettings(
                settings.copyWith(enableHDR: value),
              );
            },
          ),
          const Divider(height: 1),

          // 触觉反馈
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('触觉反馈'),
            subtitle: const Text('震动反馈 (DualSense)'),
            value: settings.enableHaptics,
            onChanged: (value) {
              provider.updateSettings(
                settings.copyWith(enableHaptics: value),
              );
            },
          ),
          const Divider(height: 1),

          // 自适应扳机
          SwitchListTile(
            secondary: const Icon(Icons.adjust),
            title: const Text('自适应扳机'),
            subtitle: const Text('L2/R2 自适应阻力 (DualSense)'),
            value: settings.enableAdaptiveTriggers,
            onChanged: (value) {
              provider.updateSettings(
                settings.copyWith(enableAdaptiveTriggers: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('关于 PSLink'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AboutScreen()),
          );
        },
      ),
    );
  }

  void _showResolutionDialog(
    BuildContext context,
    StreamProvider provider,
    StreamSettings settings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择分辨率'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PSConstants.resolutions.keys.map((resolution) {
            final isSelected = settings.resolution == resolution;
            return RadioListTile<String>(
              title: Text(resolution),
              subtitle: Text(
                '${PSConstants.resolutions[resolution]![0]} x ${PSConstants.resolutions[resolution]![1]}',
              ),
              value: resolution,
              groupValue: settings.resolution,
              selected: isSelected,
              onChanged: (value) {
                if (value != null) {
                  provider.setResolution(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showFrameRateDialog(
    BuildContext context,
    StreamProvider provider,
    StreamSettings settings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择帧率'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PSConstants.frameRates.map((frameRate) {
            final isSelected = settings.frameRate == frameRate;
            return RadioListTile<int>(
              title: Text('$frameRate FPS'),
              value: frameRate,
              groupValue: settings.frameRate,
              selected: isSelected,
              onChanged: (value) {
                if (value != null) {
                  provider.setFrameRate(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
