import 'package:flutter/widgets.dart';

import '../../utils/model_value/index.dart' show ElModelValue;
import '../../views/view/style/style.dart' show ElStyle;
import '../index.dart' show ElComponentProvider;

/// 单日或范围日历声明，D 为 DateTime? 或 `List<DateTime>` 的完整模型。
class ElCalendar<D> extends ElModelValue<D> {
  /// 创建单日选择，未选择时使用可空 DateTime 模型。
  ElCalendar({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.month,
    this.min,
    this.max,
    this.disabledDate,
    this.firstDayOfWeek = DateTime.monday,
    this.disabled = false,
    this.onSelect,
    this.onMonthChanged,
    this.style,
    this.semanticLabel = '日历',
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(value != null || modelValue != null || null is D, '非空 D 必须提供 value 或 modelValue'),
       assert(value == null || value is DateTime, '单日日历值必须为 DateTime'),
       assert(modelValue == null || modelValue.value == null || modelValue.value is DateTime, '单日日历模型须持有 DateTime?'),
       assert(firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday, 'firstDayOfWeek 必须在 1 至 7 之间'),
       isRange = false;

  /// 创建范围选择，值依次为一个起点或完整的两个端点。
  ElCalendar.range({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.month,
    this.min,
    this.max,
    this.disabledDate,
    this.firstDayOfWeek = DateTime.monday,
    this.disabled = false,
    this.onSelect,
    this.onMonthChanged,
    this.style,
    this.semanticLabel = '日历',
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert((modelValue?.value ?? value) is List<DateTime>, '范围日历须提供 List<DateTime> 初始值或模型'),
       assert(firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday, 'firstDayOfWeek 必须在 1 至 7 之间'),
       isRange = true;

  /// 是否由范围构造创建。
  final bool isRange;

  /// 挂载后由公共模型持有的完整日期选择。
  D get currentValue => $obs.value;

  /// 写入同一模型并沿用公共通知规则。
  set currentValue(D value) => $obs.value = value;

  /// 当前展示月份，只使用年月部分，省略时由品牌跟随选择或今天。
  final DateTime? month;

  /// 最早可选日期，包含当天。
  final DateTime? min;

  /// 最晚可选日期，包含当天。
  final DateTime? max;

  /// 返回 true 禁用指定日期，范围不得跨过禁用日期。
  final bool Function(DateTime date)? disabledDate;

  /// 每周首日，使用 DateTime.monday 至 DateTime.sunday。
  final int firstDayOfWeek;

  /// 禁止选择与月份导航。
  final bool disabled;

  /// 完成单日或两个范围端点选择时通知，区别于中间值变化。
  final ValueChanged<D>? onSelect;

  /// 用户切换展示月份时通知，仅年月部分参与展示。
  final ValueChanged<DateTime>? onMonthChanged;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 辅助技术读取的日历名称。
  final String? semanticLabel;

  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.calendar)<D>(context, this);
}
