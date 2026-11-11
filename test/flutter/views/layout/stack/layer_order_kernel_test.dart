import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return Directionality(
    textDirection: .ltr,
    child: Align(
      alignment: .topLeft,
      child: SizedBox(width: 120, height: 120, child: child),
    ),
  );
}

class _LayerProbe extends LeafRenderObjectWidget {
  const _LayerProbe(this.tag, this.paintLog, {super.key});

  final String tag;
  final List<String> paintLog;

  @override
  _RenderLayerProbe createRenderObject(BuildContext context) => _RenderLayerProbe(tag, paintLog);

  @override
  void updateRenderObject(BuildContext context, _RenderLayerProbe renderObject) {
    renderObject
      ..tag = tag
      ..paintLog = paintLog;
  }
}

class _RenderLayerProbe extends RenderBox {
  _RenderLayerProbe(this.tag, this.paintLog);

  String tag;
  List<String> paintLog;
  int layoutCount = 0;

  @override
  void performLayout() {
    layoutCount++;
    size = constraints.constrain(const Size.square(40));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    paintLog.add(tag);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..textDirection = .ltr
      ..label = tag;
  }
}

class _OrderFixture extends StatefulWidget {
  const _OrderFixture({required this.paintLog, super.key});

  final List<String> paintLog;

  @override
  State<_OrderFixture> createState() => _OrderFixtureState();
}

class _OrderFixtureState extends State<_OrderFixture> {
  int firstZ = 0;
  bool showMiddle = true;

  void setFirstZ(int value) => setState(() => firstZ = value);

  void setShowMiddle(bool value) => setState(() => showMiddle = value);

  @override
  Widget build(BuildContext context) {
    return ElStack(
      children: [
        ElPositioned(
          key: const ValueKey('first-positioned'),
          left: 0,
          top: 0,
          zIndex: firstZ,
          child: _LayerProbe('first', widget.paintLog, key: const ValueKey('first')),
        ),
        if (showMiddle)
          ElPositioned(
            key: const ValueKey('middle-positioned'),
            left: 0,
            top: 0,
            zIndex: 2,
            child: _LayerProbe('middle', widget.paintLog, key: const ValueKey('middle')),
          ),
        ElPositioned(
          key: const ValueKey('last-positioned'),
          left: 0,
          top: 0,
          child: _LayerProbe('last', widget.paintLog, key: const ValueKey('last')),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('source order 原位换序后 paint、hit 与 semantics 同帧一致', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final paints = <String>[];
      await tester.pumpWidget(
        _app(
          ElStack(
            children: [
              _LayerProbe('first', paints, key: const ValueKey('first')),
              _LayerProbe('last', paints, key: const ValueKey('last')),
            ],
          ),
        ),
      );
      final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
      final first = tester.renderObject<_RenderLayerProbe>(find.byKey(const ValueKey('first')));
      final last = tester.renderObject<_RenderLayerProbe>(find.byKey(const ValueKey('last')));
      final element = tester.element(find.byKey(const ValueKey('first')));
      final layouts = first.layoutCount + last.layoutCount;
      paints.clear();
      stack.setChildStackSourceOrder(first, 2);
      await tester.pump();
      expect(paints, ['last', 'first']);
      final hit = BoxHitTestResult();
      expect(stack.hitTest(hit, position: const Offset(10, 10)), isTrue);
      expect(hit.path.first.target, same(first));
      final semanticOrder = <RenderObject>[];
      stack.visitChildrenForSemantics(semanticOrder.add);
      expect(semanticOrder, [last, first]);
      expect(first.layoutCount + last.layoutCount, layouts);
      expect(tester.element(find.byKey(const ValueKey('first'))), same(element));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('强制层序刷新隐藏 child 后真实命中不穿过负层', (tester) async {
    final paints = <String>[];
    await tester.pumpWidget(_app(ElStack(children: [_LayerProbe('single', paints, key: const ValueKey('single'))])));
    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
    final child = tester.renderObject<_RenderLayerProbe>(find.byKey(const ValueKey('single')));
    final layouts = child.layoutCount;
    (child.parentData! as ElStackParentData).zIndex = -1;
    stack.markNeedsPaintOrder();
    paints.clear();
    await tester.pump();
    expect(paints, isEmpty);
    expect(stack.hitTest(BoxHitTestResult(), position: const Offset(10, 10)), isFalse);
    expect(child.layoutCount, layouts);
  });

  testWidgets('显式层序连续 120 帧未跨序只改数值，不 layout 或 repaint', (tester) async {
    final key = GlobalKey<_OrderFixtureState>();
    final paints = <String>[];
    await tester.pumpWidget(_app(_OrderFixture(key: key, paintLog: paints)));
    key.currentState!.setFirstZ(5);
    await tester.pump();
    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
    final first = tester.renderObject<_RenderLayerProbe>(find.byKey(const ValueKey('first')));
    final element = tester.element(find.byKey(const ValueKey('first')));
    final order = stack.explicitStackPaintOrder;
    final resolves = stack.debugLayerOrderRebuildCount;
    final layouts = first.layoutCount;
    paints.clear();
    for (var frame = 0; frame < 120; frame++) {
      key.currentState!.setFirstZ(6 + frame);
      await tester.pump(const Duration(microseconds: 8333));
      expect(stack.explicitStackPaintOrder, same(order));
    }
    expect(stack.debugLayerOrderRebuildCount, resolves);
    expect(first.layoutCount, layouts);
    expect(paints, isEmpty);
    expect(tester.element(find.byKey(const ValueKey('first'))), same(element));
  });

  testWidgets('zIndex 更新保持 child identity 且不触发布局', (tester) async {
    final fixtureKey = GlobalKey<_OrderFixtureState>();
    final paintLog = <String>[];
    await tester.pumpWidget(_app(_OrderFixture(key: fixtureKey, paintLog: paintLog)));

    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
    final first = tester.renderObject<_RenderLayerProbe>(find.byKey(const ValueKey('first')));
    final element = tester.element(find.byKey(const ValueKey('first')));
    final layoutCount = first.layoutCount;

    fixtureKey.currentState!.setFirstZ(5);
    await tester.pump();

    expect(tester.element(find.byKey(const ValueKey('first'))), same(element));
    expect(tester.renderObject(find.byKey(const ValueKey('first'))), same(first));
    expect(first.layoutCount, layoutCount);
    expect(stack.debugChildrenInPaintOrder.map((child) => (child as _RenderLayerProbe).tag), [
      'last',
      'middle',
      'first',
    ]);
  });

  testWidgets('同一帧连续更新只按最终 zIndex 重算一次', (tester) async {
    final fixtureKey = GlobalKey<_OrderFixtureState>();
    final paintLog = <String>[];
    await tester.pumpWidget(_app(_OrderFixture(key: fixtureKey, paintLog: paintLog)));
    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
    final before = stack.debugLayerOrderRebuildCount;

    fixtureKey.currentState!
      ..setFirstZ(5)
      ..setFirstZ(-3)
      ..setFirstZ(1);
    await tester.pump();

    expect(stack.debugLayerOrderRebuildCount - before, 1);
    expect(stack.debugChildrenInPaintOrder.map((child) => (child as _RenderLayerProbe).tag), [
      'last',
      'first',
      'middle',
    ]);
  });

  testWidgets('child remove 和 insert 都精确失效排序缓存', (tester) async {
    final fixtureKey = GlobalKey<_OrderFixtureState>();
    final paintLog = <String>[];
    await tester.pumpWidget(_app(_OrderFixture(key: fixtureKey, paintLog: paintLog)));
    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
    var before = stack.debugLayerOrderRebuildCount;

    fixtureKey.currentState!.setShowMiddle(false);
    await tester.pump();
    expect(stack.debugLayerOrderRebuildCount - before, 0, reason: '恢复 sibling 顺序后直接遍历，不再解析排序缓存');
    expect(stack.debugChildrenInPaintOrder.map((child) => (child as _RenderLayerProbe).tag), ['first', 'last']);

    before = stack.debugLayerOrderRebuildCount;
    fixtureKey.currentState!.setShowMiddle(true);
    await tester.pump();
    expect(stack.debugLayerOrderRebuildCount - before, 1);
    expect(stack.debugChildrenInPaintOrder.map((child) => (child as _RenderLayerProbe).tag), [
      'first',
      'last',
      'middle',
    ]);
  });

  testWidgets('非零 zIndex 恢复全零后重新进入挂载序快路径', (tester) async {
    final fixtureKey = GlobalKey<_OrderFixtureState>();
    final paintLog = <String>[];
    await tester.pumpWidget(_app(_OrderFixture(key: fixtureKey, paintLog: paintLog)));
    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
    expect(stack.debugUsesDefaultLayerOrder, isFalse, reason: 'middle 的 zIndex=2 会启用显式排序');

    fixtureKey.currentState!
      ..setShowMiddle(false)
      ..setFirstZ(0);
    await tester.pump();

    expect(stack.debugUsesDefaultLayerOrder, isTrue);
    expect(stack.debugChildrenInPaintOrder.map((child) => (child as _RenderLayerProbe).tag), ['first', 'last']);
  });

  testWidgets('paint 与 semantics 读取同一份排序快照', (tester) async {
    final handle = tester.ensureSemantics();
    final paintLog = <String>[];
    await tester.pumpWidget(_app(_OrderFixture(paintLog: paintLog)));
    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));

    expect(paintLog, ['first', 'last', 'middle']);
    final semanticOrder = <String>[];
    stack.visitChildrenForSemantics((child) => semanticOrder.add((child as _RenderLayerProbe).tag));
    expect(semanticOrder, paintLog);
    expect(stack.debugChildrenInPaintOrder.map((child) => (child as _RenderLayerProbe).tag), paintLog);
    handle.dispose();
  });

  testWidgets('zIndex < 0 保留布局但不绘制、不命中、不进入语义', (tester) async {
    final handle = tester.ensureSemantics();
    final paintLog = <String>[];
    await tester.pumpWidget(
      _app(
        ElStack(
          children: [
            ElPositioned(
              left: 0,
              top: 0,
              zIndex: -1,
              child: _LayerProbe('hidden', paintLog, key: const ValueKey('hidden')),
            ),
          ],
        ),
      ),
    );

    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
    final hidden = tester.renderObject<_RenderLayerProbe>(find.byKey(const ValueKey('hidden')));
    expect(hidden.layoutCount, 1, reason: '负层只隐藏呈现，不销毁或跳过布局');
    expect(paintLog, isEmpty);
    expect(stack.debugChildrenInPaintOrder, isEmpty);
    expect(stack.paintsChild(hidden), isFalse);

    final hit = BoxHitTestResult();
    expect(stack.hitTest(hit, position: const Offset(10, 10)), isFalse);
    final semanticChildren = <RenderObject>[];
    stack.visitChildrenForSemantics(semanticChildren.add);
    expect(semanticChildren, isEmpty);
    handle.dispose();
  });
}
