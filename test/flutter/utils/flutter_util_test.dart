import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('尺寸工具在有限约束下等比缩放', () {
    expect(
      ElFlutterUtil.calcConstraintsSize(
        Size(100, 50),
        BoxConstraints(maxWidth: 50, maxHeight: 50),
      ),
      Size(50, 25),
    );
    expect(
      ElFlutterUtil.calcConstraintsSize(
        Size(50, 100),
        BoxConstraints(maxWidth: 50, maxHeight: 50),
      ),
      Size(25, 50),
    );
  });
}
