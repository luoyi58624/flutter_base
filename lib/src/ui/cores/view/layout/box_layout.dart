import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../style/resolved/layout.dart';

/// 向后代暴露盒模型参照，执行器不依赖具体的 Render 实现。
abstract interface class BoxLayoutOwner {
  /// 本节点唯一的盒模型执行器。
  BoxLayout get boxLayout;
}

/// 统一执行尺寸、内外边距、真实测量和只读布局查询。
class BoxLayout {
  /// 绑定单子宿主，并通过宿主提供的布局回调安全地使后代失效。
  BoxLayout(
    this._host, {
    required void Function(VoidCallback) mutateLayout,
    // 保留语义明确的公开参数名，内部回调不暴露为可调用字段。
    // ignore: prefer_initializing_formals
  }) : _mutateLayout = mutateLayout;

  final RenderShiftedBox _host;
  final void Function(VoidCallback) _mutateLayout;

  static int _measurementDepth = 0;
  static Set<BoxLayout>? _measuredLayouts;

  /// 当前调用栈是否处于真实端点测量，期间不得提交正式样式或几何。
  static bool get isMeasuring => _measurementDepth != 0;

  Size _boxSize = Size.zero;
  Offset _boxOrigin = Offset.zero;

  BoxConstraints? _referenceBox;
  EdgeInsets? _referencePadding;
  BoxConstraints? _queryBox;
  EdgeInsets? _queryPadding;
  Set<BoxLayout>? _widthReferences, _heightReferences;
  Set<BoxLayout>? _widthDependents, _heightDependents;

  /// 正式视觉盒尺寸，包含内边距，不包含外边距。
  Size get boxSize => _boxSize;

  /// 正式视觉盒在宿主局部坐标中的范围。
  Rect get boxRect => _boxOrigin & _boxSize;

  /// 扣除外边距得到可用盒约束；未声明外边距时直接复用父约束。
  static BoxConstraints availableConstraints(
    BoxConstraints outer,
    EdgeInsets? margin,
  ) => margin == null ? outer : outer.deflate(margin);

  /// 清理本节点上一轮登记的参照，随后仅登记本轮实际使用的轴。
  void beginLayout() {
    if (!isMeasuring) _clearReferences();
  }

  /// 执行真实 child 布局并返回外占位，测量作用域内不提交正式几何。
  Size perform(BoxConstraints outer, LayoutStyle style) {
    final temporary = isMeasuring;
    if (temporary) _measuredLayouts!.add(this);
    final box = _layout(outer, style, temporary: temporary);
    final margin = style.margin;
    return margin == null ? box : outer.constrain(margin.inflateSize(box));
  }

  /// 按已解析请求测量真实目标视觉盒，测量结果不覆盖正式几何。
  Size measure(BoxConstraints outer, LayoutStyle style) {
    final outermost = !isMeasuring;
    if (outermost) _measuredLayouts = <BoxLayout>{};
    _measurementDepth++;
    try {
      return _layout(outer, style, temporary: true);
    } finally {
      try {
        if (outermost) {
          final measured = _measuredLayouts!;
          if (measured.isNotEmpty) {
            // 恢复标脏仍属测量，避免后代误判为外部变更而重置动画时序。
            _mutateLayout(() {
              for (final layout in measured) {
                if (layout._host.attached) layout._host.markNeedsLayout();
              }
            });
          }
        }
      } finally {
        _measurementDepth--;
        if (outermost) _measuredLayouts = null;
      }
    }
  }

  /// 按相同盒模型规则查询外占位，不改变引用、偏移或正式几何。
  Size dryLayout(BoxConstraints outer, LayoutStyle style) {
    final plan = _queryConstraints(outer, style);
    return _withQueryGeometry(plan.box, style.padding, () {
      final content = _host.child?.getDryLayout(plan.inner) ?? Size.zero;
      final box = _constrainBox(plan.box, content, style);
      final margin = style.margin;
      return margin == null ? box : outer.constrain(margin.inflateSize(box));
    });
  }

  /// 查询加上内外边距后的基线，不执行真实布局。
  double? dryBaseline(
    BoxConstraints outer,
    TextBaseline baseline,
    LayoutStyle style,
  ) {
    final child = _host.child;
    if (child == null) return null;
    final plan = _queryConstraints(outer, style);
    final value = _withQueryGeometry(
      plan.box,
      style.padding,
      () => child.getDryBaseline(plan.inner, baseline),
    );
    if (value == null) return null;
    return value + (style.padding?.top ?? 0) + (style.margin?.top ?? 0);
  }

  /// 查询指定轴的固有尺寸，固定尺寸直接返回，自动尺寸交给 child 求值。
  double intrinsic(
    bool horizontal,
    double extent,
    bool minimum,
    LayoutStyle style,
  ) {
    final padding = style.padding;
    final margin = style.margin;
    final axisMargin = horizontal
        ? (margin?.horizontal ?? 0)
        : (margin?.vertical ?? 0);
    final lower = horizontal ? style.minWidth : style.minHeight;
    final upper = horizontal ? style.maxWidth : style.maxHeight;
    var fixed = horizontal ? style.width : style.height;
    final ratio = style.aspectRatio;
    if (fixed == null && ratio != null) {
      final cross = horizontal ? style.height : style.width;
      if (cross != null) fixed = _ratioExtent(cross, ratio, horizontal);
    }
    if (fixed != null) return _bound(fixed, lower, upper) + axisMargin;
    if (!horizontal && ratio != null) {
      // 双 auto 用内容自然宽派生高度；查询也必须遵守跨轴上限与百分比参照。
      final plan = _queryConstraints(BoxConstraints(maxWidth: extent), style);
      return plan.box.maxHeight + axisMargin;
    }
    final factor = horizontal ? style.widthFactor : style.heightFactor;
    if (factor == 0) return _bound(0, lower, upper) + axisMargin;
    final child = _host.child;
    final axisPadding = horizontal
        ? (padding?.horizontal ?? 0)
        : (padding?.vertical ?? 0);
    if (child == null) {
      final natural = factor == null ? axisPadding : axisPadding * factor;
      return _bound(natural, lower, upper) + axisMargin;
    }
    final crossMargin = horizontal
        ? (margin?.vertical ?? 0)
        : (margin?.horizontal ?? 0);
    final crossPadding = horizontal
        ? (padding?.vertical ?? 0)
        : (padding?.horizontal ?? 0);
    final availableCross = math.max(0.0, extent - crossMargin);
    final cross = math.min(
      availableCross,
      _bound(
        (horizontal ? style.height : style.width) ?? availableCross,
        horizontal ? style.minHeight : style.minWidth,
        horizontal ? style.maxHeight : style.maxWidth,
      ),
    );
    final childExtent = math.max(0.0, cross - crossPadding);
    final value = ratio == null
        ? _childIntrinsic(child, horizontal, minimum, childExtent)
        : _withQueryGeometry(
            _constraints(BoxConstraints(maxHeight: extent), style).box,
            padding,
            () => _childIntrinsic(child, horizontal, minimum, childExtent),
          );
    final natural = value + axisPadding;
    return _bound(factor == null ? natural : natural * factor, lower, upper) +
        axisMargin;
  }

  double _childIntrinsic(
    RenderBox child,
    bool horizontal,
    bool minimum,
    double extent,
  ) => horizontal
      ? (minimum
            ? child.getMinIntrinsicWidth(extent)
            : child.getMaxIntrinsicWidth(extent))
      : (minimum
            ? child.getMinIntrinsicHeight(extent)
            : child.getMaxIntrinsicHeight(extent));

  /// 按需沿祖先查找确定内容尺寸，真实查询只订阅经过的候选节点。
  double? reference(Axis axis, {bool dry = false}) {
    for (RenderObject? node = _host.parent; node != null; node = node.parent) {
      if (node is! BoxLayoutOwner) continue;
      final candidate = (node as BoxLayoutOwner).boxLayout;
      if (!dry && !isMeasuring) _dependOn(candidate, axis);
      final value = candidate._reference(axis, query: dry);
      if (value != null) return value;
    }
    return null;
  }

  /// 解除旧树上的双向引用登记，重挂后由正式布局重新建立。
  void detach() {
    _clearReferences();
    _clearDependents(Axis.horizontal);
    _clearDependents(Axis.vertical);
  }

  /// 释放本执行器持有的参照登记。
  void dispose() => detach();

  ({BoxConstraints box, BoxConstraints inner}) _constraints(
    BoxConstraints outer,
    LayoutStyle style, {
    double? naturalWidth,
  }) {
    final available = availableConstraints(outer, style.margin);
    var width = style.width, height = style.height;
    final ratio = style.aspectRatio;
    if (ratio != null) {
      if (width != null && height == null) {
        height = _ratioExtent(width, ratio, false);
      } else if (height != null && width == null) {
        width = _ratioExtent(height, ratio, true);
      } else if (width == null && height == null && naturalWidth != null) {
        width = naturalWidth;
        height = _ratioExtent(width, ratio, false);
      }
    }
    final bounded =
        style.minWidth != null ||
        style.maxWidth != null ||
        style.minHeight != null ||
        style.maxHeight != null;
    final BoxConstraints box;
    if (!bounded) {
      box = width == null && height == null
          ? available
          : BoxConstraints.tightFor(
              width: width,
              height: height,
            ).enforce(available);
    } else {
      final maxWidth = style.maxWidth ?? double.infinity;
      final maxHeight = style.maxHeight ?? double.infinity;
      final usedWidth = width == null
          ? null
          : _bound(width, style.minWidth, style.maxWidth);
      final usedHeight = height == null
          ? null
          : _bound(height, style.minHeight, style.maxHeight);
      // 自身冲突时 max 优先，父约束始终具有最终决定权。
      box = BoxConstraints(
        minWidth: usedWidth ?? math.min(style.minWidth ?? 0, maxWidth),
        maxWidth: usedWidth ?? maxWidth,
        minHeight: usedHeight ?? math.min(style.minHeight ?? 0, maxHeight),
        maxHeight: usedHeight ?? maxHeight,
      ).enforce(available);
    }
    // 自身 min 只撑大视觉盒；auto child 保留父下限，显式尺寸 child 保持 loose。
    var inner =
        width == null &&
            height == null &&
            (!bounded ||
                (box.minWidth == available.minWidth &&
                    box.minHeight == available.minHeight))
        ? box
        : BoxConstraints(
            minWidth: width == null ? available.minWidth : 0,
            maxWidth: box.maxWidth,
            minHeight: height == null ? available.minHeight : 0,
            maxHeight: box.maxHeight,
          );
    final padding = style.padding;
    if (padding != null) inner = inner.deflate(padding);
    return (box: box, inner: inner);
  }

  ({BoxConstraints box, BoxConstraints inner}) _queryConstraints(
    BoxConstraints outer,
    LayoutStyle style,
  ) {
    final plan = _constraints(outer, style);
    if (!_usesNaturalRatio(style)) return plan;
    final content = _withQueryGeometry(
      plan.box,
      style.padding,
      () => _host.child?.getDryLayout(plan.inner) ?? Size.zero,
    );
    return _constraints(
      outer,
      style,
      naturalWidth: content.width + (style.padding?.horizontal ?? 0),
    );
  }

  bool _usesNaturalRatio(LayoutStyle style) =>
      style.aspectRatio != null && style.width == null && style.height == null;

  double _ratioExtent(double extent, double ratio, bool width) {
    final result = width ? extent * ratio : extent / ratio;
    // 极小或极大的有限比值也不能向 Flutter 交付无限紧约束。
    return result.isFinite ? result : double.maxFinite;
  }

  double _bound(double value, double? minimum, double? maximum) {
    if (minimum != null) value = math.max(value, minimum);
    if (maximum != null) value = math.min(value, maximum);
    return value;
  }

  Size _layout(
    BoxConstraints outer,
    LayoutStyle style, {
    required bool temporary,
  }) {
    var plan = _constraints(outer, style);
    final padding = style.padding;
    final previousBox = _referenceBox;
    final previousPadding = _referencePadding;
    _setReferenceGeometry(plan.box, padding);
    try {
      final child = _host.child;
      if (_usesNaturalRatio(style)) {
        child?.layout(plan.inner, parentUsesSize: true);
        plan = _constraints(
          outer,
          style,
          naturalWidth: (child?.size.width ?? 0) + (padding?.horizontal ?? 0),
        );
        // 先确定视觉盒，再让后代按派生轴重新布局；只测一次自然宽，不循环逼近。
        _setReferenceGeometry(plan.box, padding);
      }
      child?.layout(plan.inner, parentUsesSize: true);
      final content = child?.size ?? Size.zero;
      final box = _constrainBox(plan.box, content, style);
      if (!temporary) {
        _boxSize = box;
        _boxOrigin = style.margin?.topLeft ?? Offset.zero;
        if (child != null) {
          (child.parentData! as BoxParentData).offset = padding == null
              ? _boxOrigin
              : _boxOrigin + padding.topLeft;
        }
      }
      return box;
    } finally {
      if (temporary) {
        _setReferenceGeometry(previousBox, previousPadding);
      }
    }
  }

  Size _constrainBox(
    BoxConstraints constraints,
    Size child,
    LayoutStyle style,
  ) {
    final padding = style.padding;
    var natural = padding == null ? child : padding.inflateSize(child);
    final widthFactor = style.widthFactor, heightFactor = style.heightFactor;
    if (widthFactor != null || heightFactor != null) {
      natural = Size(
        widthFactor == null ? natural.width : natural.width * widthFactor,
        heightFactor == null ? natural.height : natural.height * heightFactor,
      );
    }
    return constraints.constrain(natural);
  }

  T _withQueryGeometry<T>(
    BoxConstraints box,
    EdgeInsets? padding,
    T Function() query,
  ) {
    final previousBox = _queryBox, previousPadding = _queryPadding;
    _queryBox = box;
    _queryPadding = padding;
    try {
      return query();
    } finally {
      _queryBox = previousBox;
      _queryPadding = previousPadding;
    }
  }

  double? _reference(Axis axis, {bool query = false}) {
    // 后代只读查询使用本次预测约束，不借用祖先上次正式布局的参照。
    final querying = query && _queryBox != null;
    final box = querying ? _queryBox : _referenceBox;
    if (box == null) return null;
    final padding = querying ? _queryPadding : _referencePadding;
    if (axis == Axis.horizontal) {
      if (!box.hasTightWidth) return null;
      return padding == null
          ? box.maxWidth
          : math.max(0.0, box.maxWidth - padding.horizontal);
    }
    if (!box.hasTightHeight) return null;
    return padding == null
        ? box.maxHeight
        : math.max(0.0, box.maxHeight - padding.vertical);
  }

  void _setReferenceGeometry(BoxConstraints? box, EdgeInsets? padding) {
    final usesWidth = _widthDependents?.isNotEmpty ?? false;
    final usesHeight = _heightDependents?.isNotEmpty ?? false;
    // 未被后代使用的轴只保存几何事实，不提前计算或比较内容参照。
    final oldWidth = usesWidth ? _reference(Axis.horizontal) : null;
    final oldHeight = usesHeight ? _reference(Axis.vertical) : null;
    _referenceBox = box;
    _referencePadding = padding;
    if (usesWidth) {
      _notify(Axis.horizontal, oldWidth, _reference(Axis.horizontal));
    }
    if (usesHeight) {
      _notify(Axis.vertical, oldHeight, _reference(Axis.vertical));
    }
  }

  void _notify(Axis axis, double? previous, double? next) {
    if (previous == next) return;
    final dependents = axis == Axis.horizontal
        ? _widthDependents
        : _heightDependents;
    if (dependents == null || dependents.isEmpty) return;
    _mutateLayout(() {
      for (final dependent in dependents) {
        if (dependent._host.attached) dependent._host.markNeedsLayout();
      }
    });
  }

  void _dependOn(BoxLayout candidate, Axis axis) {
    if (axis == Axis.horizontal) {
      (_widthReferences ??= <BoxLayout>{}).add(candidate);
      (candidate._widthDependents ??= <BoxLayout>{}).add(this);
    } else {
      (_heightReferences ??= <BoxLayout>{}).add(candidate);
      (candidate._heightDependents ??= <BoxLayout>{}).add(this);
    }
  }

  void _clearReferences() {
    final width = _widthReferences;
    if (width != null) {
      for (final candidate in width) {
        candidate._widthDependents?.remove(this);
      }
      width.clear();
    }
    final height = _heightReferences;
    if (height != null) {
      for (final candidate in height) {
        candidate._heightDependents?.remove(this);
      }
      height.clear();
    }
  }

  void _clearDependents(Axis axis) {
    final dependents = axis == Axis.horizontal
        ? _widthDependents
        : _heightDependents;
    if (dependents == null) return;
    for (final dependent in dependents) {
      if (axis == Axis.horizontal) {
        dependent._widthReferences?.remove(this);
      } else {
        dependent._heightReferences?.remove(this);
      }
    }
    dependents.clear();
  }
}
