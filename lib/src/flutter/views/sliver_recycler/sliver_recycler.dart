import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../recycler_view/extent_index.dart';

/// 在官方滚动视口中自然测量子项，并按类型回收条目结构的 Sliver。
///
/// [itemBuilder] 接收槽位持有的活序号；内容通过 ValueListenableBuilder 等方式
/// 监听序号，事件执行时读取最新 value，滚动换绑不会重新调用外层构建器。
/// 同一槽位保留 Element、State 和 RenderObject，业务状态应存放在数据模型中；
/// 条目自己的临时状态、异步任务和订阅需要在序号变化时自行重置。
class ElSliverRecycler extends RenderObjectWidget {
  /// 创建可放入 CustomScrollView.slivers 的回收列表。
  const ElSliverRecycler({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemType,
    this.maxRecycledItems = 32,
  }) : assert(itemCount >= 0),
       assert(maxRecycledItems >= 0);

  /// 当前数据条目数量。
  final int itemCount;

  /// 创建槽位内容，序号改变时由内容自己的监听器更新数据。
  ///
  /// 父组件更新配置或构建上下文依赖变化时可以重新调用此构建器。
  final Widget Function(BuildContext context, ValueListenable<int> index) itemBuilder;

  /// 返回可相互复用的结构类型，未指定时所有条目属于同一类型。
  final Object? Function(int index)? itemType;

  /// 所有类型合计最多保留的空闲槽位数，不包含当前缓存窗口中的条目。
  ///
  /// 设为零仍允许同一轮布局先回收再复用，但不会留下额外空闲条目。
  final int maxRecycledItems;

  @override
  RenderObjectElement createElement() => _RecyclerElement(this);

  @override
  RenderSliver createRenderObject(BuildContext context) => ElRenderSliverRecycler._(context as _RecyclerElement);

  @override
  void updateRenderObject(BuildContext context, covariant ElRenderSliverRecycler renderObject) {
    renderObject.scheduleLayoutCallback();
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
  _Slot(this.type, int index) : index = _IndexBinding(index);

  final Object? type;
  final _IndexBinding index;
  final FocusNode focusNode = FocusNode(canRequestFocus: false, skipTraversal: true);
  Element? child;
  RenderBox? box;
  Widget? content;
  int generation = -1;
  bool active = false;

  void dispose() {
    index.dispose();
    focusNode.dispose();
  }
}

class _RecyclerElement extends RenderObjectElement {
  _RecyclerElement(ElSliverRecycler super.widget);

  final Set<_Slot> _slots = {};
  final Map<int, _Slot> _active = {};
  final Map<Object?, List<_Slot>> _pool = {};
  late final BuildScope _scope = BuildScope(scheduleRebuild: _scheduleRebuild);
  int _generation = 0;
  int _laidOutGeneration = -1;
  int _firstIndex = 0;
  int _lastIndex = -1;
  bool _deferredRebuild = false;

  ElSliverRecycler get _widget => widget as ElSliverRecycler;

  @override
  BuildScope get buildScope => _scope;

  @override
  ElRenderSliverRecycler get renderObject => super.renderObject as ElRenderSliverRecycler;

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
  void update(covariant ElSliverRecycler newWidget) {
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
    final rebound = index != null && slot.index.value != index;
    final refresh = active && slot.generation != _generation;
    if (!active || rebound) slot.focusNode.unfocus();
    if (index != null) slot.index.bind(index, refresh: refresh);
    if (refresh) {
      slot.generation = _generation;
      slot.content = Builder(builder: (context) => _widget.itemBuilder(context, slot.index));
    }
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
              child: IndexedSemantics(index: slot.index.value, child: slot.content!),
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
    _active.remove(slot.index.value);
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
      // 必须在 buildScope 刷新脏子树前丢弃失效绑定，避免缩短后的数组越界。
      candidates.removeWhere((slot) {
        if (slot.index.value < _widget.itemCount) return false;
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

/// 将 RecyclerView 的实测尺寸索引接入官方 Sliver 布局、绘制和命中协议。
class ElRenderSliverRecycler extends RenderSliver
    with
        ContainerRenderObjectMixin<RenderBox, _RecyclerParentData>,
        RenderSliverHelpers,
        RenderObjectWithLayoutCallbackMixin {
  ElRenderSliverRecycler._(this._element);

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

  _RecyclerAnchor? _visibleAnchor() {
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
    var anchor = _visibleAnchor();
    final reset =
        _geometryGeneration != _element._generation ||
        _axis != constraints.axis ||
        _crossExtent != constraints.crossAxisExtent;
    if (reset) {
      final types = <Object?, int>{};
      // 直接复用原 RecyclerView 的索引；估值、前缀和与 offset 反查只有一份实现。
      _extents = RecyclerExtentIndex.groups(
        List.generate(count, (index) => types.putIfAbsent(widget.itemType?.call(index), () => types.length)),
      );
      _geometryGeneration = _element._generation;
      _axis = constraints.axis;
      _crossExtent = constraints.crossAxisExtent;
      _needsFirstMeasurement = count > 0;
    }
    final extents = _extents!;
    if (count == 0) {
      _element.owner!.buildScope(_element, () => _element._finishLayout({}));
      geometry = SliverGeometry.zero;
      return;
    }

    // 与原 RecyclerView 相同：只约束交叉轴，主轴尺寸交给条目自身。
    final childConstraints = constraints.asBoxConstraints();
    var pixels = constraints.scrollOffset;
    void layoutPosition(int index) {
      late _Slot slot;
      _element.owner!.buildScope(_element, () {
        slot = _element._obtain(index);
        _element._discardInvalidSpares();
      });
      // 绑定通知必须先完成 build，再读取新条目的真实尺寸。
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
      // 先测真实条目再定位，等高内容无需调用方提供任何尺寸提示。
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
      // 补测前端也可能改变尾端的位置，两个方向都按最新实测边界填满。
      // 每次只推进到一个尚未布局的索引，最多访问 count 项，不依赖重试次数。
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
      data.layoutOffset = extents.prefix(slot.index.value);
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
    // 在后代 State.dispose 完成后释放绑定，池淘汰时只 deactivate 还不够。
    slot.dispose();
  }
}

class _ItemRenderBoundary extends RenderRepaintBoundary {
  bool _visible = false;

  bool get visible => _visible;

  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    // 取消离屏边界的旧图层挂接，避免脏子树在 flushPaint 中独立重画。
    if (!value) layer?.remove();
  }
}
