import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// ElTabView 边缘越界视效回归（ui_example 实测缺陷）：
///
/// clamping 环境（Android / 桌面默认物理）下，首/尾页继续外拉的位移被
/// `applyBoundaryConditions` 静默吃掉——无 OverscrollNotification、无
/// indicator，Android 拉伸完全不触发；iOS 弹跳依赖环境 bouncing 物理，
/// 需要真实 MaterialApp 环境（而非测试自造 behavior）验证仍然成立。
///
/// 修复口径与 ElScroll 单源一致：环境 `buildOverscrollIndicator` 收口
/// 视效 + 官方 `setPixels → didOverscrollBy` 同构的通知流（Start/End 整个
/// 手势各一次，越界期间纯 Overscroll 序列）。
void main() {
  final notifications = <ScrollNotification>[];
  final indicatorNotifications = <OverscrollIndicatorNotification>[];

  setUp(() {
    notifications.clear();
    indicatorNotifications.clear();
  });

  Widget app({required TargetPlatform platform, ElTabController? controller, List<Widget>? pages}) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            indicatorNotifications.add(n);
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              notifications.add(n);
              return false;
            },
            child: ElTabView(
              controller: controller,
              children:
                  pages ??
                  [
                    for (var i = 0; i < 3; i++)
                      ColoredBox(
                        color: Colors.transparent,
                        child: Center(child: Text('page-$i')),
                      ),
                  ],
            ),
          ),
        ),
      ),
    );
  }

  Iterable<OverscrollNotification> overscrolls() => notifications.whereType<OverscrollNotification>();

  testWidgets('Android 环境：首页继续外拉走 stretch 链路——indicator 建立、越界通知派发、拉伸确认', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(app(platform: TargetPlatform.android, controller: controller));

    // M3 Android 环境必须建出官方 stretch indicator（修复前 ElTabView 根本不建）。
    expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }

    // clamping 硬止在边界，但被吃掉的量必须按官方口径上报（负 = 前边界，
    // 横轴 metrics），而不是静默黑洞。
    expect(controller.position, 0.0);
    expect(overscrolls(), isNotEmpty, reason: '贴边外拉的每一帧都该报 OverscrollNotification');
    for (final n in overscrolls()) {
      expect(n.overscroll, lessThan(0.0));
      expect(n.metrics.axis, Axis.horizontal);
      expect(n.depth, 0, reason: 'tab 自己的通知必须以 depth 0 到达 indicator');
    }
    // indicator 真的接了这条流：接受新一轮越界时会发确认通知（leading 边）。
    expect(indicatorNotifications, isNotEmpty, reason: 'stretch indicator 应确认接受本轮拉伸');
    expect(indicatorNotifications.first.leading, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    // Start/End 整手势各一次：松手补 End，indicator 借此回收拉伸。
    expect(notifications.whereType<ScrollStartNotification>().length, 1);
    expect(notifications.whereType<ScrollEndNotification>().length, 1);
    expect(controller.position, 0.0);
    controller.dispose();
  });

  testWidgets('Android 环境：尾页继续外拉报正向越界（trailing 边）', (tester) async {
    final controller = ElTabController(length: 3, initialIndex: 2);
    await tester.pumpWidget(app(platform: TargetPlatform.android, controller: controller));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
    }

    expect(controller.position, 2.0);
    expect(overscrolls(), isNotEmpty);
    for (final n in overscrolls()) {
      expect(n.overscroll, greaterThan(0.0));
    }
    expect(indicatorNotifications, isNotEmpty);
    expect(indicatorNotifications.first.leading, isFalse);

    await gesture.up();
    await tester.pumpAndSettle();
    controller.dispose();
  });

  testWidgets('Android 环境：甩动撞界带冲击速度（absorbImpact 路径）', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(app(platform: TargetPlatform.android, controller: controller));

    // 首页向右快甩：拖拽帧的越界 velocity 为 0，松手后弹道撞界那一帧必须
    // 带非零冲击速度，喂 indicator 的 absorbImpact。
    await tester.fling(find.byType(ElTabView), const Offset(120, 0), 2000);
    await tester.pumpAndSettle();

    expect(controller.position, 0.0);
    expect(overscrolls().any((n) => n.velocity != 0.0), isTrue, reason: '弹道撞界应报带冲击速度的越界');
    controller.dispose();
  });

  testWidgets('iOS 环境：el 平台默认 bouncing 下首页外拉出橡皮筋、松手回弹', (tester) async {
    // 物理按 defaultTargetPlatform 解析（el 平台默认，不读 Flutter
    // ScrollConfiguration）；indicator 侧走 Theme platform，两头都要 iOS。
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(app(platform: TargetPlatform.iOS, controller: controller));

    // iOS 不建 indicator，弹跳由 bouncing 物理承担。
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }

    expect(controller.position, lessThan(0.0), reason: '橡皮筋要求 position 能出界');
    // bouncing 越界不经过边界吃量，不该出现 OverscrollNotification。
    expect(overscrolls().where((n) => n.overscroll != 0.0), isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.position, 0.0, reason: '松手必须回弹归位');
    controller.dispose();
    // 主动复位，不等 tearDown——binding 的 postTest 断言先于 tearDown 跑。
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('页内滚动通知跨越 tab viewport 后 depth 递增，不误拉 tab 的 indicator', (tester) async {
    final controller = ElTabController(length: 3);
    await tester.pumpWidget(app(platform: TargetPlatform.android, controller: controller));

    // RenderAbstractViewport 契约：页内容能定位到 tab viewport，且 reveal
    // 偏移按页序几何给出（页 0 贴左缘 = 0）。
    final pageRender = tester.renderObject(find.text('page-0'));
    final viewport = RenderAbstractViewport.maybeOf(pageRender);
    expect(viewport, isNotNull, reason: 'tab viewport 必须参与官方 depth 计数');
    final revealed = viewport!.getOffsetToReveal(pageRender, 0.0);
    expect(revealed.offset, closeTo(0.0, 0.01));

    // 从页内容 context 派发一条横轴越界通知（模拟页内横向滚动条的越界），
    // 到达外层监听时 depth 必须 ≥ 1——tab 的 indicator 只认 depth 0，不误拉。
    final pageContext = tester.element(find.text('page-0'));
    OverscrollNotification(
      metrics: FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: 0,
        viewportDimension: 200,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1,
      ),
      context: pageContext,
      overscroll: -10,
    ).dispatch(pageContext);
    await tester.pump();

    expect(overscrolls(), isNotEmpty);
    expect(overscrolls().first.depth, greaterThanOrEqualTo(1));
    expect(indicatorNotifications, isEmpty, reason: '页内越界不得触发 tab 层拉伸确认');
    controller.dispose();
  });
}
