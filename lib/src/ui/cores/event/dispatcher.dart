import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart' show Axis;
import 'package:flutter/services.dart' show MouseCursor, SystemMouseCursors;

import '../view/render/index.dart';
import 'event.dart';
import 'recognizers/index.dart';

/// 将宿主输入与几何连接到独立识别器，管理反馈、业务回调和拖拽代理。
class ElEventDispatcher {
  /// 连接具体视图宿主与事件声明；构造期间不向宿主发送通知。
  ElEventDispatcher(this._render, ElEvent event) : _event = event {
    _team.onPointerEvent = _handlePointer;
    _feedback = _TapFeedback((value) => _render.onTapChanged?.call(value));
    _configureRecognizers();
  }

  final ElRenderView _render;
  static final _callbacks = Expando<ElEventCallback>('ElEvent callback');
  final _team = ElGestureArenaTeam()..matchParentGestures = true;
  late final _press = ElPressGestureRecognizer(debugOwner: this)..team = _team;
  late final _transform = ElTransformGestureRecognizer(debugOwner: this)..team = _team;
  late final _TapFeedback _feedback;
  final _dragProxies = <Object, List<ElEventDispatcher>>{};
  final _hoverDevices = <int>{};
  ElEvent? _event;
  bool _disposed = false;
  bool _disposing = false;
  int _configurationRevision = 0;

  /// 当前元素的局部配置声明。
  ElEventConfig get config => _event?.config ?? const ElEventConfig();

  /// 当前是否禁用。
  bool get disabled => _event?.disabled ?? false;

  /// 当前是否显示按压反馈。
  bool get isTapPressed => _feedback.value;

  /// 直接读取识别器的拖拽状态。
  bool get isDragged => _transform.isDragging;

  /// 当前仍接收原始输入的指针数。
  int get activePointerCount => _team.pointerCount;

  /// 当前元素是否已销毁。
  bool get isDisposed => _disposed;

  /// 更新事件声明，识别器负责旧订阅的取消和回调失效。
  ElEvent? get event => _event;

  set event(ElEvent? value) {
    if (_disposed || _disposing || identical(_event, value)) return;
    final revision = ++_configurationRevision;
    final old = _event;
    final terminal = _team.isDispatchingTerminal;
    if (old != null) {
      if (value == null || !old.hasSameNonDragShape(value) || terminal) {
        _press.cancelMember();
      }
      if (_disposed || revision != _configurationRevision) return;
      final changedDuringRaw =
          _team.isDispatching && value != null && !old.hasSameGestureShape(value, compareConfig: false);
      if (value == null || !old.hasSameTransformShape(value) || terminal || changedDuringRaw && !isDragged) {
        _transform.cancelMember(null);
      }
      if (_disposed || revision != _configurationRevision) return;
    }
    if (value == null || value.disabled) {
      _render.cancelDescendantEvents();
      if (_disposed || revision != _configurationRevision) return;
      cancelAllPending();
    }
    if (_disposed || revision != _configurationRevision) return;
    _event = value;
    _configureRecognizers();
  }

  double get _tapDistance => config.tapCancelDistance ?? ElPressGestureRecognizer.defaultConsecutiveTapDistance;

  ElEventDispatcher? _parent;

  /// 刷新宿主设备配置与反馈需求，不取消正在识别的输入。
  void sync() {
    if (!_disposed && !_disposing) _configureRecognizers();
  }

  /// 按真实渲染树更新祖先关系，当前手势仍使用识别器已冻结的路线。
  void syncParent() {
    if (_disposed || _disposing) return;
    _parent = null;
    for (var node = _render.parent; node != null; node = node.parent) {
      final candidate = node is ElRenderView ? node.eventDispatcher : null;
      if (candidate == null || candidate._disposed || candidate._disposing) continue;
      _parent = candidate;
      break;
    }
    _press.parent = _parent?._press;
    _transform.parent = _parent?._transform;
    _team.parent = _parent?._team;
  }

  Iterable<ElEventDispatcher> get _ancestors sync* {
    var node = _parent;
    while (node != null) {
      if (!node._disposed) yield node;
      node = node._parent;
    }
  }

  /// 接收保留命中路径变换的原始输入，后续手势输入由官方指针路由投递。
  void handleEvent(PointerEvent event) {
    if (_disposed || _disposing) return;
    if (event is PointerHoverEvent || event is PointerSignalEvent) {
      if (!disabled && _event != null) _handlePointer(event, null);
      return;
    }
    final before = _event;
    final start = event is PointerDownEvent || event is PointerPanZoomStartEvent;
    if (start && (disabled || before == null)) return;
    if (start) syncParent();
    if (!_team.observePointer(event) || disabled || _event == null) return;
    if (event is PointerDownEvent) {
      if (before != null && before.hasSameTransformShape(_event!) && (_hasDrag || _hasScale)) {
        _transform.addPointer(event);
      }
      if (before != null && before.hasSameNonDragShape(_event!)) {
        _press.addPointer(event);
      }
    } else if (event is PointerPanZoomStartEvent &&
        before != null &&
        before.hasSameTransformShape(_event!) &&
        (_hasDrag || _hasScale)) {
      _transform.addPointerPanZoom(event);
    }
  }

  bool _handlePointer(PointerEvent input, ElGestureCancelReason? reason) {
    final event = _event;
    final target = switch (input) {
      PointerDownEvent() => (ElEventPhase.pointerDown, event?.onPointerDown),
      PointerMoveEvent() => (ElEventPhase.pointerMove, event?.onPointerMove),
      PointerUpEvent() => (ElEventPhase.pointerUp, event?.onPointerUp),
      PointerCancelEvent() => (ElEventPhase.pointerCancel, event?.onPointerCancel),
      PointerHoverEvent() => (ElEventPhase.pointerHover, event?.onPointerHover),
      PointerSignalEvent() => (ElEventPhase.pointerSignal, event?.onPointerSignal),
      PointerPanZoomStartEvent() => (ElEventPhase.pointerPanZoomStart, event?.onPointerPanZoomStart),
      PointerPanZoomUpdateEvent() => (ElEventPhase.pointerPanZoomUpdate, event?.onPointerPanZoomUpdate),
      PointerPanZoomEndEvent() => (ElEventPhase.pointerPanZoomEnd, event?.onPointerPanZoomEnd),
      _ => null,
    };
    if (target == null) return true;
    final (phase, handler) = target;
    final callback = _rawCallback(phase, input, reason: reason == null ? null : _cancelReason(reason))
      ..pointerCount = activePointerCount;
    _invoke(handler, callback);
    if (input is PointerSignalEvent && callback.defaultPrevented) {
      GestureBinding.instance.pointerSignalResolver.register(
        input,
        (event) => event.respond(allowPlatformDefault: false),
      );
    }
    return !callback.propagationStopped;
  }

  static ElEventCancelReason _cancelReason(ElGestureCancelReason? reason) => switch (reason) {
    ElGestureCancelReason.arenaRejected => ElEventCancelReason.otherGestureAccepted,
    ElGestureCancelReason.pointerCanceled => ElEventCancelReason.pointerCanceled,
    ElGestureCancelReason.longPressAccepted => ElEventCancelReason.selfGestureAccepted,
    ElGestureCancelReason.rejected || ElGestureCancelReason.ineligible => ElEventCancelReason.tapRejected,
    _ => ElEventCancelReason.external,
  };

  void _handlePress(ElPressGestureDetails details, ElEventPhase phase, ElEventHandler? Function(ElEvent) select) {
    if (_disposed) return;
    if (phase == ElEventPhase.tapDown && _render.onTapChanged != null) {
      _feedback.down(details.downEvent, config);
    }
    if (phase == ElEventPhase.tapCancel) {
      _feedback.cancel(
        down: details.downEvent,
        preserveDuration: details.cancelReason == ElGestureCancelReason.ineligible,
      );
      if (_team.isDispatchingTerminal) return;
    }
    if (!details.isActive) return;
    final callback = _gestureCallback(details, phase);
    _invoke(_event == null ? null : select(_event!), callback);
    if (callback.propagationStopped) details.stopPropagation();
    if (phase == ElEventPhase.longPress && !callback.defaultPrevented && details.isActive) {
      _team.claimPointer(details.pointer, cancelTap: true);
    }
  }

  void _handleTransform(
    ElTransformGestureDetails details,
    ElEventPhase phase,
    ElEventHandler? Function(ElEvent, Axis?) select,
  ) {
    if (_disposed) return;
    if (phase == ElEventPhase.dragCancel && !details.started && _event?.onDragDown == null) {
      return;
    }
    if (phase == ElEventPhase.dragStart) {
      final proxies = _collectDragProxies(details.dragAxis);
      if (proxies.isNotEmpty) _dragProxies[details.sequenceIdentity] = proxies;
      if (details.isPrimaryTarget && proxies.isNotEmpty) {
        _press.rejectTap(details.pointer, reason: ElGestureCancelReason.longPressAccepted);
        for (final proxy in proxies) {
          proxy._team.cancelPress(details.pointer, reason: ElGestureCancelReason.arenaRejected);
        }
      }
    }
    if (phase == ElEventPhase.dragUpdate) {
      if (details.isPrimaryTarget) _dispatchDragUpdate(details, select);
      return;
    }
    if (phase == ElEventPhase.dragEnd || phase == ElEventPhase.dragCancel) {
      _dragProxies.remove(details.sequenceIdentity);
    }
    final callback = _gestureCallback(details, phase);
    _invoke(_event == null ? null : select(_event!, details.dragAxis), callback);
    if (callback.propagationStopped) details.stopPropagation();
    if (phase == ElEventPhase.scaleStart && !callback.defaultPrevented && details.isActive) {
      for (final pointer in details.pointerIds) {
        _team.claimPointer(pointer, cancelTap: true);
      }
    }
  }

  Offset _localDelta(Offset position, Offset delta) =>
      _render.eventLocalPosition(position) - _render.eventLocalPosition(position - delta);

  /// 当前光标；禁用时显示禁止操作。
  MouseCursor get cursor => disabled ? SystemMouseCursors.forbidden : _event?.cursor ?? MouseCursor.defer;

  /// 接收官方鼠标进入通知。
  void handlePointerEnter(PointerEnterEvent event) {
    if (_disposed || _disposing) return;
    _hoverDevices.add(event.device);
    _render.onHoverChanged?.call(true);
    if (!disabled && !_disposed) {
      _invoke(_event?.onPointerEnter, _rawCallback(ElEventPhase.pointerEnter, event));
    }
  }

  /// 接收官方鼠标离开通知。
  void handlePointerExit(PointerExitEvent event) {
    if (_disposed || _disposing) return;
    _hoverDevices.remove(event.device);
    _render.onHoverChanged?.call(_hoverDevices.isNotEmpty);
    if (!disabled && !_disposed) {
      _invoke(_event?.onPointerExit, _rawCallback(ElEventPhase.pointerExit, event));
    }
  }

  /// 结清当前元素，原始输入和手势终态由团队与识别器负责。
  void cancelAllPending() {
    final down = _feedback.contact;
    _team.cancel();
    _feedback.cancel(down: down);
  }

  /// 结清当前输入并释放识别器；宿主的 detach 不应调用此方法。
  void dispose() {
    if (_disposed || _disposing) return;
    _disposing = true;
    cancelAllPending();
    _disposed = true;
    _team.dispose();
    _press.dispose();
    _transform.dispose();
    _dragProxies.clear();
    _hoverDevices.clear();
  }
}

/// 只保存反馈计时，不保存手势资格、报名、归属或阶段状态。
final class _TapFeedback {
  _TapFeedback(this.onChanged);

  final ValueChanged<bool> onChanged;
  PointerEvent? _down;
  bool _released = false;
  Timer? _enter;
  Timer? _leave;
  bool value = false;

  PointerEvent? get contact => _down;

  void _set(bool next) {
    if (value == next) return;
    value = next;
    onChanged(next);
  }

  void down(PointerEvent source, ElEventConfig config) {
    final down = source.original ?? source;
    final minimum = config.delayTouchUp ?? const Duration(milliseconds: 100);
    final delay = down.kind == PointerDeviceKind.touch ? config.delayTouchDown ?? Duration.zero : Duration.zero;
    assert(minimum >= Duration.zero && delay >= Duration.zero);
    _enter?.cancel();
    if (!identical(_down, down)) {
      _leave?.cancel();
      _down = down;
      _released = false;
      if (down.kind == PointerDeviceKind.touch && minimum > Duration.zero) {
        _leave = Timer(minimum, () {
          _leave = null;
          if (identical(_down, down) && _released) cancel(down: down);
        });
      }
    }
    if (delay == Duration.zero) {
      _set(true);
    } else {
      _enter = Timer(delay, () {
        if (identical(_down, down) && !_released) _set(true);
      });
    }
  }

  void up(PointerEvent source) {
    final down = source.original ?? source;
    if (!identical(_down, down)) return;
    _released = true;
    _enter?.cancel();
    if (!value || down.kind != PointerDeviceKind.touch || !(_leave?.isActive ?? false)) {
      cancel(down: down);
    }
  }

  void cancel({required PointerEvent? down, bool preserveDuration = false}) {
    final source = down?.original ?? down;
    if (!identical(_down, source)) return;
    _enter?.cancel();
    _enter = null;
    if (!preserveDuration) {
      _leave?.cancel();
      _leave = null;
      _down = null;
    }
    _set(false);
  }
}

/// 将声明映射到原生识别器及业务回调，不维护另一套手势路线。
extension _EventBinding on ElEventDispatcher {
  bool get _hasPrimaryTap =>
      _event?.onTap != null ||
      _event?.onDoubleTap != null ||
      _event?.onDoubleTapDown != null ||
      _event?.onTripleTap != null ||
      _event?.onTripleTapDown != null;

  bool get _hasFreeDrag =>
      _event?.onDragStart != null ||
      _event?.onDragUpdate != null ||
      _event?.onDragEnd != null ||
      _event?.onDragCancel != null;

  bool get _hasVertical =>
      _event?.onVerticalDragStart != null ||
      _event?.onVerticalDragUpdate != null ||
      _event?.onVerticalDragEnd != null ||
      _event?.onVerticalDragCancel != null;

  bool get _hasHorizontal =>
      _event?.onHorizontalDragStart != null ||
      _event?.onHorizontalDragUpdate != null ||
      _event?.onHorizontalDragEnd != null ||
      _event?.onHorizontalDragCancel != null;

  bool get _hasDrag => _hasFreeDrag || _hasVertical || _hasHorizontal || _event?.onDragDown != null;

  bool get _hasScale =>
      _event?.onScaleStart != null ||
      _event?.onScaleUpdate != null ||
      _event?.onScaleEnd != null ||
      _event?.onScaleCancel != null ||
      _event?.onRotationUpdate != null;

  Axis? get _axis => _hasFreeDrag || _hasHorizontal && _hasVertical
      ? null
      : _hasVertical
      ? Axis.vertical
      : _hasHorizontal
      ? Axis.horizontal
      : null;

  void _configureRecognizers() {
    final press = _press;
    press
      ..onReleased = (details) {
        _feedback.up(details.downEvent);
      }
      ..gestureSettings = _render.gestureSettings
      ..doubleTapInterval = config.doubleTapInterval
      ..tripleTapInterval = config.tripleTapInterval
      ..longPressDelay = config.longPressDelay
      ..tapSlopTolerance = config.tapCancelOnMove == true ? _tapDistance : double.infinity
      ..secondaryTapSlopTolerance = _tapDistance
      ..longPressSlopTolerance = config.longPressCancelDistance
      ..consecutiveTapDistance = config.tapCancelDistance
      ..deferTap = config.deferTap
      ..cancelTapOnLongPress = false
      ..isEligible = (phase, event) {
        return config.tapCancelOnMove == true || _render.eventContains(event.position);
      }
      ..competeForTap = _hasPrimaryTap
      ..onTapDown = _bindPress(.tapDown, (event) => event.onTapDown, observe: true)
      ..onTapUp = _bindPress(.tapUp, (event) => event.onTapUp, observe: true)
      ..onTap = _bindPress(.tap, (event) => event.onTap)
      ..onTapCancel = _bindPress(.tapCancel, (event) => event.onTapCancel, observe: true)
      ..onDoubleTap = _bindPress(.doubleTap, (event) => event.onDoubleTap)
      ..onDoubleTapDown = _bindPress(.doubleTapDown, (event) => event.onDoubleTapDown)
      ..onTripleTap = _bindPress(.tripleTap, (event) => event.onTripleTap)
      ..onTripleTapDown = _bindPress(.tripleTapDown, (event) => event.onTripleTapDown)
      ..onLongPress = _bindPress(.longPress, (event) => event.onLongPress)
      ..onSecondaryTapDown = _bindPress(.secondaryTapDown, (event) => event.onSecondaryTapDown)
      ..onSecondaryTapUp = _bindPress(.secondaryTapUp, (event) => event.onSecondaryTapUp)
      ..onSecondaryTap = _bindPress(.secondaryTap, (event) => event.onSecondaryTap)
      ..onTertiaryTapDown = _bindPress(.tertiaryTapDown, (event) => event.onTertiaryTapDown)
      ..onTertiaryTapUp = _bindPress(.tertiaryTapUp, (event) => event.onTertiaryTapUp)
      ..onTertiaryTap = _bindPress(.tertiaryTap, (event) => event.onTertiaryTap)
      ..onForwardTapDown = _bindPress(.forwardTapDown, (event) => event.onForwardTapDown)
      ..onForwardTapUp = _bindPress(.forwardTapUp, (event) => event.onForwardTapUp)
      ..onForwardTap = _bindPress(.forwardTap, (event) => event.onForwardTap)
      ..onBackTapDown = _bindPress(.backTapDown, (event) => event.onBackTapDown)
      ..onBackTapUp = _bindPress(.backTapUp, (event) => event.onBackTapUp)
      ..onBackTap = _bindPress(.backTap, (event) => event.onBackTap);

    _transform
      ..gestureSettings = _render.gestureSettings
      ..supportedDevices = config.dragDevices
      ..startDistance = config.dragStartDistance
      ..horizontalAngle = config.dragHorizontalAngle
      ..minFlingDistance = config.dragMinFlingDistance
      ..minFlingVelocity = config.dragMinFlingVelocity
      ..maxFlingVelocity = config.dragMaxFlingVelocity
      ..axis = _axis
      ..lockAxis = _hasHorizontal && _hasVertical
      ..cancelDragOnScale = true
      ..onDragDown = _bindTransform(.dragDown, (event, _) => event.onDragDown, enabled: _hasDrag)
      ..onDragStart = _bindTransform(
        .dragStart,
        (event, axis) => _dragHandler(axis, event.onDragStart, event.onHorizontalDragStart, event.onVerticalDragStart),
        enabled: _hasDrag,
      )
      ..onDragUpdate = _bindTransform(
        .dragUpdate,
        (event, axis) =>
            _dragHandler(axis, event.onDragUpdate, event.onHorizontalDragUpdate, event.onVerticalDragUpdate),
        enabled: _hasDrag,
      )
      ..onDragEnd = _bindTransform(
        .dragEnd,
        (event, axis) => _dragHandler(axis, event.onDragEnd, event.onHorizontalDragEnd, event.onVerticalDragEnd),
        enabled: _hasDrag,
      )
      ..onDragCancel = _bindTransform(
        .dragCancel,
        (event, axis) =>
            _dragHandler(axis, event.onDragCancel, event.onHorizontalDragCancel, event.onVerticalDragCancel),
        enabled: _hasDrag,
      )
      ..onScaleStart = _bindTransform(.scaleStart, (event, _) => event.onScaleStart, enabled: _hasScale)
      ..onScaleUpdate = _bindTransform(.scaleUpdate, (event, _) => event.onScaleUpdate, enabled: _hasScale)
      ..onScaleEnd = _bindTransform(.scaleEnd, (event, _) => event.onScaleEnd, enabled: _hasScale)
      ..onScaleCancel = _bindTransform(.scaleCancel, (event, _) => event.onScaleCancel, enabled: _hasScale)
      ..onRotationUpdate = _bindTransform(
        .rotationUpdate,
        (event, _) => event.onRotationUpdate,
        enabled: _event?.onRotationUpdate != null,
      );
    _team.acceptsPanZoom = _event?.onPointerPanZoomUpdate != null;
  }

  ElEventCallback _gestureCallback(ElGestureDetails details, ElEventPhase phase) {
    final transform = details is ElTransformGestureDetails ? details : null;
    final press = details is ElPressGestureDetails ? details : null;
    final callback = ElEventDispatcher._callbacks[details.dispatchIdentity] ??= ElEventCallback(
      phase: phase,
      globalPosition: details.globalPosition,
      localPosition: details.localPosition,
      delta: transform?.delta ?? Offset.zero,
      localDelta: transform?.localDelta ?? Offset.zero,
      dragOffset: transform?.dragOffset ?? Offset.zero,
      dragAxis: transform?.dragAxis,
      dragDirection: transform?.dragDirection,
      velocity: transform?.velocity ?? Velocity.zero,
      primaryVelocity: transform?.primaryVelocity,
      buttons: details.buttons,
      tapCount: press?.tapCount ?? 0,
      pointerCount: transform?.pointerCount ?? 0,
      scale: transform?.scale ?? 1,
      rotation: transform?.rotation ?? 0,
      logScaleVelocity: transform?.logScaleVelocity ?? 0,
      originalEvent: details.originalEvent,
      cancelReason: phase == ElEventPhase.tapCancel ? ElEventDispatcher._cancelReason(press?.cancelReason) : null,
    );
    callback.localPosition = details.localPosition;
    callback.tapCount = press?.tapCount ?? 0;
    callback.localDelta = transform?.localDelta ?? Offset.zero;
    callback.pointerCount = transform?.pointerCount ?? 0;
    callback.updateLocalDeltaResolver((delta) => _localDelta(details.globalPosition, delta));
    final down = _team.downEventFor(details.pointer);
    callback.updateEagerGestureHandler((callback, cancelTap, allowScale) {
      if (!details.isActive || down == null) return;
      _team.claimPointer(details.pointer, downEvent: down, cancelTap: cancelTap, allowScaleUpgrade: allowScale);
    });
    return callback;
  }

  ElEventCallback _rawCallback(ElEventPhase phase, PointerEvent event, {ElEventCancelReason? reason}) {
    final callback = ElEventCallback(
      phase: phase,
      globalPosition: event.position,
      localPosition: _render.eventLocalPosition(event.position),
      delta: event.delta,
      localDelta: _localDelta(event.position, event.delta),
      buttons: event.buttons,
      originalEvent: event,
      cancelReason: reason,
      scale: event is PointerPanZoomUpdateEvent ? event.scale : 1,
      rotation: event is PointerPanZoomUpdateEvent ? event.rotation : 0,
    );
    final down = _team.downEventFor(event.pointer);
    callback.updateEagerGestureHandler((callback, cancelTap, allowScale) {
      if (down == null) return;
      _team.claimPointer(event.pointer, downEvent: down, cancelTap: cancelTap, allowScaleUpgrade: allowScale);
    });
    return callback;
  }

  List<ElEventDispatcher> _collectDragProxies(Axis? axis) {
    List<ElEventDispatcher>? proxies;
    for (final member in _ancestors) {
      final proxy = member.event?.dragProxy;
      if (proxy != null && (proxy.axis == null || proxy.axis == axis)) {
        (proxies ??= []).add(member);
      } else if (member._hasDrag) {
        break;
      }
    }
    return proxies ?? const [];
  }

  void _dispatchDragUpdate(ElTransformGestureDetails details, ElEventHandler? Function(ElEvent, Axis?) select) {
    final proxies = _dragProxies[details.sequenceIdentity];
    final pipeline = proxies ?? const <ElEventDispatcher>[];
    bool isActive() => details.isActive;
    final callback = _gestureCallback(details, ElEventPhase.dragUpdate)
      ..dragPipelineActive = pipeline.isNotEmpty
      ..hasAncestorDragConsumer = _transform.parent != null;
    for (final member in pipeline.reversed) {
      if (!isActive()) return;
      _invokeDragProxy(member, member.event?.dragProxy?.onDragPreUpdate, callback);
    }
    if (!isActive()) return;
    // 代理共享消费余量，主处理器沿用同一回调并恢复自身坐标与独占入口。
    if (pipeline.isNotEmpty) _gestureCallback(details, ElEventPhase.dragUpdate);
    _invoke(_event == null ? null : select(_event!, details.dragAxis), callback);
    if (callback.propagationStopped) details.stopPropagation();
    for (final member in pipeline) {
      if (!isActive() || callback.remainingDelta == Offset.zero) break;
      _invokeDragProxy(member, member.event?.dragProxy?.onDragOverflow, callback);
    }
  }

  void _invokeDragProxy(ElEventDispatcher member, ElEventHandler? handler, ElEventCallback callback) {
    if (member._disposed || member.disabled || handler == null) return;
    callback.localPosition = member._render.eventLocalPosition(callback.globalPosition);
    callback.localDelta = member._localDelta(callback.globalPosition, callback.delta);
    callback.updateLocalDeltaResolver((delta) => member._localDelta(callback.globalPosition, delta));
    callback.updateEagerGestureHandler(null);
    member._invoke(handler, callback);
    callback.resetPropagation();
  }

  ElPressGestureCallback? _bindPress(
    ElEventPhase phase,
    ElEventHandler? Function(ElEvent) select, {
    bool observe = false,
  }) {
    if (!observe && (_event == null || select(_event!) == null)) return null;
    // 反馈通知可能同步替换声明，派发时再读取当前业务闭包。
    return (details) => _handlePress(details, phase, select);
  }

  ElTransformGestureCallback? _bindTransform(
    ElEventPhase phase,
    ElEventHandler? Function(ElEvent, Axis?) select, {
    required bool enabled,
  }) => enabled ? (details) => _handleTransform(details, phase, select) : null;

  ElEventHandler? _dragHandler(
    Axis? axis,
    ElEventHandler? free,
    ElEventHandler? horizontal,
    ElEventHandler? vertical,
  ) => switch (axis) {
    Axis.horizontal => horizontal ?? free,
    Axis.vertical => vertical ?? free,
    null => free,
  };

  void _invoke(ElEventHandler? handler, ElEventCallback callback) {
    if (handler == null) return;
    callback.markCallbackInvoked();
    try {
      handler(callback);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'ElEvent',
          context: ErrorDescription('处理 ${callback.phase.name}'),
        ),
      );
    }
  }
}
