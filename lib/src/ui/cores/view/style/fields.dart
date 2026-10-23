part of 'index.dart';

/// 样式字段独立于公开过渡枚举，集中声明读取、插值和消费域。
enum StyleField {
  width,
  height,
  backgroundColor,
  padding,
  margin,
  borderRadius,
  clipBehavior,
  widthFactor,
  heightFactor,
  border,
  outline,
  minWidth,
  maxWidth,
  minHeight,
  maxHeight,
  aspectRatio,
  gradient,
  boxShadow,
  opacity,
  transform,
  transformAlignment,
  filter,
  backdropFilter,
  clipper,
  alignment;

  /// 仅宽高需要真实 auto 端点，min/max 的空值沿旧版规则切换。
  bool get isLength => this == width || this == height;

  /// 阴影列表按内容比较，重建等值声明不能重启动画或重复解析。
  bool sameValue(Object? a, Object? b) => this == boxShadow
      ? listEquals(a as List<BoxShadow>?, b as List<BoxShadow>?)
      : a == b;

  int get damage => switch (this) {
    width ||
    height ||
    padding ||
    margin ||
    widthFactor ||
    heightFactor ||
    minWidth ||
    maxWidth ||
    minHeight ||
    maxHeight ||
    aspectRatio ||
    alignment => StyleEngine.layout,
    backgroundColor ||
    borderRadius ||
    border ||
    outline ||
    gradient ||
    boxShadow ||
    opacity ||
    filter ||
    backdropFilter => StyleEngine.paint,
    clipBehavior ||
    clipper ||
    transform ||
    transformAlignment => StyleEngine.paint | StyleEngine.semantics,
  };

  ElTransitionField? get transitionField => switch (this) {
    width => ElTransitionField.width,
    height => ElTransitionField.height,
    backgroundColor => ElTransitionField.backgroundColor,
    padding => ElTransitionField.padding,
    margin => ElTransitionField.margin,
    borderRadius => ElTransitionField.borderRadius,
    clipBehavior => null,
    widthFactor => ElTransitionField.widthFactor,
    heightFactor => ElTransitionField.heightFactor,
    border => ElTransitionField.border,
    outline => ElTransitionField.outline,
    minWidth => ElTransitionField.minWidth,
    maxWidth => ElTransitionField.maxWidth,
    minHeight => ElTransitionField.minHeight,
    maxHeight => ElTransitionField.maxHeight,
    aspectRatio => ElTransitionField.aspectRatio,
    gradient => ElTransitionField.gradient,
    boxShadow => ElTransitionField.boxShadow,
    opacity => ElTransitionField.opacity,
    transform => ElTransitionField.transform,
    transformAlignment => ElTransitionField.transformAlignment,
    filter => ElTransitionField.filter,
    backdropFilter => ElTransitionField.backdropFilter,
    clipper => null,
    alignment => ElTransitionField.alignment,
  };

  Object? declaration(ElStyle style) => switch (this) {
    width => style.width,
    height => style.height,
    backgroundColor => style.backgroundColor,
    padding => style.padding,
    margin => style.margin,
    borderRadius => style.borderRadius,
    clipBehavior => style.clipBehavior,
    widthFactor => style.widthFactor,
    heightFactor => style.heightFactor,
    border => style.border,
    outline => style.outline,
    minWidth => style.minWidth,
    maxWidth => style.maxWidth,
    minHeight => style.minHeight,
    maxHeight => style.maxHeight,
    aspectRatio => style.aspectRatio,
    gradient => style.gradient,
    boxShadow => style.boxShadow,
    opacity => style.opacity,
    transform => style.transform,
    transformAlignment => style.transformAlignment,
    filter => style.filter,
    backdropFilter => style.backdropFilter,
    clipper => style.clipper,
    alignment => style.alignment,
  };

  /// 物理值不随文字方向变化，混合方向值与方向性声明才需要重新解析。
  bool dependsOnDirection(Object? value) => switch (this) {
    padding || margin => value is EdgeInsetsGeometry && value is! EdgeInsets,
    borderRadius => value is BorderRadiusGeometry && value is! BorderRadius,
    border => value is BorderDirectional,
    width ||
    height ||
    backgroundColor ||
    clipBehavior ||
    widthFactor ||
    heightFactor ||
    outline ||
    minWidth ||
    maxWidth ||
    minHeight ||
    maxHeight ||
    aspectRatio ||
    gradient ||
    boxShadow ||
    opacity ||
    transform ||
    transformAlignment ||
    filter ||
    backdropFilter ||
    clipper ||
    alignment => false,
  };

  Object? parse(Object value, TextDirection direction) => switch (this) {
    width ||
    height ||
    minWidth ||
    maxWidth ||
    minHeight ||
    maxHeight => _parseLength(value),
    backgroundColor => value as Color,
    padding || margin => _resolveInsets(value as EdgeInsetsGeometry, direction),
    borderRadius => _resolveRadius(value as BorderRadiusGeometry, direction),
    clipBehavior => value as Clip,
    widthFactor || heightFactor => _parseFactor(value as num),
    border => _resolveBorder(value as BoxBorder, direction),
    outline => _parseOutline(value as ElOutline, direction),
    aspectRatio => _parseAspectRatio(value as num),
    gradient => value as Gradient,
    boxShadow => _parseShadows(value as List<BoxShadow>),
    opacity => _parseOpacity(value as num),
    transform => value as ElTransform,
    transformAlignment => (value: value as AlignmentGeometry, fallback: 0.0),
    filter || backdropFilter => _parseFilter(value as ElFilter),
    clipper => value as CustomClipper<Path>,
    // 保留方向分量到布局求值，动画期间改向无需重启轨道。
    alignment => value as AlignmentGeometry,
  };

  Object? interpolate(Object? from, Object? to, double t) => switch (this) {
    width ||
    height ||
    minWidth ||
    maxWidth ||
    minHeight ||
    maxHeight => _lengthLerp(from, to, t),
    backgroundColor => _colorLerp(from, to, t),
    padding || margin => _insetsLerp(from, to, t),
    borderRadius => _radiusLerp(from, to, t),
    clipBehavior || clipper => to,
    widthFactor || heightFactor => _factorLerp(from, to, t),
    border => _borderLerp(from as Border?, to as Border?, t),
    outline => _outlineLerp(from as OutlineStyle?, to as OutlineStyle?, t),
    aspectRatio => _ratioLerp(from as double?, to as double?, t),
    gradient => Gradient.lerp(from as Gradient?, to as Gradient?, t),
    boxShadow => _shadowsLerp(
      from as List<ElBoxShadow>?,
      to as List<ElBoxShadow>?,
      t,
    ),
    opacity => _opacityLerp(from as double?, to as double?, t),
    transform => ElTransform.lerp(from as ElTransform?, to as ElTransform?, t),
    transformAlignment => _transformAlignmentLerp(
      from as _TransformAlignment?,
      to as _TransformAlignment?,
      t,
    ),
    filter ||
    backdropFilter => _filterLerp(from as FilterStyle?, to as FilterStyle?, t),
    alignment =>
      from == null || to == null
          ? (t < 0.5 ? from : to)
          : AlignmentGeometry.lerp(
              from as AlignmentGeometry,
              to as AlignmentGeometry,
              t,
            ),
  };
}
