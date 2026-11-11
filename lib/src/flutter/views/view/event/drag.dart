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
    if (details.propagationStopped) route._drags?.stopPropagation(this, details.phase);
  }

  ElEventDetails _updateDrag(PointerEvent input, Offset delta, ElEventDetails? previous) {
    final drag = _drag!;
    drag.position = EventDispatcher._pointerPosition(input);
    drag.offset += drag.project(delta);
    final details = _dragDetails(.dragUpdate, input, delta: delta, remaining: previous?.remainingDelta ?? delta);
    _invoke(details);
    if (details.propagationStopped) drag.route._drags?.stopPropagation(this, details.phase);
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

/// 一条路线上的拖拽：按下协商、起拖判定、轴向锁定与驱动指针交接。
///
/// 路线上有宿主声明拖拽时才创建。进行中的拖拽只经 [_DragEvents._startDrag] 与 [adopt] 绑定路线，
/// 两处都在本对象上发生，所以驱动拖拽的路线必有本对象。
final class _RouteDrags {
  _RouteDrags(this.route) {
    assert(() {
      BenchmarkProbe.eventRouteDragsInstantiateCount++;
      return true;
    }());
  }

  final _Route route;

  /// 尚未起拖的候选，由内向外。
  var candidates = <EventDispatcher>[];

  /// 首个起拖者锁定的轴向。
  Axis? lockedAxis;

  // 仅设备阈值覆盖或回调重接时分配。
  Map<EventDispatcher, double>? startDistances;
  Map<EventDispatcher, (PointerEvent, Axis?)>? deferredStarts;
  Map<EventDispatcher, PointerEvent>? deferMoves;

  /// 宿主的进行中拖拽是否由本路线的指针驱动。
  bool drives(EventDispatcher host) => host._drag?.route == route;

  Iterable<EventDispatcher> get driving => route.hosts.where(drives);

  /// 宿主是本路线的候选或正由本路线驱动。
  bool engages(EventDispatcher host) => candidates.contains(host) || drives(host);

  /// 仍有候选或进行中的拖拽。
  bool get engaged => candidates.isNotEmpty || driving.isNotEmpty;

  /// 是否需要为释放速度采样。
  bool get tracking => candidates.isNotEmpty || (deferredStarts?.isNotEmpty ?? false) || driving.isNotEmpty;

  /// 派发拖拽按下并确定候选；已在拖拽的宿主改由本路线的指针驱动。
  void begin(List<EventDispatcher> hosts) {
    final input = route.down;
    candidates = hosts;
    final downDetails = <EventDispatcher, ElEventDetails>{};
    final stop = _Route._bubble(candidates, .dragDown, (host) => downDetails[host] = host._pointer(.dragDown, input));
    for (final MapEntry(key: host, value: details) in downDetails.entries) {
      if (details.dragStartDistance case final distance?) (startDistances ??= {})[host] = distance;
    }
    if (stop >= 0) candidates = candidates.sublist(0, stop + 1);
    candidates.removeWhere((host) => !host._shape.drag);
    // 拖拽中落下新手指：与 Flutter 一致，由最新的手指继续驱动。
    for (final host in candidates.where((host) => host._drag != null && !host._shape.scale).toList()) {
      adopt(host);
      route.claim();
    }
  }

  /// 接手宿主进行中的拖拽，坐标基线移到本路线的触点。
  void adopt(EventDispatcher host) {
    candidates.remove(host);
    host._drag!
      ..route = route
      ..position = route.position;
  }

  /// 回调重接期间暂缓的起拖在下一次移动时补发。
  void startDeferred(EventDispatcher host, PointerEvent event) {
    final pending = deferredStarts?.remove(host);
    if (pending != null) host._startDrag(route, pending.$2, event);
  }

  /// 越过起拖距离的候选开始拖拽。轴向候选等主方向落在自己的轴上，首个开始者锁定轴向，
  /// 同轴其余候选随即开始；同时声明两轴时横向需越过更长的 pan slop，避免误触横滚。
  void tryStart(EventDispatcher host, PointerEvent event, double distance, double slop) {
    final moved = route.moved;
    final dominant = moved.dx.abs() >= moved.dy.abs() ? Axis.horizontal : Axis.vertical;
    candidates.removeWhere((item) => !item._live || !route._allowsRaw(item) || item._scaling || item._drag != null);
    if (!candidates.contains(host)) return;
    Axis? axisFor(EventShape shape) => shape.pan ? null : lockedAxis ?? dominant;
    bool ready(EventDispatcher host) {
      final shape = host._shape;
      final axis = axisFor(shape);
      final both = shape.acceptsDrag(.horizontal) && shape.acceptsDrag(.vertical);
      final pan = axis == null || both && axis == .horizontal;
      final start =
          host._e.dragStartDistance ?? startDistances?[host] ?? (pan ? computePanSlop(route.down.kind, null) : slop);
      return (axis == null || shape.acceptsDrag(axis)) && (distance > start || axis != null && lockedAxis != null);
    }

    final proposal = candidates.indexWhere(ready);
    if (proposal < 0) return;
    // 外层先达到阈值时，先让兼容的内层响应，内层停止传播后外层不能抢先起拖。
    final index = candidates.indexOf(host);
    final axis = axisFor(host._shape);
    if (axis != null && !host._shape.acceptsDrag(axis)) return;
    if (index > proposal && !ready(host)) return;
    candidates.remove(host);
    lockedAxis ??= axis;
    route._taps?.longPress?.cancel();
    route.claim();
    if (!route._allowsRaw(host) || !host._live || !route.hosts.contains(host)) return;
    if (identical(deferMoves?.remove(host), event.original ?? event)) {
      (deferredStarts ??= {})[host] = (event, axis);
      route._taps?.eligible.remove(host);
      if (host._pressed == route.pointer) host._release();
      return;
    }
    host._startDrag(route, axis, event);
  }

  /// 驱动指针离开时沿用已有拖拽，将坐标基线移到最近仍接受输入的触点。
  void handoff() {
    for (final host in driving.toList()) {
      final next = EventDispatcher._routes.values
          .where(
            (other) =>
                other != route &&
                !other._ended &&
                !other._closed &&
                !other._rejected &&
                other._accepted &&
                other.hosts.contains(host) &&
                host._canTransform(other.down),
          )
          .lastOrNull;
      if (next != null && !host._shape.scale) next._ensureDrags().adopt(host);
    }
  }

  /// 松手时结束仍由本路线驱动的拖拽。
  void finish(PointerEvent event, Offset velocity) {
    for (final host in driving.toList()) {
      host._endDrag(event, velocity);
    }
  }

  /// 未越过起拖距离就快速抬手时，移动超过点击取消距离一半的候选按速度补发一次完整拖拽。
  bool fling(PointerEvent event, Offset velocity) {
    final offset = route.moved;
    if (velocity == Offset.zero || candidates.isEmpty) return false;
    final axis = offset.dx.abs() >= offset.dy.abs() ? Axis.horizontal : Axis.vertical;
    final flung = candidates
        .where((host) => host._live && host._drag == null && host._shape.acceptsDrag(axis))
        .where((host) => offset.distance > (host._e.tapCancelDistance ?? 10) / 2)
        .toList();
    if (flung.isEmpty) return false;
    route._cancelTaps(.otherGestureAccepted);
    for (final host in flung) {
      if (!candidates.remove(host)) continue;
      host._startDrag(route, host._shape.pan ? null : axis, event);
      final drag = host._drag;
      if (drag == null) continue;
      drag.position = EventDispatcher._pointerPosition(route.down);
      host._updateDrag(event, offset, null);
      host._endDrag(event, velocity);
    }
    return true;
  }

  /// 起拖回调停止了传播：外层候选退出，外层进行中的拖拽取消。
  void stopPropagation(EventDispatcher owner, ElEventPhase phase) {
    if (phase != .dragStart) return;
    final outside = route.hosts.skip(route.hosts.indexOf(owner) + 1).toList();
    candidates.removeWhere(outside.contains);
    for (final host in outside) {
      deferredStarts?.remove(host);
      cancelDriven(host);
    }
  }

  /// 取消本路线的全部候选与进行中的拖拽。
  void cancel() {
    deferredStarts?.clear();
    deferMoves?.clear();
    candidates.clear();
    for (final host in route.hosts.toList()) {
      cancelDriven(host);
    }
  }

  /// 宿主退出起拖候选，进行中的拖拽不受影响。
  void withdraw(EventDispatcher host) {
    candidates.remove(host);
    deferredStarts?.remove(host);
    deferMoves?.remove(host);
  }

  /// 取消宿主由本路线驱动的拖拽。
  void cancelDriven(EventDispatcher host) {
    if (drives(host)) host._endDrag(route.last, null);
  }

  /// 宿主不再参与本路线的拖拽；[notify] 为 false 时静默丢弃进行中的拖拽。
  void drop(EventDispatcher host, {required bool notify}) {
    withdraw(host);
    startDistances?.remove(host);
    if (!drives(host)) return;
    if (notify) {
      host._endDrag(route.last, null);
    } else {
      host._drag = null;
    }
  }

  /// 宿主换了回调结构：按新声明加入或退出候选。
  void reseed(EventDispatcher host, bool wanted) {
    deferredStarts?.remove(host);
    deferMoves?.remove(host);
    candidates = route._resync(candidates, host, wanted);
    if (!wanted) return;
    // 在移动回调里换结构时，这次移动仍属于旧声明，起拖顺延到下一次移动。
    if (host._activeCallback case final callback? when callback.phase == ElEventPhase.pointerMove) {
      final move = callback.originalEvent! as PointerEvent;
      (deferMoves ??= {})[host] = move.original ?? move;
    }
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
