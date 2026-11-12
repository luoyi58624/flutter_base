import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _page({required Axis axis, required double extent, required Widget child}) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(
      style: ElStyle(width: axis == .horizontal ? extent : 80, height: axis == .vertical ? extent : 80),
      child: child,
    ),
  ),
);

ElStyle _sizeStyle(Axis axis, Object extent) =>
    ElStyle(width: axis == .horizontal ? extent : 20, height: axis == .vertical ? extent : 20);

double _extent(WidgetTester tester, Key key, Axis axis) {
  final size = tester.getSize(find.byKey(key));
  return axis == .horizontal ? size.width : size.height;
}

void main() {
  for (final axis in Axis.values) {
    testWidgets('$axis 参照变化只重排相关后代，嵌套百分比继续传递', (tester) async {
      final fixedKey = ValueKey('fixed');
      final relativeKey = ValueKey('relative');
      final nestedKey = ValueKey('nested');
      final isolatedKey = ValueKey('isolated');
      final content = Flex(
        direction: axis,
        mainAxisSize: .min,
        children: [
          ElView(key: fixedKey, style: _sizeStyle(axis, 20)),
          ElView(
            key: relativeKey,
            style: _sizeStyle(axis, '50%'),
            child: Flex(
              direction: axis,
              mainAxisSize: .min,
              children: [ElView(key: nestedKey, style: _sizeStyle(axis, '50%'))],
            ),
          ),
          ElView(
            style: _sizeStyle(axis, 40),
            child: Flex(
              direction: axis,
              mainAxisSize: .min,
              children: [ElView(key: isolatedKey, style: _sizeStyle(axis, '50%'))],
            ),
          ),
        ],
      );
      await tester.pumpWidget(_page(axis: axis, extent: 300, child: content));
      final fixed = tester.renderObject<ElRenderView>(find.byKey(fixedKey));
      final isolated = tester.renderObject<ElRenderView>(find.byKey(isolatedKey));
      final fixedLayouts = fixed.debugLayoutCount;
      final isolatedLayouts = isolated.debugLayoutCount;
      expect(_extent(tester, relativeKey, axis), 150);
      expect(_extent(tester, nestedKey, axis), 75);

      for (final (extent, nestedExtent) in [(400.0, 100.0), (240.0, 60.0)]) {
        await tester.pumpWidget(_page(axis: axis, extent: extent, child: content));
        expect(_extent(tester, relativeKey, axis), nestedExtent * 2);
        expect(_extent(tester, nestedKey, axis), nestedExtent);
        expect(_extent(tester, isolatedKey, axis), 20);
        expect(fixed.debugLayoutCount, fixedLayouts, reason: '固定尺寸不能因祖先参照变化被重排');
        expect(isolated.debugLayoutCount, isolatedLayouts, reason: '近层固定参照隔离外层变化');
        expect(tester.takeException(), isNull);
      }
    });

    for (final field in ['min', 'max', 'calc']) {
      testWidgets('$axis 无界轴的 $field 长度随参照更新', (tester) async {
        final key = ValueKey(field);
        final horizontal = axis == Axis.horizontal;
        final style = switch (field) {
          'min' => ElStyle(
            width: horizontal ? 20 : 10,
            height: horizontal ? 10 : 20,
            minWidth: horizontal ? '50%' : null,
            minHeight: horizontal ? null : '50%',
          ),
          'max' => ElStyle(
            width: horizontal ? 600 : 10,
            height: horizontal ? 10 : 600,
            maxWidth: horizontal ? '50%' : null,
            maxHeight: horizontal ? null : '50%',
          ),
          _ => _sizeStyle(axis, ElDimension.calc(10, 25)),
        };
        final content = Flex(
          direction: axis,
          mainAxisSize: .min,
          children: [ElView(key: key, style: style)],
        );
        await tester.pumpWidget(_page(axis: axis, extent: 300, child: content));
        expect(_extent(tester, key, axis), field == 'calc' ? 85 : 150);
        await tester.pumpWidget(_page(axis: axis, extent: 400, child: content));
        expect(_extent(tester, key, axis), field == 'calc' ? 110 : 200);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('高度参照变化不重排只依赖宽度的无界节点', (tester) async {
    final key = ValueKey('width-only');
    final content = UnconstrainedBox(
      child: ElView(
        key: key,
        style: ElStyle(width: '50%', height: 20),
      ),
    );
    await tester.pumpWidget(_page(axis: .vertical, extent: 300, child: content));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final layouts = render.debugLayoutCount;
    await tester.pumpWidget(_page(axis: .vertical, extent: 400, child: content));
    expect(render.size, Size(40, 20));
    expect(render.debugLayoutCount, layouts);
    expect(tester.takeException(), isNull);
  });
}
