import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 正文与导航采用独立文档根，向上拖出正文时不能选中导航或锚点下方内容。
void main() {
  String keyOf(SelectionParticipant p) => p.selectionTextForRange(TextRange(start: 0, end: p.selectionTextLength));

  Map<String, TextRange> selectedTexts(WidgetTester tester) {
    final out = <String, TextRange>{};
    final seen = <SelectionParticipant>{};
    for (final p in selectionParticipantsOf(tester.allRenderObjects)) {
      if (!seen.add(p)) continue;
      if (p.selectionContentKind != SelectionContentKind.text) continue;
      final range = p.currentSelectionRange;
      if (range == null || range.isCollapsed) continue;
      out[keyOf(p)] = range;
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

  testWidgets('从内容区向上拖选到 AppBar 导航：锚点下方的行不得被选中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ElSelectionView(
          // 外层：包整页（含 AppBar），对应 view/index.dart 的全页包裹。
          child: Scaffold(
            appBar: AppBar(title: const ElView(child: '顶部导航标题')),
            // 正文显式建立独立文档。
            body: ElSelectionView(
              child: Align(
                alignment: .topLeft,
                child: Column(
                  crossAxisAlignment: .start,
                  children: const [
                    ElView(child: '内容第一行文本'),
                    ElView(child: '内容第二行文本'),
                    ElView(child: '内容第三行文本'),
                    ElView(child: '内容第四行文本'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 锚点按在第二行，向上拖到 AppBar 标题（视觉反向选）。
    final anchor = centerOf(tester, '第二行');
    final navCenter = centerOf(tester, '顶部导航标题');
    final gesture = await tester.startGesture(anchor, kind: PointerDeviceKind.mouse);
    await tester.pump();
    // 分两步移动，确保拖选路径经过内容区上缘再进入 AppBar。
    await gesture.moveTo(Offset(anchor.dx, (anchor.dy + navCenter.dy) / 2));
    await tester.pump();
    await gesture.moveTo(navCenter);
    await tester.pump();

    final selected = selectedTexts(tester);

    // 核心（报告症状）：锚点下方的行绝不入选。
    expect(selected.keys.where((k) => k.contains('第三行')), isEmpty, reason: '锚点下方的第三行不得被选中');
    expect(selected.keys.where((k) => k.contains('第四行')), isEmpty, reason: '锚点下方的第四行不得被选中');

    // 反向拖出时保留正文第一行，导航属于另一个文档。
    expect(selected.keys.where((k) => k.contains('顶部导航标题')), isEmpty, reason: '拖出正文不能跨入导航文档');
    expect(selected.keys.where((k) => k.contains('第一行')), isNotEmpty, reason: '锚点上方的第一行应入选');

    await gesture.up();
    await tester.pump();
  });
}
