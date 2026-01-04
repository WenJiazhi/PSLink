import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:pslink/l10n/app_localizations.dart';
import 'package:pslink/l10n/language_provider.dart';

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
    final l10n = AppLocalizations.of(context);
    final languageProvider = context.watch<LanguageProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1A1F38),
              Color(0xFF0D1B2A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(l10n),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSection(
                      l10n.get('video'),
                      [
                        _buildSelectOption(
                          l10n.get('resolution'),
                          _resolution,
                          ['720p', '1080p', '1440p', '4K'],
                          (value) => setState(() => _resolution = value),
                          l10n,
                        ),
                        _buildSelectOption(
                          l10n.get('frameRate'),
                          '$_frameRate FPS',
                          ['30 FPS', '60 FPS'],
                          (value) {
                            setState(() {
                              _frameRate = value.replaceAll(' FPS', '');
                            });
                          },
                          l10n,
                        ),
                        _buildSelectOption(
                          l10n.get('videoCodec'),
                          _codec,
                          ['H.264', 'HEVC (H.265)'],
                          (value) {
                            setState(() {
                              _codec = value.contains('HEVC') ? 'HEVC' : 'H.264';
                            });
                          },
                          l10n,
                        ),
                        _buildToggleOption(
                          l10n.get('hdr'),
                          l10n.get('enableHdr'),
                          _useHDR,
                          (value) => setState(() => _useHDR = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      l10n.get('network'),
                      [
                        _buildSliderOption(
                          l10n.get('bitrateLimit'),
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
                      l10n.get('controller'),
                      [
                        _buildToggleOption(
                          l10n.get('hapticFeedback'),
                          l10n.get('enableVibration'),
                          _useHaptics,
                          (value) => setState(() => _useHaptics = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      l10n.get('audio'),
                      [
                        _buildToggleOption(
                          l10n.get('microphone'),
                          l10n.get('enableVoiceChat'),
                          _useMicrophone,
                          (value) => setState(() => _useMicrophone = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      l10n.get('language'),
                      [
                        _buildLanguageOption(
                          l10n.get('language'),
                          languageProvider.locale.languageCode == 'zh'
                              ? l10n.get('chinese')
                              : l10n.get('english'),
                          l10n,
                          languageProvider,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      l10n.get('about'),
                      [
                        _buildInfoOption(l10n.get('version'), '1.0.1'),
                        _buildInfoOption(l10n.get('developer'), 'PSLink Team'),
                        _buildInfoOption(l10n.get('basedOn'), 'Chiaki Open Source'),
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

  Widget _buildAppBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: const Icon(
                CupertinoIcons.back,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              l10n.get('settings'),
              style: const TextStyle(
                fontSize: 22,
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
              color: const Color(0xFF0072CE).withValues(alpha: 0.8),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
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
                        color: Colors.white.withValues(alpha: 0.08),
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
    AppLocalizations l10n,
  ) {
    return GestureDetector(
      onTap: () => _showOptionPicker(label, options, value, onChanged, l10n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
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

  Widget _buildLanguageOption(
    String label,
    String value,
    AppLocalizations l10n,
    LanguageProvider languageProvider,
  ) {
    return GestureDetector(
      onTap: () => _showLanguagePicker(l10n, languageProvider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0072CE).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.globe,
                    color: Color(0xFF0072CE),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                    color: Colors.white.withValues(alpha: 0.4),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0072CE).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0072CE),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF0072CE),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF0072CE).withValues(alpha: 0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
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
    AppLocalizations l10n,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 280,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1F38),
              Color(0xFF0D1B2A),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0072CE).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.get('done'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0072CE),
                          fontWeight: FontWeight.w600,
                        ),
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
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0072CE).withValues(alpha: 0.15)
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
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0072CE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.checkmark,
                                color: Colors.white,
                                size: 14,
                              ),
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

  void _showLanguagePicker(
    AppLocalizations l10n,
    LanguageProvider languageProvider,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 220,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1F38),
              Color(0xFF0D1B2A),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
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
                    l10n.get('language'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0072CE).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.get('done'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0072CE),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildLanguageItem(
              'English',
              '🇺🇸',
              languageProvider.locale.languageCode == 'en',
              () {
                languageProvider.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
              indent: 18,
            ),
            _buildLanguageItem(
              '中文',
              '🇨🇳',
              languageProvider.locale.languageCode == 'zh',
              () {
                languageProvider.setLocale(const Locale('zh'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem(
    String label,
    String flag,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0072CE).withValues(alpha: 0.15)
              : null,
        ),
        child: Row(
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF0072CE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark,
                  color: Colors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
