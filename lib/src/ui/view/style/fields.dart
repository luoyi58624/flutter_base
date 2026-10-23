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
  heightFactor;

  bool get isLength => this == width || this == height;

  int get damage => switch (this) {
    width ||
    height ||
    padding ||
    margin ||
    widthFactor ||
    heightFactor => StyleEngine.layout,
    backgroundColor || borderRadius => StyleEngine.paint,
    clipBehavior => StyleEngine.paint | StyleEngine.semantics,
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
  };

  /// 物理值不随文字方向变化，混合方向值与方向性声明才需要重新解析。
  bool dependsOnDirection(Object? value) => switch (this) {
    padding || margin => value is EdgeInsetsGeometry && value is! EdgeInsets,
    borderRadius => value is BorderRadiusGeometry && value is! BorderRadius,
    width ||
    height ||
    backgroundColor ||
    clipBehavior ||
    widthFactor ||
    heightFactor => false,
  };

  Object? parse(Object value, TextDirection direction) => switch (this) {
    width || height => _parseLength(value),
    backgroundColor => value as Color,
    padding || margin => _resolveInsets(value as EdgeInsetsGeometry, direction),
    borderRadius => _resolveRadius(value as BorderRadiusGeometry, direction),
    clipBehavior => value == Clip.none ? null : value as Clip,
    widthFactor || heightFactor => _parseFactor(value as num),
  };

  Object? interpolate(Object? from, Object? to, double t) => switch (this) {
    width || height => _lengthLerp(from, to, t),
    backgroundColor => _colorLerp(from, to, t),
    padding || margin => _insetsLerp(from, to, t),
    borderRadius => _radiusLerp(from, to, t),
    clipBehavior => to,
    widthFactor || heightFactor => _factorLerp(from, to, t),
  };
}
