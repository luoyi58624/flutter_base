import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 普通分组只组织内容，不管理选中值。
class Example1 extends HookWidget {
  /// 创建普通分组示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final count = useState(0);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElListGroup(
          title: '账户设置',
          children: [
            ElListTile(title: '个人资料', leading: Icon(Icons.person_outline), onTap: () => count.value++),
            ElListTile(title: '隐私设置', onTap: () => count.value++),
          ],
        ),
        Text('已操作 ${count.value} 次'),
      ],
    );
  }
}
