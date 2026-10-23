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

/// 独立事件元素，仅适配命中、原始输入、反馈和业务默认动作。
///
/// 识别、普通冒泡和手势竞争直接使用独立识别器与 Flutter 竞技场。
class RenderElEvent extends RenderProxyBoxWithHitTestBehavior
    implements MouseTrackerAnnotation {
  /// 创建事件元素，反馈订阅本身不会报名手势竞技场。
  RenderElEvent({
    ElEvent event = const ElEvent(),
    this.onTapChanged,
    this.onHoverChanged,
    this.gestureSettings,
    super.child,
  }) : super(behavior: event.behavior) {
    _feedback = _TapFeedback((value) => onTapChanged?.call(value));
    this.event = event;
  }

  // 原始 Down 的弱引用仅冻结元素命中链，不保存竞技场归属或手势驱动者。
  static final _hitPaths = Expando<List<RenderElEvent>>('ElEvent hit path');
  static final _callbacks = Expando<ElEventCallback>('ElEvent callback');
  final _inputs = <int, _ElementInput>{};
  final _passivePointers = <int>{};
  final _snapshots = Expando<(_ElementInput, int, bool)>('ElEvent lifecycle');
  final _dragProxies = <Object, List<RenderElEvent>>{};
  final _hoverDevices = <int>{};
  final _team = ElGestureArenaTeam();
  late final _TapFeedback _feedback;
  ElPressGestureRecognizer? _press;
  ElTransformGestureRecognizer? _transform;
  ElEvent? _event;
  bool _disposed = false;
  bool _canceling = false;
  bool _mayClaimNewPointer = false;
  int _tapVersion = 0;
  int _transformVersion = 0;
  int _revision = 0;
  ElEventPhase? _rawPhase;
  Offset _lastPosition = Offset.zero;

  /// 元素按压反馈通知，不参与手势竞争。
  ValueChanged<bool>? onTapChanged;

  /// 元素悬停反馈通知。
  ValueChanged<bool>? onHoverChanged;

  /// 当前设备提供的官方手势容差。
  DeviceGestureSettings? gestureSettings;

  /// 当前局部配置，空字段由使用方采用默认行为。
  ElEventConfig get config => _event?.config ?? const ElEventConfig();

  /// 当前是否禁用。
  bool get disabled => _event?.disabled ?? false;

  /// 当前按压反馈。
  bool get isTapPressed => _feedback.value;

  /// 当前是否存在已公开的拖拽生命周期。
  bool get isDragged => _dragProxies.isNotEmpty;
  bool get _dragging => isDragged;

  /// 尚未物理结束且仍投递给当前元素的指针数。
  int get activePointerCount =>
      _inputs.values.where((input) => input.active && !input.ended).length;

  /// 用于检查元素输入清理的数量。
  int get debugRoutedPointerCount => activePointerCount;

  /// 当前元素是否已经销毁，仅供内部生命周期检查。
  bool get isDisposed => _disposed;

  /// 当前事件声明，同形闭包替换保留正在进行的识别。
  ElEvent? get event => _event;
  set event(ElEvent? value) {
    if (_disposed || identical(_event, value)) return;
    final revision = ++_revision;
    final previous = _event;
    final sameTap =
        previous != null &&
        value != null &&
        previous.hasSameNonDragShape(value);
    final sameTransform =
        previous != null &&
        value != null &&
        previous.hasSameTransformShape(value);
    final terminal =
        _rawPhase == ElEventPhase.pointerUp ||
        _rawPhase == ElEventPhase.pointerCancel ||
        _rawPhase == ElEventPhase.pointerPanZoomEnd;
    final rawStructureChanged =
        _rawPhase != null &&
        previous != null &&
        (value == null ||
            !previous.hasSameGestureShape(value, compareConfig: false));
    if (previous != null) {
      if (!sameTap || terminal) {
        _press?.cancelMember();
        _tapVersion++;
      }
      if (!sameTransform || terminal || rawStructureChanged && !_dragging) {
        _transform?.cancelMember(null);
        _dragProxies.clear();
        _transformVersion++;
      }
      if (!sameTap) _feedback.cancel();
    }
    if (value == null || value.disabled) {
      _cancelSubtree(this);
    }
    if (_disposed || revision != _revision) return;
    _event = value;
    behavior = value?.behavior ?? HitTestBehavior.opaque;
    if (value != null && !value.disabled) _configureRecognizers();
    if ((previous?.cursor != value?.cursor ||
            previous?.disabled != value?.disabled) &&
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
      if (node is RenderElEvent && !node._disposed && node.event != null) {
        yield node;
      }
      node = node.parent;
    }
  }

  bool _compatibleDrag(RenderElEvent other) =>
      !_hasDrag ||
      !other._hasDrag ||
      _axis == other._axis &&
          (_hasHorizontal && _hasVertical) ==
              (other._hasHorizontal && other._hasVertical) &&
          config.dragStartDistance == other.config.dragStartDistance &&
          config.dragHorizontalAngle == other.config.dragHorizontalAngle;

  void _bind(List<RenderElEvent> path, int pointer, {bool bindTeam = true}) {
    for (var index = path.length - 1; index >= 0; index--) {
      final member = path[index];
      member._configureRecognizers();
      final ancestors = path
          .skip(index + 1)
          .where((node) => node._inputs[pointer]?.active ?? false)
          .toList();
      member._press?.parent = ancestors
          .where(
            (node) =>
                node._hasPress && node._hasPrimaryTap == member._hasPrimaryTap,
          )
          .firstOrNull
          ?._press;
      member._transform?.parent = ancestors
          .where(
            (node) =>
                (node._hasDrag || node._hasScale) &&
                member._compatibleDrag(node),
          )
          .firstOrNull
          ?._transform;
      // 不兼容的拖拽各自向官方报名，避免在宿主中重新选择胜出者。
      final teamParent = ancestors
          .where((node) => node._hasPrimaryTap == member._hasPrimaryTap)
          .firstOrNull;
      if (!bindTeam) continue;
      member._team.parent =
          teamParent != null && member._compatibleDrag(teamParent)
          ? teamParent._team
          : null;
    }
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
    // 禁用后仍须结清已缓存命中路径的物理终态，避免保留旧输入。
    if (event is PointerUpEvent ||
        event is PointerCancelEvent ||
        event is PointerPanZoomEndEvent) {
      final input = _inputs[event.pointer];
      if (input != null) {
        input.lastEvent = event;
        input.ended = true;
        scheduleMicrotask(() {
          if (identical(_inputs[event.pointer], input)) {
            _inputs.remove(event.pointer);
          }
        });
      }
    }
    if (_disposed || _canceling || disabled || _event == null) return;
    _lastPosition = event.position;
    if (event is PointerHoverEvent || event is PointerSignalEvent) {
      final callback = _rawCallback(
        event is PointerHoverEvent
            ? ElEventPhase.pointerHover
            : ElEventPhase.pointerSignal,
        event,
      );
      _invoke(_handler(callback.phase), callback);
      if (event is PointerSignalEvent && callback.defaultPrevented) {
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (event) => event.respond(allowPlatformDefault: false),
        );
      }
      return;
    }
    final start =
        event is PointerDownEvent || event is PointerPanZoomStartEvent;
    if (start) {
      final key = event.original ?? event;
      final previousPath = _hitPaths[key];
      if (previousPath == null ||
          previousPath.first._disposed ||
          previousPath.first._inputs[event.pointer]?.ended != false) {
        final path = [this, ..._ancestors];
        _hitPaths[key] = path;
        for (final member in path) {
          member._inputs[event.pointer] = _ElementInput(
            path,
            event,
            member._tapVersion,
            member._transformVersion,
          );
        }
        _bind(path, event.pointer);
        final phase = event is PointerDownEvent
            ? ElEventPhase.pointerDown
            : ElEventPhase.pointerPanZoomStart;
        var stopped = false;
        for (final member in path) {
          final input = member._inputs[event.pointer]!;
          if (stopped) {
            input.active = false;
            continue;
          }
          // 待决独占只暂停后续原始 Down，成员取消必须等官方接受后执行。
          if (path.any((node) => node._inputs[event.pointer]?.claim != null)) {
            continue;
          }
          input.rawStarted = true;
          final callback = member._rawCallback(phase, event)
            ..pointerCount = member.activePointerCount;
          member._invoke(member._handler(phase), callback);
          // 原始指针的停止传播只裁剪元素命中链，手势冒泡仍由识别器负责。
          stopped = callback.propagationStopped;
        }
        _bind(path, event.pointer, bindTeam: false);
      }
    }
    final input = _inputs[event.pointer];
    if (input == null) return;
    input.lastEvent = event;
    if (!input.active) return;
    if (start) {
      if (input.registered) return;
      input.registered = true;
      if (event is PointerDownEvent) {
        if ((_hasDrag || _hasScale) &&
            input.transformVersion == _transformVersion) {
          _transform?.addPointer(event);
        }
        if (_hasPress && input.tapVersion == _tapVersion) {
          input.pressRegistered = true;
          _press?.addPointer(event);
        } else if (event.buttons == kPrimaryButton &&
            (onTapChanged != null ||
                _event?.onTapDown != null ||
                _event?.onTapUp != null ||
                _event?.onTapCancel != null)) {
          _passivePointers.add(event.pointer);
          GestureBinding.instance.pointerRouter.addRoute(
            event.pointer,
            _handlePassiveInput,
            event.transform,
          );
        }
      } else if (event is PointerPanZoomStartEvent) {
        if (_hasDrag || _hasScale) {
          _transform?.addPointerPanZoom(event);
        } else if (_event?.onPointerPanZoomUpdate != null) {
          input.entry ??= _team.add(event.pointer, _InputClaim(this));
        }
      }
      if (input.claim != null) _acceptInput(input);
      return;
    }
    final phase = switch (event) {
      PointerMoveEvent() => ElEventPhase.pointerMove,
      PointerUpEvent() => ElEventPhase.pointerUp,
      PointerCancelEvent() => ElEventPhase.pointerCancel,
      PointerPanZoomUpdateEvent() => ElEventPhase.pointerPanZoomUpdate,
      PointerPanZoomEndEvent() => ElEventPhase.pointerPanZoomEnd,
      _ => null,
    };
    if (phase == null) return;
    final previousPhase = _rawPhase;
    _rawPhase = phase;
    try {
      _invoke(
        _handler(phase),
        _rawCallback(phase, event)..pointerCount = activePointerCount,
      );
    } finally {
      _rawPhase = previousPhase;
    }
    if (input.active &&
        event is PointerMoveEvent &&
        input.down.buttons == kPrimaryButton) {
      _updateBounds(input, event);
    }
  }

  void _handlePassiveInput(PointerEvent event) {
    final input = _inputs[event.pointer];
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      GestureBinding.instance.pointerRouter.removeRoute(
        event.pointer,
        _handlePassiveInput,
      );
      _passivePointers.remove(event.pointer);
    }
    if (input == null || !input.active || input.tapVersion != _tapVersion) {
      return;
    }
    if (event is PointerDownEvent) _tapDown(input, event);
    if (event is PointerUpEvent) _tapUp(input, event);
    if (event is PointerCancelEvent) {
      _cancelTap(input, event, ElEventCancelReason.pointerCanceled);
    }
  }

  (_ElementInput, int, bool) _snapshot(ElGestureDetails details) =>
      _snapshots[details.sequenceIdentity] ??= (
        _inputs[details.pointer] ??
            _ElementInput(
              [this],
              details.originalEvent,
              _tapVersion,
              _transformVersion,
            ),
        details is ElPressGestureDetails ? _tapVersion : _transformVersion,
        details is ElPressGestureDetails,
      );

  bool _valid(
    (_ElementInput, int, bool) snapshot, [
    bool terminal = false,
    bool scale = false,
  ]) =>
      !_disposed &&
      snapshot.$2 == (snapshot.$3 ? _tapVersion : _transformVersion) &&
      (terminal ||
          !disabled &&
              (snapshot.$1.active || scale && snapshot.$1.scaleAllowed));

  void _handlePress(ElPressGestureDetails details) {
    final snapshot = _snapshot(details);
    final input = snapshot.$1;
    if (!_valid(snapshot, details.phase == ElGesturePhase.tapCancel)) return;
    final phase = ElEventPhase.values.byName(details.phase.name);
    if (phase == ElEventPhase.tapDown) {
      _tapDown(input, details.originalEvent);
      if (!input.tapVisible) return;
    }
    if (phase == ElEventPhase.tapUp) _tapUp(input, details.originalEvent);
    if (phase == ElEventPhase.tapCancel) {
      input.tapEligible = false;
      final reason = switch (details.cancelReason) {
        ElGestureCancelReason.arenaRejected =>
          ElEventCancelReason.otherGestureAccepted,
        ElGestureCancelReason.pointerCanceled =>
          ElEventCancelReason.pointerCanceled,
        ElGestureCancelReason.longPressAccepted =>
          ElEventCancelReason.selfGestureAccepted,
        ElGestureCancelReason.rejected => ElEventCancelReason.tapRejected,
        _ => ElEventCancelReason.external,
      };
      _cancelTap(input, details.originalEvent, reason);
      return;
    }
    if (!_valid(snapshot) || phase == ElEventPhase.tap && !input.tapEligible) {
      return;
    }
    final callback = _gestureCallback(details, phase);
    _invoke(_handler(phase), callback);
    if (callback.propagationStopped) details.stopPropagation();
    if (phase == ElEventPhase.longPress &&
        !callback.defaultPrevented &&
        _valid(snapshot)) {
      _claim(input, callback, true, false);
    }
  }

  void _handleTransform(ElTransformGestureDetails details) {
    final snapshot = _snapshot(details);
    final input = snapshot.$1;
    final phase = ElEventPhase.values.byName(details.phase.name);
    final terminal =
        phase == ElEventPhase.dragEnd ||
        phase == ElEventPhase.dragCancel ||
        phase == ElEventPhase.scaleEnd ||
        phase == ElEventPhase.scaleCancel;
    final scale =
        phase == ElEventPhase.scaleStart ||
        phase == ElEventPhase.scaleUpdate ||
        phase == ElEventPhase.scaleEnd ||
        phase == ElEventPhase.scaleCancel ||
        phase == ElEventPhase.rotationUpdate;
    if (!_valid(snapshot, terminal, scale)) return;
    if (phase == ElEventPhase.scaleStart) {
      final members = _inputs.values
          .where(
            (input) => !input.ended && (input.active || input.scaleAllowed),
          )
          .expand((input) => input.path)
          .toSet();
      for (final member in members) {
        if (member._dragging) {
          member._transform?.cancelMember(null, cancelScale: false);
        }
      }
      if (!_valid(snapshot, false, true)) return;
    }
    if (phase == ElEventPhase.dragCancel &&
        !_dragProxies.containsKey(details.sequenceIdentity) &&
        _event?.onDragDown == null) {
      return;
    }
    if (phase == ElEventPhase.dragStart) {
      final proxies = _collectDragProxies(details.dragAxis);
      _dragProxies[details.sequenceIdentity] = proxies;
      if (details.isPrimaryTarget && proxies.isNotEmpty) {
        input.tapEligible = false;
        _press?.rejectTap(details.pointer);
        _cancelTap(
          input,
          details.originalEvent,
          ElEventCancelReason.selfGestureAccepted,
        );
        for (final member in proxies) {
          final target = member._inputs[details.pointer];
          if (target == null) continue;
          target.tapEligible = false;
          member._cancelTap(
            target,
            details.originalEvent,
            ElEventCancelReason.otherGestureAccepted,
          );
          member._press?.cancelMember(details.pointer);
        }
      }
    }
    if (phase == ElEventPhase.dragUpdate) {
      if (details.isPrimaryTarget) _dispatchDragUpdate(details, snapshot);
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
        _valid(snapshot, false, true)) {
      for (final target in _inputs.values.toList()) {
        if (target.ended || !target.active && !target.scaleAllowed) continue;
        target.active = true;
        target.accepted = true;
        _claim(target, callback, true, false);
      }
    }
  }

  void _claim(
    _ElementInput input,
    ElEventCallback callback,
    bool cancelTap,
    bool allowScale,
  ) {
    if (_disposed || disabled || !input.active) return;
    input.claim = (
      callback,
      cancelTap || (input.claim?.$2 ?? false),
      allowScale,
    );
    if (_mayClaimNewPointer &&
        !input.ended &&
        !input.accepted &&
        input.entry == null) {
      input.entry = _team.add(input.down.pointer, _InputClaim(this));
    }
    _acceptInput(input);
  }

  void _acceptInput(_ElementInput input) {
    final pointer = input.down.pointer;
    _press?.acceptPointer(pointer);
    _transform?.acceptPointer(pointer);
    input.entry?.resolve(GestureDisposition.accepted);
    if (input.accepted) _applyClaim(input);
  }

  void _accepted(int pointer) {
    final input = _inputs[pointer];
    if (input == null) return;
    // 官方已经将本次输入判给 El 协作成员，原始回调此后可请求元素内排他。
    for (final member in input.path) {
      final target = member._inputs[pointer];
      if (target == null) continue;
      target.entry = null;
      target.accepted = true;
    }
    for (final member in input.path) {
      final target = member._inputs[pointer];
      if (target != null && target.active && target.claim != null) {
        member._applyClaim(target);
      }
    }
  }

  void _applyClaim(_ElementInput input) {
    final claim = input.claim;
    if (claim == null || !input.active || input.claiming) return;
    input.claiming = true;
    try {
      for (final member in input.path) {
        final target = member._inputs[input.down.pointer];
        if (target == null || !target.active) continue;
        if (identical(member, this)) {
          if (claim.$2) {
            target.tapEligible = false;
            _press?.rejectTap(input.down.pointer);
            _cancelTap(
              target,
              target.lastEvent,
              ElEventCancelReason.selfGestureAccepted,
            );
          }
        } else {
          target.active = false;
          target.scaleAllowed = claim.$3;
          if (target.rawStarted) {
            member._invoke(
              member._handler(ElEventPhase.pointerCancel),
              member._rawCallback(
                ElEventPhase.pointerCancel,
                _cancelEvent(target, claim.$1.globalPosition),
                reason: ElEventCancelReason.otherGestureAccepted,
              ),
            );
          }
          member._cancelTap(
            target,
            target.lastEvent,
            ElEventCancelReason.otherGestureAccepted,
          );
          member._press?.cancelMember(input.down.pointer);
          member._transform?.cancelMember(
            input.down.pointer,
            cancelScale: !claim.$3,
          );
        }
      }
    } finally {
      input.claiming = false;
    }
  }

  PointerCancelEvent _cancelEvent(_ElementInput input, [Offset? position]) =>
      PointerCancelEvent(
        pointer: input.down.pointer,
        position: position ?? input.lastEvent.position,
        timeStamp: input.lastEvent.timeStamp,
        kind: input.down.kind == PointerDeviceKind.trackpad
            ? PointerDeviceKind.unknown
            : input.down.kind,
      );

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

  /// 接收官方 MouseTracker 进入事件，同时维护多鼠标悬停反馈。
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

  /// 接收官方 MouseTracker 离开事件。
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

  /// 结清当前元素的输入和延迟反馈，取消其他元素通过识别器成员原语完成。
  void cancelAllPending(PointerEvent event) {
    if (_canceling) return;
    _canceling = true;
    try {
      for (final input in _inputs.values.toList()) {
        if (input.active && !input.ended && input.rawStarted) {
          _invoke(
            _handler(ElEventPhase.pointerCancel),
            _rawCallback(
              ElEventPhase.pointerCancel,
              _cancelEvent(input),
              reason: ElEventCancelReason.external,
            ),
          );
        }
        _cancelTap(input, event, ElEventCancelReason.external);
        input.active = false;
        input.entry?.resolve(GestureDisposition.rejected);
      }
      _press?.cancelMember();
      _transform?.cancelMember(null);
      _dragProxies.clear();
      _feedback.cancel();
      for (final pointer in _passivePointers.toList()) {
        GestureBinding.instance.pointerRouter.removeRoute(
          pointer,
          _handlePassiveInput,
        );
      }
      _passivePointers.clear();
    } finally {
      _canceling = false;
    }
  }

  /// 使用最后输入位置结清元素。
  void cancelAllPendingAtLastPosition() =>
      cancelAllPending(PointerCancelEvent(position: _lastPosition));

  static void _cancelSubtree(RenderObject root) {
    root.visitChildren(_cancelSubtree);
    if (root is RenderElEvent) root.cancelAllPendingAtLastPosition();
  }

  @override
  void dispose() {
    if (_disposed) return;
    cancelAllPendingAtLastPosition();
    _disposed = true;
    _press?.dispose();
    _transform?.dispose();
    _inputs.clear();
    super.dispose();
  }
}
