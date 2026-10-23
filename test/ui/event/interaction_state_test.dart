import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter_base/src/ui/event/index.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _shell(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(alignment: .topLeft, child: child),
);

Widget _probe(void Function(BuildContext) read) => Builder(
  builder: (context) {
    read(context);
    return const SizedBox(width: 100, height: 100);
  },
);

const _immediate = ElEventConfig(
  delayTouchDown: Duration.zero,
  delayTouchUp: Duration.zero,
);

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  testWidgets('宿主外查询返回空状态，交互扩展均返回 false', (tester) async {
    await tester.pumpWidget(
      _shell(
        _probe((context) {
          expect(ElEventView.maybeOf(context), isNull);
          expect(context.hasTap, isFalse);
          expect(context.hasHover, isFalse);
        }),
      ),
    );
  });

  testWidgets('无需回调也能由按压与悬停状态改变后代颜色', (tester) async {
    const idle = Color(0xff112233);
    const hovered = Color(0xff445566);
    const pressed = Color(0xff778899);
    const colorKey = ValueKey('feedback-color');
    TestGesture? mouse;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: const ElEvent(config: _immediate),
            child: Builder(
              builder: (context) => ColoredBox(
                key: colorKey,
                color: context.hasTap
                    ? pressed
                    : context.hasHover
                    ? hovered
                    : idle,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      Color color() => tester.widget<ColoredBox>(find.byKey(colorKey)).color;
      expect(color(), idle);
      mouse = await tester.createGesture(kind: .mouse);
      await mouse.addPointer(location: const Offset(150, 20));
      await mouse.moveTo(const Offset(20, 20));
      await tester.pump();
      expect(color(), hovered);
      await mouse.down(const Offset(20, 20));
      down = true;
      await tester.pump();
      expect(color(), pressed);
      await mouse.up();
      down = false;
      await tester.pump();
      expect(color(), hovered);
      await mouse.moveTo(const Offset(150, 20));
      await tester.pump();
      expect(color(), idle);
    } finally {
      if (down) await mouse?.cancel();
      await mouse?.removePointer();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('扩展按字段订阅，整体查询订阅全部，静态后代不重建', (tester) async {
    var tapBuilds = 0;
    var hoverBuilds = 0;
    var allBuilds = 0;
    var staticBuilds = 0;
    final child = SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          _probe((context) {
            tapBuilds++;
            context.hasTap;
          }),
          _probe((context) {
            hoverBuilds++;
            context.hasHover;
          }),
          _probe((context) {
            allBuilds++;
            ElEventView.maybeOf(context);
          }),
          _probe((_) => staticBuilds++),
        ],
      ),
    );
    TestGesture? mouse;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: const ElEvent(config: _immediate),
            child: child,
          ),
        ),
      );
      expect([tapBuilds, hoverBuilds, allBuilds, staticBuilds], [1, 1, 1, 1]);
      mouse = await tester.createGesture(kind: .mouse);
      await mouse.addPointer(location: const Offset(150, 20));
      await mouse.moveTo(const Offset(20, 20));
      await tester.pump();
      expect([tapBuilds, hoverBuilds, allBuilds, staticBuilds], [1, 2, 2, 1]);
      await mouse.down(const Offset(20, 20));
      down = true;
      await tester.pump();
      expect([tapBuilds, hoverBuilds, allBuilds, staticBuilds], [2, 2, 3, 1]);
      await mouse.up();
      down = false;
      await tester.pump();
      expect([tapBuilds, hoverBuilds, allBuilds, staticBuilds], [3, 2, 4, 1]);
    } finally {
      if (down) await mouse?.cancel();
      await mouse?.removePointer();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('嵌套查询始终读取最近宿主，外层交互不会污染内层', (tester) async {
    ElEventState? inner;
    ElEventState? outer;
    TestGesture? mouse;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: const ElEvent(config: _immediate),
            child: SizedBox(
              width: 200,
              height: 100,
              child: Row(
                children: [
                  ElEventView(
                    event: const ElEvent(config: _immediate),
                    child: _probe(
                      (context) => inner = ElEventView.maybeOf(context),
                    ),
                  ),
                  _probe((context) => outer = ElEventView.maybeOf(context)),
                ],
              ),
            ),
          ),
        ),
      );
      mouse = await tester.createGesture(kind: .mouse);
      await mouse.addPointer(location: const Offset(20, 20));
      await tester.pump();
      expect(inner!.hasHover, isTrue);
      expect(outer!.hasHover, isTrue);
      await mouse.moveTo(const Offset(150, 20));
      await tester.pump();
      expect(inner!.hasHover, isFalse);
      expect(outer!.hasHover, isTrue);
      await mouse.down(const Offset(150, 20));
      down = true;
      await tester.pump();
      expect(inner!.hasTap, isFalse);
      expect(outer!.hasTap, isTrue);
      await mouse.up();
      down = false;
    } finally {
      if (down) await mouse?.cancel();
      await mouse?.removePointer();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('触摸反馈延迟进入，抬手保留从物理按下起算且不延迟点击', (tester) async {
    ElEventState? state;
    var taps = 0;
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: ElEvent(
              config: const ElEventConfig(
                delayTouchDown: Duration(milliseconds: 30),
                delayTouchUp: Duration(milliseconds: 100),
              ),
              onTap: (_) => taps++,
            ),
            child: _probe((context) => state = ElEventView.maybeOf(context)),
          ),
        ),
      );
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 29));
      expect(state!.hasTap, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state!.hasTap, isTrue);
      await tester.pump(const Duration(milliseconds: 30));
      await touch.up();
      down = false;
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 39));
      expect(state!.hasTap, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state!.hasTap, isFalse);
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('短于进入延迟的触摸不补播按压反馈', (tester) async {
    final values = <bool>[];
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: const ElEvent(
              config: ElEventConfig(
                delayTouchDown: Duration(milliseconds: 60),
                delayTouchUp: Duration(milliseconds: 100),
              ),
            ),
            child: _probe((context) => values.add(context.hasTap)),
          ),
        ),
      );
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 20));
      await touch.up();
      down = false;
      await tester.pump(const Duration(milliseconds: 200));
      expect(values, isNot(contains(true)));
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('持续按住超过最短反馈时间后松手立即清除', (tester) async {
    ElEventState? state;
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: const ElEvent(
              config: ElEventConfig(
                delayTouchDown: Duration(milliseconds: 30),
                delayTouchUp: Duration(milliseconds: 100),
              ),
            ),
            child: _probe((context) => state = ElEventView.maybeOf(context)),
          ),
        ),
      );
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 120));
      expect(state!.hasTap, isTrue);
      await touch.up();
      down = false;
      await tester.pump();
      expect(state!.hasTap, isFalse);
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('移出再移回不会重置从物理按下起算的最短反馈时间', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: const ElEvent(),
          child: _probe((context) => pressed = context.hasTap),
        ),
      ),
    );
    final touch = await tester.startGesture(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 60));
    expect(pressed, isTrue);
    await touch.moveTo(const Offset(150, 20));
    await tester.pump(const Duration(milliseconds: 20));
    expect(pressed, isFalse);
    await touch.moveTo(const Offset(20, 20));
    await touch.up();
    await tester.pump();
    expect(pressed, isTrue);
    await tester.pump(const Duration(milliseconds: 20));
    expect(pressed, isFalse);
  });

  testWidgets('连续触摸不会被上一次抬手遗留的退出计时器清除', (tester) async {
    ElEventState? state;
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: const ElEvent(
              config: ElEventConfig(delayTouchUp: Duration(milliseconds: 100)),
            ),
            child: _probe((context) => state = ElEventView.maybeOf(context)),
          ),
        ),
      );
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 20));
      await touch.up();
      down = false;
      await tester.pump(const Duration(milliseconds: 30));
      expect(state!.hasTap, isTrue);

      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 60));
      expect(state!.hasTap, isTrue, reason: '第一次抬手的截止时间不能清除第二次按压');
      await touch.up();
      down = false;
      await tester.pump(const Duration(milliseconds: 39));
      expect(state!.hasTap, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state!.hasTap, isFalse);
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('鼠标和笔忽略触摸进入延迟与抬手保留', (tester) async {
    ElEventState? state;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: const ElEvent(
              config: ElEventConfig(
                delayTouchDown: Duration(milliseconds: 80),
                delayTouchUp: Duration(milliseconds: 200),
              ),
            ),
            child: _probe((context) => state = ElEventView.maybeOf(context)),
          ),
        ),
      );
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
        final gesture = await tester.startGesture(
          const Offset(20, 20),
          kind: kind,
        );
        try {
          await tester.pump();
          expect(state!.hasTap, isTrue, reason: kind.name);
          await gesture.up();
          await tester.pump();
          expect(state!.hasTap, isFalse, reason: kind.name);
        } finally {
          await gesture.removePointer();
        }
      }
    } finally {
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('按压移出边界清除反馈，移回恢复反馈', (tester) async {
    ElEventState? state;
    TestGesture? mouse;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: const ElEvent(config: _immediate),
            child: _probe((context) => state = ElEventView.maybeOf(context)),
          ),
        ),
      );
      mouse = await tester.startGesture(const Offset(20, 20), kind: .mouse);
      down = true;
      await tester.pump();
      expect(state!.hasTap, isTrue);
      await mouse.moveTo(const Offset(150, 20));
      await tester.pump();
      expect(state!.hasTap, isFalse);
      await mouse.moveTo(const Offset(20, 20));
      await tester.pump();
      expect(state!.hasTap, isTrue);
      await mouse.up();
      down = false;
      await tester.pump();
      expect(state!.hasTap, isFalse);
    } finally {
      if (down) await mouse?.cancel();
      await mouse?.removePointer();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('PointerCancel 同时清理已生效和仍等待进入的触摸反馈', (tester) async {
    ElEventState? state;
    try {
      for (final wait in [20, 60]) {
        await tester.pumpWidget(
          _shell(
            ElEventView(
              event: const ElEvent(
                config: ElEventConfig(
                  delayTouchDown: Duration(milliseconds: 40),
                  delayTouchUp: Duration(milliseconds: 200),
                ),
              ),
              child: _probe((context) => state = ElEventView.maybeOf(context)),
            ),
          ),
        );
        final touch = await tester.startGesture(const Offset(20, 20));
        await tester.pump(Duration(milliseconds: wait));
        expect(state!.hasTap, wait > 40);
        await touch.cancel();
        await tester.pump();
        expect(state!.hasTap, isFalse);
        await tester.pump(const Duration(milliseconds: 250));
        expect(state!.hasTap, isFalse);
      }
    } finally {
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('长按识别成功后通过取消阶段清理按压反馈', (tester) async {
    ElEventState? state;
    var longPresses = 0;
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: ElEvent(
              config: _immediate.copyWith(
                longPressDelay: const Duration(milliseconds: 50),
              ),
              onLongPress: (_) => longPresses++,
            ),
            child: _probe((context) => state = ElEventView.maybeOf(context)),
          ),
        ),
      );
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 49));
      expect(state!.hasTap, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(longPresses, 1);
      expect(state!.hasTap, isFalse);
      await touch.up();
      down = false;
      await tester.pump();
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('拖拽主动接管后立即清除按压反馈且不会补播', (tester) async {
    ElEventState? state;
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: ElEvent(
              config: const ElEventConfig(
                delayTouchUp: Duration(milliseconds: 200),
                dragStartDistance: 0,
                dragResampling: {},
              ),
              onDragStart: (event) => event.eagerGesture(cancelSelfTap: true),
              onDragEnd: (_) {},
            ),
            child: _probe((context) => state = ElEventView.maybeOf(context)),
          ),
        ),
      );
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump();
      expect(state!.hasTap, isTrue);
      await touch.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(state!.hasTap, isFalse);
      await touch.up();
      down = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(state!.hasTap, isFalse);
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('被动拖拽保留按压反馈，读取状态不改变盒内点击语义', (tester) async {
    ElEventState? state;
    var taps = 0;
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: ElEvent(
              config: _immediate.copyWith(
                dragStartDistance: 0,
                dragResampling: {},
              ),
              onTap: (_) => taps++,
              onDragStart: (_) {},
              onDragEnd: (_) {},
            ),
            child: _probe((context) => state = ElEventView.maybeOf(context)),
          ),
        ),
      );
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await touch.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(state!.hasTap, isTrue);
      await touch.up();
      down = false;
      await tester.pump();
      expect(taps, 1);
      expect(state!.hasTap, isFalse);
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('祖先独占后立即清除失权后代，不补播其等待中的触摸反馈', (tester) async {
    ElEventState? inner;
    ElEventState? outer;
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(
        _shell(
          ElEventView(
            event: ElEvent(
              config: _immediate,
              onPointerDown: (event) => event.eagerGesture(),
            ),
            child: Builder(
              builder: (context) {
                outer = ElEventView.maybeOf(context);
                return ElEventView(
                  event: const ElEvent(
                    config: ElEventConfig(
                      delayTouchDown: Duration(milliseconds: 30),
                      delayTouchUp: Duration(milliseconds: 200),
                    ),
                  ),
                  child: _probe(
                    (context) => inner = ElEventView.maybeOf(context),
                  ),
                );
              },
            ),
          ),
        ),
      );
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 40));
      expect(inner!.hasTap, isFalse);
      expect(outer!.hasTap, isTrue);
      await touch.up();
      down = false;
      await tester.pump();
      expect(inner!.hasTap, isFalse);
      expect(outer!.hasTap, isFalse);
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('禁用清空交互，重新启用可恢复静止鼠标悬停', (tester) async {
    ElEventState? state;
    final child = _probe((context) => state = ElEventView.maybeOf(context));
    Widget tree(bool disabled) => _shell(
      ElEventView(
        event: ElEvent(config: _immediate, disabled: disabled),
        child: child,
      ),
    );
    TestGesture? mouse;
    var down = false;
    try {
      await tester.pumpWidget(tree(false));
      mouse = await tester.createGesture(kind: .mouse);
      await mouse.addPointer(location: const Offset(20, 20));
      await tester.pump();
      expect(state!.hasHover, isTrue);
      await mouse.down(const Offset(20, 20));
      down = true;
      await tester.pump();
      expect(state!.hasTap, isTrue);
      await tester.pumpWidget(tree(true));
      expect(state!.disabled, isTrue);
      expect(state!.hasTap, isFalse);
      expect(state!.hasHover, isFalse);
      await mouse.up();
      down = false;
      await tester.pumpWidget(tree(false));
      await tester.pump();
      expect(state!.disabled, isFalse);
      expect(state!.hasHover, isTrue);
      expect(state!.hasTap, isFalse);
    } finally {
      if (down) await mouse?.cancel();
      await mouse?.removePointer();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('卸载会释放等待进入和等待退出的计时器', (tester) async {
    ElEventState? state;
    Widget tree() => _shell(
      ElEventView(
        event: const ElEvent(
          config: ElEventConfig(
            delayTouchDown: Duration(milliseconds: 40),
            delayTouchUp: Duration(milliseconds: 200),
          ),
        ),
        child: _probe((context) => state = ElEventView.maybeOf(context)),
      ),
    );
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(tree());
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
      await touch.up();
      down = false;
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(tree());
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 50));
      expect(state!.hasTap, isTrue);
      await touch.up();
      down = false;
      await tester.pump();
      expect(state!.hasTap, isTrue);
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('仅修改触摸反馈时长不重启正在等待的长按', (tester) async {
    var longPresses = 0;
    final child = const SizedBox(width: 100, height: 100);
    Widget tree(Duration delay) => _shell(
      ElEventView(
        event: ElEvent(
          config: ElEventConfig(
            delayTouchDown: delay,
            delayTouchUp: delay,
            longPressDelay: const Duration(milliseconds: 80),
          ),
          onLongPress: (_) => longPresses++,
        ),
        child: child,
      ),
    );
    TestGesture? touch;
    var down = false;
    try {
      await tester.pumpWidget(tree(Duration.zero));
      touch = await tester.startGesture(const Offset(20, 20));
      down = true;
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(tree(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 39));
      expect(longPresses, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(longPresses, 1);
      await touch.up();
      down = false;
    } finally {
      if (down) await touch?.cancel();
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });

  testWidgets('仅修改触摸反馈时长保留两次点击之间的双击窗口', (tester) async {
    var doubles = 0;
    Widget tree(Duration delay) => _shell(
      ElEventView(
        event: ElEvent(
          config: ElEventConfig(
            delayTouchDown: delay,
            delayTouchUp: delay,
            doubleTapInterval: const Duration(milliseconds: 100),
          ),
          onDoubleTap: (_) => doubles++,
        ),
        child: const SizedBox(width: 100, height: 100),
      ),
    );
    try {
      await tester.pumpWidget(tree(Duration.zero));
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(tree(const Duration(milliseconds: 20)));
      await tester.tapAt(const Offset(20, 20));
      expect(doubles, 1);
    } finally {
      await tester.pumpWidget(_shell(const SizedBox.shrink()));
    }
  });
}
