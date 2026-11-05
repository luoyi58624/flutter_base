import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 选中值双向绑定，关闭回调由调用方决定是否移除标签。
class Example2 extends HookWidget {
  /// 创建切换与关闭示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = useState(false);
    final visible = useState(true);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: .center,
      children: [
        ElTag.toggle(modelValue: selected, child: selected.value ? '已选中' : '未选中'),
        if (visible.value) ElTag(closable: true, onClose: () => visible.value = false, child: '可关闭'),
        ElButton(onPressed: () => visible.value = true, child: '恢复标签'),
      ],
    );
  }
}
