import 'package:flutter/widgets.dart';

import '../../utils/model_value/index.dart';
import '../../views/view/event/event.dart';
import '../../views/view/style/style.dart';
import '../index.dart';

/// 使用列表模型保存各列业务值的滚轮选择器，单列也使用单元素列表。
class ElPicker<T> extends ElModelValue<List<T>> {
  /// columns 表示独立列，options 表示按 children 联动的选项树，两者二选一。
  ElPicker({
    super.key,
    List<T>? value,
    super.modelValue,
    super.onChanged,
    this.columns,
    this.options,
    this.columnLabels = const [],
    this.disabled = false,
    this.style,
    this.event,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert((columns == null) != (options == null), 'columns 与 options 二选一'),
       super(value: value ?? <T>[]);

  /// 每一列的独立选项。
  final List<List<ElMenuOption<T>>>? columns;

  /// 按 children 决定下一列的选项树。
  final List<ElMenuOption<T>>? options;

  /// 各列上方的辅助名称。
  final List<String> columnLabels;

  /// 禁用滚动和选择。
  final bool disabled;

  /// 覆盖品牌默认外观。
  final ElStyle? style;

  /// 原生事件，与组件默认交互组合。
  final ElEvent? event;

  /// 辅助技术读取的选择器名称。
  final String? semanticLabel;
  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.picker)<T>(context, this, $obs);
}

/// 使用 DateTime 模型的年月日滚轮选择。
class ElDatePicker extends ElModelValue<DateTime> {
  /// 未提供值时使用今天，年月改变后自动限制到有效日期。
  ElDatePicker({
    super.key,
    DateTime? value,
    super.modelValue,
    super.onChanged,
    this.min,
    this.max,
    this.disabled = false,
    this.style,
    this.event,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       super(value: value ?? DateTime.now());

  /// 最早可选日期，包含当天。
  final DateTime? min;

  /// 最晚可选日期，包含当天。
  final DateTime? max;

  /// 禁止选择。
  final bool disabled;

  /// 覆盖品牌默认外观。
  final ElStyle? style;

  /// 原生事件。
  final ElEvent? event;

  /// 辅助名称。
  final String? semanticLabel;
  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.datePicker)(context, this, $obs);
}

/// 用当日零点起的 Duration 表示时间的滚轮选择。
class ElTimePicker extends ElModelValue<Duration> {
  /// 可显示秒列，并按分钟和秒步长限定选项。
  ElTimePicker({
    super.key,
    Duration? value,
    super.modelValue,
    super.onChanged,
    this.min = Duration.zero,
    this.max = const Duration(hours: 23, minutes: 59, seconds: 59),
    this.minuteStep = 1,
    this.secondStep = 1,
    this.showSeconds = false,
    this.disabled = false,
    this.style,
    this.event,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(minuteStep > 0 && minuteStep <= 60),
       assert(secondStep > 0 && secondStep <= 60),
       assert(min >= Duration.zero && max < const Duration(days: 1) && min <= max),
       super(value: value ?? min);

  /// 最早可选时刻。
  final Duration min;

  /// 最晚可选时刻。
  final Duration max;

  /// 分钟选项间隔。
  final int minuteStep;

  /// 秒选项间隔。
  final int secondStep;

  /// 是否显示秒列。
  final bool showSeconds;

  /// 禁止选择。
  final bool disabled;

  /// 覆盖品牌默认外观。
  final ElStyle? style;

  /// 原生事件。
  final ElEvent? event;

  /// 辅助名称。
  final String? semanticLabel;
  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.timePicker)(context, this, $obs);
}
