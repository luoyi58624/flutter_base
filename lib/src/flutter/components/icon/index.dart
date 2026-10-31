import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 图标字体、可变轴和辅助说明的公共声明。
class ElIcon extends StatelessWidget {
  /// 创建图标配置；null 图标的占位由品牌实现解释。
  const ElIcon(
    this.child, {
    super.key,
    this.size,
    this.color,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.fontWeight,
    this.semanticLabel,
    this.textDirection,
    this.applyTextScaling = false,
    this.style,
  });

  /// 要展示的字体图标。
  final IconData? child;

  /// 图标的逻辑边长，省略时继承品牌默认值。
  final double? size;

  /// 显式图标颜色。
  final Color? color;

  /// 可变图标字体的 FILL 轴。
  final double? fill;

  /// 可变图标字体的 wght 轴。
  final double? weight;

  /// 可变图标字体的 GRAD 轴。
  final double? grade;

  /// 可变图标字体的 opsz 轴。
  final double? opticalSize;

  /// 图标字体的静态字重。
  final FontWeight? fontWeight;

  /// 图标的辅助名称，装饰图标可省略。
  final String? semanticLabel;

  /// 图标的阅读方向。
  final TextDirection? textDirection;

  /// 是否随系统文字缩放调整占位与字形。
  final bool applyTextScaling;

  /// 在品牌默认样式之后合并的样式。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).iconBuilder!(context, this);
}
