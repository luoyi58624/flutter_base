part of 'render_view.dart';

/// 盒内外边距与 intrinsic 测量共用的几何规则。
class BoxInsets {
  const BoxInsets._();

  /// padding 不含边框，边框只参与绘制。
  static EdgeInsets outerInsets(ResolvedStyle style) =>
      style.box.padding?.resolve(style.inheritedBox.textDirection ?? TextDirection.ltr) ?? EdgeInsets.zero;

  /// margin 是节点对外占位，不计入视觉盒。
  static EdgeInsets marginInsets(ResolvedStyle style) =>
      style.box.margin?.resolve(style.inheritedBox.textDirection ?? TextDirection.ltr) ?? EdgeInsets.zero;

  /// max 优先于冲突的 min。
  static double clampDimension(double value, double min, double max) => value.clamp(min <= max ? min : max, max);
}

typedef _LayoutAxis = ({double min, double max, double childMin, double childMax, double? reference, double limit});

/// 一次布局的已解析几何，真实布局、dry layout 和 auto 终点共用。
class _BoxLayout {
  _BoxLayout(
    this.box,
    this.margin,
    this.padding,
    this.inner,
    this.used,
    this.referenceWidth,
    this.referenceHeight,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
  );

  factory _BoxLayout.resolve(
    ResolvedStyle resolved,
    BoxConstraints parent, {
    required double Function(double) availableWidth,
    required double Function(double) availableHeight,
  }) {
    final box = resolved.box;
    final margin = BoxInsets.marginInsets(resolved);
    final padding = BoxInsets.outerInsets(resolved);
    final constraints = margin == EdgeInsets.zero ? parent : parent.deflate(margin);
    final aw = availableWidth(constraints.maxWidth);
    final ah = availableHeight(constraints.maxHeight);
    final w = box.width?.resolve(aw), h = box.height?.resolve(ah);
    final ratio = box.aspectRatio;
    final x = _resolveAxis(
      constraints.minWidth,
      constraints.maxWidth,
      box.minWidth?.resolve(aw),
      box.maxWidth?.resolve(aw),
      w ?? (h != null && ratio != null ? h * ratio : null),
      padding.horizontal,
      parent.hasTightWidth,
    );
    final y = _resolveAxis(
      constraints.minHeight,
      constraints.maxHeight,
      box.minHeight?.resolve(ah),
      box.maxHeight?.resolve(ah),
      h ?? (w != null && ratio != null ? w / ratio : null),
      padding.vertical,
      parent.hasTightHeight,
    );
    return _BoxLayout(
      box,
      margin,
      padding,
      BoxConstraints(minWidth: x.childMin, maxWidth: x.childMax, minHeight: y.childMin, maxHeight: y.childMax),
      BoxConstraints(minWidth: x.min, maxWidth: x.max, minHeight: y.min, maxHeight: y.max),
      x.reference,
      y.reference,
      w,
      h,
      x.limit,
      y.limit,
    );
  }

  final Box box;
  final EdgeInsets margin, padding;
  final BoxConstraints inner, used;
  final double? referenceWidth, referenceHeight, width, height;
  final double maxWidth, maxHeight;

  Offset get contentOrigin => margin.topLeft + padding.topLeft;
  Size addMargin(Size size) =>
      margin == EdgeInsets.zero ? size : Size(size.width + margin.horizontal, size.height + margin.vertical);

  Size resolveSize(Size content) {
    final naturalW = content.width + padding.horizontal;
    final naturalH = content.height + padding.vertical;
    final wf = width == null ? validStyleFactor(box.widthFactor) : null;
    final hf = height == null ? validStyleFactor(box.heightFactor) : null;
    final preferredW = width ?? (wf == null ? null : naturalW * wf);
    final preferredH = height ?? (hf == null ? null : naturalH * hf);
    // factor 是独立尺寸关系，避免再由 ratio 反向派生另一轴形成环。
    final ratio = wf == null && hf == null ? box.aspectRatio : null;
    final w = preferredW ?? (preferredH != null && ratio != null ? preferredH * ratio : naturalW);
    final h = preferredH ?? (ratio != null ? w / ratio : naturalH);
    return used.constrain(Size(w > maxWidth ? maxWidth : w, h > maxHeight ? maxHeight : h));
  }

  static _LayoutAxis _resolveAxis(
    double parentMin,
    double parentMax,
    double? min,
    double? max,
    double? preferred,
    double padding,
    bool parentTight,
  ) {
    final maximum = (max ?? parentMax).clamp(0.0, parentMax);
    final minimum = (min == null || parentMin > min ? parentMin : min).clamp(0.0, maximum);
    final explicit = preferred?.clamp(minimum, maximum);
    // 显式尺寸是子内容的宽松上限，自身 min/max 声明拥有更高优先级。
    final childMax = (max ?? explicit ?? parentMax).clamp(0.0, parentMax);
    final childMin = min != null ? min.clamp(0.0, childMax) : (max != null || explicit != null ? 0.0 : parentMin);
    final innerMax = (childMax - padding).clamp(0.0, double.infinity);
    final reference = explicit ?? (parentTight && parentMax.isFinite ? parentMax : null);
    return (
      min: explicit ?? minimum,
      max: explicit ?? parentMax,
      limit: maximum,
      childMin: (childMin - padding).clamp(0.0, innerMax),
      childMax: innerMax,
      reference: reference == null ? null : (reference - padding).clamp(0.0, double.infinity),
    );
  }
}
