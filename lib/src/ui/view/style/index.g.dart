// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'index.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension ElStyleExt on ElStyle {
  ElStyle copyWith({
    Object? width = $absent,
    Object? height = $absent,
    Object? widthFactor = $absent,
    Object? heightFactor = $absent,
    Object? backgroundColor = $absent,
    Object? padding = $absent,
    Object? margin = $absent,
    Object? borderRadius = $absent,
    Object? clipBehavior = $absent,
    Object? transitions = $absent,
  }) {
    return ElStyle(
      width: identical(width, $absent) ? this.width : width,
      height: identical(height, $absent) ? this.height : height,
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
      widthFactor: other.widthFactor ?? widthFactor,
      heightFactor: other.heightFactor ?? heightFactor,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      borderRadius: other.borderRadius ?? borderRadius,
      clipBehavior: other.clipBehavior ?? clipBehavior,
      transitions: other.transitions ?? transitions,
    );
  }

  List<Object?> get _props => [
    width,
    height,
    widthFactor,
    heightFactor,
    backgroundColor,
    padding,
    margin,
    borderRadius,
    clipBehavior,
    transitions,
  ];
}

extension ElTransitionExt on ElTransition {
  List<Object?> get _props => [field, duration, curve, delay];
}
