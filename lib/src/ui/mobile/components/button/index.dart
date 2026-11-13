/// 参照：D:/project/html/my-ui/packages/vue/components/Button.vue；packages/core/my-ui.js:1243-1316；my-ui.css:165-441。
library;

import 'package:flutter/widgets.dart';

import '../../../../flutter/components/tokens.dart' show ElThemeContextExt, ElThemeExt, ElThemeTypeColor;
import '../../../../flutter/components/button/index.dart' show ElButton, ElButtonVariant;
import '../../../../flutter/utils/obs/index.dart' show Obs;
import '../../../../flutter/views/view/event/event.dart' show ElEvent, ElEventHandler;
import '../../../../flutter/views/view/style/style.dart' show ElBorder, ElStyle, ElStyleExt, ElTransform;
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
  /// onClick 为空仍保留按压反馈，loading 保留用户焦点与内容尺寸。
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

  Button._fromComponent(ElButton component, Obs<bool> model)
    : _component = component,
      variant = _variantOf(component.variant, component.child),
      icon = null,
      disabled = component.disabled,
      loading = component.loading,
      selected = component.isToggle ? model.value : null,
      delayTouchDown = component.event?.delayTouchDown ?? Duration.zero,
      delayTouchUp = component.event?.delayTouchUp ?? const Duration(milliseconds: 100),
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
    final theme = context.elTheme;
    final component = _component;
    final fixed = variant == .icon || variant == .bare || variant == .round;
    final enabled = !disabled && !loading && event?.disabled != true;
    final pressedBackground = enabled && component == null
        ? (variant == .primary ? Color.lerp(theme.primary, theme.black, .14) : theme.press)
        : null;
    final defaultStyle = component == null
        ? _webStyle(context, theme, fixed)
        : _componentStyle(theme, component, fixed, accent: component.type?.color(context) ?? theme.primary);
    final buttonStyle = defaultStyle
        .copyWith(
          transition: enabled ? pressTransitions(theme) : null,
          onTap: enabled
              ? ElStyle(backgroundColor: pressedBackground, transform: ElTransform.scale(theme.buttonPressScale))
              : null,
        )
        .merge(style);
    // 加载指示原位替换前导图标，图标按钮只显示指示器。
    const indicator = ExcludeSemantics(child: Loading(size: LoadingSize.small));
    final content = component != null
        ? _componentContent(component.icon, child, loading: loading)
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: (loading || icon != null) && child != null ? (variant == .link ? 6 : 7) : 0,
            children: [
              if (loading) indicator else if (icon != null) ExcludeSemantics(child: Glyph(name: icon!)),
              if (child != null) buildContent(child),
            ],
          );
    final result = ActionView(
      style: buttonStyle,
      trackTouchPress: true,
      hapticFeedback: TouchActionScope.enabled(context),
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
        if (e.defaultPrevented || type == .button) return;
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
      child: loading && fixed ? indicator : content,
    );
    // 显式宽度（如 '100%'）需要父级约束，其余按内容宽度排布。
    return style?.width != null ? result : inline(result);
  }

  ElStyle _webStyle(BuildContext context, ElThemeExt t, bool fixed) {
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
    final glyphSize = switch (variant) {
      ButtonVariant.icon || ButtonVariant.bare => 19.0,
      ButtonVariant.round => 17.0,
      ButtonVariant.link => 14.0,
      _ => 16.0,
    };
    return ElStyle(
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
    );
  }

  ElStyle _componentStyle(ElThemeExt theme, ElButton component, bool fixed, {required Color accent}) {
    final link = component.variant == .link;
    final flat = link || component.variant == .text;
    final outlined = component.variant == .outline;
    final tinted = !flat && !outlined && component.type == .info;
    const transparent = Color(0x00000000);
    final background = flat
        ? transparent
        : outlined
        ? theme.cardColor
        : tinted
        ? Color.lerp(theme.cardColor, accent, .12)!
        : accent;
    final foreground = flat || outlined || tinted
        ? accent
        : accent.computeLuminance() > .45
        ? theme.primaryText
        : theme.white;
    final color = disabled ? theme.textSecondary : foreground;
    final selectedBackground = flat
        ? accent.withValues(alpha: .12)
        : Color.lerp(background, outlined || tinted ? accent : theme.black, outlined || tinted ? .18 : .14);
    return ElStyle(
      minWidth: !flat && !fixed && style?.width == null ? 64 : null,
      minHeight: !link && style?.height == null ? 40 : null,
      widthFactor: 1,
      heightFactor: 1,
      width: fixed ? 40 : null,
      height: fixed ? 40 : null,
      padding: fixed ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: link ? 0 : (flat ? 8 : 16), vertical: 6),
      alignment: .center,
      softWrap: false,
      userSelect: .none,
      backgroundColor: disabled
          ? (flat ? transparent : theme.fill)
          : (selected == true ? selectedBackground : background),
      color: color,
      iconColor: color,
      iconSize: fixed ? 19 : (link ? 14 : 16),
      fontSize: link ? 14 : 15,
      fontWeight: textWeight(theme.fontWeightAction),
      border: outlined
          ? ElBorder.all(
              borderWidth: theme.borderWidth,
              borderColor: disabled ? theme.borderColor : Color.lerp(theme.borderColor, accent, .36),
            )
          : null,
      borderRadius: .circular(theme.radiusMd),
      opacity: disabled && !flat ? .68 : 1,
    );
  }
}

Widget _componentContent(Object? icon, Object? child, {required bool loading}) {
  const indicator = ExcludeSemantics(child: Loading(size: LoadingSize.small));
  if (child is IconData) return loading ? indicator : buildContent(child);
  // 不需要前导图标时保留内容约束，显式整行按钮可以组合 Expanded 等布局。
  if (!loading && icon == null) return buildContent(child);
  return Row(
    mainAxisSize: .min,
    spacing: 7,
    children: [
      if (loading) indicator else if (icon != null) buildContent(icon),
      if (child != null) buildContent(child),
    ],
  );
}
