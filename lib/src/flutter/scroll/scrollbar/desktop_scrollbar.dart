import 'package:flutter/widgets.dart';

/// 复用官方 [RawScrollbar] 的桌面滚动条，Windows 占位，macOS/Linux 悬浮。
///
/// 与子树共享 [ScrollController]；不传时使用 [PrimaryScrollController]。
/// 滑块拖动、轨道翻页、指标监听和绘制均由官方滚动条处理。
class ElDesktopScrollbar extends StatelessWidget {
  /// 创建预留 15 像素轨道空间的 Windows 滚动条。
  const ElDesktopScrollbar.windows({
    super.key,
    this.controller,
    this.direction = AxisDirection.down,
    this.notificationDepth = 0,
    required this.child,
  }) : _occupiesSpace = true;

  /// 创建不占正文空间的 macOS/Linux 悬浮滚动条。
  const ElDesktopScrollbar.mac({
    super.key,
    this.controller,
    this.direction = AxisDirection.down,
    this.notificationDepth = 0,
    required this.child,
  }) : _occupiesSpace = false;

  /// 与被包装滚动视图共享的官方控制器，缺省使用最近的 PrimaryScrollController。
  final ScrollController? controller;

  /// 滚动轴方向，横向条位于底部，纵向条位于右侧。
  final AxisDirection direction;

  /// 被监听的滚动视图相对 [child] 的嵌套深度。
  final int notificationDepth;

  /// 被滚动条包装的内容。
  final Widget child;

  final bool _occupiesSpace;

  @override
  Widget build(BuildContext context) {
    final vertical = axisDirectionToAxis(direction) == Axis.vertical;
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final trackColor = dark ? const Color(0xFF2C2C2C) : const Color(0xFFFCFCFC);
    Widget content = child;
    if (_occupiesSpace) {
      // 占位放在官方绘制层内部，让条带仍画在整个包装区域的最外缘。
      final border = BorderSide(color: trackColor, width: 15);
      content = DecoratedBox(
        decoration: BoxDecoration(
          border: vertical ? Border(right: border) : Border(bottom: border),
        ),
        child: Padding(
          padding: vertical ? const EdgeInsets.only(right: 15) : const EdgeInsets.only(bottom: 15),
          child: child,
        ),
      );
    }
    return RawScrollbar(
      controller: controller,
      notificationPredicate: (notification) =>
          notification.depth == notificationDepth && notification.metrics.axis == axisDirectionToAxis(direction),
      scrollbarOrientation: vertical ? ScrollbarOrientation.right : ScrollbarOrientation.bottom,
      thumbVisibility: _occupiesSpace,
      trackVisibility: _occupiesSpace,
      interactive: true,
      // 命中宽度覆盖整条轨道，shape 只收窄绘制，避免细边界被官方识别成轨道点击。
      thickness: _occupiesSpace ? 15 : 10,
      shape: _ThumbShape(axis: axisDirectionToAxis(direction), inset: _occupiesSpace ? 3 : 2),
      minThumbLength: 36,
      padding: EdgeInsets.zero,
      thumbColor: dark ? const Color(0x8BFFFFFF) : const Color(0x72000000),
      trackColor: trackColor,
      trackBorderColor: const Color(0x00000000),
      child: content,
    );
  }
}

// 官方 Painter 用完整 thumbRect 命中；仅通过形状缩小视觉宽度，不缩小拖动区域。
class _ThumbShape extends OutlinedBorder {
  const _ThumbShape({required this.axis, required this.inset, this.radius = 3});

  final Axis axis;
  final double inset;
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final visual = axis == Axis.vertical
        ? Rect.fromLTRB(rect.left + inset, rect.top, rect.right - inset, rect.bottom)
        : Rect.fromLTRB(rect.left, rect.top + inset, rect.right, rect.bottom - inset);
    return Path()..addRRect(RRect.fromRectAndRadius(visual, Radius.circular(radius)));
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  _ThumbShape copyWith({BorderSide? side}) => this;

  @override
  _ThumbShape scale(double t) => _ThumbShape(axis: axis, inset: inset * t, radius: radius * t);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}
