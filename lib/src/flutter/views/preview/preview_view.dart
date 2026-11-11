import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 读取与驱动 [ElPreviewView] 的当前项、连续翻页位置和当前项变换。
class ElPreviewController extends ChangeNotifier {
  /// 创建控制器，[initialIndex] 为首次挂载时的当前项。
  ElPreviewController({int initialIndex = 0}) : _index = initialIndex, _page = ValueNotifier(initialIndex.toDouble());

  int _index;
  final ValueNotifier<double> _page;
  _PreviewEngine? _engine;

  /// 当前项：手势越过整页、第二指落下切换操作项或松手吸附完成时更新，并通知监听者。
  int get index => _index;

  /// 连续翻页位置，整数表示停在对应项；可用于指示器等上层外观。
  ValueListenable<double> get page => _page;

  /// 当前项的缩放倍数。
  double get scale => _engine?._active.scale ?? 1;

  /// 当前项的旋转弧度。
  double get rotation => _engine?._active.rotation ?? 0;

  /// 当前项中心相对视口中心的平移。
  Offset get translation => _engine?._active.offset ?? Offset.zero;

  /// 立即切换到 [index] 并还原变换。
  void jumpToPage(int index) {
    final engine = _engine;
    if (engine != null) return engine.jumpToPage(index);
    _setIndex(index);
    _page.value = index.toDouble();
  }

  /// 以动画切换到 [index]。
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

  /// 围绕视口中心缩放当前项，倍数限制在视图允许的范围内。
  void zoomTo(double scale, {bool animate = true}) {
    assert(scale.isFinite && scale > 0);
    _engine?.transformTo(scale: scale, animate: animate);
  }

  /// 将当前项旋转指定弧度，默认顺时针旋转九十度。
  void rotateBy([double radians = math.pi / 2]) {
    assert(radians.isFinite);
    _engine?.transformTo(rotation: rotation + radians, animate: true);
  }

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

/// 预览视图：任意内容的多指缩放、旋转与平移，平移到边缘继续移动即进入相邻项，支持双击缩放与鼠标滚轮缩放。
///
/// 组件自己管理相邻项与横向切换，上层只提供每一项的内容。手势由组件独占：竞技场里只登记一个成员
/// 用来声明归属，其余按原始指针计算，所以捏合、旋转、平移和翻页之间切换不会中断。
/// 两指里先越过角度阈值的进入旋转模式（同时可缩放），先越过间距阈值的进入缩放模式（锁定旋转），
/// 模式保持到手指少于两根；松手后旋转沿最短方向吸附到最近的直角，缩放保留。
class ElPreviewView extends StatefulWidget {
  /// 创建预览视图。
  const ElPreviewView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.pageSpacing = 16,
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
       assert(doubleTapScale >= 1),
       assert(pageSpacing >= 0);

  /// 预览项数量。
  final int itemCount;

  /// 构建第 index 项的内容，任意 Widget，按视口尺寸布局。
  final IndexedWidgetBuilder itemBuilder;

  /// 外部控制器；缺省时组件内部创建。
  final ElPreviewController? controller;

  /// 相邻项之间的横向间隔。
  final double pageSpacing;

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
  State<ElPreviewView> createState() => _PreviewState();
}

// 引擎自己持有 Ticker，用 State 管理生命周期，保证停止与释放顺序可控。
class _PreviewState extends State<ElPreviewView> with SingleTickerProviderStateMixin {
  late final _PreviewEngine _engine = _PreviewEngine(this, widget);
  ElPreviewController? _fallback;

  ElPreviewController get _controller => widget.controller ?? (_fallback ??= ElPreviewController());

  @override
  void initState() {
    super.initState();
    _engine
      ..attach(_controller)
      ..structure.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(ElPreviewView oldWidget) {
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
                    child: _ItemTransform(engine: _engine, index: index, child: widget.itemBuilder(context, index)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 翻页位移与该项自身变换合成一个矩阵，每帧只重建变换节点，内容子树保持原实例。
class _ItemTransform extends StatelessWidget {
  const _ItemTransform({required this.engine, required this.index, required this.child});

  final _PreviewEngine engine;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine.changed,
    builder: (context, child) => Transform(transform: engine.matrixFor(index), child: child),
    child: child,
  );
}

final class _Signal extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// 单项的缩放、旋转与平移；平移为该项中心相对视口中心的偏移。
final class _ItemState {
  double scale = 1;
  double rotation = 0;
  Offset offset = Offset.zero;
}

enum _Mode { idle, ignored, pan, vertical }

/// 预览手势与变换状态机：多指跟踪、模式锁定、位移分配（当前项 → 翻页）、松手惯性与吸附。
final class _PreviewEngine {
  _PreviewEngine(TickerProvider vsync, this.widget) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  late final recognizer = _PreviewRecognizer(this);
  ElPreviewView widget;
  ElPreviewController? _controller;
  Size size = Size.zero;

  /// 挂载项集合变化时通知组件重建。
  final structure = _Signal();

  /// 翻页位置或任一项变换变化时通知变换节点。
  final changed = _Signal();

  // 当前操作项；每项各自保存变换，离开视口或吸附到其他项后复位。
  int _anchor = 0;
  final _items = <int, _ItemState>{};
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

  // 多指基准：每次手指数量变化或模式判定时重设，保证跟手不跳变；焦点均换算到当前项坐标。
  Offset _f0 = Offset.zero;
  double _span0 = 0;
  // 手指连线相对基准累计转过的角度，逐次累加增量，超过半圈也保持连续。
  double _lastAngle = 0;
  double _turn = 0;
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
  double get _stride => size.width + widget.pageSpacing;
  _ItemState get _active => _items.putIfAbsent(_anchor, _ItemState.new);

  void attach(ElPreviewController controller) {
    if (identical(_controller, controller)) return;
    _controller?._engine = null;
    _controller = controller.._engine = this;
    _anchor = controller._index;
    _items.clear();
  }

  void dispose() {
    _stopMotion();
    _doubleTapTimer?.cancel();
    _ticker.dispose();
    recognizer.dispose();
    if (_controller?._engine == this) _controller!._engine = null;
    structure.dispose();
    changed.dispose();
  }

  // ───────────────────────── 挂载与翻页 ─────────────────────────

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

  void _setPage(double value) {
    _controller!._page.value = value;
    changed.notify();
    _syncStructure();
  }

  void _syncStructure() {
    final next = mounted;
    if (listEquals(next, _mountedKey)) return;
    _mountedKey = next;
    _items.removeWhere((index, _) => !next.contains(index));
    structure.notify();
  }

  void _setAnchor(int index) {
    if (index == _anchor) return;
    _anchor = index;
    _controller!._setIndex(index);
    widget.onIndexChanged?.call(index);
    _syncStructure();
  }

  // 停到某一项后，其余项的变换复位。
  void _settleAt(int index) {
    _setAnchor(index);
    _setPage(index.toDouble());
    _items.removeWhere((key, _) => key != index);
    changed.notify();
  }

  double _shiftOf(int index) => (index - _page) * _stride;

  /// 视口坐标换算到当前项坐标：当前项未归位时扣除它的翻页位移。
  Offset _toActive(Offset position) => position - Offset(_shiftOf(_anchor), 0);

  // ───────────────────────── 变换几何 ─────────────────────────

  Matrix4 matrixFor(int index) {
    final shift = _shiftOf(index);
    final item = _items[index];
    if (item == null) return Matrix4.translationValues(shift, 0, 0);
    final c = _center;
    return Matrix4.translationValues(shift + c.dx + item.offset.dx, c.dy + item.offset.dy, 0)
      ..multiply(Matrix4.rotationZ(item.rotation))
      ..multiply(Matrix4.diagonal3Values(item.scale, item.scale, 1))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }

  void _setTransform(double scale, double rotation, Offset offset) {
    _active
      ..scale = scale
      ..rotation = rotation
      ..offset = offset;
    changed.notify();
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
    final range = _range(_active.scale, _active.rotation);
    return range.dx > 0.5 || range.dy > 0.5;
  }

  bool get _isTransformed {
    final item = _active;
    return (item.scale - 1).abs() > 1e-3 || item.rotation.abs() > 1e-3 || item.offset.distance > 0.5;
  }

  static Offset _rotate(Offset v, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(v.dx * cos - v.dy * sin, v.dx * sin + v.dy * cos);
  }

  /// 松手时旋转吸附到最近的直角，落在 (-π, π]。
  static double _snapRotation(double rotation) {
    const quarter = math.pi / 2;
    final snapped = (rotation / quarter).round() * quarter;
    return math.atan2(math.sin(snapped), math.cos(snapped));
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
    final item = _active;
    if (item.scale <= 0) return;
    final c = _center;
    final local = _toActive(focal);
    final next = (local - c) - (local - c - item.offset) * (scale / item.scale);
    _setTransform(scale, item.rotation, _clampOffset(next, scale, item.rotation));
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
      if (_points.length == 2) {
        _rotating = null;
        _focusNearest();
      }
      _mode = _Mode.pan;
      _claim();
    } else if (_claimed) {
      recognizer.claim();
    }
    _rebase();
  }

  // 翻页未归位时开始捏合：操作项切到更靠近中间的一项，翻页同时吸附过去。
  void _focusNearest() {
    final displacement = _page - _anchor;
    if (displacement.abs() <= 1e-4 || _count <= 0) return;
    final target = _page.round().clamp(0, _count - 1);
    _setAnchor(target);
    final simulation = SpringSimulation(
      _spring,
      _page,
      target.toDouble(),
      0,
      tolerance: Tolerance(distance: 1e-3, velocity: 1e-2),
    );
    _startMotion((t) {
      if (simulation.isDone(t)) {
        _settleAt(target);
        // 手指已全部抬起时，接着执行松手复位（旋转吸附直角、缩放与平移收回范围）。
        if (_points.isEmpty) _settle(Offset.zero);
        return false;
      }
      _setPage(simulation.x(t));
      return true;
    });
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
    final item = _active;
    _f0 = _toActive(focal);
    _span0 = span;
    _lastAngle = angle;
    _turn = 0;
    _rawScale0 = _unresist(item.scale);
    _s0 = item.scale;
    _r0 = item.rotation;
    _o0 = item.offset;
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
    final span = _span;
    final angle = _angle;
    if (_span0 <= 1) {
      _rebaseMulti(_focal, span, angle);
      return;
    }
    _turn += _angleDelta(angle, _lastAngle);
    _lastAngle = angle;
    if (_rotating == null) {
      if (!widget.enableRotation) {
        _rotating = false;
      } else if (_turn.abs() * _span0 > _slop) {
        // 旋转从判定这一刻开始，不补回阈值内的角度，避免跳变。
        _rotating = true;
        _rebaseMulti(_focal, span, angle);
      } else if ((span - _span0).abs() > _slop) {
        _rotating = false;
      }
    }
    final scale = _resist(_rawScale0 * span / _span0);
    final rotation = _rotating == true ? _r0 + _turn : _r0;
    final c = _center;
    final local = _rotate(_f0 - c - _o0, -_r0) / _s0;
    _setTransform(scale, rotation, _toActive(_focal) - c - _rotate(local, rotation) * scale);
  }

  // 单指位移分配：翻页偏离时先收回，其次平移当前项，到边缘后的余量进入翻页。
  // 一旦翻页偏离当前项就只做横向移动，纵向位移不再平移图片，收回到当前项后才恢复自由平移。
  void _panBy(Offset delta) {
    final stride = _stride;
    if (stride <= 0) return;
    final item = _active;
    final range = _range(item.scale, item.rotation);
    final displacedBefore = (_page - _anchor).abs() > 1e-6;
    var rest = delta.dx;
    var x = item.offset.dx;
    final displacement = (_page - _anchor) * stride;
    if (displacement.abs() > 1e-6 && rest != 0 && (rest > 0) == (displacement > 0)) {
      final closing = rest.sign * math.min(rest.abs(), displacement.abs());
      final next = _page - closing / stride;
      _setPage(((next - _anchor) * stride).abs() < 0.01 ? _anchor.toDouble() : next);
      rest -= closing;
    }
    if (rest != 0 && (_page - _anchor).abs() <= 1e-6) {
      final (next, overflow) = _axisPan(x, rest, range.dx);
      x = next;
      rest = overflow;
    }
    final paging = displacedBefore || rest.abs() > 1e-6;
    final y = paging ? item.offset.dy : _axisPan(item.offset.dy, delta.dy, range.dy).$1;
    if (x != item.offset.dx || y != item.offset.dy) _setTransform(item.scale, item.rotation, Offset(x, y));
    if (rest.abs() > 1e-6) _movePage(-rest / stride);
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
    // 捏合时启动的翻页吸附仍在进行，让它自然完成。
    if (_frame != null) return;
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
    _animateTransform(scale, 0, _clampOffset((_toActive(position) - _center) * (1 - scale), scale, 0));
  }

  void pointerSignal(PointerSignalEvent event) {
    if (!widget.enableWheelZoom || event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      final factor = math.exp(-scroll.scrollDelta.dy * widget.wheelZoomSensitivity);
      _stopMotion();
      _scaleAround(scroll.localPosition, (_active.scale * factor).clamp(1.0, widget.maxScale));
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
    if ((ratio - 1).abs() > 1e-6) {
      _scaleAround(event.localPosition, (_active.scale * ratio).clamp(1.0, widget.maxScale));
    }
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

  // 松手：旋转吸附到最近直角、缩放与平移收回范围；翻页未归位时按速度或过半决定目标并弹簧吸附；否则按速度做惯性平移。
  void _settle(Offset velocity) {
    if (size.isEmpty || _count <= 0) return;
    final item = _active;
    final targetScale = item.scale.clamp(1.0, widget.maxScale);
    final targetRotation = _snapRotation(item.rotation);
    final targetOffset = _clampOffset(item.offset * (targetScale / item.scale), targetScale, targetRotation);
    final needTransform =
        (targetScale - item.scale).abs() > 1e-4 ||
        _angleDelta(targetRotation, item.rotation).abs() > 1e-4 ||
        (targetOffset - item.offset).distance > 0.5;
    final displacement = _page - _anchor;
    if (displacement.abs() > 1e-4) {
      final pageVelocity = -velocity.dx / _stride;
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
          ? _transformFrame(targetScale, targetRotation, targetOffset)
          : null;
      _startMotion((t) {
        final pageDone = simulation.isDone(t);
        if (!pageDone) _setPage(simulation.x(t));
        final transformRunning = transform?.call(t) ?? false;
        if (pageDone && !transformRunning) {
          _settleAt(target);
          return false;
        }
        return true;
      });
      return;
    }
    if (needTransform) {
      _animateTransform(targetScale, targetRotation, targetOffset);
      return;
    }
    if (_canPan && velocity.distance > kMinFlingVelocity) {
      final x = FrictionSimulation(0.135, item.offset.dx, velocity.dx);
      final y = FrictionSimulation(0.135, item.offset.dy, velocity.dy);
      _startMotion((t) {
        _setTransform(item.scale, item.rotation, _clampOffset(Offset(x.x(t), y.x(t)), item.scale, item.rotation));
        return !(x.isDone(t) && y.isDone(t));
      });
    }
  }

  bool Function(double seconds) _transformFrame(double scale, double rotation, Offset offset) {
    final item = _active;
    final fromScale = item.scale;
    final fromRotation = item.rotation;
    final fromOffset = item.offset;
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
    _settleAt(index.clamp(0, _count - 1));
    _items.clear();
    changed.notify();
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
      if (k < 1) {
        _setPage(from + (target - from) * k);
        return true;
      }
      _settleAt(target);
      return false;
    });
    return completer.future;
  }

  void transformTo({double? scale, double? rotation, required bool animate}) {
    final item = _active;
    final targetScale = (scale ?? item.scale).clamp(1.0, widget.maxScale);
    final targetRotation = rotation ?? item.rotation;
    final offset = _clampOffset(item.offset * (targetScale / item.scale), targetScale, targetRotation);
    if (animate) {
      _animateTransform(targetScale, targetRotation, offset);
    } else {
      _stopMotion();
      _setTransform(targetScale, targetRotation, offset);
    }
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
  String get debugDescription => 'ElPreviewView';
}
