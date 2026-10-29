import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/cores/view/event/press.dart';

/// 等待旧序列的长按与连击窗口全部结束。
const afterGesture = Duration(milliseconds: 700);

/// 在固定的左上角坐标系中运行宿主。
Widget gestureShell(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

/// 只向识别器登记官方命中路径中的开始事件。
Widget gestureHost(GestureRecognizer recognizer, {Key? key, Widget? child}) => Listener(
  key: key,
  behavior: HitTestBehavior.opaque,
  onPointerDown: recognizer.addPointer,
  onPointerPanZoomStart: recognizer.addPointerPanZoom,
  child: child ?? const SizedBox(width: 200, height: 200),
);

/// 记录点击生命周期，供真实命中场景复用。
PressRecognizer recordingPress(List<String> events, String name, {PressRecognizer? parent}) {
  final recognizer = PressRecognizer()..parent = parent;
  recognizer.callbacks[.tapDown] = (_) => events.add('$name.down');
  recognizer.callbacks[.tapUp] = (_) => events.add('$name.up');
  recognizer.callbacks[.tap] = (_) => events.add('$name.tap');
  recognizer.callbacks[.longPress] = (_) => events.add('$name.longPress');
  recognizer.callbacks[.tapCancel] = (_) => events.add('$name.cancel');
  return recognizer;
}

/// 记录水平拖拽生命周期，供真实命中场景复用。
TransformRecognizer recordingDrag(
  List<String> events,
  String name, {
  TransformRecognizer? parent,
  double distance = 6,
}) {
  final recognizer = TransformRecognizer()
    ..startDistance = distance
    ..parent = parent
    ..axis = Axis.horizontal;
  recognizer.callbacks[.dragDown] = (_) => events.add('$name.down');
  recognizer.callbacks[.dragStart] = (_) => events.add('$name.start');
  recognizer.callbacks[.dragUpdate] = (_) => events.add('$name.update');
  recognizer.callbacks[.dragEnd] = (_) => events.add('$name.end');
  recognizer.callbacks[.dragCancel] = (_) => events.add('$name.cancel');
  return recognizer;
}

/// 构造同一指针同时命中两个透明分支的真实场景。
Widget overlapHost({
  required GestureRecognizer parent,
  required GestureRecognizer back,
  required GestureRecognizer front,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: parent.addPointer,
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 子树本身不命中，让 Stack 将同一指针送到前后两个透明分支。
            for (final recognizer in [back, front])
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: recognizer.addPointer,
                child: const SizedBox.expand(),
              ),
          ],
        ),
      ),
    ),
  ),
);
