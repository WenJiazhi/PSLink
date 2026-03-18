import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pslink/core/constants.dart';
import 'package:pslink/widgets/virtual_controller.dart';

void main() {
  group('VirtualController', () {
    Future<void> pumpController(
      WidgetTester tester, {
      VirtualController child = const VirtualController(),
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: child,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the core controller sections', (tester) async {
      await pumpController(tester);

      expect(find.byType(VirtualController), findsOneWidget);
      expect(find.byType(Opacity), findsOneWidget);
      expect(find.byType(LayoutBuilder), findsOneWidget);
      expect(find.byType(Stack), findsAtLeastNWidgets(3));
      expect(find.text('L1'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('R2'), findsOneWidget);
      expect(find.text('SHARE'), findsOneWidget);
      expect(find.text('OPT'), findsOneWidget);
      expect(find.text('PS'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app), findsOneWidget);
    });

    testWidgets('uses the provided opacity', (tester) async {
      await pumpController(
        tester,
        child: const VirtualController(opacity: 0.5),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.5);
    });

    testWidgets('fires button callbacks on press and release', (tester) async {
      String? lastButton;
      bool? lastPressed;

      await pumpController(
        tester,
        child: VirtualController(
          onButtonChanged: (button, pressed) {
            lastButton = button;
            lastPressed = pressed;
          },
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('L1')));
      await tester.pump();

      expect(lastButton, 'l1');
      expect(lastPressed, isTrue);

      await gesture.up();
      await tester.pump();

      expect(lastButton, 'l1');
      expect(lastPressed, isFalse);
    });

    testWidgets('fires trigger callbacks', (tester) async {
      String? lastTrigger;
      double? lastValue;

      await pumpController(
        tester,
        child: VirtualController(
          onTriggerChanged: (trigger, value) {
            lastTrigger = trigger;
            lastValue = value;
          },
        ),
      );

      await tester.tap(find.text('L2'));
      await tester.pumpAndSettle();

      expect(lastTrigger, 'l2');
      expect(lastValue, 0.0);
    });

    testWidgets('fires stick callbacks when dragging a joystick', (tester) async {
      String? lastStick;
      double? lastX;
      double? lastY;

      await pumpController(
        tester,
        child: VirtualController(
          onStickChanged: (stick, x, y) {
            lastStick = stick;
            lastX = x;
            lastY = y;
          },
        ),
      );

      final joystick = find.byType(GestureDetector).first;
      await tester.drag(joystick, const Offset(20, -20));
      await tester.pumpAndSettle();

      expect(lastStick, isNotNull);
      expect(lastX, isNotNull);
      expect(lastY, isNotNull);
    });

    testWidgets('does not throw without callbacks', (tester) async {
      await pumpController(tester);

      await tester.tap(find.text('PS'));
      await tester.drag(find.byType(GestureDetector).first, const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the PS button with a gradient decoration', (tester) async {
      await pumpController(tester);

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('PS'),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(
        (decoration.gradient! as LinearGradient).colors,
        contains(Color(AppColors.primaryColor)),
      );
    });
  });
}
