part of 'dispatcher.dart';

/// 一个指针从按下到抬起的路线：命中宿主由内向外排列，统一处理派生手势并作为竞技场成员。
final class _Route extends GestureArenaMember {
  _Route(this.down) : last = down, _lastPosition = EventDispatcher._pointerPosition(down);

  final PointerEvent down;
  PointerEvent last;
  Offset _lastPosition;
  List<(Duration, Offset)>? _velocitySamples;
  final hosts = <EventDispatcher>[];
  // pressed 收到 tapDown、松手时收到 tapUp；taps 仍有资格触发 tap；_outside 暂时移出点击边界。
  var pressed = <EventDispatcher>[];
  var taps = <EventDispatcher>[];
  var drags = <EventDispatcher>[];
  _RouteDragConfiguration? _dragConfiguration;
  var scales = <EventDispatcher>[];
  Set<EventDispatcher>? _outside;
  Set<EventDispatcher>? _longPressTargets;
  GestureArenaEntry? _entry;
  bool _accepted = false, _rejected = false, _closed = false, _begun = false;
  PointerUpEvent? _pendingUp;
  Axis? _axis;
  Timer? _longPress;

  int get pointer => down.pointer;
  Offset get position => EventDispatcher._pointerPosition(last);
  Offset get moved => position - EventDispatcher._pointerPosition(down);
  bool get _primary => down is PointerDownEvent && down.buttons == kPrimaryButton;
  bool get _ended =>
      last is PointerUpEvent ||
      last is PointerCancelEvent ||
      last is PointerRemovedEvent ||
      last is PointerPanZoomEndEvent;
  Iterable<EventDispatcher> get _dragging => hosts.where((host) => host._drag?.route == this);
  (ElEventPhase, ElEventPhase, ElEventPhase) get _phases => EventDispatcher._tapPhases(down.buttons)!;

  _RouteDragConfiguration _ensureDragConfiguration() => _dragConfiguration ??= _RouteDragConfiguration();

  /// 宿主按命中顺序加入路线；首个加入者创建路线并接入指针路由。
  static void join(PointerEvent down, EventDispatcher host) {
    var route = EventDispatcher._routes[down.pointer];
    if (route == null || !identical(route.down, down)) {
      route?.close();
      route = EventDispatcher._routes[down.pointer] = _Route(down);
      GestureBinding.instance.pointerRouter.addRoute(down.pointer, route.handle);
    }
    route.hosts.add(host);
    // 在命中阶段报名，内层 ElEvent 与官方手势按命中顺序竞争。
    if (host._wantsGesture) route._entry ??= GestureBinding.instance.gestureArena.add(down.pointer, route);
  }

  /// 指针路由在所有宿主收到原始事件之后调用，处理派生手势。
  void handle(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerPanZoomStartEvent) {
      if (identical(event.original ?? event, down)) _begin();
      return;
    }
    last = event;
    switch (event) {
      case PointerMoveEvent() || PointerPanZoomUpdateEvent():
        _track(event);
        _move(event);
        _lastPosition = position;
      case PointerUpEvent() || PointerPanZoomEndEvent():
        _end(event);
        close();
      case PointerCancelEvent() || PointerRemovedEvent():
        _handoffDrags();
        cancel(.pointerCanceled);
        close();
    }
  }

  void _begin() {
    final live = hosts.where((host) => host._live).toList();
    final input = down;
    final transform = live.where((host) => host._canTransform(input)).toList();
    drags = transform.where((host) => host._e.hasDragCallback || host._e.onDragDown != null).toList();
    if (drags.isNotEmpty) {
      final downDetails = <EventDispatcher, ElEventDetails>{};
      final stop = _bubble(drags, .dragDown, (host) => downDetails[host] = host._pointer(.dragDown, input));
      for (final MapEntry(key: host, value: details) in downDetails.entries) {
        if (details.dragStartDistance case final distance?) {
          (_ensureDragConfiguration().startDistances ??= {})[host] = distance;
        }
      }
      if (stop >= 0) drags = drags.sublist(0, stop + 1);
    }
    drags.removeWhere((host) => !host._e.hasDragCallback);
    // 拖拽中落下新手指：与 Flutter 一致，由最新的手指继续驱动。
    for (final host in drags.where((host) => host._drag != null && !host._e.hasScaleCallback).toList()) {
      drags.remove(host);
      host._drag!
        ..route = this
        ..position = position;
      claim();
    }
    if (input is PointerDownEvent && EventDispatcher._tapPhases(input.buttons) != null) {
      // 拖拽中的宿主不为新手指重建点击候选。
      taps = live.where((host) => host._drag == null && host._wantsTap(input.buttons)).toList();
      // 非主键点击只交给最内层。
      if (!_primary && taps.isNotEmpty) taps = [taps.first];
      final stop = _bubble(taps, _phases.$1, (host) => host._pointer(_phases.$1, input));
      if (stop >= 0) taps = taps.sublist(0, stop + 1);
      pressed = List.of(taps);
      if (_primary) {
        for (final host in taps) {
          host._countTap(input);
        }
        for (final (count, phase) in [(2, ElEventPhase.doubleTapDown), (3, ElEventPhase.tripleTapDown)]) {
          final hosts = taps.where((host) => host._tapCount == count).toList();
          _bubble(hosts, phase, (host) => host._pointer(phase, input, count: count));
        }
        for (final host in taps) {
          if (host._e.onLongPress != null) (_longPressTargets ??= {}).add(host);
        }
        final owner = _longPressTargets?.firstOrNull;
        if (owner != null) {
          owner._e.longPressDelay == Duration.zero
              ? _fireLongPress()
              : _longPress = Timer(owner._e.longPressDelay, _fireLongPress);
        }
      }
    }
    scales = transform.where((host) => host._e.hasScaleCallback).toList();
    for (final host in scales.toList()) {
      if (!scales.contains(host)) continue;
      host._ensureScale().points[pointer] = position;
      host._rebase();
      if (host._drag != null && (host._scaleState?.points.length ?? 0) > 1) host._startScale(input);
      if (host._scaling) claim();
      final points = host._scaleState?.points;
      if (points != null && points.length > 1) {
        // 双指先保留仍有效的触点，避免慢捏合被外层滚动抢走；越过缩放阈值才发 Start、取消点击。
        final routes = points.keys.map((pointer) => EventDispatcher._routes[pointer]).toList();
        if (routes.any(
          (route) => route == null || route._rejected || route._closed || route._ended || !route.scales.contains(host),
        )) {
          continue;
        }
        for (final route in routes) {
          if (!host._live || !route!.scales.contains(host)) break;
          route.claim();
        }
      }
    }
    _track(down);
    _begun = true;
  }

  void _move(PointerEvent event) {
    // 鼠标按键组合变化时结束本次点击与拖拽。
    if (down is PointerDownEvent && event.buttons != down.buttons) {
      final releases = List.of(pressed);
      cancel(.tapRejected);
      pressed = releases;
      return;
    }
    final slop = computeHitSlop(down.kind, null);
    final distance = moved.distance;
    if (distance > kTouchSlop) {
      _longPress?.cancel();
      // 只声明长按的候选随长按一起退出。
      taps.removeWhere((host) => host._longPressOnly);
    }
    for (final host in taps.toList()) {
      // 侧键没有按压反馈，始终按距离取消（默认 10）。
      final limit = host._e.tapCancelDistance ?? (_primary ? null : 10.0);
      if (limit != null) {
        if (distance > limit) _cancelTap(host, .tapRejected);
        continue;
      }
      // 未设置取消距离时按点击边界判定：移出发 tapCancel，移回重新 tapDown。
      final inside = host._contains(position);
      if (inside != (_outside?.contains(host) ?? false)) continue;
      if (inside) {
        _outside?.remove(host);
      } else {
        (_outside ??= {}).add(host);
      }
      if (host._pressed == pointer) host._show(inside);
      if (_primary) host._invoke(host._pointer(inside ? .tapDown : .tapCancel, event, reason: .tapRejected));
    }
    // 没有点击候选的纯反馈宿主在越过 hit slop 后结束反馈。
    for (final host in hosts.toList()) {
      if (host._pressed == pointer && !taps.contains(host) && distance > slop) host._release();
    }

    // 已开始的拖拽先收到本次位移，内层消费后余量传给外层。
    final delta = position - _lastPosition;
    ElEventDetails? previous;
    for (final host in _dragConfiguration?.deferredStarts?.keys.toList() ?? const <EventDispatcher>[]) {
      final pending = _dragConfiguration?.deferredStarts?.remove(host);
      if (pending != null && host._live && hosts.contains(host)) host._startDrag(this, pending.$2, event);
    }
    for (final host in _dragging.toList()) {
      if (host._drag?.route != this || !identical(host._lastInput, event.original ?? event)) continue;
      previous = host._updateDrag(event, delta, previous);
      if (previous.propagationStopped) break;
    }

    var stopped = false;
    for (final host in scales.toList()) {
      if (!scales.contains(host) || !host._live) continue;
      final points = host._scaleState?.points;
      if (points == null) continue;
      points[pointer] = position;
      stopped = host._moveScale(event, stopped) || stopped;
    }

    _startDrags(event, distance, slop);
    if (pressed.isEmpty && drags.isEmpty && scales.isEmpty && _dragging.isEmpty) _resolve(.rejected);
  }

  /// 越过起拖距离的候选开始拖拽。轴向候选等主方向落在自己的轴上，首个开始者锁定轴向，
  /// 同轴其余候选随即开始；同时声明两轴时横向需越过更长的 pan slop，避免误触横滚。
  void _startDrags(PointerEvent event, double distance, double slop) {
    final dominant = moved.dx.abs() >= moved.dy.abs() ? Axis.horizontal : Axis.vertical;
    drags.removeWhere((host) => !host._live || host._scaling || host._drag != null);
    Axis? axisFor(ElEvent e) => e.hasPanCallback ? null : _axis ?? dominant;
    bool ready(EventDispatcher host) {
      final e = host._e;
      final axis = axisFor(e);
      final both = e.acceptsDrag(.horizontal) && e.acceptsDrag(.vertical);
      final pan = axis == null || both && axis == .horizontal;
      final start =
          e.dragStartDistance ??
          _dragConfiguration?.startDistances?[host] ??
          (pan ? computePanSlop(down.kind, null) : slop);
      return (axis == null || e.acceptsDrag(axis)) && (distance > start || axis != null && _axis != null);
    }

    final candidates = drags.toList();
    final proposal = candidates.indexWhere(ready);
    if (proposal < 0) return;
    // 外层先达到阈值时，先让兼容的内层响应，内层停止传播后外层不能抢先起拖。
    for (final (index, host) in candidates.indexed) {
      if (!drags.contains(host)) continue;
      if (!host._live || host._scaling || host._drag != null) {
        drags.remove(host);
        continue;
      }
      final e = host._e;
      final axis = axisFor(e);
      if (axis != null && !e.acceptsDrag(axis)) continue;
      if (index > proposal && !ready(host)) continue;
      drags.remove(host);
      _axis ??= axis;
      _longPress?.cancel();
      claim();
      if (identical(_dragConfiguration?.deferMoves?.remove(host), event.original ?? event)) {
        (_ensureDragConfiguration().deferredStarts ??= {})[host] = (event, axis);
        taps.remove(host);
        if (host._pressed == pointer) host._release();
        continue;
      }
      host._startDrag(this, axis, event);
    }
  }

  void _end(PointerEvent event) {
    _longPress?.cancel();
    _dragConfiguration?.deferredStarts?.clear();
    final velocity = _velocity(sparse: true);
    _handoffDrags();
    for (final host in _dragging.toList()) {
      host._endDrag(event, velocity);
    }
    for (final host in hosts.toList()) {
      // 点击候选与纯样式宿主原地松手时保留触摸反馈，被取消的点击已在取消时结束反馈。
      final tapped =
          event is PointerUpEvent &&
          !(_outside?.contains(host) ?? false) &&
          (pressed.contains(host) || !host._wantsGesture);
      if (host._pressed == pointer) host._release(tapped: tapped);
    }
    final flung = event is PointerUpEvent && _flung(event, velocity);
    if (event is PointerUpEvent && pressed.isNotEmpty) {
      // tapUp 对应真实松手；tap 还要求点击资格仍在。
      final stop = _bubble(pressed, _phases.$2, (host) => host._pointer(_phases.$2, event, buttons: down.buttons));
      if (stop >= 0) taps.removeWhere((host) => pressed.indexOf(host) > stop);
      if (_outside case final outside?) taps.removeWhere(outside.contains);
      if (!flung && taps.isNotEmpty) {
        _entry == null || _accepted ? _fireTap(event) : _pendingUp = event;
      }
    }
    for (final host in scales.toList()) {
      final points = host._scaleState?.points;
      if (points?.remove(pointer) == null) continue;
      points!.isEmpty ? host._endScale(event, _velocity()) : host._rebase();
      host._pruneScale();
    }
    scales = [];
  }

  /// 驱动指针离开时沿用已有拖拽，将坐标基线移到最近仍接受输入的触点。
  void _handoffDrags() {
    for (final host in _dragging.toList()) {
      final next = EventDispatcher._routes.values
          .where(
            (route) =>
                route != this &&
                !route._ended &&
                !route._closed &&
                !route._rejected &&
                route._accepted &&
                route.hosts.contains(host) &&
                host._canTransform(route.down),
          )
          .lastOrNull;
      if (next != null && !host._e.hasScaleCallback) {
        host._drag!
          ..route = next
          ..position = next.position;
        next.drags.remove(host);
      }
    }
  }

  /// 只有拖拽与缩放需要速度，纯点击路线不采样。
  bool get _tracking =>
      drags.isNotEmpty ||
      (_dragConfiguration?.deferredStarts?.isNotEmpty ?? false) ||
      scales.isNotEmpty ||
      _dragging.isNotEmpty;

  void _track(PointerEvent event) {
    if (!_tracking || event.synthesized) return;
    var samples = _velocitySamples;
    if (samples == null) {
      samples = _velocitySamples = [];
      assert(() {
        BenchmarkProbe.eventVelocityBufferInstantiateCount++;
        return true;
      }());
    }
    samples.add((event.timeStamp, EventDispatcher._pointerPosition(event)));
    if (samples.length > 20) samples.removeAt(0);
  }

  /// 采样不足的稀疏拖拽按按下到松手的两倍均速估计末速度，避免短促轻扫丢失。
  Offset _velocity({bool sparse = false}) {
    if (!_tracking) return Offset.zero;
    final samples = _velocitySamples;
    if (samples == null || samples.length < 2 || last.timeStamp - samples.last.$1 > const Duration(milliseconds: 80)) {
      return Offset.zero;
    }
    // 释放时拟合真实输入，避免合成位置和 UI 线程排队时间污染速度。
    final tracker = VelocityTracker.withKind(down.kind);
    for (final (time, position) in samples) {
      tracker.addPosition(time, position);
    }
    var speed = tracker.getVelocityEstimate()?.pixelsPerSecond ?? Offset.zero;
    final elapsed = (last.timeStamp - down.timeStamp).inMicroseconds;
    if (sparse && speed == Offset.zero && elapsed > 0) {
      var end = samples.last.$2;
      if (last is PointerUpEvent && (position - end).distance <= kTouchSlop * 4) end = position;
      speed = (end - EventDispatcher._pointerPosition(down)) * (2 * Duration.microsecondsPerSecond / elapsed);
    }
    if (speed.distance < kMinFlingVelocity) return Offset.zero;
    return Velocity(pixelsPerSecond: speed).clampMagnitude(0, kMaxFlingVelocity).pixelsPerSecond;
  }

  /// 未越过起拖距离就快速抬手时，移动超过点击取消距离一半的候选按速度补发一次完整拖拽。
  bool _flung(PointerEvent event, Offset velocity) {
    final offset = moved;
    if (velocity == Offset.zero || drags.isEmpty) return false;
    final axis = offset.dx.abs() >= offset.dy.abs() ? Axis.horizontal : Axis.vertical;
    final candidates = drags
        .where((host) => host._live && host._drag == null && host._e.acceptsDrag(axis))
        .where((host) => offset.distance > (host._e.tapCancelDistance ?? 10) / 2)
        .toList();
    if (candidates.isEmpty) return false;
    _cancelTaps(.otherGestureAccepted);
    for (final host in candidates) {
      if (!drags.remove(host)) continue;
      host._startDrag(this, host._e.hasPanCallback ? null : axis, event);
      final drag = host._drag;
      if (drag == null) continue;
      drag.position = EventDispatcher._pointerPosition(down);
      host._updateDrag(event, offset, null);
      host._endDrag(event, velocity);
    }
    return true;
  }

  void _fireTap(PointerUpEvent up) {
    final hosts = taps.where((host) => host._live).toList();
    taps = [];
    if (!_primary) {
      _bubble(hosts, _phases.$3, (host) => host._pointer(_phases.$3, up, buttons: down.buttons));
      return;
    }
    final counts = {for (final host in hosts) host: host._tapCount};
    void tap() => _bubble(hosts, .tap, (host) => host._pointer(.tap, up, buttons: down.buttons, count: counts[host]!));
    // 任一节点声明 deferTap 时，整条路线的单击等连击窗口结束再派发，连击发生则放弃。
    final deferrer = hosts.where((host) => host._e.deferTap && host._maxTaps > 1).firstOrNull;
    for (final host in hosts) {
      host._confirmTap(up);
    }
    if (deferrer == null) {
      tap();
    } else if (counts[deferrer] == 1) {
      deferrer._deferred = tap;
    }
    for (final (count, phase) in [(2, ElEventPhase.doubleTap), (3, ElEventPhase.tripleTap)]) {
      final hosts = counts.keys.where((host) => counts[host] == count).toList();
      _bubble(hosts, phase, (host) => host._pointer(phase, down, buttons: down.buttons, count: count));
    }
  }

  void _fireLongPress() {
    _longPress = null;
    final owners = taps
        .where(
          (host) => host._live && (_longPressTargets?.contains(host) ?? false) && !(_outside?.contains(host) ?? false),
        )
        .toList();
    if (owners.isEmpty || _rejected) return;
    final details = <ElEventDetails>[];
    final stop = _bubble(owners, .longPress, (host) => (details..add(host._pointer(.longPress, down))).last);
    // 业务拒绝默认动作时不认领指针，点击资格保留。
    if (details.any((details) => details.defaultPrevented)) return;
    claim();
    _cancelTaps(.selfGestureAccepted);
    if (stop >= 0) exclusive(owners[stop]);
  }

  void _cancelTap(EventDispatcher host, ElEventCancelReason reason) {
    if (!taps.remove(host)) return;
    host._resetTaps();
    if (host._pressed == pointer) host._release();
    if (_primary && !(_outside?.contains(host) ?? false)) {
      host._invoke(host._pointer(.tapCancel, last, reason: reason));
    }
  }

  void _cancelTaps(ElEventCancelReason reason, {EventDispatcher? owner}) {
    _longPress?.cancel();
    for (final host in taps.toList()) {
      _cancelTap(host, owner != null && host != owner ? .otherGestureAccepted : reason);
    }
  }

  /// 节点在起拖、缩放或长按时停止了传播：独占本路线，其余节点退出，自身点击取消但保留 tapUp。
  void exclusive(EventDispatcher owner) {
    claim();
    _cancelTaps(.selfGestureAccepted, owner: owner);
    final outside = hosts.skip(hosts.indexOf(owner) + 1).toList();
    drags.removeWhere(outside.contains);
    for (final host in outside) {
      _dragConfiguration?.deferredStarts?.remove(host);
      pressed.remove(host);
      if (host._drag?.route == this) host._endDrag(last, null);
      if (scales.remove(host) && host._scaleState?.points.remove(pointer) != null) {
        host._endScale(last, null);
        host._pruneScale();
      }
    }
  }

  /// 取消本路线的全部派生手势，宿主仍接收原始事件。
  void cancel(ElEventCancelReason reason) {
    _pendingUp = null;
    _dragConfiguration?.deferredStarts?.clear();
    _dragConfiguration?.deferMoves?.clear();
    drags.clear();
    for (final host in hosts.toList()) {
      if (host._drag?.route == this) host._endDrag(last, null);
    }
    for (final host in scales.toList()) {
      if (host._scaleState?.points.remove(pointer) != null) host._endScale(last, null);
      host._pruneScale();
    }
    scales = [];
    _cancelTaps(reason);
    pressed = [];
    for (final host in hosts.toList()) {
      if (host._pressed == pointer) host._release();
    }
  }

  /// 宿主不再参与本路线的派生手势，仍接收原始事件。
  void drop(EventDispatcher host, {bool notify = true}) {
    final revision = host._revision;
    if (notify) {
      _cancelTap(host, .external);
    } else {
      taps.remove(host);
    }
    pressed.remove(host);
    drags.remove(host);
    _dragConfiguration?.startDistances?.remove(host);
    _dragConfiguration?.deferredStarts?.remove(host);
    _dragConfiguration?.deferMoves?.remove(host);
    if (host._drag?.route == this) {
      if (notify && revision == host._revision) {
        host._endDrag(last, null);
      } else {
        host._drag = null;
      }
    }
    if (scales.remove(host) && host._scaleState?.points.remove(pointer) != null) {
      if (notify && revision == host._revision) {
        host._endScale(last, null);
      } else {
        host._scaleState?.active = false;
      }
      host._pruneScale();
    }
    if (host._pressed == pointer) host._release();
  }

  /// 宿主换了回调结构：按新声明加入或退出未结束路线的点击与拖拽候选。
  void reseed(EventDispatcher host) {
    final input = down;
    if (_ended || !host._live || input is! PointerDownEvent) return;
    if (!_begun) {
      // 按下途中换结构：本次按下不再交给新声明。
      drop(host);
      hosts.remove(host);
      if (hosts.isEmpty) {
        _resolve(.rejected);
        close();
      }
      return;
    }
    List<EventDispatcher> sync(List<EventDispatcher> list, bool wanted) =>
        hosts.where((item) => item == host ? wanted : list.contains(item)).toList();
    _dragConfiguration?.deferredStarts?.remove(host);
    _dragConfiguration?.deferMoves?.remove(host);
    drags = sync(drags, host._drag == null && host._canTransform(input) && host._e.hasDragCallback);
    if (drags.contains(host)) {
      if (host._activeCallback case final callback? when callback.phase == ElEventPhase.pointerMove) {
        final move = callback.originalEvent! as PointerEvent;
        (_ensureDragConfiguration().deferMoves ??= {})[host] = move.original ?? move;
      }
    }
    if (_rejected || EventDispatcher._tapPhases(input.buttons) == null) return;
    final tap = host._wantsTap(input.buttons);
    if (!tap) taps.remove(host);
    if (tap && !pressed.contains(host)) {
      taps = sync(taps, true);
      pressed = sync(pressed, true);
    }
  }

  /// 宿主中途退出（卸载、禁用）。
  void leave(EventDispatcher host, {bool notify = true}) {
    if (!hosts.remove(host)) return;
    final revision = host._revision;
    if (notify && !_ended && down is PointerPanZoomStartEvent) {
      final end = PointerPanZoomEndEvent(pointer: pointer, device: down.device, position: position);
      host._invoke(host._pointer(.pointerPanZoomEnd, end));
    } else if (notify && !_ended) {
      final cancel = PointerCancelEvent(pointer: pointer, kind: down.kind, device: down.device, position: position);
      host._invoke(host._pointer(.pointerCancel, cancel, reason: .external));
    }
    drop(host, notify: notify && revision == host._revision);
    if (hosts.isEmpty) {
      _resolve(.rejected);
      close();
    }
  }

  /// 认领指针，官方手势随之失败。
  void claim() => _resolve(.accepted);

  void _resolve(GestureDisposition disposition) {
    if (!_accepted && !_rejected) _entry?.resolve(disposition);
  }

  void close() {
    _longPress?.cancel();
    if (_closed) return;
    _closed = true;
    GestureBinding.instance.pointerRouter.removeRoute(pointer, handle);
    if (identical(EventDispatcher._routes[pointer], this)) EventDispatcher._routes.remove(pointer);
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    final up = _pendingUp;
    _pendingUp = null;
    if (up != null) _fireTap(up);
  }

  @override
  void rejectGesture(int pointer) {
    if (_rejected) return;
    _rejected = true;
    cancel(.otherGestureAccepted);
  }

  /// 由内向外派发，返回停止传播的宿主下标，未停止返回 -1。
  static int _bubble(List<EventDispatcher> hosts, ElEventPhase phase, ElEventDetails Function(EventDispatcher) make) {
    ElEventDetails? previous;
    for (var i = 0; i < hosts.length; i++) {
      final host = hosts[i];
      if (!host._live || host._e.handlerFor(phase) == null) continue;
      final details = make(host);
      if (previous?.defaultPrevented == true) details.preventDefault();
      if (previous?.focusPreserved == true) details.preserveFocus();
      host._invoke(details);
      previous = details;
      if (details.propagationStopped) return i;
    }
    return -1;
  }
}

/// 仅设备阈值覆盖或回调重接时需要的拖拽配置，不占用普通点击路线。
final class _RouteDragConfiguration {
  Map<EventDispatcher, double>? startDistances;
  Map<EventDispatcher, (PointerEvent, Axis?)>? deferredStarts;
  Map<EventDispatcher, PointerEvent>? deferMoves;
}
