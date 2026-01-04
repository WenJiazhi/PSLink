import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/controller_state.dart';
import '../protocol/constants.dart';

/// Virtual controller for touch-based input
class VirtualController {
  final ControllerState _state = ControllerState();
  final StreamController<ControllerState> _stateController =
      StreamController<ControllerState>.broadcast();

  Timer? _sendTimer;
  bool _isActive = false;

  // Touch zones for virtual buttons (normalized 0-1)
  final Map<int, TouchZone> _buttonZones = {
    PSConstants.buttonCross: TouchZone(0.9, 0.7, 0.08),
    PSConstants.buttonMoon: TouchZone(0.95, 0.6, 0.08),
    PSConstants.buttonBox: TouchZone(0.85, 0.6, 0.08),
    PSConstants.buttonPyramid: TouchZone(0.9, 0.5, 0.08),
    PSConstants.buttonDpadUp: TouchZone(0.1, 0.5, 0.06),
    PSConstants.buttonDpadDown: TouchZone(0.1, 0.7, 0.06),
    PSConstants.buttonDpadLeft: TouchZone(0.05, 0.6, 0.06),
    PSConstants.buttonDpadRight: TouchZone(0.15, 0.6, 0.06),
    PSConstants.buttonL1: TouchZone(0.1, 0.15, 0.1),
    PSConstants.buttonR1: TouchZone(0.9, 0.15, 0.1),
    PSConstants.buttonOptions: TouchZone(0.7, 0.1, 0.06),
    PSConstants.buttonShare: TouchZone(0.3, 0.1, 0.06),
    PSConstants.buttonPS: TouchZone(0.5, 0.9, 0.08),
    PSConstants.buttonTouchpad: TouchZone(0.5, 0.1, 0.15),
  };

  // Analog stick zones
  final TouchZone _leftStickZone = TouchZone(0.15, 0.4, 0.12);
  final TouchZone _rightStickZone = TouchZone(0.85, 0.8, 0.12);

  // Active touches for analog sticks
  int? _leftStickTouchId;
  int? _rightStickTouchId;
  double _leftStickCenterX = 0;
  double _leftStickCenterY = 0;
  double _rightStickCenterX = 0;
  double _rightStickCenterY = 0;

  ControllerState get state => _state;
  Stream<ControllerState> get stateStream => _stateController.stream;
  bool get isActive => _isActive;

  /// Start the virtual controller
  void start({int sendIntervalMs = 16}) {
    if (_isActive) return;
    _isActive = true;

    _sendTimer = Timer.periodic(
      Duration(milliseconds: sendIntervalMs),
      (_) => _emitState(),
    );
  }

  /// Stop the virtual controller
  void stop() {
    _isActive = false;
    _sendTimer?.cancel();
    _sendTimer = null;
    _state.setIdle();
  }

  /// Handle touch down event
  void onTouchDown(int pointerId, double x, double y) {
    // Check analog sticks first
    if (_leftStickTouchId == null && _leftStickZone.contains(x, y)) {
      _leftStickTouchId = pointerId;
      _leftStickCenterX = x;
      _leftStickCenterY = y;
      return;
    }

    if (_rightStickTouchId == null && _rightStickZone.contains(x, y)) {
      _rightStickTouchId = pointerId;
      _rightStickCenterX = x;
      _rightStickCenterY = y;
      return;
    }

    // Check button zones
    for (final entry in _buttonZones.entries) {
      if (entry.value.contains(x, y)) {
        _state.pressButton(entry.key);
        HapticFeedback.lightImpact();
        return;
      }
    }

    // Touchpad touch
    if (_buttonZones[PSConstants.buttonTouchpad]!.contains(x, y)) {
      final zone = _buttonZones[PSConstants.buttonTouchpad]!;
      final touchX = ((x - (zone.x - zone.radius)) / (zone.radius * 2) * 1920).round();
      final touchY = ((y - (zone.y - zone.radius / 2)) / zone.radius * 942).round();
      _state.startTouch(pointerId, touchX, touchY);
    }
  }

  /// Handle touch move event
  void onTouchMove(int pointerId, double x, double y) {
    // Update left stick
    if (pointerId == _leftStickTouchId) {
      final dx = (x - _leftStickCenterX) / _leftStickZone.radius;
      final dy = (y - _leftStickCenterY) / _leftStickZone.radius;
      _state.setLeftStick(
        (dx.clamp(-1, 1) * 32767).round(),
        (dy.clamp(-1, 1) * 32767).round(),
      );
      return;
    }

    // Update right stick
    if (pointerId == _rightStickTouchId) {
      final dx = (x - _rightStickCenterX) / _rightStickZone.radius;
      final dy = (y - _rightStickCenterY) / _rightStickZone.radius;
      _state.setRightStick(
        (dx.clamp(-1, 1) * 32767).round(),
        (dy.clamp(-1, 1) * 32767).round(),
      );
      return;
    }

    // Update touchpad touch
    _state.moveTouch(
      pointerId,
      (x * 1920).round(),
      (y * 942).round(),
    );
  }

  /// Handle touch up event
  void onTouchUp(int pointerId, double x, double y) {
    // Release left stick
    if (pointerId == _leftStickTouchId) {
      _leftStickTouchId = null;
      _state.setLeftStick(0, 0);
      return;
    }

    // Release right stick
    if (pointerId == _rightStickTouchId) {
      _rightStickTouchId = null;
      _state.setRightStick(0, 0);
      return;
    }

    // Release buttons
    for (final entry in _buttonZones.entries) {
      if (entry.value.contains(x, y)) {
        _state.releaseButton(entry.key);
        return;
      }
    }

    // Release touchpad touch
    _state.stopTouch(pointerId);
  }

  /// Press a button programmatically
  void pressButton(int button) {
    _state.pressButton(button);
    HapticFeedback.lightImpact();
  }

  /// Release a button programmatically
  void releaseButton(int button) {
    _state.releaseButton(button);
  }

  /// Set trigger value
  void setTrigger(bool isL2, int value) {
    if (isL2) {
      _state.setL2(value);
    } else {
      _state.setR2(value);
    }
  }

  /// Update motion data from device sensors
  void updateMotion({
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? accelX,
    double? accelY,
    double? accelZ,
  }) {
    _state.setMotion(
      gyroX: gyroX,
      gyroY: gyroY,
      gyroZ: gyroZ,
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
    );
  }

  void _emitState() {
    if (!_isActive) return;
    _stateController.add(_state.clone());
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}

/// Touch zone for button hit testing
class TouchZone {
  final double x; // Center X (0-1)
  final double y; // Center Y (0-1)
  final double radius; // Radius (0-1)

  TouchZone(this.x, this.y, this.radius);

  bool contains(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    return (dx * dx + dy * dy) <= (radius * radius);
  }
}

/// Physical controller support via Game Controller framework
class PhysicalController {
  final ControllerState _state = ControllerState();
  final StreamController<ControllerState> _stateController =
      StreamController<ControllerState>.broadcast();

  final bool _isConnected = false;

  ControllerState get state => _state;
  Stream<ControllerState> get stateStream => _stateController.stream;
  bool get isConnected => _isConnected;

  /// Initialize physical controller support
  Future<void> initialize() async {
    // This would use platform channels to access iOS Game Controller framework
    // For now, we'll just set up the basic structure
    debugPrint('Physical controller support initialized');
  }

  /// Process controller input event
  void processInput(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final value = event['value'];

    switch (type) {
      case 'button':
        final button = event['button'] as int;
        final pressed = value as bool;
        if (pressed) {
          _state.pressButton(button);
        } else {
          _state.releaseButton(button);
        }
        break;

      case 'leftStick':
        _state.setLeftStick(
          ((value['x'] as double) * 32767).round(),
          ((value['y'] as double) * 32767).round(),
        );
        break;

      case 'rightStick':
        _state.setRightStick(
          ((value['x'] as double) * 32767).round(),
          ((value['y'] as double) * 32767).round(),
        );
        break;

      case 'l2':
        _state.setL2(((value as double) * 255).round());
        break;

      case 'r2':
        _state.setR2(((value as double) * 255).round());
        break;

      case 'motion':
        _state.setMotion(
          gyroX: value['gyroX'] as double?,
          gyroY: value['gyroY'] as double?,
          gyroZ: value['gyroZ'] as double?,
          accelX: value['accelX'] as double?,
          accelY: value['accelY'] as double?,
          accelZ: value['accelZ'] as double?,
        );
        break;
    }

    _stateController.add(_state.clone());
  }

  void dispose() {
    _stateController.close();
  }
}
