part of 'dispatcher.dart';

extension _TapEvents on EventDispatcher {
  bool _wantsTap(int buttons) {
    final event = _e;
    final phases = EventDispatcher._tapPhases(buttons);
    if (phases == null) return false;
    if (buttons == kPrimaryButton && (event.hasTapLikeCallback || event.onTapCancel != null)) return true;
    return [phases.$1, phases.$2, phases.$3].any((phase) => event.handlerFor(phase) != null);
  }

  bool get _longPressOnly =>
      _e.onLongPress != null &&
      const <ElEventPhase>[
        .tapDown,
        .tapUp,
        .tap,
        .tapCancel,
        .doubleTapDown,
        .doubleTap,
        .tripleTapDown,
        .tripleTap,
      ].every((phase) => _e.handlerFor(phase) == null);

  bool get _wantsGesture =>
      _e.hasDragCallback ||
      ElEventPhase.values
          .getRange(ElEventPhase.tapDown.index, ElEventPhase.rotationUpdate.index + 1)
          .any((phase) => _e.handlerFor(phase) != null);

  bool _canTransform(PointerEvent down) =>
      (_e.dragDevices?.contains(down.kind) ?? true) &&
      (down is PointerPanZoomStartEvent || down.buttons == kPrimaryButton);

  int get _maxTaps => _event?.onTripleTap != null || _event?.onTripleTapDown != null
      ? 3
      : _event?.onDoubleTap != null || _event?.onDoubleTapDown != null
      ? 2
      : 1;

  /// 只有连击监听才记录历史，单击不分配窗口状态。
  void _countTap(PointerDownEvent down) {
    if (_maxTaps == 1) return;
    final state = _tapSequence ??= _TapSequence();
    final close =
        state.window?.isActive == true &&
        down.timeStamp - state.time <= _e.doubleTapInterval &&
        (down.position - state.position!).distance <= kDoubleTapSlop;
    state.window?.cancel();
    final pending = state.deferred;
    state.deferred = null;
    if (!close) pending?.call();
    if (!identical(_tapSequence, state)) return;
    state.count = close && state.count < _maxTaps ? state.count + 1 : 1;
  }

  /// 确认点击后打开连击窗口，窗口结束时派发延后的单击并释放历史。
  void _confirmTap(PointerUpEvent up) {
    final state = _tapSequence;
    if (state == null) return;
    state.position = up.position;
    state.time = up.timeStamp;
    if (_maxTaps == 1 || state.count >= _maxTaps) return _resetTaps();
    state.window = Timer(_e.doubleTapInterval, () {
      if (!identical(_tapSequence, state)) return;
      _tapSequence = null;
      final pending = state.deferred;
      state.deferred = null;
      pending?.call();
    });
  }

  void _resetTaps() {
    final state = _tapSequence;
    _tapSequence = null;
    state?.window?.cancel();
    state?.deferred = null;
  }

  bool _contains(Offset global) {
    if (!_render.attached || !_render.hasSize) return true;
    return hitBoundsContainsGlobal?.call(global) ??
        (Offset.zero & _render.size).contains(_render.globalToLocal(global));
  }

  void _press(PointerDownEvent down) {
    if (_pressed != null || down.buttons != kPrimaryButton) return;
    final state = _pressState ??= _PressState();
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
    }
    if (changed) onTapChanged?.call(isTapPressed);
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
