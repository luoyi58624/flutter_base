import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:flutter_base/builder.dart';
import 'package:test/test.dart';

void main() {
  var caseIndex = 0;

  Future<({bool succeeded, String code, String logs})> generate(
    String declarations, {
    Builder? builder,
  }) async {
    final readerWriter = TestReaderWriter(
      rootPackage: 'flutter_base',
      flattenOutput: true,
    );
    await readerWriter.testing.loadIsolateSources();
    final name = 'model_boundary_${caseIndex++}';
    final logs = <String>[];
    final result = await testBuilder(
      builder ?? elModelBuilder(BuilderOptions.empty),
      {
        'flutter_base|lib/$name.dart':
            '''
import 'package:flutter_base/dart.dart';
part '$name.g.dart';
$declarations
''',
      },
      rootPackage: 'flutter_base',
      generateFor: {'flutter_base|lib/$name.dart'},
      readerWriter: readerWriter,
      flattenOutput: true,
      onLog: (record) => logs.add(record.toString()),
    );
    final output = AssetId('flutter_base', 'lib/$name.model_generator.g.part');
    if (result.succeeded) {
      expect(
        readerWriter.testing.exists(output),
        isTrue,
        reason: logs.join('\n'),
      );
      expect(readerWriter.testing.readString(output), isNotEmpty);
    }
    return (
      succeeded: result.succeeded,
      code: readerWriter.testing.exists(output)
          ? readerWriter.testing.readString(output)
          : '',
      logs: logs.join('\n'),
    );
  }

  group('模型生成边界', () {
    test('jsonKey 和默认值中的引号、换行、反斜杠与插值字符正确转义', () async {
      final result = await generate(r'''
@ElModelGenerator.all(generateProps: false)
class EscapedModel {
  const EscapedModel({required this.value});
  @ElFieldGenerator(
    jsonKey: "user's\\key\$id\n下一行",
    defaultValue: "It's \\ready\n\$value",
  )
  final String value;
}
''');
      expect(result.succeeded, isTrue, reason: result.logs);
      expect(parseString(content: result.code).errors, isEmpty);
    });

    test('保留枚举序列化器的构造参数', () async {
      final result = await generate('''
enum Status { ready, done }
@ElModelGenerator.all(generateProps: false)
class EnumModel {
  const EnumModel({this.status});
  @ElEnumSerialize(Status.values)
  final Status? status;
}
''');
      expect(result.succeeded, isTrue, reason: result.logs);
      expect(result.code, contains('ElEnumSerialize(Status.values)'));
      expect(result.code, isNot(contains('ElEnumSerialize()')));
    });

    test('保留命名构造及其命名参数', () async {
      final result = await generate('''
class ScaledDuration implements ElSerialize<Duration> {
  const ScaledDuration.seconds({required this.factor});
  final int factor;
  @override
  String? serialize(Duration? value) => null;
  @override
  Duration? deserialize(String? value) => null;
}
@ElModelGenerator.all(generateProps: false)
class DurationModel {
  const DurationModel({this.value});
  @ScaledDuration.seconds(factor: 3)
  final Duration? value;
}
''');
      expect(result.succeeded, isTrue, reason: result.logs);
      expect(result.code, contains('ScaledDuration.seconds(factor: 3)'));
    });

    test('嵌套泛型按类型参数生成，不能把内层逗号当作外层分隔', () async {
      final result = await generate('''
@ElModelGenerator.all(generateProps: false)
class NestedCollections {
  const NestedCollections({required this.matrix, required this.rows});
  final Map<String, Map<String, int>> matrix;
  final List<Map<String, List<int?>>> rows;
}
''');
      expect(result.succeeded, isTrue, reason: result.logs);
      expect(parseString(content: result.code).errors, isEmpty);
      expect(result.code, isNot(contains('<null>')));
    });

    test('无名构造不受其他构造函数的声明顺序影响', () async {
      final result = await generate('''
@ElModelGenerator.json(generateProps: false)
class ConstructorOrder {
  const ConstructorOrder.other({this.ignored = 0}) : name = '';
  const ConstructorOrder({required this.name}) : ignored = 0;
  final String name;
  final int ignored;
}
''');
      expect(result.succeeded, isTrue, reason: result.logs);
      expect(result.code, contains('name:'));
      expect(result.code, isNot(contains('ignored:')));
    });

    for (final entry in {
      '缺少无名构造': '''
@ElModelGenerator.copy(generateProps: false)
class NamedOnly {
  const NamedOnly.named({this.value});
  final String? value;
}
''',
      '位置参数': '''
@ElModelGenerator.copy(generateProps: false)
class Positional {
  const Positional(this.value);
  final String value;
}
''',
      '泛型模型': '''
@ElModelGenerator.copy(generateProps: false)
class GenericModel<T> {
  const GenericModel({required this.value});
  final T value;
}
''',
      '抽象类': '''
@ElModelGenerator.copy(generateProps: false)
abstract class AbstractModel {
  const AbstractModel({this.value});
  final String? value;
}
''',
      'Map 的键': '''
@ElModelGenerator.json(generateProps: false)
class NumericKeys {
  const NumericKeys({required this.values});
  final Map<int, String> values;
}
''',
    }.entries) {
      test('生成阶段明确报告${entry.key}', () async {
        final result = await generate(entry.value);
        expect(result.succeeded, isFalse);
        expect(result.logs, contains(entry.key));
      });
    }

    test('接口名字包含 ElSerializeModel 不代表实现了框架接口', () async {
      final result = await generate('''
abstract interface class FakeElSerializeModel {}
class Payload implements FakeElSerializeModel {}
@ElModelGenerator.json(generateProps: false)
class UnrelatedModel {
  const UnrelatedModel({this.payload});
  final Payload? payload;
}
''');
      expect(result.succeeded, isTrue, reason: result.logs);
      expect(result.code, isNot(contains('PayloadExt.defaultModel')));
      expect(result.code, isNot(contains('payload?.toJson()')));
    });

    test('不同构建器实例的扩展后缀互不覆盖', () async {
      final first = elModelBuilder(BuilderOptions({'ext_suffix': 'First'}));
      elModelBuilder(BuilderOptions({'ext_suffix': 'Second'}));
      final result = await generate('''
@ElModelGenerator.copy(generateProps: false)
class ConfigModel {
  const ConfigModel({this.value});
  final String? value;
}
''', builder: first);
      expect(result.succeeded, isTrue, reason: result.logs);
      expect(result.code, contains('extension ConfigModelFirst'));
      expect(result.code, isNot(contains('ConfigModelSecond')));
    });

    test('非法扩展后缀在创建构建器时报告配置项', () {
      for (final suffix in ['', 'not-valid', 123]) {
        expect(
          () => elModelBuilder(BuilderOptions({'ext_suffix': suffix})),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.toString(),
              'message',
              contains('ext_suffix'),
            ),
          ),
        );
      }
    });
  });
}
