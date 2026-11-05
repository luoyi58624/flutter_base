import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required Widget child}) => MaterialApp(
    home: ElComponentProvider(
      components: el.mobileComponents,
      child: ElView(
        style: ElStyle(vars: {ElTokens.$cardColor: Colors.white}),
        child: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  );

  testWidgets('圆形波纹越过单项边界，圆外区域不被矩形填满', (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      host(
        child: RepaintBoundary(
          key: boundaryKey,
          child: ElBottomTabbar(
            onDestinationSelected: (_) {},
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            destinations: [
              for (final label in ['首页', '组件', '示例', '设置'])
                NavigationDestination(icon: SizedBox.shrink(), label: label),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final response = find.byType(InkResponse).at(1);
    final gesture = await tester.startGesture(tester.getCenter(response));
    await tester.pump();
    await tester.pump(Duration(seconds: 1));

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final sample = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
      Color pixel(int x, int y) {
        final offset = (y * image.width + x) * 4;
        return Color.fromARGB(
          data.getUint8(offset + 3),
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
      }

      // 第二项横向范围为 80–160；圆的左右两侧应越过该边界，四角仍留白。
      final colors = [pixel(68, 28), pixel(172, 28), pixel(68, 2), pixel(172, 2)];
      image.dispose();
      return colors;
    });
    expect(sample![0], isNot(Colors.white));
    expect(sample[1], isNot(Colors.white));
    expect(sample[2], Colors.white);
    expect(sample[3], Colors.white);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('隐藏文字仍保留按钮名称，禁用项不可激活', (tester) async {
    final semantics = tester.ensureSemantics();
    final selections = <int>[];
    await tester.pumpWidget(
      host(
        child: ElBottomTabbar(
          onDestinationSelected: selections.add,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: [
            NavigationDestination(icon: Icon(Icons.home), label: '首页'),
            NavigationDestination(icon: Icon(Icons.settings), label: '设置', enabled: false),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('首页')),
      matchesSemantics(label: '首页', isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('设置')),
      matchesSemantics(label: '设置', isButton: true, hasEnabledState: true),
    );
    await tester.tap(find.byType(InkResponse).at(1));
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
    await tester.tap(find.byType(InkResponse).first);
    await tester.pumpAndSettle();
    expect(selections, [0]);
    await tester.pumpWidget(SizedBox());
    semantics.dispose();
  });
}
