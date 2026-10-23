import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// 供盒模型执行器消费的数值属性；空尺寸表示 auto，空边距表示零。
@immutable
class LayoutStyle {
  /// 创建已求值的布局属性。
  const LayoutStyle({
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.widthFactor,
    this.heightFactor,
  });

  /// 无尺寸和边距修饰的共享属性。
  static const empty = LayoutStyle();

  /// 已求值的视觉盒宽度，不包含外边距。
  final double? width;

  /// 已求值的视觉盒高度，不包含外边距。
  final double? height;

  /// 已解析方向且非零的物理内边距。
  final EdgeInsets? padding;

  /// 已解析方向且非零的物理外边距。
  final EdgeInsets? margin;

  /// 仅用于 auto 宽度的自然盒倍数，空值表示 1。
  final double? widthFactor;

  /// 仅用于 auto 高度的自然盒倍数，空值表示 1。
  final double? heightFactor;
}
