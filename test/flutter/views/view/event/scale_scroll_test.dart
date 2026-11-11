import 'package:flutter/material.dart';
import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(EventDispatcher.debugReset);
  tearDown(EventDispatcher.debugReset);

  for (final movingFirst in [true, false]) {
    for (final beforeSecondDown in [0.0, 8.0]) {
      testWidgets('双指单边慢缩放优先于真实滚动，移动第${movingFirst ? 1 : 2}指，首指预先移动 $beforeSecondDown px', (tester) async {
        final host = await _pumpHost(tester);
        final firstPosition = tester.getTopLeft(find.byKey(host.stageKey)) + Offset(40, 80);
        final secondPosition = firstPosition + Offset(0, 100);
        final first = await tester.startGesture(firstPosition, pointer: 1);
        if (beforeSecondDown > 0) {
          await _move(tester, first, firstPosition - Offset(0, beforeSecondDown));
        }
        final second = await tester.startGesture(secondPosition, pointer: 2);
        final moving = movingFirst ? first : second;
        final movingOrigin = movingFirst ? firstPosition - Offset(0, beforeSecondDown) : secondPosition;
        final direction = movingFirst ? -1.0 : 1.0;
        expect(host.pointerDowns, 2, reason: '两指都在中央图形外的空白舞台内落下');
        expect(host.scalePhases, isEmpty);
        expect(host.tapCancels, 0);

        // 分别移动旧指和最新触点，避免反向同步移动掩盖外层滚动的接受阈值。
        for (final distance in [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0]) {
          await _move(tester, moving, movingOrigin + Offset(0, direction * distance));
        }
        expect(host.scalePhases, isEmpty, reason: '半跨度变化未超过 18px，不提前公开 ScaleStart');
        expect(host.tapCancels, 0, reason: '等待缩放阈值期间不提前取消自身点击');
        expect(host.controller.offset, closeTo(host.initialScrollOffset, 0.01), reason: '两指慢缩放不能被外层单指滚动抢走');

        await _move(tester, moving, movingOrigin + Offset(0, direction * 40));
        expect(host.scalePhases, [ElEventPhase.scaleStart]);
        expect(host.startPointerCounts, [2]);
        expect(host.tapCancels, 2, reason: '正式缩放开始时才取消两条指针上的点击候选');
        await _move(tester, moving, movingOrigin + Offset(0, direction * 48));
        await _move(tester, moving, movingOrigin + Offset(0, direction * 56));
        expect(host.scales.last, greaterThan(1));
        expect(host.controller.offset, closeTo(host.initialScrollOffset, 0.01));

        await first.up();
        expect(host.scalePhases, isNot(contains(ElEventPhase.scaleEnd)));
        await second.up();
        expect(host.scalePhases, [
          ElEventPhase.scaleStart,
          ElEventPhase.scaleUpdate,
          ElEventPhase.scaleUpdate,
          ElEventPhase.scaleEnd,
        ]);
        await tester.pump(Duration(milliseconds: 120));
      });
    }
  }

  testWidgets('双指未达缩放阈值就离开不伪造生命周期，下一次单指仍能滚动', (tester) async {
    final host = await _pumpHost(tester);
    final origin = tester.getTopLeft(find.byKey(host.stageKey));
    final first = await tester.startGesture(origin + Offset(40, 80), pointer: 1);
    final second = await tester.startGesture(origin + Offset(40, 180), pointer: 2);
    await _move(tester, first, origin + Offset(40, 72));
    expect(host.scalePhases, isEmpty);
    expect(host.tapCancels, 0);
    await first.up();
    await second.up();
    await tester.pump(Duration(milliseconds: 120));
    expect(host.scalePhases, isEmpty, reason: '没有 ScaleStart，就不能补发 ScaleEnd 或 ScaleCancel');
    expect(host.controller.offset, closeTo(host.initialScrollOffset, 0.01));

    final nextPosition = tester.getTopLeft(find.byKey(host.stageKey)) + Offset(40, 220);
    final next = await tester.startGesture(nextPosition, pointer: 3);
    for (final distance in [10.0, 20.0, 30.0, 40.0]) {
      await _move(tester, next, nextPosition - Offset(0, distance));
    }
    expect(host.controller.offset, greaterThan(host.initialScrollOffset));
    expect(host.scalePhases, isEmpty, reason: '新一轮单指滚动不会复活上一轮未开始的缩放');
    await next.up();
    await tester.pump(Duration(milliseconds: 120));
  });

  testWidgets('首指已让外层滚动胜出后再落第二指，不恢复已失权缩放', (tester) async {
    final host = await _pumpHost(tester);
    final origin = tester.getTopLeft(find.byKey(host.stageKey));
    final firstPosition = origin + Offset(40, 220);
    final first = await tester.startGesture(firstPosition, pointer: 1);
    for (final distance in [10.0, 20.0, 30.0, 40.0]) {
      await _move(tester, first, firstPosition - Offset(0, distance));
    }
    expect(host.controller.offset, greaterThan(host.initialScrollOffset), reason: '第二指落下前，单指滚动已经实际发生');
    expect(host.scalePhases, isEmpty);

    final offsetBeforeSecond = host.controller.offset;
    final secondPosition = origin + Offset(40, 100);
    final second = await tester.startGesture(secondPosition, pointer: 2);
    for (final distance in [20.0, 40.0, 60.0]) {
      await _move(tester, second, secondPosition - Offset(0, distance));
    }
    expect(host.controller.offset, greaterThan(offsetBeforeSecond), reason: '新触点继续已成立的滚动');
    expect(host.scalePhases, isEmpty, reason: '第二指不能把已被官方滚动淘汰的第一指重新纳入缩放');
    await first.up();
    await second.up();
    expect(host.scalePhases, isEmpty);
    await tester.pump(Duration(milliseconds: 120));
  });
}

Future<void> _move(WidgetTester tester, TestGesture gesture, Offset position) async {
  await gesture.moveTo(position);
  await tester.pump(Duration(milliseconds: 16));
}

Future<_ScrollScaleHost> _pumpHost(WidgetTester tester) async {
  final host = _ScrollScaleHost();
  addTearDown(() async {
    await tester.pumpWidget(SizedBox.shrink());
    host.controller.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: 320,
          height: 400,
          child: SingleChildScrollView(
            controller: host.controller,
            physics: ClampingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: host.initialScrollOffset),
                ElView(
                  key: host.stageKey,
                  style: .new(width: 320, height: 320, alignment: .center),
                  event: ElEvent(
                    onPointerDown: (_) => host.pointerDowns++,
                    onTap: (_) {},
                    onTapCancel: (_) => host.tapCancels++,
                    onScaleStart: (event) {
                      host.scalePhases.add(event.phase);
                      host.startPointerCounts.add(event.pointerCount);
                    },
                    onScaleUpdate: (event) {
                      host.scalePhases.add(event.phase);
                      host.scales.add(event.scale);
                    },
                    onScaleEnd: (event) => host.scalePhases.add(event.phase),
                    onScaleCancel: (event) => host.scalePhases.add(event.phase),
                  ),
                  child: SizedBox(width: 80, height: 80, child: ColoredBox(color: Colors.blue)),
                ),
                SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  expect(tester.getSize(find.byKey(host.stageKey)), Size(320, 320));
  expect(host.controller.offset, host.initialScrollOffset);
  return host;
}

class _ScrollScaleHost {
  final initialScrollOffset = 160.0;
  late final controller = ScrollController(initialScrollOffset: initialScrollOffset);
  final stageKey = ValueKey('scale-scroll-stage');
  final scalePhases = <ElEventPhase>[];
  final startPointerCounts = <int>[];
  final scales = <double>[];
  var pointerDowns = 0;
  var tapCancels = 0;
}
