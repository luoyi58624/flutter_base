import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 在可点击卡片中拖放文件，观察投放结果和外层按压的结束时机。
class ElDropInteractionExample extends HookWidget {
  /// 创建卡片拖放示例。
  // ignore: prefer_const_constructors_in_immutables
  ElDropInteractionExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final opened = useState(0);
    final received = useState(0);
    final pressed = useState(false);
    final phase = useState('就绪');
    final sequence = useState(<String>[]);

    void record(String event) => sequence.value = [...sequence.value, event];

    Widget file({bool preview = false}) => Container(
      key: preview ? null : ValueKey('advanced-drop-file'),
      width: preview ? 160 : null,
      height: 64,
      padding: .symmetric(horizontal: 14),
      decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: .circular(12)),
      child: Row(
        spacing: 10,
        children: [
          Icon(Icons.description_outlined, color: colors.onPrimaryContainer),
          Expanded(
            child: Text('项目计划', style: TextStyle(color: colors.onPrimaryContainer)),
          ),
          Icon(Icons.drag_indicator_rounded, color: colors.onPrimaryContainer, size: 18),
        ],
      ),
    );

    Widget target({required bool accepts}) => ElDropTarget<String>(
      canAccept: (_) => accepts,
      onDrop: (data, details) => received.value++,
      builder: (context, candidate) => ElCard(
        key: ValueKey(accepts ? 'advanced-drop-inbox' : 'advanced-drop-locked'),
        style: .new(
          padding: .all(10),
          backgroundColor: candidate == null
              ? colors.surface
              : accepts
              ? colors.tertiaryContainer
              : colors.errorContainer,
          border: .all(borderColor: candidate == null ? colors.outlineVariant : colors.primary),
        ),
        child: Column(
          mainAxisAlignment: .center,
          spacing: 8,
          children: [
            Icon(
              accepts ? Icons.move_to_inbox_outlined : Icons.lock_outline_rounded,
              color: accepts ? colors.primary : colors.onSurfaceVariant,
            ),
            Text(accepts ? '收件箱 ${received.value}' : '锁定区'),
          ],
        ),
      ),
    );

    return ElEventDemoSurface(
      height: 280,
      footer: Column(
        crossAxisAlignment: .stretch,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(child: Text(phase.value, key: ValueKey('advanced-drop-phase'))),
              Text('打开 ${opened.value}', key: ValueKey('advanced-drop-opened')),
              Text(pressed.value ? '按下' : '松开', key: ValueKey('advanced-drop-press')),
              ElButton(
                key: ValueKey('advanced-drop-reset'),
                semanticLabel: '重置拖放',
                variant: .text,
                onPressed: () {
                  opened.value = received.value = 0;
                  phase.value = '就绪';
                  sequence.value = [];
                },
                child: Icons.restart_alt_rounded,
              ),
            ],
          ),
          Text(
            sequence.value.isEmpty ? '—' : sequence.value.join(' → '),
            key: ValueKey('advanced-drop-sequence'),
            maxLines: 3,
          ),
        ],
      ),
      child: Padding(
        padding: .all(16),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 16,
          children: [
            ElCard(
              style: .new(padding: .zero),
              child: ElView(
                key: ValueKey('advanced-drop-card'),
                style: .new(
                  padding: .all(12),
                  backgroundColor: pressed.value ? colors.tertiaryContainer : colors.surface,
                  borderRadius: .circular(16),
                ),
                event: ElEvent(
                  onTapDown: (_) {
                    pressed.value = true;
                    sequence.value = ['按下'];
                  },
                  onTapUp: (_) => pressed.value = false,
                  onTapCancel: (_) {
                    pressed.value = false;
                    record('取消按压');
                  },
                  onTap: (_) {
                    opened.value++;
                    record('打开文件');
                  },
                ),
                child: ElDraggable<String>(
                  data: '项目计划',
                  ghostBuilder: (_) => file(preview: true),
                  onDragStarted: () {
                    phase.value = '拖放中';
                    record('开始拖放');
                  },
                  onDragEnded: (accepted) {
                    phase.value = accepted ? '已投放' : '未投放';
                    record(phase.value);
                  },
                  child: file(),
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: .stretch,
                spacing: 12,
                children: [
                  Expanded(child: target(accepts: true)),
                  Expanded(child: target(accepts: false)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
