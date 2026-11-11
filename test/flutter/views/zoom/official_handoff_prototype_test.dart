// 原型验证：缩放视图只用官方手势识别器，贴边余量经祖先 ScrollPosition.drag 交给翻页。
//
// 目标是确认移除 ElView 拖动 / 缩放手势后，「已缩放图片平移到边缘 → 同一手势继续翻页 →
// 反向先收回翻页再平移图片」能否连续完成。翻页容器用官方 PageView，代表 ElScroll 去掉事件层
// 桥接后的形态（同样由官方 Scrollable 识别器驱动）。
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 已缩放时与拖动识别器同阈值抢先接受，未缩放的单指交给祖先滚动。
class _ZoomRecognizer extends ScaleGestureRecognizer {
  _ZoomRecognizer(this.zoomed);

  final bool Function() zoomed;
  final _downs = <int, Offset>{};
  bool _accepted = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _downs[event.pointer] = event.position;
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (!_accepted && event is PointerMoveEvent && zoomed()) {
      final down = _downs[event.pointer];
      if (down != null && (event.position - down).distance > computeHitSlop(event.kind, gestureSettings)) {
        resolve(GestureDisposition.accepted);
      }
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) _downs.remove(event.pointer);
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    super.acceptGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _accepted = false;
    _downs.clear();
    super.didStopTrackingLastPointer(pointer);
  }
}

class _ProtoZoom extends StatefulWidget {
  _ProtoZoom({super.key, required this.child, this.initialScale = 1, this.initialOffset = Offset.zero});

  final Widget child;
  final double initialScale;
  final Offset initialOffset;

  @override
  State<_ProtoZoom> createState() => _ProtoZoomState();
}

class _ProtoZoomState extends State<_ProtoZoom> {
  late double scale = widget.initialScale;
  late Offset offset = widget.initialOffset;
  late final _ZoomRecognizer _recognizer = _ZoomRecognizer(() => scale > 1 + precisionErrorTolerance)
    ..onStart = _start
    ..onUpdate = _update
    ..onEnd = _end;

  Size _size = Size.zero;
  double _startScale = 1;
  ScrollPosition? _ancestor;
  // 本页在祖先滚动坐标中的起点，手势开始时由布局换算一次，之后只读实时 pixels。
  double _pageStart = 0;
  Drag? _drag;
  Offset _lastGlobal = Offset.zero;

  @override
  void dispose() {
    _drag?.cancel();
    _recognizer.dispose();
    super.dispose();
  }

  Offset _clamp(Offset value, double s) {
    final minX = math.min(0.0, _size.width * (1 - s));
    final minY = math.min(0.0, _size.height * (1 - s));
    return Offset(value.dx.clamp(minX, 0.0), value.dy.clamp(minY, 0.0));
  }

  void _start(ScaleStartDetails details) {
    _startScale = scale;
    _lastGlobal = details.focalPoint;
    final scrollable = Scrollable.maybeOf(context, axis: Axis.horizontal);
    _ancestor = scrollable?.position;
    final box = context.findRenderObject() as RenderBox?;
    final viewport = scrollable?.context.findRenderObject() as RenderBox?;
    if (_ancestor != null && box != null && viewport != null) {
      _pageStart = _ancestor!.pixels + box.localToGlobal(Offset.zero, ancestor: viewport).dx;
    }
  }

  void _update(ScaleUpdateDetails details) {
    _lastGlobal = details.focalPoint;
    if (details.pointerCount >= 2) {
      _releaseDrag(0);
      final next = (_startScale * details.scale).clamp(1.0, 4.0);
      final content = (details.localFocalPoint - offset) / scale;
      setState(() {
        offset = _clamp(details.localFocalPoint - content * next + details.focalPointDelta, next);
        scale = next;
      });
      return;
    }
    final delta = details.focalPointDelta;
    setState(() => offset = _clamp(Offset(offset.dx, offset.dy + delta.dy), scale));
    _panHorizontal(delta.dx);
  }

  void _panHorizontal(double dx) {
    var rest = dx;
    if (rest == 0) return;
    final ancestor = _ancestor;
    // 翻页已经偏离本页时，反向位移先把翻页收回到本页边界。
    if (ancestor != null && _drag != null) {
      final displacement = _pageStart - ancestor.pixels;
      if (displacement.abs() > precisionErrorTolerance && rest.sign == -displacement.sign) {
        final closing = rest.sign * math.min(rest.abs(), displacement.abs());
        _feed(closing);
        rest -= closing;
      }
    }
    if (rest.abs() <= precisionErrorTolerance) return;
    final before = offset.dx;
    final next = _clamp(Offset(before + rest, offset.dy), scale);
    setState(() => offset = next);
    rest -= next.dx - before;
    if (rest.abs() > precisionErrorTolerance) _feed(rest);
  }

  void _feed(double delta) {
    final ancestor = _ancestor;
    if (ancestor == null) return;
    _drag ??= ancestor.drag(DragStartDetails(globalPosition: _lastGlobal), () => _drag = null);
    _drag?.update(DragUpdateDetails(globalPosition: _lastGlobal, delta: Offset(delta, 0), primaryDelta: delta));
  }

  void _releaseDrag(double velocity) {
    final drag = _drag;
    if (drag == null) return;
    _drag = null;
    drag.end(
      DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(velocity, 0)),
        primaryVelocity: velocity,
      ),
    );
  }

  void _end(ScaleEndDetails details) => _releaseDrag(details.velocity.pixelsPerSecond.dx);

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _recognizer.addPointer,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          return ClipRect(
            child: Transform(
              transform: Matrix4.translationValues(offset.dx, offset.dy, 0)
                ..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

const _pageWidth = 400.0;

Future<(PageController, List<GlobalKey<_ProtoZoomState>>)> _pump(
  WidgetTester tester, {
  double scale = 1,
  Offset offset = Offset.zero,
}) async {
  final controller = PageController();
  addTearDown(controller.dispose);
  final keys = List.generate(3, (_) => GlobalKey<_ProtoZoomState>());
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: _pageWidth,
          height: 400,
          child: PageView(
            controller: controller,
            children: [
              for (var i = 0; i < 3; i++)
                _ProtoZoom(
                  key: keys[i],
                  initialScale: i == 0 ? scale : 1,
                  initialOffset: i == 0 ? offset : Offset.zero,
                  child: SizedBox.expand(child: ColoredBox(color: Color(0xFF000000 + i * 0x404040))),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  return (controller, keys);
}

void main() {
  testWidgets('已缩放贴右边缘：同一手势里图片 → 翻页 → 收回翻页 → 图片 → 再翻页，松手吸附回本页', (tester) async {
    // 2 倍缩放、右边缘可见：offset.dx 下限 = 400 * (1 - 2) = -400。
    final (controller, keys) = await _pump(tester, scale: 2, offset: Offset(-400, -200));
    final zoom = keys[0].currentState!;
    final center = tester.getCenter(find.byKey(keys[0]));
    var t = 0;
    Duration next() => Duration(milliseconds: t += 16);

    final gesture = await tester.startGesture(center);
    await gesture.moveBy(Offset(-30, 0), timeStamp: next());
    await tester.pump();
    final p0 = controller.position.pixels;
    expect(zoom.offset.dx, -400, reason: '右边缘无法继续左移，越过起手阈值后的余量交给翻页');

    await gesture.moveBy(Offset(-100, 0), timeStamp: next());
    await tester.pump();
    expect(controller.position.pixels, moreOrLessEquals(p0 + 100));
    expect(zoom.offset.dx, -400);

    // 反向：先收回翻页偏移，再平移图片。
    await gesture.moveBy(Offset(150, 0), timeStamp: next());
    await tester.pump();
    expect(controller.position.pixels, moreOrLessEquals(0));
    expect(zoom.offset.dx, moreOrLessEquals(-400 + 150 - (p0 + 100)));

    // 再次正向：图片先回到边缘，余量重新交给翻页。
    final imageRoom = zoom.offset.dx + 400;
    await gesture.moveBy(Offset(-80, 0), timeStamp: next());
    await tester.pump();
    expect(zoom.offset.dx, moreOrLessEquals(-400));
    expect(controller.position.pixels, moreOrLessEquals(80 - imageRoom));

    // 停住后再松手：速度为零，未过半页吸附回本页。
    await gesture.moveBy(Offset.zero, timeStamp: Duration(milliseconds: t += 300));
    await gesture.up(timeStamp: Duration(milliseconds: t += 16));
    await tester.pumpAndSettle();
    expect(controller.position.pixels, 0);
    expect(zoom.scale, 2, reason: '翻页交接不改变缩放');
  });

  testWidgets('已缩放贴右边缘快速左滑：松手速度交给翻页物理，翻到下一页', (tester) async {
    final (controller, keys) = await _pump(tester, scale: 2, offset: Offset(-400, -200));
    var t = 0;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(keys[0])));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(-30, 0), timeStamp: Duration(milliseconds: t += 10));
      await tester.pump();
    }
    await gesture.up(timeStamp: Duration(milliseconds: t += 10));
    await tester.pumpAndSettle();
    expect(controller.position.pixels, _pageWidth);
    expect(controller.page, 1);
  });

  testWidgets('已缩放未贴边：先平移图片，到边缘后同一手势继续翻页', (tester) async {
    final (controller, keys) = await _pump(tester, scale: 2, offset: Offset(-300, -200));
    final zoom = keys[0].currentState!;
    var t = 0;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(keys[0])));
    await gesture.moveBy(Offset(-30, 0), timeStamp: Duration(milliseconds: t += 16));
    await tester.pump();
    expect(controller.position.pixels, 0, reason: '图片尚有行程时翻页不动');
    final room = zoom.offset.dx + 400;

    await gesture.moveBy(Offset(-room - 50, 0), timeStamp: Duration(milliseconds: t += 16));
    await tester.pump();
    expect(zoom.offset.dx, moreOrLessEquals(-400));
    expect(controller.position.pixels, moreOrLessEquals(50));
    await gesture.up(timeStamp: Duration(milliseconds: t += 300));
    await tester.pumpAndSettle();
  });

  testWidgets('未缩放单指横滑：缩放视图不参与，官方翻页直接接手', (tester) async {
    final (controller, keys) = await _pump(tester);
    final zoom = keys[0].currentState!;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(keys[0])));
    await gesture.moveBy(Offset(-300, 0));
    await tester.pump();
    expect(zoom.scale, 1);
    expect(zoom.offset, Offset.zero, reason: '未缩放时单指位移全部交给翻页');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.page, 1);
  });

  testWidgets('双指同时起手捏合：缩放视图接手，翻页不动', (tester) async {
    final (controller, keys) = await _pump(tester);
    final center = tester.getCenter(find.byKey(keys[0]));
    final a = await tester.startGesture(center - Offset(50, 0), pointer: 1);
    final b = await tester.startGesture(center + Offset(50, 0), pointer: 2);
    for (var i = 0; i < 5; i++) {
      await a.moveBy(Offset(-10, 0));
      await b.moveBy(Offset(10, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(keys[0].currentState!.scale, greaterThan(1.5));
    expect(controller.position.pixels, 0);
  });

  testWidgets('已知降级：翻页先接住第一指后，第二指落下无法再接管为捏合', (tester) async {
    final (controller, keys) = await _pump(tester);
    final center = tester.getCenter(find.byKey(keys[0]));
    final a = await tester.startGesture(center - Offset(50, 0), pointer: 1);
    await a.moveBy(Offset(-40, 0));
    await tester.pump();
    expect(controller.position.pixels, greaterThan(0), reason: '第一指已被官方翻页识别器接受');

    final b = await tester.startGesture(center + Offset(50, 0), pointer: 2);
    for (var i = 0; i < 5; i++) {
      await b.moveBy(Offset(15, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(keys[0].currentState!.scale, 1, reason: '官方竞技场里第一指归属不可转移，捏合需双指同时起手');
  });
}
