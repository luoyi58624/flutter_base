// tapCancelByDistance（2026-07-26）：主键 tap 的取消口径可选。
//
// - 默认 false = **边界口径**（iOS UIControl touchDragExit / touchDragEnter）：
//   拖出宿主熄灭按压态并 fire cancel，拖回复燃并重 fire tapDown，抬手位置
//   在范围内照常 fire tap。
// - true = **距离口径**：超过 tapCancelDistance 永久取消最终 tap，移回不复活。
// - 两种口径都只取消激活资格；物理 PointerUp 仍兑现 tapUp。

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

class _NoChromeBehavior extends ScrollBehavior {
  const _NoChromeBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

void main() {
  setUp(() {
    EventDispatcher.debugResetEagerGestureOwners();
  });

  Widget shell(Widget child) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );
  }

  testWidgets('TAP-B1: 默认口径下盒内大幅移动仍触发 tap', (tester) async {
    var taps = 0;
    var cancels = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 200, height: 200),
          event: ElEvent(onTap: (_) => taps++, onTapCancel: (_) => cancels++),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(20, 20));
    await g.moveTo(const Offset(180, 180)); // 位移 226px，远超 tapCancelDistance
    await g.up();
    await tester.pump();

    expect(taps, 1, reason: '始终没出元素范围 → 抬手照常触发 tap');
    expect(cancels, 0);
  });

  testWidgets('TAP-B2: 拖出边界抬手不触发 tap，且 fire 一次 cancel', (tester) async {
    var taps = 0;
    var tapUps = 0;
    var cancels = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: ElEvent(onTapUp: (_) => tapUps++, onTap: (_) => taps++, onTapCancel: (_) => cancels++),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(20, 20));
    await g.moveTo(const Offset(300, 20));
    await g.up();
    await tester.pump();

    expect(taps, 0);
    expect(tapUps, 1, reason: '拖出只取消激活资格，物理释放仍有 tapUp');
    expect(cancels, 1, reason: '拖出时 fire 一次，抬手不得重复 fire');
  });

  testWidgets('TAP-B3: 拖出再拖回 → tapDown 复燃，抬手触发 tap', (tester) async {
    final phases = <ElEventPhase>[];
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: ElEvent(
            onTapDown: (e) => phases.add(e.phase),
            onTapCancel: (e) => phases.add(e.phase),
            onTapUp: (e) => phases.add(e.phase),
            onTap: (e) => phases.add(e.phase),
          ),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(20, 20));
    await g.moveTo(const Offset(300, 20)); // 出界
    await g.moveTo(const Offset(20, 20)); // 回来
    await g.up();
    await tester.pump();

    expect(phases, <ElEventPhase>[
      ElEventPhase.tapDown,
      ElEventPhase.tapCancel,
      ElEventPhase.tapDown,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ]);
  });

  testWidgets('TAP-B4: 多次进出只在跨界时 fire，不逐帧刷屏', (tester) async {
    var tapDowns = 0;
    var cancels = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: ElEvent(onTap: (_) {}, onTapDown: (_) => tapDowns++, onTapCancel: (_) => cancels++),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(20, 20));
    // 界内连续移动多次：不应产生任何额外 tapDown / cancel
    await g.moveTo(const Offset(40, 40));
    await g.moveTo(const Offset(60, 60));
    // 出界后继续在界外移动多次：只 fire 一次 cancel
    await g.moveTo(const Offset(300, 60));
    await g.moveTo(const Offset(400, 60));
    // 回界内再移动多次：只 fire 一次 tapDown
    await g.moveTo(const Offset(30, 30));
    await g.moveTo(const Offset(50, 50));
    await g.up();
    await tester.pump();

    expect(tapDowns, 2, reason: '初次按下 + 回界复燃各一次');
    expect(cancels, 1);
  });

  testWidgets('TAP-B5: 边界口径认圆角裁剪，角外区域算出界', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(
            width: 100,
            height: 100,
            borderRadius: .all(Radius.circular(50)),
            clipBehavior: Clip.antiAlias,
          ),
          event: ElEvent(onTap: (_) => taps++),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(50, 50));
    await g.moveTo(const Offset(2, 2)); // 圆形之外的左上角
    await g.up();
    await tester.pump();

    expect(taps, 0, reason: '抬手落在圆角裁掉的角上 → 不算在元素范围内');
  });

  testWidgets('TAP-B6: tapCancelByDistance=true 恢复距离口径，移回不复活', (tester) async {
    var taps = 0;
    var tapUps = 0;
    var cancels = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 200, height: 200),
          event: ElEvent(
            config: const ElEventConfig(tapCancelByDistance: true),
            onTapUp: (_) => tapUps++,
            onTap: (_) => taps++,
            onTapCancel: (_) => cancels++,
          ),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(100, 100));
    await g.moveTo(const Offset(140, 100)); // 盒内，但超 10px
    await g.moveTo(const Offset(100, 100)); // 移回原位
    await g.up();
    await tester.pump();

    expect(taps, 0, reason: '距离口径：越界即永久取消，移回原位也不复活');
    expect(tapUps, 1);
    expect(cancels, 1);
  });

  testWidgets('TAP-B11: 官方 SingleChildScrollView 滚动后，子按钮不得复燃变体也不得 tap', (tester) async {
    // 用户实机报告（button 页用官方 SingleChildScrollView）：按压 → 滚动 →
    // 手指移回按钮 → 变体又亮了、松手还触发点击。官方 Scrollable 在 gesture
    // arena 里独立获胜，ElEvent 闭环收不到任何拖拽信号，只能靠"内容在手指
    // 底下漂移"反推手势归属已定。
    var taps = 0;
    var cancels = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(
        SizedBox(
          width: 200,
          height: 400,
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                for (var i = 0; i < 30; i++)
                  ElView(
                    key: ValueKey('btn-$i'),
                    style: const ElStyle(
                      width: 200,
                      height: 200,
                      backgroundColor: Color(0xFFFF0000),
                      onTap: ElStyle(backgroundColor: Color(0xFF0000FF)),
                    ),
                    event: ElEvent(onTap: (_) => taps++, onTapCancel: (_) => cancels++),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final box = tester.renderObject<ElRenderView>(find.byKey(const ValueKey('btn-0')));
    Object? bg() => box.committedResolvedStyle.box.backgroundColor;

    final g = await tester.createGesture();
    await g.down(const Offset(100, 100));
    await tester.pump();
    expect(bg(), const Color(0xFF0000FF), reason: '按下进 active');

    await g.moveBy(const Offset(0, -60));
    await tester.pump();
    await g.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(controller.offset, greaterThan(0), reason: '确认官方滚动真的动了');
    expect(bg(), const Color(0xFFFF0000), reason: '内容被搬走 → 按压态必须熄灭');
    expect(cancels, 1);

    // 手指移回按钮区域：不得复燃（手势归属已定，不是"拖出又拖回"）
    await g.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(bg(), const Color(0xFFFF0000), reason: '滚动过的手势不得复燃变体');

    await g.up();
    await tester.pumpAndSettle();
    expect(taps, 0, reason: '滚动过的手势松手不得触发 tap');
  });

  testWidgets('TAP-B12: 跟手拖动自身的元素不因宿主位移自伤（漂移判据只认相对漂移）', (tester) async {
    // 宿主随手指同步平移时，手指与宿主同速 → 相对漂移恒 0，拖拽不得被掐断。
    var dragUpdates = 0;
    var offset = Offset.zero;

    await tester.pumpWidget(
      shell(
        StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 400,
              height: 400,
              child: Stack(
                children: [
                  Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: ElView(
                      style: const ElStyle(width: 100, height: 100),
                      event: ElEvent(
                        onTap: (_) {},
                        onDragStart: (_) {},
                        onDragUpdate: (e) {
                          dragUpdates++;
                          setState(() => offset += e.delta);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(50, 50));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    await g.up();
    await tester.pump();

    expect(dragUpdates, greaterThan(0), reason: '跟手拖动必须持续收到 update');
    expect(offset.dy, greaterThan(0), reason: '元素确实跟着手指走了');
  });

  testWidgets('TAP-B13: 按下反馈是缩放的元素不得自伤（盒子缩到手指底下跑掉≠出界）', (tester) async {
    // 按下变换是控件对这次按压的响应，不该反过来否决这次按压。取并集之前
    // 这里会形成 按下→缩小→出界→取消→回弹→又进来 的自激环。
    var taps = 0;
    var cancels = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(
            width: 300,
            height: 300,
            backgroundColor: Color(0xFF884422),
            onTap: ElStyle(transform: .scale(0.85)),
          ),
          event: ElEvent(onTap: (_) => taps++, onTapCancel: (_) => cancels++),
        ),
      ),
    );

    // 按在靠边处：scale 0.85 让该点相对中心位移约 0.15×140 ≈ 21px
    final g = await tester.createGesture();
    await g.down(const Offset(290, 150));
    await tester.pump();
    await g.moveBy(const Offset(1, 0)); // 手指几乎没动
    await tester.pump();
    await g.up();
    await tester.pump();

    expect(cancels, 0, reason: '自身按下动画造成的位移不是"手指离开了控件"');
    expect(taps, 1);
  });

  testWidgets('TAP-B14: 按下反馈是平移的元素同样不得自伤', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(
            width: 200,
            height: 200,
            backgroundColor: Color(0xFF884422),
            onTap: ElStyle(transform: .translate(0, 25)),
          ),
          event: ElEvent(onTap: (_) => taps++),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(100, 100));
    await tester.pump();
    await g.moveBy(const Offset(0, 1));
    await tester.pump();
    await g.up();
    await tester.pump();

    expect(taps, 1, reason: '自身 translate 反馈不得自伤');
  });

  testWidgets('TAP-B15: 长距离滚动全程跟手，不得出现停顿帧', (tester) async {
    // 漂移判据跑在每个 move 上，必须证明它不会掐断滚动本身。
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(
        ScrollConfiguration(
          behavior: const _NoChromeBehavior(),
          child: SizedBox(
            width: 200,
            height: 400,
            child: ElScroll(
              controller: controller,
              children: [
                for (var i = 0; i < 60; i++)
                  ElView(
                    style: const ElStyle(width: 200, height: 100, backgroundColor: Color(0xFF884422)),
                    event: ElEvent(onTap: (_) {}),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(100, 200));
    await tester.pump();

    final offsets = <double>[];
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, -20));
      await tester.pump();
      offsets.add(controller.offset);
    }
    await g.up();
    await tester.pump();

    // 跳过起手 slop 段，之后每步都必须有位移增量
    for (var i = 6; i < offsets.length; i++) {
      expect(offsets[i] - offsets[i - 1], greaterThan(1.0), reason: '第 $i 步滚动停顿了：${offsets[i - 1]} → ${offsets[i]}');
    }
  });

  testWidgets('TAP-B16: 按住的元素中途从树上摘除，后续 move / up 不得抛', (tester) async {
    var present = true;
    late StateSetter setter;
    await tester.pumpWidget(
      shell(
        StatefulBuilder(
          builder: (context, setState) {
            setter = setState;
            return SizedBox(
              width: 300,
              height: 300,
              child: present
                  ? ElView(
                      style: const ElStyle(width: 300, height: 300, backgroundColor: Color(0xFF884422)),
                      event: ElEvent(onTap: (_) {}, onTapCancel: (_) {}),
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(150, 150));
    await tester.pump();
    setter(() => present = false); // 虚拟滚动回收 / 路由切换的等价场景
    await tester.pump();
    await g.moveBy(const Offset(0, -40));
    await tester.pump();
    await g.up();
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'detach 后漂移判定必须放弃而不是撞 assert');
  });

  testWidgets('TAP-B7: 滚动容器里的子项——滚动后抬手不得误触发 tap', (tester) async {
    var taps = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(
        ScrollConfiguration(
          behavior: const _NoChromeBehavior(),
          child: SizedBox(
            width: 200,
            height: 300,
            child: ElScroll(
              controller: controller,
              children: List<Widget>.generate(
                40,
                // 子项做得很高：滚动位移全程都落在同一个子项盒内，
                // 距离口径的"移动即取消"帮不上忙，只能靠 drag 接受取消。
                (i) => ElView(
                  key: ValueKey('item-$i'),
                  style: const ElStyle(width: 200, height: 250),
                  event: ElEvent(onTap: (_) => taps++),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(100, 100));
    await g.moveBy(const Offset(0, -60));
    await tester.pump();
    await g.moveBy(const Offset(0, -60));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0), reason: '确认这一手势真的滚动了');
    expect(taps, 0, reason: '滚动接受拖拽后必须取消子项 tap 候选');
  });

  testWidgets('TAP-B8: 滚动容器里的子项——原地轻点仍触发 tap', (tester) async {
    var taps = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(
        ScrollConfiguration(
          behavior: const _NoChromeBehavior(),
          child: SizedBox(
            width: 200,
            height: 300,
            child: ElScroll(
              controller: controller,
              children: List<Widget>.generate(
                40,
                (i) => ElView(
                  key: ValueKey('item-$i'),
                  style: const ElStyle(width: 200, height: 250),
                  event: ElEvent(onTap: (_) => taps++),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('TAP-B9: 长按仍抑制 tap，不因边界口径复燃', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: ElEvent(
            onTap: (_) => taps++,
            onLongPress: (event) {
              longPresses++;
              event.eagerGesture(cancelSelfTap: true);
            },
          ),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveTo(const Offset(40, 40)); // 长按后盒内移动
    await g.up();
    await tester.pump();

    expect(longPresses, 1);
    expect(taps, 0, reason: '长按消费者显式认领后，边界口径不得让 tap 复活');
  });

  testWidgets('TAP-B10: PointerCancel 终局取消，不可复燃', (tester) async {
    var taps = 0;
    var cancels = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: ElEvent(onTap: (_) => taps++, onTapCancel: (_) => cancels++),
        ),
      ),
    );

    final pointer = TestPointer(1, PointerDeviceKind.touch);
    await tester.sendEventToBinding(pointer.down(const Offset(20, 20)));
    await tester.sendEventToBinding(pointer.cancel());
    await tester.pump();

    expect(cancels, 1);
    expect(taps, 0);
  });

  testWidgets('TAP-B17: 越界已取消点击，Flutter 拖拽胜出时只结清一次', (tester) async {
    var tapUps = 0;
    var taps = 0;
    var cancels = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 100, height: 100),
          event: ElEvent(
            config: const ElEventConfig(dragStartDistance: 100),
            onTapUp: (_) => tapUps++,
            onTap: (_) => taps++,
            onTapCancel: (_) => cancels++,
            onDragStart: (event) => event.eagerGesture(cancelSelfTap: true),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture();
    await gesture.down(const Offset(50, 50));
    await gesture.moveTo(const Offset(110, 50));
    await gesture.moveTo(const Offset(170, 50));
    await gesture.up();
    await tester.pump();

    expect(cancels, 1);
    expect(tapUps, 0);
    expect(taps, 0);
  });
}
