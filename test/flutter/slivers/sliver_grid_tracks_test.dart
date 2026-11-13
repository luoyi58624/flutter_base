import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(double width, Widget sliver, {Axis direction = Axis.vertical, double height = 600}) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: SizedBox(
      width: width,
      height: height,
      child: ElScrollView.sliver(scrollDirection: direction, slivers: [sliver]),
    ),
  ),
);

class _Probe extends StatefulWidget {
  const _Probe(this.index, this.built, {this.height});
  final int index;
  final Set<int> built;
  final double? height;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.built.add(widget.index);
  }

  @override
  Widget build(BuildContext context) => SizedBox(key: ValueKey(widget.index), height: widget.height);
}

void main() {
  testWidgets('itemWidth 按可用宽度向下取列数，间距在列数确定后扣除，至少保留一列', (tester) async {
    Widget build(double width) => _host(
      width,
      ElSliverGrid(
        itemWidth: 150,
        aspectRatio: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 6,
        children: [for (var i = 0; i < 5; i++) SizedBox(key: ValueKey(i))],
      ),
    );

    await tester.pumpWidget(build(400));
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(195, 97.5));
    expect(tester.getTopLeft(find.byKey(ValueKey(1))), Offset(205, 0));
    expect(tester.getTopLeft(find.byKey(ValueKey(2))), Offset(0, 103.5));

    await tester.pumpWidget(build(640));
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(152.5, 76.25));
    expect(tester.getTopLeft(find.byKey(ValueKey(4))), Offset(0, 82.25));

    await tester.pumpWidget(build(100));
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(100, 50));
    expect(tester.getTopLeft(find.byKey(ValueKey(1))), Offset(0, 56));
    expect(tester.takeException(), isNull);
  });

  testWidgets('crossAxisCount 与 mainAxisExtent 给出固定格尺寸，gap 同时作用于两个方向', (tester) async {
    await tester.pumpWidget(
      _host(
        100,
        ElSliverGrid(
          crossAxisCount: 2,
          mainAxisExtent: 10,
          gap: 4,
          children: [for (var i = 0; i < 3; i++) SizedBox(key: ValueKey(i))],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(48, 10));
    expect(tester.getTopLeft(find.byKey(ValueKey(1))), Offset(52, 0));
    expect(tester.getTopLeft(find.byKey(ValueKey(2))), Offset(0, 14));
  });

  testWidgets('minCrossAxisExtent 取尽量多的列，maxCrossAxisExtent 取尽量少的列', (tester) async {
    Widget build({double? min, double? max}) => _host(
      300,
      ElSliverGrid(
        minCrossAxisExtent: min,
        maxCrossAxisExtent: max,
        crossAxisSpacing: 10,
        mainAxisExtent: 20,
        children: [for (var i = 0; i < 4; i++) SizedBox(key: ValueKey(i))],
      ),
    );

    await tester.pumpWidget(build(min: 100));
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(145, 20));
    expect(tester.getTopLeft(find.byKey(ValueKey(2))), Offset(0, 20));

    await tester.pumpWidget(build(max: 100));
    expect(tester.getSize(find.byKey(ValueKey(0))).width, closeTo(280 / 3, 1e-9));
    expect(tester.getTopLeft(find.byKey(ValueKey(3))), Offset(0, 20));
  });

  testWidgets('横向 itemWidth 按物理宽高比换算行高，再按可用高度取行数', (tester) async {
    await tester.pumpWidget(
      _host(
        400,
        height: 104,
        direction: .horizontal,
        ElSliverGrid(
          itemWidth: 100,
          aspectRatio: 2,
          mainAxisSpacing: 6,
          crossAxisSpacing: 4,
          children: [for (var i = 0; i < 5; i++) SizedBox(key: ValueKey(i))],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(ValueKey(0))), Size(100, 50));
    expect(tester.getTopLeft(find.byKey(ValueKey(1))), Offset(0, 54));
    expect(tester.getTopLeft(find.byKey(ValueKey(2))), Offset(106, 0));
  });

  testWidgets('固定格尺寸的 builder 不做探测构建，远跳只构建目标窗口', (tester) async {
    final built = <int>{};
    final controller = ScrollController(initialScrollOffset: 10000);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 300,
            height: 600,
            child: ElScrollView.sliver(
              controller: controller,
              scrollCacheExtent: ScrollCacheExtent.pixels(0),
              slivers: [
                ElSliverGrid.builder(
                  itemCount: 10000,
                  crossAxisCount: 3,
                  mainAxisExtent: 100,
                  itemBuilder: (context, index) => _Probe(index, built),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // 偏移 10000 对应第 100 行；视口 600 高恰好容纳 6 行。
    expect(built, {for (var i = 300; i < 318; i++) i});
    expect(tester.getTopLeft(find.byKey(ValueKey(300))), Offset(0, 0));
    expect(controller.position.maxScrollExtent, (10000 / 3).ceil() * 100.0 - 600);
  });

  testWidgets('未指定格尺寸时保持自然测量，行高取最高条目', (tester) async {
    final built = <int>{};
    await tester.pumpWidget(
      _host(
        300,
        ElSliverGrid.builder(
          itemCount: 6,
          itemWidth: 100,
          gap: 0,
          itemBuilder: (context, index) => _Probe(index, built, height: 20.0 + index * 10),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(ValueKey(3))), Offset(0, 40));
    expect(tester.getTopLeft(find.byKey(ValueKey(5))), Offset(200, 40));
  });

  testWidgets('瀑布流同样支持自适应列数', (tester) async {
    await tester.pumpWidget(
      _host(
        310,
        ElSliverMasonry(
          itemWidth: 150,
          gap: 10,
          children: [for (var i = 0; i < 3; i++) SizedBox(key: ValueKey(i), height: 40.0 + i * 20)],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(ValueKey(0))).width, 150);
    expect(tester.getTopLeft(find.byKey(ValueKey(1))), Offset(160, 0));
    // 第三项落在较短的第一列。
    expect(tester.getTopLeft(find.byKey(ValueKey(2))), Offset(0, 50));
  });

  testWidgets('列数声明冲突或缺失时断言失败', (tester) async {
    await tester.pumpWidget(_host(300, ElSliverGrid(crossAxisCount: 3, minCrossAxisExtent: 80, children: [])));
    expect(tester.takeException(), isAssertionError);
    await tester.pumpWidget(_host(300, ElSliverGrid(key: ValueKey('none'), children: [])));
    expect(tester.takeException(), isAssertionError);
  });
}
