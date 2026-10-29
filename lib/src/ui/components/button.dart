import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 公共按钮声明，外观与行为由全局组件主题提供。
class ElButton extends ElModelValue<bool> {
  /// 创建按钮；onPressed 为空不等于禁用。
  ElButton({
    super.key,
    this._onPressed,
    this.child,
    this.type,
    this.bgColor,
    this.plain = false,
    this.text = false,
    this.bg = false,
    this.link = false,
    this.ghost = false,
    this.round = false,
    this.circle = false,
    this.loading = false,
    this.block = false,
    this.leftIcon,
    this.rightIcon,
    this.semanticLabel,
    this.style,
    this.event,
    this.focusNode,
    this.disabled = false,
    bool selected = false,
  }) : _selected = selected,
       isToggle = false,
       super(value: selected);

  /// 创建独立布尔开关，外观与普通按钮一致并绘制选中态。
  ElButton.toggle({
    super.key,
    bool? value,
    super.modelValue,
    super.onChanged,
    this.child,
    this.type,
    this.bgColor,
    this.plain = false,
    this.text = false,
    this.bg = false,
    this.link = false,
    this.ghost = false,
    this.round = false,
    this.circle = false,
    this.loading = false,
    this.block = false,
    this.leftIcon,
    this.rightIcon,
    this.semanticLabel,
    this.style,
    this.event,
    this.focusNode,
    this.disabled = false,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       _onPressed = null,
       _selected = false,
       isToggle = true,
       super(value: value ?? false);

  /// 默认激活回调，可被 event.preventDefault 阻止。
  VoidCallback? get onPressed => isToggle ? _toggle : _onPressed;
  final VoidCallback? _onPressed;

  void _toggle() {
    if (!disabled && !loading) $obs.value = !$obs.value;
  }

  /// 文本、Widget、IconData 或底层视图支持的混排内容。
  final Object? child;

  /// 中性语义色，由当前实现映射到自己的 token。
  final ElThemeType? type;

  /// Color 或颜色 token，显式覆盖 type 的颜色来源。
  final Color? bgColor;

  /// 朴素外观；优先级为 link > text > ghost > plain。
  final bool plain;

  /// 文本外观，保留按钮盒尺寸。
  final bool text;

  /// 为文本按钮添加默认背景，由品牌背景色按比重 5 加深。
  final bool bg;

  /// 链接外观，采用紧凑的内容尺寸。
  final bool link;

  /// 透明背景与描边的幽灵外观。
  final bool ghost;

  /// 胶囊圆角，与 circle 同传时 circle 优先。
  final bool round;

  /// 正圆按钮，宽高相同。
  final bool circle;

  /// 加载中阻止默认激活并显示加载内容，不自动使用禁用配色。
  final bool loading;

  /// 占满父级可用宽度。
  final bool block;

  /// 左侧图标或内容，加载中由当前实现替换为加载指示。
  final Object? leftIcon;

  /// 右侧图标或内容；child 为 IconData 时忽略左右槽。
  final Object? rightIcon;

  /// 辅助技术读取的按钮名称。
  final String? semanticLabel;

  /// 在主题默认样式之后合并的用户样式。
  final ElStyle? style;

  /// 用户事件，沿用 ElButtonView 的默认动作与键盘让位规则。
  final ElEvent? event;

  /// 外部焦点节点，节点由调用方拥有。
  final FocusNode? focusNode;

  /// 禁止按钮激活与焦点请求。
  final bool disabled;

  /// 受控选中态，与键盘物理按压状态独立。
  bool get selected => isToggle ? $obs.value : _selected;
  final bool _selected;

  /// 是否为独立布尔开关，供外观实现声明开关语义。
  final bool isToggle;

  @override
  Widget obsBuilder(BuildContext context) => ElComponentProvider.of(context).buttonBuilder!(context, this);
}
