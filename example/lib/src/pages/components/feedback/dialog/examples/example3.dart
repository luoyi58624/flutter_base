import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// prompt 确认或回车时先经 validator 校验，错误提示留在面板内；确认得到输入值，取消得到 null。
class Example3 extends HookWidget {
  /// 创建输入框示例。
  Example3({super.key});

  @override
  Widget build(BuildContext context) {
    final name = useState('未命名项目');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: .center,
      children: [
        ElButton(
          onPressed: () async {
            final value = await el.dialog.prompt(
              context,
              title: '重命名项目',
              content: '名称最多 20 个字符。',
              value: name.value,
              placeholder: '输入项目名称',
              validator: (value) => switch (value.trim()) {
                '' => '名称不能为空',
                final text when text.length > 20 => '名称最多 20 个字符',
                _ => null,
              },
            );
            if (value != null) name.value = value.trim();
          },
          child: '重命名',
        ),
        ElView(child: '当前名称：${name.value}'),
      ],
    );
  }
}
