part of 'render.dart';

/// 将声明映射到原生识别器及业务回调，不维护另一套手势路线。
extension _EventBinding on RenderElEvent {
  bool get _hasPrimaryTap =>
      _event?.onTap != null ||
      _event?.onDoubleTap != null ||
      _event?.onDoubleTapDown != null ||
      _event?.onTripleTap != null ||
      _event?.onTripleTapDown != null;

  bool get _hasPress =>
      _event != null &&
      (_inputs.values.any((input) => input.claim != null) ||
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
        ..onReleased = (event) {
          final input = _inputs[event.pointer];
          if (input != null &&
              identical(
                input.lastEvent.original ?? input.lastEvent,
                event.original ?? event,
              )) {
            _feedback.up(input);
          }
        }
        ..gestureSettings = gestureSettings
        ..doubleTapInterval = config.doubleTapInterval
        ..tripleTapInterval = config.tripleTapInterval
        ..longPressDelay = config.longPressDelay
        ..tapSlopTolerance = config.tapCancelOnMove == true
            ? _tapDistance
            : double.infinity
        ..secondaryTapSlopTolerance = _tapDistance
        ..longPressSlopTolerance = config.longPressCancelDistance
        ..consecutiveTapDistance = config.tapCancelDistance
        ..deferTap = config.deferTap
        ..cancelTapOnLongPress = false
        ..isEligible = (phase, event) {
          final input = _inputs[event.pointer];
          return input != null &&
              input.active &&
              input.tapEligible &&
              (config.tapCancelOnMove == true || _contains(event.position)) &&
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

  ElEventCallback _gestureCallback(
    ElGestureDetails details,
    ElEventPhase phase,
  ) {
    final transform = details is ElTransformGestureDetails ? details : null;
    final press = details is ElPressGestureDetails ? details : null;
    final callback = RenderElEvent._callbacks[details.dispatchIdentity] ??=
        ElEventCallback(
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
    final input = _snapshot(details).$1;
    callback.updateEagerGestureHandler(
      (callback, cancelTap, allowScale) =>
          _claim(input, callback, cancelTap, allowScale),
    );
    return callback;
  }

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
            _claim(input, callback, cancelTap, allowScale),
      );
    }
    return callback;
  }

  List<RenderElEvent> _collectDragProxies(Axis? axis) {
    List<RenderElEvent>? proxies;
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

  void _dispatchDragUpdate(
    ElTransformGestureDetails details,
    (_ElementInput, int, bool) snapshot,
  ) {
    final proxies = _dragProxies[details.sequenceIdentity];
    if (proxies == null) return;
    bool isActive() =>
        _valid(snapshot) && _dragProxies.containsKey(details.sequenceIdentity);
    final callback = _gestureCallback(details, ElEventPhase.dragUpdate)
      ..dragPipelineActive = proxies.isNotEmpty
      ..hasAncestorDragConsumer = _transform?.parent != null;
    for (final member in proxies.reversed) {
      if (!isActive()) return;
      _invokeDragProxy(
        member,
        member.event?.dragProxy?.onDragPreUpdate,
        callback,
      );
    }
    if (!isActive()) return;
    // 代理共享消费余量，主处理器沿用同一回调并恢复自身坐标与独占入口。
    if (proxies.isNotEmpty) _gestureCallback(details, ElEventPhase.dragUpdate);
    _invoke(_handler(ElEventPhase.dragUpdate, details.dragAxis), callback);
    if (callback.propagationStopped) details.stopPropagation();
    for (final member in proxies) {
      if (!isActive() || callback.remainingDelta == Offset.zero) break;
      _invokeDragProxy(
        member,
        member.event?.dragProxy?.onDragOverflow,
        callback,
      );
    }
  }

  void _invokeDragProxy(
    RenderElEvent member,
    ElEventHandler? handler,
    ElEventCallback callback,
  ) {
    if (member._disposed || member.disabled || handler == null) return;
    callback.localPosition = member._local(callback.globalPosition);
    callback.localDelta = member._localDelta(
      callback.globalPosition,
      callback.delta,
    );
    callback.updateLocalDeltaResolver(
      (delta) => member._localDelta(callback.globalPosition, delta),
    );
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
}
