import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 事件组件测试共享的固定命中盒样式。
ElStyle get eventTestDefaultStyle => const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF00FF00));

/// 把 [view] 挂到最小可命中布局，供真实 ElView wiring 合同复用。
Future<void> pumpEventView(WidgetTester tester, ElView view) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: view),
    ),
  );
}

/// 在 [position] 以指定 [buttons] 完成一次鼠标按键点击。
Future<void> clickPointerButtonAt(WidgetTester tester, Offset position, int buttons, {int pointer = 1}) async {
  final gesture = await tester.createGesture(pointer: pointer, kind: PointerDeviceKind.mouse, buttons: buttons);
  await gesture.down(position);
  await gesture.up();
}
