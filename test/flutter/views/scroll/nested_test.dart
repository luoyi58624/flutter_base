import 'dart:math' as math;

import 'package:flutter_base/src/flutter/views/scroll/common/pointer/scroll_pointer_chain.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

class _Header extends StatefulWidget {
  const _Header({super.key, this.duringBallistic, this.pixelsPerUnit = 1, this.duplicate = false});
  final VoidCallback? duringBallistic;
  final double pixelsPerUnit;
  final bool duplicate;
  @override
  State<_Header> createState() => _HeaderState();
}

class _HalfRecoveryPhysics extends ElBouncingScrollPhysics {
  const _HalfRecoveryPhysics({super.parent});
  @override
  _HalfRecoveryPhysics applyTo(ScrollPhysics? ancestor) => _HalfRecoveryPhysics(parent: buildParent(ancestor));
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) => position.outOfRange ? offset / 2 : offset;
}

class _HeaderState extends State<_Header> with ElScrollMixin<_Header> {
  double collapsed = 50;
  bool enabled = true;
  void disable() {
    enabled = false;
    updateScrollEffect();
  }

  final ballisticInputs = <ElScrollInputDetails>[];
  int? inputSessionId;
  late final track = ElScrollEffectTrack(
    effectId: #collapse,
    minValue: 0,
    maxValue: 100 / widget.pixelsPerUnit,
    unit: widget.pixelsPerUnit == 1 ? ElScrollEffectUnit.logicalPixels : ElScrollEffectUnit.progress,
    pixelsPerUnit: widget.pixelsPerUnit,
    readValue: () => collapsed / widget.pixelsPerUnit,
    updateValue: (value) => setState(() => collapsed = value * widget.pixelsPerUnit),
  );
  @override
  Object? get scrollInputSlot => enabled ? #header : null;
  @override
  Iterable<ElScrollEffectTrack> get scrollEffectTracks => enabled ? [track, if (widget.duplicate) track] : const [];
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    inputSessionId = input.sessionId;
    if (input.source == ElScrollInputSource.ballistic) {
      ballisticInputs.add(input);
      widget.duringBallistic?.call();
    }
    final accepted = rest > 0 ? rest.clamp(0.0, 100.0 - collapsed) : -(-rest).clamp(0.0, collapsed);
    if (accepted != 0) track.updateValue((collapsed + accepted).clamp(0.0, 100.0) / widget.pixelsPerUnit);
    return rest - accepted;
  }

  @override
  Widget build(BuildContext context) =>
      ElView(style: const ElStyle(width: 100, height: 100), child: '${collapsed.round()}');
}

double _offset(ScrollPosition position) => axisDirectionIsReversed(position.axisDirection)
    ? position.maxScrollExtent - position.pixels
    : position.pixels - position.minScrollExtent;

class _RecordingBouncingPhysics extends ElBouncingScrollPhysics {
  const _RecordingBouncingPhysics(this.velocities, {super.parent});
  final List<double> velocities;
  @override
  _RecordingBouncingPhysics applyTo(ScrollPhysics? ancestor) =>
      _RecordingBouncingPhysics(velocities, parent: buildParent(ancestor));
  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (velocity.abs() > 1) velocities.add(velocity.abs());
    return super.createBallisticSimulation(position, velocity);
  }
}

class _Observer extends StatefulWidget {
  const _Observer({required this.axis, required this.header});
  final Axis axis;
  final bool header;
  @override
  State<_Observer> createState() => _ObserverState();
}

class _ObserverState extends State<_Observer> with ElScrollMixin<_Observer> {
  double progress = 0;
  late final track = ElScrollEffectTrack(
    effectId: #header,
    minValue: 0,
    maxValue: 1000,
    pixelsPerUnit: 1,
    readValue: () => progress,
    updateValue: (value) => progress = value,
  );
  @override
  Object? get scrollInputSlot => widget.header ? #header : null;
  @override
  Iterable<ElScrollEffectTrack> get scrollEffectTracks => widget.header ? [track] : const [];
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    final accepted = rest.clamp(-progress, 1000 - progress);
    progress += accepted;
    return rest - accepted;
  }

  @override
  Widget build(BuildContext context) => _content(widget.axis);
}

Widget _content(Axis axis) => ElView(
  style: ElStyle(width: axis == Axis.horizontal ? 20000 : 300, height: axis == Axis.vertical ? 20000 : 300),
);

class _Half extends StatefulWidget {
  const _Half();
  @override
  State<_Half> createState() => _HalfState();
}

class _HalfState extends State<_Half> with ElScrollMixin<_Half> {
  @override
  Object get scrollInputSlot => #half;
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) => super.onPreScroll(input, remaining) * .5;
  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 1100));
}

class _LinearSmooth extends ElSmoothScroll {
  const _LinearSmooth();
  @override
  double stepForEvent(double rawDelta, int burstTicks) => rawDelta;
  @override
  Duration segmentDuration(double delta, double velocity) => const Duration(milliseconds: 200);
  @override
  Curve curveFor(double initialSlope) => Curves.linear;
}

class _PointerHeader extends StatefulWidget {
  const _PointerHeader({super.key, this.onInput, this.child});
  final VoidCallback? onInput;
  final Widget? child;
  @override
  State<_PointerHeader> createState() => _PointerHeaderState();
}

class _PointerHeaderState extends State<_PointerHeader> with ElScrollMixin<_PointerHeader> {
  double collapsed = 0;
  final samples = <ElScrollInputDetails>[];
  final deltas = <double>[];
  late final track = ElScrollEffectTrack(
    effectId: #header,
    minValue: 0,
    maxValue: 50,
    pixelsPerUnit: 1,
    readValue: () => collapsed,
    updateValue: (value) => collapsed = value,
  );
  @override
  Object? get scrollInputSlot => #header;
  @override
  Iterable<ElScrollEffectTrack> get scrollEffectTracks => [track];
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    remaining = super.onPreScroll(input, remaining);
    samples.add(input);
    deltas.add(remaining);
    widget.onInput?.call();
    final accepted = remaining.clamp(-collapsed, 50 - collapsed);
    collapsed += accepted;
    return remaining - accepted;
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const ElView(style: ElStyle(width: 50, height: 50));
}

const _innerHorizontalKey = ValueKey('inner-h');

const _innerVerticalKey = ValueKey('inner-v');

const _innerVerticalInHorizontalKey = ValueKey('inner-v-in-h');

const _dragKinds = <PointerDeviceKind>[PointerDeviceKind.touch, PointerDeviceKind.mouse];

const _allDragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.mouse,
};

enum _BoundaryEdge { leading, trailing }

String _kindName(PointerDeviceKind kind) => switch (kind) {
  PointerDeviceKind.mouse => '鼠标',
  PointerDeviceKind.touch => '触摸',
  _ => kind.name,
};

String _edgeLabel(_BoundaryEdge edge) => switch (edge) {
  _BoundaryEdge.leading => 'leading',
  _BoundaryEdge.trailing => 'trailing',
};

String _edgeName(_BoundaryEdge edge) => switch (edge) {
  _BoundaryEdge.leading => '起始',
  _BoundaryEdge.trailing => '末端',
};

String _axisName(Axis axis) => switch (axis) {
  Axis.horizontal => '横向',
  Axis.vertical => '纵向',
};

Axis _oppositeAxis(Axis axis) => axis == Axis.horizontal ? Axis.vertical : Axis.horizontal;

Key _keyForAxis(Axis axis) => axis == Axis.horizontal ? _innerHorizontalKey : _innerVerticalKey;

Offset _outwardDrag(Axis axis, _BoundaryEdge edge, {double distance = 60}) {
  return switch ((axis, edge)) {
    (Axis.horizontal, _BoundaryEdge.leading) => Offset(distance, 0),
    (Axis.horizontal, _BoundaryEdge.trailing) => Offset(-distance, 0),
    (Axis.vertical, _BoundaryEdge.leading) => Offset(0, distance),
    (Axis.vertical, _BoundaryEdge.trailing) => Offset(0, -distance),
  };
}

Offset _inwardDrag(Axis axis, _BoundaryEdge edge, {double distance = 60}) {
  return -_outwardDrag(axis, edge, distance: distance);
}

double _wheelOutwardDelta(_BoundaryEdge edge) {
  return edge == _BoundaryEdge.leading ? -80 : 80;
}

double _edgeOffsetFor(ScrollController controller, _BoundaryEdge edge) {
  return edge == _BoundaryEdge.leading ? controller.position.minScrollExtent : controller.position.maxScrollExtent;
}

double _jumpToEdge(ScrollController controller, _BoundaryEdge edge) {
  final offset = _edgeOffsetFor(controller, edge);
  controller.jumpTo(offset);
  return offset;
}

void _expectAtEdge(ScrollController controller, _BoundaryEdge edge, {String? reason}) {
  expect(controller.offset, moreOrLessEquals(_edgeOffsetFor(controller, edge), epsilon: 0.5), reason: reason);
}

void _expectMovedInward(ScrollController controller, _BoundaryEdge edge, double edgeOffset, {String? reason}) {
  if (edge == _BoundaryEdge.leading) {
    expect(controller.offset, greaterThan(edgeOffset + precisionErrorTolerance), reason: reason);
  } else {
    expect(controller.offset, lessThan(edgeOffset - precisionErrorTolerance), reason: reason);
  }
}

void _expectBouncedOutward(ScrollController controller, _BoundaryEdge edge, double edgeOffset, {String? reason}) {
  if (edge == _BoundaryEdge.leading) {
    expect(controller.offset, lessThan(edgeOffset - precisionErrorTolerance), reason: reason);
  } else {
    expect(controller.offset, greaterThan(edgeOffset + precisionErrorTolerance), reason: reason);
  }
}

void _expectBouncedFurtherOutward(
  ScrollController controller,
  _BoundaryEdge edge,
  double previousOffset, {
  String? reason,
}) {
  if (edge == _BoundaryEdge.leading) {
    expect(controller.offset, lessThan(previousOffset - precisionErrorTolerance), reason: reason);
  } else {
    expect(controller.offset, greaterThan(previousOffset + precisionErrorTolerance), reason: reason);
  }
}

Future<void> _sendWheel(WidgetTester tester, {required Offset position, required Offset scrollDelta}) async {
  await tester.sendEventToBinding(
    PointerScrollEvent(position: position, kind: PointerDeviceKind.mouse, scrollDelta: scrollDelta),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 180));
}

/// 最小 dragProxy 宿主，与 input_test.dart 的拖动代理场景共用相同协议：
/// `RenderProxyBox` 直通布局与命中，dispatcher 只挂 [ElEvent.dragProxy]
/// （无 drag 回调 → 无 drag shape），滚动 driver 在祖先链快照里纳入 roster。
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

class _DampedPhysics extends ClampingScrollPhysics {
  const _DampedPhysics({required this.nonlinear, super.parent});
  final bool nonlinear;
  @override
  _DampedPhysics applyTo(ScrollPhysics? ancestor) =>
      _DampedPhysics(nonlinear: nonlinear, parent: buildParent(ancestor));
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      offset * .25 * (nonlinear ? 1 + offset.abs() / 20 : 1);
}

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with ElScrollMixin<_Probe> {
  final posts = <double>[];
  @override
  Object get scrollInputSlot => #probe;
  @override
  double onPostScroll(ElScrollInputDetails input, double remaining) {
    posts.add(super.onPostScroll(input, remaining));
    return 0;
  }

  @override
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    super.onPreFling(details, remainingVelocity);
    return 0;
  }

  @override
  Widget build(BuildContext context) => const ElView();
}

class _InputBindingRetirementProbe extends StatefulWidget {
  const _InputBindingRetirementProbe({super.key});
  @override
  State<_InputBindingRetirementProbe> createState() => _InputBindingRetirementProbeState();
}

class _InputBindingRetirementProbeState extends State<_InputBindingRetirementProbe>
    with ElScrollMixin<_InputBindingRetirementProbe> {
  final inputs = <ElScrollInputDetails>[];
  @override
  Object get scrollInputSlot => #input;
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    inputs.add(input);
    return super.onPreScroll(input, remaining);
  }

  @override
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    super.onPreFling(details, remainingVelocity);
    return 0;
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 1000));
}

enum _Shape {
  vertical,
  horizontal,
  dualVertical,
  dualHorizontal,
  reverseVertical,
  rtlHorizontal;

  Axis get inputAxis => switch (this) {
    horizontal || dualHorizontal || rtlHorizontal => .horizontal,
    _ => .vertical,
  };
  Axis? get axis => this == dualVertical || this == dualHorizontal ? null : inputAxis;
}

class _NestedPage {
  _NestedPage(
    this.controllers, {
    this.shape = .vertical,
    this.threeLevels = false,
    this.crossAxisOuter = false,
    this.outerDisabled = false,
    this.refresh,
  });

  final String controllers;
  final _Shape shape;
  final bool threeLevels;
  final bool crossAxisOuter;
  final bool outerDisabled;
  final String? refresh;
  final outerKey = GlobalKey<ElScrollViewState>();
  final middleKey = GlobalKey<ElScrollViewState>();
  final innerKey = GlobalKey<ElScrollViewState>();

  ScrollPosition position(GlobalKey<ElScrollViewState> key, Axis? axis) =>
      axis == null && shape.inputAxis == .horizontal
      ? key.currentState!.horizontalPosition!
      : key.currentState!.position;
  ScrollPosition get inner => position(innerKey, shape.axis);
  Axis? get outerAxis => crossAxisOuter ? (shape.inputAxis == .horizontal ? .vertical : .horizontal) : shape.axis;
  ScrollPosition get outer => position(outerKey, outerAxis);
  List<double> get parentOffsets => [outer.pixels, if (threeLevels) middleKey.currentState!.position.pixels];

  void expectParents(List<double> expected, String reason) => expect(parentOffsets, expected, reason: reason);

  Offset drag(double scrollDelta) {
    final sign = axisDirectionIsReversed(inner.axisDirection) ? 1.0 : -1.0;
    return shape.inputAxis == .vertical ? Offset(0, scrollDelta * sign) : Offset(scrollDelta * sign, 0);
  }

  Offset point(WidgetTester tester) {
    var visible = tester.getRect(find.byKey(innerKey)).intersect(tester.getRect(find.byKey(outerKey)));
    if (threeLevels) visible = visible.intersect(tester.getRect(find.byKey(middleKey)));
    expect(visible.isEmpty, isFalse, reason: '手势必须落在真实可见的最内层');
    return visible.center;
  }

  Future<void> mount(WidgetTester tester) async {
    ScrollController? controller() {
      final result = switch (controllers) {
        'el' => ElScrollController(),
        'flutter' => ScrollController(),
        _ => null,
      };
      if (result != null) addTearDown(result.dispose);
      return result;
    }

    Widget view(GlobalKey<ElScrollViewState> key, Axis? axis, List<Widget> children, {bool disabled = false}) =>
        ElScrollView(
          key: key,
          axis: axis,
          reverse: shape == .reverseVertical,
          controller: controller(),
          horizontalController: axis == null ? controller() : null,
          physics: disabled ? const NeverScrollableScrollPhysics() : const ElClampingScrollPhysics(),
          scrollbar: const ElNoScrollBar(),
          refresher: refresh == null ? null : const _Refresher(),
          onRefresh: refresh == 'both' || (key == innerKey ? refresh == 'inner' : refresh == 'outer')
              ? () async {}
              : null,
          children: children,
        );

    List<Widget> body(Widget nested, Axis? axis) {
      final horizontal = axis == .horizontal || (axis == null && shape.inputAxis == .horizontal);
      final children = [
        ElView(
          style: ElStyle(width: horizontal ? 100 : (axis == null ? 660 : 160), height: horizontal ? 160 : 100),
        ),
        nested,
        ElView(
          style: ElStyle(width: horizontal ? 1000 : (axis == null ? 660 : 160), height: horizontal ? 160 : 1000),
        ),
      ];
      return axis == null && horizontal ? [Row(mainAxisSize: .min, children: children)] : children;
    }

    Widget nested = ElView(
      style: const ElStyle(width: 160, height: 160),
      child: view(innerKey, shape.axis, [
        ElView(
          style: ElStyle(width: shape.axis == .vertical ? 160 : 660, height: shape.axis == .horizontal ? 160 : 660),
        ),
      ]),
    );
    if (threeLevels) {
      nested = ElView(
        style: const ElStyle(width: 200, height: 200),
        child: view(middleKey, .vertical, body(nested, .vertical)),
      );
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: shape == .rtlHorizontal ? .rtl : .ltr,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(dragDevices: {.touch, .mouse, .trackpad}, overscroll: false),
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 240, height: 240),
              child: view(outerKey, outerAxis, body(nested, outerAxis), disabled: outerDisabled),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // reverse / RTL 仅翻转像素锚点，成员仍按正向布局，先换回真实内容坐标。
    outer.jumpTo(axisDirectionIsReversed(outer.axisDirection) ? outer.maxScrollExtent - 100 : 100);
    if (threeLevels) middleKey.currentState!.position.jumpTo(100);
    await tester.pump();
    expect(inner.maxScrollExtent, greaterThan(160));
    expect(outer.maxScrollExtent, greaterThan(100));
  }
}

class _Refresher extends ElRefresher {
  const _Refresher() : super(movesContent: false);

  @override
  double get triggerExtent => 100;

  @override
  double get refreshingExtent => 100;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) => const ElView();
}

class _Input {
  _Input(this.tester, this.point, this.kind, this.stamp);

  final WidgetTester tester;
  final Offset point;
  final PointerDeviceKind kind;
  Duration stamp;
  Offset pan = Offset.zero;
  TestGesture? gesture;

  static Future<_Input> start(WidgetTester tester, Offset point, PointerDeviceKind kind) async {
    final input = _Input(tester, point, kind, tester.binding.currentSystemFrameTimeStamp);
    if (kind == .trackpad) {
      await tester.sendEventToBinding(PointerPanZoomStartEvent(pointer: 79, position: point, timeStamp: input.stamp));
    } else {
      input.gesture = await tester.createGesture(kind: kind);
      addTearDown(input.gesture!.removePointer);
      await input.gesture!.down(point, timeStamp: input.stamp);
    }
    await tester.pump();
    return input;
  }

  Future<void> move(Offset delta, {int milliseconds = 16}) async {
    final duration = Duration(milliseconds: milliseconds);
    stamp += duration;
    if (kind == .trackpad) {
      pan += delta;
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(pointer: 79, position: point, pan: pan, panDelta: delta, timeStamp: stamp),
      );
    } else {
      await gesture!.moveBy(delta, timeStamp: stamp);
    }
    await tester.pump(duration);
  }

  Future<void> end({bool cancel = false, bool fling = false}) async {
    final duration = Duration(milliseconds: fling ? 1 : 1000);
    stamp += duration;
    await tester.pump(duration);
    if (kind == .trackpad) {
      await tester.sendEventToBinding(PointerPanZoomEndEvent(pointer: 79, position: point, timeStamp: stamp));
    } else if (cancel) {
      await gesture!.cancel(timeStamp: stamp);
    } else {
      await gesture!.up(timeStamp: stamp);
    }
    await tester.pumpAndSettle();
  }
}

class _Member extends StatefulWidget {
  const _Member({required this.enabled, required this.onInput});
  final bool enabled;
  final VoidCallback onInput;
  @override
  State<_Member> createState() => _MemberState();
}

class _MemberState extends State<_Member> with ElScrollMixin<_Member> {
  @override
  Object? get scrollInputSlot => widget.enabled ? #member : null;
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    widget.onInput();
    return super.onPreScroll(input, remaining);
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 20));
}

class _Region extends StatefulWidget {
  const _Region({required this.child});
  final Widget child;
  @override
  State<_Region> createState() => _RegionState();
}

class _RegionState extends State<_Region> with ElScrollMixin<_Region>, ElNestedScrollMixin<_Region> {
  @override
  Object get scrollInputSlot => #region;
  @override
  Widget build(BuildContext context) => buildNestedScrollRegion(child: widget.child);
}

Widget _inner(ScrollController controller) => ElView(
  style: const ElStyle(height: 180),
  child: ElScrollView(
    controller: controller,
    physics: const ElClampingScrollPhysics(),
    scrollbar: const ElNoScrollBar(),
    children: const [ElView(style: ElStyle(height: 600))],
  ),
);

Widget _shell(ScrollController outer, List<Widget> children, {bool disabled = false}) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(
      style: const ElStyle(width: 300, height: 300),
      child: ElScrollView(
        controller: outer,
        physics: disabled ? const NeverScrollableScrollPhysics() : const ElClampingScrollPhysics(),
        scrollbar: const ElNoScrollBar(),
        children: [
          ...children,
          const ElView(style: ElStyle(height: 1000)),
        ],
      ),
    ),
  ),
);

Future<void> _crossBoundary(WidgetTester tester, ScrollController inner) async {
  inner.jumpTo(inner.position.maxScrollExtent - 60);
  await tester.pump();
  final view = find.byWidgetPredicate((widget) => widget is ElScrollView && identical(widget.controller, inner));
  final gesture = await tester.startGesture(tester.getCenter(view));
  for (final delta in [30.0, 20.0, 90.0]) {
    await gesture.moveBy(Offset(0, -delta));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.cancel();
  await tester.pumpAndSettle();
  expect(inner.offset, inner.position.maxScrollExtent);
}

class _Participant extends StatefulWidget {
  const _Participant({
    super.key,
    required this.slot,
    required this.trace,
    required this.preFraction,
    this.postFraction = 0,
    this.fling = false,
    this.flingFraction = 0,
    this.onInput,
    required this.child,
  });
  final Object slot;
  final List<String> trace;
  final double preFraction;
  final double postFraction;
  final bool fling;
  final double flingFraction;
  final void Function(ElScrollInputDetails)? onInput;
  final Widget child;
  @override
  State<_Participant> createState() => _ParticipantState();
}

class _ParticipantState extends State<_Participant> with ElScrollMixin<_Participant> {
  final inputs = <ElScrollInputDetails>[];
  final releases = <ElScrollReleaseDetails>[];
  final releaseInputs = <double>[];
  double accepted = 0;
  @override
  Object get scrollInputSlot => widget.slot;
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    widget.trace.add('${widget.slot}:pre');
    inputs.add(input);
    widget.onInput?.call(input);
    accepted += rest * widget.preFraction;
    return rest * (1 - widget.preFraction);
  }

  @override
  double onPostScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPostScroll(input, remaining);
    widget.trace.add('${widget.slot}:post');
    inputs.add(input);
    accepted += rest * widget.postFraction;
    return rest * (1 - widget.postFraction);
  }

  @override
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    final remaining = super.onPreFling(details, remainingVelocity);
    releases.add(details);
    releaseInputs.add(remaining);
    return widget.fling ? remaining * (1 - widget.flingFraction) : 0;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

double _contentOffset(ScrollPosition position) => axisDirectionIsReversed(position.axisDirection)
    ? position.maxScrollExtent - position.pixels
    : position.pixels - position.minScrollExtent;

class _Log {
  int starts = 0;
  int ends = 0;
  int flings = 0;
  double pre = 0;
  double consumed = 0;
  double post = 0;
  final List<Axis> axes = [];
}

class _NestedScrollRegion extends StatefulWidget {
  const _NestedScrollRegion({
    super.key,
    required this.log,
    required this.child,
    this.enabled = true,
    this.fraction = 0,
    this.name = '',
    this.trace,
    this.remainder,
    this.axis,
    this.slot,
    this.onEnd,
  });
  final _Log log;
  final Widget child;
  final bool enabled;
  final double fraction;
  final String name;
  final List<String>? trace;
  final double Function(double)? remainder;
  final Axis? axis;
  final Object? slot;
  final VoidCallback? onEnd;
  @override
  State<_NestedScrollRegion> createState() => _NestedScrollRegionState();
}

class _NestedScrollRegionState extends State<_NestedScrollRegion>
    with ElScrollMixin<_NestedScrollRegion>, ElNestedScrollMixin<_NestedScrollRegion> {
  bool? enabledOverride;
  void setEnabled(bool enabled) {
    enabledOverride = enabled;
    updateScrollEffect();
  }

  @override
  Object? get scrollInputSlot =>
      participatesInNestedScroll ? (widget.slot ?? (widget.name.isEmpty ? #region : widget.name)) : null;
  @override
  Axis? get requestedScrollAxis => widget.axis;
  @override
  bool get participatesInNestedScroll => enabledOverride ?? widget.enabled;
  @override
  void onNestedScrollStart(ElScrollInputDetails details) {
    super.onNestedScrollStart(details);
    widget.log.starts++;
    widget.log.axes.add(details.axis);
  }

  @override
  double onNestedPreScroll(ElScrollInputDetails details, double inputRemaining) {
    final remaining = super.onNestedPreScroll(details, inputRemaining);
    widget.log.pre += remaining;
    widget.trace?.add('${widget.name}:pre');
    final next = widget.remainder?.call(remaining) ?? remaining * (1 - widget.fraction);
    widget.log.consumed += remaining - next;
    return next;
  }

  @override
  double onNestedPostScroll(ElScrollInputDetails details, double inputRemaining) {
    final remaining = super.onNestedPostScroll(details, inputRemaining);
    widget.log.post += remaining;
    widget.trace?.add('${widget.name}:post');
    return remaining;
  }

  @override
  double onNestedPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    widget.log.flings++;
    return super.onNestedPreFling(details, remainingVelocity);
  }

  @override
  void onNestedScrollEnd() {
    super.onNestedScrollEnd();
    widget.log.ends++;
    widget.onEnd?.call();
  }

  @override
  Widget build(BuildContext context) => buildNestedScrollRegion(child: widget.child);
}

Widget _nestedScrollInner(ScrollController controller, {int count = 100, Axis axis = Axis.vertical}) => ElScrollView(
  controller: controller,
  axis: axis,
  scrollbar: const ElNoScrollBar(),
  physics: const ClampingScrollPhysics(),
  children: [
    ElListView.builder(
      itemCount: count,
      itemBuilder: (context, index) => ElView(style: const ElStyle(height: 40), child: 'row $index'),
      fixedSize: true,
    ),
  ],
);

Widget _outer(
  Widget child, {
  GlobalKey<ElScrollViewState>? key,
  Axis? axis = Axis.vertical,
  Map<Axis, List<Object>> inputOrder = const {},
}) => ElView(
  style: const ElStyle(width: 200, height: 200),
  child: ElScrollView(
    key: key,
    axis: axis,
    inputOrder: inputOrder,
    scrollbar: const ElNoScrollBar(),
    physics: const ClampingScrollPhysics(),
    children: [ElView(style: const ElStyle(width: 200, height: 200), child: child)],
  ),
);

Widget _app(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(alignment: .topLeft, child: child),
);

Finder _scroll(ScrollController controller) =>
    find.byWidgetPredicate((widget) => widget is ElScrollView && identical(widget.controller, controller));

class _InputSlotsParticipant extends StatefulWidget {
  const _InputSlotsParticipant({
    super.key,
    required this.slot,
    required this.factor,
    required this.log,
    required this.inputs,
    this.postLog,
    this.postInputs,
    this.postFactor = 1,
    this.duringPre,
    this.duringScroll,
    this.releases,
    this.observe = true,
  });
  final Object slot;
  final double factor;
  final List<String> log;
  final List<ElScrollInputDetails> inputs;
  final List<String>? postLog;
  final List<ElScrollInputDetails>? postInputs;
  final double postFactor;
  final VoidCallback? duringPre;
  final VoidCallback? duringScroll;
  final List<ElScrollReleaseDetails>? releases;
  final bool observe;
  @override
  State<_InputSlotsParticipant> createState() => _InputSlotsParticipantState();
}

class _InputSlotsParticipantState extends State<_InputSlotsParticipant> with ElScrollMixin<_InputSlotsParticipant> {
  bool enabled = true;
  void disableInput() {
    enabled = false;
    updateScrollEffect();
  }

  @override
  Object? get scrollInputSlot => enabled ? widget.slot : null;

  @override
  bool get observesScrollUpdates => widget.observe;

  @override
  bool get observesScrollMetrics => widget.observe;

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    super.onScrollUpdate(details);
    widget.duringScroll?.call();
  }

  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    widget.log.add('${widget.slot}:$rest');
    widget.inputs.add(input);
    widget.duringPre?.call();
    return rest * widget.factor;
  }

  @override
  double onPostScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPostScroll(input, remaining);
    widget.postLog?.add('${widget.slot}:$rest');
    widget.postInputs?.add(input);
    return rest * widget.postFactor;
  }

  @override
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    widget.releases?.add(details);
    return super.onPreFling(details, remainingVelocity);
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 20));
}

mixin _A on State<_Compound>, ElScrollMixin<_Compound> {
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    widget.log.add('A:$rest');
    return rest / 2;
  }
}

mixin _B on State<_Compound>, ElScrollMixin<_Compound> {
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    widget.log.add('B:$rest');
    return rest / 2;
  }
}

mixin _C on State<_Compound>, ElScrollMixin<_Compound> {
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    widget.log.add('C:$rest');
    return rest / 2;
  }
}

class _Compound extends StatefulWidget {
  const _Compound(this.log);
  final List<String> log;
  @override
  State<_Compound> createState() => _CompoundState();
}

class _CompoundState extends State<_Compound> with ElScrollMixin<_Compound>, _A, _B, _C {
  @override
  Object get scrollInputSlot => #compound;
  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 20));
}

Widget _frame(Widget child, {TextDirection direction = TextDirection.ltr}) => Directionality(
  textDirection: direction,
  child: Align(
    alignment: .topLeft,
    child: ElView(style: const ElStyle(width: 300, height: 200), child: child),
  ),
);

Future<void> _wheel(WidgetTester tester, {Offset delta = const Offset(0, 80)}) async {
  await tester.sendEventToBinding(PointerScrollEvent(position: const Offset(150, 100), scrollDelta: delta));
  await tester.pump();
}

class _LinearWheel extends ElSmoothScroll {
  const _LinearWheel(this.duration);
  final Duration duration;
  @override
  double stepForEvent(double rawDelta, int burstTicks) => rawDelta;
  @override
  Duration segmentDuration(double delta, double velocity) => duration;
  @override
  Curve curveFor(double initialSlope) => Curves.linear;
}

class _WheelNestedHandoffNestedPage {
  _WheelNestedHandoffNestedPage(
    this.controllers,
    this.smooth, {
    this.horizontal = false,
    this.bars = false,
    this.duration = const Duration(milliseconds: 40),
  });
  final String controllers;
  final bool smooth;
  final bool horizontal;
  final bool bars;
  final Duration duration;
  final outerKey = GlobalKey<ElScrollViewState>();
  final innerKey = GlobalKey<ElScrollViewState>();
  ScrollController? outerController;
  ScrollController? innerController;
  ScrollPosition get outer => outerKey.currentState!.position;
  ScrollPosition get inner => innerKey.currentState!.position;

  Future<void> mount(WidgetTester tester) async {
    ScrollController? makeController() => switch (controllers) {
      'el' => ElScrollController(),
      'flutter' => ScrollController(),
      _ => null,
    };
    outerController = makeController();
    innerController = makeController();
    addTearDown(() {
      outerController?.dispose();
      innerController?.dispose();
    });
    final algorithm = smooth ? _LinearWheel(duration) : null;
    final scrollbar = bars ? const ElWindowScrollBar() : const ElNoScrollBar();
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: ElView(
            style: const ElStyle(width: 400, height: 500),
            child: ElSelectionView(
              child: ElScrollView(
                key: outerKey,
                axis: null,
                controller: outerController,
                smoothScroll: algorithm,
                scrollbar: scrollbar,
                physics: const ElClampingScrollPhysics(),
                children: [
                  const ElView(style: ElStyle(width: '100%', height: 100)),
                  ElView(
                    style: const ElStyle(width: '100%', height: 200),
                    child: ElScrollView(
                      key: innerKey,
                      axis: horizontal ? .horizontal : .vertical,
                      controller: innerController,
                      mouseWheelHorizontalModifiers: null,
                      smoothScroll: algorithm,
                      scrollbar: scrollbar,
                      physics: const ElClampingScrollPhysics(),
                      children: [
                        for (var i = 0; i < 20; i++)
                          ElView(style: const ElStyle(width: 100, height: 100), child: '第 $i 项'),
                      ],
                    ),
                  ),
                  const ElView(style: ElStyle(width: '100%', height: 2000)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset innerPoint(WidgetTester tester) => tester.getCenter(find.byKey(innerKey));

  Future<void> wheel(WidgetTester tester, Offset point, {double delta = 40}) async {
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: .mouse,
        position: point,
        scrollDelta: Offset(0, delta),
        timeStamp: tester.binding.currentSystemFrameTimeStamp,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  group('协同惯性', () {
    for (final axis in Axis.values) {
      for (final reverse in [false, true]) {
        for (final atStart in [true, false]) {
          for (final inwardVelocity in [0.0, 10.0, -1500.0, 1500.0]) {
            testWidgets('$axis reverse=$reverse start=$atStart 越界速度 $inwardVelocity 区分回弹与反向惯性', (tester) async {
              final controller = ElScrollController();
              addTearDown(controller.dispose);
              final key = GlobalKey<_HeaderState>();
              await tester.pumpWidget(
                Directionality(
                  textDirection: .ltr,
                  child: Align(
                    alignment: .topLeft,
                    child: ElView(
                      style: const ElStyle(width: 300, height: 300),
                      child: ElScrollView(
                        axis: axis,
                        reverse: reverse,
                        controller: controller,
                        physics: const ElBouncingScrollPhysics(),
                        scrollbar: const ElNoScrollBar(),
                        children: [
                          _Header(key: key),
                          const ElView(style: ElStyle(width: 3000, height: 3000)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final position = controller.position as ScrollPositionWithSingleContext;
              final rawLeading = atStart != reverse;
              final boundary = rawLeading ? position.minScrollExtent : position.maxScrollExtent;
              final sign = rawLeading ? 1.0 : -1.0;
              controller.jumpTo(boundary);
              // 固定相同的越界起点，只改变释放速度，检查惯性实际经过的消费顺序。
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              position.forcePixels(boundary - sign * 40);
              position.goBallistic(inwardVelocity * sign);
              final carries = inwardVelocity == 1500;
              var enteredBody = false;
              for (var frame = 0; frame < 100; frame++) {
                await tester.pump(const Duration(milliseconds: 16));
                final inwardDistance = (position.pixels - boundary) * sign;
                if (carries && inwardDistance > 1) {
                  enteredBody = true;
                  expect(key.currentState!.collapsed, atStart ? 100 : 0);
                } else if (!carries || inwardDistance < -.01) {
                  expect(key.currentState!.collapsed, 50, reason: '越界回位不能推动效果');
                }
              }
              await tester.pumpAndSettle();
              expect(enteredBody, carries);
              expect(key.currentState!.collapsed, carries ? (atStart ? 100 : 0) : 50);
              if (!carries) expect(position.pixels, closeTo(boundary, .01));
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }

    for (final axis in Axis.values) {
      for (final reverse in [false, true]) {
        testWidgets('$axis reverse=$reverse 越界反拖先按阻尼恢复正文，跨界余量同帧推进效果', (tester) async {
          final controller = ElScrollController();
          addTearDown(controller.dispose);
          final key = GlobalKey<_HeaderState>();
          await tester.pumpWidget(
            Directionality(
              textDirection: .ltr,
              child: Align(
                alignment: .topLeft,
                child: ElView(
                  style: const ElStyle(width: 300, height: 300),
                  child: ElScrollView(
                    axis: axis,
                    reverse: reverse,
                    controller: controller,
                    physics: const _HalfRecoveryPhysics(),
                    scrollbar: const ElNoScrollBar(),
                    children: [
                      _Header(key: key),
                      const ElView(style: ElStyle(width: 2000, height: 2000)),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final boundary = reverse ? controller.position.maxScrollExtent : controller.position.minScrollExtent;
          controller.jumpTo(boundary);
          await tester.pump();
          Offset delta(double value) => axis == Axis.vertical ? Offset(0, value) : Offset(value, 0);
          final gesture = await tester.startGesture(const Offset(150, 150));
          await gesture.moveBy(delta(-30));
          // 30 像素间隙、1/2 阻尼需要 60 输入，100 输入余下的 40 应全部交给效果。
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          controller.position.forcePixels(boundary + (reverse ? 30 : -30));
          await gesture.moveBy(delta(-100));
          await tester.pump();
          expect(controller.offset, closeTo(boundary, 1e-7));
          expect(key.currentState!.collapsed, closeTo(90, 1e-7));
          await gesture.moveBy(delta(-20));
          await tester.pump();
          expect(key.currentState!.collapsed, 100);
          expect(controller.offset, closeTo(boundary + (reverse ? -10 : 10), 1e-7));
          await gesture.up(timeStamp: const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('正文尚未创建 Drag 时，raw 命令也会退役被头部吃完的旧输入', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_HeaderState>();
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
                  _Header(key: key),
                  const ElView(style: ElStyle(height: 3000)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final gesture = await tester.startGesture(const Offset(150, 140));
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -4));
      expect(key.currentState!.collapsed, 54);
      expect(controller.offset, 0);
      expect(key.currentState!.inputSessionId, isNotNull);
      expect(key.currentState!.scrollSnapshot.sessionId, key.currentState!.inputSessionId);
      controller.jumpTo(200);
      expect(key.currentState!.scrollSnapshot.sessionId, isNull);
      await gesture.moveBy(const Offset(0, -4));
      expect(key.currentState!.collapsed, 54);
      expect(controller.offset, 200);
      await gesture.up();
      final next = await tester.startGesture(const Offset(150, 140));
      await next.moveBy(const Offset(0, -30));
      await next.moveBy(const Offset(0, -4));
      expect(key.currentState!.collapsed, 58);
      await next.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final invalid in ['controller', 'duplicate', 'range']) {
      testWidgets('效果轨道的 $invalid 配置在真实注册入口明确失败', (tester) async {
        final ScrollController controller = invalid == 'controller' ? ScrollController() : ElScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: ElView(
              style: const ElStyle(width: 300, height: 200),
              child: ElScrollView(
                controller: controller,
                scrollbar: const ElNoScrollBar(),
                children: [
                  _Header(duplicate: invalid == 'duplicate', pixelsPerUnit: invalid == 'range' ? double.nan : 1),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isA<FlutterError>());
      });
    }

    for (final takeover in ['pointer', 'pan', 'command', 'remove', 'callback', 'error']) {
      testWidgets('协同惯性 $takeover 接管后不再推进旧效果或正文', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final headerKey = GlobalKey<_HeaderState>();
        var handled = false;
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
                    _Header(
                      key: headerKey,
                      duringBallistic: takeover == 'callback' || takeover == 'error'
                          ? () {
                              if (handled) return;
                              handled = true;
                              if (takeover == 'error') throw StateError('ballistic failure');
                              controller.jumpTo(320);
                            }
                          : null,
                    ),
                    const ElView(style: ElStyle(height: 3000)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        controller.jumpTo(200);
        await tester.pump();
        final t0 = tester.binding.currentSystemFrameTimeStamp;
        var y = 140.0;
        await tester.sendEventToBinding(
          PointerDownEvent(pointer: 91, kind: PointerDeviceKind.touch, position: Offset(150, y), timeStamp: t0),
        );
        for (final move in [(-30.0, 16), (-4.0, 20)]) {
          y += move.$1;
          await tester.sendEventToBinding(
            PointerMoveEvent(
              pointer: 91,
              kind: PointerDeviceKind.touch,
              position: Offset(150, y),
              delta: Offset(0, move.$1),
              timeStamp: t0 + Duration(milliseconds: move.$2),
            ),
          );
        }
        await tester.sendEventToBinding(
          PointerUpEvent(
            pointer: 91,
            kind: PointerDeviceKind.touch,
            position: Offset(150, y),
            timeStamp: t0 + const Duration(milliseconds: 24),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 8));
        if (takeover == 'error') expect(tester.takeException(), isA<StateError>());
        Future<void>? replacement;
        if (takeover == 'pointer') {
          await tester.sendEventToBinding(
            PointerDownEvent(
              pointer: 92,
              kind: PointerDeviceKind.touch,
              position: const Offset(150, 100),
              timeStamp: tester.binding.currentSystemFrameTimeStamp,
            ),
          );
        } else if (takeover == 'pan') {
          await tester.sendEventToBinding(
            PointerPanZoomStartEvent(
              pointer: 82,
              position: const Offset(150, 100),
              timeStamp: tester.binding.currentSystemFrameTimeStamp,
            ),
          );
        } else if (takeover == 'command') {
          replacement = controller.animateTo(320, duration: const Duration(milliseconds: 100), curve: Curves.linear);
        } else if (takeover == 'remove') {
          headerKey.currentState!.disable();
        }
        final stoppedHeader = headerKey.currentState!.collapsed;
        final stoppedInputs = headerKey.currentState!.ballisticInputs.length;
        final stoppedBody = controller.offset;
        await tester.pumpAndSettle();
        await replacement;
        expect(headerKey.currentState!.collapsed, stoppedHeader);
        expect(headerKey.currentState!.ballisticInputs, hasLength(stoppedInputs));
        expect(controller.offset, takeover == 'command' || takeover == 'callback' ? closeTo(320, .01) : stoppedBody);
        if (takeover == 'pointer') {
          await tester.sendEventToBinding(
            PointerUpEvent(
              pointer: 92,
              kind: PointerDeviceKind.touch,
              position: const Offset(150, 100),
              timeStamp: tester.binding.currentSystemFrameTimeStamp,
            ),
          );
        } else if (takeover == 'pan') {
          await tester.sendEventToBinding(
            PointerPanZoomEndEvent(
              pointer: 82,
              position: const Offset(150, 100),
              timeStamp: tester.binding.currentSystemFrameTimeStamp,
            ),
          );
        }
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    for (final physics in <ScrollPhysics>[
      const ElClampingScrollPhysics(),
      const ElBrowserScrollPhysics(),
      const ElBouncingScrollPhysics(),
    ]) {
      testWidgets('${physics.runtimeType}：pan 在零正文范围释放后继续效果惯性', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final key = GlobalKey<_HeaderState>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 300, height: 200),
                child: ElScrollView(
                  controller: controller,
                  physics: physics,
                  scrollbar: const ElNoScrollBar(),
                  children: [_Header(key: key)],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final t0 = tester.binding.currentSystemFrameTimeStamp;
        const center = Offset(150, 100);
        await tester.sendEventToBinding(PointerPanZoomStartEvent(pointer: 81, position: center, timeStamp: t0));
        for (final update in [(12.0, 4), (24.0, 8)]) {
          await tester.sendEventToBinding(
            PointerPanZoomUpdateEvent(
              pointer: 81,
              position: center,
              pan: Offset(0, -update.$1),
              panDelta: const Offset(0, -12),
              timeStamp: t0 + Duration(milliseconds: update.$2),
            ),
          );
        }
        expect(key.currentState!.collapsed, 74);
        expect(controller.offset, 0);
        await tester.sendEventToBinding(
          PointerPanZoomEndEvent(pointer: 81, position: center, timeStamp: t0 + const Duration(milliseconds: 10)),
        );
        expect(controller.position.isScrollingNotifier.value, isTrue);
        await tester.pumpAndSettle();
        expect(key.currentState!.collapsed, 100);
        expect(key.currentState!.ballisticInputs, isNotEmpty);
        expect(controller.offset, closeTo(0, .01));
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${physics.runtimeType}：视口变化后的惯性续接保留实际速度和位置', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final headerKey = GlobalKey<_HeaderState>();
        final hostKey = GlobalKey<ElScrollViewState>();
        Widget fixture(double height) => Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: ElStyle(width: 300, height: height),
              child: ElScrollView(
                key: hostKey,
                controller: controller,
                physics: physics,
                scrollbar: const ElNoScrollBar(),
                children: [
                  _Header(key: headerKey),
                  const ElView(style: ElStyle(height: 3000)),
                ],
              ),
            ),
          ),
        );
        await tester.pumpWidget(fixture(200));
        await tester.pump();
        controller.jumpTo(200);
        await tester.pump();
        final t0 = tester.binding.currentSystemFrameTimeStamp;
        await tester.sendEventToBinding(
          PointerDownEvent(pointer: 91, kind: PointerDeviceKind.touch, position: const Offset(150, 140), timeStamp: t0),
        );
        for (final move in [(110.0, -30.0, 16), (106.0, -4.0, 20)]) {
          await tester.sendEventToBinding(
            PointerMoveEvent(
              pointer: 91,
              kind: PointerDeviceKind.touch,
              position: Offset(150, move.$1),
              delta: Offset(0, move.$2),
              timeStamp: t0 + Duration(milliseconds: move.$3),
            ),
          );
        }
        await tester.sendEventToBinding(
          PointerUpEvent(
            pointer: 91,
            kind: PointerDeviceKind.touch,
            position: const Offset(150, 106),
            timeStamp: t0 + const Duration(milliseconds: 24),
          ),
        );
        for (var frame = 0; frame < 4; frame++) {
          await tester.pump(const Duration(milliseconds: 8));
        }
        final before = hostKey.currentState!.debugScrollMotionSample(Axis.vertical)!;
        final velocity = before.simulation.dx(before.time);
        final offset = controller.offset;
        final header = headerKey.currentState!.collapsed;
        await tester.pumpWidget(fixture(180));
        expect(controller.offset, offset);
        expect(headerKey.currentState!.collapsed, header);
        await tester.pump(const Duration(milliseconds: 8));
        final after = hostKey.currentState!.debugScrollMotionSample(Axis.vertical)!;
        expect(identical(before.simulation, after.simulation), isFalse);
        expect(after.simulation.dx(0), closeTo(velocity, 1e-8));
        expect(
          controller.offset + headerKey.currentState!.collapsed - offset - header,
          closeTo(after.simulation.x(after.time) - after.simulation.x(0), 1e-8),
        );
        await tester.pumpAndSettle();
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      });

      for (final configuration in [
        (false, 1.0, 1.0),
        (true, 1.0, 1.0),
        (false, 100.0, 1.0),
        (true, 100.0, 1.0),
        (false, 100.0, -1.0),
        (true, 100.0, -1.0),
      ]) {
        final hasBody = configuration.$1;
        final scale = configuration.$2;
        final sign = configuration.$3;
        for (final axis in Axis.values) {
          for (final reverse in [false, true]) {
            for (final direction in TextDirection.values) {
              testWidgets(
                '${physics.runtimeType} $axis reverse=$reverse $direction scale=$scale sign=$sign：${hasBody ? '正文同帧交接' : '零范围正文'}协同惯性',
                (tester) async {
                  final controller = ElScrollController();
                  addTearDown(controller.dispose);
                  final headerKey = GlobalKey<_HeaderState>();
                  final hostKey = GlobalKey<ElScrollViewState>();
                  Offset at(double value) => axis == Axis.vertical ? Offset(150, value) : Offset(value, 100);
                  Offset delta(double value) => axis == Axis.vertical ? Offset(0, value) : Offset(value, 0);
                  await tester.pumpWidget(
                    Directionality(
                      textDirection: direction,
                      child: Align(
                        alignment: .topLeft,
                        child: ElView(
                          style: const ElStyle(width: 300, height: 200),
                          child: ElScrollView(
                            key: hostKey,
                            axis: axis,
                            reverse: reverse,
                            controller: controller,
                            physics: physics,
                            scrollbar: const ElNoScrollBar(),
                            children: [
                              _Header(key: headerKey, pixelsPerUnit: scale),
                              if (hasBody)
                                ElListView.builder(
                                  itemCount: 100,
                                  itemBuilder: (_, _) => const ElView(style: ElStyle(width: 40, height: 40)),
                                  fixedSize: true,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  await tester.pump();
                  if (hasBody) {
                    controller.jumpTo(
                      axisDirectionIsReversed(controller.position.axisDirection)
                          ? controller.position.maxScrollExtent - 200
                          : 200,
                    );
                    await tester.pump();
                  }
                  final t0 = tester.binding.currentSystemFrameTimeStamp;
                  await tester.sendEventToBinding(
                    PointerDownEvent(pointer: 91, kind: PointerDeviceKind.touch, position: at(140), timeStamp: t0),
                  );
                  await tester.sendEventToBinding(
                    PointerMoveEvent(
                      pointer: 91,
                      kind: PointerDeviceKind.touch,
                      position: at(140 - 30 * sign),
                      delta: delta(-30 * sign),
                      timeStamp: t0 + const Duration(milliseconds: 16),
                    ),
                  );
                  await tester.sendEventToBinding(
                    PointerMoveEvent(
                      pointer: 91,
                      kind: PointerDeviceKind.touch,
                      position: at(140 - 34 * sign),
                      delta: delta(-4 * sign),
                      timeStamp: t0 + const Duration(milliseconds: 20),
                    ),
                  );
                  final beforeRelease = headerKey.currentState!.collapsed;
                  expect((beforeRelease - 50) * sign, inExclusiveRange(0, 50));
                  await tester.sendEventToBinding(
                    PointerUpEvent(
                      pointer: 91,
                      kind: PointerDeviceKind.touch,
                      position: at(140 - 34 * sign),
                      timeStamp: t0 + const Duration(milliseconds: 24),
                    ),
                  );
                  expect(controller.position.isScrollingNotifier.value, isTrue);
                  var sharedFrame = false;
                  for (var frame = 0; frame < 32; frame++) {
                    final beforeHeader = headerKey.currentState!.collapsed;
                    final beforeBody = _offset(controller.position);
                    await tester.pump(const Duration(milliseconds: 8));
                    sharedFrame |=
                        (headerKey.currentState!.collapsed - beforeHeader) * sign > 0 &&
                        (_offset(controller.position) - beforeBody) * sign > 0;
                    final sample = hostKey.currentState!.debugScrollMotionSample(axis);
                    if (sample != null) {
                      final before = (
                        headerKey.currentState!.collapsed,
                        controller.offset,
                        headerKey.currentState!.ballisticInputs.length,
                      );
                      sample.simulation.x(sample.time);
                      sample.simulation.dx(sample.time);
                      sample.simulation.isDone(sample.time);
                      hostKey.currentState!.debugReplayScrollMotionSample(axis);
                      expect((
                        headerKey.currentState!.collapsed,
                        controller.offset,
                        headerKey.currentState!.ballisticInputs.length,
                      ), before);
                    }
                  }
                  expect(headerKey.currentState!.collapsed, sign > 0 ? 100 : 0);
                  final inputs = headerKey.currentState!.ballisticInputs;
                  expect(inputs, isNotEmpty);
                  expect(inputs.map((input) => input.timeStamp).toSet(), hasLength(inputs.length));
                  if (hasBody) {
                    expect(sharedFrame, isTrue);
                    expect((_offset(controller.position) - 200) * sign, greaterThan(0));
                  }
                  await tester.pumpAndSettle();
                  expect(controller.position.isScrollingNotifier.value, isFalse);
                  expect(headerKey.currentState!.collapsed, sign > 0 ? 100 : 0);
                  if (!hasBody) expect(controller.offset, closeTo(0, .01));
                  expect(tester.takeException(), isNull);
                },
              );
            }
          }
        }
      }
    }
  });

  group('协同动量', () {
    for (final axis in Axis.values) {
      for (final reverse in [false, true]) {
        for (final direction in TextDirection.values) {
          for (final sameDirection in [false, true]) {
            for (final pan in [false, true]) {
              if (pan && (axis != Axis.vertical || reverse || direction != TextDirection.ltr)) continue;
              testWidgets('$axis reverse=$reverse $direction 同向=$sameDirection pan=$pan 协同 bouncing 保留平台动量', (
                tester,
              ) async {
                final launches = <String, List<double>>{};
                for (final mode in ['plain', 'observer', 'header']) {
                  final velocities = <double>[];
                  final controller = ElScrollController();
                  addTearDown(controller.dispose);
                  await tester.pumpWidget(
                    Directionality(
                      textDirection: direction,
                      child: Align(
                        alignment: .topLeft,
                        child: ElView(
                          style: const ElStyle(width: 300, height: 300),
                          child: ElScrollView(
                            key: ValueKey(mode),
                            axis: axis,
                            reverse: reverse,
                            controller: controller,
                            physics: _RecordingBouncingPhysics(velocities),
                            scrollbar: const ElNoScrollBar(),
                            children: [
                              mode == 'plain' ? _content(axis) : _Observer(axis: axis, header: mode == 'header'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  await tester.pump();
                  if (axisDirectionIsReversed(controller.position.axisDirection)) {
                    controller.jumpTo(controller.position.maxScrollExtent);
                    await tester.pump();
                  }
                  Future<void> fling(int time, double sign) async {
                    if (pan) {
                      const center = Offset(150, 200);
                      final pointer = time + 1;
                      await tester.sendEventToBinding(
                        PointerPanZoomStartEvent(
                          pointer: pointer,
                          position: center,
                          timeStamp: Duration(milliseconds: time),
                        ),
                      );
                      for (var sample = 1; sample <= 3; sample++) {
                        await tester.sendEventToBinding(
                          PointerPanZoomUpdateEvent(
                            pointer: pointer,
                            position: center,
                            pan: Offset(0, -30.0 * sample * sign),
                            panDelta: Offset(0, -30.0 * sign),
                            timeStamp: Duration(milliseconds: time + sample * 16),
                          ),
                        );
                      }
                      await tester.sendEventToBinding(
                        PointerPanZoomEndEvent(
                          pointer: pointer,
                          position: center,
                          timeStamp: Duration(milliseconds: time + 50),
                        ),
                      );
                      return;
                    }
                    final gesture = await tester.createGesture();
                    await gesture.down(const Offset(150, 200), timeStamp: Duration(milliseconds: time));
                    for (final sample in [(30.0, 16), (30.0, 32), (30.0, 48)]) {
                      await gesture.moveBy(
                        axis == Axis.vertical ? Offset(0, -sample.$1 * sign) : Offset(-sample.$1 * sign, 0),
                        timeStamp: Duration(milliseconds: time + sample.$2),
                      );
                    }
                    await gesture.up(timeStamp: Duration(milliseconds: time + 50));
                  }

                  await fling(0, 1);
                  final first = velocities.last;
                  await tester.pump();
                  await tester.pump(const Duration(milliseconds: 16));
                  expect(controller.position.isScrollingNotifier.value, isTrue);
                  await fling(90, sameDirection ? 1 : -1);
                  final second = velocities.last;
                  launches[mode] = [first, second];
                  expect(second, sameDirection ? greaterThan(first) : closeTo(first, .01), reason: 'mode=$mode');
                  controller.jumpTo(0);
                  await tester.pumpWidget(const ElView());
                  expect(tester.takeException(), isNull);
                }
                for (final mode in ['observer', 'header']) {
                  expect(launches[mode]!.first, closeTo(launches['plain']!.first, .01));
                  expect(launches[mode]!.last, closeTo(launches['plain']!.last, .01));
                }
              });
            }
          }
        }
      }
    }
  });

  group('协同运动基准更新', () {
    testWidgets('输入被消费但未形成几何行程时，不在虚构边界提前回弹', (tester) async {
      final controller = ElScrollController();
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
                physics: const ElBouncingScrollPhysics(),
                scrollbar: const ElNoScrollBar(),
                children: const [_Half()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.jumpTo(400);
      final initialVelocity = controller.position.physics.createBallisticSimulation(controller.position, 1200)!.dx(0);
      (controller.position as ScrollPositionWithSingleContext).goBallistic(1200);
      await tester.pump();
      var previous = controller.offset;
      for (var i = 0; i < 220; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(controller.offset, greaterThanOrEqualTo(previous - .00001), reason: '正文尚未到边界，不得提前反向');
        expect(controller.position.outOfRange, isFalse);
        previous = controller.offset;
      }
      // 输入折半只改变实际位移，续接保持平台初速与摩擦衰减，不重复施加释放策略。
      expect(controller.offset, closeTo(400 + initialVelocity / 2.0024805 / 2, 10));
      expect(controller.position.isScrollingNotifier.value, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('协同指针输入', () {
    for (final recovery in [false, true]) {
      for (final smooth in [false, true]) {
        testWidgets('pointer smooth=$smooth 接管旧触屏，recovery=$recovery 结束后不留下越界正文', (tester) async {
          final controller = ElScrollController();
          addTearDown(controller.dispose);
          final header = GlobalKey<_PointerHeaderState>();
          await tester.pumpWidget(
            Directionality(
              textDirection: .ltr,
              child: Align(
                alignment: .topLeft,
                child: ElView(
                  style: const ElStyle(width: 200, height: 200),
                  child: ElScrollView(
                    controller: controller,
                    physics: const ElBouncingScrollPhysics(),
                    scrollbar: const ElNoScrollBar(),
                    smoothScroll: smooth ? const _LinearSmooth() : null,
                    children: [
                      _PointerHeader(key: header),
                      const ElView(style: ElStyle(height: 2000)),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final gesture = await tester.startGesture(const Offset(100, 100));
          final step = Offset(0, recovery ? 30 : -30);
          await gesture.moveBy(step);
          await gesture.moveBy(Offset(0, recovery ? 40 : -4));
          if (recovery) {
            expect(controller.offset, lessThan(0));
          } else {
            expect(header.currentState!.collapsed, 4);
          }
          expect(
            controller.dispatchPointerScroll(
              PointerScrollEvent(
                position: const Offset(100, 100),
                kind: PointerDeviceKind.mouse,
                scrollDelta: Offset(0, recovery ? -120 : 120),
                timeStamp: tester.binding.currentSystemFrameTimeStamp,
              ),
            ),
            isTrue,
          );
          await gesture.moveBy(step);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(header.currentState!.collapsed + controller.offset, closeTo(recovery ? 0 : 124, 0.01));
          expect(controller.position.outOfRange, isFalse);
          expect(controller.position.isScrollingNotifier.value, isFalse);
          expect(tester.takeException(), isNull);
        }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
      }
    }

    for (final smooth in [false, true]) {
      testWidgets('pointer smooth=$smooth 祖先效果与内层正文分账，边界余量不推动祖先正文', (tester) async {
        final outer = ElScrollController();
        final inner = ElScrollController();
        addTearDown(outer.dispose);
        addTearDown(inner.dispose);
        final outerHeader = GlobalKey<_PointerHeaderState>();
        final innerHeader = GlobalKey<_PointerHeaderState>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 200, height: 200),
                child: ElScrollView(
                  controller: outer,
                  physics: const ElClampingScrollPhysics(),
                  scrollbar: const ElNoScrollBar(),
                  smoothScroll: smooth ? const _LinearSmooth() : null,
                  children: [
                    _PointerHeader(
                      key: outerHeader,
                      child: ElView(
                        style: const ElStyle(height: 200),
                        child: ElScrollView(
                          controller: inner,
                          physics: const ElClampingScrollPhysics(),
                          scrollbar: const ElNoScrollBar(),
                          smoothScroll: smooth ? const _LinearSmooth() : null,
                          children: [
                            _PointerHeader(key: innerHeader),
                            const ElView(style: ElStyle(height: 180)),
                          ],
                        ),
                      ),
                    ),
                    const ElView(style: ElStyle(height: 1000)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: const Offset(100, 100),
            kind: PointerDeviceKind.mouse,
            scrollDelta: const Offset(0, 200),
            timeStamp: tester.binding.currentSystemFrameTimeStamp,
          ),
        );
        if (smooth) {
          expect(outerHeader.currentState!.collapsed, 0);
          expect(innerHeader.currentState!.collapsed, 0);
        }
        await tester.pumpAndSettle();
        expect(outerHeader.currentState!.collapsed, 50);
        expect(innerHeader.currentState!.collapsed, 50);
        expect(inner.offset, closeTo(30, 0.01));
        expect(outer.offset, 0, reason: '滚轮同格余量不得绕过接收者的 500ms 交接保护');
        expect(outerHeader.currentState!.deltas.fold(0.0, (sum, value) => sum + value), closeTo(200, 0.01));
        final sessions = [
          ...outerHeader.currentState!.samples,
          ...innerHeader.currentState!.samples,
        ].map((input) => input.sessionId).toSet();
        expect(sessions.length, 1);
        expect(
          outerHeader.currentState!.samples.first.sourceScrollView,
          same(innerHeader.currentState!.samples.first.scrollView),
        );
        expect(outer.position.isScrollingNotifier.value, isFalse);
        expect(inner.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
    }

    for (final second in [120.0, -120.0]) {
      testWidgets('协同 smooth 连续目标 $second 保留实际输入坐标和会话', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final header = GlobalKey<_PointerHeaderState>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 200, height: 200),
                child: ElScrollView(
                  controller: controller,
                  physics: const ElClampingScrollPhysics(),
                  scrollbar: const ElNoScrollBar(),
                  smoothScroll: const _LinearSmooth(),
                  children: [
                    _PointerHeader(key: header),
                    const ElView(style: ElStyle(height: 2000)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        Future<void> wheel(double value) => tester.sendEventToBinding(
          PointerScrollEvent(
            position: const Offset(100, 100),
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, value),
            timeStamp: tester.binding.currentSystemFrameTimeStamp,
          ),
        );
        await wheel(120);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final session = header.currentState!.samples.first.sessionId;
        expect(header.currentState!.collapsed + controller.offset, closeTo(60, 0.01));
        await wheel(second);
        await tester.pumpAndSettle();
        expect(header.currentState!.collapsed + controller.offset, closeTo(second > 0 ? 240 : 0, 0.01));
        expect(header.currentState!.samples.map((input) => input.sessionId).toSet(), {session});
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
    }

    for (final smooth in [false, true]) {
      for (final axis in Axis.values) {
        for (final reverse in [false, true]) {
          for (final direction in TextDirection.values) {
            testWidgets('pointer smooth=$smooth $axis reverse=$reverse $direction 实际样本中头部与正文共用输入预算', (tester) async {
              final controller = ElScrollController();
              addTearDown(controller.dispose);
              final header = GlobalKey<_PointerHeaderState>();
              await tester.pumpWidget(
                Directionality(
                  textDirection: direction,
                  child: Align(
                    alignment: .topLeft,
                    child: ElView(
                      style: const ElStyle(width: 200, height: 200),
                      child: ElScrollView(
                        axis: axis,
                        reverse: reverse,
                        controller: controller,
                        physics: const ElClampingScrollPhysics(),
                        scrollbar: const ElNoScrollBar(),
                        smoothScroll: smooth ? const _LinearSmooth() : null,
                        children: [
                          _PointerHeader(key: header),
                          ElView(
                            style: ElStyle(
                              width: axis == Axis.horizontal ? 2000 : 200,
                              height: axis == Axis.vertical ? 2000 : 200,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              if (axisDirectionIsReversed(controller.position.axisDirection)) {
                controller.jumpTo(controller.position.maxScrollExtent);
                await tester.pump();
              }
              await tester.sendEventToBinding(
                PointerScrollEvent(
                  position: const Offset(100, 100),
                  kind: PointerDeviceKind.mouse,
                  scrollDelta: axis == Axis.vertical ? const Offset(0, 120) : const Offset(120, 0),
                  timeStamp: tester.binding.currentSystemFrameTimeStamp,
                ),
              );
              if (smooth) {
                expect(header.currentState!.collapsed, 0, reason: '原始滚轮事件只设定目标，不提前调用 pre');
                expect(_offset(controller.position), 0);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 100));
                expect(header.currentState!.collapsed, closeTo(50, 0.01));
                expect(_offset(controller.position), closeTo(10, 0.01));
              }
              await tester.pumpAndSettle();
              expect(header.currentState!.collapsed, 50);
              expect(_offset(controller.position), closeTo(70, 0.01));
              expect(header.currentState!.deltas.fold(0.0, (sum, delta) => sum + delta), closeTo(120, 0.01));
              expect(
                header.currentState!.samples.every((sample) => sample.source == ElScrollInputSource.pointerSignal),
                isTrue,
              );
              expect(header.currentState!.samples.map((sample) => sample.sessionId).toSet().length, 1);
              expect(header.currentState!.samples.first.sessionId, isNotNull);
              expect(
                header.currentState!.samples.every((input) => input.snapshot.sessionId == input.sessionId),
                isTrue,
              );
              expect(header.currentState!.scrollSnapshot.sessionId, isNull);
              expect(tester.takeException(), isNull);
            }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
          }
        }
      }
    }

    for (final smooth in [false, true]) {
      testWidgets('pointer smooth=$smooth 正文无范围时仍消费有限头部，边界停止', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final header = GlobalKey<_PointerHeaderState>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 200, height: 200),
                child: ElScrollView(
                  controller: controller,
                  physics: const ElClampingScrollPhysics(),
                  scrollbar: const ElNoScrollBar(),
                  smoothScroll: smooth ? const _LinearSmooth() : null,
                  children: [_PointerHeader(key: header)],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(controller.position.maxScrollExtent, 0);
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: const Offset(100, 100),
            kind: PointerDeviceKind.mouse,
            scrollDelta: const Offset(0, 120),
            timeStamp: tester.binding.currentSystemFrameTimeStamp,
          ),
        );
        await tester.pumpAndSettle();
        expect(header.currentState!.collapsed, 50);
        expect(controller.offset, 0);
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
    }

    for (final phase in ['start', 'pre', 'body']) {
      testWidgets('协同 smooth $phase 回调的新命令使旧生产者退役', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        var taken = false;
        void takeOver() {
          if (taken) return;
          taken = true;
          controller.jumpTo(300);
        }

        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 200, height: 200),
                child: ElScrollView(
                  controller: controller,
                  physics: const ElClampingScrollPhysics(),
                  scrollbar: const ElNoScrollBar(),
                  smoothScroll: const _LinearSmooth(),
                  children: [
                    _PointerHeader(onInput: phase == 'pre' ? takeOver : null),
                    const ElView(style: ElStyle(height: 2000)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        if (phase == 'start') {
          controller.position.isScrollingNotifier.addListener(() {
            if (controller.position.isScrollingNotifier.value) takeOver();
          });
        } else if (phase == 'body') {
          controller.addListener(takeOver);
        }
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: const Offset(100, 100),
            kind: PointerDeviceKind.mouse,
            scrollDelta: const Offset(0, 120),
            timeStamp: tester.binding.currentSystemFrameTimeStamp,
          ),
        );
        await tester.pumpAndSettle();
        expect(taken, isTrue);
        expect(controller.offset, 300);
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
    }

    for (final phase in ['start', 'tick']) {
      testWidgets('smooth $phase 的新命令不会被旧目标兜底覆盖', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 200, height: 200),
                child: ElScrollView(
                  controller: controller,
                  physics: const ElClampingScrollPhysics(),
                  scrollbar: const ElNoScrollBar(),
                  smoothScroll: const _LinearSmooth(),
                  children: const [ElView(style: ElStyle(height: 2000))],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        var interrupted = false;
        void replace() {
          if (interrupted) return;
          interrupted = true;
          controller.jumpTo(7);
        }

        if (phase == 'start') {
          controller.position.isScrollingNotifier.addListener(() {
            if (!interrupted && controller.position.isScrollingNotifier.value) replace();
          });
        } else {
          controller.addListener(replace);
        }
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: const Offset(100, 100),
            kind: PointerDeviceKind.mouse,
            scrollDelta: const Offset(0, 120),
            timeStamp: tester.binding.currentSystemFrameTimeStamp,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
        await tester.pumpAndSettle();
        expect(interrupted, isTrue);
        expect(controller.offset, 7);
        expect(controller.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
    }
  });

  group('交叉轴嵌套', () {
    var pointer = 9000;

    Future<TestGesture> dragDown(
      WidgetTester tester,
      Finder target, {
      PointerDeviceKind kind = PointerDeviceKind.touch,
    }) async {
      final gesture = await tester.createGesture(pointer: pointer++, kind: kind);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(target));
      await tester.pump();
      return gesture;
    }

    Future<void> dragSteps(
      WidgetTester tester,
      TestGesture gesture,
      Offset delta, {
      int count = 1,
      Duration duration = const Duration(milliseconds: 16),
    }) async {
      for (var i = 0; i < count; i++) {
        await gesture.moveBy(delta);
        await tester.pump(duration);
      }
    }

    Future<void> finishDrag(WidgetTester tester, TestGesture gesture) async {
      await gesture.up();
      await tester.pumpAndSettle();
    }

    Widget app(Widget child, {bool mouseDrag = false}) => MaterialApp(
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
        dragDevices: mouseDrag ? _allDragDevices : null,
      ),
      home: Align(alignment: Alignment.topLeft, child: child),
    );

    List<Widget> rows(String prefix, int count, {double width = 200, double height = 40}) => List<Widget>.generate(
      count,
      (i) => ElView(
        key: ValueKey('$prefix-$i'),
        style: ElStyle(width: width, height: height),
      ),
    );

    List<Widget> columns(String prefix, int count, {double width = 40, double height = 200}) => List<Widget>.generate(
      count,
      (i) => ElView(
        key: ValueKey('$prefix-$i'),
        style: ElStyle(width: width, height: height),
      ),
    );

    Widget horizontalInner(
      ScrollController controller, {
      Key key = _innerHorizontalKey,
      double width = 200,
      double height = 100,
      ScrollPhysics physics = const ClampingScrollPhysics(),
      ElEvent? event,
      Iterable<LogicalKeyboardKey>? mouseWheelHorizontalModifiers = ElScrollView.defaultMouseWheelHorizontalModifiers,
    }) => SizedBox(
      key: key,
      width: width,
      height: height,
      child: ElScrollView(
        axis: Axis.horizontal,
        controller: controller,
        physics: physics,
        mouseWheelHorizontalModifiers: mouseWheelHorizontalModifiers,
        event: event,
        children: columns('h', 10, height: height),
      ),
    );

    Widget verticalInner(
      ScrollController controller, {
      Key key = _innerVerticalKey,
      double width = 200,
      double height = 100,
      ElEvent? event,
    }) => SizedBox(
      key: key,
      width: width,
      height: height,
      child: ElScrollView(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        event: event,
        children: rows('v', 10, width: width),
      ),
    );

    Widget verticalOuterHorizontalInner(
      ScrollController outer,
      ScrollController inner, {
      bool mouseDrag = false,
      ScrollPhysics innerPhysics = const ClampingScrollPhysics(),
      Iterable<LogicalKeyboardKey>? mouseWheelHorizontalModifiers = ElScrollView.defaultMouseWheelHorizontalModifiers,
      ElEvent? innerEvent,
    }) => app(
      SizedBox(
        width: 200,
        height: 200,
        child: ElScrollView(
          controller: outer,
          physics: const ClampingScrollPhysics(),
          children: [
            horizontalInner(
              inner,
              physics: innerPhysics,
              mouseWheelHorizontalModifiers: mouseWheelHorizontalModifiers,
              event: innerEvent,
            ),
            ...rows('outer-v', 10),
          ],
        ),
      ),
      mouseDrag: mouseDrag,
    );

    Widget horizontalOuterVerticalInner(
      ScrollController outer,
      ScrollController inner, {
      bool mouseDrag = false,
      ElEvent? innerEvent,
    }) => app(
      SizedBox(
        width: 200,
        height: 200,
        child: ElScrollView(
          axis: Axis.horizontal,
          controller: outer,
          physics: const ClampingScrollPhysics(),
          children: [
            verticalInner(inner, key: _innerVerticalInHorizontalKey, height: 200, event: innerEvent),
            ...columns('outer-h', 10),
          ],
        ),
      ),
      mouseDrag: mouseDrag,
    );

    Widget sameAxisScrollShell(Axis axis, ScrollController outer, ScrollController inner, {bool mouseDrag = false}) {
      final child = axis == Axis.vertical
          ? ElScrollView(
              controller: outer,
              physics: const ClampingScrollPhysics(),
              children: [...rows('same-v-before', 4), verticalInner(inner), ...rows('same-v-outer', 10)],
            )
          : ElScrollView(
              axis: Axis.horizontal,
              controller: outer,
              physics: const ClampingScrollPhysics(),
              children: [
                ...columns('same-h-before', 4),
                horizontalInner(inner, width: 100, height: 200),
                ...columns('same-h-outer', 10),
              ],
            );
      return app(SizedBox(width: 200, height: 200, child: child), mouseDrag: mouseDrag);
    }

    Widget tabWithHorizontalInner(
      ElTabController tab,
      ScrollController inner, {
      required _BoundaryEdge edge,
      required bool mouseDrag,
    }) {
      final innerPage = horizontalInner(inner, width: 240, height: 180);
      final pages = edge == _BoundaryEdge.leading
          ? <Widget>[const Text('page-0'), innerPage]
          : <Widget>[innerPage, const Text('page-1')];
      return app(
        SizedBox(
          width: 240,
          height: 180,
          child: ElTabView(controller: tab, physics: const ClampingScrollPhysics(), children: pages),
        ),
        mouseDrag: mouseDrag,
      );
    }

    Widget proxyThroughCrossAxisMiddle(
      Axis proxyAxis,
      ScrollController middle,
      ScrollController inner, {
      required ElEvent proxyEvent,
      required bool mouseDrag,
    }) {
      final middleScroll = proxyAxis == Axis.horizontal
          ? ElScrollView(
              controller: middle,
              physics: const ClampingScrollPhysics(),
              children: [horizontalInner(inner), ...rows('proxy-middle-v', 10)],
            )
          : ElScrollView(
              axis: Axis.horizontal,
              controller: middle,
              physics: const ClampingScrollPhysics(),
              children: [
                verticalInner(inner, key: _innerVerticalInHorizontalKey, height: 200),
                ...columns('proxy-middle-h', 10),
              ],
            );
      return app(
        _DragProxyHost(
          event: proxyEvent,
          child: SizedBox(width: 200, height: 200, child: middleScroll),
        ),
        mouseDrag: mouseDrag,
      );
    }

    Widget crossAxisProxyShell(
      Axis innerAxis,
      ScrollController inner, {
      required ElEvent proxyEvent,
      required bool mouseDrag,
    }) {
      final child = innerAxis == Axis.horizontal
          ? horizontalInner(inner)
          : verticalInner(inner, key: _innerVerticalInHorizontalKey, height: 200);
      return app(
        _DragProxyHost(
          event: proxyEvent,
          child: SizedBox(width: 200, height: 200, child: child),
        ),
        mouseDrag: mouseDrag,
      );
    }

    Widget singleHorizontalBouncingShell(ScrollController controller, {bool mouseDrag = false}) =>
        app(horizontalInner(controller, physics: const BouncingScrollPhysics()), mouseDrag: mouseDrag);

    group('交叉轴锁定：子滚动与异轴祖先滚动', () {
      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 横向子滚动 ${_edgeLabel(boundary)} 边界不交给垂直外层，回拖仍响应', (tester) async {
            final outer = ScrollController();
            final inner = ScrollController();
            addTearDown(outer.dispose);
            addTearDown(inner.dispose);
            await tester.pumpWidget(
              verticalOuterHorizontalInner(outer, inner, mouseDrag: device == PointerDeviceKind.mouse),
            );
            await tester.pump();
            final edgeOffset = _jumpToEdge(inner, boundary);
            await tester.pump();

            final gesture = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, gesture, _outwardDrag(Axis.horizontal, boundary), count: 2);
            _expectAtEdge(inner, boundary, reason: '横向子滚动已经贴住${_edgeName(boundary)}边界');
            expect(outer.offset, 0, reason: '横向边界余量不能被垂直外层捡走');

            await dragSteps(tester, gesture, _inwardDrag(Axis.horizontal, boundary, distance: 100), count: 2);
            _expectMovedInward(inner, boundary, edgeOffset, reason: '同手势反向横拖仍要由原横向子滚动接住');
            expect(outer.offset, 0, reason: '横轴手势全程不能冒泡到垂直外层');
            await finishDrag(tester, gesture);
          });
        }
      }

      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 纵向子滚动 ${_edgeLabel(boundary)} 边界不交给水平外层，回拖仍响应', (tester) async {
            final outer = ScrollController();
            final inner = ScrollController();
            addTearDown(outer.dispose);
            addTearDown(inner.dispose);
            await tester.pumpWidget(
              horizontalOuterVerticalInner(outer, inner, mouseDrag: device == PointerDeviceKind.mouse),
            );
            await tester.pump();
            final edgeOffset = _jumpToEdge(inner, boundary);
            await tester.pump();

            final gesture = await dragDown(tester, find.byKey(_innerVerticalInHorizontalKey), kind: device);
            await dragSteps(tester, gesture, _outwardDrag(Axis.vertical, boundary), count: 2);
            _expectAtEdge(inner, boundary, reason: '纵向子滚动已经贴住${_edgeName(boundary)}边界');
            expect(outer.offset, 0, reason: '纵向边界余量不能被水平外层捡走');

            await dragSteps(tester, gesture, _inwardDrag(Axis.vertical, boundary, distance: 100), count: 2);
            _expectMovedInward(inner, boundary, edgeOffset, reason: '同手势反向纵拖仍要由原纵向子滚动接住');
            expect(outer.offset, 0, reason: '纵轴手势全程不能冒泡到水平外层');
            await finishDrag(tester, gesture);
          });
        }
      }

      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 横向胜出并撞到 ${_edgeLabel(boundary)} 后，同手势竖向移动不得补启动垂直外层', (tester) async {
            final outer = ScrollController();
            final inner = ScrollController();
            addTearDown(outer.dispose);
            addTearDown(inner.dispose);
            await tester.pumpWidget(
              verticalOuterHorizontalInner(outer, inner, mouseDrag: device == PointerDeviceKind.mouse),
            );
            await tester.pump();
            inner.jumpTo(inner.position.maxScrollExtent / 2);
            await tester.pump();
            final edgeOffset = _edgeOffsetFor(inner, boundary);

            final gesture = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, gesture, _outwardDrag(Axis.horizontal, boundary, distance: 80), count: 4);
            _expectAtEdge(inner, boundary, reason: '前置：横向子滚动已被同一手势拖到${_edgeName(boundary)}边界');

            await dragSteps(tester, gesture, const Offset(0, -90), count: 2);
            expect(inner.offset, moreOrLessEquals(edgeOffset, epsilon: 0.5), reason: '竖向移动不是横向滚动可消费轴');
            expect(outer.offset, 0, reason: '同一段拖拽已横向胜出，垂直祖先不得补启动');

            await dragSteps(tester, gesture, _inwardDrag(Axis.horizontal, boundary, distance: 110));
            _expectMovedInward(inner, boundary, edgeOffset, reason: '回到横向位移后仍由已胜出的横向子滚动接住');
            expect(outer.offset, 0, reason: '横轴生命周期内外层垂直始终不能动');
            await finishDrag(tester, gesture);
          });
        }
      }

      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 纵向胜出并撞到 ${_edgeLabel(boundary)} 后，同手势横向移动不得补启动水平外层', (tester) async {
            final outer = ScrollController();
            final inner = ScrollController();
            addTearDown(outer.dispose);
            addTearDown(inner.dispose);
            await tester.pumpWidget(
              horizontalOuterVerticalInner(outer, inner, mouseDrag: device == PointerDeviceKind.mouse),
            );
            await tester.pump();
            inner.jumpTo(inner.position.maxScrollExtent / 2);
            await tester.pump();
            final edgeOffset = _edgeOffsetFor(inner, boundary);

            final gesture = await dragDown(tester, find.byKey(_innerVerticalInHorizontalKey), kind: device);
            await dragSteps(tester, gesture, _outwardDrag(Axis.vertical, boundary, distance: 80), count: 4);
            _expectAtEdge(inner, boundary, reason: '前置：纵向子滚动已被同一手势拖到${_edgeName(boundary)}边界');

            await dragSteps(tester, gesture, const Offset(-90, 0), count: 2);
            expect(inner.offset, moreOrLessEquals(edgeOffset, epsilon: 0.5), reason: '横向移动不是纵向滚动可消费轴');
            expect(outer.offset, 0, reason: '同一段拖拽已纵向胜出，水平祖先不得补启动');

            await dragSteps(tester, gesture, _inwardDrag(Axis.vertical, boundary, distance: 110));
            _expectMovedInward(inner, boundary, edgeOffset, reason: '回到纵向位移后仍由已胜出的纵向子滚动接住');
            expect(outer.offset, 0, reason: '纵轴生命周期内外层水平始终不能动');
            await finishDrag(tester, gesture);
          });
        }
      }
    });

    group('新手势：松手后重新按轴竞争', () {
      for (final kind in _dragKinds) {
        final device = kind;
        testWidgets('${_kindName(device)} 横向手势结束后，新竖向手势可由垂直外层胜出', (tester) async {
          final outer = ScrollController();
          final inner = ScrollController();
          addTearDown(outer.dispose);
          addTearDown(inner.dispose);
          await tester.pumpWidget(
            verticalOuterHorizontalInner(outer, inner, mouseDrag: device == PointerDeviceKind.mouse),
          );
          await tester.pump();

          final first = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
          await dragSteps(tester, first, const Offset(-70, 0), count: 3);
          expect(inner.offset, greaterThan(0), reason: '前置：第一段横向手势确实驱动了内层');
          await finishDrag(tester, first);
          final innerAfterFirst = inner.offset;

          final second = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
          await dragSteps(tester, second, const Offset(0, -90), count: 2);
          expect(outer.offset, greaterThan(0), reason: '松手后的新手势要重新竞争，竖向应由外层胜出');
          expect(inner.offset, moreOrLessEquals(innerAfterFirst, epsilon: 0.5), reason: '新竖向手势不应改变横向子滚动');
          await finishDrag(tester, second);
        });
      }

      for (final kind in _dragKinds) {
        final device = kind;
        testWidgets('${_kindName(device)} 纵向手势结束后，新横向手势可由水平外层胜出', (tester) async {
          final outer = ScrollController();
          final inner = ScrollController();
          addTearDown(outer.dispose);
          addTearDown(inner.dispose);
          await tester.pumpWidget(
            horizontalOuterVerticalInner(outer, inner, mouseDrag: device == PointerDeviceKind.mouse),
          );
          await tester.pump();

          final first = await dragDown(tester, find.byKey(_innerVerticalInHorizontalKey), kind: device);
          await dragSteps(tester, first, const Offset(0, -70), count: 3);
          expect(inner.offset, greaterThan(0), reason: '前置：第一段纵向手势确实驱动了内层');
          await finishDrag(tester, first);
          final innerAfterFirst = inner.offset;

          final second = await dragDown(tester, find.byKey(_innerVerticalInHorizontalKey), kind: device);
          await dragSteps(tester, second, const Offset(-90, 0), count: 2);
          expect(outer.offset, greaterThan(0), reason: '松手后的新手势要重新竞争，横向应由外层胜出');
          expect(inner.offset, moreOrLessEquals(innerAfterFirst, epsilon: 0.5), reason: '新横向手势不应改变纵向子滚动');
          await finishDrag(tester, second);
        });
      }
    });

    group('最高级 bouncing 边界回弹', () {
      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 单个横向滚动 ${_edgeLabel(boundary)} 边界继续外拖必须进入弹性区并回弹', (tester) async {
            final controller = ScrollController();
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              singleHorizontalBouncingShell(controller, mouseDrag: device == PointerDeviceKind.mouse),
            );
            await tester.pump();
            final edgeOffset = _jumpToEdge(controller, boundary);
            await tester.pump();

            final gesture = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, gesture, _outwardDrag(Axis.horizontal, boundary, distance: 70), count: 3);

            _expectBouncedOutward(controller, boundary, edgeOffset, reason: '最高级横向滚动没有同轴祖先，边界外拖必须保留 iOS 弹性位移');

            await finishDrag(tester, gesture);
            _expectAtEdge(controller, boundary, reason: '松手后必须按 bouncing spring 回到边界');
          });
        }
      }

      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 垂直外层包横向滚动时，横向 ${_edgeLabel(boundary)} 边界仍是最高级并继续回弹', (tester) async {
            final outer = ScrollController();
            final inner = ScrollController();
            addTearDown(outer.dispose);
            addTearDown(inner.dispose);
            await tester.pumpWidget(
              verticalOuterHorizontalInner(
                outer,
                inner,
                mouseDrag: device == PointerDeviceKind.mouse,
                innerPhysics: const BouncingScrollPhysics(),
              ),
            );
            await tester.pump();
            final innerEdgeOffset = _jumpToEdge(inner, boundary);
            await tester.pump();
            final outerBefore = outer.offset;

            final gesture = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, gesture, _outwardDrag(Axis.horizontal, boundary, distance: 70), count: 3);

            _expectBouncedOutward(inner, boundary, innerEdgeOffset, reason: '外层只有纵向消费者时，横向内层就是横轴最高级，不能被边界逻辑吞掉弹性区');
            expect(outer.offset, moreOrLessEquals(outerBefore, epsilon: 0.5), reason: '横向 bouncing 不能带动垂直外层');

            await finishDrag(tester, gesture);
            _expectAtEdge(inner, boundary, reason: '横向内层松手后必须按原 bouncing 动画回位');
            expect(outer.offset, moreOrLessEquals(outerBefore, epsilon: 0.5), reason: '整段横向回弹都不能冒泡到垂直外层');
          });
        }
      }

      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 单个横向滚动 ${_edgeLabel(boundary)} 回弹动画中重新外拖必须继续加深弹性位移', (tester) async {
            final controller = ScrollController();
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              singleHorizontalBouncingShell(controller, mouseDrag: device == PointerDeviceKind.mouse),
            );
            await tester.pump();
            final edgeOffset = _jumpToEdge(controller, boundary);
            await tester.pump();

            final first = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, first, _outwardDrag(Axis.horizontal, boundary, distance: 90), count: 4);
            _expectBouncedOutward(controller, boundary, edgeOffset, reason: '前置：第一段拖拽已经把横向滚动拉进弹性区');
            await first.up();
            await tester.pump(const Duration(milliseconds: 16));
            _expectBouncedOutward(controller, boundary, edgeOffset, reason: '前置：松手后一帧仍处在 bouncing 回弹动画中');
            final offsetDuringSpring = controller.offset;

            final second = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, second, _outwardDrag(Axis.horizontal, boundary, distance: 90), count: 2);

            _expectBouncedFurtherOutward(
              controller,
              boundary,
              offsetDuringSpring,
              reason: '最高级横向滚动在回弹中被重新外拖时，必须取消回位并继续加深弹性位移',
            );

            await finishDrag(tester, second);
            _expectAtEdge(controller, boundary, reason: '第二次松手后仍必须回弹归位');
          });
        }
      }

      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 垂直外层包横向滚动时，横向 ${_edgeLabel(boundary)} 回弹动画中重新外拖必须继续回弹', (tester) async {
            final outer = ScrollController();
            final inner = ScrollController();
            addTearDown(outer.dispose);
            addTearDown(inner.dispose);
            await tester.pumpWidget(
              verticalOuterHorizontalInner(
                outer,
                inner,
                mouseDrag: device == PointerDeviceKind.mouse,
                innerPhysics: const BouncingScrollPhysics(),
              ),
            );
            await tester.pump();
            final innerEdgeOffset = _jumpToEdge(inner, boundary);
            await tester.pump();
            final outerBefore = outer.offset;

            final first = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, first, _outwardDrag(Axis.horizontal, boundary, distance: 90), count: 4);
            _expectBouncedOutward(inner, boundary, innerEdgeOffset, reason: '前置：嵌套横向滚动已经进入弹性区');
            await first.up();
            await tester.pump(const Duration(milliseconds: 16));
            _expectBouncedOutward(inner, boundary, innerEdgeOffset, reason: '前置：内层横向滚动仍在回弹动画中');
            final offsetDuringSpring = inner.offset;

            final second = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, second, _outwardDrag(Axis.horizontal, boundary, distance: 90), count: 2);

            _expectBouncedFurtherOutward(
              inner,
              boundary,
              offsetDuringSpring,
              reason: '横轴没有同轴祖先时，回弹中再次外拖不能被垂直外层或边界分支钉死',
            );
            expect(outer.offset, moreOrLessEquals(outerBefore, epsilon: 0.5), reason: '横向回弹重入不能带动垂直外层');

            await finishDrag(tester, second);
            _expectAtEdge(inner, boundary, reason: '重入拖拽松手后必须继续按 bouncing spring 回位');
            expect(outer.offset, moreOrLessEquals(outerBefore, epsilon: 0.5), reason: '重入回弹全过程不能冒泡到垂直外层');
          });
        }
      }
    });

    group('同轴接力：祖先滚动、Tab 与 dragProxy', () {
      for (final axis in Axis.values) {
        for (final kind in _dragKinds) {
          for (final edge in _BoundaryEdge.values) {
            final scrollAxis = axis;
            final device = kind;
            final boundary = edge;
            testWidgets('${_kindName(device)} ${_axisName(scrollAxis)} 内外滚动同轴 ${_edgeLabel(boundary)} 边界由外层接力', (
              tester,
            ) async {
              final outer = ScrollController();
              final inner = ScrollController();
              addTearDown(outer.dispose);
              addTearDown(inner.dispose);
              await tester.pumpWidget(
                sameAxisScrollShell(scrollAxis, outer, inner, mouseDrag: device == PointerDeviceKind.mouse),
              );
              await tester.pump();
              final innerEdgeOffset = _jumpToEdge(inner, boundary);
              final outerStartOffset = 120.0;
              outer.jumpTo(outerStartOffset);
              await tester.pump();

              final gesture = await dragDown(tester, find.byKey(_keyForAxis(scrollAxis)), kind: device);
              await dragSteps(tester, gesture, _outwardDrag(scrollAxis, boundary, distance: 70), count: 3);

              expect(inner.offset, moreOrLessEquals(innerEdgeOffset, epsilon: 0.5), reason: '内层贴边后不应继续越界滚');
              if (boundary == _BoundaryEdge.leading) {
                expect(outer.offset, lessThan(outerStartOffset), reason: '同轴 leading 边界余量应让外层回滚');
              } else {
                expect(outer.offset, greaterThan(outerStartOffset), reason: '同轴 trailing 边界余量应让外层前进');
              }
              await finishDrag(tester, gesture);
            });
          }
        }
      }

      for (final kind in _dragKinds) {
        for (final edge in _BoundaryEdge.values) {
          final device = kind;
          final boundary = edge;
          testWidgets('${_kindName(device)} 横向子滚动 ${_edgeLabel(boundary)} 边界可让同轴 ElTabView 接力翻页', (tester) async {
            final tabInitialIndex = boundary == _BoundaryEdge.leading ? 1 : 0;
            final expectedIndex = boundary == _BoundaryEdge.leading ? 0 : 1;
            final tab = ElTabController(length: 2, initialIndex: tabInitialIndex);
            final inner = ScrollController();
            addTearDown(tab.dispose);
            addTearDown(inner.dispose);
            await tester.pumpWidget(
              tabWithHorizontalInner(tab, inner, edge: boundary, mouseDrag: device == PointerDeviceKind.mouse),
            );
            await tester.pump();
            final innerEdgeOffset = _jumpToEdge(inner, boundary);
            await tester.pump();

            final gesture = await dragDown(tester, find.byKey(_innerHorizontalKey), kind: device);
            await dragSteps(tester, gesture, _outwardDrag(Axis.horizontal, boundary, distance: 70), count: 6);
            await finishDrag(tester, gesture);

            expect(inner.offset, moreOrLessEquals(innerEdgeOffset, epsilon: 0.5), reason: '子横滚在边界方向 0 消费');
            expect(tab.index, expectedIndex, reason: '同轴边界余量必须交给 ElTabView 完成翻页');
          });
        }
      }

      for (final proxyAxis in Axis.values) {
        for (final kind in _dragKinds) {
          for (final edge in _BoundaryEdge.values) {
            final axis = proxyAxis;
            final device = kind;
            final boundary = edge;
            testWidgets('${_kindName(device)} ${_axisName(axis)} 边界余量可穿过异轴中层到达同轴 dragProxy', (tester) async {
              final middle = ScrollController();
              final inner = ScrollController();
              final overflowDeltas = <double>[];
              addTearDown(middle.dispose);
              addTearDown(inner.dispose);
              await tester.pumpWidget(
                proxyThroughCrossAxisMiddle(
                  axis,
                  middle,
                  inner,
                  mouseDrag: device == PointerDeviceKind.mouse,
                  proxyEvent: ElEvent(
                    dragProxy: ElDragProxy(
                      axis: axis,
                      onDragOverflow: (event) => overflowDeltas.add(event.remainingPrimaryDelta(axis)),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final targetKey = axis == Axis.horizontal ? _innerHorizontalKey : _innerVerticalInHorizontalKey;
              _jumpToEdge(inner, boundary);
              await tester.pump();

              final gesture = await dragDown(tester, find.byKey(targetKey), kind: device);
              await dragSteps(tester, gesture, _outwardDrag(axis, boundary, distance: 60), count: 3);
              await finishDrag(tester, gesture);

              expect(overflowDeltas, isNotEmpty, reason: '同轴 proxy 必须收到边界余量');
              expect(
                overflowDeltas.every((delta) => boundary == _BoundaryEdge.leading ? delta > 0 : delta < 0),
                isTrue,
                reason: 'proxy 收到的余量方向要与边界拖出方向一致',
              );
              expect(middle.offset, 0, reason: '中间异轴滚动只允许穿透，不能消费');
            });
          }
        }
      }
    });

    group('异轴代理：Tab 与 dragProxy 不能抢轴', () {
      for (final kind in _dragKinds) {
        final device = kind;
        testWidgets('${_kindName(device)} 横向 Tab 包纵向滚动，纵向触顶和横向噪声都不得翻页', (tester) async {
          final tab = ElTabController(length: 2);
          final inner = ScrollController();
          addTearDown(tab.dispose);
          addTearDown(inner.dispose);
          await tester.pumpWidget(
            app(
              SizedBox(
                width: 240,
                height: 200,
                child: ElTabView(
                  controller: tab,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    ElScrollView(
                      key: const ValueKey('tab-inner-v'),
                      controller: inner,
                      physics: const ClampingScrollPhysics(),
                      children: rows('tab-v', 10, width: 240),
                    ),
                    const ElView(style: ElStyle(width: 240, height: 200)),
                  ],
                ),
              ),
              mouseDrag: device == PointerDeviceKind.mouse,
            ),
          );
          await tester.pump();
          expect(inner.offset, 0, reason: '前置：内层纵向滚动在顶部');
          expect(tab.position, 0, reason: '前置：Tab 在第一页');

          final gesture = await dragDown(tester, find.byKey(const ValueKey('tab-inner-v')), kind: device);
          await dragSteps(tester, gesture, const Offset(-30, 40), count: 2);
          expect(inner.offset, 0, reason: '顶部继续下拉不产生纵向位移');
          expect(tab.position, closeTo(0, precisionErrorTolerance), reason: '纵向触顶带横向噪声也不能让 Tab 接管');

          await dragSteps(tester, gesture, const Offset(-80, 0), count: 2);
          expect(tab.position, closeTo(0, precisionErrorTolerance), reason: '纵轴锁定后连续横移也不得补启动 Tab');

          await dragSteps(tester, gesture, const Offset(0, -120));
          expect(inner.offset, greaterThan(0), reason: '同手势反向上滑仍由原纵向滚动接住');
          expect(tab.position, closeTo(0, precisionErrorTolerance), reason: 'Tab 全程不应翻页');
          await finishDrag(tester, gesture);
        });
      }

      for (final kind in _dragKinds) {
        final device = kind;
        testWidgets('${_kindName(device)} 外层纵向滚动胜出后，内层横向 Tab 不得补启动', (tester) async {
          final outer = ScrollController();
          final tab = ElTabController(length: 2);
          addTearDown(outer.dispose);
          addTearDown(tab.dispose);
          await tester.pumpWidget(
            app(
              SizedBox(
                width: 240,
                height: 200,
                child: ElScrollView(
                  controller: outer,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    SizedBox(
                      key: const ValueKey('outer-top-inner-tab'),
                      width: 240,
                      height: 200,
                      child: ElTabView(
                        controller: tab,
                        physics: const ClampingScrollPhysics(),
                        children: const [
                          ElView(style: ElStyle(width: 240, height: 200)),
                          ElView(style: ElStyle(width: 240, height: 200)),
                        ],
                      ),
                    ),
                    ...rows('outer-tab-v', 10, width: 240),
                  ],
                ),
              ),
              mouseDrag: device == PointerDeviceKind.mouse,
            ),
          );
          await tester.pump();

          final gesture = await dragDown(tester, find.byKey(const ValueKey('outer-top-inner-tab')), kind: device);
          await dragSteps(tester, gesture, const Offset(0, 50), count: 2);
          expect(outer.offset, 0, reason: '外层顶部继续下拉不产生纵向位移');
          expect(tab.position, closeTo(0, precisionErrorTolerance), reason: '纵向触顶阶段内层 Tab 不得翻页');

          await dragSteps(tester, gesture, const Offset(-80, 0), count: 2);
          expect(tab.position, closeTo(0, precisionErrorTolerance), reason: '外层纵轴锁定后内层横向 Tab 不得补启动');
          await finishDrag(tester, gesture);
          expect(tab.position, closeTo(0, precisionErrorTolerance), reason: '松手后也不得用横向速度翻页');
        });
      }

      for (final innerAxis in Axis.values) {
        for (final kind in _dragKinds) {
          for (final edge in _BoundaryEdge.values) {
            final axis = innerAxis;
            final proxyAxis = _oppositeAxis(axis);
            final device = kind;
            final boundary = edge;
            testWidgets('${_kindName(device)} ${_axisName(axis)} 子滚动边界余量不得交给${_axisName(proxyAxis)} dragProxy', (
              tester,
            ) async {
              final inner = ScrollController();
              final overflowDeltas = <double>[];
              addTearDown(inner.dispose);
              await tester.pumpWidget(
                crossAxisProxyShell(
                  axis,
                  inner,
                  mouseDrag: device == PointerDeviceKind.mouse,
                  proxyEvent: ElEvent(
                    dragProxy: ElDragProxy(
                      axis: proxyAxis,
                      onDragOverflow: (event) => overflowDeltas.add(event.remainingPrimaryDelta(proxyAxis)),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final targetKey = axis == Axis.horizontal ? _innerHorizontalKey : _innerVerticalInHorizontalKey;
              _jumpToEdge(inner, boundary);
              await tester.pump();

              final gesture = await dragDown(tester, find.byKey(targetKey), kind: device);
              await dragSteps(tester, gesture, _outwardDrag(axis, boundary, distance: 60), count: 3);
              await finishDrag(tester, gesture);

              expect(overflowDeltas, isEmpty, reason: '异轴 dragProxy 不能接收子滚动的边界拖拽余量');
            });
          }
        }
      }
    });

    group('滚轮隔离：pointer signal 不溢出到异轴外层', () {
      for (final edge in _BoundaryEdge.values) {
        final boundary = edge;
        testWidgets('鼠标纵向滚轮转横向滚动时，横向内层 ${_edgeLabel(boundary)} 边界吞掉输入', (tester) async {
          final outer = ScrollController();
          final inner = ScrollController();
          addTearDown(outer.dispose);
          addTearDown(inner.dispose);
          await tester.pumpWidget(verticalOuterHorizontalInner(outer, inner, mouseWheelHorizontalModifiers: null));
          await tester.pump();
          final innerEdgeOffset = _jumpToEdge(inner, boundary);
          outer.jumpTo(40);
          await tester.pump();
          final outerBefore = outer.offset;

          await _sendWheel(
            tester,
            position: tester.getCenter(find.byKey(_innerHorizontalKey)),
            scrollDelta: Offset(0, _wheelOutwardDelta(boundary)),
          );

          expect(inner.offset, moreOrLessEquals(innerEdgeOffset, epsilon: 0.5), reason: '横向内层在边界方向不再前进');
          expect(outer.offset, moreOrLessEquals(outerBefore, epsilon: 0.5), reason: '转译后的滚轮输入不能漏给垂直外层');
        });
      }

      for (final edge in _BoundaryEdge.values) {
        final boundary = edge;
        testWidgets('鼠标原生横向滚轮到横向内层 ${_edgeLabel(boundary)} 边界时，不影响垂直外层', (tester) async {
          final outer = ScrollController();
          final inner = ScrollController();
          addTearDown(outer.dispose);
          addTearDown(inner.dispose);
          await tester.pumpWidget(verticalOuterHorizontalInner(outer, inner));
          await tester.pump();
          final innerEdgeOffset = _jumpToEdge(inner, boundary);
          outer.jumpTo(40);
          await tester.pump();
          final outerBefore = outer.offset;

          await _sendWheel(
            tester,
            position: tester.getCenter(find.byKey(_innerHorizontalKey)),
            scrollDelta: Offset(_wheelOutwardDelta(boundary), 0),
          );

          expect(inner.offset, moreOrLessEquals(innerEdgeOffset, epsilon: 0.5), reason: '横向内层在边界方向不再前进');
          expect(outer.offset, moreOrLessEquals(outerBefore, epsilon: 0.5), reason: '原生横向滚轮不能影响垂直外层');
        });
      }
    });
  });

  group('阻尼输入分配', () {
    for (final pan in [false, true]) {
      for (final nonlinear in [false, true]) {
        for (final configuration in <(double?, bool)>[
          (null, false),
          (2, false),
          (0, false),
          (null, true),
          (2, true),
          (0, true),
        ]) {
          final capacity = configuration.$1;
          final reverse = configuration.$2;
          final boundary = capacity != null;
          final input = capacity == 0 ? 20.3 : 20.0;
          for (final sign in [1.0, -1.0]) {
            final rawSign = sign * (reverse ? -1 : 1);
            testWidgets('pan=$pan nonlinear=$nonlinear capacity=$capacity reverse=$reverse sign=$sign：阻尼位移与输入接受量分别守恒', (
              tester,
            ) async {
              final controller = ElScrollController();
              addTearDown(controller.dispose);
              final key = GlobalKey<_ProbeState>();
              await tester.pumpWidget(
                Directionality(
                  textDirection: .ltr,
                  child: Align(
                    alignment: .topLeft,
                    child: ElView(
                      style: const ElStyle(width: 300, height: 200),
                      child: ElScrollView(
                        controller: controller,
                        reverse: reverse,
                        physics: _DampedPhysics(nonlinear: nonlinear),
                        scrollbar: const ElNoScrollBar(),
                        children: [
                          _Probe(key: key),
                          const ElView(style: ElStyle(height: 1000)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              controller.jumpTo(
                capacity != null ? (rawSign > 0 ? controller.position.maxScrollExtent - capacity : capacity) : 200,
              );
              await tester.pump();
              final before = controller.offset;
              final t0 = tester.binding.currentSystemFrameTimeStamp;
              const center = Offset(150, 100);
              if (pan) {
                await tester.sendEventToBinding(PointerPanZoomStartEvent(pointer: 81, position: center, timeStamp: t0));
                await tester.sendEventToBinding(
                  PointerPanZoomUpdateEvent(
                    pointer: 81,
                    position: center,
                    pan: Offset(0, -input * sign),
                    panDelta: Offset(0, -input * sign),
                    timeStamp: t0 + const Duration(milliseconds: 16),
                  ),
                );
              } else {
                await tester.sendEventToBinding(
                  PointerDownEvent(pointer: 81, kind: PointerDeviceKind.touch, position: center, timeStamp: t0),
                );
                for (final move in [(30.0, 30.0, 8), (30 + input, input, 16)]) {
                  await tester.sendEventToBinding(
                    PointerMoveEvent(
                      pointer: 81,
                      kind: PointerDeviceKind.touch,
                      position: center + Offset(0, -move.$1 * sign),
                      delta: Offset(0, -move.$2 * sign),
                      timeStamp: t0 + Duration(milliseconds: move.$3),
                    ),
                  );
                }
              }
              final displacement = (controller.offset - before) * rawSign;
              expect(displacement, closeTo(capacity ?? (nonlinear ? 10 : 5), 1e-8));
              if (boundary) {
                final acceptedInput = capacity == 0
                    ? 0
                    : nonlinear
                    ? (math.sqrt(1040) - 20) / 2
                    : 8;
                expect(key.currentState!.posts, hasLength(1));
                expect(key.currentState!.posts.single * sign, closeTo(input - acceptedInput, 1e-8));
                expect(acceptedInput + key.currentState!.posts.single * sign, closeTo(input, 1e-8));
              } else {
                expect(key.currentState!.posts, isEmpty);
              }
              if (pan) {
                await tester.sendEventToBinding(
                  PointerPanZoomEndEvent(
                    pointer: 81,
                    position: center,
                    timeStamp: t0 + const Duration(milliseconds: 200),
                  ),
                );
              } else {
                await tester.sendEventToBinding(
                  PointerUpEvent(
                    pointer: 81,
                    kind: PointerDeviceKind.touch,
                    position: center + Offset(0, -(30 + input) * sign),
                    timeStamp: t0 + const Duration(milliseconds: 200),
                  ),
                );
              }
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });

  group('输入绑定注销', () {
    for (final pan in [false, true]) {
      testWidgets('pan=$pan：实际 position 换绑后忽略旧序列尾段，新手势正常开始', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final key = GlobalKey<_InputBindingRetirementProbeState>();
        var dpr = 3.0;
        late StateSetter update;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQueryData(devicePixelRatio: dpr),
                child: Directionality(
                  textDirection: .ltr,
                  child: Align(
                    alignment: .topLeft,
                    child: ElView(
                      style: const ElStyle(width: 200, height: 200),
                      child: ElScrollView(
                        controller: controller,
                        physics: const ElClampingScrollPhysics(),
                        scrollbar: const ElNoScrollBar(),
                        children: [_InputBindingRetirementProbe(key: key)],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pump();
        final t0 = tester.binding.currentSystemFrameTimeStamp;
        const center = Offset(100, 150);
        Future<void> start(int pointer, int ms) => tester.sendEventToBinding(
          pan
              ? PointerPanZoomStartEvent(
                  pointer: pointer,
                  position: center,
                  timeStamp: t0 + Duration(milliseconds: ms),
                )
              : PointerDownEvent(
                  pointer: pointer,
                  kind: PointerDeviceKind.touch,
                  position: center,
                  timeStamp: t0 + Duration(milliseconds: ms),
                ),
        );
        Future<void> move(int pointer, double total, double delta, int ms) => tester.sendEventToBinding(
          pan
              ? PointerPanZoomUpdateEvent(
                  pointer: pointer,
                  position: center,
                  pan: Offset(0, -total),
                  panDelta: Offset(0, -delta),
                  timeStamp: t0 + Duration(milliseconds: ms),
                )
              : PointerMoveEvent(
                  pointer: pointer,
                  kind: PointerDeviceKind.touch,
                  position: center + Offset(0, -total),
                  delta: Offset(0, -delta),
                  timeStamp: t0 + Duration(milliseconds: ms),
                ),
        );
        Future<void> end(int pointer, int ms) => tester.sendEventToBinding(
          pan
              ? PointerPanZoomEndEvent(
                  pointer: pointer,
                  position: center,
                  timeStamp: t0 + Duration(milliseconds: ms),
                )
              : PointerUpEvent(
                  pointer: pointer,
                  kind: PointerDeviceKind.touch,
                  position: center + const Offset(0, -70),
                  timeStamp: t0 + Duration(milliseconds: ms),
                ),
        );
        await start(91, 0);
        if (!pan) await move(91, 30, 30, 8);
        await move(91, pan ? 20 : 50, 20, 16);
        expect(controller.offset, 20);
        final oldPosition = controller.position;
        update(() => dpr = 2);
        await tester.pump();
        expect(controller.position, isNot(same(oldPosition)));
        await move(91, pan ? 40 : 70, 20, 32);
        expect(controller.offset, 20);
        expect(key.currentState!.inputs, hasLength(1));
        await end(91, 160);
        await start(92, 200);
        if (!pan) await move(92, 30, 30, 208);
        await move(92, pan ? 20 : 50, 20, 216);
        expect(controller.offset, 40);
        final inputs = key.currentState!.inputs;
        expect(inputs, hasLength(2));
        expect(inputs.last.sessionId, isNot(inputs.first.sessionId));
        expect(inputs.last.snapshot.bindingGeneration, greaterThan(inputs.first.snapshot.bindingGeneration));
        await end(92, 400);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('嵌套拖动交接', () {
    for (final controllers in ['default', 'el', 'flutter']) {
      testWidgets('$controllers 双轴原生 pan 同帧消费两分量，任一轴撞边界都不写祖先', (tester) async {
        final page = _NestedPage(controllers, shape: .dualVertical);
        await page.mount(tester);
        final innerHorizontal = page.innerKey.currentState!.horizontalPosition!;
        final outerHorizontal = page.outerKey.currentState!.horizontalPosition!;
        expect(outerHorizontal.maxScrollExtent, greaterThan(0), reason: '横向祖先必须真实可滚，不能用无范围的假对照');
        page.inner.jumpTo(100);
        innerHorizontal.jumpTo(100);
        await tester.pump();
        final parents = page.parentOffsets;
        final gesture = await _Input.start(tester, page.point(tester), .trackpad);
        await gesture.move(const Offset(-30, -40));
        expect(page.inner.pixels, closeTo(140, .01));
        expect(innerHorizontal.pixels, closeTo(130, .01));
        for (final delta in [const Offset(-450, -440), const Offset(-30, -30)]) {
          await gesture.move(delta);
          expect(page.inner.pixels, closeTo(page.inner.maxScrollExtent, .01));
          expect(innerHorizontal.pixels, closeTo(innerHorizontal.maxScrollExtent, .01));
          page.expectParents(parents, '双轴 pan 的纵向接收者撞边界也不能换成祖先');
          expect(outerHorizontal.pixels, 0, reason: '双轴 pan 的横向接收者也必须保持同轴隔离');
        }
        await gesture.end();
      });
      for (final refresh in ['inner', 'outer', 'both']) {
        for (final leading in [false, true]) {
          testWidgets('$controllers $refresh refresher ${leading ? "leading" : "trailing"} 不得授权普通祖先接管正文', (
            tester,
          ) async {
            final page = _NestedPage(controllers, refresh: refresh);
            await page.mount(tester);
            final sign = leading ? -1.0 : 1.0;
            final edge = leading ? page.inner.minScrollExtent : page.inner.maxScrollExtent;
            page.inner.jumpTo(edge - sign * 60);
            await tester.pump();
            final parents = page.parentOffsets;
            final gesture = await _Input.start(tester, page.point(tester), .touch);
            for (final delta in [30.0, 20.0, 90.0, 30.0]) {
              await gesture.move(page.drag(sign * delta));
              page.expectParents(parents, '本地刷新器不能把普通嵌套升级为正文联动');
            }
            expect(page.inner.pixels, closeTo(edge, .01));
            await gesture.end(cancel: true);
            page.expectParents(parents, '刷新结束不能给祖先遗留运动');
          });
        }
      }
      for (final input in <PointerDeviceKind>[.touch, .mouse, .trackpad]) {
        for (final shape in _Shape.values) {
          for (final leading in [false, true]) {
            testWidgets('$controllers ${input.name} ${shape.name} ${leading ? "leading" : "trailing"} 途中撞边界锁定，新手势才让位', (
              tester,
            ) async {
              final page = _NestedPage(controllers, shape: shape);
              await page.mount(tester);
              final edge = leading ? page.inner.minScrollExtent : page.inner.maxScrollExtent;
              final sign = leading ? -1.0 : 1.0;
              page.inner.jumpTo(edge - sign * 100);
              await tester.pump();
              final start = page.inner.pixels;
              final parents = page.parentOffsets;
              final gesture = await _Input.start(tester, page.point(tester), input);
              await gesture.move(page.drag(sign * 30));
              await gesture.move(page.drag(sign * 20));
              // 双轴 touch 的自由拖拽阈值更大，第三次输入确保越过阈值后已有正文更新。
              await gesture.move(page.drag(sign * 20));
              expect((page.inner.pixels - start) * sign, greaterThan(0), reason: '前置：同一手势已真实消费内层正文');
              expect((edge - page.inner.pixels) * sign, greaterThan(0), reason: '前置：尚未到边界，防止测成起手贴边');

              await gesture.move(page.drag(sign * 90));
              expect(page.inner.pixels, closeTo(edge, .01));
              page.expectParents(parents, '撞边界的同帧余量不能直接写入祖先');
              await gesture.move(page.drag(sign * 30));
              page.expectParents(parents, '同手势后续输入也不能交给祖先');
              await gesture.move(page.drag(-sign * 25));
              expect((edge - page.inner.pixels) * sign, greaterThan(0), reason: '回拖仍归原内层');
              page.expectParents(parents, '回拖不能先偿还错误的祖先位移');
              await gesture.end(cancel: leading);
              page.expectParents(parents, '结束或取消不得向祖先遗留惯性');

              page.inner.jumpTo(edge);
              await tester.pump();
              final next = await _Input.start(tester, page.point(tester), input);
              await next.move(page.drag(sign * 30));
              await next.move(page.drag(sign * 20));
              await next.move(page.drag(sign * 20));
              expect((page.outer.pixels - parents.first) * sign, greaterThan(0), reason: '新手势起手贴边必须仍能让同轴祖先接管');
              expect(page.inner.pixels, closeTo(edge, .01));
              await next.end();
              expect(tester.takeException(), isNull);
            });
          }
        }

        testWidgets('$controllers ${input.name} 三级滚动途中撞边界不越过中层或页面', (tester) async {
          final page = _NestedPage(controllers, threeLevels: true);
          await page.mount(tester);
          page.inner.jumpTo(page.inner.maxScrollExtent - 60);
          await tester.pump();
          final parents = page.parentOffsets;
          final gesture = await _Input.start(tester, page.point(tester), input);
          for (final delta in [30.0, 20.0, 90.0, 30.0]) {
            await gesture.move(page.drag(delta));
            page.expectParents(parents, '内层锁定必须同时守住中层和最外页面');
          }
          expect(page.inner.pixels, closeTo(page.inner.maxScrollExtent, .01));
          await gesture.end();
          page.expectParents(parents, '释放后两级祖先也必须保持原位');
        });

        for (final innerAxis in Axis.values) {
          testWidgets(
            '$controllers ${input.name} ${innerAxis.name} ${input == .trackpad ? "原生 pan 保留按轴消费" : "锁轴后异轴不能补启动"}，新手势可重新判轴',
            (tester) async {
              final page = _NestedPage(
                controllers,
                shape: innerAxis == .horizontal ? .horizontal : .vertical,
                crossAxisOuter: true,
              );
              await page.mount(tester);
              page.inner.jumpTo(page.inner.maxScrollExtent - 60);
              await tester.pump();
              final parents = page.parentOffsets;
              final gesture = await _Input.start(tester, page.point(tester), input);
              for (final delta in [30.0, 20.0, 90.0]) {
                await gesture.move(page.drag(delta));
              }
              expect(page.inner.pixels, closeTo(page.inner.maxScrollExtent, .01));
              final crossDelta = innerAxis == .horizontal ? const Offset(0, -30) : const Offset(-30, 0);
              await gesture.move(crossDelta * 2);
              // fe9de435e 已回退原生 pan 的跨轴锁；只对 touch/mouse 保持整段手势锁轴。
              if (input == .trackpad) {
                expect(page.outer.pixels, closeTo(parents.first + 60, .01), reason: '原生 pan 的另一分量必须仍能由对应轴容器消费');
              } else {
                page.expectParents(parents, '胜出轴不能被随后出现的异轴位移改判');
              }
              final outerAfterCross = page.outer.pixels;
              await gesture.move(page.drag(-25));
              expect(page.inner.pixels, lessThan(page.inner.maxScrollExtent), reason: '原轴反向回拖仍须由原内层消费');
              expect(page.outer.pixels, outerAfterCross, reason: '原轴回拖不应继续写异轴祖先');
              await gesture.end(cancel: true);
              final next = await _Input.start(tester, page.point(tester), input);
              await next.move(crossDelta);
              await next.move(crossDelta);
              expect(page.outer.pixels, greaterThan(outerAfterCross));
              await next.end();
            },
          );
        }

        testWidgets('$controllers ${input.name} NeverScrollable 祖先在贴边让位与途中撞边界时都不移动', (tester) async {
          final page = _NestedPage(controllers, outerDisabled: true);
          await page.mount(tester);
          final parents = page.parentOffsets;
          for (final distance in [60.0, 0.0]) {
            page.inner.jumpTo(page.inner.maxScrollExtent - distance);
            await tester.pump();
            final gesture = await _Input.start(tester, page.point(tester), input);
            for (final delta in [30.0, 20.0, 90.0]) {
              await gesture.move(page.drag(delta));
            }
            page.expectParents(parents, '协同入口也不能绕过祖先的用户滚动禁用');
            await gesture.end();
            page.expectParents(parents, '禁用祖先不能获得释放惯性');
          }
        });

        testWidgets('$controllers ${input.name} 离手前仍在内容区，惯性撞边界不能移动祖先', (tester) async {
          final page = _NestedPage(controllers);
          await page.mount(tester);
          page.inner.jumpTo(page.inner.maxScrollExtent - 160);
          await tester.pump();
          final parents = page.parentOffsets;
          final gesture = await _Input.start(tester, page.point(tester), input);
          for (final delta in [30.0, 40.0, 40.0]) {
            await gesture.move(page.drag(delta), milliseconds: 10);
          }
          expect(page.inner.pixels, lessThan(page.inner.maxScrollExtent), reason: '前置：边界必须由释放惯性到达');
          var ancestorMoved = false;
          void observe() => ancestorMoved |= page.outer.pixels != parents.first;
          page.outer.addListener(observe);
          await gesture.end(fling: true);
          page.outer.removeListener(observe);
          expect(page.inner.pixels, closeTo(page.inner.maxScrollExtent, .01), reason: '前置：释放速度确实驱动内层惯性到边界');
          expect(ancestorMoved, isFalse, reason: '祖先不能先动后恢复，必须整段惯性都未移动');
          page.expectParents(parents, '内层惯性终点不能交接到祖先正文');
        });
      }
    }
  });

  group('嵌套输入成员', () {
    for (final pan in [false, true]) {
      testWidgets('pan=$pan 按住时新增祖先 slot 只参与下一手势', (tester) async {
        final outer = ElScrollController();
        final inner = ElScrollController();
        addTearDown(outer.dispose);
        addTearDown(inner.dispose);
        var enabled = false;
        var calls = 0;
        late StateSetter update;
        await tester.pumpWidget(
          _shell(outer, [
            _inner(inner),
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return _Member(enabled: enabled, onInput: () => calls++);
              },
            ),
          ]),
        );
        await tester.pumpAndSettle();
        inner.jumpTo(inner.position.maxScrollExtent - 100);
        await tester.pump();
        final gesture = await tester.createGesture(kind: pan ? .trackpad : .touch);
        const point = Offset(100, 100);
        var distance = 0.0;
        var stamp = Duration.zero;
        Future<void> move(double delta) async {
          distance += delta;
          stamp += const Duration(milliseconds: 16);
          if (pan) {
            await gesture.panZoomUpdate(point, pan: Offset(0, -distance), timeStamp: stamp);
          } else {
            await gesture.moveTo(point + Offset(0, -distance), timeStamp: stamp);
          }
          await tester.pump(const Duration(milliseconds: 16));
        }

        if (pan) {
          await gesture.panZoomStart(point, timeStamp: stamp);
        } else {
          await gesture.down(point, timeStamp: stamp);
        }
        await move(30);
        await move(20);
        expect(inner.offset, greaterThan(inner.position.maxScrollExtent - 100));
        update(() => enabled = true);
        await tester.pumpAndSettle();
        await move(120);
        expect(calls, 0, reason: '新增参与者不能把旧设备序列改接到新路线');
        expect(outer.offset, 0);
        if (pan) {
          await gesture.panZoomEnd(timeStamp: stamp + const Duration(seconds: 1));
        } else {
          await gesture.cancel();
        }
        await tester.pumpAndSettle();
        await _crossBoundary(tester, inner);
        expect(calls, greaterThan(0));
        expect(outer.offset, greaterThan(0));
      });
    }

    testWidgets('仅观察不联动，后挂载 slot 的启停会通知已存在的内层', (tester) async {
      final outer = ElScrollController();
      final inner = ElScrollController();
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      var enabled = false;
      var calls = 0;
      late StateSetter update;
      final child = _inner(inner);
      await tester.pumpWidget(
        _shell(outer, [
          child,
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _Member(enabled: enabled, onInput: () => calls++);
            },
          ),
        ]),
      );
      await tester.pumpAndSettle();
      for (final active in [false, true, false, true]) {
        update(() => enabled = active);
        await tester.pumpAndSettle();
        outer.jumpTo(0);
        calls = 0;
        await _crossBoundary(tester, inner);
        if (active) {
          expect(calls, greaterThan(0));
          expect(outer.offset, greaterThan(0));
        } else {
          expect(calls, 0);
          expect(outer.offset, 0, reason: '保留观察 State 不得继续授权祖先正文接力');
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('显式协同也尊重祖先 NeverScrollable，slot 仍接收输入', (tester) async {
      final outer = ElScrollController();
      final inner = ElScrollController();
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      var calls = 0;
      await tester.pumpWidget(
        _shell(outer, [_inner(inner), _Member(enabled: true, onInput: () => calls++)], disabled: true),
      );
      await tester.pumpAndSettle();
      await _crossBoundary(tester, inner);
      expect(calls, greaterThan(0));
      expect(outer.offset, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Nested 区域外的兄弟内层不能借该区域推动祖先', (tester) async {
      final outer = ElScrollController();
      final outside = ElScrollController();
      addTearDown(outer.dispose);
      addTearDown(outside.dispose);
      await tester.pumpWidget(
        _shell(outer, [_inner(outside), const _Region(child: ElView(style: ElStyle(height: 20)))]),
      );
      await tester.pumpAndSettle();
      await _crossBoundary(tester, outside);
      expect(outer.offset, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('显式协同跨过普通中层时不能把中层正文当联动成员', (tester) async {
      final outer = ElScrollController();
      final middle = ElScrollController();
      final inner = ElScrollController();
      for (final controller in [outer, middle, inner]) {
        addTearDown(controller.dispose);
      }
      var calls = 0;
      await tester.pumpWidget(
        _shell(outer, [
          ElView(
            style: const ElStyle(height: 220),
            child: ElScrollView(
              controller: middle,
              scrollbar: const ElNoScrollBar(),
              physics: const ElClampingScrollPhysics(),
              children: [
                _inner(inner),
                const ElView(style: ElStyle(height: 800)),
              ],
            ),
          ),
          _Member(enabled: true, onInput: () => calls++),
        ]),
      );
      await tester.pumpAndSettle();
      await _crossBoundary(tester, inner);
      expect(calls, greaterThan(0));
      expect(outer.offset, greaterThan(0));
      expect(middle.offset, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('嵌套输入路线', () {
    testWidgets('祖先过滤释放速度后，源宿主仍保留原始释放详情', (tester) async {
      final inner = ElScrollController();
      addTearDown(inner.dispose);
      final trace = <String>[];
      final outerKey = GlobalKey<_ParticipantState>();
      final innerKey = GlobalKey<_ParticipantState>();
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 200, height: 200),
              child: ElScrollView(
                physics: const ElClampingScrollPhysics(),
                scrollbar: const ElNoScrollBar(),
                children: [
                  _Participant(
                    key: outerKey,
                    slot: 'outer',
                    trace: trace,
                    preFraction: 0,
                    fling: true,
                    flingFraction: .5,
                    child: ElView(
                      style: const ElStyle(height: 200),
                      child: ElScrollView(
                        controller: inner,
                        physics: const ElClampingScrollPhysics(),
                        scrollbar: const ElNoScrollBar(),
                        children: [
                          _Participant(
                            key: innerKey,
                            slot: 'inner',
                            trace: trace,
                            preFraction: 0,
                            child: const ElView(style: ElStyle(height: 1000)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final t0 = tester.binding.currentSystemFrameTimeStamp;
      const center = Offset(100, 150);
      await tester.sendEventToBinding(
        PointerDownEvent(pointer: 91, kind: PointerDeviceKind.touch, position: center, timeStamp: t0),
      );
      for (final move in [(30.0, 30.0, 8), (50.0, 20.0, 12)]) {
        await tester.sendEventToBinding(
          PointerMoveEvent(
            pointer: 91,
            kind: PointerDeviceKind.touch,
            position: center + Offset(0, -move.$1),
            delta: Offset(0, -move.$2),
            timeStamp: t0 + Duration(milliseconds: move.$3),
          ),
        );
      }
      await tester.sendEventToBinding(
        PointerUpEvent(
          pointer: 91,
          kind: PointerDeviceKind.touch,
          position: center + const Offset(0, -50),
          timeStamp: t0 + const Duration(milliseconds: 14),
        ),
      );
      final original = outerKey.currentState!.releases.single.releaseVelocity;
      expect(original, greaterThan(0));
      expect(innerKey.currentState!.releaseInputs.single, original * .5);
      expect(innerKey.currentState!.releases.single.releaseVelocity, original);
      expect(
        innerKey.currentState!.releases.single.sourceScrollView,
        same(outerKey.currentState!.releases.single.sourceScrollView),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final phase in ['outer_pre', 'inner_pre', 'inner_body', 'outer_body', 'activity_start', 'ballistic']) {
      testWidgets('祖先路线 $phase 中的新 raw 动画接管整组旧输入', (tester) async {
        final inner = ElScrollController();
        final outer = ElScrollController();
        addTearDown(inner.dispose);
        addTearDown(outer.dispose);
        final trace = <String>[];
        var triggered = false;
        Future<void>? replacement;
        void takeOver() {
          if (triggered) return;
          triggered = true;
          replacement = (phase == 'outer_body' ? inner : outer).animateTo(
            phase == 'outer_body' ? 400 : 200,
            duration: const Duration(milliseconds: 100),
            curve: Curves.linear,
          );
        }

        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 200, height: 200),
                child: ElScrollView(
                  controller: outer,
                  physics: const ElClampingScrollPhysics(),
                  scrollbar: const ElNoScrollBar(),
                  children: [
                    const ElView(style: ElStyle(height: 2000)),
                    _Participant(
                      slot: 'outer',
                      trace: trace,
                      preFraction: 0,
                      fling: phase == 'ballistic',
                      onInput: (input) {
                        if (phase == 'outer_pre' ||
                            (phase == 'ballistic' && input.source == ElScrollInputSource.ballistic)) {
                          takeOver();
                        }
                      },
                      child: ElPositioned(
                        top: 0,
                        left: 0,
                        width: 200,
                        height: 200,
                        child: ElScrollView(
                          controller: inner,
                          physics: const ElClampingScrollPhysics(),
                          scrollbar: const ElNoScrollBar(),
                          children: [
                            _Participant(
                              slot: 'inner',
                              trace: trace,
                              preFraction: 0,
                              fling: phase == 'ballistic',
                              onInput: (_) {
                                if (phase == 'inner_pre') takeOver();
                              },
                              child: const ElView(style: ElStyle(height: 1000)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        inner.jumpTo(inner.position.maxScrollExtent - 5);
        await tester.pump();
        if (phase == 'inner_body') inner.addListener(takeOver);
        if (phase == 'outer_body') outer.addListener(takeOver);
        if (phase == 'activity_start') {
          outer.position.isScrollingNotifier.addListener(() {
            if (outer.position.isScrollingNotifier.value) takeOver();
          });
        }
        final t0 = tester.binding.currentSystemFrameTimeStamp;
        const center = Offset(100, 160);
        await tester.sendEventToBinding(
          PointerDownEvent(pointer: 81, kind: PointerDeviceKind.touch, position: center, timeStamp: t0),
        );
        for (final move in [(30.0, 30.0, 8), (110.0, 80.0, 16)]) {
          await tester.sendEventToBinding(
            PointerMoveEvent(
              pointer: 81,
              kind: PointerDeviceKind.touch,
              position: center + Offset(0, -move.$1),
              delta: Offset(0, -move.$2),
              timeStamp: t0 + Duration(milliseconds: move.$3),
            ),
          );
        }
        await tester.sendEventToBinding(
          PointerUpEvent(
            pointer: 81,
            kind: PointerDeviceKind.touch,
            position: center + const Offset(0, -110),
            timeStamp: t0 + Duration(milliseconds: phase == 'ballistic' ? 17 : 200),
          ),
        );
        await tester.pumpAndSettle();
        await replacement;
        expect(triggered, isTrue);
        expect(
          inner.offset,
          closeTo(
            phase == 'outer_body'
                ? 400
                : phase.endsWith('_pre')
                ? 795
                : 800,
            .01,
          ),
        );
        expect(outer.offset, closeTo(phase == 'outer_body' ? 75 : 200, .01));
        if (phase == 'outer_pre' || phase == 'inner_pre' || phase == 'inner_body') {
          expect(trace, isNot(contains('inner:post')));
        }
        expect(inner.position.isScrollingNotifier.value, isFalse);
        expect(outer.position.isScrollingNotifier.value, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    for (final orientation in [
      (Axis.vertical, TextDirection.ltr),
      (Axis.horizontal, TextDirection.ltr),
      (Axis.horizontal, TextDirection.rtl),
    ]) {
      final axis = orientation.$1;
      Offset vector(double amount) => axis == Axis.vertical ? Offset(0, amount) : Offset(amount, 0);
      for (final physics in <ScrollPhysics>[
        const ElClampingScrollPhysics(),
        const ElBrowserScrollPhysics(),
        const ElBouncingScrollPhysics(),
      ]) {
        for (final pan in [false, true]) {
          for (final innerReverse in [false, true]) {
            for (final configuration in [
              (false, false, false),
              (true, false, false),
              (false, true, false),
              (true, true, false),
              (false, false, true),
            ]) {
              final outerReverse = configuration.$1;
              final fling = configuration.$2;
              final terminal = configuration.$3;
              final elastic = terminal && physics is ElBouncingScrollPhysics;
              testWidgets(
                '${physics.runtimeType} $orientation pan=$pan innerReverse=$innerReverse outerReverse=$outerReverse fling=$fling terminal=$terminal：唯一祖先输入路线',
                (tester) async {
                  final inner = ElScrollController();
                  final outer = ElScrollController();
                  addTearDown(inner.dispose);
                  addTearDown(outer.dispose);
                  final trace = <String>[];
                  final innerKey = GlobalKey<_ParticipantState>();
                  final outerKey = GlobalKey<_ParticipantState>();
                  await tester.pumpWidget(
                    Directionality(
                      textDirection: orientation.$2,
                      child: Align(
                        alignment: .topLeft,
                        child: ElView(
                          style: const ElStyle(width: 200, height: 200),
                          child: ElScrollView(
                            axis: axis,
                            controller: outer,
                            reverse: outerReverse,
                            physics: physics,
                            scrollbar: const ElNoScrollBar(),
                            children: [
                              ElView(
                                style: ElStyle(
                                  width: axis == Axis.horizontal ? 2000 : null,
                                  height: axis == Axis.vertical ? 2000 : null,
                                ),
                              ),
                              _Participant(
                                key: outerKey,
                                slot: 'outer',
                                trace: trace,
                                preFraction: .25,
                                fling: fling,
                                child: ElPositioned(
                                  top: 0,
                                  left: 0,
                                  width: 200,
                                  height: 200,
                                  child: ElScrollView(
                                    axis: axis,
                                    controller: inner,
                                    reverse: innerReverse,
                                    physics: physics,
                                    scrollbar: const ElNoScrollBar(),
                                    children: [
                                      _Participant(
                                        key: innerKey,
                                        slot: 'inner',
                                        trace: trace,
                                        preFraction: .5,
                                        postFraction: .4,
                                        fling: fling,
                                        child: ElView(
                                          style: ElStyle(
                                            width: axis == Axis.horizontal ? 1000 : null,
                                            height: axis == Axis.vertical ? 1000 : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  await tester.pump();
                  inner.jumpTo(
                    axisDirectionIsReversed(inner.position.axisDirection) ? 5 : inner.position.maxScrollExtent - 5,
                  );
                  outer.jumpTo(
                    terminal
                        ? (axisDirectionIsReversed(outer.position.axisDirection)
                              ? 5
                              : outer.position.maxScrollExtent - 5)
                        : (axisDirectionIsReversed(outer.position.axisDirection) ? outer.position.maxScrollExtent : 0),
                  );
                  await tester.pump();
                  final beforeInner = _contentOffset(inner.position);
                  final beforeOuter = _contentOffset(outer.position);
                  inner.addListener(() => trace.add('inner:body'));
                  outer.addListener(() => trace.add('outer:body'));
                  final t0 = tester.binding.currentSystemFrameTimeStamp;
                  const center = Offset(100, 160);
                  if (pan) {
                    await tester.sendEventToBinding(
                      PointerPanZoomStartEvent(pointer: 81, position: center, timeStamp: t0),
                    );
                    await tester.sendEventToBinding(
                      PointerPanZoomUpdateEvent(
                        pointer: 81,
                        position: center,
                        pan: vector(-80),
                        panDelta: vector(-80),
                        timeStamp: t0 + const Duration(milliseconds: 16),
                      ),
                    );
                  } else {
                    await tester.sendEventToBinding(
                      PointerDownEvent(pointer: 81, kind: PointerDeviceKind.touch, position: center, timeStamp: t0),
                    );
                    for (final move in [(30.0, 30.0, 8), (110.0, 80.0, 16)]) {
                      await tester.sendEventToBinding(
                        PointerMoveEvent(
                          pointer: 81,
                          kind: PointerDeviceKind.touch,
                          position: center + vector(-move.$1),
                          delta: vector(-move.$2),
                          timeStamp: t0 + Duration(milliseconds: move.$3),
                        ),
                      );
                    }
                  }
                  expect(trace, [
                    'outer:pre',
                    'inner:pre',
                    'inner:body',
                    'inner:post',
                    'outer:body',
                    if (terminal) 'outer:post',
                    if (elastic) 'inner:body',
                  ]);
                  expect(_contentOffset(inner.position) - beforeInner, closeTo(elastic ? 15 : 5, 1e-8));
                  expect(_contentOffset(outer.position) - beforeOuter, closeTo(terminal ? 5 : 15, 1e-8));
                  expect(outerKey.currentState!.accepted, 20);
                  expect(innerKey.currentState!.accepted, 40);
                  final innerInput = innerKey.currentState!.inputs.first;
                  expect(innerKey.currentState!.inputs.last, same(innerInput));
                  expect(outerKey.currentState!.inputs.first.transactionId, innerInput.transactionId);
                  if (terminal) expect(outerKey.currentState!.inputs.first, same(outerKey.currentState!.inputs.last));
                  expect(innerInput.requestedDelta, 80);
                  if (fling) {
                    if (pan) {
                      await tester.sendEventToBinding(
                        PointerPanZoomUpdateEvent(
                          pointer: 81,
                          position: center,
                          pan: vector(-90),
                          panDelta: vector(-10),
                          timeStamp: t0 + const Duration(milliseconds: 20),
                        ),
                      );
                    } else {
                      await tester.sendEventToBinding(
                        PointerMoveEvent(
                          pointer: 81,
                          kind: PointerDeviceKind.touch,
                          position: center + vector(-120),
                          delta: vector(-10),
                          timeStamp: t0 + const Duration(milliseconds: 20),
                        ),
                      );
                    }
                  }
                  final beforeRelease = _contentOffset(outer.position);
                  final endTime = t0 + Duration(milliseconds: fling ? 21 : 200);
                  if (pan) {
                    await tester.sendEventToBinding(
                      PointerPanZoomEndEvent(pointer: 81, position: center, timeStamp: endTime),
                    );
                  } else {
                    await tester.sendEventToBinding(
                      PointerUpEvent(
                        pointer: 81,
                        kind: PointerDeviceKind.touch,
                        position: center + vector(fling ? -120 : -110),
                        timeStamp: endTime,
                      ),
                    );
                  }
                  await tester.pumpAndSettle();
                  if (fling) expect(_contentOffset(outer.position), greaterThan(beforeRelease));
                  expect(inner.position.isScrollingNotifier.value, isFalse);
                  expect(outer.position.isScrollingNotifier.value, isFalse);
                  expect(inner.position.outOfRange, isFalse);
                  expect(outer.position.outOfRange, isFalse);
                  expect(tester.takeException(), isNull);
                },
              );
            }
          }
        }
      }
    }
  });

  group('嵌套滚动协议', () {
    testWidgets('取消命令触发区域 end 时，回调中较新的 raw 动画保持所有权', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final log = _Log();
      Future<void>? replacement;
      await tester.pumpWidget(
        _app(
          _outer(
            _NestedScrollRegion(
              log: log,
              onEnd: () => replacement = controller.animateTo(
                300,
                duration: const Duration(milliseconds: 100),
                curve: Curves.linear,
              ),
              child: _nestedScrollInner(controller),
            ),
          ),
        ),
      );
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(_scroll(controller)));
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -20));
      controller.jumpTo(50);
      expect(log.ends, 1);
      await gesture.up();
      await tester.pumpAndSettle();
      await replacement;
      expect(controller.offset, closeTo(300, .01));
      expect(log.ends, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('区域在 pre 中停用不拆开当前 post，内部重启只参与下一手势', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_NestedScrollRegionState>();
      var disabled = false;
      await tester.pumpWidget(
        _app(
          _outer(
            _NestedScrollRegion(
              key: key,
              log: log,
              remainder: (remaining) {
                if (!disabled) {
                  disabled = true;
                  key.currentState!.setEnabled(false);
                }
                return remaining;
              },
              child: _nestedScrollInner(controller, count: 8),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      final position = controller.position;
      final gesture = await tester.startGesture(tester.getCenter(_scroll(controller)));
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(log.pre, 40);
      expect(log.post, 40);
      expect(log.ends, 1);
      key.currentState!.setEnabled(true);
      await gesture.moveBy(const Offset(0, -30));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log.pre, 40);
      expect(log.post, 40);
      expect(log.starts, 1);
      expect(log.ends, 1);
      expect(controller.position, same(position));
      await tester.drag(_scroll(controller), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(log.starts, 2);
      expect(log.ends, 2);
      expect(log.pre, greaterThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('区域 input end 在释放时发生，惯性中的 pre 不重复开始结束', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(_outer(_NestedScrollRegion(log: log, fraction: .5, child: _nestedScrollInner(controller)))),
      );
      await tester.pump();
      final t0 = tester.binding.currentSystemFrameTimeStamp;
      const center = Offset(100, 160);
      await tester.sendEventToBinding(
        PointerDownEvent(pointer: 91, kind: PointerDeviceKind.touch, position: center, timeStamp: t0),
      );
      for (final move in [(30.0, 30.0, 8), (50.0, 20.0, 12)]) {
        await tester.sendEventToBinding(
          PointerMoveEvent(
            pointer: 91,
            kind: PointerDeviceKind.touch,
            position: center + Offset(0, -move.$1),
            delta: Offset(0, -move.$2),
            timeStamp: t0 + Duration(milliseconds: move.$3),
          ),
        );
      }
      final directInput = log.pre;
      await tester.sendEventToBinding(
        PointerUpEvent(
          pointer: 91,
          kind: PointerDeviceKind.touch,
          position: center + const Offset(0, -50),
          timeStamp: t0 + const Duration(milliseconds: 14),
        ),
      );
      expect(log.starts, 1);
      expect(log.ends, 1);
      expect(controller.position.isScrollingNotifier.value, isTrue);
      await tester.pumpAndSettle();
      expect(log.pre, greaterThan(directInput));
      expect(log.starts, 1);
      expect(log.ends, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('嵌套区域消费也遵守同一宿主的显式 slot 顺序', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      await tester.pumpWidget(
        _app(
          _outer(
            _NestedScrollRegion(
              log: _Log(),
              name: 'a',
              slot: 'a',
              trace: trace,
              fraction: .5,
              child: _NestedScrollRegion(
                log: _Log(),
                name: 'b',
                slot: 'b',
                trace: trace,
                fraction: .5,
                child: _nestedScrollInner(controller),
              ),
            ),
            inputOrder: {
              Axis.vertical: ['b', 'a'],
            },
          ),
        ),
      );
      await tester.pump();
      await tester.drag(_scroll(controller), const Offset(0, -100));
      await tester.pumpAndSettle();
      final pre = trace.where((entry) => entry.endsWith(':pre')).toList();
      expect(pre, isNotEmpty);
      expect(pre, [
        for (var index = 0; index < pre.length ~/ 2; index++) ...['b:pre', 'a:pre'],
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('横向区域能绑定单轴和双轴外层的真实水平 position', (tester) async {
      for (final outerAxis in <Axis?>[Axis.horizontal, null]) {
        final log = _Log();
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            _outer(
              _NestedScrollRegion(
                log: log,
                axis: .horizontal,
                fraction: .5,
                child: _nestedScrollInner(controller, axis: .horizontal),
              ),
              axis: outerAxis,
            ),
          ),
        );
        await tester.pump();
        final before = controller.offset;
        await tester.drag(_scroll(controller), const Offset(-100, 0));
        await tester.pumpAndSettle();
        expect(log.axes, [Axis.horizontal]);
        expect(log.ends, 1);
        expect(log.pre, greaterThan(0));
        expect(controller.offset - before, closeTo(log.consumed.abs(), 2));
      }
    });

    testWidgets('真实后代 Mixin 在内层消费前分配 delta', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_NestedScrollRegionState>();
      final host = GlobalKey<ElScrollViewState>();
      await tester.pumpWidget(
        _app(
          _outer(
            _NestedScrollRegion(key: key, log: log, fraction: .5, child: _nestedScrollInner(controller)),
            key: host,
          ),
        ),
      );
      await tester.pump();
      expect(key.currentState!.scrollView, same(host.currentState));
      await tester.drag(_scroll(controller), const Offset(0, -100));
      await tester.pump();
      expect(log.pre, greaterThan(0));
      expect(controller.offset, closeTo(log.consumed.abs(), 2));
      await tester.pumpAndSettle();
    });

    testWidgets('start/end 配对且零速松手仍交接 preFling', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(_outer(_NestedScrollRegion(log: log, child: _nestedScrollInner(controller)))));
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(_scroll(controller)));
      await gesture.moveBy(const Offset(0, -35));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log.starts, 1);
      expect(log.ends, 1);
      expect(log.flings, 1);
      expect(log.axes, [Axis.vertical]);
    });

    testWidgets('到达内层边界后向 Mixin 上交余量', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(_outer(_NestedScrollRegion(log: log, child: _nestedScrollInner(controller, count: 8)))),
      );
      await tester.pump();
      controller.jumpTo(120);
      await tester.pump();
      await tester.drag(_scroll(controller), const Offset(0, -60));
      await tester.pump();
      expect(controller.offset, closeTo(120, .5));
      expect(log.post.abs(), greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('多层 region 保持外到内 pre 顺序，剩余量逐级消费', (tester) async {
      final a = _Log();
      final b = _Log();
      final trace = <String>[];
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          _outer(
            _NestedScrollRegion(
              log: a,
              name: 'a',
              fraction: .5,
              trace: trace,
              child: _NestedScrollRegion(
                log: b,
                name: 'b',
                fraction: .5,
                trace: trace,
                child: _nestedScrollInner(controller),
              ),
            ),
            inputOrder: {
              Axis.vertical: ['a', 'b'],
            },
          ),
        ),
      );
      await tester.pump();
      await tester.drag(_scroll(controller), const Offset(0, -100));
      await tester.pump();
      final pre = trace.where((event) => event.endsWith(':pre')).toList();
      expect(pre, isNotEmpty);
      expect(pre, [
        for (var i = 0; i < pre.length ~/ 2; i++) ...['a:pre', 'b:pre'],
      ]);
      expect(b.pre, closeTo(a.pre * .5, .01));
      expect(controller.offset, closeTo(a.pre.abs() * .25, 2));
      await tester.pumpAndSettle();
    });

    testWidgets('停用补齐 end，重新启用不接管已经开始的触摸会话', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _outer(
                _NestedScrollRegion(log: log, enabled: enabled, fraction: .5, child: _nestedScrollInner(controller)),
              );
            },
          ),
        ),
      );
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(_scroll(controller)));
      await gesture.moveBy(const Offset(0, -35));
      await tester.pump();
      expect(log.starts, 1);
      update(() => enabled = false);
      await tester.pump();
      expect(log.ends, 1);
      final before = log.pre;
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump();
      update(() => enabled = true);
      await tester.pump();
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump();
      expect(log.pre, before);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log.ends, 1);
      await tester.drag(_scroll(controller), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(log.starts, 2);
      expect(log.ends, 2);
      expect(log.pre.abs(), greaterThan(before.abs()));
    });

    testWidgets('活动区域移除时不会遗留会话或调用已卸载 State', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(_outer(_NestedScrollRegion(log: log, child: _nestedScrollInner(controller)))));
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(_scroll(controller)));
      await gesture.moveBy(const Offset(0, -35));
      await tester.pump();
      expect(log.starts, 1);
      await tester.pumpWidget(_app(const ElView()));
      expect(log.ends, 1);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log.ends, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GlobalKey 重父化后绑定新的真实外层宿主', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_NestedScrollRegionState>();
      final left = GlobalKey<ElScrollViewState>();
      final right = GlobalKey<ElScrollViewState>();
      var moved = false;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              final region = _NestedScrollRegion(
                key: key,
                log: log,
                fraction: .5,
                child: _nestedScrollInner(controller),
              );
              return Row(
                children: [
                  _outer(moved ? const ElView() : region, key: left),
                  _outer(moved ? region : const ElView(), key: right),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      final state = key.currentState;
      expect(state!.scrollView, same(left.currentState));
      update(() => moved = true);
      await tester.pump();
      expect(key.currentState, same(state));
      expect(state.scrollView, same(right.currentState));
      await tester.drag(_scroll(controller), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(log.starts, 1);
      expect(log.ends, 1);
      expect(log.pre, greaterThan(0));
    });

    testWidgets('垂直区域不截取内层横向输入', (tester) async {
      final log = _Log();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          _outer(
            _NestedScrollRegion(
              log: log,
              fraction: .5,
              child: _nestedScrollInner(controller, axis: .horizontal),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.drag(_scroll(controller), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(log.starts, 0);
      expect(log.pre, 0);
    });

    testWidgets('祖先页面 State 不能用 region helper 冒充滚动后代', (tester) async {
      await tester.pumpWidget(_app(_NestedScrollRegion(log: _Log(), child: const ElView())));
      expect(tester.takeException().toString(), contains('真实后代'));
    });

    testWidgets('公共 nested 剩余量拒绝 NaN、反号和放大', (tester) async {
      for (final remainder in <double Function(double)>[
        (delta) => double.nan,
        (delta) => -delta,
        (delta) => delta * 2,
      ]) {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            _outer(
              _NestedScrollRegion(
                key: UniqueKey(),
                log: _Log(),
                remainder: remainder,
                child: _nestedScrollInner(controller),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.sendEventToBinding(
          PointerScrollEvent(position: tester.getCenter(_scroll(controller)), scrollDelta: const Offset(0, 30)),
        );
        expect(tester.takeException().toString(), contains('有限、同号且不放大的剩余量'));
      }
    });
  });

  group('输入槽消费顺序', () {
    testWidgets('固定种子：合法范围内各 slot 接受量与正文预算守恒', (tester) async {
      const seed = 0xE152;
      final random = math.Random(seed);
      final key = GlobalKey<ElScrollViewState>();
      final log = <String>[];
      final inputs = <ElScrollInputDetails>[];
      var factors = [.5, .5, .5];
      late StateSetter update;
      await tester.pumpWidget(
        _frame(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElScrollView(
                key: key,
                scrollbar: const ElNoScrollBar(),
                smoothScroll: null,
                physics: const ClampingScrollPhysics(),
                inputOrder: const {
                  Axis.vertical: [#a, #b, #c],
                },
                children: [
                  for (var index = 0; index < 3; index++)
                    _InputSlotsParticipant(
                      slot: const [#a, #b, #c][index],
                      factor: factors[index],
                      log: log,
                      inputs: inputs,
                    ),
                  const ElView(style: ElStyle(height: 100000)),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      for (var sample = 0; sample < 80; sample++) {
        update(() => factors = List.generate(3, (_) => .15 + random.nextDouble() * .7));
        await tester.pump();
        final state = key.currentState!;
        state.controller.jumpTo(state.position.maxScrollExtent / 2);
        await tester.pump();
        final before = state.position.pixels;
        final requested = (40 + random.nextDouble() * 80) * (random.nextBool() ? 1 : -1);
        log.clear();
        inputs.clear();
        await _wheel(tester, delta: Offset(0, requested));
        final reason = 'seed=$seed sample=$sample requested=$requested factors=$factors';
        expect(log, hasLength(3), reason: reason);
        var accepted = 0.0;
        for (var index = 0; index < 3; index++) {
          accepted += double.parse(log[index].split(':').last) * (1 - factors[index]);
        }
        // 这里只使用范围内的 clamping 线性路径，阻尼接受预算与位移另行测试。
        expect(accepted + state.position.pixels - before, closeTo(requested, .00001), reason: reason);
        expect(inputs.every((input) => identical(input, inputs.first)), isTrue, reason: reason);
        expect(
          inputs.map((input) => input.requestedDelta),
          everyElement(closeTo(requested, .00000001)),
          reason: reason,
        );
      }
    });

    testWidgets('T01 同 State A/B/C 先 super 再消费，书写顺序即实际消费顺序', (tester) async {
      final key = GlobalKey<ElScrollViewState>();
      final log = <String>[];
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            key: key,
            scrollbar: const ElNoScrollBar(),
            smoothScroll: null,
            children: [
              _Compound(log),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      await _wheel(tester);
      expect(log, ['A:80.0', 'B:40.0', 'C:20.0']);
      expect(key.currentState!.position.pixels, 10);
    });

    testWidgets('T02 两个 State 按 inputOrder 消费，共享固定 requestedDelta 详情', (tester) async {
      final key = GlobalKey<ElScrollViewState>();
      final log = <String>[];
      final inputs = <ElScrollInputDetails>[];
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            key: key,
            scrollbar: const ElNoScrollBar(),
            smoothScroll: null,
            inputOrder: const {
              Axis.vertical: [#header, #filters],
            },
            children: [
              _InputSlotsParticipant(slot: #filters, factor: .5, log: log, inputs: inputs),
              _InputSlotsParticipant(slot: #header, factor: .5, log: log, inputs: inputs),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      await _wheel(tester);
      expect(log, ['Symbol("header"):80.0', 'Symbol("filters"):40.0']);
      expect(inputs, hasLength(2));
      expect(inputs[0], same(inputs[1]));
      expect(inputs[0].requestedDelta, 80);
      expect(inputs[0].source, ElScrollInputSource.pointerSignal);
      expect(inputs[0].sessionId, isNotNull);
      expect(inputs[0].rawEvent, isA<PointerScrollEvent>());
      expect(inputs[0].timeStamp, inputs[0].rawEvent!.timeStamp);
      expect(inputs[0].transactionId, greaterThan(0));
      expect(key.currentState!.position.pixels, 20);
    });

    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.stylus]) {
      testWidgets('真实 $kind 手势保留来源、采样时间与释放会话，下一手势换号', (tester) async {
        final inputs = <ElScrollInputDetails>[];
        final releases = <ElScrollReleaseDetails>[];
        await tester.pumpWidget(
          _frame(
            ElScrollView(
              scrollbar: const ElNoScrollBar(),
              physics: const ClampingScrollPhysics(),
              children: [
                _InputSlotsParticipant(
                  slot: #input,
                  factor: .5,
                  log: [],
                  inputs: inputs,
                  releases: releases,
                  observe: false,
                ),
                const ElView(style: ElStyle(height: 1000)),
              ],
            ),
          ),
        );
        await tester.pump();
        final gesture = await tester.startGesture(const Offset(150, 160), kind: kind);
        await gesture.moveBy(const Offset(0, -30), timeStamp: const Duration(milliseconds: 20));
        await gesture.moveBy(const Offset(0, -40), timeStamp: const Duration(milliseconds: 42));
        final first = inputs.last;
        expect(first.source, kind == PointerDeviceKind.touch ? ElScrollInputSource.touch : ElScrollInputSource.stylus);
        expect(first.rawEvent!.kind, kind);
        expect(first.timeStamp, const Duration(milliseconds: 42));
        expect(first.sessionId, isNotNull);
        expect(first.snapshot.hasMetrics, isTrue);
        expect(first.rawDelta, -40);
        expect(first.requestedDelta, 40);
        await gesture.moveBy(const Offset(0, -10), timeStamp: const Duration(milliseconds: 58));
        final second = inputs.last;
        expect(second.sessionId, first.sessionId);
        expect(second.snapshot.contentOffset, 20);
        expect(second.transactionId, greaterThan(first.transactionId));
        expect(second.sampleId, greaterThan(first.sampleId));
        expect(second.timeStamp, const Duration(milliseconds: 58));
        await gesture.up(timeStamp: const Duration(milliseconds: 500));
        expect(releases, hasLength(1));
        expect(releases.single.sessionId, first.sessionId);
        expect(releases.single.source, first.source);
        expect(releases.single.timeStamp, const Duration(milliseconds: 500));
        expect(releases.single.rawEvent, isA<PointerUpEvent>());
        final next = await tester.startGesture(const Offset(150, 160), kind: kind);
        await next.moveBy(const Offset(0, -30), timeStamp: const Duration(milliseconds: 520));
        await next.moveBy(const Offset(0, -40), timeStamp: const Duration(milliseconds: 542));
        expect(inputs.last.sessionId, isNot(first.sessionId));
        await next.cancel();
      });
    }

    for (final axis in Axis.values) {
      for (final reverse in [false, true]) {
        for (final direction in TextDirection.values) {
          testWidgets('本地输入在 $axis reverse=$reverse $direction 中统一为内容旅行方向', (tester) async {
            final key = GlobalKey<ElScrollViewState>();
            final log = <String>[];
            final inputs = <ElScrollInputDetails>[];
            await tester.pumpWidget(
              _frame(
                ElScrollView(
                  key: key,
                  axis: axis,
                  reverse: reverse,
                  scrollbar: const ElNoScrollBar(),
                  smoothScroll: null,
                  children: [
                    _InputSlotsParticipant(slot: #header, factor: .5, log: log, inputs: inputs),
                    ElView(
                      style: ElStyle(
                        width: axis == Axis.horizontal ? 1000 : null,
                        height: axis == Axis.vertical ? 1000 : 40,
                      ),
                    ),
                  ],
                ),
                direction: direction,
              ),
            );
            await tester.pump();
            final position = key.currentState!.position;
            key.currentState!.controller.jumpTo(position.maxScrollExtent / 2);
            await tester.pump();
            final before = position.pixels;
            await _wheel(tester, delta: axis == Axis.vertical ? const Offset(0, 80) : const Offset(80, 0));
            expect(inputs, hasLength(1));
            expect(inputs.single.requestedDelta, 80);
            final sign = axisDirectionIsReversed(position.axisDirection) ? -1 : 1;
            expect(position.pixels - before, 40 * sign);
          });
        }
      }
    }

    testWidgets('T02 post 按 inputOrder 反序分配同一份边界余量', (tester) async {
      final post = <String>[];
      final log = <String>[];
      final inputs = <ElScrollInputDetails>[];
      final postInputs = <ElScrollInputDetails>[];
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            scrollbar: const ElNoScrollBar(),
            physics: const ClampingScrollPhysics(),
            inputOrder: const {
              Axis.vertical: [#header, #filters],
            },
            children: [
              _InputSlotsParticipant(
                slot: #header,
                factor: .5,
                postFactor: .5,
                log: log,
                inputs: inputs,
                postLog: post,
                postInputs: postInputs,
              ),
              _InputSlotsParticipant(
                slot: #filters,
                factor: .5,
                postFactor: .5,
                log: log,
                inputs: inputs,
                postLog: post,
                postInputs: postInputs,
              ),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      final gesture = await tester.startGesture(const Offset(150, 80));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      post.clear();
      postInputs.clear();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.cancel();
      expect(post, ['Symbol("filters"):-10.0', 'Symbol("header"):-5.0']);
      expect(postInputs.first.requestedDelta, -40);
      expect(postInputs.first, same(inputs.last));
    });

    testWidgets('T34 回调中停用另一个 slot，在当前分派完成后统一生效', (tester) async {
      final key = GlobalKey<ElScrollViewState>();
      final filters = GlobalKey<_InputSlotsParticipantState>();
      final log = <String>[];
      final inputs = <ElScrollInputDetails>[];
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            key: key,
            scrollbar: const ElNoScrollBar(),
            smoothScroll: null,
            inputOrder: const {
              Axis.vertical: [#header, #filters],
            },
            children: [
              _InputSlotsParticipant(
                slot: #header,
                factor: .5,
                log: log,
                inputs: inputs,
                duringPre: () => filters.currentState!.disableInput(),
              ),
              _InputSlotsParticipant(key: filters, slot: #filters, factor: .5, log: log, inputs: inputs),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: const Offset(150, 100), scrollDelta: const Offset(0, 80)),
      );
      expect(log, ['Symbol("header"):80.0', 'Symbol("filters"):40.0']);
      expect(key.currentState!.position.pixels, 20);
      log.clear();
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: const Offset(150, 100), scrollDelta: const Offset(0, 80)),
      );
      expect(log, ['Symbol("header"):80.0']);
      expect(key.currentState!.position.pixels, 60);
    });

    testWidgets('T34 正文回调中停用 slot，不改变同一次输入的后置参与顺序', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final filters = GlobalKey<_InputSlotsParticipantState>();
      final log = <String>[];
      final inputs = <ElScrollInputDetails>[];
      final post = <String>[];
      var armed = false;
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            scrollbar: const ElNoScrollBar(),
            inputOrder: const {
              Axis.vertical: [#header, #filters],
            },
            children: [
              _InputSlotsParticipant(
                slot: #header,
                factor: 1,
                postFactor: .5,
                log: log,
                inputs: inputs,
                postLog: post,
                duringScroll: () {
                  if (armed) filters.currentState!.disableInput();
                },
              ),
              _InputSlotsParticipant(
                key: filters,
                slot: #filters,
                factor: 1,
                postFactor: .5,
                log: log,
                inputs: inputs,
                postLog: post,
              ),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      final gesture = await tester.startGesture(const Offset(150, 80));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      controller.jumpTo(10);
      armed = true;
      post.clear();
      await gesture.moveBy(const Offset(0, 40));
      expect(controller.offset, 0);
      expect(post, ['Symbol("filters"):-30.0', 'Symbol("header"):-15.0']);
      await tester.pump();
      post.clear();
      await gesture.moveBy(const Offset(0, 40));
      expect(post, ['Symbol("header"):-40.0']);
      await gesture.cancel();
    });

    for (final invalidFactor in [double.nan, double.infinity, -1.0, 2.0]) {
      testWidgets('T03 非法剩余量保留前序消费并隔离（factor=$invalidFactor）', (tester) async {
        final key = GlobalKey<ElScrollViewState>();
        final log = <String>[];
        final inputs = <ElScrollInputDetails>[];
        await tester.pumpWidget(
          _frame(
            ElScrollView(
              key: key,
              scrollbar: const ElNoScrollBar(),
              smoothScroll: null,
              inputOrder: const {
                Axis.vertical: [#first, #bad, #last],
              },
              children: [
                _InputSlotsParticipant(slot: #first, factor: .5, log: log, inputs: inputs),
                _InputSlotsParticipant(slot: #bad, factor: invalidFactor, log: log, inputs: inputs),
                _InputSlotsParticipant(slot: #last, factor: .5, log: log, inputs: inputs),
                const ElView(style: ElStyle(height: 1000)),
              ],
            ),
          ),
        );
        await tester.pump();
        await _wheel(tester);
        expect(tester.takeException(), isA<FlutterError>());
        expect(key.currentState!.position.pixels, 20);
        await _wheel(tester);
        expect(tester.takeException(), isNull, reason: '同一个错误参与者只诊断一次');
        expect(key.currentState!.position.pixels, 40);
      });
    }

    testWidgets('回调抛错停止本次内容推进，配置收尾后下一次输入可继续', (tester) async {
      final key = GlobalKey<ElScrollViewState>();
      final filters = GlobalKey<_InputSlotsParticipantState>();
      final log = <String>[];
      final inputs = <ElScrollInputDetails>[];
      var fail = true;
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            key: key,
            scrollbar: const ElNoScrollBar(),
            smoothScroll: null,
            inputOrder: const {
              Axis.vertical: [#header, #filters],
            },
            children: [
              _InputSlotsParticipant(
                slot: #header,
                factor: .5,
                log: log,
                inputs: inputs,
                duringPre: () {
                  if (!fail) return;
                  fail = false;
                  filters.currentState!.disableInput();
                  throw StateError('input callback failure');
                },
              ),
              _InputSlotsParticipant(key: filters, slot: #filters, factor: .5, log: log, inputs: inputs),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      await _wheel(tester);
      expect(tester.takeException().toString(), contains('input callback failure'));
      expect(key.currentState!.position.pixels, 0);
      log.clear();
      await _wheel(tester);
      expect(log, ['Symbol("header"):80.0']);
      expect(key.currentState!.position.pixels, 40);
    });

    testWidgets('原地修改 inputOrder 列表在下一配置提交后生效', (tester) async {
      final order = <Object>[#header, #filters];
      final declaration = {Axis.vertical: order};
      final log = <String>[];
      final inputs = <ElScrollInputDetails>[];
      late StateSetter update;
      await tester.pumpWidget(
        _frame(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElScrollView(
                scrollbar: const ElNoScrollBar(),
                smoothScroll: null,
                inputOrder: declaration,
                children: [
                  _InputSlotsParticipant(slot: #header, factor: .5, log: log, inputs: inputs),
                  _InputSlotsParticipant(slot: #filters, factor: .5, log: log, inputs: inputs),
                  const ElView(style: ElStyle(height: 1000)),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      await _wheel(tester);
      expect(log, ['Symbol("header"):80.0', 'Symbol("filters"):40.0']);
      log.clear();
      update(() {
        order.setAll(0, [#filters, #header]);
      });
      await tester.pump();
      await _wheel(tester);
      expect(log, ['Symbol("filters"):80.0', 'Symbol("header"):40.0']);
    });

    for (final config in <({Map<Axis, List<Object>> order, List<Object> slots, String error})>[
      (order: const {}, slots: const [#a, #b], error: 'inputOrder'),
      (
        order: const {
          Axis.vertical: [#a, #a],
        },
        slots: const [#a],
        error: '重复 slot',
      ),
      (
        order: const {
          Axis.vertical: [#a],
        },
        slots: const [#a, #b],
        error: '遗漏',
      ),
      (
        order: const {
          Axis.vertical: [#a],
        },
        slots: const [#a, #a],
        error: '重复 input slot',
      ),
    ]) {
      testWidgets('T02 无效输入配置明确失败：${config.error}', (tester) async {
        final log = <String>[];
        final inputs = <ElScrollInputDetails>[];
        await tester.pumpWidget(
          _frame(
            ElScrollView(
              inputOrder: config.order,
              scrollbar: const ElNoScrollBar(),
              children: [
                for (final slot in config.slots)
                  _InputSlotsParticipant(slot: slot, factor: .5, log: log, inputs: inputs),
                const ElView(style: ElStyle(height: 1000)),
              ],
            ),
          ),
        );
        final error = tester.takeException();
        expect(error, isA<FlutterError>());
        expect(error.toString(), contains(config.error));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('滚轮嵌套交接', () {
    setUp(ScrollPointerChain.debugReset);

    tearDown(ScrollPointerChain.debugReset);

    testWidgets('纵向滚轮转横滚后的 500ms 锁不拦截新的触控板纵向手势', (tester) async {
      final page = _WheelNestedHandoffNestedPage('default', true, horizontal: true);
      await page.mount(tester);
      final point = page.innerPoint(tester);
      await page.wheel(tester, point);
      final stamp = tester.binding.currentSystemFrameTimeStamp;
      await tester.sendEventToBinding(PointerPanZoomStartEvent(pointer: 78, position: point, timeStamp: stamp));
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          pointer: 78,
          position: point,
          pan: const Offset(0, -40),
          panDelta: const Offset(0, -40),
          timeStamp: stamp + const Duration(milliseconds: 20),
        ),
      );
      await tester.pump();
      expect(page.outer.pixels, closeTo(40, .01));
      expect(page.inner.pixels, closeTo(40, .01));
      await tester.sendEventToBinding(
        PointerPanZoomEndEvent(pointer: 78, position: point, timeStamp: stamp + const Duration(seconds: 1)),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('内层滚轮在途不把未移动的祖先正文标记为正在滚动', (tester) async {
      final page = _WheelNestedHandoffNestedPage('default', true, bars: true);
      await page.mount(tester);
      await page.wheel(tester, page.innerPoint(tester));
      expect(page.inner.isScrollingNotifier.value, isTrue);
      expect(page.outer.pixels, 0);
      expect(page.outer.isScrollingNotifier.value, isFalse);
      await tester.pumpAndSettle();
    });

    for (final smooth in [false, true]) {
      testWidgets('smooth=$smooth 鼠标不动，横向区域进入指针下方也不偷走纵向滚轮', (tester) async {
        final page = _WheelNestedHandoffNestedPage('default', smooth, horizontal: true);
        await page.mount(tester);
        const point = Offset(200, 80);
        await page.wheel(tester, point);
        expect(tester.getRect(find.byKey(page.innerKey)).contains(point), isTrue);
        await page.wheel(tester, point);
        expect(page.outer.pixels, closeTo(80, .01));
        expect(page.inner.pixels, 0);
        await tester.pump(const Duration(milliseconds: 460));
        await page.wheel(tester, point);
        expect(page.outer.pixels, closeTo(80, .01));
        expect(page.inner.pixels, closeTo(40, .01));
        await tester.pumpAndSettle();
      });

      testWidgets('smooth=$smooth 鼠标移到外层滚动条后立即交接滚轮', (tester) async {
        final page = _WheelNestedHandoffNestedPage('default', smooth, bars: true);
        await page.mount(tester);
        await page.wheel(tester, page.innerPoint(tester));
        const outerBarPoint = Offset(393, 120);
        await page.wheel(tester, outerBarPoint);
        expect(page.inner.pixels, closeTo(40, .01));
        expect(page.outer.pixels, closeTo(40, .01));
        await page.wheel(tester, outerBarPoint);
        expect(page.inner.pixels, closeTo(40, .01));
        expect(page.outer.pixels, closeTo(80, .01));
        await tester.pumpAndSettle();
      });
    }

    for (final controllers in ['default', 'flutter']) {
      testWidgets('$controllers 内层长动画期间移到外层立即交接并停止旧动画', (tester) async {
        final page = _WheelNestedHandoffNestedPage(controllers, true, duration: Duration(seconds: 1));
        await page.mount(tester);
        await page.wheel(tester, page.innerPoint(tester), delta: 80);
        final innerAtHandoff = page.inner.pixels;
        expect(innerAtHandoff, inExclusiveRange(0, 80));
        await page.wheel(tester, Offset(200, 20));
        expect(page.outer.pixels, greaterThan(0));
        expect(page.inner.pixels, closeTo(innerAtHandoff, .01));
        await tester.pumpAndSettle();
        expect(page.outer.pixels, closeTo(40, .01));
        expect(page.inner.pixels, closeTo(innerAtHandoff, .01));
      });

      testWidgets('$controllers 停顿从最后滚轮计时，不等长动画结束；新接收者接管后旧动画停止', (tester) async {
        final page = _WheelNestedHandoffNestedPage(controllers, true, duration: const Duration(seconds: 1));
        await page.mount(tester);
        await page.wheel(tester, const Offset(200, 20), delta: 80);
        await tester.pump(const Duration(milliseconds: 460));
        final outerAtHandoff = page.outer.pixels;
        expect(outerAtHandoff, inExclusiveRange(0, 80));
        await page.wheel(tester, page.innerPoint(tester));
        expect(page.inner.pixels, greaterThan(0));
        expect(page.outer.pixels, closeTo(outerAtHandoff, .01));
        await tester.pumpAndSettle();
        expect(page.outer.pixels, closeTo(outerAtHandoff, .01));
        expect(page.inner.pixels, closeTo(40, .01));
      });
    }

    for (final controllers in ['default', 'el', 'flutter']) {
      for (final smooth in [false, true]) {
        for (final horizontal in [false, true]) {
          testWidgets('$controllers smooth=$smooth 外层纵滚经过${horizontal ? "横向" : "纵向"}内层，499ms 不换目标，500ms 才接力', (
            tester,
          ) async {
            final page = _WheelNestedHandoffNestedPage(controllers, smooth, horizontal: horizontal);
            await page.mount(tester);
            await page.wheel(tester, const Offset(200, 20));
            expect(page.outer.pixels, closeTo(40, .01));
            expect(page.inner.pixels, 0);
            await tester.pump(const Duration(milliseconds: 459));
            await page.wheel(tester, page.innerPoint(tester));
            expect(page.outer.pixels, closeTo(80, .01), reason: '未停满 500ms，仍应由外层纵向接收');
            expect(page.inner.pixels, 0, reason: '鼠标经过内层不得改变接收者或把 dy 改成横滚');
            await tester.pump(const Duration(milliseconds: 460));
            await page.wheel(tester, page.innerPoint(tester));
            expect(page.outer.pixels, closeTo(80, .01));
            expect(page.inner.pixels, closeTo(40, .01), reason: '停满 500ms 后按鼠标所在内层重新命中');
            await tester.pumpAndSettle();
          });
        }

        testWidgets('$controllers smooth=$smooth 内层到边界不泄漏同格余量，连续滚轮重置 500ms 停顿', (tester) async {
          final page = _WheelNestedHandoffNestedPage(controllers, smooth);
          await page.mount(tester);
          final end = page.inner.maxScrollExtent;
          page.inner.jumpTo(end - 20);
          await tester.pump();
          final point = page.innerPoint(tester);
          await page.wheel(tester, point);
          expect(page.inner.pixels, closeTo(end, .01));
          expect(page.outer.pixels, 0, reason: '同一格剩余 20 不能越界写外层');
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 459));
            await page.wheel(tester, point);
            expect(page.outer.pixels, 0, reason: '边界空消费也必须从最后一格重新计时');
          }
          await tester.pump(const Duration(milliseconds: 460));
          await page.wheel(tester, point);
          expect(page.inner.pixels, closeTo(end, .01));
          expect(page.outer.pixels, closeTo(40, .01), reason: '停满 500ms 后内层已无范围，由同轴外层接收');
          await tester.pumpAndSettle();
        });

        for (final horizontal in [false, true]) {
          for (final atBoundary in [false, true]) {
            testWidgets('$controllers smooth=$smooth horizontal=$horizontal boundary=$atBoundary 移出内层立即交接滚轮', (
              tester,
            ) async {
              final page = _WheelNestedHandoffNestedPage(controllers, smooth, horizontal: horizontal);
              await page.mount(tester);
              if (atBoundary) {
                page.inner.jumpTo(page.inner.maxScrollExtent - 20);
                await tester.pump();
              }
              // 只跨边界 2px，也必须释放内层，不能被 10px 移动容差挡住。
              final inside = tester.getTopLeft(find.byKey(page.innerKey)) + Offset(200, 1);
              await page.wheel(tester, inside);
              final innerAtHandoff = page.inner.pixels;
              expect(innerAtHandoff, closeTo(atBoundary ? page.inner.maxScrollExtent : 40, .01));
              await page.wheel(tester, inside - Offset(0, 2));
              expect(page.outer.pixels, closeTo(40, .01), reason: '移出内层后的第一格立即交给外层');
              expect(page.inner.pixels, closeTo(innerAtHandoff, .01));
              await page.wheel(tester, Offset(200, 20));
              expect(page.outer.pixels, closeTo(80, .01));
              expect(page.inner.pixels, closeTo(innerAtHandoff, .01));
              await tester.pumpAndSettle();
            });
          }
        }
      }
    }
  });
}
