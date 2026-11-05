import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 用 ValueNotifier 绑定切换按钮的选中值。
class ButtonToggleExample extends HookWidget {
  const ButtonToggleExample({super.key});

  @override
  Widget build(BuildContext context) {
    final favorite = useState(false);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: .center,
      children: [
        ElButton.toggle(
          type: .primary,
          modelValue: favorite,
          icon: favorite.value ? Icons.favorite : Icons.favorite_border,
          child: '收藏',
        ),
        Text(favorite.value ? '已收藏' : '未收藏'),
      ],
    );
  }
}
