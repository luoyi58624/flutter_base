import '../../support/scrollbar_thumb.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

/// 先解除测试窗口上界，再显式提供约束，避免把有限屏幕高度误当作无界。
Widget _host(Widget child, {double? maxHeight, double width = 200}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: .topLeft,
        fit: .deferToChild,
        minWidth: 0,
        maxWidth: width,
        minHeight: 0,
        maxHeight: maxHeight ?? double.infinity,
        child: child,
      ),
    ),
  );
}

class _ProbeFlutterScrollBehavior extends ScrollBehavior {
  const _ProbeFlutterScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const NeverScrollableScrollPhysics();
  }

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return KeyedSubtree(key: const ValueKey<String>('flutter-scrollbar-wrapper'), child: child);
  }
}

class _VisibleBar extends ElAndroidScrollBar {
  _VisibleBar(Color color) : super(thumbColor: color, interactive: true);

  @override
  bool resolveAlwaysVisible(BuildContext context, ElScrollbarAxisDetails axis) => true;
}

Finder _thumb(Color color) => find.byWidgetPredicate((widget) => widget is ElView && widget.style?.bgColor == color);

Future<Color> _pixel(WidgetTester tester, GlobalKey key, Offset point) async => (await tester.runAsync(() async {
  final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage(pixelRatio: 1);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    return Color.fromARGB(255, bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
  } finally {
    image.dispose();
  }
}))!;

ValueKey<String> _stripKey(Axis axis) => ValueKey<String>('el-scrollbar-win-strip-${axis.name}');

ValueKey<String> _trackKey(Axis axis) => ValueKey<String>('probe-scrollbar-track-${axis.name}');

ValueKey<String> _buttonKey(Axis axis, {required bool forward}) {
  return ValueKey<String>('probe-scrollbar-button-${axis.name}-${forward ? 'trailing' : 'leading'}');
}

class _ProbeWindowScrollBar extends ElWindowScrollBar {
  const _ProbeWindowScrollBar();

  @override
  Widget? buildTrack(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  }) {
    return SizedBox.expand(key: _trackKey(axis.axis));
  }

  @override
  Widget buildLeadingButton(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool enabled,
    required bool pressed,
  }) {
    return SizedBox.expand(key: _buttonKey(axis.axis, forward: false));
  }

  @override
  Widget buildTrailingButton(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool enabled,
    required bool pressed,
  }) {
    return SizedBox.expand(key: _buttonKey(axis.axis, forward: true));
  }
}

Widget _scrollbarShortViewportHost({required double extent, required Widget child}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: extent, height: extent, child: child),
    ),
  );
}

Widget _scrollView({
  ScrollController? controller,
  ScrollController? horizontalController,
  double contentWidth = 400.0,
  double contentHeight = 400.0,
}) {
  return ElScrollView(
    axis: null,
    controller: controller,
    horizontalController: horizontalController,
    scrollbar: const _ProbeWindowScrollBar(),
    children: <Widget>[SizedBox(width: contentWidth, height: contentHeight)],
  );
}

void _expectSize(WidgetTester tester, Finder finder, Size expected, {String? reason}) {
  final actual = tester.getSize(finder);
  expect(actual.width, moreOrLessEquals(expected.width, epsilon: 0.001), reason: reason);
  expect(actual.height, moreOrLessEquals(expected.height, epsilon: 0.001), reason: reason);
}

void main() {
  group('Android 滚动条颜色', () {
    testWidgets('显式滑块颜色不订阅 Material 主题，缺省轴仍随主题变化', (tester) async {
      const light = Color(0xff123456);
      const dark = Color(0xffabcdef);
      final theme = ValueNotifier(const Color(0x33112233));
      addTearDown(theme.dispose);
      final configured = <Color>[];
      final fallback = <Color>[];
      var configuredBuilds = 0;
      final content = Column(
        children: [
          Builder(
            builder: (context) {
              configuredBuilds++;
              const bar = ElAndroidScrollBar(thumbColor: light, thumbColorDark: dark);
              configured
                ..clear()
                ..add(bar.resolveThumbColor(context, dark: false, hovered: false, dragging: false))
                ..add(bar.resolveThumbColor(context, dark: true, hovered: false, dragging: false));
              return const ElView();
            },
          ),
          Builder(
            builder: (context) {
              const bar = ElAndroidScrollBar(thumbColor: light);
              fallback
                ..clear()
                ..add(bar.resolveThumbColor(context, dark: false, hovered: false, dragging: false))
                ..add(bar.resolveThumbColor(context, dark: true, hovered: false, dragging: false));
              return const ElView();
            },
          ),
        ],
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ValueListenableBuilder(
            valueListenable: theme,
            child: content,
            builder: (context, color, child) => Theme(
              data: ThemeData(highlightColor: color),
              child: child!,
            ),
          ),
        ),
      );
      expect(configured, [light, dark]);
      expect(fallback, [light, const Color(0xff112233)]);
      final initialBuilds = configuredBuilds;
      theme.value = const Color(0x44556677);
      await tester.pump();
      expect(configuredBuilds, initialBuilds);
      expect(configured, [light, dark]);
      expect(fallback, [light, const Color(0xff556677)]);
    });

    testWidgets('无 Material 祖先时可解析默认颜色，hover 与 drag 保持原有优先级', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Builder(
            builder: (context) {
              const bar = ElAndroidScrollBar(thumbColor: Color(0xff123456));
              expect(
                bar.resolveThumbColor(context, dark: true, hovered: false, dragging: false),
                Theme.of(context).highlightColor.withAlpha(0xff),
              );
              for (final dark in [false, true]) {
                expect(
                  bar.resolveThumbColor(context, dark: dark, hovered: true, dragging: false),
                  dark ? const Color.fromRGBO(255, 255, 255, 0.66) : const Color.fromRGBO(0, 0, 0, 0.54),
                );
                expect(
                  bar.resolveThumbColor(context, dark: dark, hovered: true, dragging: true),
                  dark ? const Color.fromRGBO(255, 255, 255, 0.82) : const Color.fromRGBO(0, 0, 0, 0.70),
                );
              }
              return const ElView();
            },
          ),
        ),
      );
    });
  });

  group('Windows inset 首帧布局', () {
    testWidgets('普通双轴视口使用 Windows inset 滚动条仍撑满约束', (tester) async {
      const selectionKey = ValueKey<String>('bounded-selection-host');
      await tester.pumpWidget(
        _host(
          ElSelectionView(
            key: selectionKey,
            child: const ElScrollView(
              axis: null,
              scrollbar: ElWindowScrollBar(),
              children: [SizedBox(width: 400, height: 400)],
            ),
          ),
          maxHeight: 300,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(selectionKey)), const Size(200, 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows inset 滚动条在首帧同步预留空间，后续帧不再挤压页面', (tester) async {
      const contentKey = ValueKey<String>('first-frame-inset-content');
      await tester.pumpWidget(
        _host(
          const ElScrollView(
            scrollbar: ElWindowScrollBar(),
            children: [SizedBox(key: contentKey, width: double.infinity, height: 400)],
          ),
          maxHeight: 300,
        ),
      );

      final firstFrame = tester.getRect(find.byKey(contentKey));
      expect(firstFrame.width, 185.0, reason: '200px 宿主首帧即扣除 15px Windows 纵向条');
      expect(find.byKey(const ValueKey<String>('el-scrollbar-win-strip-vertical')), findsOneWidget);

      await tester.pump();

      expect(tester.getRect(find.byKey(contentKey)), firstFrame, reason: 'metrics 回刷帧不得再次改变内容布局');
    });

    testWidgets('Windows inset 缓存随 overflow 状态变化同步移除并恢复', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late StateSetter resize;
      var contentHeight = 400.0;
      const contentKey = ValueKey<String>('dynamic-inset-content');
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              resize = setState;
              return ElScrollView(
                controller: controller,
                scrollbar: const ElWindowScrollBar(),
                children: [SizedBox(key: contentKey, width: double.infinity, height: contentHeight)],
              );
            },
          ),
          maxHeight: 300,
        ),
      );

      expect(tester.getSize(find.byKey(contentKey)).width, 185.0);
      expect(controller.position.maxScrollExtent, 100.0);

      resize(() => contentHeight = 100.0);
      await tester.pump();
      expect(tester.getSize(find.byKey(contentKey)).width, 200.0, reason: '内容不再溢出时必须同帧归还 15px gutter');
      expect(controller.position.maxScrollExtent, 0.0);

      resize(() => contentHeight = 400.0);
      await tester.pump();
      expect(tester.getSize(find.byKey(contentKey)).width, 185.0, reason: '内容重新溢出时必须同帧恢复 gutter');
      expect(controller.position.maxScrollExtent, 100.0);
    });

    testWidgets('Windows inset 稳态 resize 复用收敛结果，视口只布局一次', (tester) async {
      late StateSetter resize;
      var hostWidth = 200.0;
      const contentKey = ValueKey<String>('stable-inset-resize-content');
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            resize = setState;
            return _host(
              const ElScrollView(
                scrollbar: ElWindowScrollBar(),
                children: [SizedBox(key: contentKey, width: double.infinity, height: 400)],
              ),
              width: hostWidth,
              maxHeight: 300,
            );
          },
        ),
      );
      await tester.pump();

      final dynamic viewport = tester.renderObject(find.byKey(contentKey)).parent;
      final layoutsBefore = viewport.debugLayoutCount as int;
      resize(() => hostWidth = 210.0);
      await tester.pump();

      expect(viewport.debugLayoutCount - layoutsBefore, 1, reason: 'overflow 状态未变时不得再走“无 gutter → 有 gutter”双布局');
      expect(tester.getSize(find.byKey(contentKey)).width, 195.0);
    });

    testWidgets('Windows 双轴 inset 在首帧同步收敛交叉诱发的第二根滚动条', (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);
      await tester.pumpWidget(
        _host(
          ElScrollView(
            axis: null,
            controller: vertical,
            horizontalController: horizontal,
            scrollbar: const ElWindowScrollBar(),
            children: const <Widget>[SizedBox(width: 190, height: 400)],
          ),
          maxHeight: 300,
        ),
      );

      expect(vertical.position.viewportDimension, 285.0, reason: '横向条首帧占去底部 15px');
      expect(horizontal.position.viewportDimension, 185.0, reason: '纵向条首帧占去右侧 15px');
      expect(vertical.position.maxScrollExtent, 115.0);
      expect(horizontal.position.maxScrollExtent, 5.0, reason: '纵向条挤窄视口后应同帧诱发横向条');
      expect(find.byKey(const ValueKey<String>('el-scrollbar-win-strip-vertical')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('el-scrollbar-win-strip-horizontal')), findsOneWidget);
    });
  });

  group('虚拟网格拖柄', () {
    testWidgets(
      '97 张五列网格：thumb 按住底部期间整行挂载且可见区无缺项',
      (tester) async {
        tester.view.physicalSize = const Size(500, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ElScrollView(
              controller: controller,
              scrollbar: const ElWindowScrollBar(),
              children: [
                ElGridView.builder(
                  crossAxisCount: 5,
                  rowGap: 2,
                  columnGap: 2,
                  itemCount: 97,
                  itemBuilder: (_, index) => ElView(key: ValueKey('cell-$index'), child: '$index'),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        final render = tester.renderObject<RenderVirtualScrollView>(
          find.byElementPredicate(
            (element) => element is RenderObjectElement && element.renderObject is RenderVirtualScrollView,
          ),
        );
        final thumb = elThumbRect(tester, render)!;
        final start = render.localToGlobal(thumb.center);
        final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: start);
        await tester.pump();
        await gesture.down(start);
        final travel = math.max(1.0, render.size.height - thumb.height - 8.0);
        final bottom = render.localToGlobal(
          Offset(thumb.center.dx, (thumb.height / 2 + 4 + travel).clamp(0.0, render.size.height - 1)),
        );
        await gesture.moveTo(bottom);
        await tester.pump(const Duration(milliseconds: 16));

        final mounted = <int>[
          for (var index = 0; index < 97; index++)
            if (find.byKey(ValueKey('cell-$index'), skipOffstage: false).evaluate().isNotEmpty) index,
        ];
        expect(mounted, isNotEmpty);
        expect(mounted.first % 5, 0, reason: '拖拽补窗起点必须落在网格行首');
        expect(mounted.last, 96, reason: '底部拖拽必须挂载真实末项');
        expect(mounted.length, lessThanOrEqualTo(40), reason: '修复只能补足视口行与保守余量，不得退化成全量挂载');
        for (var index = render.debugVisibleStart; index < render.debugVisibleEnd; index++) {
          expect(mounted, contains(index), reason: 'thumb 按住期间可见项 $index 不得因少算列数而缺失');
        }

        await gesture.up();
      },
    );

    testWidgets('485 张五列网格：连续快速拖 thumb 时每帧都挂载完整可见行', (tester) async {
      const columns = 5;
      const gap = 2.0;
      const cellExtent = (1000 - (columns - 1) * gap) / columns;
      const stride = cellExtent + gap;
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ElScrollView(
            controller: controller,
            cacheExtent: 700,
            scrollbar: const ElWindowScrollBar(),
            children: [
              ElGridView.builder(
                crossAxisCount: columns,
                mainAxisExtent: cellExtent,
                rowGap: gap,
                columnGap: gap,
                itemCount: 485,
                itemBuilder: (_, index) => ElView(key: ValueKey('scrub-cell-$index'), child: '$index'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final render = tester.renderObject<RenderVirtualScrollView>(
        find.byElementPredicate(
          (element) => element is RenderObjectElement && element.renderObject is RenderVirtualScrollView,
        ),
      );
      final thumb = elThumbRect(tester, render)!;
      final thumbCenter = render.localToGlobal(thumb.center);
      final viewportTop = render.localToGlobal(Offset.zero).dy;
      final thumbTravel = math.max(0.0, render.size.height - thumb.height);
      final gesture = await tester.startGesture(thumbCenter, kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 8));

      for (final fraction in const <double>[0.9, 0.76, 0.74, 0.5, 0.72, 0.74, 0.1]) {
        await gesture.moveTo(Offset(thumbCenter.dx, viewportTop + thumb.height / 2 + thumbTravel * fraction));
        await tester.pump(const Duration(milliseconds: 8));
        final firstRow = (controller.offset / stride).floor();
        final lastRow = ((controller.offset + controller.position.viewportDimension - 0.01) / stride).floor();
        for (var row = firstRow; row <= lastRow; row++) {
          for (var column = 0; column < columns; column++) {
            final index = row * columns + column;
            if (index >= 485) break;
            expect(
              find.byKey(ValueKey('scrub-cell-$index'), skipOffstage: false),
              findsOneWidget,
              reason: 'thumb=$fraction 时可见项 $index 不得因窗口相位差缺失',
            );
          }
        }
      }

      await gesture.up();
    });
  });

  group('网格滚动条跳转', () {
    testWidgets('SliverGrid 跨区 jumpTo 同帧挂载目标可见行', (tester) async {
      const columns = 5;
      const extent = 100.0;
      const gap = 2.0;
      const itemCount = 485;
      final controller = ScrollController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ElScrollView(
            controller: controller,
            cacheExtent: 600,
            children: [
              ElGridView.builder(
                crossAxisCount: columns,
                mainAxisExtent: extent,
                rowGap: gap,
                columnGap: gap,
                itemCount: itemCount,
                itemBuilder: (_, index) => ElView(key: ValueKey('grid-jump-$index'), child: '$index'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      for (final fraction in const <double>[0.94, 0.08, 0.82, 0.18, 1, 0.0, 0.68, 0.32]) {
        controller.jumpTo(controller.position.maxScrollExtent * fraction);
        await tester.pump();
        final firstRow = (controller.offset / (extent + gap)).floor();
        final lastRow = ((controller.offset + controller.position.viewportDimension - 0.01) / (extent + gap)).floor();
        final missing = <int>[];
        for (var row = firstRow; row <= lastRow; row++) {
          for (var column = 0; column < columns; column++) {
            final index = row * columns + column;
            if (index >= itemCount) break;
            if (find.byKey(ValueKey('grid-jump-$index')).evaluate().isEmpty) missing.add(index);
          }
        }
        expect(missing, isEmpty, reason: 'fraction=$fraction offset=${controller.offset}');
      }
    });
  });

  group('官方 Scrollable 的滚动条', () {
    Widget host({required Widget body, ElScrollbar? scrollbar}) {
      return MaterialApp(
        scrollBehavior: const _ProbeFlutterScrollBehavior(),
        home: ElViewProvider(
          scrollbarBuilder: (_) => scrollbar,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 300, height: 200, child: body),
          ),
        ),
      );
    }

    testWidgets('ElViewProvider does not alter official Scrollable behavior', (tester) async {
      await tester.pumpWidget(
        host(
          scrollbar: const ElNoScrollBar(),
          body: ListView.builder(
            itemCount: 40,
            itemBuilder: (context, index) => SizedBox(height: 30, child: Text('row $index')),
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('flutter-scrollbar-wrapper')), findsOneWidget);
    });

    testWidgets(
      'official ScrollBehavior does not select El scrollbar chrome',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final controller = ScrollController();

        try {
          await tester.pumpWidget(
            host(
              scrollbar: const ElNoScrollBar(),
              body: ElScrollView(
                controller: controller,
                physics: const ClampingScrollPhysics(),
                children: List<Widget>.generate(40, (index) => SizedBox(height: 30, child: Text('row $index'))),
              ),
            ),
          );

          expect(find.byKey(const ValueKey<String>('flutter-scrollbar-wrapper')), findsNothing);
          expect(find.byKey(const ValueKey<String>('el-scrollbar-win-strip-vertical')), findsNothing);

          await tester.sendEventToBinding(
            const PointerScrollEvent(position: Offset(150, 100), scrollDelta: Offset(0, 80)),
          );
          await tester.pumpAndSettle();
          expect(controller.offset, greaterThan(0.0));
        } finally {
          debugDefaultTargetPlatformOverride = null;
          controller.dispose();
        }
      },
    );
  });

  group('平台条带与刷新默认值', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('无全局覆写时滚动条与刷新器按平台使用 el_ui 内建实现', (tester) async {
      final cases = <TargetPlatform, (Type, Type)>{
        TargetPlatform.android: (ElAndroidScrollBar, ElAndroidRefresher),
        TargetPlatform.fuchsia: (ElAndroidScrollBar, ElAndroidRefresher),
        TargetPlatform.iOS: (ElIosScrollBar, ElIosRefresher),
        TargetPlatform.macOS: (ElMacScrollBar, ElIosRefresher),
        TargetPlatform.linux: (ElMacScrollBar, ElIosRefresher),
        TargetPlatform.windows: (ElWindowScrollBar, ElIosRefresher),
      };

      try {
        for (final entry in cases.entries) {
          debugDefaultTargetPlatformOverride = entry.key;
          await tester.pumpWidget(
            MaterialApp(
              home: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 160,
                  height: 120,
                  child: ElScrollView(
                    onRefresh: () async {},
                    children: List.generate(
                      8,
                      (index) => ElView(style: const ElStyle(width: 160, height: 40), child: 'row $index'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final dynamic viewport = tester.widget(
            find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_ScrollViewport'),
          );
          final scrollbar = viewport.scrollbar as ElScrollbar;
          final refresher = tester.widget<RefreshHost>(find.byType(RefreshHost)).refresher;
          expect(scrollbar.runtimeType, entry.value.$1, reason: '${entry.key} 滚动条');
          expect(refresher.runtimeType, entry.value.$2, reason: '${entry.key} 刷新器');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('无全局覆写时文本选中 controls 按平台使用 el_ui 内建实现', (tester) async {
      final cases = <TargetPlatform, Type>{
        TargetPlatform.android: AndroidSelectionControls,
        TargetPlatform.fuchsia: AndroidSelectionControls,
        TargetPlatform.iOS: IosSelectionControls,
        TargetPlatform.macOS: DesktopSelectionControls,
        TargetPlatform.linux: DesktopSelectionControls,
        TargetPlatform.windows: DesktopSelectionControls,
      };

      try {
        for (final entry in cases.entries) {
          debugDefaultTargetPlatformOverride = entry.key;
          await tester.pumpWidget(
            MaterialApp(
              home: ElSelectionView(
                key: ValueKey<TargetPlatform>(entry.key),
                child: const ElView(child: 'alpha'),
              ),
            ),
          );
          await tester.pump();

          final render = tester.allRenderObjects.whereType<RenderSelectionView>().first;
          expect(render.selectionControls.runtimeType, entry.value, reason: '${entry.key} 文本选中 controls');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('滚动条层序', () {
    testWidgets('无作用域时条带留在视口内，z=10 只在视口 stacking context 内生效', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(300, 300);
      addTearDown(tester.view.reset);
      final main = ScrollController();
      addTearDown(main.dispose);
      final imageKey = GlobalKey();
      final red = Color(0xffff0000);
      final white = Color(0xffffffff);
      await tester.pumpWidget(
        RepaintBoundary(
          key: imageKey,
          child: Directionality(
            textDirection: .ltr,
            child: MediaQuery(
              data: MediaQueryData(size: Size(300, 300)),
              child: ElStackView(
                fit: .expand,
                children: [
                  ElPositioned.fill(
                    child: ElScrollView(
                      controller: main,
                      scrollbar: _VisibleBar(red),
                      children: [ElView(style: ElStyle(height: 1200))],
                    ),
                  ),
                  ElPositioned.fill(
                    zIndex: 9,
                    child: ElView(style: ElStyle(bgColor: white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final thumbElement = tester.element(_thumb(red));
      expect(thumbElement.findAncestorWidgetOfExactType<ElScrollView>(), isNotNull, reason: '条带仍挂在来源视口内');
      var stripRender = thumbElement.findRenderObject()!;
      while (stripRender.parentData is! ScrollChildParentData) {
        stripRender = stripRender.parent!;
      }
      expect((stripRender.parentData! as ScrollChildParentData).zIndex, 10, reason: '条带层序仍是视口内 z=10');
      expect(
        await _pixel(tester, imageKey, tester.getCenter(_thumb(red))),
        white,
        reason: '外层 Stack 的 z=9 兄弟仍盖住内部 z=10 的条带：页面层序边界胜过视口内层序',
      );
    });
  });

  group('短视口滚动条', () {
    testWidgets('Windows 双轴滚动条在 16.1 短视口内不让按钮挤爆条带', (tester) async {
      await tester.pumpWidget(_scrollbarShortViewportHost(extent: 16.1, child: _scrollView()));

      _expectSize(tester, find.byKey(_stripKey(Axis.vertical)), const Size(15.0, 1.1));
      _expectSize(tester, find.byKey(_stripKey(Axis.horizontal)), const Size(1.1, 15.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.vertical, forward: false)), const Size(15.0, 0.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.vertical, forward: true)), const Size(15.0, 0.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: false)), const Size(0.0, 15.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: true)), const Size(0.0, 15.0));
      _expectSize(tester, find.byKey(_trackKey(Axis.vertical)), const Size(15.0, 1.1));
      _expectSize(tester, find.byKey(_trackKey(Axis.horizontal)), const Size(1.1, 15.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows 双轴滚动条短视口热 resize 后恢复按钮和轨道几何', (tester) async {
      late StateSetter resize;
      var extent = 80.0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            resize = setState;
            return _scrollbarShortViewportHost(extent: extent, child: _scrollView());
          },
        ),
      );

      _expectSize(tester, find.byKey(_stripKey(Axis.vertical)), const Size(15.0, 65.0));
      _expectSize(tester, find.byKey(_stripKey(Axis.horizontal)), const Size(65.0, 15.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.vertical, forward: false)), const Size(15.0, 18.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.vertical, forward: true)), const Size(15.0, 18.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: false)), const Size(18.0, 15.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: true)), const Size(18.0, 15.0));
      _expectSize(tester, find.byKey(_trackKey(Axis.vertical)), const Size(15.0, 29.0));
      _expectSize(tester, find.byKey(_trackKey(Axis.horizontal)), const Size(29.0, 15.0));
      expect(tester.takeException(), isNull);

      resize(() => extent = 16.1);
      await tester.pump();
      _expectSize(tester, find.byKey(_buttonKey(Axis.vertical, forward: false)), const Size(15.0, 0.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.vertical, forward: true)), const Size(15.0, 0.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: false)), const Size(0.0, 15.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: true)), const Size(0.0, 15.0));
      _expectSize(tester, find.byKey(_trackKey(Axis.vertical)), const Size(15.0, 1.1));
      _expectSize(tester, find.byKey(_trackKey(Axis.horizontal)), const Size(1.1, 15.0));
      expect(tester.takeException(), isNull);

      resize(() => extent = 80.0);
      await tester.pump();
      _expectSize(tester, find.byKey(_buttonKey(Axis.vertical, forward: false)), const Size(15.0, 18.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.vertical, forward: true)), const Size(15.0, 18.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: false)), const Size(18.0, 15.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: true)), const Size(18.0, 15.0));
      _expectSize(tester, find.byKey(_trackKey(Axis.vertical)), const Size(15.0, 29.0));
      _expectSize(tester, find.byKey(_trackKey(Axis.horizontal)), const Size(29.0, 15.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows 双轴 chrome 中不可滚轴 gate 仍布局且不触发短视口 overflow', (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);

      await tester.pumpWidget(
        _scrollbarShortViewportHost(
          extent: 16.1,
          child: _scrollView(
            controller: vertical,
            horizontalController: horizontal,
            contentWidth: 1.0,
            contentHeight: 400.0,
          ),
        ),
      );

      expect(vertical.position.maxScrollExtent, greaterThan(0.0));
      expect(horizontal.position.maxScrollExtent, 0.0);
      _expectSize(tester, find.byKey(_stripKey(Axis.vertical)), const Size(15.0, 1.1));
      _expectSize(tester, find.byKey(_stripKey(Axis.horizontal)), const Size(1.1, 15.0));
      _expectSize(tester, find.byKey(_trackKey(Axis.horizontal)), const Size(1.1, 15.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: false)), const Size(0.0, 15.0));
      _expectSize(tester, find.byKey(_buttonKey(Axis.horizontal, forward: true)), const Size(0.0, 15.0));
      expect(tester.takeException(), isNull);
    });
  });
}
