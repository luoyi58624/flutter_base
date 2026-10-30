// handle 拖拽中宿主 detach/dispose 强制结束 magnifier 拖动会话的回归：
// per-pointer route 必须随宿主卸载摘除，抬手事件不得回调已 dispose 的 render。
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

void main() {
  testWidgets('handle 拖拽中宿主卸载：抬手不再经 PointerRouter 回调已 dispose 的 render', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(
      _app(
        ElSelectionView(
          controller: controller,
          child: const ElView(child: 'hello world'),
        ),
      ),
    );
    controller.selectAll();
    await tester.pump();

    final render = tester.allRenderObjects.whereType<RenderSelectionView>().first;
    const pointer = 71;
    final position = render.endpoints!.end.globalPosition;
    render.beginHandleDrag(SelectionHandleSide.end, position, pointer: pointer);
    expect(render.dragInfoListenable.value, isNotNull);

    // 拖拽中整体卸载宿主子树（导航跳转 / 条件移除的最小等价物）。
    await tester.pumpWidget(_app(const ElView(child: 'placeholder')));

    // 抬手事件仍会进 PointerRouter：route 未随宿主卸载摘除时，end() 会写已
    // dispose 的 _dragInfoNotifier（debug assert 经 FlutterError 上报为测试异常）。
    GestureBinding.instance.pointerRouter.route(
      PointerUpEvent(pointer: pointer, kind: PointerDeviceKind.touch, position: position),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
