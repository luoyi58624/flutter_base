import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../views/button/button_view.dart' show ElButtonView;
import '../../views/view/event/event.dart' show ElEvent;
import '../../views/view/event/press.dart' show ElEventDetails;
import '../../views/view/render/render_view.dart' show ElRenderView;
import '../../views/view/style/style.dart' show ElStyle;
import '../../views/view/view.dart' show ElView;

part 'ripple.dart';

part 'ripple_painter.dart';

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
