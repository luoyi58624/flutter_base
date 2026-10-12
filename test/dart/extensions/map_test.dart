import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('映射扩展', () {
    test('Map 比较不依赖插入顺序，但区分键和对应的值', () {
      final source = {'a': 1, 'b': 2};
      expect(source.eq({'b': 2, 'a': 1}), isTrue);
      expect(source.neq({'a': 1, 'b': 3}), isTrue);
      expect(source.eq({'a': 1}), isFalse);
    });

    test('Map 过滤按条件与指定键创建新容器', () {
      final source = {'a': 1, 'b': 2, 'c': 3};
      final filtered = source.filter((key, value) => key != 'a' && value.isOdd);
      expect(filtered, {'c': 3});
      expect(source.filterFromKeys(['c', 'a']), {'c': 3, 'a': 1});
      expect(source.filterFromKeys([]), isEmpty);
      filtered['c'] = 9;
      expect(source['c'], 3);
    });

    test('Map 按值查询返回首次匹配键，无匹配返回 null', () {
      final source = {'first': 1, 'second': 1, 'third': 2};
      expect(source.getKeyByValue(1), 'first');
      expect(source.getKeyByValue(7), isNull);
    });

    test('Map 转 List 保持遍历顺序，转 Set 去除重复结果', () {
      final source = {'a': 1, 'b': 2, 'c': 2};
      expect(source.mapToList((key, value) => '$key=$value'), [
        'a=1',
        'b=2',
        'c=2',
      ]);
      expect(source.mapToSet((key, value) => value), {1, 2});
      expect(<String, int>{}.mapToList((key, value) => key), isEmpty);
      expect(<String, int>{}.mapToSet((key, value) => value), isEmpty);
    });
  });
}
