import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'support/dispatcher_test_host.dart';

void main() {
  for (final releaseMs in [45, 50]) {
  }

  for (final sparse in [false, true]) {
    testWidgets('合成 move 不掩盖真实停顿或污染稀疏速度终点：sparse=$sparse', (tester) async {
      final box = _attachedBox();
      Velocity? released;
      final dispatcher = EventDispatcher(box)
        ..event = ElEvent(
          dragStartDistance: 3,
          onHorizontalDragStart: (_) {},
          onHorizontalDragEnd: (event) => released = event.velocity,
        );
      addTearDown(dispatcher.dispose);
      final entry = BoxHitTestEntry(box, Offset.zero);
      dispatcher.dispatchTestPointer(PointerDownEvent(pointer: 1, position: Offset.zero), entry);
      dispatcher.dispatchTestPointer(
        PointerMoveEvent(
          pointer: 1,
          position: Offset(10, 0),
          delta: Offset(10, 0),
          timeStamp: Duration(milliseconds: 16),
        ),
        entry,
      );
      final time = Duration(milliseconds: sparse ? 32 : 500);
      final end = Offset(sparse ? 1000 : 10.01, 0);
      dispatcher.dispatchTestPointer(
        PointerMoveEvent(pointer: 1, synthesized: true, position: end, delta: end - Offset(10, 0), timeStamp: time),
        entry,
      );
      dispatcher.dispatchTestPointer(PointerUpEvent(pointer: 1, position: end, timeStamp: time), entry);
      expect(released!.pixelsPerSecond.dx, closeTo(sparse ? 625 : 0, 0.001));
    });
  }

  for (final accepted in [false, true]) {
    for (final timing in ['continuous', 'paused', 'deliveryDelay']) {
    }
  }
}

_EventTestBox _attachedBox() {
  final owner = PipelineOwner();
  final box = _EventTestBox();
  owner.rootNode = box;
  return box;
}

final class _EventTestBox extends RenderBox {
  _EventTestBox() {
    layout(BoxConstraints.tight(Size(100, 100)));
  }

  @override
  void performLayout() {
    size = constraints.constrain(const Size(100, 100));
  }
}

final class _RecordingVelocityTracker extends VelocityTracker {
  _RecordingVelocityTracker(super.kind) : super.withKind();

  final List<Offset> positions = <Offset>[];

  @override
  void addPosition(Duration time, Offset position) {
    positions.add(position);
    super.addPosition(time, position);
  }
}
