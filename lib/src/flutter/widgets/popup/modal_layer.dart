import 'dart:math' as math;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderEditable, RenderSemanticsAnnotations;
import 'package:flutter/widgets.dart';

import '../../views/view/render/render_view.dart' show ElRenderView;

/// 品牌组合模态外观的骨架：铺满视口的遮罩，加按停靠方向排布的面板。
///
/// 遮罩和面板共用同一进度；停靠在边缘且提供 [onDismiss] 时，触屏可从面板或遮罩沿退场方向拖动关闭，
/// 遮罩随拖动距离逐帧变淡。遮罩只负责绘制，点击由路由的 ModalBarrier 接收。
@internal
class ModalLayer extends StatefulWidget {
  /// 尺寸、遮罩和进退场画面由品牌提供。
  const ModalLayer({
    super.key,
    required this.animation,
    required this.alignment,
    required this.child,
    this.curve = Curves.linear,
    this.margin = 0,
    this.constraints,
    this.barrier,
    this.transition,
    this.onDismiss,
  });

  /// ElOverlayTransition 提供的进退场控制器。
  final AnimationController animation;

  /// 面板在视口中的停靠位置，非居中时决定拖动方向。
  final Alignment alignment;

  /// 面板内容。
  final Widget child;

  /// 进度曲线，遮罩和面板共用。
  final Curve curve;

  /// 面板与视口边缘的最小留白，与安全区取较大值，底部另加键盘高度。
  final double margin;

  /// 按可用空间给出面板约束。
  final BoxConstraints Function(BoxConstraints available)? constraints;

  /// 按可见度（进度乘以拖动剩余比例）绘制遮罩。
  final Widget Function(BuildContext context, double visible)? barrier;

  /// 按进度包装面板，实现进退场画面。
  final Widget Function(BuildContext context, double progress, Widget panel)? transition;

  /// 拖动越过阈值后关闭，为空时不支持拖动。
  final VoidCallback? onDismiss;

  @override
  State<ModalLayer> createState() => _ModalLayerState();
}

class _ModalLayerState extends State<ModalLayer> with SingleTickerProviderStateMixin {
  final _panelKey = GlobalKey();
  final _scrollables = <ScrollableState>{};
  final _offset = ValueNotifier(0.0);
  late final _settle = AnimationController(vsync: this);
  _ModalSwipeRecognizer? _swipe;

  Axis get _axis => widget.alignment.x != 0 ? .horizontal : .vertical;

  double get _sign => widget.alignment.x + widget.alignment.y;

  bool get _draggable => widget.onDismiss != null && widget.alignment != Alignment.center;

  RenderBox? get _panel => _panelKey.currentContext?.findRenderObject() as RenderBox?;

  double get _extent => switch (_panel?.size) {
    Size(:final width, :final height) => _axis == .horizontal ? width : height,
    null => 0,
  };

  double get _distance {
    final extent = _extent;
    return extent > 0 ? (_offset.value / extent).clamp(0.0, 1.0) : 0;
  }

  @override
  void initState() {
    super.initState();
    _syncSwipe();
  }

  @override
  void didUpdateWidget(ModalLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alignment != widget.alignment || (oldWidget.onDismiss == null) != (widget.onDismiss == null)) {
      _syncSwipe();
    }
  }

  void _syncSwipe() {
    _swipe?.dispose();
    _swipe = _draggable
        ? _ModalSwipeRecognizer(axis: _axis, sign: _sign, canStart: _canStart, onMove: _move, onEnd: _end)
        : null;
  }

  bool _canStart(PointerDownEvent event) {
    final panel = _panel;
    if (!widget.animation.isCompleted || _settle.isAnimating || panel == null || !panel.hasSize) return false;
    // 遮罩区直接登记手势，面板内起手才检查输入和滚动控件。
    final position = panel.globalToLocal(event.position);
    if (!(Offset.zero & panel.size).contains(position)) return true;
    final result = BoxHitTestResult();
    panel.hitTest(result, position: position);
    final targets = <HitTestTarget>{};
    for (final entry in result.path) {
      final target = entry.target;
      targets.add(target);
      if (target is RenderEditable) return false;
      final semantics = switch (target) {
        ElRenderView() => target.semantics?.properties,
        RenderSemanticsAnnotations() => target.properties,
        _ => null,
      };
      if (semantics?.textField == true || semantics?.slider == true) return false;
    }
    _scrollables.removeWhere((scrollable) => !scrollable.mounted);
    for (final scrollable in _scrollables) {
      if (!targets.contains(scrollable.notificationContext?.findRenderObject())) continue;
      final position = scrollable.position;
      if (position is FixedExtentMetrics) return false;
      if (position.axis != _axis || !position.hasContentDimensions) continue;
      final reversed = axisDirectionIsReversed(position.axisDirection);
      final towardsMin = (_sign > 0) != reversed;
      if (towardsMin
          ? position.pixels > position.minScrollExtent + 1
          : position.pixels < position.maxScrollExtent - 1) {
        return false;
      }
    }
    return true;
  }

  bool _trackScroll(ScrollMetricsNotification notification) {
    final scrollable = Scrollable.maybeOf(notification.context);
    if (scrollable != null) _scrollables.add(scrollable);
    return false;
  }

  void _move(double offset) => _offset.value = offset;

  Future<void> _end(double velocity, {bool cancelled = false}) async {
    final from = _offset.value;
    final extent = _extent;
    if (extent <= 0) {
      _offset.value = 0;
      return;
    }
    final dismiss =
        !cancelled && from >= 12 && velocity >= -300 && (from >= math.min(88, extent * .28) || velocity >= 550);
    final to = dismiss ? math.max(from, extent + 32) : 0.0;
    if (to == from && !dismiss) return;
    // 松手速度决定回弹曲线起点，收尾沿用 Web 面板的阻尼曲线。
    final slope = to == from ? 0.0 : (.174 * velocity * .22 / (to - from)).clamp(-.35, .9).toDouble();
    final curve = Cubic(.174, slope, .185, 1);
    void tick() => _offset.value = math.max(0.0, from + (to - from) * curve.transform(_settle.value));
    _settle.addListener(tick);
    try {
      final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _settle.duration = reduced ? Duration.zero : const Duration(milliseconds: 220);
      await _settle.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) _settle.removeListener(tick);
    }
    if (!mounted) return;
    if (dismiss) {
      // 面板已经拖出视口，直接结束进度，关闭时无需再播放退场。
      widget.animation.value = 0;
      widget.onDismiss?.call();
    } else {
      _offset.value = 0;
    }
  }

  @override
  void dispose() {
    _swipe?.dispose();
    _settle.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final margin = widget.margin;
    // 面板与遮罩共用根视口，屏幕边缘同时保留留白和系统安全区。
    final frame = EdgeInsets.fromLTRB(
      math.max(margin, padding.left),
      math.max(margin, padding.top),
      math.max(margin, padding.right),
      insets.bottom + math.max(margin, padding.bottom),
    );
    final motion = Listenable.merge([widget.animation, _offset]);
    double progress() => widget.curve.transform(widget.animation.value);
    final panel = AnimatedBuilder(
      animation: _offset,
      child: NotificationListener<ScrollMetricsNotification>(onNotification: _trackScroll, child: widget.child),
      builder: (context, child) {
        final offset = _sign * _offset.value;
        return Transform.translate(
          key: _panelKey,
          offset: _axis == .horizontal ? Offset(offset, 0) : Offset(0, offset),
          child: child,
        );
      },
    );
    final barrier = widget.barrier;
    final transition = widget.transition;
    return Stack(
      fit: .expand,
      children: [
        if (barrier != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: motion,
              builder: (context, _) => barrier(context, progress() * (1 - _distance)),
            ),
          ),
        Padding(
          padding: frame,
          child: LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: widget.alignment,
              child: AnimatedBuilder(
                animation: widget.animation,
                child: ConstrainedBox(constraints: widget.constraints?.call(constraints) ?? const .new(), child: panel),
                builder: (context, child) => transition == null ? child! : transition(context, progress(), child!),
              ),
            ),
          ),
        ),
        // 先于正文滚动器登记手势，遮罩空白的点击仍交给下层 ModalBarrier。
        if (_swipe case final swipe?)
          Positioned.fill(
            child: Listener(behavior: .translucent, onPointerDown: swipe.addPointer),
          ),
      ],
    );
  }
}

// 起手方向和滚动边界决定是否进入竞技场，正文能滚动时由它消费整次手势。
class _ModalSwipeRecognizer extends OneSequenceGestureRecognizer {
  _ModalSwipeRecognizer({
    required this.axis,
    required this.sign,
    required this.canStart,
    required this.onMove,
    required this.onEnd,
  }) : super(supportedDevices: const {PointerDeviceKind.touch});

  final Axis axis;
  final double sign;
  final bool Function(PointerDownEvent event) canStart;
  final ValueChanged<double> onMove;
  final void Function(double velocity, {bool cancelled}) onEnd;
  int? _pointer;
  late Offset _origin;
  late VelocityTracker _velocity;
  late Duration _lastMovedAt;
  double _distance = 0;
  bool _active = false;
  bool _accepted = false;

  @override
  String get debugDescription => '模态面板滑动';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) {
      _finish(cancelled: true);
      return;
    }
    if (!canStart(event)) return;
    _pointer = event.pointer;
    _origin = event.position;
    _distance = 0;
    _lastMovedAt = event.timeStamp;
    _velocity = VelocityTracker.withKind(event.kind)..addPosition(event.timeStamp, event.position);
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      final moved = event.position - _origin;
      final main = axis == .horizontal ? moved.dx : moved.dy;
      final cross = axis == .horizontal ? moved.dy : moved.dx;
      _distance = math.max(0.0, main * sign);
      if (!event.synthesized) {
        _lastMovedAt = event.timeStamp;
        _velocity.addPosition(event.timeStamp, event.position);
      }
      if (!_active) {
        if (math.max(main.abs(), cross.abs()) < 6) return;
        if (main * sign <= 0 || main.abs() < cross.abs() * 1.15) {
          _finish(cancelled: true);
          return;
        }
        _active = true;
        if (!_accepted) {
          resolve(GestureDisposition.accepted);
          return;
        }
      }
      if (_accepted) onMove(_distance);
    } else if (event is PointerUpEvent) {
      _finish(cancelled: false, velocity: _releaseVelocity(event));
    } else if (event is PointerCancelEvent) {
      _finish(cancelled: true);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer) return;
    _accepted = true;
    if (_active) onMove(_distance);
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) _finish(cancelled: true);
  }

  double _releaseVelocity(PointerUpEvent event) {
    if (!_active || event.timeStamp - _lastMovedAt > const Duration(milliseconds: 100)) return 0;
    final estimate = _velocity.getVelocityEstimate();
    if (estimate == null) return 0;
    final elapsed = estimate.duration;
    // Flutter 至少需要三个采样点；稀疏的短促轻扫用采样区间的均速。
    final speed = estimate.pixelsPerSecond == Offset.zero && elapsed > Duration.zero
        ? estimate.offset * (Duration.microsecondsPerSecond / elapsed.inMicroseconds)
        : estimate.pixelsPerSecond;
    return (axis == .horizontal ? speed.dx : speed.dy) * sign;
  }

  void _finish({required bool cancelled, double velocity = 0}) {
    final pointer = _pointer;
    if (pointer == null) return;
    _pointer = null;
    final active = _active && _accepted;
    _active = false;
    _accepted = false;
    resolve(GestureDisposition.rejected);
    stopTrackingPointer(pointer);
    if (active) onEnd(velocity, cancelled: cancelled);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
