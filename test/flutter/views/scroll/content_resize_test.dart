import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _ResizableItem extends StatefulWidget {
  const _ResizableItem({super.key});

  @override
  State<_ResizableItem> createState() => _ResizableItemState();
}

class _ResizableItemState extends State<_ResizableItem> {
  double extent = 100;

  void resize(double value) => setState(() => extent = value);

  @override
  Widget build(BuildContext context) => ElView(
    style: ElStyle(width: extent, height: extent),
  );
}

Widget _frame(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElView(
    style: ElStyle(alignment: .topLeft),
    child: ElView(style: ElStyle(width: 300, height: 300), child: child),
  ),
);

void main() {
  testWidgets('默认首个可见成员变高时保留像素位置，后面的成员自然下移', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final item = GlobalKey<_ResizableItemState>();
    final following = GlobalKey();
    await tester.pumpWidget(
      _frame(
        ElScrollView(
          controller: controller,
          scrollbar: ElNoScrollBar(),
          children: [
            ElView(style: ElStyle(height: 400)),
            _ResizableItem(key: item),
            ElView(key: following, style: ElStyle(height: 800)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(400);
    await tester.pump();
    final itemTop = tester.getTopLeft(find.byKey(item)).dy;
    final followingTop = tester.getTopLeft(find.byKey(following)).dy;

    item.currentState!.resize(300);
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(Duration(milliseconds: 16));
      expect(controller.offset, 400, reason: '真实内容增长不得作为滚动输入或强制保位');
      expect(tester.getTopLeft(find.byKey(item)).dy, itemTop);
      expect(tester.getTopLeft(find.byKey(following)).dy, followingTop + 200);
    }
  });

  for (final axis in Axis.values) {
    for (final reverse in [false, true]) {
      for (final virtual in [false, true]) {
        testWidgets('默认 $axis reverse=$reverse virtual=$virtual 已实测成员在视口前中后变高不改位置', (tester) async {
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final items = List.generate(12, (_) => GlobalKey<_ResizableItemState>());
          await tester.pumpWidget(
            _frame(
              ElScrollView(
                controller: controller,
                axis: axis,
                reverse: reverse,
                cacheExtent: 2000,
                scrollbar: ElNoScrollBar(),
                children: virtual
                    ? [
                        ElListView.builder(
                          itemCount: items.length,
                          itemBuilder: (_, index) => _ResizableItem(key: items[index]),
                        ),
                      ]
                    : [for (final key in items) _ResizableItem(key: key)],
              ),
            ),
          );
          await tester.pumpAndSettle();
          controller.jumpTo(400);
          await tester.pumpAndSettle();
          for (final index in [1, 4, 10]) {
            items[index].currentState!.resize(160);
            for (var frame = 0; frame < 4; frame++) {
              await tester.pump(Duration(milliseconds: 16));
              expect(controller.offset, 400, reason: '第 $index 项变高不得自动定位');
            }
          }
        });
      }
    }
  }

  for (final preserveAnchor in [false, true]) {
    testWidgets('preserveAnchor=$preserveAnchor 真实内容变高是否保住后续可见成员', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final item = GlobalKey<_ResizableItemState>();
      final following = GlobalKey();
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            controller: controller,
            preserveAnchor: preserveAnchor,
            scrollbar: ElNoScrollBar(),
            children: [
              ElView(style: ElStyle(height: 400)),
              _ResizableItem(key: item),
              ElView(key: following, style: ElStyle(height: 800)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(400);
      await tester.pump();
      final followingTop = tester.getTopLeft(find.byKey(following)).dy;
      item.currentState!.resize(300);
      await tester.pumpAndSettle();
      expect(controller.offset, preserveAnchor ? 600 : 400);
      expect(tester.getTopLeft(find.byKey(following)).dy, followingTop + (preserveAnchor ? 0 : 200));
    });

    for (final virtual in [false, true]) {
      testWidgets('preserveAnchor=$preserveAnchor virtual=$virtual 头部插入与删除成员', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final ids = List.generate(12, (index) => index);
        Widget row(int id) => ElView(key: ValueKey(id), style: ElStyle(height: 100), child: '$id');
        Widget page() => _frame(
          ElScrollView(
            controller: controller,
            preserveAnchor: preserveAnchor,
            cacheExtent: 2000,
            scrollbar: ElNoScrollBar(),
            children: virtual
                ? [
                    ElListView.builder(
                      itemCount: ids.length,
                      fixedSize: true,
                      itemBuilder: (_, index) => row(ids[index]),
                      findChildIndexCallback: (key) {
                        final index = ids.indexOf((key as ValueKey<int>).value);
                        return index < 0 ? null : index;
                      },
                    ),
                  ]
                : [for (final id in ids) row(id)],
          ),
        );
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        controller.jumpTo(400);
        await tester.pump();
        ids.insert(0, -1);
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(controller.offset, preserveAnchor ? 500 : 400);
        ids.removeAt(0);
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(controller.offset, 400);
      });
    }
  }

  testWidgets('默认内容缩短只在原位置超过新范围时回钳', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final item = GlobalKey<_ResizableItemState>();
    await tester.pumpWidget(
      _frame(
        ElScrollView(
          controller: controller,
          scrollbar: ElNoScrollBar(),
          children: [
            ElView(style: ElStyle(height: 400)),
            _ResizableItem(key: item),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    item.currentState!.resize(500);
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    item.currentState!.resize(100);
    await tester.pump();
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(controller.offset, 200);
  });
}
