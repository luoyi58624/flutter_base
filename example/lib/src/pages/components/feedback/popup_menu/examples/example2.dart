import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// cover 为真时菜单从目标所在位置展开并盖住目标，例如标题栏右上角的溢出菜单；下方放不下时改为向上展开。
class Example2 extends StatelessWidget {
  /// 创建覆盖目标示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    void show(String action) => el.message.show(action, context: context);
    return ElCard(
      child: Row(
        children: [
          Expanded(
            child: ElView(
              style: ElStyle(fontSize: 16, fontWeight: .w600),
              child: '项目文档',
            ),
          ),
          ElPopupMenu(
            cover: true,
            placement: .bottomEnd,
            items: [
              ElContextMenuItem(label: '刷新', onSelect: () => show('刷新')),
              ElContextMenuItem(label: '分享', onSelect: () => show('分享')),
              ElContextMenuItem(label: '设置', onSelect: () => show('设置')),
            ],
            child: ElButton(variant: .text, child: Icons.more_vert),
          ),
        ],
      ),
    );
  }
}
