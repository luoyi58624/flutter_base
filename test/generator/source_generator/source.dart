import 'package:flutter_base/dart.dart';

part '../generates/source_generator/source.g.dart';
part 'source_part.dart';

/// 返回主文件中生成的声明源码。
String get generatedMainSource => _mainCode;

/// 返回 part 文件中生成的声明源码。
String get generatedPartSource => _partCode;

@ElSourceGenerator('_mainCode')
class MainExample {
  String get message => '主文件示例';
}
