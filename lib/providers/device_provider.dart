import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ps_device.dart';
import '../services/discovery_service.dart';
import '../services/storage_service.dart';

/// 设备状态管理 Provider
class DeviceProvider extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final StorageService _storageService;

  DeviceProvider(this._storageService);

  // 状态
  List<PSDevice> _discoveredDevices = [];
  List<PSDevice> _savedDevices = [];
  PSDevice? _selectedDevice;
  bool _isDiscovering = false;
  String? _error;

  // Getters
  List<PSDevice> get discoveredDevices => _discoveredDevices;
  List<PSDevice> get savedDevices => _savedDevices;
  PSDevice? get selectedDevice => _selectedDevice;
  bool get isDiscovering => _isDiscovering;
  String? get error => _error;

  /// 合并发现的和已保存的设备列表
  List<PSDevice> get allDevices {
    final deviceMap = <String, PSDevice>{};

    // 先添加已保存的设备
    for (final device in _savedDevices) {
      deviceMap[device.hostId] = device;
    }

    // 用发现的设备更新状态
    for (final device in _discoveredDevices) {
      final saved = deviceMap[device.hostId];
      if (saved != null) {
        // 更新已保存设备的状态
        deviceMap[device.hostId] = saved.copyWith(
          stateValue: device.stateValue,
          ipAddress: device.ipAddress, // IP 可能变化
        );
      } else {
        deviceMap[device.hostId] = device;
      }
    }

    return deviceMap.values.toList()
      ..sort((a, b) {
        // 已注册的设备优先
        if (a.isRegistered != b.isRegistered) {
          return a.isRegistered ? -1 : 1;
        }
        // 然后按最后连接时间
        final aTime = a.lastConnected ?? DateTime(1970);
        final bTime = b.lastConnected ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
  }

  /// 初始化
  Future<void> initialize() async {
    await loadSavedDevices();

    // 尝试加载上次选择的设备
    final lastDevice = _storageService.getLastDevice();
    if (lastDevice != null) {
      _selectedDevice = lastDevice;
      notifyListeners();
    }
  }

  /// 加载已保存的设备
  Future<void> loadSavedDevices() async {
    _savedDevices = _storageService.getDevices();
    notifyListeners();
  }

  /// 开始发现设备
  Future<void> startDiscovery({bool continuous = false}) async {
    if (_isDiscovering) return;

    _isDiscovering = true;
    _error = null;
    notifyListeners();

    try {
      await _discoveryService.startDiscovery(continuous: continuous);

      // 监听发现的设备
      _discoveryService.deviceStream?.listen((device) {
        if (!_discoveredDevices.any((d) => d.hostId == device.hostId)) {
          _discoveredDevices.add(device);
          notifyListeners();
        }
      });

      // 更新发现列表
      await Future.delayed(const Duration(seconds: 3));
      _discoveredDevices = _discoveryService.devices;
      notifyListeners();
    } catch (e) {
      _error = '设备发现失败: $e';
      notifyListeners();
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  /// 停止发现
  void stopDiscovery() {
    _discoveryService.stopDiscovery();
    _isDiscovering = false;
    notifyListeners();
  }

  /// 唤醒设备
  Future<bool> wakeDevice(PSDevice device) async {
    return await _discoveryService.wakeDevice(device);
  }

  /// 选择设备
  void selectDevice(PSDevice device) {
    _selectedDevice = device;
    _storageService.saveLastDeviceId(device.hostId);
    notifyListeners();
  }

  /// 保存/更新设备
  Future<void> saveDevice(PSDevice device) async {
    await _storageService.saveDevice(device);
    await loadSavedDevices();

    // 如果当前选中的是这个设备，更新它
    if (_selectedDevice?.hostId == device.hostId) {
      _selectedDevice = device;
    }

    notifyListeners();
  }

  /// 删除设备
  Future<void> deleteDevice(String hostId) async {
    await _storageService.deleteDevice(hostId);
    await loadSavedDevices();

    if (_selectedDevice?.hostId == hostId) {
      _selectedDevice = null;
      _storageService.saveLastDeviceId(null);
    }

    notifyListeners();
  }

  /// 更新设备昵称
  Future<void> updateDeviceNickname(String hostId, String nickname) async {
    final device = _storageService.getDevice(hostId);
    if (device != null) {
      await saveDevice(device.copyWith(nickname: nickname));
    }
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    super.dispose();
  }
}
