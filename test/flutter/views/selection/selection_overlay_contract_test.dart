import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 选中文字换色 overlay 的绘制契约（连续大文本选中性能，2026-08-01 用户报告）：
///
/// Windows 实底蓝+白字需要把选中文字换色绘制。旧实现 partial 分支对每个选中
/// 行带 `clipRect + 重绘**全文** overlay`——3.3 万字文本选中 16 行时每 move
/// 光栅化 16 遍全文（峰值 528 万 glyph），比官方（只画背景色块、不重绘文字）
/// 慢很多倍。
///
/// 契约：partial 换色每帧**至多绘制 1 遍** overlay（选中带并成 path 一次
/// clip，视觉等价——Windows 换色为不透明色，逐行 clip 与并集 clip 结果一致）。
String get paragraph => '''
OpenAI 在 5.6 这一代上太想炫耀它的"全自动多智能体协作"和"直接看渲染画面"的能力了。这就导致：

GPT-5.6 Sol： 像一个汇报工作时 PPT 写得天花乱坠、嘴上说着"我可以派 4 个分身同时干活"，结果一不小心把本地硬盘搞出 Bug 的浮躁员工。

Cursor 的 Auto 模式： 像一个低调的技术主管。它不管外面吹什么新概念，只管把最硬核的任务分给 Fable 5 或者 Grok 4.5，把杂活分给轻量模型，在后台默默把代码码得严丝合缝。

所以，如果你的高频场景是硬核的写代码、修 Bug、理清复杂的局部状态逻辑，直接用 Cursor 开启 Auto 模式，体验绝对会更顺畅。
''';

void main() {
  testWidgets('Windows 换色拖选跨多行：每 move partial 绘制至多 1 遍', semanticsEnabled: false, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 800,
              height: 600,
              child: ElSelectionView(
                child: ElScrollView(
                  controller: controller,
                  children: [ElView(style: const ElStyle(fontSize: 14, lineHeight: 1.5), child: paragraph * 100)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textRender = tester.allRenderObjects.whereType<ElRenderView>().firstWhere(
        (r) => r.textEngineForTest != null,
      );
      final painter = textRender.textEngineForTest!;

      // 斜向拖选跨约 16 行（与性能 probe 同路径），逐 move 采样 partial 绘制增量。
      final gesture = await tester.startGesture(const Offset(30, 40), kind: PointerDeviceKind.mouse);
      await tester.pump();
      var prev = painter.debugSelectionClipRectOverlayCount;
      var maxPerMove = 0;
      for (var i = 1; i <= 40; i++) {
        await gesture.moveTo(Offset.lerp(const Offset(30, 40), const Offset(600, 500), i / 40)!);
        await tester.pump();
        final delta = painter.debugSelectionClipRectOverlayCount - prev;
        prev = painter.debugSelectionClipRectOverlayCount;
        if (delta > maxPerMove) maxPerMove = delta;
      }
      await gesture.up();
      await tester.pump();

      final range = textRender.currentSelectionRange;
      expect(range != null && !range.isCollapsed, isTrue, reason: '拖选未建立');
      // 契约：每帧至多 1 遍 partial 绘制（不随选中行数放大）。
      expect(maxPerMove, lessThanOrEqualTo(1), reason: '每 move 不得重绘全文 N 遍');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
