import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 选择条目后整条菜单先关闭再执行 onSelect；placement 决定展开方位，靠近边缘时自动翻转。桌面端打开后可用方向键切换、回车选择、Esc 关闭。
class Example1 extends StatelessWidget {
  /// 创建下拉菜单示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    void show(String action) => el.message.show(action, context: context);
    List<ElContextMenuItem> items() => [
      ElContextMenuItem(label: '编辑', icon: Icons.edit_outlined, shortcut: 'Ctrl+E', onSelect: () => show('编辑')),
      ElContextMenuItem(label: '复制链接', icon: Icons.link, shortcut: 'Ctrl+L', onSelect: () => show('复制链接')),
      ElContextMenuItem(label: '移动到', icon: Icons.drive_file_move_outline, enabled: false),
      ElContextMenuItem.divider(),
      ElContextMenuItem(label: '删除', icon: Icons.delete_outline, onSelect: () => show('删除')),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElPopupMenu(
          items: items(),
          child: ElButton(child: '下方左对齐'),
        ),
        ElPopupMenu(
          placement: .bottomEnd,
          items: items(),
          child: ElButton(child: '下方右对齐'),
        ),
        ElPopupMenu(
          placement: .top,
          items: items(),
          child: ElButton(child: '上方居中'),
        ),
        ElPopupMenu(
          placement: .rightStart,
          items: items(),
          child: ElButton(child: '右侧'),
        ),
      ],
    );
  }
}
