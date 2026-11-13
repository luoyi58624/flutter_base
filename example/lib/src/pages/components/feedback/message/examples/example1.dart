import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// type 决定颜色和图标。
class Example1 extends StatelessWidget {
  /// 创建消息类型示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElButton(
          onPressed: () => el.message.show('这是一条消息', context: context),
          child: '消息',
        ),
        ElButton(
          type: .success,
          onPressed: () => el.message.show('保存成功', context: context, type: .success),
          child: '成功',
        ),
        ElButton(
          type: .warning,
          onPressed: () => el.message.show('网络不稳定，请稍后重试', context: context, type: .warning),
          child: '警告',
        ),
        ElButton(
          type: .error,
          onPressed: () => el.message.show('提交失败', context: context, type: .error),
          child: '错误',
        ),
        ElButton(
          type: .primary,
          onPressed: () => el.message.show('有新的版本可用', context: context, type: .primary),
          child: '主要',
        ),
      ],
    );
  }
}
