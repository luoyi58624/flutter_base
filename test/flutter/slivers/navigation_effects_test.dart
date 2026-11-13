import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget scroll) => MaterialApp(
  home: Scaffold(
    body: ScrollConfiguration(
      behavior: ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
      child: SizedBox(width: 320, height: 480, child: scroll),
    ),
  ),
);

void main() {
  testWidgets('普通折叠使用官方 PersistentHeader 并提供准确折叠进度', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    double progress = -1;
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          physics: ClampingScrollPhysics(),
          slivers: [
            ElSliverCollapse.scroll(
              minExtent: 56,
              maxExtent: 156,
              builder: (context, value) {
                progress = value;
                return ColoredBox(color: Colors.white, child: Text('普通折叠'));
              },
            ),
            SliverToBoxAdapter(child: SizedBox(height: 1600)),
          ],
        ),
      ),
    );
    expect(find.byType(SliverPersistentHeader), findsOneWidget);
    expect(progress, closeTo(0, .01));
    controller.jumpTo(60);
    await tester.pump();
    expect(progress, closeTo(.6, .01));
    controller.jumpTo(300);
    await tester.pump();
    expect(progress, closeTo(1, .01));
  });

  testWidgets('方向浮现直接复用官方 SliverFloatingHeader', (tester) async {
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          slivers: [
            ElSliverCollapse.floating(child: SizedBox(height: 56, child: Text('方向浮现'))),
            SliverToBoxAdapter(child: SizedBox(height: 1500)),
          ],
        ),
      ),
    );
    expect(find.byType(SliverFloatingHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('优先折叠：搜索区始终在频道栏上方，折叠时频道栏向上移动并吸顶', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          physics: ClampingScrollPhysics(),
          slivers: [
            ElSliverCollapse.priority(
              compact: Text('固定频道'),
              content: Text('搜索内容'),
              compactExtent: 43,
              contentExtent: 58,
              holdSnapDelay: Duration(milliseconds: 200),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 1800)),
          ],
        ),
      ),
    );
    controller.jumpTo(500);
    await tester.pump();
    final search = find.text('搜索内容');
    final tabs = find.text('固定频道');
    final before = tester.getTopLeft(tabs).dy;
    expect(tester.getTopLeft(search).dy, lessThan(before));

    final gesture = await tester.startGesture(Offset(140, 200));
    await gesture.moveBy(Offset(0, -59));
    await tester.pump();
    expect(tester.getTopLeft(tabs).dy, closeTo(before - 58, 1));
    expect(controller.offset, closeTo(501, .01), reason: '页头消耗 58px 后，仅剩余 1px 才能进入正文');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('优先折叠：在正文中段优先吸收拖拽，按住停止移动后按 50% 自动吸附', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final progress = <double>[];
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          physics: ClampingScrollPhysics(),
          slivers: [
            ElSliverCollapse.priority(
              compact: Text('固定频道'),
              content: Text('搜索内容'),
              compactExtent: 56,
              contentExtent: 58,
              holdSnapDelay: Duration(milliseconds: 100),
              snapDuration: Duration(milliseconds: 150),
              onProgressChanged: progress.add,
            ),
            SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );
    controller.jumpTo(500);
    await tester.pump();
    final start = controller.offset;

    final gesture = await tester.startGesture(Offset(150, 200));
    await gesture.moveBy(Offset(0, -40));
    await tester.pump();
    expect(controller.offset, closeTo(start, .01), reason: '在任何正文位置先缩进头部，不能滚动正文');
    expect(progress.last, greaterThan(.5));
    await tester.pump(Duration(milliseconds: 120));
    await tester.pump(Duration(milliseconds: 180));
    expect(controller.offset, closeTo(start, .01), reason: '手指未松开，吸附不得挪动正文');
    final content = find.text('搜索内容');
    final opacity = tester.widget<Opacity>(find.ancestor(of: content, matching: find.byType(Opacity)).first);
    expect(opacity.opacity, closeTo(0, .01), reason: '过半并停住按压时自动折叠到尽头');

    await gesture.moveBy(Offset(0, 42));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 120));
    await tester.pump(Duration(milliseconds: 180));
    final resumed = tester.widget<Opacity>(find.ancestor(of: content, matching: find.byType(Opacity)).first);
    expect(resumed.opacity, closeTo(1, .01), reason: '回拉超过一半、持续按住应自动展开');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('优先折叠：在正文中段和滚动起点都先消费滚轮，随后按阈值吸附', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          physics: ClampingScrollPhysics(),
          slivers: [
            ElSliverCollapse.priority(
              compact: Text('频道导航'),
              content: Text('搜索内容'),
              compactExtent: 56,
              contentExtent: 58,
              holdSnapDelay: Duration(milliseconds: 100),
              snapDuration: Duration(milliseconds: 150),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 1800)),
          ],
        ),
      ),
    );

    Future<void> wheel(double delta) => tester.sendEventToBinding(
      PointerScrollEvent(position: Offset(160, 230), scrollDelta: Offset(0, delta), kind: PointerDeviceKind.mouse),
    );

    controller.jumpTo(500);
    await tester.pump();
    await wheel(40);
    await tester.pump();
    expect(controller.offset, closeTo(500, .01), reason: '滚轮也应先折叠页头，而不是直接移动正文');
    var contentOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('搜索内容'), matching: find.byType(Opacity)).first,
    );
    expect(contentOpacity.opacity, lessThan(.5));
    await tester.pump(Duration(milliseconds: 110));
    await tester.pump(Duration(milliseconds: 180));
    controller.jumpTo(0);
    await tester.pump();

    await wheel(-42);
    await tester.pump();
    expect(controller.offset, closeTo(0, .01), reason: '正文已经到顶部时，反向滚轮仍能展开页头');
    contentOpacity = tester.widget<Opacity>(find.ancestor(of: find.text('搜索内容'), matching: find.byType(Opacity)).first);
    expect(contentOpacity.opacity, greaterThan(.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('优先折叠：折叠额度耗尽后，同一次拖拽剩余量进入正文', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          physics: ClampingScrollPhysics(),
          slivers: [
            ElSliverCollapse.priority(
              compact: Text('标签栏'),
              content: Text('搜索区域'),
              compactExtent: 56,
              contentExtent: 58,
            ),
            SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );
    controller.jumpTo(400);
    await tester.pump();
    final gesture = await tester.startGesture(Offset(150, 210));
    await gesture.moveBy(Offset(0, -110));
    await tester.pump();
    expect(controller.offset, greaterThan(420));
    final opacity = tester.widget<Opacity>(find.ancestor(of: find.text('搜索区域'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, closeTo(0, .001));
    await gesture.up();
  });

  testWidgets('优先折叠：页头展开后，拉距剩余部分交给 SliverRefresh', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    ElRefreshDetails? refreshDetails;
    var calls = 0;
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          physics: ClampingScrollPhysics(),
          slivers: [
            ElSliverCollapse.priority(compact: Text('导航'), content: Text('搜索内容'), compactExtent: 56, contentExtent: 58),
            ElSliverRefresh(
              refresher: ElCustomRefresher(
                triggerExtent: 60,
                movesContent: false,
                builder: (context, details) {
                  refreshDetails = details;
                  return SizedBox.expand();
                },
              ),
              onRefresh: () async => calls++,
            ),
            SliverToBoxAdapter(child: SizedBox(height: 1600)),
          ],
        ),
      ),
    );

    final collapse = await tester.startGesture(Offset(160, 200));
    await collapse.moveBy(Offset(0, -45));
    await tester.pump();
    await collapse.up();
    await tester.pumpAndSettle();
    controller.jumpTo(0);
    await tester.pump();

    final pull = await tester.startGesture(Offset(160, 250));
    await pull.moveBy(Offset(0, 150));
    await tester.pump();
    expect(controller.offset, closeTo(0, .01));
    expect(refreshDetails!.snapshot.value.status, RefreshIndicatorStatus.armed);
    await pull.up();
    await tester.pump(Duration(milliseconds: 1));
    expect(calls, 1, reason: '搜索栏用掉自己的展开行程后，下拉余量应该触发刷新');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('LargeTitle 底部搜索控件自然测高且保留同一个 Element', (tester) async {
    final controller = ScrollController();
    final searchKey = GlobalKey();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          slivers: [
            ElSliverLargeTitle(
              title: '书库',
              bottom: SizedBox(key: searchKey, height: 48, child: TextField()),
              bottomPadding: EdgeInsets.only(bottom: 12, left: 16, right: 16),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 1500)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(searchKey), findsOneWidget);
    final element = tester.element(find.byKey(searchKey));
    final header = tester.renderObject(find.byType(SliverResizingHeader)) as RenderSliver;
    expect(header.geometry!.scrollExtent, greaterThan(56 + 48 + 12));
    controller.jumpTo(70);
    await tester.pump();
    expect(tester.element(find.byKey(searchKey)), same(element));
    expect(tester.takeException(), isNull);
  });

  testWidgets('LargeTitle 缩放型文字朝紧凑导航移动，而不是在原地渐隐', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          slivers: [
            ElSliverLargeTitle(title: '收藏', leading: Icon(Icons.arrow_back)),
            SliverToBoxAdapter(child: SizedBox(height: 1400)),
          ],
        ),
      ),
    );
    await tester.pump();
    final header = tester.renderObject(find.byType(SliverResizingHeader)) as RenderSliver;
    final range = header.geometry!.scrollExtent - 56;
    final title = find.text('收藏');
    final large = find.ancestor(of: title.last, matching: find.byType(Transform)).last;
    final initialTransform = tester.widget<Transform>(large);
    expect(initialTransform.transform.storage[13], closeTo(0, .01));
    controller.jumpTo(range / 2);
    await tester.pump();
    final translated = tester.widget<Transform>(large);
    expect(translated.transform.storage[13], lessThan(-10), reason: '标题必须向紧凑导航的实际位置上移');
    controller.jumpTo(range);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('LargeTitle 使用官方自然测高，缩入固定导航，不指定展开高度', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          physics: ClampingScrollPhysics(),
          slivers: [
            ElSliverLargeTitle(title: '收藏', backgroundColor: Colors.white),
            SliverToBoxAdapter(child: SizedBox(height: 1800)),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SliverResizingHeader), findsOneWidget);
    final render = tester.renderObject(find.byType(SliverResizingHeader));
    expect(render, isA<RenderSliver>());
    final sliver = render as RenderSliver;
    expect(sliver.geometry!.scrollExtent, greaterThan(56), reason: '展开高度由文字自然测得');
    controller.jumpTo(150);
    await tester.pump();
    final compact = tester.widgetList<Opacity>(find.byType(Opacity)).map((opacity) => opacity.opacity);
    expect(compact.any((opacity) => opacity > .999), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('浮动折叠开启吸附后，反向滚动停下时用官方动画吸附到端点', (tester) async {
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          physics: ClampingScrollPhysics(),
          slivers: [
            ElSliverCollapse.scroll(
              minExtent: 0,
              maxExtent: 100,
              pinned: false,
              floating: true,
              snap: true,
              builder: (context, value) => ColoredBox(color: Colors.white, child: Text('浮动吸附')),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );
    await tester.drag(find.byType(ElScrollView), Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ElScrollView), Offset(0, 50));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final header = tester.renderObject(find.byType(SliverPersistentHeader)) as RenderSliver;
    expect(header.geometry!.paintExtent, 100, reason: '露出一部分后停下，应吸附到完全展开。');
  });

  testWidgets('大标题前面还有其他 Sliver 时，吸附按自身的折叠进度取端点', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ElScrollView.sliver(
          controller: controller,
          physics: ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 100)),
            ElSliverLargeTitle(title: '收藏', snap: true),
            SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 滚过前置内容后只折叠了一小段，应回到大标题完全展开的位置，而不是停在半折叠。
    await tester.drag(find.byType(ElScrollView), Offset(0, -130));
    await tester.pumpAndSettle();
    expect(controller.offset, 100);
  });
}
