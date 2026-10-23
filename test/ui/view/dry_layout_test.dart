import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (axis, crossExtent) in [
    for (final axis in Axis.values)
      for (final crossExtent in [300.0, 250.0]) (axis, crossExtent),
  ]) {
    final horizontal = axis == Axis.horizontal;
    final direction = horizontal ? '横向' : '纵向';
    final change = crossExtent == 300 ? '仅主轴约束变化' : '双轴约束变化';

    testWidgets('$direction百分比嵌套在$change后预测尺寸与正式布局一致', (tester) async {
      const outerKey = ValueKey('outer');
      const innerKey = ValueKey('inner');
      const childKey = ValueKey('child');
      final style = ElStyle(
        width: horizontal ? '50%' : null,
        height: horizontal ? null : '50%',
      );

      Widget scene(double extent, double crossExtent) {
        final inner = ElView(
          key: innerKey,
          style: style,
          child: const AspectRatio(key: childKey, aspectRatio: 1),
        );
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: horizontal ? extent : crossExtent,
                maxHeight: horizontal ? crossExtent : extent,
              ),
              child: ElView(
                key: outerKey,
                style: style,
                child: horizontal
                    ? Row(children: [inner])
                    : Column(children: [inner]),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(scene(400, 300));
      final outer = tester.renderObject<RenderBox>(find.byKey(outerKey));
      final inner = tester.renderObject<RenderBox>(find.byKey(innerKey));
      expect(
        outer.size,
        horizontal ? const Size(200, 100) : const Size(100, 200),
      );
      expect(inner.size, const Size(100, 100));
      final geometry = [
        for (final key in [outerKey, innerKey, childKey])
          (
            key,
            tester.getSize(find.byKey(key)),
            tester.getTopLeft(find.byKey(key)),
          ),
      ];

      // 首次查询新约束，分别覆盖仅主轴变化和双轴变化。
      final dry = outer.getDryLayout(
        BoxConstraints(
          maxWidth: horizontal ? 200 : crossExtent,
          maxHeight: horizontal ? crossExtent : 200,
        ),
      );
      for (final (key, size, origin) in geometry) {
        expect(tester.getSize(find.byKey(key)), size);
        expect(tester.getTopLeft(find.byKey(key)), origin);
      }

      // 先验证相同渲染对象的新正式尺寸，再比较预测值，完整保留复现证据。
      await tester.pumpWidget(scene(200, crossExtent));
      expect(tester.renderObject<RenderBox>(find.byKey(outerKey)), same(outer));
      expect(tester.renderObject<RenderBox>(find.byKey(innerKey)), same(inner));
      expect(
        outer.size,
        horizontal ? const Size(100, 50) : const Size(50, 100),
      );
      expect(inner.size, const Size(50, 50));
      expect(dry, outer.size);
    });
  }
}
