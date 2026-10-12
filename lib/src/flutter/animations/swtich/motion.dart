part of 'index.dart';

/// 快速起步、提前达到速度峰值，末端的速度与加速度归零。
class _MotionCurve extends Curve {
  const _MotionCurve();

  @override
  double transformInternal(double t) => _motionPosition(t);
}

double _motionPosition(double t) => t <= 0.5
    ? t * t * (10 + t * (-20 + t * (15 - 4 * t)))
    : 1 - math.pow(1 - t, 4) * (1 + 4 * t);

double _motionVelocity(double t) => 20 * t * math.pow(1 - t, 3);

/// 同时求出曲线位置与导数，避免贝塞尔误差被微小差分放大成错误速度。
(double, double) _sampleCurve(Curve curve, double t) {
  if (curve is _MotionCurve) {
    return (_motionPosition(t), _motionVelocity(t));
  }
  if (curve is Cubic) {
    double position(double a, double b, double u) =>
        3 * a * u * (1 - u) * (1 - u) + 3 * b * u * u * (1 - u) + u * u * u;
    double derivative(double a, double b, double u) =>
        3 * a * (1 - u) * (1 - u) +
        6 * (b - a) * (1 - u) * u +
        3 * (1 - b) * u * u;
    if (t == 0) {
      final slope = curve.a > 0
          ? curve.b / curve.a
          : curve.b == 0 && curve.c > 0
          ? curve.d / curve.c
          : curve.transform(0.001) / 0.001;
      return (0, slope);
    }
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 32; i++) {
      final u = (low + high) / 2;
      if (position(curve.a, curve.c, u) < t) {
        low = u;
      } else {
        high = u;
      }
    }
    final u = (low + high) / 2;
    return (
      position(curve.b, curve.d, u),
      derivative(curve.b, curve.d, u) / derivative(curve.a, curve.c, u),
    );
  }
  final before = (t - 0.001).clamp(0.0, 1.0);
  final after = (t + 0.001).clamp(0.0, 1.0);
  return (
    curve.transform(t),
    (curve.transform(after) - curve.transform(before)) / (after - before),
  );
}

/// 使用明确时长完成整段动作，并准确提供反转所需的当前速度。
class _TimedMotion extends Simulation {
  _TimedMotion(this.begin, this.end, Duration duration, this.curve)
    : seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  final double begin;
  final double end;
  final double seconds;
  final Curve curve;

  @override
  double x(double time) {
    if (time <= 0) return begin;
    if (isDone(time)) return end;
    return begin + (end - begin) * _sampleCurve(curve, time / seconds).$1;
  }

  @override
  double dx(double time) => isDone(time)
      ? 0
      : (end - begin) *
            _sampleCurve(curve, math.max(0.0, time / seconds)).$2 /
            seconds;

  @override
  bool isDone(double time) => time >= seconds;
}

/// 承接位置和速度，最多用 4ms 制动，并在给定时长内平稳停靠。
class _RetargetMotion extends Simulation {
  _RetargetMotion(this.begin, this.end, this.velocity, Duration duration) {
    final budget = duration.inMicroseconds / Duration.microsecondsPerSecond;
    final opposing = velocity * (end - begin) < 0;
    final space = velocity > 0 ? 1 - begin : begin;
    brake = opposing
        ? math.min(0.004, math.min(budget / 8, 2 * space / velocity.abs()))
        : 0;
    turn = begin + velocity * brake / 2;
    final towardVelocity = opposing ? 0.0 : velocity;
    final distance = (end - turn).abs();
    // 将切线限制在单调区间，继承速度时也不会越过目标。
    arrival = towardVelocity == 0
        ? budget - brake
        : math.min(budget - brake, 5 * distance / towardVelocity.abs());
    tangent = towardVelocity * arrival / (end - turn);
  }

  final double begin;
  final double end;
  final double velocity;
  late final double brake;
  late final double turn;
  late final double arrival;
  late final double tangent;

  @override
  double x(double time) {
    if (time <= 0) return begin;
    if (isDone(time)) return end;
    if (time < brake) {
      return begin + velocity * time * (1 - time / (2 * brake));
    }
    final t = (time - brake) / arrival;
    return turn +
        (end - turn) * (_motionPosition(t) + tangent * t * math.pow(1 - t, 4));
  }

  @override
  double dx(double time) {
    if (isDone(time)) return 0;
    if (time < brake) return velocity * (1 - time / brake);
    final t = math.max(0.0, (time - brake) / arrival);
    return (end - turn) /
        arrival *
        (_motionVelocity(t) + tangent * math.pow(1 - t, 3) * (1 - 5 * t));
  }

  @override
  bool isDone(double time) => time >= brake + arrival;
}
