import 'package:flutter/widgets.dart';

import '../../view/view.dart';
import '../../view/style/style.dart';
import 'scrollbar_base.dart';

/// 用于 Windows 的 Chromium Fluent 内嵌滚动条。
class ElWindowScrollBar extends ElScrollbar {
  /// 创建 Windows 平台滚动条。
  const ElWindowScrollBar({
    this.extent,
    this.animationStyle,
    this.trackColor,
    this.trackColorDark,
    this.thumbColor,
    this.thumbColorDark,
    this.thumbHoverColor,
    this.thumbHoverColorDark,
    this.thumbActiveColor,
    this.thumbActiveColorDark,
    this.arrowColor,
    this.arrowColorDark,
    this.thumbThickness,
    this.minThumbExtent,
  });

  /// 滚动条占用的视口边缘宽度。
  final double? extent;

  /// 交互状态动画配置。
  final AnimationStyle? animationStyle;

  /// 亮色模式轨道颜色。
  final Color? trackColor;

  /// 暗色模式轨道颜色。
  final Color? trackColorDark;

  /// 亮色模式滑块常态色。
  final Color? thumbColor;

  /// 暗色模式滑块常态色。
  final Color? thumbColorDark;

  /// 亮色模式滑块悬停色。
  final Color? thumbHoverColor;

  /// 暗色模式滑块悬停色。
  final Color? thumbHoverColorDark;

  /// 亮色模式滑块按压色。
  final Color? thumbActiveColor;

  /// 暗色模式滑块按压色。
  final Color? thumbActiveColorDark;

  /// 亮色模式箭头颜色。
  final Color? arrowColor;

  /// 暗色模式箭头颜色。
  final Color? arrowColorDark;

  /// 滑块厚度。
  final double? thumbThickness;

  /// 滑块最小主轴长度。
  final double? minThumbExtent;

  /// 解析滚动条占用的视口边缘宽度。
  double resolveExtent(BuildContext context, Axis axis) => extent ?? 15.0;

  /// 按明暗状态解析轨道颜色。
  Color resolveTrackColor(BuildContext context, {required bool dark}) {
    return dark ? trackColorDark ?? const Color(0xFF2C2C2C) : trackColor ?? const Color(0xFFFCFCFC);
  }

  /// 按明暗与交互状态解析滑块颜色。
  Color resolveThumbColor(BuildContext context, {required bool dark, required bool hovered, required bool dragging}) {
    if (dragging) {
      return dark
          ? thumbActiveColorDark ?? thumbHoverColorDark ?? const Color(0xB3FFFFFF)
          : thumbActiveColor ?? thumbHoverColor ?? const Color(0x99000000);
    }
    if (hovered) {
      return dark ? thumbHoverColorDark ?? const Color(0xB3FFFFFF) : thumbHoverColor ?? const Color(0x99000000);
    }
    return dark ? thumbColorDark ?? const Color(0x8BFFFFFF) : thumbColor ?? const Color(0x72000000);
  }

  /// 按明暗状态解析箭头颜色。
  Color resolveArrowColor(BuildContext context, {required bool dark}) {
    return dark ? arrowColorDark ?? const Color(0x8BFFFFFF) : arrowColor ?? const Color(0x72000000);
  }

  @override
  double resolveInsetExtent(BuildContext context, Axis axis) => resolveExtent(context, axis);

  @override
  AnimationStyle resolveAnimationStyle(BuildContext context) {
    return animationStyle ?? const AnimationStyle(duration: Duration(milliseconds: 160), curve: Curves.easeOut);
  }

  @override
  bool resolveAlwaysVisible(BuildContext context, ElScrollbarAxisDetails axis) => true;

  @override
  bool resolveHoverOnEntireTrack(BuildContext context, ElScrollbarAxisDetails axis) => false;

  @override
  bool resolveCenterThumb(BuildContext context, ElScrollbarAxisDetails axis) => true;

  @override
  double resolveThumbThickness(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool hovered,
    required bool dragging,
  }) {
    return thumbThickness ?? 9.0;
  }

  @override
  double resolveInteractiveThickness(BuildContext context, ElScrollbarAxisDetails axis) {
    return resolveExtent(context, axis.axis);
  }

  @override
  double resolveMinThumbExtent(BuildContext context, ElScrollbarAxisDetails axis) {
    return minThumbExtent ?? 17.0;
  }

  @override
  double resolveLeadingButtonExtent(BuildContext context, ElScrollbarAxisDetails axis) => 18.0;

  @override
  double resolveTrailingButtonExtent(BuildContext context, ElScrollbarAxisDetails axis) => 18.0;

  @override
  bool resolveButtonInteractiveAtBoundary(BuildContext context, ElScrollbarAxisDetails axis, {required bool forward}) =>
      true;

  @override
  Key resolveAxisKey(Axis axis) => ValueKey<String>('el-scrollbar-win-strip-${axis.name}');

  @override
  Widget buildAxisBackground(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  }) {
    return ElView(
      style: ElStyle(
        bgColor: resolveTrackColor(context, dark: false),
        onDark: ElStyle(bgColor: resolveTrackColor(context, dark: true)),
      ),
    );
  }

  @override
  Widget buildThumb(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  }) {
    final isVertical = axis.axis == Axis.vertical;
    return ElView(
      key: ValueKey<String>('el-scrollbar-win-thumb-${axis.axis.name}'),
      style: ElStyle(
        width: isVertical ? thumbThickness ?? 9.0 : '100%',
        height: isVertical ? '100%' : thumbThickness ?? 9.0,
        bgColor: resolveThumbColor(context, dark: false, hovered: false, dragging: dragging),
        onHover: ElStyle(bgColor: resolveThumbColor(context, dark: false, hovered: true, dragging: dragging)),
        onDark: ElStyle(
          bgColor: resolveThumbColor(context, dark: true, hovered: false, dragging: dragging),
          onHover: ElStyle(bgColor: resolveThumbColor(context, dark: true, hovered: true, dragging: dragging)),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(9999)),
        transitions: const [ElTransition.field(ElTransitionField.bgColor, Duration(milliseconds: 150))],
      ),
    );
  }

  @override
  Widget buildLeadingButton(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool enabled,
    required bool pressed,
  }) {
    return _buildArrow(context, axis, forward: false, pressed: pressed);
  }

  @override
  Widget buildTrailingButton(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool enabled,
    required bool pressed,
  }) {
    return _buildArrow(context, axis, forward: true, pressed: pressed);
  }

  Widget _buildArrow(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool forward,
    required bool pressed,
  }) {
    final direction = switch ((axis.axis, forward)) {
      (Axis.vertical, false) => AxisDirection.up,
      (Axis.vertical, true) => AxisDirection.down,
      (Axis.horizontal, false) => AxisDirection.left,
      (Axis.horizontal, true) => AxisDirection.right,
    };
    final side = pressed ? 7.0 : 9.0;
    final delta = forward ? 1.0 : -1.0;
    final transform = axis.axis == Axis.vertical
        ? ElTransform.translate(0.0, delta)
        : ElTransform.translate(delta, 0.0);
    return ElView(
      style: ElStyle(
        width: side,
        height: side,
        bgColor: resolveArrowColor(context, dark: false),
        onDark: ElStyle(bgColor: resolveArrowColor(context, dark: true)),
        clipper: _WinArrowClipper(direction),
        transform: transform,
      ),
    );
  }

  @override
  Widget buildCorner(BuildContext context, ElScrollbarDetails details) {
    return ElView(
      style: ElStyle(
        bgColor: resolveTrackColor(context, dark: false),
        onDark: ElStyle(bgColor: resolveTrackColor(context, dark: true)),
      ),
    );
  }
}

class _WinArrowClipper extends CustomClipper<Path> {
  const _WinArrowClipper(this.direction);

  final AxisDirection direction;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    switch (direction) {
      case AxisDirection.up:
        path
          ..moveTo(w / 2.0, h * 0.25)
          ..lineTo(w, h * 0.72)
          ..lineTo(0.0, h * 0.72);
      case AxisDirection.down:
        path
          ..moveTo(w / 2.0, h * 0.75)
          ..lineTo(w, h * 0.28)
          ..lineTo(0.0, h * 0.28);
      case AxisDirection.left:
        path
          ..moveTo(w * 0.25, h / 2.0)
          ..lineTo(w * 0.72, 0.0)
          ..lineTo(w * 0.72, h);
      case AxisDirection.right:
        path
          ..moveTo(w * 0.75, h / 2.0)
          ..lineTo(w * 0.28, 0.0)
          ..lineTo(w * 0.28, h);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _WinArrowClipper oldClipper) => oldClipper.direction != direction;
}
