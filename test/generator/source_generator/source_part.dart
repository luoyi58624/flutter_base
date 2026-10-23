part of 'source.dart';

@ElSourceGenerator('_partCode')
// ignore: unused_element
class _PartExample {
  String describe(String value) {
    final path = r'C:\docs\例子';
    final single = "It's ready";
    final double = 'say "hello"';
    final tripleSingle = """contains '''""";
    final tripleDouble = '''contains """''';
    return '$path\n$single\n$double\n$tripleSingle\n$tripleDouble\n$value';
  }
}
