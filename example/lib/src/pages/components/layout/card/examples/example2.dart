import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 加载时保留内容，style 在品牌默认样式之后合并。
class Example2 extends HookWidget {
  /// 创建加载与样式示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final loading = useState(true);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        ElSwitch(modelValue: loading, semanticLabel: '卡片加载状态'),
        ElCard(
          loading: loading.value,
          style: ElStyle(borderRadius: .circular(16)),
          child: Text('这段内容在加载结束后继续显示。'),
        ),
      ],
    );
  }
}
