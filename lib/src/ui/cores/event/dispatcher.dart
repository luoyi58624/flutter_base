import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'callback.dart';
import 'event.dart';
import 'recognizers/recognizers.dart';

part 'interaction.dart';
part 'drag/output.dart';

/// 连接单个 RenderBox 与独立识别器，负责输入、业务适配和宿主生命周期。
///
/// 手势归属由官方竞技场决定，普通手势冒泡由识别器完成；本类不识别手势。
class ElEventDispatcher {
  /// 创建宿主控制器，测试中的临时宿主可关闭渲染树注册。
  ElEventDispatcher(this._owner, {bool register = true})
    : _registered = register {
    if (register) _registry[_owner] = this;
    _feedback = _TapFeedback((value) => onTapChanged?.call(value));
  }

  static final Expando<ElEventDispatcher> _registry = Expando(
    'ElEventDispatcher',
  );
  static final Map<int, _InputRoute> _routes = {};
  static final Expando<ElEventCallback> _callbacks = Expando('ElEventCallback');
  final RenderBox _owner;
  final bool _registered;
  final Map<int, _HostInput> _inputs = {};
  final Set<int> _passivePointers = {};
  final Map<int, GestureArenaEntry> _claims = {};
  final Expando<_GestureSnapshot> _snapshots = Expando('ElEventSnapshot');
  late final _TapFeedback _feedback;
  ElEvent? _event;
  ElPressGestureRecognizer? _press;
  ElTransformGestureRecognizer? _transform;
  final ElGestureArenaTeam _team = ElGestureArenaTeam();
  final Map<Object, _DragOutput> _dragOutputs = {};
  bool _disposed = false;
  bool _disposing = false;
  bool _canceling = false;
  int _generation = 0;
  int _tapGeneration = 0;
  int _transformGeneration = 0;
  int _updateRevision = 0;
  ElEventPhase? _rawPhase;
  bool _mayClaimNewPointer = false;
  bool get _dragging => _dragOutputs.isNotEmpty;
  Offset _lastPosition = Offset.zero;

  /// 获取渲染节点绑定的控制器，不创建新的控制器。
  static ElEventDispatcher? of(RenderBox node) => _registry[node];

  /// 按压反馈通知，监听它不会创建识别器或改变手势竞争。
  ValueChanged<bool>? onTapChanged;

  /// 宿主提供的全局范围判断，不把 RenderBox 交给识别器。
  bool Function(Offset position)? hitBoundsContainsGlobal;

  /// 平台提供的手势设备容差。
  DeviceGestureSettings? gestureSettings;

  /// 当前生效的局部配置，不从祖先继承。
  ElEventConfig get config => _event?.config ?? const ElEventConfig();

  /// 当前是否禁用。
  bool get disabled => _event?.disabled ?? false;

  /// 当前鼠标光标。
  MouseCursor get cursor => disabled
      ? SystemMouseCursors.forbidden
      : _event?.cursor ?? MouseCursor.defer;

  /// 当前按压反馈，触摸反馈可能短暂延迟或保留。
  bool get isTapPressed => _feedback.value;

  /// 当前是否有已开始的拖拽，仅供内部生命周期协调。
  bool get isDragged => _dragging;

  /// 尚未物理结束且仍向当前宿主投递的指针数。
  int get activePointerCount =>
      _inputs.values.where((input) => !input.ended && input.active).length;

  /// 当前参与的指针数量，供回归测试检查清理。
  int get debugRoutedPointerCount => activePointerCount;

  /// 当前事件声明，闭包热替换不会无故重置识别过程。
  ElEvent? get event => _event;
  set event(ElEvent? value) {
    if (_disposed || _disposing || identical(_event, value)) return;
    final revision = ++_updateRevision;
    final previous = _event;
    final refreshCursor =
        previous?.cursor != value?.cursor ||
        previous?.disabled != value?.disabled;
    final sameTap =
        previous != null &&
        value != null &&
        previous.hasSameNonDragShape(value);
    final sameTransform =
        previous != null &&
        value != null &&
        previous.hasSameTransformShape(value);
    final terminalReplacement =
        _rawPhase == ElEventPhase.pointerUp ||
        _rawPhase == ElEventPhase.pointerCancel ||
        _rawPhase == ElEventPhase.pointerPanZoomEnd;
    final rawStructureChanged =
        _rawPhase != null &&
        previous != null &&
        (value == null ||
            !previous.hasSameGestureShape(value, compareConfig: false));
    if (previous != null &&
        (value == null ||
            !previous.hasSameGestureShape(value) ||
            terminalReplacement)) {
      if (!sameTap || terminalReplacement) {
        _press?.cancel();
        _tapGeneration++;
      }
      if (!sameTransform ||
          terminalReplacement ||
          rawStructureChanged && !_dragging) {
        _cancelTransform();
        _transformGeneration++;
      }
      if (!sameTap) _feedback.cancel();
    }
    if (value == null || value.disabled) {
      terminateActivePointerSequencesIn(_owner, force: true);
      cancelAllPendingAtLastPosition();
    }
    if (revision != _updateRevision || _disposed) return;
    if (!sameTap && previous != null) _generation++;
    for (final input in _inputs.values) {
      input.generation = _generation;
    }
    _event = value;
    if (value != null && !value.disabled) {
      _configureRecognizers();
    }
    if (refreshCursor &&
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      RendererBinding.instance.ensureVisualUpdate();
    }
  }

  bool get _hasPrimaryTap =>
      _event?.onTap != null ||
      _event?.onDoubleTap != null ||
      _event?.onDoubleTapDown != null ||
      _event?.onTripleTap != null ||
      _event?.onTripleTapDown != null;

  bool get _hasPress =>
      _event != null &&
      (_inputs.values.any((input) => input.eager) ||
          [
            _event!.onTap,
            _event!.onDoubleTap,
            _event!.onDoubleTapDown,
            _event!.onTripleTap,
            _event!.onTripleTapDown,
            _event!.onLongPress,
            _event!.onSecondaryTapDown,
            _event!.onSecondaryTapUp,
            _event!.onSecondaryTap,
            _event!.onTertiaryTapDown,
            _event!.onTertiaryTapUp,
            _event!.onTertiaryTap,
            _event!.onForwardTapDown,
            _event!.onForwardTapUp,
            _event!.onForwardTap,
            _event!.onBackTapDown,
            _event!.onBackTapUp,
            _event!.onBackTap,
          ].any((handler) => handler != null));

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
  bool get _hasDrag =>
      _hasFreeDrag ||
      _hasVertical ||
      _hasHorizontal ||
      _event?.onDragDown != null;
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
    if (_hasPress) {
      final press = _press ??= ElPressGestureRecognizer(debugOwner: this)
        ..team = _team;
      press
        ..onAccepted = _accepted
        ..onReleased = _released
        ..gestureSettings = gestureSettings
        ..doubleTapInterval = config.doubleTapInterval
        ..tripleTapInterval = config.tripleTapInterval
        ..longPressDelay = config.longPressDelay
        ..tapSlopTolerance = config.tapCancelOnMove
            ? config.tapCancelDistance
            : double.infinity
        ..secondaryTapSlopTolerance = config.tapCancelDistance
        ..longPressSlopTolerance = config.longPressCancelDistance
        ..consecutiveTapDistance = config.tapCancelDistance
        ..deferTap = config.deferTap
        ..cancelTapOnLongPress = false
        ..isEligible = (phase, event) {
          final input = _inputs[event.pointer];
          return input != null &&
              input.active &&
              input.generation == _generation &&
              input.tapEligible &&
              (config.tapCancelOnMove || _contains(event.position)) &&
              (_handler(ElEventPhase.values.byName(phase.name)) != null ||
                  phase == ElGesturePhase.tap &&
                      (_event?.onDoubleTap != null ||
                          _event?.onTripleTap != null ||
                          _event?.onDoubleTapDown != null ||
                          _event?.onTripleTapDown != null));
        }
        ..onTapDown = _handlePress
        ..onTapUp = _handlePress
        ..onTap = _handlePress
        ..onTapCancel = _handlePress
        ..onDoubleTap = _event?.onDoubleTap == null ? null : _handlePress
        ..onDoubleTapDown = _event?.onDoubleTapDown == null
            ? null
            : _handlePress
        ..onTripleTap = _event?.onTripleTap == null ? null : _handlePress
        ..onTripleTapDown = _event?.onTripleTapDown == null
            ? null
            : _handlePress
        ..onLongPress = _event?.onLongPress == null ? null : _handlePress
        ..onSecondaryTapDown = _handlePress
        ..onSecondaryTapUp = _handlePress
        ..onSecondaryTap = _handlePress
        ..onTertiaryTapDown = _handlePress
        ..onTertiaryTapUp = _handlePress
        ..onTertiaryTap = _handlePress
        ..onForwardTapDown = _handlePress
        ..onForwardTapUp = _handlePress
        ..onForwardTap = _handlePress
        ..onBackTapDown = _handlePress
        ..onBackTapUp = _handlePress
        ..onBackTap = _handlePress;
    }
    if (_hasDrag || _hasScale) {
      final transform = _transform ??= ElTransformGestureRecognizer(
        debugOwner: this,
      )..team = _team;
      transform
        ..onAccepted = _accepted
        ..gestureSettings = gestureSettings
        ..supportedDevices = config.dragDevices
        ..startDistance = config.dragStartDistance
        ..horizontalAngle = config.dragHorizontalAngle
        ..minFlingDistance = config.dragMinFlingDistance
        ..minFlingVelocity = config.dragMinFlingVelocity
        ..maxFlingVelocity = config.dragMaxFlingVelocity
        ..axis = _axis
        ..lockAxis = _hasHorizontal && _hasVertical
        ..onDragDown = _hasDrag ? _handleTransform : null
        ..onDragStart = _hasDrag ? _handleTransform : null
        ..onDragUpdate = _hasDrag ? _handleTransform : null
        ..onDragEnd = _hasDrag ? _handleTransform : null
        ..onDragCancel = _hasDrag ? _handleTransform : null
        ..onScaleStart = _hasScale ? _handleTransform : null
        ..onScaleUpdate = _hasScale ? _handleTransform : null
        ..onScaleEnd = _hasScale ? _handleTransform : null
        ..onScaleCancel = _hasScale ? _handleTransform : null
        ..onRotationUpdate = _event?.onRotationUpdate == null
            ? null
            : _handleTransform;
    }
  }

  List<ElEventDispatcher> _chain() {
    final chain = <ElEventDispatcher>[this];
    RenderObject? node = _owner.parent;
    while (node != null) {
      if (node is RenderBox) {
        final member = of(node);
        if (member != null && !member._disposed && member.event != null) {
          chain.add(member);
        }
      }
      node = node.parent;
    }
    return chain;
  }

  void _bindRecognizers(_InputRoute route) {
    for (var index = route.chain.length - 1; index >= 0; index--) {
      final member = route.chain[index];
      if (!route.active.contains(member)) continue;
      member._configureRecognizers();
      ElPressGestureRecognizer? pressParent;
      ElTransformGestureRecognizer? transformParent;
      for (final ancestor in route.chain.skip(index + 1)) {
        if (!route.active.contains(ancestor)) continue;
        if (pressParent == null &&
            ancestor._hasPress &&
            ancestor._hasPrimaryTap == member._hasPrimaryTap) {
          pressParent = ancestor._press;
        }
        if (transformParent == null &&
            (ancestor._hasDrag || ancestor._hasScale) &&
            (!ancestor._hasDrag ||
                !member._hasDrag ||
                ancestor._axis == member._axis &&
                    ancestor.config.dragStartDistance ==
                        member.config.dragStartDistance)) {
          transformParent = ancestor._transform;
        }
      }
      member._press?.parent = pressParent;
      member._transform?.parent = transformParent;
    }
  }

  /// 转发真实命中输入，识别器自行使用官方 PointerRouter 跟踪后续输入。
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (_disposed || _disposing || _canceling || disabled || _event == null) {
      return;
    }
    _lastPosition = event.position;
    if (event is PointerHoverEvent) {
      _invoke(
        _handler(ElEventPhase.pointerHover),
        _rawCallback(ElEventPhase.pointerHover, event),
      );
      return;
    }
    if (event is PointerSignalEvent) {
      final callback = _rawCallback(ElEventPhase.pointerSignal, event);
      _invoke(_handler(callback.phase), callback);
      if (callback.defaultPrevented) {
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (event) => event.respond(allowPlatformDefault: false),
        );
      }
      return;
    }
    final start =
        event is PointerDownEvent || event is PointerPanZoomStartEvent;
    var route = _routes[event.pointer];
    if (start && route == null) {
      route = _InputRoute(event.pointer, _chain());
      _routes[event.pointer] = route;
      for (final member in route.chain) {
        member._inputs[event.pointer] = _HostInput(
          route,
          event,
          member._generation,
        );
      }
      for (var index = 0; index < route.chain.length; index++) {
        final member = route.chain[index];
        // 长按或侧键不能替祖先的主键点击提前占位，保留中间官方 Tap 的优先级。
        member._team.parent = route.chain
            .skip(index + 1)
            .where(
              (ancestor) => ancestor._hasPrimaryTap == member._hasPrimaryTap,
            )
            .firstOrNull
            ?._team;
      }
      final phase = event is PointerDownEvent
          ? ElEventPhase.pointerDown
          : ElEventPhase.pointerPanZoomStart;
      for (final member in route.chain) {
        if (!route.active.contains(member)) continue;
        if (route.requester != null && !identical(route.requester, member)) {
          continue;
        }
        member._inputs[event.pointer]?.rawStarted = true;
        final callback = member._rawCallback(phase, event)
          ..pointerCount = member.activePointerCount;
        callback.updateEagerGestureHandler(
          (callback, cancelTap, allowScale) =>
              member._claim(route!, callback, cancelTap, allowScale),
        );
        member._invoke(member._handler(phase), callback);
        if (callback.propagationStopped) {
          final boundary = route.chain.indexOf(member);
          route.active.removeAll(route.chain.skip(boundary + 1));
          break;
        }
      }
      _bindRecognizers(route);
    }
    final input = _inputs[event.pointer];
    if (input != null &&
        (event is PointerUpEvent ||
            event is PointerCancelEvent ||
            event is PointerPanZoomEndEvent)) {
      _endInput(input);
    }
    if (route == null ||
        input == null ||
        !input.active ||
        !route.active.contains(this)) {
      return;
    }
    input.lastEvent = event;
    if (start) {
      if (input.registered) return;
      input.registered = true;
      if (input.initialGeneration != _generation) return;
      if (event is PointerDownEvent) {
        if (_hasDrag || _hasScale) _transform?.addPointer(event);
        if (_hasPress) {
          input.pressRegistered = true;
          _press?.addPointer(event);
        }
        if (input.eager) {
          _press?.acceptPointer(event.pointer);
          _transform?.acceptPointer(event.pointer);
        }
        if (!_hasPress &&
            event.buttons == kPrimaryButton &&
            (onTapChanged != null ||
                _event?.onTapDown != null ||
                _event?.onTapUp != null ||
                _event?.onTapCancel != null)) {
          _passivePointers.add(event.pointer);
          input.tapGeneration = _tapGeneration;
          GestureBinding.instance.pointerRouter.addRoute(
            event.pointer,
            _handlePassiveInput,
            event.transform,
          );
        }
      } else if (event is PointerPanZoomStartEvent && (_hasDrag || _hasScale)) {
        _transform?.addPointerPanZoom(event);
      } else if (event is PointerPanZoomStartEvent &&
          _event?.onPointerPanZoomUpdate != null &&
          !input.eagerRegistered) {
        // 原始变换消费者预先报名，后续独占请求只能使用这个尚未落败的官方席位。
        _claims[event.pointer] = _team.add(event.pointer, _EagerClaim(this));
      }
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
    final terminal =
        event is PointerUpEvent ||
        event is PointerCancelEvent ||
        event is PointerPanZoomEndEvent;
    if (terminal) input.ended = true;
    final callback = _rawCallback(phase, event)
      ..pointerCount = activePointerCount;
    callback.updateEagerGestureHandler(
      (callback, cancelTap, allowScale) =>
          _claim(route!, callback, cancelTap, allowScale),
    );
    final previousRawPhase = _rawPhase;
    _rawPhase = phase;
    try {
      _invoke(_handler(phase), callback);
    } finally {
      _rawPhase = previousRawPhase;
    }
    if (!input.active || input.generation != _generation) return;
    if (event is PointerMoveEvent && input.down.buttons == kPrimaryButton) {
      _updateBounds(input, event);
    }
  }

  void _endInput(_HostInput input) {
    input.ended = true;
    final pointer = input.down.pointer;
    final route = input.route;
    scheduleMicrotask(() {
      if (identical(_inputs[pointer], input)) _inputs.remove(pointer);
      if (identical(_routes[pointer], route) &&
          route.chain.every(
            (member) => member._inputs[pointer]?.ended ?? true,
          )) {
        _routes.remove(pointer);
      }
    });
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
    if (input == null ||
        !input.active ||
        input.generation != _generation ||
        input.tapGeneration != _tapGeneration) {
      return;
    }
    if (event is PointerDownEvent &&
        (input.route.requester == null ||
            identical(input.route.requester, this))) {
      _tapDown(input, event);
    }
    if (event is PointerUpEvent) _tapUp(input, event);
    if (event is PointerCancelEvent) {
      _cancelTap(input, event, ElEventCancelReason.pointerCanceled);
    }
  }

  void _handlePress(ElPressGestureDetails details) {
    final snapshot = _snapshot(details);
    if (!_valid(snapshot, details.phase == ElGesturePhase.tapCancel)) return;
    final phase = ElEventPhase.values.byName(details.phase.name);
    final input = snapshot.input;
    if (phase == ElEventPhase.tapDown) {
      if (input.route.requester != null &&
          !identical(input.route.requester, this)) {
        return;
      }
      _tapDown(input, details.originalEvent);
    } else if (phase == ElEventPhase.tapUp) {
      _tapUp(input, details.originalEvent);
    } else if (phase == ElEventPhase.tapCancel) {
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
    if (!_valid(snapshot)) return;
    if (phase == ElEventPhase.tap && !input.tapEligible) return;
    final callback = _gestureCallback(details, phase);
    _invoke(_handler(phase), callback);
    if (callback.propagationStopped) details.stopPropagation();
    if (phase == ElEventPhase.longPress &&
        !callback.defaultPrevented &&
        _valid(snapshot)) {
      _claim(input.route, callback, true, false);
    }
  }

  void _handleTransform(ElTransformGestureDetails details) {
    final snapshot = _snapshot(details);
    final terminal = [
      ElGesturePhase.dragCancel,
      ElGesturePhase.dragEnd,
      ElGesturePhase.scaleCancel,
      ElGesturePhase.scaleEnd,
    ].contains(details.phase);
    final phase = ElEventPhase.values.byName(details.phase.name);
    final scaleFamily = [
      ElEventPhase.scaleStart,
      ElEventPhase.scaleUpdate,
      ElEventPhase.scaleEnd,
      ElEventPhase.scaleCancel,
      ElEventPhase.rotationUpdate,
    ].contains(phase);
    if (!_valid(snapshot, terminal, scaleFamily)) return;
    if (phase == ElEventPhase.scaleStart && !_prepareScale(details, snapshot)) {
      return;
    }
    if (phase == ElEventPhase.dragCancel &&
        !_dragOutputs.containsKey(details.sequenceIdentity) &&
        _event?.onDragDown == null) {
      return;
    }
    if (phase == ElEventPhase.dragStart) {
      final route = snapshot.input.route;
      if (route.dragIdentity != null &&
          !identical(route.dragIdentity, details.sequenceIdentity)) {
        _transform?.cancelMember(details.pointer, cancelScale: false);
        return;
      }
      route.dragIdentity = details.sequenceIdentity;
      _dragOutputs.remove(details.sequenceIdentity)?.dispose();
      snapshot.input.route.driver ??= this;
      final output = _DragOutput(this, details);
      _dragOutputs[details.sequenceIdentity] = output;
      if (output.proxies.isNotEmpty &&
          identical(snapshot.input.route.driver, this)) {
        snapshot.input.tapEligible = false;
        _cancelTap(
          snapshot.input,
          details.originalEvent,
          ElEventCancelReason.selfGestureAccepted,
        );
        _press?.rejectTap(details.pointer);
        for (final member in output.proxies) {
          final input = member._inputs[details.pointer];
          if (input == null) continue;
          input.tapEligible = false;
          member._cancelTap(
            input,
            details.originalEvent,
            ElEventCancelReason.otherGestureAccepted,
          );
          member._press?.cancelMember(details.pointer);
        }
      }
    }
    if (phase == ElEventPhase.dragUpdate) {
      if (identical(snapshot.input.route.driver, this)) {
        _dragOutputs[details.sequenceIdentity]?.update(details);
      }
      return;
    }
    if (phase == ElEventPhase.dragEnd || phase == ElEventPhase.dragCancel) {
      _dragOutputs.remove(details.sequenceIdentity)?.dispose();
    }
    final callback = _gestureCallback(details, phase);
    _invoke(_handler(phase, details.dragAxis), callback);
    if (callback.propagationStopped) details.stopPropagation();
    if (phase == ElEventPhase.scaleStart &&
        !callback.defaultPrevented &&
        _valid(snapshot, false, true)) {
      for (final input in _inputs.values.toList()) {
        if (!input.active && !input.scaleAllowed || input.ended) continue;
        input.active = true;
        input.accepted = true;
        _claim(input.route, callback, true, false);
      }
    }
  }

  bool _prepareScale(
    ElTransformGestureDetails details,
    _GestureSnapshot snapshot,
  ) {
    final inputs = _inputs.values
        .where((input) => !input.ended && (input.active || input.scaleAllowed))
        .toList();
    if (inputs.any((input) {
      final winner = input.route.winner;
      return winner != null &&
          !(winner._inputs[input.route.pointer]?.allowScale ?? false);
    })) {
      _transform?.cancelMember(details.pointer, cancelDrag: false);
      return false;
    }
    final members = inputs.expand((input) => input.route.chain).toSet();
    for (final member in members) {
      if (!member._dragging) continue;
      for (final input in inputs) {
        member._transform?.cancelMember(
          input.route.pointer,
          cancelScale: false,
        );
      }
      if (!_valid(snapshot, false, true)) return false;
    }
    return true;
  }

  _GestureSnapshot _snapshot(ElGestureDetails details) =>
      _snapshots[details.sequenceIdentity] ??= _GestureSnapshot(
        _inputs[details.pointer] ??
            _HostInput(
              _InputRoute(details.pointer, [this]),
              details.originalEvent,
              _generation,
            ),
        details is ElPressGestureDetails
            ? _tapGeneration
            : _transformGeneration,
        details is ElPressGestureDetails,
      );
  bool _valid(
    _GestureSnapshot snapshot, [
    bool terminal = false,
    bool scale = false,
  ]) =>
      !_disposed &&
      snapshot.generation ==
          (snapshot.press ? _tapGeneration : _transformGeneration) &&
      (terminal ||
          !disabled &&
              (snapshot.input.active || scale && snapshot.input.scaleAllowed));

  ElEventCallback _gestureCallback(
    ElGestureDetails details,
    ElEventPhase phase,
  ) {
    final transform = details is ElTransformGestureDetails ? details : null;
    final press = details is ElPressGestureDetails ? details : null;
    final callback = _callbacks[details.dispatchIdentity] ??= ElEventCallback(
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
    );
    callback.localPosition = details.localPosition;
    callback.tapCount = press?.tapCount ?? 0;
    callback.localDelta = transform?.localDelta ?? Offset.zero;
    callback.pointerCount = transform?.pointerCount ?? 0;
    callback.updateLocalDeltaResolver(
      (delta) => _localDelta(details.globalPosition, delta),
    );
    final route = _snapshot(details).input.route;
    callback.updateEagerGestureHandler(
      (callback, cancelTap, allowScale) =>
          _claim(route, callback, cancelTap, allowScale),
    );
    return callback;
  }

  void _claim(
    _InputRoute route,
    ElEventCallback callback,
    bool cancelTap,
    bool allowScale,
  ) {
    final input = _inputs[route.pointer];
    if (_disposed || disabled || input == null || !input.active) return;
    input.eager = true;
    input.route.requester ??= this;
    input.cancelSelfTap = input.cancelSelfTap || cancelTap;
    input.allowScale = allowScale;
    input.claimCallback = callback;
    if (_mayClaimNewPointer &&
        !input.ended &&
        !input.eagerRegistered &&
        !route.accepted) {
      input.eagerRegistered = true;
      final entry = _team.add(route.pointer, _EagerClaim(this));
      _claims[route.pointer] = entry;
      entry.resolve(GestureDisposition.accepted);
    }
    _press?.acceptPointer(route.pointer);
    _transform?.acceptPointer(route.pointer);
    _claims[route.pointer]?.resolve(GestureDisposition.accepted);
    if (!input.accepted && !route.accepted) return;
    _applyClaim(input);
  }

  void _accepted(int pointer) {
    _claims.remove(pointer);
    final input = _inputs[pointer];
    if (input == null || !input.active) return;
    input.accepted = true;
    input.route.accepted = true;
    final requester = input.route.requester;
    final request = requester?._inputs[pointer];
    if (requester != null && request != null && request.active) {
      requester._applyClaim(request);
    }
  }

  void _released(PointerUpEvent event) {
    final input = _inputs[event.pointer];
    if (input != null && identical(input.lastEvent.original, event.original)) {
      _feedback.up(input, config);
    }
  }

  void _applyClaim(_HostInput input) {
    final route = input.route;
    final callback = input.claimCallback;
    if (callback == null || !input.active || input.claiming) return;
    input.claiming = true;
    final cancelTap = input.cancelSelfTap;
    final allowScale = input.allowScale;
    route.winner = this;
    route.driver = this;
    for (final member in route.chain.toList()) {
      final target = member._inputs[route.pointer];
      if (target == null || !target.active) continue;
      if (identical(member, this)) {
        if (cancelTap) {
          target.tapEligible = false;
          _press?.rejectTap(route.pointer);
          _cancelTap(
            target,
            target.lastEvent,
            ElEventCancelReason.selfGestureAccepted,
          );
        }
      } else {
        target.active = false;
        target.scaleAllowed = allowScale;
        final canceled = PointerCancelEvent(
          pointer: route.pointer,
          position: callback.globalPosition,
          timeStamp: target.lastEvent.timeStamp,
          kind: target.down.kind == PointerDeviceKind.trackpad
              ? PointerDeviceKind.unknown
              : target.down.kind,
        );
        if (target.rawStarted) {
          member._invoke(
            member._handler(ElEventPhase.pointerCancel),
            member._rawCallback(
              ElEventPhase.pointerCancel,
              canceled,
              reason: ElEventCancelReason.otherGestureAccepted,
            ),
          );
        }
        member._cancelTap(
          target,
          target.lastEvent,
          ElEventCancelReason.otherGestureAccepted,
        );
        member._press?.cancelMember(route.pointer);
        member._transform?.cancelMember(
          route.pointer,
          cancelScale: !allowScale,
        );
      }
    }
    input.claiming = false;
  }

  bool _contains(Offset position) {
    if (hitBoundsContainsGlobal != null) {
      return hitBoundsContainsGlobal!(position);
    }
    if (!_owner.attached || !_owner.hasSize) return true;
    final inverse = Matrix4.tryInvert(_owner.getTransformTo(null));
    return inverse != null &&
        _owner.size.contains(MatrixUtils.transformPoint(inverse, position));
  }

  Offset _local(Offset position) =>
      _owner.attached ? _owner.globalToLocal(position) : position;
  Offset _localDelta(Offset position, Offset delta) =>
      _local(position) - _local(position - delta);
  ElEventCallback _rawCallback(
    ElEventPhase phase,
    PointerEvent event, {
    ElEventCancelReason? reason,
  }) {
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
    final input = _inputs[event.pointer];
    if (input != null) {
      callback.updateEagerGestureHandler(
        (callback, cancelTap, allowScale) =>
            _claim(input.route, callback, cancelTap, allowScale),
      );
    }
    return callback;
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
    final previousClaimPhase = _mayClaimNewPointer;
    _mayClaimNewPointer =
        (callback.originalEvent is PointerDownEvent ||
            callback.originalEvent is PointerPanZoomStartEvent) &&
        [
          ElEventPhase.pointerDown,
          ElEventPhase.tapDown,
          ElEventPhase.secondaryTapDown,
          ElEventPhase.tertiaryTapDown,
          ElEventPhase.forwardTapDown,
          ElEventPhase.backTapDown,
          ElEventPhase.pointerPanZoomStart,
        ].contains(callback.phase);
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
    } finally {
      _mayClaimNewPointer = previousClaimPhase;
    }
  }

  /// 转发 MouseTracker 的进入通知。
  void handlePointerEnter(PointerEnterEvent event) {
    if (!disabled && !_disposed) {
      _invoke(
        _handler(ElEventPhase.pointerEnter),
        _rawCallback(ElEventPhase.pointerEnter, event),
      );
    }
  }

  /// 转发 MouseTracker 的离开通知。
  void handlePointerExit(PointerExitEvent event) {
    if (!disabled && !_disposed) {
      _invoke(
        _handler(ElEventPhase.pointerExit),
        _rawCallback(ElEventPhase.pointerExit, event),
      );
    }
  }

  /// 取消当前宿主的活动输入与待发点击，结清后仍可复用。
  void cancelAllPending(PointerEvent event) {
    if (_canceling) return;
    _canceling = true;
    try {
      for (final input in _inputs.values.toList()) {
        if (input.active && !input.ended) {
          input.active = false;
          final canceled = PointerCancelEvent(
            pointer: input.down.pointer,
            position: input.lastEvent.position,
            timeStamp: input.lastEvent.timeStamp,
            kind: input.down.kind == PointerDeviceKind.trackpad
                ? PointerDeviceKind.unknown
                : input.down.kind,
          );
          _invoke(
            _handler(ElEventPhase.pointerCancel),
            _rawCallback(
              ElEventPhase.pointerCancel,
              canceled,
              reason: ElEventCancelReason.external,
            ),
          );
        }
        _cancelTap(input, event, ElEventCancelReason.external);
        input.active = false;
      }
      _press?.cancel();
      for (final entry in _claims.values.toList()) {
        entry.resolve(GestureDisposition.rejected);
      }
      _claims.clear();
      _cancelTransform();
      _feedback.cancel();
      for (final pointer in _passivePointers.toList()) {
        GestureBinding.instance.pointerRouter.removeRoute(
          pointer,
          _handlePassiveInput,
        );
      }
      _passivePointers.clear();
      final routes = _inputs.values.map((input) => input.route).toSet();
      _inputs.clear();
      for (final route in routes) {
        if (route.chain.every(
          (member) => !member._inputs.values.any(
            (input) =>
                identical(input.route, route) && input.active && !input.ended,
          ),
        )) {
          if (identical(_routes[route.pointer], route)) {
            _routes.remove(route.pointer);
          }
        }
      }
    } finally {
      _canceling = false;
    }
  }

  void _cancelTransform() {
    for (final pointer in _inputs.keys.toList()) {
      _transform?.cancelMember(pointer);
    }
    _transform?.cancel();
    for (final output in _dragOutputs.values.toList()) {
      output.dispose();
    }
    _dragOutputs.clear();
  }

  /// 使用最后输入位置取消当前宿主。
  void cancelAllPendingAtLastPosition() =>
      cancelAllPending(PointerCancelEvent(position: _lastPosition));

  /// 禁用或删除子树时同步结清活动输入与已经抬起的延迟点击。
  static void terminateActivePointerSequencesIn(
    RenderObject root, {
    bool force = false,
  }) {
    root.visitChildren(
      (child) => terminateActivePointerSequencesIn(child, force: force),
    );
    if (root is RenderBox) of(root)?.cancelAllPendingAtLastPosition();
  }

  /// 重新挂载时恢复注册，不重建仍有效的手势。
  void attach() {
    if (_registered && !_disposed) _registry[_owner] = this;
  }

  /// 暂时拆树保留手势；最终销毁由 dispose 统一结清。
  void detach({bool preserveEvent = false}) {
    if (!preserveEvent) cancelAllPendingAtLastPosition();
  }

  /// 释放输入、识别器、定时器和渲染树注册。
  void dispose() {
    if (_disposed || _disposing) return;
    _disposing = true;
    cancelAllPendingAtLastPosition();
    _disposed = true;
    _press?.dispose();
    _transform?.dispose();
    _inputs.clear();
    if (_registered && identical(_registry[_owner], this)) {
      _registry[_owner] = null;
    }
  }

  /// 测试隔离用，取消仍保留在物理输入路线中的宿主。
  static void debugResetEagerGestureOwners() {
    final members = _routes.values.expand((route) => route.chain).toSet();
    for (final member in members) {
      member.cancelAllPendingAtLastPosition();
    }
    _routes.clear();
  }
}
