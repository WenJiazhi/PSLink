/// PlayStation Remote Play 协议常量
class PSConstants {
  // PlayStation Remote Play 默认端口
  static const int discoveryPort = 9302;
  static const int remotePlayPort = 9295;
  static const int registrationPort = 9295;

  // UDP 广播地址
  static const String broadcastAddress = '255.255.255.255';

  // 设备类型
  static const int deviceTypePS4 = 0;
  static const int deviceTypePS5 = 1;

  // 视频分辨率选项
  static const Map<String, List<int>> resolutions = {
    '360p': [640, 360],
    '540p': [960, 540],
    '720p': [1280, 720],
    '1080p': [1920, 1080],
  };

  // 帧率选项
  static const List<int> frameRates = [30, 60];

  // 码率范围 (kbps)
  static const int minBitrate = 2000;
  static const int maxBitrate = 15000;
  static const int defaultBitrate = 8000;

  // 连接超时 (毫秒)
  static const int connectionTimeout = 10000;
  static const int discoveryTimeout = 5000;

  // 心跳间隔 (毫秒)
  static const int heartbeatInterval = 1000;

  // 控制器输入采样率 (Hz)
  static const int controllerSampleRate = 120;
}

/// 应用主题颜色
class AppColors {
  // PlayStation 蓝色主题
  static const int primaryColor = 0xFF003791;
  static const int secondaryColor = 0xFF00439C;
  static const int accentColor = 0xFF0070D1;

  // 背景色
  static const int backgroundColor = 0xFF121212;
  static const int surfaceColor = 0xFF1E1E1E;
  static const int cardColor = 0xFF2D2D2D;

  // 文字颜色
  static const int textPrimary = 0xFFFFFFFF;
  static const int textSecondary = 0xFFB3B3B3;

  // 状态颜色
  static const int successColor = 0xFF4CAF50;
  static const int errorColor = 0xFFF44336;
  static const int warningColor = 0xFFFF9800;
}

/// 路由名称
class Routes {
  static const String splash = '/';
  static const String home = '/home';
  static const String discovery = '/discovery';
  static const String registration = '/registration';
  static const String streaming = '/streaming';
  static const String settings = '/settings';
  static const String about = '/about';
}
