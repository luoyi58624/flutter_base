import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 在官方滚动视口中按类型回收条目结构的固定尺寸 Sliver。
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
    required this.itemExtent,
    required this.itemBuilder,
    this.itemType,
    this.maxRecycledItems = 32,
  }) : assert(itemCount >= 0),
       assert(itemExtent > 0 && itemExtent < double.infinity),
       assert(maxRecycledItems >= 0);

  /// 当前数据条目数量。
  final int itemCount;

  /// 每个条目在滚动主轴上占用的固定尺寸。
  final double itemExtent;

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

  void _syncChildren(int first, int last) {
    // 范围不变时仍由外层 buildScope 刷新条目自身产生的脏更新。
    if (first == _firstIndex && last == _lastIndex && _laidOutGeneration == _generation) return;
    _firstIndex = first;
    _lastIndex = last;
    _laidOutGeneration = _generation;

    final types = <int, Object?>{for (var index = first; index <= last; index++) index: _widget.itemType?.call(index)};
    // 先回收再取用，大幅跳转和零容量池也能在同一轮复用原有结构。
    for (final entry in _active.entries.toList(growable: false)) {
      if (entry.key < first || entry.key > last || entry.value.type != types[entry.key]) {
        _active.remove(entry.key);
        (_pool[entry.value.type] ??= []).add(entry.value);
      }
    }
    for (var index = first; index <= last; index++) {
      var slot = _active[index];
      if (slot == null) {
        final type = types[index];
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
    }

    var spareCount = 0;
    for (final type in _pool.keys.toList(growable: false)) {
      final candidates = _pool[type]!;
      // 数据缩短后，旧绑定不能留给离屏子树的异步重建读取。
      candidates.removeWhere((slot) {
        if (slot.index.value < _widget.itemCount) return false;
        _discard(slot);
        return true;
      });
      spareCount += candidates.length;
      if (candidates.isEmpty) _pool.remove(type);
    }
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
    renderObject.markNeedsSemanticsUpdate();
  }
}

class _RecyclerParentData extends ContainerBoxParentData<RenderBox> {
  late _Slot slot;
  double layoutOffset = 0;
}

/// 把固定尺寸条目的回收窗口接入官方 Sliver 布局、绘制和命中协议。
class ElRenderSliverRecycler extends RenderSliver
    with
        ContainerRenderObjectMixin<RenderBox, _RecyclerParentData>,
        RenderSliverHelpers,
        RenderObjectWithLayoutCallbackMixin {
  ElRenderSliverRecycler._(this._element);

  final _RecyclerElement _element;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RecyclerParentData) child.parentData = _RecyclerParentData();
  }

  @override
  void layoutCallback() {
    final widget = _element._widget;
    final total = widget.itemCount * widget.itemExtent;
    final start = math.max(0.0, constraints.scrollOffset + constraints.cacheOrigin);
    final end = math.min(total, start + constraints.remainingCacheExtent);
    final first = math.min(widget.itemCount, (start / widget.itemExtent).floor());
    final last = end <= start ? first - 1 : math.min(widget.itemCount - 1, (end / widget.itemExtent).ceil() - 1);
    _element.owner!.buildScope(_element, () => _element._syncChildren(first, last));
  }

  @override
  void performLayout() {
    runLayoutCallback();
    final widget = _element._widget;
    final extent = widget.itemExtent;
    final total = widget.itemCount * extent;
    final paintExtent = calculatePaintOffset(constraints, from: 0, to: total);
    geometry = SliverGeometry(
      scrollExtent: total,
      paintExtent: paintExtent,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: total),
      maxPaintExtent: total,
      hasVisualOverflow: constraints.scrollOffset > 0 || total > constraints.remainingPaintExtent,
    );
    final childConstraints = constraints.asBoxConstraints(minExtent: extent, maxExtent: extent);
    final direction = applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection);
    final reversed = direction == AxisDirection.up || direction == AxisDirection.left;
    for (final slot in _element._active.values) {
      final child = slot.box!;
      final data = child.parentData! as _RecyclerParentData;
      data.layoutOffset = slot.index.value * extent;
      final logical = data.layoutOffset - constraints.scrollOffset;
      final position = reversed ? paintExtent - logical - extent : logical;
      data.offset = constraints.axis == Axis.vertical ? Offset(0, position) : Offset(position, 0);
      child.layout(childConstraints);
      (child as _ItemRenderBoundary).visible = logical < paintExtent && logical + extent > 0;
    }
  }

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
      final child = _element._active[index]!.box!;
      if (paintsChild(child)) {
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
    final index = ((mainAxisPosition + constraints.scrollOffset) / _element._widget.itemExtent).floor();
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
