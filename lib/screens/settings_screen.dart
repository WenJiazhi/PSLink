import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/stream_settings.dart';
import '../providers/stream_provider.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<PSStreamProvider>(
        builder: (context, provider, child) {
          final settings = provider.settings;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _buildSectionHeader('视频'),
              _buildVideoSettings(context, provider, settings),
              const SizedBox(height: 24),
              _buildSectionHeader('控制器'),
              _buildControllerSettings(context, provider, settings),
              const SizedBox(height: 24),
              _buildSectionHeader('音频'),
              _buildAudioSettings(context, provider, settings),
              const SizedBox(height: 24),
              _buildSectionHeader('高级'),
              _buildAdvancedSettings(context, provider, settings),
              const SizedBox(height: 24),
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
    PSStreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.aspect_ratio),
            title: const Text('分辨率'),
            subtitle: Text(settings.resolution),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showResolutionDialog(context, provider, settings),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('帧率'),
            subtitle: Text('${settings.frameRate} FPS'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFrameRateDialog(context, provider, settings),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.signal_cellular_alt, size: 20),
                    const SizedBox(width: 12),
                    const Text('码率', style: TextStyle(fontSize: 16)),
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
                  divisions:
                      ((PSConstants.maxBitrate - PSConstants.minBitrate) / 500)
                          .round(),
                  onChanged: (value) => provider.setBitrate(value.round()),
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
    PSStreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.opacity, size: 20),
                    const SizedBox(width: 12),
                    const Text('虚拟手柄透明度', style: TextStyle(fontSize: 16)),
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
                  onChanged: provider.setControllerOpacity,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.gamepad),
            title: const Text('始终显示虚拟手柄'),
            subtitle: const Text('关闭后可通过三指手势显示或隐藏'),
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
    PSStreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.graphic_eq, size: 20),
                    const SizedBox(width: 12),
                    const Text('音频缓冲', style: TextStyle(fontSize: 16)),
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
          SwitchListTile(
            secondary: const Icon(Icons.mic),
            title: const Text('启用麦克风'),
            subtitle: const Text('允许串流期间使用语音输入'),
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
    PSStreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.hdr_on),
            title: const Text('启用 HDR'),
            subtitle: const Text('需要主机和当前设备同时支持 HDR'),
            value: settings.enableHDR,
            onChanged: (value) {
              provider.updateSettings(settings.copyWith(enableHDR: value));
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('触觉反馈'),
            subtitle: const Text('启用手柄震动反馈'),
            value: settings.enableHaptics,
            onChanged: (value) {
              provider.updateSettings(settings.copyWith(enableHaptics: value));
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.adjust),
            title: const Text('自适应扳机'),
            subtitle: const Text('启用 DualSense L2 / R2 阻力效果'),
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
    PSStreamProvider provider,
    StreamSettings settings,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(AppColors.cardColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('选择分辨率')),
              for (final resolution in PSConstants.resolutions.keys)
                ListTile(
                  title: Text(resolution),
                  subtitle: Text(
                    '${PSConstants.resolutions[resolution]![0]} x ${PSConstants.resolutions[resolution]![1]}',
                  ),
                  trailing: settings.resolution == resolution
                      ? const Icon(Icons.check, color: Color(AppColors.accentColor))
                      : null,
                  onTap: () {
                    provider.setResolution(resolution);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showFrameRateDialog(
    BuildContext context,
    PSStreamProvider provider,
    StreamSettings settings,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(AppColors.cardColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('选择帧率')),
              for (final frameRate in PSConstants.frameRates)
                ListTile(
                  title: Text('$frameRate FPS'),
                  trailing: settings.frameRate == frameRate
                      ? const Icon(Icons.check, color: Color(AppColors.accentColor))
                      : null,
                  onTap: () {
                    provider.setFrameRate(frameRate);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
