import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 字体图标、尺寸、颜色和辅助名称的公共声明。
class ElIcon extends StatelessWidget {
  /// 创建图标配置，字形信息继续使用 Flutter IconData。
  const ElIcon(this.child, {super.key, this.size, this.color, this.style, this.semanticLabel})
    : assert(size == null || (size >= 0 && size < double.infinity));

  /// 要展示的字体图标。
  final IconData? child;

  /// 图标的逻辑边长，省略时继承品牌默认值。
  final double? size;

  /// 显式图标颜色。
  final Color? color;

  /// 在品牌默认外观之后合并的样式，字重、可变轴与方向由此或既有机制处理。
  final ElStyle? style;

  /// 辅助名称，装饰图标可省略。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.icon)(context, this);
}
