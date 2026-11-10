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
  test('itemWidth 沿用旧版取整顺序，固定数量和主轴尺寸仍优先', () {
    final grid = GridLayoutGeometry(itemWidth: 150, columnGap: 10, rowGap: 6, aspectRatio: 2);
    final resolved = grid.resolve(axis: .vertical, crossExtent: 300, itemCount: 5);
    expect(resolved.trackCount, 2);
    expect(resolved.cellSize, Size(145, 72.5));
    expect(resolved.size, Size(300, 229.5));
    expect(resolved.mainStart(4), 157);

    final fixed = GridLayoutGeometry(
      itemWidth: 150,
      crossAxisCount: 4,
      mainAxisExtent: 20,
      columnGap: 10,
      rowGap: 6,
    ).resolve(axis: .vertical, crossExtent: 430, itemCount: 5);
    expect(fixed.trackCount, 4);
    expect(fixed.cellSize, Size(100, 20));
    expect(fixed.size, Size(430, 46));
    final unbounded = GridLayoutGeometry(
      itemWidth: 150,
      crossAxisCount: 2,
      mainAxisExtent: 20,
      columnGap: 10,
      rowGap: 6,
    ).resolve(axis: .vertical, crossExtent: double.infinity, itemCount: 5);
    expect(unbounded.cellSize, Size(150, 20));
    expect(unbounded.size, Size(310, 72));

    final empty = grid.resolve(axis: .vertical, crossExtent: double.infinity, itemCount: 0);
    expect(empty.size, Size.zero);
    final zero = grid.resolve(axis: .vertical, crossExtent: 0, itemCount: 1);
    expect(zero.trackCount, 1);
    expect(zero.size, Size.zero);
  });

  test('横向 itemWidth 按物理宽高比换算行高，间距在行数确定后扣除', () {
    final grid = GridLayoutGeometry(
      itemWidth: 100,
      aspectRatio: 2,
      rowGap: 4,
      columnGap: 6,
    ).resolve(axis: .horizontal, crossExtent: 104, itemCount: 5);
    expect(grid.trackCount, 2);
    expect(grid.cellSize, Size(100, 50));
    expect(grid.size, Size(312, 104));
  });

  test('itemWidth 拒绝非法值和冲突的轨道尺寸声明', () {
    for (final width in [0.0, -1.0, double.infinity, double.nan]) {
      expect(() => ElGridView(itemWidth: width), throwsAssertionError);
      expect(() => GridLayoutGeometry(itemWidth: width), throwsAssertionError);
    }
    expect(() => ElGridView(itemWidth: 100, minCrossAxisExtent: 80), throwsAssertionError);
    expect(() => GridLayoutGeometry(itemWidth: 100, maxCrossAxisExtent: 120), throwsAssertionError);
  });

  testWidgets('itemWidth 的 dry 与固有尺寸无需探测格子，无界时按预估尺寸排成一带', (tester) async {
    final measured = <int>[];
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        ElGridView(
          key: key,
          itemWidth: 150,
          aspectRatio: 2,
          rowGap: 6,
          columnGap: 10,
          children: List.generate(5, (index) => _Probe(index, measured)),
        ),
      ),
    );
    final render = key.currentContext!.findRenderObject()! as RenderBox;
    measured.clear();
    expect(render.getDryLayout(BoxConstraints(maxWidth: 400)), Size(400, 304.5));
    expect(render.getDryLayout(BoxConstraints()), Size(790, 75));
    expect(render.getMinIntrinsicWidth(double.infinity), 150);
    expect(render.getMaxIntrinsicWidth(double.infinity), 150);
    expect(measured, isEmpty);
  });

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
    expect(() => ElGridView(gap: 4, rowGap: 4), throwsAssertionError);
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
