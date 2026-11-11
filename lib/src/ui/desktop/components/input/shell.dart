part of 'index.dart';

/// 输入框壳样式（官方 el-input 盒模型直译）：
/// - 边框 = `1px inset box-shadow` 三态（base → hover → focus-within），
///   官方就是 shadow 而非真实 border，零布局影响、过渡走 transitionBoxShadow；
/// - 单行：高度、字号与水平 padding 跟随紧凑模式；
///   textarea：垂直 padding 固定 5，水平 padding 随密度 + 列布局自然高；
/// - 错误态（表单校验失败）danger 环压过 hover/focus；禁用态三色 + not-allowed。
ElStyle _inputShellStyle(
  BuildContext c, {
  required bool isDisabled,
  required bool hasError,
  required bool textarea,
  required bool compact,
  required double fontSize,
  required EdgeInsetsGeometry padding,
}) {
  final boxSize = elInputControlHeight(compact);
  final radius = BorderRadius.circular(c.elTheme.radiusSm);
  List<BoxShadow> ring(Color color) => [ElBoxShadow(color: color, spreadRadius: 1, inset: true)];

  if (isDisabled) {
    return ElStyle(
      width: '100%',
      height: textarea ? null : boxSize,
      cursor: SystemMouseCursors.forbidden,
      alignment: textarea ? null : .centerLeft,
      backgroundColor: c.isDark ? const Color(0xff262727) : const Color(0xfff5f7fa),
      borderRadius: radius,
      boxShadow: ring(c.elTheme.borderColorLight),
      fontSize: fontSize,
      iconColor: c.elTheme.textPlaceholder,
      lineHeight: elInputLineHeightFactor,
      padding: padding,
    );
  }

  final danger = hasError ? c.elTheme.error : null;
  final baseRing = danger ?? c.elTheme.borderColor;
  final hoverRing = danger ?? (c.isDark ? const Color(0xff8d9095) : const Color(0xffc0c4cc));
  final focusRing = danger ?? c.elTheme.primary;

  return ElStyle(
    width: '100%',
    height: textarea ? null : boxSize,
    cursor: SystemMouseCursors.text,
    alignment: textarea ? null : .centerLeft,
    backgroundColor: c.elTheme.bgColor,
    borderRadius: radius,
    boxShadow: ring(baseRing),
    transition: const [
      ElTransition.field(ElTransitionField.boxShadow, Duration(milliseconds: 200), Cubic(0.645, 0.045, 0.355, 1)),
    ],
    fontSize: fontSize,
    // 默认图标色放在壳上，前后缀继承状态样式，用户 style 与 affixStyle 仍可覆写。
    iconColor: c.elTheme.textPlaceholder,
    lineHeight: elInputLineHeightFactor,
    padding: padding,
    // focus 用 onFocusWithin，因为焦点在内部 editable 节点上；
    // 官方 `.is-focus` 是任意焦点来源（非 focus-visible），无键盘专属环
    onHover: ElStyle(boxShadow: ring(hoverRing)),
    onFocusWithin: ElStyle(boxShadow: ring(focusRing)),
  );
}
