import 'package:flutter/widgets.dart';

/// 提供文字方向及宽松约束，便于测量动画自身的布局尺寸。
Widget animationScene(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
}) {
  return Directionality(
    textDirection: direction,
    child: UnconstrainedBox(child: child),
  );
}
