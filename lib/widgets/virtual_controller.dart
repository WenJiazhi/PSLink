import 'package:flutter/material.dart';

import '../core/constants.dart';

class VirtualController extends StatefulWidget {
  const VirtualController({
    super.key,
    this.opacity = 0.7,
    this.onButtonChanged,
    this.onStickChanged,
    this.onTriggerChanged,
  });

  final double opacity;
  final Function(String button, bool pressed)? onButtonChanged;
  final Function(String stick, double x, double y)? onStickChanged;
  final Function(String trigger, double value)? onTriggerChanged;

  @override
  State<VirtualController> createState() => _VirtualControllerState();
}

class _VirtualControllerState extends State<VirtualController> {
  Offset _leftStickOffset = Offset.zero;
  Offset _rightStickOffset = Offset.zero;
  double _l2Value = 0.0;
  double _r2Value = 0.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.opacity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          return Stack(
            children: [
              Positioned(
                left: 40,
                bottom: screenHeight * 0.15,
                child: _buildJoystick(
                  currentOffset: _leftStickOffset,
                  onChanged: (offset) {
                    setState(() => _leftStickOffset = offset);
                    widget.onStickChanged?.call('left', offset.dx, offset.dy);
                  },
                ),
              ),
              Positioned(
                right: 40,
                bottom: screenHeight * 0.15,
                child: _buildJoystick(
                  currentOffset: _rightStickOffset,
                  onChanged: (offset) {
                    setState(() => _rightStickOffset = offset);
                    widget.onStickChanged?.call('right', offset.dx, offset.dy);
                  },
                ),
              ),
              Positioned(
                left: 30,
                bottom: screenHeight * 0.35,
                child: _buildDPad(),
              ),
              Positioned(
                right: 30,
                bottom: screenHeight * 0.35,
                child: _buildActionButtons(),
              ),
              Positioned(
                left: 40,
                top: 60,
                child: _buildShoulderButton('L1', 'l1'),
              ),
              Positioned(
                right: 40,
                top: 60,
                child: _buildShoulderButton('R1', 'r1'),
              ),
              Positioned(
                left: 40,
                top: 20,
                child: _buildTrigger(
                  label: 'L2',
                  value: _l2Value,
                  onChanged: (value) {
                    setState(() => _l2Value = value);
                    widget.onTriggerChanged?.call('l2', value);
                  },
                ),
              ),
              Positioned(
                right: 40,
                top: 20,
                child: _buildTrigger(
                  label: 'R2',
                  value: _r2Value,
                  onChanged: (value) {
                    setState(() => _r2Value = value);
                    widget.onTriggerChanged?.call('r2', value);
                  },
                ),
              ),
              Positioned(
                bottom: screenHeight * 0.45,
                left: screenWidth / 2 - 110,
                child: _buildCenterButtons(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJoystick({
    required Offset currentOffset,
    required ValueChanged<Offset> onChanged,
  }) {
    const size = 120.0;
    const knobSize = 50.0;
    const maxDistance = (size - knobSize) / 2;

    return GestureDetector(
      onPanUpdate: (details) {
        final center = const Offset(size / 2, size / 2);
        var newOffset = details.localPosition - center;
        final distance = newOffset.distance;
        if (distance > maxDistance) {
          newOffset = newOffset * (maxDistance / distance);
        }
        onChanged(
          Offset(
            newOffset.dx / maxDistance,
            -newOffset.dy / maxDistance,
          ),
        );
      },
      onPanEnd: (_) => onChanged(Offset.zero),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: Offset(
              currentOffset.dx * maxDistance,
              -currentOffset.dy * maxDistance,
            ),
            child: Container(
              width: knobSize,
              height: knobSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.grey.shade500,
                    Colors.grey.shade800,
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDPad() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        children: [
          Positioned(top: 0, left: 35, child: _buildDPadButton('↑', 'dpadUp')),
          Positioned(
            bottom: 0,
            left: 35,
            child: _buildDPadButton('↓', 'dpadDown'),
          ),
          Positioned(
            left: 0,
            top: 35,
            child: _buildDPadButton('←', 'dpadLeft'),
          ),
          Positioned(
            right: 0,
            top: 35,
            child: _buildDPadButton('→', 'dpadRight'),
          ),
          Positioned(
            left: 35,
            top: 35,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDPadButton(String label, String buttonId) {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call(buttonId, true),
      onTapUp: (_) => widget.onButtonChanged?.call(buttonId, false),
      onTapCancel: () => widget.onButtonChanged?.call(buttonId, false),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 45,
            child: _buildActionButton('△', 'triangle', Colors.green),
          ),
          Positioned(
            bottom: 0,
            left: 45,
            child: _buildActionButton('X', 'cross', Colors.blue),
          ),
          Positioned(
            left: 0,
            top: 45,
            child: _buildActionButton('□', 'square', Colors.pink),
          ),
          Positioned(
            right: 0,
            top: 45,
            child: _buildActionButton('O', 'circle', Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, String buttonId, Color color) {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call(buttonId, true),
      onTapUp: (_) => widget.onButtonChanged?.call(buttonId, false),
      onTapCancel: () => widget.onButtonChanged?.call(buttonId, false),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildShoulderButton(String label, String buttonId) {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call(buttonId, true),
      onTapUp: (_) => widget.onButtonChanged?.call(buttonId, false),
      onTapCancel: () => widget.onButtonChanged?.call(buttonId, false),
      child: Container(
        width: 80,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTrigger({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return GestureDetector(
      onTapDown: (_) => onChanged(1.0),
      onTapUp: (_) => onChanged(0.0),
      onTapCancel: () => onChanged(0.0),
      onVerticalDragUpdate: (details) {
        final normalized = (-details.localPosition.dy / 60).clamp(0.0, 1.0);
        onChanged(normalized);
      },
      onVerticalDragEnd: (_) => onChanged(0.0),
      child: Container(
        width: 90,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(AppColors.accentColor).withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSmallButton('SHARE', 'share'),
        const SizedBox(width: 12),
        _buildPsButton(),
        const SizedBox(width: 12),
        _buildSmallButton('OPT', 'options'),
        const SizedBox(width: 12),
        _buildTouchpadButton(),
      ],
    );
  }

  Widget _buildSmallButton(String label, String buttonId) {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call(buttonId, true),
      onTapUp: (_) => widget.onButtonChanged?.call(buttonId, false),
      onTapCancel: () => widget.onButtonChanged?.call(buttonId, false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPsButton() {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call('ps', true),
      onTapUp: (_) => widget.onButtonChanged?.call('ps', false),
      onTapCancel: () => widget.onButtonChanged?.call('ps', false),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(AppColors.primaryColor),
              Color(AppColors.accentColor),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'PS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTouchpadButton() {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call('touchpad', true),
      onTapUp: (_) => widget.onButtonChanged?.call('touchpad', false),
      onTapCancel: () => widget.onButtonChanged?.call('touchpad', false),
      child: Container(
        width: 54,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.touch_app,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}
