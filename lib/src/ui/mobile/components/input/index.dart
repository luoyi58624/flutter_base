import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../../desktop/components/input/index.dart' as core;
import '../../commons/icons.dart';

/// 移动输入只换外观，IME、选区、清除、密码与表单继续使用现有编辑内核。
Widget inputBuilder(BuildContext context, ElInput c) {
  final t = context.elTheme;
  return core.Input(
    c,
    ElStyle(
      width: '100%',
      height: c.textarea ? null : 44,
      padding: .symmetric(horizontal: 14, vertical: c.textarea ? 12 : 1),
      borderRadius: .circular(12),
      backgroundColor: t.fill,
      color: c.disabled ? t.textDisabled : t.textColor,
      iconColor: t.textSecondary,
      fontSize: 14,
      lineHeight: 1.5,
      boxShadow: const [],
      border: .only(),
      onHover: const ElStyle(boxShadow: []),
      onFocusWithin: ElStyle(
        boxShadow: [BoxShadow(color: t.primary.withValues(alpha: .12), spreadRadius: 3)],
        border: .all(borderColor: t.primary),
      ),
    ),
    affixGap: 8,
    clearIcon: ElMobileIcons.x,
    passwordIcon: ElMobileIcons.eyeOff,
    passwordVisibleIcon: ElMobileIcons.eye,
  );
}

/// 移动表单项复用字段注册与校验，只提供品牌文字。
Widget formItemBuilder(BuildContext context, ElFormItem c) => ElFormItemView(
  component: c,
  labelStyle: ElStyle(fontSize: 13, fontWeight: .w500, color: context.elTheme.textColor),
  errorStyle: ElStyle(fontSize: 12, color: context.elTheme.error),
);
