class ControllerState {
  final bool cross;
  final bool circle;
  final bool square;
  final bool triangle;
  final bool l1;
  final bool r1;
  final bool l3;
  final bool r3;
  final bool options;
  final bool share;
  final bool ps;
  final bool touchpad;
  final bool dpadUp;
  final bool dpadDown;
  final bool dpadLeft;
  final bool dpadRight;
  final bool mute;

  final double leftStickX;
  final double leftStickY;
  final double rightStickX;
  final double rightStickY;

  final double l2;
  final double r2;

  final double? touchX1;
  final double? touchY1;
  final double? touchX2;
  final double? touchY2;

  final double? gyroX;
  final double? gyroY;
  final double? gyroZ;
  final double? accelX;
  final double? accelY;
  final double? accelZ;

  const ControllerState({
    this.cross = false,
    this.circle = false,
    this.square = false,
    this.triangle = false,
    this.l1 = false,
    this.r1 = false,
    this.l3 = false,
    this.r3 = false,
    this.options = false,
    this.share = false,
    this.ps = false,
    this.touchpad = false,
    this.dpadUp = false,
    this.dpadDown = false,
    this.dpadLeft = false,
    this.dpadRight = false,
    this.mute = false,
    this.leftStickX = 0.0,
    this.leftStickY = 0.0,
    this.rightStickX = 0.0,
    this.rightStickY = 0.0,
    this.l2 = 0.0,
    this.r2 = 0.0,
    this.touchX1,
    this.touchY1,
    this.touchX2,
    this.touchY2,
    this.gyroX,
    this.gyroY,
    this.gyroZ,
    this.accelX,
    this.accelY,
    this.accelZ,
  });

  List<int> toBytes() {
    final bytes = <int>[];

    var buttons = 0;
    if (cross) buttons |= 0x0001;
    if (circle) buttons |= 0x0002;
    if (square) buttons |= 0x0004;
    if (triangle) buttons |= 0x0008;
    if (l1) buttons |= 0x0010;
    if (r1) buttons |= 0x0020;
    if (l3) buttons |= 0x0040;
    if (r3) buttons |= 0x0080;
    if (options) buttons |= 0x0100;
    if (share) buttons |= 0x0200;
    if (ps) buttons |= 0x0400;
    if (touchpad) buttons |= 0x0800;
    if (dpadUp) buttons |= 0x1000;
    if (dpadDown) buttons |= 0x2000;
    if (dpadLeft) buttons |= 0x4000;
    if (dpadRight) buttons |= 0x8000;
    if (mute) buttons |= 0x10000;

    bytes.addAll([
      buttons & 0xFF,
      (buttons >> 8) & 0xFF,
      (buttons >> 16) & 0xFF,
      (buttons >> 24) & 0xFF,
    ]);

    bytes.addAll(_encodeAxis(leftStickX));
    bytes.addAll(_encodeAxis(leftStickY));
    bytes.addAll(_encodeAxis(rightStickX));
    bytes.addAll(_encodeAxis(rightStickY));
    bytes.add((l2 * 255).round().clamp(0, 255));
    bytes.add((r2 * 255).round().clamp(0, 255));

    return bytes;
  }

  List<int> _encodeAxis(double value) {
    final intValue = (value * 32767).round().clamp(-32768, 32767);
    return [intValue & 0xFF, (intValue >> 8) & 0xFF];
  }

  ControllerState copyWith({
    bool? cross,
    bool? circle,
    bool? square,
    bool? triangle,
    bool? l1,
    bool? r1,
    bool? l3,
    bool? r3,
    bool? options,
    bool? share,
    bool? ps,
    bool? touchpad,
    bool? dpadUp,
    bool? dpadDown,
    bool? dpadLeft,
    bool? dpadRight,
    bool? mute,
    double? leftStickX,
    double? leftStickY,
    double? rightStickX,
    double? rightStickY,
    double? l2,
    double? r2,
    double? touchX1,
    double? touchY1,
    double? touchX2,
    double? touchY2,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? accelX,
    double? accelY,
    double? accelZ,
  }) {
    return ControllerState(
      cross: cross ?? this.cross,
      circle: circle ?? this.circle,
      square: square ?? this.square,
      triangle: triangle ?? this.triangle,
      l1: l1 ?? this.l1,
      r1: r1 ?? this.r1,
      l3: l3 ?? this.l3,
      r3: r3 ?? this.r3,
      options: options ?? this.options,
      share: share ?? this.share,
      ps: ps ?? this.ps,
      touchpad: touchpad ?? this.touchpad,
      dpadUp: dpadUp ?? this.dpadUp,
      dpadDown: dpadDown ?? this.dpadDown,
      dpadLeft: dpadLeft ?? this.dpadLeft,
      dpadRight: dpadRight ?? this.dpadRight,
      mute: mute ?? this.mute,
      leftStickX: leftStickX ?? this.leftStickX,
      leftStickY: leftStickY ?? this.leftStickY,
      rightStickX: rightStickX ?? this.rightStickX,
      rightStickY: rightStickY ?? this.rightStickY,
      l2: l2 ?? this.l2,
      r2: r2 ?? this.r2,
      touchX1: touchX1 ?? this.touchX1,
      touchY1: touchY1 ?? this.touchY1,
      touchX2: touchX2 ?? this.touchX2,
      touchY2: touchY2 ?? this.touchY2,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      accelX: accelX ?? this.accelX,
      accelY: accelY ?? this.accelY,
      accelZ: accelZ ?? this.accelZ,
    );
  }

  static const ControllerState empty = ControllerState();

  @override
  String toString() {
    final pressedButtons = <String>[];
    if (cross) pressedButtons.add('X');
    if (circle) pressedButtons.add('O');
    if (square) pressedButtons.add('□');
    if (triangle) pressedButtons.add('△');
    if (l1) pressedButtons.add('L1');
    if (r1) pressedButtons.add('R1');
    if (l2 > 0.1) pressedButtons.add('L2:${(l2 * 100).toInt()}%');
    if (r2 > 0.1) pressedButtons.add('R2:${(r2 * 100).toInt()}%');

    return 'ControllerState{buttons: [${pressedButtons.join(', ')}], '
        'L:(${leftStickX.toStringAsFixed(2)},${leftStickY.toStringAsFixed(2)}), '
        'R:(${rightStickX.toStringAsFixed(2)},${rightStickY.toStringAsFixed(2)})}';
  }
}
