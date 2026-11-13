import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// trigger 为 contextMenu 时在右键或长按的位置展开；再次右键会移动到新位置。
class Example3 extends StatelessWidget {
  /// 创建右键菜单示例。
  Example3({super.key});

  @override
  Widget build(BuildContext context) {
    void show(String action) => el.message.show(action, context: context);
    return ElPopupMenu(
      trigger: {.contextMenu},
      items: [
        ElContextMenuItem(label: '新建文件', shortcut: 'Ctrl+N', onSelect: () => show('新建文件')),
        ElContextMenuItem(label: '新建文件夹', onSelect: () => show('新建文件夹')),
        ElContextMenuItem.divider(),
        ElContextMenuItem(label: '刷新', shortcut: 'F5', onSelect: () => show('刷新')),
      ],
      child: ElCard(
        style: ElStyle(height: 160),
        child: Center(
          child: ElView(style: ElStyle(color: context.elTheme.textSecondary), child: '在此区域右键或长按'),
        ),
      ),
    );
  }
}
