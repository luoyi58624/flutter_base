import 'package:flutter_base/src/ui/cores/view/event/press.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Press owner 销毁时原样移交未决席位，不把祖先重新排到官方 Tap 后面', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final child = _press(trace, 'child')..parent = parent;
    final official = TapGestureRecognizer()..onTap = () => trace.add('official.tap');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    addTearDown(official.dispose);
    _down(12001, [child, official, parent]);
    child.dispose();
    _up(12001);
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.up', 'parent.tap']);
    expect(parent.hasActiveInput, isFalse);
  });

  testWidgets('物理 Up 后官方席位尚未结算时移除 owner，仍沿原席位完成祖先点击', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final child = _press(trace, 'child')..parent = parent;
    final official = TapGestureRecognizer()..onTap = () => trace.add('official.tap');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    addTearDown(official.dispose);
    _down(12013, [child, official, parent]);
    GestureBinding.instance.pointerRouter.route(
      PointerUpEvent(pointer: 12013, device: 12013, timeStamp: Duration(milliseconds: 30)),
    );
    child.dispose();
    GestureBinding.instance.gestureArena.sweep(12013);
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.up', 'parent.tap']);
    expect(parent.hasActiveInput, isFalse);
  });

  testWidgets('已接受 Press 的 owner 销毁后，祖先继续唯一 Up 和 Tap', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final child = _press(trace, 'child')..parent = parent;
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(12002, [child, parent]);
    child.acceptPointer(12002);
    child.dispose();
    _up(12002);
    await tester.pump();
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.up', 'parent.tap']);
  });

  testWidgets('销毁订阅祖先只结清该成员，后代继续原按压', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final child = _press(trace, 'child')..parent = parent;
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(12003, [child, parent]);
    parent.dispose();
    _up(12003);
    expect(trace, ['child.down', 'parent.down', 'parent.cancel', 'child.up', 'child.tap']);
  });

  testWidgets('Move 资格回调内移除 owner，不向旧成员补发阶段且祖先继续释放', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final child = _press(trace, 'child')..parent = parent;
    child.isEligible = (_, event) {
      if (event is PointerMoveEvent) child.dispose();
      return true;
    };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(12011, [child, parent]);
    GestureBinding.instance.pointerRouter.route(
      PointerMoveEvent(pointer: 12011, device: 12011, position: Offset(5, 0), delta: Offset(5, 0)),
    );
    _up(12011);
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.up', 'parent.tap']);
  });

  testWidgets('在自身 TapDown 内销毁 owner，祖先仍收到 Down 并正常释放', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final child = _press(trace, 'child')..parent = parent;
    child.callbacks[.tapDown] = (_) {
      trace.add('child.down');
      child.dispose();
    };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(12004, [child, parent]);
    _up(12004);
    expect(trace, ['child.down', 'child.cancel', 'parent.down', 'parent.up', 'parent.tap']);
  });

  testWidgets('在自身 LongPress 内销毁 owner，祖先长按和释放均继续且不恢复点击', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent')
      ..longPressDelay = Duration(milliseconds: 100)
      ..callbacks[.longPress] = (_) => trace.add('parent.long');
    final child = _press(trace, 'child')
      ..parent = parent
      ..longPressDelay = Duration(milliseconds: 20);
    child.callbacks[.longPress] = (_) {
      trace.add('child.long');
      child.dispose();
    };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(12005, [child, parent]);
    await tester.pump(Duration(milliseconds: 20));
    _up(12005);
    await tester.pump(Duration(milliseconds: 150));
    expect(trace, [
      'child.down',
      'parent.down',
      'child.long',
      'child.cancel',
      'parent.long',
      'parent.cancel',
      'parent.up',
    ]);
  });

  testWidgets('在自身 TapUp 内销毁 owner，完成祖先释放与点击且不补重复取消', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final child = _press(trace, 'child')..parent = parent;
    child.callbacks[.tapUp] = (_) {
      trace.add('child.up');
      child.dispose();
    };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(12006, [child, parent]);
    _up(12006);
    expect(trace, ['child.down', 'parent.down', 'child.up', 'parent.up', 'parent.tap']);
  });

  testWidgets('抬手后延迟点击期间 owner 销毁，只取消自己的待发通知', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent')
      ..doubleTapInterval = Duration(milliseconds: 40)
      ..deferTap = true
      ..callbacks[.doubleTap] = (_) => trace.add('parent.double');
    final child = _press(trace, 'child')
      ..parent = parent
      ..doubleTapInterval = Duration(milliseconds: 40)
      ..deferTap = true
      ..callbacks[.doubleTap] = (_) => trace.add('child.double');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(12007, [child, parent]);
    _up(12007);
    child.dispose();
    await tester.pump(Duration(milliseconds: 50));
    expect(trace, ['child.down', 'parent.down', 'child.up', 'parent.up', 'parent.tap']);
  });

  testWidgets('owner 销毁后祖先原来的长按计时仍生效，旧 Timer 不再通知', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent')
      ..longPressDelay = Duration(milliseconds: 60)
      ..callbacks[.longPress] = (_) => trace.add('parent.long');
    final child = _press(trace, 'child')
      ..parent = parent
      ..longPressDelay = Duration(milliseconds: 20)
      ..callbacks[.longPress] = (_) => trace.add('child.long');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(12012, [child, parent]);
    await tester.pump(Duration(milliseconds: 10));
    child.dispose();
    await tester.pump(Duration(milliseconds: 50));
    _up(12012);
    await tester.pump(Duration(milliseconds: 100));
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.long', 'parent.cancel', 'parent.up']);
  });

  testWidgets('纯观察 Press 续接不会获得官方席位，反馈时钟沿原 Down 继续', (tester) async {
    final trace = <String>[];
    final feedback = <String>[];
    final parent = _press(trace, 'parent')
      ..competeForTap = false
      ..feedbackDelay = Duration(milliseconds: 20)
      ..minimumFeedbackDuration = Duration(milliseconds: 80)
      ..onFeedbackChanged = (active) => feedback.add('parent:$active');
    final child = _press(trace, 'child')
      ..parent = parent
      ..competeForTap = false
      ..feedbackDelay = Duration(milliseconds: 20)
      ..minimumFeedbackDuration = Duration(milliseconds: 80)
      ..onFeedbackChanged = (active) => feedback.add('child:$active');
    final official = TapGestureRecognizer()..onTap = () => trace.add('official.tap');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    addTearDown(official.dispose);
    _down(12008, [child, official, parent]);
    await tester.pump(Duration(milliseconds: 10));
    child.dispose();
    await tester.pump(Duration(milliseconds: 15));
    expect(feedback, ['parent:true']);
    _up(12008);
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.up', 'official.tap']);
    await tester.pump(Duration(milliseconds: 55));
    expect(feedback, ['parent:true', 'parent:false']);
  });

  testWidgets('官方候选已经获胜后销毁原 owner，不会让失权祖先复活', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final child = _press(trace, 'child')..parent = parent;
    final official = TapGestureRecognizer()..onTap = () => trace.add('official.tap');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    addTearDown(official.dispose);
    _down(12009, [child, official, parent]);
    official.resolve(GestureDisposition.accepted);
    child.dispose();
    _up(12009);
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.cancel', 'official.tap']);
    expect(parent.hasActiveInput, isFalse);
  });

  testWidgets('owner 续接使用冻结路线，不给重挂后的新祖先补旧 Down', (tester) async {
    final trace = <String>[];
    final parent = _press(trace, 'parent');
    final replacement = _press(trace, 'replacement');
    final child = _press(trace, 'child')..parent = parent;
    addTearDown(parent.dispose);
    addTearDown(replacement.dispose);
    addTearDown(child.dispose);
    _down(12010, [child, parent]);
    child.parent = replacement;
    child.dispose();
    _up(12010);
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.up', 'parent.tap']);
  });
}

PressRecognizer _press(List<String> trace, String name) => PressRecognizer()
  ..callbacks[.tapDown] = ((_) => trace.add('$name.down'))
  ..callbacks[.tapUp] = ((_) => trace.add('$name.up'))
  ..callbacks[.tap] = ((_) => trace.add('$name.tap'))
  ..callbacks[.tapCancel] = ((_) => trace.add('$name.cancel'));

void _down(int pointer, List<GestureRecognizer> recognizers) {
  final down = PointerDownEvent(pointer: pointer, device: pointer);
  for (final recognizer in recognizers) {
    recognizer.addPointer(down);
  }
  GestureBinding.instance.pointerRouter.route(down);
  GestureBinding.instance.gestureArena.close(pointer);
}

void _up(int pointer) {
  GestureBinding.instance.pointerRouter.route(
    PointerUpEvent(pointer: pointer, device: pointer, timeStamp: Duration(milliseconds: 30)),
  );
  GestureBinding.instance.gestureArena.sweep(pointer);
}
