import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 通过内外层的位置和计数观察拖拽传播边界。
class ElNestedDragExample extends HookWidget {
  /// 创建嵌套拖拽示例。
  // ignore: prefer_const_constructors_in_immutables
  ElNestedDragExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outer = useState(Offset(12, 12));
    final inner = useState(Offset(16, 76));
    final outerStarts = useState(0), outerUpdates = useState(0);
    final innerStarts = useState(0), innerUpdates = useState(0), clicks = useState(0);

    return ElEventDemoSurface(
      footer: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '外层  起拖 ${outerStarts.value} · 更新 ${outerUpdates.value}',
                  key: ValueKey('advanced-nested-outer-count'),
                ),
              ),
              IconButton(
                key: ValueKey('advanced-nested-reset'),
                tooltip: '重置',
                onPressed: () {
                  outer.value = Offset(12, 12);
                  inner.value = Offset(16, 76);
                  outerStarts.value = outerUpdates.value = innerStarts.value = innerUpdates.value = clicks.value = 0;
                },
                icon: Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          Wrap(
            spacing: 16,
            children: [
              Text(
                '内层  起拖 ${innerStarts.value} · 更新 ${innerUpdates.value}',
                key: ValueKey('advanced-nested-inner-count'),
              ),
              Text('点击 ${clicks.value}', key: ValueKey('advanced-nested-click-count')),
            ],
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(0.0, math.min(320.0, constraints.maxWidth - 24));
          Offset clampOuter(Offset value) => Offset(
            value.dx.clamp(0.0, math.max(0.0, constraints.maxWidth - width)),
            value.dy.clamp(0.0, constraints.maxHeight - 196),
          );
          Offset clampInner(Offset value) =>
              Offset(value.dx.clamp(12.0, math.max(12.0, width - 92)), value.dy.clamp(52.0, 108.0));
          final outerPosition = clampOuter(outer.value), innerPosition = clampInner(inner.value);
          return Stack(
            key: ValueKey('advanced-nested-area'),
            children: [
              Positioned(
                left: outerPosition.dx,
                top: outerPosition.dy,
                width: width,
                height: 196,
                child: ElView(
                  key: ValueKey('advanced-nested-outer'),
                  style: .new(
                    borderRadius: .circular(18),
                    border: .all(borderColor: colors.outlineVariant),
                    backgroundColor: colors.secondaryContainer,
                  ),
                  event: ElEvent(
                    cursor: SystemMouseCursors.move,
                    dragStartDistance: 3,
                    onDragStart: (_) => outerStarts.value++,
                    onDragUpdate: (event) {
                      outer.value = clampOuter(clampOuter(outer.value) + event.delta);
                      outerUpdates.value++;
                    },
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 16,
                        top: 16,
                        child: Row(
                          spacing: 8,
                          children: [
                            Icon(Icons.layers_outlined, size: 20, color: colors.onSecondaryContainer),
                            Text('外层', style: TextStyle(color: colors.onSecondaryContainer)),
                          ],
                        ),
                      ),
                      Positioned(
                        left: innerPosition.dx,
                        top: innerPosition.dy,
                        width: 80,
                        height: 76,
                        child: ElView(
                          key: ValueKey('advanced-nested-inner'),
                          style: .new(borderRadius: .circular(16), alignment: .center, backgroundColor: colors.primary),
                          event: ElEvent(
                            cursor: SystemMouseCursors.move,
                            dragStartDistance: 24,
                            onTap: (_) => clicks.value++,
                            onDragStart: (event) {
                              innerStarts.value++;
                              event.stopPropagation();
                            },
                            onDragUpdate: (event) {
                              inner.value = clampInner(clampInner(inner.value) + event.delta);
                              innerUpdates.value++;
                            },
                          ),
                          child: Column(
                            mainAxisSize: .min,
                            spacing: 4,
                            children: [
                              Icon(Icons.open_with_rounded, color: colors.onPrimary),
                              Text('内层', style: TextStyle(color: colors.onPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
