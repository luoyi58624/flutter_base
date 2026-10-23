part of 'index.dart';

/// 样式字段独立于公开过渡枚举，集中声明读取、插值和消费域。
enum StyleField {
  width,
  height,
  backgroundColor,
  padding,
  margin;

  bool get isLength => switch (this) {
    width || height => true,
    backgroundColor || padding || margin => false,
  };

  int get damage => switch (this) {
    width || height || padding || margin => StyleEngine.layout,
    backgroundColor => StyleEngine.paint,
  };

  ElTransitionField get transitionField => switch (this) {
    width => ElTransitionField.width,
    height => ElTransitionField.height,
    backgroundColor => ElTransitionField.backgroundColor,
    padding => ElTransitionField.padding,
    margin => ElTransitionField.margin,
  };

  Object? declaration(ElStyle style) => switch (this) {
    width => style.width,
    height => style.height,
    backgroundColor => style.backgroundColor,
    padding => style.padding,
    margin => style.margin,
  };

  Object? parse(Object value, TextDirection direction) => switch (this) {
    width || height => _parseLength(value),
    backgroundColor => value as Color,
    padding || margin => _resolveInsets(value as EdgeInsetsGeometry, direction),
  };

  Object? interpolate(Object? from, Object? to, double t) => switch (this) {
    width || height => _lengthLerp(from, to, t),
    backgroundColor => _colorLerp(from, to, t),
    padding || margin => _insetsLerp(from, to, t),
  };
}
