part of 'index.dart';

/// 提供颜色编码、感知亮度、混色与明暗调整。
extension ElColorExt on Color {
  /// 代替被弃用的方法 withOpacity
  Color elOpacity(double opacity) {
    return withValues(alpha: opacity);
  }

  /// 判断一个颜色是否是暗色，171 表示常用 warning 色的感知亮度，这个值可以覆盖 Element UI 默认的主题系统
  bool get isDark => hsp <= 171;

  /// 返回一个颜色的感知亮度：0 - 255，0 表示纯黑色，255 表示纯白色，
  /// 参考链接：http://www.w3.org/TR/AERT#color-contrast
  int get hsp =>
      ((r.floatToInt8 * 299 + g.floatToInt8 * 587 + b.floatToInt8 * 114) / 1000)
          .ceilToDouble()
          .toInt();

  /// 检查一个颜色是否为强调色，如果颜色越接近白色、黑色，它将返回 false
  bool get isHighlight {
    final hsp = this.hsp;
    return 78 <= hsp && hsp <= 178;
  }

  /// 根据明亮度获取一个新的颜色，lightness以1为基准，小于1则颜色变暗，大于1则颜色变亮
  Color getLightnessColor(double lightness) {
    final originalColor = HSLColor.fromColor(this);
    final newLightness = originalColor.lightness * lightness;
    final newColor = originalColor.withLightness(newLightness.clamp(0.0, 1.0));
    return newColor.toColor();
  }

  /// 反转红、绿、蓝通道，同时保留透明度
  Color get reversal {
    return Color.fromARGB(
      a.floatToInt8,
      255 - r.floatToInt8,
      255 - g.floatToInt8,
      255 - b.floatToInt8,
    );
  }

  /// 将颜色转成 int
  int get toInt =>
      a.floatToInt8 << 24 |
      r.floatToInt8 << 16 |
      g.floatToInt8 << 8 |
      b.floatToInt8 << 0;

  /// Color对象转16进制字符串格式颜色
  /// * hasLeading 是否添加 # 前缀，默认true
  /// * hasAlpha 是否添加透明度，默认false
  String toHex({bool hasLeading = true, bool hasAlpha = false}) =>
      '${hasLeading == true ? '#' : ''}'
      '${hasAlpha == true ? a.floatToInt8.toRadixString(16).padLeft(2, '0') : ''}'
      '${r.floatToInt8.toRadixString(16).padLeft(2, '0')}'
      '${g.floatToInt8.toRadixString(16).padLeft(2, '0')}'
      '${b.floatToInt8.toRadixString(16).padLeft(2, '0')}';

  /// 将当前颜色转换成 Material 颜色。
  ///
  /// 注意：[MaterialColor] 中所有颜色都是手动预设值，此函数只是简单根据预设梯度创建不同级别颜色，
  /// 所以返回的 MaterialColor 对象并不相同。
  MaterialColor toMaterialColor() {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }

    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = .fromRGBO(
        r.floatToInt8 +
            ((ds < 0 ? r.floatToInt8 : (255 - r.floatToInt8)) * ds).round(),
        g.floatToInt8 +
            ((ds < 0 ? g.floatToInt8 : (255 - g.floatToInt8)) * ds).round(),
        b.floatToInt8 +
            ((ds < 0 ? b.floatToInt8 : (255 - b.floatToInt8)) * ds).round(),
        1,
      );
    }
    return MaterialColor(toInt, swatch);
  }

  /// 设置颜色亮度，取值范围 -100 ~ 100，正数变亮，负数变暗
  Color setBrightness(int scale) {
    assert(
      scale >= -100 && scale <= 100,
      'setBrightness 颜色函数 scale 取值范围必须在 -100 ~ 100 之间：$scale',
    );
    if (scale == 0) return this;
    final p = scale / 100;

    return Color.fromARGB(
      a.floatToInt8,
      _applyScale(r.floatToInt8, p),
      _applyScale(g.floatToInt8, p),
      _applyScale(b.floatToInt8, p),
    );
  }

  /// 对颜色的 r、g、b 应用 scale 调整明亮度
  int _applyScale(int v, double p) =>
      p > 0 ? (v + (255 - v) * p).round() : (v * (1 + p)).round();

  /// 将颜色变得更亮
  /// * scale 值越大，颜色越亮，当为负数时，值越小，颜色越暗
  Color brighten(int scale) => setBrightness(scale);

  /// 将颜色变得更暗
  /// * scale 值越大，颜色越深，当为负数时，值越小，颜色越亮
  Color darken(int scale) => setBrightness(-scale);

  /// 将颜色变得深，如果当前颜色是亮色，颜色会变暗，但如果当前颜色是暗色，则颜色会变亮
  /// * scale -100-100，值越大，颜色越深
  /// * reversal 是否反转，如果颜色是亮色，则颜色更亮，否则更暗
  /// * lightScale 0 ~ 100，当颜色是亮色时，应用的 scale 值
  /// * darkScale 0 ~ 100，当颜色是暗色时，应用的 scale 值
  Color deepen(
    int scale, {
    bool reversal = false,
    int? lightScale,
    int? darkScale,
  }) {
    return reversal
        ? (isDark ? darken(darkScale ?? scale) : brighten(lightScale ?? scale))
        : (isDark ? brighten(darkScale ?? scale) : darken(lightScale ?? scale));
  }

  /// 将当前颜色和另一种颜色按一定比例进行混合
  /// * other 与之混合的颜色
  /// * scale 0 ~ 100，比值越小就越接近color1，比值越大就接近color2
  Color mix(Color other, int scale) {
    assert(
      scale >= 0 && scale <= 100,
      'mix 颜色函数 scale 取值范围必须在 0 ~ 100 之间：$scale',
    );
    final p = scale / 100;
    final a = this.a.floatToInt8;
    final r = this.r.floatToInt8;
    final g = this.g.floatToInt8;
    final b = this.b.floatToInt8;

    return Color.fromARGB(
      ((other.a.floatToInt8 - a) * p + a).round(),
      ((other.r.floatToInt8 - r) * p + r).round(),
      ((other.g.floatToInt8 - g) * p + g).round(),
      ((other.b.floatToInt8 - b) * p + b).round(),
    );
  }
}
