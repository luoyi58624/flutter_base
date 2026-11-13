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
  bool _inMotion = false;
  double _lastDirection = 0;
  double _flingDirection = 0;
  Timer? _wheelIdle;
  bool _disposed = false;

  /// 展开为零，收起为 [extent]。
  ValueListenable<double> get offset => _offset.view;

  /// 让频道 [index] 内的 ElScrollView 先把位移交给页头，并在滚动停稳后吸附。
  Widget bindPage(int index, {required Widget child}) => ElNestedScroll(
    parent: _interceptors.putIfAbsent(index, () => _BibiPageInterceptor(this, index)),
    child: NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        // 惯性跑完才结算，页头跟随整段惯性后再吸附到最近的端点。
        if (notification.depth == 0) _motionSettled(index)?.ignore();
        return false;
      },
      child: child,
    ),
  );

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
    _inMotion = false;
    _lastDirection = 0;
    _flingDirection = 0;
    _wheelIdle?.cancel();
    _wheelIdle = null;
  }

  void _beginMotion(int index) {
    if (!_isActive(index)) return;
    _clearMotion();
    _inMotion = true;
  }

  bool _canConsume(int index, double delta) {
    if (!_isActive(index)) return false;
    final value = _offset.value;
    return delta > 0 ? value < extent : value > 0;
  }

  double _consume(int index, double delta, ElScrollDeltaSource source) {
    if (!_isActive(index) || (source != .pointerScroll && !_inMotion)) return 0;
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

  void _release(int index, double velocity) {
    // 松手速度是手指方向，页头方向与之相反；惯性帧未推动页头时按它决定吸附方向。
    if (_isActive(index) && _inMotion && _flingDirection == 0) _flingDirection = -velocity.sign;
  }

  Future<void>? _motionSettled(int index) {
    if (!_isActive(index) || !_inMotion) return null;
    final moved = _lastDirection != 0;
    final direction = _flingDirection;
    _inMotion = false;
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

final class _BibiPageInterceptor extends ElNestedScrollParent {
  const _BibiPageInterceptor(this.motion, this.index);

  final BibiHeaderMotion motion;
  final int index;

  @override
  Axis? get nestedScrollAxis => .vertical;

  @override
  void onNestedScrollStart(Axis axis, ElScrollDeltaSource source) => motion._beginMotion(index);

  @override
  double onNestedPreScroll(double delta, ElScrollDeltaSource source) => motion._consume(index, delta, source);

  @override
  bool canConsumeNestedPreScroll(double delta, ElScrollDeltaSource source) => motion._canConsume(index, delta);

  @override
  double onNestedPreFling(double velocity) {
    motion._release(index, velocity);
    return velocity;
  }

  @override
  void onNestedScrollCancel() {
    if (motion._isActive(index) && motion._inMotion) motion._cancelMotion();
  }
}
