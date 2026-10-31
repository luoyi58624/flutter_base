import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 描述列表的单项配置。
class ElDescriptionsItem {
  /// 创建描述列表的单项配置。
  const ElDescriptionsItem({
    this.label,
    this.child,
    this.span = 1,
    this.labelStyle,
    this.contentStyle,
  }) : assert(span >= 1, 'span 至少为 1');

  /// 条目标签内容。
  final Object? label;

  /// 条目正文内容。
  final Object? child;

  /// 条目占据的列数。
  final int span;

  /// 单项标签样式。
  final ElStyle? labelStyle;

  /// 单项正文样式。
  final ElStyle? contentStyle;
}

/// 描述列表公共声明。
class ElDescriptions extends StatelessWidget {
  /// 创建描述列表公共声明。
  const ElDescriptions({
    super.key,
    required this.items,
    this.title,
    this.extra,
    this.column = 3,
    this.border = false,
    this.direction = Axis.horizontal,
    this.style,
    this.titleStyle,
    this.labelStyle,
    this.contentStyle,
    this.semanticLabel,
  }) : assert(column >= 1, 'column 至少为 1');

  /// 描述条目列表。
  final List<ElDescriptionsItem> items;

  /// 列表标题。
  final Object? title;

  /// 标题旁的附加操作内容。
  final Object? extra;

  /// 每行的列数。
  final int column;

  /// 显示单元格边框。
  final bool border;

  /// 标签与内容的排列方向。
  final Axis direction;

  /// 组件根样式。
  final ElStyle? style;

  /// 列表标题样式。
  final ElStyle? titleStyle;

  /// 条目标签的默认样式。
  final ElStyle? labelStyle;

  /// 条目正文的默认样式。
  final ElStyle? contentStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).descriptionsBuilder!(context, this);
}
