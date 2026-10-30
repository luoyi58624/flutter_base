part of '../virtual/virtual_pipeline.dart';

Future<void>? _joinScrollSettles(Future<void>? first, Future<void>? second) => first == null
    ? second
    : second == null
    ? first
    : Future.wait<void>([first, second], eagerError: true).then<void>((_) {});

/// 所有滚动生命周期详情共享的不可变字段。
@immutable
abstract base class ElScrollDetails {
  const ElScrollDetails({
    required this.scrollView,
    required this.axis,
    required this.position,
    required this.previousSnapshot,
    required this.snapshot,
  });

  /// 当前真实宿主的实时能力入口，不是历史状态副本。
  final ElScrollViewState scrollView;

  /// 此次详情对应的滚动轴。
  final Axis axis;

  /// 当前 position 的实时引用；历史指标应读取不可变 snapshot。
  final ScrollPosition position;

  /// 上一次同轴提交的不可变快照。
  final ElScrollSnapshot previousSnapshot;

  /// 本次同轴提交的不可变快照。
  final ElScrollSnapshot snapshot;
}

/// 滚动活动开始。
@immutable
final class ElScrollStartDetails extends ElScrollDetails {
  const ElScrollStartDetails({
    required super.scrollView,
    required super.axis,
    required super.position,
    required super.previousSnapshot,
    required super.snapshot,
  });
}

/// 正文位移或受控速度样本发生变化。
@immutable
final class ElScrollUpdateDetails extends ElScrollDetails {
  const ElScrollUpdateDetails({
    required super.scrollView,
    required super.axis,
    required super.position,
    required super.previousSnapshot,
    required super.snapshot,
  });
}

/// 滚动活动结束。
@immutable
final class ElScrollEndDetails extends ElScrollDetails {
  const ElScrollEndDetails({
    required super.scrollView,
    required super.axis,
    required super.position,
    required super.previousSnapshot,
    required super.snapshot,
  });
}

/// viewport / content dimensions 发生变化。
@immutable
final class ElScrollMetricsDetails extends ElScrollDetails {
  const ElScrollMetricsDetails({
    required super.scrollView,
    required super.axis,
    required super.position,
    required super.previousSnapshot,
    required super.snapshot,
    required this.metrics,
  });

  /// 布局尚未完成时为 null；宿主派发时冻结指标，不随实时 position 变化。
  final ScrollMetrics? metrics;
}

/// 滚动活动或所属输入会话发生变化，即使 pixels 未变化也会派发。
@immutable
final class ElScrollActivityDetails extends ElScrollDetails {
  const ElScrollActivityDetails({
    required super.scrollView,
    required super.axis,
    required super.position,
    required super.previousSnapshot,
    required super.snapshot,
  });

  ElScrollActivityType get previousActivity => previousSnapshot.activity;
  ElScrollActivityType get activity => snapshot.activity;
}

/// 滚动成员几何或 sticky 状态发生变化。
@immutable
final class ElScrollItemUpdateDetails {
  const ElScrollItemUpdateDetails({required this.scrollView, required this.previousSnapshot, required this.snapshot});

  /// 当前成员所属的真实滚动宿主。
  final ElScrollViewState scrollView;

  /// 本次更新前的成员快照。
  final ElScrollItemSnapshot previousSnapshot;

  /// 本次更新后的成员快照。
  final ElScrollItemSnapshot snapshot;
}

/// 同一宿主输入阶段共享的不可变详情，当前剩余量由钩子的独立参数传递。
@immutable
final class ElScrollInputDetails {
  /// 创建标准化内容坐标的输入详情。
  const ElScrollInputDetails({
    required this.scrollView,
    required this.sourceScrollView,
    required this.axis,
    required this.source,
    required this.sessionId,
    required this.transactionId,
    required this.sampleId,
    required this.timeStamp,
    required this.rawEvent,
    required this.axisDirection,
    required this.rawDelta,
    required this.requestedDelta,
    required this.snapshot,
  });

  /// 实时宿主能力入口。
  final ElScrollViewState scrollView;

  /// 命中本次输入的实时源宿主，参与接力的 scrollView 可能是它的祖先。
  final ElScrollViewState sourceScrollView;

  /// 当前输入对应的轴。
  final Axis axis;

  /// 该轴实际的 position 方向。
  final AxisDirection axisDirection;

  /// 由实际设备入口确认的输入来源。
  final ElScrollInputSource source;

  /// 实际输入的稳定会话号；未接通会话的独立信号及不透明入口为 null。
  final int? sessionId;

  /// 覆盖此次同步输入各阶段的事务号。
  final int transactionId;

  /// 当前宿主轴的输入观察序号，同一事务的 pre/post 共用。
  final int sampleId;

  /// 真实事件或重采样时刻，与系统帧时钟同域。
  final Duration timeStamp;

  /// 只读原始设备事件；重采样时其时间戳可能不同于当前 sample。
  final PointerEvent? rawEvent;

  /// 适配边界的只读原值；不同来源的符号空间不同，业务消费使用 remaining。
  final double rawDelta;

  /// 本宿主收到的标准化原始预算，正值增加内容坐标，不随参与者消费而改变。
  final double requestedDelta;

  /// 进入当前阶段前最新可用的不可变状态。
  final ElScrollSnapshot snapshot;
}

/// 同一释放阶段共享的不可变速度详情，当前剩余速度单独传递。
@immutable
final class ElScrollReleaseDetails {
  /// 创建内容坐标系中的释放详情。
  const ElScrollReleaseDetails({
    required this.scrollView,
    required this.sourceScrollView,
    required this.axis,
    required this.axisDirection,
    required this.source,
    required this.sessionId,
    required this.transactionId,
    required this.sampleId,
    required this.timeStamp,
    required this.rawEvent,
    required this.rawVelocity,
    required this.releaseVelocity,
    required this.snapshot,
  });

  /// 实时宿主能力入口。
  final ElScrollViewState scrollView;

  /// 本次直接手势的实时源宿主。
  final ElScrollViewState sourceScrollView;

  /// 释放对应的轴。
  final Axis axis;

  /// 该轴实际的 position 方向。
  final AxisDirection axisDirection;

  /// 低层释放接口收到的物理轴速度。
  final double rawVelocity;

  /// 释放来自的设备或未知直接入口。
  final ElScrollInputSource source;

  /// 与本次直接手势输入一致的会话号。
  final int? sessionId;

  /// 覆盖本次释放过滤的事务号。
  final int transactionId;

  /// 当前轴递增的释放观察序号。
  final int sampleId;

  /// 释放事件时刻，与系统帧时钟同域。
  final Duration timeStamp;

  /// 只读原始释放事件；无法提供时为 null。
  final PointerEvent? rawEvent;

  /// 标准化的原始释放速度，不随参与者过滤而变化。
  final double releaseVelocity;

  /// 释放时最新可用的内容快照。
  final ElScrollSnapshot snapshot;
}

/// 为 [ElScrollView] 真实后代 State 提供统一滚动生命周期与状态。
///
/// Mixin 只沿当前 [BuildContext] 的祖先链绑定最近滚动宿主，不创建或接管
/// controller，也不会向下遍历寻找由当前 State 自己构建的滚动视图。
/// 默认只更新本地不可变快照，不调用 [setState]；需要逐 tick 重建时显式覆写
/// [rebuildOnScrollUpdate]，局部动画效果应在最小 State 中维护状态并正常构建。
mixin ElScrollMixin<T extends StatefulWidget> on State<T> implements _ScrollMixinClient {
  ElScrollViewState? _scrollView;
  _ScrollItemScope? _scrollItemScope;
  ElScrollSnapshot _scrollSnapshot = ElScrollSnapshot.detached;
  ElScrollItemSnapshot _scrollItemSnapshot = ElScrollItemSnapshot.detached;
  bool _scrollCallbacksActive = true;
  bool _scrollDisposed = false;
  bool _scrollRebuildScheduled = false;
  _ScrollSessionClient? _sessionSubscription;

  /// 预设合并默认全局订阅需求；null 沿用基础默认，业务覆写 observes* 始终优先。
  @protected
  bool? get scrollEffectGlobalObservation => null;

  /// 请求绑定的轴；null 使用最近滚动宿主的布局主轴。
  ///
  /// getter 依赖 widget 参数时，[didUpdateWidget] 会自动重新解算。
  @protected
  Axis? get requestedScrollAxis => null;

  @override
  Axis? get _scrollAxis => requestedScrollAxis;

  /// 是否接收 scroll start/update/end 与 activity 更新。
  @protected
  bool get observesScrollUpdates => scrollEffectGlobalObservation ?? true;

  /// 是否接收 viewport / content dimensions 更新。
  @protected
  bool get observesScrollMetrics => scrollEffectGlobalObservation ?? true;

  /// 是否观察实际输入和整组运动终态；关闭不影响普通滚动或尺寸订阅。
  @protected
  bool get observesScrollSessions => scrollEffectGlobalObservation ?? true;

  /// 是否订阅当前直接滚动成员的几何快照。
  ///
  /// 开启后基础 Mixin 只重建当前最小 State；窗口外进度已钳到端点时宿主会
  /// 停止空转通知。
  @protected
  bool get listenScrollItem => false;

  /// 只观察成员几何，由效果自行判断是否需要重建。
  @protected
  bool get observesScrollItemUpdates => false;

  /// 仅观察成员尺寸变化，复用 onScrollItemUpdate，不因正文平移派发或自动重建。
  @protected
  bool get observesScrollItemSize => false;

  /// 宿主开启 preserveAnchor 后本成员是否参与保位；false 保留其正常排版位移。
  @protected
  bool get scrollItemPreserveAnchor => true;

  /// 是否作为保留正文占位、固定在视口起边的头部；其真实尺寸同时约束正文和刷新可用区域。
  @protected
  bool get scrollItemViewportHeader => false;

  /// 是否接收当前成员的进入/离开事件。
  @protected
  bool get trackScrollItemVisibility => false;

  /// 可见状态不变时是否继续接收连续 visibleFraction 变化。
  @protected
  bool get trackScrollItemVisibleFraction => false;

  /// 当前 State 声明的 sticky offset；null 表示不占有 sticky 布局能力。
  @protected
  @override
  double? get scrollItemStickyOffset => null;

  /// 非 null 时以稳定 slot 身份参与当前轴的输入协商；一个 State 仍只有一个 client。
  /// 同轴多个 State 使用宿主 inputOrder 明确排序，与 Widget 或 zIndex 顺序无关。
  @protected
  @override
  Object? get scrollInputSlot => null;

  /// 声明此 State 的有限效果自由度，多 Mixin 合并 super 的结果且身份不得重复。
  @protected
  Iterable<ElScrollEffectTrack> get scrollEffectTracks => const [];

  @override
  Iterable<ElScrollEffectTrack> get _effectTracks => scrollEffectTracks;

  /// 是否在每次滚动位置更新后由基础 Mixin 调用 [setState]。
  @protected
  bool get rebuildOnScrollUpdate => false;

  /// 当前是否已绑定有效滚动宿主。
  bool get hasScrollView => _scrollView != null;

  /// 当前 State 是否处于所属滚动宿主的直接 item scope 中。
  bool get hasScrollItem => _scrollItemScope != null;

  /// 当前滚动成员的扁平 index；未绑定 item 时为 null。
  int? get scrollItemIndex => _scrollItemScope?.index;

  /// 最近一次由宿主统一生成的成员几何快照。
  ElScrollItemSnapshot get scrollItemSnapshot => _scrollItemSnapshot;

  /// 当前 item 是否位于真实可视窗口；滚动视图外按可立即解码处理。
  @internal
  bool get scrollItemDecodeVisible {
    final host = _scrollView;
    final index = _scrollItemScope?.index;
    return host == null || index == null ? true : host._imageDecodeVisibleFor(index);
  }

  /// 当前 item 的图片解码优先级；滚动视图外返回 0。
  @internal
  int get scrollItemDecodePriority {
    final host = _scrollView;
    final index = _scrollItemScope?.index;
    return host == null || index == null ? 0 : host._imageDecodePriorityFor(index);
  }

  /// 当前最近滚动宿主；未绑定时为 null。
  ElScrollViewState? get scrollView => _scrollView;

  /// 当前绑定轴实际使用的 controller；未绑定时为 null。
  ScrollController? get scrollController {
    final host = _scrollView;
    final axis = _resolvedScrollAxis;
    return host == null || axis == null ? null : host._controllerForMixinAxis(axis);
  }

  /// 当前绑定轴实际使用的 position；未绑定或轴不可用时为 null。
  ScrollPosition? get scrollPosition {
    final host = _scrollView;
    final axis = _resolvedScrollAxis;
    return host == null || axis == null ? null : host.positionFor(axis);
  }

  /// 当前绑定轴的实时 metrics；布局未完成时为 null。
  ScrollMetrics? get scrollMetrics {
    final host = _scrollView;
    final axis = _resolvedScrollAxis;
    return host == null || axis == null ? null : host.metricsFor(axis);
  }

  /// 已订阅时读取最近一次观察；关闭订阅时补读当前值，不补造未观察的运动历史。
  ElScrollSnapshot get scrollSnapshot {
    final host = _scrollView;
    final axis = _resolvedScrollAxis;
    if (host != null && axis != null && (!observesScrollUpdates || !observesScrollMetrics)) {
      return host._readMixinSnapshotFor(axis);
    }
    return _scrollSnapshot;
  }

  /// 未绑定时抛出包含组件结构提示的错误。
  ElScrollViewState get requireScrollView =>
      _scrollView ?? _missingScrollCapability('ElScrollViewState', '当前 State 不是 ElScrollView 的真实后代。');

  ScrollController get requireScrollController =>
      scrollController ?? _missingScrollCapability('ScrollController', '当前绑定轴没有可用 controller。');

  ScrollPosition get requireScrollPosition =>
      scrollPosition ?? _missingScrollCapability('ScrollPosition', '当前绑定轴尚未挂载可用 position。');

  ScrollMetrics get requireScrollMetrics =>
      scrollMetrics ?? _missingScrollCapability('ScrollMetrics', '滚动视口尚未完成 content dimensions 布局。');

  Axis? get _resolvedScrollAxis => _scrollSnapshot.axis ?? requestedScrollAxis ?? _scrollView?._layoutAxis;

  Never _missingScrollCapability(String capability, String reason) {
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('$runtimeType 请求的 $capability 当前不可用。'),
      ErrorDescription(reason),
      ErrorHint(
        '把持有 ElScrollMixin 的 State 放进 ElScrollView.children 的真实后代子树；'
        '若该 State 自己创建 ElScrollView，请把滚动效果拆到 scroll child 的独立 State。',
      ),
    ]);
  }

  @override
  bool get mountedForScrollCallbacks => mounted && _scrollCallbacksActive && !_scrollDisposed;

  @override
  int? get _scrollItemIndex => _scrollItemScope?.index;

  @override
  Object? get _scrollItemIdentity => _scrollItemScope?.identity;

  @override
  bool get wantsScrollUpdates => observesScrollUpdates;

  @override
  bool get wantsViewportUpdates => observesScrollMetrics;

  @override
  bool get wantsScrollItemUpdates => listenScrollItem || observesScrollItemUpdates;

  @override
  bool get tracksScrollItemVisibility => trackScrollItemVisibility;

  @override
  bool get tracksScrollItemVisibleFraction => trackScrollItemVisibleFraction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollCallbacksActive = true;
    updateScrollBinding();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateScrollBinding();
  }

  /// 重新解算最近宿主、轴与行为配置。
  ///
  /// 自定义 Mixin 的配置由非 widget 状态驱动时，可在配置变化后主动调用。
  @protected
  void updateScrollBinding() {
    if (_scrollDisposed || !_scrollCallbacksActive || !mounted) return;
    final next = maybeFindScrollViewState(context, axis: requestedScrollAxis);
    final foundItemScope = _ScrollItemScope.maybeOf(context);
    final nextItemScope = foundItemScope != null && identical(foundItemScope.owner, next) ? foundItemScope : null;
    final previous = _scrollView;
    if (identical(previous, next)) {
      _scrollItemScope = nextItemScope;
      next?._updateMixinClient(this);
      if (next != null) {
        _scrollSnapshot = next._currentMixinSnapshotFor(requestedScrollAxis ?? next._layoutAxis);
        _scrollItemSnapshot = next._currentMixinItemSnapshotFor(this);
      } else {
        _scrollItemSnapshot = ElScrollItemSnapshot.detached;
      }
      return;
    }
    previous?._unregisterMixinClient(this);
    _scrollItemScope = nextItemScope;
    next?._registerMixinClient(this);
    if (next == null) _scrollItemSnapshot = ElScrollItemSnapshot.detached;
  }

  /// 行为参数发生变化后同步登记配置；等价于重新解算绑定。
  @protected
  void updateScrollEffect() => updateScrollBinding();

  /// item sticky/listen/visibility 参数变化后原位同步同一个 client handle。
  @protected
  void updateScrollItem() => updateScrollEffect();

  @override
  void deactivate() {
    _sessionSubscription?.cancel();
    _scrollCallbacksActive = false;
    final previous = _scrollView;
    previous?._unregisterMixinClient(this);
    _scrollItemScope = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _scrollCallbacksActive = true;
    // 依赖关系由随后必达的 didChangeDependencies 重新建立，避免在 activate
    // 阶段读取尚未稳定的祖先链。
  }

  @override
  void dispose() {
    _scrollDisposed = true;
    _scrollCallbacksActive = false;
    final previous = _scrollView;
    previous?._unregisterMixinClient(this);
    _scrollItemScope = null;
    _scrollItemSnapshot = ElScrollItemSnapshot.detached;
    super.dispose();
  }

  @override
  void attachToScrollView(ElScrollViewState state) {
    assert(_scrollView == null || identical(_scrollView, state));
    _scrollView = state;
    _scrollSnapshot = state._currentMixinSnapshotFor(requestedScrollAxis ?? state._layoutAxis);
    _scrollItemSnapshot = state._currentMixinItemSnapshotFor(this);
    onScrollViewAttached(state);
  }

  @override
  void detachFromScrollView(ElScrollViewState state) {
    if (!identical(_scrollView, state)) return;
    _sessionSubscription?.cancel();
    onScrollViewDetached(state);
    _scrollView = null;
    _scrollItemScope = null;
    _scrollSnapshot = ElScrollSnapshot.detached;
    _scrollItemSnapshot = ElScrollItemSnapshot.detached;
  }

  @override
  void handleScrollStart(ElScrollStartDetails details) {
    _scrollSnapshot = details.snapshot;
    onScrollStart(details);
  }

  @override
  void handleScrollUpdate(ElScrollUpdateDetails details) {
    _scrollSnapshot = details.snapshot;
    onScrollUpdate(details);
    if (rebuildOnScrollUpdate) _scheduleScrollMixinRebuild();
  }

  @override
  void handleScrollEnd(ElScrollEndDetails details) {
    _scrollSnapshot = details.snapshot;
    onScrollEnd(details);
  }

  @override
  void handleMetricsChanged(ElScrollMetricsDetails details) {
    _scrollSnapshot = details.snapshot;
    onScrollMetricsChanged(details);
  }

  @override
  void handleActivityChanged(ElScrollActivityDetails details) {
    _scrollSnapshot = details.snapshot;
    onScrollActivityChanged(details);
  }

  @override
  void handleScrollItemChanged(ElScrollItemUpdateDetails details) {
    _scrollItemSnapshot = details.snapshot;
    onScrollItemUpdate(details);
    if (listenScrollItem) _scheduleScrollMixinRebuild();
  }

  @override
  void handleScrollItemVisibilityChanged(ElVisibilityInfo info) {
    onScrollItemVisibilityChanged(info);
  }

  @override
  double handlePreScroll(ElScrollInputDetails input, double remaining) =>
      mountedForScrollCallbacks && identical(_scrollView, input.scrollView) ? onPreScroll(input, remaining) : remaining;

  @override
  double handlePostScroll(ElScrollInputDetails input, double remaining) =>
      mountedForScrollCallbacks && identical(_scrollView, input.scrollView)
      ? onPostScroll(input, remaining)
      : remaining;

  @override
  double handlePreFling(ElScrollReleaseDetails details, double remainingVelocity) =>
      mountedForScrollCallbacks && identical(_scrollView, details.scrollView)
      ? onPreFling(details, remainingVelocity)
      : remainingVelocity;

  void _scheduleScrollMixinRebuild() {
    if (!mountedForScrollCallbacks) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks && phase != SchedulerPhase.midFrameMicrotasks) {
      setState(() {});
      return;
    }
    if (_scrollRebuildScheduled) return;
    _scrollRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollRebuildScheduled = false;
      if (mountedForScrollCallbacks) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// 已成功登记到宿主。
  @protected
  void onScrollViewAttached(ElScrollViewState scrollView) {}

  /// 宿主即将解除当前 State 的登记；回调期间 getter 仍指向旧宿主。
  @protected
  void onScrollViewDetached(ElScrollViewState scrollView) {}

  @protected
  void onScrollStart(ElScrollStartDetails details) {}

  @protected
  void onScrollUpdate(ElScrollUpdateDetails details) {}

  @protected
  void onScrollEnd(ElScrollEndDetails details) {}

  @protected
  void onScrollMetricsChanged(ElScrollMetricsDetails details) {}

  @protected
  void onScrollActivityChanged(ElScrollActivityDetails details) {}

  /// 当前 item 的几何、可见端点或 sticky 状态发生变化。
  @protected
  void onScrollItemUpdate(ElScrollItemUpdateDetails details) {}

  /// 当前 item 的进入/离开或连续可见比例变化；宿主在 post-frame 派发。
  @protected
  void onScrollItemVisibilityChanged(ElVisibilityInfo info) {}

  void _handleSessionPhase(_ScrollSessionPhase phase, ElScrollSessionDetails details) {
    _scrollSnapshot = details.snapshot;
    switch (phase) {
      case _ScrollSessionPhase.inputStart:
        onInputStart(details);
      case _ScrollSessionPhase.inputEnd:
        onInputEnd(details);
      case _ScrollSessionPhase.inputCancel:
        onInputCancel(details);
      case _ScrollSessionPhase.motionSettled:
        onMotionSettled(details);
      case _ScrollSessionPhase.motionCancelled:
        onMotionCancelled(details);
    }
  }

  /// 实际输入开始，头部独占输入而正文不动时仍会调用。
  @protected
  @mustCallSuper
  void onInputStart(ElScrollSessionDetails details) {}

  /// 设备输入结束，后续惯性或 snap 尚未稳定时不会冒充 motion settled。
  @protected
  @mustCallSuper
  void onInputEnd(ElScrollSessionDetails details) {}

  /// 当前输入被接管或绑定退役，只结算原会话一次。
  @protected
  @mustCallSuper
  void onInputCancel(ElScrollSessionDetails details) {}

  /// 正文运动结束后提交自身收尾动画；返回的 Future 与最终布局完成后才派发 onMotionSettled。
  @protected
  @mustCallSuper
  Future<void>? onScrollSettle(ElScrollSessionDetails details) => null;

  /// 当前回调所属运动是否仍有效，super 中的新命令可使旧收尾立即退役。
  @protected
  bool isScrollMotionCurrent(ElScrollSessionDetails details) =>
      mountedForScrollCallbacks &&
      _sessionSubscription?.session.motionId == details.motionId &&
      _sessionSubscription?._motionTerminal == false;

  /// 当前组的所有受控自由度已经稳定。
  @protected
  @mustCallSuper
  void onMotionSettled(ElScrollSessionDetails details) {}

  /// 当前运动组被接管或绑定退役，只结算原组一次。
  @protected
  @mustCallSuper
  void onMotionCancelled(ElScrollSessionDetails details) {}

  /// 返回 pre 阶段剩余量；内置行为先调用 super 再消费，保持 Mixin 书写顺序。
  @protected
  @mustCallSuper
  double onPreScroll(ElScrollInputDetails input, double remaining) => remaining;

  /// 返回正文不能接受的预算经处理后的剩余量；不允许放大或反号。
  @protected
  @mustCallSuper
  double onPostScroll(ElScrollInputDetails input, double remaining) => remaining;

  /// 返回消费后的剩余 fling 速度；默认原样传递。
  @protected
  @mustCallSuper
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) => remainingVelocity;
}
