// ignore_for_file: prefer_initializing_formals

part of 'table.dart';

/// 表格网格几何引擎（包内部，不进公开导出面）。
///
/// 单真值多投影模型：全表只有一份横向滚动偏移 h（来自唯一的横向
/// [ScrollController]），行原语 [_TableGridRow] 在 paint 期按 h 做三带投影：
/// - shell 形态（行在双轴滚动壳内）：壳整体平移 -h，冻结带反向 +h 钉回
///   viewport 边缘（浏览器 position: sticky 的同款手法）；
/// - selfShift 形态（壳外的表头/固定行/合计行）：mid 段自画 -h、冻结带钉原位。
///
/// 列宽是**一次解析、N 行共享**的计算值（[_TableGridLayout]），行内不再做
/// per-row flex 协商；行高 = max(cell 高)，动态行高与冻结列天然对齐。

/// 列几何解析输入：视觉序列（左冻结列在前、右冻结列在后）的列规格。
class _TableGridSpec {
  _TableGridSpec({
    required this.columns,
    required this.leftCount,
    required this.rightCount,
    required this.columnMinWidth,
    required this.forcedWidth,
    this.resizeOverrides,
  });

  /// **视觉序**列列表（调用方已把 fixed 列移到两端）。
  final List<ElTableColumn> columns;

  /// 视觉序头部的左冻结列数。
  final int leftCount;

  /// 视觉序尾部的右冻结列数。
  final int rightCount;

  /// 未声明宽度的列的兜底最小宽。
  final double columnMinWidth;

  /// 定宽模式（scrollX / 分栏）：列宽 = width ?? minWidth ?? columnMinWidth，
  /// 不参与弹性分配；false 时按 flex 权重分配有界宽。
  final bool forcedWidth;

  /// 已提交的列宽覆盖（**视觉列号** → 宽）：拖拽调宽 / 受控 columnWidths。
  /// 命中的列按该宽定宽解析（不参与弹性分配），优先于列声明的
  /// width / minWidth。
  final Map<int, double>? resizeOverrides;

  /// 内容等价判定：列几何输入不变则解析结果必然不变。
  bool contentEquals(_TableGridSpec other) {
    if (leftCount != other.leftCount ||
        rightCount != other.rightCount ||
        columnMinWidth != other.columnMinWidth ||
        forcedWidth != other.forcedWidth ||
        columns.length != other.columns.length) {
      return false;
    }
    final ao = resizeOverrides;
    final bo = other.resizeOverrides;
    if ((ao?.length ?? 0) != (bo?.length ?? 0)) return false;
    if (ao != null && bo != null) {
      for (final entry in ao.entries) {
        if (bo[entry.key] != entry.value) return false;
      }
    }
    for (var i = 0; i < columns.length; i++) {
      final a = columns[i];
      final b = other.columns[i];
      if (!identical(a, b) && (a.width != b.width || a.minWidth != b.minWidth || a.flex != b.flex)) return false;
    }
    return true;
  }
}

/// 列几何解析结果：视觉序列宽 + 前缀偏移 + 三带宽度。
class _TableGridLayout {
  _TableGridLayout._(this.widths, this.prefixes, this.leftCount, this.rightCount);

  /// 视觉序各列宽。
  final Float64List widths;

  /// 视觉序前缀偏移，长度 = 列数 + 1，`prefixes.last == totalW`。
  final Float64List prefixes;

  final int leftCount;
  final int rightCount;

  double get totalW => prefixes.isEmpty ? 0.0 : prefixes[prefixes.length - 1];

  double get leftW => prefixes.isEmpty ? 0.0 : prefixes[leftCount];

  double get rightW => totalW - (widths.isEmpty ? 0.0 : prefixes[widths.length - rightCount]);

  int get columnCount => widths.length;

  /// mid 段（非冻结列）的视觉下标区间 [leftCount, columnCount - rightCount)。
  int get midStart => leftCount;

  int get midEnd => columnCount - rightCount;

  /// 内容坐标窗口 [x0, x1) 命中的 mid 列区间（列虚拟化 v1 的窗口推导）。
  /// 返回 (startIndex, endIndexExclusive)；无交集返回 (midStart, midStart)。
  (int, int) midRangeFor(double x0, double x1) {
    var lo = midStart;
    var hi = midEnd;
    if (lo >= hi) return (lo, lo);
    // start：第一个右边缘 > x0 的列。
    var a = lo, b = hi;
    while (a < b) {
      final m = (a + b) >> 1;
      if (prefixes[m + 1] > x0) {
        b = m;
      } else {
        a = m + 1;
      }
    }
    final start = a;
    // end：第一个左边缘 >= x1 的列。
    a = start;
    b = hi;
    while (a < b) {
      final m = (a + b) >> 1;
      if (prefixes[m] >= x1) {
        b = m;
      } else {
        a = m + 1;
      }
    }
    return (start, a);
  }

  /// 解析列几何。[maxWidth] 为有界可用宽（弹性模式的分配基数；定宽模式忽略）。
  ///
  /// [live] 为拖拽进行中的列宽覆盖（视觉列号 → 宽），优先于
  /// [_TableGridSpec.resizeOverrides]（已提交覆盖）。
  static _TableGridLayout resolve(_TableGridSpec spec, double maxWidth, {Map<int, double>? live}) {
    final cols = spec.columns;
    final n = cols.length;
    final widths = Float64List(n);
    final committed = spec.resizeOverrides;
    double? overrideOf(int i) => live?[i] ?? committed?[i];
    if (spec.forcedWidth) {
      for (var i = 0; i < n; i++) {
        final c = cols[i];
        widths[i] = overrideOf(i) ?? c.width ?? c.minWidth ?? spec.columnMinWidth;
      }
    } else {
      // 弹性分配：固定宽列（含覆盖列）先扣除，其余按 flex 权重分配剩余宽、
      // minWidth 兜底。迭代收敛：分到低于 min 的列钉在 min 上退出分配池，
      // 余量重分。
      var remaining = maxWidth.isFinite ? maxWidth : 0.0;
      var flexTotal = 0.0;
      final flexIdx = <int>[];
      for (var i = 0; i < n; i++) {
        final c = cols[i];
        final ow = overrideOf(i);
        if (ow != null) {
          widths[i] = ow;
          remaining -= ow;
        } else if (c.width != null) {
          widths[i] = c.width!;
          remaining -= c.width!;
        } else {
          flexIdx.add(i);
          flexTotal += c.flex ?? 1;
        }
      }
      remaining = math.max(remaining, 0.0);
      final pending = List.of(flexIdx);
      var pool = remaining;
      var poolFlex = flexTotal;
      var changed = true;
      while (changed && pending.isNotEmpty) {
        changed = false;
        for (var k = pending.length - 1; k >= 0; k--) {
          final i = pending[k];
          final c = cols[i];
          final min = c.minWidth ?? spec.columnMinWidth;
          final weight = c.flex ?? 1;
          final share = poolFlex > 0 ? pool * weight / poolFlex : 0.0;
          if (share < min) {
            widths[i] = min;
            pool = math.max(pool - min, 0.0);
            poolFlex -= weight;
            pending.removeAt(k);
            changed = true;
          }
        }
      }
      for (final i in pending) {
        final c = cols[i];
        final weight = c.flex ?? 1;
        widths[i] = poolFlex > 0 ? pool * weight / poolFlex : (c.minWidth ?? spec.columnMinWidth);
      }
    }
    final prefixes = Float64List(n + 1);
    var acc = 0.0;
    for (var i = 0; i < n; i++) {
      prefixes[i] = acc;
      acc += widths[i];
    }
    prefixes[n] = acc;
    return _TableGridLayout._(widths, prefixes, spec.leftCount, spec.rightCount);
  }

  bool geometryEquals(_TableGridLayout other) {
    if (leftCount != other.leftCount || rightCount != other.rightCount || widths.length != other.widths.length) {
      return false;
    }
    for (var i = 0; i < widths.length; i++) {
      if (widths[i] != other.widths[i]) return false;
    }
    return true;
  }
}

/// 表格网格协调器：State 持有，发布列几何与横向滚动单真值。
///
/// - [spec] 每 build 由表格 State 刷新（内容等价则不换代）；
/// - 列几何在**layout 期**由首个拿到有界宽的行（ruler / 表头）解析并缓存；
/// - 横向偏移变化只对**登记过的投影行**（含冻结列 / selfShift）
///   `markNeedsPaint`——无 setState、无 build、无同步链。
class _TableGridCoordinator {
  _TableGridSpec? _spec;
  int _generation = 0;

  _TableGridLayout? _layout;
  int _layoutGeneration = -1;
  double _layoutMaxWidth = -1.0;

  /// selfShift / ruler 行发布的有界行宽（= 表格 viewport 宽）。
  double viewportW = 0.0;

  /// 定宽口径总列宽 Σ(width ?? minWidth ?? columnMinWidth)，按代缓存。
  double _forcedTotal = 0.0;
  int _forcedTotalGeneration = -1;

  bool _hOverflow = false;

  /// 列总宽是否超出可用宽（layout 期判定）。表格 State 据此自动开横滚。
  bool get hOverflow => _hOverflow;

  /// 溢出事实翻转通知（表格 State 注入）。layout 期禁止同步 setState，
  /// 故经 post-frame 回调递交，State 侧自带 mounted 守卫。
  VoidCallback? onHOverflowChanged;

  bool _overflowNotifyScheduled = false;

  ScrollController? _hCtrl;

  final Set<_RenderTableGridRow> _followers = <_RenderTableGridRow>{};

  /// 全部已挂载行（含 plain / ruler）：列几何换代时逐行失效布局的通知面。
  final Set<_RenderTableGridRow> _rows = <_RenderTableGridRow>{};

  /// 测试探针：横向滚动触发稀疏列窗口换页的累计次数。
  int debugSparseWindowResetCount = 0;

  /// 测试探针：当前登记的横向投影跟随行数。
  int get debugFollowerCount => _followers.length;

  set spec(_TableGridSpec value) {
    final old = _spec;
    if (old != null && old.contentEquals(value)) {
      _spec = value;
      return;
    }
    _spec = value;
    // 列几何换代：存量行的外部约束通常不变、不会自发 relayout，必须显式
    // 逐行失效，否则运行时改 width/minWidth/flex 后已挂载行保持旧列宽。
    _bumpGeometry();
  }

  /// 列几何换代 + 全部挂载行失效布局（spec 内容变化 / live 列宽变化共用）。
  void _bumpGeometry() {
    _generation++;
    for (final render in _rows) {
      render.markNeedsLayout();
    }
  }

  // ---- 列宽拖拽 live 通道（render 级，不经 setState / build） ----

  /// 拖拽进行中的列宽覆盖（视觉列号 → 宽）。spec 的 resizeOverrides 是
  /// 已提交状态，本表是提交前的实时值，解析时优先于 spec 覆盖——拖拽帧
  /// 只换代 + 逐行 relayout，零 widget 重建。
  final Map<int, double> _liveResize = <int, double>{};

  /// 开始列宽拖拽。返回该列当前解析宽（拖拽基准）；列几何尚未解析或
  /// 列号越界时返回 null（调用方放弃本次拖拽）。
  ///
  /// 弹性模式下把**全部**弹性列钉在当前解析宽（Excel / AG-Grid 口径，
  /// 2026-08-02 用户裁决）：拖拽只改被拖列，绝不挤压/拉伸其他列——左侧
  /// 钉宽保证被拖列左缘不漂移（边界跟手），右侧钉宽保证拖宽多出的宽度
  /// 直接进横向滚动余量而不是压缩邻列；拖窄则右侧留空隙（表格变窄）。
  /// 定宽模式下各列解析互不依赖，无需钉宽。
  double? beginColumnResize(int visualIndex) {
    final layout = this.layout;
    final spec = _spec;
    if (layout == null || spec == null || visualIndex < 0 || visualIndex >= layout.columnCount) return null;
    if (!spec.forcedWidth) {
      for (var i = 0; i < layout.columnCount; i++) {
        if (i == visualIndex) continue;
        final c = spec.columns[i];
        if (c.width == null && !_liveResize.containsKey(i) && !(spec.resizeOverrides?.containsKey(i) ?? false)) {
          _liveResize[i] = layout.widths[i];
        }
      }
    }
    return layout.widths[visualIndex];
  }

  /// 拖拽帧更新列宽（调用方已钳制下限）。
  void updateColumnResize(int visualIndex, double width) {
    if (_liveResize[visualIndex] == width) return;
    _liveResize[visualIndex] = width;
    _bumpGeometry();
  }

  /// 当前 live 覆盖快照（提交用，视觉列号键，含 begin 时钉住的弹性列）。
  Map<int, double> takeLiveResize() => Map.of(_liveResize);

  /// 清空 live 覆盖。提交路径下 spec 随后带同值覆盖、几何不变；
  /// 取消 / 受控未接受时行回弹到 spec 口径。
  void clearLiveResize() {
    if (_liveResize.isEmpty) return;
    _liveResize.clear();
    _bumpGeometry();
  }

  // ---- 表头换序 live 通道（render 级，整列同步位移） -----------------------

  static const Duration _columnReorderDuration = Duration(milliseconds: 130);

  int _reorderSourceStart = -1;
  int _reorderSourceEnd = -1;
  int _reorderTargetStart = -1;
  int _reorderTargetEnd = -1;
  double _reorderSourceOffset = 0.0;
  double _reorderSourceFrom = 0.0;
  double _reorderSourceTo = 0.0;
  bool _animateReorderSource = false;
  Map<int, double> _reorderOffsets = <int, double>{};
  Map<int, double> _reorderFrom = <int, double>{};
  Map<int, double> _reorderTo = <int, double>{};
  Ticker? _reorderTicker;
  VoidCallback? _reorderAnimationCompleted;

  bool get _columnReorderActive => _reorderSourceStart >= 0;

  /// 建立一次整列换序会话；[sourceStart]/[sourceEnd] 是视觉列半开区间。
  bool beginColumnReorder(int sourceStart, int sourceEnd) {
    final layout = this.layout;
    if (layout == null || sourceStart < 0 || sourceEnd <= sourceStart || sourceEnd > layout.columnCount) {
      return false;
    }
    clearColumnReorder();
    _reorderSourceStart = sourceStart;
    _reorderSourceEnd = sourceEnd;
    _reorderTargetStart = sourceStart;
    _reorderTargetEnd = sourceEnd;
    _markColumnReorderChanged();
    return true;
  }

  /// 更新指针跟手位移及当前目标列组，相邻整列会动画让出插入位置。
  void updateColumnReorder({required double sourceOffset, required int targetStart, required int targetEnd}) {
    final layout = this.layout;
    if (!_columnReorderActive || layout == null) return;
    _reorderSourceOffset = sourceOffset;
    final validTarget = targetStart >= 0 && targetEnd > targetStart && targetEnd <= layout.columnCount;
    final nextStart = validTarget ? targetStart : _reorderSourceStart;
    final nextEnd = validTarget ? targetEnd : _reorderSourceEnd;
    if (_reorderTargetStart != nextStart || _reorderTargetEnd != nextEnd) {
      _reorderTargetStart = nextStart;
      _reorderTargetEnd = nextEnd;
      final target = _columnReorderFinalOffsets(layout, nextStart, nextEnd).offsets;
      _startColumnReorderAnimation(target, animateSource: false);
    } else {
      _markColumnReorderChanged();
    }
  }

  /// 松手后把拖动列吸附到目标位置，动画结束再由上层提交真实列顺序。
  void settleColumnReorder(VoidCallback onCompleted) {
    final layout = this.layout;
    if (!_columnReorderActive || layout == null) {
      onCompleted();
      return;
    }
    final finalState = _columnReorderFinalOffsets(layout, _reorderTargetStart, _reorderTargetEnd);
    _startColumnReorderAnimation(
      finalState.offsets,
      sourceTarget: finalState.sourceOffset,
      animateSource: true,
      onCompleted: onCompleted,
    );
  }

  /// 取消换序时让全部列平滑回到原位。
  void cancelColumnReorder(VoidCallback onCompleted) {
    if (!_columnReorderActive) {
      onCompleted();
      return;
    }
    _startColumnReorderAnimation(
      const <int, double>{},
      sourceTarget: 0.0,
      animateSource: true,
      onCompleted: onCompleted,
    );
  }

  /// 立即清除换序投影；真实列顺序提交后的同帧切换使用它避免重影。
  void clearColumnReorder() {
    final hadState = _columnReorderActive || _reorderOffsets.isNotEmpty || _reorderSourceOffset != 0;
    _reorderTicker?.stop();
    _reorderAnimationCompleted = null;
    _reorderSourceStart = -1;
    _reorderSourceEnd = -1;
    _reorderTargetStart = -1;
    _reorderTargetEnd = -1;
    _reorderSourceOffset = 0.0;
    _reorderSourceFrom = 0.0;
    _reorderSourceTo = 0.0;
    _animateReorderSource = false;
    _reorderOffsets = <int, double>{};
    _reorderFrom = <int, double>{};
    _reorderTo = <int, double>{};
    if (hadState) _markColumnReorderChanged();
  }

  ({Map<int, double> offsets, double sourceOffset}) _columnReorderFinalOffsets(
    _TableGridLayout layout,
    int targetStart,
    int targetEnd,
  ) {
    final sourceStart = _reorderSourceStart;
    final sourceEnd = _reorderSourceEnd;
    if (targetStart == sourceStart && targetEnd == sourceEnd) {
      return (offsets: const <int, double>{}, sourceOffset: 0.0);
    }
    final sourceWidth = layout.prefixes[sourceEnd] - layout.prefixes[sourceStart];
    final offsets = <int, double>{};
    if (targetStart > sourceStart) {
      for (var index = sourceEnd; index < targetEnd; index++) {
        offsets[index] = -sourceWidth;
      }
      return (offsets: offsets, sourceOffset: layout.prefixes[targetEnd] - layout.prefixes[sourceEnd]);
    }
    if (targetStart < sourceStart) {
      for (var index = targetStart; index < sourceStart; index++) {
        offsets[index] = sourceWidth;
      }
      return (offsets: offsets, sourceOffset: layout.prefixes[targetStart] - layout.prefixes[sourceStart]);
    }
    return (offsets: const <int, double>{}, sourceOffset: 0.0);
  }

  void _startColumnReorderAnimation(
    Map<int, double> target, {
    double? sourceTarget,
    required bool animateSource,
    VoidCallback? onCompleted,
  }) {
    _reorderTicker?.stop();
    _reorderFrom = Map<int, double>.of(_reorderOffsets);
    _reorderTo = Map<int, double>.of(target);
    _reorderSourceFrom = _reorderSourceOffset;
    _reorderSourceTo = sourceTarget ?? _reorderSourceOffset;
    _animateReorderSource = animateSource;
    _reorderAnimationCompleted = onCompleted;
    _reorderTicker ??= Ticker(_tickColumnReorderAnimation);
    _reorderTicker!.start();
  }

  void _tickColumnReorderAnimation(Duration elapsed) {
    if (!_columnReorderActive) {
      _reorderTicker?.stop();
      return;
    }
    final raw = elapsed.inMicroseconds / _columnReorderDuration.inMicroseconds;
    final done = raw >= 1.0;
    final t = Curves.easeOutCubic.transform(raw.clamp(0.0, 1.0));
    final keys = <int>{..._reorderFrom.keys, ..._reorderTo.keys};
    final next = <int, double>{};
    for (final key in keys) {
      final value = ui.lerpDouble(_reorderFrom[key] ?? 0.0, _reorderTo[key] ?? 0.0, t)!;
      if (value.abs() > precisionErrorTolerance) next[key] = value;
    }
    _reorderOffsets = next;
    if (_animateReorderSource) {
      _reorderSourceOffset = ui.lerpDouble(_reorderSourceFrom, _reorderSourceTo, t)!;
    }
    _markColumnReorderChanged();
    if (!done) return;
    _reorderTicker?.stop();
    _reorderOffsets = Map<int, double>.of(_reorderTo);
    if (_animateReorderSource) _reorderSourceOffset = _reorderSourceTo;
    final completed = _reorderAnimationCompleted;
    _reorderAnimationCompleted = null;
    completed?.call();
  }

  double columnReorderOffset(int visualIndex) {
    if (!_columnReorderActive) return 0.0;
    if (visualIndex >= _reorderSourceStart && visualIndex < _reorderSourceEnd) {
      return _reorderSourceOffset;
    }
    return _reorderOffsets[visualIndex] ?? 0.0;
  }

  double columnReorderSpanOffset(int start, int end) {
    if (!_columnReorderActive || start >= end) return 0.0;
    final first = columnReorderOffset(start);
    for (var index = start + 1; index < end; index++) {
      if ((columnReorderOffset(index) - first).abs() > precisionErrorTolerance) return 0.0;
    }
    return first;
  }

  bool isColumnReorderSource(int visualIndex) =>
      _columnReorderActive && visualIndex >= _reorderSourceStart && visualIndex < _reorderSourceEnd;

  bool isColumnReorderSourceSpan(int start, int end) =>
      _columnReorderActive && start >= _reorderSourceStart && end <= _reorderSourceEnd;

  void _markColumnReorderChanged() {
    for (final render in _rows) {
      if (render._freezeAll || render._mode == _TableGridRowMode.ruler) continue;
      render
        ..markNeedsPaint()
        ..markNeedsSemanticsUpdate();
    }
  }

  /// 按 [_TableGridRow.resizeId] 找已挂载数据行（行高拖拽寻址）。
  /// O(挂载行数) 线性扫，拖拽帧频调用可接受。
  _RenderTableGridRow? rowById(Object id) {
    for (final render in _rows) {
      if (render.resizeId == id) return render;
    }
    return null;
  }

  /// 按全局坐标命中当前已挂载的数据行，表格据此复用一套行手势入口。
  ElTableRowContext? rowAtGlobalPosition(Offset position) {
    for (final render in _rows) {
      final row = render.interactionData;
      if (row == null || !render.attached || !render.hasSize) continue;
      if ((render.localToGlobal(Offset.zero) & render.size).contains(position)) return row;
    }
    return null;
  }

  /// 定宽口径总列宽（惰性算一次/代）。
  ///
  /// 溢出判据两模式数值恒等：flex 模式一旦溢出，全部 flex 列已钉在 min 上，
  /// 解析输出与定宽输出逐像素一致——判据只依赖 (spec, viewportW)，与当前
  /// 处于哪个模式无关，故 auto 横滚开/关不会互相触发形成振荡。
  double get forcedTotal {
    if (_forcedTotalGeneration == _generation) return _forcedTotal;
    final spec = _spec;
    var total = 0.0;
    if (spec != null) {
      final cols = spec.columns;
      for (var i = 0; i < cols.length; i++) {
        final c = cols[i];
        total += _liveResize[i] ?? spec.resizeOverrides?[i] ?? c.width ?? c.minWidth ?? spec.columnMinWidth;
      }
    }
    _forcedTotalGeneration = _generation;
    return _forcedTotal = total;
  }

  /// 按有界可用宽更新溢出事实；翻转时 post-frame 通知宿主 State。
  void _updateHOverflow(double maxWidth) {
    if (!maxWidth.isFinite) return;
    final next = forcedTotal > maxWidth + precisionErrorTolerance;
    if (next == _hOverflow) return;
    _hOverflow = next;
    final cb = onHOverflowChanged;
    if (cb == null || _overflowNotifyScheduled) return;
    _overflowNotifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _overflowNotifyScheduled = false;
      onHOverflowChanged?.call();
    });
  }

  /// 按有界宽解析（或复用）列几何。layout 期由行 render 调用。
  _TableGridLayout resolveFor(double maxWidth) {
    assert(_spec != null, '_TableGridCoordinator.spec 未设置——表格 State 必须在 build 期先发布列规格。');
    final cached = _layout;
    if (cached != null && _layoutGeneration == _generation && _layoutMaxWidth == maxWidth) return cached;
    final next = _TableGridLayout.resolve(_spec!, maxWidth, live: _liveResize.isEmpty ? null : _liveResize);
    _layoutGeneration = _generation;
    _layoutMaxWidth = maxWidth;
    if (cached != null && cached.geometryEquals(next)) return cached;
    return _layout = next;
  }

  /// 已解析的列几何。shell 形态行（无界宽）依赖 ruler / selfShift 行先行解析。
  _TableGridLayout? get layout => _layoutGeneration == _generation ? _layout : null;

  void attachHorizontal(ScrollController? ctrl) {
    if (identical(_hCtrl, ctrl)) return;
    _hCtrl?.removeListener(_handleHorizontalScroll);
    _hCtrl = ctrl;
    ctrl?.addListener(_handleHorizontalScroll);
  }

  /// 横向内容偏移单真值。position 未挂载时为 0。
  double get h {
    final ctrl = _hCtrl;
    if (ctrl == null || !ctrl.hasClients) return 0.0;
    return ctrl.position.pixels;
  }

  /// 横向最大滚动量；position 未就绪时按几何推导兜底。
  double get maxH {
    final ctrl = _hCtrl;
    if (ctrl != null && ctrl.hasClients && ctrl.position.hasContentDimensions) {
      return ctrl.position.maxScrollExtent;
    }
    final layout = _layout;
    if (layout == null) return 0.0;
    return math.max(layout.totalW - viewportW, 0.0);
  }

  _TableGridLayout? _visibleRangeLayout;
  double _visibleRangeH = double.nan;
  double _visibleRangeViewportW = double.nan;
  (int, int) _visibleMidRange = (0, 0);

  /// 全表共享的当前可见中段列区间，横滚一帧只做一次二分查找。
  (int, int) visibleMidRange(_TableGridLayout layout) {
    final offset = h;
    final width = viewportW;
    if (identical(_visibleRangeLayout, layout) && _visibleRangeH == offset && _visibleRangeViewportW == width) {
      return _visibleMidRange;
    }
    _visibleRangeLayout = layout;
    _visibleRangeH = offset;
    _visibleRangeViewportW = width;
    return _visibleMidRange = layout.midRangeFor(offset + layout.leftW, offset + width - layout.rightW);
  }

  // ---- 列虚拟化规范窗口（全表稀疏行共享，内容坐标） ----

  /// mid 窗口的缓冲半径（px）：可见区间两侧各多挂约 2-3 列，
  /// 逐像素滚动期间 paint 永远落在已挂载列上。
  static const double sparseBufferPx = 240.0;
  static const double _sparseTrailingBufferPx = 80.0;
  static const double _sparseLeadingBufferPx = sparseBufferPx * 2 - _sparseTrailingBufferPx;
  static const double _sparseSafetyPx = 40.0;
  static const double _sparseJumpBufferPx = 0.0;

  // x0 > x1 表示未初始化。
  double _winX0 = 1.0;
  double _winX1 = 0.0;

  // 窗口计算时的 viewportW：resize / 首帧发布后失效重算（首帧 ruler 缺席时
  // 窗口退化为全量，viewport 就位必须能收窄回来）。
  double _winBasis = -1.0;
  double _lastSparseH = double.nan;

  void _resetSparseWindow(double x0, double x1, double direction) {
    if (direction > 0) {
      _winX0 = x0 - _sparseTrailingBufferPx;
      _winX1 = x1 + _sparseLeadingBufferPx;
    } else if (direction < 0) {
      _winX0 = x0 - _sparseLeadingBufferPx;
      _winX1 = x1 + _sparseTrailingBufferPx;
    } else {
      _winX0 = x0 - sparseBufferPx;
      _winX1 = x1 + sparseBufferPx;
    }
  }

  void _resetSparseJumpWindow(double x0, double x1) {
    _winX0 = x0 - _sparseJumpBufferPx;
    _winX1 = x1 + _sparseJumpBufferPx;
  }

  /// 稀疏行 layout 期取规范窗口。可见区间逃出覆盖（跨窗迟滞未触发的硬边界）
  /// 或 viewport 变化时立即重算——同帧兜底，绝不画未挂载列。
  (double, double) sparseWindowX() {
    final vw = viewportW;
    final x0 = h;
    final x1 = x0 + (vw > 0 ? vw : double.maxFinite);
    if (_winX0 > _winX1 || _winBasis != vw || x0 < _winX0 || x1 > _winX1) {
      _winBasis = vw;
      _resetSparseWindow(x0, x1, 0);
      _lastSparseH = x0;
    }
    return (_winX0, _winX1);
  }

  void _handleHorizontalScroll() {
    // 跨窗判定：可见区间逃出规范窗口的内半区（迟滞 = buffer/2）→ 重置窗口
    // 并对稀疏行发起 relayout 补列/卸列；layout 早于 paint，同帧先补后绘。
    // 未逃逸时保持 paint-only（零 relayout）。
    if (_winX0 <= _winX1) {
      final x0 = h;
      final x1 = x0 + viewportW;
      final previous = _lastSparseH;
      _lastSparseH = x0;
      if (x0 < _winX0 + _sparseSafetyPx || x1 > _winX1 - _sparseSafetyPx) {
        debugSparseWindowResetCount++;
        _winBasis = viewportW;
        final delta = previous.isNaN ? 0.0 : x0 - previous;
        if (delta.abs() > viewportW * 0.75) {
          _resetSparseJumpWindow(x0, x1);
        } else {
          _resetSparseWindow(x0, x1, delta);
        }
        for (final render in _rows) {
          if (render._windowed) render.markNeedsLayout();
        }
      }
    }
    for (final render in _followers) {
      render.markNeedsPaint();
    }
  }

  void _register(_RenderTableGridRow render) => _followers.add(render);

  void _unregister(_RenderTableGridRow render) => _followers.remove(render);

  void _attachRow(_RenderTableGridRow render) => _rows.add(render);

  void _detachRow(_RenderTableGridRow render) {
    _followers.remove(render);
    _rows.remove(render);
  }

  void dispose() {
    _reorderTicker?.dispose();
    _reorderTicker = null;
    _reorderAnimationCompleted = null;
    _hCtrl?.removeListener(_handleHorizontalScroll);
    _hCtrl = null;
    onHOverflowChanged = null;
    _followers.clear();
    _rows.clear();
    _liveResize.clear();
    _winX0 = 1.0;
    _winX1 = 0.0;
    _winBasis = -1.0;
    _lastSparseH = double.nan;
    debugSparseWindowResetCount = 0;
    _visibleRangeLayout = null;
    _visibleRangeH = double.nan;
    _visibleRangeViewportW = double.nan;
  }
}

/// 行原语投影形态。
enum _TableGridRowMode {
  /// 无横滚表格的普通行：纯网格摆放，零投影机制。
  plain,

  /// 双轴/横向滚动壳内的行：壳平移 -h，冻结带 +h 反钉回 viewport 边缘。
  shell,

  /// 壳外的表头/固定行/合计行：mid 段自画 -h，冻结带钉原位。
  selfShift,

  /// 零高测量行：只负责在 layout 期解析列几何并发布 viewport 宽。
  ruler,
}

class _TableHostedCell {
  const _TableHostedCell(this.style, this.value);

  final ElStyle style;
  final Object? value;
}

typedef _TableHostedOrdinal = ({
  int totalRows,
  int firstNumber,
  int rowIndex,
  _IndexTextEnvironment environment,
  TextAlign textAlign,
});

// 行号也必须经过单元格盒模型，保证两种托管路径的内边距、背景和对齐一致。
class _RenderTableOrdinalCell extends RenderProxyBox {
  _RenderTableOrdinalCell(ElStyle style, this.gutter) {
    box = ElRenderView(style: style)..add(gutter);
    child = box;
  }

  final ElRenderOrdinalGutter gutter;
  late final ElRenderView box;

  @override
  void dispose() {
    child = null;
    box.remove(gutter);
    gutter.dispose();
    box.dispose();
    super.dispose();
  }
}

typedef _TableHostedCacheEntry = ({RenderBox render, _TableHostedCell cell});

typedef _TableHostedCellBuilder = _TableHostedCell? Function(int visualIndex);

class _TableGridCellSpan {
  const _TableGridCellSpan(this.start, this.end) : assert(start >= 0 && end > start);

  final int start;
  final int end;
}

/// 表格行原语：一行的全部单元格（含冻结列）在同一个 render 里布局。
///
/// 子模型三态：
/// - **托管**（[hostedCells]）：纯值单元格由行 render 直接持有 ElRenderView，
///   保留样式、文本和语义，但省去逐单元格 Widget/Element；
/// - **稠密**（[children]）：视觉序单元格全量挂载（左冻结、mid、右冻结）；
/// - **稀疏**（[cellBuilder] + [cellCount]，列级虚拟化）：layout 期只挂载
///   冻结带 + 规范 mid 窗口内的列，横滚跨窗增量补列/卸列——挂载集之外的列
///   没有 Element/RenderObject/semantics，滚出窗口的 cell 子树状态丢弃
///   （与行虚拟化同契约）。稀疏要求定高行（动态行高需全列实测，走稠密）。
///
/// 几何一律来自 [_TableGridCoordinator] 的共享解析——单元格样式不再声明宽度。
/// [freezeAll] = 整行冻结（展开详情行）：唯一子项按 viewport 宽布局并整体反钉。
class _TableGridRow extends RenderObjectWidget {
  const _TableGridRow({
    super.key,
    required this.coordinator,
    required this.mode,
    this.rowHeight,
    this.freezeAll = false,
    this.bandDividerColor,
    this.bandDividerWidth = 1.0,
    this.bandShadow,
    this.resizeId,
    this.interactionData,
    this.cellBuilder,
    this.cellCount,
    this.hostedCells,
    this.hostedCellBuilder,
    this.windowed = false,
    this.parentLayered = false,
    this.cellSpans,
    this.children = const [],
  }) : assert(cellBuilder == null || cellCount != null, '稀疏模式必须声明 cellCount（总视觉列数）。'),
       assert(cellBuilder == null || rowHeight != null, '列虚拟化行必须定高——动态行高需全列实测，走稠密 children。'),
       assert(cellBuilder == null || !freezeAll, '整行冻结只有唯一子项，不参与列虚拟化。'),
       assert(hostedCells == null || (cellBuilder == null && children.length == 0), '稠密托管单元格不能与 element 单元格混用。'),
       assert(hostedCellBuilder == null || cellBuilder != null, '稀疏托管必须与列虚拟化 builder 配套。'),
       assert(cellSpans == null || (cellBuilder == null && hostedCells == null), '跨列单元格只支持稠密 element 行。'),
       assert(cellSpans == null || cellSpans.length == children.length, '跨列范围必须与 children 一一对应。');

  final _TableGridCoordinator coordinator;
  final _TableGridRowMode mode;

  /// 稠密子（视觉序全量单元格）。[cellBuilder] 非 null 时忽略。
  final List<Widget> children;

  /// 稀疏懒建单元格（列级虚拟化）。非 null 时忽略 [children]，参数为视觉列号。
  final IndexedWidgetBuilder? cellBuilder;

  /// [cellBuilder] 的总视觉列数。
  final int? cellCount;

  /// 纯值单元格直接由行 render 托管，跳过逐单元格 Widget/Element 生命周期。
  final List<_TableHostedCell>? hostedCells;

  /// 稀疏窗口内的纯值单元格按列惰性托管，返回 null 时只为该列回退 element。
  final _TableHostedCellBuilder? hostedCellBuilder;

  /// 是否按横向窗口裁剪惰性 cell；false 时混合托管仍挂载全部视觉列。
  final bool windowed;

  /// 外层是否已经提供整行保留层。
  final bool parentLayered;

  /// 稠密子对应的视觉列半开区间；null 表示每个子只占一列。
  final List<_TableGridCellSpan>? cellSpans;

  /// 行高。null = 动态行高（行高 = max(cell 高)，两趟布局拉齐背景/边框）。
  final double? rowHeight;

  /// 整行冻结（展开详情行）。
  final bool freezeAll;

  /// 冻结带内缘分割线的字面色。
  final Color? bandDividerColor;

  final double bandDividerWidth;

  /// 冻结带在遮挡侧投出的阴影。
  final List<BoxShadow>? bandShadow;

  /// 行高拖拽寻址标识（数据行的 rowKey）。表格 State 经
  /// [_TableGridCoordinator.rowById] 找到本行 render 直写 live 行高。
  /// null = 本行不参与行高拖拽（表头 / 合计 / 未开启开关）。
  final Object? resizeId;

  /// 行事件命中直接返回的数据，不经全量 rowKey 索引反查。
  final ElTableRowContext? interactionData;

  @override
  RenderObjectElement createElement() => _GridRowElement(this);

  @override
  _RenderTableGridRow createRenderObject(BuildContext context) {
    return _RenderTableGridRow(
      coordinator: coordinator,
      selectionRegistrar: SelectionContainer.maybeOf(context),
      mode: mode,
      rowHeight: rowHeight,
      freezeAll: freezeAll,
      bandDividerColor: bandDividerColor,
      bandDividerWidth: bandDividerWidth,
      bandShadow: bandShadow,
      resizeId: resizeId,
      interactionData: interactionData,
      sparse: cellBuilder != null,
      hostedCells: hostedCells,
      hostedCellBuilder: hostedCellBuilder,
      windowed: windowed,
      parentLayered: parentLayered,
      spanned: cellSpans != null,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderTableGridRow renderObject) {
    renderObject
      ..coordinator = coordinator
      ..selectionRegistrar = SelectionContainer.maybeOf(context)
      ..mode = mode
      ..rowHeight = rowHeight
      ..freezeAll = freezeAll
      ..bandDividerColor = bandDividerColor
      ..bandDividerWidth = bandDividerWidth
      ..bandShadow = bandShadow
      ..resizeId = resizeId
      ..interactionData = interactionData
      ..sparse = cellBuilder != null
      ..hostedCells = hostedCells
      ..hostedCellBuilder = hostedCellBuilder
      ..windowed = windowed
      ..parentLayered = parentLayered
      ..spanned = cellSpans != null;
  }
}

/// 行原语元素：同一元素类承载稠密与稀疏两种子模型（同 key 行在两态间切换
/// 时 element 可复用，不因 createElement 分叉炸树）。
///
/// 稀疏协议仿 RenderSliverMultiBoxAdaptor：render 在 performLayout 内经
/// invokeLayoutCallback 请求把挂载集对齐到目标列集，slot 即视觉列号，
/// parentData.visualIndex 由 slot 写入（遍历序不再等于视觉序）。
class _GridRowElement extends RenderObjectElement {
  _GridRowElement(_TableGridRow super.widget);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    renderObject.selectionRegistrar = SelectionContainer.maybeOf(this);
  }

  @override
  _RenderTableGridRow get renderObject => super.renderObject as _RenderTableGridRow;

  _TableGridRow get _row => widget as _TableGridRow;

  /// 稠密子（视觉序）。
  List<Element> _dense = const [];
  final Set<Element> _forgottenDense = HashSet<Element>();

  /// 稀疏子：视觉列号 → element；render 插入时扫描混合子链定位前驱，
  /// 保持 element cell 与 render 托管 cell 的链表恒为视觉序升序。
  final Map<int, Element> _cells = <int, Element>{};
  final List<int> _staleCells = <int>[];

  /// widget 更新后置脏：下次 layout 挂载回调里用新 builder 重建已挂载 cell；
  /// 未置脏的跨窗 relayout 只补缺列，存量 cell 零构建。
  bool _cellsDirty = true;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject._element = this;
    if (_row.cellBuilder == null && _row.hostedCells == null) {
      final dense = <Element>[];
      Element? previous;
      for (final child in _row.children) {
        previous = inflateWidget(child, IndexedSlot<Element?>(dense.length, previous));
        dense.add(previous);
      }
      _dense = dense;
    }
    _cellsDirty = true;
  }

  @override
  void update(_TableGridRow newWidget) {
    final wasSparse = _row.cellBuilder != null;
    final wasHosted = _row.hostedCells != null;
    super.update(newWidget);
    if (newWidget.cellBuilder != null) {
      if (!wasSparse && !wasHosted && _dense.isNotEmpty) {
        for (final child in _dense) {
          if (!_forgottenDense.contains(child)) deactivateChild(child);
        }
        _dense = const [];
        _forgottenDense.clear();
      }
      _cellsDirty = true;
      renderObject.markNeedsLayout();
    } else if (newWidget.hostedCells != null) {
      if (wasSparse && _cells.isNotEmpty) {
        for (final child in _cells.values.toList()) {
          deactivateChild(child);
        }
        _cells.clear();
      }
      if (!wasHosted && _dense.isNotEmpty) {
        for (final child in _dense) {
          if (!_forgottenDense.contains(child)) deactivateChild(child);
        }
        _dense = const [];
        _forgottenDense.clear();
      }
    } else {
      if (wasSparse && _cells.isNotEmpty) {
        for (final child in _cells.values.toList()) {
          deactivateChild(child);
        }
        _cells.clear();
      }
      _dense = updateChildren(_dense, newWidget.children, forgottenChildren: _forgottenDense);
      _forgottenDense.clear();
      for (var index = 0; index < _dense.length; index++) {
        final render = _dense[index].renderObject;
        if (render is RenderBox) renderObject._noteChildSpan(render, _spanFor(index));
      }
    }
  }

  @override
  void unmount() {
    renderObject._element = null;
    super.unmount();
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final child in _dense) {
      if (!_forgottenDense.contains(child)) visitor(child);
    }
    for (final child in _cells.values.toList()) {
      visitor(child);
    }
  }

  @override
  void forgetChild(Element child) {
    final slot = child.slot;
    if (slot is int && identical(_cells[slot], child)) {
      _cells.remove(slot);
    } else if (_dense.contains(child)) {
      _forgottenDense.add(child);
    }
    super.forgetChild(child);
  }

  /// layout 期挂载回调：把挂载集对齐到 冻结带（恒驻）+ mid 窗口 [midStart, midEnd)。
  void _ensureSparseCells(_TableGridLayout layout, int midStart, int midEnd) {
    owner!.buildScope(this, () {
      final builder = _row.cellBuilder!;
      final count = math.min(_row.cellCount ?? layout.columnCount, layout.columnCount);
      final dirty = _cellsDirty;
      _cellsDirty = false;
      renderObject._pruneSparseHostedCells(layout, count, midStart, midEnd);
      // 卸载：目标集之外的 mid cell（带列恒驻）。
      _staleCells.clear();
      for (final i in _cells.keys) {
        if (i >= count || (i >= layout.midStart && i < layout.midEnd && (i < midStart || i >= midEnd))) {
          _staleCells.add(i);
        }
      }
      for (final i in _staleCells) {
        deactivateChild(_cells.remove(i)!);
      }
      void ensure(int i) {
        final existing = _cells[i];
        if (!dirty && (existing != null || renderObject._hasSparseHostedCell(i))) return;
        final hosted = renderObject._buildSparseHostedCell(i);
        if (hosted != null) {
          if (existing != null) deactivateChild(_cells.remove(i)!);
          renderObject._setSparseHostedCell(i, hosted);
          return;
        }
        renderObject._removeSparseHostedCell(i);
        final built = updateChild(existing, builder(this, i), i);
        if (built != null) {
          _cells[i] = built;
        } else {
          _cells.remove(i);
        }
      }

      final leftEnd = math.min(layout.leftCount, count);
      for (var i = 0; i < leftEnd; i++) {
        ensure(i);
      }
      final midS = math.max(midStart, layout.midStart);
      final midE = math.min(math.min(midEnd, layout.midEnd), count);
      for (var i = midS; i < midE; i++) {
        ensure(i);
      }
      for (var i = math.max(layout.midEnd, leftEnd); i < count; i++) {
        ensure(i);
      }
    });
  }

  /// 稀疏插入的前驱 render：已挂载列号中最大的 < index 者。
  RenderBox? _sparseAfter(int index) => renderObject._childBeforeVisualIndex(index);

  _TableGridCellSpan _spanFor(int index) => _row.cellSpans?[index] ?? _TableGridCellSpan(index, index + 1);

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    child as RenderBox;
    if (slot is IndexedSlot<Element?>) {
      renderObject.insert(child, after: slot.value?.renderObject as RenderBox?);
      renderObject._noteChildSpan(child, _spanFor(slot.index));
    } else {
      final index = slot! as int;
      renderObject.insert(child, after: _sparseAfter(index));
      renderObject._noteChildIndex(child, index);
    }
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    child as RenderBox;
    if (newSlot is IndexedSlot<Element?>) {
      renderObject.move(child, after: newSlot.value?.renderObject as RenderBox?);
      renderObject._noteChildSpan(child, _spanFor(newSlot.index));
    } else {
      final index = newSlot! as int;
      renderObject.move(child, after: _sparseAfter(index));
      renderObject._noteChildIndex(child, index);
    }
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    renderObject.remove(child as RenderBox);
  }
}

class _TableGridRowParentData extends ContainerBoxParentData<RenderBox> {
  /// 视觉列下标（layout 期写入，applyPaintTransform / hitTest O(1) 取带归属）。
  int visualIndex = 0;

  /// 当前单元格占用的视觉列半开区间终点。
  int visualEnd = 1;
}

class _RenderTableGridRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TableGridRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TableGridRowParentData> {
  _RenderTableGridRow({
    required _TableGridCoordinator coordinator,
    required _TableGridRowMode mode,
    SelectionRegistrar? selectionRegistrar,
    double? rowHeight,
    bool freezeAll = false,
    Color? bandDividerColor,
    double bandDividerWidth = 1.0,
    List<BoxShadow>? bandShadow,
    this.resizeId,
    this.interactionData,
    bool sparse = false,
    List<_TableHostedCell>? hostedCells,
    _TableHostedCellBuilder? hostedCellBuilder,
    bool windowed = false,
    bool parentLayered = false,
    bool spanned = false,
  }) : _coordinator = coordinator,
       _selectionRegistrar = selectionRegistrar,
       _mode = mode,
       _rowHeight = rowHeight,
       _freezeAll = freezeAll,
       _bandDividerColor = bandDividerColor,
       _bandDividerWidth = bandDividerWidth,
       _bandShadow = bandShadow,
       _sparse = sparse,
       _windowed = windowed,
       _hostedCellBuilder = hostedCellBuilder,
       _parentLayered = parentLayered,
       _spanned = spanned {
    this.hostedCells = hostedCells;
  }

  /// 测试探针：paint 执行次数（验证「无冻结列行零重录」）。
  int debugPaintCount = 0;

  /// 测试探针：当前挂载的 cell 数（稀疏 = 带列 + 窗口列；稠密 = 全列）。
  int get debugMountedCellCount => childCount;

  /// 测试探针：共享 coordinator 的稀疏列窗口换页次数。
  int get debugSparseWindowResetCount => _coordinator.debugSparseWindowResetCount;

  /// 测试探针：当前脱树保留的上一横向窗口纯值 cell 数。
  int get debugCachedCellCount => _sparseHostedCache?.length ?? 0;

  /// element 桥（稀疏挂载协议的对端）。
  _GridRowElement? _element;

  /// 测试探针：最近一次 paint 画出的带阴影（bit0 = 左带、bit1 = 右带）。
  int debugPaintedShadowMask = 0;

  _TableGridCoordinator _coordinator;
  _TableGridCoordinator get coordinator => _coordinator;
  set coordinator(_TableGridCoordinator value) {
    if (identical(_coordinator, value)) return;
    if (attached) _coordinator._detachRow(this);
    _coordinator = value;
    if (attached) {
      _coordinator._attachRow(this);
      _syncFollower();
    }
    markNeedsLayout();
  }

  _TableGridRowMode _mode;
  _TableGridRowMode get mode => _mode;
  set mode(_TableGridRowMode value) {
    if (_mode == value) return;
    _mode = value;
    if (attached) _syncFollower();
    markNeedsLayout();
  }

  double? _rowHeight;
  double? get rowHeight => _rowHeight;
  set rowHeight(double? value) {
    if (_rowHeight == value) return;
    _rowHeight = value;
    markNeedsLayout();
  }

  /// 行高拖拽寻址标识（widget 透传）。coordinator 按它线性扫挂载行。
  Object? resizeId;

  ElTableRowContext? interactionData;

  double? _liveHeight;

  /// 行高拖拽 live 覆盖：非 null 时优先于 [rowHeight] 参与布局。
  /// 表格 State 在拖拽帧经 coordinator 寻址直写（零 build），提交 / 取消后
  /// 置 null；中途 widget 重建不清除本值，拖拽不被无关 build 打断。
  double? get liveHeight => _liveHeight;
  set liveHeight(double? value) {
    if (_liveHeight == value) return;
    _liveHeight = value;
    markNeedsLayout();
  }

  /// 本帧生效的定高（live 覆盖优先）。null = 动态行高。
  double? get _effectiveRowHeight => _liveHeight ?? _rowHeight;

  bool _freezeAll;
  bool get freezeAll => _freezeAll;
  set freezeAll(bool value) {
    if (_freezeAll == value) return;
    _freezeAll = value;
    if (attached) _syncFollower();
    markNeedsLayout();
  }

  Color? _bandDividerColor;
  Color? get bandDividerColor => _bandDividerColor;
  set bandDividerColor(Color? value) {
    if (_bandDividerColor == value) return;
    _bandDividerColor = value;
    markNeedsPaint();
  }

  double _bandDividerWidth;
  double get bandDividerWidth => _bandDividerWidth;
  set bandDividerWidth(double value) {
    if (_bandDividerWidth == value) return;
    _bandDividerWidth = value;
    markNeedsPaint();
  }

  List<BoxShadow>? _bandShadow;
  List<BoxShadow>? get bandShadow => _bandShadow;
  set bandShadow(List<BoxShadow>? value) {
    if (identical(_bandShadow, value)) return;
    _bandShadow = value;
    markNeedsPaint();
  }

  bool _sparse;
  bool _windowed;

  bool _parentLayered;
  set parentLayered(bool value) {
    if (_parentLayered == value) return;
    _parentLayered = value;
    markNeedsCompositingBitsUpdate();
  }

  bool _spanned;
  set spanned(bool value) {
    if (_spanned == value) return;
    _spanned = value;
    markNeedsLayout();
  }

  /// 稀疏子模型（列级虚拟化）：layout 期经 element 桥把挂载集对齐到
  /// 冻结带 + 规范 mid 窗口。
  bool get sparse => _sparse;
  set sparse(bool value) {
    if (_sparse == value) return;
    _sparse = value;
    if (!value) _clearSparseHostedChildren();
    markNeedsLayout();
  }

  set windowed(bool value) {
    if (_windowed == value) return;
    _windowed = value;
    markNeedsLayout();
  }

  List<RenderBox> _hostedChildren = const [];
  SelectionRegistrar? _selectionRegistrar;

  // 托管单元格没有 Element，由行宿主转交同一个官方注册中心。
  set selectionRegistrar(SelectionRegistrar? value) {
    if (identical(value, _selectionRegistrar)) return;
    _selectionRegistrar = value;
    for (final child in _hostedChildren) {
      if (child is ElRenderView) child.selectionRegistrar = value;
    }
    for (final entry in _sparseHostedChildren.values.followedBy(_sparseHostedCache?.values ?? const [])) {
      final child = entry.render;
      if (child is ElRenderView) child.selectionRegistrar = value;
    }
  }

  final Map<int, _TableHostedCacheEntry> _sparseHostedChildren = <int, _TableHostedCacheEntry>{};
  Map<int, _TableHostedCacheEntry>? _sparseHostedCache;
  final List<int> _staleSparseHostedIndices = <int>[];
  _TableHostedCellBuilder? _hostedCellBuilder;
  static const int _sparseHostedCacheLimit = 32;

  set hostedCellBuilder(_TableHostedCellBuilder? value) {
    if (identical(_hostedCellBuilder, value)) return;
    _hostedCellBuilder = value;
    _clearSparseHostedCache();
    markNeedsLayout();
  }

  set hostedCells(List<_TableHostedCell>? value) {
    if (value == null) {
      _clearHostedChildren();
      return;
    }
    if (_hostedChildren.length == value.length) {
      for (var index = 0; index < value.length; index++) {
        final cell = value[index];
        final child = _hostedChildren[index];
        if (!_updateHostedRender(child, cell)) {
          // 列数不变也可能切换普通列与行号列，渲染器类型必须随配置替换。
          remove(child);
          child.dispose();
          final replacement = _createHostedRender(cell);
          insert(replacement, after: index == 0 ? null : _hostedChildren[index - 1]);
          _noteChildIndex(replacement, index);
          _hostedChildren[index] = replacement;
        }
      }
      return;
    }
    _clearHostedChildren();
    final children = <RenderBox>[];
    for (var index = 0; index < value.length; index++) {
      final cell = value[index];
      final child = _createHostedRender(cell);
      insert(child, after: children.isEmpty ? null : children.last);
      _noteChildIndex(child, index);
      children.add(child);
    }
    _hostedChildren = children;
  }

  void _clearHostedChildren() {
    if (_hostedChildren.isEmpty) return;
    for (final child in _hostedChildren) {
      remove(child);
      child.dispose();
    }
    _hostedChildren = const [];
  }

  bool _hasSparseHostedCell(int index) => _sparseHostedChildren.containsKey(index);

  _TableHostedCell? _buildSparseHostedCell(int index) => _hostedCellBuilder?.call(index);

  void _setSparseHostedCell(int index, _TableHostedCell cell) {
    final existing = _sparseHostedChildren[index];
    if (existing != null) {
      if (!_sameHostedCell(existing.cell, cell)) {
        if (!_updateHostedRender(existing.render, cell)) {
          remove(existing.render);
          existing.render.dispose();
          final child = _createHostedRender(cell);
          insert(child, after: _childBeforeVisualIndex(index));
          _noteChildIndex(child, index);
          _sparseHostedChildren[index] = (render: child, cell: cell);
          return;
        }
      }
      _sparseHostedChildren[index] = (render: existing.render, cell: cell);
      return;
    }
    final cache = _sparseHostedCache;
    final cached = cache?.remove(index);
    if (cache?.isEmpty ?? false) _sparseHostedCache = null;
    final RenderBox child;
    if (cached == null) {
      child = _createHostedRender(cell);
    } else {
      final candidate = cached.render;
      if (_sameHostedCell(cached.cell, cell) || _updateHostedRender(candidate, cell)) {
        child = candidate;
      } else {
        candidate.dispose();
        child = _createHostedRender(cell);
      }
    }
    insert(child, after: _childBeforeVisualIndex(index));
    _noteChildIndex(child, index);
    _sparseHostedChildren[index] = (render: child, cell: cell);
  }

  static bool _sameHostedCell(_TableHostedCell? old, _TableHostedCell next) =>
      old != null && identical(old.style, next.style) && _sameHostedValue(old.value, next.value);

  static bool _sameHostedValue(Object? old, Object? next) =>
      identical(old, next) ||
      (old is String && next is String && old == next) ||
      (old is num && next is num && old == next) ||
      (old is bool && next is bool && old == next);

  RenderBox _createHostedRender(_TableHostedCell cell) {
    final ordinal = cell.value;
    if (ordinal is _TableHostedOrdinal) return _RenderTableOrdinalCell(cell.style, _createOrdinalRender(ordinal));
    return ElRenderView(style: cell.style, child: ordinal)..selectionRegistrar = _selectionRegistrar;
  }

  bool _updateHostedRender(RenderBox render, _TableHostedCell cell) {
    final ordinal = cell.value;
    if (render is _RenderTableOrdinalCell && ordinal is _TableHostedOrdinal) {
      render.box.style = cell.style;
      _configureOrdinalRender(render.gutter, ordinal);
      return true;
    }
    if (render is ElRenderView && ordinal is! _TableHostedOrdinal) {
      render
        ..style = cell.style
        ..setTextPayload(ordinal);
      return true;
    }
    return false;
  }

  ElRenderOrdinalGutter _createOrdinalRender(_TableHostedOrdinal ordinal) => ElRenderOrdinalGutter.single(
    totalRows: ordinal.totalRows,
    firstNumber: ordinal.firstNumber,
    rowIndex: ordinal.rowIndex,
    textAlign: ordinal.textAlign,
    style: ordinal.environment.style,
    textDirection: ordinal.environment.direction,
    textScaler: ordinal.environment.scaler,
    locale: ordinal.environment.locale,
  );

  void _configureOrdinalRender(ElRenderOrdinalGutter render, _TableHostedOrdinal ordinal) {
    render.configureSingle(
      totalRows: ordinal.totalRows,
      firstNumber: ordinal.firstNumber,
      rowIndex: ordinal.rowIndex,
      textAlign: ordinal.textAlign,
      style: ordinal.environment.style,
      textDirection: ordinal.environment.direction,
      textScaler: ordinal.environment.scaler,
      locale: ordinal.environment.locale,
    );
  }

  void _removeSparseHostedCell(int index) {
    final entry = _sparseHostedChildren.remove(index);
    if (entry == null) return;
    remove(entry.render);
    entry.render.dispose();
  }

  void _cacheSparseHostedCell(int index) {
    final entry = _sparseHostedChildren.remove(index);
    if (entry == null) return;
    remove(entry.render);
    final cache = _sparseHostedCache ??= <int, _TableHostedCacheEntry>{};
    final replaced = cache.remove(index);
    replaced?.render.dispose();
    cache[index] = entry;
    while (cache.length > _sparseHostedCacheLimit) {
      final staleKey = cache.keys.first;
      cache.remove(staleKey)!.render.dispose();
    }
  }

  void _pruneSparseHostedCells(_TableGridLayout layout, int count, int midStart, int midEnd) {
    _staleSparseHostedIndices.clear();
    for (final index in _sparseHostedChildren.keys) {
      if (index >= count ||
          (index >= layout.midStart && index < layout.midEnd && (index < midStart || index >= midEnd))) {
        _staleSparseHostedIndices.add(index);
      }
    }
    for (final index in _staleSparseHostedIndices) {
      _cacheSparseHostedCell(index);
    }
  }

  void _clearSparseHostedChildren() {
    if (_sparseHostedChildren.isEmpty && (_sparseHostedCache?.isEmpty ?? true)) return;
    final children = _sparseHostedChildren.values.toList(growable: false);
    _sparseHostedChildren.clear();
    for (final entry in children) {
      remove(entry.render);
      entry.render.dispose();
    }
    _clearSparseHostedCache();
  }

  void _clearSparseHostedCache() {
    final cache = _sparseHostedCache;
    if (cache == null || cache.isEmpty) return;
    _sparseHostedCache = null;
    for (final entry in cache.values) {
      entry.render.dispose();
    }
    cache.clear();
  }

  RenderBox? _childBeforeVisualIndex(int index) {
    RenderBox? previous;
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _TableGridRowParentData;
      if (parentData.visualIndex >= index) break;
      previous = child;
      child = parentData.nextSibling;
    }
    return previous;
  }

  /// element 桥：子挂载/移位时按 slot 写入视觉列号——稀疏挂载下遍历序
  /// 不再等于视觉序，几何一律以 parentData.visualIndex 为准。
  void _noteChildIndex(RenderBox child, int index) {
    final pd = child.parentData;
    if (pd is _TableGridRowParentData) {
      pd.visualIndex = index;
      pd.visualEnd = index + 1;
    }
  }

  void _noteChildSpan(RenderBox child, _TableGridCellSpan span) {
    final pd = child.parentData;
    if (pd is _TableGridRowParentData) {
      pd.visualIndex = span.start;
      pd.visualEnd = span.end;
    }
  }

  /// 本帧生效的列几何（layout 期定格）。
  _TableGridLayout? _gridLayout;

  /// 稠密行按视觉下标 O(1) 取列；稀疏行只保留已挂载列的紧凑有序索引，
  /// 避免每个可见行都按总列数分配空槽。
  List<RenderBox?> _childTable = const <RenderBox?>[];
  final List<int> _sparseVisualIndices = <int>[];
  final List<RenderBox> _sparseChildren = <RenderBox>[];

  /// 独立重绘边界：无冻结带的 shell 行靠壳 OffsetLayer 平移复合，父滚动
  /// markNeedsPaint 时不得重录本行；有冻结带 / selfShift 仍由 coordinator
  /// 显式 markNeedsPaint 触发重录。
  @override
  bool get isRepaintBoundary => !_parentLayered;

  /// 是否存在冻结带（layout 期定格）。
  bool get _hasBands => _freezeAll || (_gridLayout?.leftCount ?? 0) > 0 || (_gridLayout?.rightCount ?? 0) > 0;

  /// 是否需要跟随横向偏移重绘：selfShift 恒需要（mid 段自平移）；
  /// shell 只在有冻结带时需要（无带行由壳的保留层平移复合，零重录）。
  bool get _needsHFollow => switch (_mode) {
    _TableGridRowMode.selfShift => true,
    _TableGridRowMode.shell => _freezeAll || _specHasBands,
    _ => false,
  };

  /// layout 之前也能判定的「规格声明了冻结带」：注册时机早于首次 layout。
  bool get _specHasBands {
    final spec = _coordinator._spec;
    if (spec == null) return false;
    return spec.leftCount > 0 || spec.rightCount > 0;
  }

  void _syncFollower() {
    if (_needsHFollow) {
      _coordinator._register(this);
    } else {
      _coordinator._unregister(this);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _coordinator._attachRow(this);
    _syncFollower();
  }

  @override
  void detach() {
    _coordinator._detachRow(this);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TableGridRowParentData) {
      child.parentData = _TableGridRowParentData();
    }
  }

  // ---- 布局 ----

  @override
  void performLayout() {
    if (_mode == _TableGridRowMode.ruler) {
      _childTable = const <RenderBox?>[];
      _sparseVisualIndices.clear();
      _sparseChildren.clear();
      _publishViewportWidth();
      size = Size(constraints.hasBoundedWidth ? constraints.maxWidth : _coordinator.forcedTotal, 0.0);
      _gridLayout = _coordinator.layout;
      return;
    }
    final bounded = constraints.hasBoundedWidth;
    _TableGridLayout layout;
    if (_mode == _TableGridRowMode.shell) {
      // shell 行不发布 viewportW——展开行包装列的 stretch 会给它受限宽
      // （= 内容宽而非 viewport 宽），误发布会污染右带钉靠基准。
      final shared = _coordinator.layout;
      assert(
        shared != null || bounded,
        '_TableGridRow(shell) 在无界宽下布局，但列几何尚未解析——'
        '表格必须先放置 ruler / 表头等有界行完成解析。',
      );
      layout = shared ?? _coordinator.resolveFor(constraints.maxWidth);
    } else {
      _publishViewportWidth();
      layout = _coordinator.resolveFor(bounded ? constraints.maxWidth : _coordinator.forcedTotal);
    }
    _gridLayout = layout;

    final rowW = switch (_mode) {
      _TableGridRowMode.shell => math.max(layout.totalW, _coordinator.viewportW),
      _ => bounded ? constraints.maxWidth : layout.totalW,
    };

    if (_freezeAll) {
      _layoutFreezeAll(rowW);
      return;
    }

    if (_sparse) {
      // 列虚拟化对齐冻结带 + 规范 mid 窗口；普通混合托管对齐全部列。
      int s;
      int e;
      if (_windowed) {
        final (wx0, wx1) = _coordinator.sparseWindowX();
        (s, e) = layout.midRangeFor(wx0, wx1);
      } else {
        s = layout.midStart;
        e = layout.midEnd;
      }
      final reconcileTrace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
      invokeLayoutCallback<BoxConstraints>((_) {
        _element?._ensureSparseCells(layout, s, e);
      });
      if (reconcileTrace != null) {
        MountTrace.tableSparseReconcileCount++;
        MountTrace.tableSparseReconcileUs += reconcileTrace.elapsedMicroseconds;
      }
    }

    // 几何按 parentData.visualIndex 取（element 按 slot 写入）——稀疏挂载下
    // 遍历序 != 视觉序，稠密下两者相等。
    List<RenderBox?>? table;
    if (_sparse || _spanned) {
      _childTable = const <RenderBox?>[];
      _sparseVisualIndices.clear();
      _sparseChildren.clear();
    } else if (_childTable.length == layout.columnCount) {
      table = _childTable..fillRange(0, _childTable.length, null);
    } else {
      table = List<RenderBox?>.filled(layout.columnCount, null);
    }
    final fixedH = _effectiveRowHeight;
    final childLayoutTrace = _sparse && elMountTraceEnabled ? (Stopwatch()..start()) : null;
    var maxH = 0.0;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _TableGridRowParentData;
      final i = pd.visualIndex;
      final end = _spanned ? pd.visualEnd : i + 1;
      final inRange = i >= 0 && i < layout.columnCount && end > i && end <= layout.columnCount;
      final w = inRange ? layout.prefixes[end] - layout.prefixes[i] : 0.0;
      child.layout(
        fixedH != null
            ? BoxConstraints.tightFor(width: w, height: fixedH)
            : BoxConstraints(minWidth: w, maxWidth: w, minHeight: 0.0, maxHeight: double.infinity),
        parentUsesSize: fixedH == null,
      );
      pd.offset = Offset(inRange ? layout.prefixes[i] : 0.0, 0.0);
      if (inRange) {
        if (_sparse) {
          _sparseVisualIndices.add(i);
          _sparseChildren.add(child);
        } else if (!_spanned) {
          table![i] = child;
        }
      }
      if (fixedH == null) maxH = math.max(maxH, child.size.height);
      child = pd.nextSibling;
    }
    if (!_sparse && !_spanned) _childTable = table!;
    if (childLayoutTrace != null) MountTrace.tableSparseChildLayoutUs += childLayoutTrace.elapsedMicroseconds;
    final rowH = fixedH ?? maxH;
    if (fixedH == null) {
      // 第二趟：把矮于行高的 cell 拉齐（背景 / 边框 / 垂直居中需要满高盒）。
      child = firstChild;
      while (child != null) {
        final pd = child.parentData! as _TableGridRowParentData;
        if (child.size.height != rowH) {
          final i = pd.visualIndex;
          final end = _spanned ? pd.visualEnd : i + 1;
          final w = i >= 0 && i < layout.columnCount && end > i && end <= layout.columnCount
              ? layout.prefixes[end] - layout.prefixes[i]
              : 0.0;
          child.layout(BoxConstraints.tightFor(width: w, height: rowH), parentUsesSize: true);
        }
        child = pd.nextSibling;
      }
    }
    size = constraints.constrain(Size(rowW, rowH));
  }

  /// 整行冻结（展开详情）：唯一子项按 viewport 宽布局，paint 期整体反钉。
  void _layoutFreezeAll(double rowW) {
    final child = firstChild;
    final w = _viewportW;
    if (child != null) {
      final pd = child.parentData! as _TableGridRowParentData;
      final fixedH = _rowHeight;
      child.layout(
        fixedH != null
            ? BoxConstraints.tightFor(width: w, height: fixedH)
            : BoxConstraints(minWidth: w, maxWidth: w, minHeight: 0.0, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      pd.visualIndex = 0;
      pd.offset = Offset.zero;
      _childTable = List<RenderBox?>.filled(1, child);
      size = constraints.constrain(Size(rowW, child.size.height));
    } else {
      _childTable = const <RenderBox?>[];
      size = constraints.constrain(Size(rowW, 0.0));
    }
  }

  void _publishViewportWidth() {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : _coordinator.forcedTotal;
    _coordinator.viewportW = width;
    _coordinator.resolveFor(width);
    // 溢出事实只由 viewport 行发布；无界父级退回自然列总宽，不产生横向溢出。
    if (constraints.hasBoundedWidth) _coordinator._updateHOverflow(width);
  }

  double get _viewportW {
    final w = _coordinator.viewportW;
    if (w > 0) return w;
    // 兜底：selfShift 自身有界；shell 在 ruler 缺席时退化为内容宽（无钉靠）。
    return _gridLayout?.totalW ?? 0.0;
  }

  // ---- 三带投影 ----

  double get _h => _coordinator.h;

  /// 左冻结带偏移：shell 反钉 +h；selfShift 钉原位。
  double get _leftShift => _mode == _TableGridRowMode.shell ? _h : 0.0;

  /// mid 段偏移：shell 由壳平移（自身 0）；selfShift 自画 -h。
  double get _midShift => _mode == _TableGridRowMode.selfShift ? -_h : 0.0;

  /// 右冻结带偏移：恒钉 viewport 右缘。
  /// shell: h + W - totalW（h=maxH 时归零）；selfShift: W - totalW。
  double get _rightShift {
    final layout = _gridLayout;
    if (layout == null) return 0.0;
    final base = _viewportW - layout.totalW;
    return _mode == _TableGridRowMode.shell ? _h + base : base;
  }

  /// 整行冻结的偏移（等价"左带宽 = viewport 宽"）。
  double get _freezeAllShift => _mode == _TableGridRowMode.shell ? _h : 0.0;

  double _shiftOf(int visualIndex) {
    final layout = _gridLayout!;
    if (_freezeAll) return _freezeAllShift;
    if (visualIndex < layout.leftCount) return _leftShift;
    if (visualIndex >= layout.midEnd) return _rightShift;
    return _midShift;
  }

  double _reorderShiftOf(_TableGridRowParentData parentData) => _spanned
      ? _coordinator.columnReorderSpanOffset(parentData.visualIndex, parentData.visualEnd)
      : _coordinator.columnReorderOffset(parentData.visualIndex);

  bool _isLiftedColumn(_TableGridRowParentData parentData) => _spanned
      ? _coordinator.isColumnReorderSourceSpan(parentData.visualIndex, parentData.visualEnd)
      : _coordinator.isColumnReorderSource(parentData.visualIndex);

  /// mid 段在行本地坐标里的可视窗口 [x0, x1)（冻结带内缘之间）。
  (double, double) get _midWindow {
    final layout = _gridLayout!;
    final x0 = _leftShift + layout.leftW;
    final x1 = _rightShift + layout.totalW - layout.rightW;
    return (x0, x1);
  }

  // ---- paint ----

  @override
  void paint(PaintingContext context, Offset offset) {
    debugPaintCount++;
    final layout = _gridLayout;
    if (layout == null || firstChild == null) return;

    if (_freezeAll) {
      final child = firstChild!;
      final pd = child.parentData! as _TableGridRowParentData;
      context.paintChild(child, offset + pd.offset + Offset(_freezeAllShift, 0.0));
      return;
    }

    if (!_hasBands) {
      // 纯网格：plain 行 / 无冻结列的 shell 行（后者由壳平移复合，永不因 h 重录）。
      // 列总宽超出行宽时裁到行盒：auto 横滚生效前的那一帧（以及用户显式
      // 关掉横滚的场景）只是尾列被裁，绝不把像素画到表格外面去。
      if (layout.totalW > size.width + 0.5) {
        _plainClipHandle.layer = context.pushClipRect(
          needsCompositing,
          offset,
          Offset.zero & size,
          _paintPlainPass,
          oldLayer: _plainClipHandle.layer,
        );
        return;
      }
      _plainClipHandle.layer = null;
      _paintPlainPass(context, offset);
      return;
    }

    final (winX0, winX1) = _midWindow;
    // mid 段：裁剪到冻结带内缘窗口——band 下方永不出现 mid 内容，行背景
    // （hover / 斑马 / 当前行，画在行 ElView 上）自然透进冻结带。
    if (winX1 > winX0) {
      final (start, end) = _coordinator.visibleMidRange(layout);
      _paintMidPass(context, offset, layout, winX0, winX1, start, end);
    }
    _paintBandShadow(context, offset, layout);
    _paintBandCells(context, offset, layout);
    _paintBandDivider(context, offset, layout);
  }

  void _paintPlainPass(PaintingContext context, Offset offset) {
    for (final lifted in const [false, true]) {
      var child = firstChild;
      while (child != null) {
        final pd = child.parentData! as _TableGridRowParentData;
        if (_isLiftedColumn(pd) == lifted) {
          context.paintChild(child, offset + pd.offset + Offset(_midShift + _reorderShiftOf(pd), 0.0));
        }
        child = pd.nextSibling;
      }
    }
  }

  final LayerHandle<ClipRectLayer> _plainClipHandle = LayerHandle<ClipRectLayer>();

  /// 测试探针：最近一次 paint 是否因列总宽超出行宽而裁剪了无带网格。
  bool get debugDidClipPlainOverflow => _plainClipHandle.layer != null;

  void _paintMidPass(
    PaintingContext context,
    Offset offset,
    _TableGridLayout layout,
    double winX0,
    double winX1,
    int start,
    int end,
  ) {
    if (start >= end) return;
    final clipRect = Rect.fromLTRB(winX0, 0.0, winX1, size.height);
    _midClipHandle.layer = context.pushClipRect(needsCompositing, offset, clipRect, (context, offset) {
      final shift = Offset(_midShift, 0.0);
      if (_spanned) {
        _paintSpannedRange(context, offset, shift, start, end);
        return;
      }
      for (final lifted in const [false, true]) {
        for (var i = start; i < end; i++) {
          final child = _childAtVisualIndex(i);
          if (child == null) continue; // 稀疏未挂载槽（跨窗补列前的防御兜底）。
          final pd = child.parentData! as _TableGridRowParentData;
          if (_isLiftedColumn(pd) != lifted) continue;
          context.paintChild(child, offset + pd.offset + shift + Offset(_reorderShiftOf(pd), 0.0));
        }
      }
    }, oldLayer: _midClipHandle.layer);
  }

  final LayerHandle<ClipRectLayer> _midClipHandle = LayerHandle<ClipRectLayer>();

  void _paintBandCells(PaintingContext context, Offset offset, _TableGridLayout layout) {
    if (layout.leftCount > 0) {
      final shift = Offset(_leftShift, 0.0);
      if (_spanned) {
        _paintSpannedRange(context, offset, shift, 0, layout.leftCount);
      } else {
        for (final lifted in const [false, true]) {
          for (var i = 0; i < layout.leftCount; i++) {
            final child = _childAtVisualIndex(i);
            if (child == null) continue;
            final pd = child.parentData! as _TableGridRowParentData;
            if (_isLiftedColumn(pd) != lifted) continue;
            context.paintChild(child, offset + pd.offset + shift + Offset(_reorderShiftOf(pd), 0.0));
          }
        }
      }
    }
    if (layout.rightCount > 0) {
      final shift = Offset(_rightShift, 0.0);
      if (_spanned) {
        _paintSpannedRange(context, offset, shift, layout.midEnd, layout.columnCount);
      } else {
        for (final lifted in const [false, true]) {
          for (var i = layout.midEnd; i < layout.columnCount; i++) {
            final child = _childAtVisualIndex(i);
            if (child == null) continue;
            final pd = child.parentData! as _TableGridRowParentData;
            if (_isLiftedColumn(pd) != lifted) continue;
            context.paintChild(child, offset + pd.offset + shift + Offset(_reorderShiftOf(pd), 0.0));
          }
        }
      }
    }
  }

  void _paintSpannedRange(PaintingContext context, Offset offset, Offset shift, int start, int end) {
    for (final lifted in const [false, true]) {
      var child = firstChild;
      while (child != null) {
        final pd = child.parentData! as _TableGridRowParentData;
        if (pd.visualIndex < end && pd.visualEnd > start && _isLiftedColumn(pd) == lifted) {
          context.paintChild(child, offset + pd.offset + shift + Offset(_reorderShiftOf(pd), 0.0));
        }
        child = pd.nextSibling;
      }
    }
  }

  /// 冻结带遮挡侧阴影：左带在 h > 0（右侧有被遮内容）时投向右，右带对称。
  ///
  /// 逐行绘制段落，两条纪律保证跨行拼接成连续整列：
  /// 1. 只裁到**外溢侧**可见（带自身区域不落阴影体——带内无不透明底色遮盖）；
  /// 2. 阴影源矩形纵向外延 3σ 再裁回本行 y 区间——每行看到的都是"无限高
  ///    阴影柱"的中段切片，横向衰减剖面逐行一致，无缝拼接。
  void _paintBandShadow(PaintingContext context, Offset offset, _TableGridLayout layout) {
    debugPaintedShadowMask = 0;
    final shadows = _bandShadow;
    if (shadows == null || shadows.isEmpty) return;
    final h = _h;
    final maxH = _coordinator.maxH;
    final canvas = context.canvas;
    final (winX0, winX1) = _midWindow;
    if (layout.leftCount > 0 && h > 0.5) {
      debugPaintedShadowMask |= 1;
      final rect = Rect.fromLTWH(offset.dx + _leftShift, offset.dy, layout.leftW, size.height);
      final spill = Rect.fromLTRB(offset.dx + winX0, offset.dy, offset.dx + winX1, offset.dy + size.height);
      _drawShadows(canvas, rect, spill, shadows);
    }
    if (layout.rightCount > 0 && h < maxH - 0.5) {
      debugPaintedShadowMask |= 2;
      final rect0 = _rightShift + layout.totalW - layout.rightW;
      final rect = Rect.fromLTWH(offset.dx + rect0, offset.dy, layout.rightW, size.height);
      final spill = Rect.fromLTRB(offset.dx + winX0, offset.dy, offset.dx + winX1, offset.dy + size.height);
      _drawShadows(canvas, rect, spill, shadows);
    }
  }

  /// bandShadow → Paint 缓存（按列表身份判等，与 bandShadow setter 的
  /// identical 门同口径）：h 滚动逐帧重绘不再逐带新建 Paint / MaskFilter。
  List<Paint>? _shadowPaints;
  List<BoxShadow>? _shadowPaintsSource;

  List<Paint> _shadowPaintsFor(List<BoxShadow> shadows) {
    if (!identical(_shadowPaintsSource, shadows)) {
      _shadowPaintsSource = shadows;
      _shadowPaints = [
        for (final s in shadows)
          Paint()
            ..color = s.color
            ..maskFilter = s.blurRadius > 0 ? MaskFilter.blur(s.blurStyle, s.blurSigma) : null,
      ];
    }
    return _shadowPaints!;
  }

  void _drawShadows(Canvas canvas, Rect rect, Rect spillClip, List<BoxShadow> shadows) {
    final paints = _shadowPaintsFor(shadows);
    canvas.save();
    canvas.clipRect(spillClip);
    for (var i = 0; i < shadows.length; i++) {
      final s = shadows[i];
      final extend = s.blurSigma * 3.0 + s.offset.dy.abs();
      final source = rect.shift(s.offset).inflate(s.spreadRadius);
      canvas.drawRect(Rect.fromLTRB(source.left, source.top - extend, source.right, source.bottom + extend), paints[i]);
    }
    canvas.restore();
  }

  /// 冻结带内缘分割线（带与 mid 的视觉界线，常驻）。
  void _paintBandDivider(PaintingContext context, Offset offset, _TableGridLayout layout) {
    final color = _bandDividerColor;
    if (color == null || _bandDividerWidth <= 0) return;
    final paint = Paint()..color = color;
    final w = _bandDividerWidth;
    final canvas = context.canvas;
    final (winX0, winX1) = _midWindow;
    if (layout.leftCount > 0) {
      // 覆盖 mid 首列的左边框，避免固定分界线与普通列线相邻成双线。
      canvas.drawRect(Rect.fromLTWH(offset.dx + winX0, offset.dy, w, size.height), paint);
    }
    if (layout.rightCount > 0) {
      canvas.drawRect(Rect.fromLTWH(offset.dx + winX1, offset.dy, w, size.height), paint);
    }
  }

  RenderBox? _childAtVisualIndex(int index) {
    if (_sparse) {
      var low = 0;
      var high = _sparseVisualIndices.length - 1;
      while (low <= high) {
        final middle = (low + high) >> 1;
        final candidate = _sparseVisualIndices[middle];
        if (candidate == index) return _sparseChildren[middle];
        if (candidate < index) {
          low = middle + 1;
        } else {
          high = middle - 1;
        }
      }
      return null;
    }
    if (index < 0 || index >= _childTable.length) return null;
    return _childTable[index];
  }

  // ---- hitTest / 坐标 ----

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final layout = _gridLayout;
    if (layout == null || firstChild == null) return false;

    if (_freezeAll) {
      final child = firstChild!;
      final pd = child.parentData! as _TableGridRowParentData;
      return _hitChild(result, child, position, pd.offset + Offset(_freezeAllShift, 0.0));
    }

    if (!_hasBands) {
      final shift = Offset(_midShift, 0.0);
      if (_spanned) return _hitSpannedRange(result, position, shift, 0, layout.columnCount);
      return _hitIndexedRange(result, position, shift, 0, layout.columnCount);
    }

    final (winX0, winX1) = _midWindow;
    if (position.dx >= winX0 && position.dx < winX1) {
      // mid 窗口内：只可能命中 mid 单元格（冻结带在窗口外）。
      final (visibleStart, visibleEnd) = layout.midRangeFor(position.dx - _midShift, position.dx - _midShift + 0.001);
      final start = _coordinator._columnReorderActive ? layout.midStart : visibleStart;
      final end = _coordinator._columnReorderActive ? layout.midEnd : visibleEnd;
      final shift = Offset(_midShift, 0.0);
      if (_spanned) return _hitSpannedRange(result, position, shift, start, end);
      return _hitIndexedRange(result, position, shift, start, end);
    }
    // 窗口外：冻结带区域。带占位遮挡 mid（不命中带内 cell 也不下穿到 mid）。
    if (layout.leftCount > 0 && position.dx < winX0) {
      final shift = Offset(_leftShift, 0.0);
      if (_spanned) return _hitSpannedRange(result, position, shift, 0, layout.leftCount);
      return _hitIndexedRange(result, position, shift, 0, layout.leftCount);
    }
    if (layout.rightCount > 0 && position.dx >= winX1) {
      final shift = Offset(_rightShift, 0.0);
      if (_spanned) return _hitSpannedRange(result, position, shift, layout.midEnd, layout.columnCount);
      return _hitIndexedRange(result, position, shift, layout.midEnd, layout.columnCount);
    }
    return false;
  }

  bool _hitSpannedRange(BoxHitTestResult result, Offset position, Offset shift, int start, int end) {
    for (final lifted in const [true, false]) {
      var child = lastChild;
      while (child != null) {
        final pd = child.parentData! as _TableGridRowParentData;
        if (pd.visualIndex < end &&
            pd.visualEnd > start &&
            _isLiftedColumn(pd) == lifted &&
            _hitChild(result, child, position, pd.offset + shift + Offset(_reorderShiftOf(pd), 0.0))) {
          return true;
        }
        child = pd.previousSibling;
      }
    }
    return false;
  }

  bool _hitIndexedRange(BoxHitTestResult result, Offset position, Offset shift, int start, int end) {
    for (final lifted in const [true, false]) {
      for (var index = end - 1; index >= start; index--) {
        final child = _childAtVisualIndex(index);
        if (child == null) continue;
        final pd = child.parentData! as _TableGridRowParentData;
        if (_isLiftedColumn(pd) != lifted) continue;
        if (_hitChild(result, child, position, pd.offset + shift + Offset(_reorderShiftOf(pd), 0.0))) return true;
      }
    }
    return false;
  }

  static bool _hitChild(BoxHitTestResult result, RenderBox child, Offset position, Offset paintOffset) {
    return result.addWithPaintOffset(
      offset: paintOffset,
      position: position,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    // 反钉/自平移必须如实申报——selection / semantics / localToGlobal 的一致性关键。
    final pd = child.parentData! as _TableGridRowParentData;
    final shift = _gridLayout == null
        ? 0.0
        : (_freezeAll ? _freezeAllShift : _shiftOf(pd.visualIndex) + _reorderShiftOf(pd));
    transform.translateByDouble(pd.offset.dx + shift, pd.offset.dy, 0.0, 1.0);
  }

  // ---- intrinsics / dry layout ----

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth();

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth();

  double _intrinsicWidth() => _coordinator.layout?.totalW ?? 0.0;

  @override
  double computeMinIntrinsicHeight(double width) => _effectiveRowHeight ?? _dynamicIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _effectiveRowHeight ?? _dynamicIntrinsicHeight(width);

  double _dynamicIntrinsicHeight(double width) {
    final layout = _coordinator.layout;
    if (layout == null) return 0.0;
    var maxH = 0.0;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _TableGridRowParentData;
      final i = pd.visualIndex;
      final end = _spanned ? pd.visualEnd : i + 1;
      final w = i >= 0 && i < layout.columnCount && end > i && end <= layout.columnCount
          ? layout.prefixes[end] - layout.prefixes[i]
          : 0.0;
      maxH = math.max(maxH, child.getMinIntrinsicHeight(w));
      child = pd.nextSibling;
    }
    return maxH;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_mode == _TableGridRowMode.ruler) {
      return Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0.0, 0.0);
    }
    final layout = _coordinator.layout;
    final rowW = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : math.max(layout?.totalW ?? 0.0, _coordinator.viewportW);
    return constraints.constrain(Size(rowW, _effectiveRowHeight ?? _dynamicIntrinsicHeight(rowW)));
  }

  @override
  void dispose() {
    _clearHostedChildren();
    _clearSparseHostedChildren();
    _midClipHandle.layer = null;
    _plainClipHandle.layer = null;
    super.dispose();
  }
}
