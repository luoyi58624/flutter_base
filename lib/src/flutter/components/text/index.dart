import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 公共文本声明，参数与 Flutter [Text] 一一对应平铺，外观由全局组件
/// 提供器（[ElComponentProvider]）登记的实现渲染。
///
/// 不使用 [ElStyle] 构造：`style` 直接透传 Flutter [TextStyle]，方便在
/// 品牌实现与 Flutter 文本能力之间无缝替换。
class ElText extends StatelessWidget {
  /// 创建文本声明；参数语义与 Flutter [Text] 完全一致。
  const ElText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  /// 要显示的文本。
  final String data;

  /// 文本样式，优先级高于品牌默认样式。
  final TextStyle? style;

  /// 文本的字体结构样式。
  final StrutStyle? strutStyle;

  /// 文本的水平对齐方式。
  final TextAlign? textAlign;

  /// 文本方向。
  final TextDirection? textDirection;

  /// 用于选择区域的语言环境。
  final Locale? locale;

  /// 文本是否在软换行处换行。
  final bool? softWrap;

  /// 文本溢出时的截断方式。
  final TextOverflow? overflow;

  /// 文本缩放器。
  final TextScaler? textScaler;

  /// 文本最大行数，配合 [overflow] 使用。
  final int? maxLines;

  /// 文本宽度计算基准。
  final TextWidthBasis? textWidthBasis;

  /// 文本高度行为。
  final TextHeightBehavior? textHeightBehavior;

  /// 选中文本的颜色。
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => ElComponentProvider.of(context).textBuilder!(context, this);
}