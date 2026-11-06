import 'package:example/src/pages/examples/recycler_view/takeaway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('菜单已挂接但尚未布局时连续换绑，恢复最后一家店的位置', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final content = ValueNotifier<Widget>(SizedBox());
    addTearDown(content.dispose);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(
          home: Stack(
            children: [
              RecyclerTakeawayPage(),
              ValueListenableBuilder<Widget>(
                valueListenable: content,
                builder: (context, child, _) => Align(
                  alignment: .topLeft,
                  child: SingleChildScrollView(child: SizedBox(width: 390, child: child)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView));
    list.scrollToPosition(24);
    await tester.pumpAndSettle();
    final menu = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.identifier == 'takeaway-menu-24'),
      matching: find.byType(ListView),
    );
    tester.widget<ListView>(menu).controller!.jumpTo(240);
    await tester.pumpAndSettle();
    final adapter = list.getAdapter()!;
    final holder = adapter.createViewHolder(list, 0);
    adapter.bindViewHolder(holder, 0);
    content.value = holder.itemView;
    // 只执行构建：真实 Scrollable 已 attach，但 RenderViewport 尚未建立滚动范围。
    await tester.pump(Duration.zero, EnginePhase.build);
    final root = find.byWidget(holder.itemView, skipOffstage: false);
    final controller = tester
        .widget<ListView>(
          find.descendant(of: root, matching: find.byType(ListView, skipOffstage: false), skipOffstage: false),
        )
        .controller!;
    expect(controller.hasClients, isTrue);
    expect(controller.position.hasContentDimensions, isFalse);
    for (final id in [24, 48, 24]) {
      adapter.bindViewHolder(holder, id);
      await tester.pump(Duration.zero, EnginePhase.build);
      expect(tester.takeException(), isNull);
      expect(controller.position.hasContentDimensions, isFalse);
      expect(controller.position.pixels, id == 24 ? 240 : 0);
    }
    await tester.pumpAndSettle();
    expect(controller.position.hasContentDimensions, isTrue);
    expect(controller.position.pixels, closeTo(240, .1));
    final title = tester.widget<ElView>(find.descendant(of: root, matching: find.byKey(ValueKey('takeaway-title'))));
    expect(title.child, contains('25店'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
