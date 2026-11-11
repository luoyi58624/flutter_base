part of 'dispatcher.dart';

extension _KeyboardEvents on EventDispatcher {
  _KeyboardState _ensureKeyboard() => _keyboard ??= _KeyboardState();

  void _pruneKeyboard() {
    final state = _keyboard;
    if (state == null || (state.held?.isNotEmpty ?? false) || (state.repeats?.isNotEmpty ?? false)) return;
    state.clock?.stop();
    _keyboard = null;
  }

  /// 重复限流只为实际订阅的键盘输入建立记录，释放或失焦后回收。
  void _deliver(ElEventDetails details) {
    final phase = details.phase, key = details.physicalKey, interval = _e.keyRepeatInterval;
    if (phase == .blur || phase == .keyDown && details.logicalKey == LogicalKeyboardKey.escape) {
      _keyboard?.repeats?.clear();
    }
    if (key == null || phase != .keyDown && phase != .keyRepeat || _handler(phase) == null || interval == .zero) {
      if (key != null) _keyboard?.repeats?.remove(key);
      _pruneKeyboard();
      return _invoke(details);
    }
    final state = _ensureKeyboard();
    final repeats = state.repeats ??= {};
    // 采样时钟在测试中随虚拟时间推进。
    final now = (state.clock ??= GestureBinding.instance.samplingClock.stopwatch()..start()).elapsed;
    final last = repeats[key];
    if (phase == .keyRepeat && last != null && now - last.$1 < interval) {
      if (last.$2) details.preventDefault();
      if (last.$3) details.stopPropagation();
      return;
    }
    repeats[key] = (now, false, false);
    _invoke(details);
    if (identical(_keyboard, state) && repeats.containsKey(key)) {
      repeats[key] = (now, details.defaultPrevented, details.propagationStopped);
    }
  }

  /// 沿渲染祖先链冒泡，用于键盘与焦点。
  void _bubbleUp(ElEventDetails details) {
    _deliver(details);
    for (var render = _render.parent; render != null && !details.propagationStopped; render = render.parent) {
      final target = EventDispatcher._hosts[render];
      if (target == null || !render.attached || !target._live) continue;
      details.keyboardTapMatched = false;
      details.localPosition = target._local(details.globalPosition, details);
      target._deliver(details);
    }
  }

  /// 保存指针请求焦点时的坐标。
  void _rememberFocusPosition(Offset global, Offset local) {
    _position = global;
    _focusPosition = local;
  }

  /// 沿当前渲染祖先链派发焦点变化。
  void _notifyFocusChanged(
    bool focused, {
    ElFocusReason reason = .programmatic,
    Offset? globalPosition,
    Offset? localPosition,
  }) {
    if (_disposed) return;
    if (!focused) _releaseKeys();
    if (globalPosition != null) _position = globalPosition;
    _bubbleUp(
      ElEventDetails(
        phase: focused ? .focus : .blur,
        globalPosition: _position,
        localPosition: localPosition ?? _focusPosition ?? _local(_position),
        focusReason: reason,
      ),
    );
    if (focused) _focusPosition = null;
  }

  /// 转发键盘事件，记录激活键的按下与释放，并按 keyRepeatInterval 限流重复键。
  ElEventDetails? _notifyKeyEvent(KeyEvent event) {
    if (!_live || !_render.attached) return null;
    final key = event.physicalKey;
    final logical = event.logicalKey;
    final wasPressed = isTapPressed;
    var matched = _keyboard?.held?.containsKey(key) ?? false;
    ElEventPhase? tapPhase;
    if (event is KeyDownEvent) {
      if (logical == LogicalKeyboardKey.escape) {
        matched = _keyboard?.held?.values.any((down) => down.logicalKey == LogicalKeyboardKey.space) ?? false;
        _releaseKeys();
      } else if (!matched &&
          (logical == LogicalKeyboardKey.space ||
              logical == LogicalKeyboardKey.enter ||
              logical == LogicalKeyboardKey.numpadEnter)) {
        (_ensureKeyboard().held ??= {})[key] = event;
        tapPhase = .tapDown;
      }
    } else if (event is KeyUpEvent && _keyboard?.held?.remove(key) != null) {
      tapPhase = .tapUp;
    }
    if (tapPhase != null) {
      if (wasPressed != isTapPressed) onTapChanged?.call(isTapPressed);
      _invoke(_key(tapPhase, event));
    }
    if (!_live || !_render.attached) return null;
    final phase = switch (event) {
      KeyDownEvent() => ElEventPhase.keyDown,
      KeyRepeatEvent() => ElEventPhase.keyRepeat,
      _ => ElEventPhase.keyUp,
    };
    final details = _key(phase, event)..keyboardTapMatched = matched;
    _bubbleUp(details);
    _pruneKeyboard();
    return details;
  }

  ElEventDetails _key(ElEventPhase phase, KeyEvent event) =>
      ElEventDetails(phase: phase, originalEvent: event, globalPosition: _position, localPosition: _local(_position));

  void _releaseKeys() {
    final state = _keyboard;
    if (state == null) return;
    final held = state.held?.values.toList();
    _keyboard = null;
    state.clock?.stop();
    if (held == null || held.isEmpty) return;
    onTapChanged?.call(isTapPressed);
    for (final event in held) {
      _invoke(_key(.tapCancel, event));
    }
  }
}

/// 激活键和重复键分开创建记录，纯指针点击不会分配键盘状态。
final class _KeyboardState {
  _KeyboardState() {
    assert(() {
      BenchmarkProbe.eventKeyboardStateInstantiateCount++;
      return true;
    }());
  }
  Map<PhysicalKeyboardKey, KeyDownEvent>? held;
  Map<PhysicalKeyboardKey, (Duration, bool, bool)>? repeats;
  Stopwatch? clock;
}
