part of 'dispatcher.dart';

extension _TapEvents on EventDispatcher {
  bool _canTransform(PointerEvent down) =>
      (_e.dragDevices?.contains(down.kind) ?? true) &&
      (down is PointerPanZoomStartEvent || down.buttons == kPrimaryButton);

  /// 只有连击监听才记录历史，单击不分配窗口状态。
  void _countTap(PointerDownEvent down) {
    if (_shape.maxTaps == 1) return;
    final state = _tapSequence ??= _TapSequence();
    EventDispatcher._retaining.add(this);
    final close =
        state.window?.isActive == true &&
        down.timeStamp - state.time <= _e.doubleTapInterval &&
        (down.position - state.position!).distance <= kDoubleTapSlop;
    state.window?.cancel();
    final pending = state.deferred;
    state.deferred = null;
    if (!close) pending?.call();
    if (!identical(_tapSequence, state)) return;
    state.count = close && state.count < _shape.maxTaps ? state.count + 1 : 1;
  }

  /// 确认点击后打开连击窗口，窗口结束时派发延后的单击并释放历史。
  void _confirmTap(PointerUpEvent up) {
    final state = _tapSequence;
    if (state == null) return;
    state.position = up.position;
    state.time = up.timeStamp;
    final maxTaps = _shape.maxTaps;
    if (maxTaps == 1 || state.count >= maxTaps) return _resetTaps();
    state.window = Timer(_e.doubleTapInterval, () {
      if (!identical(_tapSequence, state)) return;
      _tapSequence = null;
      _settle();
      final pending = state.deferred;
      state.deferred = null;
      pending?.call();
    });
  }

  void _resetTaps() {
    final state = _tapSequence;
    if (state == null) return;
    _tapSequence = null;
    _settle();
    state.window?.cancel();
    state.deferred = null;
  }

  bool _contains(Offset global) {
    if (!_render.attached || !_render.hasSize) return true;
    return hitBoundsContainsGlobal?.call(global) ??
        (Offset.zero & _render.size).contains(_render.globalToLocal(global));
  }

  void _press(PointerDownEvent down) {
    if (_pressed != null || down.buttons != kPrimaryButton) return;
    final state = _pressState ??= _PressState();
    EventDispatcher._retaining.add(this);
    state.pointer = down.pointer;
    final touch = down.kind == PointerDeviceKind.touch;
    state.pressTimer?.cancel();
    state.holdTimer?.cancel();
    final delay = touch ? _e.delayTouchDown : Duration.zero;
    state.pressTimer = delay > Duration.zero ? Timer(delay, () => _show(true)) : null;
    if (state.pressTimer == null) _show(true);
    if (!identical(_pressState, state)) return;
    final hold = touch ? _e.delayTouchUp : Duration.zero;
    state.holdTimer = hold > Duration.zero ? Timer(hold, () => state.pointer == null ? _show(false) : null) : null;
  }

  /// 触摸确认点击时保留最短反馈时长，反馈结束立即释放按压状态。
  void _release({bool tapped = false}) {
    final state = _pressState;
    if (state == null || state.pointer == null) return;
    state.pointer = null;
    state.pressTimer?.cancel();
    if (tapped && state.shown && state.holdTimer?.isActive == true) return;
    state.holdTimer?.cancel();
    _show(false);
  }

  void _show(bool value) {
    final state = _pressState;
    if (state == null) return;
    final changed = state.shown != value;
    state.shown = value;
    if (!value && state.pointer == null) {
      state.pressTimer?.cancel();
      state.holdTimer?.cancel();
      _pressState = null;
      _settle();
    }
    if (changed) onTapChanged?.call(isTapPressed);
  }
}

/// 一条路线上的点击候选：按下、连击、长按与最终点击。
///
/// 路线上有宿主为本次按键声明点击或长按时才创建，因此只对应 [PointerDownEvent]。
final class _RouteTaps {
  _RouteTaps(this.route) {
    assert(() {
      BenchmarkProbe.eventRouteTapsInstantiateCount++;
      return true;
    }());
  }

  final _Route route;

  // pressed 收到按下、松手时收到抬起；eligible 仍有资格触发点击；outside 暂时移出点击边界。
  var pressed = <EventDispatcher>[];
  var eligible = <EventDispatcher>[];
  Set<EventDispatcher>? outside;
  Set<EventDispatcher>? longPressTargets;
  Timer? longPress;
  PointerUpEvent? pendingUp;

  /// 仍有宿主等待抬起。
  bool get engaged => pressed.isNotEmpty;

  bool get _primary => route.down.buttons == kPrimaryButton;
  (ElEventPhase, ElEventPhase, ElEventPhase) get _phases => EventDispatcher._tapPhases(route.down.buttons)!;

  /// 派发按下并登记连击与长按。
  void begin(List<EventDispatcher> hosts, PointerDownEvent input) {
    // 非主键点击只交给最内层。
    eligible = _primary ? hosts : [hosts.first];
    final stop = _Route._bubble(eligible, _phases.$1, (host) => host._pointer(_phases.$1, input));
    if (stop >= 0) eligible = eligible.sublist(0, stop + 1);
    pressed = List.of(eligible);
    if (!_primary) return;
    for (final host in eligible) {
      host._countTap(input);
    }
    for (final (count, phase) in [(2, ElEventPhase.doubleTapDown), (3, ElEventPhase.tripleTapDown)]) {
      final hosts = eligible.where((host) => host._tapCount == count).toList();
      _Route._bubble(hosts, phase, (host) => host._pointer(phase, input, count: count));
    }
    for (final host in eligible) {
      if (host._e.onLongPress != null) (longPressTargets ??= {}).add(host);
    }
    final owner = longPressTargets?.firstOrNull;
    if (owner != null) {
      owner._e.longPressDelay == Duration.zero
          ? fireLongPress()
          : longPress = Timer(owner._e.longPressDelay, fireLongPress);
    }
  }

  /// 位移越过触摸容差：长按不再触发，只声明长按的候选随之退出。
  void exceedTouchSlop() {
    longPress?.cancel();
    eligible.removeWhere((host) => host._shape.longPressOnly);
  }

  /// 候选随指针移动：越过取消距离即退出，否则按是否仍在边界内切换按压反馈。
  void move(EventDispatcher host, PointerEvent event, double distance) {
    if (!eligible.contains(host)) return;
    final limit = host._e.tapCancelDistance ?? (_primary ? null : 10.0);
    if (limit != null) {
      if (distance > limit) cancel(host, .tapRejected);
      return;
    }
    final inside = host._contains(route.position);
    if (inside != (outside?.contains(host) ?? false)) return;
    if (inside) {
      outside?.remove(host);
    } else {
      (outside ??= {}).add(host);
    }
    if (host._pressed == route.pointer) host._show(inside);
    if (_primary) host._invoke(host._pointer(inside ? .tapDown : .tapCancel, event, reason: .tapRejected));
  }

  /// 松手：派发抬起，仍有资格的候选在竞技场裁决后触发点击。
  void end(PointerUpEvent event, {required bool flung}) {
    if (pressed.isEmpty) return;
    // tapUp 对应真实松手；tap 还要求点击资格仍在。
    final stop = _Route._bubble(
      pressed,
      _phases.$2,
      (host) => host._pointer(_phases.$2, event, buttons: route.down.buttons),
    );
    if (stop >= 0) eligible.removeWhere((host) => pressed.indexOf(host) > stop);
    if (outside case final outside?) eligible.removeWhere(outside.contains);
    if (!flung && eligible.isNotEmpty) {
      route._entry == null || route._accepted ? fire(event) : pendingUp = event;
    }
  }

  /// 竞技场胜出后补发等待裁决的点击。
  void firePendingUp() {
    final up = pendingUp;
    pendingUp = null;
    if (up != null) fire(up);
  }

  void fire(PointerUpEvent up) {
    final down = route.down;
    final hosts = eligible.where((host) => host._live).toList();
    eligible = [];
    if (!_primary) {
      _Route._bubble(hosts, _phases.$3, (host) => host._pointer(_phases.$3, up, buttons: down.buttons));
      return;
    }
    final counts = {for (final host in hosts) host: host._tapCount};
    void tap() =>
        _Route._bubble(hosts, .tap, (host) => host._pointer(.tap, up, buttons: down.buttons, count: counts[host]!));
    // 任一节点声明 deferTap 时，整条路线的单击等连击窗口结束再派发，连击发生则放弃。
    final deferrer = hosts.where((host) => host._e.deferTap && host._shape.maxTaps > 1).firstOrNull;
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
      _Route._bubble(hosts, phase, (host) => host._pointer(phase, down, buttons: down.buttons, count: count));
    }
  }

  void fireLongPress() {
    longPress = null;
    final owners = eligible
        .where(
          (host) => host._live && (longPressTargets?.contains(host) ?? false) && !(outside?.contains(host) ?? false),
        )
        .toList();
    if (owners.isEmpty || route._rejected) return;
    final details = <ElEventDetails>[];
    final stop = _Route._bubble(
      owners,
      .longPress,
      (host) => (details..add(host._pointer(.longPress, route.down))).last,
    );
    // 业务拒绝默认动作时不认领指针，点击资格保留。
    if (details.any((details) => details.defaultPrevented)) return;
    route.claim();
    cancelAll(.selfGestureAccepted);
    if (stop >= 0) route.exclusive(owners[stop]);
  }

  void cancel(EventDispatcher host, ElEventCancelReason reason) {
    if (!eligible.remove(host)) return;
    host._resetTaps();
    if (host._pressed == route.pointer) host._release();
    if (_primary && !(outside?.contains(host) ?? false)) {
      host._invoke(host._pointer(.tapCancel, route.last, reason: reason));
    }
  }

  void cancelAll(ElEventCancelReason reason, {EventDispatcher? owner}) {
    longPress?.cancel();
    for (final host in eligible.toList()) {
      cancel(host, owner != null && host != owner ? .otherGestureAccepted : reason);
    }
  }

  /// 宿主换了回调结构：按新声明加入或退出候选，已按下的成员保持原状。
  void reseed(EventDispatcher host, bool wanted) {
    if (!wanted) {
      eligible.remove(host);
    } else if (!pressed.contains(host)) {
      eligible = route._resync(eligible, host, true);
      pressed = route._resync(pressed, host, true);
    }
  }
}

/// 一次指针按压及其最短反馈时长。
final class _PressState {
  _PressState() {
    assert(() {
      BenchmarkProbe.eventPressStateInstantiateCount++;
      return true;
    }());
  }
  int? pointer;
  bool shown = false;
  Timer? pressTimer, holdTimer;
}

/// 仅双击或三击监听跨按下保留的历史。
final class _TapSequence {
  _TapSequence() {
    assert(() {
      BenchmarkProbe.eventTapSequenceInstantiateCount++;
      return true;
    }());
  }
  int count = 0;
  Offset? position;
  Duration time = Duration.zero;
  Timer? window;
  VoidCallback? deferred;
}
