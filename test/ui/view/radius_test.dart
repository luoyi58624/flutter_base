import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/view/paint/decoration.dart';
import 'package:flutter_base/src/ui/view/paint/shape.dart';
import 'package:flutter_base/src/ui/view/render/view.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewKey = ValueKey('radius-view');
const _red = Color(0xffff0000), _blue = Color(0xff0000ff);
const _linear = [
  ElTransition.field(
    ElTransitionField.borderRadius,
    Duration(milliseconds: 100),
    Curves.linear,
  ),
];

Widget _scene(
  ElStyle style, {
  Widget? child,
  TextDirection direction = TextDirection.ltr,
  _Counts? counts,
}) => Directionality(
  textDirection: direction,
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
      child: counts == null
          ? ElView(key: _viewKey, style: style, child: child)
          : _CountedView(counts, key: _viewKey, style: style, child: child),
    ),
  ),
);

ElRenderView _render(WidgetTester tester) =>
    tester.renderObject<ElRenderView>(find.byKey(_viewKey));

ElStyle _style(BorderRadiusGeometry? radius, {Color? color = _red}) => ElStyle(
  width: 100,
  height: 60,
  backgroundColor: color,
  borderRadius: radius,
  transitions: _linear,
);

TestRecordingCanvas _record(void Function(PaintingContext) paint) {
  final canvas = TestRecordingCanvas();
  paint(TestRecordingPaintingContext(canvas));
  return canvas;
}

class _Counts {
  int layouts = 0;
  int dryLayouts = 0;
}

class _CountedView extends ElView {
  const _CountedView(this.counts, {super.key, super.style, super.child});

  final _Counts counts;

  @override
  ElRenderView createRenderObject(BuildContext context) =>
      _CountedRenderView(counts, style, Directionality.of(context));
}

class _CountedRenderView extends ElRenderView {
  _CountedRenderView(this.counts, super.style, super.direction);

  final _Counts counts;

  @override
  void performLayout() {
    counts.layouts++;
    super.performLayout();
  }
}

class _PaintedBox extends LeafRenderObjectWidget {
  const _PaintedBox({this.counts});

  final _Counts? counts;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintedRenderBox(counts);
}

class _PaintedRenderBox extends RenderBox {
  _PaintedRenderBox(this.counts);

  final _Counts? counts;

  @override
  void performLayout() {
    if (counts != null) counts!.layouts++;
    size = constraints.constrain(const Size(80, 40));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (counts != null) counts!.dryLayouts++;
    return constraints.constrain(const Size(80, 40));
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) => context.canvas.drawRect(
    (offset & size).inflate(8),
    Paint()..color = _blue,
  );
}

class _NegativeCurve extends Curve {
  const _NegativeCurve();

  @override
  double transformInternal(double t) => -t;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('圆角参与样式相等、复制、清空和合并', () {
    const radius = BorderRadius.all(Radius.circular(12));
    const style = ElStyle(borderRadius: radius);
    expect(style, const ElStyle(borderRadius: radius));
    expect(style, isNot(const ElStyle()));
    expect(style.copyWith().borderRadius, radius);
    expect(style.copyWith(borderRadius: null).borderRadius, isNull);
    expect(const ElStyle().merge(style).borderRadius, radius);
    expect(style.merge(const ElStyle()).borderRadius, radius);
  });

  test('物理圆角不随文字方向重新解析，混合圆角按方向求值', () {
    const physical = BorderRadius.only(topLeft: Radius.elliptical(3, 5));
    final mixed = physical.add(
      const BorderRadiusDirectional.only(
        topStart: Radius.elliptical(7, 11),
        bottomEnd: Radius.elliptical(13, 17),
      ),
    );
    final render = ElRenderView(
      const ElStyle(borderRadius: physical),
      TextDirection.ltr,
    );
    final engine = render.styleEngine;
    expect(engine.borderRadius, physical);
    final physicalCount = engine.debugParseCount;
    render.applyStyle(
      const ElStyle(borderRadius: physical),
      textDirection: TextDirection.rtl,
    );
    expect(engine.debugParseCount, physicalCount);
    render.applyStyle(
      ElStyle(borderRadius: mixed),
      textDirection: TextDirection.ltr,
    );
    expect(engine.borderRadius, mixed.resolve(TextDirection.ltr));
    final mixedCount = engine.debugParseCount;
    render.applyStyle(
      ElStyle(borderRadius: mixed),
      textDirection: TextDirection.rtl,
    );
    expect(engine.debugParseCount, mixedCount + 1);
    expect(engine.borderRadius, mixed.resolve(TextDirection.rtl));
    expect(engine.debugTickerCreated, isFalse);
    render.dispose();
  });

  test('全零与全退化椭圆角走矩形，非法分量在解析处报错', () {
    for (final radius in [
      BorderRadius.zero,
      const BorderRadius.all(Radius.elliptical(0, 12)),
      const BorderRadius.all(Radius.elliptical(12, 0)),
    ]) {
      final render = ElRenderView(
        ElStyle(borderRadius: radius),
        TextDirection.ltr,
      );
      expect(render.styleEngine.borderRadius, isNull);
      render.dispose();
    }
    final partial = ElRenderView(
      const ElStyle(
        borderRadius: BorderRadius.only(
          topLeft: Radius.elliptical(0, 12),
          bottomRight: Radius.circular(4),
        ),
      ),
      TextDirection.ltr,
    );
    expect(partial.styleEngine.borderRadius!.topLeft.x, 0);
    expect(
      partial.styleEngine.borderRadius!.bottomRight,
      const Radius.circular(4),
    );
    partial.dispose();
    for (final value in [-1.0, double.infinity, double.nan]) {
      expect(
        () => ElRenderView(
          ElStyle(
            borderRadius: BorderRadius.only(
              topLeft: Radius.elliptical(value, 2),
            ),
          ),
          TextDirection.ltr,
        ),
        throwsAssertionError,
      );
    }
  });

  test('形状缓存使用局部尺寸和圆角，超大椭圆角统一缩放', () {
    final shape = ShapeGeometry();
    const radius = BorderRadius.only(
      topLeft: Radius.elliptical(200, 100),
      topRight: Radius.elliptical(100, 70),
      bottomLeft: Radius.elliptical(30, 90),
      bottomRight: Radius.elliptical(80, 30),
    );
    const size = Size(100, 60);
    final first = shape.resolve(size, radius);
    expect(first, radius.toRRect(Offset.zero & size).scaleRadii());
    expect(shape.resolve(size, radius), same(first));
    expect(shape.resolve(const Size(120, 60), radius), isNot(same(first)));
  });

  test('颜色、绘制位置和命中查询复用形状，矩形快路不创建形状', () {
    final painter = DecorationPainter();
    const rect = Rect.fromLTWH(3, 4, 100, 60);
    void paint(Rect box, Color color, BorderRadius? radius) => _record(
      (context) =>
          painter.paintBackground(context, box, color, borderRadius: radius),
    );
    paint(rect, _red, null);
    expect(painter.debugShapeCreated, isFalse);
    expect(painter.debugShapeBuildCount, 0);
    const radius = BorderRadius.all(Radius.circular(20));
    paint(rect, _red, radius);
    expect(painter.debugShapeCreated, isTrue);
    expect(painter.debugShapeBuildCount, 1);
    final moved = rect.shift(const Offset(31, 17));
    paint(moved, _blue, radius);
    expect(painter.contains(moved, moved.center, borderRadius: radius), isTrue);
    expect(painter.debugShapeBuildCount, 1);
    paint(moved, _blue, const BorderRadius.all(Radius.circular(24)));
    expect(painter.debugShapeBuildCount, 2);
    paint(
      Rect.fromLTWH(moved.left, moved.top, 120, 60),
      _blue,
      const BorderRadius.all(Radius.circular(24)),
    );
    expect(painter.debugShapeBuildCount, 3);
    paint(rect, _red, null);
    expect(painter.debugShapeBuildCount, 3);
  });

  testWidgets('单独声明圆角不绘制，零圆角走矩形绘制', (tester) async {
    await tester.pumpWidget(
      _scene(_style(const BorderRadius.all(Radius.circular(20)), color: null)),
    );
    expect(_render(tester), paintsNothing);
    expect(_render(tester).hitTestSelf(const Offset(50, 30)), isFalse);
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 100,
          height: 60,
          backgroundColor: _red,
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
    expect(
      _render(tester),
      paints..rect(rect: const Rect.fromLTWH(0, 0, 100, 60), color: _red),
    );
    expect(_render(tester), paintsExactlyCountTimes(#drawRRect, 0));
    expect(_render(tester).hitTestSelf(const Offset(1, 1)), isTrue);
  });

  testWidgets('方向性圆角在 RTL 下绘制正确，不影响外边距位置', (tester) async {
    const radius = BorderRadiusDirectional.only(
      topStart: Radius.elliptical(14, 20),
      bottomEnd: Radius.elliptical(7, 11),
    );
    const style = ElStyle(
      width: 100,
      height: 60,
      backgroundColor: _red,
      margin: EdgeInsets.fromLTRB(3, 5, 7, 11),
      borderRadius: radius,
    );
    await tester.pumpWidget(_scene(style));
    expect(
      _render(tester),
      paints..rrect(
        rrect: radius
            .resolve(TextDirection.ltr)
            .toRRect(const Rect.fromLTWH(3, 5, 100, 60)),
        color: _red,
      ),
    );
    final render = _render(tester),
        parseCount = render.styleEngine.debugParseCount;
    await tester.pumpWidget(_scene(style, direction: TextDirection.rtl));
    expect(_render(tester), same(render));
    expect(render.styleEngine.debugParseCount, parseCount + 1);
    expect(
      render,
      paints..rrect(
        rrect: radius
            .resolve(TextDirection.rtl)
            .toRRect(const Rect.fromLTWH(3, 5, 100, 60)),
        color: _red,
      ),
    );
    expect(render.size, const Size(110, 76));
  });

  testWidgets('尺寸和 auto 内容变化后重新生成适配盒子的圆角', (tester) async {
    const radius = BorderRadius.all(Radius.elliptical(120, 80));
    Future<void> check(ElStyle style, {Widget? child}) async {
      await tester.pumpWidget(_scene(style, child: child));
      final render = _render(tester);
      expect(
        render,
        paints..rrect(
          rrect: radius.toRRect(render.boxLayout.boxRect).scaleRadii(),
          color: _red,
        ),
      );
    }

    await check(
      const ElStyle(
        width: 100,
        height: 60,
        backgroundColor: _red,
        borderRadius: radius,
      ),
    );
    await check(
      const ElStyle(
        width: 200,
        height: 100,
        backgroundColor: _red,
        borderRadius: radius,
      ),
    );
    const auto = ElStyle(backgroundColor: _red, borderRadius: radius);
    await check(auto, child: const SizedBox(width: 40, height: 30));
    expect(_render(tester).size, const Size(40, 30));
    await check(auto, child: const SizedBox(width: 160, height: 70));
    expect(_render(tester).size, const Size(160, 70));
  });

  testWidgets('超大圆角的自身命中与最终绘制形状一致，margin 不参与命中', (tester) async {
    const radius = BorderRadius.only(
      topLeft: Radius.elliptical(200, 100),
      topRight: Radius.elliptical(100, 70),
      bottomLeft: Radius.elliptical(30, 90),
      bottomRight: Radius.elliptical(80, 30),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 100,
          height: 60,
          backgroundColor: _red,
          margin: EdgeInsets.all(10),
          borderRadius: radius,
        ),
      ),
    );
    final render = _render(tester);
    final shape = radius
        .toRRect(const Rect.fromLTWH(10, 10, 100, 60))
        .scaleRadii();
    for (var y = 0.0; y <= 80; y += 5) {
      for (var x = 0.0; x <= 120; x += 5) {
        final point = Offset(x, y);
        expect(
          render.hitTestSelf(point),
          shape.contains(point),
          reason: '$point',
        );
      }
    }
    expect(render.hitTestSelf(const Offset(11, 11)), isFalse);
    expect(render.hitTestSelf(const Offset(60, 40)), isTrue);
    expect(render.hitTestSelf(const Offset(5, 40)), isFalse);
  });

  testWidgets('圆角只约束背景，child 保留绘制与角落命中', (tester) async {
    await tester.pumpWidget(
      _scene(
        _style(const BorderRadius.all(Radius.circular(30))),
        child: const _PaintedBox(),
      ),
    );
    final render = _render(tester);
    final canvas = _record((context) => render.paint(context, Offset.zero));
    final methods = canvas.invocations.map(
      (entry) => entry.invocation.memberName,
    );
    expect(methods, containsAllInOrder([#drawRRect, #drawRect]));
    expect(methods, isNot(contains(#clipRRect)));
    expect(methods, isNot(contains(#clipRect)));
    expect(methods, isNot(contains(#clipPath)));
    expect(methods, isNot(contains(#saveLayer)));
    expect(render.hitTestSelf(const Offset(1, 1)), isFalse);
    final result = BoxHitTestResult();
    expect(render.hitTest(result, position: const Offset(1, 1)), isTrue);
    expect(result.path.any((entry) => entry.target == render.child), isTrue);
    expect(
      render,
      paints..rect(rect: const Rect.fromLTWH(-8, -8, 96, 56), color: _blue),
    );
  });

  testWidgets('圆角从零过渡、被中断与清空时保持连续', (tester) async {
    await tester.pumpWidget(_scene(_style(null)));
    final engine = _render(tester).styleEngine;
    await tester.pumpWidget(_scene(_style(BorderRadius.circular(40))));
    expect(engine.borderRadius, isNull);
    await tester.pump(const Duration(milliseconds: 25));
    expect(engine.borderRadius, BorderRadius.circular(10));
    await tester.pumpWidget(_scene(_style(BorderRadius.circular(20))));
    expect(engine.borderRadius, BorderRadius.circular(10));
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.borderRadius, BorderRadius.circular(15));
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.borderRadius, BorderRadius.circular(20));
    await tester.pumpWidget(_scene(_style(null)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.borderRadius, BorderRadius.circular(10));
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.borderRadius, isNull);
    expect(_render(tester), paintsExactlyCountTimes(#drawRRect, 0));
    expect(_render(tester), paintsExactlyCountTimes(#drawRect, 1));
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final end in [
    const Radius.elliptical(20, 20),
    const Radius.elliptical(20, 0),
  ]) {
    testWidgets('退化椭圆角保留两轴端点，过渡到 $end', (tester) async {
      await tester.pumpWidget(
        _scene(_style(const BorderRadius.all(Radius.elliptical(0, 20)))),
      );
      final engine = _render(tester).styleEngine;
      expect(engine.borderRadius, isNull);
      await tester.pumpWidget(_scene(_style(BorderRadius.all(end))));
      expect(engine.borderRadius, isNull);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        engine.borderRadius,
        BorderRadius.all(Radius.elliptical(10, (20 + end.y) / 2)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.borderRadius, end.y == 0 ? isNull : BorderRadius.all(end));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('宽高与圆角同时过渡时按本帧盒子缩放绘制', (tester) async {
    const transitions = [
      ElTransition.all(Duration(milliseconds: 200), Curves.linear),
      ElTransition.field(
        ElTransitionField.width,
        Duration(milliseconds: 100),
        Curves.linear,
      ),
      ElTransition.field(
        ElTransitionField.height,
        Duration(milliseconds: 100),
        Curves.linear,
      ),
    ];
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 100,
          height: 60,
          backgroundColor: _red,
          borderRadius: BorderRadius.all(Radius.circular(110)),
          transitions: transitions,
        ),
      ),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 200,
          height: 100,
          backgroundColor: _red,
          borderRadius: BorderRadius.all(Radius.circular(30)),
          transitions: transitions,
        ),
      ),
    );
    final render = _render(tester);
    for (final (size, radius) in [
      (const Size(150, 80), 40.0),
      (const Size(200, 100), 50.0),
      (const Size(200, 100), 50.0),
      (const Size(200, 100), 30.0),
    ]) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(render.boxLayout.boxSize, size);
      expect(
        render,
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(radius),
          ),
          color: _red,
        ),
      );
    }
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('延迟期间保持矩形，到期后按半径插值', (tester) async {
    const transitions = [
      ElTransition.field(
        ElTransitionField.borderRadius,
        Duration(milliseconds: 100),
        Curves.linear,
        Duration(milliseconds: 50),
      ),
    ];
    ElStyle style(BorderRadius? radius) => ElStyle(
      width: 100,
      height: 60,
      backgroundColor: _red,
      borderRadius: radius,
      transitions: transitions,
    );
    await tester.pumpWidget(_scene(style(null)));
    await tester.pumpWidget(_scene(style(BorderRadius.circular(20))));
    final engine = _render(tester).styleEngine;
    await tester.pump(const Duration(milliseconds: 49));
    expect(engine.borderRadius, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(engine.borderRadius, isNull);
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.borderRadius, BorderRadius.circular(10));
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.borderRadius, BorderRadius.circular(20));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('负过冲半径归零，截止帧恢复精确目标', (tester) async {
    const transitions = [
      ElTransition.field(
        ElTransitionField.borderRadius,
        Duration(milliseconds: 100),
        _NegativeCurve(),
      ),
    ];
    await tester.pumpWidget(_scene(const ElStyle(transitions: transitions)));
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          borderRadius: BorderRadius.only(
            topLeft: Radius.elliptical(10, 20),
            bottomRight: Radius.elliptical(30, 40),
          ),
          transitions: transitions,
        ),
      ),
    );
    final engine = _render(tester).styleEngine;
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.borderRadius, isNull);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      engine.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.elliptical(10, 20),
        bottomRight: Radius.elliptical(30, 40),
      ),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('纯圆角动画不触发布局、干布局、child 重建或重复解析', (tester) async {
    final host = _Counts(), childCounts = _Counts();
    var builds = 0;
    final child = Builder(
      builder: (_) {
        builds++;
        return _PaintedBox(counts: childCounts);
      },
    );
    await tester.pumpWidget(_scene(_style(null), child: child, counts: host));
    final render = _render(tester);
    final hostLayouts = host.layouts;
    final childLayouts = childCounts.layouts;
    final dryLayouts = childCounts.dryLayouts;
    final parses = render.styleEngine.debugParseCount;
    await tester.pumpWidget(
      _scene(_style(BorderRadius.circular(24)), child: child, counts: host),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(host.layouts, hostLayouts);
      expect(childCounts.layouts, childLayouts);
      expect(childCounts.dryLayouts, dryLayouts);
      expect(builds, 1);
      expect(render.styleEngine.debugParseCount, parses + 1);
    }
    expect(render.styleEngine.borderRadius, BorderRadius.circular(24));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
