import 'package:flutter_base/src/flutter/views/view/event/dispatcher.dart' show EventDispatcher;
import 'dart:math' as math;

import 'package:flutter_base/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

const _contentKey = ValueKey<String>('zoom-transform-contract-content');

void main() {
  setUp(EventDispatcher.debugResetEagerGestureOwners);

  test('ElZoomTransform 提供稳定的 identity、值相等、hashCode 与 copyWith', () {
    const identity = ElZoomTransform();
    expect(identity.scale, 1);
    expect(identity.rotation, 0);
    expect(identity.offset, Offset.zero);

    const value = ElZoomTransform(scale: 2, rotation: 0.25, offset: Offset(12, -8));
    const equalValue = ElZoomTransform(scale: 2, rotation: 0.25, offset: Offset(12, -8));
    expect(value, equalValue);
    expect(value.hashCode, equalValue.hashCode);
    final values = <ElZoomTransform>{value}..add(equalValue);
    expect(values, hasLength(1));
    expect(value.copyWith(), value);
    expect(
      value.copyWith(scale: 3, rotation: -0.5, offset: const Offset(-4, 6)),
      const ElZoomTransform(scale: 3, rotation: -0.5, offset: Offset(-4, 6)),
    );
  });

  test('ElZoomTransform 拒绝非法 scale/rotation，controller 拒绝非 finite offset', () {
    final invalidValue = anyOf(isA<AssertionError>(), isA<ArgumentError>());
    final constructors = <ElZoomTransform Function()>[
      () => ElZoomTransform(scale: 0),
      () => ElZoomTransform(scale: -1),
      () => ElZoomTransform(scale: double.nan),
      () => ElZoomTransform(scale: double.infinity),
      () => ElZoomTransform(rotation: double.nan),
      () => ElZoomTransform(rotation: double.infinity),
    ];

    for (final constructor in constructors) {
      expect(constructor, throwsA(invalidValue));
    }

    final controller = ElZoomController();
    addTearDown(controller.dispose);
    expect(() => controller.jumpTo(ElZoomTransform(offset: Offset(double.nan, 0))), throwsArgumentError);
    expect(
      () => ElZoomController(initialValue: ElZoomTransform(offset: Offset(0, double.infinity))),
      throwsArgumentError,
    );
  });

  test('未挂载 controller 的 value、jump、animate 与 reset 都立即落值', () async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    expect(controller.value, const ElZoomTransform());

    const jumped = ElZoomTransform(scale: 2, rotation: 0.2, offset: Offset(10, 20));
    controller.jumpTo(jumped);
    expect(controller.value, jumped);

    const assigned = ElZoomTransform(scale: 1.5, rotation: -0.3, offset: Offset(-5, 8));
    controller.value = assigned;
    expect(controller.value, assigned);

    const animated = ElZoomTransform(scale: 3, rotation: 0.6, offset: Offset(30, -12));
    await controller.animateTo(animated, duration: const Duration(hours: 1)).timeout(const Duration(seconds: 1));
    expect(controller.value, animated);

    await controller.reset().timeout(const Duration(seconds: 1));
    expect(controller.value, const ElZoomTransform());
  });

  testWidgets('controller 首挂按 min/max 钳制，jump 同步更新真实 paint matrix', (tester) async {
    final belowMin = ElZoomController(initialValue: const ElZoomTransform(scale: 0.5));
    final aboveMax = ElZoomController(initialValue: const ElZoomTransform(scale: 8));
    addTearDown(belowMin.dispose);
    addTearDown(aboveMax.dispose);

    for (final entry in [(controller: belowMin, scale: 2.0), (controller: aboveMax, scale: 3.0)]) {
      await tester.pumpWidget(
        _zoomShell(
          controller: entry.controller,
          minScale: 2,
          maxScale: 3,
          child: const SizedBox(key: _contentKey),
        ),
      );
      expect(entry.controller.value.scale, entry.scale);
      expect(_matrixOf(tester).storage[0], closeTo(entry.scale, 1e-9));
      await tester.pumpWidget(const SizedBox.shrink());
    }

    await tester.pumpWidget(
      _zoomShell(
        controller: belowMin,
        minScale: 2,
        maxScale: 3,
        child: const SizedBox(key: _contentKey),
      ),
    );
    belowMin.jumpTo(const ElZoomTransform(scale: 9));
    await tester.pump();
    expect(belowMin.value.scale, 3);
    expect(_matrixOf(tester).storage[0], closeTo(3, 1e-9));

    const target = ElZoomTransform(scale: 2.5, offset: Offset(20, -10));
    belowMin.jumpTo(target);
    await tester.pump();
    final matrix = _matrixOf(tester);
    expect(belowMin.value, target);
    _expectOffset(MatrixUtils.transformPoint(matrix, const Offset(100, 100)), const Offset(120, 90));
  });

  testWidgets('同一 ElZoomController 不允许绑定第二个 live host', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: ElZoomView(controller: controller, child: const SizedBox.expand()),
              ),
              Expanded(
                child: ElZoomView(controller: controller, child: const SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('ElZoomController'));
  });

  testWidgets('constrained=false 使用 child 实际尺寸并按 alignment 生成 identity 几何', (tester) async {
    await tester.pumpWidget(
      _zoomShell(
        viewport: const Size(300, 200),
        constrained: false,
        alignment: Alignment.bottomRight,
        child: const SizedBox(key: _contentKey, width: 80, height: 40),
      ),
    );

    final content = tester.renderObject<RenderBox>(find.byKey(_contentKey));
    expect(content.size, const Size(80, 40));
    final matrix = _matrixOf(tester);
    expect(matrix.storage[0], closeTo(1, 1e-9));
    expect(matrix.storage[5], closeTo(1, 1e-9));
    _expectOffset(MatrixUtils.transformPoint(matrix, Offset.zero), const Offset(220, 160));
    _expectOffset(MatrixUtils.transformPoint(matrix, const Offset(80, 40)), const Offset(300, 200));

    await tester.pumpWidget(
      _zoomShell(
        viewport: const Size(300, 200),
        constrained: false,
        alignment: Alignment.bottomRight,
        child: const SizedBox(key: _contentKey, width: 500, height: 400),
      ),
    );
    final oversized = tester.renderObject<RenderBox>(find.byKey(_contentKey));
    expect(oversized.size, const Size(500, 400), reason: '非 constrained child 不得被 viewport 上限截断');
    final oversizedMatrix = _matrixOf(tester);
    _expectOffset(MatrixUtils.transformPoint(oversizedMatrix, Offset.zero), const Offset(-200, -200));
    _expectOffset(MatrixUtils.transformPoint(oversizedMatrix, const Offset(500, 400)), const Offset(300, 200));
  });

  testWidgets('alignment 热更新即时重新 clamp 并回写 controller', (tester) async {
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 2));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _zoomShell(
        viewport: const Size(300, 200),
        controller: controller,
        constrained: false,
        alignment: Alignment.centerLeft,
        child: const SizedBox(key: _contentKey, width: 80, height: 40),
      ),
    );
    expect(controller.value.offset.dx, closeTo(40, 1e-6));

    await tester.pumpWidget(
      _zoomShell(
        viewport: const Size(300, 200),
        controller: controller,
        constrained: false,
        alignment: Alignment.centerRight,
        child: const SizedBox(key: _contentKey, width: 80, height: 40),
      ),
    );
    expect(controller.value.offset.dx, closeTo(-40, 1e-6));
    final matrix = _matrixOf(tester);
    _expectOffset(MatrixUtils.transformPoint(matrix, Offset.zero), const Offset(140, 60));
    _expectOffset(MatrixUtils.transformPoint(matrix, const Offset(80, 40)), const Offset(300, 140));
  });

  testWidgets('viewport 尺寸变化保持旧矩阵中心对应的内容点', (tester) async {
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 2, offset: Offset(20, -10)));
    addTearDown(controller.dispose);
    Widget zoom(Size viewport) => _zoomShell(
      viewport: viewport,
      controller: controller,
      constrained: false,
      alignment: Alignment.topLeft,
      child: const SizedBox(key: _contentKey, width: 300, height: 250),
    );
    await tester.pumpWidget(zoom(const Size(300, 200)));
    final inverse = Matrix4.copy(_matrixOf(tester))..invert();
    final anchoredContentPoint = MatrixUtils.transformPoint(inverse, const Offset(150, 100));

    await tester.pumpWidget(zoom(const Size(400, 300)));
    _expectOffset(MatrixUtils.transformPoint(_matrixOf(tester), anchoredContentPoint), const Offset(200, 150));
  });

  testWidgets('触摸旋转围绕 focal，paint matrix 与 hit test 使用同一变换', (tester) async {
    Offset? hitLocalPosition;
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 2));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _zoomShell(
        viewport: const Size.square(300),
        controller: controller,
        enableRotation: true,
        panInertia: false,
        child: _HitProbe(key: _contentKey, onPointerDown: (position) => hitLocalPosition = position),
      ),
    );

    final first = await tester.createGesture();
    final second = await tester.createGesture();
    await first.down(const Offset(60, 150));
    await second.down(const Offset(160, 150));
    // 先越过 scale/rotation slop；该帧只建立手势基线。
    await second.moveTo(const Offset(200, 150));
    await tester.pump();

    const focal = Offset(130, 150);
    final startMatrix = _matrixOf(tester);
    final inverseStart = Matrix4.copy(startMatrix)..invert();
    final anchoredContentPoint = MatrixUtils.transformPoint(inverseStart, focal);

    // 保持 focal 与跨度不变，将两指从水平旋转到竖直。
    await first.moveTo(const Offset(130, 80));
    await second.moveTo(const Offset(130, 220));
    await tester.pump();

    final rotatedMatrix = _matrixOf(tester);
    expect(controller.value.rotation, closeTo(math.pi / 2, 1e-6));
    expect(math.atan2(rotatedMatrix.storage[1], rotatedMatrix.storage[0]), closeTo(math.pi / 2, 1e-6));
    _expectOffset(MatrixUtils.transformPoint(rotatedMatrix, anchoredContentPoint), focal);

    const testedChildPoint = Offset(170, 150);
    final visualPoint = MatrixUtils.transformPoint(rotatedMatrix, testedChildPoint);
    expect((Offset.zero & const Size.square(300)).contains(visualPoint), isTrue);
    await first.up();
    await second.up();
    hitLocalPosition = null;

    final host = tester.renderObject<RenderBox>(find.byType(ElZoomView));
    await tester.tapAt(host.localToGlobal(visualPoint));
    expect(hitLocalPosition, isNotNull);
    _expectOffset(hitLocalPosition!, testedChildPoint);
  });

  testWidgets('enablePan=false 禁止 2→1 平移与松手惯性', (tester) async {
    final controller = ElZoomController(initialValue: const ElZoomTransform(scale: 2));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _zoomShell(
        viewport: const Size.square(300),
        controller: controller,
        enablePan: false,
        child: const SizedBox(key: _contentKey),
      ),
    );

    final first = await tester.createGesture();
    final second = await tester.createGesture();
    await first.down(const Offset(80, 150));
    await second.down(const Offset(220, 150));
    await second.moveTo(const Offset(260, 150));
    await tester.pump();
    await second.moveTo(const Offset(280, 150));
    await tester.pump();
    await second.up();
    await tester.pump();
    final beforeSingleMove = controller.value.offset;

    await first.moveBy(const Offset(60, 0));
    await tester.pump();
    _expectOffset(controller.value.offset, beforeSingleMove);
    await first.up();
    await tester.pump(const Duration(milliseconds: 500));
    _expectOffset(controller.value.offset, beforeSingleMove);
  });

  testWidgets('controller 动画帧不重建或重排 child', (tester) async {
    final counters = _ChildCounters();
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _zoomShell(
        controller: controller,
        child: _CountingChild(counters: counters),
      ),
    );
    final builds = counters.builds;
    final layouts = counters.layouts;
    final paints = counters.paints;

    final animation = controller.animateTo(
      const ElZoomTransform(scale: 2),
      duration: const Duration(milliseconds: 120),
      curve: Curves.linear,
    );
    await tester.pump();
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await animation;

    expect(counters.builds, builds);
    expect(counters.layouts, layouts);
    expect(counters.paints, paints);
    expect(controller.value.scale, closeTo(2, 1e-9));
  });

  testWidgets('新命令与宿主卸载都会完成被打断的 controller Future', (tester) async {
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _zoomShell(
        controller: controller,
        child: const SizedBox(key: _contentKey),
      ),
    );

    final interrupted = controller.animateTo(const ElZoomTransform(scale: 3), duration: const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    controller.jumpTo(const ElZoomTransform(scale: 1.5));
    await interrupted.timeout(const Duration(seconds: 1));
    expect(controller.value.scale, 1.5);

    final disposedHost = controller.animateTo(const ElZoomTransform(scale: 2.5), duration: const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(const SizedBox.shrink());
    await disposedHost.timeout(const Duration(seconds: 1));
  });

  testWidgets('reduced motion 下 controller 直接落最终变换且不留下动画帧', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final controller = ElZoomController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _zoomShell(
        controller: controller,
        child: const SizedBox(key: _contentKey),
      ),
    );

    await controller.animateTo(const ElZoomTransform(scale: 2), duration: const Duration(hours: 1));
    expect(controller.value.scale, 2);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('替换 controller 会终止旧动画，旧 Future 完成且不再覆盖新值', (tester) async {
    final first = ElZoomController();
    final second = ElZoomController(initialValue: const ElZoomTransform(scale: 1.5));
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      _zoomShell(
        controller: first,
        child: const SizedBox(key: _contentKey),
      ),
    );

    final interrupted = first.animateTo(const ElZoomTransform(scale: 3), duration: const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(
      _zoomShell(
        controller: second,
        child: const SizedBox(key: _contentKey),
      ),
    );
    await interrupted.timeout(const Duration(seconds: 1));
    final detachedValue = first.value;
    expect(second.value.scale, 1.5);

    await tester.pump(const Duration(seconds: 1));
    expect(first.value, detachedValue);
    expect(second.value.scale, 1.5);
  });
}

Widget _zoomShell({
  required Widget child,
  ElZoomController? controller,
  Size viewport = const Size.square(200),
  double minScale = 1,
  double maxScale = 4,
  bool constrained = true,
  Alignment alignment = Alignment.center,
  bool enablePan = true,
  bool enableRotation = false,
  bool panInertia = true,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: viewport,
        child: ElZoomView(
          controller: controller,
          minScale: minScale,
          maxScale: maxScale,
          constrained: constrained,
          alignment: alignment,
          enablePan: enablePan,
          enableRotation: enableRotation,
          panInertia: panInertia,
          enableDoubleTapZoom: false,
          child: child,
        ),
      ),
    ),
  );
}

Matrix4 _matrixOf(WidgetTester tester) {
  final content = tester.renderObject<RenderBox>(find.byKey(_contentKey));
  final host = tester.renderObject<RenderBox>(find.byType(ElZoomView));
  return content.getTransformTo(host);
}

void _expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-6));
  expect(actual.dy, closeTo(expected.dy, 1e-6));
}

class _HitProbe extends LeafRenderObjectWidget {
  const _HitProbe({super.key, required this.onPointerDown});

  final ValueChanged<Offset> onPointerDown;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitProbe(onPointerDown);

  @override
  void updateRenderObject(BuildContext context, _RenderHitProbe renderObject) {
    renderObject.onPointerDown = onPointerDown;
  }
}

class _RenderHitProbe extends RenderBox {
  _RenderHitProbe(this.onPointerDown);

  ValueChanged<Offset> onPointerDown;

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) onPointerDown(event.localPosition);
  }
}

class _ChildCounters {
  int builds = 0;
  int layouts = 0;
  int paints = 0;
}

class _CountingChild extends StatelessWidget {
  const _CountingChild({required this.counters});

  final _ChildCounters counters;

  @override
  Widget build(BuildContext context) {
    counters.builds++;
    return _CountingLeaf(counters: counters);
  }
}

class _CountingLeaf extends LeafRenderObjectWidget {
  const _CountingLeaf({required this.counters});

  final _ChildCounters counters;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCountingLeaf(counters);

  @override
  void updateRenderObject(BuildContext context, _RenderCountingLeaf renderObject) {
    renderObject.counters = counters;
  }
}

class _RenderCountingLeaf extends RenderBox {
  _RenderCountingLeaf(this.counters);

  _ChildCounters counters;

  @override
  void performLayout() {
    counters.layouts++;
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    counters.paints++;
  }
}
