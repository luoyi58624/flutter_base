part of '../dispatcher.dart';

typedef _DragPipelinePlan = ({
  List<ElEventDispatcher> roster,
  ElEventDispatcher? latchBreakMember,
  Axis? axis,
});

/// 主键 Drag 状态机：负责 slop/轴竞争、多指策略、生命周期与结束速度，
/// 并在 accept 后按配置接入 [DragResampler]；raw 仍驱动 slop/Tap/velocity。
/// 仅有 Drag 回调时惰性创建；[_DragPipeline] 只维护 roster，
/// 三段余量投递由 dispatcher 执行。
final class _DragMachine {
  _DragMachine(this.host);

  /// 释放速度的真停顿阈值，正常拟合和样本不足兜底都先检查 move→up 事件间隔。
  /// 取官方 stopped 阈(40ms)的 2 倍,给平台帧批量投递/jank 下的事件迟到留
  /// 余量;极短轻扫(硬件只报出 down + 1-2 个样本)gap = 手势总时长(几十
  /// ms),仍在阈内。
  static const Duration _kReleaseMoveGap = Duration(milliseconds: 80);

  final ElEventDispatcher host;

  /// 本机作为 driver 持有的分账管线；null 表示当前无管线。
  _DragPipeline? _pipeline;

  int? _dragPointerId;
  Offset? _dragDownPosition;
  AxisDirection? _dragDirection;

  /// 本次手势的胜出轴。起手判定时写入：只挂单一轴向组恒为该轴；双轴组同挂
  /// 按起手方向竞争锁轴；自由拖拽（onDrag*）为 null。接受前无意义。
  Axis? _acceptedAxis;
  bool _dragStarted = false;
  bool _dragStartDispatched = false;
  Offset _dragOffset = Offset.zero;
  final Map<int, Offset> _pointerDownPositions = <int, Offset>{};
  final Map<int, Offset> _pointerPositions = <int, Offset>{};
  final Map<int, Duration> _pointerDownTimeStamps = <int, Duration>{};

  /// 每指针最后一个非合成 move 的**事件时间戳**(down 时初始化为 down 时间戳)。
  /// velocity fallback 用它判定"真停顿":事件 ts 的 move→up 间隔不受处理
  /// 延迟(jank/重采样排队)影响;而 VelocityTracker 的停顿检测走
  /// samplingClock 墙钟,真机 jank 下会把高速轻扫误判成 stopped(全零占位)。
  final Map<int, Duration> _pointerLastMoveTimeStamps = <int, Duration>{};
  // 位置校正与速度样本分开：Web 抬手前的合成 move 不能污染稀疏样本兜底的终点。
  final Map<int, Offset> _pointerLastVelocityPositions = <int, Offset>{};
  final Map<int, PointerDeviceKind> _pointerKinds = <int, PointerDeviceKind>{};
  final Map<int, int> _pointerButtons = <int, int>{};
  final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};
  final Map<int, _PointerSequence> _pointerSequences =
      <int, _PointerSequence>{};
  final List<int> _pointerOrder = <int>[];
  final Map<int, Offset> _averageBoundaryFrameDeltas = <int, Offset>{};
  Duration? _averageBoundaryFrameTimeStamp;
  Offset _averageBoundaryLastPanFrameDelta = Offset.zero;

  bool get hasPointers => _pointerPositions.isNotEmpty;

  bool hasPointersOtherThan(int pointer) {
    if (_pointerPositions.isEmpty) return false;
    if (_pointerPositions.length > 1) return true;
    return !_pointerPositions.containsKey(pointer);
  }

  bool isTracking(int pointer) => _pointerPositions.containsKey(pointer);

  _PointerSequence? get _activeSequence {
    final pointer = _dragPointerId;
    if (pointer == null) return null;
    return _pointerSequences[pointer];
  }

  /// 卸载冷路径检查全部指针，避免 latest driver 不是 eager 所属指针时漏结算。
  bool get ownsCompositeState {
    if (_pipeline?.active == true) return true;
    for (final sequence in _pointerSequences.values) {
      if (identical(sequence.eagerMember, host)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------

  void feedDown(_PointerSequence seq, PointerDownEvent event) {
    final event0 = host._event;
    final tracksDrag = host._hasDragShape(event0);
    if (event0?.onDragDown == null && !tracksDrag) return;
    if (!_isPrimaryButtonEvent(event)) return;
    final devices = host._configOf(host._event).dragDevices ?? host.dragDevices;
    if (devices != null && !devices.contains(event.kind)) return;
    // 钝化检查：本宿主是某活跃管线的 roster 成员时不建立跟踪
    // （多指第二根手指落下也不得重建）。
    if (host._passiveDragPipeline?.active == true) return;

    if (_dragPointerId != null) {
      _trackAdditionalPointer(seq, event);
      return;
    }
    if (event0?.onDragDown != null) {
      host._fire(
        seq,
        ElEventPhase.dragDown,
        event.position,
        originalEvent: event,
      );
    }
    if (!tracksDrag) return;
    _dragPointerId = event.pointer;
    _dragDownPosition = event.position;
    _dragStarted = false;
    _dragStartDispatched = false;
    _dragDirection = null;
    _dragOffset = Offset.zero;
    _trackPointer(
      seq,
      event.pointer,
      event.position,
      event.kind,
      event.buttons,
      event,
      event.timeStamp,
    );
  }

  void _trackAdditionalPointer(_PointerSequence seq, PointerDownEvent event) {
    if (_pointerPositions.containsKey(event.pointer)) return;
    // 多指降级：第二指落下先按 raw 终点结清尾段并解除采样（一期仅单 touch
    // 指针采样），后续回 raw 多指策略路径。
    _disengageDragResampling(fireUpdate: true);
    _trackPointer(
      seq,
      event.pointer,
      event.position,
      event.kind,
      event.buttons,
      event,
      event.timeStamp,
    );
    // latestPointer 策略下,新 down 的手指立即接管驱动权(对齐官方 monodrag:
    // acceptGesture 时 `_activePointer = pointer`;闭环系统下 arena resolution
    // 等价于 down + accepted,首指已 accepted 时第二指 down 立即被 accept)。
    // 这保证第二指落下期间第一指 move 不再产生 dragUpdate——Android RecyclerView
    // 语义"最新手指接管、抬起交还"由此在 down 阶段生效,不用等第二指 move。
    if (_dragStarted &&
        host.multitouchDragStrategy == MultitouchDragStrategy.latestPointer) {
      _dragPointerId = event.pointer;
    }
    // 管线活跃时多指后续 down 复用现有管线，但新 pointer 的序列是独立对象：
    // 截断与豁免必须对它同步施加，外层竞争机器才不会经该序列复活。
    final pipeline = _pipeline;
    if (pipeline != null && pipeline.active) {
      _applyPipelineToSequence(seq, pipeline);
    }
  }

  void _trackPointer(
    _PointerSequence seq,
    int pointer,
    Offset position,
    PointerDeviceKind kind,
    int buttons,
    PointerEvent event,
    Duration timeStamp,
  ) {
    seq.hasTrackedDrag = true;
    _pointerDownPositions[pointer] = position;
    _pointerPositions[pointer] = position;
    _pointerDownTimeStamps[pointer] = timeStamp;
    _pointerLastMoveTimeStamps[pointer] = timeStamp;
    _pointerLastVelocityPositions[pointer] = position;
    _pointerKinds[pointer] = kind;
    _pointerButtons[pointer] = buttons;
    _pointerSequences[pointer] = seq;
    _pointerOrder.add(pointer);
    final tracker = _velocityTrackers[pointer] = host.velocityTrackerBuilder(
      event,
    );
    if (!event.synthesized) tracker.addPosition(timeStamp, position);
  }

  void _trackVelocitySample(PointerMoveEvent event) {
    // 对齐官方 DragGestureRecognizer：合成 move 只校正位置，不代表新的真实速度样本。
    if (event.synthesized) return;
    _pointerLastMoveTimeStamps[event.pointer] = event.timeStamp;
    _pointerLastVelocityPositions[event.pointer] = event.position;
    _velocityTrackers[event.pointer]?.addPosition(
      event.timeStamp,
      event.position,
    );
  }

  /// event 结构替换后：为已按下且仍活跃的主键指针补种 drag 跟踪
  /// （对齐旧 `_seedDragTrackingForActivePrimaryIfNeeded`）。
  void seedForActivePrimaryIfNeeded() {
    if (_dragPointerId != null) return;
    // 钝化检查：roster 成员的结构替换补种同样禁用，防止钝化后自机复活。
    if (host._passiveDragPipeline?.active == true) return;
    final tap = host._tapMachine;
    final downEvent = tap?._downEvent;
    final seq = tap?._seq;
    if (downEvent == null || seq == null) return;
    if (!_isPrimaryButtonEvent(downEvent)) return;
    final devices = host._configOf(host._event).dragDevices ?? host.dragDevices;
    if (devices != null && !devices.contains(downEvent.kind)) return;

    _dragPointerId = downEvent.pointer;
    _dragDownPosition = downEvent.position;
    _dragStarted = false;
    _dragStartDispatched = false;
    _dragDirection = null;
    _dragOffset = Offset.zero;
    _trackPointer(
      seq,
      downEvent.pointer,
      downEvent.position,
      downEvent.kind,
      downEvent.buttons,
      downEvent,
      downEvent.timeStamp,
    );
  }

  /// move 处理中途配置被结构替换：更新位置/速度，按**旧配置**判定接受但不
  /// 派发 dragStart（deferred：下一次 move 补发）。返回是否本次接受了拖拽。
  /// 对齐旧 `_settleDragMoveAfterEventReplacement`。
  bool _settleMoveAfterReplacement(
    _PointerSequence seq,
    PointerMoveEvent event,
    ElEvent previousConfig,
  ) {
    if (!_pointerPositions.containsKey(event.pointer)) return false;
    // 钝化检查：roster 成员的替换沉降同样禁用，防止钝化后自机复活。
    if (host._passiveDragPipeline?.active == true) return false;
    // 沉降走 raw 口径：先静默结清采样尾段（路径契约"不派发"），账目回到
    // 投影 raw 累计；后续 deferred dragStart 补发后可再挂载。
    _disengageDragResampling(fireUpdate: false);
    // latestPointer 策略下 dragPointerId 只在 down / _removePointer fallback 时
    // 切换,move 事件不切换驱动权(否则任何非当前驱动手指的抖动 move 都会抢回
    // 驱动权,违反 Android RecyclerView 的 activePointer 语义)。
    final Offset beforeOffset =
        _dragStarted &&
            host.multitouchDragStrategy ==
                MultitouchDragStrategy.averageBoundaryPointers
        ? _dragOffset
        : _strategyOffset(previousConfig);
    _pointerPositions[event.pointer] = event.position;
    _trackVelocitySample(event);
    final afterOffset = _strategyOffset(
      previousConfig,
      pointer: event.pointer,
      delta: event.delta,
      timeStamp: event.timeStamp,
    );
    final effectiveDelta = afterOffset - beforeOffset;
    if (_dragStarted) {
      _dragOffset += effectiveDelta;
      _recordAverageBoundaryFrameDelta(
        event.pointer,
        event.delta,
        event.timeStamp,
      );
      return false;
    }
    final accepted = _acceptedDragAxisAndDirection(
      previousConfig,
      afterOffset,
      event.kind,
    );
    if (accepted == null) {
      _recordAverageBoundaryFrameDelta(
        event.pointer,
        event.delta,
        event.timeStamp,
      );
      return false;
    }
    final (axis, direction) = accepted;
    _dragStarted = true;
    _dragStartDispatched = false;
    _acceptedAxis = axis;
    _dragDirection = direction;
    // 台账零基起账（同 feedMove 接受分支）：accept 前段位移不进上层。
    _dragOffset = Offset.zero;
    _recordAverageBoundaryFrameDelta(
      event.pointer,
      event.delta,
      event.timeStamp,
    );
    return true;
  }

  /// 同步解析命中链中更近后代的 Start 提案，再兑现本机 DragStart。
  ///
  /// handler 的存在本身不参与竞争；后代只有真实 stop / eager 才能使本机失权。
  /// 结构替换沉降把 `_dragStartDispatched` 留为 false，下一次 move 也从本入口
  /// 补齐同一套路由，而不会绕过后代边界。
  bool _dispatchDragStartIfNeeded(
    _PointerSequence seq,
    PointerEvent event, {
    bool formPipeline = true,
  }) {
    if (_dragStartDispatched) return true;
    final direction = _dragDirection ?? AxisDirection.down;
    final hostIndex = seq.indexOf(host);
    if (hostIndex < 0 ||
        !host._memberActiveAt(seq, hostIndex) ||
        seq.blockedAt(ElEventPhase.dragStart, hostIndex) ||
        !_pointerPositions.containsKey(event.pointer)) {
      resetSilently();
      return false;
    }
    final observedFamily = seq.observedDragStartFamily(host);
    final acceptedFamily = seq.dragStartFamilyFor(host, _acceptedAxis);
    if (observedFamily != 0 && observedFamily != acceptedFamily) {
      // 同一 pointer 的公开 Start 已锁定回调组；单台 DragMachine 不能再换轴
      // 产生没有独立终态的第二条生命周期。
      resetSilently();
      return false;
    }
    final alreadyObserved = observedFamily != 0;
    if (alreadyObserved) {
      _dragDirection = seq.observedDragStartDirection(host) ?? _dragDirection;
      _acceptedAxis = seq.observedDragStartAxis(host);
    } else if (seq.dragStartAxisConflicts(_acceptedAxis)) {
      // 同一 pointer 的 Drag 轴一旦公开，后续不同轴候选不得补启动。
      resetSilently();
      return false;
    }
    final canCreatePipeline = formPipeline && !alreadyObserved;
    var pipelinePlan = canCreatePipeline ? _resolvePipelinePlan(seq) : null;
    final planEpoch = ElEventDispatcher._configCascadeEpoch;
    final planDragCutoff = seq.dragRouteCutoff;
    final planPrimaryCutoff = seq.primaryGestureCutoff;
    final planEager = seq.eagerMember;
    final pipelineIntent = pipelinePlan != null;
    if (!alreadyObserved &&
        !host._routeDragStartProposal(
          seq,
          event,
          direction,
          dragAxis: _acceptedAxis,
          dragPipelineActive: pipelineIntent,
        )) {
      resetSilently();
      return false;
    }
    if (!_pointerPositions.containsKey(event.pointer) ||
        !host._memberActiveAt(seq, hostIndex) ||
        seq.blockedAt(ElEventPhase.dragStart, hostIndex)) {
      resetSilently();
      return false;
    }
    _dragStartDispatched = true;
    if (!alreadyObserved) {
      host._fireDragStart(
        seq,
        event,
        Offset.zero,
        Offset.zero,
        direction,
        dragAxis: _acceptedAxis,
        dragPipelineActive: pipelineIntent,
        endIndexExclusive: pipelinePlan?.latchBreakMember == null
            ? null
            : seq.indexOf(pipelinePlan!.latchBreakMember!),
      );
      if (!_pointerPositions.containsKey(event.pointer) ||
          !host._memberActiveAt(seq, hostIndex) ||
          seq.blockedAt(ElEventPhase.dragStart, hostIndex)) {
        resetSilently();
        return false;
      }
    }
    // Start 先只暴露管线意图；stop/eager/结构替换的真实结果同步可见后才提交
    // Tap 取消与 roster 钝化，stop-only Drag 不会留下任何复合副作用。
    if (canCreatePipeline) {
      final planInvalidated =
          planEpoch != ElEventDispatcher._configCascadeEpoch ||
          planDragCutoff != seq.dragRouteCutoff ||
          planPrimaryCutoff != seq.primaryGestureCutoff ||
          !identical(planEager, seq.eagerMember);
      if (planInvalidated) pipelinePlan = _resolvePipelinePlan(seq);
      if (pipelinePlan != null) _commitPipeline(seq, event, pipelinePlan);
    }
    return _dragStarted &&
        _dragStartDispatched &&
        _pointerPositions.containsKey(event.pointer);
  }

  void feedMove(_PointerSequence seq, PointerMoveEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    // 钝化检查：roster 成员的自机推进禁用。driver 自身推进不受影响
    // （其 _passiveDragPipeline 为 null）。
    if (host._passiveDragPipeline?.active == true) return;
    final down = _dragDownPosition;
    final event0 = host._event;
    if (down == null || !host._hasDragShape(event0)) {
      resetSilently();
      return;
    }
    final dragEvent = event0!;

    if (_buttonsChanged(event)) {
      _cancelForButtonsChange(seq, event);
      return;
    }
    final resampler = _dragResampler;
    if (resampler != null) {
      if (event.pointer == _dragPointerId && _dragResamplingGatesHold()) {
        // 采样快路径：raw 只记账（位置 / 时间戳 / 速度全吃原始事件），渲染
        // 节奏完全交给帧回调——事件本身绝不触发派发（杜绝双驱动）。
        _pointerPositions[event.pointer] = event.position;
        _trackVelocitySample(event);
        _lastResampledSourceMove = event;
        resampler.push(event.timeStamp, event.position);
        return;
      }
      // 门控失效（开关 / config 中途翻转）或异常指针来源：结清尾段转回 raw。
      _disengageDragResampling(fireUpdate: true);
    }

    // 见 _settleMoveAfterReplacement 处的相同注释:latestPointer 策略在 down 阶段
    // 切换 dragPointerId,move 不切换。
    final Offset beforeOffset =
        _dragStarted &&
            host.multitouchDragStrategy ==
                MultitouchDragStrategy.averageBoundaryPointers
        ? _dragOffset
        : _strategyOffset(dragEvent);
    _pointerPositions[event.pointer] = event.position;
    _trackVelocitySample(event);
    final afterOffset = _strategyOffset(
      dragEvent,
      pointer: event.pointer,
      delta: event.delta,
      timeStamp: event.timeStamp,
    );
    final effectiveDelta = afterOffset - beforeOffset;

    if (!_dragStarted) {
      final intentOffset = _strategyOffset(
        dragEvent,
        pointer: event.pointer,
        delta: event.delta,
        timeStamp: event.timeStamp,
        preserveCrossAxis: true,
      );
      final accepted = _acceptedDragAxisAndDirection(
        dragEvent,
        intentOffset,
        event.kind,
      );
      if (accepted == null) return;
      final (axis, direction) = accepted;
      _dragStarted = true;
      _dragStartDispatched = false;
      _acceptedAxis = axis;
      _dragDirection = direction;
      // 台账零基起账：down→accept 的 slop 段位移**彻底丢弃**，对上层的
      // delta 流与 dragOffset 流都不可见——两条流恒同口径（dragOffset ≡
      // 已派发 delta 的累计）。曾以投影 raw 累计做种子：dragStart 报 0、
      // 首个 dragUpdate 的 dragOffset 却带上整段激活距离，dragOffset
      // 消费者首帧一口气追账，视觉上跳一下。起手段几何内部仍可由
      // [_pointerDownPositions] 推得，禁止再流入任何上层回调。
      _dragOffset = Offset.zero;
      // dragStart 为纯生命周期信号：种子（delta / remainingDelta / dragOffset）
      // 全部归零，分账从首个 dragUpdate 帧开始。对齐 Flutter DragStartBehavior.start
      // 的"down→accept 位移丢弃、首帧从 0 跟手"契约；避免真机首帧合并事件把 30+px
      // 一口气 apply 到 position 造成跳动。
      if (!_dispatchDragStartIfNeeded(seq, event)) return;
      _recordAverageBoundaryFrameDelta(
        event.pointer,
        event.delta,
        event.timeStamp,
      );
      _maybeEngageDragResampling(event);
      return;
    }

    if (effectiveDelta == Offset.zero) {
      _recordAverageBoundaryFrameDelta(
        event.pointer,
        event.delta,
        event.timeStamp,
      );
      _maybeEngageDragResampling(event);
      return;
    }
    _dragOffset += effectiveDelta;
    if (!_dragStartDispatched) {
      // dragStart 纯生命周期信号：种子归零，与 feedMove 接受分支对齐。
      if (!_dispatchDragStartIfNeeded(seq, event)) return;
    }
    host._fireWithDelta(
      seq,
      ElEventPhase.dragUpdate,
      event.position,
      _projectToAxis(_acceptedAxis, effectiveDelta),
      _dragOffset,
      dragDirection: _dragDirection,
      dragAxis: _acceptedAxis,
      originalEvent: event,
    );
    _recordAverageBoundaryFrameDelta(
      event.pointer,
      event.delta,
      event.timeStamp,
    );
    _maybeEngageDragResampling(event);
  }

  void feedUp(_PointerSequence seq, PointerUpEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    final down = _dragDownPosition;
    final dragEvent = host._event;
    if (down == null || dragEvent == null) {
      resetSilently();
      return;
    }

    // 采样器在场：先按 raw 终点结清未采样尾段（消费者位移一像素不丢），再走
    // raw 结算——_dragOffset 回到 raw 增量口径（零基台账），velocity 兑现全程无感。
    // fire 可能触发消费者反调（cancel / 结构替换），结清后重查跟踪在场。
    if (_dragResampler != null) {
      _disengageDragResampling(fireUpdate: true);
      if (!_pointerPositions.containsKey(event.pointer)) return;
    }

    final beforeOffset = _strategyOffset(dragEvent);
    // up 的位置可能是平台上报的合成跳变(memory:up 位置不喂 tracker、不参与
    // velocity)。velocity fallback 使用最后一个真实 move，不能采信 up 前补发
    // 的合成 move；几何位移仍由 _pointerPositions 完整保留。
    final preUpPosition = _pointerLastVelocityPositions[event.pointer];
    _pointerPositions[event.pointer] = event.position;
    final afterOffset = _strategyOffset(dragEvent);
    final effectiveDelta = afterOffset - beforeOffset;
    if (effectiveDelta != Offset.zero) {
      _dragOffset += effectiveDelta;
    }
    // 契约:up 事件位置**绝不**喂 VelocityTracker。两个理由:
    // - 平台可能上报合成跳变位置(见 drag_velocity_test "ignores pointerUp-only
    //   position jump"),污染估计;
    // - 非塌缩场景 up 与最后 move 位置相同,喂进去等于追加一个"停住"样本,
    //   3 点 LSQ 会把末端速度掰小甚至掰反(实测 SLOP-1 变反向 fling)。
    // 塌缩场景(采样点不足)的速度由 _endVelocity/_preAcceptFlingVelocity 的
    // fallback 分支重建(经 _trustedEndPosition 甄别 + 末端补偿)。
    final isLastPointer = _pointerPositions.length == 1;
    var velocity = Velocity.zero;
    // pre-accept 轻扫的胜出轴由 fling 裁决产出（双轴候选按速度分量竞争）；
    // 已接受场景恒为 _acceptedAxis。
    var flingAxis = _acceptedAxis;
    if (isLastPointer && _dragStarted) {
      velocity = _endVelocity(dragEvent, event, preUpPosition);
    } else if (isLastPointer) {
      (velocity, flingAxis) = _preAcceptFlingVelocity(
        dragEvent,
        event,
        preUpPosition,
      );
    }
    if (!isLastPointer) {
      _removePointer(event.pointer);
      return;
    }

    if (_dragStarted && !_dragStartDispatched) {
      resetSilently();
      return;
    }

    if (_dragStarted && _dragStartDispatched) {
      final dragOffset = _dragOffset;
      final dragDirection = _dragDirection;
      final acceptedAxis = _acceptedAxis;
      resetSilently();
      host._fireWithVelocity(
        seq,
        ElEventPhase.dragEnd,
        event.position,
        velocity,
        dragOffset,
        dragDirection: dragDirection,
        dragAxis: acceptedAxis,
        originalEvent: event,
      );
      return;
    }
    if (!_dragStarted && velocity.pixelsPerSecond != Offset.zero) {
      // 轻扫救援的全部位移都落在激活前段：方向判定用真实位移，对外
      // dragOffset 归零（零基契约下本手势未派发过任何 delta，dragEnd 不得
      // 把激活前段追账进来），消费者以 velocity 起 fling。
      final flingOffset = _projectToAxis(flingAxis, afterOffset);
      final dragDirection = _directionForPreAcceptFling(
        flingAxis,
        flingOffset,
        velocity,
        host._configOf(dragEvent).dragHorizontalAngle,
      );
      _dragStarted = true;
      _dragStartDispatched = false;
      _acceptedAxis = flingAxis;
      _dragDirection = dragDirection;
      _dragOffset = Offset.zero;
      if (!_dispatchDragStartIfNeeded(seq, event, formPipeline: false)) return;
      resetSilently();
      host._fireWithVelocity(
        seq,
        ElEventPhase.dragEnd,
        event.position,
        velocity,
        Offset.zero,
        dragDirection: dragDirection,
        dragAxis: flingAxis,
        originalEvent: event,
      );
      return;
    }
    _removePointer(event.pointer);
    resetSilently();
  }

  void feedCancel(_PointerSequence seq, PointerCancelEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    // 终态前静默并账采样尾段，dragCancel 报出的 dragOffset 与 raw 口径一致。
    _disengageDragResampling(fireUpdate: false);
    _removePointer(event.pointer);
    if (_pointerPositions.isNotEmpty) return;
    if (_dragStarted && _dragStartDispatched) {
      final dragOffset = _dragOffset;
      final dragDirection = _dragDirection;
      final acceptedAxis = _acceptedAxis;
      resetSilently();
      host._fireDragCancel(
        seq,
        event,
        dragOffset: dragOffset,
        dragDirection: dragDirection,
        dragAxis: acceptedAxis,
      );
      return;
    }
    resetSilently();
  }

  void feedRemoved(_PointerSequence seq, PointerRemovedEvent event) {
    final pointer = event.pointer;
    if (!_pointerPositions.containsKey(pointer)) return;
    // 普通 legacy drag 保持 PointerRemoved 静默合同；只有持有复合管线或 eager
    // 独占资源的 driver 需要公开 cancel，避免 page gap / ghost 等状态泄漏。
    final ownsCompositeState =
        _pipeline?.active == true || identical(seq.eagerMember, host);
    if (_pointerPositions.length == 1 && ownsCompositeState) {
      cancelActive(event: event, pointerCount: _pointerCountAfterTerminal);
      return;
    }
    removePointerSilently(pointer);
  }

  /// 静默移除单个指针（不触发回调）。
  void removePointerSilently(int pointer) {
    if (!_pointerPositions.containsKey(pointer)) return;
    if (_pointerPositions.length == 1) {
      resetSilently();
      return;
    }
    _removePointer(pointer);
  }

  /// 主动取消进行中的 drag（fire dragCancel）。
  void cancelActive({
    PointerEvent? event,
    int pointerCount = _pointerCountCurrent,
  }) {
    // 终态前静默并账采样尾段（同 feedCancel）。
    _disengageDragResampling(fireUpdate: false);
    if (_dragPointerId == null || !_dragStarted) {
      resetSilently();
      return;
    }
    if (!_dragStartDispatched) {
      resetSilently();
      return;
    }
    final seq = _activeSequence;
    final position = event?.position ?? host._lastPointerPosition;
    final dragOffset = _dragOffset;
    final dragDirection = _dragDirection;
    final acceptedAxis = _acceptedAxis;
    resetSilently();
    host._fireWithDelta(
      seq,
      ElEventPhase.dragCancel,
      position,
      Offset.zero,
      dragOffset,
      dragDirection: dragDirection,
      dragAxis: acceptedAxis,
      pointerCount: pointerCount,
      originalEvent: event,
    );
  }

  void _cancelForButtonsChange(_PointerSequence seq, PointerMoveEvent event) {
    _disengageDragResampling(fireUpdate: false);
    if (_dragStarted && _dragStartDispatched) {
      final dragOffset = _dragOffset;
      final dragDirection = _dragDirection;
      final acceptedAxis = _acceptedAxis;
      resetSilently();
      host._fireWithDelta(
        seq,
        ElEventPhase.dragCancel,
        event.position,
        Offset.zero,
        dragOffset,
        dragDirection: dragDirection,
        dragAxis: acceptedAxis,
        originalEvent: event,
      );
      return;
    }
    resetSilently();
  }

  /// scale 手势接受时取消 drag。
  void cancelForScaleGesture(
    Offset focalPoint, {
    Object? originalEvent,
    bool selfOnly = false,
  }) {
    if (_dragPointerId == null) return;
    // 终态前静默并账采样尾段（同 feedCancel）。
    _disengageDragResampling(fireUpdate: false);
    if (_dragStarted && _dragStartDispatched) {
      final seq = selfOnly ? null : _activeSequence;
      final dragOffset = _dragOffset;
      final dragDirection = _dragDirection;
      final acceptedAxis = _acceptedAxis;
      resetSilently();
      host._fireWithDelta(
        seq,
        ElEventPhase.dragCancel,
        focalPoint,
        Offset.zero,
        dragOffset,
        dragDirection: dragDirection,
        dragAxis: acceptedAxis,
        originalEvent: originalEvent,
        selfOnly: selfOnly,
      );
      return;
    }
    resetSilently();
  }

  /// 静默重置全部跟踪状态。
  void resetSilently() {
    _dissolvePipeline();
    _disengageDragResampling(fireUpdate: false);
    _dragPointerId = null;
    _dragDownPosition = null;
    _dragDirection = null;
    _acceptedAxis = null;
    _dragStarted = false;
    _dragStartDispatched = false;
    _dragOffset = Offset.zero;
    _pointerDownPositions.clear();
    _pointerPositions.clear();
    _pointerDownTimeStamps.clear();
    _pointerLastMoveTimeStamps.clear();
    _pointerLastVelocityPositions.clear();
    _pointerKinds.clear();
    _pointerButtons.clear();
    _velocityTrackers.clear();
    _pointerSequences.clear();
    _pointerOrder.clear();
    _averageBoundaryFrameDeltas.clear();
    _averageBoundaryFrameTimeStamp = null;
    _averageBoundaryLastPanFrameDelta = Offset.zero;
  }

  /// 解散当前作为 driver 挂载的管线：置 active=false、清 roster 成员反向引用、
  /// 置 _pipeline=null。覆盖 dragEnd / dragCancel / removed / eager 失权 /
  /// 结构替换 cancelActive 全部路径（都经 resetSilently）。
  void _dissolvePipeline() {
    final pipeline = _pipeline;
    if (pipeline == null) return;
    pipeline.active = false;
    for (final seq in _pointerSequences.values) {
      final target = seq.scaleUpgradeTarget;
      if (identical(target, host) || pipeline.exemptMembers.contains(target)) {
        seq.scaleUpgradeTarget = null;
      }
    }
    for (final member in pipeline.roster) {
      if (identical(member._passiveDragPipeline, pipeline)) {
        member._passiveDragPipeline = null;
      }
    }
    _pipeline = null;
  }

  /// 形成分账管线：从 driver（host）沿链向外收集所有兼容 [ElDragProxy]
  /// 的祖先成员组成 roster。
  ///
  /// 语义细则：
  /// - 跳过 eager / primaryGestureCutoff 之外的成员；
  /// - **latch 截断**：遇到"有 drag 回调
  ///   但 dragProxy 为空或轴不兼容"的竞争型拖拽消费者立即停止收集；
  /// - 已被其他活跃管线钝化的成员跳过不重复收编；
  /// - roster 为空 → 不建管线（走完全现状路径，零成本）；
  /// - 钝化 roster 成员 drag 机（resetSilently + 设 _passiveDragPipeline）；
  /// - 施加 formation cutoff（primaryGestureCutoff = latch 截断点索引）+
  ///   pipelineExemptMembers = roster；这是外层非 roster 竞争机器的压制来源
  ///   （绝不调 eagerGesture，否则 roster 成员的投递会被 eager 杀掉）。
  _DragPipelinePlan? _resolvePipelinePlan(_PointerSequence seq) {
    if (_pipeline != null) return null; // 已存在管线（多指后续 down 复用现有管线）
    final driverIndex = seq.indexOf(host);
    if (driverIndex < 0) return null;
    // 形成时机在拖拽接受之后，胜出轴已定；roster 兼容以胜出轴为准。
    final driverAxis = _acceptedAxis;

    final roster = <ElEventDispatcher>[];
    ElEventDispatcher? latchBreakMember;
    for (var i = driverIndex + 1; i < seq.chain.length; i++) {
      // proposal 阶段已经由更近后代建立的 route 边界不能在稍后接受时被
      // DragProxy 管线绕过；driver 自身 Start 新建的边界仍由既有豁免处理。
      if (i >= seq.dragRouteCutoff) break;
      final member = seq.chain[i];
      // 已被 eager 排除的成员跳过；被主键手势截断的成员亦跳过。
      if (!host._memberActiveAt(seq, i)) continue;
      if (i >= seq.primaryGestureCutoff) continue;

      // 竞争判定按 driver 胜出轴过滤（2026-08-09 缺陷修复）：交叉轴滚动组
      // 接不了本轴 delta，不构成竞争也不截断收集——垂直滚动不得挡住更外层
      // 的横向 proxy（tab 滑动）入 roster。
      final memberCompetesOnAxis = ElEventDispatcher._memberConsumesDragAxis(
        member,
        driverAxis,
      );
      final proxy = member._event?.dragProxy;
      final proxyCompatible =
          proxy != null &&
          proxy.hasAnyHandler &&
          _axisCompatible(proxy.axis, driverAxis);

      // latch 截断：**同轴**竞争型消费者（有本轴 drag shape 但无兼容 proxy，
      // 如同轴外层滚动）出现在 driver 之上 → 停止收集，后续更外层的 proxy
      // 不入 roster（管线不得穿透该 latch，driver 与它之间按现状 latch/defer
      // 规则换手）。
      if (memberCompetesOnAxis && !proxyCompatible) {
        latchBreakMember = member;
        break;
      }

      if (!proxyCompatible) continue;
      // 已被其他活跃管线钝化 → 跳过不重复收编。
      if (member._passiveDragPipeline?.active == true) continue;

      roster.add(member);
    }

    if (roster.isEmpty) return null;
    return (
      roster: roster,
      latchBreakMember: latchBreakMember,
      axis: driverAxis,
    );
  }

  /// Start 路由裁决完成后提交预先解析的复合管线计划。
  void _commitPipeline(
    _PointerSequence seq,
    PointerEvent event,
    _DragPipelinePlan plan,
  ) {
    if (_pipeline != null || plan.roster.isEmpty) return;
    final roster = plan.roster;
    final driverAxis = plan.axis;
    final latchBreakMember = plan.latchBreakMember;

    // 复合管线是一个协作式 Drag winner：保留 roster 的分账生命周期，但
    // 当前 pointer 的 Tap 激活必须同步取消，不能退回普通 passive drag 语义。
    seq.cancelTapActivationsForDragPipeline(event, host);

    final pipeline = _DragPipeline(
      driver: host,
      roster: roster,
      axis: driverAxis,
      latchBreakMember: latchBreakMember,
    );
    _pipeline = pipeline;

    // 钝化 roster 成员的 drag 机：resetSilently 清理跟踪，然后设反向引用。
    for (final member in roster) {
      member._dragMachine?.resetSilently();
      member._passiveDragPipeline = pipeline;
    }

    // 对本序列施加形成即截断 + 投递豁免。
    _applyPipelineToSequence(seq, pipeline);
    // driver 已跟踪的其他 pointer 各自有序列，同样施加。
    if (_pointerSequences.length > 1) {
      final applied = <_PointerSequence>{seq};
      for (final otherSeq in _pointerSequences.values) {
        if (!applied.add(otherSeq)) continue;
        _applyPipelineToSequence(otherSeq, pipeline);
      }
    }
  }

  /// 对单条序列施加"形成即截断"+ 投递豁免。
  ///
  /// 形成时对涉事各序列调用；管线活跃期间多指后续 down 在
  /// [_trackAdditionalPointer] 接受跟踪时对新序列同步施加——否则外层竞争
  /// 机器会在第二指序列上照常收 down/move 并可能并行接受拖拽，roster 成员
  /// 也会因缺豁免而收不到该序列上 fire 的 dragEnd。
  void _applyPipelineToSequence(_PointerSequence seq, _DragPipeline pipeline) {
    final breakMember = pipeline.latchBreakMember;
    var cutoff = seq.chain.length;
    if (breakMember != null) {
      final breakIndex = seq.indexOf(breakMember);
      if (breakIndex >= 0) cutoff = breakIndex;
    }
    if (cutoff < seq.primaryGestureCutoff) {
      seq.primaryGestureCutoff = cutoff;
      // 静默压制被截断的非 roster 外层成员（等价旧 latch 的 eagerGesture 效果，
      // 但保留 roster 成员——其反向压制走 _passiveDragPipeline 通道）。
      for (var i = cutoff; i < seq.chain.length; i++) {
        final member = seq.chain[i];
        if (pipeline.exemptMembers.contains(member)) continue;
        member._suppressPrimaryGestureSilently(seq);
      }
    }
    final existing = seq.pipelineExemptMembers;
    if (existing == null) {
      seq.pipelineExemptMembers = HashSet<ElEventDispatcher>.identity()
        ..addAll(pipeline.exemptMembers);
    } else {
      existing.addAll(pipeline.exemptMembers);
    }
    if (seq.eagerMember == null) {
      final scaleTarget = seq.resolveScaleTracker();
      if (identical(scaleTarget, pipeline.driver) ||
          pipeline.exemptMembers.contains(scaleTarget)) {
        seq.scaleUpgradeTarget = scaleTarget;
      }
    }
  }

  static bool _axisCompatible(Axis? proxyAxis, Axis? driverAxis) {
    if (driverAxis == null) return proxyAxis == null;
    return proxyAxis == null || proxyAxis == driverAxis;
  }

  void _removePointer(int pointer) {
    _pointerDownPositions.remove(pointer);
    _pointerPositions.remove(pointer);
    _pointerDownTimeStamps.remove(pointer);
    _pointerLastMoveTimeStamps.remove(pointer);
    _pointerLastVelocityPositions.remove(pointer);
    _pointerKinds.remove(pointer);
    _pointerButtons.remove(pointer);
    // tracker 与其他每指针状态同点清理：全部调用点的速度计算都发生在移除
    // 之前，此处删除不影响 _endVelocity / _preAcceptFlingVelocity 取值。
    _velocityTrackers.remove(pointer);
    _pointerSequences.remove(pointer);
    _pointerOrder.remove(pointer);
    _averageBoundaryFrameDeltas.remove(pointer);
    if (_dragPointerId == pointer) {
      _dragPointerId = _latestActivePointer();
    }
  }

  int? _latestActivePointer() {
    for (final pointer in _pointerOrder.reversed) {
      if (_pointerPositions.containsKey(pointer)) return pointer;
    }
    return null;
  }

  bool _buttonsChanged(PointerMoveEvent event) {
    if (!_tracksStableButtons(event.kind)) return false;
    final expected = _pointerButtons[event.pointer];
    return expected != null && event.buttons != expected;
  }

  // --- 触控重采样（帧驱动插值，见 _DragResampler 类注） ---------------------

  /// 帧驱动采样器；仅在单 touch 指针拖拽 accepted 后在场。
  DragResampler? _dragResampler;

  /// 采样期最近一个 raw move：合成 dragUpdate 的 originalEvent 载体 +
  /// deferred dragStart 补发的事件源。
  PointerMoveEvent? _lastResampledSourceMove;

  /// accepted 后尝试挂载采样器；任一门控不满足则静默跳过（保持 raw 驱动）。
  ///
  /// 多指抬回单指后每个 started move 都会再次尝试，自动重新挂载。
  void _maybeEngageDragResampling(PointerMoveEvent event) {
    if (_dragResampler != null) return;
    if (!_dragStarted) return;
    if (event.pointer != _dragPointerId) return;
    if (!_dragResamplingGatesHold()) return;
    // seed = 挂载时刻的 raw 位置：此后逐帧采样 delta 求和与端点相减等价
    // （投影线性），解除时结清尾段即可严格回到 raw 增量口径（_dragOffset
    // 是零基台账，与投影 raw 累计恒差已丢弃的起手段）。偏移配方（覆写档
    // 固定 / builder 下限 + 自适应尾随）收口在共享工厂。
    final resampler = createDragResampler(
      DragResamplingContext(
        refreshRate: host._displayRefreshRate(),
        seedTime: event.timeStamp,
        seedPosition: event.position,
        onSample: _onResampledMove,
      ),
    );
    if (resampler == null) return;
    _lastResampledSourceMove = event;
    _dragResampler = resampler;
  }

  /// 采样器的持续门控（挂载与快路径共用）：全局调试总闸 / 平台（宿主平台 ∈
  /// 当前有效 config 的平台集合）/ 单指针且种类过平台矩阵 / drag shape。
  bool _dragResamplingGatesHold() {
    if (!DragResamplingPolicy.allowsGlobalGate()) return false;
    final platform = DragResamplingPolicy.hostPlatform;
    if (platform == null) return false;
    if (_pointerKinds.length != 1) return false;
    if (!dragResamplingAllowsKind(
      platform: platform,
      kind: _pointerKinds.values.single,
    )) {
      return false;
    }
    return host._hasDragShape(host._event) &&
        host.config.dragResampling.contains(platform);
  }

  /// 采样器帧回调：把插值位移按胜出轴投影并经正常投递引擎派发 dragUpdate。
  ///
  /// 帧回调没有环境 [_DispatchCycle]，自包 run（嵌套安全）。
  void _onResampledMove(
    DragResampler resampler,
    Offset position,
    Offset delta,
  ) {
    if (!identical(resampler, _dragResampler)) return;
    final pointer = _dragPointerId;
    if (!_dragStarted || pointer == null) {
      _disengageDragResampling(fireUpdate: false);
      return;
    }
    final projected = _projectToAxis(_acceptedAxis, delta);
    if (projected == Offset.zero) return;
    _dragOffset += projected;
    final seq = _pointerSequences[pointer];
    final sourceMove = _lastResampledSourceMove;
    _DispatchCycle.run(() {
      // 每个采样帧都是独立的合成事件周期；复用上一 raw move 的 delivery 位图
      // 会把第二帧起的 dragUpdate 误判成重复投递。
      seq?.beginCycle();
      if (!_dragStartDispatched) {
        // 投递引擎按 deferred 契约丢弃过 dragStart：采样驱动下由帧回调补发
        // （raw 驱动下由下一次 move 补发，此处等价）。
        final sequence = seq;
        if (sequence == null) {
          resetSilently();
          return;
        }
        final proposalEvent =
            sourceMove ??
            PointerMoveEvent(
              pointer: pointer,
              position: position,
              delta: projected,
              kind: _pointerKinds[pointer] ?? PointerDeviceKind.touch,
              buttons: _pointerButtons[pointer] ?? 0,
            );
        if (!_dispatchDragStartIfNeeded(sequence, proposalEvent)) return;
      }
      host._fireWithDelta(
        seq,
        ElEventPhase.dragUpdate,
        position,
        projected,
        _dragOffset,
        dragDirection: _dragDirection,
        dragAxis: _acceptedAxis,
        originalEvent: sourceMove,
        sampleTimeStamp: resampler.lastSampleTime,
      );
    });
  }

  /// 解除采样并把"最新 raw 位置 − 已采样位置"的尾段结清进 [_dragOffset]。
  ///
  /// [fireUpdate]：true = 尾段作为一次常规 dragUpdate 派发（up / 多指降级等
  /// raw 即将接管、消费者位移不能丢的路径，须在环境 cycle 内调用）；false =
  /// 仅并账不派发（cancel / 静默沉降；resetSilently 里账目随后清零，并账为
  /// 无害冗余）。
  ///
  /// 例外：尾段是纯外推过冲的回收账时（[DragResampler.isOvershootPayback]）
  /// fireUpdate 也降级为静默并账——负尾段派发到 clamping 边界会让内容倒走
  /// 一帧（安卓拉伸"松手闪一下"根因），而账目仍按 raw 口径结清，dragEnd 的
  /// dragOffset / 速度不受影响。
  void _disengageDragResampling({required bool fireUpdate}) {
    final resampler = _dragResampler;
    if (resampler == null) return;
    _dragResampler = null;
    final sampled = resampler.lastSampledPosition;
    resampler.dispose();
    final sourceMove = _lastResampledSourceMove;
    _lastResampledSourceMove = null;
    final pointer = _dragPointerId;
    if (!_dragStarted || pointer == null) return;
    final raw = _pointerPositions[pointer];
    if (raw == null) return;
    final projected = _projectToAxis(_acceptedAxis, raw - sampled);
    if (projected == Offset.zero) return;
    _dragOffset += projected;
    if (!fireUpdate || !_dragStartDispatched) return;
    // 过冲回收账静默并账：负尾段不派发（见方法注释），账目已按 raw 结清。
    if (resampler.isOvershootPayback(projected)) return;
    host._fireWithDelta(
      _pointerSequences[pointer],
      ElEventPhase.dragUpdate,
      raw,
      projected,
      _dragOffset,
      dragDirection: _dragDirection,
      dragAxis: _acceptedAxis,
      originalEvent: sourceMove,
    );
    // 结清 update 与 dragEnd / 机器 reset 同处一个派发周期：排队到周期末
    // flush 时 pipeline 已被 reset 置为不活跃，_deliverQueued 复查失败会把
    // 管线阶段（pre/overflow）整体跳过——尾段全量直达 driver（嵌套拖拽代理
    // "松手被吞"根因）。立即 flush 让尾段在管线仍活跃时按三段分账送达，
    // feedUp 结清后的"消费者反调重查"防御也由此真正生效。
    _DispatchCycle.flushNow();
  }

  // --- 多指策略 / 轴向 / 阈值（自旧实现移植） --------------------------------

  Velocity _endVelocity(
    ElEvent event,
    PointerUpEvent upEvent,
    Offset? preUpPosition,
  ) {
    final endingPointer = upEvent.pointer;
    final lastMoveTimeStamp = _pointerLastMoveTimeStamps[endingPointer];
    if (lastMoveTimeStamp == null ||
        upEvent.timeStamp - lastMoveTimeStamp > _kReleaseMoveGap) {
      return Velocity.zero;
    }
    final estimate = _velocityTrackers[endingPointer]?.getVelocityEstimate();
    final kind = _pointerKinds[endingPointer] ?? PointerDeviceKind.touch;
    if (estimate != null) {
      if (_isFlingGesture(_acceptedAxis, event, estimate, kind)) {
        return _clampedVelocity(_acceptedAxis, event, estimate.pixelsPerSecond);
      }
      // fallback 只救"测量缺失",不推翻"有效测量的判定"。tracker 的两种
      // **全零占位**都不是真实测量,一并放行 fallback:
      // - 样本 <3:pixelsPerSecond 恒 zero、offset 记录 newest-oldest 位移;
      // - stopped 占位:samplingClock **墙钟**距最后 addPosition 超 40ms 返回
      //   全零——真机 jank/重采样排队会让高速轻扫误中此分支(实机"正常连续
      //   滚动也被打断"),它区分不了"手指停了"和"事件晚处理了"。
      // 真停顿已按事件时间拦截；墙钟处理延迟不能否决兜底，有效 LSQ 低速仍尊重归零。
      if (estimate.pixelsPerSecond != Offset.zero) return Velocity.zero;
    }
    // 塌缩/占位兜底:平台帧批量投递或极短轻扫下,硬件可能只报出"down(+ up)"
    // 两个样本 → LSQ 无法估计(自建帧驱动采样器不重写事件流,不再制造塌缩,
    // 但平台侧样本不足仍真实存在)。用 down→trustedEnd 的总位移/总时长重建
    // 速度;甩动是从静止加速的运动,末端瞬时速度 ≈ 2×平均(匀加速模型,官方
    // LSQ 报的正是末端瞬时)——不补偿会让轻扫的 fling 距离缩水一半以上(实机
    // 体感"甩不动")。过 fling 双阈(设备距离阈 + 最小速度)才兑现。
    final downPosition = _pointerDownPositions[endingPointer];
    if (downPosition == null) return Velocity.zero;
    final fallbackOffset =
        _trustedEndPosition(preUpPosition, upEvent.position) - downPosition;
    final averagePixelsPerSecond = _fallbackPixelsPerSecondFor(
      fallbackOffset,
      endingPointer,
      upEvent.timeStamp,
    );
    if (averagePixelsPerSecond == Offset.zero) return Velocity.zero;
    final fallbackPixelsPerSecond = averagePixelsPerSecond * 2.0;
    final minVelocity = host._configOf(event).dragMinFlingVelocity;
    final minDistance = _minFlingDistance(event, kind);
    final isFling = switch (_acceptedAxis) {
      Axis.vertical =>
        fallbackPixelsPerSecond.dy.abs() > minVelocity &&
            fallbackOffset.dy.abs() > minDistance,
      Axis.horizontal =>
        fallbackPixelsPerSecond.dx.abs() > minVelocity &&
            fallbackOffset.dx.abs() > minDistance,
      null =>
        fallbackPixelsPerSecond.distanceSquared > minVelocity * minVelocity &&
            fallbackOffset.distanceSquared > minDistance * minDistance,
    };
    if (!isFling) return Velocity.zero;
    return _clampedVelocity(_acceptedAxis, event, fallbackPixelsPerSecond);
  }

  /// pre-accept 轻扫的 fling 轴向裁决：返回 (是否成立, 胜出轴)。
  ///
  /// 双轴向组同挂时按**速度向量的倾斜角**判轴（与起手判定
  /// [_acceptedDragAxisAndDirection] 同一把 [ElEventConfig.dragHorizontalAngle]
  /// 标尺），再过该轴的 fling 双阈；单轴组恒为该轴；自由拖拽按 2D 判定、
  /// 轴为 null。[matchOffset] 对应 estimate 路径的"速度与位移同向"校验，
  /// fallback 路径不启用（与既有两条路径的差异一致）。
  (bool, Axis?) _resolvePreAcceptFling(
    ElEvent event,
    Offset offset,
    Offset pixelsPerSecond, {
    required bool matchOffset,
  }) {
    final vertical = ElEventDispatcher._hasVerticalDragShape(event);
    final horizontal = ElEventDispatcher._hasHorizontalDragShape(event);
    if (vertical && horizontal) {
      if (pixelsPerSecond == Offset.zero) return (false, null);
      final axis = axisDirectionToAxis(
        _directionForDragOffset(
          pixelsPerSecond,
          host._configOf(event).dragHorizontalAngle,
        ),
      );
      final ok =
          _isPreAcceptFlingGesture(axis, event, offset, pixelsPerSecond) &&
          (!matchOffset ||
              _preAcceptVelocityMatchesOffset(axis, offset, pixelsPerSecond));
      return (ok, ok ? axis : null);
    }
    if (vertical || horizontal) {
      final axis = vertical ? Axis.vertical : Axis.horizontal;
      if (pixelsPerSecond == Offset.zero ||
          axisDirectionToAxis(
                _directionForDragOffset(
                  pixelsPerSecond,
                  host._configOf(event).dragHorizontalAngle,
                ),
              ) !=
              axis) {
        return (false, null);
      }
      final ok =
          _isPreAcceptFlingGesture(axis, event, offset, pixelsPerSecond) &&
          (!matchOffset ||
              _preAcceptVelocityMatchesOffset(axis, offset, pixelsPerSecond));
      return (ok, ok ? axis : null);
    }
    final ok =
        _isPreAcceptFlingGesture(null, event, offset, pixelsPerSecond) &&
        (!matchOffset ||
            _preAcceptVelocityMatchesOffset(null, offset, pixelsPerSecond));
    return (ok, null);
  }

  (Velocity, Axis?) _preAcceptFlingVelocity(
    ElEvent event,
    PointerUpEvent upEvent,
    Offset? preUpPosition,
  ) {
    final pointer = upEvent.pointer;
    final lastMoveTimeStamp = _pointerLastMoveTimeStamps[pointer];
    if (lastMoveTimeStamp == null ||
        upEvent.timeStamp - lastMoveTimeStamp > _kReleaseMoveGap) {
      return (Velocity.zero, null);
    }
    final estimate = _velocityTrackers[pointer]?.getVelocityEstimate();

    if (estimate != null) {
      final (isFling, axis) = _resolvePreAcceptFling(
        event,
        estimate.offset,
        estimate.pixelsPerSecond,
        matchOffset: true,
      );
      if (isFling) {
        return (_clampedVelocity(axis, event, estimate.pixelsPerSecond), axis);
      }
    }

    // fallback 位移基于甄别后的终点(塌缩采信 up 插值位置、合成跳变回退最后
    // move 位置,与 _endVelocity 的兜底同一契约);平均速度 ×2 端点补偿同上。
    final downPosition = _pointerDownPositions[pointer];
    if (downPosition == null) return (Velocity.zero, null);
    final fallbackOffset =
        _trustedEndPosition(preUpPosition, upEvent.position) - downPosition;
    final averagePixelsPerSecond = _fallbackPixelsPerSecondFor(
      fallbackOffset,
      pointer,
      upEvent.timeStamp,
    );
    if (averagePixelsPerSecond == Offset.zero) return (Velocity.zero, null);
    final fallbackPixelsPerSecond = averagePixelsPerSecond * 2.0;
    final (isFling, axis) = _resolvePreAcceptFling(
      event,
      fallbackOffset,
      fallbackPixelsPerSecond,
      matchOffset: false,
    );
    if (!isFling) return (Velocity.zero, null);
    return (_clampedVelocity(axis, event, fallbackPixelsPerSecond), axis);
  }

  /// velocity fallback 用的手势终点位置。
  ///
  /// 两个互斥场景共用 up 位置通道,必须区分:
  /// - **平台批量塌缩**(真机 Android 帧批量投递/jank):短促轻扫的中间样本可能
  ///   缺失,位移整体并进 up 位置(实测 preUp==down、up 携带全部 9-16px)
  ///   ——up 位置是真实轨迹终点,**必须采信**,否则轻扫 velocity 恒零死停;
  /// - **平台合成跳变**(memory:up 位置不喂 tracker 的原因):up 报出离最后
  ///   move 数百 px 的合成位置,采信会算出上万 px/s 的假 velocity。
  /// 判据:一帧内手指物理位移有界(60Hz 输入快甩 ≈ 48px),取 kTouchSlop*4=72px
  /// 为信任上界——塌缩增量(≤ ~50px)采信,合成跳变(数百 px)丢弃。
  Offset _trustedEndPosition(Offset? preUpPosition, Offset upPosition) {
    final pre = preUpPosition;
    if (pre == null) return upPosition;
    const maxTrustedUpDelta = kTouchSlop * 4;
    return (upPosition - pre).distance <= maxTrustedUpDelta ? upPosition : pre;
  }

  Offset _fallbackPixelsPerSecondFor(
    Offset offset,
    int pointer,
    Duration endTimeStamp,
  ) {
    final start = _pointerDownTimeStamps[pointer];
    if (start == null) return Offset.zero;
    final elapsedMicros = endTimeStamp.inMicroseconds - start.inMicroseconds;
    if (elapsedMicros <= 0) return Offset.zero;
    return offset * (Duration.microsecondsPerSecond / elapsedMicros);
  }

  /// 当前用于投影/多指聚合的轴：已接受 → 胜出轴；未接受 → 候选唯一时即该轴
  /// （与旧 dragAxis 配置行为一致），双轴候选或自由拖拽为 null（2D 口径）。
  Axis? _effectiveAxis(ElEvent event) {
    if (_dragStarted) return _acceptedAxis;
    final vertical = ElEventDispatcher._hasVerticalDragShape(event);
    final horizontal = ElEventDispatcher._hasHorizontalDragShape(event);
    if (vertical && !horizontal) return Axis.vertical;
    if (horizontal && !vertical) return Axis.horizontal;
    return null;
  }

  Offset _strategyOffset(
    ElEvent event, {
    int? pointer,
    Offset? delta,
    Duration? timeStamp,
    bool preserveCrossAxis = false,
  }) {
    if (_pointerPositions.isEmpty) return Offset.zero;
    final axis = _effectiveAxis(event);
    final offset = switch (host.multitouchDragStrategy) {
      MultitouchDragStrategy.latestPointer => _latestPointerOffset(),
      MultitouchDragStrategy.sumAllPointers => _sumAllPointerOffsets(),
      MultitouchDragStrategy.averageBoundaryPointers => _averageBoundaryOffset(
        preserveCrossAxis ? null : axis,
        pointer: pointer,
        delta: delta,
        timeStamp: timeStamp,
      ),
    };
    return preserveCrossAxis ? offset : _projectToAxis(axis, offset);
  }

  Offset _projectToAxis(Axis? axis, Offset offset) {
    return switch (axis) {
      Axis.vertical => Offset(0.0, offset.dy),
      Axis.horizontal => Offset(offset.dx, 0.0),
      null => offset,
    };
  }

  Offset _latestPointerOffset() {
    final pointer = _dragPointerId;
    if (pointer == null) return Offset.zero;
    return _pointerOffset(pointer);
  }

  Offset _sumAllPointerOffsets() {
    var result = Offset.zero;
    for (final pointer in _pointerPositions.keys) {
      result += _pointerOffset(pointer);
    }
    return result;
  }

  Offset _averageBoundaryOffset(
    Axis? axis, {
    int? pointer,
    Offset? delta,
    Duration? timeStamp,
  }) {
    if (_pointerPositions.isEmpty) return Offset.zero;
    if (!_dragStarted ||
        pointer == null ||
        delta == null ||
        timeStamp == null) {
      if (axis != null) {
        final primary = _averageBoundaryPrimaryOffset(axis);
        return axis == Axis.vertical
            ? Offset(0.0, primary)
            : Offset(primary, 0.0);
      }
      return _sumAllPointerOffsets() / _pointerPositions.length.toDouble();
    }

    if (axis == null) {
      return _dragOffset + _averageBoundaryPanFrameDelta(delta, timeStamp);
    }

    final primaryDelta = _averageBoundaryPrimaryFrameDelta(
      axis,
      pointer,
      delta,
      timeStamp,
    );
    final currentPrimary = axis == Axis.vertical
        ? _dragOffset.dy
        : _dragOffset.dx;
    final primary = currentPrimary + primaryDelta;
    return axis == Axis.vertical ? Offset(0.0, primary) : Offset(primary, 0.0);
  }

  void _syncAverageBoundaryFrame(Duration timeStamp) {
    final scheduler = SchedulerBinding.instance;
    final frameTimeStamp = scheduler.schedulerPhase == SchedulerPhase.idle
        ? Duration.zero
        : scheduler.currentSystemFrameTimeStamp;
    final bucket = frameTimeStamp == Duration.zero
        ? _averageBoundaryFallbackFrameBucket(timeStamp)
        : frameTimeStamp;
    if (_averageBoundaryFrameTimeStamp != bucket) {
      _averageBoundaryFrameDeltas.clear();
      _averageBoundaryLastPanFrameDelta = Offset.zero;
      _averageBoundaryFrameTimeStamp = bucket;
    }
  }

  Duration _averageBoundaryFallbackFrameBucket(Duration timeStamp) {
    const fallbackFrame = Duration(milliseconds: 16);
    final refreshRate = host._displayRefreshRate();
    if (refreshRate == null || !refreshRate.isFinite || refreshRate <= 0) {
      return fallbackFrame *
          (timeStamp.inMicroseconds ~/ fallbackFrame.inMicroseconds);
    }
    final frameMicros = math.max(
      1,
      (Duration.microsecondsPerSecond / refreshRate).round(),
    );
    return Duration(
      microseconds: frameMicros * (timeStamp.inMicroseconds ~/ frameMicros),
    );
  }

  void _recordAverageBoundaryFrameDelta(
    int pointer,
    Offset delta,
    Duration timeStamp,
  ) {
    if (host.multitouchDragStrategy !=
            MultitouchDragStrategy.averageBoundaryPointers ||
        !_dragStarted ||
        delta == Offset.zero) {
      return;
    }
    _syncAverageBoundaryFrame(timeStamp);
    _averageBoundaryFrameDeltas[pointer] =
        (_averageBoundaryFrameDeltas[pointer] ?? Offset.zero) + delta;
  }

  double _averageBoundaryPrimaryFrameDelta(
    Axis axis,
    int pointer,
    Offset delta,
    Duration timeStamp,
  ) {
    _syncAverageBoundaryFrame(timeStamp);
    final previous = _averageBoundaryFrameDeltas[pointer] ?? Offset.zero;
    final primaryDelta = axis == Axis.vertical ? delta.dy : delta.dx;
    if (primaryDelta == 0.0) return 0.0;
    if (_averageBoundaryFrameDeltas.isEmpty) return primaryDelta;

    final positive = primaryDelta > 0.0;
    final boundary = _averageBoundaryPrimaryFrameBoundary(axis, positive);
    final current = axis == Axis.vertical ? previous.dy : previous.dx;
    final next = current + primaryDelta;
    if (boundary == null) return primaryDelta;
    if (positive) return math.max(0.0, next - boundary);
    return math.min(0.0, next - boundary);
  }

  Offset _averageBoundaryPanFrameDelta(Offset delta, Duration timeStamp) {
    _syncAverageBoundaryFrame(timeStamp);
    var sum = delta;
    for (final frameDelta in _averageBoundaryFrameDeltas.values) {
      sum += frameDelta;
    }
    final average = sum / _pointerPositions.length.toDouble();
    final result = average - _averageBoundaryLastPanFrameDelta;
    _averageBoundaryLastPanFrameDelta = average;
    return result;
  }

  double? _averageBoundaryPrimaryFrameBoundary(Axis axis, bool positive) {
    double? boundary;
    for (final entry in _averageBoundaryFrameDeltas.entries) {
      final primary = axis == Axis.vertical ? entry.value.dy : entry.value.dx;
      if (positive) {
        final candidate = math.max(primary, 0.0);
        boundary = boundary == null ? candidate : math.max(boundary, candidate);
      } else {
        final candidate = math.min(primary, 0.0);
        boundary = boundary == null ? candidate : math.min(boundary, candidate);
      }
    }
    return boundary;
  }

  double _averageBoundaryPrimaryOffset(Axis axis) {
    var maxPositive = 0.0;
    var minNegative = 0.0;
    for (final pointer in _pointerPositions.keys) {
      final offset = _pointerOffset(pointer);
      final primary = axis == Axis.vertical ? offset.dy : offset.dx;
      if (primary > maxPositive) maxPositive = primary;
      if (primary < minNegative) minNegative = primary;
    }
    return maxPositive + minNegative;
  }

  Offset _pointerOffset(int pointer) {
    final position = _pointerPositions[pointer];
    final down = _pointerDownPositions[pointer];
    if (position == null || down == null) return Offset.zero;
    return position - down;
  }

  /// 按倾斜角把位移/速度向量分类到轴向方向。
  ///
  /// 与水平轴夹角(含负向 ±π 侧)在 ±[horizontalAngle] 弧度内判水平,
  /// 否则判垂直；默认 45° 时两个方向对半，边界稳定归横向。
  AxisDirection _directionForDragOffset(Offset offset, double horizontalAngle) {
    final direction = offset.direction;
    if ((-horizontalAngle <= direction && direction <= horizontalAngle) ||
        direction <= -math.pi + horizontalAngle ||
        direction >= math.pi - horizontalAngle) {
      return offset.dx < 0 ? AxisDirection.left : AxisDirection.right;
    }
    return offset.dy < 0 ? AxisDirection.up : AxisDirection.down;
  }

  AxisDirection _directionForPreAcceptFling(
    Axis? axis,
    Offset offset,
    Velocity velocity,
    double horizontalAngle,
  ) {
    final dragOffset = _projectToAxis(axis, offset);
    if (dragOffset != Offset.zero) {
      return _directionForDragOffset(dragOffset, horizontalAngle);
    }
    final velocityOffset = _projectToAxis(axis, velocity.pixelsPerSecond);
    if (velocityOffset != Offset.zero) {
      return _directionForDragOffset(velocityOffset, horizontalAngle);
    }
    return AxisDirection.down;
  }

  /// 起手判定：按宿主声明的回调组竞争，返回 (胜出轴, 起手方向)。
  ///
  /// - 只声明单一轴向组：累计方向先进入该轴的捕获锥，该轴分量再过 hit
  ///   slop 才接受；方向不匹配时保持未决定，允许后续累计轨迹翻转意图；
  /// - 双轴向组同挂：起手方向按**倾斜角**判轴（[ElEventConfig.dragHorizontalAngle]
  ///   定义水平捕获锥半角），2D 位移越过胜出轴的启动阈即激活并锁轴——
  ///   对齐旧 ElDrag.horizontalAngle 语义；胜出水平轴的阈更大（pan slop
  ///   口径，见 [_dragStartThreshold]），未过阈前判轴方向仍是活的，纵向
  ///   意图有机会把累计位移转出水平锥翻盘；
  /// - 自由拖拽（onDrag*）：2D 距离过 pan slop，轴为 null。
  (Axis?, AxisDirection)? _acceptedDragAxisAndDirection(
    ElEvent event,
    Offset offset,
    PointerDeviceKind kind,
  ) {
    final vertical = ElEventDispatcher._hasVerticalDragShape(event);
    final horizontal = ElEventDispatcher._hasHorizontalDragShape(event);
    if (vertical && horizontal) {
      final direction = _directionForDragOffset(
        offset,
        host._configOf(event).dragHorizontalAngle,
      );
      final axis = axisDirectionToAxis(direction);
      if (offset.distance <=
          _dragStartThreshold(event, kind, axis: axis, biaxial: true)) {
        return null;
      }
      return (axis, direction);
    }
    if (vertical) {
      final direction = _directionForDragOffset(
        offset,
        host._configOf(event).dragHorizontalAngle,
      );
      if (axisDirectionToAxis(direction) != Axis.vertical) return null;
      if (offset.dy.abs() <=
          _dragStartThreshold(event, kind, axis: Axis.vertical)) {
        return null;
      }
      return (Axis.vertical, direction);
    }
    if (horizontal) {
      final direction = _directionForDragOffset(
        offset,
        host._configOf(event).dragHorizontalAngle,
      );
      if (axisDirectionToAxis(direction) != Axis.horizontal) return null;
      if (offset.dx.abs() <=
          _dragStartThreshold(event, kind, axis: Axis.horizontal)) {
        return null;
      }
      return (Axis.horizontal, direction);
    }
    final threshold = _dragStartThreshold(event, kind, axis: null);
    if (offset.distance <= threshold) return null;
    return (
      null,
      _directionForDragOffset(
        offset,
        host._configOf(event).dragHorizontalAngle,
      ),
    );
  }

  /// [biaxial]：双轴组竞争路径。竞争中胜出的**水平轴**取 pan slop（hit
  /// slop × 2）——水平比垂直更易被起手噪声推进捕获锥，加长确认距离给纵向
  /// 意图留翻盘窗口（误触横滚防线之二，之一是窄水平锥）；单轴水平组无竞争
  /// 无误触，仍取 hit slop。显式 [ElEventConfig.dragStartDistance] = 用户
  /// 接管，按值生效不放大。
  double _dragStartThreshold(
    ElEvent event,
    PointerDeviceKind kind, {
    Axis? axis,
    bool biaxial = false,
  }) {
    final configured = host._configOf(event).dragStartDistance;
    if (configured != null) return configured;
    if (axis == null) return computePanSlop(kind, host.gestureSettings);
    if (biaxial && axis == Axis.horizontal) {
      return computePanSlop(kind, host.gestureSettings);
    }
    return computeHitSlop(kind, host.gestureSettings);
  }

  /// fling 距离阈:与 [_dragStartThreshold] 同款的设备适配。官方
  /// `DragGestureRecognizer._isFlingGesture` 的 minDistance 是
  /// `minFlingDistance ?? computeHitSlop(kind, gestureSettings)` —— 跟随设备
  /// slop(Android 系统值 ≈ 8-9 逻辑px),不是 kTouchSlop 常量。若锚死在 18:
  /// 真机 8~18px 的轻扫会 dragStart(过设备阈)但 estimate.offset < 18 被判
  /// "非 fling" → velocity 归零 → 惯性中的轻扫死停(实机一次必现;测试环境
  /// gestureSettings=null 时两个阈相等,死亡区间不存在,故此前全绿)。
  double _minFlingDistance(ElEvent event, PointerDeviceKind kind) {
    final configured = host._configOf(event).dragMinFlingDistance;
    if (configured != null) return configured;
    return computeHitSlop(kind, host.gestureSettings);
  }

  bool _isFlingGesture(
    Axis? axis,
    ElEvent event,
    VelocityEstimate estimate,
    PointerDeviceKind kind,
  ) {
    final minVelocity = host._configOf(event).dragMinFlingVelocity;
    final minDistance = _minFlingDistance(event, kind);
    return switch (axis) {
      Axis.vertical =>
        estimate.pixelsPerSecond.dy.abs() > minVelocity &&
            estimate.offset.dy.abs() > minDistance,
      Axis.horizontal =>
        estimate.pixelsPerSecond.dx.abs() > minVelocity &&
            estimate.offset.dx.abs() > minDistance,
      null =>
        estimate.pixelsPerSecond.distanceSquared > minVelocity * minVelocity &&
            estimate.offset.distanceSquared > minDistance * minDistance,
    };
  }

  bool _isPreAcceptFlingGesture(
    Axis? axis,
    ElEvent event,
    Offset offset,
    Offset pixelsPerSecond,
  ) {
    // 微甩救援距离阈:必须容忍真机重采样的塌缩。真机 Android 触摸事件走
    // resampler,24ms 内的短手势会被 sample 到中间时刻——原始 16px 常被塌缩到
    // 9-10px。若沿用 `min(dragMinFlingDistance=18, tapCancelDistance=10)=10` 作
    // 阈值,真机上明确的反向轻扫必然被误否(实测 fbOff=9.3 → 拒绝)。
    // 但也不能完全去掉——纯 tap 的手指微移(2-5px)在 velocity tracker 上速度可
    // 达 200-400 px/s(时间窗短),会被误判为 flick 且补发 dragStart/dragEnd
    // (drag_replacement_tap_test.dart 覆盖此情形)。折中:取 tapCancelDistance
    // 的一半(默认 5),既大于 tap 微移(<4px)又小于塌缩后 flick(>=9px)。
    final minVelocity = host._configOf(event).dragMinFlingVelocity;
    final minDistance = host._configOf(event).tapCancelDistance / 2;
    return switch (axis) {
      Axis.vertical =>
        pixelsPerSecond.dy.abs() > minVelocity && offset.dy.abs() > minDistance,
      Axis.horizontal =>
        pixelsPerSecond.dx.abs() > minVelocity && offset.dx.abs() > minDistance,
      null =>
        pixelsPerSecond.distanceSquared > minVelocity * minVelocity &&
            offset.distanceSquared > minDistance * minDistance,
    };
  }

  bool _preAcceptVelocityMatchesOffset(
    Axis? axis,
    Offset offset,
    Offset pixelsPerSecond,
  ) {
    return switch (axis) {
      Axis.vertical =>
        offset.dy == 0.0 ||
            pixelsPerSecond.dy == 0.0 ||
            offset.dy.sign == pixelsPerSecond.dy.sign,
      Axis.horizontal =>
        offset.dx == 0.0 ||
            pixelsPerSecond.dx == 0.0 ||
            offset.dx.sign == pixelsPerSecond.dx.sign,
      null =>
        offset == Offset.zero ||
            pixelsPerSecond == Offset.zero ||
            offset.dx * pixelsPerSecond.dx + offset.dy * pixelsPerSecond.dy >
                0.0,
    };
  }

  Velocity _clampedVelocity(Axis? axis, ElEvent event, Offset raw) {
    final axisVelocity = switch (axis) {
      Axis.vertical => Offset(0.0, raw.dy),
      Axis.horizontal => Offset(raw.dx, 0.0),
      null => raw,
    };

    final maxVelocity = host._configOf(event).dragMaxFlingVelocity;
    if (axis != null) {
      final primary = axis == Axis.vertical ? axisVelocity.dy : axisVelocity.dx;
      return Velocity(
        pixelsPerSecond: axis == Axis.vertical
            ? Offset(0.0, primary.clamp(-maxVelocity, maxVelocity).toDouble())
            : Offset(primary.clamp(-maxVelocity, maxVelocity).toDouble(), 0.0),
      );
    }

    final magnitude = axisVelocity.distance;
    if (magnitude > maxVelocity) {
      final scale = maxVelocity / magnitude;
      return Velocity(pixelsPerSecond: axisVelocity * scale);
    }
    return Velocity(pixelsPerSecond: axisVelocity);
  }
}
