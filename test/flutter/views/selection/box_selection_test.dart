import 'package:flutter_base/src/ui/testing/ui_test_api.dart' hide ElBoxSelectionController;

import 'package:flutter_base/src/flutter/views/selection/box/box_selection_view.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(style: ElStyle(width: 400, height: 240), child: child),
  ),
);

Widget _cards(
  ElBoxSelectionController controller, {
  ValueChanged<({Set<Object> added, Set<Object> removed, int selectedCount})>? changed,
  bool enabled = true,
}) => ElBoxSelectionView(
  controller: controller,
  enabled: enabled,
  onSelectionChanged: changed,
  child: Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (var i = 0; i < 8; i++)
        ElBoxSelectable(
          key: ValueKey(i),
          value: i,
          style: ElStyle(width: 80, height: 50, backgroundColor: Color(0xffeeeeee)),
          selectedStyle: ElStyle(
            backgroundColor: Color(0xffddeeff),
            border: .all(borderColor: Color(0xff0000ff), borderWidth: 3),
            borderRadius: .all(Radius.circular(12)),
          ),
          child: ElView(child: '文件 $i'),
        ),
    ],
  ),
);

Future<void> _drag(WidgetTester tester, Offset start, Offset end) async {
  final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await pointer.down(start);
  await tester.pump();
  await pointer.moveTo(end);
  await tester.pump();
  await pointer.up();
  await tester.pump();
}

void main() {
  test('增量矩形索引与线性几何结果一致', () {
    final index = SelectionRectIndex<int>([]);
    final entries = <({Rect rect, int value})>[];
    for (var i = 0; i < 4096; i++) {
      final entry = (rect: Rect.fromLTWH((i * 137 % 251) * 10, (i * 73 % 241) * 10, 17, 13), value: i);
      entries.add(entry);
      index.add(entry);
      if (i % 97 == 0) {
        final area = entry.rect.inflate(20);
        expect(
          index.query(area),
          entries.where((entry) => entry.rect.overlaps(area)).map((entry) => entry.value).toSet(),
        );
      }
    }
  });

  testWidgets('无 key 对象重排不会误报重复值，选中样式随稳定值迁移', (tester) async {
    final selection = ElBoxSelectionController();
    addTearDown(selection.dispose);
    var reversed = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;
            return ElBoxSelectionView(
              controller: selection,
              child: Row(
                children: [
                  for (final value in reversed ? ['b', 'a'] : ['a', 'b'])
                    ElBoxSelectable(
                      value: value,
                      style: ElStyle(width: 80, height: 60),
                      selectedStyle: ElStyle(backgroundColor: Color(0xff2288ee)),
                      child: ElView(child: value),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
    selection.select('a');
    await tester.pump();
    rebuild(() => reversed = true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(selection.selectedValues, {'a'});
    final selected = tester.allRenderObjects
        .whereType<ElRenderView>()
        .where((view) => view.committedResolvedStyle.box.backgroundColor == Color(0xff2288ee))
        .toList();
    expect(selected, hasLength(1));
    expect(selected.single.localToGlobal(Offset.zero).dx, 80);
  });

  testWidgets('同一框选根中重复 value 明确报错', (tester) async {
    await tester.pumpWidget(
      _host(
        ElBoxSelectionView(
          child: Row(
            children: [
              ElBoxSelectable(value: 'same', style: ElStyle(width: 40, height: 40)),
              ElBoxSelectable(value: 'same', style: ElStyle(width: 40, height: 40)),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException().toString(), contains('value 在同一个框选根内必须唯一'));
  });

  for (final reverse in [false, true]) {
    testWidgets('横向框选 reverse=$reverse 随自动滚动延伸', (tester) async {
      final selection = ElBoxSelectionController();
      final scroll = ScrollController();
      addTearDown(selection.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _host(
          ElBoxSelectionView(
            controller: selection,
            child: ElScrollView.sliver(
              controller: scroll,
              scrollDirection: .horizontal,
              reverse: reverse,
              scrollCacheExtent: .pixels(0),
              slivers: [
                SliverList.builder(
                  itemCount: 1000,
                  itemBuilder: (_, i) => ElBoxSelectable(value: i, style: ElStyle(width: 40, height: 100)),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(Offset(reverse ? 390 : 10, 10));
      await mouse.moveTo(Offset(reverse ? 2 : 398, 80));
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(Duration(milliseconds: 16));
      }
      expect(scroll.offset, greaterThan(200));
      expect(selection.selectedCount, greaterThan(10));
      // 官方 reverse 让 0 号贴在起始的右缘，按下点正落在 0 号。
      expect(selection.isSelected(0), isTrue);
      await mouse.up();
    });
  }

  testWidgets('十万虚拟对象全选只取可见项，不包含缓存且不额外调用 builder', (tester) async {
    final controller = ElBoxSelectionController();
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    var builds = 0;
    await tester.pumpWidget(
      _host(
        ElBoxSelectionView(
          controller: controller,
          child: ElScrollView.sliver(
            controller: scroll,
            scrollCacheExtent: .pixels(800),
            slivers: [
              SliverList.builder(
                itemCount: 100000,
                itemBuilder: (_, i) {
                  builds++;
                  return ElBoxSelectable(key: ValueKey(i), value: i, style: ElStyle(height: 40, width: 200));
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialBuilds = builds;
    controller.selectAll();
    await tester.pump();
    expect(controller.selectedValues, {0, 1, 2, 3, 4, 5});
    expect(builds, initialBuilds);
    scroll.jumpTo(4000);
    await tester.pumpAndSettle();
    final scrolledBuilds = builds;
    controller.clear();
    controller.selectAll();
    await tester.pump();
    expect(controller.selectedValues, {100, 101, 102, 103, 104, 105});
    expect(builds, scrolledBuilds);
  });

  testWidgets('虚拟拖选滚动新挂载项首次绘制就选中，释放指针立即停滚', (tester) async {
    final controller = ElBoxSelectionController();
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    final painted = <int, bool>{};
    await tester.pumpWidget(
      _host(
        ElBoxSelectionView(
          controller: controller,
          child: ElScrollView.sliver(
            controller: scroll,
            scrollCacheExtent: .pixels(0),
            slivers: [
              SliverList.builder(
                itemCount: 10000,
                itemBuilder: (_, i) => ElBoxSelectable(
                  key: ValueKey(i),
                  value: i,
                  style: ElStyle(height: 40, width: 200),
                  selectedStyle: ElStyle(backgroundColor: Color(0xff0088ff)),
                  child: _PaintProbe(onPaint: () => painted[i] = controller.isSelected(i)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(Offset(10, 10));
    await mouse.moveTo(Offset(100, 238));
    await tester.pump();
    for (var frame = 0; frame < 12; frame++) {
      painted.clear();
      await tester.pump(Duration(milliseconds: 16));
      final first = (scroll.offset / 40).floor();
      final last = ((scroll.offset + 238) / 40).floor();
      for (var i = first; i <= last; i++) {
        expect(controller.isSelected(i), isTrue, reason: '第 $frame 帧，第 $i 项，滚动 ${scroll.offset}');
        if (painted.containsKey(i)) expect(painted[i], isTrue, reason: '新项不能先绘制未选中状态');
      }
    }
    expect(scroll.offset, greaterThan(240));
    await mouse.up();
    final stopped = scroll.offset;
    await tester.pump(Duration(milliseconds: 80));
    expect(scroll.offset, stopped);
  });

  testWidgets('尺寸样式改变排布后同次拖选不抖动，下次拖动使用新布局', (tester) async {
    final controller = ElBoxSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        ElBoxSelectionView(
          controller: controller,
          child: Column(
            children: [
              for (var i = 0; i < 4; i++)
                ElBoxSelectable(value: i, style: ElStyle(width: 200, height: 40), selectedStyle: ElStyle(height: 60)),
            ],
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(Offset(105, 5));
    await mouse.moveTo(Offset(150, 70));
    await tester.pump();
    expect(controller.selectedValues, {0, 1});
    await mouse.moveTo(Offset(151, 69));
    await tester.pump();
    expect(controller.selectedValues, {0, 1});
    await mouse.up();
    await tester.pump();
    await _drag(tester, Offset(105, 65), Offset(150, 110));
    expect(controller.selectedValues, {1});
  });

  testWidgets('框选中的编辑器禁止键盘和拖选，仍能定位光标并接收输入法', (tester) async {
    final controller = EditableController(text: 'alpha beta', singleLine: true);
    final box = ElBoxSelectionController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(box.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _host(
        ElBoxSelectionView(
          controller: box,
          child: EditableView(
            controller: controller,
            focusNode: focus,
            style: EditableConfiguration(
              textStyle: TextStyle(fontFamily: 'Ahem', fontSize: 20),
              retainSelectionOnBlur: true,
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.selection.isCollapsed, isTrue);
    await tester.tapAt(Offset(85, 12), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(controller.selection.extentOffset, greaterThan(0));
    final modelRange = TextSelection(baseOffset: 1, extentOffset: 5);
    controller.setSelection(modelRange);
    await tester.pump();
    expect(controller.selection, modelRange, reason: '程序化和输入法替换范围不得被禁选边界清掉');
    for (final line in tester.allRenderObjects.whereType<RenderEditableLine>()) {
      expect(line.paintStateForTest.hasSelection, isFalse);
    }
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    expect(controller.text, 'a');
    expect(controller.composing, TextRange(start: 0, end: 1));
  });

  test('对象集合视图保持实时与只读，重复命令不通知', () {
    final controller = ElBoxSelectionController();
    final view = controller.selectedValues;
    var calls = 0;
    controller.addListener(() => calls++);
    controller.select('a');
    controller.select('a');
    controller.deselect('b');
    expect(calls, 1);
    expect(view, {'a'});
    expect(() => view.add('b'), throwsUnsupportedError);
    controller.clear();
    controller.clear();
    expect(calls, 2);
    expect(view, isEmpty);
    controller.dispose();
  });

  test('一万个矩形的局部命中只检查少量候选，边缘相接不选中', () {
    final index = SelectionRectIndex<int>([
      for (var i = 0; i < 10000; i++) (rect: Rect.fromLTWH((i % 100) * 20, (i ~/ 100) * 20, 10, 10), value: i),
    ]);
    expect(index.query(Rect.fromLTWH(1001, 1001, 5, 5)), {5050});
    expect(index.debugLastCandidateCount, lessThan(64));
    expect(index.query(Rect.fromLTWH(1010, 1000, 10, 10)), isEmpty);
    expect(index.query(Rect.zero), isEmpty);
  });

  testWidgets('框选四个对象，只发布新增项，选中样式驱动完整边框', (tester) async {
    final controller = ElBoxSelectionController();
    addTearDown(controller.dispose);
    final changes = <({Set<Object> added, Set<Object> removed, int selectedCount})>[];
    await tester.pumpWidget(_host(_cards(controller, changed: changes.add)));
    await _drag(tester, Offset(5, 5), Offset(135, 100));
    expect(controller.selectedValues, {0, 1, 4, 5});
    expect(changes.expand((change) => change.added).toSet(), {0, 1, 4, 5});
    expect(changes.every((change) => change.removed.isEmpty), isTrue);
    final view = tester
        .renderObjectList<ElRenderView>(
          find.descendant(of: find.byKey(ValueKey(0)), matching: find.byWidgetPredicate((widget) => widget is ElView)),
        )
        .first;
    expect(controller.isSelected(0), isTrue);
    expect(view.committedResolvedStyle.box.border?.borderTop.borderWidth, 3);
  });

  testWidgets('点击替换、Ctrl 切换、Shift 加选与 Esc 清空', (tester) async {
    final controller = ElBoxSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_cards(controller)));
    await tester.tap(find.byKey(ValueKey(0)), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(controller.selectedValues, {0});
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byKey(ValueKey(1)), kind: PointerDeviceKind.mouse);
    await tester.tap(find.byKey(ValueKey(0)), kind: PointerDeviceKind.mouse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.selectedValues, {1});
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(ValueKey(2)), kind: PointerDeviceKind.mouse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.selectedValues, {1, 2});
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.selectedValues, isEmpty);
  });

  testWidgets('内外文档根与显式 text 无法穿过硬边界，禁用框选后仍禁选文字', (tester) async {
    final outer = ElSelectionController();
    final inner = ElSelectionController();
    final box = ElBoxSelectionController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    addTearDown(box.dispose);
    for (final enabled in [true, false]) {
      await tester.pumpWidget(
        _host(
          ElSelectionView(
            controller: outer,
            child: Column(
              children: [
                ElView(child: '之前'),
                ElBoxSelectionView(
                  controller: box,
                  enabled: enabled,
                  child: ElSelectionView(
                    controller: inner,
                    child: ElView(
                      style: ElStyle(userSelect: .text),
                      child: '禁止文字',
                    ),
                  ),
                ),
                ElView(child: '之后'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      inner.selectAll();
      outer.selectAll();
      await tester.pump();
      expect(inner.text, isNull);
      expect(outer.text, contains('之前'));
      expect(outer.text, contains('之后'));
      expect(outer.text, isNot(contains('禁止文字')));
    }
  });
}

class _PaintProbe extends LeafRenderObjectWidget {
  const _PaintProbe({required this.onPaint});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) => _ProbeRender(onPaint);
}

class _ProbeRender extends RenderBox {
  _ProbeRender(this.onPaint);
  final VoidCallback onPaint;
  @override
  void performLayout() => size = constraints.smallest;
  @override
  void paint(PaintingContext context, Offset offset) => onPaint();
}
