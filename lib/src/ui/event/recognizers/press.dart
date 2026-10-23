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
    this.secondaryTapSlopTolerance,
    this.longPressSlopTolerance,
    this.consecutiveTapDistance = 10,
    this.deferTap = false,
    this.isEligible,
    this.cancelTapOnLongPress = true,
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  }) : assert(doubleTapInterval >= Duration.zero),
       assert(tripleTapInterval >= Duration.zero),
       assert(longPressDelay >= Duration.zero),
       assert(tapSlopTolerance == null || tapSlopTolerance >= 0),
       assert(
         secondaryTapSlopTolerance == null || secondaryTapSlopTolerance >= 0,
       ),
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

  /// 侧键点击移动容差；为空时沿用主键容差，与宿主的主键边界策略独立。
  double? secondaryTapSlopTolerance;

  /// 提交点击或长按前的成员资格判断，尺寸等外部条件由调用方计算。
  bool Function(ElGesturePhase phase, PointerEvent event)? isEligible;

  /// 长按成立后是否自动取消自身点击，关闭后可由调用方通过 rejectTap 决定。
  bool cancelTapOnLongPress;

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
    secondaryTapSlopTolerance: secondaryTapSlopTolerance,
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

  /// 物理释放对应的同步语义通知全部结束后调用，不等待延迟单击。
  void Function(PointerUpEvent event)? onReleased;

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

  _PressGroup? _group;
  final Map<_GestureRoute, _PressSequence> _sequences = {};
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

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_disposed || _disposing || _canceling) return false;
    if (_isDelegated(event.pointer)) return true;
    if (!super.isPointerAllowed(event)) return false;
    final phases = _pressPhases(event.buttons);
    if (phases == null) return false;
    return [
      phases.$1,
      phases.$2,
      phases.$3,
      if (event.buttons == kPrimaryButton) ...[
        ElGesturePhase.doubleTap,
        ElGesturePhase.doubleTapDown,
        ElGesturePhase.tripleTap,
        ElGesturePhase.tripleTapDown,
        ElGesturePhase.longPress,
        ElGesturePhase.tapCancel,
      ],
    ].any(_hasHandlerInChain);
  }

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {}

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_delegatePointer(event)) return;
    final previous = _group;
    if (previous != null) {
      final stillDown = previous.up == null;
      _abortGroup(previous, ElGestureCancelReason.rejected, previous.lastEvent);
      if (stillDown || _disposed || _disposing || _group != null) return;
    }
    final route = _beginRoute(event);
    final group = _PressGroup(this, route, event);
    _group = group;
    for (final node in route.members.cast<ElPressGestureRecognizer>()) {
      final settings = node._settings;
      final slop = event.buttons == kPrimaryButton
          ? settings.tapSlopTolerance
          : settings.secondaryTapSlopTolerance ?? settings.tapSlopTolerance;
      final sequence = _PressSequence(
        node,
        group,
        settings,
        slop ?? computeHitSlop(event.kind, node.gestureSettings),
        settings.longPressSlopTolerance ??
            computeHitSlop(event.kind, node.gestureSettings),
        node.isEligible,
        node.cancelTapOnLongPress,
      );
      group.sequences[node] = sequence;
      node._sequences[route] = sequence;
    }
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final group = _group;
    if (group == null || group.down.pointer != event.pointer) return;
    group.lastEvent = event;
    if (event is PointerDownEvent) {
      for (final sequence in group.sequences.values) {
        sequence.downVisible = true;
      }
      _emit(group, _pressPhases(event.buttons)!.$1, event);
      for (final sequence in group.sequences.values.toList()) {
        final node = sequence.node;
        if (!node._isCurrent(sequence) || event.buttons != kPrimaryButton) {
          continue;
        }
        final count = node._consecutiveCount(sequence, event);
        if (count > 1) {
          _emit(
            group,
            count == 2
                ? ElGesturePhase.doubleTapDown
                : ElGesturePhase.tripleTapDown,
            event,
            only: sequence,
            tapCount: count,
          );
        }
        if (node._isCurrent(sequence) &&
            node.onLongPress != null &&
            _allows(sequence)) {
          sequence.longPressTimer = Timer(
            sequence.settings.longPressDelay,
            () => _longPressDeadline(sequence),
          );
        }
      }
      return;
    }
    if (event is PointerCancelEvent ||
        event is PointerMoveEvent && event.buttons != group.down.buttons) {
      _abortGroup(
        group,
        event is PointerCancelEvent
            ? ElGestureCancelReason.pointerCanceled
            : ElGestureCancelReason.rejected,
        event,
      );
      return;
    }
    if (event is PointerMoveEvent || event is PointerUpEvent) {
      for (final sequence in group.sequences.values.toList()) {
        _updatePosition(sequence, event);
      }
    }
    if (event is PointerUpEvent && identical(_group, group)) {
      group.up = event;
      for (final sequence in group.sequences.values) {
        sequence.longPressTimer?.cancel();
      }
      if (group.accepted) {
        _completeAccepted(group);
      } else if (!group.sequences.values.any(
        (sequence) =>
            sequence.tapEligible &&
            sequence.node._isCurrent(sequence) &&
            (sequence.eligible?.call(
                  _pressPhases(group.down.buttons)!.$3,
                  event,
                ) ??
                true),
      )) {
        _abortGroup(group, ElGestureCancelReason.rejected, event);
      } else {
        // 释放交给官方 sweep；不能在 up 抢先接受而越过更内层的官方 Tap。
        stopTrackingPointer(event.pointer);
      }
    }
  }

  bool _isCurrent(_PressSequence sequence) =>
      !_disposed &&
      !sequence.canceled &&
      !sequence.released &&
      !sequence.canceling &&
      sequence.group.route.active;

  static bool _allows(_PressSequence sequence) {
    final route = sequence.group.route;
    final index = route.members.indexOf(sequence.node);
    return index >= 0 &&
        index <=
            (route.cutoffs[_GestureFamily.press] ?? route.members.length - 1);
  }

  void _updatePosition(_PressSequence sequence, PointerEvent event) {
    if (!sequence.node._isCurrent(sequence)) return;
    final distance = (event.position - sequence.group.down.position).distance;
    if (distance > sequence.longPressSlop) {
      sequence.longPressTimer?.cancel();
      sequence.longPressTimer = null;
    }
    if (sequence.tapEligible && distance > sequence.tapSlop) {
      sequence.tapEligible = false;
      _notifyCancel(sequence, ElGestureCancelReason.rejected, event);
    }
  }

  void _longPressDeadline(_PressSequence sequence) {
    sequence.longPressTimer = null;
    final group = sequence.group;
    if (!sequence.node._isCurrent(sequence) ||
        group.up != null ||
        !_allows(sequence) ||
        !(sequence.eligible?.call(ElGesturePhase.longPress, group.lastEvent) ??
            true)) {
      return;
    }
    sequence.longPressRequested = true;
    if (group.accepted) {
      _deliverLongPress(sequence);
    } else {
      resolvePointer(group.down.pointer, GestureDisposition.accepted);
    }
  }

  void _deliverLongPress(_PressSequence sequence) {
    if (!sequence.node._isCurrent(sequence) ||
        !sequence.longPressRequested ||
        sequence.longPressFired ||
        !_allows(sequence)) {
      return;
    }
    sequence.longPressFired = true;
    if (sequence.cancelTapOnLongPress) {
      sequence.tapEligible = false;
      sequence.node._resetHistory();
      _notifyCancel(
        sequence,
        ElGestureCancelReason.longPressAccepted,
        sequence.group.lastEvent,
      );
    }
    _emit(
      sequence.group,
      ElGesturePhase.longPress,
      sequence.group.lastEvent,
      only: sequence,
    );
  }

  @override
  void acceptGesture(int pointer) {
    final group = _group;
    if (group == null || group.down.pointer != pointer || group.accepted) {
      return;
    }
    group.accepted = true;
    resolvePointer(pointer, GestureDisposition.accepted);
    _notifyAccepted(group.route, pointer);
    for (final sequence in group.sequences.values.toList()) {
      if (sequence.longPressRequested) _deliverLongPress(sequence);
    }
    if (identical(_group, group) && group.up != null) _completeAccepted(group);
  }

  @override
  void rejectGesture(int pointer) {
    final group = _group;
    if (group != null && group.down.pointer == pointer) {
      _abortGroup(group, ElGestureCancelReason.arenaRejected, group.lastEvent);
    }
  }

  @override
  void _requestAccept(_GestureRoute route, int pointer) {
    if (!_disposing && !_canceling && identical(_group?.route, route)) {
      resolvePointer(pointer, GestureDisposition.accepted);
    }
  }

  @override
  void _cancelRoutePointer(
    _GestureRoute route,
    int pointer,
    PointerEvent? event,
  ) {
    final group = _group;
    if (group != null &&
        identical(group.route, route) &&
        group.down.pointer == pointer) {
      _abortGroup(
        group,
        ElGestureCancelReason.canceled,
        event ?? group.lastEvent,
      );
    }
  }

  /// 永久取消当前成员的点击资格，保留同一路线其他成员及物理释放通知。
  void rejectTap(
    int pointer, {
    ElGestureCancelReason reason = ElGestureCancelReason.rejected,
  }) {
    for (final sequence in _sequences.values.toList()) {
      if (sequence.group.down.pointer != pointer || !_isCurrent(sequence)) {
        continue;
      }
      sequence.tapEligible = false;
      sequence.longPressTimer?.cancel();
      _resetHistory();
      sequence.group.owner._notifyCancel(
        sequence,
        reason,
        sequence.group.lastEvent,
      );
    }
  }

  /// 终止当前成员及其待发点击，不终止同一路线的父子成员。
  void cancelMember(int pointer) {
    for (final sequence in _sequences.values.toList()) {
      if (sequence.group.down.pointer == pointer) {
        _cancelSequence(
          sequence,
          ElGestureCancelReason.canceled,
          sequence.group.lastEvent,
        );
      }
    }
  }

  @override
  void cancel() {
    if (_disposed || _canceling) return;
    _canceling = true;
    try {
      final groups = _sequences.values
          .map((sequence) => sequence.group)
          .toSet();
      if (_group != null) groups.add(_group!);
      for (final group in groups) {
        if (identical(group.owner, this)) {
          _abortGroup(group, ElGestureCancelReason.canceled, group.lastEvent);
        } else {
          final sequence = group.sequences[this];
          if (sequence != null) {
            _cancelSequence(
              sequence,
              ElGestureCancelReason.canceled,
              group.lastEvent,
            );
          }
        }
      }
      _resetHistory();
    } finally {
      _canceling = false;
    }
  }

  void _completeAccepted(_PressGroup group) {
    final up = group.up;
    if (up == null || group.completing || !group.route.active) return;
    group.completing = true;
    if (identical(_group, group)) _group = null;
    _releaseRoutePointers(group.route);
    stopTrackingPointer(group.down.pointer);
    for (final sequence in group.sequences.values) {
      sequence.longPressTimer?.cancel();
    }
    _emit(group, _pressPhases(group.down.buttons)!.$2, up);
    for (final sequence in group.sequences.values) {
      sequence.downVisible = false;
    }
    final counts = <_PressSequence, int>{};
    for (final sequence in group.sequences.values.toList()) {
      final node = sequence.node;
      if (!node._isCurrent(sequence)) continue;
      if (!sequence.tapEligible ||
          !(sequence.eligible?.call(_pressPhases(group.down.buttons)!.$3, up) ??
              true) ||
          !_allows(sequence)) {
        node._resetHistory();
        continue;
      }
      final count = group.down.buttons == kPrimaryButton
          ? node._consecutiveCount(sequence, up)
          : 1;
      counts[sequence] = count;
      if (group.down.buttons != kPrimaryButton) continue;
      final hasDouble = node.onDoubleTap != null;
      final hasTriple =
          node.onTripleTap != null || node.onTripleTapDown != null;
      final needsHistory =
          hasDouble || hasTriple || node.onDoubleTapDown != null;
      final historyGroup = count > 1 ? node._historyGroup : ++node._nextGroup;
      if (needsHistory) {
        node._recordHistory(
          sequence,
          up,
          count,
          historyGroup,
          hasTriple: hasTriple,
        );
      }
      if (sequence.settings.deferTap && hasDouble && count == 1) {
        node._scheduleTap(sequence, up, historyGroup);
      } else if (count > 1) {
        node._cancelDeferredGroup(historyGroup);
      }
    }
    final primary = group.down.buttons == kPrimaryButton;
    _emit(
      group,
      _pressPhases(group.down.buttons)!.$3,
      up,
      select: (sequence) =>
          counts.containsKey(sequence) &&
          !(primary &&
              sequence.settings.deferTap &&
              sequence.node.onDoubleTap != null),
      counts: counts,
    );
    if (primary) {
      _emit(
        group,
        ElGesturePhase.doubleTap,
        group.down,
        select: (sequence) => counts[sequence] == 2,
        tapCount: 2,
      );
      _emit(
        group,
        ElGesturePhase.tripleTap,
        group.down,
        select: (sequence) => counts[sequence] == 3,
        tapCount: 3,
      );
    }
    for (final sequence in group.sequences.values.toList()) {
      final node = sequence.node;
      final callback = node.onReleased;
      if (!node._disposed && callback != null) {
        node.invokeCallback<void>('released', () => callback(up));
      }
    }
    for (final sequence in group.sequences.values.toList()) {
      if (!sequence.pending) sequence.node._releaseSequence(sequence);
    }
  }

  int _consecutiveCount(_PressSequence sequence, PointerEvent event) {
    if (_historySettings != sequence.settings ||
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
    if (count == 3 || count == 2 && !hasTriple) return;
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
    final pending = _DeferredPressTap(sequence, group);
    sequence.pending = true;
    _deferred.add(pending);
    pending.timer = Timer(sequence.settings.doubleTapInterval, () {
      if (!_deferred.remove(pending)) return;
      try {
        if (_isCurrent(sequence)) {
          sequence.group.owner._emit(
            sequence.group,
            ElGesturePhase.tap,
            up,
            only: sequence,
            tapCount: 1,
          );
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
    _emit(
      sequence.group,
      ElGesturePhase.tapCancel,
      event,
      only: sequence,
      cancelReason: reason,
    );
  }

  void _cancelSequence(
    _PressSequence sequence,
    ElGestureCancelReason reason,
    PointerEvent event,
  ) {
    if (sequence.canceled || sequence.released || sequence.canceling) return;
    sequence.canceling = true;
    sequence.longPressTimer?.cancel();
    _resetHistory();
    for (final pending in _deferred.toList()) {
      if (!identical(pending.sequence, sequence)) continue;
      _deferred.remove(pending);
      pending.timer?.cancel();
    }
    sequence.group.owner._notifyCancel(sequence, reason, event);
    sequence.canceled = true;
    _releaseSequence(sequence);
  }

  void _abortGroup(
    _PressGroup group,
    ElGestureCancelReason reason,
    PointerEvent event,
  ) {
    if (group.canceling) return;
    if (group.completing && group.route.terminalDispatchDepth > 0) {
      // Up 内销毁只阻止后续业务点击，已经公开的父级释放仍须兑现。
      for (final sequence in group.sequences.values) {
        sequence.tapEligible = false;
        sequence.longPressTimer?.cancel();
        sequence.node._resetHistory();
      }
      return;
    }
    group.canceling = true;
    if (identical(_group, group)) _group = null;
    _releaseRoutePointers(group.route);
    resolvePointer(group.down.pointer, GestureDisposition.rejected);
    stopTrackingPointer(group.down.pointer);
    for (final sequence in group.sequences.values.toList()) {
      sequence.node._cancelSequence(sequence, reason, event);
    }
    _endRoute(group.route);
  }

  void _releaseSequence(_PressSequence sequence) {
    if (sequence.released) return;
    sequence.released = true;
    if (identical(_sequences[sequence.group.route], sequence)) {
      _sequences.remove(sequence.group.route);
    }
    if (sequence.group.sequences.values.every((member) => member.released)) {
      final group = sequence.group;
      final owner = group.owner;
      if (identical(owner._group, group)) {
        owner._group = null;
        owner.resolvePointer(group.down.pointer, GestureDisposition.rejected);
        owner.stopTrackingPointer(group.down.pointer);
      }
      owner._endRoute(group.route);
    }
  }

  void _emit(
    _PressGroup group,
    ElGesturePhase phase,
    PointerEvent event, {
    _PressSequence? only,
    bool Function(_PressSequence sequence)? select,
    Map<_PressSequence, int>? counts,
    int tapCount = 0,
    ElGestureCancelReason? cancelReason,
  }) {
    if (!group.route.active) return;
    final shared = ElPressGestureDetails(
      phase: phase,
      globalPosition: event.position,
      buttons: group.down.buttons,
      originalEvent: event,
      cancelReason: cancelReason,
    );
    _dispatchGesture(
      group.route,
      shared,
      prepare: (member) {
        final sequence = group.sequences[member];
        if (sequence == null ||
            sequence.canceled ||
            sequence.released ||
            sequence.canceling && phase != ElGesturePhase.tapCancel ||
            only != null && !identical(only, sequence) ||
            !(select?.call(sequence) ?? true)) {
          return null;
        }
        return ElPressGestureDetails(
          phase: phase,
          globalPosition: event.position,
          buttons: group.down.buttons,
          originalEvent: event,
          tapCount: counts?[sequence] ?? tapCount,
          cancelReason: cancelReason,
        ).._dispatchIdentity = shared;
      },
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

final class _PressGroup {
  _PressGroup(this.owner, this.route, this.down) : lastEvent = down;
  final ElPressGestureRecognizer owner;
  final _GestureRoute route;
  final PointerDownEvent down;
  final Map<ElPressGestureRecognizer, _PressSequence> sequences = {};
  PointerEvent lastEvent;
  PointerUpEvent? up;
  bool accepted = false;
  bool completing = false;
  bool canceling = false;
}

final class _PressSequence {
  _PressSequence(
    this.node,
    this.group,
    this.settings,
    this.tapSlop,
    this.longPressSlop,
    this.eligible,
    this.cancelTapOnLongPress,
  );
  final ElPressGestureRecognizer node;
  final _PressGroup group;
  final _PressSettings settings;
  final double tapSlop;
  final double longPressSlop;
  final bool Function(ElGesturePhase, PointerEvent)? eligible;
  final bool cancelTapOnLongPress;
  Timer? longPressTimer;
  bool downVisible = false;
  bool tapEligible = true;
  bool longPressRequested = false;
  bool longPressFired = false;
  bool canceled = false;
  bool canceling = false;
  bool pending = false;
  bool released = false;
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
  double? secondaryTapSlopTolerance,
  double? longPressSlopTolerance,
  double consecutiveTapDistance,
  bool deferTap,
});
