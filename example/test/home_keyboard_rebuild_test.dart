// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';
import '../lib/src/router/index.dart';
import 'home_showcase_test.dart' as fixture;

void main() {
  setUpAll(fixture.loadShowcaseFonts);

  testWidgets('首页聚焦和键盘高度变化只更新相关内容', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    routingConfig.isMobile = true;
    router.go('/home');
    await tester.pumpWidget(App());
    await tester.pumpAndSettle();
    await fixture.reveal(tester, 'scenario-form');
    final input = find.byWidgetPredicate((widget) => widget is ElInput && widget.semanticLabel == '显示名称');
    await tester.ensureVisible(input);
    await tester.pumpAndSettle();
    final focus = tester.widget<ElInput>(input).focusNode!;
    final scroll = tester.widget<ElScrollView>(find.byKey(ValueKey('showcase-scroll'))).controller!;
    final initialViewport = scroll.position.viewportDimension;
    final previous = debugOnRebuildDirtyWidget;
    final builds = <String, int>{};
    // 统计构建范围，避免把无头测试耗时当成真机帧耗时。
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final type = element.widget.runtimeType.toString();
      builds.update(type, (count) => count + 1, ifAbsent: () => 1);
      previous?.call(element, builtOnce);
    };
    final reports = <Map<String, Object>>[];
    Future<void> sample(String phase, FutureOr<void> Function() action) async {
      builds.clear();
      final before = {
        for (final render in tester.renderObjectList<ElRenderView>(find.byType(ElView, skipOffstage: false)))
          render: render.debugLayoutCount,
      };
      await action();
      await tester.pump();
      var layouts = 0, offscreenLayouts = 0;
      final viewport = Rect.fromLTWH(0, 57, 390, scroll.position.viewportDimension);
      for (final entry in before.entries) {
        final render = entry.key;
        final count = render.debugLayoutCount - entry.value;
        layouts += count;
        if (count > 0 && render.attached && render.hasSize) {
          final rect = MatrixUtils.transformRect(render.getTransformTo(null), render.paintBounds);
          if (!rect.overlaps(viewport)) offscreenLayouts += count;
        }
      }
      final sorted = builds.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      reports.add({
        'phase': phase,
        'builds': builds.values.fold<int>(0, (sum, count) => sum + count),
        'byType': Map.fromEntries(sorted),
        'layouts': layouts,
        'offscreenLayouts': offscreenLayouts,
      });
      expect(tester.takeException(), isNull, reason: phase);
    }

    try {
      await sample('focus', () => tester.tap(input));
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.pump(Duration(milliseconds: 300));
      for (final height in [120.0, 240.0, 320.0]) {
        await sample('keyboard-$height', () => tester.view.viewInsets = FakeViewPadding(bottom: height));
        await tester.pump(Duration(milliseconds: 16));
      }
      expect(scroll.position.viewportDimension, lessThan(initialViewport));
      expect(focus.hasFocus, isTrue);
      tester.testTextInput.enterText('键盘回归');
      await tester.pump();
      await sample('keyboard-close', () => tester.view.viewInsets = FakeViewPadding());
      expect(scroll.position.viewportDimension, initialViewport);
      expect(ElForm.of(tester.element(input)).formData['name'], '键盘回归');
    } finally {
      debugOnRebuildDirtyWidget = previous;
    }
    final json = JsonEncoder.withIndent('  ').convert(reports);
    for (final report in reports) {
      debugPrint(
        '${report['phase']}: ${report['builds']} 次构建，${report['layouts']} 次布局，屏外 ${report['offscreenLayouts']}',
      );
    }
    final report = Platform.environment['HOME_KEYBOARD_REPORT'];
    if (report != null) File(report).writeAsStringSync(json);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(seconds: 4));
    for (final report in reports.where((report) => report['phase'] != 'focus')) {
      final types = report['byType']! as Map<String, int>;
      expect(types['ShowcasePanel'] ?? 0, 0, reason: '${report['phase']} 不重建整页面板');
      expect(types['ShowcaseHero'] ?? 0, 0, reason: '${report['phase']} 不重建屏外首屏');
      expect(types['EditableView'] ?? 0, 0, reason: '${report['phase']} 不唤醒常驻编辑器');
      expect(report['builds'], lessThan(1000), reason: '${report['phase']} 只更新导航与视口');
      expect(report['layouts'], lessThan(50), reason: '${report['phase']} 不能把整棵 ElView 子树标记为需要布局');
      expect(report['offscreenLayouts'], lessThan(10), reason: '${report['phase']} 不重排屏外展示内容');
    }
  });
}
