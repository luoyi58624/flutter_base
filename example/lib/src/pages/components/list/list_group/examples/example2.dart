import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 条目 value 对应完整单值模型。
class Example2 extends HookWidget {
  /// 创建单选分组示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState<String?>('标准');
    return ElListGroup<String?>.single(
      modelValue: selected,
      title: '显示密度',
      children: [
        for (final item in ['紧凑', '标准', '宽松']) ElListTile<String>(value: item, title: item),
      ],
    );
  }
}
