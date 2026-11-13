import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// duration 为零时保留到 close；连续显示时新提示替换当前提示。
class Example2 extends HookWidget {
  /// 创建常驻与替换示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final count = useState(0);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElButton(
          onPressed: () => el.toast.show('正在同步…', context: context, duration: Duration.zero),
          child: '常驻提示',
        ),
        ElButton(onPressed: el.toast.close, child: '关闭提示'),
        ElButton(
          onPressed: () => el.toast.show('第 ${++count.value} 条提示', context: context),
          child: '连续显示',
        ),
      ],
    );
  }
}
