import 'dart:convert';
import 'dart:io';

import 'package:example/src/pages/examples/bibi/bibi.dart';
import 'package:example/src/pages/examples/scroll_examples/media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('BIBI_GRID_PERFORMANCE');
const _width = 390.0;
const _height = 844.0;
const _frame = Duration(microseconds: 8333);
const _step = 40.0;
const _samples = 96;
const _atlas = 'assets/recycler_cards/bili_home.webp';
const _firstTitle = '职业选手的极限反打，第一视角复盘';
const _secondRowTitle = '从小城出发，找到了这片安静的海';

enum _Scenario { home, grid }

void main() {
  // flutter test test/bibi_grid_performance_test.dart --dart-define=BIBI_GRID_PERFORMANCE=true
  testWidgets('Bibi 首页与同卡片 Grid 的整页滚动耗时', skip: !_enabled, (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('bibi-grid-perf-')))!;
    addTearDown(() async => directory.delete());
    await tester.pumpWidget(_app(Scaffold()));
    await _warmAtlas(tester);

    final runs = <Map<String, Object>>[];
    final timings = {for (final scenario in _Scenario.values) scenario: (forward: <int>[], reverse: <int>[])};
    double? viewport;
    double? rowExtent;
    double? titleWidth;
    // ABBA 顺序降低首次 JIT 和场景执行顺序对两边的偏置。
    for (final scenario in [_Scenario.home, _Scenario.grid, _Scenario.grid, _Scenario.home]) {
      final (host, controller) = await _open(tester, scenario, directory.path);
      if (viewport != null) {
        // 只调整测试窗口高度，使两页实际参与虚拟化的视口一致。
        final delta = viewport - controller.position.viewportDimension;
        if (delta != 0) {
          tester.view.physicalSize = Size(_width, _height + delta);
          await tester.pumpAndSettle();
        }
        expect(controller.position.viewportDimension, closeTo(viewport, .01));
      }
      viewport ??= controller.position.viewportDimension;

      final first = tester.getRect(find.descendant(of: host, matching: find.text(_firstTitle)).first);
      final second = tester.getRect(find.descendant(of: host, matching: find.text(_secondRowTitle)).first);
      final extent = second.top - first.top;
      if (rowExtent != null) expect(extent, closeTo(rowExtent, .01));
      if (titleWidth != null) expect(first.width, closeTo(titleWidth, .01));
      rowExtent ??= extent;
      titleWidth ??= first.width;
      expect(extent, greaterThan(0));

      // 对齐正文坐标，去掉 Bibi 首页在首行上方的轮播偏移。
      final bodyOrigin = first.top - tester.getTopLeft(host).dy + controller.offset;
      controller.jumpTo(bodyOrigin);
      await tester.pumpAndSettle();
      await _measure(tester, controller, bodyOrigin, _step, sampleCount: 8);
      final start = bodyOrigin + rowExtent * 25;
      final end = start + _samples * _step;
      expect(end, lessThan(controller.position.maxScrollExtent));
      controller.jumpTo(start);
      await tester.pumpAndSettle();
      final forward = await _measure(tester, controller, start, _step);
      final reverse = await _measure(tester, controller, end, -_step);
      timings[scenario]!.forward.addAll(forward);
      timings[scenario]!.reverse.addAll(reverse);
      runs.add({'page': scenario.name, 'forward': _summary(forward), 'reverse': _summary(reverse)});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
    }
    debugPrint(
      'BIBI_GRID_PERFORMANCE ${jsonEncode({
        'scope': 'whole-page headless widget-test pump wall time during one linear animateTo per leg',
        'viewport_width': _width,
        'viewport_height': viewport,
        'row_extent': rowExtent,
        'step_px': _step,
        'frame_interval_us': _frame.inMicroseconds,
        'scenarios': {
          for (final entry in timings.entries) entry.key.name: {'forward': _summary(entry.value.forward), 'reverse': _summary(entry.value.reverse)},
        },
        'runs': runs,
      })}',
    );
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(platform: .android),
  home: ElComponentProvider(components: el.mobileComponents, child: child),
);

Future<void> _warmAtlas(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold));
  Object? failure;
  await tester.runAsync(() => precacheImage(AssetImage(_atlas), context, onError: (error, _) => failure = error));
  expect(failure, isNull);
  await tester.pump();
}

Future<(Finder, ScrollController)> _open(WidgetTester tester, _Scenario scenario, String directory) async {
  tester.view.physicalSize = Size(_width, _height);
  final Finder host;
  if (scenario == _Scenario.home) {
    await tester.pumpWidget(_app(BibiPage()));
    await tester.pumpAndSettle();
    host = find.descendant(of: find.byKey(ValueKey('bibi-feed-1')), matching: find.byType(ElScroll));
    final tabs = find.byKey(ValueKey('bibi-tabs'));
    final expanded = tester.getTopLeft(tabs).dy;
    final drag = await tester.startGesture(tester.getCenter(host));
    await drag.moveBy(Offset(0, -23), timeStamp: Duration(milliseconds: 70));
    await tester.pump(Duration(milliseconds: 70));
    await drag.moveBy(Offset(0, -32), timeStamp: Duration(milliseconds: 150));
    await tester.pump(Duration(milliseconds: 150));
    await tester.pump(Duration(milliseconds: 200));
    await drag.up(timeStamp: Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(tabs).dy, closeTo(expanded - 58, .01));
  } else {
    await tester.pumpWidget(_app(RecyclerVideoGridPage(directory: directory)));
    final empty = find.text('这里还没有可显示的影像');
    for (var attempt = 0; attempt < 30 && empty.evaluate().isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(empty, findsOneWidget);
    await tester.tap(find.byKey(ValueKey('media-scroll-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('media-mode-bibiCards')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('media-scroll-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('media-mode-official')));
    await tester.pumpAndSettle();
    host = find.byKey(ValueKey('media-bibi-official'));
  }
  final scrollView = tester.widget(host);
  final controller = switch (scrollView) {
    ElScroll(:final controller) => controller!,
    CustomScrollView(:final controller) => controller!,
    _ => throw StateError('缺少滚动宿主'),
  };
  expect(controller.offset, 0);
  return (host, controller);
}

Future<List<int>> _measure(
  WidgetTester tester,
  ScrollController controller,
  double origin,
  double step, {
  int sampleCount = _samples,
}) async {
  // 最后一帧仍在同一次动画内，取消与换向的开销留在采样区间外。
  final animation = controller.animateTo(
    origin + (sampleCount + 1) * step,
    duration: _frame * (sampleCount + 1),
    curve: Curves.linear,
  );
  await tester.pump();
  expect(controller.offset, closeTo(origin, .01));
  final samples = <int>[];
  for (var frame = 1; frame <= sampleCount; frame++) {
    final watch = Stopwatch()..start();
    await tester.pump(_frame);
    watch.stop();
    samples.add(watch.elapsedMicroseconds);
    expect(controller.offset, closeTo(origin + frame * step, .01));
  }
  controller.jumpTo(origin + sampleCount * step);
  await animation;
  await tester.pumpAndSettle();
  return samples;
}

Map<String, num> _summary(List<int> samples) {
  final sorted = [...samples]..sort();
  double percentile(double fraction) => sorted[(sorted.length * fraction).ceil() - 1] / 1000;
  return {
    'frames': sorted.length,
    'mean_ms': sorted.fold(0, (sum, value) => sum + value) / sorted.length / 1000,
    'p95_ms': percentile(.95),
    'p99_ms': percentile(.99),
    'max_ms': sorted.last / 1000,
    'over_8_33_ms': sorted.where((value) => value > _frame.inMicroseconds).length,
  };
}
