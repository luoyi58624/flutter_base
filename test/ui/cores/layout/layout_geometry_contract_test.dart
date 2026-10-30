import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/layout/geometry/grid_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: SizedBox(width: 300, child: child),
  ),
);

void main() {
  testWidgets('独立固定列表只 dry 测量首项，真实条目仍全量布局', (tester) async {
    final measured = <int>[];
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElListView(key: key, fixedSize: true, gap: 4, children: List.generate(20, (index) => _Probe(index, measured))),
      ),
    );
    final render = key.currentContext!.findRenderObject()! as RenderBox;
    expect(render.size, Size(300, 20 * 16 + 19 * 4));
    measured.clear();
    final dry = render.getDryLayout(BoxConstraints(maxWidth: 200));
    expect(dry, Size(200, 20 * 16 + 19 * 4));
    expect(measured, [0]);
  });

  testWidgets('独立网格从共享几何得出 dry 尺寸，不探测任意格子', (tester) async {
    final measured = <int>[];
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElGridView(
          key: key,
          crossAxisCount: 3,
          aspectRatio: 2,
          gap: 6,
          children: List.generate(20, (index) => _Probe(index, measured)),
        ),
      ),
    );
    final render = key.currentContext!.findRenderObject()! as RenderBox;
    measured.clear();
    final expected = GridLayoutGeometry(
      crossAxisCount: 3,
      aspectRatio: 2,
      rowGap: 6,
      columnGap: 6,
    ).resolve(axis: .vertical, crossExtent: 200, itemCount: 20);
    expect(render.getDryLayout(BoxConstraints(maxWidth: 200)), expected.size);
    expect(measured, isEmpty);
  });

  test('Grid 最小与最大轨道、物理宽高比、空内容使用同一套解析规则', () {
    expect(
      GridLayoutGeometry(
        minCrossAxisExtent: 100,
        columnGap: 10,
      ).resolve(axis: .vertical, crossExtent: 300, itemCount: 100).trackCount,
      2,
    );
    expect(
      GridLayoutGeometry(
        maxCrossAxisExtent: 100,
        columnGap: 10,
      ).resolve(axis: .vertical, crossExtent: 300, itemCount: 100).trackCount,
      3,
    );
    final horizontal = GridLayoutGeometry(
      crossAxisCount: 2,
      aspectRatio: 2,
      rowGap: 4,
    ).resolve(axis: .horizontal, crossExtent: 104, itemCount: 4);
    expect(horizontal.cellSize, Size(100, 50));
    expect(horizontal.size, Size(200, 104));
    expect(GridLayoutGeometry().resolve(axis: .vertical, crossExtent: double.infinity, itemCount: 0).size, Size.zero);
    expect(() => ElGridView(crossAxisCount: 3, minCrossAxisExtent: 80), throwsAssertionError);
    expect(
      () => ElGridView.builder(itemCount: 1, itemBuilder: (_, _) => ElView(), gap: 4, rowGap: 4),
      throwsAssertionError,
    );
    expect(
      () => ElListView.builder(
        itemCount: 1,
        itemBuilder: (_, _) => ElView(),
        separatorBuilder: (_, _) => ElView(),
        gap: 4,
      ),
      throwsAssertionError,
    );
  });
}

class _Probe extends LeafRenderObjectWidget {
  const _Probe(this.index, this.measured);
  final int index;
  final List<int> measured;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe(index, measured);
}

class _RenderProbe extends RenderBox {
  _RenderProbe(this.index, this.measured);
  final int index;
  final List<int> measured;
  @override
  void performLayout() => size = constraints.constrain(Size(40, 16 + index.toDouble()));
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    measured.add(index);
    return constraints.constrain(Size(40, 16 + index.toDouble()));
  }
}
