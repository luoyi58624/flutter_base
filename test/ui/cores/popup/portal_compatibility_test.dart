import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('页面返回经官方局部历史只关闭最后打开的浮层，不退出页面', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final first = ElPortalController();
    final second = ElPortalController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Row(
          children: [
            for (final controller in [first, second])
              ElPortal(
                controller: controller,
                panel: SizedBox(width: 120, height: 60),
                captureFocus: false,
                restoreFocus: false,
                closeOnEscape: false,
                closeOnBack: true,
                closeOnOutsideTap: false,
                child: SizedBox(width: 80, height: 40),
              ),
          ],
        ),
      ),
    );
    second.open();
    first.open();
    await settle(tester);
    expect(await navigator.currentState!.maybePop(), isTrue);
    expect(first.isOpen, isFalse);
    expect(second.isOpen, isTrue);
    expect(await navigator.currentState!.maybePop(), isTrue);
    expect(second.isOpen, isFalse);
    await settle(tester);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('仅官方 Overlay：相位与几何读取入口获得新内核数据', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    ElPresencePhase? phase;
    ElOverlayAnchorGeometry? geometry;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: ElPortal(
            controller: controller,
            exitDuration: Duration(milliseconds: 80),
            anchor: ElOverlayAnchor(placement: .bottomStart),
            overlayBuilder: (context) {
              phase = ElPortal.phaseOf(context);
              geometry = ElPortal.geometryOf(context);
              return SizedBox(width: 120, height: 60);
            },
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    controller.open();
    await settle(tester);
    expect(phase, ElPresencePhase.visible);
    expect(geometry?.overlayRect, Rect.fromLTWH(8, 40, 120, 60));
    expect(geometry?.anchorRect, Rect.fromLTWH(0, 0, 80, 40));
    controller.close();
    await tester.pump();
    expect(phase, ElPresencePhase.exiting);
    await tester.pump(Duration(milliseconds: 100));
    await settle(tester);
  });

  for (final consume in [false, true]) {
    testWidgets('外点关闭策略：consume=$consume，关闭当帧面板和外点均穿透', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      var backgroundTaps = 0;
      var panelTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => backgroundTaps++,
            child: Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 100,
                  child: ElPortal(
                    controller: controller,
                    exitDuration: Duration(milliseconds: 80),
                    overlayBuilder: (_) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => panelTaps++,
                      child: SizedBox(key: ValueKey('panel'), width: 120, height: 60),
                    ),
                    captureFocus: false,
                    restoreFocus: false,
                    consumeOutsideTap: consume,
                    child: SizedBox(width: 80, height: 40),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      controller.open();
      await settle(tester);
      await tester.tapAt(Offset(600, 400));
      expect(controller.isOpen, isFalse);
      expect(backgroundTaps, consume ? 0 : 1);
      final panelCenter = tester.getCenter(find.byKey(ValueKey('panel')));
      // 不 pump：控制器关闭须同步撤销面板及遮罩命中，退场内容仍挂载。
      await tester.tapAt(panelCenter);
      await tester.tapAt(Offset(600, 400));
      expect(panelTaps, 0);
      expect(backgroundTaps, consume ? 2 : 3);
      await tester.pump(Duration(milliseconds: 100));
      await settle(tester);
      expect(find.byKey(ValueKey('panel')), findsNothing);
    });
  }

  testWidgets('外点禁用时 consume 不生效，配置和业务关闭回调原位更新', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    var taps = 0;
    var requests = 0;
    Widget app({required bool outside, required bool escape}) => MaterialApp(
      home: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => taps++,
        child: Align(
          alignment: Alignment.topLeft,
          child: ElPortal(
            controller: controller,
            panel: SizedBox(width: 120, height: 60),
            captureFocus: false,
            restoreFocus: false,
            closeOnEscape: escape,
            closeOnOutsideTap: outside,
            consumeOutsideTap: outside,
            onDismiss: () => requests++,
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(outside: false, escape: false));
    controller.open();
    await settle(tester);
    await tester.tapAt(Offset(600, 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(taps, 1);
    expect(requests, 0);
    expect(controller.isOpen, isTrue);
    await tester.pumpWidget(app(outside: true, escape: true));
    await tester.tapAt(Offset(600, 400));
    expect(taps, 1);
    expect(requests, 1);
    expect(controller.isOpen, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(requests, 2);
    controller.close();
    await settle(tester);
  });

  for (final capture in [false, true]) {
    testWidgets('面板焦点策略 capture=$capture，关闭恢复触发物且退场不可聚焦', (tester) async {
      final controller = ElPortalController();
      final trigger = FocusNode();
      final panel = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(trigger.dispose);
      addTearDown(panel.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: ElPortal(
              controller: controller,
              exitDuration: Duration(milliseconds: 80),
              panel: Focus(focusNode: panel, child: SizedBox(width: 120, height: 60)),
              captureFocus: capture,
              restoreFocus: capture,
              child: Focus(focusNode: trigger, child: SizedBox(width: 80, height: 40)),
            ),
          ),
        ),
      );
      trigger.requestFocus();
      await tester.pump();
      controller.open();
      await settle(tester);
      expect(trigger.hasFocus, !capture);
      if (capture) {
        panel.requestFocus();
        await tester.pump();
        expect(panel.hasPrimaryFocus, isTrue);
      }
      controller.close();
      await tester.pump();
      expect(trigger.hasFocus, isTrue);
      panel.requestFocus();
      await tester.pump();
      expect(panel.hasPrimaryFocus, isFalse);
      await tester.pump(Duration(milliseconds: 100));
      await settle(tester);
    });
  }
}
