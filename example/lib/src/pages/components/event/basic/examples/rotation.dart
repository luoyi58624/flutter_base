import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 用双指旋转改变中央方向卡片的角度。
class ElRotationEventExample extends HookWidget {
  /// 创建独立旋转示例。
  // ignore: prefer_const_constructors_in_immutables
  ElRotationEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final rotation = useState(0.0);
    final origin = useRef(0.0);
    final currentEvent = useState('—');
    final colors = Theme.of(context).colorScheme;
    return ElEventDemoSurface(
      footer: Row(
        spacing: 12,
        children: [
          Expanded(child: Text(currentEvent.value, maxLines: 1, overflow: .ellipsis)),
          Text('${(rotation.value * 180 / math.pi).round()}°'),
        ],
      ),
      child: Stack(
        fit: .expand,
        children: [
          Positioned.fill(
            child: ElView(
              key: ValueKey('event-basic-rotation'),
              style: .new(alignment: .center),
              event: ElEvent(
                onScaleStart: (_) {
                  origin.value = rotation.value;
                  currentEvent.value = 'onScaleStart';
                },
                onRotationUpdate: (event) {
                  rotation.value = origin.value + event.rotation;
                  currentEvent.value = 'onRotationUpdate';
                },
                onScaleEnd: (_) {
                  origin.value = rotation.value;
                  currentEvent.value = 'onScaleEnd';
                },
                onScaleCancel: (_) {
                  origin.value = rotation.value;
                  currentEvent.value = 'onScaleCancel';
                },
              ),
              child: Transform.rotate(
                angle: rotation.value,
                child: ElView(
                  key: ValueKey('event-basic-rotation-block'),
                  style: .new(
                    width: 96,
                    height: 112,
                    alignment: .center,
                    borderRadius: BorderRadius.circular(24),
                    backgroundColor: colors.primary,
                  ),
                  child: Icon(Icons.navigation_rounded, size: 48, color: colors.onPrimary),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: ElButton(
              key: ValueKey('event-basic-rotation-reset'),
              semanticLabel: '重置旋转',
              variant: .text,
              onPressed: () {
                rotation.value = origin.value = 0;
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
