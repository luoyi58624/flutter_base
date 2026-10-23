import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:flutter_base/builder.dart';
import 'package:test/test.dart';

import 'source_generator/source.dart';

void main() {
  group('@ElSourceGenerator', () {
    test('主文件类声明与私有输出名保持源码一致', () {
      expect(
        generatedMainSource,
        _declarationSource(
          'test/generator/source_generator/source.dart',
          'class MainExample',
        ),
      );
    });

    test('part 私有类与特殊字符保持源码一致', () {
      expect(
        generatedPartSource,
        _declarationSource(
          'test/generator/source_generator/source_part.dart',
          'class _PartExample',
        ),
      );
      expect(generatedPartSource, contains(r'C:\docs\例子'));
      expect(generatedPartSource, contains(r"'$path\n$single"));
      expect(generatedPartSource, contains("\"\"\"contains '''\"\"\""));
      expect(generatedPartSource, contains("'''contains \"\"\"'''"));
    });

    test('拒绝非法输出名', () async {
      final logs = <String>[];
      final readerWriter = TestReaderWriter(rootPackage: 'flutter_base');
      await readerWriter.testing.loadIsolateSources();
      await testBuilder(
        elSourceGeneratorBuilder(BuilderOptions.empty),
        {
          'flutter_base|lib/invalid_name.dart': '''
import 'package:flutter_base/dart.dart';
part 'invalid_name.g.dart';

@ElSourceGenerator('not-valid')
class Example {}
''',
        },
        rootPackage: 'flutter_base',
        onLog: (record) => logs.add(record.toString()),
        readerWriter: readerWriter,
      );

      expect(logs, contains(contains('不是合法的 Dart 标识符')));
    });

    test('拒绝同一 library 的重复输出名', () async {
      final logs = <String>[];
      final readerWriter = TestReaderWriter(rootPackage: 'flutter_base');
      await readerWriter.testing.loadIsolateSources();
      await testBuilder(
        elSourceGeneratorBuilder(BuilderOptions.empty),
        {
          'flutter_base|lib/duplicate_name.dart': '''
import 'package:flutter_base/dart.dart';
part 'duplicate_name.g.dart';

@ElSourceGenerator('_code')
class FirstExample {}

@ElSourceGenerator('_code')
class SecondExample {}
''',
        },
        rootPackage: 'flutter_base',
        onLog: (record) => logs.add(record.toString()),
        readerWriter: readerWriter,
      );

      expect(logs, contains(contains('重复生成了 `_code`')));
    });
  });
}

String _declarationSource(String path, String marker) {
  final contents = File(path).readAsStringSync();
  return contents.substring(contents.indexOf(marker)).trimRight();
}
