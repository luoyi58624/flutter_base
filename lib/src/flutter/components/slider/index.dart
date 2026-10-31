import 'package:flutter/material.dart'
    show SemanticFormatterCallback, SliderInteraction;
import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 滑动数值选择公共声明。
class ElSlider extends StatelessWidget {
  /// 创建滑动数值选择公共声明。
  const ElSlider({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.onChangeStart,
    this.onChangeEnd,
    this.divisions,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.secondaryActiveColor,
    this.thumbColor,
    this.overlayColor,
    this.mouseCursor,
    this.semanticFormatterCallback,
    this.focusNode,
    this.allowedInteraction,
    this.padding,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(min <= max, 'min 不得大于 max'),
       assert(divisions == null || divisions > 0, 'divisions 必须大于 0');

  /// 普通值输入，具体同步由品牌实现处理。
  final double? value;

  /// 外部双向模型，生命周期由调用方管理。
  final ValueNotifier<double>? modelValue;

  /// 模型变化通知。
  final ValueChanged<double>? onChanged;

  /// 允许的最小值。
  final double min;

  /// 允许的最大值。
  final double max;

  /// 用户开始拖动时通知当前值。
  final ValueChanged<double>? onChangeStart;

  /// 用户结束拖动时通知当前值。
  final ValueChanged<double>? onChangeEnd;

  /// 离散分段数量，null 表示连续选择。
  final int? divisions;

  /// 显示在滑块提示中的文字。
  final String? label;

  /// 已完成轨道颜色。
  final Color? activeColor;

  /// 未完成轨道颜色。
  final Color? inactiveColor;

  /// 次级活动轨道颜色。
  final Color? secondaryActiveColor;

  /// 滑块颜色。
  final Color? thumbColor;

  /// 按交互状态解析的覆盖色。
  final WidgetStateProperty<Color?>? overlayColor;

  /// 滑块鼠标光标。
  final MouseCursor? mouseCursor;

  /// 将数值转为辅助技术读数。
  final SemanticFormatterCallback? semanticFormatterCallback;

  /// 调用方管理的外部焦点节点。
  final FocusNode? focusNode;

  /// 允许的滑动与轨道点击方式。
  final SliderInteraction? allowedInteraction;

  /// 轨道周围的内边距。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).sliderBuilder!(context, this);
}
