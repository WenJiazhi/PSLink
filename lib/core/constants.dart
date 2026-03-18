/// PlayStation Remote Play protocol constants.
class PSConstants {
  // Discovery and session ports.
  static const int discoveryPort = 9302;
  static const int discoveryPortPS4 = 987;
  static const int discoveryPortPS5 = 9302;
  static const int discoveryClientPort = 9303;
  static const int remotePlayPort = 9295;
  static const int registrationPort = 9295;
  static const List<int> discoveryPorts = [
    discoveryPortPS5,
    discoveryPortPS4,
  ];

  // Discovery protocol metadata.
  static const String broadcastAddress = '255.255.255.255';
  static const String ddpVersion = '00030010';
  static const String remotePlayUserAgent = 'remoteplay Windows';
  static const String remotePlayVersionPS4 = '10.0';
  static const String remotePlayVersionPS5 = '1.0';

  // Device types.
  static const int deviceTypePS4 = 0;
  static const int deviceTypePS5 = 1;

  // Video presets.
  static const Map<String, List<int>> resolutions = {
    '360p': [640, 360],
    '540p': [960, 540],
    '720p': [1280, 720],
    '1080p': [1920, 1080],
  };

  // FPS presets.
  static const List<int> frameRates = [30, 60];

  // Bitrate range (kbps).
  static const int minBitrate = 2000;
  static const int maxBitrate = 15000;
  static const int defaultBitrate = 8000;

  // Timeouts (ms).
  static const int connectionTimeout = 10000;
  static const int discoveryTimeout = 5000;

  // Heartbeat interval (ms).
  static const int heartbeatInterval = 1000;

  // Takion / UDP stream defaults.
  static const int defaultTakionRttMs = 1;
  static const int defaultTakionMtu = 1454;

  // Controller sampling rate (Hz).
  static const int controllerSampleRate = 120;
}

/// App theme colors.
class AppColors {
  // PlayStation blue palette.
  static const int primaryColor = 0xFF003791;
  static const int secondaryColor = 0xFF00439C;
  static const int accentColor = 0xFF0070D1;

  // Background colors.
  static const int backgroundColor = 0xFF121212;
  static const int surfaceColor = 0xFF1E1E1E;
  static const int cardColor = 0xFF2D2D2D;

  // Text colors.
  static const int textPrimary = 0xFFFFFFFF;
  static const int textSecondary = 0xFFB3B3B3;

  // Status colors.
  static const int successColor = 0xFF4CAF50;
  static const int errorColor = 0xFFF44336;
  static const int warningColor = 0xFFFF9800;
}

/// Route names.
class Routes {
  static const String splash = '/';
  static const String home = '/home';
  static const String discovery = '/discovery';
  static const String registration = '/registration';
  static const String streaming = '/streaming';
  static const String settings = '/settings';
  static const String about = '/about';
}
