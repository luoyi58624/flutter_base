part of '../virtual_pipeline.dart';

/// 仅供白盒测试验证滚动 Mixin client 登记与生命周期的后代组件。
@visibleForTesting
final class ScrollMixinClientProbe extends StatefulWidget {
  const ScrollMixinClientProbe({
    super.key,
    this.axis,
    this.wantsViewportUpdates = true,
    this.scrollInputSlot,
    this.child = const SizedBox.shrink(),
  });

  /// 要绑定的祖先滚动轴；null 使用最近宿主的主布局轴。
  final Axis? axis;

  /// 是否订阅 viewport/content dimensions 变化。
  final bool wantsViewportUpdates;

  /// 测试参与者的稳定 input slot；null 表示只观察。
  final Object? scrollInputSlot;

  /// 探针下方的普通业务子树。
  final Widget child;

  @override
  ScrollMixinClientProbeState createState() => ScrollMixinClientProbeState();
}

/// [ScrollMixinClientProbe] 的白盒状态与回调计数器。
@visibleForTesting
final class ScrollMixinClientProbeState extends State<ScrollMixinClientProbe> implements _ScrollMixinClient {
  ElScrollViewState? _scrollView;
  bool _active = true;

  /// 当前绑定的真实滚动宿主；未找到或已停用时为 null。
  ElScrollViewState? get scrollView => _scrollView;

  /// `didChangeDependencies` 调用次数。
  int dependencyCount = 0;

  /// 本 State 的 build 次数。
  int buildCount = 0;

  /// 宿主 attach 回调次数。
  int attachCount = 0;

  /// 宿主 detach 回调次数。
  int detachCount = 0;

  /// 滚动开始回调次数。
  int scrollStartCount = 0;

  /// 滚动位移更新回调次数。
  int scrollUpdateCount = 0;

  /// 滚动结束回调次数。
  int scrollEndCount = 0;

  /// metrics-only 更新回调次数。
  int metricsChangedCount = 0;

  /// activity 类型变化回调次数。
  int activityChangedCount = 0;

  /// pre-scroll 输入调用次数。
  int preScrollCount = 0;

  /// post-scroll 输入调用次数。
  int postScrollCount = 0;

  /// pre-fling 输入调用次数。
  int preFlingCount = 0;

  /// 最近一次回调对应的轴。
  Axis? lastCallbackAxis;

  /// 最近一次回调对应的 position。
  ScrollPosition? lastPosition;

  /// 最近一次 metrics 回调值；布局前允许为 null。
  ScrollMetrics? lastMetrics;

  /// 最近一次宿主共享快照。
  ElScrollSnapshot lastSnapshot = ElScrollSnapshot.detached;

  @override
  Axis? get _scrollAxis => widget.axis;

  @override
  int? get _scrollItemIndex => null;

  @override
  Object? get _scrollItemIdentity => null;

  @override
  bool get mountedForScrollCallbacks => mounted && _active;

  @override
  bool get wantsScrollUpdates => true;

  @override
  bool get wantsViewportUpdates => widget.wantsViewportUpdates;

  @override
  bool get wantsScrollItemUpdates => false;

  @override
  bool get tracksScrollItemVisibility => false;

  @override
  bool get tracksScrollItemVisibleFraction => false;

  @override
  double? get scrollItemStickyOffset => null;

  @override
  Object? get scrollInputSlot => widget.scrollInputSlot;

  @override
  Iterable<ElScrollEffectTrack> get _effectTracks => const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dependencyCount++;
    _bindToNearestScrollView();
  }

  @override
  void didUpdateWidget(covariant ScrollMixinClientProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.axis != widget.axis) {
      _bindToNearestScrollView();
    } else {
      _scrollView?._updateMixinClient(this);
    }
  }

  void _bindToNearestScrollView() {
    final next = maybeFindScrollViewState(context, axis: widget.axis);
    if (identical(next, _scrollView)) {
      next?._updateMixinClient(this);
      return;
    }
    final previous = _scrollView;
    _scrollView = null;
    previous?._unregisterMixinClient(this);
    next?._registerMixinClient(this);
  }

  @override
  void deactivate() {
    _active = false;
    final previous = _scrollView;
    _scrollView = null;
    previous?._unregisterMixinClient(this);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void dispose() {
    _active = false;
    final previous = _scrollView;
    _scrollView = null;
    previous?._unregisterMixinClient(this);
    super.dispose();
  }

  @override
  void attachToScrollView(ElScrollViewState state) {
    assert(_scrollView == null || identical(_scrollView, state));
    _scrollView = state;
    attachCount++;
  }

  @override
  void detachFromScrollView(ElScrollViewState state) {
    if (identical(_scrollView, state)) _scrollView = null;
    detachCount++;
  }

  @override
  void handleScrollStart(ElScrollStartDetails details) {
    scrollStartCount++;
    _recordDetails(details);
  }

  @override
  void handleScrollUpdate(ElScrollUpdateDetails details) {
    scrollUpdateCount++;
    _recordDetails(details);
  }

  @override
  void handleScrollEnd(ElScrollEndDetails details) {
    scrollEndCount++;
    _recordDetails(details);
  }

  @override
  void handleMetricsChanged(ElScrollMetricsDetails details) {
    metricsChangedCount++;
    _recordDetails(details);
    lastMetrics = details.metrics;
  }

  @override
  void handleActivityChanged(ElScrollActivityDetails details) {
    activityChangedCount++;
    _recordDetails(details);
  }

  @override
  void handleScrollItemChanged(ElScrollItemUpdateDetails details) {}

  @override
  void handleScrollItemVisibilityChanged(ElVisibilityInfo info) {}

  void _recordDetails(ElScrollDetails details) {
    lastCallbackAxis = details.axis;
    lastPosition = details.position;
    lastSnapshot = details.snapshot;
  }

  @override
  double handlePreScroll(ElScrollInputDetails input, double remaining) {
    preScrollCount++;
    return remaining;
  }

  @override
  double handlePostScroll(ElScrollInputDetails input, double remaining) {
    postScrollCount++;
    return remaining;
  }

  @override
  double handlePreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    preFlingCount++;
    return remainingVelocity;
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return widget.child;
  }
}
