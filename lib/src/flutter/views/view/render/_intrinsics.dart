part of 'render_view.dart';

/// 按盒模型推导自然尺寸；查询缓存与失效由 RenderBox.get*Intrinsic* 统一管理。
extension _ViewIntrinsics on ElRenderView {
  double _measureIntrinsic(double input, {required bool width, required bool isMin}) {
    final margin = BoxInsets.marginInsets(_committedResolved);
    return _intrinsicAxis(width, input - (width ? margin.vertical : margin.horizontal), isMin: isMin) +
        (width ? margin.horizontal : margin.vertical);
  }

  double _intrinsicAxis(bool width, double cross, {required bool isMin}) {
    final box = _committedResolved.box;
    final explicit = (width ? box.width : box.height)?.resolve(double.infinity);
    double clamp(double value) => BoxInsets.clampDimension(
      value,
      (width ? box.minWidth : box.minHeight)?.resolve(double.infinity) ?? 0,
      (width ? box.maxWidth : box.maxHeight)?.resolve(double.infinity) ?? double.infinity,
    );
    if (explicit != null) return clamp(explicit);
    final factor = validStyleFactor(width ? box.widthFactor : box.heightFactor);
    final ratio = box.aspectRatio;
    final crossExplicit = (width ? box.height : box.width)?.resolve(double.infinity);
    final crossFactor = crossExplicit == null ? validStyleFactor(width ? box.heightFactor : box.widthFactor) : null;
    // 已知交叉尺寸和比例时直接求解，避免访问不影响结果的子节点 intrinsic。
    if (factor == null && ratio != null && crossFactor == null) {
      final basis = crossExplicit ?? (cross.isFinite ? cross.clamp(0.0, double.infinity) : null);
      if (basis != null) return clamp(width ? basis * ratio : basis / ratio);
      if (!width) return clamp(_intrinsicAxis(true, double.infinity, isMin: isMin) / ratio);
    }
    // intrinsic 没有包含块宽度，百分比 padding 按 0 解析。
    final insets = BoxInsets.outerInsets(_committedResolved);
    final natural = width
        ? _intrinsicContentWidth(isMin: isMin) + insets.horizontal
        : _intrinsicChildHeight((cross - insets.horizontal).clamp(0.0, double.infinity), isMin: isMin) +
              insets.vertical;
    return clamp(natural * (factor ?? 1));
  }

  // ---- 内容 intrinsic ----------------------------------------------------

  /// 按需内容模块负责固有宽度，其余情况读取普通子项。
  double _intrinsicContentWidth({required bool isMin}) {
    final content = _content;
    if (content != null) return content.intrinsicWidth(isMin: isMin);
    final child = _singleWidgetChild;
    if (child == null) return 0;
    return isMin ? child.getMinIntrinsicWidth(double.infinity) : child.getMaxIntrinsicWidth(double.infinity);
  }

  /// 内容模块负责固有高度；普通子项直接查询 RenderBox，无子项为零。
  double _intrinsicChildHeight(double width, {required bool isMin}) {
    final content = _content;
    if (content != null) return content.intrinsicHeight(width, isMin: isMin);
    final c = _singleWidgetChild;
    if (c == null) return 0;
    return isMin ? c.getMinIntrinsicHeight(width) : c.getMaxIntrinsicHeight(width);
  }
}
