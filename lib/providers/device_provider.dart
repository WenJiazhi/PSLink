import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ps_device.dart';
import '../services/discovery_service.dart';
import '../services/storage_service.dart';

class DeviceProvider extends ChangeNotifier {
  DeviceProvider(this._storageService);

  final DiscoveryService _discoveryService = DiscoveryService();
  final StorageService _storageService;

  StreamSubscription<PSDevice>? _discoverySubscription;

  List<PSDevice> _discoveredDevices = [];
  List<PSDevice> _savedDevices = [];
  PSDevice? _selectedDevice;
  bool _isDiscovering = false;
  String? _error;

  List<PSDevice> get discoveredDevices => _discoveredDevices;
  List<PSDevice> get savedDevices => _savedDevices;
  PSDevice? get selectedDevice => _selectedDevice;
  bool get isDiscovering => _isDiscovering;
  String? get error => _error;

  List<PSDevice> get allDevices {
    final deviceMap = <String, PSDevice>{};

    for (final device in _savedDevices) {
      deviceMap[device.hostId] = device;
    }

    for (final device in _discoveredDevices) {
      final saved = deviceMap[device.hostId];
      if (saved != null) {
        deviceMap[device.hostId] = saved.copyWith(
          stateValue: device.stateValue,
          ipAddress: device.ipAddress,
          systemVersion: device.systemVersion,
          deviceTypeValue: device.deviceTypeValue,
        );
      } else {
        deviceMap[device.hostId] = device;
      }
    }

    return deviceMap.values.toList()
      ..sort((a, b) {
        if (a.isRegistered != b.isRegistered) {
          return a.isRegistered ? -1 : 1;
        }
        final aTime = a.lastConnected ?? DateTime(1970);
        final bTime = b.lastConnected ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
  }

  Future<void> initialize() async {
    await loadSavedDevices();

    final lastDevice = _storageService.getLastDevice();
    if (lastDevice != null) {
      _selectedDevice = lastDevice;
      notifyListeners();
    }
  }

  Future<void> loadSavedDevices() async {
    _savedDevices = _storageService.getDevices();
    notifyListeners();
  }

  Future<void> startDiscovery({bool continuous = false}) async {
    if (_isDiscovering) {
      return;
    }

    _isDiscovering = true;
    _error = null;
    _discoveredDevices = [];
    notifyListeners();

    try {
      await _discoveryService.startDiscovery(continuous: continuous);
      await _discoverySubscription?.cancel();
      _discoverySubscription = _discoveryService.deviceStream?.listen((device) {
        final existingIndex = _discoveredDevices.indexWhere(
          (item) => item.hostId == device.hostId,
        );
        if (existingIndex >= 0) {
          _discoveredDevices[existingIndex] = device;
        } else {
          _discoveredDevices.add(device);
        }
        notifyListeners();
      });

      await Future.delayed(const Duration(seconds: 3));
      _discoveredDevices = _discoveryService.devices;
      notifyListeners();
    } catch (e) {
      _error = 'Device discovery failed: $e';
      notifyListeners();
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  void stopDiscovery() {
    _discoveryService.stopDiscovery();
    _isDiscovering = false;
    notifyListeners();
  }

  Future<bool> wakeDevice(PSDevice device) async {
    return _discoveryService.wakeDevice(device);
  }

  void selectDevice(PSDevice device) {
    _selectedDevice = device;
    _storageService.saveLastDeviceId(device.hostId);
    notifyListeners();
  }

  Future<void> saveDevice(PSDevice device) async {
    await _storageService.saveDevice(device);
    await loadSavedDevices();

    if (_selectedDevice?.hostId == device.hostId) {
      _selectedDevice = device;
    }

    notifyListeners();
  }

  Future<void> deleteDevice(String hostId) async {
    await _storageService.deleteDevice(hostId);
    await loadSavedDevices();

    if (_selectedDevice?.hostId == hostId) {
      _selectedDevice = null;
      await _storageService.saveLastDeviceId(null);
    }

    notifyListeners();
  }

  Future<void> updateDeviceNickname(String hostId, String nickname) async {
    final device = _storageService.getDevice(hostId);
    if (device != null) {
      await saveDevice(device.copyWith(nickname: nickname));
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _discoveryService.dispose();
    super.dispose();
  }
}
