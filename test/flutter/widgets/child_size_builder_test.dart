import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('临时布局将探测尺寸传给实际内容', (tester) async {
    Size? measured;
    await tester.pumpWidget(
      Center(
        child: ElChildSizeBuilder(
          tempChild: SizedBox(width: 30, height: 20),
          builder: (size) {
            measured = size;
            return SizedBox(
              key: ValueKey('actual'),
              width: size.width + 5,
              height: size.height,
            );
          },
        ),
      ),
    );
    expect(measured, Size(30, 20));
    expect(tester.getSize(find.byKey(ValueKey('actual'))), Size(35, 20));
  });
}
