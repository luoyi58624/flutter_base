import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/views/scroll/refresh/refresher/android.dart' show buildAndroidRefreshSpinner;
import 'package:flutter_base/src/flutter/views/scroll/refresh/refresher/ios.dart' show buildIosRefreshSpinner;
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _Product {
  _Product(this.name);

  final String name;
}

Widget _host(Widget child, {double height = 300}) {
  return Directionality(
    textDirection: .ltr,
    child: ScrollConfiguration(
      behavior: ScrollBehavior().copyWith(overscroll: false, scrollbars: false),
      child: Align(
        alignment: .topLeft,
        child: SizedBox(width: 320, height: height, child: child),
      ),
    ),
  );
}

Widget _rows(BuildContext context, List<int> items) => SliverList.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => SizedBox(height: 60, child: Text('条目 ${items[index]}')),
);

Future<void> _pullToRefresh(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byType(ElScrollView)));
  await gesture.moveBy(Offset(0, 35));
  await tester.pump();
  await gesture.moveBy(Offset(0, 200));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('Model 和游标分页按配置距离触发，自定义底部加载，末页停止', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final requests = <String>[];
    final nextPage = Completer<ElInfiniteScrollPage<_Product, String>>();
    final footerKey = ValueKey('自定义加载');
    late List<_Product> snapshot;

    await tester.pumpWidget(
      _host(
        ElInfiniteScroll<_Product, String>(
          controller: controller,
          firstPageKey: 'first',
          loadDistance: 80,
          onLoadPage: (key) async {
            requests.add(key);
            if (key == 'next') return nextPage.future;
            return ElInfiniteScrollPage(
              items: List.generate(12, (index) => _Product('商品 $index')),
              nextPageKey: 'next',
            );
          },
          sliverBuilder: (context, items) {
            snapshot = items;
            return ElSliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => SizedBox(height: 60, child: Text(items[index].name)),
            );
          },
          loadingBuilder: (context) => SizedBox(key: footerKey, height: 64, child: Text('加载商品')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final firstSnapshot = snapshot;
    expect(() => firstSnapshot.add(_Product('修改')), throwsUnsupportedError);
    expect(requests, ['first']);

    final bottom = controller.position.maxScrollExtent;
    controller.jumpTo(bottom - 81);
    await tester.pumpAndSettle();
    expect(requests, ['first']);

    controller.jumpTo(bottom - 80);
    await tester.pumpAndSettle();
    expect(requests, ['first', 'next']);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(footerKey)).height, 64);

    controller.jumpTo(bottom - 1);
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(requests, ['first', 'next']);

    nextPage.complete(ElInfiniteScrollPage(items: [_Product('末页商品')]));
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('末页商品'), findsOneWidget);
    expect(firstSnapshot, hasLength(12));
    expect(snapshot, hasLength(13));
    expect(find.byKey(footerKey), findsNothing);
    expect(requests, ['first', 'next']);
  });

  testWidgets('Map 网格可以跳过空页，补到视口填满后等待滚动或尺寸变化', (tester) async {
    final requests = <int>[];
    final list = ElInfiniteScroll<Map<String, String>, int>(
      firstPageKey: 1,
      loadDistance: 0,
      onLoadPage: (page) async {
        requests.add(page);
        return ElInfiniteScrollPage(
          items: List.generate(switch (page) {
            1 => 0,
            3 => 10,
            _ => 2,
          }, (index) => {'name': '商品 $page-$index'}),
          nextPageKey: page == 4 ? null : page + 1,
        );
      },
      sliverBuilder: (context, items) => SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 72),
        itemCount: items.length,
        itemBuilder: (context, index) => Text(items[index]['name']!),
      ),
    );
    await tester.pumpWidget(_host(list));
    await tester.pumpAndSettle();
    expect(requests, [1, 2, 3]);
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('商品 2-0'), findsOneWidget);

    await tester.pumpWidget(_host(list, height: 500));
    await tester.pumpAndSettle();
    expect(requests, [1, 2, 3, 4]);
    expect(find.text('商品 4-0'), findsOneWidget);
  });

  testWidgets('iOS 使用现有刷新指示器，空数据可以自定义占位并下拉刷新', variant: TargetPlatformVariant({.iOS}), (tester) async {
    final firstPage = Completer<ElInfiniteScrollPage<int, int>>();
    final requests = <int>[];
    final spinner = find.byType(buildIosRefreshSpinner().runtimeType);
    await tester.pumpWidget(
      _host(
        ElInfiniteScroll<int, int>(
          firstPageKey: 1,
          onLoadPage: (page) async {
            requests.add(page);
            if (requests.length == 1) return firstPage.future;
            return ElInfiniteScrollPage(items: [10]);
          },
          sliverBuilder: _rows,
          emptyBuilder: (context) => LayoutBuilder(builder: (context, constraints) => Text('自定义空态')),
        ),
      ),
    );
    await tester.pump();
    expect(spinner, findsOneWidget);
    expect(find.text('自定义空态'), findsNothing);

    firstPage.complete(ElInfiniteScrollPage(items: []));
    await tester.pumpAndSettle();
    expect(find.text('自定义空态'), findsOneWidget);
    expect(spinner, findsNothing);

    await _pullToRefresh(tester);
    await tester.pumpAndSettle();
    expect(requests, [1, 1]);
    expect(find.text('自定义空态'), findsNothing);
    expect(find.text('条目 10'), findsOneWidget);
  });

  testWidgets('Android 底部加载使用现有刷新指示器', variant: TargetPlatformVariant({.android}), (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final nextPage = Completer<ElInfiniteScrollPage<int, int>>();
    final spinner = find.byType(buildAndroidRefreshSpinner().runtimeType);

    await tester.pumpWidget(
      _host(
        ElInfiniteScroll<int, int>(
          controller: controller,
          firstPageKey: 1,
          onLoadPage: (page) async {
            if (page == 2) return nextPage.future;
            return ElInfiniteScrollPage(items: List.generate(12, (index) => index), nextPageKey: 2);
          },
          sliverBuilder: _rows,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(spinner, findsNothing);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(spinner, findsOneWidget);

    nextPage.complete(ElInfiniteScrollPage(items: []));
    await tester.pumpAndSettle();
    expect(spinner, findsNothing);
  });

  testWidgets('追加失败保留已有数据，重试同一页且不会自动重复请求', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final requests = <int>[];
    final error = StateError('请求失败');
    late List<int> snapshot;

    await tester.pumpWidget(
      _host(
        ElInfiniteScroll<int, int>(
          controller: controller,
          firstPageKey: 1,
          loadDistance: 0,
          onLoadPage: (page) async {
            requests.add(page);
            if (page == 1) return ElInfiniteScrollPage(items: List.generate(10, (index) => index), nextPageKey: 2);
            if (requests.length == 2) throw error;
            return ElInfiniteScrollPage(items: [10]);
          },
          sliverBuilder: (context, items) {
            snapshot = items;
            return _rows(context, items);
          },
          errorBuilder: (context, failure, retry) {
            expect(failure, same(error));
            return ElButtonView(onPressed: retry, child: Text('自定义重试'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(snapshot, hasLength(10));
    expect(requests, [1, 2]);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(requests, [1, 2]);
    await tester.tap(find.text('自定义重试'));
    await tester.pumpAndSettle();
    expect(snapshot, List.generate(11, (index) => index));
    expect(find.text('自定义重试'), findsNothing);
    expect(requests, [1, 2, 2]);
  });

  testWidgets('下拉刷新优先，旧追加结果被忽略，刷新失败可从第一页重试', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final pendingAppend = Completer<ElInfiniteScrollPage<int, int>>();
    final pendingRefresh = Completer<ElInfiniteScrollPage<int, int>>();
    final requests = <int>[];
    late List<int> snapshot;
    ElRefreshDetails? refreshDetails;

    await tester.pumpWidget(
      _host(
        ElInfiniteScroll<int, int>(
          controller: controller,
          firstPageKey: 1,
          loadDistance: 0,
          onLoadPage: (page) async {
            requests.add(page);
            return switch (requests.length) {
              1 => ElInfiniteScrollPage(items: List.generate(10, (index) => index), nextPageKey: 2),
              2 => pendingAppend.future,
              3 => pendingRefresh.future,
              _ => ElInfiniteScrollPage(items: [100]),
            };
          },
          refresher: ElCustomRefresher(
            triggerExtent: 40,
            movesContent: false,
            builder: (context, details) {
              refreshDetails = details;
              return SizedBox.shrink();
            },
          ),
          sliverBuilder: (context, items) {
            snapshot = items;
            return _rows(context, items);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(requests, [1, 2]);

    controller.jumpTo(0);
    await tester.pump();
    await _pullToRefresh(tester);
    expect(requests, [1, 2, 1]);
    expect(refreshDetails!.snapshot.value.status, RefreshIndicatorStatus.refresh);

    pendingAppend.complete(ElInfiniteScrollPage(items: [900], nextPageKey: 3));
    pendingRefresh.completeError(StateError('刷新失败'));
    await tester.pumpAndSettle();
    expect(snapshot, List.generate(10, (index) => index));
    await tester.tap(find.text('加载失败，点击重试'));
    await tester.pumpAndSettle();
    expect(requests, [1, 2, 1, 1]);
    expect(snapshot, [100]);
    expect(find.text('条目 100'), findsOneWidget);
  });

  testWidgets('重复分页键停止自动请求并展示重试入口', (tester) async {
    final requests = <int>[];
    await tester.pumpWidget(
      _host(
        ElInfiniteScroll<int, int>(
          firstPageKey: 1,
          onLoadPage: (page) async {
            requests.add(page);
            return ElInfiniteScrollPage(items: [page], nextPageKey: page == 1 ? 2 : 1);
          },
          sliverBuilder: _rows,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, [1, 2]);
    expect(find.text('条目 1'), findsOneWidget);
    expect(find.text('条目 2'), findsNothing);
    expect(find.text('加载失败，点击重试'), findsOneWidget);
  });

  testWidgets('切换首键后旧请求不能写回，卸载后迟到的异常已被处理', (tester) async {
    final pendingFirst = Completer<ElInfiniteScrollPage<int, int>>();
    final pendingLast = Completer<ElInfiniteScrollPage<int, int>>();
    final requests = <int>[];
    Widget scene(int firstPageKey) => _host(
      ElInfiniteScroll<int, int>(
        firstPageKey: firstPageKey,
        onLoadPage: (page) async {
          requests.add(page);
          return switch (page) {
            1 => pendingFirst.future,
            2 => ElInfiniteScrollPage(items: [2]),
            _ => pendingLast.future,
          };
        },
        sliverBuilder: _rows,
      ),
    );

    await tester.pumpWidget(scene(1));
    await tester.pumpWidget(scene(2));
    await tester.pumpAndSettle();
    pendingFirst.complete(ElInfiniteScrollPage(items: [1], nextPageKey: 99));
    await tester.pumpAndSettle();
    expect(find.text('条目 1'), findsNothing);
    expect(find.text('条目 2'), findsOneWidget);

    await tester.pumpWidget(scene(3));
    await tester.pumpWidget(SizedBox.shrink());
    pendingLast.completeError(StateError('请求已过期'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(requests, [1, 2, 3]);
  });
}
