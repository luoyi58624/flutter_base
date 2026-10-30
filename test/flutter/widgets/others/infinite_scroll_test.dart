import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('无限滚动检查不足一屏的内容并响应禁用状态切换', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var loads = 0;
    Widget scene(bool disabled) => ElInfiniteScroll(
      controller: controller,
      disabled: disabled,
      delay: Duration.zero,
      onLoad: () => loads++,
      child: SingleChildScrollView(
        controller: controller,
        child: SizedBox(height: 100),
      ),
    );
    await tester.pumpWidget(scene(false));
    await tester.pump(Duration(milliseconds: 1));
    expect(loads, 1);
    await tester.pumpWidget(scene(true));
    await tester.pump(Duration(milliseconds: 1));
    expect(loads, 1);
    await tester.pumpWidget(scene(false));
    await tester.pump(Duration(milliseconds: 1));
    expect(loads, 2);
    await tester.pumpWidget(SizedBox());
  });
}
