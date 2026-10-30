import 'package:flutter/painting.dart';

/// 布局内核的主轴与交叉轴映射，不读取滚动位置或 Widget。
final class AxisGeometry {
  /// 创建一次解析后可复用的方向映射。
  const AxisGeometry(this.axis, {this.textDirection = TextDirection.ltr, this.reverse = false});

  /// 条目推进方向。
  final Axis axis;

  /// 横向推进与垂直网格交叉轴的文字方向。
  final TextDirection textDirection;

  /// 是否反转主轴物理方向。
  final bool reverse;

  /// 主轴坐标是否从右侧或底部推进。
  bool get reversed => reverse != (axis == Axis.horizontal && textDirection == TextDirection.rtl);

  /// 垂直布局的交叉轴是否由右向左排列。
  bool get crossReversed => axis == Axis.vertical && textDirection == TextDirection.rtl;

  /// 读取物理尺寸的主轴分量。
  double mainOf(Size size) => axis == Axis.vertical ? size.height : size.width;

  /// 读取物理尺寸的交叉轴分量。
  double crossOf(Size size) => axis == Axis.vertical ? size.width : size.height;

  /// 将主轴、交叉轴尺寸还原成物理宽高。
  Size size(double main, double cross) => axis == Axis.vertical ? Size(cross, main) : Size(main, cross);

  /// 将正向内容坐标映射为物理坐标；方向反转不会改变业务索引。
  Offset offset(
    double main,
    double cross, {
    required double mainExtent,
    required double crossExtent,
    required Size childSize,
  }) {
    if (reversed) main = mainExtent - main - mainOf(childSize);
    if (crossReversed) cross = crossExtent - cross - crossOf(childSize);
    return axis == Axis.vertical ? Offset(cross, main) : Offset(main, cross);
  }
}
