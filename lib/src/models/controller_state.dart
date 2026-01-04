import '../protocol/constants.dart';

/// Represents the current state of the controller
class ControllerState {
  /// Button bitmask
  int buttons;

  /// Trigger states (0-255)
  int l2State;
  int r2State;

  /// Analog stick positions (-32768 to 32767)
  int leftX;
  int leftY;
  int rightX;
  int rightY;

  /// Motion data
  double gyroX;
  double gyroY;
  double gyroZ;
  double accelX;
  double accelY;
  double accelZ;

  /// Orientation quaternion
  double orientX;
  double orientY;
  double orientZ;
  double orientW;

  /// Touchpad touches
  List<TouchPoint> touches;

  ControllerState()
      : buttons = 0,
        l2State = 0,
        r2State = 0,
        leftX = 0,
        leftY = 0,
        rightX = 0,
        rightY = 0,
        gyroX = 0,
        gyroY = 0,
        gyroZ = 0,
        accelX = 0,
        accelY = 0,
        accelZ = 0,
        orientX = 0,
        orientY = 0,
        orientZ = 0,
        orientW = 1,
        touches = [];

  void setIdle() {
    buttons = 0;
    l2State = 0;
    r2State = 0;
    leftX = 0;
    leftY = 0;
    rightX = 0;
    rightY = 0;
  }

  void pressButton(int button) {
    buttons |= button;
  }

  void releaseButton(int button) {
    buttons &= ~button;
  }

  bool isButtonPressed(int button) {
    return (buttons & button) != 0;
  }

  void setLeftStick(int x, int y) {
    leftX = x.clamp(-32768, 32767);
    leftY = y.clamp(-32768, 32767);
  }

  void setRightStick(int x, int y) {
    rightX = x.clamp(-32768, 32767);
    rightY = y.clamp(-32768, 32767);
  }

  void setL2(int value) {
    l2State = value.clamp(0, 255);
    if (value > 0) {
      buttons |= PSConstants.analogButtonL2;
    } else {
      buttons &= ~PSConstants.analogButtonL2;
    }
  }

  void setR2(int value) {
    r2State = value.clamp(0, 255);
    if (value > 0) {
      buttons |= PSConstants.analogButtonR2;
    } else {
      buttons &= ~PSConstants.analogButtonR2;
    }
  }

  void startTouch(int id, int x, int y) {
    if (touches.length < PSConstants.maxTouches) {
      touches.add(TouchPoint(id: id, x: x, y: y));
    }
  }

  void moveTouch(int id, int x, int y) {
    for (var i = 0; i < touches.length; i++) {
      if (touches[i].id == id) {
        touches[i] = TouchPoint(id: id, x: x, y: y);
        break;
      }
    }
  }

  void stopTouch(int id) {
    touches.removeWhere((t) => t.id == id);
  }

  void setMotion({
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? accelX,
    double? accelY,
    double? accelZ,
  }) {
    if (gyroX != null) this.gyroX = gyroX;
    if (gyroY != null) this.gyroY = gyroY;
    if (gyroZ != null) this.gyroZ = gyroZ;
    if (accelX != null) this.accelX = accelX;
    if (accelY != null) this.accelY = accelY;
    if (accelZ != null) this.accelZ = accelZ;
  }

  void setOrientation(double x, double y, double z, double w) {
    orientX = x;
    orientY = y;
    orientZ = z;
    orientW = w;
  }

  ControllerState clone() {
    final state = ControllerState()
      ..buttons = buttons
      ..l2State = l2State
      ..r2State = r2State
      ..leftX = leftX
      ..leftY = leftY
      ..rightX = rightX
      ..rightY = rightY
      ..gyroX = gyroX
      ..gyroY = gyroY
      ..gyroZ = gyroZ
      ..accelX = accelX
      ..accelY = accelY
      ..accelZ = accelZ
      ..orientX = orientX
      ..orientY = orientY
      ..orientZ = orientZ
      ..orientW = orientW
      ..touches = touches.map((t) => TouchPoint(id: t.id, x: t.x, y: t.y)).toList();
    return state;
  }
}

class TouchPoint {
  final int id;
  final int x;
  final int y;

  TouchPoint({required this.id, required this.x, required this.y});
}
