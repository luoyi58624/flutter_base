// GlobalKey 重挂 × 嵌套焦点子树 —— activate 期后代遍历回归。
//
// 真机现场（Android 预测性返回）：路由过渡包装变化触发 GlobalKey retake，
// _activateRecursively 自顶向下 activate；父 ViewElement.activate 若在此刻
// 遍历后代做 _reparentFocusNode（visitAncestorElements），后代还处于
// inactive 态 → "Looking up a deactivated widget's ancestor is unsafe" →
// inflateWidget 把子树打成 failed 态 → 后续帧连环
// "_elements.contains(element)" / "renderObject of inactive element"。
//
// 本测直接模拟最小等价路径：带 GlobalKey 的嵌套焦点子树整体换父。

import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GlobalKey 重挂嵌套焦点子树不抛 deactivated-ancestor', (tester) async {
    final subtreeKey = GlobalKey();
    final outerNode = FocusNode(debugLabel: 'reparent-outer');
    final middleNode = FocusNode(debugLabel: 'reparent-middle');
    final innerNode = FocusNode(debugLabel: 'reparent-inner');
    addTearDown(outerNode.dispose);
    addTearDown(middleNode.dispose);
    addTearDown(innerNode.dispose);

    // 三层嵌套，每层都有焦点节点（activate 时每层都会 _reparentFocusNode）。
    Widget subtree() => ElView(
      key: subtreeKey,
      focusNode: outerNode,
      style: const ElStyle(
        padding: EdgeInsets.all(8),
        onFocusVisible: ElStyle(outline: ElOutline(outlineColor: Colors.blue, outlineWidth: 2)),
      ),
      child: ElView(
        focusNode: middleNode,
        style: const ElStyle(padding: EdgeInsets.all(8)),
        child: ElView(
          focusNode: innerNode,
          style: const ElStyle(width: 40, height: 20, backgroundColor: Colors.white),
        ),
      ),
    );

    Widget host({required bool wrapped}) => MaterialApp(
      home: Scaffold(
        // 换一层包装（真机上是预测性返回改变路由过渡包装形状）→
        // 结构差异迫使 GlobalKey 子树走 deactivate → retake → activate。
        body: wrapped
            ? Center(
                child: Padding(padding: const EdgeInsets.all(4), child: subtree()),
              )
            : Align(alignment: Alignment.topLeft, child: subtree()),
      ),
    );

    await tester.pumpWidget(host(wrapped: false));
    expect(tester.takeException(), isNull);

    // 来回换父两次（三层都传入 focusNode，每层持有 FocusNode attachment，
    // activate 期的 _reparentFocusNode 有真实工作量）
    await tester.pumpWidget(host(wrapped: true));
    expect(tester.takeException(), isNull, reason: '重挂 #1 不应抛异常');
    await tester.pumpWidget(host(wrapped: false));
    expect(tester.takeException(), isNull, reason: '重挂 #2 不应抛异常');

    // 树健康：还能正常聚焦
    await tester.pump();
    expect(find.byKey(subtreeKey), findsOneWidget);
  });
}
