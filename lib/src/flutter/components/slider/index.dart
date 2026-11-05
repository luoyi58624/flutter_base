import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 滑块数值提示的显示方式。
enum ElSliderValueLabelDisplay {
  /// 交互或键盘聚焦时显示。
  auto,

  /// 始终显示。
  on,

  /// 隐藏提示。
  off,
}

/// 使用与滑块相同单位的刻度位置和可选文字。
class ElSliderMark {
  /// 创建刻度。
  const ElSliderMark({required this.value, this.label});

  /// 刻度对应的数值。
  final double value;

  /// 刻度下方的文字或内容，省略时只显示刻度。
  final Object? label;
}

/// 单值或范围滑块声明，D 为 double 或 `List<double>` 的完整模型。
class ElSlider<D> extends ElModelValue<D> {
  /// 创建单滑块，省略普通值时以 min 作为初始值。
  ElSlider({
    super.key,
    D? value,
    super.modelValue,
    super.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.buffer,
    this.marks = false,
    this.label,
    this.valueLabelDisplay = .auto,
    this.valueLabelFormat,
    this.semanticValueFormat,
    this.disabled = false,
    this.unit = '%',
    this.startLabel = '柔和',
    this.endLabel = '鲜明',
    this.style,
    this.focusNode,
    this.event,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(0.0 is D, '单滑块的模型类型必须兼容 double'),
       assert(value == null || value is double, '单滑块的值必须为 double'),
       assert(modelValue == null || modelValue.value is double, '单滑块模型必须持有 double'),
       assert(min <= max, 'min 不得大于 max'),
       assert(step == null || (step > 0 && step < double.infinity), 'step 须为正有限数或 null'),
       assert(marks is bool || marks is List<ElSliderMark>, 'marks 须为 bool 或 ElSliderMark 列表'),
       isRange = false,
       super(value: value ?? min as D);

  /// 创建范围滑块，D 为完整 `List<double>`，初始值或模型由调用方提供。
  ElSlider.range({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.buffer,
    this.marks = false,
    this.label,
    this.valueLabelDisplay = .auto,
    this.valueLabelFormat,
    this.semanticValueFormat,
    this.disabled = false,
    this.unit = '%',
    this.startLabel = '柔和',
    this.endLabel = '鲜明',
    this.style,
    this.focusNode,
    this.event,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert((modelValue?.value ?? value) is List<double>, '范围滑块须提供 List<double> 初始值或模型'),
       assert(min <= max, 'min 不得大于 max'),
       assert(step == null || (step > 0 && step < double.infinity), 'step 须为正有限数或 null'),
       assert(marks is bool || marks is List<ElSliderMark>, 'marks 须为 bool 或 ElSliderMark 列表'),
       isRange = true;

  /// 是否由范围构造创建。
  final bool isRange;

  /// 挂载后由公共模型持有的完整数值。
  D get currentValue => $obs.value;

  /// 写入同一模型并沿用公共通知规则。
  set currentValue(D value) => $obs.value = value;

  /// 允许的最小值。
  final double min;

  /// 允许的最大值。
  final double max;

  /// 业务值步长，null 仅允许 marks；拖动圆块连续跟手，松开后吸附，触屏仅抬起提交。
  final double? step;

  /// 已缓冲到的数值，与 min / max 使用相同单位。
  final double? buffer;

  /// true 按步长展示刻度，列表指定刻度位置与内容，false 隐藏刻度。
  final Object marks;

  /// 滑块的可见标签及默认辅助名称。
  final String? label;

  /// 数值提示的显示方式。
  final ElSliderValueLabelDisplay valueLabelDisplay;

  /// 自定义可见数值文案，索引区分范围的两个端点。
  final String Function(double value, int index)? valueLabelFormat;

  /// 自定义辅助技术数值文案，省略时沿用可见文案。
  final String Function(double value, int index)? semanticValueFormat;

  /// 禁止拖动与键盘调整。
  final bool disabled;

  /// 默认数值文案追加的单位。
  final String unit;

  /// 轨道起点说明。
  final String? startLabel;

  /// 轨道终点说明。
  final String? endLabel;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 外部焦点节点，生命周期由调用方管理。
  final FocusNode? focusNode;

  /// 用户事件，沿用公共事件与 preventDefault 规则。
  final ElEvent? event;

  @override
  Widget obsBuilder(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.sliderBuilder)<D>(context, this);
}
