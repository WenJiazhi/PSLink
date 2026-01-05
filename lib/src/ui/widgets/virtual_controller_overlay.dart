import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pslink/src/models/controller_state.dart';
import 'package:pslink/src/protocol/constants.dart';
import 'package:pslink/src/services/controller_service.dart';

class VirtualControllerOverlay extends StatefulWidget {
  final VirtualController controller;
  final Function(ControllerState) onControllerStateChanged;

  const VirtualControllerOverlay({
    super.key,
    required this.controller,
    required this.onControllerStateChanged,
  });

  @override
  State<VirtualControllerOverlay> createState() =>
      _VirtualControllerOverlayState();
}

class _VirtualControllerOverlayState extends State<VirtualControllerOverlay> {
  final Map<int, Offset> _activeTouches = {};
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.controller.stateStream.listen(widget.onControllerStateChanged);
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _handlePointerDown(event, width, height),
          onPointerMove: (event) => _handlePointerMove(event, width, height),
          onPointerUp: (event) => _handlePointerUp(event, width, height),
          onPointerCancel: (event) => _handlePointerUp(event, width, height),
          child: Stack(
            children: [
              // Left analog stick
              _buildAnalogStick(
                left: width * 0.05,
                top: height * 0.3,
                size: width * 0.18,
                isLeft: true,
              ),

              // D-Pad
              _buildDPad(
                left: width * 0.05,
                top: height * 0.55,
                size: width * 0.15,
              ),

              // Right analog stick
              _buildAnalogStick(
                left: width * 0.77,
                top: height * 0.55,
                size: width * 0.18,
                isLeft: false,
              ),

              // Face buttons (Cross, Moon, Box, Pyramid)
              _buildFaceButtons(
                left: width * 0.77,
                top: height * 0.15,
                size: width * 0.18,
              ),

              // L1/R1 buttons
              _buildShoulderButton(
                left: width * 0.08,
                top: height * 0.05,
                width: width * 0.12,
                label: 'L1',
                button: PSConstants.buttonL1,
              ),
              _buildShoulderButton(
                left: width * 0.80,
                top: height * 0.05,
                width: width * 0.12,
                label: 'R1',
                button: PSConstants.buttonR1,
              ),

              // L2/R2 triggers
              _buildTrigger(
                left: width * 0.02,
                top: height * 0.08,
                width: width * 0.05,
                height: height * 0.3,
                isL2: true,
              ),
              _buildTrigger(
                left: width * 0.93,
                top: height * 0.08,
                width: width * 0.05,
                height: height * 0.3,
                isL2: false,
              ),

              // Options and Share
              _buildSmallButton(
                left: width * 0.35,
                top: height * 0.15,
                label: 'Share',
                button: PSConstants.buttonShare,
              ),
              _buildSmallButton(
                left: width * 0.58,
                top: height * 0.15,
                label: 'Opt',
                button: PSConstants.buttonOptions,
              ),

              // PS button
              _buildPSButton(
                left: width * 0.46,
                top: height * 0.85,
              ),

              // Touchpad
              _buildTouchpad(
                left: width * 0.35,
                top: height * 0.03,
                width: width * 0.30,
                height: height * 0.08,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalogStick({
    required double left,
    required double top,
    required double size,
    required bool isLeft,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Center(
          child: Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.3),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDPad({
    required double left,
    required double top,
    required double size,
  }) {
    final buttonSize = size * 0.35;
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            // Up
            Positioned(
              left: size * 0.325,
              top: 0,
              child: _buildDPadButton(buttonSize, 'up', PSConstants.buttonDpadUp),
            ),
            // Down
            Positioned(
              left: size * 0.325,
              bottom: 0,
              child: _buildDPadButton(buttonSize, 'down', PSConstants.buttonDpadDown),
            ),
            // Left
            Positioned(
              left: 0,
              top: size * 0.325,
              child: _buildDPadButton(buttonSize, 'left', PSConstants.buttonDpadLeft),
            ),
            // Right
            Positioned(
              right: 0,
              top: size * 0.325,
              child: _buildDPadButton(buttonSize, 'right', PSConstants.buttonDpadRight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDPadButton(double size, String direction, int button) {
    return GestureDetector(
      onTapDown: (_) => widget.controller.pressButton(button),
      onTapUp: (_) => widget.controller.releaseButton(button),
      onTapCancel: () => widget.controller.releaseButton(button),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          _getDPadIcon(direction),
          color: Colors.white.withValues(alpha: 0.5),
          size: size * 0.6,
        ),
      ),
    );
  }

  IconData _getDPadIcon(String direction) {
    switch (direction) {
      case 'up':
        return CupertinoIcons.chevron_up;
      case 'down':
        return CupertinoIcons.chevron_down;
      case 'left':
        return CupertinoIcons.chevron_left;
      case 'right':
        return CupertinoIcons.chevron_right;
      default:
        return CupertinoIcons.circle;
    }
  }

  Widget _buildFaceButtons({
    required double left,
    required double top,
    required double size,
  }) {
    final buttonSize = size * 0.35;
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            // Triangle (top)
            Positioned(
              left: size * 0.325,
              top: 0,
              child: _buildFaceButton(
                buttonSize,
                PSConstants.buttonPyramid,
                color: const Color(0xFF00D9C0),
                icon: Icons.change_history,
              ),
            ),
            // Cross (bottom)
            Positioned(
              left: size * 0.325,
              bottom: 0,
              child: _buildFaceButton(
                buttonSize,
                PSConstants.buttonCross,
                color: const Color(0xFF6E9EFF),
                icon: CupertinoIcons.xmark,
              ),
            ),
            // Square (left)
            Positioned(
              left: 0,
              top: size * 0.325,
              child: _buildFaceButton(
                buttonSize,
                PSConstants.buttonBox,
                color: const Color(0xFFFF6B9D),
                icon: CupertinoIcons.square,
              ),
            ),
            // Circle (right)
            Positioned(
              right: 0,
              top: size * 0.325,
              child: _buildFaceButton(
                buttonSize,
                PSConstants.buttonMoon,
                color: const Color(0xFFFF6B6B),
                icon: CupertinoIcons.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceButton(
    double size,
    int button, {
    required Color color,
    required IconData icon,
  }) {
    return GestureDetector(
      onTapDown: (_) => widget.controller.pressButton(button),
      onTapUp: (_) => widget.controller.releaseButton(button),
      onTapCancel: () => widget.controller.releaseButton(button),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: color.withValues(alpha: 0.7),
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildShoulderButton({
    required double left,
    required double top,
    required double width,
    required String label,
    required int button,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTapDown: (_) => widget.controller.pressButton(button),
        onTapUp: (_) => widget.controller.releaseButton(button),
        onTapCancel: () => widget.controller.releaseButton(button),
        child: Container(
          width: width,
          height: width * 0.5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: width * 0.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrigger({
    required double left,
    required double top,
    required double width,
    required double height,
    required bool isL2,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          final value = ((details.localPosition.dy / height) * 255)
              .clamp(0, 255)
              .round();
          widget.controller.setTrigger(isL2, value);
        },
        onVerticalDragEnd: (_) {
          widget.controller.setTrigger(isL2, 0);
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(width / 2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              isL2 ? 'L2' : 'R2',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: width * 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required double left,
    required double top,
    required String label,
    required int button,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTapDown: (_) => widget.controller.pressButton(button),
        onTapUp: (_) => widget.controller.releaseButton(button),
        onTapCancel: () => widget.controller.releaseButton(button),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPSButton({
    required double left,
    required double top,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTapDown: (_) => widget.controller.pressButton(PSConstants.buttonPS),
        onTapUp: (_) => widget.controller.releaseButton(PSConstants.buttonPS),
        onTapCancel: () => widget.controller.releaseButton(PSConstants.buttonPS),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
              color: const Color(0xFF0072CE).withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: const Center(
            child: Text(
              'PS',
              style: TextStyle(
                color: Color(0xFF0072CE),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTouchpad({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTapDown: (_) => widget.controller.pressButton(PSConstants.buttonTouchpad),
        onTapUp: (_) => widget.controller.releaseButton(PSConstants.buttonTouchpad),
        onTapCancel: () => widget.controller.releaseButton(PSConstants.buttonTouchpad),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Center(
            child: Text(
              'Touchpad',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event, double width, double height) {
    final x = event.localPosition.dx / width;
    final y = event.localPosition.dy / height;
    _activeTouches[event.pointer] = Offset(x, y);
    widget.controller.onTouchDown(event.pointer, x, y);
  }

  void _handlePointerMove(PointerMoveEvent event, double width, double height) {
    final x = event.localPosition.dx / width;
    final y = event.localPosition.dy / height;
    _activeTouches[event.pointer] = Offset(x, y);
    widget.controller.onTouchMove(event.pointer, x, y);
  }

  void _handlePointerUp(PointerEvent event, double width, double height) {
    final pos = _activeTouches.remove(event.pointer);
    if (pos != null) {
      widget.controller.onTouchUp(event.pointer, pos.dx, pos.dy);
    }
  }
}
