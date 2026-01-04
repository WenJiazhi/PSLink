/// 串流设置模型
class StreamSettings {
  final String resolution;
  final int frameRate;
  final int bitrate;
  final bool enableHDR;
  final bool enableHaptics;
  final bool enableAdaptiveTriggers;
  final double controllerOpacity;
  final bool showControllerAlways;
  final int audioLatency;
  final bool enableMicrophone;

  const StreamSettings({
    this.resolution = '720p',
    this.frameRate = 60,
    this.bitrate = 8000,
    this.enableHDR = false,
    this.enableHaptics = true,
    this.enableAdaptiveTriggers = true,
    this.controllerOpacity = 0.7,
    this.showControllerAlways = false,
    this.audioLatency = 40,
    this.enableMicrophone = false,
  });

  int get resolutionWidth {
    switch (resolution) {
      case '360p':
        return 640;
      case '540p':
        return 960;
      case '720p':
        return 1280;
      case '1080p':
        return 1920;
      default:
        return 1280;
    }
  }

  int get resolutionHeight {
    switch (resolution) {
      case '360p':
        return 360;
      case '540p':
        return 540;
      case '720p':
        return 720;
      case '1080p':
        return 1080;
      default:
        return 720;
    }
  }

  StreamSettings copyWith({
    String? resolution,
    int? frameRate,
    int? bitrate,
    bool? enableHDR,
    bool? enableHaptics,
    bool? enableAdaptiveTriggers,
    double? controllerOpacity,
    bool? showControllerAlways,
    int? audioLatency,
    bool? enableMicrophone,
  }) {
    return StreamSettings(
      resolution: resolution ?? this.resolution,
      frameRate: frameRate ?? this.frameRate,
      bitrate: bitrate ?? this.bitrate,
      enableHDR: enableHDR ?? this.enableHDR,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      enableAdaptiveTriggers: enableAdaptiveTriggers ?? this.enableAdaptiveTriggers,
      controllerOpacity: controllerOpacity ?? this.controllerOpacity,
      showControllerAlways: showControllerAlways ?? this.showControllerAlways,
      audioLatency: audioLatency ?? this.audioLatency,
      enableMicrophone: enableMicrophone ?? this.enableMicrophone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resolution': resolution,
      'frameRate': frameRate,
      'bitrate': bitrate,
      'enableHDR': enableHDR,
      'enableHaptics': enableHaptics,
      'enableAdaptiveTriggers': enableAdaptiveTriggers,
      'controllerOpacity': controllerOpacity,
      'showControllerAlways': showControllerAlways,
      'audioLatency': audioLatency,
      'enableMicrophone': enableMicrophone,
    };
  }

  factory StreamSettings.fromJson(Map<String, dynamic> json) {
    return StreamSettings(
      resolution: json['resolution'] as String? ?? '720p',
      frameRate: json['frameRate'] as int? ?? 60,
      bitrate: json['bitrate'] as int? ?? 8000,
      enableHDR: json['enableHDR'] as bool? ?? false,
      enableHaptics: json['enableHaptics'] as bool? ?? true,
      enableAdaptiveTriggers: json['enableAdaptiveTriggers'] as bool? ?? true,
      controllerOpacity: (json['controllerOpacity'] as num?)?.toDouble() ?? 0.7,
      showControllerAlways: json['showControllerAlways'] as bool? ?? false,
      audioLatency: json['audioLatency'] as int? ?? 40,
      enableMicrophone: json['enableMicrophone'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'StreamSettings{resolution: $resolution, frameRate: $frameRate, '
        'bitrate: $bitrate, enableHDR: $enableHDR}';
  }
}
