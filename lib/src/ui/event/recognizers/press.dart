part of 'recognizers.dart';

/// 在 Flutter 手势竞技场中识别按压、连续点击、鼠标按钮点击和长按。
///
/// [parent] 仅建立 El 事件冒泡链；整条链由最深层识别器参赛，官方识别器仍
/// 按竞技场规则竞争。Down 是候选通知，Up、Tap、LongPress 只在获胜后通知。
/// 未提供 [hitTest] 时按设备 hit slop 取消，提供后允许移出范围再移回。
/// 回调中的 eagerGesture 只请求官方接受；allowScaleUpgrade 不会转交已获胜的
/// 指针，跨类型连续转换需要同一复合识别器协调。
class ElPressGestureRecognizer extends _ElGestureRecognizer {
  /// 创建独立按压识别器；配置和命中函数在每次按下时冻结。
  ElPressGestureRecognizer({
    this.config = const ElEventConfig(),
    this.parent,
    this.hitTest,
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    super.globalToLocal,
  });

  /// 下一次按压采用的识别配置；反馈延时配置不属于识别器职责。
  ElEventConfig config;

  /// 同类 El 祖先，参与事件冒泡而不重复参加同一指针的竞争。
  ElPressGestureRecognizer? parent;

  /// 判断全局坐标是否仍在点击范围内；为空时使用设备移动容差。
  bool Function(Offset globalPosition)? hitTest;

  /// 主按钮按下候选；竞技场落败时随后通知 [onTapCancel]。
  ElEventHandler? onTapDown;

  /// 获胜后的主按钮释放；自身点击被取消时仍可通知。
  ElEventHandler? onTapUp;

  /// 获胜并通过点击条件后的单击。
  ElEventHandler? onTap;

  /// 第二次有效点击；默认与本次单击同时通知。
  ElEventHandler? onDoubleTap;

  /// 连续点击窗口内第二次按下的候选通知。
  ElEventHandler? onDoubleTapDown;

  /// 第三次有效点击；完成后重新开始连续点击分组。
  ElEventHandler? onTripleTap;

  /// 连续点击窗口内第三次按下的候选通知。
  ElEventHandler? onTripleTapDown;

  /// 获胜并达到长按时间后的通知；preventDefault 不撤销竞技场结果。
  ElEventHandler? onLongPress;

  /// 候选因失权、越界或生命周期结束而取消。
  ElEventHandler? onTapCancel;

  /// 第二按钮按下候选，通常对应鼠标右键。
  ElEventHandler? onSecondaryTapDown;

  /// 获胜后的第二按钮释放。
  ElEventHandler? onSecondaryTapUp;

  /// 获胜后的第二按钮点击。
  ElEventHandler? onSecondaryTap;

  /// 第三按钮按下候选，通常对应鼠标中键。
  ElEventHandler? onTertiaryTapDown;

  /// 获胜后的第三按钮释放。
  ElEventHandler? onTertiaryTapUp;

  /// 获胜后的第三按钮点击。
  ElEventHandler? onTertiaryTap;

  /// 鼠标前进按钮按下候选。
  ElEventHandler? onForwardTapDown;

  /// 获胜后的鼠标前进按钮释放。
  ElEventHandler? onForwardTapUp;

  /// 获胜后的鼠标前进按钮点击。
  ElEventHandler? onForwardTap;

  /// 鼠标后退按钮按下候选。
  ElEventHandler? onBackTapDown;

  /// 获胜后的鼠标后退按钮释放。
  ElEventHandler? onBackTapUp;

  /// 获胜后的鼠标后退按钮点击。
  ElEventHandler? onBackTap;

  _PressSequence? _sequence;
  final Map<_GestureRoute, _PressSequence> _pressRoutes = {};
  final Set<_DeferredPressTap> _deferred = {};
  Timer? _historyTimer;
  Offset? _lastTapPosition;
  Duration? _historyDeadline;
  int _historyCount = 0;
  int _historyGroup = 0;
  int _nextGroup = 0;
  bool _disposing = false;

  @override
  ElPressGestureRecognizer? get _bubbleParent => parent;

  @override
  ElEventHandler? _handlerFor(ElEventPhase phase) => switch (phase) {
    ElEventPhase.tapDown => onTapDown,
    ElEventPhase.tapUp => onTapUp,
    ElEventPhase.tap => onTap,
    ElEventPhase.doubleTap => onDoubleTap,
    ElEventPhase.doubleTapDown => onDoubleTapDown,
    ElEventPhase.tripleTap => onTripleTap,
    ElEventPhase.tripleTapDown => onTripleTapDown,
    ElEventPhase.longPress => onLongPress,
    ElEventPhase.tapCancel => onTapCancel,
    ElEventPhase.secondaryTapDown => onSecondaryTapDown,
    ElEventPhase.secondaryTapUp => onSecondaryTapUp,
    ElEventPhase.secondaryTap => onSecondaryTap,
    ElEventPhase.tertiaryTapDown => onTertiaryTapDown,
    ElEventPhase.tertiaryTapUp => onTertiaryTapUp,
    ElEventPhase.tertiaryTap => onTertiaryTap,
    ElEventPhase.forwardTapDown => onForwardTapDown,
    ElEventPhase.forwardTapUp => onForwardTapUp,
    ElEventPhase.forwardTap => onForwardTap,
    ElEventPhase.backTapDown => onBackTapDown,
    ElEventPhase.backTapUp => onBackTapUp,
    ElEventPhase.backTap => onBackTap,
    _ => null,
  };

  bool _chainHasHandler(ElEventPhase phase) {
    final visited = <ElPressGestureRecognizer>{};
    ElPressGestureRecognizer? node = this;
    while (node != null && visited.add(node)) {
      if (!node._disposed && node._handlerFor(phase) != null) return true;
      node = node.parent;
    }
    return false;
  }

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_disposed || _disposing) return false;
    if (_isDelegated(event.pointer)) return true;
    if (!super.isPointerAllowed(event)) return false;
    final phases = _pressPhases(event.buttons);
    if (phases == null) return false;
    if (_chainHasHandler(phases.$1) ||
        _chainHasHandler(phases.$2) ||
        _chainHasHandler(phases.$3)) {
      return true;
    }
    return event.buttons == kPrimaryButton &&
        const [
          ElEventPhase.doubleTap,
          ElEventPhase.doubleTapDown,
          ElEventPhase.tripleTap,
          ElEventPhase.tripleTapDown,
          ElEventPhase.longPress,
          ElEventPhase.tapCancel,
        ].any(_chainHasHandler);
  }

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {
    // 无关按钮或设备不能把正在识别的另一根指针整体踢出竞技场。
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_delegatePointer(event)) return;
    final previous = _sequence;
    if (previous != null) {
      final stillDown = previous.up == null;
      _abort(previous, ElEventCancelReason.tapRejected, previous.lastEvent);
      if (stillDown || _disposed || _disposing || _sequence != null) return;
    }
    final route = _beginRoute(event);
    final sequence = _PressSequence(
      route: route,
      down: event,
      config: config,
      hitTest: hitTest,
      hitSlop: computeHitSlop(event.kind, gestureSettings),
      longPressSlop:
          config.longPressCancelDistance ??
          computeHitSlop(event.kind, gestureSettings),
    );
    _sequence = sequence;
    _pressRoutes[route] = sequence;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final sequence = _sequence;
    if (sequence == null || sequence.down.pointer != event.pointer) return;
    sequence.lastEvent = event;
    if (event is PointerDownEvent) {
      _sendDown(sequence, event);
      if (!_isCurrent(sequence)) return;
      if (!sequence.selfTapCanceled &&
          event.buttons == kPrimaryButton &&
          _routeHasHandler(sequence.route, ElEventPhase.longPress)) {
        sequence.longPressPossible = true;
        sequence.longPressTimer = Timer(
          sequence.config.longPressDelay,
          () => _longPressDeadline(sequence),
        );
      }
      return;
    }
    if (event is PointerCancelEvent) {
      _abort(sequence, ElEventCancelReason.pointerCanceled, event);
      return;
    }
    if (event is PointerMoveEvent) {
      if (event.buttons != sequence.down.buttons) {
        _abort(sequence, ElEventCancelReason.tapRejected, event);
        return;
      }
      _updatePosition(sequence, event);
      return;
    }
    if (event is PointerUpEvent) {
      sequence.longPressTimer?.cancel();
      sequence.longPressTimer = null;
      sequence.longPressPossible = false;
      _updatePosition(sequence, event);
      if (!_isCurrent(sequence)) return;
      sequence.up = event;
      if (sequence.accepted) {
        _completeAccepted(sequence);
      } else if (!sequence.tapEligible || sequence.outside) {
        _abort(sequence, ElEventCancelReason.tapRejected, event);
      } else {
        // 等待官方 sweep，避免父 El 在 up 阶段抢赢先入场的官方子 Tap。
        stopTrackingPointer(event.pointer);
      }
    }
  }

  bool _isCurrent(_PressSequence sequence) =>
      !_disposed &&
      !sequence.finished &&
      sequence.route.active &&
      identical(_sequence, sequence);

  void _sendDown(_PressSequence sequence, PointerEvent event) {
    if (sequence.downVisible || sequence.finished) return;
    sequence.downVisible = true;
    _emit(sequence, _pressPhases(sequence.down.buttons)!.$1, event);
    if (!_isCurrent(sequence) || sequence.down.buttons != kPrimaryButton) {
      return;
    }
    final count = _consecutiveCount(sequence, sequence.down);
    if (count == 2) {
      _emit(sequence, ElEventPhase.doubleTapDown, event, tapCount: count);
    } else if (count == 3) {
      _emit(sequence, ElEventPhase.tripleTapDown, event, tapCount: count);
    }
  }

  void _updatePosition(_PressSequence sequence, PointerEvent event) {
    final distance = (event.position - sequence.down.position).distance;
    if (distance > sequence.longPressSlop) {
      sequence.longPressPossible = false;
      sequence.longPressTimer?.cancel();
      sequence.longPressTimer = null;
    }
    if (!sequence.tapEligible || sequence.longPressFired) return;
    final isPrimary = sequence.down.buttons == kPrimaryButton;
    final boundsMode =
        isPrimary &&
        !sequence.config.tapCancelOnMove &&
        sequence.hitTest != null;
    if (boundsMode) {
      final outside = !sequence.hitTest!(event.position);
      if (outside == sequence.outside) return;
      sequence.outside = outside;
      if (outside) {
        _notifyCancel(sequence, ElEventCancelReason.tapRejected, event);
      } else if (event is! PointerUpEvent) {
        _sendDown(sequence, event);
      }
      return;
    }
    final limit = isPrimary && !sequence.config.tapCancelOnMove
        ? sequence.hitSlop
        : sequence.config.tapCancelDistance;
    if (distance <= limit) return;
    sequence.tapEligible = false;
    _notifyCancel(sequence, ElEventCancelReason.tapRejected, event);
    if (_isCurrent(sequence) &&
        !sequence.accepted &&
        !sequence.longPressPossible) {
      _abort(sequence, ElEventCancelReason.tapRejected, event);
    }
  }

  void _longPressDeadline(_PressSequence sequence) {
    sequence.longPressTimer = null;
    if (!_isCurrent(sequence) || !sequence.longPressPossible) return;
    sequence.longPressRequested = true;
    if (sequence.accepted) {
      _deliverLongPress(sequence);
    } else {
      resolvePointer(sequence.down.pointer, GestureDisposition.accepted);
    }
  }

  void _deliverLongPress(_PressSequence sequence) {
    if (!_isCurrent(sequence) ||
        !sequence.accepted ||
        !sequence.longPressRequested ||
        sequence.longPressFired) {
      return;
    }
    sequence.longPressFired = true;
    sequence.tapEligible = false;
    sequence.longPressPossible = false;
    _resetHistory();
    _notifyCancel(
      sequence,
      ElEventCancelReason.selfGestureAccepted,
      sequence.lastEvent,
    );
    if (!_isCurrent(sequence)) return;
    _emit(sequence, ElEventPhase.longPress, sequence.lastEvent);
  }

  @override
  void acceptGesture(int pointer) {
    final sequence = _sequence;
    if (sequence == null || sequence.down.pointer != pointer) return;
    sequence.accepted = true;
    resolvePointer(pointer, GestureDisposition.accepted);
    if (sequence.longPressRequested) _deliverLongPress(sequence);
    if (_isCurrent(sequence) && sequence.up != null) {
      _completeAccepted(sequence);
    }
  }

  @override
  void rejectGesture(int pointer) {
    final sequence = _sequence;
    if (sequence == null || sequence.down.pointer != pointer) return;
    _abort(
      sequence,
      ElEventCancelReason.otherGestureAccepted,
      sequence.lastEvent,
    );
  }

  @override
  void _requestAccept(
    _GestureRoute route, {
    bool cancelSelfTap = false,
    bool allowScaleUpgrade = false,
  }) {
    final sequence = _pressRoutes[route];
    if (_disposing || sequence == null || sequence.finished || !route.active) {
      return;
    }
    // allowScaleUpgrade 不转交官方归属；跨类型升级应由同一复合识别器协调。
    if (cancelSelfTap && sequence.tapEligible) {
      sequence.selfTapCanceled = true;
      sequence.tapEligible = false;
      sequence.longPressPossible = false;
      sequence.longPressTimer?.cancel();
      sequence.longPressTimer = null;
      _notifyCancel(
        sequence,
        ElEventCancelReason.selfGestureAccepted,
        sequence.lastEvent,
      );
    }
    if (!sequence.finished && route.active && !_disposed) {
      resolvePointer(sequence.down.pointer, GestureDisposition.accepted);
    }
  }

  void _completeAccepted(_PressSequence sequence) {
    final up = sequence.up;
    if (!_isCurrent(sequence) || up == null) return;
    _releaseRoutePointers(sequence.route);
    _sequence = null;
    stopTrackingPointer(sequence.down.pointer);
    final phases = _pressPhases(sequence.down.buttons)!;
    _emit(sequence, phases.$2, up);
    if (_disposed || !sequence.route.active || sequence.finished) return;
    var deferred = false;
    if (sequence.tapEligible && !sequence.outside) {
      if (sequence.down.buttons == kPrimaryButton) {
        deferred = _completePrimaryTap(sequence, up);
      } else {
        _emit(sequence, phases.$3, up, tapCount: 1);
      }
    } else {
      _resetHistory();
    }
    sequence.finished = true;
    if (!deferred) _releaseSequence(sequence);
  }

  bool _completePrimaryTap(_PressSequence sequence, PointerUpEvent up) {
    final route = sequence.route;
    final count = _consecutiveCount(sequence, up);
    final hasDouble = _routeHasHandler(route, ElEventPhase.doubleTap);
    final hasTriple =
        _routeHasHandler(route, ElEventPhase.tripleTap) ||
        _routeHasHandler(route, ElEventPhase.tripleTapDown);
    final needsHistory =
        hasDouble ||
        hasTriple ||
        _routeHasHandler(route, ElEventPhase.doubleTapDown);
    final group = count > 1 ? _historyGroup : ++_nextGroup;
    if (needsHistory) {
      _recordHistory(sequence, up, count, group, hasTriple: hasTriple);
    }
    final defer = sequence.config.deferTap && hasDouble;
    if (defer && count == 1) {
      _scheduleTap(sequence, up, group);
      return true;
    }
    if (!defer) _emit(sequence, ElEventPhase.tap, up, tapCount: count);
    if (_disposed || !route.active || !sequence.tapEligible) return false;
    if (count == 2) {
      if (hasDouble) _cancelDeferredGroup(group);
      _emit(sequence, ElEventPhase.doubleTap, sequence.down, tapCount: count);
    } else if (count == 3) {
      _cancelDeferredGroup(group);
      _emit(sequence, ElEventPhase.tripleTap, sequence.down, tapCount: count);
    }
    return false;
  }

  int _consecutiveCount(_PressSequence sequence, PointerEvent event) {
    if (sequence.down.buttons != kPrimaryButton ||
        !(_historyTimer?.isActive ?? false) ||
        _historyDeadline == null ||
        event.timeStamp > _historyDeadline! ||
        _lastTapPosition == null ||
        (event.position - _lastTapPosition!).distance >
            sequence.config.tapCancelDistance) {
      return 1;
    }
    return (_historyCount + 1).clamp(1, 3);
  }

  void _recordHistory(
    _PressSequence sequence,
    PointerUpEvent up,
    int count,
    int group, {
    required bool hasTriple,
  }) {
    _resetHistory();
    if (count == 3 || (count == 2 && !hasTriple)) return;
    final interval = count == 2
        ? sequence.config.tripleTapInterval
        : sequence.config.doubleTapInterval;
    _historyCount = count;
    _historyGroup = group;
    _lastTapPosition = up.position;
    _historyDeadline = up.timeStamp + interval;
    _historyTimer = Timer(interval, _resetHistory);
  }

  void _resetHistory() {
    _historyTimer?.cancel();
    _historyTimer = null;
    _historyDeadline = null;
    _lastTapPosition = null;
    _historyCount = 0;
    _historyGroup = 0;
  }

  void _scheduleTap(_PressSequence sequence, PointerUpEvent up, int group) {
    late final _DeferredPressTap pending;
    pending = _DeferredPressTap(sequence, group);
    _deferred.add(pending);
    pending.timer = Timer(sequence.config.doubleTapInterval, () {
      if (!_deferred.remove(pending)) return;
      try {
        if (!_disposed && sequence.route.active) {
          _emit(sequence, ElEventPhase.tap, up, tapCount: 1);
        }
      } finally {
        _releaseSequence(sequence);
      }
    });
  }

  void _cancelDeferredGroup(int group) {
    for (final pending in _deferred.toList()) {
      if (pending.group != group) continue;
      _deferred.remove(pending);
      pending.timer?.cancel();
      _releaseSequence(pending.sequence);
    }
  }

  void _notifyCancel(
    _PressSequence sequence,
    ElEventCancelReason reason,
    PointerEvent event,
  ) {
    if (!sequence.downVisible) return;
    sequence.downVisible = false;
    _emit(sequence, ElEventPhase.tapCancel, event, cancelReason: reason);
  }

  void _abort(
    _PressSequence sequence,
    ElEventCancelReason reason,
    PointerEvent event,
  ) {
    if (sequence.finished) return;
    sequence.finished = true;
    sequence.longPressTimer?.cancel();
    sequence.longPressTimer = null;
    if (identical(_sequence, sequence)) _sequence = null;
    _resetHistory();
    _releaseRoutePointers(sequence.route);
    resolvePointer(sequence.down.pointer, GestureDisposition.rejected);
    stopTrackingPointer(sequence.down.pointer);
    _notifyCancel(sequence, reason, event);
    _releaseSequence(sequence);
  }

  void _releaseSequence(_PressSequence sequence) {
    _pressRoutes.remove(sequence.route);
    _endRoute(sequence.route);
  }

  void _emit(
    _PressSequence sequence,
    ElEventPhase phase,
    PointerEvent event, {
    int tapCount = 0,
    ElEventCancelReason? cancelReason,
  }) {
    if (_disposed || !sequence.route.active) return;
    _dispatchGesture(
      sequence.route,
      ElEventCallback(
        phase: phase,
        globalPosition: event.position,
        localPosition: event.localPosition,
        buttons: sequence.down.buttons,
        tapCount: tapCount,
        originalEvent: event,
        cancelReason: cancelReason,
      ),
    );
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'el press';

  @override
  void dispose() {
    if (_disposed || _disposing) return;
    _disposing = true;
    final sequence = _sequence;
    if (sequence != null) {
      _abort(sequence, ElEventCancelReason.external, sequence.lastEvent);
    }
    _resetHistory();
    for (final pending in _deferred.toList()) {
      pending.timer?.cancel();
      _releaseSequence(pending.sequence);
    }
    _deferred.clear();
    _pressRoutes.clear();
    super.dispose();
  }
}

final class _PressSequence {
  _PressSequence({
    required this.route,
    required this.down,
    required this.config,
    required this.hitTest,
    required this.hitSlop,
    required this.longPressSlop,
  }) : lastEvent = down;

  final _GestureRoute route;
  final PointerDownEvent down;
  final ElEventConfig config;
  final bool Function(Offset)? hitTest;
  final double hitSlop;
  final double longPressSlop;
  PointerEvent lastEvent;
  PointerUpEvent? up;
  Timer? longPressTimer;
  bool accepted = false;
  bool downVisible = false;
  bool tapEligible = true;
  bool selfTapCanceled = false;
  bool outside = false;
  bool longPressPossible = false;
  bool longPressRequested = false;
  bool longPressFired = false;
  bool finished = false;
}

final class _DeferredPressTap {
  _DeferredPressTap(this.sequence, this.group);

  final _PressSequence sequence;
  final int group;
  Timer? timer;
}

(ElEventPhase, ElEventPhase, ElEventPhase)? _pressPhases(int buttons) =>
    switch (buttons) {
      kPrimaryButton => (
        ElEventPhase.tapDown,
        ElEventPhase.tapUp,
        ElEventPhase.tap,
      ),
      kSecondaryButton => (
        ElEventPhase.secondaryTapDown,
        ElEventPhase.secondaryTapUp,
        ElEventPhase.secondaryTap,
      ),
      kTertiaryButton => (
        ElEventPhase.tertiaryTapDown,
        ElEventPhase.tertiaryTapUp,
        ElEventPhase.tertiaryTap,
      ),
      kForwardMouseButton => (
        ElEventPhase.forwardTapDown,
        ElEventPhase.forwardTapUp,
        ElEventPhase.forwardTap,
      ),
      kBackMouseButton => (
        ElEventPhase.backTapDown,
        ElEventPhase.backTapUp,
        ElEventPhase.backTap,
      ),
      _ => null,
    };
