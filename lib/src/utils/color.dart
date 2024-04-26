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
        return context.isDarkMode ? darkColor : lightColor;
      case ColorMode.light:
        return lightColor;
      case ColorMode.dark:
        return darkColor;
    }
  }
}

class FlutterColorData {
  FlutterColorData._();

  static List<MaterialColor> materialColors = [
    Colors.cyan,
    Colors.green,
    Colors.amber,
    Colors.indigo,
    Colors.blue,
    Colors.red,
    Colors.purple,
    Colors.blueGrey,
    Colors.brown,
    Colors.yellow,
    Colors.teal,
    Colors.lightBlue,
    Colors.lime,
    Colors.lightGreen,
    Colors.grey,
    Colors.pink,
    Colors.deepOrange,
  ];

  static List<int> materialColorSwatchs = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];

  static List<Color> get expandMaterialSwatchColors {
    return [
      ...materialColorSwatchs.map((e) => Colors.cyan[e]!),
      ...materialColorSwatchs.map((e) => Colors.green[e]!),
      ...materialColorSwatchs.map((e) => Colors.amber[e]!),
      ...materialColorSwatchs.map((e) => Colors.indigo[e]!),
      ...materialColorSwatchs.map((e) => Colors.blue[e]!),
      ...materialColorSwatchs.map((e) => Colors.red[e]!),
      ...materialColorSwatchs.map((e) => Colors.purple[e]!),
      ...materialColorSwatchs.map((e) => Colors.blueGrey[e]!),
      ...materialColorSwatchs.map((e) => Colors.brown[e]!),
      ...materialColorSwatchs.map((e) => Colors.yellow[e]!),
      ...materialColorSwatchs.map((e) => Colors.teal[e]!),
      ...materialColorSwatchs.map((e) => Colors.lightBlue[e]!),
      ...materialColorSwatchs.map((e) => Colors.lime[e]!),
      ...materialColorSwatchs.map((e) => Colors.lightGreen[e]!),
      ...materialColorSwatchs.map((e) => Colors.grey[e]!),
      ...materialColorSwatchs.map((e) => Colors.pink[e]!),
      ...materialColorSwatchs.map((e) => Colors.deepOrange[e]!),
    ];
  }
}
