part of 'recognizers.dart';

/// 在官方竞技场中识别点击、连击、侧键与长按，并沿 [parent] 冒泡。
///
/// 仅使用指针输入与识别参数；元素边界和样式反馈由宿主判断及处理。
class ElPressGestureRecognizer extends _ElGestureRecognizer {
  /// 创建独立按压识别器，识别参数在每次按下时冻结。
  ElPressGestureRecognizer({
    this.parent,
    this.doubleTapInterval = kDoubleTapTimeout,
    this.tripleTapInterval = kDoubleTapTimeout,
    this.longPressDelay = kLongPressTimeout,
    this.tapSlopTolerance,
    this.longPressSlopTolerance,
    this.consecutiveTapDistance = 10,
    this.deferTap = false,
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  }) : assert(doubleTapInterval >= Duration.zero),
       assert(tripleTapInterval >= Duration.zero),
       assert(longPressDelay >= Duration.zero),
       assert(tapSlopTolerance == null || tapSlopTolerance >= 0),
       assert(longPressSlopTolerance == null || longPressSlopTolerance >= 0),
       assert(consecutiveTapDistance >= 0);

  /// 同类手势冒泡父级，不重复参加同一指针的竞技场。
  ElPressGestureRecognizer? parent;

  /// 第二击与前一击的最长间隔。
  Duration doubleTapInterval;

  /// 第三击与前一击的最长间隔。
  Duration tripleTapInterval;

  /// 长按成立前的等待时间。
  Duration longPressDelay;

  /// 点击移动容差；为空时使用官方设备容差，可设为无穷大交由宿主决定取消。
  double? tapSlopTolerance;

  /// 长按移动容差；为空时使用官方设备容差。
  double? longPressSlopTolerance;

  /// 相邻连续点击允许的最大位置间距。
  double consecutiveTapDistance;

  /// 有双击订阅时是否等待窗口结束再通知单击，不延迟释放或持有竞技场。
  bool deferTap;

  _PressSettings get _settings => (
    doubleTapInterval: doubleTapInterval,
    tripleTapInterval: tripleTapInterval,
    longPressDelay: longPressDelay,
    tapSlopTolerance: tapSlopTolerance,
    longPressSlopTolerance: longPressSlopTolerance,
    consecutiveTapDistance: consecutiveTapDistance,
    deferTap: deferTap,
  );

  /// 主按钮按下候选；竞技场落败时随后通知 [onTapCancel]。
  ElPressGestureCallback? onTapDown;

  /// 获胜后的主按钮释放；自身点击被取消时仍可通知。
  ElPressGestureCallback? onTapUp;

  /// 获胜并通过点击条件后的单击。
  ElPressGestureCallback? onTap;

  /// 第二次有效点击；默认与本次单击同时通知。
  ElPressGestureCallback? onDoubleTap;

  /// 连续点击窗口内第二次按下的候选通知。
  ElPressGestureCallback? onDoubleTapDown;

  /// 第三次有效点击；完成后重新开始连续点击分组。
  ElPressGestureCallback? onTripleTap;

  /// 连续点击窗口内第三次按下的候选通知。
  ElPressGestureCallback? onTripleTapDown;

  /// 获胜并达到长按时间后的通知。
  ElPressGestureCallback? onLongPress;

  /// 候选因失权、超出移动容差或宿主主动取消而结束。
  ElPressGestureCallback? onTapCancel;

  /// 第二按钮按下候选，通常对应鼠标右键。
  ElPressGestureCallback? onSecondaryTapDown;

  /// 获胜后的第二按钮释放。
  ElPressGestureCallback? onSecondaryTapUp;

  /// 获胜后的第二按钮点击。
  ElPressGestureCallback? onSecondaryTap;

  /// 第三按钮按下候选，通常对应鼠标中键。
  ElPressGestureCallback? onTertiaryTapDown;

  /// 获胜后的第三按钮释放。
  ElPressGestureCallback? onTertiaryTapUp;

  /// 获胜后的第三按钮点击。
  ElPressGestureCallback? onTertiaryTap;

  /// 鼠标前进按钮按下候选。
  ElPressGestureCallback? onForwardTapDown;

  /// 获胜后的鼠标前进按钮释放。
  ElPressGestureCallback? onForwardTapUp;

  /// 获胜后的鼠标前进按钮点击。
  ElPressGestureCallback? onForwardTap;

  /// 鼠标后退按钮按下候选。
  ElPressGestureCallback? onBackTapDown;

  /// 获胜后的鼠标后退按钮释放。
  ElPressGestureCallback? onBackTapUp;

  /// 获胜后的鼠标后退按钮点击。
  ElPressGestureCallback? onBackTap;

  _PressSequence? _sequence;
  final Map<_GestureRoute, _PressSequence> _pressRoutes = {};
  final Set<_DeferredPressTap> _deferred = {};
  Timer? _historyTimer;
  Offset? _lastTapPosition;
  Duration? _historyDeadline;
  _PressSettings? _historySettings;
  int _historyCount = 0;
  int _historyGroup = 0;
  int _nextGroup = 0;
  bool _disposing = false;

  @override
  ElPressGestureRecognizer? get _bubbleParent => parent;

  @override
  _ElGestureCallback? _handlerFor(ElGesturePhase phase) {
    final handler = switch (phase) {
      ElGesturePhase.tapDown => onTapDown,
      ElGesturePhase.tapUp => onTapUp,
      ElGesturePhase.tap => onTap,
      ElGesturePhase.doubleTap => onDoubleTap,
      ElGesturePhase.doubleTapDown => onDoubleTapDown,
      ElGesturePhase.tripleTap => onTripleTap,
      ElGesturePhase.tripleTapDown => onTripleTapDown,
      ElGesturePhase.longPress => onLongPress,
      ElGesturePhase.tapCancel => onTapCancel,
      ElGesturePhase.secondaryTapDown => onSecondaryTapDown,
      ElGesturePhase.secondaryTapUp => onSecondaryTapUp,
      ElGesturePhase.secondaryTap => onSecondaryTap,
      ElGesturePhase.tertiaryTapDown => onTertiaryTapDown,
      ElGesturePhase.tertiaryTapUp => onTertiaryTapUp,
      ElGesturePhase.tertiaryTap => onTertiaryTap,
      ElGesturePhase.forwardTapDown => onForwardTapDown,
      ElGesturePhase.forwardTapUp => onForwardTapUp,
      ElGesturePhase.forwardTap => onForwardTap,
      ElGesturePhase.backTapDown => onBackTapDown,
      ElGesturePhase.backTapUp => onBackTapUp,
      ElGesturePhase.backTap => onBackTap,
      _ => null,
    };
    return handler == null
        ? null
        : (details) => handler(details as ElPressGestureDetails);
  }

  bool _chainHasHandler(ElGesturePhase phase) {
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
    if (_disposed || _disposing || _canceling) return false;
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
          ElGesturePhase.doubleTap,
          ElGesturePhase.doubleTapDown,
          ElGesturePhase.tripleTap,
          ElGesturePhase.tripleTapDown,
          ElGesturePhase.longPress,
          ElGesturePhase.tapCancel,
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
      _abort(previous, ElGestureCancelReason.rejected, previous.lastEvent);
      if (stillDown || _disposed || _disposing || _sequence != null) return;
    }
    final route = _beginRoute(event);
    final sequence = _PressSequence(
      route: route,
      down: event,
      settings: _settings,
      tapSlop: tapSlopTolerance ?? computeHitSlop(event.kind, gestureSettings),
      longPressSlop:
          longPressSlopTolerance ?? computeHitSlop(event.kind, gestureSettings),
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
      if (event.buttons == kPrimaryButton &&
          _routeHasHandler(sequence.route, ElGesturePhase.longPress)) {
        sequence.longPressPossible = true;
        sequence.longPressTimer = Timer(
          sequence.settings.longPressDelay,
          () => _longPressDeadline(sequence),
        );
      }
      return;
    }
    if (event is PointerCancelEvent) {
      _abort(sequence, ElGestureCancelReason.pointerCanceled, event);
      return;
    }
    if (event is PointerMoveEvent) {
      if (event.buttons != sequence.down.buttons) {
        _abort(sequence, ElGestureCancelReason.rejected, event);
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
      } else if (!sequence.tapEligible) {
        _abort(sequence, ElGestureCancelReason.rejected, event);
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
      _emit(sequence, ElGesturePhase.doubleTapDown, event, tapCount: count);
    } else if (count == 3) {
      _emit(sequence, ElGesturePhase.tripleTapDown, event, tapCount: count);
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
    if (distance <= sequence.tapSlop) return;
    sequence.tapEligible = false;
    _notifyCancel(sequence, ElGestureCancelReason.rejected, event);
    if (_isCurrent(sequence) &&
        !sequence.accepted &&
        !sequence.longPressPossible) {
      _abort(sequence, ElGestureCancelReason.rejected, event);
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
      ElGestureCancelReason.longPressAccepted,
      sequence.lastEvent,
    );
    if (!_isCurrent(sequence)) return;
    _emit(sequence, ElGesturePhase.longPress, sequence.lastEvent);
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
    _abort(sequence, ElGestureCancelReason.arenaRejected, sequence.lastEvent);
  }

  @override
  void _requestAccept(_GestureRoute route, int pointer) {
    final sequence = _sequence;
    if (_disposing ||
        _canceling ||
        sequence == null ||
        sequence.down.pointer != pointer ||
        !identical(sequence.route, route)) {
      return;
    }
    resolvePointer(pointer, GestureDisposition.accepted);
  }

  @override
  void _cancelRoutePointer(
    _GestureRoute route,
    int pointer,
    PointerEvent? event,
  ) {
    final sequence = _sequence;
    if (sequence != null &&
        sequence.down.pointer == pointer &&
        identical(sequence.route, route)) {
      _abort(
        sequence,
        ElGestureCancelReason.canceled,
        event ?? sequence.lastEvent,
      );
    }
  }

  @override
  void cancel() {
    if (_disposed || _canceling) return;
    _canceling = true;
    try {
      final sequence = _sequence;
      if (sequence != null) {
        _abort(sequence, ElGestureCancelReason.canceled, sequence.lastEvent);
      }
      _resetHistory();
      for (final pending in _deferred.toList()) {
        pending.timer?.cancel();
        _releaseSequence(pending.sequence);
      }
      _deferred.clear();
      for (final route in _pressRoutes.keys.toList()) {
        _endRoute(route);
      }
      _pressRoutes.clear();
    } finally {
      _canceling = false;
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
    if (_disposed || !sequence.route.active || sequence.finished) {
      _releaseSequence(sequence);
      return;
    }
    var deferred = false;
    if (sequence.tapEligible) {
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
    final hasDouble = _routeHasHandler(route, ElGesturePhase.doubleTap);
    final hasTriple =
        _routeHasHandler(route, ElGesturePhase.tripleTap) ||
        _routeHasHandler(route, ElGesturePhase.tripleTapDown);
    final needsHistory =
        hasDouble ||
        hasTriple ||
        _routeHasHandler(route, ElGesturePhase.doubleTapDown);
    final group = count > 1 ? _historyGroup : ++_nextGroup;
    if (needsHistory) {
      _recordHistory(sequence, up, count, group, hasTriple: hasTriple);
    }
    final defer = sequence.settings.deferTap && hasDouble;
    if (defer && count == 1) {
      _scheduleTap(sequence, up, group);
      return true;
    }
    if (!defer) _emit(sequence, ElGesturePhase.tap, up, tapCount: count);
    if (_disposed || !route.active || !sequence.tapEligible) return false;
    if (count == 2) {
      if (hasDouble) _cancelDeferredGroup(group);
      _emit(sequence, ElGesturePhase.doubleTap, sequence.down, tapCount: count);
    } else if (count == 3) {
      _cancelDeferredGroup(group);
      _emit(sequence, ElGesturePhase.tripleTap, sequence.down, tapCount: count);
    }
    return false;
  }

  int _consecutiveCount(_PressSequence sequence, PointerEvent event) {
    final previous = _historySettings;
    if (sequence.down.buttons != kPrimaryButton ||
        previous == null ||
        previous != sequence.settings ||
        !(_historyTimer?.isActive ?? false) ||
        _historyDeadline == null ||
        event.timeStamp > _historyDeadline! ||
        _lastTapPosition == null ||
        (event.position - _lastTapPosition!).distance >
            sequence.settings.consecutiveTapDistance) {
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
        ? sequence.settings.tripleTapInterval
        : sequence.settings.doubleTapInterval;
    _historyCount = count;
    _historySettings = sequence.settings;
    _historyGroup = group;
    _lastTapPosition = up.position;
    _historyDeadline = up.timeStamp + interval;
    _historyTimer = Timer(interval, _resetHistory);
  }

  void _resetHistory() {
    _historyTimer?.cancel();
    _historyTimer = null;
    _historyDeadline = null;
    _historySettings = null;
    _lastTapPosition = null;
    _historyCount = 0;
    _historyGroup = 0;
  }

  void _scheduleTap(_PressSequence sequence, PointerUpEvent up, int group) {
    late final _DeferredPressTap pending;
    pending = _DeferredPressTap(sequence, group);
    _deferred.add(pending);
    pending.timer = Timer(sequence.settings.doubleTapInterval, () {
      if (!_deferred.remove(pending)) return;
      try {
        if (!_disposed && sequence.route.active) {
          _emit(sequence, ElGesturePhase.tap, up, tapCount: 1);
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
    ElGestureCancelReason reason,
    PointerEvent event,
  ) {
    if (!sequence.downVisible) return;
    sequence.downVisible = false;
    _emit(sequence, ElGesturePhase.tapCancel, event, cancelReason: reason);
  }

  void _abort(
    _PressSequence sequence,
    ElGestureCancelReason reason,
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
    ElGesturePhase phase,
    PointerEvent event, {
    int tapCount = 0,
    ElGestureCancelReason? cancelReason,
  }) {
    if (_disposed || !sequence.route.active) return;
    _dispatchGesture(
      sequence.route,
      ElPressGestureDetails(
        phase: phase,
        globalPosition: event.position,
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
    if (_disposed || _disposing || _canceling) return;
    _disposing = true;
    cancel();
    super.dispose();
  }
}

final class _PressSequence {
  _PressSequence({
    required this.route,
    required this.down,
    required this.settings,
    required this.tapSlop,
    required this.longPressSlop,
  }) : lastEvent = down;

  final _GestureRoute route;
  final PointerDownEvent down;
  final _PressSettings settings;
  final double tapSlop;
  final double longPressSlop;
  PointerEvent lastEvent;
  PointerUpEvent? up;
  Timer? longPressTimer;
  bool accepted = false;
  bool downVisible = false;
  bool tapEligible = true;
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

(ElGesturePhase, ElGesturePhase, ElGesturePhase)? _pressPhases(int buttons) =>
    switch (buttons) {
      kPrimaryButton => (
        ElGesturePhase.tapDown,
        ElGesturePhase.tapUp,
        ElGesturePhase.tap,
      ),
      kSecondaryButton => (
        ElGesturePhase.secondaryTapDown,
        ElGesturePhase.secondaryTapUp,
        ElGesturePhase.secondaryTap,
      ),
      kTertiaryButton => (
        ElGesturePhase.tertiaryTapDown,
        ElGesturePhase.tertiaryTapUp,
        ElGesturePhase.tertiaryTap,
      ),
      kForwardMouseButton => (
        ElGesturePhase.forwardTapDown,
        ElGesturePhase.forwardTapUp,
        ElGesturePhase.forwardTap,
      ),
      kBackMouseButton => (
        ElGesturePhase.backTapDown,
        ElGesturePhase.backTapUp,
        ElGesturePhase.backTap,
      ),
      _ => null,
    };

typedef _PressSettings = ({
  Duration doubleTapInterval,
  Duration tripleTapInterval,
  Duration longPressDelay,
  double? tapSlopTolerance,
  double? longPressSlopTolerance,
  double consecutiveTapDistance,
  bool deferTap,
});
