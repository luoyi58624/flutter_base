import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// child 可提供文字或自定义 Widget。
class Example2 extends HookWidget {
  /// 创建可见说明示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 16,
      children: [
        ElLoadingIndicator(child: '正在加载，请稍候'),
        ElLoadingIndicator(size: 20, semanticLabel: '同步数据中', child: Text('正在同步数据')),
      ],
    );
  }
}
