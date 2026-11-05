import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';

/// 从单选菜单回写业务值，并展示可空的初始选择。
class Example6 extends HookWidget {
  /// 创建弹出单选菜单示例。
  Example6({super.key});

  @override
  Widget build(BuildContext context) {
    final sort = useState('latest');
    final group = useState<String?>(null);
    final labels = {'latest': '最新发布', 'earliest': '最早发布', 'popular': '最多收藏'};

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        ElListGroup(
          children: [
            ElListTile<String>.popup(
              title: '排序方式',
              modelValue: sort,
              popupAnchor: ElOverlayAnchor(placement: .bottomStart, offset: 4),
              options: [
                ElLabelModel('最新发布', 'latest'),
                ElLabelModel('最早发布', 'earliest'),
                ElLabelModel('最多收藏', 'popular'),
              ],
            ),
            ElListTile<String?>.popup(
              title: '默认分组',
              modelValue: group,
              trailingText: group.value == null ? '请选择' : null,
              options: [ElLabelModel('工作', 'work'), ElLabelModel('生活', 'life')],
            ),
          ],
        ),
        Text('当前排序：${labels[sort.value]}'),
      ],
    );
  }
}
