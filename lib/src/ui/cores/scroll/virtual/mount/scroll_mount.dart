// 滚动挂载快照、局部更新控制器与视口 Element。
// ignore_for_file: prefer_initializing_formals

part of '../virtual_pipeline.dart';

abstract final class _ScrollMount {
  static List<_VirtualIndexRange> mountedRanges(_ScrollMountSnapshot snapshot) {
    return _buildMountedRanges(
      firstIndex: snapshot.firstIndex,
      lastIndex: snapshot.lastIndex,
      keepAliveIndices: snapshot.keepAliveIndices,
      pinnedStickyIndex: snapshot.pinnedStickyIndex,
      children: snapshot.sourceChildren,
      residentRanges: [
        // 新宿主尚在测量首窗时保留已接回的 Element，避免 GlobalKey 跨容器移动被冷启动窗口拆掉。
        if (snapshot.keepAliveOwner._measuringInitialWindow)
          for (final index in snapshot.keepAliveOwner._contentController._element?._coldRestoredIndices ?? <int>{})
            _VirtualIndexRange(index, index + 1),
        for (final index in snapshot.keepAliveOwner._contentController._element?._builderKeepAliveIndices ?? <int>{})
          _VirtualIndexRange(index, index + 1),
        for (var s = 0; s < snapshot.sectionPlan.segments.length; s++)
          if (snapshot.sectionPlan.segments[s].resident)
            _VirtualIndexRange(
              snapshot.sectionPlan.itemStartOf(s),
              snapshot.sectionPlan.itemStartOf(s) + snapshot.sectionPlan.segments[s].itemCount,
            ),
      ],
    );
  }

  static List<_VirtualIndexRange> _buildMountedRanges({
    required int firstIndex,
    required int lastIndex,
    required Set<int> keepAliveIndices,
    required int? pinnedStickyIndex,
    required List<Widget> children,
    List<_VirtualIndexRange> residentRanges = const [],
  }) {
    // sticky pinned 与其他保活来源同口径 union，即使自然位置滚出可视窗口
    // 也保 element 树、保 State，达成"接力"必需的持续性。
    final hasStickyPinned = pinnedStickyIndex != null;
    if (keepAliveIndices.isEmpty && !hasStickyPinned && residentRanges.isEmpty) {
      final range = _normalizedMountedRange(firstIndex, lastIndex, children.length);
      return range == null ? const <_VirtualIndexRange>[] : <_VirtualIndexRange>[range];
    }

    // keep-alive index 收成单 index 的窄 range；跟可视窗口与 selection 保留
    // 一起走 sorted-merge，保证 element 树顺序按 index 递增。
    final sourceRanges = <_VirtualIndexRange>[
      _VirtualIndexRange(firstIndex, lastIndex),
      ...residentRanges,
      for (final index in keepAliveIndices) _VirtualIndexRange(index, index + 1),
      if (pinnedStickyIndex != null) _VirtualIndexRange(pinnedStickyIndex, pinnedStickyIndex + 1),
    ].where((range) => range.start < range.end).toList()..sort((a, b) => a.start.compareTo(b.start));

    final ranges = <_VirtualIndexRange>[];
    _VirtualIndexRange? merged;
    for (final range in sourceRanges) {
      final normalized = _normalizedMountedRange(range.start, range.end, children.length);
      if (normalized == null) continue;
      final current = merged;
      if (current == null) {
        merged = normalized;
      } else if (normalized.start <= current.end) {
        merged = _VirtualIndexRange(current.start, math.max(current.end, normalized.end));
      } else {
        ranges.add(current);
        merged = normalized;
      }
    }
    if (merged == null) return const <_VirtualIndexRange>[];
    ranges.add(merged);
    return ranges;
  }

  static _VirtualIndexRange? _normalizedMountedRange(int start, int end, int childCount) {
    final safeStart = start.clamp(0, childCount).toInt();
    final safeEnd = end.clamp(safeStart, childCount).toInt();
    return safeStart < safeEnd ? _VirtualIndexRange(safeStart, safeEnd) : null;
  }

  static void _updateRenderObjectFromSnapshot(_RenderVirtualViewport renderObject, _ScrollMountSnapshot snapshot) {
    renderObject
      ..contentAxis = snapshot.axis
      ..dualAxis = snapshot.dualAxis
      ..totalExtent = snapshot.totalExtent
      ..contentPadding = snapshot.padding
      ..gap = snapshot.gap
      ..crossAxisAlignment = snapshot.crossAxisAlignment
      ..minimumCrossAxisExtent = snapshot.minimumCrossAxisExtent
      ..firstIndex = snapshot.firstIndex
      ..lastIndex = snapshot.lastIndex
      ..dragOptimizeEnabled = snapshot.dragOptimizeEnabled
      ..pinToEnd = snapshot.pinToEnd
      ..preserveAnchor = snapshot.preserveAnchor
      ..sourceChildren = snapshot.sourceChildren
      ..sectionPlan = snapshot.sectionPlan
      ..measurementGeneration = snapshot.measurementGeneration
      ..reportMeasuredExtentsWhenUnchanged = snapshot.reportMeasuredExtentsWhenUnchanged
      ..extentIndex = snapshot.extentIndex
      ..onItemExtentsChanged = snapshot.onItemExtentsChanged
      ..onMeasurementsChanged = snapshot.onMeasurementsChanged;
  }
}

class _ScrollMountSnapshot {
  const _ScrollMountSnapshot({
    required this.axis,
    required this.dualAxis,
    required this.totalExtent,
    required this.padding,
    required this.gap,
    required this.crossAxisAlignment,
    required this.minimumCrossAxisExtent,
    required this.firstIndex,
    required this.lastIndex,
    required this.dragOptimizeEnabled,
    required this.pinToEnd,
    required this.preserveAnchor,
    required this.sourceChildren,
    required this.sectionPlan,
    required this.childrenRevision,
    required this.measurementGeneration,
    required this.reportMeasuredExtentsWhenUnchanged,
    required this.keepAliveIndices,
    required this.pinnedStickyIndex,
    required this.keepAliveOwner,
    required this.extentIndex,
    required this.onItemExtentsChanged,
    required this.onMeasurementsChanged,
  });

  final Axis axis;

  /// 双轴模式：content 给 items 无界交叉轴、交叉轴尺寸按 mounted maxCross 撑。
  final bool dualAxis;
  final double totalExtent;
  final EdgeInsets padding;
  final double gap;

  /// 成员交叉轴对齐（容器级，CSS align-items）；null = 沿轴向既有行为
  /// （vertical stretch / horizontal start）。grid cell 列几何不受影响。
  final CrossAxisAlignment? crossAxisAlignment;

  /// 自然交叉轴尺寸的额外下限；0 保持 mounted-only 默认语义。
  final double minimumCrossAxisExtent;
  final int firstIndex;
  final int lastIndex;

  /// 拖拽快路径开关（widget.dragOptimize != false）：content render 在 thumb
  /// 拖拽期据此决定可见边界跟 thumb 分数还是真实 position。
  final bool dragOptimizeEnabled;

  /// 贴末端跟随开关（[ElScrollView.pinToEnd]）：content render 的布局期测量
  /// 就地应用据此决定贴 max 边时钉住新 max 还是走锚点保位。
  final bool pinToEnd;

  /// 真实内容变化是否保留可见成员的位置，虚拟估高修正独立处理。
  final bool preserveAnchor;
  final List<Widget> sourceChildren;

  /// 统一段计划，提供视口布局所需的行号、列几何与固定行高。
  final SegmentPlan sectionPlan;

  /// State 侧 children 结构修订号（见 `_childrenRevision`）。
  final int childrenRevision;
  final int measurementGeneration;
  final bool reportMeasuredExtentsWhenUnchanged;

  /// 当前保活 index 集合的引用（不 copy——同一集合被 State 与 snapshot 共享，
  /// 变化对下一帧 reconcile 立即可见）。
  final Set<int> keepAliveIndices;

  /// 当前钉住的 sticky index（null = 无）；即使自然位置滚出可视窗口，
  /// mountedRanges 也要把它 union 进来，才能 paint / hit-test。
  final int? pinnedStickyIndex;

  /// 与保活 gate 通信的 State 引用；gate 用它注册/反注册 handle。
  final ElScrollViewState keepAliveOwner;
  final SegmentExtentIndex extentIndex;
  final void Function(Map<int, double> extents) onItemExtentsChanged;
  final void Function(int?, {required bool duringLayout}) onMeasurementsChanged;
}

class _ScrollMountController extends ChangeNotifier {
  _ScrollMountController(this._snapshot);

  _ScrollMountSnapshot get snapshot => _snapshot;

  _ScrollMountSnapshot _snapshot;
  _ScrollViewportElement? _element;
  bool _needsReconcile = false;

  bool get needsReconcile => _needsReconcile;

  void replaceSnapshot(_ScrollMountSnapshot snapshot) {
    _snapshot = snapshot;
    _needsReconcile = false;
  }

  void updateSnapshot(
    _ScrollMountSnapshot snapshot, {
    required bool reconcileChildren,
    bool forceLayout = false,
    bool notify = true,
  }) {
    _snapshot = snapshot;
    _needsReconcile = _needsReconcile || reconcileChildren;
    if (forceLayout) _element?.markRenderNeedsLayout();
    if (notify) notifyListeners();
  }

  void attachElement(_ScrollViewportElement element) {
    _element = element;
  }

  void detachElement(_ScrollViewportElement element) {
    if (!identical(_element, element)) return;
    _element = null;
  }

  void refreshParentDataForIndex(int index) {
    _element?.refreshParentDataForIndex(index);
  }

  bool takeNeedsReconcile() {
    final result = _needsReconcile;
    _needsReconcile = false;
    return result;
  }

  /// layout 期同帧对账：把快照落到 render 并（有需要时）就地重建 children。
  ///
  /// why：这是 LayoutBuilder 内核 build-during-layout 的等价物。走
  /// `buildScope(element)` 而非 markNeedsBuild——后者在 persistentCallbacks 相位
  /// 会被推到下一帧（晚一帧挂载事故的形态）。仅允许在视口 performLayout 的
  /// `invokeLayoutCallback` 窗口内调用（content element 是视口后代，合法）。
  void reconcileDuringLayout() {
    final element = _element;
    if (element == null || !element.mounted) return;
    element.owner!.buildScope(element, () {
      element.applyControllerSnapshotWithoutReconcile();
      if (takeNeedsReconcile()) element.reconcileChildrenDuringLayout();
    });
  }
}

class _ScrollViewportElement extends RenderObjectElement with NotifiableElementMixin, ViewportElementMixin {
  _ScrollViewportElement(_ScrollViewport super.widget);

  @override
  _ScrollViewport get widget => super.widget as _ScrollViewport;

  @override
  _RenderVirtualViewport get renderObject => super.renderObject as _RenderVirtualViewport;

  final List<Element?> _chromeChildren = [];
  Object? _builtChromeConfiguration;

  Object _chromeConfiguration() {
    final v = widget.scrollbarDetails[Axis.vertical];
    final h = widget.scrollbarDetails[Axis.horizontal];
    return (
      widget.scrollbar,
      v?.isScrollable,
      v?.viewportExtent,
      v?.axisDirection,
      h?.isScrollable,
      h?.viewportExtent,
      h?.axisDirection,
    );
  }

  void _handleChromeChanged() {
    if (!mounted || _builtChromeConfiguration == _chromeConfiguration()) return;
    _scheduleLocalRebuild();
  }

  bool _needsChromeReconcile() {
    if (widget.scrollbar is ElNoScrollBar && _chromeChildren.isEmpty) return false;
    return _builtChromeConfiguration != _chromeConfiguration();
  }

  void _reconcileChromeDuringLayout() => owner!.buildScope(this, _reconcileChrome);

  void _reconcileChrome() {
    if (widget.scrollbar is ElNoScrollBar && _chromeChildren.isEmpty) return;
    final configuration = _chromeConfiguration();
    if (_builtChromeConfiguration == configuration) return;
    _builtChromeConfiguration = configuration;
    final children = widget.scrollbar.buildChildren(this, widget.scrollbarDetails);
    final length = math.max(children.length, _chromeChildren.length);
    for (var index = 0; index < length; index++) {
      final previous = index < _chromeChildren.length ? _chromeChildren[index] : null;
      final next = updateChild(previous, index < children.length ? children[index] : null, _ScrollChromeSlot(index));
      if (index < _chromeChildren.length) {
        _chromeChildren[index] = next;
      } else {
        _chromeChildren.add(next);
      }
      final render = next?.renderObject;
      if (render is RenderBox) {
        final data = render.parentData! as _ScrollViewportParentData;
        data.isChrome = true;
        // 使用 JavaScript 安全整数，确保 Web 编译和末尾槽位排序均不丢失精度。
        renderObject.setChildStackSourceOrder(render, 0x1fffffffffffff - 3 + index);
      }
    }
    _chromeChildren.length = children.length;
  }

  final Map<Object, _LayoutBinding> _layouts = {};
  final Map<Element, LayoutViewElement> _layoutByChild = {};
  final Set<int> _builderKeepAliveIndices = {};
  SegmentPlan? _layoutPlan;

  /// 只迁移实际挂载过的条目，避免保活声明把整段 builder 提前物化。
  void _remapBuilderKeepAliveIndices(SegmentPlan plan) {
    _builderKeepAliveIndices.clear();
    final sections = <Object, int>{
      for (var section = 0; section < plan.segments.length; section++)
        if (plan.segments[section].view?.layoutKeepAlive == true) _layoutKey(plan, section): section,
    };
    if (sections.isEmpty) return;
    for (final entry in _childByKey.entries) {
      final parent = _layoutByChild[entry.value];
      if (parent == null) continue;
      final (layoutKey, identity) = entry.key as (Object, Object);
      final section = sections[layoutKey];
      if (section == null) continue;
      final segment = plan.segments[section];
      if (segment.view.runtimeType != parent.widget.runtimeType) continue;
      final source = switch (segment) {
        LinearSegment(:final source) || GridSegment(:final source) => source,
        StaticSegment() => throw StateError('布局段不能是普通成员'),
      };
      if (source is! BuilderItemSource) continue;
      final scope = entry.value.widget as _ScrollItemScope;
      final oldLocal = scope.index - (parent.binding! as _LayoutBinding).itemStart;
      // 分隔项按槽位保留，业务 key 回查只接收正文 key。
      final isSeparator = parent.widget.layoutSeparatorBuilder != null && oldLocal.isOdd;
      final local = identity is Key && source.findChildIndex != null && !isSeparator
          ? source.findChildIndex!(identity)
          : oldLocal;
      if (local != null && local >= 0 && local < source.itemCount) {
        _builderKeepAliveIndices.add(plan.itemStartOf(section) + local);
      }
    }
  }

  void _retainBuilderIndex(int index) {
    final plan = widget.controller.snapshot.sectionPlan;
    if (plan.segments[plan.segmentOfItem(index)].view?.layoutKeepAlive == true) {
      _builderKeepAliveIndices.add(index);
    }
  }

  Object _layoutKey(SegmentPlan plan, int section) {
    final view = plan.segments[section].view!;
    return view.key ?? (view.runtimeType, section);
  }

  Object _itemKey(int index, Widget child) {
    final plan = widget.controller.snapshot.sectionPlan;
    final section = plan.segmentOfItem(index);
    return plan.segments[section].view == null
        ? child.key ?? index
        : (_layoutKey(plan, section), child.key ?? index - plan.itemStartOf(section));
  }

  void _reconcileLayouts(_ScrollMountSnapshot snapshot) {
    final plan = snapshot.sectionPlan;
    if (identical(_layoutPlan, plan)) return;
    _remapBuilderKeepAliveIndices(plan);
    final active = <Object>{};
    for (var section = 0; section < plan.segments.length; section++) {
      final view = plan.segments[section].view;
      if (view == null) continue;
      final key = _layoutKey(plan, section);
      assert(active.add(key), 'ElScrollView 中的布局 View key 必须唯一。');
      active.add(key);
      final binding = _layouts.putIfAbsent(key, () => _LayoutBinding(this, section));
      binding.section = section;
      binding.itemStart = plan.itemStartOf(section);
      final previous = binding.element;
      updateChild(previous, view, _LayoutSlot(binding));
      if (snapshot.sourceChildren case FlatSegmentItemList flat) flat.attachSegmentContext(section, binding.element!);
    }
    for (final key in _layouts.keys.where((key) => !active.contains(key)).toList()) {
      final binding = _layouts.remove(key)!;
      final element = binding.element;
      if (element != null) {
        updateChild(element, null, null);
      }
    }
    _layoutPlan = plan;
  }

  void _refreshLayoutItems(_LayoutBinding binding) {
    final snapshot = widget.controller.snapshot;
    final layout = binding.element!;
    final indices = <int>[
      for (final entry in _indexByKey.entries)
        if (identical(_layoutByChild[_childByKey[entry.key]], layout)) entry.value,
    ]..sort();
    final active = <Object>{};
    final oldKeys = <Object>[for (final index in indices) _keyByIndex[index]!];
    for (final index in indices) {
      final child = snapshot.sourceChildren[index];
      final key = _itemKey(index, child);
      active.add(key);
      final previousKey = _keyByIndex[index - 1];
      final previous = _childByKey[previousKey];
      final old = _childByKey[key];
      final next = _updateItem(
        old,
        _wrapMountedChild(child, index: index, owner: snapshot.keepAliveOwner),
        _ScrollElementSlot(key, previous, sourceIndex: index),
      )!;
      if (old != null && !identical(old, next)) _keyByChild.remove(old);
      _childByKey[key] = next;
      _keyByChild[next] = key;
      _indexByKey[key] = index;
      _keyByIndex[index] = key;
      _selectionIdentityByKey[key] = key;
      _widgetByKey[key] = child;
      _refreshChildParentData(next, index: index, selectionIdentityId: key);
    }
    for (final key in oldKeys) {
      if (active.contains(key)) continue;
      final child = _childByKey[key]!;
      _updateItem(child, null, null);
      forgetChild(child);
    }
  }

  void _releaseLayoutItems(LayoutViewElement layout) {
    final children = _layoutByChild.keys.where((child) => identical(_layoutByChild[child], layout)).toList();
    for (final child in children) {
      forgetChild(child);
    }
  }

  Element? _updateItem(Element? oldChild, Widget? next, Object? slot) {
    final previousParent = oldChild == null ? null : _layoutByChild[oldChild];
    LayoutViewElement? parent;
    if (next != null) {
      final index = (slot as _ScrollElementSlot).sourceIndex!;
      final plan = widget.controller.snapshot.sectionPlan;
      final section = plan.segmentOfItem(index);
      if (plan.segments[section].view != null) parent = _layouts[_layoutKey(plan, section)]!.element!;
    }
    if (oldChild != null && next != null && previousParent != parent) {
      if (previousParent == null) {
        updateChild(oldChild, null, null);
      } else {
        previousParent.updateHostedChild(oldChild, null, null);
      }
      _layoutByChild.remove(oldChild);
      oldChild = null;
    }
    final owner = next == null ? previousParent : parent;
    final result = owner == null ? updateChild(oldChild, next, slot) : owner.updateHostedChild(oldChild, next, slot);
    if (oldChild != null && !identical(oldChild, result)) _layoutByChild.remove(oldChild);
    if (result != null && owner != null) _layoutByChild[result] = owner;
    if (result != null && next != null) _retainBuilderIndex((slot as _ScrollElementSlot).sourceIndex!);
    return result;
  }

  final Map<Object, Element> _childByKey = <Object, Element>{};
  Set<int>? _coldRestoredIndices;
  final Map<Element, Object> _keyByChild = <Element, Object>{};
  final Map<Object, int> _indexByKey = <Object, int>{};
  final Map<int, Object> _keyByIndex = <int, Object>{};
  final Map<Object, Object> _selectionIdentityByKey = <Object, Object>{};
  final Map<Object, Widget> _widgetByKey = <Object, Widget>{};
  final Set<Object> _activeKeysScratch = <Object>{};
  final List<Object> _staleKeysScratch = <Object>[];
  bool _buildScheduled = false;

  // 上一次 reconcile 落定的基线：增量快路径用它判定"窗口只是平移"。
  List<_VirtualIndexRange>? _lastReconcileRanges;
  List<Widget>? _lastReconcileSourceChildren;
  int _lastReconcileChildrenRevision = -1;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    widget.controller.attachElement(this);
    widget.controller.addListener(_handleControllerChanged);
    renderObject.onLayoutChrome = _reconcileChromeDuringLayout;
    renderObject.needsChromeReconcile = _needsChromeReconcile;
    widget.scrollbarDetails.addListener(_handleChromeChanged);
    _reconcileChrome();
    _reconcileChildren();
  }

  @override
  void update(_ScrollViewport newWidget) {
    final oldController = widget.controller;
    final oldDetails = widget.scrollbarDetails;
    super.update(newWidget);
    if (!identical(oldDetails, newWidget.scrollbarDetails)) {
      oldDetails.removeListener(_handleChromeChanged);
      newWidget.scrollbarDetails.addListener(_handleChromeChanged);
    }
    _builtChromeConfiguration = null;
    _reconcileChrome();
    if (!identical(oldController, newWidget.controller)) {
      oldController.removeListener(_handleControllerChanged);
      oldController.detachElement(this);
      newWidget.controller.attachElement(this);
      newWidget.controller.addListener(_handleControllerChanged);
    }
    _reconcileChildren();
  }

  @override
  void unmount() {
    widget.scrollbarDetails.removeListener(_handleChromeChanged);
    renderObject.onLayoutChrome = null;
    renderObject.needsChromeReconcile = null;
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.detachElement(this);
    super.unmount();
  }

  @override
  void performRebuild() {
    super.performRebuild();
    _reconcileChrome();
    if (widget.controller.takeNeedsReconcile()) {
      _reconcileChildren();
    }
  }

  void _handleControllerChanged() {
    _updateRenderFromController();
    if (!widget.controller.needsReconcile) return;
    _scheduleLocalRebuild();
  }

  void applyControllerSnapshotWithoutReconcile() {
    _updateRenderFromController();
  }

  /// 供 controller 在 layout 窗口内直调的对账入口（私有 _reconcileChildren 的
  /// 包内可见转发）。
  void reconcileChildrenDuringLayout() {
    _reconcileChildren();
  }

  void markRenderNeedsLayout() {
    renderObject.markNeedsLayout();
  }

  void refreshParentDataForIndex(int index) {
    final key = _keyByIndex[index];
    final child = key == null ? null : _childByKey[key];
    if (child == null) return;
    final identity = _selectionIdentityByKey[key] ?? index;
    _refreshChildParentData(child, index: index, selectionIdentityId: identity);
  }

  void _updateRenderFromController() {
    _ScrollMount._updateRenderObjectFromSnapshot(renderObject, widget.controller.snapshot);
  }

  void _scheduleLocalRebuild() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks) {
      markNeedsBuild();
      return;
    }
    if (_buildScheduled) return;
    _buildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildScheduled = false;
      if (mounted) markNeedsBuild();
    });
  }

  @override
  void forgetChild(Element child) {
    if (child is LayoutViewElement) {
      _layouts.removeWhere((_, binding) => identical(binding.element, child));
      _layoutPlan = null;
    }
    final key = _keyByChild.remove(child);
    _layoutByChild.remove(child);
    if (key != null) {
      _childByKey.remove(key);
      final index = _indexByKey.remove(key);
      if (index != null && _keyByIndex[index] == key) {
        _keyByIndex.remove(index);
        _builderKeepAliveIndices.remove(index);
      }
      _selectionIdentityByKey.remove(key);
      _widgetByKey.remove(key);
    }
    super.forgetChild(child);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    final children = _childByKey.values.toList(growable: false);
    for (final child in children) {
      if (!_layoutByChild.containsKey(child)) visitor(child);
    }
    for (final binding in _layouts.values) {
      final element = binding.element;
      if (element != null) visitor(element);
    }
    for (final child in _chromeChildren) {
      if (child != null) visitor(child);
    }
  }

  void _reconcileChildren() {
    final snapshot = widget.controller.snapshot;
    _reconcileLayouts(snapshot);
    if (!snapshot.keepAliveOwner._measuringInitialWindow) _coldRestoredIndices = null;
    final ranges = _ScrollMount.mountedRanges(widget.controller.snapshot);
    if (_tryIncrementalReconcile(snapshot, ranges)) return;
    final sourceChildren = snapshot.sourceChildren;
    if (_scrollDebugCountersEnabled) {
      var mountedChildCount = 0;
      for (final range in ranges) {
        mountedChildCount += range.end - range.start;
      }
      snapshot.keepAliveOwner._debugCounters!.recordMountedChildCount(mountedChildCount);
    }
    final activeKeys = _activeKeysScratch..clear();

    Element? previousChild;
    var updateChildCount = 0;
    var reuseChildCount = 0;
    var slotMoveCount = 0;

    for (final range in ranges) {
      for (var index = range.start; index < range.end; index++) {
        final child = sourceChildren[index];
        final key = _itemKey(index, child);
        final selectionIdentityId = key;
        activeKeys.add(key);
        final oldChild = _childByKey.remove(key);
        final slot = _slotFor(key, previousChild, oldChild, sourceIndex: index);
        Element? newChild;
        if (oldChild != null &&
            _canReuseChildWithoutWidgetUpdate(
              oldChild,
              key: key,
              index: index,
              selectionIdentityId: selectionIdentityId,
              child: child,
            )) {
          if (oldChild.slot != slot) {
            final parent = _layoutByChild[oldChild];
            if (parent == null) {
              updateSlotForChild(oldChild, slot);
            } else {
              parent.updateHostedSlot(oldChild, slot);
            }
            if (_scrollDebugCountersEnabled) slotMoveCount++;
          }
          newChild = oldChild;
          if (_scrollDebugCountersEnabled) reuseChildCount++;
        } else {
          newChild = _updateItem(
            oldChild,
            _wrapMountedChild(child, index: index, owner: snapshot.keepAliveOwner),
            slot,
          );
          if (_scrollDebugCountersEnabled) updateChildCount++;
        }
        if (newChild == null) {
          if (oldChild != null) {
            _keyByChild.remove(oldChild);
            _indexByKey.remove(key);
            _selectionIdentityByKey.remove(key);
            _widgetByKey.remove(key);
          }
          continue;
        }
        if (oldChild != null && !identical(oldChild, newChild)) {
          _keyByChild.remove(oldChild);
        }
        _refreshChildParentData(newChild, index: index, selectionIdentityId: selectionIdentityId);
        _childByKey[key] = newChild;
        _keyByChild[newChild] = key;
        _indexByKey[key] = index;
        _keyByIndex[index] = key;
        _selectionIdentityByKey[key] = selectionIdentityId;
        _widgetByKey[key] = child;
        previousChild = newChild;
      }
    }

    final staleKeys = _staleKeysScratch..clear();
    for (final key in _childByKey.keys) {
      if (!activeKeys.contains(key)) staleKeys.add(key);
    }
    for (final key in staleKeys) {
      final child = _childByKey.remove(key);
      if (child == null) continue;
      _keyByChild.remove(child);
      _indexByKey.remove(key);
      _selectionIdentityByKey.remove(key);
      _widgetByKey.remove(key);
      _updateItem(child, null, null);
    }
    activeKeys.clear();
    staleKeys.clear();
    // index→key 反查表全量重建（stale 清扫后 _indexByKey 即真集）；增量路径
    // 依赖它做边界锚点定位与退出行免物化查键。
    _keyByIndex.clear();
    _indexByKey.forEach((key, index) => _keyByIndex[index] = key);
    _commitReconcileBaseline(snapshot, ranges);
    if (_scrollDebugCountersEnabled) {
      widget.controller.snapshot.keepAliveOwner._debugCounters!.recordContentReconcile(
        updateChildCount: updateChildCount,
        reuseChildCount: reuseChildCount,
        slotMoveCount: slotMoveCount,
      );
    }
  }

  void _commitReconcileBaseline(_ScrollMountSnapshot snapshot, List<_VirtualIndexRange> ranges) {
    _lastReconcileRanges = ranges;
    _lastReconcileSourceChildren = snapshot.sourceChildren;
    _lastReconcileChildrenRevision = snapshot.childrenRevision;
  }

  /// 增量 reconcile 快路径（含常驻多区间形态）。
  ///
  /// 条件：children identity / revision 未变，且新旧 mounted 集
  /// 相交。对两个有序区间集做**区间差分**：退出差集 unmount、进入差集升序
  /// mount（锚点取新集内前驱），保留行**零操作**——旧实现每次窗口平移都对
  /// 全 mounted 集做 5 张 map 的 remove/insert 与复用判定，记账成本与真实
  /// mount 同量级。常驻成员（keepAlive / preLayout / sticky 钉住 / selection
  /// 保留）造成的多区间形态同样走本路径，不再退回全量（否则一个保活 item
  /// 就把 P0 优化永久打回全量路径）。保留行的 element slot 允许暂时陈旧
  /// （只在下一次全量路径被比对，比对失败也只产生一次 no-op move）。
  /// 记账失衡（GlobalKey 抢子 / forgetChild）或进入段锚点缺失，动树前先验
  /// 发现即返回 false 走全量路径自愈。
  bool _tryIncrementalReconcile(_ScrollMountSnapshot snapshot, List<_VirtualIndexRange> ranges) {
    final lastRanges = _lastReconcileRanges;
    if (lastRanges == null) return false;
    if (!identical(snapshot.sourceChildren, _lastReconcileSourceChildren)) return false;
    // 原地改同一 List 实例的形态靠 revision 兜底——identity 判不出来。
    if (snapshot.childrenRevision != _lastReconcileChildrenRevision) return false;
    if (ranges.isEmpty || lastRanges.isEmpty) return false;
    // 完全不相交的大跳转走全量（重建反查表更划算）。
    if (ranges.last.end <= lastRanges.first.start || ranges.first.start >= lastRanges.last.end) return false;
    // 失衡防御：GlobalKey 抢子 / forgetChild 会让映射数偏离基线，全量自愈。
    var lastTotal = 0;
    for (final range in lastRanges) {
      lastTotal += range.end - range.start;
    }
    if (_childByKey.length != lastTotal) return false;

    final exits = _subtractRanges(lastRanges, ranges);
    final enters = _subtractRanges(ranges, lastRanges);

    // 动树前先验每个进入段的锚点：前驱 index 要么当前已 mounted，要么落在
    // 更早的进入段里（升序处理时届时已 mount）。
    for (final enter in enters) {
      final predecessor = _predecessorIndexInRanges(ranges, enter.start);
      if (predecessor == null) continue;
      if (_keyByIndex.containsKey(predecessor)) continue;
      var coveredByEarlierEnter = false;
      for (final other in enters) {
        if (other.start >= enter.start) break;
        if (predecessor >= other.start && predecessor < other.end) {
          coveredByEarlierEnter = true;
          break;
        }
      }
      if (!coveredByEarlierEnter) return false;
    }

    final sourceChildren = snapshot.sourceChildren;
    var updateChildCount = 0;

    void unmountIndex(int index) {
      final key = _keyByIndex.remove(index);
      if (key == null) return;
      final element = _childByKey.remove(key);
      _indexByKey.remove(key);
      _selectionIdentityByKey.remove(key);
      _widgetByKey.remove(key);
      if (element == null) return;
      _keyByChild.remove(element);
      _updateItem(element, null, null);
    }

    Element? mountIndex(int index, Element? previous) {
      final child = sourceChildren[index];
      final key = _itemKey(index, child);
      final selectionIdentityId = key;
      if (_scrollDebugCountersEnabled) updateChildCount++;
      final newChild = _updateItem(
        null,
        _wrapMountedChild(child, index: index, owner: snapshot.keepAliveOwner),
        _ScrollElementSlot(key, previous, sourceIndex: index),
      );
      if (newChild == null) return previous;
      _refreshChildParentData(newChild, index: index, selectionIdentityId: selectionIdentityId);
      _childByKey[key] = newChild;
      _keyByChild[newChild] = key;
      _indexByKey[key] = index;
      _keyByIndex[index] = key;
      _selectionIdentityByKey[key] = selectionIdentityId;
      _widgetByKey[key] = child;
      return newChild;
    }

    // 先卸载全部退出差集，再升序挂载进入差集（锚点此时已全部可解）。
    for (final exit in exits) {
      for (var index = exit.start; index < exit.end; index++) {
        unmountIndex(index);
      }
    }
    for (final enter in enters) {
      final predecessor = _predecessorIndexInRanges(ranges, enter.start);
      Element? previous = predecessor == null ? null : _childByKey[_keyByIndex[predecessor]];
      for (var index = enter.start; index < enter.end; index++) {
        previous = mountIndex(index, previous);
      }
    }

    _lastReconcileRanges = ranges;
    if (_scrollDebugCountersEnabled) {
      var mountedChildCount = 0;
      for (final range in ranges) {
        mountedChildCount += range.end - range.start;
      }
      final counters = snapshot.keepAliveOwner._debugCounters!;
      counters.recordMountedChildCount(mountedChildCount);
      counters.debugContentIncrementalReconcileCount++;
      widget.controller.snapshot.keepAliveOwner._debugCounters!.recordContentReconcile(
        updateChildCount: updateChildCount,
        reuseChildCount: mountedChildCount - updateChildCount,
        slotMoveCount: 0,
      );
    }
    return true;
  }

  /// 有序非重叠区间集减法：`from \ minus`，结果仍为有序非重叠区间。
  /// 复杂度 O(|from| + |minus|)，产出总长度 = 差集 index 数。
  static List<_VirtualIndexRange> _subtractRanges(List<_VirtualIndexRange> from, List<_VirtualIndexRange> minus) {
    final result = <_VirtualIndexRange>[];
    var mi = 0;
    for (final f in from) {
      var start = f.start;
      while (start < f.end) {
        while (mi < minus.length && minus[mi].end <= start) {
          mi++;
        }
        if (mi >= minus.length || minus[mi].start >= f.end) {
          result.add(_VirtualIndexRange(start, f.end));
          break;
        }
        final m = minus[mi];
        if (m.start > start) result.add(_VirtualIndexRange(start, m.start));
        start = m.end;
      }
    }
    return result;
  }

  /// [index]（必须落在 [ranges] 内）在区间集里的前驱 index；无前驱返回 null。
  static int? _predecessorIndexInRanges(List<_VirtualIndexRange> ranges, int index) {
    for (var i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      if (index >= range.start && index < range.end) {
        if (index > range.start) return index - 1;
        return i > 0 ? ranges[i - 1].end - 1 : null;
      }
    }
    return null;
  }

  bool _canReuseChildWithoutWidgetUpdate(
    Element oldChild, {
    required Object key,
    required int index,
    required Object selectionIdentityId,
    required Widget child,
  }) {
    final snapshot = widget.controller.snapshot;
    if (!identical(_widgetByKey[key], child)) return false;
    if (_indexByKey[key] != index || _selectionIdentityByKey[key] != selectionIdentityId) return false;
    // 复用要求已挂载顶层结构与本帧应生成的 wrapping 精确一致——index 变化
    // 需要 updateChild 走完整路径。直接核对（ItemScope → child），与
    // [_wrapMountedChild] 的装配一一对应，不构造 expected 实例。
    final mounted = oldChild.widget;
    if (mounted is! _ScrollItemScope) return false;
    if (mounted.index != index || !identical(mounted.owner, snapshot.keepAliveOwner) || mounted.identity != key) {
      return false;
    }
    return identical(mounted.child, child);
  }

  /// 挂载时只增加没有 RenderObject 的私有 item scope。
  /// scope 没有 RenderObject/State；未消费它的业务 item 只多一个既有
  /// InheritedElement，不创建 handle 或 listener。
  Widget _wrapMountedChild(Widget child, {required int index, required ElScrollViewState owner}) {
    return _ScrollItemScope(owner: owner, index: index, identity: _itemKey(index, child), child: child);
  }

  _ScrollElementSlot _slotFor(Object key, Element? previousChild, Element? oldChild, {int? sourceIndex}) {
    final oldSlot = oldChild?.slot;
    if (oldSlot is _ScrollElementSlot &&
        oldSlot.key == key &&
        oldSlot.sourceIndex == sourceIndex &&
        identical(oldSlot.previousChild, previousChild)) {
      return oldSlot;
    }
    return _ScrollElementSlot(key, previousChild, sourceIndex: sourceIndex);
  }

  void _refreshChildParentData(Element child, {required int index, required Object selectionIdentityId}) {
    final renderObject = child.renderObject;
    if (renderObject == null) return;
    final parentData = renderObject.parentData;
    if (parentData is! _ScrollViewportParentData) return;
    var changed = false;
    if (parentData.index != index) {
      parentData.index = index;
      changed = true;
    }
    if (parentData.selectionIdentityId != selectionIdentityId) {
      parentData.selectionIdentityId = selectionIdentityId;
      changed = true;
    }
    // sticky 不再识别顶层 Widget 类型，直接读取 item client 登记表。
    final stickyOffset = widget.controller.snapshot.keepAliveOwner._stickyByIndex[index];
    final header = widget.controller.snapshot.keepAliveOwner._viewportHeaderOwners?.containsKey(index) ?? false;
    if (parentData.isViewportHeader != header) {
      parentData.isViewportHeader = header;
      changed = true;
    }
    if (parentData.stickyOffset != stickyOffset) {
      parentData.stickyOffset = stickyOffset;
      changed = true;
    }
    (renderObject.parent as _RenderVirtualViewport).setChildStackSourceOrder(renderObject as RenderBox, index);
    if (!changed) return;
    final targetParent = renderObject.parent;
    if (targetParent is _RenderVirtualViewport) {
      targetParent.markNeedsLayoutForChildParentData();
    } else if (targetParent is RenderObject) {
      targetParent.markNeedsLayout();
    }
  }

  RenderBox? _lastContentRenderChild() {
    var child = renderObject.lastChild;
    while (child != null && (child.parentData! as _ScrollViewportParentData).isChrome) {
      child = (child.parentData! as _ScrollViewportParentData).previousSibling;
    }
    return child;
  }

  RenderBox? _previousRenderForSlot(Object slot, RenderObject child) {
    Element? previous;
    if (slot is _ScrollChromeSlot) {
      if (slot.index == 0) return _lastContentRenderChild();
      previous = _chromeChildren[slot.index - 1];
    } else if (slot is _ScrollElementSlot) {
      previous = slot.previousChild;
      final index = slot.sourceIndex;
      if (index != null && _indexByKey.containsKey(slot.key)) {
        // 增量窗口允许保留成员的旧 slot；内部根换代时重新定位活着的前驱，
        // 不读取已离屏销毁的 Element，也不把新根误插到整个窗口之前。
        final ranges = _ScrollMount.mountedRanges(widget.controller.snapshot);
        final predecessor = _predecessorIndexInRanges(ranges, index);
        previous = predecessor == null ? null : _childByKey[_keyByIndex[predecessor]];
      }
    } else {
      throw StateError('未知滚动成员 slot');
    }
    final render = previous?.mounted == true ? previous!.renderObject : null;
    if (identical(render, child)) return (child.parentData! as _ScrollViewportParentData).previousSibling;
    return render is RenderBox && identical(render.parent, renderObject) ? render : null;
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object slot) {
    if (slot is _LayoutSlot) {
      renderObject.addLayout(slot.binding, child as RenderLayoutView);
      return;
    }
    final previous = _previousRenderForSlot(slot, child);
    renderObject.setupParentData(child as RenderBox);
    final data = child.parentData! as _ScrollViewportParentData;
    if (slot is _ScrollChromeSlot) {
      data.isChrome = true;
      // 与更新路径保持一致，避免超过 JavaScript 的精确整数范围。
      data.mountOrder = 0x1fffffffffffff - 3 + slot.index;
    } else if (slot is _ScrollElementSlot) {
      // 成员内部 GlobalKey 换父或根 RenderBox 替换不经过外层 reconcile，
      // 必须在直接插入时恢复既有 slot 的索引、选区和 sticky 元数据。
      data.isChrome = false;
      final index = slot.sourceIndex ?? _indexByKey[slot.key];
      if (index != null) {
        data.index = index;
        data.selectionIdentityId = _selectionIdentityByKey[slot.key] ?? slot.key;
        data.stickyOffset = widget.controller.snapshot.keepAliveOwner._stickyByIndex[index];
        data.isViewportHeader =
            widget.controller.snapshot.keepAliveOwner._viewportHeaderOwners?.containsKey(index) ?? false;
        data.mountOrder = index;
      }
    }
    renderObject.insert(child, after: previous);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object oldSlot, Object newSlot) {
    if (newSlot is _LayoutSlot) return;
    final previous = _previousRenderForSlot(newSlot, child);
    renderObject.move(child as RenderBox, after: previous);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    if (child is RenderLayoutView && slot is _LayoutSlot) {
      renderObject.removeLayout(slot.binding, child);
    } else {
      renderObject.remove(child as RenderBox);
    }
  }
}

final class _ScrollChromeSlot {
  const _ScrollChromeSlot(this.index);
  final int index;
  @override
  bool operator ==(Object other) => other is _ScrollChromeSlot && other.index == index;
  @override
  int get hashCode => index.hashCode;
}

// 一个布局段只有一个真实 View 宿主，条目直接进入统一视口。
final class _LayoutBinding implements LayoutViewBinding {
  _LayoutBinding(this.owner, this.section);
  final _ScrollViewportElement owner;
  int section;
  int itemStart = 0;
  @override
  LayoutViewElement? element;
  @override
  Axis get axis => owner.widget.controller.snapshot.axis;
  @override
  bool get reverse => owner.widget.controller.snapshot.keepAliveOwner.widget.reverse;
  @override
  void attach(LayoutViewElement value) => element = value;
  @override
  void releaseChildren(LayoutViewElement view) => owner._releaseLayoutItems(view);

  @override
  void restoreChildren(LayoutViewElement view, LayoutViewBinding previous) {
    final old = previous as _LayoutBinding;
    final children = <Element>[];
    view.visitChildren(children.add);
    children.sort((a, b) => (a.widget as _ScrollItemScope).index.compareTo((b.widget as _ScrollItemScope).index));
    for (final child in children) {
      final scope = child.widget as _ScrollItemScope;
      final index = itemStart + scope.index - old.itemStart;
      final key = owner._itemKey(index, scope.child);
      final ranges = _ScrollMount.mountedRanges(owner.widget.controller.snapshot);
      final predecessor = _ScrollViewportElement._predecessorIndexInRanges(ranges, index);
      final before = predecessor == null ? null : owner._childByKey[owner._keyByIndex[predecessor]];
      owner._layoutByChild[child] = view;
      owner._childByKey[key] = child;
      owner._keyByChild[child] = key;
      owner._indexByKey[key] = index;
      owner._keyByIndex[index] = key;
      owner._selectionIdentityByKey[key] = key;
      owner._widgetByKey[key] = scope.child;
      owner._retainBuilderIndex(index);
      if (owner.widget.controller.snapshot.keepAliveOwner._measuringInitialWindow) {
        (owner._coldRestoredIndices ??= <int>{}).add(index);
      }
      child.attachRenderObject(_ScrollElementSlot(key, before, sourceIndex: index));
    }
  }

  @override
  void dependenciesChanged() {
    final flat = owner.widget.controller.snapshot.sourceChildren as FlatSegmentItemList;
    flat.invalidateSection(section);
    final segment = flat.plan.segments[section];
    if (segment is LinearSegment && segment.fixed != null) {
      segment.fixed!.item.measuredGeneration = null;
      segment.fixed!.separator.measuredGeneration = null;
    }
    // 由 View 自己的 build 更新后代，避免在后代 build 中标脏祖先。
    owner._refreshLayoutItems(this);
    owner.renderObject.markNeedsLayout();
  }

  @override
  void detach(LayoutViewElement value) {
    if (identical(element, value)) element = null;
  }

  @override
  void insertChild(RenderBox child, Object? slot) => owner.insertRenderObjectChild(child, slot!);
  @override
  void moveChild(RenderBox child, Object? oldSlot, Object? newSlot) =>
      owner.moveRenderObjectChild(child, oldSlot!, newSlot!);
  @override
  void removeChild(RenderBox child, Object? slot) => owner.removeRenderObjectChild(child, slot);
  @override
  void forgetChild(Element child) => owner.forgetChild(child);
}

final class _LayoutSlot implements LayoutViewSlot {
  const _LayoutSlot(this.binding);
  @override
  final _LayoutBinding binding;
  @override
  bool operator ==(Object other) => other is _LayoutSlot && identical(other.binding, binding);
  @override
  int get hashCode => identityHashCode(binding);
}
