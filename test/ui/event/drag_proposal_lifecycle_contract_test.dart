import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  group('DragStart proposal 生命周期', () {
    testWidgets('配置移除同步向旧 handler 补唯一 DragCancel', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childPhases = <ElEventPhase>[];
      _installProposalPair(host, childPhases: childPhases);

      final move = _move(
        pointer: 1,
        position: const Offset(5, 0),
        delta: const Offset(5, 0),
      );
      host.dispatch(_down(pointer: 1));
      host.dispatch(move);
      expect(childPhases, <ElEventPhase>[ElEventPhase.dragStart]);

      host.leafDispatcher.event = null;
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);

      host.dispatch(_up(pointer: 1, position: move.position));
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
    });

    testWidgets('cancelAllPending 同步取消 proposal，后续 Up 不得再发 End', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childPhases = <ElEventPhase>[];
      _installProposalPair(host, childPhases: childPhases);

      final move = _move(
        pointer: 2,
        position: const Offset(5, 0),
        delta: const Offset(5, 0),
      );
      host.dispatch(_down(pointer: 2));
      host.dispatch(move);
      host.leafDispatcher.cancelAllPending(move);
      expect(childPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);

      host.dispatch(_up(pointer: 2, position: move.position));
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
        _installProposalPair(host, childPhases: childPhases);

        host.dispatch(_down(pointer: 3));
        host.dispatch(
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

        host.dispatch(_up(pointer: 3, position: const Offset(5, 0)));
        expect(childPhases, <ElEventPhase>[
          ElEventPhase.dragStart,
          ElEventPhase.dragCancel,
        ]);
      });
    }

    testWidgets('PointerRemoved 同步取消 active 与 proposal Start', (_) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childPhases = <ElEventPhase>[];
      final ancestorPhases = <ElEventPhase>[];
      _installProposalPair(
        host,
        childPhases: childPhases,
        ancestorPhases: ancestorPhases,
      );

      host.dispatch(_down(pointer: 4, device: 404));
      host.dispatch(
        _move(
          pointer: 4,
          device: 404,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
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

  group('DragStart proposal 路由终态', () {
    testWidgets('一指 PointerCancel 后仍有指针继续时只在最终 Up 发 End', (_) async {
      final host = DispatcherTestHost.chain();
      addTearDown(host.dispose);
      final phases = <ElEventPhase>[];
      host.leafDispatcher
        ..multitouchDragStrategy = MultitouchDragStrategy.latestPointer
        ..event = ElEvent(
          config: _dragConfig(3),
          onDragStart: (event) => phases.add(event.phase),
          onDragUpdate: (_) {},
          onDragEnd: (event) => phases.add(event.phase),
          onDragCancel: (event) => phases.add(event.phase),
        );

      host.dispatch(_down(pointer: 5, position: Offset.zero));
      host.dispatch(
        _move(
          pointer: 5,
          position: const Offset(4, 0),
          delta: const Offset(4, 0),
        ),
      );
      host.dispatch(
        _down(pointer: 6, position: const Offset(100, 0), millis: 20),
      );
      host.dispatch(
        _move(
          pointer: 6,
          position: const Offset(110, 0),
          delta: const Offset(10, 0),
          millis: 32,
        ),
      );
      host.dispatch(
        _cancel(pointer: 6, position: const Offset(110, 0), millis: 48),
      );
      expect(
        phases.where(_isDragTerminal),
        isEmpty,
        reason: '还有一指继续时不得提前结清整次 Drag。',
      );

      host.dispatch(
        _move(
          pointer: 5,
          position: const Offset(12, 0),
          delta: const Offset(8, 0),
          millis: 64,
        ),
      );
      host.dispatch(_up(pointer: 5, position: const Offset(12, 0), millis: 80));
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
          config: _dragConfig(index == 0 ? 0 : 20),
          onDragStart: (_) => starts.add(index),
          onDragEnd: (event) {
            ends.add(index);
            if (index == 2) event.stopPropagation();
          },
        );
      }

      host.dispatch(_down(pointer: 7));
      host.dispatch(
        _move(
          pointer: 7,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      host.dispatch(_up(pointer: 7, position: const Offset(5, 0)));

      expect(starts, <int>[2, 1, 0]);
      expect(ends, <int>[
        2,
        1,
        0,
      ], reason: 'Start 已公开后，每个成员都必须独立结清，终态 stop 不能制造悬空生命周期。');
    });

    testWidgets('generic child 继承 vertical ancestor proposal 的轴并保持到 End', (
      _,
    ) async {
      final host = DispatcherTestHost.chain(depth: 2);
      addTearDown(host.dispose);
      final childEvents = <(ElEventPhase, Axis?)>[];
      host.rootDispatcher.event = ElEvent(
        config: _dragConfig(0),
        onVerticalDragStart: (_) {},
        onVerticalDragEnd: (_) {},
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(20),
        onDragStart: (event) => childEvents.add((event.phase, event.dragAxis)),
        onDragEnd: (event) => childEvents.add((event.phase, event.dragAxis)),
      );

      host.dispatch(_down(pointer: 8));
      host.dispatch(
        _move(
          pointer: 8,
          position: const Offset(0, 5),
          delta: const Offset(0, 5),
        ),
      );
      host.dispatch(_up(pointer: 8, position: const Offset(0, 5)));

      expect(childEvents, <(ElEventPhase, Axis?)>[
        (ElEventPhase.dragStart, Axis.vertical),
        (ElEventPhase.dragEnd, Axis.vertical),
      ]);
    });

    for (final ancestorHasStart in <bool>[true, false]) {
      testWidgets(
        '后发 child.stop 截断${ancestorHasStart ? '已公开' : '仅有 Cancel handler 的'} ancestor 并保留真实偏移',
        (_) async {
          final host = DispatcherTestHost.chain(depth: 2);
          addTearDown(host.dispose);
          var ancestorStarts = 0;
          final cancelOffsets = <Offset>[];
          host.rootDispatcher.event = ElEvent(
            config: _dragConfig(3),
            onDragStart: ancestorHasStart ? (_) => ancestorStarts++ : null,
            onDragCancel: (event) => cancelOffsets.add(event.dragOffset),
          );
          host.leafDispatcher.event = ElEvent(
            config: _dragConfig(20),
            onVerticalDragStart: (event) => event.stopPropagation(),
          );

          host.dispatch(_down(pointer: 9));
          host.dispatch(
            _move(
              pointer: 9,
              position: const Offset(10, 0),
              delta: const Offset(10, 0),
            ),
          );
          host.dispatch(
            _move(
              pointer: 9,
              position: const Offset(18, 0),
              delta: const Offset(8, 0),
              millis: 32,
            ),
          );
          host.dispatch(
            _move(
              pointer: 9,
              position: const Offset(18, 25),
              delta: const Offset(0, 25),
              millis: 48,
            ),
          );

          expect(ancestorStarts, ancestorHasStart ? 1 : 0);
          expect(cancelOffsets, <Offset>[const Offset(8, 0)]);
          host.dispatch(
            _up(pointer: 9, position: const Offset(18, 25), millis: 64),
          );
          expect(cancelOffsets, <Offset>[
            const Offset(8, 0),
          ], reason: '截断时已结清，Up 不得重复产生第二个终态。');
        },
      );
    }

    for (final firstTerminal in <String>['Up', 'Cancel', 'PointerRemoved']) {
      testWidgets(
        'sibling 多指 Drag：pointer1 $firstTerminal 只结清 A，ancestor 等待 pointer2',
        (_) async {
          final host = _SiblingDispatcherTestHost();
          addTearDown(host.dispose);
          final childAPhases = <ElEventPhase>[];
          final ancestorPhases = <ElEventPhase>[];
          var ancestorUpdates = 0;
          host.rootDispatcher
            ..multitouchDragStrategy = MultitouchDragStrategy.latestPointer
            ..event = ElEvent(
              config: _dragConfig(0),
              onDragStart: (event) => ancestorPhases.add(event.phase),
              onDragUpdate: (_) => ancestorUpdates++,
              onDragEnd: (event) => ancestorPhases.add(event.phase),
              onDragCancel: (event) => ancestorPhases.add(event.phase),
            );
          host.childADispatcher.event = ElEvent(
            config: _dragConfig(20),
            onDragStart: (event) => childAPhases.add(event.phase),
            onDragEnd: (event) => childAPhases.add(event.phase),
            onDragCancel: (event) => childAPhases.add(event.phase),
          );
          host.childBDispatcher.event = ElEvent(onPointerDown: (_) {});

          host.dispatchA(
            _down(pointer: 21, device: 421, position: const Offset(50, 50)),
          );
          host.dispatchA(
            _move(
              pointer: 21,
              device: 421,
              position: const Offset(55, 50),
              delta: const Offset(5, 0),
            ),
          );
          expect(childAPhases, <ElEventPhase>[ElEventPhase.dragStart]);
          expect(ancestorPhases, <ElEventPhase>[ElEventPhase.dragStart]);

          host.dispatchB(
            _down(
              pointer: 22,
              device: 422,
              position: const Offset(150, 50),
              millis: 20,
            ),
          );
          host.dispatchB(
            _move(
              pointer: 22,
              device: 422,
              position: const Offset(160, 50),
              delta: const Offset(10, 0),
              millis: 32,
            ),
          );
          expect(
            ancestorUpdates,
            1,
            reason: 'latestPointer 下 sibling B 的 pointer2 必须接管共同 ancestor 的更新。',
          );

          if (firstTerminal == 'Up') {
            host.dispatchA(
              _up(
                pointer: 21,
                device: 421,
                position: const Offset(55, 50),
                millis: 48,
              ),
            );
          } else if (firstTerminal == 'Cancel') {
            host.dispatchA(
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
          ], reason: '共同 ancestor 仍由 pointer2 驱动，不能随 A 提前结清。');

          host.dispatchB(
            _move(
              pointer: 22,
              device: 422,
              position: const Offset(170, 50),
              delta: const Offset(10, 0),
              millis: 64,
            ),
          );
          host.dispatchB(
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
            ElEventPhase.dragEnd,
          ]);
        },
      );
    }
  });

  group('DragStart proposal 失权', () {
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
        config: _dragConfig(20),
        onDragStart: (event) => childPhases.add(event.phase),
        onDragCancel: (event) {
          childPhases.add(event.phase);
          cancelObservedEagerReturned = eagerReturned;
        },
      );

      host.dispatch(_down(pointer: 10));
      host.dispatch(
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
        config: _dragConfig(20),
        onDragStart: (_) => trace.add('dragStart'),
        onDragCancel: (_) => trace.add('dragCancel'),
        onScaleStart: (_) => trace.add('scaleStart'),
        onScaleUpdate: (_) {},
      );

      host.dispatch(_down(pointer: 11, position: const Offset(70, 100)));
      host.dispatch(
        _move(
          pointer: 11,
          position: const Offset(75, 100),
          delta: const Offset(5, 0),
        ),
      );
      expect(trace, <String>['dragStart']);

      host.dispatch(
        _down(pointer: 12, position: const Offset(130, 100), millis: 20),
      );
      host.dispatch(
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
        config: _dragConfig(20),
        onDragStart: (_) => starts[1]++,
        onDragEnd: (_) => ends[1]++,
        onDragCancel: (_) {
          cancels[1]++;
          scaleHost.event = ElEvent(onTap: (_) {});
        },
      );
      scaleHost.event = ElEvent(
        config: _dragConfig(20),
        onDragStart: (_) => starts[2]++,
        onDragEnd: (_) => ends[2]++,
        onDragCancel: (_) => cancels[2]++,
        onScaleStart: (_) => scaleStarts++,
        onScaleUpdate: (_) {},
      );

      host.dispatch(_down(pointer: 13, position: const Offset(70, 100)));
      host.dispatch(
        _move(
          pointer: 13,
          position: const Offset(75, 100),
          delta: const Offset(5, 0),
        ),
      );
      expect(starts, <int>[1, 1, 1]);

      host.dispatch(
        _down(pointer: 14, position: const Offset(130, 100), millis: 20),
      );
      host.dispatch(
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

      host.dispatch(
        _up(pointer: 14, position: const Offset(170, 100), millis: 48),
      );
      host.dispatch(
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

  group('DragStart proposal 配置替换', () {
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
        config: _dragConfig(20),
        onDragStart: (event) => oldPhases.add(event.phase),
        onDragEnd: (event) => oldPhases.add(event.phase),
        onDragCancel: (event) => oldPhases.add(event.phase),
      );

      host.dispatch(_down(pointer: 31));
      host.dispatch(
        _move(
          pointer: 31,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      expect(oldPhases, <ElEventPhase>[ElEventPhase.dragStart]);

      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(20),
        onVerticalDragStart: (event) => newPhases.add(event.phase),
        onVerticalDragEnd: (event) => newPhases.add(event.phase),
        onVerticalDragCancel: (event) => newPhases.add(event.phase),
      );
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(newPhases, isEmpty);

      host.dispatch(_up(pointer: 31, position: const Offset(5, 0)));
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

    testWidgets(
      'free proposal 外部替换为 generic End+Cancel 完整 terminal shape 时保持到 Up',
      (_) async {
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
          config: _dragConfig(20),
          onDragStart: (event) => oldPhases.add(event.phase),
          onDragEnd: (event) => oldPhases.add(event.phase),
          onDragCancel: (event) => oldPhases.add(event.phase),
        );

        host.dispatch(_down(pointer: 32));
        host.dispatch(
          _move(
            pointer: 32,
            position: const Offset(5, 0),
            delta: const Offset(5, 0),
          ),
        );
        host.leafDispatcher.event = ElEvent(
          config: _dragConfig(20),
          onDragEnd: (event) => newPhases.add(event.phase),
          onDragCancel: (event) => newPhases.add(event.phase),
        );
        expect(oldPhases, <ElEventPhase>[ElEventPhase.dragStart]);
        expect(newPhases, isEmpty);

        host.dispatch(_up(pointer: 32, position: const Offset(5, 0)));
        expect(oldPhases, <ElEventPhase>[ElEventPhase.dragStart]);
        expect(newPhases, <ElEventPhase>[ElEventPhase.dragEnd]);
      },
    );

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
        config: _dragConfig(20),
        onDragStart: (event) => oldPhases.add(event.phase),
        onDragEnd: (event) => oldPhases.add(event.phase),
        onDragCancel: (event) => oldPhases.add(event.phase),
      );

      host.dispatch(_down(pointer: 33));
      host.dispatch(
        _move(
          pointer: 33,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(20),
        onDragEnd: (event) => newPhases.add(event.phase),
      );
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(newPhases, isEmpty);

      host.dispatch(_cancel(pointer: 33, position: const Offset(5, 0)));
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
        config: _dragConfig(20),
        onDragStart: (event) => oldPhases.add(event.phase),
        onDragEnd: (event) => oldPhases.add(event.phase),
        onDragCancel: (event) => oldPhases.add(event.phase),
      );

      host.dispatch(_down(pointer: 34));
      host.dispatch(
        _move(
          pointer: 34,
          position: const Offset(5, 0),
          delta: const Offset(5, 0),
        ),
      );
      host.leafDispatcher.event = ElEvent(
        config: _dragConfig(20),
        onDragUpdate: (event) => newPhases.add(event.phase),
      );
      expect(oldPhases, <ElEventPhase>[
        ElEventPhase.dragStart,
        ElEventPhase.dragCancel,
      ]);
      expect(newPhases, isEmpty);

      host.dispatch(_up(pointer: 34, position: const Offset(5, 0)));
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

void _installProposalPair(
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
    config: _dragConfig(20),
    onDragStart: (event) => childPhases.add(event.phase),
    onDragEnd: (event) => childPhases.add(event.phase),
    onDragCancel: (event) => childPhases.add(event.phase),
  );
}

ElEventConfig _dragConfig(double distance) => ElEventConfig(
  dragStartDistance: distance,
  dragResampling: const <TargetPlatform>{},
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

  void dispatchA(PointerEvent event) =>
      _dispatch(childADispatcher, childA, event);

  void dispatchB(PointerEvent event) =>
      _dispatch(childBDispatcher, childB, event);

  void remove(PointerRemovedEvent event) =>
      GestureBinding.instance.pointerRouter.route(event);

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
