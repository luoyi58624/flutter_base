import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 拖拽期页内容不吃指针（误触选中/点击的修复口径，2026-07-26 用户裁决）：
/// 开在真正消费位移那一刻，关在松手/取消那一刻——包括"甩出去"那一下。
void main() {
  Future<ElTabController> pumpTabs(WidgetTester tester, List<String> taps) async {
    final controller = ElTabController(length: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 600)),
          child: SizedBox(
            width: 400,
            height: 600,
            child: ElTabView(
              controller: controller,
              children: [
                for (var i = 0; i < 3; i++)
                  ElView(
                    key: ValueKey('page-$i'),
                    style: const ElStyle(width: 400, height: 600),
                    event: ElEvent(onTap: (_) => taps.add('page-$i')),
                    child: ElView(
                      key: ValueKey('card-$i'),
                      style: const ElStyle(width: 200, height: 100),
                      event: ElEvent(onTap: (_) => taps.add('card-$i')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('tap still works when no drag happened', (tester) async {
    final taps = <String>[];
    await pumpTabs(tester, taps);

    await tester.tap(find.byKey(const ValueKey('card-0')));
    await tester.pump();

    // 卡片与页都挂了 onTap，未 stopPropagation 时两者都该收到（冒泡）。
    expect(taps, contains('card-0'), reason: '未拖拽时页内容照常可点');
  });

  testWidgets('page content stops receiving pointers once the drag is consumed', (tester) async {
    final taps = <String>[];
    await pumpTabs(tester, taps);

    // 横向拖过翻页阈值：手指仍按下时页内容已不该吃命中。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('card-0'))),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // 断言口径：拖拽期页子树（page/card 的 ElRenderView 与 _RenderTabPage）
    // 必须整体退出命中路径。注：不能只断言"某点击不到"——事件面在认领手势时
    // 本就会吞子命中，那个既有行为会掩盖开关失效（本测试曾因此假绿）。
    final pageRender = tester.renderObject(find.byKey(const ValueKey('page-0')));
    final during = tester.hitTestOnBinding(const Offset(200, 300));
    final targets = during.path.map((e) => e.target).toList();
    expect(targets, isNot(contains(pageRender)), reason: '拖拽期页内容退出命中路径');
    expect(targets.whereType<RenderBox>().length, lessThan(during.path.length), reason: '前提：命中路径本身非空（只是不含页子树）');

    // 抬手（带甩动速度）后立刻恢复：settle 还在跑也该点得到。
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.up();
    await tester.pump();

    expect(taps, isEmpty, reason: '整条拖拽手势不产生任何 tap');
  });

  testWidgets('content is tappable again right after release, mid-settle', (tester) async {
    final taps = <String>[];
    final controller = await pumpTabs(tester, taps);

    final gesture = await tester.startGesture(const Offset(200, 300), kind: PointerDeviceKind.touch);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    expect(controller.isAnimating, isTrue, reason: '前提：松手后 settle 动画在跑');

    // settle 期间页子树必须已回到命中路径（`hit.path isNotEmpty` 证明不了
    // 任何事——RenderView 恒在路径里，那是假绿）。
    final pageTargets = tester
        .hitTestOnBinding(const Offset(200, 300))
        .path
        .map((e) => e.target)
        .whereType<RenderObject>()
        .toSet();
    final pages = [
      for (var i = 0; i < 3; i++)
        if (find.byKey(ValueKey('page-$i')).evaluate().isNotEmpty) tester.renderObject(find.byKey(ValueKey('page-$i'))),
    ];
    expect(pages.any(pageTargets.contains), isTrue, reason: '甩出后 settle 期页内容重回命中路径');
    await tester.pumpAndSettle();
  });
}
