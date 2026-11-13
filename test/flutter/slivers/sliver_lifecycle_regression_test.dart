import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(List<Widget> slivers, {ScrollController? controller, double height = 300}) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: SizedBox(
      width: 300,
      height: height,
      child: CustomScrollView(controller: controller, scrollCacheExtent: ScrollCacheExtent.pixels(0), slivers: slivers),
    ),
  ),
);

class _Tracked extends StatefulWidget {
  const _Tracked(this.label, this.log, {super.key, this.height = 10});
  final String label;
  final List<String> log;
  final double height;
  @override
  State<_Tracked> createState() => _TrackedState();
}

class _TrackedState extends State<_Tracked> {
  @override
  void initState() {
    super.initState();
    widget.log.add('init ${widget.label}');
  }

  @override
  void dispose() {
    widget.log.add('dispose ${widget.label}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: widget.height);
}

void main() {
  testWidgets('jumpToIndex 在 SliverPadding 内、列表起点未到视口顶端时仍对齐目标', (tester) async {
    final list = ElSliverRecyclerController();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _host(controller: scroll, [
        SliverToBoxAdapter(child: SizedBox(height: 100)),
        SliverPadding(
          padding: EdgeInsets.only(top: 50),
          sliver: ElSliverList.recycler(
            itemCount: 100,
            controller: list,
            itemBuilder: (context, index) => SizedBox(
              height: 40,
              child: ValueListenableBuilder<int>(
                valueListenable: index,
                builder: (context, value, child) => Text('item $value'),
              ),
            ),
          ),
        ),
      ]),
    );
    expect(scroll.offset, 0);

    final done = list.jumpToIndex(20);
    await tester.pump();
    await tester.pump();
    expect(await done, isTrue);
    // 列表前有 100 高的头部和 50 的顶部留白，第 20 项在列表内的起点是 800。
    expect(scroll.offset, 950);
    expect(tester.getTopLeft(find.text('item 20')).dy, 0);
  });

  testWidgets('builder 数量变化重新测量时，窗口内条目不会先销毁再重建', (tester) async {
    final log = <String>[];
    // 首项远高于其余条目：按首项估值得到的窗口比真实窗口小得多。
    Widget build(int count) => _host([
      ElSliverList.builder(
        itemCount: count,
        itemBuilder: (context, index) => _Tracked('$index', log, height: index == 0 ? 100 : 10),
      ),
    ]);

    await tester.pumpWidget(build(50));
    expect(log, [for (var i = 0; i <= 20; i++) 'init $i']);
    log.clear();

    await tester.pumpWidget(build(51));
    expect(log, isEmpty, reason: '仍在窗口内的条目必须保留 State。');
  });

  testWidgets('builder 按 Key 重排与原地槽位撞到同一序号时，被占位的槽位正常卸载', (tester) async {
    final log = <String>[];
    Widget build(List<Widget> items) => _host([
      ElSliverList.builder(
        itemCount: items.length,
        findChildIndexCallback: (key) {
          final index = items.indexWhere((item) => item.key == key);
          return index < 0 ? null : index;
        },
        itemBuilder: (context, index) => items[index],
      ),
    ]);

    await tester.pumpWidget(build([_Tracked('plain', log), _Tracked('keyed', log, key: ValueKey('keyed'))]));
    expect(log, ['init plain', 'init keyed']);
    log.clear();

    // keyed 移到序号 0，与没有 Key、留在序号 0 的 plain 冲突。
    await tester.pumpWidget(build([_Tracked('keyed', log, key: ValueKey('keyed')), _Tracked('tail', log)]));
    expect(log, containsAll(['dispose plain', 'init tail']));
    expect(log, isNot(contains('init keyed')), reason: '带 Key 的条目随 Key 移动并保留 State。');
    expect(tester.takeException(), isNull);

    log.clear();
    await tester.pumpWidget(SizedBox());
    expect(log, unorderedEquals(['dispose keyed', 'dispose tail']));
  });
}
