import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, precisionErrorTolerance;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 在频道之间共享页头行程，每次输入只由当前频道修改。
final class BibiHeaderMotion {
  /// 创建由页面持有的页头运动状态。
  BibiHeaderMotion(TickerProvider vsync, {this.extent = 58})
    : assert(extent > 0 && extent < double.infinity),
      _offset = AnimationController(vsync: vsync, upperBound: extent);

  /// 搜索栏完全收起时的偏移。
  final double extent;
  final AnimationController _offset;
  final _interceptors = <int, _BibiPageInterceptor>{};
  int _activePage = 0;
  int? _motionId;
  double _lastDirection = 0;
  double _flingDirection = 0;
  Timer? _wheelIdle;
  bool _disposed = false;

  /// 展开为零，收起为 [extent]。
  ValueListenable<double> get offset => _offset.view;

  /// 为每个频道提供稳定的位移拦截器。
  ElScrollDeltaInterceptor forPage(int index) =>
      _interceptors.putIfAbsent(index, () => _BibiPageInterceptor(this, index));

  /// 将惯性行程和运动终态绑定到频道内的常驻成员。
  Widget bindPage(int index, {required Widget child}) => _BibiMotionBinding(motion: this, index: index, child: child);

  /// 切页时退役旧频道的输入，防止它继续带动共享页头。
  void setActivePage(int index) {
    if (_activePage == index) return;
    _activePage = index;
    _cancelMotion();
  }

  /// 回到首页顶部时立即展开。
  void reset() {
    _clearMotion();
    _offset.value = 0;
  }

  /// 结束页面持有的动画和滚轮计时。
  void dispose() {
    _disposed = true;
    _clearMotion();
    _offset.dispose();
  }

  bool _isActive(int index) => !_disposed && index == _activePage;

  void _clearMotion() {
    _motionId = null;
    _lastDirection = 0;
    _flingDirection = 0;
    _wheelIdle?.cancel();
    _wheelIdle = null;
  }

  void _beginMotion(int index, int motionId) {
    if (!_isActive(index)) return;
    _clearMotion();
    _motionId = motionId;
  }

  double _consume(int index, double delta, ElScrollDeltaSource source) {
    if (!_isActive(index) || (source != .pointerScroll && _motionId == null)) return 0;
    // 滚轮使用像素方向，手指拖拽和惯性使用手指方向。
    final scale = source == .pointerScroll ? 1.0 : -1.0;
    final previous = _offset.value;
    final movement = (delta * scale).clamp(-previous, extent - previous);
    if (movement.abs() <= precisionErrorTolerance) return 0;
    if (source == .pointerScroll) {
      _wheelIdle?.cancel();
      _wheelIdle = Timer(Duration(milliseconds: 100), () => _settle(movement.sign)?.ignore());
    } else {
      _lastDirection = movement.sign;
      if (source == .fling) _flingDirection = movement.sign;
    }
    // 只有实际移动了页头的输入才会中断上一段吸附。
    _offset.value = (previous + movement).clamp(0.0, extent);
    return movement * scale;
  }

  Future<void>? _motionSettled(int index, ElScrollSessionDetails details) {
    if (!_isActive(index) || details.motionId != _motionId) return null;
    final moved = _lastDirection != 0;
    final direction = _flingDirection != 0 ? _flingDirection : (details.releaseVelocity ?? 0.0).sign;
    _motionId = null;
    _lastDirection = 0;
    _flingDirection = 0;
    // 速度为零的真实拖拽按中点吸附，短甩则沿惯性原方向补足未完成的行程。
    return moved ? _settle(direction) : null;
  }

  void _cancelMotion() {
    final direction = _lastDirection;
    _clearMotion();
    if (direction != 0) _settle(direction)?.ignore();
  }

  Future<void>? _settle(double direction) {
    final value = _offset.value;
    if (_disposed || _offset.isAnimating || value <= 0 || value >= extent) return null;
    final target = direction > 0 || (direction == 0 && value >= extent / 2) ? extent : 0.0;
    return _offset
        .animateTo(
          target,
          duration: Duration(milliseconds: 180),
          curve: direction == 0 ? Curves.decelerate : Curves.easeInOutSine,
        )
        .orCancel;
  }
}

final class _BibiPageInterceptor extends ElScrollDeltaInterceptor {
  const _BibiPageInterceptor(this.motion, this.index);

  final BibiHeaderMotion motion;
  final int index;

  @override
  double interceptScrollDelta(double delta, ElScrollDeltaSource source) => motion._consume(index, delta, source);
}

class _BibiMotionBinding extends StatefulWidget {
  const _BibiMotionBinding({required this.motion, required this.index, required this.child});

  final BibiHeaderMotion motion;
  final int index;
  final Widget child;

  @override
  State<_BibiMotionBinding> createState() => _BibiMotionBindingState();
}

class _BibiMotionBindingState extends State<_BibiMotionBinding> with ElScrollMixin<_BibiMotionBinding> {
  @override
  bool get observesScrollUpdates => false;

  @override
  bool get observesScrollMetrics => false;

  @override
  Object get scrollInputSlot => #bibiHeader;

  // 宿主惯性用页头与正文的总行程，正文到边界时仍可继续推进页头。
  late final _track = ElScrollEffectTrack(
    effectId: #bibiHeader,
    minValue: 0,
    maxValue: widget.motion.extent,
    pixelsPerUnit: 1,
    readValue: () => widget.motion.offset.value,
    updateValue: (value) => widget.motion._offset.value = value,
  );

  @override
  Iterable<ElScrollEffectTrack> get scrollEffectTracks => [_track];

  @override
  void onInputStart(ElScrollSessionDetails details) {
    super.onInputStart(details);
    widget.motion._beginMotion(widget.index, details.motionId);
  }

  @override
  Future<void>? onScrollSettle(ElScrollSessionDetails details) {
    final previous = super.onScrollSettle(details);
    return widget.motion._motionSettled(widget.index, details) ?? previous;
  }

  @override
  void onMotionCancelled(ElScrollSessionDetails details) {
    super.onMotionCancelled(details);
    final motion = widget.motion;
    if (motion._isActive(widget.index) && details.motionId == motion._motionId) motion._cancelMotion();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
