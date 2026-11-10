import 'dart:ui' as ui;

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归：虚拟滚动 + 全选时，半透明选区带在**相邻 item 之间**叠出深色横带
/// （ui_example VirtualScrollPage 场景）。
///
/// 单 render 内的行缝已按行带记账裁平（_selection_paint.dart），但虚拟列表
/// 里每个 ElView 各自绘制自己的选区带：item 高度为小数时（真机字体行高
/// 几乎必然是小数），本 item 行盒 ceil 出的带底与下一个 item floor 出的带顶
/// 在全局坐标上交叠。测试字体行高恒为整数，须用 lineHeight 小数倍率模拟。
void main() {
  /// 收集所有已挂载 ElRenderView 的选区带并换算到全局坐标——与真实绘制
  /// 同构（paint 时 rect 直接以 render 的 paint offset 平移）。
  List<ui.Rect> collectGlobalSelectionRects(WidgetTester tester) {
    final globalRects = <ui.Rect>[];
    // allRenderObjects 按 element 映射 render：无 render 的包装 element 会把同一个
    // ElRenderView（文本合并后 participant 就是宿主）再报一次，须按身份去重，
    // 否则自身矩形与自身"重叠"。
    final seen = <SelectionParticipant>{};
    for (final render in selectionParticipantsOf(tester.allRenderObjects)) {
      if (!seen.add(render)) continue;
      final length = render.selectionTextLength;
      if (length <= 0) continue;
      final rects = render.adjustedSelectionPaintRectsForRange(ui.TextRange(start: 0, end: length));
      final origin = render.box.localToGlobal(Offset.zero);
      globalRects.addAll(rects.map((r) => r.shift(origin)));
    }
    return globalRects;
  }

  /// 任意两 rect 的交集面积必须为零（±0.01 容差）——半透明选区叠加变深的
  /// 充要条件。跨 item 的重叠必然发生在非相邻 rect 之间，必须全对全。
  void expectNoAreaOverlap(List<ui.Rect> rects, {required String label}) {
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        final overlap = rects[i].intersect(rects[j]);
        final hasArea = overlap.width > 0.01 && overlap.height > 0.01;
        expect(
          hasArea,
          isFalse,
          reason:
              '$label: rect[$i]=${rects[i]} 与 rect[$j]=${rects[j]} '
              '交集 ${overlap.width.toStringAsFixed(2)}x${overlap.height.toStringAsFixed(2)}',
        );
      }
    }
  }

  Widget host({
    required ElSelectionController selectionController,
    required ScrollController scrollController,
    required List<Widget> rows,
  }) {
    return MaterialApp(
      home: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: 375,
          height: 400,
          child: ElSelectionView(
            controller: selectionController,
            child: ElScroll.sliver(
              controller: scrollController,
              physics: ClampingScrollPhysics(),
              slivers: [_listItems(rows)],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('demo 同构：默认样式 ElView 全选无跨 item 重叠', (tester) async {
    final selectionController = ElSelectionController();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    final rows = List<Widget>.generate(
      60,
      (index) => ElView(child: '黄金法则：让可交互的元素不可选（none），让可阅读的内容可选（text）。 - ${index + 1}'),
    );

    await tester.pumpWidget(
      host(selectionController: selectionController, scrollController: scrollController, rows: rows),
    );
    await tester.pumpAndSettle();

    selectionController.selectAll();
    await tester.pump();

    final rects = collectGlobalSelectionRects(tester);
    expect(rects.length, greaterThan(5), reason: '视口内必须有多个已选中的文本 item');
    expectNoAreaOverlap(rects, label: '默认样式');

    // 收尾清选区：带着全选卸载虚拟列表触发 teardown setState during build
    // （独立 bug，另行跟进），与本测试的几何断言无关。
    selectionController.clear();
    await tester.pump();
  });

  testWidgets('小数行高（真机字体形态）全选无跨 item 重叠', (tester) async {
    final selectionController = ElSelectionController();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    // fontSize 13 × lineHeight 1.55 = 20.15px：item 高度小数，堆叠偏移逐项
    // 累积小数——真机字体下的常态，测试字体默认行高整数复现不出来。
    final rows = List<Widget>.generate(
      60,
      (index) => ElView(
        style: const ElStyle(fontSize: 13, lineHeight: 1.55),
        child: '黄金法则：让可交互的元素不可选（none），让可阅读的内容可选（text）。 - ${index + 1}',
      ),
    );

    await tester.pumpWidget(
      host(selectionController: selectionController, scrollController: scrollController, rows: rows),
    );
    await tester.pumpAndSettle();

    selectionController.selectAll();
    await tester.pump();

    final rects = collectGlobalSelectionRects(tester);
    expect(rects.length, greaterThan(5));
    expectNoAreaOverlap(rects, label: '小数行高');

    // 滚到小数偏移（拖动/惯性中的常态）后重新校验挂载窗口。
    scrollController.jumpTo(123.45);
    await tester.pump();
    selectionController.selectAll();
    await tester.pump();

    final scrolled = collectGlobalSelectionRects(tester);
    expect(scrolled.length, greaterThan(5));
    expectNoAreaOverlap(scrolled, label: '小数行高+小数滚动偏移');

    // 收尾清选区：带着全选选区卸载虚拟列表会触发 RenderSelectionView 在
    // build 期间广播端点（setState during build，独立 bug，另行跟进），
    // 与本测试验证的选区带几何无关。
    selectionController.clear();
    await tester.pump();
  });

  testWidgets('非整数 dpr：item extent 对齐物理像素网格（合成器 layer 吸附深线回归）', (tester) async {
    // Windows 桌面实测：item 高度带小数时逐 item RepaintBoundary layer 被
    // 合成器按物理像素各自吸附，相位回绕处相邻 item 半透明选区带叠出 1
    // 物理像素深线（周期性横带）。toImage 不走吸附路径测不出视觉结果，
    // 这里锁修复的机制本身：extent 与位置必须都落在 1/dpr 网格上。
    const dpr = 1.25;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetDevicePixelRatio);

    final selectionController = ElSelectionController();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    // fontSize 13 × lineHeight 1.55 = 20.15 逻辑像素 → 25.1875 物理像素，
    // 天然不在网格上，必须被量化。
    final rows = List<Widget>.generate(
      40,
      (index) => ElView(
        style: const ElStyle(fontSize: 13, lineHeight: 1.55),
        child: '黄金法则：让可交互的元素不可选（none），让可阅读的内容可选（text）。 - ${index + 1}',
      ),
    );

    await tester.pumpWidget(
      host(selectionController: selectionController, scrollController: scrollController, rows: rows),
    );
    await tester.pumpAndSettle();

    selectionController.selectAll();
    await tester.pump();

    var checked = 0;
    for (final render in selectionParticipantsOf(tester.allRenderObjects)) {
      if (render.selectionTextLength <= 0) continue;
      final devHeight = render.size.height * dpr;
      final devTop = render.localToGlobal(Offset.zero).dy * dpr;
      expect(
        (devHeight - devHeight.roundToDouble()).abs(),
        lessThan(1e-6),
        reason: 'item 高度 ${render.size.height} × $dpr = $devHeight 不在物理像素网格上',
      );
      expect(
        (devTop - devTop.roundToDouble()).abs(),
        lessThan(1e-6),
        reason: 'item 全局位置 dy × $dpr = $devTop 不在物理像素网格上',
      );
      checked++;
    }
    expect(checked, greaterThan(5));

    expectNoAreaOverlap(collectGlobalSelectionRects(tester), label: '非整数 dpr');

    selectionController.clear();
    await tester.pump();
  });

  testWidgets('富文本 inline 项（多 box 行）全选无重叠', (tester) async {
    // 真机上 demo 字符串里的 "none"/"text" 走 latin 字体、与 CJK metrics
    // 不同，一行拆多个 box——测试字体全字符同 metrics 会合并成单 box，
    // 必须用不同 fontSize 的 inline 子节点才能在测试环境拆出多 box 行，
    // 打中"行缝只裁首个 box"的老路径（用户虚拟滚动页截图问题）。
    final selectionController = ElSelectionController();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    final rows = List<Widget>.generate(
      40,
      (index) => ElView(
        style: const ElStyle(fontSize: 17, lineHeight: 1.7),
        child: [
          // 前导文本长过一行：inline 子节点必须折到第 2 行（带行缝的行），
          // 否则落在首行（无行缝可裁）打不中老路径。
          '黄金法则：让可交互的元素不可选，让可阅读的内容保持可选，选区表现要与浏览器一致。',
          const ElView(style: ElStyle(fontSize: 13), child: '不可选（none）'),
          '，让可阅读的内容可选（text）。 - ${index + 1}',
        ],
      ),
    );

    await tester.pumpWidget(
      host(selectionController: selectionController, scrollController: scrollController, rows: rows),
    );
    await tester.pumpAndSettle();

    selectionController.selectAll();
    await tester.pump();

    final rects = collectGlobalSelectionRects(tester);
    expect(rects.length, greaterThan(5));
    expectNoAreaOverlap(rects, label: '富文本 inline 项');

    selectionController.clear();
    await tester.pump();
  });
}

// 将已构造的测试条目接入列表配置，并保留按 key 重排的索引回查。
Widget _listItems(List<Widget> children) {
  final indices = <Key, int>{for (var index = 0; index < children.length; index++) ?children[index].key: index};
  return SliverList.builder(
    itemCount: children.length,
    itemBuilder: (context, index) => children[index],
    findChildIndexCallback: (key) => indices[key],
  );
}
