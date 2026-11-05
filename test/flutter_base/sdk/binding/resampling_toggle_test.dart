import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter_base/sdk/binding/binding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = _ToggleTestBinding();

  test('触摸重采样门禁默认开启，不改变官方重采样配置', () {
    expect(binding.touchResamplingEnabled, isTrue);
    expect(binding.resamplingEnabled, isFalse);
    binding.resamplingEnabled = true;
    binding.touchResamplingEnabled = false;
    binding.touchResamplingEnabled = true;
    expect(binding.resamplingEnabled, isTrue);
    binding.resamplingEnabled = false;
  });

  group('运行时门禁', () {
    setUp(() {
      binding.resamplingEnabled = false;
      binding.touchResamplingEnabled = true;
    });
    tearDown(() {
      binding.touchResamplingEnabled = false;
      binding.resetGestureBinding();
    });

    _androidTest('关闭后真实移动立即分发，不再等待采样帧', (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_shell(events));
      binding.touchResamplingEnabled = false;
      final base = binding.currentSystemFrameTimeStamp;
      final gesture = await _start(tester, base);
      await gesture.moveTo(Offset(40, 20), timeStamp: base + _ms(8));
      await gesture.moveTo(Offset(60, 20), timeStamp: base + _ms(16));

      expect(events.whereType<PointerMoveEvent>().map((event) => event.position), [Offset(40, 20), Offset(60, 20)]);
      await tester.pump(_ms(16));
      expect(events.whereType<PointerMoveEvent>(), hasLength(2));
      await gesture.up(timeStamp: base + _ms(24));
      expect(events.last, isA<PointerUpEvent>());
      expect(binding.resamplingEnabled, isFalse);
    });

    _androidTest('关闭时结清在途真实移动，抬起之前不丢失最终位置', (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_shell(events));
      final base = binding.currentSystemFrameTimeStamp;
      final gesture = await _start(tester, base);
      await gesture.moveTo(Offset(40, 20), timeStamp: base + _ms(8));
      await gesture.moveTo(Offset(60, 20), timeStamp: base + _ms(16));
      expect(events.whereType<PointerMoveEvent>(), isEmpty);

      binding.touchResamplingEnabled = false;
      final flushed = events.whereType<PointerMoveEvent>().single;
      expect(flushed.position, Offset(60, 20));
      expect(flushed.delta, Offset(40, 0));
      expect(flushed.synthesized, isFalse);
      await gesture.up(timeStamp: base + _ms(24));
      expect(events, orderedEquals([isA<PointerDownEvent>(), isA<PointerMoveEvent>(), isA<PointerUpEvent>()]));
      final count = events.length;
      await tester.pump(_ms(100));
      expect(events, hasLength(count));
      expect(binding.transientCallbackCount, 0);
    });

    _androidTest('重新开启后后续触摸序列恢复逐帧采样', (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_shell(events));
      binding.touchResamplingEnabled = false;
      final firstBase = binding.currentSystemFrameTimeStamp;
      final first = await _start(tester, firstBase);
      await first.moveTo(Offset(40, 20), timeStamp: firstBase + _ms(8));
      expect(events.whereType<PointerMoveEvent>(), hasLength(1));
      await first.up(timeStamp: firstBase + _ms(16));
      await tester.pump(_ms(24));
      events.clear();

      binding.touchResamplingEnabled = true;
      final secondBase = binding.currentSystemFrameTimeStamp;
      final second = await _start(tester, secondBase);
      await second.moveTo(Offset(40, 20), timeStamp: secondBase + _ms(8));
      await second.moveTo(Offset(60, 20), timeStamp: secondBase + _ms(16));
      expect(events.whereType<PointerMoveEvent>(), isEmpty);
      await tester.pump(_ms(16));
      final sampled = events.whereType<PointerMoveEvent>().single;
      expect(sampled.pointer, events.whereType<PointerDownEvent>().single.pointer);
      expect(sampled.synthesized, isFalse);
      expect(sampled.timeStamp, greaterThan(secondBase));
      expect(sampled.timeStamp, lessThanOrEqualTo(secondBase + _ms(20)));
      await second.up(timeStamp: secondBase + _ms(24));
      expect(events.last, isA<PointerUpEvent>());
      expect(events.last.pointer, sampled.pointer);
      expect(events.last.position, events.whereType<PointerMoveEvent>().last.position);
      expect(events.last.timeStamp, greaterThanOrEqualTo(sampled.timeStamp));
      final count = events.length;
      await tester.pump(_ms(100));
      expect(events, hasLength(count));
    });

    _androidTest('锁定中关闭采样会在解锁后结清在途移动', (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(_shell(events));
      final base = binding.currentSystemFrameTimeStamp;
      final gesture = await _start(tester, base);
      await gesture.moveTo(Offset(60, 20), timeStamp: base + _ms(8));
      expect(events.whereType<PointerMoveEvent>(), isEmpty);

      await binding._withLockedEvents(() async {
        binding.touchResamplingEnabled = false;
        expect(events.whereType<PointerMoveEvent>(), isEmpty);
      });
      expect(events.whereType<PointerMoveEvent>().single.position, Offset(60, 20));
      await gesture.up(timeStamp: base + _ms(16));
      expect(events.last, isA<PointerUpEvent>());
      final count = events.length;
      await tester.pump(_ms(100));
      expect(events, hasLength(count));
    });
  });
}

class _ToggleTestBinding extends AutomatedTestWidgetsFlutterBinding with TouchResamplingBinding {
  Future<void> _withLockedEvents(Future<void> Function() callback) => lockEvents(callback);
}

Widget _shell(List<PointerEvent> events) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 300,
      height: 300,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: events.add,
        onPointerMove: events.add,
        onPointerUp: events.add,
      ),
    ),
  ),
);

Future<TestGesture> _start(WidgetTester tester, Duration timeStamp) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
  await gesture.down(Offset(20, 20), timeStamp: timeStamp);
  return gesture;
}

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

void _androidTest(String description, WidgetTesterCallback callback) {
  testWidgets(description, callback, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
