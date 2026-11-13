import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 卡片里可以放按钮、输入框等交互组件；ElPopupController 在内容中主动关闭，onOpenChanged 回调开闭状态。
class Example2 extends HookWidget {
  /// 创建交互内容示例。
  Example2({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(ElPopupController.new);
    useEffect(() => controller.dispose, []);
    final open = useState(false);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: .center,
      children: [
        ElPopover(
          controller: controller,
          width: 240,
          onOpenChanged: (value) => open.value = value,
          content: Column(
            crossAxisAlignment: .stretch,
            spacing: 12,
            children: [
              ElView(child: '删除后无法恢复，确定删除这条记录吗？'),
              Row(
                mainAxisAlignment: .end,
                spacing: 8,
                children: [
                  ElButton(onPressed: controller.close, child: '取消'),
                  ElButton(
                    type: .error,
                    onPressed: () {
                      controller.close();
                      el.message.show('已删除', context: context);
                    },
                    child: '删除',
                  ),
                ],
              ),
            ],
          ),
          child: ElButton(type: .error, child: '删除记录'),
        ),
        ElView(child: open.value ? '弹出框已打开' : '弹出框已关闭'),
      ],
    );
  }
}
