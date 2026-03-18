import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/controller_state.dart';
import '../models/ps_device.dart';
import '../models/stream_settings.dart';
import '../services/storage_service.dart';
import '../services/streaming_service.dart';

class PSStreamProvider extends ChangeNotifier {
  PSStreamProvider(this._storageService);

  final StreamingService _streamingService = StreamingService();
  final StorageService _storageService;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _statsSubscription;

  SessionState _sessionState = SessionState.disconnected;
  StreamSettings _settings = const StreamSettings();
  StreamStats? _stats;
  ControllerState _controllerState = ControllerState.empty;
  String? _error;
  bool _showController = false;

  SessionState get sessionState => _sessionState;
  StreamSettings get settings => _settings;
  StreamStats? get stats => _stats;
  ControllerState get controllerState => _controllerState;
  String? get error => _error;
  bool get showController => _showController;
  String? get videoStreamUrl => _streamingService.videoStreamUrl;
  bool get isConnected => _sessionState == SessionState.streaming;
  bool get isConnecting =>
      _sessionState == SessionState.connecting ||
      _sessionState == SessionState.authenticating;

  Stream<Uint8List> get videoStream => _streamingService.videoStream;
  Stream<Uint8List> get audioStream => _streamingService.audioStream;

  void initialize() {
    _settings = _storageService.getSettings();

    _stateSubscription = _streamingService.stateStream.listen((state) {
      _sessionState = state;
      if (state == SessionState.error) {
        _error = _streamingService.lastError;
      }
      notifyListeners();
    });

    _statsSubscription = _streamingService.statsStream.listen((stats) {
      _stats = stats;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<bool> startStreaming(PSDevice device) async {
    _error = null;
    notifyListeners();

    final success = await _streamingService.startSession(device, _settings);
    if (!success) {
      _error = _streamingService.lastError;
      notifyListeners();
    }
    return success;
  }

  Future<void> stopStreaming() async {
    await _streamingService.stopSession();
    _stats = null;
    _controllerState = ControllerState.empty;
    notifyListeners();
  }

  void updateControllerState(ControllerState state) {
    _controllerState = state;
    _streamingService.sendControllerInput(state);
    notifyListeners();
  }

  void pressButton(String button) {
    _controllerState = _setButtonState(_controllerState, button, true);
    _streamingService.sendControllerInput(_controllerState);
    notifyListeners();
  }

  void releaseButton(String button) {
    _controllerState = _setButtonState(_controllerState, button, false);
    _streamingService.sendControllerInput(_controllerState);
    notifyListeners();
  }

  void updateStick(String stick, double x, double y) {
    if (stick == 'left') {
      _controllerState = _controllerState.copyWith(
        leftStickX: x,
        leftStickY: y,
      );
    } else {
      _controllerState = _controllerState.copyWith(
        rightStickX: x,
        rightStickY: y,
      );
    }
    _streamingService.sendControllerInput(_controllerState);
    notifyListeners();
  }

  void updateTrigger(String trigger, double value) {
    if (trigger == 'l2') {
      _controllerState = _controllerState.copyWith(l2: value);
    } else {
      _controllerState = _controllerState.copyWith(r2: value);
    }
    _streamingService.sendControllerInput(_controllerState);
    notifyListeners();
  }

  void toggleController() {
    _showController = !_showController;
    notifyListeners();
  }

  Future<void> updateSettings(StreamSettings newSettings) async {
    _settings = newSettings;
    await _storageService.saveSettings(newSettings);
    await _streamingService.updateSettings(newSettings);
    notifyListeners();
  }

  Future<void> setResolution(String resolution) async {
    await updateSettings(_settings.copyWith(resolution: resolution));
  }

  Future<void> setFrameRate(int frameRate) async {
    await updateSettings(_settings.copyWith(frameRate: frameRate));
  }

  Future<void> setBitrate(int bitrate) async {
    await updateSettings(_settings.copyWith(bitrate: bitrate));
  }

  Future<void> setControllerOpacity(double opacity) async {
    await updateSettings(_settings.copyWith(controllerOpacity: opacity));
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  ControllerState _setButtonState(
    ControllerState state,
    String button,
    bool pressed,
  ) {
    switch (button) {
      case 'cross':
        return state.copyWith(cross: pressed);
      case 'circle':
        return state.copyWith(circle: pressed);
      case 'square':
        return state.copyWith(square: pressed);
      case 'triangle':
        return state.copyWith(triangle: pressed);
      case 'l1':
        return state.copyWith(l1: pressed);
      case 'r1':
        return state.copyWith(r1: pressed);
      case 'l3':
        return state.copyWith(l3: pressed);
      case 'r3':
        return state.copyWith(r3: pressed);
      case 'options':
        return state.copyWith(options: pressed);
      case 'share':
        return state.copyWith(share: pressed);
      case 'ps':
        return state.copyWith(ps: pressed);
      case 'touchpad':
        return state.copyWith(touchpad: pressed);
      case 'dpadUp':
        return state.copyWith(dpadUp: pressed);
      case 'dpadDown':
        return state.copyWith(dpadDown: pressed);
      case 'dpadLeft':
        return state.copyWith(dpadLeft: pressed);
      case 'dpadRight':
        return state.copyWith(dpadRight: pressed);
      default:
        return state;
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _statsSubscription?.cancel();
    _streamingService.dispose();
    super.dispose();
  }
}
