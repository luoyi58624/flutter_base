part of 'index.dart';

/// 输入框壳样式（官方 el-input 盒模型直译）：
/// - 边框 = `1px inset box-shadow` 三态（base → hover → focus-within），
///   官方就是 shadow 而非真实 border，零布局影响、过渡走 transitionBoxShadow；
/// - 单行：高度跟随 [ElThemeData.buttonHeights] 当前档，字号与 padding 同档递进；
///   textarea：垂直 padding 固定 5，水平 padding 随档 + 列布局自然高；
/// - 错误态（表单校验失败）danger 环压过 hover/focus；禁用态三色 + not-allowed。
ElStyle _inputShellStyle(
  BuildContext c, {
  required bool isDisabled,
  required bool hasError,
  required bool textarea,
  required ElLevelType size,
  required double fontSize,
  required EdgeInsetsGeometry padding,
  required ElLevelType? declaredSize,
}) {
  final isDesktop = ElPlatform.isDesktop;
  final boxSize = ElThemeData.of(c).buttonHeights[size.index];
  final radius = BorderRadius.circular(ElThemeData.of(c).radiusSm);
  List<BoxShadow> ring(Color color) => [
    ElBoxShadow(color: color, spreadRadius: 1, inset: true),
  ];

  if (isDisabled) {
    return ElStyle(
      width: '100%',
      height: textarea ? null : boxSize,
      cursor: SystemMouseCursors.forbidden,
      alignment: textarea ? null : .centerLeft,
      bgColor: c.isDark ? const Color(0xff262727) : const Color(0xfff5f7fa),
      borderRadius: radius,
      boxShadow: ring(c.elTheme.borderColorLight),
      fontSize: fontSize,
      lineHeight: elInputLineHeightFactor,
      leadingDistribution: .even,
      textBaseline: .alphabetic,
      padding: padding,
    );
  }

  final danger = hasError ? ElThemeData.of(c).error : null;
  final baseRing = danger ?? ElThemeData.of(c).borderColor;
  final hoverRing =
      danger ?? (c.isDark ? const Color(0xff8d9095) : const Color(0xffc0c4cc));
  final focusRing = danger ?? ElThemeData.of(c).primary;

  return ElStyle(
    width: '100%',
    height: textarea ? null : boxSize,
    cursor: SystemMouseCursors.text,
    alignment: textarea ? null : .centerLeft,
    bgColor: ElThemeData.of(c).bgColor,
    borderRadius: radius,
    boxShadow: ring(baseRing),
    transitions: ElThemeData.of(c).transitionBoxShadow,
    fontSize: fontSize,
    lineHeight: elInputLineHeightFactor,
    leadingDistribution: .even,
    textBaseline: .alphabetic,
    padding: padding,
    // 桌面才有 hover 语义；focus 用 onFocusWithin——焦点在内部 editable 节点上，
    // 官方 `.is-focus` 是任意焦点来源（非 focus-visible），无键盘专属环
    onHover: isDesktop ? ElStyle(boxShadow: ring(hoverRing)) : null,
    onFocusWithin: ElStyle(boxShadow: ring(focusRing)),
  );
}
