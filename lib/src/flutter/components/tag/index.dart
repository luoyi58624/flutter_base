import 'package:flutter/widgets.dart';

import '../../commons/models.dart' show ElThemeType;
import '../../utils/model_value/index.dart' show ElModelValue;
import '../../views/button/button_view.dart' show ElButtonView;
import '../../views/view/event/event.dart' show ElEvent, ElEventExt;
import '../../views/view/semantics/semantics.dart' show ElSemantics;
import '../../views/view/style/style.dart' show ElStyle;
import '../../views/view/view.dart' show ElView;
import '../index.dart' show ElComponentProvider;

/// 标签的浅色、实心与朴素外观。
enum ElTagEffect {
  /// 柔和浅底与细描边。
  light,

  /// 主题色填充与反白文字。
  dark,

  /// 空白底与主题描边。
  plain,
}

/// 公共标签声明，值绑定与交互共用，Builder 提供品牌外观。
class ElTag extends ElModelValue<bool> {
  /// 创建展示标签，关闭动作由 onClose 处理。
  ElTag({
    super.key,
    this.child,
    this.type = .primary,
    this.effect = .light,
    this.round = false,
    this.hit = false,
    this.closable = false,
    this.onClose,
    this.style,
    this.closeStyle,
    this.event,
    this.semanticLabel,
    this.closeSemanticLabel,
  }) : isToggle = false,
       disabled = false,
       focusNode = null,
       super(value: false);

  /// 创建独立布尔开关，不接入表单，未提供值时默认关闭。
  ElTag.toggle({
    super.key,
    bool? value,
    super.modelValue,
    super.onChanged,
    this.child,
    this.type = .primary,
    this.effect = .light,
    this.round = false,
    this.hit = false,
    this.closable = false,
    this.onClose,
    this.disabled = false,
    this.style,
    this.closeStyle,
    this.event,
    this.focusNode,
    this.semanticLabel,
    this.closeSemanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       isToggle = true,
       super(value: value ?? false);

  /// 标签文字、图标或 Widget 内容。
  final Object? child;

  /// 标签语义色。
  final ElThemeType type;

  /// 标签填充风格。
  final ElTagEffect effect;

  /// 使用完整胶囊圆角。
  final bool round;

  /// 使用主题本色强调描边。
  final bool hit;

  /// 显示独立可聚焦的关闭按钮。
  final bool closable;

  /// 关闭通知，是否移除标签由调用方决定。
  final VoidCallback? onClose;

  /// 禁止切换和关闭。
  final bool disabled;

  /// 在品牌默认样式之后合并的样式。
  final ElStyle? style;

  /// 关闭按钮样式。
  final ElStyle? closeStyle;

  /// 追加事件，可通过 preventDefault 阻止默认切换。
  final ElEvent? event;

  /// 开关的外部焦点节点，节点由调用方拥有。
  final FocusNode? focusNode;

  /// 辅助技术读取的标签名称。
  final String? semanticLabel;

  /// 辅助技术读取的关闭按钮名称。
  final String? closeSemanticLabel;

  /// 是否为独立布尔开关。
  final bool isToggle;

  /// 当前开关状态，普通标签始终为 false。
  bool get selected => isToggle && $obs.value;

  void _toggle() {
    if (!disabled) $obs.value = !$obs.value;
  }

  @override
  Widget obsBuilder(BuildContext context) => ElView(
    focusNode: isToggle ? focusNode : null,
    event: disabled
        ? ((isToggle ? ElButtonView.buildEvent(_toggle, disabled, event) : event) ?? ElEvent()).copyWith(disabled: true)
        : (isToggle ? ElButtonView.buildEvent(_toggle, disabled, event) : event),
    semantics: ElSemantics(
      container: true,
      mergeDescendants: !closable,
      label: semanticLabel,
      enabled: isToggle ? !disabled : null,
      toggled: isToggle ? selected : null,
      onTap: isToggle ? ElButtonView.buildSemanticsTap(_toggle, event, disabled) : null,
    ),
    style: const ElStyle(widthFactor: 1, userSelect: .none),
    child: ElComponentProvider.builderOf(context, this, (b) => b.tag)(context, this),
  );
}
