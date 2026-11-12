part of 'dispatcher.dart';

/// 一个指针从按下到抬起的路线：命中宿主由内向外排列，作为竞技场成员协调成员进出、原始输入与认领。
///
/// 点击、拖拽、缩放各由路线内的独立对象承担，路线上有宿主声明对应能力时才创建。
final class _Route extends GestureArenaMember {
  _Route(this.down) : last = down, _lastPosition = EventDispatcher._pointerPosition(down);

  final PointerEvent down;
  PointerEvent last;
  Offset _lastPosition;
  List<(Duration, Offset)>? _velocitySamples;
  final hosts = <EventDispatcher>[];
  _RouteTaps? _taps;
  _RouteDrags? _drags;
  _RouteScales? _scales;
  _PointerOwnership? _ownership;
  List<(EventDispatcher, ElEventPhase, PointerEvent)>? _pendingRaw;
  GestureArenaEntry? _entry;
  bool _accepted = false, _rejected = false, _closed = false, _begun = false;

  int get pointer => down.pointer;
  Offset get position => EventDispatcher._pointerPosition(last);
  Offset get moved => position - EventDispatcher._pointerPosition(down);
  bool get _ended =>
      last is PointerUpEvent ||
      last is PointerCancelEvent ||
      last is PointerRemovedEvent ||
      last is PointerPanZoomEndEvent;

  _RouteDrags _ensureDrags() => _drags ??= _RouteDrags(this);

  bool _inScale(EventDispatcher host) => _scales?.members.contains(host) ?? false;

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
    if (host._shape.gesture) route._entry ??= GestureBinding.instance.gestureArena.add(down.pointer, route);
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
        _abandonPendingOwnership();
        _drags?.handoff();
        cancel(.pointerCanceled);
        close();
    }
  }

  /// 按拖拽、点击、缩放的顺序建立候选；没有宿主声明的能力不创建对应对象。
  void _begin() {
    final live = hosts.where((host) => host._live && _allowsRaw(host)).toList();
    final input = down;
    final transform = live.where((host) => host._canTransform(input)).toList();
    final dragging = transform.where((host) => host._shape.drag || host._shape.has(.dragDown)).toList();
    if (dragging.isNotEmpty) _ensureDrags().begin(dragging);
    if (input is PointerDownEvent && EventDispatcher._tapPhases(input.buttons) != null) {
      // 拖拽中的宿主不为新手指重建点击候选。
      final tapping = live.where((host) => host._drag == null && host._shape.wantsTap(input.buttons)).toList();
      if (tapping.isNotEmpty) (_taps ??= _RouteTaps(this)).begin(tapping, input);
    }
    final scaling = transform.where((host) => host._shape.scale).toList();
    if (scaling.isNotEmpty) (_scales ??= _RouteScales(this)).begin(scaling);
    _track(down);
    _begun = true;
    _tryOwnedScaleUpgrades();
  }

  void _move(PointerEvent event) {
    // 鼠标按键组合变化时结束本次点击与拖拽。
    if (down is PointerDownEvent && event.buttons != down.buttons) {
      for (final host in hosts.toList()) {
        _flushRawFor(host, event);
      }
      final releases = List.of(_taps?.pressed ?? const <EventDispatcher>[]);
      cancel(.tapRejected);
      _taps?.pressed = releases;
      return;
    }
    final slop = computeHitSlop(down.kind, null);
    final distance = moved.distance;
    if (distance > kTouchSlop) _taps?.exceedTouchSlop();
    final delta = position - _lastPosition;
    final original = event.original ?? event;
    ElEventDetails? previous;
    var dragStopped = false;
    var scaleStopped = false;
    // 每个实际命中成员先交付自身 raw，再推进手势；内层认领可使尚未执行的祖先 raw 失效。
    for (final host in hosts.toList()) {
      if (_closed || !identical(last.original ?? last, original)) return;
      _flushRawFor(host, event);
      if (_closed || !identical(last.original ?? last, original)) return;
      if (!host._live || !hosts.contains(host)) continue;
      final active = _allowsRaw(host);
      if (active) {
        _taps?.move(host, event, distance);
        if (_closed || !identical(last.original ?? last, original)) return;
        if (!_allowsRaw(host) || !host._live || !hosts.contains(host)) continue;
        if (host._pressed == pointer && !(_taps?.eligible.contains(host) ?? false) && distance > slop) host._release();
        final drags = _drags;
        if (drags != null) {
          drags.startDeferred(host, event);
          if (!dragStopped && drags.drives(host) && identical(host._lastInput, original)) {
            previous = host._updateDrag(event, delta, previous);
            dragStopped = previous.propagationStopped;
          }
        }
      }
      final scales = _scales;
      if (scales != null &&
          scales.members.contains(host) &&
          (active || (_ownership?.scaleAllowed.contains(host) ?? false))) {
        scaleStopped = scales.move(host, event, scaleStopped);
      }
      if (_allowsRaw(host) && host._live && hosts.contains(host)) _drags?.tryStart(host, event, distance, slop);
    }
    if (_taps?.engaged != true && _drags?.engaged != true && _scales?.engaged != true) _resolve(.rejected);
  }

  void _end(PointerEvent event) {
    _taps?.longPress?.cancel();
    _drags?.deferredStarts?.clear();
    final velocity = _velocity(sparse: true);
    _drags
      ?..handoff()
      ..finish(event, velocity);
    if (event is PointerUpEvent) _taps?.settle(event);
    for (final host in hosts.toList()) {
      // 点击候选与纯样式宿主原地松手时保留触摸反馈，被取消的点击已在取消时结束反馈。
      final tapped =
          event is PointerUpEvent &&
          !(_taps?.outside?.contains(host) ?? false) &&
          ((_taps?.pressed.contains(host) ?? false) || !host._shape.gesture);
      if (host._pressed == pointer) host._release(tapped: tapped);
    }
    if (event is PointerUpEvent) {
      final flung = _drags?.fling(event, velocity) ?? false;
      _taps?.end(event, flung: flung);
    }
    _scales?.end(event);
  }

  /// 只有拖拽与缩放需要速度，纯点击路线不采样。
  bool get _tracking => _drags?.tracking == true || _scales?.engaged == true;

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

  void _cancelTap(EventDispatcher host, ElEventCancelReason reason) => _taps?.cancel(host, reason);

  void _cancelTaps(ElEventCancelReason reason, {EventDispatcher? owner}) => _taps?.cancelAll(reason, owner: owner);

  /// 节点在起拖、缩放或长按时停止了传播：独占本路线，其余节点退出，自身点击取消但保留 tapUp。
  void exclusive(EventDispatcher owner) {
    claim();
    _cancelTaps(.selfGestureAccepted, owner: owner);
    final outside = hosts.skip(hosts.indexOf(owner) + 1).toList();
    _drags?.candidates.removeWhere(outside.contains);
    for (final host in outside) {
      _drags?.deferredStarts?.remove(host);
      _taps?.pressed.remove(host);
      _drags?.cancelDriven(host);
      _scales?.release(host);
    }
  }

  /// 取消本路线的全部派生手势，宿主仍接收原始事件。
  void cancel(ElEventCancelReason reason) {
    _taps?.pendingUp = null;
    _drags?.cancel();
    _scales?.cancel();
    _taps
      ?..cancelAll(reason)
      ..pressed = [];
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
      _taps?.eligible.remove(host);
    }
    _taps?.pressed.remove(host);
    _drags?.drop(host, notify: notify && revision == host._revision);
    _scales?.release(host, notify: notify && revision == host._revision);
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
      _forgetInput(host);
      if (hosts.isEmpty) {
        _resolve(.rejected);
        close();
      }
      return;
    }
    final draggable = host._drag == null && host._canTransform(input) && host._shape.drag;
    if (draggable || _drags != null) _ensureDrags().reseed(host, draggable);
    if (_rejected || EventDispatcher._tapPhases(input.buttons) == null) return;
    final tappable = host._shape.wantsTap(input.buttons);
    if (tappable || _taps != null) (_taps ??= _RouteTaps(this)).reseed(host, tappable);
  }

  /// 按路线的由内向外顺序重排候选，[host] 按 [wanted] 加入或退出。
  List<EventDispatcher> _resync(List<EventDispatcher> list, EventDispatcher host, bool wanted) =>
      hosts.where((item) => item == host ? wanted : list.contains(item)).toList();

  /// 宿主中途退出（卸载、禁用）。
  void leave(EventDispatcher host, {bool notify = true}) {
    if (!hosts.remove(host)) return;
    _forgetInput(host);
    final revision = host._revision;
    final notifyRaw = notify && !_ended && (_ownership?.rawInactive.add(host) ?? true);
    if (notifyRaw && down is PointerPanZoomStartEvent) {
      final end = PointerPanZoomEndEvent(pointer: pointer, device: down.device, position: position);
      host._invoke(host._pointer(.pointerPanZoomEnd, end));
    } else if (notifyRaw) {
      final cancel = PointerCancelEvent(pointer: pointer, kind: down.kind, device: down.device, position: position);
      host._invoke(host._pointer(.pointerCancel, cancel, reason: .external));
    }
    drop(host, notify: notify && revision == host._revision);
    if (_ownership?.pendingOwner == host) _abandonPendingOwnership();
    if (hosts.isEmpty) {
      _resolve(.rejected);
      close();
    }
  }

  /// 输入身份只在路线存续期间用于比对，成员离开或路线结束后不再保留本指针的事件对象。
  void _forgetInput(EventDispatcher host) {
    if (host._lastInput?.pointer == pointer) host._lastInput = null;
  }

  /// 认领指针，官方手势随之失败。
  void claim() => _resolve(.accepted);

  void _resolve(GestureDisposition disposition) {
    if (!_accepted && !_rejected) _entry?.resolve(disposition);
  }

  void close() {
    _taps?.longPress?.cancel();
    if (_closed) return;
    _closed = true;
    hosts.forEach(_forgetInput);
    GestureBinding.instance.pointerRouter.removeRoute(pointer, handle);
    if (identical(EventDispatcher._routes[pointer], this)) EventDispatcher._routes.remove(pointer);
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    _commitPendingOwnership();
    if (_begun) _tryOwnedScaleUpgrades();
    _taps?.firePendingUp();
  }

  @override
  void rejectGesture(int pointer) {
    if (_rejected) return;
    _rejected = true;
    _abandonPendingOwnership();
    cancel(.otherGestureAccepted);
  }

  /// 由内向外派发，返回停止传播的宿主下标，未停止返回 -1。
  static int _bubble(List<EventDispatcher> hosts, ElEventPhase phase, ElEventDetails Function(EventDispatcher) make) {
    ElEventDetails? previous;
    for (var i = 0; i < hosts.length; i++) {
      final host = hosts[i];
      if (!host._live || !host._shape.has(phase)) continue;
      final details = make(host);
      final pointer = details.pointerEvent?.pointer;
      if (pointer != null && EventDispatcher._routes[pointer]?._allowsRaw(host) == false) continue;
      if (previous?.defaultPrevented == true) details.preventDefault();
      if (previous?.focusPreserved == true) details.preserveFocus();
      host._invoke(details);
      previous = details;
      if (details.propagationStopped) return i;
    }
    return -1;
  }
}
