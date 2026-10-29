import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// 核心视口挂给控制器的动画执行通道。
typedef TabAnimationDelegate = Future<void> Function(int index, {Duration? duration, Curve? curve});

/// 控制 `ElTabView` 的连续页位置与编程切换。
class ElTabController extends ChangeNotifier {
  /// 创建指定页数的视口控制器。
  ElTabController({required int length, int initialIndex = 0})
    : assert(length >= 0),
      _length = length,
      _index = _clampIndex(initialIndex, length),
      _previousIndex = _clampIndex(initialIndex, length),
      _position = _clampIndex(initialIndex, length).toDouble();

  int _length;
  int _index;
  int _previousIndex;
  double _position;
  bool _isDragging = false;
  bool _isAnimating = false;
  TabAnimationDelegate? _animateDelegate;
  void Function(int index)? _jumpDelegate;

  /// 当前内容页数。
  int get length => _length;

  /// 当前落定或正在前往的页下标。
  int get index => _index;

  /// 上一次落定的页下标。
  int get previousIndex => _previousIndex;

  /// 连续页位置，拖拽或动画期间可包含小数和物理越界量。
  double get position => _position;

  /// 相对当前页的连续偏移，范围钳制在 -1 到 1。
  double get offset => length <= 0 ? 0.0 : (_position - _index).clamp(-1.0, 1.0);

  /// 视口当前是否由用户拖拽。
  bool get isDragging => _isDragging;

  /// 视口当前是否正在执行停靠或编程动画。
  bool get isAnimating => _isAnimating;

  /// 立即切换到指定页。
  void jumpTo(int index) {
    final target = _normalizeIndex(index);
    _jumpDelegate?.call(target);
    _setSettledIndex(target, notify: true);
  }

  /// 动画切换到指定页。
  Future<void> animateTo(int index, {Duration? duration, Curve? curve}) {
    final target = _normalizeIndex(index);
    final delegate = _animateDelegate;
    if (delegate == null) {
      jumpTo(target);
      return Future<void>.value();
    }
    return delegate(target, duration: duration, curve: curve);
  }

  /// 动画切换到下一页。
  Future<void> next({Duration? duration, Curve? curve}) {
    return animateTo(_index + 1, duration: duration, curve: curve);
  }

  /// 动画切换到上一页。
  Future<void> previous({Duration? duration, Curve? curve}) {
    return animateTo(_index - 1, duration: duration, curve: curve);
  }

  @override
  void dispose() {
    _animateDelegate = null;
    _jumpDelegate = null;
    super.dispose();
  }

  /// 在测试中调整控制器维护的页数。
  @protected
  @visibleForTesting
  void debugSetLength(int value) {
    _setLength(value);
  }

  /// 在测试中写入连续页位置以验证跟手消费者。
  @visibleForTesting
  void debugSetPosition(double value) {
    setPosition(value);
  }

  /// 由 `ElTabView` 挂接动画与瞬时切换执行通道。
  @internal
  void attach({required TabAnimationDelegate animateTo, required void Function(int index) jumpTo}) {
    _animateDelegate = animateTo;
    _jumpDelegate = jumpTo;
  }

  /// 由 `ElTabView` 卸载当前执行通道。
  @internal
  void detach({required TabAnimationDelegate animateTo, required void Function(int index) jumpTo}) {
    if (identical(_animateDelegate, animateTo)) {
      _animateDelegate = null;
    }
    if (identical(_jumpDelegate, jumpTo)) {
      _jumpDelegate = null;
    }
  }

  /// 由 `ElTabView` 同步当前内容页数。
  @internal
  void setLength(int value) {
    _setLength(value);
  }

  /// 写入连续页位置。
  ///
  /// **不 clamp 到 [0, length−1]**：越界拉伸（bouncing 橡皮筋）本身就要靠
  /// 界外的 position 表达。曾经这里 clamp，导致 `ElTabView` 算出的越界量
  /// 写进来就被吃掉——无论环境物理怎么设都看不到拉伸。到边要不要止住由
  /// physics 的 `applyBoundaryConditions` 决定，不由数据层兜。
  ///
  /// [index] / [settleAt] 仍恒被夹在合法页范围内，越界只影响 position。
  @internal
  void setPosition(double value) {
    if (_position == value || value.isNaN) return;
    _position = value;
    notifyListeners();
  }

  /// 根据连续位置更新当前目标页下标。
  @internal
  void setIndexFromPosition(int value) {
    final target = _normalizeIndex(value);
    if (_index == target) return;
    _previousIndex = _index;
    _index = target;
    notifyListeners();
  }

  /// 更新视口是否正由用户拖拽。
  @internal
  void setDragging(bool value) {
    if (_isDragging == value) return;
    _isDragging = value;
    notifyListeners();
  }

  /// 更新视口是否正在执行动画。
  @internal
  void setAnimating(bool value) {
    if (_isAnimating == value) return;
    _isAnimating = value;
    notifyListeners();
  }

  /// 将连续位置与当前页统一落定到指定下标。
  @internal
  void settleAt(int value) {
    _setSettledIndex(_normalizeIndex(value), notify: true);
  }

  int _normalizeIndex(int value) => _clampIndex(value, _length);

  void _setLength(int value) {
    assert(value >= 0);
    if (_length == value) return;
    _length = value;
    final nextIndex = _clampIndex(_index, _length);
    _index = nextIndex;
    _previousIndex = _clampIndex(_previousIndex, _length);
    _position = _clampPosition(_position, _length);
    if (_length == 0) {
      _position = 0.0;
    } else if (_position > _length - 1) {
      _position = (_length - 1).toDouble();
    }
    notifyListeners();
  }

  void _setSettledIndex(int value, {required bool notify}) {
    final target = _normalizeIndex(value);
    final changed = _index != target || _position != target.toDouble();
    _previousIndex = _index;
    _index = target;
    _position = target.toDouble();
    if (changed && notify) {
      notifyListeners();
    }
  }

  static int _clampIndex(int value, int length) {
    if (length <= 0) return 0;
    return value.clamp(0, length - 1);
  }

  static double _clampPosition(double value, int length) {
    if (length <= 0) return 0.0;
    return value.clamp(0.0, (length - 1).toDouble());
  }
}
