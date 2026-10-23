import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/src/flutter_base/sdk/binding.dart';
import 'package:flutter_base/src/flutter_base/sdk/touch_resampling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 应用绑定与测试绑定均为单例，在独立测试模式验证实际应用绑定的首次初始化。
  if (const bool.fromEnvironment('testBindingInitialization')) {
    test('显式初始化绑定，重复调用与官方初始化复用同一实例', () {
      final binding = ElWidgetsFlutterBinding.ensureInitialized();
      expect(ElWidgetsFlutterBinding.ensureInitialized(), same(binding));
      expect(WidgetsFlutterBinding.ensureInitialized(), same(binding));
      expect(binding.resamplingEnabled, isFalse);
    });
    return;
  }

  final binding = _InputTestBinding();
  test('已有其他绑定时拒绝替换，原实例继续可用', () {
    expect(ElWidgetsFlutterBinding.ensureInitialized, throwsStateError);
    expect(TestWidgetsFlutterBinding.ensureInitialized(), same(binding));
  });
  group('采样算法', _positionTests);
  group('触摸生命周期', _pointerTests);
  group('官方手势接入', () => _bindingTests(binding));
  group('依赖边界', _architectureTests);
}

void _positionTests() {
  test('相邻样本插值，外推限于半个周期，时间戳不会伪装成更远的预测', () {
    final sampler = _sampler();
    sampler.push(_ms(10), const Offset(10, 0));
    expect(sampler.sample(_ms(5))!.position, const Offset(5, 0));
    final predicted = sampler.sample(_ms(100))!;
    expect(predicted.position, const Offset(15, 0));
    expect(predicted.timeStamp, _ms(15));
    expect(sampler.sample(_ms(200)), isNull);
    expect(sampler.hasPendingMotion, isFalse);
  });

  for (final interval in [1, 25]) {
    test('${interval}ms 异常周期不用速度外推', () {
      final sampler = _sampler();
      sampler.push(_ms(interval), const Offset(10, 0));
      expect(sampler.sample(_ms(40))!.position, const Offset(10, 0));
      expect(sampler.hasPendingMotion, isFalse);
    });
  }

  test('自适应尾随保留原周期策略和 -5ms 下限', () {
    final sampler = TouchPositionResampler(
      seedTime: Duration.zero,
      seedPosition: Offset.zero,
    );
    expect(sampler.effectiveOffset, _ms(-5));
    sampler.push(_ms(8), const Offset(8, 0));
    expect(sampler.effectiveOffset, _ms(-12));
    sampler.push(_ms(24), const Offset(24, 0));
    expect(sampler.effectiveOffset, const Duration(microseconds: -14500));
    sampler.sample(_ms(20));
    sampler.sample(_ms(10));
    expect(sampler.lastSampleTime, _ms(20));
  });

  test('外推过冲不产生反向回收，真实反向超过 2px 后恢复', () {
    final sampler = _sampler();
    sampler.push(_ms(10), const Offset(10, 0));
    expect(sampler.sample(_ms(16))!.position.dx, 15);
    expect(sampler.isOvershootPayback(const Offset(-1, 0)), isTrue);
    sampler.push(_ms(20), const Offset(12, 0));
    expect(sampler.sample(_ms(32)), isNull);
    sampler.push(_ms(30), const Offset(11, 0));
    expect(sampler.sample(_ms(48)), isNull);
    sampler.push(_ms(40), const Offset(8, 0));
    expect(sampler.sample(_ms(64))!.delta.dx, lessThan(0));
  });

  test('外推上限不超过 8ms，停顿后不继续累积移动', () {
    final sampler = _sampler();
    sampler.push(_ms(20), const Offset(20, 0));
    final sample = sampler.sample(_ms(100))!;
    expect(sample.position.dx, 28);
    expect(sample.timeStamp, _ms(28));
    expect(sampler.sample(_ms(200)), isNull);
  });

  test('相同时间戳替换坐标，倒序输入不破坏采样', () {
    final sampler = _sampler();
    sampler.push(_ms(10), const Offset(10, 0));
    sampler.push(_ms(10), const Offset(20, 0));
    sampler.push(_ms(5), const Offset(999, 0));
    expect(sampler.sample(_ms(10))!.position, const Offset(20, 0));
  });
}

TouchPositionResampler _sampler() => TouchPositionResampler(
  seedTime: Duration.zero,
  seedPosition: Offset.zero,
  samplingOffset: Duration.zero,
  adaptive: false,
);

void _pointerTests() {
  testWidgets('按下即时分发，短手势抬起前结清移动，结束后不再输出', (tester) async {
    final base = await _prime(tester);
    final events = <PointerEvent>[];
    final sampler = _pipeline(events);
    addTearDown(sampler.clear);
    sampler.handleEvent(PointerDownEvent(pointer: 1, timeStamp: base));
    sampler.handleEvent(
      PointerMoveEvent(
        pointer: 1,
        timeStamp: base + _ms(8),
        position: const Offset(20, 0),
        delta: const Offset(20, 0),
      ),
    );
    expect(events, hasLength(1));
    sampler.handleEvent(PointerUpEvent(pointer: 1, timeStamp: base + _ms(10)));
    expect(events.map((event) => event.runtimeType), [
      PointerDownEvent,
      PointerMoveEvent,
      PointerUpEvent,
    ]);
    expect(events[1].delta, const Offset(20, 0));
    expect(events.last.position, const Offset(20, 0));
    await tester.pump(_ms(100));
    expect(events, hasLength(3));
  });

  testWidgets('逐帧合并输入，采样移动保留设备、压力与平台属性', (tester) async {
    final base = await _prime(tester);
    final events = <PointerEvent>[];
    final sampler = _pipeline(events);
    addTearDown(sampler.clear);
    sampler.handleEvent(
      PointerDownEvent(pointer: 7, device: 42, timeStamp: base),
    );
    for (final ms in [8, 16]) {
      sampler.handleEvent(
        PointerMoveEvent(
          pointer: 7,
          device: 42,
          timeStamp: base + _ms(ms),
          position: Offset(ms.toDouble(), 0),
          delta: const Offset(8, 0),
          pressure: 0.6,
          pressureMax: 2,
          radiusMajor: 9,
          tilt: 0.2,
          platformData: 123,
          embedderId: 456,
        ),
      );
    }
    expect(events.whereType<PointerMoveEvent>(), isEmpty);
    await tester.pump(_ms(16));
    final move = events.whereType<PointerMoveEvent>().single;
    expect(move.position, const Offset(4, 0));
    expect(move.delta, const Offset(4, 0));
    expect(move.timeStamp, base + _ms(4));
    expect(move.device, 42);
    expect(move.pointer, 7);
    expect(move.pressure, 0.6);
    expect(move.pressureMax, 2);
    expect(move.radiusMajor, 9);
    expect(move.tilt, 0.2);
    expect(move.platformData, 123);
    expect(move.embedderId, 456);
    expect(move.synthesized, isFalse);
    sampler.clear();
  });

  testWidgets('同设备多指独立跟踪并按同一时刻输出', (tester) async {
    final base = await _prime(tester);
    final events = <PointerEvent>[];
    final sampler = _pipeline(events);
    addTearDown(sampler.clear);
    for (final pointer in [1, 2]) {
      sampler.handleEvent(
        PointerDownEvent(
          pointer: pointer,
          device: 10,
          position: Offset(pointer * 100, 0),
          timeStamp: base,
        ),
      );
      for (final ms in [8, 16]) {
        sampler.handleEvent(
          PointerMoveEvent(
            pointer: pointer,
            device: 10,
            position: Offset(pointer * 100 + ms.toDouble(), 0),
            timeStamp: base + _ms(ms),
          ),
        );
      }
    }
    await tester.pump(_ms(16));
    final moves = events.whereType<PointerMoveEvent>().toList();
    expect(moves.map((event) => event.pointer), [1, 2]);
    expect(moves.map((event) => event.position.dx), [104, 204]);
    expect(moves.map((event) => event.timeStamp).toSet(), {base + _ms(4)});
    sampler.clear();
  });

  testWidgets('框架仅带 pointer 的取消能清理真实设备，取消后没有补尾移动', (tester) async {
    final base = await _prime(tester);
    final events = <PointerEvent>[];
    final sampler = _pipeline(events);
    addTearDown(sampler.clear);
    sampler.handleEvent(
      PointerDownEvent(pointer: 1, device: 99, timeStamp: base),
    );
    sampler.handleEvent(
      PointerMoveEvent(
        pointer: 1,
        device: 99,
        position: const Offset(10, 0),
        timeStamp: base + _ms(8),
      ),
    );
    sampler.handleEvent(const PointerCancelEvent(pointer: 1));
    final cancel = events.last as PointerCancelEvent;
    expect(cancel.device, 99);
    expect(cancel.position, Offset.zero);
    expect(cancel.timeStamp, base);
    await tester.pump(_ms(100));
    expect(events, hasLength(2));
  });

  testWidgets('绑定锁定时暂停帧采样，解锁后恢复，重置取消所有帧', (tester) async {
    final base = await _prime(tester);
    var unlocked = true;
    final events = <PointerEvent>[];
    final sampler = _pipeline(events, canDispatch: () => unlocked);
    addTearDown(sampler.clear);
    sampler.handleEvent(PointerDownEvent(pointer: 1, timeStamp: base));
    sampler.handleEvent(
      PointerMoveEvent(
        pointer: 1,
        timeStamp: base + _ms(8),
        position: const Offset(8, 0),
      ),
    );
    unlocked = false;
    await tester.pump(_ms(16));
    expect(events, hasLength(1));
    unlocked = true;
    sampler.resume();
    await tester.pump(_ms(16));
    expect(events.whereType<PointerMoveEvent>(), hasLength(1));
    sampler.clear();
    final count = events.length;
    await tester.pump(_ms(100));
    expect(events, hasLength(count));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('纯预测帧标记为合成输入，抬起不反向偿还外推过冲', (tester) async {
    final base = await _prime(tester);
    final events = <PointerEvent>[];
    final sampler = _pipeline(events);
    addTearDown(sampler.clear);
    sampler.handleEvent(PointerDownEvent(pointer: 1, timeStamp: base));
    sampler.handleEvent(
      PointerMoveEvent(
        pointer: 1,
        position: const Offset(8, 0),
        timeStamp: base + _ms(8),
      ),
    );
    await tester.pump(_ms(16));
    await tester.pump(_ms(8));
    final moves = events.whereType<PointerMoveEvent>().toList();
    expect(moves.map((event) => event.synthesized), [false, true]);
    expect(moves.last.position.dx, 12);
    sampler.handleEvent(
      PointerUpEvent(
        pointer: 1,
        timeStamp: base + _ms(25),
        position: const Offset(8, 0),
      ),
    );
    expect(events.whereType<PointerMoveEvent>(), hasLength(2));
    expect(events.last.position, moves.last.position);
    await tester.pump(_ms(100));
    expect(events.last, isA<PointerUpEvent>());
  });

  testWidgets('让位时结清真实输入并停止后续采样，按钮变化即时分发', (tester) async {
    final base = await _prime(tester);
    var enabled = true;
    final events = <PointerEvent>[];
    final sampler = _pipeline(events, isEnabled: () => enabled);
    addTearDown(sampler.clear);
    sampler.handleEvent(PointerDownEvent(pointer: 1, timeStamp: base));
    sampler.handleEvent(
      PointerMoveEvent(pointer: 1, buttons: 0, timeStamp: base + _ms(1)),
    );
    expect(events.last.buttons, 0);
    sampler.handleEvent(
      PointerMoveEvent(
        pointer: 1,
        buttons: 0,
        position: const Offset(10, 0),
        timeStamp: base + _ms(8),
      ),
    );
    enabled = false;
    await tester.pump(_ms(16));
    expect(events.last.position, const Offset(10, 0));
    final count = events.length;
    await tester.pump(_ms(100));
    expect(events, hasLength(count));
  });
}

TouchEventResampler _pipeline(
  List<PointerEvent> events, {
  bool Function()? canDispatch,
  bool Function()? isEnabled,
}) => TouchEventResampler(
  dispatch: events.add,
  canDispatch: canDispatch ?? () => true,
  isEnabled: isEnabled ?? () => true,
);

Future<Duration> _prime(WidgetTester tester) async {
  tester.binding.scheduleFrame();
  await tester.pump();
  return tester.binding.currentSystemFrameTimeStamp;
}

void _bindingTests(_InputTestBinding binding) {
  _platformTest('全局采样进入官方 GestureDetector，按帧更新且抬起完整结束', (tester) async {
    final moves = <PointerMoveEvent>[];
    final updates = <DragUpdateDetails>[];
    var starts = 0;
    var ends = 0;
    await tester.pumpWidget(
      _shell(
        Listener(
          onPointerMove: moves.add,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: (_) => starts++,
            onPanUpdate: updates.add,
            onPanEnd: (_) => ends++,
          ),
        ),
      ),
    );
    final base = binding.currentSystemFrameTimeStamp;
    final gesture = await _start(tester, const Offset(20, 20), timeStamp: base);
    await gesture.moveTo(const Offset(60, 20), timeStamp: base + _ms(8));
    await gesture.moveTo(const Offset(100, 20), timeStamp: base + _ms(16));
    expect(moves, isEmpty);

    await tester.pump(_ms(16));
    expect(moves, hasLength(1));
    expect(moves.single.position, const Offset(40, 20));
    expect(starts, 1);
    await gesture.up(timeStamp: base + _ms(24));
    expect(ends, 1);
    expect(moves.last.position, const Offset(100, 20));
    expect(updates.fold<double>(0, (sum, event) => sum + event.delta.dx), 80);
    final count = moves.length;
    await tester.pump(_ms(100));
    expect(moves, hasLength(count));
    expect(binding.resamplingEnabled, isFalse);
  });

  _platformTest('按下和点击无需等待采样帧', (tester) async {
    var downs = 0;
    var taps = 0;
    await tester.pumpWidget(
      _shell(
        Listener(
          onPointerDown: (_) => downs++,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final base = binding.currentSystemFrameTimeStamp;
    final gesture = await _start(tester, const Offset(20, 20), timeStamp: base);
    expect(downs, 1);
    await gesture.up(timeStamp: base + _ms(1));
    expect(taps, 1);
  });

  _platformTest('ElEvent 接收全局采样事件，不再进行第二次输出采样', (tester) async {
    final rawMoves = <PointerMoveEvent>[];
    final updates = <ElEventCallback>[];
    var ends = 0;
    await tester.pumpWidget(
      _shell(
        Listener(
          onPointerMove: rawMoves.add,
          child: ElEventView(
            event: ElEvent(
              config: const ElEventConfig(dragStartDistance: 0),
              onDragStart: (_) {},
              onDragUpdate: updates.add,
              onDragEnd: (_) => ends++,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final base = binding.currentSystemFrameTimeStamp;
    final gesture = await _start(tester, const Offset(20, 20), timeStamp: base);
    await gesture.moveTo(const Offset(40, 20), timeStamp: base + _ms(8));
    await gesture.moveTo(const Offset(60, 20), timeStamp: base + _ms(16));
    expect(rawMoves, isEmpty);
    await tester.pump(_ms(16));
    await gesture.moveTo(const Offset(80, 20), timeStamp: base + _ms(24));
    await tester.pump(_ms(8));
    expect(updates, isNotEmpty);
    expect(
      (updates.last.originalEvent as PointerEvent).original,
      same(rawMoves.last.original),
    );
    expect(updates.last.globalPosition, rawMoves.last.position);
    await gesture.up(timeStamp: base + _ms(32));
    expect(ends, 1);
    await tester.pump(_ms(100));
  });

  _platformTest('官方 ListView 正常滚动并保留甩出惯性', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ListView.builder(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          itemExtent: 50,
          itemCount: 100,
          itemBuilder: (_, index) => Text('$index'),
        ),
      ),
    );
    final base = binding.currentSystemFrameTimeStamp;
    final gesture = await _start(
      tester,
      const Offset(150, 250),
      timeStamp: base,
    );
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(
        Offset(150, 250 - i * 12),
        timeStamp: base + _ms(i * 8),
      );
      await tester.pump(_ms(8));
    }
    expect(controller.offset, greaterThan(50));
    await gesture.up(timeStamp: base + _ms(100));
    final released = controller.offset;
    expect(controller.position.isScrollingNotifier.value, isTrue);
    await tester.pump();
    await tester.pump(_ms(32));
    expect(controller.offset, greaterThan(released));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _platformTest('原始输入停顿后抬起不会因迟到采样重新产生甩动', (tester) async {
    Velocity? released;
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (_) {},
          onPanEnd: (details) => released = details.velocity,
        ),
      ),
    );
    final base = binding.currentSystemFrameTimeStamp;
    final gesture = await _start(tester, const Offset(20, 20), timeStamp: base);
    for (var i = 1; i <= 3; i++) {
      await gesture.moveTo(
        Offset(20 + i * 10, 20),
        timeStamp: base + _ms(i * 8),
      );
      await tester.pump(_ms(8));
    }
    await gesture.moveTo(const Offset(60, 20), timeStamp: base + _ms(32));
    await tester.pump(_ms(100));
    await gesture.up(timeStamp: base + _ms(132));
    expect(released, Velocity.zero);
    await tester.pump(_ms(100));
  });

  _platformTest('官方多指缩放保持对称中心与旋转方向', (tester) async {
    final updates = <ScaleUpdateDetails>[];
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleUpdate: updates.add,
        ),
      ),
    );
    final base = binding.currentSystemFrameTimeStamp;
    final first = await _start(
      tester,
      const Offset(100, 100),
      pointer: 1,
      timeStamp: base,
    );
    final second = await _start(
      tester,
      const Offset(200, 100),
      pointer: 2,
      timeStamp: base,
    );
    for (final ms in [8, 16]) {
      await first.moveTo(Offset(100 - ms * 4, 100), timeStamp: base + _ms(ms));
      await second.moveTo(Offset(200 + ms * 4, 100), timeStamp: base + _ms(ms));
    }
    await tester.pump(_ms(32));
    expect(updates, isNotEmpty);
    expect(updates.last.scale, greaterThan(1));
    expect(updates.last.focalPoint.dx, closeTo(150, 0.001));
    expect(updates.last.rotation, closeTo(0, 0.001));
    await first.up(timeStamp: base + _ms(40));
    await second.up(timeStamp: base + _ms(40));
    await tester.pump(_ms(100));
  });

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    _platformTest('$platform 的触摸输入直接分发', (tester) async {
      final moves = <PointerMoveEvent>[];
      await tester.pumpWidget(
        _shell(
          Listener(behavior: HitTestBehavior.opaque, onPointerMove: moves.add),
        ),
      );
      final gesture = await _start(tester, const Offset(20, 20));
      await gesture.moveBy(const Offset(10, 0));
      expect(moves.single.delta, const Offset(10, 0));
      await gesture.up();
    }, platform: platform);
  }

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
    _platformTest('Android 的 $kind 输入直接分发', (tester) async {
      final moves = <PointerMoveEvent>[];
      await tester.pumpWidget(
        _shell(
          Listener(behavior: HitTestBehavior.opaque, onPointerMove: moves.add),
        ),
      );
      final gesture = await _start(tester, const Offset(20, 20), kind: kind);
      await gesture.moveBy(const Offset(10, 0));
      expect(moves.single.delta, const Offset(10, 0));
      await gesture.up();
      await gesture.removePointer();
    });
  }

  _platformTest('框架 cancelPointer 正确结束采样并保留取消回调', (tester) async {
    final moves = <PointerMoveEvent>[];
    var canceled = 0;
    await tester.pumpWidget(
      _shell(
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerMove: moves.add,
          onPointerCancel: (_) => canceled++,
        ),
      ),
    );
    final base = binding.currentSystemFrameTimeStamp;
    final gesture = await _start(
      tester,
      const Offset(20, 20),
      pointer: 55,
      timeStamp: base,
    );
    await gesture.moveBy(const Offset(20, 0), timeStamp: base + _ms(8));
    binding.cancelPointer(55);
    await tester.idle();
    expect(canceled, 1);
    expect(moves, isEmpty);
    await tester.pump(_ms(100));
    expect(moves, isEmpty);
  });
}

class _InputTestBinding extends AutomatedTestWidgetsFlutterBinding
    with TouchResamplingBinding {}

Widget _shell(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 300, height: 300, child: child),
  ),
);

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);
void _architectureTests() {
  test('可选输入模块仅依赖 Flutter SDK 和自身目录', () {
    final root = Directory('lib/src/flutter_base/sdk').absolute.uri;
    final imports = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
    for (final path in [
      'lib/src/flutter_base/sdk/binding.dart',
      'lib/src/flutter_base/sdk/touch_resampling.dart',
    ]) {
      final file = File(path);
      for (final match in imports.allMatches(file.readAsStringSync())) {
        final target = match.group(1)!;
        if (target.startsWith('dart:') ||
            target.startsWith('package:flutter/')) {
          continue;
        }
        expect(
          file.absolute.uri.resolve(target).toString(),
          startsWith(root.toString()),
          reason: file.path,
        );
      }
    }
  });

  test('主入口只导出可选绑定，事件模块不引用输入模块', () {
    final entry = File('lib/flutter_base.dart').readAsStringSync();
    expect(entry, contains("export 'src/flutter_base/sdk/binding.dart'"));
    expect(entry, isNot(contains('ensureInitialized()')));
    for (final path in ['lib/flutter.dart', 'lib/ui.dart']) {
      expect(File(path).readAsStringSync(), isNot(contains('binding.dart')));
    }
    final eventFiles = Directory('lib/src/ui/cores/event')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in eventFiles) {
      expect(
        file.readAsStringSync(),
        isNot(contains('flutter_base/sdk')),
        reason: file.path,
      );
    }
  });
}

// createGesture 允许显式设置按下时戳，保持触点与系统帧使用同一时钟。
Future<TestGesture> _start(
  WidgetTester tester,
  Offset position, {
  int? pointer,
  PointerDeviceKind kind = PointerDeviceKind.touch,
  Duration timeStamp = Duration.zero,
}) async {
  final gesture = await tester.createGesture(pointer: pointer, kind: kind);
  await gesture.down(position, timeStamp: timeStamp);
  return gesture;
}

void _platformTest(
  String description,
  WidgetTesterCallback callback, {
  TargetPlatform platform = TargetPlatform.android,
}) {
  testWidgets(
    description,
    callback,
    variant: TargetPlatformVariant.only(platform),
  );
}
