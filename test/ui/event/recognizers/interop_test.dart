import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

// 释放后跨过默认长按与连击窗口，同时验证失权序列不会产生延迟事件。
const _afterGesture = Duration(milliseconds: 700);

Widget _shell(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

// 这里只提供真实命中入口，指针路由与胜负裁决始终由 Flutter binding 执行。
Widget _host(GestureRecognizer recognizer, {Key? key, Widget? child}) =>
    Listener(
      key: key,
      behavior: HitTestBehavior.opaque,
      onPointerDown: recognizer.addPointer,
      onPointerPanZoomStart: recognizer.addPointerPanZoom,
      child: child ?? const SizedBox(width: 200, height: 200),
    );

ElPressGestureRecognizer _press(
  List<String> events,
  String name, {
  ElPressGestureRecognizer? parent,
  ElEventConfig config = const ElEventConfig(),
  Offset Function(Offset)? globalToLocal,
}) {
  final recognizer = ElPressGestureRecognizer(
    config: config,
    parent: parent,
    globalToLocal: globalToLocal,
  );
  recognizer.onTapDown = (_) => events.add('$name.down');
  recognizer.onTapUp = (_) => events.add('$name.up');
  recognizer.onTap = (_) => events.add('$name.tap');
  recognizer.onLongPress = (_) => events.add('$name.longPress');
  recognizer.onTapCancel = (_) => events.add('$name.cancel');
  return recognizer;
}

ElTransformGestureRecognizer _drag(
  List<String> events,
  String name, {
  ElTransformGestureRecognizer? parent,
  double distance = 6,
}) {
  final recognizer = ElTransformGestureRecognizer(
    config: ElEventConfig(dragStartDistance: distance),
    parent: parent,
    axis: Axis.horizontal,
  );
  recognizer.onDragDown = (_) => events.add('$name.down');
  recognizer.onDragStart = (_) => events.add('$name.start');
  recognizer.onDragUpdate = (_) => events.add('$name.update');
  recognizer.onDragEnd = (_) => events.add('$name.end');
  recognizer.onDragCancel = (_) => events.add('$name.cancel');
  return recognizer;
}

Offset _local(GlobalKey key, Offset global) =>
    (key.currentContext!.findRenderObject()! as RenderBox).globalToLocal(
      global,
    );

void main() {
  testWidgets('El 子点击向 El 父冒泡，并使外层官方 Tap 落败', (tester) async {
    final events = <String>[];
    final parent = _press(events, 'parent');
    final child = _press(events, 'child', parent: parent);
    addTearDown(parent.dispose);
    addTearDown(child.dispose);

    await tester.pumpWidget(
      _shell(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => events.add('official.down'),
          onTap: () => events.add('official.tap'),
          onTapCancel: () => events.add('official.cancel'),
          child: _host(parent, child: _host(child)),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pump(_afterGesture);

    expect(events, containsAllInOrder(['child.down', 'parent.down']));
    expect(events.where((event) => event.endsWith('.tap')), [
      'child.tap',
      'parent.tap',
    ]);
    expect(events.where((event) => event.endsWith('.up')), [
      'child.up',
      'parent.up',
    ]);
    expect(events.where((event) => event.endsWith('.cancel')), [
      'official.cancel',
    ]);
  });

  testWidgets('官方子 Tap 获胜后，外层 El 仅取消而不产生 Up 或 Tap', (tester) async {
    final events = <String>[];
    final press = _press(events, 'el');
    addTearDown(press.dispose);
    await tester.pumpWidget(
      _shell(
        _host(
          press,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => events.add('official.tap'),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.up();
    await tester.pump(_afterGesture);

    expect(events, containsAllInOrder(['el.down', 'el.cancel']));
    expect(events.where((event) => event.endsWith('.tap')), ['official.tap']);
    expect(events, isNot(contains('el.up')));
    expect(events.where((event) => event == 'el.cancel'), hasLength(1));
  });

  testWidgets('TapDown 截断只影响 El 冒泡，官方外层仍由竞技场取消', (tester) async {
    final events = <String>[];
    final parent = _press(events, 'parent');
    final child = _press(events, 'child', parent: parent)
      ..onTapDown = (event) {
        events.add('child.down');
        event.stopPropagation();
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          onTapDown: (_) => events.add('official.down'),
          onTap: () => events.add('official.tap'),
          onTapCancel: () => events.add('official.cancel'),
          child: _host(parent, child: _host(child)),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pump(_afterGesture);

    expect(events.where((event) => event.startsWith('parent.')), isEmpty);
    expect(events, containsAll(['child.up', 'child.tap', 'official.cancel']));
    expect(events, isNot(contains('official.tap')));
  });

  testWidgets('停止 El 冒泡不能抢走官方子 Tap 的胜利', (tester) async {
    final events = <String>[];
    final parent = _press(events, 'parent');
    final child = _press(events, 'child', parent: parent)
      ..onTapDown = (event) {
        events.add('child.down');
        event.stopPropagation();
      };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      _shell(
        _host(
          parent,
          child: _host(
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
    await tester.pump(_afterGesture);

    expect(events.where((event) => event.startsWith('parent.')), isEmpty);
    expect(events.where((event) => event.endsWith('.tap')), ['official.tap']);
    expect(events, contains('child.cancel'));
    expect(events, isNot(contains('child.up')));
  });

  testWidgets('El 水平拖拽先激活后，外层官方水平拖拽仅取消', (tester) async {
    final events = <String>[];
    final drag = _drag(events, 'el');
    addTearDown(drag.dispose);
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          onHorizontalDragDown: (_) => events.add('official.down'),
          onHorizontalDragStart: (_) => events.add('official.start'),
          onHorizontalDragUpdate: (_) => events.add('official.update'),
          onHorizontalDragEnd: (_) => events.add('official.end'),
          onHorizontalDragCancel: () => events.add('official.cancel'),
          child: _host(drag),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(14, 0));
    await gesture.up();
    await tester.pump(_afterGesture);

    expect(
      events,
      containsAllInOrder(['el.down', 'el.start', 'el.update', 'el.end']),
    );
    expect(events.where((event) => event == 'official.cancel'), hasLength(1));
    expect(events, isNot(contains('el.cancel')));
    expect(events, isNot(contains('official.start')));
    expect(events, isNot(contains('official.update')));
    expect(events, isNot(contains('official.end')));
  });

  testWidgets('官方子拖拽先激活后，El 外层仅取消且不继续更新', (tester) async {
    final events = <String>[];
    final drag = _drag(events, 'el', distance: 60);
    addTearDown(drag.dispose);
    await tester.pumpWidget(
      _shell(
        _host(
          drag,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => events.add('official.start'),
            onHorizontalDragUpdate: (_) => events.add('official.update'),
            onHorizontalDragEnd: (_) => events.add('official.end'),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(80, 0));
    await gesture.up();
    await tester.pump(_afterGesture);

    expect(
      events,
      containsAllInOrder(['official.start', 'official.update', 'official.end']),
    );
    expect(events.where((event) => event.startsWith('el.')), [
      'el.down',
      'el.cancel',
    ]);
  });

  testWidgets('El 拖拽冒泡至父订阅者时，官方外层仍被正常排除', (tester) async {
    final events = <String>[];
    final parent = _drag(events, 'parent');
    final child = _drag(events, 'child', parent: parent);
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          onHorizontalDragStart: (_) => events.add('official.start'),
          child: _host(parent, child: _host(child)),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(14, 0));
    await gesture.up();
    await tester.pump(_afterGesture);

    expect(events.where((event) => event.endsWith('.start')), [
      'child.start',
      'parent.start',
    ]);
    expect(events.where((event) => event.endsWith('.end')), [
      'child.end',
      'parent.end',
    ]);
    expect(events, isNot(contains('official.start')));
    expect(events.where((event) => event.endsWith('.cancel')), isEmpty);
  });

  testWidgets('ListView 滚动获胜后内部 El 点击和长按不会在释放后复活', (tester) async {
    final events = <String>[];
    final press = _press(events, 'el');
    final controller = ScrollController();
    addTearDown(press.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        SizedBox(
          width: 200,
          height: 250,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              _host(press, child: const SizedBox(height: 200)),
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

  testWidgets('同一宿主的 El 拖拽获胜会取消 El 点击', (tester) async {
    final events = <String>[];
    final press = _press(events, 'press');
    final drag = _drag(events, 'drag');
    addTearDown(press.dispose);
    addTearDown(drag.dispose);
    await tester.pumpWidget(
      _shell(
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            press.addPointer(event);
            drag.addPointer(event);
          },
          child: const SizedBox(width: 200, height: 200),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(50, 50));
    await gesture.moveBy(const Offset(12, 0));
    await gesture.moveBy(const Offset(14, 0));
    await gesture.up();
    await tester.pump(_afterGesture);

    expect(events.where((event) => event.startsWith('press.')), [
      'press.down',
      'press.cancel',
    ]);
    expect(
      events,
      containsAllInOrder(['drag.start', 'drag.update', 'drag.end']),
    );
  });

  testWidgets('El 多指缩放获胜后外层官方 Scale 不跟随更新', (tester) async {
    final events = <String>[];
    final transform = ElTransformGestureRecognizer(
      config: const ElEventConfig(dragStartDistance: 4),
    );
    transform.onScaleStart = (_) => events.add('el.start');
    transform.onScaleUpdate = (_) => events.add('el.update');
    transform.onScaleEnd = (_) => events.add('el.end');
    addTearDown(transform.dispose);
    await tester.pumpWidget(
      _shell(
        GestureDetector(
          onScaleStart: (_) => events.add('official.start'),
          onScaleUpdate: (_) => events.add('official.update'),
          onScaleEnd: (_) => events.add('official.end'),
          child: _host(transform),
        ),
      ),
    );
    final first = await tester.startGesture(const Offset(80, 100), pointer: 1);
    final second = await tester.startGesture(
      const Offset(120, 100),
      pointer: 2,
    );
    await first.moveTo(const Offset(40, 100));
    await second.moveTo(const Offset(160, 100));
    await first.moveTo(const Offset(30, 100));
    await second.up();
    await first.up();
    await tester.pump(_afterGesture);

    expect(events, containsAllInOrder(['el.start', 'el.update', 'el.end']));
    expect(events.where((event) => event.startsWith('official.')), isEmpty);
  });

  testWidgets('官方 Scale 先获胜后 El 缩放候选失权，继续移动也不复活', (tester) async {
    final events = <String>[];
    final transform = ElTransformGestureRecognizer(
      config: const ElEventConfig(dragStartDistance: 100),
    );
    transform.onScaleStart = (_) => events.add('el.start');
    transform.onScaleUpdate = (_) => events.add('el.update');
    transform.onScaleEnd = (_) => events.add('el.end');
    transform.onScaleCancel = (_) => events.add('el.cancel');
    addTearDown(transform.dispose);
    await tester.pumpWidget(
      _shell(
        _host(
          transform,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => events.add('official.start'),
            onScaleUpdate: (_) => events.add('official.update'),
            onScaleEnd: (_) => events.add('official.end'),
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    final first = await tester.startGesture(const Offset(80, 100), pointer: 1);
    final second = await tester.startGesture(
      const Offset(120, 100),
      pointer: 2,
    );
    await first.moveTo(const Offset(40, 100));
    await second.moveTo(const Offset(160, 100));
    await first.moveTo(const Offset(5, 100));
    await second.moveTo(const Offset(195, 100));
    await second.up();
    await first.up();
    await tester.pump(_afterGesture);

    expect(
      events,
      containsAllInOrder(['official.start', 'official.update', 'official.end']),
    );
    // Scale 没有对外 Down 候选通知，尚未开始的候选失权不制造取消生命周期。
    expect(events.where((event) => event.startsWith('el.')), isEmpty);
  });

  testWidgets('冒泡分别换算变换后子节点与父节点的本地坐标', (tester) async {
    final parentKey = GlobalKey();
    final childKey = GlobalKey();
    final positions = <String, Offset>{};
    final parent = ElPressGestureRecognizer(
      globalToLocal: (global) => _local(parentKey, global),
    )..onTap = (event) => positions['parent'] = event.localPosition;
    final child = ElPressGestureRecognizer(
      parent: parent,
      globalToLocal: (global) => _local(childKey, global),
    )..onTap = (event) => positions['child'] = event.localPosition;
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      _shell(
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 30),
          child: _host(
            parent,
            key: parentKey,
            child: Padding(
              padding: const EdgeInsets.only(left: 40, top: 50),
              child: Transform.scale(
                scale: 2,
                alignment: Alignment.topLeft,
                child: _host(child, key: childKey),
              ),
            ),
          ),
        ),
      ),
    );
    final childBox = childKey.currentContext!.findRenderObject()! as RenderBox;
    final global = childBox.localToGlobal(const Offset(10, 15));
    await tester.tapAt(global);
    await tester.pump(_afterGesture);

    expect(positions['child'], const Offset(10, 15));
    expect(positions['parent'], const Offset(60, 80));
  });

  testWidgets('委托父在官方子获胜时只收到一次取消，并使用父本地坐标', (tester) async {
    final parentKey = GlobalKey();
    final childKey = GlobalKey();
    final events = <String>[];
    final cancelPositions = <String, Offset>{};
    final parent =
        _press(
            events,
            'parent',
            globalToLocal: (global) => _local(parentKey, global),
          )
          ..onTapCancel = (event) {
            events.add('parent.cancel');
            cancelPositions['parent'] = event.localPosition;
          };
    final child =
        _press(
            events,
            'child',
            parent: parent,
            globalToLocal: (global) => _local(childKey, global),
          )
          ..onTapCancel = (event) {
            events.add('child.cancel');
            cancelPositions['child'] = event.localPosition;
          };
    addTearDown(parent.dispose);
    addTearDown(child.dispose);
    await tester.pumpWidget(
      _shell(
        _host(
          parent,
          key: parentKey,
          child: Padding(
            padding: const EdgeInsets.only(left: 40, top: 50),
            child: _host(
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
    await tester.pump(_afterGesture);

    expect(events.where((event) => event.endsWith('.cancel')), [
      'child.cancel',
      'parent.cancel',
    ]);
    expect(events.where((event) => event.endsWith('.up')), isEmpty);
    expect(events.where((event) => event.endsWith('.tap')), ['official.tap']);
    expect(cancelPositions['child'], const Offset(10, 15));
    expect(cancelPositions['parent'], const Offset(50, 65));
  });
}
