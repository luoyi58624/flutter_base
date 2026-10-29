import 'dart:async';

import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/reparent.dart';

class _Header extends StatefulWidget {
  const _Header({super.key, required this.mode});
  final ElScrollCollapseMode mode;
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with ElScrollMixin<_Header>, ElScrollCollapseMixin<_Header> {
  @override
  ElScrollCollapseMode get scrollCollapseMode => widget.mode;
  @override
  bool get scrollCollapseSnap => false;
  double get range => scrollCollapseRange;
  @override
  Widget build(BuildContext context) => widget.mode == .consumeDelta
      ? buildScrollCollapse(
          context,
          expanded: ElView(style: ElStyle(height: 100), child: 'expanded'),
          collapsed: ElView(style: ElStyle(height: 40), child: 'compact'),
        )
      : buildScrollCollapse(context, child: ElView(style: ElStyle(height: 100), child: 'header'));
}

class _LargeHeader extends StatefulWidget {
  const _LargeHeader({super.key});
  @override
  State<_LargeHeader> createState() => _LargeHeaderState();
}

class _LargeHeaderState extends State<_LargeHeader> with ElScrollMixin<_LargeHeader>, ElLargeTitleNavbarMixin<_LargeHeader> {
  @override
  bool get largeTitleNavbarSnap => false;
  @override
  Widget build(BuildContext context) => buildLargeTitleNavbar(
    context,
    largeTitle: ElView(style: ElStyle(fontSize: 34), child: '大标题'),
    compactTitle: ElView(style: ElStyle(fontSize: 18), child: '小标题'),
    actions: [ElView(style: ElStyle(width: 0, height: 56))],
  );
}

Future<void> dragBy(WidgetTester tester, double delta) async {
  final gesture = await tester.startGesture(Offset(400, delta < 0 ? 480 : 160));
  await gesture.moveBy(Offset(0, delta.sign * 25));
  await tester.pump(Duration(milliseconds: 16));
  for (var i = 0; i < 12; i++) {
    await gesture.moveBy(Offset(0, delta / 12));
    await tester.pump(Duration(milliseconds: 16));
  }
  await tester.pump(Duration(milliseconds: 200));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final virtual in [false, true]) {
    testWidgets('Scroll 连续同尺寸重挂保留位置，双向滚动仍有效 virtual=$virtual', (tester) async {
      final move = GlobalKey<ReparentHarnessState>();
      final controller = ElScrollController();
      Widget row(int i) => ElView(key: ValueKey('row-$i'), style: ElStyle(height: 70), child: 'row-$i');
      await tester.pumpWidget(lifecycleHost(ReparentHarness(
        key: move,
        child: ElScrollView(
          controller: controller,
          physics: ElClampingScrollPhysics(),
          scrollbar: ElWindowScrollBar(),
          children: [
            if (virtual)
              ElListView.builder(itemCount: 100, fixedSize: true, itemBuilder: (_, i) => row(i))
            else
              for (var i = 0; i < 100; i++) row(i),
          ],
        ),
      )));
      await tester.pumpAndSettle();
      controller.jumpTo(700);
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.byKey(ValueKey('row-11')));
      final position = controller.position;
      for (var i = 0; i < 3; i++) {
        await reparent(tester, move);
        expect(controller.position, same(position));
        expect(controller.offset, closeTo(700, .01));
        expect(tester.getTopLeft(find.byKey(ValueKey('row-11'))), before);
      }
      await dragBy(tester, -120);
      expect(controller.offset, greaterThan(700));
      await dragBy(tester, 240);
      expect(controller.offset, lessThan(700));
      await tester.pumpWidget(ElView());
      expect(controller.hasClients, isFalse);
      controller.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in ElScrollCollapseMode.values) {
    testWidgets('折叠效果重挂保留当前进度和行程 mode=$mode', (tester) async {
      final move = GlobalKey<ReparentHarnessState>();
      final header = GlobalKey<_HeaderState>();
      final controller = ElScrollController();
      addTearDown(() async {
        await tester.pumpWidget(ElView());
        controller.dispose();
      });
      await tester.pumpWidget(lifecycleHost(ReparentHarness(
        key: move,
        child: ElScrollView(
          controller: controller,
          physics: ElClampingScrollPhysics(),
          scrollbar: ElNoScrollBar(),
          children: [
            _Header(key: header, mode: mode),
            for (var i = 0; i < 50; i++) ElView(style: ElStyle(height: 70), child: 'row-$i'),
          ],
        ),
      )));
      await tester.pumpAndSettle();
      final state = header.currentState!;
      final range = state.range;
      expect(range, greaterThan(0));
      await dragBy(tester, -240);
      final progress = state.scrollCollapseProgress;
      expect(progress, greaterThan(.9));
      for (var i = 0; i < 3; i++) {
        await reparent(tester, move);
        expect(header.currentState, same(state));
        expect(state.range, range);
        expect(state.scrollCollapseProgress, closeTo(progress, .001), reason: '仅重挂不能让已折叠内容无故展开');
      }
      await dragBy(tester, 500);
      expect(state.scrollCollapseProgress, closeTo(0, .001));
      await dragBy(tester, -200);
      expect(state.scrollCollapseProgress, greaterThan(.9));
    });
  }

  for (final fraction in [.35, 1.0]) {
    testWidgets('LargeTitle 正文零位移时重挂不能丢失折叠进度 fraction=$fraction', (tester) async {
      final move = GlobalKey<ReparentHarnessState>();
      final header = GlobalKey<_LargeHeaderState>();
      final controller = ElScrollController();
      addTearDown(() async {
        await tester.pumpWidget(ElView());
        controller.dispose();
      });
      await tester.pumpWidget(lifecycleHost(ReparentHarness(
        key: move,
        child: ElScrollView(
          controller: controller, physics: ElClampingScrollPhysics(), scrollbar: ElNoScrollBar(),
          children: [_LargeHeader(key: header), for (var i = 0; i < 30; i++) ElView(style: ElStyle(height: 70))],
        ),
      )));
      await tester.pumpAndSettle();
      final state = header.currentState!;
      final range = state.scrollEffectTracks.single.pixelsPerUnit;
      await dragBy(tester, -range * fraction);
      expect(controller.offset, closeTo(0, .01));
      final progress = state.largeTitleNavbarProgress;
      expect(progress, greaterThan(.1));
      final height = tester.getSize(find.byKey(header)).height;
      for (var i = 0; i < 3; i++) {
        await reparent(tester, move);
        expect(state.largeTitleNavbarProgress, closeTo(progress, .001));
        expect(tester.getSize(find.byKey(header)).height, closeTo(height, .01));
      }
      await dragBy(tester, 120);
      expect(state.largeTitleNavbarProgress, closeTo(0, .001));
    });
  }

  for (final large in [false, true]) {
    testWidgets('效果迁移到不同滚动宿主不能携带旧位置进度 large=$large', (tester) async {
      final move = GlobalKey<ReparentHarnessState>();
      final header = GlobalKey();
      final controllers = [ElScrollController(), ElScrollController()];
      double progress() => switch (header.currentState) {
        _LargeHeaderState state => state.largeTitleNavbarProgress,
        _HeaderState state => state.scrollCollapseProgress,
        _ => throw StateError('缺少效果 State'),
      };
      await tester.pumpWidget(lifecycleHost(ReparentHarness(
        key: move,
        wrap: (generation, child) => ElScrollView(
          controller: controllers[generation % 2],
          physics: ElClampingScrollPhysics(),
          scrollbar: ElNoScrollBar(),
          children: [child, for (var i = 0; i < 30; i++) ElView(style: ElStyle(height: 70))],
        ),
        child: large ? _LargeHeader(key: header) : _Header(key: header, mode: .consumeDelta),
      )));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await dragBy(tester, -30);
        expect(progress(), greaterThan(.1));
        await reparent(tester, move);
        expect(progress(), closeTo(0, .001));
        expect(controllers[i % 2].hasClients, isFalse);
        expect(controllers[(i + 1) % 2].hasClients, isTrue);
      }
      await tester.pumpWidget(ElView());
      for (final controller in controllers) {
        controller.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final finishAfterDispose in [false, true]) {
    testWidgets('异步刷新跨重挂/销毁完成不重复调用或访问失效宿主 dispose=$finishAfterDispose', (tester) async {
      final move = GlobalKey<ReparentHarnessState>();
      final controller = ElScrollController();
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(lifecycleHost(ReparentHarness(
        key: move,
        child: ElScrollView(
          controller: controller,
          physics: ElClampingScrollPhysics(),
          onRefresh: () { calls++; return done.future; },
          children: [for (var i = 0; i < 30; i++) ElView(style: ElStyle(height: 70), child: 'row-$i')],
        ),
      )));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(Offset(400, 180));
      await gesture.moveBy(Offset(0, 30));
      await tester.pump(Duration(milliseconds: 16));
      await gesture.moveBy(Offset(0, 280));
      await tester.pump(Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump(Duration(milliseconds: 300));
      expect(calls, 1);
      await reparent(tester, move, settle: false);
      if (finishAfterDispose) await tester.pumpWidget(ElView());
      done.complete();
      await tester.pumpAndSettle();
      expect(calls, 1);
      if (!finishAfterDispose) {
        await dragBy(tester, -150);
        expect(controller.offset, greaterThan(0));
        await tester.pumpWidget(ElView());
      }
      expect(controller.hasClients, isFalse);
      controller.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
