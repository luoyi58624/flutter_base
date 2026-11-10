import 'package:flutter_base/src/flutter/views/layout/stack/stack_view.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('共享基座接受官方和 El 定位声明', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: _Host(
          children: [
            ElPositioned(
              left: '25%',
              top: 12,
              width: 40,
              height: 30,
              child: SizedBox(key: ValueKey('el')),
            ),
            Positioned(right: 8, bottom: 10, width: 20, height: 24, child: SizedBox(key: ValueKey('official'))),
          ],
        ),
      ),
    );
    final render = tester.renderObject<_RenderHost>(find.byType(_Host));
    final child = tester.renderObject<RenderBox>(find.byKey(const ValueKey('el')));
    expect(child.parent, same(render));
    expect(child.parentData, isA<ElStackParentData>());
    expect(tester.getTopLeft(find.byKey(const ValueKey('el'))), const Offset(200, 12));
    expect(tester.getBottomRight(find.byKey(const ValueKey('official'))), const Offset(792, 590));
  });

  testWidgets('有序非零层级零排序，换层不 layout 或更换 RenderObject', (tester) async {
    Widget build(int z) => Directionality(
      textDirection: TextDirection.ltr,
      child: _Host(
        children: [
          ElPositioned(
            zIndex: z,
            child: const SizedBox(key: ValueKey('a'), width: 30, height: 30),
          ),
          const ElPositioned(zIndex: 10, child: SizedBox(key: ValueKey('b'), width: 30, height: 30)),
        ],
      ),
    );
    await tester.pumpWidget(build(0));
    final render = tester.renderObject<_RenderHost>(find.byType(_Host));
    final child = tester.renderObject<RenderBox>(find.byKey(const ValueKey('a')));
    final layouts = render.layouts;
    expect(render.debugUsesDefaultLayerOrder, isTrue);
    final resolves = render.debugLayerOrderRebuildCount;
    await tester.pumpWidget(build(5));
    expect(render.layouts, layouts);
    expect(render.debugUsesDefaultLayerOrder, isTrue);
    expect(render.debugLayerOrderRebuildCount, resolves);
    await tester.pumpWidget(build(11));
    expect(render.layouts, layouts);
    expect(tester.renderObject(find.byKey(const ValueKey('a'))), same(child));
    expect(render.debugChildrenInPaintOrder.last, same(child));
    await tester.pumpWidget(build(-1));
    expect(render.debugChildrenInPaintOrder, isNot(contains(child)));
    expect(render.layouts, layouts);
  });
}

class _Host extends MultiChildRenderObjectWidget {
  const _Host({required super.children});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHost();
}

class _RenderHost extends RenderStackingBox<ElStackParentData> {
  int layouts = 0;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ElStackParentData) child.parentData = ElStackParentData();
  }

  @override
  void performLayout() {
    layouts++;
    size = constraints.biggest;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as ElStackParentData;
      data.resolveDimensions(size);
      if (data.isPositionedForLayout) {
        RenderStack.layoutPositionedChild(child, data, size, Alignment.topLeft);
      } else {
        child.layout(constraints.loosen(), parentUsesSize: true);
      }
      child = data.nextSibling;
    }
  }

  @override
  Rect get selfHitRect => Offset.zero & size;
  @override
  bool get clipsHitBounds => true;
  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {}
}
