import 'dart:ui' show FrameTiming;

import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ElFps 组件级测试：通过 onReportTimings 注入伪造 FrameTiming，
/// 验证「静止 0 → 跨过整秒结算显示 → 停帧归 0」全链路。
void main() {
  const us = 1000000;

  Finder fpsText(int value) => find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is ElFpsPainter &&
            (widget.painter! as ElFpsPainter).fps == value,
      );

  FrameTiming timing(int vsyncUs) {
    return FrameTiming(
      vsyncStart: vsyncUs,
      buildStart: vsyncUs + 100,
      buildFinish: vsyncUs + 2000,
      rasterStart: vsyncUs + 2100,
      rasterFinish: vsyncUs + 5000,
      rasterFinishWallTime: vsyncUs + 5000,
    );
  }

  Widget shell() {
    return const MediaQuery(
      data: MediaQueryData(),
      child: ElFps(),
    );
  }

  testWidgets('静止显示 0，跨过整秒结算显示帧数，停帧后归 0', (tester) async {
    await tester.pumpWidget(shell());
    expect(fpsText(0), findsOneWidget);

    // 60Hz 帧流分两批注入（模拟引擎攒批投递），末帧跨过 1 秒边界触发结算。
    // scheduleFrame 还原动画进行中的真实前提：恒有帧已调度，显示刷新的
    // setState 只是搭车，不会被判定为自诱发帧。
    final report = tester.binding.platformDispatcher.onReportTimings;
    expect(report, isNotNull, reason: 'ElFps 应已注册 timings 回调');
    const interval = us ~/ 60;
    tester.binding.scheduleFrame();
    report!([for (var i = 0; i < 30; i++) timing(i * interval)]);
    await tester.pump();
    expect(fpsText(0), findsOneWidget, reason: '桶内累计阶段不出值');
    report([for (var i = 30; i < 62; i++) timing(i * interval)]);
    await tester.pump();
    expect(fpsText(60), findsOneWidget);

    // 停帧：超过归零超时无任何上报 → 一步归 0
    await tester.pump(const Duration(milliseconds: 800));
    expect(fpsText(0), findsOneWidget);
  });

  testWidgets('停帧归 0 后的孤立帧不恢复旧值', (tester) async {
    await tester.pumpWidget(shell());
    final report = tester.binding.platformDispatcher.onReportTimings!;
    const interval = us ~/ 60;
    tester.binding.scheduleFrame();
    report([for (var i = 0; i < 62; i++) timing(i * interval)]);
    await tester.pump();
    expect(fpsText(60), findsOneWidget);

    // 停帧归 0（归零同时 reset 计数器）
    await tester.pump(const Duration(milliseconds: 800));
    expect(fpsText(0), findsOneWidget);

    // 之后一个孤立 hover 帧：只重新锚定新桶，不出值 → 显示保持 0
    report([timing(62 * interval + 2 * us)]);
    await tester.pump();
    expect(fpsText(0), findsOneWidget);
  });

  testWidgets('show=false 不显示帧率文本', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: ElFps(show: false),
      ),
    );
    expect(fpsText(0), findsNothing);
  });

  testWidgets('显示自刷新帧不回流计数器（回归：静止时数字受自产帧污染）', (tester) async {
    await tester.pumpWidget(shell());
    final report = tester.binding.platformDispatcher.onReportTimings!;
    // 30Hz 避开测试显示器 60Hz 刷新率封顶
    const interval = us ~/ 30;

    // 静止页面上一段 30Hz 帧流跨过整秒：结算显示 30；此时无已调度帧，
    // 刷新文本的 setState 被标记为自诱发帧
    report([for (var i = 0; i < 32; i++) timing(i * interval)]);
    await tester.pump();
    expect(fpsText(30), findsOneWidget);

    // 模拟自诱发帧随下一批回流：若不扣除，它会计入下一个桶、参与后续
    // 结算，污染真实计数
    report([timing(32 * interval + 100000)]);
    await tester.pump();
    expect(fpsText(30), findsOneWidget, reason: '自刷新帧被扣除，显示不变');

    // 无后续真实帧：超时一步归 0，不出现中间值
    await tester.pump(const Duration(milliseconds: 800));
    expect(fpsText(0), findsOneWidget);
  });
}
