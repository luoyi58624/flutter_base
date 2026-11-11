import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../utils/internal/benchmark_probe.dart';
import 'details.dart' show EventDetailsAccess;
import 'event.dart';

part 'gestures.dart';

/// 接入 RenderBox 的原始输入、官方手势和 ElEvent 冒泡。
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
  static final _starts = Expando<_PointerRoute>('ElEvent down');
  static final _rawEvents = Expando<ElEventDetails>('ElEvent input');
  static final _pointers = <int, _PointerRoute>{};
  static bool _watchingRemoval = false;

  final RenderBox _render;
  ElEvent? _event;
  _NativeGestures? _gestures;
  Offset _position = Offset.zero;
  Offset? _focusPosition;
  bool _disposed = false;
  bool _canceling = false;
  PointerDownEvent? _pressed;
  final _keys = <PhysicalKeyboardKey, KeyDownEvent>{};

  /// 向宿主同步按压样式。
  ValueChanged<bool>? onTapChanged;

  /// 特殊绘制宿主可调整事件的局部坐标。
  Offset Function(RenderBox, Offset, ElEventDetails?)? localPositionResolver;

  /// 原生拖拽允许的设备。
  Set<PointerDeviceKind>? dragDevices;

  /// 宿主提供的 Flutter 设备手势设置。
  DeviceGestureSettings? gestureSettings;

  /// 设备直接移除时通知跟踪该指针的组件。
  ValueChanged<PointerRemovedEvent>? onRoutedPointerRemoved;

  /// 获取对应 RenderBox 的事件入口。
  static EventDispatcher? of(RenderObject render) => _hosts[render];

  /// 结清关闭或禁用的子树里的事件。
  static void terminateActivePointerSequencesIn(RenderObject root, {bool force = false}) {
    root.visitChildren((child) => terminateActivePointerSequencesIn(child, force: force));
    of(root)?.cancelAllPendingAtLastPosition();
  }

  /// 测试结束后清理残留指针。
  @visibleForTesting
  static void debugResetEagerGestureOwners() {
    for (final host in _pointers.values.expand((route) => route.members).toSet()) {
      host.cancelAllPendingAtLastPosition();
    }
    _pointers.clear();
    _watchDevices();
  }

  static void _watchDevices() {
    final needed = _pointers.isNotEmpty;
    if (_watchingRemoval == needed) return;
    _watchingRemoval = needed;
    final router = GestureBinding.instance.pointerRouter;
    needed ? router.addGlobalRoute(_deviceRemoved) : router.removeGlobalRoute(_deviceRemoved);
  }

  static void _deviceRemoved(PointerEvent event) {
    if (event is! PointerRemovedEvent) return;
    final matches = _pointers.values.where((route) {
      final down = route.down;
      return !route.ended &&
          (event.pointer != 0 ? event.pointer == down.pointer : event.device == down.device && event.kind == down.kind);
    }).toList();
    if (matches.length != 1) return;
    final route = matches.single;
    _pointers.remove(route.down.pointer);
    for (final host in route.members.toList()) {
      final removed = PointerRemovedEvent(
        pointer: route.down.pointer,
        position: route.last.position,
        kind: event.kind,
        device: event.device,
        timeStamp: event.timeStamp,
        original: event,
      );
      if (host._gestures?.tracks(removed.pointer) == true) host._cancelGestures(removed, .pointerCanceled);
      if (host._pressed?.pointer == removed.pointer) host._releaseFeedback();
      host.onRoutedPointerRemoved?.call(removed);
      host._cancelPointer(route, .pointerCanceled, removed);
    }
    _watchDevices();
  }

  /// 当前配置。
  ElEventConfig get config => _event?.config ?? const ElEventConfig();

  /// 当前是否禁用。
  bool get disabled => _event?.disabled == true;

  /// 是否已销毁。
  bool get isDisposed => _disposed;

  /// 指针或键盘是否处于按压状态。
  bool get isTapPressed => _pressed != null || _keys.isNotEmpty;

  /// 当前普通触点的数量。
  int get activePointerCount => _pointers.values
      .where((route) => !route.ended && route.down is PointerDownEvent && route.members.contains(this))
      .length;

  /// 当前事件声明。同构重建直接更换回调。
  ElEvent? get event => _event;
  set event(ElEvent? value) {
    final old = _event;
    if (_disposed || identical(old, value)) return;
    if (old?.disabled != true && value?.disabled == true) {
      terminateActivePointerSequencesIn(_render, force: true);
    } else if (value == null) {
      cancelAllPendingAtLastPosition();
    } else if (old == null || !old.hasSameGestureShape(value)) {
      _cancelGestures();
      _releaseFeedback();
    }
    if (_disposed || !identical(_event, old)) return;
    _event = value;
    if (_render.attached &&
        (old?.cursor != value?.cursor ||
            old?.behavior != value?.behavior ||
            old?.disabled != value?.disabled ||
            (old?.onPointerEnter == null) != (value?.onPointerEnter == null) ||
            (old?.onPointerExit == null) != (value?.onPointerExit == null))) {
      RendererBinding.instance.ensureVisualUpdate();
    }
  }

  /// 刷新渲染宿主注册。
  void attach() => _hosts[_render] = this;

  /// 离树时结束输入，临时重挂沿用原宿主。
  void detach({bool preserveEvent = false}) {
    if (!preserveEvent) dispose();
  }

  /// 是否具有自身命中回调。
  bool hitTestSelf(Offset position) => _event?.hasAnyCallback == true;

  /// 读取按下路径上对焦点默认动作的保留标记。
  static bool preservesFocus(PointerDownEvent input) => _rawEvents[input.original ?? input]?.focusPreserved ?? false;

  /// 按 Flutter 命中顺序接收原始输入。
  void handleEvent(PointerEvent input, BoxHitTestEntry entry) {
    final original = input.original ?? input;
    final previous = _rawEvents[original];
    if (_disposed || disabled) return;
    final phase = switch (input) {
      PointerDownEvent() => ElEventPhase.pointerDown,
      PointerMoveEvent() => ElEventPhase.pointerMove,
      PointerUpEvent() => ElEventPhase.pointerUp,
      PointerCancelEvent() => ElEventPhase.pointerCancel,
      PointerPanZoomStartEvent() => ElEventPhase.pointerPanZoomStart,
      PointerPanZoomUpdateEvent() => ElEventPhase.pointerPanZoomUpdate,
      PointerPanZoomEndEvent() => ElEventPhase.pointerPanZoomEnd,
      PointerHoverEvent() => ElEventPhase.pointerHover,
      PointerSignalEvent() => ElEventPhase.pointerSignal,
      _ => null,
    };
    if (phase == null) return;
    final start = input is PointerDownEvent || input is PointerPanZoomStartEvent;
    final tracked = input is! PointerHoverEvent && input is! PointerSignalEvent;
    var route = _pointers[input.pointer];
    if (start && (route == null || !identical(route.down, original) || route.ended)) {
      route = _starts[original] = _PointerRoute(original);
    }
    if (tracked && route == null) return;
    if (start) {
      if (previous?.propagationStopped == true || !route!.members.add(this)) return;
      _pointers[input.pointer] = route;
      _watchDevices();
    } else if (tracked) {
      if (!route!.members.contains(this)) return;
      if (!identical(route.last, original)) {
        route.last = original;
        if (route.ended) {
          scheduleMicrotask(() {
            if (identical(_pointers[input.pointer], route)) _pointers.remove(input.pointer);
            _watchDevices();
          });
        }
      }
      _gestures?.observe(input);
    }
    if (input is! PointerPanZoomEndEvent) _position = _pointerPosition(input);
    if (!start) _updateFeedback(input);
    final before = _event;
    final details = _pointer(
      phase,
      input,
      position: _position,
      reason: input is PointerCancelEvent ? .pointerCanceled : null,
    );
    if (previous != null) {
      details.shareControl(previous);
      if (input is PointerSignalEvent && previous.remainingDelta != details.delta) {
        details.remainingDelta = previous.remainingDelta;
        details.remainingLocalDelta = _localDelta(_position, details.remainingDelta, input);
      }
    }
    _rawEvents[original] = details;
    if (previous == null) scheduleMicrotask(() => _rawEvents[original] = null);
    if (!details.propagationStopped) _send(details);
    if (start &&
        !_disposed &&
        !disabled &&
        route!.members.contains(this) &&
        (identical(before, _event) || before != null && _event != null && before.hasSameGestureShape(_event!))) {
      _updateFeedback(input);
      _addGestures(input, route);
    }
    if (input is PointerSignalEvent &&
        (details.defaultPrevented || details.delta != Offset.zero && details.remainingDelta == Offset.zero)) {
      GestureBinding.instance.pointerSignalResolver.register(
        input,
        (event) => event.respond(allowPlatformDefault: false),
      );
    }
  }

  void _addGestures(PointerEvent input, _PointerRoute route) {
    if (_event?.hasAnyCallback != true) return;
    final devices = config.dragDevices ?? dragDevices;
    final transform =
        (devices == null || devices.contains(input.kind)) &&
        (input is PointerPanZoomStartEvent || input.buttons == kPrimaryButton);
    final drag = transform && !route.dragStopped;
    final before = _event;
    if (drag && before?.onDragDown != null) {
      final down = _pointer(.dragDown, input);
      _send(down);
      route.dragStopped = down.propagationStopped;
    }
    if (disabled ||
        _disposed ||
        !route.members.contains(this) ||
        !identical(before, _event) && (before == null || _event == null || !before.hasSameGestureShape(_event!))) {
      return;
    }
    (_gestures ??= _NativeGestures(this)).add(input, drag: drag, scale: transform);
  }

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

  void _send(ElEventDetails details, {Axis? axis, _PointerRoute? route, bool bubble = false}) {
    _invoke(details, axis);
    if (!bubble ||
        details.propagationStopped ||
        _disposed ||
        disabled ||
        route != null && !route.members.contains(this)) {
      return;
    }
    for (var render = _render.parent; render != null; render = render.parent) {
      final target = _hosts[render];
      if (target == null ||
          !render.attached ||
          target._disposed ||
          target.disabled ||
          route != null && !route.members.contains(target)) {
        continue;
      }
      details.keyboardTapMatched = false;
      details.localPosition = target._local(details.globalPosition, null, details);
      target._invoke(details, axis);
      if (details.propagationStopped) break;
    }
  }

  void _invoke(ElEventDetails details, Axis? axis) {
    final phase = details.phase;
    final handler = _event?.handlerFor(phase, axis) ?? (phase == .keyRepeat ? _event?.onKeyDown : null);
    if (handler == null) return;
    try {
      handler(details);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ElEvent'));
    }
  }

  void _updateFeedback(PointerEvent input) {
    if (onTapChanged == null) return;
    final down = _pressed;
    if (down == null && input is PointerDownEvent && input.buttons == kPrimaryButton) {
      _pressed = input;
      onTapChanged?.call(true);
    } else if (down?.pointer == input.pointer &&
        (input is PointerUpEvent ||
            input is PointerCancelEvent ||
            input is PointerMoveEvent &&
                (input.position - down!.position).distance > computeHitSlop(input.kind, gestureSettings))) {
      _releaseFeedback();
    }
  }

  void _releaseFeedback() {
    if (_pressed == null) return;
    _pressed = null;
    onTapChanged?.call(isTapPressed);
  }

  /// 交付鼠标进入事件。
  void handlePointerEnter(PointerEnterEvent event) => _send(_pointer(.pointerEnter, event));

  /// 交付鼠标离开事件。
  void handlePointerExit(PointerExitEvent event) => _send(_pointer(.pointerExit, event));

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
    _send(
      ElEventDetails(
        phase: focused ? .focus : .blur,
        globalPosition: _position,
        localPosition: localPosition ?? _focusPosition ?? _local(_position),
        focusReason: reason,
      ),
      bubble: true,
    );
    if (focused) _focusPosition = null;
  }

  /// 转发键盘事件并记录激活键的按下与释放。
  ElEventDetails? notifyKeyEvent(KeyEvent event) {
    if (_disposed || disabled || !_render.attached) return null;
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
      _send(_key(tapPhase, event));
    }
    if (_disposed || disabled || !_render.attached) return null;
    final phase = switch (event) {
      KeyDownEvent() => ElEventPhase.keyDown,
      KeyRepeatEvent() => ElEventPhase.keyRepeat,
      _ => ElEventPhase.keyUp,
    };
    final details = _key(phase, event)..keyboardTapMatched = matched;
    _send(details, bubble: true);
    return details;
  }

  ElEventDetails _key(ElEventPhase phase, KeyEvent event) =>
      ElEventDetails(phase: phase, originalEvent: event, globalPosition: _position, localPosition: _local(_position));

  void _releaseKeys() {
    if (_keys.isEmpty) return;
    final held = _keys.values.toList();
    _keys.clear();
    onTapChanged?.call(isTapPressed);
    for (final event in held) {
      _send(_key(.tapCancel, event));
    }
  }

  void _cancelGestures([PointerEvent? input, ElEventCancelReason reason = .external]) {
    final gestures = _gestures;
    _gestures = null;
    gestures?.dispose(input, reason);
  }

  void _cancelPointer(_PointerRoute route, ElEventCancelReason reason, [PointerRemovedEvent? removed]) {
    route.members.remove(this);
    if (route.ended) return;
    final down = route.down;
    final position = _pointerPosition(route.last);
    if (down is PointerPanZoomStartEvent) {
      final end = PointerPanZoomEndEvent(pointer: down.pointer, device: down.device, position: position);
      _send(_pointer(.pointerPanZoomEnd, end)..preventDefault());
    } else {
      final cancel =
          removed ??
          PointerCancelEvent(pointer: down.pointer, kind: down.kind, device: down.device, position: position);
      _send(_pointer(.pointerCancel, cancel, reason: reason));
    }
  }

  /// 结束宿主跟踪的输入和反馈。
  void cancelAllPendingAtLastPosition() {
    if (_canceling) return;
    _canceling = true;
    try {
      _cancelGestures();
      _releaseFeedback();
      _releaseKeys();
      for (final route in _pointers.values.where((route) => route.members.contains(this)).toList()) {
        _cancelPointer(route, .external);
        if (route.members.isEmpty) _pointers.remove(route.down.pointer);
      }
    } finally {
      _watchDevices();
      DragPointerLock.release(_render);
      _canceling = false;
    }
  }

  /// 释放识别器和宿主注册。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelAllPendingAtLastPosition();
    if (identical(_hosts[_render], this)) _hosts[_render] = null;
    _event = null;
    onTapChanged = null;
    onRoutedPointerRemoved = null;
  }
}

final class _PointerRoute {
  _PointerRoute(this.down) : last = down;
  final PointerEvent down;
  PointerEvent last;
  final members = <EventDispatcher>{};
  bool dragStopped = false;
  bool get ended => last is PointerUpEvent || last is PointerCancelEvent || last is PointerPanZoomEndEvent;
}

/// 保留框架操作使用的全局输入锁，不参与普通手势识别。
@internal
final class DragPointerLock {
  DragPointerLock._();

  static RenderObject? _owner;

  /// 当前是否处于拖拽指针锁定期。
  static bool get isActive => _owner?.attached ?? false;

  /// [owner]（拖拽宿主 render）声明拖拽激活；后声明者接管且永不改变光标。
  static void claim(RenderObject owner) => _owner = owner;

  /// 拖拽结束/取消/宿主销毁时释放；仅当前 owner 的释放生效。
  static void release(RenderObject owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    if (owner.attached) {
      RendererBinding.instance.addPostFrameCallback((_) {
        if (!isActive) RendererBinding.instance.mouseTracker.updateAllDevices();
      });
      RendererBinding.instance.ensureVisualUpdate();
    }
  }

  @visibleForTesting
  static void debugReset() => _owner = null;
}

/// 锁激活期放在命中结果最前的屏障：吞事件但不下发任何光标换形命令。
final HitTestTarget dragPointerLockBarrier = const _DragPointerLockBarrier();

final class _DragPointerLockBarrier extends MouseTrackerAnnotation implements HitTestTarget {
  const _DragPointerLockBarrier();

  @override
  MouseCursor get cursor => MouseCursor.uncontrolled;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {}
}
