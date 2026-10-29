// 统一滚动宿主 State 及其既有私有协作类型。
// ignore_for_file: prefer_initializing_formals

part of '../virtual_pipeline.dart';

final class _ScrollViewScope extends InheritedWidget {
  const _ScrollViewScope({required this.state, required super.child});

  final ElScrollViewState state;

  @override
  InheritedElement createElement() => _ScrollViewScopeElement(this);

  @override
  bool updateShouldNotify(_ScrollViewScope oldWidget) => true;
}

class _ScrollViewScopeElement extends InheritedElement with NotifiableElementMixin {
  _ScrollViewScopeElement(_ScrollViewScope super.widget) {
    (widget as _ScrollViewScope).state._scopeElement = this;
  }

  bool _inputChanged = false;

  // 只在协同成员换代时唤醒后代，不重建滚动宿主或在逐帧输入中遍历树。
  void inputChanged() {
    if (_inputChanged) return;
    _inputChanged = true;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical((widget as _ScrollViewScope).state._scopeElement, this)) markNeedsBuild();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    } else {
      markNeedsBuild();
    }
  }

  @override
  Widget build() {
    if (_inputChanged) {
      _inputChanged = false;
      notifyClients(widget as _ScrollViewScope);
    }
    return super.build();
  }

  @override
  void unmount() {
    final state = (widget as _ScrollViewScope).state;
    if (identical(state._scopeElement, this)) state._scopeElement = null;
    super.unmount();
  }

  @override
  bool onNotification(Notification notification) {
    if (notification is ScrollNotification) (widget as _ScrollViewScope).state._stretch?.handle(notification);
    return false;
  }
}

/// 供 [ElScrollView.maybeOf] 跨滚动实现 library 查找最近宿主。
@internal
ElScrollViewState? maybeFindScrollViewState(BuildContext context, {Axis? axis}) {
  final originalContext = context;
  InheritedElement? element = context.getElementForInheritedWidgetOfExactType<_ScrollViewScope>();
  while (element != null) {
    final state = (element.widget as _ScrollViewScope).state;
    // 被跳过的近层宿主以后可能支持目标轴，也必须能唤醒当前依赖者重新查找。
    originalContext.dependOnInheritedElement(element);
    if (axis == null || state.positionFor(axis) != null) {
      return state;
    }
    context = state.context;
    element = context.getElementForInheritedWidgetOfExactType<_ScrollViewScope>();
  }
  return null;
}

abstract interface class _ScrollMixinClient {
  Axis? get _scrollAxis;

  int? get _scrollItemIndex;

  Object? get _scrollItemIdentity;

  bool get mountedForScrollCallbacks;

  bool get wantsScrollUpdates;

  bool get wantsViewportUpdates;

  bool get wantsScrollItemUpdates;

  bool get tracksScrollItemVisibility;

  bool get tracksScrollItemVisibleFraction;

  double? get scrollItemStickyOffset;

  Object? get scrollInputSlot;

  Iterable<ElScrollEffectTrack> get _effectTracks;

  void attachToScrollView(ElScrollViewState state);

  void detachFromScrollView(ElScrollViewState state);

  void handleScrollStart(ElScrollStartDetails details);

  void handleScrollUpdate(ElScrollUpdateDetails details);

  void handleScrollEnd(ElScrollEndDetails details);

  void handleMetricsChanged(ElScrollMetricsDetails details);

  void handleActivityChanged(ElScrollActivityDetails details);

  void handleScrollItemChanged(ElScrollItemUpdateDetails details);

  void handleScrollItemVisibilityChanged(ElVisibilityInfo info);

  double handlePreScroll(ElScrollInputDetails input, double remaining);

  double handlePostScroll(ElScrollInputDetails input, double remaining);

  double handlePreFling(ElScrollReleaseDetails details, double remainingVelocity);
}

final class _ScrollMixinClientRegistration {
  _ScrollMixinClientRegistration({
    required this.axis,
    required this.itemIndex,
    required this.itemIdentity,
    required this.wantsScrollUpdates,
    required this.wantsViewportUpdates,
    required this.wantsScrollSessions,
    required this.wantsScrollItemUpdates,
    required this.wantsScrollItemSize,
    required this.preserveItemAnchor,
    required this.viewportHeader,
    required this.tracksScrollItemVisibility,
    required this.tracksScrollItemVisibleFraction,
    required this.stickyOffset,
    required this.scrollInputSlot,
    required this.effectTracks,
  });

  final Axis axis;
  int? itemIndex;
  final Object? itemIdentity;
  final bool wantsScrollUpdates;
  final bool wantsViewportUpdates;
  final bool wantsScrollSessions;
  final bool wantsScrollItemUpdates;
  final bool wantsScrollItemSize;
  final bool preserveItemAnchor;
  final bool viewportHeader;
  final bool tracksScrollItemVisibility;
  final bool tracksScrollItemVisibleFraction;
  final double? stickyOffset;
  final Object? scrollInputSlot;
  final List<ElScrollEffectTrack> effectTracks;

  ElScrollItemSnapshot lastItemSnapshot = ElScrollItemSnapshot.detached;
  bool visibilityDispatched = false;
  bool lastVisible = false;
  double lastVisibleFraction = 0.0;

  bool get hasItem => itemIndex != null && itemIdentity != null;

  bool get participatesInItemDispatch =>
      hasItem &&
      (wantsScrollItemUpdates ||
          wantsScrollItemSize ||
          !preserveItemAnchor ||
          viewportHeader ||
          tracksScrollItemVisibility ||
          stickyOffset != null);

  void inheritDispatchState(_ScrollMixinClientRegistration previous) {
    if (itemIndex != previous.itemIndex || itemIdentity != previous.itemIdentity) return;
    lastItemSnapshot = previous.lastItemSnapshot;
    visibilityDispatched = previous.visibilityDispatched;
    lastVisible = previous.lastVisible;
    lastVisibleFraction = previous.lastVisibleFraction;
  }

  @override
  bool operator ==(Object other) {
    return other is _ScrollMixinClientRegistration &&
        other.axis == axis &&
        other.itemIndex == itemIndex &&
        other.itemIdentity == itemIdentity &&
        other.wantsScrollUpdates == wantsScrollUpdates &&
        other.wantsViewportUpdates == wantsViewportUpdates &&
        other.wantsScrollSessions == wantsScrollSessions &&
        other.wantsScrollItemUpdates == wantsScrollItemUpdates &&
        other.wantsScrollItemSize == wantsScrollItemSize &&
        other.preserveItemAnchor == preserveItemAnchor &&
        other.viewportHeader == viewportHeader &&
        other.tracksScrollItemVisibility == tracksScrollItemVisibility &&
        other.tracksScrollItemVisibleFraction == tracksScrollItemVisibleFraction &&
        other.stickyOffset == stickyOffset &&
        other.scrollInputSlot == scrollInputSlot &&
        listEquals(other.effectTracks, effectTracks);
  }

  @override
  int get hashCode => Object.hash(
    axis,
    itemIndex,
    itemIdentity,
    wantsScrollUpdates,
    wantsViewportUpdates,
    wantsScrollSessions,
    wantsScrollItemUpdates,
    wantsScrollItemSize,
    preserveItemAnchor,
    viewportHeader,
    tracksScrollItemVisibility,
    tracksScrollItemVisibleFraction,
    stickyOffset,
    scrollInputSlot,
    Object.hashAll(effectTracks),
  );
}

final class _ScrollMetricsSignature {
  const _ScrollMetricsSignature({
    required this.ready,
    required this.axisDirection,
    this.minScrollExtent,
    this.maxScrollExtent,
    this.viewportDimension,
  });

  factory _ScrollMetricsSignature.fromPosition(ScrollPosition position) {
    final ready = position.hasPixels && position.hasContentDimensions;
    return _ScrollMetricsSignature(
      ready: ready,
      axisDirection: position.axisDirection,
      minScrollExtent: ready ? position.minScrollExtent : null,
      maxScrollExtent: ready ? position.maxScrollExtent : null,
      viewportDimension: ready ? position.viewportDimension : null,
    );
  }

  final bool ready;
  final AxisDirection axisDirection;
  final double? minScrollExtent;
  final double? maxScrollExtent;
  final double? viewportDimension;

  @override
  bool operator ==(Object other) {
    return other is _ScrollMetricsSignature &&
        other.ready == ready &&
        other.axisDirection == axisDirection &&
        other.minScrollExtent == minScrollExtent &&
        other.maxScrollExtent == maxScrollExtent &&
        other.viewportDimension == viewportDimension;
  }

  @override
  int get hashCode => Object.hash(ready, axisDirection, minScrollExtent, maxScrollExtent, viewportDimension);
}

final class _ScrollMixinAxisState {
  ScrollPosition? position;
  ElScrollSnapshot snapshot = ElScrollSnapshot.detached;
  ElScrollSnapshot? readSnapshot;
  double pendingCorrectionPixels = 0;
  ElScrollActivityType? explicitActivity;
}

/// 本地输入参与者与既有 refresher / nested / widget interceptor 的稳定边界接线。
final class _ScrollMixinInputLink extends ElScrollDeltaInterceptor
    implements ElScrollPostDeltaInterceptor, ScrollInputTransactionSource, ScrollMotionInput, ScrollPointerMotionInput {
  _ScrollMixinInputLink({required this.host, required this.axis});

  final ElScrollViewState host;
  Axis axis;
  ElScrollDeltaInterceptor? next;

  @override
  void joinInputTransaction(ScrollInputTransaction transaction) {
    transaction.establishOrigin(host);
    if (transaction.source != ElScrollInputSource.pointerSignal || transaction.sessionId != null) {
      host._ancestorRouteFor(axis)?.join(transaction);
    }
    host._inputRouter?._joinTransaction(transaction);
  }

  @override
  bool get hasMotionInputRange =>
      (axis == host._layoutAxis && host._baseEffectiveInterceptor != null) ||
      (host._inputRouter?.hasMotionInputRange(axis) ?? false) ||
      (host._ancestorRouteFor(axis)?.hasInputRange ?? false);

  @override
  bool get handlesAncestorInput => host._ancestorRouteFor(axis) != null;

  @override
  bool get supportsPointerMotion => host._ancestorRouteFor(axis) != null;

  @override
  bool canConsumePointerDelta(double delta) {
    if (delta == 0) return false;
    final route = host._ancestorRouteFor(axis);
    if (route == null) return false;
    final position = host.positionFor(axis)!;
    if (position.outOfRange ||
        (delta > 0 ? position.pixels < position.maxScrollExtent : position.pixels > position.minScrollExtent)) {
      return true;
    }
    final contentDelta = delta * _ScrollInputRouter._inputScale(.pointerScroll, position.axisDirection);
    bool effectCanConsume(ElScrollViewState target) =>
        (axis == target._layoutAxis && target.widget.deltaInterceptor != null) ||
        (target._inputRouter?.canConsumePointerInput(axis, contentDelta) ?? false);
    return effectCanConsume(host) || route.ancestors.any(effectCanConsume);
  }

  @override
  ScrollPointerMotionSession beginPointerMotion(PointerScrollEvent event, VoidCallback onCancelled) =>
      _ScrollPointerMotionSession(this, event, onCancelled)..initialize();

  @override
  void cancelCoordinatedInput() {
    final route = host._ancestorRouteFor(axis);
    if (route != null) {
      route.finish(cancelled: true);
    } else if (next is ScrollMotionInput) {
      (next as ScrollMotionInput).cancelCoordinatedInput();
    }
  }

  @override
  ({bool handled, bool launched}) startReleasedMotion(DragEndDetails details) =>
      host._motionCoordinatorFor(axis)?.startReleasedMotion(details) ?? (handled: false, launched: false);

  @override
  double interceptScrollDelta(double delta, ElScrollDeltaSource source) {
    final position = host.positionFor(axis);
    // 越界正文先按原物理收回；只把跨回真实边界后的输入交给头部，不能用像素间隙直接扣原始输入。
    final recovery = source == ElScrollDeltaSource.touchDrag && position != null && position.outOfRange
        ? ScrollInputStep.resolve(position, position.physics, delta, stopAtBoundary: true).acceptedInput
        : 0.0;
    var remaining = delta - recovery;
    final route = source == ElScrollDeltaSource.pointerScroll && ScrollInputTransaction.current?.sessionId == null
        ? null
        : host._ancestorRouteFor(axis);
    if (route != null) remaining = _subtractValidConsumed(remaining, route.pre(remaining, source));
    if (route != null && !route.isCurrent) return delta;
    final target = route != null && next is RefreshScrollLink ? (next as RefreshScrollLink).next : next;
    if (target != null && remaining.abs() > precisionErrorTolerance) {
      remaining = _subtractValidConsumed(remaining, target.interceptScrollDelta(remaining, source));
      if (route != null && !route.isCurrent) return delta;
    }
    final ownConsumed = host._dispatchMixinPreScroll(axis, remaining, source, requestedDelta: delta);
    if (route != null && !route.isCurrent) return delta;
    remaining = _subtractValidConsumed(remaining, ownConsumed);
    return delta - remaining - recovery;
  }

  @override
  double interceptPostScroll(double delta, ElScrollDeltaSource source) {
    final activeRoute = source == ElScrollDeltaSource.pointerScroll && ScrollInputTransaction.current?.sessionId == null
        ? null
        : host._ancestorRouteFor(axis);
    if (activeRoute != null && !activeRoute.isCurrent) return delta;
    var remaining = delta;
    final ownConsumed = host._dispatchMixinPostScroll(axis, remaining, source);
    if (activeRoute != null && !activeRoute.isCurrent) return delta;
    remaining = _subtractValidConsumed(remaining, ownConsumed);
    final route = activeRoute;
    final target = route != null && next is RefreshScrollLink ? (next as RefreshScrollLink).next : next;
    if (target != null && target is ElScrollPostDeltaInterceptor && remaining.abs() > precisionErrorTolerance) {
      remaining = _subtractValidConsumed(
        remaining,
        (target as ElScrollPostDeltaInterceptor).interceptPostScroll(remaining, source),
      );
      if (route != null && !route.isCurrent) return delta;
    }
    if (route != null && remaining.abs() > precisionErrorTolerance) {
      remaining = _subtractValidConsumed(remaining, route.post(remaining, source));
    }
    return delta - remaining;
  }

  @override
  double interceptFlingVelocity(double velocity) {
    final routed = host._ancestorRouteFor(axis)?.preFling(velocity) ?? velocity;
    var remaining = host._dispatchMixinPreFling(axis, routed, requestedVelocity: velocity);
    if (!_isValidRemaining(velocity, remaining)) remaining = velocity;
    final target = host._ancestorRouteFor(axis) != null && next is RefreshScrollLink
        ? (next as RefreshScrollLink).next
        : next;
    if (target != null) {
      final nextRemaining = target.interceptFlingVelocity(remaining);
      if (_isValidRemaining(remaining, nextRemaining)) remaining = nextRemaining;
    }
    return remaining;
  }

  static double _subtractValidConsumed(double delta, double consumed) {
    if (consumed == 0.0) return delta;
    if (consumed.sign != delta.sign || consumed.abs() > delta.abs()) return delta;
    return delta - consumed;
  }

  static bool _isValidRemaining(double input, double remaining) {
    if (!input.isFinite || !remaining.isFinite) return false;
    if (input == 0.0) return remaining == 0.0;
    if (remaining == 0.0) return true;
    return remaining.sign == input.sign && remaining.abs() <= input.abs();
  }
}

/// [ElScrollView] 的真实滚动宿主 State。
///
/// 本类持有实际 controller、position、viewport 与滚动管线；业务组件应通过
/// [ElScrollView.of] 或 [ElScrollView.maybeOf] 获取最近祖先宿主，而不是自行
/// 创建第二套滚动对象。
final class ElScrollViewState extends State<ElScrollView> with TickerProviderStateMixin implements ScrollIndexBridge {
  _ScrollStretch? _stretch;
  bool _inputTickerEnabled = true;
  ValueListenable<TickerModeData>? _inputTickerModeNotifier;
  Map<int, _ScrollMixinClient>? _viewportHeaderOwners;

  double get _viewportHeaderExtent {
    if (_viewportHeaderOwners == null) return 0;
    final viewport = _activeMixinViewportRenderObject();
    return viewport is _RenderVirtualViewport ? viewport._headerExtent : 0;
  }

  static const bool _debugTraceCorrections = false;

  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _focusKey = GlobalKey();
  final GlobalKey _notificationKey = GlobalKey();
  final ElVirtualScrollDebugCounters? _debugCounters = _scrollDebugCountersEnabled
      ? ElVirtualScrollDebugCounters()
      : null;

  /// 外部 controller 的滚轮命令仍进入真实视口的输入链。
  @override
  bool dispatchPointerScroll(PointerScrollEvent event) {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    return viewport is RenderVirtualScrollView && viewport.dispatchPointerScroll(event);
  }

  /// widget 层滚动条 thumb 拖拽映射:走 render 的同步 extent 模型
  /// (估算 extent 下线性 fraction→pixels 会漂),并把拖拽起止/分数状态
  /// 转发进既有 [_handleScrollbarDragChanged] 快路径。
  late final _VirtualThumbDragDelegate _thumbDragDelegate = _VirtualThumbDragDelegate(this);

  /// render layout 尾声 → host 快照刷新的 metrics 通道(仅 extent 变化、
  /// 无像素移动时 position 不通知,host 会盲)。
  ScrollbarController? _scrollbarController;

  late final ScrollPositionBinding<ElScrollView> _scrollBinding;

  /// 双轴模式（axis: null）下的水平轴 binding；单轴恒为 null。
  ScrollPositionBinding<ElScrollView>? _horizontalBinding;
  late final _ScrollMountController _contentController;
  ScrollController? _appliedController;
  ScrollController? _appliedHorizontalController;

  /// 已生效的**基础**物理（wrap 前）——结构比对与刷新停靠都以它为基准，
  /// [_appliedPhysics] 是 wrap 后的实例，直接跟它比会永远不等。
  late ScrollPhysics _appliedWidgetPhysics;

  /// 环境滚动物理（官方 `ScrollConfiguration` 通道）缓存。
  ///
  /// 解析要查 InheritedWidget：initState 里查会断言，render 侧回调
  /// （[RenderVirtualScrollView.deferStructuralUpdateForActiveTouch]）触发的结构
  /// 更新路径也不该查。因此只在依赖变化 / widget 更新这些有 context 的时机刷新
  /// （口径同 [_selectedRefresher] / [_selectedSmoothScroll]），其余路径读缓存；
  /// 未解析前（initState 到首次依赖回调之间）按 el 平台口径兜底。
  ScrollPhysics? _environmentPhysics;

  /// 生效基础物理：widget 直参 > 环境（`ScrollConfiguration`）> el 平台口径，
  /// 刷新器不参与物理选择。
  ///
  /// 全程**不查 inherited**（环境值走 [_environmentPhysics] 缓存），所以
  /// [_hasPendingStructuralScrollUpdate] / [_applyStructuralScrollUpdate] 这类会被
  /// render 侧回调触发的路径也能安全求值。
  ScrollPhysics get _effectiveWidgetPhysics =>
      widget.physics ?? _environmentPhysics ?? elScrollPhysicsFor(defaultTargetPlatform);

  /// 从官方 `ScrollConfiguration` 取当前子树默认物理；**树上没有祖先时返回 null**，
  /// 由 [_effectiveWidgetPhysics] 的第三级 el 平台口径兜底（必须有 context）。
  ///
  /// 必须用 `dependOnInheritedWidgetOfExactType` 直读，而不是
  /// [ScrollConfiguration.of]：后者在无祖先时会兜底返回官方基类 behavior，
  /// 于是「没人包 ScrollConfiguration」与「祖先就是官方基类」不可区分，
  /// 第三级 el 口径永远轮不到——el 组件会退成官方 clamping
  /// （Windows/Linux 丢弹跳、Android 平白多套一层 RangeMaintaining）。
  ScrollPhysics? _resolveEnvironmentPhysics() =>
      context.dependOnInheritedWidgetOfExactType<ScrollConfiguration>()?.behavior.getScrollPhysics(context);

  late ScrollPhysics _appliedPhysics;

  /// 双轴水平轴生效的 physics：与 [_appliedPhysics] 分开缓存，**不含**
  /// fling 拦截 / 刷新停靠包装——双轴 v1 拦截器与刷新只作用于垂直主轴。
  late ScrollPhysics _appliedHorizontalPhysics;
  ElRefresher? _selectedRefresher;

  /// 生效的平滑滚动算法（缓存稳定实例）：post-frame 报告触发的 rebuild 若每
  /// build 重新 resolve，viewport 每次拿到新实例 → 基座驱动状态被重置，
  /// 进行中的滚轮动画时序错乱；只在 init / 依赖变化 / widget 更新时刷新。
  ElSmoothScroll? _selectedSmoothScroll;
  Axis? _appliedAxis;
  late bool _appliedReverse;

  /// 尚未接入本地输入参与者的底层滚动 delta 拦截链。
  ElScrollDeltaInterceptor? _baseEffectiveInterceptor;

  /// 主轴最终生效的滚动 delta 拦截器。
  ElScrollDeltaInterceptor? _effectiveInterceptor;

  /// 双轴水平轴最终生效的滚动 delta 拦截器；v1 只有 Mixin driver 会安装。
  ElScrollDeltaInterceptor? _effectiveHorizontalInterceptor;

  _ScrollMixinInputLink? _mainMixinInputLink;
  _ScrollMixinInputLink? _horizontalMixinInputLink;
  _ScrollViewScopeElement? _scopeElement;

  Map<ElNestedScrollParent, NestedScrollNode>? _nestedRegions;

  NestedScrollNode _registerNestedRegion(ElNestedScrollParent parent, Axis axis, NestedScrollNode? outer) {
    final node = NestedScrollNode(parent: parent, axis: axis, outer: outer);
    (_nestedRegions ??= <ElNestedScrollParent, NestedScrollNode>{})[parent] = node;
    _scopeElement?.inputChanged();
    return node;
  }

  void _unregisterNestedRegion(ElNestedScrollParent parent) {
    _nestedRegions?.remove(parent)?.detached = true;
    if (_nestedRegions?.isEmpty ?? false) _nestedRegions = null;
    _scopeElement?.inputChanged();
  }

  /// 刷新回位拦截接线件（惰性，生命周期稳定）：refresher 在场时挂链首，
  /// 指示器拉出后回收方向的拖拽先回位再滚动（官方 onNestedPreScroll 语义）；
  /// 原拦截器挂 [RefreshScrollLink.next] 继续生效。
  RefreshScrollLink? _refreshLink;

  /// 主轴保留平台物理与刷新停靠，输入消费统一由实际运动帧分账。
  ScrollPhysics _wrapMainPhysics(ScrollPhysics base) {
    final upgraded = ElBouncingScrollPhysics.upgrade(base).applyTo(const RangeMaintainingScrollPhysics());
    return RefreshDockPhysics(getLink: () => _refreshLink).applyTo(upgraded);
  }

  /// 水平轴基础链：仅保留 bouncing 动量修正升级，不挂 fling 拦截与刷新停靠。
  ScrollPhysics _wrapHorizontalPhysics(ScrollPhysics base) {
    return ElBouncingScrollPhysics.upgrade(base).applyTo(const RangeMaintainingScrollPhysics());
  }

  late SegmentExtentIndex _extentIndex;
  late List<Widget> _childrenSnapshot;

  /// children 结构修订号：每次检测到 child 身份/数量变化（含**原地改同一
  /// List 实例**的形态——此时 sourceChildren identity 不变，单靠 identical
  /// 判不出来）时自增，随 snapshot 下发给 content element，revision 变化即
  /// 禁用增量 reconcile 走全量路径。
  int _childrenRevision = 0;
  double _viewportExtent = 0.0;
  double _scrollOffset = 0.0;
  bool _imageDecodeForward = true;
  int _firstIndex = 0;
  int _lastIndex = 0;

  // 未取得样本前按真实尺寸填窗，零占位不参与窗口索引反查。
  bool get _measuringInitialWindow => !widget.shrinkWrap && !_sectionPlan.isAllResident && !_extentIndex.hasEstimate;
  int? _initialMeasurementIndex;
  SegmentExtentIndex? _initialMeasurementModel;
  double _visibleContentStart = 0.0;
  double _visibleContentEnd = 0.0;
  double _semanticContentStart = 0.0;
  double _semanticContentEnd = 0.0;

  // Measurement environment describes the layout inputs that can change item
  // heights without changing the item list. `_extentEnvironment` is what the
  // current frame is laid out under. `_measuredExtentEnvironment` is the
  // environment that the cached measured extents are known to match.
  _VirtualExtentEnvironment? _extentEnvironment;
  _VirtualExtentEnvironment? _measuredExtentEnvironment;

  /// build 期读到的文本度量输入；layout 回调里组装度量环境时复用。
  TextScaler _buildTextScaler = TextScaler.noScaling;
  TextDirection? _buildTextDirection;
  int _measurementGeneration = 0;
  int? _minimumVisibleLastIndex;
  bool _rangeScheduled = false;
  bool _jumpScheduled = false;
  int _scrollToIndexEpoch = 0;
  Completer<bool>? _scrollToIndexCompleter;
  int? _scrollToIndexAnimatingEpoch;
  bool _scrollCorrectionFrameScheduled = false;
  bool _scrollCorrectionFrameNotify = false;
  bool _extentEnvironmentResetScheduled = false;
  bool _minimumCrossAxisExtentUpdateScheduled = false;
  bool _itemExtentInvalidationScheduled = false;
  ElScrollExtentInvalidation? _pendingItemExtentInvalidation;

  // True while we are deliberately keeping old measured extents alive through
  // a possible layout-environment change until mounted rows prove that their
  // sizes actually changed. This avoids resize jitter, but conservative fill
  // must stay enabled so the viewport never exposes blank space.
  bool _extentEnvironmentDriftedFromMeasured = false;

  bool get _debugExtentEnvironmentDriftedFromMeasured => _extentEnvironmentDriftedFromMeasured;

  double? get _debugMeasuredEnvironmentCrossAxisExtent => _measuredExtentEnvironment?.crossAxisExtent;
  int? _pendingAnchorIndex;
  double _pendingAnchorDelta = 0.0;

  /// 锚点捕获时刻的 pixels。修正应用可能晚 1~2 帧（post-frame 报告 →
  /// 下一帧 frame callback），期间 fling/拖拽还在推进 pixels；应用时把
  /// 「当前 pixels − 捕获 pixels」的位移补回目标值，让修正只补偿模型偏移、
  /// 不回卷用户滚动——否则每次修正都把惯性滚动拉回捕获时刻，表现为
  /// fling 穿越未测量区域时的连续回跳（chat 页 reverse+prepend 形态最重）。
  double _pendingAnchorCapturePixels = 0.0;
  VirtualScrollEdge? _pendingScrollPositionEdge;

  // Selection retention keeps anchor/focus rows mounted while a user extends a
  // selection through a virtual list. These ranges are item-index windows, not
  // text ranges. They are intentionally separate from the visible window.

  // Scrollbar drag has two coordinate systems:
  // - ScrollPosition.pixels is Flutter's synchronous scroll position.
  // - `_scrollbarThumbDragFraction` is the thumb location on the track while
  //   held by the pointer. The mounted window may be derived from this visual
  //   fraction so thumb dragging feels direct, but measured extents are still
  //   applied synchronously and may move the real scroll range.
  //
  // `_scrollbarDragHandledScrollOffset` records the programmatic jump produced
  // from a drag update so the normal scroll listener can ignore that echo once.
  bool _scrollbarDragging = false;
  double? _scrollbarThumbDragFraction;
  double? _scrollbarDragHandledScrollOffset;
  bool _structuralScrollUpdateDeferred = false;
  double? _minimumObservedItemExtent;

  // 普通成员恒常驻；与可见窗口合并后保持 Element，绘制和命中仍按实际位置裁剪。
  final Set<int> _keepAliveIndices = <int>{};

  /// 只有首个 Mixin client 登记后才分配，普通滚动热路径保持 null 短路。
  LinkedHashMap<_ScrollMixinClient, _ScrollMixinClientRegistration>? _mixinClients;
  List<MapEntry<_ScrollMixinClient, _ScrollMixinClientRegistration>>? _mixinObserverCache;
  Map<int, LinkedHashSet<_ScrollMixinClient>>? _mixinItemClientsByIndex;
  List<MapEntry<int, LinkedHashSet<_ScrollMixinClient>>>? _mixinItemBucketCache;
  bool? _mixinItemVisibilityCache;
  Map<int, _ScrollMixinClient>? _mixinStickyOwners;
  _ScrollInputRouter? _inputRouter;
  _ScrollMotionCoordinator? _verticalMotion;
  _ScrollMotionCoordinator? _horizontalMotion;
  Map<Axis, _ScrollInputRoute>? _ancestorInputRoutes;
  Map<Axis, _ScrollMixinAxisState>? _mixinAxisStates;
  int _layoutRevision = 0;
  int _verticalObservationId = 0;
  int _horizontalObservationId = 0;
  int _debugMixinSnapshotBuildCount = 0;
  Map<Axis, _ScrollMetricsSignature>? _mixinMetricsSignatures;
  Set<Axis>? _pendingMixinMetricsAxes;
  bool _mixinMetricsDispatchScheduled = false;
  bool _mixinCallbacksActive = true;
  ScrollPosition? _mixinObservedMainPosition;
  ScrollPosition? _mixinObservedHorizontalPosition;
  bool _mixinMainWasScrolling = false;
  bool _mixinHorizontalWasScrolling = false;

  // sticky 注册表（index → 吸附偏移）：唯一来源是 item client 登记，不再
  // 扫描 Widget 类型。对应 owner 由 [_mixinStickyOwners] 保证单一性。
  final SplayTreeMap<int, double> _stickyByIndex = SplayTreeMap<int, double>();

  /// `_stickyByIndex.keys` 的升序快照，供钉住判定二分；任何 sticky 集合变更
  /// 处置空（见 [_invalidateSortedStickyIndices]）。
  List<int>? _sortedStickyIndicesCache;

  /// 当前应钉住的 sticky index（"最后一个自然位置 <= scroll 主轴起始的
  /// sticky"）。null 表示无。除了正常出现在 mounted 窗口的情形，我们把这个
  /// index 并入 mountedRanges 让它保活，即使自然位置滚出 mounted 窗口后依然
  /// 可以 paint / hit-test。
  int? _pinnedStickyIndex;

  // item snapshot/visibility 与列表 range 共用 post-frame 合并调度。
  ElVisibleRange? _lastVisibleRange;
  bool _visibilityDispatchScheduled = false;
  bool _visibilityDispatchPassRequested = false;

  /// 当前主轴实际使用的控制器：显式 controller 或 State 持有的 fallback。
  ScrollController get controller => _scrollBinding.controller;

  ScrollController get _controller => controller;

  /// 当前主轴真实挂载的滚动位置。
  ScrollPosition get position => _scrollBinding.position;

  /// 双轴模式下实际使用的水平控制器；单轴模式返回 null。
  ScrollController? get horizontalController => _horizontalBinding?.controller;

  /// 双轴模式下真实挂载的水平滚动位置；单轴模式返回 null。
  ScrollPosition? get horizontalPosition => _horizontalBinding?.position;

  /// 当前生效的声明轴；null 表示双轴滚动。
  Axis? get axis => _appliedAxis;

  /// 当前主轴方向，已包含 directionality 与 reverse 的解算结果。
  AxisDirection get axisDirection => _scrollBinding.axisDirection;

  AxisDirection get _axisDirection => axisDirection;

  /// 当前主轴是否反转。
  bool get reverse => _appliedReverse;

  /// 当前主轴是否已经拥有像素值与完整内容尺寸。
  bool get hasContentDimensions => position.hasPixels && position.hasContentDimensions;

  /// 主轴完成布局后返回实时 metrics；布局前返回 null。
  ScrollMetrics? get metrics => hasContentDimensions ? position : null;

  /// 返回指定轴的真实 position；当前宿主不支持该轴时返回 null。
  ScrollPosition? positionFor(Axis axis) {
    if (_appliedAxis == null) {
      return axis == Axis.vertical ? position : horizontalPosition;
    }
    return _layoutAxis == axis ? position : null;
  }

  /// 指定轴完成布局后返回实时 metrics；轴不受支持或尺寸未就绪时返回 null。
  ScrollMetrics? metricsFor(Axis axis) {
    final target = positionFor(axis);
    if (target == null || !target.hasPixels || !target.hasContentDimensions) return null;
    return target;
  }

  /// 布局主轴：双轴模式（_appliedAxis == null）items 仍纵向堆叠、纵向虚拟化。
  Axis get _layoutAxis => _appliedAxis ?? Axis.vertical;

  bool get _isDualAxis => _appliedAxis == null;

  bool get _dragOptimizeEnabled => widget.dragOptimize != false;

  double get _effectiveCacheExtent {
    // 拖 thumb 期间保留一行保护带：位置与窗口更新跨输入/布局相位时，完全
    // 收缩到 0 会偶发少挂相邻整行，形成按住时空白、松手后恢复。只留一行
    // 足以覆盖相位差，又不会恢复成整屏预挂载拖累每帧 build/layout。
    if (_scrollbarDragging) return math.max(0.0, _extentIndex.estimatedExtent + _gap);
    final cacheExtent = widget.cacheExtent;
    if (!cacheExtent.isFinite || cacheExtent <= precisionErrorTolerance) return 0.0;
    return cacheExtent;
  }

  // --- Layout-space mapping (padding + gap) ---
  //
  // The extent index stores pure **row** extents (a row = one list item, or one
  // grid row of N cells). Layout space adds the main-axis leading padding before
  // row 0 and inter-row spacing. All content-offset math in this state runs in
  // layout space over **item** indices; [_sectionPlan] maps item↔row and supplies
  // cumulative spacing (which is excluded from the Fenwick tree so render's
  // "model extent == measured row height" anchor comparison stays exact).
  //
  // Pure-list (no ElGridView.builder member): row == item, spacing == index*gap — the
  // helpers below reduce byte-for-byte to the original list implementation, so
  // list users pay nothing.

  double get _gap => widget.gap;

  /// 段解构产物（解构自 widget.children，didUpdateWidget 期重解构做 diff）。
  late List<SegmentSpec> _segments;

  /// 段计划：虚拟管线恒非 null（散 child 是 StaticSegment、一行一
  /// item；虚拟段窗口化），承载行↔item 映射、间距与交叉轴几何。
  /// 交叉轴宽变化（grid 自动列数输入）由 layout 回调驱动重建。
  late SegmentPlan _sectionPlan;

  /// 扁平 item 视图（喂给快照/reconcile/选区的 List 面）。恒非 null。
  late FlatSegmentItemList _flatChildren;

  /// 整条管线消费的扁平 item 列表（段解构产物的扁平面）。
  List<Widget> get _effectiveChildren => _flatChildren;

  double get _mainAxisLeadingPadding => _layoutAxis == Axis.vertical ? widget.padding.top : widget.padding.left;

  double get _mainAxisPaddingTotal =>
      _layoutAxis == Axis.vertical ? widget.padding.vertical : widget.padding.horizontal;

  /// Full content extent in layout space (padding + rows + inter-row spacing).
  double get _totalLayoutExtent {
    return _mainAxisPaddingTotal + _extentIndex.totalExtent + _sectionPlan.totalSpacing();
  }

  /// Item start position in layout space. 行记账下：item 所在行的行首偏移
  /// （同行所有 cell 共享该主轴起点）。
  double _layoutOffsetOfItem(int index) {
    final plan = _sectionPlan;
    final row = plan.rowOfItem(index);
    return _mainAxisLeadingPadding + _extentIndex.offsetOf(row) + plan.cumulativeSpacingBeforeRow(row);
  }

  /// First item whose end is after [position] (layout space). 纯 list 时 gap
  /// 折进 Fenwick 下降（[SegmentExtentIndex.indexAt]）。行记账时 Fenwick 无
  /// gap（间距在 plan 里），先折返定位行、再取该行首 item——窗口天然整行对齐。
  int _itemIndexAtLayoutOffset(double position) {
    if (_extentIndex.count == 0) return 0;
    final content = position - _mainAxisLeadingPadding;
    if (content < 0.0) return 0;
    final plan = _sectionPlan;
    final row = _extentIndex.rowAtContentOffset(content);
    return row >= plan.totalRowCount ? plan.totalItemCount : plan.firstItemOfRow(row);
  }

  /// First item whose start is at or after [position] (layout space).
  int _firstItemWithLayoutStartAtOrAfter(double position) {
    if (_extentIndex.count == 0) return 0;
    final content = position - _mainAxisLeadingPadding;
    if (content <= 0.0) return 0;
    final plan = _sectionPlan;
    final row = _extentIndex.rowAtContentOffset(content, startAtOrAfter: true);
    return row >= plan.totalRowCount ? plan.totalItemCount : plan.firstItemOfRow(row);
  }

  double get _maxLayoutScrollOffset => math.max(_totalLayoutExtent - _viewportExtent, 0.0);

  @override
  void initState() {
    super.initState();
    // Provider / ScrollConfiguration 都属于 Inherited 依赖，initState 不能建立依赖。
    // 这里只保留 widget 直参的临时值；首帧真实环境值由 didChangeDependencies 补齐。
    final initialRefresher = widget.refresher;
    _selectedRefresher = widget.onRefresh == null || initialRefresher is ElNoRefresher ? null : initialRefresher;
    _appliedController = widget.controller;
    _appliedHorizontalController = widget.horizontalController;
    // 环境物理要查 ScrollConfiguration（InheritedWidget），initState 里查会断言：
    // 这里先按 widget 直参 + el 平台口径落位，首帧真实值由紧随其后的
    // didChangeDependencies 解析补齐（position 到那时才创建，见下）。
    _appliedWidgetPhysics = _effectiveWidgetPhysics;
    _appliedPhysics = _wrapMainPhysics(_effectiveWidgetPhysics);
    _appliedHorizontalPhysics = _wrapHorizontalPhysics(_effectiveWidgetPhysics);
    final initialSmoothScroll = widget.smoothScroll;
    _selectedSmoothScroll = initialSmoothScroll is ElNoSmoothScroll ? null : initialSmoothScroll;
    _appliedAxis = widget.axis;
    _appliedReverse = widget.reverse;
    _baseEffectiveInterceptor = widget.deltaInterceptor;
    _effectiveInterceptor = _baseEffectiveInterceptor;
    _scrollBinding = ScrollPositionBinding<ElScrollView>(
      owner: this,
      vsync: this,
      viewportKey: _viewportKey,
      notificationKey: _notificationKey,
      controller: () => _appliedController,
      physics: () => _appliedPhysics,
      axis: () => _layoutAxis,
      reverse: () => _appliedReverse,
      onIgnorePointerChanged: _applyIgnorePointerToRender,
      onCanDragChanged: _applyCanDragToRender,
      onSemanticsActionsChanged: _applySemanticsActionsToRender,
      onPositionWillChange: _detachMixinPositionListeners,
    );
    _scrollBinding.initState();
    if (_appliedAxis == null) {
      _createHorizontalBinding().initState();
    }
    _rebuildSectionPlan();
    _extentIndex = _createExtentIndex();
    if (_scrollDebugCountersEnabled) {
      _debugCounters!.debugMeasuredItemCountProvider = () => _extentIndex.measuredCount;
    }
    _childrenSnapshot = _flatChildren;
    _segmentsSnapshot = _segments;
    _contentController = _ScrollMountController(_createContentSnapshot());
    widget.minimumCrossAxisExtentListenable?.addListener(_handleMinimumCrossAxisExtentChanged);
    widget.itemExtentInvalidationListenable?.addListener(_handleItemExtentInvalidationChanged);
    _controller.addListener(_handleScrollOffsetChanged);
    _attachIndexBridgeIfNeeded(widget.controller);
    _rebuildResidentIndicesFromSegments();
    _updateInputOrder();
  }

  /// 交叉轴可用宽（grid 列数/固定行高派生输入）：layout 回调喂入，首帧 0。
  double _planCrossAxisExtent = 0.0;

  /// 从 widget.children 重解构段并重建段计划与扁平视图。
  ///
  /// 恒有段模型：散 child = StaticSegment（一行一 item、恒常驻），
  /// 列表配置与网格声明形成窗口化段，其他 box 恒常驻；不支持的 delegate
  /// 在解构层直接报错，不保留隐式布局壳或兼容分支。
  void _rebuildSectionPlan() {
    _segments = resolveScrollSegments(widget.children, scrollAxis: _layoutAxis);
    _rebuildPlanFromSegments();
  }

  /// 用当前 [_segments] 与交叉轴宽重建 plan 与扁平视图（交叉轴 resize 时
  /// 段列表不重解构，仅几何重算）。
  void _rebuildPlanFromSegments({bool geometryOnly = false}) {
    _sectionPlan = SegmentPlan(_segments, outerGap: _gap, crossAxisExtent: _planCrossAxisExtent);
    _flatChildren = geometryOnly ? _flatChildren.withPlan(_sectionPlan) : FlatSegmentItemList(_sectionPlan);
    if (mounted) _flatChildren.attachBuildContext(context);
  }

  /// 同身份列表先继承统一尺寸，首条在声明或环境变化时同帧重测。
  void _inheritFixedSizes(List<SegmentSpec> oldSegments, SegmentListDiff diff) {
    for (final pairing in diff.pairings) {
      final oldIndex = pairing.oldIndex;
      final newIndex = pairing.newIndex;
      if (oldIndex == null || newIndex == null) continue;
      final oldSegment = oldSegments[oldIndex];
      final newSegment = _segments[newIndex];
      if (oldSegment is! LinearSegment || newSegment is! LinearSegment) continue;
      if (oldSegment.key == newSegment.key && oldSegment.fixed?.itemStride == newSegment.fixed?.itemStride) {
        newSegment.fixed?.extent = oldSegment.fixed?.extent;
        newSegment.fixed?.separatorExtent = oldSegment.fixed?.separatorExtent;
      }
    }
  }

  /// index 定位通道：仅 [ElScrollController] 类型的 controller 才建立
  /// 通道；官方 [ScrollController] 用户不受影响。
  void _attachIndexBridgeIfNeeded(ScrollController? controller) {
    if (controller is ElScrollController) controller.attachIndexBridge(this);
  }

  void _detachIndexBridgeIfNeeded(ScrollController? controller) {
    if (controller is ElScrollController) controller.detachIndexBridge(this);
  }

  /// 水平轴 binding：axis 恒 horizontal、reverse false；persistOffset 关掉，
  /// 避免与主轴 binding 共用同一 PageStorage bucket 时互相覆写恢复值。
  ScrollPositionBinding<ElScrollView> _createHorizontalBinding() {
    return _horizontalBinding = ScrollPositionBinding<ElScrollView>(
      owner: this,
      vsync: this,
      viewportKey: _viewportKey,
      notificationKey: _notificationKey,
      controller: () => _appliedHorizontalController,
      physics: () => _appliedHorizontalPhysics,
      axis: () => Axis.horizontal,
      reverse: () => false,
      persistOffset: false,
      onIgnorePointerChanged: _applyIgnorePointerToRender,
      onCanDragChanged: _applyCanDragToRender,
      onSemanticsActionsChanged: _applySemanticsActionsToRender,
      onPositionWillChange: _detachMixinPositionListeners,
    );
  }

  /// diff 基线快照：段解构产物按引用留存（拷贝扁平面会物化 builder 段全量），
  /// 结构 diff 走段级 [SegmentListDiff]，不做逐元素扫描。
  List<SegmentSpec> _segmentsSnapshot = const <SegmentSpec>[];

  void _attachBuilderContext() {
    _flatChildren.attachBuildContext(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncInputTickerMode();
    _selectedRefresher = _resolveRefresher();
    _selectedSmoothScroll = _resolveSmoothScroll();
    // 环境物理（官方 ScrollConfiguration 通道）只能在这里解析：子树换 behavior
    // 后靠这条链跟随（behavior 的 shouldNotify 决定要不要通知我们）。首帧也走
    // 这里——initState 查不到 InheritedWidget。
    _environmentPhysics = _resolveEnvironmentPhysics();
    if (_appliedWidgetPhysics != _effectiveWidgetPhysics) {
      _appliedWidgetPhysics = _effectiveWidgetPhysics;
      _appliedPhysics = _wrapMainPhysics(_effectiveWidgetPhysics);
      _appliedHorizontalPhysics = _wrapHorizontalPhysics(_effectiveWidgetPhysics);
    }
    _scrollBinding.didChangeDependencies();
    _horizontalBinding?.didChangeDependencies();
    _syncMixinPositionListeners();
  }

  // 只监听输入启停，避免页面覆盖时因 InheritedWidget 依赖让整个滚动宿主重建。
  void _syncInputTickerMode() {
    final notifier = TickerMode.getValuesNotifier(context);
    if (identical(notifier, _inputTickerModeNotifier)) return;
    _inputTickerModeNotifier?.removeListener(_handleInputTickerMode);
    _inputTickerModeNotifier = notifier;
    notifier.addListener(_handleInputTickerMode);
    _handleInputTickerMode();
  }

  void _handleInputTickerMode() {
    final enabled = _inputTickerModeNotifier!.value.enabled;
    final reenabled = !_inputTickerEnabled && enabled;
    final disabled = _inputTickerEnabled && !enabled;
    _inputTickerEnabled = enabled;
    if (disabled) _finishAncestorInputRoutes();
    if (reenabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_inputTickerEnabled) return;
        for (final axis in Axis.values) {
          final position = positionFor(axis);
          if (_ancestorRouteFor(axis) != null &&
              position is ScrollEnginePosition &&
              position.outOfRange &&
              position.observedActivity == .idle) {
            position.goBallistic(0);
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(ElScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.deltaInterceptor, widget.deltaInterceptor)) _finishAncestorInputRoutes();
    _updateInputOrder();
    if (!identical(oldWidget.minimumCrossAxisExtentListenable, widget.minimumCrossAxisExtentListenable)) {
      oldWidget.minimumCrossAxisExtentListenable?.removeListener(_handleMinimumCrossAxisExtentChanged);
      widget.minimumCrossAxisExtentListenable?.addListener(_handleMinimumCrossAxisExtentChanged);
      _handleMinimumCrossAxisExtentChanged();
    }
    if (!identical(oldWidget.itemExtentInvalidationListenable, widget.itemExtentInvalidationListenable)) {
      oldWidget.itemExtentInvalidationListenable?.removeListener(_handleItemExtentInvalidationChanged);
      widget.itemExtentInvalidationListenable?.addListener(_handleItemExtentInvalidationChanged);
      _handleItemExtentInvalidationChanged();
    }
    _selectedRefresher = _resolveRefresher();
    _selectedSmoothScroll = _resolveSmoothScroll();
    // 与 refresher / smoothScroll 同口径：widget 更新期也刷一次环境物理。
    // 全量刷新（refreshApp = 整树重建）走的就是这条 didUpdateWidget 链，那时
    // 依赖回调不一定来；换完由下面的结构更新统一落盘（含活动触摸延迟路径）。
    _environmentPhysics = _resolveEnvironmentPhysics();
    if (_scrollDebugCountersEnabled) _debugCounters!.beginDidUpdate();

    // 段计划先于 diff 重建：children 变化可能改变段结构（grid 成员增删、
    // itemCount 变化），diff 与后续 _createExtentIndex 都要读**新** plan——
    // 即使段结构签名不变也用新 plan/facade（list 段成员与 itemBuilder 是新
    // 实例，per-item 更新必须流出）。facade 间的结构 diff 不走逐元素扫描
    // （会物化 grid 段全量），由 [_childChangeSpan] 的 facade 分支按段结构
    // 签名判定。
    final oldPlan = _sectionPlan;
    final oldSegments = _segmentsSnapshot;
    _rebuildSectionPlan();
    _attachBuilderContext();

    // 段级 diff（计划 §5）：未变段的实测行区间在 Fenwick 中原位保留，变化段
    // 折算为升序 row/item splice 序列（从后往前应用）。builder 闭包身份不入
    // 判定；per-item 实例刷新（同结构）由 reconcile 消化。
    final diff = SegmentListDiff.compute(oldSegments, _segments);
    _inheritFixedSizes(oldSegments, diff);
    final transition = diff.anyChange
        ? SegmentPlanTransition.compute(oldPlan: oldPlan, newPlan: _sectionPlan, diff: diff)
        : null;
    _pendingTransition = transition;
    _pendingOldPlan = oldPlan;
    final oldChildren = _childrenSnapshot;
    final childChange = _aggregateItemChangeSpan(transition);

    final oldAppliedAxis = _appliedAxis;
    final oldAppliedReverse = _appliedReverse;
    final structuralUpdateApplied = _applyStructuralScrollUpdate(deferForActiveTouch: true);

    if (structuralUpdateApplied) {
      _handleAppliedStructuralWidgetUpdate(oldChildren, childChange, oldAppliedAxis, oldAppliedReverse);
    } else if (oldChildren.length != _effectiveChildren.length || childChange != null) {
      _handleAppliedStructuralWidgetUpdate(oldChildren, childChange, _appliedAxis, _appliedReverse);
    }
    _flushPendingItemExtentInvalidation();
    _pendingTransition = null;
    _pendingOldPlan = null;
    _childrenSnapshot = _flatChildren;
    _segmentsSnapshot = _segments;

    if (oldWidget.gap != widget.gap || oldWidget.padding != widget.padding) {
      _minimumVisibleLastIndex = null;
      _scheduleScrollClamp();
      _scheduleVisibleRangeUpdate();
    }

    // 列表级回调从无到有：门禁期间没有任何派发，补一次初始 range（清掉
    // 陈旧快照强制发出当前值，保证"进入可见"有对称起点）。
    if (oldWidget.onVisibleRangeChanged == null && widget.onVisibleRangeChanged != null) {
      _lastVisibleRange = null;
      _scheduleVisibilityDispatch();
    }
  }

  ElRefresher? _resolveRefresher() {
    if (widget.onRefresh == null) return null;
    final configured = widget.refresher ?? ElViewProvider.refresherOf(context);
    if (configured is ElNoRefresher) return null;
    return configured;
  }

  ElScrollbar _resolveScrollbar() {
    return widget.scrollbar ?? ElViewProvider.scrollbarOf(context);
  }

  ElSmoothScroll? _resolveSmoothScroll() {
    final configured = widget.smoothScroll ?? ElViewProvider.smoothScrollOf(context);
    if (configured is ElNoSmoothScroll) return null;
    if (configured != null) return configured;
    return resolveDefaultSmoothScroll();
  }

  bool get _hasPendingStructuralScrollUpdate {
    return _appliedController != widget.controller ||
        _appliedHorizontalController != widget.horizontalController ||
        _appliedWidgetPhysics != _effectiveWidgetPhysics ||
        _appliedAxis != widget.axis ||
        _appliedReverse != widget.reverse;
  }

  bool _deferStructuralScrollUpdateIfNeeded() {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderVirtualScrollView) return false;
    final deferred = renderObject.deferStructuralUpdateForActiveTouch(() {
      if (!mounted) return;
      setState(() {
        // 段 diff 已在 didUpdateWidget 期消化（快照即当前）；此处只补
        // controller/physics/axis/reverse 的延迟结构更新。
        final oldChildren = _childrenSnapshot;
        final oldAppliedAxis = _appliedAxis;
        final oldAppliedReverse = _appliedReverse;
        _applyStructuralScrollUpdate(deferForActiveTouch: false);
        _handleAppliedStructuralWidgetUpdate(oldChildren, null, oldAppliedAxis, oldAppliedReverse);
      });
    });
    if (deferred) {
      _structuralScrollUpdateDeferred = true;
    }
    return deferred;
  }

  bool _applyStructuralScrollUpdate({required bool deferForActiveTouch}) {
    if (!_hasPendingStructuralScrollUpdate) {
      _structuralScrollUpdateDeferred = false;
      return true;
    }
    if (deferForActiveTouch) {
      if (_structuralScrollUpdateDeferred || _deferStructuralScrollUpdateIfNeeded()) {
        return false;
      }
    }

    final oldController = _appliedController;
    final oldHorizontalController = _appliedHorizontalController;
    final oldPhysics = _appliedPhysics;
    final oldLayoutAxis = _layoutAxis;
    final wasDual = _appliedAxis == null;
    final oldReverse = _appliedReverse;
    final controllerChanged = oldController != widget.controller;
    if (controllerChanged || _appliedAxis != widget.axis || _appliedReverse != widget.reverse) {
      _cancelScrollToIndexOperation();
    }
    final oldEffectiveController = _scrollBinding.controllerFor(oldController);

    if (controllerChanged) {
      oldEffectiveController.removeListener(_handleScrollOffsetChanged);
      _detachIndexBridgeIfNeeded(oldController);
    }

    _appliedController = widget.controller;
    _appliedHorizontalController = widget.horizontalController;
    _appliedWidgetPhysics = _effectiveWidgetPhysics;
    _appliedPhysics = _wrapMainPhysics(_effectiveWidgetPhysics);
    _appliedHorizontalPhysics = _wrapHorizontalPhysics(_effectiveWidgetPhysics);
    _appliedAxis = widget.axis;
    _appliedReverse = widget.reverse;
    _structuralScrollUpdateDeferred = false;

    _scrollBinding.didUpdateWidget(
      oldController: oldController,
      oldPhysics: oldPhysics,
      oldAxis: oldLayoutAxis,
      oldReverse: oldReverse,
    );

    // 双轴开关热切换：建/销水平轴 binding；持续双轴则透传结构更新。
    final isDual = _appliedAxis == null;
    if (isDual && !wasDual) {
      _createHorizontalBinding()
        ..initState()
        ..didChangeDependencies();
    } else if (!isDual && wasDual) {
      // Render viewport 会在本轮子树更新稍后才收到 horizontalPosition=null；
      // 先摘控制器但保留 position 到同步更新结束，避免 GlobalKey 重挂时监听
      // 已释放对象。
      _horizontalBinding?.disposeAfterTreeUpdate();
      _horizontalBinding = null;
    } else if (isDual) {
      _horizontalBinding!.didUpdateWidget(
        oldController: oldHorizontalController,
        oldPhysics: oldPhysics,
        oldAxis: Axis.horizontal,
        oldReverse: false,
      );
    }

    if (controllerChanged) {
      _controller.addListener(_handleScrollOffsetChanged);
      _attachIndexBridgeIfNeeded(widget.controller);
    }
    _mixinMetricsSignatures?.clear();
    _syncMixinPositionListeners();
    return true;
  }

  void _handleAppliedStructuralWidgetUpdate(
    List<Widget> oldChildren,
    _VirtualChildChangeSpan? childChange,
    Axis? oldAxis,
    bool oldReverse,
  ) {
    final childIdentitiesChanged = childChange != null;
    if (oldAxis != _appliedAxis || oldChildren.length != _effectiveChildren.length || childIdentitiesChanged) {
      _cancelScrollToIndexOperation();
      _childrenRevision++;
      _remapItemConfigForChildChange(childChange);
      // 度量保留只关心布局主轴是否变化：双轴（null）的布局主轴恒 vertical，
      // 传布局投影而非原始 axis 值。
      _resetExtentIndexPreservingAnchor(oldChildren, childChange, previousAxis: oldAxis ?? Axis.vertical);

      // 结构变化（如 chat 到顶 prepend 一批）的锚点修正**同帧落地**：此刻
      // 处于 build 阶段，correctPixels 不通知、不打断惯性，且先于本帧
      // layout——否则本帧会以新模型 + 未修正 pixels 绘制一次（可见跳变），
      // 修正再等到 post-frame jumpTo（打断 fling）。先修正再算可见窗口。
      if (_pendingAnchorIndex != null) _applyPendingScrollCorrection(notify: false);
      _recomputeVisibleRange();
      _scheduleScrollClamp();
    } else if (oldReverse != _appliedReverse) {
      _minimumVisibleLastIndex = null;
      _scheduleVisibleRangeUpdate();
    }
  }

  @override
  void deactivate() {
    // 预测性返回会先失活 Material 祖先，清理滚动活动前必须封闭双轴通知。
    _scrollBinding.suspendContext();
    _horizontalBinding?.suspendContext();
    _cancelScrollToIndexOperation();
    _mixinCallbacksActive = false;
    _finishAncestorInputRoutes();
    _detachMixinPositionListeners();
    _detachIndexBridgeIfNeeded(_appliedController);
    // 结构换壳（外层包 ElView 等重建）时新宿主同帧 attach 同一 controller，
    // 这里先摘挂——等 dispose 才 detach 会在 layout 期撞 "attached to
    // multiple scroll views"（官方 Scrollable 同款 deactivate 语义）。
    _scrollBinding.deactivate();
    _horizontalBinding?.deactivate();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _syncInputTickerMode();
    _scrollBinding.activate();
    _horizontalBinding?.activate();
    _attachIndexBridgeIfNeeded(_appliedController);
    _mixinCallbacksActive = true;
    _syncMixinPositionListeners();
    _syncMixinInputInterceptors();
  }

  @override
  void dispose() {
    _inputTickerModeNotifier?.removeListener(_handleInputTickerMode);
    _inputTickerModeNotifier = null;
    _stretch?.dispose();
    _cancelScrollToIndexOperation();
    _mixinCallbacksActive = false;
    _detachMixinPositionListeners();
    _detachAllMixinClients();
    widget.minimumCrossAxisExtentListenable?.removeListener(_handleMinimumCrossAxisExtentChanged);
    widget.itemExtentInvalidationListenable?.removeListener(_handleItemExtentInvalidationChanged);
    _detachIndexBridgeIfNeeded(_appliedController);
    _controller.removeListener(_handleScrollOffsetChanged);
    _scrollBinding.dispose();
    _horizontalBinding?.dispose();
    _contentController.dispose();
    _scrollbarController?.dispose();
    super.dispose();
  }

  _ScrollMixinClientRegistration _resolveMixinClientRegistration(_ScrollMixinClient client) {
    final clientAxis = client._scrollAxis ?? _layoutAxis;
    if (positionFor(clientAxis) == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('滚动 Mixin client 请求了宿主不支持的轴。'),
        ErrorDescription(
          '${client.runtimeType} 请求 $clientAxis，但当前 ${widget.runtimeType} '
          '只支持 ${axis ?? _layoutAxis}。',
        ),
      ]);
    }
    final requestedIndex = client._scrollItemIndex;
    final requestedIdentity = client._scrollItemIdentity;
    final requestedStickyOffset = client.scrollItemStickyOffset;
    final hasValidItem =
        requestedIndex != null &&
        requestedIdentity != null &&
        requestedIndex >= 0 &&
        requestedIndex < _effectiveChildren.length;
    if (requestedStickyOffset != null && !hasValidItem) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('sticky Mixin 必须位于 ElScrollView 的直接 item scope 中。'),
        ErrorDescription('${client.runtimeType} 已找到滚动宿主，但当前 State 不是一个滚动成员。'),
        ErrorHint('把 sticky 行为混入 ElScrollView.children 或 List/Grid 条目 返回值的根 State。'),
      ]);
    }
    final stickyOffset = hasValidItem ? requestedStickyOffset : null;
    if (stickyOffset != null && !stickyOffset.isFinite) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('stickyOffset 必须是有限数值。'),
        ErrorDescription('${client.runtimeType} 在 item $requestedIndex 返回了 $stickyOffset。'),
      ]);
    }
    final declaredTracks = client._effectTracks;
    final tracks = declaredTracks.isEmpty
        ? const <ElScrollEffectTrack>[]
        : List<ElScrollEffectTrack>.unmodifiable(declaredTracks);
    if (tracks.isNotEmpty) {
      if (positionFor(clientAxis) is! ScrollEnginePosition) {
        throw FlutterError('效果协同运动需要默认控制器或 ElScrollController，当前自定义 position 未提供受控运动接线。');
      }
      final ids = <Object>{};
      for (final track in tracks) {
        if (!ids.add(track.effectId)) throw FlutterError('同一个 State 不能重复声明效果身份 ${track.effectId}。');
        track._validate();
        if (track.pixelsPerUnit > 0 && client.scrollInputSlot == null) {
          throw FlutterError('声明输入行程的效果 ${track.effectId} 必须同时提供 scrollInputSlot。');
        }
      }
    }
    return _ScrollMixinClientRegistration(
      axis: clientAxis,
      itemIndex: hasValidItem ? requestedIndex : null,
      itemIdentity: hasValidItem ? requestedIdentity : null,
      wantsScrollUpdates: client.wantsScrollUpdates,
      wantsViewportUpdates: client.wantsViewportUpdates,
      wantsScrollSessions: client is ElScrollMixin && client.observesScrollSessions,
      wantsScrollItemUpdates: hasValidItem && client.wantsScrollItemUpdates,
      wantsScrollItemSize: hasValidItem && client is ElScrollMixin && client.observesScrollItemSize,
      preserveItemAnchor: client is! ElScrollMixin || client.scrollItemPreserveAnchor,
      viewportHeader: hasValidItem && client is ElScrollMixin && client.scrollItemViewportHeader,
      tracksScrollItemVisibility: hasValidItem && client.tracksScrollItemVisibility,
      tracksScrollItemVisibleFraction:
          hasValidItem && client.tracksScrollItemVisibility && client.tracksScrollItemVisibleFraction,
      stickyOffset: stickyOffset,
      scrollInputSlot: client.scrollInputSlot,
      effectTracks: tracks,
    );
  }

  void _validateMixinStickyOwner(_ScrollMixinClient client, _ScrollMixinClientRegistration registration) {
    final index = registration.itemIndex;
    if (index == null || registration.stickyOffset == null) return;
    final existing = _mixinStickyOwners?[index];
    if (existing == null || identical(existing, client)) return;
    final existingRegistration = _mixinClients?[existing];
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('同一滚动 item 只能登记一个 sticky owner。'),
      ErrorDescription(
        'item index：$index\n'
        'item identity：${registration.itemIdentity}\n'
        '已登记：${existing.runtimeType}（${existingRegistration?.itemIdentity}）\n'
        '重复登记：${client.runtimeType}\n'
        '宿主：${widget.toStringShort()}',
      ),
      ErrorHint('多个 sticky 视觉或算法应混入同一个 item State，通过同一个 client handle 组合。'),
    ]);
  }

  void _attachMixinItemRegistration(
    _ScrollMixinClient client,
    _ScrollMixinClientRegistration registration, {
    Set<int>? changedIndices,
    bool captureSnapshot = true,
  }) {
    _mixinObserverCache = null;
    _mixinItemBucketCache = null;
    _mixinItemVisibilityCache = null;
    final index = registration.itemIndex;
    if (index == null) return;
    if (registration.participatesInItemDispatch) {
      final buckets = _mixinItemClientsByIndex ??= <int, LinkedHashSet<_ScrollMixinClient>>{};
      (buckets[index] ??= LinkedHashSet<_ScrollMixinClient>.identity()).add(client);
    }
    if (registration.viewportHeader) {
      final headers = _viewportHeaderOwners ??= {};
      if (headers[index] != null && !identical(headers[index], client)) {
        throw FlutterError('同一滚动成员只能声明一个视口头部。');
      }
      headers[index] = client;
      _keepAliveIndices.add(index);
      changedIndices?.add(index);
    }
    final stickyOffset = registration.stickyOffset;
    if (stickyOffset != null) {
      (_mixinStickyOwners ??= <int, _ScrollMixinClient>{})[index] = client;
      if (_stickyByIndex[index] != stickyOffset) {
        _stickyByIndex[index] = stickyOffset;
        _invalidateSortedStickyIndices();
        changedIndices?.add(index);
      }
    }
    if (captureSnapshot) registration.lastItemSnapshot = _buildScrollItemSnapshot(index);
  }

  void _detachMixinItemRegistration(
    _ScrollMixinClient client,
    _ScrollMixinClientRegistration registration, {
    Set<int>? changedIndices,
  }) {
    _mixinObserverCache = null;
    _mixinItemBucketCache = null;
    _mixinItemVisibilityCache = null;
    final index = registration.itemIndex;
    if (index == null) return;
    final bucket = _mixinItemClientsByIndex?[index];
    bucket?.remove(client);
    if (bucket?.isEmpty ?? false) _mixinItemClientsByIndex!.remove(index);
    if (_mixinItemClientsByIndex?.isEmpty ?? false) _mixinItemClientsByIndex = null;
    if (identical(_viewportHeaderOwners?[index], client)) {
      _viewportHeaderOwners!.remove(index);
      if (_viewportHeaderOwners!.isEmpty) _viewportHeaderOwners = null;
      _rebuildResidentIndicesFromSegments();
      changedIndices?.add(index);
    }
    if (identical(_mixinStickyOwners?[index], client)) {
      _mixinStickyOwners!.remove(index);
      if (_mixinStickyOwners!.isEmpty) _mixinStickyOwners = null;
      if (_stickyByIndex.remove(index) != null) {
        _invalidateSortedStickyIndices();
        changedIndices?.add(index);
      }
    }
  }

  void _finishMixinItemRegistrationChange(Set<int> changedIndices) {
    if (changedIndices.isNotEmpty) {
      for (final index in changedIndices) {
        _contentController.refreshParentDataForIndex(index);
      }
      final update = _recomputeVisibleRangeWithDetail();
      if (update.anyChanged) _applyVisibleRangeUpdate(update);
    }
    _scheduleVisibilityDispatch();
  }

  void _registerMixinClient(_ScrollMixinClient client) {
    final existing = _mixinClients?[client];
    if (existing != null) {
      _updateMixinClient(client);
      return;
    }
    final registration = _resolveMixinClientRegistration(client);
    _validateMixinStickyOwner(client, registration);
    final clients = _mixinClients ??= LinkedHashMap<_ScrollMixinClient, _ScrollMixinClientRegistration>.identity();
    final changedItemIndices = <int>{};
    clients[client] = registration;
    _attachMixinItemRegistration(client, registration, changedIndices: changedItemIndices);
    _ensureMixinAxisSnapshot(registration.axis);
    _syncMixinPositionListeners();
    _syncMixinInputInterceptors();
    try {
      client.attachToScrollView(this);
    } catch (_) {
      _detachMixinItemRegistration(client, registration, changedIndices: changedItemIndices);
      clients.remove(client);
      if (clients.isEmpty) _mixinClients = null;
      _discardUnusedMixinAxisState(registration.axis);
      _syncMixinPositionListeners();
      _syncMixinInputInterceptors();
      _finishMixinItemRegistrationChange(changedItemIndices);
      rethrow;
    }
    _invalidateInputConfiguration(
      registration.scrollInputSlot,
      tracks: registration.effectTracks.isNotEmpty,
      sessions: registration.wantsScrollSessions,
    );
    _finishMixinItemRegistrationChange(changedItemIndices);
    if (registration.wantsViewportUpdates) {
      _scheduleMixinMetricsDispatch(registration.axis, force: true);
    }
  }

  void _updateMixinClient(_ScrollMixinClient client) {
    if (_inputRouter?.deferUpdate(client) ?? false) return;
    if (client is ElNestedScrollMixin) client._syncNestedRegion();
    final clients = _mixinClients;
    final previous = clients?[client];
    if (clients == null || previous == null) {
      _registerMixinClient(client);
      return;
    }
    final next = _resolveMixinClientRegistration(client);
    if (next == previous) return;
    if (client is ElScrollMixin && (next.axis != previous.axis || !next.wantsScrollSessions)) {
      client._sessionSubscription?.cancel();
    }
    next.inheritDispatchState(previous);
    _validateMixinStickyOwner(client, next);
    final changedItemIndices = <int>{};
    _detachMixinItemRegistration(client, previous, changedIndices: changedItemIndices);
    clients[client] = next;
    _attachMixinItemRegistration(client, next, changedIndices: changedItemIndices);
    _ensureMixinAxisSnapshot(next.axis, resetDelta: previous.axis != next.axis);
    if (previous.axis != next.axis || previous.wantsViewportUpdates != next.wantsViewportUpdates) {
      _mixinMetricsSignatures?.remove(previous.axis);
      _mixinMetricsSignatures?.remove(next.axis);
    }
    if (previous.axis != next.axis) _discardUnusedMixinAxisState(previous.axis);
    _syncMixinPositionListeners();
    _syncMixinInputInterceptors();
    _invalidateInputConfiguration(
      previous.scrollInputSlot ?? next.scrollInputSlot,
      tracks: previous.effectTracks.isNotEmpty || next.effectTracks.isNotEmpty,
      sessions: previous.wantsScrollSessions || next.wantsScrollSessions,
    );
    _finishMixinItemRegistrationChange(changedItemIndices);
    if (next.wantsViewportUpdates && (!previous.wantsViewportUpdates || previous.axis != next.axis)) {
      _scheduleMixinMetricsDispatch(next.axis, force: true);
    }
  }

  void _unregisterMixinClient(_ScrollMixinClient client) {
    final clients = _mixinClients;
    final registration = clients?.remove(client);
    if (clients == null || registration == null) return;
    final changedItemIndices = <int>{};
    _detachMixinItemRegistration(client, registration, changedIndices: changedItemIndices);
    if (clients.isEmpty) _mixinClients = null;
    if (!_hasMixinViewportClient(registration.axis)) {
      _mixinMetricsSignatures?.remove(registration.axis);
      _pendingMixinMetricsAxes?.remove(registration.axis);
    }
    _discardUnusedMixinAxisState(registration.axis);
    _syncMixinPositionListeners();
    _syncMixinInputInterceptors();
    _invalidateInputConfiguration(
      registration.scrollInputSlot,
      tracks: registration.effectTracks.isNotEmpty,
      sessions: registration.wantsScrollSessions,
    );
    _finishMixinItemRegistrationChange(changedItemIndices);
    client.detachFromScrollView(this);
  }

  void _detachAllMixinClients() {
    final clients = _mixinClients;
    if (clients == null) return;
    final snapshot = clients.keys.toList(growable: false);
    _mixinClients = null;
    _mixinObserverCache = null;
    _mixinItemBucketCache = null;
    _mixinItemVisibilityCache = null;
    _viewportHeaderOwners = null;
    _mixinItemClientsByIndex = null;
    _mixinStickyOwners = null;
    _stickyByIndex.clear();
    _pinnedStickyIndex = null;
    _invalidateSortedStickyIndices();
    _inputRouter = null;
    _mixinAxisStates = null;
    _mixinMetricsSignatures = null;
    _pendingMixinMetricsAxes = null;
    _syncMixinInputInterceptors();
    for (final client in snapshot) {
      client.detachFromScrollView(this);
    }
  }

  bool _hasMixinClientForAxis(Axis axis) => _mixinClients?.values.any((entry) => entry.axis == axis) ?? false;

  // 登记变化时才筛选；子项几何预设不参加逐帧全局观察扫描。
  List<MapEntry<_ScrollMixinClient, _ScrollMixinClientRegistration>> get _mixinObservers => _mixinObserverCache ??=
      _mixinClients?.entries
          .where((entry) => entry.value.wantsScrollUpdates || entry.value.wantsViewportUpdates)
          .toList(growable: false) ??
      const [];

  bool _hasMixinScrollClient(Axis axis) =>
      _mixinObservers.any((entry) => entry.value.axis == axis && entry.value.wantsScrollUpdates);

  bool _hasMixinViewportClient(Axis axis) =>
      _mixinObservers.any((entry) => entry.value.axis == axis && entry.value.wantsViewportUpdates);

  bool get _hasMixinItemVisibilityClients => _mixinItemVisibilityCache ??=
      _mixinClients?.values.any((entry) => entry.itemIndex != null && entry.tracksScrollItemVisibility) ?? false;

  // 只缓存桶的顺序，桶内成员仍在轮到该桶时取快照，保留回调期间增删登记的生效顺序。
  List<MapEntry<int, LinkedHashSet<_ScrollMixinClient>>> get _mixinItemBuckets =>
      _mixinItemBucketCache ??= _mixinItemClientsByIndex?.entries.toList(growable: false) ?? const [];

  bool _rowPreservesAnchor(int row) {
    final buckets = _mixinItemClientsByIndex;
    if (buckets == null) return true;
    final first = _sectionPlan.firstItemOfRow(row);
    final count = _sectionPlan.itemsInRow(row);
    for (var index = first; index < first + count; index++) {
      final clients = buckets[index];
      if (clients == null) continue;
      for (final client in clients) {
        if (_mixinClients?[client]?.preserveItemAnchor == false) return false;
      }
    }
    return true;
  }

  /// 只有未实测的虚拟成员需要估高补偿，常驻新成员属于真实内容增量。
  bool _rowUsesEstimatedExtent(int row) =>
      !_extentIndex.isMeasured(row) &&
      !widget.shrinkWrap &&
      !_sectionPlan.segments[_sectionPlan.segmentOfRow(row)].resident;

  /// 真实尺寸变化仅在显式保位时补偿，环境重测与虚拟估高仍保留原有修正。
  bool _shouldAnchorMeasurement(int row, {required bool environmentChanged}) =>
      _rowPreservesAnchor(row) && (widget.preserveAnchor || environmentChanged || _rowUsesEstimatedExtent(row));

  ScrollController? _controllerForMixinAxis(Axis axis) {
    if (_isDualAxis) {
      return axis == Axis.vertical ? controller : horizontalController;
    }
    return _layoutAxis == axis ? controller : null;
  }

  ElScrollSnapshot _ensureMixinAxisSnapshot(Axis axis, {bool resetDelta = false}) {
    final states = _mixinAxisStates ??= <Axis, _ScrollMixinAxisState>{};
    final state = states.putIfAbsent(axis, _ScrollMixinAxisState.new);
    final target = positionFor(axis);
    final positionChanged = !identical(state.position, target);
    if (!resetDelta && !positionChanged && state.snapshot.attached) return state.snapshot;
    state.position = target;
    state.readSnapshot = null;
    state.snapshot = _buildMixinSnapshot(axis, target, state, resetDelta: resetDelta || positionChanged);
    return state.snapshot;
  }

  ElScrollSnapshot _currentMixinSnapshotFor(Axis axis) {
    return _ensureMixinAxisSnapshot(axis);
  }

  int _bindingGenerationFor(Axis axis) =>
      axis == _layoutAxis ? _scrollBinding.generation : _horizontalBinding?.generation ?? 0;

  int _takeMixinSampleId(Axis axis) => axis == Axis.vertical ? ++_verticalObservationId : ++_horizontalObservationId;

  ElScrollSnapshot _readMixinSnapshotFor(Axis axis) {
    final dispatched = _ensureMixinAxisSnapshot(axis);
    final state = _mixinAxisStates![axis]!;
    final snapshot = state.readSnapshot ?? dispatched;
    final target = positionFor(axis);
    if (target == null) return ElScrollSnapshot.detached;
    final ready = target.hasPixels && target.hasContentDimensions;
    final stamp = ScrollInputTransaction.current?.timeStamp ?? SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final sampleVelocity = target is ScrollEnginePosition ? target.motionVelocityAt(stamp) : null;
    if (snapshot.bindingGeneration == _bindingGenerationFor(axis) &&
        snapshot.layoutRevision == _layoutRevision &&
        snapshot.sessionId == (target is ScrollEnginePosition ? target.observedSessionId : null) &&
        (snapshot.velocitySource == ElScrollVelocitySource.frameEstimate
            ? snapshot.velocity == sampleVelocity
            : sampleVelocity == null) &&
        snapshot.hasMetrics == ready &&
        snapshot.rawPixels == (target.hasPixels ? target.pixels : 0) &&
        snapshot.axisDirection == target.axisDirection &&
        (!ready ||
            (snapshot.minScrollExtent == target.minScrollExtent &&
                snapshot.maxScrollExtent == target.maxScrollExtent &&
                snapshot.viewportExtent == target.viewportDimension)) &&
        snapshot.activity == _resolveMixinActivity(axis, target, _mixinAxisStates?[axis]?.explicitActivity)) {
      return snapshot;
    }
    // 未订阅期间没有连续历史：补读当前值，不把跨观察窗口差分冒充本次运动。
    // 读取可能先于 position 的宿主监听器执行，不能提前消耗事件差分及待提交修正。
    return state.readSnapshot = _buildMixinSnapshot(axis, target, state, resetDelta: true, consumeCorrections: false);
  }

  /// 实测和锚点修正单独记账，避免下次观察把它误归因于用户运动。
  void _recordMixinLayoutCorrection(Axis axis, double pixelsDelta) {
    if (pixelsDelta == 0 || !_mixinCallbacksActive || _mixinClients == null) return;
    final state = _mixinAxisStates?[axis];
    if (state == null) return;
    state.pendingCorrectionPixels += pixelsDelta;
    _scheduleMixinMetricsDispatch(axis, force: true);
  }

  ElScrollItemSnapshot _currentMixinItemSnapshotFor(_ScrollMixinClient client) {
    final registration = _mixinClients?[client];
    final index = registration?.itemIndex;
    if (registration == null || index == null) return ElScrollItemSnapshot.detached;
    final snapshot = _buildScrollItemSnapshot(index);
    registration.lastItemSnapshot = snapshot;
    return snapshot;
  }

  ElScrollItemSnapshot _buildScrollItemSnapshot(int index) {
    if (_scrollDebugCountersEnabled) _debugCounters!.debugItemSnapshotBuildCount++;
    final count = _effectiveChildren.length;
    if (index < 0 || index >= count) return ElScrollItemSnapshot.detached;
    final item = _mountedItemRender(index);
    final data = item?.parentData as _ScrollViewportParentData?;
    if (item != null && item.hasSize && (data!.isPositionedForLayout || data.isViewportHeader)) {
      final viewport = item.parent! as _RenderVirtualViewport;
      final vertical = _layoutAxis == Axis.vertical;
      final viewportExtent = vertical ? viewport.size.height : viewport.size.width;
      final itemExtent = vertical ? item.size.height : item.size.width;
      final offset = viewport._childPresentationOffset(item, null);
      final leading = vertical ? offset.dy : offset.dx;
      final intersection = (offset & item.size).intersect(Offset.zero & viewport.size);
      final visible = data.zIndex >= 0 && !intersection.isEmpty;
      final visibleExtent = visible ? (vertical ? intersection.height : intersection.width) : 0.0;
      return ElScrollItemSnapshot(
        attached: true,
        index: index,
        layoutSize: item.size,
        itemExtent: itemExtent,
        viewportExtent: viewportExtent,
        leadingOffset: leading,
        trailingOffset: leading + itemExtent - viewportExtent,
        visibleExtent: visibleExtent,
        visibleFraction: itemExtent <= precisionErrorTolerance ? 0.0 : (visibleExtent / itemExtent).clamp(0.0, 1.0),
        viewProgress: viewportExtent + itemExtent <= precisionErrorTolerance
            ? 0.0
            : ((viewportExtent - leading) / (viewportExtent + itemExtent)).clamp(0.0, 1.0),
        isVisible: visible,
        isMounted: true,
        isSticky: false,
        isPinned: data.isViewportHeader,
      );
    }
    final headerExtent = _viewportHeaderExtent;
    final viewportExtent = math.max(_viewportExtent - headerExtent, 0.0);
    final itemExtent = math.max(_rowExtentOfItem(index), 0.0);
    final leadingOffset = _layoutOffsetOfItem(index) - _contentScrollOffset() - headerExtent;
    final trailingOffset = leadingOffset + itemExtent - viewportExtent;
    final overlapStart = math.max(leadingOffset, 0.0);
    final overlapEnd = math.min(leadingOffset + itemExtent, viewportExtent);
    final visibleExtent = data != null && data.zIndex < 0 ? 0.0 : math.max(overlapEnd - overlapStart, 0.0);
    final visibleFraction = itemExtent <= precisionErrorTolerance
        ? 0.0
        : (visibleExtent / itemExtent).clamp(0.0, 1.0).toDouble();
    final travel = viewportExtent + itemExtent;
    final viewProgress = travel <= precisionErrorTolerance
        ? 0.0
        : ((viewportExtent - leadingOffset) / travel).clamp(0.0, 1.0).toDouble();
    return ElScrollItemSnapshot(
      attached: true,
      index: index,
      layoutSize: item != null && item.hasSize ? item.size : null,
      itemExtent: itemExtent,
      viewportExtent: viewportExtent,
      leadingOffset: leadingOffset,
      trailingOffset: trailingOffset,
      visibleExtent: visibleExtent,
      visibleFraction: visibleFraction,
      viewProgress: viewProgress,
      isVisible: visibleExtent > precisionErrorTolerance,
      isMounted: _isScrollItemMounted(index),
      isSticky: _stickyByIndex.containsKey(index),
      isPinned: _pinnedStickyIndex == index,
    );
  }

  RenderBox? _mountedItemRender(int index) {
    final element = _contentController._element;
    final key = element?._keyByIndex[index];
    final render = key == null ? null : element?._childByKey[key]?.renderObject;
    return render is RenderBox && render.parentData is _ScrollViewportParentData ? render : null;
  }

  bool _itemPresentationDispatchScheduled = false;

  void _scheduleItemPresentationDispatch() {
    if (_itemPresentationDispatchScheduled || (_mixinItemClientsByIndex?.isEmpty ?? true)) return;
    _itemPresentationDispatchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _itemPresentationDispatchScheduled = false;
      if (!mounted || !_mixinCallbacksActive) return;
      _dispatchMixinItemSnapshots();
      _scheduleVisibilityDispatch();
    });
  }

  bool _isScrollItemMounted(int index) {
    if (index >= _firstIndex && index < _lastIndex) return true;
    if (_keepAliveIndices.contains(index) || _pinnedStickyIndex == index) return true;
    return _contentController._element?._builderKeepAliveIndices.contains(index) ?? false;
  }

  bool _shouldDispatchScrollItemSnapshot(_ScrollMixinClientRegistration registration, ElScrollItemSnapshot next) {
    final previous = registration.lastItemSnapshot;
    if (!previous.attached || previous.index != next.index) return true;
    if (previous.layoutSize != next.layoutSize) return true;
    if (previous.isPinned != next.isPinned ||
        previous.isSticky != next.isSticky ||
        previous.isMounted != next.isMounted ||
        previous.itemExtent != next.itemExtent ||
        previous.viewportExtent != next.viewportExtent) {
      return true;
    }
    if (!registration.wantsScrollItemUpdates) return false;
    if (previous.isVisible || next.isVisible) return previous != next;
    return previous.viewProgress != next.viewProgress;
  }

  ({ElScrollSnapshot previous, ElScrollSnapshot current, ScrollPosition position})? _refreshMixinSnapshot(
    Axis axis, {
    bool resetDelta = false,
    ElScrollUpdateCause observationCause = ElScrollUpdateCause.unknown,
    double? sampledMotionDelta,
  }) {
    final target = positionFor(axis);
    if (target == null) return null;
    final states = _mixinAxisStates ??= <Axis, _ScrollMixinAxisState>{};
    final state = states.putIfAbsent(axis, _ScrollMixinAxisState.new);
    final previous = state.snapshot;
    final positionChanged = !identical(state.position, target);
    state.position = target;
    state.readSnapshot = null;
    final current = state.snapshot = _buildMixinSnapshot(
      axis,
      target,
      state,
      resetDelta: resetDelta || positionChanged,
      observationCause: observationCause,
      sampledMotionDelta: sampledMotionDelta,
    );
    return (previous: previous, current: current, position: target);
  }

  ElScrollSnapshot _buildMixinSnapshot(
    Axis axis,
    ScrollPosition? target,
    _ScrollMixinAxisState state, {
    required bool resetDelta,
    bool consumeCorrections = true,
    ElScrollUpdateCause observationCause = ElScrollUpdateCause.unknown,
    double? sampledMotionDelta,
  }) {
    if (target == null) return ElScrollSnapshot.detached;
    if (_scrollDebugCountersEnabled) _debugMixinSnapshotBuildCount++;
    final previous = state.snapshot;
    final hasPixels = target.hasPixels;
    final hasMetrics = hasPixels && target.hasContentDimensions;
    final axisDirection = target.axisDirection;
    final reversed = axisDirectionIsReversed(axisDirection);
    final rawPixels = hasPixels ? target.pixels : 0.0;
    final minExtent = hasMetrics ? target.minScrollExtent : 0.0;
    final maxExtent = hasMetrics ? target.maxScrollExtent : 0.0;
    final range = math.max(maxExtent - minExtent, 0.0);
    final visualRawOffset = !hasMetrics
        ? 0.0
        : reversed
        ? maxExtent - rawPixels
        : rawPixels - minExtent;
    final offset = visualRawOffset.clamp(0.0, range).toDouble();
    final leadingOverscroll = hasMetrics ? math.max(-visualRawOffset, 0.0) : 0.0;
    final trailingOverscroll = hasMetrics ? math.max(visualRawOffset - range, 0.0) : 0.0;
    final coordinateReset =
        resetDelta ||
        !previous.hasMetrics ||
        !hasMetrics ||
        previous.bindingGeneration != _bindingGenerationFor(axis) ||
        previous.axis != axis ||
        previous.axisDirection != axisDirection ||
        previous.minScrollExtent != minExtent ||
        (reversed && previous.maxScrollExtent != maxExtent);
    final correctionPixels = resetDelta ? 0.0 : state.pendingCorrectionPixels;
    if (consumeCorrections) state.pendingCorrectionPixels = 0;
    final offsetDelta = coordinateReset ? 0.0 : offset - previous.contentOffset;
    final correctionDelta = coordinateReset
        ? 0.0
        : sampledMotionDelta != null
        ? offsetDelta - sampledMotionDelta
        : observationCause == ElScrollUpdateCause.layoutCorrection
        ? offsetDelta
        : (previous.rawContentOffset + (reversed ? -correctionPixels : correctionPixels)).clamp(0.0, range) -
              previous.contentOffset;
    final motionDelta = offsetDelta - correctionDelta;
    final activity = _resolveMixinActivity(axis, target, state.explicitActivity);
    final cause =
        (!resetDelta && coordinateReset && previous.hasMetrics) ||
            correctionPixels != 0 ||
            correctionDelta.abs() > precisionErrorTolerance ||
            observationCause == ElScrollUpdateCause.layoutCorrection
        ? ElScrollUpdateCause.layoutCorrection
        : observationCause != ElScrollUpdateCause.unknown
        ? observationCause
        : switch (state.explicitActivity) {
            ElScrollActivityType.touchDrag ||
            ElScrollActivityType.trackpad ||
            ElScrollActivityType.pointerScroll ||
            ElScrollActivityType.scrollbarDrag => ElScrollUpdateCause.userInput,
            _ => target is ScrollEnginePosition ? target.observedCause : ElScrollUpdateCause.unknown,
          };
    final stamp = ScrollInputTransaction.current?.timeStamp ?? SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final sampleVelocity = target is ScrollEnginePosition ? target.motionVelocityAt(stamp) : null;
    final double? velocity =
        sampleVelocity ??
        (motionDelta.abs() > precisionErrorTolerance
            ? null
            : hasMetrics && activity == ElScrollActivityType.idle
            ? 0.0
            : null);
    final direction = motionDelta > precisionErrorTolerance
        ? ElScrollTravelDirection.towardEnd
        : motionDelta < -precisionErrorTolerance
        ? ElScrollTravelDirection.towardStart
        : ElScrollTravelDirection.idle;
    return ElScrollSnapshot(
      attached: true,
      hasMetrics: hasMetrics,
      axis: axis,
      axisDirection: axisDirection,
      bindingGeneration: _bindingGenerationFor(axis),
      layoutRevision: _layoutRevision,
      sampleId: _takeMixinSampleId(axis),
      sessionId: target is ScrollEnginePosition ? target.observedSessionId : null,
      timeStamp: stamp,
      reverse: reversed,
      contentOffset: offset,
      rawPixels: rawPixels,
      rawContentOffset: visualRawOffset,
      motionDelta: motionDelta,
      correctionDelta: correctionDelta,
      coordinateReset: coordinateReset,
      cause: cause,
      velocitySource: sampleVelocity != null
          ? ElScrollVelocitySource.frameEstimate
          : velocity == 0
          ? ElScrollVelocitySource.stationary
          : ElScrollVelocitySource.unknown,
      velocity: velocity,
      direction: direction,
      activity: activity,
      viewportExtent: hasMetrics ? target.viewportDimension : 0.0,
      minScrollExtent: minExtent,
      maxScrollExtent: maxExtent,
      leadingOverscroll: leadingOverscroll,
      trailingOverscroll: trailingOverscroll,
      atStart: hasMetrics && offset <= precisionErrorTolerance,
      atEnd: hasMetrics && range - offset <= precisionErrorTolerance,
    );
  }

  ElScrollActivityType _resolveMixinActivity(
    Axis axis,
    ScrollPosition position,
    ElScrollActivityType? explicitActivity,
  ) {
    if (axis == _layoutAxis && _scrollbarDragging) return ElScrollActivityType.scrollbarDrag;
    if (explicitActivity != null) return explicitActivity;
    final renderObject = _activeMixinViewportRenderObject();
    if (renderObject != null && renderObject.hasActivePointerScrollActivityOn(axis)) {
      return ElScrollActivityType.pointerScroll;
    }
    if (position is ScrollEnginePosition) return position.observedActivity;
    if (!position.isScrollingNotifier.value) return ElScrollActivityType.idle;
    // 普通外部 position 未提供活动所有权接线时保留未知，不能靠滚动方向猜来源。
    return ElScrollActivityType.unknown;
  }

  void _discardUnusedMixinAxisState(Axis axis) {
    if (_hasMixinClientForAxis(axis)) return;
    _mixinAxisStates?.remove(axis);
    if (_mixinAxisStates?.isEmpty ?? false) {
      _mixinAxisStates = null;
    }
  }

  _ScrollMixinInputLink _mixinInputLinkFor(Axis axis) {
    if (axis == _layoutAxis) {
      final link = _mainMixinInputLink ??= _ScrollMixinInputLink(host: this, axis: axis);
      link.axis = axis;
      return link;
    }
    final link = _horizontalMixinInputLink ??= _ScrollMixinInputLink(host: this, axis: axis);
    link.axis = axis;
    return link;
  }

  void _updateInputOrder() {
    if (_inputRouter == null && widget.inputOrder.isEmpty) return;
    (_inputRouter ??= _ScrollInputRouter(this)).setOrder(widget.inputOrder);
  }

  void _invalidateInputConfiguration(Object? changedSlot, {bool tracks = false, bool sessions = false}) {
    if (changedSlot == null && !tracks && !sessions) return;
    final router = _inputRouter ??= _ScrollInputRouter(this);
    router.setOrder(widget.inputOrder);
    router.invalidate();
  }

  void _syncMixinInputInterceptors() {
    if (widget.deltaInterceptor != null && position is! ScrollEnginePosition) {
      throw FlutterError('deltaInterceptor 的统一运动接线需要默认控制器或 ElScrollController。');
    }
    _syncMotionCoordinators();
    final mainAxis = _layoutAxis;
    final hasMainDriver = (_inputRouter?.hasParticipants(mainAxis) ?? false) || _ancestorRouteFor(mainAxis) != null;
    if (hasMainDriver) {
      final link = _mixinInputLinkFor(mainAxis)..next = _baseEffectiveInterceptor;
      _effectiveInterceptor = link;
    } else {
      _effectiveInterceptor = _baseEffectiveInterceptor;
    }

    final hasHorizontalDriver =
        _isDualAxis &&
        ((_inputRouter?.hasParticipants(Axis.horizontal) ?? false) || _ancestorRouteFor(Axis.horizontal) != null);
    if (hasHorizontalDriver) {
      final link = _mixinInputLinkFor(Axis.horizontal)..next = null;
      _effectiveHorizontalInterceptor = link;
    } else {
      _effectiveHorizontalInterceptor = null;
    }

    if (!_mixinCallbacksActive) return;
    final renderObject = _activeMixinViewportRenderObject();
    if (renderObject != null) {
      renderObject
        ..deltaInterceptor = _effectiveInterceptor
        ..horizontalDeltaInterceptor = _effectiveHorizontalInterceptor
        ..onScrollInputActivityChanged = _mixinClients == null ? null : _handleMixinInputActivityChanged;
      renderObject.canDrag = _mergedCanDrag;
    }
  }

  _ScrollMotionCoordinator? _motionCoordinatorFor(Axis axis) =>
      axis == Axis.vertical ? _verticalMotion : _horizontalMotion;

  _ScrollInputRoute? _ancestorRouteFor(Axis axis) => _ancestorInputRoutes?[axis];

  bool _needsLocalInputRoute(Axis axis) =>
      (axis == _layoutAxis && _selectedRefresher != null) ||
      (axis == _layoutAxis && widget.deltaInterceptor != null) ||
      (_inputRouter?.hasParticipants(axis) ?? false) ||
      (_inputRouter?.tracksFor(axis).isNotEmpty ?? false) ||
      (_mixinClients?.values.any((entry) => entry.axis == axis && entry.wantsScrollSessions) ?? false);

  /// 被动需求消失时释放本地输入路线；路线仍在消费手势或惯性时只登记待回收，
  /// 等它自然到达终态再摘除，避免观察者离屏把未抬手的拖动一并取消。
  void _releaseLocalInputRoute(Axis axis, _ScrollInputRoute route) {
    if (route.isBusy) {
      route.retireWhenIdle = true;
      return;
    }
    route.finish(cancelled: true);
    _dropInputRoute(axis, route);
  }

  void _dropInputRoute(Axis axis, _ScrollInputRoute route) {
    final routes = _ancestorInputRoutes;
    if (routes == null || !identical(routes[axis], route)) return;
    route.retireWhenIdle = false;
    routes.remove(axis);
    if (routes.isEmpty) _ancestorInputRoutes = null;
  }

  void _finishAncestorInputRoutes() {
    for (final route in _ancestorInputRoutes?.values ?? const <_ScrollInputRoute>[]) {
      route.finish(cancelled: true);
    }
  }

  void _syncDeferredAncestorInputRoutes() {
    if (!mounted || !_mixinCallbacksActive) return;
    _syncAncestorInputRoutes();
    _syncMixinInputInterceptors();
  }

  void _syncAncestorInputRoutes() {
    final regions = _NestedScrollScope.declarationsOf(context);
    for (final axis in Axis.values) {
      final target = positionFor(axis);
      List<ElScrollViewState>? ancestors;
      if (target != null && _inputTickerEnabled) {
        var searchContext = context;
        while (true) {
          final ancestor = maybeFindScrollViewState(searchContext, axis: axis);
          if (ancestor == null) break;
          // 刷新器拥有边界分账时同时登记普通祖先，非刷新边仍能继续向外交接。
          if ((axis == _layoutAxis && _selectedRefresher != null) ||
              (ancestor._mixinClients?.entries.any((entry) {
                    final client = entry.key;
                    if (entry.value.axis != axis ||
                        entry.value.scrollInputSlot == null ||
                        !client.mountedForScrollCallbacks) {
                      return false;
                    }
                    return client is! ElNestedScrollMixin ||
                        (client._nestedNode?.detached == false && regions.contains(client._nestedParent));
                  }) ??
                  false)) {
            (ancestors ??= []).add(ancestor);
          }
          searchContext = ancestor.context;
        }
      }
      if (ancestors != null &&
          (target is! ScrollEnginePosition ||
              ancestors.any((host) => host.positionFor(axis) is! ScrollEnginePosition))) {
        if (ancestors.any(
          (host) =>
              host._mixinClients?.values.any((entry) => entry.axis == axis && entry.scrollInputSlot != null) ?? false,
        )) {
          throw FlutterError('跨宿主协同输入需要各层使用默认控制器或 ElScrollController。');
        }
        ancestors = null;
      }
      if (ancestors == null && target is ScrollEnginePosition && _needsLocalInputRoute(axis)) ancestors = const [];
      final previous = _ancestorRouteFor(axis);
      previous?.updateRegions(regions);
      if (listEquals(previous?.ancestors, ancestors)) continue;
      // 新协同成员只接下一段手势，不能把正在运行的普通拖拽改接到祖先。
      if (previous == null &&
          ancestors != null &&
          (_activeMixinViewportRenderObject()?.deferStructuralUpdateForActiveTouch(_syncDeferredAncestorInputRoutes) ??
              false)) {
        continue;
      }
      if (ancestors == null && previous != null && previous.ancestors.isEmpty) {
        // 本地被动路线失去需求时同样延迟回收，不打断在途手势。
        _releaseLocalInputRoute(axis, previous);
      } else {
        previous?.finish(cancelled: true);
        if (ancestors == null) {
          _ancestorInputRoutes?.remove(axis);
        } else {
          (_ancestorInputRoutes ??= {})[axis] = _ScrollInputRoute(this, axis, List.unmodifiable(ancestors))
            ..updateRegions(regions);
        }
      }
    }
    if (_ancestorInputRoutes?.isEmpty ?? false) _ancestorInputRoutes = null;
  }

  void _syncMotionCoordinators() {
    // 本地 pre 也必须先取得输入所有权，不能等正文第一次发生位移才登记。
    for (final axis in Axis.values) {
      final route = _ancestorRouteFor(axis);
      if (positionFor(axis) is ScrollEnginePosition && _needsLocalInputRoute(axis)) {
        if (route == null) (_ancestorInputRoutes ??= {})[axis] = _ScrollInputRoute(this, axis, const []);
      } else if (route != null && route.ancestors.isEmpty) {
        _releaseLocalInputRoute(axis, route);
      }
    }
    if (_ancestorInputRoutes?.isEmpty ?? false) _ancestorInputRoutes = null;
    if (_verticalMotion == null &&
        _horizontalMotion == null &&
        !(_inputRouter?.hasTracks ?? false) &&
        _ancestorInputRoutes == null) {
      return;
    }
    for (final axis in Axis.values) {
      final target = positionFor(axis);
      final tracks = _inputRouter?.tracksFor(axis) ?? const <_EffectTrackBinding>[];
      final existing = _motionCoordinatorFor(axis);
      if (target is ScrollEnginePosition &&
          (tracks.isNotEmpty || _ancestorRouteFor(axis) != null) &&
          _mixinCallbacksActive) {
        final coordinator = existing ?? _ScrollMotionCoordinator(this, axis);
        if (axis == Axis.vertical) {
          _verticalMotion = coordinator;
        } else {
          _horizontalMotion = coordinator;
        }
        coordinator.configure(target, tracks);
      } else {
        existing?.dispose();
        if (axis == Axis.vertical) {
          _verticalMotion = null;
        } else {
          _horizontalMotion = null;
        }
      }
    }
  }

  RenderVirtualScrollView? _activeMixinViewportRenderObject() {
    final viewportContext = _viewportKey.currentContext;
    if (viewportContext == null) return null;
    var debugActive = true;
    assert(() {
      if (viewportContext case final Element element) debugActive = element.debugIsActive;
      return true;
    }());
    if (!debugActive) return null;
    final renderObject = viewportContext.findRenderObject();
    return renderObject is RenderVirtualScrollView ? renderObject : null;
  }

  double _dispatchMixinPreScroll(Axis axis, double delta, ElScrollDeltaSource source, {double? requestedDelta}) =>
      _inputRouter?.dispatch(axis, delta, source, post: false, requestedDelta: requestedDelta) ?? 0.0;

  double _dispatchMixinPostScroll(Axis axis, double delta, ElScrollDeltaSource source) =>
      _inputRouter?.dispatch(axis, delta, source, post: true) ?? 0.0;

  double _dispatchMixinPreFling(Axis axis, double velocity, {double? requestedVelocity}) =>
      _inputRouter?.fling(axis, velocity, requestedVelocity: requestedVelocity) ?? velocity;

  void _syncMixinPositionListeners() {
    if (!_mixinCallbacksActive || _mixinClients == null) {
      _detachMixinPositionListeners();
      return;
    }
    final mainAxis = _layoutAxis;
    final nextMain = _hasMixinScrollClient(mainAxis) ? position : null;
    if (!identical(nextMain, _mixinObservedMainPosition)) {
      if (_mixinObservedMainPosition case final ScrollEnginePosition old?) {
        old.onActivityChanged = null;
        old.onMotionSample = null;
      }
      _mixinObservedMainPosition?.isScrollingNotifier.removeListener(_handleMixinMainScrollingChanged);
      _mixinObservedMainPosition = nextMain;
      _mixinMainWasScrolling = nextMain?.isScrollingNotifier.value ?? false;
      if (nextMain != null) _ensureMixinAxisSnapshot(mainAxis, resetDelta: true);
      nextMain?.isScrollingNotifier.addListener(_handleMixinMainScrollingChanged);
      if (nextMain is ScrollEnginePosition) {
        nextMain.onActivityChanged = _handleMixinMainActivityChanged;
        nextMain.onMotionSample = _handleMixinMainMotionSample;
      }
    }

    final nextHorizontal = _isDualAxis && _hasMixinScrollClient(Axis.horizontal) ? horizontalPosition : null;
    if (!identical(nextHorizontal, _mixinObservedHorizontalPosition)) {
      if (_mixinObservedHorizontalPosition case final ScrollEnginePosition old?) {
        old.onActivityChanged = null;
        old.onMotionSample = null;
      }
      _mixinObservedHorizontalPosition?.removeListener(_handleMixinHorizontalOffsetChanged);
      _mixinObservedHorizontalPosition?.isScrollingNotifier.removeListener(_handleMixinHorizontalScrollingChanged);
      _mixinObservedHorizontalPosition = nextHorizontal;
      _mixinHorizontalWasScrolling = nextHorizontal?.isScrollingNotifier.value ?? false;
      if (nextHorizontal != null) _ensureMixinAxisSnapshot(Axis.horizontal, resetDelta: true);
      nextHorizontal?.addListener(_handleMixinHorizontalOffsetChanged);
      nextHorizontal?.isScrollingNotifier.addListener(_handleMixinHorizontalScrollingChanged);
      if (nextHorizontal is ScrollEnginePosition) {
        nextHorizontal.onActivityChanged = _handleMixinHorizontalActivityChanged;
        nextHorizontal.onMotionSample = _handleMixinHorizontalMotionSample;
      }
    }
  }

  void _detachMixinPositionListeners() {
    if (_mixinObservedMainPosition case final ScrollEnginePosition old?) {
      old.onActivityChanged = null;
      old.onMotionSample = null;
    }
    if (_mixinObservedHorizontalPosition case final ScrollEnginePosition old?) {
      old.onActivityChanged = null;
      old.onMotionSample = null;
    }
    _mixinObservedMainPosition?.isScrollingNotifier.removeListener(_handleMixinMainScrollingChanged);
    _mixinObservedHorizontalPosition?.removeListener(_handleMixinHorizontalOffsetChanged);
    _mixinObservedHorizontalPosition?.isScrollingNotifier.removeListener(_handleMixinHorizontalScrollingChanged);
    _mixinObservedMainPosition = null;
    _mixinObservedHorizontalPosition = null;
    _mixinMainWasScrolling = false;
    _mixinHorizontalWasScrolling = false;
  }

  void _forEachActiveMixinClient(
    Axis axis,
    void Function(_ScrollMixinClient client, _ScrollMixinClientRegistration registration) callback,
  ) {
    if (!_mixinCallbacksActive) return;
    final snapshot = _mixinObservers;
    for (final entry in snapshot) {
      if (entry.value.axis != axis || !entry.key.mountedForScrollCallbacks) continue;
      if (!identical(_mixinClients?[entry.key], entry.value)) continue;
      callback(entry.key, entry.value);
    }
  }

  void _handleMixinMainScrollingChanged() {
    final target = _mixinObservedMainPosition;
    if (target == null) return;
    final scrolling = target.isScrollingNotifier.value;
    if (scrolling == _mixinMainWasScrolling) return;
    _mixinMainWasScrolling = scrolling;
    _dispatchMixinScrollingChanged(_layoutAxis, scrolling);
  }

  void _handleMixinMainActivityChanged() => _handleMixinPositionActivityChanged(_layoutAxis);

  void _handleMixinHorizontalActivityChanged() => _handleMixinPositionActivityChanged(Axis.horizontal);

  void _handleMixinPositionActivityChanged(Axis axis) {
    final target = positionFor(axis);
    final state = _mixinAxisStates?[axis];
    if (target == null ||
        state == null ||
        (state.snapshot.activity == _resolveMixinActivity(axis, target, state.explicitActivity) &&
            state.snapshot.sessionId == (target is ScrollEnginePosition ? target.observedSessionId : null))) {
      return;
    }
    final update = _refreshMixinSnapshot(axis);
    if (update != null) _dispatchMixinActivityChanged(axis, update);
  }

  void _handleMixinHorizontalScrollingChanged() {
    final target = _mixinObservedHorizontalPosition;
    if (target == null) return;
    final scrolling = target.isScrollingNotifier.value;
    if (scrolling == _mixinHorizontalWasScrolling) return;
    _mixinHorizontalWasScrolling = scrolling;
    _dispatchMixinScrollingChanged(Axis.horizontal, scrolling);
  }

  void _dispatchMixinScrollingChanged(Axis axis, bool scrolling) {
    final update = _refreshMixinSnapshot(axis);
    if (update == null) return;
    if (scrolling) {
      final details = ElScrollStartDetails(
        scrollView: this,
        axis: axis,
        position: update.position,
        previousSnapshot: update.previous,
        snapshot: update.current,
      );
      _forEachActiveMixinClient(axis, (client, registration) {
        if (registration.wantsScrollUpdates) client.handleScrollStart(details);
      });
    } else {
      final details = ElScrollEndDetails(
        scrollView: this,
        axis: axis,
        position: update.position,
        previousSnapshot: update.previous,
        snapshot: update.current,
      );
      _forEachActiveMixinClient(axis, (client, registration) {
        if (registration.wantsScrollUpdates) client.handleScrollEnd(details);
      });
    }
    _dispatchMixinActivityChanged(axis, update);
  }

  void _handleMixinHorizontalOffsetChanged() {
    _dispatchMixinScrollUpdate(Axis.horizontal);
  }

  void _dispatchMixinMainScrollUpdate() {
    _dispatchMixinScrollUpdate(_layoutAxis);
  }

  void _handleMixinMainMotionSample(ElScrollUpdateCause cause, double? motionDelta) => _dispatchMixinScrollUpdate(
    _layoutAxis,
    completeSample: true,
    observationCause: cause,
    sampledMotionDelta: motionDelta,
  );

  void _handleMixinHorizontalMotionSample(ElScrollUpdateCause cause, double? motionDelta) => _dispatchMixinScrollUpdate(
    Axis.horizontal,
    completeSample: true,
    observationCause: cause,
    sampledMotionDelta: motionDelta,
  );

  void _dispatchMixinScrollUpdate(
    Axis axis, {
    bool completeSample = false,
    ElScrollUpdateCause observationCause = ElScrollUpdateCause.unknown,
    double? sampledMotionDelta,
  }) {
    final target = positionFor(axis);
    if (!completeSample && target is ScrollEnginePosition && (target.isRetiredWrite || target.hasActiveMotionSample)) {
      return;
    }
    final update = _refreshMixinSnapshot(
      axis,
      observationCause: observationCause,
      sampledMotionDelta: sampledMotionDelta,
    );
    if (update == null) return;
    final details = ElScrollUpdateDetails(
      scrollView: this,
      axis: axis,
      position: update.position,
      previousSnapshot: update.previous,
      snapshot: update.current,
    );
    _forEachActiveMixinClient(axis, (client, registration) {
      if (registration.wantsScrollUpdates) client.handleScrollUpdate(details);
    });
    _dispatchMixinActivityChanged(axis, update);
  }

  void _dispatchMixinActivityChanged(
    Axis axis,
    ({ElScrollSnapshot previous, ElScrollSnapshot current, ScrollPosition position}) update,
  ) {
    if (update.previous.activity == update.current.activity && update.previous.sessionId == update.current.sessionId) {
      return;
    }
    final details = ElScrollActivityDetails(
      scrollView: this,
      axis: axis,
      position: update.position,
      previousSnapshot: update.previous,
      snapshot: update.current,
    );
    _forEachActiveMixinClient(axis, (client, registration) {
      if (registration.wantsScrollUpdates) client.handleActivityChanged(details);
    });
  }

  void _handleMixinInputActivityChanged(Axis axis, ElScrollActivityType? activity) {
    if (!_hasMixinClientForAxis(axis)) return;
    final states = _mixinAxisStates ??= <Axis, _ScrollMixinAxisState>{};
    final state = states.putIfAbsent(axis, _ScrollMixinAxisState.new);
    if (state.explicitActivity == activity) return;
    state.explicitActivity = activity;
    final update = _refreshMixinSnapshot(axis);
    if (update != null) _dispatchMixinActivityChanged(axis, update);
  }

  void _scheduleMixinMetricsDispatch(Axis axis, {bool force = false}) {
    if (!_mixinCallbacksActive || !_hasMixinViewportClient(axis)) return;
    final target = positionFor(axis);
    if (target == null) return;
    final signature = _ScrollMetricsSignature.fromPosition(target);
    final previous = _mixinMetricsSignatures?[axis];
    if (!force && signature == previous) return;
    (_mixinMetricsSignatures ??= <Axis, _ScrollMetricsSignature>{})[axis] = signature;
    (_pendingMixinMetricsAxes ??= <Axis>{}).add(axis);
    if (_mixinMetricsDispatchScheduled) return;
    _mixinMetricsDispatchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mixinMetricsDispatchScheduled = false;
      final axes = _pendingMixinMetricsAxes?.toList(growable: false) ?? const <Axis>[];
      _pendingMixinMetricsAxes = null;
      if (!mounted || !_mixinCallbacksActive) return;
      for (final pendingAxis in axes) {
        final update = _refreshMixinSnapshot(pendingAxis, observationCause: ElScrollUpdateCause.layoutCorrection);
        if (update == null) continue;
        final details = ElScrollMetricsDetails(
          scrollView: this,
          axis: pendingAxis,
          position: update.position,
          previousSnapshot: update.previous,
          snapshot: update.current,
          metrics: metricsFor(pendingAxis)?.copyWith(),
        );
        _forEachActiveMixinClient(pendingAxis, (client, registration) {
          if (registration.wantsViewportUpdates) client.handleMetricsChanged(details);
        });
        _dispatchMixinActivityChanged(pendingAxis, update);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _handleScrollbarMetricsChanged() {
    _scrollbarController?.refresh();
    if (_mixinClients == null) return;
    _scheduleItemPresentationDispatch();
    _scheduleMixinMetricsDispatch(_layoutAxis);
    if (_isDualAxis) _scheduleMixinMetricsDispatch(Axis.horizontal);
  }

  void _handleMinimumCrossAxisExtentChanged() {
    if (_minimumCrossAxisExtentUpdateScheduled || !mounted) return;
    _minimumCrossAxisExtentUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _minimumCrossAxisExtentUpdateScheduled = false;
      if (!mounted) return;
      _contentController.updateSnapshot(_createContentSnapshot(), reconcileChildren: false, forceLayout: true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _handleItemExtentInvalidationChanged() {
    final invalidation = widget.itemExtentInvalidationListenable?.value;
    if (invalidation == null) return;
    _pendingItemExtentInvalidation = invalidation;
    if (_itemExtentInvalidationScheduled || !mounted) return;
    _itemExtentInvalidationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _itemExtentInvalidationScheduled = false;
      if (mounted) _flushPendingItemExtentInvalidation();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _flushPendingItemExtentInvalidation() {
    final invalidation = _pendingItemExtentInvalidation;
    if (invalidation == null) return;
    _pendingItemExtentInvalidation = null;
    _cancelScrollToIndexOperation();
    if (invalidation.resetAll) {
      _resetExtentIndexPreservingAnchor(_childrenSnapshot, null, discardMeasuredExtents: true);
      if (_pendingAnchorIndex != null || _pendingScrollPositionEdge != null) {
        _applyPendingScrollCorrection(notify: false);
      }
      _refreshVisibleRangeAndCommit(forceContentSnapshot: true, forceContentLayout: true);
      _scheduleVisibleRangeUpdate();
      return;
    }
    final changedIndices = <int>{
      for (final index in invalidation.indices)
        if (index >= 0 && index < _extentIndex.count && _extentIndex.isMeasured(index)) index,
    };
    if (changedIndices.isEmpty) return;

    final oldMaxOffset = _maxLayoutScrollOffset;
    final oldPixels = _currentScrollOffset().clamp(0.0, oldMaxOffset).toDouble();
    final pinnedEdge = _pinnedScrollPositionEdge(oldPixels, oldMaxOffset);
    final oldContentOffset = _isAxisReversed ? oldMaxOffset - oldPixels : oldPixels;
    final mountedAnchor = _mountedAnchorAtContentOffset(
      oldContentOffset,
      within: _viewportExtent,
      skip: changedIndices.contains,
    );
    final anchorIndex =
        mountedAnchor?.index ?? _anchorIndexAtContentOffset(oldContentOffset, _effectiveChildren.length);
    final anchorDelta = mountedAnchor?.delta ?? _layoutOffsetOfItem(anchorIndex) - oldContentOffset;
    for (final index in changedIndices) {
      _extentIndex.invalidateMeasuredExtent(index);
    }
    if (pinnedEdge != null) {
      _pendingScrollPositionEdge = pinnedEdge;
      _pendingAnchorIndex = null;
    } else {
      _pendingAnchorIndex = anchorIndex;
      _pendingAnchorDelta = anchorDelta;
      _pendingAnchorCapturePixels = oldPixels;
    }
    _minimumVisibleLastIndex = null;
    _applyPendingScrollCorrection(notify: false);
    _refreshVisibleRangeAndCommit(forceContentSnapshot: true, forceContentLayout: true);
    _scheduleVisibleRangeUpdate();
  }

  /// 双轴时两份 binding 各自驱动同一个 render 标志位，合并口径取"或"：
  /// 任一轴 scrolling 需要 ignorePointer / 任一轴可拖即 canDrag。
  bool get _mergedIgnorePointer => _scrollBinding.ignorePointer || (_horizontalBinding?.ignorePointer ?? false);

  bool get _mergedCanDrag =>
      _refreshLink != null ||
      _scrollBinding.canDrag ||
      (_horizontalBinding?.canDrag ?? false) ||
      (_inputRouter?.hasMotionInputRange(_layoutAxis) ?? false) ||
      (_ancestorRouteFor(_layoutAxis)?.hasInputRange ?? false) ||
      (_isDualAxis &&
          ((_inputRouter?.hasMotionInputRange(Axis.horizontal) ?? false) ||
              (_ancestorRouteFor(Axis.horizontal)?.hasInputRange ?? false)));

  void _applyIgnorePointerToRender(bool value) {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is RenderVirtualScrollView) {
      renderObject.ignorePointer = _mergedIgnorePointer;
    }
  }

  void _applyCanDragToRender(bool value) {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is RenderVirtualScrollView) {
      renderObject.canDrag = _mergedCanDrag;
    }
  }

  void _applySemanticsActionsToRender(Set<SemanticsAction> actions) {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    renderObject?.markNeedsSemanticsUpdate();
  }

  /// Fenwick 按段计划的行记账：固定行高直接写入，变动行高由首窗实测建立估算。
  /// 行间距由计划额外叠加，不计入行高。
  SegmentExtentIndex _createExtentIndex({double? estimatedExtent}) =>
      SegmentExtentIndex(_sectionPlan, estimatedExtent: estimatedExtent);

  /// 只刷新变尺寸段的估算，固定段保持一次算出的完整范围。
  bool _refreshEstimatedExtents(double estimatedExtent) =>
      _extentIndex.refreshEstimatedExtents(estimatedExtent: estimatedExtent);

  /// 本次 didUpdateWidget 的段计划迁移产物（row/item splice 序列）；
  /// 消费点：[_nextExtentIndexAfterUpdate]（Fenwick 演进）与各注册表 remap。
  /// 同帧消费后清空。
  SegmentPlanTransition? _pendingTransition;

  /// 与 [_pendingTransition] 同生命周期的旧 plan（keyed remap 通道要旧段的
  /// 行/item 起点做坐标换算）。
  SegmentPlan? _pendingOldPlan;

  /// 把多点 item splice 聚合为单一覆盖 span（旧 change-span 消费面的聚合
  /// 视图：判"有没有变化"与粗定位；精细路径走 [_pendingTransition] 序列）。
  _VirtualChildChangeSpan? _aggregateItemChangeSpan(SegmentPlanTransition? transition) {
    if (transition == null || transition.itemSplices.isEmpty) return null;
    final splices = transition.itemSplices;
    final first = splices.first;
    var oldEnd = first.itemStart;
    var newEnd = first.itemStart;
    for (final splice in splices) {
      oldEnd = splice.itemStart + splice.deleteItems;
      newEnd = splice.itemStart + splice.insertItems;
    }
    // 升序序列在 old 坐标系：末 splice 的 old 终点即覆盖窗 old 端；new 端
    // 需累计前序 splice 的净增减。
    var delta = 0;
    for (var i = 0; i < splices.length - 1; i++) {
      delta += splices[i].insertItems - splices[i].deleteItems;
    }
    return _VirtualChildChangeSpan(
      start: first.itemStart,
      deleteCount: oldEnd - first.itemStart,
      insertCount: newEnd + delta - first.itemStart,
    );
  }

  /// 锚点 item index 经段级 splice 序列平移到新 item 空间。
  ///
  /// 前缀 identity、后缀平移；落在删除窗内 → keyed 重排 splice 用行映射
  /// 找回（linear 段行=item），普通 splice 钉到窗口起点（widget identity
  /// 扫描已废弃——扁平面是惰性 facade，扫描即物化）。
  int? _resolveAnchorIndexAfterChildChange(
    List<Widget> oldChildren,
    int oldAnchorIndex,
    _VirtualChildChangeSpan? change,
  ) {
    final newChildren = _effectiveChildren;
    if (newChildren.isEmpty) return null;
    if (oldChildren.isEmpty) return 0;

    var index = oldAnchorIndex.clamp(0, oldChildren.length - 1).toInt();
    final transition = _pendingTransition;
    if (change == null || transition == null) return index.clamp(0, newChildren.length - 1).toInt();

    // findChildIndexCallback keyed 反查优先：builder 段 diff 是 index-is-identity
    // 尾部 splice，头/中部插入下算术平移会错行——锚点行有 key 时跟 key 走。
    final keyedIndex = _keyedNewIndexForOldIndex(index);
    if (keyedIndex != null) return keyedIndex.clamp(0, newChildren.length - 1).toInt();

    // 从后往前平移：后缀 splice 先应用不影响前面的坐标判定。
    for (var i = transition.itemSplices.length - 1; i >= 0; i--) {
      final splice = transition.itemSplices[i];
      final oldEnd = splice.itemStart + splice.deleteItems;
      if (index >= oldEnd) {
        index = index - splice.deleteItems + splice.insertItems;
      } else if (index >= splice.itemStart) {
        // 落在变化窗内：对应 row splice 若带 keyed 映射，用 old→new 行映射
        // 找回（行=item 的 linear 段成立）；否则钉窗口起点。
        final rowSplice = i < transition.rowSplices.length ? transition.rowSplices[i] : null;
        final keyed = rowSplice?.oldRowForNewRow;
        int? mapped;
        if (keyed != null && rowSplice != null && rowSplice.rowStart == splice.itemStart) {
          for (final MapEntry(key: newRow, value: oldRow) in keyed.entries) {
            if (oldRow == index) {
              mapped = newRow;
              break;
            }
          }
        }
        index = mapped ?? splice.itemStart;
      }
    }
    return index.clamp(0, newChildren.length - 1).toInt();
  }

  void _resetExtentIndexPreservingAnchor(
    List<Widget> oldChildren,
    _VirtualChildChangeSpan? childChange, {
    bool discardMeasuredExtents = false,
    Axis? previousAxis,
  }) {
    if (_scrollDebugCountersEnabled) _debugCounters!.recordExtentIndexReset();
    final oldCount = _extentIndex.count;
    int? anchorIndex;
    double anchorDelta = 0.0;
    double capturePixels = 0.0;
    VirtualScrollEdge? pinnedEdge;
    if (oldCount > 0) {
      final oldMaxOffset = _maxLayoutScrollOffset;
      final oldPixels = _currentScrollOffset().clamp(0.0, oldMaxOffset).toDouble();
      // 结构变化默认保留 pixels；历史消息保位和贴底跟随分别显式开启。
      // 弃度量重建属于环境修正，仍使用原有锚点与边缘收敛规则。
      pinnedEdge = _pinnedScrollPositionEdge(oldPixels, oldMaxOffset);
      if (!discardMeasuredExtents) {
        if (pinnedEdge == VirtualScrollEdge.min && childChange != null) pinnedEdge = null;
        if (pinnedEdge == VirtualScrollEdge.max && !widget.pinToEnd) pinnedEdge = null;
      }
      if (widget.preserveAnchor || discardMeasuredExtents || childChange == null) {
        final oldContentOffset = _isAxisReversed ? oldMaxOffset - oldPixels : oldPixels;
        final mountedAnchor = _mountedAnchorAtContentOffset(oldContentOffset);
        final oldAnchorIndex = mountedAnchor?.index ?? _anchorIndexAtContentOffset(oldContentOffset, oldCount);
        anchorIndex = _resolveAnchorIndexAfterChildChange(oldChildren, oldAnchorIndex, childChange);
        anchorDelta = mountedAnchor?.delta ?? _layoutOffsetOfItem(oldAnchorIndex) - oldContentOffset;
        capturePixels = oldPixels;
      }
    }
    _minimumVisibleLastIndex = null;
    _minimumObservedItemExtent = null;
    if (discardMeasuredExtents) {
      final retainedEstimate = _extentIndex.hasEstimate ? _extentIndex.estimatedExtent : null;
      _measurementGeneration++;
      _extentIndex = _createExtentIndex(estimatedExtent: retainedEstimate);
    } else {
      _extentIndex = _nextExtentIndexAfterUpdate(oldChildren, childChange, previousAxis: previousAxis);
    }
    if (pinnedEdge != null) {
      _pendingScrollPositionEdge = pinnedEdge;
      _pendingAnchorIndex = null;
    } else if (anchorIndex != null && anchorIndex < _effectiveChildren.length) {
      _pendingAnchorIndex = anchorIndex;
      _pendingAnchorDelta = anchorDelta;
      _pendingAnchorCapturePixels = capturePixels;
    } else {
      _pendingScrollPositionEdge = null;
      _pendingAnchorIndex = null;
    }
  }

  SegmentExtentIndex _nextExtentIndexAfterUpdate(
    List<Widget> oldChildren,
    _VirtualChildChangeSpan? childChange, {
    Axis? previousAxis,
  }) {
    if ((previousAxis ?? _layoutAxis) != _layoutAxis) return _createExtentIndex();
    final keyedRows = <int, Map<int, int>>{};
    for (final splice in _pendingTransition?.rowSplices ?? <RowSplice>[]) {
      if (_sectionPlan.totalRowCount == 0) break;
      final section = _sectionPlan.segmentOfRow(splice.rowStart.clamp(0, _sectionPlan.totalRowCount - 1));
      final segment = _segments[section];
      if (segment is! LinearSegment || segment.fixed != null) continue;
      final keyed = splice.oldRowForNewRow ?? _keyedRowMapFromFindChildIndex(splice);
      if (keyed != null) keyedRows[section] = keyed;
    }
    return _extentIndex.reconfigured(_sectionPlan, keyedRows: keyedRows);
  }

  /// 旧全局 item index 经 findChildIndexCallback 反查新全局 index：命中旧
  /// memo 的带 key 行且新段 callback 认识该 key 时返回，否则 null。
  int? _keyedNewIndexForOldIndex(int oldIndex) {
    final oldPlan = _pendingOldPlan;
    final oldFlat = _childrenSnapshot;
    if (oldPlan == null || oldFlat is! FlatSegmentItemList) return null;
    Widget? widget;
    oldFlat.forEachMaterialized((index, w) {
      if (index == oldIndex) widget = w;
    });
    final key = widget?.key;
    if (key == null) return null;
    final oldSeg = oldPlan.segmentOfItem(oldIndex);
    final newPlan = _sectionPlan;
    if (oldSeg >= newPlan.segments.length) return null;
    final newSegment = newPlan.segments[oldSeg];
    if (newSegment is! LinearSegment) return null;
    final source = newSegment.source;
    if (source is! BuilderItemSource || source.findChildIndex == null) return null;
    final newLocal = source.findChildIndex!(key);
    if (newLocal == null || newLocal < 0 || newLocal >= source.itemCount) return null;
    return newPlan.itemStartOf(oldSeg) + newLocal;
  }

  /// 为一个普通 row splice 尝试构造 findChildIndexCallback keyed 全局行映射
  /// （new row → old row）。仅当 splice 落在单一 builder 段、新旧段都带
  /// findChildIndex、且旧 memo 至少命中一行时返回非 null；行=item 的
  /// linear 段语义（grid 段不走此通道）。
  Map<int, int>? _keyedRowMapFromFindChildIndex(RowSplice splice) {
    final oldPlan = _pendingOldPlan;
    final oldFlat = _childrenSnapshot;
    if (oldPlan == null || oldFlat is! FlatSegmentItemList) return null;
    final newPlan = _sectionPlan;
    if (splice.rowStart >= newPlan.totalRowCount && splice.insertRows == 0) return null;
    final segIndex = newPlan.segmentOfRow(splice.rowStart.clamp(0, math.max(newPlan.totalRowCount - 1, 0)).toInt());
    final newSegment = newPlan.segments[segIndex];
    if (newSegment is! LinearSegment) return null;
    final newSource = newSegment.source;
    if (newSource is! BuilderItemSource || newSource.findChildIndex == null) return null;

    final newRowStart = newPlan.rowStartOf(segIndex);
    final map = <int, int>{};
    oldFlat.forEachMaterialized((oldGlobalIndex, widget) {
      final key = widget.key;
      if (key == null) return;
      final newLocal = newSource.findChildIndex!(key);
      if (newLocal == null || newLocal < 0 || newLocal >= newSource.itemCount) return;
      // 行=item：旧全局行 = 旧全局 index 的行；新全局行 = 新段行起点 + 局部。
      if (oldGlobalIndex < 0 || oldGlobalIndex >= oldPlan.totalItemCount) return;
      map[newRowStart + newLocal] = oldPlan.rowOfItem(oldGlobalIndex);
    });
    if (map.isEmpty) return null;
    return map;
  }

  void _handleScrollOffsetChanged() {
    final next = _currentScrollOffset();
    if ((next - _scrollOffset).abs() <= precisionErrorTolerance) return;
    if (_dragOptimizeEnabled && _scrollbarDragging && _scrollbarDragHandledScrollOffset != null) {
      if ((next - _scrollbarDragHandledScrollOffset!).abs() <= precisionErrorTolerance) {
        _scrollOffset = next;
        _scrollbarDragHandledScrollOffset = null;
        if (_hasMixinScrollClient(_layoutAxis)) _dispatchMixinMainScrollUpdate();
        return;
      }
    }
    _pendingScrollPositionEdge = null;
    // 注意：这里**不**清 _pendingAnchorIndex。fling 中每个弹道 tick 都会走到
    // 本回调；若在此清锚点，post-frame 报告排下的修正在落地前就被下一个
    // tick 取消，度量带来的模型偏移被原样绘制——即 fling 穿越未测量区域时
    // 的逐帧回跳。锚点修正已增量化（capturePixels 补偿），与用户滚动可
    // 交换，滚动期间保留它是安全的。edge pin 仍然清：用户主动滚离边缘后
    // 不应被拽回。
    final previousContentOffset = _contentScrollOffset();
    _scrollOffset = next;
    final currentContentOffset = _contentScrollOffset();
    final contentDelta = currentContentOffset - previousContentOffset;
    if (contentDelta.abs() > precisionErrorTolerance) {
      _imageDecodeForward = contentDelta > 0;
    }
    final jumpExtent = math.max(_viewportExtent, _extentIndex.estimatedExtent + _gap);
    final teleported = (currentContentOffset - previousContentOffset).abs() > jumpExtent;
    // 瞬移级跳变（jumpToIndex / 程序性远跳）后，针对旧视口的模型补偿不再
    // 有意义，丢弃；连续滚动（含反向）保留。
    if (teleported) _pendingAnchorIndex = null;
    if (currentContentOffset < previousContentOffset - precisionErrorTolerance || teleported) {
      _minimumVisibleLastIndex = null;
    }
    final update = _recomputeVisibleRangeWithDetail();
    _applyVisibleRangeUpdate(update);
    if (_hasMixinScrollClient(_layoutAxis)) _dispatchMixinMainScrollUpdate();
  }

  bool _scrollbarDragRangeUpdateScheduled = false;

  /// 拖 thumb 期间的窗口重算合并：一帧最多一次，取帧首时刻的最新 thumb
  /// 分数。回调注册为 transient frame callback（帧首、build 前执行），
  /// 高回报率指针的多次 move 不再逐事件重算。
  void _scheduleScrollbarDragRangeUpdate() {
    if (_scrollbarDragRangeUpdateScheduled || !mounted) return;
    _scrollbarDragRangeUpdateScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _scrollbarDragRangeUpdateScheduled = false;
      if (!mounted || !_scrollbarDragging) return;
      _applyVisibleRangeUpdate(_recomputeVisibleRangeWithDetail());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _scheduleVisibleRangeUpdate() {
    if (_rangeScheduled || !mounted) return;
    _rangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rangeScheduled = false;
      final update = _recomputeVisibleRangeWithDetail();
      if (update.anyChanged) _applyVisibleRangeUpdate(update);
    });
  }

  bool _recomputeVisibleRange() => _recomputeVisibleRangeWithDetail().anyChanged;

  void _applyVisibleRangeUpdate(
    _VirtualVisibleRangeUpdate update, {
    bool forceContentSnapshot = false,
    bool forceContentLayout = false,
  }) {
    if ((!update.anyChanged && !forceContentSnapshot) || !mounted) return;
    if (update.requiresRebuild) {
      _commitContentSnapshot(reconcileChildren: true);
    } else if (forceContentSnapshot) {
      _commitContentSnapshot(reconcileChildren: false, forceLayout: forceContentLayout);
    } else if (update.paintChanged) {
      if (_scrollbarDragging && !_dragOptimizeEnabled) {
        _commitContentSnapshot(reconcileChildren: false, forceLayout: true);
      }
      // else：亚行级滚动 / 同窗口 thumb 拖拽的热路径。paint/semantic 边界由
      // content render 从 position + thumb 分数实时自推（纯函数），State 侧
      // 无需任何推送；outer render 的 position 监听已按 tick markNeedsPaint。
    }
    // timeline/sticky 需要进入下一次业务 build 前立即推送；visibility 仍按
    // Flutter 生命周期合并到 post-frame，允许回调安全 setState。
    if (update.anyChanged) {
      _dispatchMixinItemSnapshots();
      _scheduleVisibilityDispatch();
    }
  }

  /// Like [_recomputeVisibleRange] but exposes which class of state actually
  /// shifted, so the scroll handler can skip a full Widget rebuild when only
  /// the paint-side bounds (visibleContentStart/End, semantic*) moved and the
  /// mounted [_firstIndex, _lastIndex] window is identical.
  _VirtualVisibleRangeUpdate _recomputeVisibleRangeWithDetail() {
    if (_scrollDebugCountersEnabled) _debugCounters!.recordVisibleRangeRecompute();
    final count = _effectiveChildren.length;
    // shrinkWrap：强制按完整子内容布局，虚拟化失效——窗口恒全量，item
    // 全部常驻挂载实测，容器宽高在 layout 期间精确（视口尺寸不参与窗口
    // 计算，与"先排 content 再回填视口尺寸"的布局时序解耦）。sticky
    // 识别/钉选照常；内容超过父级上界时仍可滚动。全量窗口下可视边界 =
    // 全内容。
    if (widget.shrinkWrap) {
      final totalLayoutExtent = _totalLayoutExtent;
      final rangeChanged = _firstIndex != 0 || _lastIndex != count || _minimumVisibleLastIndex != null;
      final paintChanged =
          (0.0 - _visibleContentStart).abs() > precisionErrorTolerance ||
          (totalLayoutExtent - _visibleContentEnd).abs() > precisionErrorTolerance ||
          (0.0 - _semanticContentStart).abs() > precisionErrorTolerance ||
          (totalLayoutExtent - _semanticContentEnd).abs() > precisionErrorTolerance;
      _firstIndex = 0;
      _lastIndex = count;
      _visibleContentStart = 0.0;
      _visibleContentEnd = totalLayoutExtent;
      _semanticContentStart = 0.0;
      _semanticContentEnd = totalLayoutExtent;
      _minimumVisibleLastIndex = null;
      final oldPinned = _pinnedStickyIndex;
      _pinnedStickyIndex = _computePinnedStickyIndex(_effectiveContentOffsetForVisibleRange());
      return _VirtualVisibleRangeUpdate(
        rangeChanged: rangeChanged || _pinnedStickyIndex != oldPinned,
        paintChanged: paintChanged,
        retainedFocusChanged: false,
      );
    }
    if (count == 0 || _viewportExtent <= 0.0) {
      final rangeChanged = _firstIndex != 0 || _lastIndex != 0 || _minimumVisibleLastIndex != null;
      final paintChanged =
          _visibleContentStart != 0.0 ||
          _visibleContentEnd != 0.0 ||
          _semanticContentStart != 0.0 ||
          _semanticContentEnd != 0.0;
      _firstIndex = 0;
      _lastIndex = 0;
      _visibleContentStart = 0.0;
      _visibleContentEnd = 0.0;
      _semanticContentStart = 0.0;
      _semanticContentEnd = 0.0;
      _minimumVisibleLastIndex = null;
      return _VirtualVisibleRangeUpdate(
        rangeChanged: rangeChanged,
        paintChanged: paintChanged,
        retainedFocusChanged: false,
      );
    }

    final initialRange = _measuringInitialWindow ? _initialMeasuredRange() : null;
    final effectiveOffset = _effectiveContentOffsetForVisibleRange();
    // Children are laid out at real extent-index offsets, not the scrollbar
    // drag fraction. Semantics must use the real scroll offset so screen
    // readers still see the rows that paint inside the viewport while a
    // scrollbar drag is in progress.
    final semanticOffset = _scrollbarDragging ? _contentScrollOffset() : effectiveOffset;
    final semanticStart = semanticOffset;
    final totalLayoutExtent = _totalLayoutExtent;
    final semanticEnd = math.min(totalLayoutExtent, semanticOffset + _viewportExtent);
    final start = effectiveOffset.clamp(0.0, totalLayoutExtent).toDouble();
    final end = math.min(totalLayoutExtent, effectiveOffset + _viewportExtent);
    final cacheExtent = _effectiveCacheExtent;
    final mountedStart = math.max(0.0, start - cacheExtent);
    final mountedEnd = math.min(totalLayoutExtent, end + cacheExtent);
    var first = initialRange?.start ?? _itemIndexAtLayoutOffset(mountedStart).clamp(0, count).toInt();
    final computedLast =
        initialRange?.end ?? _firstItemWithLayoutStartAtOrAfter(mountedEnd).clamp(first, count).toInt();
    final fillRange = initialRange != null
        ? null
        : _variableHeightFillRange(
            first: first,
            last: computedLast,
            start: mountedStart,
            end: mountedEnd,
            count: count,
          );
    if (fillRange != null) {
      first = fillRange.start;
    }
    final minimumLast = _minimumVisibleLastIndex;
    final filledLast = fillRange?.end ?? computedLast;
    final last = initialRange != null || minimumLast == null
        ? filledLast
        : math.max(filledLast, minimumLast.clamp(first, count).toInt());
    if (minimumLast != null && computedLast >= minimumLast) {
      _minimumVisibleLastIndex = null;
    }

    var retainedFocusChanged = false;

    final oldPinned = _pinnedStickyIndex;
    _pinnedStickyIndex = _computePinnedStickyIndex(effectiveOffset);
    final rangeChanged = first != _firstIndex || last != _lastIndex || _pinnedStickyIndex != oldPinned;
    final paintChanged =
        (start - _visibleContentStart).abs() > precisionErrorTolerance ||
        (end - _visibleContentEnd).abs() > precisionErrorTolerance ||
        (semanticStart - _semanticContentStart).abs() > precisionErrorTolerance ||
        (semanticEnd - _semanticContentEnd).abs() > precisionErrorTolerance;
    _firstIndex = first;
    _lastIndex = last;
    _visibleContentStart = start;
    _visibleContentEnd = end;
    _semanticContentStart = semanticStart;
    _semanticContentEnd = semanticEnd;
    // 全静态：mounted 集恒为常驻并集（全量），窗口序数推移不改变实际挂载，
    // paint/hit/semantics 又由 content render 实时自推——为它 rebuild 是纯
    // 浪费，滚动降为 paint 级（wheel/trackpad 零重建零重排，旧简单口径）。
    // 序数本身照常更新：onVisibleRangeChanged 的 mounted 语义保持真实，
    // 可视性派发经 paintChanged 兜住。
    final allStatic = _sectionPlan.isAllResident;
    return _VirtualVisibleRangeUpdate(
      rangeChanged: rangeChanged && !allStatic,
      paintChanged: paintChanged || (rangeChanged && allStatic),
      retainedFocusChanged: retainedFocusChanged,
    );
  }

  /// 从显示起点实测一窗，再用真实样本估计未挂载内容；反向从尾项开始。
  _VirtualIndexRange? _initialMeasuredRange() {
    final plan = _sectionPlan;
    final reversed = _isAxisReversed;
    final limit = _viewportExtent + _effectiveCacheExtent;
    var extent = reversed ? _mainAxisPaddingTotal - _mainAxisLeadingPadding : _mainAxisLeadingPadding;
    var first = reversed ? plan.totalItemCount : 0;
    var last = first;
    // 上一轮只新增一个未知行，已确认前缀直接查索引，避免重复扫描整窗。
    final previous = identical(_initialMeasurementModel, _extentIndex) ? _initialMeasurementIndex : null;
    final startStep = previous == null
        ? 0
        : reversed
        ? plan.totalRowCount - 1 - plan.rowOfItem(previous)
        : plan.rowOfItem(previous);
    if (startStep > 0) {
      final row = reversed ? plan.totalRowCount - 1 - startStep : startStep;
      extent += reversed
          ? _extentIndex.totalExtent -
                _extentIndex.offsetOf(row + 1) +
                plan.totalSpacing() -
                plan.cumulativeSpacingBeforeRow(row)
          : _extentIndex.offsetOf(row) + plan.cumulativeSpacingBeforeRow(row);
    }
    _initialMeasurementModel = _extentIndex;
    _initialMeasurementIndex = null;
    for (var step = startStep; step < plan.totalRowCount; step++) {
      if (extent >= limit - precisionErrorTolerance && _extentIndex.measuredCount > 0) break;
      final row = reversed ? plan.totalRowCount - 1 - step : step;
      final item = plan.firstItemOfRow(row);
      if (reversed) {
        first = item;
      } else {
        last = item + plan.itemsInRow(row);
      }
      if (!_extentIndex.isMeasured(row)) {
        _initialMeasurementIndex = item;
        return _VirtualIndexRange(first, last);
      }
      extent += _extentIndex.extentOf(row);
      if (extent >= limit - precisionErrorTolerance) break;
      extent += reversed && row > 0 ? plan.spacingAfterRow(row - 1) : plan.spacingAfterRow(row);
    }
    // 全零尺寸也是有效实测结果；不得替换成任意正数。
    final average =
        _extentIndex.measuredExtentAverage ??
        (_extentIndex.measuredCount == 0 ? 0.0 : _extentIndex.measuredExtentTotal / _extentIndex.measuredCount);
    _refreshEstimatedExtents(average);
    _initialMeasurementModel = null;
    return null;
  }

  /// children 结构变化时按稳定 item identity 原位迁移所有登记表。
  ///
  /// keyed materialized/static 项直接扫描新 plan，builder 项只调用官方
  /// findChildIndexCallback；绝不为反查物化整个 builder 段。无 key 项维持
  /// index-is-identity，与 Flutter 普通无 key child 的位置语义一致。
  void _remapItemConfigForChildChange(_VirtualChildChangeSpan? change) {
    final count = _effectiveChildren.length;
    _mixinItemClientsByIndex = null;
    _mixinItemBucketCache = null;
    _mixinItemVisibilityCache = null;
    _viewportHeaderOwners = null;
    _mixinStickyOwners = null;
    _stickyByIndex.clear();
    _pinnedStickyIndex = null;
    _invalidateSortedStickyIndices();

    final clients = _mixinClients;
    if (clients != null) {
      for (final entry in clients.entries) {
        final registration = entry.value;
        final oldIndex = registration.itemIndex;
        if (oldIndex == null) continue;
        registration.itemIndex = _newIndexForMixinItemIdentity(
          registration.itemIdentity,
          oldIndex: oldIndex,
          count: count,
        );
        registration.lastItemSnapshot = ElScrollItemSnapshot.detached;
        registration.visibilityDispatched = false;
        if (registration.itemIndex != null) {
          _attachMixinItemRegistration(entry.key, registration, captureSnapshot: false);
        }
      }
    }
    _rebuildResidentIndicesFromSegments();
  }

  int? _newIndexForMixinItemIdentity(Object? identity, {required int oldIndex, required int count}) {
    Object? layoutIdentity;
    if (identity case (final Object section, final Object local)) {
      layoutIdentity = section;
      identity = local;
    }
    if (identity is! Key) return oldIndex >= 0 && oldIndex < count ? oldIndex : null;
    final plan = _sectionPlan;
    for (var segmentIndex = 0; segmentIndex < plan.segments.length; segmentIndex++) {
      final segment = plan.segments[segmentIndex];
      if (layoutIdentity != null &&
          (segment.view?.key ?? (segment.view?.runtimeType, segmentIndex)) != layoutIdentity) {
        continue;
      }
      final start = plan.itemStartOf(segmentIndex);
      if (segment is StaticSegment) {
        if (segment.child.key == identity) return start;
        continue;
      }
      final source = switch (segment) {
        LinearSegment(:final source) => source,
        GridSegment(:final source) => source,
        StaticSegment() => throw StateError('handled above'),
      };
      if (source is MaterializedItemSource) {
        for (var localIndex = 0; localIndex < source.itemCount; localIndex++) {
          if (source.children[localIndex].key == identity) return start + localIndex;
        }
      } else if (source is BuilderItemSource && source.findChildIndex != null) {
        final localIndex = source.findChildIndex!(identity);
        if (localIndex != null && localIndex >= 0 && localIndex < source.itemCount) {
          return start + localIndex;
        }
      }
    }
    return null;
  }

  /// 普通成员与统一尺寸列表的真实首条保活，sticky 再按当前 pinned client 并集。
  void _rebuildResidentIndicesFromSegments() {
    _keepAliveIndices.clear();
    if (_viewportHeaderOwners != null) _keepAliveIndices.addAll(_viewportHeaderOwners!.keys);
    final plan = _sectionPlan;
    for (var s = 0; s < plan.segments.length; s++) {
      final segment = plan.segments[s];
      if (segment is StaticSegment || segment is LinearSegment && segment.fixed != null && segment.itemCount > 0) {
        _keepAliveIndices.add(plan.itemStartOf(s));
        if (segment is LinearSegment && segment.fixed?.itemStride == 2 && segment.itemCount > 1) {
          _keepAliveIndices.add(plan.itemStartOf(s) + 1);
        }
      }
    }
  }

  /// "当前钉住的 sticky" = 已识别集合中最后一个 layoutOffsetOfItem <= 有效
  /// scroll offset + 自身吸附偏移的 sticky。返回 null 表示无。
  /// 单钉 + 接力语义：按 index 升序取最后一个满足自身判据者，异质 offset
  /// 的重叠堆叠不支持（与 render 侧 [_computeStickyResolution] 同口径）。
  ///
  /// 主轴四方向通用：`effectiveOffset` 与 `_layoutOffsetOfItem` 都是内容
  /// 口径（布局恒正向、reverse 只翻像素锚定端且已在 offset 换算层归一化），
  /// 判据对 horizontal / reverse 天然成立。
  int? _computePinnedStickyIndex(double effectiveOffset) {
    if (_stickyByIndex.isEmpty) return null;
    // 判据对 index 单调（layoutOffsetOfItem 随 index 递增，stickyOffset 视作
    // 同质），改二分：每 tick 从 O(#sticky × log n) 降到 O(log #sticky × log n)，
    // 顺带消掉 SplayTreeMap 迭代器与 MapEntry 分配。
    final indices = _sortedStickyIndices();
    var low = 0;
    var high = indices.length - 1;
    int? pinned;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final index = indices[mid];
      final stickyOffset = _stickyByIndex[index]! + _viewportHeaderExtent;
      final layoutStart = _layoutOffsetOfItem(index) - _mainAxisLeadingPadding;
      if (layoutStart <= effectiveOffset + stickyOffset + precisionErrorTolerance) {
        pinned = index;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return pinned;
  }

  /// 升序 sticky index 快照（缓存：`_stickyByIndex` 变更处置空）。
  List<int> _sortedStickyIndices() {
    return _sortedStickyIndicesCache ??= List<int>.of(_stickyByIndex.keys, growable: false);
  }

  void _invalidateSortedStickyIndices() => _sortedStickyIndicesCache = null;

  void _refreshVisibleRangeAndCommit({bool forceContentSnapshot = false, bool forceContentLayout = false}) {
    _applyVisibleRangeUpdate(
      _recomputeVisibleRangeWithDetail(),
      forceContentSnapshot: forceContentSnapshot,
      forceContentLayout: forceContentLayout,
    );
  }

  void _commitContentSnapshot({required bool reconcileChildren, bool forceLayout = false}) {
    if (_scrollDebugCountersEnabled) _debugCounters!.recordContentSnapshotUpdate();
    _contentController.updateSnapshot(
      _createContentSnapshot(),
      reconcileChildren: reconcileChildren,
      forceLayout: forceLayout,
      notify: reconcileChildren,
    );
    if (reconcileChildren) return;
    final element = _viewportKey.currentContext;
    if (element is _ScrollViewportElement) {
      element.applyControllerSnapshotWithoutReconcile();
    }
  }

  /// Content offset used to choose the mounted window.
  ///
  /// Normally this is the synchronous [ScrollPosition] mapped into content
  /// coordinates. During an active scrollbar drag it is derived from the held
  /// thumb's visual fraction instead. That does not make the scroll model
  /// browser-style asynchronous: measured extents still update immediately, and
  /// the fraction is only a pointer-to-window mapping while the thumb is held.
  double _effectiveContentOffsetForVisibleRange() {
    final maxOffset = _maxLayoutScrollOffset;
    final dragFraction = _scrollbarThumbDragFraction;
    if (_dragOptimizeEnabled && _scrollbarDragging && dragFraction != null) {
      return _contentOffsetForScrollbarThumbFraction(dragFraction, maxOffset);
    }
    return _contentScrollOffset(maxOffset);
  }

  /// Maps a held scrollbar thumb position into content coordinates.
  ///
  /// [thumbFraction] is a track fraction, not a durable scroll state. It is
  /// allowed to map to a different item after measurements refine the extent
  /// model; that correction is preferable to keeping an inaccurate estimated
  /// range.
  /// visualFraction ≡ 内容偏移分数（与 [_rawThumbRect] / viewport render 的
  /// `_positionPixelsForVisualFraction` 同口径）；反向轴把 content→pixels 的
  /// 翻转放在像素换算侧，这里不再二次反转。判据委托 geometry 模块。
  double _contentOffsetForScrollbarThumbFraction(double thumbFraction, double maxOffset) =>
      VirtualScrollGeometry.contentOffsetForFraction(thumbFraction, maxOffset);

  /// Expands the mounted window when estimates may be wrong.
  ///
  /// The range computed from the prefix index is exact for measured rows and
  /// approximate for unknown rows. When thumb dragging, selection retention, or
  /// environment drift makes underfill possible, this method mounts a
  /// conservative extra window based on the smallest observed extent so the
  /// viewport stays filled while the exact measurements stream in.
  _VirtualIndexRange? _variableHeightFillRange({
    required int first,
    required int last,
    required double start,
    required double end,
    required int count,
  }) {
    final dragFraction = _scrollbarThumbDragFraction;
    final scrollbarEdgeDrag =
        _scrollbarDragging && dragFraction != null && VirtualScrollGeometry.isEdgeFraction(dragFraction);
    final scrollbarNeedsConservativeFill =
        _scrollbarDragging && (scrollbarEdgeDrag || _rangeHasUnmeasuredExtent(first, last));
    // 已实测窗口的环境变高由同帧 underflow 补齐，不为确认环境额外挂未知行。
    final needsConservativeFill =
        scrollbarNeedsConservativeFill ||
        _minimumVisibleLastIndex != null ||
        (_extentEnvironmentDriftedFromMeasured && _rangeHasUnmeasuredExtent(first, last));
    if (!needsConservativeFill) return null;
    if (count <= 0 || first >= count) {
      return null;
    }
    final plan = _sectionPlan;
    final firstRowForExtent = plan.rowOfItem(first);
    final fixedExtent = plan.fixedExtentOfRow(firstRowForExtent);
    final observedExtent = _minimumObservedItemExtent;
    // grid 的 mainAxisExtent / aspectRatio 在 plan 里已经能给出精确行高，冷拖
    // 时不能再拿变高段的均值扩窗，否则宽屏照片墙会无谓多挂数倍 cell。
    final fallbackExtent = fixedExtent != null && fixedExtent > precisionErrorTolerance
        ? fixedExtent
        : _extentIndex.estimatedExtent;
    final extent = ((observedExtent == null ? fallbackExtent : math.min(observedExtent, fallbackExtent)) + _gap)
        .clamp(1.0, double.infinity)
        .toDouble();
    final firstStart = _layoutOffsetOfItem(first);
    final neededExtent = math.max(end - math.min(start, firstStart), _viewportExtent);
    // Cap the conservative window: a pathologically small observed extent
    // (e.g. a single 1px row) must not mount hundreds of rows in one frame.
    // Real underfill beyond the cap is corrected by the underflow report loop,
    // which grows the window from actual laid-out sizes.
    // extent index 按「行」记账，neededExtent / extent 得到的也是行数。这里
    // 必须始终留在行空间扩窗，最后才映射回扁平 item；直接拿它减 itemCount
    // 会让 N 列 grid 只挂约 1/N 的行，并从行中间切入产生大片空白。
    final neededRowCount = math.min(math.max(1, (neededExtent / extent).ceil() + 1), _maxConservativeFillCount);
    // 纯列表保持原来的 item==row 算术快路，新增网格修正不给主流列表拖拽
    // 增加任何二分或映射成本。
    if (plan.isRowPerItem) {
      if (dragFraction != null && dragFraction >= 1.0 - precisionErrorTolerance) {
        final nextFirst = math.max(0, count - neededRowCount);
        return nextFirst == first && last == count ? null : _VirtualIndexRange(nextFirst, count);
      }
      var nextFirst = first;
      final nextLast = math.max(last, math.min(count, first + neededRowCount));
      if (nextLast == count && count - nextFirst < neededRowCount) {
        nextFirst = math.max(0, count - neededRowCount);
      }
      if (nextFirst == first && nextLast == last) return null;
      return _VirtualIndexRange(nextFirst, nextLast);
    }
    final totalRows = plan.totalRowCount;
    if (totalRows <= 0) return null;
    final firstRow = plan.rowOfItem(first);
    final lastRowExclusive = last <= first
        ? firstRow
        : math.min(totalRows, plan.rowOfItem(math.min(last, count) - 1) + 1);
    if (dragFraction != null && dragFraction >= 1.0 - precisionErrorTolerance) {
      final nextFirstRow = math.max(0, totalRows - neededRowCount);
      final nextFirst = plan.firstItemOfRow(nextFirstRow);
      return nextFirst == first && last == count ? null : _VirtualIndexRange(nextFirst, count);
    }
    var nextFirstRow = firstRow;
    final nextLastRow = math.max(lastRowExclusive, math.min(totalRows, firstRow + neededRowCount));
    if (nextLastRow == totalRows && totalRows - nextFirstRow < neededRowCount) {
      nextFirstRow = math.max(0, totalRows - neededRowCount);
    }
    final nextFirst = plan.firstItemOfRow(nextFirstRow);
    final nextLast = nextLastRow == totalRows ? count : plan.firstItemOfRow(nextLastRow);
    if (nextFirst == first && nextLast == last) return null;
    return _VirtualIndexRange(nextFirst, nextLast);
  }

  /// [start, end) 为 **item** 区间；Fenwick 按行记账，判定按行去重后逐行查。
  bool _rangeHasUnmeasuredExtent(int start, int end) {
    if (end <= start) return true;
    final plan = _sectionPlan;
    final firstRow = plan.rowOfItem(start.clamp(0, math.max(plan.totalItemCount - 1, 0)).toInt());
    final lastRow = plan.rowOfItem((end - 1).clamp(0, math.max(plan.totalItemCount - 1, 0)).toInt());
    for (var row = firstRow; row <= lastRow && row < _extentIndex.count; row++) {
      if (!_extentIndex.isMeasured(row)) return true;
    }
    return false;
  }

  /// item 所在行的模型 extent（行空间安全查询；越界 0）。
  double _rowExtentOfItem(int index) {
    final row = _sectionPlan.rowOfItem(index);
    return row >= 0 && row < _extentIndex.count ? _extentIndex.extentOf(row) : 0.0;
  }

  double _currentScrollOffset() {
    if (!_controller.hasClients) return _scrollOffset;
    return _controller.position.pixels;
  }

  // --- item client / lazy image 几何 ---

  bool _imageDecodeVisibleFor(int index) {
    final count = _effectiveChildren.length;
    final item = _mountedItemRender(index);
    if (item != null) {
      final data = item.parentData! as _ScrollViewportParentData;
      if (data.zIndex < 0) return false;
      if (item.hasSize && data.isPositionedForLayout) {
        final viewport = item.parent! as _RenderVirtualViewport;
        return !(data.offset & item.size).intersect(Offset.zero & viewport.size).isEmpty;
      }
    }
    if (widget.shrinkWrap) return index >= 0 && index < count;
    if (count == 0 || _viewportExtent <= 0) return false;
    final total = _totalLayoutExtent;
    final maxOffset = math.max(total - _viewportExtent, 0.0);
    final dragFraction = _scrollbarThumbDragFraction;
    final currentOffset = _dragOptimizeEnabled && _scrollbarDragging && dragFraction != null
        ? _contentOffsetForScrollbarThumbFraction(dragFraction, maxOffset)
        : () {
            final pixels = _currentScrollOffset().clamp(0.0, maxOffset).toDouble();
            return _isAxisReversed ? maxOffset - pixels : pixels;
          }();
    final start = currentOffset.clamp(0.0, total).toDouble();
    final end = math.min(total, start + _viewportExtent);
    final first = _itemIndexAtLayoutOffset(start).clamp(0, count).toInt();
    final last = _firstItemWithLayoutStartAtOrAfter(end).clamp(first, count).toInt();
    return index >= first && index < last;
  }

  int _imageDecodePriorityFor(int index) => _imageDecodeForward ? index : -index;

  void _dispatchMixinItemSnapshots() {
    final buckets = _mixinItemClientsByIndex;
    if (!_mixinCallbacksActive || buckets == null || buckets.isEmpty) return;
    final bucketEntries = _mixinItemBuckets;
    for (final entry in bucketEntries) {
      final index = entry.key;
      ElScrollItemSnapshot? itemSnapshot;
      final clients = entry.value.toList(growable: false);
      for (final client in clients) {
        final registration = _mixinClients?[client];
        if (registration == null ||
            registration.itemIndex != index ||
            !client.mountedForScrollCallbacks ||
            (!registration.wantsScrollItemUpdates &&
                !registration.wantsScrollItemSize &&
                !registration.viewportHeader &&
                registration.stickyOffset == null)) {
          continue;
        }
        itemSnapshot ??= _buildScrollItemSnapshot(index);
        if (!_shouldDispatchScrollItemSnapshot(registration, itemSnapshot)) continue;
        final previous = registration.lastItemSnapshot;
        registration.lastItemSnapshot = itemSnapshot;
        client.handleScrollItemChanged(
          ElScrollItemUpdateDetails(scrollView: this, previousSnapshot: previous, snapshot: itemSnapshot),
        );
      }
    }
  }

  void _scheduleVisibilityDispatch() {
    // 几何效果不等于可见性订阅；没有真实消费者时，不排队也不复制登记集合。
    if (widget.onVisibleRangeChanged == null && !_hasMixinItemVisibilityClients) return;
    _visibilityDispatchPassRequested = true;
    if (_visibilityDispatchScheduled || !mounted) return;
    _visibilityDispatchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityDispatchScheduled = false;
      if (!mounted || !_visibilityDispatchPassRequested) return;
      _visibilityDispatchPassRequested = false;
      _dispatchVisibility();
    });
  }

  void _dispatchVisibleRange() {
    final count = _effectiveChildren.length;
    final visibleFirst = _firstIndex.clamp(0, count).toInt();
    final visibleLastComputed = _lastIndex.clamp(visibleFirst, count).toInt();
    // 严格可视 index 集：跟 render 层用 _visibleContentStart/End 一致的判定。
    // mounted 窗口就是当前 State 持的 [_firstIndex, _lastIndex)。可视窗口
    // 通常等于 mounted（cache=0）或更小（cache>0）——用 layoutOffset 判定
    // item 主轴区间与 [_visibleContentStart, _visibleContentEnd) 的交叠。
    var firstVisible = count;
    var lastVisible = 0;
    final headerExtent = _viewportHeaderExtent;
    final viewportExtent = math.max(_viewportExtent - headerExtent, 0.0);
    final scrollOffset = _contentScrollOffset();
    for (var index = visibleFirst; index < visibleLastComputed; index++) {
      final fraction = _visibilityFractionForIndex(index, scrollOffset, headerExtent, viewportExtent);
      if (fraction > 0.0) {
        if (index < firstVisible) firstVisible = index;
        if (index + 1 > lastVisible) lastVisible = index + 1;
      }
    }
    if (firstVisible > lastVisible) {
      firstVisible = 0;
      lastVisible = 0;
    }

    // 列表级回调：range 变化才发。
    final nextRange = ElVisibleRange(
      first: firstVisible,
      last: lastVisible,
      mountedFirst: visibleFirst,
      mountedLast: visibleLastComputed,
    );
    if (_lastVisibleRange != nextRange) {
      _lastVisibleRange = nextRange;
      widget.onVisibleRangeChanged?.call(nextRange);
    }
  }

  void _dispatchVisibility() {
    if (_scrollDebugCountersEnabled) _debugCounters!.debugVisibilityDispatchCount++;
    if (widget.onVisibleRangeChanged != null) _dispatchVisibleRange();
    if (!_hasMixinItemVisibilityClients) return;
    // item 级：同一 index 的所有 client 共享同一个不可变 snapshot。回调期间
    // 允许 setState / 改登记，因此桶和 client 均先取快照再走身份校验。
    final buckets = _mixinItemClientsByIndex;
    if (buckets == null || buckets.isEmpty) return;
    final bucketEntries = _mixinItemBuckets;
    for (final entry in bucketEntries) {
      final index = entry.key;
      ElScrollItemSnapshot? itemSnapshot;
      final clients = entry.value.toList(growable: false);
      for (final client in clients) {
        final registration = _mixinClients?[client];
        if (registration == null || registration.itemIndex != index || !client.mountedForScrollCallbacks) continue;
        if (!registration.tracksScrollItemVisibility) continue;
        itemSnapshot ??= _buildScrollItemSnapshot(index);
        final visibilityChanged =
            !registration.visibilityDispatched || registration.lastVisible != itemSnapshot.isVisible;
        final fractionChanged =
            registration.tracksScrollItemVisibleFraction &&
            (registration.lastVisibleFraction - itemSnapshot.visibleFraction).abs() > precisionErrorTolerance;
        if (!visibilityChanged && !fractionChanged) continue;
        registration.visibilityDispatched = true;
        registration.lastVisible = itemSnapshot.isVisible;
        registration.lastVisibleFraction = itemSnapshot.visibleFraction;
        client.handleScrollItemVisibilityChanged(
          ElVisibilityInfo(
            index: index,
            visible: itemSnapshot.isVisible,
            visibleFraction: itemSnapshot.visibleFraction,
          ),
        );
      }
    }
  }

  /// item 与可视区在主轴上的交叠比例。未 mounted 或不在可视区 → 0。
  /// grid 下按其所在**行**的主轴几何算（同行 cell 的 fraction 相同）。
  double _visibilityFractionForIndex(int index, double scrollOffset, double headerExtent, double viewportExtent) {
    final item = _mountedItemRender(index);
    final data = item?.parentData as _ScrollViewportParentData?;
    if (data != null && data.zIndex < 0) return 0.0;
    if (item != null && item.hasSize && (data!.isPositionedForLayout || data.isViewportHeader)) {
      return _buildScrollItemSnapshot(index).visibleFraction;
    }
    // 范围回调只用交叠比例，不创建成员快照或计算进度、挂载与吸顶状态。
    final extent = math.max(_rowExtentOfItem(index), 0.0);
    if (extent <= precisionErrorTolerance) return 0.0;
    final leading = _layoutOffsetOfItem(index) - scrollOffset - headerExtent;
    final overlap = math.max(math.min(leading + extent, viewportExtent) - math.max(leading, 0.0), 0.0);
    return (overlap / extent).clamp(0.0, 1.0);
  }

  // --- ScrollIndexBridge 实现 ---
  //
  // estimate 前缀和收敛策略：目标 index 的偏移可能是估计值，jumpTo 后新窗口
  // 挂载会触发目标附近真实度量，度量上报再改前缀和 → 目标 offset 就漂移。
  // 我们在 jumpToIndex 里跑一个多帧循环：每帧 endOfFrame 后重算目标、若差异
  // >=0.5px 就再 jump 一次，否则收敛结束；上限 10 帧防死循环。animateToIndex
  // 走两段式：animateTo(estimate) 落点后再跑 jump 收敛，v1 不做逐帧修正以免
  // 打断动画曲线（注释见方法内）。

  static const int _scrollToIndexMaxIterations = 10;
  static const double _scrollToIndexConvergedDelta = 0.5;
  ScrollMotionOwner? _scrollToIndexMotionOwner;

  bool _jumpForIndexOperation(double pixels) {
    final owner = _scrollToIndexMotionOwner;
    if (owner != null) return owner.position.jumpToOwned(owner, pixels);
    _controller.jumpTo(pixels);
    return true;
  }

  /// 计算目标 pixels：把 index 的主轴内容位置按 alignment 对齐到视口，clamp 到
  /// `[0, maxScrollExtent]`，reverse 轴做 max - offset 翻转。
  double _pixelsForIndex(int safeIndex, double alignment) {
    final maxOffset = _maxLayoutScrollOffset;
    final itemStart = _layoutOffsetOfItem(safeIndex);
    final itemExtent = _rowExtentOfItem(safeIndex);
    final visibleSlack = math.max(_viewportExtent - itemExtent, 0.0);
    final targetContentOffset = (itemStart - visibleSlack * alignment.clamp(0.0, 1.0)).clamp(0.0, maxOffset).toDouble();
    return _isAxisReversed ? maxOffset - targetContentOffset : targetContentOffset;
  }

  /// clamp index 并 debug 断言越界。
  int _sanitizeScrollToIndex(int index) {
    final count = _effectiveChildren.length;
    assert(count > 0, 'scrollToIndex 在空列表上调用无意义。');
    if (count <= 0) return 0;
    assert(index >= 0 && index < count, 'scrollToIndex: index $index 超出范围 [0, $count)，已 clamp。');
    return index.clamp(0, count - 1).toInt();
  }

  @override
  Future<bool> jumpToIndex(int index, {required double alignment}) {
    if (!mounted) return Future<bool>.value(false);
    final count = _effectiveChildren.length;
    if (count <= 0 || !_controller.hasClients) return Future<bool>.value(false);
    final safeIndex = _sanitizeScrollToIndex(index);
    final operation = _beginScrollToIndexOperation();
    _startJumpToIndexOperation(
      safeIndex: safeIndex,
      alignment: alignment,
      epoch: operation.epoch,
      completer: operation.completer,
    );
    return operation.completer.future;
  }

  ({int epoch, Completer<bool> completer}) _beginScrollToIndexOperation() {
    _cancelScrollToIndexOperation();
    final completer = Completer<bool>();
    _scrollToIndexCompleter = completer;
    final epoch = ++_scrollToIndexEpoch;
    if (_controller.position case final ScrollEnginePosition target) {
      _scrollToIndexMotionOwner = target.claimMotion(
        cause: ElScrollUpdateCause.navigation,
        onCancelled: () => _cancelSpecificScrollToIndexOperation(epoch, completer),
      );
    }
    return (epoch: epoch, completer: completer);
  }

  void _completeScrollToIndexOperation(int epoch, Completer<bool> completer) {
    if (!completer.isCompleted) completer.complete(true);
    if (epoch == _scrollToIndexEpoch && identical(_scrollToIndexCompleter, completer)) {
      _scrollToIndexCompleter = null;
      final owner = _scrollToIndexMotionOwner;
      _scrollToIndexMotionOwner = null;
      if (owner != null) owner.position.completeMotion(owner);
    }
    if (_scrollToIndexAnimatingEpoch == epoch) _scrollToIndexAnimatingEpoch = null;
  }

  void _cancelSpecificScrollToIndexOperation(int epoch, Completer<bool> completer) {
    if (!completer.isCompleted) completer.complete(false);
    if (epoch == _scrollToIndexEpoch && identical(_scrollToIndexCompleter, completer)) {
      _scrollToIndexEpoch++;
      _scrollToIndexCompleter = null;
      final owner = _scrollToIndexMotionOwner;
      _scrollToIndexMotionOwner = null;
      if (owner != null) owner.position.cancelMotion(owner);
    }
    if (_scrollToIndexAnimatingEpoch == epoch) _scrollToIndexAnimatingEpoch = null;
  }

  @override
  bool cancelScrollToIndex() => _cancelScrollToIndexOperation();

  bool _cancelScrollToIndexOperation() {
    final completer = _scrollToIndexCompleter;
    if (completer == null) return false;
    final epoch = _scrollToIndexEpoch;
    final owner = _scrollToIndexMotionOwner;
    _scrollToIndexEpoch++;
    _scrollToIndexCompleter = null;
    _scrollToIndexMotionOwner = null;
    final stopsIndexAnimation = _scrollToIndexAnimatingEpoch == epoch;
    if (owner != null) {
      _scrollToIndexAnimatingEpoch = null;
      owner.position.cancelMotion(owner);
    } else if (stopsIndexAnimation) {
      _scrollToIndexAnimatingEpoch = null;
      if (_controller.hasClients) {
        try {
          final pixels = _controller.position.pixels;
          _controller.jumpTo(pixels);
        } catch (_) {
          // controller 正在解绑时 position 可能已释放；取消仍需可靠结清。
        }
      }
    }
    if (!completer.isCompleted) completer.complete(false);
    return true;
  }

  void _startJumpToIndexOperation({
    required int safeIndex,
    required double alignment,
    required int epoch,
    required Completer<bool> completer,
  }) {
    if (epoch != _scrollToIndexEpoch || completer.isCompleted || !mounted || !_controller.hasClients) {
      _cancelSpecificScrollToIndexOperation(epoch, completer);
      return;
    }
    // 首帧：立即定位到 estimate 目标；后续每一帧末尾的 post-frame 回调继续
    // 重算与修正——用 completer + addPostFrameCallback 而非 `await endOfFrame`：
    // 测试驱动下 `await` 会阻塞 test flow 使 pump 永不发生，导致死锁。
    final initialTarget = _pixelsForIndex(safeIndex, alignment);
    try {
      if (!_jumpForIndexOperation(initialTarget)) {
        _cancelSpecificScrollToIndexOperation(epoch, completer);
        return;
      }
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      _cancelSpecificScrollToIndexOperation(epoch, completer);
      return;
    }
    _scheduleScrollToIndexIteration(
      safeIndex: safeIndex,
      alignment: alignment,
      epoch: epoch,
      completer: completer,
      iteration: 0,
    );
  }

  void _scheduleScrollToIndexIteration({
    required int safeIndex,
    required double alignment,
    required int epoch,
    required Completer<bool> completer,
    required int iteration,
  }) {
    if (iteration >= _scrollToIndexMaxIterations) {
      _cancelSpecificScrollToIndexOperation(epoch, completer);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (epoch != _scrollToIndexEpoch || completer.isCompleted || !mounted || !_controller.hasClients) {
        _cancelSpecificScrollToIndexOperation(epoch, completer);
        return;
      }
      // pending 修正（anchor / measurement）在同一 post-frame 阶段仍会跑；
      // 让它们先落地再重算目标。
      _applyPendingScrollCorrectionOrSchedule(notify: false);
      final nextTarget = _pixelsForIndex(safeIndex, alignment);
      final delta = (nextTarget - _controller.position.pixels).abs();
      if (delta <= _scrollToIndexConvergedDelta) {
        _completeScrollToIndexOperation(epoch, completer);
        return;
      }
      if (!_jumpForIndexOperation(nextTarget)) {
        _cancelSpecificScrollToIndexOperation(epoch, completer);
        return;
      }
      _scheduleScrollToIndexIteration(
        safeIndex: safeIndex,
        alignment: alignment,
        epoch: epoch,
        completer: completer,
        iteration: iteration + 1,
      );
    });
  }

  @override
  Future<bool> animateToIndex(
    int index, {
    required double alignment,
    required Duration duration,
    required Curve curve,
  }) {
    if (!mounted) return Future<bool>.value(false);
    final count = _effectiveChildren.length;
    if (count <= 0 || !_controller.hasClients) return Future<bool>.value(false);
    final safeIndex = _sanitizeScrollToIndex(index);
    final operation = _beginScrollToIndexOperation();
    unawaited(
      _runAnimateToIndexOperation(
        safeIndex: safeIndex,
        alignment: alignment,
        duration: duration,
        curve: curve,
        epoch: operation.epoch,
        completer: operation.completer,
      ),
    );
    return operation.completer.future;
  }

  Future<void> _runAnimateToIndexOperation({
    required int safeIndex,
    required double alignment,
    required Duration duration,
    required Curve curve,
    required int epoch,
    required Completer<bool> completer,
  }) async {
    final target = _pixelsForIndex(safeIndex, alignment);
    // v1 简化：动画过程中不做逐帧修正——曲线被打断观感差；落点后再走 jump
    // 收敛校正 estimate 误差（两段式）。
    _scrollToIndexAnimatingEpoch = epoch;
    try {
      final owner = _scrollToIndexMotionOwner;
      if (owner == null) {
        await _controller.animateTo(target, duration: duration, curve: curve);
      } else {
        await owner.position.animateToOwned(owner, target, duration: duration, curve: curve);
      }
    } catch (error, stackTrace) {
      if (epoch == _scrollToIndexEpoch && !completer.isCompleted) {
        completer.completeError(error, stackTrace);
        _cancelSpecificScrollToIndexOperation(epoch, completer);
      }
      return;
    } finally {
      if (_scrollToIndexAnimatingEpoch == epoch) _scrollToIndexAnimatingEpoch = null;
    }
    if (epoch != _scrollToIndexEpoch || completer.isCompleted || !mounted) {
      _cancelSpecificScrollToIndexOperation(epoch, completer);
      return;
    }
    _startJumpToIndexOperation(safeIndex: safeIndex, alignment: alignment, epoch: epoch, completer: completer);
  }

  bool get _isAxisReversed => axisDirectionIsReversed(_axisDirection);

  double _contentScrollOffset([double? maxOffset]) {
    final max = maxOffset ?? _maxLayoutScrollOffset;
    final pixels = _scrollOffset.clamp(0.0, max).toDouble();
    return _isAxisReversed ? max - pixels : pixels;
  }

  int _anchorIndexAtContentOffset(double contentOffset, int count) {
    if (count <= 0) return 0;
    final safeOffset = contentOffset.clamp(0.0, math.max(_totalLayoutExtent, 0.0)).toDouble();
    return _itemIndexAtLayoutOffset(safeOffset).clamp(0, count - 1).toInt();
  }

  ({int index, double delta})? _mountedAnchorAtContentOffset(
    double contentOffset, {
    double? within,
    bool Function(int index)? skip,
    bool useModelOffsets = false,
  }) {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is! _RenderVirtualViewport) return null;
    return renderObject.anchorAtContentOffset(
      contentOffset,
      within: within,
      skip: skip,
      useModelOffsets: useModelOffsets,
    );
  }

  /// 贴边判据委托 geometry 模块（与 content render / viewport render 同源）。
  VirtualScrollEdge? _pinnedScrollPositionEdge(double pixels, double maxOffset) =>
      VirtualScrollGeometry.pinnedEdge(pixels, maxOffset);

  void _scheduleScrollClamp() {
    if (_jumpScheduled || !mounted) return;
    _jumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpScheduled = false;
      _applyPendingScrollCorrectionOrSchedule();
    });
  }

  bool _applyPendingScrollCorrectionOrSchedule({bool notify = true}) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      _schedulePendingScrollCorrectionFrame(notify: notify);
      return false;
    }
    return _applyPendingScrollCorrection(notify: notify);
  }

  void _schedulePendingScrollCorrectionFrame({required bool notify}) {
    if (!mounted) return;
    _scrollCorrectionFrameNotify = _scrollCorrectionFrameNotify || notify;
    if (_scrollCorrectionFrameScheduled) return;
    _scrollCorrectionFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scrollCorrectionFrameScheduled = false;
      if (!mounted) return;
      final shouldNotify = _scrollCorrectionFrameNotify;
      _scrollCorrectionFrameNotify = false;
      final corrected = _applyPendingScrollCorrection(notify: shouldNotify);
      if (corrected) {
        _refreshVisibleRangeAndCommit(forceContentSnapshot: true, forceContentLayout: true);
      }
    });
  }

  bool _applyPendingScrollCorrection({bool notify = true}) {
    if (!mounted || !_controller.hasClients) return false;
    // 未取得首窗样本时总长只是占位，不能据此截断 initialScrollOffset / PageStorage 恢复值。
    if (_measuringInitialWindow) return false;
    // 越界期间（bouncing 拉伸 / 下拉刷新停靠 / finishing 送回）pixels 归滚动
    // 物理与活动所有，模型锚点修正一律弃权并丢弃 pending：捕获/应用两侧的
    // clamp 会把越界量误当"钉在边缘"抹掉——correctPixels(0) 让停靠内容闪跳
    // 到顶、下一帧收起动画又拽回，用户看到刷新结束"回弹一次"。边缘内容不
    // 依赖锚点补偿：min 侧首项恒在 0，max 侧回位由 ballistic 按新鲜 metrics
    // 收口。
    final position = _controller.position;
    if (position.hasPixels && position.hasContentDimensions) {
      final beyondMin = position.pixels < position.minScrollExtent - precisionErrorTolerance;
      final beyondMax = position.pixels > position.maxScrollExtent + precisionErrorTolerance;
      if (beyondMin || beyondMax) {
        _pendingScrollPositionEdge = null;
        _pendingAnchorIndex = null;
        _scrollOffset = _currentScrollOffset();
        return false;
      }
    }
    final maxOffset = _maxLayoutScrollOffset;
    double? target;
    final edge = _pendingScrollPositionEdge;
    if (edge != null) {
      _pendingScrollPositionEdge = null;
      _pendingAnchorIndex = null;
      target = switch (edge) {
        VirtualScrollEdge.min => 0.0,
        VirtualScrollEdge.max => maxOffset,
      };
    } else {
      final anchorIndex = _pendingAnchorIndex;
      if (anchorIndex != null) {
        _pendingAnchorIndex = null;
        final contentOffset = (_layoutOffsetOfItem(anchorIndex) - _pendingAnchorDelta).clamp(0.0, maxOffset).toDouble();
        final staleTarget = _isAxisReversed ? maxOffset - contentOffset : contentOffset;
        // 增量化修正：staleTarget 恢复的是捕获时刻的内容位置 + 模型偏移，
        // 补上捕获→应用之间的滚动位移（惯性/拖拽仍在推进），只补偿模型
        // 偏移、不回卷用户滚动。
        final advance = _currentScrollOffset() - _pendingAnchorCapturePixels;
        target = (staleTarget + advance).clamp(0.0, maxOffset).toDouble();
      } else {
        final current = _controller.position.pixels;
        if (current > maxOffset) target = maxOffset;
      }
    }
    if (target == null || (_controller.position.pixels - target).abs() <= precisionErrorTolerance) {
      _scrollOffset = _currentScrollOffset();
      return false;
    }
    assert(() {
      if (ElScrollViewState._debugTraceCorrections) {
        debugPrint(
          '  [correction] pixels=${_controller.position.pixels.toStringAsFixed(1)} '
          '→ target=${target!.toStringAsFixed(1)} (Δ${(target - _controller.position.pixels).toStringAsFixed(1)}) '
          'notify=$notify max=${maxOffset.toStringAsFixed(1)}',
        );
      }
      return true;
    }());
    _recordMixinLayoutCorrection(_layoutAxis, target - _controller.position.pixels);
    if (notify) {
      if (position is ScrollEnginePosition) {
        position.correctLayoutPixels(target);
      } else {
        _controller.jumpTo(target);
      }
    } else {
      _controller.position.correctPixels(target);
    }
    _scrollOffset = _currentScrollOffset();
    return true;
  }

  /// 视口 performLayout 在 `invokeLayoutCallback` 窗口内直调：吃约束、算窗口、
  /// 同帧对账 content children。
  ///
  /// why：原先这段挂在 build 的 LayoutBuilder 体里（包内禁用官方行为类
  /// widget）。稳态帧此函数为 O(1) 空转——extent 等值早退、环境等值早退、
  /// 窗口未变不 reconcile，构成"推送型组件"要求的幂等闸门，不会自激。
  void _handleLayoutMetrics(double viewportExtent, double crossAxisExtent) {
    // 完整子内容布局首次会先用临时尺寸触发一次全量子项挂载与度量，
    // 此值不是实际视口。若把它当成真实尺寸，贴底时会先把 pixels 校正到
    // contentHeight，随后最终视口回填又拒绝处理这个已越界的位置，形成整块
    // 内容被移出视口的空白暗区。
    if (viewportExtent.isFinite && (!widget.shrinkWrap || viewportExtent > precisionErrorTolerance)) {
      _handleViewportExtentChanged(viewportExtent);
    }
    // 交叉轴宽变化只被 grid 段消费（列数/固定行高派生）：仅 grid 在场才
    // 重建 plan（facade/memo 一并换新是重建的副作用，纯 linear/static 形态
    // 绝不为 resize 付这笔——交叉轴引发的行高变化由既有度量环境漂移机制
    // 处理）。列数变化按整段行重建。
    final crossPadding = _layoutAxis == Axis.vertical ? widget.padding.horizontal : widget.padding.vertical;
    final crossForPlan = crossAxisExtent.isFinite ? math.max(crossAxisExtent - crossPadding, 0.0) : 0.0;
    if ((crossForPlan - _planCrossAxisExtent).abs() > precisionErrorTolerance) {
      _planCrossAxisExtent = crossForPlan;
      if (_segments.any((segment) => segment is GridSegment)) {
        _rebuildPlanFromSegments(geometryOnly: true);
        // 网格重算不丢弃同页列表的实测前缀，也不重新构建已有条目。
        _resetExtentIndexPreservingAnchor(_childrenSnapshot, null);
      }
    }
    final crossAxisPadding = _layoutAxis == Axis.vertical ? widget.padding.horizontal : widget.padding.vertical;
    // 行按 padded 交叉轴 extent 度量，故它才是度量环境的口径。
    //
    // 双轴：items 收无界交叉轴约束、按内容宽自然量（横向不虚拟化的
    // mounted-only 语义，不做 fill），度量环境的交叉轴口径取 ∞——
    // 视口宽变化不再影响 item 高度度量，无需按视口宽重新度量。
    // 单轴交叉轴无界时同口径透传，帧间稳定不触发重探；默认滚动壳会先在
    // render 层拒绝无界尺寸，shrinkWrap 则由完整子内容实测回填。
    final rowCrossAxisExtent = _isDualAxis || !crossAxisExtent.isFinite
        ? double.infinity
        : math.max(crossAxisExtent - crossAxisPadding, 0.0);
    _handleExtentEnvironmentChanged(
      _VirtualExtentEnvironment(
        crossAxisExtent: rowCrossAxisExtent,
        textScaler: _buildTextScaler,
        textDirection: _buildTextDirection,
      ),
    );
    _applyPendingScrollCorrection(notify: false);
    _scrollOffset = _currentScrollOffset();
    final windowChanged = _recomputeVisibleRange();
    // 快照每次 layout 都推（原 LayoutBuilder replaceSnapshot 口径），但
    // reconcile 脏位只在窗口真变时置起：进入行测量就地写 Fenwick 会触发同帧
    // 第二次 layout pass，无条件置脏 = 每个变窗帧多空跑一遍 reconcile（白付
    // 区间差分成本且覆盖 last 计数器）。children 变更等路径挂起的脏位经
    // updateSnapshot 内部的 `||` 保留，仍在本窗口落地。
    _contentController.updateSnapshot(_createContentSnapshot(), reconcileChildren: windowChanged, notify: false);
    _contentController.reconcileDuringLayout();
    if (windowChanged) _scheduleVisibilityDispatch();
  }

  void _handleViewportExtentChanged(double viewportExtent) {
    if ((_viewportExtent - viewportExtent).abs() <= precisionErrorTolerance) return;
    final oldViewportExtent = _viewportExtent;
    int? anchorIndex;
    double anchorDelta = 0.0;
    double capturePixels = 0.0;
    VirtualScrollEdge? pinnedEdge;
    if (oldViewportExtent > precisionErrorTolerance && _effectiveChildren.isNotEmpty) {
      final oldMaxOffset = _controller.hasClients && _controller.position.hasContentDimensions
          ? _controller.position.maxScrollExtent
          : math.max(_totalLayoutExtent - oldViewportExtent, 0.0);
      final oldPixels = _currentScrollOffset().clamp(0.0, oldMaxOffset).toDouble();
      pinnedEdge = _pinnedScrollPositionEdge(oldPixels, oldMaxOffset);
      final oldContentOffset = _isAxisReversed ? oldMaxOffset - oldPixels : oldPixels;
      final mountedAnchor = _mountedAnchorAtContentOffset(oldContentOffset);
      anchorIndex = mountedAnchor?.index ?? _anchorIndexAtContentOffset(oldContentOffset, _effectiveChildren.length);
      anchorDelta = mountedAnchor?.delta ?? _layoutOffsetOfItem(anchorIndex) - oldContentOffset;
      capturePixels = oldPixels;
    }
    _viewportExtent = viewportExtent;
    _scrollOffset = _currentScrollOffset();
    _minimumVisibleLastIndex = null;
    if (pinnedEdge != null) {
      _pendingScrollPositionEdge = pinnedEdge;
      _pendingAnchorIndex = null;
    } else if (anchorIndex != null) {
      _pendingAnchorIndex = anchorIndex;
      _pendingAnchorDelta = anchorDelta;
      _pendingAnchorCapturePixels = capturePixels;
    }
    final correctedNow = pinnedEdge == null && _applyPendingScrollCorrection(notify: false);
    _scheduleVisibleRangeUpdate();
    if (pinnedEdge != null || !correctedNow) _scheduleScrollClamp();
  }

  void _handleExtentEnvironmentChanged(_VirtualExtentEnvironment environment) {
    _extentEnvironment = environment;
    final measuredEnvironment = _measuredExtentEnvironment;
    if (measuredEnvironment == null) {
      _measuredExtentEnvironment = environment;
      _extentEnvironmentDriftedFromMeasured = false;
      return;
    }
    final driftedFromMeasured = measuredEnvironment.requiresMeasurementReset(environment);
    _extentEnvironmentDriftedFromMeasured = driftedFromMeasured;
    if (!driftedFromMeasured || _extentEnvironmentResetScheduled) return;
    if (measuredEnvironment.requiresImmediateMeasurementReset(environment)) {
      // Defer the discard so it never runs synchronously inside build().
      _scheduleExtentEnvironmentReset();
    }
  }

  void _scheduleExtentEnvironmentReset() {
    if (_extentEnvironmentResetScheduled || !mounted) return;
    _extentEnvironmentResetScheduled = true;
    WidgetsBinding.instance.endOfFrame.then((_) {
      _extentEnvironmentResetScheduled = false;
      if (!mounted) return;
      final currentEnvironment = _extentEnvironment;
      final measuredEnvironment = _measuredExtentEnvironment;
      if (currentEnvironment == null ||
          measuredEnvironment == null ||
          !measuredEnvironment.requiresImmediateMeasurementReset(currentEnvironment)) {
        _extentEnvironmentDriftedFromMeasured = false;
        return;
      }
      _measuredExtentEnvironment = currentEnvironment;
      _extentEnvironmentDriftedFromMeasured = false;
      _resetExtentIndexPreservingAnchor(_childrenSnapshot, null, discardMeasuredExtents: true);

      _applyPendingScrollCorrection(notify: false);
      _refreshVisibleRangeAndCommit(forceContentSnapshot: true, forceContentLayout: true);
      _scheduleScrollClamp();
    });
  }

  void _handleMeasurementsChanged(int? requestedLastIndex, {required bool duringLayout}) {
    if (!mounted) return;
    if (requestedLastIndex != null) {
      if (requestedLastIndex <= _lastIndex || requestedLastIndex <= _firstIndex) return;
      final nextLastIndex = requestedLastIndex.clamp(_lastIndex + 1, _effectiveChildren.length).toInt();
      if (_minimumVisibleLastIndex != null && _minimumVisibleLastIndex! >= nextLastIndex) return;
      _minimumVisibleLastIndex = nextLastIndex;
    }
    // 只有全部固定尺寸的内容可直接确认环境，变高段仍须等待真实行的度量报告。
    final onlyFixedContent =
        requestedLastIndex == null &&
        _segments.every(
          (segment) =>
              segment is GridSegment ||
              segment is LinearSegment &&
                  segment.resolvedFixedExtent != null &&
                  (segment.fixed!.itemStride == 1 || segment.itemCount < 2 || segment.fixed!.separatorExtent != null),
        );
    if (onlyFixedContent) {
      _measuredExtentEnvironment = _extentEnvironment;
      _extentEnvironmentDriftedFromMeasured = false;
    }
    _scrollOffset = _currentScrollOffset();
    final windowChanged = _recomputeVisibleRange();
    if (duringLayout) {
      // 尺寸模型更新后在同次布局补齐窗口，避免首条测量或变高收敛时露白。
      _contentController.updateSnapshot(_createContentSnapshot(), reconcileChildren: windowChanged, notify: false);
      _contentController.reconcileDuringLayout();
      _scheduleVisibilityDispatch();
    } else if (windowChanged) {
      _commitContentSnapshot(reconcileChildren: true);
    }
  }

  void _handleItemExtentsChanged(Map<int, double> extents) {
    if (extents.isEmpty) return;
    if (_scrollDebugCountersEnabled) _debugCounters!.recordItemExtentReportBatch(extents.length);
    _applyItemExtentsChanged(extents);
  }

  bool _environmentReportChangesMeasuredExtent(Map<int, double> extents) {
    if (!_extentEnvironmentDriftedFromMeasured || extents.isEmpty) return false;
    for (final MapEntry(:key, :value) in extents.entries) {
      if (key < 0 || key >= _extentIndex.count || !_extentIndex.isMeasured(key)) continue;
      if ((_extentIndex.extentOf(key) - value).abs() > precisionErrorTolerance) return true;
    }
    return false;
  }

  bool _recordObservedItemExtent(double extent) {
    if (!extent.isFinite || extent <= precisionErrorTolerance) return false;
    final previous = _minimumObservedItemExtent;
    if (previous != null && previous <= extent + precisionErrorTolerance) return false;
    _minimumObservedItemExtent = extent;
    return true;
  }

  void _handleScrollbarDragChanged(VirtualScrollbarDragStatus status) {
    _scrollOffset = _currentScrollOffset();
    final nextFraction = status.thumbFraction;
    final previousDragEdge = _scrollPositionEdgeForScrollbarThumbFraction(_scrollbarThumbDragFraction);
    final fractionChanged =
        nextFraction != _scrollbarThumbDragFraction &&
        (nextFraction == null ||
            _scrollbarThumbDragFraction == null ||
            (nextFraction - _scrollbarThumbDragFraction!).abs() > precisionErrorTolerance);
    final draggingChanged = _scrollbarDragging != status.dragging;
    if (!draggingChanged && !fractionChanged) return;
    _scrollbarDragging = status.dragging;
    if (draggingChanged && _mixinClients != null) {
      final update = _refreshMixinSnapshot(_layoutAxis);
      if (update != null) _dispatchMixinActivityChanged(_layoutAxis, update);
    }
    if (status.dragging) {
      _pendingScrollPositionEdge = null;
      _pendingAnchorIndex = null;
      if (nextFraction != null) {
        _setScrollbarThumbDragFraction(nextFraction);
        if (_dragOptimizeEnabled) {
          // 高回报率指针（120Hz 触摸 / 1000Hz 鼠标）一帧内触发多次 move，
          // 每次都同步重算窗口 + 提交快照是纯浪费且引入输入相位抖动。
          // 合并到帧回调：一帧只用最新 thumb 分数重算一次。
          //
          // thumb 按下会先 seed 当前 fraction（浮层/窗口，确保
          // 无 move 的尾缘 hold 也能启动 edge fill）。seed 时内容偏移未变且
          // 非边缘 → 窗口本就正确，跳过调度，避免 same-window 拖拽多一次
          // recompute。
          final atEdge = VirtualScrollGeometry.isEdgeFraction(nextFraction);
          final maxOffset = _maxLayoutScrollOffset;
          final target = _contentOffsetForScrollbarThumbFraction(nextFraction, maxOffset);
          final offsetChanged = (target - _contentScrollOffset(maxOffset)).abs() > precisionErrorTolerance;
          if (atEdge || offsetChanged) {
            _scheduleScrollbarDragRangeUpdate();
          }
        }
      }
    } else {
      final releaseEdge = _scrollPositionEdgeForScrollbarDragEdge(status.edge) ?? previousDragEdge;
      _scrollbarThumbDragFraction = null;
      _scrollbarDragHandledScrollOffset = null;
      if (releaseEdge != null) {
        // If the user released at either visual edge, preserve the edge in the
        // refined synchronous model. This may move ScrollPosition because
        // measured extents changed the true max/min while the thumb was held.
        _pendingScrollPositionEdge = releaseEdge;
        _pendingAnchorIndex = null;
        _applyPendingScrollCorrection();
        _refreshVisibleRangeAndCommit(forceContentSnapshot: true, forceContentLayout: true);
      }
      if (releaseEdge != null) _scheduleScrollClamp();
      _scheduleVisibleRangeUpdate();
    }
  }

  void _setScrollbarThumbDragFraction(double thumbFraction) {
    _scrollbarThumbDragFraction = thumbFraction.clamp(0.0, 1.0).toDouble();
    if (_dragOptimizeEnabled) {
      _updateScrollbarDragHandledContentOffset();
    } else {
      _scrollbarDragHandledScrollOffset = null;
    }
  }

  void _updateScrollbarDragHandledContentOffset() {
    final fraction = _scrollbarThumbDragFraction;
    if (!_scrollbarDragging || fraction == null) {
      _scrollbarDragHandledScrollOffset = null;
      return;
    }
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      _scrollbarDragHandledScrollOffset = null;
      return;
    }
    final position = _controller.position;
    final maxOffset = math.max(position.maxScrollExtent - position.minScrollExtent, 0.0);
    final contentOffset = _contentOffsetForScrollbarThumbFraction(fraction, maxOffset);
    // The render scrollbar already jumped ScrollPosition for this drag update.
    // Store the exact pixels we expect so `_handleScrollOffsetChanged` can
    // consume the resulting listener callback without recomputing the range a
    // second time from the same input.
    _scrollbarDragHandledScrollOffset =
        (_isAxisReversed ? position.maxScrollExtent - contentOffset : position.minScrollExtent + contentOffset)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
  }

  void _applyItemExtentsChanged(Map<int, double> extents) {
    if (_extentIndex.count == 0) return;
    final environmentChanged = _environmentReportChangesMeasuredExtent(extents);
    if (environmentChanged && _extentEnvironment != null) {
      // 已挂载真实行确认了新环境；屏外未测行继续使用当前估计，首条统一尺寸
      // 段由独立测量 slot 同帧刷新整段固定值。
      _measuredExtentEnvironment = _extentEnvironment;
      _extentEnvironmentDriftedFromMeasured = false;
    }
    if (_itemExtentsAreAlreadyMeasured(extents)) {
      // P2 帧内收敛后，报告通常已在 content layout 就地写入 Fenwick 并
      // correctBy 补偿像素，这里只剩簿记：最小观测 extent（conservative
      // fill 用）、估计刷新判定、吸收未经通知的像素修正并补算一次窗口
      // （静态画面也要收敛 mounted 集）。估计刷新是罕见事件，命中时继续
      // 走下方全量旧路（updateMeasuredExtent 全部无操作，刷新带着锚点
      // 补偿落地）。
      var confirmedMeasuredRow = false;
      for (final MapEntry(:key, :value) in extents.entries) {
        if (key < 0 || key >= _extentIndex.count) continue;
        _recordObservedItemExtent(value);
        confirmedMeasuredRow = true;
      }
      // 漂移收敛的"确认未变"臂：本批已测行在新环境下重报且与存量全部一致，
      // 说明新环境不改行高——把 measured 环境推进到当前环境并落 drift 标志。
      // 否则（`_environmentReportChangesMeasuredExtent` 只在不一致时
      // 为真）drift 恒真，P2 帧内测量收敛被永久关停、conservative fill 常开。
      final confirmedEnvironment =
          confirmedMeasuredRow && _extentEnvironmentDriftedFromMeasured && _extentEnvironment != null;
      if (confirmedEnvironment) {
        _measuredExtentEnvironment = _extentEnvironment;
        _extentEnvironmentDriftedFromMeasured = false;
      }
      if (!_shouldRefreshUnmeasuredEstimate()) {
        _scrollOffset = _currentScrollOffset();
        // 漂移验证结束后即使 mounted range 没变，也必须把 false 推回 content。
        // 否则 render 会永久停在“重报已测高度”模式，等高 tight 快路径失效。
        if (confirmedEnvironment) {
          _commitContentSnapshot(reconcileChildren: false);
        }
        _scheduleVisibleRangeUpdate();
        return;
      }
    }
    if (_scrollDebugCountersEnabled) _debugCounters!.recordApplyItemExtentsChanged();
    final oldMaxOffset = _maxLayoutScrollOffset;
    final oldPixels = _currentScrollOffset().clamp(0.0, oldMaxOffset).toDouble();
    var pinnedEdge = _pinnedScrollPositionEdge(oldPixels, oldMaxOffset);
    final oldContentOffset = _contentScrollOffset();
    // 虚拟估高修正跳过刚进入的行；真实内容变化仅在显式保位时跳过，
    // 否则会把正在展开的首个可见成员顶出视口。
    final changedExtentIndices = <int>{};
    var hasMeasuredRowChange = false;
    for (final MapEntry(:key, :value) in extents.entries) {
      if (key < 0 || key >= _extentIndex.count) continue;
      final measured = _extentIndex.isMeasured(key);
      if (measured && (_extentIndex.extentOf(key) - value).abs() <= precisionErrorTolerance) {
        continue;
      }
      final estimated = _rowUsesEstimatedExtent(key);
      if (widget.preserveAnchor || environmentChanged || estimated) {
        changedExtentIndices.add(key);
      }
      if (!estimated) hasMeasuredRowChange = true;
    }
    // 贴 max 钉边细分（[ElScrollView.pinToEnd]）：纯首测/估计收敛是估算
    // artifact，恒钉——保证 jumpTo(max) 类"回到底部"操作收敛到真实底部；
    // 批次含**已实测行**的尺寸变化（展开/流式长高等真实内容增长）时，跟随
    // 是显式 opt-in；是否保留原可见成员另由 preserveAnchor 决定。
    if (pinnedEdge == VirtualScrollEdge.max && !widget.pinToEnd && hasMeasuredRowChange) {
      pinnedEdge = null;
    }
    final mountedAnchor = _mountedAnchorAtContentOffset(
      oldContentOffset,
      within: _viewportExtent,
      skip: changedExtentIndices.isEmpty ? null : changedExtentIndices.contains,
      // 环境重排沿用窗口展示锚点；普通内容变高读取修改前的模型坐标。
      useModelOffsets: hasMeasuredRowChange && !environmentChanged,
    );
    final anchorIndex =
        mountedAnchor?.index ?? _anchorIndexAtContentOffset(oldContentOffset, _effectiveChildren.length);
    final anchorDelta = mountedAnchor?.delta ?? _layoutOffsetOfItem(anchorIndex) - oldContentOffset;
    var changed = false;
    var unanchoredDelta = 0.0;
    var unanchoredTotalDelta = 0.0;
    for (final MapEntry(:key, :value) in extents.entries) {
      if (key < 0 || key >= _extentIndex.count) continue;
      if (!_shouldAnchorMeasurement(key, environmentChanged: environmentChanged)) {
        final delta = value - _extentIndex.extentOf(key);
        unanchoredTotalDelta += delta;
        if (_sectionPlan.firstItemOfRow(key) < anchorIndex) unanchoredDelta += delta;
      }
      _recordObservedItemExtent(value);
      changed = _extentIndex.updateMeasuredExtent(key, value) || changed;
    }
    if (_shouldRefreshUnmeasuredEstimate()) {
      final measuredAverage = _extentIndex.measuredExtentAverage;
      if (measuredAverage != null && measuredAverage > precisionErrorTolerance) {
        changed = _refreshEstimatedExtents(measuredAverage) || changed;
      }
    }
    if (!changed) return;
    if (_scrollbarDragging && _scrollbarThumbDragFraction != null) {
      // Keep applying measurements while the scrollbar is held. Flutter scroll
      // is synchronous; deferring these updates would keep an inflated max
      // range alive and produce the classic bottom blank area.
      _updateScrollbarDragHandledContentOffset();
      _pendingScrollPositionEdge = _scrollPositionEdgeForScrollbarThumbFraction(_scrollbarThumbDragFraction);
      _pendingAnchorIndex = null;
      _minimumVisibleLastIndex = null;
    } else if (pinnedEdge != null) {
      _pendingScrollPositionEdge = pinnedEdge;
      _pendingAnchorIndex = null;
    } else {
      _pendingAnchorIndex = anchorIndex;
      _pendingAnchorDelta = anchorDelta + unanchoredDelta - (_isAxisReversed ? unanchoredTotalDelta : 0.0);
      _pendingAnchorCapturePixels = oldPixels;
    }
    if (!_scrollbarDragging) {
      _applyPendingScrollCorrectionOrSchedule(notify: pinnedEdge != null);
    }
    _refreshVisibleRangeAndCommit(forceContentSnapshot: true, forceContentLayout: true);
    _scheduleVisibleRangeUpdate();
  }

  bool _itemExtentsAreAlreadyMeasured(Map<int, double> extents) {
    if (extents.isEmpty) return true;
    for (final MapEntry(:key, :value) in extents.entries) {
      if (key < 0 || key >= _extentIndex.count) continue;
      if (!_extentIndex.isMeasured(key)) return false;
      if ((_extentIndex.extentOf(key) - value).abs() > precisionErrorTolerance) return false;
    }
    return true;
  }

  VirtualScrollEdge? _scrollPositionEdgeForScrollbarThumbFraction(double? thumbFraction) => thumbFraction == null
      ? null
      : VirtualScrollGeometry.edgeForThumbFraction(thumbFraction, reversed: _isAxisReversed);

  VirtualScrollEdge? _scrollPositionEdgeForScrollbarDragEdge(ScrollbarDragEdge? edge) =>
      VirtualScrollGeometry.edgeForDragEdge(edge, reversed: _isAxisReversed);

  bool _shouldRefreshUnmeasuredEstimate({bool force = false}) {
    final measuredAverage = _extentIndex.measuredExtentAverage;
    if (measuredAverage == null || measuredAverage <= precisionErrorTolerance) return false;
    // 不设 count 门槛：旧实现的 `count < 1000` 直通会让分页加载的列表
    //（chat 每批 160 条）在前几页永远用初始 32px 估计——真实行高 ~3 倍于
    // 估计时，每行进入视口都产生一次大幅修正。估计刷新本身有比值滞回
    //（±25%），小列表刷新代价 O(n) 可忽略。
    if (force) return _extentIndex.measuredCount > 0;
    if (_extentIndex.measuredCount < 4) return false;
    final currentEstimate = _extentIndex.estimatedExtent;
    if (currentEstimate <= precisionErrorTolerance) return false;
    final ratio = measuredAverage / currentEstimate;
    return ratio >= 1.25 || ratio <= 0.8;
  }

  /// 子控件持焦时不执行默认动作，方向键交给控件自身或 Flutter 默认策略。
  void _handleFocusedKey(ElEventDetails event) {
    if (!identical(FocusManager.instance.primaryFocus?.context, _focusKey.currentContext)) return;
    final userEvent = widget.event;
    final handler = switch (event.phase) {
      ElEventPhase.keyDown => userEvent?.onKeyDown,
      ElEventPhase.keyRepeat => userEvent?.onKeyRepeat ?? userEvent?.onKeyDown,
      ElEventPhase.keyUp => userEvent?.onKeyUp,
      _ => null,
    };
    handler?.call(event);
    if (!widget.keyboardScroll || event.defaultPrevented || event.phase == ElEventPhase.keyUp) return;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is RenderVirtualScrollView) viewport.handleKeyboardScroll(event);
  }

  @override
  Widget build(BuildContext context) {
    _syncAncestorInputRoutes();
    if (_scrollDebugCountersEnabled) _debugCounters!.debugBuildCount++;
    final axisDirection = _axisDirection;
    final configuration = _scrollBinding.configuration;
    final selectedRefresher = _selectedRefresher;
    final selectedSmoothScroll = _selectedSmoothScroll;

    var baseInterceptor = widget.deltaInterceptor;
    // refresher 在场时刷新回位链挂链首（实例稳定，identity 不抖）。
    if (selectedRefresher != null) {
      final link = _refreshLink ??= RefreshScrollLink();
      link.contentViewportRectOf = () {
        final viewport = _activeMixinViewportRenderObject();
        return viewport is _RenderVirtualViewport ? viewport._lastRefreshContentRect : null;
      };
      link.next = baseInterceptor;
      link.position = () => position;
      baseInterceptor = link;
    } else {
      _refreshLink = null;
    }
    _baseEffectiveInterceptor = baseInterceptor;
    _syncMixinInputInterceptors();

    // textScaler / textDirection 在 build 里读：inherited 依赖照常注册，变更
    // 仍触发 rebuild（度量环境的这两项不来自约束，故不进 layout 回调）。
    final textScaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final textDirection = Directionality.maybeOf(context);
    final fixedEnvironmentChanged =
        _sectionPlan.hasFixed && (_buildTextScaler != textScaler || _buildTextDirection != textDirection);
    if (fixedEnvironmentChanged) {
      // 首条已经受 tight 约束，文字环境变化不会靠子树自然冒泡触发重新测量。
      for (final segment in _segments) {
        if (segment is LinearSegment && segment.fixed != null) {
          segment.fixed!.item.measuredGeneration = null;
          segment.fixed!.separator.measuredGeneration = null;
        }
      }
    }
    _buildTextScaler = textScaler;
    _buildTextDirection = textDirection;
    final contentSnapshot = _createContentSnapshot();
    _contentController.replaceSnapshot(contentSnapshot);
    if (fixedEnvironmentChanged) {
      _contentController.updateSnapshot(contentSnapshot, reconcileChildren: false, forceLayout: true, notify: false);
    }
    // 首帧：即使 anyChanged 判为 false，也要向 item mixin/列表回调派发
    // 一次初始 range，让"进入可见"事件有对称的起点。
    _scheduleVisibilityDispatch();

    final selectedScrollbar = _resolveScrollbar();
    final mainAxisVertical = _layoutAxis == Axis.vertical;
    // 无滚动条时不订阅 position，避免为不可见的 chrome 生成逐帧快照。
    final scrollbarEnabled = selectedScrollbar is! ElNoScrollBar;
    final verticalScrollbarPosition = scrollbarEnabled && mainAxisVertical ? position : null;
    final horizontalScrollbarPosition = scrollbarEnabled
        ? (mainAxisVertical ? _horizontalBinding?.position : position)
        : null;
    final scrollbarController = _scrollbarController ??= ScrollbarController(
      verticalPosition: verticalScrollbarPosition,
      horizontalPosition: horizontalScrollbarPosition,
      dispatchPointerSignal: (event) {
        final viewport = _viewportKey.currentContext?.findRenderObject();
        if (viewport is! RenderVirtualScrollView) return false;
        return event is PointerScrollEvent
            ? viewport.dispatchPointerScroll(event)
            : viewport.dispatchSelectionPointerSignal(event);
      },
    );
    scrollbarController.updatePositions(
      verticalPosition: verticalScrollbarPosition,
      horizontalPosition: horizontalScrollbarPosition,
    );
    scrollbarController.updateThumbDragDelegates(
      vertical: mainAxisVertical ? _thumbDragDelegate : null,
      horizontal: mainAxisVertical ? null : _thumbDragDelegate,
    );

    Widget result = KeyedSubtree(
      key: _notificationKey,
      child: ScrollSemantics(
        child: _ScrollViewport(
          key: _viewportKey,
          position: position,
          horizontalPosition: _horizontalBinding?.position,
          horizontalAxisDirection: _horizontalBinding?.axisDirection ?? AxisDirection.right,
          physics: _scrollBinding.physics,
          axis: _layoutAxis,
          axisDirection: axisDirection,
          shrinkWrap: widget.shrinkWrap,
          velocityTrackerBuilder: configuration.velocityTrackerBuilder(context),
          multitouchDragStrategy: configuration.getMultitouchDragStrategy(context),
          devicePixelRatio: _scrollBinding.devicePixelRatio,
          dragDevices: configuration.dragDevices,
          pointerAxisModifiers: configuration.pointerAxisModifiers,
          mouseWheelHorizontalModifiers: widget.mouseWheelHorizontalModifiers,
          gestureSettings: MediaQuery.maybeGestureSettingsOf(context),
          clipBehavior: widget.clipBehavior,
          excludeSemantics: widget.excludeSemantics,
          semanticsRole: widget.semanticsRole,
          ignorePointer: _mergedIgnorePointer,
          canDrag: _mergedCanDrag,
          dragStartDistance: widget.dragStartDistance,
          onScrollbarDragChanged: _handleScrollbarDragChanged,
          onScrollbarMetricsChanged: _handleScrollbarMetricsChanged,
          onLayoutMetrics: _handleLayoutMetrics,
          event: widget.event,
          deltaInterceptor: _effectiveInterceptor,
          horizontalDeltaInterceptor: _effectiveHorizontalInterceptor,
          onScrollInputActivityChanged: _mixinClients == null ? null : _handleMixinInputActivityChanged,
          smoothScroll: selectedSmoothScroll,
          controller: _contentController,
          scrollbar: selectedScrollbar,
          scrollbarDetails: scrollbarController,
        ),
      ),
    );

    final onRefresh = widget.onRefresh;
    if (selectedRefresher != null && onRefresh != null) {
      result = RefreshHost(
        refresher: selectedRefresher,
        physics: _appliedWidgetPhysics,
        onRefresh: onRefresh,
        axisDirection: axisDirection,
        edge: widget.refreshEdge,
        link: _refreshLink,
        child: result,
      );
    }

    if (widget.keyboardDismissBehavior == ScrollViewKeyboardDismissBehavior.onDrag) {
      result = NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          final currentScope = FocusScope.of(context);
          if (notification.dragDetails != null && !currentScope.hasPrimaryFocus && currentScope.hasFocus) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
          return false;
        },
        child: result,
      );
    }

    final overscrollDetails = ScrollableDetails(direction: axisDirection, decorationClipBehavior: widget.clipBehavior);
    final decorated = configuration.buildOverscrollIndicator(context, result, overscrollDetails);
    if (decorated is StretchingOverscrollIndicator) {
      (_stretch ??= _ScrollStretch(this)).configuration = decorated;
    } else {
      _stretch?.dispose();
      _stretch = null;
      result = decorated;
    }

    if (widget.focusNode != null) {
      result = ElView(
        key: _focusKey,
        focusNode: widget.focusNode,
        event: ElEvent(onKeyDown: _handleFocusedKey, onKeyRepeat: _handleFocusedKey, onKeyUp: _handleFocusedKey),
        child: result,
      );
    }

    return _ScrollViewScope(
      state: this,
      child: LayoutScrollScope(axis: _layoutAxis, reverse: widget.reverse, child: result),
    );
  }

  _ScrollMountSnapshot _createContentSnapshot() {
    return _ScrollMountSnapshot(
      axis: _layoutAxis,
      dualAxis: _isDualAxis,
      totalExtent: _totalLayoutExtent,
      padding: widget.padding,
      gap: _gap,
      crossAxisAlignment: widget.crossAxisAlignment,
      minimumCrossAxisExtent: math.max(widget.minimumCrossAxisExtentListenable?.value ?? 0.0, 0.0),
      firstIndex: _firstIndex,
      lastIndex: _lastIndex,
      dragOptimizeEnabled: _dragOptimizeEnabled,
      pinToEnd: widget.pinToEnd,
      preserveAnchor: widget.preserveAnchor,
      sourceChildren: _effectiveChildren,
      sectionPlan: _sectionPlan,
      childrenRevision: _childrenRevision,
      measurementGeneration: _measurementGeneration,
      reportMeasuredExtentsWhenUnchanged: _extentEnvironmentDriftedFromMeasured,
      keepAliveIndices: _keepAliveIndices,
      pinnedStickyIndex: _pinnedStickyIndex,
      keepAliveOwner: this,
      extentIndex: _extentIndex,
      onItemExtentsChanged: _handleItemExtentsChanged,
      onMeasurementsChanged: _handleMeasurementsChanged,
    );
  }
}

/// `ElScrollViewState` 的包内白盒测试探针。
@visibleForTesting
extension ElScrollViewStateTesting on ElScrollViewState {
  /// 读取真实计数；非 debug 构建须启用 EL_UI_SCROLL_DEBUG_COUNTERS，否则抛出 StateError。
  ElVirtualScrollDebugCounters get debugCounters {
    if (!_scrollDebugCountersEnabled) {
      throw StateError('滚动计数未启用，请使用 --dart-define=EL_UI_SCROLL_DEBUG_COUNTERS=true。');
    }
    return _debugCounters!;
  }

  /// 尺寸数组的槽数量，固定列表与网格应只占常数规模。
  int get debugExtentStorageSlotCount => _extentIndex.debugStorageSlotCount;

  /// 度量环境是否仍等待挂载行确认。
  bool get debugExtentEnvironmentDriftedFromMeasured => _debugExtentEnvironmentDriftedFromMeasured;

  /// 已确认匹配缓存度量的交叉轴尺寸。
  double? get debugMeasuredEnvironmentCrossAxisExtent => _debugMeasuredEnvironmentCrossAxisExtent;

  /// 当前登记的滚动 Mixin client 数量。
  int get debugScrollMixinClientCount => _mixinClients?.length ?? 0;

  /// 是否已经为 Mixin client 分配登记表；无 client 的普通路径应始终为 false。
  bool get debugScrollMixinClientRegistryAllocated => _mixinClients != null;

  /// 宿主实际构造统一快照的次数；同一事件的多个 observer 必须共享一次。
  int get debugScrollMixinSnapshotBuildCount => _debugMixinSnapshotBuildCount;

  /// 当前已激活的滚动 viewport render；仅供白盒输入来源测试。
  RenderVirtualScrollView? get debugScrollMixinViewportRenderObject => _activeMixinViewportRenderObject();

  /// 指定轴是否存在已提交的输入参与者。
  bool debugHasScrollInputParticipants(Axis axis) => _inputRouter?.hasParticipants(axis) ?? false;

  /// 是否分配输入路由器；无参与者与显式顺序的路径保持 false。
  bool get debugScrollInputRouterAllocated => _inputRouter != null;

  /// 输入顺序解析次数，稳定滚动时不得增长。
  int get debugScrollInputOrderResolveCount => _inputRouter?.resolveCount ?? 0;

  /// 当前受控 simulation 的只读诊断入口；只能按不递减时间查询。
  ({Simulation simulation, double time})? debugScrollMotionSample(Axis axis) {
    final activity = _motionCoordinatorFor(axis)?._activity;
    if (activity == null || activity.lastStamp == null || activity.startStamp == null) return null;
    return (
      simulation: activity.simulation,
      time: (activity.lastStamp! - activity.startStamp!).inMicroseconds / Duration.microsecondsPerSecond,
    );
  }

  /// 重放同一运动帧，验证时间去重不会再次调用业务参与者。
  void debugReplayScrollMotionSample(Axis axis) {
    final coordinator = _motionCoordinatorFor(axis);
    final activity = coordinator?._activity;
    if (activity != null && activity.lastStamp != null) coordinator!.tick(activity, activity.lastStamp!);
  }

  /// 开始记录最多 2048 次 slot 分账；只供诊断，默认不分配记录集合。
  void debugRecordScrollInputTrace() {
    final router = _inputRouter;
    if (router == null) throw StateError('记录输入分账前必须挂载输入参与者。');
    router.trace = [];
  }

  /// 当前诊断分账的不可变副本；记录上限为 2048 条。
  List<({Object slot, String phase, double input, double remaining})> get debugScrollInputTrace =>
      List.unmodifiable(_inputRouter?.trace ?? const []);
}

/// 虚拟滚动的 widget 层 thumb 拖拽委托:直接走 render 的 thumb 分数快路径
/// 入口(设置 render 内部 thumb 分数供 held-window 布局推导,并经
/// [RenderVirtualScrollView.onScrollbarDragChanged] 回流 state 快路径),
/// 映射走 render 同步 extent 模型——估算 extent 下线性 fraction→pixels 会漂。
final class _VirtualThumbDragDelegate extends ScrollbarThumbDragDelegate {
  _VirtualThumbDragDelegate(this._state);

  final ElScrollViewState _state;

  RenderVirtualScrollView? get _render {
    final renderObject = _state._viewportKey.currentContext?.findRenderObject();
    return renderObject is RenderVirtualScrollView ? renderObject : null;
  }

  @override
  void beginThumbDrag() {
    _render?.handleScrollbarDragStarted();
  }

  @override
  double? pixelsForThumbFraction(double fraction) {
    // 全静态：extent 模型首帧即精确、拖拽期无估算收敛，映射回落 host 的
    // 冻结会话范围语义（pointer-down 时的 min/max，内容中途变尺寸不重映射
    // 手上的 thumb——旧简单管线口径）；render 快拖分数不置位，避免 layout
    // 期按"活 max"correctPixels 顶掉冻结映射。虚拟段在场才走模型同步映射。
    if (_state._sectionPlan.isAllStatic) return null;
    final render = _render;
    if (render == null) return null;
    render.handleScrollbarDragUpdate(fraction);
    return render.scrollbarPositionPixelsForVisualFraction(fraction);
  }

  @override
  void endThumbDrag() {
    final render = _render;
    if (render == null) return;
    render.handleScrollbarDragEnded(render.scrollbarDragEdge());
  }
}
