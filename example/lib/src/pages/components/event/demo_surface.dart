import 'package:flutter/material.dart';

/// 为独立事件示例提供圆角点阵舞台与状态栏。
class ElEventDemoSurface extends StatelessWidget {
  /// 创建固定高度、适应可用宽度的事件舞台。
  // ignore: prefer_const_constructors_in_immutables
  ElEventDemoSurface({super.key, required this.child, this.height = 240, this.footer});

  /// 舞台中的交互内容。
  final Widget child;

  /// 舞台高度，不包括状态栏。
  final double height;

  /// 显示当前事件或操作数值。
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        Container(
          height: height,
          clipBehavior: .antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: .circular(20),
            border: .all(color: colors.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Stack(
            fit: .expand,
            children: [
              IgnorePointer(child: CustomPaint(painter: _DotsPainter(colors.outlineVariant))),
              child,
            ],
          ),
        ),
        if (footer case final footer?)
          DefaultTextStyle.merge(
            maxLines: 1,
            overflow: .ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
            child: Padding(padding: .symmetric(horizontal: 4), child: footer),
          ),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.6);
    for (var x = 12.0; x < size.width; x += 20) {
      for (var y = 12.0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => oldDelegate.color != color;
}
