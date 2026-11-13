import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// trigger 可组合 click、hover、focus 与 contextMenu；悬停延迟由 hoverIntent 控制，斜向移入卡片途中不会关闭。
class Example1 extends HookWidget {
  /// 创建触发方式示例。
  Example1({super.key});

  @override
  Widget build(BuildContext context) {
    final keyword = useState('');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: .center,
      children: [
        ElPopover(
          title: '点击触发',
          content: '再次点击目标或点击外部关闭。',
          child: ElButton(child: '点击'),
        ),
        ElPopover(
          trigger: {.hover},
          hoverIntent: ElHoverIntent(openDelay: Duration(milliseconds: 300)),
          title: '悬停触发',
          content: '悬停 300 毫秒后打开，移入卡片保持打开；触摸设备上点击切换。',
          child: ElButton(child: '悬停'),
        ),
        ElPopover(
          trigger: {.focus},
          placement: .right,
          content: '输入框获得焦点时打开，焦点离开后关闭。',
          child: SizedBox(width: 200, child: ElInput(modelValue: keyword, placeholder: '聚焦时显示')),
        ),
        ElPopover(
          trigger: {.contextMenu},
          placement: .bottomStart,
          content: '在右键或长按的位置打开。',
          child: ElButton(child: '右键 / 长按'),
        ),
      ],
    );
  }
}
