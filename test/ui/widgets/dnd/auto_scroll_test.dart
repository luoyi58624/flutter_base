import '../../support/overlay.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/cores/scroll/common/render/scroll_viewport_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// DnD 边缘自动滚动：拖拽指针进入滚动视口底部边缘带 → 内容持续滚动；
/// 移出边缘带 → 停；滚动中命中跟手重派发。
void main() {
  const dragKey = ValueKey('drag');
  const scrollKey = ValueKey('scroll');

  testWidgets('底部边缘带持续滚动，移出即停', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ElView(
          child: ElTestOverlay(
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 20,
                  child: ElDraggable<String>(
                    data: 'x',
                    child: const ElView(key: dragKey, style: ElStyle(width: 60, height: 60, bgColor: Color(0xFF2266AA))),
                  ),
                ),
                Positioned(
                  left: 300,
                  top: 100,
                  child: ElView(
                    key: scrollKey,
                    style: const ElStyle(width: 200, height: 200, bgColor: Color(0xFF222222)),
                    child: ElScrollView(
                      children: [
                        for (var i = 0; i < 40; i++)
                          ElView(style: const ElStyle(width: 180, height: 40), child: 'row'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final viewport = tester.allRenderObjects.whereType<RenderVirtualScrollView>().firstWhere((v) => v.size.width == 200);
    expect(viewport.position.pixels, 0);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(dragKey)));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    // 移到滚动视口底部边缘带内（底边上方 10px）。
    final scrollRect = tester.getRect(find.byKey(scrollKey));
    await gesture.moveTo(Offset(scrollRect.center.dx, scrollRect.bottom - 10));
    await tester.pump();
    // 持续几帧：位置应持续增长。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final scrolled = viewport.position.pixels;
    expect(scrolled, greaterThan(20));

    // 移出边缘带（视口中心）：停止增长。
    await gesture.moveTo(scrollRect.center);
    await tester.pump();
    final atCenter = viewport.position.pixels;
    await tester.pump(const Duration(milliseconds: 200));
    expect(viewport.position.pixels, atCenter);

    await gesture.up();
    await tester.pump();
  });
}
