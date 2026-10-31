import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 分段控制器的选项配置。
class ElSegmentedOption {
  /// 创建分段控制器的选项配置。
  const ElSegmentedOption({
    required this.value,
    this.label,
    this.disabled = false,
  });

  /// 选项业务值。
  final Object? value;

  /// 选项显示内容，省略时由实现使用值的文字。
  final Object? label;

  /// 禁止选择该项。
  final bool disabled;
}

/// 分段控制器公共声明。
class ElSegmented extends StatelessWidget {
  /// 创建分段控制器公共声明。
  const ElSegmented({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.options,
    this.disabled = false,
    this.block = false,
    this.direction = Axis.horizontal,
    this.style,
    this.itemStyle,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥');

  /// 普通值输入，具体同步由品牌实现处理。
  final Object? value;

  /// 外部双向模型，生命周期由调用方管理。
  final ValueNotifier<Object?>? modelValue;

  /// 模型变化通知。
  final ValueChanged<Object?>? onChanged;

  /// 分段选项列表。
  final List<ElSegmentedOption> options;

  /// 禁止整个分段控制器交互。
  final bool disabled;

  /// 占满可用空间并均分选项。
  final bool block;

  /// 选项排列方向。
  final Axis direction;

  /// 组件根样式。
  final ElStyle? style;

  /// 单个选项的样式。
  final ElStyle? itemStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).segmentedBuilder!(context, this);
}
