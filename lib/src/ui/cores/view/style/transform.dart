part of 'index.dart';

// 保留函数来源才能让完整圈旋转及动画中断继续按角度插值。
enum _TransformKind {
  matrix,
  identity,
  translate,
  scale,
  rotate,
  skew,
  perspective,
}

/// 不可变的视觉变换，平移使用逻辑像素，旋转和倾斜使用弧度。
@immutable
final class ElTransform {
  const ElTransform._(
    this._kind,
    this.origin, [
    this._a = 0,
    this._b = 0,
    this._c = 0,
    this._d = 0,
    this._e = 0,
    this._f = 0,
    this._g = 0,
    this._h = 0,
    this._i = 0,
    this._j = 0,
    this._k = 0,
    this._l = 0,
    this._m = 0,
    this._n = 0,
    this._o = 0,
    this._p = 0,
  ]);

  /// 创建 CSS matrix(a, b, c, d, tx, ty) 对应的二维变换。
  const ElTransform.matrix(
    double a,
    double b,
    double c,
    double d,
    double tx,
    double ty, {
    AlignmentGeometry? origin,
  }) : this.matrix3d(
         a,
         b,
         0,
         0,
         c,
         d,
         0,
         0,
         0,
         0,
         1,
         0,
         tx,
         ty,
         0,
         1,
         origin: origin,
       );

  /// 按 Matrix4 列主序创建完整的三维矩阵变换。
  const ElTransform.matrix3d(
    double m00,
    double m01,
    double m02,
    double m03,
    double m10,
    double m11,
    double m12,
    double m13,
    double m20,
    double m21,
    double m22,
    double m23,
    double m30,
    double m31,
    double m32,
    double m33, {
    AlignmentGeometry? origin,
  }) : this._(
         .matrix,
         origin,
         m00,
         m01,
         m02,
         m03,
         m10,
         m11,
         m12,
         m13,
         m20,
         m21,
         m22,
         m23,
         m30,
         m31,
         m32,
         m33,
       );

  /// 复制外部 Matrix4 的全部分量，之后不受原矩阵修改影响。
  factory ElTransform.matrix4(Matrix4 matrix, {AlignmentGeometry? origin}) {
    final v = matrix.storage;
    return ElTransform.matrix3d(
      v[0],
      v[1],
      v[2],
      v[3],
      v[4],
      v[5],
      v[6],
      v[7],
      v[8],
      v[9],
      v[10],
      v[11],
      v[12],
      v[13],
      v[14],
      v[15],
      origin: origin,
    );
  }

  /// 创建不改变视觉的单位变换。
  const ElTransform.identity() : this._(.identity, null);

  /// 按逻辑像素平移，未指定的 y 和 z 轴位移为零。
  const ElTransform.translate(double x, [double? y, double? z])
    : this.translate3d(x, y ?? 0, z ?? 0);

  /// 沿 x 轴按逻辑像素平移。
  const ElTransform.translateX(double x) : this.translate3d(x, 0, 0);

  /// 沿 y 轴按逻辑像素平移。
  const ElTransform.translateY(double y) : this.translate3d(0, y, 0);

  /// 沿 z 轴按逻辑像素平移。
  const ElTransform.translateZ(double z) : this.translate3d(0, 0, z);

  /// 分别指定三个轴的逻辑像素位移。
  const ElTransform.translate3d(double x, double y, double z)
    : this._(.translate, null, x, y, z);

  /// 缩放三个轴，未指定 y 时与 x 相同，未指定 z 时为一。
  const ElTransform.scale(double x, [double? y, double? z])
    : this.scale3d(x, y ?? x, z ?? 1);

  /// 仅缩放 x 轴。
  const ElTransform.scaleX(double x) : this.scale3d(x, 1, 1);

  /// 仅缩放 y 轴。
  const ElTransform.scaleY(double y) : this.scale3d(1, y, 1);

  /// 仅缩放 z 轴。
  const ElTransform.scaleZ(double z) : this.scale3d(1, 1, z);

  /// 分别指定三个轴的缩放系数。
  const ElTransform.scale3d(double x, double y, double z)
    : this._(.scale, null, x, y, z);

  /// 围绕 z 轴旋转，角度使用弧度且保留完整圈数。
  const ElTransform.rotate(double radians) : this.rotateZ(radians);

  /// 围绕 x 轴按弧度旋转。
  const ElTransform.rotateX(double radians)
    : this._(.rotate, null, 1, 0, 0, radians);

  /// 围绕 y 轴按弧度旋转。
  const ElTransform.rotateY(double radians)
    : this._(.rotate, null, 0, 1, 0, radians);

  /// 围绕 z 轴按弧度旋转。
  const ElTransform.rotateZ(double radians)
    : this._(.rotate, null, 0, 0, 1, radians);

  /// 围绕归一化三维轴按弧度旋转，近零轴等同单位变换。
  factory ElTransform.rotate3d(double x, double y, double z, double radians) {
    if (!x.isFinite || !y.isFinite || !z.isFinite || !radians.isFinite) {
      return const ElTransform.matrix3d(
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      );
    }
    final scale = math.max(x.abs(), math.max(y.abs(), z.abs()));
    if (scale == 0) return const ElTransform.identity();
    // 先缩到单位数量级，避免有限的大轴分量在平方求长时溢出。
    final nx = x / scale, ny = y / scale, nz = z / scale;
    final length = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (scale < 1e-12 && scale * length < 1e-12) {
      return const ElTransform.identity();
    }
    return ElTransform._(
      .rotate,
      null,
      nx / length,
      ny / length,
      nz / length,
      radians,
    );
  }

  /// 按弧度分别指定 x 和 y 轴的倾斜角。
  const ElTransform.skew(double xRadians, [double yRadians = 0])
    : this._(.skew, null, xRadians, yRadians);

  /// 按弧度指定 x 轴倾斜角。
  const ElTransform.skewX(double radians) : this.skew(radians);

  /// 按弧度指定 y 轴倾斜角。
  const ElTransform.skewY(double radians) : this.skew(0, radians);

  /// 指定透视深度，无效深度由绘制执行器过滤。
  const ElTransform.perspective(double depth)
    : this._(.perspective, null, depth);

  final _TransformKind _kind;
  // 简单函数只使用前四槽保存参数，原始矩阵才使用全部十六槽。
  final double _a, _b, _c, _d, _e, _f, _g, _h;
  final double _i, _j, _k, _l, _m, _n, _o, _p;

  /// 视觉盒内的变换原点，样式 transformAlignment 优先，未指定时使用中心。
  final AlignmentGeometry? origin;

  /// 创建带指定原点且保留函数来源的副本。
  ElTransform alignment(AlignmentGeometry value) => ElTransform._(
    _kind,
    value,
    _a,
    _b,
    _c,
    _d,
    _e,
    _f,
    _g,
    _h,
    _i,
    _j,
    _k,
    _l,
    _m,
    _n,
    _o,
    _p,
  );

  /// 每次创建独立矩阵，调用者修改结果不会影响变换声明。
  Matrix4 toMatrix4() {
    switch (_kind) {
      case .matrix:
        return Matrix4(
          _a,
          _b,
          _c,
          _d,
          _e,
          _f,
          _g,
          _h,
          _i,
          _j,
          _k,
          _l,
          _m,
          _n,
          _o,
          _p,
        );
      case .identity:
        return Matrix4.identity();
      case .translate:
        return Matrix4.translationValues(_a, _b, _c);
      case .scale:
        return Matrix4.diagonal3Values(_a, _b, _c);
      case .rotate:
        if (!_d.isFinite) return Matrix4.zero();
        final c = math.cos(_d), s = math.sin(_d), t = 1 - c;
        return Matrix4(
          c + _a * _a * t,
          _b * _a * t + _c * s,
          _c * _a * t - _b * s,
          0,
          _a * _b * t - _c * s,
          c + _b * _b * t,
          _c * _b * t + _a * s,
          0,
          _a * _c * t + _b * s,
          _b * _c * t - _a * s,
          c + _c * _c * t,
          0,
          0,
          0,
          0,
          1,
        );
      case .skew:
        if (!_a.isFinite || !_b.isFinite) return Matrix4.zero();
        return Matrix4(
          1,
          math.tan(_b),
          0,
          0,
          math.tan(_a),
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        );
      case .perspective:
        if (!_a.isFinite || _a == 0) return Matrix4.zero();
        return Matrix4.identity()..setEntry(3, 2, -1 / _a);
    }
  }

  /// 同类函数插参数，其他变换逐矩阵分量插值，null 以单位变换补位。
  static ElTransform? lerp(ElTransform? start, ElTransform? end, double t) {
    if (identical(start, end) || t == 0) return start;
    if (t == 1) return end;
    final a = start ?? const ElTransform.identity();
    final b = end ?? const ElTransform.identity();
    final AlignmentGeometry? pivot;
    if (a._kind == .identity && b._kind != .identity) {
      pivot = b.origin;
    } else if (b._kind == .identity && a._kind != .identity) {
      pivot = a.origin;
    } else {
      pivot = a.origin == null && b.origin == null
          ? null
          : AlignmentGeometry.lerp(
              a.origin ?? Alignment.center,
              b.origin ?? Alignment.center,
              t,
            );
    }
    final result = _lerpFunction(a, b, t);
    if (result != null) return pivot == null ? result : result.alignment(pivot);
    final av = a.toMatrix4().storage, bv = b.toMatrix4().storage;
    return ElTransform.matrix3d(
      _mix(av[0], bv[0], t),
      _mix(av[1], bv[1], t),
      _mix(av[2], bv[2], t),
      _mix(av[3], bv[3], t),
      _mix(av[4], bv[4], t),
      _mix(av[5], bv[5], t),
      _mix(av[6], bv[6], t),
      _mix(av[7], bv[7], t),
      _mix(av[8], bv[8], t),
      _mix(av[9], bv[9], t),
      _mix(av[10], bv[10], t),
      _mix(av[11], bv[11], t),
      _mix(av[12], bv[12], t),
      _mix(av[13], bv[13], t),
      _mix(av[14], bv[14], t),
      _mix(av[15], bv[15], t),
      origin: pivot,
    );
  }

  static double _mix(double a, double b, double t) =>
      a == b ? a : a * (1 - t) + b * t;

  static (double, double, double, double) _neutral(
    _TransformKind kind,
    ElTransform other,
  ) => switch (kind) {
    .scale => (1, 1, 1, 0),
    .rotate => (other._a, other._b, other._c, 0),
    _ => (0, 0, 0, 0),
  };

  static ElTransform? _lerpFunction(ElTransform a, ElTransform b, double t) {
    final kind = a._kind == .identity ? b._kind : a._kind;
    if (kind == .matrix || kind == .perspective) return null;
    if (a._kind != b._kind && a._kind != .identity && b._kind != .identity) {
      return null;
    }
    final (ax, ay, az, angleA) = a._kind == .identity
        ? _neutral(kind, b)
        : (a._a, a._b, a._c, a._d);
    final (bx, by, bz, angleB) = b._kind == .identity
        ? _neutral(kind, a)
        : (b._a, b._b, b._c, b._d);
    return switch (kind) {
      .identity => const ElTransform.identity(),
      .translate => ElTransform.translate3d(
        _mix(ax, bx, t),
        _mix(ay, by, t),
        _mix(az, bz, t),
      ),
      .scale => ElTransform.scale3d(
        _mix(ax, bx, t),
        _mix(ay, by, t),
        _mix(az, bz, t),
      ),
      .skew => ElTransform.skew(_mix(ax, bx, t), _mix(ay, by, t)),
      .rotate => _lerpRotation(ax, ay, az, angleA, bx, by, bz, angleB, t),
      .matrix || .perspective => null,
    };
  }

  static ElTransform? _lerpRotation(
    double ax,
    double ay,
    double az,
    double angleA,
    double bx,
    double by,
    double bz,
    double angleB,
    double t,
  ) {
    if (angleA == 0) {
      return ElTransform.rotate3d(bx, by, bz, _mix(angleA, angleB, t));
    }
    if (angleB == 0 ||
        ((ax - bx).abs() <= 1e-9 &&
            (ay - by).abs() <= 1e-9 &&
            (az - bz).abs() <= 1e-9)) {
      return ElTransform.rotate3d(ax, ay, az, _mix(angleA, angleB, t));
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElTransform &&
          _kind == other._kind &&
          origin == other.origin &&
          _a == other._a &&
          _b == other._b &&
          _c == other._c &&
          _d == other._d &&
          _e == other._e &&
          _f == other._f &&
          _g == other._g &&
          _h == other._h &&
          _i == other._i &&
          _j == other._j &&
          _k == other._k &&
          _l == other._l &&
          _m == other._m &&
          _n == other._n &&
          _o == other._o &&
          _p == other._p;

  @override
  int get hashCode => Object.hash(
    _kind,
    origin,
    _a,
    _b,
    _c,
    _d,
    _e,
    _f,
    _g,
    _h,
    _i,
    _j,
    _k,
    _l,
    _m,
    _n,
    _o,
    _p,
  );
}
