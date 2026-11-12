part of 'index.dart';

/// 覆盖在内容上方、不占布局空间的 Mac 滚动条。
class ElMacScrollbar extends StatelessWidget {
  /// 创建 Mac 悬浮滚动条。
  const ElMacScrollbar({
    super.key,
    this.controller,
    this.direction = AxisDirection.down,
    this.notificationDepth = 0,
    this.extent = 10,
    this.thickness = 6,
    this.radius = 9999,
    this.minThumbLength = 36,
    this.thumbColor,
    this.thumbHoverColor,
    this.thumbActiveColor,
    required this.child,
  }) : assert(extent > 0),
       assert(thickness > 0 && thickness <= extent),
       assert(radius >= 0),
       assert(minThumbLength > 0),
       assert(notificationDepth >= 0);

  /// 与内容共享的官方控制器，缺省使用最近的 PrimaryScrollController。
  final ScrollController? controller;

  /// 滚动轴方向，纵向条位于右侧，横向条位于底部。
  final AxisDirection direction;

  /// 被监听滚动视图相对 child 的嵌套深度。
  final int notificationDepth;

  /// 悬浮滚动条的命中区域宽度，不挤占内容空间。
  final double extent;

  /// 滑块的可见宽度，两侧留白仍属于滑块拖动区域。
  final double thickness;

  /// 滑块圆角半径，默认呈胶囊形。
  final double radius;

  /// 滑块的最小长度。
  final double minThumbLength;

  /// 滑块的默认颜色，缺省随系统明暗模式变化。
  final Color? thumbColor;

  /// 鼠标悬停滑块时的颜色。
  final Color? thumbHoverColor;

  /// 拖动滑块时的颜色，缺省沿用悬停颜色。
  final Color? thumbActiveColor;

  /// 被滚动条包装的内容。
  final Widget child;

  @override
  Widget build(BuildContext context) => _buildScrollbar(
    context,
    occupiesSpace: false,
    controller: controller,
    direction: direction,
    notificationDepth: notificationDepth,
    extent: extent,
    thickness: thickness,
    radius: radius,
    minThumbLength: minThumbLength,
    thumbColor: thumbColor,
    thumbHoverColor: thumbHoverColor,
    thumbActiveColor: thumbActiveColor,
    child: child,
  );
}
