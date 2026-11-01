import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/src/flutter/widgets/popup/anchor.dart';
import 'package:flutter_base/src/flutter/widgets/popup/portal.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  for (final rootOverlay in [false, true]) {
    testWidgets('全局点锚转换到嵌套Overlay坐标，rootOverlay=$rootOverlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Padding(
            padding: EdgeInsets.only(left: 100, top: 80),
            child: Align(
              alignment: .topLeft,
              child: SizedBox(
                width: 360,
                height: 300,
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (_) => Stack(
                        children: [
                          Positioned(
                            left: 30,
                            top: 40,
                            child: ElPortal(
                              rootOverlay: rootOverlay,
                              anchor: ElOverlayAnchor(placement: .bottomStart),
                              anchorPosition: Offset(240, 190),
                              panel: SizedBox(key: ValueKey('panel'), width: 120, height: 60),
                              child: SizedBox(width: 80, height: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.getRect(find.byKey(ValueKey('panel'))), Rect.fromLTWH(240, 190, 120, 60));
    });
  }

  testWidgets('受控弹层保持开闭控制权，同时接收新的面板内容', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    var label = '初始内容';
    var providePanel = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: .topLeft,
              child: ElPortal(
                controller: controller,
                panel: providePanel ? SizedBox(width: 160, height: 60, child: Text(label)) : null,
                child: SizedBox(width: 80, height: 20),
              ),
            );
          },
        ),
      ),
    );
    controller.open();
    await _settle(tester);
    expect(find.text('初始内容'), findsOneWidget);
    update(() => label = '更新内容');
    await _settle(tester);
    expect(find.text('初始内容'), findsNothing);
    expect(find.text('更新内容'), findsOneWidget);
    expect(controller.isOpen, isTrue);
    update(() => providePanel = false);
    await _settle(tester);
    expect(find.text('更新内容'), findsOneWidget);
    expect(controller.isOpen, isTrue);
    controller.close();
    await _settle(tester);
    expect(find.text('更新内容'), findsNothing);
  });

  testWidgets('关闭后触发物随模型移动或变高，退出面板仍固定原来的姿态', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    var left = 100.0;
    var height = 20.0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: 100,
                  child: ElPortal(
                    controller: controller,
                    exitDuration: Duration(milliseconds: 200),
                    anchor: ElOverlayAnchor(placement: .bottomStart),
                    panel: SizedBox(key: ValueKey('panel'), width: 120, height: 60),
                    child: SizedBox(width: 80, height: height),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    controller.open();
    await _settle(tester);
    final before = tester.getRect(find.byKey(ValueKey('panel')));
    controller.close();
    update(() {
      left = 300;
      height = 80;
    });
    await tester.pump(Duration(milliseconds: 30));
    expect(controller.isOpen, isFalse);
    expect(tester.getRect(find.byKey(ValueKey('panel'))), before);
    await tester.pump(Duration(milliseconds: 200));
    await _settle(tester);
    expect(find.byKey(ValueKey('panel')), findsNothing);
  });

  testWidgets('系统返回可单独消费且重新挂历史，外点仍走整层关闭请求', (tester) async {
    final controller = ElPortalController();
    addTearDown(controller.dispose);
    late BuildContext triggerContext;
    var backs = 0;
    var dismisses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: ElPortal(
            controller: controller,
            closeOnBack: true,
            onBack: () => backs++,
            onDismiss: () {
              dismisses++;
              controller.close();
            },
            panel: SizedBox(width: 120, height: 60),
            child: Builder(
              builder: (context) {
                triggerContext = context;
                return SizedBox(width: 80, height: 20);
              },
            ),
          ),
        ),
      ),
    );
    controller.open();
    await _settle(tester);
    for (var i = 1; i <= 2; i++) {
      expect(await Navigator.of(triggerContext).maybePop(), isTrue);
      await _settle(tester);
      expect(backs, i);
      expect(dismisses, 0);
      expect(controller.isOpen, isTrue);
    }
    await tester.tapAt(Offset(600, 400));
    await _settle(tester);
    expect(dismisses, 1);
    expect(backs, 2);
    expect(controller.isOpen, isFalse);
  });

  for (final immediate in [false, true]) {
    testWidgets('外点${immediate ? '按下' : '有效抬起'}请求关闭，其他阶段不重复通知', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      var dismisses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: .topLeft,
            child: ElPortal(
              controller: controller,
              closeOnOutsidePointerDown: immediate,
              onDismiss: () {
                dismisses++;
                controller.close();
              },
              panel: SizedBox(width: 120, height: 60),
              child: SizedBox(width: 80, height: 20),
            ),
          ),
        ),
      );
      controller.open();
      await _settle(tester);
      final gesture = await tester.startGesture(Offset(600, 400));
      expect(controller.isOpen, !immediate);
      expect(dismisses, immediate ? 1 : 0);
      await gesture.up();
      await _settle(tester);
      expect(controller.isOpen, isFalse);
      expect(dismisses, 1);
    });
  }

  testWidgets('点锚菜单内部滚动不关闭，外部滚轮立即关闭且卸载不残留监听', (tester) async {
    final controller = ElPortalController();
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: ElPortal(
            controller: controller,
            closeOnScroll: true,
            anchorPosition: Offset(120, 140),
            panel: SizedBox(
              key: ValueKey('panel'),
              width: 160,
              height: 100,
              child: SingleChildScrollView(controller: scroll, child: SizedBox(height: 500)),
            ),
            child: SizedBox(width: 80, height: 20),
          ),
        ),
      ),
    );
    controller.open();
    await _settle(tester);
    scroll.jumpTo(40);
    await _settle(tester);
    expect(controller.isOpen, isTrue);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(find.byKey(ValueKey('panel'))), scrollDelta: Offset(0, 30)),
    );
    await _settle(tester);
    expect(controller.isOpen, isTrue);
    await tester.sendEventToBinding(PointerScrollEvent(position: Offset(600, 400), scrollDelta: Offset(0, 30)));
    expect(controller.isOpen, isFalse);
    await tester.pumpWidget(SizedBox());
    await tester.sendEventToBinding(PointerScrollEvent(position: Offset(600, 400), scrollDelta: Offset(0, 30)));
    expect(tester.takeException(), isNull);
  });

  for (final closeOnScroll in [false, true]) {
    testWidgets('祖先程序滚动仅在closeOnScroll=$closeOnScroll时关闭点锚', (tester) async {
      final controller = ElPortalController();
      final scroll = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            controller: scroll,
            child: Column(
              crossAxisAlignment: .start,
              children: [
                SizedBox(height: 200),
                ElPortal(
                  controller: controller,
                  closeOnScroll: closeOnScroll,
                  anchorPosition: Offset(120, 220),
                  panel: SizedBox(width: 160, height: 100),
                  child: SizedBox(width: 80, height: 20),
                ),
                SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      );
      controller.open();
      await _settle(tester);
      scroll.jumpTo(10);
      await _settle(tester);
      expect(controller.isOpen, !closeOnScroll);
    });
  }

  testWidgets('元素仍在Overlay视口内但完全离开祖先裁剪区时关闭', (tester) async {
    final controller = ElPortalController();
    final scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Padding(
          padding: EdgeInsets.only(top: 200),
          child: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 300,
              height: 100,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    SizedBox(height: 20),
                    ElPortal(
                      controller: controller,
                      closeWhenUnlinked: true,
                      panel: SizedBox(width: 160, height: 60),
                      child: SizedBox(key: ValueKey('trigger'), width: 80, height: 20),
                    ),
                    SizedBox(height: 1000),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    controller.open();
    await _settle(tester);
    expect(controller.isOpen, isTrue);
    scroll.jumpTo(80);
    await _settle(tester);
    expect(tester.getTopLeft(find.byKey(ValueKey('trigger'))).dy, 140);
    expect(controller.isOpen, isFalse);
  });
}
