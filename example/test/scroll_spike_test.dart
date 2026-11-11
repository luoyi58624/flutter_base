import 'dart:convert';

import 'package:example/src/pages/examples/scroll_examples/scroll_mode.dart';
import 'package:example/src/pages/examples/scroll_examples/spike.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Injection = (Duration, SchedulerPhase);

const _baseline = bool.fromEnvironment('SPECIAL_REUSE_BASELINE');

Future<List<_Injection>> _open(WidgetTester tester, [SliverExampleMode mode = .recycler]) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 840);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final work = <_Injection>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: .android),
      home: ElComponentProvider(
        components: el.mobileComponents,
        child: RecyclerSpikePage(runWork: (duration) => work.add((duration, SchedulerBinding.instance.schedulerPhase))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (mode != .recycler) {
    await tester.tap(find.byKey(ValueKey('comparison-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('comparison-mode-${mode.name}')));
    await tester.pumpAndSettle();
  }
  return work;
}

Future<void> _move(WidgetTester tester, TestGesture gesture, double dy, int timestamp) async {
  await gesture.moveBy(Offset(0, dy), timeStamp: Duration(milliseconds: timestamp));
  await tester.pump(Duration(milliseconds: 16));
}

Finder _list(SliverExampleMode mode) => find.byKey(ValueKey('comparison-${mode.name}-list'));

void main() {
  testWidgets('尖峰参数操作保留列表，换绑只更新编号', (tester) async {
    final work = await _open(tester);
    final rows = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_SpikeRow');
    final original = {for (final element in rows.evaluate()) element: element.widget};
    final originalList = tester.widget<ElSliverRecyclerList>(find.byType(ElSliverRecyclerList));
    var builds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (element.widget.runtimeType.toString() == '_SpikeRow') builds++;
    };
    try {
      tester.widget<ChoiceChip>(find.byKey(ValueKey('spike-budget-12'))).onSelected!(true);
      await tester.pumpAndSettle();
      debugPrintSynchronously(
        'SPECIAL_REUSE_RESULT ${jsonEncode({'scene': 'spike', 'phase': 'budget', 'row_rebuilds': builds, 'changed_row_widgets': original.entries.where((entry) => entry.key.mounted && !identical(entry.key.widget, entry.value)).length})}',
      );
      if (!_baseline) {
        expect(builds, 0);
        expect(tester.widget<ElSliverRecyclerList>(find.byType(ElSliverRecyclerList)), same(originalList));
        for (final entry in original.entries) {
          expect(entry.key.widget, same(entry.value));
        }
      }
      expect(work, isEmpty, reason: '调整参数不能触发真实尖峰工作。');
      final factory = tester.widget<ElSliverRecyclerList>(find.byType(ElSliverRecyclerList)).itemBuilder;
      final index = ValueNotifier(0);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ElComponentProvider(
              components: el.mobileComponents,
              child: Scaffold(body: Builder(builder: (context) => factory(context, index))),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = tester.element(rows);
        final rowWidget = row.widget;
        final caption = tester.widget<Text>(find.text('统一行高 · 逻辑像素'));
        builds = 0;
        index.value = 4;
        await tester.pumpAndSettle();
        expect(find.text('滚动采样 00005'), findsOneWidget);
        debugPrintSynchronously(
          'SPECIAL_REUSE_RESULT ${jsonEncode({'scene': 'spike', 'phase': 'rebind', 'row_rebuilds': builds, 'changed_row_widgets': identical(row.widget, rowWidget) ? 0 : 1})}',
        );
        if (!_baseline) {
          expect(builds, 0);
          expect(row.widget, same(rowWidget));
          expect(tester.widget<Text>(find.text('统一行高 · 逻辑像素')), same(caption));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(SizedBox.shrink());
      } finally {
        index.dispose();
      }
    } finally {
      debugOnRebuildDirtyWidget = previous;
    }
  });

  for (final mode in SliverExampleMode.values) {
    testWidgets('${mode.label} 脚本跨越相同距离并在 transient 阶段只执行一次 12ms 任务', (tester) async {
      final work = await _open(tester, mode);
      await tester.tap(find.byKey(ValueKey('spike-budget-12')));
      await tester.pump();
      expect(find.text('滚动采样 00001').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('spike-script')));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 100));
      expect(work, isEmpty);
      await tester.pumpAndSettle(Duration(milliseconds: 50));
      expect(work, [(Duration(milliseconds: 12), SchedulerPhase.transientCallbacks)]);
      expect(find.text('滚动采样 00028').hitTestable(), findsOneWidget);
      final result = tester.widget<Text>(find.byKey(ValueKey('spike-result'))).data!;
      expect(result, startsWith('${mode.label} · 脚本快滑 · 目标 12 ms'));
      work.clear();
      await tester.tap(find.byKey(ValueKey('spike-script')));
      await tester.pumpAndSettle(Duration(milliseconds: 50));
      expect(work, [(Duration(milliseconds: 12), SchedulerPhase.transientCallbacks)]);
      expect(find.text('滚动采样 00028').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('手势武装仅在真实列表拖动时执行一次，并可在执行前取消', (tester) async {
    final work = await _open(tester);
    await tester.tap(find.byKey(ValueKey('spike-budget-20')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('spike-arm')));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(ValueKey('comparison-recycler-list')), Offset(0, -90));
    await tester.pumpAndSettle();
    expect(work, isEmpty);

    await tester.tap(find.byKey(ValueKey('spike-arm')));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('comparison-recycler-list'))));
    await _move(tester, gesture, -40, 16);
    await _move(tester, gesture, -90, 32);
    expect(work, [(Duration(milliseconds: 20), SchedulerPhase.transientCallbacks)]);
    await _move(tester, gesture, -90, 48);
    await gesture.up(timeStamp: Duration(milliseconds: 64));
    await tester.pumpAndSettle();
    expect(work, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final mode in SliverExampleMode.values) {
    testWidgets('${mode.label} 惯性模式等待手指抬起后的实际滚动，再安排一次 8ms 任务', (tester) async {
      final work = await _open(tester, mode);
      await tester.tap(find.byKey(ValueKey('spike-phase')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('松手惯性').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('spike-arm')));
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(_list(mode)));
      await _move(tester, gesture, -50, 16);
      await _move(tester, gesture, -60, 32);
      await _move(tester, gesture, -70, 48);
      expect(work, isEmpty);
      await gesture.up(timeStamp: Duration(milliseconds: 49));
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(Duration(milliseconds: 16));
      }
      expect(work, [(Duration(milliseconds: 8), SchedulerPhase.transientCallbacks)]);
      await tester.pumpAndSettle();
      expect(work, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
