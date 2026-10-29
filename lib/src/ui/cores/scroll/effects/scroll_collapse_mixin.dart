part of '../virtual/virtual_pipeline.dart';

double _consumeMeasuredCollapse(double remaining, double range, double progress, ValueChanged<double> update) {
  if (range <= 0 || remaining == 0) return remaining;
  final current = progress * range;
  final next = (current + remaining).clamp(0.0, range);
  final consumed = next - current;
  if (consumed.abs() > precisionErrorTolerance) update(next / range);
  final rest = remaining - consumed;
  if (rest.abs() <= precisionErrorTolerance) return 0.0;
  return rest.sign == remaining.sign && rest.abs() <= remaining.abs() ? rest : 0.0;
}

/// 折叠效果使用的滚动策略。
enum ElScrollCollapseMode {
  /// 观察实际移动方向，平移显隐且保留正常占位。
  direction,

  /// 跟随实际滚动增量平移，保留占位，不消费输入，也不在停手后吸附。
  followDelta,

  /// 先消费输入改变头部真实尺寸，再将余量交给正文。
  consumeDelta,
}

// 每帧只分配一份位移额度；反向确认消耗的距离和限速丢弃的距离都不留待以后补走。
class _CollapseFollowFilter {
  Duration? _frame;
  double _input = 0, _output = 0, _budget = 0;
  double _direction = 0, _reverse = 0;

  void reset() {
    _frame = null;
    _input = _output = _budget = _direction = _reverse = 0;
  }

  double apply(double delta, double maxVelocity, double reverseTolerance, double frameSeconds) {
    final frame = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    if (frame != _frame) {
      final elapsed = _frame == null ? frameSeconds : (frame - _frame!).inMicroseconds / 1000000;
      // 空闲时间不能积累成下一次输入的巨额额度；掉帧也最多放行两帧的距离。
      final seconds = elapsed > 0 && elapsed <= frameSeconds * 2 ? elapsed : frameSeconds;
      _frame = frame;
      _input = _output = 0;
      _budget = maxVelocity * seconds;
    }
    final direction = delta.sign;
    if (_direction == 0) _direction = direction;
    if (direction != _direction) {
      _reverse += delta.abs();
      if (_reverse < reverseTolerance) return 0;
      delta = direction * (_reverse - reverseTolerance);
      _direction = direction;
      _reverse = 0;
    } else {
      _reverse = 0;
    }
    if (!maxVelocity.isFinite || delta == 0) return delta;
    final previous = _output;
    _input += delta.abs();
    final knee = _budget / 2;
    // 半速以内保持 1:1，之后平滑逼近上限，避免硬裁速度带来的突变。
    _output = _input <= knee ? _input : _budget - knee * knee / _input;
    return delta.sign * (_output - previous);
  }
}

/// 自动测量的显隐与折叠效果，动画与状态由当前最小 State 管理。
mixin ElScrollCollapseMixin<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  @override
  bool? get scrollEffectGlobalObservation => true;
  AnimationController? _collapseAnimation;
  TickerFuture? _collapseFuture;
  double _collapseTarget = 0;
  double _collapseTravel = 0;

  /// 上一次解绑时的视觉进度与宿主；同宿主重挂据此恢复，换宿主则丢弃。
  double _collapseSavedProgress = 0;
  ElScrollViewState? _collapseLastHost;
  bool _collapseReduceMotion = false;
  double _collapseRange = 0;
  double _collapsePixelRatio = 1;
  double _collapseFrameSeconds = 1 / 60;
  _CollapseFollowFilter? _followFilter;
  double _followPixelRemainder = 0;
  Duration? _thresholdSampleStamp;
  double? _thresholdSampleSeconds;
  double _thresholdSampleDelta = 0;

  /// 使用方向显隐、增量平移或真实尺寸折叠。
  @protected
  ElScrollCollapseMode get scrollCollapseMode => .direction;

  /// 朝内容终点滚动且速度超过此阈值时折叠；单位为逻辑像素/秒，单侧缺省时复用另一侧。
  @protected
  double? get scrollCollapseVelocityThreshold => null;

  /// 朝内容起点滚动且速度绝对值超过此阈值时展开；低速或停止保持目标，回到顶部始终展开。
  @protected
  double? get scrollCollapseExpandVelocityThreshold => null;

  /// 位置超过此值时折叠，小于等于时展开；与速度阈值及输入消费模式互斥。
  @protected
  double? get scrollCollapseOffset => null;

  bool get _hasVelocityThreshold =>
      scrollCollapseVelocityThreshold != null || scrollCollapseExpandVelocityThreshold != null;
  bool get _hasCollapseThreshold => scrollCollapseOffset != null || _hasVelocityThreshold;

  /// 尺寸折叠在输入运动结束后是否吸附至最近端点；增量平移不吸附。
  @protected
  bool get scrollCollapseSnap => true;

  /// 跟手平移的速度上限（逻辑像素/秒），半速以内保持 1:1；默认不限制。
  @protected
  double get scrollCollapseFollowMaxVelocity => double.infinity;

  /// 跟手反向时先确认的距离，超过后仅使用余量；默认无反向门槛。
  @protected
  double get scrollCollapseFollowReverseTolerance => 0;

  @override
  Object? get scrollInputSlot =>
      scrollCollapseMode == .consumeDelta ? super.scrollInputSlot ?? this : super.scrollInputSlot;

  @override
  Iterable<ElScrollEffectTrack> get scrollEffectTracks => [
    ...super.scrollEffectTracks,
    if (scrollCollapseMode == .consumeDelta && _collapseRange > 0)
      ElScrollEffectTrack(
        effectId: #scrollCollapse,
        minValue: 0,
        maxValue: 1,
        unit: .progress,
        pixelsPerUnit: _collapseRange,
        readValue: () => scrollCollapseProgress,
        updateValue: _setCollapseProgress,
      ),
  ];

  void _setCollapseProgress(double value) {
    _collapseTarget = value;
    final animation = _collapseAnimation;
    if (animation == null || animation.value == value && !animation.isAnimating) return;
    animation.value = value;
  }

  void _measureCollapseRange(double value) {
    if (!mountedForScrollCallbacks || value == _collapseRange) return;
    _collapseRange = value;
    updateScrollEffect();
    // 使用实测行程同步平移的上层需要更新；正常进度变化不改变行程，不增加逐帧重建。
    if (scrollCollapseProgress > 0) _scheduleScrollMixinRebuild();
  }

  /// 同方向累计超过此逻辑距离才改变显隐目标。
  @protected
  double get scrollCollapseTolerance => 12;

  /// 内容到达视觉起点时恢复显示。
  @protected
  bool get scrollCollapseExpandAtStart => true;

  /// 是否同时淡出隐藏内容。
  @protected
  bool get scrollCollapseFade => false;

  /// 展开和收起的动画时长。
  @protected
  Duration get scrollCollapseSnapDuration => const Duration(milliseconds: 220);

  /// 展开和收起的动画曲线。
  @protected
  Curve get scrollCollapseSnapCurve => Curves.easeOutCubic;

  /// 是否允许独立的程序性位置命令改变观察型效果的显隐位置。
  @protected
  bool get scrollCollapseRespondToCommands => false;

  /// 当前隐藏进度，0 为完整显示，1 为完整隐藏。
  double get scrollCollapseProgress => _collapseAnimation?.value ?? 0;

  /// 实测主轴行程；平移模式使用自然尺寸，尺寸折叠使用展开与收起端点差。
  double get scrollCollapseRange {
    if (scrollCollapseMode == .consumeDelta) return _collapseRange;
    final size = scrollItemSnapshot.layoutSize;
    return size == null
        ? 0
        : _resolvedScrollAxis == Axis.horizontal
        ? size.width
        : size.height;
  }

  /// 当前内容是否已经完整隐藏。
  bool get scrollCollapseHidden => scrollCollapseProgress >= 1;

  @override
  bool get observesScrollItemSize => true;

  @override
  bool get scrollItemPreserveAnchor => scrollCollapseMode != .consumeDelta && super.scrollItemPreserveAnchor;

  void _validateCollapseConfiguration() {
    if (!scrollCollapseTolerance.isFinite || scrollCollapseTolerance < 0 || scrollCollapseSnapDuration.isNegative) {
      throw FlutterError('折叠阈值必须有限且非负，动画时长不得为负。');
    }
    if (scrollCollapseFollowMaxVelocity.isNaN ||
        scrollCollapseFollowMaxVelocity <= 0 ||
        !scrollCollapseFollowReverseTolerance.isFinite ||
        scrollCollapseFollowReverseTolerance < 0) {
      throw FlutterError('跟手速度上限必须为正数或正无穷，反向确认距离必须有限且非负。');
    }
    for (final value in [
      scrollCollapseVelocityThreshold,
      scrollCollapseExpandVelocityThreshold,
      scrollCollapseOffset,
    ]) {
      if (value != null && (!value.isFinite || value < 0)) throw FlutterError('速度与位置阈值必须有限且非负。');
    }
    if (_hasCollapseThreshold && scrollCollapseMode == .consumeDelta ||
        _hasVelocityThreshold && (scrollCollapseMode == .followDelta || scrollCollapseOffset != null)) {
      throw FlutterError('速度阈值不能与跟手、位置阈值混用，输入消费模式不能使用显隐阈值。');
    }
  }

  double? _collapseThresholdVelocity(ElScrollSnapshot snapshot) {
    if (snapshot.velocity != null ||
        (snapshot.activity != .scrollbarDrag && snapshot.activity != .pointerScroll) ||
        snapshot.timeStamp == null) {
      _thresholdSampleStamp = null;
      return snapshot.velocity;
    }
    // 原生拖柄与离散滚轮可能没有受控速度；仅对明确的输入使用同一帧时钟内的实际位移。
    final stamp = snapshot.timeStamp!;
    if (stamp != _thresholdSampleStamp) {
      _thresholdSampleSeconds = _thresholdSampleStamp == null
          ? null
          : (stamp - _thresholdSampleStamp!).inMicroseconds / 1000000;
      _thresholdSampleDelta = 0;
      _thresholdSampleStamp = stamp;
    }
    _thresholdSampleDelta += snapshot.motionDelta;
    final seconds = _thresholdSampleSeconds;
    return seconds != null && seconds > 0 ? _thresholdSampleDelta / seconds : null;
  }

  void _updateCollapseThreshold(ElScrollSnapshot snapshot, {bool animate = true, bool readVelocity = true}) {
    if (!_hasCollapseThreshold || !snapshot.hasMetrics) return;
    _followFilter = null;
    _followPixelRemainder = 0;
    final offset = scrollCollapseOffset;
    double? target;
    if (offset != null) {
      if (scrollCollapseMode == .followDelta) {
        final range = scrollCollapseRange;
        _setCollapseProgress(range <= 0 ? 0 : ((snapshot.contentOffset - offset) / range).clamp(0.0, 1.0));
        return;
      }
      target = snapshot.contentOffset > offset ? 1 : 0;
    } else if (snapshot.atStart) {
      target = 0;
    } else if (readVelocity &&
        !snapshot.coordinateReset &&
        snapshot.motionDelta.abs() > precisionErrorTolerance &&
        snapshot.leadingOverscroll == 0 &&
        snapshot.trailingOverscroll == 0) {
      final velocity = _collapseThresholdVelocity(snapshot);
      final observable =
          snapshot.cause == .userInput || snapshot.cause == .ballistic || scrollCollapseRespondToCommands;
      if (observable && velocity != null && velocity.isFinite) {
        final collapse = scrollCollapseVelocityThreshold ?? scrollCollapseExpandVelocityThreshold!;
        final expand = scrollCollapseExpandVelocityThreshold ?? collapse;
        // 方向决定目标，速度只负责触发；反向初期可能仍有旧方向的速度样本，必须与实际位移同向。
        target = snapshot.motionDelta > 0 && velocity > collapse
            ? 1
            : snapshot.motionDelta < 0 && velocity < -expand
            ? 0
            : null;
      }
    }
    if (target == null) return;
    _collapseTravel = 0;
    if (animate) {
      _animateCollapseTo(target);
    } else {
      _setCollapseProgress(target);
    }
  }

  @override
  void onScrollViewAttached(ElScrollViewState scrollView) {
    super.onScrollViewAttached(scrollView);
    _validateCollapseConfiguration();
    // 同一宿主重挂：进度是持久视觉状态，不能因为绑定重建而清零；
    // 换到另一宿主才按初始规则从 0 开始。
    final sameSource = identical(_collapseLastHost, scrollView);
    _collapseAnimation = AnimationController(vsync: scrollView, duration: scrollCollapseSnapDuration)
      ..addListener(_scheduleScrollMixinRebuild);
    if (sameSource) {
      _collapseAnimation!.value = _collapseSavedProgress;
      _collapseTarget = _collapseSavedProgress;
    }
    if (_hasCollapseThreshold) _updateCollapseThreshold(scrollSnapshot, animate: false, readVelocity: false);
  }

  @override
  void onScrollViewDetached(ElScrollViewState scrollView) {
    _collapseSavedProgress = scrollCollapseProgress;
    _collapseLastHost = scrollView;
    _collapseAnimation?.dispose();
    _collapseAnimation = null;
    _collapseFuture = null;
    _collapseTarget = _collapseTravel = 0;
    _followFilter = null;
    _followPixelRemainder = 0;
    _thresholdSampleStamp = null;
    super.onScrollViewDetached(scrollView);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _collapseReduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _collapsePixelRatio = View.maybeOf(context)?.devicePixelRatio ?? 1;
    final refreshRate = View.maybeOf(context)?.display.refreshRate ?? 60;
    _collapseFrameSeconds = 1 / (refreshRate.isFinite && refreshRate > 0 ? refreshRate : 60);
    if (_collapseReduceMotion) _collapseAnimation?.value = _collapseTarget;
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateCollapseConfiguration();
    _collapseAnimation?.duration = scrollCollapseSnapDuration;
    if (_hasCollapseThreshold) _updateCollapseThreshold(scrollSnapshot, readVelocity: false);
  }

  @override
  void onScrollMetricsChanged(ElScrollMetricsDetails details) {
    super.onScrollMetricsChanged(details);
    _updateCollapseThreshold(details.snapshot, animate: false, readVelocity: false);
  }

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    super.onScrollUpdate(details);
    final snapshot = details.snapshot;
    if (_hasCollapseThreshold) {
      final rebase = snapshot.coordinateReset || snapshot.cause == .layoutCorrection || snapshot.cause == .restoration;
      _updateCollapseThreshold(snapshot, animate: !rebase, readVelocity: !rebase);
      return;
    }
    if (!snapshot.hasMetrics || snapshot.coordinateReset) {
      _collapseTravel = 0;
      _followFilter?.reset();
      _followPixelRemainder = 0;
      return;
    }
    if (snapshot.cause == ElScrollUpdateCause.layoutCorrection || snapshot.cause == ElScrollUpdateCause.restoration) {
      return;
    }
    if (scrollCollapseMode == .consumeDelta) {
      if (snapshot.motionDelta.abs() <= precisionErrorTolerance) return;
      // 相对输入在 pre/post 已处理；绝对用户定位只观察，不再次消费其预算。
      if (snapshot.cause == .userInput &&
              (snapshot.activity == .scrollbarDrag ||
                  snapshot.activity == .programmatic ||
                  snapshot.activity == .idle ||
                  snapshot.activity == .unknown) ||
          scrollCollapseRespondToCommands && snapshot.cause == .externalCommand) {
        if (snapshot.atStart && scrollCollapseExpandAtStart) {
          _setCollapseProgress(0);
        } else if (_collapseRange > 0) {
          _setCollapseProgress((scrollCollapseProgress + snapshot.motionDelta / _collapseRange).clamp(0.0, 1.0));
        }
      }
      return;
    }
    if (scrollCollapseMode == .followDelta) {
      if (!scrollCollapseRespondToCommands && snapshot.cause != .userInput && snapshot.cause != .ballistic) return;
      final extent = scrollCollapseRange;
      final command = snapshot.cause == .externalCommand || snapshot.cause == .navigation;
      final filtered =
          !command && (scrollCollapseFollowMaxVelocity.isFinite || scrollCollapseFollowReverseTolerance > 0);
      if (snapshot.atStart && scrollCollapseExpandAtStart) {
        _followFilter?.reset();
        _followPixelRemainder = 0;
        // 到顶可短暂归位，避免高速回顶瞬间弹出；明确跳转命令和减少动画仍直接到位。
        if (filtered) {
          _animateCollapseTo(0);
        } else {
          _setCollapseProgress(0);
        }
      } else if (extent > 0 && snapshot.motionDelta.abs() > precisionErrorTolerance) {
        var delta = snapshot.motionDelta;
        if (filtered) {
          delta = (_followFilter ??= _CollapseFollowFilter()).apply(
            delta,
            scrollCollapseFollowMaxVelocity,
            scrollCollapseFollowReverseTolerance,
            _collapseFrameSeconds,
          );
        } else {
          _followFilter?.reset();
          _followPixelRemainder = 0;
        }
        final naturalShift = (scrollCollapseProgress * extent + delta + _followPixelRemainder).clamp(0.0, extent);
        var shift = naturalShift;
        // 沿用旧导航的物理像素对齐，只量化绘制位移，不修改正文滚动距离。
        if (_collapsePixelRatio > 0 && _collapsePixelRatio.isFinite) {
          shift = (shift * _collapsePixelRatio).roundToDouble() / _collapsePixelRatio;
        }
        shift = shift.clamp(0.0, extent);
        // 只保留不足半个物理像素的取整误差，确保低速和不同刷新率不会丢失小位移。
        _followPixelRemainder = filtered ? naturalShift - shift : 0;
        _setCollapseProgress((shift / extent).clamp(0.0, 1.0));
      }
      return;
    }
    if (scrollCollapseExpandAtStart && snapshot.atStart) {
      _collapseTravel = 0;
      _animateCollapseTo(0);
      return;
    }
    if (!scrollCollapseRespondToCommands &&
        snapshot.cause != ElScrollUpdateCause.userInput &&
        snapshot.cause != ElScrollUpdateCause.ballistic) {
      return;
    }
    final delta = snapshot.motionDelta;
    if (delta.abs() <= precisionErrorTolerance) return;
    if (_collapseTravel.sign != delta.sign) _collapseTravel = 0;
    _collapseTravel += delta;
    if (_collapseTravel.abs() >= scrollCollapseTolerance) _animateCollapseTo(delta > 0 ? 1 : 0);
  }

  double _consumeCollapse(double remaining) {
    return _consumeMeasuredCollapse(remaining, _collapseRange, scrollCollapseProgress, _setCollapseProgress);
  }

  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    return scrollCollapseMode == .consumeDelta && rest > 0 ? _consumeCollapse(rest) : rest;
  }

  @override
  double onPostScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPostScroll(input, remaining);
    return scrollCollapseMode == .consumeDelta && rest < 0 ? _consumeCollapse(rest) : rest;
  }

  @override
  Future<void>? onScrollSettle(ElScrollSessionDetails details) {
    final previous = super.onScrollSettle(details);
    if (!isScrollMotionCurrent(details)) return previous;
    if (_hasVelocityThreshold) {
      // 停止只完成既有动画和到顶归位，不能按零速度触发新的显隐目标。
      _updateCollapseThreshold(details.snapshot, readVelocity: false);
    }
    if (scrollCollapseMode == .followDelta) {
      return scrollCollapseExpandAtStart && details.snapshot.atStart
          ? _joinScrollSettles(previous, _animateCollapseTo(0)?.orCancel)
          : previous;
    }
    final target = scrollCollapseMode == .direction
        ? _collapseTarget
        : scrollCollapseProgress >= .5
        ? 1.0
        : 0.0;
    if (scrollCollapseMode == .consumeDelta && !scrollCollapseSnap) return previous;
    return _joinScrollSettles(previous, _animateCollapseTo(target)?.orCancel);
  }

  TickerFuture? _animateCollapseTo(double target) {
    final animation = _collapseAnimation;
    if (animation == null) return null;
    if (target == _collapseTarget && animation.isAnimating) return _collapseFuture;
    _collapseTarget = target;
    if (animation.value == target) {
      animation.stop();
      _collapseFuture = null;
      return null;
    }
    if (_collapseReduceMotion || scrollCollapseSnapDuration == Duration.zero) {
      animation.value = target;
      _collapseFuture = null;
    } else {
      return _collapseFuture = animation.animateTo(
        target,
        // 方向反转沿用 AnimatedSlide 的完整过渡时长，不能按剩余行程突然加速。
        duration: scrollCollapseMode == .direction ? scrollCollapseSnapDuration : null,
        curve: scrollCollapseSnapCurve,
      );
    }
    return null;
  }

  @override
  void onInputStart(ElScrollSessionDetails details) {
    super.onInputStart(details);
    // 离散滚轮跨事件估速，其余新手势不继承上一轮的时间样本。
    if (_hasVelocityThreshold && details.source != .pointerSignal) _thresholdSampleStamp = null;
    if (scrollCollapseMode == .followDelta) _collapseAnimation?.stop();
    // 观察型效果跨输入连续播放并累计防抖距离；只有独占输入的尺寸折叠需要停下吸附。
    if (scrollCollapseMode == .consumeDelta) {
      _collapseAnimation?.stop();
      _collapseTravel = 0;
    }
  }

  @override
  void onMotionCancelled(ElScrollSessionDetails details) {
    super.onMotionCancelled(details);
    if (scrollCollapseMode == .consumeDelta) {
      _collapseAnimation?.stop();
      _collapseTravel = 0;
    }
  }

  @override
  void onScrollItemUpdate(ElScrollItemUpdateDetails details) {
    super.onScrollItemUpdate(details);
    if (scrollCollapseOffset != null &&
        scrollCollapseMode == .followDelta &&
        details.previousSnapshot.layoutSize != details.snapshot.layoutSize) {
      _updateCollapseThreshold(scrollSnapshot, animate: false, readVelocity: false);
      return;
    }
    if (scrollCollapseMode != .consumeDelta &&
        scrollCollapseProgress != 0 &&
        details.previousSnapshot.layoutSize != details.snapshot.layoutSize) {
      _scheduleScrollMixinRebuild();
    }
  }

  /// 构建显隐内容或展开/收起槽位，真实尺寸由正常布局自动取得。
  Widget buildScrollCollapse(BuildContext context, {Widget? child, Widget? expanded, Widget? collapsed}) {
    if ((child == null) == (expanded == null) || child != null && collapsed != null) {
      throw FlutterError('提供 child，或提供 expanded 与可选的 collapsed，不能混用。');
    }
    final progress = scrollCollapseProgress;
    if (scrollCollapseMode == .consumeDelta) {
      return _ScrollCollapseLayout(
        axis: _resolvedScrollAxis ?? Axis.vertical,
        progress: progress,
        onRangeChanged: _measureCollapseRange,
        children: [
          ElView(
            style: ElStyle(opacity: collapsed != null || scrollCollapseFade ? 1 - progress : null),
            child: child ?? expanded,
          ),
          if (collapsed != null)
            ElView(
              style: ElStyle(opacity: progress),
              child: collapsed,
            ),
        ],
      );
    }
    final horizontal = _resolvedScrollAxis == Axis.horizontal;
    final extent = scrollCollapseRange;
    return ElView(
      style: ElStyle(
        transform: progress == 0
            ? null
            : horizontal
            ? .translateX(-extent * progress)
            : .translateY(-extent * progress),
        opacity: scrollCollapseFade ? 1 - progress : null,
      ),
      child: child ?? expanded,
    );
  }
}
