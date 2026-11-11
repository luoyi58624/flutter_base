import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import '../../../utils/platform/index.dart' show ElPlatform;

/// 鼠标滚轮平滑滚动算法（独立可配置类，形态对齐滚动条 / 下拉刷新）。
///
/// 编排恒在 `SmoothPointerScrollController`（目标累积、retarget、
/// Activity/Ticker 生命周期、滚轮链协作、触控板直滚判定、burst 连击记账），
/// 算法只做三项数值决策——这正是不同平台平滑滚动手感的全部差异面：
///
/// 1. [stepForEvent]：单次滚轮事件折算成多大的动画步长（加速语义在此）；
/// 2. [segmentDuration]：新目标段走多久（速度接续的时长收缩在此）；
/// 3. [curveFor]：段内缓动形状（retarget 速度连续性在此）。
///
/// 滚动容器默认自动接入，无需额外配置；也可通过 `smoothScroll:` 单独指定。
/// 未传入或使用 `$absent` 时由
/// [resolveDefaultSmoothScroll] 按平台解析（Windows 客户端
/// [ElWindowsSmoothScroll]、Windows Web [ElChromiumSmoothScroll]，其余直滚）；
/// 显式 null 关闭。配置变化对进行中的动画段不生效，下一段生效。
///
/// 内置算法：
/// - [ElWindowsSmoothScroll]：Windows 10 口径，长尾 ease-out + 速度接续 +
///   连击倍率加速；
/// - [ElChromiumSmoothScroll]：Chromium 口径，原始步长、动态时长和速度接续曲线。
///
/// 两者的步长/增量类手感参数均为构造参数，可通过
/// 滚动容器的 `smoothScroll:` 参数覆写。
/// 默认解析见 [resolveDefaultSmoothScroll]。
abstract class ElSmoothScroll {
  const ElSmoothScroll();

  /// 单次滚轮事件 → 动画步长（带符号，与 [rawDelta] 同向）。
  ///
  /// [burstTicks] 为编排层记账的同向连击计数（90ms 窗口内递增，变向/断流
  /// 归零）；是否消费它做加速属算法语义，线性算法可忽略。
  double stepForEvent(double rawDelta, int burstTicks);

  /// 新动画段的时长。
  ///
  /// [delta] = 新目标与当前动画值的差（带符号）；[velocity] = 当前动画速度
  /// （px/s，非动画期为 0）。恒返回非负时长；返回 [Duration.zero] 表示
  /// 瞬时到位（编排层直接落点结算）。
  Duration segmentDuration(double delta, double velocity);

  /// 段内缓动曲线。
  ///
  /// [initialSlope] = retarget 速度接续的归一化初始斜率（首段为 0，已被
  /// 编排层按新段时长归一化）；线性算法可忽略直接返回 [Curves.linear]。
  Curve curveFor(double initialSlope);
}

/// 滚动容器未覆写时使用的平台默认算法。
///
/// Windows 桌面客户端 → [ElWindowsSmoothScroll]；Windows Web →
/// [ElChromiumSmoothScroll]（Chromium/Google 口径）；其余平台 → null（直滚）。
ElSmoothScroll? resolveDefaultSmoothScroll() {
  if (defaultTargetPlatform != TargetPlatform.windows) return null;
  if (ElPlatform.isDesktopClient) return const ElWindowsSmoothScroll();
  if (ElPlatform.isDesktopWeb) return const ElChromiumSmoothScroll();
  return null;
}

/// Windows 10 口径的鼠标滚轮平滑滚动（Windows 默认）。
///
/// 对齐 Win10 原生（DirectManipulation）滚轮手感的三要素：
///
/// 1. **长尾 ease-out**：段基准时长 [duration]（默认 200ms）配 Hermite
///    缓动（冷启动端点斜率 2，恰为 [Curves.decelerate] 的多项式——首帧
///    即峰值速度、长尾轻收）。滚轮间隔小于段时长的慢速连续滚动，下一格
///    到来时上一格尾巴仍在动，不再逐格停顿；
/// 2. **retarget 不刹车**：新段初始斜率取「速度接续」与「踢感基准 2」的
///    较大者、Hermite 单调上界 3 封顶（无过冲），连续滚动速度只升不降，
///    每格仍保留 Win10 标志性的踢一下；
/// 3. **快滚不拖沓**：动画中按当前速度给时长上界（×2.5 松弛，归一化
///    斜率恒 ≤ 2.5 < 3），高速小余量时段自动收短。
///
/// 首格保留平台提供的原始滚动距离；90ms 内同向连击每格提升
/// [accelerationPerTick] 倍率、封顶 [maxAcceleration]，现役目标继续由
/// 编排层叠加。
///
/// ### 调手感速查
///
/// ```dart
/// ElScroll(
///   smoothScroll: const ElWindowsSmoothScroll(
///     duration: Duration(milliseconds: 200),
///     accelerationPerTick: 0.5,
///     maxAcceleration: 4.0,
///   ),
///   children: [],
/// );
/// ```
///
/// - 嫌单格太冲/太肉 → 调 [duration]；
/// - 嫌连滚提速突兀 → 调小 [accelerationPerTick]；
/// - 嫌长滚太快 → 调低 [maxAcceleration]；
/// - 单容器覆盖：通过滚动容器 `smoothScroll:` 直接配置。
class ElWindowsSmoothScroll extends ElSmoothScroll {
  /// 创建 Windows 10 口径的平滑滚动算法；参数不传使用内置默认手感。
  const ElWindowsSmoothScroll({
    this.duration = const Duration(milliseconds: 200),
    this.accelerationPerTick = 0.5,
    this.maxAcceleration = 4.0,
  });

  /// 单格动画段的基准时长（长尾）；慢速连击间隔小于它即获得连续滚动。
  final Duration duration;

  /// 90ms 同向连击每格增加的步长倍率（首格恒 1.0 倍；调大提速更猛，
  /// 调小更从容）。
  final double accelerationPerTick;

  /// 连击加速的步长倍率封顶。
  final double maxAcceleration;

  /// 冷启动/每格踢感的端点斜率基准：2 恰为 decelerate 的端点斜率。
  static const double _baseSlope = 2.0;

  /// Hermite 端点斜率的单调无过冲上界（s₀ > 3 会越过目标再折返）。
  static const double _maxSlope = 3.0;

  /// 速度接续的时长松弛（Chromium 同款）；2.5 < [_maxSlope]，保证时长
  /// 上界生效时归一化斜率不触过冲区。
  static const double _velocityEaseOutFactor = 2.5;

  static const double _epsilon = 0.01;

  @override
  double stepForEvent(double rawDelta, int burstTicks) {
    final multiplier = math.min(1.0 + burstTicks * accelerationPerTick, maxAcceleration);
    return rawDelta * multiplier;
  }

  @override
  Duration segmentDuration(double delta, double velocity) {
    if (delta.abs() <= _epsilon) return Duration.zero;
    var result = duration;
    if (velocity.abs() > _epsilon) {
      final seconds = delta / velocity * _velocityEaseOutFactor;
      // 反向速度不设上界(转向段走满基准时长)。
      if (seconds > 0.0) {
        final bound = Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());
        if (bound < result) result = bound;
      }
    }
    return result;
  }

  @override
  Curve curveFor(double initialSlope) {
    return _HermiteEaseOut(initialSlope.clamp(_baseSlope, _maxSlope).toDouble());
  }
}

/// 端点斜率参数化的 Hermite ease-out：h(t) = t²(3−2t) + s₀·t(1−t)²。
///
/// h(0)=0、h(1)=1、h'(0)=s₀、h'(1)=0；s₀ ∈ [0, 3] 时单调无过冲;
/// s₀=2 时恒等于 [Curves.decelerate] 的多项式 1−(1−t)²。
class _HermiteEaseOut extends Curve {
  const _HermiteEaseOut(this.initialSlope);

  /// 归一化端点初始斜率(由 [ElWindowsSmoothScroll.curveFor] 保证落在
  /// 单调区间内)。
  final double initialSlope;

  @override
  double transformInternal(double t) {
    final u = 1.0 - t;
    return t * t * (3.0 - 2.0 * t) + initialSlope * t * u * u;
  }
}

/// Chromium 原生鼠标滚轮曲线：保留平台步长，按剩余距离决定时长并接续瞬时速度。
///
/// 默认不叠加应用层加速；120px→480px 仅是时长由 200ms→100ms 的插值区间，
/// 不是滚轮步长下限。换段采用 Cubic(0.42, 0.42×初始斜率, 0.58, 1)，
/// 以曲线导数接续速度，并按剩余距离 / 速度 × 2.5 限制时长。
///
/// 对照 Chromium `cc/animation/scroll_offset_animation_curve.cc` 的鼠标滚轮路径；
/// 浏览器输入延迟及合成线程调度仍由各自运行环境负责。
/// [minStep]、[strongDeltaMultiplier]、[maxStep]、[accelerationPerTick]
/// 允许显式定制距离；修改这些参数后不再是原生默认步长。
class ElChromiumSmoothScroll extends ElSmoothScroll {
  /// 创建默认对齐 Chromium 鼠标滚轮距离与曲线的平滑滚动算法。
  const ElChromiumSmoothScroll({
    this.minStep = 0.0,
    this.strongDeltaMultiplier = 1.0,
    this.maxStep = double.infinity,
    this.accelerationPerTick = 0.0,
    this.maxAcceleration = 1.2,
    this.minDuration = const Duration(milliseconds: 100),
    this.maxDuration = const Duration(milliseconds: 200),
  });

  /// 单次滚轮步长下限（逻辑像素），默认 0 保留小步输入。
  final double minStep;

  /// 原始 delta 超出 [minStep] 部分的放大系数。
  final double strongDeltaMultiplier;

  /// 单步步长上限（逻辑像素），默认不截断平台输入。
  final double maxStep;

  /// 90ms 同向连击每 tick 增加的加速比例。
  final double accelerationPerTick;

  /// 额外连击加速比例的封顶，只有 [accelerationPerTick] 非零时生效。
  final double maxAcceleration;

  /// 剩余距离 ≥480px 时的基准时长；速度约束可能进一步缩短它。
  final Duration minDuration;

  /// 剩余距离 ≤120px 时的基准时长，默认 200ms。
  final Duration maxDuration;

  static const double _rampStartPx = 120.0;
  static const double _rampEndPx = 480.0;
  static const double _cubicX1 = 0.42;
  static const double _cubicX2 = 0.58;
  static const double _cubicY2 = 1.0;
  static const double _velocityEaseOutFactor = 2.5;
  static const double _epsilon = 0.01;

  @override
  double stepForEvent(double rawDelta, int burstTicks) {
    final direction = rawDelta.sign;
    final rawStep = rawDelta.abs();
    final step = rawStep <= minStep ? minStep : minStep + (rawStep - minStep) * strongDeltaMultiplier;
    final acceleration = 1.0 + math.min(burstTicks * accelerationPerTick, maxAcceleration);
    return direction * math.min(step * acceleration, maxStep);
  }

  @override
  Duration segmentDuration(double delta, double velocity) {
    var duration = _rampDuration(delta);
    final bound = _velocityDurationBound(delta, velocity);
    if (bound != null && bound < duration) duration = bound;
    return duration;
  }

  @override
  Curve curveFor(double initialSlope) {
    final clampedSlope = initialSlope.clamp(-1000.0, 1000.0).toDouble();
    return _ScrollCubic(_cubicX1, _cubicX1 * clampedSlope, _cubicX2, _cubicY2);
  }

  Duration _rampDuration(double delta) {
    final t = ((delta.abs() - _rampStartPx) / (_rampEndPx - _rampStartPx)).clamp(0.0, 1.0);
    final maxUs = maxDuration.inMicroseconds;
    final minUs = minDuration.inMicroseconds;
    return Duration(microseconds: (maxUs + (minUs - maxUs) * t).round());
  }

  Duration? _velocityDurationBound(double delta, double velocity) {
    if (delta.abs() <= _epsilon) return Duration.zero;
    if (velocity.abs() <= _epsilon) return null;

    final seconds = delta / velocity * _velocityEaseOutFactor;
    if (seconds < 0.0) return null;
    return Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());
  }
}

/// 编排层使用的归一化曲线导数；内置曲线解析求导，自定义 Curve 使用局部差分。
double smoothScrollCurveSlope(Curve curve, double progress) {
  final t = progress.clamp(0.0, 1.0).toDouble();
  if (curve is _ScrollCubic) return curve.slope(t);
  if (curve is _HermiteEaseOut) {
    return 6 * t * (1 - t) + curve.initialSlope * (1 - t) * (1 - 3 * t);
  }
  const epsilon = 0.0001;
  final start = math.max(0.0, t - epsilon);
  final end = math.min(1.0, t + epsilon);
  return (curve.transform(end) - curve.transform(start)) / (end - start);
}

// Flutter Cubic 的 1e-3 求解误差会放大成滚动位置台阶；位置与速度共用高精度参数解。
class _ScrollCubic extends Cubic {
  const _ScrollCubic(super.a, super.b, super.c, super.d);

  double _value(double p1, double p2, double u) {
    final v = 1 - u;
    return 3 * p1 * v * v * u + 3 * p2 * v * u * u + u * u * u;
  }

  double _derivative(double p1, double p2, double u) {
    final v = 1 - u;
    return 3 * p1 * v * v + 6 * (p2 - p1) * v * u + 3 * (1 - p2) * u * u;
  }

  double _solve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    var lower = 0.0;
    var upper = 1.0;
    var u = t;
    for (var i = 0; i < 32; i++) {
      final error = _value(a, c, u) - t;
      if (error.abs() < 1e-9) return u;
      if (error < 0) {
        lower = u;
      } else {
        upper = u;
      }
      final next = u - error / _derivative(a, c, u);
      u = next > lower && next < upper ? next : (lower + upper) / 2;
    }
    return u;
  }

  double slope(double t) {
    final u = _solve(t);
    return _derivative(b, d, u) / _derivative(a, c, u);
  }

  @override
  double transformInternal(double t) => _value(b, d, _solve(t));
}
