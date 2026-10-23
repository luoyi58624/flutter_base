import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show
        MouseTrackerAnnotation,
        PointerEnterEventListener,
        PointerExitEventListener;

import 'callback.dart';
import 'event.dart';
import 'recognizers/index.dart';

part 'interaction.dart';
part 'render_binding.dart';

/// 事件元素，只处理几何、样式反馈与业务载荷适配。
class RenderElEvent extends RenderProxyBoxWithHitTestBehavior
    implements MouseTrackerAnnotation {
  /// 创建单个事件元素，按压反馈使用识别器的被动观察能力。
  RenderElEvent({
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
  late final _transform = ElTransformGestureRecognizer(debugOwner: this)
    ..team = _team;
  late final _TapFeedback _feedback;
  final _dragProxies = <Object, List<RenderElEvent>>{};
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
          _team.isDispatching &&
          value != null &&
          !old.hasSameGestureShape(value, compareConfig: false);
      if (value == null ||
          !old.hasSameTransformShape(value) ||
          terminal ||
          changedDuringRaw && !isDragged) {
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

  double get _tapDistance =>
      config.tapCancelDistance ??
      ElPressGestureRecognizer.defaultConsecutiveTapDistance;

  Iterable<RenderElEvent> get _ancestors sync* {
    RenderObject? node = parent;
    while (node != null) {
      if (node is RenderElEvent && !node._disposed) yield node;
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
    final start =
        event is PointerDownEvent || event is PointerPanZoomStartEvent;
    if (start && (disabled || before == null)) return;
    if (!_team.observePointer(event) || disabled || _event == null) return;
    if (event is PointerDownEvent) {
      if (before != null &&
          before.hasSameTransformShape(_event!) &&
          (_hasDrag || _hasScale)) {
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
    final callback = _rawCallback(
      phase,
      input,
      reason: reason == null ? null : _cancelReason(reason),
    )..pointerCount = activePointerCount;
    _invoke(_handler(phase), callback);
    if (input is PointerSignalEvent && callback.defaultPrevented) {
      GestureBinding.instance.pointerSignalResolver.register(
        input,
        (event) => event.respond(allowPlatformDefault: false),
      );
    }
    return !callback.propagationStopped;
  }

  static ElEventCancelReason _cancelReason(ElGestureCancelReason? reason) =>
      switch (reason) {
        ElGestureCancelReason.arenaRejected =>
          ElEventCancelReason.otherGestureAccepted,
        ElGestureCancelReason.pointerCanceled =>
          ElEventCancelReason.pointerCanceled,
        ElGestureCancelReason.longPressAccepted =>
          ElEventCancelReason.selfGestureAccepted,
        ElGestureCancelReason.rejected ||
        ElGestureCancelReason.ineligible => ElEventCancelReason.tapRejected,
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
        preserveDuration:
            details.cancelReason == ElGestureCancelReason.ineligible,
      );
      if (_team.isDispatchingTerminal) return;
    }
    if (!details.isActive) return;
    final callback = _gestureCallback(details, phase);
    _invoke(_handler(phase), callback);
    if (callback.propagationStopped) details.stopPropagation();
    if (phase == ElEventPhase.longPress &&
        !callback.defaultPrevented &&
        details.isActive) {
      _team.claimPointer(details.pointer, cancelTap: true);
    }
  }

  void _handleTransform(ElTransformGestureDetails details) {
    if (_disposed) return;
    final phase = ElEventPhase.values.byName(details.phase.name);
    if (phase == ElEventPhase.dragCancel &&
        !details.started &&
        _event?.onDragDown == null) {
      return;
    }
    if (phase == ElEventPhase.dragStart) {
      final proxies = _collectDragProxies(details.dragAxis);
      if (proxies.isNotEmpty) _dragProxies[details.sequenceIdentity] = proxies;
      if (details.isPrimaryTarget && proxies.isNotEmpty) {
        _press.rejectTap(
          details.pointer,
          reason: ElGestureCancelReason.longPressAccepted,
        );
        for (final proxy in proxies) {
          proxy._team.cancelPress(
            details.pointer,
            reason: ElGestureCancelReason.arenaRejected,
          );
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
    if (phase == ElEventPhase.scaleStart &&
        !callback.defaultPrevented &&
        details.isActive) {
      for (final pointer in details.pointerIds) {
        _team.claimPointer(pointer, cancelTap: true);
      }
    }
  }

  bool _contains(Offset position) {
    if (!attached || !hasSize) return true;
    final inverse = Matrix4.tryInvert(getTransformTo(null));
    return inverse != null &&
        size.contains(MatrixUtils.transformPoint(inverse, position));
  }

  Offset _local(Offset position) =>
      attached ? globalToLocal(position) : position;
  Offset _localDelta(Offset position, Offset delta) =>
      _local(position) - _local(position - delta);

  @override
  MouseCursor get cursor => disabled
      ? SystemMouseCursors.forbidden
      : _event?.cursor ?? MouseCursor.defer;
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
      _invoke(
        _handler(ElEventPhase.pointerEnter),
        _rawCallback(ElEventPhase.pointerEnter, event),
      );
    }
  }

  /// 接收官方鼠标离开通知。
  void handlePointerExit(PointerExitEvent event) {
    _hoverDevices.remove(event.device);
    onHoverChanged?.call(_hoverDevices.isNotEmpty);
    if (!disabled && !_disposed) {
      _invoke(
        _handler(ElEventPhase.pointerExit),
        _rawCallback(ElEventPhase.pointerExit, event),
      );
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
    if (root is RenderElEvent) root.cancelAllPending();
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
