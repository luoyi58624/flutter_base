import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 按钮的视觉层级，两端品牌各自映射到自己的外观。
enum ElButtonVariant {
  /// 实心填充。
  solid,

  /// 描边或浅底。
  outline,

  /// 无底色文字按钮，保留按钮盒尺寸。
  text,

  /// 链接形态，紧凑内容尺寸。
  link,
}

/// 按钮声明；child 为 IconData 时由品牌渲染为方形图标按钮，toggle 构造的选中态由模型持有。
class ElButton extends ElModelValue<bool> {
  /// 创建普通按钮；onPressed 为空不等于禁用。
  ElButton({
    super.key,
    this.onPressed,
    this.child,
    this.icon,
    this.type,
    this.variant = .solid,
    this.disabled = false,
    this.loading = false,
    this.style,
    this.event,
    this.focusNode,
    this.semanticLabel,
  }) : isToggle = false,
       super(value: false);

  /// 创建布尔切换按钮，不接入表单，未提供值时从 false 开始。
  ElButton.toggle({
    super.key,
    bool? value,
    super.modelValue,
    super.onChanged,
    this.child,
    this.icon,
    this.type,
    this.variant = .solid,
    this.disabled = false,
    this.style,
    this.event,
    this.focusNode,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       onPressed = null,
       loading = false,
       isToggle = true,
       super(value: value ?? false);

  /// 普通按钮的激活动作。
  final VoidCallback? onPressed;

  /// 按钮内容。
  final Object? child;

  /// 前置图标，加载中由加载指示替代。
  final Object? icon;

  /// 语义色，省略时使用品牌的中性外观。
  final ElThemeType? type;

  /// 视觉层级。
  final ElButtonVariant variant;

  /// 禁止激活与焦点请求。
  final bool disabled;

  /// 显示加载指示并阻止激活，保留焦点与尺寸。
  final bool loading;

  /// 在品牌默认样式之后合并；显式 width 时按宽度布局，例如 '100%' 通栏。
  final ElStyle? style;

  /// 追加事件，与激活动作组合执行，preventDefault 可阻止默认激活或切换。
  final ElEvent? event;

  /// 外部焦点节点，由调用方持有并释放。
  final FocusNode? focusNode;

  /// 辅助名称，图标按钮应提供。
  final String? semanticLabel;

  /// 是否为切换按钮；为 true 时激活即翻转模型，品牌据模型绘制选中态。
  final bool isToggle;

  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.button)(context, this, $obs);
}
