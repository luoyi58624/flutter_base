import 'package:flutter_base/src/flutter/views/view/text/text_engine.dart' show TextEngine;
import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/render/render_view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 压缩行高下选中带的墨迹覆盖（vp_home hero y/p 尾巴事故，2026-07-31）：
///
/// 浏览器口径 = 选中带按**字体内容区**出值（CSS content area = ascent+descent，
/// 不被 line-height 压缩），行高压缩时带合法超出行盒与元素盒。旧修法保持带为
/// 行盒 strip、给换色 clip 单独扩张出第二套矩形——带背景仍贴行盒切，压缩行高
/// 下 y/p 伸部露在带外。现口径：带 = 行盒 ∪ 字体内容区（链式取整不变），带
/// 背景与换色 clip 共用这一套矩形，`_selectionColorClipRectsForRange` 已退役。
///
/// 断言全部落在带矩形上：垂直盖住 tight 字形墨迹、垂直放行出节点盒、水平仍走
/// 字符 advance 边界（跨字形从中间切开，与 Chrome 一致）。
void main() {
  Future<ElRenderView> pumpText(
    WidgetTester tester, {
    required double lineHeight,
    double fontSize = 56,
    Object? child,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: ElSelectionView(
            child: ElView(
              style: ElStyle(fontSize: fontSize, lineHeight: lineHeight),
              child: child ?? 'My py Components',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.allRenderObjects.whereType<ElRenderView>().firstWhere((r) => (r.content as TextEngine?) != null);
  }

  testWidgets('lineHeight 0.8（墨迹出行盒）：带 = 行盒 ∪ 内容区，垂直盖住墨迹且放行出节点盒', (tester) async {
    // 单行文本（5 字 ×56px < 800 视口）：出节点盒断言只对首/末行成立，
    // 默认 16 字文本会折两行，'py' 落在第一行测不到末行带底。
    final render = await pumpText(tester, lineHeight: 0.8, child: 'My py');
    final painter = (render.content as TextEngine?)!;
    const range = TextRange(start: 3, end: 5); // 'py'，含下伸部

    final tight = painter.getBoxesForSelectionForTest(range.start, range.end).single.toRect();
    final band = painter.adjustedSelectionPaintRectsForRange(range, nodeSize: render.size).single;

    // 判别性前提：压缩行高下字体内容区（tight 高 = 1em）确实高于行盒。
    expect(tight.height, greaterThan(56 * 0.8 + 1), reason: '判别配置失效：tight 盒必须高于压缩行盒');

    // 核心（截图 bug）：带必须盖住字形墨迹——下伸部不再残留未选中色
    //（换色 clip 与带共用同一套矩形，带盖住即换色盖住）。
    expect(band.bottom, greaterThanOrEqualTo(tight.bottom), reason: '带必须盖住下伸部墨迹');
    expect(band.top, lessThanOrEqualTo(tight.top), reason: '带必须盖住上伸部墨迹');

    // clamp 垂直放宽：首/末行带合法超出节点盒（浏览器同样画到元素盒外），
    // 垂直若仍按节点盒切，扩张会被刚好切回去。
    expect(band.top, lessThan(0), reason: '首行带顶应超出节点盒');
    expect(band.bottom, greaterThan(render.size.height), reason: '末行带底应超出节点盒');

    // 水平仍走字符 advance 边界（跨字形从中间切开，浏览器口径）。
    expect(band.left, closeTo(tight.left, 0.01));
    expect(band.right, closeTo(tight.right, 0.01));
  });

  testWidgets('lineHeight 1.5（行盒宽裕）：内容区 ⊂ 行盒，带垂直即行盒 strip 零扩张', (tester) async {
    final render = await pumpText(tester, lineHeight: 1.5);
    final painter = (render.content as TextEngine?)!;
    const range = TextRange(start: 3, end: 5);

    final band = painter.adjustedSelectionPaintRectsForRange(range, nodeSize: render.size).single;
    // 行盒 strip = 56×1.5 = 84；内容区（56 高居中）⊂ strip → 并集 = 行盒。
    expect(band.top, closeTo(0, 0.01));
    expect(band.bottom, closeTo(84, 0.01));
  });

  testWidgets('首行 top limit：正常行高只夹回 painter 顶，纯 floor 取整不越界', (tester) async {
    // 13 × 1.55 = 20.15px 时首行 rawTop=-0.15，floor 会凭取整多探出
    // 1px；tight 内容区仍完整落在 painter 盒内，不能把它误判成墨迹溢出。
    final render = await pumpText(tester, fontSize: 13, lineHeight: 1.55, child: 'normal');
    final painter = (render.content as TextEngine?)!;
    final tight = painter.getBoxesForSelectionForTest(0, 6).single.toRect();
    final band = painter
        .adjustedSelectionPaintRectsForRange(const TextRange(start: 0, end: 6), nodeSize: render.size)
        .single;

    expect(tight.top, greaterThan(0), reason: '判别配置失效：正常行高的内容区应在 painter 盒内');
    expect(band.top, closeTo(0, 0.01), reason: '正常行高的首行不得因 rawTop floor 多探出 1px');
  });

  testWidgets('首行 top limit：压缩行高仍保留真实内容区溢出', (tester) async {
    final render = await pumpText(tester, fontSize: 14, lineHeight: 0.8, child: 'My py');
    final painter = (render.content as TextEngine?)!;
    const range = TextRange(start: 3, end: 5);
    final tight = painter.getBoxesForSelectionForTest(range.start, range.end).single.toRect();
    final band = painter.adjustedSelectionPaintRectsForRange(range, nodeSize: render.size).single;

    expect(tight.top, lessThan(0), reason: '判别配置失效：压缩行高下内容区应真实越出 painter 顶');
    expect(band.top, lessThan(0), reason: 'top limit 不得切掉压缩行高的上伸墨迹');
    expect(band.top, lessThanOrEqualTo(tight.top));
  });

  testWidgets('富文本 inline span：部分选中的带同样逐盒盖住墨迹', (tester) async {
    final render = await pumpText(
      tester,
      lineHeight: 0.8,
      child: const [
        'My ',
        ElView(
          style: ElStyle(color: Color(0xff61afef)),
          child: 'py',
        ),
        ' Components',
      ],
    );
    final painter = (render.content as TextEngine?)!;
    const range = TextRange(start: 3, end: 5); // inline span 'py'

    final boxes = painter.getBoxesForSelectionForTest(range.start, range.end);
    final bands = painter.adjustedSelectionPaintRectsForRange(range, nodeSize: render.size);
    expect(bands, hasLength(boxes.length));
    for (var i = 0; i < boxes.length; i++) {
      expect(bands[i].bottom, greaterThanOrEqualTo(boxes[i].toRect().bottom));
      expect(bands[i].top, lessThanOrEqualTo(boxes[i].toRect().top));
    }
  });
}
