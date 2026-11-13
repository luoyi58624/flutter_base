part of 'style.dart';

/// 盒阴影的视觉风格，各风格共用整数级别与自定义参数。
enum ElShadowType {
  /// 底部明显、四周较淡的 Material 投影。
  material,

  /// 四周均匀扩散的弹层阴影。
  uniform,

  /// 柔和且离表面较远的悬浮阴影。
  floating,

  /// 紧贴边缘、范围较小的短阴影。
  contact,

  /// 沿四周扩散的光晕，可配合自定义颜色使用。
  glow,

  /// 裁剪在盒子内部的内凹阴影。
  inset,
}

const _shadowLayers = [
  (offset: .65, blur: 1.5, spread: -1.0, alpha: .13),
  (offset: 1.5, blur: 2.8, spread: -.25, alpha: .10),
  (offset: .85, blur: 5.5, spread: 0.0, alpha: .08),
];

/// 为视图样式添加分层阴影，圆角与自适应颜色在绘制时跟随最终样式。
extension ElShadowStyleExt on ElStyle {
  /// 替换当前盒阴影，保留其他属性、状态变体和过渡。
  ///
  /// [level] 越大，阴影越广、越浓，`0` 清除阴影，正整数没有预设上限。
  /// [color] 未传时根据当前背景配色，显式 `null` 或没有背景时使用黑色。
  /// [blurRadius] 覆盖最宽层的模糊半径，其余层按比例调整，0 表示无模糊。
  /// [offset] 和 [spreadRadius] 在计算结果上追加整体偏移与扩散。
  /// 数值必须有限，级别和模糊半径必须非负，非法参数抛出 [ArgumentError]。
  ElStyle withShadow({
    ElShadowType type = .material,
    int level = 1,
    Object? color = $absent,
    double? blurRadius,
    Offset offset = Offset.zero,
    double spreadRadius = 0,
  }) {
    if (!identical(color, $absent) && color != null && color is! Color) {
      throw ArgumentError.value(color, 'color', 'Must be a Color, null, or the absent sentinel.');
    }
    if (level < 0) throw ArgumentError.value(level, 'level');
    if (blurRadius != null && (!blurRadius.isFinite || blurRadius < 0)) {
      throw ArgumentError.value(blurRadius, 'blurRadius');
    }
    if (!offset.dx.isFinite || !offset.dy.isFinite) throw ArgumentError.value(offset, 'offset');
    if (!spreadRadius.isFinite) throw ArgumentError.value(spreadRadius, 'spreadRadius');
    if (level == 0 || (color is Color && color.a == 0)) return copyWith(boxShadow: const <BoxShadow>[]);

    final (offsetScale, blurScale, spreadScale, alphaScale) = switch (type) {
      .material => (1.0, 1.0, 1.0, 1.0),
      .uniform => (0.0, 1.0, 1.0, .75),
      .floating => (1.5, 1.6, 1.0, .75),
      .contact => (.25, .35, .25, 1.0),
      .glow => (0.0, 1.5, 1.0, .75),
      .inset => (.5, .5, 0.0, .8),
    };
    // 范围随级别放缓增长，高级别的阴影仍有变化，同时避免模糊范围暴涨。
    final scale = math.log(1.0 + level) / math.ln2;
    final density = level / (level + 5.0) * alphaScale;
    final widestLayer = _shadowLayers.last.blur;
    final maxBlur = blurRadius ?? widestLayer * scale * blurScale;
    final adaptive = identical(color, $absent);
    final literal = color is Color ? color : const Color(0xff000000);
    return copyWith(
      boxShadow: List<BoxShadow>.unmodifiable(
        _shadowLayers.map((layer) {
          final alpha = layer.alpha * density;
          final spread = type == .glow ? layer.spread.abs() * .5 + .35 : layer.spread * spreadScale;
          return _PresetBoxShadow(
            fixedColor: adaptive ? const Color(0x00000000) : literal.withValues(alpha: (alpha * literal.a).clamp(0, 1)),
            adaptiveAlpha: adaptive ? alpha : 0,
            offset: Offset(0, layer.offset * scale * offsetScale) + offset,
            blurRadius: layer.blur / widestLayer * maxBlur,
            spreadRadius: spread * scale + spreadRadius,
            inset: type == .inset,
          );
        }),
      ),
    );
  }
}

// 分别保存固定色与自适应色的预乘贡献，插值不丢颜色模式，也不积累表达式树。
class _PresetBoxShadow extends ElBoxShadow {
  _PresetBoxShadow({
    required this.fixedColor,
    required this.adaptiveAlpha,
    super.offset,
    super.blurRadius,
    super.spreadRadius,
    super.blurStyle,
    super.inset,
  }) : super(color: _resolveColor(fixedColor, adaptiveAlpha, null));

  final Color fixedColor;
  final double adaptiveAlpha;

  static Color _resolveColor(Color fixed, double adaptiveAlpha, Color? background) {
    if (adaptiveAlpha == 0) return fixed;
    var tint = const Color(0xff000000);
    var density = 1.0;
    if (background != null && background.a > 0) {
      final hsl = HSLColor.fromColor(background);
      tint = hsl
          .withAlpha(1)
          .withSaturation(hsl.saturation * .4)
          .withLightness(hsl.lightness * .25 * (hsl.saturation / .2).clamp(0.0, 1.0) * background.a)
          .toColor();
      final darkness = 1 - background.computeLuminance();
      density += 1.5 * background.a * darkness * darkness;
    }
    final autoAlpha = adaptiveAlpha * density;
    final totalAlpha = fixed.a + autoAlpha;
    if (totalAlpha <= 0) return const Color(0x00000000);
    return Color.from(
      alpha: totalAlpha.clamp(0.0, 1.0),
      red: (fixed.r * fixed.a + tint.r * autoAlpha) / totalAlpha,
      green: (fixed.g * fixed.a + tint.g * autoAlpha) / totalAlpha,
      blue: (fixed.b * fixed.a + tint.b * autoAlpha) / totalAlpha,
    );
  }

  @override
  Paint toPaintWithBackground(Color? backgroundColor) =>
      toPaint()..color = _resolveColor(fixedColor, adaptiveAlpha, backgroundColor);

  @override
  ElBoxShadow copyWith({
    Color? color,
    Offset? offset,
    double? blurRadius,
    double? spreadRadius,
    BlurStyle? blurStyle,
    bool? inset,
  }) => _PresetBoxShadow(
    fixedColor: color ?? fixedColor,
    adaptiveAlpha: color == null ? adaptiveAlpha : 0,
    offset: offset ?? this.offset,
    blurRadius: blurRadius ?? this.blurRadius,
    spreadRadius: spreadRadius ?? this.spreadRadius,
    blurStyle: blurStyle ?? this.blurStyle,
    inset: inset ?? this.inset,
  );

  @override
  ElBoxShadow scale(double factor) {
    final scale = math.max(0.0, factor);
    return _PresetBoxShadow(
      fixedColor: fixedColor.withValues(alpha: (fixedColor.a * scale).clamp(0.0, 1.0)),
      adaptiveAlpha: (adaptiveAlpha * scale).clamp(0.0, 1.0),
      offset: offset * scale,
      blurRadius: blurRadius * scale,
      spreadRadius: spreadRadius * scale,
      blurStyle: blurStyle,
      inset: inset,
    );
  }

  static BoxShadow interpolate(BoxShadow? a, BoxShadow? b, double t) {
    if (a == null) return b!.scale(t);
    if (b == null) return a.scale(1 - t);
    final geometry = BoxShadow.lerp(a, b, t)!;
    Color fixed(BoxShadow shadow) => shadow is _PresetBoxShadow ? shadow.fixedColor : shadow.color;
    double autoAlpha(BoxShadow shadow) => shadow is _PresetBoxShadow ? shadow.adaptiveAlpha : 0;
    return _PresetBoxShadow(
      fixedColor: lerpColorPremul(fixed(a), fixed(b), t)!,
      adaptiveAlpha: math.max(0.0, lerpDouble(autoAlpha(a), autoAlpha(b), t)!),
      offset: geometry.offset,
      blurRadius: geometry.blurRadius,
      spreadRadius: geometry.spreadRadius,
      blurStyle: geometry.blurStyle,
      inset: t < .5 ? a is ElBoxShadow && a.inset : b is ElBoxShadow && b.inset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _PresetBoxShadow &&
      super == other &&
      fixedColor == other.fixedColor &&
      adaptiveAlpha == other.adaptiveAlpha;

  @override
  int get hashCode => Object.hash(super.hashCode, fixedColor, adaptiveAlpha);
}
