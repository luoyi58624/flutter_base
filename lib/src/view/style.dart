part of 'index.dart';

/// 命令式 View 的初始样式，创建后直接通过 View 属性更新。
class ElStyle {
  /// 声明背景色、盒子尺寸与内外边距，宽高均包含 padding。
  const ElStyle({this.bgColor, this.width, this.height, this.margin = EdgeInsets.zero, this.padding = EdgeInsets.zero})
    : assert(width == null || (width >= 0 && width < double.infinity)),
      assert(height == null || (height >= 0 && height < double.infinity));

  /// 背景色，空值表示透明。
  final Color? bgColor;

  /// 盒子宽度，空值在有界约束下填满可用宽度，否则由内容决定。
  final double? width;

  /// 盒子高度，空值由垂直排列的子 View 与 padding 决定。
  final double? height;

  /// 盒子外部的非负边距，相邻 View 的边距相加。
  final EdgeInsets margin;

  /// 背景内部的非负边距。
  final EdgeInsets padding;
}
