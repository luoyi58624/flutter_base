import 'package:flutter/widgets.dart';

import '../../internal.dart';
import '../../../../flutter/views/view/style/cascade/style_spec.dart' show hasFocusableVariantOf;

/// 桌面预设使用的 Element 标签实现。
class Tag extends StatelessWidget {
  const Tag(this.component, {super.key});

  final ElTag component;

  @override
  Widget build(BuildContext context) {
    final selected = component.selected;
    final ownsKeyboard =
        component.isToggle &&
        component.focusNode == null &&
        !hasFocusableVariantOf(component.style) &&
        component.event?.hasKeyboardCallback != true;
    final keyboard = ownsKeyboard
        ? ElButtonView.buildEvent(
            () => component.selected = !component.selected,
            component.disabled,
            (component.event ?? const ElEvent()).copyWith(
              onTap: (event) {
                component.event?.onTap?.call(event);
                event.stopPropagation();
              },
            ),
          )
        : null;
    return ElView(
      event: keyboard?.copyWith(onTap: null) ?? (component.disabled ? ElEvent(disabled: true) : null),
      style: ((BuildContext context) {
        final override = component.style;
        final style = override;
        final compact = context.elComponentCompact(style);
        final height = compact ? 24.0 : 26.0;
        final type = component.isToggle && !selected ? ElThemeType.info : component.type;
        final color = type.color(context);
        final solid = component.effect == .dark && (!component.isToggle || selected);
        final bg = solid
            ? color
            : component.effect == .plain
            ? context.elTheme.bgColor
            : color.elLight9(context);
        final border = component.hit || solid ? color : color.elLight8(context);
        final outline = ElStyle(
          outline: .new(outlineWidth: 2, outlineColor: context.elTheme.primary, outlineOffset: 2),
        );
        final pressed = ElStyle(
          backgroundColor: solid ? color.mix(const Color(0xff000000), 20) : color.elLight8(context),
        );
        return ElStyle(
              height: height,
              widthFactor: 1,
              padding: .only(left: 12, right: component.closable ? 4 : 12),
              backgroundColor: bg,
              border: .all(borderColor: border),
              borderRadius: .all(Radius.circular(component.round ? 9999 : height * 0.45)),
              color: solid ? context.elTheme.white : color,
              fontSize: compact ? 11 : 12,
              fontWeight: .w500,
              lineHeight: 1,
              alignment: .center,
              softWrap: false,
              cursor: component.isToggle ? SystemMouseCursors.click : null,
              onDisabled: const ElStyle(opacity: 0.5, cursor: SystemMouseCursors.forbidden),
              transition: const [ElTransition.all(Duration(milliseconds: 150), Curves.easeInOut)],
              iconColor: solid ? context.elTheme.white : color,
              onFocusVisible: ownsKeyboard ? outline : null,
              onTap: ownsKeyboard && !component.disabled ? pressed : null,
            )
            .merge(
              component.isToggle && !component.disabled
                  ? const ElStyle()
                        .merge(ElView.of(context).hasFocusVisible ? outline : null)
                        .merge(ElView.of(context).hasTap ? pressed : null)
                  : null,
            )
            .merge(style);
      })(context),
      child: component.closable
          ? Row(
              mainAxisSize: .min,
              children: [
                if (component.child != null) ElView(child: elContent(component.child)),
                _TagClose(component),
              ],
            )
          : elContent(component.child),
    );
  }
}

class _TagClose extends StatelessWidget {
  const _TagClose(this.component);

  final ElTag component;

  // 关闭是独立动作，指针和键盘均不得冒泡成标签切换。
  static void _stopPropagation(ElEventDetails event) => event.stopPropagation();

  @override
  Widget build(BuildContext context) => ElButtonView(
    onPressed: component.onClose,
    disabled: component.disabled,
    semanticLabel: component.closeSemanticLabel,
    event: ElEvent(onTapDown: _stopPropagation, onTap: _stopPropagation),
    style: ((BuildContext context) {
      final type = component.isToggle && !component.selected ? ElThemeType.info : component.type;
      final color = type.color(context);
      final solid = component.effect == .dark && (!component.isToggle || component.selected);
      final foreground = solid ? context.elTheme.white : color;
      final override = component.closeStyle;
      return ElStyle(
        margin: .only(left: 4),
        width: 14,
        height: 14,
        borderRadius: BorderRadius.all(Radius.circular(9999)),
        alignment: .center,
        iconSize: 12,
        iconColor: foreground,
        cursor: SystemMouseCursors.click,
        onHover: ElStyle(iconColor: context.elTheme.white, backgroundColor: solid ? color.elLight3(context) : color),
        onTap: ElStyle(iconColor: context.elTheme.white, backgroundColor: color.mix(const Color(0xff000000), 20)),
        onFocusVisible: ElStyle(
          outline: .new(outlineWidth: 2, outlineColor: context.elTheme.primary, outlineOffset: 2),
        ),
        transition: const [ElTransition.all(Duration(milliseconds: 150))],
      ).merge(override);
    })(context),
    child: const ElIcon(ElDesktopIcons.close),
  );
}
