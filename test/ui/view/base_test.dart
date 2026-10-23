import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// 场景中接受样式的视图标识。
const viewKey = ValueKey('view');

/// 在方向、父约束和 child 都真实参与布局的环境中挂载视图。
Widget viewScene(
  ElStyle style, {
  Widget? child,
  double width = 400,
  double height = 300,
  TextDirection direction = TextDirection.ltr,
  Key key = viewKey,
}) => Directionality(
  textDirection: direction,
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: height),
      child: ElView(key: key, style: style, child: child),
    ),
  ),
);

/// 获取已挂载视图的实际渲染结果，不读取组件内部状态。
RenderBox viewBox(WidgetTester tester, {Key key = viewKey}) =>
    tester.renderObject<RenderBox>(find.byKey(key));

/// 读取包含 margin 的实际占位。
Size viewSize(WidgetTester tester, {Key key = viewKey}) =>
    tester.getSize(find.byKey(key));

/// 记录实际绘制输出，用于验证背景、圆角与裁剪的可见结果。
List<Invocation> recordView(
  WidgetTester tester, {
  Key key = viewKey,
  Offset offset = Offset.zero,
}) {
  final canvas = TestRecordingCanvas();
  viewBox(tester, key: key).paint(TestRecordingPaintingContext(canvas), offset);
  return canvas.invocations.map((entry) => entry.invocation).toList();
}

const _red = Color(0xffff0000), _blue = Color(0xff0000ff);
const _radiusTransition = [
  ElTransition.field(
    ElTransitionField.borderRadius,
    Duration(milliseconds: 100),
    Curves.linear,
  ),
];

ElStyle _radiusStyle(BorderRadiusGeometry? radius, {Color? color = _red}) =>
    ElStyle(
      width: 100,
      height: 60,
      backgroundColor: color,
      borderRadius: radius,
      transitions: _radiusTransition,
    );

void _background(
  WidgetTester tester,
  BorderRadius? radius, {
  Rect rect = const Rect.fromLTWH(0, 0, 100, 60),
  Color color = _red,
}) => expect(
  viewBox(tester),
  radius == null
      ? (paints..rect(rect: rect, color: color))
      : (paints..rrect(rrect: radius.toRRect(rect).scaleRadii(), color: color)),
);

const _overflowKey = ValueKey('clip-overflow-child');
const _overflow = OverflowBox(
  alignment: Alignment.topLeft,
  minWidth: 160,
  maxWidth: 160,
  minHeight: 100,
  maxHeight: 100,
  child: ColoredBox(key: _overflowKey, color: _blue),
);

ElStyle _clipStyle({
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

Iterable<Invocation> _calls(List<Invocation> calls, Symbol method) =>
    calls.where((call) => call.memberName == method);

bool _hits(WidgetTester tester, Offset position, {Key key = viewKey}) =>
    viewBox(tester, key: key).hitTest(BoxHitTestResult(), position: position);

void _clip(
  WidgetTester tester,
  Clip clip, {
  BorderRadius? radius,
  Rect rect = const Rect.fromLTWH(0, 0, 100, 60),
  Offset offset = Offset.zero,
  Key key = viewKey,
}) {
  final calls = recordView(tester, key: key, offset: offset);
  if (clip == Clip.none) {
    expect(calls.map((call) => call.memberName), isNot(contains(#clipRect)));
    expect(calls.map((call) => call.memberName), isNot(contains(#clipRRect)));
    return;
  }
  final invocation = _calls(
    calls,
    radius == null ? #clipRect : #clipRRect,
  ).first;
  expect(
    invocation.positionalArguments.first,
    radius == null
        ? rect.shift(offset)
        : radius.toRRect(rect).scaleRadii().shift(offset),
  );
  expect(invocation.namedArguments[#doAntiAlias], clip != Clip.hardEdge);
  if (clip == Clip.antiAliasWithSaveLayer) {
    expect(
      _calls(calls, #saveLayer).first.positionalArguments.first,
      rect.shift(offset),
    );
  }
}

Color _color(RenderBox box) {
  Color? result;
  expect(
    box,
    paints..something((method, arguments) {
      if (method != #drawRect) return false;
      result = (arguments[1] as Paint).color;
      return true;
    }),
  );
  return result!;
}

const _borderCaptureKey = ValueKey('border-capture');
const _green = Color(0xff00ff00), _yellow = Color(0xffffff00);

class _Pixels {
  const _Pixels(this.bytes, this.width);

  final ByteData bytes;
  final int width;

  Color at(int x, int y) {
    final index = (y * width + x) * 4;
    return Color.fromARGB(
      bytes.getUint8(index + 3),
      bytes.getUint8(index),
      bytes.getUint8(index + 1),
      bytes.getUint8(index + 2),
    );
  }
}

/// 在视觉盒四周保留空间，读取真实合成后的内外描边像素。
Future<_Pixels> _borderPixels(
  WidgetTester tester,
  ElStyle style, {
  Widget? child,
  TextDirection direction = TextDirection.ltr,
  Widget Function(Widget)? wrap,
}) async {
  final view = ElView(key: viewKey, style: style, child: child);
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Center(
        child: RepaintBoundary(
          key: _borderCaptureKey,
          child: SizedBox(
            width: 160,
            height: 120,
            child: Center(child: wrap?.call(view) ?? view),
          ),
        ),
      ),
    ),
  );
  return (await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_borderCaptureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      return _Pixels(bytes!, image.width);
    } finally {
      image.dispose();
    }
  }))!;
}

void _pixel(Color actual, Color expected) {
  expect(actual.a, closeTo(expected.a, 2 / 255));
  if (expected.a == 0) return;
  expect(actual.r, closeTo(expected.r, 2 / 255));
  expect(actual.g, closeTo(expected.g, 2 / 255));
  expect(actual.b, closeTo(expected.b, 2 / 255));
}

void _point(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-6));
  expect(actual.dy, closeTo(expected.dy, 1e-6));
}

Rect _semanticRect(SemanticsNode node, SemanticsNode ancestor) {
  var matrix = Matrix4.identity();
  for (var current = node; current != ancestor; current = current.parent!) {
    if (current.transform != null) matrix = current.transform! * matrix;
  }
  return MatrixUtils.transformRect(matrix, node.rect);
}

void _rect(Rect actual, Rect expected) {
  _point(actual.topLeft, expected.topLeft);
  _point(actual.bottomRight, expected.bottomRight);
}

void main() {
  group('视觉变换基本功能', () {
    testWidgets('复制合并与清空变换只移动画面，布局占位及只读尺寸查询保持不变', (tester) async {
      const childKey = ValueKey('transform-layout-child');
      const style = ElStyle(
        width: 100,
        height: 60,
        transform: ElTransform.translate(20, 10),
      );
      for (final (value, offset) in <(ElStyle, Offset)>[
        (style, const Offset(20, 10)),
        (
          style.copyWith(transform: const ElTransform.translate(-10, 5)),
          const Offset(-10, 5),
        ),
        (
          style.merge(const ElStyle(transform: ElTransform.translate(8, 6))),
          const Offset(8, 6),
        ),
        (
          style.copyWith(transform: null, transformAlignment: null),
          Offset.zero,
        ),
      ]) {
        await tester.pumpWidget(
          viewScene(
            value,
            child: const SizedBox(key: childKey, width: 20, height: 10),
          ),
        );
        final child = tester.renderObject<RenderBox>(find.byKey(childKey));
        final box = viewBox(tester);
        expect(viewSize(tester), const Size(100, 60));
        expect(
          box.getDryLayout(const BoxConstraints(maxWidth: 200, maxHeight: 200)),
          const Size(100, 60),
        );
        expect(box.getMaxIntrinsicWidth(300), 100);
        expect(box.getMaxIntrinsicHeight(300), 60);
        _point(child.localToGlobal(Offset.zero, ancestor: box), offset);
      }
    });

    testWidgets('便捷构造和完整矩阵让后代坐标与真实绘制采用同一个变换', (tester) async {
      const childKey = ValueKey('transform-coordinate-child');
      final matrix = Matrix4.identity()..setTranslationRaw(12, 6, 0);
      for (final (transform, expected) in <(ElTransform, Offset)>[
        (const ElTransform.identity(), const Offset(10, 20)),
        (const ElTransform.translate(12, 6), const Offset(22, 26)),
        (const ElTransform.translateX(12), const Offset(22, 20)),
        (const ElTransform.translateY(6), const Offset(10, 26)),
        (const ElTransform.translateZ(6), const Offset(10, 20)),
        (const ElTransform.translate3d(12, 6, 8), const Offset(22, 26)),
        (const ElTransform.scale(2, 0.5), const Offset(20, 10)),
        (const ElTransform.scaleX(2), const Offset(20, 20)),
        (const ElTransform.scaleY(0.5), const Offset(10, 10)),
        (const ElTransform.scaleZ(2), const Offset(10, 20)),
        (const ElTransform.scale3d(2, 0.5, 3), const Offset(20, 10)),
        (ElTransform.rotate(math.pi / 2), const Offset(-20, 10)),
        (ElTransform.rotateX(math.pi / 3), const Offset(10, 10)),
        (ElTransform.rotateY(math.pi / 3), const Offset(5, 20)),
        (ElTransform.rotateZ(math.pi / 2), const Offset(-20, 10)),
        (ElTransform.rotate3d(0, 0, 2, math.pi / 2), const Offset(-20, 10)),
        (ElTransform.rotate3d(0, 0, 1e300, math.pi / 2), const Offset(-20, 10)),
        (
          ElTransform.skew(math.atan(0.5), math.atan(0.25)),
          const Offset(20, 22.5),
        ),
        (ElTransform.skewX(math.atan(0.5)), const Offset(20, 20)),
        (ElTransform.skewY(math.atan(0.25)), const Offset(10, 22.5)),
        (const ElTransform.perspective(500), const Offset(10, 20)),
        (
          const ElTransform.matrix(1, 0.25, 0.5, 1, 12, 6),
          const Offset(32, 28.5),
        ),
        (
          const ElTransform.matrix3d(
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            12,
            6,
            0,
            1,
          ),
          const Offset(22, 26),
        ),
        (ElTransform.matrix4(matrix), const Offset(22, 26)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: 100,
              height: 60,
              transform: transform,
              transformAlignment: Alignment.topLeft,
            ),
            child: const SizedBox(key: childKey, width: 40, height: 40),
          ),
        );
        final child = tester.renderObject<RenderBox>(find.byKey(childKey));
        final box = viewBox(tester);
        const local = Offset(10, 20);
        _point(child.localToGlobal(local, ancestor: box), expected);
        _point(
          MatrixUtils.transformPoint(child.getTransformTo(box), local),
          expected,
        );
        _point(child.globalToLocal(child.localToGlobal(local)), local);
      }
      for (final (transform, inside, outside)
          in <(ElTransform, Offset, Offset)>[
            (
              const ElTransform.translateX(20),
              const Offset(140, 60),
              const Offset(40, 60),
            ),
            (
              const ElTransform.scale(0.5),
              const Offset(80, 60),
              const Offset(40, 60),
            ),
            (
              ElTransform.rotate(math.pi / 2),
              const Offset(80, 15),
              const Offset(40, 60),
            ),
          ]) {
        final pixels = await _borderPixels(
          tester,
          ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            transform: transform,
          ),
        );
        _pixel(pixels.at(inside.dx.toInt(), inside.dy.toInt()), _red);
        _pixel(
          pixels.at(outside.dx.toInt(), outside.dy.toInt()),
          const Color(0x00000000),
        );
      }
    });

    testWidgets('原点优先级与方向性对齐以含 padding、不含 margin 的视觉盒为准', (tester) async {
      const childKey = ValueKey('transform-origin-child');
      final transform = const ElTransform.scale(2)
          .alignment(Alignment.bottomRight);
      for (final (alignment, direction, expected)
          in <(AlignmentGeometry?, TextDirection, Offset)>[
            (null, TextDirection.ltr, const Offset(-74, -36)),
            (Alignment.topLeft, TextDirection.ltr, const Offset(26, 24)),
            (
              AlignmentDirectional.centerStart,
              TextDirection.ltr,
              const Offset(26, -6),
            ),
            (
              AlignmentDirectional.centerStart,
              TextDirection.rtl,
              const Offset(-74, -6),
            ),
          ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: 100,
              height: 60,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.fromLTRB(6, 4, 10, 8),
              transform: transform,
              transformAlignment: alignment,
            ),
            direction: direction,
            child: const SizedBox(key: childKey, width: 20, height: 10),
          ),
        );
        final child = tester.renderObject<RenderBox>(find.byKey(childKey));
        _point(
          child.localToGlobal(Offset.zero, ancestor: viewBox(tester)),
          expected,
        );
        expect(viewSize(tester), const Size(116, 72));
      }
    });

    testWidgets('变换包住组透明、装饰和合成 child，自身与祖先裁剪各守住其坐标范围', (tester) async {
      final style = ElStyle(
        width: 100,
        height: 60,
        transform: const ElTransform.translateX(10),
        opacity: 0.5,
        gradient: const LinearGradient(colors: [_green, _green]),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        boxShadow: const [BoxShadow(color: _blue, offset: Offset(12, 0))],
        border: Border.all(color: _yellow, width: 4),
        outline: const ElOutline(width: 4, color: _red),
      );
      var pixels = await _borderPixels(
        tester,
        style,
        child: const RepaintBoundary(
          child: Align(
            child: SizedBox(
              width: 40,
              height: 20,
              child: ColoredBox(color: _blue),
            ),
          ),
        ),
      );
      for (final (point, color) in <(Offset, Color)>[
        (const Offset(90, 60), const Color(0x800000ff)),
        (const Offset(90, 45), const Color(0x8000ff00)),
        (const Offset(42, 60), const Color(0x80ffff00)),
        (const Offset(38, 60), const Color(0x80ff0000)),
        (const Offset(150, 60), const Color(0x800000ff)),
        (const Offset(32, 60), const Color(0x00000000)),
      ]) {
        _pixel(pixels.at(point.dx.toInt(), point.dy.toInt()), color);
      }
      pixels = await _borderPixels(
        tester,
        style,
        wrap: (child) => ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 0.6,
            heightFactor: 1,
            child: child,
          ),
        ),
      );
      _pixel(pixels.at(90, 60), const Color(0x8000ff00));
      _pixel(pixels.at(120, 60), const Color(0x00000000));
    });

    testWidgets('实际指针路径使用逆变换后的 child 局部坐标，旧位置不再命中', (tester) async {
      final positions = <Offset>[];
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            transform: ElTransform.scale(0.5),
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => positions.add(event.localPosition),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final origin = viewBox(tester).localToGlobal(Offset.zero);
      await tester.tapAt(origin + const Offset(45, 25));
      expect(positions, hasLength(1));
      _point(positions.single, const Offset(40, 20));
      await tester.tapAt(origin + const Offset(10, 30));
      expect(positions, hasLength(1));
      expect(_hits(tester, const Offset(10, 30)), isFalse);
    });

    testWidgets('不可逆、非有限及跨投影零面的变换不绘制不命中并移除子语义，清空后恢复', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final crossesPlane = Matrix4.identity()..setEntry(3, 0, -0.02);
        for (final transform in <ElTransform?>[
          const ElTransform.scale(0),
          const ElTransform.scaleZ(0),
          const ElTransform.matrix(1, 0, 0, 1, double.nan, 0),
          const ElTransform.matrix(1, 0, 0, 1, double.infinity, 0),
          ElTransform.matrix4(crossesPlane),
          const ElTransform.matrix3d(
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            -1,
          ),
          null,
        ]) {
          final pixels = await _borderPixels(
            tester,
            ElStyle(
              width: 100,
              height: 60,
              backgroundColor: _red,
              transform: transform,
            ),
            child: Semantics(
              container: true,
              label: '变换可访问内容',
              child: const SizedBox.expand(),
            ),
          );
          final visible = transform == null;
          _pixel(pixels.at(80, 60), visible ? _red : const Color(0x00000000));
          expect(_hits(tester, const Offset(50, 30)), visible);
          expect(
            find.semantics.byLabel('变换可访问内容'),
            visible ? findsOne : findsNothing,
          );
          expect(viewSize(tester), const Size(100, 60));
        }
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('真实语义节点的矩形与父级累计变换对应可见画面，嵌套原生变换不重复计算', (tester) async {
      final semantics = tester.ensureSemantics();
      const rootKey = ValueKey('transform-semantics-root');
      try {
        for (final (transform, expected) in <(ElTransform, Rect)>[
          (
            const ElTransform.translate(12, 6),
            const Rect.fromLTWH(22, 16, 20, 10),
          ),
          (const ElTransform.scale(2), const Rect.fromLTWH(20, 20, 40, 20)),
          (
            ElTransform.rotate(math.pi / 2),
            const Rect.fromLTWH(-20, 10, 10, 20),
          ),
        ]) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: Semantics(
                  key: rootKey,
                  container: true,
                  explicitChildNodes: true,
                  child: Transform.translate(
                    offset: const Offset(7, 3),
                    child: ElView(
                      key: viewKey,
                      style: ElStyle(
                        width: 100,
                        height: 60,
                        padding: const EdgeInsets.all(10),
                        transform: transform,
                        transformAlignment: Alignment.topLeft,
                      ),
                      child: Semantics(
                        container: true,
                        label: '坐标标记',
                        child: const SizedBox(width: 20, height: 10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final node = find.semantics.byLabel('坐标标记').evaluate().single;
          final root = tester.semantics.find(find.byKey(rootKey));
          _rect(_semanticRect(node, root), expected.shift(const Offset(7, 3)));
        }
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('嵌套旋转和祖先裁剪下，子语义的裁剪矩形与树节点和原生 Transform 一致', (tester) async {
      final semantics = tester.ensureSemantics();
      const rootKey = ValueKey('transform-clip-semantics-root');
      try {
        Widget markers() => OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 160,
          maxWidth: 160,
          minHeight: 100,
          maxHeight: 100,
          child: Stack(
            children: [
              for (final (label, left) in [
                ('clip-inside', 10.0),
                ('clip-partial', 90.0),
                ('clip-outside', 130.0),
              ])
                Positioned(
                  left: left,
                  top: 20,
                  child: Semantics(
                    container: true,
                    label: label,
                    child: const SizedBox(width: 20, height: 20),
                  ),
                ),
            ],
          ),
        );
        Future<Map<String, (Rect, bool)>> snapshot(
          bool native,
          Clip clip,
        ) async {
          Widget child = native
              ? Transform.rotate(
                  angle: math.pi / 12,
                  child: Transform.translate(
                    offset: const Offset(10, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: clip,
                      child: SizedBox(width: 100, height: 60, child: markers()),
                    ),
                  ),
                )
              : Transform.rotate(
                  angle: math.pi / 12,
                  child: ElView(
                    style: ElStyle(
                      width: 100,
                      height: 60,
                      transform: const ElTransform.translateX(10),
                      clipBehavior: clip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: markers(),
                  ),
                );
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: Semantics(
                  key: rootKey,
                  container: true,
                  explicitChildNodes: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 140,
                      height: 100,
                      child: Center(child: child),
                    ),
                  ),
                ),
              ),
            ),
          );
          final root = tester.semantics.find(find.byKey(rootKey));
          return {
            for (final node
                in find.semantics.byLabel(RegExp('^clip-')).evaluate())
              node.label: (
                _semanticRect(node, root),
                node.flagsCollection.isHidden,
              ),
          };
        }

        for (final clip in [Clip.none, Clip.hardEdge, Clip.antiAlias]) {
          final expected = await snapshot(true, clip);
          final actual = await snapshot(false, clip);
          expect(expected, contains('clip-inside'));
          expect(actual.keys, unorderedEquals(expected.keys));
          for (final label in expected.keys) {
            _rect(actual[label]!.$1, expected[label]!.$1);
            expect(actual[label]!.$2, expected[label]!.$2);
          }
        }
      } finally {
        semantics.dispose();
      }
    });
  });

  group('宽高比基本功能', () {
    testWidgets('显式轴、自然盒、百分比和边距按先比例后限制的顺序求值', (tester) async {
      for (final (style, expected) in <(ElStyle, Size)>[
        (const ElStyle(width: 100, aspectRatio: 2), const Size(100, 50)),
        (const ElStyle(height: 60, aspectRatio: 2), const Size(120, 60)),
        (
          const ElStyle(width: 100, height: 60, aspectRatio: 2),
          const Size(100, 60),
        ),
        (
          const ElStyle(aspectRatio: 2, padding: EdgeInsets.all(10)),
          const Size(100, 50),
        ),
        (
          const ElStyle(
            width: '50%',
            aspectRatio: 2,
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.all(10),
          ),
          const Size(210, 115),
        ),
        (
          const ElStyle(width: 100, maxWidth: 80, aspectRatio: 2),
          const Size(80, 50),
        ),
        (
          const ElStyle(width: 100, minHeight: 70, aspectRatio: 2),
          const Size(100, 70),
        ),
        (const ElStyle(width: 1000, aspectRatio: 2), const Size(400, 300)),
      ]) {
        await tester.pumpWidget(
          viewScene(style, child: const SizedBox(width: 80, height: 40)),
        );
        expect(viewSize(tester), expected, reason: '$style');
      }
    });

    testWidgets('仅有效 auto 因子禁用比例，非法比例恢复自然尺寸', (tester) async {
      for (final (style, expected) in <(ElStyle, Size)>[
        (const ElStyle(aspectRatio: 2, widthFactor: 2), const Size(160, 40)),
        (
          const ElStyle(width: 100, aspectRatio: 2, widthFactor: 2),
          const Size(100, 50),
        ),
        (
          const ElStyle(width: 100, aspectRatio: 2, heightFactor: 2),
          const Size(100, 80),
        ),
        (
          const ElStyle(aspectRatio: 4, widthFactor: 1, heightFactor: 1),
          const Size(80, 20),
        ),
        for (final ratio in <num?>[null, 0, -2, double.nan, double.infinity])
          (ElStyle(aspectRatio: ratio), const Size(80, 40)),
      ]) {
        await tester.pumpWidget(
          viewScene(style, child: const SizedBox(width: 80, height: 40)),
        );
        expect(viewSize(tester), expected);
      }
    });

    testWidgets('真实布局、dry 查询与固有尺寸都包含比例后的盒和外边距', (tester) async {
      const style = ElStyle(
        width: 100,
        aspectRatio: 2,
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.all(5),
      );
      await tester.pumpWidget(
        viewScene(style, child: const SizedBox(width: 80, height: 40)),
      );
      final box = viewBox(tester);
      expect(viewSize(tester), const Size(110, 60));
      expect(
        box.getDryLayout(const BoxConstraints(maxWidth: 400, maxHeight: 300)),
        const Size(110, 60),
      );
      expect(box.getMinIntrinsicWidth(300), 110);
      expect(box.getMaxIntrinsicWidth(300), 110);
      expect(box.getMinIntrinsicHeight(400), 60);
      expect(box.getMaxIntrinsicHeight(400), 60);
      expect(
        box.getDryLayout(const BoxConstraints.tightFor(width: 80, height: 45)),
        const Size(80, 45),
      );
      expect(viewSize(tester), const Size(110, 60));
    });

    testWidgets('比例父盒在 Row 与 Column 中为无界轴的百分比后代提供当前内容参照', (tester) async {
      const nestedKey = ValueKey('ratio-percentage-child');
      for (final vertical in [false, true]) {
        Widget scene(double width, num ratio) {
          const nested = ElView(
            key: nestedKey,
            style: ElStyle(width: '50%', height: '50%'),
          );
          return viewScene(
            ElStyle(
              width: width,
              aspectRatio: ratio,
              padding: const EdgeInsets.all(10),
            ),
            child: vertical
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [nested],
                  )
                : const Row(mainAxisSize: MainAxisSize.min, children: [nested]),
          );
        }

        await tester.pumpWidget(scene(200, 2));
        expect(viewSize(tester), const Size(200, 100));
        expect(tester.getSize(find.byKey(nestedKey)), const Size(90, 40));
        expect(
          viewBox(
            tester,
          ).getDryLayout(const BoxConstraints(maxWidth: 100, maxHeight: 300)),
          const Size(100, 100),
        );
        expect(tester.getSize(find.byKey(nestedKey)), const Size(90, 40));
        await tester.pumpWidget(scene(200, 4));
        expect(tester.getSize(find.byKey(nestedKey)), const Size(90, 15));
        await tester.pumpWidget(scene(300, 4));
        expect(viewSize(tester), const Size(300, 75));
        expect(tester.getSize(find.byKey(nestedKey)), const Size(140, 27.5));
      }
    });
  });

  group('渐变阴影与透明度基本功能', () {
    testWidgets('四项样式支持复制、合并和显式清空，并反映在尺寸与画面上', (tester) async {
      const style = ElStyle(
        width: 100,
        aspectRatio: 2,
        gradient: LinearGradient(colors: [_red, _red]),
        opacity: 0.5,
        boxShadow: [BoxShadow(color: _blue, offset: Offset(12, 0))],
      );
      var pixels = await _borderPixels(tester, style);
      expect(viewSize(tester), const Size(100, 50));
      _pixel(pixels.at(80, 60), const Color(0x80ff0000));
      _pixel(pixels.at(140, 60), const Color(0x800000ff));
      pixels = await _borderPixels(
        tester,
        style.merge(
          const ElStyle(
            aspectRatio: 1,
            gradient: LinearGradient(colors: [_green, _green]),
            opacity: 1,
            boxShadow: [],
          ),
        ),
      );
      expect(viewSize(tester), const Size(100, 100));
      _pixel(pixels.at(80, 60), _green);
      _pixel(pixels.at(140, 60), const Color(0x00000000));
      pixels = await _borderPixels(
        tester,
        style.copyWith(
          aspectRatio: null,
          gradient: null,
          opacity: null,
          boxShadow: null,
        ),
        child: const SizedBox(height: 40),
      );
      expect(viewSize(tester), const Size(100, 40));
      _pixel(pixels.at(80, 60), const Color(0x00000000));
    });

    testWidgets('渐变覆盖背景并响应方向、圆角和尺寸，三种原生渐变均可见', (tester) async {
      const gradient = LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [_red, _blue],
        stops: [0.25, 0.75],
      );
      for (final direction in TextDirection.values) {
        final pixels = await _borderPixels(
          tester,
          const ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _green,
            gradient: gradient,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          direction: direction,
        );
        _pixel(
          pixels.at(40, 60),
          direction == TextDirection.ltr ? _red : _blue,
        );
        _pixel(
          pixels.at(120, 60),
          direction == TextDirection.ltr ? _blue : _red,
        );
        _pixel(pixels.at(30, 30), const Color(0x00000000));
      }
      for (final gradient in const <Gradient>[
        RadialGradient(colors: [_red, _red]),
        SweepGradient(colors: [_blue, _blue]),
      ]) {
        final pixels = await _borderPixels(
          tester,
          ElStyle(width: 100, height: 60, gradient: gradient),
        );
        _pixel(pixels.at(80, 60), gradient.colors.first);
      }
      final pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          backgroundColor: _green,
          gradient: LinearGradient(
            colors: [Color(0x80ff0000), Color(0x80ff0000)],
          ),
        ),
      );
      _pixel(pixels.at(80, 60), const Color(0xff807f00));
      expect(_hits(tester, const Offset(50, 30)), isTrue);
    });

    testWidgets('外阴影按 offset 和 spread 绘制，负 spread、模糊及圆角保留真实边缘', (tester) async {
      const base = ElStyle(width: 100, height: 60, backgroundColor: _green);
      var pixels = await _borderPixels(
        tester,
        base.copyWith(
          boxShadow: const [
            BoxShadow(color: _blue, offset: Offset(12, 0), spreadRadius: 4),
          ],
        ),
      );
      _pixel(pixels.at(140, 60), _blue);
      _pixel(pixels.at(80, 28), _blue);
      _pixel(pixels.at(80, 60), _green);
      expect(viewSize(tester), const Size(100, 60));
      expect(
        viewBox(tester).paintBounds.contains(const Offset(114, 30)),
        isTrue,
      );
      expect(_hits(tester, const Offset(110, 30)), isFalse);
      pixels = await _borderPixels(
        tester,
        base.copyWith(
          backgroundColor: null,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          boxShadow: const [BoxShadow(color: _blue, spreadRadius: -5)],
        ),
      );
      _pixel(pixels.at(32, 60), const Color(0x00000000));
      _pixel(pixels.at(35, 35), const Color(0x00000000));
      _pixel(pixels.at(80, 60), _blue);
      final previous = debugDisableShadows;
      debugDisableShadows = false;
      try {
        pixels = await _borderPixels(
          tester,
          base.copyWith(
            boxShadow: const [BoxShadow(color: _blue, blurRadius: 8)],
          ),
        );
        expect(pixels.at(80, 26).a, inExclusiveRange(0, 1));
        expect(pixels.at(80, 26).b, closeTo(1, 2 / 255));
        _pixel(pixels.at(80, 60), _green);
        expect(viewBox(tester).paintBounds.top, lessThan(-8));
      } finally {
        debugDisableShadows = previous;
      }
    });

    testWidgets('内外阴影混排保持声明顺序，内阴影覆盖背景且在 child 之前', (tester) async {
      final pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          backgroundColor: _green,
          boxShadow: [
            BoxShadow(color: _red, offset: Offset(12, 0)),
            ElBoxShadow(color: _blue, offset: Offset(12, 0)),
            ElBoxShadow(color: _red, spreadRadius: 8, inset: true),
            ElBoxShadow(color: Color(0x800000ff), spreadRadius: 8, inset: true),
          ],
        ),
        child: const Align(
          child: SizedBox(
            width: 40,
            height: 20,
            child: ColoredBox(color: _yellow),
          ),
        ),
      );
      _pixel(pixels.at(140, 60), _blue);
      _pixel(pixels.at(35, 60), const Color(0xff7f0080));
      _pixel(pixels.at(80, 45), _green);
      _pixel(pixels.at(80, 60), _yellow);
      expect(viewSize(tester), const Size(100, 60));
    });

    testWidgets('自身裁剪保留外阴影，内阴影与渐变遵守圆角，边框和轮廓最后绘制', (tester) async {
      for (final clip in Clip.values) {
        final pixels = await _borderPixels(
          tester,
          ElStyle(
            width: 100,
            height: 60,
            gradient: const LinearGradient(colors: [_green, _green]),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: clip,
            boxShadow: const [
              BoxShadow(color: _blue, offset: Offset(12, 0)),
              ElBoxShadow(color: _red, spreadRadius: 8, inset: true),
            ],
            border: Border.all(color: _yellow, width: 4),
            outline: const ElOutline(width: 4, color: _red),
          ),
        );
        _pixel(pixels.at(140, 60), _blue);
        _pixel(pixels.at(35, 60), _red);
        _pixel(pixels.at(32, 60), _yellow);
        _pixel(pixels.at(28, 60), _red);
        _pixel(pixels.at(30, 30), const Color(0x00000000));
      }
    });

    testWidgets('透明度对背景、渐变、阴影、合成 child、边框和轮廓整体合成', (tester) async {
      for (final (clip, margin) in <(Clip, EdgeInsets?)>[
        (Clip.antiAlias, null),
        (Clip.antiAliasWithSaveLayer, const EdgeInsets.fromLTRB(6, 4, 10, 8)),
      ]) {
        final pixels = await _borderPixels(
          tester,
          ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            gradient: const LinearGradient(colors: [_green, _green]),
            opacity: 0.5,
            clipBehavior: clip,
            margin: margin,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: _blue, offset: Offset(12, 0)),
              ElBoxShadow(color: _red, spreadRadius: 8, inset: true),
            ],
            border: Border.all(color: _yellow, width: 4),
            outline: const ElOutline(width: 4, color: _blue),
          ),
          child: const RepaintBoundary(
            child: Align(
              child: SizedBox(
                width: 40,
                height: 20,
                child: ColoredBox(color: _blue),
              ),
            ),
          ),
        );
        final origin =
            tester.getTopLeft(find.byKey(viewKey)) -
            tester.getTopLeft(find.byKey(_borderCaptureKey)) +
            Offset(margin?.left ?? 0, margin?.top ?? 0);
        for (final (position, expected) in <(Offset, Color)>[
          (const Offset(50, 30), const Color(0x800000ff)),
          (const Offset(50, 15), const Color(0x8000ff00)),
          (const Offset(5, 30), const Color(0x80ff0000)),
          (const Offset(2, 30), const Color(0x80ffff00)),
          (const Offset(-2, 30), const Color(0x800000ff)),
          (const Offset(110, 30), const Color(0x800000ff)),
        ]) {
          final point = origin + position;
          _pixel(pixels.at(point.dx.toInt(), point.dy.toInt()), expected);
        }
        expect(
          viewSize(tester),
          margin?.inflateSize(const Size(100, 60)) ?? const Size(100, 60),
        );
      }
      await tester.pumpWidget(const SizedBox());
      final pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          backgroundColor: _red,
          opacity: 0.5,
        ),
        wrap: (child) => ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 0.5,
            heightFactor: 1,
            child: child,
          ),
        ),
      );
      final origin =
          tester.getTopLeft(find.byKey(viewKey)) -
          tester.getTopLeft(find.byKey(_borderCaptureKey));
      // 首次挂载就半透明且没有 child，也必须服从祖先裁剪。
      _pixel(
        pixels.at((origin.dx + 25).toInt(), (origin.dy + 30).toInt()),
        const Color(0x80ff0000),
      );
      _pixel(
        pixels.at((origin.dx + 75).toInt(), (origin.dy + 30).toInt()),
        const Color(0x00000000),
      );
    });

    testWidgets('透明度默认与非法值为一，越界钳制，零不命中但保留语义及布局', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final opacity in <num?>[
          null,
          1,
          2,
          double.nan,
          double.infinity,
          0,
          -1,
        ]) {
          final pixels = await _borderPixels(
            tester,
            ElStyle(
              width: 100,
              height: 60,
              backgroundColor: _red,
              opacity: opacity,
            ),
            child: Semantics(label: '透明内容', child: const SizedBox.expand()),
          );
          final hidden = opacity != null && opacity.isFinite && opacity <= 0;
          _pixel(pixels.at(80, 60), hidden ? const Color(0x00000000) : _red);
          expect(_hits(tester, const Offset(50, 30)), !hidden);
          expect(viewSize(tester), const Size(100, 60));
          expect(find.bySemanticsLabel('透明内容'), findsOneWidget);
        }
      } finally {
        semantics.dispose();
      }
    });
  });

  group('轮廓基本功能', () {
    testWidgets('默认零宽、透明和空轮廓不画，正宽默认黑色且不创建命中区域', (tester) async {
      for (final outline in <ElOutline?>[
        null,
        const ElOutline(),
        const ElOutline(color: _red, offset: 20),
        const ElOutline(width: 8, color: Color(0x00ff0000), offset: 20),
      ]) {
        await tester.pumpWidget(
          viewScene(ElStyle(width: 100, height: 60, outline: outline)),
        );
        expect(viewBox(tester), paintsNothing);
        expect(viewBox(tester).paintBounds, const Rect.fromLTWH(0, 0, 100, 60));
        expect(_hits(tester, const Offset(50, 30)), isFalse);
      }
      final pixels = await _borderPixels(
        tester,
        const ElStyle(width: 100, height: 60, outline: ElOutline(width: 8)),
      );
      expect(pixels.at(80, 25), const Color(0xff000000));
      expect(pixels.at(80, 31).a, 0);
      expect(viewBox(tester).paintBounds, const Rect.fromLTRB(-8, -8, 108, 68));
      expect(_hits(tester, const Offset(-4, 30)), isFalse);
      expect(_hits(tester, const Offset(50, 30)), isFalse);
    });

    testWidgets('轮廓声明整体替换与清空，渐变显式移除后恢复保留颜色', (tester) async {
      const outline = ElOutline(
        width: 8,
        color: _red,
        offset: 4,
        gradient: LinearGradient(colors: [_blue, _blue]),
      );
      const base = ElStyle(width: 100, height: 60, outline: outline);
      var pixels = await _borderPixels(tester, base);
      expect(pixels.at(80, 23), _blue);
      pixels = await _borderPixels(
        tester,
        base.copyWith(outline: outline.copyWith(gradient: null)),
      );
      expect(pixels.at(80, 23), _red);
      pixels = await _borderPixels(
        tester,
        base.merge(const ElStyle(outline: ElOutline(width: 4, color: _green))),
      );
      expect(pixels.at(80, 28), _green);
      expect(pixels.at(80, 23).a, 0);
      await tester.pumpWidget(viewScene(base.copyWith(outline: null)));
      expect(viewBox(tester), paintsNothing);
      expect(viewSize(tester), const Size(100, 60));
      expect(viewBox(tester).paintBounds, const Rect.fromLTWH(0, 0, 100, 60));
    });

    testWidgets('轮廓粗细和偏移不改变 auto、百分比、factor、内外边距及相邻占位', (tester) async {
      const childKey = ValueKey('outline-layout-child');
      const base = ElStyle(
        padding: EdgeInsets.fromLTRB(5, 7, 15, 13),
        margin: EdgeInsets.fromLTRB(3, 4, 7, 6),
        outline: ElOutline(width: 30, offset: 8, color: _red),
      );
      for (final (style, size) in [
        (base, const Size(110, 70)),
        (base.copyWith(width: '50%', height: '50%'), const Size(205, 155)),
        (base.copyWith(widthFactor: 2, heightFactor: 2), const Size(210, 130)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            style,
            child: const SizedBox(key: childKey, width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
        expect(
          tester.getTopLeft(find.byKey(childKey)) -
              tester.getTopLeft(find.byKey(viewKey)),
          const Offset(8, 11),
        );
      }
      const neighborKey = ValueKey('outline-layout-neighbor');
      for (final outline in [
        const ElOutline(width: 2),
        const ElOutline(width: 40, offset: -12),
      ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElView(
                    key: viewKey,
                    style: ElStyle(
                      width: 100,
                      height: 60,
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(5),
                      outline: outline,
                    ),
                    child: const SizedBox(key: childKey, width: 80, height: 40),
                  ),
                  const SizedBox(key: neighborKey, width: 20, height: 20),
                ],
              ),
            ),
          ),
        );
        final origin = tester.getTopLeft(find.byKey(viewKey));
        expect(viewSize(tester), const Size(120, 80));
        expect(
          tester.getTopLeft(find.byKey(childKey)) - origin,
          const Offset(15, 15),
        );
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
        expect(tester.getTopLeft(find.byKey(neighborKey)).dx - origin.dx, 120);
      }
    });

    testWidgets('正偏移留出间隔、负偏移移入盒内，中心线塌缩后不绘制', (tester) async {
      const base = ElStyle(width: 100, height: 60);
      for (final (offset, sampleY, emptyY, bounds) in [
        (6, 22, 27, const Rect.fromLTRB(-10, -10, 110, 70)),
        (0, 28, 31, const Rect.fromLTRB(-4, -4, 104, 64)),
        (-6, 33, 31, const Rect.fromLTWH(0, 0, 100, 60)),
      ]) {
        final pixels = await _borderPixels(
          tester,
          base.copyWith(
            outline: ElOutline(width: 4, color: _red, offset: offset),
          ),
        );
        expect(pixels.at(80, sampleY), _red, reason: 'offset: $offset');
        expect(pixels.at(80, emptyY).a, 0, reason: 'offset: $offset');
        expect(viewBox(tester).paintBounds, bounds);
      }
      for (final offset in [-32, -80]) {
        await tester.pumpWidget(
          viewScene(
            base.copyWith(
              outline: ElOutline(width: 4, color: _red, offset: offset),
            ),
          ),
        );
        expect(viewBox(tester), paintsNothing);
        expect(viewBox(tester).paintBounds, const Rect.fromLTWH(0, 0, 100, 60));
      }
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            margin: EdgeInsets.fromLTRB(3, 4, 7, 6),
            outline: ElOutline(width: 8, offset: 4, color: _red),
          ),
        ),
      );
      expect(viewBox(tester).paintBounds, const Rect.fromLTRB(-9, -8, 115, 76));
    });

    testWidgets('方向性圆角随方向更新，混合圆角与方角各自保留', (tester) async {
      const style = ElStyle(
        width: 100,
        height: 60,
        outline: ElOutline(width: 4, color: _red),
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(20),
          bottomStart: Radius.elliptical(14, 8),
        ),
      );
      for (final direction in TextDirection.values) {
        final pixels = await _borderPixels(tester, style, direction: direction);
        final squareX = direction == TextDirection.ltr ? 133 : 27;
        final roundedX = direction == TextDirection.ltr ? 27 : 133;
        expect(pixels.at(squareX, 27), _red);
        expect(pixels.at(squareX, 93), _red);
        expect(pixels.at(roundedX, 27).a, 0);
        expect(pixels.at(roundedX, 93).a, 0);
        expect(pixels.at(80, 28), _red);
        expect(pixels.at(80, 60).a, 0);
      }
    });

    testWidgets('超大椭圆先规范化，小圆角大外移和内移仍保持正确可见弧线', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            borderRadius: BorderRadius.all(Radius.elliptical(200, 100)),
            outline: ElOutline(width: 8, offset: 4, color: _red),
          ),
        ),
      );
      expect(
        viewBox(tester),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTRB(-8, -8, 108, 68),
            Radius.elliptical(50 + 400 / 54, 25 + 200 / 29),
          ),
          color: _red,
          style: PaintingStyle.stroke,
          strokeWidth: 8,
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            borderRadius: BorderRadius.all(Radius.circular(2)),
            outline: ElOutline(width: 4, offset: 20, color: _red),
          ),
        ),
      );
      expect(
        viewBox(tester),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTRB(-22, -22, 122, 82),
            const Radius.circular(70 / 13),
          ),
          color: _red,
          style: PaintingStyle.stroke,
          strokeWidth: 4,
        ),
      );
      final pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          borderRadius: BorderRadius.all(Radius.circular(2)),
          outline: ElOutline(width: 4, offset: -10, color: _red),
        ),
      );
      expect(pixels.at(37, 37), _red);
      expect(pixels.at(80, 41).a, 0);
      expect(pixels.at(80, 60).a, 0);
    });

    testWidgets('线性渐变覆盖颜色，以描边中心矩形为定义域并响应方向与变换', (tester) async {
      const gradient = LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [_red, _blue],
      );
      const base = ElStyle(
        width: 100,
        height: 60,
        outline: ElOutline(
          width: 8,
          offset: 8,
          color: _green,
          gradient: gradient,
        ),
      );
      for (final direction in TextDirection.values) {
        final pixels = await _borderPixels(tester, base, direction: direction);
        final color = pixels.at(30, 18);
        expect(color.a, 1);
        expect(color.g, 0);
        expect(
          color.r * 255,
          closeTo(direction == TextDirection.ltr ? 229 : 26, 3),
        );
        expect(
          color.b * 255,
          closeTo(direction == TextDirection.ltr ? 26 : 229, 3),
        );
      }
      final pixels = await _borderPixels(
        tester,
        base.copyWith(
          outline: base.outline!.copyWith(
            gradient: const LinearGradient(
              colors: [_red, _blue],
              transform: GradientRotation(3.141592653589793),
            ),
          ),
        ),
      );
      expect(pixels.at(30, 18).b * 255, closeTo(229, 3));
      expect(pixels.at(30, 18).r * 255, closeTo(26, 3));
    });

    testWidgets('径向与扫描渐变均真实绘制在轮廓上，不填充中心', (tester) async {
      const base = ElStyle(width: 100, height: 60);
      var pixels = await _borderPixels(
        tester,
        base.copyWith(
          outline: const ElOutline(
            width: 8,
            color: _green,
            gradient: RadialGradient(colors: [_red, _blue]),
          ),
        ),
      );
      expect(pixels.at(80, 25), _blue);
      expect(pixels.at(25, 60), _blue);
      expect(pixels.at(80, 60).a, 0);
      pixels = await _borderPixels(
        tester,
        base.copyWith(
          outline: const ElOutline(
            width: 8,
            color: _yellow,
            gradient: SweepGradient(colors: [_red, _green, _blue, _red]),
          ),
        ),
      );
      expect(pixels.at(134, 60).r, greaterThan(.95));
      expect(pixels.at(80, 94).g, greaterThan(.7));
      expect(pixels.at(25, 60).g, closeTo(.5, .04));
      expect(pixels.at(25, 60).b, closeTo(.5, .04));
      expect(pixels.at(80, 60).a, 0);
    });

    testWidgets('轮廓在 child 和边框之上，所有自身裁剪模式都保留外部轮廓', (tester) async {
      for (final clip in Clip.values) {
        final pixels = await _borderPixels(
          tester,
          ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _green,
            border: Border.all(color: _red, width: 20),
            outline: const ElOutline(width: 8, offset: -4, color: _yellow),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: clip,
          ),
          child: const RepaintBoundary(child: _overflow),
        );
        expect(pixels.at(80, 28), _yellow, reason: '$clip 外部轮廓');
        expect(pixels.at(80, 32), _yellow, reason: '$clip 轮廓覆盖边框和 child');
        expect(pixels.at(80, 40), _red, reason: '$clip 边框覆盖 child');
        expect(pixels.at(80, 60), _blue);
        expect(pixels.at(150, 60).a, clip == Clip.none ? 1 : 0);
        expect(_hits(tester, const Offset(-2, 30)), isFalse);
      }
    });
  });

  group('边框基本功能', () {
    testWidgets('边框覆盖自然盒，不挤占 auto、百分比和 factor 的内容与边距', (tester) async {
      const childKey = ValueKey('border-layout-child');
      const base = ElStyle(
        padding: EdgeInsets.fromLTRB(5, 7, 15, 13),
        margin: EdgeInsets.fromLTRB(3, 4, 7, 6),
        border: Border.fromBorderSide(BorderSide(color: _red, width: 30)),
      );
      for (final (style, size) in [
        (base, const Size(110, 70)),
        (base.copyWith(width: '50%', height: '50%'), const Size(205, 155)),
        (base.copyWith(widthFactor: 2, heightFactor: 2), const Size(210, 130)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            style,
            child: const SizedBox(key: childKey, width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
        expect(
          tester.getTopLeft(find.byKey(childKey)) -
              tester.getTopLeft(find.byKey(viewKey)),
          const Offset(8, 11),
        );
      }
      const neighborKey = ValueKey('border-layout-neighbor');
      for (final width in [2.0, 40.0]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElView(
                    key: viewKey,
                    style: ElStyle(
                      width: 100,
                      height: 60,
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(5),
                      border: Border.all(color: _red, width: width),
                    ),
                    child: const SizedBox(key: childKey, width: 80, height: 40),
                  ),
                  const SizedBox(key: neighborKey, width: 20, height: 20),
                ],
              ),
            ),
          ),
        );
        final origin = tester.getTopLeft(find.byKey(viewKey));
        expect(viewSize(tester), const Size(120, 80));
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
        expect(
          tester.getTopLeft(find.byKey(childKey)) - origin,
          const Offset(15, 15),
        );
        expect(tester.getTopLeft(find.byKey(neighborKey)).dx - origin.dx, 120);
      }
    });

    testWidgets('边框通过 copyWith、merge 替换与显式清空后更新可见结果', (tester) async {
      const base = ElStyle(
        width: 100,
        height: 60,
        border: Border.fromBorderSide(BorderSide(color: _red, width: 4)),
      );
      var pixels = await _borderPixels(tester, base);
      expect(pixels.at(80, 31), _red);
      pixels = await _borderPixels(
        tester,
        base.merge(
          const ElStyle(
            border: Border.fromBorderSide(BorderSide(color: _green, width: 8)),
          ),
        ),
      );
      expect(pixels.at(80, 35), _green);
      await tester.pumpWidget(viewScene(base.copyWith(border: null)));
      expect(viewBox(tester), paintsNothing);
      expect(viewSize(tester), const Size(100, 60));
    });

    testWidgets('矩形四边独立颜色和粗细正确，单边 none 不留下颜色', (tester) async {
      const border = Border(
        top: BorderSide(color: _red, width: 4),
        right: BorderSide(color: _green, width: 8),
        bottom: BorderSide(color: _blue, width: 12),
        left: BorderSide(color: _yellow, width: 16),
      );
      var pixels = await _borderPixels(
        tester,
        const ElStyle(width: 100, height: 60, border: border),
      );
      for (final (point, color) in [
        (const Offset(80, 31), _red),
        (const Offset(128, 60), _green),
        (const Offset(80, 85), _blue),
        (const Offset(35, 60), _yellow),
      ]) {
        expect(pixels.at(point.dx.toInt(), point.dy.toInt()), color);
      }
      expect(pixels.at(80, 35).a, 0);
      expect(pixels.at(80, 60).a, 0);
      pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          border: Border(top: BorderSide(color: _red, width: 4)),
        ),
      );
      expect(pixels.at(80, 31), _red);
      expect(pixels.at(128, 60).a, 0);
      expect(pixels.at(35, 60).a, 0);
    });

    testWidgets('方向性边框随 LTR 和 RTL 更新，而上下边保持不变', (tester) async {
      const style = ElStyle(
        width: 100,
        height: 60,
        border: BorderDirectional(
          top: BorderSide(color: _red, width: 2),
          start: BorderSide(color: _blue, width: 8),
          end: BorderSide(color: _green, width: 14),
          bottom: BorderSide(color: _yellow, width: 6),
        ),
      );
      for (final direction in TextDirection.values) {
        final pixels = await _borderPixels(tester, style, direction: direction);
        expect(
          pixels.at(34, 60),
          direction == TextDirection.ltr ? _blue : _green,
        );
        expect(
          pixels.at(125, 60),
          direction == TextDirection.ltr ? _green : _blue,
        );
        expect(pixels.at(80, 30), _red);
        expect(pixels.at(80, 87), _yellow);
      }
    });

    testWidgets('孤立底边独占两端完整圆弧，仅与可见相邻边分角', (tester) async {
      const base = ElStyle(
        width: 100,
        height: 60,
        border: Border(bottom: BorderSide(color: _blue, width: 6)),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      );
      var pixels = await _borderPixels(tester, base);
      for (final point in [
        const Offset(34, 78),
        const Offset(42, 86),
        const Offset(126, 78),
        const Offset(118, 86),
      ]) {
        expect(pixels.at(point.dx.toInt(), point.dy.toInt()), _blue);
      }
      expect(pixels.at(42, 33).a, 0);
      pixels = await _borderPixels(
        tester,
        base.copyWith(
          border: const Border(
            bottom: BorderSide(color: _blue, width: 6, strokeAlign: 1),
          ),
        ),
      );
      expect(viewBox(tester).paintBounds, const Rect.fromLTRB(-6, 0, 106, 66));
      expect(pixels.at(26, 75), _blue);
      expect(pixels.at(134, 75), _blue);
      pixels = await _borderPixels(
        tester,
        base.copyWith(
          border: const Border(
            bottom: BorderSide(color: _blue, width: 6),
            left: BorderSide(color: _yellow, width: 10),
          ),
        ),
      );
      expect(pixels.at(34, 78), _yellow);
      expect(pixels.at(42, 86), _blue);
      expect(pixels.at(126, 78), _blue);
      expect(pixels.at(42, 33), _yellow);
      expect(pixels.at(118, 33).a, 0);
    });

    testWidgets('null、全部 none 和全透明边框不绘制，也不单独创建命中区域', (tester) async {
      for (final border in <BoxBorder?>[
        null,
        const Border.fromBorderSide(
          BorderSide(color: _red, width: 30, style: BorderStyle.none),
        ),
        const Border.fromBorderSide(
          BorderSide(color: Color(0x00ff0000), width: 30, strokeAlign: 2),
        ),
      ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: 100,
              height: 60,
              border: border,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
        expect(viewBox(tester), paintsNothing);
        expect(_hits(tester, const Offset(50, 30)), isFalse);
        expect(viewBox(tester).paintBounds, const Rect.fromLTWH(0, 0, 100, 60));
      }
    });

    testWidgets('width 为零的 solid 边框保留 hairline，不变成 none 或填满', (tester) async {
      var pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          border: Border.fromBorderSide(BorderSide(color: _red, width: 0)),
        ),
      );
      expect(pixels.at(80, 29).a + pixels.at(80, 30).a, greaterThan(0));
      expect(pixels.at(80, 32).a, 0);
      expect(pixels.at(80, 60).a, 0);
      expect(_hits(tester, const Offset(50, 30)), isTrue);
      pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          border: Border(
            top: BorderSide(color: _red, width: 0),
            left: BorderSide(color: _blue, width: 8),
            bottom: BorderSide(color: _green, width: 6),
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      );
      expect(pixels.at(80, 29).a + pixels.at(80, 30).a, greaterThan(0));
      expect(pixels.at(34, 60), _blue);
      expect(pixels.at(80, 87), _green);
      expect(pixels.at(129, 60).a, 0);
      expect(pixels.at(80, 60).a, 0);
    });

    testWidgets('内外描边与范围外的有限 strokeAlign 正常，外描边不扩大命中', (tester) async {
      for (final (align, sampleX) in [
        (-2.0, 35),
        (-1.0, 35),
        (0.0, 28),
        (1.0, 25),
        (2.0, 20),
      ]) {
        final pixels = await _borderPixels(
          tester,
          ElStyle(
            width: 100,
            height: 60,
            border: Border.all(color: _red, width: 10, strokeAlign: align),
          ),
        );
        expect(pixels.at(sampleX, 60), _red, reason: 'strokeAlign: $align');
        final outset = (10 * (1 + align) / 2).clamp(0.0, double.infinity);
        expect(
          viewBox(tester).paintBounds,
          Rect.fromLTRB(-outset, -outset, 100 + outset, 60 + outset),
        );
        if (outset > 0) {
          final corner = (30 - outset + 1).toInt();
          expect(
            pixels.at(corner, corner),
            _red,
            reason: 'strokeAlign: $align 的无圆角外框仍是方角',
          );
        }
        expect(_hits(tester, const Offset(-2, 30)), isFalse);
        expect(_hits(tester, const Offset(50, 30)), isTrue);
        expect(pixels.at(80, 60).a, 0);
      }
      final pixels = await _borderPixels(
        tester,
        ElStyle(
          width: 100,
          height: 60,
          border: Border.all(color: _red, width: 10, strokeAlign: 1),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
        ),
      );
      expect(pixels.at(138, 21), _red);
      expect(pixels.at(21, 21).a, 0);
    });

    testWidgets('非均匀多色边框组合椭圆圆角，过粗和超大圆角仍绘制有限形状', (tester) async {
      const border = Border(
        top: BorderSide(color: _red, width: 6),
        right: BorderSide(color: _green, width: 10),
        bottom: BorderSide(color: _blue, width: 14),
        left: BorderSide(color: _yellow, width: 18),
      );
      var pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          border: border,
          borderRadius: BorderRadius.all(Radius.elliptical(30, 20)),
        ),
      );
      expect(pixels.at(31, 31).a, 0);
      expect(pixels.at(80, 32), _red);
      expect(pixels.at(125, 60), _green);
      expect(pixels.at(80, 85), _blue);
      expect(pixels.at(35, 60), _yellow);
      expect(pixels.at(80, 60).a, 0);
      pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          border: Border(
            top: BorderSide(color: _red, width: 80),
            right: BorderSide(color: _green, width: 90),
            bottom: BorderSide(color: _blue, width: 70),
            left: BorderSide(color: _yellow, width: 60),
          ),
          borderRadius: BorderRadius.all(Radius.elliptical(200, 100)),
        ),
      );
      expect(pixels.at(80, 60).a, 1);
      expect(pixels.at(31, 31).a, 0);
      expect(pixels.at(10, 60).a, 0);
      expect(viewBox(tester).paintBounds.isFinite, isTrue);
      pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 100,
          border: Border(
            top: BorderSide(color: _red, width: 1),
            right: BorderSide(color: _green, width: 1),
            bottom: BorderSide(color: _blue, width: 1),
            left: BorderSide(color: _yellow, width: 80),
          ),
          borderRadius: BorderRadius.all(Radius.circular(40)),
        ),
      );
      final inner = RRect.fromLTRBAndCorners(
        80,
        1,
        99,
        99,
        topLeft: const Radius.elliptical(0, 39),
        topRight: const Radius.circular(39),
        bottomRight: const Radius.circular(39),
        bottomLeft: const Radius.elliptical(0, 39),
      ).scaleRadii();
      for (final point in [
        const Offset(81, 6),
        const Offset(81, 93),
        const Offset(90, 20),
        const Offset(90, 79),
        const Offset(84, 50),
      ]) {
        expect(inner.contains(point + const Offset(0.5, 0.5)), isTrue);
        expect(
          pixels.at(30 + point.dx.toInt(), 10 + point.dy.toInt()).a,
          0,
          reason: '极不均匀粗细仍保留规范内孔 $point',
        );
      }
      expect(pixels.at(109, 60), _yellow);
      expect(pixels.at(129, 60), _green);
      final outer = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(40),
      );
      expect(outer.contains(const Offset(90.5, 10.5)), isFalse);
      expect(pixels.at(120, 20).a, 0);
    });

    testWidgets('半透明多色圆角交界处不重叠加深，也不留下透明裂缝', (tester) async {
      const halfRed = Color(0x80ff0000);
      const halfBlue = Color(0x800000ff);
      const halfGreen = Color(0x8000ff00);
      const halfYellow = Color(0x80ffff00);
      final pixels = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          border: Border(
            top: BorderSide(color: halfRed, width: 10),
            right: BorderSide(color: halfBlue, width: 14),
            bottom: BorderSide(color: halfGreen, width: 8),
            left: BorderSide(color: halfYellow, width: 18),
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      );
      expect(pixels.at(80, 32), halfRed);
      expect(pixels.at(127, 60), halfBlue);
      expect(pixels.at(80, 87), halfGreen);
      expect(pixels.at(32, 60), halfYellow);
      var maximumAlpha = 0;
      for (var index = 3; index < pixels.bytes.lengthInBytes; index += 4) {
        final alpha = pixels.bytes.getUint8(index);
        if (alpha > maximumAlpha) maximumAlpha = alpha;
      }
      expect(maximumAlpha, closeTo(128, 1));
      for (var step = 7; step <= 11; step++) {
        expect(
          pixels.at(30 + step, 30 + step).a,
          greaterThanOrEqualTo(120 / 255),
          reason: '左上圆角交界像素 $step',
        );
      }
      final reference = await _borderPixels(
        tester,
        const ElStyle(
          width: 100,
          height: 60,
          border: Border.fromBorderSide(BorderSide(color: halfRed, width: 10)),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      );
      var partialSamples = 0;
      for (final (x, y) in [
        (0, 15),
        (1, 12),
        (2, 10),
        (3, 8),
        (4, 7),
        (5, 6),
        (6, 5),
        (7, 4),
        (8, 3),
        (10, 2),
        (12, 1),
        (15, 0),
      ]) {
        for (final (localX, localY) in [
          (x, y),
          (99 - x, y),
          (99 - x, 59 - y),
          (x, 59 - y),
        ]) {
          final actual = pixels.at(30 + localX, 30 + localY).a * 255;
          final expected = reference.at(30 + localX, 30 + localY).a * 255;
          if (expected > 0 && expected < 128) partialSamples++;
          expect(
            actual,
            closeTo(expected, 1),
            reason: '圆角外弧 ($localX, $localY) 与同几何单色边框抗锯齿一致',
          );
        }
      }
      expect(partialSamples, greaterThan(4));
    });

    testWidgets('边框在 child 之后绘制，所有 clipBehavior 保留外描边并裁剪 child', (
      tester,
    ) async {
      for (final clip in Clip.values) {
        final pixels = await _borderPixels(
          tester,
          ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _green,
            border: Border.all(color: _red, width: 12, strokeAlign: 0),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: clip,
          ),
          child: const RepaintBoundary(child: _overflow),
        );
        expect(pixels.at(80, 27), _red, reason: '$clip 外描边');
        expect(pixels.at(80, 33), _red, reason: '$clip 覆盖 child');
        expect(pixels.at(80, 60), _blue);
        expect(pixels.at(150, 60).a, clip == Clip.none ? 1 : 0);
        expect(_hits(tester, const Offset(50, 30)), isTrue);
        expect(
          _hits(tester, const Offset(1, 1)),
          clip == Clip.none,
          reason: '$clip 仅按视觉盒裁剪命中',
        );
      }
    });
  });

  group('最小与最大尺寸', () {
    testWidgets('四轴像素与百分比限制使用扣除 margin 的父可用尺寸', (tester) async {
      for (final (style, expected) in [
        (const ElStyle(minWidth: 120, minHeight: 90), const Size(120, 90)),
        (const ElStyle(maxWidth: 60, maxHeight: 30), const Size(60, 30)),
        (
          const ElStyle(
            minWidth: '50%',
            minHeight: '50%',
            margin: EdgeInsets.all(10),
          ),
          const Size(210, 160),
        ),
        (
          const ElStyle(
            maxWidth: '10%',
            maxHeight: '10%',
            margin: EdgeInsets.all(10),
          ),
          const Size(58, 48),
        ),
      ]) {
        await tester.pumpWidget(
          viewScene(style, child: const SizedBox(width: 80, height: 40)),
        );
        expect(viewSize(tester), expected);
      }
    });

    testWidgets('非法与非有限限制视为未声明，负值归零，数字字符串正常解析', (tester) async {
      for (final value in <Object?>[
        null,
        'invalid',
        'NaN%',
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              minWidth: value,
              maxWidth: value,
              minHeight: value,
              maxHeight: value,
            ),
            child: const SizedBox(width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), const Size(80, 40));
      }
      for (final value in <Object>[-20, '-10%']) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(minWidth: value, minHeight: value),
            child: const SizedBox(width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), const Size(80, 40));
        await tester.pumpWidget(
          viewScene(
            ElStyle(maxWidth: value, maxHeight: value),
            child: const SizedBox(width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), Size.zero);
      }
      await tester.pumpWidget(
        viewScene(
          const ElStyle(minWidth: '120', minHeight: '90'),
          child: const SizedBox(width: 80, height: 40),
        ),
      );
      expect(viewSize(tester), const Size(120, 90));
    });

    testWidgets('复制、合并和显式清空四个限制立即更新实际尺寸', (tester) async {
      const child = SizedBox(width: 80, height: 40);
      const style = ElStyle(
        minWidth: 120,
        maxWidth: 160,
        minHeight: 70,
        maxHeight: 90,
      );
      for (final (value, expected) in [
        (style, const Size(120, 70)),
        (style.copyWith(width: 300, height: 300), const Size(160, 90)),
        (
          style.merge(const ElStyle(minWidth: 140, minHeight: 80)),
          const Size(140, 80),
        ),
        (style.merge(const ElStyle()), const Size(120, 70)),
        (
          style.copyWith(
            minWidth: null,
            maxWidth: null,
            minHeight: null,
            maxHeight: null,
          ),
          const Size(80, 40),
        ),
      ]) {
        await tester.pumpWidget(viewScene(value, child: child));
        expect(viewSize(tester), expected);
      }
    });

    testWidgets('min 大于 max 时 max 胜出，父最小、最大和紧约束仍最终生效', (tester) async {
      const style = ElStyle(
        minWidth: 180,
        maxWidth: 100,
        minHeight: 120,
        maxHeight: 60,
      );
      Widget host(BoxConstraints constraints) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ConstrainedBox(
            constraints: constraints,
            child: const ElView(
              key: viewKey,
              style: style,
              child: SizedBox(width: 20, height: 10),
            ),
          ),
        ),
      );
      for (final (constraints, expected) in [
        (
          const BoxConstraints(maxWidth: 400, maxHeight: 300),
          const Size(100, 60),
        ),
        (
          const BoxConstraints(
            minWidth: 140,
            maxWidth: 160,
            minHeight: 90,
            maxHeight: 100,
          ),
          const Size(140, 90),
        ),
        (const BoxConstraints(maxWidth: 80, maxHeight: 50), const Size(80, 50)),
        (
          const BoxConstraints.tightFor(width: 200, height: 100),
          const Size(200, 100),
        ),
      ]) {
        await tester.pumpWidget(host(constraints));
        expect(viewSize(tester), expected);
      }
      await tester.pumpWidget(
        viewScene(
          style.copyWith(width: 40, height: 30),
          child: const SizedBox(width: 20, height: 10),
        ),
      );
      expect(viewSize(tester), const Size(100, 60));
    });

    testWidgets('auto 最小值只撑视觉盒，显式尺寸先限幅再给 child 松约束', (tester) async {
      const childKey = ValueKey('minmax-child');
      for (final (style, expected, childSize) in [
        (
          const ElStyle(minWidth: 180, minHeight: 100),
          const Size(180, 100),
          const Size(80, 40),
        ),
        (
          const ElStyle(width: 40, height: 30, minWidth: 120, minHeight: 80),
          const Size(120, 80),
          const Size(80, 40),
        ),
        (
          const ElStyle(width: 300, height: 200, maxWidth: 60, maxHeight: 30),
          const Size(60, 30),
          const Size(60, 30),
        ),
      ]) {
        await tester.pumpWidget(
          viewScene(
            style,
            child: const SizedBox(key: childKey, width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), expected);
        expect(tester.getSize(find.byKey(childKey)), childSize);
      }
    });

    testWidgets('限制包含 padding 不含 margin，边框与轮廓不占布局空间', (tester) async {
      const childKey = ValueKey('minmax-inset-child');
      const base = ElStyle(
        padding: EdgeInsets.fromLTRB(7, 5, 13, 9),
        margin: EdgeInsets.all(4),
        border: Border.fromBorderSide(BorderSide(width: 20, color: _red)),
        outline: ElOutline(width: 12, offset: 6),
      );
      for (final (style, expected, childSize) in [
        (
          base.copyWith(minWidth: 130, minHeight: 90),
          const Size(138, 98),
          const Size(80, 40),
        ),
        (
          base.copyWith(maxWidth: 70, maxHeight: 50),
          const Size(78, 58),
          const Size(50, 36),
        ),
      ]) {
        await tester.pumpWidget(
          viewScene(
            style,
            child: const SizedBox(key: childKey, width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), expected);
        expect(tester.getSize(find.byKey(childKey)), childSize);
        expect(
          tester.getTopLeft(find.byKey(childKey)) -
              tester.getTopLeft(find.byKey(viewKey)),
          const Offset(11, 9),
        );
      }
    });

    testWidgets('factor 乘自然盒后限幅，零倍数仍保留最小值且不会反向挤压 child', (tester) async {
      const childKey = ValueKey('minmax-factor-child');
      const base = ElStyle(
        minWidth: 70,
        maxWidth: 130,
        minHeight: 50,
        maxHeight: 90,
        padding: EdgeInsets.all(10),
      );
      for (final (factor, expected) in [
        (0.5, const Size(70, 50)),
        (2.0, const Size(130, 90)),
        (0.0, const Size(70, 50)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            base.copyWith(widthFactor: factor, heightFactor: factor),
            child: const SizedBox(key: childKey, width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), expected);
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      }
      await tester.pumpWidget(
        viewScene(base.copyWith(widthFactor: 2, heightFactor: 2)),
      );
      expect(viewSize(tester), const Size(70, 50));
      await tester.pumpWidget(
        viewScene(
          base.copyWith(
            width: 200,
            height: 200,
            widthFactor: 0,
            heightFactor: 0,
          ),
          child: const SizedBox(key: childKey, width: 80, height: 40),
        ),
      );
      expect(viewSize(tester), const Size(130, 90));
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
    });

    testWidgets('max 先约束内容，Wrap 换行和 AspectRatio 跨轴尺寸随之变化', (tester) async {
      const wrapKey = ValueKey('minmax-wrap');
      const wrap = Wrap(
        key: wrapKey,
        children: [
          SizedBox(width: 70, height: 20),
          SizedBox(width: 70, height: 20),
          SizedBox(width: 70, height: 20),
        ],
      );
      for (final (maxWidth, expected) in <(double?, Size)>[
        (null, const Size(230, 40)),
        (160, const Size(160, 60)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(maxWidth: maxWidth, padding: const EdgeInsets.all(10)),
            child: wrap,
          ),
        );
        expect(viewSize(tester), expected);
        expect(
          tester.getSize(find.byKey(wrapKey)),
          expected - const Offset(20, 20),
        );
      }
      for (final (style, expected) in [
        (
          const ElStyle(maxWidth: 160, padding: EdgeInsets.all(10)),
          const Size(160, 90),
        ),
        (
          const ElStyle(maxHeight: 50, padding: EdgeInsets.all(10)),
          const Size(80, 50),
        ),
      ]) {
        await tester.pumpWidget(
          viewScene(style, child: const AspectRatio(aspectRatio: 2)),
        );
        expect(viewSize(tester), expected);
      }
    });

    testWidgets('无界百分比无参照时不限制，确定祖先变化时 min 与 max 重新求值', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: UnconstrainedBox(
              child: ElView(
                key: viewKey,
                style: ElStyle(
                  minWidth: '50%',
                  maxWidth: '75%',
                  minHeight: '50%',
                  maxHeight: '75%',
                ),
                child: SizedBox(width: 80, height: 40),
              ),
            ),
          ),
        ),
      );
      expect(viewSize(tester), const Size(80, 40));
      Widget host(double height, double childHeight) => viewScene(
        ElStyle(width: 200, height: height, padding: const EdgeInsets.all(10)),
        key: const ValueKey('minmax-percent-parent'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElView(
              key: viewKey,
              style: const ElStyle(minHeight: '50%', maxHeight: '75%'),
              child: SizedBox(width: 40, height: childHeight),
            ),
          ],
        ),
      );
      for (final (height, childHeight, expected) in [
        (200.0, 20.0, 90.0),
        (300.0, 20.0, 140.0),
        (200.0, 1000.0, 135.0),
        (300.0, 1000.0, 210.0),
      ]) {
        await tester.pumpWidget(host(height, childHeight));
        expect(viewSize(tester), Size(40, expected));
      }
      expect(tester.takeException(), isNull);
    });

    for (final vertical in [false, true]) {
      testWidgets(
        '${vertical ? "IntrinsicHeight" : "IntrinsicWidth"} 使用限制后的含边距尺寸',
        (tester) async {
          const child = ElView(
            key: viewKey,
            style: ElStyle(
              minWidth: 120,
              maxWidth: 140,
              minHeight: 80,
              maxHeight: 100,
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.all(4),
            ),
            child: SizedBox(width: 80, height: 40),
          );
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: vertical
                    ? const IntrinsicHeight(child: child)
                    : const IntrinsicWidth(child: child),
              ),
            ),
          );
          expect(viewSize(tester), const Size(128, 88));
        },
      );
    }

    testWidgets('限制不改变文字基线，公开 dry 查询遵守新约束且不污染正式几何', (tester) async {
      const textKey = ValueKey('minmax-baseline-child');
      const referenceKey = ValueKey('minmax-baseline-reference');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ElView(
                    key: viewKey,
                    style: ElStyle(
                      minWidth: 120,
                      maxWidth: 160,
                      minHeight: 60,
                      maxHeight: 80,
                      padding: EdgeInsets.fromLTRB(8, 5, 12, 7),
                      margin: EdgeInsets.fromLTRB(3, 2, 5, 4),
                    ),
                    child: Text('aa', key: textKey),
                  ),
                  Text('aa', key: referenceKey),
                ],
              ),
            ),
          ),
        ),
      );
      final actualSize = viewSize(tester);
      final childPosition = tester.getTopLeft(find.byKey(textKey));
      expect(actualSize, const Size(128, 66));
      expect(childPosition.dy, tester.getTopLeft(find.byKey(referenceKey)).dy);
      final box = viewBox(tester);
      const query = BoxConstraints(maxWidth: 100, maxHeight: 50);
      expect(box.getDryLayout(query), const Size(100, 50));
      final childBaseline = tester
          .renderObject<RenderBox>(find.byKey(textKey))
          .getDryBaseline(
            const BoxConstraints(maxWidth: 72, maxHeight: 32),
            TextBaseline.alphabetic,
          )!;
      expect(
        box.getDryBaseline(query, TextBaseline.alphabetic),
        childBaseline + 7,
      );
      expect(viewSize(tester), actualSize);
      expect(tester.getTopLeft(find.byKey(textKey)), childPosition);
    });
  });

  group('基础盒模型与样式声明', () {
    testWidgets('空样式使用自然尺寸，复制、合并和显式清空后布局与背景正确', (tester) async {
      const child = SizedBox(width: 80, height: 40);
      const style = ElStyle(width: 120, height: 60, backgroundColor: _red);
      await tester.pumpWidget(viewScene(const ElStyle(), child: child));
      expect(viewSize(tester), const Size(80, 40));
      expect(viewBox(tester), paintsNothing);
      await tester.pumpWidget(viewScene(style, child: child));
      expect(viewSize(tester), const Size(120, 60));
      expect(_color(viewBox(tester)), _red);
      await tester.pumpWidget(
        viewScene(
          style.merge(const ElStyle(height: 90, backgroundColor: _blue)),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(120, 90));
      expect(_color(viewBox(tester)), _blue);
      await tester.pumpWidget(
        viewScene(
          style.copyWith(width: null, height: null, backgroundColor: null),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(80, 40));
      expect(viewBox(tester), paintsNothing);
      await tester.pumpWidget(viewScene(const ElStyle()));
      expect(viewSize(tester), Size.zero);
    });

    testWidgets('尺寸包含 padding，背景覆盖视觉盒，margin 只参与占位', (tester) async {
      const childKey = ValueKey('basic-child');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 120,
            height: 80,
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.all(5),
            backgroundColor: _red,
          ),
          child: const SizedBox(key: childKey, width: 20, height: 15),
        ),
      );
      expect(viewSize(tester), const Size(130, 90));
      expect(tester.getSize(find.byKey(childKey)), const Size(20, 15));
      expect(
        tester.getTopLeft(find.byKey(childKey)) -
            tester.getTopLeft(find.byKey(viewKey)),
        const Offset(15, 15),
      );
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(5, 5, 120, 80), color: _red),
      );
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      expect(_hits(tester, const Offset(6, 6)), isTrue);
    });

    testWidgets('方向性 padding 在 RTL 中影响自然尺寸与内容位置', (tester) async {
      const childKey = ValueKey('directional-child');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(padding: EdgeInsetsDirectional.fromSTEB(10, 2, 30, 4)),
          direction: TextDirection.rtl,
          child: const SizedBox(key: childKey, width: 20, height: 15),
        ),
      );
      expect(viewSize(tester), const Size(60, 21));
      expect(
        tester.getTopLeft(find.byKey(childKey)) -
            tester.getTopLeft(find.byKey(viewKey)),
        const Offset(30, 2),
      );
    });

    testWidgets('双轴 factor 乘包含 padding 的自然盒，margin、背景与 child 位置保持正确', (
      tester,
    ) async {
      const childKey = ValueKey('factored-child');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            widthFactor: 1.5,
            heightFactor: 2,
            padding: EdgeInsets.fromLTRB(5, 7, 15, 13),
            margin: EdgeInsets.fromLTRB(4, 3, 6, 9),
            backgroundColor: _red,
          ),
          child: const SizedBox(key: childKey, width: 80, height: 40),
        ),
      );
      expect(viewSize(tester), const Size(160, 132));
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      expect(
        tester.getTopLeft(find.byKey(childKey)) -
            tester.getTopLeft(find.byKey(viewKey)),
        const Offset(9, 10),
      );
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(4, 3, 150, 120), color: _red),
      );
    });

    testWidgets('单轴、零和大于一的 factor 只改变占位，不缩放或自动裁剪 child', (tester) async {
      const childKey = ValueKey('factor-overflow-child');
      for (final (widthFactor, heightFactor, size)
          in <(double?, double?, Size)>[
            (0.5, null, const Size(40, 40)),
            (null, 2, const Size(80, 80)),
            (0, 0, Size.zero),
            (2, 1.5, const Size(160, 60)),
          ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(widthFactor: widthFactor, heightFactor: heightFactor),
            child: const ColoredBox(
              key: childKey,
              color: _blue,
              child: SizedBox(width: 80, height: 40),
            ),
          ),
        );
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
        expect(
          viewBox(tester),
          paints..rect(rect: const Rect.fromLTWH(0, 0, 80, 40), color: _blue),
        );
        final methods = recordView(tester).map((call) => call.memberName);
        expect(methods, isNot(contains(#clipRect)));
        expect(methods, isNot(contains(#clipRRect)));
      }
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            widthFactor: 0.5,
            heightFactor: 0.5,
            clipBehavior: Clip.hardEdge,
          ),
          child: const ColoredBox(
            key: childKey,
            color: _blue,
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      expect(viewSize(tester), const Size(40, 20));
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      _clip(tester, Clip.hardEdge, rect: const Rect.fromLTWH(0, 0, 40, 20));
    });

    testWidgets('显式宽高优先于对应 factor，另一条 auto 轴仍使用 factor', (tester) async {
      const childKey = ValueKey('factor-explicit-child');
      for (final (style, size) in [
        (
          const ElStyle(width: 120, widthFactor: 0.5, heightFactor: 2),
          const Size(120, 80),
        ),
        (
          const ElStyle(height: 90, widthFactor: 0.5, heightFactor: 0),
          const Size(40, 90),
        ),
        (
          const ElStyle(
            width: 120,
            height: 90,
            widthFactor: 0,
            heightFactor: 0,
          ),
          const Size(120, 90),
        ),
      ]) {
        await tester.pumpWidget(
          viewScene(
            style,
            child: const SizedBox(key: childKey, width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      }
    });

    testWidgets('百分比有参照时忽略 factor，无参照时按自然盒应用 factor', (tester) async {
      const style = ElStyle(
        width: '50%',
        height: '25%',
        widthFactor: 2,
        heightFactor: 0.5,
        margin: EdgeInsets.all(10),
      );
      const child = SizedBox(width: 80, height: 40);
      await tester.pumpWidget(viewScene(style, child: child));
      expect(viewSize(tester), const Size(210, 90));
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: UnconstrainedBox(
              child: ElView(key: viewKey, style: style, child: child),
            ),
          ),
        ),
      );
      expect(viewSize(tester), const Size(180, 40));
    });

    testWidgets('父最小、最大和紧约束最终限制 factor，child 沿用原约束', (tester) async {
      const childKey = ValueKey('factor-parent-child');
      Widget host(BoxConstraints constraints, double factor) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ConstrainedBox(
            constraints: constraints,
            child: ElView(
              key: viewKey,
              style: ElStyle(widthFactor: factor, heightFactor: factor),
              child: const SizedBox(key: childKey, width: 80, height: 40),
            ),
          ),
        ),
      );
      const range = BoxConstraints(
        minWidth: 100,
        maxWidth: 160,
        minHeight: 60,
        maxHeight: 90,
      );
      for (final (factor, size) in [
        (0.5, const Size(100, 60)),
        (2.0, const Size(160, 90)),
      ]) {
        await tester.pumpWidget(host(range, factor));
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(100, 60));
      }
      for (final factor in [0.5, 2.0]) {
        await tester.pumpWidget(
          host(const BoxConstraints.tightFor(width: 100, height: 80), factor),
        );
        expect(viewSize(tester), const Size(100, 80));
        expect(tester.getSize(find.byKey(childKey)), const Size(100, 80));
      }
    });

    testWidgets('无 child 时 factor 作用于 padding，自然尺寸为零时仍为零', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            widthFactor: 2,
            heightFactor: 0.5,
            padding: EdgeInsets.fromLTRB(4, 5, 6, 7),
            margin: EdgeInsets.all(3),
          ),
        ),
      );
      expect(viewSize(tester), const Size(26, 12));
      await tester.pumpWidget(
        viewScene(const ElStyle(widthFactor: 2, heightFactor: 0.5)),
      );
      expect(viewSize(tester), Size.zero);
    });

    testWidgets('factor 复制、合并和显式清空后实际占位同步变化', (tester) async {
      final int widthFactor = 2, heightFactor = 3;
      final style = ElStyle(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
      );
      const child = SizedBox(width: 40, height: 20);
      await tester.pumpWidget(viewScene(style, child: child));
      expect(viewSize(tester), const Size(80, 60));
      await tester.pumpWidget(
        viewScene(
          const ElStyle().copyWith(widthFactor: 2, heightFactor: 3),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(80, 60));
      await tester.pumpWidget(
        viewScene(
          style.merge(const ElStyle(widthFactor: 0.5, heightFactor: 2)),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(20, 40));
      await tester.pumpWidget(
        viewScene(style.merge(const ElStyle()), child: child),
      );
      expect(viewSize(tester), const Size(80, 60));
      await tester.pumpWidget(
        viewScene(
          style.copyWith(widthFactor: null, heightFactor: null),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(40, 20));
    });

    testWidgets('父约束限制显式尺寸，auto 保留紧约束', (tester) async {
      const childKey = ValueKey('constrained-child');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 1000, height: 1000),
          child: const SizedBox(key: childKey, width: 20, height: 15),
        ),
      );
      expect(viewSize(tester), const Size(400, 300));
      expect(tester.getSize(find.byKey(childKey)), const Size(20, 15));
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 100,
              height: 80,
              child: ElView(
                key: viewKey,
                child: SizedBox(key: childKey, width: 20, height: 15),
              ),
            ),
          ),
        ),
      );
      expect(viewSize(tester), const Size(100, 80));
      expect(tester.getSize(find.byKey(childKey)), const Size(100, 80));
    });

    for (final horizontal in [true, false]) {
      testWidgets('${horizontal ? "宽度" : "高度"}的 auto、像素、百分比、零和无效声明符合父约束', (
        tester,
      ) async {
        for (final (value, width, height) in <(Object?, double, double)>[
          (null, 80, 40),
          ('invalid', 80, 40),
          (double.infinity, 80, 40),
          (-20, 0, 0),
          (0, 0, 0),
          ('-25%', 0, 0),
          (120, 120, 120),
          ('120', 120, 120),
          ('25%', 100, 75),
          (' 50% ', 200, 150),
          ('150%', 400, 300),
        ]) {
          await tester.pumpWidget(
            viewScene(
              ElStyle(
                width: horizontal ? value : 120,
                height: horizontal ? 60 : value,
              ),
              child: const SizedBox(width: 80, height: 40),
            ),
          );
          expect(
            viewSize(tester),
            horizontal ? Size(width, 60) : Size(120, height),
          );
        }
      });
    }

    testWidgets('百分比基于扣除 margin 的父约束，嵌套再使用扣除 padding 的内容区域', (tester) async {
      const nestedKey = ValueKey('nested-percent');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: '50%',
            height: '50%',
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.all(10),
          ),
          child: const ElView(
            key: nestedKey,
            style: ElStyle(width: '50%', height: '50%'),
          ),
        ),
      );
      expect(viewSize(tester), const Size(210, 160));
      expect(tester.getSize(find.byKey(nestedKey)), const Size(85, 60));
    });

    for (final vertical in [false, true]) {
      testWidgets(
        '${vertical ? "IntrinsicHeight" : "IntrinsicWidth"} 场景包含 factor 与内外边距',
        (tester) async {
          const child = ElView(
            key: viewKey,
            style: ElStyle(
              widthFactor: 1.5,
              heightFactor: 2,
              padding: EdgeInsets.all(4),
              margin: EdgeInsets.all(2),
            ),
            child: SizedBox(width: 32, height: 18),
          );
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: vertical
                    ? const IntrinsicHeight(child: child)
                    : const IntrinsicWidth(child: child),
              ),
            ),
          );
          expect(viewSize(tester), const Size(64, 56));
        },
      );
    }

    testWidgets('真实 Row 在 factor 改变占位后仍按 child 和内外边距对齐基线', (tester) async {
      const textKey = ValueKey('baseline-child');
      const referenceKey = ValueKey('baseline-reference');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ElView(
                    key: viewKey,
                    style: ElStyle(
                      widthFactor: 0.5,
                      heightFactor: 2,
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.all(3),
                    ),
                    child: Text('a', key: textKey),
                  ),
                  Text('a', key: referenceKey),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(textKey)).dy,
        tester.getTopLeft(find.byKey(referenceKey)).dy,
      );
      final child = tester.getSize(find.byKey(textKey));
      expect(
        viewSize(tester),
        Size((child.width + 16) * 0.5 + 6, (child.height + 16) * 2 + 6),
      );
    });

    testWidgets('背景声明为 null、透明、半透明和不透明时绘制结果正确', (tester) async {
      for (final color in <Color?>[
        null,
        const Color(0x000000ff),
        const Color(0x80ff0000),
        _blue,
      ]) {
        await tester.pumpWidget(
          viewScene(ElStyle(width: 40, height: 30, backgroundColor: color)),
        );
        expect(viewSize(tester), const Size(40, 30));
        if (color == null) {
          expect(viewBox(tester), paintsNothing);
        } else {
          expect(
            viewBox(tester),
            paints..rect(rect: const Rect.fromLTWH(0, 0, 40, 30), color: color),
          );
        }
      }
    });

    testWidgets('首次挂载即显示声明值，过渡配置不改变初始画面', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            borderRadius: BorderRadius.all(Radius.circular(12)),
            transitions: [ElTransition.all()],
          ),
        ),
      );
      expect(viewSize(tester), const Size(100, 60));
      _background(tester, BorderRadius.circular(12));
    });
  });

  group('祖先参照与重挂', () {
    testWidgets('无界 Column 中最近祖先在 auto 与确定尺寸间切换百分比参照', (tester) async {
      const middleKey = ValueKey('reference-middle');
      const percentKey = ValueKey('reference-percent');
      const descendant = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElView(
            key: percentKey,
            style: ElStyle(width: 10, height: '50%'),
          ),
        ],
      );
      Widget host(double? middleHeight) => viewScene(
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

    testWidgets('GlobalKey 重挂后百分比跟随新父尺寸，旧父变化不影响当前画面', (tester) async {
      final movedKey = GlobalKey();
      final moved = ElView(
        key: movedKey,
        style: const ElStyle(width: 10, height: '50%'),
        child: const SizedBox(width: 10, height: 1000),
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
                style: ElStyle(width: 160, height: leftHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [if (!right) moved],
                ),
              ),
              ElView(
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
      expect(tester.getSize(find.byKey(movedKey)).height, 100);
      final left = tester.getTopLeft(find.byKey(movedKey));
      await tester.pumpWidget(host(right: true));
      expect(tester.getSize(find.byKey(movedKey)).height, 150);
      final right = tester.getTopLeft(find.byKey(movedKey));
      expect(right - left, const Offset(160, 0));
      await tester.pumpWidget(host(right: true, leftHeight: 240));
      expect(tester.getSize(find.byKey(movedKey)).height, 150);
      expect(tester.getTopLeft(find.byKey(movedKey)), right);
      await tester.pumpWidget(
        host(right: true, leftHeight: 240, rightHeight: 360),
      );
      expect(tester.getSize(find.byKey(movedKey)).height, 180);
      expect(tester.takeException(), isNull);
    });
  });

  group('圆角的实际画面与命中', () {
    testWidgets('样式复制、合并和清空后实际背景同步变化', (tester) async {
      const base = ElStyle(width: 100, height: 60, backgroundColor: _red);
      final rounded = base.copyWith(borderRadius: BorderRadius.circular(12));
      await tester.pumpWidget(viewScene(rounded));
      _background(tester, BorderRadius.circular(12));
      await tester.pumpWidget(
        viewScene(
          base.merge(
            const ElStyle(
              backgroundColor: _blue,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
            ),
          ),
        ),
      );
      _background(
        tester,
        const BorderRadius.only(topLeft: Radius.circular(20)),
        color: _blue,
      );
      await tester.pumpWidget(viewScene(rounded.copyWith(borderRadius: null)));
      _background(tester, null);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
    });

    testWidgets('无背景时圆角不产生可见内容，零与退化圆角显示矩形', (tester) async {
      await tester.pumpWidget(
        viewScene(_radiusStyle(BorderRadius.circular(20), color: null)),
      );
      expect(viewBox(tester), paintsNothing);
      expect(_hits(tester, const Offset(50, 30)), isFalse);
      for (final radius in [
        BorderRadius.zero,
        const BorderRadius.all(Radius.elliptical(0, 12)),
        const BorderRadius.all(Radius.elliptical(12, 0)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: 100,
              height: 60,
              backgroundColor: _red,
              borderRadius: radius,
            ),
          ),
        );
        _background(tester, null);
        expect(_hits(tester, const Offset(1, 1)), isTrue);
      }
    });

    testWidgets('独立椭圆角、padding、margin 和 child 位置保持各自几何', (tester) async {
      const childKey = ValueKey('radius-child');
      const radius = BorderRadius.only(
        topLeft: Radius.elliptical(20, 30),
        topRight: Radius.circular(8),
        bottomLeft: Radius.elliptical(12, 7),
        bottomRight: Radius.circular(3),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            padding: EdgeInsets.all(5),
            margin: EdgeInsets.fromLTRB(3, 7, 11, 13),
            borderRadius: radius,
          ),
          child: const SizedBox(key: childKey, width: 30, height: 20),
        ),
      );
      expect(viewSize(tester), const Size(114, 80));
      _background(tester, radius, rect: const Rect.fromLTWH(3, 7, 100, 60));
      expect(
        tester.getTopLeft(find.byKey(childKey)) -
            viewBox(tester).localToGlobal(Offset.zero),
        const Offset(8, 12),
      );
      expect(tester.getSize(find.byKey(childKey)), const Size(30, 20));
      expect(_hits(tester, const Offset(4, 8)), isFalse);
      expect(_hits(tester, const Offset(50, 30)), isTrue);
      expect(_hits(tester, const Offset(1, 30)), isFalse);
    });

    testWidgets('物理、方向性和混合圆角在 LTR 与 RTL 中绘制正确', (tester) async {
      const physical = BorderRadius.only(topLeft: Radius.elliptical(3, 5));
      const directional = BorderRadiusDirectional.only(
        topStart: Radius.elliptical(14, 20),
        bottomEnd: Radius.elliptical(7, 11),
      );
      for (final radius in [physical, directional, physical.add(directional)]) {
        for (final direction in TextDirection.values) {
          await tester.pumpWidget(
            viewScene(
              ElStyle(
                width: 100,
                height: 60,
                backgroundColor: _red,
                margin: const EdgeInsets.fromLTRB(3, 5, 7, 11),
                borderRadius: radius,
              ),
              direction: direction,
            ),
          );
          _background(
            tester,
            radius.resolve(direction),
            rect: const Rect.fromLTWH(3, 5, 100, 60),
          );
          expect(viewSize(tester), const Size(110, 76));
        }
      }
    });

    testWidgets('超大椭圆角随显式尺寸和 auto 内容变化适配，命中与画面一致', (tester) async {
      const radius = BorderRadius.only(
        topLeft: Radius.elliptical(200, 100),
        topRight: Radius.elliptical(100, 70),
        bottomLeft: Radius.elliptical(30, 90),
        bottomRight: Radius.elliptical(80, 30),
      );
      for (final size in [const Size(100, 60), const Size(200, 100)]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: size.width,
              height: size.height,
              backgroundColor: _red,
              margin: const EdgeInsets.all(10),
              borderRadius: radius,
            ),
          ),
        );
        final rect = Rect.fromLTWH(10, 10, size.width, size.height);
        _background(tester, radius, rect: rect);
        final shape = radius.toRRect(rect).scaleRadii();
        for (final point in [
          const Offset(11, 11),
          rect.center,
          Offset(rect.right - 1, rect.bottom - 1),
          Offset(5, rect.center.dy),
        ]) {
          expect(_hits(tester, point), shape.contains(point), reason: '$point');
        }
      }
      for (final size in [const Size(40, 30), const Size(160, 70)]) {
        await tester.pumpWidget(
          viewScene(
            const ElStyle(backgroundColor: _red, borderRadius: radius),
            child: SizedBox(width: size.width, height: size.height),
          ),
        );
        expect(viewSize(tester), size);
        _background(tester, radius, rect: Offset.zero & size);
      }
    });

    testWidgets('只设置圆角时 child 仍可绘制和命中背景角落', (tester) async {
      await tester.pumpWidget(
        viewScene(
          _radiusStyle(BorderRadius.circular(30)),
          child: const OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 160,
            maxWidth: 160,
            minHeight: 100,
            maxHeight: 100,
            child: ColoredBox(color: _blue),
          ),
        ),
      );
      _background(tester, BorderRadius.circular(30));
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(0, 0, 160, 100), color: _blue),
      );
      expect(_hits(tester, const Offset(1, 1)), isTrue);
      expect(
        recordView(tester).map((call) => call.memberName),
        isNot(contains(#clipRRect)),
      );
    });
  });

  group('裁剪与内容布局', () {
    testWidgets('all 过渡下裁剪模式切换和清空仍立即生效', (tester) async {
      const transitions = [
        ElTransition.all(Duration(milliseconds: 100), Curves.linear),
      ];
      await tester.pumpWidget(
        viewScene(_clipStyle(transitions: transitions), child: _overflow),
      );
      for (final clip in [
        Clip.hardEdge,
        Clip.antiAlias,
        Clip.antiAliasWithSaveLayer,
        Clip.none,
        Clip.hardEdge,
        null,
      ]) {
        await tester.pumpWidget(
          viewScene(
            _clipStyle(clip: clip, transitions: transitions),
            child: _overflow,
          ),
        );
        _clip(tester, clip ?? Clip.none, radius: BorderRadius.circular(30));
        expect(
          _hits(tester, const Offset(1, 1)),
          clip == null || clip == Clip.none,
        );
        expect(viewSize(tester), const Size(100, 60));
      }
    });
    testWidgets('复制、合并和清空裁剪声明后用户命中与画面同步变化', (tester) async {
      final base = _clipStyle(clip: Clip.hardEdge);
      await tester.pumpWidget(viewScene(base, child: _overflow));
      _clip(tester, Clip.hardEdge, radius: BorderRadius.circular(30));
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      await tester.pumpWidget(
        viewScene(base.copyWith(clipBehavior: Clip.none), child: _overflow),
      );
      _clip(tester, Clip.none);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
      await tester.pumpWidget(
        viewScene(
          base.merge(const ElStyle(clipBehavior: Clip.antiAliasWithSaveLayer)),
          child: _overflow,
        ),
      );
      _clip(
        tester,
        Clip.antiAliasWithSaveLayer,
        radius: BorderRadius.circular(30),
      );
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      await tester.pumpWidget(
        viewScene(base.copyWith(clipBehavior: null), child: _overflow),
      );
      _clip(tester, Clip.none);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
    });

    testWidgets('默认和显式 none 允许 child 绘制溢出并命中背景角落', (tester) async {
      for (final clip in [null, Clip.none]) {
        await tester.pumpWidget(
          viewScene(_clipStyle(clip: clip), child: _overflow),
        );
        _clip(tester, Clip.none);
        expect(
          viewBox(tester),
          paints..rect(rect: const Rect.fromLTWH(0, 0, 160, 100), color: _blue),
        );
        expect(_hits(tester, const Offset(1, 1)), isTrue);
        expect(tester.getSize(find.byKey(_overflowKey)), const Size(160, 100));
      }
    });

    for (final clip in [
      Clip.hardEdge,
      Clip.antiAlias,
      Clip.antiAliasWithSaveLayer,
    ]) {
      testWidgets('$clip 将背景和溢出 child 裁剪到不含 margin 的矩形', (tester) async {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: 100,
              height: 60,
              backgroundColor: _red,
              margin: const EdgeInsets.fromLTRB(7, 11, 13, 17),
              padding: const EdgeInsets.all(4),
              clipBehavior: clip,
            ),
            child: _overflow,
          ),
        );
        _clip(
          tester,
          clip,
          rect: const Rect.fromLTWH(7, 11, 100, 60),
          offset: const Offset(23, 31),
        );
        expect(viewSize(tester), const Size(120, 88));
        expect(
          tester.getTopLeft(find.byKey(_overflowKey)) -
              viewBox(tester).localToGlobal(Offset.zero),
          const Offset(11, 15),
        );
        final calls = recordView(tester);
        expect(
          calls.map((call) => call.memberName),
          containsAllInOrder([#clipRect, #drawRect, #drawRect, #restore]),
        );
        expect(
          viewBox(tester),
          paints..rect(rect: const Rect.fromLTWH(7, 11, 100, 60), color: _red),
        );
        expect(_hits(tester, const Offset(1, 30)), isFalse);
        expect(_hits(tester, const Offset(50, 30)), isTrue);
      });

      testWidgets('$clip 按超大椭圆角的最终形状裁剪并限制用户命中', (tester) async {
        const radius = BorderRadius.only(
          topLeft: Radius.elliptical(200, 100),
          topRight: Radius.elliptical(100, 70),
          bottomLeft: Radius.elliptical(30, 90),
          bottomRight: Radius.elliptical(80, 30),
        );
        await tester.pumpWidget(
          viewScene(
            _clipStyle(clip: clip, radius: radius),
            child: _overflow,
          ),
        );
        _clip(tester, clip, radius: radius);
        final shape = radius
            .toRRect(const Rect.fromLTWH(0, 0, 100, 60))
            .scaleRadii();
        for (final point in [
          const Offset(1, 1),
          const Offset(50, 30),
          const Offset(99, 59),
        ]) {
          expect(_hits(tester, point), shape.contains(point), reason: '$point');
        }
        expect(
          recordView(tester).map((call) => call.memberName),
          containsAllInOrder([#clipRRect, #drawRect, #drawRect, #restore]),
        );
      });
    }

    testWidgets('无背景时仍裁剪溢出 child，圆角外和 margin 内不响应命中', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            margin: EdgeInsets.all(10),
            borderRadius: BorderRadius.all(Radius.circular(30)),
            clipBehavior: Clip.hardEdge,
          ),
          child: _overflow,
        ),
      );
      _clip(
        tester,
        Clip.hardEdge,
        radius: BorderRadius.circular(30),
        rect: const Rect.fromLTWH(10, 10, 100, 60),
      );
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(10, 10, 160, 100), color: _blue),
      );
      expect(_hits(tester, const Offset(11, 11)), isFalse);
      expect(_hits(tester, const Offset(5, 40)), isFalse);
      expect(_hits(tester, const Offset(60, 40)), isTrue);
    });

    testWidgets('auto 内容尺寸变化后裁剪适配实际占位', (tester) async {
      const radius = BorderRadius.all(Radius.elliptical(120, 80));
      for (final size in [const Size(40, 30), const Size(160, 70)]) {
        await tester.pumpWidget(
          viewScene(
            const ElStyle(
              backgroundColor: _red,
              borderRadius: radius,
              clipBehavior: Clip.hardEdge,
            ),
            child: SizedBox(width: size.width, height: size.height),
          ),
        );
        expect(viewSize(tester), size);
        _clip(tester, Clip.hardEdge, radius: radius, rect: Offset.zero & size);
        expect(_hits(tester, size.center(Offset.zero)), isTrue);
        expect(_hits(tester, const Offset(1, 1)), isFalse);
      }
    });

    testWidgets('父约束与百分比嵌套尺寸变化后两级裁剪和 child 位置同步', (tester) async {
      const nestedKey = ValueKey('clip-percent-child');
      const style = ElStyle(
        width: '50%',
        height: '50%',
        backgroundColor: _red,
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.all(8),
        borderRadius: BorderRadius.all(Radius.circular(30)),
        clipBehavior: Clip.hardEdge,
      );
      const child = ElView(
        key: nestedKey,
        style: ElStyle(
          width: '50%',
          height: '50%',
          backgroundColor: _blue,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
        ),
      );
      for (final (width, height, outer, inner) in [
        (400.0, 300.0, const Size(192, 142), const Size(86, 61)),
        (600.0, 400.0, const Size(292, 192), const Size(136, 86)),
      ]) {
        await tester.pumpWidget(
          viewScene(style, child: child, width: width, height: height),
        );
        expect(viewSize(tester), Size(outer.width + 16, outer.height + 16));
        expect(viewSize(tester, key: nestedKey), inner);
        expect(
          viewBox(tester, key: nestedKey).localToGlobal(Offset.zero) -
              viewBox(tester).localToGlobal(Offset.zero),
          const Offset(18, 18),
        );
        _clip(
          tester,
          Clip.hardEdge,
          radius: BorderRadius.circular(30),
          rect: Rect.fromLTWH(8, 8, outer.width, outer.height),
        );
        _clip(
          tester,
          Clip.antiAlias,
          radius: BorderRadius.circular(20),
          rect: Offset.zero & inner,
          key: nestedKey,
        );
        expect(_hits(tester, const Offset(1, 1), key: nestedKey), isFalse);
        expect(
          _hits(tester, inner.center(Offset.zero), key: nestedKey),
          isTrue,
        );
      }
    });

    testWidgets('带 RepaintBoundary 的真实子树在启用、切换、移除和重挂后正常绘制命中', (tester) async {
      const child = RepaintBoundary(child: _overflow);
      for (final (clip, radius) in [
        (Clip.antiAliasWithSaveLayer, BorderRadius.circular(30)),
        (Clip.hardEdge, BorderRadius.circular(12)),
        (Clip.antiAlias, null),
        (Clip.none, BorderRadius.circular(30)),
        (Clip.antiAliasWithSaveLayer, BorderRadius.circular(30)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            _clipStyle(clip: clip, radius: radius),
            child: child,
          ),
        );
        _clip(tester, clip, radius: radius);
        expect(
          _hits(tester, const Offset(1, 1)),
          clip == Clip.none || radius == null,
        );
        expect(_hits(tester, const Offset(50, 30)), isTrue);
        final childPaint = _calls(recordView(tester), #drawRect).firstWhere(
          (call) => (call.positionalArguments[1] as Paint).color == _blue,
        );
        expect(
          childPaint.positionalArguments.first,
          const Rect.fromLTWH(0, 0, 160, 100),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        viewScene(_clipStyle(clip: Clip.hardEdge), child: child),
      );
      _clip(tester, Clip.hardEdge, radius: BorderRadius.circular(30));
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      expect(_hits(tester, const Offset(50, 30)), isTrue);
    });
  });
}
