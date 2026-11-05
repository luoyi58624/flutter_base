import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// ElTabBar 与 ElTabView 共用现有 ElTabController，并由示例释放。
class Example2 extends HookWidget {
  /// 创建独立标签栏与视口示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(() => ElTabController(length: 2));
    useEffect(() => controller.dispose, [controller]);
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        ElTabBar(
          controller: controller,
          tabs: [
            ElTabItem(label: '消息', icon: Icon(Icons.chat_bubble_outline)),
            ElTabItem(label: '设置', icon: Icon(Icons.settings)),
          ],
        ),
        SizedBox(
          height: 160,
          child: ElTabView(
            controller: controller,
            children: [
              Center(child: Text('消息内容')),
              Center(child: Text('设置内容')),
            ],
          ),
        ),
      ],
    );
  }
}
