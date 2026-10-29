import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(style: ElStyle(width: 300, height: 180), child: child),
  ),
);

void main() {
  for (final axis in Axis.values) {
    for (final keepAlive in [false, true]) {
      testWidgets('首帧按实测填满缓存窗且只构建一次 axis=$axis keepAlive=$keepAlive', (tester) async {
        final built = <int>[];
        final extents = [0.0, 20.0, 400.0, 10.0, 800.0];
        await tester.pumpWidget(
          _host(
            ElScrollView(
              axis: axis,
              cacheExtent: 100,
              scrollbar: ElNoScrollBar(),
              children: [
                ElListView.builder(
                  keepAlive: keepAlive,
                  itemCount: 100,
                  itemBuilder: (_, index) {
                    built.add(index);
                    final extent = index < extents.length ? extents[index] : 400.0;
                    return ElView(
                      key: ValueKey(index),
                      style: axis == Axis.vertical ? ElStyle(height: extent) : ElStyle(width: extent),
                    );
                  },
                ),
              ],
            ),
          ),
        );
        expect(built, [0, 1, 2], reason: '零高与短项之后的大项已覆盖视口及缓存，不得预构建后续条目');
        final rect = tester.getRect(find.byKey(ValueKey(2)));
        expect(axis == Axis.vertical ? rect.top : rect.left, 20);
        expect(axis == Axis.vertical ? rect.bottom : rect.right, 420);
        await tester.pumpAndSettle();
        expect(built, [0, 1, 2]);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final grid in [false, true]) {
    final name = grid ? 'Grid' : 'List';

    testWidgets('$name builder 保活只保留访问过的条目，回滚复用状态且离屏不绘制', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final scrollKey = GlobalKey<ElScrollViewState>();
      final built = <int>{};
      Widget itemBuilder(BuildContext context, int index) {
        built.add(index);
        return _Item(key: ValueKey(index));
      }

      await tester.pumpWidget(
        _host(
          ElScrollView(
            key: scrollKey,
            controller: controller,
            cacheExtent: 0,
            scrollbar: ElNoScrollBar(),
            children: [
              grid
                  ? ElGridView.builder(
                      keepAlive: true,
                      itemCount: 1000,
                      itemBuilder: itemBuilder,
                      crossAxisCount: 3,
                      mainAxisExtent: 30,
                    )
                  : ElListView.builder(keepAlive: true, itemCount: 1000, itemBuilder: itemBuilder, fixedSize: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.state<_ItemState>(find.byKey(ValueKey(3)));
      first.increment();
      controller.jumpTo(2100);
      await tester.pumpAndSettle();
      expect(first.mounted, isTrue);
      expect(built.length, lessThan(100));
      final dynamic viewport = scrollKey.currentState!.debugScrollMixinViewportRenderObject;
      expect(viewport.debugLastPaintedChildCount, lessThan(25));

      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.state(find.byKey(ValueKey(3))), same(first));
      expect(first.value, 1);
      await tester.pumpWidget(_host(ElView()));
      expect(first.mounted, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name builder 默认回收离屏条目，动态开关保活及时生效', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      Widget build({bool? keepAlive}) => _host(
        ElScrollView(
          controller: controller,
          cacheExtent: 0,
          scrollbar: ElNoScrollBar(),
          children: [
            grid
                ? ElGridView.builder(
                    keepAlive: keepAlive ?? false,
                    itemCount: 1000,
                    itemBuilder: (_, index) => _Item(key: ValueKey(index)),
                    crossAxisCount: 3,
                    mainAxisExtent: 30,
                  )
                : ElListView.builder(
                    keepAlive: keepAlive ?? false,
                    itemCount: 1000,
                    itemBuilder: (_, index) => _Item(key: ValueKey(index)),
                    fixedSize: true,
                  ),
          ],
        ),
      );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      final first = tester.state<_ItemState>(find.byKey(ValueKey(3)));
      controller.jumpTo(2100);
      await tester.pumpAndSettle();
      expect(first.mounted, isFalse);

      controller.jumpTo(0);
      await tester.pumpAndSettle();
      final second = tester.state<_ItemState>(find.byKey(ValueKey(3)));
      expect(second, isNot(same(first)));
      await tester.pumpWidget(build(keepAlive: true));
      controller.jumpTo(2100);
      await tester.pumpAndSettle();
      expect(second.mounted, isTrue);

      await tester.pumpWidget(build(keepAlive: false));
      await tester.pumpAndSettle();
      expect(second.mounted, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name builder 离屏保活随业务 key 重排和段位移，删除后销毁', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final items = List.generate(1000, (index) => index);
      Widget build({bool prefix = false}) {
        int? findIndex(Key key) {
          final index = items.indexOf((key as ValueKey<int>).value);
          return index < 0 ? null : index;
        }

        return _host(
          ElScrollView(
            controller: controller,
            cacheExtent: 0,
            scrollbar: ElNoScrollBar(),
            children: [
              if (prefix) ElView(style: ElStyle(height: 30)),
              grid
                  ? ElGridView.builder(
                      key: ValueKey('items'),
                      keepAlive: true,
                      itemCount: items.length,
                      itemBuilder: (_, index) => _Item(key: ValueKey(items[index])),
                      findChildIndexCallback: findIndex,
                      crossAxisCount: 3,
                      mainAxisExtent: 30,
                    )
                  : ElListView.builder(
                      key: ValueKey('items'),
                      keepAlive: true,
                      itemCount: items.length,
                      itemBuilder: (_, index) => _Item(key: ValueKey(items[index])),
                      findChildIndexCallback: findIndex,
                      fixedSize: true,
                    ),
            ],
          ),
        );
      }

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      final first = tester.state<_ItemState>(find.byKey(ValueKey(3)));
      first.increment();
      controller.jumpTo(2100);
      await tester.pumpAndSettle();
      items.remove(3);
      items.insert(600, 3);
      await tester.pumpWidget(build(prefix: true));
      await tester.pumpAndSettle();
      expect(tester.state(find.byKey(ValueKey(3))), same(first));
      expect(first.value, 1);

      items.remove(3);
      await tester.pumpWidget(build(prefix: true));
      await tester.pumpAndSettle();
      expect(first.mounted, isFalse);
      expect(find.byKey(ValueKey(3)), findsNothing);
      final remaining = tester.state<_ItemState>(find.byKey(ValueKey(4)));
      await tester.pumpWidget(_host(ElScrollView(controller: controller, scrollbar: ElNoScrollBar(), children: [])));
      await tester.pumpAndSettle();
      expect(remaining.mounted, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('无 key 的可变高度条目随段位移保活，数量缩减后释放越界条目', (tester) async {
    final controller = ElScrollController();
    addTearDown(controller.dispose);
    Widget build({bool prefix = false, int count = 1000}) => _host(
      ElScrollView(
        controller: controller,
        cacheExtent: 0,
        scrollbar: ElNoScrollBar(),
        children: [
          if (prefix) ElView(style: ElStyle(height: 60)),
          ElListView.builder(key: ValueKey('items'), keepAlive: true, itemCount: count, itemBuilder: (_, _) => _Item()),
        ],
      ),
    );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    final first = tester.state<_ItemState>(find.byType(_Item).at(3));
    controller.jumpTo(2100);
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(prefix: true));
    await tester.pumpAndSettle();
    expect(first.mounted, isTrue);
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_Item).at(3)), same(first));
    await tester.pumpWidget(build(prefix: true, count: 2));
    await tester.pumpAndSettle();
    expect(first.mounted, isFalse);
    expect(find.byType(_Item), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('保活布局段跨滚动容器移动保留离屏条目', (tester) async {
    final controller = ElScrollController();
    addTearDown(controller.dispose);
    final viewKey = GlobalKey();
    Widget build(bool moved) {
      final view = ElListView.builder(
        key: viewKey,
        keepAlive: true,
        fixedSize: true,
        itemCount: 1000,
        itemBuilder: (_, index) => _Item(key: ValueKey(index)),
      );
      return _host(
        Row(
          children: [
            Expanded(
              child: ElScrollView(
                key: ValueKey('left'),
                controller: controller,
                cacheExtent: 0,
                scrollbar: ElNoScrollBar(),
                children: moved ? [] : [view],
              ),
            ),
            Expanded(
              child: ElScrollView(
                key: ValueKey('right'),
                cacheExtent: 0,
                scrollbar: ElNoScrollBar(),
                children: [if (moved) view],
              ),
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();
    controller.jumpTo(2100);
    await tester.pumpAndSettle();
    final distant = tester.state<_ItemState>(find.byKey(ValueKey(72)));
    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();
    expect(tester.state(find.byKey(ValueKey(72))), same(distant));
    expect(tester.takeException(), isNull);
  });

  testWidgets('List builder 分隔项保活且不传入业务 key 回查', (tester) async {
    final controller = ElScrollController();
    addTearDown(controller.dispose);
    Widget build() => _host(
      ElScrollView(
        controller: controller,
        cacheExtent: 0,
        scrollbar: ElNoScrollBar(),
        children: [
          ElListView.builder(
            keepAlive: true,
            fixedSize: true,
            itemCount: 1000,
            itemBuilder: (_, index) => _Item(key: ValueKey(index)),
            separatorBuilder: (_, index) => _Item(key: ValueKey('separator-$index')),
            findChildIndexCallback: (key) => (key as ValueKey<int>).value,
          ),
        ],
      ),
    );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    final separator = tester.state<_ItemState>(find.byKey(ValueKey('separator-2')));
    controller.jumpTo(2100);
    await tester.pumpAndSettle();
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(tester.state(find.byKey(ValueKey('separator-2'))), same(separator));
    expect(tester.takeException(), isNull);
  });
}

class _Item extends StatefulWidget {
  const _Item({super.key});

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  int value = 0;

  void increment() => setState(() => value++);

  @override
  Widget build(BuildContext context) => ElView(style: ElStyle(height: 30), child: '$value');
}
