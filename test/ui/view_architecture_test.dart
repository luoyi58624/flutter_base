import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/view/render/view.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewKey = ValueKey('architecture-view');
const _red = Color(0xffff0000), _blue = Color(0xff0000ff);
const _widthAndPadding = [
  ElTransition.field(
    ElTransitionField.width,
    Duration(milliseconds: 100),
    Curves.linear,
  ),
  ElTransition.field(
    ElTransitionField.padding,
    Duration(milliseconds: 200),
    Curves.linear,
  ),
];
const _widthAndHeight = [
  ElTransition.field(
    ElTransitionField.width,
    Duration(milliseconds: 100),
    Curves.linear,
  ),
  ElTransition.field(
    ElTransitionField.height,
    Duration(milliseconds: 200),
    Curves.linear,
  ),
];
const _linear = [ElTransition.all(Duration(milliseconds: 100), Curves.linear)];

Widget _scene(ElStyle style, {Widget? child, double maxWidth = 400}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 300),
          child: ElView(key: _viewKey, style: style, child: child),
        ),
      ),
    );

Size _size(WidgetTester tester) => tester.getSize(find.byKey(_viewKey));

Future<void> _advanceTo99(WidgetTester tester, {required bool dense}) async {
  if (dense) {
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pump(const Duration(milliseconds: 9));
  } else {
    await tester.pump(const Duration(milliseconds: 99));
  }
}

class _LayoutCounts {
  int layouts = 0;
  int dryLayouts = 0;
}

class _CountedBox extends LeafRenderObjectWidget {
  const _CountedBox(this.counts, {this.preferredSize = const Size(1000, 20)});

  final _LayoutCounts counts;
  final Size preferredSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _CountedRenderBox(counts, preferredSize);
}

class _CountedRenderBox extends RenderBox {
  _CountedRenderBox(this.counts, this.preferredSize);

  final _LayoutCounts counts;
  final Size preferredSize;

  @override
  void performLayout() {
    counts.layouts++;
    size = constraints.constrain(preferredSize);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    counts.dryLayouts++;
    return constraints.constrain(preferredSize);
  }
}

class _CountedView extends ElView {
  const _CountedView(this.counts, {super.style, super.child});

  final _LayoutCounts counts;

  @override
  ElRenderView createRenderObject(BuildContext context) => _CountedRenderView(
    counts,
    style,
    Directionality.maybeOf(context) ?? TextDirection.ltr,
  );
}

class _CountedRenderView extends ElRenderView {
  _CountedRenderView(this.counts, super.style, super.direction);

  final _LayoutCounts counts;

  @override
  void performLayout() {
    counts.layouts++;
    super.performLayout();
  }
}

void main() {
  for (final dense in [false, true]) {
    final sampling = dense ? '逐帧推进' : '首次稀疏推进';

    testWidgets('auto 宽度与较慢 padding 在截止帧保持连续：$sampling', (tester) async {
      const child = SizedBox(width: 100, height: 20);
      await tester.pumpWidget(
        _scene(
          const ElStyle(width: 200, transitions: _widthAndPadding),
          child: child,
        ),
      );
      await tester.pumpWidget(
        _scene(
          const ElStyle(
            padding: EdgeInsets.symmetric(horizontal: 40),
            transitions: _widthAndPadding,
          ),
          child: child,
        ),
      );
      await _advanceTo99(tester, dense: dense);
      final before = _size(tester).width;
      await tester.pump(const Duration(milliseconds: 1));
      expect((_size(tester).width - before).abs(), lessThan(3));
      expect(_size(tester).width, closeTo(140, .001));
      if (dense) {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
      } else {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_size(tester).width, closeTo(180, .001));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('双 auto 与宽高比跨轴耦合在截止帧保持连续：$sampling', (tester) async {
      const child = AspectRatio(aspectRatio: 2);
      await tester.pumpWidget(
        _scene(
          const ElStyle(width: 200, height: 50, transitions: _widthAndHeight),
          child: child,
        ),
      );
      await tester.pumpWidget(
        _scene(const ElStyle(transitions: _widthAndHeight), child: child),
      );
      await _advanceTo99(tester, dense: dense);
      final before = _size(tester).width;
      await tester.pump(const Duration(milliseconds: 1));
      expect((_size(tester).width - before).abs(), lessThan(5));
      expect(_size(tester).width, closeTo(250, .001));
      expect(_size(tester).height, closeTo(125, .001));
      if (dense) {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
      } else {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_size(tester), const Size(400, 200));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('纯颜色更新与逐帧动画不触发布局、干布局或 child 重建', (tester) async {
    final counts = _LayoutCounts();
    var builds = 0;
    final child = Builder(
      builder: (_) {
        builds++;
        return _CountedBox(counts, preferredSize: const Size(80, 20));
      },
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(backgroundColor: _red, transitions: _linear),
        child: child,
      ),
    );
    final layouts = counts.layouts, dryLayouts = counts.dryLayouts;
    expect(layouts, greaterThan(0));
    await tester.pumpWidget(
      _scene(
        const ElStyle(backgroundColor: _blue, transitions: _linear),
        child: child,
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(counts.layouts, layouts);
      expect(counts.dryLayouts, dryLayouts);
      expect(builds, 1);
    }
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('固定像素宽度动画每帧只执行一次必要的 child 布局', (tester) async {
    final counts = _LayoutCounts();
    final child = _CountedBox(counts);
    await tester.pumpWidget(
      _scene(const ElStyle(width: 100, transitions: _linear), child: child),
    );
    await tester.pumpWidget(
      _scene(const ElStyle(width: 200, transitions: _linear), child: child),
    );
    final dryLayouts = counts.dryLayouts;
    for (var i = 0; i < 10; i++) {
      final layouts = counts.layouts;
      await tester.pump(const Duration(milliseconds: 10));
      expect(counts.layouts - layouts, 1);
      expect(counts.dryLayouts, dryLayouts);
      expect(_size(tester).width, closeTo(110 + i * 10, .001));
    }
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto 临时测量后恢复 Column 百分比几何与后代动画截止时间', (tester) async {
    const columnKey = ValueKey('architecture-column');
    const nestedKey = ValueKey('architecture-nested');
    const leafKey = ValueKey('architecture-leaf');
    const padding = EdgeInsets.fromLTRB(7, 11, 13, 17);
    const margin = EdgeInsets.fromLTRB(3, 5, 9, 15);
    const childTransitions = [
      ElTransition.field(
        ElTransitionField.width,
        Duration(milliseconds: 200),
        Curves.linear,
      ),
    ];
    Widget nested(double width) => Column(
      key: columnKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElView(
          key: nestedKey,
          style: ElStyle(
            width: width,
            height: '50%',
            transitions: childTransitions,
          ),
          child: LayoutBuilder(
            builder: (_, _) =>
                const SizedBox(key: leafKey, width: 30, height: 40),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 200,
          height: 200,
          padding: padding,
          margin: margin,
          transitions: _linear,
        ),
        child: nested(100),
      ),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 200,
          padding: padding,
          margin: margin,
          transitions: _linear,
        ),
        child: nested(140),
      ),
    );
    for (var i = 1; i <= 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(
        tester.getSize(find.byKey(nestedKey)).width,
        closeTo(100 + i * 2, .001),
      );
      final column = tester.renderObject<RenderBox>(find.byKey(columnKey));
      final nestedBox = tester.renderObject<RenderBox>(find.byKey(nestedKey));
      expect(
        (column.parentData! as BoxParentData).offset,
        const Offset(10, 16),
      );
      expect((nestedBox.parentData! as BoxParentData).offset, Offset.zero);
      if (i < 10) {
        final contentHeight =
            _size(tester).height - margin.vertical - padding.vertical;
        expect(nestedBox.size.height, closeTo(contentHeight * .5, .001));
        expect(column.size.height, nestedBox.size.height);
      }
      if (i >= 10) {
        expect(_size(tester), const Size(212, 88));
        expect(nestedBox.size.height, 40);
        expect(column.size.height, 40);
        expect(tester.getSize(find.byKey(leafKey)).height, 40);
      }
      expect(tester.takeException(), isNull);
    }
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('无界 Column 中最近祖先在 auto 与确定尺寸间切换参照', (tester) async {
    const middleKey = ValueKey('architecture-reference-middle');
    const percentKey = ValueKey('architecture-reference-percent');
    const descendant = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElView(
          key: percentKey,
          style: ElStyle(width: 10, height: '50%'),
        ),
      ],
    );
    Widget host(double? middleHeight) => _scene(
      const ElStyle(width: 200, height: 300, padding: EdgeInsets.all(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElView(
            key: middleKey,
            style: ElStyle(
              height: middleHeight,
              padding: const EdgeInsets.all(5),
            ),
            child: descendant,
          ),
        ],
      ),
    );
    await tester.pumpWidget(host(null));
    expect(tester.getSize(find.byKey(percentKey)).height, 140);
    expect(tester.getSize(find.byKey(middleKey)).height, 150);
    await tester.pumpWidget(host(160));
    expect(tester.getSize(find.byKey(percentKey)).height, 75);
    expect(tester.getSize(find.byKey(middleKey)).height, 160);
    await tester.pumpWidget(host(null));
    expect(tester.getSize(find.byKey(percentKey)).height, 140);
    expect(tester.getSize(find.byKey(middleKey)).height, 150);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GlobalKey 重挂到新参照后旧父变化不再使其布局', (tester) async {
    final movedKey = GlobalKey();
    final counts = _LayoutCounts();
    final moved = ElView(
      key: movedKey,
      style: const ElStyle(width: 10, height: '50%'),
      child: _CountedBox(counts, preferredSize: const Size(10, 1000)),
    );
    Widget host({
      required bool right,
      double leftHeight = 200,
      double rightHeight = 300,
    }) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElView(
              key: const ValueKey('architecture-old-parent'),
              style: ElStyle(width: 160, height: leftHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [if (!right) moved],
              ),
            ),
            ElView(
              key: const ValueKey('architecture-new-parent'),
              style: ElStyle(width: 160, height: rightHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [if (right) moved],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(host(right: false));
    final render = tester.renderObject<RenderBox>(find.byKey(movedKey));
    expect(render.size.height, 100);
    await tester.pumpWidget(host(right: true));
    expect(tester.renderObject(find.byKey(movedKey)), same(render));
    expect(render.size.height, 150);
    final layoutsAfterMove = counts.layouts;
    await tester.pumpWidget(host(right: true, leftHeight: 240));
    expect(render.size.height, 150);
    expect(counts.layouts, layoutsAfterMove);
    await tester.pumpWidget(
      host(right: true, leftHeight: 240, rightHeight: 360),
    );
    expect(render.size.height, 180);
    expect(counts.layouts, layoutsAfterMove + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto 宽度与较慢非对称 margin 保持截止帧和正式绘制几何连续', (tester) async {
    const transitions = [
      ElTransition.field(
        ElTransitionField.width,
        Duration(milliseconds: 100),
        Curves.linear,
      ),
      ElTransition.field(
        ElTransitionField.margin,
        Duration(milliseconds: 200),
        Curves.linear,
      ),
    ];
    const childKey = ValueKey('architecture-margin-child');
    const child = SizedBox(key: childKey, width: 400, height: 20);
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 200,
          backgroundColor: _red,
          transitions: transitions,
        ),
        child: child,
      ),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          margin: EdgeInsets.fromLTRB(40, 10, 20, 30),
          backgroundColor: _red,
          transitions: transitions,
        ),
        child: child,
      ),
    );
    await tester.pump(const Duration(milliseconds: 99));
    final before = _size(tester).width;
    await tester.pump(const Duration(milliseconds: 1));
    expect((_size(tester).width - before).abs(), lessThan(3));
    expect(_size(tester), const Size(400, 40));
    final box = tester.renderObject<RenderBox>(find.byKey(_viewKey));
    final renderChild = tester.renderObject<RenderBox>(find.byKey(childKey));
    expect(renderChild.size, const Size(370, 20));
    expect(
      (renderChild.parentData! as BoxParentData).offset,
      const Offset(20, 5),
    );
    expect(
      box,
      paints..rect(rect: const Rect.fromLTWH(20, 5, 370, 20), color: _red),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(_size(tester).width, 400);
    }
    expect(_size(tester), const Size(400, 60));
    expect(renderChild.size, const Size(340, 20));
    expect(
      (renderChild.parentData! as BoxParentData).offset,
      const Offset(40, 10),
    );
    expect(
      box,
      paints..rect(rect: const Rect.fromLTWH(40, 10, 340, 20), color: _red),
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto 端点未变时无关父约束变化保持原缓动时间线', (tester) async {
    const transitions = [
      ElTransition.field(
        ElTransitionField.width,
        Duration(milliseconds: 100),
        Curves.easeInQuad,
      ),
    ];
    const child = SizedBox(width: 100, height: 20);
    await tester.pumpWidget(
      _scene(const ElStyle(width: 200, transitions: transitions), child: child),
    );
    const target = ElStyle(transitions: transitions);
    await tester.pumpWidget(_scene(target, child: child));
    await tester.pump(const Duration(milliseconds: 50));
    // Flutter 的 easeInQuad 是三次贝塞尔近似，按声明曲线验证原始时间进度。
    final halfway = 200 - 100 * Curves.easeInQuad.transform(.5);
    expect(_size(tester).width, closeTo(halfway, .001));
    await tester.pumpWidget(_scene(target, child: child, maxWidth: 500));
    expect(_size(tester).width, closeTo(halfway, .001));
    await tester.pump(const Duration(milliseconds: 25));
    expect(
      _size(tester).width,
      closeTo(200 - 100 * Curves.easeInQuad.transform(.75), .001),
    );
    await tester.pump(const Duration(milliseconds: 25));
    expect(_size(tester).width, 100);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('阶跃曲线采样值未变时宿主与 child 都不重新布局', (tester) async {
    final hostCounts = _LayoutCounts(), childCounts = _LayoutCounts();
    final child = _CountedBox(childCounts);
    const transitions = [
      ElTransition.field(
        ElTransitionField.width,
        Duration(milliseconds: 100),
        Threshold(.8),
      ),
    ];
    Widget host(double width) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
          child: _CountedView(
            hostCounts,
            style: ElStyle(width: width, transitions: transitions),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(100));
    await tester.pumpWidget(host(200));
    final hostLayouts = hostCounts.layouts, childLayouts = childCounts.layouts;
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(hostCounts.layouts, hostLayouts);
      expect(childCounts.layouts, childLayouts);
      expect(tester.getSize(find.byType(_CountedView)).width, 100);
    }
    await tester.pump(const Duration(milliseconds: 10));
    expect(tester.getSize(find.byType(_CountedView)).width, 200);
    expect(hostCounts.layouts, hostLayouts + 1);
    expect(childCounts.layouts, childLayouts + 1);
    await tester.pump(const Duration(milliseconds: 15));
    expect(hostCounts.layouts, hostLayouts + 1);
    expect(childCounts.layouts, childLayouts + 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto 宽度延迟期间 padding 每帧只触发正式 child 布局', (tester) async {
    const transitions = [
      ElTransition.field(
        ElTransitionField.width,
        Duration(milliseconds: 100),
        Curves.linear,
        Duration(milliseconds: 1000),
      ),
      ElTransition.field(
        ElTransitionField.padding,
        Duration(milliseconds: 200),
        Curves.linear,
      ),
    ];
    final counts = _LayoutCounts();
    final child = _CountedBox(counts, preferredSize: const Size(400, 20));
    await tester.pumpWidget(
      _scene(const ElStyle(width: 200, transitions: transitions), child: child),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          padding: EdgeInsets.symmetric(horizontal: 40),
          transitions: transitions,
        ),
        child: child,
      ),
    );
    final dryLayouts = counts.dryLayouts;
    for (var i = 1; i <= 20; i++) {
      final layouts = counts.layouts;
      await tester.pump(const Duration(milliseconds: 10));
      expect(counts.layouts - layouts, 1);
      expect(counts.dryLayouts, dryLayouts);
      expect(_size(tester).width, 200);
      expect(
        tester
            .renderObject<RenderShiftedBox>(find.byKey(_viewKey))
            .child!
            .size
            .width,
        closeTo(200 - i * 4, .001),
      );
    }
    await tester.pump(const Duration(milliseconds: 900));
    expect(_size(tester).width, 400);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧约束 child 在同一时间戳更新内容后 auto 动画使用新端点', (tester) async {
    await tester.pumpWidget(
      _scene(
        const ElStyle(width: 0, height: 0, transitions: _linear),
        child: const SizedBox(width: 100),
      ),
    );
    const target = ElStyle(height: 0, transitions: _linear);
    await tester.pumpWidget(_scene(target, child: const SizedBox(width: 100)));
    expect(_size(tester), Size.zero);
    await tester.pumpWidget(_scene(target, child: const SizedBox(width: 200)));
    expect(_size(tester), Size.zero);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_size(tester), const Size(100, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_size(tester), const Size(200, 0));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto 动画中即时修改 padding 保持当前画面与原截止时间', (tester) async {
    const transitions = [
      ElTransition.field(
        ElTransitionField.width,
        Duration(milliseconds: 100),
        Curves.linear,
      ),
    ];
    const child = SizedBox(width: 100, height: 20);
    await tester.pumpWidget(
      _scene(const ElStyle(width: 200, transitions: transitions), child: child),
    );
    await tester.pumpWidget(
      _scene(const ElStyle(transitions: transitions), child: child),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(_size(tester).width, 150);
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          padding: EdgeInsets.symmetric(horizontal: 40),
          transitions: transitions,
        ),
        child: child,
      ),
    );
    expect(_size(tester).width, 150);
    await tester.pump(const Duration(milliseconds: 25));
    expect(_size(tester).width, 165);
    await tester.pump(const Duration(milliseconds: 25));
    expect(_size(tester).width, 180);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto 起点终点同为零时仍感知紧约束 child 后续内容变化', (tester) async {
    await tester.pumpWidget(
      _scene(
        const ElStyle(width: 0, height: 0, transitions: _linear),
        child: const SizedBox(width: 0),
      ),
    );
    const target = ElStyle(height: 0, transitions: _linear);
    await tester.pumpWidget(_scene(target, child: const SizedBox(width: 0)));
    await tester.pump(const Duration(milliseconds: 25));
    expect(_size(tester), Size.zero);
    await tester.pumpWidget(_scene(target, child: const SizedBox(width: 200)));
    expect(_size(tester), Size.zero);
    await tester.pump(const Duration(milliseconds: 25));
    expect(_size(tester), const Size(100, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_size(tester), const Size(200, 0));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
