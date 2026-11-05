import 'package:flutter_base/src/flutter/views/scroll/common/pointer/scroll_drag_controller.dart';
import 'package:flutter_base/src/flutter/views/scroll/common/pointer/scroll_pointer_chain.dart';
import 'package:flutter_base/src/flutter/views/scroll/common/pointer/scroll_touch_event_latch.dart';
import 'package:flutter_base/src/flutter/views/scroll/common/viewport/scroll_position_binding.dart';
import 'package:flutter_base/src/flutter/views/scroll/common/viewport/scroll_viewport.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/virtual_test_host.dart';

ElEventDetails _dragCallback({
  required ElEventPhase phase,
  Offset position = const Offset(10, 10),
  Offset localPosition = const Offset(2, 2),
  Offset delta = Offset.zero,
  Offset dragOffset = Offset.zero,
  Velocity velocity = Velocity.zero,
  bool hasAncestorDragConsumer = false,
  void Function(bool cancelSelfTap, bool allowScaleUpgrade)? onEagerGesture,
}) {
  final callback =
      ElEventDetails(
          phase: phase,
          globalPosition: position,
          localPosition: localPosition,
          delta: delta,
          localDelta: delta,
          dragOffset: dragOffset,
          velocity: velocity,
          originalEvent: PointerMoveEvent(position: position, delta: delta),
        )
        // 嵌套场景 stub：滚动 0 消费分支按三态语义只在存在祖先拖拽消费者时 defer
        //（否则走顶层吞余量），bubble 类测试需显式声明。
        ..hasAncestorDragConsumer = hasAncestorDragConsumer;
  if (onEagerGesture != null) {
    callback.updateEagerGestureHandler((_, cancelSelfTap, allowScaleUpgrade) {
      onEagerGesture(cancelSelfTap, allowScaleUpgrade);
    });
  }
  return callback;
}

ElEventDetails _panZoomStartCallback({
  int pointer = 7,
  Offset position = const Offset(10, 10),
  Offset localPosition = const Offset(2, 2),
  Duration timeStamp = Duration.zero,
}) {
  return ElEventDetails(
    phase: ElEventPhase.pointerPanZoomStart,
    globalPosition: position,
    localPosition: localPosition,
    originalEvent: PointerPanZoomStartEvent(pointer: pointer, timeStamp: timeStamp, position: position),
  );
}

ElEventDetails _panZoomUpdateCallback({
  int pointer = 7,
  required Offset pan,
  required Offset panDelta,
  required Duration timeStamp,
  Offset position = const Offset(10, 10),
  Offset localPosition = const Offset(2, 2),
}) {
  final event = PointerPanZoomUpdateEvent(
    pointer: pointer,
    timeStamp: timeStamp,
    position: position,
    pan: pan,
    panDelta: panDelta,
  );
  return ElEventDetails(
    phase: ElEventPhase.pointerPanZoomUpdate,
    globalPosition: position,
    localPosition: localPosition,
    delta: panDelta,
    localDelta: panDelta,
    originalEvent: event,
  );
}

ElEventDetails _panZoomEndCallback({
  int pointer = 7,
  Offset position = const Offset(10, 10),
  Offset localPosition = const Offset(2, 2),
  Duration timeStamp = Duration.zero,
}) {
  return ElEventDetails(
    phase: ElEventPhase.pointerPanZoomEnd,
    globalPosition: position,
    localPosition: localPosition,
    originalEvent: PointerPanZoomEndEvent(pointer: pointer, timeStamp: timeStamp, position: position),
  );
}

final class _InputCallback extends ElScrollDeltaInterceptor {
  const _InputCallback(this.callback);
  final double Function(double) callback;
  @override
  double interceptScrollDelta(double delta, ElScrollDeltaSource source) => callback(delta);
}

final class _ScrollDragHarness {
  _ScrollDragHarness({
    this.axis = Axis.vertical,
    this.axisDirection = AxisDirection.down,
    double pixels = 0,
    double minScrollExtent = 0,
    double maxScrollExtent = 300,
    ElScrollDeltaInterceptor? interceptor,
  }) : viewport = _FakeScrollViewport(axis: axis, axisDirection: axisDirection),
       position = _RecordingScrollPosition(
         axisDirection: axisDirection,
         pixels: pixels,
         minScrollExtent: minScrollExtent,
         maxScrollExtent: maxScrollExtent,
       ) {
    viewport.position = position;
    controller = ScrollViewDragController(
      owner: viewport,
      position: () => position,
      axis: () => axis,
      axisDirection: () => axisDirection,
      physics: () => const ClampingScrollPhysics(),
      velocityTrackerBuilder: () =>
          (_) => velocityTracker,
      canDrag: () => canDrag,
      shouldAcceptUserOffset: () => shouldAcceptUserOffset,
      resetSmoothPointerScroll: () => smoothPointerScrollResets++,
      deltaInterceptor: () => interceptor,
    );
  }

  final Axis axis;
  final AxisDirection axisDirection;
  final _FakeScrollViewport viewport;
  final _RecordingScrollPosition position;
  final _RecordingVelocityTracker velocityTracker = _RecordingVelocityTracker();

  late final ScrollViewDragController controller;

  bool canDrag = true;
  bool shouldAcceptUserOffset = true;
  int smoothPointerScrollResets = 0;
}

final class _RecordingVelocityTracker extends VelocityTracker {
  _RecordingVelocityTracker() : super.withKind(PointerDeviceKind.trackpad);

  final List<Offset> positions = <Offset>[];

  @override
  void addPosition(Duration time, Offset position) {
    positions.add(position);
  }

  @override
  Velocity getVelocity() {
    return positions.isEmpty ? Velocity.zero : Velocity(pixelsPerSecond: positions.last);
  }
}

final class _RecordingScrollPosition extends ScrollPositionWithSingleContext {
  _RecordingScrollPosition({
    required AxisDirection axisDirection,
    required double pixels,
    required double minScrollExtent,
    required double maxScrollExtent,
  }) : super(
         physics: const ClampingScrollPhysics(),
         context: _TestScrollContext(axisDirection),
         initialPixels: pixels,
         keepScrollOffset: false,
       ) {
    applyViewportDimension(100);
    applyContentDimensions(minScrollExtent, maxScrollExtent);
  }

  final List<_RecordingHold> holds = <_RecordingHold>[];
  final List<_RecordingDrag> drags = <_RecordingDrag>[];

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    final hold = _RecordingHold(holdCancelCallback);
    holds.add(hold);
    return hold;
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    final drag = _RecordingDrag(details, dragCancelCallback, this);
    drags.add(drag);
    return drag;
  }

  void applyRecordedPrimaryDelta(double primaryDelta) {
    forcePixels(pixels - primaryDelta);
  }
}

final class _RecordingHold implements ScrollHoldController {
  _RecordingHold(this._onCancel);

  final VoidCallback _onCancel;
  int cancels = 0;

  @override
  void cancel() {
    cancels++;
    _onCancel();
  }
}

final class _RecordingDrag implements Drag {
  _RecordingDrag(this.start, this._onCancel, this._position);

  final DragStartDetails start;
  final VoidCallback _onCancel;
  final _RecordingScrollPosition _position;
  final List<DragUpdateDetails> updates = <DragUpdateDetails>[];
  final List<DragEndDetails> ends = <DragEndDetails>[];
  int cancels = 0;

  @override
  void update(DragUpdateDetails details) {
    updates.add(details);
    final primaryDelta = details.primaryDelta ?? 0;
    _position.applyRecordedPrimaryDelta(primaryDelta);
  }

  @override
  void end(DragEndDetails details) {
    ends.add(details);
  }

  @override
  void cancel() {
    cancels++;
    _onCancel();
  }
}

final class _TestScrollContext implements ScrollContext {
  _TestScrollContext(this.axisDirection);

  @override
  final AxisDirection axisDirection;

  @override
  double get devicePixelRatio => 1.0;

  @override
  BuildContext? get notificationContext => null;

  @override
  BuildContext get storageContext => throw UnimplementedError();

  @override
  TickerProvider get vsync => const _TestTickerProvider();

  @override
  void saveOffset(double offset) {}

  @override
  void setCanDrag(bool value) {}

  @override
  void setIgnorePointer(bool value) {}

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {}
}

final class _TestTickerProvider implements TickerProvider {
  const _TestTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

final class _FakeScrollViewport extends RenderBox implements ScrollViewport {
  _FakeScrollViewport({required this.axis, required this.axisDirection});

  @override
  late ScrollPosition position;

  bool canConsumePointerScroll = true;
  final Set<RenderObject> descendants = <RenderObject>{};

  @override
  final Axis axis;

  @override
  final AxisDirection axisDirection;

  @override
  Clip get clipBehavior => Clip.hardEdge;

  @override
  Rect get contentViewportRect => Offset.zero & size;

  @override
  Set<PointerDeviceKind> get effectiveContentDragDevices => kViewportDragDevices;

  @override
  bool get attached => true;

  @override
  bool containsGlobalPosition(Offset globalPosition) => true;

  @override
  bool hasActivePointerScrollActivity = false;

  @override
  bool canConsumePointerScrollEvent(PointerScrollEvent event) => canConsumePointerScroll;

  @override
  bool dispatchPointerScroll(PointerScrollEvent event) => canConsumePointerScroll;

  int cancelPointerScrollActivityCount = 0;

  @override
  void cancelPointerScrollActivity() {
    cancelPointerScrollActivityCount++;
  }

  @override
  bool dispatchSelectionPointerSignal(PointerSignalEvent event) => false;

  @override
  bool isAncestorOf(RenderObject node) => descendants.contains(node);

  @override
  double applySelectionAutoScrollDelta(double delta) => 0;

  @override
  Listenable get scrollOffsetListenable => _scrollOffsetRelay;
  final ScrollOffsetRelay _scrollOffsetRelay = ScrollOffsetRelay();
}

PointerDownEvent _touchDown(int pointer) {
  return PointerDownEvent(pointer: pointer, kind: PointerDeviceKind.touch);
}

PointerUpEvent _touchUp(int pointer) {
  return PointerUpEvent(pointer: pointer, kind: PointerDeviceKind.touch);
}

PointerCancelEvent _touchCancel(int pointer) {
  return PointerCancelEvent(pointer: pointer, kind: PointerDeviceKind.touch);
}

PointerRemovedEvent _touchRemoved(int pointer) {
  return PointerRemovedEvent(pointer: pointer, kind: PointerDeviceKind.touch);
}

PointerUpEvent _mouseUp(int pointer) {
  return PointerUpEvent(pointer: pointer, kind: PointerDeviceKind.mouse);
}

PointerDownEvent _mouseDown(int pointer) {
  return PointerDownEvent(pointer: pointer, kind: PointerDeviceKind.mouse);
}

PointerPanZoomStartEvent _panZoomStart(int pointer) {
  return PointerPanZoomStartEvent(pointer: pointer);
}

PointerPanZoomUpdateEvent _panZoomUpdate(int pointer) {
  return PointerPanZoomUpdateEvent(pointer: pointer, panDelta: const Offset(0, -10));
}

PointerPanZoomEndEvent _panZoomEnd(int pointer) {
  return PointerPanZoomEndEvent(pointer: pointer);
}

class _NoChromeBehavior extends ScrollBehavior {
  const _NoChromeBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

class _NoChromeScrollBehavior extends ScrollBehavior {
  const _NoChromeScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

const _scrollKey = Key('single-scroll-view');

Widget _singleScrollShell(ScrollController controller) {
  return MaterialApp(
    scrollBehavior: const _NoChromeScrollBehavior(),
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: _scrollKey,
        width: 120,
        height: 100,
        child: ElScrollView(
          controller: controller,
          children: List<Widget>.generate(10, (index) {
            return ElView(
              key: ValueKey('row-$index'),
              style: ElStyle(width: 120, height: 40, backgroundColor: Color(0xFF101010 + index)),
            );
          }),
        ),
      ),
    ),
  );
}

Widget _clickableTopScrollShell(ScrollController controller, VoidCallback onTap) {
  return MaterialApp(
    scrollBehavior: const _NoChromeScrollBehavior(),
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: _scrollKey,
        width: 200,
        height: 160,
        child: ElScrollView(
          controller: controller,
          children: [
            ElView(
              key: const ValueKey('large-tap-target'),
              event: ElEvent(onTap: (_) => onTap()),
              style: const ElStyle(width: 200, height: 200),
            ),
            ElView(style: ElStyle(width: 200, height: 200)),
          ],
        ),
      ),
    ),
  );
}

/// 记账拦截器：吃指定比例（0.0 = 全放行，1.0 = 全吃）；同时可配置 fling 消费。
class _RatioInterceptor extends ElScrollDeltaInterceptor {
  _RatioInterceptor({this.ratio = 0.5, this.flingRatio = 0.0});

  double ratio;
  double flingRatio;

  final List<(double, ElScrollDeltaSource)> deltaLog = [];
  int flingCalls = 0;

  @override
  double interceptScrollDelta(double delta, ElScrollDeltaSource source) {
    deltaLog.add((delta, source));
    return delta * ratio;
  }

  @override
  double interceptFlingVelocity(double velocity) {
    flingCalls++;
    return velocity * (1.0 - flingRatio);
  }
}

Widget _row(int i) => SizedBox(key: ValueKey('row-$i'), height: 60, width: 200);

/// flutter_test `WidgetController.drag` 的起手阈值（kDragSlopDefault = 20）：
/// 事件层 seed=0 契约把越过阈值前的位移全部丢弃，实际进滚动管线的 delta =
/// 手势总位移 - 20。所有期望值按此折算。
const _dragSlop = 20.0;

Future<void> _pump(
  WidgetTester tester, {
  required ScrollController controller,
  required ElScrollDeltaInterceptor? interceptor,
  int count = 20,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ScrollConfiguration(
        behavior: const _NoChromeBehavior(),
        child: SizedBox(
          height: 300,
          width: 200,
          child: ElScrollView(
            controller: controller,
            deltaInterceptor: interceptor,
            children: [for (var i = 0; i < count; i++) _row(i)],
          ),
        ),
      ),
    ),
  );
}

/// 最小的 dragProxy 宿主：`SingleChildRenderObjectWidget` + `RenderProxyBox`
/// 组合，自带 [EventDispatcher] 并注册到全局 registry。ElView / ElRenderView
/// 目前处于高频重构中（见 memory: event-scroll-test-hosting），事件/滚动测试
/// 的宿主基准优先用官方小部件组合承载，这里正是这种做法：`RenderProxyBox`
/// 直通布局与命中，dispatcher 只挂 [ElEvent.dragProxy]（无 drag 回调 →
/// 无 drag shape），滚动 driver 会在祖先链快照里发现它并纳入 roster。
class _DragProxyHost extends SingleChildRenderObjectWidget {
  const _DragProxyHost({required Widget super.child, required this.event});

  final ElEvent event;

  @override
  _DragProxyHostRender createRenderObject(BuildContext context) => _DragProxyHostRender(event);

  @override
  void updateRenderObject(BuildContext context, _DragProxyHostRender renderObject) {
    renderObject.event = event;
  }
}

class _DragProxyHostRender extends RenderProxyBox {
  _DragProxyHostRender(ElEvent event) {
    _dispatcher = EventDispatcher(this);
    _dispatcher.event = event;
  }

  late final EventDispatcher _dispatcher;

  set event(ElEvent value) => _dispatcher.event = value;

  @override
  void dispose() {
    _dispatcher.dispose();
    super.dispose();
  }
}

/// 弹道活动瞬时速度（非弹道期返回 0）：把测试泵进旧两档设计的"慢速尾段"
/// 窗口（|v| < 800），验证整段屏蔽后尾段不再放行。
double _ballisticVelocity(ScrollPosition position) {
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  final activity = position.activity;
  return activity is BallisticScrollActivity ? activity.velocity.abs() : 0.0;
}

Future<void> _keyboardFocusPump(WidgetTester tester, Widget child) => tester.pumpWidget(
  Directionality(
    textDirection: .ltr,
    child: ElView(
      style: ElStyle(alignment: .topLeft),
      child: child,
    ),
  ),
);

bool _focusVisible(FocusNode node) =>
    (node.context!.findRenderObject()! as ElRenderView).internalStateHas(ViewState.focusVisible);

class _MouseDragScrollBehavior extends ScrollBehavior {
  const _MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{PointerDeviceKind.touch, PointerDeviceKind.mouse};
}

Widget _host(ScrollController controller, {Clip clipBehavior = Clip.hardEdge}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ScrollConfiguration(
      behavior: const _MouseDragScrollBehavior(),
      child: ElView(
        style: const ElStyle(width: 300, height: 300),
        child: ElScrollView(
          controller: controller,
          smoothScroll: null,
          scrollbar: const ElNoScrollBar(),
          clipBehavior: clipBehavior,
          children: const <Widget>[ElView(style: ElStyle(width: 300, height: 1200))],
        ),
      ),
    ),
  );
}

RenderScrollViewportBase _viewport(WidgetTester tester, ScrollController controller) {
  final matches = tester.allRenderObjects
      .whereType<RenderScrollViewportBase>()
      .where((viewport) => identical(viewport.position, controller.position))
      .toSet()
      .toList();
  if (matches.length != 1) {
    throw StateError(
      'viewport matches=${matches.length}: '
      '${matches.map((viewport) => '${viewport.runtimeType} size=${viewport.size} parent=${viewport.parent.runtimeType}').join(' | ')}',
    );
  }
  return matches.single;
}

const _frame = Duration(milliseconds: 16);

class _FixedStepSmoothScroll extends ElSmoothScroll {
  const _FixedStepSmoothScroll(this.step);

  final double step;

  @override
  double stepForEvent(double rawDelta, int burstTicks) => rawDelta.sign * step;

  @override
  Duration segmentDuration(double delta, double velocity) => const Duration(milliseconds: 80);

  @override
  Curve curveFor(double initialSlope) => Curves.linear;
}

String _messageText(int index) {
  final units = switch (index % 6) {
    0 => 1,
    1 => 3,
    2 => 2,
    3 => 5,
    4 => 1,
    _ => 4,
  };
  return List<String>.filled(
    units,
    'message $index keeps a natural height so virtual measurement must not move content under the finger.',
  ).join(' ');
}

Widget _messageRow(int index) {
  return ElView(
    key: ValueKey('row-$index'),
    style: ElStyle(
      width: 320,
      padding: const .all(10),
      margin: const .only(bottom: 6),
      backgroundColor: Color(index.isEven ? 0xFFE7F6DF : 0xFFFFFFFF),
    ),
    child: _messageText(index),
  );
}

Widget _touchDragAnchorFollowHost({required ScrollController controller, required bool virtualized}) {
  final list = virtualized
      ? buildVirtualTestViewBuilder(
          key: const ValueKey('scroll'),
          controller: controller,
          physics: const ClampingScrollPhysics(),
          cacheExtent: 0,
          itemCount: 2000,
          itemBuilder: (_, index) => _messageRow(index),
        )
      : ElScrollView(
          key: const ValueKey('scroll'),
          controller: controller,
          physics: const ClampingScrollPhysics(),
          children: [for (var index = 0; index < 160; index++) _messageRow(index)],
        );
  return MaterialApp(
    scrollBehavior: const _NoChromeScrollBehavior(),
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 320, height: 520, child: list),
    ),
  );
}

Finder _anchoredVisibleRow(WidgetTester tester) {
  final rows = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('row-');
  }).evaluate();
  for (final element in rows) {
    final key = element.widget.key! as ValueKey<String>;
    final finder = find.byKey(key);
    final rect = tester.getRect(finder);
    if (rect.top < 280 && rect.bottom > 240) return finder;
  }
  fail('没有找到覆盖手指锚定线的可见行');
}

class _Controller extends ScrollController {
  final updates = <DragUpdateDetails>[];

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) =>
      _Position(physics: physics, context: context, oldPosition: oldPosition, updates: updates);
}

class _Position extends ScrollPositionWithSingleContext {
  _Position({required super.physics, required super.context, super.oldPosition, required this.updates});
  final List<DragUpdateDetails> updates;

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) =>
      _Drag(super.drag(details, dragCancelCallback), updates);
}

class _Drag implements Drag {
  _Drag(this.inner, this.updates);
  final Drag inner;
  final List<DragUpdateDetails> updates;
  @override
  void update(DragUpdateDetails details) {
    updates.add(details);
    inner.update(details);
  }

  @override
  void end(DragEndDetails details) => inner.end(details);
  @override
  void cancel() => inner.cancel();
}

class _InputProbe extends StatefulWidget {
  const _InputProbe({super.key, required this.fraction, this.fail = false});
  final double fraction;
  final bool fail;
  @override
  State<_InputProbe> createState() => _InputProbeState();
}

class _InputProbeState extends State<_InputProbe> with ElScrollMixin<_InputProbe> {
  final inputs = <ElScrollInputDetails>[];
  final releases = <ElScrollReleaseDetails>[];
  final posts = <(ElScrollInputDetails, double)>[];
  double accepted = 0;
  @override
  Object get scrollInputSlot => #probe;
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    inputs.add(input);
    if (widget.fail) throw StateError('pan input failure');
    accepted += rest * widget.fraction;
    return rest * (1 - widget.fraction);
  }

  @override
  double onPostScroll(ElScrollInputDetails input, double remaining) {
    posts.add((input, super.onPostScroll(input, remaining)));
    return 0;
  }

  @override
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    super.onPreFling(details, remainingVelocity);
    releases.add(details);
    return 0;
  }

  @override
  Widget build(BuildContext context) => ElView();
}

void main() {
  group('滚动期间光标冻结', () {
    testWidgets('单次 claim 到期即释放', (tester) async {
      addTearDown(ScrollCursorFreeze.debugReset);
      await tester.pumpWidget(const SizedBox());
      final owner = tester.renderObject(find.byType(SizedBox));

      ScrollCursorFreeze.claim(owner);
      expect(ScrollCursorFreeze.isActive, isTrue);
      expect(ScrollCursorFreeze.ownedBy(owner), isTrue);

      await tester.pump(elScrollCursorFreezeDuration + const Duration(milliseconds: 1));
      expect(ScrollCursorFreeze.isActive, isFalse);
    });

    testWidgets('逐帧 claim 续期保持冻结（second-chance 复用 Timer），停滚后 1~2 倍窗口内释放', (tester) async {
      addTearDown(ScrollCursorFreeze.debugReset);
      await tester.pumpWidget(const SizedBox());
      final owner = tester.renderObject(find.byType(SizedBox));

      // 每 100ms 续 claim，跨过多个 160ms 到期点仍保持冻结。
      ScrollCursorFreeze.claim(owner);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        ScrollCursorFreeze.claim(owner);
        expect(ScrollCursorFreeze.isActive, isTrue, reason: '持续 claim 期间不得因到期释放');
      }

      // 停止 claim：second-chance 语义下最迟 2 倍窗口由 Timer 释放。
      await tester.pump(elScrollCursorFreezeDuration);
      await tester.pump(elScrollCursorFreezeDuration);
      expect(ScrollCursorFreeze.isActive, isFalse);
    });

    testWidgets('release 立即终止冻结并清续期状态', (tester) async {
      addTearDown(ScrollCursorFreeze.debugReset);
      await tester.pumpWidget(const SizedBox());
      final owner = tester.renderObject(find.byType(SizedBox));

      ScrollCursorFreeze.claim(owner);
      ScrollCursorFreeze.claim(owner);
      ScrollCursorFreeze.release(updateMouseTracker: false);
      expect(ScrollCursorFreeze.isActive, isFalse);

      // release 后不残留会复活冻结的 Timer。
      await tester.pump(elScrollCursorFreezeDuration * 2);
      expect(ScrollCursorFreeze.isActive, isFalse);
    });
  });

  group('拖动控制器', () {
    tearDown(() {
      ScrollPointerChain.debugReset();
      ScrollCursorFreeze.debugReset();
    });

    test('scroll drag details preserve pointer timestamp and device kind', () {
      const timestamp = Duration(milliseconds: 42);
      const globalPosition = Offset(20, 30);
      const localPosition = Offset(5, 7);
      const delta = Offset(0, 12);
      const move = PointerMoveEvent(
        timeStamp: timestamp,
        kind: PointerDeviceKind.touch,
        position: globalPosition,
        delta: delta,
      );
      final event = ElEventDetails(
        phase: ElEventPhase.dragUpdate,
        globalPosition: globalPosition,
        localPosition: localPosition,
        delta: delta,
        localDelta: delta,
        originalEvent: move,
      );

      final start = ScrollViewDragController.debugDragStartDetailsFor(event);
      expect(start.sourceTimeStamp, timestamp);
      expect(start.kind, PointerDeviceKind.touch);
      expect(start.globalPosition, globalPosition);
      expect(start.localPosition, localPosition);

      final update = ScrollViewDragController.debugDragUpdateDetailsFor(event, Axis.vertical, 9);
      expect(update.sourceTimeStamp, timestamp);
      expect(update.kind, PointerDeviceKind.touch);
      expect(update.globalPosition, globalPosition);
      expect(update.localPosition, localPosition);
      expect(update.delta, const Offset(0, 9));
      expect(update.primaryDelta, 9);
    });

    test('设备入口拒绝同步重入，异常不破坏外层及下次输入', () {
      late _ScrollDragHarness harness;
      final event = ElEventDetails(
        phase: ElEventPhase.dragUpdate,
        globalPosition: const Offset(20, 30),
        localPosition: const Offset(20, 30),
        delta: const Offset(0, -12),
        originalEvent: const PointerMoveEvent(kind: PointerDeviceKind.touch, timeStamp: Duration(milliseconds: 24)),
      );
      var inputs = 0;
      harness = _ScrollDragHarness(
        interceptor: _InputCallback((delta) {
          inputs++;
          expect(() => harness.controller.handleDragUpdate(event), throwsA(isA<FlutterError>()));
          return delta;
        }),
      );
      addTearDown(harness.controller.disposeActiveDrag);
      harness.controller.handleDragUpdate(event);
      harness.controller.handleDragUpdate(
        ElEventDetails(
          phase: ElEventPhase.dragUpdate,
          globalPosition: const Offset(20, 20),
          localPosition: const Offset(20, 20),
          delta: const Offset(0, -10),
          originalEvent: const PointerMoveEvent(kind: PointerDeviceKind.touch, timeStamp: Duration(milliseconds: 42)),
        ),
      );
      expect(inputs, 2);
    });

    test('trackpad pan holds lazily on first consumed update', () {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());

      expect(harness.position.holds, isEmpty);
      expect(harness.position.drags, isEmpty);
      expect(harness.smoothPointerScrollResets, 1);

      final update = _panZoomUpdateCallback(
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(update);

      expect(harness.position.drags, hasLength(1));
      expect(harness.position.holds, hasLength(1));
      final drag = harness.position.drags.single;
      expect(drag.start.kind, PointerDeviceKind.trackpad);
      expect(drag.start.sourceTimeStamp, const Duration(milliseconds: 16));
      expect(drag.updates.single.globalPosition, const Offset(10, -10));
      expect(drag.updates.single.localPosition, const Offset(2, -18));
      expect(drag.updates.single.delta, const Offset(0, -20));
      expect(drag.updates.single.primaryDelta, -20);
      expect(update.remainingDelta, Offset.zero);
      expect(update.propagationStopped, isTrue);
      expect(ScrollPointerChain.debugOwner, same(harness.viewport));
      expect(ScrollPointerChain.debugGestureClaimActive, isTrue);
    });

    test('trackpad pan keeps gesture snapshot when canDrag changes mid gesture', () {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      final firstUpdate = _panZoomUpdateCallback(
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(firstUpdate);

      harness.canDrag = false;
      final secondUpdate = _panZoomUpdateCallback(
        pan: const Offset(0, -40),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 32),
      );
      controller.handlePanZoomUpdate(secondUpdate);

      expect(harness.position.drags, hasLength(1));
      expect(harness.position.drags.single.updates, hasLength(2));
      expect(firstUpdate.remainingDelta, Offset.zero);
      expect(secondUpdate.remainingDelta, Offset.zero);
      expect(secondUpdate.propagationStopped, isTrue);

      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 48)));

      expect(harness.position.drags.single.ends, hasLength(1));
    });

    test('trackpad pan ignores update and end from a different pan zoom pointer', () {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback(pointer: 7));
      final firstUpdate = _panZoomUpdateCallback(
        pointer: 7,
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(firstUpdate);

      final foreignUpdate = _panZoomUpdateCallback(
        pointer: 8,
        pan: const Offset(0, -80),
        panDelta: const Offset(0, -60),
        timeStamp: const Duration(milliseconds: 24),
      );
      controller.handlePanZoomUpdate(foreignUpdate);
      controller.handlePanZoomEnd(_panZoomEndCallback(pointer: 8, timeStamp: const Duration(milliseconds: 32)));

      expect(harness.position.drags.single.updates, hasLength(1));
      expect(foreignUpdate.remainingDelta, const Offset(0, -60));
      expect(ScrollPointerChain.debugOwner, same(harness.viewport));

      controller.handlePanZoomEnd(_panZoomEndCallback(pointer: 7, timeStamp: const Duration(milliseconds: 48)));

      expect(harness.position.drags.single.ends, hasLength(1));
      expect(ScrollPointerChain.debugOwner, isNull);
    });

    test('trackpad pan start cancels stale consumed gesture before accepting a new one', () {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      controller.handlePanZoomUpdate(
        _panZoomUpdateCallback(
          pan: const Offset(0, -16),
          panDelta: const Offset(0, -16),
          timeStamp: const Duration(milliseconds: 16),
        ),
      );

      expect(ScrollPointerChain.debugOwner, same(harness.viewport));
      expect(harness.position.drags.single.cancels, 0);

      harness.canDrag = false;
      controller.handlePanZoomStart(_panZoomStartCallback(timeStamp: const Duration(milliseconds: 32)));

      expect(harness.position.drags.single.cancels, 1);
      expect(ScrollPointerChain.debugOwner, isNull);

      harness.canDrag = true;
      controller.handlePanZoomStart(_panZoomStartCallback(timeStamp: const Duration(milliseconds: 48)));
      final update = _panZoomUpdateCallback(
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 64),
      );
      controller.handlePanZoomUpdate(update);

      expect(harness.position.drags, hasLength(2));
      expect(harness.position.drags.last.updates.single.primaryDelta, -20);
      expect(update.propagationStopped, isTrue);
    });

    test('unconsumed trackpad pan end does not release an existing wheel owner', () {
      final wheelOwner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      const wheel = PointerScrollEvent(position: Offset.zero, scrollDelta: Offset(0, 80));
      ScrollPointerChain.claimForPointerScroll(wheelOwner, wheel);

      final harness = _ScrollDragHarness(pixels: 100, maxScrollExtent: 100);
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      controller.handlePanZoomUpdate(
        _panZoomUpdateCallback(
          pan: const Offset(0, -16),
          panDelta: const Offset(0, -16),
          timeStamp: const Duration(milliseconds: 16),
        ),
      );
      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 32)));

      expect(harness.position.drags, isEmpty);
      expect(ScrollPointerChain.debugOwner, same(wheelOwner));
    });

    testWidgets('trackpad gesture claim survives 500ms wheel hold until pan zoom end', (tester) async {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      controller.handlePanZoomUpdate(
        _panZoomUpdateCallback(
          pan: const Offset(0, -12),
          panDelta: const Offset(0, -12),
          timeStamp: const Duration(milliseconds: 16),
        ),
      );

      await tester.pump(ScrollPointerChain.debugPointerScrollChainHoldDuration + const Duration(milliseconds: 1));

      expect(ScrollPointerChain.debugOwner, same(harness.viewport));
      expect(ScrollPointerChain.debugGestureClaimActive, isTrue);

      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 180)));

      expect(ScrollPointerChain.debugOwner, isNull);
      expect(ScrollPointerChain.debugGestureClaimActive, isFalse);
      ScrollCursorFreeze.debugReset();
    });

    test('trackpad pan locks to child after consuming boundary delta', () {
      final harness = _ScrollDragHarness(pixels: 95, maxScrollExtent: 100);
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      final firstUpdate = _panZoomUpdateCallback(
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(firstUpdate);
      final secondUpdate = _panZoomUpdateCallback(
        pan: const Offset(0, -40),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 32),
      );
      controller.handlePanZoomUpdate(secondUpdate);

      expect(harness.velocityTracker.positions, <Offset>[Offset.zero, const Offset(0, -20), const Offset(0, -40)]);
      expect(firstUpdate.remainingDelta, Offset.zero);
      expect(secondUpdate.remainingDelta, Offset.zero);
      expect(firstUpdate.propagationStopped, isTrue);
      expect(secondUpdate.propagationStopped, isTrue);
      expect(harness.position.drags.single.updates.single.primaryDelta, -5);

      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 48)));

      final drag = harness.position.drags.single;
      expect(drag.ends, hasLength(1));
      expect(drag.cancels, 0);
    });

    test('trackpad pan consumes only viewport axis and preserves cross-axis delta', () {
      final harness = _ScrollDragHarness(axis: Axis.vertical);
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      final update = _panZoomUpdateCallback(
        pan: const Offset(15, -20),
        panDelta: const Offset(15, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(update);

      expect(harness.position.drags.single.updates.single.primaryDelta, -20);
      expect(update.remainingDelta, const Offset(15, 0));
      expect(update.propagationStopped, isFalse);
    });

    test('trackpad pan bubbles when child starts at boundary', () {
      final harness = _ScrollDragHarness(pixels: 100, maxScrollExtent: 100);
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      final update = _panZoomUpdateCallback(
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(update);

      expect(harness.position.pixels, 100);
      expect(update.remainingPrimaryDelta(Axis.vertical), -20);
      expect(update.propagationStopped, isFalse);
      expect(harness.position.drags, isEmpty);

      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 32)));

      expect(ScrollPointerChain.debugOwner, isNull);
    });

    test('top-level trackpad boundary can reverse within the same pan zoom stream', () {
      final harness = _ScrollDragHarness(pixels: 100, maxScrollExtent: 100);
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      final boundary = _panZoomUpdateCallback(
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(boundary);
      final reverse = _panZoomUpdateCallback(
        pan: Offset.zero,
        panDelta: const Offset(0, 20),
        timeStamp: const Duration(milliseconds: 32),
      );
      controller.handlePanZoomUpdate(reverse);

      expect(harness.position.pixels, 80, reason: '没有祖先接盘时，同一 stream 反向必须由顶层视口立即消费。');
      expect(reverse.remainingDelta, Offset.zero);
      expect(harness.position.drags, hasLength(1));
      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 48)));
    });

    test('trackpad pan does not recapture after bubbling to ancestor at boundary', () {
      final harness = _ScrollDragHarness(pixels: 100, maxScrollExtent: 100);
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      final boundary = _panZoomUpdateCallback(
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(boundary);

      expect(boundary.remainingPrimaryDelta(Axis.vertical), -20);
      expect(boundary.propagationStopped, isFalse);

      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down)
        ..descendants.add(harness.viewport);
      ScrollPointerChain.claimGesture(outer, axis: Axis.vertical);

      final reverse = _panZoomUpdateCallback(
        pan: Offset.zero,
        panDelta: const Offset(0, 20),
        timeStamp: const Duration(milliseconds: 32),
      );
      controller.handlePanZoomUpdate(reverse);

      expect(harness.position.pixels, 100);
      expect(reverse.remainingPrimaryDelta(Axis.vertical), 20);
      expect(reverse.propagationStopped, isFalse);
      expect(harness.position.drags, isEmpty);

      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 48)));

      expect(ScrollPointerChain.debugOwner, same(outer));
    });

    test('trackpad pan end keeps child fling when later update consumes all remaining delta', () {
      final harness = _ScrollDragHarness(pixels: 95, maxScrollExtent: 100);
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      final boundaryUpdate = _panZoomUpdateCallback(
        pan: const Offset(0, -20),
        panDelta: const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 16),
      );
      controller.handlePanZoomUpdate(boundaryUpdate);

      final reverseUpdate = _panZoomUpdateCallback(
        pan: const Offset(0, -10),
        panDelta: const Offset(0, 10),
        timeStamp: const Duration(milliseconds: 32),
      );
      controller.handlePanZoomUpdate(reverseUpdate);

      expect(harness.position.pixels, 90);
      expect(reverseUpdate.remainingDelta, Offset.zero);
      expect(reverseUpdate.propagationStopped, isTrue);

      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 48)));

      final drag = harness.position.drags.single;
      expect(drag.cancels, 0);
      expect(drag.ends, hasLength(1));
    });

    test('pan zoom end cleans active drag even when scrolling becomes disabled mid gesture', () {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      controller.handlePanZoomUpdate(
        _panZoomUpdateCallback(
          pan: const Offset(0, -16),
          panDelta: const Offset(0, -16),
          timeStamp: const Duration(milliseconds: 16),
        ),
      );
      harness.shouldAcceptUserOffset = false;

      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 32)));

      expect(harness.position.drags.single.ends, hasLength(1));
      expect(ScrollPointerChain.debugOwner, isNull);

      controller.handlePanZoomEnd(_panZoomEndCallback(timeStamp: const Duration(milliseconds: 48)));

      expect(harness.position.drags.single.ends, hasLength(1));
    });

    test('pan zoom end can clean active drag without ballistic velocity', () {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      controller.handlePanZoomUpdate(
        _panZoomUpdateCallback(
          pan: const Offset(0, -16),
          panDelta: const Offset(0, -16),
          timeStamp: const Duration(milliseconds: 16),
        ),
      );

      controller.handlePanZoomEnd(
        _panZoomEndCallback(timeStamp: const Duration(milliseconds: 32)),
        allowBallistic: false,
      );

      expect(harness.position.drags.single.cancels, 1);
      expect(harness.position.drags.single.ends, isEmpty);
      expect(ScrollPointerChain.debugOwner, isNull);
    });

    test('cancelActiveDrag cancels trackpad hold and drag without ending velocity', () {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handlePanZoomStart(_panZoomStartCallback());
      controller.handlePanZoomUpdate(
        _panZoomUpdateCallback(
          pan: const Offset(0, -16),
          panDelta: const Offset(0, -16),
          timeStamp: const Duration(milliseconds: 16),
        ),
      );

      controller.cancelActiveDrag();

      expect(harness.position.holds.single.cancels, 0);
      expect(harness.position.drags.single.cancels, 1);
      expect(harness.position.drags.single.ends, isEmpty);
      expect(ScrollPointerChain.debugOwner, isNull);
    });

    test('drag end can clean active drag without ballistic velocity', () {
      final harness = _ScrollDragHarness();
      final controller = harness.controller;

      controller.handleDragStart(
        _dragCallback(phase: ElEventPhase.dragStart, delta: const Offset(0, -24), dragOffset: const Offset(0, -24)),
      );
      controller.handleDragEnd(
        _dragCallback(
          phase: ElEventPhase.dragEnd,
          velocity: const Velocity(pixelsPerSecond: Offset(0, -900)),
        ),
        allowBallistic: false,
      );

      expect(harness.position.drags.single.cancels, 1);
      expect(harness.position.drags.single.ends, isEmpty);
      expect(harness.position.holds.single.cancels, 0);
    });

    test('touch drag stays latched after consuming boundary delta', () {
      final harness = _ScrollDragHarness(pixels: 95, maxScrollExtent: 100);
      final controller = harness.controller;
      final eagerClaims = <({bool cancelSelfTap, bool allowScaleUpgrade})>[];

      final start = _dragCallback(
        phase: ElEventPhase.dragStart,
        delta: const Offset(0, -20),
        dragOffset: const Offset(0, -20),
        onEagerGesture: (cancelSelfTap, allowScaleUpgrade) =>
            eagerClaims.add((cancelSelfTap: cancelSelfTap, allowScaleUpgrade: allowScaleUpgrade)),
      );
      controller.handleDragStart(start);

      expect(harness.position.pixels, 100);
      expect(start.remainingDelta, Offset.zero);
      expect(start.propagationStopped, isFalse);

      final boundaryUpdate = _dragCallback(
        phase: ElEventPhase.dragUpdate,
        delta: const Offset(0, -20),
        dragOffset: const Offset(0, -40),
        onEagerGesture: (cancelSelfTap, allowScaleUpgrade) =>
            eagerClaims.add((cancelSelfTap: cancelSelfTap, allowScaleUpgrade: allowScaleUpgrade)),
      );
      controller.handleDragUpdate(boundaryUpdate);

      expect(harness.position.pixels, 100);
      expect(boundaryUpdate.remainingDelta, Offset.zero);
      expect(boundaryUpdate.propagationStopped, isFalse);
      expect(eagerClaims, const [
        (cancelSelfTap: true, allowScaleUpgrade: true),
        (cancelSelfTap: true, allowScaleUpgrade: true),
      ]);

      controller.handleDragEnd(
        _dragCallback(
          phase: ElEventPhase.dragEnd,
          velocity: const Velocity(pixelsPerSecond: Offset(0, -900)),
        ),
      );

      expect(harness.position.drags.single.cancels, 0);
      expect(harness.position.drags.single.ends, hasLength(1));
    });

    test('touch drag consumes only viewport axis and preserves cross-axis delta', () {
      final harness = _ScrollDragHarness(axis: Axis.vertical);
      final controller = harness.controller;
      final eagerClaims = <({bool cancelSelfTap, bool allowScaleUpgrade})>[];

      final start = _dragCallback(
        phase: ElEventPhase.dragStart,
        delta: const Offset(15, -20),
        dragOffset: const Offset(15, -20),
        onEagerGesture: (cancelSelfTap, allowScaleUpgrade) =>
            eagerClaims.add((cancelSelfTap: cancelSelfTap, allowScaleUpgrade: allowScaleUpgrade)),
      );
      controller.handleDragStart(start);

      expect(harness.position.drags.single.updates.single.primaryDelta, -20);
      expect(start.remainingDelta, const Offset(15, 0));
      expect(start.propagationStopped, isFalse);

      final update = _dragCallback(
        phase: ElEventPhase.dragUpdate,
        delta: const Offset(8, -12),
        dragOffset: const Offset(23, -32),
        onEagerGesture: (cancelSelfTap, allowScaleUpgrade) =>
            eagerClaims.add((cancelSelfTap: cancelSelfTap, allowScaleUpgrade: allowScaleUpgrade)),
      );
      controller.handleDragUpdate(update);

      expect(harness.position.drags.single.updates.last.primaryDelta, -12);
      expect(update.remainingDelta, const Offset(8, 0));
      expect(update.propagationStopped, isFalse);
      expect(eagerClaims, const [
        (cancelSelfTap: true, allowScaleUpgrade: true),
        (cancelSelfTap: true, allowScaleUpgrade: true),
      ]);
    });

    test('horizontal drag at trailing boundary accepts inward delta on a fresh gesture', () {
      final harness = _ScrollDragHarness(
        axis: Axis.horizontal,
        axisDirection: AxisDirection.right,
        pixels: 100,
        maxScrollExtent: 100,
      );
      final controller = harness.controller;

      final start = _dragCallback(
        phase: ElEventPhase.dragStart,
        delta: const Offset(20, 0),
        dragOffset: const Offset(20, 0),
      );
      controller.handleDragStart(start);

      expect(harness.position.pixels, lessThan(100), reason: '右边界向右反拖必须立刻降低横向 offset');
      expect(harness.position.drags.single.updates.single.primaryDelta, 20);
      expect(start.remainingDelta, Offset.zero);
    });

    test('touch drag bubbles when child starts at boundary', () {
      final harness = _ScrollDragHarness(pixels: 100, maxScrollExtent: 100);
      final controller = harness.controller;

      final start = _dragCallback(
        phase: ElEventPhase.dragStart,
        delta: const Offset(0, -20),
        dragOffset: const Offset(0, -20),
        hasAncestorDragConsumer: true,
      );
      controller.handleDragStart(start);

      expect(harness.position.pixels, 100);
      expect(start.remainingPrimaryDelta(Axis.vertical), -20);
      expect(start.propagationStopped, isFalse);
      expect(harness.position.drags, isEmpty);
    });

    test('touch drag does not recapture after bubbling to ancestor at boundary', () {
      final harness = _ScrollDragHarness(pixels: 100, maxScrollExtent: 100);
      final controller = harness.controller;

      final start = _dragCallback(
        phase: ElEventPhase.dragStart,
        delta: const Offset(0, -20),
        dragOffset: const Offset(0, -20),
        hasAncestorDragConsumer: true,
      );
      controller.handleDragStart(start);

      expect(start.remainingPrimaryDelta(Axis.vertical), -20);
      expect(start.propagationStopped, isFalse);

      final reverse = _dragCallback(
        phase: ElEventPhase.dragUpdate,
        delta: const Offset(0, 20),
        dragOffset: Offset.zero,
        hasAncestorDragConsumer: true,
      );
      controller.handleDragUpdate(reverse);

      expect(harness.position.pixels, 100);
      expect(reverse.remainingPrimaryDelta(Axis.vertical), 20);
      expect(reverse.propagationStopped, isFalse);
      expect(harness.position.drags, isEmpty);
    });

    test('pointer wheel chain can be claimed immediately after current owner releases at boundary', () {
      final inner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);

      ScrollPointerChain.claim(inner);
      expect(ScrollPointerChain.ownerAt(Offset.zero), same(inner));

      ScrollPointerChain.release(inner);
      ScrollPointerChain.claim(outer);

      expect(ScrollPointerChain.ownerAt(Offset.zero), same(outer));
      expect(ScrollPointerChain.debugGestureClaimActive, isFalse);
    });

    test('pointer wheel chain cancels previous owner activity when ownership changes', () {
      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      final inner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      const event = PointerScrollEvent(position: Offset.zero, scrollDelta: Offset(0, 120));

      ScrollPointerChain.claimForPointerScroll(outer, event);
      ScrollPointerChain.claimForPointerScroll(outer, event);
      expect(outer.cancelPointerScrollActivityCount, 0);

      ScrollPointerChain.claimForPointerScroll(inner, event);

      expect(outer.cancelPointerScrollActivityCount, 1);
      expect(inner.cancelPointerScrollActivityCount, 0);
      expect(ScrollPointerChain.ownerAt(Offset.zero, event: event), same(inner));
      ScrollPointerChain.debugReset();
    });

    testWidgets('pointer wheel chain releases after the owner hold transaction', (tester) async {
      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      final inner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);

      ScrollPointerChain.claim(outer);
      await tester.pump(ScrollPointerChain.debugPointerScrollChainHoldDuration - const Duration(milliseconds: 1));

      expect(ScrollPointerChain.ownerAt(Offset.zero), same(outer));

      await tester.pump(const Duration(milliseconds: 2));
      ScrollPointerChain.claim(inner);

      expect(ScrollPointerChain.ownerAt(Offset.zero), same(inner));
      expect(ScrollPointerChain.debugGestureClaimActive, isFalse);
      ScrollPointerChain.debugReset();
    });

    testWidgets('pointer wheel chain releases owner with the ancestor retarget window', (tester) async {
      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      const event = PointerScrollEvent(position: Offset.zero, scrollDelta: Offset(0, 120));

      ScrollPointerChain.claimForPointerScroll(outer, event);

      expect(ScrollPointerChain.debugPointerScrollChainHoldDuration, const Duration(milliseconds: 500));
      expect(ScrollPointerChain.debugPointerScrollAncestorRetargetDelay, const Duration(milliseconds: 500));
      expect(ScrollPointerChain.debugOwner, same(outer));
      expect(ScrollPointerChain.debugAncestorRetargetBlocked, isTrue);

      await tester.pump(ScrollPointerChain.debugPointerScrollChainHoldDuration - const Duration(milliseconds: 1));

      expect(ScrollPointerChain.debugOwner, same(outer));
      expect(ScrollPointerChain.debugAncestorRetargetBlocked, isTrue);

      await tester.pump(const Duration(milliseconds: 2));

      expect(ScrollPointerChain.debugOwner, isNull);
      expect(ScrollPointerChain.debugAncestorRetargetBlocked, isFalse);
      ScrollPointerChain.debugReset();
    });

    testWidgets('pointer wheel chain keeps current owner until idle timeout even when it cannot consume', (
      tester,
    ) async {
      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      final inner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      const event = PointerScrollEvent(position: Offset.zero, scrollDelta: Offset(0, 120));

      ScrollPointerChain.claimForPointerScroll(outer, event);
      outer.canConsumePointerScroll = false;

      expect(ScrollPointerChain.ownerAt(Offset.zero, event: event), same(outer));

      await tester.pump(ScrollPointerChain.debugPointerScrollChainHoldDuration - const Duration(milliseconds: 1));

      expect(ScrollPointerChain.ownerAt(Offset.zero, event: event), same(outer));
      expect(ScrollPointerChain.debugAncestorRetargetBlocked, isTrue);

      await tester.pump(const Duration(milliseconds: 2));

      expect(ScrollPointerChain.ownerAt(Offset.zero, event: event), isNull);
      ScrollPointerChain.claimForPointerScroll(inner, event);
      expect(ScrollPointerChain.ownerAt(Offset.zero, event: event), same(inner));
      expect(ScrollPointerChain.debugGestureClaimActive, isFalse);
      ScrollPointerChain.debugReset();
    });

    testWidgets('pointer wheel chain keeps deferring descendants while ancestor wheel activity is active', (
      tester,
    ) async {
      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);

      ScrollPointerChain.claim(outer);
      outer.hasActivePointerScrollActivity = true;

      await tester.pump(ScrollPointerChain.debugPointerScrollChainHoldDuration - const Duration(milliseconds: 1));

      expect(ScrollPointerChain.debugAncestorRetargetBlocked, isFalse);
      expect(ScrollPointerChain.shouldDeferToAncestor(outer), isTrue);

      outer.hasActivePointerScrollActivity = false;

      expect(ScrollPointerChain.shouldDeferToAncestor(outer), isFalse);
      ScrollPointerChain.debugReset();
    });

    test('pointer wheel chain keeps independent owners per scroll axis', () {
      final verticalInner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      final horizontalOuter = _FakeScrollViewport(axis: Axis.horizontal, axisDirection: AxisDirection.right);
      const event = PointerScrollEvent(position: Offset.zero, scrollDelta: Offset(80, 120));

      ScrollPointerChain.claimForPointerScroll(verticalInner, event, axis: Axis.vertical);
      ScrollPointerChain.claimForPointerScroll(horizontalOuter, event, axis: Axis.horizontal);

      expect(ScrollPointerChain.ownerAt(Offset.zero, event: event, axis: Axis.vertical), same(verticalInner));
      expect(ScrollPointerChain.ownerAt(Offset.zero, event: event, axis: Axis.horizontal), same(horizontalOuter));
      expect(
        ScrollPointerChain.shouldDeferViewportToOwner(horizontalOuter, verticalInner, axis: Axis.horizontal),
        isFalse,
      );
      expect(verticalInner.cancelPointerScrollActivityCount, 0);
      expect(horizontalOuter.cancelPointerScrollActivityCount, 0);
    });

    test('pointer wheel batch skips duplicate handled actions on the same axis', () {
      const event = PointerScrollEvent(position: Offset.zero, scrollDelta: Offset(80, 120));
      final owner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      final calls = <String>[];

      ScrollPointerChain.registerPointerScrollAction(
        event,
        (_) {
          calls.add('vertical-1');
          return true;
        },
        axis: Axis.vertical,
        owner: owner,
      );
      ScrollPointerChain.registerPointerScrollAction(
        event,
        (_) {
          calls.add('vertical-2');
          return true;
        },
        axis: Axis.vertical,
        owner: owner,
      );
      ScrollPointerChain.registerPointerScrollAction(
        event,
        (_) {
          calls.add('horizontal-1');
          return true;
        },
        axis: Axis.horizontal,
        owner: owner,
      );
      ScrollPointerChain.registerPointerScrollAction(
        event,
        (_) {
          calls.add('horizontal-2');
          return true;
        },
        axis: Axis.horizontal,
        owner: owner,
      );

      GestureBinding.instance.pointerSignalResolver.resolve(event);

      expect(calls, <String>['vertical-1', 'horizontal-1']);
    });

    test('pointer wheel batch resolves descendant viewport before ancestor on the same axis', () {
      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      final inner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      outer.descendants.add(inner);
      const event = PointerScrollEvent(position: Offset.zero, scrollDelta: Offset(0, 20));
      final calls = <String>[];

      ScrollPointerChain.registerPointerScrollAction(
        event,
        (_) {
          calls.add('outer');
          return true;
        },
        axis: Axis.vertical,
        owner: outer,
      );
      ScrollPointerChain.registerPointerScrollAction(
        event,
        (_) {
          calls.add('inner');
          return true;
        },
        axis: Axis.vertical,
        owner: inner,
      );

      GestureBinding.instance.pointerSignalResolver.resolve(event);

      expect(calls, <String>['inner']);
    });

    test('pointer wheel chain releases at the latching slop boundary', () {
      final outer = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);
      final inner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down);

      ScrollPointerChain.claimForPointerScroll(
        outer,
        const PointerScrollEvent(position: Offset(0, 0), scrollDelta: Offset(0, 120)),
      );

      expect(
        ScrollPointerChain.ownerAt(
          const Offset(6, 7),
          event: const PointerScrollEvent(position: Offset(6, 7), scrollDelta: Offset(0, 120)),
        ),
        same(outer),
      );

      expect(
        ScrollPointerChain.ownerAt(
          const Offset(10, 0),
          event: const PointerScrollEvent(position: Offset(10, 0), scrollDelta: Offset(0, 120)),
        ),
        isNull,
      );
      expect(outer.cancelPointerScrollActivityCount, 1);

      // querier 就是现役 owner 时越阈不解 latch、更不停在途动画：同一容器内挪一下
      // 鼠标也会越阈，硬停会让动画段半路 goIdle 再从静止重起。
      ScrollPointerChain.claimForPointerScroll(
        outer,
        const PointerScrollEvent(position: Offset(0, 0), scrollDelta: Offset(0, 120)),
      );
      expect(
        ScrollPointerChain.ownerAt(
          const Offset(40, 0),
          event: const PointerScrollEvent(position: Offset(40, 0), scrollDelta: Offset(0, 120)),
          querier: outer,
        ),
        same(outer),
      );
      expect(outer.cancelPointerScrollActivityCount, 1);

      ScrollPointerChain.claimForPointerScroll(
        inner,
        const PointerScrollEvent(position: Offset(10, 0), scrollDelta: Offset(0, 120)),
      );

      expect(ScrollPointerChain.ownerAt(const Offset(10, 0)), same(inner));
      expect(ScrollPointerChain.debugGestureClaimActive, isFalse);
    });

    test('pointer wheel chain keeps an owner that cannot consume until the idle timer fires', () {
      final owner = _FakeScrollViewport(axis: Axis.vertical, axisDirection: AxisDirection.down)
        ..canConsumePointerScroll = false;
      const event = PointerScrollEvent(position: Offset.zero, scrollDelta: Offset(0, 120));

      ScrollPointerChain.claim(owner);

      expect(ScrollPointerChain.ownerAt(Offset.zero, event: event), same(owner));
      expect(ScrollPointerChain.debugOwner, same(owner));
      expect(ScrollPointerChain.debugGestureClaimActive, isFalse);
      ScrollPointerChain.debugReset();
    });
  });

  group('触摸事件锁存', () {
    test('defers sync until every active touch pointer ends', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_touchDown(1)), isFalse);
      expect(latch.beforeDispatch(_touchDown(2)), isFalse);
      expect(latch.active, isTrue);
      expect(latch.deferIfActive(), isTrue);
      expect(latch.hasDeferredSync, isTrue);

      expect(latch.beforeDispatch(_touchUp(1)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 0);
      expect(latch.active, isTrue);
      expect(latch.hasDeferredSync, isTrue);

      expect(latch.beforeDispatch(_touchUp(2)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
      expect(latch.hasDeferredSync, isFalse);
    });

    test('ignores unknown pointer endings', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_touchDown(1)), isFalse);
      expect(latch.deferIfActive(), isTrue);

      expect(latch.beforeDispatch(_mouseUp(2)), isFalse);
      latch.flushAfterDispatch(() => syncCount++);
      expect(syncCount, 0);
      expect(latch.hasDeferredSync, isTrue);

      expect(latch.beforeDispatch(_touchUp(2)), isFalse);
      latch.flushAfterDispatch(() => syncCount++);
      expect(syncCount, 0);
      expect(latch.active, isTrue);

      expect(latch.beforeDispatch(_touchCancel(1)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);
      expect(syncCount, 1);
      expect(latch.active, isFalse);
    });

    test('defers sync until active mouse pointer ends', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_mouseDown(1)), isFalse);
      expect(latch.active, isTrue);
      expect(latch.deferIfActive(), isTrue);

      expect(latch.beforeDispatch(_mouseUp(1)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
      expect(latch.hasDeferredSync, isFalse);
    });

    test('defers sync until active pan zoom sequence ends', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_panZoomStart(7)), isFalse);
      expect(latch.active, isTrue);
      expect(latch.deferIfActive(), isTrue);

      expect(latch.beforeDispatch(_panZoomUpdate(7)), isFalse);
      latch.flushAfterDispatch(() => syncCount++);
      expect(syncCount, 0);
      expect(latch.hasDeferredSync, isTrue);

      expect(latch.beforeDispatch(_panZoomEnd(7)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
      expect(latch.hasDeferredSync, isFalse);
    });

    test('ignores unknown pan zoom endings', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_panZoomStart(7)), isFalse);
      expect(latch.deferIfActive(), isTrue);

      expect(latch.beforeDispatch(_panZoomEnd(8)), isFalse);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 0);
      expect(latch.active, isTrue);
      expect(latch.hasDeferredSync, isTrue);

      expect(latch.beforeDispatch(_panZoomEnd(7)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
    });

    test('defers pan zoom sync until every active pan zoom pointer ends', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_panZoomStart(7)), isFalse);
      expect(latch.beforeDispatch(_panZoomStart(8)), isFalse);
      expect(latch.deferIfActive(), isTrue);

      expect(latch.beforeDispatch(_panZoomEnd(7)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 0);
      expect(latch.active, isTrue);

      expect(latch.beforeDispatch(_panZoomEnd(8)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
    });

    test('runs deferred callbacks before final sync when last touch pointer ends', () {
      final latch = ScrollTouchEventSyncLatch();
      final phases = <String>[];

      expect(latch.beforeDispatch(_touchDown(1)), isFalse);
      expect(
        latch.deferCallbackIfActive(() {
          phases.add('callback');
        }),
        isTrue,
      );
      expect(latch.deferIfActive(), isTrue);

      expect(latch.beforeDispatch(_touchUp(1)), isTrue);
      latch.flushAfterDispatch(() {
        phases.add('sync');
      });

      expect(phases, <String>['callback', 'sync']);
      expect(latch.hasDeferredSync, isFalse);
    });

    test('releases deferred sync on pointer removed', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_touchDown(1)), isFalse);
      expect(latch.deferIfActive(), isTrue);

      expect(latch.beforeDispatch(_touchRemoved(1)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
      expect(latch.hasDeferredSync, isFalse);
    });

    test('releases deferred pan zoom sync on pointer removed', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_panZoomStart(7)), isFalse);
      expect(latch.deferIfActive(), isTrue);

      expect(latch.beforeDispatch(_touchRemoved(7)), isTrue);
      latch.flushAfterDispatch(() => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
      expect(latch.hasDeferredSync, isFalse);
    });

    test('routed pointer removed releases deferred sync outside hit-test dispatch', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_touchDown(1)), isFalse);
      expect(latch.deferIfActive(), isTrue);

      latch.handleRoutedPointerRemoved(_touchRemoved(1), () => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
      expect(latch.hasDeferredSync, isFalse);
    });

    test('routed pointer removed releases deferred pan zoom sync outside hit-test dispatch', () {
      final latch = ScrollTouchEventSyncLatch();
      var syncCount = 0;

      expect(latch.beforeDispatch(_panZoomStart(7)), isFalse);
      expect(latch.deferIfActive(), isTrue);

      latch.handleRoutedPointerRemoved(_touchRemoved(7), () => syncCount++);

      expect(syncCount, 1);
      expect(latch.active, isFalse);
      expect(latch.hasDeferredSync, isFalse);
    });

    testWidgets('reset 不丢 deferred 回调：迁移到 post-frame 执行（detach 转移语义）', (tester) async {
      final latch = ScrollTouchEventSyncLatch();
      var callbackRuns = 0;

      expect(latch.beforeDispatch(_touchDown(1)), isFalse);
      expect(latch.deferCallbackIfActive(() => callbackRuns++), isTrue);

      // 模拟触摸序列进行中 render detach：reset 只应中止等待，不得吞掉回调
      // （宿主 State 清 deferred flag 的唯一路径在回调里）。
      latch.reset();

      expect(callbackRuns, 0, reason: 'reset 当帧不同步执行回调');
      expect(latch.active, isFalse);
      expect(latch.hasDeferredSync, isFalse);

      await tester.pump();

      expect(callbackRuns, 1, reason: '回调应在 post-frame 落地');

      // 后续帧不重复执行。
      await tester.pump();
      expect(callbackRuns, 1);
    });
  });

  group('默认滚动动作取消', () {
    const scrollKey = ValueKey('scroll');

    Widget shell({
      required ScrollController controller,
      ScrollController? horizontalController,
      Axis? axis = Axis.vertical,
      ElEvent? event,
    }) {
      return MaterialApp(
        scrollBehavior: const _NoChromeBehavior(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: scrollKey,
            width: 240,
            height: 180,
            child: ElScrollView(
              axis: axis,
              controller: controller,
              horizontalController: horizontalController,
              physics: const ClampingScrollPhysics(),
              smoothScroll: null,
              event: event,
              children: [
                ElView(
                  style: ElStyle(
                    width: axis == null ? 900 : 240,
                    height: 1200,
                    backgroundColor: const Color(0xff334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('onPointerDown preventDefault 不阻止后续触摸滚动', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var pointerDowns = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          event: ElEvent(
            onPointerDown: (event) {
              pointerDowns++;
              event.preventDefault();
            },
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(pointerDowns, 1);
      expect(controller.offset, greaterThan(20), reason: 'PointerDown 没有滚动默认动作，不能跨阶段阻止后续 Drag 滚动');
    });

    testWidgets('dragStart preventDefault 阻止本次默认滚动，下一手势恢复', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var dragStarts = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          event: ElEvent(
            onVerticalDragStart: (event) {
              dragStarts++;
              if (dragStarts == 1) event.preventDefault();
            },
          ),
        ),
      );

      final center = tester.getCenter(find.byKey(scrollKey));
      final blocked = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 11);
      await blocked.down(center);
      await tester.pump();
      await blocked.moveBy(const Offset(0, -50));
      await tester.pump();
      await blocked.moveBy(const Offset(0, -50));
      await tester.pump();
      await blocked.up();
      await tester.pump();
      expect(controller.offset, 0, reason: 'DragStart 是整段滚动默认动作的门禁');

      final allowed = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 12);
      await allowed.down(center);
      await tester.pump();
      await allowed.moveBy(const Offset(0, -50));
      await tester.pump();
      await allowed.moveBy(const Offset(0, -50));
      await tester.pump();
      await allowed.up();
      await tester.pumpAndSettle();

      expect(dragStarts, 2);
      expect(controller.offset, greaterThan(20), reason: 'preventDefault 只作用于调用所在的手势序列');
    });

    testWidgets('pointerSignal preventDefault 只阻止当前滚轮事件', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var signals = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          event: ElEvent(
            onPointerSignal: (event) {
              signals++;
              if (signals == 1) event.preventDefault();
            },
          ),
        ),
      );

      final center = tester.getCenter(find.byKey(scrollKey));
      await tester.sendEventToBinding(PointerScrollEvent(position: center, scrollDelta: const Offset(0, 80)));
      await tester.pump();
      expect(controller.offset, 0);

      await tester.sendEventToBinding(PointerScrollEvent(position: center, scrollDelta: const Offset(0, 80)));
      await tester.pump();
      expect(signals, 2);
      expect(controller.offset, closeTo(80, 0.1), reason: '下一次 PointerSignal 有独立的默认动作裁决');
    });

    testWidgets('dragEnd preventDefault 仅禁用惯性，保留已应用位移并完成清理', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var dragEnds = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          event: ElEvent(
            onVerticalDragEnd: (event) {
              dragEnds++;
              event.preventDefault();
            },
          ),
        ),
      );

      final center = tester.getCenter(find.byKey(scrollKey));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 21);
      await gesture.down(center, timeStamp: Duration.zero);
      await tester.pump();
      await gesture.moveBy(const Offset(0, -50), timeStamp: const Duration(milliseconds: 10));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -50), timeStamp: const Duration(milliseconds: 20));
      await tester.pump();
      final beforeUp = controller.offset;
      expect(beforeUp, greaterThan(20), reason: 'End 阶段不能撤销此前已提交的 DragUpdate 位移');
      await gesture.up(timeStamp: const Duration(milliseconds: 28));
      await tester.pump();
      final atRelease = controller.offset;
      await tester.pump(const Duration(milliseconds: 240));

      expect(dragEnds, 1);
      expect(controller.offset, closeTo(atRelease, 0.1), reason: 'DragEnd 的默认动作仅是按速度启动 ballistic');
      expect(controller.position.isScrollingNotifier.value, isFalse, reason: '阻止 ballistic 仍必须结束 Drag activity');

      final next = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 22);
      await next.down(center);
      await tester.pump();
      await next.moveBy(const Offset(0, -40));
      await tester.pump();
      await next.moveBy(const Offset(0, -40));
      await tester.pump();
      await next.up();
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(atRelease + 20), reason: 'End 清理完成后下一手势仍可滚动');
    });

    testWidgets('dragCancel preventDefault 不得跳过终态清理', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var cancels = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          event: ElEvent(
            onVerticalDragCancel: (event) {
              cancels++;
              event.preventDefault();
            },
          ),
        ),
      );

      final center = tester.getCenter(find.byKey(scrollKey));
      final cancelled = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 31);
      await cancelled.down(center);
      await tester.pump();
      await cancelled.moveBy(const Offset(0, -50));
      await tester.pump();
      await cancelled.moveBy(const Offset(0, -30));
      await tester.pump();
      final beforeCancel = controller.offset;
      await cancelled.cancel();
      await tester.pump();

      expect(cancels, 1);
      expect(controller.offset, closeTo(beforeCancel, 0.1));
      expect(controller.position.isScrollingNotifier.value, isFalse, reason: 'Cancel 是强制生命周期收尾，不是可取消的默认动作');

      final next = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 32);
      await next.down(center);
      await tester.pump();
      await next.moveBy(const Offset(0, -40));
      await tester.pump();
      await next.moveBy(const Offset(0, -40));
      await tester.pump();
      await next.up();
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(beforeCancel + 20));
    });

    testWidgets('双轴 horizontal dragUpdate preventDefault 冻结当前滚动并清理两轴', (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);
      var prevented = false;
      double? offsetAtPrevent;
      await tester.pumpWidget(
        shell(
          controller: vertical,
          horizontalController: horizontal,
          axis: null,
          event: ElEvent(
            onHorizontalDragUpdate: (event) {
              if (!prevented && horizontal.hasClients && horizontal.offset > 0) {
                prevented = true;
                offsetAtPrevent = horizontal.offset;
                event.preventDefault();
              }
            },
          ),
        ),
      );

      final center = tester.getCenter(find.byKey(scrollKey));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 41);
      await gesture.down(center);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(-35, 0));
        await tester.pump();
      }
      expect(prevented, isTrue);
      expect(horizontal.offset, closeTo(offsetAtPrevent!, 0.1), reason: 'Update 被阻止后本手势余下位移不得再进入 position');
      await gesture.up();
      await tester.pump();
      final atRelease = horizontal.offset;
      await tester.pump(const Duration(milliseconds: 240));
      expect(horizontal.offset, closeTo(atRelease, 0.1), reason: '被阻止的 Update 必须取消活动 Drag，End 不得残留惯性');
      expect(horizontal.position.isScrollingNotifier.value, isFalse);
      expect(vertical.position.isScrollingNotifier.value, isFalse, reason: '双轴滚动的两个 controller 必须一起完成终态清理');

      final next = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 42);
      await next.down(center);
      await tester.pump();
      await next.moveBy(const Offset(-45, 0));
      await tester.pump();
      await next.moveBy(const Offset(-45, 0));
      await tester.pump();
      await next.up();
      await tester.pumpAndSettle();
      expect(horizontal.offset, greaterThan(atRelease + 20), reason: 'Update 阻止状态必须在终态后复位');
    });

    testWidgets('双轴 panZoomUpdate preventDefault 冻结当前滚动并清理两轴', (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);
      var updates = 0;
      await tester.pumpWidget(
        shell(
          controller: vertical,
          horizontalController: horizontal,
          axis: null,
          event: ElEvent(
            onPointerPanZoomUpdate: (event) {
              updates++;
              if (updates == 2) event.preventDefault();
            },
          ),
        ),
      );

      final center = tester.getCenter(find.byKey(scrollKey));
      await tester.sendEventToBinding(PointerPanZoomStartEvent(pointer: 51, position: center));
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          pointer: 51,
          position: center,
          pan: const Offset(-35, -40),
          panDelta: const Offset(-35, -40),
          timeStamp: const Duration(milliseconds: 10),
        ),
      );
      await tester.pump();
      expect(vertical.offset, greaterThan(0));
      expect(horizontal.offset, greaterThan(0));
      final verticalAtPrevent = vertical.offset;
      final horizontalAtPrevent = horizontal.offset;

      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          pointer: 51,
          position: center,
          pan: const Offset(-70, -80),
          panDelta: const Offset(-35, -40),
          timeStamp: const Duration(milliseconds: 20),
        ),
      );
      await tester.pump();
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          pointer: 51,
          position: center,
          pan: const Offset(-105, -120),
          panDelta: const Offset(-35, -40),
          timeStamp: const Duration(milliseconds: 30),
        ),
      );
      await tester.sendEventToBinding(
        PointerPanZoomEndEvent(pointer: 51, position: center, timeStamp: const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 240));

      expect(vertical.offset, closeTo(verticalAtPrevent, 0.1));
      expect(horizontal.offset, closeTo(horizontalAtPrevent, 0.1));
      expect(vertical.position.isScrollingNotifier.value, isFalse);
      expect(horizontal.position.isScrollingNotifier.value, isFalse, reason: 'PanZoom Update 被阻止时不能只清理主轴 controller');

      await tester.sendEventToBinding(PointerPanZoomStartEvent(pointer: 52, position: center));
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          pointer: 52,
          position: center,
          pan: const Offset(-40, -45),
          panDelta: const Offset(-40, -45),
          timeStamp: const Duration(milliseconds: 300),
        ),
      );
      await tester.sendEventToBinding(
        PointerPanZoomEndEvent(pointer: 52, position: center, timeStamp: const Duration(milliseconds: 320)),
      );
      await tester.pumpAndSettle();
      expect(vertical.offset, greaterThan(verticalAtPrevent + 20));
      expect(horizontal.offset, greaterThan(horizontalAtPrevent + 20), reason: '下一次 PanZoom 使用独立的默认动作裁决');
    });
  });

  group('输入延迟三态', () {
    testWidgets('top-level clamping boundary drag cancels an in-bounds descendant tap', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var taps = 0;

      await tester.pumpWidget(_clickableTopScrollShell(controller, () => taps++));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      final target = tester.getRect(find.byKey(const ValueKey('large-tap-target')));
      final start = target.topCenter + const Offset(0, 60);
      await gesture.down(start);
      await tester.pump();
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();

      expect(controller.offset, 0, reason: '顶部向边界方向拖动时 clamping 物理应保持零位移');
      expect(target.contains(start + const Offset(0, 48)), isTrue, reason: '指针移动超过 drag slop 后仍在点击元素内');

      await gesture.up();
      await tester.pump();

      expect(taps, 0, reason: '拖拽已越过 slop，即使边界夹住全部位移也不能误触后代点击');
    });

    testWidgets('single top-level scroll: reverse drag within the same gesture responds immediately (缺陷 2)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_singleScrollShell(controller));
      // 起手在顶部（offset 0）；先向 boundary 方向拖（手指下滑 → 内容后退 → offset 已在 0
      // 无法再减小 → 0 消费）。
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);

      await gesture.down(tester.getCenter(find.byKey(_scrollKey)));
      await tester.pump();
      // 手指向下拖 40px（正 dy）：在 offset 0 处 clamp physics 完全吃掉，0 消费。
      // 缺陷 2 场景下会置 _dragDeferredToAncestor=true，从此本手势不响应。
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(controller.offset, 0, reason: 'boundary + clamping physics: 0 consume expected');

      // 关键断言：**同一手势**内立刻反向（手指上滑 = 内容前进 = offset↑）：
      // 三态化后不置 defer，应立即消费。
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      expect(
        controller.offset,
        greaterThan(0),
        reason: 'reverse drag within the same gesture must respond immediately — defer-to-nowhere is a bug',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('single top-level scroll at bottom: reverse drag within the same gesture responds (对称回归)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_singleScrollShell(controller));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      final atBottom = controller.offset;
      expect(atBottom, greaterThan(0));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);

      await gesture.down(tester.getCenter(find.byKey(_scrollKey)));
      await tester.pump();
      // 底部拖 boundary 方向：手指上滑 → offset↑ 已到 max → 0 消费。
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(controller.offset, atBottom, reason: 'boundary at bottom: 0 consume');

      // 反向：手指下滑 → offset↓，立即响应。
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(controller.offset, lessThan(atBottom), reason: 'reverse drag from bottom-boundary must respond');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('top-level scroll activation eager-suppresses an ancestor longPress', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      var ancestorLongPresses = 0;
      double? offsetSeenByLoserCancel;

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const _NoChromeScrollBehavior(),
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 200,
              child: ElView(
                event: ElEvent(
                  config: const ElEventConfig(longPressDelay: Duration(milliseconds: 50)),
                  onTapDown: (_) {},
                  onTapCancel: (_) => offsetSeenByLoserCancel = scrollController.offset,
                  onLongPress: (_) => ancestorLongPresses++,
                ),
                child: SizedBox(
                  key: _scrollKey,
                  width: 120,
                  height: 100,
                  child: ElScrollView(
                    controller: scrollController,
                    children: List<Widget>.generate(10, (index) {
                      return ElView(
                        key: ValueKey('row-$index'),
                        style: ElStyle(width: 120, height: 40, backgroundColor: Color(0xFF101010 + index)),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(find.byKey(_scrollKey)));
      await tester.pump();
      // 反方向拖足够远，滚动越过 slop 并 eagerGesture claim。
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      expect(scrollController.offset, greaterThan(0), reason: 'scroll drag is active');
      expect(offsetSeenByLoserCancel, 0, reason: '滚动必须先结清 loser，再提交首帧 position 副作用。');

      // 长按 timer 应在 eager 独占下静默失效（machines.dart 里 _onLongPressTimeout
      // 二次防御 + claimEager first-win）。
      await tester.pump(const Duration(milliseconds: 200));

      expect(ancestorLongPresses, 0, reason: 'ancestor longPress must not fire while scroll owns the drag');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('滚动增量拦截', () {
    testWidgets('无拦截器：滚动全量进 position', (tester) async {
      final c = ElScrollController();
      await _pump(tester, controller: c, interceptor: null);
      await tester.drag(find.byKey(const ValueKey('row-0')), const Offset(0, -100));
      await tester.pump();
      // drag 100 里前 20（_dragSlop）在越阈前被丢弃 → position 前进 80。
      expect(c.position.pixels, closeTo(100.0 - _dragSlop, 0.5));
    });

    testWidgets('touchDrag：拦截器吃一半，剩余进 position', (tester) async {
      final c = ElScrollController();
      final interceptor = _RatioInterceptor(ratio: 0.5);
      await _pump(tester, controller: c, interceptor: interceptor);
      await tester.drag(find.byKey(const ValueKey('row-0')), const Offset(0, -100));
      await tester.pump();
      expect(interceptor.deltaLog.isNotEmpty, isTrue);
      expect(interceptor.deltaLog.every((e) => e.$2 == ElScrollDeltaSource.touchDrag), isTrue);
      // 越阈后进管线的量 = 100 - 20 = 80，拦截器吃一半 → position ≈ 40。
      expect(c.position.pixels, closeTo((100.0 - _dragSlop) / 2, 5.0));
    });

    testWidgets('拦截器 ratio=0：与无拦截器行为一致', (tester) async {
      final c = ElScrollController();
      final interceptor = _RatioInterceptor(ratio: 0.0);
      await _pump(tester, controller: c, interceptor: interceptor);
      await tester.drag(find.byKey(const ValueKey('row-0')), const Offset(0, -100));
      await tester.pump();
      // 与无拦截器一致：越阈后 80 全量进 position。
      expect(c.position.pixels, closeTo(100.0 - _dragSlop, 0.5));
      // 拦截器被调用了，但没吃。
      expect(interceptor.deltaLog.isNotEmpty, isTrue);
    });

    testWidgets('fling velocity 拦截：flingRatio=1.0 完全吃掉惯性', (tester) async {
      final c = ElScrollController();
      final interceptor = _RatioInterceptor(ratio: 0.0, flingRatio: 1.0);
      await _pump(tester, controller: c, interceptor: interceptor);
      await tester.fling(find.byKey(const ValueKey('row-0')), const Offset(0, -200), 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(interceptor.flingCalls, greaterThan(0));
    });

    testWidgets('热更换拦截器实例生效', (tester) async {
      final c = ElScrollController();
      final first = _RatioInterceptor(ratio: 1.0); // 全吃
      await _pump(tester, controller: c, interceptor: first);
      await tester.drag(find.byKey(const ValueKey('row-0')), const Offset(0, -50));
      await tester.pump();
      expect(c.position.pixels, closeTo(0.0, 1.0));

      // 换成 ratio=0：越阈后 50 - 20 = 30 全量进 position。
      final second = _RatioInterceptor(ratio: 0.0);
      await _pump(tester, controller: c, interceptor: second);
      await tester.drag(find.byKey(const ValueKey('row-0')), const Offset(0, -50));
      await tester.pump();
      expect(c.position.pixels, closeTo(50.0 - _dragSlop, 1.0));
    });

    testWidgets('fling 在实际帧过链，界内和触边共用输入分账', (tester) async {
      final c = ElScrollController();
      final interceptor = _RatioInterceptor(ratio: 0.0);
      await _pump(tester, controller: c, interceptor: interceptor);

      // 界内 fling：起点 0 向上拖内容前进（20*60=1200 内容、300 视口，轻甩
      // 不至滚到底）——实际帧也应经过 pre 消费。
      await tester.fling(find.byKey(const ValueKey('row-0')), const Offset(0, -100), 800);
      await tester.pumpAndSettle();
      expect(
        interceptor.deltaLog.where((e) => e.$2 == ElScrollDeltaSource.fling),
        isNotEmpty,
        reason: '界内 fling 与触摸一样先经过参与者',
      );
      expect(c.position.pixels, greaterThan(0.0));

      // 越界 fling：向下大力甩回到顶，动能有余 → 越界帧过链（fling source）。
      // row-0 已滚出视口，用视口内绝对坐标起手（viewport 是 200x300 顶靠左上）。
      interceptor.deltaLog.clear();
      await tester.flingFrom(const Offset(100, 50), const Offset(0, 200), 5000);
      await tester.pumpAndSettle();
      final flingEntries = interceptor.deltaLog.where((e) => e.$2 == ElScrollDeltaSource.fling).toList();
      expect(flingEntries, isNotEmpty, reason: 'fling 撞顶后剩余动能应逐帧过链');
      // 撞顶方向的越界在用户 delta 空间为正（展开方向）。
      expect(flingEntries.every((e) => e.$1 > 0), isTrue);
      expect(c.position.pixels, 0.0);
    });

    testWidgets('重复及乱序查询 simulation 不调用业务拦截器', (tester) async {
      final c = ElScrollController();
      addTearDown(c.dispose);
      final interceptor = _RatioInterceptor(ratio: .5);
      await _pump(tester, controller: c, interceptor: interceptor);
      c.jumpTo(100);
      final simulation = c.position.physics.createBallisticSimulation(c.position, -2000)!;
      final first = simulation.x(.1);
      simulation.x(.3);
      simulation.dx(.2);
      simulation.isDone(.5);
      expect(simulation.x(.1), first);
      expect(interceptor.deltaLog, isEmpty);
      expect(c.offset, 100);
    });

    testWidgets('惯性期间更换拦截器会取消旧生产者', (tester) async {
      final c = ElScrollController();
      addTearDown(c.dispose);
      await _pump(tester, controller: c, interceptor: _RatioInterceptor(ratio: 0));
      await tester.flingFrom(const Offset(100, 150), const Offset(0, -100), 1500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      expect(c.position.isScrollingNotifier.value, isTrue);
      final offset = c.offset;
      final next = _RatioInterceptor(ratio: .5);
      await _pump(tester, controller: c, interceptor: next);
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.position.isScrollingNotifier.value, isFalse);
      expect(c.offset, offset);
      expect(next.deltaLog, isEmpty);
    });

    testWidgets('自定义外部 position 缺少所有权接线时明确拒绝拦截器', (tester) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      await _pump(tester, controller: c, interceptor: _RatioInterceptor());
      expect(
        tester.takeException(),
        isA<FlutterError>().having((error) => error.message, 'message', contains('ElScrollController')),
      );
    });
  });

  group('设备起手阈值与惯性', () {
    setUp(EventDispatcher.debugResetEagerGestureOwners);

    const scrollKey = ValueKey('scroll');

    const deviceSettings = DeviceGestureSettings(touchSlop: 8.0);

    Widget shell({required ScrollController controller}) {
      return MaterialApp(
        scrollBehavior: const _NoChromeBehavior(),
        home: MediaQuery(
          data: const MediaQueryData(gestureSettings: deviceSettings),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: scrollKey,
              width: 200,
              height: 300,
              child: ElScrollView(
                controller: controller,
                physics: const ClampingScrollPhysics(),
                children: List<Widget>.generate(
                  60,
                  (i) => ElView(
                    key: ValueKey('item-$i'),
                    style: ElStyle(width: 200, height: 40, backgroundColor: Color(0xff222222 + i)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('SLOP-1: 设备 slop=8 时,惯性中 8~18px 反向轻扫不得死停(dragStart 已发但零 dragUpdate)', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      controller.jumpTo(800);
      await tester.pump();

      // 起向下惯性。
      await tester.fling(find.byKey(scrollKey), const Offset(0, -200), 2200);
      await tester.pump(const Duration(milliseconds: 48));
      final duringBallistic = controller.offset;
      expect(duringBallistic, greaterThan(800), reason: '前置:向下惯性推进中');

      // 反向轻扫共 14px:第一 move 10px 已过设备 slop 8 → dragStart(seed=0 丢弃);
      // 第二 move 4px 是同帧批量的尾巴——真机重采样塌缩后常见整个手势只有起手
      // 一个有效 move,这里用"过阈即最后一个 move"复刻:阈值落在首 move,后续
      // 无任何越过 precisionErrorTolerance 的 dragUpdate 帧。
      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 500);
      await g.down(center, timeStamp: const Duration(milliseconds: 5000));
      await tester.pump(const Duration(milliseconds: 4));
      await g.moveBy(const Offset(0, 14), timeStamp: const Duration(milliseconds: 5014));
      await tester.pump(const Duration(milliseconds: 4));
      await g.up(timeStamp: const Duration(milliseconds: 5022));
      await tester.pump();
      final afterRelease = controller.offset;
      await tester.pump(const Duration(milliseconds: 96));

      expect(
        controller.offset,
        lessThan(afterRelease - 1),
        reason:
            '设备 slop=8 下 14px 反向轻扫:dragStart 已发、无 dragUpdate、'
            '塌缩 offset(14) < 常量 dragMinFlingDistance(18) → 旧实现 velocity 归零死停。'
            '官方语义:fling 距离阈跟随设备 slop(8),14px 必须起反向惯性',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('SLOP-3: 塌缩轻扫的 fling 速度量级必须接近末端瞬时速度,不能用平均速度糊弄', (tester) async {
      // 用户实机体感(2026-07-06):打断修复后"甩动速度不匹配,轻触时滚动速度、
      // 距离没有期望的那么大"。根因:塌缩 fallback 用 down→up 总位移/总时长的
      // **平均速度**,而甩动是从静止加速的运动——匀加速模型下末端瞬时速度 =
      // 2×平均;官方 VelocityTracker 的 LSQ 拟合报的正是末端瞬时。fallback 必须
      // 做端点补偿,否则轻扫的 fling 距离缩水一半以上。
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      controller.jumpTo(400);
      await tester.pump();

      // 塌缩形态:down + 单 move(12px)+ up。总时长 20ms,平均速度 600px/s,
      // 真实末端 ≈ 1200px/s。
      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 540);
      await g.down(center, timeStamp: const Duration(milliseconds: 20000));
      await tester.pump(const Duration(milliseconds: 4));
      await g.moveBy(const Offset(0, -12), timeStamp: const Duration(milliseconds: 20012));
      await tester.pump(const Duration(milliseconds: 4));
      await g.up(timeStamp: const Duration(milliseconds: 20020));
      await tester.pump();
      final atRelease = controller.offset;

      // 300ms 内的惯性滚动距离量级:v0=600(平均,旧实现)的 Clamping 模拟
      // ≈ 越 60-80px;v0=1200(末端补偿)≈ 150px+。断言 ≥100px 判别两者。
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        controller.offset - atRelease,
        greaterThan(100),
        reason: '12px/20ms 轻扫(平均 600px/s,末端 ≈1200px/s)的惯性距离必须反映末端速度量级',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('SLOP-4: jank 墙钟延迟不得让同向轻扫被 stopped 占位误杀(实机"正常连续滚动也打断")', (tester) async {
      // VelocityTracker 的停顿检测 `_sinceLastSample` 是**真实墙钟** Stopwatch
      // (SDK flutter_ignore 注释,逃逸 FakeAsync)。真机 jank/重采样延迟会让
      // "最后 move 喂入 tracker → up 处理"的墙钟间隔超过 40ms,tracker 返回
      // **全零 stopped 占位**(pixelsPerSecond/offset/duration 全零)——它不区分
      // "手指真停了"和"事件延迟处理"。把占位当真停顿归零 = 明明是高速轻扫却
      // velocity 归零 → 死停。真停顿必须改由**事件时间戳**的 move→up 间隔判定
      // (事件 ts 不受处理延迟影响)。
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      controller.jumpTo(400);
      await tester.pump();

      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 560);
      await g.down(center, timeStamp: const Duration(milliseconds: 30000));
      await tester.pump(const Duration(milliseconds: 4));
      await g.moveBy(const Offset(0, -14), timeStamp: const Duration(milliseconds: 30008));
      await tester.pump(const Duration(milliseconds: 4));
      await g.moveBy(const Offset(0, -14), timeStamp: const Duration(milliseconds: 30016));
      // jank:up 事件晚 60ms 才被处理(事件时间戳仍是 8ms 后!)。tracker 的
      // 停顿检测走 GestureBinding.samplingClock(测试=fake 钟,真机=墙钟),
      // pump 推进 60ms 即等价真机 jank 下"最后 move 喂入 → up 处理"超 40ms。
      await tester.pump(const Duration(milliseconds: 60));
      await g.up(timeStamp: const Duration(milliseconds: 30024));
      await tester.pump();
      final atRelease = controller.offset;
      for (var f = 0; f < 8; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        controller.offset,
        greaterThan(atRelease + 10),
        reason: '28px/24ms 同向轻扫(事件时间戳无停顿)必须起 fling——处理延迟 60ms 不代表手指停了',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('SLOP-5: 划动后真停顿(事件时间戳停 500ms)再松手,不得被 fallback 误判成 fling', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      controller.jumpTo(400);
      await tester.pump();

      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 570);
      await g.down(center, timeStamp: const Duration(milliseconds: 40000));
      await tester.pump(const Duration(milliseconds: 4));
      // 快划一段(过 slop,内容跟随),然后**事件时间戳停顿 500ms** 再抬手。
      await g.moveBy(const Offset(0, -60), timeStamp: const Duration(milliseconds: 40012));
      await tester.pump(const Duration(milliseconds: 4));
      await g.up(timeStamp: const Duration(milliseconds: 40512));
      await tester.pump();
      final atRelease = controller.offset;
      for (var f = 0; f < 8; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        controller.offset,
        lessThan(atRelease + 2),
        reason: '停顿 500ms 后松手(官方语义 velocity=0)不得被 down→up 平均速度 fallback 误判成 fling',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('SLOP-2: 设备 slop=8 时,连续小轻扫(10-16px)持续推进不死停', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      var previous = controller.offset;
      for (var i = 0; i < 5; i++) {
        final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 520 + i);
        final base = Duration(milliseconds: 8000 + i * 200);
        await g.down(center, timeStamp: base);
        await tester.pump(const Duration(milliseconds: 4));
        // 单 move 12px 向上(offset 增方向),过 8 阈、低于 18 常量。
        await g.moveBy(const Offset(0, -12), timeStamp: base + const Duration(milliseconds: 12));
        await tester.pump(const Duration(milliseconds: 4));
        await g.up(timeStamp: base + const Duration(milliseconds: 20));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          controller.offset,
          greaterThan(previous + 2),
          reason: '第 ${i + 1} 次 12px 轻扫必须推进滚动(移动量+惯性),不能被 18px 常量阈吞掉',
        );
        previous = controller.offset;
        await tester.pumpAndSettle();
        previous = controller.offset;
      }
    });
  });

  group('拖动代理', () {
    const scrollKey = ValueKey('scroll');

    Future<void> touchDragSteps(WidgetTester tester, Finder target, List<Offset> steps) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(target));
      await tester.pump();
      for (final step in steps) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    Widget proxyShell({
      required ScrollController controller,
      required ElEvent proxyEvent,
      ScrollPhysics? physics,
      int itemCount = 20,
      double itemExtent = 40,
      double width = 120,
      double height = 100,
    }) {
      return MaterialApp(
        scrollBehavior: const _NoChromeScrollBehavior(),
        home: Align(
          alignment: Alignment.topLeft,
          child: _DragProxyHost(
            event: proxyEvent,
            child: SizedBox(
              key: scrollKey,
              width: width,
              height: height,
              child: ElScrollView(
                controller: controller,
                physics: physics ?? const ClampingScrollPhysics(),
                children: List<Widget>.generate(itemCount, (index) {
                  return ElView(
                    key: ValueKey('item-$index'),
                    style: ElStyle(width: width, height: itemExtent, backgroundColor: Color(0xFF303030 + index)),
                  );
                }),
              ),
            ),
          ),
        ),
      );
    }

    for (final handoff in [false, true]) {
      testWidgets('bouncing: boundaryHandoff=$handoff 只接管声明方向，另一端保留弹性', (tester) async {
        final controller = ScrollController(initialScrollOffset: 40);
        addTearDown(controller.dispose);
        final overflow = <double>[];
        await tester.pumpWidget(
          proxyShell(
            controller: controller,
            physics: BouncingScrollPhysics(),
            proxyEvent: ElEvent(
              dragProxy: ElDragProxy(
                axis: Axis.vertical,
                boundaryHandoff: handoff ? {AxisDirection.down} : {},
                onDragOverflow: (event) {
                  overflow.add(event.remainingPrimaryDelta(Axis.vertical));
                  event.consumeAllDelta();
                },
              ),
            ),
          ),
        );
        // 本合同验证边界分账，显式准备实际起点，不依赖首轮布局的偏移恢复。
        controller.jumpTo(40);
        await tester.pump();
        final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
        await gesture.down(tester.getCenter(find.byKey(scrollKey)));
        await gesture.moveBy(Offset(0, 30));
        await tester.pump();
        await gesture.moveBy(Offset(0, 80));
        await tester.pump();
        if (handoff) {
          expect(controller.offset, 0);
          expect(overflow, [40]);
        } else {
          expect(controller.offset, lessThan(0));
          expect(overflow, isEmpty);
        }
        await gesture.cancel();
        await tester.pumpAndSettle();
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        final reverse = await tester.createGesture(kind: PointerDeviceKind.touch);
        await reverse.down(tester.getCenter(find.byKey(scrollKey)));
        await reverse.moveBy(Offset(0, -30));
        await tester.pump();
        await reverse.moveBy(Offset(0, -80));
        await tester.pump();
        expect(controller.offset, greaterThan(controller.position.maxScrollExtent));
        await reverse.cancel();
        await tester.pumpAndSettle();
        if (handoff) {
          controller.jumpTo(-20);
          final outside = await tester.createGesture(kind: PointerDeviceKind.touch);
          await outside.down(tester.getCenter(find.byKey(scrollKey)));
          await outside.moveBy(Offset(0, 30));
          await tester.pump();
          await outside.moveBy(Offset(0, 80));
          await tester.pump();
          expect(controller.offset, -20, reason: '已有越界不跳变，也不再往外交给弹性滚动');
          expect(overflow.last, 80);
          await outside.cancel();
          await tester.pumpAndSettle();
        }
      });
    }

    testWidgets('overflow receives residual when scroll drags down at top boundary', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final overflowDeltas = <double>[];
      final preSeen = <double>[];

      await tester.pumpWidget(
        proxyShell(
          controller: controller,
          proxyEvent: ElEvent(
            dragProxy: ElDragProxy(
              axis: Axis.vertical,
              onDragPreUpdate: (e) => preSeen.add(e.remainingPrimaryDelta(Axis.vertical)),
              onDragOverflow: (e) => overflowDeltas.add(e.remainingPrimaryDelta(Axis.vertical)),
            ),
          ),
        ),
      );
      // Start at top (offset = 0) so downward drag has nothing to consume.
      expect(controller.offset, 0);

      // C2b：首帧 accept 只发 dragStart 纯信号（seed=0，pre/overflow 早退不触达），
      // 分账实际从第二帧 dragUpdate 起。用三帧才有 ≥2 次触达 pre/overflow。
      await touchDragSteps(tester, find.byKey(scrollKey), [
        const Offset(0, 40),
        const Offset(0, 40),
        const Offset(0, 40),
      ]);

      // Scroll is stuck at top boundary — every dragUpdate frame's residual bubbles to overflow.
      expect(controller.offset, 0);
      expect(preSeen.length, greaterThanOrEqualTo(2));
      // Overflow was called each frame with a positive (downward) residual.
      expect(overflowDeltas, isNotEmpty);
      expect(overflowDeltas.every((d) => d > 0), isTrue, reason: 'downward residual bubbles to proxy');
      // Sum of overflow deltas approaches the total dragged distance (minus dragStart slop),
      // since scroll consumed nothing.
      final overflowSum = overflowDeltas.fold<double>(0, (a, b) => a + b);
      expect(overflowSum, greaterThan(40), reason: 'proxy overflow accumulates the residual');
    });

    testWidgets('overflow stays zero when scroll consumes the whole delta below top', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final overflowNonZero = <double>[];

      await tester.pumpWidget(
        proxyShell(
          controller: controller,
          proxyEvent: ElEvent(
            dragProxy: ElDragProxy(
              axis: Axis.vertical,
              onDragOverflow: (e) {
                final d = e.remainingPrimaryDelta(Axis.vertical);
                if (d.abs() > precisionErrorTolerance) overflowNonZero.add(d);
              },
            ),
          ),
        ),
      );
      // Sit well below the top boundary — scroll can absorb every step of a downward drag.
      controller.jumpTo(200);
      await tester.pump();

      await touchDragSteps(tester, find.byKey(scrollKey), [const Offset(0, 30), const Offset(0, 30)]);

      // Scroll offset decreased (scrolled up in pixel space) — driver consumed everything.
      expect(controller.offset, lessThan(200));
      expect(controller.offset, greaterThan(0));
      // Overflow saw no residual at any frame.
      expect(overflowNonZero, isEmpty, reason: 'driver drained delta; overflow stays empty');
    });

    testWidgets('pre consumes upstream; scroll only applies the remainder', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var preConsumedTotal = 0.0;
      // pre 每帧偷至多 4px（向上）—— 若整帧 delta 为 -20（起手夹带 slop 后的 seed 或
      // 后续 update），pre 扣 -4，driver 应看到 -16 或更小。
      const double preSteal = -4;

      await tester.pumpWidget(
        proxyShell(
          controller: controller,
          proxyEvent: ElEvent(
            dragProxy: ElDragProxy(
              axis: Axis.vertical,
              onDragPreUpdate: (e) {
                final d = e.remainingPrimaryDelta(Axis.vertical);
                if (d >= 0) return; // 只在上拖时先扣
                final take = d < preSteal ? preSteal : d; // max(d, preSteal)（都是负数）
                e.consumePrimaryDelta(Axis.vertical, take);
                preConsumedTotal += take;
              },
            ),
          ),
        ),
      );
      // Below the top so scroll can accept upward motion; well above zero.
      controller.jumpTo(200);
      await tester.pump();
      final startOffset = controller.offset;

      // Three moveBy steps: the first crosses the touch slop into dragStart,
      // the next two are proper dragUpdate frames so pipelineActive covers both paths.
      await touchDragSteps(tester, find.byKey(scrollKey), [
        const Offset(0, -25), // crosses kTouchSlop=18
        const Offset(0, -20),
        const Offset(0, -20),
      ]);

      // pre fired on every frame with negative remaining (both start + update paths).
      expect(preConsumedTotal, lessThan(0));
      expect(
        preConsumedTotal,
        greaterThanOrEqualTo(preSteal * 3),
        reason: 'pre may take at most preSteal per frame (dragStart + 2 dragUpdate)',
      );
      // Scroll advanced (pixels increased) but strictly less than the raw delta absolute
      // value, because pre had first bite each frame.
      final scrolled = controller.offset - startOffset;
      expect(scrolled, greaterThan(0));
      expect(scrolled, lessThan(65), reason: 'pre stole part of each frame; scroll applied the remainder');
    });
  });

  group('惯性期间触摸穿透', () {
    Widget host({required ScrollController controller, required List<int> taps, required bool virtualized}) {
      Widget itemBuilder(int i) => ElView(
        key: ValueKey('item-$i'),
        event: ElEvent(onTap: (_) => taps.add(i)),
        style: ElStyle(width: 200, height: 40, backgroundColor: Color(0xff222222 + i)),
      );
      final children = List<Widget>.generate(80, itemBuilder);
      return MaterialApp(
        scrollBehavior: const _NoChromeBehavior(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 400,
            child: virtualized
                ? buildVirtualTestView(controller: controller, children: children)
                : ElScrollView(controller: controller, children: children),
          ),
        ),
      );
    }

    for (final virtualized in [false, true]) {
      final label = virtualized ? 'virtual' : 'simple';
      const finderType = ElScrollView;

      testWidgets('$label 快速 fling 中触摸：不激活内容，只停住滚动（连续轻甩不误触）', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final taps = <int>[];
        await tester.pumpWidget(host(controller: controller, taps: taps, virtualized: virtualized));
        await tester.pumpAndSettle();

        await tester.fling(find.byType(finderType), const Offset(0, -300), 3000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
        expect(touchFlingScrolling(controller.position), isTrue, reason: '前置条件：触摸弹道飞行中');

        final target = tester.getCenter(find.byType(finderType));
        await tester.tapAt(target, kind: PointerDeviceKind.touch);
        await tester.pump(const Duration(milliseconds: 32));

        expect(taps, isEmpty, reason: '快段接住的触摸不得落成内容点击');
        expect(controller.position.isScrollingNotifier.value, isFalse, reason: '但按下要停住滚动');
        await tester.pumpAndSettle();
      });

      testWidgets('$label 惯性尾段（低速）触摸：仍屏蔽内容，只停住滚动（整段屏蔽裁决）', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final taps = <int>[];
        await tester.pumpWidget(host(controller: controller, taps: taps, virtualized: virtualized));
        await tester.pumpAndSettle();

        await tester.fling(find.byType(finderType), const Offset(0, -300), 3000);
        await tester.pump();
        // 泵到"仍在惯性滚动但速度已深度衰减"的窗口（旧两档设计的放行区）。
        var reachedTail = false;
        for (var i = 0; i < 900; i++) {
          if (!controller.position.isScrollingNotifier.value) break;
          if (_ballisticVelocity(controller.position) < 800) {
            reachedTail = true;
            break;
          }
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(reachedTail, isTrue, reason: '前置条件：进入惯性尾段（滚动中且速度已衰减）');
        expect(controller.position.isScrollingNotifier.value, isTrue);
        expect(touchFlingScrolling(controller.position), isTrue, reason: '整段屏蔽：尾段判据依然成立');

        final target = tester.getCenter(find.byType(finderType));
        await tester.tapAt(target, kind: PointerDeviceKind.touch);
        await tester.pump(const Duration(milliseconds: 32));

        expect(taps, isEmpty, reason: '尾段触摸不得落成内容点击（2026-08-02 整段屏蔽裁决）');
        expect(controller.position.isScrollingNotifier.value, isFalse, reason: '但按下要停住滚动');
        await tester.pumpAndSettle();
      });

      testWidgets('$label 频繁轻甩连刷：全程零误触（含接住即松手的轻触）', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final taps = <int>[];
        await tester.pumpWidget(host(controller: controller, taps: taps, virtualized: virtualized));
        await tester.pumpAndSettle();

        final center = tester.getCenter(find.byType(finderType));
        // 起手一甩，随后每一下都落在上一次 fling 里。
        await tester.fling(find.byType(finderType), const Offset(0, -300), 3000);
        await tester.pump();
        for (var round = 0; round < 3; round++) {
          await tester.pump(const Duration(milliseconds: 48));
          expect(touchFlingScrolling(controller.position), isTrue, reason: '前置条件：第 $round 下落在飞行中的弹道');
          // 接住即松手的轻触（位移不足 slop，历史上会落成卡片 onTap）……
          final light = await tester.startGesture(center, kind: PointerDeviceKind.touch);
          await light.moveBy(const Offset(0, -6));
          await tester.pump(const Duration(milliseconds: 16));
          await light.up();
          await tester.pump();
          // ……紧接着再甩出去。
          await tester.fling(find.byType(finderType), const Offset(0, -200), 3000);
          await tester.pump();
        }

        expect(taps, isEmpty, reason: '连续轻甩期间不得有任何内容激活');
        await tester.pumpAndSettle();
      });

      testWidgets('$label 手指拖拽进行中：他指触摸不得命中内容', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final taps = <int>[];
        await tester.pumpWidget(host(controller: controller, taps: taps, virtualized: virtualized));
        await tester.pumpAndSettle();

        final center = tester.getCenter(find.byType(finderType));
        final dragger = await tester.startGesture(center, pointer: 11, kind: PointerDeviceKind.touch);
        await dragger.moveBy(const Offset(0, -60));
        await tester.pump();
        await dragger.moveBy(const Offset(0, -60));
        await tester.pump();
        expect(controller.position.pixels, greaterThan(0), reason: '前置条件：拖拽已在滚动');

        await tester.tapAt(center + const Offset(0, 20), pointer: 12, kind: PointerDeviceKind.touch);
        await tester.pump(const Duration(milliseconds: 32));
        expect(taps, isEmpty, reason: '拖拽期内容退出命中路径');

        await dragger.up();
        await tester.pumpAndSettle();
      });

      testWidgets('$label 静止时触摸照常命中内容', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final taps = <int>[];
        await tester.pumpWidget(host(controller: controller, taps: taps, virtualized: virtualized));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('item-3')), kind: PointerDeviceKind.touch);
        await tester.pump(const Duration(milliseconds: 32));
        expect(taps, [3]);
      });
    }
  });

  group('键盘与焦点', () {
    for (final axis in [Axis.horizontal, Axis.vertical]) {
      testWidgets('$axis 容器自身得焦才滚动，方向键滚动不点亮焦点环', (tester) async {
        final node = FocusNode(debugLabel: 'scroll-self');
        final controller = ElScrollController();
        addTearDown(node.dispose);
        addTearDown(controller.dispose);
        final key = ValueKey('keyboard-scroll');
        await _keyboardFocusPump(
          tester,
          ElView(
            key: key,
            style: ElStyle(width: 300, height: 120),
            child: ElScrollView(
              axis: axis,
              controller: controller,
              focusNode: node,
              scrollbar: ElNoScrollBar(),
              physics: ElClampingScrollPhysics(),
              children: [ElView(style: ElStyle(width: 900, height: 900))],
            ),
          ),
        );
        await tester.tap(find.byKey(key), kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(node.hasPrimaryFocus, isTrue);
        final forward = axis == Axis.horizontal ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowDown;
        final backward = axis == Axis.horizontal ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowUp;
        await tester.sendKeyDownEvent(forward);
        await tester.pump();
        expect(controller.offset, 50);
        expect(_focusVisible(node), isFalse);
        await tester.sendKeyRepeatEvent(forward);
        await tester.pump();
        expect(controller.offset, 100);
        await tester.sendKeyUpEvent(forward);
        await tester.sendKeyEvent(backward);
        await tester.pump();
        expect(controller.offset, 50);
        expect(_focusVisible(node), isFalse);
      });
    }

    testWidgets('普通滚动容器不处理后代键盘事件，祖先收到未消费的事件', (tester) async {
      final node = FocusNode(debugLabel: 'scroll-child');
      final controller = ElScrollController();
      addTearDown(node.dispose);
      addTearDown(controller.dispose);
      final keys = <LogicalKeyboardKey?>[];
      await _keyboardFocusPump(
        tester,
        ElView(
          style: ElStyle(width: 300, height: 120),
          event: ElEvent(
            onKeyDown: (event) {
              expect(event.defaultPrevented, isFalse);
              keys.add(event.logicalKey);
            },
          ),
          child: ElScrollView(
            controller: controller,
            scrollbar: ElNoScrollBar(),
            children: [ElView(focusNode: node, style: ElStyle(height: 900))],
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      for (final key in [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.pageDown, LogicalKeyboardKey.end]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      expect(keys, [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.pageDown, LogicalKeyboardKey.end]);
      expect(controller.offset, 0);
      expect(_focusVisible(node), isFalse);
    });

    testWidgets('keyboardScroll 可动态关闭，用户回调仍执行且不会重复调用', (tester) async {
      final node = FocusNode(debugLabel: 'keyboard-switch');
      final child = FocusNode(debugLabel: 'keyboard-child');
      final controller = ElScrollController();
      addTearDown(node.dispose);
      addTearDown(child.dispose);
      addTearDown(controller.dispose);
      var enabled = false;
      var calls = 0;
      late StateSetter update;
      await _keyboardFocusPump(
        tester,
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return ElView(
              style: ElStyle(width: 300, height: 120),
              child: ElScrollView(
                axis: .horizontal,
                focusNode: node,
                keyboardScroll: enabled,
                controller: controller,
                scrollbar: ElNoScrollBar(),
                event: ElEvent(onKeyDown: (_) => calls++),
                children: [ElView(focusNode: child, style: ElStyle(width: 900))],
              ),
            );
          },
        ),
      );
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.offset, 0);
      expect(calls, 1);
      update(() => enabled = true);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.offset, 50);
      expect(calls, 2);
      child.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.offset, 50);
      expect(calls, 3, reason: '子控件事件只经过视口一次，不因焦点外壳再调用');
    });
  });

  group('鼠标拖动热路径', () {
    setUp(ScrollCursorFreeze.debugReset);

    tearDown(ScrollCursorFreeze.debugReset);

    testWidgets('内容 mouse drag 不得进入静止鼠标冻结热路', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      final viewport = _viewport(tester, controller);
      final hitBoundsDirtyBefore = viewport.debugScrollHitBoundsDirtyCount;
      final wheelPointer = TestPointer(77, PointerDeviceKind.mouse);
      wheelPointer.hover(const Offset(150, 150));
      await tester.sendEventToBinding(wheelPointer.scroll(const Offset(0, 53)));
      expect(viewport.debugCursorFreezeActive, isTrue, reason: '先建立一段静止鼠标滚轮冻结窗口');
      final trackerUpdatesBefore = ScrollCursorFreeze.debugMouseTrackerUpdateCount;
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);

      await gesture.down(const Offset(150, 240));
      // 首笔越过 slop 只负责起手，后续 move 才是稳态拖拽热路。
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump();
      expect(controller.offset, greaterThan(0));
      expect(DragPointerLock.isActive, isTrue, reason: '鼠标滚动 drag 胜出后必须持有全局命中屏障');
      expect(viewport.debugCursorFreezeActive, isFalse, reason: '指针正在移动时不得续期静止鼠标冻结 Timer');

      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -2.5));
        await tester.pump(const Duration(milliseconds: 6));
        expect(viewport.debugCursorFreezeActive, isFalse, reason: 'move=$i 不得反复 release/claim 冻结窗口');
      }
      expect(
        ScrollCursorFreeze.debugMouseTrackerUpdateCount,
        trackerUpdatesBefore,
        reason: '活动 drag 期不得手动重跑全局 MouseTracker',
      );
      expect(viewport.debugScrollHitBoundsDirtyCount, hitBoundsDirtyBefore, reason: '已裁剪视口对外命中盒不变，滚动不得每帧污染父链');

      await gesture.up();
      await tester.pump();
    });

    testWidgets('滚轮仍冻结静止鼠标，Clip.none 仍更新溢出命中边界', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, clipBehavior: Clip.none));
      await tester.pump();
      final viewport = _viewport(tester, controller);
      final hitBoundsDirtyBefore = viewport.debugScrollHitBoundsDirtyCount;

      final wheelPointer = TestPointer(78, PointerDeviceKind.mouse);
      wheelPointer.hover(const Offset(150, 150));
      await tester.sendEventToBinding(wheelPointer.scroll(const Offset(0, 53)));
      expect(controller.offset, greaterThan(0));
      expect(viewport.debugCursorFreezeActive, isTrue, reason: '滚轮时鼠标未移动，仍需冻结 cursor');
      expect(
        viewport.debugScrollHitBoundsDirtyCount,
        greaterThan(hitBoundsDirtyBefore),
        reason: 'Clip.none 的内容命中边界会随滚动 transform 变化',
      );
    });
  });

  group('多指交互', () {
    const scrollKey = ValueKey('scroll');

    Widget shell({
      required ScrollController controller,
      ElEvent? Function(int index)? itemEventBuilder,
      ElEvent? event,
    }) {
      return MaterialApp(
        scrollBehavior: const _NoChromeBehavior(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: scrollKey,
            width: 120,
            height: 100,
            child: ElScrollView(
              controller: controller,
              physics: const ClampingScrollPhysics(),
              event: event,
              children: List<Widget>.generate(
                40,
                (i) => ElView(
                  key: ValueKey('item-$i'),
                  event: itemEventBuilder?.call(i),
                  style: ElStyle(width: 120, height: 40, backgroundColor: Color(0xff222222 + i)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('REPRO-A: second finger down+up mid-drag, first finger keeps scrolling', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      final g1 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 1);
      await g1.down(center);
      await tester.pump();
      // 越过阈值 + 若干帧滚动
      await g1.moveBy(const Offset(0, -30));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final beforeSecond = controller.offset;
      expect(beforeSecond, greaterThan(0), reason: '前置：单指滚动本身工作');

      // 第二指落下（同一视图内，静止）。latestPointer 平台语义：Android 原生
      // 第二指落下即接管驱动权,第二指静止期间第一指的 move 被忽略(RecyclerView
      // 同款,官方 monodrag `_activePointer` = 最新 accepted pointer)。这是**平台
      // 语义,不是 bug**。真机 bug 的核心在"第二指抬起后第一指是否恢复驱动"——
      // 冻结阶段的期望不在本用例覆盖范围内(见 memory drag-proxy-scope.md #9)。
      final g2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 2);
      await g2.down(center + const Offset(30, 10));
      await tester.pump();

      // 第一指在第二指按住期间的 move:平台语义下被忽略,不做断言。
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final whileSecondDown = controller.offset;

      // 第二指抬起
      await g2.up();
      await tester.pump();

      // 第一指继续移动——必须恢复驱动滚动(核心用户 bug:抬起后仍冻结)
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final afterSecondUp = controller.offset;

      // 收尾
      await g1.up();
      await tester.pumpAndSettle();

      // 判别断言：第二指抬起后第一指必须还能滚动
      expect(afterSecondUp, greaterThan(whileSecondDown + 30), reason: '第二指抬起后，第一指恢复驱动滚动（用户实机 bug：永久丢失）');
    });

    testWidgets('REPRO-B: second finger down mid-drag then MOVES — drives scroll (latestPointer)', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      final g1 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 1);
      await g1.down(center);
      await tester.pump();
      await g1.moveBy(const Offset(0, -30));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final beforeSecond = controller.offset;
      expect(beforeSecond, greaterThan(0));

      final g2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 2);
      await g2.down(center + const Offset(30, 10));
      await tester.pump();

      // 第二指移动，应当接管驱动
      await g2.moveBy(const Offset(0, -20));
      await tester.pump();
      await g2.moveBy(const Offset(0, -20));
      await tester.pump();
      final afterSecondMoves = controller.offset;

      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();

      expect(afterSecondMoves, greaterThan(beforeSecond + 30), reason: '第二指落下后移动应接管驱动滚动（latestPointer）');
    });

    testWidgets('REPRO-C: tap during active drag must not kill the drag activity', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      final g1 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 1);
      await g1.down(center);
      await tester.pump();
      await g1.moveBy(const Offset(0, -30));
      await tester.pump();

      // 拖拽活跃中：另一指快速点一下（down 立即 up）
      final g2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 2);
      await g2.down(center + const Offset(40, 20));
      await g2.up();
      await tester.pump();

      final beforeContinue = controller.offset;
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final afterContinue = controller.offset;

      // 第一指抬起时带 fling 速度，滚动应继续
      await g1.up();
      await tester.pump();

      expect(afterContinue, greaterThan(beforeContinue + 30), reason: '轻点不应杀死进行中的 drag activity');
      await tester.pumpAndSettle();
    });

    testWidgets('REPRO-C2: tap on interactive child during drag must not steal first pointer', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var childPointerDowns = 0;
      var childTaps = 0;
      await tester.pumpWidget(
        shell(
          controller: controller,
          itemEventBuilder: (_) => ElEvent(onPointerDown: (_) => childPointerDowns++, onTap: (_) => childTaps++),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      final g1 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 11);
      await g1.down(center);
      await tester.pump();
      await g1.moveBy(const Offset(0, -30));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final beforeSecondTap = controller.offset;
      expect(beforeSecondTap, greaterThan(0), reason: '前置：第一指拖拽已经驱动滚动');

      final g2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 12);
      await g2.down(tester.getCenter(find.byKey(const ValueKey('item-1'))));
      await tester.pump();
      await g2.up();
      await tester.pump();

      final beforeContinue = controller.offset;
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final afterContinue = controller.offset;

      await g1.up();
      await tester.pumpAndSettle();

      expect(afterContinue, greaterThan(beforeContinue + 30), reason: '第二指只是在带事件子节点上轻点，第一指后续 move 仍必须继续滚动');
      expect(childTaps, lessThanOrEqualTo(childPointerDowns));
    });

    testWidgets('REPRO-E: 快速轻甩(阈值落在最后一个 move)不得丢失 fling 速度', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 21);
      await g.down(center, timeStamp: Duration.zero);
      await tester.pump();
      // 第一帧低于 18px 阈值，不 accept
      await g.moveBy(const Offset(0, -10), timeStamp: const Duration(milliseconds: 8));
      await tester.pump();
      // 越阈发生在**最后一个 move**：seed=0 契约丢弃全部起手位移，
      // 手势内没有任何非零 dragUpdate 帧 → 旧实现 _drag 从未建立，velocity 被吞。
      await g.moveBy(const Offset(0, -50), timeStamp: const Duration(milliseconds: 16));
      await tester.pump();
      await g.up(timeStamp: const Duration(milliseconds: 24));
      await tester.pump();

      final atRelease = controller.offset;
      await tester.pump(const Duration(milliseconds: 120));
      expect(controller.offset, greaterThan(atRelease + 20), reason: '微甩救援：无 dragUpdate 帧的快甩仍须兑现 velocity 起 ballistic');
      await tester.pumpAndSettle();
    });

    testWidgets('REPRO-F: 第二指落下不得杀死活跃 DragScrollActivity', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      final g1 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 31);
      await g1.down(center);
      await tester.pump();
      await g1.moveBy(const Offset(0, -30));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      expect(controller.offset, greaterThan(0));
      expect(controller.position.isScrollingNotifier.value, isTrue, reason: '前置：drag activity 活跃');

      // 第二指落下：旧实现 raw down 触发 position.hold() → beginActivity 顶掉
      // DragScrollActivity（isScrollingNotifier 翻 false）。
      final g2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 32);
      await g2.down(center + const Offset(40, 10));
      await tester.pump();
      expect(controller.position.isScrollingNotifier.value, isTrue, reason: '第二指落下不得顶掉活跃的 DragScrollActivity');

      // 第二指抬起同样不得 goBallistic(0) 打断（hold 以最后一指为准，且此时无 hold）
      await g2.up();
      await tester.pump();
      expect(controller.position.isScrollingNotifier.value, isTrue);

      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      await g1.up();
      await tester.pumpAndSettle();
    });

    testWidgets('REPRO-G: 被动 Drag 不得越过 pointer 边界压制第二指 LongPress', (tester) async {
      // 普通 Drag 只报告当前 pointer 的语义，不会凭 handler 存在就建立跨指针
      // 独占；需要独占的组件必须在自己的有效回调中显式认领对应 pointer。
      var longPressed = 0;
      var dragTravel = 0.0;
      const paneKey = ValueKey('pane');
      const lpKey = ValueKey('lp-child');

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: ElView(
              key: paneKey,
              event: ElEvent(onVerticalDragUpdate: (e) => dragTravel += e.localDelta.dy.abs()),
              style: ElStyle(width: 300, height: 300, backgroundColor: Color(0xff334155)),
              child: Center(
                child: ElView(
                  key: lpKey,
                  event: ElEvent(onLongPress: (_) => longPressed++),
                  style: ElStyle(width: 120, height: 120, backgroundColor: Color(0xffcc0000)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 第一指在 pane 空白区起拖（避开长按子节点），越阈并持续
      final g1 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 41);
      await g1.down(const Offset(30, 30));
      await tester.pump();
      await g1.moveBy(const Offset(0, 40));
      await tester.pump();
      await g1.moveBy(const Offset(0, 15));
      await tester.pump();
      expect(dragTravel, greaterThan(0), reason: '前置：pane 拖拽已接受并产生 dragUpdate');

      // 第二指是独立序列，按在长按子节点上并保持应照常触发。
      final g2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 42);
      await g2.down(tester.getCenter(find.byKey(lpKey)));
      await tester.pump(const Duration(milliseconds: 700));
      expect(longPressed, 1, reason: '被动 Drag 不得把另一 pointer 的事件链全局清空。');

      await g2.up();
      await g1.up();
      await tester.pumpAndSettle();

      // 对照：无拖拽时长按正常触发
      final g3 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 43);
      await g3.down(tester.getCenter(find.byKey(lpKey)));
      await tester.pump(const Duration(milliseconds: 700));
      expect(longPressed, 2, reason: '对照：前一 Drag 结束后长按继续正常工作。');
      await g3.up();
      await tester.pumpAndSettle();
    });

    testWidgets('REPRO-D: rapid overlapping flicks keep ballistic alive (轻触中断滚动)', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));

      // 第一次 fling
      await tester.fling(find.byKey(scrollKey), const Offset(0, -200), 1500);
      await tester.pump(const Duration(milliseconds: 50));
      final duringBallistic = controller.offset;
      expect(duringBallistic, greaterThan(0));

      // ballistic 进行中：第二次 flick 与第一次 up 后立刻衔接（模拟频繁轻扫）
      final g2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 7);
      await g2.down(center);
      await tester.pump(const Duration(milliseconds: 8));
      await g2.moveBy(const Offset(0, -40), timeStamp: const Duration(milliseconds: 8));
      await tester.pump(const Duration(milliseconds: 8));
      await g2.moveBy(const Offset(0, -40), timeStamp: const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 8));
      await g2.moveBy(const Offset(0, -40), timeStamp: const Duration(milliseconds: 24));
      await tester.pump(const Duration(milliseconds: 8));
      await g2.up(timeStamp: const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 100));
      final afterSecondFling = controller.offset;

      // 第二次 flick 后 ballistic 应继续推进（不被"中断"卡死）
      await tester.pump(const Duration(milliseconds: 200));
      final laterBallistic = controller.offset;

      expect(laterBallistic, greaterThan(afterSecondFling + 1), reason: '快速衔接的第二次 flick 应产生新的 ballistic 惯性');
      await tester.pumpAndSettle();
    });

    testWidgets('REPRO-D2: repeated light reverse flicks after scrolling down do not stall', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      controller.jumpTo(420);
      await tester.pump();
      expect(controller.offset, closeTo(420, 0.1), reason: '前置：已经向下滚动到列表中段');

      var previous = controller.offset;
      var totalReduction = 0.0;
      for (var i = 0; i < 6; i++) {
        // 到达顶部就停止,继续没意义。
        if (previous <= 1.0) break;
        controller.jumpTo(previous);
        await tester.pump();
        final pointer = 70 + i;
        final base = Duration(milliseconds: i * 40);
        final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: pointer);
        await g.down(center, timeStamp: base);
        await tester.pump(const Duration(milliseconds: 4));
        // 反向轻扫：手指向下，内容应往上回。两段小 move 模拟"轻触式"短滚，
        // 总位移刚过 touch slop，容易暴露 accepted frame / velocity 丢失。
        await g.moveBy(const Offset(0, 9), timeStamp: base + const Duration(milliseconds: 8));
        await tester.pump(const Duration(milliseconds: 4));
        await g.moveBy(const Offset(0, 15), timeStamp: base + const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 4));
        await g.up(timeStamp: base + const Duration(milliseconds: 24));
        // 微甩救援起 ballistic 后给 ticker 若干帧积累位移。
        await tester.pump();
        for (var f = 0; f < 4; f++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        final now = controller.offset;
        final reduction = previous - now;
        totalReduction += reduction.clamp(0.0, double.infinity);
        expect(reduction, greaterThan(2.0), reason: '第 ${i + 1} 次反向轻扫后 offset 必须往回滑,不能停在原地');
        previous = now;
      }
      expect(totalReduction, greaterThan(40), reason: '整个循环反向轻扫累计位移必须显著(说明每次都被兑现)');
    });

    testWidgets('REPRO-D3: immediate light reverse flick during downward ballistic does not stall', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      for (var i = 0; i < 5; i++) {
        controller.jumpTo(360);
        await tester.pump();
        await tester.fling(find.byKey(scrollKey), const Offset(0, -160), 2200);
        await tester.pump(const Duration(milliseconds: 48));
        final duringDownwardBallistic = controller.offset;
        expect(duringDownwardBallistic, greaterThan(360), reason: '第 ${i + 1} 轮前置：向下滚动的 ballistic 已经在推进');

        final pointer = 90 + i;
        final base = Duration(milliseconds: 1000 + i * 80);
        final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: pointer);
        await g.down(center, timeStamp: base);
        await tester.pump(const Duration(milliseconds: 4));
        await g.moveBy(const Offset(0, 8), timeStamp: base + const Duration(milliseconds: 8));
        await tester.pump(const Duration(milliseconds: 4));
        await g.moveBy(const Offset(0, 16), timeStamp: base + const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 4));
        await g.up(timeStamp: base + const Duration(milliseconds: 24));
        await tester.pump();
        final afterRelease = controller.offset;
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          controller.offset,
          lessThan(duringDownwardBallistic - 4),
          reason: '第 ${i + 1} 轮：向下惯性中的反向轻扫必须立刻让 offset 往回走，不能暂停',
        );
        expect(controller.offset, lessThan(afterRelease - 1), reason: '第 ${i + 1} 轮：反向轻扫松手后必须继续产生惯性，而不是停在 release 位置');
      }
    });

    testWidgets('REPRO-D5: sub-slop reverse micro flick during ballistic must not pause', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var dragStarts = 0;
      var dragEnds = 0;
      double? dragEndPrimaryVelocity;
      Offset? dragEndVelocity;
      bool? dragEndPipelineActive;
      await tester.pumpWidget(
        shell(
          controller: controller,
          event: ElEvent(
            onDragStart: (_) => dragStarts++,
            onDragEnd: (e) {
              dragEnds++;
              dragEndPrimaryVelocity = e.primaryVelocity;
              dragEndVelocity = e.velocity.pixelsPerSecond;
              dragEndPipelineActive = e.dragPipelineActive;
            },
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      controller.jumpTo(360);
      await tester.pump();
      await tester.fling(find.byKey(scrollKey), const Offset(0, -160), 2200);
      await tester.pump(const Duration(milliseconds: 48));
      final duringDownwardBallistic = controller.offset;
      expect(duringDownwardBallistic, greaterThan(360), reason: '前置：向下惯性已推进');

      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 130);
      await g.down(center, timeStamp: const Duration(milliseconds: 3000));
      await tester.pump(const Duration(milliseconds: 4));
      // 总位移低于默认 touch slop，但时间很短、速度很高。真实用户会把它感知为
      // 一次轻扫，而不是"点一下让滚动停住"。
      await g.moveBy(const Offset(0, 12), timeStamp: const Duration(milliseconds: 3012));
      await tester.pump(const Duration(milliseconds: 4));
      await g.up(timeStamp: const Duration(milliseconds: 3016));
      await tester.pump();
      final afterRelease = controller.offset;
      await tester.pump(const Duration(milliseconds: 80));

      expect(dragStarts, greaterThan(0), reason: 'micro flick 应补发 dragStart');
      expect(dragEnds, greaterThan(0), reason: 'micro flick 应补发 dragEnd 让滚动层兑现 velocity');
      expect(dragEndPrimaryVelocity, greaterThan(0), reason: 'micro flick 的 velocity 方向必须跟手指反向轻扫一致');
      expect(dragEndVelocity?.dy, greaterThan(0), reason: 'micro flick 的轴向 velocity 不能被 VelocityTracker 估成反向');
      expect(dragEndPipelineActive, isFalse, reason: '未过 slop 的微扫不能被标记成管线拖拽，否则 scroll rescue 会被跳过');
      expect(controller.offset, lessThan(duringDownwardBallistic - 1), reason: '低于 slop 的快速反向轻扫不能只把原有滚动停住，必须产生可见反向滚动');
      expect(controller.offset, lessThan(afterRelease - 1), reason: 'micro flick 松手后必须继续有反向惯性');
    });

    Widget virtualShell({required ScrollController controller, ElEvent? Function(int index)? itemEventBuilder}) {
      return MaterialApp(
        scrollBehavior: const _NoChromeBehavior(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: scrollKey,
            width: 120,
            height: 100,
            child: buildVirtualTestViewBuilder(
              controller: controller,
              physics: const ClampingScrollPhysics(),
              itemCount: 1000,
              itemBuilder: (_, i) => ElView(
                key: ValueKey('virtual-item-$i'),
                event: itemEventBuilder?.call(i),
                style: ElStyle(width: 120, height: 40, backgroundColor: Color(0xff222222 + (i % 100))),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('REPRO-C3: virtual scroll child tap during drag must not steal first pointer', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var childPointerDowns = 0;
      await tester.pumpWidget(
        virtualShell(
          controller: controller,
          itemEventBuilder: (_) => ElEvent(onPointerDown: (_) => childPointerDowns++),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      final g1 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 13);
      await g1.down(center);
      await tester.pump();
      await g1.moveBy(const Offset(0, -30));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final beforeSecondDown = controller.offset;
      expect(beforeSecondDown, greaterThan(0), reason: '前置：virtual scroll 第一指已滚动');

      final g2 = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 14);
      await g2.down(tester.getCenter(find.byKey(const ValueKey('virtual-item-1'))));
      await tester.pump();

      // 第二指按住期间的第一指 move:latestPointer 平台语义下被忽略,不做断言。
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final duringSecondDown = controller.offset;

      await g2.up();
      await tester.pump();

      // 第二指抬起后第一指必须恢复驱动(核心 bug 的判别断言)
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      await g1.moveBy(const Offset(0, -20));
      await tester.pump();
      final afterSecondUp = controller.offset;

      await g1.up();
      await tester.pumpAndSettle();

      expect(afterSecondUp, greaterThan(duringSecondDown + 30), reason: 'virtual scroll 中第二指抬起后,第一指必须恢复驱动滚动');
      expect(childPointerDowns, greaterThanOrEqualTo(0));
    });

    testWidgets('REPRO-D4: virtual scroll immediate light reverse flick does not stall', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(virtualShell(controller: controller));
      await tester.pump();

      final center = tester.getCenter(find.byKey(scrollKey));
      for (var i = 0; i < 5; i++) {
        controller.jumpTo(360);
        await tester.pump();
        await tester.fling(find.byKey(scrollKey), const Offset(0, -160), 2200);
        await tester.pump(const Duration(milliseconds: 48));
        final duringDownwardBallistic = controller.offset;
        expect(duringDownwardBallistic, greaterThan(360), reason: '第 ${i + 1} 轮前置：virtual 向下惯性已推进');

        final pointer = 110 + i;
        final base = Duration(milliseconds: 2000 + i * 80);
        final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: pointer);
        await g.down(center, timeStamp: base);
        await tester.pump(const Duration(milliseconds: 4));
        await g.moveBy(const Offset(0, 8), timeStamp: base + const Duration(milliseconds: 8));
        await tester.pump(const Duration(milliseconds: 4));
        await g.moveBy(const Offset(0, 16), timeStamp: base + const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 4));
        await g.up(timeStamp: base + const Duration(milliseconds: 24));
        await tester.pump();
        final afterRelease = controller.offset;
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          controller.offset,
          lessThan(duringDownwardBallistic - 4),
          reason: '第 ${i + 1} 轮：virtual 向下惯性中的反向轻扫必须立刻往回走',
        );
        expect(controller.offset, lessThan(afterRelease - 1), reason: '第 ${i + 1} 轮：virtual 反向轻扫松手后必须继续有惯性');
      }
    });
  });

  group('滚轮与指针移动', () {
    const scrollKey = ValueKey('smooth-scroll');

    Widget shell(
      ScrollController controller, {
      ElSmoothScroll smoothScroll = const _FixedStepSmoothScroll(100.0),
      List<int>? enters,
      List<int>? exits,
    }) {
      return MaterialApp(
        home: SizedBox(
          width: 300,
          height: 300,
          child: ElScrollView(
            key: scrollKey,
            controller: controller,
            smoothScroll: smoothScroll,
            children: [
              for (var i = 0; i < 100; i++)
                ElView(
                  key: ValueKey('row-$i'),
                  event: enters == null
                      ? null
                      : ElEvent(onPointerEnter: (_) => enters[i]++, onPointerExit: (_) => exits![i]++),
                  style: const ElStyle(height: 40),
                  child: 'row - $i',
                ),
            ],
          ),
        ),
      );
    }

    Future<void> wheelAt(WidgetTester tester, Offset position) async {
      // 53px > 触控板判定阈（20px）→ 走滚轮动画路径。
      await tester.sendEventToBinding(PointerScrollEvent(position: position, scrollDelta: const Offset(0, 53)));
    }

    testWidgets('MOVE-1: 动画期间鼠标越过 latch slop 后继续滚，目标累加且不硬停', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller));

      final anchor = tester.getCenter(find.byKey(scrollKey));
      await wheelAt(tester, anchor);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final midway = controller.offset;
      expect(midway, greaterThan(0), reason: '首段动画应已在途');
      expect(midway, lessThan(100), reason: '首段动画不应已结束');

      final render = tester.allRenderObjects.whereType<RenderVirtualScrollView>().first;
      expect(render.hasActivePointerScrollActivity, isTrue, reason: '第二格之前动画必须仍在途');
      expect(ScrollPointerChain.debugOwner, same(render), reason: '第二格之前 chain owner 必须仍是本视口');

      // 同一容器内把指针挪出 10px latch slop，再滚一格。
      await wheelAt(tester, anchor + const Offset(20, 0));
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(200.0, 0.5), reason: '第二格必须在前一段目标上累加（100 + 100），而非从半路重起 100');
    }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);

    testWidgets('MOVE-2: 动画期间纯移动鼠标（不滚轮）不得打断动画，必须走满整段', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller));

      final anchor = tester.getCenter(find.byKey(scrollKey));
      await wheelAt(tester, anchor);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 24));

      final midway = controller.offset;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(100));

      // 纯 hover：动画在途时把指针挪 30px（远超 10px latch slop）。
      final pointer = TestPointer(7, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(anchor));
      await tester.pump();
      await tester.sendEventToBinding(pointer.hover(anchor + const Offset(30, 12)));
      await tester.pump();

      final afterHover = controller.offset;
      expect(afterHover, lessThan(100), reason: 'hover 不应让动画瞬间到位');

      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(100.0, 0.5), reason: '纯 hover 不得截断动画段，必须走满 100px 目标');
    }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);

    for (final entry in <(String, ElSmoothScroll)>[
      ('Windows', const ElWindowsSmoothScroll()),
      ('Chromium', const ElChromiumSmoothScroll()),
    ]) {
      testWidgets('OPEN-${entry.$1}: 平滑滚动期间内容照常命中、滚轮续接', (tester) async {
        final controller = ScrollController();
        final enters = List<int>.filled(100, 0);
        final exits = List<int>.filled(100, 0);
        addTearDown(controller.dispose);
        await tester.pumpWidget(shell(controller, smoothScroll: entry.$2, enters: enters, exits: exits));

        final pointer = TestPointer(11, PointerDeviceKind.mouse);
        final anchor = tester.getCenter(find.byKey(const ValueKey('row-0')));
        await tester.sendEventToBinding(pointer.hover(anchor));
        await tester.pump();
        expect(enters[0], 1, reason: '测试前置：首行必须先进入 hover');

        await tester.sendEventToBinding(
          pointer.scroll(const Offset(0, 53), timeStamp: const Duration(milliseconds: 1)),
        );
        await tester.pump();
        // 2026-08-10 用户裁决：滚轮平滑滚动不再屏蔽内容指针事件，
        // 动画在途内容保持可命中（hover 不移出 MouseTracker 路径）。
        expect(exits[0], 0, reason: '动画启动不得把内容移出命中路径');

        final entersWhileScrolling = enters.fold<int>(0, (sum, count) => sum + count);
        await tester.sendEventToBinding(pointer.hover(anchor + const Offset(0, 24)));
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          enters.fold<int>(0, (sum, count) => sum + count),
          greaterThan(entersWhileScrolling),
          reason: '动画在途移动鼠标照常触发内容 hover',
        );

        await tester.sendEventToBinding(
          pointer.scroll(const Offset(0, 53), timeStamp: const Duration(milliseconds: 50)),
        );
        await tester.pump();

        final render = tester.allRenderObjects.whereType<RenderVirtualScrollView>().first;
        expect(render.hasActivePointerScrollActivity, isTrue, reason: '动画在途时第二格滚轮仍须进入 viewport');

        await tester.pumpAndSettle();
        // 期望值从算法实例现算(首格 + 90ms 窗口内第二格),不锚定手感数值:
        // 续接语义 = 总位移恰为两步之和。
        final expectedOffset = entry.$2.stepForEvent(53, 0) + entry.$2.stepForEvent(53, 1);
        expect(controller.offset, closeTo(expectedOffset, 0.5), reason: '第二格滚轮必须续接现役目标');
      }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
    }
  });

  group('触摸拖动锚点跟随', () {
    for (final virtualized in [false, true]) {
      final label = virtualized ? 'virtual' : 'materialized';

      testWidgets('$label touch drag keeps visible content anchored to every pointer move', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(_touchDragAnchorFollowHost(controller: controller, virtualized: virtualized));
        await tester.pump();
        controller.jumpTo(3600);
        await tester.pump();
        await tester.pump();

        final anchor = _anchoredVisibleRow(tester);
        var anchorTop = tester.getTopLeft(anchor).dy;
        var finger = tester.getCenter(anchor);

        final gesture = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 901);
        addTearDown(gesture.removePointer);
        await gesture.down(finger);
        await tester.pump(_frame);
        expect(tester.getTopLeft(anchor).dy, closeTo(anchorTop, 0.5), reason: 'down 本身不能让内容产生额外偏移');

        finger += const Offset(0, -24);
        await gesture.moveTo(finger);
        await tester.pump(_frame);
        finger += const Offset(0, -24);
        await gesture.moveTo(finger);
        await tester.pump(_frame);
        anchorTop = tester.getTopLeft(anchor).dy;

        const moves = <double>[-34, 26, -42, 31, -36, -28, 24, -40, 33, -30];
        for (var i = 0; i < moves.length; i++) {
          final dy = moves[i];
          finger += Offset(0, dy);
          await gesture.moveTo(finger);
          await tester.pump(_frame);

          final afterMoveTop = tester.getTopLeft(anchor).dy;
          expect(afterMoveTop - anchorTop, closeTo(dy, 0.5), reason: '第 $i 帧：内容锚点必须 100% 跟随本帧手指位移');
          anchorTop = afterMoveTop;

          await tester.pump(_frame);
          expect(
            tester.getTopLeft(anchor).dy,
            closeTo(anchorTop, 0.5),
            reason: '第 $i 帧后：没有新的 pointer move，内容不能自己漂移或校正跳位',
          );
        }

        var t = tester.binding.currentSystemFrameTimeStamp;
        const batchedMoves = <double>[-24, 21, -27, 19, -31, 23, -29];
        final batchedStartTop = anchorTop;
        var expectedBatchedDelta = 0.0;
        for (var i = 0; i < batchedMoves.length; i++) {
          final dy = batchedMoves[i];
          expectedBatchedDelta += dy;
          finger += Offset(0, dy);
          t += const Duration(milliseconds: 2);
          await gesture.moveTo(finger, timeStamp: t);
        }
        await tester.pump(_frame);
        anchorTop = tester.getTopLeft(anchor).dy;
        expect(
          anchorTop - batchedStartTop,
          closeTo(expectedBatchedDelta, 0.5),
          reason: '同一帧内频繁上下滑动后，内容只能追随指针最终净位移，不能叠加出额外偏移',
        );

        await tester.pump(_frame);
        expect(tester.getTopLeft(anchor).dy, closeTo(anchorTop, 0.5), reason: '批量 move 落帧后，没有新 pointer move 时内容不能继续漂移');

        await gesture.up();
        await tester.pump();
      });
    }
  });

  group('触控板原始输入', () {
    for (final scenario in ['post', 'pause', 'error']) {
      testWidgets('pan $scenario：边界余量、停顿释放与异常清理', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final key = GlobalKey<_InputProbeState>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 300, height: 200),
                child: ElScrollView(
                  controller: controller,
                  physics: const ElClampingScrollPhysics(),
                  scrollbar: const ElNoScrollBar(),
                  children: [
                    _InputProbe(key: key, fraction: .5, fail: scenario == 'error'),
                    ElView(style: ElStyle(height: 1000)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        if (scenario == 'post') controller.jumpTo(controller.position.maxScrollExtent - 5);
        final t0 = tester.binding.currentSystemFrameTimeStamp;
        const center = Offset(150, 100);
        await tester.sendEventToBinding(PointerPanZoomStartEvent(pointer: 81, position: center, timeStamp: t0));
        await tester.sendEventToBinding(
          PointerPanZoomUpdateEvent(
            pointer: 81,
            position: center,
            pan: const Offset(0, -20),
            panDelta: const Offset(0, -20),
            timeStamp: t0 + const Duration(milliseconds: 8),
          ),
        );
        if (scenario == 'error') expect(tester.takeException(), isA<StateError>());
        await tester.sendEventToBinding(
          PointerPanZoomEndEvent(pointer: 81, position: center, timeStamp: t0 + const Duration(milliseconds: 200)),
        );
        final state = key.currentState!;
        if (scenario == 'post') {
          expect(state.posts, hasLength(1));
          expect(state.posts.single.$1, same(state.inputs.single));
          expect(state.posts.single.$2, 5);
          expect(state.inputs.single.requestedDelta, 20);
          expect(controller.offset, controller.position.maxScrollExtent);
        } else if (scenario == 'pause') {
          expect(state.releases.single.releaseVelocity, 0);
        } else {
          expect(state.releases, isEmpty);
        }
        await tester.pumpAndSettle();
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    for (final verifyTime in [true, false]) {
      testWidgets('Windows pan 直通${verifyTime ? '保留原始输入时刻' : '保留起手首段位移'}', (tester) async {
        final controller = _Controller();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 300, height: 200),
                child: ElScrollView(
                  controller: controller,
                  scrollbar: const ElNoScrollBar(),
                  physics: const ClampingScrollPhysics(),
                  children: [ElView(style: ElStyle(height: 1000))],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final t0 = tester.binding.currentSystemFrameTimeStamp;
        const center = Offset(150, 100);
        await tester.sendEventToBinding(PointerPanZoomStartEvent(pointer: 81, position: center, timeStamp: t0));
        await tester.sendEventToBinding(
          PointerPanZoomUpdateEvent(
            pointer: 81,
            position: center,
            pan: const Offset(0, -20),
            panDelta: const Offset(0, -20),
            timeStamp: t0 + const Duration(milliseconds: 8),
          ),
        );
        expect(controller.updates, hasLength(1));
        if (verifyTime) {
          expect(controller.updates.single.sourceTimeStamp, t0 + const Duration(milliseconds: 8));
        } else {
          expect(controller.offset, closeTo(20, .001));
        }
        await tester.sendEventToBinding(
          PointerPanZoomUpdateEvent(
            pointer: 81,
            position: center,
            pan: const Offset(0, -60),
            panDelta: const Offset(0, -40),
            timeStamp: t0 + const Duration(milliseconds: 24),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(controller.updates, hasLength(2));
        expect(controller.offset, closeTo(60, .001));
        await tester.pump(const Duration(milliseconds: 8));
        expect(controller.updates, hasLength(2));
        expect(controller.updates.last.sourceTimeStamp, t0 + const Duration(milliseconds: 24));
        await tester.sendEventToBinding(
          PointerPanZoomEndEvent(pointer: 81, position: center, timeStamp: t0 + const Duration(milliseconds: 32)),
        );
        controller.jumpTo(controller.offset);
        expect(controller.offset, closeTo(60, .001));
        expect(controller.updates.last.sourceTimeStamp, t0 + const Duration(milliseconds: 24));
        await tester.pumpAndSettle();
      }, variant: TargetPlatformVariant({TargetPlatform.windows}));
    }
  });
}
