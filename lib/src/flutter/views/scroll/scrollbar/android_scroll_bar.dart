import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import '../../view/view.dart';
import '../../view/style/style.dart';
import 'scrollbar_base.dart';

/// 使用 Material 几何与交互规则的 Android 平台滚动条。
class ElAndroidScrollBar extends ElScrollbar {
  /// 创建 Android 平台滚动条。
  const ElAndroidScrollBar({
    this.interactive,
    this.thumbColor,
    this.thumbColorDark,
    this.thickness,
    this.interactiveThickness,
    this.radius,
  });

  /// 是否启用拖拽与轨道点击；null 时启用。
  final bool? interactive;

  /// 亮色模式滑块颜色。
  final Color? thumbColor;

  /// 暗色模式滑块颜色。
  final Color? thumbColorDark;

  /// 滑块视觉厚度。
  final double? thickness;

  /// 滑块交互热区厚度。
  final double? interactiveThickness;

  /// 滑块圆角半径。
  final double? radius;

  /// 按明暗与交互状态解析滑块颜色。
  Color resolveThumbColor(BuildContext context, {required bool dark, required bool hovered, required bool dragging}) {
    if (dragging) {
      return dark ? const Color.fromRGBO(255, 255, 255, 0.82) : const Color.fromRGBO(0, 0, 0, 0.70);
    }
    if (hovered) {
      return dark ? const Color.fromRGBO(255, 255, 255, 0.66) : const Color.fromRGBO(0, 0, 0, 0.54);
    }
    final configured = dark ? thumbColorDark : thumbColor;
    return configured ?? Theme.of(context).highlightColor.withAlpha(0xFF);
  }

  /// 按交互状态解析滑块圆角。
  double resolveThumbRadius(BuildContext context, {required bool hovered, required bool dragging}) => radius ?? 0.0;

  @override
  AnimationStyle resolveAnimationStyle(BuildContext context) {
    return const AnimationStyle(duration: Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  bool resolveInteractive(BuildContext context, ElScrollbarAxisDetails axis) => interactive ?? true;

  @override
  bool resolveTrackTapJumps(BuildContext context, ElScrollbarAxisDetails axis) {
    return resolveInteractive(context, axis);
  }

  @override
  double resolveThumbThickness(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool hovered,
    required bool dragging,
  }) {
    return thickness ?? 4.0;
  }

  @override
  double resolveInteractiveThickness(BuildContext context, ElScrollbarAxisDetails axis) {
    final visual = thickness ?? 4.0;
    final fallback = isDesktopPlatform(defaultTargetPlatform) ? visual : 24.0;
    final requested = interactiveThickness ?? fallback;
    return requested < visual ? visual : requested;
  }

  @override
  double resolveMinThumbExtent(BuildContext context, ElScrollbarAxisDetails axis) => 18.0;

  @override
  Duration resolveFadeDelay(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 600);
  }

  @override
  Duration resolveFadeDuration(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 300);
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
    final duration = animationStyle.duration ?? const Duration(milliseconds: 200);
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
