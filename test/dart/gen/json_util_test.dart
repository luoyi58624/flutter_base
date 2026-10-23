import 'package:flutter_base/dart.dart';
import 'package:test/test.dart';

void main() {
  group('\$ElJsonUtil', () {
    test('非 Map json 返回 null（不抛异常）', () {
      expect($ElJsonUtil.$string('not map', 'a'), null);
      expect($ElJsonUtil.$int('not map', 'a'), null);
      expect($ElJsonUtil.$double('not map', 'a'), null);
      expect($ElJsonUtil.$bool('not map', 'a'), null);
      expect($ElJsonUtil.$list('not map', 'a'), null);
      expect($ElJsonUtil.$set('not map', 'a'), null);
      expect($ElJsonUtil.$map('not map', 'a'), null);
    });

    test('key 同时支持驼峰和下划线', () {
      final json = {'user_id': '12'};
      expect($ElJsonUtil.$int(json, 'userId'), 12);
    });

    test(r'$num/$int/$double 支持 num 和带空白字符串', () {
      final json = {'a': 1, 'b': ' 2 ', 'c': ' 1.25 '};
      expect($ElJsonUtil.$num(json, 'a'), 1);
      expect($ElJsonUtil.$int(json, 'b'), 2);
      expect($ElJsonUtil.$double(json, 'c'), 1.25);
    });

    test(r'$num/$int/$double fallback 分支覆盖', () {
      final json = {
        'n': '3',
        'i': Object(),
        'd': DateTime.fromMillisecondsSinceEpoch(0),
      };
      expect($ElJsonUtil.$num(json, 'n'), 3);
      expect($ElJsonUtil.$int(json, 'i'), null);
      expect($ElJsonUtil.$double(json, 'd'), null);
    });

    test(r'$bool 支持 bool/num/0-1 字符串', () {
      final json = {
        't': true,
        'n1': 1,
        'n0': 0,
        's1': '1',
        's0': '0',
        'st': ' true ',
        'sf': 'FALSE',
      };
      expect($ElJsonUtil.$bool(json, 't'), true);
      expect($ElJsonUtil.$bool(json, 'n1'), true);
      expect($ElJsonUtil.$bool(json, 'n0'), false);
      expect($ElJsonUtil.$bool(json, 's1'), true);
      expect($ElJsonUtil.$bool(json, 's0'), false);
      expect($ElJsonUtil.$bool(json, 'st'), true);
      expect($ElJsonUtil.$bool(json, 'sf'), false);
    });

    test(r'$list/$set/$map 类型不匹配返回 null', () {
      final json = {'l': 'x', 's': 1, 'm': []};
      expect($ElJsonUtil.$list<int>(json, 'l'), null);
      expect($ElJsonUtil.$set<int>(json, 's'), null);
      expect($ElJsonUtil.$map<int>(json, 'm'), null);
    });

    test('复杂 json 解析（嵌套/混合类型/驼峰下划线）', () {
      final json = <String, dynamic>{
        'user_id': '12',
        'userName': 'Alice',
        'age': ' 18 ',
        'height': 1.65,
        'is_vip': '1',
        'score': ' 99.5 ',
        'tags': ['a', 'b', 'c'],
        'nums': ['1', 2, 3.1, 'x'],
        'prefs': {'dark_mode': true, 'lang': 'zh'},
        'items': [
          {'item_id': '1', 'price': ' 9.9 '},
          {'itemId': 2, 'price': 10},
          {'item_id': 'x', 'price': 'bad'},
        ],
        'misc': null,
      };

      expect($ElJsonUtil.$int(json, 'userId'), 12);
      expect($ElJsonUtil.$string(json, 'userName'), 'Alice');
      expect($ElJsonUtil.$int(json, 'age'), 18);
      expect($ElJsonUtil.$double(json, 'height'), 1.65);
      expect($ElJsonUtil.$bool(json, 'isVip'), true);
      expect($ElJsonUtil.$double(json, 'score'), 99.5);

      expect($ElJsonUtil.$list<String>(json, 'tags'), ['a', 'b', 'c']);
      expect($ElJsonUtil.$set<String>(json, 'tags'), {'a', 'b', 'c'});

      final prefs = $ElJsonUtil.$map<dynamic>(json, 'prefs');
      expect(prefs?['dark_mode'], true);
      expect(prefs?['lang'], 'zh');

      final items = $ElJsonUtil.$list<Map<String, dynamic>>(json, 'items');
      expect(items?.length, 3);

      expect($ElJsonUtil.$int(items?[0], 'itemId'), 1);
      expect($ElJsonUtil.$double(items?[0], 'price'), 9.9);

      expect($ElJsonUtil.$int(items?[1], 'itemId'), 2);
      expect($ElJsonUtil.$double(items?[1], 'price'), 10.0);

      expect($ElJsonUtil.$int(items?[2], 'itemId'), null);
      expect($ElJsonUtil.$double(items?[2], 'price'), null);

      // 缺失/空字段返回 null
      expect($ElJsonUtil.$string(json, 'notExist'), null);
      expect($ElJsonUtil.$string(json, 'misc'), null);
    });

    test(r'$list/$set/$map 支持 ElSerializeModel 元素反序列化', () {
      final json = <String, dynamic>{
        'items': [
          {'id': '1'},
          {'id': 2},
        ],
        'itemSet': [
          {'id': '3'},
          {'id': 4},
        ],
        'itemMap': {
          'a': {'id': '5'},
          'b': {'id': 6},
        },
      };

      const fallback = _JsonItem(0);

      expect($ElJsonUtil.$list<_JsonItem>(json, 'items', fallback), [
        _JsonItem(1),
        _JsonItem(2),
      ]);
      expect($ElJsonUtil.$set<_JsonItem>(json, 'itemSet', fallback), {
        _JsonItem(3),
        _JsonItem(4),
      });
      expect($ElJsonUtil.$map<_JsonItem>(json, 'itemMap', fallback), {
        'a': _JsonItem(5),
        'b': _JsonItem(6),
      });
    });

    test(r'$map 支持 raw ElSerializeModel 元素反序列化', () {
      final json = <String, dynamic>{
        'itemMap': {
          'a': {'id': '1'},
          'b': {'id': 2},
        },
      };

      expect(
        $ElJsonUtil.$map<_RawJsonItem>(json, 'itemMap', const _RawJsonItem(0)),
        {'a': _RawJsonItem(1), 'b': _RawJsonItem(2)},
      );
    });

    test('集合比较一边为 null 时返回 false', () {
      expect($ElJsonUtil.eqList(null, [1]), false);
      expect($ElJsonUtil.eqList([1], null), false);
      expect($ElJsonUtil.eqSet(null, {1}), false);
      expect($ElJsonUtil.eqSet({1}, null), false);
      expect($ElJsonUtil.eqMap(null, {'a': 1}), false);
      expect($ElJsonUtil.eqMap({'a': 1}, null), false);
    });
  });
}

/// 用于验证 `$ElJsonUtil` 对模型集合的递归反序列化。
final class _JsonItem implements ElSerializeModel<_JsonItem> {
  /// 创建测试模型。
  const _JsonItem(this.id);

  /// 模型标识。
  final int id;

  @override
  _JsonItem fromJson(Map<String, dynamic>? json) =>
      _JsonItem($ElJsonUtil.$int(json, 'id') ?? id);

  @override
  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) => other is _JsonItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 用于验证 raw `ElSerializeModel` 实现也能被识别。
final class _RawJsonItem implements ElSerializeModel {
  /// 创建测试模型。
  const _RawJsonItem(this.id);

  /// 模型标识。
  final int id;

  @override
  _RawJsonItem fromJson(Map<String, dynamic>? json) =>
      _RawJsonItem($ElJsonUtil.$int(json, 'id') ?? id);

  @override
  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) => other is _RawJsonItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
