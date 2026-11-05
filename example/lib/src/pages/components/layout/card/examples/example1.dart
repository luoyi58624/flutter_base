import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 卡片内自由组合内容，通过 onTap 响应整卡点击。
class Example1 extends HookWidget {
  /// 创建内容与点击示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final count = useState(0);
    return ElCard(
      onTap: () => count.value++,
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        spacing: 8,
        children: [
          Text('可点击卡片', style: Theme.of(context).textTheme.titleMedium),
          Text('已点击 ${count.value} 次'),
        ],
      ),
    );
  }
}
