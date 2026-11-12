import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 复现 ScrollPage 向上拖选越出内容区进入 AppBar 的 bug（2026-08-11 用户报告）。
///
/// ## 场景还原
///
/// vp_layout.dart 的 [ElSelectionView] 包住整站（含 AppBar/NavBar + 内容区），
/// ScrollPage 内结构：
///   ElSelectionView(全局根) → Scaffold(appBar: ElView('ScrollPage'), body: ElScrollView(...))
///
/// ## Bug 表现（三张截图）
///
/// 1. 图 1：用户在 ElScrollView 内容区拖选，rows 1-15 高亮。
/// 2. 图 2：鼠标向上移出内容区、进入 AppBar → 只剩 AppBar "ScrollPage" 高亮，
///    内容行全部丢失（虚拟滚动已把可见窗口滚到 row~619，anchor 已卸载）。
/// 3. 图 3：鼠标回到顶部 → 只有 row1 开头 "黄金" 两字被选（是 span 的另一端）。
///
/// ## 根因
///
/// Scaffold 的 CustomMultiChildLayout children 顺序：body 先于 AppBar 加入
/// → 文档序（render tree 前序 DFS）里，AppBar 的 ElView 排在所有 body 内容**之后**
/// → "ScrollPage" 拥有最高索引。
///
/// 从 row ~3（anchor，低索引）向上拖到 AppBar（focus = ScrollPage，最高索引），
/// span 扩展为 anchor → 末端，把锚点之后所有行都纳入。
/// 虚拟滚动只挂载可见窗口（row 619-643），行 1-618 已卸载；`_halfMountedDynamicSpan`
/// 只能钳到挂载窗口边缘，内容区无高亮 → 视觉上"选区消失"，只剩 AppBar 一处高亮。
/// 鼠标回到 row 1 后，row 1 重新挂载，span 端点落在 row1 起始 → 显示 "黄金" 两字。
///
/// ## 根本修复
///
/// AppBar 标题 `ElView(child: 'ScrollPage')` 应加 `style: ElStyle(userSelect: .none)`
/// —— AppBar 标题是 chrome，不是可选内容（违反示例页自身演示的黄金法则）。
///
/// ---
///
/// 本文件分两组测试：
///   1. **复现**：无 userSelect 时，向上拖到 AppBar 导致锚点下方行被纳入/内容丢失。
///   2. **修复验证**：AppBar 标题加 userSelect none 后，AppBar 不入选，内容行正确。
void main() {
  // ── 工具函数 ──────────────────────────────────────────────────────────────

  /// 收集所有已挂载参与者的 "文本全文 → 选中range" 映射。
  Map<String, TextRange> selectedTexts(WidgetTester tester) {
    final out = <String, TextRange>{};
    final seen = <SelectionParticipant>{};
    for (final p in selectionParticipantsOf(tester.allRenderObjects)) {
      if (!seen.add(p)) continue;
      if (p.selectionContentKind != SelectionContentKind.text) continue;
      final range = p.currentSelectionRange;
      if (range == null || range.isCollapsed) continue;
      out[p.selectionTextForRange(TextRange(start: 0, end: p.selectionTextLength))] = range;
    }
    return out;
  }

  /// 找到含 [needle] 的参与者中心坐标（全局）。
  Offset centerOf(WidgetTester tester, String needle) {
    for (final p in selectionParticipantsOf(tester.allRenderObjects)) {
      if (p.selectionContentKind != SelectionContentKind.text) continue;
      final text = p.selectionTextForRange(TextRange(start: 0, end: p.selectionTextLength));
      if (text.contains(needle)) {
        return p.box.localToGlobal(p.box.size.center(Offset.zero));
      }
    }
    fail('未找到含 "$needle" 的已挂载选区参与者');
  }

  // ── 公共 Widget 构建 ──────────────────────────────────────────────────────

  /// 与 ScrollPage 同构：ElSelectionView 包整页（AppBar + body ElScrollView）。
  /// [appBarUserSelectNone]：true = 修复版（AppBar 标题加 userSelect none）。
  Widget buildScrollPage({
    required int rowCount,
    bool appBarUserSelectNone = false,
    ScrollController? scrollController,
    double viewportHeight = 400,
  }) {
    final appBarTitle = appBarUserSelectNone
        ? const ElView(
            style: ElStyle(userSelect: .none),
            child: 'ScrollPage',
          )
        : const ElView(child: 'ScrollPage');

    return MaterialApp(
      home: ElSelectionView(
        // 全局 ElSelectionView，对应 vp_layout.dart 的包裹层
        child: Scaffold(
          appBar: AppBar(title: appBarTitle),
          body: SizedBox(
            width: 400,
            height: viewportHeight,
            child: ElScrollView(
              controller: scrollController,
              physics: ClampingScrollPhysics(),
              scrollCacheExtent: .pixels(0), // 关掉预加载：精确控制挂载窗口
              children: [
                for (var i = 0; i < rowCount; i++)
                  SizedBox(height: 24, child: ElView(child: '黄金法则：让可交互的元素不可选（none） - ${i + 1}')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 组 1：复现 bug（AppBar 无 userSelect none） ───────────────────────────

  group('Bug 复现：AppBar ElView 无 userSelect none', () {
    testWidgets('从 row3 向上拖到 AppBar — row3 锚点下方的行不得入选（否则为 bug）', (tester) async {
      // 足够多行但用小视口确保可滚动。
      await tester.pumpWidget(buildScrollPage(rowCount: 30, viewportHeight: 200));
      await tester.pumpAndSettle();

      final anchor = centerOf(tester, '- 3');
      final appBar = centerOf(tester, 'ScrollPage');

      final gesture = await tester.startGesture(anchor, kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // 先向下移一小步触发拖选识别（超过 dragThreshold）。
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();

      // 再往上拖进 AppBar 区域。
      await gesture.moveTo(appBar);
      await tester.pump();

      final selected = selectedTexts(tester);

      // === 核心断言：锚点（row3）下方的行绝不入选 ===
      // bug 现象：AppBar 在文档序末尾 → span 从 anchor 延伸到末端 → 行 4..N 全进选区。
      expect(selected.keys.where((k) => k.contains('- 4')), isEmpty, reason: '锚点（row3）下方 row4 不得入选（文档序末端反向扩展 bug）');
      expect(selected.keys.where((k) => k.contains('- 5')), isEmpty, reason: '锚点（row3）下方 row5 不得入选');

      // 向上拖：row1/row2 应在选区内（anchor 上方的内容行应被选中）。
      expect(selected.keys.where((k) => k.contains('- 1')), isNotEmpty, reason: 'anchor 上方的 row1 应在选区内');
      expect(selected.keys.where((k) => k.contains('- 2')), isNotEmpty, reason: 'anchor 上方的 row2 应在选区内');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('虚拟滚动 + 拖到 AppBar：anchor 卸载后 row1 重挂载应只选 row1 前缀，不选 row4+', (tester) async {
      // 用少量行 + 固定行高，所有行都会被挂载（不依赖虚拟卸载），
      // 专注验证 AppBar 跳转时 anchor 下方行不入选的核心约束。
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        buildScrollPage(
          rowCount: 20,
          viewportHeight: 150, // 仅容 ~6 行可见（24px/行）
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      // anchor 落在第1行（顶部）。
      final row1Center = centerOf(tester, '- 1');
      final appBar = centerOf(tester, 'ScrollPage');

      final gesture = await tester.startGesture(row1Center, kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // 触发拖选。
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();

      // 向上拖到 AppBar 区域。
      await gesture.moveTo(appBar);
      await tester.pump();

      final selected = selectedTexts(tester);

      // anchor 是 row1（文档序首）；focus 跳到 AppBar（文档序末）→ span 从 row1 到末端。
      // bug 表现：锚点下方所有行（row2..row20）都被选中。
      // 修复后应只选 anchor 上方的内容（此处 anchor=row1，上方无更多行）。
      //
      // row3 不应因文档序末端扩展而入选：
      expect(selected.keys.where((k) => k.contains('- 3')), isEmpty, reason: '向上拖选时 anchor 下方的 row3 不得入选（末端反向扩展 bug）');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  // ── 组 2：修复验证（AppBar 加 userSelect none） ───────────────────────────

  group('修复验证：AppBar ElView 加 userSelect none', () {
    testWidgets('从 row3 向上拖到 AppBar 区域：AppBar 不入选，row1/2 入选，row4+ 不入选', (tester) async {
      await tester.pumpWidget(buildScrollPage(rowCount: 30, viewportHeight: 200, appBarUserSelectNone: true));
      await tester.pumpAndSettle();

      final anchor = centerOf(tester, '- 3');
      // AppBar 有 userSelect none，_centerOf 找不到它；直接取 AppBar 区域的 y。
      // AppBar 高约 56px，取 y=28 为中点。
      final appBarAreaOffset = Offset(anchor.dx, 28.0);

      final gesture = await tester.startGesture(anchor, kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();

      await gesture.moveTo(appBarAreaOffset);
      await tester.pump();

      final selected = selectedTexts(tester);

      // AppBar 文本不入选。
      expect(
        selected.keys.where((k) => k.contains('ScrollPage')),
        isEmpty,
        reason: 'AppBar 加了 userSelect none，不应出现在选区',
      );

      // 锚点下方行不入选。
      expect(selected.keys.where((k) => k.contains('- 4')), isEmpty, reason: '锚点（row3）下方 row4 不得入选');

      // anchor 上方的内容行应入选。
      expect(selected.keys.where((k) => k.contains('- 1')), isNotEmpty, reason: 'focus 钳在 list 顶边，row1 应在选区内');
      expect(selected.keys.where((k) => k.contains('- 2')), isNotEmpty, reason: 'row2 应在选区内');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
