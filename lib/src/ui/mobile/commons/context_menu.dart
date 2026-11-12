import 'package:flutter/widgets.dart';

import '../../../../flutter.dart';
import 'icons.dart';

/// 复用现有上下文菜单机制的移动品牌皮肤。
class ElMobileContextMenu extends ElContextMenu {
  /// 创建可供 el.showContextMenu 使用的菜单外观。
  const ElMobileContextMenu();

  @override
  bool get touchSelection => true;

  @override
  Widget buildPanel(BuildContext context, List<Widget> children) => ElCard(
    style: ElStyle(
      width: 248,
      maxHeight: MediaQuery.sizeOf(context).height * .7,
      padding: const .all(6),
      borderRadius: .circular(18),
      border: .all(borderColor: context.elTheme.borderColor),
      boxShadow: context.elTheme.shadowLg,
    ),
    child: SingleChildScrollView(
      child: Column(mainAxisSize: .min, crossAxisAlignment: .stretch, children: children),
    ),
  );
  @override
  ElStyle buildItemStyle(BuildContext context, ElContextMenuItem item) => ElStyle(
    minHeight: 44,
    padding: const .symmetric(horizontal: 12, vertical: 10),
    borderRadius: .circular(11),
    fontSize: 14,
    color: item.enabled ? context.elTheme.textColor : context.elTheme.textDisabled,
    iconColor: item.enabled ? context.elTheme.textSecondary : context.elTheme.textDisabled,
    iconSize: 18,
    onTap: ElStyle(backgroundColor: context.elTheme.press),
  );
  @override
  Widget buildItemContent(BuildContext context, ElContextMenuItem item) => Row(
    spacing: 10,
    children: [
      if (item.icon != null) buildIcon(context, item.icon)!,
      Expanded(child: ElView(child: item.label)),
      if (item.hasChildren) ElMobileIcons.chevronRight else if (item.checked == true) ElMobileIcons.check,
    ],
  );
  @override
  Widget buildDivider(BuildContext context) => ElView(
    style: ElStyle(
      height: 1,
      margin: const .symmetric(horizontal: 10, vertical: 5),
      backgroundColor: context.elTheme.borderColor,
    ),
  );
}
