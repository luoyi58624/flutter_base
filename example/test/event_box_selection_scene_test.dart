import 'package:example/src/pages/components/event/advanced/examples/box_selection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

String? _text(WidgetTester tester, String key) => tester.widget<Text>(_key(key)).data;

ElBoxSelectionController _controller(WidgetTester tester) =>
    tester.widget<ElBoxSelectionView>(find.byType(ElBoxSelectionView)).controller!;

Future<void> _show(WidgetTester tester) async {
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 288, child: ElBoxSelectionSceneExample())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() => tester.pumpWidget(SizedBox()));
}

Future<TestGesture> _startBox(WidgetTester tester) async {
  final area = tester.getRect(_key('event-box-area'));
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.down(area.topLeft + Offset(4, 4));
  return mouse;
}

void main() {
  testWidgets('从留白真实框选三项后继续扩至六项，松手保留选中且不打开卡片', (tester) async {
    await _show(tester);
    final mouse = await _startBox(tester);
    await mouse.moveTo(tester.getRect(_key('event-box-file-3')).bottomRight + Offset(2, 2));
    await tester.pump();
    expect(_controller(tester).selectedValues, {1, 2, 3});
    expect(_text(tester, 'event-box-selected'), '已选 3 / 6');

    await mouse.moveTo(tester.getRect(_key('event-box-file-6')).bottomRight + Offset(2, 2));
    await tester.pump();
    expect(_controller(tester).selectedValues, {1, 2, 3, 4, 5, 6});
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_text(tester, 'event-box-selected'), '已选 6 / 6');
    expect(_text(tester, 'event-box-opens'), '打开 0');
    expect(_text(tester, 'event-box-pressed'), '已松开');
    expect(tester.takeException(), isNull);
  });

  testWidgets('鼠标普通点击保留卡片打开和按压反馈，也能选中单个文件', (tester) async {
    await _show(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.down(tester.getCenter(_key('event-box-file-2')));
    await tester.pump();
    expect(_text(tester, 'event-box-pressed'), '按压中');
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_controller(tester).selectedValues, {2});
    expect(_text(tester, 'event-box-opens'), '打开 1');
    expect(_text(tester, 'event-box-pressed'), '已松开');

    final area = tester.getRect(_key('event-box-area'));
    await mouse.down(area.bottomLeft + Offset(8, -8));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_controller(tester).selectedValues, isEmpty);
    expect(_text(tester, 'event-box-opens'), '打开 2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('区域外清空按钮清除真实选择，不增加卡片打开次数', (tester) async {
    await _show(tester);
    final mouse = await _startBox(tester);
    await mouse.moveTo(tester.getRect(_key('event-box-file-6')).bottomRight + Offset(2, 2));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_controller(tester).selectedCount, 6);
    await tester.tap(_key('event-box-clear'));
    await tester.pumpAndSettle();
    expect(_controller(tester).selectedValues, isEmpty);
    expect(_text(tester, 'event-box-selected'), '已选 0 / 6');
    expect(_text(tester, 'event-box-opens'), '打开 0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('320宽屏幕中六个文件与状态栏完整布局', (tester) async {
    await tester.binding.setSurfaceSize(Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _show(tester);
    final area = tester.getRect(_key('event-box-area'));
    for (var index = 1; index <= 6; index++) {
      final rect = tester.getRect(_key('event-box-file-$index'));
      expect(area.contains(rect.topLeft), isTrue);
      expect(area.contains(rect.bottomRight), isTrue);
    }
    expect(tester.getSize(_key('event-box-card')).height, lessThanOrEqualTo(320));
    expect(_text(tester, 'event-box-moves'), '原始 Move 0');
    expect(tester.takeException(), isNull);
  });
}
