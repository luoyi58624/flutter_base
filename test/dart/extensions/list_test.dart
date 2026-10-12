import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('列表、集合和可迭代对象扩展', () {
    test('列表比较保留顺序，集合比较不依赖顺序', () {
      expect([1, 2].eq([1, 2]), isTrue);
      expect([1, 2].neq([2, 1]), isTrue);
      expect([1, 2].eq([1]), isFalse);
      expect({1, 2}.eq({2, 1}), isTrue);
      expect({1, 2}.neq({1}), isTrue);
    });

    test('列表重复和元素间插入均不修改原始内容', () {
      final source = [1, 2];
      expect(source * 3, [1, 2, 1, 2, 1, 2]);
      expect(source * 0, isEmpty);
      expect(source.insertBetween(0), [1, 0, 2]);
      expect(source, [1, 2]);
      expect(<int>[].insertBetween(0), isEmpty);
      expect([1].insertBetween(0), [1]);
    });

    test('列表移动支持两个方向和指定替代元素', () {
      final items = [1, 2, 3];
      expect(items.move(0, 2), isTrue);
      expect(items, [2, 3, 1]);
      expect(items.move(2, 0), isTrue);
      expect(items, [1, 2, 3]);
      expect(items.move(0, 2, 9), isTrue);
      expect(items, [2, 3, 9]);
    });

    test('列表移动拒绝相同位置和越界索引，并保留原列表', () {
      final items = [1, 2, 3];
      expect(items.move(1, 1), isFalse);
      expect(items.move(-1, 0), isFalse);
      expect(items.move(0, -1), isFalse);
      expect(items.move(3, 0), isFalse);
      expect(items.move(0, 3), isFalse);
      expect(items, [1, 2, 3]);
    });

    test('循环取值支持越过列表长度并保持非正索引约定', () {
      final items = ['a', 'b', 'c'];
      expect(items.loopGetContent(-1), 'a');
      expect(items.loopGetContent(0), 'a');
      expect(items.loopGetContent(2), 'c');
      expect(items.loopGetContent(3), 'a');
      expect(items.loopGetContent(7), 'b');
      expect(() => <int>[].loopGetContent(0), throwsRangeError);
    });

    test('onlyOne 在一般 Iterable 上只统计非 null 元素', () {
      final values = <int?>[null, 1, null].where((_) => true);
      expect(values.onlyOne(), isTrue);
      expect(<int?>[1, 2, null].onlyOne(), isFalse);
      expect(<int?>[null, null].onlyOne(), isFalse);
      expect(<int?>[null, null].onlyOne(allowAllNull: true), isTrue);
      expect(<int?>[].onlyOne(allowAllNull: true), isTrue);
    });
  });
}
