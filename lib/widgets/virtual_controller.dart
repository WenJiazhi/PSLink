import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/constants.dart';

/// 虚拟游戏手柄组件
class VirtualController extends StatefulWidget {
  final double opacity;
  final Function(String button, bool pressed)? onButtonChanged;
  final Function(String stick, double x, double y)? onStickChanged;
  final Function(String trigger, double value)? onTriggerChanged;

  const VirtualController({
    super.key,
    this.opacity = 0.7,
    this.onButtonChanged,
    this.onStickChanged,
    this.onTriggerChanged,
  });

  @override
  State<VirtualController> createState() => _VirtualControllerState();
}

class _VirtualControllerState extends State<VirtualController> {
  // 摇杆状态
  Offset _leftStickOffset = Offset.zero;
  Offset _rightStickOffset = Offset.zero;

  // 触发器状态
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
              // 左侧摇杆
              Positioned(
                left: 40,
                bottom: screenHeight * 0.15,
                child: _buildJoystick(
                  'left',
                  _leftStickOffset,
                  (offset) {
                    setState(() => _leftStickOffset = offset);
                    widget.onStickChanged?.call('left', offset.dx, offset.dy);
                  },
                ),
              ),

              // 右侧摇杆
              Positioned(
                right: 40,
                bottom: screenHeight * 0.15,
                child: _buildJoystick(
                  'right',
                  _rightStickOffset,
                  (offset) {
                    setState(() => _rightStickOffset = offset);
                    widget.onStickChanged?.call('right', offset.dx, offset.dy);
                  },
                ),
              ),

              // 方向键
              Positioned(
                left: 30,
                bottom: screenHeight * 0.35,
                child: _buildDPad(),
              ),

              // 功能按钮 (X, O, □, △)
              Positioned(
                right: 30,
                bottom: screenHeight * 0.35,
                child: _buildActionButtons(),
              ),

              // L1/R1 按钮
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

              // L2/R2 触发器
              Positioned(
                left: 40,
                top: 20,
                child: _buildTrigger('L2', 'l2', _l2Value, (value) {
                  setState(() => _l2Value = value);
                  widget.onTriggerChanged?.call('l2', value);
                }),
              ),
              Positioned(
                right: 40,
                top: 20,
                child: _buildTrigger('R2', 'r2', _r2Value, (value) {
                  setState(() => _r2Value = value);
                  widget.onTriggerChanged?.call('r2', value);
                }),
              ),

              // 中间按钮 (Options, Share, PS, Touchpad)
              Positioned(
                bottom: screenHeight * 0.45,
                left: screenWidth / 2 - 100,
                child: _buildCenterButtons(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建摇杆
  Widget _buildJoystick(
    String id,
    Offset currentOffset,
    Function(Offset) onChanged,
  ) {
    const double size = 120;
    const double knobSize = 50;
    const double maxDistance = (size - knobSize) / 2;

    return GestureDetector(
      onPanStart: (_) {},
      onPanUpdate: (details) {
        final center = const Offset(size / 2, size / 2);
        var newOffset = details.localPosition - center;

        // 限制在圆形范围内
        final distance = newOffset.distance;
        if (distance > maxDistance) {
          newOffset = newOffset * (maxDistance / distance);
        }

        // 归一化到 -1 到 1
        final normalized = Offset(
          newOffset.dx / maxDistance,
          -newOffset.dy / maxDistance, // Y 轴反转
        );

        onChanged(normalized);
      },
      onPanEnd: (_) {
        onChanged(Offset.zero);
      },
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
                    Colors.grey.shade600,
                    Colors.grey.shade800,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建方向键
  Widget _buildDPad() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        children: [
          // 上
          Positioned(
            top: 0,
            left: 35,
            child: _buildDPadButton('↑', 'dpadUp'),
          ),
          // 下
          Positioned(
            bottom: 0,
            left: 35,
            child: _buildDPadButton('↓', 'dpadDown'),
          ),
          // 左
          Positioned(
            left: 0,
            top: 35,
            child: _buildDPadButton('←', 'dpadLeft'),
          ),
          // 右
          Positioned(
            right: 0,
            top: 35,
            child: _buildDPadButton('→', 'dpadRight'),
          ),
          // 中心
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
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建功能按钮
  Widget _buildActionButtons() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: [
          // △ (上)
          Positioned(
            top: 0,
            left: 40,
            child: _buildActionButton('△', 'triangle', Colors.teal),
          ),
          // X (下)
          Positioned(
            bottom: 0,
            left: 40,
            child: _buildActionButton('✕', 'cross', Colors.blue),
          ),
          // □ (左)
          Positioned(
            left: 0,
            top: 40,
            child: _buildActionButton('□', 'square', Colors.pink),
          ),
          // ○ (右)
          Positioned(
            right: 0,
            top: 40,
            child: _buildActionButton('○', 'circle', Colors.red),
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
          color: Colors.grey.shade800,
          border: Border.all(color: color.withOpacity(0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建肩键
  Widget _buildShoulderButton(String label, String buttonId) {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call(buttonId, true),
      onTapUp: (_) => widget.onButtonChanged?.call(buttonId, false),
      onTapCancel: () => widget.onButtonChanged?.call(buttonId, false),
      child: Container(
        width: 60,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建触发器
  Widget _buildTrigger(
    String label,
    String triggerId,
    double value,
    Function(double) onChanged,
  ) {
    return GestureDetector(
      onVerticalDragStart: (_) => onChanged(1.0),
      onVerticalDragEnd: (_) => onChanged(0.0),
      onTapDown: (_) => onChanged(1.0),
      onTapUp: (_) => onChanged(0.0),
      onTapCancel: () => onChanged(0.0),
      child: Container(
        width: 60,
        height: 35,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade800,
              Color.lerp(Colors.grey.shade800, Color(AppColors.primaryColor), value)!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建中间按钮
  Widget _buildCenterButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSmallButton('SHARE', 'share'),
        const SizedBox(width: 16),
        _buildPSButton(),
        const SizedBox(width: 16),
        _buildTouchpadButton(),
        const SizedBox(width: 16),
        _buildSmallButton('OPT', 'options'),
      ],
    );
  }

  Widget _buildSmallButton(String label, String buttonId) {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call(buttonId, true),
      onTapUp: (_) => widget.onButtonChanged?.call(buttonId, false),
      onTapCancel: () => widget.onButtonChanged?.call(buttonId, false),
      child: Container(
        width: 45,
        height: 25,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPSButton() {
    return GestureDetector(
      onTapDown: (_) => widget.onButtonChanged?.call('ps', true),
      onTapUp: (_) => widget.onButtonChanged?.call('ps', false),
      onTapCancel: () => widget.onButtonChanged?.call('ps', false),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color(AppColors.primaryColor),
              Color(AppColors.accentColor),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(AppColors.primaryColor).withOpacity(0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'PS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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
        width: 70,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: Icon(
            Icons.touch_app,
            color: Colors.white54,
            size: 18,
          ),
        ),
      ),
    );
  }
}
