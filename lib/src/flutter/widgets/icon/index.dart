import 'package:flutter/widgets.dart';

import '../../views/view/semantics/semantics.dart' show ElSemantics;
import '../../views/view/style/style.dart' show ElStyle, ElTextOptions;
import '../../views/view/view.dart' show ElView;

/// 使用 ElView 字形渲染的字体图标。
///
/// 图标占用居中的正方形，尺寸和颜色通过 iconSize / iconColor 独立继承。
/// 默认不随系统文字缩放；样式仍支持主题、状态变体、阴影与过渡。
///
/// 旋转动画可由 `ElLoading` 提供。
class ElIcon extends StatelessWidget {
  /// 创建图标。
  const ElIcon(
    this.child, {
    super.key,
    this.size,
    this.color,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.fontWeight,
    this.semanticLabel,
    this.textDirection,
    this.applyTextScaling = false,
    this.style,
  }) : assert(size == null || (size >= 0 && size < double.infinity)),
       assert(fill == null || (fill >= 0 && fill <= 1)),
       assert(weight == null || (weight > 0 && weight < double.infinity)),
       assert(grade == null || (grade > double.negativeInfinity && grade < double.infinity)),
       assert(opticalSize == null || (opticalSize > 0 && opticalSize < double.infinity));

  /// 图标字体信息；null 保留尺寸但不绘制。
  final IconData? child;

  /// 图标正方形的边长，缺省继承 iconSize，父级约束仍可限制最终尺寸。
  final double? size;

  /// 图标颜色，缺省继承独立的图标色通道。
  final Color? color;

  /// 可变图标字体的填充程度，范围为 0 到 1。
  final double? fill;

  /// 可变图标字体的 wght 轴，必须大于 0。
  final double? weight;

  /// 可变图标字体的 GRAD 轴，用于细调笔画粗细。
  final double? grade;

  /// 可变图标字体的 opsz 轴，必须大于 0。
  final double? opticalSize;

  /// 图标字体字重，默认普通字重，不继承正文的粗体。
  final FontWeight? fontWeight;

  /// 读屏描述；装饰图标不传，按钮内通常由按钮提供语义。
  final String? semanticLabel;

  /// 覆盖阅读方向；方向性图标在 RTL 下自动镜像。
  final TextDirection? textDirection;

  /// 是否随系统文字缩放，同时调整字形和占位，默认关闭。
  final bool applyTextScaling;

  /// 附加样式（hover 变体等，merge 在图标通道之上）
  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElView(
      semantics: semanticLabel == null ? null : ElSemantics(label: semanticLabel, textDirection: textDirection),
      style: ElStyle(
        iconSize: size,
        iconColor: color,
        alignment: .center,
        direction: textDirection,
        fontWeight: fontWeight ?? .normal,
        textOptions: ElTextOptions(
          textScaler: applyTextScaling
              ? (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling)
              : TextScaler.noScaling,
        ),
        fontVariationSettings: [
          if (fill != null) FontVariation('FILL', fill!),
          if (weight != null) FontVariation('wght', weight!),
          if (grade != null) FontVariation('GRAD', grade!),
          if (opticalSize != null) FontVariation('opsz', opticalSize!),
        ],
      ).merge(style),
      child: child ?? const IconData(0x20),
    );
  }
}
