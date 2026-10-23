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
    Object? aspectRatio = $absent,
    Object? backgroundColor = $absent,
    Object? gradient = $absent,
    Object? boxShadow = $absent,
    Object? opacity = $absent,
    Object? transform = $absent,
    Object? transformAlignment = $absent,
    Object? filter = $absent,
    Object? backdropFilter = $absent,
    Object? padding = $absent,
    Object? margin = $absent,
    Object? alignment = $absent,
    Object? border = $absent,
    Object? outline = $absent,
    Object? borderRadius = $absent,
    Object? clipper = $absent,
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
      aspectRatio: identical(aspectRatio, $absent)
          ? this.aspectRatio
          : aspectRatio as num?,
      backgroundColor: identical(backgroundColor, $absent)
          ? this.backgroundColor
          : backgroundColor as Color?,
      gradient: identical(gradient, $absent)
          ? this.gradient
          : gradient as Gradient?,
      boxShadow: identical(boxShadow, $absent)
          ? this.boxShadow
          : boxShadow as List<BoxShadow>?,
      opacity: identical(opacity, $absent) ? this.opacity : opacity as num?,
      transform: identical(transform, $absent)
          ? this.transform
          : transform as ElTransform?,
      transformAlignment: identical(transformAlignment, $absent)
          ? this.transformAlignment
          : transformAlignment as AlignmentGeometry?,
      filter: identical(filter, $absent) ? this.filter : filter as ElFilter?,
      backdropFilter: identical(backdropFilter, $absent)
          ? this.backdropFilter
          : backdropFilter as ElFilter?,
      padding: identical(padding, $absent)
          ? this.padding
          : padding as EdgeInsetsGeometry?,
      margin: identical(margin, $absent)
          ? this.margin
          : margin as EdgeInsetsGeometry?,
      alignment: identical(alignment, $absent)
          ? this.alignment
          : alignment as AlignmentGeometry?,
      border: identical(border, $absent) ? this.border : border as BoxBorder?,
      outline: identical(outline, $absent)
          ? this.outline
          : outline as ElOutline?,
      borderRadius: identical(borderRadius, $absent)
          ? this.borderRadius
          : borderRadius as BorderRadiusGeometry?,
      clipper: identical(clipper, $absent)
          ? this.clipper
          : clipper as CustomClipper<Path>?,
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
      aspectRatio: other.aspectRatio ?? aspectRatio,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      gradient: other.gradient ?? gradient,
      boxShadow: other.boxShadow ?? boxShadow,
      opacity: other.opacity ?? opacity,
      transform: other.transform ?? transform,
      transformAlignment: other.transformAlignment ?? transformAlignment,
      filter: other.filter ?? filter,
      backdropFilter: other.backdropFilter ?? backdropFilter,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      alignment: other.alignment ?? alignment,
      border: other.border ?? border,
      outline: other.outline ?? outline,
      borderRadius: other.borderRadius ?? borderRadius,
      clipper: other.clipper ?? clipper,
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
    aspectRatio,
    backgroundColor,
    gradient,
    boxShadow,
    opacity,
    transform,
    transformAlignment,
    filter,
    backdropFilter,
    padding,
    margin,
    alignment,
    border,
    outline,
    borderRadius,
    clipper,
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

extension ElFilterExt on ElFilter {
  ElFilter copyWith({
    Object? blur = $absent,
    Object? blurX = $absent,
    Object? blurY = $absent,
    Object? saturate = $absent,
    Object? brightness = $absent,
    Object? contrast = $absent,
    Object? grayscale = $absent,
    Object? sepia = $absent,
    Object? invert = $absent,
    Object? hueRotate = $absent,
    Object? opacity = $absent,
  }) {
    return ElFilter(
      blur: identical(blur, $absent) ? this.blur : blur as num?,
      blurX: identical(blurX, $absent) ? this.blurX : blurX as num?,
      blurY: identical(blurY, $absent) ? this.blurY : blurY as num?,
      saturate: identical(saturate, $absent) ? this.saturate : saturate as num?,
      brightness: identical(brightness, $absent)
          ? this.brightness
          : brightness as num?,
      contrast: identical(contrast, $absent) ? this.contrast : contrast as num?,
      grayscale: identical(grayscale, $absent)
          ? this.grayscale
          : grayscale as num?,
      sepia: identical(sepia, $absent) ? this.sepia : sepia as num?,
      invert: identical(invert, $absent) ? this.invert : invert as num?,
      hueRotate: identical(hueRotate, $absent)
          ? this.hueRotate
          : hueRotate as num?,
      opacity: identical(opacity, $absent) ? this.opacity : opacity as num?,
    );
  }

  List<Object?> get _props => [
    blur,
    blurX,
    blurY,
    saturate,
    brightness,
    contrast,
    grayscale,
    sepia,
    invert,
    hueRotate,
    opacity,
  ];
}
