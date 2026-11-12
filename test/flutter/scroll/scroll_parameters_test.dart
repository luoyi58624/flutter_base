import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  testWidgets('默认 children 将重绘、语义和 spacing 交给 ElSliverList', (tester) async {
    for (final enabled in [false, true]) {
      await tester.pumpWidget(
        _host(
          ElScrollView(
            spacing: 8,
            addRepaintBoundaries: enabled,
            addSemanticIndexes: enabled,
            children: [
              SizedBox(height: 20, child: Text('a')),
              SizedBox(height: 20, child: Text('b')),
            ],
          ),
        ),
      );
      final sliver = tester.widget<ElSliverList>(find.byWidgetPredicate((widget) => widget is ElSliverList));
      expect(sliver.spacing, 8);
      expect(sliver.addRepaintBoundaries, enabled);
      expect(sliver.addSemanticIndexes, enabled);
      expect(find.byType(IndexedSemantics), enabled ? findsNWidgets(2) : findsNothing);
      expect(tester.getTopLeft(find.text('b')).dy - tester.getTopLeft(find.text('a')).dy, 28);
    }
  });

  for (final shrinkWrap in [false, true]) {
    testWidgets('scrollCacheExtent 默认 250、自定义范围与视口倍数 shrinkWrap=$shrinkWrap', (tester) async {
      tester.view.physicalSize = Size(360, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Future<int> mount(ScrollCacheExtent? cache, {bool omitted = false}) async {
        var builds = 0;
        final sliver = ElSliverList.builder(
          itemCount: 1000,
          itemBuilder: (_, i) {
            builds++;
            return SizedBox(height: 50);
          },
        );
        await tester.pumpWidget(SizedBox.shrink());
        await tester.pumpWidget(
          _host(
            omitted
                ? ElScrollView.sliver(controller: controller, shrinkWrap: shrinkWrap, slivers: [sliver])
                : ElScrollView.sliver(
                    controller: controller,
                    shrinkWrap: shrinkWrap,
                    scrollCacheExtent: cache,
                    slivers: [sliver],
                  ),
          ),
        );
        final viewport = tester.renderObject<RenderViewportBase>(
          find.byWidgetPredicate((w) => shrinkWrap ? w is ShrinkWrappingViewport : w is Viewport),
        );
        expect(viewport.scrollCacheExtent.value, omitted ? 250 : cache!.value);
        expect(tester.takeException(), isNull);
        return builds;
      }

      final visible = await mount(ScrollCacheExtent.pixels(0));
      final cached = await mount(null, omitted: true);
      final viewportCache = await mount(ScrollCacheExtent.viewport(1));
      expect(visible, 5);
      expect(cached, 10);
      expect(viewportCache, 10);
    });
  }

  testWidgets('primary 继承控制器，标准输入与恢复参数抵达 Scrollable', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final behavior = ScrollBehavior().copyWith(dragDevices: {PointerDeviceKind.stylus});
    await tester.pumpWidget(
      _host(
        PrimaryScrollController(
          controller: controller,
          child: ElScrollView(
            primary: true,
            scrollBehavior: behavior,
            dragStartBehavior: DragStartBehavior.down,
            restorationId: 'scroll-position',
            semanticChildCount: 2,
            hitTestBehavior: HitTestBehavior.translucent,
            children: [SizedBox(height: 900), SizedBox(height: 900)],
          ),
        ),
      ),
    );
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
    expect(controller.hasClients, isTrue);
    expect(scrollable.scrollBehavior, same(behavior));
    expect(scrollable.dragStartBehavior, DragStartBehavior.down);
    expect(scrollable.restorationId, 'scroll-position');
    expect(scrollable.semanticChildCount, 2);
    expect(scrollable.hitTestBehavior, HitTestBehavior.translucent);
    controller.jumpTo(100);
    await tester.pump();
    expect(Scrollable.of(tester.element(find.byWidgetPredicate((w) => w is Viewport))).position.pixels, 100);
  });

  testWidgets('center、anchor 与 paintOrder 抵达视口', (tester) async {
    final center = ValueKey('center');
    await tester.pumpWidget(
      _host(
        ElScrollView.sliver(
          center: center,
          anchor: .5,
          paintOrder: SliverPaintOrder.lastIsTop,
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 100)),
            SliverToBoxAdapter(key: center, child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
    final viewport = tester.widget<Viewport>(find.byWidgetPredicate((w) => w is Viewport));
    expect(viewport.center, center);
    expect(viewport.anchor, .5);
    expect(viewport.paintOrder, SliverPaintOrder.lastIsTop);
    final render = tester.renderObject<RenderViewport>(find.byWidgetPredicate((w) => w is Viewport));
    expect(render.anchor, .5);
    expect(render.paintOrder, SliverPaintOrder.lastIsTop);
  });

  for (final behavior in HitTestBehavior.values) {
    testWidgets('空白视口命中行为 $behavior', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: SizedBox.expand()),
              ),
              Positioned.fill(
                child: ElScrollView(hitTestBehavior: behavior, children: []),
              ),
            ],
          ),
        ),
      );
      await tester.tapAt(Offset(100, 100));
      expect(taps, behavior == HitTestBehavior.opaque ? 0 : 1);
    });
  }
}
