import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../utils/internal/benchmark_probe.dart';
import 'details.dart' show EventDetailsAccess;
import 'drag_pointer_lock.dart';
import 'event.dart';

/// 基于原始指针实现 ElEvent。
///
/// 一次按下命中的宿主由内向外组成一条 [_Route]。点击、连击、长按、拖拽和缩放都沿路线默认冒泡，
/// 回调调用 stopPropagation 即可截断外层；在按下阶段截断时，外层不再参与本次手势。
/// 路线以一个竞技场成员与 Flutter 手势协作：拖拽、缩放或长按开始时认领指针，官方手势胜出时取消本路线。
class EventDispatcher {
  /// 为宿主注册事件入口。
  EventDispatcher(this._render) {
    _hosts[_render] = this;
    assert(() {
      BenchmarkProbe.eventDispatcherInstantiateCount++;
      return true;
    }());
  }

  static final _hosts = Expando<EventDispatcher>('ElEvent host');
  static final _raw = Expando<ElEventDetails>('ElEvent input');
  static final _routes = <int, _Route>{};

  final RenderBox _render;
  ElEvent? _event;
  bool _disposed = false;
  Offset _position = Offset.zero;
  Offset? _focusPosition;

  // 连击：计数、上次点击位置、连击窗口与等待窗口结束的延后单击。
  int _tapCount = 0;
  Offset? _tapPosition;
  Timer? _tapWindow;
  VoidCallback? _deferred;

  // 按压反馈：_pressed 为按下的指针，_shown 为当前是否显示反馈。
  int? _pressed;
  bool _shown = false, _pressTouch = false;
  Timer? _pressTimer, _holdTimer;
  final _keys = <PhysicalKeyboardKey, KeyDownEvent>{};
  // 键盘重复限流：本节点每个物理键上次实际回调的时刻，以及当时的消费与停止冒泡结果。
  final _keyRepeats = <PhysicalKeyboardKey, (Duration, bool, bool)>{};
  Stopwatch? _keyClock;

  // 拖拽与缩放。
  _Drag? _drag;
  // 缩放：触点、最近一次重定的基线、累计值，以及最近一段对数缩放速度（时刻、速度、焦点）。
  final _points = <int, Offset>{};
  bool _scaling = false;
  double _span0 = 0, _angle0 = 0, _scale0 = 1, _rotation0 = 0, _scale = 1, _rotation = 0;
  Offset _focal = Offset.zero, _focal0 = Offset.zero;
  Duration _scaleTime = Duration.zero;
  (Duration, double, Offset)? _logScale;

  /// 向宿主同步按压样式。
  ValueChanged<bool>? onTapChanged;

  /// 特殊绘制宿主可调整事件的局部坐标。
  Offset Function(RenderBox, Offset, ElEventDetails?)? localPositionResolver;

  /// 宿主的点击边界（圆角、裁剪与变换），默认使用布局盒。
  bool Function(Offset global)? hitBoundsContainsGlobal;

  /// 获取对应 RenderBox 的事件入口。
  static EventDispatcher? of(RenderObject render) => _hosts[render];

  /// 结清关闭或禁用的子树里的事件。
  static void terminateActivePointerSequencesIn(RenderObject root) {
    root.visitChildren(terminateActivePointerSequencesIn);
    of(root)?.cancelAllPendingAtLastPosition();
  }

  /// 读取按下路径上对焦点默认动作的保留标记。
  static bool preservesFocus(PointerDownEvent input) => _raw[input.original ?? input]?.focusPreserved ?? false;

  /// 测试结束后清理残留指针。
  @visibleForTesting
  static void debugReset() {
    for (final route in _routes.values.toList()) {
      route.cancel(.external);
      route.close();
    }
  }

  /// 当前事件声明，闭包变化不影响进行中的手势。
  ElEvent? get event => _event;
  set event(ElEvent? value) {
    final old = _event;
    if (_disposed || identical(old, value)) return;
    final reshaped = old != null && value != null && !old.sameShape(value);
    if (value?.disabled == true && old?.disabled != true) {
      terminateActivePointerSequencesIn(_render);
    } else if (value == null) {
      cancelAllPendingAtLastPosition();
    } else if (_drag case final drag? when reshaped) {
      // 回调结构变化：新声明接得住的拖拽继续；接不住或指针已在结束时，由旧回调取消。
      final accepted = drag.axis == null ? value.hasPanCallback : value.acceptsDrag(drag.axis!);
      if (!accepted || drag.route._ended) _endDrag(drag.route.last, null, .external);
    }
    _event = value;
    if (reshaped) {
      for (final route in _myRoutes) {
        route.reseed(this);
      }
    }
    if (_render.attached &&
        (old?.cursor != value?.cursor ||
            old?.behavior != value?.behavior ||
            old?.disabled != value?.disabled ||
            (old?.onPointerEnter == null) != (value?.onPointerEnter == null) ||
            (old?.onPointerExit == null) != (value?.onPointerExit == null))) {
      RendererBinding.instance.ensureVisualUpdate();
    }
  }

  /// 当前是否禁用。
  bool get disabled => _event?.disabled == true;

  /// 指针或键盘是否处于按压状态。
  bool get isTapPressed => _shown || _keys.isNotEmpty;

  /// 当前按在本节点上的指针数量。
  int get activePointerCount => _routes.values
      .where((route) => route.down is PointerDownEvent && !route._ended && route.hosts.contains(this))
      .length;

  bool get _live => !_disposed && !disabled;

  List<_Route> get _myRoutes => _routes.values.where((route) => route.hosts.contains(this)).toList();

  ElEvent get _e => _event ?? const ElEvent();

  /// 刷新渲染宿主注册。
  void attach() => _hosts[_render] = this;

  /// 离树时结束输入，临时重挂沿用原宿主。
  void detach({bool preserveEvent = false}) {
    if (!preserveEvent) dispose();
  }

  /// 是否具有自身命中回调。
  bool hitTestSelf(Offset position) => _event?.hasAnyCallback == true;

  /// 按 Flutter 命中顺序接收原始输入。
  void handleEvent(PointerEvent input, HitTestEntry entry) {
    if (!_live) return;
    final phase = switch (input) {
      PointerDownEvent() => ElEventPhase.pointerDown,
      PointerMoveEvent() => ElEventPhase.pointerMove,
      PointerUpEvent() => ElEventPhase.pointerUp,
      PointerCancelEvent() || PointerRemovedEvent() => ElEventPhase.pointerCancel,
      PointerPanZoomStartEvent() => ElEventPhase.pointerPanZoomStart,
      PointerPanZoomUpdateEvent() => ElEventPhase.pointerPanZoomUpdate,
      PointerPanZoomEndEvent() => ElEventPhase.pointerPanZoomEnd,
      PointerHoverEvent() => ElEventPhase.pointerHover,
      PointerSignalEvent() => ElEventPhase.pointerSignal,
      _ => null,
    };
    if (phase == null) return;
    final original = input.original ?? input;
    final previous = _raw[original];
    if (previous?.propagationStopped == true) return;
    if (input is PointerDownEvent || input is PointerPanZoomStartEvent) {
      _Route.join(original, this);
    } else if (input is! PointerHoverEvent && input is! PointerSignalEvent) {
      final route = _routes[input.pointer];
      if (route == null || !route.hosts.contains(this)) return;
      route.last = input;
    }
    _position = _pointerPosition(input);
    final details = _pointer(phase, input, position: _position);
    if (previous != null) {
      if (previous.focusPreserved) details.preserveFocus();
      details.remainingDelta = previous.remainingDelta;
      details.remainingLocalDelta = _localDelta(_position, previous.remainingDelta, input);
    }
    _raw[original] = details;
    _invoke(details);
    // 原始回调可能已移除或替换事件，仍在路线上才点亮按压反馈。
    if (input is PointerDownEvent && _live && _routes[input.pointer]?.hosts.contains(this) == true) _press(input);
    if (input is PointerSignalEvent &&
        (details.defaultPrevented || details.delta != Offset.zero && details.remainingDelta == Offset.zero)) {
      GestureBinding.instance.pointerSignalResolver.register(
        input,
        (event) => event.respond(allowPlatformDefault: false),
      );
    }
  }

  /// 交付鼠标进入事件。
  void handlePointerEnter(PointerEnterEvent event) => _invoke(_pointer(.pointerEnter, event));

  /// 交付鼠标离开事件。
  void handlePointerExit(PointerExitEvent event) => _invoke(_pointer(.pointerExit, event));

  static (ElEventPhase, ElEventPhase, ElEventPhase)? _tapPhases(int buttons) => switch (buttons) {
    kPrimaryButton => (.tapDown, .tapUp, .tap),
    kSecondaryButton => (.secondaryTapDown, .secondaryTapUp, .secondaryTap),
    kTertiaryButton => (.tertiaryTapDown, .tertiaryTapUp, .tertiaryTap),
    kForwardMouseButton => (.forwardTapDown, .forwardTapUp, .forwardTap),
    kBackMouseButton => (.backTapDown, .backTapUp, .backTap),
    _ => null,
  };

  bool _wantsTap(int buttons) {
    final event = _e;
    final phases = _tapPhases(buttons);
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

  /// 主键按下时累计连击：窗口内且距离足够近才递增，远处按下先结算延后的单击。
  void _countTap(PointerDownEvent down) {
    final close = _tapWindow?.isActive == true && (down.position - _tapPosition!).distance <= kDoubleTapSlop;
    _tapWindow?.cancel();
    final pending = _deferred;
    _deferred = null;
    if (!close) pending?.call();
    _tapCount = close && _tapCount < _maxTaps ? _tapCount + 1 : 1;
  }

  /// 确认点击后打开连击窗口，窗口结束时派发延后的单击。
  void _confirmTap(PointerUpEvent up) {
    _tapPosition = up.position;
    if (_tapCount >= _maxTaps) return _resetTaps();
    _tapWindow = Timer(_e.doubleTapInterval, () {
      _tapCount = 0;
      final pending = _deferred;
      _deferred = null;
      pending?.call();
    });
  }

  void _resetTaps() {
    _tapWindow?.cancel();
    _tapWindow = null;
    _tapCount = 0;
    _deferred = null;
  }

  bool _contains(Offset global) {
    if (!_render.attached || !_render.hasSize) return true;
    return hitBoundsContainsGlobal?.call(global) ??
        (Offset.zero & _render.size).contains(_render.globalToLocal(global));
  }

  void _press(PointerDownEvent down) {
    if (_pressed != null || down.buttons != kPrimaryButton) return;
    _pressed = down.pointer;
    _pressTouch = down.kind == PointerDeviceKind.touch;
    _pressTimer?.cancel();
    _holdTimer?.cancel();
    final delay = _pressTouch ? _e.delayTouchDown : Duration.zero;
    _pressTimer = delay > Duration.zero ? Timer(delay, () => _show(true)) : null;
    if (_pressTimer == null) _show(true);
    final hold = _pressTouch ? _e.delayTouchUp : Duration.zero;
    _holdTimer = hold > Duration.zero ? Timer(hold, () => _pressed == null ? _show(false) : null) : null;
  }

  /// 结束按压反馈；触摸确认点击时从按下起至少保持 delayTouchUp，未亮起的轻触不补播。
  void _release({bool tapped = false}) {
    if (_pressed == null) return;
    _pressed = null;
    _pressTimer?.cancel();
    if (tapped && _shown && _holdTimer?.isActive == true) return;
    _holdTimer?.cancel();
    _show(false);
  }

  void _show(bool value) {
    if (_shown == value) return;
    _shown = value;
    onTapChanged?.call(isTapPressed);
  }

  void _startDrag(_Route route, Axis? axis, PointerEvent input) {
    final moved = route.position - _pointerPosition(route.down);
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
    drag.position = _pointerPosition(input);
    drag.offset += drag.project(delta);
    final details = _dragDetails(.dragUpdate, input, delta: delta, remaining: previous?.remainingDelta ?? delta);
    _invoke(details);
    if (details.propagationStopped) drag.route.exclusive(this);
    return details;
  }

  /// 结束拖拽；velocity 为 null 表示取消。
  void _endDrag(PointerEvent input, Offset? velocity, [ElEventCancelReason? reason]) {
    final drag = _drag;
    if (drag == null) return;
    _drag = null;
    // 松手点与最后一次移动不同时，这段位移计入 dragEnd 的累计偏移。
    if (velocity != null && input is PointerUpEvent) {
      drag.offset += drag.project(input.position - drag.position);
      drag.position = input.position;
    }
    final phase = velocity == null ? ElEventPhase.dragCancel : ElEventPhase.dragEnd;
    final details = _dragDetails(phase, input, drag: drag, velocity: velocity ?? Offset.zero, reason: reason);
    _invoke(details, drag: drag);
  }

  ElEventDetails _dragDetails(
    ElEventPhase phase,
    PointerEvent input, {
    _Drag? drag,
    Offset delta = Offset.zero,
    Offset? remaining,
    Offset velocity = Offset.zero,
    ElEventCancelReason? reason,
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
      localPosition: _local(position, input),
      delta: own,
      localDelta: _localDelta(position, own, input),
      remainingDelta: rest,
      remainingLocalDelta: _localDelta(position, rest, input),
      dragOffset: drag.offset,
      dragAxis: drag.axis,
      dragDirection: drag.direction,
      velocity: Velocity(pixelsPerSecond: v),
      primaryVelocity: drag.axis == null ? null : (drag.axis == Axis.horizontal ? v.dx : v.dy),
      buttons: input.buttons,
      pointerCount: activePointerCount,
      cancelReason: reason,
    )..resolveLocalDelta((value) => _localDelta(position, value, input));
  }

  /// 触点的焦点、平均半径与前两指连线角度。
  (Offset, double, double) _shape() {
    final points = _points.values.toList();
    final focal = points.fold(Offset.zero, (sum, point) => sum + point) / points.length.toDouble();
    final span = points.fold(0.0, (sum, point) => sum + (point - focal).distance) / points.length;
    return (focal, span, points.length < 2 ? 0 : (points[1] - points[0]).direction);
  }

  /// 触点增减时重定基线，缩放与旋转从当前累计值续算。
  void _rebase() {
    final (focal, span, angle) = _shape();
    _focal = _focal0 = focal;
    _span0 = span;
    _angle0 = angle;
    _scale0 = _scale;
    _rotation0 = _rotation;
  }

  /// 开始缩放：认领参与的指针并取消其上的点击；双指捏合或停止传播时独占这些指针。
  void _startScale(PointerEvent input) {
    _scaling = true;
    _scale = 1;
    _rotation = 0;
    _logScale = null;
    _scaleTime = input.timeStamp;
    _rebase();
    _endDrag(input, null);
    _release();
    final routes = _routes.values.where((route) => route.scales.contains(this)).toList();
    for (final route in routes) {
      route
        ..claim()
        .._cancelTaps(.selfGestureAccepted);
    }
    final details = _scaleDetails(.scaleStart, input);
    _invoke(details);
    if (details.propagationStopped || _points.length > 1) {
      for (final route in routes) {
        route.exclusive(this);
      }
    }
  }

  /// 触点移动：未开始时跨度或焦点越过阈值才起步；silent 时只更新状态。返回是否停止传播。
  bool _moveScale(PointerEvent input, bool silent, double slop) {
    final (focal, span, angle) = _shape();
    if (!_scaling) {
      final kind = input.kind;
      final moved = (focal - _focal0).distance;
      if (input is PointerPanZoomUpdateEvent ||
          (_points.length == 1
              ? !_e.hasDragCallback && moved > slop
              : (span - _span0).abs() > computeScaleSlop(kind) || moved > computePanSlop(kind, null))) {
        _startScale(input);
      }
      return false;
    }
    final (last, scale, rotation) = (_focal, _scale, _rotation);
    _focal = focal;
    if (input is PointerPanZoomUpdateEvent) {
      _scale = input.scale;
      _rotation = input.rotation;
    } else if (_points.length > 1) {
      _scale = _scale0 * (_span0 > 0 ? span / _span0 : 1);
      // 取最短角差，跨越 ±π 时保持连续。
      _rotation = _rotation0 + (angle - _angle0 + math.pi) % (2 * math.pi) - math.pi;
    }
    final elapsed = (input.timeStamp - _scaleTime).inMicroseconds / Duration.microsecondsPerSecond;
    _scaleTime = input.timeStamp;
    _logScale = _points.length > 1 && span > 0 && elapsed > 0
        ? (input.timeStamp, math.log(_scale / scale) / elapsed, focal)
        : null;
    if (silent) return true;
    final details = _scaleDetails(.scaleUpdate, input, delta: _focal - last);
    _invoke(details);
    if (_rotation != rotation && !details.propagationStopped) {
      _invoke(_scaleDetails(.rotationUpdate, input, delta: _focal - last));
    }
    return details.propagationStopped;
  }

  /// 结束缩放；velocity 为 null 表示取消。最近 80ms 内的双指段提供对数缩放速度与其焦点。
  void _endScale(PointerEvent input, Offset? velocity, [ElEventCancelReason? reason]) {
    if (!_scaling) return;
    _scaling = false;
    final log = _logScale;
    _logScale = null;
    final fresh = velocity != null && log != null && input.timeStamp - log.$1 <= const Duration(milliseconds: 80);
    if (fresh) _focal = log.$3;
    final phase = velocity == null ? ElEventPhase.scaleCancel : ElEventPhase.scaleEnd;
    _invoke(
      _scaleDetails(phase, input, velocity: velocity ?? Offset.zero, logScale: fresh ? log.$2 : 0, reason: reason),
    );
  }

  ElEventDetails _scaleDetails(
    ElEventPhase phase,
    PointerEvent input, {
    Offset delta = Offset.zero,
    Offset velocity = Offset.zero,
    double logScale = 0,
    ElEventCancelReason? reason,
  }) => ElEventDetails(
    phase: phase,
    originalEvent: input,
    globalPosition: _focal,
    localPosition: _local(_focal, input),
    delta: delta,
    localDelta: _localDelta(_focal, delta, input),
    pointerCount: _points.length,
    scale: _scale,
    rotation: _rotation,
    buttons: input.buttons,
    velocity: Velocity(pixelsPerSecond: velocity),
    logScaleVelocity: logScale,
    cancelReason: reason,
  );

  static Offset _pointerPosition(PointerEvent input) =>
      input is PointerPanZoomUpdateEvent ? input.position + input.pan : input.position;

  ElEventDetails _pointer(
    ElEventPhase phase,
    PointerEvent input, {
    Offset? position,
    int? buttons,
    int count = 0,
    ElEventCancelReason? reason,
  }) {
    final global = position ?? _pointerPosition(input);
    final delta = switch (input) {
      PointerScrollEvent() => input.scrollDelta,
      PointerPanZoomUpdateEvent() => input.panDelta,
      _ => input.delta,
    };
    return ElEventDetails(
      phase: phase,
      originalEvent: input,
      globalPosition: global,
      localPosition: _local(global, input),
      delta: delta,
      localDelta: _localDelta(global, delta, input),
      buttons: buttons ?? input.buttons,
      tapCount: count,
      pointerCount: activePointerCount,
      cancelReason: reason,
      scale: input is PointerPanZoomUpdateEvent ? input.scale : 1,
      rotation: input is PointerPanZoomUpdateEvent ? input.rotation : 0,
    )..resolveLocalDelta((value) => _localDelta(global, value, input));
  }

  Offset _local(Offset position, [PointerEvent? input, ElEventDetails? details]) {
    if (!_render.attached) return details?.localPosition ?? position;
    return localPositionResolver?.call(_render, position, details) ??
        (input == null ? _render.globalToLocal(position) : PointerEvent.transformPosition(input.transform, position));
  }

  Offset _localDelta(Offset end, Offset delta, PointerEvent input) =>
      delta == Offset.zero ? Offset.zero : _local(end, input) - _local(end - delta, input);

  void _invoke(ElEventDetails details, {_Drag? drag}) {
    if (_disposed) return;
    final phase = details.phase;
    final axis = ElEventPhase.dragPhases.contains(phase) ? (drag ?? _drag)?.axis : null;
    final handler = _handler(phase, axis);
    if (handler == null) return;
    try {
      handler(details);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ElEvent'));
    }
  }

  ElEventHandler? _handler(ElEventPhase phase, [Axis? axis]) =>
      _event?.handlerFor(phase, axis) ?? (phase == .keyRepeat ? _event?.onKeyDown : null);

  /// 每个节点按自己的 keyRepeatInterval 丢弃过密的重复键，被丢弃时沿用上次的消费与停止冒泡结果。
  void _deliver(ElEventDetails details) {
    final phase = details.phase, key = details.physicalKey, interval = _e.keyRepeatInterval;
    if (phase == .blur || phase == .keyDown && details.logicalKey == LogicalKeyboardKey.escape) _keyRepeats.clear();
    if (key == null || phase != .keyDown && phase != .keyRepeat || _handler(phase) == null || interval == .zero) {
      if (key != null) _keyRepeats.remove(key);
      return _invoke(details);
    }
    // 采样时钟在测试中随虚拟时间推进。
    final now = (_keyClock ??= GestureBinding.instance.samplingClock.stopwatch()..start()).elapsed;
    final last = _keyRepeats[key];
    if (phase == .keyRepeat && last != null && now - last.$1 < interval) {
      if (last.$2) details.preventDefault();
      if (last.$3) details.stopPropagation();
      return;
    }
    _keyRepeats[key] = (now, false, false);
    _invoke(details);
    if (_keyRepeats.containsKey(key)) _keyRepeats[key] = (now, details.defaultPrevented, details.propagationStopped);
  }

  /// 沿渲染祖先链冒泡，用于键盘与焦点。
  void _bubbleUp(ElEventDetails details) {
    _deliver(details);
    for (var render = _render.parent; render != null && !details.propagationStopped; render = render.parent) {
      final target = _hosts[render];
      if (target == null || !render.attached || !target._live) continue;
      details.keyboardTapMatched = false;
      details.localPosition = target._local(details.globalPosition, null, details);
      target._deliver(details);
    }
  }

  /// 保存指针请求焦点时的坐标。
  void rememberFocusPosition(Offset global, Offset local) {
    _position = global;
    _focusPosition = local;
  }

  /// 沿当前渲染祖先链派发焦点变化。
  void notifyFocusChanged(
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
  ElEventDetails? notifyKeyEvent(KeyEvent event) {
    if (!_live || !_render.attached) return null;
    final key = event.physicalKey;
    final logical = event.logicalKey;
    final wasPressed = isTapPressed;
    var matched = _keys.containsKey(key);
    ElEventPhase? tapPhase;
    if (event is KeyDownEvent) {
      if (logical == LogicalKeyboardKey.escape) {
        matched = _keys.values.any((down) => down.logicalKey == LogicalKeyboardKey.space);
        _releaseKeys();
      } else if (!matched &&
          (logical == LogicalKeyboardKey.space ||
              logical == LogicalKeyboardKey.enter ||
              logical == LogicalKeyboardKey.numpadEnter)) {
        _keys[key] = event;
        tapPhase = .tapDown;
      }
    } else if (event is KeyUpEvent && _keys.remove(key) != null) {
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
    return details;
  }

  ElEventDetails _key(ElEventPhase phase, KeyEvent event) =>
      ElEventDetails(phase: phase, originalEvent: event, globalPosition: _position, localPosition: _local(_position));

  void _releaseKeys() {
    _keyRepeats.clear();
    if (_keys.isEmpty) return;
    final held = _keys.values.toList();
    _keys.clear();
    onTapChanged?.call(isTapPressed);
    for (final event in held) {
      _invoke(_key(.tapCancel, event));
    }
  }

  /// 结束宿主跟踪的输入和反馈。
  void cancelAllPendingAtLastPosition() {
    for (final route in _myRoutes) {
      route.leave(this);
    }
    _resetTaps();
    _release();
    _holdTimer?.cancel();
    _show(false);
    _releaseKeys();
    DragPointerLock.release(_render);
  }

  /// 释放宿主注册。
  void dispose() {
    if (_disposed) return;
    cancelAllPendingAtLastPosition();
    _disposed = true;
    if (identical(_hosts[_render], this)) _hosts[_render] = null;
    _event = null;
    onTapChanged = null;
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

/// 一个指针从按下到抬起的路线：命中宿主由内向外排列，统一处理派生手势并作为竞技场成员。
final class _Route extends GestureArenaMember {
  _Route(this.down) : last = down, _lastPosition = EventDispatcher._pointerPosition(down);

  final PointerEvent down;
  PointerEvent last;
  Offset _lastPosition;
  late final tracker = VelocityTracker.withKind(down.kind);
  final hosts = <EventDispatcher>[];
  // pressed 收到 tapDown、松手时收到 tapUp；taps 仍有资格触发 tap；_outside 暂时移出点击边界。
  var pressed = <EventDispatcher>[];
  var taps = <EventDispatcher>[];
  var drags = <EventDispatcher>[];
  var scales = <EventDispatcher>[];
  final _outside = <EventDispatcher>{};
  GestureArenaEntry? _entry;
  bool _accepted = false, _rejected = false, _closed = false, _begun = false;
  PointerUpEvent? _pendingUp;
  Axis? _axis;
  Timer? _longPress;

  int get pointer => down.pointer;
  Offset get position => EventDispatcher._pointerPosition(last);
  Offset get moved => position - EventDispatcher._pointerPosition(down);
  bool get _primary => down is PointerDownEvent && down.buttons == kPrimaryButton;
  bool get _ended => last is PointerUpEvent || last is PointerCancelEvent || last is PointerPanZoomEndEvent;
  Iterable<EventDispatcher> get _dragging => hosts.where((host) => host._drag?.route == this);
  (ElEventPhase, ElEventPhase, ElEventPhase) get _phases => EventDispatcher._tapPhases(down.buttons)!;

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
        cancel(.pointerCanceled);
        close();
    }
  }

  void _begin() {
    final live = hosts.where((host) => host._live).toList();
    final input = down;
    final transform = live.where((host) => host._canTransform(input)).toList();
    drags = transform.where((host) => host._e.hasDragCallback || host._e.onDragDown != null).toList();
    final stop = _bubble(drags, .dragDown, (host) => host._pointer(.dragDown, input));
    if (stop >= 0) drags = drags.sublist(0, stop + 1);
    drags.removeWhere((host) => !host._e.hasDragCallback);
    // 拖拽中落下新手指：与 Flutter 一致，由最新的手指继续驱动。
    for (final host in drags.where((host) => host._drag != null && !host._e.hasScaleCallback).toList()) {
      drags.remove(host);
      host._drag!.route = this;
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
        final owner = taps.where((host) => host._e.onLongPress != null).firstOrNull;
        if (owner != null) _longPress = Timer(owner._e.longPressDelay, _fireLongPress);
      }
    }
    scales = transform.where((host) => host._e.hasScaleCallback).toList();
    for (final host in scales) {
      host._points[pointer] = position;
      host._rebase();
      if (host._scaling) claim();
    }
    _track(down);
    _begun = true;
  }

  void _move(PointerEvent event) {
    // 鼠标按键组合变化时结束本次点击与拖拽。
    if (down is PointerDownEvent && event.buttons != down.buttons) return cancel(.tapRejected);
    final slop = computeHitSlop(down.kind, null);
    final distance = moved.distance;
    if (distance > slop) {
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
      if (inside != _outside.contains(host)) continue;
      inside ? _outside.remove(host) : _outside.add(host);
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
    for (final host in _dragging.toList()) {
      previous = host._updateDrag(event, delta, previous);
      if (previous.propagationStopped) break;
    }

    var stopped = false;
    for (final host in scales.toList()) {
      if (!host._live) continue;
      host._points[pointer] = position;
      stopped = host._moveScale(event, stopped, slop) || stopped;
    }

    _startDrags(event, distance, slop);
    if (pressed.isEmpty && drags.isEmpty && scales.isEmpty && _dragging.isEmpty) _resolve(.rejected);
  }

  /// 越过起拖距离的候选开始拖拽。轴向候选等主方向落在自己的轴上，首个开始者锁定轴向，
  /// 同轴其余候选随即开始；同时声明两轴时横向需越过更长的 pan slop，避免误触横滚。
  void _startDrags(PointerEvent event, double distance, double slop) {
    final dominant = moved.dx.abs() >= moved.dy.abs() ? Axis.horizontal : Axis.vertical;
    final locked = _axis;
    for (final host in drags.toList()) {
      if (!drags.contains(host)) continue;
      if (!host._live || host._scaling || host._drag != null) {
        drags.remove(host);
        continue;
      }
      final e = host._e;
      final axis = e.hasPanCallback ? null : locked ?? dominant;
      if (axis != null && !e.acceptsDrag(axis)) continue;
      final both = e.acceptsDrag(.horizontal) && e.acceptsDrag(.vertical);
      final pan = axis == null || both && axis == .horizontal;
      final start = e.dragStartDistance ?? (pan ? computePanSlop(down.kind, null) : slop);
      if (distance <= start && (axis == null || locked == null)) continue;
      drags.remove(host);
      _axis ??= axis;
      _longPress?.cancel();
      claim();
      host._startDrag(this, axis, event);
    }
    if (locked == null && _axis != null) _startDrags(event, distance, slop);
  }

  void _end(PointerEvent event) {
    _longPress?.cancel();
    final velocity = _velocity(sparse: true);
    for (final host in _dragging.toList()) {
      // 其他手指仍按在该节点上时由最新的一根接管拖拽，不结束。
      final next = EventDispatcher._routes.values
          .where((route) => route != this && !route._ended && route.hosts.contains(host))
          .lastOrNull;
      if (next != null && host._canTransform(next.down) && !host._e.hasScaleCallback) {
        host._drag!.route = next;
        next.drags.remove(host);
        next.claim();
      } else {
        host._endDrag(event, velocity);
      }
    }
    for (final host in hosts.toList()) {
      // 点击候选与纯样式宿主原地松手时保留触摸反馈，被取消的点击已在取消时结束反馈。
      final tapped =
          event is PointerUpEvent && !_outside.contains(host) && (taps.contains(host) || !host._wantsGesture);
      if (host._pressed == pointer) host._release(tapped: tapped);
    }
    if (event is PointerUpEvent && pressed.isNotEmpty) {
      // tapUp 对应真实松手；tap 还要求点击资格仍在。
      final stop = _bubble(pressed, _phases.$2, (host) => host._pointer(_phases.$2, event, buttons: down.buttons));
      if (stop >= 0) taps.removeWhere((host) => pressed.indexOf(host) > stop);
      taps.removeWhere(_outside.contains);
      if (!_flung(event, velocity) && taps.isNotEmpty) {
        _entry == null || _accepted ? _fireTap(event) : _pendingUp = event;
      }
    }
    for (final host in scales.toList()) {
      if (host._points.remove(pointer) == null) continue;
      host._points.isEmpty ? host._endScale(event, _velocity()) : host._rebase();
    }
    scales = [];
  }

  /// 只有拖拽与缩放需要速度，纯点击路线不采样。
  bool get _tracking => drags.isNotEmpty || scales.isNotEmpty || _dragging.isNotEmpty;

  void _track(PointerEvent event) {
    if (_tracking) tracker.addPosition(event.timeStamp, position);
  }

  /// 采样不足的稀疏拖拽按按下到松手的两倍均速估计末速度，避免短促轻扫丢失。
  Offset _velocity({bool sparse = false}) {
    if (!_tracking) return Offset.zero;
    var speed = tracker.getVelocityEstimate()?.pixelsPerSecond ?? Offset.zero;
    final elapsed = (last.timeStamp - down.timeStamp).inMicroseconds;
    if (sparse && speed == Offset.zero && elapsed > 0) speed = moved * (2 * Duration.microsecondsPerSecond / elapsed);
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
      _bubble(hosts, phase, (host) => host._pointer(phase, up, buttons: down.buttons, count: count));
    }
  }

  void _fireLongPress() {
    _longPress = null;
    final owners = taps.where((host) => host._live && host._e.onLongPress != null && !_outside.contains(host)).toList();
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
    if (_primary && !_outside.contains(host)) host._invoke(host._pointer(.tapCancel, last, reason: reason));
  }

  void _cancelTaps(ElEventCancelReason reason) {
    _longPress?.cancel();
    for (final host in taps.toList()) {
      _cancelTap(host, reason);
    }
  }

  /// 节点在起拖、缩放或长按时停止了传播：独占本路线，其余节点退出，自身点击取消但保留 tapUp。
  void exclusive(EventDispatcher owner) {
    claim();
    _cancelTaps(.selfGestureAccepted);
    drags.removeWhere((host) => host != owner);
    for (final host in hosts.where((host) => host != owner).toList()) {
      pressed.remove(host);
      if (host._drag?.route == this) host._endDrag(last, null, .otherGestureAccepted);
      if (scales.remove(host) && host._points.remove(pointer) != null) {
        host._endScale(last, null, .otherGestureAccepted);
      }
    }
  }

  /// 取消本路线的全部派生手势，宿主仍接收原始事件。
  void cancel(ElEventCancelReason reason) {
    _pendingUp = null;
    drags.clear();
    for (final host in hosts.toList()) {
      if (host._drag?.route == this) host._endDrag(last, null, reason);
    }
    for (final host in scales.toList()) {
      if (host._points.remove(pointer) != null) host._endScale(last, null, reason);
    }
    scales = [];
    _cancelTaps(reason);
    pressed = [];
    for (final host in hosts.toList()) {
      if (host._pressed == pointer) host._release();
    }
  }

  /// 宿主不再参与本路线的派生手势，仍接收原始事件。
  void drop(EventDispatcher host) {
    _cancelTap(host, .external);
    pressed.remove(host);
    drags.remove(host);
    if (host._drag?.route == this) host._endDrag(last, null, .external);
    if (scales.remove(host) && host._points.remove(pointer) != null) host._endScale(last, null, .external);
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
    drags = sync(drags, host._drag == null && host._canTransform(input) && host._e.hasDragCallback);
    if (_rejected || EventDispatcher._tapPhases(input.buttons) == null) return;
    final tap = host._wantsTap(input.buttons);
    if (!tap) taps.remove(host);
    if (tap && !pressed.contains(host)) {
      taps = sync(taps, true);
      pressed = sync(pressed, true);
    }
  }

  /// 宿主中途退出（卸载、禁用）。
  void leave(EventDispatcher host) {
    drop(host);
    if (!_ended && down is PointerPanZoomStartEvent) {
      final end = PointerPanZoomEndEvent(pointer: pointer, device: down.device, position: position);
      host._invoke(host._pointer(.pointerPanZoomEnd, end));
    } else if (!_ended) {
      final cancel = PointerCancelEvent(pointer: pointer, kind: down.kind, device: down.device, position: position);
      host._invoke(host._pointer(.pointerCancel, cancel, reason: .external));
    }
    hosts.remove(host);
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
    for (var i = 0; i < hosts.length; i++) {
      final host = hosts[i];
      if (!host._live || host._e.handlerFor(phase) == null) continue;
      final details = make(host);
      host._invoke(details);
      if (details.propagationStopped) return i;
    }
    return -1;
  }
}
