import 'package:example/src/pages/components/event/basic/examples/drag.dart';
import 'package:example/src/pages/components/event/basic/examples/hover.dart';
import 'package:example/src/pages/components/event/basic/examples/keyboard.dart';
import 'package:example/src/pages/components/event/basic/examples/mouse.dart';
import 'package:example/src/pages/components/event/basic/examples/pointer.dart';
import 'package:example/src/pages/components/event/basic/examples/press.dart';
import 'package:example/src/pages/components/event/basic/examples/rotation.dart';
import 'package:example/src/pages/components/event/basic/examples/scale.dart';
import 'package:example/src/pages/components/event/basic/examples/scroll.dart';
import 'package:example/src/pages/components/event/basic/examples/tap.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _show(WidgetTester tester, Widget example) async {
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 248, child: example)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('指针位置跟随移动，按压与长按在独立示例反馈', (tester) async {
    await _show(tester, ElPointerEventExample());
    final origin = tester.getTopLeft(_key('event-basic-pointer'));
    final pointer = await tester.startGesture(origin + Offset(40, 50));
    await pointer.moveTo(origin + Offset(90, 100));
    await tester.pump();
    expect(find.text('onPointerMove · 90, 100'), findsOneWidget);
    await pointer.up();
    await tester.pump();
    expect(find.text('onPointerUp · 90, 100'), findsOneWidget);

    await _show(tester, ElPressEventExample());
    final press = await tester.startGesture(tester.getCenter(_key('event-basic-press')));
    await tester.pump(Duration(milliseconds: 150));
    expect(find.text('按下'), findsOneWidget);
    await tester.pump(Duration(milliseconds: 450));
    expect(find.text('已长按'), findsOneWidget);
    await press.up();
    await tester.pumpAndSettle();
    expect(find.text('已点击'), findsNothing);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('悬停与连击独立工作，双击三击显示不同结果', (tester) async {
    await _show(tester, ElHoverEventExample());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_key('event-basic-hover')));
    await tester.pumpAndSettle();
    expect(find.text('鼠标在这里'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('onPointerExit'), findsOneWidget);
    await mouse.removePointer();

    await _show(tester, ElTapEventExample());
    for (var count = 1; count <= 3; count++) {
      await tester.tap(_key('event-basic-tap'));
      await tester.pump(Duration(milliseconds: 60));
      if (count > 1) expect(find.text('$count 连击'), findsOneWidget);
    }
    expect(find.text('onTripleTap'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('鼠标按键、滚轮与键盘显示真实输入', (tester) async {
    await _show(tester, ElMouseEventExample());
    for (final (button, label) in [(kSecondaryMouseButton, '右键'), (kMiddleMouseButton, '中键')]) {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: button);
      await mouse.down(tester.getCenter(_key('event-basic-mouse')));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      await mouse.removePointer();
    }
    await _show(tester, ElScrollEventExample());
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(_key('event-basic-scroll')), scrollDelta: Offset(0, 60)),
    );
    await tester.pump();
    expect(find.text('onPointerSignal'), findsOneWidget);
    await _show(tester, ElKeyboardEventExample());
    await tester.tap(_key('event-basic-keyboard'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('onKeyDown'), findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(find.text('onKeyUp'), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('水平拖拽真实移动且纵坐标不变，重置回到中央', (tester) async {
    await _show(tester, ElDragEventExample());
    await tester.tap(_key('event-basic-drag-horizontal'));
    await tester.pumpAndSettle();
    final block = _key('event-basic-drag-block');
    final initial = tester.getCenter(block);
    final drag = await tester.startGesture(initial);
    await drag.moveBy(Offset(8, 0));
    await drag.moveBy(Offset(32, 24));
    await tester.pump();
    expect(tester.getCenter(block).dx, greaterThan(initial.dx));
    expect(tester.getCenter(block).dy, initial.dy);
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('onHorizontalDragEnd'), findsOneWidget);
    await tester.tap(_key('event-basic-drag-reset'));
    await tester.pumpAndSettle();
    expect(tester.getCenter(block), initial);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('双指捏合改变大小，松手保持比例且可以重置', (tester) async {
    await _show(tester, ElScaleEventExample());
    final center = tester.getCenter(_key('event-basic-scale'));
    final first = await tester.startGesture(center - Offset(30, 0), pointer: 1);
    final second = await tester.startGesture(center + Offset(30, 0), pointer: 2);
    await first.moveTo(center - Offset(60, 0));
    await second.moveTo(center + Offset(60, 0));
    await first.moveTo(center - Offset(80, 0));
    await second.moveTo(center + Offset(80, 0));
    await tester.pump();
    double scale() =>
        tester.renderObject<RenderBox>(_key('event-basic-scale-block')).getTransformTo(null).getMaxScaleOnAxis();
    final expanded = scale();
    expect(expanded, greaterThan(1));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(scale(), expanded);
    await tester.tap(_key('event-basic-scale-reset'));
    await tester.pumpAndSettle();
    expect(scale(), 1);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('双指只旋转也能转动方向图形，大小保持不变', (tester) async {
    await _show(tester, ElRotationEventExample());
    final center = tester.getCenter(_key('event-basic-rotation'));
    final first = await tester.startGesture(center - Offset(40, 0), pointer: 1);
    final second = await tester.startGesture(center + Offset(40, 0), pointer: 2);
    await first.moveTo(center - Offset(0, 40));
    await second.moveTo(center + Offset(0, 40));
    await first.moveTo(center + Offset(28, -28));
    await second.moveTo(center + Offset(-28, 28));
    await tester.pump();
    final transform = tester.renderObject<RenderBox>(_key('event-basic-rotation-block')).getTransformTo(null);
    expect(transform.storage[1].abs(), greaterThan(0.1), reason: '无需额外捏合，纯旋转就应看到角度变化');
    expect(transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    await tester.tap(_key('event-basic-rotation-reset'));
    await tester.pumpAndSettle();
    expect(tester.renderObject<RenderBox>(_key('event-basic-rotation-block')).getTransformTo(null).storage[1], 0);
    await tester.pumpWidget(SizedBox());
  });
}
