import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

/// 关于页面
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String githubUrl = 'https://github.com/yourusername/pslink';
  static const String licenseUrl = 'https://github.com/yourusername/pslink/blob/main/LICENSE';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          // 应用图标和名称
          _buildAppHeader(),

          const SizedBox(height: 32),

          // 版本信息
          _buildSectionHeader('版本信息'),
          _buildVersionInfo(),

          const SizedBox(height: 24),

          // 开源协议
          _buildSectionHeader('开源协议'),
          _buildLicenseInfo(context),

          const SizedBox(height: 24),

          // 链接
          _buildSectionHeader('链接'),
          _buildLinks(),

          const SizedBox(height: 24),

          // 致谢
          _buildSectionHeader('致谢'),
          _buildAcknowledgments(),

          const SizedBox(height: 32),

          // 版权信息
          _buildCopyright(),
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(AppColors.primaryColor),
                Color(AppColors.accentColor),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(AppColors.primaryColor).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.sports_esports,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'PSLink',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'PlayStation Remote Play',
          style: TextStyle(
            fontSize: 14,
            color: Color(AppColors.textSecondary),
          ),
        ),
      ],
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

  Widget _buildVersionInfo() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本号'),
            trailing: Text(
              appVersion,
              style: const TextStyle(
                color: Color(AppColors.textSecondary),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.build_circle_outlined),
            title: const Text('构建号'),
            trailing: Text(
              buildNumber,
              style: const TextStyle(
                color: Color(AppColors.textSecondary),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseInfo(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('开源许可证'),
            subtitle: const Text('MIT License'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrl(licenseUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('第三方许可证'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'PSLink',
                applicationVersion: appVersion,
                applicationIcon: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(AppColors.primaryColor),
                        Color(AppColors.accentColor),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.sports_esports,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLinks() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub 仓库'),
            subtitle: const Text('查看源代码'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl(githubUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('报告问题'),
            subtitle: const Text('提交 Bug 或功能请求'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl('$githubUrl/issues'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.star_border),
            title: const Text('Star on GitHub'),
            subtitle: const Text('支持这个项目'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl(githubUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildAcknowledgments() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '本应用基于以下开源项目:',
              style: TextStyle(
                fontSize: 14,
                color: Color(AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            _buildAcknowledgmentItem('Flutter', 'UI 框架'),
            _buildAcknowledgmentItem('Provider', '状态管理'),
            _buildAcknowledgmentItem('VLC Player', '视频播放'),
            _buildAcknowledgmentItem('Chiaki', '协议参考'),
            const SizedBox(height: 8),
            const Text(
              '\n免责声明: 本应用与 Sony Interactive Entertainment 无关。PlayStation 和 DualSense 是 Sony Interactive Entertainment 的商标。',
              style: TextStyle(
                fontSize: 11,
                color: Color(AppColors.textSecondary),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcknowledgmentItem(String name, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Color(AppColors.successColor),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '- $description',
            style: const TextStyle(
              fontSize: 12,
              color: Color(AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyright() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text(
            '© 2025 PSLink Contributors',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Made with ❤️ for PlayStation gamers',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }
}
