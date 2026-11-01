import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 分段控制器中的业务值与显示内容。
class ElSegmentedOption<T> {
  /// 创建分段选项，值类型与所属分段模型保持一致。
  const ElSegmentedOption({required this.value, this.label, this.disabled = false});

  /// 选项的业务值。
  final T value;

  /// 显示内容，省略时由品牌使用值的文字。
  final Object? label;

  /// 禁止选择此项。
  final bool disabled;
}

/// 单值绑定的分段控制器声明，T 保留调用方的业务值类型。
class ElSegmented<T> extends ElModelValue<T> {
  /// 创建与 Web 相同的单行分段选择。
  ElSegmented({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    required this.options,
    this.disabled = false,
    this.style,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(value != null || modelValue != null || null is T, '非空 T 必须提供 value 或 modelValue');

  /// 挂载后由公共模型持有的当前值。
  T get currentValue => $obs.value;

  /// 写入同一模型并沿用公共通知规则。
  set currentValue(T value) => $obs.value = value;

  /// 分段选项，不把业务值限制为字符串。
  final List<ElSegmentedOption<T>> options;

  /// 禁止整个分段控制器交互。
  final bool disabled;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 辅助技术读取的分组名称。
  final String? semanticLabel;

  @override
  Widget obsBuilder(BuildContext context) => ElComponentProvider.of(context).segmentedBuilder!<T>(context, this);
}
