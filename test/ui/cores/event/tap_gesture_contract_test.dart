import 'package:flutter/gestures.dart';
import 'package:flutter_base/src/ui/cores/event/dispatcher.dart';
import 'package:flutter_base/src/ui/cores/event/index.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dispatcher_test_host.dart';

void main() {
  setUp(ElEventDispatcher.debugResetEagerGestureOwners);

  testWidgets('主键点击立即依次发送 tapDown、tapUp、tap', (_) async {
    final host = DispatcherTestHost.chain();
    try {
      final phases = <ElEventPhase>[];
      void record(ElEventCallback event) => phases.add(event.phase);
      host.leafDispatcher.event = ElEvent(
        onTapDown: record,
        onTapUp: record,
        onTap: record,
        onDoubleTap: record,
      );

      await _tap(host, 1, 0);

      expect(phases, [
        ElEventPhase.tapDown,
        ElEventPhase.tapUp,
        ElEventPhase.tap,
      ]);
      expect(host.leafDispatcher.activePointerCount, 0);
    } finally {
      host.dispose();
    }
  });

  for (final triples in [false, true]) {
    testWidgets('连击窗口按双击或三击分组：triple=$triples', (_) async {
      final host = DispatcherTestHost.chain();
      try {
        final phases = <String>[];
        var ordinal = 0;
        host.leafDispatcher.event = ElEvent(
          onDoubleTapDown: (_) => phases.add('double:$ordinal'),
          onTripleTapDown: triples
              ? (_) => phases.add('triple:$ordinal')
              : null,
        );

        for (ordinal = 1; ordinal <= 5; ordinal++) {
          await _tap(host, ordinal, ordinal * 40);
        }

        expect(
          phases,
          triples
              ? ['double:2', 'triple:3', 'double:5']
              : ['double:2', 'double:4'],
        );
      } finally {
        host.dispose();
      }
    });
  }

  testWidgets('连击参数变化清空旧窗口，Drag 参数变化保留窗口', (_) async {
    final host = DispatcherTestHost.chain();
    try {
      var doubles = 0;
      void doubleTap(ElEventCallback _) => doubles++;
      host.leafDispatcher.event = ElEvent(onDoubleTapDown: doubleTap);
      await _tap(host, 1, 0);
      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(dragStartDistance: 8),
        onDoubleTapDown: doubleTap,
      );
      await _tap(host, 2, 40);
      expect(doubles, 1);

      await _tap(host, 3, 80);
      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(
          doubleTapInterval: Duration(milliseconds: 500),
        ),
        onDoubleTapDown: doubleTap,
      );
      await _tap(host, 4, 120);
      expect(doubles, 1);
    } finally {
      host.dispose();
    }
  });

  testWidgets('deferTap 延迟单击但不延迟 tapUp，第二击取消延迟单击', (tester) async {
    final host = DispatcherTestHost.chain();
    try {
      final phases = <ElEventPhase>[];
      void record(ElEventCallback event) => phases.add(event.phase);
      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(
          deferTap: true,
          doubleTapInterval: Duration(milliseconds: 100),
        ),
        onTapUp: record,
        onTap: record,
        onDoubleTap: record,
      );

      await _tap(host, 1, 0);
      expect(phases, [ElEventPhase.tapUp]);
      await tester.pump(const Duration(milliseconds: 120));
      expect(phases, [ElEventPhase.tapUp, ElEventPhase.tap]);

      phases.clear();
      await _tap(host, 2, 200);
      await tester.pump(const Duration(milliseconds: 20));
      await _tap(host, 3, 240);
      await tester.pump(const Duration(milliseconds: 120));
      expect(phases, [
        ElEventPhase.tapUp,
        ElEventPhase.tapUp,
        ElEventPhase.doubleTap,
      ]);
    } finally {
      host.dispose();
    }
  });

  testWidgets('deferTap 未声明双击时仍立即发送单击', (_) async {
    final host = DispatcherTestHost.chain();
    try {
      var taps = 0;
      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(deferTap: true),
        onTap: (_) => taps++,
      );
      await _tap(host, 1, 0);
      expect(taps, 1);
    } finally {
      host.dispose();
    }
  });

  testWidgets('长按接管终止祖先候选并保留自身 tapUp', (tester) async {
    final host = DispatcherTestHost.chain(depth: 2);
    try {
      final trace = <String>[];
      const config = ElEventConfig(longPressDelay: Duration(milliseconds: 20));
      host.rootDispatcher.event = ElEvent(
        config: config,
        onLongPress: (_) => trace.add('parent:long'),
        onTapCancel: (_) => trace.add('parent:cancel'),
        onTap: (_) => trace.add('parent:tap'),
      );
      host.leafDispatcher.event = ElEvent(
        config: config,
        onTapDown: (_) => trace.add('child:down'),
        onTapCancel: (_) => trace.add('child:cancel'),
        onLongPress: (event) {
          trace.add('child:long');
          event.eagerGesture(cancelSelfTap: true);
        },
        onTapUp: (_) => trace.add('child:up'),
        onTap: (_) => trace.add('child:tap'),
      );

      await host.dispatch(
        const PointerDownEvent(pointer: 1, position: Offset(30, 30)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await host.dispatch(
        const PointerUpEvent(
          pointer: 1,
          position: Offset(30, 30),
          timeStamp: Duration(milliseconds: 40),
        ),
      );

      expect(trace.where((phase) => phase.startsWith('child:')), [
        'child:down',
        'child:long',
        'child:cancel',
        'child:up',
      ]);
      expect(trace.where((phase) => phase.startsWith('parent:')), [
        'parent:cancel',
      ]);
      expect(
        host.dispatchers.map((dispatcher) => dispatcher.activePointerCount),
        everyElement(0),
      );
    } finally {
      host.dispose();
    }
  });

  testWidgets('拖拽先接管后不再触发长按', (tester) async {
    final host = DispatcherTestHost.chain();
    try {
      var drags = 0;
      var longPresses = 0;
      host.leafDispatcher.event = ElEvent(
        config: const ElEventConfig(
          longPressDelay: Duration(milliseconds: 30),
          dragStartDistance: 3,
        ),
        onLongPress: (_) => longPresses++,
        onDragStart: (event) {
          drags++;
          event.eagerGesture(cancelSelfTap: true);
        },
      );

      await host.dispatch(const PointerDownEvent(pointer: 1));
      await host.dispatch(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(10, 0),
          delta: Offset(10, 0),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await host.dispatch(
        const PointerUpEvent(
          pointer: 1,
          position: Offset(10, 0),
          timeStamp: Duration(milliseconds: 60),
        ),
      );
      expect(drags, 1);
      expect(longPresses, 0);
    } finally {
      host.dispose();
    }
  });

  for (final (buttons, down, up, tap) in [
    (
      kSecondaryButton,
      ElEventPhase.secondaryTapDown,
      ElEventPhase.secondaryTapUp,
      ElEventPhase.secondaryTap,
    ),
    (
      kMiddleMouseButton,
      ElEventPhase.tertiaryTapDown,
      ElEventPhase.tertiaryTapUp,
      ElEventPhase.tertiaryTap,
    ),
    (
      kForwardMouseButton,
      ElEventPhase.forwardTapDown,
      ElEventPhase.forwardTapUp,
      ElEventPhase.forwardTap,
    ),
    (
      kBackMouseButton,
      ElEventPhase.backTapDown,
      ElEventPhase.backTapUp,
      ElEventPhase.backTap,
    ),
  ]) {
    testWidgets('鼠标按钮 $buttons 仅发送对应按下、抬起、点击', (tester) async {
      final host = DispatcherTestHost.chain();
      try {
        final phases = <ElEventPhase>[];
        var primaryTaps = 0;
        var longPresses = 0;
        void record(ElEventCallback event) => phases.add(event.phase);
        host.leafDispatcher.event = ElEvent(
          config: const ElEventConfig(
            longPressDelay: Duration(milliseconds: 20),
          ),
          onTap: (_) => primaryTaps++,
          onLongPress: (_) => longPresses++,
          onSecondaryTapDown: record,
          onSecondaryTapUp: record,
          onSecondaryTap: record,
          onTertiaryTapDown: record,
          onTertiaryTapUp: record,
          onTertiaryTap: record,
          onForwardTapDown: record,
          onForwardTapUp: record,
          onForwardTap: record,
          onBackTapDown: record,
          onBackTapUp: record,
          onBackTap: record,
        );

        await host.dispatch(
          PointerDownEvent(
            pointer: 1,
            position: const Offset(30, 30),
            kind: PointerDeviceKind.mouse,
            buttons: buttons,
          ),
        );
        await tester.pump(const Duration(milliseconds: 40));
        await host.dispatch(
          const PointerUpEvent(
            pointer: 1,
            position: Offset(30, 30),
            kind: PointerDeviceKind.mouse,
            timeStamp: Duration(milliseconds: 40),
          ),
        );
        expect(phases, [down, up, tap]);
        expect(primaryTaps, 0);
        expect(longPresses, 0);
        expect(host.leafDispatcher.activePointerCount, 0);
      } finally {
        host.dispose();
      }
    });
  }

  testWidgets('侧键取消后下一次主键不残留侧键回调', (_) async {
    final host = DispatcherTestHost.chain();
    try {
      var taps = 0;
      var sideTaps = 0;
      host.leafDispatcher.event = ElEvent(
        onTap: (_) => taps++,
        onForwardTap: (_) => sideTaps++,
      );
      await host.dispatch(
        const PointerDownEvent(
          pointer: 1,
          kind: PointerDeviceKind.mouse,
          buttons: kForwardMouseButton,
        ),
      );
      await host.dispatch(
        const PointerCancelEvent(pointer: 1, kind: PointerDeviceKind.mouse),
      );
      await _tap(host, 2, 50);
      expect(taps, 1);
      expect(sideTaps, 0);
    } finally {
      host.dispose();
    }
  });
}

Future<void> _tap(DispatcherTestHost host, int pointer, int millis) async {
  await host.tap(
    pointer: pointer,
    downTime: Duration(milliseconds: millis),
    upTime: Duration(milliseconds: millis + 10),
    position: const Offset(30, 30),
  );
}
