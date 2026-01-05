import 'package:flutter/material.dart';

/// Application localization support for Chinese and English
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // App
      'appName': 'PSLink',
      'appSubtitle': 'Remote Play for iOS',

      // Home Screen
      'searchingPlayStation': 'Searching for PlayStation...',
      'noPlayStationFound': 'No PlayStation Found',
      'noPlayStationHint': 'Make sure your console is on\nand connected to the same network',
      'online': 'Online',
      'standby': 'Standby',
      'offline': 'Offline',
      'addPlayStation': 'Add PlayStation',
      'ipAddress': 'IP Address',
      'ipAddressHint': 'IP Address (e.g., 192.168.1.100)',
      'cancel': 'Cancel',
      'add': 'Add',
      'searchDevices': 'Search',
      'searching': 'Searching...',
      'invalidIpFormat': 'Invalid IP address format',
      'noPlayStationAtAddress': 'No PlayStation found at this address',
      'searchFailedPrefix': 'Search failed',

      // Discovery Screen
      'registrationRequired': 'Registration Required',
      'registrationStep1': '1. On your {console}, go to Settings > System > Remote Play',
      'registrationStep2': '2. Select "Link Device" and note the PIN code',
      'registrationStep3': '3. Enter the PIN below to register',
      'psnId': 'PSN ID (Online ID)',
      'pinCode': '8-digit PIN',
      'registerDevice': 'Register Device',
      'startRemotePlay': 'Start Remote Play',
      'wakeUpConsole': 'Wake Up Console',
      'unregister': 'Unregister',
      'unregisterTitle': 'Unregister Device',
      'unregisterConfirm': 'Are you sure you want to unregister from {host}?',
      'connecting': 'Connecting...',
      'wakingUp': 'Waking up console...',
      'wakeUpSent': 'Wake up signal sent. Please wait...',
      'registering': 'Registering...',
      'registrationSuccess': 'Registration successful!',
      'registrationFailed': 'Registration failed',
      'consoleNotOnline': 'Console is not online. Try waking it up first.',
      'enterPsnId': 'Please enter your PSN ID',
      'pinMustBe8Digits': 'PIN must be 8 digits',
      'ipAddressLabel': 'IP Address',
      'systemVersion': 'System Version',
      'status': 'Status',
      'nowPlaying': 'Now Playing',
      'registration': 'Registration',
      'registered': 'Registered',
      'notRegistered': 'Not Registered',

      // Settings Screen
      'settings': 'Settings',
      'video': 'Video',
      'resolution': 'Resolution',
      'frameRate': 'Frame Rate',
      'videoCodec': 'Video Codec',
      'hdr': 'HDR',
      'enableHdr': 'Enable HDR video output',
      'network': 'Network',
      'bitrateLimit': 'Bitrate Limit',
      'controller': 'Controller',
      'hapticFeedback': 'Haptic Feedback',
      'enableVibration': 'Enable vibration feedback',
      'audio': 'Audio',
      'microphone': 'Microphone',
      'enableVoiceChat': 'Enable voice chat',
      'about': 'About',
      'version': 'Version',
      'developer': 'Developer',
      'basedOn': 'Based on',
      'language': 'Language',
      'languageHint': 'Select display language',
      'english': 'English',
      'chinese': 'Chinese',
      'done': 'Done',

      // Streaming Screen
      'disconnect': 'Disconnect',
      'connectionLost': 'Connection Lost',
      'reconnecting': 'Reconnecting...',
      'quality': 'Quality',
      'latency': 'Latency',
      'fps': 'FPS',
      'authenticating': 'Authenticating...',
      'startingStream': 'Starting stream...',
      'disconnecting': 'Disconnecting...',
      'disconnected': 'Disconnected',
      'unknownError': 'Unknown error',
      'videoStream': 'Video Stream',
      'goBack': 'Go Back',
      'endRemotePlaySession': 'End the Remote Play session?',
      'streamSettings': 'Stream Settings',
      'bitrateAuto': 'Auto (10 Mbps)',

      // Errors
      'connectionFailed': 'Connection failed',
      'wakeUpFailed': 'Failed to wake up',
      'registrationError': 'Registration error',
      'networkError': 'Network error',
    },
    'zh': {
      // App
      'appName': 'PSLink',
      'appSubtitle': 'iOS 远程游玩',

      // Home Screen
      'searchingPlayStation': '正在搜索 PlayStation...',
      'noPlayStationFound': '未找到 PlayStation',
      'noPlayStationHint': '请确保您的主机已开机\n并连接到同一网络',
      'online': '在线',
      'standby': '待机',
      'offline': '离线',
      'addPlayStation': '添加 PlayStation',
      'ipAddress': 'IP 地址',
      'ipAddressHint': 'IP 地址 (例如 192.168.1.100)',
      'cancel': '取消',
      'add': '添加',
      'searchDevices': '搜索设备',
      'searching': '搜索中...',
      'invalidIpFormat': 'IP 地址格式无效',
      'noPlayStationAtAddress': '未找到 PlayStation,请检查 IP 和网络设置',
      'searchFailedPrefix': '搜索失败',

      // Discovery Screen
      'registrationRequired': '需要注册',
      'registrationStep1': '1. 在您的 {console} 上，前往 设置 > 系统 > 远程游玩',
      'registrationStep2': '2. 选择"链接设备"并记下 PIN 码',
      'registrationStep3': '3. 在下方输入 PIN 码进行注册',
      'psnId': 'PSN ID (在线 ID)',
      'pinCode': '8 位 PIN 码',
      'registerDevice': '注册设备',
      'startRemotePlay': '开始远程游玩',
      'wakeUpConsole': '唤醒主机',
      'unregister': '取消注册',
      'unregisterTitle': '取消注册设备',
      'unregisterConfirm': '确定要从 {host} 取消注册吗？',
      'connecting': '正在连接...',
      'wakingUp': '正在唤醒主机...',
      'wakeUpSent': '唤醒信号已发送，请稍候...',
      'registering': '正在注册...',
      'registrationSuccess': '注册成功！',
      'registrationFailed': '注册失败',
      'consoleNotOnline': '主机未在线，请先尝试唤醒。',
      'enterPsnId': '请输入您的 PSN ID',
      'pinMustBe8Digits': 'PIN 码必须为 8 位数字',
      'ipAddressLabel': 'IP 地址',
      'systemVersion': '系统版本',
      'status': '状态',
      'nowPlaying': '正在游玩',
      'registration': '注册状态',
      'registered': '已注册',
      'notRegistered': '未注册',

      // Settings Screen
      'settings': '设置',
      'video': '视频',
      'resolution': '分辨率',
      'frameRate': '帧率',
      'videoCodec': '视频编码',
      'hdr': 'HDR',
      'enableHdr': '启用 HDR 视频输出',
      'network': '网络',
      'bitrateLimit': '码率限制',
      'controller': '手柄',
      'hapticFeedback': '触觉反馈',
      'enableVibration': '启用震动反馈',
      'audio': '音频',
      'microphone': '麦克风',
      'enableVoiceChat': '启用语音聊天',
      'about': '关于',
      'version': '版本',
      'developer': '开发者',
      'basedOn': '基于',
      'language': '语言',
      'languageHint': '选择显示语言',
      'english': '英语',
      'chinese': '中文',
      'done': '完成',

      // Streaming Screen
      'disconnect': '断开连接',
      'connectionLost': '连接已断开',
      'reconnecting': '正在重新连接...',
      'quality': '画质',
      'latency': '延迟',
      'fps': '帧率',
      'authenticating': '正在验证...',
      'startingStream': '正在启动串流...',
      'disconnecting': '正在断开...',
      'disconnected': '已断开',
      'unknownError': '未知错误',
      'videoStream': '视频流',
      'goBack': '返回',
      'endRemotePlaySession': '结束远程游玩会话？',
      'streamSettings': '串流设置',
      'bitrateAuto': '自动 (10 Mbps)',

      // Errors
      'connectionFailed': '连接失败',
      'wakeUpFailed': '唤醒失败',
      'registrationError': '注册错误',
      'networkError': '网络错误',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  String getFormatted(String key, Map<String, String> args) {
    String result = get(key);
    args.forEach((argKey, argValue) {
      result = result.replaceAll('{$argKey}', argValue);
    });
    return result;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
