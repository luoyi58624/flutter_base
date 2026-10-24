import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/src/ui/cores/event/dispatcher.dart';
import 'package:flutter_base/src/ui/cores/event/event.dart';
import 'package:flutter_base/src/ui/cores/view/render/index.dart';
import 'package:flutter_base/src/ui/cores/view/style/index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('分发器通过 Render 几何换算原始事件并恢复移回反馈', (_) async {
    final feedback = <bool>[];
    final moves = <(Offset, Offset, Offset, Object?)>[];
    var taps = 0;
    final render = _GeometryTestRender(
      bounds: Rect.fromLTWH(100, 200, 80, 80),
      origin: Offset(100, 200),
      scale: 2,
      onTapChanged: feedback.add,
      event: ElEvent(
        onPointerMove: (event) => moves.add((
          event.globalPosition,
          event.localPosition,
          event.localDelta,
          event.originalEvent,
        )),
        onTap: (_) => taps++,
      ),
    );
    addTearDown(render.dispose);
    final dispatcher = render.eventDispatcher!;
    final path = [render];
    await _dispatch(
      path,
      PointerDownEvent(pointer: 1, kind: .mouse, position: Offset(120, 220)),
    );
    expect(feedback, [true]);

    final outside = PointerMoveEvent(
      pointer: 1,
      kind: .mouse,
      position: Offset(182, 220),
      delta: Offset(62, 0),
      buttons: kPrimaryButton,
    );
    await _dispatch(path, outside);
    expect(dispatcher.isTapPressed, isFalse);
    expect(moves.single, (
      Offset(182, 220),
      Offset(41, 10),
      Offset(31, 0),
      outside,
    ));

    await _dispatch(
      path,
      PointerMoveEvent(
        pointer: 1,
        kind: .mouse,
        position: Offset(130, 230),
        delta: Offset(-52, 10),
        buttons: kPrimaryButton,
      ),
    );
    expect(dispatcher.isTapPressed, isTrue);
    await _dispatch(
      path,
      PointerUpEvent(pointer: 1, kind: .mouse, position: Offset(130, 230)),
    );
    expect(feedback, [true, false, true, false]);
    expect(taps, 1);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets('实际 Render 父链按各级几何冒泡并保留停止传播语义', (_) async {
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
    final parent = _GeometryTestRender(
      origin: Offset(10, 10),
      event: handlers('parent'),
    );
    final child = _GeometryTestRender(
      origin: Offset(20, 20),
      event: handlers('child'),
    );
    parent.child = child;
    final owner = PipelineOwner()..rootNode = parent;
    addTearDown(() {
      child.dispose();
      parent.dispose();
      owner.rootNode = null;
    });
    final path = [child, parent];
    final transforms = [
      Matrix4.translationValues(-20, -20, 0),
      Matrix4.translationValues(-10, -10, 0),
    ];
    Future<void> dispatch(PointerEvent event) =>
        _dispatch(path, event, transforms: transforms);
    final position = Offset(40, 40);
    await dispatch(
      PointerDownEvent(pointer: 2, kind: .mouse, position: position),
    );
    await dispatch(
      PointerUpEvent(pointer: 2, kind: .mouse, position: position),
    );
    expect(calls, [
      ('child', ElEventPhase.pointerDown, Offset(20, 20)),
      ('parent', ElEventPhase.pointerDown, Offset(30, 30)),
      ('child', ElEventPhase.tap, Offset(20, 20)),
      ('parent', ElEventPhase.tap, Offset(30, 30)),
    ]);

    stopTap = true;
    calls.clear();
    await dispatch(
      PointerDownEvent(pointer: 3, kind: .mouse, position: position),
    );
    await dispatch(
      PointerUpEvent(pointer: 3, kind: .mouse, position: position),
    );
    expect(calls, [
      ('child', ElEventPhase.pointerDown, Offset(20, 20)),
      ('parent', ElEventPhase.pointerDown, Offset(30, 30)),
      ('child', ElEventPhase.tap, Offset(20, 20)),
    ]);
    expect(child.eventDispatcher!.activePointerCount, 0);
    expect(parent.eventDispatcher!.activePointerCount, 0);
  });

  testWidgets('主动取消的业务回调内销毁不会重复取消或遗留反馈', (_) async {
    final feedback = <bool>[];
    var cancels = 0;
    var taps = 0;
    late final ElEventDispatcher dispatcher;
    final render = ElRenderView(
      ElStyle(),
      TextDirection.ltr,
      onTapChanged: feedback.add,
      event: ElEvent(
        onPointerCancel: (_) {
          cancels++;
          dispatcher.dispose();
        },
        onTap: (_) => taps++,
      ),
    );
    dispatcher = render.eventDispatcher!;
    addTearDown(render.dispose);
    await _dispatch([render], PointerDownEvent(pointer: 4, kind: .mouse));
    expect(dispatcher.activePointerCount, 1);
    dispatcher.cancelAllPending();
    await _dispatch([render], PointerUpEvent(pointer: 4, kind: .mouse));
    dispatcher.dispose();
    expect(cancels, 1);
    expect(taps, 0);
    expect(feedback, [true, false]);
    expect(dispatcher.isDisposed, isTrue);
    expect(dispatcher.isTapPressed, isFalse);
    expect(dispatcher.activePointerCount, 0);
  });

  testWidgets('延迟单击不延长物理按压反馈或指针生命周期', (tester) async {
    final phases = <ElEventPhase>[];
    final feedback = <bool>[];
    void record(ElEventCallback event) => phases.add(event.phase);
    final render = ElRenderView(
      ElStyle(),
      TextDirection.ltr,
      onTapChanged: feedback.add,
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
    );
    final dispatcher = render.eventDispatcher!;
    addTearDown(render.dispose);
    await _dispatch([render], PointerDownEvent(pointer: 5));
    await tester.pump(Duration(milliseconds: 20));
    await _dispatch([
      render,
    ], PointerUpEvent(pointer: 5, timeStamp: Duration(milliseconds: 20)));
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
}

/// 路径按叶到根排列，完整投递后再推进官方路由与竞技场。
Future<void> _dispatch(
  List<ElRenderView> path,
  PointerEvent event, {
  List<Matrix4>? transforms,
}) async {
  for (var index = 0; index < path.length; index++) {
    final transformed = event.transformed(transforms?[index]);
    path[index].handleEvent(
      transformed,
      BoxHitTestEntry(path[index], transformed.localPosition),
    );
  }
  GestureBinding.instance.pointerRouter.route(event);
  if (event is PointerDownEvent || event is PointerPanZoomStartEvent) {
    GestureBinding.instance.gestureArena.close(event.pointer);
  } else if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
    GestureBinding.instance.gestureArena.sweep(event.pointer);
  }
}

/// 固定各级宿主的几何，单独验证分发器读取正确宿主而非复用子级坐标。
final class _GeometryTestRender extends ElRenderView {
  _GeometryTestRender({
    required ElEvent event,
    this.origin = Offset.zero,
    this.scale = 1,
    this.bounds,
    super.onTapChanged,
  }) : super(ElStyle(), TextDirection.ltr, event: event);

  final Offset origin;
  final double scale;
  final Rect? bounds;

  @override
  bool eventContains(Offset position) => bounds?.contains(position) ?? true;

  @override
  Offset eventLocalPosition(Offset position) => (position - origin) / scale;
}
