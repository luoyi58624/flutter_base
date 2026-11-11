import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/reparent.dart';

Finder text(String value) => find.byWidgetPredicate((w) => w is ElView && w.child == value);

void main() {
  testWidgets('View 连续重挂到新级联祖先后颜色、点击和键盘焦点均更新', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final button = GlobalKey();
    final focus = FocusNode();
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      lifecycleHost(
        ReparentHarness(
          key: move,
          wrap: (generation, child) => ElView(
            style: ElStyle(color: generation.isEven ? Color(0xff123456) : Color(0xffabcdef)),
            child: child,
          ),
          child: ElButtonView(
            key: button,
            focusNode: focus,
            onPressed: () => taps++,
            semanticLabel: '搬迁按钮',
            child: '搬迁按钮',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final render = tester.renderObject<ElRenderView>(find.byKey(button));
    for (var i = 1; i <= 3; i++) {
      await reparent(tester, move);
      expect(tester.renderObject(find.byKey(button)), same(render));
      expect(render.committedResolvedStyle.inheritedText.color, i.isEven ? Color(0xff123456) : Color(0xffabcdef));
      await tester.tap(find.byKey(button));
      await tester.pump();
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, i * 2);
      expect(focus.hasFocus, isTrue);
      expect(tester.getSemantics(find.byKey(button)).label, '搬迁按钮');
    }
    await tester.pumpWidget(ElView());
    focus.dispose();
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final lazy in [false, true]) {
    testWidgets('Tab 重挂保留页位置并继续响应程序切换和真实拖拽 lazy=$lazy', (tester) async {
      final move = GlobalKey<ReparentHarnessState>();
      final controller = ElTabController(length: 3, initialIndex: 1);
      await tester.pumpWidget(
        lifecycleHost(
          ReparentHarness(
            key: move,
            child: ElTabView(
              controller: controller,
              lazy: lazy,
              children: [for (var i = 0; i < 3; i++) ElView(child: 'page-$i')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(ElTabView));
      for (var i = 0; i < 3; i++) {
        await reparent(tester, move);
        expect(tester.state(find.byType(ElTabView)), same(state));
        expect(controller.index, 1);
        controller.jumpTo(2);
        await tester.pumpAndSettle();
        expect(tester.getRect(text('page-2')).center.dx, closeTo(400, .1));
        await tester.drag(find.byType(ElTabView), Offset(600, 0));
        await tester.pumpAndSettle();
        expect(controller.index, 1);
        expect(tester.getRect(text('page-1')).center.dx, closeTo(400, .1));
      }
      await tester.pumpWidget(ElView());
      controller.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Tab 动画中重挂后 Future 能结束且仍可反向切页', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(
      lifecycleHost(
        ReparentHarness(
          key: move,
          child: ElTabView(
            controller: controller,
            children: [for (var i = 0; i < 3; i++) ElView(child: 'page-$i')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    var done = false;
    controller.animateTo(2).then((_) => done = true);
    await tester.pump();
    await tester.pump(Duration(milliseconds: 40));
    await reparent(tester, move);
    expect(done, isTrue);
    final back = controller.animateTo(0);
    await tester.pumpAndSettle();
    await back;
    expect(controller.index, 0);
    expect(tester.getRect(text('page-0')).center.dx, closeTo(400, .1));
    await tester.pumpWidget(ElView());
    controller.dispose();
  });

  testWidgets('Zoom 重挂保留变换，动画和点击命中继续使用相同 RenderObject', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final content = GlobalKey();
    final controller = ElZoomController();
    var taps = 0;
    await tester.pumpWidget(
      lifecycleHost(
        ReparentHarness(
          key: move,
          child: ElZoomView(
            controller: controller,
            child: ElView(
              key: content,
              event: ElEvent(onTap: (_) => taps++),
              child: 'zoom',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(ElZoomTransform(scale: 2));
    await tester.pumpAndSettle();
    final render = tester.renderObject<RenderBox>(find.byKey(content));
    for (var i = 0; i < 3; i++) {
      await reparent(tester, move);
      expect(controller.value.scale, 2);
      expect(tester.renderObject(find.byKey(content)), same(render));
      await tester.tapAt(Offset(400, 300));
      await tester.pumpAndSettle();
      expect(taps, i + 1);
      final future = controller.animateTo(ElZoomTransform(scale: 3));
      await tester.pumpAndSettle();
      await future;
      expect(controller.value.scale, closeTo(3, .001));
      controller.jumpTo(ElZoomTransform(scale: 2));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(ElView());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Table 重挂后仍能更新数据、排序与虚拟滚动', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElTableController(
      rowKey: 'id',
      columns: [ElTableColumn(title: '名称', prop: 'name', sort: true)],
      data: [
        for (var i = 0; i < 100; i++) {'id': i, 'name': 'row-$i'},
      ],
    );
    await tester.pumpWidget(
      lifecycleHost(
        ReparentHarness(
          key: move,
          child: ElTable(controller: controller, height: 500),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(ElTable));
    Iterable<ElRenderView> cells(String value, {bool prefix = false}) sync* {
      final nodes = <RenderObject>[tester.renderObject(find.byType(ElTable))];
      while (nodes.isNotEmpty) {
        final node = nodes.removeLast();
        if (node is ElRenderView) {
          final content = (node.content as TextEngine?)?.rawChild;
          if (content == value || prefix && content is String && content.startsWith(value)) {
            yield node;
          }
        }
        node.visitChildren(nodes.add);
      }
    }

    for (var i = 0; i < 3; i++) {
      await reparent(tester, move);
      expect(tester.state(find.byType(ElTable)), same(state));
      controller.data = [
        for (var j = 0; j < 100; j++) {'id': j, 'name': 'updated-$i-$j'},
      ];
      await tester.pumpAndSettle();
      expect(cells('updated-$i-', prefix: true), isNotEmpty);
      final header = cells('名称').first;
      final beforeSort = controller.sortState;
      await tester.tapAt(header.localToGlobal(header.size.center(Offset.zero)));
      await tester.pumpAndSettle();
      expect(controller.sortState, isNot(beforeSort));
      final visible = cells('updated-$i-', prefix: true).first;
      final visibleText = (visible.content as TextEngine).rawChild as String;
      final beforeY = visible.localToGlobal(Offset.zero).dy;
      await tester.drag(find.byType(ElTable), Offset(0, -150));
      await tester.pumpAndSettle();
      final remaining = cells(visibleText).toList();
      expect(remaining.isEmpty || remaining.first.localToGlobal(Offset.zero).dy < beforeY, isTrue);
      await tester.drag(find.byType(ElTable), Offset(0, 500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(ElView());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });
}
