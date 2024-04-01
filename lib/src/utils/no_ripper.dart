part of flutter_base;

/// 禁止组件水波纹，全局禁用: MaterialApp -> Theme -> splashFactory = noRipperFactory
///
/// 局部使用：
/// ```dart
///  Theme(
///     data: Theme.of(context).copyWith(splashFactory: noRipperFactory, highlightColor: Colors.transparent),
///     child: Child(),
///  )
/// ```
const noRipperFactory = _NoRipperFactory();

class _NoRipperFactory extends InteractiveInkFeatureFactory {
  const _NoRipperFactory();

  @override
  InteractiveInkFeature create(
      {required MaterialInkController controller,
      required RenderBox referenceBox,
      required Offset position,
      required Color color,
      required TextDirection textDirection,
      bool containedInkWell = false,
      RectCallback? rectCallback,
      BorderRadius? borderRadius,
      ShapeBorder? customBorder,
      double? radius,
      VoidCallback? onRemoved}) {
    return _NoInteractiveInkFeature(
        controller: controller, referenceBox: referenceBox, color: color, onRemoved: onRemoved);
  }
}

class _NoInteractiveInkFeature extends InteractiveInkFeature {
  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {}

  _NoInteractiveInkFeature({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Color color,
    VoidCallback? onRemoved,
  }) : super(controller: controller, referenceBox: referenceBox, color: color, onRemoved: onRemoved);
}
