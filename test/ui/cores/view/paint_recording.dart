import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录实际边框指令，保留原有几何断言使用的形状和画笔。
List<(Object, Paint)>? recordBorderPaints({
  required Rect rect,
  required ElBorder border,
  required BorderRadius? borderRadius,
}) {
  final draws = _recordDraws(
    (canvas) => ViewBoxPainter.paintBorder(canvas, rect: rect, border: border, borderRadius: borderRadius),
  );
  return draws.isEmpty ? null : draws;
}

/// 记录内阴影的实际 Path，裁剪与保存顺序由绘制管线测试单独断言。
List<(Path, Paint)> recordInsetShadowPaints({required RRect outerRRect, required List<BoxShadow> shadows}) => [
  for (final (shape, paint) in _recordDraws(
    (canvas) => ViewBoxPainter.paintShadows(canvas, outerRRect: outerRRect, shadows: shadows, inset: true),
  ))
    (shape as Path, paint),
];

List<(Object, Paint)> _recordDraws(void Function(Canvas) paint) {
  final canvas = TestRecordingCanvas();
  paint(canvas);
  return [
    for (final call in canvas.invocations)
      if ({#drawRect, #drawRRect, #drawPath}.contains(call.invocation.memberName))
        (call.invocation.positionalArguments[0] as Object, call.invocation.positionalArguments[1] as Paint),
  ];
}
