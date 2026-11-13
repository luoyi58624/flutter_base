import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// show 显示文字提示，可附带图标并调整停留时长。
class Example1 extends StatelessWidget {
  /// 创建基础用法示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElButton(
          onPressed: () => el.toast.show('已保存', context: context),
          child: '文字提示',
        ),
        ElButton(
          onPressed: () => el.toast.show(
            Row(mainAxisSize: .min, spacing: 8, children: [Icon(Icons.check_circle_outline), Text('收藏成功')]),
            context: context,
          ),
          child: '自定义内容',
        ),
        ElButton(
          onPressed: () => el.toast.show('内容较长时可以适当延长停留时间，确保用户读完。', context: context, duration: Duration(seconds: 4)),
          child: '停留 4 秒',
        ),
      ],
    );
  }
}
