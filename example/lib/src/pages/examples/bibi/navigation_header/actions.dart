import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 导航栏里的定尺寸图标按钮。
class BibiHeaderAction extends StatelessWidget {
  /// 创建带标签和触摸反馈的图标按钮。
  const BibiHeaderAction({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    required this.onTap,
    required this.child,
    this.radius = 0,
    this.color,
  });

  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final Widget child;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Material(
      color: color ?? Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

/// Bibi 导航栏使用的线条图标。
enum BibiGlyph { tv, search, mail, menu, plus }

/// 绘制指定的 Bibi 导航图标。
class BibiGlyphIcon extends StatelessWidget {
  /// 使用指定颜色绘制图标。
  const BibiGlyphIcon(this.glyph, this.color);

  final BibiGlyph glyph;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(24), painter: _GlyphPainter(glyph, color));
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final BibiGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..strokeWidth = glyph == BibiGlyph.plus ? 2.7 : 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double endX, double endY) => canvas.drawLine(Offset(x, y), Offset(endX, endY), pen);
    void box(double left, double top, double right, double bottom, double radius) => canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(left, top, right, bottom), Radius.circular(radius)),
      pen,
    );

    switch (glyph) {
      case BibiGlyph.tv:
        box(3, 7, 21, 21, 3);
        line(7, 2, 11, 7);
        line(17, 2, 13, 7);
        line(7, 13, 9, 12);
        line(15, 12, 17, 13);
        canvas.drawArc(Rect.fromLTRB(9, 13, 15, 17), math.pi / 6, math.pi * 2 / 3, false, pen);
      case BibiGlyph.search:
        canvas.drawCircle(Offset(10.5, 10.5), 6.8, pen);
        line(15.6, 15.6, 21, 21);
      case BibiGlyph.mail:
        box(2, 4.5, 22, 19.5, 2);
        line(3, 6, 12, 13);
        line(12, 13, 21, 6);
      case BibiGlyph.menu:
        for (var y = 6.0; y <= 18; y += 6) {
          line(5, y, 19, y);
        }
      case BibiGlyph.plus:
        line(5, 12, 19, 12);
        line(12, 5, 12, 19);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.glyph != glyph || oldDelegate.color != color;
}
