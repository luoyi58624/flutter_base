import 'dart:math' as math;

import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

/// Element Plus 水印。
///
/// 在 [child] 之上平铺旋转文字。水印层不吃指针事件，底下内容照常交互。
class ElWatermark extends StatelessWidget {
  const ElWatermark({
    super.key,
    required this.child,
    this.content,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.fontFamily,
    this.color = const Color(0x26000000),
    this.rotate = -22,
    this.gap = const Offset(100, 100),
    this.offset,
    this.style,
  });

  final Widget child;

  /// 水印文案，单行传 String，多行传 `List<String>`
  final Object? content;

  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;

  /// 官方默认 rgba(0, 0, 0, .15)
  final Color color;

  /// 旋转角度（度），官方默认 -22
  final double rotate;

  /// 相邻水印的水平 / 垂直间距
  final Offset gap;

  /// 整体偏移，缺省取 [gap] 的一半（对齐官方）
  final Offset? offset;

  final ElStyle? style;

  List<String> get _lines {
    final value = content;
    if (value == null) return const [];
    if (value is List) return value.map((line) => line.toString()).toList();
    return [value.toString()];
  }

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: style,
      child: Stack(
        children: [
          child,
          // 水印层铺满内容并放弃全部命中，避免挡住底下的交互
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WatermarkPainter(
                  lines: _lines,
                  textStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    fontFamily: fontFamily,
                    color: color,
                  ),
                  rotate: rotate,
                  gap: gap,
                  offset: offset ?? Offset(gap.dx / 2, gap.dy / 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({
    required this.lines,
    required this.textStyle,
    required this.rotate,
    required this.gap,
    required this.offset,
  });

  final List<String> lines;
  final TextStyle textStyle;
  final double rotate;
  final Offset gap;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(text: lines.join('\n'), style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final stepX = painter.width + gap.dx;
    final stepY = painter.height + gap.dy;
    if (stepX <= 0 || stepY <= 0) return;

    final radians = rotate * math.pi / 180;
    // 旋转后单块会越界，两侧各多铺一圈保证边角不留白
    for (var y = -stepY; y < size.height + stepY; y += stepY) {
      for (var x = -stepX; x < size.width + stepX; x += stepX) {
        canvas.save();
        // 绕自身中心旋转，再把中心挪到网格点
        canvas.translate(x + offset.dx + painter.width / 2, y + offset.dy + painter.height / 2);
        canvas.rotate(radians);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) =>
      !listEquals(lines, oldDelegate.lines) ||
      textStyle != oldDelegate.textStyle ||
      rotate != oldDelegate.rotate ||
      gap != oldDelegate.gap ||
      offset != oldDelegate.offset;
}