import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';

/// 标题栏皮肤以对称操作槽保证标题居中。
Widget appBarBuilder(BuildContext context, ElAppBar c) {
  final t = context.elTheme;
  final leading =
      c.leading ??
      (c.back
          ? ElButton(
              variant: .text,
              semanticLabel: '返回',
              style: const ElStyle(width: 44, padding: .zero),
              onPressed: c.onBack ?? () => Navigator.of(context).maybePop(),
              child: ElView(
                style: ElStyle(transform: ElTransform.rotate(3.14159265359)),
                child: ElMobileIcons.chevronRight,
              ),
            )
          : null);
  final title = ElView(
    style: ElStyle(textAlign: c.centerTitle ? .center : .start),
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: c.centerTitle ? .center : .start,
      spacing: 4,
      children: [
        ElView(
          style: const ElStyle(fontSize: 16, fontWeight: .w600),
          child: c.title,
        ),
        if (c.subtitle != null)
          ElView(
            style: ElStyle(fontSize: 11, color: t.textSecondary),
            child: c.subtitle,
          ),
      ],
    ),
  );
  return ElView(
    event: c.event,
    style: ElStyle(
      minHeight: 64,
      padding: const .symmetric(horizontal: 8),
      backgroundColor: t.cardColor,
      color: t.textColor,
      border: ElBorder.only(borderBottom: ElBorderSide(borderColor: t.borderColor)),
    ).merge(c.style),
    child: c.centerTitle
        ? Stack(
            alignment: .center,
            children: [
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  leading ?? const SizedBox(width: 44),
                  Row(mainAxisSize: .min, children: c.actions),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: (c.actions.length * 44.0).clamp(44, 132)),
                child: title,
              ),
            ],
          )
        : Row(
            children: [
              ?leading,
              Expanded(child: title),
              ...c.actions,
            ],
          ),
  );
}
