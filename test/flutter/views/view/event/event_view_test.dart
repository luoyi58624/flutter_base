import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

Widget _shell(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(alignment: .topLeft, child: child),
);

Widget _box() => SizedBox(width: 100, height: 100);

void main() {
  setUp(EventDispatcher.debugReset);

  testWidgets('直接更新 dispatcher 光标会调度静止鼠标刷新', (tester) async {
    await tester.pumpWidget(
      _shell(
        ElView(
          event: ElEvent(cursor: SystemMouseCursors.click),
          child: _box(),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset(20, 20));
    await tester.pump();
    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
    final render = tester.renderObject<RenderBox>(find.byType(ElView));
    final dispatcher = EventDispatcher.of(render)!;
    dispatcher.event = dispatcher.event!.copyWith(cursor: SystemMouseCursors.text);
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(render.debugNeedsPaint, isFalse);
    expect(render.debugNeedsLayout, isFalse);
    await tester.pump();
    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);
    dispatcher.event = dispatcher.event!.copyWith(cursor: null);
    await tester.pump();
    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
  });

  testWidgets('禁用外层也清除后代已经抬起的延迟 Tap', (tester) async {
    var taps = 0;
    final child = ElView(
      event: ElEvent(
        deferTap: true,
        doubleTapInterval: Duration(milliseconds: 40),
        onTap: (_) => taps++,
        onDoubleTap: (_) {},
      ),
      child: _box(),
    );
    Widget tree(bool disabled) => _shell(
      ElView(
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
    await tester.pumpWidget(_shell(ElView(event: event, child: _box())));
    final finder = find.byType(ElView);
    final box = tester.renderObject<RenderBox>(finder);
    expect(tester.getSize(finder), Size(100, 100));
    expect(EventDispatcher.of(box)!.event, same(event));
    expect(box, isA<ElRenderView>());
    expect(find.descendant(of: finder, matching: find.byType(Focus)), findsNothing);
  });

  for (final behavior in HitTestBehavior.values) {
    testWidgets('$behavior 区分空白、子内容与背后命中', (tester) async {
      var taps = 0;
      var behindDowns = 0;
      Widget tree({bool disabled = false}) => _shell(
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            children: [
              Listener(
                onPointerDown: (_) => behindDowns++,
                child: ColoredBox(color: Color(0xff112233), child: SizedBox.expand()),
              ),
              ElView(
                event: ElEvent(behavior: behavior, disabled: disabled, onTap: (_) => taps++),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Center(
                    child: ColoredBox(color: Color(0xff445566), child: SizedBox(width: 40, height: 40)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree());
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
      behindDowns = 0;
      await tester.pumpWidget(tree(disabled: true));
      await tester.tapAt(Offset(10, 10));
      await tester.tapAt(Offset(50, 50));
      expect(taps, 0);
      expect(behindDowns, 0, reason: '禁用表面始终吞命中，不受事件命中行为影响');
    });
  }

  testWidgets('半透明宿主保留自身变换和圆角裁剪，指针透明时不加入事件路径', (tester) async {
    var downs = 0;
    var behindDowns = 0;
    Widget tree({ElPointerEvents? pointerEvents}) => _shell(
      SizedBox(
        width: 200,
        height: 150,
        child: Stack(
          children: [
            Listener(
              onPointerDown: (_) => behindDowns++,
              child: ColoredBox(color: Color(0xff112233), child: SizedBox.expand()),
            ),
            ElView(
              style: ElStyle(
                width: 100,
                height: 100,
                backgroundColor: Color(0xff445566),
                borderRadius: BorderRadius.all(Radius.circular(50)),
                clipBehavior: Clip.hardEdge,
                transform: ElTransform.translate(20, 0),
                pointerEvents: pointerEvents,
              ),
              event: ElEvent(behavior: .translucent, onPointerDown: (_) => downs++),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree());
    await tester.tapAt(Offset(21, 1));
    expect(downs, 0, reason: '自身变换后的圆角外仍不参与事件');
    expect(behindDowns, 1);
    await tester.tapAt(Offset(70, 50));
    expect(downs, 1);
    expect(behindDowns, 2, reason: '背景绘制不能覆盖显式半透明命中行为');
    await tester.pumpWidget(tree(pointerEvents: .none));
    await tester.tapAt(Offset(70, 50));
    expect(downs, 1);
    expect(behindDowns, 3);
  });

  for (final elAncestor in [true, false]) {
    testWidgets('混合冒泡保持各宿主坐标：ElView 祖先=$elAncestor', (tester) async {
      final calls = <(String, ElEventPhase, Offset)>[];
      ElEvent record(String owner) => ElEvent(
        onPointerDown: (e) => calls.add((owner, e.phase, e.localPosition)),
        onTap: (e) => calls.add((owner, e.phase, e.localPosition)),
      );
      final content = ColoredBox(color: Color(0xff112233), child: SizedBox(width: 60, height: 40));
      final style = ElStyle(width: 120, height: 80, padding: EdgeInsets.all(10));
      await tester.pumpWidget(
        _shell(
          elAncestor
              ? ElView(
                  style: style,
                  event: record('parent'),
                  child: ElView(event: record('child'), child: content),
                )
              : ElView(
                  event: record('parent'),
                  child: ElView(style: style, event: record('child'), child: content),
                ),
        ),
      );
      await tester.tapAt(Offset(30, 30));
      expect(calls, [
        ('child', ElEventPhase.pointerDown, Offset(20, 20)),
        ('parent', ElEventPhase.pointerDown, elAncestor ? Offset(20, 20) : Offset(30, 30)),
        ('child', ElEventPhase.tap, Offset(20, 20)),
        ('parent', ElEventPhase.tap, elAncestor ? Offset(20, 20) : Offset(30, 30)),
      ]);
    });
  }

  testWidgets('子 ElView 截断 Tap 冒泡并保留自身按压样式', (tester) async {
    var parentTaps = 0;
    var childTaps = 0;
    final key = GlobalKey();
    await tester.pumpWidget(
      _shell(
        ElView(
          event: ElEvent(onTap: (_) => parentTaps++),
          child: ElView(
            key: key,
            style: ElStyle(
              width: 100,
              height: 100,
              backgroundColor: Color(0xff112233),
              onTap: ElStyle(backgroundColor: Color(0xff445566)),
            ),
            event: ElEvent(
              onTap: (e) {
                childTaps++;
                e.stopPropagation();
              },
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(Offset(20, 20), kind: .mouse);
    await tester.pump();
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff445566));
    await gesture.up();
    await tester.pump();
    expect(childTaps, 1);
    expect(parentTaps, 0);
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff112233));
  });

  testWidgets('hover 回调与静止鼠标光标更新直接接入宿主', (tester) async {
    final phases = <ElEventPhase>[];
    final positions = <Offset>[];
    void record(ElEventDetails e) {
      phases.add(e.phase);
      positions.add(e.localPosition);
    }

    final event = ElEvent(onPointerEnter: record, onPointerHover: record, onPointerExit: record);
    Widget tree(MouseCursor cursor, {bool disabled = false}) => _shell(
      ElView(
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
    expect(phases, containsAll([ElEventPhase.pointerEnter, ElEventPhase.pointerHover]));
    expect(positions.every((position) => position == Offset(20, 20)), isTrue);
    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
    await tester.pumpWidget(tree(SystemMouseCursors.text));
    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);
    await mouse.moveTo(Offset(150, 20));
    await tester.pump();
    expect(phases.last, ElEventPhase.pointerExit);
    await mouse.moveTo(Offset(20, 20));
    await tester.pumpWidget(tree(SystemMouseCursors.click, disabled: true));
    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.forbidden);
    final count = phases.length;
    await mouse.moveTo(Offset(30, 20));
    await tester.pump();
    expect(phases, hasLength(count));
    await tester.pumpWidget(tree(SystemMouseCursors.click));
    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
  });

  testWidgets('按下后更换闭包和命中行为仍向新回调释放', (tester) async {
    final calls = <String>[];
    Widget tree(String label, HitTestBehavior behavior) => _shell(
      ElView(
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
        ElView(
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
        ElView(
          event: ElEvent(cursor: SystemMouseCursors.click),
          child: _box(),
        ),
      ),
    );
    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
    await mouse.moveTo(Offset(30, 20));
    expect(hovers, 1, reason: '移除回调后不应继续调用旧闭包');
  });

  testWidgets('禁用外层结清已按下后代，且不会穿透到背后', (tester) async {
    final calls = <ElEventPhase>[];
    var behindDowns = 0;
    void record(ElEventDetails e) => calls.add(e.phase);
    final child = ElView(
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
          ElView(
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
    expect(calls, [ElEventPhase.pointerDown, ElEventPhase.tapDown, ElEventPhase.pointerCancel, ElEventPhase.tapCancel]);
    await tester.tapAt(Offset(20, 20));
    expect(calls, hasLength(4));
    expect(behindDowns, 0);
    await tester.pumpWidget(tree(false));
    await tester.tapAt(Offset(20, 20));
    expect(calls.where((phase) => phase == ElEventPhase.tap), hasLength(2));
  });

  testWidgets('变换后的边界仍允许移出取消、移回复燃', (tester) async {
    final phases = <ElEventPhase>[];
    void record(ElEventDetails e) => phases.add(e.phase);
    await tester.pumpWidget(
      _shell(
        Transform.scale(
          scale: 2,
          alignment: .topLeft,
          child: ElView(
            event: ElEvent(onTapDown: record, onTapCancel: record, onTapUp: record, onTap: record),
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
    void record(ElEventDetails e) => phases.add(e.phase);
    final event = ElEvent(onTapDown: record, onTapCancel: record, onTapUp: record, onTap: record);
    Widget tree(bool left) {
      final view = ElView(key: key, event: event, child: _box());
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
    final dispatcher = EventDispatcher.of(render)!;
    final gesture = await tester.startGesture(Offset(20, 20));
    await tester.pumpWidget(tree(false));
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect(EventDispatcher.of(render), same(dispatcher));
    await gesture.up();
    await tester.pump();
    expect(phases, [ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
  });

  testWidgets('GlobalKey 重挂到指针之外：保留按压序列，松手只收到取消与抬起', (tester) async {
    final key = GlobalKey();
    final phases = <ElEventPhase>[];
    void record(ElEventDetails e) => phases.add(e.phase);
    final event = ElEvent(onTapDown: record, onTapCancel: record, onTapUp: record, onTap: record);
    Widget tree(bool left) {
      final view = ElView(key: key, event: event, child: _box());
      return _shell(
        Row(
          mainAxisSize: .min,
          children: [
            KeyedSubtree(key: ValueKey('left'), child: left ? view : _box()),
            KeyedSubtree(key: ValueKey('right'), child: left ? _box() : view),
          ],
        ),
      );
    }

    await tester.pumpWidget(tree(true));
    final render = tester.renderObject<RenderBox>(find.byKey(key));
    final dispatcher = EventDispatcher.of(render)!;
    final gesture = await tester.startGesture(Offset(20, 20));
    await tester.pumpWidget(tree(false));
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect(EventDispatcher.of(render), same(dispatcher));
    expect(phases, [ElEventPhase.tapDown], reason: '重挂本身不结束按压');
    await gesture.up();
    await tester.pump();
    // 指针没有移动，视图却已不在指针下：松手时按最终位置核对，过期的点击不完成。
    expect(phases, [ElEventPhase.tapDown, ElEventPhase.tapCancel, ElEventPhase.tapUp]);

    phases.clear();
    await tester.tap(find.byKey(key));
    await tester.pump();
    expect(phases, [ElEventPhase.tapDown, ElEventPhase.tapUp, ElEventPhase.tap]);
  });

  testWidgets('卸载已开始的拖拽只发一次 Cancel 并释放注册', (tester) async {
    final phases = <ElEventPhase>[];
    void record(ElEventDetails e) => phases.add(e.phase);
    await tester.pumpWidget(
      _shell(
        ElView(
          event: ElEvent(dragStartDistance: 0, onDragStart: record, onDragEnd: record, onDragCancel: record),
          child: _box(),
        ),
      ),
    );
    final render = tester.renderObject<RenderBox>(find.byType(ElView));
    final gesture = await tester.startGesture(Offset(20, 20));
    await gesture.moveBy(Offset(20, 0));
    await tester.pump();
    expect(phases, [ElEventPhase.dragStart]);
    await tester.pumpWidget(_shell(SizedBox.shrink()));
    expect(phases, [ElEventPhase.dragStart, ElEventPhase.dragCancel]);
    expect(EventDispatcher.of(render), isNull);
    await gesture.up();
    expect(phases, hasLength(2));
  });

  testWidgets('仅监听后代 El 焦点和键盘冒泡，不创建自己的 Focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final keys = <String>[];
    final focus = <String>[];
    await tester.pumpWidget(
      _shell(
        ElView(
          event: ElEvent(onFocus: (_) => focus.add('parent'), onKeyDown: (_) => keys.add('parent')),
          child: ElView(
            focusNode: node,
            event: ElEvent(onFocus: (_) => focus.add('child'), onKeyDown: (_) => keys.add('child')),
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    expect(focus, ['child', 'parent']);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(keys, ['child', 'parent']);
  });
}
