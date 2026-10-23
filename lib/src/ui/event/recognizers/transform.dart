part of 'recognizers.dart';

/// 在官方竞技场内统一识别拖拽、缩放和旋转。
///
/// 每根指针分别参赛，只有获胜的指针才能驱动正式手势；新增指针落败不会
/// 撤销已经获胜的拖拽。多指拖拽采用 latestPointer：最新获胜指针驱动，
/// 抬起后交回仍获胜的指针。缩放、旋转只使用已获胜的触点。
///
/// [parent] 是 El 回调的冒泡订阅者，不会为同一指针重复参赛；官方识别器
/// 仍然独立竞争。本类直接识别官方采样输入，不做第二次帧重采样。
class ElTransformGestureRecognizer extends _ElGestureRecognizer {
  /// 创建独立变换识别器；[axis] 为空时自由拖拽，[lockAxis] 可按起手方向锁轴。
  ElTransformGestureRecognizer({
    this.config = const ElEventConfig(),
    this.parent,
    this.axis,
    this.lockAxis = false,
    super.debugOwner,
    super.supportedDevices,
    AllowedButtonsFilter? allowedButtonsFilter,
    super.globalToLocal,
  }) : super(
         allowedButtonsFilter: allowedButtonsFilter ?? _primaryTransformButton,
       );

  static bool _primaryTransformButton(int buttons) => buttons == kPrimaryButton;

  /// 下一轮手势使用的配置，进行中的指针序列保留开始时的快照。
  ElEventConfig config;

  /// El 冒泡父级；在一次指针序列开始时冻结路线。
  ElTransformGestureRecognizer? parent;

  /// 拖拽轴；为空时允许二维拖拽，不限制缩放与旋转。
  Axis? axis;

  /// [axis] 为空时，是否按照起手方向锁定水平或垂直轴。
  bool lockAxis;

  /// 拖拽候选按下；此阶段尚未取得官方手势所有权。
  ElEventHandler? onDragDown;

  /// 拖拽超过阈值并取得官方所有权后调用，不补发阈值内位移。
  ElEventHandler? onDragStart;

  /// 已获胜拖拽的位移更新。
  ElEventHandler? onDragUpdate;

  /// 已获胜拖拽正常释放，速度按当前配置过滤并限幅。
  ElEventHandler? onDragEnd;

  /// 拖拽候选落败、平台取消或识别器销毁。
  ElEventHandler? onDragCancel;

  /// 至少两个已获胜触点或触控板开始变换。
  ElEventHandler? onScaleStart;

  /// 缩放更新；只有声明缩放或旋转回调时才识别多指变换。
  ElEventHandler? onScaleUpdate;

  /// 变换正常结束，剩余单指可继续原有拖拽。
  ElEventHandler? onScaleEnd;

  /// 变换被平台、竞技场或销毁取消。
  ElEventHandler? onScaleCancel;

  /// 旋转更新，弧度从本轮变换开始累计。
  ElEventHandler? onRotationUpdate;

  _TransformSession? _session;
  bool _disposing = false;

  @override
  ElTransformGestureRecognizer? get _bubbleParent => parent;

  @override
  ElEventHandler? _handlerFor(ElEventPhase phase) => switch (phase) {
    ElEventPhase.dragDown => onDragDown,
    ElEventPhase.dragStart => onDragStart,
    ElEventPhase.dragUpdate => onDragUpdate,
    ElEventPhase.dragEnd => onDragEnd,
    ElEventPhase.dragCancel => onDragCancel,
    ElEventPhase.scaleStart => onScaleStart,
    ElEventPhase.scaleUpdate => onScaleUpdate,
    ElEventPhase.scaleEnd => onScaleEnd,
    ElEventPhase.scaleCancel => onScaleCancel,
    ElEventPhase.rotationUpdate => onRotationUpdate,
    _ => null,
  };

  static const _dragPhases = <ElEventPhase>[
    ElEventPhase.dragDown,
    ElEventPhase.dragStart,
    ElEventPhase.dragUpdate,
    ElEventPhase.dragEnd,
    ElEventPhase.dragCancel,
  ];
  static const _scalePhases = <ElEventPhase>[
    ElEventPhase.scaleStart,
    ElEventPhase.scaleUpdate,
    ElEventPhase.scaleEnd,
    ElEventPhase.scaleCancel,
    ElEventPhase.rotationUpdate,
  ];

  bool _allowsKind(PointerDeviceKind kind) =>
      (_session?.config ?? config).dragDevices?.contains(kind) ?? true;

  bool get _hasHandlers =>
      _dragPhases.any(_hasHandlerInChain) ||
      _scalePhases.any(_hasHandlerInChain);

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_disposed || _disposing) return false;
    if (_isDelegated(event.pointer)) return true;
    return _allowsKind(event.kind) &&
        _hasHandlers &&
        super.isPointerAllowed(event);
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) {
    if (_disposed || _disposing) return false;
    if (_isDelegated(event.pointer)) return true;
    return _allowsKind(event.kind) &&
        _hasHandlers &&
        super.isPointerPanZoomAllowed(event);
  }

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {
    // 不支持的额外按钮或设备不能否决另一根已在拖动的指针。
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_delegatePointer(event)) return;
    _addTransformPointer(event);
    super.addAllowedPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    if (_delegatePointer(event)) return;
    _addTransformPointer(event);
    super.addAllowedPointerPanZoom(event);
    startTrackingPointer(event.pointer, event.transform);
  }

  void _addTransformPointer(PointerEvent event) {
    var session = _session;
    if (session == null) {
      final route = _beginRoute(event);
      session = _TransformSession(
        route,
        config.copyWith(
          dragDevices: config.dragDevices == null
              ? null
              : Set<PointerDeviceKind>.of(config.dragDevices!),
        ),
        axis,
        lockAxis,
        _dragPhases.any((phase) => _routeHasHandler(route, phase)),
        _scalePhases.any((phase) => _routeHasHandler(route, phase)),
        _scalePhases
            .where((phase) => phase != ElEventPhase.rotationUpdate)
            .any((phase) => _routeHasHandler(route, phase)),
        _routeHasHandler(route, ElEventPhase.rotationUpdate),
      );
      _session = session;
    } else {
      _beginRoute(event, route: session.route);
    }
    session.pointers[event.pointer] = _TransformPointer(event);
    _resetCandidateGeometry(session);
  }

  @override
  void handleEvent(PointerEvent event) {
    final session = _session;
    final pointer = session?.pointers[event.pointer];
    if (session == null || pointer == null || _disposed || _disposing) return;
    pointer.event = event;
    if (event is PointerDownEvent || event is PointerPanZoomStartEvent) {
      pointer.delivered = true;
      if (!session.downDispatched && session.hasDrag) {
        session.downDispatched = true;
        _emit(session, ElEventPhase.dragDown, event);
        if (!_isCurrent(session)) return;
      }
      if (session.dragStarted || session.scaleStarted) {
        // 新指针必须先赢得自己的竞技场，不能直接加入已有变换。
        resolvePointer(event.pointer, GestureDisposition.accepted);
        if (!_isCurrent(session)) return;
      }
      if (pointer.accepted) _acceptedRosterChanged(session, event);
      return;
    }

    if (event is PointerMoveEvent) {
      if (event.buttons != pointer.down.buttons) {
        _removePointer(session, pointer, event, canceled: true);
        return;
      }
      pointer.position = event.position;
      pointer.localPosition = event.localPosition;
    } else if (event is PointerPanZoomUpdateEvent) {
      pointer.position = event.position + event.pan;
      pointer.localPosition = event.localPosition + event.localPan;
      pointer.panScale = event.scale;
      pointer.panRotation = event.rotation;
    } else if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
      _removePointer(session, pointer, event, canceled: false);
      return;
    } else if (event is PointerCancelEvent) {
      _removePointer(session, pointer, event, canceled: true);
      return;
    } else {
      return;
    }

    if (!event.synthesized) {
      pointer.addVelocitySample(event.timeStamp, pointer.localPosition);
    }
    final wasDragging = session.dragStarted;
    final wasScaling = session.scaleStarted;
    _considerThresholds(session, pointer, event);
    if (!_isCurrent(session) || !pointer.accepted) return;

    _startReadyGestures(session, event);
    if (!_isCurrent(session)) return;

    if (wasDragging && session.dragStarted && session.driver == event.pointer) {
      final localDelta = pointer.localPosition - pointer.lastOutputLocal;
      pointer.lastOutputLocal = pointer.localPosition;
      final projected = _project(localDelta, session.acceptedAxis);
      final delta = _toGlobalDelta(event, pointer.localPosition, projected);
      session.dragOffset += delta;
      _emit(session, ElEventPhase.dragUpdate, event, delta: delta);
      if (!_isCurrent(session)) return;
    }
    if (wasScaling && session.scaleStarted) {
      _updateScale(session, event);
    }
  }

  bool _isCurrent(_TransformSession session) =>
      identical(_session, session) && session.route.active && !_disposed;

  void _considerThresholds(
    _TransformSession session,
    _TransformPointer pointer,
    PointerEvent event,
  ) {
    if (session.hasDrag && !session.dragThresholdMet) {
      final moved = pointer.localPosition - pointer.initialLocal;
      final candidateAxis =
          session.axis ??
          (session.lockAxis ? _axisFor(moved, session.config) : null);
      final intendedAxis = _axisFor(moved, session.config);
      if (candidateAxis == null || candidateAxis == intendedAxis) {
        final projected = _project(moved, candidateAxis);
        final globalMoved = _toGlobalDelta(
          event,
          pointer.localPosition,
          projected,
        );
        final threshold =
            session.config.dragStartDistance ??
            (candidateAxis == Axis.vertical || session.axis != null
                ? computeHitSlop(event.kind, gestureSettings)
                : computePanSlop(event.kind, gestureSettings));
        if (globalMoved.distance > threshold) {
          pointer.dragThresholdMet = true;
          pointer.candidateAxis = candidateAxis;
          pointer.direction = _directionFor(moved, session.config);
          if (pointer.accepted) _acceptDragThreshold(session, pointer);
          resolvePointer(event.pointer, GestureDisposition.accepted);
        }
      }
    }
    if (!_isCurrent(session) ||
        !session.hasScale ||
        session.scaleThresholdMet) {
      return;
    }
    final geometry = _geometry(session, acceptedOnly: false);
    if (!geometry.canScale) return;
    final initial = session.candidateGeometry;
    if (initial == null || !initial.canScale) {
      session.candidateGeometry = geometry;
      return;
    }
    final changed =
        session.canZoom &&
            ((geometry.span - initial.span).abs() >
                    computeScaleSlop(event.kind) ||
                (geometry.panScale / initial.panScale - 1).abs() > 0.05) ||
        (session.hasDrag || session.canZoom) &&
            (geometry.focal - initial.focal).distance >
                computePanSlop(event.kind, gestureSettings) ||
        session.canRotate &&
            (_angleDelta(geometry.angle - initial.angle).abs() > 0.05 ||
                (geometry.panRotation - initial.panRotation).abs() > 0.05);
    if (changed) {
      session.scaleThresholdMet = true;
      for (final id in session.pointers.keys.toList()) {
        if (!_isCurrent(session)) return;
        resolvePointer(id, GestureDisposition.accepted);
      }
    }
  }

  @override
  void acceptGesture(int pointer) {
    final session = _session;
    final tracked = session?.pointers[pointer];
    if (session == null || tracked == null || tracked.accepted) return;
    tracked.accepted = true;
    if (tracked.dragThresholdMet) _acceptDragThreshold(session, tracked);
    session.acceptedOrder.add(pointer);
    session.driver = pointer;
    tracked.lastOutputLocal = tracked.localPosition;
    if (tracked.delivered) _acceptedRosterChanged(session, tracked.event);
  }

  void _acceptDragThreshold(
    _TransformSession session,
    _TransformPointer pointer,
  ) {
    if (session.dragStarted) return;
    session.dragThresholdMet = true;
    session.acceptedAxis = pointer.candidateAxis;
    session.direction = pointer.direction;
  }

  void _acceptedRosterChanged(_TransformSession session, PointerEvent event) {
    if (!_isCurrent(session)) return;
    _rebaseScale(session);
    if (session.dragStarted &&
        session.hasScale &&
        _geometry(session).canScale) {
      session.scaleThresholdMet = true;
    }
    _startReadyGestures(session, event);
  }

  void _startReadyGestures(_TransformSession session, PointerEvent event) {
    final owned = session.pointers.values
        .where((pointer) => pointer.accepted && pointer.delivered)
        .toList();
    if (owned.isEmpty) return;
    if (session.hasDrag && session.dragThresholdMet && !session.dragStarted) {
      session.dragStarted = true;
      for (final pointer in owned) {
        pointer.lastOutputLocal = pointer.localPosition;
      }
      _emit(session, ElEventPhase.dragStart, event);
      if (!_isCurrent(session)) return;
    }
    if (session.dragStarted &&
        session.hasScale &&
        _geometry(session).canScale) {
      session.scaleThresholdMet = true;
    }
    if (session.hasScale &&
        session.scaleThresholdMet &&
        !session.scaleStarted &&
        _geometry(session).canScale) {
      session.scaleStarted = true;
      session.scale = 1;
      session.rotation = 0;
      session.scaleVelocity = VelocityTracker.withKind(event.kind);
      _rebaseScale(session);
      _emit(session, ElEventPhase.scaleStart, event);
    }
  }

  void _updateScale(_TransformSession session, PointerEvent event) {
    final current = _geometry(session);
    final initial = session.scaleGeometry;
    if (initial == null || !current.canScale) return;
    final pointerFactor = initial.span > 0 ? current.span / initial.span : 1.0;
    session.scale =
        session.scaleAtRebase *
        pointerFactor *
        current.panScale /
        initial.panScale;
    session.rotation +=
        _angleDelta(current.angle - session.lastRotationAngle) +
        current.panRotation -
        session.lastPanRotation;
    session.lastRotationAngle = current.angle;
    session.lastPanRotation = current.panRotation;
    final delta = current.focal - session.lastScaleFocal;
    session.lastScaleFocal = current.focal;
    session.scaleVelocity?.addPosition(
      event.timeStamp,
      Offset(math.log(session.scale), 0),
    );
    _emit(session, ElEventPhase.scaleUpdate, event, delta: delta);
    if (!_isCurrent(session)) return;
    _emit(session, ElEventPhase.rotationUpdate, event, delta: delta);
  }

  void _rebaseScale(_TransformSession session) {
    final geometry = _geometry(session);
    session.scaleGeometry = geometry;
    session.scaleAtRebase = session.scale;
    session.lastRotationAngle = geometry.angle;
    session.lastPanRotation = geometry.panRotation;
    session.lastScaleFocal = geometry.focal;
  }

  void _resetCandidateGeometry(_TransformSession session) {
    session.candidateGeometry = _geometry(session, acceptedOnly: false);
  }

  @override
  void rejectGesture(int pointer) {
    final session = _session;
    final tracked = session?.pointers[pointer];
    if (session == null || tracked == null) return;
    _removePointer(session, tracked, tracked.event, canceled: true);
  }

  void _removePointer(
    _TransformSession session,
    _TransformPointer pointer,
    PointerEvent event, {
    required bool canceled,
  }) {
    final wasAccepted = pointer.accepted;
    session.pointers.remove(event.pointer);
    session.acceptedOrder.remove(event.pointer);
    if (!session.scaleStarted) session.scaleThresholdMet = false;
    if (!session.dragStarted && pointer.dragThresholdMet) {
      session.dragThresholdMet = false;
      for (final remaining in session.pointers.values) {
        if (remaining.accepted && remaining.dragThresholdMet) {
          _acceptDragThreshold(session, remaining);
          break;
        }
      }
    }
    stopTrackingPointer(event.pointer);
    resolvePointer(event.pointer, GestureDisposition.rejected);
    if (!_isCurrent(session)) return;
    if (session.pointers.isEmpty ||
        (session.dragStarted || session.scaleStarted) &&
            !session.pointers.values.any((pointer) => pointer.accepted)) {
      _finishSession(session, event, canceled: canceled, lastPointer: pointer);
      return;
    }
    if (session.driver == event.pointer) {
      session.driver = session.acceptedOrder.lastOrNull;
      final next = session.pointers[session.driver];
      if (next != null) next.lastOutputLocal = next.localPosition;
    }
    if (wasAccepted && session.scaleStarted && !_geometry(session).canScale) {
      session.scaleStarted = false;
      _emit(
        session,
        canceled ? ElEventPhase.scaleCancel : ElEventPhase.scaleEnd,
        event,
      );
      if (!_isCurrent(session)) return;
      session.scaleThresholdMet = false;
    }
    _rebaseScale(session);
    _resetCandidateGeometry(session);
  }

  void _finishSession(
    _TransformSession session,
    PointerEvent event, {
    required bool canceled,
    _TransformPointer? lastPointer,
  }) {
    if (!identical(_session, session)) return;
    _session = null;
    // 最新 driver 可能尚未产生 Update，终态仍须使用它最后可信的位置。
    session.lastDriverPosition =
        session.pointers[session.driver]?.position ??
        lastPointer?.position ??
        session.lastDriverPosition;
    final pending = session.pointers.keys.toList();
    session.pointers.clear();
    for (final id in pending) {
      stopTrackingPointer(id);
      resolvePointer(id, GestureDisposition.rejected);
    }
    _releaseRoutePointers(session.route);
    if (session.scaleStarted) {
      _emit(
        session,
        canceled ? ElEventPhase.scaleCancel : ElEventPhase.scaleEnd,
        event,
      );
    }
    if (session.dragStarted || session.downDispatched) {
      final end = !canceled && session.dragStarted;
      _emit(
        session,
        end ? ElEventPhase.dragEnd : ElEventPhase.dragCancel,
        event,
        velocity: end && lastPointer != null
            ? _flingVelocity(session, lastPointer, event)
            : Velocity.zero,
      );
    }
    _endRoute(session.route);
  }

  Velocity _flingVelocity(
    _TransformSession session,
    _TransformPointer pointer,
    PointerEvent event,
  ) {
    final samples = pointer.velocitySamples;
    // 停顿按输入时间判断；不能把 UI 线程排队时间误当成手指停顿。
    if (samples.length < 2 ||
        event.timeStamp - samples.last.$1 > const Duration(milliseconds: 80)) {
      return Velocity.zero;
    }
    final tracker = VelocityTracker.withKind(pointer.down.kind);
    for (final (time, position) in samples) {
      tracker.addPosition(time, position);
    }
    final estimate = tracker.getVelocityEstimate();
    if (estimate == null) return Velocity.zero;
    var measuredSpeed = estimate.pixelsPerSecond;
    var measuredOffset = estimate.offset;
    // 两个真实样本不足以拟合，沿用旧版短促轻扫的平均速度两倍兜底。
    if (samples.length == 2) {
      final elapsed = event.timeStamp - pointer.down.timeStamp;
      if (elapsed <= Duration.zero) return Velocity.zero;
      measuredOffset = samples.last.$2 - pointer.down.localPosition;
      measuredSpeed =
          measuredOffset *
          (2 * Duration.microsecondsPerSecond / elapsed.inMicroseconds);
    }
    var speed = _project(measuredSpeed, session.acceptedAxis);
    final distance = _project(measuredOffset, session.acceptedAxis).distance;
    final minDistance =
        session.config.dragMinFlingDistance ??
        computeHitSlop(pointer.down.kind, gestureSettings);
    if (distance <= minDistance ||
        speed.distance <= session.config.dragMinFlingVelocity) {
      return Velocity.zero;
    }
    final maximum = session.config.dragMaxFlingVelocity;
    if (speed.distance > maximum) speed = speed / speed.distance * maximum;
    return Velocity(
      pixelsPerSecond: _toGlobalDelta(event, pointer.localPosition, speed),
    );
  }

  void _emit(
    _TransformSession session,
    ElEventPhase phase,
    PointerEvent event, {
    Offset delta = Offset.zero,
    Velocity velocity = Velocity.zero,
  }) {
    final scalePhase = _scalePhases.contains(phase);
    final geometry = _geometry(session);
    final position = scalePhase
        ? (geometry.count > 0 ? geometry.focal : session.lastScaleFocal)
        : session.pointers[session.driver]?.position ??
              session.lastDriverPosition ??
              event.position;
    if (!scalePhase) session.lastDriverPosition = position;
    final localVelocity = PointerEvent.transformDeltaViaPositions(
      transform: event.transform,
      untransformedDelta: velocity.pixelsPerSecond,
      untransformedEndPosition: position,
    );
    final primaryVelocity = switch (session.acceptedAxis) {
      Axis.horizontal => localVelocity.dx,
      Axis.vertical => localVelocity.dy,
      null => null,
    };
    _dispatchGesture(
      session.route,
      ElEventCallback(
        phase: phase,
        globalPosition: position,
        localPosition: position,
        delta: delta,
        localDelta: delta,
        dragOffset: session.dragOffset,
        dragDirection: session.direction,
        dragAxis: session.acceptedAxis,
        velocity: velocity,
        primaryVelocity: primaryVelocity,
        pointerCount: geometry.count,
        buttons: event.buttons,
        scale: session.scale,
        rotation: session.rotation,
        logScaleVelocity:
            session.scaleVelocity?.getVelocity().pixelsPerSecond.dx ?? 0,
        originalEvent: event,
        sampleTimeStamp: event.timeStamp,
      ),
    );
  }

  @override
  void _requestAccept(
    _GestureRoute route, {
    bool cancelSelfTap = false,
    bool allowScaleUpgrade = false,
  }) {
    final session = _session;
    if (session == null || !identical(session.route, route)) return;
    for (final pointer in session.pointers.keys.toList()) {
      if (!_isCurrent(session)) return;
      resolvePointer(pointer, GestureDisposition.accepted);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'El transform';

  @override
  void dispose() {
    if (_disposed || _disposing) return;
    _disposing = true;
    final session = _session;
    if (session != null) {
      _finishSession(
        session,
        session.pointers.values.last.event,
        canceled: true,
      );
    }
    super.dispose();
  }

  static Axis _axisFor(Offset delta, ElEventConfig config) =>
      delta.dy.abs() <= delta.dx.abs() * math.tan(config.dragHorizontalAngle)
      ? Axis.horizontal
      : Axis.vertical;

  static AxisDirection _directionFor(Offset delta, ElEventConfig config) =>
      switch (_axisFor(delta, config)) {
        Axis.horizontal =>
          delta.dx < 0 ? AxisDirection.left : AxisDirection.right,
        Axis.vertical => delta.dy < 0 ? AxisDirection.up : AxisDirection.down,
      };

  static Offset _project(Offset delta, Axis? axis) => switch (axis) {
    Axis.horizontal => Offset(delta.dx, 0),
    Axis.vertical => Offset(0, delta.dy),
    null => delta,
  };

  static Offset _toGlobalDelta(
    PointerEvent event,
    Offset localPosition,
    Offset localDelta,
  ) => PointerEvent.transformDeltaViaPositions(
    transform: event.transform == null
        ? null
        : Matrix4.tryInvert(event.transform!),
    untransformedDelta: localDelta,
    untransformedEndPosition: localPosition,
  );

  static double _angleDelta(double value) =>
      math.atan2(math.sin(value), math.cos(value));

  static _TransformGeometry _geometry(
    _TransformSession session, {
    bool acceptedOnly = true,
  }) {
    final pointers = session.pointers.values
        .where(
          (pointer) => !acceptedOnly || pointer.accepted && pointer.delivered,
        )
        .toList();
    if (pointers.isEmpty) return const _TransformGeometry();
    final touch = pointers.where((pointer) => !pointer.panZoom).toList();
    final panZoom = pointers.where((pointer) => pointer.panZoom).toList();
    final focal =
        pointers.fold(Offset.zero, (sum, pointer) => sum + pointer.position) /
        pointers.length.toDouble();
    final touchFocal = touch.isEmpty
        ? Offset.zero
        : touch.fold(Offset.zero, (sum, pointer) => sum + pointer.position) /
              touch.length.toDouble();
    final span = touch.isEmpty
        ? 0.0
        : touch.fold(
                0.0,
                (sum, pointer) =>
                    sum + (pointer.position - touchFocal).distance,
              ) /
              touch.length;
    final line = touch.length < 2
        ? Offset.zero
        : touch[1].position - touch[0].position;
    return _TransformGeometry(
      focal: focal,
      span: span,
      angle: line.direction,
      panScale: panZoom.fold(1.0, (scale, pointer) => scale * pointer.panScale),
      panRotation: panZoom.fold(
        0.0,
        (sum, pointer) => sum + pointer.panRotation,
      ),
      count: touch.length + 2 * panZoom.length,
      canScale: touch.length >= 2 || panZoom.isNotEmpty,
    );
  }
}

class _TransformSession {
  _TransformSession(
    this.route,
    this.config,
    this.axis,
    this.lockAxis,
    this.hasDrag,
    this.hasScale,
    this.canZoom,
    this.canRotate,
  );

  final _GestureRoute route;
  final ElEventConfig config;
  final Axis? axis;
  final bool lockAxis;
  final bool hasDrag;
  final bool hasScale;
  final bool canZoom;
  final bool canRotate;
  final Map<int, _TransformPointer> pointers = <int, _TransformPointer>{};
  final List<int> acceptedOrder = <int>[];
  int? driver;
  bool downDispatched = false;
  bool dragThresholdMet = false;
  bool scaleThresholdMet = false;
  bool dragStarted = false;
  bool scaleStarted = false;
  Axis? acceptedAxis;
  AxisDirection? direction;
  Offset dragOffset = Offset.zero;
  Offset? lastDriverPosition;
  _TransformGeometry? candidateGeometry;
  _TransformGeometry? scaleGeometry;
  Offset lastScaleFocal = Offset.zero;
  double scale = 1;
  double scaleAtRebase = 1;
  double rotation = 0;
  double lastRotationAngle = 0;
  double lastPanRotation = 0;
  VelocityTracker? scaleVelocity;
}

class _TransformPointer {
  _TransformPointer(this.down)
    : event = down,
      position = down.position,
      initialLocal = down.localPosition,
      localPosition = down.localPosition,
      lastOutputLocal = down.localPosition {
    addVelocitySample(down.timeStamp, down.localPosition);
  }

  final PointerEvent down;
  PointerEvent event;
  Offset position;
  final Offset initialLocal;
  Offset localPosition;
  Offset lastOutputLocal;
  final List<(Duration, Offset)> velocitySamples = [];

  // 只保存官方拟合器需要的有限真实样本，释放时再拟合，避免逐帧求解开销。
  void addVelocitySample(Duration time, Offset position) {
    velocitySamples.add((time, position));
    if (velocitySamples.length > 20) velocitySamples.removeAt(0);
  }

  bool accepted = false;
  bool delivered = false;
  bool dragThresholdMet = false;
  Axis? candidateAxis;
  AxisDirection? direction;
  double panScale = 1;
  double panRotation = 0;
  bool get panZoom => down is PointerPanZoomStartEvent;
}

class _TransformGeometry {
  const _TransformGeometry({
    this.focal = Offset.zero,
    this.span = 0,
    this.angle = 0,
    this.panScale = 1,
    this.panRotation = 0,
    this.count = 0,
    this.canScale = false,
  });

  final Offset focal;
  final double span;
  final double angle;
  final double panScale;
  final double panRotation;
  final int count;
  final bool canScale;
}
