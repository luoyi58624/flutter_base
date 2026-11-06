import 'package:flutter/widgets.dart';
import 'package:flutter_base/view.dart' as view;
import 'package:flutter_test/flutter_test.dart';

Widget _host(view.ElView root, {Key? key}) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: view.ElRootView(key: key, root: root),
  ),
);

RenderBox _render(WidgetTester tester) => tester.renderObject(find.byType(view.ElRootView));

void main() {
  testWidgets('样式映射、垂直排列和内外边距形成正确的矩形', (tester) async {
    final root = view.ElView(
      style: view.ElStyle(width: 140, bgColor: Color(0xFFEEEEEE), padding: .all(10), margin: .all(4)),
    );
    final first = view.ElView(
      style: view.ElStyle(width: 50, height: 20, margin: .all(2), bgColor: Color(0xFFFF0000)),
    );
    final second = view.ElView(
      style: view.ElStyle(height: 12, margin: .only(top: 3, bottom: 5), bgColor: Color(0xFF0000FF)),
    );
    root
      ..add(first)
      ..add(second);
    await tester.pumpWidget(_host(root));

    expect(root.size, Size(140, 64));
    expect(_render(tester).size, Size(148, 72));
    expect(first.size, Size(50, 20));
    expect(first.offset, Offset(12, 12));
    expect(second.size, Size(120, 12));
    expect(second.offset, Offset(10, 37));
    expect(
      _render(tester),
      paints
        ..rect(rect: Rect.fromLTWH(4, 4, 140, 64), color: Color(0xFFEEEEEE))
        ..rect(rect: Rect.fromLTWH(16, 16, 50, 20), color: Color(0xFFFF0000))
        ..rect(rect: Rect.fromLTWH(14, 41, 120, 12), color: Color(0xFF0000FF)),
    );
  });

  testWidgets('颜色只标记重绘，几何修改标记布局，相同值不请求帧', (tester) async {
    final child = view.ElView(style: view.ElStyle(width: 40, height: 20, bgColor: Color(0xFFFF0000)));
    final root = view.ElView()..add(child);
    var builds = 0;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          builds++;
          return _host(root);
        },
      ),
    );
    final render = _render(tester);
    child.bgColor = Color(0xFF0000FF);
    expect(render.debugNeedsLayout, isFalse);
    expect(render.debugNeedsPaint, isTrue);
    await tester.pump();
    expect(builds, 1);
    expect(render, paints..rect(color: Color(0xFF0000FF)));

    child
      ..bgColor = Color(0xFF0000FF)
      ..width = 40
      ..height = 20
      ..margin = .zero
      ..padding = .zero;
    expect(render.debugNeedsLayout, isFalse);
    expect(render.debugNeedsPaint, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);

    child.width = 60;
    expect(render.debugNeedsLayout, isTrue);
    await tester.pump();
    expect(child.size.width, 60);
    child.height = 30;
    expect(render.debugNeedsLayout, isTrue);
    await tester.pump();
    expect(root.size.height, 30);
    child.margin = .all(3);
    expect(render.debugNeedsLayout, isTrue);
    await tester.pump();
    expect(root.size.height, 36);
    root.padding = .all(7);
    expect(render.debugNeedsLayout, isTrue);
    await tester.pump();
    expect(root.size.height, 50);
    expect(child.offset, Offset(10, 10));
    expect(builds, 1);
  });

  testWidgets('同一个 key 重建宿主保留首次 root，换 key 才替换', (tester) async {
    final first = view.ElView(style: view.ElStyle(width: 40, height: 20, bgColor: Color(0xFFFF0000)));
    final second = view.ElView(style: view.ElStyle(width: 90, height: 50, bgColor: Color(0xFF0000FF)));
    await tester.pumpWidget(_host(first, key: ValueKey('root')));
    final render = _render(tester);
    await tester.pumpWidget(_host(second, key: ValueKey('root')));
    expect(_render(tester), same(render));
    expect(render.size, Size(40, 20));
    first.width = 60;
    await tester.pump();
    expect(render.size, Size(60, 20));
    expect(render, paints..rect(color: Color(0xFFFF0000)));
    await tester.pumpWidget(_host(second, key: ValueKey('other-root')));
    expect(_render(tester), isNot(same(render)));
    expect(_render(tester).size, Size(90, 50));
  });

  testWidgets('增删子树始终只占一个 Element 和 RenderBox', (tester) async {
    final root = view.ElView();
    await tester.pumpWidget(_host(root));
    final render = _render(tester);
    final element = tester.element(find.byType(view.ElRootView));
    for (var i = 0; i < 100; i++) {
      root.add(view.ElView(style: view.ElStyle(height: 2)));
    }
    await tester.pump();
    expect(root.childCount, 100);
    expect(root.size.height, 200);
    var elements = 0;
    var renders = 0;
    element.visitChildElements((_) => elements++);
    render.visitChildren((_) => renders++);
    expect(elements, 0);
    expect(renders, 0);
    final child = root.children.first;
    expect(child.parent, same(root));
    expect(root.remove(child), isTrue);
    await tester.pump();
    expect(root.size.height, 198);
    expect(child.parent, isNull);
    expect(root.remove(child), isFalse);
    root.add(child);
    await tester.pump();
    expect(root.size.height, 200);
    expect(tester.element(find.byType(view.ElRootView)), same(element));
    expect(() => root.children.clear(), throwsUnsupportedError);
  });

  testWidgets('dry layout 和内在尺寸不改写已布局节点', (tester) async {
    final child = view.ElView(style: view.ElStyle(height: 20, margin: .all(2)));
    final root = view.ElView(style: view.ElStyle(padding: .all(5)))..add(child);
    await tester.pumpWidget(_host(root));
    final size = root.size;
    final childSize = child.size;
    final offset = child.offset;
    final render = _render(tester);
    expect(render.getDryLayout(BoxConstraints(maxWidth: 80)), Size(80, 34));
    expect(render.getMaxIntrinsicHeight(80), 34);
    expect(render.getMinIntrinsicWidth(100), 14);
    expect(root.size, size);
    expect(child.size, childSize);
    expect(child.offset, offset);
    expect(render.debugNeedsLayout, isFalse);
  });

  testWidgets('卸载解绑后可以修改并重新挂载同一棵树', (tester) async {
    final root = view.ElView(style: view.ElStyle(width: 40, height: 20));
    await tester.pumpWidget(_host(root));
    await tester.pumpWidget(SizedBox());
    root
      ..width = 80
      ..bgColor = Color(0xFFFF0000);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_host(root));
    expect(_render(tester).size, Size(80, 20));
    root.height = 30;
    await tester.pump();
    expect(_render(tester).size, Size(80, 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('宿主约束优先，清空尺寸恢复自动布局', (tester) async {
    final key = GlobalKey();
    final root = view.ElView(style: view.ElStyle(width: 100, height: 50, padding: .all(4)))
      ..add(view.ElView(style: view.ElStyle(height: 20)));
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: SizedBox.expand(
          child: view.ElRootView(key: key, root: root),
        ),
      ),
    );
    expect(root.size, tester.view.physicalSize / tester.view.devicePixelRatio);
    await tester.pumpWidget(_host(root, key: key));
    root
      ..width = null
      ..height = null;
    await tester.pump();
    expect(root.size.height, 28);
    expect(root.size.width, 800);
  });

  test('拒绝重复父节点、环和非法几何', () {
    final root = view.ElView();
    final child = view.ElView();
    root.add(child);
    expect(() => view.ElView().add(child), throwsStateError);
    expect(() => child.add(root), throwsArgumentError);
    expect(() => root.add(root), throwsArgumentError);
    expect(() => root.width = -1, throwsAssertionError);
    expect(() => root.height = double.infinity, throwsAssertionError);
    expect(() => root.padding = EdgeInsets.all(-1), throwsAssertionError);
    expect(() => view.ElView(style: view.ElStyle(margin: EdgeInsets.all(double.infinity))), throwsAssertionError);
  });
}
