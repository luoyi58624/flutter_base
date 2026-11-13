import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// show 打开自定义内容，内容里用 Navigator.pop(context, value) 返回结果；遮罩、Esc 和返回键关闭时得到 null。
class Example1 extends StatelessWidget {
  /// 创建基础对话框示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElButton(
          onPressed: () =>
              el.dialog.show(context, title: '提示', showClose: true, child: '点击遮罩、按 Esc 或右上角的关闭按钮都可以关闭对话框。'),
          child: '打开对话框',
        ),
        ElButton(
          type: .primary,
          onPressed: () async {
            final plan = await el.dialog.show<String>(
              context,
              title: '选择套餐',
              child: '不同套餐的存储空间和协作人数不同，选择后可随时升级。',
              footer: Builder(
                builder: (context) => Row(
                  mainAxisAlignment: .end,
                  spacing: 12,
                  children: [
                    ElButton(onPressed: () => Navigator.pop(context, '基础版'), child: '基础版'),
                    ElButton(type: .primary, onPressed: () => Navigator.pop(context, '专业版'), child: '专业版'),
                  ],
                ),
              ),
            );
            if (context.mounted) el.message.show(plan == null ? '未选择套餐' : '已选择$plan', context: context);
          },
          child: '返回结果',
        ),
      ],
    );
  }
}
