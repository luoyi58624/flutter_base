part of flutter_base;

enum ColorMode {
  auto,
  light,
  dark,
}

/// 颜色工具类
class ColorUtil {
  ColorUtil._();

  /// 判断一个颜色是否是暗色
  static bool isDark(Color color) {
    return getColorHsp(color) <= 150;
  }

  /// 返回一个颜色的hsp (颜色的感知亮度)
  static int getColorHsp(Color color) {
    final int r = color.red, g = color.green, b = color.blue;
    double hsp = math.sqrt(0.299 * (r * r) + 0.587 * (g * g) + 0.114 * (b * b));
    return hsp.ceilToDouble().toInt();
  }

  /// 根据明亮度获取一个新的颜色，lightness以1为基准，小于1则颜色变暗，大于1则颜色变亮
  static Color getLightnessColor(Color color, double lightness) {
    final originalColor = HSLColor.fromColor(color);
    final newLightness = originalColor.lightness * lightness;
    final newColor = originalColor.withLightness(newLightness.clamp(0.0, 1.0));
    return newColor.toColor();
  }

  /// 创建material颜色
  static MaterialColor createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  /// 16进制字符串格式颜色转Color对象
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// 是否为黑暗模式，要想保持响应式必须以函数形式使用
  static bool isDarkMode(BuildContext context) {
    return FlutterAppData.of(context).currentTheme.brightness == Brightness.dark;
  }

  /// 返回一个动态颜色
  static Color dynamicColor(
    lightColor,
    darkColor,
    BuildContext context, {
    ColorMode? mode,
  }) {
    ColorMode colorMode = mode ?? ColorMode.auto;
    switch (colorMode) {
      case ColorMode.auto:
        return isDarkMode(context) ? darkColor : lightColor;
      case ColorMode.light:
        return lightColor;
      case ColorMode.dark:
        return darkColor;
    }
  }
}

extension HexColor on Color {
  /// Color对象转16进制字符串格式颜色
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}
