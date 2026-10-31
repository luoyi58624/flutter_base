import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 分页公共声明。
class ElPagination extends StatelessWidget {
  /// 创建分页公共声明。
  const ElPagination({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.total = 0,
    this.pageSize = 10,
    this.pageCount,
    this.pagerCount = 7,
    this.background = false,
    this.small = false,
    this.disabled = false,
    this.hideOnSinglePage = false,
    this.showTotal = false,
    this.totalFormatter,
    this.style,
    this.itemStyle,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(
         pagerCount >= 5 && pagerCount % 2 == 1,
         'pagerCount 必须是不小于 5 的奇数',
       );

  /// 普通值输入，具体同步由品牌实现处理。
  final int? value;

  /// 外部双向模型，生命周期由调用方管理。
  final ValueNotifier<int>? modelValue;

  /// 模型变化通知。
  final ValueChanged<int>? onChanged;

  /// 数据总条数。
  final int total;

  /// 每页数据条数。
  final int pageSize;

  /// 显式总页数，优先于 total 与 pageSize 推导。
  final int? pageCount;

  /// 最多显示的页码数量，要求不小于五的奇数。
  final int pagerCount;

  /// 为页码显示背景块。
  final bool background;

  /// 使用紧凑分页外观。
  final bool small;

  /// 禁止分页交互。
  final bool disabled;

  /// 只有一页时隐藏整个分页器。
  final bool hideOnSinglePage;

  /// 显示数据总数说明。
  final bool showTotal;

  /// 自定义数据总数说明。
  final String Function(int total)? totalFormatter;

  /// 组件根样式。
  final ElStyle? style;

  /// 单个页码的样式。
  final ElStyle? itemStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).paginationBuilder!(context, this);
}
