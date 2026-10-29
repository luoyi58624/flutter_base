import 'dart:async';

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/reparent.dart';

Widget _scrollPage(ElScrollController controller, {VoidCallback? onScrollEnd}) => Material(
  child: NotificationListener<ScrollEndNotification>(
    onNotification: (_) {
      onScrollEnd?.call();
      return false;
    },
    child: ElScrollView(
      controller: controller,
      physics: ElClampingScrollPhysics(),
      scrollbar: ElNoScrollBar(),
      children: [
        // 输入参与者保证经过统一 route 的所有权取消路径。
        ScrollMixinClientProbe(scrollInputSlot: #input, child: SizedBox(height: 80)),
        for (var i = 0; i < 60; i++) SizedBox(height: 80),
      ],
    ),
  ),
);

Future<void> _fling(WidgetTester tester, ElScrollController controller) async {
  var timestamp = tester.binding.currentSystemFrameTimeStamp;
  final gesture = await tester.createGesture();
  await gesture.down(Offset(400, 480), timeStamp: timestamp);
  for (var i = 0; i < 5; i++) {
    timestamp += Duration(milliseconds: 16);
    await gesture.moveBy(Offset(0, -35), timeStamp: timestamp);
    await tester.pump(Duration(milliseconds: 16));
  }
  await gesture.up(timeStamp: timestamp + Duration(milliseconds: 16));
  await tester.pump(Duration(milliseconds: 16));
  expect(controller.offset, greaterThan(0));
  expect(controller.position.isScrollingNotifier.value, isTrue, reason: '返回发生时必须仍有在途滚动活动');
}

Future<void> _backMessage(WidgetTester tester, String method, [Map<String, Object?>? arguments]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}

void main() {
  for (final commit in [false, true]) {
    testWidgets('滚动中预测性返回不向失活的 Material 派发通知 commit=$commit', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final controller = ElScrollController();
      var scrollEnds = 0;
      addTearDown(() async {
        await tester.pumpWidget(SizedBox.shrink());
        controller.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(
            platform: .android,
            pageTransitionsTheme: PageTransitionsTheme(builders: {.android: PredictiveBackPageTransitionsBuilder()}),
          ),
          home: Material(child: SizedBox.expand()),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => _scrollPage(controller, onScrollEnd: () => scrollEnds++)),
        ),
      );
      await tester.pumpAndSettle();
      await _fling(tester, controller);
      final position = controller.position;
      final offset = controller.offset;
      await _backMessage(tester, 'startBackGesture', {
        'touchOffset': <double>[5, 300],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _backMessage(tester, 'updateBackGestureProgress', {
        'touchOffset': <double>[100, 300],
        'progress': .35,
        'swipeEdge': 0,
      });
      await tester.pump(Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await _backMessage(tester, commit ? 'commitBackGesture' : 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (commit) {
        expect(controller.hasClients, isFalse);
        expect(navigator.currentState!.canPop(), isFalse);
      } else {
        expect(controller.position, same(position));
        expect(controller.offset, closeTo(offset, .01), reason: '重挂取消旧惯性，但保留页面当前位置');
        expect(controller.position.isScrollingNotifier.value, isFalse);
        final endsBefore = scrollEnds;
        await _fling(tester, controller);
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(offset));
        expect(scrollEnds, greaterThan(endsBefore), reason: '返回取消后正常滚动仍须派发终态通知');
      }
    }, variant: TargetPlatformVariant.only(.android));
  }

  testWidgets('Material 与滚动子树一起重挂时停止旧惯性并保留 position', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final controller = ElScrollController();
    addTearDown(() async {
      await tester.pumpWidget(SizedBox.shrink());
      controller.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ReparentHarness(key: move, child: _scrollPage(controller)),
      ),
    );
    await tester.pumpAndSettle();
    await _fling(tester, controller);
    final position = controller.position;
    final offset = controller.offset;
    await reparent(tester, move, settle: false);
    expect(controller.position, same(position));
    expect(controller.offset, closeTo(offset, .01));
    expect(position.isScrollingNotifier.value, isFalse);
  });

  testWidgets('滚动终态通知抛错后，失效惯性不能继续请求帧', (tester) async {
    final controller = ElScrollController();
    var failOnEnd = true;
    addTearDown(() async {
      await tester.pumpWidget(SizedBox.shrink());
      controller.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: _scrollPage(
          controller,
          onScrollEnd: () {
            if (!failOnEnd) return;
            failOnEnd = false;
            throw StateError('scroll end failure');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _fling(tester, controller);
    expect(() => controller.jumpTo(controller.offset), throwsStateError);
    final offset = controller.offset;
    // 复刻真机残留：通知异常中断官方 beginActivity，旧 activity 尚未 dispose。
    await tester.pump(Duration(milliseconds: 16));
    expect(controller.offset, offset);
    expect(tester.binding.transientCallbackCount, 0, reason: '失去写入权的 Ticker 必须停止，不能每帧空转');
    controller.jumpTo(offset);
    await _fling(tester, controller);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(offset), reason: '停止旧 Ticker 不能误伤后续正常惯性');
  });
}
