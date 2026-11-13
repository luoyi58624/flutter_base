import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// duration 调整停留时长，为零时保留到用户关闭；连续显示时多条消息同时存在。
class Example2 extends HookWidget {
  /// 创建时长与多条消息示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final count = useState(0);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElButton(
          onPressed: () => el.message.show('这条消息停留 10 秒', context: context, duration: Duration(seconds: 10)),
          child: '停留 10 秒',
        ),
        ElButton(
          onPressed: () => el.message.show('常驻消息，点击关闭', context: context, duration: Duration.zero),
          child: '常驻消息',
        ),
        ElButton(
          onPressed: () => el.message.show('第 ${++count.value} 条消息', context: context),
          child: '连续显示',
        ),
      ],
    );
  }
}
