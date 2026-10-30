/// 参照：D:/project/html/my-ui/packages/vue/components/Button.vue；packages/core/my-ui.js:1243-1316；my-ui.css:165-441。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../cores/common.dart';
import '../cores/glyph.dart';
import '../cores/theme.dart';
import 'loading.dart';

/// Web按钮的七种视觉层级。
enum MyButtonVariant {
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
enum MyButtonType {
  /// 只触发click。
  button,

  /// click未阻止默认行为时校验并保存最近Form。
  submit,

  /// click未阻止默认行为时重置最近Form。
  reset,
}

/// 与Web相同的尺寸、变体、加载覆盖层和激活事件。
class MyButton extends StatelessWidget {
  /// onClick为空仍可聚焦，loading保留焦点与内容尺寸。
  const MyButton({
    super.key,
    this.variant = MyButtonVariant.primary,
    this.icon,
    this.disabled = false,
    this.loading = false,
    this.selected,
    this.delayTouchDown = Duration.zero,
    this.delayTouchUp = const Duration(milliseconds: 100),
    this.type = MyButtonType.button,
    this.onClick,
    this.child,
    this.label,
    this.focusNode,
    this.style,
    this.event,
  });

  /// 视觉层级。
  final MyButtonVariant variant;

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
  final MyButtonType type;

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
    final t = MyTheme.of(context);
    final fixed = [
      MyButtonVariant.icon,
      MyButtonVariant.bare,
      MyButtonVariant.round,
    ].contains(variant);
    final flat = [
      MyButtonVariant.text,
      MyButtonVariant.bare,
      MyButtonVariant.link,
    ].contains(variant);
    final side = variant == MyButtonVariant.round ? 46.0 : 44.0;
    final foreground = switch (variant) {
      MyButtonVariant.primary => t.primaryText,
      MyButtonVariant.icon => selected == true ? t.primary : t.textSecondary,
      MyButtonVariant.bare => t.textSecondary,
      _ => t.primary,
    };
    final background = switch (variant) {
      MyButtonVariant.primary => t.primary,
      MyButtonVariant.outline => t.cardBackground,
      MyButtonVariant.icon || MyButtonVariant.round => t.fill,
      _ => const Color(0x00000000),
    };
    final border =
        [
          MyButtonVariant.outline,
          MyButtonVariant.icon,
          MyButtonVariant.round,
        ].contains(variant)
        ? t.border
        : const Color(0x00000000);
    final noFeedback = disabled || loading;
    final buttonStyle = ElStyle(
      minHeight: 44,
      widthFactor: 1,
      heightFactor: 1,
      width: fixed ? side : null,
      height: fixed ? side : null,
      // ElView边框只绘制不占布局，补入CSS border-box的横向1px。
      padding: EdgeInsets.symmetric(
        horizontal: fixed || variant == MyButtonVariant.link
            ? 0
            : (variant == MyButtonVariant.text
                      ? 8
                      : myViewport(context) <= 400
                      ? 13
                      : 17) +
                  1,
      ),
      margin: variant == MyButtonVariant.link
          ? const EdgeInsets.only(top: 24)
          : null,
      alignment: Alignment.center,
      softWrap: false,
      bgColor: disabled && variant != MyButtonVariant.bare
          ? t.fill
          : background,
      color: disabled && !(variant == MyButtonVariant.icon && selected == true)
          ? t.textSecondary
          : foreground,
      fontSize: variant == MyButtonVariant.link ? 14 : 15,
      fontWeight: t.weight(t.fontWeightAction),
      fontVariations: [FontVariation('wght', t.fontWeightAction)],
      border: ElBorder.all(
        width: variant == MyButtonVariant.link ? 0 : 1,
        color: border,
      ),
      borderRadius: BorderRadius.circular(
        variant == MyButtonVariant.round
            ? 14
            : fixed
            ? 12
            : 13,
      ),
      opacity:
          disabled &&
              ![MyButtonVariant.text, MyButtonVariant.bare].contains(variant)
          ? .68
          : 1,
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : loading
          ? SystemMouseCursors.progress
          : SystemMouseCursors.click,
      transitions: const [
        ElTransition.all(Duration(milliseconds: 150), Curves.ease),
        ElTransition.field(
          ElTransitionField.transform,
          Duration(milliseconds: 160),
          Cubic(.2, .7, .2, 1),
        ),
        ElTransition.field(
          ElTransitionField.opacity,
          Duration(milliseconds: 200),
          Curves.ease,
        ),
      ],
      onHover: noFeedback
          ? null
          : ElStyle(
              bgColor: variant == MyButtonVariant.primary
                  ? Color.lerp(t.primary, const Color(0xff000000), .06)
                  : t.hover,
            ),
      onTap: noFeedback
          ? null
          : ElStyle(
              bgColor: variant == MyButtonVariant.primary
                  ? Color.lerp(t.primary, const Color(0xff000000), .14)
                  : t.press,
              transform: ElTransform.scale(flat ? 1 : .95),
              transitions: flat ? const [] : null,
            ),
      onFocusVisible: myFocusStyle(context),
    ).merge(style);
    final glyphSize = switch (variant) {
      MyButtonVariant.icon || MyButtonVariant.bare => 19.0,
      MyButtonVariant.round => 17.0,
      MyButtonVariant.link => 14.0,
      _ => 16.0,
    };
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: icon != null && child != null
          ? (variant == MyButtonVariant.link ? 6 : 7)
          : 0,
      children: [
        if (icon != null)
          ExcludeSemantics(
            child: ElView(
              style: ElStyle(width: glyphSize, height: glyphSize),
              child: MyGlyph(name: icon!),
            ),
          ),
        if (child != null) myContent(child),
      ],
    );
    return myInline(
      MyAction(
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
            case MyButtonType.button:
              break;
            case MyButtonType.submit:
              if (form?.validate() == true) form!.save();
            case MyButtonType.reset:
              form?.reset();
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: loading ? 0 : 1,
              alwaysIncludeSemantics: true,
              child: content,
            ),
            if (loading)
              const Positioned.fill(
                child: ExcludeSemantics(
                  child: Center(child: MyLoading(size: MyLoadingSize.small)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
