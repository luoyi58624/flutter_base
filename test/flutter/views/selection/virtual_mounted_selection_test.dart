import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart' show selectionParticipantOf;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, height: 200, child: child),
  ),
);

Set<String> _mountedLabels(WidgetTester tester) => tester
    .widgetList<ElView>(find.byType(ElView, skipOffstage: false))
    .map((view) => view.child)
    .whereType<String>()
    .where((text) => text.startsWith('row-'))
    .toSet();

Set<String> _selectedLabels(ElSelectionController selection) =>
    selection.text?.split('\n').where((text) => text.isNotEmpty).toSet() ?? {};

void main() {
  testWidgets('常驻列表全选包含已经挂载的离屏内容', (tester) async {
    final selection = ElSelectionController();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: selection,
          child: ElScrollView(
            children: List.generate(20, (index) => ElView(style: ElStyle(height: 40), child: 'row-$index')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    selection.selectAll();
    expect(_selectedLabels(selection), {for (var index = 0; index < 20; index++) 'row-$index'});
  });

  for (final cache in [0.0, 400.0]) {
    testWidgets('cache=$cache：全选仅当前挂载内容，不构建或保活其他虚拟行', (tester) async {
      final selection = ElSelectionController();
      final scroll = ScrollController();
      addTearDown(selection.dispose);
      addTearDown(scroll.dispose);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          ElSelectionView(
            controller: selection,
            child: ElScrollView.sliver(
              controller: scroll,
              scrollCacheExtent: .pixels(cache),
              slivers: [
                SliverList.builder(
                  itemCount: 120,
                  itemBuilder: (_, index) {
                    builds++;
                    return ElView(key: ValueKey(index), style: ElStyle(height: 40), child: 'row-$index');
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = _mountedLabels(tester);
      final before = builds;
      selection.selectAll();
      await tester.pump();
      expect(_selectedLabels(selection), initial);
      expect(builds, before);

      scroll.jumpTo(2400);
      await tester.pumpAndSettle();
      final current = _mountedLabels(tester);
      expect(initial.difference(current), isNotEmpty, reason: '离屏旧窗口确实发生回收');
      expect(_selectedLabels(selection), initial.intersection(current), reason: '只保留仍挂载的原选中项');
      selection.selectAll();
      await tester.pump();
      expect(_selectedLabels(selection), current);

      // 固定尺寸列表可能正常保留测量样本；对照未选中滚动，证明没有额外的选区保活。
      selection.clear();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      scroll.jumpTo(2400);
      await tester.pumpAndSettle();
      expect(_mountedLabels(tester), current);
    });
  }

  testWidgets('复制不补齐已销毁行，普通组件不需要静态选区接口', (tester) async {
    final selection = ElSelectionController();
    final scroll = ScrollController();
    addTearDown(selection.dispose);
    addTearDown(scroll.dispose);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: selection,
          child: ElScrollView.sliver(
            controller: scroll,
            scrollCacheExtent: .pixels(0),
            slivers: [
              SliverList.builder(
                itemCount: 120,
                itemBuilder: (_, index) => Padding(
                  padding: EdgeInsets.zero,
                  child: ElView(key: ValueKey(index), style: ElStyle(height: 40), child: 'row-$index'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = _mountedLabels(tester);
    selection.selectAll();
    await tester.pump();
    scroll.jumpTo(2400);
    await tester.pumpAndSettle();
    selection.selectAll();
    await tester.pump();
    await selection.copy();
    expect(copied?.split('\n').toSet(), _mountedLabels(tester));
    final destroyed = initial.difference(_mountedLabels(tester));
    expect(destroyed, isNotEmpty);
    expect(copied!.split('\n').toSet().intersection(destroyed), isEmpty);
  });

  testWidgets('拖选触发自动滚动时回收旧行，选区仅引用当前有效宿主', (tester) async {
    final selection = ElSelectionController();
    final scroll = ScrollController();
    addTearDown(selection.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _host(
        ElSelectionView(
          controller: selection,
          child: ElScrollView.sliver(
            controller: scroll,
            scrollCacheExtent: .pixels(0),
            slivers: [
              SliverList.builder(
                itemCount: 120,
                itemBuilder: (_, index) =>
                    ElView(key: ValueKey(index), style: ElStyle(height: 40), child: 'row-$index'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = _mountedLabels(tester);
    final first = tester.getRect(find.byKey(ValueKey(0)));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.down(first.centerLeft + Offset(5, 0));
    await pointer.moveTo(Offset(80, 190));
    await tester.pump(Duration(milliseconds: 16));
    await pointer.moveTo(Offset(80, 240));
    for (var frame = 0; frame < 18; frame++) {
      await tester.pump(Duration(milliseconds: 16));
    }
    expect(scroll.offset, greaterThan(200));
    expect(initial.difference(_mountedLabels(tester)), isNotEmpty);
    await pointer.moveTo(Offset(90, 150));
    await tester.pump();
    await pointer.up();
    await pointer.removePointer();
    await tester.pumpAndSettle();
    final live = _mountedLabels(tester);
    expect(_selectedLabels(selection), isNotEmpty, reason: '旧节点回收后仍能选择当前有效范围');
    expect(_selectedLabels(selection).difference(live), isEmpty);
    for (final render in tester.allRenderObjects.whereType<ElRenderView>()) {
      final range = selectionParticipantOf(render)?.currentSelectionRange;
      if (range != null) {
        expect(range.end, lessThanOrEqualTo((selectionParticipantOf(render)?.selectionTextLength ?? 0)));
      }
    }
    expect(tester.takeException(), isNull);
  });
}
