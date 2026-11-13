import 'dart:convert';

import 'package:example/src/pages/examples/scroll_examples/cards.dart';
import 'package:example/src/pages/examples/scroll_examples/comparison_list.dart';
import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

const _timing = bool.fromEnvironment('BUSINESS_CREATION_PERF');
const _warmups = _timing ? 2 : 0;
const _samples = _timing ? 3 : 1;

// 只读现有行配置中的记录集合，兼容优化前的 List 与优化后的 Map。
int _recordCount(WidgetTester tester, String scene) {
  final finder = find.byType(SliverComparisonList);
  final list = tester.widget<SliverComparisonList>(finder);
  expect(list.itemCount, 1000);
  final frame = list.itemBuilder(tester.element(finder), 0) as RepaintBoundary;
  final dynamic row = frame.child;
  final dynamic records = scene == 'cards' ? row.adapter.records : row.records.items;
  return records.length as int;
}

VoidCallback _official(WidgetTester tester, String scene) {
  final finder = find.byKey(ValueKey('$scene-menu'));
  final dynamic menu = tester.widget(finder);
  final Iterable entries = menu.itemBuilder(tester.element(finder));
  final dynamic option = entries.singleWhere((dynamic entry) => entry.key == ValueKey('$scene-mode-official'));
  return () => menu.onSelected(option.value);
}

Future<void> _warmImages(WidgetTester tester) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(home: SizedBox(key: key)));
  final errors = <Object>[];
  await tester.runAsync(() async {
    for (final name in ['owl.jpg', 'owl-2.jpg']) {
      await precacheImage(
        ResizeImage.resizeIfNeeded(960, null, AssetImage('assets/recycler_cards/$name')),
        key.currentContext!,
        onError: (error, _) => errors.add(error),
      ).timeout(Duration(seconds: 15));
    }
  });
  expect(errors, isEmpty);
  await tester.pumpAndSettle();
  await tester.pumpWidget(SizedBox.shrink());
}

void _report(String scene, String mode, String phase, List<int> times, List<int> records) {
  final sorted = [...times]..sort();
  debugPrintSynchronously(
    'RECORDS_CREATION_RESULT ${jsonEncode({
      'scene': scene,
      'mode': mode,
      'phase': phase,
      'samples': records.length,
      'warmups': _warmups,
      'record_counts': records,
      'timing': _timing,
      if (_timing) 'raw_us': times,
      if (_timing) 'median_us': sorted[(sorted.length - 1) ~/ 2],
      if (_timing) 'p95_us': sorted[(sorted.length * .95).ceil() - 1],
      'viewport': [390, 800],
      'device_pixel_ratio': 1,
      'scope': 'instrumented flutter_tester debug action+pump wall time; not device frame time',
      'count_scope': 'records retained by the actual page, including viewport and cache; not widget count',
      'mode_note': 'page defaults to recycler; official measures a subsequent container switch with the same records',
      'images': scene == 'cards' ? 'real local images predecoded before timed mounts' : 'no images',
    })}',
  );
}

void main() {
  for (final scene in ['cards', 'selection']) {
    testWidgets('记录创建 $scene 首次复用页面及官方容器切换', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final initialTimes = <int>[];
      final switchTimes = <int>[];
      final initialCounts = <int>[];
      final switchCounts = <int>[];
      try {
        if (scene == 'cards') await _warmImages(tester);
        for (var sample = -_warmups; sample < _samples; sample++) {
          await tester.pumpWidget(SizedBox.shrink());
          await tester.pumpAndSettle();
          final watch = Stopwatch()..start();
          await tester.pumpWidget(
            ElComponentProvider(
              components: el.mobileComponents,
              child: MaterialApp(home: scene == 'cards' ? RecyclerCardsPage() : RecyclerSelectionPage()),
            ),
          );
          watch.stop();
          final initialCount = _recordCount(tester, scene);
          expect(initialCount, inInclusiveRange(1, 1000));
          expect(find.byWidgetPredicate((widget) => widget is ElSliverList), findsOneWidget);
          if (sample >= 0) {
            initialTimes.add(watch.elapsedMicroseconds);
            initialCounts.add(initialCount);
          }
          await tester.pumpAndSettle();
          if (scene == 'cards') {
            for (final image in find.byType(RawImage).evaluate()) {
              expect((image.renderObject! as RenderImage).image, isNotNull);
            }
          }
          final switchMode = _official(tester, scene);
          watch
            ..reset()
            ..start();
          switchMode();
          await tester.pump();
          watch.stop();
          final switchCount = _recordCount(tester, scene);
          expect(switchCount, inInclusiveRange(initialCount, 1000));
          expect(find.byType(SliverList), findsOneWidget);
          if (sample >= 0) {
            switchTimes.add(watch.elapsedMicroseconds);
            switchCounts.add(switchCount);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        _report(scene, 'recycler', 'initialPage', initialTimes, initialCounts);
        _report(scene, 'official', 'containerSwitch', switchTimes, switchCounts);
      } finally {
        await tester.pumpWidget(SizedBox.shrink());
        await tester.pump();
      }
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }
}
