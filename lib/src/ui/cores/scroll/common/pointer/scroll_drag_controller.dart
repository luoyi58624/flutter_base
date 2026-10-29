// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart' show VoidCallback, precisionErrorTolerance, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../view/event/event.dart';
import '../../../view/event/dispatcher.dart';
import 'scroll_input_transaction.dart';
import 'scroll_input_step.dart';
import '../../scroll_state.dart' show ElScrollInputSource;
import '../nested/scroll_delta_interceptor.dart';
import '../physics/browser_scroll_physics.dart' show ElFlingBoostSpec;
import '../viewport/scroll_viewport.dart';
import '../viewport/scroll_engine_position.dart';
import '../../../view/render/scroll_cursor_freeze.dart';
import 'scroll_pointer_chain.dart';
import 'scroll_touch_gate.dart';

typedef ScrollAxisGetter = Axis Function();
typedef ScrollAxisDirectionGetter = AxisDirection Function();
typedef ScrollPhysicsGetter = ScrollPhysics Function();
typedef ScrollCanDragGetter = bool Function();
typedef ScrollShouldAcceptOffsetGetter = bool Function();
typedef ScrollVelocityTrackerBuilderGetter = GestureVelocityTrackerBuilder Function();
typedef ScrollDeltaInterceptorGetter = ElScrollDeltaInterceptor? Function();

/// Shared drag and trackpad-pan controller for El scroll viewports.
///
/// The controller owns the Flutter [Drag]/hold lifecycle and nested-scroll delta
/// consumption. Render objects provide current axis, physics, and position by
/// getter so controller state survives position/configuration replacement.
final class ScrollViewDragController {
  ScrollViewDragController({
    required ScrollViewport owner,
    required ScrollPosition Function() position,
    required ScrollAxisGetter axis,
    required ScrollAxisDirectionGetter axisDirection,
    required ScrollPhysicsGetter physics,
    required ScrollVelocityTrackerBuilderGetter velocityTrackerBuilder,
    required ScrollCanDragGetter canDrag,
    required ScrollShouldAcceptOffsetGetter shouldAcceptUserOffset,
    required VoidCallback resetSmoothPointerScroll,
    ScrollDeltaInterceptorGetter? deltaInterceptor,
  }) : _owner = owner,
       _position = position,
       _axis = axis,
       _axisDirection = axisDirection,
       _physics = physics,
       _velocityTrackerBuilder = velocityTrackerBuilder,
       _canDrag = canDrag,
       _shouldAcceptUserOffset = shouldAcceptUserOffset,
       _resetSmoothPointerScroll = resetSmoothPointerScroll,
       _deltaInterceptor = deltaInterceptor;

  @visibleForTesting
  static DragStartDetails debugDragStartDetailsFor(ElEventDetails event) => _dragStartDetailsFor(event);

  @visibleForTesting
  static DragUpdateDetails debugDragUpdateDetailsFor(ElEventDetails event, Axis axis, double consumed) {
    return _dragUpdateDetailsFor(event, axis, consumed);
  }

  final ScrollViewport _owner;
  final ScrollPosition Function() _position;
  final ScrollAxisGetter _axis;
  final ScrollAxisDirectionGetter _axisDirection;
  final ScrollPhysicsGetter _physics;
  final ScrollVelocityTrackerBuilderGetter _velocityTrackerBuilder;
  final ScrollCanDragGetter _canDrag;
  final ScrollShouldAcceptOffsetGetter _shouldAcceptUserOffset;
  final VoidCallback _resetSmoothPointerScroll;
  final ScrollDeltaInterceptorGetter? _deltaInterceptor;
  ClampingScrollPhysics? _handoffPhysics;
  bool get _handlesAncestorInput {
    final input = _deltaInterceptor?.call();
    return input is ScrollMotionInput && (input as ScrollMotionInput).handlesAncestorInput;
  }

  static bool _liveHandle(Object? handle) =>
      handle != null && (handle is! ScrollInputActivityHandle || handle.isCurrent);

  void _discardRetiredDelta(ElEventDetails event, Axis axis) {
    event.consumePrimaryDelta(axis, event.remainingPrimaryDelta(axis));
    if (event.remainingDelta == Offset.zero) event.stopPropagation();
  }

  Drag _createScrollDrag(DragStartDetails details, VoidCallback onCancelled) {
    final position = _position();
    final authority = ScrollInputTransaction.current?.writerFor(position);
    return position is ScrollEnginePosition && authority is ScrollMotionOwner
        ? position.dragOwned(authority, details, onCancelled)
        : position.drag(details, onCancelled);
  }

  ScrollHoldController _createScrollHold(VoidCallback onCancelled) {
    final position = _position();
    final authority = ScrollInputTransaction.current?.writerFor(position);
    return position is ScrollEnginePosition && authority is ScrollMotionOwner
        ? position.holdOwned(authority, onCancelled)
        : position.hold(onCancelled);
  }

  /// 拦截器消费包装：把 [primaryDelta] 先喂拦截器，扣掉消费量后返回剩余。
  /// null / 无拦截时零开销直穿。
  double _applyDeltaInterceptor(double primaryDelta, ElScrollDeltaSource source) {
    final getter = _deltaInterceptor;
    if (getter == null) return primaryDelta;
    final interceptor = getter();
    if (interceptor == null) return primaryDelta;
    if (primaryDelta.abs() <= precisionErrorTolerance) return primaryDelta;
    final consumed = interceptor.interceptScrollDelta(primaryDelta, source);
    // 契约：consumed 与 delta 同号且 |consumed| ≤ |delta|；越界的实现视为
    // "不消费"，避免拦截器反转/放大方向破坏物理。
    if (consumed == 0.0) return primaryDelta;
    if (consumed.sign != primaryDelta.sign) return primaryDelta;
    if (consumed.abs() > primaryDelta.abs()) return 0.0;
    return primaryDelta - consumed;
  }

  ScrollHoldController? _hold;
  Drag? _drag;
  DragStartDetails? _pendingDragStart;
  _ScrollGestureSnapshot? _dragSnapshot;
  bool _dragConsumedInGesture = false;
  bool _dragDeferredToAncestor = false;
  bool _ownsPointerLock = false;

  /// 内容区直接 pointer 拖拽是否正在驱动滚动。
  ///
  /// 不含 trackpad pan-zoom；视口用它避免在 mouse drag 每次 move 时
  /// 反复冻结/释放光标并强制全树 MouseTracker 重新命中。
  bool get isDirectPointerDragActive => _liveHandle(_drag);

  /// 指针按下后是否仍持有当前 position、尚未进入 drag activity。
  bool get isHolding => _liveHandle(_hold);

  /// 本次触摸拖拽的位移被**拦截器**吃走过（下拉刷新、nested driver 等）。
  ///
  /// 位移没进 position 时不会有 DragScrollActivity，`ignorePointer` 那条链
  /// 整条失明：安卓下拉刷新拉出期内容纹丝不动、手指又始终留在同一张卡的边界
  /// 内，tap 的边界取消口径也兜不住 → 抬手激活卡片（用户报障）。所以拦截器
  /// 吃到位移即等同"手势归滚动侧"：eagerGesture 掐掉后代手势 + 内容退出命中
  /// 路径（[gestureClaimedByInterceptor]）。手势结束一并清零。
  bool _interceptorClaimedGesture = false;

  /// 本次拖拽是否已被拦截器接管——render 的命中屏蔽据此把窗口扩到拉出期。
  bool get gestureClaimedByInterceptor => _interceptorClaimedGesture;

  /// post 段只传递尚未接受的输入，像素阻尼差额不参与嵌套预算。
  double _dispatchRemainingInput(double inputRemaining) {
    if (inputRemaining.abs() <= precisionErrorTolerance) return inputRemaining;
    var remaining = inputRemaining;

    // Mixin driver 等可选 post-scroll 消费者先接收 position 吃不下的余量。
    final interceptor = _deltaInterceptor?.call();
    if (interceptor != null && interceptor is ElScrollPostDeltaInterceptor) {
      final consumed = (interceptor as ElScrollPostDeltaInterceptor).interceptPostScroll(
        remaining,
        ElScrollDeltaSource.touchDrag,
      );
      if (consumed != 0.0 && consumed.sign == remaining.sign && consumed.abs() <= remaining.abs()) {
        remaining -= consumed;
      }
    }

    return remaining;
  }

  /// 本手势是否走过 dragProxy 分账管线（dragStart/dragUpdate 快照；dragEnd
  /// 不携带管线快照，微甩救援分支据此判定"余量归协作方"而不越权起飞。
  bool _dragPipelineGesture = false;

  // ---- FlingBooster(Chrome 连甩加速)状态 ----
  //
  // 官方 `ui/events/blink/fling_booster.cc` 语义:上一次起飞的 fling 起始
  // 速度记在 [_lastFlingStartVelocity] / [_lastFlingStartTimestamp];本手势
  // 按下时若该 fling 仍在跑且够快,置 [_boostArmedThisGesture] 并把起始速度
  // 存进 [_boostCarryVelocity];松手成甩且同向达门槛时等差叠加。
  //
  // 绕开官方 [ScrollDragController] 的 carried 路径:后者叠加门是"新手势 >
  // 0.5×携带",叠加值又被 [ScrollPhysics.maxFlingVelocity] 约束的单手势速度
  // 主导——累计过 2×上限即整体丢弃、速度塌回单手势水平。本控制器自行叠加,
  // 结果经官方 `drag.end → goBallistic` **不再 clamp**(scroll_activity.dart
  // 的 end() 直传 velocity),累积得以突破单手势上限,复现 Chrome 连甩。
  double _lastFlingStartVelocity = 0.0;
  Duration? _lastFlingStartTimestamp;
  bool _boostArmedThisGesture = false;
  double _boostCarryVelocity = 0.0;
  ElFlingBoostSpec? _boostSpec;

  /// 最近一次"达标快速移动"的时刻(armed 起点算首次达标)。官方 cutoff 语义:
  /// 松手/每次 move 距它超过 boostTimeout 即断 boost。
  Duration? _boostLastFastTimestamp;
  Duration? _boostLastMoveTimestamp;

  /// 沿 physics.parent 链找到首个 [ElFlingBoostSpec]，跳过刷新等纯物理包装。
  ElFlingBoostSpec? _boostSpecOf(ScrollPhysics physics) {
    for (ScrollPhysics? node = physics; node != null; node = node.parent) {
      if (node case final ElFlingBoostSpec spec) return spec;
    }
    return null;
  }

  /// 按下即将 hold 停住现存 fling 前,判定是否可 boost:physics 支持 booster、
  /// 存在上一 fling 起始速度、该 fling 仍在跑且当前速度 ≥ 门槛。达标则记住
  /// 起始速度供松手叠加(官方叠加的是**起始**速度而非衰减后值)。
  ///
  /// 近似说明:"fling 仍在跑"用 isScrolling + 起始速度按样条推算当前速度
  /// 判定,不逐活动核对(position.activity 非公开面);fling 被程序化动画
  /// 替换的极端情形可能误判 armed,量级罕见可接受。
  void _tryArmFlingBoost(_ScrollGestureSnapshot snapshot, PointerEvent? original) {
    _boostArmedThisGesture = false;
    _boostCarryVelocity = 0.0;
    _boostLastFastTimestamp = null;
    _boostLastMoveTimestamp = null;
    final spec = _boostSpec = _boostSpecOf(snapshot.physics);
    if (spec == null) return;
    final prevStart = _lastFlingStartVelocity;
    final startTs = _lastFlingStartTimestamp;
    if (prevStart.abs() < precisionErrorTolerance || startTs == null || original == null) return;
    // 现存 fling 必须仍在跑(自然停 / 被别的活动接管则链断)。
    if (!_position().isScrollingNotifier.value) return;
    // 跨手势 elapsed 用事件时间戳推算样条衰减;时间戳域重置(测试合成手势
    // 各自从 0 计时、设备时钟回绕)出现负值时按 0 处理——活跃性主判据是上面
    // 的 isScrolling,这里只影响衰减估计,取起始速度偏保守可接受。
    var elapsed = (original.timeStamp - startTs).inMicroseconds / Duration.microsecondsPerSecond;
    if (elapsed < 0.0) elapsed = 0.0;
    final currentFling = spec.flingVelocityAt(startVelocity: prevStart, elapsedSeconds: elapsed);
    if (currentFling.abs() < spec.boostMinVelocity) return;
    _boostArmedThisGesture = true;
    _boostCarryVelocity = prevStart;
    // 官方 cutoff 起点:按下(scroll begin)即开一个 boostTimeout 窗口,
    // 后续每次达标快速同向移动续期。
    _boostLastFastTimestamp = original.timeStamp;
    _boostLastMoveTimestamp = original.timeStamp;
  }

  /// 拖拽移动帧维护 boost 窗口(官方 GSU 观察语义):
  /// - 反向移动 → 立即断 boost(官方 dot ≤ 0 Reset);
  /// - 帧速 ≥ [ElFlingBoostSpec.boostMinScrollVelocity] → cutoff 续期;
  /// - 距上次达标超过 boostTimeout(手指停着/慢蹭)→ 断 boost。
  void _trackFlingBoostMove(ElEventDetails event, _ScrollGestureSnapshot snapshot) {
    if (!_boostArmedThisGesture) return;
    final spec = _boostSpec;
    final original = event.originalEvent;
    if (spec == null || original is! PointerEvent) return;
    final now = event.sampleTimeStamp ?? original.timeStamp;
    final prev = _boostLastMoveTimestamp;
    _boostLastMoveTimestamp = now;
    final delta = event.remainingPrimaryDelta(snapshot.axis);
    if (delta.abs() > precisionErrorTolerance && delta.sign != _boostCarryVelocity.sign) {
      _boostArmedThisGesture = false;
      return;
    }
    final lastFast = _boostLastFastTimestamp;
    if (prev == null || lastFast == null) return;
    final dtMicros = (now - prev).inMicroseconds;
    if (dtMicros <= 0) return;
    final speed = delta.abs() * Duration.microsecondsPerSecond / dtMicros;
    if (speed >= spec.boostMinScrollVelocity) {
      _boostLastFastTimestamp = now;
    } else if (now - lastFast > spec.boostTimeout) {
      _boostArmedThisGesture = false;
    }
  }

  /// 松手速度经 booster 叠加:armed 未被移动追踪断掉、松手仍在窗口内、
  /// 同向且新手势达门槛时返回叠加后的起飞速度,否则原样返回。
  double _applyFlingBoost(double primaryVelocity, PointerEvent? original) {
    if (!_boostArmedThisGesture) return primaryVelocity;
    final spec = _boostSpec;
    if (spec == null) return primaryVelocity;
    final lastFast = _boostLastFastTimestamp;
    if (original != null && lastFast != null && original.timeStamp - lastFast > spec.boostTimeout) {
      return primaryVelocity;
    }
    if (primaryVelocity.abs() < spec.boostMinVelocity) return primaryVelocity;
    if (_boostCarryVelocity.sign != primaryVelocity.sign) return primaryVelocity;
    return spec.combineBoostedVelocity(primaryVelocity, _boostCarryVelocity);
  }

  /// 起飞后记录本 fling 起始速度 + 时刻,供下一手势 boost;非 fling(零速/
  /// 未起飞)清空累积链。
  void _recordFlingLaunch(double flingStartVelocity, PointerEvent? original) {
    if (flingStartVelocity.abs() > precisionErrorTolerance && original != null) {
      _lastFlingStartVelocity = flingStartVelocity;
      _lastFlingStartTimestamp = original.timeStamp;
      _boostArmedThisGesture = false;
      _boostCarryVelocity = 0.0;
      _boostLastFastTimestamp = null;
      _boostLastMoveTimestamp = null;
    } else {
      _resetFlingBoostChain();
    }
  }

  void _resetFlingBoostChain() {
    _lastFlingStartVelocity = 0.0;
    _lastFlingStartTimestamp = null;
    _boostArmedThisGesture = false;
    _boostCarryVelocity = 0.0;
    _boostLastFastTimestamp = null;
    _boostLastMoveTimestamp = null;
  }

  /// 本手势集中仍按着的 raw pointer（down 加入、up/cancel 移除）。hold 的释放
  /// 以**最后一根手指抬起**为准（对齐 Flutter recognizer 的 gesture 级 onEnd/
  /// onCancel 语义），而不是任意一根手指 up 就 goBallistic(0) 停住。
  final Set<int> _heldPointers = <int>{};
  ScrollHoldController? _trackpadHold;
  Drag? _trackpadDrag;
  VelocityTracker? _trackpadVelocityTracker;
  _ScrollGestureSnapshot? _trackpadSnapshot;
  int? _trackpadPointer;
  Offset _trackpadLastPan = Offset.zero;
  Offset _trackpadInputPosition = Offset.zero;
  int? _trackpadSessionId;
  Offset _trackpadLastGlobalPosition = Offset.zero;
  Offset _trackpadLastLocalPosition = Offset.zero;
  bool _trackpadConsumedInGesture = false;
  bool _trackpadClaimedPointerChain = false;

  /// pointer down 建立 hold：立刻停住进行中的 ballistic（对齐 Flutter Scrollable
  /// 的 onDown → position.hold 语义）。若拖拽在此手势内起飞，hold 会被 drag
  /// activity 替换并自动清空；若手指抬起前 dragStart 未触发（纯 tap / 越阈不够），
  /// [handlePointerUpOrCancel] 负责主动释放，避免永久冻结滚动。
  ///
  /// **多指防线**：raw down 对每根手指都会到达这里，但官方 recognizer 的
  /// onDown 只对手势集第一根手指触发。拖拽进行中（[_drag] 非 null）后续手指
  /// down 绝不能再 hold——`position.hold()` 走 beginActivity 会**杀掉活跃的
  /// DragScrollActivity**（实机"第二指触摸导致第一指滚动丢失"的根因）。
  void handlePointerDown(ElEventDetails event) {
    final snapshot = _dragSnapshot ?? _captureSnapshot();
    if (!snapshot.canDrag || !snapshot.shouldAcceptUserOffset) return;
    final original = event.originalEvent;
    if (original is PointerEvent) _heldPointers.add(original.pointer);
    // 触摸类 down 的两道处理，都必须在 hold() **之前**（hold 会 goBallistic(0)
    // 把 isScrolling 转 false，之后判不出这一下落在滚动中的容器上）：
    //
    // 1. 落在**正在滚动**（fling / 程序驱动 / 他指拖拽）的容器上 → 登记到
    //    [ScrollCatchPointers]。程序动画期后代命中不屏蔽，这一下会一路到达
    //    选区根，登记表让选区认出"这是接住滚动、不是选择手势"（不 arm 长按、
    //    不计连击），否则按住 400ms 就在刚接住的内容上凭空选中。
    // 2. 落在**他指拖拽进行中**或**触摸起飞的 fling**（[touchFlingScrolling]，
    //    2026-08-02 起整段屏蔽、不分快慢）的容器上 → 整条 pointer 链截断
    //    祖先侧消费者：后代已被命中屏蔽挡掉、接住的语义是"停住滚动"，但
    //    选区根挂在视口之外、participant 按几何解析绕过那道闸，还要把这
    //    一下排除出连击计数（AOSP：被 parent 截获的 down 不作双击首击）。
    //
    // 判据 = 本视口是否认领该 kind 的内容区拖拽（两档交互模型）：默认集合
    // 即触摸类；dragDevices 注入 mouse 后 mouse 与触摸同档同保护——否则接住
    // fling 的 mouse down 按住 400ms 就凭空选中（Windows 实测报障）。未认领
    // 的 kind（默认 mouse / trackpad）一概不吞，保留桌面"滚动动画中点击"语义。
    if (original is PointerDownEvent && _owner.effectiveContentDragDevices.contains(original.kind)) {
      final position = _position();
      final dragging = fingerDragScrolling(position);
      if (position.isScrollingNotifier.value) ScrollCatchPointers.add(original.pointer, duringDrag: dragging);
      final blocksAncestorCatch =
          dragging || (touchFlingScrolling(position) && !_isBouncingOutOfRange(snapshot.physics, position));
      if (!_dragPipelineGesture && blocksAncestorCatch) {
        event.stopPropagation();
      }
    }
    if (_liveHandle(_drag) || _liveHandle(_trackpadDrag)) return;
    if (!_liveHandle(_hold)) _hold = null;
    // FlingBooster armed 判定必须在 hold() **之前**:hold 会 goBallistic(0)/
    // beginActivity 停住现存 fling,之后 isScrolling 转 false 就判不出"落在
    // 活跃 fling 上"。这里只读现存 fling 状态,不改变按下即停的既有语义
    // (Chrome 的延迟取消由"松手时用记住的起始速度叠加"等价达成:内容仍
    // 在按下瞬间停住,但连甩动量通过起始速度累积得以保留)。
    _tryArmFlingBoost(snapshot, original is PointerEvent ? original : null);
    _hold ??= _position().hold(_disposeHold);
  }

  /// pointer up / cancel 的 hold 释放。dragStart 已触发时 hold 已由 drag activity
  /// 接管（活跃或已被替换清空），此处 no-op；未触发拖拽（纯 tap）时释放 hold
  /// 走 goBallistic(0)，位置在界内即回到 idle。
  ///
  /// 多指下 hold 的释放以**最后一根手指抬起**为准：任一手指 up 就释放会让
  /// 仍按着的手指失去"按住即停"语义。
  void handlePointerUpOrCancel(ElEventDetails event) {
    final original = event.originalEvent;
    if (original is PointerEvent) {
      _heldPointers.remove(original.pointer);
      ScrollCatchPointers.remove(original.pointer);
    }
    if (_heldPointers.isNotEmpty) return;
    final hold = _hold;
    if (hold == null) return;
    _hold = null;
    hold.cancel();
  }

  int? _inputSessionId;
  int? _beginningInputSessionId;
  bool _directInputRetired = false;
  bool _panInputRetired = false;
  Axis? _retiredDragAxis;
  Axis? _retiredPanAxis;

  void _retireInputSession(int? sessionId) {
    if (sessionId == null) return;
    if (sessionId == (_beginningInputSessionId ?? _inputSessionId)) {
      _directInputRetired = true;
      _retiredDragAxis = _dragSnapshot?.axis ?? _axis();
      _inputSessionId = null;
      _releasePointerLock();
    }
    if (sessionId == _trackpadSessionId) {
      _panInputRetired = true;
      _retiredPanAxis = _trackpadSnapshot?.axis ?? _axis();
      _finishTrackpadState(releasePointerChain: true);
    }
  }

  ScrollInputTransaction? _beginInputSample(ElEventDetails event, {bool startsSession = false}) {
    final interceptor = _deltaInterceptor?.call();
    if (interceptor == null) return null;
    final sessionId = startsSession || _inputSessionId == null
        ? ScrollInputTransaction.newSessionId()
        : _inputSessionId;
    final original = event.originalEvent;
    final rawEvent = original is PointerEvent ? original : null;
    _beginningInputSessionId = sessionId;
    try {
      final transaction = ScrollInputTransaction.begin(
        source: ScrollInputTransaction.dragSource(rawEvent),
        rawEvent: rawEvent,
        timeStamp: event.sampleTimeStamp,
        sessionId: sessionId,
        onInputCancelled: _retireInputSession,
        participants: interceptor is ScrollInputTransactionSource ? interceptor as ScrollInputTransactionSource : null,
      );
      if (!_directInputRetired) _inputSessionId = sessionId;
      return transaction;
    } finally {
      _beginningInputSessionId = null;
    }
  }

  void handleDragStart(ElEventDetails event) {
    _directInputRetired = false;
    _retiredDragAxis = null;
    if (!_liveHandle(_drag)) _drag = null;
    final transaction = _beginInputSample(event, startsSession: true);
    try {
      _handleDragStart(event);
    } finally {
      transaction?.close();
    }
  }

  void _handleDragStart(ElEventDetails event) {
    if (_directInputRetired) return;
    _dragConsumedInGesture = false;
    _interceptorClaimedGesture = false;
    _dragDeferredToAncestor = false;
    _dragPipelineGesture = event.dragPipelineActive;
    final snapshot = _captureSnapshot();
    if (!snapshot.canDrag || !snapshot.shouldAcceptUserOffset) return;
    _resetSmoothPointerScroll();
    _dragSnapshot = snapshot;
    // start details 必须在 seed=0 早退前落袋：快速轻甩可能整个手势没有任何
    // 非零 dragUpdate（位移全部落在被丢弃的起手帧），dragEnd 需要它兜底建
    // Drag 兑现 velocity（见 handleDragEnd 的微甩救援分支）。
    _pendingDragStart = _dragStartDetailsFor(event);
    // dragStart 已 fired，但本层是否创建 Drag 还要等边界/祖先裁决。
    // hold 不能提前丢：若本层让位祖先，需要 cancel 它恢复 bouncing 回位动画；
    // 若本层消费，_ensureScrollDrag 会用 Drag activity 替换并清空。
    final axis = snapshot.axis;
    final pipelineActive = event.dragPipelineActive;
    final rawPrimaryDelta = event.remainingPrimaryDelta(axis);
    if (rawPrimaryDelta.abs() <= precisionErrorTolerance) {
      _settleZeroDeltaDragStartRoute(event, snapshot);
      return;
    }
    // 拦截器优先吃一层：吃掉的量算作 gesture 级消费，从事件台账里 mark 掉，
    // 剩余量走既有边界物理路径。管线模式不设 gesture 级 eager，只 mark 已用。
    final interceptorEaten = rawPrimaryDelta - _applyDeltaInterceptor(rawPrimaryDelta, ElScrollDeltaSource.touchDrag);
    if (interceptorEaten.abs() > precisionErrorTolerance) {
      event.consumePrimaryDelta(axis, interceptorEaten);
      _interceptorClaimedGesture = true;
    }
    final primaryDelta = event.remainingPrimaryDelta(axis);
    if (primaryDelta.abs() <= precisionErrorTolerance) {
      // 拦截器吃光了（下拉刷新拉出期）：手势已归滚动侧，照样 eager 掐掉后代
      // 的 tap / 长按，否则抬手会落成卡片点击。
      if (_interceptorClaimedGesture && !pipelineActive) _consumeRemainingPrimaryDelta(event, axis);
      return;
    }

    final residuals = _boundaryResiduals(primaryDelta, snapshot, handoff: event.dragBoundaryHandoff);
    final consumed = _shouldDeferBouncingBoundaryDelta(event, primaryDelta, residuals.remainingInput, snapshot)
        ? 0.0
        : residuals.acceptedInput;
    if (consumed.abs() <= precisionErrorTolerance) {
      // 三态：
      // 1) 管线模式：不设置 gesture 级让渡（让渡语义由 pre/overflow 承担），
      //    后续帧仍需继续尝试消费；余量归 overflow 分账，不当越界报告。
      // 2) 有祖先能接手（hasAncestorDragConsumer=true）：defer 让渡，嵌套滚动
      //    起手落在边界方向时让外层接管；越界归属未定，也不报告。
      // 3) 自己是顶层（无同轴祖先消费者，非管线）：吞余量并认领手势。Drag
      //    已越过起手阈，即使边界夹住位置也必须取消后代 tap。同步截断祖先
      //    Drag route，避免交叉轴祖先（如横向 Tab）在本轴滚动已锁定后接管
      //    同一手势。**不置 defer flag**，
      //    下一帧继续尝试消费，反向回拖时立即响应（避免"顶层滚动起手拖出界
      //    方向后同手势内失灵"）。被吞的量本质就是越界量，向 position 报告
      //    以驱动 stretch indicator。
      if (pipelineActive && !_handlesAncestorInput) return;
      if (event.hasAncestorDragConsumer && !_handlesAncestorInput) {
        _resumeDeferredBoundaryHandoffSpring();
        _dragDeferredToAncestor = true;
      } else {
        if (!pipelineActive) _claimGesture(event);
        event.stopPropagation();
        _reportOverscrollAtBoundary(event, snapshot, residuals.overscroll);
        event.consumePrimaryDelta(axis, event.remainingPrimaryDelta(axis));
      }
      return;
    }

    if (!pipelineActive) _claimGesture(event);
    _pendingDragStart = _dragStartDetailsFor(event);
    _hold ??= _createScrollHold(_disposeHold);
    _applyScrollDragUpdate(event, consumed);
    _dragConsumedInGesture = true;
    if (pipelineActive && !_handlesAncestorInput) {
      // 管线模式下只记实际应用量；余量留给 overflow 阶段接盘。
      // 绝不调 _consumeRemainingPrimaryDelta（其内含 eagerGesture，会坍缩链、
      // 杀掉 roster 成员的全部投递——外层竞争压制由事件层"形成即截断"承担）。
      // 管线越界归属 overflow 祖先分账，此处也不报 overscroll notification。
      event.consumePrimaryDelta(axis, consumed);
    } else {
      // 非管线：consumed 已 apply 到 position（clamped），residual 是被夹掉的
      // 越界量。position.applyUserOffset 走 setPixels 时因 delta 已 clamp 而
      // 不会自动 didOverscrollBy——手动补报驱动 stretch。
      _dispatchOverscrollIfScrolling(residuals.overscroll, remainingInput: residuals.remainingInput, event: event);
      _consumeRemainingPrimaryDelta(event, axis, claim: false);
    }
  }

  void handleDragUpdate(ElEventDetails event) {
    if (_directInputRetired) {
      _discardRetiredDelta(event, _retiredDragAxis ?? _axis());
      return;
    }
    final transaction = _beginInputSample(event);
    try {
      _handleDragUpdate(event);
    } finally {
      transaction?.close();
    }
  }

  void _handleDragUpdate(ElEventDetails event) {
    if (_dragDeferredToAncestor) return;
    var snapshot = _dragSnapshot;
    if (snapshot == null) {
      snapshot = _captureSnapshot();
      if (!snapshot.canDrag || !snapshot.shouldAcceptUserOffset) return;
      _dragSnapshot = snapshot;
    } else if (!snapshot.canDrag || !snapshot.shouldAcceptUserOffset) {
      return;
    }
    final axis = snapshot.axis;
    final pipelineActive = event.dragPipelineActive;
    if (pipelineActive) _dragPipelineGesture = true;
    // boost 窗口维护要在任何消费之前读原始手指增量(方向/速度是手势语义,
    // 与拦截器/边界吃掉多少无关)。
    _trackFlingBoostMove(event, snapshot);
    final rawPrimaryDelta = event.remainingPrimaryDelta(axis);
    if (rawPrimaryDelta.abs() > precisionErrorTolerance) {
      final interceptorEaten = rawPrimaryDelta - _applyDeltaInterceptor(rawPrimaryDelta, ElScrollDeltaSource.touchDrag);
      if (interceptorEaten.abs() > precisionErrorTolerance) {
        event.consumePrimaryDelta(axis, interceptorEaten);
        _interceptorClaimedGesture = true;
      }
    }
    final primaryDelta = event.remainingPrimaryDelta(axis);
    if (primaryDelta.abs() <= precisionErrorTolerance) {
      if ((_dragConsumedInGesture || _interceptorClaimedGesture) && !pipelineActive) {
        // 管线模式下 delta≈0 直接 return：没有可吞的余量，也不能 eagerGesture。
        _consumeRemainingPrimaryDelta(event, axis);
      }
      return;
    }

    final residuals = _boundaryResiduals(primaryDelta, snapshot, handoff: event.dragBoundaryHandoff);
    final consumed = _shouldDeferBouncingBoundaryDelta(event, primaryDelta, residuals.remainingInput, snapshot)
        ? 0.0
        : residuals.acceptedInput;
    if (consumed.abs() > precisionErrorTolerance) {
      if (!pipelineActive) _claimGesture(event);
      _applyScrollDragUpdate(event, consumed);
      _dragConsumedInGesture = true;
    }

    if (pipelineActive && !_handlesAncestorInput) {
      // 管线模式：只记实际应用量，余量留给 overflow；不 eagerGesture、不 defer。
      // 反向回拖时 driver 每帧持续尝试消费，接管由 pre/overflow 承担。
      // 管线越界归属 overflow 祖先分账，此处不报 overscroll notification。
      if (consumed.abs() > precisionErrorTolerance) {
        event.consumePrimaryDelta(axis, consumed);
      }
      return;
    }

    if (_dragConsumedInGesture) {
      // 顶层消费路径：consumed 已 apply 到 position（clamped），residual 是被
      // 夹掉的越界量。首帧到达边界后继续外拖同样命中此支（consumed=0 但
      // _dragConsumedInGesture 已置位），补报 overscroll 驱动 stretch 持续拉伸。
      _dispatchOverscrollIfScrolling(residuals.overscroll, remainingInput: residuals.remainingInput, event: event);
      _consumeRemainingPrimaryDelta(event, axis, claim: consumed.abs() <= precisionErrorTolerance);
    } else if (event.hasAncestorDragConsumer && !_handlesAncestorInput) {
      // 有祖先能接手 → defer；已定的顶层身份不应再改口。
      _resumeDeferredBoundaryHandoffSpring();
      _dragDeferredToAncestor = true;
    } else {
      // 顶层 & 尚未在本手势消费过 & 本次也是 0 消费：吞余量并取消后代 tap；
      // 同步截断祖先 Drag route，避免交叉轴祖先后续接管；
      // **不置 defer flag**，下一帧继续尝试。见 handleDragStart。被吞的量
      // 本质是越界量，向 position 报告驱动 stretch。
      if (!pipelineActive) _claimGesture(event);
      event.stopPropagation();
      _reportOverscrollAtBoundary(event, snapshot, residuals.overscroll);
      event.consumePrimaryDelta(axis, event.remainingPrimaryDelta(axis));
    }
  }

  /// 顶层"吞余量"分支的越界报告。position 尚未持有 drag activity 时先启动
  /// drag（+hold）建立 scrolling activity，喂一次 0-delta update 让
  /// `ScrollDragController.lastDetails` 成为 `DragUpdateDetails`（`DragScrollActivity.
  /// dispatchOverscrollNotification` 内部 assert 依赖这个契约），之后
  /// didOverscrollBy 才能派发 OverscrollNotification。activity 建立后 dragEnd
  /// 会走正常清理路径。
  void _reportOverscrollAtBoundary(ElEventDetails event, _ScrollGestureSnapshot snapshot, double overscroll) {
    if (overscroll.abs() <= precisionErrorTolerance) return;
    // drag activity 已建立后绝不能再 hold()：`_hold` 引用在 [_ensureScrollDrag]
    // 里已被清空，而 `position.hold()` 走 beginActivity(HoldScrollActivity) 会
    // 杀掉活跃的 DragScrollActivity → 每帧多派发一对 ScrollEnd+ScrollStart。
    // 官方 StretchingOverscrollIndicator 收到 ScrollEnd 就启动回收动画，下一帧
    // pull() 又把动画当前值当 _interruptedOverscroll 叠加——拉伸每帧棘轮式增长
    // 且不收敛（真机"无限拉伸、幅度比官方大"的根因）。官方越界期间的通知流
    // 是纯 Overscroll 序列，Start/End 整个手势各一次。
    if (_drag == null) _hold ??= _createScrollHold(_disposeHold);
    _pendingDragStart ??= _dragStartDetailsFor(event);
    _applyScrollDragUpdate(event, 0.0);
    _dispatchOverscrollIfScrolling(
      overscroll,
      remainingInput: event.remainingPrimaryDelta(snapshot.axis),
      event: event,
    );
  }

  /// `ScrollPosition.didOverscrollBy` 内部 assert `activity!.isScrolling`；
  /// 生产路径下调 [_applyScrollDragUpdate] 已让 activity → DragScrollActivity
  /// （isScrolling=true）。为兼容用 stub 直接 handle drag 相位的单元测试
  /// （scroll_drag_controller_test.dart 的 `_RecordingScrollPosition` 只捕获调用不
  /// 建 activity），在此用公共 `isScrollingNotifier.value` 防御性 gate。
  void _dispatchOverscrollIfScrolling(
    double overscroll, {
    required double remainingInput,
    required ElEventDetails event,
  }) {
    if (overscroll.abs() <= precisionErrorTolerance) return;
    // 内层到边界的越界余量:先交嵌套链外层接力(安卓 onNestedScroll
    // unconsumed 语义),链吃剩的才作真实越界驱动 stretch/glow。
    final inputLeftover = _dispatchRemainingInput(remainingInput);
    if (_handlesAncestorInput) {
      // 所有祖先处理后，最终余量才由源视口自己的物理产生弹性或边界反馈。
      if (inputLeftover.abs() > precisionErrorTolerance) _applyScrollDragUpdate(event, inputLeftover);
      return;
    }
    // 边界指示器按未处理预算的比例保留像素反馈；该值绝不再作为输入传递。
    final leftover = remainingInput == 0 ? overscroll : overscroll * (inputLeftover / remainingInput);
    if (leftover.abs() <= precisionErrorTolerance) return;
    final position = _position();
    if (!position.isScrollingNotifier.value) return;
    position.didOverscrollBy(leftover);
  }

  void handleDragEnd(ElEventDetails event, {bool allowBallistic = true}) {
    if (_directInputRetired) return;
    final transaction = _beginInputSample(event);
    try {
      _handleDragEnd(event, allowBallistic: allowBallistic);
    } finally {
      _inputSessionId = null;
      transaction?.close();
    }
  }

  void _handleDragEnd(ElEventDetails event, {bool allowBallistic = true}) {
    _releasePointerLock();
    if (!allowBallistic) {
      _drag?.cancel();
      _drag = null;
      _dragSnapshot = null;
      _dragConsumedInGesture = false;
      _interceptorClaimedGesture = false;
      _dragDeferredToAncestor = false;
      _dragPipelineGesture = false;
      _pendingDragStart = null;
      _hold?.cancel();
      _hold = null;
      _resetFlingBoostChain();
      return;
    }
    final velocity = event.velocity;
    final snapshot = _dragSnapshot ?? _captureSnapshot();
    var primaryVelocity = _primaryDelta(velocity.pixelsPerSecond, snapshot);
    // 拦截器速度交接：把起飞速度先过一次拦截器，剩余量喂 ballistic。
    // 不消费默认返回原值；异常返回（反向/放大）视为不消费，避免破坏物理。
    // **零 velocity 也调用一次**——有状态拦截器需要 dragEnd 信号
    // 完成手势收尾（snap 动画启动等），否则慢拖松手（无 fling）收不到通知。
    // 零 velocity 时残差必须仍为 0（同号钳制的退化情形），行为等价。
    final getter = _deltaInterceptor;
    final interceptor = getter?.call();
    if (interceptor != null) {
      final residual = interceptor.interceptFlingVelocity(primaryVelocity);
      if (residual == 0.0 ||
          (primaryVelocity != 0.0 &&
              residual.sign == primaryVelocity.sign &&
              residual.abs() <= primaryVelocity.abs())) {
        primaryVelocity = residual;
      }
    }
    // FlingBooster 等差叠加:本手势按下时落在活跃 fling 上(armed)、移动期间
    // 未反向/未停顿超窗、松手成甩且同向达门槛 → 起飞速度 = combine(新手势,
    // 上次 fling 起始速度)。拦截器吃光(residual→0)时天然不达门槛,不 boost。
    final original = event.originalEvent;
    final launchPointer = original is PointerEvent ? original : null;
    primaryVelocity = _applyFlingBoost(primaryVelocity, launchPointer);
    final details = DragEndDetails(
      globalPosition: event.globalPosition,
      localPosition: event.localPosition,
      velocity: Velocity(pixelsPerSecond: _axisDelta(primaryVelocity, snapshot)),
      primaryVelocity: primaryVelocity,
    );
    if (interceptor is ScrollMotionInput) {
      final result = (interceptor as ScrollMotionInput).startReleasedMotion(details);
      if (result.handled) {
        _recordFlingLaunch(result.launched ? primaryVelocity : 0, launchPointer);
        _finishDragEndState();
        return;
      }
    }
    final drag = _drag;
    _drag = null;
    if (drag != null) {
      // 官方 ScrollDragController.end 把 velocity 直传 goBallistic,不再 clamp
      // 回 maxFlingVelocity——叠加后的速度得以突破单手势上限。但官方 end() 内
      // 还有 _retainMomentum(carriedMomentum 派生)的 0.5× 门:此路径下 physics
      // 的 carriedMomentum 恒 0(见 ElBrowserScrollPhysics),_retainMomentum
      // 为 false,不会二次叠加/塌方。
      drag.end(details);
      _recordFlingLaunch(primaryVelocity, launchPointer);
    } else if (_pendingDragStart != null &&
        !_dragDeferredToAncestor &&
        !_dragPipelineGesture &&
        primaryVelocity.abs() > precisionErrorTolerance &&
        snapshot.canDrag &&
        snapshot.shouldAcceptUserOffset) {
      // 微甩救援：seed=0 契约把起手帧位移全部丢弃，快速轻甩（阈值在最后一个
      // move 事件才越过）可能整个手势没有任何非零 dragUpdate → Drag 从未建立，
      // velocity 会随 hold 释放一起被吞掉，表现为"轻甩偶发把滚动停死"。
      // 官方 Scrollable 的 Drag 在 onStart 即建立、onEnd 必达 velocity；此处
      // 对齐：fling 方向自身可消费时补建 Drag 立即 end，让 ballistic 起飞。
      // defer / 管线让渡的手势不救援（velocity 归属祖先/协作方）；首个可消费者
      // 兑现后截断冒泡，避免祖先重复起飞。
      final probe = primaryVelocity.sign;
      final residuals = _boundaryResiduals(probe, snapshot);
      if (residuals.acceptedInput.abs() > precisionErrorTolerance) {
        _ensureScrollDrag(event);
        final rescued = _drag;
        _drag = null;
        rescued?.end(details);
        _recordFlingLaunch(primaryVelocity, launchPointer);
        event.stopPropagation();
      } else {
        // 救援方向撞界起不了飞:本手势非 fling,断连甩链。
        _recordFlingLaunch(0.0, launchPointer);
      }
    } else {
      // 未建 Drag 且不满足救援(慢拖松手 / defer / 管线让渡):非 fling,断链。
      _recordFlingLaunch(0.0, launchPointer);
    }
    _finishDragEndState();
  }

  void _finishDragEndState() {
    _pendingDragStart = null;
    _dragSnapshot = null;
    final hold = _hold;
    _hold = null;
    hold?.cancel();
    _dragConsumedInGesture = false;
    _interceptorClaimedGesture = false;
    _dragDeferredToAncestor = false;
    _dragPipelineGesture = false;
  }

  void handleDragCancel(ElEventDetails event) {
    if (_directInputRetired) return;
    final position = _position();
    cancelActiveDrag();
    // 真正的设备取消需要续接边界回位；换绑和外部命令退役仍只取消旧活动。
    if (identical(position, _position()) &&
        position is ScrollPositionWithSingleContext &&
        position.hasPixels &&
        position.hasContentDimensions &&
        position.outOfRange &&
        !position.isScrollingNotifier.value) {
      position.goBallistic(0);
    }
  }

  void handlePanZoomStart(ElEventDetails event) {
    if (_hasTrackpadState) {
      _cancelTrackpadDrag(releasePointerChain: true);
    }
    _panInputRetired = false;
    _retiredPanAxis = null;
    final snapshot = _captureSnapshot();
    if (!snapshot.canDrag || !snapshot.shouldAcceptUserOffset) return;
    _resetSmoothPointerScroll();
    _trackpadSnapshot = snapshot;
    // 新 pan 开始即接管正在运行的运动；静止视口仍在首次实际更新时惰性创建 Drag。
    if (_position().isScrollingNotifier.value) _trackpadHold ??= _position().hold(_disposeTrackpadHold);
    final originalEvent = event.originalEvent;
    _trackpadPointer = originalEvent is PointerPanZoomStartEvent ? originalEvent.pointer : null;
    _trackpadLastPan = Offset.zero;
    _trackpadVelocityTracker = originalEvent is PointerEvent
        ? _velocityTrackerBuilder()(originalEvent)
        : VelocityTracker.withKind(PointerDeviceKind.trackpad);
    _trackpadVelocityTracker?.addPosition(
      originalEvent is PointerEvent ? originalEvent.timeStamp : Duration.zero,
      Offset.zero,
    );
    _trackpadInputPosition = Offset.zero;
    _trackpadLastGlobalPosition = event.globalPosition;
    _trackpadLastLocalPosition = event.localPosition;
    _trackpadConsumedInGesture = false;
    _trackpadClaimedPointerChain = false;
  }

  void handlePanZoomUpdate(ElEventDetails callback) {
    if (_panInputRetired) {
      _discardRetiredDelta(callback, _retiredPanAxis ?? _axis());
      return;
    }
    final event = callback.originalEvent;
    if (event is! PointerPanZoomUpdateEvent) return;
    final trackpadPointer = _trackpadPointer;
    if (trackpadPointer != null && event.pointer != trackpadPointer) return;

    var snapshot = _trackpadSnapshot;
    if (snapshot == null) {
      snapshot = _captureSnapshot();
      if (!snapshot.canDrag || !snapshot.shouldAcceptUserOffset) return;
      _trackpadSnapshot = snapshot;
    } else if (!snapshot.canDrag || !snapshot.shouldAcceptUserOffset) {
      return;
    }
    final axis = snapshot.axis;
    final panDelta = _trackpadPrimaryPanDelta(event, snapshot, callback.remainingPrimaryDelta(axis));
    if (panDelta.abs() <= precisionErrorTolerance) {
      if (_trackpadConsumedInGesture) {
        callback.consumePrimaryDelta(axis, callback.remainingPrimaryDelta(axis));
        if (callback.remainingDelta == Offset.zero) {
          callback.stopPropagation();
        }
      }
      return;
    }

    final chainOwner = ScrollPointerChain.gestureOwnerAt(callback.globalPosition, axis: axis);
    if (chainOwner != null && ScrollPointerChain.shouldDeferViewportToOwner(_owner, chainOwner, axis: axis)) {
      return;
    }

    final residual = _residualPrimaryDeltaForScroll(panDelta, snapshot);
    final consumed = panDelta - residual;
    _trackpadInputPosition = _axisDelta(_primaryDelta(event.pan, snapshot), snapshot);
    _trackpadVelocityTracker?.addPosition(event.timeStamp, _trackpadInputPosition);
    if (consumed.abs() > precisionErrorTolerance || _deltaInterceptor?.call() != null) {
      ScrollPointerChain.claimGesture(_owner, axis: axis);
      _trackpadClaimedPointerChain = true;
      ScrollCursorFreeze.claim(_owner);
      _resetSmoothPointerScroll();
      final globalPosition = event.position + event.pan;
      final localPosition = callback.localPosition + event.localPan;
      _trackpadVelocityTracker ??= _velocityTrackerBuilder()(event);
      if (!_handlesAncestorInput) _ensureTrackpadDrag(callback, event);
      _trackpadConsumedInGesture = true;
      _trackpadLastGlobalPosition = globalPosition;
      _trackpadLastLocalPosition = localPosition;
      _applyTrackpadDelta(
        _axisDelta(panDelta, snapshot),
        source: event,
        sourceTimeStamp: event.timeStamp,
        globalPosition: globalPosition,
        localPosition: localPosition,
      );
    }

    if (_trackpadConsumedInGesture || _panInputRetired) {
      callback.consumePrimaryDelta(axis, callback.remainingPrimaryDelta(axis));
      if (callback.remainingDelta == Offset.zero) {
        callback.stopPropagation();
      }
    }
  }

  void handlePanZoomEnd(ElEventDetails event, {bool allowBallistic = true}) {
    if (_panInputRetired) return;
    if (!_hasTrackpadState) return;
    final originalEvent = event.originalEvent;
    final trackpadPointer = _trackpadPointer;
    if (trackpadPointer != null &&
        originalEvent is PointerPanZoomEndEvent &&
        originalEvent.pointer != trackpadPointer) {
      return;
    }
    try {
      // panEnd 会沿命中链分发；未接收实际样本的祖先不能在结束时抢占源会话。
      if (_trackpadSessionId == null && _trackpadDrag == null) return;
      final transaction = _beginTrackpadSample(originalEvent is PointerEvent ? originalEvent : null);
      try {
        final drag = _trackpadDrag;
        if (drag == null) return;
        if (!allowBallistic) {
          drag.cancel();
          return;
        }
        if (originalEvent is PointerEvent) {
          _trackpadVelocityTracker?.addPosition(originalEvent.timeStamp, _trackpadInputPosition);
        }
        final velocity = _trackpadVelocityTracker?.getVelocity() ?? Velocity.zero;
        final snapshot = _trackpadSnapshot ?? _captureSnapshot();
        var primaryVelocity = _primaryDelta(velocity.pixelsPerSecond, snapshot);
        final interceptor = _deltaInterceptor?.call();
        if (interceptor != null) {
          final rest = interceptor.interceptFlingVelocity(primaryVelocity);
          if (rest == 0 || (rest.sign == primaryVelocity.sign && rest.abs() <= primaryVelocity.abs())) {
            primaryVelocity = rest;
          }
        }
        if (!identical(drag, _trackpadDrag)) return;
        final details = DragEndDetails(
          globalPosition: _trackpadLastGlobalPosition,
          localPosition: _trackpadLastLocalPosition,
          velocity: Velocity(pixelsPerSecond: _axisDelta(primaryVelocity, snapshot)),
          primaryVelocity: primaryVelocity,
        );
        if (interceptor is ScrollMotionInput &&
            (interceptor as ScrollMotionInput).startReleasedMotion(details).handled) {
          return;
        }
        drag.end(details);
      } finally {
        transaction?.close();
      }
    } catch (_) {
      _trackpadDrag?.cancel();
      rethrow;
    } finally {
      _finishTrackpadState(releasePointerChain: true);
    }
  }

  void _finishTrackpadState({required bool releasePointerChain}) {
    final claimedAxis = _trackpadSnapshot?.axis;
    final hold = _trackpadHold;
    _trackpadHold = null;
    _trackpadDrag = null;
    _trackpadVelocityTracker = null;
    _trackpadSnapshot = null;
    _trackpadPointer = null;
    _trackpadLastPan = Offset.zero;
    _trackpadInputPosition = Offset.zero;
    _trackpadSessionId = null;
    _trackpadConsumedInGesture = false;
    final claimedPointerChain = _trackpadClaimedPointerChain;
    _trackpadClaimedPointerChain = false;
    if (releasePointerChain && claimedPointerChain) {
      ScrollPointerChain.release(_owner, axis: claimedAxis);
    }
    hold?.cancel();
  }

  /// 退役当前输入序列并释放拖拽资源，阻止旧事件重新发起滚动。
  void cancelActiveDrag() {
    // 换绑只取消当前序列，后续旧 move 不能伪装成一次新的输入开始。
    _directInputRetired |= _inputSessionId != null || _dragSnapshot != null || _pendingDragStart != null;
    _panInputRetired |= _hasTrackpadState;
    if (_directInputRetired) _retiredDragAxis ??= _dragSnapshot?.axis ?? _axis();
    if (_panInputRetired) _retiredPanAxis ??= _trackpadSnapshot?.axis ?? _axis();
    final input = _deltaInterceptor?.call();
    if (input is ScrollMotionInput) (input as ScrollMotionInput).cancelCoordinatedInput();
    _inputSessionId = null;
    _releaseDragResources();
  }

  /// 销毁拖拽资源，保持销毁入口不触发换绑时的输入退役协议。
  void disposeActiveDrag() => _releaseDragResources();

  void _releaseDragResources() {
    _releasePointerLock();
    _hold?.cancel();
    _drag?.cancel();
    _cancelTrackpadDrag(releasePointerChain: true);
    _hold = null;
    _drag = null;
    _dragSnapshot = null;
    _dragConsumedInGesture = false;
    _interceptorClaimedGesture = false;
    _dragDeferredToAncestor = false;
    _dragPipelineGesture = false;
    _pendingDragStart = null;
    for (final pointer in _heldPointers) {
      ScrollCatchPointers.remove(pointer);
    }
    _heldPointers.clear();
    _resetFlingBoostChain();
  }

  void _ensureScrollDrag(ElEventDetails event) {
    if (_drag != null) return;
    final start = _pendingDragStart ?? _dragStartDetailsFor(event);
    _drag = _createScrollDrag(start, _disposeDrag);
    if (!_liveHandle(_drag)) {
      _drag = null;
      _directInputRetired = true;
      _retiredDragAxis = _dragSnapshot?.axis ?? _axis();
    }
    _pendingDragStart = null;
    if (_hold != null) _disposeHold();
  }

  void _applyScrollDragUpdate(ElEventDetails event, double consumed) {
    _ensureScrollDrag(event);
    final snapshot = _dragSnapshot ??= _captureSnapshot();
    _drag?.update(_dragUpdateDetailsFor(event, snapshot.axis, consumed));
  }

  double _residualPrimaryDeltaForScroll(double primaryDelta, _ScrollGestureSnapshot snapshot) {
    return _boundaryResiduals(primaryDelta, snapshot).remainingInput;
  }

  /// bouncing 系物理的嵌套让位判定。弹簧物理不设边界条件
  /// (`applyBoundaryConditions` 恒 0),[_boundaryResiduals] 对"贴边继续外拖"
  /// 失明:delta 全量转成弹性越界位移,consumed 永不为 0,clamping 下由
  /// "0 消费"触发的 defer 让位在弹簧下永远不发生——嵌套滚动起手在边界时
  /// 内层自己 rubber-band 吃掉整个手势,外层接不到。
  ///
  /// 显式补判:物理没报边界余量、position 贴在或已经越过 delta 指向的边界、
  /// 本手势尚未消费过、且有外层能接手 → 视作 0 消费走 defer(与 clamping
  /// 的起手在界让位对齐)。已经越界后继续往外拖也让位外层；反向回拖收
  /// rubber-band 仍归本层。顶层无人接手时维持全量弹性,管线路径(proxy 分账)
  /// 不经此判定。
  bool _shouldDeferBouncingBoundaryDelta(
    ElEventDetails event,
    double primaryDelta,
    double residual,
    _ScrollGestureSnapshot snapshot,
  ) {
    if (_handlesAncestorInput) return false;
    if (_dragConsumedInGesture) return false;
    if (event.dragPipelineActive) return false;
    if (!event.hasAncestorDragConsumer) return false;
    if (residual.abs() > precisionErrorTolerance) return false;
    final position = _position();
    if (!position.hasPixels || !position.hasContentDimensions) return false;
    final pixels = position.pixels;
    var userOffset = primaryDelta;
    if (axisDirectionIsReversed(snapshot.axisDirection)) userOffset = -userOffset;
    // userOffset 正 = pixels 减小方向；贴边或已在弹性区时继续外拖，都应让位祖先。
    return userOffset > 0
        ? pixels <= position.minScrollExtent + precisionErrorTolerance
        : pixels >= position.maxScrollExtent - precisionErrorTolerance;
  }

  bool _isBouncingOutOfRange(ScrollPhysics physics, ScrollPosition position) {
    if (!position.hasPixels || !position.hasContentDimensions || !position.outOfRange) return false;
    for (ScrollPhysics? node = physics; node != null; node = node.parent) {
      if (node is BouncingScrollPhysics) return true;
    }
    return false;
  }

  void _resumeDeferredBoundaryHandoffSpring() {
    final hold = _hold;
    _hold = null;
    if (hold != null) {
      hold.cancel();
      return;
    }

    final position = _position();
    if (!position.hasPixels || !position.hasContentDimensions || !position.outOfRange) return;
    if (position is ScrollPositionWithSingleContext) {
      // 没有 hold 可释放时，沿用当前 physics 起一段零速 ballistic，让 iOS
      // 弹性区按原本动画回位，而不是硬跳回边界。
      position.goBallistic(0.0);
      return;
    }
  }

  /// 一次计算分别保留输入接受量与像素边界反馈，不额外包装分账结果。
  ScrollInputStep _boundaryResiduals(double primaryDelta, _ScrollGestureSnapshot snapshot, {bool handoff = false}) {
    var physics = snapshot.physics;
    if (handoff) {
      // 只钳制本帧交接方向；保留阻尼，也允许已有弹性越界正常回位。
      if (!identical(_handoffPhysics?.parent, physics)) _handoffPhysics = ClampingScrollPhysics(parent: physics);
      physics = _handoffPhysics!;
    }
    return ScrollInputStep.resolve(_position(), physics, primaryDelta, clampToRange: _handlesAncestorInput);
  }

  /// DragStart 是零基种子事件，也必须完成手势归属裁决。
  void _settleZeroDeltaDragStartRoute(ElEventDetails event, _ScrollGestureSnapshot snapshot) {
    if (event.dragPipelineActive) return;
    if (_handlesAncestorInput) {
      _claimGesture(event);
      event.stopPropagation();
      return;
    }
    if (!event.hasAncestorDragConsumer) {
      // DragStart 已越过设备 slop；边界夹住位置不等于一次点击。
      _claimGesture(event);
      event.stopPropagation();
      return;
    }
    final probe = _dragStartDirectionProbe(event, snapshot);
    if (probe != null && _dragStartDirectionHitsBoundary(event, snapshot, probe)) {
      _resumeDeferredBoundaryHandoffSpring();
      _dragDeferredToAncestor = true;
      return;
    }
    event.stopPropagation();
  }

  bool _dragStartDirectionHitsBoundary(ElEventDetails event, _ScrollGestureSnapshot snapshot, double probe) {
    final residuals = _boundaryResiduals(probe, snapshot);
    if (_shouldDeferBouncingBoundaryDelta(event, probe, residuals.remainingInput, snapshot)) return true;
    final consumed = residuals.acceptedInput;
    return consumed.abs() <= precisionErrorTolerance;
  }

  double? _dragStartDirectionProbe(ElEventDetails event, _ScrollGestureSnapshot snapshot) {
    return switch ((snapshot.axis, event.dragDirection)) {
      (Axis.vertical, AxisDirection.down) || (Axis.horizontal, AxisDirection.right) => 1.0,
      (Axis.vertical, AxisDirection.up) || (Axis.horizontal, AxisDirection.left) => -1.0,
      _ => null,
    };
  }

  void _consumeRemainingPrimaryDelta(ElEventDetails event, Axis axis, {bool claim = true}) {
    event.consumePrimaryDelta(axis, event.remainingPrimaryDelta(axis));
    if (claim) _claimGesture(event);
  }

  /// 滚动消费方在认领当前 pointer 后，单独申请鼠标强排他锁。
  ///
  /// `eagerGesture` 只负责当前 pointer 的 ElEvent 归属；内容区鼠标拖动滚动还需
  /// 屏蔽新命中，因此强锁必须由真实消费方显式持有，不能反向污染普通 eager。
  void _claimGesture(ElEventDetails event) {
    event.eagerGesture(cancelSelfTap: true, allowScaleUpgrade: true);
    final original = event.originalEvent;
    if (_ownsPointerLock || original is! PointerEvent || original.kind != PointerDeviceKind.mouse) return;
    _ownsPointerLock = true;
    DragPointerLock.claim(_owner);
  }

  void _releasePointerLock() {
    if (!_ownsPointerLock) return;
    _ownsPointerLock = false;
    DragPointerLock.release(_owner);
  }

  void _ensureTrackpadDrag(ElEventDetails callback, PointerPanZoomUpdateEvent event) {
    final details = DragStartDetails(
      sourceTimeStamp: event.timeStamp,
      globalPosition: callback.globalPosition,
      localPosition: callback.localPosition,
      kind: PointerDeviceKind.trackpad,
    );
    _ensureTrackpadDragDetails(details);
  }

  void _ensureTrackpadDragDetails(DragStartDetails details) {
    if (_trackpadDrag != null) return;
    _trackpadHold ??= _createScrollHold(_disposeTrackpadHold);
    _trackpadDrag = _createScrollDrag(details, _disposeTrackpadDrag);
    if (!_liveHandle(_trackpadDrag)) {
      _panInputRetired = true;
      _retiredPanAxis = _trackpadSnapshot?.axis ?? _axis();
      _cancelTrackpadDrag(releasePointerChain: true);
    }
    if (_trackpadHold != null) _disposeTrackpadHold();
  }

  _ScrollGestureSnapshot _captureSnapshot() {
    return _ScrollGestureSnapshot(
      axis: _axis(),
      axisDirection: _axisDirection(),
      physics: _physics(),
      velocityTrackerBuilder: _velocityTrackerBuilder(),
      canDrag: _canDrag(),
      shouldAcceptUserOffset: _shouldAcceptUserOffset(),
    );
  }

  double _primaryDelta(Offset delta, _ScrollGestureSnapshot snapshot) =>
      snapshot.axis == Axis.vertical ? delta.dy : delta.dx;

  Offset _axisDelta(double primaryDelta, _ScrollGestureSnapshot snapshot) =>
      snapshot.axis == Axis.vertical ? Offset(0.0, primaryDelta) : Offset(primaryDelta, 0.0);

  void _disposeHold() {
    _hold = null;
  }

  void _disposeTrackpadHold() {
    _trackpadHold = null;
  }

  void _disposeDrag() {
    _releasePointerLock();
    _drag = null;
    _dragSnapshot = null;
  }

  void _disposeTrackpadDrag() {
    _trackpadDrag = null;
  }

  double _trackpadPrimaryPanDelta(PointerPanZoomUpdateEvent event, _ScrollGestureSnapshot snapshot, double fallback) {
    final currentPan = event.pan;
    final panDelta = currentPan - _trackpadLastPan;
    _trackpadLastPan = currentPan;
    final primary = _primaryDelta(panDelta, snapshot);
    if (primary.abs() <= precisionErrorTolerance) return fallback;
    if (fallback.abs() <= precisionErrorTolerance) return primary;
    if (primary.sign != fallback.sign) return fallback;
    return primary;
  }

  bool get _hasTrackpadState =>
      _trackpadHold != null ||
      _trackpadDrag != null ||
      _trackpadVelocityTracker != null ||
      _trackpadSnapshot != null ||
      _trackpadLastPan != Offset.zero ||
      _trackpadConsumedInGesture ||
      _trackpadClaimedPointerChain;

  void _applyTrackpadDelta(
    Offset panDelta, {
    required PointerPanZoomUpdateEvent source,
    required Duration sourceTimeStamp,
    required Offset globalPosition,
    Offset? localPosition,
  }) {
    final snapshot = _trackpadSnapshot;
    if (snapshot == null) return;

    final primaryDelta = _primaryDelta(panDelta, snapshot);
    if (primaryDelta.abs() <= precisionErrorTolerance) return;

    final transaction = _beginTrackpadSample(source, timeStamp: sourceTimeStamp);
    try {
      if (_panInputRetired) return;
      _ensureTrackpadDragDetails(
        DragStartDetails(
          sourceTimeStamp: sourceTimeStamp,
          globalPosition: globalPosition,
          localPosition: localPosition ?? _owner.globalToLocal(globalPosition),
          kind: PointerDeviceKind.trackpad,
        ),
      );
      final drag = _trackpadDrag;
      if (drag == null) return;
      final afterPre = _applyDeltaInterceptor(primaryDelta, ElScrollDeltaSource.touchDrag);
      if (!identical(drag, _trackpadDrag)) return;
      var remaining = afterPre.abs() <= precisionErrorTolerance
          ? 0.0
          : _residualPrimaryDeltaForScroll(afterPre, snapshot);
      final consumed = afterPre - remaining;
      if (consumed.abs() > precisionErrorTolerance) {
        final local = localPosition ?? _owner.globalToLocal(globalPosition);
        _trackpadLastGlobalPosition = globalPosition;
        _trackpadLastLocalPosition = local;
        drag.update(
          DragUpdateDetails(
            sourceTimeStamp: sourceTimeStamp,
            globalPosition: globalPosition,
            localPosition: local,
            delta: _axisDelta(consumed, snapshot),
            primaryDelta: consumed,
            kind: PointerDeviceKind.trackpad,
          ),
        );
      }
      if (!identical(drag, _trackpadDrag)) return;
      final interceptor = _deltaInterceptor?.call();
      if (remaining.abs() > precisionErrorTolerance && interceptor is ElScrollPostDeltaInterceptor) {
        final accepted = (interceptor as ElScrollPostDeltaInterceptor).interceptPostScroll(
          remaining,
          ElScrollDeltaSource.touchDrag,
        );
        if (accepted.sign == remaining.sign && accepted.abs() <= remaining.abs()) remaining -= accepted;
      }
      if (_handlesAncestorInput && remaining.abs() > precisionErrorTolerance && identical(drag, _trackpadDrag)) {
        drag.update(
          DragUpdateDetails(
            sourceTimeStamp: sourceTimeStamp,
            globalPosition: globalPosition,
            localPosition: localPosition ?? _owner.globalToLocal(globalPosition),
            delta: _axisDelta(remaining, snapshot),
            primaryDelta: remaining,
            kind: PointerDeviceKind.trackpad,
          ),
        );
      }
    } catch (_) {
      _cancelTrackpadDrag(releasePointerChain: true);
      rethrow;
    } finally {
      transaction?.close();
    }
  }

  ScrollInputTransaction? _beginTrackpadSample(PointerEvent? rawEvent, {Duration? timeStamp}) {
    final interceptor = _deltaInterceptor?.call();
    if (interceptor == null) return null;
    _trackpadSessionId ??= ScrollInputTransaction.newSessionId();
    return ScrollInputTransaction.begin(
      source: ElScrollInputSource.trackpad,
      rawEvent: rawEvent,
      timeStamp: timeStamp,
      sessionId: _trackpadSessionId,
      onInputCancelled: _retireInputSession,
      participants: interceptor is ScrollInputTransactionSource ? interceptor as ScrollInputTransactionSource : null,
    );
  }

  void _cancelTrackpadDrag({required bool releasePointerChain}) {
    _trackpadDrag?.cancel();
    _finishTrackpadState(releasePointerChain: releasePointerChain);
  }

  static DragStartDetails _dragStartDetailsFor(ElEventDetails event) {
    final originalEvent = event.originalEvent;
    return DragStartDetails(
      sourceTimeStamp: event.sampleTimeStamp ?? (originalEvent is PointerEvent ? originalEvent.timeStamp : null),
      globalPosition: event.globalPosition,
      localPosition: event.localPosition,
      kind: originalEvent is PointerEvent ? originalEvent.kind : null,
    );
  }

  static DragUpdateDetails _dragUpdateDetailsFor(ElEventDetails event, Axis axis, double consumed) {
    final originalEvent = event.originalEvent;
    return DragUpdateDetails(
      sourceTimeStamp: event.sampleTimeStamp ?? (originalEvent is PointerEvent ? originalEvent.timeStamp : null),
      globalPosition: event.globalPosition,
      localPosition: event.localPosition,
      delta: axis == Axis.vertical ? Offset(0.0, consumed) : Offset(consumed, 0.0),
      primaryDelta: consumed,
      kind: originalEvent is PointerEvent ? originalEvent.kind : null,
    );
  }
}

final class _ScrollGestureSnapshot {
  const _ScrollGestureSnapshot({
    required this.axis,
    required this.axisDirection,
    required this.physics,
    required this.velocityTrackerBuilder,
    required this.canDrag,
    required this.shouldAcceptUserOffset,
  });

  final Axis axis;
  final AxisDirection axisDirection;
  final ScrollPhysics physics;
  final GestureVelocityTrackerBuilder velocityTrackerBuilder;
  final bool canDrag;
  final bool shouldAcceptUserOffset;
}
