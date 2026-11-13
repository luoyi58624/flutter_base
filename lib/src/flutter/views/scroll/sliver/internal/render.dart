import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show ScrollPosition;

import 'child_source.dart';
import 'index_controller.dart';
import 'layout.dart';

class _Reveal {
  _Reveal(this.index, this.alignment);

  final int index;
  final double alignment;
  final completer = Completer<bool>();

  void complete(bool value) {
    if (!completer.isCompleted) completer.complete(value);
  }
}

/// 组合布局算法与子项来源的自然尺寸 Sliver：一套布局循环、绘制、命中和语义覆盖全部组合。
class RenderNaturalSliver extends RenderSliver
    with
        ContainerRenderObjectMixin<RenderBox, NaturalSliverParentData>,
        RenderSliverHelpers,
        RenderObjectWithLayoutCallbackMixin
    implements SliverIndexTarget {
  RenderNaturalSliver(this.source, SliverLayoutSpec spec) : _spec = spec, _layout = spec.createLayout();

  final SliverChildSource source;
  SliverLayoutSpec _spec;
  SliverLayout _layout;
  // 本轮缓存窗口内的条目，升序；绘制、命中与语义都只遍历它。
  List<int> _window = const [];
  bool _contentDirty = true;
  bool _unmeasured = true;
  int _typesGeneration = -1;
  int _semanticsGeneration = -1;
  SliverIndexChannel? _channel;
  _Reveal? _reveal;
  // 上次布局后的条目增删，按通知顺序记录 (起点, 增量)。
  final List<(int, int)> _shifts = [];

  set spec(SliverLayoutSpec value) {
    if (_spec == value) return;
    _spec = value;
    _layout = value.createLayout();
    markNeedsLayout();
  }

  set channel(SliverIndexChannel? value) {
    if (identical(_channel, value)) return;
    if (identical(_channel?.target, this)) _channel!.target = null;
    _channel = value;
    value?.target = this;
  }

  // 常驻内容滚动时不重排子项，独立图层让滚动只移动合成结果。
  @override
  bool get isRepaintBoundary => source.mountsAll;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! NaturalSliverParentData) child.parentData = NaturalSliverParentData();
  }

  @override
  void markNeedsLayout() {
    // 子项尺寸与结构变化经过这里；视口滚动只传入新约束，常驻模式据此跳过子项布局。
    _contentDirty = true;
    super.markNeedsLayout();
  }

  @override
  void dispose() {
    channel = null;
    _reveal?.complete(false);
    _reveal = null;
    super.dispose();
  }

  // ---- 控制器通道 ----

  ScrollPosition? get _position => switch (RenderAbstractViewport.maybeOf(this)) {
    RenderViewportBase(:final ScrollPosition offset) when offset.hasPixels => offset,
    _ => null,
  };

  @override
  Future<bool> reveal(int index, double alignment) {
    // 新请求覆盖尚未执行的旧请求，旧请求按未完成返回。
    _reveal?.complete(false);
    final request = _reveal = _Reveal(index, alignment);
    // 定位是一次跳转：先停下惯性、平滑滚轮等进行中的活动。
    if (_position case final position?) position.jumpTo(position.pixels);
    scheduleLayoutCallback();
    return request.completer.future;
  }

  @override
  void cancelReveal() {
    _reveal?.complete(false);
    _reveal = null;
  }

  @override
  void shift(int index, int delta) {
    _shifts.add((index, delta));
    scheduleLayoutCallback();
  }

  int _shifted(int index) {
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

  // ---- 布局 ----

  double _mainOf(RenderBox child) => constraints.axis == Axis.vertical ? child.size.height : child.size.width;

  /// 上一轮已定位、仍与视口相交的首个条目：(序号, 相对视口起点的位置)。
  (int, double)? _visibleAnchor() {
    if (constraints.remainingPaintExtent <= 0) return null;
    final start = constraints.scrollOffset;
    final end = start + constraints.remainingPaintExtent;
    final count = source.childCount;
    (int, double)? result;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final data = child.parentData! as NaturalSliverParentData;
      final slot = data.slot;
      if (slot == null || !slot.active || slot.index >= count) continue;
      if (data.extent <= 0 || data.layoutOffset + data.extent <= start || data.layoutOffset >= end) continue;
      if (result == null || slot.index < result.$1) result = (slot.index, data.layoutOffset - start);
    }
    return result;
  }

  @override
  void performLayout() => runLayoutCallback();

  @override
  void layoutCallback() {
    final reordered = source.beginLayout();
    final count = source.childCount;
    final layout = _layout;
    var anchor = source.mountsAll ? null : _visibleAnchor();
    if (_shifts.isNotEmpty) {
      if (anchor != null) anchor = (_shifted(anchor.$1), anchor.$2);
      _shifts.clear();
    }
    List<Object?>? types;
    if (_typesGeneration != source.generation || layout.count != count) {
      // 父级重建只刷新业务绑定；真实类型与规格未变时保留实测尺寸和列分配。
      types = source.hasTypes ? List<Object?>.generate(count, source.typeOf, growable: false) : const [];
      _typesGeneration = source.generation;
    }
    final reset = layout.sync(count, types, constraints, force: reordered);
    if (reset) _unmeasured = true;
    if (count == 0) {
      source.endLayout(const []);
      _setWindow(const []);
      _contentDirty = false;
      geometry = SliverGeometry.zero;
      cancelReveal();
      return;
    }
    if (source.mountsAll) {
      _layoutMounted(reset);
    } else {
      _layoutWindow(anchor);
    }
  }

  void _layoutMounted(bool reset) {
    final layout = _layout;
    if (_contentDirty || reset) {
      final count = source.childCount;
      final childConstraints = layout.childConstraints(constraints);
      for (var index = 0; index < count; index++) {
        layout.measure(index, _mainOf(source.layoutChild(index, childConstraints)));
      }
      for (var index = 0; index < count; index++) {
        _place(index);
      }
      _contentDirty = false;
      _unmeasured = false;
    }
    final start = math.max(0.0, constraints.scrollOffset + constraints.cacheOrigin);
    _setWindow(
      constraints.remainingCacheExtent > 0
          ? layout.indicesIn(start, start + constraints.remainingCacheExtent)
          : const [],
    );
    _finish(constraints.scrollOffset);
  }

  void _layoutWindow((int, double)? anchor) {
    final layout = _layout;
    final count = source.childCount;
    final childConstraints = layout.childConstraints(constraints);
    var pixels = constraints.scrollOffset;
    // 起点没有待保留的离屏内容；零高首项展开应自然露出，而非被锚点修正滚走。
    if (pixels <= precisionErrorTolerance) anchor = (0, 0);
    final visited = <int>{};

    void keepAnchor() {
      if (anchor case (final index, final relative)) pixels = math.max(0.0, layout.startOf(index) - relative);
    }

    bool measureUnit(int index) {
      final (first, end) = layout.unitOf(index);
      var changed = false;
      for (var i = first; i < end; i++) {
        // 绑定通知必须先完成 build，再读取新条目的真实尺寸。
        changed |= layout.measure(i, _mainOf(source.layoutChild(i, childConstraints)));
        visited.add(i);
      }
      if (changed) keepAnchor();
      return changed;
    }

    if (_unmeasured) {
      _unmeasured = false;
      if (layout.usesEstimates) {
        // 先测真实条目再定窗口，等高内容无需调用方提供任何尺寸提示。
        measureUnit(anchor?.$1 ?? 0);
        keepAnchor();
      }
    }

    if (_reveal case final reveal?) {
      _reveal = null;
      final index = reveal.index.clamp(0, count - 1);
      measureUnit(index);
      final viewportExtent = constraints.viewportMainAxisExtent;
      final lowest = -constraints.precedingScrollExtent;
      final target = (layout.startOf(index) - reveal.alignment * (viewportExtent - _mainOf(source.childAt(index)!)))
          .clamp(lowest, math.max(lowest, layout.total - viewportExtent))
          .toDouble();
      // 列表起点还没滚到视口顶端时 scrollOffset 恒为 0，需要按视口位置换算当前偏移；
      // 经真实视口查找，包在 SliverPadding 等容器里同样成立。
      final current = switch (_position) {
        final position? when constraints.scrollOffset <= 0 => position.pixels - constraints.precedingScrollExtent,
        _ => constraints.scrollOffset,
      };
      SchedulerBinding.instance.addPostFrameCallback((_) => reveal.complete(attached));
      if ((target - current).abs() > precisionErrorTolerance) {
        final window = [index];
        source.endLayout(window);
        _relayoutParked();
        _setWindow(window);
        _place(index);
        geometry = SliverGeometry(scrollOffsetCorrection: target - current);
        return;
      }
    }

    if (anchor == null && pixels < layout.total && constraints.remainingPaintExtent > 0) {
      if (layout.anchorAt(pixels) case final index?) anchor = (index, layout.startOf(index) - pixels);
    }

    var window = const <int>[];
    if (constraints.remainingCacheExtent > 0) {
      // 每轮按最新几何重取候选；任一实测改变位置就重新取窗口，
      // 过期估值不会积累成窗口外的构建。
      while (true) {
        final start = math.max(0.0, pixels + constraints.cacheOrigin);
        if (start >= layout.total && layout.total > 0) break;
        final candidates = layout.indicesIn(start, start + constraints.remainingCacheExtent);
        source.prepareWindow(candidates);
        var changed = false;
        for (final index in candidates) {
          if (visited.contains(index) && source.childAt(index) != null) continue;
          if (measureUnit(index)) {
            changed = true;
            break;
          }
        }
        if (!changed) {
          window = candidates;
          break;
        }
      }
    }
    source.endLayout(window);
    _relayoutParked();
    _setWindow(window);
    for (final index in window) {
      _place(index);
    }
    _finish(pixels);
  }

  // 停放子树仍挂载：独立布局边界让嵌套 LayoutBuilder 的补建不经过已完成布局的 Sliver。
  void _relayoutParked() {
    for (final box in source.parked) {
      if (box.hasSize) box.layout(box.constraints, parentUsesSize: false);
    }
  }

  void _setWindow(List<int> window) {
    final changed = !listEquals(_window, window);
    if (changed) _window = window;
    if (changed || _semanticsGeneration != source.generation) markNeedsSemanticsUpdate();
    _semanticsGeneration = source.generation;
  }

  void _place(int index) {
    final child = source.childAt(index)!;
    (child.parentData! as NaturalSliverParentData)
      ..layoutOffset = _layout.startOf(index)
      ..extent = _mainOf(child)
      ..crossAxisOffset = _layout.crossOf(index, child.size, constraints);
  }

  void _finish(double pixels) {
    final correction = pixels - constraints.scrollOffset;
    if (correction.abs() > precisionErrorTolerance) {
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }
    final total = _layout.total;
    geometry = SliverGeometry(
      scrollExtent: total,
      paintExtent: calculatePaintOffset(constraints, from: 0, to: total),
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: total),
      maxPaintExtent: total,
      hasVisualOverflow: constraints.scrollOffset > 0 || total > constraints.remainingPaintExtent,
    );
    for (final index in _window) {
      final child = source.childAt(index)!;
      final painted = paintsChild(child);
      if (child case final ViewportVisibility boundary) boundary.visible = painted;
      if (painted) _layout.retain(index);
    }
  }

  // ---- 定位、绘制、命中、语义 ----

  @override
  double childMainAxisPosition(RenderBox child) =>
      (child.parentData! as NaturalSliverParentData).layoutOffset - constraints.scrollOffset;

  @override
  double childCrossAxisPosition(RenderBox child) => (child.parentData! as NaturalSliverParentData).crossAxisOffset;

  @override
  double? childScrollOffset(RenderObject child) {
    final data = child.parentData! as NaturalSliverParentData;
    return data.active ? data.layoutOffset : null;
  }

  // 位置按当前约束即时换算，滚动不需要逐项改写 parentData。
  Offset _paintOffsetOf(NaturalSliverParentData data) {
    final logical = data.layoutOffset - constraints.scrollOffset;
    final direction = applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection);
    final main = axisDirectionIsReversed(direction) ? geometry!.paintExtent - logical - data.extent : logical;
    return constraints.axis == Axis.vertical ? Offset(data.crossAxisOffset, main) : Offset(main, data.crossAxisOffset);
  }

  @override
  bool paintsChild(RenderObject child) {
    final data = child.parentData! as NaturalSliverParentData;
    return data.active &&
        geometry?.visible == true &&
        data.extent > 0 &&
        data.layoutOffset < constraints.scrollOffset + geometry!.paintExtent &&
        data.layoutOffset + data.extent > constraints.scrollOffset;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (geometry?.visible != true) return;
    for (final index in _window) {
      final child = source.childAt(index);
      if (child != null && paintsChild(child)) {
        context.paintChild(child, offset + _paintOffsetOf(child.parentData! as NaturalSliverParentData));
      }
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    for (var i = _window.length - 1; i >= 0; i--) {
      final child = source.childAt(_window[i]);
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

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final data = child.parentData! as NaturalSliverParentData;
    // 常驻和活跃子项保留真实变换，离屏时 ensureVisible 与选区自动滚动仍需要它；停放子项不参与坐标换算。
    if (data.active && geometry != null) {
      final offset = _paintOffsetOf(data);
      transform.translateByDouble(offset.dx, offset.dy, 0, 1);
    } else {
      transform.setZero();
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // 语义覆盖整个缓存窗口，读屏才能顺序滑到视口外的下一项；裁剪交给视口。
    for (final index in _window) {
      if (source.childAt(index) case final child?) visitor(child);
    }
  }
}
