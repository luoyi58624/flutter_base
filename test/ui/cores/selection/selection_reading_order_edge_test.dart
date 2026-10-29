import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/cores/selection/common/selection_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 文档使用结构顺序，滚动和视觉叠放不改变正文的全选顺序。
void main() {
  String keyOf(SelectionParticipant p) => p.selectionTextForRange(TextRange(start: 0, end: p.selectionTextLength));

  Set<String> selectedKeys(WidgetTester tester) {
    final out = <String>{};
    final seen = <SelectionParticipant>{};
    for (final p in selectionParticipantsOf(tester.allRenderObjects)) {
      if (!seen.add(p)) continue;
      if (p.selectionContentKind != SelectionContentKind.text) continue;
      final range = p.currentSelectionRange;
      if (range == null || range.isCollapsed) continue;
      out.add(keyOf(p));
    }
    return out;
  }

  Offset centerOf(WidgetTester tester, String needle) {
    for (final p in selectionParticipantsOf(tester.allRenderObjects)) {
      if (p.selectionContentKind != SelectionContentKind.text) continue;
      if (keyOf(p).contains(needle)) {
        return p.box.localToGlobal(p.box.size.center(Offset.zero));
      }
    }
    fail('未找到文本参与者: $needle');
  }

  Future<void> reverseDragToNav(WidgetTester tester, String anchorNeedle) async {
    final anchor = centerOf(tester, anchorNeedle);
    final nav = centerOf(tester, '导航标题');
    final gesture = await tester.startGesture(anchor, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveTo(Offset(anchor.dx, (anchor.dy + nav.dy) / 2));
    await tester.pump();
    await gesture.moveTo(nav);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  Widget shell({required Widget body, ElSelectionController? selection}) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const ElView(child: '导航标题')),
      body: ElSelectionView(controller: selection, child: body),
    ),
  );

  testWidgets('虚拟滚动：滚动触发 order 重建后，反选到导航仍不选锚点下方', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      shell(
        body: ElScrollView(
          controller: controller,
          children: [
            _listItems(<Widget>[
              for (var i = 0; i < 40; i++) ElView(style: const ElStyle(height: 40), child: '第$i行文本'),
            ]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 410 = 非整行偏移：首个可见行被视口裁去上半，raw rect 伸进 AppBar 区域；
    // cacheExtent 还会在其上多挂一段——不做裁剪求交必然与 AppBar 重叠。
    controller.jumpTo(410);
    await tester.pumpAndSettle();

    await reverseDragToNav(tester, '第15行');
    final selected = selectedKeys(tester);

    expect(selected.where((k) => k.contains('第16行')), isEmpty, reason: '锚点下方的行不得被选中');
    expect(selected.where((k) => k.contains('第20行')), isEmpty, reason: '锚点下方的行不得被选中');
    expect(selected.where((k) => k.contains('导航标题')), isEmpty, reason: '导航不属于正文作用域');
    expect(selected.where((k) => k.contains('第13行')), isNotEmpty, reason: '锚点上方的可见行应入选');
  });

  testWidgets('普通滚动后正文拖选保持范围，全选仍包含已挂载的卷出行', (tester) async {
    final controller = ScrollController();
    final selection = ElSelectionController();
    addTearDown(controller.dispose);
    addTearDown(selection.dispose);
    var showExtra = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      shell(
        selection: selection,
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ElScrollView(
              controller: controller,
              children: [
                for (var i = 0; i < 30; i++) ElView(style: const ElStyle(height: 40), child: '第$i行文本'),
                if (showExtra) const ElView(child: '新增尾部文本'),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.jumpTo(410);
    await tester.pumpAndSettle();
    // 全量挂载形态滚动不触发注册变化——此刻显式加一个参与者迫使 order 以
    // "已滚动"几何重建：行 0..9 仍挂载且 raw rect 在 AppBar 之上/之内。
    rebuild(() => showExtra = true);
    await tester.pumpAndSettle();

    await reverseDragToNav(tester, '第15行');
    final selected = selectedKeys(tester);

    expect(selected.where((k) => k.contains('第16行')), isEmpty, reason: '锚点下方的行不得被选中');
    expect(selected.where((k) => k.contains('新增尾部文本')), isEmpty, reason: '锚点下方的参与者不得被选中');
    expect(selected.where((k) => k.contains('导航标题')), isEmpty, reason: '导航不属于正文作用域');
    expect(selected.where((k) => k.contains('第13行')), isNotEmpty, reason: '锚点上方的可见行应入选');
    selection.selectAll();
    await tester.pump();
    final all = selectedKeys(tester);
    expect(all.where((k) => k.contains('第3行')), isNotEmpty, reason: '普通列表的挂载内容没有被虚拟选区精简误删');
  });

  testWidgets(
    'Stack 部分重叠：保持树序（保守判据），全选文本按树序连接',
    (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        MaterialApp(
          home: ElSelectionView(
            controller: controller,
            child: Stack(
              children: const [
                // 树序 [甲(20..50), 乙(0..30)]：垂直部分重叠（20..30），乙视觉在上
                // 但不得前移。
                Positioned(
                  left: 0,
                  top: 20,
                  child: ElView(style: ElStyle(height: 30), child: '甲段文本'),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: ElView(style: ElStyle(height: 30), child: '乙段文本'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.selectAll();
      await tester.pump();
      expect(controller.text, '甲段文本\n乙段文本');
      controller.clear();
      await tester.pump();
    },
  );

  testWidgets(
    'Stack 垂直错位与链式重叠均保持文档结构顺序',
    (tester) async {
      final controller = ElSelectionController();
      await tester.pumpWidget(
        MaterialApp(
          home: ElSelectionView(
            controller: controller,
            child: Column(
              crossAxisAlignment: .start,
              children: [
                // 树序 [下(40..70), 上(0..30)]：完全不相交（触边之外还有 10px 缝），
                // 上段应前移 → 阅读序。
                SizedBox(
                  height: 80,
                  width: 400,
                  child: Stack(
                    children: const [
                      Positioned(
                        left: 0,
                        top: 40,
                        child: ElView(style: ElStyle(height: 30), child: '下段文本'),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: ElView(style: ElStyle(height: 30), child: '上段文本'),
                      ),
                    ],
                  ),
                ),
                // 链式重叠：树序 [丙(40..70), 丁(20..50), 戊(0..30)]——丙~丁重叠、
                // 丁~戊重叠、丙~戊不相交。局部比较不构成全序，全部保持树序。
                SizedBox(
                  height: 80,
                  width: 400,
                  child: Stack(
                    children: const [
                      Positioned(
                        left: 0,
                        top: 40,
                        child: ElView(style: ElStyle(height: 30), child: '丙段文本'),
                      ),
                      Positioned(
                        left: 0,
                        top: 20,
                        child: ElView(style: ElStyle(height: 30), child: '丁段文本'),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: ElView(style: ElStyle(height: 30), child: '戊段文本'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.selectAll();
      await tester.pump();
      expect(controller.text, '下段文本\n上段文本\n丙段文本\n丁段文本\n戊段文本', reason: '仅按正文结构连接，不修正视觉阅读序');
      controller.clear();
      await tester.pump();
    },
  );

  testWidgets(
    'Row 水平排布：LTR 与 RTL 都保持树序（只修垂直，不按视觉水平重排）',
    (tester) async {
      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        final controller = ElSelectionController();
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: ElSelectionView(
                controller: controller,
                child: Align(
                  alignment: .topLeft,
                  child: Row(
                    mainAxisSize: .min,
                    children: const [
                      ElView(child: '首段文本'),
                      ElView(child: '次段文本'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        controller.selectAll();
        await tester.pump();
        expect(controller.text, '首段文本\n次段文本', reason: '$direction 下水平排布保持树序');
        controller.clear();
        await tester.pump();
      }
    },
  );
}

// 将已构造的测试条目接入列表配置，并保留按 key 重排的索引回查。
ElListView _listItems(List<Widget> children, {bool fixedSize = false}) {
  final indices = <Key, int>{for (var index = 0; index < children.length; index++) ?children[index].key: index};
  return ElListView.builder(
    itemCount: children.length,
    itemBuilder: (context, index) => children[index],
    fixedSize: fixedSize,
    findChildIndexCallback: (key) => indices[key],
  );
}
