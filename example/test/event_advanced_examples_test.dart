import 'package:example/src/pages/components/event/advanced/examples/disable.dart';
import 'package:example/src/pages/components/event/advanced/examples/handoff.dart';
import 'package:example/src/pages/components/event/advanced/examples/nested.dart';
import 'package:example/src/pages/components/event/advanced/examples/transform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

String? _text(WidgetTester tester, String key) => tester.widget<Text>(_key(key)).data;

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
  testWidgets('嵌套拖拽先由内层响应，父层不动且松手不误点击', (tester) async {
    await _show(tester, ElNestedDragExample());
    final outer = _key('advanced-nested-outer');
    final inner = _key('advanced-nested-inner');
    expect(tester.widget<ElView>(outer).event!.dragStartDistance, 3);
    expect(tester.widget<ElView>(inner).event!.dragStartDistance, 24);

    await tester.tap(inner);
    await tester.pumpAndSettle();
    expect(_text(tester, 'advanced-nested-click-count'), '点击 1');
    final outerInitial = tester.getTopLeft(outer);
    final innerInitial = tester.getTopLeft(inner);
    final drag = await tester.startGesture(tester.getCenter(inner));
    await drag.moveBy(Offset(12, 0));
    await tester.pump();
    expect(tester.getTopLeft(outer), outerInitial, reason: '父层不能凭较小的阈值抢先移动');
    expect(tester.getTopLeft(inner), innerInitial);
    expect(_text(tester, 'advanced-nested-outer-count'), '外层  起拖 0 · 更新 0');
    // 外层先达到阈值时，内层先获得处理机会，并在起手回调中截断外层。
    expect(_text(tester, 'advanced-nested-inner-count'), '内层  起拖 1 · 更新 0');

    await drag.moveBy(Offset(60, 0));
    await tester.pump();
    expect(_text(tester, 'advanced-nested-inner-count'), startsWith('内层  起拖 1'));
    await drag.moveBy(Offset(20, 0));
    await tester.pump();
    expect(tester.getTopLeft(inner).dx, greaterThan(innerInitial.dx));
    expect(tester.getTopLeft(inner).dy, innerInitial.dy);
    expect(tester.getTopLeft(outer), outerInitial);
    expect(_text(tester, 'advanced-nested-outer-count'), '外层  起拖 0 · 更新 0');
    final moved = tester.getTopLeft(inner);
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(inner), moved);
    expect(_text(tester, 'advanced-nested-click-count'), '点击 1');

    await tester.tap(inner);
    await tester.pumpAndSettle();
    expect(_text(tester, 'advanced-nested-click-count'), '点击 2');
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('第二指接力后松开，第一指继续从现有位置拖动而不跳回', (tester) async {
    await _show(tester, ElPointerHandoffExample());
    final area = tester.getTopLeft(_key('advanced-handoff-area'));
    final card = _key('advanced-handoff-card');
    final initial = tester.getTopLeft(card);
    final first = await tester.startGesture(tester.getCenter(card), pointer: 1);
    await first.moveBy(Offset(8, 0));
    await first.moveBy(Offset(24, 0));
    await tester.pump();
    final beforeHandoff = tester.getTopLeft(card);
    expect(beforeHandoff.dx, greaterThan(initial.dx));
    expect(_text(tester, 'advanced-handoff-phase'), '拖动中');
    expect(_text(tester, 'advanced-handoff-count'), '触点 1');

    final second = await tester.startGesture(area + Offset(170, 140), pointer: 2);
    await tester.pump();
    expect(tester.getTopLeft(card), beforeHandoff, reason: '新增手指的落点不应使卡片跳跃');
    expect(_text(tester, 'advanced-handoff-count'), '触点 2');
    await second.moveBy(Offset(-12, 14));
    await tester.pump();
    final afterSecond = tester.getTopLeft(card);
    expect(afterSecond, beforeHandoff + Offset(-12, 14));
    await second.up();
    await tester.pump();
    expect(tester.getTopLeft(card), afterSecond);
    expect(_text(tester, 'advanced-handoff-phase'), '拖动中');
    expect(_text(tester, 'advanced-handoff-count'), '触点 1');

    await first.moveBy(Offset(18, -9));
    await tester.pump();
    final resumed = tester.getTopLeft(card);
    expect(resumed, afterSecond + Offset(18, -9), reason: '接回旧手指时只使用本次位移');
    await first.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card), resumed);
    expect(_text(tester, 'advanced-handoff-phase'), '已松手');
    expect(_text(tester, 'advanced-handoff-count'), '触点 0');
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('单指拖动连续转为双指缩放，余下一指继续移动并在最后松手结束', (tester) async {
    await _show(tester, ElDragScaleExample());
    final area = _key('advanced-transform-area');
    final card = _key('advanced-transform-card');
    final center = tester.getCenter(area);
    double scale() => tester.renderObject<RenderBox>(card).getTransformTo(null).getMaxScaleOnAxis();
    final initial = tester.getCenter(card);
    final first = await tester.startGesture(center - Offset(25, 0), pointer: 1);
    await first.moveBy(Offset(8, 0));
    await first.moveBy(Offset(12, 0));
    await tester.pump();
    expect(tester.getCenter(card).dx, greaterThan(initial.dx));
    expect(scale(), 1);
    expect(_text(tester, 'advanced-transform-phase'), '拖动中');
    final dragged = tester.getCenter(card);

    final second = await tester.startGesture(center + Offset(25, 0), pointer: 2);
    await tester.pump();
    expect(tester.getCenter(card), dragged, reason: '第二指加入只切换手势，不重置位置');
    expect(_text(tester, 'advanced-transform-phase'), '缩放中');
    expect(_text(tester, 'advanced-transform-count'), '触点 2');
    await first.moveTo(center - Offset(50, 0));
    await second.moveTo(center + Offset(60, 0));
    await tester.pump();
    final expanded = scale();
    expect(expanded, greaterThan(1));
    expect(_text(tester, 'advanced-transform-phase'), '缩放中');
    final beforeLift = tester.getCenter(card);

    await second.up();
    await tester.pump();
    expect(tester.getCenter(card), beforeLift);
    expect(scale(), closeTo(expanded, 0.001));
    expect(_text(tester, 'advanced-transform-phase'), '缩放中');
    expect(_text(tester, 'advanced-transform-count'), '触点 1');
    await first.moveBy(Offset(0, 14));
    await tester.pump();
    final continued = tester.getCenter(card);
    expect(continued.dx, closeTo(beforeLift.dx, 0.001));
    expect(continued.dy, closeTo(beforeLift.dy + 14, 0.001));
    expect(scale(), closeTo(expanded, 0.001));
    expect(_text(tester, 'advanced-transform-phase'), '缩放中');

    await first.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(card), continued);
    expect(scale(), closeTo(expanded, 0.001));
    expect(_text(tester, 'advanced-transform-phase'), '已松手');
    expect(_text(tester, 'advanced-transform-count'), '触点 0');
    await tester.pump(Duration(milliseconds: 300));
    expect(tester.getCenter(card), continued);
    expect(_text(tester, 'advanced-transform-phase'), '已松手');
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('拖入停止区重建禁用只取消一次，后续移动冻结且复位后可再次拖拽', (tester) async {
    await _show(tester, ElDisableDuringDragExample());
    final card = _key('advanced-disable-card');
    final initial = tester.getTopLeft(card);
    final center = tester.getCenter(card);
    final stopZone = tester.getRect(_key('advanced-disable-stop-zone'));
    final drag = await tester.startGesture(center);
    await drag.moveBy(Offset(8, 0));
    await drag.moveTo(center + Offset(140, 0));
    await tester.pumpAndSettle();
    expect(tester.getCenter(card).dx, greaterThanOrEqualTo(stopZone.left));
    expect(tester.widget<ElView>(card).event!.disabled, isTrue);
    expect(_text(tester, 'advanced-disable-phase'), '已停用');
    expect(_text(tester, 'advanced-disable-count'), '取消 1');
    final stopped = tester.getTopLeft(card);

    await drag.moveBy(Offset(30, 20));
    await tester.pump();
    expect(tester.getTopLeft(card), stopped);
    expect(_text(tester, 'advanced-disable-count'), '取消 1');
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card), stopped);
    expect(_text(tester, 'advanced-disable-phase'), '已停用');
    expect(_text(tester, 'advanced-disable-count'), '取消 1');

    await tester.tap(_key('advanced-disable-reset'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card), initial);
    expect(tester.widget<ElView>(card).event!.disabled, isFalse);
    expect(_text(tester, 'advanced-disable-count'), '取消 0');
    final resumed = await tester.startGesture(tester.getCenter(card));
    await resumed.moveBy(Offset(8, 0));
    await resumed.moveBy(Offset(20, 0));
    await tester.pump();
    expect(tester.getTopLeft(card), initial + Offset(20, 0));
    expect(_text(tester, 'advanced-disable-phase'), '拖动中');
    await resumed.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card), initial + Offset(20, 0));
    expect(_text(tester, 'advanced-disable-phase'), '已松手');
    expect(_text(tester, 'advanced-disable-count'), '取消 0');
    await tester.pumpWidget(SizedBox());
  });
}
