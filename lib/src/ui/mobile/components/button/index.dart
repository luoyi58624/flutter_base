/// 参照：D:/project/html/my-ui/packages/vue/components/Button.vue；packages/core/my-ui.js:1243-1316；my-ui.css:165-441。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import '../../cores/glyph.dart';
import '../../cores/theme.dart';
import '../loading/index.dart';

/// 以移动端按钮外观实现通用声明，切换模型仍由 ElButton 持有。
Widget buttonBuilder(BuildContext context, ElButton component) => Button._fromComponent(component);

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
  }) : _component = null;

  Button._fromComponent(ElButton component)
    : _component = component,
      variant = component.link
          ? .link
          : component.text
          ? .text
          : component.ghost || component.plain
          ? .outline
          : component.circle || component.child is IconData
          ? .icon
          : .primary,
      icon = null,
      disabled = component.disabled,
      loading = component.loading,
      selected = component.selected,
      delayTouchDown = Duration.zero,
      delayTouchUp = const Duration(milliseconds: 100),
      type = .button,
      onClick = ((_) => component.onPressed?.call()),
      child = component.child,
      label = component.semanticLabel,
      focusNode = component.focusNode,
      style = component.style,
      event = component.event;

  final ElButton? _component;

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
    final component = _component;
    if (component != null) {
      buttonStyle = _commonStyle(context, component, buttonStyle);
    }
    buttonStyle = buttonStyle.merge(style);
    if (component?.circle == true) {
      // 正圆是形状约束，显式高度覆盖后仍保持宽高相同。
      buttonStyle = buttonStyle.copyWith(width: buttonStyle.height);
    }
    final content = component != null
        ? _commonContent(component)
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: icon != null && child != null ? (variant == ButtonVariant.link ? 6 : 7) : 0,
            children: [
              if (icon != null) ExcludeSemantics(child: Glyph(name: icon!)),
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
      toggled: component == null || component.isToggle ? selected : null,
      selected: component?.isToggle == false && selected == true ? true : null,
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: loading ? 0 : 1, alwaysIncludeSemantics: true, child: content),
          if (loading)
            const Positioned.fill(
              child: ExcludeSemantics(
                child: Center(child: Loading(size: LoadingSize.small)),
              ),
            ),
        ],
      ),
    );
    return component?.block == true ? result : inline(result);
  }
}

Widget _commonContent(ElButton component) {
  if (component.child is IconData) return buildContent(component.child);
  return Row(
    mainAxisSize: .min,
    spacing: 7,
    children: [
      if (component.leftIcon != null) buildContent(component.leftIcon),
      if (component.child != null) buildContent(component.child),
      if (component.rightIcon != null) buildContent(component.rightIcon),
    ],
  );
}

ElStyle _commonStyle(BuildContext context, ElButton component, ElStyle base) {
  final theme = context.elTheme;
  final accent =
      component.bgColor ??
      switch (component.type) {
        ElThemeType.success => theme.success,
        ElThemeType.warning => theme.warning,
        ElThemeType.error => theme.error,
        ElThemeType.info => theme.textSecondary,
        _ => theme.primary,
      };
  final flat = component.link || component.text;
  final outlined = !flat && (component.ghost || component.plain);
  final background = flat
      ? (component.bg && component.text && !component.link ? theme.fill : const Color(0x00000000))
      : component.ghost
      ? const Color(0x00000000)
      : component.plain
      ? Color.lerp(theme.cardColor, accent, .1)!
      : accent;
  final foreground = flat || outlined
      ? accent
      : accent.computeLuminance() > .45
      ? const Color(0xff000000)
      : const Color(0xffffffff);
  final selectedBackground = Color.lerp(
    background,
    flat || outlined ? accent : const Color(0xff000000),
    flat || outlined ? .18 : .14,
  )!;
  return base.copyWith(
    margin: component.link ? EdgeInsets.zero : base.margin,
    width: component.circle ? 44.0 : base.width,
    height: component.circle ? 44.0 : base.height,
    borderRadius: component.circle || component.round ? BorderRadius.circular(999) : base.borderRadius,
    backgroundColor: component.disabled
        ? theme.fill
        : component.selected
        ? selectedBackground
        : background,
    color: component.disabled ? theme.textSecondary : foreground,
    iconColor: component.disabled ? theme.textSecondary : foreground,
    border: ElBorder.all(
      borderWidth: flat ? 0 : 1,
      borderColor: component.disabled
          ? theme.borderColor
          : outlined
          ? accent
          : background,
    ),
    onTap: component.disabled || component.loading
        ? null
        : ElStyle(backgroundColor: selectedBackground, transform: ElTransform.scale(flat ? 1 : .95)),
  );
}
