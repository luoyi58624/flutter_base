import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动弹层提供内容框架，路由生命周期由公共层持有。
Widget popupBuilder(BuildContext context, ElPopup c) => _panel(context, c);

/// 移动确认框沿用同一内容结构并收紧宽度。
Widget dialogBuilder(BuildContext context, ElDialog c) => _panel(context, c);

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
