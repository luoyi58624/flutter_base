part of '../sliver.dart';

/// 驱动 [ElSliverList.recycler] 按序号定位的控制器，可在挂载前创建、随列表更换。
///
/// 远处条目不需要预先构建：下一次布局先实测目标条目，再用官方偏移修正一次移动视口。
class ElSliverRecyclerController {
  ElRenderSliverRecycler? _render;

  /// 是否已关联到正在显示的列表。
  bool get isAttached => _render?.attached ?? false;

  /// 将 [index] 对齐到视口的 [alignment] 位置：0 顶端、0.5 居中、1 底端。
  ///
  /// 完成定位的那一帧布局结束后返回 true；未挂载、列表为空或期间列表被移除时返回 false。
  /// 内容不足以滚到目标位置时停在可滚动范围的边界。
  Future<bool> jumpToIndex(int index, {double alignment = 0}) {
    final render = _render;
    if (render == null || !render.attached) return Future.value(false);
    return render._requestReveal(index, alignment);
  }

  /// 通知 [index] 处插入了 [count] 个条目。
  ///
  /// 下一次布局把视口内首个条目的序号随之后移，正文保持原位，不被插在上方的内容推走。
  void notifyItemsInserted(int index, int count) {
    if (count > 0) _render?._shiftItems(index, count);
  }

  /// 通知从 [index] 起移除了 [count] 个条目。
  ///
  /// 下一次布局把视口内首个条目的序号随之前移；它本身被移除时由紧随其后的条目接替原位置。
  void notifyItemsRemoved(int index, int count) {
    if (count > 0) _render?._shiftItems(index, -count);
  }

  /// 撤销尚未执行的定位，等待中的 [jumpToIndex] 返回 false。
  void cancel() {
    final render = _render;
    render?._reveal?.complete(false);
    render?._reveal = null;
  }
}

class _LazySliver extends RenderObjectWidget {
  const _LazySliver({
    super.key,
    required int itemCount,
    this.itemBuilder,
    this.delegate,
    this.columns,
    this.masonry = false,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.center = false,
    this.stretch = true,
    this.itemType,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.maxRecycledItems = 32,
    this.controller,
  }) : _childCount = itemCount,
       assert(itemCount >= 0),
       assert(maxRecycledItems >= 0),
       assert(mainAxisSpacing >= 0 && mainAxisSpacing < double.infinity),
       assert(crossAxisSpacing >= 0 && crossAxisSpacing < double.infinity);

  /// 当前数据条目数量。
  final int _childCount;
  int get itemCount => _childCount;

  /// 创建槽位内容，序号改变时由内容自己的监听器更新数据。
  ///
  /// 父组件更新配置或构建上下文依赖变化时可以重新调用此构建器。
  /// 监听对象由容器持有；事件执行时读取最新 value。
  final Widget Function(BuildContext context, ValueListenable<int> index)? itemBuilder;
  final SliverChildBuilderDelegate? delegate;
  final int? columns;
  int get crossAxisCount => columns ?? 1;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final bool masonry;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final bool center;
  final bool stretch;
  List<Widget> get children => const [];
  double get spacing => mainAxisSpacing;

  /// 返回可相互复用的结构类型，未指定时所有条目属于同一类型。
  final Object? Function(int index)? itemType;

  /// 所有类型合计最多保留的空闲槽位数，不包含当前缓存窗口。
  /// 设为零仍允许同一轮布局先回收再复用。
  final int maxRecycledItems;

  /// 按序号定位的控制器，仅列表开放。
  final ElSliverRecyclerController? controller;

  @override
  RenderObjectElement createElement() => delegate == null ? _RecyclerElement(this) : _BuilderElement(this);

  @override
  RenderSliver createRenderObject(BuildContext context) =>
      ElRenderSliverRecycler._(context as _RecyclerElement)..controller = controller;

  @override
  void updateRenderObject(BuildContext context, covariant ElRenderSliverRecycler renderObject) {
    renderObject
      ..controller = controller
      ..scheduleLayoutCallback();
  }
}

class _IndexBinding extends ChangeNotifier implements ValueListenable<int> {
  _IndexBinding(this._value);

  int _value;

  @override
  int get value => _value;

  void bind(int value, {bool refresh = false}) {
    if (_value == value && !refresh) return;
    _value = value;
    notifyListeners();
  }
}

class _Slot {
  _Slot(this.type, this.indexValue);

  final Object? type;
  int indexValue;
  // builder 只使用数字索引，不分配复用模式的通知对象。
  _IndexBinding? _binding;
  _IndexBinding get index => _binding ??= _IndexBinding(indexValue);
  late final ReuseAnimationState animation = ReuseAnimationState();
  FocusNode? _focusNode;
  FocusNode get focusNode => _focusNode ??= FocusNode(canRequestFocus: false, skipTraversal: true);
  Element? child;
  RenderBox? box;
  Widget? content;
  int generation = -1;
  bool active = false;

  void dispose() {
    _binding?.dispose();
    _focusNode?.dispose();
  }
}

class _RecyclerElement extends RenderObjectElement {
  _RecyclerElement(_LazySliver super.widget);

  final Set<_Slot> _slots = {};
  final Map<int, _Slot> _active = {};
  final Map<Object?, List<_Slot>> _pool = {};
  late final BuildScope _scope = BuildScope(scheduleRebuild: _scheduleRebuild);
  int _generation = 0;
  int _laidOutGeneration = -1;
  List<int> _visibleIndices = [];
  bool _deferredRebuild = false;

  _LazySliver get _widget => widget as _LazySliver;

  @override
  BuildScope get buildScope => _scope;

  @override
  ElRenderSliverRecycler get renderObject => super.renderObject as ElRenderSliverRecycler;

  void _prepareLayout() {}

  void _scheduleRebuild() {
    if (_deferredRebuild) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      _deferredRebuild = true;
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        _deferredRebuild = false;
        if (mounted) renderObject.scheduleLayoutCallback();
      });
    } else {
      renderObject.scheduleLayoutCallback();
    }
  }

  @override
  void markNeedsBuild() {
    _generation++;
    _scheduleRebuild();
  }

  @override
  void update(covariant _LazySliver newWidget) {
    _generation++;
    super.update(newWidget);
  }

  @override
  void performRebuild() {
    _generation++;
    super.performRebuild();
    renderObject.scheduleLayoutCallback();
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final slot in _slots.toList(growable: false)) {
      if (slot.child case final child?) visitor(child);
    }
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    for (final index in _visibleIndices) {
      if (_active[index]?.child case final child?) visitor(child);
    }
  }

  @override
  void insertRenderObjectChild(RenderBox child, covariant _Slot slot) {
    renderObject.insert(child, after: renderObject.lastChild);
    (child.parentData! as _RecyclerParentData).slot = slot;
    slot.box = child;
  }

  @override
  void moveRenderObjectChild(RenderBox child, covariant _Slot oldSlot, covariant _Slot newSlot) {
    oldSlot.box = null;
    newSlot.box = child;
    (child.parentData! as _RecyclerParentData).slot = newSlot;
  }

  @override
  void removeRenderObjectChild(RenderBox child, covariant _Slot slot) {
    slot.box = null;
    renderObject.remove(child);
  }

  @override
  void forgetChild(Element child) {
    final slot = child.slot! as _Slot;
    _slots.remove(slot);
    _active.removeWhere((_, value) => identical(value, slot));
    _pool[slot.type]?.remove(slot);
    if (_pool[slot.type]?.isEmpty ?? false) _pool.remove(slot.type);
    slot.child = null;
    super.forgetChild(child);
  }

  void _updateSlot(_Slot slot, {required bool active, int? index}) {
    final rebound = index != null && slot.indexValue != index;
    final refresh = active && slot.generation != _generation;
    if (!active || rebound) slot.focusNode.unfocus();
    if (index != null) {
      slot.indexValue = index;
      slot.index.bind(index, refresh: refresh);
    }
    if (refresh) {
      slot.generation = _generation;
      // 索引语义独立更新，child 保留业务结构，单纯换绑无需重新配置外层状态包装。
      final content = Builder(builder: (context) => _widget.itemBuilder!(context, slot.index));
      slot.content = _widget.addSemanticIndexes
          ? ValueListenableBuilder<int>(
              valueListenable: slot.index,
              child: content,
              builder: (_, value, child) => IndexedSemantics(index: value, child: child!),
            )
          : content;
    }
    if (slot.child != null && slot.active == active && !refresh) return;
    slot.active = active;
    final child = _ItemBoundary(
      slot: slot,
      repaintBoundary: _widget.addRepaintBoundaries,
      child: TickerMode(
        enabled: active,
        child: HeroMode(
          enabled: active,
          child: Focus(
            focusNode: slot.focusNode,
            canRequestFocus: false,
            skipTraversal: true,
            descendantsAreFocusable: active,
            descendantsAreTraversable: active,
            child: ReuseAnimationScope(state: slot.animation, child: slot.content!),
          ),
        ),
      ),
    );
    slot.child = updateChild(slot.child, child, slot);
    if (!active) (slot.box as _ItemRenderBoundary?)?.visible = false;
  }

  void _discard(_Slot slot) {
    _slots.remove(slot);
    slot.child = updateChild(slot.child, null, slot);
  }

  void _retire(_Slot slot) {
    _active.remove(slot.indexValue);
    (_pool[slot.type] ??= []).add(slot);
  }

  void _recycleOutside(int first, int last) {
    for (final entry in _active.entries.toList(growable: false)) {
      if (entry.key < first || entry.key > last || entry.value.type != _widget.itemType?.call(entry.key)) {
        // 先保留到本轮结束，零容量池也可以马上把槽位交给新条目。
        _retire(entry.value);
      }
    }
  }

  void _recycleExcept(Set<int> wanted) {
    for (final entry in _active.entries.toList(growable: false)) {
      if (!wanted.contains(entry.key) ||
          entry.key >= _widget._childCount ||
          entry.value.type != _widget.itemType?.call(entry.key)) {
        _retire(entry.value);
      }
    }
  }

  _Slot _obtain(int index) {
    final type = _widget.itemType?.call(index);
    var slot = _active[index];
    if (slot != null && slot.type != type) {
      _retire(slot);
      slot = null;
    }
    if (slot == null) {
      final candidates = _pool[type];
      if (candidates != null && candidates.isNotEmpty) {
        slot = candidates.removeLast();
        if (candidates.isEmpty) _pool.remove(type);
      } else {
        slot = _Slot(type, index);
        _slots.add(slot);
      }
    }
    _active[index] = slot;
    return slot;
  }

  RenderBox _layoutItem(int index, BoxConstraints constraints) {
    final slot = _obtain(index);
    void updateAndLayout() {
      owner!.buildScope(this, () {
        _updateSlot(slot, active: true, index: index);
        _discardInvalidSpares();
      });
      slot.box!.layout(constraints, parentUsesSize: true);
    }

    // 换记录时让构建与布局共享局部作用域，同一记录的状态更新继续正常过渡。
    if (slot.indexValue != index) {
      slot.animation.runRebind(updateAndLayout);
    } else {
      updateAndLayout();
    }
    return slot.box!;
  }

  void _discardInvalidSpares() {
    for (final type in _pool.keys.toList(growable: false)) {
      final candidates = _pool[type]!;
      // 必须在 buildScope 刷新脏子树前丢弃失效绑定，避免越界或旧结构读取新类型的数据。
      candidates.removeWhere((slot) {
        final index = slot.indexValue;
        if (index < _widget._childCount && slot.type == _widget.itemType?.call(index)) return false;
        _discard(slot);
        return true;
      });
      if (candidates.isEmpty) _pool.remove(type);
    }
  }

  void _finishLayout(Set<int> wanted) {
    for (final entry in _active.entries.toList(growable: false)) {
      if (!wanted.contains(entry.key)) _retire(entry.value);
    }
    _discardInvalidSpares();
    var spareCount = _pool.values.fold(0, (count, slots) => count + slots.length);
    while (spareCount > _widget.maxRecycledItems) {
      final type = _pool.keys.first;
      final candidates = _pool[type]!;
      _discard(candidates.removeAt(0));
      spareCount--;
      if (candidates.isEmpty) _pool.remove(type);
    }
    for (final candidates in _pool.values) {
      for (final slot in candidates) {
        _updateSlot(slot, active: false);
      }
    }
    final indicesChanged =
        wanted.length != _visibleIndices.length || _visibleIndices.any((index) => !wanted.contains(index));
    final changed = indicesChanged || _laidOutGeneration != _generation;
    if (indicesChanged) _visibleIndices = wanted.toList()..sort();
    _laidOutGeneration = _generation;
    if (changed) renderObject.markNeedsSemanticsUpdate();
  }
}

class _RecyclerParentData extends ContainerBoxParentData<RenderBox> with KeepAliveParentDataMixin {
  @override
  bool get keptAlive => keepAlive && !slot.active;
  late _Slot slot;
  double layoutOffset = 0;
  double crossAxisOffset = 0;
  double extent = 0;
}

class _RevealRequest {
  _RevealRequest(this.index, this.alignment);

  final int index;
  final double alignment;
  final completer = Completer<bool>();

  void complete(bool value) {
    if (!completer.isCompleted) completer.complete(value);
  }
}

class _RecyclerAnchor {
  _RecyclerAnchor(this.index, this.relativeStart);

  final int index;
  final double relativeStart;
}

/// 将自然尺寸回收内容接入官方 Sliver 布局、绘制和命中协议。
class ElRenderSliverRecycler extends RenderSliver
    with
        ContainerRenderObjectMixin<RenderBox, _RecyclerParentData>,
        RenderSliverHelpers,
        RenderObjectWithLayoutCallbackMixin {
  ElRenderSliverRecycler._(this._element);

  final _RecyclerElement _element;
  _ExtentIndex? _extents;
  _RecyclerGridRows? _gridRows;
  _RecyclerMasonry? _masonry;
  int _geometryGeneration = -1;
  List<Object?> _geometryTypes = const [];
  ({bool masonry, int crossAxisCount, double mainAxisSpacing, double crossAxisSpacing})? _gridConfiguration;
  Axis? _axis;
  double? _crossExtent;
  bool _needsFirstMeasurement = true;
  ElSliverRecyclerController? _controller;
  _RevealRequest? _reveal;
  // 上次布局后的条目增删，按通知顺序记录 (起点, 增量)；负增量表示移除。
  final List<(int, int)> _shifts = [];

  void _shiftItems(int index, int delta) {
    _shifts.add((index, delta));
    scheduleLayoutCallback();
  }

  int _shiftedIndex(int index) {
    for (final (start, delta) in _shifts) {
      if (delta > 0) {
        if (index >= start) index += delta;
      } else if (index >= start - delta) {
        index += delta;
      } else if (index >= start) {
        index = start;
      }
    }
    return index;
  }

  set controller(ElSliverRecyclerController? value) {
    if (identical(_controller, value)) return;
    if (identical(_controller?._render, this)) _controller!._render = null;
    _controller = value;
    value?._render = this;
  }

  Future<bool> _requestReveal(int index, double alignment) {
    // 新请求覆盖尚未执行的旧请求，旧请求按未完成返回。
    _reveal?.complete(false);
    final request = _reveal = _RevealRequest(index, alignment);
    // 定位是一次跳转：先停下惯性、平滑滚轮等进行中的活动。
    if (parent case RenderViewportBase(:final ScrollPosition offset) when offset.hasPixels) {
      offset.jumpTo(offset.pixels);
    }
    scheduleLayoutCallback();
    return request.completer.future;
  }

  @override
  void dispose() {
    controller = null;
    _reveal?.complete(false);
    _reveal = null;
    super.dispose();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RecyclerParentData) child.parentData = _RecyclerParentData();
  }

  _RecyclerAnchor? _visibleAnchor() {
    if (constraints.remainingPaintExtent <= 0) return null;
    _RecyclerAnchor? result;
    final start = constraints.scrollOffset;
    final end = start + constraints.remainingPaintExtent;
    for (final entry in _element._active.entries) {
      if (entry.key >= _element._widget._childCount) continue;
      final data = entry.value.box!.parentData! as _RecyclerParentData;
      if (data.extent <= 0 || data.layoutOffset + data.extent <= start || data.layoutOffset >= end) continue;
      if (result == null || entry.key < result.index) {
        result = _RecyclerAnchor(entry.key, data.layoutOffset - start);
      }
    }
    return result;
  }

  @override
  void layoutCallback() {
    _element._prepareLayout();
    final widget = _element._widget;
    final count = widget._childCount;
    var anchor = _visibleAnchor();
    if (_shifts.isNotEmpty) {
      if (anchor != null) anchor = _RecyclerAnchor(_shiftedIndex(anchor.index), anchor.relativeStart);
      _shifts.clear();
    }
    final gridConfiguration = widget.columns != null
        ? (
            masonry: widget.masonry,
            crossAxisCount: widget.crossAxisCount,
            mainAxisSpacing: widget.mainAxisSpacing,
            crossAxisSpacing: widget.crossAxisSpacing,
          )
        : null;
    var reset =
        _extents?.length != count ||
        _axis != constraints.axis ||
        _crossExtent != constraints.crossAxisExtent ||
        _gridConfiguration != gridConfiguration;
    if (reset || _geometryGeneration != _element._generation) {
      // 路由或父级重建只刷新业务绑定；真实类型与几何配置未变时保留实测尺寸和列分配。
      final types = widget.itemType == null ? const <Object?>[] : List<Object?>.generate(count, widget.itemType!);
      reset |= !listEquals(_geometryTypes, types);
      _geometryTypes = types;
      _geometryGeneration = _element._generation;
    }
    if (reset) {
      final groups = <Object?, int>{};
      // 尺寸、类型估值和偏移反查使用同一份 Sliver 内部索引。
      _extents = _ExtentIndex.groups(
        _geometryTypes.isEmpty
            ? List<int>.filled(count, 0)
            : [for (final type in _geometryTypes) groups.putIfAbsent(type, () => groups.length)],
      );
      if (widget.columns != null) {
        _gridRows = widget.masonry ? null : _RecyclerGridRows(_extents!, widget.crossAxisCount, widget.mainAxisSpacing);
        _masonry = widget.masonry ? _RecyclerMasonry(_extents!, widget.crossAxisCount, widget.mainAxisSpacing) : null;
      } else {
        _gridRows = null;
        _masonry = null;
      }
      _gridConfiguration = gridConfiguration;
      _axis = constraints.axis;
      _crossExtent = constraints.crossAxisExtent;
      _needsFirstMeasurement = count > 0;
    }
    final extents = _extents!;
    if (count == 0) {
      _finishLayout({});
      geometry = SliverGeometry.zero;
      _reveal?.complete(false);
      _reveal = null;
      return;
    }

    if (widget.columns != null) {
      _layoutGrid(widget, anchor);
      return;
    }

    // 只约束交叉轴，主轴尺寸交给条目自身。
    final cross = constraints.crossAxisExtent;
    final childConstraints = constraints.axis == Axis.vertical
        ? BoxConstraints(minWidth: widget.stretch ? cross : 0, maxWidth: cross)
        : BoxConstraints(minHeight: widget.stretch ? cross : 0, maxHeight: cross);
    final spacing = widget.mainAxisSpacing;
    double startAt(int index) => extents.prefix(index) + index * spacing;
    double total() => extents.total + math.max(0, count - 1) * spacing;
    int indexAt(double pixels) => extents.indexAt(pixels, spacing: spacing);
    var pixels = constraints.scrollOffset;
    // 起点没有待保留的离屏内容；结构变化不能把旧索引锚点带到起点之后。
    if (pixels <= precisionErrorTolerance) anchor = _RecyclerAnchor(0, 0);
    void layoutPosition(int index) {
      // 绑定通知必须先完成 build，再读取新条目的真实尺寸。
      final child = _element._layoutItem(index, childConstraints);
      final extent = constraints.axis == Axis.vertical ? child.size.height : child.size.width;
      final changed = extents.measure(index, extent);
      if (changed && anchor != null) {
        pixels = math.max(0.0, startAt(anchor.index) - anchor.relativeStart);
      }
      (child.parentData! as _RecyclerParentData)
        ..layoutOffset = startAt(index)
        ..extent = extent;
    }

    _element.owner!.buildScope(_element, () {
      _element._recycleOutside(0, count - 1);
      _element._discardInvalidSpares();
    });
    if (_needsFirstMeasurement) {
      // 先测真实条目再定位，等高内容无需调用方提供任何尺寸提示。
      layoutPosition(anchor?.index ?? 0);
      _needsFirstMeasurement = false;
      if (anchor != null) pixels = math.max(0.0, startAt(anchor.index) - anchor.relativeStart);
    }
    if (_reveal case final reveal?) {
      _reveal = null;
      final index = reveal.index.clamp(0, count - 1);
      layoutPosition(index);
      final viewportExtent = constraints.viewportMainAxisExtent;
      final start = startAt(index);
      final lowest = -constraints.precedingScrollExtent;
      final target = (start - reveal.alignment * (viewportExtent - extents.extentAt(index)))
          .clamp(lowest, math.max(lowest, total() - viewportExtent))
          .toDouble();
      // 列表起点之前还有其他 Sliver 时 scrollOffset 恒为 0，需要按视口位置换算当前偏移。
      final current = switch (parent) {
        RenderViewportBase(:final offset) when offset.hasPixels => offset.pixels - constraints.precedingScrollExtent,
        _ => constraints.scrollOffset,
      };
      SchedulerBinding.instance.addPostFrameCallback((_) => reveal.complete(attached));
      if ((target - current).abs() > precisionErrorTolerance) {
        _finishLayout({index});
        geometry = SliverGeometry(scrollOffsetCorrection: target - current);
        return;
      }
    }
    if (anchor == null && pixels < total() && constraints.remainingPaintExtent > 0) {
      final index = indexAt(pixels);
      anchor = _RecyclerAnchor(index, startAt(index) - pixels);
    }

    double cacheStart() => math.max(0.0, pixels + constraints.cacheOrigin);
    double cacheEnd() => cacheStart() + constraints.remainingCacheExtent;
    final wanted = <int>{};
    if (constraints.remainingCacheExtent > 0 && (cacheStart() < total() || total() == 0)) {
      var first = total() == 0 ? 0 : indexAt(cacheStart());
      final last = indexAt(cacheEnd() - precisionErrorTolerance);
      _element.owner!.buildScope(_element, () => _element._recycleOutside(first, last));

      var next = first;
      // 补测前端也可能改变尾端的位置，两个方向都按最新实测边界填满。
      // 每次只推进到一个尚未布局的索引，最多访问 count 项，不依赖重试次数。
      while (true) {
        if (first > 0 && startAt(first) > cacheStart() + precisionErrorTolerance) {
          layoutPosition(--first);
          wanted.add(first);
          continue;
        }
        if (next >= count || (wanted.isNotEmpty && startAt(next) >= cacheEnd() - precisionErrorTolerance)) break;
        layoutPosition(next);
        wanted.add(next++);
      }
      wanted.removeWhere((index) {
        final data = _element._active[index]!.box!.parentData! as _RecyclerParentData;
        final start = startAt(index);
        return start >= cacheEnd() - precisionErrorTolerance ||
            (data.extent > 0
                ? start + data.extent + (index + 1 < count ? spacing : 0) <= cacheStart() + precisionErrorTolerance
                : start < cacheStart());
      });
    }
    _finishLayout(wanted);

    for (final slot in _element._active.values) {
      (slot.box!.parentData! as _RecyclerParentData)
        ..layoutOffset = startAt(slot.indexValue)
        ..crossAxisOffset = widget.center
            ? (cross - (constraints.axis == Axis.vertical ? slot.box!.size.width : slot.box!.size.height)) / 2
            : axisDirectionIsReversed(constraints.crossAxisDirection)
            ? cross - (constraints.axis == Axis.vertical ? slot.box!.size.width : slot.box!.size.height)
            : 0;
    }
    _completeGeometry(total(), pixels);
  }

  void _finishLayout(Set<int> wanted) {
    _element.owner!.buildScope(_element, () => _element._finishLayout(wanted));
    // 留池子树仍挂载：独立布局边界让嵌套 LayoutBuilder 的补建不经过已完成布局的 Sliver。
    // 先刷新停用 TickerMode 产生的构建，再清理脏布局链；复用时 _layoutItem 恢复尺寸依赖。
    for (final candidates in _element._pool.values) {
      for (final slot in candidates) {
        final box = slot.box;
        if (box != null && box.hasSize) box.layout(box.constraints, parentUsesSize: false);
      }
    }
  }

  void _completeGeometry(double total, double pixels) {
    final correction = pixels - constraints.scrollOffset;
    if (correction.abs() > precisionErrorTolerance) {
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }

    final paintExtent = calculatePaintOffset(constraints, from: 0, to: total);
    geometry = SliverGeometry(
      scrollExtent: total,
      paintExtent: paintExtent,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: total),
      maxPaintExtent: total,
      hasVisualOverflow: constraints.scrollOffset > 0 || total > constraints.remainingPaintExtent,
    );
    final direction = applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection);
    final reversed = direction == AxisDirection.up || direction == AxisDirection.left;
    for (final slot in _element._active.values) {
      final child = slot.box!;
      final data = child.parentData! as _RecyclerParentData;
      final logical = data.layoutOffset - constraints.scrollOffset;
      final position = reversed ? paintExtent - logical - data.extent : logical;
      data.offset = constraints.axis == Axis.vertical
          ? Offset(data.crossAxisOffset, position)
          : Offset(position, data.crossAxisOffset);
      if (child is _ItemRenderBoundary) child.visible = logical < paintExtent && logical + data.extent > 0;
    }
  }

  @override
  void performLayout() => runLayoutCallback();

  @override
  double childMainAxisPosition(RenderBox child) =>
      (child.parentData! as _RecyclerParentData).layoutOffset - constraints.scrollOffset;

  @override
  double childCrossAxisPosition(RenderBox child) => (child.parentData! as _RecyclerParentData).crossAxisOffset;

  @override
  double? childScrollOffset(RenderObject child) {
    final data = child.parentData! as _RecyclerParentData;
    return data.slot.active ? data.layoutOffset : null;
  }

  @override
  bool paintsChild(RenderObject child) {
    final data = child.parentData! as _RecyclerParentData;
    return data.slot.active &&
        geometry?.visible == true &&
        data.extent > 0 &&
        data.layoutOffset < constraints.scrollOffset + geometry!.paintExtent &&
        data.layoutOffset + data.extent > constraints.scrollOffset;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!geometry!.visible) return;
    for (final index in _element._visibleIndices) {
      final child = _element._active[index]?.box;
      if (child != null && paintsChild(child)) {
        context.paintChild(child, offset + (child.parentData! as _RecyclerParentData).offset);
      }
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    final extents = _extents;
    if (extents == null || extents.length == 0) return false;
    if (_element._widget.columns != null) {
      for (final index in _element._visibleIndices.reversed) {
        final child = _element._active[index]?.box;
        if (child != null &&
            paintsChild(child) &&
            hitTestBoxChild(
              BoxHitTestResult.wrap(result),
              child,
              mainAxisPosition: mainAxisPosition,
              crossAxisPosition: crossAxisPosition,
            )) {
          return true;
        }
      }
      return false;
    }
    final index = extents.indexAt(
      mainAxisPosition + constraints.scrollOffset,
      spacing: _element._widget.mainAxisSpacing,
    );
    final child = _element._active[index]?.box;
    return child != null &&
        paintsChild(child) &&
        hitTestBoxChild(
          BoxHitTestResult.wrap(result),
          child,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
        );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final data = child.parentData! as _RecyclerParentData;
    if (data.slot.active) {
      transform.translateByDouble(data.offset.dx, data.offset.dy, 0, 1);
    } else {
      transform.setZero();
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final index in _element._visibleIndices) {
      if (_element._active[index]?.box case final child?) visitor(child);
    }
  }
}

class _ItemBoundary extends SingleChildRenderObjectWidget {
  const _ItemBoundary({required this.slot, required this.repaintBoundary, required super.child});

  final _Slot slot;
  final bool repaintBoundary;

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) => _ItemRenderBoundary(repaintBoundary);

  @override
  void updateRenderObject(BuildContext context, _ItemRenderBoundary renderObject) {
    if (renderObject._repaintBoundary == repaintBoundary) return;
    renderObject._repaintBoundary = repaintBoundary;
    renderObject.markNeedsCompositingBitsUpdate();
    renderObject.markNeedsPaint();
  }

  @override
  void didUnmountRenderObject(covariant RenderRepaintBoundary renderObject) {
    // 在后代 State.dispose 完成后释放绑定，池淘汰时只 deactivate 还不够。
    slot.dispose();
  }
}

class _ItemRenderBoundary extends RenderRepaintBoundary {
  _ItemRenderBoundary(this._repaintBoundary);
  bool _repaintBoundary;

  @override
  bool get isRepaintBoundary => _repaintBoundary;

  bool _visible = false;

  bool get visible => _visible;

  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    // 取消离屏边界的旧图层挂接，避免脏子树在 flushPaint 中独立重画。
    if (!value) layer?.remove();
  }
}
