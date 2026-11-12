import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mixed in [false, true]) {
    testWidgets('全选后回收窗口仅保留仍挂载的选择，新窗口可重新全选 mixed=$mixed', (tester) async {
      final selection = ElSelectionController();
      final scroll = ScrollController();
      addTearDown(selection.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ElSelectionView(
            controller: selection,
            child: Column(
              children: [
                if (mixed) ElView(key: ValueKey('outside'), child: 'outside'),
                Expanded(
                  child: ElScrollView.sliver(
                    controller: scroll,
                    slivers: [
                      SliverList.builder(
                        itemCount: 500,
                        itemBuilder: (context, index) =>
                            ElView(key: ValueKey(index), style: ElStyle(height: 40), child: 'row $index'),
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
      selection.selectAll();
      await tester.pumpAndSettle();
      List<ElRenderView> mounted() {
        final rows = tester.allRenderObjects
            .whereType<ElRenderView>()
            .toSet()
            .where(
              (row) => (row.content is TextEngine) && (selectionParticipantOf(row)?.hasEnabledSelectionRoot ?? false),
            )
            .toList();
        String text(ElRenderView row) => selectionParticipantOf(row)!
            .selectionTextForRange(TextRange(start: 0, end: (selectionParticipantOf(row)?.selectionTextLength ?? 0)));
        int order(ElRenderView row) => text(row) == 'outside' ? -1 : int.parse(text(row).substring(4));
        rows.sort((a, b) => order(a).compareTo(order(b)));
        return rows;
      }

      String? textOf(Iterable<ElRenderView> rows) {
        final content = rows
            .map(
              (row) => selectionParticipantOf(row)!.selectionTextForRange(
                TextRange(start: 0, end: (selectionParticipantOf(row)?.selectionTextLength ?? 0)),
              ),
            )
            .toList();
        return content.isEmpty ? null : content.join('\n');
      }

      var selected = mounted().toSet();
      expect(selection.text, textOf(selected));
      for (final offset in [10000.0, 0.0]) {
        scroll.jumpTo(offset);
        await tester.pumpAndSettle();
        final rows = mounted();
        expect(selection.text, textOf(rows.where(selected.contains)), reason: '复制只保留仍有效的旧节点，不续接新窗口');
        expect(rows.length, lessThan(50), reason: '选区不能迫使整份列表一直挂载');
        for (final row in rows) {
          expect(
            selectionParticipantOf(row)?.currentSelectionRange,
            selected.contains(row)
                ? TextRange(start: 0, end: (selectionParticipantOf(row)?.selectionTextLength ?? 0))
                : null,
          );
        }
        selection.selectAll();
        await tester.pump();
        selected = mounted().toSet();
        expect(selection.text, textOf(selected), reason: '新窗口内的有效节点仍能正常全选');
      }
      selection.clear();
      await tester.pump();
      expect(selection.text, isNull);
      await tester.pumpWidget(ElView());
    });
  }
}
