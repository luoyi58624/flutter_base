import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('面板直接继承局部样式和明暗变化，不重建业务内容', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    var dark = false, builds = 0;
    late StateSetter update;
    final panel = Builder(
      builder: (_) {
        builds++;
        return ElView(
          key: ValueKey('inherited-panel'),
          style: ElStyle(
            width: 120,
            height: 50,
            backgroundColor: Colors.white,
            onDark: ElStyle(backgroundColor: Colors.black),
          ),
          child: '内容',
        );
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return ElView(
              themeMode: ElThemeMode(brightness: dark ? Brightness.dark : Brightness.light, duration: Duration.zero),
              style: ElStyle(color: dark ? Colors.blue : Colors.red, fontSize: dark ? 22 : 14),
              child: ElPortal(controller: controller, panel: panel, child: SizedBox(width: 80, height: 30)),
            );
          },
        ),
      ),
    );
    controller.open();
    await settle(tester);
    final render = tester.renderObject<ElRenderView>(find.byKey(ValueKey('inherited-panel')));
    final before = builds;
    expect(render.committedResolvedStyle.inheritedText.color, Colors.red);
    update(() => dark = true);
    await settle(tester);
    expect(render.committedResolvedStyle.inheritedText.color, Colors.blue);
    expect(render.committedResolvedStyle.inheritedText.fontSize, 22);
    expect(render.committedResolvedStyle.box.backgroundColor, Colors.black);
    expect(builds, before);
  });

  testWidgets('同一面板换到另一局部样式祖先时保留 State 并更新继承', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    var right = false;
    late StateSetter update;
    final portal = ElPortal(
      key: GlobalKey(),
      controller: controller,
      panel: ElView(key: ValueKey('moved-panel'), style: ElStyle(width: 100, height: 50), child: '内容'),
      child: SizedBox(width: 80, height: 30),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Row(
              children: [
                ElView(
                  style: ElStyle(color: Colors.red),
                  child: right ? SizedBox() : portal,
                ),
                ElView(
                  style: ElStyle(color: Colors.blue),
                  child: right ? portal : SizedBox(),
                ),
              ],
            );
          },
        ),
      ),
    );
    controller.open();
    await settle(tester);
    final element = tester.element(find.byKey(ValueKey('moved-panel')));
    final render = tester.renderObject<ElRenderView>(find.byKey(ValueKey('moved-panel')));
    expect(render.committedResolvedStyle.inheritedText.color, Colors.red);
    update(() => right = true);
    await settle(tester);
    expect(controller.isOpen, isTrue);
    expect(tester.element(find.byKey(ValueKey('moved-panel'))), same(element));
    expect(render.committedResolvedStyle.inheritedText.color, Colors.blue);
  });

  testWidgets('同帧按树顺序的反序打开时，ESC 仍按实际打开顺序关闭栈顶', (tester) async {
    final first = ElPortalController();
    final second = ElPortalController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (final controller in [first, second])
              ElPortal(
                controller: controller,
                panel: SizedBox(width: 120, height: 60),
                captureFocus: false,
                restoreFocus: false,
                child: SizedBox(width: 80, height: 40),
              ),
          ],
        ),
      ),
    );
    second.open();
    first.open();
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(first.isOpen, isFalse);
    expect(second.isOpen, isTrue);
    // 不 pump：关闭栈顶后同帧即把 ESC 仲裁交回下一层。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(second.isOpen, isFalse);
    await settle(tester);
  });

  testWidgets('开启期 rootOverlay 变化不迁移，下一次打开使用新挂载点', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    var root = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 50, top: 40),
            child: SizedBox(
              width: 300,
              height: 200,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (_) => StatefulBuilder(
                      builder: (context, setState) {
                        update = setState;
                        return Stack(
                          children: [
                            Positioned(
                              left: 220,
                              top: 100,
                              child: ElPortal(
                                controller: controller,
                                rootOverlay: root,
                                anchor: ElOverlayAnchor(placement: .bottomStart),
                                panel: SizedBox(key: ValueKey('panel'), width: 200, height: 60),
                                child: SizedBox(width: 80, height: 40),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.open();
    await settle(tester);
    expect(tester.getTopLeft(find.byKey(ValueKey('panel'))), Offset(270, 180));
    update(() => root = false);
    await settle(tester);
    expect(tester.getTopLeft(find.byKey(ValueKey('panel'))), Offset(270, 180));
    controller.close();
    await settle(tester);
    controller.open();
    await settle(tester);
    expect(tester.getTopLeft(find.byKey(ValueKey('panel'))), Offset(142, 80));
  });

  Widget app(
    ElPortalController controller, {
    Duration exitDuration = Duration.zero,
    bool consume = false,
    bool escape = true,
    VoidCallback? onBackground,
    ElHoverIntent? hover,
  }) => MaterialApp(
    home: ElView(
      style: ElStyle(color: Color(0xFF123456)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBackground,
        child: Stack(
          children: [
            Positioned(
              left: 100,
              top: 100,
              child: ElPortal(
                controller: controller,
                exitDuration: exitDuration,
                consumeOutsideTap: consume,
                closeOnEscape: escape,
                hoverIntent: hover,
                anchor: ElOverlayAnchor(placement: .bottomStart),
                overlayBuilder: (context) => ElView(
                  key: ValueKey('panel'),
                  style: ElStyle(width: 120, height: 60),
                  child: ElPortal.geometryOf(context)?.placement.name,
                ),
                child: SizedBox(key: ValueKey('trigger'), width: 80, height: 40),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('仅官方 Overlay：开闭、通知、几何与 El 级联继承', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    var changes = 0;
    controller.addListener(() => changes++);
    await tester.pumpWidget(app(controller));
    controller.open();
    expect(controller.isOpen, isTrue);
    controller.open();
    expect(changes, 1);
    await settle(tester);
    expect(tester.getTopLeft(find.byKey(ValueKey('panel'))), Offset(100, 140));
    expect(tester.widget<ElView>(find.byKey(ValueKey('panel'))).child, 'bottomStart');
    expect(
      tester.renderObject<ElRenderView>(find.byKey(ValueKey('panel'))).committedResolvedStyle.inheritedText.color,
      Color(0xFF123456),
    );
    controller.close();
    final closed = controller.closed;
    await settle(tester);
    await closed;
    expect(changes, 2);
    expect(controller.isOpen, isFalse);
    expect(find.byKey(ValueKey('panel')), findsNothing);
  });

  testWidgets('closed 摘树后完成，退场期间重开不会重复挂 GlobalKey', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: ElPortal(
          controller: controller,
          exitDuration: Duration(milliseconds: 80),
          panel: SizedBox(key: key, width: 120, height: 60),
          child: SizedBox(width: 80, height: 40),
        ),
      ),
    );
    controller.open();
    await settle(tester);
    controller.close();
    var done = false;
    final closed = controller.closed.then((_) {
      done = true;
    });
    controller.open();
    await tester.pump();
    expect(controller.isOpen, isFalse);
    expect(done, isFalse);
    expect(find.byKey(key), findsOneWidget);
    await tester.pump(Duration(milliseconds: 100));
    await settle(tester);
    await closed;
    expect(done, isTrue);
    expect(controller.isOpen, isTrue);
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('退场立即释放外点，且 toggle 可取消排队重开', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    var taps = 0;
    await tester.pumpWidget(
      app(controller, consume: true, exitDuration: Duration(milliseconds: 80), onBackground: () => taps++),
    );
    controller.open();
    await settle(tester);
    controller.close();
    controller.toggle();
    controller.toggle();
    await tester.tapAt(Offset(600, 400));
    expect(taps, 1);
    await tester.pump(Duration(milliseconds: 100));
    await settle(tester);
    expect(controller.isOpen, isFalse);
    expect(find.byKey(ValueKey('panel')), findsNothing);
  });

  for (final consume in [false, true]) {
    testWidgets('ElPortal 外点吞/穿透：$consume，ESC 配置实时更新', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      var taps = 0;
      await tester.pumpWidget(app(controller, consume: consume, escape: false, onBackground: () => taps++));
      controller.open();
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(controller.isOpen, isTrue);
      await tester.tapAt(Offset(600, 400));
      await settle(tester);
      expect(controller.isOpen, isFalse);
      expect(taps, consume ? 0 : 1);
      controller.open();
      await settle(tester);
      await tester.pumpWidget(app(controller, consume: consume, escape: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(controller.isOpen, isFalse);
    });
  }

  testWidgets('hover 触发器到面板续命，卸载完成当前 closed', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        controller,
        hover: ElHoverIntent(
          openDelay: Duration(milliseconds: 30),
          closeDelay: Duration(milliseconds: 50),
          safePolygon: false,
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(Offset(140, 120));
    await tester.pump(Duration(milliseconds: 40));
    await settle(tester);
    expect(controller.isOpen, isTrue);
    await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('panel'))));
    await tester.pump(Duration(milliseconds: 80));
    expect(controller.isOpen, isTrue);
    final closed = controller.closed;
    await tester.pumpWidget(SizedBox());
    await closed;
    expect(controller.isOpen, isFalse);
  });
}
