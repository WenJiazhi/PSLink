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
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(l10n),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                  _buildSection(
                    l10n.get('about'),
                    [
                      _buildInfoOption(l10n.get('version'), '1.0.2'),
                      _buildInfoOption(l10n.get('developer'), 'PSLink Team'),
                      _buildInfoOption(l10n.get('basedOn'), 'Chiaki Open Source'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                CupertinoIcons.back,
                color: Colors.grey[700],
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            l10n.get('settings'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
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
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children.map((child) {
              final isLast = child == children.last;
              return Column(
                children: [
                  child,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey[200],
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: Colors.grey[400],
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: Colors.grey[400],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: const Color(0xFF1A1A1A),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF1A1A1A),
              inactiveTrackColor: Colors.grey[200],
              thumbColor: const Color(0xFF1A1A1A),
              overlayColor: Colors.grey.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
              color: Color(0xFF1A1A1A),
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[500],
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
        height: 260,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      l10n.get('done'),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A1A1A),
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
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.grey[100] : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: const Color(0xFF1A1A1A),
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              CupertinoIcons.checkmark,
                              color: Color(0xFF1A1A1A),
                              size: 18,
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
        height: 200,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.get('language'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      l10n.get('done'),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildLanguageItem(
              'English',
              languageProvider.locale.languageCode == 'en',
              () {
                languageProvider.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
            _buildLanguageItem(
              '中文',
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
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[100] : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                CupertinoIcons.checkmark,
                color: Color(0xFF1A1A1A),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
