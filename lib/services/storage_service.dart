import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import '../models/ps_device.dart';
import '../models/stream_settings.dart';

/// 存储服务
/// 管理设备信息和设置的持久化存储
class StorageService {
  final Logger _logger = Logger();

  static const String _devicesBoxName = 'devices';
  static const String _settingsKey = 'stream_settings';
  static const String _lastDeviceKey = 'last_device_id';

  late Box<Map> _devicesBox;
  late SharedPreferences _prefs;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// 初始化存储
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 初始化 Hive
      await Hive.initFlutter();

      // 打开设备存储盒
      _devicesBox = await Hive.openBox<Map>(_devicesBoxName);

      // 初始化 SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      _initialized = true;
      _logger.i('Storage initialized');
    } catch (e) {
      _logger.e('Failed to initialize storage', error: e);
      rethrow;
    }
  }

  /// 保存设备
  Future<void> saveDevice(PSDevice device) async {
    _ensureInitialized();
    await _devicesBox.put(device.hostId, device.toJson());
    _logger.d('Saved device: ${device.hostName}');
  }

  /// 获取所有已保存的设备
  List<PSDevice> getDevices() {
    _ensureInitialized();
    return _devicesBox.values
        .map((json) => PSDevice.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// 获取单个设备
  PSDevice? getDevice(String hostId) {
    _ensureInitialized();
    final json = _devicesBox.get(hostId);
    if (json == null) return null;
    return PSDevice.fromJson(Map<String, dynamic>.from(json));
  }

  /// 删除设备
  Future<void> deleteDevice(String hostId) async {
    _ensureInitialized();
    await _devicesBox.delete(hostId);
    _logger.d('Deleted device: $hostId');
  }

  /// 更新设备最后连接时间
  Future<void> updateLastConnected(String hostId) async {
    final device = getDevice(hostId);
    if (device != null) {
      await saveDevice(device.copyWith(lastConnected: DateTime.now()));
    }
  }

  /// 保存串流设置
  Future<void> saveSettings(StreamSettings settings) async {
    _ensureInitialized();
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    _logger.d('Saved stream settings');
  }

  /// 获取串流设置
  StreamSettings getSettings() {
    _ensureInitialized();
    final json = _prefs.getString(_settingsKey);
    if (json == null) return const StreamSettings();
    try {
      return StreamSettings.fromJson(jsonDecode(json));
    } catch (e) {
      _logger.w('Failed to parse settings, using defaults', error: e);
      return const StreamSettings();
    }
  }

  /// 保存最后使用的设备 ID
  Future<void> saveLastDeviceId(String? hostId) async {
    _ensureInitialized();
    if (hostId == null) {
      await _prefs.remove(_lastDeviceKey);
    } else {
      await _prefs.setString(_lastDeviceKey, hostId);
    }
  }

  /// 获取最后使用的设备 ID
  String? getLastDeviceId() {
    _ensureInitialized();
    return _prefs.getString(_lastDeviceKey);
  }

  /// 获取最后使用的设备
  PSDevice? getLastDevice() {
    final hostId = getLastDeviceId();
    if (hostId == null) return null;
    return getDevice(hostId);
  }

  /// 清除所有数据
  Future<void> clearAll() async {
    _ensureInitialized();
    await _devicesBox.clear();
    await _prefs.clear();
    _logger.i('All storage cleared');
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('StorageService not initialized. Call initialize() first.');
    }
  }

  /// 关闭存储
  Future<void> close() async {
    await _devicesBox.close();
    _initialized = false;
  }
}
