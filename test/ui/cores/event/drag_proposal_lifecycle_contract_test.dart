import 'package:flutter_base/src/ui/cores/event/index.dart';
import 'package:flutter_base/src/ui/cores/event/dispatcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  group('DragStart 路线 生命周期', () {
    testWidgets('配置移除同步向旧 handler 补唯一 DragCancel', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childPhases = <ElEventPhase>[];
      _installBubblingPair(host, childPhases: childPhases);

      final move = _move(
        pointer: 1,
        position: const Offset(5, 0),
        delta: const Offset(5, 0),
      );
      await host.dispatch(_down(pointer: 1));
      await host.dispatch(move);
      expect(childPhases, <ElEventPhase>[ElEventPhase.dragStart]);

      host.leafDispatcher.event = null;
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);

      await host.dispatch(_up(pointer: 1, position: move.position));
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
    });

    testWidgets('cancelAllPending 同步取消 proposal，后续 Up 不得再发 End', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childPhases = <ElEventPhase>[];
      _installBubblingPair(host, childPhases: childPhases);

      final move = _move(
        pointer: 2,
        position: const Offset(5, 0),
        delta: const Offset(5, 0),
      );
      await host.dispatch(_down(pointer: 2));
      await host.dispatch(move);
      host.leafDispatcher.cancelAllPending(move);
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);

      await host.dispatch(_up(pointer: 2, position: move.position));
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
    });

    for (final lifecycle in <String>['detach', 'dispose']) {
      testWidgets('$lifecycle 同步取消 proposal 且只产生一个终态', (_) async {
        final host = DispatcherTestHost.chain(depth: 2);
        addTearDown(host.dispose);
        final childPhases = <ElEventPhase>[];
        _installBubblingPair(host, childPhases: childPhases);

        await host.dispatch(_down(pointer: 3));
        await host.dispatch(
          _move(
            pointer: 3,
            position: const Offset(5, 0),
            delta: const Offset(5, 0),
          ),
        );
        if (lifecycle == 'detach') {
          host.leafDispatcher.detach();
        } else {
          host.leafDispatcher.dispose();
        }
        expect(childPhases, <ElEventPhase>[
          ElEventPhase.dragStart,
          ElEventPhase.dragCancel,
        ]);

        await host.dispatch(_up(pointer: 3, position: const Offset(5, 0)));
        expect(childPhases, <ElEventPhase>[
          ElEventPhase.dragStart,
          ElEventPhase.dragCancel,
        ]);
      });
    }

    testWidgets('移除前的 PointerCancel 结清路线，Removed 不重复结清', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childPhases = <ElEventPhase>[];
      final ancestorPhases = <ElEventPhase>[];
      _installBubblingPair(
        host,
        childPhases: childPhases,
        ancestorPhases: ancestorPhases,
      );

      await host.dispatch(_down(pointer: 4, device: 404));
      await host.dispatch(
        _move(
          pointer: 4,
          device: 404,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      await host.dispatch(
        _cancel(pointer: 4, device: 404, position: const Offset(5, 0)),
      );
      GestureBinding.instance.pointerRouter.route(
        const PointerRemovedEvent(
          pointer: 4,
          device: 404,
          kind: PointerDeviceKind.touch,
          position: Offset(5, 0),
        ),
      );

      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(ancestorPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
    });
  });

  group('DragStart 路线 路由终态', () {
    testWidgets('一指 PointerCancel 后仍有指针继续时只在最终 Up 发 End', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final phases = <ElEventPhase>[];
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(3),
        onDragStart: (event) => phases.add(event.phase),
        onDragUpdate: (_) {},
        onDragEnd: (event) => phases.add(event.phase),
        onDragCancel: (event) => phases.add(event.phase),
      );

      await host.dispatch(_down(pointer: 5, position: Offset.zero));
      await host.dispatch(
        _move(
          pointer: 5,
          position: const Offset(4, 0),
          delta: const Offset(4, 0),
        ),
      );
      await host.dispatch(
        _down(pointer: 6, position: const Offset(100, 0), millis: 20),
      );
      await host.dispatch(
        _move(
          pointer: 6,
          position: const Offset(110, 0),
          delta: const Offset(10, 0),
          millis: 32,
        ),
      );
      await host.dispatch(
        _cancel(pointer: 6, position: const Offset(110, 0), millis: 48),
      );
      expect(
        phases.where(_isDragTerminal),
        isEmpty,
        reason: '还有一指继续时不得提前结清整次 Drag。',
      );

      await host.dispatch(
        _move(
          pointer: 5,
          position: const Offset(12, 0),
          delta: const Offset(8, 0),
          millis: 64,
        ),
      );
      await host.dispatch(
        _up(pointer: 5, position: const Offset(12, 0), millis: 80),
      );
      expect(phases.where(_isDragTerminal), <ElEventPhase>[
        ElEventPhase.dragEnd,
      ]);
    });

    testWidgets('终态 stopPropagation 不得吞掉已收到 Start 成员的唯一终态', (_) async {
      final host = DispatcherTestHost.chain(depth: 3);
      addTearDown(host.dispose);
      final starts = <int>[];
      final ends = <int>[];
      for (var index = 0; index < host.dispatchers.length; index++) {
        host.dispatchers[index].event = ElEvent(
          config: _dragConfig(0),
          onDragStart: (_) => starts.add(index),
          onDragEnd: (event) {
            ends.add(index);
            if (index == 2) event.stopPropagation();
          },
        );
      }

      await host.dispatch(_down(pointer: 7));
      await host.dispatch(
        _move(
          pointer: 7,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      await host.dispatch(_up(pointer: 7, position: const Offset(5, 0)));

      expect(starts, <int>[2, 1, 0]);
      expect(ends, <int>[
        2,
        1,
        0,
      ], reason: 'Start 已公开后，每个成员都必须独立结清，终态 stop 不能制造悬空生命周期。');
    });

    testWidgets('不同轴向独立识别，free child 不继承祖先的 vertical 轴', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childEvents = <(ElEventPhase, Axis?)>[];
      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onVerticalDragStart: (_) {},
        onVerticalDragEnd: (_) {},
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (event) => childEvents.add((event.phase, event.dragAxis)),
        onDragEnd: (event) => childEvents.add((event.phase, event.dragAxis)),
      );

      await host.dispatch(_down(pointer: 8));
      await host.dispatch(
        _move(
          pointer: 8,
          position: const Offset(0, 5),
          delta: const Offset(0, 5),
        ),
      );
      await host.dispatch(_up(pointer: 8, position: const Offset(0, 5)));

      expect(childEvents, <(ElEventPhase, Axis?)>[
        (ElEventPhase.dragStart, null),
        (ElEventPhase.dragEnd, null),
      ]);
    });

    for (final ancestorHasStart in <bool>[true, false]) {
      testWidgets(
        '祖先 Drag 已接受后，后发的不同轴 child.stop 不得重新接管：start=$ancestorHasStart',
        (_) async {
          final host = DispatcherTestHost.chain(depth: 2);
          addTearDown(host.dispose);
          var ancestorStarts = 0;
          var childStarts = 0;
          var ancestorEnds = 0;
          final cancelOffsets = <Offset>[];
          host.rootDispatcher.event = ElEvent(
            config: _dragConfig(3),
            onDragStart: ancestorHasStart ? (_) => ancestorStarts++ : null,
            onDragCancel: (event) => cancelOffsets.add(event.dragOffset),
            onDragEnd: (_) => ancestorEnds++,
          );
          host.leafDispatcher.event = ElEvent(
            config: _dragConfig(0),
            onVerticalDragStart: (event) {
              childStarts++;
              event.stopPropagation();
            },
          );

          await host.dispatch(_down(pointer: 9));
          await host.dispatch(
            _move(
              pointer: 9,
              position: const Offset(10, 0),
              delta: const Offset(10, 0),
            ),
          );
          await host.dispatch(
            _move(
              pointer: 9,
              position: const Offset(18, 0),
              delta: const Offset(8, 0),
              millis: 32,
            ),
          );
          await host.dispatch(
            _move(
              pointer: 9,
              position: const Offset(18, 25),
              delta: const Offset(0, 25),
              millis: 48,
            ),
          );

          expect(ancestorStarts, ancestorHasStart ? 1 : 0);
          expect(cancelOffsets, isEmpty);
          expect(childStarts, 0);
          await host.dispatch(
            _up(pointer: 9, position: const Offset(18, 25), millis: 64),
          );
          expect(cancelOffsets, isEmpty);
          expect(ancestorEnds, 1);
        },
      );
    }

    for (final firstTerminal in <String>['Up', 'Cancel', 'PointerRemoved']) {
      testWidgets('兄弟独立路线分别向共同祖先配对 Start 与终态：$firstTerminal', (_) async {
        final host = _SiblingDispatcherTestHost();
        addTearDown(host.dispose);
        final childAPhases = <ElEventPhase>[];
        final ancestorPhases = <ElEventPhase>[];
        var ancestorUpdates = 0;
        host.rootDispatcher.event = ElEvent(
          config: _dragConfig(0),
          onDragStart: (event) => ancestorPhases.add(event.phase),
          onDragUpdate: (_) => ancestorUpdates++,
          onDragEnd: (event) => ancestorPhases.add(event.phase),
          onDragCancel: (event) => ancestorPhases.add(event.phase),
        );
        host.childADispatcher.event = ElEvent(
          config: _dragConfig(0),
          onDragStart: (event) => childAPhases.add(event.phase),
          onDragEnd: (event) => childAPhases.add(event.phase),
          onDragCancel: (event) => childAPhases.add(event.phase),
        );
        host.childBDispatcher.event = ElEvent(onPointerDown: (_) {});

        await host.dispatchA(
          _down(pointer: 21, device: 421, position: const Offset(50, 50)),
        );
        await host.dispatchA(
          _move(
            pointer: 21,
            device: 421,
            position: const Offset(55, 50),
            delta: const Offset(5, 0),
          ),
        );
        expect(childAPhases, <ElEventPhase>[ElEventPhase.dragStart]);
        expect(ancestorPhases, <ElEventPhase>[ElEventPhase.dragStart]);

        await host.dispatchB(
          _down(
            pointer: 22,
            device: 422,
            position: const Offset(150, 50),
            millis: 20,
          ),
        );
        await host.dispatchB(
          _move(
            pointer: 22,
            device: 422,
            position: const Offset(160, 50),
            delta: const Offset(10, 0),
            millis: 32,
          ),
        );
        expect(ancestorPhases, [
          ElEventPhase.dragStart,
          ElEventPhase.dragStart,
        ]);

        if (firstTerminal == 'Up') {
          await host.dispatchA(
            _up(
              pointer: 21,
              device: 421,
              position: const Offset(55, 50),
              millis: 48,
            ),
          );
        } else if (firstTerminal == 'Cancel') {
          await host.dispatchA(
            _cancel(
              pointer: 21,
              device: 421,
              position: const Offset(55, 50),
              millis: 48,
            ),
          );
        } else {
          host.remove(
            const PointerRemovedEvent(
              pointer: 21,
              device: 421,
              kind: PointerDeviceKind.touch,
              position: Offset(55, 50),
              timeStamp: Duration(milliseconds: 48),
            ),
          );
        }

        final expectedATerminal = firstTerminal == 'Up'
            ? ElEventPhase.dragEnd
            : ElEventPhase.dragCancel;
        expect(childAPhases, <ElEventPhase>[
          ElEventPhase.dragStart,
          expectedATerminal,
        ]);
        expect(ancestorPhases, <ElEventPhase>[
          ElEventPhase.dragStart,
          ElEventPhase.dragStart,
          expectedATerminal,
        ], reason: '共同祖先分别结清 A 的路线，B 的路线仍可继续。');

        await host.dispatchB(
          _move(
            pointer: 22,
            device: 422,
            position: const Offset(170, 50),
            delta: const Offset(10, 0),
            millis: 64,
          ),
        );
        await host.dispatchB(
          _up(
            pointer: 22,
            device: 422,
            position: const Offset(170, 50),
            millis: 80,
          ),
        );
        expect(childAPhases, <ElEventPhase>[
          ElEventPhase.dragStart,
          expectedATerminal,
        ]);
        expect(ancestorPhases, <ElEventPhase>[
          ElEventPhase.dragStart,
          ElEventPhase.dragStart,
          expectedATerminal,
          ElEventPhase.dragEnd,
        ]);
        expect(ancestorUpdates, 1);
      });
    }
  });

  group('DragStart 路线 失权', () {
    testWidgets('ancestor eagerGesture 返回前同步取消 child proposal', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childPhases = <ElEventPhase>[];
      var eagerReturned = false;
      bool? cancelObservedEagerReturned;
      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (event) {
          event.eagerGesture();
          eagerReturned = true;
        },
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (event) => childPhases.add(event.phase),
        onDragCancel: (event) {
          childPhases.add(event.phase);
          cancelObservedEagerReturned = eagerReturned;
        },
      );

      await host.dispatch(_down(pointer: 10));
      await host.dispatch(
        _move(
          pointer: 10,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );

      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(
        cancelObservedEagerReturned,
        isFalse,
        reason: 'loser terminal 必须在 eagerGesture 调用返回前同步完成。',
      );
    });

    testWidgets('双指 Scale Start 前同步取消 child proposal', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final trace = <String>[];
      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) {},
        onDragCancel: (_) {},
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) => trace.add('dragStart'),
        onDragCancel: (_) => trace.add('dragCancel'),
        onScaleStart: (_) => trace.add('scaleStart'),
        onScaleUpdate: (_) {},
      );

      await host.dispatch(_down(pointer: 11, position: const Offset(70, 100)));
      await host.dispatch(
        _move(
          pointer: 11,
          position: const Offset(75, 100),
          delta: const Offset(5, 0),
        ),
      );
      expect(trace, <String>['dragStart']);

      await host.dispatch(
        _down(pointer: 12, position: const Offset(130, 100), millis: 20),
      );
      await host.dispatch(
        _move(
          pointer: 12,
          position: const Offset(170, 100),
          delta: const Offset(40, 0),
          millis: 32,
        ),
      );

      expect(trace, <String>['dragStart', 'dragCancel', 'scaleStart']);
    });

    testWidgets('Scale takeover 重入中止仍完整结清全部 proposal', (_) async {
      final host = DispatcherTestHost.chain(depth: 3);
      addTearDown(host.dispose);
      final starts = List<int>.filled(3, 0);
      final cancels = List<int>.filled(3, 0);
      final ends = List<int>.filled(3, 0);
      var scaleStarts = 0;
      final scaleHost = host.leafDispatcher;

      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) => starts[0]++,
        onDragEnd: (_) => ends[0]++,
        onDragCancel: (_) => cancels[0]++,
      );
      host.dispatchers[1].event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) => starts[1]++,
        onDragEnd: (_) => ends[1]++,
        onDragCancel: (_) {
          cancels[1]++;
          scaleHost.event = ElEvent(onTap: (_) {});
        },
      );
      scaleHost.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) => starts[2]++,
        onDragEnd: (_) => ends[2]++,
        onDragCancel: (_) => cancels[2]++,
        onScaleStart: (_) => scaleStarts++,
        onScaleUpdate: (_) {},
      );

      await host.dispatch(_down(pointer: 13, position: const Offset(70, 100)));
      await host.dispatch(
        _move(
          pointer: 13,
          position: const Offset(75, 100),
          delta: const Offset(5, 0),
        ),
      );
      expect(starts, <int>[1, 1, 1]);

      await host.dispatch(
        _down(pointer: 14, position: const Offset(130, 100), millis: 20),
      );
      await host.dispatch(
        _move(
          pointer: 14,
          position: const Offset(170, 100),
          delta: const Offset(40, 0),
          millis: 32,
        ),
      );

      expect(cancels, <int>[
        1,
        1,
        1,
      ], reason: 'loser 回调重接 Scale host 只能中止 ScaleStart，不能中止既有 Start 的终态结算。');
      expect(ends, <int>[0, 0, 0]);
      expect(scaleStarts, 0);

      await host.dispatch(
        _up(pointer: 14, position: const Offset(170, 100), millis: 48),
      );
      await host.dispatch(
        _up(pointer: 13, position: const Offset(75, 100), millis: 64),
      );
      expect(cancels, <int>[1, 1, 1]);
      expect(ends, <int>[
        0,
        0,
        0,
      ], reason: 'Scale takeover 已用 Cancel 结清，后续 Up 不得再补第二终态。');
      expect(scaleStarts, 0);
    });
  });

  group('DragStart 路线 配置替换', () {
    testWidgets('free proposal 外部替换为 vertical shape 时同步取消旧 handler', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final oldPhases = <ElEventPhase>[];
      final newPhases = <ElEventPhase>[];
      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) {},
        onDragEnd: (_) {},
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (event) => oldPhases.add(event.phase),
        onDragEnd: (event) => oldPhases.add(event.phase),
        onDragCancel: (event) => oldPhases.add(event.phase),
      );

      await host.dispatch(_down(pointer: 31));
      await host.dispatch(
        _move(
          pointer: 31,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      expect(oldPhases, <ElEventPhase>[ElEventPhase.dragStart]);

      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onVerticalDragStart: (event) => newPhases.add(event.phase),
        onVerticalDragEnd: (event) => newPhases.add(event.phase),
        onVerticalDragCancel: (event) => newPhases.add(event.phase),
      );
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(newPhases, isEmpty);

      await host.dispatch(_up(pointer: 31, position: const Offset(5, 0)));
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(
        newPhases,
        isEmpty,
        reason: 'actual axis 为 null 的旧 free Start 不能由 vertical-only 新配置承接。',
      );
    });

    testWidgets('移除 Start 属于声明结构变化，即使保留 End+Cancel 也结清旧路线', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final oldPhases = <ElEventPhase>[];
      final newPhases = <ElEventPhase>[];
      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) {},
        onDragEnd: (_) {},
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (event) => oldPhases.add(event.phase),
        onDragEnd: (event) => oldPhases.add(event.phase),
        onDragCancel: (event) => oldPhases.add(event.phase),
      );

      await host.dispatch(_down(pointer: 32));
      await host.dispatch(
        _move(
          pointer: 32,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragEnd: (event) => newPhases.add(event.phase),
        onDragCancel: (event) => newPhases.add(event.phase),
      );
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(newPhases, isEmpty);

      await host.dispatch(_up(pointer: 32, position: const Offset(5, 0)));
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(newPhases, isEmpty);
    });

    testWidgets('free proposal 替换为 generic End-only 时当场取消旧 handler', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final oldPhases = <ElEventPhase>[];
      final newPhases = <ElEventPhase>[];
      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) {},
        onDragEnd: (_) {},
        onDragCancel: (_) {},
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (event) => oldPhases.add(event.phase),
        onDragEnd: (event) => oldPhases.add(event.phase),
        onDragCancel: (event) => oldPhases.add(event.phase),
      );

      await host.dispatch(_down(pointer: 33));
      await host.dispatch(
        _move(
          pointer: 33,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragEnd: (event) => newPhases.add(event.phase),
      );
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(newPhases, isEmpty);

      await host.dispatch(_cancel(pointer: 33, position: const Offset(5, 0)));
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(
        newPhases,
        isEmpty,
        reason: 'End-only 无法承接 PointerCancel，替换时已由旧 handler 唯一结清。',
      );
    });

    testWidgets('free proposal 替换为 generic Update-only 时当场取消旧 handler', (
      _,
    ) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final oldPhases = <ElEventPhase>[];
      final newPhases = <ElEventPhase>[];
      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (_) {},
        onDragEnd: (_) {},
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragStart: (event) => oldPhases.add(event.phase),
        onDragEnd: (event) => oldPhases.add(event.phase),
        onDragCancel: (event) => oldPhases.add(event.phase),
      );

      await host.dispatch(_down(pointer: 34));
      await host.dispatch(
        _move(
          pointer: 34,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onDragUpdate: (event) => newPhases.add(event.phase),
      );
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(newPhases, isEmpty);

      await host.dispatch(_up(pointer: 34, position: const Offset(5, 0)));
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(
        newPhases,
        isEmpty,
        reason: 'Update-only 没有完整 terminal shape，Up 不得向新配置补终态。',
      );
    });
  });
}

void _installBubblingPair(
  DispatcherTestHost host, {
  required List<ElEventPhase> childPhases,
  List<ElEventPhase>? ancestorPhases,
}) {
  host.rootDispatcher.event = ElEvent(
    config: _dragConfig(0),
    onDragStart: (event) => ancestorPhases?.add(event.phase),
    onDragEnd: (event) => ancestorPhases?.add(event.phase),
    onDragCancel: (event) => ancestorPhases?.add(event.phase),
  );
  host.leafDispatcher.event = ElEvent(
    config: _dragConfig(0),
    onDragStart: (event) => childPhases.add(event.phase),
    onDragEnd: (event) => childPhases.add(event.phase),
    onDragCancel: (event) => childPhases.add(event.phase),
  );
}

ElEventConfig _dragConfig(double distance) => ElEventConfig(
  dragStartDistance: distance,

);

bool _isDragTerminal(ElEventPhase phase) =>
    phase == ElEventPhase.dragEnd || phase == ElEventPhase.dragCancel;

PointerDownEvent _down({
  required int pointer,
  Offset position = Offset.zero,
  int device = 0,
  int millis = 0,
}) => PointerDownEvent(
  pointer: pointer,
  device: device,
  position: position,
  kind: PointerDeviceKind.touch,
  timeStamp: Duration(milliseconds: millis),
);

PointerMoveEvent _move({
  required int pointer,
  required Offset position,
  required Offset delta,
  int device = 0,
  int millis = 16,
}) => PointerMoveEvent(
  pointer: pointer,
  device: device,
  position: position,
  delta: delta,
  kind: PointerDeviceKind.touch,
  timeStamp: Duration(milliseconds: millis),
);

PointerUpEvent _up({
  required int pointer,
  required Offset position,
  int device = 0,
  int millis = 32,
}) => PointerUpEvent(
  pointer: pointer,
  device: device,
  position: position,
  kind: PointerDeviceKind.touch,
  timeStamp: Duration(milliseconds: millis),
);

PointerCancelEvent _cancel({
  required int pointer,
  required Offset position,
  int device = 0,
  int millis = 32,
}) => PointerCancelEvent(
  pointer: pointer,
  device: device,
  position: position,
  kind: PointerDeviceKind.touch,
  timeStamp: Duration(milliseconds: millis),
);

final class _SiblingDispatcherTestHost {
  _SiblingDispatcherTestHost()
    : _pipelineOwner = PipelineOwner(),
      root = RenderFlex(
        direction: Axis.horizontal,
        textDirection: TextDirection.ltr,
      ),
      childA = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 100,
          height: 100,
        ),
      ),
      childB = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 100,
          height: 100,
        ),
      ) {
    root.addAll(<RenderBox>[childA, childB]);
    _pipelineOwner.rootNode = root;
    root.layout(const BoxConstraints.tightFor(width: 200, height: 100));
    rootDispatcher = ElEventDispatcher(root);
    childADispatcher = ElEventDispatcher(childA);
    childBDispatcher = ElEventDispatcher(childB);
  }

  final PipelineOwner _pipelineOwner;
  final RenderFlex root;
  final RenderBox childA;
  final RenderBox childB;
  late final ElEventDispatcher rootDispatcher;
  late final ElEventDispatcher childADispatcher;
  late final ElEventDispatcher childBDispatcher;

  Future<void> dispatchA(PointerEvent event) async =>
      _dispatch(childADispatcher, childA, event);

  Future<void> dispatchB(PointerEvent event) async =>
      _dispatch(childBDispatcher, childB, event);

  void remove(PointerRemovedEvent event) {
    _dispatch(
      childADispatcher,
      childA,
      PointerCancelEvent(
        pointer: event.pointer,
        device: event.device,
        kind: event.kind,
        position: event.position,
        timeStamp: event.timeStamp,
      ),
    );
    GestureBinding.instance.pointerRouter.route(event);
  }

  void _dispatch(ElEventDispatcher leaf, RenderBox box, PointerEvent event) {
    leaf.handleEvent(
      event,
      BoxHitTestEntry(box, box.globalToLocal(event.position)),
    );
    rootDispatcher.handleEvent(event, BoxHitTestEntry(root, event.position));
    GestureBinding.instance.pointerRouter.route(event);
    if (event is PointerDownEvent) {
      GestureBinding.instance.gestureArena.close(event.pointer);
    } else if (event is PointerUpEvent) {
      GestureBinding.instance.gestureArena.sweep(event.pointer);
    }
  }

  void dispose() {
    childBDispatcher.dispose();
    childADispatcher.dispose();
    rootDispatcher.dispose();
    _pipelineOwner.rootNode = null;
  }
}
