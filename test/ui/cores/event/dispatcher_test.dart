import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/cores/event/index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('普通 Render 默认几何正确处理变换、越界与移回反馈', (tester) async {
    final feedback = <bool>[];
    final moves = <(Offset, Offset, Offset)>[];
    var taps = 0;
    final key = GlobalKey();
    await tester.pumpWidget(
      _shell(
        Padding(
          padding: EdgeInsets.only(left: 100, top: 200),
          child: Transform.scale(
            scale: 2,
            alignment: .topLeft,
            child: _EventBox(
              key: key,
              event: ElEvent(
                onPointerMove: (event) => moves.add((
                  event.globalPosition,
                  event.localPosition,
                  event.localDelta,
                )),
                onTap: (_) => taps++,
              ),
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      ),
    );
    final dispatcher = _dispatcher(key)..onTapChanged = feedback.add;
    final pointer = await tester.startGesture(Offset(120, 220), kind: .mouse);
    expect(feedback, [true]);
    await pointer.moveTo(Offset(182, 220));
    expect(dispatcher.isTapPressed, isFalse);
    expect(moves.single, (Offset(182, 220), Offset(41, 10), Offset(31, 0)));
    await pointer.moveTo(Offset(130, 230));
    expect(dispatcher.isTapPressed, isTrue);
    await pointer.up();
    expect(feedback, [true, false, true, false]);
    expect(taps, 1);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets('不同 Render 基类通过真实父链冒泡并独立换算坐标', (tester) async {
    final calls = <(String, ElEventPhase, Offset)>[];
    var stopTap = false;
    ElEvent handlers(String name) => ElEvent(
      onPointerDown: (event) =>
          calls.add((name, event.phase, event.localPosition)),
      onTap: (event) {
        calls.add((name, event.phase, event.localPosition));
        if (name == 'child' && stopTap) event.stopPropagation();
      },
    );
    final parentKey = GlobalKey();
    final childKey = GlobalKey();
    await tester.pumpWidget(
      _shell(
        Padding(
          padding: EdgeInsets.all(10),
          child: _EventBox(
            key: parentKey,
            constrained: true,
            event: handlers('parent'),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: _EventBox(key: childKey, event: handlers('child')),
            ),
          ),
        ),
      ),
    );
    expect(
      parentKey.currentContext!.findRenderObject(),
      isA<_ConstrainedEventRender>(),
    );
    expect(
      childKey.currentContext!.findRenderObject(),
      isA<_ProxyEventRender>(),
    );
    await tester.tapAt(Offset(40, 40));
    expect(calls, [
      ('child', ElEventPhase.pointerDown, Offset(20, 20)),
      ('parent', ElEventPhase.pointerDown, Offset(30, 30)),
      ('child', ElEventPhase.tap, Offset(20, 20)),
      ('parent', ElEventPhase.tap, Offset(30, 30)),
    ]);
    stopTap = true;
    calls.clear();
    await tester.tapAt(Offset(40, 40));
    expect(calls, [
      ('child', ElEventPhase.pointerDown, Offset(20, 20)),
      ('parent', ElEventPhase.pointerDown, Offset(30, 30)),
      ('child', ElEventPhase.tap, Offset(20, 20)),
    ]);
    expect(_dispatcher(childKey).activePointerCount, 0);
    expect(_dispatcher(parentKey).activePointerCount, 0);
  });

  testWidgets('默认反馈无需监听器，取消回调重入销毁只结清一次并清除注册', (tester) async {
    var cancels = 0;
    var taps = 0;
    late ElEventDispatcher dispatcher;
    final key = GlobalKey();
    await tester.pumpWidget(
      _shell(
        _EventBox(
          key: key,
          event: ElEvent(
            onPointerCancel: (_) {
              cancels++;
              dispatcher.dispose();
            },
            onTap: (_) => taps++,
          ),
        ),
      ),
    );
    final render = key.currentContext!.findRenderObject()!;
    dispatcher = _dispatcher(key);
    final pointer = await tester.startGesture(Offset(20, 20), kind: .mouse);
    expect(dispatcher.isTapPressed, isTrue);
    expect(dispatcher.activePointerCount, 1);
    dispatcher.cancelAllPending();
    await pointer.up();
    dispatcher.dispose();
    expect(cancels, 1);
    expect(taps, 0);
    expect(dispatcher.isDisposed, isTrue);
    expect(dispatcher.isTapPressed, isFalse);
    expect(dispatcher.activePointerCount, 0);
    expect(ElEventDispatcher.of(render), isNull);
    await tester.pumpWidget(SizedBox());
    expect(render.debugDisposed, isTrue);
  });

  testWidgets('延迟单击不延长物理按压反馈或指针生命周期', (tester) async {
    final phases = <ElEventPhase>[];
    final feedback = <bool>[];
    void record(ElEventCallback event) => phases.add(event.phase);
    final key = GlobalKey();
    await tester.pumpWidget(
      _shell(
        _EventBox(
          key: key,
          event: ElEvent(
            config: ElEventConfig(
              deferTap: true,
              doubleTapInterval: Duration(milliseconds: 300),
              delayTouchUp: Duration(milliseconds: 100),
            ),
            onTapUp: record,
            onTap: record,
            onDoubleTap: record,
          ),
        ),
      ),
    );
    final dispatcher = _dispatcher(key)..onTapChanged = feedback.add;
    final pointer = await tester.startGesture(Offset(20, 20));
    await tester.pump(Duration(milliseconds: 20));
    await pointer.up();
    expect(phases, [ElEventPhase.tapUp]);
    expect(dispatcher.activePointerCount, 0);
    expect(dispatcher.isTapPressed, isTrue);
    await tester.pump(Duration(milliseconds: 100));
    expect(feedback, [true, false]);
    expect(phases, [ElEventPhase.tapUp]);
    await tester.pump(Duration(milliseconds: 220));
    expect(phases, [ElEventPhase.tapUp, ElEventPhase.tap]);
    expect(feedback, [true, false]);
  });

  testWidgets('普通 Render 接入真实 MouseTracker 后具有悬停、光标与禁用状态', (tester) async {
    final phases = <ElEventPhase>[];
    void record(ElEventCallback event) => phases.add(event.phase);
    final key = GlobalKey();
    await tester.pumpWidget(
      _shell(
        _EventBox(
          key: key,
          event: ElEvent(
            cursor: SystemMouseCursors.click,
            onPointerEnter: record,
            onPointerHover: record,
            onPointerExit: record,
          ),
        ),
      ),
    );
    final dispatcher = _dispatcher(key);
    final mouse = await tester.createGesture(kind: .mouse, pointer: 30);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset(20, 20));
    await tester.pump();
    expect(dispatcher.isHovered, isTrue);
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    await mouse.moveTo(Offset(30, 20));
    await mouse.moveTo(Offset(120, 20));
    expect(dispatcher.isHovered, isFalse);
    expect(phases, [
      ElEventPhase.pointerEnter,
      ElEventPhase.pointerHover,
      ElEventPhase.pointerExit,
    ]);
    await mouse.moveTo(Offset(20, 20));
    dispatcher.event = dispatcher.event!.copyWith(disabled: true);
    expect(dispatcher.isHovered, isTrue);
    expect(dispatcher.cursor, SystemMouseCursors.forbidden);
    await mouse.moveTo(Offset(30, 20));
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.forbidden,
    );
  });

  testWidgets('禁用不同类型的祖先取消后代活动输入和已释放的延迟点击', (tester) async {
    final parentKey = GlobalKey();
    final childKey = GlobalKey();
    var cancels = 0;
    var taps = 0;
    final parentEvent = ElEvent();
    await tester.pumpWidget(
      _shell(
        _EventBox(
          key: parentKey,
          event: parentEvent,
          constrained: true,
          child: _EventBox(
            key: childKey,
            event: ElEvent(
              config: ElEventConfig(
                deferTap: true,
                doubleTapInterval: Duration(milliseconds: 40),
              ),
              onPointerCancel: (_) => cancels++,
              onTap: (_) => taps++,
              onDoubleTap: (_) {},
            ),
          ),
        ),
      ),
    );
    final parent = _dispatcher(parentKey);
    final child = _dispatcher(childKey);
    final pointer = await tester.startGesture(Offset(20, 20), kind: .mouse);
    parent.event = parentEvent.copyWith(disabled: true);
    expect(child.activePointerCount, 0);
    expect(child.isTapPressed, isFalse);
    expect(cancels, 1);
    await pointer.up();
    parent.event = parentEvent;
    await tester.tapAt(Offset(20, 20));
    expect(child.activePointerCount, 0);
    expect(taps, 0);
    parent.event = parentEvent.copyWith(disabled: true);
    await tester.pump(Duration(milliseconds: 80));
    expect(taps, 0);
    parent.event = parentEvent;
    await tester.tapAt(Offset(20, 20));
    await tester.pump(Duration(milliseconds: 80));
    expect(taps, 1);
  });

  testWidgets('两参数独立宿主直接识别触控板平移、缩放和旋转', (tester) async {
    final phases = <ElEventPhase>[];
    final scales = <double>[];
    final rotations = <double>[];
    void record(ElEventCallback event) => phases.add(event.phase);
    final key = GlobalKey();
    await tester.pumpWidget(
      _shell(
        _EventBox(
          key: key,
          constrained: true,
          event: ElEvent(
            onPointerPanZoomStart: record,
            onPointerPanZoomUpdate: record,
            onPointerPanZoomEnd: record,
            onScaleStart: record,
            onScaleUpdate: (event) => scales.add(event.scale),
            onScaleEnd: record,
            onRotationUpdate: (event) => rotations.add(event.rotation),
          ),
        ),
      ),
    );
    final pointer = TestPointer(40, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(Offset(20, 20)));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(Offset(20, 20), pan: Offset(10, 0), scale: 1.2),
    );
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(
        Offset(20, 20),
        pan: Offset(20, 0),
        scale: 1.5,
        rotation: 0.2,
      ),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());
    expect(
      phases,
      containsAllInOrder([
        ElEventPhase.pointerPanZoomStart,
        ElEventPhase.pointerPanZoomUpdate,
        ElEventPhase.scaleStart,
        ElEventPhase.pointerPanZoomUpdate,
        ElEventPhase.pointerPanZoomEnd,
        ElEventPhase.scaleEnd,
      ]),
    );
    expect(scales.single, closeTo(1.5 / 1.2, 0.0001));
    expect(rotations.single, closeTo(0.2, 0.0001));
    expect(_dispatcher(key).activePointerCount, 0);
  });

  testWidgets('已挂载外层新增分发器时内层停止传播仍截断完整祖先链', (tester) async {
    final calls = <String>[];
    final outerKey = GlobalKey();
    await tester.pumpWidget(
      _shell(
        _LateEventBox(
          key: outerKey,
          child: _EventBox(
            constrained: true,
            event: ElEvent(onTap: (_) => calls.add('middle')),
            child: _EventBox(
              event: ElEvent(
                onTap: (event) {
                  calls.add('inner');
                  event.stopPropagation();
                },
              ),
            ),
          ),
        ),
      ),
    );
    final outer =
        outerKey.currentContext!.findRenderObject()! as _LateEventRender;
    expect(ElEventDispatcher.of(outer), isNull);
    outer.dispatcher = ElEventDispatcher(
      outer,
      ElEvent(onTap: (_) => calls.add('outer')),
    );
    outer.dispatcher!.attach();
    await tester.tapAt(Offset(20, 20));
    expect(calls, ['inner']);
    await tester.pumpWidget(SizedBox());
    expect(ElEventDispatcher.of(outer), isNull);
  });

  testWidgets('取消后代回调重入启用父级时旧遍历不取消后来启动的兄弟输入', (tester) async {
    final parentKey = GlobalKey();
    final laterKey = GlobalKey();
    late ElEventDispatcher parent;
    var laterCancels = 0;
    var laterTaps = 0;
    await tester.pumpWidget(
      _shell(
        _EventBox(
          key: parentKey,
          constrained: true,
          event: ElEvent(),
          child: Row(
            children: [
              _EventBox(
                event: ElEvent(
                  onPointerCancel: (_) {
                    parent.event = ElEvent();
                    GestureBinding.instance.handlePointerEvent(
                      PointerDownEvent(
                        pointer: 72,
                        kind: .mouse,
                        position: Offset(75, 20),
                      ),
                    );
                  },
                ),
                child: SizedBox(width: 50, height: 100),
              ),
              _EventBox(
                key: laterKey,
                event: ElEvent(
                  onPointerCancel: (_) => laterCancels++,
                  onTap: (_) => laterTaps++,
                ),
                child: SizedBox(width: 50, height: 100),
              ),
            ],
          ),
        ),
      ),
    );
    parent = _dispatcher(parentKey);
    final first = await tester.startGesture(
      Offset(25, 20),
      pointer: 71,
      kind: .mouse,
    );
    parent.event = ElEvent(disabled: true);
    expect(parent.disabled, isFalse);
    expect(_dispatcher(laterKey).activePointerCount, 1);
    expect(laterCancels, 0);
    await tester.sendEventToBinding(
      PointerUpEvent(pointer: 72, kind: .mouse, position: Offset(75, 20)),
    );
    await first.up();
    expect(laterTaps, 1);
    expect(laterCancels, 0);
  });

  testWidgets('帧结束修改命中行为会安排下一帧更新静止鼠标', (tester) async {
    final key = GlobalKey();
    var exits = 0;
    await tester.pumpWidget(
      _shell(
        _EventBox(
          key: key,
          event: ElEvent(
            cursor: SystemMouseCursors.click,
            onPointerExit: (_) => exits++,
          ),
        ),
      ),
    );
    final dispatcher = _dispatcher(key);
    final mouse = await tester.createGesture(kind: .mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset(20, 20));
    await tester.pump();
    expect(dispatcher.isHovered, isTrue);
    tester.binding.addPostFrameCallback((_) {
      dispatcher.event = dispatcher.event!.copyWith(
        behavior: HitTestBehavior.deferToChild,
      );
    });
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump();
    expect(dispatcher.isHovered, isFalse);
    expect(exits, 1);
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.basic,
    );
  });

  testWidgets('非 RenderBox 的 Sliver 使用默认坐标与命中范围获得点击能力', (tester) async {
    final positions = <Offset>[];
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 60)),
            _EventSliver(
              key: key,
              event: ElEvent(
                onTap: (event) => positions.add(event.localPosition),
              ),
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
    final render = key.currentContext!.findRenderObject()!;
    expect(render, isA<RenderSliver>());
    final dispatcher = _dispatcher(key);
    final pointer = await tester.startGesture(Offset(20, 80), kind: .mouse);
    expect(dispatcher.isTapPressed, isTrue);
    await pointer.moveTo(Offset(20, 170));
    expect(dispatcher.isTapPressed, isFalse);
    await pointer.moveTo(Offset(20, 90));
    expect(dispatcher.isTapPressed, isTrue);
    await pointer.up();
    expect(positions, [Offset(20, 30)]);
    expect(dispatcher.activePointerCount, 0);
    await tester.pumpWidget(SizedBox());
    expect(dispatcher.isDisposed, isTrue);
    expect(ElEventDispatcher.of(render), isNull);
  });
}

Widget _shell(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(alignment: .topLeft, child: child),
);

ElEventDispatcher _dispatcher(GlobalKey key) =>
    ElEventDispatcher.of(key.currentContext!.findRenderObject()!)!;

// 测试宿主仅接线 Flutter 的输入与生命周期，不提供事件算法或自定义几何。
mixin _EventConnection on RenderObject implements MouseTrackerAnnotation {
  late final ElEventDispatcher dispatcher;

  void connect(ElEvent event) => dispatcher = ElEventDispatcher(this, event);

  @override
  MouseCursor get cursor => dispatcher.cursor;

  @override
  bool get validForMouseTracker => attached && !dispatcher.isDisposed;

  @override
  PointerEnterEventListener get onEnter => dispatcher.handlePointerEnter;

  @override
  PointerExitEventListener get onExit => dispatcher.handlePointerExit;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) =>
      dispatcher.handleEvent(event);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    dispatcher.attach();
  }

  @override
  void dispose() {
    dispatcher.dispose();
    super.dispose();
  }
}

mixin _BoxHitTest on RenderBox, _EventConnection {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    if (dispatcher.disabled) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    final behavior = dispatcher.event!.behavior;
    final hit =
        hitTestChildren(result, position: position) ||
        behavior == HitTestBehavior.opaque;
    if (hit || behavior == HitTestBehavior.translucent) {
      result.add(BoxHitTestEntry(this, position));
    }
    return hit;
  }
}

final class _ProxyEventRender extends RenderProxyBoxWithHitTestBehavior
    with _EventConnection, _BoxHitTest {
  _ProxyEventRender(ElEvent event) {
    connect(event);
  }
}

final class _ConstrainedEventRender extends RenderConstrainedBox
    with _EventConnection, _BoxHitTest {
  _ConstrainedEventRender(ElEvent event)
    : super(
        additionalConstraints: BoxConstraints.tightFor(width: 100, height: 100),
      ) {
    connect(event);
  }
}

final class _EventBox extends SingleChildRenderObjectWidget {
  _EventBox({
    super.key,
    required this.event,
    this.constrained = false,
    Widget? child,
  }) : super(child: child ?? SizedBox(width: 100, height: 100));

  final ElEvent event;
  final bool constrained;

  @override
  RenderBox createRenderObject(BuildContext context) =>
      constrained ? _ConstrainedEventRender(event) : _ProxyEventRender(event);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBox renderObject,
  ) {
    (renderObject as _EventConnection).dispatcher.event = event;
  }
}

final class _SliverEventRender extends RenderSliverToBoxAdapter
    with _EventConnection {
  _SliverEventRender(ElEvent event) {
    connect(event);
  }

  @override
  bool hitTestSelf({
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) => true;
}

final class _EventSliver extends SingleChildRenderObjectWidget {
  const _EventSliver({super.key, required this.event, super.child});

  final ElEvent event;

  @override
  RenderSliver createRenderObject(BuildContext context) =>
      _SliverEventRender(event);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SliverEventRender renderObject,
  ) {
    renderObject.dispatcher.event = event;
  }
}

final class _LateEventRender extends RenderProxyBoxWithHitTestBehavior {
  _LateEventRender() : super(behavior: HitTestBehavior.opaque);

  ElEventDispatcher? dispatcher;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) =>
      dispatcher?.handleEvent(event);

  @override
  void dispose() {
    dispatcher?.dispose();
    super.dispose();
  }
}

final class _LateEventBox extends SingleChildRenderObjectWidget {
  const _LateEventBox({super.key, super.child});

  @override
  RenderBox createRenderObject(BuildContext context) => _LateEventRender();
}
