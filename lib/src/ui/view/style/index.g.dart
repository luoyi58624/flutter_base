// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'index.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension ElStyleExt on ElStyle {
  ElStyle copyWith({
    Object? width = $absent,
    Object? height = $absent,
    Object? minWidth = $absent,
    Object? maxWidth = $absent,
    Object? minHeight = $absent,
    Object? maxHeight = $absent,
    Object? widthFactor = $absent,
    Object? heightFactor = $absent,
    Object? backgroundColor = $absent,
    Object? padding = $absent,
    Object? margin = $absent,
    Object? border = $absent,
    Object? outline = $absent,
    Object? borderRadius = $absent,
    Object? clipBehavior = $absent,
    Object? transitions = $absent,
  }) {
    return ElStyle(
      width: identical(width, $absent) ? this.width : width,
      height: identical(height, $absent) ? this.height : height,
      minWidth: identical(minWidth, $absent) ? this.minWidth : minWidth,
      maxWidth: identical(maxWidth, $absent) ? this.maxWidth : maxWidth,
      minHeight: identical(minHeight, $absent) ? this.minHeight : minHeight,
      maxHeight: identical(maxHeight, $absent) ? this.maxHeight : maxHeight,
      widthFactor: identical(widthFactor, $absent)
          ? this.widthFactor
          : widthFactor as num?,
      heightFactor: identical(heightFactor, $absent)
          ? this.heightFactor
          : heightFactor as num?,
      backgroundColor: identical(backgroundColor, $absent)
          ? this.backgroundColor
          : backgroundColor as Color?,
      padding: identical(padding, $absent)
          ? this.padding
          : padding as EdgeInsetsGeometry?,
      margin: identical(margin, $absent)
          ? this.margin
          : margin as EdgeInsetsGeometry?,
      border: identical(border, $absent) ? this.border : border as BoxBorder?,
      outline: identical(outline, $absent)
          ? this.outline
          : outline as ElOutline?,
      borderRadius: identical(borderRadius, $absent)
          ? this.borderRadius
          : borderRadius as BorderRadiusGeometry?,
      clipBehavior: identical(clipBehavior, $absent)
          ? this.clipBehavior
          : clipBehavior as Clip?,
      transitions: identical(transitions, $absent)
          ? this.transitions
          : transitions as List<ElTransition>?,
    );
  }

  ElStyle merge([ElStyle? other]) {
    if (other == null) return this;
    return ElStyle(
      width: other.width ?? width,
      height: other.height ?? height,
      minWidth: other.minWidth ?? minWidth,
      maxWidth: other.maxWidth ?? maxWidth,
      minHeight: other.minHeight ?? minHeight,
      maxHeight: other.maxHeight ?? maxHeight,
      widthFactor: other.widthFactor ?? widthFactor,
      heightFactor: other.heightFactor ?? heightFactor,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      border: other.border ?? border,
      outline: other.outline ?? outline,
      borderRadius: other.borderRadius ?? borderRadius,
      clipBehavior: other.clipBehavior ?? clipBehavior,
      transitions: other.transitions ?? transitions,
    );
  }

  List<Object?> get _props => [
    width,
    height,
    minWidth,
    maxWidth,
    minHeight,
    maxHeight,
    widthFactor,
    heightFactor,
    backgroundColor,
    padding,
    margin,
    border,
    outline,
    borderRadius,
    clipBehavior,
    transitions,
  ];
}

extension ElTransitionExt on ElTransition {
  List<Object?> get _props => [field, duration, curve, delay];
}

extension ElOutlineExt on ElOutline {
  ElOutline copyWith({
    Object? width,
    Object? color,
    Object? gradient = $absent,
    Object? offset,
  }) {
    return ElOutline(
      width: width == null ? this.width : width as num,
      color: color == null ? this.color : color as Color,
      gradient: identical(gradient, $absent)
          ? this.gradient
          : gradient as Gradient?,
      offset: offset == null ? this.offset : offset as num,
    );
  }

  List<Object?> get _props => [width, color, gradient, offset];
}
