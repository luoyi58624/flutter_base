import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../view/view.dart';
import '../../view/style/style.dart';
import 'scrollbar_base.dart';

/// 使用 Cupertino 几何与交互规则的 iOS 平台滚动条。
class ElIosScrollBar extends ElScrollbar {
  /// 创建 iOS 平台滚动条。
  const ElIosScrollBar({
    this.thumbColor,
    this.thumbColorDark,
    this.thickness,
    this.dragThickness,
    this.interactiveThickness,
    this.radius,
    this.dragRadius,
    this.interactive,
  });

  /// 亮色模式滑块颜色。
  final Color? thumbColor;

  /// 暗色模式滑块颜色。
  final Color? thumbColorDark;

  /// 常态滑块厚度。
  final double? thickness;

  /// 拖拽态滑块厚度。
  final double? dragThickness;

  /// 滑块交互热区厚度。
  final double? interactiveThickness;

  /// 常态滑块圆角半径。
  final double? radius;

  /// 拖拽态滑块圆角半径。
  final double? dragRadius;

  /// 是否启用滑块拖拽。
  final bool? interactive;

  /// 按明暗状态解析滑块颜色。
  Color resolveThumbColor(BuildContext context, {required bool dark, required bool hovered, required bool dragging}) {
    return dark ? thumbColorDark ?? const Color(0x80FFFFFF) : thumbColor ?? const Color(0x59000000);
  }

  /// 按交互状态解析滑块圆角。
  double resolveThumbRadius(BuildContext context, {required bool hovered, required bool dragging}) {
    return dragging ? dragRadius ?? 4.0 : radius ?? 1.5;
  }

  @override
  AnimationStyle resolveAnimationStyle(BuildContext context) {
    return const AnimationStyle(duration: Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  @override
  bool resolveInteractive(BuildContext context, ElScrollbarAxisDetails axis) => interactive ?? true;

  @override
  bool resolveTrackTapJumps(BuildContext context, ElScrollbarAxisDetails axis) => false;

  @override
  bool resolveHapticOnThumbPress(BuildContext context, ElScrollbarAxisDetails axis) => true;

  @override
  double resolveThumbThickness(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool hovered,
    required bool dragging,
  }) {
    return dragging ? dragThickness ?? 8.0 : thickness ?? 3.0;
  }

  @override
  double resolveInteractiveThickness(BuildContext context, ElScrollbarAxisDetails axis) {
    final visual = resolveThumbThickness(context, axis, hovered: false, dragging: false);
    final fallback = isDesktopPlatform(defaultTargetPlatform) ? visual : 28.0;
    final requested = interactiveThickness ?? fallback;
    return requested < visual ? visual : requested;
  }

  @override
  double resolveMinThumbExtent(BuildContext context, ElScrollbarAxisDetails axis) => 36.0;

  @override
  double? resolveMinOverscrollThumbExtent(BuildContext context, ElScrollbarAxisDetails axis) => 8.0;

  @override
  double resolveEdgeMargin(BuildContext context, ElScrollbarAxisDetails axis) => 3.0;

  @override
  double resolveMainAxisMargin(BuildContext context, ElScrollbarAxisDetails axis) => 3.0;

  @override
  Duration resolveFadeDelay(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 1200);
  }

  @override
  Duration resolveFadeDuration(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 250);
  }

  @override
  Duration resolvePressDuration(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 100);
  }

  @override
  Widget buildThumb(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  }) {
    var light = resolveThumbColor(context, dark: false, hovered: hovered, dragging: dragging);
    var dark = resolveThumbColor(context, dark: true, hovered: hovered, dragging: dragging);
    if (!visible) {
      light = light.withValues(alpha: 0.0);
      dark = dark.withValues(alpha: 0.0);
    }
    final animationStyle = resolveAnimationStyle(context);
    final duration = animationStyle.duration ?? const Duration(milliseconds: 100);
    final curve = animationStyle.curve ?? Curves.easeOut;
    final transition = ElTransition.all(duration, curve);
    final fade = ElTransition.fields(const {ElTransitionField.backgroundColor}, resolveFadeDuration(context, axis), curve);
    final isVertical = axis.axis == Axis.vertical;
    return ElView(
      style: ElStyle(
        width: isVertical ? resolveThumbThickness(context, axis, hovered: hovered, dragging: dragging) : '100%',
        height: isVertical ? '100%' : resolveThumbThickness(context, axis, hovered: hovered, dragging: dragging),
        backgroundColor: light,
        onDark: ElStyle(backgroundColor: dark),
        borderRadius: BorderRadius.circular(resolveThumbRadius(context, hovered: hovered, dragging: dragging)),
        transition: <ElTransition>[transition, fade],
      ),
    );
  }
}
