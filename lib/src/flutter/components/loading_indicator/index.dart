import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 加载指示内容和外观的公共声明。
class ElLoadingIndicator extends StatelessWidget {
  /// 创建加载指示配置，不包含旋转或计时实现。
  const ElLoadingIndicator({
    super.key,
    this.size,
    this.child,
    this.style,
    this.semanticLabel = '加载中',
  });

  /// 指示图形的逻辑边长，省略时使用品牌默认值。
  final double? size;

  /// 可选的可见说明内容。
  final Object? child;

  /// 在品牌默认样式之后合并的样式。
  final ElStyle? style;

  /// 没有可见说明时的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).loadingIndicatorBuilder!(context, this);
}
