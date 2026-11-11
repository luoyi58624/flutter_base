import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动端空态为正文、重试和自定义操作保留自然高度。
Widget emptyBuilder(BuildContext context, ElEmpty c) {
  final t = context.elTheme;
  return ElView(
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    style: ElStyle(padding: const .symmetric(horizontal: 20, vertical: 30)).merge(c.style),
    child: Column(
      mainAxisSize: .min,
      children: [
        ElView(
          style: ElStyle(
            width: 68,
            height: 68,
            alignment: .center,
            iconSize: 30,
            iconColor: t.primary,
            backgroundColor: t.fill,
            borderRadius: .circular(23),
          ),
          child: c.icon ?? (c.state == .error ? ElMobileIcons.alertCircle : ElMobileIcons.inbox),
        ),
        const SizedBox(height: 16),
        ElView(
          style: ElStyle(fontSize: 15, fontWeight: .w600, color: t.textColor),
          child: c.title ?? (c.state == .error ? '暂时无法加载' : '这里还没有内容'),
        ),
        if (c.description != null) ...[
          const SizedBox(height: 8),
          ElView(
            style: ElStyle(fontSize: 13, lineHeight: 1.7, textAlign: .center, color: t.textSecondary),
            child: c.description,
          ),
        ],
        if (c.child != null) ...[const SizedBox(height: 20), buildContent(c.child)],
      ],
    ),
  );
}
