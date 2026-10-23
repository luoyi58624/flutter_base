import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/event/recognizers/recognizers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recognizer_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('识别器只导入 Dart 和 Flutter，不依赖宿主配置或事件模块', () {
    final files = Directory('lib/src/ui/event/recognizers')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final imports = RegExp("import\\s+['\"]([^'\"]+)['\"]");
    for (final file in files) {
      for (final directive in imports.allMatches(file.readAsStringSync())) {
        expect(
          directive.group(1),
          anyOf(startsWith('dart:'), startsWith('package:flutter/')),
          reason: file.path,
        );
      }
    }
  });

  testWidgets('所有按压阶段都提供冒泡控制，截断后的祖先候选仍被结清', (tester) async {
    const phases = [
      ElGesturePhase.tapDown,
      ElGesturePhase.tapUp,
      ElGesturePhase.tap,
      ElGesturePhase.doubleTapDown,
      ElGesturePhase.doubleTap,
      ElGesturePhase.tripleTapDown,
      ElGesturePhase.tripleTap,
      ElGesturePhase.longPress,
      ElGesturePhase.tapCancel,
      ElGesturePhase.secondaryTapDown,
      ElGesturePhase.secondaryTapUp,
      ElGesturePhase.secondaryTap,
      ElGesturePhase.tertiaryTapDown,
      ElGesturePhase.tertiaryTapUp,
      ElGesturePhase.tertiaryTap,
      ElGesturePhase.forwardTapDown,
      ElGesturePhase.forwardTapUp,
      ElGesturePhase.forwardTap,
      ElGesturePhase.backTapDown,
      ElGesturePhase.backTapUp,
      ElGesturePhase.backTap,
    ];
    var nextPointer = 430;
    for (final phase in phases) {
      final trace = <(bool, ElGesturePhase)>[];
      final parent = ElPressGestureRecognizer();
      final child = ElPressGestureRecognizer(
        parent: parent,
        longPressDelay: const Duration(milliseconds: 20),
      );
      void wire(ElPressGestureRecognizer recognizer, bool isChild) {
        void record(ElPressGestureDetails details) {
          trace.add((isChild, details.phase));
          if (isChild && details.phase == phase) details.stopPropagation();
        }

        recognizer
          ..onTapDown = record
          ..onTapUp = record
          ..onTap = record
          ..onDoubleTapDown = record
          ..onDoubleTap = record
          ..onTripleTapDown = record
          ..onTripleTap = record
          ..onLongPress = record
          ..onTapCancel = record
          ..onSecondaryTapDown = record
          ..onSecondaryTapUp = record
          ..onSecondaryTap = record
          ..onTertiaryTapDown = record
          ..onTertiaryTapUp = record
          ..onTertiaryTap = record
          ..onForwardTapDown = record
          ..onForwardTapUp = record
          ..onForwardTap = record
          ..onBackTapDown = record
          ..onBackTapUp = record
          ..onBackTap = record;
      }

      wire(parent, false);
      wire(child, true);
      final clicks = switch (phase) {
        ElGesturePhase.doubleTapDown || ElGesturePhase.doubleTap => 2,
        ElGesturePhase.tripleTapDown || ElGesturePhase.tripleTap => 3,
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
        if (phase == ElGesturePhase.longPress) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        if (phase == ElGesturePhase.tapCancel) {
          GestureBinding.instance.pointerRouter.route(
            PointerCancelEvent(pointer: pointer),
          );
        }
        _up(pointer, milliseconds: i * 40 + 30);
      }
      expect(trace, contains((true, phase)), reason: phase.name);
      final cleanup =
          phase == ElGesturePhase.tapCancel || phase.name.endsWith('Up');
      expect(trace.contains((false, phase)), cleanup, reason: phase.name);
      if (trace.contains((false, ElGesturePhase.tapDown))) {
        expect(
          trace.any(
            (item) =>
                !item.$1 &&
                (item.$2 == ElGesturePhase.tapUp ||
                    item.$2 == ElGesturePhase.tapCancel),
          ),
          isTrue,
          reason: '${phase.name} 不能遗留祖先按压',
        );
      }
      child.dispose();
      parent.dispose();
    }
  });

  testWidgets('主动取消清除活动长按与待发单击，取消后识别器可复用', (tester) async {
    final trace = <ElGesturePhase>[];
    final press = ElPressGestureRecognizer(deferTap: true)
      ..onTap = (event) {
        trace.add(event.phase);
      }
      ..onDoubleTap = (event) {
        trace.add(event.phase);
      }
      ..onLongPress = (event) {
        trace.add(event.phase);
      }
      ..onTapCancel = (event) {
        trace.add(event.phase);
      };
    _down(410, [press]);
    press.cancel();
    press.cancel();
    _up(410);
    await tester.pump(const Duration(seconds: 1));
    expect(trace, [ElGesturePhase.tapCancel]);
    _down(411, [press]);
    _up(411);
    press.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(trace, [ElGesturePhase.tapCancel]);
    press.deferTap = false;
    _down(412, [press]);
    _up(412);
    expect(trace, [ElGesturePhase.tapCancel, ElGesturePhase.tap]);
    press.dispose();
  });

  for (final disposeOnUp in [false, true]) {
    testWidgets('Up 中截断或销毁不能遗留祖先候选：dispose=$disposeOnUp', (tester) async {
      final trace = <String>[];
      final parent = recordingPress(trace, 'parent');
      late ElPressGestureRecognizer child;
      child = recordingPress(trace, 'child', parent: parent)
        ..onTapUp = (event) {
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
      expect(trace, [
        'child.down',
        'parent.down',
        'child.up',
        'parent.up',
        if (!disposeOnUp) 'child.tap',
      ]);
    });
  }

  testWidgets('连击窗口按双击分组，过期后重新开始且无双击时 deferTap 不延迟', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer(deferTap: true)
      ..onTap = (event) => calls.add('tap${event.tapCount}');
    addTearDown(press.dispose);
    _down(201, [press]);
    _up(201);
    expect(calls, ['tap1']);
    press.onDoubleTapDown = (_) => calls.add('doubleDown');
    press.onDoubleTap = (_) => calls.add('double');
    press.deferTap = false;
    for (var index = 0; index < 4; index++) {
      _down(202 + index, [press], milliseconds: 50 + index * 40);
      _up(202 + index, milliseconds: 60 + index * 40);
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(calls, [
      'tap1',
      'tap1',
      'doubleDown',
      'tap2',
      'double',
      'tap1',
      'doubleDown',
      'tap2',
      'double',
    ]);
    await tester.pump(const Duration(milliseconds: 350));
    _down(206, [press], milliseconds: 600);
    _up(206, milliseconds: 610);
    expect(calls.last, 'tap1');
    press.dispose();
  });

  testWidgets('相同识别参数保留连击窗口，修改间隔后重新分组', (tester) async {
    var doubles = 0;
    final press = ElPressGestureRecognizer()
      ..onDoubleTapDown = (_) => doubles++;
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
    final press =
        ElPressGestureRecognizer(
            tapSlopTolerance: double.infinity,
            longPressDelay: Duration(milliseconds: 50),
            longPressSlopTolerance: 10,
          )
          ..onTap = (_) {
            calls.add('tap');
          }
          ..onTapCancel = (_) {
            calls.add('cancel');
          }
          ..onLongPress = (_) {
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
      event: const PointerMoveEvent(
        pointer: 221,
        position: Offset(60, 0),
        timeStamp: Duration(milliseconds: 130),
      ),
    );
    _up(221, position: const Offset(60, 0), milliseconds: 130);
    expect(calls, ['tap', 'cancel']);
  });

  testWidgets('侧键不触发长按，按钮组合变化只取消一次且不污染下一次主键', (tester) async {
    final calls = <String>[];
    final press =
        ElPressGestureRecognizer(longPressDelay: Duration(milliseconds: 20))
          ..onSecondaryTapDown = (_) {
            calls.add('side.down');
          }
          ..onSecondaryTap = (_) {
            calls.add('side.tap');
          }
          ..onTapCancel = (_) {
            calls.add('cancel');
          }
          ..onLongPress = (_) {
            calls.add('long');
          }
          ..onTap = (_) {
            calls.add('tap');
          };
    addTearDown(press.dispose);
    _down(
      230,
      [press],
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 30));
    GestureBinding.instance.pointerRouter.route(
      const PointerMoveEvent(
        pointer: 230,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton | kPrimaryButton,
      ),
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
      ..onTapCancel = (event) {
        trace.add('child.cancel');
        event.stopPropagation();
      };
    addTearDown(child.dispose);
    addTearDown(parent.dispose);
    _down(240, [child, parent]);
    GestureBinding.instance.pointerRouter.route(
      const PointerCancelEvent(pointer: 240),
    );
    _up(240);
    expect(trace, [
      'child.down',
      'parent.down',
      'child.cancel',
      'parent.cancel',
    ]);
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
    expect(trace.where((e) => e.endsWith('.tap')), [
      'child.tap',
      'first.tap',
      'child.tap',
      'second.tap',
    ]);
  });

  testWidgets('单击双击三击和候选 Down 按三次分组', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer()
      ..onTap = (event) {
        calls.add('tap${event.tapCount}');
      }
      ..onDoubleTapDown = (_) {
        calls.add('doubleDown');
      }
      ..onDoubleTap = (event) {
        calls.add('double${event.tapCount}');
      }
      ..onTripleTapDown = (_) {
        calls.add('tripleDown');
      }
      ..onTripleTap = (event) {
        calls.add('triple${event.tapCount}');
      };
    for (var pointer = 10; pointer < 14; pointer++) {
      _down(pointer, [press], milliseconds: (pointer - 10) * 50);
      _up(pointer, milliseconds: (pointer - 10) * 50 + 10);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(calls, [
      'tap1',
      'doubleDown',
      'tap2',
      'double2',
      'tripleDown',
      'tap3',
      'triple3',
      'tap1',
    ]);
    press.dispose();
  });

  testWidgets('deferTap 只延迟业务通知，不持有竞技场', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer(deferTap: true)
      ..onTapUp = (_) {
        calls.add('up');
      }
      ..onTap = (_) {
        calls.add('tap');
      }
      ..onDoubleTap = (_) {
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
    final press = ElPressGestureRecognizer(deferTap: true)
      ..onTap = (event) {
        taps.add(event.globalPosition);
      }
      ..onDoubleTap = (_) {};
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
    final press = ElPressGestureRecognizer()
      ..onTapDown = (_) {
        calls.add('down');
      }
      ..onTapCancel = (_) {
        calls.add('cancel');
      }
      ..onLongPress = (event) {
        calls.add('long');
      }
      ..onTapUp = (_) {
        calls.add('up');
      }
      ..onTap = (_) {
        calls.add('tap');
      };
    final official = TapGestureRecognizer()
      ..onTap = () {
        calls.add('official');
      };
    _down(30, [press, official]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, ['down', 'cancel', 'long']);
    _up(30, milliseconds: 600);
    expect(calls, ['down', 'cancel', 'long', 'up']);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['down', 'cancel', 'long', 'up']);
    press.dispose();
    official.dispose();
  });

  testWidgets('长按输给官方拖拽后 timer 不再通知且下一次可点击', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer(tapSlopTolerance: double.infinity)
      ..onTapCancel = (_) {
        calls.add('cancel');
      }
      ..onLongPress = (_) {
        calls.add('long');
      }
      ..onTap = (_) {
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
    final press = ElPressGestureRecognizer(tapSlopTolerance: double.infinity)
      ..onTapDown = (_) {
        calls.add('down');
      }
      ..onTapCancel = (_) {
        calls.add('cancel');
      }
      ..onTap = (_) {
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
    final press = ElPressGestureRecognizer(tapSlopTolerance: 30)
      ..onTap = (_) {
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
    final phases = <ElGesturePhase>[];
    void record(ElPressGestureDetails event) => phases.add(event.phase);
    final press = ElPressGestureRecognizer()
      ..onSecondaryTapDown = record
      ..onSecondaryTapUp = record
      ..onSecondaryTap = record
      ..onTertiaryTapDown = record
      ..onTertiaryTapUp = record
      ..onTertiaryTap = record
      ..onForwardTapDown = record
      ..onForwardTapUp = record
      ..onForwardTap = record
      ..onBackTapDown = record
      ..onBackTapUp = record
      ..onBackTap = record;
    const buttons = [
      kSecondaryButton,
      kTertiaryButton,
      kForwardMouseButton,
      kBackMouseButton,
    ];
    for (var index = 0; index < buttons.length; index++) {
      _down(
        50 + index,
        [press],
        buttons: buttons[index],
        kind: PointerDeviceKind.mouse,
      );
      _up(50 + index, kind: PointerDeviceKind.mouse);
    }
    expect(phases, [
      ElGesturePhase.secondaryTapDown,
      ElGesturePhase.secondaryTapUp,
      ElGesturePhase.secondaryTap,
      ElGesturePhase.tertiaryTapDown,
      ElGesturePhase.tertiaryTapUp,
      ElGesturePhase.tertiaryTap,
      ElGesturePhase.forwardTapDown,
      ElGesturePhase.forwardTapUp,
      ElGesturePhase.forwardTap,
      ElGesturePhase.backTapDown,
      ElGesturePhase.backTapUp,
      ElGesturePhase.backTap,
    ]);
    press.dispose();
  });

  testWidgets('空处理器、按钮过滤和设备过滤不抢官方 Tap', (tester) async {
    var taps = 0;
    final press = ElPressGestureRecognizer();
    final official = TapGestureRecognizer()
      ..onTap = () {
        taps++;
      };
    _down(60, [press, official]);
    _up(60);
    expect(taps, 1);
    press.onTap = (_) => fail('设备过滤后的识别器不能触发');
    press.supportedDevices = {PointerDeviceKind.mouse};
    _down(61, [press, official]);
    _up(61);
    expect(taps, 2);
    final filtered =
        ElPressGestureRecognizer(allowedButtonsFilter: (_) => false)
          ..onTap = (_) {
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
    late ElPressGestureRecognizer press;
    press = ElPressGestureRecognizer()
      ..onTapDown = (event) {
        calls.add('down');
        press.acceptPointer(event.pointer);
      }
      ..onTapCancel = (_) {
        calls.add('cancel');
      }
      ..onTapUp = (_) {
        calls.add('up');
      }
      ..onTap = (_) {
        calls.add('tap');
      }
      ..onLongPress = (_) {
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
    final press = ElPressGestureRecognizer()
      ..onTap = (_) {
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
      ..onTapCancel = (_) {
        cancels++;
        press.dispose();
      }
      ..onLongPress = (_) {
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
    final press = ElPressGestureRecognizer()
      ..onTap = (_) {
        taps++;
      }
      ..onTapCancel = (_) {
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
    void record(String name, ElPressGestureDetails event) {
      canceled.add((
        name,
        event.globalPosition,
        event.localPosition,
        event.pointer,
      ));
    }

    final parent = ElPressGestureRecognizer()
      ..onTapCancel = (event) {
        record('parent', event);
      };
    final child = ElPressGestureRecognizer(parent: parent)
      ..onTapCancel = (event) {
        record('child', event);
      };
    const first = PointerDownEvent(
      pointer: 130,
      position: Offset(100, 100),
      buttons: kPrimaryButton,
    );
    child.addPointer(first.transformed(Matrix4.translationValues(-10, -20, 0)));
    parent.addPointer(
      first.transformed(Matrix4.translationValues(-30, -40, 0)),
    );
    GestureBinding.instance.pointerRouter.route(first);
    GestureBinding.instance.gestureArena.close(130);
    GestureBinding.instance.pointerRouter.route(
      const PointerMoveEvent(
        pointer: 130,
        position: Offset(105, 107),
        delta: Offset(5, 7),
        buttons: kPrimaryButton,
      ),
    );

    const second = PointerDownEvent(
      pointer: 131,
      position: Offset(400, 500),
      buttons: kPrimaryButton,
    );
    child.addPointer(
      second.transformed(Matrix4.translationValues(-100, -200, 0)),
    );
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
    final press = ElPressGestureRecognizer(deferTap: true)
      ..onTap = (_) {
        calls.add('tap');
      }
      ..onDoubleTap = (_) {
        calls.add('double');
      }
      ..onLongPress = (_) {
        calls.add('long');
      }
      ..onTapCancel = (event) {
        calls.add(event.cancelReason!.name);
      };
    _down(100, [press]);
    GestureBinding.instance.pointerRouter.route(
      const PointerCancelEvent(pointer: 100),
    );
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
    final press = ElPressGestureRecognizer(deferTap: true)
      ..onTap = (_) {
        calls.add('tap');
      }
      ..onDoubleTap = (_) {
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
    final parent = ElPressGestureRecognizer()
      ..onTap = (event) {
        positions.add(event.localPosition);
      };
    final child = ElPressGestureRecognizer(parent: parent, deferTap: true)
      ..onDoubleTap = (_) {};

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
      parent.addPointer(
        event.transformed(
          Matrix4.translationValues(translation.dx, translation.dy, 0),
        ),
      );
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
    _up(
      110,
      position: const Offset(200, 200),
      milliseconds: 330,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(positions, [const Offset(90, 80), const Offset(130, 120)]);
    child.dispose();
    parent.dispose();
  });

  testWidgets('官方 DoubleTap 持有前一次竞技场时仍跟踪下一次候选', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer()
      ..onTapDown = (_) {
        calls.add('down');
      }
      ..onTap = (_) {
        calls.add('tap');
      }
      ..onTapCancel = (_) {
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
      ..onTapDown = (event) {
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
      ..onTapDown = (event) {
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
    final parent = ElPressGestureRecognizer()
      ..onTap = (event) => positions['parent'] = event.localPosition;
    final child = ElPressGestureRecognizer(parent: parent)
      ..onTap = (event) => positions['child'] = event.localPosition;
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
      ..onTapCancel = (event) {
        events.add('parent.cancel');
        cancelPositions['parent'] = event.localPosition;
      };
    final child = recordingPress(events, 'child', parent: parent)
      ..onTapCancel = (event) {
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

    expect(events.where((event) => event.endsWith('.cancel')), [
      'child.cancel',
      'parent.cancel',
    ]);
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
    expect(
      events,
      containsAllInOrder(['front.down', 'parent.down', 'back.down']),
    );
    expect(events.where((event) => event.startsWith('front.')), [
      'front.down',
      'front.up',
      'front.tap',
    ]);
    expect(events.where((event) => event.startsWith('back.')), [
      'back.down',
      'back.cancel',
    ]);
    expect(events.where((event) => event.startsWith('parent.')), [
      'parent.down',
      'parent.up',
      'parent.tap',
    ]);
    expect(events.where((event) => event.startsWith('official.')), [
      'official.down',
      'official.cancel',
    ]);
  });

  for (final stopCancel in [false, true]) {
    testWidgets('Down 内同步取消不向祖先补发孤立候选：stopCancel=$stopCancel', (tester) async {
      final trace = <String>[];
      final parent = ElPressGestureRecognizer()
        ..onTapDown = (_) {
          trace.add('parent.down');
        }
        ..onTapCancel = (_) {
          trace.add('parent.cancel');
        }
        ..onTapUp = (_) => trace.add('parent.up');
      late ElPressGestureRecognizer child;
      child = ElPressGestureRecognizer(parent: parent)
        ..onTapDown = (event) {
          trace.add('child.down');
          child.cancelPointer(event.pointer);
        }
        ..onTapCancel = (event) {
          trace.add('child.cancel');
          if (stopCancel) event.stopPropagation();
        }
        ..onTapUp = (_) => trace.add('child.up');
      addTearDown(parent.dispose);
      addTearDown(child.dispose);
      await tester.pumpWidget(
        gestureShell(gestureHost(parent, child: gestureHost(child))),
      );

      await tester.tapAt(const Offset(50, 50));
      expect(trace, ['child.down', 'child.cancel']);
    });
  }

  testWidgets('子回调异常不会截断父冒泡，下一次点击仍可识别', (tester) async {
    final trace = <String>[];
    final parent = ElPressGestureRecognizer()
      ..onTap = (_) => trace.add('parent');
    final child = ElPressGestureRecognizer(parent: parent)
      ..onTap = (_) {
        trace.add('child');
        throw StateError('回调失败');
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      gestureShell(gestureHost(parent, child: gestureHost(child))),
    );
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(const Offset(50, 50));
      expect(tester.takeException(), isA<StateError>());
    }
    expect(trace, ['child', 'parent', 'child', 'parent']);
  });

  testWidgets('子回调销毁委托父级后继续自身点击，父级不再收到事件', (tester) async {
    final trace = <String>[];
    final parent = ElPressGestureRecognizer()
      ..onTapDown = (_) {
        trace.add('parent.down');
      }
      ..onTap = (_) => trace.add('parent.tap');
    final child = ElPressGestureRecognizer(parent: parent)
      ..onTapDown = (_) {
        trace.add('child.down');
        parent.dispose();
      }
      ..onTap = (_) => trace.add('child.tap');
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      gestureShell(gestureHost(parent, child: gestureHost(child))),
    );

    await tester.tapAt(const Offset(50, 50));
    expect(trace, ['child.down', 'child.tap']);
  });
  testWidgets('成员资格在连击提交前生效，子成员无效点击不污染父级历史', (tester) async {
    final trace = <String>[];
    var eligible = true;
    final parent = ElPressGestureRecognizer()
      ..onTap = (event) {
        trace.add('parent:${event.tapCount}');
      }
      ..onDoubleTap = (_) {};
    final child =
        ElPressGestureRecognizer(parent: parent, isEligible: (_, _) => eligible)
          ..onTap = (event) {
            trace.add('child:${event.tapCount}');
          }
          ..onDoubleTap = (_) {};
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
    child.cancelMember(1510);
    _up(1510);
    expect(trace, [
      'child.down',
      'parent.down',
      'child.cancel',
      'parent.up',
      'parent.tap',
    ]);
  });

  testWidgets('父子长按采用各自等待时间，资格失败不提前认领官方手势', (tester) async {
    final trace = <String>[];
    var childEligible = false;
    final parent = ElPressGestureRecognizer(
      longPressDelay: const Duration(milliseconds: 40),
    )..onLongPress = (_) => trace.add('parent.long');
    final child = ElPressGestureRecognizer(
      parent: parent,
      longPressDelay: const Duration(milliseconds: 10),
      isEligible: (_, _) => childEligible,
    )..onLongPress = (_) => trace.add('child.long');
    final official = TapGestureRecognizer()
      ..onTap = () => trace.add('official.tap');
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

  testWidgets('主键放宽移动不改变侧键的独立移动容差', (tester) async {
    final taps = <String>[];
    final press =
        ElPressGestureRecognizer(
            tapSlopTolerance: double.infinity,
            secondaryTapSlopTolerance: 3,
          )
          ..onTap = (_) {
            taps.add('primary');
          }
          ..onSecondaryTap = (_) => taps.add('secondary');
    addTearDown(press.dispose);
    _down(1530, [press]);
    _move(1530, const Offset(20, 0));
    _up(1530, position: const Offset(20, 0));
    _down(1531, [press], buttons: kSecondaryButton);
    _up(1531, position: const Offset(20, 0));
    expect(taps, ['primary']);
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
