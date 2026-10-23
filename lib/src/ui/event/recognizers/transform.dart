part of 'recognizers.dart';

/// 在官方竞技场内统一识别拖拽、缩放和旋转。
///
/// 每根指针分别参赛，只有获胜的指针才能驱动正式手势；新增指针落败不会
/// 撤销已经获胜的拖拽。多指拖拽采用 latestPointer：最新获胜指针驱动，
/// 抬起后交回仍获胜的指针。缩放、旋转只使用已获胜的触点。
///
/// [parent] 负责同类手势冒泡；本类只接收指针数据，不处理元素范围或样式状态。
class ElTransformGestureRecognizer extends _ElGestureRecognizer {
  /// 创建独立变换识别器；[axis] 为空时自由拖拽，[lockAxis] 可按起手方向锁轴。
  ElTransformGestureRecognizer({
    this.startDistance,
    this.horizontalAngle = math.pi / 4,
    this.minFlingDistance,
    this.minFlingVelocity = kMinFlingVelocity,
    this.maxFlingVelocity = kMaxFlingVelocity,
    this.parent,
    this.axis,
    this.lockAxis = false,
    super.debugOwner,
    super.supportedDevices,
    AllowedButtonsFilter? allowedButtonsFilter,
  }) : assert(startDistance == null || startDistance >= 0),
       assert(horizontalAngle > 0 && horizontalAngle < math.pi / 2),
       assert(minFlingDistance == null || minFlingDistance >= 0),
       assert(minFlingVelocity >= 0 && maxFlingVelocity >= minFlingVelocity),
       super(
         allowedButtonsFilter: allowedButtonsFilter ?? _primaryTransformButton,
       );

  static bool _primaryTransformButton(int buttons) => buttons == kPrimaryButton;

  /// 开始拖拽的全局移动阈值；为空时采用官方设备与轴向容差。
  double? startDistance;

  /// 水平起手方向的捕获半角，默认 45 度。
  double horizontalAngle;

  /// 产生释放速度的最小移动距离；为空时采用官方设备容差。
  double? minFlingDistance;

  /// 产生甩动的最小速度。
  double minFlingVelocity;

  /// 释放速度的最大值。
  double maxFlingVelocity;

  _TransformSettings get _settings => (
    startDistance: startDistance,
    horizontalAngle: horizontalAngle,
    minFlingDistance: minFlingDistance,
    minFlingVelocity: minFlingVelocity,
    maxFlingVelocity: maxFlingVelocity,
  );

  /// El 冒泡父级；在一次指针序列开始时冻结路线。
  ElTransformGestureRecognizer? parent;

  /// 拖拽轴；为空时允许二维拖拽，不限制缩放与旋转。
  Axis? axis;

  /// [axis] 为空时，是否按照起手方向锁定水平或垂直轴。
  bool lockAxis;

  /// 拖拽候选按下；此阶段尚未取得官方手势所有权。
  ElTransformGestureCallback? onDragDown;

  /// 拖拽超过阈值并取得官方所有权后调用，不补发阈值内位移。
  ElTransformGestureCallback? onDragStart;

  /// 已获胜拖拽的位移更新。
  ElTransformGestureCallback? onDragUpdate;

  /// 已获胜拖拽正常释放，速度按当前配置过滤并限幅。
  ElTransformGestureCallback? onDragEnd;

  /// 拖拽候选落败、平台取消或识别器销毁。
  ElTransformGestureCallback? onDragCancel;

  /// 至少两个已获胜触点或触控板开始变换。
  ElTransformGestureCallback? onScaleStart;

  /// 缩放更新；只有声明缩放或旋转回调时才识别多指变换。
  ElTransformGestureCallback? onScaleUpdate;

  /// 变换正常结束，剩余单指可继续原有拖拽。
  ElTransformGestureCallback? onScaleEnd;

  /// 变换被平台、竞技场或销毁取消。
  ElTransformGestureCallback? onScaleCancel;

  /// 旋转更新，弧度从本轮变换开始累计。
  ElTransformGestureCallback? onRotationUpdate;

  _TransformSession? _session;
  bool _disposing = false;

  @override
  ElTransformGestureRecognizer? get _bubbleParent => parent;

  @override
  _ElGestureCallback? _handlerFor(ElGesturePhase phase) {
    final handler = switch (phase) {
      ElGesturePhase.dragDown => onDragDown,
      ElGesturePhase.dragStart => onDragStart,
      ElGesturePhase.dragUpdate => onDragUpdate,
      ElGesturePhase.dragEnd => onDragEnd,
      ElGesturePhase.dragCancel => onDragCancel,
      ElGesturePhase.scaleStart => onScaleStart,
      ElGesturePhase.scaleUpdate => onScaleUpdate,
      ElGesturePhase.scaleEnd => onScaleEnd,
      ElGesturePhase.scaleCancel => onScaleCancel,
      ElGesturePhase.rotationUpdate => onRotationUpdate,
      _ => null,
    };
    return handler == null
        ? null
        : (details) => handler(details as ElTransformGestureDetails);
  }

  static const _dragPhases = <ElGesturePhase>[
    ElGesturePhase.dragDown,
    ElGesturePhase.dragStart,
    ElGesturePhase.dragUpdate,
    ElGesturePhase.dragEnd,
    ElGesturePhase.dragCancel,
  ];
  static const _scalePhases = <ElGesturePhase>[
    ElGesturePhase.scaleStart,
    ElGesturePhase.scaleUpdate,
    ElGesturePhase.scaleEnd,
    ElGesturePhase.scaleCancel,
    ElGesturePhase.rotationUpdate,
  ];

  bool get _hasHandlers =>
      _dragPhases.any(_hasHandlerInChain) ||
      _scalePhases.any(_hasHandlerInChain);

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_disposed || _disposing || _canceling) return false;
    if (_isDelegated(event.pointer)) return true;
    return _hasHandlers && super.isPointerAllowed(event);
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) {
    if (_disposed || _disposing || _canceling) return false;
    if (_isDelegated(event.pointer)) return true;
    return _hasHandlers && super.isPointerPanZoomAllowed(event);
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
        _settings,
        axis,
        lockAxis,
        _dragPhases.any((phase) => _routeHasHandler(route, phase)),
        _scalePhases.any((phase) => _routeHasHandler(route, phase)),
        _scalePhases
            .where((phase) => phase != ElGesturePhase.rotationUpdate)
            .any((phase) => _routeHasHandler(route, phase)),
        _routeHasHandler(route, ElGesturePhase.rotationUpdate),
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
        _emit(session, ElGesturePhase.dragDown, event);
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
      _emit(session, ElGesturePhase.dragUpdate, event, delta: delta);
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
          (session.lockAxis
              ? _axisFor(moved, session.settings.horizontalAngle)
              : null);
      final intendedAxis = _axisFor(moved, session.settings.horizontalAngle);
      if (candidateAxis == null || candidateAxis == intendedAxis) {
        final projected = _project(moved, candidateAxis);
        final globalMoved = _toGlobalDelta(
          event,
          pointer.localPosition,
          projected,
        );
        final threshold =
            session.settings.startDistance ??
            (candidateAxis == Axis.vertical || session.axis != null
                ? computeHitSlop(event.kind, gestureSettings)
                : computePanSlop(event.kind, gestureSettings));
        if (globalMoved.distance > threshold) {
          pointer.dragThresholdMet = true;
          pointer.candidateAxis = candidateAxis;
          pointer.direction = _directionFor(
            moved,
            session.settings.horizontalAngle,
          );
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
      _emit(session, ElGesturePhase.dragStart, event);
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
      _emit(session, ElGesturePhase.scaleStart, event);
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
    _emit(session, ElGesturePhase.scaleUpdate, event, delta: delta);
    if (!_isCurrent(session)) return;
    _emit(session, ElGesturePhase.rotationUpdate, event, delta: delta);
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
        canceled ? ElGesturePhase.scaleCancel : ElGesturePhase.scaleEnd,
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
        canceled ? ElGesturePhase.scaleCancel : ElGesturePhase.scaleEnd,
        event,
      );
    }
    if (session.dragStarted || session.downDispatched) {
      final end = !canceled && session.dragStarted;
      _emit(
        session,
        end ? ElGesturePhase.dragEnd : ElGesturePhase.dragCancel,
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
        session.settings.minFlingDistance ??
        computeHitSlop(pointer.down.kind, gestureSettings);
    if (distance <= minDistance ||
        speed.distance <= session.settings.minFlingVelocity) {
      return Velocity.zero;
    }
    final maximum = session.settings.maxFlingVelocity;
    if (speed.distance > maximum) speed = speed / speed.distance * maximum;
    return Velocity(
      pixelsPerSecond: _toGlobalDelta(event, pointer.localPosition, speed),
    );
  }

  void _emit(
    _TransformSession session,
    ElGesturePhase phase,
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
    _dispatchGesture(
      session.route,
      ElTransformGestureDetails(
        phase: phase,
        globalPosition: position,
        delta: delta,
        dragOffset: session.dragOffset,
        dragDirection: session.direction,
        dragAxis: session.acceptedAxis,
        velocity: velocity,
        pointerCount: geometry.count,
        scale: session.scale,
        rotation: session.rotation,
        logScaleVelocity:
            session.scaleVelocity?.getVelocity().pixelsPerSecond.dx ?? 0,
        originalEvent: event,
      ),
    );
  }

  @override
  void _requestAccept(_GestureRoute route, int pointer) {
    final session = _session;
    if (!_canceling &&
        session != null &&
        identical(session.route, route) &&
        session.pointers.containsKey(pointer)) {
      resolvePointer(pointer, GestureDisposition.accepted);
    }
  }

  @override
  void _cancelRoutePointer(
    _GestureRoute route,
    int pointer,
    PointerEvent? event,
  ) {
    final session = _session;
    final tracked = session?.pointers[pointer];
    if (session != null && tracked != null && identical(session.route, route)) {
      _removePointer(session, tracked, event ?? tracked.event, canceled: true);
    }
  }

  @override
  void cancel() {
    if (_disposed || _canceling) return;
    _canceling = true;
    try {
      final session = _session;
      if (session != null) {
        _finishSession(
          session,
          session.pointers.values.last.event,
          canceled: true,
        );
      }
    } finally {
      _canceling = false;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'El transform';

  @override
  void dispose() {
    if (_disposed || _disposing || _canceling) return;
    _disposing = true;
    cancel();
    super.dispose();
  }

  static Axis _axisFor(Offset delta, double horizontalAngle) =>
      delta.dy.abs() <= delta.dx.abs() * math.tan(horizontalAngle)
      ? Axis.horizontal
      : Axis.vertical;

  static AxisDirection _directionFor(Offset delta, double horizontalAngle) =>
      switch (_axisFor(delta, horizontalAngle)) {
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
    this.settings,
    this.axis,
    this.lockAxis,
    this.hasDrag,
    this.hasScale,
    this.canZoom,
    this.canRotate,
  );

  final _GestureRoute route;
  final _TransformSettings settings;
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

typedef _TransformSettings = ({
  double? startDistance,
  double horizontalAngle,
  double? minFlingDistance,
  double minFlingVelocity,
  double maxFlingVelocity,
});
