import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 统计数值公共声明。
class ElStatistic extends StatelessWidget {
  /// 创建统计数值公共声明。
  const ElStatistic({
    super.key,
    required this.value,
    this.title,
    this.precision = 0,
    this.groupSeparator = ',',
    this.formatter,
    this.prefix,
    this.suffix,
    this.style,
    this.titleStyle,
    this.valueStyle,
    this.semanticLabel,
  }) : assert(precision >= 0, 'precision 不能为负');

  /// 统计内容，数值以外的输入可作为文字展示。
  final Object? value;

  /// 统计标题。
  final Object? title;

  /// 显示的小数位数。
  final int precision;

  /// 数值分组分隔符，空串表示不分组。
  final String groupSeparator;

  /// 自定义值格式化函数，优先于默认数值格式。
  final String Function(Object? value)? formatter;

  /// 读数前置内容。
  final Object? prefix;

  /// 读数后置内容。
  final Object? suffix;

  /// 组件根样式。
  final ElStyle? style;

  /// 统计标题样式。
  final ElStyle? titleStyle;

  /// 统计读数样式。
  final ElStyle? valueStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).statisticBuilder!(context, this);
}
