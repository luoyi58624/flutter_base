import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 通过嵌套区域的点击计数对照冒泡与阻止冒泡。
class ElEventPropagationExample extends HookWidget {
  /// 创建点击传播示例。
  // ignore: prefer_const_constructors_in_immutables
  ElEventPropagationExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stop = useState(false);
    final innerCount = useState(0);
    final outerCount = useState(0);
    final pressed = useState(false);

    return Column(
      spacing: 12,
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            Text('阻止冒泡', style: Theme.of(context).textTheme.labelLarge),
            SizedBox(width: 8),
            Switch(
              key: ValueKey('event-propagation-toggle'),
              value: stop.value,
              onChanged: (value) => stop.value = value,
            ),
            Spacer(),
            IconButton(
              key: ValueKey('event-propagation-reset'),
              tooltip: '重置',
              onPressed: () {
                innerCount.value = outerCount.value = 0;
                pressed.value = false;
              },
              icon: Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
        ElView(
          key: ValueKey('event-propagation-outer'),
          style: .new(
            height: 240,
            padding: .all(20),
            borderRadius: .circular(20),
            border: .all(borderColor: colors.outlineVariant),
            backgroundColor: colors.surfaceContainerLow,
          ),
          event: ElEvent(cursor: SystemMouseCursors.click, onTap: (_) => outerCount.value++),
          child: Column(
            children: [
              Row(
                spacing: 8,
                children: [
                  Icon(Icons.layers_outlined, size: 20, color: colors.onSurfaceVariant),
                  Text('外层', style: TextStyle(color: colors.onSurfaceVariant)),
                  Spacer(),
                  Text(
                    '${outerCount.value}',
                    key: ValueKey('event-propagation-outer-count'),
                    style: TextStyle(color: colors.primary, fontSize: 24, fontWeight: .w700),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: AnimatedScale(
                    scale: pressed.value ? 0.96 : 1,
                    duration: Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: ElView(
                      key: ValueKey('event-propagation-inner'),
                      style: .new(
                        width: 140,
                        height: 120,
                        alignment: .center,
                        borderRadius: .circular(16),
                        backgroundColor: colors.primary,
                      ),
                      event: ElEvent(
                        cursor: SystemMouseCursors.click,
                        onTapDown: (_) => pressed.value = true,
                        onTapUp: (_) => pressed.value = false,
                        onTapCancel: (_) => pressed.value = false,
                        onTap: (event) {
                          innerCount.value++;
                          if (stop.value) event.stopPropagation();
                        },
                      ),
                      child: Column(
                        mainAxisSize: .min,
                        children: [
                          Text('内层', style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.8))),
                          Text(
                            '${innerCount.value}',
                            key: ValueKey('event-propagation-inner-count'),
                            style: TextStyle(color: colors.onPrimary, fontSize: 36, fontWeight: .w700),
                          ),
                          Icon(
                            stop.value ? Icons.block_rounded : Icons.arrow_upward_rounded,
                            size: 18,
                            color: colors.onPrimary.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
