import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Overlay M2：锚定引擎 ElOverlayAnchor + ElPortal。
///
/// 不变量（测试视口 800×600）：
/// 1. bottomStart 基础定位：弹层左上 = 锚左下 + offset。
/// 2. flip：锚贴近底边时 bottom 翻 top（弹层底 = 锚顶 - offset）。
/// 3. 锚贴右缘时交叉轴起止对调，右缘对齐锚。
/// 4. matchWidth：弹层宽 = 锚宽。
/// 5. 跟随：锚移动后弹层帧级跟随。
/// 6. ElPortal：open/close/toggle/isOpen、退场保活、触发器卸载自动收。
/// 7. geometryOf：flip 后 resolvedPlacement = top。
void main() {
  const anchorKey = ValueKey('anchor');
  const popupKey = ValueKey('popup');

  /// host + 绝对定位锚（left/top 由参数控制）。
  Widget app({
    required ElPortalController controller,
    required double left,
    required double top,
    double anchorW = 80,
    double anchorH = 40,
    ElOverlayAnchor anchor = const ElOverlayAnchor(),
    WidgetBuilder? builder,
  }) {
    return MaterialApp(
      home: ElView(
        style: const ElStyle(color: Color(0xFF123456)),
        child: KeyedSubtree(
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: ElPortal(
                  controller: controller,
                  anchor: anchor,
                  overlayBuilder:
                      builder ??
                      (_) => ElView(
                        key: popupKey,
                        style: ElStyle(width: 120, height: 60, backgroundColor: Color(0xFFAA0000)),
                      ),
                  child: ElView(
                    key: anchorKey,
                    style: ElStyle(width: anchorW, height: anchorH, backgroundColor: Color(0xFF222222)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget popup({double w = 120, double h = 60}) => ElView(
    key: popupKey,
    style: ElStyle(width: w, height: h, backgroundColor: const Color(0xFFAA0000)),
  );

  group('锚定解算', () {
    testWidgets('bottomStart：弹层左上 = 锚左下 + offset', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          controller: controller,
          left: 100,
          top: 100,
          anchor: ElOverlayAnchor(placement: .bottomStart, offset: 6),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(popupKey)), Offset(100, 146));
    });
    testWidgets('flip：锚贴底边 → bottom 翻 top', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      ElOverlayAnchorGeometry? geometry;
      await tester.pumpWidget(
        app(
          controller: controller,
          left: 100,
          top: 540,
          anchor: ElOverlayAnchor(placement: .bottomStart, offset: 6),
          builder: (context) {
            geometry = ElPortal.geometryOf(context);
            return popup();
          },
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.byKey(popupKey)), Offset(100, 534));
      expect(geometry?.placement, ElPlacement.topStart);
    });
    testWidgets('锚贴右缘 → 左对齐越界时改为右对齐锚', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          controller: controller,
          left: 760,
          top: 100,
          anchorW: 30,
          anchor: ElOverlayAnchor(placement: .bottomStart, viewportPadding: 8),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(tester.getTopRight(find.byKey(popupKey)).dx, 790);
    });
    testWidgets('matchWidth：弹层宽 = 锚宽', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          controller: controller,
          left: 100,
          top: 100,
          anchorW: 220,
          anchor: ElOverlayAnchor(matchWidth: true),
          builder: (_) => ElView(
            key: popupKey,
            style: ElStyle(height: 60, backgroundColor: Color(0xFFAA0000)),
          ),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(popupKey)).width, 220);
    });
    testWidgets('跟随：锚移动后弹层帧级跟随', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          controller: controller,
          left: 100,
          top: 100,
          anchor: ElOverlayAnchor(placement: .bottomStart),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(popupKey)).dx, 100);
      await tester.pumpWidget(
        app(
          controller: controller,
          left: 300,
          top: 100,
          anchor: ElOverlayAnchor(placement: .bottomStart),
        ),
      );
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(popupKey)).dx, 300);
    });
  });

  group('ElPortal', () {
    testWidgets('open/close/toggle/isOpen + 退场保活 + 桥接生效', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ElView(
            style: const ElStyle(color: Color(0xFF123456)),
            child: KeyedSubtree(
              child: Stack(
                children: [
                  Positioned(
                    left: 100,
                    top: 100,
                    child: ElPortal(
                      controller: controller,
                      anchor: const ElOverlayAnchor(placement: ElPlacement.bottomStart),
                      exitDuration: const Duration(milliseconds: 150),
                      overlayBuilder: (c) {
                        return popup();
                      },
                      child: ElView(
                        key: anchorKey,
                        style: const ElStyle(width: 80, height: 40, backgroundColor: Color(0xFF222222)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(controller.isOpen, isFalse);
      controller.open();
      await tester.pump();
      await tester.pump();
      expect(controller.isOpen, isTrue);
      expect(find.byKey(popupKey), findsOneWidget);
      expect(
        tester.renderObject<ElRenderView>(find.byKey(popupKey)).committedResolvedStyle.inheritedText.color,
        const Color(0xFF123456),
      );
      expect(tester.getTopLeft(find.byKey(popupKey)), const Offset(100, 140));

      controller.close();
      expect(controller.isOpen, isFalse);
      await tester.pump();
      // 退场保活中仍挂载。
      expect(find.byKey(popupKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byKey(popupKey), findsNothing);

      controller.toggle();
      await tester.pump();
      // 官方 Portal 的首次几何未知时先 offstage，下一帧按实测锚点定位。
      await tester.pump();
      expect(controller.isOpen, isTrue);
      expect(find.byKey(popupKey), findsOneWidget);
    });

    testWidgets('触发器卸载自动收弹层', (tester) async {
      final controller = ElPortalController();
      addTearDown(controller.dispose);
      Widget build({required bool showTrigger}) => MaterialApp(
        home: ElView(
          child: KeyedSubtree(
            child: Stack(
              children: [
                if (showTrigger)
                  Positioned(
                    left: 100,
                    top: 100,
                    child: ElPortal(
                      controller: controller,
                      overlayBuilder: (c) => popup(),
                      child: ElView(key: anchorKey, style: const ElStyle(width: 80, height: 40)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(showTrigger: true));
      controller.open();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(popupKey), findsOneWidget);
      await tester.pumpWidget(build(showTrigger: false));
      // 官方 Portal 随触发器卸载，额外推进帧以处理焦点和清理回调。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      expect(find.byKey(popupKey), findsNothing);
    });
  });
}
