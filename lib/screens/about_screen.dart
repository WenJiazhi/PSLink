import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String githubUrl = 'https://github.com/WenJiazhi/PSLink';
  static const String licenseUrl =
      'https://github.com/WenJiazhi/PSLink/blob/main/LICENSE';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          _buildAppHeader(),
          const SizedBox(height: 32),
          _buildSectionHeader('版本信息'),
          _buildVersionInfo(),
          const SizedBox(height: 24),
          _buildSectionHeader('开源与许可'),
          _buildLicenseInfo(context),
          const SizedBox(height: 24),
          _buildSectionHeader('项目链接'),
          _buildLinks(),
          const SizedBox(height: 24),
          _buildSectionHeader('说明'),
          _buildNotes(),
          const SizedBox(height: 32),
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
                color: const Color(AppColors.primaryColor).withValues(alpha: 0.3),
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
      child: const Column(
        children: [
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本号'),
            trailing: Text(
              appVersion,
              style: TextStyle(
                color: Color(AppColors.textSecondary),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.build_circle_outlined),
            title: Text('构建号'),
            trailing: Text(
              buildNumber,
              style: TextStyle(
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
            subtitle: const Text('查看源码和开发进度'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl(githubUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('问题反馈'),
            subtitle: const Text('提交 Bug 或功能建议'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl('$githubUrl/issues'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PSLink 是一个面向局域网的 PlayStation Remote Play 客户端。'),
            SizedBox(height: 8),
            Text('设备发现、注册和会话协议会持续对齐 Chiaki / pyremoteplay 的真实实现。'),
            SizedBox(height: 8),
            Text('如果连接异常，请先确认主机已启用 Remote Play，并与当前设备处于同一网络。'),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyright() {
    return const Center(
      child: Text(
        '© 2026 PSLink',
        style: TextStyle(
          color: Color(AppColors.textSecondary),
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not launch $url');
    }
  }
}
