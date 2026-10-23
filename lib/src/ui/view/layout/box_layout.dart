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

  Size _layoutSize = Size.zero;
  Size _boxSize = Size.zero;
  Offset _boxOrigin = Offset.zero;
  Offset _childOffset = Offset.zero;
  EdgeInsets? _padding;
  BoxConstraints? _childConstraints;

  BoxConstraints? _referenceBox;
  EdgeInsets? _referencePadding;
  Set<BoxLayout>? _widthReferences, _heightReferences;
  Set<BoxLayout>? _widthDependents, _heightDependents;

  /// 正式布局的外占位，包含外边距并满足父约束。
  Size get layoutSize => _layoutSize;

  /// 正式视觉盒尺寸，包含内边距，不包含外边距。
  Size get boxSize => _boxSize;

  /// 正式视觉盒在宿主局部坐标中的起点。
  Offset get boxOrigin => _boxOrigin;

  /// 正式 child 在宿主局部坐标中的偏移。
  Offset get childOffset => _childOffset;

  /// 正式布局传给 child 的约束，尚未布局时为空。
  BoxConstraints? get childConstraints => _childConstraints;

  /// 正式视觉盒在宿主局部坐标中的范围。
  Rect get boxRect => _boxOrigin & _boxSize;

  /// 正式视觉盒扣除内边距后的内容范围。
  Rect get contentRect {
    final padding = _padding;
    if (padding == null) return boxRect;
    return Rect.fromLTWH(
      _boxOrigin.dx + padding.left,
      _boxOrigin.dy + padding.top,
      math.max(0, _boxSize.width - padding.horizontal),
      math.max(0, _boxSize.height - padding.vertical),
    );
  }

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
    final result = margin == null
        ? box
        : outer.constrain(margin.inflateSize(box));
    if (!temporary) _layoutSize = result;
    return result;
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
    final plan = _constraints(outer, style);
    final content = _host.child?.getDryLayout(plan.inner) ?? Size.zero;
    final padding = style.padding;
    final box = plan.box.constrain(
      padding == null ? content : padding.inflateSize(content),
    );
    final margin = style.margin;
    return margin == null ? box : outer.constrain(margin.inflateSize(box));
  }

  /// 查询加上内外边距后的基线，不执行真实布局。
  double? dryBaseline(
    BoxConstraints outer,
    TextBaseline baseline,
    LayoutStyle style,
  ) {
    final child = _host.child;
    if (child == null) return null;
    final value = child.getDryBaseline(
      _constraints(outer, style).inner,
      baseline,
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
    final fixed = horizontal ? style.width : style.height;
    if (fixed != null) return fixed + axisMargin;
    final child = _host.child;
    final axisPadding = horizontal
        ? (padding?.horizontal ?? 0)
        : (padding?.vertical ?? 0);
    if (child == null) return axisMargin + axisPadding;
    final crossMargin = horizontal
        ? (margin?.vertical ?? 0)
        : (margin?.horizontal ?? 0);
    final crossPadding = horizontal
        ? (padding?.vertical ?? 0)
        : (padding?.horizontal ?? 0);
    final cross =
        (horizontal ? style.height : style.width) ??
        math.max(0.0, extent - crossMargin);
    final childExtent = math.max(0.0, cross - crossPadding);
    final double value;
    if (horizontal) {
      value = minimum
          ? child.getMinIntrinsicWidth(childExtent)
          : child.getMaxIntrinsicWidth(childExtent);
    } else {
      value = minimum
          ? child.getMinIntrinsicHeight(childExtent)
          : child.getMaxIntrinsicHeight(childExtent);
    }
    return value + axisMargin + axisPadding;
  }

  /// 按需沿祖先查找确定内容尺寸，真实查询只订阅经过的候选节点。
  double? reference(Axis axis, {bool dry = false}) {
    for (RenderObject? node = _host.parent; node != null; node = node.parent) {
      if (node is! BoxLayoutOwner) continue;
      final candidate = (node as BoxLayoutOwner).boxLayout;
      if (!dry && !isMeasuring) _dependOn(candidate, axis);
      final value = candidate._reference(axis);
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
    LayoutStyle style,
  ) {
    final available = availableConstraints(outer, style.margin);
    final width = style.width, height = style.height;
    final box = width == null && height == null
        ? available
        : BoxConstraints.tightFor(
            width: width,
            height: height,
          ).enforce(available);
    // 显式尺寸约束视觉盒，不强迫 child 填满；auto 保留父最小约束。
    var inner = width == null && height == null
        ? box
        : BoxConstraints(
            minWidth: width == null ? box.minWidth : 0,
            maxWidth: box.maxWidth,
            minHeight: height == null ? box.minHeight : 0,
            maxHeight: box.maxHeight,
          );
    final padding = style.padding;
    if (padding != null) inner = inner.deflate(padding);
    return (box: box, inner: inner);
  }

  Size _layout(
    BoxConstraints outer,
    LayoutStyle style, {
    required bool temporary,
  }) {
    final plan = _constraints(outer, style);
    final padding = style.padding;
    final previousBox = _referenceBox;
    final previousPadding = _referencePadding;
    _setReferenceGeometry(plan.box, padding);
    try {
      final child = _host.child;
      child?.layout(plan.inner, parentUsesSize: true);
      final content = child?.size ?? Size.zero;
      final box = plan.box.constrain(
        padding == null ? content : padding.inflateSize(content),
      );
      if (!temporary) {
        _boxSize = box;
        _boxOrigin = style.margin?.topLeft ?? Offset.zero;
        _childOffset = padding == null
            ? _boxOrigin
            : _boxOrigin + padding.topLeft;
        _childConstraints = plan.inner;
        _padding = padding;
        if (child != null) {
          (child.parentData! as BoxParentData).offset = _childOffset;
        }
      }
      return box;
    } finally {
      if (temporary) {
        _setReferenceGeometry(previousBox, previousPadding);
      }
    }
  }

  double? _reference(Axis axis) {
    final box = _referenceBox;
    if (box == null) return null;
    final padding = _referencePadding;
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
