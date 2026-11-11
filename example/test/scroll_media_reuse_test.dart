import 'dart:io';
import 'dart:ui' as ui;

import 'package:example/src/pages/examples/scroll_examples/media.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void _mode(WidgetTester tester, String mode) {
  final finder = find.byKey(ValueKey('media-scroll-menu'));
  final dynamic menu = tester.widget(finder);
  final Iterable entries = menu.itemBuilder(tester.element(finder));
  final dynamic option = entries.singleWhere((dynamic item) => item.key == ValueKey('media-mode-$mode'));
  menu.onSelected(option.value);
}

Future<void> _mount(
  WidgetTester tester,
  Widget page, {
  double width = 390,
  double scale = 1,
  bool rtl = false,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: dark ? .dark : .light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: rtl ? .rtl : .ltr, child: child!),
      ),
      home: ElComponentProvider(components: el.mobileComponents, child: page),
    ),
  );
  await tester.pumpAndSettle();
}

SliverGridLayout _layout(WidgetTester tester) {
  final grid = find.byType(SliverGrid);
  final widget = tester.widget<SliverGrid>(grid);
  final render = tester.renderObject<RenderSliverGrid>(grid);
  return widget.gridDelegate.getLayout(render.constraints);
}

ScrollController _controller(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

void main() {
  testWidgets('官方媒体瀑布流复用几何，宽度字号和方向变化正确失效', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final page = RecyclerWaterfallPage();
    await _mount(tester, page);
    _mode(tester, 'official');
    await tester.pumpAndSettle();
    final first = _layout(tester);
    expect(_layout(tester), same(first));
    _controller(tester).jumpTo(800);
    await tester.pumpAndSettle();
    expect(_layout(tester), same(first));

    await _mount(tester, page, dark: true);
    expect(_layout(tester), same(first), reason: '颜色变化不改变固定几何。');
    await _mount(tester, page, width: 430);
    final wider = _layout(tester);
    expect(wider, isNot(same(first)));
    expect(
      wider.getGeometryForChildIndex(0).crossAxisExtent,
      greaterThan(first.getGeometryForChildIndex(0).crossAxisExtent),
    );
    await _mount(tester, page, width: 430, scale: 1.5);
    final scaled = _layout(tester);
    expect(
      scaled.getGeometryForChildIndex(0).mainAxisExtent,
      greaterThan(wider.getGeometryForChildIndex(0).mainAxisExtent),
    );
    await _mount(tester, page, width: 430, scale: 1.5, rtl: true);
    final reversed = _layout(tester);
    expect(reversed, isNot(same(scaled)));
    expect(reversed.getGeometryForChildIndex(0).crossAxisOffset, greaterThan(0));
    expect(reversed.getGeometryForChildIndex(1).crossAxisOffset, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('换绑保持相同来源文字，selector 自身不重建', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final page = RecyclerWaterfallPage();
    await _mount(tester, page);
    final sources = find.byWidgetPredicate((widget) => widget is ElView && widget.child == '自然影像集');
    final records = <Element, Object?>{};
    for (final element in sources.evaluate()) {
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is! ElListenableBuilder) return true;
        final listenable = (ancestor.widget as ElListenableBuilder).listenable! as ValueListenable;
        records[ancestor] = listenable.value;
        return false;
      });
    }
    expect(records, isNotEmpty);
    final builds = <Element, int>{};
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (records.containsKey(element)) builds.update(element, (count) => count + 1, ifAbsent: () => 1);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    _controller(tester).jumpTo(1600);
    await tester.pumpAndSettle();
    final rebound = records.keys.where((element) {
      if (!element.mounted) return false;
      final listenable = (element.widget as ElListenableBuilder).listenable! as ValueListenable;
      return !identical(listenable.value, records[element]);
    }).toList();
    expect(rebound, isNotEmpty, reason: '必须真实换绑其他业务记录，不能只测停放不更新。');
    for (final element in rebound) {
      expect(builds[element] ?? 0, 0);
    }
    expect(sources, findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('本地来源刷新即使数量不变也重新生成官方几何', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final directory = await tester.runAsync(() => Directory.systemTemp.createTemp('media-geometry-'));
    final file = File(path.join(directory!.path, '唯一图片.png'));
    addTearDown(() async {
      await tester.runAsync(() async {
        if (await file.exists()) await file.delete();
        await directory.delete();
      });
    });
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, 24, 32), Paint()..color = Colors.orange);
      final picture = recorder.endRecording();
      final image = await picture.toImage(24, 32);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    Future<void> waitForSource() async {
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: 10)));
        await tester.pump();
        if (find.byKey(ValueKey('media-card')).evaluate().isNotEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      fail('本地图片未在有界等待内完成读取。');
    }

    // IO 完成前转圈不会 settle，先只挂载一帧，再有界等待真实目录读取。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 800);
    await tester.pumpWidget(
      MaterialApp(
        home: ElComponentProvider(
          components: el.mobileComponents,
          child: RecyclerWaterfallPage(directory: directory.path),
        ),
      ),
    );
    await waitForSource();
    _mode(tester, 'official');
    await tester.pumpAndSettle();
    final before = _layout(tester);
    final count = tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate.estimatedChildCount;
    await tester.tap(find.byTooltip('刷新'));
    await waitForSource();
    expect(tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate.estimatedChildCount, count);
    expect(_layout(tester), isNot(same(before)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
