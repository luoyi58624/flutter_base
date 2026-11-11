part of 'dispatcher.dart';

extension _DragEvents on EventDispatcher {
  void _startDrag(_Route route, Axis? axis, PointerEvent input) {
    final moved = route.position - EventDispatcher._pointerPosition(route.down);
    final horizontal = moved.dx.abs() >= moved.dy.abs();
    final direction = horizontal
        ? (moved.dx < 0 ? AxisDirection.left : AxisDirection.right)
        : (moved.dy < 0 ? AxisDirection.up : AxisDirection.down);
    _drag = _Drag(route, axis, direction, route.position);
    final details = _dragDetails(.dragStart, input);
    _invoke(details);
    if (details.propagationStopped) route.exclusive(this);
  }

  ElEventDetails _updateDrag(PointerEvent input, Offset delta, ElEventDetails? previous) {
    final drag = _drag!;
    drag.position = EventDispatcher._pointerPosition(input);
    drag.offset += drag.project(delta);
    final details = _dragDetails(.dragUpdate, input, delta: delta, remaining: previous?.remainingDelta ?? delta);
    _invoke(details);
    if (details.propagationStopped) drag.route.exclusive(this);
    return details;
  }

  /// 结束拖拽；velocity 为 null 表示取消。
  void _endDrag(PointerEvent input, Offset? velocity) {
    final drag = _drag;
    if (drag == null) return;
    _drag = null;
    // 松手点与最后一次移动不同时，这段位移计入 dragEnd 的累计偏移。
    if (velocity != null && input is PointerUpEvent) {
      drag.offset += drag.project(input.position - drag.position);
      drag.position = input.position;
    }
    final phase = velocity == null ? ElEventPhase.dragCancel : ElEventPhase.dragEnd;
    final details = _dragDetails(phase, input, drag: drag, velocity: velocity ?? Offset.zero);
    _invoke(details, drag: drag);
  }

  ElEventDetails _dragDetails(
    ElEventPhase phase,
    PointerEvent input, {
    _Drag? drag,
    Offset delta = Offset.zero,
    Offset? remaining,
    Offset velocity = Offset.zero,
  }) {
    drag ??= _drag!;
    final position = drag.position;
    final own = drag.project(delta);
    final rest = drag.project(remaining ?? delta);
    final v = drag.project(velocity);
    return ElEventDetails(
      phase: phase,
      originalEvent: input,
      globalPosition: position,
      localPosition: _local(position),
      delta: own,
      localDelta: _localDelta(position, own),
      remainingDelta: rest,
      remainingLocalDelta: _localDelta(position, rest),
      dragOffset: drag.offset,
      dragAxis: drag.axis,
      dragDirection: drag.direction,
      velocity: Velocity(pixelsPerSecond: v),
      primaryVelocity: drag.axis == null ? null : (drag.axis == Axis.horizontal ? v.dx : v.dy),
      buttons: input.buttons,
      pointerCount: activePointerCount,
    )..resolveLocalDelta((value) => _localDelta(position, value));
  }
}

/// 一次拖拽的状态，axis 为 null 表示自由拖拽。
final class _Drag {
  _Drag(this.route, this.axis, this.direction, this.position);
  _Route route;
  final Axis? axis;
  final AxisDirection direction;
  Offset position;
  Offset offset = Offset.zero;

  Offset project(Offset value) => switch (axis) {
    null => value,
    Axis.horizontal => Offset(value.dx, 0),
    Axis.vertical => Offset(0, value.dy),
  };
}
