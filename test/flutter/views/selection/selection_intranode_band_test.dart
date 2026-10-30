import 'dart:ui' as ui;

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 节点内行带链恒定（docs 代码预览块回归，2026-07-31）：
///
/// 单个多行参与者内部，行带链必须锚定**全段**行序列而非选中子集——任一行的
/// 带 top/bottom 与"选中窗口从哪行开始"无关。旧实现（_selectionRectsForBoxes
/// 的 lastLineTop/lastLineBottom 链态）从首个被选中的 box 起锚：首选行用
/// raw floor top，把上一行选进来后本行 top 被链到上一行 ceil bottom，产生
/// ±1px 高度跳变；代码预览块整块是一个语法高亮富文本节点，往上扩选逐行复现。
/// 修法 = 全段 chained line bands memo（选中无关），选中矩形按行索引查带。
///
/// 独立成文件：不依赖 scroll 模块（跨节点用例见 selection_band_static_test）。
void main() {
  SelectionParticipant textParticipant(WidgetTester tester) {
    for (final p in selectionParticipantsOf(tester.allRenderObjects)) {
      if (p.selectionContentKind == SelectionContentKind.text && p.selectionTextLength > 0) {
        return p;
      }
    }
    fail('未找到文本参与者');
  }

  /// 断言行 [line] 的带矩形在三个选中窗口（仅本行 / 含上一行 / 全选）下逐位
  /// 恒定。行几何按 fontSize 13 × lineHeight 1.55 = 20.15 推算。
  void expectLineBandStable(SelectionParticipant participant, {required int line}) {
    final lineCenterY = line * 20.15 + 10;
    int offsetAt(double x, double y) => participant.selectionOffsetForLocalPosition(Offset(x, y));
    final lineStart = offsetAt(1, lineCenterY);
    final lineEnd = offsetAt(participant.size.width - 1, lineCenterY);
    final prevLineStart = offsetAt(1, lineCenterY - 20.15);
    expect(lineEnd, greaterThan(lineStart));
    expect(prevLineStart, lessThan(lineStart));

    ui.Rect bandOf(List<ui.Rect> rects) => rects.firstWhere(
      (r) => r.top <= lineCenterY && r.bottom >= lineCenterY,
      orElse: () => fail('行 $line 无带: $rects'),
    );

    final alone = bandOf(participant.adjustedSelectionPaintRectsForRange(TextRange(start: lineStart, end: lineEnd)));
    final withPrev = bandOf(
      participant.adjustedSelectionPaintRectsForRange(TextRange(start: prevLineStart, end: lineEnd)),
    );
    final full = bandOf(
      participant.adjustedSelectionPaintRectsForRange(TextRange(start: 0, end: participant.selectionTextLength)),
    );
    expect(withPrev.top, alone.top, reason: '行 $line 带 top 不得随上一行入选而变（选中子集锚定链的 ±1px 跳变）');
    expect(withPrev.bottom, alone.bottom, reason: '行 $line 带 bottom 不得随上一行入选而变');
    expect(full.top, alone.top, reason: '行 $line 带 top 在全选窗口下同样恒定');
    expect(full.bottom, alone.bottom, reason: '行 $line 带 bottom 在全选窗口下同样恒定');
  }

  testWidgets('纯文本多行：选中窗口变化行带不变', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 200,
            child: ElSelectionView(
              child: const ElView(
                style: ElStyle(fontSize: 13, lineHeight: 1.55),
                child: '中文选区测试折行折行折行 中文选区测试折行折行折行 中文选区测试折行折行折行 中文选区测试折行',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectLineBandStable(textParticipant(tester), line: 2);
  });

  testWidgets(
    '富文本多 span（vitepress 语法高亮形态）：选中窗口变化行带不变',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 300,
              child: ElSelectionView(
                child: const ElView(
                  style: ElStyle(fontSize: 13, lineHeight: 1.55),
                  child: [
                    ElView(
                      style: ElStyle(color: Color(0xffe06c75)),
                      child: 'ElView(',
                    ),
                    '\n  ',
                    ElView(
                      style: ElStyle(color: Color(0xffd19a66)),
                      child: 'style:',
                    ),
                    ' ',
                    ElView(
                      style: ElStyle(color: Color(0xff61afef)),
                      child: 'ElStyle(',
                    ),
                    '\n    ',
                    ElView(
                      style: ElStyle(color: Color(0xffd19a66)),
                      child: 'bgColor:',
                    ),
                    ' ',
                    ElView(
                      style: ElStyle(color: Color(0xff98c379)),
                      child: 'Colors.blue',
                    ),
                    ',',
                    '\n  ),',
                    '\n  ',
                    ElView(
                      style: ElStyle(color: Color(0xffd19a66)),
                      child: 'child:',
                    ),
                    ' ',
                    ElView(
                      style: ElStyle(color: Color(0xff98c379)),
                      child: "Text('Click Me')",
                    ),
                    ',',
                    '\n)',
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 行 4 = `child: Text('Click Me'),`（事故截图里的选中行）。
      expectLineBandStable(textParticipant(tester), line: 4);
    },
  );

  testWidgets('逐行窗口扫描：每一行在"仅本行"与"从行 0 选到本行"两窗口下带恒定', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 200,
            child: ElSelectionView(
              child: const ElView(
                style: ElStyle(fontSize: 13, lineHeight: 1.55),
                child: '中文选区测试折行折行折行 中文选区测试折行折行折行 中文选区测试折行折行折行 中文选区测试折行',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p = textParticipant(tester);
    final full = p.adjustedSelectionPaintRectsForRange(TextRange(start: 0, end: p.selectionTextLength));
    final lineCount = full.length;
    expect(lineCount, greaterThan(2));
    for (var line = 1; line < lineCount; line++) {
      expectLineBandStable(p, line: line);
    }
  });
}
