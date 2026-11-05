import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../dimension.dart';
import '../internal/field_spec.dart';
import '../style.dart';

/// 单字段动画状态机。
///
/// 给定 from / to / duration / curve / delay，按 elapsed 计算当前插值。
/// 真正的 tick 驱动由 [StyleAnimationDriver] 提供。
class FieldAnimation {
  /// 创建。
  FieldAnimation({
    required this.field,
    required this.from,
    required this.to,
    required this.duration,
    this.curve = Curves.linear,
    this.delay = Duration.zero,
    this.isThemeMode = false,
  });

  /// 字段。
  final ElTransitionField field;

  /// 起点声明，来自已提交的归一化样式；长度字段的 null 表示 auto。
  ///
  /// `currentValue()` 在 `isComplete` 时仍返回 `to`（保留 null 语义让 cascade
  /// 收尾时正确回到"未声明"）。中间帧只用 [_autoLengthSnapshot] 补齐 null，
  /// 显式端点始终沿用 [from] / [to]。
  final Object? from;

  /// 终点值（同 [from] 注释）。
  final Object? to;

  /// 是否由 ElThemeMode 强制启动，供后代继承同一帧的主题采样。
  final bool isThemeMode;

  /// 时长。
  final Duration duration;

  /// 缓动。
  final Curve curve;

  /// 延迟。
  final Duration delay;

  /// auto 长度的一次真实 used-size，等价 CSS calc-size 的 null↔px 连续过渡。
  ElDimension? _autoLengthSnapshot;

  /// 只把声明为 null（auto）的 lerp 端点替换为一次性布局快照。
  ///
  /// 真实 layout 可延后补入；显式端点与原始声明不变，完成态仍返回原始 [to]。
  void replaceNullLerpEndpoint(ElDimension snapshot) {
    _autoLengthSnapshot = snapshot;
  }

  /// 累计已过时间。
  Duration _elapsed = Duration.zero;

  /// 当前进度 [0, 1]。
  double get progress {
    // delay 期内仍要回到 `curve.transform(0)`——某些 curve 在 0 点的 transform
    // 不等于 0（例：spring / overshoot curve），直接返回 0 会让 delay 结束瞬间
    // 视觉跳变到 curve(0)。CSS transition-delay 期内的 sample 应等价 curve(0)。
    if (_elapsed <= delay) return curve.transform(0.0);
    final after = _elapsed - delay;
    if (after >= duration) return 1;
    final t = after.inMicroseconds / duration.inMicroseconds;
    return curve.transform(t.clamp(0.0, 1.0));
  }

  /// 是否完成。
  bool get isComplete => _elapsed >= delay + duration;

  /// 推进 [dt] 时长。
  void advance(Duration dt) {
    _elapsed += dt;
    if (_elapsed > delay + duration) {
      _elapsed = delay + duration;
    }
  }

  /// 当前插值值。
  Object? currentValue() {
    if (isComplete) return to;
    return fieldSpecOf(field).lerp(from ?? _autoLengthSnapshot, to ?? _autoLengthSnapshot, progress);
  }

  @override
  String toString() => 'FieldAnimation(${field.name}, progress=$progress)';

  /// 用于测试观察。
  @visibleForTesting
  Duration get debugElapsed => _elapsed;
}
