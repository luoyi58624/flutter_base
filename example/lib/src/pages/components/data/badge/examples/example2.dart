import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// hidden 保留宿主内容，showZero 控制零值徽标。
class Example2 extends HookWidget {
  /// 创建条件显示示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final hidden = useState(false);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 16,
      children: [
        ElSwitch(modelValue: hidden, semanticLabel: '隐藏徽标'),
        Padding(
          padding: .all(12),
          child: ElBadge(
            value: 5,
            hidden: hidden.value,
            bgColor: Colors.red,
            child: Icon(Icons.shopping_cart_outlined, size: 32),
          ),
        ),
        ElBadge(value: 0, showZero: false, bgColor: Colors.red, child: Text('零值时隐藏')),
      ],
    );
  }
}
