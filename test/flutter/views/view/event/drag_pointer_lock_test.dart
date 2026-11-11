// 普通拖拽期间 MouseTracker 继续处理悬停，全局指针锁由组件显式开启。
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(() {
    EventDispatcher.debugResetEagerGestureOwners();
    DragPointerLock.debugReset();
  });
  tearDown(DragPointerLock.debugReset);

  Widget shell(Widget child) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );
  }

  testWidgets('LOCK-0: stop-only mouse Drag 不锁且真实 hover 可移出移入', (tester) async {
    const leftKey = ValueKey('passive-drag-source');
    const rightKey = ValueKey('passive-hover-target');
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 400, height: 200),
          child: [
            ElView(
              key: leftKey,
              style: const ElStyle(width: 200, height: 200, onHover: ElStyle(backgroundColor: Color(0xFF654321))),
              event: ElEvent(
                config: const ElEventConfig(dragStartDistance: 6.0),
                onDragStart: (event) => event.stopPropagation(),
                onDragUpdate: (_) {},
              ),
            ),
            ElView(
              key: rightKey,
              style: const ElStyle(width: 200, height: 200, onHover: ElStyle(backgroundColor: Color(0xFF123456))),
            ),
          ],
        ),
      ),
    );
    final leftRender = tester.renderObject<ElRenderView>(find.byKey(leftKey));
    final rightRender = tester.renderObject<ElRenderView>(find.byKey(rightKey));
    const leftCenter = Offset(100, 100);
    const rightCenter = Offset(300, 100);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: leftCenter);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.down(leftCenter);
    await mouse.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(DragPointerLock.isActive, isFalse, reason: 'stopPropagation 只裁剪路由，不取得 pointer ownership。');

    await mouse.moveTo(rightCenter);
    await tester.pump();
    expect(leftRender.internalStateHas(ViewState.hover), isFalse);
    expect(rightRender.internalStateHas(ViewState.hover), isTrue);

    await mouse.moveTo(leftCenter);
    await tester.pump();
    expect(leftRender.internalStateHas(ViewState.hover), isTrue);
    expect(rightRender.internalStateHas(ViewState.hover), isFalse);
    await mouse.up();
  });

  testWidgets('LOCK-1: 鼠标拖拽调用旧 eagerGesture 时，悬停与其他指针照常派发', (tester) async {
    const leftKey = ValueKey('lock-drag-source');
    const rightKey = ValueKey('lock-hover-target');
    var rightTaps = 0;
    var rightEnters = 0;
    var rightExits = 0;
    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 400, height: 200),
          child: [
            ElView(
              key: leftKey,
              style: const ElStyle(width: 200, height: 200),
              event: ElEvent(
                config: const ElEventConfig(dragStartDistance: 6.0),
                onDragStart: (event) => event.eagerGesture(cancelSelfTap: true),
                onDragUpdate: (_) {},
              ),
            ),
            ElView(
              key: rightKey,
              style: const ElStyle(width: 200, height: 200, onHover: ElStyle(backgroundColor: Color(0xFF123456))),
              event: ElEvent(
                onPointerEnter: (_) => rightEnters++,
                onPointerExit: (_) => rightExits++,
                onTap: (_) => rightTaps++,
              ),
            ),
          ],
        ),
      ),
    );
    final rightRender = tester.renderObject<ElRenderView>(find.byKey(rightKey));
    const leftCenter = Offset(100, 100);
    const rightCenter = Offset(300, 100);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    // 对照组：无拖拽时 hover 探针工作正常。
    await mouse.moveTo(rightCenter);
    await tester.pump();
    expect(rightRender.internalStateHas(ViewState.hover), isTrue, reason: '探针自证：hover 正常可翻转');

    // 移到左侧按下并越过起拖阈值。
    await mouse.moveTo(leftCenter);
    await tester.pump();
    await mouse.down(leftCenter);
    await tester.pump();
    await mouse.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(DragPointerLock.isActive, isFalse);

    // 按住拖过右侧：MouseTracker 仍按当前位置产生 enter 与 hover 样式。
    await mouse.moveTo(rightCenter);
    await tester.pump();
    expect(rightEnters, 2, reason: '对照阶段进入一次，eager 拖拽中再次进入一次');
    expect(rightRender.internalStateHas(ViewState.hover), isTrue, reason: 'eager 拖拽不得破坏真实 hover');

    await mouse.moveTo(leftCenter);
    await tester.pump();
    expect(rightExits, 2, reason: '对照阶段退出一次，eager 拖拽中再次退出一次');
    expect(rightRender.internalStateHas(ViewState.hover), isFalse);

    await mouse.moveTo(rightCenter);
    await tester.pump();
    expect(rightEnters, 3);
    expect(rightRender.internalStateHas(ViewState.hover), isTrue);

    // 新触点继续走自己的命中路径。
    final touch = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 77);
    await touch.down(rightCenter);
    await touch.up();
    await tester.pump();
    expect(rightTaps, 1);

    // 松手不需要补算，hover 从拖拽期间起就保持真实。
    await mouse.up();
    await tester.pump();
    expect(DragPointerLock.isActive, isFalse);
    expect(rightRender.internalStateHas(ViewState.hover), isTrue);
  });

  testWidgets('LOCK-2: touch 拖拽不上锁', (tester) async {
    const key = ValueKey('touch-drag');
    await tester.pumpWidget(
      shell(
        ElView(
          key: key,
          style: const ElStyle(width: 200, height: 200),
          event: ElEvent(
            config: const ElEventConfig(dragStartDistance: 6.0),
            onDragStart: (event) => event.eagerGesture(cancelSelfTap: true),
            onDragUpdate: (_) {},
          ),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(100, 100));
    await g.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(DragPointerLock.isActive, isFalse, reason: 'touch 无光标/hover 语义,多指交互不得被屏蔽');
    await g.up();
    await tester.pump();
  });

  testWidgets('LOCK-3: eager 拖拽取消与 dispatcher 销毁均不会建立全局锁', (tester) async {
    const key = ValueKey('cancel-drag');
    await tester.pumpWidget(
      shell(
        ElView(
          key: key,
          style: const ElStyle(width: 200, height: 200),
          event: ElEvent(
            config: const ElEventConfig(dragStartDistance: 6.0),
            onDragStart: (event) => event.eagerGesture(cancelSelfTap: true),
            onDragUpdate: (_) {},
            onDragCancel: (_) {},
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.down(const Offset(100, 100));
    await mouse.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(DragPointerLock.isActive, isFalse);

    await mouse.cancel();
    await tester.pump();
    expect(DragPointerLock.isActive, isFalse);

    await mouse.down(const Offset(100, 100));
    await mouse.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(DragPointerLock.isActive, isFalse);

    await tester.pumpWidget(shell(const SizedBox()));
    expect(DragPointerLock.isActive, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
