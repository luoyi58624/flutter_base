import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Align(alignment: .topLeft, child: child),
  );
  Finder mark() => find.byWidgetPredicate((widget) => widget is ElView && widget.style?.minWidth != null);

  testWidgets('只导入 el_ui 即可使用徽章，背景完全由 backgroundColor 控制', (tester) async {
    await tester.pumpWidget(host(ElBadge(bgColor: Color(0xff123456), value: 123)));
    expect(tester.widget<ElView>(mark()).child, '99+');
    expect(tester.widget<ElView>(mark()).style?.backgroundColor, Color(0xff123456));
    expect(tester.takeException(), isNull);
  });

  testWidgets('附着位置跟随徽章真实尺寸，偏移与自定义高度同时生效', (tester) async {
    final childKey = ValueKey('badge-host');
    await tester.pumpWidget(
      host(
        ElBadge(
          bgColor: Color(0xff345678),
          value: 'new',
          offset: Offset(4, 6),
          badgeStyle: ElStyle(height: 30),
          child: ElView(key: childKey, style: ElStyle(width: 80, height: 40)),
        ),
      ),
    );
    final hostRect = tester.getRect(find.byKey(childKey));
    final markRect = tester.getRect(mark());
    expect(markRect.left, closeTo(hostRect.right - 10 + 4, 0.01));
    expect(markRect.center.dy, closeTo(hostRect.top + 6, 0.01));
    expect(markRect.height, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('零值隐藏保留宿主，圆点忽略 value', (tester) async {
    final childKey = ValueKey('badge-host');
    await tester.pumpWidget(
      host(
        ElBadge(
          bgColor: Color(0xff345678),
          value: 0,
          showZero: false,
          child: ElView(key: childKey, child: 'host'),
        ),
      ),
    );
    expect(find.byKey(childKey), findsOneWidget);
    expect(mark(), findsNothing);
    await tester.pumpWidget(host(ElBadge(bgColor: Color(0xff345678), isDot: true, value: 123)));
    final dot = find.byWidgetPredicate((widget) => widget is ElView && widget.style?.width == 8);
    expect(dot, findsOneWidget);
    expect(tester.widget<ElView>(dot).child, isNull);
  });
}
