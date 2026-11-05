import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';

/// 展示普通列表行和由调用方处理的点击动作。
class Example1 extends HookWidget {
  /// 创建基础列表行示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final count = useState(0);

    return ElListGroup(
      children: [
        ElListTile(title: '列表标题'),
        ElListTile(title: '点击计数', trailingText: '${count.value} 次', onTap: () => count.value++),
      ],
    );
  }
}
