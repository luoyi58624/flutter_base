import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) => Directionality(
  textDirection: direction,
  child: Align(
    alignment: .topLeft,
    child: ElView(style: ElStyle(width: 600, height: 600), child: child),
  ),
);

void main() {
  for (final axis in Axis.values) {
    for (final reverse in [false, true]) {
      for (final direction in TextDirection.values) {
        for (final offset in [0.0, 42000.0]) {
          testWidgets('实测冷启动 $axis reverse=$reverse $direction offset=$offset', (tester) async {
            final controller = ElScrollController(initialScrollOffset: offset);
            addTearDown(controller.dispose);
            final key = GlobalKey<ElScrollViewState>();
            final built = <int>[];
            await tester.pumpWidget(
              _host(
                ElScrollView(
                  key: key,
                  axis: axis,
                  reverse: reverse,
                  controller: controller,
                  cacheExtent: 900,
                  scrollbar: ElNoScrollBar(),
                  children: [
                    ElListView.builder(
                      keepAlive: true,
                      itemCount: 10000,
                      itemBuilder: (_, index) {
                        built.add(index);
                        return ElView(
                          key: ValueKey(index),
                          style: axis == Axis.vertical ? ElStyle(height: 420) : ElStyle(width: 420),
                        );
                      },
                    ),
                  ],
                ),
                direction: direction,
              ),
            );
            final reversed = reverse != (axis == Axis.horizontal && direction == TextDirection.rtl);
            expect(built.take(4), reversed ? [9999, 9998, 9997, 9996] : [0, 1, 2, 3]);
            expect(built.length, offset == 0 ? 4 : 11);
            expect(controller.offset, offset);
            expect(controller.position.maxScrollExtent, 4200000 - 600);
            final visibleIndex = reversed ? 9999 - offset ~/ 420 : offset ~/ 420;
            final rect = tester.getRect(find.byKey(ValueKey(visibleIndex)));
            expect(
              axis == Axis.vertical ? (reversed ? rect.bottom : rect.top) : (reversed ? rect.right : rect.left),
              reversed ? 600 : 0,
            );
            expect(key.currentState!.debugCounters.debugLayoutChildVisitCount, lessThanOrEqualTo(24));
            await tester.pumpAndSettle();
            expect(built.length, offset == 0 ? 4 : 11);
            expect(controller.offset, offset);
            controller.jumpTo(84000);
            await tester.pumpAndSettle();
            expect(controller.offset, 84000);
            expect(built.length, lessThan(30));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  for (final reverse in [false, true]) {
    testWidgets('缓存边界落在间距内时不构建下一项 reverse=$reverse', (tester) async {
      final built = <int>[];
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          ElScrollView(
            reverse: reverse,
            controller: controller,
            padding: .symmetric(vertical: 30),
            cacheExtent: 0,
            scrollbar: ElNoScrollBar(),
            children: [
              ElListView.builder(
                keepAlive: true,
                gap: 200,
                itemCount: 100,
                itemBuilder: (_, index) {
                  built.add(index);
                  return ElView(key: ValueKey(index), style: ElStyle(height: 420));
                },
              ),
            ],
          ),
        ),
      );
      expect(built, reverse ? [99] : [0]);
      final rect = tester.getRect(find.byKey(ValueKey(reverse ? 99 : 0)));
      expect(reverse ? rect.bottom : rect.top, reverse ? 570 : 30);
      expect(controller.position.maxScrollExtent, 420 * 100 + 200 * 99 + 60 - 600);
      await tester.pumpAndSettle();
      expect(built.length, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('全零条目完整测量后停止，后续新内容仍能建立滚动范围', (tester) async {
    final controller = ElScrollController();
    addTearDown(controller.dispose);
    var count = 20;
    final built = <int>[];
    Widget content() => _host(
      ElScrollView(
        controller: controller,
        scrollbar: ElNoScrollBar(),
        children: [
          ElListView.builder(
            itemCount: count,
            itemBuilder: (_, index) {
              built.add(index);
              return ElView(style: ElStyle(height: index < 20 ? 0 : 420));
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(content());
    await tester.pumpAndSettle();
    expect(built.toSet(), Set.of(List.generate(20, (i) => i)));
    expect(controller.position.maxScrollExtent, 0);
    count = 100;
    await tester.pumpWidget(content());
    await tester.pumpAndSettle();
    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
