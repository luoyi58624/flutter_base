part of flutter_base;

/// Color工具函数扩展
extension FlutterColorExtension on Color {
  /// 判断一个颜色是否是暗色
  bool get isDark => hsp <= 150;

  /// 返回一个颜色的hsp (颜色的感知亮度)
  int get hsp =>
      math.sqrt(0.299 * (red * red) + 0.587 * (green * green) + 0.114 * (blue * blue)).ceilToDouble().toInt();

  /// Color对象转16进制字符串格式颜色
  /// * noLeading 是否不加 # 前缀
  String toHex([bool? noLeading]) => '${noLeading == true ? '' : '#'}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';

  /// 创建Material颜色
  MaterialColor toMaterialColor() {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        red + ((ds < 0 ? red : (255 - red)) * ds).round(),
        green + ((ds < 0 ? green : (255 - green)) * ds).round(),
        blue + ((ds < 0 ? blue : (255 - blue)) * ds).round(),
        1,
      );
    }
    return MaterialColor(value, swatch);
  }

  /// 将颜色变得更亮
  /// * scale 0-100，值越大，颜色越亮
  Color brighten(int scale) {
    assert(scale > 0 && scale <= 100);
    var p = scale / 100;
    return Color.fromARGB(
        alpha, red + ((255 - red) * p).round(), green + ((255 - green) * p).round(), blue + ((255 - blue) * p).round());
  }

  /// 将颜色变得更暗
  /// * scale 0-100，值越大，颜色越深
  Color darken(int scale) {
    assert(scale > 0 && scale <= 100);
    var f = 1 - scale / 100;
    return Color.fromARGB(alpha, (red * f).round(), (green * f).round(), (blue * f).round());
  }

  /// 将颜色变得深，如果当前颜色是亮色，颜色会变暗，但如果当前颜色是暗色，则颜色会变亮
  /// * scale 0-100，值越大，颜色越深
  Color deepen(int scale) {
    return isDark ? brighten(scale) : darken(scale);
  }

  /// 当用户鼠标悬停时的颜色
  Color onHover(BuildContext context, bool flag, [int? scale]) =>
      flag ? deepen(scale ?? context.globalConfig.hoverScale) : this;

  /// 当用户鼠标、手指按下时的颜色
  Color onTap(BuildContext context, bool flag, [int? scale]) =>
      flag ? deepen(scale ?? context.globalConfig.tapScale) : this;
}
