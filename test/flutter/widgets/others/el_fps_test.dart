import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Finder fpsText(int value) => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is ElFpsPainter && (widget.painter! as ElFpsPainter).fps == value,
);

Widget shell({bool show = true, bool enabled = true, Color color = Colors.green}) => TickerMode(
  enabled: enabled,
  child: ElFps(show: show, color: color),
);

// 精确分配一秒内的帧时间，避免整数微秒舍入使最后一帧还没越过结算边界。
Future<void> pumpSecond(WidgetTester tester, int frames) async {
  var previous = 0;
  for (var i = 1; i <= frames; i++) {
    final timestamp = (i * 1000000 / frames).round();
    await tester.pump(Duration(microseconds: timestamp - previous));
    previous = timestamp;
  }
}

void main() {
  for (final rate in [30, 60, 90, 120, 165]) {
    testWidgets('$rate 帧按实际回调计数，不受显示器上报 60Hz 封顶', (tester) async {
      tester.view.display.refreshRate = 60;
      addTearDown(tester.view.display.resetRefreshRate);
      await tester.pumpWidget(shell());
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await pumpSecond(tester, rate);
      expect(fpsText(rate), findsOneWidget);
      await tester.pumpWidget(SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('120 帧降到 60 帧后显示实际降幅，重复时间戳不多计', (tester) async {
    await tester.pumpWidget(shell());
    await tester.pump();
    await pumpSecond(tester, 120);
    expect(fpsText(120), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    await pumpSecond(tester, 60);
    expect(fpsText(60), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('长卡顿越过窗口时用实际耗时计算，不把 1.5 秒当 1 秒', (tester) async {
    await tester.pumpWidget(shell());
    await tester.pump();
    for (var i = 0; i < 59; i++) {
      await tester.pump(Duration(milliseconds: 10));
    }
    await tester.pump(Duration(milliseconds: 910));
    expect(fpsText(40), findsOneWidget, reason: '60 个间隔 / 1.5 秒 = 40 fps');
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('show 关闭和卸载后停止请求帧，重新显示重新计数', (tester) async {
    await tester.pumpWidget(shell());
    await tester.pump();
    await pumpSecond(tester, 120);
    await tester.pumpWidget(shell(show: false));
    expect(find.byType(CustomPaint), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(Duration(seconds: 5));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(shell());
    await tester.pump();
    expect(fpsText(0), findsOneWidget);
    await pumpSecond(tester, 90);
    expect(fpsText(90), findsOneWidget);
    await tester.pumpWidget(SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('TickerMode 停用后暂停，恢复时不把停用时长算作卡顿', (tester) async {
    await tester.pumpWidget(shell());
    await tester.pump();
    await pumpSecond(tester, 120);
    await tester.pumpWidget(shell(enabled: false));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(Duration(seconds: 5));
    await tester.pumpWidget(shell());
    await tester.pump();
    expect(fpsText(0), findsOneWidget);
    await pumpSecond(tester, 120);
    expect(fpsText(120), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('后台暂停采样，返回前台不包含后台时长', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await tester.pumpWidget(shell());
    await tester.pump();
    await pumpSecond(tester, 120);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(fpsText(0), findsOneWidget);
    await pumpSecond(tester, 120);
    expect(fpsText(120), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('慢动画倍率不改变实时时钟，修改颜色不重启采样', (tester) async {
    timeDilation = 5;
    addTearDown(() => timeDilation = 1);
    await tester.pumpWidget(shell());
    await tester.pump();
    await pumpSecond(tester, 120);
    expect(fpsText(120), findsOneWidget);
    await tester.pumpWidget(shell(color: Colors.red));
    expect(fpsText(120), findsOneWidget);
    expect((tester.widget<CustomPaint>(fpsText(120)).painter! as ElFpsPainter).color, Colors.red);
    await tester.pumpWidget(SizedBox());
  });
}
