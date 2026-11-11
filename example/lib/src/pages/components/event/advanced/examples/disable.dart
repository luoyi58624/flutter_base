import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 将图形拖入停止区，观察声明禁用后正在进行的拖拽如何结束。
class ElDisableDuringDragExample extends HookWidget {
  /// 创建操作中禁用示例。
  // ignore: prefer_const_constructors_in_immutables
  ElDisableDuringDragExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final position = useState(Offset(16, 88));
    final disabled = useState(false);
    final cancels = useState(0);
    final phase = useState('就绪');

    void canceled(ElEventDetails event) {
      void update() {
        if (!context.mounted) return;
        cancels.value++;
        phase.value = '已取消';
      }

      // 禁用在构建期间生效时，等本帧结束再刷新取消计数。
      if (SchedulerBinding.instance.schedulerPhase == .persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => update());
      } else {
        update();
      }
    }

    return ElEventDemoSurface(
      footer: Row(
        children: [
          Expanded(child: Text(disabled.value ? '已停用' : phase.value, key: ValueKey('advanced-disable-phase'))),
          Text('取消 ${cancels.value}', key: ValueKey('advanced-disable-count')),
          IconButton(
            key: ValueKey('advanced-disable-reset'),
            tooltip: '复位',
            onPressed: () {
              disabled.value = false;
              cancels.value = 0;
              phase.value = '就绪';
              position.value = Offset(16, 88);
            },
            icon: Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stopX = constraints.maxWidth * 0.68;
          Offset clamp(Offset value) => Offset(
            value.dx.clamp(0.0, math.max(0.0, constraints.maxWidth - 64)),
            value.dy.clamp(0.0, constraints.maxHeight - 64),
          );
          final current = clamp(position.value);
          return Stack(
            key: ValueKey('advanced-disable-area'),
            children: [
              Positioned(
                left: stopX,
                top: 0,
                bottom: 0,
                right: 0,
                child: ColoredBox(
                  key: ValueKey('advanced-disable-stop-zone'),
                  color: colors.errorContainer.withValues(alpha: 0.55),
                  child: Column(
                    mainAxisAlignment: .center,
                    spacing: 8,
                    children: [
                      Icon(Icons.block_rounded, color: colors.onErrorContainer),
                      Text('停止区', style: TextStyle(color: colors.onErrorContainer)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: current.dx,
                top: current.dy,
                width: 64,
                height: 64,
                child: ElView(
                  key: ValueKey('advanced-disable-card'),
                  style: .new(
                    borderRadius: .circular(16),
                    alignment: .center,
                    backgroundColor: disabled.value ? colors.outline : colors.primary,
                  ),
                  event: ElEvent(
                    disabled: disabled.value,
                    cursor: disabled.value ? SystemMouseCursors.forbidden : SystemMouseCursors.move,
                    dragStartDistance: 3,
                    onDragStart: (event) {
                      phase.value = '拖动中';
                      event.stopPropagation();
                    },
                    onDragUpdate: (event) {
                      final next = clamp(clamp(position.value) + event.delta);
                      position.value = next;
                      if (next.dx + 32 >= stopX) disabled.value = true;
                    },
                    onDragEnd: (_) => phase.value = '已松手',
                    onDragCancel: canceled,
                  ),
                  child: Icon(
                    disabled.value ? Icons.lock_rounded : Icons.open_with_rounded,
                    color: disabled.value ? colors.surface : colors.onPrimary,
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
