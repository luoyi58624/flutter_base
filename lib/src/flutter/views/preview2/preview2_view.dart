import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 构建预览项在多项切换中的呈现。
///
/// [position] 是该项相对当前停留位置的连续偏移：0 居中，-1 完全移到前一侧，1 完全移到后一侧；
/// [child] 已包含缩放、旋转与平移。滑动、淡入、层叠等过渡由上层决定，组件本身不内置。
typedef ElPreview2TransitionBuilder = Widget Function(
  BuildContext context,
  int index,
  ValueListenable<double> position,
  Widget child,
);

/// 读取与驱动 [ElPreview2View] 的当前项、连续翻页位置和当前项变换。
class ElPreview2Controller extends ChangeNotifier {
  /// 创建控制器，[initialIndex] 为首次挂载时的当前项。
  ElPreview2Controller({int initialIndex = 0}) : _index = initialIndex, _page = ValueNotifier(initialIndex.toDouble());

  int _index;
  final ValueNotifier<double> _page;
  _PreviewEngine? _engine;

  /// 当前项：手势越过整页或松手吸附完成时更新，并通知监听者。
  int get index => _index;

  /// 连续翻页位置，整数表示停在对应项；供上层实现切换过渡与指示器。
  ValueListenable<double> get page => _page;

  /// 当前项的缩放倍数。
  double get scale => _engine?._scale ?? 1;

  /// 当前项的旋转弧度。
  double get rotation => _engine?._rotation ?? 0;

  /// 当前项中心相对视口中心的平移。
  Offset get translation => _engine?._offset ?? Offset.zero;

  /// 立即切换到 [index] 并还原变换。
  void jumpToPage(int index) {
    final engine = _engine;
    if (engine != null) return engine.jumpToPage(index);
    _setIndex(index);
    _page.value = index.toDouble();
  }

  /// 以动画切换到 [index]；动画只驱动 [page]，视觉过渡由转场构建器决定。
  Future<void> animateToPage(
    int index, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    final engine = _engine;
    if (engine != null) return engine.animateToPage(index, duration, curve);
    jumpToPage(index);
    return Future.value();
  }

  /// 还原当前项的缩放、旋转与平移。
  void resetTransform({bool animate = true}) => _engine?.resetTransform(animate: animate);

  void _setIndex(int value) {
    if (_index == value) return;
    _index = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }
}

/// 预览视图：多指缩放、旋转与平移，平移到边缘继续移动即进入相邻项，支持双击缩放与鼠标滚轮缩放。
///
/// 手势由组件独占：竞技场里只登记一个成员用来声明归属，其余按原始指针计算，
/// 所以捏合、旋转、平移和翻页之间切换不会中断。两指里先越过角度阈值的进入旋转模式（同时可缩放），
/// 先越过间距阈值的进入缩放模式（锁定旋转），模式保持到手指少于两根。
/// 多项之间的切换过渡交给 [transitionBuilder]，画廊外观、关闭手势等由上层二次包装。
class ElPreview2View extends StatefulWidget {
  /// 创建预览视图。
  const ElPreview2View({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.transitionBuilder,
    this.controller,
    this.maxScale = 4,
    this.doubleTapScale = 2.5,
    this.enableRotation = true,
    this.enableDoubleTap = true,
    this.enableWheelZoom = true,
    this.wheelZoomSensitivity = 0.002,
    this.onTap,
    this.onIndexChanged,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(maxScale >= 1),
       assert(doubleTapScale >= 1);

  /// 预览项数量。
  final int itemCount;

  /// 构建第 index 项的内容，内容按视口尺寸布局。
  final IndexedWidgetBuilder itemBuilder;

  /// 决定各项在切换中的呈现，组件只提供连续位置。
  final ElPreview2TransitionBuilder transitionBuilder;

  /// 外部控制器；缺省时组件内部创建。
  final ElPreview2Controller? controller;

  /// 最大缩放倍数，捏合越界时带阻尼，松手回弹。
  final double maxScale;

  /// 双击放大的目标倍数；已缩放或旋转时双击还原。
  final double doubleTapScale;

  /// 是否允许双指旋转。
  final bool enableRotation;

  /// 是否启用双击缩放；启用后单击回调延迟到双击判定窗口结束。
  final bool enableDoubleTap;

  /// 是否响应鼠标滚轮缩放。
  final bool enableWheelZoom;

  /// 滚轮每逻辑像素对应的缩放指数。
  final double wheelZoomSensitivity;

  /// 单击回调，常用于切换上层外观。
  final VoidCallback? onTap;

  /// 当前项变化回调。
  final ValueChanged<int>? onIndexChanged;

  /// 未缩放时纵向拖动开始；声明任一纵向回调后组件才接管纵向手势，否则留给祖先。
  final GestureDragStartCallback? onVerticalDragStart;

  /// 未缩放时纵向拖动更新。
  final GestureDragUpdateCallback? onVerticalDragUpdate;

  /// 纵向拖动结束；第二指落下转为捏合时也以零速度结束。
  final GestureDragEndCallback? onVerticalDragEnd;

  /// 视口裁剪行为。
  final Clip clipBehavior;

  @override
  State<ElPreview2View> createState() => _PreviewState();
}

// 引擎自己持有 Ticker，用 State 管理生命周期，保证停止与释放顺序可控。
class _PreviewState extends State<ElPreview2View> with SingleTickerProviderStateMixin {
  late final _PreviewEngine _engine = _PreviewEngine(this, widget);
  ElPreview2Controller? _fallback;

  ElPreview2Controller get _controller => widget.controller ?? (_fallback ??= ElPreview2Controller());

  @override
  void initState() {
    super.initState();
    _engine
      ..attach(_controller)
      ..structure.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(ElPreview2View oldWidget) {
    super.didUpdateWidget(oldWidget);
    _engine
      ..widget = widget
      ..attach(_controller);
  }

  @override
  void dispose() {
    _engine.dispose();
    _fallback?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _engine.size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _engine.recognizer.addPointer,
          onPointerPanZoomStart: _engine.recognizer.addPointerPanZoom,
          onPointerSignal: _engine.pointerSignal,
          child: ClipRect(
            clipBehavior: widget.clipBehavior,
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final index in _engine.mounted)
                  KeyedSubtree(
                    key: ValueKey(index),
                    child: widget.transitionBuilder(
                      context,
                      index,
                      _engine.positionOf(index),
                      _ItemTransform(engine: _engine, index: index, child: widget.itemBuilder(context, index)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 每帧只重建变换节点，内容子树保持原实例。
class _ItemTransform extends StatelessWidget {
  const _ItemTransform({required this.engine, required this.index, required this.child});

  final _PreviewEngine engine;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine.transformChanged,
    builder: (context, child) => Transform(transform: engine.matrixFor(index), child: child),
    child: child,
  );
}

final class _Signal extends ChangeNotifier {
  void notify() => notifyListeners();
}

enum _Mode { idle, ignored, pan, vertical }

/// 预览手势与变换状态机：多指跟踪、模式锁定、位移分配（图片 → 翻页）、松手惯性与吸附。
final class _PreviewEngine {
  _PreviewEngine(TickerProvider vsync, this.widget) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  late final recognizer = _PreviewRecognizer(this);
  ElPreview2View widget;
  ElPreview2Controller? _controller;
  Size size = Size.zero;

  /// 挂载项集合变化时通知组件重建。
  final structure = _Signal();

  /// 当前项变换变化时通知变换节点。
  final transformChanged = _Signal();

  int _anchor = 0;
  double _scale = 1;
  double _rotation = 0;
  Offset _offset = Offset.zero;
  final _positions = <int, ValueNotifier<double>>{};
  List<int> _mountedKey = const [];

  // 指针会话。
  final _points = <int, Offset>{};
  final _downs = <int, Offset>{};
  PointerDeviceKind _kind = PointerDeviceKind.touch;
  bool _claimed = false;
  _Mode _mode = _Mode.idle;
  bool? _rotating;
  Offset _lastFocal = Offset.zero;
  VelocityTracker? _tracker;

  // 多指基准：每次手指数量变化或模式判定时重设，保证跟手不跳变。
  Offset _f0 = Offset.zero;
  double _span0 = 0;
  double _angle0 = 0;
  double _rawScale0 = 1;
  double _s0 = 1;
  double _r0 = 0;
  Offset _o0 = Offset.zero;

  // 点击与双击。
  int? _tapPointer;
  bool _tapValid = false;
  int? _pendingTapPointer;
  Offset _pendingTapPosition = Offset.zero;
  final _accepted = <int>{};
  Timer? _doubleTapTimer;
  Offset _firstTap = Offset.zero;

  // 触控板平移缩放。
  double _panZoomScale = 1;

  // 动画：一个 Ticker 承载吸附、惯性、双击与翻页动画，返回 false 表示结束。
  bool Function(double seconds)? _frame;
  Completer<void>? _pageAnimation;

  double get _page => _controller!._page.value;
  int get _count => widget.itemCount;
  Offset get _center => size.center(Offset.zero);
  double get _slop => computeHitSlop(_kind, null);

  void attach(ElPreview2Controller controller) {
    if (identical(_controller, controller)) return;
    _controller?._engine = null;
    _controller = controller.._engine = this;
    _anchor = controller._index;
    _scale = 1;
    _rotation = 0;
    _offset = Offset.zero;
  }

  void dispose() {
    _stopMotion();
    _doubleTapTimer?.cancel();
    _ticker.dispose();
    recognizer.dispose();
    if (_controller?._engine == this) _controller!._engine = null;
    for (final position in _positions.values) {
      position.dispose();
    }
    structure.dispose();
    transformChanged.dispose();
  }

  // ───────────────────────── 挂载与位置 ─────────────────────────

  /// 需要挂载的项：当前项及其两侧，再加翻页位置跨越的两项。
  List<int> get mounted {
    if (_count <= 0) return const [];
    final page = _page;
    final indices = {_anchor - 1, _anchor, _anchor + 1, page.floor(), page.ceil()}.toList()..sort();
    return [
      for (final index in indices)
        if (index >= 0 && index < _count) index,
    ];
  }

  ValueListenable<double> positionOf(int index) {
    final position = _positions.putIfAbsent(index, () => ValueNotifier(0));
    position.value = index - _page;
    return position;
  }

  void _setPage(double value) {
    _controller!._page.value = value;
    for (final entry in _positions.entries) {
      entry.value.value = entry.key - value;
    }
    _syncStructure();
  }

  void _syncStructure() {
    final next = mounted;
    if (listEquals(next, _mountedKey)) return;
    _mountedKey = next;
    final stale = [
      for (final index in _positions.keys)
        if (!next.contains(index)) index,
    ];
    if (stale.isNotEmpty) {
      final removed = [for (final index in stale) _positions.remove(index)!];
      // 旧项的监听在下一帧卸载时移除，之后再释放。
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final position in removed) {
          position.dispose();
        }
      });
    }
    structure.notify();
  }

  void _setAnchor(int index) {
    if (index == _anchor) return;
    _anchor = index;
    _scale = 1;
    _rotation = 0;
    _offset = Offset.zero;
    transformChanged.notify();
    _controller!._setIndex(index);
    widget.onIndexChanged?.call(index);
    _syncStructure();
  }

  // ───────────────────────── 变换几何 ─────────────────────────

  Matrix4 matrixFor(int index) {
    if (index != _anchor) return Matrix4.identity();
    final c = _center;
    return Matrix4.translationValues(c.dx + _offset.dx, c.dy + _offset.dy, 0)
      ..multiply(Matrix4.rotationZ(_rotation))
      ..multiply(Matrix4.diagonal3Values(_scale, _scale, 1))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }

  void _setTransform(double scale, double rotation, Offset offset) {
    _scale = scale;
    _rotation = rotation;
    _offset = offset;
    transformChanged.notify();
  }

  /// 旋转缩放后的内容外接框超出视口的一半，即各轴可平移的范围。
  Offset _range(double scale, double rotation) {
    final cos = math.cos(rotation).abs();
    final sin = math.sin(rotation).abs();
    final width = size.width * scale * cos + size.height * scale * sin;
    final height = size.width * scale * sin + size.height * scale * cos;
    return Offset(math.max(0, (width - size.width) / 2), math.max(0, (height - size.height) / 2));
  }

  Offset _clampOffset(Offset offset, double scale, double rotation) {
    final range = _range(scale, rotation);
    return Offset(offset.dx.clamp(-range.dx, range.dx), offset.dy.clamp(-range.dy, range.dy));
  }

  bool get _canPan {
    final range = _range(_scale, _rotation);
    return range.dx > 0.5 || range.dy > 0.5;
  }

  bool get _isTransformed => (_scale - 1).abs() > 1e-3 || _rotation.abs() > 1e-3 || _offset.distance > 0.5;

  static Offset _rotate(Offset v, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(v.dx * cos - v.dy * sin, v.dx * sin + v.dy * cos);
  }

  static double _angleDelta(double to, double from) {
    var delta = to - from;
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    return delta;
  }

  // 捏合越界阻尼：边界处连续，越界越远越难拉。
  double _resist(double raw) {
    final max = widget.maxScale;
    if (raw < 1) return math.pow(raw, 0.4).toDouble();
    if (raw > max) return max * math.pow(raw / max, 0.4);
    return raw;
  }

  double _unresist(double scale) {
    final max = widget.maxScale;
    if (scale < 1) return math.pow(scale, 1 / 0.4).toDouble();
    if (scale > max) return max * math.pow(scale / max, 1 / 0.4);
    return scale;
  }

  void _scaleAround(Offset focal, double scale) {
    if (_scale <= 0) return;
    final c = _center;
    final next = (focal - c) - (focal - c - _offset) * (scale / _scale);
    _setTransform(scale, _rotation, _clampOffset(next, scale, _rotation));
  }

  // ───────────────────────── 指针输入 ─────────────────────────

  Offset get _focal {
    var sum = Offset.zero;
    for (final point in _points.values) {
      sum += point;
    }
    return sum / _points.length.toDouble();
  }

  double get _span {
    final focal = _focal;
    var sum = 0.0;
    for (final point in _points.values) {
      sum += (point - focal).distance;
    }
    return sum / _points.length;
  }

  double get _angle {
    final points = _points.values.take(2).toList();
    final v = points[1] - points[0];
    return math.atan2(v.dy, v.dx);
  }

  void down(PointerDownEvent event) {
    if (_points.isEmpty) {
      _stopMotion();
      _claimed = false;
      _mode = _Mode.idle;
      _rotating = null;
      _kind = event.kind;
      _accepted.clear();
      _tapPointer = event.pointer;
      _tapValid = true;
    } else {
      _tapValid = false;
    }
    _points[event.pointer] = event.localPosition;
    _downs[event.pointer] = event.localPosition;
    if (_points.length >= 2) {
      if (_mode == _Mode.vertical) _endVertical(Velocity.zero);
      if (_points.length == 2) _rotating = null;
      _mode = _Mode.pan;
      _claim();
    } else if (_claimed) {
      recognizer.claim();
    }
    _rebase();
  }

  void handle(PointerEvent event) {
    switch (event) {
      case PointerMoveEvent():
        _move(event);
      case PointerUpEvent():
        _up(event);
      case PointerCancelEvent():
        _removePointer(event.pointer, canceled: true);
      case PointerPanZoomUpdateEvent():
        _panZoomUpdate(event);
      case PointerPanZoomEndEvent():
        _panZoomEnd();
      default:
        break;
    }
  }

  void accept(int pointer) {
    _accepted.add(pointer);
    if (_pendingTapPointer == pointer) {
      _pendingTapPointer = null;
      _commitTap(_pendingTapPosition);
    }
  }

  void reject(int pointer) {
    if (_pendingTapPointer == pointer) _pendingTapPointer = null;
    _removePointer(pointer, canceled: true);
  }

  void _claim() {
    _claimed = true;
    recognizer.claim();
  }

  void _rebase() {
    _tracker = VelocityTracker.withKind(_kind);
    if (_points.isEmpty) return;
    _lastFocal = _focal;
    if (_points.length >= 2) _rebaseMulti(_focal, _span, _angle);
  }

  void _rebaseMulti(Offset focal, double span, double angle) {
    _f0 = focal;
    _span0 = span;
    _angle0 = angle;
    _rawScale0 = _unresist(_scale);
    _s0 = _scale;
    _r0 = _rotation;
    _o0 = _offset;
  }

  void _move(PointerMoveEvent event) {
    if (!_points.containsKey(event.pointer)) return;
    _points[event.pointer] = event.localPosition;
    if (_tapValid && event.pointer == _tapPointer) {
      if ((event.localPosition - _downs[event.pointer]!).distance > _slop) _tapValid = false;
    }
    if (!_claimed && !_tryClaim(event)) return;
    _tracker?.addPosition(event.timeStamp, _focal);
    if (_points.length >= 2) {
      _updateMulti();
      return;
    }
    final focal = _focal;
    final delta = focal - _lastFocal;
    _lastFocal = focal;
    if (_mode == _Mode.vertical) {
      widget.onVerticalDragUpdate?.call(
        DragUpdateDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          sourceTimeStamp: event.timeStamp,
          delta: Offset(0, delta.dy),
          primaryDelta: delta.dy,
        ),
      );
    } else {
      _panBy(delta);
    }
  }

  bool get _hasVertical =>
      widget.onVerticalDragStart != null || widget.onVerticalDragUpdate != null || widget.onVerticalDragEnd != null;

  // 单指越过阈值时决定归属：已缩放或翻页未归位时自由平移；未缩放时按起手方向分为翻页与纵向扩展。
  bool _tryClaim(PointerMoveEvent event) {
    if (_mode == _Mode.ignored || _points.length != 1) return false;
    final down = _downs[event.pointer]!;
    final delta = event.localPosition - down;
    if (delta.distance <= _slop) return false;
    if (_canPan || (_page - _anchor).abs() > 1e-6) {
      _mode = _Mode.pan;
    } else if (delta.dx.abs() >= delta.dy.abs()) {
      if (_count < 2) {
        _mode = _Mode.ignored;
        return false;
      }
      _mode = _Mode.pan;
    } else {
      if (!_hasVertical) {
        _mode = _Mode.ignored;
        return false;
      }
      _mode = _Mode.vertical;
      widget.onVerticalDragStart?.call(
        DragStartDetails(
          globalPosition: event.position - delta,
          localPosition: down,
          sourceTimeStamp: event.timeStamp,
          kind: event.kind,
        ),
      );
    }
    _claim();
    return true;
  }

  void _updateMulti() {
    final focal = _focal;
    final span = _span;
    final angle = _angle;
    if (_span0 <= 1) {
      _rebaseMulti(focal, span, angle);
      return;
    }
    if (_rotating == null) {
      if (!widget.enableRotation) {
        _rotating = false;
      } else if (_angleDelta(angle, _angle0).abs() * _span0 > _slop) {
        // 旋转从判定这一刻开始，不补回阈值内的角度，避免跳变。
        _rotating = true;
        _rebaseMulti(focal, span, angle);
      } else if ((span - _span0).abs() > _slop) {
        _rotating = false;
      }
    }
    final scale = _resist(_rawScale0 * span / _span0);
    final rotation = _rotating == true ? _r0 + _angleDelta(angle, _angle0) : _r0;
    final c = _center;
    final local = _rotate(_f0 - c - _o0, -_r0) / _s0;
    _setTransform(scale, rotation, focal - c - _rotate(local, rotation) * scale);
  }

  // 单指位移分配：翻页偏离时先收回，其次平移图片，图片到边缘后的余量进入翻页。
  void _panBy(Offset delta) {
    final width = size.width;
    if (width <= 0) return;
    final range = _range(_scale, _rotation);
    final y = _axisPan(_offset.dy, delta.dy, range.dy).$1;
    var rest = delta.dx;
    var x = _offset.dx;
    final displacement = (_page - _anchor) * width;
    if (displacement.abs() > 1e-6 && rest != 0 && (rest > 0) == (displacement > 0)) {
      final closing = rest.sign * math.min(rest.abs(), displacement.abs());
      final next = _page - closing / width;
      _setPage(((next - _anchor) * width).abs() < 0.01 ? _anchor.toDouble() : next);
      rest -= closing;
    }
    if (rest != 0 && (_page - _anchor).abs() <= 1e-6) {
      final (next, overflow) = _axisPan(x, rest, range.dx);
      x = next;
      rest = overflow;
    }
    if (x != _offset.dx || y != _offset.dy) _setTransform(_scale, _rotation, Offset(x, y));
    if (rest.abs() > 1e-6) _movePage(-rest / width);
  }

  static (double, double) _axisPan(double value, double delta, double range) {
    if (delta > 0) {
      if (value >= range) return (value, delta);
      final room = range - value;
      return delta <= room ? (value + delta, 0) : (range, delta - room);
    }
    if (delta < 0) {
      if (value <= -range) return (value, delta);
      final room = -range - value;
      return delta >= room ? (value + delta, 0) : (-range, delta - room);
    }
    return (value, 0);
  }

  void _movePage(double delta) {
    final last = (_count - 1).toDouble();
    final page = _page;
    var next = page + delta;
    if (delta < 0 && next < 0) {
      final rest = delta + math.max(0.0, page);
      final current = math.min(page, 0.0);
      next = math.max(-0.5, current + rest * _edgeFactor(-current));
    } else if (delta > 0 && next > last) {
      final rest = delta - math.max(0.0, last - page);
      final current = math.max(page, last);
      next = math.min(last + 0.5, current + rest * _edgeFactor(current - last));
    }
    _setPage(next);
    while (_page - _anchor >= 1 - 1e-9 && _anchor < _count - 1) {
      _setAnchor(_anchor + 1);
    }
    while (_page - _anchor <= -1 + 1e-9 && _anchor > 0) {
      _setAnchor(_anchor - 1);
    }
  }

  static double _edgeFactor(double overscroll) => 0.52 * math.pow(1 - (overscroll / 0.5).clamp(0.0, 1.0), 2);

  void _up(PointerUpEvent event) {
    if (!_points.containsKey(event.pointer)) return;
    final tap = _tapValid && event.pointer == _tapPointer && !_claimed && _points.length == 1;
    if (tap) {
      _tapValid = false;
      if (_accepted.contains(event.pointer)) {
        _commitTap(event.localPosition);
      } else {
        _pendingTapPointer = event.pointer;
        _pendingTapPosition = event.localPosition;
      }
    }
    _removePointer(event.pointer, canceled: false);
  }

  void _removePointer(int pointer, {required bool canceled}) {
    if (_points.remove(pointer) == null) return;
    _downs.remove(pointer);
    if (pointer == _tapPointer) _tapValid = _tapValid && !canceled;
    if (_points.isEmpty) {
      _finish(canceled: canceled);
      return;
    }
    if (_points.length == 1) _rotating = null;
    _rebase();
  }

  void _finish({required bool canceled}) {
    final claimed = _claimed;
    var velocity = Velocity.zero;
    if (claimed && !canceled) velocity = _tracker?.getVelocity() ?? Velocity.zero;
    velocity = velocity.clampMagnitude(0, kMaxFlingVelocity);
    if (_mode == _Mode.vertical) _endVertical(velocity);
    _claimed = false;
    _mode = _Mode.idle;
    _rotating = null;
    _tracker = null;
    _settle(claimed ? velocity.pixelsPerSecond : Offset.zero);
  }

  void _endVertical(Velocity velocity) {
    _mode = _Mode.pan;
    final dy = velocity.pixelsPerSecond.dy;
    widget.onVerticalDragEnd?.call(
      DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(0, dy)),
        primaryVelocity: dy,
      ),
    );
  }

  // ───────────────────────── 点击、滚轮与触控板 ─────────────────────────

  void _commitTap(Offset position) {
    if (!widget.enableDoubleTap) {
      widget.onTap?.call();
      return;
    }
    final timer = _doubleTapTimer;
    if (timer != null && timer.isActive && (position - _firstTap).distance <= kDoubleTapSlop) {
      timer.cancel();
      _doubleTapTimer = null;
      _toggleZoom(position);
      return;
    }
    if (timer != null && timer.isActive) {
      timer.cancel();
      widget.onTap?.call();
    }
    _firstTap = position;
    _doubleTapTimer = Timer(kDoubleTapTimeout, () {
      _doubleTapTimer = null;
      widget.onTap?.call();
    });
  }

  void _toggleZoom(Offset position) {
    if (_isTransformed) {
      _animateTransform(1, 0, Offset.zero);
      return;
    }
    final scale = widget.doubleTapScale.clamp(1.0, widget.maxScale);
    _animateTransform(scale, 0, _clampOffset((position - _center) * (1 - scale), scale, 0));
  }

  void pointerSignal(PointerSignalEvent event) {
    if (!widget.enableWheelZoom || event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      final factor = math.exp(-scroll.scrollDelta.dy * widget.wheelZoomSensitivity);
      _stopMotion();
      _scaleAround(scroll.localPosition, (_scale * factor).clamp(1.0, widget.maxScale));
    });
  }

  void panZoomStart(PointerPanZoomStartEvent event) {
    _stopMotion();
    _kind = event.kind;
    _claimed = true;
    _mode = _Mode.pan;
    _panZoomScale = 1;
    _tracker = VelocityTracker.withKind(event.kind);
  }

  void _panZoomUpdate(PointerPanZoomUpdateEvent event) {
    final ratio = event.scale / _panZoomScale;
    _panZoomScale = event.scale;
    if ((ratio - 1).abs() > 1e-6) _scaleAround(event.localPosition, (_scale * ratio).clamp(1.0, widget.maxScale));
    if (event.localPanDelta != Offset.zero) _panBy(event.localPanDelta);
    _tracker?.addPosition(event.timeStamp, event.localPan);
  }

  void _panZoomEnd() {
    final velocity = (_tracker?.getVelocity() ?? Velocity.zero).clampMagnitude(0, kMaxFlingVelocity);
    _claimed = false;
    _mode = _Mode.idle;
    _tracker = null;
    _settle(velocity.pixelsPerSecond);
  }

  // ───────────────────────── 松手与动画 ─────────────────────────

  static final _spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 1);
  static const _pageFlingVelocity = 300.0;
  static const _transformSeconds = 0.22;

  // 松手：翻页未归位时按速度或过半决定目标并弹簧吸附；否则回弹越界变换，或按速度做图片惯性。
  void _settle(Offset velocity) {
    if (size.isEmpty || _count <= 0) return;
    final targetScale = _scale.clamp(1.0, widget.maxScale);
    final targetOffset = _clampOffset(_offset * (targetScale / _scale), targetScale, _rotation);
    final needTransform = (targetScale - _scale).abs() > 1e-4 || (targetOffset - _offset).distance > 0.5;
    final displacement = _page - _anchor;
    if (displacement.abs() > 1e-4) {
      final pageVelocity = -velocity.dx / size.width;
      var target = _anchor;
      if (velocity.dx.abs() > _pageFlingVelocity && (pageVelocity > 0) == (displacement > 0)) {
        target += pageVelocity > 0 ? 1 : -1;
      } else if (displacement.abs() >= 0.5) {
        target += displacement > 0 ? 1 : -1;
      }
      target = target.clamp(0, _count - 1);
      final simulation = SpringSimulation(
        _spring,
        _page,
        target.toDouble(),
        pageVelocity,
        tolerance: Tolerance(distance: 1e-3, velocity: 1e-2),
      );
      final transform = needTransform && target == _anchor
          ? _transformFrame(targetScale, _rotation, targetOffset)
          : null;
      _startMotion((t) {
        final pageDone = simulation.isDone(t);
        _setPage(pageDone ? target.toDouble() : simulation.x(t));
        final transformRunning = transform?.call(t) ?? false;
        if (pageDone && !transformRunning) {
          _setAnchor(target);
          return false;
        }
        return true;
      });
      return;
    }
    if (needTransform) {
      _animateTransform(targetScale, _rotation, targetOffset);
      return;
    }
    if (_canPan && velocity.distance > kMinFlingVelocity) {
      final x = FrictionSimulation(0.135, _offset.dx, velocity.dx);
      final y = FrictionSimulation(0.135, _offset.dy, velocity.dy);
      _startMotion((t) {
        _setTransform(_scale, _rotation, _clampOffset(Offset(x.x(t), y.x(t)), _scale, _rotation));
        return !(x.isDone(t) && y.isDone(t));
      });
    }
  }

  bool Function(double seconds) _transformFrame(double scale, double rotation, Offset offset) {
    final fromScale = _scale;
    final fromRotation = _rotation;
    final fromOffset = _offset;
    final turn = _angleDelta(rotation, fromRotation);
    return (t) {
      final k = Curves.easeOutCubic.transform((t / _transformSeconds).clamp(0.0, 1.0));
      _setTransform(fromScale + (scale - fromScale) * k, fromRotation + turn * k, Offset.lerp(fromOffset, offset, k)!);
      return k < 1;
    };
  }

  void _animateTransform(double scale, double rotation, Offset offset) =>
      _startMotion(_transformFrame(scale, rotation, offset));

  void jumpToPage(int index) {
    if (_count <= 0) return;
    _stopMotion();
    final target = index.clamp(0, _count - 1);
    if (target == _anchor) {
      _setTransform(1, 0, Offset.zero);
    } else {
      _setAnchor(target);
    }
    _setPage(target.toDouble());
  }

  Future<void> animateToPage(int index, Duration duration, Curve curve) {
    if (_count <= 0) return Future.value();
    _stopMotion();
    final target = index.clamp(0, _count - 1);
    final from = _page;
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    final completer = _pageAnimation = Completer<void>();
    _startMotion((t) {
      final k = seconds <= 0 ? 1.0 : curve.transform((t / seconds).clamp(0.0, 1.0));
      _setPage(from + (target - from) * k);
      if (k < 1) return true;
      _setAnchor(target);
      _setPage(target.toDouble());
      return false;
    });
    return completer.future;
  }

  void resetTransform({required bool animate}) {
    if (animate) {
      _animateTransform(1, 0, Offset.zero);
    } else {
      _stopMotion();
      _setTransform(1, 0, Offset.zero);
    }
  }

  void _startMotion(bool Function(double seconds) frame) {
    _stopMotion();
    _frame = frame;
    _ticker.start();
  }

  void _stopMotion() {
    _frame = null;
    if (_ticker.isActive) _ticker.stop();
    final completer = _pageAnimation;
    _pageAnimation = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _tick(Duration elapsed) {
    final frame = _frame;
    if (frame == null) return;
    // 帧回调里可能触发 onIndexChanged，上层若借机启动新动画，不能被这里误停。
    if (!frame(elapsed.inMicroseconds / Duration.microsecondsPerSecond) && identical(_frame, frame)) _stopMotion();
  }
}

/// 竞技场里的唯一成员：只负责声明手势归属，原始指针交给引擎处理。
final class _PreviewRecognizer extends OneSequenceGestureRecognizer {
  _PreviewRecognizer(this._engine);

  final _PreviewEngine _engine;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) return false;
    return super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _engine.down(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolvePointer(event.pointer, GestureDisposition.accepted);
    _engine.panZoomStart(event);
  }

  /// 接受当前跟踪的全部指针。
  void claim() => resolve(GestureDisposition.accepted);

  @override
  void handleEvent(PointerEvent event) {
    _engine.handle(event);
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) => _engine.accept(pointer);

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    _engine.reject(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'ElPreview2View';
}
