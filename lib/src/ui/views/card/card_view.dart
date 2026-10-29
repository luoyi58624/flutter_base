import 'package:flutter_base/src/ui/cores/view/semantics/semantics.dart';
import 'package:flutter_base/src/ui/cores/view/view.dart';

/// 无默认样式的区域语义基元，为内容盒建立独立容器并保留后代语义节点。
///
/// 外观、布局和事件沿用 [ElView]；默认不创建焦点或激活动作。后代的
/// 文字与按钮节点保持独立可达，滚动裁剪及浮层层序由所属宿主统一处理。
/// 直接传入文字沿用 ElView 自持文本及显式 label 覆盖规则。
/// 区域边界包含边框与内边距，外边距只参与排布。
class ElCardView extends ElView {
  /// 构建区域；[semanticLabel] 可选，仅命名容器，不替换后代内容。
  ElCardView({
    super.key,
    String? semanticLabel,
    super.style,
    super.event,
    super.focusNode,
    super.themeMode,
    super.breakpoint,
    super.inheritSize,
    super.locale,
    super.child,
  }) : super(semantics: ElSemantics(container: true, explicitChildNodes: true, label: semanticLabel));
}
