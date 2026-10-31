import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 评分公共声明。
class ElRate extends StatelessWidget {
  /// 创建评分公共声明。
  const ElRate({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.max = 5,
    this.allowHalf = false,
    this.clearable = false,
    this.disabled = false,
    this.iconSize,
    this.icon,
    this.voidIcon,
    this.colors,
    this.inactiveColor,
    this.showText = false,
    this.showScore = false,
    this.texts,
    this.scoreTemplate,
    this.style,
    this.textStyle,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(max > 0, 'max 必须大于 0'),
       assert(!(showText && showScore), 'showText 与 showScore 互斥');

  /// 普通值输入，具体同步由品牌实现处理。
  final double? value;

  /// 外部双向模型，生命周期由调用方管理。
  final ValueNotifier<double>? modelValue;

  /// 模型变化通知。
  final ValueChanged<double>? onChanged;

  /// 评分图标的总数。
  final int max;

  /// 允许选择半分。
  final bool allowHalf;

  /// 再次激活当前分值时允许清零。
  final bool clearable;

  /// 禁止修改评分。
  final bool disabled;

  /// 显式评分图标尺寸。
  final double? iconSize;

  /// 选中图标，null 时使用品牌默认图标。
  final Object? icon;

  /// 未选中图标，null 时使用品牌默认图标。
  final Object? voidIcon;

  /// 按分值分段使用的颜色。
  final List<Color>? colors;

  /// 未选中图标的颜色。
  final Color? inactiveColor;

  /// 显示与当前分值对应的辅助文字。
  final bool showText;

  /// 显示分值读数。
  final bool showScore;

  /// 按分值对应的辅助文字列表。
  final List<String>? texts;

  /// 分值模板，其中 {value} 表示当前分值。
  final String? scoreTemplate;

  /// 组件根样式。
  final ElStyle? style;

  /// 辅助文字或读数的样式。
  final ElStyle? textStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).rateBuilder!(context, this);
}
