import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';
import 'support/event_widget_test_host.dart';

/// 测试自持的按压样式延迟。
///
/// 不使用 [ElEventConfig.delayTouchDown] 的出厂默认值——那是随时会调的手感参数，
/// 拿它当断言基准会让每次调参都变成"测试坏了"。本文件的时序编排一律按这个值写。
const _styleDelay = Duration(milliseconds: 100);

/// 本文件的基准节点配置：显式给出样式延迟，并关掉拖拽重采样。
///
/// 事件配置没有全局入口了，凡是要按 [_styleDelay] 编排的节点都得自己带上。
/// 重采样同理——它的内部默认是 {android}（测试平台即 android），不关掉会在
/// 拖拽激活后插入帧驱动的合成 move，干扰本文件的手工时序编排。
/// （不能写成 const：构造器断言里的 Duration 比较不是常量表达式。）
final _baseConfig = ElEventConfig(delayTouchDown: _styleDelay, delayTouchUp: Duration.zero);

/// 把 [_baseConfig] 垫在节点已声明的 config 之下（声明字段优先）。
ElEvent _withBase(ElEvent event) =>
    event.copyWith(config: (event.config ?? const ElEventConfig()).withFallback(_baseConfig));

void main() {
  setUp(() {
    EventDispatcher.debugResetEagerGestureOwners();
  });

  DispatcherTestHost hostWithDrag({ElEvent? leaf, ElEvent? parent}) {
    final host = DispatcherTestHost.chain(depth: 2);
    addTearDown(host.dispose);
    host.rootDispatcher.event = _withBase(parent ?? ElEvent(onVerticalDragStart: (_) {}));
    host.leafDispatcher.event = _withBase(leaf ?? ElEvent(onTap: (_) {}));
    return host;
  }

  testWidgets('touch 等待配置时长激活样式，原始事件与 TapDown 立即响应', (tester) async {
    final phases = <ElEventPhase>[];
    final styles = <bool>[];
    final host = hostWithDrag(
      leaf: ElEvent(
        onPointerDown: (e) => phases.add(e.phase),
        onTapDown: (e) => phases.add(e.phase),
        onTapUp: (e) => phases.add(e.phase),
        onTap: (e) => phases.add(e.phase),
      ),
    );
    host.leafDispatcher.onTapChanged = styles.add;
    host.dispatch(PointerDownEvent(pointer: 1));
    expect(phases, [ElEventPhase.pointerDown, ElEventPhase.tapDown]);
    expect(styles, isEmpty);
    await tester.pump(_styleDelay - const Duration(milliseconds: 1));
    expect(host.leafDispatcher.isTapPressed, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(styles, [true]);
    host.dispatch(PointerUpEvent(pointer: 1));
    expect(styles, [true, false]);
    expect(phases, [ElEventPhase.pointerDown, ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
  });

  testWidgets('快速点击在抬手时立即触发，之后不会补亮样式', (tester) async {
    var taps = 0;
    final styles = <bool>[];
    final host = hostWithDrag(leaf: ElEvent(onTap: (_) => taps++));
    host.leafDispatcher.onTapChanged = styles.add;
    host.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 30));
    host.dispatch(PointerUpEvent(pointer: 1));
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 150));
    expect(styles, isEmpty);
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus]) {
    testWidgets('$kind 存在拖拽也立即激活样式', (tester) async {
      final host = hostWithDrag();
      host.dispatch(PointerDownEvent(pointer: 1, kind: kind));
      expect(host.leafDispatcher.isTapPressed, isTrue);
      host.dispatch(PointerUpEvent(pointer: 1, kind: kind));
      expect(host.leafDispatcher.isTapPressed, isFalse);
    });
  }

  for (final parent in [
    ElEvent(onPointerMove: (_) {}),
    ElEvent(
      config: ElEventConfig(dragDevices: {PointerDeviceKind.mouse}),
      onDragStart: (_) {},
    ),
  ]) {
    testWidgets('没有可参与的 touch 拖拽时仍遵循显式按下延迟：${parent.config?.dragDevices}', (tester) async {
      final host = hostWithDrag(parent: parent);
      host.dispatch(PointerDownEvent(pointer: 1));
      expect(host.leafDispatcher.isTapPressed, isFalse);
      await tester.pump(_styleDelay);
      expect(host.leafDispatcher.isTapPressed, isTrue);
      host.dispatch(PointerUpEvent(pointer: 1));
    });
  }

  testWidgets('祖先拖拽被截断也不取消节点自己的按下延迟', (tester) async {
    final host = hostWithDrag(
      leaf: ElEvent(onPointerDown: (e) => e.stopPropagation(), onTap: (_) {}),
    );
    host.dispatch(PointerDownEvent(pointer: 1));
    expect(host.leafDispatcher.isTapPressed, isFalse);
    await tester.pump(_styleDelay);
    expect(host.leafDispatcher.isTapPressed, isTrue);
    host.dispatch(PointerUpEvent(pointer: 1));
  });

  for (final (name, drag) in [
    ('候选按下', ElEvent(onDragDown: (_) {})),
    ('自由拖拽', ElEvent(onDragStart: (_) {})),
    ('水平拖拽', ElEvent(onHorizontalDragUpdate: (_) {})),
    ('垂直拖拽', ElEvent(onVerticalDragUpdate: (_) {})),
  ]) {
    testWidgets('本节点$name 同样延迟样式', (tester) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      host.leafDispatcher.event = _withBase(drag).copyWith(onTap: (_) {});
      host.dispatch(PointerDownEvent(pointer: 1));
      expect(host.leafDispatcher.isTapPressed, isFalse);
      await tester.pump(_styleDelay);
      expect(host.leafDispatcher.isTapPressed, isTrue);
      host.dispatch(PointerUpEvent(pointer: 1));
    });
  }

  testWidgets('节点声明时长、零时长关闭以及配置热替换均生效', (tester) async {
    final host = hostWithDrag(
      leaf: ElEvent(
        config: ElEventConfig(delayTouchDown: Duration(milliseconds: 180)),
        onTap: (_) {},
      ),
      parent: ElEvent(
        config: ElEventConfig(delayTouchDown: Duration.zero),
        onDragStart: (_) {},
      ),
    );
    host.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 179));
    expect(host.leafDispatcher.isTapPressed, isFalse, reason: '祖先配置不向后代继承');
    await tester.pump(Duration(milliseconds: 1));
    expect(host.leafDispatcher.isTapPressed, isTrue);
    host.dispatch(PointerUpEvent(pointer: 1));

    host.leafDispatcher.event = ElEvent(
      config: ElEventConfig(delayTouchDown: Duration(milliseconds: 25), delayTouchUp: Duration.zero),
      onTap: (_) {},
    );
    host.dispatch(PointerDownEvent(pointer: 2));
    await tester.pump(Duration(milliseconds: 24));
    expect(host.leafDispatcher.isTapPressed, isFalse);
    await tester.pump(Duration(milliseconds: 1));
    expect(host.leafDispatcher.isTapPressed, isTrue);
    host.dispatch(PointerUpEvent(pointer: 2));

    host.leafDispatcher.event = ElEvent(
      config: ElEventConfig(delayTouchDown: Duration.zero, delayTouchUp: Duration.zero),
      onTap: (_) {},
    );
    host.dispatch(PointerDownEvent(pointer: 3));
    expect(host.leafDispatcher.isTapPressed, isTrue);
    host.dispatch(PointerUpEvent(pointer: 3));
  });

  for (final waitBeforeDrag in [30, 120]) {
    testWidgets('拖拽在 $waitBeforeDrag ms 接管时立即取消等待或已激活样式', (tester) async {
      final phases = <ElEventPhase>[];
      final host = hostWithDrag(
        parent: ElEvent(
          config: ElEventConfig(dragStartDistance: 3),
          onVerticalDragStart: (e) => e.eagerGesture(cancelSelfTap: true),
        ),
        leaf: ElEvent(onTapCancel: (e) => phases.add(e.phase), onTap: (e) => phases.add(e.phase)),
      );
      host.dispatch(PointerDownEvent(pointer: 1));
      await tester.pump(Duration(milliseconds: waitBeforeDrag));
      expect(host.leafDispatcher.isTapPressed, waitBeforeDrag >= _styleDelay.inMilliseconds);
      host.dispatch(PointerMoveEvent(pointer: 1, position: Offset(0, 30), delta: Offset(0, 30)));
      expect(phases, [ElEventPhase.tapCancel]);
      expect(host.leafDispatcher.isTapPressed, isFalse);
      await tester.pump(Duration(milliseconds: 150));
      expect(host.leafDispatcher.isTapPressed, isFalse);
      host.dispatch(PointerUpEvent(pointer: 1, position: Offset(0, 30)));
      expect(phases, [ElEventPhase.tapCancel]);
    });
  }

  // detach(preserveEvent: true) 已不属于"终结清理"：它只让宿主临时离树，手势账
  // 原样保留，因此不在此表内，单独成例见下方"重挂保留…"用例。
  for (final terminal in ['cancel', 'removeEvent', 'disable']) {
    testWidgets('$terminal 清理尚未激活的样式', (tester) async {
      final styles = <bool>[];
      final host = hostWithDrag();
      host.leafDispatcher.onTapChanged = styles.add;
      host.dispatch(PointerDownEvent(pointer: 1));
      await tester.pump(Duration(milliseconds: 30));
      switch (terminal) {
        case 'cancel':
          host.dispatch(PointerCancelEvent(pointer: 1));
        case 'removeEvent':
          host.leafDispatcher.event = null;
        case 'disable':
          host.leafDispatcher.event = host.leafDispatcher.event!.copyWith(disabled: true);
      }
      await tester.pump(Duration(milliseconds: 150));
      expect(styles, isEmpty);
      host.dispatch(PointerUpEvent(pointer: 1));
    });
  }

  testWidgets('重挂保留尚未激活的样式并按原节奏激活', (tester) async {
    final styles = <bool>[];
    final host = hostWithDrag();
    host.leafDispatcher.onTapChanged = styles.add;
    host.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(const Duration(milliseconds: 30));
    host.leafDispatcher.detach(preserveEvent: true);
    await tester.pump(const Duration(milliseconds: 30));
    expect(styles, isEmpty, reason: '重挂不是手势结束，等待中的样式激活必须继续计时');
    await tester.pump(_styleDelay);
    expect(styles, [true], reason: '重挂保留手势账，但不改变激活节奏');
    host.dispatch(PointerUpEvent(pointer: 1));
  });

  testWidgets('移出取消等待，重新进入时事件立即响应且样式重新等待', (tester) async {
    final phases = <ElEventPhase>[];
    final host = hostWithDrag(
      leaf: ElEvent(onTapDown: (e) => phases.add(e.phase), onTapCancel: (e) => phases.add(e.phase)),
    );
    host.leafDispatcher.hitBoundsContainsGlobal = (position) => position.dx < 50;
    host.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 50));
    host.dispatch(PointerMoveEvent(pointer: 1, position: Offset(60, 0), delta: Offset(60, 0)));
    await tester.pump(Duration(milliseconds: 100));
    expect(host.leafDispatcher.isTapPressed, isFalse);
    host.dispatch(PointerMoveEvent(pointer: 1, position: Offset.zero, delta: Offset(-60, 0)));
    expect(phases, [ElEventPhase.tapDown, ElEventPhase.tapCancel, ElEventPhase.tapDown]);
    await tester.pump(_styleDelay - const Duration(milliseconds: 1));
    expect(host.leafDispatcher.isTapPressed, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(host.leafDispatcher.isTapPressed, isTrue);
    host.dispatch(PointerUpEvent(pointer: 1));
  });

  testWidgets('只修改样式延迟不会打断已开始的长按计时', (tester) async {
    var longPresses = 0;
    final event = ElEvent(
      config: ElEventConfig(longPressDelay: Duration(milliseconds: 80)),
      onLongPress: (_) => longPresses++,
    );
    final host = hostWithDrag(leaf: event);
    host.dispatch(PointerDownEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 40));
    host.leafDispatcher.event = event.copyWith(
      config: event.config!.copyWith(delayTouchDown: Duration(milliseconds: 200)),
    );
    await tester.pump(Duration(milliseconds: 40));
    expect(longPresses, 1);
    host.dispatch(PointerUpEvent(pointer: 1));
    await tester.pump(Duration(milliseconds: 200));
    expect(host.leafDispatcher.isTapPressed, isFalse);
  });

  testWidgets('ElScrollView 内纯样式节点延迟变色，实际滚动会取消反馈', (tester) async {
    final key = UniqueKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpEventView(
      tester,
      ElView(
        style: ElStyle(width: 200, height: 200),
        child: ElScrollView(
          controller: controller,
          scrollbar: ElAndroidScrollBar(),
          children: [
            ElView(
              key: key,
              // 事件配置没有全局入口了：真实组件树里的节点不经过 [hostWithDrag]
              // 垫底，本文件按 [_styleDelay] 编排的时序必须就地声明。
              event: ElEvent(config: ElEventConfig(delayTouchDown: _styleDelay)),
              style: ElStyle(
                width: 200,
                height: 600,
                backgroundColor: Color(0xFF00FF00),
                onTap: ElStyle(backgroundColor: Color(0xFFFF0000)),
              ),
            ),
          ],
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final gesture = await tester.startGesture(Offset(50, 100));
    await tester.pump(_styleDelay - const Duration(milliseconds: 1));
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xFF00FF00));
    await tester.pump(const Duration(milliseconds: 1));
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xFFFF0000));
    await gesture.moveBy(Offset(0, -60));
    await gesture.moveBy(Offset(0, -30));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xFF00FF00));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });
}
