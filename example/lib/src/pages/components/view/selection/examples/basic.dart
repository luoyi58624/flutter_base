import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 演示跨段落选择和清空选区。
class ElSelectionExample extends HookWidget {
  /// 创建文本选择示例。
  // ignore: prefer_const_constructors_in_immutables
  ElSelectionExample({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(ElSelectionController.new);
    useEffect(() => controller.dispose, [controller]);
    final selectedText = useValueNotifier<String?>(null);

    return Column(
      crossAxisAlignment: .stretch,
      spacing: 16,
      children: [
        ElSelectionView(
          key: ValueKey('selection-area'),
          controller: controller,
          onSelectionChanged: (text) => selectedText.value = text,
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: 12,
            children: [
              Text('清晨，沿湖的步道还很安静。晨风拂过水面，芦苇轻轻摇动，几只白鹭停在浅水里。', key: ValueKey('selection-paragraph-1')),
              Text('走到木桥时，太阳已经升过树梢。桥下的水流缓慢，远处的山影渐渐清晰起来。', key: ValueKey('selection-paragraph-2')),
            ],
          ),
        ),
        Wrap(
          crossAxisAlignment: .center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('当前选中文字', style: Theme.of(context).textTheme.labelLarge),
            ElButton(key: ValueKey('selection-clear'), onPressed: controller.clear, child: '清空选区'),
          ],
        ),
        ValueListenableBuilder<String?>(
          valueListenable: selectedText,
          builder: (context, text, _) => Text(text ?? '尚未选中文字', key: ValueKey('selection-result')),
        ),
      ],
    );
  }
}
