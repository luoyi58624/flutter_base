import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _host(WidgetTester tester, Widget slider) async => tester.pumpWidget(
  MaterialApp(
    home: ElMobileTheme(
      child: Align(
        alignment: .topLeft,
        child: SizedBox(width: 300, child: slider),
      ),
    ),
  ),
);
Finder _track() => find.byWidgetPredicate((w) => w is GestureDetector && w.onHorizontalDragUpdate != null);
Offset _point(WidgetTester tester, double ratio) {
  final rect = tester.getRect(_track());
  return Offset(rect.left + 10 + (rect.width - 20) * ratio, rect.center.dy);
}

double _ratio(WidgetTester tester, int index) =>
    (tester.getCenter(find.byKey(ValueKey('slider-thumb-$index'))).dx - _point(tester, 0).dx) /
    (_point(tester, 1).dx - _point(tester, 0).dx);

void main() {
  testWidgets('触屏圆块连续跟手，步长仅限制业务值，抬起吸附且只提交一次', (tester) async {
    final value = ValueNotifier(50.0), changes = <double>[];
    await _host(tester, ElSlider<double>(modelValue: value, onChanged: changes.add, step: 10, marks: true));
    final touch = await tester.startGesture(_point(tester, .5));
    await touch.moveTo(_point(tester, .63));
    await touch.moveTo(_point(tester, .64));
    await tester.pump();
    expect(value.value, 50);
    expect(changes, isEmpty);
    expect(_ratio(tester, 0), closeTo(.64, .001));
    await touch.up();
    await tester.pumpAndSettle();
    expect(value.value, 60);
    expect(changes, [60]);
    expect(_ratio(tester, 0), closeTo(.6, .001));
  });

  testWidgets('鼠标实时提交中点吸附值，圆块仍停在连续指针位置', (tester) async {
    final value = ValueNotifier(50.0);
    await _host(tester, ElSlider<double>(modelValue: value, step: 10));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(_point(tester, .25));
    await tester.pump();
    expect(value.value, 30);
    expect(_ratio(tester, 0), closeTo(.25, .001));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_ratio(tester, 0), closeTo(.3, .001));
  });

  testWidgets('父级回灌值并重建同内容的 marks 时，不中断连续拖动', (tester) async {
    final value = ValueNotifier(50.0);
    await _host(
      tester,
      ValueListenableBuilder(
        valueListenable: value,
        builder: (_, v, _) => ElSlider<double>(
          value: v,
          step: 10,
          marks: [ElSliderMark(value: 0), ElSliderMark(value: 50), ElSliderMark(value: 100)],
          onChanged: (next) => value.value = next,
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(_point(tester, .25));
    await tester.pump();
    expect(value.value, 30);
    expect(_ratio(tester, 0), closeTo(.25, .001));
    await mouse.moveTo(_point(tester, .44));
    await tester.pump();
    expect(value.value, 40);
    expect(_ratio(tester, 0), closeTo(.44, .001));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_ratio(tester, 0), closeTo(.4, .001));
  });

  testWidgets('触屏轻点抬起提交，纵向滚动和 pointercancel 不提交', (tester) async {
    final value = ValueNotifier(50.0);
    await _host(tester, ElSlider<double>(modelValue: value, step: 10));
    await tester.tapAt(_point(tester, .25));
    await tester.pumpAndSettle();
    expect(value.value, 30);
    final vertical = await tester.startGesture(_point(tester, .3));
    await vertical.moveBy(Offset(2, 40));
    await vertical.up();
    await tester.pumpAndSettle();
    expect(value.value, 30);
    final cancel = await tester.startGesture(_point(tester, .3));
    await cancel.moveTo(_point(tester, .9));
    await cancel.cancel();
    await tester.pumpAndSettle();
    expect(value.value, 30);
  });

  testWidgets('范围交叉切换端点职责，原数组保持不变，抬起提交新数组', (tester) async {
    final original = <double>[20, 70];
    final value = ValueNotifier(original);
    await _host(tester, ElSlider<List<double>>.range(modelValue: value, step: 5));
    final touch = await tester.startGesture(_point(tester, .2));
    await touch.moveTo(_point(tester, .9));
    await touch.moveTo(_point(tester, .91));
    await tester.pump();
    expect(value.value, same(original));
    expect(_ratio(tester, 1), closeTo(.91, .001));
    await touch.moveTo(_point(tester, .31));
    await tester.pump();
    expect(_ratio(tester, 0), closeTo(.31, .001));
    await touch.up();
    await tester.pumpAndSettle();
    expect(value.value, [30, 70]);
    expect(value.value, isNot(same(original)));
    expect(original, [20, 70]);
  });

  testWidgets('外部更新与第二触点撤销预览，迟到抬起不覆盖外部值', (tester) async {
    final value = ValueNotifier(50.0);
    await _host(tester, ElSlider<double>(modelValue: value, step: 10));
    final touch = await tester.startGesture(_point(tester, .5));
    await touch.moveTo(_point(tester, .8));
    await tester.pump();
    value.value = 30;
    await tester.pump();
    await touch.up();
    await tester.pumpAndSettle();
    expect(value.value, 30);
    final first = await tester.startGesture(_point(tester, .3), pointer: 11);
    await first.moveTo(_point(tester, .8));
    final second = await tester.startGesture(Offset(400, 400), pointer: 12);
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(value.value, 30);
  });

  testWidgets('step=null 仅选 marks，键盘、无障碍与禁用沿用合法值', (tester) async {
    final value = ValueNotifier(20.0), node = FocusNode();
    addTearDown(node.dispose);
    await _host(
      tester,
      ElSlider<double>(
        modelValue: value,
        focusNode: node,
        step: null,
        marks: [ElSliderMark(value: 0), ElSliderMark(value: 20), ElSliderMark(value: 37), ElSliderMark(value: 100)],
      ),
    );
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(value.value, 37);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    expect(value.value, 100);
    await _host(tester, ElSlider<double>(modelValue: value, disabled: true));
    await tester.tapAt(_point(tester, .2));
    await tester.pumpAndSettle();
    expect(value.value, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('不规则 marks 也不限制拖动位置，抬起才吸附到最近刻度', (tester) async {
    final value = ValueNotifier(20.0);
    await _host(
      tester,
      ElSlider<double>(
        modelValue: value,
        step: null,
        marks: [
          for (final v in [0.0, 20.0, 37.0, 100.0]) ElSliderMark(value: v),
        ],
      ),
    );
    final touch = await tester.startGesture(_point(tester, .2));
    await touch.moveTo(_point(tester, .55));
    await touch.moveTo(_point(tester, .56));
    await tester.pump();
    expect(_ratio(tester, 0), closeTo(.56, .001));
    expect(value.value, 20);
    await touch.up();
    await tester.pumpAndSettle();
    expect(value.value, 37);
    expect(_ratio(tester, 0), closeTo(.37, .001));
  });

  testWidgets('触屏 auto 提示仅在操作时出现，on 常显，禁用后隐藏', (tester) async {
    final value = ValueNotifier(50.0);
    Finder tip() => find.byWidgetPredicate(
      (w) => w is ElView && w.style?.borderRadius == BorderRadius.circular(4) && w.child is String,
    );
    await _host(tester, ElSlider<double>(modelValue: value));
    expect(tip(), findsNothing);
    final touch = await tester.startGesture(_point(tester, .5));
    await touch.moveTo(_point(tester, .7));
    await tester.pumpAndSettle();
    expect(tip(), findsOneWidget);
    await touch.up();
    await tester.pumpAndSettle();
    expect(tip(), findsNothing);
    await _host(tester, ElSlider<double>(modelValue: value, valueLabelDisplay: .on));
    await tester.pumpAndSettle();
    expect(tip(), findsOneWidget);
    await _host(tester, ElSlider<double>(modelValue: value, valueLabelDisplay: .on, disabled: true));
    await tester.pumpAndSettle();
    expect(tip(), findsNothing);
  });

  testWidgets('拖动中禁用或应用失焦撤销预览，抬起不产生迟到提交', (tester) async {
    final value = ValueNotifier(50.0), disabled = ValueNotifier(false);
    await _host(
      tester,
      ValueListenableBuilder(
        valueListenable: disabled,
        builder: (_, flag, _) => ElSlider<double>(modelValue: value, disabled: flag),
      ),
    );
    final touch = await tester.startGesture(_point(tester, .5));
    await touch.moveTo(_point(tester, .8));
    disabled.value = true;
    await tester.pumpAndSettle();
    await touch.up();
    expect(value.value, 50);
    disabled.value = false;
    await tester.pumpAndSettle();
    final next = await tester.startGesture(_point(tester, .5));
    await next.moveTo(_point(tester, .8));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await next.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(value.value, 50);
    expect(tester.takeException(), isNull);
  });
}
