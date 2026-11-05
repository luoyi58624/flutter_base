import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 通过行样式调整主题色、背景、圆角和内边距。
class Example8 extends HookWidget {
  /// 创建自定义样式示例。
  Example8({super.key});

  @override
  Widget build(BuildContext context) {
    final count = useState(0);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        ElListTile(
          title: '重要提醒',
          subtitle: '有新的消息等你查看',
          leading: Icons.campaign_outlined,
          trailingText: '新内容',
          trailing: null,
          style: ElStyle(
            color: context.elTheme.primary,
            iconColor: context.elTheme.primary,
            backgroundColor: context.elTheme.selectedBackground,
            borderRadius: .circular(12),
            padding: .symmetric(vertical: 20),
          ),
        ),
        ElListTile(
          title: '清理缓存',
          subtitle: '点击体验操作反馈',
          leading: Icons.delete_outline,
          trailing: null,
          style: ElStyle(
            color: context.elTheme.error,
            iconColor: context.elTheme.error,
            backgroundColor: context.elTheme.cardColor,
            borderRadius: .circular(12),
          ),
          onTap: () => count.value++,
        ),
        Text('已清理 ${count.value} 次'),
      ],
    );
  }
}
