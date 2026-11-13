import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动弹层提供内容框架，路由生命周期由公共层持有。
Widget popupBuilder(BuildContext context, ElPopup c) {
  final t = context.elTheme;
  return _surface(
    context,
    c,
    ElStyle(
      borderRadius: .circular(28),
      vars: {
        ElTokens.$popupListPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ElTokens.$dividerColor: Color.lerp(t.borderColor, t.cardColor, .5)!,
      },
    ),
    Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        if (c.title != null || c.showClose)
          Stack(
            alignment: .center,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(c.showClose ? 52 : 24, 28, c.showClose ? 52 : 24, 16),
                child: ElView(
                  style: ElStyle(
                    fontSize: 20,
                    lineHeight: 1.4,
                    fontWeight: textWeight(t.fontWeightSubtitle),
                    textAlign: .center,
                  ),
                  child: c.title,
                ),
              ),
              if (c.showClose) PositionedDirectional(end: 12, child: _closeButton(context, 40)),
            ],
          ),
        Flexible(child: _scrollBody(c.child)),
        if (c.footer != null) TouchActionScope(child: buildContent(c.footer)),
      ],
    ),
  );
}

/// 移动确认框为正文保留内边距，页脚通栏贴合底部圆角。
Widget dialogBuilder(BuildContext context, ElDialog c) {
  final t = context.elTheme;
  return _surface(
    context,
    c,
    const ElStyle(
      maxWidth: 420,
      borderRadius: .all(.circular(28)),
      textAlign: .center,
      vars: {ElTokens.$popupListPadding: EdgeInsets.zero},
    ),
    Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const SizedBox(height: 32),
        if (c.title != null || c.showClose)
          Padding(
            padding: const .fromLTRB(32, 0, 32, 10),
            child: Row(
              children: [
                if (c.showClose) const SizedBox(width: 40),
                Expanded(
                  child: ElView(
                    style: ElStyle(fontSize: 22, lineHeight: 1.45, fontWeight: textWeight(t.fontWeightSubtitle)),
                    child: c.title,
                  ),
                ),
                if (c.showClose) _closeButton(context, 40),
              ],
            ),
          ),
        Flexible(child: _scrollBody(c.child, padding: EdgeInsets.fromLTRB(32, 0, 32, c.footer == null ? 32 : 24))),
        // 确认、取消等页脚操作额外提供触感。
        if (c.footer != null) TouchActionScope(child: buildContent(c.footer)),
      ],
    ),
  );
}

/// 抽屉保留业务子树和页脚，内容超长时独立滚动。
Widget drawerBuilder(BuildContext context, ElDrawer c) {
  final t = context.elTheme;
  return _surface(
    context,
    c,
    const ElStyle(vars: {ElTokens.$popupListPadding: EdgeInsets.zero}),
    LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (c.title != null || c.showClose)
            ElView(
              style: ElStyle(
                minHeight: 73,
                padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 16, 15),
                border: ElBorder.only(borderBottom: ElBorderSide(borderColor: t.borderColor)),
              ),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: ElView(
                      style: ElStyle(fontSize: 20, lineHeight: 1.4, fontWeight: textWeight(t.fontWeightSubtitle)),
                      child: c.title,
                    ),
                  ),
                  if (c.showClose) _closeButton(context, 44),
                ],
              ),
            ),
          // 有限高度内让正文占满余量，短内容时页脚也贴着底边。
          Flexible(
            fit: constraints.hasBoundedHeight ? .tight : .loose,
            child: _scrollBody(c.child, padding: context.elTheme.drawerBodyPadding ?? const .all(24)),
          ),
          if (c.footer != null)
            ElView(
              style: ElStyle(
                padding: const .fromLTRB(24, 17, 24, 20),
                border: ElBorder.only(borderTop: ElBorderSide(borderColor: t.borderColor)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                child: buildContent(c.footer),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _surface(BuildContext context, ElPopup component, ElStyle style, Widget child) {
  final theme = context.elTheme;
  return ElView(
    event: component.event,
    semantics: ElSemantics(container: true, label: component.semanticLabel),
    style: ElStyle(
      width: '100%',
      clipBehavior: .antiAlias,
      backgroundColor: theme.cardColor,
      color: theme.textColor,
    ).merge(style).withShadow(type: .floating, level: theme.shadowXl).merge(component.style),
    child: child,
  );
}

Widget _scrollBody(Widget child, {EdgeInsetsGeometry? padding}) =>
    SingleChildScrollView(primary: false, padding: padding, physics: const ClampingScrollPhysics(), child: child);

Widget _closeButton(BuildContext context, double size) => ElButton(
  semanticLabel: '关闭弹层',
  variant: .text,
  style: ElStyle(
    width: size,
    height: size,
    padding: .zero,
    borderRadius: .circular(12),
    iconSize: 18,
    iconColor: context.elTheme.textSecondary,
    transition: reducedMotion(context)
        ? const []
        : const [ElTransition.field(.backgroundColor, Duration(milliseconds: 140))],
    onTap: ElStyle(backgroundColor: context.elTheme.press, transform: ElTransform.scale(1), transition: const []),
  ),
  child: ElMobileIcons.x,
  onPressed: () => Navigator.of(context).pop(),
);

/// 轻提示使用品牌阴影和文字色，不创建可交互焦点。
Widget toastBuilder(BuildContext context, ElToast c) {
  final t = context.elTheme;
  return ElView(
    semantics: ElSemantics(label: c.semanticLabel),
    style: ElStyle(
      maxWidth: 400,
      padding: const .symmetric(horizontal: 20, vertical: 15),
      backgroundColor: t.cardColor,
      borderRadius: .circular(18),
      border: .all(borderColor: t.borderColor),
      fontSize: 14,
      lineHeight: 1.6,
      color: t.textColor,
      iconColor: t.primary,
      iconSize: 20,
    ).withShadow(level: ElLevelType.lg.shadow(context)).merge(c.style),
    child: Row(
      mainAxisSize: .min,
      children: [
        if (c.icon != null) ...[buildContent(c.icon), const SizedBox(width: 12)],
        Flexible(child: buildContent(c.child)),
      ],
    ),
  );
}
