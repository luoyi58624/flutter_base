import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 空状态内容的原因。
enum ElEmptyState {
  /// 当前没有内容。
  empty,

  /// 内容加载失败。
  error,
}

/// 空内容或加载错误的共同状态声明。
class ElEmpty extends StatelessWidget {
  /// 创建状态内容，默认标题和图标由品牌按 state 选择。
  const ElEmpty({
    super.key,
    this.state = .empty,
    this.title,
    this.description,
    this.icon,
    this.style,
    this.semanticLabel,
    this.child,
  });

  /// 空内容或加载错误状态。
  final ElEmptyState state;

  /// 状态标题，省略时使用对应状态的默认文字。
  final Object? title;

  /// 补充说明。
  final Object? description;

  /// 自定义状态图标，省略时由品牌按状态选择。
  final Object? icon;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 辅助技术读取的状态名称。
  final String? semanticLabel;

  /// 底部操作或补充内容。
  final Object? child;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.emptyBuilder)(context, this);
}
