import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 在可点击资料卡内选择正文，观察外层事件与真实选区。
class ElSelectionClaimExample extends HookWidget {
  /// 创建文本选择与外层点击示例。
  // ignore: prefer_const_constructors_in_immutables
  ElSelectionClaimExample({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(ElSelectionController.new);
    useEffect(() => controller.dispose, [controller]);
    final opens = useValueNotifier(0);
    final moves = useValueNotifier(0);
    final colors = Theme.of(context).colorScheme;

    return ElEventDemoSurface(
      height: 300,
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
                  Text('选中文字'),
                  Text(controller.text ?? '—', key: ValueKey('advanced-selection-result'), maxLines: 3),
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey('advanced-selection-reset'),
            tooltip: '复位',
            onPressed: () {
              controller.clear();
              opens.value = moves.value = 0;
            },
            icon: Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      child: Padding(
        padding: .all(12),
        child: ElCard(
          style: .new(padding: .all(16), borderRadius: .circular(18)),
          child: ElView(
            key: ValueKey('advanced-selection-outer'),
            style: .new(
              height: 240,
              width: '100%',
              onTap: .new(backgroundColor: colors.primaryContainer),
            ),
            event: ElEvent(onTap: (_) => opens.value++, onPointerMove: (_) => moves.value++),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 12,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('湖边手记', key: ValueKey('advanced-selection-header'))),
                    Builder(
                      builder: (context) => Text(
                        ElView.of(context).hasTap ? '按下' : '松开',
                        key: ValueKey('advanced-selection-pressed'),
                        style: TextStyle(color: colors.primary),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ElSelectionView(
                    key: ValueKey('advanced-selection-area'),
                    controller: controller,
                    child: ElView(
                      key: ValueKey('advanced-selection-text'),
                      style: .new(alignment: .topLeft, fontSize: 16, userSelect: .text),
                      child: '清晨的湖边很安静。风从水面吹来，芦苇轻轻摇动。\n下午去书店，挑一本喜欢的书。',
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: Listenable.merge([opens, moves]),
                  builder: (context, child) => Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text('打开 ${opens.value}', key: ValueKey('advanced-selection-opens')),
                      Text('外层移动 ${moves.value}', key: ValueKey('advanced-selection-moves')),
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
