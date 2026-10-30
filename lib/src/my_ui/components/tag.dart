/// 参照：D:/project/html/my-ui/packages/vue/components/Tag.vue；packages/core/my-ui.js:1317-1357；my-ui.css:443-533。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../cores/common.dart';
import '../cores/theme.dart';

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
      final t = MyTheme.of(context);
      final selectable = value != null || modelValue != null;
      final accent =
          t.tagColor ??
          switch (tone) {
            MyTagTone.blue => t.primary,
            MyTagTone.green => t.success,
            MyTagTone.orange => t.warning,
            MyTagTone.red => t.danger,
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
                            width: 1,
                            color: selectable
                                ? (selected ? t.primary : t.border)
                                : Color.lerp(t.cardBackground, accent, .18),
                          ),
                          color: selectable
                              ? (selected ? t.primaryText : t.textSecondary)
                              : accent,
                          bgColor: pressed
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
                              ? (selected ? t.primary : t.cardBackground)
                              : Color.lerp(t.cardBackground, accent, .1),
                          transform: ElTransform.scale(pressed ? .95 : 1),
                          transitions: myReducedMotion(context)
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
