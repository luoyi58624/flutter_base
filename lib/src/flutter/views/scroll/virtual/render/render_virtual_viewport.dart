// 直接滚动视口的业务布局、层序、命中与选区实现。
// ignore_for_file: prefer_initializing_formals

part of '../virtual_pipeline.dart';

class _PositionedPaintContext extends PaintingContext {
  _PositionedPaintContext(super.layer, super.bounds);

  void finish() => stopRecordingIfNeeded();
}

class _PositionedPaintRun {
  final LayerHandle<OffsetLayer> layer = LayerHandle<OffsetLayer>();
  RenderBox? last;
  List<RenderBox>? ordering;
  int revision = -1;
  int generation = -1;
  int endIndex = -1;
  int count = 0;
  int lastPaintPass = -1;
  final List<RenderBox> members = [];
}

class _ScrollViewportParentData extends ScrollChildParentData {
  /// 滚动条内部成员不进入业务索引、选区和 extent 模型。
  bool isChrome = false;

  /// 定位字段只在布局时解算，绘制与命中读取已完成的布局角色。
  bool isViewportPositioned = false;

  /// 内容遍历在尾部内部滚动条前结束，默认层序无需额外排序。
  RenderBox? get nextContentSibling {
    final next = nextSibling;
    return next != null && (next.parentData! as _ScrollViewportParentData).isChrome ? null : next;
  }

  /// 当前业务 child 在扁平 item 空间中的 index。
  int index = 0;
  Object? selectionIdentityId;
  double? lastReportedExtent;

  /// item client 登记的吸附偏移；null = 不参与 sticky。
  /// 由 item client 登记时同步，绘制阶段不再向上查找业务 Widget。
  double? stickyOffset;
  bool isViewportHeader = false;
  double viewportHeaderOffset = 0;
}

class _RenderVirtualViewport extends RenderVirtualScrollView
    implements SelectionPaintOrderChildren, SelectionItemVisibility, VirtualContentVisibleWindow {
  _RenderVirtualViewport({
    required _ScrollViewport viewport,
    required Axis axis,
    required bool dualAxis,
    required double totalExtent,
    required EdgeInsets padding,
    required double gap,
    required CrossAxisAlignment? crossAxisAlignment,
    required double minimumCrossAxisExtent,
    required int firstIndex,
    required int lastIndex,
    required bool dragOptimizeEnabled,
    required this.pinToEnd,
    required this.preserveAnchor,
    required List<Widget> children,
    required SegmentPlan sectionPlan,
    required int measurementGeneration,
    required bool reportMeasuredExtentsWhenUnchanged,
    required SegmentExtentIndex extentIndex,
    required void Function(Map<int, double> extents) onItemExtentsChanged,
    required void Function(int?, {required bool duringLayout}) onMeasurementsChanged,
  }) : _viewportConfiguration = viewport,
       _axis = axis,
       _dualAxis = dualAxis,
       _totalExtent = totalExtent,
       _padding = padding,
       _gap = gap,
       _crossAxisAlignment = crossAxisAlignment,
       _minimumCrossAxisExtent = minimumCrossAxisExtent,
       _firstIndex = firstIndex,
       _lastIndex = lastIndex,
       _dragOptimizeEnabled = dragOptimizeEnabled,
       _children = children,
       _sectionPlan = sectionPlan,
       _measurementGeneration = measurementGeneration,
       _reportMeasuredExtentsWhenUnchanged = reportMeasuredExtentsWhenUnchanged,
       _extentIndex = extentIndex,
       _onItemExtentsChanged = onItemExtentsChanged,
       _onMeasurementsChanged = onMeasurementsChanged,
       super(
         position: viewport.position,
         horizontalPosition: viewport.horizontalPosition,
         horizontalAxisDirection: viewport.horizontalAxisDirection,
         axis: viewport.axis,
         axisDirection: viewport.axisDirection,
         shrinkWrap: viewport.shrinkWrap,
         physics: viewport.physics,
         velocityTrackerBuilder: viewport.velocityTrackerBuilder,
         multitouchDragStrategy: viewport.multitouchDragStrategy,
         devicePixelRatio: viewport.devicePixelRatio,
         dragDevices: viewport.dragDevices,
         pointerAxisModifiers: viewport.pointerAxisModifiers,
         mouseWheelHorizontalModifiers: viewport.mouseWheelHorizontalModifiers,
         gestureSettings: viewport.gestureSettings,
         clipBehavior: viewport.clipBehavior,
         excludeSemantics: viewport.excludeSemantics,
         semanticsRole: viewport.semanticsRole,
         ignorePointer: viewport.ignorePointer,
         canDrag: viewport.canDrag,
         dragStartDistance: viewport.dragStartDistance,
         onScrollbarDragChanged: viewport.onScrollbarDragChanged,
         event: viewport.event,
         deltaInterceptor: viewport.deltaInterceptor,
         horizontalDeltaInterceptor: viewport.horizontalDeltaInterceptor,
         onScrollInputActivityChanged: viewport.onScrollInputActivityChanged,
         smoothScroll: viewport.smoothScroll,
       );

  _ScrollViewport _viewportConfiguration;
  Alignment _positionedAlignment = Alignment.topLeft;

  void _updatePositionedDirection(TextDirection direction) {
    final next = AlignmentDirectional.topStart.resolve(direction);
    if (_positionedAlignment == next) return;
    _positionedAlignment = next;
    markNeedsLayout();
  }

  Size _laidOutContentSize = Size.zero;
  bool _hasContentSize = false;
  late BoxConstraints contentConstraints;

  Axis get contentAxis => _axis;
  Axis _axis;

  /// 选区空白取点树下降的主轴声明：item 沿滚动轴堆叠（双轴模式水平位移只是
  /// 交叉轴平移，不改变堆叠方向）。
  set contentAxis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    _resetPendingExtentReports();
    _clearReportedExtents();
    _selfMarkNeedsLayout();
  }

  /// 双轴模式：items 收无界交叉轴约束、交叉轴尺寸取 mounted items 的 maxCross
  /// （横向不虚拟化——mounted 窗口变化时该值动态变化，属预期语义）。
  bool get dualAxis => _dualAxis;
  bool _dualAxis;

  set dualAxis(bool value) {
    if (_dualAxis == value) return;
    _dualAxis = value;
    _selfMarkNeedsLayout();
  }

  double get totalExtent => _totalExtent;
  double _totalExtent;

  set totalExtent(double value) {
    if ((_totalExtent - value).abs() <= precisionErrorTolerance) return;
    _totalExtent = value;
    _selfMarkNeedsLayout();
  }

  EdgeInsets get contentPadding => _padding;
  EdgeInsets _padding;

  set contentPadding(EdgeInsets value) {
    if (_padding == value) return;
    _padding = value;
    _selfMarkNeedsLayout();
  }

  double get gap => _gap;
  double _gap;

  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    _selfMarkNeedsLayout();
  }

  /// 成员交叉轴对齐（容器级）。null = 沿轴向既有行为（vertical tight 拉满 /
  /// horizontal loose 自然高）；显式 stretch = tight，start/center/end 给
  /// loose 按固有尺寸摆位；约束变化时由 Flutter 重新测量自然尺寸。
  CrossAxisAlignment? _crossAxisAlignment;

  double _minimumCrossAxisExtent;

  set minimumCrossAxisExtent(double value) {
    final next = math.max(value, 0.0);
    if ((_minimumCrossAxisExtent - next).abs() <= precisionErrorTolerance) return;
    _minimumCrossAxisExtent = next;
    _selfMarkNeedsLayout();
  }

  set crossAxisAlignment(CrossAxisAlignment? value) {
    if (_crossAxisAlignment == value) return;
    _crossAxisAlignment = value;
    _selfMarkNeedsLayout();
  }

  /// 唯一布局计划；新计划实例触发布局，列表与网格统一按行解析。
  SegmentPlan get sectionPlan => _sectionPlan;
  SegmentPlan _sectionPlan;

  set sectionPlan(SegmentPlan value) {
    if (identical(_sectionPlan, value)) return;
    _sectionPlan = value;
    _selfMarkNeedsLayout();
  }

  double get _mainLeadingPadding => _axis == Axis.vertical ? _padding.top : _padding.left;

  double get _mainTrailingPadding => _axis == Axis.vertical ? _padding.bottom : _padding.right;

  double get _crossLeadingPadding => _axis == Axis.vertical ? _padding.left : _padding.top;

  double get _crossPaddingTotal => _axis == Axis.vertical ? _padding.horizontal : _padding.vertical;

  int get firstIndex => _firstIndex;
  int _firstIndex;

  set firstIndex(int value) {
    if (_firstIndex == value) return;
    _firstIndex = value;
    _markWindowLayout();
  }

  int get lastIndex => _lastIndex;
  int _lastIndex;

  set lastIndex(int value) {
    if (_lastIndex == value) return;
    _lastIndex = value;
    _markWindowLayout();
  }

  /// 拖拽快路径开关：thumb 拖拽期可见窗口跟 thumb 分数（true）还是真实
  /// position（false）。
  bool get dragOptimizeEnabled => _dragOptimizeEnabled;
  bool _dragOptimizeEnabled;

  set dragOptimizeEnabled(bool value) {
    if (_dragOptimizeEnabled == value) return;
    _dragOptimizeEnabled = value;
    markNeedsPaint();
  }

  /// 贴末端跟随开关（[ElScrollView.pinToEnd] 经 snapshot 透传）：
  /// [_applyPendingMeasurementsInLayout] 据此决定贴 max 边时钉住新 max
  /// 还是走锚点保位。纯行为标志，切换不触发重排/重绘。
  bool pinToEnd;

  /// 真实内容变化的锚点补偿开关，默认保留像素位置。
  bool preserveAnchor;

  /// P1-B：paint/semantic 边界是 (position, thumb 分数, viewportExtent,
  /// totalExtent) 的纯函数，由本节点在使用点实时自推——State 侧不再按 tick
  /// 推送（旧链路：State 监听 → recompute → controller → element → render
  /// setter 五跳）。数学与 State `_recomputeVisibleRangeWithDetail` 的
  /// 边界口径逐位一致：可见窗口在 dragOptimize thumb 拖拽期跟 thumb 分数，
  /// 语义窗口恒跟真实 position（读屏应看到实际滚到的行）。
  ({double visibleStart, double visibleEnd, double semanticStart, double semanticEnd}) _liveContentBounds() {
    final viewportExtent = mainViewportExtent;
    final maxOffset = math.max(_totalExtent - viewportExtent, 0.0);
    // 与视口平移读取同一份 raw content 像素，fixed/sticky 不得另行量化；
    // clamp 只负责保留既有 overscroll 语义。
    final realContent = paintedMainScrollPixels.clamp(0.0, maxOffset).toDouble();
    final dragFraction = heldThumbDragFraction;
    final effective = dragFraction != null && _dragOptimizeEnabled
        ? VirtualScrollGeometry.contentOffsetForFraction(dragFraction, maxOffset)
        : realContent;
    final semanticOffset = dragFraction != null ? realContent : effective;
    return (
      visibleStart: effective.clamp(0.0, _totalExtent).toDouble(),
      visibleEnd: math.min(_totalExtent, effective + viewportExtent),
      semanticStart: semanticOffset,
      semanticEnd: math.min(_totalExtent, semanticOffset + viewportExtent),
    );
  }

  /// 可见 item 窗口 `[start, end)`：起点 = 首个「行尾 > 可视起点」的行，终点
  /// = 首个「行首 >= 可视终点」的行——同一份模型前缀和两端二分（落位数组
  /// 口径），pixels 恰落行边界与浮点噪声行高下都与实际落位一致，不做
  /// stride 解析式。gap/padding 经 plan 折算进纯行高空间后查询。
  @override
  ({int start, int end}) visibleItemWindow() {
    final plan = _sectionPlan;
    final itemCount = plan.totalItemCount;
    if (itemCount == 0 || !_hasContentSize) return const (start: 0, end: 0);
    final bounds = _liveContentBounds();
    final startContent = bounds.visibleStart - _mainLeadingPadding;
    final endContent = bounds.visibleEnd - _mainLeadingPadding;
    final rowCount = plan.totalRowCount;
    final startRow = _extentIndex.rowAtContentOffset(startContent).clamp(0, rowCount);
    final endRow = _extentIndex.rowAtContentOffset(endContent, startAtOrAfter: true).clamp(startRow, rowCount);
    return (
      start: startRow >= rowCount ? itemCount : plan.firstItemOfRow(startRow),
      end: endRow >= rowCount ? itemCount : plan.firstItemOfRow(endRow),
    );
  }

  /// 可见边界越过实际排出的 mounted 末端 → 排 underflow 补挂载。paint 期
  /// 逐帧核对（亚行级滚动只动边界不动窗口时，模型高估导致的露白由此路径
  /// 兜住；窗口变化路径由 performLayout 末尾的同名检查覆盖）。
  void _checkVisibleUnderflowForBounds(double visibleEnd) {
    if (!_layoutMetricsValid || visibleEnd > _visibleLayoutMountedEnd + precisionErrorTolerance) {
      _scheduleUnderflowReportFromCurrentLayout(visibleEnd);
    }
  }

  /// 白盒测试钩子：以给定可见末端跑一次 paint 路径的 underflow 检查。
  /// 生产路径恒在 paint/layout 帧内触发（post-frame 回调随帧尾冲出）；测试
  /// 体在 idle 相位调用时无脏帧，补一次帧调度让 pump 能推进报告。
  @visibleForTesting
  void debugCheckVisibleUnderflow(double visibleContentEnd) {
    _checkVisibleUnderflowForBounds(visibleContentEnd);
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  List<Widget> get sourceChildren => _children;
  List<Widget> _children;

  set sourceChildren(List<Widget> value) {
    if (identical(_children, value)) return;
    _children = value;
  }

  int get measurementGeneration => _measurementGeneration;
  int _measurementGeneration;

  set measurementGeneration(int value) {
    if (_measurementGeneration == value) return;
    _measurementGeneration = value;
    _resetPendingExtentReports();
    _clearReportedExtents();
    _selfMarkNeedsLayout();
  }

  bool get reportMeasuredExtentsWhenUnchanged => _reportMeasuredExtentsWhenUnchanged;
  bool _reportMeasuredExtentsWhenUnchanged;

  set reportMeasuredExtentsWhenUnchanged(bool value) {
    if (_reportMeasuredExtentsWhenUnchanged == value) return;
    _reportMeasuredExtentsWhenUnchanged = value;
    _clearReportedExtents();
    _selfMarkNeedsLayout();
  }

  SegmentExtentIndex get extentIndex => _extentIndex;
  SegmentExtentIndex _extentIndex;

  set extentIndex(SegmentExtentIndex value) {
    if (identical(_extentIndex, value)) return;
    _extentIndex = value;
    _resetPendingExtentReports();
    _clearReportedExtents();
    _selfMarkNeedsLayout();
  }

  void Function(Map<int, double> extents) _onItemExtentsChanged;

  set onItemExtentsChanged(void Function(Map<int, double> extents) value) {
    _onItemExtentsChanged = value;
  }

  void Function(int?, {required bool duringLayout}) _onMeasurementsChanged;

  set onMeasurementsChanged(void Function(int?, {required bool duringLayout}) value) {
    _onMeasurementsChanged = value;
  }

  final Map<int, double> _pendingExtentReports = <int, double>{};
  bool _extentReportScheduled = false;
  int _extentReportGeneration = 0;
  int? _pendingUnderflowLastIndex;
  SelectionGeometryObserver? _selectionGeometryObserver;
  bool _layoutMetricsValid = false;
  double _visibleLayoutMountedEnd = double.negativeInfinity;
  double _visibleLayoutExtentSum = 0.0;
  int _visibleLayoutChildCount = 0;

  /// 本帧 mounted 集里是否存在 sticky child（layout 顺手累计）。false 时
  /// [_resolveSticky] 零成本早退——无 sticky 的列表不再为 paint/hitTest/
  /// applyPaintTransform 各付一次 O(mounted) 走查。
  bool _hasStickyChild = false;
  bool _requiresItemPaintOffsets = false;

  /// [_resolveSticky] 的帧内缓存：结果只依赖 layout 产物（offset/_laidOutContentSize/
  /// stickyOffset）与 _visibleContentStart，两者变化点（markNeedsLayout /
  /// paint-only 可见边界更新）都会失效缓存。applyPaintTransform 逐 child
  /// 调用时不再退化为 O(mounted²)。
  ({RenderBox child, double clampedMain})? _stickyResolutionCache;
  bool _stickyResolutionCacheValid = false;
  double _stickyResolutionCacheStart = double.nan;

  // --- P2 帧内测量收敛：本 pass 待就地写入 Fenwick 的 (index, extent) 对 ---
  final List<int> _pendingInLayoutApplyIndices = <int>[];
  final List<double> _pendingInLayoutApplyExtents = <double>[];
  int _debugInLayoutMeasurementApplyCount = 0;
  int _debugInLayoutCorrectionCount = 0;

  @visibleForTesting
  int get debugInLayoutMeasurementApplyCount => _debugInLayoutMeasurementApplyCount;

  @visibleForTesting
  int get debugInLayoutCorrectionCount => _debugInLayoutCorrectionCount;

  /// P2 帧内收敛资格。三个跳过条件，任一命中即整 pass 回退 post-frame 报告
  /// 旧路：①环境漂移验证窗口（[_reportMeasuredExtentsWhenUnchanged]）需要
  /// 原始报告与旧存量对比，预写会吞掉重置判据；但全静态或 shrinkWrap 本帧会全量
  /// 实测，可直接覆盖完整模型并由后续报告确认新环境，无需先弃度量；②thumb
  /// 拖拽期走 fraction 管线（含边缘 rebase）；③越界期修正一律弃权（对齐
  /// State 侧越界弃权语义，bouncing 停靠/刷新回位期间不动 pixels）。首帧（position 度量
  /// 未建立）**不回退**：走纯灌注分支（见 [_applyPendingMeasurementsInLayout]），
  /// 外壳首个 applyContentDimensions 即拿到实测精确 max——全常驻场景
  /// （散 child 列表）首帧 maxScrollExtent/contentSize 就是终值。
  bool get _canApplyMeasurementsInLayout {
    if (_reportMeasuredExtentsWhenUnchanged && !_sectionPlan.isAllStatic && !shrinkWrap) return false;
    if (heldThumbDragFraction != null) return false;
    final position = this.position;
    if (position.hasPixels && position.hasContentDimensions) {
      final pixels = position.pixels;
      if (pixels < position.minScrollExtent - precisionErrorTolerance ||
          pixels > position.maxScrollExtent + precisionErrorTolerance) {
        return false;
      }
    }
    return true;
  }

  /// P2 帧内收敛：把本 pass 实测行高就地写入共享 Fenwick，并按锚点行的模型
  /// 位移同帧 [ScrollPosition.correctBy] 补偿像素。旧路径是 2-3 帧管线
  /// （post-frame 报告 → State 锚点走查 → 强制快照+再 layout → 下帧修正），
  /// fling 穿越未测量区时每帧全价；本 pass 的绘制位置不变（run 定位本就用
  /// 实测值），修正只让下一帧的模型定位与本帧视觉对齐，无需二次 layout。
  /// 锚点判据与 State 旧路径一致：leading edge 处首个本批高度未变的行，
  /// 变高行的尺寸增量被吸收到视口外（进入侧）。correctBy 置 correction 位，
  /// 进行中的 ballistic 在 applyNewDimensions 里按修正后 pixels 重建弹道。
  bool _applyPendingMeasurementsInLayout() {
    final indices = _pendingInLayoutApplyIndices;
    if (indices.isEmpty) return false;
    final extents = _pendingInLayoutApplyExtents;
    final position = this.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      // 首帧纯灌注（散 child 常驻行或 shrinkWrap）：全量布局使实测首帧就齐——
      // 写 Fenwick、总长同步，锚点/钉边/correctBy 免除（无既有视觉可保，
      // pixels 将由首个 applyContentDimensions 按新 max clamp，PageStorage
      // 恢复值不受损）。首屏逐项填窗同样立即写入；其他窗口化段仍沿用原收敛路径。
      // 零测量快路径与窗口化收敛维持原路。返回 true 触发同帧重定位与
      // _laidOutContentSize 重设，全常驻场景首帧 maxScrollExtent 即终值。
      final plan = _sectionPlan;
      final extentTotalBefore = _extentIndex.totalExtent;
      for (var i = 0; i < indices.length; i++) {
        final row = indices[i];
        if (!shrinkWrap &&
            !_viewportConfiguration.controller.snapshot.keepAliveOwner._measuringInitialWindow &&
            plan.segments[plan.segmentOfItem(plan.firstItemOfRow(row))] is! StaticSegment) {
          continue;
        }
        _extentIndex.updateMeasuredExtent(row, extents[i]);
      }
      indices.clear();
      extents.clear();
      final totalDelta = _extentIndex.totalExtent - extentTotalBefore;
      if (totalDelta.abs() <= precisionErrorTolerance) return false;
      if (_scrollDebugCountersEnabled) _debugInLayoutMeasurementApplyCount++;
      _totalExtent += totalDelta;
      return true;
    }
    if (_scrollDebugCountersEnabled) _debugInLayoutMeasurementApplyCount++;
    final viewportExtent = mainViewportExtent;
    final oldMax = math.max(_totalExtent - viewportExtent, 0.0);
    final pixels = position.pixels.clamp(0.0, oldMax).toDouble();
    final realContent = VirtualScrollGeometry.contentFromPixels(pixels, oldMax, reversed: mainAxisReversed);
    // 边缘钉靠优先（判据与 State 同走 geometry 模块）：pixels 贴 min 边保持
    // 0；贴 max 边（trailing 贴底）分两类——纯首测/估计收敛是估算 artifact，
    // 恒钉（jumpTo(max) 收敛到真实底部）；批次含**已实测行**的尺寸变化
    // （展开/流式长高等真实内容增长）时跟随是显式 opt-in（[pinToEnd]），
    // 关闭时只补偿虚拟估高，真实内容变化按 preserveAnchor 决定是否保位。
    final pinnedEdge = VirtualScrollGeometry.pinnedEdge(pixels, oldMax);
    final pinnedToMin = pinnedEdge == VirtualScrollEdge.min;
    var pinnedToMax = pinnedEdge == VirtualScrollEdge.max;
    if (pinnedToMax && !pinToEnd && !_reportMeasuredExtentsWhenUnchanged) {
      for (var i = 0; i < indices.length; i++) {
        final row = indices[i];
        if (!_viewportConfiguration.controller.snapshot.keepAliveOwner._rowUsesEstimatedExtent(row) &&
            (_extentIndex.extentOf(row) - extents[i]).abs() > precisionErrorTolerance) {
          pinnedToMax = false;
          break;
        }
      }
    }
    final reversed = mainAxisReversed;
    final needsAnchoring = !pinnedToMin && !pinnedToMax;
    Set<int>? changed;
    var hasMeasuredMutation = false;
    if (needsAnchoring && !reversed) {
      for (var i = 0; i < indices.length; i++) {
        if ((_extentIndex.extentOf(indices[i]) - extents[i]).abs() > precisionErrorTolerance) {
          if (preserveAnchor ||
              _reportMeasuredExtentsWhenUnchanged ||
              _viewportConfiguration.controller.snapshot.keepAliveOwner._rowUsesEstimatedExtent(indices[i])) {
            (changed ??= <int>{}).add(indices[i]);
          }
          hasMeasuredMutation = hasMeasuredMutation || _extentIndex.isMeasured(indices[i]);
        }
      }
    }
    final anchor = needsAnchoring && !reversed
        ? anchorAtContentOffset(
            realContent,
            within: viewportExtent,
            skip: changed == null ? null : (index) => changed!.contains(_sectionPlan.rowOfItem(index)),
            useModelOffsets: hasMeasuredMutation,
          )
        : null;
    // 反向轴不走锚点行：pixels 锚定在 max 端，视觉稳定性 = 「窗口末端 →
    // 内容末端」的距离不变。只有**窗口末端之后**（内容坐标更大侧，即退出侧
    // 已看过的行）的行高变化会改变这段距离需要补偿 pixels；窗口内与窗口前
    // （进入侧）的变化天然被吸收到进入侧，pixels 不动。窗口内全是新测行时
    // 锚点行方案无解（mounted 集里没有"老"行可钉），按旧模型位置逐行归类
    // 直算是唯一稳定口径。
    var reversedPixelsDelta = 0.0;
    if (needsAnchoring && reversed) {
      final windowEnd = realContent + viewportExtent;
      for (var i = 0; i < indices.length; i++) {
        final row = indices[i];
        final firstItem = _sectionPlan.firstItemOfRow(row);
        if (_modelMainStartOfIndex(firstItem) >= windowEnd - precisionErrorTolerance &&
            _viewportConfiguration.controller.snapshot.keepAliveOwner._shouldAnchorMeasurement(
              row,
              environmentChanged: _reportMeasuredExtentsWhenUnchanged,
            )) {
          reversedPixelsDelta += extents[i] - _extentIndex.extentOf(row);
        }
      }
    }
    final extentTotalBefore = _extentIndex.totalExtent;
    var unanchoredDelta = 0.0;
    for (var i = 0; i < indices.length; i++) {
      if (anchor != null &&
          _sectionPlan.firstItemOfRow(indices[i]) < anchor.index &&
          !_viewportConfiguration.controller.snapshot.keepAliveOwner._shouldAnchorMeasurement(
            indices[i],
            environmentChanged: _reportMeasuredExtentsWhenUnchanged,
          )) {
        unanchoredDelta += extents[i] - _extentIndex.extentOf(indices[i]);
      }
      _extentIndex.updateMeasuredExtent(indices[i], extents[i]);
    }
    indices.clear();
    extents.clear();
    final totalDelta = _extentIndex.totalExtent - extentTotalBefore;
    // 布局空间总长同步（gap 数不随测量变化），供本帧 _laidOutContentSize 重设与
    // _liveContentBounds 立即取新值；下一次快照推送写入同值。
    _totalExtent += totalDelta;
    if (pinnedToMin) return true;
    if (pinnedToMax) {
      final delta = math.max(_totalExtent - viewportExtent, 0.0) - position.pixels;
      if (delta.abs() > precisionErrorTolerance) {
        if (_scrollDebugCountersEnabled) _debugInLayoutCorrectionCount++;
        recordLayoutPositionCorrection(contentAxis, delta);
        position.correctBy(delta);
      }
      return true;
    }
    final double pixelsDelta;
    if (reversed) {
      pixelsDelta = reversedPixelsDelta;
    } else if (anchor != null) {
      final paintedStart = realContent + anchor.delta;
      final newModelStart = _modelMainStartOfIndex(anchor.index);
      pixelsDelta = newModelStart - paintedStart - unanchoredDelta;
    } else {
      return true;
    }
    if (pixelsDelta.abs() <= precisionErrorTolerance) return true;
    final newMax = math.max(_totalExtent - viewportExtent, 0.0);
    final appliedDelta = (position.pixels + pixelsDelta).clamp(0.0, newMax).toDouble() - position.pixels;
    if (appliedDelta.abs() <= precisionErrorTolerance) return true;
    if (_scrollDebugCountersEnabled) _debugInLayoutCorrectionCount++;
    recordLayoutPositionCorrection(contentAxis, appliedDelta);
    position.correctBy(appliedDelta);
    return true;
  }

  /// 双轴：本帧 mounted items 的最大交叉轴 extent（layout 循环累计）。
  /// mounted 窗口变化即重排（markNeedsLayout 由 firstIndex/lastIndex setter
  /// 触发），值随窗口动态漂移是 mounted-only 撑的预期语义。
  double _mountedMaxCross = 0.0;

  bool get _usesNaturalCrossExtent => _dualAxis || shrinkWrap;

  int _debugLayoutCount = 0;
  int _debugLastPaintedChildCount = 0;
  int _debugLastHitTestChildCount = 0;
  int _debugVisibleLayoutMetricsReadCount = 0;

  @visibleForTesting
  @override
  int get debugLayoutCount => _debugLayoutCount;

  @visibleForTesting
  int get debugLastPaintedChildCount => _debugLastPaintedChildCount;

  @visibleForTesting
  int get debugLastHitTestChildCount => _debugLastHitTestChildCount;

  @visibleForTesting
  double get debugVisibleContentStart => _liveContentBounds().visibleStart;

  @visibleForTesting
  double get debugVisibleContentEnd => _liveContentBounds().visibleEnd;

  @visibleForTesting
  double get debugVisibleMountedEnd {
    if (!_layoutMetricsValid) return double.nan;
    if (_scrollDebugCountersEnabled) _debugVisibleLayoutMetricsReadCount++;
    return _visibleLayoutMountedEnd;
  }

  @visibleForTesting
  int get debugVisibleLayoutMetricsReadCount => _debugVisibleLayoutMetricsReadCount;

  @visibleForTesting
  int get debugVisibleLayoutMetricsScanCount => 0;

  @override
  void markNeedsLayout() {
    if (!_windowMutation) _flowLayoutDirty = true;
    _semanticChildren = null;
    _layoutMetricsValid = false;
    _visibleLayoutMountedEnd = double.negativeInfinity;
    _visibleLayoutExtentSum = 0.0;
    _visibleLayoutChildCount = 0;
    _invalidateStickyResolution();
    super.markNeedsLayout();
    if (_performingViewportLayout) return;
    final host = _viewportConfiguration.controller.snapshot.keepAliveOwner;
    if (host._refreshLink == null) return;
    final hasNavigation =
        host._viewportHeaderOwners != null || _headerExtent != 0 || host._stickyByIndex.isNotEmpty || _hasStickyChild;
    if (!hasNavigation &&
        !_requiresItemPaintOffsets &&
        _sectionPlan.segments.any((segment) => segment is StaticSegment)) {
      // 只有静态成员允许定位；兼容官方 Positioned 首次启用，虚拟列表不扫描。
      var child = _firstBusinessChild();
      while (child != null) {
        if (_scrollDebugCountersEnabled) host._debugCounters!.debugRefreshGeometryChildVisitCount++;
        final data = child.parentData! as _ScrollViewportParentData;
        if (data.isPositionedForLayout) {
          _requiresItemPaintOffsets = true;
          break;
        }
        child = data.nextContentSibling;
      }
    }
    if (hasNavigation || _requiresItemPaintOffsets) {
      // 刷新区域依赖成员几何：穿过独立布局边界，使父组合先排正文再读取区域。
      parent?.markNeedsLayout();
      host._refreshLink!.notifyContentLayout();
    }
  }

  bool _windowMutation = false;
  bool _flowLayoutDirty = true;
  SegmentExtentIndex? _lastLayoutIndex;
  SegmentPlan? _lastLayoutPlan;
  BoxConstraints? _lastFlowConstraints;

  void _selfMarkNeedsLayout() => markNeedsLayout();

  void _markWindowLayout() {
    _windowMutation = true;
    try {
      markNeedsLayout();
    } finally {
      _windowMutation = false;
    }
  }

  /// 成员索引或布局配置变化时请求重新布局。
  void markNeedsLayoutForChildParentData() => markNeedsLayout();

  RenderBox? _firstBusinessChild() {
    var child = firstChild;
    while (child != null && (child.parentData! as _ScrollViewportParentData).isChrome) {
      child = (child.parentData! as _ScrollViewportParentData).nextContentSibling;
    }
    return child;
  }

  /// 保留业务行自然尺寸，仅将滚动占位向上对齐像素；clean 行由 Flutter 短路。
  double _layoutChildToGrid(
    RenderBox child,
    _ScrollViewportParentData parentData,
    BoxConstraints childConstraints, {
    required bool isVertical,
    required double devicePixelRatio,
  }) {
    child.layout(childConstraints, parentUsesSize: true);
    var extent = isVertical ? child.size.height : child.size.width;
    if (parentData.isViewportHeader) {
      final owner = _viewportConfiguration.controller.snapshot.keepAliveOwner._viewportHeaderOwners?[parentData.index];
      if (owner is ElLargeTitleNavbarMixin) {
        // 绝对位置已包含导航折叠距离，流布局保留它，绘制和刷新边界仍使用真实盒高。
        final extra = owner._navbarAbsolutePosition ? owner._navbarLayoutCollapseExtent : 0.0;
        owner._navbarLayoutFlowExtra = extra;
        extent += extra;
      }
    }
    return snapVirtualItemExtentToPixelGrid(extent, devicePixelRatio);
  }

  /// 等高段沿主轴使用固定约束；全 tight 时业务行自身成为重排边界。
  double _layoutChildFixedTight(
    RenderBox child,
    _ScrollViewportParentData parentData,
    BoxConstraints childConstraints,
    double extent, {
    required bool isVertical,
  }) {
    child.layout(
      isVertical
          ? childConstraints.copyWith(minHeight: extent, maxHeight: extent)
          : childConstraints.copyWith(minWidth: extent, maxWidth: extent),
      parentUsesSize: true,
    );
    return extent;
  }

  /// 同帧测量真实首条并发布统一尺寸，按旧视口锚点修正 pixels 后布局业务条目。
  bool _layoutFixedSizes(
    BoxConstraints childConstraints, {
    required bool isVertical,
    required double devicePixelRatio,
  }) {
    final plan = _sectionPlan;
    if (!plan.hasFixed) return false;
    final changes = <({int section, FixedSizeSample sample, bool separator, double extent, bool first})>[];
    var measuredUniform = false;
    // 固定段只访问两个真实样本，不扫描完整挂载链表。
    for (var section = 0; section < plan.segments.length; section++) {
      final segment = plan.segments[section];
      if (segment is! LinearSegment || segment.fixed == null || segment.itemCount == 0) continue;
      final fixed = segment.fixed!;
      final sampleConstraints = _childConstraintsFor(alignment: segment.geometry.crossAxisAlignment);
      final start = plan.itemStartOf(section);
      final samples = math.min(segment.itemCount, fixed.itemStride);
      for (var local = 0; local < samples; local++) {
        final first = _renderChildForIndex(start + local);
        if (first == null) continue;
        final sample = local == 0 ? fixed.item : fixed.separator;
        if (sample.measuredConstraints == sampleConstraints &&
            sample.measuredGeneration == _measurementGeneration &&
            sample.measuredDevicePixelRatio == devicePixelRatio &&
            !_reportMeasuredExtentsWhenUnchanged) {
          continue;
        }
        first.layout(sampleConstraints, parentUsesSize: true);
        final extent = snapVirtualItemExtentToPixelGrid(
          isVertical ? first.size.height : first.size.width,
          devicePixelRatio,
        );
        sample.measuredConstraints = sampleConstraints;
        sample.measuredGeneration = _measurementGeneration;
        sample.measuredDevicePixelRatio = devicePixelRatio;
        measuredUniform = true;
        if (sample.extent == null || (sample.extent! - extent).abs() > precisionErrorTolerance) {
          changes.add((
            section: section,
            sample: sample,
            separator: local == 1,
            extent: extent,
            first: sample.extent == null,
          ));
        }
      }
    }
    if (changes.isEmpty) {
      // 新环境下首条 已真实布局但共享值未变：只确认缓存环境，不能
      // 为此清空整棵 Fenwick 或重建业务 item。
      if (measuredUniform && _reportMeasuredExtentsWhenUnchanged) {
        invokeLayoutCallback<BoxConstraints>((_) => _onMeasurementsChanged(null, duringLayout: true));
      }
      return false;
    }

    final canCorrect =
        heldThumbDragFraction == null &&
        mainViewportExtent > precisionErrorTolerance &&
        this.position.hasPixels &&
        this.position.hasContentDimensions;
    final viewportExtent = canCorrect ? mainViewportExtent : 0.0;
    final position = canCorrect ? this.position : null;
    final oldMax = canCorrect ? math.max(_totalExtent - viewportExtent, 0.0) : 0.0;
    final oldPixels = canCorrect ? (position!.pixels - position.minScrollExtent).clamp(0.0, oldMax).toDouble() : 0.0;
    final oldContent = canCorrect
        ? VirtualScrollGeometry.contentFromPixels(oldPixels, oldMax, reversed: mainAxisReversed)
        : 0.0;
    final pinnedEdge = canCorrect ? VirtualScrollGeometry.pinnedEdge(oldPixels, oldMax) : null;
    final firstMeasurement = changes.any((change) => change.first);
    final pinToMin = pinnedEdge == VirtualScrollEdge.min;
    final pinToMax =
        pinnedEdge == VirtualScrollEdge.max && (pinToEnd || firstMeasurement || _reportMeasuredExtentsWhenUnchanged);
    final anchor =
        canCorrect &&
            !pinToMin &&
            !pinToMax &&
            (preserveAnchor || firstMeasurement || _reportMeasuredExtentsWhenUnchanged)
        ? anchorAtContentOffset(oldContent, within: viewportExtent, useModelOffsets: true)
        : null;

    var totalDelta = 0.0;
    for (final change in changes) {
      change.sample.extent = change.extent;
      totalDelta += _extentIndex.updateFixedSizes(
        change.section,
        itemExtent: change.separator ? null : change.extent,
        separatorExtent: change.separator ? change.extent : null,
      );
    }
    if (totalDelta.abs() > precisionErrorTolerance) {
      _totalExtent += totalDelta;
      _invalidateStickyResolution();
      if (_scrollDebugCountersEnabled) _debugInLayoutMeasurementApplyCount++;
    }

    if (canCorrect) {
      final newMax = math.max(_totalExtent - viewportExtent, 0.0);
      double targetPixels;
      if (pinToMin) {
        targetPixels = 0.0;
      } else if (pinToMax) {
        targetPixels = newMax;
      } else if (anchor != null) {
        final newContent = (_modelMainStartOfIndex(anchor.index) - anchor.delta).clamp(0.0, newMax).toDouble();
        targetPixels = VirtualScrollGeometry.pixelsFromContent(newContent, newMax, reversed: mainAxisReversed);
      } else {
        targetPixels = oldPixels.clamp(0.0, newMax).toDouble();
      }
      final currentPixels = position!.pixels - position.minScrollExtent;
      final correction = targetPixels - currentPixels;
      if (correction.abs() > precisionErrorTolerance) {
        if (_scrollDebugCountersEnabled) _debugInLayoutCorrectionCount++;
        recordLayoutPositionCorrection(contentAxis, correction);
        position.correctBy(correction);
      }
    }

    invokeLayoutCallback<BoxConstraints>((_) => _onMeasurementsChanged(null, duringLayout: true));
    return totalDelta.abs() > precisionErrorTolerance;
  }

  void _invalidateStickyResolution() {
    _stickyResolutionCacheValid = false;
    _stickyResolutionCache = null;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ScrollViewportParentData) {
      child.parentData = _ScrollViewportParentData();
    }
  }

  ({int index, double delta})? anchorAtContentOffset(
    double contentOffset, {
    double? within,
    bool Function(int index)? skip,
    bool useModelOffsets = false,
  }) {
    RenderBox? fallback;
    // 前缘首个相交项（skip 全被跳过时的兜底 = 原行为）。
    ({int index, double delta})? leadingAnchor;
    var child = _firstBusinessChild();
    while (child != null) {
      final parentData = child.parentData! as _ScrollViewportParentData;
      if (!child.hasSize || parentData.isPositionedForLayout) {
        child = parentData.nextContentSibling;
        continue;
      }
      // 已知行尺寸变化时，刚排好的展示位置已经移动；锚点必须读更新前的模型。
      final mainStart = useModelOffsets
          ? _modelMainStartOfIndex(parentData.index)
          : _axis == Axis.vertical
          ? parentData.offset.dy
          : parentData.offset.dx;
      final extent = useModelOffsets
          ? _extentIndex.extentOf(_sectionPlan.rowOfItem(parentData.index))
          : _axis == Axis.vertical
          ? child.size.height
          : child.size.width;
      final mainEnd = mainStart + extent;
      if (mainEnd > contentOffset + precisionErrorTolerance) {
        leadingAnchor ??= (index: parentData.index, delta: mainStart - contentOffset);
        // 超出视口可见范围仍未找到可用锚点 → 回退前缘锚。
        if (within != null && mainStart >= contentOffset + within - precisionErrorTolerance) break;
        // 跳过本批次高度将变化的行：钉住它会把它的尺寸增量推给视口内
        // 其余内容（fling 穿越未测量区域时的持续位置调整感）；钉住其后
        // 首个"老"行，增量被吸收到视口外。
        if (skip == null || !skip(parentData.index)) {
          return (index: parentData.index, delta: mainStart - contentOffset);
        }
      }
      fallback = child;
      child = parentData.nextContentSibling;
    }
    if (leadingAnchor != null) return leadingAnchor;
    if (fallback == null) return null;
    final parentData = fallback.parentData! as _ScrollViewportParentData;
    final mainStart = useModelOffsets
        ? _modelMainStartOfIndex(parentData.index)
        : _axis == Axis.vertical
        ? parentData.offset.dy
        : parentData.offset.dx;
    return (index: parentData.index, delta: mainStart - contentOffset);
  }

  @override
  bool isSelectionItemAvailable(RenderObject descendant, {required bool visibleOnly}) {
    final slot = _slotChildForRender(descendant);
    if (slot == null || !slot.attached || !slot.hasSize) return false;
    final data = slot.parentData! as _ScrollViewportParentData;
    if (data.isChrome || data.zIndex < 0 || data.index >= _sectionPlan.totalItemCount) return false;
    if (!visibleOnly || _sectionPlan.segments[_sectionPlan.segmentOfItem(data.index)].resident) return true;
    var bounds = MatrixUtils.transformRect(
      slot.getTransformTo(this),
      Offset.zero & slot.size,
    ).intersect(contentViewportRect);
    if (bounds.isEmpty) return false;
    RenderObject child = this;
    for (RenderObject? ancestor = parent; ancestor != null; ancestor = ancestor.parent) {
      bounds = MatrixUtils.transformRect(child.getTransformTo(ancestor), bounds);
      final clip = ancestor.describeApproximatePaintClip(child);
      if (clip != null) bounds = bounds.intersect(clip);
      if (bounds.isEmpty) return false;
      child = ancestor;
    }
    return !bounds.isEmpty;
  }

  RenderBox? _slotChildForRender(RenderObject descendant) {
    RenderObject? current = descendant;
    while (current != null && !identical(current.parent, this)) {
      current = current.parent;
    }
    return current is RenderBox && identical(current.parent, this) ? current : null;
  }

  @override
  void detach() {
    _semanticChildren = null;

    _resetPendingExtentReports();
    super.detach();
    for (final child in _layoutViews.values) {
      child.detach();
    }
  }

  final Map<_LayoutBinding, RenderLayoutView> _layoutViews = {};

  void addLayout(_LayoutBinding binding, RenderLayoutView child) {
    _layoutViews[binding] = child;
    adoptChild(child);
    markNeedsLayout();
  }

  void removeLayout(_LayoutBinding binding, RenderLayoutView child) {
    _layoutViews.remove(binding);
    dropChild(child);
    markNeedsLayout();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    _layoutViews.values.forEach(visitor);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final child in _layoutViews.values) {
      child.attach(owner);
    }
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    _layoutViews.values.forEach(redepthChild);
  }

  RenderBox? _renderChildForIndex(int index) {
    final element = _viewportConfiguration.controller._element;
    final child = element?._childByKey[element._keyByIndex[index]]?.renderObject;
    return child is RenderBox ? child : null;
  }

  void _layoutViewBounds() {
    for (final entry in _layoutViews.entries) {
      final section = entry.key.section;
      final plan = _sectionPlan;
      final row = plan.rowStartOf(section);
      final end = row + plan.rowCountOf(section);
      final main =
          _extentIndex.offsetOf(end) -
          _extentIndex.offsetOf(row) +
          math.max(0, end - row - 1) * plan.internalGapOf(section);
      final cross =
          plan.gridAt(section)?.crossExtent ??
          (_axis == Axis.vertical
              ? _laidOutContentSize.width - _padding.horizontal
              : _laidOutContentSize.height - _padding.vertical);
      final child = entry.value;
      child.layout(
        BoxConstraints.tight(_axis == Axis.vertical ? Size(math.max(0, cross), main) : Size(main, math.max(0, cross))),
      );
      final data = child.parentData! as _ScrollViewportParentData;
      final start = _mainLeadingPadding + _extentIndex.offsetOf(row) + plan.cumulativeSpacingBeforeRow(row);
      data.offset = _axis == Axis.vertical ? Offset(_crossLeadingPadding, start) : Offset(start, _crossLeadingPadding);
    }
  }

  /// index（item 空间）的模型主轴起点：plan 非空走行空间 + 累计间距；纯 list
  /// 与原 `offsetOf(index) + index*gap` 逐字节等价。
  double _modelMainStartOfIndex(int index) {
    final plan = _sectionPlan;
    final row = plan.rowOfItem(index);
    return _mainLeadingPadding + _extentIndex.offsetOf(row) + plan.cumulativeSpacingBeforeRow(row);
  }

  /// reverse 轴停在 min 边时从真实尾项向前落位，使尾部在尺寸测量期间保持贴边。
  bool get _shouldAnchorMountedTail {
    if (!mainAxisReversed) return false;
    final itemCount = _sectionPlan.totalItemCount;
    if (itemCount == 0 || _lastIndex < itemCount) return false;
    final position = this.position;
    return !position.hasPixels || position.pixels <= precisionErrorTolerance;
  }

  double _tailRunMainOffset(List<double> extents, {required List<int> rows}) {
    var result = _totalExtent - _mainTrailingPadding;
    for (var i = extents.length - 1; i >= 0; i--) {
      result -= extents[i];
      if (i == 0) continue;
      result -= _sectionPlan.spacingAfterRow(rows[i - 1]);
    }
    return result;
  }

  /// content-start 边缘判据：content 滚动偏移贴 0（首项可见于视口主轴起点）。
  /// 使用视口 paintedMainScrollPixels（content 坐标，reverse 已折算），与
  /// [_liveContentBounds] 同源口径，布局期内同样有效。
  bool _isAtContentStartEdge() {
    final viewportExtent = mainViewportExtent;
    if (viewportExtent <= 0.0) return false;
    final maxOffset = math.max(_totalExtent - viewportExtent, 0.0);
    final contentOffset = paintedMainScrollPixels.clamp(0.0, maxOffset);
    return contentOffset <= precisionErrorTolerance;
  }

  @override
  Size layoutVirtualContent(BoxConstraints value) {
    final host = _viewportConfiguration.controller.snapshot.keepAliveOwner;
    if (host._measuringInitialWindow) {
      // 先处理常驻成员与统一尺寸样本，随后只测新增的未知条目，避免逐项填窗变成平方级布局遍历。
      _layoutMountedContent(value);
      while (host._measuringInitialWindow) {
        invokeLayoutCallback<BoxConstraints>((_) => _onMeasurementsChanged(null, duringLayout: true));
        if (!host._measuringInitialWindow) break;
        final index = host._initialMeasurementIndex;
        final child = index == null ? null : _renderChildForIndex(index);
        if (child == null) break;
        final plan = _sectionPlan;
        final segment = plan.segments[plan.segmentOfItem(index!)];
        if (segment is! LinearSegment || segment.fixed != null) {
          _layoutMountedContent(value);
          continue;
        }
        if (_scrollDebugCountersEnabled) host._debugCounters!.debugLayoutChildVisitCount++;
        final parentData = child.parentData! as _ScrollViewportParentData;
        final extent = _layoutChildToGrid(
          child,
          parentData,
          _childConstraintsFor(alignment: segment.geometry.crossAxisAlignment),
          isVertical: _axis == Axis.vertical,
          devicePixelRatio: devicePixelRatio,
        );
        final previousTotal = _extentIndex.totalExtent;
        _extentIndex.updateMeasuredExtent(plan.rowOfItem(index), extent);
        _totalExtent += _extentIndex.totalExtent - previousTotal;
        parentData.lastReportedExtent = extent;
        _scheduleExtentReport(plan.rowOfItem(index), extent);
      }
      // 估计已由实测窗口建立，统一落位并计算恢复偏移对应的最终窗口。
    }
    while (true) {
      final result = _layoutMountedContent(value);
      final previousFirst = _firstIndex;
      final previousLast = _lastIndex;
      final bounds = _liveContentBounds();
      if (_firstIndex > 0 && _modelMainStartOfIndex(_firstIndex) > bounds.visibleStart + precisionErrorTolerance) {
        // 新测量也可能让首项移入视口；重用测量回调从已更新的模型补回前一行。
        invokeLayoutCallback<BoxConstraints>((_) => _onMeasurementsChanged(null, duringLayout: true));
        if (_firstIndex < previousFirst || _lastIndex > previousLast) continue;
      }
      final requested = _underflowTarget(bounds.visibleEnd);
      if (requested == null) return result;
      // 实测短于估算时在本次布局补齐正文；末端索引单调前进，不能等帧尾再露白一帧。
      invokeLayoutCallback<BoxConstraints>((_) => _onMeasurementsChanged(requested, duringLayout: true));
      if (_lastIndex <= previousLast) return result;
    }
  }

  Size _layoutMountedContent(BoxConstraints value) {
    contentConstraints = value;
    _hasContentSize = true;
    if (_scrollDebugCountersEnabled) _debugLayoutCount++;
    _syncSelectionGeometryObserver();
    // 双轴 / shrinkWrap：交叉轴尺寸取决于 mounted items 的 maxCross，须先排
    // children 再定 _laidOutContentSize；普通单轴仍先定 _laidOutContentSize 以保留 fill 交叉轴语义。
    final useNaturalCrossExtent = _usesNaturalCrossExtent;
    if (useNaturalCrossExtent) {
      _mountedMaxCross = 0.0;
    } else {
      _laidOutContentSize = contentConstraints.constrain(_contentSizeFor(contentConstraints));
    }
    final childConstraints = _childConstraintsFor();
    final isVertical = _axis == Axis.vertical;
    final pixelRatio = devicePixelRatio;
    final fixedModelChanged = _layoutFixedSizes(childConstraints, isVertical: isVertical, devicePixelRatio: pixelRatio);

    final segmentConstraints = <BoxConstraints>[
      for (final segment in _sectionPlan.segments)
        segment is LinearSegment
            ? _childConstraintsFor(alignment: segment.geometry.crossAxisAlignment)
            : childConstraints,
    ];
    final skipResident =
        !_flowLayoutDirty &&
        !fixedModelChanged &&
        !_reportMeasuredExtentsWhenUnchanged &&
        !_usesNaturalCrossExtent &&
        !_hasStickyChild &&
        !_requiresItemPaintOffsets &&
        _headerExtent == 0 &&
        identical(_lastLayoutPlan, _sectionPlan) &&
        identical(_lastLayoutIndex, _extentIndex) &&
        _lastFlowConstraints == value &&
        _extentIndex.measuredCount == _extentIndex.count;
    final mainLeading = _mainLeadingPadding;
    final crossLeading = _crossLeadingPadding;
    var child = _firstBusinessChild();
    var visibleExtentSum = 0.0;
    var visibleChildCount = 0;
    var visibleMountedEnd = double.negativeInfinity;
    // 逐 run（index 连续段）布局：先测量收集，再统一定位。定位锚点取 run 内
    // 首个「已测量且实测尺寸与模型一致」的 child——锚点之前（刚进入视口、
    // 尚未上报）的行倒序回排，real−estimate 的误差向进入侧（屏幕外）位移；
    // 若像旧实现那样一律从 run 首行顺排，误差会把锚点后的可见内容整体推开
    // 一帧，post-frame 修正下一帧才追上 = fling 穿越未测量区域时的持续跳动。
    final runChildren = <RenderBox>[];
    final runExtents = <double>[];
    var anySticky = false;
    _requiresItemPaintOffsets = false;
    final applyMeasurementsInLayout = _canApplyMeasurementsInLayout;
    final anchorMountedTail = _shouldAnchorMountedTail;
    _pendingInLayoutApplyIndices.clear();
    _pendingInLayoutApplyExtents.clear();
    final plan = _sectionPlan;
    var positionedRolesChanged = false;
    _positionedExtentDelta = 0.0;
    final spacingBefore = plan.totalSpacing();
    // ==== 段感知 run 锚定布局 ====
    // 非 grid 行：连续 index run 取「首个实测且与模型一致」的行为锚，锚前
    // 倒序回排、锚后按实测连续堆叠——首帧绘制即最终间距，估算误差向进入
    // 侧（屏幕外）位移（纯 list 路径的事故修复语义推广到段模型；行间距
    // 按 plan：段内 spacing / 段边界 outerGap）。grid cell：模型行定位 +
    // 列偏移（P0 固定行高零误差，无需锚定）。grid 列几何由 plan 构造期
    // 的 crossAxisExtent 解析，本帧宽突变滞后一帧随 plan 重建修正（M5）。
    var lastVisibleRowAccounted = -1;
    final runRows = <int>[];
    while (child != null) {
      final headData = child.parentData! as _ScrollViewportParentData;
      final headIndex = headData.index;
      final headSection = plan.segmentOfItem(headIndex);
      final headSegment = plan.segments[headSection];
      if (skipResident && headSegment.resident) {
        final last = _renderChildForIndex(plan.itemStartOf(headSection) + headSegment.itemCount - 1);
        child = (last!.parentData! as _ScrollViewportParentData).nextContentSibling;
        continue;
      }
      if (_scrollDebugCountersEnabled) {
        _viewportConfiguration.controller.snapshot.keepAliveOwner._debugCounters!.debugLayoutChildVisitCount++;
      }
      positionedRolesChanged = _syncMountedPositionedRole(headData, plan, headSegment) || positionedRolesChanged;
      final headFixed = headData.isViewportPositioned;
      if (headFixed) {
        final previousOffset = headData.offset;
        final previousSize = child.hasSize ? child.size : null;
        headData.resolveDimensions(size);
        RenderStack.layoutPositionedChild(child, headData, size, _positionedAlignment);
        if (previousOffset != headData.offset || previousSize != child.size) _positionedPaintGeneration++;
        headData.lastReportedExtent = 0.0;
        child = headData.nextContentSibling;
        continue;
      }
      final headIsGrid = headSegment is GridSegment;
      final headFixedExtent = headSegment is LinearSegment
          ? headSegment.fixedExtentAt(headIndex - plan.itemStartOf(headSection))
          : null;
      if (headIsGrid || headFixedExtent != null) {
        final parentData = headData;
        final index = headIndex;
        // 网格单元全 tight，业务行内部重排不会传播到视口。
        if (parentData.stickyOffset != null) anySticky = true;
        final row = plan.rowOfItem(index);
        final rowInRange = row >= 0 && row < _extentIndex.count;
        final rowExtent = headFixedExtent ?? plan.gridAt(headSection)!.cellMainExtent;
        var gridCross = 0.0;
        if (headIsGrid) {
          final geometry = plan.gridAt(headSection)!;
          final cell = geometry.cellSize;
          child.layout(BoxConstraints.tight(cell), parentUsesSize: true);
          gridCross = geometry.crossStart(index - plan.itemStartOf(headSection));
          final rtl =
              isVertical &&
              _viewportConfiguration.controller.snapshot.keepAliveOwner._buildTextDirection == TextDirection.rtl;
          if (rtl) gridCross = geometry.crossExtent - gridCross - geometry.cellCrossExtent;
        } else {
          _layoutChildFixedTight(child, parentData, segmentConstraints[headSection], rowExtent, isVertical: isVertical);
        }
        // P0 固定行高：模型创建即精确。就地标记 measured（幂等、同值零改
        // 前缀），让范围查询知道该行是准的；不排任何报告。
        if (rowInRange && !_extentIndex.isMeasured(row)) {
          _extentIndex.updateMeasuredExtent(row, rowExtent);
        }
        parentData.lastReportedExtent = rowExtent;
        final mainStart = _modelMainStartOfIndex(index);
        final crossOffset = headIsGrid
            ? crossLeading + gridCross
            : _childCrossOffsetFor(child, crossLeading, isVertical: isVertical);
        parentData.offset = isVertical ? Offset(crossOffset, mainStart) : Offset(mainStart, crossOffset);
        if (useNaturalCrossExtent) {
          _mountedMaxCross = math.max(
            _mountedMaxCross,
            headIsGrid
                ? plan.gridAt(headSection)!.crossExtent
                : isVertical
                ? child.size.width
                : child.size.height,
          );
        }
        // 可视度量按**行**去重累计（underflow 的平均行高估算要行口径，
        // 逐 cell 累计会把平均值摊薄 n 倍导致多挂）。
        if (index >= _firstIndex && index < _lastIndex && row != lastVisibleRowAccounted) {
          lastVisibleRowAccounted = row;
          visibleExtentSum += rowExtent;
          visibleChildCount++;
          visibleMountedEnd = math.max(visibleMountedEnd, mainStart + rowExtent);
        }
        child = parentData.nextContentSibling;
        continue;
      }

      // 收集非 grid 连续 run（遇 grid cell 或 index 断裂即止）。
      runChildren.clear();
      runExtents.clear();
      runRows.clear();
      var anchorPos = -1;
      int? prevIndex;
      RenderBox? cursor = child;
      while (cursor != null) {
        if (_scrollDebugCountersEnabled) {
          _viewportConfiguration.controller.snapshot.keepAliveOwner._debugCounters!.debugLayoutChildVisitCount++;
        }
        final parentData = cursor.parentData! as _ScrollViewportParentData;
        final index = parentData.index;
        if (prevIndex != null && index != prevIndex + 1) break;
        final segment = index >= 0 && index < plan.totalItemCount ? plan.segments[plan.segmentOfItem(index)] : null;
        positionedRolesChanged = _syncMountedPositionedRole(parentData, plan, segment) || positionedRolesChanged;
        if (parentData.isViewportPositioned) break;
        if (segment is GridSegment) break;
        if (segment is LinearSegment &&
            segment.fixedExtentAt(index - plan.itemStartOf(plan.segmentOfItem(index))) != null) {
          break;
        }
        if (skipResident && segment?.resident == true) break;
        if (parentData.stickyOffset != null) anySticky = true;
        final row = index >= 0 && index < plan.totalItemCount ? plan.rowOfItem(index) : -1;
        final rowInRange = row >= 0 && row < _extentIndex.count;
        // 已完成首条测量的统一尺寸段，模型值即终值并按主轴
        // tight 布局；普通列表 才探测真实自然高。
        final fixedFlowExtent = switch (segment) {
          LinearSegment() when rowInRange => plan.fixedExtentOfRow(row),
          GridSegment() when rowInRange => plan.fixedExtentOfRow(row),
          _ => null,
        };
        final itemConstraints = segmentConstraints[plan.segmentOfItem(index)];
        final extent = fixedFlowExtent != null
            ? _layoutChildFixedTight(cursor, parentData, itemConstraints, fixedFlowExtent, isVertical: isVertical)
            : _layoutChildToGrid(
                cursor,
                parentData,
                itemConstraints,
                isVertical: isVertical,
                devicePixelRatio: pixelRatio,
              );
        if (useNaturalCrossExtent) {
          _mountedMaxCross = math.max(_mountedMaxCross, isVertical ? cursor.size.width : cursor.size.height);
        }
        if (anchorPos < 0 &&
            rowInRange &&
            _extentIndex.isMeasured(row) &&
            (_extentIndex.extentOf(row) - extent).abs() <= precisionErrorTolerance) {
          anchorPos = runChildren.length;
        }
        runChildren.add(cursor);
        runExtents.add(extent);
        runRows.add(row);
        prevIndex = index;
        cursor = parentData.nextContentSibling;
      }

      final runFirstData = runChildren.first.parentData! as _ScrollViewportParentData;
      double mainOffset;
      final runLastData = runChildren.last.parentData! as _ScrollViewportParentData;
      if (anchorMountedTail && runLastData.index == plan.totalItemCount - 1) {
        mainOffset = _tailRunMainOffset(runExtents, rows: runRows);
      } else if (anchorPos <= 0) {
        mainOffset = _modelMainStartOfIndex(runFirstData.index);
      } else {
        final anchorData = runChildren[anchorPos].parentData! as _ScrollViewportParentData;
        var start = _modelMainStartOfIndex(anchorData.index);
        for (var i = anchorPos - 1; i >= 0; i--) {
          start -= runExtents[i] + (runRows[i] >= 0 ? plan.spacingAfterRow(runRows[i]) : 0.0);
        }
        mainOffset = start;
        // content-start 守卫：drift 帧以后继项为锚点倒排时，首项无论变高
        // 还是变矮都必须精确贴住 mainLeading；只做下限钳制会让变矮路径
        // 留下正偏移，形成整组单帧下闪。
        if (plan.rowOfItem(runFirstData.index) == 0 && _isAtContentStartEdge()) {
          mainOffset = mainLeading;
        }
      }
      for (var i = 0; i < runChildren.length; i++) {
        final runChild = runChildren[i];
        final parentData = runChild.parentData! as _ScrollViewportParentData;
        final extent = runExtents[i];
        final row = runRows[i];
        final rowInRange = row >= 0 && row < _extentIndex.count;
        final cross = _childCrossOffsetFor(runChild, crossLeading, isVertical: isVertical);
        parentData.offset = isVertical ? Offset(cross, mainOffset) : Offset(mainOffset, cross);
        final mainEnd = mainOffset + extent;
        if (parentData.index >= _firstIndex && parentData.index < _lastIndex && row != lastVisibleRowAccounted) {
          lastVisibleRowAccounted = row;
          visibleExtentSum += extent;
          visibleChildCount++;
          visibleMountedEnd = math.max(visibleMountedEnd, mainEnd);
        }
        // 报告判据与纯 list 路径一致，仅 key 换到行空间。
        final previous = parentData.lastReportedExtent;
        final previouslyReportedExtentChanged = previous != null && (previous - extent).abs() > precisionErrorTolerance;
        final measuredExtentUnchanged =
            rowInRange &&
            _extentIndex.isMeasured(row) &&
            (_extentIndex.extentOf(row) - extent).abs() <= precisionErrorTolerance;
        final unmeasuredExtentMatchesModel =
            rowInRange &&
            !_extentIndex.isMeasured(row) &&
            (_extentIndex.extentOf(row) - extent).abs() <= precisionErrorTolerance;
        final suppressUnchangedMeasuredExtent = measuredExtentUnchanged && !_reportMeasuredExtentsWhenUnchanged;
        final shouldReportExtent =
            !suppressUnchangedMeasuredExtent && (previous == null || previouslyReportedExtentChanged);
        if (!_reportMeasuredExtentsWhenUnchanged &&
            unmeasuredExtentMatchesModel &&
            (previous == null || previouslyReportedExtentChanged)) {
          _extentIndex.updateMeasuredExtent(row, extent);
          parentData.lastReportedExtent = extent;
        } else if (shouldReportExtent) {
          parentData.lastReportedExtent = extent;
          if (applyMeasurementsInLayout && rowInRange) {
            _pendingInLayoutApplyIndices.add(row);
            _pendingInLayoutApplyExtents.add(extent);
          }
          _scheduleExtentReport(row, extent);
        }
        mainOffset = mainEnd + (row >= 0 ? plan.spacingAfterRow(row) : 0.0);
      }
      child = (runChildren.last.parentData! as _ScrollViewportParentData).nextContentSibling;
    }
    _hasStickyChild = anySticky;
    if (positionedRolesChanged) {
      plan.refreshPositionedSpacing();
      _totalExtent += _positionedExtentDelta + plan.totalSpacing() - spacingBefore;
    }
    final appliedMeasurementsInLayout = _applyPendingMeasurementsInLayout();
    if (appliedMeasurementsInLayout || positionedRolesChanged) {
      // 就地应用改变了模型偏移与总长，且外壳会在同帧 applyContentDimensions
      // 取到新 max：必须**同帧**按新模型重定位（纯算术，children 已测量，
      // 无二次 child.layout），使绘制位置/总长/max/修正后 pixels 四者自洽。
      // 只修正 pixels 不重定位的话，reverse 轴（pixels 锚在 max 侧）会出现
      // "max 先动、位置下帧才动"的单帧错位，fling 穿越未测量区表现为逐次
      // 回跳振荡。可视窗口度量随新位置重算。
      visibleExtentSum = 0.0;
      visibleChildCount = 0;
      visibleMountedEnd = double.negativeInfinity;
      var repositionChild = _firstBusinessChild();
      var repositionLastRow = -1;
      while (repositionChild != null) {
        final parentData = repositionChild.parentData! as _ScrollViewportParentData;
        // 定位成员使用视口坐标，不随正文重新定位，也不参与正文行高估算。
        if (parentData.isPositionedForLayout) {
          repositionChild = parentData.nextContentSibling;
          continue;
        }
        final index = parentData.index;
        final extent = isVertical ? repositionChild.size.height : repositionChild.size.width;
        final itemCount = plan.totalItemCount;
        if (index >= 0 && index < itemCount) {
          final mainStart = _modelMainStartOfIndex(index);
          // 交叉轴偏移保持本帧已计算值（grid cell 的列偏移不受主轴模型变化影响）。
          final currentCross = isVertical ? parentData.offset.dx : parentData.offset.dy;
          parentData.offset = isVertical ? Offset(currentCross, mainStart) : Offset(mainStart, currentCross);
        }
        if (index >= _firstIndex && index < _lastIndex) {
          final row = plan.rowOfItem(index);
          if (row != repositionLastRow) {
            repositionLastRow = row;
            final mainStart = isVertical ? parentData.offset.dy : parentData.offset.dx;
            visibleExtentSum += extent;
            visibleChildCount++;
            visibleMountedEnd = math.max(visibleMountedEnd, mainStart + extent);
          }
        }
        repositionChild = parentData.nextContentSibling;
      }
    }
    if (useNaturalCrossExtent || appliedMeasurementsInLayout || fixedModelChanged || positionedRolesChanged) {
      // dual / 交叉轴收缩：maxCross 累计完成后再定 _laidOutContentSize；帧内应用后主轴总长
      // 已就地更新，同帧重设 _laidOutContentSize 让外壳 applyContentDimensions 直接取到新 max。
      _laidOutContentSize = contentConstraints.constrain(_contentSizeFor(contentConstraints));
    }
    if (useNaturalCrossExtent &&
        (_crossAxisAlignment == CrossAxisAlignment.center || _crossAxisAlignment == CrossAxisAlignment.end)) {
      // 收缩模式下 _laidOutContentSize 后定，主循环里的显式 center/end 摆位读不到本帧交叉轴
      // 尺寸——_laidOutContentSize 落定后按最终自由空间补一遍交叉轴落位。
      var repositionCross = _firstBusinessChild();
      while (repositionCross != null) {
        final parentData = repositionCross.parentData! as _ScrollViewportParentData;
        final cross = _childCrossOffsetFor(repositionCross, _crossLeadingPadding, isVertical: isVertical);
        parentData.offset = isVertical ? Offset(cross, parentData.offset.dy) : Offset(parentData.offset.dx, cross);
        repositionCross = parentData.nextContentSibling;
      }
    }
    _layoutMetricsValid = true;
    _visibleLayoutMountedEnd = visibleMountedEnd;
    _visibleLayoutExtentSum = visibleExtentSum;
    _visibleLayoutChildCount = visibleChildCount;
    _syncStickyStackOrder(_resolveSticky(_liveContentBounds().visibleStart));
    _layoutViewBounds();
    _lastLayoutIndex = _extentIndex;
    _lastLayoutPlan = plan;
    _lastFlowConstraints = value;
    _flowLayoutDirty = false;
    return _laidOutContentSize;
  }

  void _syncSelectionGeometryObserver() {
    _selectionGeometryObserver = null;
    for (RenderObject? node = parent; node != null; node = node.parent) {
      if (node is SelectionGeometryObserver) {
        _selectionGeometryObserver = node as SelectionGeometryObserver;
        return;
      }
    }
  }

  void _resetPendingExtentReports() {
    _extentReportGeneration++;
    _pendingExtentReports.clear();
    _extentReportScheduled = false;
    _pendingUnderflowLastIndex = null;
  }

  void _clearReportedExtents() {
    var child = _firstBusinessChild();
    while (child != null) {
      final parentData = child.parentData! as _ScrollViewportParentData;
      parentData.lastReportedExtent = null;
      child = parentData.nextContentSibling;
    }
  }

  Size _contentSizeFor(BoxConstraints contentConstraints) {
    final naturalCrossExtent = math.max(_mountedMaxCross, _minimumCrossAxisExtent) + _crossPaddingTotal;
    if (_dualAxis) {
      // 交叉轴 = mounted items 的 maxCross + 交叉 padding（mounted-only 撑）。
      // dry / 首帧尚无 mounted 度量时该值为 0，下一 layout 帧收敛——横向
      // 范围随 mounted 窗口动态变化是本设计接受的语义。
      return Size(naturalCrossExtent, _totalExtent);
    }
    if (_axis == Axis.vertical) {
      // shrinkWrap / 无界宽 → 交叉轴按真实子内容回填；普通有界滚动维持 fill。
      final width = _usesNaturalCrossExtent || !contentConstraints.hasBoundedWidth
          ? naturalCrossExtent
          : contentConstraints.maxWidth;
      return Size(width, _totalExtent);
    }
    final height = _usesNaturalCrossExtent || !contentConstraints.hasBoundedHeight
        ? naturalCrossExtent
        : contentConstraints.maxHeight;
    return Size(_totalExtent, height);
  }

  BoxConstraints _childConstraintsFor({CrossAxisAlignment? alignment}) {
    if (_dualAxis) {
      // 双轴：items 按内容自然量，不做视口 fill。
      return BoxConstraints(minWidth: 0.0, maxWidth: double.infinity, minHeight: 0.0, maxHeight: double.infinity);
    }
    final effectiveAlignment = alignment ?? _crossAxisAlignment;
    final useNaturalCrossExtent = _usesNaturalCrossExtent;
    if (_axis == Axis.vertical) {
      final width = contentConstraints.hasBoundedWidth
          ? math.max(contentConstraints.maxWidth - _crossPaddingTotal, 0.0)
          : double.infinity;
      if (useNaturalCrossExtent) {
        final stretch = effectiveAlignment == CrossAxisAlignment.stretch;
        final minWidth = stretch && width.isFinite ? width : 0.0;
        return BoxConstraints(minWidth: minWidth, maxWidth: width, minHeight: 0.0, maxHeight: double.infinity);
      }
      // null（缺省）沿既有行为 = tight 拉满；显式 start/center/end 才放 loose，
      // 成员按固有宽自量、落位期按自由空间摆位。
      final align = effectiveAlignment;
      final minWidth = align == null || align == CrossAxisAlignment.stretch ? width : 0.0;
      return BoxConstraints(minWidth: minWidth, maxWidth: width, minHeight: 0.0, maxHeight: double.infinity);
    }
    // horizontal 缺省沿既有行为 = loose 自然高（存量横滑内容按固有高写就，
    // 缺省拉满会整体炸版）；显式 stretch 才 tight。
    final height = contentConstraints.hasBoundedHeight
        ? math.max(contentConstraints.maxHeight - _crossPaddingTotal, 0.0)
        : double.infinity;
    final minHeight = effectiveAlignment == CrossAxisAlignment.stretch && height.isFinite ? height : 0.0;
    return BoxConstraints(minWidth: 0.0, maxWidth: double.infinity, minHeight: minHeight, maxHeight: height);
  }

  /// 单个成员的交叉轴落位：null（缺省=轴向现状）与 stretch 短路返回
  /// [crossLeading]（vertical tight 无自由空间、horizontal 现状即 start）；
  /// 显式 start/center/end 按「可用交叉轴 − 成员实际尺寸」的自由空间摆位。
  /// 双轴恒缺省（widget assert 只许 null），短路路径零开销。
  double _childCrossOffsetFor(RenderBox child, double crossLeading, {required bool isVertical}) {
    final data = child.parentData! as _ScrollViewportParentData;
    final segment = _sectionPlan.segments[_sectionPlan.segmentOfItem(data.index)];
    final align = segment is LinearSegment ? segment.geometry.crossAxisAlignment : _crossAxisAlignment;
    if (align == null || align == CrossAxisAlignment.stretch) return crossLeading;
    // 收缩模式主循环里 _laidOutContentSize 未定（首帧还没有旧值可读）：先按 start 落位，
    // _laidOutContentSize 落定后的补摆位循环会用最终自由空间重算。
    if (_usesNaturalCrossExtent && !_hasContentSize) return crossLeading;
    final available = math.max(
      (isVertical ? _laidOutContentSize.width : _laidOutContentSize.height) - _crossPaddingTotal,
      0.0,
    );
    final childCross = isVertical ? child.size.width : child.size.height;
    final free = math.max(available - childCross, 0.0);
    var offset = switch (align) {
      CrossAxisAlignment.center => free / 2.0,
      CrossAxisAlignment.end => free,
      _ => 0.0,
    };
    if (segment is LinearSegment) offset = segment.geometry.crossStart(available, childCross);
    if (isVertical &&
        _viewportConfiguration.controller.snapshot.keepAliveOwner._buildTextDirection == TextDirection.rtl) {
      offset = free - offset;
    }
    return crossLeading + offset;
  }

  int? _underflowTarget(double visibleContentEnd) {
    final plan = _sectionPlan;
    // 常驻与全部实测内容无需补挂，避免把旧窗口度量或浮点间隙当成缺行。
    if (plan.isAllResident || _extentIndex.measuredCount == _extentIndex.count) return null;
    if (!_layoutMetricsValid) return null;
    if (_scrollDebugCountersEnabled) _debugVisibleLayoutMetricsReadCount++;
    final itemCount = plan.totalItemCount;
    if (_visibleLayoutChildCount == 0 || _lastIndex >= itemCount) return null;
    final targetEnd = math.min(visibleContentEnd, _totalExtent);
    final lastRow = plan.rowOfItem((_lastIndex - 1).clamp(0, itemCount - 1).toInt());
    // 条目之后的声明间距也是有效占位，缓存边界落在间距内不代表正文缺行。
    final missingExtent = targetEnd - _visibleLayoutMountedEnd - plan.spacingAfterRow(lastRow);
    if (missingExtent <= precisionErrorTolerance) return null;
    // 可视度量按行去重累计（见 performLayout），averageExtent 是**行**均高。
    final averageExtent = _visibleLayoutExtentSum / _visibleLayoutChildCount;
    if (averageExtent <= precisionErrorTolerance || averageExtent.isNaN) return null;
    // Each additional row covers its extent plus one gap in layout space.
    final additionalRowCount = math.max(1, (missingExtent / (averageExtent + _gap)).ceil() + 1);
    // 行数转换为 item 数，补挂始终覆盖整行。
    final targetRow = math.min(plan.totalRowCount - 1, lastRow + additionalRowCount);
    return math.min(itemCount, plan.firstItemOfRow(targetRow) + plan.itemsInRow(targetRow));
  }

  void _scheduleUnderflowReportFromCurrentLayout(double visibleContentEnd) {
    final requestedLastIndex = _underflowTarget(visibleContentEnd);
    if (requestedLastIndex == null) return;
    final pending = _pendingUnderflowLastIndex;
    if (pending != null && pending >= requestedLastIndex) return;
    _pendingUnderflowLastIndex = requestedLastIndex;
    if (pending != null) return;
    final generation = _extentReportGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _extentReportGeneration) return;
      final requested = _pendingUnderflowLastIndex;
      _pendingUnderflowLastIndex = null;
      if (attached && requested != null) _onMeasurementsChanged(requested, duringLayout: false);
    });
  }

  void _scheduleExtentReport(int index, double extent) {
    _pendingExtentReports[index] = extent;
    if (_extentReportScheduled) return;
    _extentReportScheduled = true;
    final generation = _extentReportGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _extentReportGeneration) return;
      _extentReportScheduled = false;
      if (!attached) {
        _pendingExtentReports.clear();
        return;
      }
      final reports = Map<int, double>.of(_pendingExtentReports);
      _pendingExtentReports.clear();
      if (reports.isNotEmpty) _onItemExtentsChanged(reports);
    });
  }

  @override
  void layoutChromeChildren() {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as _ScrollViewportParentData;
      if (!data.isChrome) break;
      data.resolveDimensions(size);
      RenderStack.layoutPositionedChild(child, data, size, Alignment.topLeft);
      child = data.previousSibling;
    }
  }

  @override
  bool get stackSourceOrderIsExternal => true;

  @override
  void markChildStackOrderChanged(RenderBox child, {required int oldZIndex}) {
    super.markChildStackOrderChanged(child, oldZIndex: oldZIndex);
    final data = child.parentData! as _ScrollViewportParentData;
    if (!data.isChrome && (oldZIndex < 0) != (data.zIndex < 0)) {
      final host = _viewportConfiguration.controller.snapshot.keepAliveOwner;
      host._scheduleItemPresentationDispatch();
      // 固定头隐藏会改变刷新避让区域，交回布局阶段读取合法尺寸并同帧更新父级。
      if (data.isViewportPositioned && host._refreshLink != null) markNeedsLayout();
    }
  }

  @override
  void didChangeScrollOffset() {
    // 固定成员与视口头部只随布局变化，纯正文平移不重新计算刷新区域。
    if (!_hasStickyChild || !_hasContentSize) return;
    _syncStickyStackOrder(_resolveSticky(_liveContentBounds().visibleStart));
    if (!_performingViewportLayout) _updateRefreshGeometry();
  }

  RenderBox? _stackStickyChild;
  double _headerExtent = 0;
  Rect? _lastHeaderContentRect;
  Rect? _lastRefreshContentRect;
  double _fixedRefreshStart = 0;
  bool _performingViewportLayout = false;

  void _updateHeaderGeometry() {
    final host = _viewportConfiguration.controller.snapshot.keepAliveOwner;
    final headers = host._viewportHeaderOwners;
    if (headers == null && _headerExtent == 0 && _lastHeaderContentRect == null) return;
    var extent = 0.0;
    if (headers != null) {
      for (final index in headers.keys) {
        final child = host._mountedItemRender(index);
        if (child == null || !child.hasSize) continue;
        final data = child.parentData! as _ScrollViewportParentData;
        var preceding = 0.0;
        for (final before in headers.keys) {
          if (before >= index) continue;
          final prior = host._mountedItemRender(before);
          if (prior?.hasSize == true) preceding += _axis == Axis.vertical ? prior!.size.height : prior!.size.width;
        }
        data.viewportHeaderOffset = preceding;
        extent += _axis == Axis.vertical ? child.size.height : child.size.width;
      }
    }
    // 只在自己的布局阶段读取 Size，向刷新布局发布普通 Rect，避免跨父级读取 DebugSize。
    final full = super.contentViewportRect;
    final rect = headers == null
        ? null
        : _axis == Axis.vertical
        ? Rect.fromLTRB(full.left, math.min(full.bottom, full.top + extent), full.right, full.bottom)
        : Rect.fromLTRB(math.min(full.right, full.left + extent), full.top, full.right, full.bottom);
    if (extent == _headerExtent && rect == _lastHeaderContentRect) return;
    _headerExtent = extent;
    _lastHeaderContentRect = rect;
    _invalidateStickyResolution();
    host._refreshLink?.notifyViewportGeometry();
  }

  @override
  Rect get contentViewportRect => _lastHeaderContentRect ?? super.contentViewportRect;

  void _updateRefreshGeometry({bool layout = false}) {
    final link = _viewportConfiguration.controller.snapshot.keepAliveOwner._refreshLink;
    if (link == null) return;
    if (layout && !_hasStickyChild && !_requiresItemPaintOffsets && _headerExtent == 0) {
      _fixedRefreshStart = 0;
      if (_lastRefreshContentRect != null) {
        _lastRefreshContentRect = null;
        link.notifyViewportGeometry();
      }
      return;
    }
    final full = super.contentViewportRect;
    final vertical = _axis == Axis.vertical;
    final baseStart = vertical ? contentViewportRect.top : contentViewportRect.left;
    if (layout) _fixedRefreshStart = baseStart;
    if (layout && _requiresItemPaintOffsets) {
      // 只合并从顶部连续覆盖整条横轴的固定区域，悬浮按钮不挤占刷新位置。
      final fixed = <Rect>[];
      var child = firstChild;
      while (child != null) {
        if (_scrollDebugCountersEnabled) {
          _viewportConfiguration
              .controller
              .snapshot
              .keepAliveOwner
              ._debugCounters!
              .debugRefreshGeometryChildVisitCount++;
        }
        final data = child.parentData! as _ScrollViewportParentData;
        if (_isRetainedPositioned(child)) {
          final rect = data.offset & child.size;
          if (vertical
              ? rect.left <= full.left && rect.right >= full.right
              : rect.top <= full.top && rect.bottom >= full.bottom) {
            fixed.add(rect);
          }
        }
        child = data.nextSibling;
      }
      fixed.sort((a, b) => (vertical ? a.top : a.left).compareTo(vertical ? b.top : b.left));
      for (final rect in fixed) {
        if ((vertical ? rect.top : rect.left) > _fixedRefreshStart + precisionErrorTolerance) break;
        _fixedRefreshStart = math.max(_fixedRefreshStart, vertical ? rect.bottom : rect.right);
      }
    }
    var start = math.max(baseStart, _fixedRefreshStart);
    final sticky = _hasStickyChild ? _resolveSticky(_liveContentBounds().visibleStart) : null;
    if (sticky != null) {
      final rect = _childPresentationOffset(sticky.child, sticky) & sticky.child.size;
      start = math.max(start, vertical ? rect.bottom : rect.right);
    }
    final rect = start <= (vertical ? full.top : full.left)
        ? null
        : vertical
        ? Rect.fromLTRB(full.left, math.min(start, full.bottom), full.right, full.bottom)
        : Rect.fromLTRB(math.min(start, full.right), full.top, full.right, full.bottom);
    if (rect == _lastRefreshContentRect) return;
    // 刷新父级只读缓存，不能跨布局父级读取成员的 DebugSize。
    _lastRefreshContentRect = rect;
    link.notifyViewportGeometry();
    if (!layout) link.notifyContentLayout();
  }

  int _positionedPaintGeneration = 0;
  bool _skipOwnLayoutPaint = false;

  @override
  void performLayout() {
    _performingViewportLayout = true;
    try {
      do {
        super.performLayout();
      } while (_selectionGeometryObserver?.selectionLayoutChanged() == true);
      _updateHeaderGeometry();
      _updateRefreshGeometry(layout: true);
    } finally {
      _performingViewportLayout = false;
    }
    // 只记录成功返回的实际布局；不派业务回调，也不因观察需要主动触发布局。
    _viewportConfiguration.controller.snapshot.keepAliveOwner._layoutRevision++;

    // Flutter 在 performLayout 返回后补一次自身 markNeedsPaint；它不是
    // 定位成员的内容失效。成员在本轮内发起的标脏仍正常更新绘制代次。
    _skipOwnLayoutPaint = true;
  }

  @override
  void didChangeDevicePixelRatio() {
    _positionedPaintGeneration++;
    super.didChangeDevicePixelRatio();
  }

  int _positionedRunRevision = 0;
  int _positionedPaintPass = 0;
  Map<RenderBox, _PositionedPaintRun>? _positionedPaintRuns;

  @override
  void didChangeStackPresentation() {
    super.didChangeStackPresentation();
    // 层序列表会原位重排；只比较列表 identity 会保留旧 endIndex，绘制遍历可能无法前进。
    _positionedRunRevision++;
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    _windowMutation = true;
    try {
      super.insert(child, after: after);
    } finally {
      _windowMutation = false;
    }
    _positionedRunRevision++;
  }

  @override
  void move(RenderBox child, {RenderBox? after}) {
    super.move(child, after: after);
    _positionedRunRevision++;
  }

  @override
  void remove(RenderBox child) {
    _positionedPaintRuns?.remove(child)?.layer.layer = null;
    _windowMutation = true;
    try {
      super.remove(child);
    } finally {
      _windowMutation = false;
    }
    _positionedRunRevision++;
  }

  @override
  void dispose() {
    final runs = _positionedPaintRuns;
    if (runs != null) {
      for (final run in runs.values) {
        run.layer.layer = null;
      }
      runs.clear();
    }
    super.dispose();
  }

  @override
  void markNeedsPaint() {
    _semanticChildren = null;
    if (_skipOwnLayoutPaint) {
      _skipOwnLayoutPaint = false;
    } else {
      _positionedPaintGeneration++;
    }
    super.markNeedsPaint();
  }

  @override
  void markNeedsPaintForScroll() => super.markNeedsPaint();

  double _positionedExtentDelta = 0.0;

  bool _syncMountedPositionedRole(_ScrollViewportParentData data, SegmentPlan plan, SegmentSpec? segment) {
    final positioned = data.isPositionedForLayout;
    data.isViewportPositioned = positioned;
    _requiresItemPaintOffsets = _requiresItemPaintOffsets || positioned || data.relativeOffset != Offset.zero;
    if (segment is! StaticSegment) {
      if (positioned) {
        throw FlutterError('List/Grid 条目暂不支持脱离滚动流的 ElPositioned；可仅声明 zIndex，或将定位组件放入 ElScrollView.children。');
      }
      return false;
    }
    var changed = segment.updateMountedPositioned(positioned);
    if (changed) {
      _positionedRunRevision++;
      data.lastReportedExtent = null;
      _pendingExtentReports.remove(plan.rowOfItem(data.index));
    }
    if (positioned) {
      final row = plan.rowOfItem(data.index);
      final oldExtent = _extentIndex.extentOf(row);
      if (_extentIndex.updateMeasuredExtent(row, 0.0)) {
        _positionedExtentDelta -= oldExtent;
        changed = true;
      }
    }
    return changed;
  }

  void _syncStickyStackOrder(({RenderBox child, double clampedMain})? sticky) {
    final next = sticky?.child;
    if (identical(next, _stackStickyChild)) return;
    final previous = _stackStickyChild;
    _stackStickyChild = next;
    if (previous != null && identical(previous.parent, this)) setChildStackActivationOrder(previous, 0);
    if (next != null) setChildStackActivationOrder(next, 1);
  }

  Offset _childPresentationOffset(RenderBox child, ({RenderBox child, double clampedMain})? sticky) {
    final data = child.parentData! as _ScrollViewportParentData;
    if (data.isViewportPositioned || data.isChrome) return data.offset;
    if (data.isViewportHeader) {
      return _axis == Axis.vertical
          ? Offset(data.offset.dx, data.viewportHeaderOffset)
          : Offset(data.viewportHeaderOffset, data.offset.dy);
    }
    return _childFlowOffset(child, data, sticky) +
        (identical(child, sticky?.child) ? boundedContentPaintOffset : contentPaintOffset);
  }

  Offset _childFlowOffset(
    RenderBox child,
    _ScrollViewportParentData data,
    ({RenderBox child, double clampedMain})? sticky,
  ) {
    var offset = identical(child, sticky?.child)
        ? (_axis == Axis.vertical
              ? Offset(data.offset.dx, sticky!.clampedMain)
              : Offset(sticky!.clampedMain, data.offset.dy))
        : data.offset;
    if (data.relativeOffset != Offset.zero) offset += data.relativeOffset;
    return offset;
  }

  bool _presentsChild(RenderBox child, double start, double end, RenderBox? sticky) {
    final data = child.parentData! as _ScrollViewportParentData;
    return data.zIndex >= 0 &&
        (data.isChrome ||
            data.isViewportPositioned ||
            data.isViewportHeader ||
            identical(child, sticky) ||
            _childIntersectsContentRange(child, start, end));
  }

  bool _isRetainedPositioned(RenderBox child) {
    final data = child.parentData! as _ScrollViewportParentData;
    return data.isViewportPositioned && !data.isChrome && data.zIndex >= 0;
  }

  _ScrollStretch? get _activeStretch {
    final effect = _viewportConfiguration.controller.snapshot.keepAliveOwner._stretch;
    return effect?.active == true ? effect : null;
  }

  bool _protectsBoundary(RenderBox child, RenderBox? sticky) {
    final data = child.parentData! as _ScrollViewportParentData;
    return data.isChrome || data.isViewportPositioned || data.isViewportHeader || identical(child, sticky);
  }

  void _paintBodySegments(
    PaintingContext context,
    Offset offset,
    _ScrollStretch? effect,
    ({RenderBox child, double clampedMain})? sticky,
    double start,
    double end,
  ) {
    final ordered = explicitStackPaintOrder;
    var index = 0;
    RenderBox? current = ordered == null ? firstChild : (ordered.isEmpty ? null : ordered.first);
    RenderBox? next(RenderBox child) => ordered == null
        ? (child.parentData! as _ScrollViewportParentData).nextSibling
        : (++index < ordered.length ? ordered[index] : null);
    while (current != null) {
      final boundaryChild = current!;
      if (_protectsBoundary(boundaryChild, sticky?.child)) {
        if (_presentsChild(boundaryChild, start, end, sticky?.child)) {
          context.paintChild(boundaryChild, offset + _childPresentationOffset(boundaryChild, sticky));
          if (_scrollDebugCountersEnabled) _debugLastPaintedChildCount++;
        }
        current = next(boundaryChild);
      } else {
        // 保持共享堆叠顺序；每段连续正文共用一次装饰，不为普通行增加包装。
        void paintRun(PaintingContext inner, Offset origin) {
          while (current != null && !_protectsBoundary(current!, sticky?.child)) {
            final child = current!;
            if (_presentsChild(child, start, end, sticky?.child)) {
              inner.paintChild(child, origin + _childPresentationOffset(child, sticky));
              if (_scrollDebugCountersEnabled) _debugLastPaintedChildCount++;
            }
            current = next(child);
          }
        }

        void decorate(PaintingContext inner, Offset origin) {
          if (effect == null) {
            paintRun(inner, origin);
          } else {
            effect.paint(inner, origin, size, paintRun);
          }
        }

        if (_headerExtent == 0) {
          decorate(context, offset);
        } else {
          context.pushClipRect(needsCompositing, offset, contentViewportRect, decorate);
        }
      }
    }
  }

  ({int start, int end})? _indexedPresentationRange(double start, double end) {
    if (_requiresItemPaintOffsets ||
        _hasStickyChild ||
        _headerExtent != 0 ||
        explicitStackPaintOrder != null ||
        !_layoutMetricsValid ||
        _reportMeasuredExtentsWhenUnchanged ||
        _extentIndex.measuredCount != _extentIndex.count) {
      return null;
    }
    final plan = _sectionPlan;
    final first = _extentIndex.rowAtContentOffset(start - _mainLeadingPadding);
    final last = _extentIndex.rowAtContentOffset(end - _mainLeadingPadding, startAtOrAfter: true);
    return (
      start: first >= plan.totalRowCount ? plan.totalItemCount : plan.firstItemOfRow(first),
      end: last >= plan.totalRowCount ? plan.totalItemCount : plan.firstItemOfRow(last),
    );
  }

  void _visitIndexedPresentationRange(({int start, int end}) range, RenderObjectVisitor visitor) {
    for (var index = range.start; index < range.end; index++) {
      final child = _renderChildForIndex(index);
      if (child != null) visitor(child);
    }
    for (final element in _viewportConfiguration.controller._element?._chromeChildren ?? <Element?>[]) {
      final child = element?.renderObject;
      if (child != null) visitor(child);
    }
  }

  @override
  void paintViewportChildren(PaintingContext context, Offset offset) {
    recordPaintedScrollOffset();
    syncStackOverflowForPaint(deferGeometry: clipsHitBounds);
    if (_scrollDebugCountersEnabled) _debugLastPaintedChildCount = 0;
    final bounds = _liveContentBounds();
    _checkVisibleUnderflowForBounds(bounds.visibleEnd);
    final sticky = _resolveSticky(bounds.visibleStart);
    final stretch = _activeStretch;
    if (stretch != null || _headerExtent > 0) {
      _paintBodySegments(context, offset, stretch, sticky, bounds.visibleStart, bounds.visibleEnd);
      return;
    }
    final ordered = explicitStackPaintOrder;
    // 公共平移每次绘制只合成一次，普通行不额外分配中间 Offset。
    final flowPaintOffset = offset + contentPaintOffset;
    if (ordered == null && !hasHiddenStackChildren && !_requiresItemPaintOffsets && sticky == null) {
      final runs = _positionedPaintRuns;
      if (runs != null) {
        for (final run in runs.values) {
          run.layer.layer = null;
        }
        _positionedPaintRuns = null;
      }
      final indexed = _indexedPresentationRange(bounds.visibleStart, bounds.visibleEnd);
      void paintChild(RenderObject render) {
        final child = render as RenderBox;
        if (_scrollDebugCountersEnabled) {
          _viewportConfiguration.controller.snapshot.keepAliveOwner._debugCounters!.debugPaintCandidateVisitCount++;
        }
        final data = child.parentData! as _ScrollViewportParentData;
        if (data.isChrome || _childIntersectsContentRange(child, bounds.visibleStart, bounds.visibleEnd)) {
          context.paintChild(child, data.isChrome ? offset + data.offset : flowPaintOffset + data.offset);
          if (_scrollDebugCountersEnabled) _debugLastPaintedChildCount++;
        }
      }

      if (indexed != null) {
        _visitIndexedPresentationRange(indexed, paintChild);
      } else {
        var child = _firstBusinessChild();
        while (child != null) {
          paintChild(child);
          child = (child.parentData! as _ScrollViewportParentData).nextSibling;
        }
      }
      return;
    }
    final paintPass = ++_positionedPaintPass;
    var usedRuns = 0;
    var index = 0;
    RenderBox? child = ordered == null ? firstChild : (ordered.isEmpty ? null : ordered.first);
    while (child != null) {
      if (_isRetainedPositioned(child)) {
        final runs = _positionedPaintRuns ??= <RenderBox, _PositionedPaintRun>{};
        final run = runs[child] ??= _PositionedPaintRun();
        run.lastPaintPass = paintPass;
        usedRuns++;
        if (run.revision != _positionedRunRevision || !identical(run.ordering, ordered)) {
          var last = child;
          var endIndex = index;
          var count = 1;
          var sameMembers = run.members.isNotEmpty && identical(run.members.first, child);
          while (true) {
            final next = ordered == null
                ? (last.parentData! as _ScrollViewportParentData).nextSibling
                : (endIndex + 1 < ordered.length ? ordered[endIndex + 1] : null);
            if (next == null || !_isRetainedPositioned(next)) break;
            if (count >= run.members.length || !identical(run.members[count], next)) sameMembers = false;
            last = next;
            endIndex++;
            count++;
          }
          run
            ..last = last
            ..endIndex = endIndex
            ..count = count
            ..ordering = ordered
            ..revision = _positionedRunRevision;
          if (!sameMembers || count != run.members.length) {
            run.generation = -1;
            run.members.clear();
            var member = child;
            var memberIndex = index;
            while (true) {
              run.members.add(member);
              if (identical(member, last)) break;
              member = ordered == null
                  ? (member.parentData! as _ScrollViewportParentData).nextSibling!
                  : ordered[++memberIndex];
            }
          }
        }
        final layer = run.layer.layer ??= OffsetLayer();
        if (run.generation != _positionedPaintGeneration) {
          layer.removeAllChildren();
          final retained = _PositionedPaintContext(layer, context.estimatedBounds.shift(-offset));
          var current = child;
          var currentIndex = index;
          while (true) {
            retained.paintChild(current, _childPresentationOffset(current, sticky));
            if (identical(current, run.last)) break;
            current = ordered == null
                ? (current.parentData! as _ScrollViewportParentData).nextSibling!
                : ordered[++currentIndex];
          }
          retained.finish();
          run.generation = _positionedPaintGeneration;
        }
        layer.offset = offset;
        context.addLayer(layer);
        if (_scrollDebugCountersEnabled) _debugLastPaintedChildCount += run.count;
        index = run.endIndex + 1;
        child = ordered == null
            ? (run.last!.parentData! as _ScrollViewportParentData).nextSibling
            : (index < ordered.length ? ordered[index] : null);
        continue;
      }
      if (_presentsChild(child, bounds.visibleStart, bounds.visibleEnd, sticky?.child)) {
        final data = child.parentData! as _ScrollViewportParentData;
        context.paintChild(
          child,
          identical(child, sticky?.child)
              ? offset + _childPresentationOffset(child, sticky)
              : data.isChrome || data.isViewportPositioned
              ? offset + data.offset
              : flowPaintOffset + _childFlowOffset(child, data, sticky),
        );
        if (_scrollDebugCountersEnabled) _debugLastPaintedChildCount++;
      }
      index++;
      child = ordered == null
          ? (child.parentData! as _ScrollViewportParentData).nextSibling
          : (index < ordered.length ? ordered[index] : null);
    }
    final runs = _positionedPaintRuns;
    if (runs != null && runs.length != usedRuns) {
      runs.removeWhere((child, run) {
        if (run.lastPaintPass == paintPass) return false;
        run.layer.layer = null;
        return true;
      });
    }
  }

  /// 计算 mounted 里当前应钉住的 sticky child 与钳制后的主轴 offset。
  /// 沿布局主轴解析，反向滚动由可见坐标的归一化统一处理。
  /// 结果按 (layout 代, visibleStart) 缓存，无 sticky 时零成本早退。
  ({RenderBox child, double clampedMain})? _resolveSticky(double visibleStart) {
    if (_stickyResolutionCacheValid && _stickyResolutionCacheStart == visibleStart) {
      return _stickyResolutionCache;
    }
    _stickyResolutionCacheValid = true;
    _stickyResolutionCacheStart = visibleStart;
    return _stickyResolutionCache = _computeStickyResolution(visibleStart);
  }

  ({RenderBox child, double clampedMain})? _computeStickyResolution(double visibleStart) {
    if (!_hasStickyChild) return null;
    // 找 last-sticky-with(natural-start <= visibleContentStart + 自身偏移)
    // （"当前钉住"），与其后第一个 sticky（"下一个"，用于接力推挤）。
    // 单钉 + 接力：异质 offset 不做重叠堆叠，与 State 侧
    // [_computePinnedStickyIndex] 同口径。
    //
    // 主轴四方向通用：mounted offset 与 visibleStart 都是内容口径（布局
    // 恒正向、reverse 只翻像素锚定端），判据对 horizontal / reverse 天然
    // 成立；钉靠边恒为主轴视觉首边（vertical → 顶、horizontal → 左缘）。
    final isVertical = _axis == Axis.vertical;
    // 钉靠基线 = 主轴视觉首边 + leading padding（simple 时代同口径：
    // `sticky: 0` 钉在 padding 内缘而非视口裸边）。行自然位含 leading
    // padding，判据两侧同减才对称。
    final leadingPadding = _mainLeadingPadding;
    RenderBox? currentSticky;
    double? currentNaturalStart;
    double currentStickyOffset = 0;
    double? nextNaturalStart;
    var child = _firstBusinessChild();
    while (child != null) {
      final parentData = child.parentData! as _ScrollViewportParentData;
      final stickyOffset = parentData.stickyOffset == null ? null : parentData.stickyOffset! + _headerExtent;
      if (stickyOffset != null && child.hasSize) {
        final naturalStart = isVertical ? parentData.offset.dy : parentData.offset.dx;
        if (naturalStart - leadingPadding <= visibleStart + stickyOffset + precisionErrorTolerance) {
          currentSticky = child;
          currentNaturalStart = naturalStart;
          currentStickyOffset = stickyOffset;
        } else if (currentSticky != null) {
          nextNaturalStart = naturalStart;
          break;
        }
      }
      child = parentData.nextSibling;
    }
    if (currentSticky == null || currentNaturalStart == null) return null;
    final stickyExtent = isVertical ? currentSticky.size.height : currentSticky.size.width;
    // 钳制主轴 offset：钉在 visibleContentStart + 吸附偏移；
    // 若下一个 sticky 逼近则被推向首边。
    var clampedMain = visibleStart + leadingPadding + currentStickyOffset;
    if (nextNaturalStart != null) {
      final pushLimit = nextNaturalStart - stickyExtent;
      if (pushLimit < clampedMain) clampedMain = pushLimit;
    }
    // 自然位置在钳制位之前时（还没滚到该钉的位置）直接用自然位置。
    if (currentNaturalStart > clampedMain) clampedMain = currentNaturalStart;
    return (child: currentSticky, clampedMain: clampedMain);
  }

  List<RenderBox>? _semanticChildren;
  double? _semanticStart;
  double? _semanticEnd;
  int _debugSemanticCandidateScans = 0;

  /// 语义候选全量筛选次数，用于验证外部平移不会逐帧扫描完整滚动内容。
  @visibleForTesting
  int get debugSemanticCandidateScans => _debugSemanticCandidateScans;

  // 外部路由变换不改变视口内的候选集；debug 语义校验也会遍历这里，不能每次重扫所有行。
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (excludeSemantics) return;
    final bounds = _liveContentBounds();
    var children = _semanticChildren;
    if (children == null || _semanticStart != bounds.semanticStart || _semanticEnd != bounds.semanticEnd) {
      if (_scrollDebugCountersEnabled) _debugSemanticCandidateScans++;
      _semanticStart = bounds.semanticStart;
      _semanticEnd = bounds.semanticEnd;
      final sticky = _resolveSticky(bounds.visibleStart);
      final candidates = <RenderBox>[];
      void visit(RenderObject child) {
        if (_presentsChild(child as RenderBox, bounds.semanticStart, bounds.semanticEnd, sticky?.child)) {
          candidates.add(child);
        }
      }

      final indexed = _indexedPresentationRange(bounds.semanticStart, bounds.semanticEnd);
      if (indexed == null) {
        visitStackChildrenInPaintOrder(visit);
      } else {
        _visitIndexedPresentationRange(indexed, visit);
      }
      children = _semanticChildren = candidates;
    }
    for (final child in children) {
      visitor(child);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_scrollDebugCountersEnabled) _debugLastHitTestChildCount = 0;
    final bounds = _liveContentBounds();
    final sticky = _resolveSticky(bounds.visibleStart);
    bool hitChild(RenderBox child) {
      final data = child.parentData! as _ScrollViewportParentData;
      if (suppressesContentHits &&
          !data.isChrome &&
          !data.isViewportPositioned &&
          !data.isViewportHeader &&
          !identical(child, sticky?.child) &&
          !_retainsNestedFlingReceiver(child, position)) {
        return false;
      }
      if (_headerExtent > 0 && !_protectsBoundary(child, sticky?.child) && !contentViewportRect.contains(position)) {
        return false;
      }
      if (!_presentsChild(child, bounds.visibleStart, bounds.visibleEnd, sticky?.child)) return false;
      if (_scrollDebugCountersEnabled) _debugLastHitTestChildCount++;
      final stretch = _activeStretch;
      final hit = stretch != null && !_protectsBoundary(child, sticky?.child) && !ui.ImageFilter.isShaderFilterSupported
          ? result.addWithPaintTransform(
              transform: stretch.matrix(size)
                ..translateByDouble(
                  _childPresentationOffset(child, sticky).dx,
                  _childPresentationOffset(child, sticky).dy,
                  0,
                  1,
                ),
              position: position,
              hitTest: (result, transformed) => child.hitTest(result, position: transformed),
            )
          : result.addWithPaintOffset(
              offset: _childPresentationOffset(child, sticky),
              position: position,
              hitTest: (result, transformed) => child.hitTest(result, position: transformed),
            );
      return hit || hitTestStackOverflowForChild(result, position: position, child: child);
    }

    final indexed = _indexedPresentationRange(bounds.visibleStart, bounds.visibleEnd);
    if (indexed != null) {
      final chrome = _viewportConfiguration.controller._element?._chromeChildren ?? <Element?>[];
      for (var i = chrome.length - 1; i >= 0; i--) {
        final child = chrome[i]?.renderObject;
        if (child is RenderBox && hitChild(child)) return true;
      }
      for (var index = indexed.end - 1; index >= indexed.start; index--) {
        final child = _renderChildForIndex(index);
        if (child != null && hitChild(child)) return true;
      }
      return false;
    }
    final ordered = explicitStackPaintOrder;
    if (ordered != null) {
      for (var index = ordered.length - 1; index >= 0; index--) {
        if (hitChild(ordered[index])) return true;
      }
    } else {
      var child = lastChild;
      while (child != null) {
        if (hitChild(child)) return true;
        child = (child.parentData! as _ScrollViewportParentData).previousSibling;
      }
    }
    return false;
  }

  bool _retainsNestedFlingReceiver(RenderBox child, Offset point) {
    // 祖先只屏蔽内容动作，不能抹掉仍须接住下一手势的内层滚动接收者。
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    final activity = position.activity;
    if (activity is! _RouteBallisticActivity) return false;
    final target = activity.route.source._activeMixinViewportRenderObject();
    if (target == null || !target.containsGlobalPosition(localToGlobal(point))) return false;
    for (RenderObject? node = target; node != null; node = node.parent) {
      if (identical(node, child)) return true;
    }
    return false;
  }

  @override
  void recordLayoutPositionCorrection(Axis axis, double pixelsDelta) {
    _viewportConfiguration.controller.snapshot.keepAliveOwner._recordMixinLayoutCorrection(axis, pixelsDelta);
  }

  @override
  void visitSelectionChildrenInPaintOrder(RenderObjectVisitor visitor) {
    visitStackChildrenInPaintOrder((child) {
      final data = child.parentData! as _ScrollViewportParentData;
      if (!data.isChrome) visitor(child);
    });
  }

  bool _childIntersectsContentRange(RenderBox child, double start, double end) {
    if (!child.hasSize) return false;
    final data = child.parentData! as _ScrollViewportParentData;
    final mainStart = _axis == Axis.vertical ? data.offset.dy : data.offset.dx;
    final extent = _axis == Axis.vertical ? child.size.height : child.size.width;
    return mainStart + extent > start + precisionErrorTolerance && mainStart < end - precisionErrorTolerance;
  }

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    final bounds = _liveContentBounds();
    final sticky = _resolveSticky(bounds.visibleStart);
    visitStackChildrenInPaintOrder((child) {
      if (_presentsChild(child as RenderBox, bounds.visibleStart, bounds.visibleEnd, sticky?.child)) {
        visitor(child, _childPresentationOffset(child, sticky));
      }
    });
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final stretch = _activeStretch;
    final sticky = _resolveSticky(_liveContentBounds().visibleStart);
    if (stretch != null && !_protectsBoundary(child, sticky?.child) && !ui.ImageFilter.isShaderFilterSupported) {
      transform.multiply(stretch.matrix(size));
    }
    final offset = _childPresentationOffset(child, sticky);
    transform.translateByDouble(offset.dx, offset.dy, 0.0, 1.0);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _headerExtent > 0 &&
          !_protectsBoundary(child as RenderBox, _resolveSticky(_liveContentBounds().visibleStart)?.child)
      ? contentViewportRect
      : super.describeApproximatePaintClip(child);
}
