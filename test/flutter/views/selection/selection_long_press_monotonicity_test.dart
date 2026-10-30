// 长按触发前后逐帧采样选区、端点和 dragInfo，锁定逻辑状态只单向进入选中态。
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('longPress 触发前后选区状态单调，无中间清空帧', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 200),
              child: SizedBox(
                width: 360,
                child: ElSelectionView(
                  controller: controller,
                  child: const ElView(
                    style: ElStyle(fontSize: 16, lineHeight: 1.82),
                    child: '当用户按住触摸点选择文本时，视觉系统会同时追踪光标、选中色块和段落边界。',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final render = tester.allRenderObjects.whereType<RenderSelectionView>().first;
    final origin = tester.getTopLeft(find.byType(ElSelectionView));
    final endpointsLog = <String>[];
    final dragLog = <String>[];
    render.endpointsListenable.addListener(() {
      endpointsLog.add(render.endpointsListenable.value == null ? 'null' : 'set');
    });
    render.dragInfoListenable.addListener(() {
      dragLog.add(render.dragInfoListenable.value == null ? 'null' : 'set');
    });

    final gesture = await tester.startGesture(origin + const Offset(40, 14), kind: .touch);
    await tester.pump(const Duration(milliseconds: 380));
    expect(controller.text, isNull);

    final states = <String>[];
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 5));
      states.add(controller.text == null ? '-' : 'S');
    }

    final joined = states.join();
    expect(joined.contains('S'), isTrue, reason: '400ms 后必须进入选中态: $joined');
    expect(RegExp(r'S-').hasMatch(joined), isFalse, reason: '选区不得出现后又清空: $joined');
    final endpointsJoined = endpointsLog.join(',');
    expect(
      RegExp(r'set,null,set').hasMatch(endpointsJoined),
      isFalse,
      reason: 'endpoints 通道不得 set→null→set: $endpointsJoined',
    );
    final dragJoined = dragLog.join(',');
    expect(RegExp(r'set,null,set').hasMatch(dragJoined), isFalse, reason: 'dragInfo 通道不得 set→null→set: $dragJoined');

    await gesture.up();
    await tester.pump();
  });
}
