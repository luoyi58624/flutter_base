import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// ElTabView 的**边界契约**：
///
/// ElTabView 自己扮演 `ScrollPosition` 的角色（模拟直驱 controller.position），
/// 所以官方 `ScrollPosition.setPixels` 里的那道 `applyBoundaryConditions`
/// 兜底必须自己做——物理交出的弹道**本来就允许越界**（`ElClampingScrollPhysics`
/// 贴边外向会给一条一路向外的摩擦曲线，普通滚动靠下游 setPixels 拦），少了它
/// 首页 / 末页会被甩出好几屏。
void main() {
  const pageWidth = 400.0;

  Future<ElTabController> pumpTabs(
    WidgetTester tester, {
    required ScrollPhysics physics,
    int initialIndex = 0,
    int length = 3,
  }) async {
    final controller = ElTabController(length: length, initialIndex: initialIndex);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: pageWidth,
          height: 600,
          child: ElTabView(
            controller: controller,
            physics: physics,
            children: [for (var i = 0; i < length; i++) Text('page-$i')],
          ),
        ),
      ),
    );
    return controller;
  }

  /// 快速拖动并松手：每步 [step] 像素、每帧 8ms（≈ step×125 px/s），足以让
  /// 松手速度进入手势识别器的 fling 区间。返回全程 position 的极值。
  Future<(double min, double max)> fastDragAndRelease(
    WidgetTester tester,
    ElTabController controller, {
    required double step,
    int steps = 30,
  }) async {
    var min = controller.position;
    var max = controller.position;
    void sample() {
      if (controller.position < min) min = controller.position;
      if (controller.position > max) max = controller.position;
    }

    controller.addListener(sample);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
    // **必须显式喂时间戳**：TestGesture.moveBy 默认 timeStamp 恒为 0，速度追踪器
    // 拿不到时间差 → 松手速度恒 0 → settle 永远走不进弹道分支（曾因此测不出
    // 边界溢出，误判"没问题"）。
    var stamp = Duration.zero;
    for (var i = 0; i < steps; i++) {
      stamp += const Duration(milliseconds: 8);
      await gesture.moveBy(Offset(step, 0), timeStamp: stamp);
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up(timeStamp: stamp);
    await tester.pumpAndSettle();
    controller.removeListener(sample);
    return (min, max);
  }

  group('clamping：任何弹道都不得把 position 推出页范围', () {
    testWidgets('高速拖到末页并继续外推，松手后不得飞出末页', (tester) async {
      final controller = await pumpTabs(tester, physics: const ElClampingScrollPhysics(), initialIndex: 1);
      final (min, max) = await fastDragAndRelease(tester, controller, step: -60);

      expect(max, lessThanOrEqualTo(2.0 + precisionErrorTolerance), reason: '末页被甩出去了：峰值 position=$max');
      expect(min, greaterThanOrEqualTo(-precisionErrorTolerance));
      expect(controller.position, 2.0);
    });

    testWidgets('高速拖到首页并继续外推，松手后不得飞出首页', (tester) async {
      final controller = await pumpTabs(tester, physics: const ElClampingScrollPhysics(), initialIndex: 1);
      final (min, max) = await fastDragAndRelease(tester, controller, step: 60);

      expect(min, greaterThanOrEqualTo(-precisionErrorTolerance), reason: '首页被甩出去了：谷值 position=$min');
      expect(max, lessThanOrEqualTo(2.0 + precisionErrorTolerance));
      expect(controller.position, 0.0);
    });

    testWidgets('官方 clamping 同样锁死边界', (tester) async {
      final controller = await pumpTabs(tester, physics: const ClampingScrollPhysics(), initialIndex: 1);
      final (min, max) = await fastDragAndRelease(tester, controller, step: -60);

      expect(min, greaterThanOrEqualTo(-precisionErrorTolerance));
      expect(max, lessThanOrEqualTo(2.0 + precisionErrorTolerance));
    });
  });

  group('bouncing（iOS）：越界拉伸必须生效，且松手回弹归位', () {
    testWidgets('首页继续向界外拖 → position 出界（橡皮筋生效）且带阻尼', (tester) async {
      final controller = await pumpTabs(tester, physics: const ElBouncingScrollPhysics());

      final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final held = controller.position;

      expect(held, lessThan(0.0), reason: 'iOS 橡皮筋没生效：拖到界外 position 仍为 $held');
      // 拖了 480px ≈ 1.2 页，越界量必须远小于它——证明摩擦阻尼真的在起作用。
      expect(held, greaterThan(-0.6), reason: '越界无阻尼（1:1 跟手）：position=$held');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.position, 0.0, reason: '松手必须回弹归位');
    });

    testWidgets('末页继续向界外拖 → 同样拉伸 + 回弹', (tester) async {
      final controller = await pumpTabs(tester, physics: const ElBouncingScrollPhysics(), initialIndex: 2);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(ElTabView)));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final held = controller.position;

      expect(held, greaterThan(2.0), reason: 'iOS 橡皮筋没生效：position=$held');
      expect(held, lessThan(2.6), reason: '越界无阻尼：position=$held');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.position, 2.0);
    });

    testWidgets('边界兜底不得吃掉 bouncing 的越界弹道（回弹过程本身允许在界外）', (tester) async {
      final controller = await pumpTabs(tester, physics: const ElBouncingScrollPhysics());
      final (min, _) = await fastDragAndRelease(tester, controller, step: 60);

      expect(min, lessThan(0.0), reason: 'bouncing 下越界被兜底吃光了，橡皮筋失效：min=$min');
      expect(controller.position, 0.0);
    });
  });
}
