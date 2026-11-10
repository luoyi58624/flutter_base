import 'package:flutter_base/flutter_base.dart';

/// 示例中的独立局部区域：无默认外观，只建立保留后代节点的容器语义。
///
/// 外观完全由 style 决定，与具体品牌无关，因此可放在任意布局（含不限高的 Expanded）中。
class ExamplePanel extends ElView {
  /// [semanticLabel] 可选，仅命名容器，不替换后代内容。
  ExamplePanel({
    super.key,
    String? semanticLabel,
    super.style,
    super.event,
    super.focusNode,
    super.themeMode,
    super.child,
  }) : super(semantics: ElSemantics(container: true, explicitChildNodes: true, label: semanticLabel));
}
