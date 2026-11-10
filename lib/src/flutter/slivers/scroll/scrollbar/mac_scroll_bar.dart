import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../views/view/view.dart';
import '../../../views/view/style/style.dart';
import 'scrollbar_base.dart';

/// 用于 macOS 与 Linux 的 Chromium 风格悬浮滚动条。
class ElMacScrollBar extends ElScrollbar {
  /// 创建 macOS/Linux 平台滚动条。
  const ElMacScrollBar({
    this.thumbColor,
    this.thumbHoverColor,
    this.thumbDragColor,
    this.thumbColorDark,
    this.thumbHoverColorDark,
    this.thumbDragColorDark,
    this.thickness,
    this.interactiveThickness,
    this.radius,
    this.interactive,
    this.trackTapJumps,
    this.horizontalLeadingInset = 0.0,
    this.verticalLeadingInset = 0.0,
  });

  /// 亮色 thumb 常态色。
  final Color? thumbColor;

  /// 亮色 thumb hover 色。
  final Color? thumbHoverColor;

  /// 亮色 thumb 拖拽色。
  final Color? thumbDragColor;

  /// 暗色 thumb 常态色。
  final Color? thumbColorDark;

  /// 暗色 thumb hover 色。
  final Color? thumbHoverColorDark;

  /// 暗色 thumb 拖拽色。
  final Color? thumbDragColorDark;

  /// thumb 常态厚度。
  final double? thickness;

  /// hover / 拖拽时的加厚厚度。
  final double? interactiveThickness;

  /// thumb 圆角半径。
  final double? radius;

  /// 是否可交互（thumb 拖拽 / 轨道点击）。
  final bool? interactive;

  /// 点击轨道是否跳页。
  final bool? trackTapJumps;

  /// 横条左端缩进：视口左缘带被 fixed 成员（行号列 / 冻结列）占据时，把
  /// 横条起点推到固定带之后。
  final double horizontalLeadingInset;

  /// 纵条顶端缩进：对称场景（顶部固定带）用。
  final double verticalLeadingInset;

  @override
  double resolveMainAxisLeadingInset(BuildContext context, ElScrollbarAxisDetails axis) {
    return axis.axis == Axis.horizontal ? horizontalLeadingInset : verticalLeadingInset;
  }

  /// 按明暗与交互状态解析滑块颜色。
  Color resolveThumbColor(BuildContext context, {required bool dark, required bool hovered, required bool dragging}) {
    if (dragging) {
      return dark
          ? thumbDragColorDark ?? const Color.fromRGBO(255, 255, 255, 0.62)
          : thumbDragColor ?? const Color.fromRGBO(37, 41, 46, 0.58);
    }
    if (hovered) {
      return dark
          ? thumbHoverColorDark ?? const Color.fromRGBO(255, 255, 255, 0.44)
          : thumbHoverColor ?? const Color.fromRGBO(37, 41, 46, 0.42);
    }
    return dark
        ? thumbColorDark ?? const Color.fromRGBO(255, 255, 255, 0.30)
        : thumbColor ?? const Color.fromRGBO(37, 41, 46, 0.28);
  }

  /// 按交互状态解析滑块圆角。
  double resolveThumbRadius(BuildContext context, {required bool hovered, required bool dragging}) => radius ?? 999.0;

  @override
  AnimationStyle resolveAnimationStyle(BuildContext context) {
    return const AnimationStyle(duration: Duration(milliseconds: 160), curve: Curves.easeOut);
  }

  @override
  bool resolveInteractive(BuildContext context, ElScrollbarAxisDetails axis) => interactive ?? true;

  @override
  bool resolveTrackTapJumps(BuildContext context, ElScrollbarAxisDetails axis) => trackTapJumps ?? true;

  @override
  double resolveThumbThickness(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool hovered,
    required bool dragging,
  }) {
    return thickness ?? 8.0;
  }

  @override
  double resolveInteractiveThickness(BuildContext context, ElScrollbarAxisDetails axis) {
    final visual = thickness ?? 8.0;
    final fallback = isDesktopPlatform(defaultTargetPlatform) ? visual : 14.0;
    return mathMax(visual, interactiveThickness ?? fallback);
  }

  @override
  double resolveMinThumbExtent(BuildContext context, ElScrollbarAxisDetails axis) => 36.0;

  @override
  double resolveEdgeMargin(BuildContext context, ElScrollbarAxisDetails axis) => 2.0;

  @override
  Duration resolveFadeDelay(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 1000);
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
    final duration = animationStyle.duration ?? const Duration(milliseconds: 160);
    final curve = animationStyle.curve ?? Curves.easeOut;
    final transition = ElTransition.all(duration, curve);
    final fade = ElTransition.fields(
      const {ElTransitionField.backgroundColor},
      resolveFadeDuration(context, axis),
      curve,
    );
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

  /// 返回两个厚度中的较大值。
  static double mathMax(double a, double b) => a > b ? a : b;
}
