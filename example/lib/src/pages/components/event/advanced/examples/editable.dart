import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 在可点击卡片内编辑和选择文字，展示外层真实按压状态。
class ElEditableSelectionExample extends HookWidget {
  /// 创建编辑选区与按压示例。
  // ignore: prefer_const_constructors_in_immutables
  ElEditableSelectionExample({super.key});

  static final _initialText = [
    '周末出行清单',
    '带上水杯、雨伞和一本书。',
    '上午沿湖散步，观察水边的鸟。',
    '中午在街角的小店吃饭。',
    '下午去书店，挑一本喜欢的书。',
    '在明信片上写下今天的天气。',
    '傍晚沿原路慢慢回家。',
    '整理照片，记下最喜欢的风景。',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(() => ElEditableController(text: _initialText));
    useEffect(() => controller.dispose, [controller]);
    final focusNode = useFocusNode();
    final opens = useValueNotifier(0);
    final moves = useValueNotifier(0);
    final colors = Theme.of(context).colorScheme;

    return ElEventDemoSurface(
      height: 320,
      footer: Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, child) => Column(
                crossAxisAlignment: .start,
                spacing: 4,
                children: [
                  Text(
                    '选区 ${controller.selection.start}–${controller.selection.end}',
                    key: ValueKey('advanced-editable-range'),
                  ),
                  Text(
                    controller.selectedText.isEmpty ? '—' : controller.selectedText,
                    key: ValueKey('advanced-editable-result'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey('advanced-editable-reset'),
            tooltip: '复位',
            onPressed: () {
              focusNode.unfocus();
              controller.text = _initialText;
              controller.collapseTo(0);
              opens.value = moves.value = 0;
            },
            icon: Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      child: Padding(
        padding: .all(12),
        child: ElCard(
          style: .new(padding: .all(12), borderRadius: .circular(18)),
          child: ElView(
            key: ValueKey('advanced-editable-outer'),
            style: .new(
              width: '100%',
              onTap: .new(backgroundColor: colors.primaryContainer),
            ),
            event: ElEvent(onTap: (_) => opens.value++, onPointerMove: (_) => moves.value++),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('出行备忘', key: ValueKey('advanced-editable-header'))),
                    Builder(
                      builder: (context) => Text(
                        ElView.of(context).hasTap ? '按下' : '松开',
                        key: ValueKey('advanced-editable-pressed'),
                        style: TextStyle(color: colors.primary),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 200,
                  child: ElEditableView(
                    key: ValueKey('advanced-editable-editor'),
                    controller: controller,
                    focusNode: focusNode,
                    style: ElEditableStyle(
                      view: .new(fontSize: 16, backgroundColor: colors.surface, borderRadius: .circular(10)),
                      contentPadding: .all(12),
                      retainSelectionOnBlur: true,
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: Listenable.merge([opens, moves]),
                  builder: (context, child) => Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text('打开 ${opens.value}', key: ValueKey('advanced-editable-opens')),
                      Text('外层移动 ${moves.value}', key: ValueKey('advanced-editable-moves')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
