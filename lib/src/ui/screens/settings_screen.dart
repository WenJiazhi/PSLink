import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings values
  String _resolution = '1080p';
  String _frameRate = '60';
  String _codec = 'H.264';
  bool _useHDR = false;
  bool _useHaptics = true;
  bool _useMicrophone = false;
  double _bitrateLimit = 15.0;

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
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection(
                      'Video',
                      [
                        _buildSelectOption(
                          'Resolution',
                          _resolution,
                          ['720p', '1080p', '1440p', '4K'],
                          (value) => setState(() => _resolution = value),
                        ),
                        _buildSelectOption(
                          'Frame Rate',
                          '$_frameRate FPS',
                          ['30 FPS', '60 FPS'],
                          (value) {
                            setState(() {
                              _frameRate = value.replaceAll(' FPS', '');
                            });
                          },
                        ),
                        _buildSelectOption(
                          'Video Codec',
                          _codec,
                          ['H.264', 'HEVC (H.265)'],
                          (value) {
                            setState(() {
                              _codec = value.contains('HEVC') ? 'HEVC' : 'H.264';
                            });
                          },
                        ),
                        _buildToggleOption(
                          'HDR',
                          'Enable HDR video output',
                          _useHDR,
                          (value) => setState(() => _useHDR = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Network',
                      [
                        _buildSliderOption(
                          'Bitrate Limit',
                          '${_bitrateLimit.toInt()} Mbps',
                          _bitrateLimit,
                          5,
                          50,
                          (value) => setState(() => _bitrateLimit = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Controller',
                      [
                        _buildToggleOption(
                          'Haptic Feedback',
                          'Enable vibration feedback',
                          _useHaptics,
                          (value) => setState(() => _useHaptics = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Audio',
                      [
                        _buildToggleOption(
                          'Microphone',
                          'Enable voice chat',
                          _useMicrophone,
                          (value) => setState(() => _useMicrophone = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'About',
                      [
                        _buildInfoOption('Version', '1.0.0'),
                        _buildInfoOption('Developer', 'PSLink Team'),
                        _buildInfoOption('Based on', 'Chiaki Open Source'),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
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
          const Expanded(
            child: Text(
              'Settings',
              style: TextStyle(
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

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: children.map((child) {
              final isLast = child == children.last;
              return Column(
                children: [
                  child,
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectOption(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return GestureDetector(
      onTap: () => _showOptionPicker(label, options, value, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    String label,
    String description,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: const Color(0xFF0072CE),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderOption(
    String label,
    String value,
    double currentValue,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF0072CE),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF0072CE).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: currentValue,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoOption(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionPicker(
    String title,
    List<String> options,
    String currentValue,
    Function(String) onChanged,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF0072CE),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: options.map((option) {
                  final isSelected = option == currentValue ||
                      option.contains(currentValue);
                  return GestureDetector(
                    onTap: () {
                      onChanged(option);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0072CE).withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              CupertinoIcons.checkmark,
                              color: Color(0xFF0072CE),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
