import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 显示文案与业务值分别声明，选择后同步外部模型。
class Example1 extends HookWidget {
  /// 创建单值绑定示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final value = useState('beijing');
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSelect<String>(
          modelValue: value,
          hintText: '请选择城市',
          children: [ElLabelModel('北京', 'beijing'), ElLabelModel('上海', 'shanghai'), ElLabelModel('深圳', 'shenzhen')],
        ),
        Text('业务值：${value.value}'),
      ],
    );
  }
}
