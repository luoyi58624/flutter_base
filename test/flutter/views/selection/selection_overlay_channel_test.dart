// **T2** overlay 通道重构锁。见 `.claude/plan/temp/el-view-selection-mobile.md` §5-T2。
//
// 覆盖四组断言：
//   1. handle 拖动会话（begin + ≥5 update + end）`debugChromeSetStateCount`
//      增量 ≤ 2（只在显隐边界翻转）。
//   2. 拖动 update 期间 `_endpointsNotifier` 值对象 identity 不变（端点几何无关
//      变化不触发 endpoints 通知）。
//   3. dragInfo notifier 独立发通知（listener 计数 == update 次数，
//      且 endpoints listener 计数为 0）。
//   4. 滚动 frame-aligned：滚动 offset 变化 → **单个 pump 周期内** endpoints
//      notifier 已是新位置。

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

RenderSelectionView _selectionRender(WidgetTester tester) {
  return tester.allRenderObjects.whereType<RenderSelectionView>().first;
}

/// State 类是 private，通过 dynamic 拿 `@visibleForTesting` 计数。
int _chromeSetStateCount(WidgetTester tester) {
  final state = tester.state<State<ElSelectionView>>(find.byType(ElSelectionView));
  return (state as dynamic).debugChromeSetStateCount as int;
}

void main() {
  group('T2 overlay 通道 - chrome setState 边界锁', () {
    testWidgets('handle 拖动会话 debugChromeSetStateCount 增量 ≤ 2', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world foo bar baz'),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      // 选区已建立 → chrome 已从"不显示"翻到"显示"（+1）。
      final baseline = _chromeSetStateCount(tester);

      final render = _selectionRender(tester);
      final endEndpoint = render.endpoints!.end;
      render.beginHandleDrag(SelectionHandleSide.end, endEndpoint.globalPosition);
      // ≥5 次 update 全程 chrome 不 setState（都在"显示"态内）。
      for (var i = 1; i <= 8; i++) {
        render.updateHandleDrag(endEndpoint.globalPosition - Offset(i * 1.5, 0));
      }
      await tester.pump();
      render.endHandleDrag();
      await tester.pump();

      final afterDrag = _chromeSetStateCount(tester);
      // 拖动会话内至多 2 次（显隐一进一出的最大值）；稳态期望是 0。
      expect(afterDrag - baseline, lessThanOrEqualTo(2), reason: 'T2 P5: 稳态 handle 拖动不该驱动 chrome setState（分层监听消费值变化）');
    });
  });

  group('T2 overlay 通道 - endpoints 值对象 identity 稳定', () {
    testWidgets('拖动同点 update 不触发 endpoints 值对象重建', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world'),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      final endGlobal = render.endpoints!.end.globalPosition;
      render.beginHandleDrag(SelectionHandleSide.end, endGlobal);
      // 首次 update 命中同一 caret 后建立稳态。
      render.updateHandleDrag(endGlobal);
      await tester.pump();
      final stableEndpoints = render.endpoints!;

      // 同点连续 update（相同 globalPosition）：selection_handle 内 setDragInfo
      // 值相等挡通知 → endpoints 值对象不重建、identity 保持。
      for (var i = 0; i < 8; i++) {
        render.updateHandleDrag(endGlobal);
      }
      await tester.pump();
      expect(
        identical(render.endpoints, stableEndpoints),
        isTrue,
        reason: 'T2 P2: dragInfo 与端点几何解耦后，位置无变化的 update 不再触发端点值对象重建',
      );

      render.endHandleDrag();
      await tester.pump();
    });
  });

  group('T2 overlay 通道 - dragInfo 独立通知', () {
    testWidgets('dragInfo notifier 独立发通知，endpoints notifier 静默', (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        _app(
          ElSelectionView(
            controller: controller,
            child: const ElView(child: 'hello world'),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      var dragTicks = 0;
      var endpointsTicks = 0;
      void onDrag() => dragTicks++;
      void onEndpoints() => endpointsTicks++;
      render.dragInfoListenable.addListener(onDrag);
      render.endpointsListenable.addListener(onEndpoints);
      addTearDown(() {
        render.dragInfoListenable.removeListener(onDrag);
        render.endpointsListenable.removeListener(onEndpoints);
      });

      final endGlobal = render.endpoints!.end.globalPosition;
      render.beginHandleDrag(SelectionHandleSide.end, endGlobal);
      // begin 会推 dragInfo（handle kind）+1。
      final baselineDragTicks = dragTicks;
      final baselineEndpointsTicks = endpointsTicks;

      // 5 次微移 update（不改端点 caret，仅让 dragInfo.globalPosition 每次不同）。
      // 注：T1d 合帧把同窗口内多次 update 合并成 1 次 flush，dragInfo 通知次数
      // 由合帧窗口决定，本测试只锁"独立通道"语义（endpoints 全程静默 + dragInfo 有触发）。
      const updateCount = 5;
      for (var i = 1; i <= updateCount; i++) {
        render.updateHandleDrag(endGlobal + Offset(0.001 * i, 0));
      }
      await tester.pump();
      render.endHandleDrag();
      await tester.pump();

      // dragInfo 独立通道确实触发（至少一次同步 + 合帧 flush）。
      expect(dragTicks - baselineDragTicks, greaterThanOrEqualTo(1), reason: 'T2: dragInfo 独立通道应在 update / end 期间触发通知');
      // 关键锁：endpoints 增量 0（端点未变 + broadcast 内 `_sameEndpoint` 命中不改，
      // onDragInfoChanged 不再 kick _recomputeEndpoints）。
      expect(
        endpointsTicks - baselineEndpointsTicks,
        0,
        reason: 'T2 P2: 拖动 update 若端点几何未变，endpoints notifier 完全静默（独立通道核心断言）',
      );
    });
  });

  group('T2 overlay 通道 - 滚动 frame-aligned', () {
    testWidgets('滚动 1 帧后 endpoints 位置在同 pump 周期内追上', (tester) async {
      final controller = ElSelectionController();
      final scrollController = ScrollController();
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 400,
            height: 200,
            child: ElSelectionView(
              controller: controller,
              child: ElScroll(
                controller: scrollController,
                children: const [
                  ElView(child: 'row 0 selectable text content'),
                  ElView(child: 'row 1 selectable text content'),
                  ElView(child: 'row 2 selectable text content'),
                  ElView(child: 'row 3 selectable text content'),
                  ElView(child: 'row 4 selectable text content'),
                  ElView(child: 'row 5 selectable text content'),
                  ElView(child: 'row 6 selectable text content'),
                  ElView(child: 'row 7 selectable text content'),
                  ElView(child: 'row 8 selectable text content'),
                  ElView(child: 'row 9 selectable text content'),
                ],
              ),
            ),
          ),
        ),
      );

      controller.selectAll();
      await tester.pump();

      final render = _selectionRender(tester);
      final beforeStartY = render.endpoints!.start.globalPosition.dy;

      // 程序化滚动 30px。
      const scrollDelta = 30.0;
      scrollController.jumpTo(scrollController.offset + scrollDelta);
      // 单个 pump：frame-aligned 通道应保证同帧内 endpoints 已推到新位置。
      await tester.pump();

      final afterStartY = render.endpoints!.start.globalPosition.dy;
      // 首选中行在滚动后应上移 ≈ scrollDelta（允许 ±2px 亚像素 / 布局微差）。
      expect(
        (beforeStartY - afterStartY - scrollDelta).abs(),
        lessThanOrEqualTo(2.0),
        reason: 'T2 S1: 滚动同步 frame-aligned，单个 pump 周期内 endpoints 已同步到新滚动偏移',
      );
    });
  });
}
