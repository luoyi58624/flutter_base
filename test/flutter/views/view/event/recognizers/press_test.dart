import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/views/view/event/press.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recognizer_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final longPress in [false, true]) {
    testWidgets('被动按压不抢官方点击，长按仍可独立竞争：long=$longPress', (tester) async {
      final trace = <String>[];
      final press = PressRecognizer()
        ..competeForTap = false
        ..longPressDelay = const Duration(milliseconds: 20)
        ..callbacks[ElEventPhase.tapDown] = ((_) => trace.add('down'))
        ..callbacks[ElEventPhase.tapUp] = ((_) => trace.add('up'))
        ..callbacks[ElEventPhase.tap] = ((_) => trace.add('tap'))
        ..callbacks[ElEventPhase.longPress] = longPress ? (_) => trace.add('long') : null;
      final official = TapGestureRecognizer()..onTap = () => trace.add('official');
      addTearDown(press.dispose);
      addTearDown(official.dispose);
      _down(1900, [press, official]);
      _up(1900);
      expect(trace, ['down', 'up', 'official']);
      if (longPress) {
        trace.clear();
        _down(1901, [press, official]);
        await tester.pump(const Duration(milliseconds: 20));
        _up(1901);
        expect(trace, ['down', 'long', 'up']);
      }
    });
  }

  testWidgets('资格移出取消、移回恢复，所有通知保留原始 Down', (tester) async {
    final details = <PressGestureDetails>[];
    final press = PressRecognizer()
      ..tapSlopTolerance = double.infinity
      ..isEligible = ((_, event) => event.position.dx < 20)
      ..callbacks[ElEventPhase.tapDown] = details.add
      ..callbacks[ElEventPhase.tapCancel] = details.add
      ..callbacks[ElEventPhase.tapUp] = details.add
      ..callbacks[ElEventPhase.tap] = details.add
      ..onReleased = details.add;
    addTearDown(press.dispose);
    _down(1902, [press]);
    _move(1902, const Offset(30, 0));
    _move(1902, const Offset(10, 0));
    _up(1902, position: const Offset(10, 0));
    expect(details.map((event) => event.phase), [
      ElEventPhase.tapDown,
      ElEventPhase.tapCancel,
      ElEventPhase.tapDown,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
      ElEventPhase.tapUp,
    ]);
    expect(details[1].cancelReason, PressCancelReason.ineligible);
    expect(details[2].originalEvent, isA<PointerMoveEvent>());
    expect(details.every((event) => identical(event.downEvent, details.first.downEvent)), isTrue);
  });

  testWidgets('被动多指可逐指取消，取消别的指针不使当前回调失效', (tester) async {
    final trace = <String>[];
    late PressRecognizer press;
    press = PressRecognizer()
      ..competeForTap = false
      ..callbacks[ElEventPhase.tapDown] = (event) {
        trace.add('${event.pointer}.down');
        if (event.pointer == 1904) {
          press.cancelPointer(1903);
          expect(event.isActive, isTrue);
        }
      }
      ..callbacks[ElEventPhase.tapCancel] = ((event) => trace.add('${event.pointer}.cancel'))
      ..callbacks[ElEventPhase.tapUp] = (event) => trace.add('${event.pointer}.up');
    addTearDown(press.dispose);
    _down(1903, [press]);
    _down(1904, [press]);
    _up(1903);
    _up(1904);
    expect(trace, ['1903.down', '1904.down', '1903.cancel', '1904.up']);
    _down(1905, [press]);
    press.cancelMember(1905);
    _up(1905);
    expect(trace.skip(4), ['1905.down', '1905.cancel']);
  });

  for (final competing in [false, true]) {
    testWidgets('点击竞争意图在本轮 Down 冻结：competing=$competing', (tester) async {
      final trace = <String>[];
      final press = PressRecognizer()
        ..competeForTap = competing
        ..callbacks[ElEventPhase.tap] = (_) => trace.add('el');
      final official = TapGestureRecognizer()..onTap = () => trace.add('official');
      addTearDown(press.dispose);
      addTearDown(official.dispose);
      _down(1906, [press, official]);
      press.competeForTap = !competing;
      _up(1906);
      expect(trace, [competing ? 'el' : 'official']);
    });
  }

  testWidgets('关闭主键竞争不提前提交侧键，官方内层右键仍优先', (tester) async {
    final trace = <String>[];
    final press = PressRecognizer()
      ..competeForTap = false
      ..callbacks[ElEventPhase.secondaryTap] = (_) => trace.add('el');
    final official = TapGestureRecognizer()..onSecondaryTap = () => trace.add('official');
    addTearDown(press.dispose);
    addTearDown(official.dispose);
    _down(1907, [official, press], buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    _up(1907, kind: PointerDeviceKind.mouse);
    expect(trace, ['official']);
  });

  testWidgets('纯团队独占结清祖先原始输入与按压，本成员取消点击后仍收到 Up', (tester) async {
    final trace = <String>[];
    final parentTeam = GestureTeam()
      ..onPointerEvent = (event, _) {
        if (event is PointerCancelEvent) trace.add('parent.rawCancel');
        return true;
      };
    final childTeam = GestureTeam(parent: parentTeam)..onPointerEvent = (_, _) => true;
    final parent = PressRecognizer()
      ..team = parentTeam
      ..callbacks[ElEventPhase.tapDown] = ((_) => trace.add('parent.down'))
      ..callbacks[ElEventPhase.tapCancel] = ((_) => trace.add('parent.cancel'))
      ..callbacks[ElEventPhase.tap] = (_) => trace.add('parent.tap');
    final child = PressRecognizer()
      ..team = childTeam
      ..parent = parent
      ..callbacks[ElEventPhase.tapDown] = (event) {
        trace.add('child.down');
        childTeam.claimPointer(event.pointer, cancelTap: true);
      }
      ..callbacks[ElEventPhase.tapCancel] = ((_) => trace.add('child.cancel'))
      ..callbacks[ElEventPhase.tapUp] = ((_) => trace.add('child.up'))
      ..callbacks[ElEventPhase.tap] = (_) => trace.add('child.tap');
    final official = TapGestureRecognizer()..onTap = () => trace.add('official');
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    addTearDown(official.dispose);
    addTearDown(childTeam.dispose);
    addTearDown(parentTeam.dispose);
    const down = PointerDownEvent(pointer: 1908);
    childTeam.observePointer(down);
    parentTeam.observePointer(down);
    for (final recognizer in [child, parent, official]) {
      recognizer.addPointer(down);
    }
    GestureBinding.instance.pointerRouter.route(down);
    GestureBinding.instance.gestureArena.close(down.pointer);
    const up = PointerUpEvent(pointer: 1908);
    childTeam.observePointer(up);
    parentTeam.observePointer(up);
    GestureBinding.instance.pointerRouter.route(up);
    GestureBinding.instance.gestureArena.sweep(up.pointer);
    await tester.pump();
    expect(trace, ['child.down', 'child.cancel', 'parent.rawCancel', 'child.up']);
    expect([childTeam.pointerCount, parentTeam.pointerCount], [0, 0]);
  });

  testWidgets('属性配置在按下时冻结，清空参数后由识别器恢复默认时限', (tester) async {
    var count = 0;
    final press = PressRecognizer()
      ..longPressDelay = const Duration(milliseconds: 10)
      ..callbacks[ElEventPhase.longPress] = (_) => count++;
    addTearDown(press.dispose);
    _down(1800, [press]);
    press.longPressDelay = null;
    await tester.pump(const Duration(milliseconds: 20));
    expect(count, 1);
    _up(1800);
    _down(1801, [press]);
    await tester.pump(const Duration(milliseconds: 20));
    expect(count, 1);
    await tester.pump(kLongPressTimeout);
    expect(count, 2);
    _up(1801);
  });

  testWidgets('团队独占按物理 Down 校验，旧序列不能接受同编号的新竞技场', (tester) async {
    final trace = <String>[];
    final team = GestureTeam()..onPointerEvent = (_, _) => true;
    final press = PressRecognizer()
      ..team = team
      ..callbacks[ElEventPhase.tap] = (_) {
        trace.add('el');
      };
    final official = TapGestureRecognizer()..onTap = () => trace.add('official');
    addTearDown(press.dispose);
    addTearDown(official.dispose);
    addTearDown(team.dispose);
    void dispatch(PointerEvent event) {
      team.observePointer(event);
      if (event is PointerDownEvent) {
        official.addPointer(event);
        press.addPointer(event);
      }
      GestureBinding.instance.pointerRouter.route(event);
      if (event is PointerDownEvent) {
        GestureBinding.instance.gestureArena.close(event.pointer);
      } else if (event is PointerUpEvent) {
        GestureBinding.instance.gestureArena.sweep(event.pointer);
      }
    }

    final first = TestPointer(1909);
    dispatch(first.down(Offset.zero));
    final oldDown = team.downEventFor(1909);
    dispatch(first.up());
    await tester.pump();
    final second = TestPointer(1909);
    dispatch(second.down(Offset.zero));
    team.claimPointer(1909, downEvent: oldDown);
    dispatch(second.up());
    await tester.pump();
    expect(trace, ['official', 'official']);
    expect(team.pointerCount, 0);
  });

  test('识别器只导入 Dart 和 Flutter，不依赖宿主配置或事件模块', () {
    final file = File('lib/src/flutter/views/view/event/press.dart');
    final imports = RegExp("import\\s+['\"]([^'\"]+)['\"]");
    for (final directive in imports.allMatches(file.readAsStringSync())) {
      expect(directive.group(1), anyOf(startsWith('dart:'), startsWith('package:flutter/')), reason: file.path);
    }
  });

  testWidgets('所有按压阶段都提供冒泡控制，截断后的祖先候选仍被结清', (tester) async {
    const phases = [
      ElEventPhase.tapDown,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
      ElEventPhase.doubleTapDown,
      ElEventPhase.doubleTap,
      ElEventPhase.tripleTapDown,
      ElEventPhase.tripleTap,
      ElEventPhase.longPress,
      ElEventPhase.tapCancel,
      ElEventPhase.secondaryTapDown,
      ElEventPhase.secondaryTapUp,
      ElEventPhase.secondaryTap,
      ElEventPhase.tertiaryTapDown,
      ElEventPhase.tertiaryTapUp,
      ElEventPhase.tertiaryTap,
      ElEventPhase.forwardTapDown,
      ElEventPhase.forwardTapUp,
      ElEventPhase.forwardTap,
      ElEventPhase.backTapDown,
      ElEventPhase.backTapUp,
      ElEventPhase.backTap,
    ];
    var nextPointer = 430;
    for (final phase in phases) {
      final trace = <(bool, ElEventPhase)>[];
      final downEvents = <PointerEvent>[];
      final parent = PressRecognizer();
      final child = PressRecognizer()
        ..parent = parent
        ..longPressDelay = const Duration(milliseconds: 20);
      void wire(PressRecognizer recognizer, bool isChild) {
        void record(PressGestureDetails details) {
          downEvents.add(details.downEvent);
          trace.add((isChild, details.phase));
          if (isChild && details.phase == phase) details.stopPropagation();
        }

        recognizer
          ..callbacks[ElEventPhase.tapDown] = record
          ..callbacks[ElEventPhase.tapUp] = record
          ..callbacks[ElEventPhase.tap] = record
          ..callbacks[ElEventPhase.doubleTapDown] = record
          ..callbacks[ElEventPhase.doubleTap] = record
          ..callbacks[ElEventPhase.tripleTapDown] = record
          ..callbacks[ElEventPhase.tripleTap] = record
          ..callbacks[ElEventPhase.longPress] = record
          ..callbacks[ElEventPhase.tapCancel] = record
          ..callbacks[ElEventPhase.secondaryTapDown] = record
          ..callbacks[ElEventPhase.secondaryTapUp] = record
          ..callbacks[ElEventPhase.secondaryTap] = record
          ..callbacks[ElEventPhase.tertiaryTapDown] = record
          ..callbacks[ElEventPhase.tertiaryTapUp] = record
          ..callbacks[ElEventPhase.tertiaryTap] = record
          ..callbacks[ElEventPhase.forwardTapDown] = record
          ..callbacks[ElEventPhase.forwardTapUp] = record
          ..callbacks[ElEventPhase.forwardTap] = record
          ..callbacks[ElEventPhase.backTapDown] = record
          ..callbacks[ElEventPhase.backTapUp] = record
          ..callbacks[ElEventPhase.backTap] = record;
      }

      wire(parent, false);
      wire(child, true);
      final clicks = switch (phase) {
        ElEventPhase.doubleTapDown || ElEventPhase.doubleTap => 2,
        ElEventPhase.tripleTapDown || ElEventPhase.tripleTap => 3,
        _ => 1,
      };
      final buttons = switch (phase.name) {
        final name when name.startsWith('secondary') => kSecondaryButton,
        final name when name.startsWith('tertiary') => kTertiaryButton,
        final name when name.startsWith('forward') => kForwardMouseButton,
        final name when name.startsWith('back') => kBackMouseButton,
        _ => kPrimaryButton,
      };
      for (var i = 0; i < clicks; i++) {
        trace.clear();
        final pointer = nextPointer++;
        _down(pointer, [child, parent], buttons: buttons, milliseconds: i * 40);
        if (phase == ElEventPhase.longPress) {
          _move(pointer, const Offset(1, 0));
          await tester.pump(const Duration(milliseconds: 30));
        }
        if (phase == ElEventPhase.tapCancel) {
          GestureBinding.instance.pointerRouter.route(PointerCancelEvent(pointer: pointer));
        }
        _up(pointer, milliseconds: i * 40 + 30);
      }
      expect(trace, contains((true, phase)), reason: phase.name);
      expect(downEvents, everyElement(isA<PointerDownEvent>()), reason: phase.name);
      final cleanup = phase == ElEventPhase.tapCancel || phase.name.endsWith('Up');
      expect(trace.contains((false, phase)), cleanup, reason: phase.name);
      if (trace.contains((false, ElEventPhase.tapDown))) {
        expect(
          trace.any((item) => !item.$1 && (item.$2 == ElEventPhase.tapUp || item.$2 == ElEventPhase.tapCancel)),
          isTrue,
          reason: '${phase.name} 不能遗留祖先按压',
        );
      }
      child.dispose();
      parent.dispose();
    }
  });

  testWidgets('主动取消清除活动长按与待发单击，取消后识别器可复用', (tester) async {
    final trace = <ElEventPhase>[];
    final press = PressRecognizer()
      ..deferTap = true
      ..callbacks[ElEventPhase.tap] = (event) {
        trace.add(event.phase);
      }
      ..callbacks[ElEventPhase.doubleTap] = (event) {
        trace.add(event.phase);
      }
      ..callbacks[ElEventPhase.longPress] = (event) {
        trace.add(event.phase);
      }
      ..callbacks[ElEventPhase.tapCancel] = (event) {
        trace.add(event.phase);
      };
    _down(410, [press]);
    press.cancel();
    press.cancel();
    _up(410);
    await tester.pump(const Duration(seconds: 1));
    expect(trace, [ElEventPhase.tapCancel]);
    _down(411, [press]);
    _up(411);
    press.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(trace, [ElEventPhase.tapCancel]);
    press.deferTap = false;
    _down(412, [press]);
    _up(412);
    expect(trace, [ElEventPhase.tapCancel, ElEventPhase.tap]);
    press.dispose();
  });

  for (final disposeOnUp in [false, true]) {
    testWidgets('Up 中截断或销毁不能遗留祖先候选：dispose=$disposeOnUp', (tester) async {
      final trace = <String>[];
      final parent = recordingPress(trace, 'parent');
      late PressRecognizer child;
      child = recordingPress(trace, 'child', parent: parent)
        ..callbacks[ElEventPhase.tapUp] = (event) {
          trace.add('child.up');
          if (disposeOnUp) {
            child.dispose();
          } else {
            event.stopPropagation();
          }
        };
      addTearDown(parent.dispose);
      addTearDown(child.dispose);
      _down(260, [child, parent]);
      _up(260);
      expect(trace, ['child.down', 'parent.down', 'child.up', 'parent.up', disposeOnUp ? 'parent.tap' : 'child.tap']);
    });
  }

  testWidgets('连击窗口按双击分组，过期后重新开始且无双击时 deferTap 不延迟', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..deferTap = true
      ..callbacks[ElEventPhase.tap] = (event) => calls.add('tap${event.tapCount}');
    addTearDown(press.dispose);
    _down(201, [press]);
    _up(201);
    expect(calls, ['tap1']);
    press.callbacks[ElEventPhase.doubleTapDown] = (_) => calls.add('doubleDown');
    press.callbacks[ElEventPhase.doubleTap] = (_) => calls.add('double');
    press.deferTap = false;
    for (var index = 0; index < 4; index++) {
      _down(202 + index, [press], milliseconds: 50 + index * 40);
      _up(202 + index, milliseconds: 60 + index * 40);
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(calls, ['tap1', 'tap1', 'doubleDown', 'tap2', 'double', 'tap1', 'doubleDown', 'tap2', 'double']);
    await tester.pump(const Duration(milliseconds: 350));
    _down(206, [press], milliseconds: 600);
    _up(206, milliseconds: 610);
    expect(calls.last, 'tap1');
    press.dispose();
  });

  testWidgets('相同识别参数保留连击窗口，修改间隔后重新分组', (tester) async {
    var doubles = 0;
    final press = PressRecognizer()..callbacks[ElEventPhase.doubleTapDown] = (_) => doubles++;
    addTearDown(press.dispose);
    _down(210, [press]);
    _up(210, milliseconds: 10);
    press.doubleTapInterval = kDoubleTapTimeout;
    _down(211, [press], milliseconds: 40);
    _up(211, milliseconds: 50);
    expect(doubles, 1);
    _down(212, [press], milliseconds: 80);
    _up(212, milliseconds: 90);
    press.doubleTapInterval = const Duration(milliseconds: 500);
    _down(213, [press], milliseconds: 120);
    _up(213, milliseconds: 130);
    expect(doubles, 1);
    press.dispose();
  });

  testWidgets('长按移动取消不可回燃，宿主可独立取消点击', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..tapSlopTolerance = double.infinity
      ..longPressDelay = Duration(milliseconds: 50)
      ..longPressSlopTolerance = 10
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      }
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        calls.add('cancel');
      }
      ..callbacks[ElEventPhase.longPress] = (_) {
        calls.add('long');
      };
    addTearDown(press.dispose);
    _down(220, [press]);
    _move(220, const Offset(15, 0));
    _move(220, Offset.zero);
    await tester.pump(const Duration(milliseconds: 100));
    _up(220, milliseconds: 100);
    expect(calls, ['tap']);
    _down(221, [press], milliseconds: 120);
    press.cancelPointer(
      221,
      event: const PointerMoveEvent(pointer: 221, position: Offset(60, 0), timeStamp: Duration(milliseconds: 130)),
    );
    _up(221, position: const Offset(60, 0), milliseconds: 130);
    expect(calls, ['tap', 'cancel']);
  });

  testWidgets('侧键不触发长按，按钮组合变化只取消一次且不污染下一次主键', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..longPressDelay = Duration(milliseconds: 20)
      ..callbacks[ElEventPhase.secondaryTapDown] = (_) {
        calls.add('side.down');
      }
      ..callbacks[ElEventPhase.secondaryTap] = (_) {
        calls.add('side.tap');
      }
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        calls.add('cancel');
      }
      ..callbacks[ElEventPhase.longPress] = (_) {
        calls.add('long');
      }
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      };
    addTearDown(press.dispose);
    _down(230, [press], buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 30));
    GestureBinding.instance.pointerRouter.route(
      const PointerMoveEvent(pointer: 230, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton | kPrimaryButton),
    );
    _up(230, kind: PointerDeviceKind.mouse);
    _down(231, [press]);
    _up(231);
    expect(calls, ['side.down', 'cancel', 'tap']);
  });

  testWidgets('Cancel 内停止冒泡仍结清已收到 Down 的祖先', (tester) async {
    final trace = <String>[];
    final parent = recordingPress(trace, 'parent');
    final child = recordingPress(trace, 'child', parent: parent)
      ..callbacks[ElEventPhase.tapCancel] = (event) {
        trace.add('child.cancel');
        event.stopPropagation();
      };
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    _down(240, [child, parent]);
    GestureBinding.instance.pointerRouter.route(const PointerCancelEvent(pointer: 240));
    _up(240);
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.cancel']);
  });

  testWidgets('活动路线冻结 parent，下一次按下采用新的祖先', (tester) async {
    final trace = <String>[];
    final first = recordingPress(trace, 'first');
    final second = recordingPress(trace, 'second');
    final child = recordingPress(trace, 'child', parent: first);
    addTearDown(child.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    _down(250, [child, first]);
    child.parent = second;
    _up(250);
    _down(251, [child, second]);
    _up(251);
    expect(trace.where((e) => e.endsWith('.tap')), ['child.tap', 'first.tap', 'child.tap', 'second.tap']);
  });

  testWidgets('单击双击三击和候选 Down 按三次分组', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..callbacks[ElEventPhase.tap] = (event) {
        calls.add('tap${event.tapCount}');
      }
      ..callbacks[ElEventPhase.doubleTapDown] = (_) {
        calls.add('doubleDown');
      }
      ..callbacks[ElEventPhase.doubleTap] = (event) {
        calls.add('double${event.tapCount}');
      }
      ..callbacks[ElEventPhase.tripleTapDown] = (_) {
        calls.add('tripleDown');
      }
      ..callbacks[ElEventPhase.tripleTap] = (event) {
        calls.add('triple${event.tapCount}');
      };
    for (var pointer = 10; pointer < 14; pointer++) {
      _down(pointer, [press], milliseconds: (pointer - 10) * 50);
      _up(pointer, milliseconds: (pointer - 10) * 50 + 10);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(calls, ['tap1', 'doubleDown', 'tap2', 'double2', 'tripleDown', 'tap3', 'triple3', 'tap1']);
    press.dispose();
  });

  testWidgets('deferTap 只延迟业务通知，不持有竞技场', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..deferTap = true
      ..callbacks[ElEventPhase.tapUp] = (_) {
        calls.add('up');
      }
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      }
      ..callbacks[ElEventPhase.doubleTap] = (_) {
        calls.add('double');
      };
    final official = TapGestureRecognizer()
      ..onTap = () {
        calls.add('official');
      };
    _down(20, [press, official]);
    _up(20);
    expect(calls, ['up']);
    await tester.pump(const Duration(milliseconds: 100));
    _down(21, [press, official], milliseconds: 100);
    _up(21, milliseconds: 110);
    expect(calls, ['up', 'up', 'double']);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['up', 'up', 'double']);
    press.dispose();
    official.dispose();
  });

  testWidgets('不同位置的 deferred 单击不会被下一次点击吞掉', (tester) async {
    final taps = <Offset>[];
    final press = PressRecognizer()
      ..deferTap = true
      ..callbacks[ElEventPhase.tap] = (event) {
        taps.add(event.globalPosition);
      }
      ..callbacks[ElEventPhase.doubleTap] = (_) {};
    _down(22, [press]);
    _up(22);
    await tester.pump(const Duration(milliseconds: 50));
    _down(23, [press], position: const Offset(100, 0), milliseconds: 50);
    _up(23, position: const Offset(100, 0), milliseconds: 60);
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, [Offset.zero, const Offset(100, 0)]);
    press.dispose();
  });

  testWidgets('长按遵循官方胜负且只通知一次，抬起不再单击', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..callbacks[ElEventPhase.tapDown] = (_) {
        calls.add('down');
      }
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        calls.add('cancel');
      }
      ..callbacks[ElEventPhase.longPress] = (event) {
        calls.add('long');
      }
      ..callbacks[ElEventPhase.tapUp] = (_) {
        calls.add('up');
      }
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      };
    final official = TapGestureRecognizer()
      ..onTap = () {
        calls.add('official');
      };
    _down(30, [press, official]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, ['down', 'long', 'cancel']);
    _up(30, milliseconds: 600);
    expect(calls, ['down', 'long', 'cancel', 'up']);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['down', 'long', 'cancel', 'up']);
    press.dispose();
    official.dispose();
  });

  testWidgets('长按输给官方拖拽后 timer 不再通知且下一次可点击', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..tapSlopTolerance = double.infinity
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        calls.add('cancel');
      }
      ..callbacks[ElEventPhase.longPress] = (_) {
        calls.add('long');
      }
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      };
    final official = VerticalDragGestureRecognizer()
      ..onStart = (_) {
        calls.add('drag');
      };
    _down(31, [press, official]);
    _move(31, const Offset(0, 50));
    await tester.pump(const Duration(seconds: 1));
    _up(31, position: const Offset(0, 50));
    expect(calls, ['cancel', 'drag']);
    _down(32, [press]);
    _up(32);
    expect(calls, ['cancel', 'drag', 'tap']);
    press.dispose();
    official.dispose();
  });

  testWidgets('宿主取消不需要元素尺寸，取消后重新按下才产生新候选', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..tapSlopTolerance = double.infinity
      ..callbacks[ElEventPhase.tapDown] = (_) {
        calls.add('down');
      }
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        calls.add('cancel');
      }
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      };
    _down(40, [press]);
    _move(40, const Offset(30, 0));
    press.cancelPointer(40);
    press.cancelPointer(40);
    _move(40, Offset.zero);
    _up(40);
    expect(calls, ['down', 'cancel']);
    calls.clear();
    _down(41, [press]);
    _move(41, const Offset(100, 0));
    _up(41, position: const Offset(100, 0));
    expect(calls, ['down', 'tap']);
    calls.clear();
    press.tapSlopTolerance = null;
    _down(42, [press]);
    _move(42, const Offset(100, 0));
    _move(42, Offset.zero);
    _up(42);
    expect(calls, ['down', 'cancel']);
    press.dispose();
  });

  testWidgets('活动识别参数冻结，下一次按下才采用修改后的参数', (tester) async {
    final taps = <int>[];
    final press = PressRecognizer()
      ..tapSlopTolerance = 30
      ..callbacks[ElEventPhase.tap] = (_) {
        taps.add(1);
      };
    _down(42, [press]);
    press.tapSlopTolerance = 5;
    _move(42, const Offset(15, 0));
    _up(42, position: const Offset(15, 0));
    _down(43, [press]);
    _move(43, const Offset(15, 0));
    _up(43, position: const Offset(15, 0));
    expect(taps, [1]);
    press.dispose();
  });

  testWidgets('每种单独鼠标按钮都有 down、up、tap', (tester) async {
    final phases = <ElEventPhase>[];
    void record(PressGestureDetails event) => phases.add(event.phase);
    final press = PressRecognizer()
      ..callbacks[ElEventPhase.secondaryTapDown] = record
      ..callbacks[ElEventPhase.secondaryTapUp] = record
      ..callbacks[ElEventPhase.secondaryTap] = record
      ..callbacks[ElEventPhase.tertiaryTapDown] = record
      ..callbacks[ElEventPhase.tertiaryTapUp] = record
      ..callbacks[ElEventPhase.tertiaryTap] = record
      ..callbacks[ElEventPhase.forwardTapDown] = record
      ..callbacks[ElEventPhase.forwardTapUp] = record
      ..callbacks[ElEventPhase.forwardTap] = record
      ..callbacks[ElEventPhase.backTapDown] = record
      ..callbacks[ElEventPhase.backTapUp] = record
      ..callbacks[ElEventPhase.backTap] = record;
    const buttons = [kSecondaryButton, kTertiaryButton, kForwardMouseButton, kBackMouseButton];
    for (var index = 0; index < buttons.length; index++) {
      _down(50 + index, [press], buttons: buttons[index], kind: PointerDeviceKind.mouse);
      _up(50 + index, kind: PointerDeviceKind.mouse);
    }
    expect(phases, [
      ElEventPhase.secondaryTapDown,
      ElEventPhase.secondaryTapUp,
      ElEventPhase.secondaryTap,
      ElEventPhase.tertiaryTapDown,
      ElEventPhase.tertiaryTapUp,
      ElEventPhase.tertiaryTap,
      ElEventPhase.forwardTapDown,
      ElEventPhase.forwardTapUp,
      ElEventPhase.forwardTap,
      ElEventPhase.backTapDown,
      ElEventPhase.backTapUp,
      ElEventPhase.backTap,
    ]);
    press.dispose();
  });

  testWidgets('空处理器、按钮过滤和设备过滤不抢官方 Tap', (tester) async {
    var taps = 0;
    final press = PressRecognizer();
    final official = TapGestureRecognizer()
      ..onTap = () {
        taps++;
      };
    _down(60, [press, official]);
    _up(60);
    expect(taps, 1);
    press.callbacks[ElEventPhase.tap] = (_) => fail('设备过滤后的识别器不能触发');
    press.supportedDevices = {PointerDeviceKind.mouse};
    _down(61, [press, official]);
    _up(61);
    expect(taps, 2);
    final filtered = PressRecognizer(allowedButtonsFilter: (_) => false)
      ..callbacks[ElEventPhase.tap] = (_) {
        fail('按钮过滤后的识别器不能触发');
      };
    _down(62, [filtered, official]);
    _up(62);
    expect(taps, 3);
    press.dispose();
    filtered.dispose();
    official.dispose();
  });

  testWidgets('主动接受请求参与官方裁决，成功后仍正常通知释放和点击', (tester) async {
    final calls = <String>[];
    late PressRecognizer press;
    press = PressRecognizer()
      ..callbacks[ElEventPhase.tapDown] = (event) {
        calls.add('down');
        press.acceptPointer(event.pointer);
      }
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        calls.add('cancel');
      }
      ..callbacks[ElEventPhase.tapUp] = (_) {
        calls.add('up');
      }
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      }
      ..callbacks[ElEventPhase.longPress] = (_) {
        calls.add('long');
      };
    final official = TapGestureRecognizer()
      ..onTap = () {
        calls.add('official');
      };
    _down(70, [official, press]);
    _up(70);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['down', 'up', 'tap']);
    press.dispose();
    official.dispose();
  });

  testWidgets('业务异常不会破坏后续识别，dispose 回调重入不会重复取消', (tester) async {
    var taps = 0;
    final press = PressRecognizer()
      ..callbacks[ElEventPhase.tap] = (_) {
        taps++;
        throw StateError('expected callback failure');
      };
    _down(80, [press]);
    _up(80);
    expect(tester.takeException(), isA<StateError>());
    _down(81, [press]);
    _up(81);
    expect(tester.takeException(), isA<StateError>());
    expect(taps, 2);
    var cancels = 0;
    press
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        cancels++;
        press.dispose();
      }
      ..callbacks[ElEventPhase.longPress] = (_) {
        fail('销毁后的 timer 不能触发');
      };
    _down(82, [press]);
    press.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(cancels, 1);
  });

  testWidgets('追加指针取消原候选，取消后新的独立序列可正常点击', (tester) async {
    var taps = 0;
    var cancels = 0;
    final press = PressRecognizer()
      ..callbacks[ElEventPhase.tap] = (_) {
        taps++;
      }
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        cancels++;
      };
    _down(90, [press]);
    _down(91, [press]);
    _up(90);
    _up(91);
    _down(92, [press]);
    _up(92);
    expect(cancels, 1);
    expect(taps, 1);
    press.dispose();
  });

  testWidgets('追加指针取消沿用旧指针最后位置和各级坐标变换', (tester) async {
    final canceled = <(String, Offset, Offset, int)>[];
    void record(String name, PressGestureDetails event) {
      canceled.add((name, event.globalPosition, event.localPosition, event.pointer));
    }

    final parent = PressRecognizer()
      ..callbacks[ElEventPhase.tapCancel] = (event) {
        record('parent', event);
      };
    final child = PressRecognizer()
      ..parent = parent
      ..callbacks[ElEventPhase.tapCancel] = (event) {
        record('child', event);
      };
    const first = PointerDownEvent(pointer: 130, position: Offset(100, 100), buttons: kPrimaryButton);
    child.addPointer(first.transformed(Matrix4.translationValues(-10, -20, 0)));
    parent.addPointer(first.transformed(Matrix4.translationValues(-30, -40, 0)));
    GestureBinding.instance.pointerRouter.route(first);
    GestureBinding.instance.gestureArena.close(130);
    GestureBinding.instance.pointerRouter.route(
      const PointerMoveEvent(pointer: 130, position: Offset(105, 107), delta: Offset(5, 7), buttons: kPrimaryButton),
    );

    const second = PointerDownEvent(pointer: 131, position: Offset(400, 500), buttons: kPrimaryButton);
    child.addPointer(second.transformed(Matrix4.translationValues(-100, -200, 0)));
    expect(canceled, [
      ('child', const Offset(105, 107), const Offset(95, 87), 130),
      ('parent', const Offset(105, 107), const Offset(75, 67), 130),
    ]);
    _up(130, position: const Offset(105, 107));
    child.dispose();
    parent.dispose();
  });

  testWidgets('平台取消清除长按计时，deferred 通知也随 dispose 释放', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..deferTap = true
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      }
      ..callbacks[ElEventPhase.doubleTap] = (_) {
        calls.add('double');
      }
      ..callbacks[ElEventPhase.longPress] = (_) {
        calls.add('long');
      }
      ..callbacks[ElEventPhase.tapCancel] = (event) {
        calls.add(event.cancelReason!.name);
      };
    _down(100, [press]);
    GestureBinding.instance.pointerRouter.route(const PointerCancelEvent(pointer: 100));
    GestureBinding.instance.gestureArena.sweep(100);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['pointerCanceled']);
    _down(101, [press]);
    _up(101);
    press.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['pointerCanceled']);
  });

  testWidgets('后续候选失权不会吞掉已成功的 deferred 单击', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..deferTap = true
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      }
      ..callbacks[ElEventPhase.doubleTap] = (_) {
        calls.add('double');
      };
    final official = TapGestureRecognizer()
      ..onTap = () {
        calls.add('official');
      };
    _down(102, [press]);
    _up(102);
    await tester.pump(const Duration(milliseconds: 50));
    _down(103, [official, press], milliseconds: 50);
    _up(103, milliseconds: 70);
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, ['official', 'tap']);
    press.dispose();
    official.dispose();
  });

  testWidgets('deferred 路线允许复用鼠标指针并冻结各次祖先坐标', (tester) async {
    final positions = <Offset>[];
    final parent = PressRecognizer()
      ..callbacks[ElEventPhase.tap] = (event) {
        positions.add(event.localPosition);
      };
    final child = PressRecognizer()
      ..parent = parent
      ..deferTap = true
      ..callbacks[ElEventPhase.doubleTap] = (_) {};

    void down(Offset position, Offset translation, int milliseconds) {
      const pointer = 110;
      final event = PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
        timeStamp: Duration(milliseconds: milliseconds),
      );
      child.addPointer(event);
      parent.addPointer(event.transformed(Matrix4.translationValues(translation.dx, translation.dy, 0)));
      GestureBinding.instance.pointerRouter.route(event);
      GestureBinding.instance.gestureArena.close(pointer);
    }

    down(const Offset(100, 100), const Offset(-10, -20), 0);
    _up(110, position: const Offset(100, 100), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 100));
    down(const Offset(200, 200), const Offset(-70, -80), 100);
    // 旧 timer 结束路线时不能清掉复用同一 pointer 的新候选。
    await tester.pump(const Duration(milliseconds: 220));
    expect(positions, [const Offset(90, 80)]);
    _up(110, position: const Offset(200, 200), milliseconds: 330, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(positions, [const Offset(90, 80), const Offset(130, 120)]);
    child.dispose();
    parent.dispose();
  });

  testWidgets('官方 DoubleTap 持有前一次竞技场时仍跟踪下一次候选', (tester) async {
    final calls = <String>[];
    final press = PressRecognizer()
      ..callbacks[ElEventPhase.tapDown] = (_) {
        calls.add('down');
      }
      ..callbacks[ElEventPhase.tap] = (_) {
        calls.add('tap');
      }
      ..callbacks[ElEventPhase.tapCancel] = (_) {
        calls.add('cancel');
      };
    final official = DoubleTapGestureRecognizer()
      ..onDoubleTap = () {
        calls.add('officialDouble');
      };
    _down(120, [press, official]);
    _up(120);
    await tester.pump(const Duration(milliseconds: 100));
    _down(121, [press, official], milliseconds: 100);
    _up(121, milliseconds: 120);
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, ['down', 'cancel', 'down', 'cancel', 'officialDouble']);
    press.dispose();
    official.dispose();
  });

  testWidgets('TapDown 截断只影响 El 冒泡，官方外层仍由竞技场取消', (tester) async {
    final events = <String>[];
    final parent = recordingPress(events, 'parent');
    final child = recordingPress(events, 'child', parent: parent)
      ..callbacks[ElEventPhase.tapDown] = (event) {
        events.add('child.down');
        event.stopPropagation();
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      gestureShell(
        GestureDetector(
          onTapDown: (_) => events.add('official.down'),
          onTap: () => events.add('official.tap'),
          onTapCancel: () => events.add('official.cancel'),
          child: gestureHost(parent, child: gestureHost(child)),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pump(afterGesture);

    expect(events.where((event) => event.startsWith('parent.')), isEmpty);
    expect(events, containsAll(['child.up', 'child.tap', 'official.cancel']));
    expect(events, isNot(contains('official.tap')));
  });

  testWidgets('停止 El 冒泡不能抢走官方子 Tap 的胜利', (tester) async {
    final events = <String>[];
    final parent = recordingPress(events, 'parent');
    final child = recordingPress(events, 'child', parent: parent)
      ..callbacks[ElEventPhase.tapDown] = (event) {
        events.add('child.down');
        event.stopPropagation();
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      gestureShell(
        gestureHost(
          parent,
          child: gestureHost(
            child,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => events.add('official.tap'),
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.up();
    await tester.pump(afterGesture);

    expect(events.where((event) => event.startsWith('parent.')), isEmpty);
    expect(events.where((event) => event.endsWith('.tap')), ['official.tap']);
    expect(events, contains('child.cancel'));
    expect(events, isNot(contains('child.up')));
  });

  testWidgets('ListView 滚动获胜后内部 El 点击和长按不会在释放后复活', (tester) async {
    final events = <String>[];
    final press = recordingPress(events, 'el');
    final controller = ScrollController();
    addTearDown(press.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      gestureShell(
        SizedBox(
          width: 200,
          height: 250,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              gestureHost(press, child: const SizedBox(height: 200)),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(60, 150));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(0, -50));
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    expect(events, ['el.down', 'el.cancel']);
  });

  testWidgets('冒泡分别换算变换后子节点与父节点的本地坐标', (tester) async {
    final parentKey = GlobalKey();
    final childKey = GlobalKey();
    final positions = <String, Offset>{};
    final parent = PressRecognizer()
      ..callbacks[ElEventPhase.tap] = (event) => positions['parent'] = event.localPosition;
    final child = PressRecognizer()
      ..parent = parent
      ..callbacks[ElEventPhase.tap] = (event) => positions['child'] = event.localPosition;
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      gestureShell(
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 30),
          child: gestureHost(
            parent,
            key: parentKey,
            child: Padding(
              padding: const EdgeInsets.only(left: 40, top: 50),
              child: Transform.scale(
                scale: 2,
                alignment: Alignment.topLeft,
                child: gestureHost(child, key: childKey),
              ),
            ),
          ),
        ),
      ),
    );
    final childBox = childKey.currentContext!.findRenderObject()! as RenderBox;
    final global = childBox.localToGlobal(const Offset(10, 15));
    await tester.tapAt(global);
    await tester.pump(afterGesture);

    expect(positions['child'], const Offset(10, 15));
    expect(positions['parent'], const Offset(60, 80));
  });

  testWidgets('委托父在官方子获胜时只收到一次取消，并使用父本地坐标', (tester) async {
    final parentKey = GlobalKey();
    final childKey = GlobalKey();
    final events = <String>[];
    final cancelPositions = <String, Offset>{};
    final parent = recordingPress(events, 'parent')
      ..callbacks[ElEventPhase.tapCancel] = (event) {
        events.add('parent.cancel');
        cancelPositions['parent'] = event.localPosition;
      };
    final child = recordingPress(events, 'child', parent: parent)
      ..callbacks[ElEventPhase.tapCancel] = (event) {
        events.add('child.cancel');
        cancelPositions['child'] = event.localPosition;
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      gestureShell(
        gestureHost(
          parent,
          key: parentKey,
          child: Padding(
            padding: const EdgeInsets.only(left: 40, top: 50),
            child: gestureHost(
              child,
              key: childKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => events.add('official.tap'),
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(50, 65));
    await tester.pump(afterGesture);

    expect(events.where((event) => event.endsWith('.cancel')), ['child.cancel', 'parent.cancel']);
    expect(events.where((event) => event.endsWith('.up')), isEmpty);
    expect(events.where((event) => event.endsWith('.tap')), ['official.tap']);
    expect(cancelPositions['child'], const Offset(10, 15));
    expect(cancelPositions['parent'], const Offset(50, 65));
  });

  testWidgets('透明重叠点击分支分别参赛，共享 El 父只订阅首次命中的路线', (tester) async {
    final events = <String>[];
    final parent = recordingPress(events, 'parent');
    final back = recordingPress(events, 'back', parent: parent);
    final front = recordingPress(events, 'front', parent: parent);
    addTearDown(parent.dispose);
    addTearDown(back.dispose);
    addTearDown(front.dispose);
    await tester.pumpWidget(
      GestureDetector(
        onTapDown: (_) => events.add('official.down'),
        onTap: () => events.add('official.tap'),
        onTapCancel: () => events.add('official.cancel'),
        child: overlapHost(parent: parent, back: back, front: front),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 700));

    // 两个分支都必须收到 Down，保证没有误将测试简化成单一命中。
    expect(events, containsAllInOrder(['front.down', 'parent.down', 'back.down']));
    expect(events.where((event) => event.startsWith('front.')), ['front.down', 'front.up', 'front.tap']);
    expect(events.where((event) => event.startsWith('back.')), ['back.down', 'back.cancel']);
    expect(events.where((event) => event.startsWith('parent.')), ['parent.down', 'parent.up', 'parent.tap']);
    expect(events.where((event) => event.startsWith('official.')), ['official.down', 'official.cancel']);
  });

  for (final stopCancel in [false, true]) {
    testWidgets('Down 内同步取消不向祖先补发孤立候选：stopCancel=$stopCancel', (tester) async {
      final trace = <String>[];
      final parent = PressRecognizer()
        ..callbacks[ElEventPhase.tapDown] = (_) {
          trace.add('parent.down');
        }
        ..callbacks[ElEventPhase.tapCancel] = (_) {
          trace.add('parent.cancel');
        }
        ..callbacks[ElEventPhase.tapUp] = (_) => trace.add('parent.up');
      late PressRecognizer child;
      child = PressRecognizer()
        ..parent = parent
        ..callbacks[ElEventPhase.tapDown] = (event) {
          trace.add('child.down');
          child.cancelPointer(event.pointer);
        }
        ..callbacks[ElEventPhase.tapCancel] = (event) {
          trace.add('child.cancel');
          if (stopCancel) event.stopPropagation();
        }
        ..callbacks[ElEventPhase.tapUp] = (_) => trace.add('child.up');
      addTearDown(parent.dispose);
      addTearDown(child.dispose);
      await tester.pumpWidget(gestureShell(gestureHost(parent, child: gestureHost(child))));

      await tester.tapAt(const Offset(50, 50));
      expect(trace, ['child.down', 'child.cancel']);
    });
  }

  testWidgets('子回调异常不会截断父冒泡，下一次点击仍可识别', (tester) async {
    final trace = <String>[];
    final parent = PressRecognizer()..callbacks[ElEventPhase.tap] = (_) => trace.add('parent');
    final child = PressRecognizer()
      ..parent = parent
      ..callbacks[ElEventPhase.tap] = (_) {
        trace.add('child');
        throw StateError('回调失败');
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(gestureShell(gestureHost(parent, child: gestureHost(child))));
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(const Offset(50, 50));
      expect(tester.takeException(), isA<StateError>());
    }
    expect(trace, ['child', 'parent', 'child', 'parent']);
  });

  testWidgets('子回调销毁委托父级后继续自身点击，父级不再收到事件', (tester) async {
    final trace = <String>[];
    final parent = PressRecognizer()
      ..callbacks[ElEventPhase.tapDown] = (_) {
        trace.add('parent.down');
      }
      ..callbacks[ElEventPhase.tap] = (_) => trace.add('parent.tap');
    final child = PressRecognizer()
      ..parent = parent
      ..callbacks[ElEventPhase.tapDown] = (_) {
        trace.add('child.down');
        parent.dispose();
      }
      ..callbacks[ElEventPhase.tap] = (_) => trace.add('child.tap');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(gestureShell(gestureHost(parent, child: gestureHost(child))));

    await tester.tapAt(const Offset(50, 50));
    expect(trace, ['child.down', 'child.tap']);
  });
  testWidgets('成员资格在连击提交前生效，子成员无效点击不污染父级历史', (tester) async {
    final trace = <String>[];
    var eligible = true;
    final parent = PressRecognizer()
      ..callbacks[ElEventPhase.tap] = (event) {
        trace.add('parent:${event.tapCount}');
      }
      ..callbacks[ElEventPhase.doubleTap] = (_) {};
    final child = PressRecognizer()
      ..parent = parent
      ..isEligible = ((_, _) => eligible)
      ..callbacks[ElEventPhase.tap] = (event) {
        trace.add('child:${event.tapCount}');
      }
      ..callbacks[ElEventPhase.doubleTap] = (_) {};
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    for (var i = 0; i < 3; i++) {
      eligible = i != 1;
      _down(1500 + i, [child, parent], milliseconds: i * 40);
      _up(1500 + i, milliseconds: i * 40 + 10);
    }
    expect(trace, ['child:1', 'parent:1', 'parent:2', 'child:1', 'parent:1']);
    child.dispose();
    parent.dispose();
  });

  testWidgets('取消当前成员不会结束父成员或复活已取消成员', (tester) async {
    final trace = <String>[];
    final parent = recordingPress(trace, 'parent');
    final child = recordingPress(trace, 'child', parent: parent);
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(1510, [child, parent]);
    expect(child.hasActiveInput, isTrue);
    expect(parent.hasActiveInput, isTrue);
    child.cancelMember(1510);
    expect(child.hasActiveInput, isFalse);
    expect(parent.hasActiveInput, isTrue);
    _up(1510);
    expect(parent.hasActiveInput, isFalse);
    expect(trace, ['child.down', 'parent.down', 'child.cancel', 'parent.up', 'parent.tap']);
  });

  testWidgets('父子长按采用各自等待时间，资格失败不提前认领官方手势', (tester) async {
    final trace = <String>[];
    var childEligible = false;
    final parent = PressRecognizer()
      ..longPressDelay = const Duration(milliseconds: 40)
      ..callbacks[ElEventPhase.longPress] = (_) => trace.add('parent.long');
    final child = PressRecognizer()
      ..parent = parent
      ..longPressDelay = const Duration(milliseconds: 10)
      ..isEligible = ((_, _) => childEligible)
      ..callbacks[ElEventPhase.longPress] = (_) => trace.add('child.long');
    final official = TapGestureRecognizer()..onTap = () => trace.add('official.tap');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    addTearDown(official.dispose);
    _down(1520, [child, parent, official]);
    await tester.pump(const Duration(milliseconds: 20));
    expect(trace, isEmpty);
    await tester.pump(const Duration(milliseconds: 20));
    expect(trace, ['parent.long']);
    _up(1520, milliseconds: 50);
    expect(trace, ['parent.long']);
    childEligible = true;
  });

  testWidgets('反馈只观察输入，不报名或抢走官方点击，短触摸不补播', (tester) async {
    final trace = <String>[];
    final press = PressRecognizer()
      ..feedbackDelay = Duration(milliseconds: 20)
      ..minimumFeedbackDuration = Duration(milliseconds: 100)
      ..onFeedbackChanged = ((value) => trace.add('feedback:$value'));
    final official = TapGestureRecognizer()..onTap = (() => trace.add('official'));
    addTearDown(press.dispose);
    addTearDown(official.dispose);
    _down(1800, [press, official]);
    expect(press.isPressed, isTrue);
    expect(press.isFeedbackActive, isFalse);
    await tester.pump(Duration(milliseconds: 5));
    _up(1800, milliseconds: 5);
    expect(press.isPressed, isFalse);
    await tester.pump(Duration(milliseconds: 120));
    expect(trace, ['official']);
    expect(press.isFeedbackActive, isFalse);
  });

  testWidgets('反馈延迟和最短时间不延迟 Up 与 Tap', (tester) async {
    final trace = <String>[];
    final press = PressRecognizer()
      ..feedbackDelay = Duration(milliseconds: 20)
      ..minimumFeedbackDuration = Duration(milliseconds: 100)
      ..onFeedbackChanged = ((value) => trace.add('feedback:$value'))
      ..callbacks[ElEventPhase.tapDown] = ((_) => trace.add('down'))
      ..callbacks[ElEventPhase.tapUp] = ((_) => trace.add('up'))
      ..callbacks[ElEventPhase.tap] = ((_) => trace.add('tap'));
    addTearDown(press.dispose);
    _down(1801, [press]);
    expect(trace, ['down']);
    await tester.pump(Duration(milliseconds: 25));
    expect(trace, ['down', 'feedback:true']);
    _up(1801, milliseconds: 25);
    expect(trace, ['down', 'feedback:true', 'up', 'tap']);
    expect(press.isPressed, isFalse);
    expect(press.isFeedbackActive, isTrue);
    await tester.pump(Duration(milliseconds: 74));
    expect(press.isFeedbackActive, isTrue);
    await tester.pump(Duration(milliseconds: 1));
    expect(trace, ['down', 'feedback:true', 'up', 'tap', 'feedback:false']);
  });

  testWidgets('活跃输入不包含已抬手的反馈保留和延迟单击窗口', (tester) async {
    final trace = <String>[];
    final press = PressRecognizer()
      ..deferTap = true
      ..minimumFeedbackDuration = Duration(milliseconds: 100)
      ..onFeedbackChanged = ((value) => trace.add('feedback:$value'))
      ..callbacks[ElEventPhase.doubleTap] = ((_) => trace.add('double'))
      ..callbacks[ElEventPhase.tap] = ((_) => trace.add('tap'));
    addTearDown(press.dispose);
    _down(1821, [press]);
    expect(press.hasActiveInput, isTrue);
    _up(1821);
    expect(press.hasActiveInput, isFalse);
    expect(press.isFeedbackActive, isTrue);
    expect(trace, ['feedback:true']);
    press.cancel();
    expect(press.hasActiveInput, isFalse);
    expect(trace, ['feedback:true', 'feedback:false']);
    await tester.pump(Duration(seconds: 1));
    expect(trace, ['feedback:true', 'feedback:false']);
  });

  testWidgets('临时越界熄灭反馈，返回不重算最初按下的最短时间', (tester) async {
    final feedback = <bool>[];
    var taps = 0;
    final press = PressRecognizer()
      ..tapSlopTolerance = double.infinity
      ..minimumFeedbackDuration = Duration(milliseconds: 100)
      ..isEligible = ((_, event) => event.position.dx < 20)
      ..onFeedbackChanged = feedback.add
      ..callbacks[ElEventPhase.tap] = ((_) => taps++);
    addTearDown(press.dispose);
    _down(1802, [press]);
    await tester.pump(Duration(milliseconds: 40));
    _move(1802, Offset(30, 0));
    expect(press.isPressed, isFalse);
    expect(feedback, [true, false]);
    await tester.pump(Duration(milliseconds: 20));
    _move(1802, Offset(10, 0));
    expect(press.isPressed, isTrue);
    _up(1802, position: Offset(10, 0), milliseconds: 60);
    expect(taps, 1);
    expect(feedback, [true, false, true]);
    await tester.pump(Duration(milliseconds: 39));
    expect(press.isFeedbackActive, isTrue);
    await tester.pump(Duration(milliseconds: 1));
    expect(feedback, [true, false, true, false]);
  });

  testWidgets('反馈计时按物理 Down 隔离，旧触摸截止不清除新反馈', (tester) async {
    final feedback = <bool>[];
    final press = PressRecognizer()
      ..minimumFeedbackDuration = Duration(milliseconds: 100)
      ..onFeedbackChanged = feedback.add;
    addTearDown(press.dispose);
    _down(1803, [press]);
    _up(1803, milliseconds: 5);
    await tester.pump(Duration(milliseconds: 50));
    _down(1804, [press], milliseconds: 50);
    _up(1804, milliseconds: 55);
    await tester.pump(Duration(milliseconds: 50));
    expect(press.isFeedbackActive, isTrue);
    expect(feedback, [true]);
    press.cancel();
    expect(feedback, [true, false]);
    await tester.pump(Duration(milliseconds: 100));
    expect(feedback, [true, false]);
  });

  testWidgets('成员取消也清除已经抬手的反馈保留', (tester) async {
    final feedback = <bool>[];
    final press = PressRecognizer()
      ..minimumFeedbackDuration = Duration(milliseconds: 100)
      ..onFeedbackChanged = feedback.add;
    addTearDown(press.dispose);
    _down(1822, [press]);
    _up(1822);
    expect(press.isFeedbackActive, isTrue);
    press.cancelMember();
    expect(press.isFeedbackActive, isFalse);
    expect(feedback, [true, false]);
    await tester.pump(Duration(milliseconds: 100));
    expect(feedback, [true, false]);
  });

  testWidgets('反馈回调异常不吞掉同一次按压的业务通知', (tester) async {
    final trace = <String>[];
    final press = PressRecognizer()
      ..onFeedbackChanged = (value) {
        if (value) throw StateError('feedback failure');
      }
      ..callbacks[ElEventPhase.tapDown] = ((_) => trace.add('down'))
      ..callbacks[ElEventPhase.tapUp] = ((_) => trace.add('up'))
      ..callbacks[ElEventPhase.tap] = ((_) => trace.add('tap'));
    addTearDown(press.dispose);
    _down(1823, [press]);
    expect(tester.takeException(), isA<StateError>());
    _up(1823);
    expect(trace, ['down', 'up', 'tap']);
  });

  testWidgets('鼠标反馈即时进入和释放，不采用触摸延迟或保留时间', (tester) async {
    final feedback = <bool>[];
    final press = PressRecognizer()
      ..feedbackDelay = Duration(seconds: 1)
      ..minimumFeedbackDuration = Duration(seconds: 1)
      ..onFeedbackChanged = feedback.add;
    addTearDown(press.dispose);
    _down(1805, [press], kind: PointerDeviceKind.mouse);
    expect(feedback, [true]);
    _up(1805, kind: PointerDeviceKind.mouse);
    expect(feedback, [true, false]);
  });

  testWidgets('反馈到期回调重入新的按压后，旧清理不会覆盖新状态', (tester) async {
    var reentered = false;
    final feedback = <bool>[];
    late PressRecognizer press;
    press = PressRecognizer()
      ..minimumFeedbackDuration = Duration(milliseconds: 20)
      ..onFeedbackChanged = (value) {
        feedback.add(value);
        if (!value && !reentered) {
          reentered = true;
          _down(1807, [press], milliseconds: 20);
        }
      };
    addTearDown(press.dispose);
    _down(1806, [press]);
    _up(1806, milliseconds: 5);
    await tester.pump(Duration(milliseconds: 20));
    expect(feedback, [true, false, true]);
    expect(press.isPressed, isTrue);
    expect(press.isFeedbackActive, isTrue);
    _up(1807, milliseconds: 25);
    await tester.pump(Duration(milliseconds: 20));
    expect(feedback, [true, false, true, false]);
  });

  testWidgets('祖先参考点搬动永久取消，移回原点也不恢复点击', (tester) async {
    var origin = Offset.zero;
    final trace = <String>[];
    final press = PressRecognizer()
      ..tapSlopTolerance = double.infinity
      ..ancestorOriginResolver = (() => origin)
      ..callbacks[ElEventPhase.tapDown] = ((_) => trace.add('down'))
      ..callbacks[ElEventPhase.tapCancel] = ((_) => trace.add('cancel'))
      ..callbacks[ElEventPhase.tapUp] = ((_) => trace.add('up'))
      ..callbacks[ElEventPhase.tap] = ((_) => trace.add('tap'));
    addTearDown(press.dispose);
    _down(1808, [press]);
    origin = Offset(100, 0);
    _move(1808, Offset.zero);
    origin = Offset.zero;
    _move(1808, Offset.zero);
    _up(1808);
    expect(trace, ['down', 'cancel', 'up']);
    _down(1809, [press]);
    _up(1809);
    expect(trace, ['down', 'cancel', 'up', 'down', 'up', 'tap']);
  });

  testWidgets('待定点击因祖先搬移放弃时结清 Up，也不挡住官方点击', (tester) async {
    var origin = Offset.zero;
    final trace = <String>[];
    final press = PressRecognizer()
      ..ancestorOriginResolver = (() => origin)
      ..callbacks[ElEventPhase.tapDown] = ((_) => trace.add('down'))
      ..callbacks[ElEventPhase.tapCancel] = ((_) => trace.add('cancel'))
      ..callbacks[ElEventPhase.tapUp] = ((_) => trace.add('up'))
      ..callbacks[ElEventPhase.tap] = ((_) => trace.add('tap'));
    final official = TapGestureRecognizer()..onTap = () => trace.add('official');
    addTearDown(press.dispose);
    addTearDown(official.dispose);
    _down(1820, [press, official]);
    origin = Offset(100, 0);
    _move(1820, Offset.zero);
    _up(1820);
    expect(trace, ['down', 'cancel', 'up', 'official']);
  });

  testWidgets('没有 Move 时长按截止仍检查祖先搬动并取消反馈', (tester) async {
    var origin = Offset.zero;
    final trace = <String>[];
    final press = PressRecognizer()
      ..ancestorOriginResolver = (() => origin)
      ..longPressDelay = Duration(milliseconds: 20)
      ..onFeedbackChanged = ((value) => trace.add('feedback:$value'))
      ..callbacks[ElEventPhase.tapCancel] = ((_) => trace.add('cancel'))
      ..callbacks[ElEventPhase.longPress] = ((_) => trace.add('long'));
    addTearDown(press.dispose);
    _down(1810, [press]);
    origin = Offset(100, 0);
    await tester.pump(Duration(milliseconds: 20));
    _up(1810);
    expect(trace, ['feedback:true', 'feedback:false', 'cancel']);
  });

  testWidgets('祖先长按先到期仍从最深有效成员沿链通知，整组只发生一次', (tester) async {
    final trace = <String>[];
    final parent = recordingPress(trace, 'parent')..longPressDelay = Duration(milliseconds: 20);
    final child = recordingPress(trace, 'child', parent: parent)..longPressDelay = Duration(milliseconds: 100);
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(1811, [child, parent]);
    await tester.pump(Duration(milliseconds: 20));
    expect(trace, [
      'child.down',
      'parent.down',
      'child.longPress',
      'parent.longPress',
      'child.cancel',
      'parent.cancel',
    ]);
    await tester.pump(Duration(milliseconds: 100));
    expect(trace.where((event) => event.endsWith('longPress')), hasLength(2));
    _up(1811, milliseconds: 120);
    expect(trace.where((event) => event.endsWith('.tap')), isEmpty);
  });

  testWidgets('祖先可否决长按默认点击取消，同阶段共享而后续点击重新置空', (tester) async {
    final trace = <String>[];
    var defaults = 0;
    final parent = recordingPress(trace, 'parent')
      ..longPressDelay = Duration(milliseconds: 100)
      ..onLongPressDefault = ((_) => defaults++)
      ..callbacks[ElEventPhase.longPress] = (event) {
        trace.add('parent.long');
        event.preventDefault();
      };
    final child = recordingPress(trace, 'child', parent: parent)
      ..longPressDelay = Duration(milliseconds: 20)
      ..onLongPressDefault = ((_) => defaults++)
      ..callbacks[ElEventPhase.longPress] = ((event) => trace.add('child.long:${event.defaultPrevented}'))
      ..callbacks[ElEventPhase.tap] = ((event) => trace.add('child.tap:${event.defaultPrevented}'));
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(1812, [child, parent]);
    await tester.pump(Duration(milliseconds: 20));
    expect(trace, ['child.down', 'parent.down', 'child.long:false', 'parent.long']);
    expect(defaults, 0);
    _up(1812, milliseconds: 25);
    expect(trace, [
      'child.down',
      'parent.down',
      'child.long:false',
      'parent.long',
      'child.up',
      'parent.up',
      'child.tap:false',
      'parent.tap',
    ]);
  });

  testWidgets('长按默认动作在整链完成后仅由最先到期成员执行一次', (tester) async {
    final trace = <String>[];
    PressGestureDetails? parentDetails;
    PressGestureDetails? defaultDetails;
    bool? defaultWasActive;
    final parent = PressRecognizer()
      ..longPressDelay = Duration(milliseconds: 20)
      ..callbacks[ElEventPhase.longPress] = (event) {
        trace.add('parent.long');
        parentDetails = event;
      }
      ..onLongPressDefault = (event) {
        trace.add('parent.default');
        defaultDetails = event;
        defaultWasActive = event.isActive;
      };
    final child = PressRecognizer()
      ..parent = parent
      ..longPressDelay = Duration(milliseconds: 100)
      ..callbacks[ElEventPhase.longPress] = ((_) => trace.add('child.long'))
      ..onLongPressDefault = ((_) => trace.add('child.default'));
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(1824, [child, parent]);
    await tester.pump(Duration(milliseconds: 20));
    expect(trace, ['child.long', 'parent.long', 'parent.default']);
    expect(defaultDetails!.dispatchIdentity, same(parentDetails!.dispatchIdentity));
    expect(defaultDetails!.sequenceIdentity, same(parentDetails!.sequenceIdentity));
    expect(defaultWasActive, isTrue);
    await tester.pump(Duration(milliseconds: 100));
    expect(trace, ['child.long', 'parent.long', 'parent.default']);
    _up(1824, milliseconds: 120);
  });

  testWidgets('长按链中其他成员取消最先到期候选后不再执行旧默认动作', (tester) async {
    var defaults = 0;
    final parent = PressRecognizer()..longPressDelay = Duration(milliseconds: 100);
    final child = PressRecognizer()
      ..parent = parent
      ..longPressDelay = Duration(milliseconds: 20)
      ..callbacks[ElEventPhase.longPress] = ((_) {})
      ..onLongPressDefault = ((_) => defaults++);
    parent.callbacks[ElEventPhase.longPress] = (event) => child.cancelMember(event.pointer);
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    _down(1825, [child, parent]);
    await tester.pump(Duration(milliseconds: 120));
    expect(defaults, 0);
    expect(child.hasActiveInput, isFalse);
    _up(1825, milliseconds: 120);
  });

  testWidgets('只声明通用长按默认动作也能独立识别且不重复执行', (tester) async {
    var defaults = 0;
    final press = PressRecognizer()
      ..longPressDelay = Duration(milliseconds: 20)
      ..onLongPressDefault = ((_) => defaults++);
    addTearDown(press.dispose);
    _down(1826, [press]);
    await tester.pump(Duration(milliseconds: 120));
    expect(defaults, 1);
    _up(1826, milliseconds: 120);
    expect(defaults, 1);
  });

  testWidgets('侧键最近订阅策略不让祖先收到任一阶段，四种按钮均可独立点击', (tester) async {
    final trace = <String>[];
    final parent = PressRecognizer()
      ..callbacks[ElEventPhase.secondaryTapDown] = ((_) => trace.add('parent.down'))
      ..callbacks[ElEventPhase.secondaryTapUp] = ((_) => trace.add('parent.up'))
      ..callbacks[ElEventPhase.secondaryTap] = ((_) => trace.add('parent.secondary'))
      ..callbacks[ElEventPhase.tertiaryTapDown] = ((_) => trace.add('parent.down'))
      ..callbacks[ElEventPhase.tertiaryTapUp] = ((_) => trace.add('parent.up'))
      ..callbacks[ElEventPhase.tertiaryTap] = ((_) => trace.add('parent.tertiary'))
      ..callbacks[ElEventPhase.forwardTapDown] = ((_) => trace.add('parent.down'))
      ..callbacks[ElEventPhase.forwardTapUp] = ((_) => trace.add('parent.up'))
      ..callbacks[ElEventPhase.forwardTap] = ((_) => trace.add('parent.forward'))
      ..callbacks[ElEventPhase.backTapDown] = ((_) => trace.add('parent.down'))
      ..callbacks[ElEventPhase.backTapUp] = ((_) => trace.add('parent.up'))
      ..callbacks[ElEventPhase.backTap] = ((_) => trace.add('parent.back'));
    final child = PressRecognizer()
      ..parent = parent
      ..bubbleSideButtons = false
      ..callbacks[ElEventPhase.secondaryTap] = ((_) => trace.add('child.secondary'))
      ..callbacks[ElEventPhase.tertiaryTap] = ((_) => trace.add('child.tertiary'))
      ..callbacks[ElEventPhase.forwardTap] = ((_) => trace.add('child.forward'))
      ..callbacks[ElEventPhase.backTap] = ((_) => trace.add('child.back'));
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    var pointer = 1813;
    for (final button in [kSecondaryButton, kTertiaryButton, kForwardMouseButton, kBackMouseButton]) {
      _down(pointer, [child, parent], buttons: button, kind: PointerDeviceKind.mouse);
      _up(pointer++, kind: PointerDeviceKind.mouse);
    }
    expect(trace, ['child.secondary', 'child.tertiary', 'child.forward', 'child.back']);
  });

  testWidgets('主键放宽移动不改变侧键的独立移动容差', (tester) async {
    final taps = <String>[];
    final press = PressRecognizer()
      ..tapSlopTolerance = double.infinity
      ..secondaryTapSlopTolerance = 3
      ..callbacks[ElEventPhase.tap] = (_) {
        taps.add('primary');
      }
      ..callbacks[ElEventPhase.secondaryTap] = (_) => taps.add('secondary');
    addTearDown(press.dispose);
    _down(1530, [press]);
    _move(1530, const Offset(20, 0));
    _up(1530, position: const Offset(20, 0));
    _down(1531, [press], buttons: kSecondaryButton);
    _up(1531, position: const Offset(20, 0));
    expect(taps, ['primary']);
  });
  testWidgets('取消旧延期点击的反馈回调中新建同编号输入，不取消新点击', (tester) async {
    final taps = <int>[];
    var replaceInput = false;
    final press = PressRecognizer()
      ..deferTap = true
      ..minimumFeedbackDuration = Duration(milliseconds: 100)
      ..callbacks[ElEventPhase.doubleTap] = (_) {}
      ..callbacks[ElEventPhase.tap] = (details) => taps.add(details.downEvent.timeStamp.inMilliseconds);
    addTearDown(press.dispose);
    press.onFeedbackChanged = (value) {
      if (!value && replaceInput) {
        replaceInput = false;
        _down(1840, [press], milliseconds: 10);
        _up(1840, milliseconds: 20);
      }
    };
    _down(1840, [press]);
    _up(1840, milliseconds: 1);

    replaceInput = true;
    press.cancelMember(1840);
    await tester.pump(Duration(milliseconds: 301));

    expect(taps, [10]);
  });

  testWidgets('取消全部旧延期点击不清除反馈回调中新输入的连击历史', (tester) async {
    final taps = <int>[];
    final doubles = <int>[];
    var replaceInput = false;
    final press = PressRecognizer()
      ..deferTap = true
      ..minimumFeedbackDuration = Duration(milliseconds: 100)
      ..callbacks[ElEventPhase.doubleTap] = ((details) => doubles.add(details.tapCount))
      ..callbacks[ElEventPhase.tap] = (details) => taps.add(details.downEvent.timeStamp.inMilliseconds);
    addTearDown(press.dispose);
    press.onFeedbackChanged = (value) {
      if (!value && replaceInput) {
        replaceInput = false;
        _down(1841, [press], milliseconds: 10);
        _up(1841, milliseconds: 20);
      }
    };
    _down(1841, [press]);
    _up(1841, milliseconds: 1);

    replaceInput = true;
    press.cancelMember();
    _down(1842, [press], milliseconds: 50);
    _up(1842, milliseconds: 60);
    await tester.pump(Duration(milliseconds: 301));

    expect(doubles, [2]);
    expect(taps, isEmpty);
  });

  testWidgets('释放资格回调取消自身后不重新建立连击窗口', (tester) async {
    var taps = 0, doubleDowns = 0, doubles = 0;
    var cancelOnRelease = true;
    final press = PressRecognizer()
      ..deferTap = true
      ..callbacks[ElEventPhase.tap] = ((_) => taps++)
      ..callbacks[ElEventPhase.doubleTapDown] = ((_) => doubleDowns++)
      ..callbacks[ElEventPhase.doubleTap] = (_) => doubles++;
    addTearDown(press.dispose);
    press.isEligible = (phase, event) {
      if (phase == ElEventPhase.tap && event is PointerUpEvent && cancelOnRelease) {
        cancelOnRelease = false;
        press.cancelMember(event.pointer);
      }
      return true;
    };
    _down(1843, [press]);
    await tester.pump();
    _up(1843, milliseconds: 10);
    _down(1844, [press], milliseconds: 50);
    await tester.pump();
    _up(1844, milliseconds: 60);
    await tester.pump(Duration(milliseconds: 301));

    expect(doubleDowns, 0);
    expect(doubles, 0);
    expect(taps, 1);
  });

  testWidgets('释放资格回调拒绝点击后保留释放通知且不再提交点击', (tester) async {
    var taps = 0, ups = 0;
    final press = PressRecognizer()
      ..callbacks[ElEventPhase.tap] = ((_) => taps++)
      ..callbacks[ElEventPhase.tapUp] = (_) => ups++;
    addTearDown(press.dispose);
    press.isEligible = (phase, event) {
      if (phase == ElEventPhase.tap && event is PointerUpEvent) press.rejectTap(event.pointer);
      return true;
    };
    _down(1846, [press]);
    await tester.pump();
    _up(1846);

    expect(ups, 1);
    expect(taps, 0);
  });

  testWidgets('释放资格回调取消子成员后祖先点击不继承已取消的延期策略', (tester) async {
    final taps = <String>[];
    final parent = PressRecognizer()..callbacks[ElEventPhase.tap] = (_) => taps.add('parent');
    final child = PressRecognizer()
      ..parent = parent
      ..deferTap = true
      ..callbacks[ElEventPhase.tap] = ((_) => taps.add('child'))
      ..callbacks[ElEventPhase.doubleTap] = (_) {};
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    child.isEligible = (phase, event) {
      if (phase == ElEventPhase.tap && event is PointerUpEvent) child.cancelMember(event.pointer);
      return true;
    };
    _down(1845, [child, parent]);
    await tester.pump();
    _up(1845, milliseconds: 10);

    expect(taps, ['parent']);
    await tester.pump(Duration(milliseconds: 301));
    expect(taps, ['parent']);
  });
}

void _down(
  int pointer,
  List<GestureRecognizer> recognizers, {
  Offset position = Offset.zero,
  int milliseconds = 0,
  int buttons = kPrimaryButton,
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) {
  _pointerPositions[pointer] = position;
  final event = PointerDownEvent(
    pointer: pointer,
    position: position,
    buttons: buttons,
    kind: kind,
    timeStamp: Duration(milliseconds: milliseconds),
  );
  for (final recognizer in recognizers) {
    recognizer.addPointer(event);
  }
  GestureBinding.instance.pointerRouter.route(event);
  GestureBinding.instance.gestureArena.close(pointer);
}

void _move(int pointer, Offset position) {
  final previous = _pointerPositions[pointer] ?? position;
  _pointerPositions[pointer] = position;
  GestureBinding.instance.pointerRouter.route(
    PointerMoveEvent(
      pointer: pointer,
      position: position,
      delta: position - previous,
      buttons: kPrimaryButton,
      timeStamp: const Duration(milliseconds: 20),
    ),
  );
}

void _up(
  int pointer, {
  Offset position = Offset.zero,
  int milliseconds = 30,
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) {
  _pointerPositions.remove(pointer);
  GestureBinding.instance.pointerRouter.route(
    PointerUpEvent(
      pointer: pointer,
      position: position,
      kind: kind,
      timeStamp: Duration(milliseconds: milliseconds),
    ),
  );
  GestureBinding.instance.gestureArena.sweep(pointer);
}

final _pointerPositions = <int, Offset>{};
