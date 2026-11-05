import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照普通激活与被 preventDefault 拦截的激活。
class ButtonEventsExample extends HookWidget {
  const ButtonEventsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final clicks = useState(0);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: .center,
      children: [
        ElButton(type: .primary, onPressed: () => clicks.value++, child: '增加'),
        ElButton(
          variant: .outline,
          event: ElEvent(onTap: (event) => event.preventDefault()),
          onPressed: () => clicks.value++,
          child: '拦截点击',
        ),
        Text('点击次数：${clicks.value}'),
      ],
    );
  }
}
