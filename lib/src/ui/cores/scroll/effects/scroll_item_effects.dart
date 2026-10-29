part of '../virtual/virtual_pipeline.dart';

/// 根据自然流的可见距离进行淡入平移，支持反向退出与 State 生命周期内仅一次。
mixin ElScrollRevealMixin<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  double _revealProgress = 1;
  bool _revealCompleted = false;
  bool _revealReduceMotion = false;

  /// 完全隐藏时相对正常位置的平移量。
  @protected
  Offset get scrollRevealOffset => const Offset(0, 24);

  /// 是否只在当前 State 首次进入时渐显，之后保留完整显示。
  @protected
  bool get scrollRevealOnce => false;

  /// 是否同时渐变透明度。
  @protected
  bool get scrollRevealFade => true;

  /// 达到完整显示所需的可见距离，自动限制在真实子项尺寸内。
  @protected
  double get scrollRevealDistance => 64;

  /// 当前显示进度，0 为隐藏，1 为完整显示。
  double get scrollRevealProgress => _revealReduceMotion || scrollRevealOnce && _revealCompleted ? 1 : _revealProgress;

  @override
  bool? get scrollEffectGlobalObservation => super.scrollEffectGlobalObservation ?? false;
  @override
  bool get observesScrollItemUpdates =>
      !_revealReduceMotion && (!scrollRevealOnce || !_revealCompleted) || super.observesScrollItemUpdates;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_revealReduceMotion != reduce) {
      _revealReduceMotion = reduce;
      updateScrollEffect();
    }
    _updateReveal(scrollItemSnapshot);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateReveal(scrollItemSnapshot);
  }

  @override
  void onScrollItemUpdate(ElScrollItemUpdateDetails details) {
    super.onScrollItemUpdate(details);
    _updateReveal(details.snapshot);
  }

  void _updateReveal(ElScrollItemSnapshot item) {
    if (!item.attached || item.layoutSize == null) return;
    if (scrollRevealOnce && _revealCompleted) return;
    final distance = math.min(item.itemExtent, scrollRevealDistance);
    final next = distance <= 0 ? 1.0 : (item.visibleExtent / distance).clamp(0.0, 1.0);
    if (next != _revealProgress) {
      _revealProgress = next;
      _scheduleScrollMixinRebuild();
    }
    if (scrollRevealOnce && next == 1 && item.isVisible) {
      _revealCompleted = true;
      updateScrollEffect();
    }
  }

  /// 构建自然流驱动的淡入平移，不以自身变换后的坐标反推下一帧。
  Widget buildScrollReveal(BuildContext context, {required Widget child}) {
    if (!scrollRevealOffset.isFinite || !scrollRevealDistance.isFinite || scrollRevealDistance < 0) {
      throw FlutterError('显隐偏移必须有限，显隐距离必须有限且非负。');
    }
    final progress = scrollRevealProgress;
    final offset = scrollRevealOffset * (1 - progress);
    return ElView(
      style: ElStyle(
        opacity: scrollRevealFade ? progress : null,
        transform: offset == Offset.zero ? null : ElTransform.translate(offset.dx, offset.dy),
      ),
      child: child,
    );
  }
}

/// 把自然流相对视口中心的位置映射为有界视差，静止端点不重复重建。
mixin ElParallaxMixin<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  double _parallaxOffset = 0;
  bool _parallaxReduceMotion = false;

  /// 视差相对正文位移的比例，正值使内容移动更慢。
  @protected
  double get parallaxFactor => .35;

  /// 主轴偏移的绝对上限。
  @protected
  double get parallaxMaxOffset => 80;

  /// 当前主轴展示偏移。
  double get parallaxOffset => _parallaxReduceMotion ? 0 : _parallaxOffset;

  @override
  bool? get scrollEffectGlobalObservation => super.scrollEffectGlobalObservation ?? false;
  @override
  bool get observesScrollItemUpdates =>
      !_parallaxReduceMotion && parallaxFactor != 0 || super.observesScrollItemUpdates;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_parallaxReduceMotion != reduce) {
      _parallaxReduceMotion = reduce;
      updateScrollEffect();
    }
    _updateParallax(scrollItemSnapshot);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateParallax(scrollItemSnapshot);
  }

  @override
  void onScrollItemUpdate(ElScrollItemUpdateDetails details) {
    super.onScrollItemUpdate(details);
    _updateParallax(details.snapshot);
  }

  void _updateParallax(ElScrollItemSnapshot item) {
    if (!item.attached || item.layoutSize == null) return;
    final next = ((item.viewportExtent / 2 - item.leadingOffset - item.itemExtent / 2) * parallaxFactor).clamp(
      -parallaxMaxOffset,
      parallaxMaxOffset,
    );
    if (next == _parallaxOffset) return;
    _parallaxOffset = next;
    _scheduleScrollMixinRebuild();
  }

  /// 构建主轴视差展示，保留自然布局占位和原始几何。
  Widget buildParallax(BuildContext context, {required Widget child}) {
    if (!parallaxFactor.isFinite || !parallaxMaxOffset.isFinite || parallaxMaxOffset < 0) {
      throw FlutterError('视差比例必须有限，最大偏移必须有限且非负。');
    }
    final offset = parallaxOffset;
    return ElView(
      style: ElStyle(
        transform: offset == 0
            ? null
            : _resolvedScrollAxis == Axis.horizontal
            ? .translateX(offset)
            : .translateY(offset),
      ),
      child: child,
    );
  }
}

/// 根据合法内容位置构建阅读进度，支持所有位置来源及动态内容范围。
mixin ElScrollProgressMixin<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  double _scrollProgress = 0;

  /// 进度条外观；主轴长度由实际进度控制。
  @protected
  ElStyle get scrollProgressStyle => const ElStyle(height: 3, bgColor: Color(0xff808080));

  /// 进度条的展示方向，与 requestedScrollAxis 选择的滚动来源独立。
  @protected
  Axis get scrollProgressAxis => Axis.horizontal;

  /// 当前阅读进度，空范围为 0，到末端精确为 1。
  double get scrollProgressValue => _scrollProgress;

  @override
  bool? get scrollEffectGlobalObservation => true;

  @override
  void onScrollViewAttached(ElScrollViewState scrollView) {
    super.onScrollViewAttached(scrollView);
    _updateScrollProgress(scrollSnapshot);
  }

  void _updateScrollProgress(ElScrollSnapshot snapshot) {
    final range = snapshot.maxScrollExtent - snapshot.minScrollExtent;
    final next = !snapshot.hasMetrics || range <= 0 ? 0.0 : (snapshot.contentOffset / range).clamp(0.0, 1.0);
    if (next == _scrollProgress) return;
    _scrollProgress = next;
    _scheduleScrollMixinRebuild();
  }

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    super.onScrollUpdate(details);
    _updateScrollProgress(details.snapshot);
  }

  @override
  void onScrollMetricsChanged(ElScrollMetricsDetails details) {
    super.onScrollMetricsChanged(details);
    _updateScrollProgress(details.snapshot);
  }

  /// 构建进度条；外层负责可用空间，内层按百分比绘制实际长度。
  Widget buildScrollProgress(BuildContext context) => ElView(
    style: const ElStyle(alignment: .topLeft),
    child: ElView(
      style: scrollProgressAxis == .horizontal
          ? scrollProgressStyle.copyWith(width: '${scrollProgressValue * 100}%')
          : scrollProgressStyle.copyWith(height: '${scrollProgressValue * 100}%'),
    ),
  );
}
