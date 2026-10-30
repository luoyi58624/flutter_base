import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 固定物理的测试行为：把"环境物理"经官方 [ScrollConfiguration] 通道下发。
///
/// el 已删掉 `el.globalScrollPhysics` 全局表，环境物理统一走这条官方通道。
class _FixedPhysicsBehavior extends ScrollBehavior {
  const _FixedPhysicsBehavior(this.physics);

  final ScrollPhysics physics;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;
}

/// ElTabView 停靠时长契约（2026-08-02 用户裁决：iOS 风格，结束缓慢）。
///
/// k120 临界阻尼：前 ~200ms 走完 ~80% 行程，尾段渐近缓出——视觉 ~500ms
/// 基本静止，收敛到 ±1px（模拟 isDone）实测 42 帧 ≈ 670ms。上界 48 帧兜
/// "没退回官方 k100/r1.1 那种 ≈1 秒的整体拖沓"，下界 28 帧兜"没有人把
/// 尾段又砍快"（上一版 k400 ~300ms 被裁决为结束太急）。快甩入射速度钳到
/// 零过冲上界，停靠仍绝不穿页。
void main() {
  Future<ElTabController> pumpTabs(
    WidgetTester tester, {
    int initialIndex = 0,
    ScrollPhysics? physics,
    ScrollPhysics? ambientPhysics,
  }) async {
    final controller = ElTabController(length: 3, initialIndex: initialIndex);
    addTearDown(controller.dispose);
    // el 的滚动物理走官方 ScrollConfiguration 通道（全局表已删）：环境物理在
    // 这里包一层 behavior 下发，验的就是"环境设了物理，tab 认不认"。
    Widget tabs = ElTabView(
      controller: controller,
      physics: physics,
      children: const [Text('page-0'), Text('page-1'), Text('page-2')],
    );
    if (ambientPhysics != null) {
      tabs = ScrollConfiguration(behavior: _FixedPhysicsBehavior(ambientPhysics), child: tabs);
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 400, height: 600, child: tabs),
      ),
    );
    return controller;
  }

  /// 逐帧泵到动画结束，返回 (帧数, 全程 position 极值)。
  Future<(int frames, double min, double max)> pumpUntilSettled(WidgetTester tester, ElTabController controller) async {
    var min = controller.position;
    var max = controller.position;
    void sample() {
      if (controller.position < min) min = controller.position;
      if (controller.position > max) max = controller.position;
    }

    controller.addListener(sample);
    var frames = 0;
    while (controller.isAnimating && frames < 240) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    controller.removeListener(sample);
    return (frames, min, max);
  }

  testWidgets('程序化切换 ~520ms 渐近收束（iOS 风格缓出），且零过冲', (tester) async {
    final controller = await pumpTabs(tester);

    controller.animateTo(1);
    await tester.pump();
    final (frames, min, max) = await pumpUntilSettled(tester, controller);

    expect(frames, lessThanOrEqualTo(48), reason: '停靠拖沓：$frames 帧（>770ms，整体拖沓不是缓出）');
    expect(frames, greaterThan(28), reason: 'iOS 风格要求渐近尾段：$frames 帧收束太急');
    // 临界阻尼：不许越过目标页再荡回来。
    expect(max, lessThanOrEqualTo(1.0 + precisionErrorTolerance), reason: '过冲到 $max');
    expect(min, greaterThanOrEqualTo(-precisionErrorTolerance));
    expect(controller.position, 1.0);
  });

  testWidgets('拖拽松手后的停靠同样在 ~770ms 内收束（快甩速度钳制后不穿页）', (tester) async {
    final controller = await pumpTabs(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    var stamp = Duration.zero;
    for (var i = 0; i < 10; i++) {
      stamp += const Duration(milliseconds: 8);
      await gesture.moveBy(const Offset(-24, 0), timeStamp: stamp);
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up(timeStamp: stamp);
    await tester.pump();

    final (frames, _, max) = await pumpUntilSettled(tester, controller);
    expect(frames, lessThanOrEqualTo(48), reason: '松手停靠拖沓：$frames 帧');
    // 快甩入射速度超过临界阻尼零过冲上界（ω·Δx）时被钳制：软弹簧下仍
    // 绝不越过目标页再荡回。
    expect(max, lessThanOrEqualTo(1.0 + precisionErrorTolerance), reason: '过冲到 $max');
    expect(controller.position, 1.0);
  });

  testWidgets('显式 duration 仍按调用方点名的节奏走补间', (tester) async {
    final controller = await pumpTabs(tester);

    controller.animateTo(1, duration: const Duration(milliseconds: 900));
    await tester.pump();
    final (frames, _, _) = await pumpUntilSettled(tester, controller);

    // 900ms ≈ 56 帧：显式时长不该被弹簧口径（~33 帧）吃掉。
    expect(frames, greaterThan(45), reason: '显式 duration 被忽略了：$frames 帧');
    expect(controller.position, 1.0);
  });

  // --- 弹簧跟随环境物理（官方 ScrollPhysics.spring 委托语义） --------------------
  //
  // 链上任何一层覆写 spring 即视为点名，settle 跟随；无人覆写（官方
  // _kDefaultSpring 单例）才用 tab 自己的 iOS 风格默认。k600 临界阻尼
  // ω≈34.6/s，全页 ~230ms ≈ 15 帧——与默认 42 帧界线分明。

  testWidgets('widget.physics 覆写 spring 时停靠跟随点名弹簧', (tester) async {
    final controller = await pumpTabs(tester, physics: const _StiffSpringPhysics());

    controller.animateTo(1);
    await tester.pump();
    final (frames, _, max) = await pumpUntilSettled(tester, controller);

    expect(frames, lessThan(25), reason: '点名 k600 弹簧被 tab 默认弹簧吃掉了：$frames 帧');
    expect(max, lessThanOrEqualTo(1.0 + precisionErrorTolerance));
    expect(controller.position, 1.0);
  });

  testWidgets('环境 ScrollConfiguration 物理覆写 spring 时停靠同样跟随', (tester) async {
    final controller = await pumpTabs(tester, ambientPhysics: const _StiffSpringPhysics());

    controller.animateTo(1);
    await tester.pump();
    final (frames, _, _) = await pumpUntilSettled(tester, controller);

    expect(frames, lessThan(25), reason: '环境点名弹簧未被跟随：$frames 帧');
    expect(controller.position, 1.0);
  });
}

/// 覆写 spring 的测试物理：k600 临界阻尼，停靠明显快于 tab 默认（k120）。
class _StiffSpringPhysics extends ScrollPhysics {
  const _StiffSpringPhysics({super.parent});

  @override
  _StiffSpringPhysics applyTo(ScrollPhysics? ancestor) => _StiffSpringPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(mass: 0.5, stiffness: 600.0, ratio: 1.0);
}
