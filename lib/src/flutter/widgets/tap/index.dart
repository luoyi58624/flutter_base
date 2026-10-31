import 'package:flutter_base/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

part 'ripple.dart';

part 'ripple_painter.dart';

/// 按压时触发透明效果的通用按钮
class ElFadeTap extends ElButtonView {
  ElFadeTap({
    super.key,
    ElStyle? style,
    required super.onPressed,
    required super.child,
    super.disabled = false,
    super.semanticLabel,
  }) : super(
         style: const ElStyle(
           transition: [.field(ElTransitionField.opacity, Duration(milliseconds: 180), Curves.easeInOutQuad)],
           onTap: ElStyle(opacity: 0.2, transition: [.field(ElTransitionField.opacity, Duration.zero)]),
         ).merge(style),
       );
}

/// 按压时触发缩放效果的通用按钮
class ElScaleTap extends ElButtonView {
  ElScaleTap({
    super.key,
    ElStyle? style,
    required super.onPressed,
    required super.child,
    super.disabled = false,
    super.semanticLabel,
  }) : super(
         style: const ElStyle(
           transition: [.field(ElTransitionField.transform, Duration(milliseconds: 100), Curves.easeOut)],
           onTap: ElStyle(transform: ElTransform.scale(0.95)),
         ).merge(style),
       );
}

/// 悬停时浅色高亮、按下时从落点扩散 Material 2 波纹的通用按钮。
class ElRippleTap extends StatefulWidget {
  /// 创建波纹按钮，反馈颜色跟随当前文本色，裁剪跟随 [style] 及直接子 [ElView] 的圆角和路径。
  const ElRippleTap({
    super.key,
    required this.onPressed,
    required this.child,
    this.disabled = false,
    this.semanticLabel,
    this.style,
    this.focusNode,
  });

  /// 点击、键盘或辅助技术激活时执行。
  final VoidCallback? onPressed;

  /// 按钮内容，支持 Widget、文本及 ElView 的混排内容。
  final Object? child;

  /// 是否禁用交互和反馈。
  final bool disabled;

  /// 辅助技术使用的按钮名称。
  final String? semanticLabel;

  /// 按钮的盒模型、文本及状态样式。
  final ElStyle? style;

  /// 可选焦点节点，键盘激活行为由 ElButtonView 统一处理。
  final FocusNode? focusNode;

  @override
  State<ElRippleTap> createState() => _RippleTapState();
}
