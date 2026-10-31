import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 日历格子相对展示月份的归属。
enum ElCalendarDayType {
  /// 上个月的日期。
  prevMonth,

  /// 当前月份的日期。
  currentMonth,

  /// 下个月的日期。
  nextMonth,
}

/// 日历公共声明。
class ElCalendar extends StatelessWidget {
  /// 创建日历公共声明。
  const ElCalendar({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.displayMonth,
    this.onMonthChanged,
    this.firstDayOfWeek = DateTime.sunday,
    this.weekdayLabels = const ['日', '一', '二', '三', '四', '五', '六'],
    this.headerFormatter,
    this.dayBuilder,
    this.showHeader = true,
    this.style,
    this.cellStyle,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(weekdayLabels.length == 7, 'weekdayLabels 必须是 7 个'),
       assert(
         firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday,
         'firstDayOfWeek 必须在 1 至 7 之间',
       );

  /// 普通值输入，具体同步由品牌实现处理。
  final DateTime? value;

  /// 外部双向模型，生命周期由调用方管理。
  final ValueNotifier<DateTime?>? modelValue;

  /// 模型变化通知。
  final ValueChanged<DateTime?>? onChanged;

  /// 当前展示月份，只使用年月部分。
  final DateTime? displayMonth;

  /// 展示月份变化通知。
  final ValueChanged<DateTime>? onMonthChanged;

  /// 每周首日，取 DateTime.monday 至 DateTime.sunday。
  final int firstDayOfWeek;

  /// 从周日开始排列的七个星期标题。
  final List<String> weekdayLabels;

  /// 月份标题格式化函数。
  final String Function(DateTime month)? headerFormatter;

  /// 自定义日期格子的内容。
  final Widget Function(
    BuildContext context,
    DateTime date,
    ElCalendarDayType type,
  )?
  dayBuilder;

  /// 显示月份导航与标题。
  final bool showHeader;

  /// 组件根样式。
  final ElStyle? style;

  /// 日期格子的样式。
  final ElStyle? cellStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).calendarBuilder!(context, this);
}
