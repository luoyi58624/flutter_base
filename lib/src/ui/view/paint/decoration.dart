import 'package:flutter/rendering.dart';

/// 按需持有盒装饰资源，简单背景不构造路径或合成图层。
class DecorationPainter {
  Paint? _background;

  /// 绘制已经解析和采样的矩形背景，复用画笔。
  void paintBackground(PaintingContext context, Rect rect, Color color) {
    context.canvas.drawRect(rect, (_background ??= Paint())..color = color);
  }
}
