import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// content 可以是任意 Widget；waitDuration 控制悬停延迟，arrow 控制箭头，disabled 停用提示。
class Example2 extends HookWidget {
  /// 创建内容与行为示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final disabled = useState(false);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: .center,
      children: [
        ElTooltip(
          content: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              ElView(
                style: ElStyle(fontWeight: .w600),
                child: '多行内容',
              ),
              ElView(child: '第二行说明文字'),
            ],
          ),
          child: ElButton(child: '多行内容'),
        ),
        ElTooltip(
          content: '立即显示，没有箭头',
          waitDuration: Duration.zero,
          arrow: false,
          child: ElButton(child: '无延迟'),
        ),
        ElTooltip(
          content: '停用后不再显示',
          disabled: disabled.value,
          child: ElButton(
            type: .primary,
            onPressed: () => disabled.value = !disabled.value,
            child: disabled.value ? '已停用，点击启用' : '点击停用提示',
          ),
        ),
      ],
    );
  }
}
