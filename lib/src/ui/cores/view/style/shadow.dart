part of 'index.dart';

/// 可与原生 BoxShadow 混用的盒阴影，支持裁在背景之上的内阴影。
@immutable
class ElBoxShadow extends BoxShadow {
  /// 创建阴影；inset 为 true 时绘制在背景之后、内容之前。
  const ElBoxShadow({
    super.color,
    super.offset,
    super.blurRadius,
    super.spreadRadius,
    super.blurStyle,
    this.inset = false,
  });

  /// 是否绘制内阴影，内阴影始终裁在盒子的圆角边界内。
  final bool inset;

  /// 复制阴影，并替换指定的颜色、几何或内外类型。
  @override
  ElBoxShadow copyWith({
    Color? color,
    Offset? offset,
    double? blurRadius,
    double? spreadRadius,
    BlurStyle? blurStyle,
    bool? inset,
  }) => ElBoxShadow(
    color: color ?? this.color,
    offset: offset ?? this.offset,
    blurRadius: blurRadius ?? this.blurRadius,
    spreadRadius: spreadRadius ?? this.spreadRadius,
    blurStyle: blurStyle ?? this.blurStyle,
    inset: inset ?? this.inset,
  );

  /// 按非负有限倍数缩放几何，保留颜色和内外类型。
  @override
  ElBoxShadow scale(double factor) {
    assert(factor >= 0 && factor.isFinite, '阴影缩放倍数必须非负且有限');
    return copyWith(
      offset: offset * factor,
      blurRadius: blurRadius * factor,
      spreadRadius: spreadRadius * factor,
    );
  }

  /// 预乘颜色插值；缺省端淡出并缩小，内外切换经过透明中点。
  static ElBoxShadow? lerp(BoxShadow? a, BoxShadow? b, double t) {
    if (a == b) return a == null ? null : _asElShadow(a);
    final from = a == null ? null : _asElShadow(a);
    final to = b == null ? null : _asElShadow(b);
    if (from != null && to != null && from.inset != to.inset) {
      // 不把正在显示的阴影瞬间翻到另一侧，也不为中断动画追加列表项。
      return t < 0.5 ? lerp(from, null, t * 2) : lerp(null, to, t * 2 - 1);
    }
    final reference = to ?? from!;
    return ElBoxShadow(
      color: _colorLerp(from?.color, to?.color, t) as Color,
      offset: Offset.lerp(
        from?.offset ?? Offset.zero,
        to?.offset ?? Offset.zero,
        t,
      )!,
      blurRadius: math.max(
        0.0,
        lerpDouble(from?.blurRadius ?? 0, to?.blurRadius ?? 0, t)!,
      ),
      spreadRadius: lerpDouble(
        from?.spreadRadius ?? 0,
        to?.spreadRadius ?? 0,
        t,
      )!,
      blurStyle: t < 0.5
          ? (from?.blurStyle ?? reference.blurStyle)
          : (to?.blurStyle ?? reference.blurStyle),
      inset: reference.inset,
    );
  }

  /// 逐项插值阴影；多出的项目通过透明零几何端点进入或退出。
  static List<ElBoxShadow>? lerpList(
    List<BoxShadow>? a,
    List<BoxShadow>? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    final length = math.max(a?.length ?? 0, b?.length ?? 0);
    if (length == 0) return null;
    return List<ElBoxShadow>.generate(
      length,
      (i) => lerp(
        i < (a?.length ?? 0) ? a![i] : null,
        i < (b?.length ?? 0) ? b![i] : null,
        t,
      )!,
      growable: false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ElBoxShadow && super == other && inset == other.inset;

  @override
  int get hashCode => Object.hash(super.hashCode, inset);

  @override
  String toString() => '${super.toString()}, inset: $inset';
}

ElBoxShadow _asElShadow(BoxShadow value) => value is ElBoxShadow
    ? value
    : ElBoxShadow(
        color: value.color,
        offset: value.offset,
        blurRadius: value.blurRadius,
        spreadRadius: value.spreadRadius,
        blurStyle: value.blurStyle,
      );

List<ElBoxShadow>? _parseShadows(List<BoxShadow> value) {
  if (value.isEmpty) return null;
  assert(
    value.every(
      (s) =>
          s.offset.dx.isFinite &&
          s.offset.dy.isFinite &&
          s.blurRadius >= 0 &&
          s.blurRadius.isFinite &&
          s.spreadRadius.isFinite &&
          s.color.a.isFinite &&
          s.color.r.isFinite &&
          s.color.g.isFinite &&
          s.color.b.isFinite,
    ),
    '阴影的偏移、扩展、颜色必须有限，模糊半径必须非负且有限',
  );
  return List<ElBoxShadow>.unmodifiable(value.map(_asElShadow));
}

List<ElBoxShadow>? _shadowsLerp(
  List<ElBoxShadow>? from,
  List<ElBoxShadow>? to,
  double t,
) => ElBoxShadow.lerpList(from, to, t);

bool _hasVisibleShadows(List<ElBoxShadow>? value) =>
    value?.any((shadow) => shadow.color.a > 0) ?? false;
