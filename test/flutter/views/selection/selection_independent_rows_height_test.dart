import 'dart:ui' as ui;

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('截图形态：独立文本行全选后的带高一致', (tester) async {
    final controller = ElSelectionController();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 1200,
            child: ElSelectionView(
              controller: controller,
              child: const ElView(
                // 对齐文档页根排版：子标题只改字号，行高仍继承 1.5。
                style: ElStyle(padding: .all(20), fontSize: 16, lineHeight: 1.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProbeRow(
                      key: ValueKey('row-1'),
                      id: 'row-1',
                      title: 'context.elVar<Color>(ElApp.\$primary)',
                      hint: '全局 token：必声明，无回落 · #409eff',
                    ),
                    ElView(style: ElStyle(height: 8)),
                    _ProbeRow(
                      key: ValueKey('row-2'),
                      id: 'row-2',
                      title: 'context.elVarOrVar(ElCheckbox.\$checkedBgColor)',
                      hint: '组件 token：回落全局主色 · #67c23a',
                    ),
                    ElView(style: ElStyle(height: 8)),
                    _ProbeRow(
                      key: ValueKey('row-3'),
                      id: 'row-3',
                      title: 'context.elTheme.error',
                      hint: '快捷 getter：固定返回类型，免写泛型 · #f56c6c',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.selectAll();
    await tester.pump();

    final rows = <List<ui.Rect>>[];
    for (final row in ['row-1', 'row-2', 'row-3']) {
      final key = ValueKey<String>('$row-hint');
      final render = tester.renderObject<RenderBox>(find.byKey(key));
      final participant = selectionParticipantsOf(tester.allRenderObjects).firstWhere((p) => identical(p.box, render));
      final range = participant.currentSelectionRange!;
      final rects = participant.adjustedSelectionPaintRectsForRange(range);
      rows.add(rects);
    }

    expect(rows.every((rects) => rects.length == 1), isTrue);
    final heights = rows.map((rects) => rects.single.height).toList();
    expect(heights[1], heights[0]);
    expect(heights[2], heights[0]);

    controller.clear();
    await tester.pump();
    final hintRect = tester.getRect(find.byKey(const ValueKey<String>('row-3-hint')));
    final gesture = await tester.startGesture(
      Offset(hintRect.left + hintRect.width * .4, hintRect.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(Offset(hintRect.right - 1, hintRect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final thirdRender = tester.renderObject<RenderBox>(find.byKey(const ValueKey<String>('row-3-hint')));
    final thirdParticipant = selectionParticipantsOf(
      tester.allRenderObjects,
    ).firstWhere((p) => identical(p.box, thirdRender));
    final partialRange = thirdParticipant.currentSelectionRange;
    expect(partialRange, isNotNull);
    final partialRects = thirdParticipant.adjustedSelectionPaintRectsForRange(partialRange!);
    expect(partialRects, hasLength(1));
    expect(partialRects.single.height, heights[2]);
  });

  testWidgets('独立文本节点不吸附相邻选区带', (tester) async {
    final controller = ElSelectionController();
    const lowerKey = ValueKey<String>('lower');
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: ElSelectionView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ElView(style: ElStyle(fontSize: 12, lineHeight: 1.5), child: '上方独立文本'),
                // 让下方节点的首行带与上方末行带有 1px 交叠；旧 root seam
                // 算法会把它的 top 从 0 改成 1，直接压缩选区带高度。
                Transform.translate(
                  offset: Offset(0, -1),
                  child: ElView(key: lowerKey, style: ElStyle(fontSize: 12, lineHeight: 1.5), child: '下方独立文本'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.selectAll();
    await tester.pump();

    final render = tester.renderObject<RenderBox>(find.byKey(lowerKey));
    final participant = selectionParticipantsOf(tester.allRenderObjects).firstWhere((p) => identical(p.box, render));
    final range = participant.currentSelectionRange!;
    final local = participant.selectionContent!.adjustedSelectionPaintRectsForRange(range, nodeSize: render.size);
    expect(participant.adjustedSelectionPaintRectsForRange(range), local);
  });
}

class _ProbeRow extends StatelessWidget {
  const _ProbeRow({super.key, required this.id, required this.title, required this.hint});

  final String id;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElView(style: ElStyle(width: 48, height: 48)),
        const ElView(style: ElStyle(width: 12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElView(
              key: ValueKey<String>('$id-title'),
              style: const ElStyle(fontSize: 13, softWrap: false),
              child: title,
            ),
            ElView(key: ValueKey<String>('$id-hint'), style: const ElStyle(fontSize: 12, softWrap: false), child: hint),
          ],
        ),
      ],
    );
  }
}
