import 'package:flutter_base/dart.dart' as main_library;
import 'package:flutter_base/src/dart/gen/index.dart' as gen_library;
import 'package:test/test.dart';

void main() {
  test('ElSourceGenerator 由 Dart 入口导出并复用现有生成注解库', () {
    const annotation = main_library.ElSourceGenerator('_code');
    const genAnnotation = gen_library.ElSourceGenerator('_dataCode');

    expect(annotation.name, '_code');
    expect(genAnnotation.name, '_dataCode');
  });
}
