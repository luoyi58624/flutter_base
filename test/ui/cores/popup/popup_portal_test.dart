import 'package:flutter_base/src/ui/cores/popup/anchor.dart';
import 'package:flutter_base/src/ui/cores/popup/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settlePortal(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('面板内焦点经 CallbackShortcuts 关闭，closeOnEscape=false 时不关闭', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var allowEscape = true;
    var dismisses = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topLeft,
              child: ElPortal(
                closeOnEscape: allowEscape,
                onDismiss: () => dismisses++,
                panel: Focus(focusNode: focus, autofocus: true, child: SizedBox(width: 100, height: 40)),
                child: SizedBox(width: 100, height: 20),
              ),
            );
          },
        ),
      ),
    );
    await settlePortal(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismisses, 1);
    update(() => allowEscape = false);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismisses, 1);
  });

  testWidgets('上层穿透时下层遮罩也不吞点，一次外点只请求关闭上层', (tester) async {
    var lower = 0;
    var upper = 0;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 20,
                child: ElPortal(
                  onDismiss: () => lower++,
                  panel: SizedBox(width: 100, height: 40),
                  child: SizedBox(width: 100, height: 20),
                ),
              ),
              Positioned(
                left: 200,
                top: 20,
                child: ElPortal(
                  onDismiss: () => upper++,
                  panel: SizedBox(width: 100, height: 40),
                  child: SizedBox(width: 100, height: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await settlePortal(tester);
    await tester.tapAt(Offset(500, 400));
    await tester.pump();
    expect(upper, 1);
    expect(lower, 0);
    expect(taps, 1);
  });

  for (final rootOverlay in [false, true]) {
    testWidgets('嵌套 Overlay rootOverlay=$rootOverlay 的定位坐标及主题继承', (tester) async {
      final nestedKey = GlobalKey<OverlayState>();
      final panelKey = ValueKey('panel');
      await tester.pumpWidget(
        MaterialApp(
          home: Padding(
            padding: EdgeInsets.only(left: 100, top: 100),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 300,
                child: Overlay(
                  key: nestedKey,
                  initialEntries: [
                    OverlayEntry(
                      builder: (_) => Theme(
                        data: ThemeData(brightness: Brightness.dark),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 30,
                              top: 40,
                              child: ElPortal(
                                rootOverlay: rootOverlay,
                                anchor: ElOverlayAnchor(placement: .bottomStart),
                                panel: Builder(
                                  builder: (context) {
                                    expect(Theme.of(context).brightness, Brightness.dark);
                                    return SizedBox(key: panelKey, width: 100, height: 60);
                                  },
                                ),
                                child: SizedBox(width: 100, height: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settlePortal(tester);
      expect(tester.getTopLeft(find.byKey(panelKey)), Offset(130, 160));
      final render = tester.renderObject(find.byKey(panelKey));
      final overlayRender = nestedKey.currentContext!.findRenderObject();
      var underNested = false;
      var ancestor = render.parent;
      while (ancestor != null) {
        if (identical(ancestor, overlayRender)) underNested = true;
        ancestor = ancestor.parent;
      }
      expect(underNested, !rootOverlay);
    });
  }

  for (final consume in [true, false]) {
    testWidgets('空白面板内点击不判为外点 consumeOutsideTap=$consume', (tester) async {
      var dismisses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: ElPortal(
              consumeOutsideTap: consume,
              onDismiss: () => dismisses++,
              panel: SizedBox(key: ValueKey('blank-panel'), width: 100, height: 60),
              child: SizedBox(width: 100, height: 20),
            ),
          ),
        ),
      );
      await settlePortal(tester);
      await tester.tapAt(tester.getCenter(find.byKey(ValueKey('blank-panel'))));
      await tester.pump();
      expect(dismisses, 0);
    });

    testWidgets('外点 consumeOutsideTap=$consume，关闭后立即释放命中', (tester) async {
      var open = true;
      var dismisses = 0;
      var taps = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: Stack(
                  children: [
                    Positioned(
                      left: 100,
                      top: 100,
                      child: ElPortal(
                        consumeOutsideTap: consume,
                        onDismiss: () {
                          dismisses++;
                          update(() => open = false);
                        },
                        panel: open ? SizedBox(key: ValueKey('panel'), width: 100, height: 60) : null,
                        child: SizedBox(width: 100, height: 20),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await settlePortal(tester);
      await tester.tapAt(Offset(500, 400));
      await tester.pump();
      expect(dismisses, 1);
      expect(taps, consume ? 0 : 1);
      expect(find.byKey(ValueKey('panel')), findsNothing);
      await tester.tapAt(Offset(500, 400));
      expect(taps, consume ? 1 : 2);
    });
  }

  testWidgets('panel 内点击不会外点关闭，matchWidth 立即对齐并随锚宽更新', (tester) async {
    var width = 130.0;
    var dismisses = 0;
    var inside = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 100,
                  child: ElPortal(
                    anchor: ElOverlayAnchor(placement: .bottomStart, offset: 4, matchWidth: true),
                    onDismiss: () => dismisses++,
                    panel: GestureDetector(
                      onTap: () => inside++,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(key: ValueKey('panel'), width: 20, height: 60),
                    ),
                    child: SizedBox(key: ValueKey('anchor'), width: width, height: 20),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await settlePortal(tester);
    expect(tester.getSize(find.byKey(ValueKey('panel'))).width, 130);
    expect(tester.getTopLeft(find.byKey(ValueKey('panel'))), Offset(100, 124));
    await tester.tap(find.byKey(ValueKey('panel')));
    expect(inside, 1);
    expect(dismisses, 0);
    update(() => width = 180);
    await tester.pump();
    await settlePortal(tester);
    expect(tester.getSize(find.byKey(ValueKey('panel'))).width, 180);
  });

  testWidgets('底边翻转、右边 clamp 和 matchMinWidth', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned(
              left: 740,
              top: 560,
              child: ElPortal(
                anchor: ElOverlayAnchor(placement: .bottomStart, offset: 4, matchMinWidth: true),
                panel: SizedBox(key: ValueKey('panel'), width: 10, height: 80),
                child: SizedBox(width: 50, height: 20),
              ),
            ),
          ],
        ),
      ),
    );
    await settlePortal(tester);
    expect(tester.getRect(find.byKey(ValueKey('panel'))), Rect.fromLTWH(740, 476, 50, 80));
  });

  testWidgets('ESC 与穿透外点只关闭栈顶，焦点留在触发物外也可关闭', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var first = true;
    var second = true;
    final closed = <int>[];
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Focus(
              focusNode: focus,
              autofocus: true,
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 20,
                    child: ElPortal(
                      onDismiss: () {
                        closed.add(1);
                        update(() => first = false);
                      },
                      panel: first ? SizedBox(width: 100, height: 60) : null,
                      child: SizedBox(width: 100, height: 20),
                    ),
                  ),
                  Positioned(
                    left: 200,
                    top: 20,
                    child: ElPortal(
                      onDismiss: () {
                        closed.add(2);
                        update(() => second = false);
                      },
                      panel: second ? SizedBox(width: 100, height: 60) : null,
                      child: SizedBox(width: 100, height: 20),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await settlePortal(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closed, [2]);
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.tapAt(Offset(500, 400));
    await tester.pump();
    expect(closed, [2, 1]);
  });

  testWidgets('关闭 ESC 和无 onDismiss 的被动浮层不占关闭栈', (tester) async {
    var dismisses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            ElPortal(
              onDismiss: () => dismisses++,
              panel: SizedBox(width: 100, height: 40),
              child: SizedBox(width: 100, height: 20),
            ),
            ElPortal(
              closeOnEscape: false,
              panel: IgnorePointer(child: SizedBox(width: 100, height: 40)),
              child: SizedBox(width: 100, height: 20),
            ),
          ],
        ),
      ),
    );
    await settlePortal(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismisses, 1);
    await tester.pumpWidget(SizedBox());
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismisses, 1);
  });

  testWidgets('祖先移动时跟随且不重建触发物', (tester) async {
    final offset = ValueNotifier<double>(100);
    addTearDown(offset.dispose);
    var builds = 0;
    final portal = ElPortal(
      anchor: ElOverlayAnchor(placement: .bottomStart),
      panel: SizedBox(key: ValueKey('panel'), width: 80, height: 40),
      child: Builder(
        builder: (_) {
          builds++;
          return SizedBox(width: 100, height: 20);
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: offset,
          child: portal,
          builder: (_, value, child) => Stack(
            children: [Positioned(left: value, top: 100, child: child!)],
          ),
        ),
      ),
    );
    await settlePortal(tester);
    final before = builds;
    offset.value = 200;
    await tester.pump();
    await settlePortal(tester);
    expect(tester.getTopLeft(find.byKey(ValueKey('panel'))), Offset(200, 120));
    expect(builds, before);
  });
}
