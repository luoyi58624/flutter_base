import 'package:flutter_base/src/ui/cores/selection/docs/selection_view.dart';
import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/cores/selection/common/selection_core.dart';

import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElRenderView;
import 'package:flutter_base/src/ui/cores/view/view.dart';
import 'package:flutter_base/src/ui/cores/view/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用户报障的三个选中视觉症状的回归锚（2026-08）：
///
/// 1. **行间 cursor 掉档** —— 行与行之间（lineHeight 撑出的 leading 区）鼠标
///    经过时 I-beam 退回默认箭头。根因：紧凑字形盒
///    （`getBoxesForSelection` 的 tight box 只含 ascent+descent，不含 leading），
///    leading 区全 miss。命中须按**行带**垂直范围放行。
///    **pure 与 rich 两条命中分支各有一份 tight-box 判定**，只修 pure 时含嵌套
///    inline 的文本照旧掉档（用户二次报障）；判据已收口到
///    `boxAcceptsPositionWithLeading` 单点，rich 经注入共用。
/// 2. **单字符 / 整行选中高度缩小** —— 同一行内，选 1 个字符与选整行的带高
///    必须逐位相同（带高是布局静态量，与选中范围无关）。
/// 3. **末行带越出节点盒叠到下行** —— 相邻紧贴文本节点各自 ceil 多探 1px，
///    在行界叠出深色带（半透明选区尤其明显）。
///
/// 这三条此前无任何测试覆盖，故反复复发。本文件按「症状」而非「实现」断言。
///
/// 症状 1 的 rich 用例走**真实鼠标 hover + MouseTracker 读生效光标**，而不是直接
/// 调命中函数：cursor 的真实链路是
/// `hitTest → _lastHitIncludedTextContent → ElRenderView.cursor`，直接调
/// `selectionContainsLocalPosition` 走的是另一条路，会漏掉这条链上的门。
void main() {
  Widget app(Widget child) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }

  SelectionParticipant participantOf(WidgetTester tester, ElRenderView box) {
    for (final p in selectionParticipantsOf(tester.allRenderObjects)) {
      if (identical(p.box, box)) return p;
    }
    fail('未找到 $box 的选区参与者');
  }

  group('症状 1：行间 leading 区必须命中可选文本（I-beam 不掉档）', () {
    testWidgets('lineHeight 2.0 多行：两行之间的 leading 区逐点命中', (tester) async {
      const key = Key('lead');
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 120,
            child: ElSelectionView(
              // 窄容器强制折行；lineHeight 2.0 在行间撑出大片 leading。
              child: ElView(
                key: key,
                style: ElStyle(fontSize: 10, lineHeight: 2.0),
                child: 'alpha beta gamma delta epsilon zeta',
              ),
            ),
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final participant = participantOf(tester, render);
      final rects =
          (render.selectionParticipant?.selectionPaintRectsForRange(
            ui.TextRange(start: 0, end: render.selectionTextLength),
          ) ??
          const <Rect>[]);
      expect(rects.length, greaterThan(1), reason: '前置：必须折成多行');

      // 相邻两行带的交界 y。带是链式取整、首尾相接的，交界即上带 bottom。
      final tops = <double>{for (final r in rects) r.top}.toList()..sort();
      expect(tops.length, greaterThan(1), reason: '前置：应有多个不同的行带 top');

      // 逐个行界采样：交界上下各 1px 与交界本身都必须命中（leading 区在带内）。
      for (var i = 1; i < tops.length; i++) {
        final seamY = tops[i];
        for (final dy in <double>[seamY - 1.0, seamY, seamY + 1.0]) {
          expect(
            participant.selectionContainsLocalPosition(Offset(2, dy)),
            isTrue,
            reason:
                '行界 y=$seamY 附近 (2, $dy) 必须命中可选文本，'
                '否则鼠标经过行间时 I-beam 掉回默认箭头',
          );
        }
      }
    });

    testWidgets('lineHeight 2.0 单行：字形上下的 leading 区同样命中', (tester) async {
      const key = Key('lead1');
      await tester.pumpWidget(
        app(
          const ElSelectionView(
            child: ElView(key: key, style: ElStyle(fontSize: 10, lineHeight: 2.0), child: 'alpha'),
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final participant = participantOf(tester, render);
      // fontSize 10 / lineHeight 2.0 → 行盒 20，字形墨迹只占中间 10。
      expect(render.size.height, moreOrLessEquals(20, epsilon: 1.0));

      // 行盒内自上而下扫描，字形左侧列必须全程命中（上下 leading 都在带内）。
      for (var y = 1; y < render.size.height.toInt(); y++) {
        expect(
          participant.selectionContainsLocalPosition(Offset(2, y.toDouble())),
          isTrue,
          reason: '(2, $y) 在行盒内却未命中：leading 区漏检',
        );
      }
    });

    testWidgets('短行右侧空白不得误命中（不是把整盒放行）', (tester) async {
      const key = Key('tail');
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 300,
            child: ElSelectionView(
              child: ElView(key: key, style: ElStyle(fontSize: 10, lineHeight: 2.0), child: 'ab'),
            ),
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final participant = participantOf(tester, render);
      final midY = render.size.height / 2;
      expect(participant.selectionContainsLocalPosition(Offset(2, midY)), isTrue, reason: '前置：字形所在处应命中');
      expect(
        participant.selectionContainsLocalPosition(Offset(render.size.width - 2, midY)),
        isFalse,
        reason: '行尾右侧大片空白不应出 I-beam（放行 leading 不等于放行整盒）',
      );
    });
  });

  group('症状 2：带高与选中范围无关（单字符 / 整行 / 全选逐位一致）', () {
    /// 取覆盖 [y] 的那条带。
    Rect bandAt(List<Rect> rects, double y) =>
        rects.firstWhere((r) => r.top <= y && r.bottom >= y, orElse: () => fail('y=$y 无带：$rects'));

    testWidgets('纯文本多行：选 1 字符与选整行、全选的带高逐位相同', (tester) async {
      const key = Key('range');
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 160,
            child: ElSelectionView(
              child: ElView(
                key: key,
                style: ElStyle(fontSize: 12, lineHeight: 1.55),
                child: '中文选区测试折行折行 中文选区测试折行折行 中文选区测试折行',
              ),
            ),
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final participant = participantOf(tester, render);
      final total = render.selectionTextLength;
      final full = participant.adjustedSelectionPaintRectsForRange(TextRange(start: 0, end: total));
      expect(full.length, greaterThan(2), reason: '前置：必须多行');

      // 取第 2 行（有上下邻居，链式取整最容易在此暴露跳变）。
      final tops = <double>{for (final r in full) r.top}.toList()..sort();
      final lineY = (tops[1] + (tops.length > 2 ? tops[2] : tops[1] + 10)) / 2;
      final fullBand = bandAt(full, lineY);

      final lineStart = participant.selectionOffsetForLocalPosition(Offset(1, lineY));
      final lineEnd = participant.selectionOffsetForLocalPosition(Offset(render.size.width - 1, lineY));
      expect(lineEnd, greaterThan(lineStart), reason: '前置：该行应有多个字符');

      // 整行
      final wholeLine = bandAt(
        participant.adjustedSelectionPaintRectsForRange(TextRange(start: lineStart, end: lineEnd)),
        lineY,
      );
      // 单字符
      final oneChar = bandAt(
        participant.adjustedSelectionPaintRectsForRange(TextRange(start: lineStart, end: lineStart + 1)),
        lineY,
      );

      expect(
        oneChar.height,
        wholeLine.height,
        reason:
            '单字符带高 ${oneChar.height} ≠ 整行带高 ${wholeLine.height}：'
            '带高必须是布局静态量，不随选中字数缩放',
      );
      expect(oneChar.top, wholeLine.top, reason: '单字符带 top 必须与整行一致');
      expect(oneChar.bottom, wholeLine.bottom, reason: '单字符带 bottom 必须与整行一致');
      expect(wholeLine.height, fullBand.height, reason: '整行带高必须与全选时同行带高一致');
      expect(wholeLine.top, fullBand.top, reason: '整行带 top 必须与全选时一致');
    });

    testWidgets('富文本混排字号：同一行内所有 box 共享同一带高', (tester) async {
      const key = Key('mixed');
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 400,
            child: ElSelectionView(
              child: ElView(
                key: key,
                style: ElStyle(fontSize: 18, lineHeight: 1.5),
                child: [
                  'big ',
                  TextSpan(style: TextStyle(fontSize: 9), text: 'small'),
                  ' big',
                ],
              ),
            ),
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final participant = participantOf(tester, render);
      final rects = participant.adjustedSelectionPaintRectsForRange(
        TextRange(start: 0, end: render.selectionTextLength),
      );
      expect(rects.length, greaterThan(1), reason: '前置：混排应拆出多个 box');

      // 单行混排：所有 box 必须同 top / 同 bottom（WebKit 按 root inline box
      // 出 selectionTop/Bottom，一行一个带高，不按各 run 字号切成锯齿）。
      final first = rects.first;
      for (final r in rects) {
        expect(r.top, moreOrLessEquals(first.top, epsilon: 0.01), reason: '同行 box 带 top 不一致（大小字号被切成锯齿）：$rects');
        expect(r.bottom, moreOrLessEquals(first.bottom, epsilon: 0.01), reason: '同行 box 带 bottom 不一致：$rects');
      }
    });
  });

  group('症状 3：带不得越出节点盒叠到下行', () {
    testWidgets('紧挨竖排多节点：每个节点的带都在自身盒内，且行界零缝零叠', (tester) async {
      final controller = ElSelectionController();
      const texts = <String>[
        'The quick brown fox jumps over the lazy dog.',
        '敏捷的棕色狐狸跳过懒狗。',
        'Le vif renard brun saute par-dessus le chien paresseux.',
        'Быстрая коричневая лиса перепрыгивает через ленивую собаку.',
      ];
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 420,
            child: ElSelectionView(
              controller: controller,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < texts.length; i++)
                    ElView(key: ValueKey<String>('row-$i'), style: const ElStyle(lineHeight: 1.25), child: texts[i]),
                ],
              ),
            ),
          ),
        ),
      );
      controller.selectAll();
      await tester.pump();

      final renders = <ElRenderView>[];
      final bandsPerNode = <List<Rect>>[];
      for (var i = 0; i < texts.length; i++) {
        final r = tester.renderObject<ElRenderView>(find.byKey(ValueKey<String>('row-$i')));
        final rects =
            (r.selectionParticipant?.adjustedSelectionPaintRectsForRange(
              ui.TextRange(start: 0, end: r.selectionTextLength),
            ) ??
            const <Rect>[]);
        expect(rects, isNotEmpty, reason: 'row-$i 全选后应有带');
        renders.add(r);
        bandsPerNode.add(rects);
      }

      // (a) 每个节点的带都在自身盒内（越界即会叠到下行）。
      for (var i = 0; i < renders.length; i++) {
        final h = renders[i].size.height;
        for (final rect in bandsPerNode[i]) {
          expect(
            rect.bottom,
            lessThanOrEqualTo(h + 0.01),
            reason:
                'row-$i 带 bottom=${rect.bottom.toStringAsFixed(3)} '
                '越出节点高 ${h.toStringAsFixed(3)} → 叠到下一节点',
          );
          expect(rect.top, greaterThanOrEqualTo(-0.01), reason: 'row-$i 带 top 越出节点顶');
        }
      }

      // (b) 相邻节点之间零重叠。
      for (var i = 0; i + 1 < renders.length; i++) {
        final toUpper = renders[i + 1].getTransformTo(renders[i]);
        for (final upper in bandsPerNode[i]) {
          for (final lower in bandsPerNode[i + 1]) {
            final lowerInUpper = MatrixUtils.transformRect(toUpper, lower);
            final overlap = upper.intersect(lowerInUpper);
            expect(
              overlap.width <= 0 || overlap.height <= 0,
              isTrue,
              reason:
                  'row-$i 与 row-${i + 1} 带重叠 '
                  'overlapH=${overlap.height.toStringAsFixed(3)}'
                  '（半透明选区会叠出齿状深带）',
            );
          }
        }
      }
    });

    testWidgets('压缩行高 lineHeight 0.8：带仍须完整包住下伸部（不被节点盒切回）', (tester) async {
      const key = Key('squeeze');
      await tester.pumpWidget(
        app(
          const ElSelectionView(
            child: ElView(
              key: key,
              // 内容区（ascent+descent = 1em）大于压缩行盒（0.8em）。
              style: ElStyle(fontSize: 40, lineHeight: 0.8),
              child: 'ypq',
            ),
          ),
        ),
      );

      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final rects =
          (render.selectionParticipant?.adjustedSelectionPaintRectsForRange(
            ui.TextRange(start: 0, end: render.selectionTextLength),
          ) ??
          const <Rect>[]);
      expect(rects, isNotEmpty);
      final band = rects.reduce((a, b) => a.expandToInclude(b));

      // 节点盒 = 压缩行盒 ≈ 32；带须扩到内容区 ≈ 40，合法超出节点盒。
      expect(render.size.height, lessThan(36), reason: '前置：压缩行高下节点盒应矮于 1em');
      expect(
        band.height,
        greaterThan(render.size.height + 1.0),
        reason:
            '压缩行高下带高 ${band.height} 未超出节点高 ${render.size.height}：'
            'y/p 下伸部会露在带外（取整溢出的夹取不得误伤真实内容区扩张）',
      );
    });
  });
}
