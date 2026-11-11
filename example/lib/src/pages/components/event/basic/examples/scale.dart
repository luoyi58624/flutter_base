import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 用双指缩放改变中央卡片的大小。
class ElScaleEventExample extends HookWidget {
  /// 创建独立缩放示例。
  // ignore: prefer_const_constructors_in_immutables
  ElScaleEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = useState(1.0);
    final origin = useRef(1.0);
    final currentEvent = useState('—');
    final colors = Theme.of(context).colorScheme;
    return ElEventDemoSurface(
      footer: Row(
        spacing: 12,
        children: [
          Expanded(child: Text(currentEvent.value, maxLines: 1, overflow: .ellipsis)),
          Text('${(scale.value * 100).round()}%'),
        ],
      ),
      child: Stack(
        fit: .expand,
        children: [
          Positioned.fill(
            child: ElView(
              key: ValueKey('event-basic-scale'),
              style: .new(alignment: .center),
              event: ElEvent(
                onScaleStart: (_) {
                  origin.value = scale.value;
                  currentEvent.value = 'onScaleStart';
                },
                onScaleUpdate: (event) {
                  // 每次手势都以已有比例为基线，连续多次捏合不会跳回初始大小。
                  scale.value = (origin.value * event.scale).clamp(0.55, 1.8);
                  currentEvent.value = 'onScaleUpdate';
                },
                onScaleEnd: (_) {
                  origin.value = scale.value;
                  currentEvent.value = 'onScaleEnd';
                },
                onScaleCancel: (_) {
                  origin.value = scale.value;
                  currentEvent.value = 'onScaleCancel';
                },
              ),
              child: Transform.scale(
                scale: scale.value,
                child: ElView(
                  key: ValueKey('event-basic-scale-block'),
                  style: .new(
                    width: 96,
                    height: 96,
                    alignment: .center,
                    borderRadius: BorderRadius.circular(24),
                    backgroundColor: colors.primary,
                  ),
                  child: Icon(Icons.open_in_full_rounded, size: 36, color: colors.onPrimary),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: ElButton(
              key: ValueKey('event-basic-scale-reset'),
              semanticLabel: '重置缩放',
              variant: .text,
              onPressed: () {
                scale.value = origin.value = 1;
                currentEvent.value = '—';
              },
              child: Icons.restart_alt_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
