import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 带 children 的条目悬停 150 毫秒展开子菜单，斜向移入子菜单途中不收起，桌面端按右键展开、左键收起；悬停触发的菜单按 hoverIntent 延迟打开且不抢焦点。
class Example4 extends HookWidget {
  /// 创建多级菜单示例。
  Example4({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = useState(true);
    final ruler = useState(false);
    void show(String action) => el.message.show(action, context: context);
    final items = [
      ElContextMenuItem(label: '显示网格', checked: grid.value, onSelect: () => grid.value = !grid.value),
      ElContextMenuItem(label: '显示标尺', checked: ruler.value, onSelect: () => ruler.value = !ruler.value),
      ElContextMenuItem.divider(),
      ElContextMenuItem(
        label: '导出为',
        children: [
          ElContextMenuItem(label: 'PNG 图片', onSelect: () => show('导出 PNG')),
          ElContextMenuItem(label: 'PDF 文档', onSelect: () => show('导出 PDF')),
          ElContextMenuItem(
            label: '更多格式',
            children: [
              ElContextMenuItem(label: 'SVG', onSelect: () => show('导出 SVG')),
              ElContextMenuItem(label: 'WebP', onSelect: () => show('导出 WebP')),
            ],
          ),
        ],
      ),
      ElContextMenuItem(
        label: '分享到',
        children: [
          ElContextMenuItem(label: '团队空间', onSelect: () => show('分享到团队空间')),
          ElContextMenuItem(label: '复制链接', onSelect: () => show('复制链接')),
        ],
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElPopupMenu(
          items: items,
          child: ElButton(child: '点击打开'),
        ),
        ElPopupMenu(
          trigger: {.hover},
          hoverIntent: ElHoverIntent(openDelay: Duration(milliseconds: 300)),
          items: items,
          child: ElButton(child: '悬停 300 毫秒打开'),
        ),
      ],
    );
  }
}
