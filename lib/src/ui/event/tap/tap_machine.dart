part of '../dispatcher.dart';

/// 主键 Tap/连击/LongPress 状态机，由 [_needsTapMachine] 按需创建。
/// 默认边界口径以 [_outsideBounds] 表示暂时离开，re-enter 可恢复候选；
/// `tapCancelOnMove` 距离口径与 [_canceled] 只取消最终 Tap，始终保留 TapUp。
/// 真正 eager 失权由 sequence 清理 pointer；Drag/Scale/侧键各自维护状态。
final class _TapMachine {
  _TapMachine(this.host);

  final ElEventDispatcher host;

  int? _pointer;
  Offset? _downPosition;
  int? _downButtons;
  PointerDeviceKind? _kind;
  bool _canceled = false;
  bool _longPressFired = false;
  bool _longPressSlopExceeded = false;

  /// 边界口径（[ElEventConfig.tapCancelOnMove] 为 false）下指针当前是否已拖出
  /// 宿主命中盒。与 [_canceled] 的差别是**可逆**：拖回来重新激活。
  bool _outsideBounds = false;

  /// 按下时刻宿主原点在全局空间的落位（只含祖先链变换），用于识别宿主是否
  /// 被祖先搬走（见 [ElEventDispatcher._hostDriftSince]）。
  Offset? _downHostOrigin;

  PointerDownEvent? _downEvent;
  _PointerSequence? _seq;
  Timer? _longPressTimer;

  // deferTap（deferTap = true 且声明了 onDoubleTap 时延迟 onTap）
  Timer? _deferredTapTimer;
  Offset? _deferredTapPosition;
  Offset? _deferredTapLocalPosition;
  Object? _deferredTapOriginalEvent;
  _PointerSequence? _deferredTapSequence;

  // 连击窗口
  int _consecutiveCount = 0;
  Offset? _lastTapUpPosition;
  Duration? _sequenceDeadline;
  Timer? _sequenceTimer;
  PointerDownEvent? _sequenceOriginalDownEvent;

  bool get tracking => _pointer != null;

  double get _cancelDistance => host.config.tapCancelDistance;

  bool get _cancelOnMove => host.config.tapCancelOnMove;

  Duration get _longPressDelay => host.config.longPressDelay;

  double _longPressCancelDistance(PointerDeviceKind kind) =>
      host.config.longPressCancelDistance ??
      computeHitSlop(kind, host.gestureSettings);

  bool get _needsLongPress => host._event?.onLongPress != null;

  // ---------------------------------------------------------------------------

  void feedDown(_PointerSequence seq, PointerDownEvent event) {
    if (!_isPrimaryButtonEvent(event)) return;
    // drag 已跟踪**其他**指针时，新的主键按下不建立 tap 候选（多指拖拽中
    // 追加手指不该产生 tapDown），并取消现有候选。
    if (host._dragMachine?.hasPointersOtherThan(event.pointer) ?? false) {
      if (tracking) _cancelForAdditionalPointer(seq, event);
      return;
    }
    // 无 drag 跟踪时，新的主键按下成为新的 tap 候选（旧行为：覆盖旧候选）。
    _pointer = event.pointer;
    _downPosition = event.position;
    _downHostOrigin = host._hostOriginInGlobal();
    _downButtons = event.buttons;
    _kind = event.kind;
    _downEvent = event;
    _seq = seq;
    _canceled = false;
    _longPressFired = false;
    _longPressSlopExceeded = false;
    _outsideBounds = false;
    if (host._event?.onTapDown != null) {
      host._fire(
        seq,
        ElEventPhase.tapDown,
        event.position,
        originalEvent: event,
      );
    }
    if (seq.eagerCancelsSelfTap && identical(seq.eagerMember, host)) {
      _suppressTapActivationForEager(
        seq,
        reason: ElEventCancelReason.selfGestureAccepted,
        originalEvent: event,
      );
    }
    final event0 = host._event;
    if (!_canceled && event0 != null) {
      _handleConsecutiveTapDown(seq, event, event0);
    }
    if (!_canceled) _startLongPressTimer(event);
  }

  void feedMove(_PointerSequence seq, PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    if (_buttonsChanged(event)) {
      _cancelLongPressTimer();
      if (!_canceled) {
        _canceled = true;
        _clearDeferredTap();
        if (host._event?.onTapCancel != null) {
          host._fire(
            seq,
            ElEventPhase.tapCancel,
            event.position,
            cancelReason: ElEventCancelReason.tapRejected,
            originalEvent: event,
          );
        }
      }
      return;
    }
    final down = _downPosition;
    if (down == null) return;
    final moved = (event.position - down).distance;
    // 长按 slop（hit slop，默认 18）与 tap 取消距离（默认 10）独立：
    // 移动 12px 时 tap 已取消但长按仍可触发，对齐旧 recognizer 行为。
    if (!_longPressSlopExceeded &&
        moved > _longPressCancelDistance(event.kind)) {
      _longPressSlopExceeded = true;
      _cancelLongPressTimer();
    }
    if (_canceled) return;
    // 宿主被搬走 = 手势归属已定，tap 终局取消（两种口径同判）。祖先是官方
    // Scrollable 时它在 gesture arena 里独立获胜，事件层收不到任何拖拽信号，
    // 只能靠"内容在手指底下漂移"反推。判据用 hit slop（与滚动 latch 同量级）
    // 而非 tapCancelDistance——后者在边界口径下已不是取消阈值。
    if (_hostDrifted(event)) {
      _canceled = true;
      _cancelLongPressTimer();
      _clearDeferredTap();
      if (host._event?.onTapCancel != null) {
        host._fire(
          seq,
          ElEventPhase.tapCancel,
          event.position,
          cancelReason: ElEventCancelReason.tapRejected,
          originalEvent: event,
        );
      }
      return;
    }
    if (_cancelOnMove) {
      if (moved > _cancelDistance) {
        _canceled = true;
        if (host._event?.onTapCancel != null) {
          host._fire(
            seq,
            ElEventPhase.tapCancel,
            event.position,
            cancelReason: ElEventCancelReason.tapRejected,
            originalEvent: event,
          );
        }
      }
      return;
    }
    // 边界口径（默认）：拖出宿主熄灭、拖回复燃，候选始终存活。
    final inside = host._withinHostBounds(event.position);
    if (inside == !_outsideBounds) return;
    _outsideBounds = !inside;
    if (inside) {
      // 复燃：重新走一遍按下语义（对齐 iOS touchDragEnter 重新点亮控件）。
      if (host._event?.onTapDown != null) {
        host._fire(
          seq,
          ElEventPhase.tapDown,
          event.position,
          originalEvent: event,
        );
      }
    } else if (host._event?.onTapCancel != null) {
      host._fire(
        seq,
        ElEventPhase.tapCancel,
        event.position,
        cancelReason: ElEventCancelReason.tapRejected,
        originalEvent: event,
      );
    }
  }

  /// 宿主是否已被祖先搬走（滚动 / 翻页 / 路由动画）——手势归属已定的信号。
  ///
  /// 判据用 hit slop（与滚动 latch 同量级）而非 [_cancelDistance]：后者在边界
  /// 口径下已不是取消阈值，且两种口径都要吃这条终局取消。
  bool _hostDrifted(PointerEvent event) {
    final origin = _downHostOrigin;
    if (origin == null) return false;
    final drift = host._hostDriftSince(origin);
    return drift != null &&
        drift > computeHitSlop(event.kind, host.gestureSettings);
  }

  void feedUp(_PointerSequence seq, PointerUpEvent event, {int? memberIndex}) {
    if (_pointer != event.pointer) return;
    final down = _downPosition;
    final canceled = _canceled;
    final originalDownEvent = _downEvent;
    final alreadyOutside = _outsideBounds;
    final event0 = host._event;
    final index = memberIndex ?? seq.indexOf(host);
    final outOfRange =
        down != null &&
        (_cancelOnMove
            ? (event.position - down).distance > _cancelDistance
            : !host._withinHostBounds(event.position));
    _resetCandidate();

    if (down == null) return;
    if (event0 == null) return;
    if (index < 0) return;

    // 越界判定：距离口径按 tapCancelDistance，边界口径按抬手位置是否仍在宿主
    // 命中范围内（拖出去抬手不触发，拖回来抬手照常触发）。move 侧已置位的
    // _outsideBounds 记录最近一次边界状态，最终裁决恒以抬手位置为准——平台可能不发
    // move 直接跳变 up 位置。
    if (outOfRange) {
      // 边界口径下拖出时已 fire 过一次 cancel，抬手不再重复。
      if (!canceled && event0.onTapCancel != null && !alreadyOutside) {
        host._fire(
          seq,
          ElEventPhase.tapCancel,
          event.position,
          cancelReason: ElEventCancelReason.tapRejected,
          originalEvent: event,
        );
      }
    }

    // tapUp 是按压释放通知，不代表 tap 激活成功；只要本节点仍持有 pointer，
    // 即使移动越阈、长按或同节点拖拽取消了 tap，也必须兑现一次。
    if (event0.onTapUp != null && !seq.blockedAt(ElEventPhase.tapUp, index)) {
      host._fire(seq, ElEventPhase.tapUp, event.position, originalEvent: event);
    }

    if (canceled || outOfRange) return;
    final deferredRouteIndex = seq.deferredTapRouteIndex;
    if (deferredRouteIndex != null && index > deferredRouteIndex) return;
    if (host.config.deferTap && event0.onDoubleTap != null) {
      seq.deferredTapRouteIndex ??= index;
      _scheduleDeferredTap(seq, event);
    } else if (event0.onTap != null &&
        !seq.blockedAt(ElEventPhase.tap, index)) {
      host._fire(seq, ElEventPhase.tap, event.position, originalEvent: event);
    }
    _handleConsecutiveTap(
      seq,
      event,
      event0,
      originalDownEvent: originalDownEvent,
    );
  }

  /// [external] 用于宿主销毁 / 真离场结算这类由宿主发起、并非平台指针取消的终态：
  /// 这类取消对用户是"外部打断"，报告 [ElEventCancelReason.external]，不能被当成
  /// 平台 pointerCancel 语义（下游按取消原因分流，见 selection 的归属判定）。
  void feedCancel(
    _PointerSequence seq,
    PointerCancelEvent event, {
    bool external = false,
  }) {
    if (_pointer != event.pointer) return;
    if (!_canceled) {
      _canceled = true;
      if (host._event?.onTapCancel != null) {
        host._fire(
          seq,
          ElEventPhase.tapCancel,
          event.position,
          cancelReason: external
              ? ElEventCancelReason.external
              : ElEventCancelReason.pointerCanceled,
          originalEvent: event,
        );
      }
    }
    _resetCandidate();
  }

  void feedRemoved(int pointer) {
    if (_pointer != pointer) return;
    _resetCandidate();
  }

  // ---------------------------------------------------------------------------

  void _startLongPressTimer(PointerDownEvent event) {
    _cancelLongPressTimer();
    if (!_needsLongPress) return;
    final pointer = event.pointer;
    if (_longPressDelay <= Duration.zero) {
      _onLongPressTimeout(pointer);
      return;
    }
    _longPressTimer = Timer(
      _longPressDelay,
      () => _onLongPressTimeout(pointer),
    );
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _onLongPressTimeout(int pointer) {
    _longPressTimer = null;
    if (_pointer != pointer || _longPressSlopExceeded || _longPressFired) {
      return;
    }
    final seq = _seq;
    if (seq == null) return;
    // 序列已被他人 eager 独占（滚动接受拖拽的 latch 换手、外层节点 eagerGesture
    // 等胜负已定场景）→ 静默放弃：不 fire、不置状态位、不抢 claim。
    // claimEager 是"先到先得不可覆盖"（sequence.dart 语义），此处二次防御保证
    // 后进的 timeout 不会绕过 claim first-win 而擅自成立长按。
    final eager = seq.eagerMember;
    if (eager != null && !identical(eager, host)) return;
    _DispatchCycle.run(() {
      seq.beginCycle();
      // 同一冻结链只生成一个 longPress 事件；最先到期的候选负责沿链冒泡，
      // 其余成员只停自己的 Timer，不改变 pointer 归属。
      for (final member in seq.chain) {
        if (!identical(member, host)) {
          member._tapMachine?._cancelLongPressTimer();
        }
      }
      final downEvent = _downEvent;
      final callback = host._fire(
        seq,
        ElEventPhase.longPress,
        _downPosition ?? host._lastPointerPosition,
        originalEvent: downEvent,
      );
      _DispatchCycle.flushNow();
      // onLongPress 是已成立手势的业务通知：默认由事件层认领并取消 Tap，
      // 普通调用方无需了解 eagerGesture。需要条件性拒绝（例如长按未命中
      // 可选文本）时，handler 通过 preventDefault 显式取消这项默认动作。
      if (callback == null ||
          !callback.callbackInvoked ||
          callback.defaultPrevented) {
        return;
      }
      seq.claimEager(host, cancelSelfTap: true, originalEvent: downEvent);
      if (_pointer != pointer ||
          !host._memberActive(seq, host) ||
          !identical(seq.eagerMember, host)) {
        return;
      }
      _longPressFired = true;
    });
  }

  void _scheduleDeferredTap(_PointerSequence seq, PointerUpEvent event) {
    _clearDeferredTap();
    _deferredTapPosition = event.position;
    _deferredTapLocalPosition = host._localPositionFor(
      host._owner,
      event.position,
    );
    _deferredTapOriginalEvent = event;
    _deferredTapSequence = seq;
    _deferredTapTimer = Timer(host.config.doubleTapInterval, () {
      final pos = _deferredTapPosition;
      final localPosition = _deferredTapLocalPosition;
      final originalEvent = _deferredTapOriginalEvent;
      final sequence = _deferredTapSequence;
      _clearDeferredTap();
      if (pos == null || host._event == null || sequence == null) return;
      _DispatchCycle.run(() {
        // 复用原冻结链建立新的逻辑 cycle：同一次点击只从最深 deferrer
        // 向外传播一次，stopPropagation 仍可在任意一跳截断。
        sequence.beginCycle();
        host._fire(
          sequence,
          ElEventPhase.tap,
          pos,
          localPosition: localPosition,
          originalEvent: originalEvent,
        );
      });
    });
  }

  void _clearDeferredTap() {
    _deferredTapTimer?.cancel();
    _deferredTapTimer = null;
    _deferredTapPosition = null;
    _deferredTapLocalPosition = null;
    _deferredTapOriginalEvent = null;
    _deferredTapSequence = null;
  }

  void _handleConsecutiveTap(
    _PointerSequence seq,
    PointerUpEvent event,
    ElEvent event0, {
    PointerDownEvent? originalDownEvent,
  }) {
    final needsDoubleTap =
        event0.onDoubleTap != null || event0.onDoubleTapDown != null;
    final needsTripleTap =
        event0.onTripleTap != null || event0.onTripleTapDown != null;
    if (!needsDoubleTap && !needsTripleTap) return;

    final lastPosition = _lastTapUpPosition;
    final deadline = _sequenceDeadline;
    final hasOpenTapWindow =
        (_sequenceTimer?.isActive ?? false) &&
        deadline != null &&
        event.timeStamp <= deadline;
    final withinDistance =
        lastPosition != null &&
        (event.position - lastPosition).distance <= _cancelDistance;
    _consecutiveCount = hasOpenTapWindow && withinDistance
        ? (_consecutiveCount + 1).clamp(1, 3).toInt()
        : 1;
    _lastTapUpPosition = event.position;
    _sequenceOriginalDownEvent = originalDownEvent;

    if (_consecutiveCount == 2) {
      _sequenceTimer?.cancel();
      if (event0.onDoubleTap != null) {
        _clearDeferredTap();
        host._fire(
          seq,
          ElEventPhase.doubleTap,
          event.position,
          originalEvent: _sequenceOriginalDownEvent ?? event,
        );
      }
      if (!needsTripleTap) {
        resetConsecutiveWindow();
      } else {
        _startSequenceTimer(
          host.config.tripleTapInterval,
          now: event.timeStamp,
        );
      }
      return;
    }

    if (_consecutiveCount < 3 || !needsTripleTap) {
      _startSequenceTimer(host.config.doubleTapInterval, now: event.timeStamp);
      return;
    }

    _clearDeferredTap();
    if (event0.onTripleTap != null) {
      host._fire(
        seq,
        ElEventPhase.tripleTap,
        event.position,
        originalEvent: _sequenceOriginalDownEvent ?? event,
      );
    }
    resetConsecutiveWindow();
  }

  void _handleConsecutiveTapDown(
    _PointerSequence seq,
    PointerDownEvent event,
    ElEvent event0,
  ) {
    if (event0.onDoubleTapDown == null && event0.onTripleTapDown == null) {
      return;
    }
    final lastPosition = _lastTapUpPosition;
    final deadline = _sequenceDeadline;
    final hasOpenTapWindow =
        (_sequenceTimer?.isActive ?? false) &&
        deadline != null &&
        event.timeStamp <= deadline;
    final withinDistance =
        lastPosition != null &&
        (event.position - lastPosition).distance <= _cancelDistance;
    if (!hasOpenTapWindow || !withinDistance) return;

    final nextCount = (_consecutiveCount + 1).clamp(1, 3).toInt();
    if (nextCount == 2 && event0.onDoubleTapDown != null) {
      host._fire(
        seq,
        ElEventPhase.doubleTapDown,
        event.position,
        originalEvent: event,
      );
    } else if (nextCount == 3 && event0.onTripleTapDown != null) {
      host._fire(
        seq,
        ElEventPhase.tripleTapDown,
        event.position,
        originalEvent: event,
      );
    }
  }

  void _startSequenceTimer(Duration interval, {Duration? now}) {
    _sequenceTimer?.cancel();
    if (now != null) _sequenceDeadline = now + interval;
    _sequenceTimer = Timer(interval, resetConsecutiveWindow);
  }

  /// 重置连击窗口（双击/三击计数）。
  void resetConsecutiveWindow() {
    _sequenceTimer?.cancel();
    _sequenceTimer = null;
    _consecutiveCount = 0;
    _lastTapUpPosition = null;
    _sequenceDeadline = null;
    _sequenceOriginalDownEvent = null;
  }

  /// eager winner 仅取消自身最终 tap 激活，保留 pointer 跟踪以兑现 tapUp。
  void _suppressTapActivationForEager(
    _PointerSequence seq, {
    required ElEventCancelReason reason,
    Object? originalEvent,
  }) {
    _clearDeferredTap();
    resetConsecutiveWindow();
    _cancelLongPressTimer();
    if (_pointer != seq.pointer || _canceled) return;
    final shouldNotify = !_outsideBounds;
    _canceled = true;
    final event = originalEvent is PointerEvent ? originalEvent : null;
    if (shouldNotify && host._event?.onTapCancel != null) {
      host._fire(
        null,
        ElEventPhase.tapCancel,
        event?.position ?? _downPosition ?? host._lastPointerPosition,
        cancelReason: reason,
        originalEvent: originalEvent,
        selfOnly: true,
      );
    }
  }

  bool _buttonsChanged(PointerMoveEvent event) {
    final kind = _kind;
    final buttons = _downButtons;
    if (kind == null || buttons == null) return false;
    if (!_tracksStableButtons(kind)) return false;
    return event.buttons != buttons;
  }

  void _cancelForAdditionalPointer(_PointerSequence seq, PointerEvent event) {
    _clearDeferredTap();
    _downEvent = null;
    _cancelLongPressTimer();
    if (_pointer == null) return;
    if (!_canceled) {
      _canceled = true;
      if (host._event?.onTapCancel != null) {
        host._fire(
          seq,
          ElEventPhase.tapCancel,
          event.position,
          cancelReason: ElEventCancelReason.tapRejected,
          originalEvent: event,
        );
      }
    }
    _longPressFired = false;
  }

  /// Scale 接受后直接终止匹配 [pointer] 的 Tap activation。
  void cancelForAcceptedScale(
    int? pointer,
    Offset focalPoint, {
    required ElEventCancelReason reason,
    Object? originalEvent,
  }) {
    _clearDeferredTap();
    resetConsecutiveWindow();
    if (_pointer == null || (pointer != null && _pointer != pointer)) return;
    _downEvent = null;
    _cancelLongPressTimer();
    final shouldNotify = !_canceled && !_outsideBounds && !_longPressFired;
    _canceled = true;
    if (shouldNotify && host._event?.onTapCancel != null) {
      host._fire(
        null,
        ElEventPhase.tapCancel,
        focalPoint,
        cancelReason: reason,
        originalEvent: originalEvent,
        selfOnly: true,
      );
    }
    _longPressFired = false;
  }

  /// 宿主主动取消（cancelAllPending / 外部接管）时触发 onTapCancel。
  void cancelActive({PointerEvent? originalEvent}) {
    _clearDeferredTap();
    _cancelLongPressTimer();
    if (_pointer != null && !_canceled) {
      _canceled = true;
      if (host._event?.onTapCancel != null) {
        host._fire(
          null,
          ElEventPhase.tapCancel,
          originalEvent?.position ?? host._lastPointerPosition,
          cancelReason: ElEventCancelReason.external,
          originalEvent: originalEvent,
          selfOnly: true,
        );
      }
    }
    _resetCandidate();
  }

  /// 静默取消（eager 失权 / 链截断 / detach）。不 fire 任何回调。
  void cancelSilently() {
    _clearDeferredTap();
    _cancelLongPressTimer();
    _resetCandidate();
  }

  /// event 不兼容的结构替换：丢弃离散 pending（连击窗口 / 延迟 tap / 长按计时），
  /// 保留活跃 tap 候选本身（up 时按新配置判定）。
  void invalidateDiscretePending() {
    _clearDeferredTap();
    resetConsecutiveWindow();
    _cancelLongPressTimer();
  }

  /// move 处理中途配置被结构替换：按**旧配置阈值**静默判定候选是否取消
  /// （不 fire 任何回调）。对齐旧 `_settlePrimaryTapMoveAfterEventReplacement`。
  void _settleMoveAfterReplacement(
    PointerMoveEvent event,
    ElEvent previousConfig, {
    required bool dragAccepted,
  }) {
    if (_pointer != event.pointer || _canceled) return;
    if (_buttonsChanged(event)) {
      _canceled = true;
      _longPressFired = false;
      _clearDeferredTap();
      _cancelLongPressTimer();
      return;
    }
    final down = _downPosition;
    if (down == null) return;
    final previous = host._configOf(previousConfig);
    // 宿主漂移（祖先滚动搬走内容）在两种口径下都是终局取消，与 feedMove 同判。
    if (!_hostDrifted(event)) {
      if (!previous.tapCancelOnMove) {
        // 边界口径：拖出不销毁候选，只静默同步边界状态；仅 drag 接受才是终局取消。
        if (!dragAccepted) {
          final inside = host._withinHostBounds(event.position);
          if (inside != !_outsideBounds) {
            _outsideBounds = !inside;
          }
          return;
        }
      } else if ((event.position - down).distance <=
              previous.tapCancelDistance &&
          !dragAccepted) {
        return;
      }
    }
    _canceled = true;
    _longPressFired = false;
    _clearDeferredTap();
    _cancelLongPressTimer();
  }

  void _resetCandidate() {
    _cancelLongPressTimer();
    _pointer = null;
    _downPosition = null;
    _downHostOrigin = null;
    _downButtons = null;
    _kind = null;
    _downEvent = null;
    _seq = null;
    _canceled = false;
    _longPressFired = false;
    _longPressSlopExceeded = false;
    _outsideBounds = false;
  }

  void dispose() {
    _clearDeferredTap();
    _cancelLongPressTimer();
    _sequenceTimer?.cancel();
    _sequenceTimer = null;
  }
}
