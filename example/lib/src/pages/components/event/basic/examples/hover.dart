import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../demo_surface.dart';

/// 用高亮与缩放反馈鼠标进入、移动与离开。
class ElHoverEventExample extends HookWidget {
  /// 创建悬停示例。
  // ignore: prefer_const_constructors_in_immutables
  ElHoverEventExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hovered = useState(false);
    final callback = useState('等待鼠标');
    return ElEventDemoSurface(
      footer: Text(callback.value),
      child: Center(
        child: ElView(
          key: ValueKey('event-basic-hover'),
          event: ElEvent(
            cursor: SystemMouseCursors.click,
            onPointerEnter: (_) {
              hovered.value = true;
              callback.value = 'onPointerEnter';
            },
            onPointerHover: (_) => callback.value = 'onPointerHover',
            onPointerExit: (_) {
              hovered.value = false;
              callback.value = 'onPointerExit';
            },
          ),
          child: AnimatedScale(
            scale: hovered.value ? 1.08 : 1,
            duration: Duration(milliseconds: 160),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 160),
              width: 196,
              height: 124,
              alignment: .center,
              decoration: BoxDecoration(
                color: hovered.value ? colors.primaryContainer : colors.surface,
                border: Border.all(color: hovered.value ? colors.primary : colors.outlineVariant),
                borderRadius: .circular(16),
              ),
              child: Column(
                mainAxisSize: .min,
                spacing: 8,
                children: [
                  Icon(Icons.ads_click, size: 48, color: colors.primary),
                  Text(hovered.value ? '鼠标在这里' : '把鼠标移进来', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
