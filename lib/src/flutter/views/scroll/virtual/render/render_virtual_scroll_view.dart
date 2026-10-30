part of '../../common/render/scroll_viewport_base.dart';

class VirtualScrollbarDragStatus {
  const VirtualScrollbarDragStatus({required this.dragging, this.thumbFraction, this.edge});

  const VirtualScrollbarDragStatus.dragging() : dragging = true, thumbFraction = null, edge = null;

  const VirtualScrollbarDragStatus.updated(this.thumbFraction) : dragging = true, edge = null;

  const VirtualScrollbarDragStatus.ended(this.edge) : dragging = false, thumbFraction = null;

  final bool dragging;

  /// Thumb position as a fraction of the visible scrollbar track while held.
  ///
  /// This is intentionally not the same thing as content pixels. The widget
  /// layer maps it through the current measured/estimated extent model so
  /// unknown item heights can still correct synchronously.
  final double? thumbFraction;

  /// Visual edge at release, if the thumb is close enough to an edge to keep
  /// the scroll position pinned after extent corrections.
  final ScrollbarDragEdge? edge;
}

/// RenderObject viewport used by [ElScrollView].
///
/// It lays out the virtual content render object using normal Flutter box
/// layout, but paints, hit-tests, and exposes semantics only for the visible
/// window. Scroll input and scrollbar dragging stay in the render layer; item
/// measurement, extent estimation, and mounted-window decisions stay in
/// [ElScrollView].
///
/// 双轴模式（[horizontalPosition] 非空）下横向**不虚拟化**：横向内容宽 =
/// 当前 mounted items 的最大交叉轴 extent（mounted-only 撑）。主轴滚动导致
/// mounted 窗口变化时，横向 maxScrollExtent 会随之动态变化、横向滚动条
/// thumb 会漂移——这是明确接受的预期语义，不是 bug。
abstract class RenderVirtualScrollView extends RenderScrollViewportBase {
  static const int _maxLayoutCycles = 10;

  RenderVirtualScrollView({
    required super.position,
    required super.axis,
    required super.axisDirection,
    required super.physics,
    required super.velocityTrackerBuilder,
    required super.multitouchDragStrategy,
    super.horizontalPosition,
    super.horizontalAxisDirection,
    super.devicePixelRatio,
    super.dragDevices,
    super.pointerAxisModifiers,
    super.mouseWheelHorizontalModifiers,
    super.gestureSettings,
    super.clipBehavior,
    super.padding,
    double spacing = 0.0,
    bool shrinkWrap = false,
    super.excludeSemantics,
    super.semanticsRole,
    super.ignorePointer,
    super.canDrag,
    super.dragStartDistance,
    this.onScrollbarDragChanged,
    super.event,
    super.deltaInterceptor,
    super.horizontalDeltaInterceptor,
    super.onScrollInputActivityChanged,
    super.smoothScroll,
  }) : super(mainAxisGap: spacing, debugHorizontalSmoothScrollLabel: 'ElScrollView horizontal pointer scroll') {
    _shrinkWrap = shrinkWrap;
  }

  /// 是否按完整子内容布局（`ElScrollView.shrinkWrap` 的 render 面）。
  ///
  /// `true` 时 State 强制全量挂载 child，[performLayout] 实测完整 content
  /// 后以完整内容宽高回填容器尺寸，再由父级约束钳制；虚拟挂窗不再生效。
  bool _shrinkWrap = false;

  /// [shrinkWrap] 的公开 getter。
  bool get shrinkWrap => _shrinkWrap;

  /// 默认视口仅由父约束定尺，内容重排不应使祖先重新布局。
  @override
  bool get sizedByParent => !_shrinkWrap;

  /// [shrinkWrap] 的公开 setter（widget 更新通道）。
  set shrinkWrap(bool value) {
    if (_shrinkWrap == value) return;
    _shrinkWrap = value;
    if (parent == null) {
      markNeedsLayout();
    } else {
      markNeedsLayoutForSizedByParentChange();
    }
  }

  /// 主轴 item 间距（基座字段的 virtual 命名面）。
  double get spacing => _mainAxisGap;

  set spacing(double value) {
    assert(value >= 0.0);
    if (_mainAxisGap == value) return;
    _mainAxisGap = value;
    markNeedsLayout();
  }

  /// dpr 变化在 virtual 侧是 layout 级：item extent 网格对齐参与布局；
  /// 滚动 transform 本身始终保留 raw 亚像素。
  @override
  void didChangeDevicePixelRatio() => markNeedsLayout();

  double scrollbarPositionPixelsForVisualFraction(double visualFraction) {
    if (!_position.hasContentDimensions) return _position.pixels;
    return _positionPixelsForVisualFraction(visualFraction, _position.maxScrollExtent - _position.minScrollExtent);
  }

  /// widget 层 thumb 快拖起手：清掉上一轮分数并通知 state 进入拖拽态。
  void handleScrollbarDragStarted() {
    _scrollbarThumbDragFraction = null;
    _handleScrollbarDragChanged(const VirtualScrollbarDragStatus.dragging());
  }

  /// widget 层 thumb 快拖移动：记住分数（layout 期据此 correctPixels）并回流 state。
  void handleScrollbarDragUpdate(double visualFraction) {
    final next = visualFraction.clamp(0.0, 1.0).toDouble();
    final current = _scrollbarThumbDragFraction;
    if (current == null || (current - next).abs() > precisionErrorTolerance) {
      _scrollbarThumbDragFraction = next;
    }
    _handleScrollbarDragChanged(VirtualScrollbarDragStatus.updated(visualFraction));
  }

  /// widget 层 thumb 快拖松手：清分数并把贴边信息回流 state（用于 extent
  /// 修正后仍钉在边缘）。
  void handleScrollbarDragEnded(ScrollbarDragEdge? edge) {
    _scrollbarThumbDragFraction = null;
    _handleScrollbarDragChanged(VirtualScrollbarDragStatus.ended(edge));
  }

  /// 当前滚动位置贴住的视觉边缘；null = 不贴边。判据委托 geometry 模块，与
  /// state / content render 三方逐位一致。
  ScrollbarDragEdge? scrollbarDragEdge() {
    if (!_position.hasPixels || !_position.hasContentDimensions) return null;
    final scrollExtent = _position.maxScrollExtent - _position.minScrollExtent;
    // overscrollCountsAsPinned：滚动条侧沿用单向判据，越过 max 端（bouncing
    // 回弹期）仍算贴住 trailing，与删除前逐字一致。
    return switch (VirtualScrollGeometry.pinnedEdge(
      _contentScrollPixels(),
      scrollExtent,
      overscrollCountsAsPinned: true,
    )) {
      VirtualScrollEdge.min => ScrollbarDragEdge.leading,
      VirtualScrollEdge.max => ScrollbarDragEdge.trailing,
      null => null,
    };
  }

  /// widget 层 thumb 拖拽状态回流通道；纯回调、无渲染副作用，赋值无需标脏。
  ValueChanged<VirtualScrollbarDragStatus>? onScrollbarDragChanged;

  /// 布局期度量回调：`(主轴视口 extent, 交叉轴 extent)`，在 size 落定后、排
  /// content child **之前**于 `invokeLayoutCallback` 窗口内同帧调用。
  ///
  /// why：替代原先挂在 build 里的 `LayoutBuilder`（包内禁用官方行为类 widget）。
  /// 该窗口允许对后代 element markNeedsBuild / 改子树（官方 SliverMultiBoxAdaptor
  /// 同款契约），新露出的行因此进入**同一** performLayout 的 child.layout，
  /// 不会像 post-frame 重建那样晚一帧挂载。
  void Function(double viewportExtent, double crossAxisExtent)? onLayoutMetrics;

  /// Element 在同帧布局窗口内更新 scrollbar 内部成员。
  VoidCallback? onLayoutChrome;

  /// 只有条带结构变化时才进入 Element 的布局构建窗口。
  bool Function()? needsChromeReconcile;

  /// 正文尺寸收敛后布局直接挂载的 scrollbar 成员。
  @protected
  void layoutChromeChildren();

  double _verticalScrollbarInset = 0.0;

  /// 滚动条边缘占位配置，由 Widget 结构更新。
  double get verticalScrollbarInset => _verticalScrollbarInset;

  /// 更新滚动条占位配置并重新布局。
  set verticalScrollbarInset(double value) {
    if (_verticalScrollbarInset == value) return;
    _verticalScrollbarInset = value;
    _refreshViewportInsets();
    markNeedsLayout();
  }

  double _horizontalScrollbarInset = 0.0;

  /// 滚动条边缘占位配置，由 Widget 结构更新。
  double get horizontalScrollbarInset => _horizontalScrollbarInset;

  /// 更新滚动条占位配置并重新布局。
  set horizontalScrollbarInset(double value) {
    if (_horizontalScrollbarInset == value) return;
    _horizontalScrollbarInset = value;
    _refreshViewportInsets();
    markNeedsLayout();
  }

  bool _verticalScrollbarLeading = false;

  /// 滚动条边缘占位配置，由 Widget 结构更新。
  bool get verticalScrollbarLeading => _verticalScrollbarLeading;

  /// 更新滚动条占位配置并重新布局。
  set verticalScrollbarLeading(bool value) {
    if (_verticalScrollbarLeading == value) return;
    _verticalScrollbarLeading = value;
    _refreshViewportInsets();
    markNeedsLayout();
  }

  bool _horizontalScrollbarLeading = false;

  /// 滚动条边缘占位配置，由 Widget 结构更新。
  bool get horizontalScrollbarLeading => _horizontalScrollbarLeading;

  /// 更新滚动条占位配置并重新布局。
  set horizontalScrollbarLeading(bool value) {
    if (_horizontalScrollbarLeading == value) return;
    _horizontalScrollbarLeading = value;
    _refreshViewportInsets();
    markNeedsLayout();
  }

  bool _verticalInsetActive = false;
  bool _horizontalInsetActive = false;
  EdgeInsets _resolvedViewportInsets = EdgeInsets.zero;

  @override
  EdgeInsets get viewportLayoutInsets => _resolvedViewportInsets;

  void _refreshViewportInsets() {
    _resolvedViewportInsets = !_verticalInsetActive && !_horizontalInsetActive
        ? EdgeInsets.zero
        : EdgeInsets.fromLTRB(
            _verticalInsetActive && verticalScrollbarLeading ? verticalScrollbarInset : 0.0,
            _horizontalInsetActive && horizontalScrollbarLeading ? horizontalScrollbarInset : 0.0,
            _verticalInsetActive && !verticalScrollbarLeading ? verticalScrollbarInset : 0.0,
            _horizontalInsetActive && !horizontalScrollbarLeading ? horizontalScrollbarInset : 0.0,
          );
  }

  bool _updateScrollbarInsets(Size contentSize) {
    final vertical =
        verticalScrollbarInset > 0 &&
        axis == Axis.vertical &&
        contentSize.height > scrollportSize.height + precisionErrorTolerance;
    final horizontal =
        horizontalScrollbarInset > 0 &&
        (axis == Axis.horizontal || _dualAxis) &&
        contentSize.width > scrollportSize.width + precisionErrorTolerance;
    if (vertical == _verticalInsetActive && horizontal == _horizontalInsetActive) return false;
    if ((_verticalInsetActive && !vertical) || (_horizontalInsetActive && !horizontal)) {
      _verticalInsetActive = false;
      _horizontalInsetActive = false;
    } else {
      _verticalInsetActive = vertical;
      _horizontalInsetActive = horizontal;
    }
    _refreshViewportInsets();
    return true;
  }

  double? _scrollbarThumbDragFraction;

  // --- content 子节点实时自推 paint/semantic 边界的输入面（P1-B） ---

  /// 主轴视口 extent（未布局时 0）。
  double get mainViewportExtent => hasSize ? _mainExtent(scrollportSize) : 0.0;

  /// 主轴是否反向（reverse 列表 pixels→content 坐标翻转用）。
  bool get mainAxisReversed => _isAxisReversed;

  /// 双轴横向滚动 pixels（fixed 摘流的交叉轴视口锚定补偿用；content 被外层
  /// 按它做横向平移）。无横向 position 或未喂 pixels 时 0。
  ///
  /// 取外层横向平移实际使用的 raw 值，钉边成员与视口 transform 逐位同源。
  double get crossScrollPixels {
    final position = _horizontalPosition;
    if (position == null || !position.hasPixels) return 0.0;
    return _paintHorizontalScrollPixels();
  }

  /// 视口平移**实际使用**的主轴 raw 滚动像素（content 口径、未 clamp）。
  ///
  /// content 侧 fixed / sticky 钉位与可视边界必须读它，与外层平移逐位同源，
  /// 尤其不能另行量化，否则两条路径会产生亚像素相位差。
  double get paintedMainScrollPixels => _paintScrollPixels();

  /// 主轴直接成员可见窗口，由具体虚拟布局提供。
  @override
  int get debugVisibleStart => (this as VirtualContentVisibleWindow).visibleItemWindow().start;

  /// 主轴直接成员可见窗口的结束位置。
  @override
  int get debugVisibleEnd => (this as VirtualContentVisibleWindow).visibleItemWindow().end;

  /// 同帧布局并返回完整虚拟内容尺寸，成员直接归当前视口所有。
  @protected
  Size layoutVirtualContent(BoxConstraints constraints);

  /// thumb 被按住期间的轨道分数；null = 无拖拽。dragOptimize 下 content
  /// 可见窗口跟它走而非真实 position。
  double? get heldThumbDragFraction => _scrollbarThumbDragFraction;

  void _handleScrollbarDragChanged(VirtualScrollbarDragStatus status) {
    onScrollbarDragChanged?.call(status);
  }

  double _positionPixelsForVisualFraction(double visualFraction, double maxScrollExtent) {
    final fraction = visualFraction.clamp(0.0, 1.0).toDouble();
    if (maxScrollExtent <= precisionErrorTolerance) return 0.0;
    final contentPixels = fraction * maxScrollExtent;
    return _isAxisReversed ? maxScrollExtent - contentPixels : contentPixels;
  }

  /// 子约束只由父级约束与滚动轴决定：主轴放开，交叉轴保留父级上限。
  ///
  /// 双轴：两轴都放开，content 按 mounted items 的 maxCross 自行撑宽
  /// （横向不虚拟化的 mounted-only 语义）。
  ///
  /// shrinkWrap：不再用父级最大尺寸作为 viewport 目标尺寸，但交叉轴仍把
  /// 父级上界传给内容；viewport 最终尺寸由完整 content 实测值经父约束钳制。
  BoxConstraints _childConstraintsFor() {
    final contentLimits = constraints.deflate(viewportLayoutInsets);
    if (_dualAxis) {
      return BoxConstraints(minWidth: 0.0, maxWidth: double.infinity, minHeight: 0.0, maxHeight: double.infinity);
    }
    if (_axis == Axis.vertical) {
      final maxWidth = contentLimits.hasBoundedWidth
          ? contentLimits.maxWidth
          : _shrinkWrap
          ? double.infinity
          : scrollportSize.width;
      return BoxConstraints(minWidth: 0.0, maxWidth: maxWidth, minHeight: 0.0, maxHeight: double.infinity);
    }
    final maxHeight = contentLimits.hasBoundedHeight
        ? contentLimits.maxHeight
        : _shrinkWrap
        ? double.infinity
        : scrollportSize.height;
    return BoxConstraints(minWidth: 0.0, maxWidth: double.infinity, minHeight: 0.0, maxHeight: maxHeight);
  }

  double _layoutMetricsCrossExtent() {
    final contentLimits = constraints.deflate(viewportLayoutInsets);
    if (_dualAxis) return double.infinity;
    if (_axis == Axis.vertical) {
      return contentLimits.hasBoundedWidth
          ? math.max(contentLimits.maxWidth, 0.0)
          : _shrinkWrap
          ? double.infinity
          : scrollportSize.width;
    }
    return contentLimits.hasBoundedHeight
        ? math.max(contentLimits.maxHeight, 0.0)
        : _shrinkWrap
        ? double.infinity
        : scrollportSize.height;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (constraints.isTight) return constraints.smallest;
    if (_shrinkWrap) {
      // 内容挂载、网格列数与滚动条占位在真实布局内收敛，dry 查询不能触发这些副作用。
      assert(debugCannotComputeDryLayout(reason: 'shrinkWrap 的内容尺寸依赖布局回调中的完整子项挂载与实测，无法在不修改布局状态时预估。请提供紧约束，或让父级执行正常布局。'));
      return Size.zero;
    }
    return _viewportSizeFor(constraints);
  }

  Size _viewportSizeFor(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : _unboundedAxisFallbackWidth(constraints);
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : _unboundedAxisFallbackHeight(constraints);
    return constraints.constrain(Size(width.isFinite ? width : 0.0, height.isFinite ? height : 0.0));
  }

  /// 无界宽轴兜底顺序：**爬链参照 → 正有限 minWidth → 0**。虚拟滚动作为
  /// 内层必须能活在双轴外层里；参照来自外层已登记的 content box 尺寸。
  double _unboundedAxisFallbackWidth(BoxConstraints constraints) {
    final reference = LayoutReferenceBox.ancestorReferenceWidth(this);
    if (reference != null) return reference;
    if (constraints.minWidth > 0.0 && constraints.minWidth.isFinite) return constraints.minWidth;
    return 0.0;
  }

  double _unboundedAxisFallbackHeight(BoxConstraints constraints) {
    final reference = LayoutReferenceBox.ancestorReferenceHeight(this);
    if (reference != null) return reference;
    if (constraints.minHeight > 0.0 && constraints.minHeight.isFinite) return constraints.minHeight;
    return 0.0;
  }

  @override
  BoxConstraints childConstraintsForLayout() => _childConstraintsFor();

  @override
  void performLayout() {
    markHitBoundsDirty();
    final shrinkWrap = _shrinkWrap;
    // 默认模式的滚动壳尺寸不受子元素影响，只取父级给出的最大宽高；任何无界
    // 最大尺寸都无法定壳，必须改用 shrinkWrap 或由外层提供明确尺寸。
    assert(_debugCheckHasBoundedConstraints(shrinkWrap));

    if (kDebugMode || const bool.fromEnvironment('EL_UI_SCROLL_DEBUG_COUNTERS')) _debugLayoutCount++;
    var cycle = 0;
    while (!_performLayoutPass(shrinkWrap)) {
      cycle++;
      if (cycle < _maxLayoutCycles) continue;
      assert(() {
        throw FlutterError(
          'RenderVirtualScrollView 在同一帧内连续修正了 $cycle 次滚动位置，布局仍未收敛。\n'
          '这通常表示视口尺寸、内容 extent 与滚动锚点之间存在循环修正。',
        );
      }());
      return;
    }
  }

  bool _debugCheckHasBoundedConstraints(bool shrinkWrap) {
    if (shrinkWrap) return true;
    final fallbackWidth = constraints.hasBoundedWidth ? constraints.maxWidth : _unboundedAxisFallbackWidth(constraints);
    final fallbackHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : _unboundedAxisFallbackHeight(constraints);
    final hasResolvedWidth = fallbackWidth.isFinite && fallbackWidth > 0.0;
    final hasResolvedHeight = fallbackHeight.isFinite && fallbackHeight > 0.0;
    if (hasResolvedWidth && hasResolvedHeight) return true;

    final owner = _debugScrollViewOwner();
    // RenderObject 默认归属私有 _ScrollViewport，会让 Flutter 停在库内部。
    // 仅在真正报错时改指公开 ElScrollView，保留业务文件的创建位置。
    if (owner != null) debugCreator = DebugCreator(owner);
    final unboundedAxes = <String>[if (!hasResolvedWidth) 'width', if (!hasResolvedHeight) 'height'];
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('ElScrollView(shrinkWrap: false) needs bounded width and height from its parent.'),
      ErrorDescription('The viewport received unbounded ${unboundedAxes.join(' and ')}.'),
      DiagnosticsProperty<BoxConstraints>(
        'The received constraints were',
        constraints,
        style: DiagnosticsTreeStyle.errorProperty,
      ),
      if (owner != null) owner.describeWidget('The public ElScrollView was'),
      if (owner != null) owner.describeOwnershipChain('The ownership chain for this ElScrollView is'),
      describeForError('The affected RenderVirtualScrollView was', style: DiagnosticsTreeStyle.errorProperty),
      ErrorHint(
        'Wrap the ElScrollView with Expanded or Flexible, provide explicit width and height, '
        'or set shrinkWrap: true.',
      ),
    ]);
  }

  Element? _debugScrollViewOwner() {
    final creator = debugCreator;
    if (creator is! DebugCreator) return null;
    Element? owner;
    creator.element.visitAncestorElements((element) {
      if (element.widget is! ElScrollView) return true;
      owner = element;
      return false;
    });
    return owner;
  }

  bool _performLayoutPass(bool shrinkWrap) {
    if (shrinkWrap) {
      // 完整子内容布局：size 暂时保留交叉轴度量基准，防止全量虚拟段的
      // 首帧尺寸回报失去布局参照；content 沿滚动主轴放开，最终 size
      // 取实测内容并由父约束钳制。
      final fallbackSize = _viewportSizeFor(constraints);
      size = constraints.constrain(
        _axis == Axis.vertical ? Size(fallbackSize.width, 0.0) : Size(0.0, fallbackSize.height),
      );
    }
    // size 落定后即登记参照，排 children 之前完成（两轴 content box 尺寸）。
    // 单轴视口宽度变化
    // 会带动 childConstraints 交叉轴上界改变，Flutter 硬约束不等自然重排，
    // 本处不额外唤醒；只有"约束不变而参照变"才走唤醒。
    // 完整子内容布局模式：参照推迟到内容回填后（排完全部 child 才可知）。
    final referenceChanged = shrinkWrap
        ? false
        : setLayoutReference(
            math.max(scrollportSize.width - _padding.horizontal, 0.0),
            math.max(scrollportSize.height - _padding.vertical, 0.0),
          );
    // 度量回调在排 child 之前跑：窗口内新挂的行才能进入本帧 child.layout。
    // 收缩模式交叉轴按子约束上报；无界时上报 ∞，有界 shrinkWrap 保留父级上限。
    // 完整子内容布局模式：窗口恒全量（State 侧不看视口尺寸），首帧先以 0 喂一次让
    // reconcile 完成全量挂载，回填后以最终值再喂一次（锚点/滚动条读数）。
    // 回调里 State 会对 content 做挂载/卸载（reconcile），必须包
    // invokeLayoutCallback 才能在 layout 期间合法 mutate child 树。
    final onLayoutMetrics = this.onLayoutMetrics;
    if (onLayoutMetrics != null) {
      invokeLayoutCallback<BoxConstraints>((_) {
        final crossExtent = _layoutMetricsCrossExtent();
        onLayoutMetrics(shrinkWrap ? 0.0 : _mainExtent(scrollportSize), crossExtent);
      });
    }
    final childConstraints = childConstraintsForLayout();
    if (referenceChanged && _lastChildConstraints == childConstraints) {
      markSubtreeNeedsLayoutForReference();
    }
    _lastChildConstraints = childConstraints;
    final contentSize = layoutVirtualContent(childConstraints);
    setVirtualContentSize(contentSize);
    if (shrinkWrap) {
      // 内容尺寸回填：content 已全量布局，两轴都按内容 + padding 计算，
      // 再 clamp 到父约束——内容不足时收缩，内容超出时截断并滚动。
      size = constraints.constrain(
        Size(
          contentSize.width + _padding.horizontal + viewportLayoutInsets.horizontal,
          contentSize.height + _padding.vertical + viewportLayoutInsets.vertical,
        ),
      );
      // 参照与度量回调补喂（主轴参照 = 回填后的 content box 口径）。
      setLayoutReference(
        math.max(scrollportSize.width - _padding.horizontal, 0.0),
        math.max(scrollportSize.height - _padding.vertical, 0.0),
      );
      if (onLayoutMetrics != null) {
        invokeLayoutCallback<BoxConstraints>((_) {
          final crossExtent = _layoutMetricsCrossExtent();
          onLayoutMetrics(_mainExtent(scrollportSize), crossExtent);
        });
      }
    }
    if (_updateScrollbarInsets(contentSize)) return false;
    final accepted = completeMainAxisLayout(
      beforeApplyMainDimensions: (maxScrollExtent) {
        // thumb 被按住时用轨道分数反解目标像素：extent 在本帧刚收敛，必须
        // 在 applyContentDimensions 之前修正，否则拖拽期会回弹一帧。
        final dragFraction = _scrollbarThumbDragFraction;
        if (dragFraction == null || !_position.hasPixels) return;
        final dragTarget = _positionPixelsForVisualFraction(dragFraction, maxScrollExtent).clamp(0.0, maxScrollExtent);
        if ((dragTarget - _position.pixels).abs() > precisionErrorTolerance) {
          recordLayoutPositionCorrection(axis, dragTarget - _position.pixels);
          _position.correctBy(dragTarget - _position.pixels);
          _invalidateScrollPaintCache();
        }
      },
    );
    if (accepted) {
      if (needsChromeReconcile?.call() ?? false) {
        invokeLayoutCallback<BoxConstraints>((_) => onLayoutChrome?.call());
      }
      layoutChromeChildren();
    }
    return accepted;
  }
}
