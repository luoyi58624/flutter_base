import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 让列表行共享开关模型，并演示加载时阻止切换。
class Example5 extends HookWidget {
  /// 创建开关列表行示例。
  Example5({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = useState(false);
    final syncing = useState(false);
    final loading = useState(false);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        ElListGroup(
          children: [
            ElListTile<bool>.switcher(title: '消息通知', leading: Icons.notifications_none, modelValue: notifications),
            ElListTile<bool>.switcher(title: '同步通知', subtitle: '与上一行共用同一个值', modelValue: notifications),
            ElListTile<bool>.switcher(
              title: '云端同步',
              modelValue: syncing,
              loading: loading.value,
              switchStyle: ElStyle(height: 24),
            ),
          ],
        ),
        Text(notifications.value ? '通知已开启' : '通知已关闭'),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: .center,
          children: [
            ElSwitch(modelValue: loading, semanticLabel: '加载中的开关'),
            Text('显示加载状态'),
          ],
        ),
      ],
    );
  }
}
