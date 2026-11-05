import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 比较禁用按钮与可开始、结束的加载状态。
class ButtonStatesExample extends HookWidget {
  const ButtonStatesExample({super.key});

  @override
  Widget build(BuildContext context) {
    final loading = useState(false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: .center,
      children: [
        ElButton(type: .primary, disabled: true, onPressed: () {}, child: '禁用按钮'),
        ElButton(type: .primary, loading: loading.value, onPressed: () => loading.value = true, child: '提交'),
        ElButton(variant: .outline, disabled: !loading.value, onPressed: () => loading.value = false, child: '结束加载'),
      ],
    );
  }
}
