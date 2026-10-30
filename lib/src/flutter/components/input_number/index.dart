import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 控制按钮位置：官方 `controls-position`。
/// 缺省左右分置（减在左、加在右），`right` 是右侧竖排上下两钮。
enum ElInputNumberControls { sides, right }

/// 公共 InputNumber 声明，由全局组件主题提供具体实现。
class ElInputNumber extends StatelessWidget {
  /// 创建 InputNumber 公共声明。
  const ElInputNumber({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.step = 1,
    this.stepStrictly = false,
    this.min,
    this.max,
    this.precision,
    this.controls = true,
    this.controlsPosition = ElInputNumberControls.sides,
    this.disabled = false,
    this.readOnly = false,
    this.placeholder,
    this.width,
    this.style,
    this.semanticLabel,
    this.autofillHints = const <String>[],
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(min == null || max == null || min <= max, 'min 不得大于 max'),
       assert(precision == null || precision >= 0, 'precision 不得为负');

  /// 步进量（官方 step）
  final num step;

  /// 值只能是 step 的整数倍（官方 step-strictly）
  final bool stepStrictly;

  /// 允许的最小值。
  final num? min;

  /// 允许的最大值。
  final num? max;

  /// 小数位数；声明后显示与写回都按此位数取整（官方 precision）
  final int? precision;

  /// 是否显示步进按钮（官方 controls）
  final bool controls;

  /// 步进按钮的位置。
  final ElInputNumberControls controlsPosition;

  /// 是否禁用输入和交互。
  final bool disabled;

  /// 只读呈现，不接受编辑。
  final bool readOnly;

  /// 空值时显示的提示。
  final String? placeholder;

  /// 自定义整体宽度，缺省取该档官方宽度
  final double? width;

  /// 合并在品牌默认外观之后的样式。
  final ElStyle? style;

  /// 真正文本编辑节点的无障碍标签；步进按钮使用各自独立的动作标签。
  final String? semanticLabel;

  /// 平台自动填充类型提示；null 禁用，空列表启用但不指定字段类型。
  final Iterable<String>? autofillHints;

  /// 当前值；也可由品牌实现接入祖先表单字段。
  final num? value;

  /// 外部双向绑定，生命周期由调用方管理。
  final ValueNotifier<num?>? modelValue;

  /// 用户修改已确认值后的通知。
  final ValueChanged<num?>? onChanged;

  @override
  Widget build(BuildContext context) => ElComponentProvider.of(context).inputNumberBuilder!(context, this);
}
