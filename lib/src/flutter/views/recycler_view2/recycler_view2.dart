import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../recycler_view/extent_index.dart';

/// 用构建器声明条目、按类型回收子树的不定高列表。
///
/// 滚动到新序号时会再次调用 [itemBuilder]，并用返回的控件更新原来的 [Element]。
/// 根控件的类型和 [Key] 不变时，[State] 与渲染对象继续复用，只走
/// [State.didUpdateWidget] 和 [build]。根控件不要使用随序号变化的 [Key]，
/// 否则 Flutter 会拆掉旧元素并重新挂载。条目自己放在 [State] 里的临时数据，
/// 需要在 [State.didUpdateWidget] 中按新的 [Widget] 重置。
class ElRecyclerView2 extends StatelessWidget {
  /// 创建纵向或横向的回收列表。
  const ElRecyclerView2({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemType,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding = EdgeInsets.zero,
    this.cacheExtent = 250,
    this.maxRecycledItems = 32,
  }) : assert(itemCount >= 0),
       assert(cacheExtent >= 0),
       assert(maxRecycledItems >= 0);

  /// 当前数据条目数量。
  final int itemCount;

  /// 按序号创建条目配置，换绑时会用新的返回值更新已有元素。
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// 返回可相互复用的结构类型，未指定时所有条目共用一个回收池。
  ///
  /// 同一类型里混用不同的根控件类型时，Flutter 无法更新旧元素，只能重新挂载。
  /// 尚未测量的条目按该类型第一次测到的主轴尺寸估算总长，高度规律不同时应分成不同类型。
  final Object? Function(int index)? itemType;

  /// 外部滚动控制器，由调用方释放；未传入时由滚动视图自己管理。
  final ScrollController? controller;

  /// 滚动方向。
  final Axis scrollDirection;

  /// 是否从内容末端开始排列。
  final bool reverse;

  /// 列表内边距。
  final EdgeInsetsGeometry padding;

  /// 可视区域之外预先挂载的像素距离。
  final double cacheExtent;

  /// 所有类型合计最多保留的空闲槽位，不包含当前窗口中的条目。
  final int maxRecycledItems;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      scrollDirection: scrollDirection,
      reverse: reverse,
      scrollCacheExtent: ScrollCacheExtent.pixels(cacheExtent),
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: _RecyclerSliver(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
            itemType: itemType,
            maxRecycledItems: maxRecycledItems,
          ),
        ),
      ],
    );
  }
}

class _RecyclerSliver extends RenderObjectWidget {
  const _RecyclerSliver({
    required this.itemCount,
    required this.itemBuilder,
    required this.itemType,
    required this.maxRecycledItems,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Object? Function(int index)? itemType;
  final int maxRecycledItems;

  @override
  RenderObjectElement createElement() => _RecyclerElement(this);

  @override
  RenderSliver createRenderObject(BuildContext context) => _RenderRecyclerSliver(context as _RecyclerElement);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderRecyclerSliver renderObject) {
    renderObject.scheduleLayoutCallback();
  }
}

/// 把最新序号交给构建器，让返回的控件去更新槽位里原来的子元素。
class _ItemContent extends StatelessWidget {
  _ItemContent({required this.index, required this.builder});

  final int index;
  final Widget Function(BuildContext context, int index) builder;

  @override
  Widget build(BuildContext context) => builder(context, index);
}

class _Slot {
  _Slot(this.type, this.index);

  final Object? type;
  int index;
  final FocusNode focusNode = FocusNode(canRequestFocus: false, skipTraversal: true);
  Element? child;
  RenderBox? box;
  int generation = -1;
  bool active = false;

  void dispose() => focusNode.dispose();
}

class _RecyclerElement extends RenderObjectElement {
  _RecyclerElement(_RecyclerSliver super.widget);

  final Set<_Slot> _slots = {};
  final Map<int, _Slot> _active = {};
  final Map<Object?, List<_Slot>> _pool = {};
  late final BuildScope _scope = BuildScope(scheduleRebuild: _scheduleRebuild);
  int _generation = 0;
  int _laidOutGeneration = -1;
  int _firstIndex = 0;
  int _lastIndex = -1;
  bool _deferredRebuild = false;

  _RecyclerSliver get _widget => widget as _RecyclerSliver;

  @override
  BuildScope get buildScope => _scope;

  @override
  _RenderRecyclerSliver get renderObject => super.renderObject as _RenderRecyclerSliver;

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
  void update(covariant _RecyclerSliver newWidget) {
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
    for (var index = _firstIndex; index <= _lastIndex; index++) {
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
    final rebound = index != null && slot.index != index;
    final refresh = active && slot.generation != _generation;
    if (!active || rebound) slot.focusNode.unfocus();
    if (index != null) slot.index = index;
    if (refresh || rebound) slot.generation = _generation;
    if (slot.child != null && slot.active == active && !rebound && !refresh) return;
    slot.active = active;
    slot.child = updateChild(
      slot.child,
      _ItemBoundary(
        slot: slot,
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
              child: IndexedSemantics(
                index: slot.index,
                child: _ItemContent(index: slot.index, builder: _widget.itemBuilder),
              ),
            ),
          ),
        ),
      ),
      slot,
    );
    if (!active) (slot.box as _ItemRenderBoundary?)?.visible = false;
  }

  void _discard(_Slot slot) {
    _slots.remove(slot);
    slot.child = updateChild(slot.child, null, slot);
  }

  void _retire(_Slot slot) {
    _active.remove(slot.index);
    (_pool[slot.type] ??= []).add(slot);
  }

  void _recycleOutside(int first, int last) {
    for (final entry in _active.entries.toList(growable: false)) {
      if (entry.key < first || entry.key > last || entry.value.type != _widget.itemType?.call(entry.key)) {
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
      _active[index] = slot;
    }
    _updateSlot(slot, active: true, index: index);
    return slot;
  }

  void _discardInvalidSpares() {
    for (final type in _pool.keys.toList(growable: false)) {
      final candidates = _pool[type]!;
      candidates.removeWhere((slot) {
        if (slot.index < _widget.itemCount) return false;
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
    final first = wanted.isEmpty ? 0 : wanted.reduce(math.min);
    final last = wanted.isEmpty ? -1 : wanted.reduce(math.max);
    final changed = first != _firstIndex || last != _lastIndex || _laidOutGeneration != _generation;
    _firstIndex = first;
    _lastIndex = last;
    _laidOutGeneration = _generation;
    if (changed) renderObject.markNeedsSemanticsUpdate();
  }
}

class _RecyclerParentData extends ContainerBoxParentData<RenderBox> {
  late _Slot slot;
  double layoutOffset = 0;
  double extent = 0;
}

class _RecyclerAnchor {
  _RecyclerAnchor(this.index, this.relativeStart);

  final int index;
  final double relativeStart;
}

class _RenderRecyclerSliver extends RenderSliver
    with
        ContainerRenderObjectMixin<RenderBox, _RecyclerParentData>,
        RenderSliverHelpers,
        RenderObjectWithLayoutCallbackMixin {
  _RenderRecyclerSliver(this._element);

  final _RecyclerElement _element;
  RecyclerExtentIndex? _extents;
  int _geometryGeneration = -1;
  Axis? _axis;
  double? _crossExtent;
  bool _needsFirstMeasurement = true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RecyclerParentData) child.parentData = _RecyclerParentData();
  }

  double? _lastScrollOffset;

  /// 滚动位置没变时，用上一帧仍在视口里的条目做锚点。
  ///
  /// 跳转或惯性会换一批坐标；缓存里的旧坐标可能刚好落进新视口，不能当成还可见。
  _RecyclerAnchor? _visibleAnchor() {
    if (_lastScrollOffset == null || (constraints.scrollOffset - _lastScrollOffset!).abs() > precisionErrorTolerance) {
      return null;
    }
    if (constraints.remainingPaintExtent <= 0) return null;
    _RecyclerAnchor? result;
    final start = constraints.scrollOffset;
    final end = start + constraints.remainingPaintExtent;
    for (final entry in _element._active.entries) {
      if (entry.key >= _element._widget.itemCount) continue;
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
    final widget = _element._widget;
    final count = widget.itemCount;
    final reset =
        _geometryGeneration != _element._generation ||
        _axis != constraints.axis ||
        _crossExtent != constraints.crossAxisExtent;
    if (reset) {
      final types = <Object?, int>{};
      _extents = RecyclerExtentIndex.groups(
        List.generate(count, (index) => types.putIfAbsent(widget.itemType?.call(index), () => types.length)),
      );
      _geometryGeneration = _element._generation;
      _axis = constraints.axis;
      _crossExtent = constraints.crossAxisExtent;
      _needsFirstMeasurement = count > 0;
    }
    final extents = _extents!;
    var anchor = _visibleAnchor();
    if (count == 0) {
      _element.owner!.buildScope(_element, () => _element._finishLayout({}));
      geometry = SliverGeometry.zero;
      return;
    }

    final childConstraints = constraints.asBoxConstraints();
    var pixels = constraints.scrollOffset;
    void layoutPosition(int index) {
      late _Slot slot;
      _element.owner!.buildScope(_element, () {
        slot = _element._obtain(index);
        _element._discardInvalidSpares();
      });
      final child = slot.box!;
      child.layout(childConstraints, parentUsesSize: true);
      final extent = constraints.axis == Axis.vertical ? child.size.height : child.size.width;
      final changed = extents.measure(index, extent);
      if (changed && anchor != null) {
        pixels = math.max(0.0, extents.prefix(anchor.index) - anchor.relativeStart);
      }
      (child.parentData! as _RecyclerParentData)
        ..layoutOffset = extents.prefix(index)
        ..extent = extent;
    }

    _element.owner!.buildScope(_element, () {
      _element._recycleOutside(0, count - 1);
      _element._discardInvalidSpares();
    });
    if (_needsFirstMeasurement) {
      layoutPosition(anchor?.index ?? 0);
      _needsFirstMeasurement = false;
      if (anchor != null) pixels = math.max(0.0, extents.prefix(anchor.index) - anchor.relativeStart);
    }
    if (anchor == null && pixels < extents.total && constraints.remainingPaintExtent > 0) {
      final index = extents.indexAt(pixels);
      anchor = _RecyclerAnchor(index, extents.prefix(index) - pixels);
    }

    double cacheStart() => math.max(0.0, pixels + constraints.cacheOrigin);
    double cacheEnd() => cacheStart() + constraints.remainingCacheExtent;
    final wanted = <int>{};
    if (constraints.remainingCacheExtent > 0 && (cacheStart() < extents.total || extents.total == 0)) {
      var first = extents.total == 0 ? 0 : extents.indexAt(cacheStart());
      final last = extents.indexAt(cacheEnd() - precisionErrorTolerance);
      _element.owner!.buildScope(_element, () => _element._recycleOutside(first, last));

      var next = first;
      while (true) {
        if (first > 0 && extents.prefix(first) > cacheStart() + precisionErrorTolerance) {
          layoutPosition(--first);
          wanted.add(first);
          continue;
        }
        if (next >= count || (wanted.isNotEmpty && extents.prefix(next) >= cacheEnd() - precisionErrorTolerance)) break;
        layoutPosition(next);
        wanted.add(next++);
      }
      wanted.removeWhere((index) {
        final data = _element._active[index]!.box!.parentData! as _RecyclerParentData;
        final start = extents.prefix(index);
        return start >= cacheEnd() - precisionErrorTolerance ||
            (data.extent > 0 ? start + data.extent <= cacheStart() + precisionErrorTolerance : start < cacheStart());
      });
    }
    _element.owner!.buildScope(_element, () => _element._finishLayout(wanted));

    final correction = pixels - constraints.scrollOffset;
    if (correction.abs() > precisionErrorTolerance) {
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }
    _lastScrollOffset = constraints.scrollOffset;

    final total = extents.total;
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
      data.layoutOffset = extents.prefix(slot.index);
      final logical = data.layoutOffset - constraints.scrollOffset;
      final position = reversed ? paintExtent - logical - data.extent : logical;
      data.offset = constraints.axis == Axis.vertical ? Offset(0, position) : Offset(position, 0);
      (child as _ItemRenderBoundary).visible = logical < paintExtent && logical + data.extent > 0;
    }
  }

  @override
  void performLayout() => runLayoutCallback();

  @override
  double childMainAxisPosition(RenderBox child) =>
      (child.parentData! as _RecyclerParentData).layoutOffset - constraints.scrollOffset;

  @override
  double childCrossAxisPosition(RenderBox child) => 0;

  @override
  double? childScrollOffset(RenderObject child) {
    final data = child.parentData! as _RecyclerParentData;
    return data.slot.active ? data.layoutOffset : null;
  }

  @override
  bool paintsChild(RenderObject child) {
    final data = child.parentData! as _RecyclerParentData;
    return data.slot.active && (child as _ItemRenderBoundary).visible;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!geometry!.visible) return;
    for (var index = _element._firstIndex; index <= _element._lastIndex; index++) {
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
    final index = extents.indexAt(mainAxisPosition + constraints.scrollOffset);
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
    for (var index = _element._firstIndex; index <= _element._lastIndex; index++) {
      if (_element._active[index]?.box case final child?) visitor(child);
    }
  }
}

class _ItemBoundary extends SingleChildRenderObjectWidget {
  const _ItemBoundary({required this.slot, required super.child});

  final _Slot slot;

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) => _ItemRenderBoundary();

  @override
  void didUnmountRenderObject(covariant RenderRepaintBoundary renderObject) {
    slot.dispose();
  }
}

class _ItemRenderBoundary extends RenderRepaintBoundary {
  bool _visible = false;

  bool get visible => _visible;

  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    if (!value) layer?.remove();
  }
}
