import 'package:flutter/gestures.dart';
import 'package:flutter_base/src/ui/event/callback.dart';
import 'package:flutter_base/src/ui/event/config.dart';
import 'package:flutter_base/src/ui/event/recognizers/recognizers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('单击只有官方竞技场获胜后才通知 up 和 tap', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer()
      ..onTapDown = (_) {
        calls.add('down');
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
    _down(1, [press, official]);
    expect(calls, ['down']);
    _up(1);
    expect(calls, ['down', 'up', 'tap']);
    press.dispose();
    official.dispose();
  });

  testWidgets('官方子 Tap 获胜后不能恢复 El 父候选', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer(hitTest: (_) => true)
      ..onTapDown = (_) {
        calls.add('down');
      }
      ..onTapUp = (_) {
        calls.add('up');
      }
      ..onTap = (_) {
        calls.add('tap');
      }
      ..onTapCancel = (_) {
        calls.add('cancel');
      };
    final official = TapGestureRecognizer()
      ..onTap = () {
        calls.add('official');
      };
    _down(2, [official, press]);
    _up(2);
    expect(calls, ['down', 'official', 'cancel']);
    _move(2, const Offset(1, 1));
    expect(calls, ['down', 'official', 'cancel']);
    press.dispose();
    official.dispose();
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
    final press =
        ElPressGestureRecognizer(config: const ElEventConfig(deferTap: true))
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
    final press =
        ElPressGestureRecognizer(config: const ElEventConfig(deferTap: true))
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
        event.preventDefault();
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
    final press = ElPressGestureRecognizer(hitTest: (_) => true)
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

  testWidgets('显式边界允许回入，未提供边界时按设备容差取消', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer(hitTest: (p) => p.dx.abs() < 20)
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
    _move(40, Offset.zero);
    _up(40);
    expect(calls, ['down', 'cancel', 'down', 'tap']);
    calls.clear();
    press.hitTest = null;
    _down(41, [press]);
    _move(41, const Offset(100, 0));
    _move(41, Offset.zero);
    _up(41);
    expect(calls, ['down', 'cancel']);
    press.dispose();
  });

  testWidgets('活动配置冻结，下一次按下才采用修改后的配置', (tester) async {
    final taps = <int>[];
    final press =
        ElPressGestureRecognizer(
            config: const ElEventConfig(
              tapCancelOnMove: true,
              tapCancelDistance: 30,
            ),
          )
          ..onTap = (_) {
            taps.add(1);
          };
    _down(42, [press]);
    press.config = const ElEventConfig(
      tapCancelOnMove: true,
      tapCancelDistance: 5,
    );
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
    void record(ElEventCallback event) => phases.add(event.phase);
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

  testWidgets('eager 只请求官方接受，取消自身 Tap 仍兑现获胜后的 up', (tester) async {
    final calls = <String>[];
    final press = ElPressGestureRecognizer()
      ..onTapDown = (event) {
        calls.add('down');
        event.eagerGesture(cancelSelfTap: true, allowScaleUpgrade: true);
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
    await tester.pump(const Duration(seconds: 1));
    _up(70);
    expect(calls, ['down', 'cancel', 'up']);
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
    void record(String name, ElEventCallback event) {
      canceled.add((
        name,
        event.globalPosition,
        event.localPosition,
        (event.originalEvent! as PointerEvent).pointer,
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
    final press =
        ElPressGestureRecognizer(config: const ElEventConfig(deferTap: true))
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
    final press =
        ElPressGestureRecognizer(config: const ElEventConfig(deferTap: true))
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
    final child = ElPressGestureRecognizer(
      parent: parent,
      config: const ElEventConfig(deferTap: true),
    )..onDoubleTap = (_) {};

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
