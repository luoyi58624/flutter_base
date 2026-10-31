import 'package:flutter_base/src/ui/desktop/internal.dart';
import 'package:flutter/widgets.dart';

List<double> get _heights => const [20, 24, 26, 28, 32];

List<double> get _paddings => const [10, 12, 12, 20, 24];

List<double> get _fontSizes => const [10, 11, 12, 12, 13];

List<double> get _closeGaps => const [3, 4, 4, 8, 10];

List<double> get _closeSizes => const [12, 14, 14, 18, 20];

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
        final size = context.elComponentSize(style).index;
        final height = _heights[size];
        final type = component.isToggle && !selected
            ? ElThemeType.info
            : component.type;
        final color = type.color(context);
        final solid =
            component.effect == .dark && (!component.isToggle || selected);
        final bg = solid
            ? color
            : component.effect == .plain
            ? ElThemeData.of(context).bgColor
            : color.elLight9(context);
        final border = component.hit || solid ? color : color.elLight8(context);
        return ElStyle(
              height: height,
              widthFactor: 1,
              padding: .only(
                left: _paddings[size],
                right: component.closable ? _closeGaps[size] : _paddings[size],
              ),
              bgColor: bg,
              border: .all(color: border),
              borderRadius: .all(
                Radius.circular(component.round ? 9999 : height * 0.45),
              ),
              color: solid ? ElThemeData.of(context).white : color,
              fontSize: _fontSizes[size],
              fontWeight: .w500,
              lineHeight: 1,
              alignment: .center,
              softWrap: false,
              cursor: component.isToggle ? SystemMouseCursors.click : null,
              onDisabled: const ElStyle(
                opacity: 0.5,
                cursor: SystemMouseCursors.forbidden,
              ),
              transitions: const [
                ElTransition.all(Duration(milliseconds: 150), Curves.easeInOut),
              ],
              iconColor: solid ? ElThemeData.of(context).white : color,
            )
            .merge(
              component.isToggle && !component.disabled
                  ? const ElStyle()
                        .merge(
                          ElView.of(context).hasFocusVisible
                              ? ElStyle(
                                  outline: .new(
                                    width: 2,
                                    color: ElThemeData.of(context).primary,
                                    offset: 2,
                                  ),
                                )
                              : null,
                        )
                        .merge(
                          ElView.of(context).hasTap
                              ? ElStyle(
                                  bgColor: solid
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
      final size = context.elComponentSize(null).index;
      final type = component.isToggle && !component.selected
          ? ElThemeType.info
          : component.type;
      final color = type.color(context);
      final solid =
          component.effect == .dark &&
          (!component.isToggle || component.selected);
      final foreground = solid ? ElThemeData.of(context).white : color;
      final override = component.closeStyle;
      return ElStyle(
        margin: .only(left: _closeGaps[size]),
        width: _closeSizes[size],
        height: _closeSizes[size],
        borderRadius: BorderRadius.all(Radius.circular(9999)),
        alignment: .center,
        iconSize: _closeSizes[size] - 2,
        iconColor: foreground,
        cursor: SystemMouseCursors.click,
        onHover: ElStyle(
          iconColor: ElThemeData.of(context).white,
          bgColor: solid ? color.elLight3(context) : color,
        ),
        onTap: ElStyle(
          iconColor: ElThemeData.of(context).white,
          bgColor: color.mix(const Color(0xff000000), 20),
        ),
        onFocusVisible: ElStyle(
          outline: .new(
            width: 2,
            color: ElThemeData.of(context).primary,
            offset: 2,
          ),
        ),
        transitions: const [ElTransition.all(Duration(milliseconds: 150))],
      ).merge(override);
    })(context),
    child: const ElIcon(ElIcons.close),
  );
}
