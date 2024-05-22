part of '../../flutter_base.dart';

class FlutterColorData {
  FlutterColorData._();

  static Map<String, MaterialColor> materialColors = {
    'cyan': Colors.cyan,
    'green': Colors.green,
    'amber': Colors.amber,
    'indigo': Colors.indigo,
    'blue': Colors.blue,
    'red': Colors.red,
    'purple': Colors.purple,
    'blueGrey': Colors.blueGrey,
    'brown': Colors.brown,
    'yellow': Colors.yellow,
    'teal': Colors.teal,
    'lightBlue': Colors.lightBlue,
    'lime': Colors.lime,
    'lightGreen': Colors.lightGreen,
    'grey': Colors.grey,
    'pink': Colors.pink,
    'deepOrange': Colors.deepOrange,
  };

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
