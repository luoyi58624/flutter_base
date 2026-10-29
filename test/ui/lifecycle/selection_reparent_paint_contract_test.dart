import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 普通 GlobalKey 重挂保留原参与者、当前范围与高亮。
/// 每个重挂完成帧直接读取无副作用的官方范围，并实际执行正文 paint 检查高亮矩形。
/// 覆盖拖动中、松手后与程序全选；不恢复已销毁节点的历史状态。
void main() {
  const stageText =
      '把这段文字按住拖选可以选中：alpha bravo charlie delta echo foxtrot golf hotel '
      'india juliet kilo lima mike november oscar papa quebec romeo sierra tango uniform。';

  const textKey = ValueKey<String>('reparent-demo-selectable-text');

  /// 演示区外壳。`ElApp / ElScaffold / ElAppBar` 在上层组件包里、el_ui 拿不到，
  /// 已实测换成 MaterialApp + 裸 ElScrollView 后契约照旧成立（关掉修复仍会红），
  /// 故此处用等价物；其余结构与 demo 一字不差。
  Widget demoApp({required int generation, required GlobalKey stage, required ElSelectionController selection}) {
    return MaterialApp(
      home: ElScrollView(
        children: [
          ElView(
            style: const ElStyle(padding: .all(12)),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 8,
              children: [
                const ElView(
                  style: ElStyle(fontWeight: .w600),
                  child: '文本拖选',
                ),
                const ElView(style: ElStyle(fontSize: 12), child: '把这段文字拖选，观察选区是否在中途断开。'),
                ElView(
                  style: const ElStyle(height: 140),
                  child: KeyedSubtree(
                    key: ValueKey(generation),
                    child: RepaintBoundary(
                      key: stage,
                      child: ElSelectionView(
                        controller: selection,
                        child: const ElView(key: textKey, child: stageText),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 把正文 offset 换算成屏幕坐标（从正文自己的 key 取 render，不全局扫文本节点——
  /// 壳里还有标题、提示两个带文字的 render）。
  Offset Function(int) textPosGetter(WidgetTester tester) {
    final participant = tester.renderObject<ElRenderView>(find.byKey(textKey));
    return (int offset) {
      final line = participant.selectionLineGeometryAt(offset)!;
      final caret = participant.selectionCaretGeometryAt(offset)!;
      return participant.localToGlobal(Offset(caret.position.dx + 1, line.lineTop + line.lineHeight / 2));
    };
  }

  RenderSelectionView selectionRoot(WidgetTester tester) =>
      tester.allRenderObjects.whereType<RenderSelectionView>().first;

  /// 在实际完成布局的每一帧验证正文绘制，不依赖旧根的范围缓存计数。
  int Function() probeSampler(WidgetTester tester) {
    var paintedFrames = 0;
    return () {
      if (selectionRoot(tester).resolveSelectionInfo() == null) return paintedFrames;
      final render = tester.renderObject<ElRenderView>(find.byKey(textKey));
      expect(render.currentSelectionRange?.isCollapsed, isFalse, reason: '当前帧必须保有正文的官方范围');
      expect(render, paints..rect(color: render.selectionColor), reason: '当前帧正文必须实际画出选中背景');
      return ++paintedFrames;
    };
  }

  void expectNoBlankPaintFrame(int paintedFrames, {required String scene}) {
    expect(paintedFrames, greaterThan(0), reason: '$scene：必须实际验证过已选正文的绘制');
  }

  /// 换一次父（整棵树 rebuild），并断言 element / RenderObject 被认领回来、没被重建。
  Future<void> reparent(
    WidgetTester tester,
    StateSetter rebuild,
    void Function() bump,
    GlobalKey stage,
    int nth,
  ) async {
    final element = stage.currentContext!;
    final render = element.findRenderObject()!;
    rebuild(bump);
    await tester.pump();
    expect(stage.currentContext, same(element), reason: '第 $nth 次换父后 element 换了——那是重建，不是重挂');
    expect(stage.currentContext!.findRenderObject(), same(render), reason: '第 $nth 次换父后 render 换了实例');
  }

  // ---------------------------------------------------------------------------
  // 拖动中重挂
  // ---------------------------------------------------------------------------

  testWidgets('文本拖选中途重挂：选区左端固定、右端只增不减，且一帧都不空画', (tester) async {
    final selection = ElSelectionController();
    final stage = GlobalKey();
    var generation = 0;
    StateSetter? rebuild;
    var reparents = 0;
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return demoApp(generation: generation, stage: stage, selection: selection);
        },
      ),
    );
    await tester.pumpAndSettle();

    final textPos = textPosGetter(tester);
    final sample = probeSampler(tester);

    final gesture = await tester.startGesture(textPos(0), kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await tester.pump();

    String? anchor;
    var lastLength = 0;
    var lastEndDy = double.nan;
    for (var i = 1; i <= 60; i++) {
      await gesture.moveTo(textPos(i));
      await tester.pump(const Duration(milliseconds: 16));
      if (i % 20 == 0) {
        await reparent(tester, rebuild!, () => generation++, stage, ++reparents);
      }
      sample();

      final now = selection.text;
      if (now == null || now.isEmpty) {
        // 起手头几步还没越过拖选阈值，本来就没有选区；只有"建立之后又消失"才是 bug。
        if (anchor != null) {
          fail('第 $i 步：拖选过程中选区消失——重挂不得打断在途手势（已重挂 $reparents 次）');
        }
        continue;
      }
      anchor ??= now;
      if (!now.startsWith(anchor)) {
        fail(
          '第 $i 步：选区左端被移动——锚点应固定在起手处。'
          'anchor="$anchor" now="$now"（已重挂 $reparents 次）',
        );
      }
      if (now.length < lastLength) {
        fail(
          '第 $i 步：选区回退——右端只应随指针前进。'
          'last=$lastLength now=${now.length} now="$now"（已重挂 $reparents 次）',
        );
      }
      lastLength = now.length;

      // 端点几何逐帧跟手：指针一帧只走一个字，端点纵坐标最多挪一行；
      // 某帧突然跳到文档末尾 = 绑在旧树上的那一端被丢掉了。
      final endpoints = selectionRoot(tester).endpoints;
      if (endpoints != null) {
        final dy = endpoints.end.globalPosition.dy;
        if (!lastEndDy.isNaN && (dy - lastEndDy).abs() > endpoints.end.lineHeight * 1.5) {
          fail(
            '第 $i 步：端点纵坐标跳变 dy=$dy last=$lastEndDy lineH=${endpoints.end.lineHeight}'
            '（已重挂 $reparents 次）',
          );
        }
        lastEndDy = dy;
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(anchor, isNotNull, reason: '整个拖动过程必须建起过选区');
    expect(reparents, greaterThanOrEqualTo(3), reason: '本用例必须真的跨过多次重挂');
    expectNoBlankPaintFrame(sample(), scene: '拖动中重挂');
  }, timeout: const Timeout(Duration(seconds: 60)));

  // ---------------------------------------------------------------------------
  // 松手后（选区保留、非拖动）重挂——历史上闪得最凶的一幕
  // ---------------------------------------------------------------------------

  testWidgets('拖选松手后（选区保留）重挂：一帧都不许空画', (tester) async {
    final selection = ElSelectionController();
    final stage = GlobalKey();
    var generation = 0;
    StateSetter? rebuild;
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return demoApp(generation: generation, stage: stage, selection: selection);
        },
      ),
    );
    await tester.pumpAndSettle();

    final textPos = textPosGetter(tester);
    final sample = probeSampler(tester);

    final gesture = await tester.startGesture(textPos(0), kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await tester.pump();
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(textPos(i));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final logical = selection.text;
    expect(logical, isNotNull, reason: '前置：松手后选区应当保留');
    expect(logical!.length, greaterThan(1), reason: '前置：要有足够长的选区');
    sample();

    // 指针早已抬起（非拖动），选区还在，此时重挂就是那一幕。
    for (var g = 1; g <= 6; g++) {
      rebuild!(() => generation++);
      await tester.pump();
      sample();
      expect(selection.text, logical, reason: '第 $g 次重挂后逻辑选区变了——重挂不得改动已有选区');
      await tester.pump(const Duration(milliseconds: 16));
      sample();
    }

    expectNoBlankPaintFrame(sample(), scene: '松手后重挂');
  }, timeout: const Timeout(Duration(seconds: 60)));

  // ---------------------------------------------------------------------------
  // 程序化选区（无指针参与）
  // ---------------------------------------------------------------------------

  testWidgets('程序化选区后重挂：一帧都不许空画', (tester) async {
    final selection = ElSelectionController();
    final stage = GlobalKey();
    var generation = 0;
    StateSetter? rebuild;
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return demoApp(generation: generation, stage: stage, selection: selection);
        },
      ),
    );
    await tester.pumpAndSettle();

    final sample = probeSampler(tester);

    selection.selectAll();
    await tester.pumpAndSettle();
    final logical = selection.text;
    expect(logical, isNotNull, reason: '前置：全选应建立选区');
    sample();

    for (var g = 1; g <= 4; g++) {
      rebuild!(() => generation++);
      await tester.pump();
      sample();
      expect(selection.text, logical, reason: '第 $g 次重挂后全选选区变了');
      await tester.pump(const Duration(milliseconds: 16));
      sample();
    }

    expectNoBlankPaintFrame(sample(), scene: '程序化选区重挂');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
