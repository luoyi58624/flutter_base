import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/virtual_test_host.dart';

ElListView _listItems(List<Widget> children, {bool fixedSize = false}) {
  final indices = <Key, int>{for (var index = 0; index < children.length; index++) ?children[index].key: index};
  return ElListView.builder(
    itemCount: children.length,
    itemBuilder: (context, index) => children[index],
    fixedSize: fixedSize,
    crossAxisAlignment: .center,
    findChildIndexCallback: (key) => indices[key],
  );
}

class _AlwaysVisibleScrollbar extends ElScrollbar {
  const _AlwaysVisibleScrollbar();

  @override
  bool resolveAlwaysVisible(BuildContext context, ElScrollbarAxisDetails axis) => true;

  @override
  double resolveThumbThickness(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool hovered,
    required bool dragging,
  }) => 8.0;

  @override
  Widget buildThumb(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  }) => ElView(style: const ElStyle(bgColor: Color(0xff409eff)));
}

const _narrowWindow = Size(580, 300);

const _wideWindow = Size(620, 300);

const _wrappingText = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

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

List<Widget> _items(int count, {double h = 20}) {
  return List<Widget>.generate(count, (i) => SizedBox(key: ValueKey('item-$i'), width: 100, height: h));
}

/// 故意把默认滚动视图放进无界高度，用来验证错误能指回业务 Widget。
class _BusinessUnboundedScrollCase extends StatelessWidget {
  const _BusinessUnboundedScrollCase();

  @override
  Widget build(BuildContext context) {
    return const ElScrollView(
      axis: Axis.horizontal,
      scrollbar: ElNoScrollBar(),
      children: [SizedBox(width: 2000, height: 160)],
    );
  }
}

String _renderErrors(Iterable<FlutterErrorDetails> errors) {
  return errors.map((error) => error.toDiagnosticsNode().toStringDeep()).join('\n');
}

ElListView _shrinkWrapListItems(List<Widget> children, {bool fixedSize = false}) {
  final indices = <Key, int>{for (var index = 0; index < children.length; index++) ?children[index].key: index};
  return ElListView.builder(
    itemCount: children.length,
    itemBuilder: (context, index) => children[index],
    fixedSize: fixedSize,
    findChildIndexCallback: (key) => indices[key],
  );
}

class _NoChromeScrollBehavior extends ScrollBehavior {
  const _NoChromeScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

class _PaddingGapNoChromeScrollBehavior extends ScrollBehavior {
  const _PaddingGapNoChromeScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => ClampingScrollPhysics();
}

class _ParentLayoutProbe extends SingleChildRenderObjectWidget {
  const _ParentLayoutProbe({required this.onLayout, required super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderParentLayoutProbe(onLayout);
}

class _RenderParentLayoutProbe extends RenderProxyBox {
  _RenderParentLayoutProbe(this.onLayout);

  final VoidCallback onLayout;

  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}

Widget _layoutBoundaryHost(Widget child, VoidCallback onParentLayout) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200, maxHeight: 300),
      child: _ParentLayoutProbe(onLayout: onParentLayout, child: child),
    ),
  ),
);

RenderVirtualScrollView _viewport(GlobalKey<ElScrollViewState> key) =>
    key.currentState!.debugScrollMixinViewportRenderObject!;

void main() {
  group('交叉轴对齐', () {
    Widget shell({required Widget child, Axis axis = Axis.vertical, CrossAxisAlignment? crossAxisAlignment}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: ElScrollView(
              axis: axis,
              padding: axis == Axis.vertical
                  ? const EdgeInsets.only(left: 10, right: 20)
                  : const EdgeInsets.only(top: 10, bottom: 20),
              crossAxisAlignment: crossAxisAlignment,
              children: [child],
            ),
          ),
        ),
      );
    }

    const boxKey = ValueKey('box');

    testWidgets('vertical 缺省：拉满交叉轴（既有行为，固有宽被覆盖）', (tester) async {
      await tester.pumpWidget(shell(child: const SizedBox(key: boxKey, width: 100, height: 40)));
      // 可用宽 = 300 − 10 − 20 = 270；tight 约束覆盖固有宽。
      expect(tester.getSize(find.byKey(boxKey)).width, 270);
      expect(tester.getTopLeft(find.byKey(boxKey)).dx, 10);
    });

    testWidgets('start / center / end：固有宽摆位', (tester) async {
      const child = SizedBox(key: boxKey, width: 100, height: 40);
      // 自由空间 = 270 − 100 = 170。
      await tester.pumpWidget(shell(child: child, crossAxisAlignment: .start));
      expect(tester.getSize(find.byKey(boxKey)).width, 100);
      expect(tester.getTopLeft(find.byKey(boxKey)).dx, 10);

      await tester.pumpWidget(shell(child: child, crossAxisAlignment: .center));
      expect(tester.getTopLeft(find.byKey(boxKey)).dx, 10 + 170 / 2);

      await tester.pumpWidget(shell(child: child, crossAxisAlignment: .end));
      expect(tester.getTopLeft(find.byKey(boxKey)).dx, 10 + 170);
    });

    testWidgets('horizontal 主轴：缺省按固有高（既有行为）、显式 stretch 拉满、center 居中', (tester) async {
      const child = SizedBox(key: boxKey, width: 40, height: 100);
      await tester.pumpWidget(shell(child: child, axis: Axis.horizontal));
      // 缺省 = 既有 loose 行为：固有高 100、贴 padding.top——存量横滑零破坏。
      expect(tester.getSize(find.byKey(boxKey)).height, 100);
      expect(tester.getTopLeft(find.byKey(boxKey)).dy, 10);

      // 可用高 = 300 − 10 − 20 = 270。
      await tester.pumpWidget(shell(child: child, axis: Axis.horizontal, crossAxisAlignment: .stretch));
      expect(tester.getSize(find.byKey(boxKey)).height, 270);
      expect(tester.getTopLeft(find.byKey(boxKey)).dy, 10);

      await tester.pumpWidget(shell(child: child, axis: Axis.horizontal, crossAxisAlignment: .center));
      expect(tester.getSize(find.byKey(boxKey)).height, 100);
      expect(tester.getTopLeft(find.byKey(boxKey)).dy, 10 + (270 - 100) / 2);
    });

    testWidgets('裸 ElListView item 同样按 center 使用固有宽居中', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 300,
              child: ElScrollView(
                crossAxisAlignment: .center,
                children: [
                  _listItems(List.generate(30, (i) => SizedBox(key: ValueKey('item-$i'), width: 100, height: 40))),
                ],
              ),
            ),
          ),
        ),
      );
      // 无 padding：自由空间 = 300 − 100 = 200，居中 x = 100。
      expect(tester.getTopLeft(find.byKey(const ValueKey('item-0'))).dx, 100);
      expect(tester.getSize(find.byKey(const ValueKey('item-0'))).width, 100);
    });

    testWidgets('双轴不支持非默认对齐：构造期 assert 拒绝', (tester) async {
      expect(() => ElScrollView(axis: null, crossAxisAlignment: .center, children: const []), throwsAssertionError);
    });
  });

  group('尺寸变化回钳', () {
    Future<void> expectResizeReclamps(WidgetTester tester, String tag, ScrollPhysics? scrollPhysics) async {
      tester.view.physicalSize = const Size(400, 300);

      final controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElScrollView(
              controller: controller,
              physics: scrollPhysics,
              children: [for (var i = 0; i < 40; i++) SizedBox(key: ValueKey('r$i'), height: 30, width: 300)],
            ),
          ),
        ),
      );
      await tester.pump();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.position.pixels, 900.0, reason: '[$tag] 前置：小窗滚到底');

      // 模拟窗口从小窗拉到全屏：视口 300 → 900，新 max = 1200 - 900 = 300。
      tester.view.physicalSize = const Size(400, 900);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.position.pixels, controller.position.maxScrollExtent, reason: '[$tag] resize 后必须回弹收敛到新 max');
      final lastRowBottom = tester.getRect(find.byKey(const ValueKey('r39'))).bottom;
      expect(lastRowBottom, 900.0, reason: '[$tag] 内容底必须贴住视口底，不得露空白');

      controller.dispose();
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('viewport grow reclamps scroll position across physics options', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await expectResizeReclamps(tester, 'auto', null);
      await expectResizeReclamps(tester, 'browser', ElBrowserScrollPhysics());
      await expectResizeReclamps(tester, 'bouncing', ElBouncingScrollPhysics());
      await expectResizeReclamps(tester, 'clamping', const ClampingScrollPhysics());

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('content shrink at bottom reclamps in the resize layout frame without animation', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      late StateSetter resize;
      var contentHeight = 1200.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                resize = setState;
                return ElScrollView(
                  controller: controller,
                  children: [SizedBox(key: const ValueKey('instant-content'), height: contentHeight, width: 300)],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.position.pixels, 900.0, reason: '前置：300 高视口已滚到底');

      resize(() => contentHeight = 600.0);
      await tester.pump();

      expect(controller.position.maxScrollExtent, 300.0, reason: '内容缩短后新 max 已在本帧完成布局');
      expect(
        controller.position.pixels,
        controller.position.maxScrollExtent,
        reason: '内容尺寸变化属于几何修正，必须在 layout 帧直接钳到新 max，不得启动回弹动画',
      );
      expect(controller.position.outOfRange, isFalse, reason: '尺寸变化帧结束时不应残留临时越界状态');
      expect(
        tester.getRect(find.byKey(const ValueKey('instant-content'))).bottom,
        300.0,
        reason: '尺寸变化首帧内容底必须贴住视口底，不得先露空白再动画回填',
      );
    });

    testWidgets('viewport grow at bottom remounts the corrected visible window in the same frame', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late StateSetter resize;
      var viewportHeight = 300.0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) {
                resize = setState;
                return SizedBox(
                  width: 400,
                  height: viewportHeight,
                  child: ElScrollView(
                    controller: controller,
                    cacheExtent: 0,
                    children: [
                      ElListView.builder(
                        itemBuilder: (context, index) =>
                            SizedBox(key: ValueKey('resize-v$index'), width: 300, height: 48),
                        itemCount: 500,
                        fixedSize: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(controller.position.maxScrollExtent, 23700.0, reason: '前置：固定行高虚拟段已建立精确 extent');
      for (var i = 0; i < 4; i++) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        await tester.pump();
      }
      expect(controller.position.pixels, 23700.0, reason: '前置：300 高视口滚到底');
      expect(find.byKey(const ValueKey('resize-v487')), findsNothing, reason: '前置：小视口只挂载末屏');

      resize(() => viewportHeight = 600.0);
      await tester.pump();

      expect(controller.position.pixels, 23400.0, reason: '放大后同帧回钳到新 max');
      expect(find.byKey(const ValueKey('resize-v487')), findsOneWidget, reason: '回钳后的新首屏必须同帧完成挂载，不能空一帧后再补');
      expect(tester.getRect(find.byKey(const ValueKey('resize-v487'))).top, -24.0, reason: '新首行同帧落到修正后的可视位置');
    });

    testWidgets('content shrink updates scrollbar thumb geometry in the same frame', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late StateSetter resize;
      var contentHeight = 1200.0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              resize = setState;
              return ElScrollView(
                scrollbar: const _AlwaysVisibleScrollbar(),
                children: [ElView(style: ElStyle(width: 300, height: contentHeight))],
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final thumb = find.byKey(const ValueKey<String>('el-scrollbar-thumb-vertical'));
      expect(tester.getRect(thumb).height, 75.0, reason: '前置：300 / 1200 的 thumb 比例为 1/4');

      resize(() => contentHeight = 600.0);
      await tester.pump();

      expect(tester.getRect(thumb).height, 150.0, reason: 'extent 在 layout 内收敛后，thumb 必须同帧读取新 metrics');
    });

    testWidgets('ElClampingScrollPhysics out-of-range v=0 yields a converging recovery simulation', (tester) async {
      const physics = ElClampingScrollPhysics();
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 300.0,
        pixels: 900.0,
        viewportDimension: 900.0,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      final simulation = physics.createBallisticSimulation(metrics, 0.0);
      expect(simulation, isNotNull, reason: '越界必须产生回弹模拟');
      expect(simulation!.x(5.0), moreOrLessEquals(300.0, epsilon: 1.0), reason: '模拟必须收敛到 max 而非钉在越界位');
    });
  });

  group('反向初始布局', () {
    testWidgets('reverse 变高虚拟列表冷启动首帧直接显示尾项', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ElScrollView(
            reverse: true,
            cacheExtent: 800,
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            children: [
              ElListView.builder(
                itemCount: 675,
                itemBuilder: (_, index) => SizedBox(key: ValueKey('row-$index'), height: 96.0 + (index % 3) * 28),
              ),
            ],
          ),
        ),
      );

      const tailKey = ValueKey('row-674');
      final firstFrameRect = tester.getRect(find.byKey(tailKey));
      expect(firstFrameRect.bottom, closeTo(760 - 32, 0.01));
      expect(firstFrameRect.top, lessThan(760));

      await tester.pump();

      final secondFrameRect = tester.getRect(find.byKey(tailKey));
      expect(secondFrameRect.top, closeTo(firstFrameRect.top, 0.01));
      expect(secondFrameRect.bottom, closeTo(firstFrameRect.bottom, 0.01));
    });
  });

  group('同断点尺寸变化', () {
    testWidgets('同一断点内变宽时首项换行收缩，resize 首帧仍贴住视口顶部', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _narrowWindow;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      const firstKey = ValueKey('resize-first-item');
      await tester.pumpWidget(
        const MaterialApp(
          home: ElScrollView(
            scrollbar: ElNoScrollBar(),
            children: [
              ElView(
                key: firstKey,
                style: ElStyle(width: '100%', fontSize: 20, lineHeight: 1),
                child: _wrappingText,
              ),
              ElView(style: ElStyle(width: '100%', height: 400)),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final narrowRect = tester.getRect(find.byKey(firstKey));
      expect(narrowRect.top, 0);

      tester.view.physicalSize = _wideWindow;
      await tester.pump();

      final firstResizeFrameRect = tester.getRect(find.byKey(firstKey));
      expect(firstResizeFrameRect.height, lessThan(narrowRect.height), reason: '前置：宽度变化必须让首项由两行收缩为一行');
      expect(firstResizeFrameRect.top, 0, reason: '未跨断点的自然换行变化不应让首项在 resize 首帧向下闪动');

      tester.view.physicalSize = _narrowWindow;
      await tester.pump();

      final reverseResizeFrameRect = tester.getRect(find.byKey(firstKey));
      expect(reverseResizeFrameRect.height, greaterThan(firstResizeFrameRect.height));
      expect(reverseResizeFrameRect.top, 0, reason: '反向 resize 让首项重新换行时也必须在首帧保持贴顶');
    });

    testWidgets('同一断点内整页内容换行变高，固定在底部时 resize 首帧仍钉住底边', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _wideWindow;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      const contentKey = ValueKey('resize-page-content');

      await tester.pumpWidget(
        MaterialApp(
          home: ElScrollView(
            controller: controller,
            scrollbar: const ElNoScrollBar(),
            children: [
              ElView(
                key: contentKey,
                style: const ElStyle(width: '100%'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 20; i++)
                      const ElView(
                        style: ElStyle(width: '100%', fontSize: 20, lineHeight: 1),
                        child: _wrappingText,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
      }

      final wideRect = tester.getRect(find.byKey(contentKey));
      expect(controller.position.pixels, controller.position.maxScrollExtent);
      expect(wideRect.bottom, _wideWindow.height, reason: '前置：调整尺寸前内容已固定在底部');

      tester.view.physicalSize = _narrowWindow;
      await tester.pump();

      final firstResizeFrameRect = tester.getRect(find.byKey(contentKey));
      expect(firstResizeFrameRect.height, greaterThan(wideRect.height), reason: '前置：宽度变化必须让整页文本产生更多换行');
      expect(
        controller.position.pixels,
        controller.position.maxScrollExtent,
        reason: '未跨断点的内容换行变化应在 resize 首帧同步修正滚动位置，不得随后动画追赶',
      );
      expect(firstResizeFrameRect.bottom, _narrowWindow.height, reason: '固定在底部时 resize 首帧内容底必须贴住视口底');

      tester.view.physicalSize = _wideWindow;
      await tester.pump();

      final reverseResizeFrameRect = tester.getRect(find.byKey(contentKey));
      expect(reverseResizeFrameRect.height, lessThan(firstResizeFrameRect.height));
      expect(controller.position.pixels, controller.position.maxScrollExtent, reason: '反向 resize 内容收缩时也必须同帧钉住新 max');
      expect(reverseResizeFrameRect.bottom, _wideWindow.height, reason: '反向 resize 首帧不得先露出底部空白再回填');
    });
  });

  group('收缩布局', () {
    for (final axis in <Axis?>[Axis.vertical, Axis.horizontal, null]) {
      testWidgets('shrinkWrap $axis 首次布局收到真实无界主轴', (tester) async {
        await tester.pumpWidget(
          _host(
            ElScrollView(
              axis: axis,
              shrinkWrap: true,
              scrollbar: const ElNoScrollBar(),
              children: const <Widget>[SizedBox(width: 100, height: 80)],
            ),
            width: axis == Axis.vertical ? 200 : double.infinity,
            maxHeight: axis == Axis.horizontal ? 300 : null,
          ),
        );
        final viewport = tester.allRenderObjects.whereType<RenderVirtualScrollView>().toSet().single;
        expect(viewport.constraints.maxWidth, axis == Axis.vertical ? 200 : double.infinity);
        expect(viewport.constraints.maxHeight, axis == Axis.horizontal ? 300 : double.infinity);
        expect(viewport.size, const Size(100, 80));
        expect(tester.takeException(), isNull);
      });

      for (final innerAxis in <Axis?>[Axis.vertical, Axis.horizontal, null]) {
        for (final reverse in axis == null && innerAxis == null ? <bool>[false] : <bool>[false, true]) {
          testWidgets('约束矩阵：外层 $axis / 内层 $innerAxis shrinkWrap，reverse=$reverse', (tester) async {
            final outer = ElScrollController();
            final inner = ElScrollController();
            addTearDown(outer.dispose);
            addTearDown(inner.dispose);
            await tester.pumpWidget(
              _host(
                ElScrollView(
                  controller: outer,
                  axis: axis,
                  reverse: axis != null && reverse,
                  crossAxisAlignment: axis == null ? null : .start,
                  scrollbar: const ElNoScrollBar(),
                  children: [
                    ElScrollView(
                      controller: inner,
                      axis: innerAxis,
                      reverse: innerAxis != null && reverse,
                      shrinkWrap: true,
                      scrollbar: const ElNoScrollBar(),
                      children: const <Widget>[SizedBox(width: 100, height: 80)],
                    ),
                    if (axis == Axis.horizontal)
                      const SizedBox(width: 1000, height: 20)
                    else
                      const SizedBox(width: 20, height: 1000),
                  ],
                ),
                maxHeight: 300,
              ),
            );
            final viewport = tester.allRenderObjects.whereType<RenderVirtualScrollView>().toSet().singleWhere(
              (v) => v.shrinkWrap,
            );
            expect(viewport.constraints.maxWidth, axis == Axis.vertical ? 200 : double.infinity);
            expect(viewport.constraints.maxHeight, axis == Axis.horizontal ? 300 : double.infinity);
            expect(viewport.size, const Size(100, 80));
            expect(inner.position.maxScrollExtent, 0);
            expect(outer.position.maxScrollExtent, axis == Axis.horizontal ? 900 : 780);
            expect(tester.takeException(), isNull);
          });
        }
      }

      for (final shrinkWrap in <bool>[false, true]) {
        testWidgets('dry layout 与实际布局一致：$axis shrinkWrap=$shrinkWrap 的紧约束', (tester) async {
          await tester.pumpWidget(
            _host(
              SizedBox(
                width: 200,
                height: 300,
                child: ElScrollView(
                  axis: axis,
                  shrinkWrap: shrinkWrap,
                  scrollbar: const ElNoScrollBar(),
                  children: const <Widget>[SizedBox(width: 100, height: 80)],
                ),
              ),
              maxHeight: 300,
            ),
          );
          final viewport = tester.allRenderObjects.whereType<RenderVirtualScrollView>().toSet().single;
          expect(viewport.constraints.isTight, isTrue);
          expect(viewport.getDryLayout(viewport.constraints), viewport.size);
          if (!shrinkWrap) {
            expect(viewport.getDryLayout(const BoxConstraints(maxWidth: 200, maxHeight: 300)), viewport.size);
          }
        });
      }
    }

    for (final lazy in <bool>[false, true]) {
      testWidgets('loose shrinkWrap dry 明确拒绝且无副作用：lazy=$lazy', (tester) async {
        var builds = 0;
        Widget row(BuildContext context, int index) {
          builds++;
          return const SizedBox(width: 100, height: 20);
        }

        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _host(
            ElScrollView(
              controller: controller,
              shrinkWrap: true,
              scrollbar: const ElNoScrollBar(),
              children: lazy
                  ? <Widget>[ElListView.builder(itemCount: 5, itemBuilder: row, crossAxisAlignment: .start)]
                  : <Widget>[for (var i = 0; i < 5; i++) Builder(builder: (context) => row(context, i))],
            ),
            maxHeight: 300,
          ),
          phase: EnginePhase.build,
        );
        final viewport = tester.allRenderObjects.whereType<RenderVirtualScrollView>().toSet().single;
        expect(viewport.hasSize, isFalse, reason: '必须覆盖首次真实布局前，不能依赖已有 size');
        final buildsBeforeDry = builds;
        final layoutsBeforeDry = viewport.debugLayoutCount;
        // SDK 的 getDryLayout 抛错时不会复位调试标志，直接验证 override，避免污染后续真实布局。
        expect(
          () => viewport.computeDryLayout(const BoxConstraints(maxWidth: 200, maxHeight: 300)),
          throwsA(isA<FlutterError>().having((error) => error.toString(), '原因', contains('shrinkWrap'))),
        );
        expect(builds, buildsBeforeDry);
        expect(viewport.debugLayoutCount, layoutsBeforeDry);
        expect(viewport.hasSize, isFalse);
        expect(controller.position.hasContentDimensions, isFalse);

        tester.binding.scheduleFrame();
        await tester.pump();
        expect(viewport.size, const Size(100, 100));
        final buildsAfterLayout = builds;
        final layoutsAfterLayout = viewport.debugLayoutCount;
        expect(
          () => viewport.computeDryLayout(const BoxConstraints(maxWidth: 150, maxHeight: 250)),
          throwsA(isA<FlutterError>().having((error) => error.toString(), '原因', contains('shrinkWrap'))),
        );
        expect(viewport.size, const Size(100, 100));
        expect(builds, buildsAfterLayout);
        expect(viewport.debugLayoutCount, layoutsAfterLayout);
        expect(controller.offset, 0);
        expect(controller.position.maxScrollExtent, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('默认非 shrinkWrap：有界恒撑满', (tester) async {
      await tester.pumpWidget(_host(ElScrollView(children: _items(3)), maxHeight: 300));
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size, const Size(200, 300));
    });

    testWidgets('横向默认非 shrinkWrap：有界恒撑满', (tester) async {
      await tester.pumpWidget(
        _host(
          const ElScrollView(
            axis: Axis.horizontal,
            scrollbar: ElNoScrollBar(),
            children: [SizedBox(width: 120, height: 80)],
          ),
          maxHeight: 300,
        ),
      );
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size, const Size(200, 300));
    });

    testWidgets('纵向 shrinkWrap 无界：宽高 = 内容尺寸', (tester) async {
      await tester.pumpWidget(_host(ElScrollView(shrinkWrap: true, children: _items(5))));
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size, const Size(100, 100), reason: '100px 宽、5 × 20px 高的内容，两轴都应收缩');
      expect(tester.takeException(), isNull);
    });

    testWidgets('纵向 shrinkWrap 有界且内容不足：宽高 = 内容尺寸，不拉满', (tester) async {
      await tester.pumpWidget(_host(ElScrollView(shrinkWrap: true, children: _items(5)), maxHeight: 300));
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size, const Size(100, 100), reason: '内容宽高都小于父级上界时不得拉满');
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrinkWrap 有界且内容超出：高度 = 上界，可滚动', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(ElScrollView(controller: controller, shrinkWrap: true, children: _items(20)), maxHeight: 300),
      );
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size.height, 300, reason: '内容 400px > 上界 300，按上界截断');
      expect(controller.position.maxScrollExtent, 100);
      expect(controller.offset, 0);
      await tester.drag(find.byType(ElScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0), reason: '必须验证真实位置变化，不能只检查没有异常');
      expect(tester.takeException(), isNull, reason: '截断后应可滚动无异常');
    });

    testWidgets('横向 shrinkWrap：宽高收内容后受父约束钳制', (tester) async {
      await tester.pumpWidget(
        _host(
          const ElScrollView(
            axis: Axis.horizontal,
            shrinkWrap: true,
            scrollbar: ElNoScrollBar(),
            children: [SizedBox(width: 400, height: 80)],
          ),
          maxHeight: 300,
        ),
      );
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size, const Size(200, 80), reason: '内容宽 400 受父级 200 上界钳制，高度按 80px 内容收缩');
      expect(tester.takeException(), isNull);
    });

    testWidgets('横向 shrinkWrap 内容不足：宽高都不拉满', (tester) async {
      await tester.pumpWidget(
        _host(
          const ElScrollView(
            axis: Axis.horizontal,
            shrinkWrap: true,
            scrollbar: ElNoScrollBar(),
            children: [SizedBox(width: 120, height: 80)],
          ),
          maxHeight: 300,
        ),
      );
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size, const Size(120, 80));
      expect(tester.takeException(), isNull);
    });

    testWidgets('纵向 shrinkWrap 内嵌横向 shrinkWrap：横向视口受父宽钳制并保留滚动条', (tester) async {
      final horizontal = ScrollController();
      addTearDown(horizontal.dispose);
      const wideContentKey = ValueKey<String>('nested-wide-content');

      await tester.pumpWidget(
        _host(
          ElScrollView(
            shrinkWrap: true,
            scrollbar: const ElNoScrollBar(),
            children: [
              const SizedBox(width: 100, height: 40),
              ElScrollView(
                axis: Axis.horizontal,
                shrinkWrap: true,
                controller: horizontal,
                scrollbar: const ElWindowScrollBar(),
                children: const <Widget>[SizedBox(key: wideContentKey, width: 2000, height: 160)],
              ),
              const SizedBox(width: 100, height: 40),
            ],
          ),
          width: 600,
          maxHeight: 500,
        ),
      );
      await tester.pumpAndSettle();

      expect(horizontal.position.viewportDimension, 600);
      expect(horizontal.position.maxScrollExtent, 1400);
      expect(find.byKey(const ValueKey<String>('el-scrollbar-win-strip-horizontal')), findsOneWidget);

      final before = tester.getTopLeft(find.byKey(wideContentKey)).dx;
      horizontal.jumpTo(300);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(wideContentKey)).dx, before - 300);
      expect(tester.takeException(), isNull);
    });

    testWidgets('纵向 shrinkWrap 内嵌横向默认滚动：无界高度必须报错', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await tester.pumpWidget(
          _host(
            const ElScrollView(
              shrinkWrap: true,
              scrollbar: ElNoScrollBar(),
              children: [
                SizedBox(width: 100, height: 40),
                ElScrollView(
                  axis: Axis.horizontal,
                  scrollbar: ElNoScrollBar(),
                  children: [SizedBox(width: 2000, height: 160)],
                ),
                SizedBox(width: 100, height: 40),
              ],
            ),
            width: 600,
            maxHeight: 500,
          ),
        );
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(
        errors.map((error) => error.exceptionAsString()).join('\n'),
        contains('ElScrollView(shrinkWrap: false) needs bounded width and height'),
      );
    });

    testWidgets('默认滚动无界错误打印公开 ElScrollView 的业务调用路径', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await tester.pumpWidget(
          _host(
            const ElScrollView(
              shrinkWrap: true,
              scrollbar: ElNoScrollBar(),
              children: [
                SizedBox(width: 100, height: 40),
                _BusinessUnboundedScrollCase(),
                SizedBox(width: 100, height: 40),
              ],
            ),
            width: 600,
            maxHeight: 500,
          ),
        );
      } finally {
        FlutterError.onError = oldOnError;
      }

      final diagnostics = _renderErrors(errors);
      expect(
        diagnostics,
        matches(
          RegExp(
            r'The relevant error-causing widget was:[\s\S]{0,300}'
            r'ElScrollView:file:///.*layout_test\.dart',
          ),
        ),
      );
      expect(diagnostics, contains('The public ElScrollView was'));
      expect(diagnostics, contains('The ownership chain for this ElScrollView is'));
      expect(diagnostics, contains('_BusinessUnboundedScrollCase'));
      expect(diagnostics, contains('layout_test.dart'));
      expect(diagnostics, contains('BoxConstraints'));
    });

    testWidgets('shrinkWrap 裸 ElListView 首帧全量挂载且高度精确', (tester) async {
      await tester.pumpWidget(_host(ElScrollView(shrinkWrap: true, children: [_shrinkWrapListItems(_items(20))])));
      for (var i = 0; i < 20; i++) {
        expect(find.byKey(ValueKey('item-$i')), findsOneWidget, reason: 'item $i 应全量挂载');
      }
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size.height, 400, reason: '20 × 20px 全量实测，高度精确');
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrinkWrap builder 交叉轴变窄时同帧使用全部新行高', (tester) async {
      late StateSetter resize;
      var width = 200.0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            resize = setState;
            return _host(
              ElScrollView(
                shrinkWrap: true,
                scrollbar: const ElNoScrollBar(),
                children: [
                  ElListView.builder(
                    itemCount: 5,
                    crossAxisAlignment: .start,
                    itemBuilder: (context, index) => LayoutBuilder(
                      builder: (context, constraints) => SizedBox(width: 100, height: constraints.maxWidth / 5),
                    ),
                  ),
                ],
              ),
              width: width,
              maxHeight: 300,
            );
          },
        ),
      );
      final viewport = tester.allRenderObjects.whereType<RenderVirtualScrollView>().toSet().single;
      expect(viewport.size, const Size(100, 200));
      resize(() => width = 100);
      await tester.pump();
      expect(viewport.size, const Size(100, 100), reason: '全量行已按新宽度重测，不得再保留一帧旧内容高度');
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrinkWrap 双轴（axis: null）：宽高都收内容', (tester) async {
      await tester.pumpWidget(_host(ElScrollView(axis: null, shrinkWrap: true, children: _items(5))));
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size, const Size(100, 100), reason: '双轴下宽高都按完整内容收缩');
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrinkWrap 双轴使用 Windows inset 横向滚动条仍按内容收缩', (tester) async {
      const selectionKey = ValueKey<String>('selection-host');
      await tester.pumpWidget(
        _host(
          ElSelectionView(
            key: selectionKey,
            child: const ElScrollView(
              axis: null,
              shrinkWrap: true,
              scrollbar: ElWindowScrollBar(),
              children: [SizedBox(width: 400, height: 100)],
            ),
          ),
          maxHeight: 300,
        ),
      );
      final firstFrameSize = tester.getSize(find.byKey(selectionKey));
      expect(firstFrameSize, const Size(200, 115), reason: '首帧内容先钳制为 200×100，再同步加 15px Windows 横向条');
      await tester.pump();
      expect(tester.getSize(find.byKey(selectionKey)), firstFrameSize, reason: '帧尾 metrics 回刷不得让 shrinkWrap 再长高');
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrinkWrap 双轴贴底后交叉轴 resize 不产生空白', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      late StateSetter resize;
      var width = 480.0;
      const contentKey = ValueKey('resize-content');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) {
                resize = setState;
                return SizedBox(
                  width: width,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ElScrollView(
                      controller: controller,
                      axis: null,
                      shrinkWrap: true,
                      children: const [SizedBox(key: contentKey, width: 800, height: 400)],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(controller.position.maxScrollExtent, 100.0, reason: '前置：400 高内容受 300 高上界截断');

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getRect(find.byKey(contentKey)).bottom, 300.0, reason: '前置：内容底贴视口底');

      for (final nextWidth in <double>[1200, 480, 1200]) {
        resize(() => width = nextWidth);
        await tester.pump();
        await tester.pump();

        expect(controller.position.maxScrollExtent, 100.0, reason: '交叉轴 resize 不应改变纵向滚动范围');
        expect(
          controller.position.pixels,
          controller.position.maxScrollExtent,
          reason: '宽度变为 $nextWidth 后 offset 必须保持在合法 max，不能被临时零视口推到内容高度',
        );
        expect(tester.getRect(find.byKey(contentKey)).bottom, 300.0, reason: '宽度变为 $nextWidth 后内容底不得离开视口');
      }
    });

    testWidgets('shrinkWrap 空内容：高度为 0 无异常', (tester) async {
      await tester.pumpWidget(_host(const ElScrollView(shrinkWrap: true, children: [])));
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size, Size.zero);
      expect(tester.takeException(), isNull);
    });
  });

  group('长文本溢出', () {
    Widget codeBlock({required double tallLineHeight, double maxHeight = 500}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ElView(
            style: const ElStyle(width: '100%'),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 0, maxHeight: maxHeight),
              child: ElScrollView(
                shrinkWrap: true,
                axis: null,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                children: <Widget>[
                  ElView(
                    style: const ElStyle(fontSize: 14, lineHeight: 1.7, softWrap: false),
                    child: Column(
                      key: const Key('code-lines'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (var i = 0; i < 6; i++) ElView(child: 'const line$i = $i;'),
                        ElView(
                          style: ElStyle(lineHeight: tallLineHeight),
                          child: 'const tall = 1;',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('行高参差（tall 行 25px vs 基准 24px）：不得 RenderFlex 溢出', (tester) async {
      await tester.pumpWidget(codeBlock(tallLineHeight: 1.8));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '行高参差时文本块不允许 RenderFlex 溢出');
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      final column = tester.renderObject<RenderBox>(find.byKey(const Key('code-lines')));
      // shrinkWrap：视口高 = 列高 + padding，精确贴合内容，无估算。
      expect(viewport.size.height, column.size.height + 40.0, reason: '视口高度应贴合内容');
    });

    testWidgets('行高一致（全 24px）：不溢出（对照）', (tester) async {
      await tester.pumpWidget(codeBlock(tallLineHeight: 1.7));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      final column = tester.renderObject<RenderBox>(find.byKey(const Key('code-lines')));
      expect(viewport.size.height, column.size.height + 40.0, reason: '视口高度贴合内容');
    });

    testWidgets('内容超 maxHeight：按上界截断可滚动', (tester) async {
      // 30 行 × 24px + 40 padding = 760 > 500。
      final codeBlock = Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ElView(
            style: const ElStyle(width: '100%'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 0, maxHeight: 500),
              child: ElScrollView(
                shrinkWrap: true,
                axis: null,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                children: <Widget>[
                  ElView(
                    style: const ElStyle(fontSize: 14, lineHeight: 1.7, softWrap: false),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[for (var i = 0; i < 30; i++) ElView(child: 'const line$i = $i;')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(codeBlock);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      expect(viewport.size.height, 500, reason: '内容超出 maxHeight 时按 500 截断');
      await tester.drag(find.byType(ElScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '截断后应可滚动无异常');
    });
  });

  group('成员外边距', () {
    Finder scrollRenderFinder() => find.byElementPredicate(
      (element) => element is RenderObjectElement && element.renderObject is RenderVirtualScrollView,
    );

    testWidgets('ElView margin is self-contained inside ElVirtualScrollView layout', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const _NoChromeScrollBehavior(),
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 120,
              child: buildVirtualTestView(
                controller: controller,
                physics: const ClampingScrollPhysics(),
                children: const [
                  ElView(
                    key: ValueKey('virtual-margin-item-0'),
                    style: ElStyle(
                      width: 100,
                      height: 50,
                      margin: .only(left: 12, right: 12, bottom: 8),
                      bgColor: Colors.green,
                    ),
                  ),
                  ElView(
                    key: ValueKey('virtual-margin-item-1'),
                    style: ElStyle(width: 100, height: 50, bgColor: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final scroll = tester.renderObject<RenderVirtualScrollView>(scrollRenderFinder());
      final first = tester.renderObject<ElRenderView>(find.byKey(const ValueKey('virtual-margin-item-0')));
      final second = tester.renderObject<ElRenderView>(find.byKey(const ValueKey('virtual-margin-item-1')));

      // 父视口紧约束 200：节点先撑满 200，再扣 margin → 视觉盒 176×50。
      // 显式 width:100 不敌父 min（Container enforce）；height 轴父未收紧，保留 50。
      expect(first.size.height, 58);
      expect(first.size.width, 200);
      expect(first.boxOrigin, const Offset(12, 0));
      expect(first.boxSize, const Size(176, 50));
      expect(tester.getTopLeft(find.byKey(const ValueKey('virtual-margin-item-1'))).dy, 58);
      // 无 margin 行：父紧约束直接落到视觉盒。
      expect(second.boxSize, const Size(200, 50));
      expect(scroll.contentSize.height, 108);
    });
  });

  group('内边距与间距', () {
    Finder scrollRenderFinder() => find.byElementPredicate(
      (element) => element is RenderObjectElement && element.renderObject is RenderVirtualScrollView,
    );

    Widget host({required Widget child, double width = 200, double height = 300}) {
      return MaterialApp(
        scrollBehavior: _PaddingGapNoChromeScrollBehavior(),
        home: Align(
          alignment: .topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      );
    }

    List<Widget> rows(int count, {double extent = 50}) => [
      for (var i = 0; i < count; i++) SizedBox(key: ValueKey('row-$i'), height: extent, width: 40),
    ];

    testWidgets('padding offsets rows, deflates cross axis, and grows content extent', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        host(
          child: buildVirtualTestView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            padding: .only(left: 10, top: 20, right: 6, bottom: 30),
            children: rows(4),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getTopLeft(find.byKey(ValueKey('row-0'))), Offset(10, 20));
      expect(tester.getSize(find.byKey(ValueKey('row-0'))).width, 200 - 10 - 6);
      expect(tester.getTopLeft(find.byKey(ValueKey('row-1'))).dy, 20 + 50);

      final scroll = tester.renderObject<RenderVirtualScrollView>(scrollRenderFinder());
      expect(scroll.contentSize.height, 20 + 4 * 50 + 30);
    });

    testWidgets('gap separates rows and joins the scroll extent', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        host(
          child: buildVirtualTestView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            gap: 8,
            children: rows(4),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getTopLeft(find.byKey(ValueKey('row-0'))).dy, 0);
      expect(tester.getTopLeft(find.byKey(ValueKey('row-1'))).dy, 58);
      expect(tester.getTopLeft(find.byKey(ValueKey('row-2'))).dy, 116);

      final scroll = tester.renderObject<RenderVirtualScrollView>(scrollRenderFinder());
      expect(scroll.contentSize.height, 4 * 50 + 3 * 8);
    });

    testWidgets('padding and gap compose with scrolling on a long list', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      // Row extent matches the default estimated extent so the content model is
      // exact from the first frame (no estimate-refinement drift in asserts).
      await tester.pumpWidget(
        host(
          child: buildVirtualTestView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            cacheExtent: 5000,
            padding: .only(top: 20, bottom: 30),
            gap: 10,
            children: rows(100, extent: 32),
          ),
        ),
      );
      await tester.pump();

      final scroll = tester.renderObject<RenderVirtualScrollView>(scrollRenderFinder());
      expect(tester.getTopLeft(find.byKey(ValueKey('row-0'))).dy, 20);
      expect(tester.getTopLeft(find.byKey(ValueKey('row-1'))).dy, 20 + 32 + 10);
      final totalExtent = 20 + 100 * 32 + 99 * 10 + 30;
      expect(scroll.contentSize.height, totalExtent.toDouble());
      expect(controller.position.maxScrollExtent, totalExtent - 300);

      controller.jumpTo(2000);
      await tester.pump();

      // Row i starts at 20 + i * 42 in content space. At offset 2000 the first
      // row whose end (20 + i * 42 + 32) is after 2000 is row 47.
      expect(find.byKey(ValueKey('row-47')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(ValueKey('row-47'))).dy, 20 + 47 * 42 - 2000);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      // Fully scrolled: the last row's bottom edge sits above the trailing padding.
      expect(tester.getBottomLeft(find.byKey(ValueKey('row-99'))).dy, 300 - 30);
    });

    testWidgets('horizontal axis maps padding and gap onto the main axis', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        host(
          width: 300,
          height: 120,
          child: buildVirtualTestView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            axis: .horizontal,
            padding: .only(left: 12, top: 8, bottom: 4),
            gap: 6,
            children: [for (var i = 0; i < 4; i++) SizedBox(key: ValueKey('col-$i'), width: 50, height: 40)],
          ),
        ),
      );
      await tester.pump();

      expect(tester.getTopLeft(find.byKey(ValueKey('col-0'))), Offset(12, 8));
      expect(tester.getTopLeft(find.byKey(ValueKey('col-1'))).dx, 12 + 50 + 6);
      // Horizontal cross constraints are loose (maxHeight deflated by padding);
      // the column keeps its own height.
      expect(tester.getSize(find.byKey(ValueKey('col-0'))).height, 40);
    });

    testWidgets('gap change relayouts rows and clamps the scroll offset', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      Widget build(double gap) => host(
        height: 150,
        child: buildVirtualTestView(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          gap: gap,
          // 精确 maxScrollExtent 断言需要全量测量（默认 cacheExtent 已改 0，
          // 只测可见行、尾部按估算 extent）。
          cacheExtent: 400,
          children: rows(6),
        ),
      );

      await tester.pumpWidget(build(20));
      await tester.pump();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.position.pixels, 6 * 50 + 5 * 20 - 150);

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();

      expect(controller.position.pixels, 6 * 50 - 150);
      expect(tester.getBottomLeft(find.byKey(ValueKey('row-5'))).dy, 150);
    });
  });

  group('布局失效边界', () {
    for (final equipped in [false, true]) {
      testWidgets('有限 loose 默认视口的子项与虚拟窗口重排不穿透父级，refresher=$equipped', (tester) async {
        final key = GlobalKey<ElScrollViewState>();
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        var parentLayouts = 0;
        var builtRows = 0;
        var height = 600.0;
        late StateSetter resizeRow;
        await tester.pumpWidget(
          _layoutBoundaryHost(
            ElScrollView(
              key: key,
              controller: controller,
              cacheExtent: 0,
              physics: const ClampingScrollPhysics(),
              scrollbar: equipped ? const ElAndroidScrollBar() : const ElNoScrollBar(),
              refresher: equipped ? const ElAndroidRefresher() : const ElNoRefresher(),
              onRefresh: equipped ? () async {} : null,
              children: [
                StatefulBuilder(
                  builder: (context, setState) {
                    resizeRow = setState;
                    return SizedBox(width: 100, height: height);
                  },
                ),
                ElListView.builder(
                  itemCount: 100,
                  itemBuilder: (context, index) {
                    builtRows++;
                    return const SizedBox(height: 40);
                  },
                  fixedSize: true,
                ),
              ],
            ),
            () => parentLayouts++,
          ),
        );
        await tester.pumpAndSettle();
        final viewport = _viewport(key);
        expect(viewport.constraints.isTight, isFalse, reason: '必须验证 sizedByParent，不能靠 tight 父约束自带的布局边界通过');
        expect(viewport.size, const Size(200, 300));
        final parentBefore = parentLayouts;
        final layoutsBefore = viewport.debugLayoutCount;
        resizeRow(() => height = 800);
        await tester.pumpAndSettle();
        expect(viewport.debugLayoutCount, greaterThan(layoutsBefore));
        expect(controller.position.maxScrollExtent, 4500);
        expect(parentLayouts, parentBefore, reason: '正文高度改变只影响滚动范围，不改变视口及刷新组合尺寸');
        final buildsBefore = builtRows;
        final layoutsBeforeScroll = viewport.debugLayoutCount;
        controller.jumpTo(1000);
        await tester.pumpAndSettle();
        expect(builtRows, greaterThan(buildsBefore));
        expect(viewport.debugLayoutCount, greaterThan(layoutsBeforeScroll));
        expect(parentLayouts, parentBefore, reason: '真实进入窗口的新行必须布局，但不能重新布局祖先');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('同一视口切换 shrinkWrap 时更新布局边界，内容变化同帧收缩父级', (tester) async {
      final key = GlobalKey<ElScrollViewState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      var parentLayouts = 0;
      var shrinkWrap = false;
      var height = 80.0;
      late StateSetter changeMode;
      late StateSetter resizeRow;
      await tester.pumpWidget(
        _layoutBoundaryHost(
          StatefulBuilder(
            builder: (context, setState) {
              changeMode = setState;
              return ElScrollView(
                key: key,
                controller: controller,
                shrinkWrap: shrinkWrap,
                scrollbar: const ElNoScrollBar(),
                children: [
                  StatefulBuilder(
                    builder: (context, setState) {
                      resizeRow = setState;
                      return SizedBox(width: 100, height: height);
                    },
                  ),
                ],
              );
            },
          ),
          () => parentLayouts++,
        ),
      );
      await tester.pumpAndSettle();
      final viewport = _viewport(key);
      expect(viewport.size, const Size(200, 300));
      var parentBefore = parentLayouts;
      changeMode(() => shrinkWrap = true);
      await tester.pump();
      expect(identical(_viewport(key), viewport), isTrue);
      expect(viewport.sizedByParent, isFalse);
      expect(viewport.size, const Size(100, 80));
      expect(tester.getSize(find.byType(_ParentLayoutProbe)), viewport.size);
      expect(parentLayouts, greaterThan(parentBefore));
      parentBefore = parentLayouts;
      resizeRow(() => height = 160);
      await tester.pump();
      expect(viewport.size, const Size(100, 160));
      expect(tester.getSize(find.byType(_ParentLayoutProbe)), viewport.size);
      expect(parentLayouts, greaterThan(parentBefore));
      parentBefore = parentLayouts;
      changeMode(() => shrinkWrap = false);
      await tester.pump();
      expect(identical(_viewport(key), viewport), isTrue);
      expect(viewport.sizedByParent, isTrue);
      expect(viewport.size, const Size(200, 300));
      expect(tester.getSize(find.byType(_ParentLayoutProbe)), viewport.size);
      expect(parentLayouts, greaterThan(parentBefore));
      parentBefore = parentLayouts;
      resizeRow(() => height = 400);
      await tester.pump();
      expect(viewport.size, const Size(200, 300));
      expect(controller.position.maxScrollExtent, 100);
      expect(parentLayouts, parentBefore, reason: '切回默认模式后必须恢复独立布局边界');
      expect(tester.takeException(), isNull);
    });
  });

  group('虚拟列表收缩布局', () {
    testWidgets('shrinkWrap: 裸 ElListView 全量挂载', (tester) async {
      final items = List<Widget>.generate(100, (i) => SizedBox(key: ValueKey('item-$i'), width: 100, height: 20));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 300),
              child: ElScrollView(shrinkWrap: true, children: [_shrinkWrapListItems(items)]),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // shrinkWrap 下虚拟化应失效：100 个 item 应全部挂载
      for (var i = 0; i < 100; i++) {
        expect(find.byKey(ValueKey('item-$i')), findsOneWidget, reason: 'shrinkWrap 下 item $i 应全量挂载（虚拟化失效）');
      }

      final viewport = tester.renderObject<RenderBox>(find.byType(ElScrollView));
      // 100 × 20px = 2000px，但约束上界 300，应截断为 300
      expect(viewport.size.height, 300, reason: '内容 2000px 超过上界 300，应截断');

      // 应该可以滚动
      await tester.drag(find.byType(ElScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
