/// 参照：D:/project/html/my-ui/packages/vue/components/Tag.vue；packages/core/my-ui.js:1317-1357；my-ui.css:443-533。
library;

import 'package:flutter/widgets.dart';

import '../../../../flutter/commons/models.dart' show ElThemeType;
import '../../../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../../../flutter/components/tag/index.dart' show ElTag, ElTagEffect;
import '../../../../flutter/views/button/button_view.dart' show ElButtonView;
import '../../../../flutter/views/view/event/event.dart' show ElEvent, ElEventHandler;
import '../../../../flutter/views/view/style/style.dart' show ElBorder, ElStyle, ElTransform, ElTransition;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../commons/icons.dart' show ElMobileIcons;
import '../../internal/common.dart';

/// 为通用标签绘制移动端外观，值切换和主入口事件由 ElTag 统一持有。
Widget tagBuilder(BuildContext context, ElTag component) =>
    Builder(builder: (context) => _commonTag(context, component));

/// 展示标签颜色；可选择标签统一使用主题色。
enum TagTone {
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
class Tag extends StatelessWidget {
  /// 覆盖标签默认语义颜色。
  static const $color = 'tag.color';

  /// value与modelValue互斥，onChanged先于onClick。
  const Tag({
    super.key,
    this.value,
    this.modelValue,
    this.tone = TagTone.blue,
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
  final TagTone tone;

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

  /// 标签外观与交互变体覆盖。
  final ElStyle? style;
  @override
  Widget build(BuildContext context) => ValueBuilder<bool>(
    value: value ?? false,
    notifier: modelValue,
    onChanged: onChanged,
    builder: (context, current, change) {
      final t = context.elTheme;
      final selectable = value != null || modelValue != null;
      final accent =
          ElView.maybeOf(context)?.getVar<Color>(Tag.$color) ??
          switch (tone) {
            TagTone.blue => t.primary,
            TagTone.green => t.success,
            TagTone.orange => t.warning,
            TagTone.red => t.error,
            TagTone.gray => t.textSecondary,
          };
      final selected = selectable && current;
      final base = textStyle(context, 13, t.fontWeightAction, height: 20 / 13)
          .merge(
            ElStyle(
              minHeight: selectable ? 32 : 28,
              // 内容改由 Widget 承载后，仍按自然高度收紧，避免居中撑满父约束。
              heightFactor: 1,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              softWrap: false,
              borderRadius: BorderRadius.circular(selectable ? 11 : 999),
              border: ElBorder.all(
                borderWidth: 1,
                borderColor: selectable ? (selected ? t.primary : t.borderColor) : Color.lerp(t.cardColor, accent, .18),
              ),
              color: selectable ? (selected ? t.primaryText : t.textSecondary) : accent,
              iconColor: selectable ? (selected ? t.primaryText : t.textSecondary) : accent,
              backgroundColor: selectable ? (selected ? t.primary : t.cardColor) : Color.lerp(t.cardColor, accent, .1),
              opacity: disabled ? .6 : 1,
              transform: ElTransform.scale(1),
              transition: reducedMotion(context)
                  ? const []
                  : const [ElTransition.all(Duration(milliseconds: 160), Curves.ease)],
              onTap: selectable && !disabled
                  ? ElStyle(
                      backgroundColor: selected ? Color.lerp(t.primary, const Color(0xff000000), .14) : t.press,
                      transform: ElTransform.scale(.95),
                    )
                  : null,
            ),
          )
          .merge(style);
      // 视觉和交互共用宿主，内容仍不参与命中，全部变体统一交给 ElView 级联。
      final content = IgnorePointer(child: buildContent(child));
      return inline(
        selectable
            ? ActionView(
                style: base,
                disabled: disabled,
                focusNode: focusNode,
                toggled: current,
                delayTouchUp: Duration.zero,
                onActivate: (e) {
                  change(!current);
                  onClick?.call(e);
                },
                child: content,
              )
            : ElView(
                style: base,
                event: ElEvent(
                  disabled: disabled,
                  onTap: (e) {
                    if (!disabled) onClick?.call(e);
                  },
                ),
                child: content,
              ),
      );
    },
  );
}

Widget _commonTag(BuildContext context, ElTag component) {
  final theme = context.elTheme;
  final state = ElView.of(context);
  final pressed = component.isToggle && !component.disabled && state.hasTap;
  final accent =
      ElView.maybeOf(context)?.getVar<Color>(Tag.$color) ??
      switch (component.type) {
        ElThemeType.success => theme.success,
        ElThemeType.warning => theme.warning,
        ElThemeType.error => theme.error,
        ElThemeType.info => theme.textSecondary,
        _ => theme.primary,
      };
  final selected = component.isToggle && component.selected;
  final displayAccent = component.isToggle && !selected ? theme.textSecondary : accent;
  final filled = component.effect == ElTagEffect.dark;
  final background = filled
      ? displayAccent
      : component.effect == ElTagEffect.plain
      ? theme.cardColor
      : Color.lerp(theme.cardColor, displayAccent, selected ? .18 : .1)!;
  final foreground = filled
      ? (displayAccent.computeLuminance() > .45 ? const Color(0xff000000) : const Color(0xffffffff))
      : displayAccent;
  final border = filled || component.hit || component.effect == ElTagEffect.plain
      ? displayAccent
      : selected
      ? Color.lerp(theme.cardColor, displayAccent, .4)!
      : component.isToggle
      ? theme.borderColor
      : Color.lerp(theme.cardColor, displayAccent, .18)!;
  final style = textStyle(context, 13, theme.fontWeightAction, height: 20 / 13)
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
              ? Color.lerp(background, filled ? const Color(0xff000000) : theme.press, filled ? .14 : 1)
              : background,
          color: foreground,
          iconColor: foreground,
          iconSize: 16,
          opacity: component.disabled ? .6 : 1,
          transform: ElTransform.scale(pressed ? .95 : 1),
          transition: reducedMotion(context)
              ? const []
              : const [ElTransition.all(Duration(milliseconds: 160), Curves.ease)],
        ),
      )
      .merge(component.style);
  return inline(
    ElView(
      style: style,
      child: Row(
        mainAxisSize: .min,
        spacing: component.closable ? 7 : 0,
        children: [
          if (component.child != null) buildContent(component.child),
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
                iconSize: 14,
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ).merge(component.closeStyle),
              child: ElMobileIcons.x,
            ),
        ],
      ),
    ),
  );
}
