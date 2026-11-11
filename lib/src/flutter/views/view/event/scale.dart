part of 'dispatcher.dart';

extension _ScaleEvents on EventDispatcher {
  _ScaleState _ensureScale() => _scaleState ??= _ScaleState();

  void _pruneScale() {
    final state = _scaleState;
    if (state != null && !state.active && state.points.isEmpty) _scaleState = null;
  }

  /// 触点的焦点、平均半径与前两指连线角度。
  (Offset, double, double) _touchGeometry() {
    final state = _scaleState!;
    final points = state.points.values.toList();
    final focal = points.fold(Offset.zero, (sum, point) => sum + point) / points.length.toDouble();
    final span = points.fold(0.0, (sum, point) => sum + (point - focal).distance) / points.length;
    return (focal, span, points.length < 2 ? 0 : (points[1] - points[0]).direction);
  }

  /// 触点增减时重定基线，缩放与旋转从当前累计值续算。
  void _rebase() {
    final state = _scaleState!;
    final (focal, span, angle) = _touchGeometry();
    state.focal = state.focal0 = focal;
    state.span0 = span;
    state.angle0 = angle;
    state.scale0 = state.scale;
    state.rotation0 = state.rotation;
  }

  /// 开始缩放：认领参与的指针并取消其上的点击；双指捏合或停止传播时独占这些指针。
  void _startScale(PointerEvent input) {
    final state = _scaleState;
    if (state == null) return;
    final declaration = _shape;
    if (!_canStartOwnedScale() || !_commitOwnedScale()) return;
    if (!_canStartScale(declaration, state)) return;
    _endDrag(input, null);
    if (!_canStartScale(declaration, state)) return;
    _release();
    if (!_canStartScale(declaration, state)) return;
    final routes = EventDispatcher._routes.values.where((route) => route._inScale(this)).toList();
    for (final route in routes) {
      if (!route._inScale(this)) continue;
      route.claim();
      if (!_canStartScale(declaration, state)) return;
      if (route._inScale(this)) route._cancelTaps(.selfGestureAccepted, owner: this);
      if (!_canStartScale(declaration, state)) return;
    }
    state.active = true;
    state.scale = 1;
    state.rotation = 0;
    state.logScale = null;
    state.scaleTime = input.timeStamp;
    _rebase();
    final details = _scaleDetails(.scaleStart, input);
    _invoke(details);
    if (!_live || !identical(_scaleState, state) || !state.active || state.points.isEmpty) return;
    if (details.propagationStopped || state.points.length > 1) {
      for (final route in routes) {
        route.exclusive(this);
      }
    }
  }

  bool _canStartScale(EventShape declaration, _ScaleState state) {
    if (!identical(_scaleState, state)) return false;
    if (_live && declaration == _shape && state.points.isNotEmpty) return true;
    for (final route in _myRoutes) {
      route._scales?.members.remove(this);
    }
    state.points.clear();
    _pruneScale();
    return false;
  }

  /// 触点移动：未开始时跨度或焦点越过阈值才起步；silent 时只更新状态。返回是否停止传播。
  bool _moveScale(PointerEvent input, bool silent) {
    final state = _scaleState;
    if (state == null || state.points.isEmpty) return false;
    final (focal, span, angle) = _touchGeometry();
    if (!state.active) {
      final kind = input.kind;
      final moved = (focal - state.focal0).distance;
      // 纯旋转不会改变焦点或跨度，以触点沿圆周的位移判断起手。
      final turned = ((angle - state.angle0 + math.pi) % (2 * math.pi) - math.pi).abs() * span;
      if (input is PointerPanZoomUpdateEvent ||
          (state.points.length == 1
              ? _drag == null && moved > computePanSlop(kind, null)
              : (span - state.span0).abs() > computeScaleSlop(kind) ||
                    turned > computeScaleSlop(kind) ||
                    moved > computePanSlop(kind, null))) {
        _startScale(input);
      }
      return false;
    }
    final (last, scale, rotation) = (state.focal, state.scale, state.rotation);
    state.focal = focal;
    if (input is PointerPanZoomUpdateEvent) {
      state.scale = input.scale;
      state.rotation = input.rotation;
    } else if (state.points.length > 1) {
      state.scale = state.scale0 * (state.span0 > 0 ? span / state.span0 : 1);
      // 取最短角差，跨越 ±π 时保持连续。
      state.rotation = state.rotation0 + (angle - state.angle0 + math.pi) % (2 * math.pi) - math.pi;
    }
    final elapsed = (input.timeStamp - state.scaleTime).inMicroseconds / Duration.microsecondsPerSecond;
    state.scaleTime = input.timeStamp;
    state.logScale = state.points.length > 1 && span > 0 && elapsed > 0
        ? (input.timeStamp, math.log(state.scale / scale) / elapsed, focal)
        : null;
    if (silent) return true;
    final details = _scaleDetails(.scaleUpdate, input, delta: state.focal - last);
    _invoke(details);
    if (identical(_scaleState, state) && state.active && state.rotation != rotation && !details.propagationStopped) {
      _invoke(_scaleDetails(.rotationUpdate, input, delta: state.focal - last));
    }
    return details.propagationStopped;
  }

  /// 结束缩放；velocity 为 null 表示取消。最近 80ms 内的双指段提供对数缩放速度与其焦点。
  void _endScale(PointerEvent input, Offset? velocity) {
    final state = _scaleState;
    if (state == null) return;
    if (!state.active) {
      _pruneScale();
      return;
    }
    state.active = false;
    final log = state.logScale;
    state.logScale = null;
    final fresh = velocity != null && log != null && input.timeStamp - log.$1 <= const Duration(milliseconds: 80);
    if (fresh) state.focal = log.$3;
    final phase = velocity == null ? ElEventPhase.scaleCancel : ElEventPhase.scaleEnd;
    _invoke(_scaleDetails(phase, input, velocity: velocity ?? Offset.zero, logScale: fresh ? log.$2 : 0));
    _pruneScale();
  }

  ElEventDetails _scaleDetails(
    ElEventPhase phase,
    PointerEvent input, {
    Offset delta = Offset.zero,
    Offset velocity = Offset.zero,
    double logScale = 0,
  }) {
    final state = _scaleState!;
    return ElEventDetails(
      phase: phase,
      originalEvent: input,
      globalPosition: state.focal,
      localPosition: _local(state.focal),
      delta: delta,
      localDelta: _localDelta(state.focal, delta),
      pointerCount: state.points.length,
      scale: state.scale,
      rotation: state.rotation,
      buttons: input.buttons,
      velocity: Velocity(pixelsPerSecond: velocity),
      logScaleVelocity: logScale,
    );
  }
}

/// 一条路线上参与缩放的宿主：登记与撤回本指针的触点，几何与阶段由宿主的缩放状态累计。
///
/// 路线上有宿主声明缩放或旋转时才创建。
final class _RouteScales {
  _RouteScales(this.route) {
    assert(() {
      BenchmarkProbe.eventRouteScalesInstantiateCount++;
      return true;
    }());
  }

  final _Route route;

  /// 把本指针计入触点的宿主，由内向外。
  var members = <EventDispatcher>[];

  /// 仍有宿主持有本指针的触点。
  bool get engaged => members.isNotEmpty;

  /// 登记按下的触点；凑齐双指的宿主预留这些指针，拖拽中落下第二指时直接转入缩放。
  void begin(List<EventDispatcher> hosts) {
    members = hosts;
    for (final host in hosts.toList()) {
      if (!members.contains(host)) continue;
      host._ensureScale().points[route.pointer] = route.position;
      host._rebase();
      if (host._drag != null && (host._scaleState?.points.length ?? 0) > 1) host._startScale(route.down);
      if (host._scaling) route.claim();
      final points = host._scaleState?.points;
      if (points != null && points.length > 1) {
        // 双指先保留仍有效的触点，避免慢捏合被外层滚动抢走；越过缩放阈值才发 Start、取消点击。
        final routes = points.keys.map((pointer) => EventDispatcher._routes[pointer]).toList();
        if (routes.any(
          (other) => other == null || other._rejected || other._closed || other._ended || !other._inScale(host),
        )) {
          continue;
        }
        for (final other in routes) {
          if (!host._live || !other!._inScale(host)) break;
          other.claim();
        }
      }
    }
  }

  /// 认领失权后仍获准升级缩放的宿主补登本指针的触点。
  void admit(EventDispatcher host) {
    if (members.contains(host)) return;
    members.add(host);
    host._ensureScale().points[route.pointer] = route.position;
    host._rebase();
  }

  /// 触点移动；[silent] 表示内层已停止传播，返回传播是否已停止。
  bool move(EventDispatcher host, PointerEvent event, bool silent) {
    final points = host._scaleState?.points;
    if (points == null) return silent;
    points[route.pointer] = route.position;
    return host._moveScale(event, silent) || silent;
  }

  /// 松手：撤回本指针的触点，最后一个触点离开时结束缩放。
  void end(PointerEvent event) {
    for (final host in members.toList()) {
      final points = host._scaleState?.points;
      if (points?.remove(route.pointer) == null) continue;
      points!.isEmpty ? host._endScale(event, route._velocity()) : host._rebase();
      host._pruneScale();
    }
    members = [];
  }

  /// 取消本路线的全部缩放参与。
  void cancel() {
    for (final host in members.toList()) {
      if (host._scaleState?.points.remove(route.pointer) != null) host._endScale(route.last, null);
      host._pruneScale();
    }
    members = [];
  }

  /// 宿主撤回本指针的触点并取消缩放；[notify] 为 false 时静默结束。
  void release(EventDispatcher host, {bool notify = true}) {
    if (!members.remove(host) || host._scaleState?.points.remove(route.pointer) == null) return;
    if (notify) {
      host._endScale(route.last, null);
    } else {
      host._scaleState?.active = false;
    }
    host._pruneScale();
  }
}

/// 仅接收缩放或旋转指针的宿主持有，最后一个触点退出后释放。
final class _ScaleState {
  _ScaleState() {
    assert(() {
      BenchmarkProbe.eventScaleStateInstantiateCount++;
      return true;
    }());
  }
  final points = <int, Offset>{};
  bool active = false;
  double span0 = 0, angle0 = 0, scale0 = 1, rotation0 = 0, scale = 1, rotation = 0;
  Offset focal = Offset.zero, focal0 = Offset.zero;
  Duration scaleTime = Duration.zero;
  (Duration, double, Offset)? logScale;
}
