import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 加载骨架的公共声明，加载结束后展示调用方的原正文。
class ElSkeleton extends StatelessWidget {
  /// 创建与 Web 一致的标题、正文行和可选头像占位。
  const ElSkeleton({
    super.key,
    this.loading = true,
    this.rows = 3,
    this.avatar = false,
    this.style,
    this.semanticLabel = '内容加载中',
    this.child,
  });

  /// 当前是否展示加载骨架。
  final bool loading;

  /// 正文行数，由品牌按 Web 规则归一化为 1 至 10 行。
  final num rows;

  /// 在默认骨架中包含头像占位。
  final bool avatar;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 辅助技术读取的加载说明。
  final String? semanticLabel;

  /// 加载完成后的正文，加载期间保留实例与状态。
  final Widget? child;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.skeleton)(context, this);
}
