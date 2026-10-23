import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/view/render/view.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewKey = ValueKey('clip-view');
const _red = Color(0xffff0000), _blue = Color(0xff0000ff);
const _linear = [ElTransition.all(Duration(milliseconds: 100), Curves.linear)];

Widget _scene(ElStyle style, {Widget? child, _Counts? counts}) =>
    Directionality(
      textDirection: TextDirection.ltr,
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

List<Invocation> _record(ElRenderView render, {Offset offset = Offset.zero}) {
  final canvas = TestRecordingCanvas();
  render.paint(TestRecordingPaintingContext(canvas), offset);
  return canvas.invocations.map((entry) => entry.invocation).toList();
}

Iterable<Invocation> _calls(List<Invocation> calls, Symbol method) =>
    calls.where((call) => call.memberName == method);

ElStyle _style({
  Clip? clip,
  BorderRadiusGeometry? radius = const BorderRadius.all(Radius.circular(30)),
  Color? color = _red,
  List<ElTransition>? transitions,
}) => ElStyle(
  width: 100,
  height: 60,
  backgroundColor: color,
  borderRadius: radius,
  clipBehavior: clip,
  transitions: transitions,
);

class _Counts {
  int hostLayouts = 0;
  int childLayouts = 0;
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
    counts.hostLayouts++;
    super.performLayout();
  }
}

class _OverflowBox extends LeafRenderObjectWidget {
  const _OverflowBox({this.counts});

  final _Counts? counts;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _OverflowRenderBox(counts);
}

class _OverflowRenderBox extends RenderBox {
  _OverflowRenderBox(this.counts);

  final _Counts? counts;

  @override
  void performLayout() {
    if (counts != null) counts!.childLayouts++;
    size = constraints.constrain(const Size(1000, 1000));
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) => context.canvas.drawRect(
    (offset & size).inflate(20),
    Paint()..color = _blue,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clipBehavior 参与样式复制、清空、合并，默认求值为 none', () {
    const style = ElStyle(clipBehavior: Clip.hardEdge);
    expect(style, const ElStyle(clipBehavior: Clip.hardEdge));
    expect(style, isNot(const ElStyle()));
    expect(style.copyWith().clipBehavior, Clip.hardEdge);
    expect(style.copyWith(clipBehavior: null).clipBehavior, isNull);
    expect(const ElStyle().merge(style).clipBehavior, Clip.hardEdge);
    expect(style.merge(const ElStyle()).clipBehavior, Clip.hardEdge);
    for (final clip in [null, ...Clip.values]) {
      final render = ElRenderView(
        ElStyle(clipBehavior: clip),
        TextDirection.ltr,
      );
      expect(render.styleEngine.clipBehavior, clip ?? Clip.none);
      expect(render.styleEngine.debugTickerCreated, isFalse);
      render.dispose();
    }
  });

  testWidgets('默认和显式 none 保留 child 角落命中，不产生裁剪或额外图层', (tester) async {
    for (final clip in [null, Clip.none]) {
      await tester.pumpWidget(
        _scene(_style(clip: clip), child: const _OverflowBox()),
      );
      final render = _render(tester);
      final calls = _record(render);
      expect(_calls(calls, #clipRect), isEmpty);
      expect(_calls(calls, #clipRRect), isEmpty);
      expect(_calls(calls, #saveLayer), isEmpty);
      expect(render.needsCompositing, isFalse);
      expect(tester.layers.whereType<ClipRectLayer>(), isEmpty);
      expect(tester.layers.whereType<ClipRRectLayer>(), isEmpty);
      expect(render.describeApproximatePaintClip(render.child!), isNull);
      expect(render.hitTestSelf(const Offset(1, 1)), isFalse);
      expect(
        render.hitTest(BoxHitTestResult(), position: const Offset(1, 1)),
        isTrue,
      );
    }
  });

  for (final clip in [
    Clip.hardEdge,
    Clip.antiAlias,
    Clip.antiAliasWithSaveLayer,
  ]) {
    testWidgets('$clip 的矩形裁剪覆盖背景和 child，坐标不包含 margin', (tester) async {
      await tester.pumpWidget(
        _scene(
          ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            margin: const EdgeInsets.fromLTRB(7, 11, 13, 17),
            padding: const EdgeInsets.all(4),
            clipBehavior: clip,
          ),
          child: const _OverflowBox(),
        ),
      );
      final render = _render(tester);
      final calls = _record(render, offset: const Offset(23, 31));
      final clipping = _calls(calls, #clipRect).single;
      expect(
        clipping.positionalArguments.single,
        const Rect.fromLTWH(30, 42, 100, 60),
      );
      expect(clipping.namedArguments[#doAntiAlias], clip != Clip.hardEdge);
      expect(_calls(calls, #clipRRect), isEmpty);
      final draws = _calls(calls, #drawRect).toList();
      expect(draws, hasLength(2));
      expect((draws[0].positionalArguments[1] as Paint).color, _red);
      expect((draws[1].positionalArguments[1] as Paint).color, _blue);
      expect(
        calls.map((call) => call.memberName),
        containsAllInOrder([#save, #clipRect, #drawRect, #drawRect, #restore]),
      );
      expect(
        _calls(calls, #saveLayer),
        hasLength(clip == Clip.antiAliasWithSaveLayer ? 1 : 0),
      );
      expect(render.needsCompositing, isFalse);
      expect(tester.layers.whereType<ClipRectLayer>(), isEmpty);
      expect(tester.layers.whereType<ClipRRectLayer>(), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$clip 的圆角裁剪与背景使用同一最终形状', (tester) async {
      const radius = BorderRadius.only(
        topLeft: Radius.elliptical(200, 100),
        topRight: Radius.elliptical(100, 70),
        bottomLeft: Radius.elliptical(30, 90),
        bottomRight: Radius.elliptical(80, 30),
      );
      await tester.pumpWidget(
        _scene(
          _style(clip: clip, radius: radius),
          child: const _OverflowBox(),
        ),
      );
      final render = _render(tester);
      final calls = _record(render);
      final clipping = _calls(calls, #clipRRect).single;
      final expected = radius
          .toRRect(const Rect.fromLTWH(0, 0, 100, 60))
          .scaleRadii();
      expect(clipping.positionalArguments.single, expected);
      expect(clipping.namedArguments[#doAntiAlias], clip != Clip.hardEdge);
      expect(
        _calls(calls, #drawRect).first.positionalArguments.first,
        expected.outerRect,
      );
      expect(_calls(calls, #drawRRect), isEmpty);
      expect(
        calls.map((call) => call.memberName),
        containsAllInOrder([#save, #clipRRect, #drawRect, #drawRect, #restore]),
      );
      expect(
        _calls(calls, #saveLayer),
        hasLength(clip == Clip.antiAliasWithSaveLayer ? 1 : 0),
      );
      expect(render.needsCompositing, isFalse);
      expect(tester.layers.whereType<ClipRRectLayer>(), isEmpty);
    });
  }

  testWidgets('无背景时仍裁剪 child，圆角外和 margin 内不再命中 child', (tester) async {
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 100,
          height: 60,
          margin: EdgeInsets.all(10),
          borderRadius: BorderRadius.all(Radius.circular(30)),
          clipBehavior: Clip.hardEdge,
        ),
        child: const _OverflowBox(),
      ),
    );
    final render = _render(tester);
    final calls = _record(render);
    expect(
      render.describeApproximatePaintClip(render.child!),
      const Rect.fromLTWH(10, 10, 100, 60),
    );
    expect(_calls(calls, #clipRRect), hasLength(1));
    expect(_calls(calls, #drawRRect), isEmpty);
    expect(_calls(calls, #drawRect), hasLength(1));
    expect(render.hitTestSelf(const Offset(60, 40)), isFalse);
    expect(
      render.hitTest(BoxHitTestResult(), position: const Offset(11, 11)),
      isFalse,
    );
    expect(
      render.hitTest(BoxHitTestResult(), position: const Offset(5, 40)),
      isFalse,
    );
    final inside = BoxHitTestResult();
    expect(render.hitTest(inside, position: const Offset(60, 40)), isTrue);
    expect(inside.path.any((entry) => entry.target == render.child), isTrue);
  });

  testWidgets('clip 切换和清空立即生效，不参与 all 过渡或触发布局', (tester) async {
    final counts = _Counts();
    var builds = 0;
    final child = Builder(
      builder: (_) {
        builds++;
        return _OverflowBox(counts: counts);
      },
    );
    await tester.pumpWidget(
      _scene(
        _style(transitions: _linear),
        child: child,
        counts: counts,
      ),
    );
    final render = _render(tester);
    final hostLayouts = counts.hostLayouts, childLayouts = counts.childLayouts;
    for (final clip in [
      Clip.hardEdge,
      Clip.antiAlias,
      Clip.antiAliasWithSaveLayer,
      Clip.none,
      Clip.hardEdge,
      null,
    ]) {
      await tester.pumpWidget(
        _scene(
          _style(clip: clip, transitions: _linear),
          child: child,
          counts: counts,
        ),
      );
      expect(render.styleEngine.clipBehavior, clip ?? Clip.none);
      expect(render.styleEngine.debugTickerCreated, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      final calls = _record(render);
      expect(
        _calls(calls, #clipRRect),
        hasLength(clip == null || clip == Clip.none ? 0 : 1),
      );
      expect(counts.hostLayouts, hostLayouts);
      expect(counts.childLayouts, childLayouts);
      expect(builds, 1);
    }
  });

  testWidgets('活动圆角过渡期间打开或关闭 clip 保持原始时间线', (tester) async {
    await tester.pumpWidget(_scene(_style(radius: null, transitions: _linear)));
    await tester.pumpWidget(_scene(_style(transitions: _linear)));
    await tester.pump(const Duration(milliseconds: 50));
    final render = _render(tester);
    expect(render.styleEngine.borderRadius, BorderRadius.circular(15));
    await tester.pumpWidget(
      _scene(_style(clip: Clip.hardEdge, transitions: _linear)),
    );
    expect(render.styleEngine.clipBehavior, Clip.hardEdge);
    expect(render.styleEngine.borderRadius, BorderRadius.circular(15));
    expect(_calls(_record(render), #clipRRect), hasLength(1));
    await tester.pump(const Duration(milliseconds: 25));
    expect(render.styleEngine.borderRadius, BorderRadius.circular(22.5));
    await tester.pumpWidget(_scene(_style(transitions: _linear)));
    expect(render.styleEngine.clipBehavior, Clip.none);
    expect(_calls(_record(render), #clipRRect), isEmpty);
    await tester.pump(const Duration(milliseconds: 25));
    expect(render.styleEngine.borderRadius, BorderRadius.circular(30));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('宽高、圆角同步过渡时裁剪与绘制每帧保持一致，清空后改用矩形', (tester) async {
    ElStyle style(double width, double height, BorderRadius? radius) => ElStyle(
      width: width,
      height: height,
      backgroundColor: _red,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      transitions: _linear,
    );
    await tester.pumpWidget(_scene(style(100, 60, BorderRadius.circular(110))));
    await tester.pumpWidget(_scene(style(200, 100, BorderRadius.circular(30))));
    final render = _render(tester);
    for (final (size, radius) in [
      (const Size(150, 80), 40.0),
      (const Size(200, 100), 30.0),
    ]) {
      await tester.pump(const Duration(milliseconds: 50));
      final expected = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      );
      final calls = _record(render);
      expect(
        _calls(calls, #clipRRect).single.positionalArguments.first,
        expected,
      );
      expect(
        _calls(calls, #drawRect).single.positionalArguments.first,
        expected.outerRect,
      );
      expect(_calls(calls, #drawRRect), isEmpty);
    }
    await tester.pumpWidget(_scene(style(200, 100, null)));
    await tester.pump(const Duration(milliseconds: 50));
    final expected = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 200, 100),
      const Radius.circular(15),
    );
    expect(
      _calls(_record(render), #clipRRect).single.positionalArguments.first,
      expected,
    );
    await tester.pump(const Duration(milliseconds: 50));
    final calls = _record(render);
    expect(_calls(calls, #clipRRect), isEmpty);
    expect(
      _calls(calls, #clipRect).single.positionalArguments.first,
      const Rect.fromLTWH(0, 0, 200, 100),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('auto child 尺寸变化后圆角裁剪使用正式盒子尺寸', (tester) async {
    const style = ElStyle(
      borderRadius: BorderRadius.all(Radius.elliptical(120, 80)),
      clipBehavior: Clip.hardEdge,
    );
    for (final size in [const Size(40, 30), const Size(160, 70)]) {
      await tester.pumpWidget(
        _scene(
          style,
          child: SizedBox(width: size.width, height: size.height),
        ),
      );
      final render = _render(tester);
      expect(render.boxLayout.boxSize, size);
      expect(
        _calls(_record(render), #clipRRect).single.positionalArguments.first,
        style.borderRadius!
            .resolve(TextDirection.ltr)
            .toRRect(Offset.zero & size)
            .scaleRadii(),
      );
    }
  });

  testWidgets('已有合成 child 时复用裁剪层，切换形状与移除裁剪释放旧层', (tester) async {
    const child = RepaintBoundary(child: _OverflowBox());
    await tester.pumpWidget(
      _scene(_style(clip: Clip.antiAliasWithSaveLayer), child: child),
    );
    final render = _render(tester);
    expect(render.needsCompositing, isTrue);
    final rounded = tester.layers.whereType<ClipRRectLayer>().single;
    expect(rounded.clipBehavior, Clip.antiAliasWithSaveLayer);
    await tester.pumpWidget(
      _scene(
        _style(
          clip: Clip.hardEdge,
          radius: BorderRadius.circular(12),
          color: _blue,
        ),
        child: child,
      ),
    );
    expect(tester.layers.whereType<ClipRRectLayer>().single, same(rounded));
    expect(rounded.clipBehavior, Clip.hardEdge);
    await tester.pumpWidget(
      _scene(_style(clip: Clip.antiAlias, radius: null), child: child),
    );
    expect(tester.layers.whereType<ClipRRectLayer>(), isEmpty);
    expect(rounded.attached, isFalse);
    expect(rounded.debugDisposed, isTrue);
    final rectangular = tester.layers.whereType<ClipRectLayer>().single;
    expect(rectangular.clipBehavior, Clip.antiAlias);
    await tester.pumpWidget(
      _scene(_style(clip: Clip.none, radius: null), child: child),
    );
    expect(tester.layers.whereType<ClipRectLayer>(), isEmpty);
    expect(rectangular.attached, isFalse);
    expect(rectangular.debugDisposed, isTrue);
    await tester.pumpWidget(
      _scene(_style(clip: Clip.antiAliasWithSaveLayer), child: child),
    );
    final restored = tester.layers.whereType<ClipRRectLayer>().single;
    expect(restored, isNot(same(rounded)));
    await tester.pumpWidget(const SizedBox());
    expect(restored.attached, isFalse);
    expect(restored.debugDisposed, isTrue);
    expect(tester.layers.whereType<ClipRectLayer>(), isEmpty);
    expect(tester.layers.whereType<ClipRRectLayer>(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
