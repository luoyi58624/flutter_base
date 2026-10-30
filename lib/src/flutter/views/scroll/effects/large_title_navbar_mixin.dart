part of '../virtual/virtual_pipeline.dart';

// 淡出阶段保留自然高度；文字已不可见后，搜索背景才开始收起。
({double opacity, double collapse, double tail}) _navbarBottomPhase(double progress, double range, double bottom) {
  if (range <= 0 || bottom <= 0) return (opacity: 1, collapse: 0, tail: 0);
  final title = range - bottom;
  final distance = progress * range;
  final fadeEnd = title / 4;
  final collapseEnd = bottom + title / 2;
  return (
    opacity: 1 - (distance / fadeEnd).clamp(0.0, 1.0),
    collapse: ((distance - fadeEnd) / (collapseEnd - fadeEnd)).clamp(0.0, 1.0),
    tail: ((distance - collapseEnd) / (range - collapseEnd)).clamp(0.0, 1.0),
  );
}

/// 自然尺寸的大标题导航头，自己管理折叠与标题交接，正文和刷新自动避让。
mixin ElLargeTitleNavbarMixin<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  @override
  bool? get scrollEffectGlobalObservation => true;
  AnimationController? _navbarAnimation;
  double _navbarRange = 0;

  /// 上一次解绑时的折叠进度与宿主；同宿主重挂据此恢复，换宿主则丢弃。
  double _navbarSavedProgress = 0;
  ElScrollViewState? _navbarLastHost;
  double _navbarBottomExtent = 0;
  double _navbarLayoutCollapseExtent = 0;
  bool _navbarAbsolutePosition = false;
  // 仅记录已完成布局的占位，绝对位置与下一次相对输入交接时据此换算。
  double _navbarLayoutFlowExtra = 0;
  bool _navbarReduceMotion = false;

  /// 大标题是否缩小并移动到小标题实际布局的位置。
  @protected
  bool get largeTitleNavbarScale => true;

  /// 非缩放模式下是否同步淡出大标题、淡入小标题；缩放模式忽略此开关。
  @protected
  bool get largeTitleNavbarFade => false;

  /// 收起的小标题是否居中；默认按文字方向靠起边。
  @protected
  bool get largeTitleNavbarCenterTitle => false;

  /// 下拉时是否局部放大大标题，导航框架和按钮始终固定。
  @protected
  bool get largeTitleNavbarStretch => false;

  /// 运动结束时是否吸附到最近的展开或收起端点。
  @protected
  bool get largeTitleNavbarSnap => true;

  /// 导航头的正常盒模型与外观。
  @protected
  ElStyle get largeTitleNavbarStyle => const ElStyle();

  /// 搜索槽外侧的留白，不随搜索背景压缩；下方间距在搜索槽消失后才收回。
  @protected
  EdgeInsetsGeometry get largeTitleNavbarBottomPadding => EdgeInsets.zero;

  /// 搜索槽收起后接续的细线，随剩余上移行程向两侧展开；null 不绘制。
  @protected
  BorderSide? get largeTitleNavbarBottomBorder => null;

  /// 吸附动画时长。
  @protected
  Duration get largeTitleNavbarSnapDuration => const Duration(milliseconds: 220);

  /// 吸附动画曲线。
  @protected
  Curve get largeTitleNavbarSnapCurve => Curves.easeOutCubic;

  /// 当前折叠进度，0 为展开，1 为只保留紧凑导航行。
  double get largeTitleNavbarProgress => _navbarAnimation?.value ?? 0;

  /// 自然布局得到的折叠距离，供独立视口导航映射外部滚动位置。
  @protected
  double get largeTitleNavbarRange => _navbarRange;

  /// 底部槽位的收起进度，内容淡出完成前保持为 0。
  double get largeTitleNavbarBottomProgress =>
      _navbarBottomPhase(largeTitleNavbarProgress, _navbarRange, _navbarBottomExtent).collapse;

  /// 底部文字和图标的透明度，降至 0 后才开始压缩搜索背景。
  double get largeTitleNavbarBottomOpacity =>
      _navbarBottomPhase(largeTitleNavbarProgress, _navbarRange, _navbarBottomExtent).opacity;

  @override
  Axis? get requestedScrollAxis => Axis.vertical;
  @override
  bool get scrollItemViewportHeader => true;
  @override
  bool get scrollItemPreserveAnchor => false;
  @override
  Object? get scrollInputSlot => super.scrollInputSlot ?? this;
  @override
  Iterable<ElScrollEffectTrack> get scrollEffectTracks => [
    ...super.scrollEffectTracks,
    if (_navbarRange > 0)
      ElScrollEffectTrack(
        effectId: #largeTitleNavbar,
        minValue: 0,
        maxValue: 1,
        unit: .progress,
        pixelsPerUnit: _navbarRange,
        readValue: () => largeTitleNavbarProgress,
        updateValue: _setNavbarProgress,
      ),
  ];

  void _setNavbarProgress(double progress) {
    final animation = _navbarAnimation;
    if (animation == null || animation.value == progress && !animation.isAnimating) return;
    animation.value = progress;
  }

  void _measureNavbarRange(double range) {
    if (!mountedForScrollCallbacks || _navbarRange == range) return;
    _navbarRange = range;
    updateScrollEffect();
    if (!hasScrollView) _scheduleScrollMixinRebuild();
  }

  void _recordNavbarLayoutCollapse(double extent) => _navbarLayoutCollapseExtent = extent;

  void _measureNavbarBottom(double extent) {
    if (!mountedForScrollCallbacks || _navbarBottomExtent == extent) return;
    _navbarBottomExtent = extent;
    if (largeTitleNavbarProgress > 0) _scheduleScrollMixinRebuild();
  }

  @override
  void onScrollViewAttached(ElScrollViewState scrollView) {
    super.onScrollViewAttached(scrollView);
    // 同一宿主重挂：折叠进度是持久视觉状态，不能因绑定重建被正文位置反推清零；
    // 换到另一宿主才按初始规则重新定位。
    final sameSource = identical(_navbarLastHost, scrollView);
    _navbarAnimation = AnimationController(
      vsync: scrollView,
      duration: largeTitleNavbarSnapDuration,
      value: sameSource
          ? _navbarSavedProgress
          : (scrollSnapshot.hasMetrics && !scrollSnapshot.atStart ? 1 : 0),
    )..addListener(_scheduleScrollMixinRebuild);
  }

  @override
  void onScrollViewDetached(ElScrollViewState scrollView) {
    _navbarSavedProgress = largeTitleNavbarProgress;
    _navbarLastHost = scrollView;
    _navbarAnimation?.dispose();
    _navbarAnimation = null;
    _navbarRange = 0;
    _navbarBottomExtent = 0;
    _navbarLayoutCollapseExtent = 0;
    _navbarAbsolutePosition = false;
    _navbarLayoutFlowExtra = 0;
    super.onScrollViewDetached(scrollView);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navbarReduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _navbarAnimation?.duration = largeTitleNavbarSnapDuration;
  }

  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    _rebaseNavbarAbsolutePosition();
    final rest = super.onPreScroll(input, remaining);
    return rest > 0 ? _consumeMeasuredCollapse(rest, _navbarRange, largeTitleNavbarProgress, _setNavbarProgress) : rest;
  }

  @override
  double onPostScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPostScroll(input, remaining);
    return rest < 0 ? _consumeMeasuredCollapse(rest, _navbarRange, largeTitleNavbarProgress, _setNavbarProgress) : rest;
  }

  double _resolveNavbarStretch(ElScrollSnapshot snapshot) =>
      math.min(.15, snapshot.leadingOverscroll / math.max(1, snapshot.viewportExtent));

  void _updateNavbarStretch(ElScrollDetails details) {
    if (!largeTitleNavbarStretch) return;
    if (_resolveNavbarStretch(details.previousSnapshot) != _resolveNavbarStretch(details.snapshot)) {
      _scheduleScrollMixinRebuild();
    }
  }

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    super.onScrollUpdate(details);
    final snap = details.snapshot;
    if (!snap.hasMetrics) return;
    final thumbFraction = snap.activity == .scrollbarDrag ? details.scrollView._scrollbarThumbDragFraction : null;
    final absolute =
        !snap.coordinateReset &&
        (snap.cause == .externalCommand ||
            snap.cause == .navigation ||
            snap.cause == .userInput &&
                (snap.activity == .scrollbarDrag ||
                    snap.activity == .programmatic ||
                    snap.activity == .idle ||
                    snap.activity == .unknown));
    if (_navbarBottomExtent > 0 && (thumbFraction != null || absolute)) {
      if (!_navbarAbsolutePosition) {
        _navbarAbsolutePosition = true;
        _scheduleScrollMixinRebuild();
      }
      // 绝对位置本身包含折叠行程，流布局保留该占位，避免正文再被头部高度变化推一次。
      final expandedRange =
          snap.maxScrollExtent - snap.minScrollExtent + _navbarLayoutCollapseExtent - _navbarLayoutFlowExtra;
      final offset = thumbFraction == null ? snap.contentOffset : thumbFraction * expandedRange;
      _setNavbarProgress((offset / _navbarRange).clamp(0.0, 1.0));
      _updateNavbarStretch(details);
      return;
    }
    // 顶部实测折叠区间之外始终紧凑，不能按反向位移重新展开。
    if (thumbFraction != null && _navbarRange > 0) {
      // 虚拟拖柄按实时总高映射，先还原展开总行程，再直接解出稳定进度，避免高度反馈来回振荡。
      final expandedRange = snap.maxScrollExtent - snap.minScrollExtent + _navbarLayoutCollapseExtent;
      final targetOffset = thumbFraction * expandedRange / (1 + thumbFraction);
      _setNavbarProgress((targetOffset / _navbarRange).clamp(0.0, 1.0));
    } else if (snap.contentOffset >= _navbarRange && _navbarRange > 0) {
      _setNavbarProgress(1);
    } else if (!snap.coordinateReset &&
        snap.motionDelta.abs() > precisionErrorTolerance &&
        (snap.cause == .externalCommand ||
            snap.cause == .navigation ||
            snap.cause == .userInput &&
                (snap.activity == .scrollbarDrag ||
                    snap.activity == .programmatic ||
                    snap.activity == .idle ||
                    snap.activity == .unknown))) {
      _setNavbarProgress(_navbarRange > 0 ? (snap.contentOffset / _navbarRange).clamp(0.0, 1.0) : 0);
    }
    _updateNavbarStretch(details);
  }

  @override
  void onScrollMetricsChanged(ElScrollMetricsDetails details) {
    super.onScrollMetricsChanged(details);
    _updateNavbarStretch(details);
  }

  @override
  void onInputStart(ElScrollSessionDetails details) {
    super.onInputStart(details);
    if (details.source != .unknown) _rebaseNavbarAbsolutePosition();
    _navbarAnimation?.stop();
  }

  void _rebaseNavbarAbsolutePosition() {
    if (!_navbarAbsolutePosition) return;
    _navbarAbsolutePosition = false;
    final position = scrollPosition;
    final correction = math.min(_navbarLayoutFlowExtra, math.max(0.0, scrollSnapshot.contentOffset));
    if (position != null && correction > 0) {
      // 相对输入以正文为起点；位置与额外占位一起扣除，视觉位置不变。
      final delta = axisDirectionIsReversed(position.axisDirection) ? correction : -correction;
      scrollView!._recordMixinLayoutCorrection(Axis.vertical, delta);
      position.correctPixels(position.pixels + delta);
    }
    _scheduleScrollMixinRebuild();
  }

  @override
  void onMotionCancelled(ElScrollSessionDetails details) {
    super.onMotionCancelled(details);
    _navbarAnimation?.stop();
  }

  @override
  Future<void>? onScrollSettle(ElScrollSessionDetails details) {
    final previous = super.onScrollSettle(details);
    if (!largeTitleNavbarSnap || !isScrollMotionCurrent(details)) return previous;
    final target = largeTitleNavbarProgress >= .5 ? 1.0 : 0.0;
    if (largeTitleNavbarProgress == target) return previous;
    if (_navbarReduceMotion) {
      _setNavbarProgress(target);
      return previous;
    } else {
      return _joinScrollSettles(
        previous,
        _navbarAnimation?.animateTo(target, curve: largeTitleNavbarSnapCurve).orCancel,
      );
    }
  }

  /// 构建自然尺寸导航头；bottom 先保留自然高度淡出内容，再与标题联动收起。
  Widget buildLargeTitleNavbar(
    BuildContext context, {
    required Widget largeTitle,
    required Widget compactTitle,
    Widget? leading,
    List<Widget> actions = const [],
    Widget? bottom,
  }) {
    final progress = largeTitleNavbarProgress;
    final fade = !largeTitleNavbarScale && largeTitleNavbarFade;
    return ElView(
      style: largeTitleNavbarStyle,
      child: _LargeTitleNavbarLayout(
        progress: largeTitleNavbarProgress,
        scale: largeTitleNavbarScale,
        fade: fade,
        center: largeTitleNavbarCenterTitle,
        stretch: largeTitleNavbarStretch ? _resolveNavbarStretch(scrollSnapshot) : 0,
        safeTop: MediaQuery.maybeOf(context)?.padding.top ?? 0,
        direction: Directionality.of(context),
        bottomPadding: bottom == null
            ? EdgeInsets.zero
            : largeTitleNavbarBottomPadding.resolve(Directionality.of(context)),
        bottomBorder: largeTitleNavbarBottomBorder,
        onRangeChanged: _measureNavbarRange,
        onBottomExtentChanged: _measureNavbarBottom,
        onLayoutCollapseChanged: _recordNavbarLayoutCollapse,
        children: [
          ElView(
            style: ElStyle(
              opacity: fade
                  ? 1 - progress
                  : progress < 1
                  ? 1
                  : 0,
            ),
            child: largeTitle,
          ),
          ElView(
            style: ElStyle(
              opacity: fade
                  ? progress
                  : progress >= 1
                  ? 1
                  : 0,
            ),
            child: compactTitle,
          ),
          ElView(child: leading),
          Row(mainAxisSize: .min, children: actions),
          ?bottom,
        ],
      ),
    );
  }
}
