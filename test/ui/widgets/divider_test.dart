import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Align(
      alignment: .topLeft,
      child: ElView(style: ElStyle(width: 300), child: child),
    ),
  );
  Iterable<ElView> lines(WidgetTester tester) => tester
      .widgetList<ElView>(find.descendant(of: find.byType(ElDivider), matching: find.byType(ElView)))
      .where((view) => view.style?.bgColor != null);

  testWidgets('默认分割线使用中性灰色，使用 24px 留白和 1px 厚度', (tester) async {
    await tester.pumpWidget(host(ElDivider()));
    final divider = tester.widget<ElDivider>(find.byType(ElDivider));
    expect(divider.style?.height, 24);
    expect(lines(tester).single.style?.bgColor, const Color(0xff808080));
    expect(lines(tester).single.style?.height, 1);
  });

  testWidgets('方向、颜色、尺寸、厚度、内缩和间距均由参数控制', (tester) async {
    await tester.pumpWidget(
      host(ElDivider(size: 32, thickness: 2, indent: 3, gap: 7, color: Color(0xff123456), child: '标题')),
    );
    final divider = tester.widget<ElDivider>(find.byType(ElDivider));
    expect(divider.style?.height, 32);
    expect(divider.style?.padding, EdgeInsets.symmetric(horizontal: 3));
    expect(lines(tester), hasLength(2));
    expect(lines(tester).every((line) => line.style?.height == 2 && line.style?.bgColor == Color(0xff123456)), isTrue);
    await tester.pumpWidget(host(ElDivider(vertical: true, size: 40, thickness: 3)));
    expect(tester.widget<ElDivider>(find.byType(ElDivider)).style?.width, 40);
    expect(lines(tester).single.style?.width, 3);
  });

  testWidgets('用户样式最后覆盖容器', (tester) async {
    await tester.pumpWidget(host(ElDivider(style: ElStyle(height: 40, opacity: 0.5))));
    expect(tester.widget<ElDivider>(find.byType(ElDivider)).style?.height, 40);
    expect(tester.widget<ElDivider>(find.byType(ElDivider)).style?.opacity, 0.5);
  });
}
