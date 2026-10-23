import 'package:flutter_base/src/ui/event/index.dart';
import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart' show RenderProxyBoxWithHitTestBehavior;
import 'package:flutter_test/flutter_test.dart';

Widget _shell(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(alignment: .topLeft, child: child),
);

Widget _box() => SizedBox(width: 100, height: 100);

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  for (final android in [true, false]) {
    testWidgets('Widget 拖拽按帧采样并在松手释放：Android=$android', (tester) async {
      final previousPlatform =
          ElEventDispatcher.debugDragResamplingPlatformOverride;
      final previousRefreshRate =
          ElEventDispatcher.debugDragResamplingRefreshRateOverride;
      final previousEnabled = ElEventDispatcher.enableDragResampling;
      final previousOffset = ElEventDispatcher.dragSamplingOffsetOverride;
      final previousOfficial = tester.binding.resamplingEnabled;
      TestGesture? gesture;
      var pressed = false;
      try {
        ElEventDispatcher.debugDragResamplingPlatformOverride = android
            ? .android
            : .windows;
        ElEventDispatcher.debugDragResamplingRefreshRateOverride = 120;
        ElEventDispatcher.enableDragResampling = true;
        // 固定尾随量，使首个采样帧的插值位置不受自适应触点节奏影响。
        ElEventDispatcher.dragSamplingOffsetOverride = Duration(
          milliseconds: -5,
        );
        tester.binding.resamplingEnabled = false;
        final updates = <Offset>[];
        var ends = 0;
        await tester.pumpWidget(
          _shell(
            ElEventView(
              event: ElEvent(
                config: ElEventConfig(
                  dragStartDistance: 3,
                  dragResampling: android ? {.android} : {.windows},
                ),
                onDragStart: (_) {},
                onDragUpdate: (e) => updates.add(e.delta),
                onDragEnd: (_) => ends++,
              ),
              child: _box(),
            ),
          ),
        );
        final base = tester.binding.currentSystemFrameTimeStamp;
        final currentGesture = await tester.createGesture(
          kind: android ? .touch : .mouse,
        );
        gesture = currentGesture;
        await currentGesture.down(Offset(20, 20), timeStamp: base);
        pressed = true;
        final box = tester.renderObject<RenderBox>(find.byType(ElEventView));
        final dispatcher = ElEventDispatcher.of(box)!;
        await currentGesture.moveBy(
          Offset(10, 0),
          timeStamp: base + Duration(milliseconds: 8),
        );
        expect(dispatcher.debugDragResamplingActive, isTrue);
        await currentGesture.moveBy(
          Offset(10, 0),
          timeStamp: base + Duration(milliseconds: 16),
        );
        expect(updates, isEmpty);
        await tester.pump(Duration(milliseconds: 16));
        expect(updates, hasLength(1));
        expect(updates.single.dx, closeTo(3.75, 0.001));
        await currentGesture.up(timeStamp: base + Duration(milliseconds: 24));
        pressed = false;
        expect(dispatcher.debugDragResamplingActive, isFalse);
        expect(ends, 1);
        expect(tester.binding.resamplingEnabled, isFalse);
      } finally {
        if (pressed) await gesture?.cancel();
        await tester.pumpWidget(_shell(SizedBox.shrink()));
        ElEventDispatcher.debugDragResamplingPlatformOverride =
            previousPlatform;
        ElEventDispatcher.debugDragResamplingRefreshRateOverride =
            previousRefreshRate;
        ElEventDispatcher.enableDragResampling = previousEnabled;
        ElEventDispatcher.dragSamplingOffsetOverride = previousOffset;
        tester.binding.resamplingEnabled = previousOfficial;
      }
    });
  }

  testWidgets('直接更新 dispatcher 光标会调度静止鼠标刷新', (tester) async {
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: ElEvent(cursor: SystemMouseCursors.click),
          child: _box(),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset(20, 20));
    await tester.pump();
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    final render = tester.renderObject<RenderBox>(find.byType(ElEventView));
    final dispatcher = ElEventDispatcher.of(render)!;
    dispatcher.event = dispatcher.event!.copyWith(
      cursor: SystemMouseCursors.text,
    );
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(render.debugNeedsPaint, isFalse);
    expect(render.debugNeedsLayout, isFalse);
    await tester.pump();
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.text,
    );
    dispatcher.event = dispatcher.event!.copyWith(
      clear: {ElEventClearField.cursor},
    );
    await tester.pump();
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.basic,
    );
  });

  testWidgets('禁用外层也清除后代已经抬起的延迟 Tap', (tester) async {
    var taps = 0;
    final child = ElEventView(
      event: ElEvent(
        config: ElEventConfig(
          deferTap: true,
          doubleTapInterval: Duration(milliseconds: 40),
        ),
        onTap: (_) => taps++,
        onDoubleTap: (_) {},
      ),
      child: _box(),
    );
    Widget tree(bool disabled) => _shell(
      ElEventView(
        event: ElEvent(disabled: disabled),
        child: child,
      ),
    );
    await tester.pumpWidget(tree(false));
    await tester.tapAt(Offset(20, 20));
    expect(taps, 0);
    await tester.pumpWidget(tree(true));
    await tester.pump(Duration(milliseconds: 80));
    expect(taps, 0);
    await tester.pumpWidget(tree(false));
    await tester.tapAt(Offset(20, 20));
    await tester.pump(Duration(milliseconds: 80));
    expect(taps, 1);
  });

  testWidgets('直接宿主保留子组件尺寸且不创建焦点节点', (tester) async {
    final event = ElEvent(onTap: (_) {});
    await tester.pumpWidget(_shell(ElEventView(event: event, child: _box())));
    final finder = find.byType(ElEventView);
    final box = tester.renderObject<RenderBox>(finder);
    expect(tester.getSize(finder), Size(100, 100));
    expect(ElEventDispatcher.of(box)!.event, same(event));
    expect(box, isA<RenderProxyBoxWithHitTestBehavior>());
    expect(
      find.descendant(of: finder, matching: find.byType(Focus)),
      findsNothing,
    );
  });

  for (final behavior in HitTestBehavior.values) {
    testWidgets('$behavior 区分空白、子内容与背后命中', (tester) async {
      var taps = 0;
      var behindDowns = 0;
      await tester.pumpWidget(
        _shell(
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                Listener(
                  onPointerDown: (_) => behindDowns++,
                  child: ColoredBox(
                    color: Color(0xff112233),
                    child: SizedBox.expand(),
                  ),
                ),
                ElEventView(
                  event: ElEvent(behavior: behavior, onTap: (_) => taps++),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: Center(
                      child: ColoredBox(
                        color: Color(0xff445566),
                        child: SizedBox(width: 40, height: 40),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(Offset(10, 10));
      expect(taps, behavior == .deferToChild ? 0 : 1);
      expect(behindDowns, behavior == .opaque ? 0 : 1);
      taps = 0;
      behindDowns = 0;
      await tester.tapAt(Offset(50, 50));
      expect(taps, 1);
      expect(behindDowns, 0, reason: '命中真实子内容后，不应继续命中背后的兄弟');
      taps = 0;
      await tester.tapAt(Offset(150, 150));
      expect(taps, 0);
      expect(behindDowns, 1);
    });
  }

  testWidgets('嵌套宿主经过官方 Padding 后仍按各自本地坐标冒泡', (tester) async {
    final calls = <(String, ElEventPhase, Offset)>[];
    ElEvent record(String name) => ElEvent(
      onPointerDown: (e) => calls.add((name, e.phase, e.localPosition)),
      onTap: (e) => calls.add((name, e.phase, e.localPosition)),
    );
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: record('parent'),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: ElEventView(event: record('child'), child: _box()),
          ),
        ),
      ),
    );
    await tester.tapAt(Offset(30, 30));
    expect(calls, [
      ('child', ElEventPhase.pointerDown, Offset(20, 20)),
      ('parent', ElEventPhase.pointerDown, Offset(30, 30)),
      ('child', ElEventPhase.tap, Offset(20, 20)),
      ('parent', ElEventPhase.tap, Offset(30, 30)),
    ]);
  });

  testWidgets('子宿主截断 Tap 冒泡且不影响下一次交互', (tester) async {
    var parentTaps = 0;
    var childTaps = 0;
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: ElEvent(onTap: (_) => parentTaps++),
          child: ElEventView(
            event: ElEvent(
              onTap: (e) {
                childTaps++;
                e.stopPropagation();
              },
            ),
            child: _box(),
          ),
        ),
      ),
    );
    await tester.tapAt(Offset(20, 20));
    await tester.tapAt(Offset(20, 20));
    expect(childTaps, 2);
    expect(parentTaps, 0);
  });

  testWidgets('hover 回调与静止鼠标光标更新直接接入宿主', (tester) async {
    final phases = <ElEventPhase>[];
    final positions = <Offset>[];
    void record(ElEventCallback e) {
      phases.add(e.phase);
      positions.add(e.localPosition);
    }

    final event = ElEvent(
      onPointerEnter: record,
      onPointerHover: record,
      onPointerExit: record,
    );
    Widget tree(MouseCursor cursor, {bool disabled = false}) => _shell(
      ElEventView(
        event: event.copyWith(cursor: cursor, disabled: disabled),
        child: _box(),
      ),
    );
    await tester.pumpWidget(tree(SystemMouseCursors.click));
    final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset(150, 20));
    await mouse.moveTo(Offset(20, 20));
    await tester.pump();
    expect(
      phases,
      containsAll([ElEventPhase.pointerEnter, ElEventPhase.pointerHover]),
    );
    expect(positions.every((position) => position == Offset(20, 20)), isTrue);
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    await tester.pumpWidget(tree(SystemMouseCursors.text));
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.text,
    );
    await mouse.moveTo(Offset(150, 20));
    await tester.pump();
    expect(phases.last, ElEventPhase.pointerExit);
    await mouse.moveTo(Offset(20, 20));
    await tester.pumpWidget(tree(SystemMouseCursors.click, disabled: true));
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.forbidden,
    );
    final count = phases.length;
    await mouse.moveTo(Offset(30, 20));
    await tester.pump();
    expect(phases, hasLength(count));
    await tester.pumpWidget(tree(SystemMouseCursors.click));
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
  });

  testWidgets('按下后更换闭包和命中行为仍向新回调释放', (tester) async {
    final calls = <String>[];
    Widget tree(String label, HitTestBehavior behavior) => _shell(
      ElEventView(
        event: ElEvent(
          behavior: behavior,
          onTapDown: (_) => calls.add('$label:down'),
          onTapUp: (_) => calls.add('$label:up'),
          onTap: (_) => calls.add('$label:tap'),
          onTapCancel: (_) => calls.add('$label:cancel'),
        ),
        child: _box(),
      ),
    );
    await tester.pumpWidget(tree('old', .opaque));
    final gesture = await tester.startGesture(Offset(20, 20));
    await tester.pumpWidget(tree('new', .translucent));
    await gesture.up();
    await tester.pump();
    expect(calls, ['old:down', 'new:up', 'new:tap']);
  });

  testWidgets('只有 Hover 或只有光标也能独立工作', (tester) async {
    var hovers = 0;
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: ElEvent(onPointerHover: (_) => hovers++),
          child: _box(),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset(150, 20));
    await mouse.moveTo(Offset(20, 20));
    await tester.pump();
    expect(hovers, 1);
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: ElEvent(cursor: SystemMouseCursors.click),
          child: _box(),
        ),
      ),
    );
    expect(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    await mouse.moveTo(Offset(30, 20));
    expect(hovers, 1, reason: '移除回调后不应继续调用旧闭包');
  });

  testWidgets('禁用外层结清已按下后代，且不会穿透到背后', (tester) async {
    final calls = <ElEventPhase>[];
    var behindDowns = 0;
    void record(ElEventCallback e) => calls.add(e.phase);
    final child = ElEventView(
      event: ElEvent(
        onPointerDown: record,
        onPointerUp: record,
        onPointerCancel: record,
        onTapDown: record,
        onTapUp: record,
        onTap: record,
        onTapCancel: record,
      ),
      child: _box(),
    );
    Widget tree(bool disabled) => _shell(
      Stack(
        children: [
          Listener(
            onPointerDown: (_) => behindDowns++,
            child: ColoredBox(color: Color(0xff112233), child: _box()),
          ),
          ElEventView(
            event: ElEvent(onTap: record, disabled: disabled),
            child: child,
          ),
        ],
      ),
    );
    await tester.pumpWidget(tree(false));
    final gesture = await tester.startGesture(Offset(20, 20));
    await tester.pumpWidget(tree(true));
    await gesture.up();
    await tester.pump();
    expect(calls, [
      ElEventPhase.pointerDown,
      ElEventPhase.tapDown,
      ElEventPhase.pointerCancel,
      ElEventPhase.tapCancel,
    ]);
    await tester.tapAt(Offset(20, 20));
    expect(calls, hasLength(4));
    expect(behindDowns, 0);
    await tester.pumpWidget(tree(false));
    await tester.tapAt(Offset(20, 20));
    expect(calls.where((phase) => phase == ElEventPhase.tap), hasLength(2));
  });

  testWidgets('变换后的边界仍允许移出取消、移回复燃', (tester) async {
    final phases = <ElEventPhase>[];
    void record(ElEventCallback e) => phases.add(e.phase);
    await tester.pumpWidget(
      _shell(
        Transform.scale(
          scale: 2,
          alignment: .topLeft,
          child: ElEventView(
            event: ElEvent(
              onTapDown: record,
              onTapCancel: record,
              onTapUp: record,
              onTap: record,
            ),
            child: _box(),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(Offset(150, 20), kind: .mouse);
    await gesture.moveTo(Offset(250, 20));
    await gesture.moveTo(Offset(150, 20));
    await gesture.up();
    await tester.pump();
    expect(phases, [
      ElEventPhase.tapDown,
      ElEventPhase.tapCancel,
      ElEventPhase.tapDown,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ]);
  });

  testWidgets('GlobalKey 重挂保留分发器与当前按压序列', (tester) async {
    final key = GlobalKey();
    final phases = <ElEventPhase>[];
    void record(ElEventCallback e) => phases.add(e.phase);
    final event = ElEvent(
      onTapDown: record,
      onTapCancel: record,
      onTapUp: record,
      onTap: record,
    );
    Widget tree(bool left) {
      final view = ElEventView(key: key, event: event, child: _box());
      return _shell(
        Stack(
          children: [
            KeyedSubtree(key: ValueKey('left'), child: left ? view : _box()),
            KeyedSubtree(key: ValueKey('right'), child: left ? _box() : view),
          ],
        ),
      );
    }

    await tester.pumpWidget(tree(true));
    final render = tester.renderObject<RenderBox>(find.byKey(key));
    final dispatcher = ElEventDispatcher.of(render)!;
    final gesture = await tester.startGesture(Offset(20, 20));
    await tester.pumpWidget(tree(false));
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect(ElEventDispatcher.of(render), same(dispatcher));
    await gesture.up();
    await tester.pump();
    expect(phases, [
      ElEventPhase.tapDown,
      ElEventPhase.tapUp,
      ElEventPhase.tap,
    ]);
  });

  testWidgets('卸载已开始的拖拽只发一次 Cancel 并释放注册', (tester) async {
    final phases = <ElEventPhase>[];
    void record(ElEventCallback e) => phases.add(e.phase);
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: ElEvent(
            config: ElEventConfig(dragStartDistance: 0, dragResampling: {}),
            onDragStart: record,
            onDragEnd: record,
            onDragCancel: record,
          ),
          child: _box(),
        ),
      ),
    );
    final render = tester.renderObject<RenderBox>(find.byType(ElEventView));
    final gesture = await tester.startGesture(Offset(20, 20));
    await gesture.moveBy(Offset(20, 0));
    await tester.pump();
    expect(phases, [ElEventPhase.dragStart]);
    await tester.pumpWidget(_shell(SizedBox.shrink()));
    expect(phases, [ElEventPhase.dragStart, ElEventPhase.dragCancel]);
    expect(ElEventDispatcher.of(render), isNull);
    await gesture.up();
    expect(phases, hasLength(2));
  });
  for (final listenTap in [false, true]) {
    for (final readFeedback in [false, true]) {
      testWidgets(
        'onTap 决定官方点击竞争，读取样式不改变结果：tap=$listenTap read=$readFeedback',
        (tester) async {
          var officialTaps = 0;
          var elTaps = 0;
          var downs = 0;
          var ups = 0;
          var pressed = false;
          await tester.pumpWidget(
            _shell(
              GestureDetector(
                onTap: () => officialTaps++,
                child: ElEventView(
                  event: ElEvent(
                    config: const ElEventConfig(delayTouchUp: Duration.zero),
                    onTap: listenTap ? (_) => elTaps++ : null,
                    onTapDown: (_) => downs++,
                    onTapUp: (_) => ups++,
                  ),
                  child: Builder(
                    builder: (context) {
                      if (readFeedback) pressed = context.hasTap;
                      return _box();
                    },
                  ),
                ),
              ),
            ),
          );
          final pointer = await tester.startGesture(const Offset(20, 20));
          await tester.pump();
          if (readFeedback) expect(pressed, isTrue);
          await pointer.up();
          await tester.pump();
          expect(
            [elTaps, officialTaps, downs, ups],
            [listenTap ? 1 : 0, listenTap ? 0 : 1, 1, 1],
          );
          if (readFeedback) expect(pressed, isFalse);
        },
      );
    }
  }

  testWidgets('只监听 Down 也能截断 El 点击冒泡，并让官方 Tap 正常竞争', (tester) async {
    final trace = <String>[];
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          onTap: () => trace.add('official.tap'),
          child: ElEventView(
            event: ElEvent(
              onPointerUp: (_) => trace.add('parent.rawUp'),
              onTapDown: (_) => trace.add('parent.down'),
              onTap: (_) => trace.add('parent.tap'),
            ),
            child: ElEventView(
              event: ElEvent(
                onTapDown: (event) {
                  trace.add('child.down');
                  event.stopPropagation();
                },
                onTapUp: (_) => trace.add('child.up'),
              ),
              child: _box(),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 20));
    expect(trace, ['child.down', 'parent.rawUp', 'child.up', 'official.tap']);
  });

  testWidgets('官方子 Tap 获胜，外层 El 不会因冒泡或读取样式抢回点击', (tester) async {
    var official = 0;
    var el = 0;
    var pressed = false;
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: ElEvent(onTap: (_) => el++),
          child: Builder(
            builder: (context) {
              pressed = context.hasTap;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => official++,
                child: _box(),
              );
            },
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect([official, el, pressed], [1, 0, false]);
  });

  testWidgets('仅声明长按不拦截官方普通点击，达到长按时间后才接管', (tester) async {
    var taps = 0;
    var longs = 0;
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          onTap: () => taps++,
          child: ElEventView(
            event: ElEvent(
              config: const ElEventConfig(
                longPressDelay: Duration(milliseconds: 30),
              ),
              onLongPress: (_) => longs++,
            ),
            child: _box(),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 20));
    expect([taps, longs], [1, 0]);
    final pointer = await tester.startGesture(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 30));
    await pointer.up();
    expect([taps, longs], [1, 1]);
  });

  testWidgets('内层仅监听长按，不替外层 El 点击抢占中间官方 Tap', (tester) async {
    final trace = <String>[];
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: ElEvent(onTap: (_) => trace.add('outer.tap')),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => trace.add('official.tap'),
            child: ElEventView(
              event: ElEvent(
                config: const ElEventConfig(
                  longPressDelay: Duration(milliseconds: 30),
                ),
                onLongPress: (_) => trace.add('inner.long'),
              ),
              child: _box(),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 20));
    expect(trace, ['official.tap']);
    trace.clear();
    final pointer = await tester.startGesture(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 30));
    await pointer.up();
    expect(trace, ['inner.long']);
  });

  testWidgets('官方 Drag 获胜后，原始 Move 中的独占请求不能抢回归属', (tester) async {
    final trace = <String>[];
    var moves = 0;
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          onPanStart: (_) => trace.add('official.start'),
          onPanEnd: (_) => trace.add('official.end'),
          child: ElEventView(
            event: ElEvent(
              config: const ElEventConfig(
                dragStartDistance: 100,
                dragResampling: {},
              ),
              onPointerMove: (event) {
                if (++moves > 1) event.eagerGesture();
              },
              onDragStart: (_) => trace.add('el.start'),
              onDragEnd: (_) => trace.add('el.end'),
            ),
            child: _box(),
          ),
        ),
      ),
    );
    final pointer = await tester.startGesture(const Offset(20, 20));
    await pointer.moveBy(const Offset(60, 0));
    expect(trace, ['official.start']);
    await pointer.moveBy(const Offset(120, 0));
    await pointer.up();
    expect(moves, 2);
    expect(trace, ['official.start', 'official.end']);
  });

  testWidgets('子元素越界只取消自身点击，父级保留点击与独立连击历史', (tester) async {
    final trace = <String>[];
    await tester.pumpWidget(
      _shell(
        ElEventView(
          event: ElEvent(
            onTap: (event) => trace.add('parent:${event.tapCount}'),
            onDoubleTap: (_) {},
          ),
          child: SizedBox(
            width: 200,
            height: 100,
            child: Align(
              alignment: Alignment.topLeft,
              child: ElEventView(
                event: ElEvent(
                  onTap: (event) => trace.add('child:${event.tapCount}'),
                  onDoubleTap: (_) {},
                ),
                child: _box(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 20));
    final pointer = await tester.startGesture(const Offset(20, 20));
    await pointer.moveTo(const Offset(150, 20));
    await pointer.up();
    await tester.tapAt(const Offset(20, 20));
    expect(trace, ['child:1', 'parent:1', 'parent:1', 'child:1', 'parent:1']);
    await tester.pump(const Duration(milliseconds: 301));
  });

  for (final elFirst in [false, true]) {
    testWidgets('El 和官方 Drag 双向互斥且落败后不复活：elFirst=$elFirst', (tester) async {
      final trace = <String>[];
      await tester.pumpWidget(
        _shell(
          GestureDetector(
            onVerticalDragStart: (_) => trace.add('official.start'),
            onVerticalDragEnd: (_) => trace.add('official.end'),
            child: ElEventView(
              event: ElEvent(
                config: ElEventConfig(
                  dragStartDistance: elFirst ? 3 : 100,
                  dragResampling: const {},
                ),
                onVerticalDragStart: (_) => trace.add('el.start'),
                onVerticalDragEnd: (_) => trace.add('el.end'),
              ),
              child: _box(),
            ),
          ),
        ),
      );
      final pointer = await tester.startGesture(const Offset(20, 20));
      await pointer.moveBy(const Offset(0, 30));
      await pointer.moveBy(const Offset(0, 30));
      await pointer.up();
      expect(
        trace,
        elFirst ? ['el.start', 'el.end'] : ['official.start', 'official.end'],
      );
    });
  }
}
