import 'package:flutter_base/src/ui/desktop/internal.dart';
import 'package:flutter/widgets.dart';

/// Element 标签主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class Tag extends StatelessWidget {
  const Tag(this.component, {super.key});

  final ElTag component;

  @override
  Widget build(BuildContext context) {
    final selected = component.selected;
    return ElView(
      event: component.disabled ? ElEvent(disabled: true) : null,
      style: ((BuildContext context) {
        final override = component.style;
        final style = override;
        final compact = context.elComponentCompact(style);
        final height = compact ? 24.0 : 26.0;
        final type = component.isToggle && !selected
            ? ElThemeType.info
            : component.type;
        final color = type.color(context);
        final solid =
            component.effect == .dark && (!component.isToggle || selected);
        final bg = solid
            ? color
            : component.effect == .plain
            ? context.elTheme.bgColor
            : color.elLight9(context);
        final border = component.hit || solid ? color : color.elLight8(context);
        return ElStyle(
              height: height,
              widthFactor: 1,
              padding: .only(
                left: 12,
                right: component.closable ? 4 : 12,
              ),
              backgroundColor: bg,
              border: .all(borderColor: border),
              borderRadius: .all(
                Radius.circular(component.round ? 9999 : height * 0.45),
              ),
              color: solid ? context.elTheme.white : color,
              fontSize: compact ? 11 : 12,
              fontWeight: .w500,
              lineHeight: 1,
              alignment: .center,
              softWrap: false,
              cursor: component.isToggle ? SystemMouseCursors.click : null,
              onDisabled: const ElStyle(
                opacity: 0.5,
                cursor: SystemMouseCursors.forbidden,
              ),
              transition: const [
                ElTransition.all(Duration(milliseconds: 150), Curves.easeInOut),
              ],
              iconColor: solid ? context.elTheme.white : color,
            )
            .merge(
              component.isToggle && !component.disabled
                  ? const ElStyle()
                        .merge(
                          ElView.of(context).hasFocusVisible
                              ? ElStyle(
                                  outline: .new(
                                    outlineWidth: 2,
                                    outlineColor: context.elTheme.primary,
                                    outlineOffset: 2,
                                  ),
                                )
                              : null,
                        )
                        .merge(
                          ElView.of(context).hasTap
                              ? ElStyle(
                                  backgroundColor: solid
                                      ? color.mix(const Color(0xff000000), 20)
                                      : color.elLight8(context),
                                )
                              : null,
                        )
                  : null,
            )
            .merge(style);
      })(context),
      child: component.closable
          ? Row(
              mainAxisSize: .min,
              children: [
                if (component.child != null) ElView(child: component.child),
                _TagClose(component),
              ],
            )
          : component.child,
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
      final type = component.isToggle && !component.selected
          ? ElThemeType.info
          : component.type;
      final color = type.color(context);
      final solid =
          component.effect == .dark &&
          (!component.isToggle || component.selected);
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
        onHover: ElStyle(
          iconColor: context.elTheme.white,
          backgroundColor: solid ? color.elLight3(context) : color,
        ),
        onTap: ElStyle(
          iconColor: context.elTheme.white,
          backgroundColor: color.mix(const Color(0xff000000), 20),
        ),
        onFocusVisible: ElStyle(
          outline: .new(
            outlineWidth: 2,
            outlineColor: context.elTheme.primary,
            outlineOffset: 2,
          ),
        ),
        transition: const [ElTransition.all(Duration(milliseconds: 150))],
      ).merge(override);
    })(context),
    child: const ElIcon(ElIcons.close),
  );
}
