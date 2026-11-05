import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 输入内容后按 Enter 或逗号提交，通过关闭按钮删除条目。
class Example1 extends HookWidget {
  /// 创建新增与移除示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final tags = useState<List<String>>(['Flutter', 'Dart']);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElInputTag(
          modelValue: tags,
          delimiter: ',',
          clearable: true,
          placeholder: '输入标签',
          style: ElStyle(width: '100%'),
        ),
        Text('当前标签：${tags.value.join('、')}'),
      ],
    );
  }
}
