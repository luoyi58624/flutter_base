import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show MouseTrackerAnnotation, PointerEnterEventListener, PointerExitEventListener;

import 'event.dart';
import 'recognizers/index.dart';

/// 事件元素，只处理几何、样式反馈与业务载荷适配。
class ElRenderEvent extends RenderProxyBoxWithHitTestBehavior implements MouseTrackerAnnotation {
  /// 创建单个事件元素，按压反馈使用识别器的被动观察能力。
  ElRenderEvent({
    ElEvent event = const ElEvent(),
    this.onTapChanged,
    this.onHoverChanged,
    this.gestureSettings,
    super.child,
  }) : super(behavior: event.behavior) {
    _team.onPointerEvent = _handlePointer;
    _feedback = _TapFeedback((value) => onTapChanged?.call(value));
    this.event = event;
  }

  static final _callbacks = Expando<ElEventCallback>('ElEvent callback');
  final _team = ElGestureArenaTeam()..matchParentGestures = true;
  late final _press = ElPressGestureRecognizer(debugOwner: this)..team = _team;
  late final _transform = ElTransformGestureRecognizer(debugOwner: this)..team = _team;
  late final _TapFeedback _feedback;
  final _dragProxies = <Object, List<ElRenderEvent>>{};
  final _hoverDevices = <int>{};
  ElEvent? _event;
  bool _disposed = false;
  int _configurationRevision = 0;

  /// 按压反馈通知，不影响官方点击竞争。
  ValueChanged<bool>? onTapChanged;

  /// 多鼠标悬停反馈通知。
  ValueChanged<bool>? onHoverChanged;

  /// 当前设备的官方手势容差。
  DeviceGestureSettings? gestureSettings;

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

  /// 用于验证物理输入已结清。
  int get debugRoutedPointerCount => activePointerCount;

  /// 当前元素是否已销毁。
  bool get isDisposed => _disposed;

  /// 更新事件声明，识别器负责旧订阅的取消和回调失效。
  ElEvent? get event => _event;

  set event(ElEvent? value) {
    if (_disposed || identical(_event, value)) return;
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
    if (value == null || value.disabled) _cancelSubtree(this);
    if (_disposed || revision != _configurationRevision) return;
    _event = value;
    behavior = value?.behavior ?? HitTestBehavior.opaque;
    _configureRecognizers();
    if ((old?.cursor != value?.cursor || old?.disabled != value?.disabled) &&
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      RendererBinding.instance.ensureVisualUpdate();
    }
  }

  double get _tapDistance => config.tapCancelDistance ?? ElPressGestureRecognizer.defaultConsecutiveTapDistance;

  Iterable<ElRenderEvent> get _ancestors sync* {
    RenderObject? node = parent;
    while (node != null) {
      if (node is ElRenderEvent && !node._disposed) yield node;
      node = node.parent;
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    final ancestor = _ancestors.firstOrNull;
    _press.parent = ancestor?._press;
    _transform.parent = ancestor?._transform;
    _team.parent = ancestor?._team;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!disabled) return super.hitTest(result, position: position);
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (_disposed) return;
    if (event is PointerHoverEvent || event is PointerSignalEvent) {
      if (!disabled && _event != null) _handlePointer(event, null);
      return;
    }
    final before = _event;
    final start = event is PointerDownEvent || event is PointerPanZoomStartEvent;
    if (start && (disabled || before == null)) return;
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
    final phase = switch (input) {
      PointerDownEvent() => ElEventPhase.pointerDown,
      PointerMoveEvent() => ElEventPhase.pointerMove,
      PointerUpEvent() => ElEventPhase.pointerUp,
      PointerCancelEvent() => ElEventPhase.pointerCancel,
      PointerHoverEvent() => ElEventPhase.pointerHover,
      PointerSignalEvent() => ElEventPhase.pointerSignal,
      PointerPanZoomStartEvent() => ElEventPhase.pointerPanZoomStart,
      PointerPanZoomUpdateEvent() => ElEventPhase.pointerPanZoomUpdate,
      PointerPanZoomEndEvent() => ElEventPhase.pointerPanZoomEnd,
      _ => null,
    };
    if (phase == null) return true;
    final callback = _rawCallback(phase, input, reason: reason == null ? null : _cancelReason(reason))
      ..pointerCount = activePointerCount;
    _invoke(_handler(phase), callback);
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

  void _handlePress(ElPressGestureDetails details) {
    if (_disposed) return;
    final phase = ElEventPhase.values.byName(details.phase.name);
    if (phase == ElEventPhase.tapDown && onTapChanged != null) {
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
    _invoke(_handler(phase), callback);
    if (callback.propagationStopped) details.stopPropagation();
    if (phase == ElEventPhase.longPress && !callback.defaultPrevented && details.isActive) {
      _team.claimPointer(details.pointer, cancelTap: true);
    }
  }

  void _handleTransform(ElTransformGestureDetails details) {
    if (_disposed) return;
    final phase = ElEventPhase.values.byName(details.phase.name);
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
      if (details.isPrimaryTarget) _dispatchDragUpdate(details);
      return;
    }
    if (phase == ElEventPhase.dragEnd || phase == ElEventPhase.dragCancel) {
      _dragProxies.remove(details.sequenceIdentity);
    }
    final callback = _gestureCallback(details, phase);
    _invoke(_handler(phase, details.dragAxis), callback);
    if (callback.propagationStopped) details.stopPropagation();
    if (phase == ElEventPhase.scaleStart && !callback.defaultPrevented && details.isActive) {
      for (final pointer in details.pointerIds) {
        _team.claimPointer(pointer, cancelTap: true);
      }
    }
  }

  bool _contains(Offset position) {
    if (!attached || !hasSize) return true;
    final inverse = Matrix4.tryInvert(getTransformTo(null));
    return inverse != null && size.contains(MatrixUtils.transformPoint(inverse, position));
  }

  Offset _local(Offset position) => attached ? globalToLocal(position) : position;

  Offset _localDelta(Offset position, Offset delta) => _local(position) - _local(position - delta);

  @override
  MouseCursor get cursor => disabled ? SystemMouseCursors.forbidden : _event?.cursor ?? MouseCursor.defer;

  @override
  bool get validForMouseTracker => attached;

  @override
  PointerEnterEventListener get onEnter => handlePointerEnter;

  @override
  PointerExitEventListener get onExit => handlePointerExit;

  /// 接收官方鼠标进入通知。
  void handlePointerEnter(PointerEnterEvent event) {
    _hoverDevices.add(event.device);
    onHoverChanged?.call(true);
    if (!disabled && !_disposed) {
      _invoke(_handler(ElEventPhase.pointerEnter), _rawCallback(ElEventPhase.pointerEnter, event));
    }
  }

  /// 接收官方鼠标离开通知。
  void handlePointerExit(PointerExitEvent event) {
    _hoverDevices.remove(event.device);
    onHoverChanged?.call(_hoverDevices.isNotEmpty);
    if (!disabled && !_disposed) {
      _invoke(_handler(ElEventPhase.pointerExit), _rawCallback(ElEventPhase.pointerExit, event));
    }
  }

  /// 结清当前元素，原始输入和手势终态由团队与识别器负责。
  void cancelAllPending([PointerEvent? event]) {
    final down = _feedback.contact;
    _team.cancel();
    _feedback.cancel(down: down);
  }

  /// 结清当前元素，使用识别器记录的最后输入位置。
  void cancelAllPendingAtLastPosition() => cancelAllPending();

  static void _cancelSubtree(RenderObject root) {
    root.visitChildren(_cancelSubtree);
    if (root is ElRenderEvent) root.cancelAllPending();
  }

  @override
  void dispose() {
    if (_disposed) return;
    cancelAllPending();
    _disposed = true;
    _team.dispose();
    _press.dispose();
    _transform.dispose();
    _dragProxies.clear();
    super.dispose();
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
extension _EventBinding on ElRenderEvent {
  bool get _hasPrimaryTap =>
      _event?.onTap != null ||
      _event?.onDoubleTap != null ||
      _event?.onDoubleTapDown != null ||
      _event?.onTripleTap != null ||
      _event?.onTripleTapDown != null;

  bool get _hasFreeDrag =>
      _event != null &&
      [
        _event!.onDragStart,
        _event!.onDragUpdate,
        _event!.onDragEnd,
        _event!.onDragCancel,
      ].any((handler) => handler != null);

  bool get _hasVertical =>
      _event != null &&
      [
        _event!.onVerticalDragStart,
        _event!.onVerticalDragUpdate,
        _event!.onVerticalDragEnd,
        _event!.onVerticalDragCancel,
      ].any((handler) => handler != null);

  bool get _hasHorizontal =>
      _event != null &&
      [
        _event!.onHorizontalDragStart,
        _event!.onHorizontalDragUpdate,
        _event!.onHorizontalDragEnd,
        _event!.onHorizontalDragCancel,
      ].any((handler) => handler != null);

  bool get _hasDrag => _hasFreeDrag || _hasVertical || _hasHorizontal || _event?.onDragDown != null;

  bool get _hasScale =>
      _event != null &&
      [
        _event!.onScaleStart,
        _event!.onScaleUpdate,
        _event!.onScaleEnd,
        _event!.onScaleCancel,
        _event!.onRotationUpdate,
      ].any((handler) => handler != null);

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
      ..gestureSettings = gestureSettings
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
        return config.tapCancelOnMove == true || _contains(event.position);
      }
      ..competeForTap = _hasPrimaryTap
      ..onTapDown = _handlePress
      ..onTapUp = _handlePress
      ..onTap = _event?.onTap == null ? null : _handlePress
      ..onTapCancel = _handlePress
      ..onDoubleTap = _event?.onDoubleTap == null ? null : _handlePress
      ..onDoubleTapDown = _event?.onDoubleTapDown == null ? null : _handlePress
      ..onTripleTap = _event?.onTripleTap == null ? null : _handlePress
      ..onTripleTapDown = _event?.onTripleTapDown == null ? null : _handlePress
      ..onLongPress = _event?.onLongPress == null ? null : _handlePress
      ..onSecondaryTapDown = _event?.onSecondaryTapDown == null ? null : _handlePress
      ..onSecondaryTapUp = _event?.onSecondaryTapUp == null ? null : _handlePress
      ..onSecondaryTap = _event?.onSecondaryTap == null ? null : _handlePress
      ..onTertiaryTapDown = _event?.onTertiaryTapDown == null ? null : _handlePress
      ..onTertiaryTapUp = _event?.onTertiaryTapUp == null ? null : _handlePress
      ..onTertiaryTap = _event?.onTertiaryTap == null ? null : _handlePress
      ..onForwardTapDown = _event?.onForwardTapDown == null ? null : _handlePress
      ..onForwardTapUp = _event?.onForwardTapUp == null ? null : _handlePress
      ..onForwardTap = _event?.onForwardTap == null ? null : _handlePress
      ..onBackTapDown = _event?.onBackTapDown == null ? null : _handlePress
      ..onBackTapUp = _event?.onBackTapUp == null ? null : _handlePress
      ..onBackTap = _event?.onBackTap == null ? null : _handlePress;

    _transform
      ..gestureSettings = gestureSettings
      ..supportedDevices = config.dragDevices
      ..startDistance = config.dragStartDistance
      ..horizontalAngle = config.dragHorizontalAngle
      ..minFlingDistance = config.dragMinFlingDistance
      ..minFlingVelocity = config.dragMinFlingVelocity
      ..maxFlingVelocity = config.dragMaxFlingVelocity
      ..axis = _axis
      ..lockAxis = _hasHorizontal && _hasVertical
      ..cancelDragOnScale = true
      ..onDragDown = _hasDrag ? _handleTransform : null
      ..onDragStart = _hasDrag ? _handleTransform : null
      ..onDragUpdate = _hasDrag ? _handleTransform : null
      ..onDragEnd = _hasDrag ? _handleTransform : null
      ..onDragCancel = _hasDrag ? _handleTransform : null
      ..onScaleStart = _hasScale ? _handleTransform : null
      ..onScaleUpdate = _hasScale ? _handleTransform : null
      ..onScaleEnd = _hasScale ? _handleTransform : null
      ..onScaleCancel = _hasScale ? _handleTransform : null
      ..onRotationUpdate = _event?.onRotationUpdate == null ? null : _handleTransform;
    _team.acceptsPanZoom = _event?.onPointerPanZoomUpdate != null;
  }

  ElEventCallback _gestureCallback(ElGestureDetails details, ElEventPhase phase) {
    final transform = details is ElTransformGestureDetails ? details : null;
    final press = details is ElPressGestureDetails ? details : null;
    final callback = ElRenderEvent._callbacks[details.dispatchIdentity] ??= ElEventCallback(
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
      cancelReason: phase == ElEventPhase.tapCancel ? ElRenderEvent._cancelReason(press?.cancelReason) : null,
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
      localPosition: _local(event.position),
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

  List<ElRenderEvent> _collectDragProxies(Axis? axis) {
    List<ElRenderEvent>? proxies;
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

  void _dispatchDragUpdate(ElTransformGestureDetails details) {
    final proxies = _dragProxies[details.sequenceIdentity];
    final pipeline = proxies ?? const <ElRenderEvent>[];
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
    _invoke(_handler(ElEventPhase.dragUpdate, details.dragAxis), callback);
    if (callback.propagationStopped) details.stopPropagation();
    for (final member in pipeline) {
      if (!isActive() || callback.remainingDelta == Offset.zero) break;
      _invokeDragProxy(member, member.event?.dragProxy?.onDragOverflow, callback);
    }
  }

  void _invokeDragProxy(ElRenderEvent member, ElEventHandler? handler, ElEventCallback callback) {
    if (member._disposed || member.disabled || handler == null) return;
    callback.localPosition = member._local(callback.globalPosition);
    callback.localDelta = member._localDelta(callback.globalPosition, callback.delta);
    callback.updateLocalDeltaResolver((delta) => member._localDelta(callback.globalPosition, delta));
    callback.updateEagerGestureHandler(null);
    member._invoke(handler, callback);
    callback.resetPropagation();
  }

  ElEventHandler? _handler(ElEventPhase phase, [Axis? axis]) {
    final event = _event;
    if (event == null) return null;
    return switch (phase) {
      ElEventPhase.pointerEnter => event.onPointerEnter,
      ElEventPhase.pointerHover => event.onPointerHover,
      ElEventPhase.pointerExit => event.onPointerExit,
      ElEventPhase.pointerDown => event.onPointerDown,
      ElEventPhase.pointerMove => event.onPointerMove,
      ElEventPhase.pointerUp => event.onPointerUp,
      ElEventPhase.pointerCancel => event.onPointerCancel,
      ElEventPhase.pointerPanZoomStart => event.onPointerPanZoomStart,
      ElEventPhase.pointerPanZoomUpdate => event.onPointerPanZoomUpdate,
      ElEventPhase.pointerPanZoomEnd => event.onPointerPanZoomEnd,
      ElEventPhase.pointerSignal => event.onPointerSignal,
      ElEventPhase.tapDown => event.onTapDown,
      ElEventPhase.tapUp => event.onTapUp,
      ElEventPhase.tap => event.onTap,
      ElEventPhase.doubleTap => event.onDoubleTap,
      ElEventPhase.doubleTapDown => event.onDoubleTapDown,
      ElEventPhase.tripleTap => event.onTripleTap,
      ElEventPhase.tripleTapDown => event.onTripleTapDown,
      ElEventPhase.longPress => event.onLongPress,
      ElEventPhase.tapCancel => event.onTapCancel,
      ElEventPhase.secondaryTapDown => event.onSecondaryTapDown,
      ElEventPhase.secondaryTapUp => event.onSecondaryTapUp,
      ElEventPhase.secondaryTap => event.onSecondaryTap,
      ElEventPhase.tertiaryTapDown => event.onTertiaryTapDown,
      ElEventPhase.tertiaryTapUp => event.onTertiaryTapUp,
      ElEventPhase.tertiaryTap => event.onTertiaryTap,
      ElEventPhase.forwardTapDown => event.onForwardTapDown,
      ElEventPhase.forwardTapUp => event.onForwardTapUp,
      ElEventPhase.forwardTap => event.onForwardTap,
      ElEventPhase.backTapDown => event.onBackTapDown,
      ElEventPhase.backTapUp => event.onBackTapUp,
      ElEventPhase.backTap => event.onBackTap,
      ElEventPhase.dragDown => event.onDragDown,
      ElEventPhase.dragStart =>
        axis == Axis.vertical
            ? event.onVerticalDragStart ?? event.onDragStart
            : axis == Axis.horizontal
            ? event.onHorizontalDragStart ?? event.onDragStart
            : event.onDragStart,
      ElEventPhase.dragUpdate =>
        axis == Axis.vertical
            ? event.onVerticalDragUpdate ?? event.onDragUpdate
            : axis == Axis.horizontal
            ? event.onHorizontalDragUpdate ?? event.onDragUpdate
            : event.onDragUpdate,
      ElEventPhase.dragEnd =>
        axis == Axis.vertical
            ? event.onVerticalDragEnd ?? event.onDragEnd
            : axis == Axis.horizontal
            ? event.onHorizontalDragEnd ?? event.onDragEnd
            : event.onDragEnd,
      ElEventPhase.dragCancel =>
        axis == Axis.vertical
            ? event.onVerticalDragCancel ?? event.onDragCancel
            : axis == Axis.horizontal
            ? event.onHorizontalDragCancel ?? event.onDragCancel
            : event.onDragCancel,
      ElEventPhase.scaleStart => event.onScaleStart,
      ElEventPhase.scaleUpdate => event.onScaleUpdate,
      ElEventPhase.scaleEnd => event.onScaleEnd,
      ElEventPhase.scaleCancel => event.onScaleCancel,
      ElEventPhase.rotationUpdate => event.onRotationUpdate,
    };
  }

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
