import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动弹层提供内容框架，路由生命周期由公共层持有。
Widget popupBuilder(BuildContext context, ElPopup c) => _panel(context, c);

/// 移动确认框为正文保留内边距，页脚通栏贴合底部圆角。
Widget dialogBuilder(BuildContext context, ElDialog c) {
  final t = context.elTheme;
  return ElView(
    event: c.event,
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    style: ElStyle(
      width: '100%',
      maxWidth: 420,
      borderRadius: .circular(28),
      clipBehavior: .antiAlias,
      backgroundColor: t.cardColor,
      color: t.textColor,
      textAlign: .center,
      boxShadow: t.shadowXl,
    ).merge(c.style),
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const SizedBox(height: 32),
        if (c.title != null || c.showClose)
          Padding(
            padding: const .fromLTRB(32, 0, 32, 10),
            child: Row(
              children: [
                if (c.showClose) const SizedBox(width: 32),
                Expanded(
                  child: ElView(
                    style: ElStyle(fontSize: 22, fontWeight: textWeight(t.fontWeightSubtitle)),
                    child: c.title,
                  ),
                ),
                if (c.showClose)
                  ElButton(
                    semanticLabel: '关闭弹层',
                    variant: .text,
                    style: const ElStyle(width: 32, height: 32, padding: .zero),
                    child: ElMobileIcons.x,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
        Flexible(
          child: SingleChildScrollView(padding: const .symmetric(horizontal: 32), child: c.child),
        ),
        SizedBox(height: c.footer == null ? 32 : 24),
        // 确认、取消等操作按钮启用按压跟踪与触感，正文和关闭按钮保持普通行为。
        if (c.footer != null) TouchActionScope(child: buildContent(c.footer)),
      ],
    ),
  );
}

/// 抽屉保留业务子树和页脚，内容超长时独立滚动。
Widget drawerBuilder(BuildContext context, ElDrawer c) => _panel(context, c);

Widget _panel(BuildContext context, ElPopup c) {
  final t = context.elTheme;
  return ElView(
    event: c.event,
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    style: ElStyle(
      width: '100%',
      padding: const .all(24),
      borderRadius: .circular(26),
      backgroundColor: t.cardColor,
      color: t.textColor,
      boxShadow: t.shadowXl,
    ).merge(c.style),
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        if (c is! ElDialog) ...[
          Center(
            child: ElView(
              style: ElStyle(width: 34, height: 4, borderRadius: .circular(2), backgroundColor: t.borderColor),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (c.title != null || c.showClose) ...[
          Row(
            children: [
              Expanded(
                child: ElView(
                  style: const ElStyle(fontSize: 20, fontWeight: .w600),
                  child: c.title,
                ),
              ),
              if (c.showClose)
                ElButton(
                  semanticLabel: '关闭弹层',
                  variant: .text,
                  style: const ElStyle(width: 32, height: 32, padding: .zero),
                  child: ElMobileIcons.x,
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        Flexible(child: SingleChildScrollView(child: c.child)),
        if (c.footer != null) ...[const SizedBox(height: 24), buildContent(c.footer)],
      ],
    ),
  );
}

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
      boxShadow: t.shadowLg,
      border: .all(borderColor: t.borderColor),
      fontSize: 14,
      lineHeight: 1.6,
      color: t.textColor,
      iconColor: t.primary,
      iconSize: 20,
    ).merge(c.style),
    child: Row(
      mainAxisSize: .min,
      children: [
        if (c.icon != null) ...[buildContent(c.icon), const SizedBox(width: 12)],
        Flexible(child: buildContent(c.child)),
      ],
    ),
  );
}
