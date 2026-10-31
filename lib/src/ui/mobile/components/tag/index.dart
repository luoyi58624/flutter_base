/// 参照：D:/project/html/my-ui/packages/vue/components/Tag.vue；packages/core/my-ui.js:1317-1357；my-ui.css:443-533。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';

/// 为通用标签绘制移动端外观，值切换和主入口事件由 ElTag 统一持有。
Widget myTagBuilder(BuildContext context, ElTag component) =>
    Builder(builder: (context) => _commonTag(context, component));

/// 展示标签颜色；可选择标签统一使用主题色。
enum MyTagTone {
  /// 主色。
  blue,

  /// 成功色。
  green,

  /// 警告色。
  orange,

  /// 危险色。
  red,

  /// 次要文字色。
  gray,
}

/// value为空时展示，为布尔值时作为独立选择按钮。
class MyTag extends StatelessWidget {
  /// 覆盖标签默认语义颜色。
  static const $color = 'my.tag.color';

  /// value与modelValue互斥，onChanged先于onClick。
  const MyTag({
    super.key,
    this.value,
    this.modelValue,
    this.tone = MyTagTone.blue,
    this.disabled = false,
    this.onChanged,
    this.onClick,
    this.child,
    this.focusNode,
    this.style,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥');

  /// 选择值；null保留展示语义。
  final bool? value;

  /// 可选双向值，生命周期归调用方。
  final ValueNotifier<bool>? modelValue;

  /// 展示色。
  final MyTagTone tone;

  /// 禁止click与切换。
  final bool disabled;

  /// 用户切换。
  final ValueChanged<bool>? onChanged;

  /// change之后派发的click。
  final ElEventHandler? onClick;

  /// 默认插槽。
  final Object? child;

  /// 选择按钮的外部焦点。
  final FocusNode? focusNode;

  /// 内层外观覆盖。
  final ElStyle? style;
  @override
  Widget build(BuildContext context) => MyValueBuilder<bool>(
    value: value ?? false,
    notifier: modelValue,
    onChanged: onChanged,
    builder: (context, current, change) {
      final t = context.elTheme;
      final selectable = value != null || modelValue != null;
      final accent =
          ElView.maybeOf(context)?.getVar<Color>(MyTag.$color) ??
          switch (tone) {
            MyTagTone.blue => t.primary,
            MyTagTone.green => t.success,
            MyTagTone.orange => t.warning,
            MyTagTone.red => t.error,
            MyTagTone.gray => t.textSecondary,
          };
      final radius = BorderRadius.circular(selectable ? 11 : 999);
      Widget visual(bool keyboardPressed) => Builder(
        builder: (innerContext) {
          final state = ElView.of(innerContext);
          final pressed =
              selectable && !disabled && (state.hasTap || keyboardPressed);
          final hover = selectable && !disabled && state.hasHover;
          final selected = selectable && current;
          return IgnorePointer(
            child: ElView(
              style:
                  myTextStyle(context, 13, t.fontWeightAction, height: 20 / 13)
                      .merge(
                        ElStyle(
                          minHeight: selectable ? 32 : 28,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          alignment: Alignment.center,
                          softWrap: false,
                          borderRadius: radius,
                          border: ElBorder.all(
                            borderWidth: 1,
                            borderColor: selectable
                                ? (selected ? t.primary : t.borderColor)
                                : Color.lerp(t.cardColor, accent, .18),
                          ),
                          color: selectable
                              ? (selected ? t.primaryText : t.textSecondary)
                              : accent,
                          backgroundColor: pressed
                              ? (selected
                                    ? Color.lerp(
                                        t.primary,
                                        const Color(0xff000000),
                                        .14,
                                      )
                                    : t.press)
                              : hover
                              ? (selected
                                    ? Color.lerp(
                                        t.primary,
                                        const Color(0xff000000),
                                        .06,
                                      )
                                    : t.hover)
                              : selectable
                              ? (selected ? t.primary : t.cardColor)
                              : Color.lerp(t.cardColor, accent, .1),
                          transform: ElTransform.scale(pressed ? .95 : 1),
                          transition: myReducedMotion(context)
                              ? const []
                              : const [
                                  ElTransition.all(
                                    Duration(milliseconds: 160),
                                    Curves.ease,
                                  ),
                                ],
                        ),
                      )
                      .merge(style),
              child: child,
            ),
          );
        },
      );
      final outer = ElStyle(
        borderRadius: radius,
        opacity: disabled ? .6 : 1,
        onHover: const ElStyle(),
        onTap: const ElStyle(),
        onFocusVisible: selectable ? myFocusStyle(context) : null,
      );
      return myInline(
        selectable
            ? MyAction(
                style: outer,
                disabled: disabled,
                focusNode: focusNode,
                toggled: current,
                delayTouchUp: Duration.zero,
                keyboardBuilder: visual,
                onActivate: (e) {
                  change(!current);
                  onClick?.call(e);
                },
                child: const SizedBox.shrink(),
              )
            : ElView(
                style: outer.copyWith(onHover: null, onTap: null),
                event: ElEvent(
                  onTap: (e) {
                    if (!disabled) onClick?.call(e);
                  },
                ),
                child: visual(false),
              ),
      );
    },
  );
}

Widget _commonTag(BuildContext context, ElTag component) {
  final theme = context.elTheme;
  final state = ElView.of(context);
  final pressed = component.isToggle && !component.disabled && state.hasTap;
  final hovered = component.isToggle && !component.disabled && state.hasHover;
  final accent =
      ElView.maybeOf(context)?.getVar<Color>(MyTag.$color) ??
      switch (component.type) {
        ElThemeType.success => theme.success,
        ElThemeType.warning => theme.warning,
        ElThemeType.error => theme.error,
        ElThemeType.info => theme.textSecondary,
        _ => theme.primary,
      };
  final selected = component.isToggle && component.selected;
  final displayAccent = component.isToggle && !selected
      ? theme.textSecondary
      : accent;
  final filled = component.effect == ElTagEffect.dark;
  final background = filled
      ? displayAccent
      : component.effect == ElTagEffect.plain
      ? theme.cardColor
      : Color.lerp(theme.cardColor, displayAccent, selected ? .18 : .1)!;
  final foreground = filled
      ? (displayAccent.computeLuminance() > .45
            ? const Color(0xff000000)
            : const Color(0xffffffff))
      : displayAccent;
  final border =
      filled || component.hit || component.effect == ElTagEffect.plain
      ? displayAccent
      : selected
      ? Color.lerp(theme.cardColor, displayAccent, .4)!
      : component.isToggle
      ? theme.borderColor
      : Color.lerp(theme.cardColor, displayAccent, .18)!;
  final style =
      myTextStyle(context, 13, theme.fontWeightAction, height: 20 / 13)
          .merge(
            ElStyle(
              minHeight: component.isToggle ? 32 : 28,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: .center,
              softWrap: false,
              borderRadius: BorderRadius.circular(
                component.round
                    ? 999
                    : component.isToggle
                    ? 11
                    : 8,
              ),
              border: ElBorder.all(borderWidth: 1, borderColor: border),
              backgroundColor: pressed
                  ? Color.lerp(
                      background,
                      filled ? const Color(0xff000000) : theme.press,
                      filled ? .14 : 1,
                    )
                  : hovered
                  ? Color.lerp(
                      background,
                      filled ? const Color(0xff000000) : theme.hover,
                      filled ? .06 : 1,
                    )
                  : background,
              color: foreground,
              opacity: component.disabled ? .6 : 1,
              transform: ElTransform.scale(pressed ? .95 : 1),
              outline: state.hasFocusVisible
                  ? myFocusStyle(context).outline
                  : null,
              transition: myReducedMotion(context)
                  ? const []
                  : const [
                      ElTransition.all(
                        Duration(milliseconds: 160),
                        Curves.ease,
                      ),
                    ],
            ),
          )
          .merge(component.style);
  return myInline(
    ElView(
      style: style,
      child: Row(
        mainAxisSize: .min,
        spacing: component.closable ? 7 : 0,
        children: [
          if (component.child != null) myContent(component.child),
          if (component.closable)
            ElButtonView(
              semanticLabel: component.closeSemanticLabel ?? '关闭标签',
              disabled: component.disabled,
              onPressed: component.onClose,
              event: ElEvent(onTap: (event) => event.stopPropagation()),
              style: const ElStyle(
                width: 18,
                height: 18,
                alignment: .center,
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ).merge(component.closeStyle),
              child: '×',
            ),
        ],
      ),
    ),
  );
}
