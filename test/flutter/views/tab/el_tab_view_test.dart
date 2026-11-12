import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../ui/support/scrollbar_thumb.dart';

/// 固定物理的测试行为：把"环境物理"经官方 [ScrollConfiguration] 通道下发。
///
/// el 已删掉 `el.globalScrollPhysics` 全局表，环境物理统一走这条官方通道。
class _FixedPhysicsBehavior extends ScrollBehavior {
  const _FixedPhysicsBehavior(this.physics);

  final ScrollPhysics physics;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;
}

void main() {
  testWidgets('ElTabView shows the initial page', (tester) async {
    await tester.pumpWidget(_tabHarness(initialIndex: 1));

    expect(find.text('page-1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('page-0')).dx, lessThan(tester.getTopLeft(find.text('page-1')).dx));
  });

  testWidgets('horizontal drag switches to the next page', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(_tabHarness(controller: controller));

    await tester.drag(find.byType(ElTabView), const Offset(-260, 0));
    await tester.pumpAndSettle();

    expect(controller.index, 1);
    expect(find.text('page-1'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('首次消费先认领指针，再进入 dragging 与改写页面位置', (tester) async {
    final controller = ElTabController(length: 3);
    addTearDown(controller.dispose);
    bool? draggingSeenByLoserCancel;
    double? positionSeenByLoserCancel;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElView(
          style: const ElStyle(width: 400, height: 300, alignment: .center),
          event: ElEvent(
            onTapCancel: (_) {
              draggingSeenByLoserCancel = controller.isDragging;
              positionSeenByLoserCancel = controller.position;
            },
          ),
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(controller: controller, children: const [Text('page-0'), Text('page-1'), Text('page-2')]),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    addTearDown(gesture.removePointer);
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    final draggingAfterMove = controller.isDragging;
    final positionAfterMove = controller.position;
    await gesture.up();
    await tester.pumpAndSettle();

    expect(draggingSeenByLoserCancel, isFalse, reason: 'loser 结算必须早于 Tab 拖动态副作用。');
    expect(positionSeenByLoserCancel, 0, reason: 'loser 结算必须早于页面位置写入。');
    expect(draggingAfterMove, isTrue);
    expect(positionAfterMove, greaterThan(0));
  });

  testWidgets('short horizontal drag snaps back to the current page', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(_tabHarness(controller: controller));

    await tester.drag(find.byType(ElTabView), const Offset(-60, 0));
    await tester.pumpAndSettle();

    expect(controller.index, 0);
    controller.dispose();
  });

  // 松手翻页的速度阈对齐 Android `ViewPager.MIN_FLING_VELOCITY = 400` dip/s：
  // 轻扫只挪了几十像素（远不到位置阈 0.35 页 = 105px）也必须过页。
  testWidgets('a light horizontal fling above the Android 400 dp/s threshold switches page', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(_tabHarness(controller: controller));

    // 5 × 8px / 16ms ≈ 500 逻辑像素每秒，总位移 40px（0.13 页）。
    await _flingHorizontally(tester, stepDx: -8, stepCount: 5);
    await tester.pumpAndSettle();

    expect(controller.index, 1);
    controller.dispose();
  });

  testWidgets('a light horizontal fling switches back to the previous page', (tester) async {
    final controller = ElTabController(length: 3, initialIndex: 1);
    await tester.pumpWidget(_tabHarness(controller: controller));

    await _flingHorizontally(tester, stepDx: 8, stepCount: 5);
    await tester.pumpAndSettle();

    expect(controller.index, 0);
    controller.dispose();
  });

  testWidgets('a slow horizontal drag below the Android fling threshold snaps back', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(_tabHarness(controller: controller));

    // 5 × 5px / 16ms ≈ 312 逻辑像素每秒，低于 400 阈；位移 25px 也不到位置阈。
    await _flingHorizontally(tester, stepDx: -5, stepCount: 5);
    await tester.pumpAndSettle();

    expect(controller.index, 0);
    controller.dispose();
  });

  // 越界物理来自环境 ScrollConfiguration（官方通道），不是 tab 自带的常数：
  // 环境 bouncing 就该看到橡皮筋拉伸（position 走到界外），环境 clamping 就该
  // 硬止在边界。曾经 ElTabController.setPosition 把越界量 clamp 掉，无论怎么设
  // 都是死的。
  testWidgets('ambient bouncing physics stretches past the leading edge', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(_tabHarness(controller: controller, physics: const BouncingScrollPhysics()));

    // 页 0 继续向右拖 = 往前边界外拉。必须细步喂：官方
    // `applyPhysicsToUserOffset` 只在**已经越界**时才加摩擦，跨界那一笔恒
    // 无阻力，一次性甩一大段测不出橡皮筋。
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }

    expect(controller.position, lessThan(0.0), reason: '橡皮筋要求 position 能表达界外');
    // 120px 指位移 ÷ 300px 页宽：1:1 该到 -0.4（扣掉 slop 也有 ~-0.34），
    // 摩擦递减后实测 ≈ -0.17。这条阈值就是"摩擦到底有没有生效"的分界。
    expect(controller.position, greaterThan(-0.25), reason: '越拉越沉，不是 1:1 跟手');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.position, 0.0, reason: '松手必须回弹归位');
    expect(controller.index, 0);
    controller.dispose();
  });

  testWidgets('ambient clamping physics hard-stops at the leading edge', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(_tabHarness(controller: controller, physics: const ClampingScrollPhysics()));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    expect(controller.position, 0.0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.position, 0.0);
    controller.dispose();
  });

  testWidgets('vertical drag does not switch pages', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(_tabHarness(controller: controller));

    await tester.drag(find.byType(ElTabView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(controller.index, 0);
    expect(find.text('page-0'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('all pages are built eagerly at mount (full-mount contract)', (tester) async {
    // 用户裁决 2026-07-25：当前阶段全量挂载所有页（虚拟化 / 懒建后续立项）。
    final built = <int>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(
              children: List<Widget>.generate(20, (index) {
                return Builder(
                  builder: (context) {
                    built.add(index);
                    return Text('page-$index');
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );

    expect(built.toSet(), <int>{for (var i = 0; i < 20; i++) i});
  });

  testWidgets('page state survives switching and disposes only on teardown', (tester) async {
    final initialized = <int, int>{};
    final disposed = <int, int>{};
    final controller = ElTabController(length: 4);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(
              controller: controller,
              children: List<Widget>.generate(4, (index) {
                return _StateProbe(index: index, initialized: initialized, disposed: disposed);
              }),
            ),
          ),
        ),
      ),
    );

    // 全量挂载：所有页 State 一次初始化。
    expect(initialized, <int, int>{0: 1, 1: 1, 2: 1, 3: 1});

    var animation = controller.animateTo(1);
    await tester.pumpAndSettle();
    await animation;
    animation = controller.animateTo(3);
    await tester.pumpAndSettle();
    await animation;
    animation = controller.animateTo(0);
    await tester.pumpAndSettle();
    await animation;

    // 切换全程零重建零销毁：State 恒存活。
    expect(initialized, <int, int>{0: 1, 1: 1, 2: 1, 3: 1});
    expect(disposed, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(disposed, <int, int>{0: 1, 1: 1, 2: 1, 3: 1});
    controller.dispose();
  });

  testWidgets('lazy builds pages on first reveal only and keeps them by default', (tester) async {
    final built = <int>{};
    final controller = ElTabController(length: 5);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(
              controller: controller,
              lazy: true,
              children: List<Widget>.generate(5, (index) {
                return Builder(
                  builder: (context) {
                    built.add(index);
                    return Text('lazy-page-$index');
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
    expect(built, <int>{0}, reason: '懒加载：挂载时只构建可视页');

    // 拖拽露出邻页 → 首次露出瞬间构建（每页只触发一次，非逐帧）。
    // 首个 move 消费 slop（dragStart 种子归零），第二个 move 才产生位移。
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(built, <int>{0, 1}, reason: '邻页在拖拽露出时构建');

    await gesture.moveBy(const Offset(90, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(built, <int>{0, 1}, reason: 'keepState 默认保留已构建页，回弹不销毁');
  });

  testWidgets('lazy prefetches adjacent pages during idle frames within the cache budget', (tester) async {
    final built = <int>{};
    final controller = ElTabController(length: 5);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(
              controller: controller,
              lazy: true,
              maxCacheCount: 2,
              children: List<Widget>.generate(5, (index) {
                return Builder(
                  builder: (context) {
                    built.add(index);
                    return Text('prefetch-page-$index');
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
    expect(built, <int>{0}, reason: '首帧只构建可视页');

    // 空闲帧链式预热邻页：index+1 预挂后到达 maxCacheCount 上限即停
    //（绝不为预热淘汰缓存页）。
    await tester.pump();
    await tester.pump();
    expect(built, <int>{0, 1}, reason: '空闲预热邻页，且不超缓存预算');
    expect(tester.binding.hasScheduledFrame, isFalse, reason: '预热链结束后不空烧帧');
  });

  testWidgets('lazy without keepState disposes pages when they leave the viewport', (tester) async {
    final initialized = <int, int>{};
    final disposed = <int, int>{};
    final controller = ElTabController(length: 3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(
              controller: controller,
              lazy: true,
              keepState: false,
              children: List<Widget>.generate(3, (index) {
                return _StateProbe(index: index, initialized: initialized, disposed: disposed);
              }),
            ),
          ),
        ),
      ),
    );
    expect(initialized, <int, int>{0: 1});

    var animation = controller.animateTo(2);
    await tester.pumpAndSettle();
    await animation;
    expect(initialized[2], 1);
    expect(disposed[0], 1, reason: '离开可视范围即销毁');

    animation = controller.animateTo(0);
    await tester.pumpAndSettle();
    await animation;
    expect(initialized[0], 2, reason: '未保留状态的页面回来重建');
  });

  testWidgets('maxCacheCount evicts the least recently visited page first', (tester) async {
    final initialized = <int, int>{};
    final disposed = <int, int>{};
    final controller = ElTabController(length: 4);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(
              controller: controller,
              lazy: true,
              maxCacheCount: 2,
              children: List<Widget>.generate(4, (index) {
                return _StateProbe(index: index, initialized: initialized, disposed: disposed);
              }),
            ),
          ),
        ),
      ),
    );
    expect(initialized, <int, int>{0: 1});

    var animation = controller.animateTo(1);
    await tester.pumpAndSettle();
    await animation;
    expect(disposed, isEmpty, reason: '缓存 {0,1} 未超限');

    animation = controller.animateTo(2);
    await tester.pumpAndSettle();
    await animation;
    expect(disposed[0], 1, reason: '超限淘汰最久未访问的页 0');
    expect(initialized[1], 1, reason: '较新访问的页 1 保留不重建');

    animation = controller.animateTo(0);
    await tester.pumpAndSettle();
    await animation;
    expect(initialized[0], 2, reason: '被淘汰的页面回来重建');
  });

  testWidgets('drag and settle animation never rebuild or relayout pages', (tester) async {
    // 性能契约：position 变化只走 render 层 paint shift——页面 widget 零
    // rebuild、页 render 零 relayout（跟手成本与滚动同量级的结构保证）。
    var builds = 0;
    var layouts = 0;
    final controller = ElTabController(length: 3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(
              controller: controller,
              children: [
                Builder(
                  builder: (context) {
                    builds++;
                    return _LayoutProbe(onLayout: () => layouts++, child: const Text('page-0'));
                  },
                ),
                const Text('page-1'),
                const Text('page-2'),
              ],
            ),
          ),
        ),
      ),
    );
    final buildsAfterMount = builds;
    final layoutsAfterMount = layouts;

    // 拖拽跟手（不松手多帧）+ 松手 snap 动画到底。
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.index, 1);
    expect(builds, buildsAfterMount, reason: '跟手与 snap 动画期间页面 widget 不得 rebuild');
    expect(layouts, layoutsAfterMount, reason: '跟手与 snap 动画期间页面 render 不得 relayout');

    // 程序化切换动画同样零 rebuild 零 relayout。
    final animation = controller.animateTo(2);
    await tester.pumpAndSettle();
    await animation;
    expect(builds, buildsAfterMount);
    expect(layouts, layoutsAfterMount);
  });

  testWidgets('inner scroll can take over immediately while the settle animation runs', (tester) async {
    // 切换动画进行中，新指针必须能命中移动中的页面并立即接管其内部滚动。
    final tabController = ElTabController(length: 2);
    final verticalController = ScrollController();
    addTearDown(tabController.dispose);
    addTearDown(verticalController.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 220,
          child: ElTabView(
            controller: tabController,
            children: [
              const Text('page-0'),
              ElScrollView(
                controller: verticalController,
                children: List<Widget>.generate(
                  18,
                  (index) => SizedBox(width: 300, height: 60, child: Text('settle-row-$index')),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 启动切换动画，推进到中途（页面正在移动；弹簧档 160ms ≈ 位移 0.6 页，
    // 目标页中心已入视口）。
    final animation = tabController.animateTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(tabController.isAnimating, isTrue);

    // 动画中落指到目标页当前视觉位置（applyPaintTransform 反映实时位移），
    // 纵向拖拽：内层滚动立即响应。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ElScrollView)),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await animation;

    expect(verticalController.offset, greaterThan(0), reason: '动画中的新指针必须立即接管内层滚动');
    expect(tabController.index, 1, reason: '接管滚动不打断切换动画的归位');
    // index 在 _animateTo 一开始就被乐观置成目标页，断言它测不出"停在半页"；
    // 归位与否只有 position 说得准。
    expect(tabController.position, 1.0, reason: 'idle 必须停在整页');
  });

  // 复位不变量：idle（无手势 + 无动画）时 position 必须停在整页上。
  //
  // 用户实测（2026-07-26）：tab 切换动画中去滚内容，动画停住再也不归位。触发
  // 那条具体路径尚未在测试里复现出来（纵向内层滚动不会让 tab 收到 dragStart，
  // 见 A/B），所以这里**不假装复现它**，而是直接锁住"卡在半页要能自愈"这个
  // 不变量——无论是哪条路径把 position 丢在半页，守卫都得把它捞回来。
  testWidgets('a mid-page position with no drag and no animation self-heals', (tester) async {
    final controller = ElTabController(length: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_tabHarness(controller: controller));

    // 直接制造死状态：位置在页与页之间，却没有任何手势或动画会再推它一把。
    controller.setPosition(0.62);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(controller.position, 1.0, reason: '守卫必须把搁浅的 position 停靠到最近整页');
    expect(controller.index, 1);
  });

  testWidgets('descendant event that stops propagation prevents outer tab drag', (tester) async {
    final controller = ElTabController(length: 2);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: ElTabView(
              controller: controller,
              children: [
                ElView(
                  style: const ElStyle(width: 300, height: 200),
                  event: ElEvent(
                    dragStartDistance: 1,
                    onHorizontalDragStart: (event) {
                      event.consumePrimaryDelta(Axis.horizontal, event.remainingPrimaryDelta(Axis.horizontal));
                      event.stopPropagation();
                    },
                    onHorizontalDragUpdate: (event) {
                      event.consumePrimaryDelta(Axis.horizontal, event.remainingPrimaryDelta(Axis.horizontal));
                      event.stopPropagation();
                    },
                  ),
                  child: const Text('inner'),
                ),
                const Text('page-1'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('inner'), const Offset(-260, 0));
    await tester.pumpAndSettle();

    expect(controller.index, 0);
    controller.dispose();
  });

  testWidgets('dragging a child scroll bar does not trigger outer tab drag', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final controller = ElTabController(length: 2);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      ScrollConfiguration(
        behavior: ElScrollBehavior(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: ElTabView(
                controller: controller,
                children: [
                  ElScrollView(
                    key: const ValueKey('scrollbar-child-scroll'),
                    controller: scroll,
                    children: List<Widget>.generate(24, (index) {
                      return ElView(
                        style: ElStyle(width: 300, height: 40, backgroundColor: Color(0xFF202020 + index)),
                        child: Text('row-$index'),
                      );
                    }),
                  ),
                  const Text('page-1'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final thumb = elThumbRect(tester, scroll.position);
    expect(thumb, isNotNull);

    final gesture = await tester.startGesture(thumb!.center, kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(-260, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = null;
    expect(controller.index, 0);
    controller.dispose();
  });

  // TODO: fix nested tab/scroll gesture handoff so the inner vertical scroll
  // receives this pointer sequence even when wrapped by ElTabView.
  testWidgets('vertical child scroll wins over tab drag in a three-level nested gesture', (tester) async {
    final tabController = ElTabController(length: 2);
    final verticalController = ScrollController();
    final horizontalController = ScrollController();
    addTearDown(tabController.dispose);
    addTearDown(verticalController.dispose);
    addTearDown(horizontalController.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 220,
          child: ElTabView(
            controller: tabController,
            children: [
              ElScrollView(
                controller: verticalController,
                children: [
                  SizedBox(
                    width: 300,
                    height: 80,
                    child: ElScrollView(
                      controller: horizontalController,
                      axis: Axis.horizontal,
                      children: List<Widget>.generate(
                        12,
                        (index) => SizedBox(
                          key: ValueKey('horizontal-item-$index'),
                          width: 90,
                          height: 80,
                          child: Text('h-$index'),
                        ),
                      ),
                    ),
                  ),
                  ...List<Widget>.generate(
                    18,
                    (index) =>
                        SizedBox(key: ValueKey('vertical-row-$index'), width: 300, height: 60, child: Text('v-$index')),
                  ),
                ],
              ),
              const Text('page-1'),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('vertical-row-1'))),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(0, -180));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(verticalController.offset, greaterThan(0));
    expect(tabController.index, 0, reason: 'the vertical scroll consumed the drag and must be the only winner');
  }, skip: true);

  testWidgets('inner scroll should own a vertical-dominant drag so the tab does not switch', (tester) async {
    final tabController = ElTabController(length: 2);
    final verticalController = ScrollController();
    addTearDown(tabController.dispose);
    addTearDown(verticalController.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 220,
          child: ElTabView(
            controller: tabController,
            children: [
              ElScrollView(
                controller: verticalController,
                children: List<Widget>.generate(
                  18,
                  (index) =>
                      SizedBox(key: ValueKey('vertical-row-$index'), width: 300, height: 60, child: Text('v-$index')),
                ),
              ),
              const Text('page-1'),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('vertical-row-2'))),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(-160, -180));
    await tester.pump();
    await gesture.moveBy(const Offset(-12, -12));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(verticalController.offset, greaterThan(0));
    expect(tabController.index, 0, reason: 'the vertical scroll owns the gesture, so the tab must not switch');
  });

  testWidgets('tab drag switches page while the inner scroll stays put', (tester) async {
    final tabController = ElTabController(length: 2);
    final verticalController = ScrollController();
    addTearDown(tabController.dispose);
    addTearDown(verticalController.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 180,
            child: ElTabView(
              controller: tabController,
              children: [
                ElScrollView(
                  controller: verticalController,
                  children: List<Widget>.generate(
                    12,
                    (index) => SizedBox(
                      key: ValueKey('tab-owned-vertical-$index'),
                      width: 300,
                      height: 80,
                      child: Text('owned-$index'),
                    ),
                  ),
                ),
                const Text('page-1'),
              ],
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tab-owned-vertical-0'))),
      kind: PointerDeviceKind.touch,
    );
    // 零基契约下 accept 帧位移整段丢弃：单次 moveBy(-180) 起手会被 slop 吞掉，
    // 改用真实多步手势，激活后位移过半页。
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
    }
    await gesture.moveBy(const Offset(-24, -40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tabController.index, 1);
    expect(verticalController.offset, 0);
  });

  // 边缘让渡：内层横向滚动在边界方向 0 消费 → defer 给祖先，ElTabView 自机
  // 接管拖拽。旧版单次 moveBy 手势已过时（dragStart 种子归零契约下整段位移
  // 被 slop 吞掉），改用真实多步手势。
  // 暂跳过：ElScrollView 已改用官方 Scrollable 手势，不再作为 ElView 拖拽台账的 driver；
  // 待 ElView 拖拽识别器迁移到官方实现后，按新的手势归属重写本用例。
  testWidgets('horizontal child at boundary lets the tab claim the drag start', (tester) async {
    final tabController = ElTabController(length: 2, initialIndex: 1);
    final horizontalController = ScrollController();
    addTearDown(tabController.dispose);
    addTearDown(horizontalController.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 180,
            child: ElTabView(
              controller: tabController,
              children: [
                const Text('page-0'),
                ElScrollView(
                  controller: horizontalController,
                  axis: Axis.horizontal,
                  children: List<Widget>.generate(
                    12,
                    (index) => SizedBox(
                      key: ValueKey('boundary-horizontal-$index'),
                      width: 90,
                      height: 180,
                      child: Text('boundary-$index'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('boundary-horizontal-1'))),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(45, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(horizontalController.offset, 0, reason: '边界方向内层 0 消费，不滚动');
    expect(tabController.index, 0, reason: '让渡后 ElTabView 接管拖拽并切页');
  }, skip: true);

  testWidgets('programmatic animateTo can be called repeatedly', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(_tabHarness(controller: controller));

    var animation = controller.animateTo(1);
    await tester.pumpAndSettle();
    await animation;
    animation = controller.animateTo(2);
    await tester.pumpAndSettle();
    await animation;

    expect(controller.index, 2);
    controller.dispose();
  });

  testWidgets('replacing controller detaches the previous command delegate', (tester) async {
    final first = ElTabController(length: 3);
    final second = ElTabController(length: 3);

    await tester.pumpWidget(_tabHarness(controller: first));
    await tester.pumpWidget(_tabHarness(controller: second));

    await first.animateTo(2);

    expect(first.index, 2);
    expect(second.index, 0);

    first.dispose();
    second.dispose();
  });
}

/// 定速轻扫：每 [stepMs] 走 [stepDx] 像素，共 [stepCount] 步 → 末端速度
/// ≈ `stepDx / stepMs * 1000`。用真实时间戳喂速度追踪器（`tester.drag` 全程
/// 时间戳为 0，测不出速度，只能验位置阈）。
Future<void> _flingHorizontally(
  WidgetTester tester, {
  required double stepDx,
  required int stepCount,
  int stepMs = 16,
}) async {
  var elapsed = Duration.zero;
  final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)), pointer: 7);
  for (var i = 0; i < stepCount; i++) {
    elapsed += Duration(milliseconds: stepMs);
    await gesture.moveBy(Offset(stepDx, 0), timeStamp: elapsed);
    await tester.pump(Duration(milliseconds: stepMs));
  }
  await gesture.up(timeStamp: elapsed);
}

Widget _tabHarness({ElTabController? controller, int initialIndex = 0, ScrollPhysics? physics}) {
  Widget result = Center(
    child: SizedBox(
      width: 300,
      height: 200,
      child: ElTabView(
        controller: controller,
        initialIndex: initialIndex,
        children: const [Text('page-0'), Text('page-1'), Text('page-2')],
      ),
    ),
  );
  // 环境注入走官方 ScrollConfiguration 通道（全局表 el.globalScrollPhysics 已删）
  // 而不是 ElTabView.physics 直参：验的就是"环境设了物理，tab 认不认"。
  if (physics != null) {
    result = ScrollConfiguration(behavior: _FixedPhysicsBehavior(physics), child: result);
  }
  return Directionality(textDirection: TextDirection.ltr, child: result);
}

/// 布局计数探针：performLayout 每执行一次计一次，证页面在跟手期零 relayout。
class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayout, required Widget super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLayoutProbe(onLayout);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderLayoutProbe renderObject) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderLayoutProbe extends RenderProxyBox {
  _RenderLayoutProbe(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    onLayout();
    super.performLayout();
  }
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({required this.index, required this.initialized, required this.disposed});

  final int index;
  final Map<int, int> initialized;
  final Map<int, int> disposed;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.initialized.update(widget.index, (value) => value + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    widget.disposed.update(widget.index, (value) => value + 1, ifAbsent: () => 1);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('state-${widget.index}');
  }
}
