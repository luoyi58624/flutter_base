import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 在可点击卡片中展示真实的鼠标文件框选。
class ElBoxSelectionSceneExample extends HookWidget {
  /// 创建鼠标框选与卡片点击示例。
  // ignore: prefer_const_constructors_in_immutables
  ElBoxSelectionSceneExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = useMemoized(ElBoxSelectionController.new);
    useEffect(() => controller.dispose, [controller]);
    useListenable(controller);
    final opens = useState(0), moves = useState(0);
    final pressed = useState(false);
    final fileColors = [Colors.blue, Colors.orange, Colors.teal, Colors.purple, Colors.pink, Colors.indigo];

    return ElCard(
      key: ValueKey('event-box-card'),
      style: .new(padding: .all(12), borderRadius: .circular(20)),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 8,
        children: [
          ElView(
            key: ValueKey('event-box-area'),
            style: .new(
              height: 202,
              borderRadius: .circular(14),
              backgroundColor: colors.surfaceContainerLow,
              onTap: .new(backgroundColor: colors.surfaceContainerHighest),
            ),
            event: ElEvent(
              onTapDown: (_) => pressed.value = true,
              onTapUp: (_) => pressed.value = false,
              onTapCancel: (_) => pressed.value = false,
              onTap: (_) => opens.value++,
              onPointerMove: (_) => moves.value++,
            ),
            child: ElBoxSelectionView(
              controller: controller,
              selectionColor: colors.primary.withValues(alpha: .18),
              child: Padding(
                padding: .all(16),
                child: Column(
                  spacing: 12,
                  children: [
                    for (var row = 0; row < 2; row++)
                      Row(
                        spacing: 10,
                        children: [
                          for (var column = 0; column < 3; column++)
                            Expanded(
                              child: ElBoxSelectable(
                                key: ValueKey('event-box-file-${row * 3 + column + 1}'),
                                value: row * 3 + column + 1,
                                style: .new(
                                  height: 64,
                                  borderRadius: .circular(10),
                                  border: .all(borderColor: Colors.transparent),
                                  backgroundColor: fileColors[row * 3 + column].withValues(alpha: .15),
                                ),
                                selectedStyle: .new(
                                  border: .all(borderColor: colors.primary),
                                  backgroundColor: colors.primaryContainer,
                                ),
                                child: Column(
                                  mainAxisAlignment: .center,
                                  spacing: 4,
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file_rounded,
                                      color: fileColors[row * 3 + column],
                                      size: 25,
                                    ),
                                    Text('文件 ${row * 3 + column + 1}', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: Text('已选 ${controller.selectedCount} / 6', key: ValueKey('event-box-selected'))),
              TextButton(key: ValueKey('event-box-clear'), onPressed: controller.clear, child: Text('清空')),
            ],
          ),
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('打开 ${opens.value}', key: ValueKey('event-box-opens')),
                Text(pressed.value ? '按压中' : '已松开', key: ValueKey('event-box-pressed')),
                Text('原始 Move ${moves.value}', key: ValueKey('event-box-moves')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
