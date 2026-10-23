import 'dart:convert';

import 'package:test/test.dart';

import 'models/boundaries.dart';

void main() {
  test('特殊字符在 JSON 键、标量和集合默认值中保持原值', () {
    final model = BoundaryModelExt.fromJson({});
    expect(model.value, escapedDefault);
    expect(model.labels, [escapedDefault]);
    expect(model.mapping, {escapedKey: escapedDefault});
    final json = jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
    expect(json[escapedKey], escapedDefault);
    expect(BoundaryModelExt.fromJson(json).value, escapedDefault);
    expect(BoundaryModelExt.fromJson({escapedKey: 'changed'}).value, 'changed');
  });

  test('带参数的枚举及带导入前缀的命名序列化器正确往返', () {
    final model = BoundaryModelExt.fromJson({
      'status': 'done',
      'duration': 7,
      'statuses': ['ready', null, 'invalid', 'done'],
    });
    expect(model.status, BoundaryStatus.done);
    expect(model.duration, const Duration(microseconds: 70));
    expect(model.statuses, [
      BoundaryStatus.ready,
      null,
      null,
      BoundaryStatus.done,
    ]);
    final json = jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
    expect(json['status'], 'done');
    expect(json['duration'], '7');
    expect(json['statuses'], ['ready', null, null, 'done']);
    expect(BoundaryModelExt.fromJson(json).duration, model.duration);
    expect(BoundaryModelExt.fromJson({}).status, BoundaryStatus.ready);
  });

  test('多层 Map、List、Set 和可空模型元素正确往返', () {
    final model = NestedBoundaryModelExt.fromJson({
      'matrix': {
        'a': {'b': 3},
      },
      'rows': [
        {
          'a': [1, null, 2],
        },
      ],
      'leaves': {
        'a': [
          {'name': 'leaf'},
          null,
        ],
      },
      'sets': {
        'a': [1, 2, 1],
      },
      'optionalRows': [
        null,
        [3, 4],
      ],
    });
    expect(model.matrix, {
      'a': {'b': 3},
    });
    expect(model.rows, [
      {
        'a': [1, null, 2],
      },
    ]);
    expect(model.leaves['a']!.first!.name, 'leaf');
    expect(model.leaves['a']!.last, isNull);
    expect(model.sets['a'], {1, 2});
    expect(model.optionalRows, [
      null,
      [3, 4],
    ]);
    final json = jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
    expect(json['leaves'], {
      'a': [
        {'name': 'leaf'},
        null,
      ],
    });
    expect(json['sets'], {
      'a': [1, 2],
    });
    final restored = NestedBoundaryModelExt.fromJson(json);
    expect(restored.leaves['a']!.first!.name, 'leaf');
    expect(restored.matrix, model.matrix);
    expect(restored.rows, model.rows);
    expect(restored.sets, model.sets);
    expect(restored.optionalRows, model.optionalRows);
  });

  test('嵌套集合的自定义序列化保持元素的空值与过滤语义', () {
    final model = NestedBoundaryModelExt.fromJson({
      'times': {
        'a': [2, null, 'bad', 3],
      },
      'strictTimes': [
        {'ok': 4, 'bad': 'invalid', 'empty': null},
      ],
    });
    expect(model.times['a'], [
      const Duration(microseconds: 20),
      null,
      null,
      const Duration(microseconds: 30),
    ]);
    expect(model.strictTimes, [
      {'ok': const Duration(microseconds: 40)},
    ]);
    final json = jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
    expect(json['times'], {
      'a': ['2', null, null, '3'],
    });
    expect(json['strictTimes'], [
      {'ok': '4'},
    ]);
    final restored = NestedBoundaryModelExt.fromJson(json);
    expect(restored.times, model.times);
    expect(restored.strictTimes, model.strictTimes);
  });

  test('嵌套集合缺省值、空集合与空值保持声明语义', () {
    for (final json in [null, <String, dynamic>{}]) {
      final model = NestedBoundaryModelExt.fromJson(json);
      expect(model.matrix, isEmpty);
      expect(model.rows, isEmpty);
      expect(model.optionalRows, isNull);
    }
    expect(
      NestedBoundaryModelExt.fromJson({'optionalRows': []}).optionalRows,
      [],
    );
    final wrongShapes = NestedBoundaryModelExt.fromJson({
      'matrix': [],
      'rows': {},
      'optionalRows': 'invalid',
    });
    expect(wrongShapes.matrix, isEmpty);
    expect(wrongShapes.rows, isEmpty);
    expect(wrongShapes.optionalRows, isNull);
  });

  test('嵌套集合类型错误报告具体字段', () {
    expect(
      () => NestedBoundaryModelExt.fromJson({
        'matrix': {
          'a': {'b': 'bad'},
        },
      }),
      throwsA(contains('matrix -> Map<String, Map<String, int>>')),
    );
  });

  test('无名构造顺序及既有 copyWith 和 merge 空值语义保持正确', () {
    final leaf = BoundaryLeafExt.fromJson({'name': 'leaf'});
    expect(leaf.name, 'leaf');
    expect(leaf.copyWith(name: 'changed').name, 'changed');
    const model = NestedBoundaryModel(
      optionalRows: [
        [1],
      ],
    );
    expect(model.copyWith().optionalRows, [
      [1],
    ]);
    expect(model.copyWith(optionalRows: null).optionalRows, isNull);
    expect(model.merge(const NestedBoundaryModel()).optionalRows, [
      [1],
    ]);
  });
}
