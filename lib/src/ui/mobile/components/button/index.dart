/// 参照：D:/project/html/my-ui/packages/vue/components/Button.vue；packages/core/my-ui.js:1243-1316；my-ui.css:165-441。
library;

import 'package:flutter/widgets.dart';

import '../../../../flutter/commons/models.dart' show ElThemeType;
import '../../../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../../../flutter/components/button/index.dart' show ElButton, ElButtonVariant;
import '../../../../flutter/utils/obs/index.dart' show Obs;
import '../../../../flutter/views/view/event/event.dart' show ElEvent, ElEventHandler;
import '../../../../flutter/views/view/style/style.dart'
    show ElBorder, ElStyle, ElStyleExt, ElTransform, ElTransition, ElTransitionField;
import '../../commons/icons.dart' show Glyph;
import '../../internal/common.dart';
import '../loading/index.dart';

/// 以移动端按钮外观实现通用按钮声明，切换按钮的选中态读写公共模型。
Widget buttonBuilder(BuildContext context, ElButton component, Obs<bool> model) =>
    Button._fromComponent(component, model);

/// Web按钮的七种视觉层级。
enum ButtonVariant {
  /// 主色填充。
  primary,

  /// 卡片底色描边。
  outline,

  /// 文本按钮。
  text,

  /// 有底色图标按钮。
  icon,

  /// 透明图标按钮。
  bare,

  /// 带24px顶部间距的链接。
  link,

  /// 46px圆角箭头。
  round,
}

/// Web按钮类型到Flutter表单默认动作的映射。
enum ButtonType {
  /// 只触发click。
  button,

  /// click未阻止默认行为时校验并保存最近Form。
  submit,

  /// click未阻止默认行为时重置最近Form。
  reset,
}

/// 与Web相同的尺寸、变体、加载覆盖层和激活事件。
class Button extends StatelessWidget {
  /// onClick为空仍可聚焦，loading保留焦点与内容尺寸。
  const Button({
    super.key,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.disabled = false,
    this.loading = false,
    this.selected,
    this.delayTouchDown = Duration.zero,
    this.delayTouchUp = const Duration(milliseconds: 100),
    this.type = ButtonType.button,
    this.onClick,
    this.child,
    this.label,
    this.focusNode,
    this.style,
    this.event,
  }) : _common = null;

  Button._fromComponent(ElButton component, Obs<bool> model)
    : _common = _CommonButton(component.type, component.variant, component.icon),
      variant = _variantOf(component.variant, component.child),
      icon = null,
      disabled = component.disabled,
      loading = component.loading,
      selected = component.isToggle ? model.value : null,
      delayTouchDown = Duration.zero,
      delayTouchUp = const Duration(milliseconds: 100),
      type = .button,
      onClick = component.isToggle ? ((_) => model.value = !model.value) : ((_) => component.onPressed?.call()),
      child = component.child,
      label = component.semanticLabel,
      focusNode = component.focusNode,
      style = component.style,
      event = component.event;

  static ButtonVariant _variantOf(ElButtonVariant variant, Object? child) => switch (variant) {
    .link => .link,
    .text => .text,
    .outline => .outline,
    .solid => child is IconData ? .icon : .primary,
  };

  /// 来自通用声明时的语义色与前置图标；直接使用内部按钮时为 null。
  final _CommonButton? _common;

  /// 视觉层级。
  final ButtonVariant variant;

  /// Web同名内置图标，未知名称回退sun。
  final String? icon;

  /// 禁用按钮。
  final bool disabled;

  /// 显示小型spinner并阻止激活。
  final bool loading;

  /// 可选切换状态，null不声明pressed语义。
  final bool? selected;

  /// 触摸按下等待时间。
  final Duration delayTouchDown;

  /// 从按下起算的最短触摸反馈时间。
  final Duration delayTouchUp;

  /// 原生按钮类型。
  final ButtonType type;

  /// 可用时派发，preventDefault可阻止表单默认动作。
  final ElEventHandler? onClick;

  /// 默认内容插槽。
  final Object? child;

  /// 对应aria-label，图标按钮应提供。
  final String? label;

  /// 调用方拥有的焦点节点。
  final FocusNode? focusNode;

  /// 合并到默认样式的覆盖。
  final ElStyle? style;

  /// 原生ElView事件扩展。
  final ElEvent? event;

  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    final fixed = [ButtonVariant.icon, ButtonVariant.bare, ButtonVariant.round].contains(variant);
    final flat = [ButtonVariant.text, ButtonVariant.bare, ButtonVariant.link].contains(variant);
    final side = variant == ButtonVariant.round ? 46.0 : 44.0;
    final foreground = switch (variant) {
      ButtonVariant.primary => t.primaryText,
      ButtonVariant.icon => selected == true ? t.primary : t.textSecondary,
      ButtonVariant.bare => t.textSecondary,
      _ => t.primary,
    };
    final background = switch (variant) {
      ButtonVariant.primary => t.primary,
      ButtonVariant.outline => t.cardColor,
      ButtonVariant.icon || ButtonVariant.round => t.fill,
      _ => const Color(0x00000000),
    };
    final border = [ButtonVariant.outline, ButtonVariant.icon, ButtonVariant.round].contains(variant)
        ? t.borderColor
        : const Color(0x00000000);
    final noFeedback = disabled || loading;
    final glyphSize = switch (variant) {
      ButtonVariant.icon || ButtonVariant.bare => 19.0,
      ButtonVariant.round => 17.0,
      ButtonVariant.link => 14.0,
      _ => 16.0,
    };
    var buttonStyle = ElStyle(
      minHeight: 44,
      widthFactor: 1,
      heightFactor: 1,
      width: fixed ? side : null,
      height: fixed ? side : null,
      // ElView边框只绘制不占布局，补入CSS border-box的横向1px。
      padding: EdgeInsets.symmetric(
        horizontal: fixed || variant == ButtonVariant.link
            ? 0
            : (variant == ButtonVariant.text
                      ? 8
                      : viewport(context) <= 400
                      ? 13
                      : 17) +
                  1,
      ),
      margin: variant == ButtonVariant.link ? const EdgeInsets.only(top: 24) : null,
      alignment: Alignment.center,
      softWrap: false,
      backgroundColor: disabled && variant != ButtonVariant.bare ? t.fill : background,
      color: disabled && !(variant == ButtonVariant.icon && selected == true) ? t.textSecondary : foreground,
      iconColor: disabled && !(variant == ButtonVariant.icon && selected == true) ? t.textSecondary : foreground,
      iconSize: glyphSize,
      fontSize: variant == ButtonVariant.link ? 14 : 15,
      fontWeight: textWeight(t.fontWeightAction),
      border: ElBorder.all(borderWidth: variant == ButtonVariant.link ? 0 : 1, borderColor: border),
      borderRadius: BorderRadius.circular(
        variant == ButtonVariant.round
            ? 14
            : fixed
            ? 12
            : 13,
      ),
      opacity: disabled && ![ButtonVariant.text, ButtonVariant.bare].contains(variant) ? .68 : 1,
      transition: const [
        ElTransition.all(Duration(milliseconds: 150), Curves.ease),
        ElTransition.field(ElTransitionField.transform, Duration(milliseconds: 160), Cubic(.2, .7, .2, 1)),
        ElTransition.field(ElTransitionField.opacity, Duration(milliseconds: 200), Curves.ease),
      ],
      onTap: noFeedback
          ? null
          : ElStyle(
              backgroundColor: variant == ButtonVariant.primary
                  ? Color.lerp(t.primary, const Color(0xff000000), .14)
                  : t.press,
              transform: ElTransform.scale(flat ? 1 : .95),
              transition: flat ? const [] : null,
            ),
    );
    final common = _common;
    if (common != null) {
      buttonStyle = _commonStyle(
        context,
        common,
        buttonStyle,
        disabled: disabled,
        loading: loading,
        selected: selected,
      );
    }
    buttonStyle = buttonStyle.merge(style);
    // 加载中时指示器顶替前导图标的位置：有图标就原位换，没有图标才排在文字前面。
    // 这样设计图要求的「指示器 + 文字」成立，同时图标按钮在加载中不会撑宽。
    final indicator = ExcludeSemantics(child: Loading(size: LoadingSize.small));
    final content = common != null
        ? _commonContent(common, child, loading: loading)
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: (loading || icon != null) && child != null ? (variant == ButtonVariant.link ? 6 : 7) : 0,
            children: [
              if (loading) indicator else if (icon != null) ExcludeSemantics(child: Glyph(name: icon!)),
              if (child != null) buildContent(child),
            ],
          );
    final result = ActionView(
      style: buttonStyle,
      quickTouchFeedback: true,
      label: label,
      focusNode: focusNode,
      event: event,
      disabled: disabled,
      blocked: loading,
      toggled: selected,
      delayTouchDown: delayTouchDown,
      delayTouchUp: delayTouchUp,
      onActivate: (e) {
        onClick?.call(e);
        if (e.defaultPrevented) return;
        final form = Form.maybeOf(context);
        switch (type) {
          case ButtonType.button:
            break;
          case ButtonType.submit:
            if (form?.validate() == true) form!.save();
          case ButtonType.reset:
            form?.reset();
        }
      },
      // 正圆这类锁死宽高的按钮放不下「指示器 + 图标」，加载中只留指示器，尺寸与焦点都保持不变。
      child: loading && fixed ? indicator : content,
    );
    // 显式宽度（如 '100%'）需要父级约束，其余按内容宽度排布。
    return buttonStyle.width != null && !fixed ? result : inline(result);
  }
}

/// 通用声明中移动端按钮没有直接对应的部分。
class _CommonButton {
  const _CommonButton(this.type, this.variant, this.icon);

  final ElThemeType? type;
  final ElButtonVariant variant;
  final Object? icon;
}

/// 把声明层的内容拼成一行；加载中用指示器顶替前导图标，文字照常可见。
Widget _commonContent(_CommonButton common, Object? child, {bool loading = false}) {
  final indicator = ExcludeSemantics(child: Loading(size: LoadingSize.small));
  if (child is IconData) return loading ? indicator : buildContent(child);
  return Row(
    mainAxisSize: .min,
    spacing: 7,
    children: [
      if (loading) indicator else if (common.icon != null) buildContent(common.icon),
      if (child != null) buildContent(child),
    ],
  );
}

ElStyle _commonStyle(
  BuildContext context,
  _CommonButton common,
  ElStyle base, {
  required bool disabled,
  required bool loading,
  required bool? selected,
}) {
  final theme = context.elTheme;
  final accent = switch (common.type) {
    ElThemeType.success => theme.success,
    ElThemeType.warning => theme.warning,
    ElThemeType.error => theme.error,
    ElThemeType.info => theme.info,
    _ => theme.primary,
  };
  final flat = common.variant == .link || common.variant == .text;
  final outlined = common.variant == .outline;
  // 设计图的信息按钮是「浅蓝底 + 蓝字」，用主色低透明度铺底，和实心蓝的主要按钮拉开层级。
  final tinted = !flat && !outlined && common.type == ElThemeType.info;
  final background = flat
      ? const Color(0x00000000)
      : outlined
      ? Color.lerp(theme.cardColor, accent, .1)!
      : tinted
      ? Color.lerp(theme.cardColor, accent, .12)!
      : accent;
  // 实心底上统一白字（警告橙的亮度已跨过阈值，靠 primaryText 保证浅底时才翻黑）。
  final foreground = flat || outlined || tinted
      ? accent
      : accent.computeLuminance() > .45
      ? theme.primaryText
      : const Color(0xffffffff);
  final selectedBackground = Color.lerp(
    background,
    flat || outlined || tinted ? accent : const Color(0xff000000),
    flat || outlined || tinted ? .18 : .14,
  )!;
  return base.copyWith(
    margin: common.variant == .link ? EdgeInsets.zero : base.margin,
    backgroundColor: disabled
        ? theme.fill
        : selected == true
        ? selectedBackground
        : background,
    color: disabled ? theme.textSecondary : foreground,
    iconColor: disabled ? theme.textSecondary : foreground,
    border: ElBorder.all(
      borderWidth: flat || tinted ? 0 : 1,
      borderColor: disabled
          ? theme.borderColor
          : outlined
          ? accent
          : background,
    ),
    onTap: disabled || loading
        ? null
        : ElStyle(backgroundColor: selectedBackground, transform: ElTransform.scale(flat ? 1 : .95)),
  );
}
