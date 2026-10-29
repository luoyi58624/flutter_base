import 'package:flutter_base/src/ui/cores/view/event/press.dart';
import 'package:flutter_base/src/ui/cores/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter/rendering.dart' show RenderConstrainedBox;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  test('内部宿主可独立使用 EventDispatcher', () {
    final render = RenderConstrainedBox(additionalConstraints: BoxConstraints.tight(Size(1, 1)));
    final dispatcher = EventDispatcher(render);
    addTearDown(dispatcher.dispose);
    expect(EventDispatcher.of(render), same(dispatcher));
  });

  testWidgets('内部识别器及配套协议可通过 src 独立使用', (tester) async {
    final phases = <ElEventPhase>[];
    final cancellations = <PressCancelReason?>[];
    final team = GestureTeam();
    final press = PressRecognizer()..team = team;
    final transform = TransformRecognizer()
      ..team = team
      ..startDistance = 2
      ..dragCooperation = (pointer, axis) => DragCooperation([]);
    addTearDown(() {
      press.dispose();
      transform.dispose();
      team.dispose();
    });
    PointerGestureDetails? raw;
    team.onPointerEvent = (event, reason) {
      raw = team.currentPointerDetails;
      return true;
    };
    void tap(PressGestureDetails details) => phases.add(details.phase);
    void drag(TransformGestureDetails details) => phases.add(details.phase);
    expect(tap, isA<PressGestureCallback>());
    expect(drag, isA<TransformGestureCallback>());
    TransformGestureDetails? last;
    press.callbacks = {.tap: tap, .tapCancel: (details) => cancellations.add(details.cancelReason)};
    transform.callbacks = {
      .dragStart: drag,
      .dragEnd: (details) {
        last = details;
        drag(details);
      },
    };
    await tester.pumpWidget(
      Align(
        alignment: Alignment.topLeft,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            team.observePointer(event);
            press.addPointer(event);
            transform.addPointer(event);
          },
          child: SizedBox(width: 200, height: 200),
        ),
      ),
    );
    await tester.tapAt(Offset(10, 10));
    final pointer = await tester.startGesture(Offset(10, 10));
    await pointer.moveBy(Offset(30, 0));
    await pointer.up();
    expect(phases, [ElEventPhase.tap, ElEventPhase.dragStart, ElEventPhase.dragEnd]);
    expect(cancellations, isNotEmpty);
    expect(last, isA<TransformGestureDetails>());
    final GestureControl? control = raw;
    expect(control, isNotNull);
    expect(ElEventPhase.tap, same(ElEventPhase.tap));
  });
}
