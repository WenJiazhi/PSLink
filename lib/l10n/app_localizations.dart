/// Minimal in-app localized strings.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final String locale;

  static const Map<String, Map<String, String>> _localizedStrings = {
    'en': {
      'appName': 'PSLink',
      'appDescription': 'PlayStation Remote Play Client',
      'ok': 'OK',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'delete': 'Delete',
      'save': 'Save',
      'retry': 'Retry',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'devices': 'Devices',
      'settings': 'Settings',
      'about': 'About',
      'noDevices': 'No devices found',
      'searchDevices': 'Search Devices',
      'searching': 'Searching...',
      'deviceReady': 'Ready',
      'deviceStandby': 'Standby',
      'deviceUnknown': 'Unknown',
      'wakeDevice': 'Wake',
      'connectDevice': 'Connect',
      'registerDevice': 'Register',
      'forgetDevice': 'Forget Device',
      'renameDevice': 'Rename',
      'registration': 'Registration',
      'enterPin': 'Enter the 8-digit PIN shown on your PlayStation',
      'pinHint': '8-digit PIN',
      'registering': 'Registering...',
      'registrationSuccess': 'Registration successful',
      'registrationFailed': 'Registration failed',
      'invalidPin': 'Invalid PIN format',
      'connecting': 'Connecting...',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'connectionFailed': 'Connection failed',
      'latency': 'Latency',
      'fps': 'FPS',
      'bitrate': 'Bitrate',
      'videoSettings': 'Video Settings',
      'resolution': 'Resolution',
      'frameRate': 'Frame Rate',
      'bitrateLabel': 'Bitrate (kbps)',
      'controllerSettings': 'Controller Settings',
      'controllerOpacity': 'Controller Opacity',
      'alwaysShowController': 'Always Show Controller',
      'audioSettings': 'Audio Settings',
      'audioLatency': 'Audio Latency (ms)',
      'advancedSettings': 'Advanced Settings',
      'enableHDR': 'Enable HDR',
      'enableHaptics': 'Enable Haptic Feedback',
      'enableAdaptiveTriggers': 'Enable Adaptive Triggers',
      'version': 'Version',
      'openSource': 'Open Source',
      'licenses': 'Licenses',
      'github': 'GitHub',
    },
    'zh': {
      'appName': 'PSLink',
      'appDescription': 'PlayStation 远程串流客户端',
      'ok': '确定',
      'cancel': '取消',
      'confirm': '确认',
      'delete': '删除',
      'save': '保存',
      'retry': '重试',
      'loading': '加载中...',
      'error': '错误',
      'success': '成功',
      'devices': '设备',
      'settings': '设置',
      'about': '关于',
      'noDevices': '未发现设备',
      'searchDevices': '搜索设备',
      'searching': '搜索中...',
      'deviceReady': '就绪',
      'deviceStandby': '待机',
      'deviceUnknown': '未知',
      'wakeDevice': '唤醒',
      'connectDevice': '连接',
      'registerDevice': '注册',
      'forgetDevice': '忘记设备',
      'renameDevice': '重命名',
      'registration': '注册设备',
      'enterPin': '请输入 PlayStation 屏幕上显示的 8 位 PIN 码',
      'pinHint': '8 位 PIN 码',
      'registering': '注册中...',
      'registrationSuccess': '注册成功',
      'registrationFailed': '注册失败',
      'invalidPin': 'PIN 码格式不正确',
      'connecting': '连接中...',
      'connected': '已连接',
      'disconnected': '已断开',
      'connectionFailed': '连接失败',
      'latency': '延迟',
      'fps': '帧率',
      'bitrate': '码率',
      'videoSettings': '视频设置',
      'resolution': '分辨率',
      'frameRate': '帧率',
      'bitrateLabel': '码率 (kbps)',
      'controllerSettings': '控制器设置',
      'controllerOpacity': '控制器透明度',
      'alwaysShowController': '始终显示控制器',
      'audioSettings': '音频设置',
      'audioLatency': '音频延迟 (毫秒)',
      'advancedSettings': '高级设置',
      'enableHDR': '启用 HDR',
      'enableHaptics': '启用触觉反馈',
      'enableAdaptiveTriggers': '启用自适应扳机',
      'version': '版本',
      'openSource': '开源协议',
      'licenses': '许可证',
      'github': 'GitHub',
    },
  };

  String get(String key) {
    return _localizedStrings[locale]?[key] ??
        _localizedStrings['en']?[key] ??
        key;
  }

  String get appName => get('appName');
  String get appDescription => get('appDescription');
  String get ok => get('ok');
  String get cancel => get('cancel');
  String get devices => get('devices');
  String get settings => get('settings');
  String get about => get('about');
  String get noDevices => get('noDevices');
  String get searchDevices => get('searchDevices');
  String get searching => get('searching');
  String get registration => get('registration');
  String get enterPin => get('enterPin');
  String get connecting => get('connecting');
  String get connected => get('connected');
  String get disconnected => get('disconnected');

  static AppLocalizations of(String locale) {
    return AppLocalizations(locale);
  }
}
