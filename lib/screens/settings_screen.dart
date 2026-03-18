import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/stream_provider.dart';
import '../models/stream_settings.dart';
import 'about_screen.dart';

/// 璁剧疆椤甸潰
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('璁剧疆'),
      ),
      body: Consumer<PSStreamProvider>(
        builder: (context, provider, child) {
          final settings = provider.settings;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // Video settings
              _buildSectionHeader('Video'),
              _buildVideoSettings(context, provider, settings),

              const SizedBox(height: 24),

              // Controller settings
              _buildSectionHeader('Controller'),
              _buildControllerSettings(context, provider, settings),

              const SizedBox(height: 24),

              // Audio settings
              _buildSectionHeader('Audio'),
              _buildAudioSettings(context, provider, settings),

              const SizedBox(height: 24),

              // Advanced settings
              _buildSectionHeader('Advanced'),
              _buildAdvancedSettings(context, provider, settings),

              const SizedBox(height: 24),

              // About
              _buildSectionHeader('About'),
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
          // Resolution
          ListTile(
            leading: const Icon(Icons.aspect_ratio),
            title: const Text('Resolution'),
            subtitle: Text(settings.resolution),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showResolutionDialog(context, provider, settings),
          ),
          const Divider(height: 1),

          // 甯х巼
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('甯х巼'),
            subtitle: Text('${settings.frameRate} FPS'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFrameRateDialog(context, provider, settings),
          ),
          const Divider(height: 1),

          // 鐮佺巼
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
                      '鐮佺巼',
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
    PSStreamProvider provider,
    StreamSettings settings,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Controller opacity
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
                      'Controller opacity',
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

          // Always show controller
          SwitchListTile(
            secondary: const Icon(Icons.gamepad),
            title: const Text('Always show controller'),
            subtitle: const Text('Disable this to toggle with a three-finger gesture'),
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
          // 闊抽寤惰繜
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
                      '闊抽寤惰繜琛ュ伩',
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

          // Enable microphone
          SwitchListTile(
            secondary: const Icon(Icons.mic),
            title: const Text('Enable microphone'),
            subtitle: const Text('Allow voice chat during Remote Play'),
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
          // HDR
          SwitchListTile(
            secondary: const Icon(Icons.hdr_on),
            title: const Text('鍚敤 HDR'),
            subtitle: const Text('闇€瑕佽澶囨敮鎸?(PS5)'),
            value: settings.enableHDR,
            onChanged: (value) {
              provider.updateSettings(
                settings.copyWith(enableHDR: value),
              );
            },
          ),
          const Divider(height: 1),

          // 瑙﹁鍙嶉
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('瑙﹁鍙嶉'),
            subtitle: const Text('闇囧姩鍙嶉 (DualSense)'),
            value: settings.enableHaptics,
            onChanged: (value) {
              provider.updateSettings(
                settings.copyWith(enableHaptics: value),
              );
            },
          ),
          const Divider(height: 1),

          // 鑷€傚簲鎵虫満
          SwitchListTile(
            secondary: const Icon(Icons.adjust),
            title: const Text('鑷€傚簲鎵虫満'),
            subtitle: const Text('L2/R2 鑷€傚簲闃诲姏 (DualSense)'),
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
        title: const Text('About PSLink'),
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
    showDialog(
      context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select resolution'),
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFrameRateDialog(
    BuildContext context,
    PSStreamProvider provider,
    StreamSettings settings,
  ) {
    showDialog(
      context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select frame rate'),
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}


