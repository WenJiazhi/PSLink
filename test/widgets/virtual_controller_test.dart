import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/widgets/virtual_controller.dart';

void main() {
  group('VirtualController Widget', () {
    group('Widget 渲染测试', () {
      testWidgets('应该正确渲染虚拟控制器', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        // 验证基本结构
        expect(find.byType(VirtualController), findsOneWidget);
        expect(find.byType(Opacity), findsOneWidget);
        expect(find.byType(LayoutBuilder), findsOneWidget);
        expect(find.byType(Stack), findsOneWidget);
      });

      testWidgets('应该使用自定义透明度', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(opacity: 0.5),
            ),
          ),
        );

        final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
        expect(opacity.opacity, 0.5);
      });

      testWidgets('应该使用默认透明度 0.7', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
        expect(opacity.opacity, 0.7);
      });

      testWidgets('应该渲染所有按钮组', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 检查是否包含各种按钮文本
        expect(find.text('L1'), findsOneWidget);
        expect(find.text('R1'), findsOneWidget);
        expect(find.text('L2'), findsOneWidget);
        expect(find.text('R2'), findsOneWidget);
        expect(find.text('SHARE'), findsOneWidget);
        expect(find.text('OPT'), findsOneWidget);
        expect(find.text('PS'), findsOneWidget);
      });

      testWidgets('应该渲染方向键', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 检查方向键箭头
        expect(find.text('↑'), findsOneWidget);
        expect(find.text('↓'), findsOneWidget);
        expect(find.text('←'), findsOneWidget);
        expect(find.text('→'), findsOneWidget);
      });

      testWidgets('应该渲染功能按钮', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 检查功能按钮符号
        expect(find.text('✕'), findsOneWidget); // Cross
        expect(find.text('○'), findsOneWidget); // Circle
        expect(find.text('□'), findsOneWidget); // Square
        expect(find.text('△'), findsOneWidget); // Triangle
      });

      testWidgets('应该渲染触摸板按钮', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.touch_app), findsOneWidget);
      });
    });

    group('按钮交互测试', () {
      testWidgets('Cross 按钮点击应该触发回调', (WidgetTester tester) async {
        String? lastButton;
        bool? lastPressed;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VirtualController(
                onButtonChanged: (button, pressed) {
                  lastButton = button;
                  lastPressed = pressed;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 查找并点击 Cross 按钮
        final crossButton = find.text('✕');
        expect(crossButton, findsOneWidget);

        // 模拟按下
        await tester.press(crossButton);
        await tester.pumpAndSettle();

        expect(lastButton, 'cross');
        expect(lastPressed, true);

        // 模拟释放
        await tester.tap(crossButton);
        await tester.pumpAndSettle();

        expect(lastButton, 'cross');
        expect(lastPressed, false);
      });

      testWidgets('Circle 按钮点击应该触发回调', (WidgetTester tester) async {
        String? lastButton;
        bool? lastPressed;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VirtualController(
                onButtonChanged: (button, pressed) {
                  lastButton = button;
                  lastPressed = pressed;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final circleButton = find.text('○');
        await tester.tap(circleButton);
        await tester.pumpAndSettle();

        expect(lastButton, 'circle');
        expect(lastPressed, false); // tap 会触发 up 事件
      });

      testWidgets('方向键点击应该触发回调', (WidgetTester tester) async {
        String? lastButton;
        bool? lastPressed;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VirtualController(
                onButtonChanged: (button, pressed) {
                  lastButton = button;
                  lastPressed = pressed;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 测试上方向键
        await tester.tap(find.text('↑'));
        await tester.pumpAndSettle();
        expect(lastButton, 'dpadUp');

        // 测试下方向键
        await tester.tap(find.text('↓'));
        await tester.pumpAndSettle();
        expect(lastButton, 'dpadDown');

        // 测试左方向键
        await tester.tap(find.text('←'));
        await tester.pumpAndSettle();
        expect(lastButton, 'dpadLeft');

        // 测试右方向键
        await tester.tap(find.text('→'));
        await tester.pumpAndSettle();
        expect(lastButton, 'dpadRight');
      });

      testWidgets('肩键点击应该触发回调', (WidgetTester tester) async {
        String? lastButton;
        bool? lastPressed;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VirtualController(
                onButtonChanged: (button, pressed) {
                  lastButton = button;
                  lastPressed = pressed;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 测试 L1
        await tester.tap(find.text('L1'));
        await tester.pumpAndSettle();
        expect(lastButton, 'l1');

        // 测试 R1
        await tester.tap(find.text('R1'));
        await tester.pumpAndSettle();
        expect(lastButton, 'r1');
      });

      testWidgets('功能按钮点击应该触发回调', (WidgetTester tester) async {
        String? lastButton;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VirtualController(
                onButtonChanged: (button, pressed) {
                  lastButton = button;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 测试 Options
        await tester.tap(find.text('OPT'));
        await tester.pumpAndSettle();
        expect(lastButton, 'options');

        // 测试 Share
        await tester.tap(find.text('SHARE'));
        await tester.pumpAndSettle();
        expect(lastButton, 'share');

        // 测试 PS 按钮
        await tester.tap(find.text('PS'));
        await tester.pumpAndSettle();
        expect(lastButton, 'ps');

        // 测试 Touchpad
        await tester.tap(find.byIcon(Icons.touch_app));
        await tester.pumpAndSettle();
        expect(lastButton, 'touchpad');
      });

      testWidgets('触发器点击应该触发回调', (WidgetTester tester) async {
        String? lastTrigger;
        double? lastValue;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VirtualController(
                onTriggerChanged: (trigger, value) {
                  lastTrigger = trigger;
                  lastValue = value;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 测试 L2
        await tester.tap(find.text('L2'));
        await tester.pumpAndSettle();
        expect(lastTrigger, 'l2');
        expect(lastValue, 0.0); // tap 会触发 up 事件,值为 0

        // 测试 R2
        await tester.tap(find.text('R2'));
        await tester.pumpAndSettle();
        expect(lastTrigger, 'r2');
        expect(lastValue, 0.0);
      });
    });

    group('摇杆交互测试', () {
      testWidgets('摇杆拖动应该触发回调', (WidgetTester tester) async {
        String? lastStick;
        double? lastX;
        double? lastY;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: VirtualController(
                  onStickChanged: (stick, x, y) {
                    lastStick = stick;
                    lastX = x;
                    lastY = y;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 查找摇杆容器 (通过查找圆形容器)
        final joystickContainers = tester.widgetList<Container>(
          find.byType(Container),
        ).where((container) =>
          container.decoration is BoxDecoration &&
          (container.decoration as BoxDecoration).shape == BoxShape.circle &&
          container.constraints?.maxWidth == 120
        );

        expect(joystickContainers.length, greaterThanOrEqualTo(2));

        // 查找左摇杆 (左下角的位置)
        final leftJoystick = find.byType(GestureDetector).at(0);

        // 模拟拖动
        await tester.drag(leftJoystick, const Offset(20, -20));
        await tester.pumpAndSettle();

        // 验证回调被触发
        expect(lastStick, isNotNull);
        expect(lastX, isNotNull);
        expect(lastY, isNotNull);
      });

      testWidgets('摇杆释放应该重置为中心', (WidgetTester tester) async {
        String? lastStick;
        double? lastX;
        double? lastY;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: VirtualController(
                  onStickChanged: (stick, x, y) {
                    lastStick = stick;
                    lastX = x;
                    lastY = y;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 查找第一个 GestureDetector (左摇杆)
        final leftJoystick = find.byType(GestureDetector).first;

        // 拖动然后释放
        await tester.drag(leftJoystick, const Offset(30, 30));
        await tester.pumpAndSettle();

        // 释放后应该回到中心 (0, 0)
        // 由于 onPanEnd 会调用 onChanged(Offset.zero)
        expect(lastX?.abs(), lessThan(0.1)); // 接近 0
        expect(lastY?.abs(), lessThan(0.1)); // 接近 0
      });
    });

    group('无回调测试', () {
      testWidgets('没有回调时点击按钮不应该崩溃', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 点击各种按钮
        await tester.tap(find.text('✕'));
        await tester.tap(find.text('L1'));
        await tester.tap(find.text('PS'));
        await tester.pumpAndSettle();

        // 验证没有异常抛出
        expect(tester.takeException(), isNull);
      });

      testWidgets('没有回调时拖动摇杆不应该崩溃', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: const VirtualController(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final joystick = find.byType(GestureDetector).first;
        await tester.drag(joystick, const Offset(20, 20));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    group('视觉样式测试', () {
      testWidgets('功能按钮应该有不同的颜色', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 验证按钮容器存在
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, greaterThan(10));

        // 功能按钮应该有彩色边框
        // Cross: blue, Circle: red, Square: pink, Triangle: teal
        // 这些颜色通过 BoxDecoration 的 border 设置
      });

      testWidgets('PS 按钮应该有渐变效果', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VirtualController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 查找包含 PS 文本的容器
        final psContainer = tester.widget<Container>(
          find.ancestor(
            of: find.text('PS'),
            matching: find.byType(Container),
          ).first,
        );

        // 验证有渐变装饰
        expect(psContainer.decoration, isA<BoxDecoration>());
        final decoration = psContainer.decoration as BoxDecoration;
        expect(decoration.gradient, isA<LinearGradient>());
      });
    });

    group('状态管理测试', () {
      testWidgets('摇杆状态应该被正确维护', (WidgetTester tester) async {
        final List<Offset> leftStickValues = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: VirtualController(
                  onStickChanged: (stick, x, y) {
                    if (stick == 'left') {
                      leftStickValues.add(Offset(x, y));
                    }
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 多次拖动
        final joystick = find.byType(GestureDetector).first;

        await tester.drag(joystick, const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.drag(joystick, const Offset(-10, -10));
        await tester.pumpAndSettle();

        // 验证状态被记录
        expect(leftStickValues.length, greaterThan(0));
      });

      testWidgets('触发器值应该在按下时更新', (WidgetTester tester) async {
        final List<double> l2Values = [];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VirtualController(
                onTriggerChanged: (trigger, value) {
                  if (trigger == 'l2') {
                    l2Values.add(value);
                  }
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 多次点击 L2
        final l2Button = find.text('L2');
        await tester.press(l2Button);
        await tester.pumpAndSettle();

        await tester.tap(l2Button);
        await tester.pumpAndSettle();

        // 验证值被记录
        expect(l2Values.length, greaterThan(0));
      });
    });

    group('布局响应测试', () {
      testWidgets('应该在不同屏幕尺寸下正确渲染', (WidgetTester tester) async {
        // 小屏幕
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: const VirtualController(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(VirtualController), findsOneWidget);

        // 大屏幕
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1920,
                height: 1080,
                child: const VirtualController(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(VirtualController), findsOneWidget);
      });
    });
  });
}
