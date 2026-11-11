import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 原型：只用官方识别器的缩放视图，平移贴边后的余量经祖先 ScrollPosition.drag 交给翻页。
///
/// 用于验证移除 ElView 拖动 / 缩放手势后的目标形态，不依赖事件层台账。
class OfficialZoomView extends StatefulWidget {
  /// 创建原型缩放视图。
  const OfficialZoomView({
    super.key,
    required this.child,
    this.initialScale = 1,
    this.initialOffset = Offset.zero,
    this.maxScale = 4,
    this.doubleTapScale = 2.5,
  });

  /// 被缩放的内容，按视口尺寸布局。
  final Widget child;

  /// 初始缩放倍数。
  final double initialScale;

  /// 初始平移量，内容左上角相对视口的位置。
  final Offset initialOffset;

  /// 最大缩放倍数。
  final double maxScale;

  /// 双击放大的目标倍数。
  final double doubleTapScale;

  @override
  State<OfficialZoomView> createState() => OfficialZoomViewState();
}

/// 原型缩放视图的状态，测试经它读取当前缩放与平移。
class OfficialZoomViewState extends State<OfficialZoomView> with SingleTickerProviderStateMixin {
  /// 当前缩放倍数。
  late double scale = widget.initialScale;

  /// 当前平移量。
  late Offset offset = widget.initialOffset;

  late final _ZoomRecognizer _recognizer = _ZoomRecognizer(() => scale > 1 + precisionErrorTolerance)
    ..onStart = _start
    ..onUpdate = _update
    ..onEnd = _end;
  late final DoubleTapGestureRecognizer _doubleTap = DoubleTapGestureRecognizer()..onDoubleTapDown = _doubleTapDown;
  late final Ticker _ticker = createTicker(_tick);

  Size _size = Size.zero;
  double _startScale = 1;
  int _pointerCount = 0;
  ScrollPosition? _ancestor;
  // 本页在祖先滚动坐标中的起点，手势开始时由布局换算一次，之后只读实时 pixels。
  double _pageStart = 0;
  Drag? _drag;
  Offset _lastGlobal = Offset.zero;
  // 双击动画与平移惯性共用一个 Ticker，返回 false 表示结束。
  bool Function(double seconds)? _frame;

  @override
  void dispose() {
    _drag?.cancel();
    _ticker.dispose();
    _recognizer.dispose();
    _doubleTap.dispose();
    super.dispose();
  }

  Offset _clamp(Offset value, double s) {
    final minX = math.min(0.0, _size.width * (1 - s));
    final minY = math.min(0.0, _size.height * (1 - s));
    return Offset(value.dx.clamp(minX, 0.0), value.dy.clamp(minY, 0.0));
  }

  void _pointerDown(PointerDownEvent event) {
    _stopMotion();
    _recognizer.addPointer(event);
    _doubleTap.addPointer(event);
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
    _pointerCount = details.pointerCount;
    if (details.pointerCount >= 2) {
      _releaseDrag(0);
      final next = (_startScale * details.scale).clamp(1.0, widget.maxScale);
      final content = (details.localFocalPoint - details.focalPointDelta - offset) / scale;
      setState(() {
        offset = _clamp(details.localFocalPoint - content * next, next);
        scale = next;
      });
      return;
    }
    // 未缩放的单指位移属于祖先滚动，本视图不处理。
    if (scale <= 1 + precisionErrorTolerance) return;
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

  void _end(ScaleEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (_drag != null) {
      _releaseDrag(velocity.dx);
      return;
    }
    // 只有单指平移松手才有图片惯性；惯性停在图片边缘，不翻页。
    if (_pointerCount != 1 || scale <= 1 + precisionErrorTolerance || velocity.distance < kMinFlingVelocity) return;
    final x = FrictionSimulation(0.135, offset.dx, velocity.dx);
    final y = FrictionSimulation(0.135, offset.dy, velocity.dy);
    _startMotion((t) {
      setState(() => offset = _clamp(Offset(x.x(t), y.x(t)), scale));
      return !(x.isDone(t) && y.isDone(t));
    });
  }

  void _doubleTapDown(TapDownDetails details) {
    final fromScale = scale;
    final fromOffset = offset;
    final toScale = scale > 1 + precisionErrorTolerance ? 1.0 : widget.doubleTapScale;
    final focal = details.localPosition;
    final toOffset = _clamp(focal - (focal - offset) / scale * toScale, toScale);
    _startMotion((t) {
      final progress = Curves.easeOutCubic.transform((t / 0.25).clamp(0.0, 1.0));
      setState(() {
        scale = fromScale + (toScale - fromScale) * progress;
        offset = Offset.lerp(fromOffset, toOffset, progress)!;
      });
      return progress < 1;
    });
  }

  void _startMotion(bool Function(double seconds) frame) {
    _stopMotion();
    _frame = frame;
    _ticker.start();
  }

  void _stopMotion() {
    _frame = null;
    if (_ticker.isActive) _ticker.stop();
  }

  void _tick(Duration elapsed) {
    final frame = _frame;
    if (frame == null || !frame(elapsed.inMicroseconds / Duration.microsecondsPerSecond)) _stopMotion();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _pointerDown,
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
    // 两指很难同时落下：第二指一落下就接受为捏合，避免第一指的少量横移先让翻页越过起手阈值。
    if (!_accepted && _downs.length >= 2) resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    // 命中路径更深的识别器先收到同一次移动，所以同阈值下本视图先于祖先翻页接受。
    if (!_accepted && event is PointerMoveEvent && zoomed()) {
      final down = _downs[event.pointer];
      if (down != null && (event.position - down).distance > computeHitSlop(event.kind, gestureSettings)) {
        resolve(GestureDisposition.accepted);
      }
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) _downs.remove(event.pointer);
  }

  @override
  void resolve(GestureDisposition disposition) {
    // 未缩放的单指平移不接受，留给祖先翻页；保持候选，第二指落下仍可接受为捏合。
    if (disposition == GestureDisposition.accepted && !zoomed() && _downs.length < 2) return;
    super.resolve(disposition);
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
