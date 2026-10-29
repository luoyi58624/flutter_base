import 'package:flutter_base/src/ui/cores/popup/anchor.dart';
import 'package:flutter_base/src/ui/cores/popup/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('首次布局直接定位，几何按 flip 后结果发布', (tester) async {
    ElOverlayAnchorGeometry? geometry;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned(
              left: 100,
              top: 560,
              child: ElPortal(
                anchor: ElOverlayAnchor(placement: .bottomStart, offset: 4),
                panel: Builder(
                  builder: (context) {
                    geometry = ElPortal.geometryOf(context);
                    return SizedBox(key: ValueKey('panel'), width: 120, height: 80);
                  },
                ),
                child: SizedBox(width: 80, height: 20),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(ValueKey('panel')), findsOneWidget);
    await settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('panel'))), Rect.fromLTWH(100, 476, 120, 80));
    expect(geometry?.placement, ElPlacement.topStart);
    expect(geometry?.arrowTarget, Offset(40, 80));
  });

  for (final action in ['hide', 'none', 'close']) {
    testWidgets('滚动锚离屏与返回：$action，触发物不重建', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var dismisses = 0;
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            controller: scroll,
            child: SizedBox(
              height: 2000,
              child: Align(
                alignment: Alignment.topLeft,
                child: ElPortal(
                  onDismiss: () => dismisses++,
                  panel: SizedBox(key: ValueKey('panel'), width: 100, height: 60),
                  hideWhenUnlinked: action == 'hide',
                  closeWhenUnlinked: action == 'close',
                  child: Builder(
                    builder: (_) {
                      builds++;
                      return SizedBox(width: 80, height: 20);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      final before = builds;
      scroll.jumpTo(400);
      await settle(tester);
      expect(find.byKey(ValueKey('panel')), action == 'hide' ? findsNothing : findsOneWidget);
      expect(dismisses, action == 'close' ? 1 : 0);
      await settle(tester);
      expect(dismisses, action == 'close' ? 1 : 0);
      scroll.jumpTo(0);
      await settle(tester);
      expect(find.byKey(ValueKey('panel')), findsOneWidget);
      expect(builds, before);
    });
  }

  testWidgets('零尺寸光标锚在视口内时不触发 hide', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned(
              left: 100,
              top: 100,
              child: ElPortal(
                anchor: ElOverlayAnchor(placement: .bottomStart),
                panel: SizedBox(key: ValueKey('panel'), width: 100, height: 60),
                hideWhenUnlinked: true,
                child: SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
    await settle(tester);
    expect(tester.getTopLeft(find.byKey(ValueKey('panel'))), Offset(100, 100));
  });

  testWidgets('视口变化重解算且 viewportPadding 约束双轴尺寸', (tester) async {
    tester.view.physicalSize = Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned(
              left: 100,
              top: 100,
              child: ElPortal(
                anchor: ElOverlayAnchor(viewportPadding: 16, matchMinWidth: true),
                panel: SizedBox(key: ValueKey('panel'), width: 900, height: 900),
                child: SizedBox(width: 200, height: 20),
              ),
            ),
          ],
        ),
      ),
    );
    await settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('panel'))), Rect.fromLTWH(16, 16, 768, 568));
    tester.view.physicalSize = Size(400, 300);
    await settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('panel'))), Rect.fromLTWH(16, 16, 368, 268));
  });
}
