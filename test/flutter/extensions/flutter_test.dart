import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter 扩展保留 CSS 内边距和文本缩放语义', () {
    expect([10].toEdgeInsets, EdgeInsets.all(10));
    expect(
      [10, 20].toEdgeInsets,
      EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    );
    expect([10, 20, 30].toEdgeInsets, EdgeInsets.fromLTRB(20, 10, 20, 30));
    expect(
      [10.0, 20.0, 30.0, 40.0].toEdgeInsets,
      EdgeInsets.fromLTRB(40, 10, 20, 30),
    );
    expect(<double>[].toEdgeInsets, isNull);
    expect(10.applyTextScale(TextScaler.linear(2)), 20);
    expect(10.0.applyTextScale(TextScaler.linear(2), maxValue: 15), 15);
    expect(700.toFontWeight(), FontWeight.w700);
    expect(123.toFontWeight(FontWeight.w300), FontWeight.w300);
    expect(
      AxisDirection.left.applyTextDirection(TextDirection.rtl),
      AxisDirection.right,
    );
    expect(Size(2, 3).toOffset, Offset(2, 3));
  });
}
