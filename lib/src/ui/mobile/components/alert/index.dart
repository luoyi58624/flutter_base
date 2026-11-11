import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动通知条通过已有模型控制关闭，语义色随主题级联。
Widget alertBuilder(BuildContext context, ElAlert c) {
  if (!c.currentValue) return const SizedBox.shrink();
  final t = context.elTheme;
  final accent = switch (c.type) {
    .success => t.success,
    .warning => t.warning,
    .error => t.error,
    _ => t.primary,
  };
  final icon = c.icon is ElEmptyWidget
      ? switch (c.type) {
          .success => ElMobileIcons.check,
          .warning => ElMobileIcons.alertTriangle,
          .error => ElMobileIcons.alertCircle,
          _ => ElMobileIcons.info,
        }
      : c.icon;
  return ElView(
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    style: ElStyle(
      padding: const .all(16),
      borderRadius: .circular(16),
      backgroundColor: Color.alphaBlend(accent.withValues(alpha: .08), t.cardColor),
      border: .all(borderColor: accent.withValues(alpha: .18)),
    ).merge(c.style),
    child: Row(
      crossAxisAlignment: .start,
      children: [
        if (icon != null) ...[
          ElView(
            style: ElStyle(iconSize: 20, iconColor: accent),
            child: icon,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            spacing: 5,
            children: [
              if (c.title != null)
                ElView(
                  style: ElStyle(fontSize: 14, fontWeight: .w600, color: t.textColor),
                  child: c.title,
                ),
              if (c.description != null)
                ElView(
                  style: ElStyle(fontSize: 13, lineHeight: 1.7, color: t.textSecondary),
                  child: c.description,
                ),
            ],
          ),
        ),
        if (c.closable)
          ActionView(
            label: '关闭通知',
            style: ElStyle(width: 28, height: 28, alignment: .center, iconSize: 16, iconColor: t.textSecondary),
            onActivate: (_) {
              c.currentValue = false;
              c.onClose?.call();
            },
            child: ElMobileIcons.x,
          ),
      ],
    ),
  );
}
