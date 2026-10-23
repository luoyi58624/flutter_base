import 'package:test/test.dart';

import 'models/animal.dart';
import 'models/collection_merge.dart';

void main() {
  group('merge / Map 集合合并', () {
    test('vars 逐 key 并集,同名 key 后表覆前表', () {
      const base = CollectionMergeModel(vars: {'--a': 1, '--b': 2});
      const other = CollectionMergeModel(vars: {'--b': 9, '--c': 3});
      final merged = base.merge(other);
      expect(merged.vars, {'--a': 1, '--b': 9, '--c': 3});
    });

    test('单侧 null:保留另一侧原实例(identical)', () {
      const base = CollectionMergeModel(vars: {'--a': 1});
      final keepBase = base.merge(const CollectionMergeModel());
      expect(identical(keepBase.vars, base.vars), isTrue);

      const other = CollectionMergeModel(vars: {'--a': 1});
      final takeOther = const CollectionMergeModel().merge(other);
      expect(identical(takeOther.vars, other.vars), isTrue);
    });

    test('空表短路:合并无效果时返回原实例(identical)', () {
      const base = CollectionMergeModel(vars: {'--a': 1});
      const other = CollectionMergeModel(vars: {});
      final merged = base.merge(other);
      expect(identical(merged.vars, base.vars), isTrue);
    });

    test('styles 同 key 值深合并,不同 key 并集', () {
      const base = CollectionMergeModel(
        styles: {'k': AnimalModel(name: '旺财', type: '小狗')},
      );
      const other = CollectionMergeModel(
        styles: {
          'k': AnimalModel(type: '猫咪'),
          'k2': AnimalModel(name: '小白'),
        },
      );
      final merged = base.merge(other);
      // 同 key:other 的 type 覆盖,base 的 name 保留(深合并而非替换)
      expect(merged.styles!['k']!.name, '旺财');
      expect(merged.styles!['k']!.type, '猫咪');
      expect(merged.styles!['k2']!.name, '小白');
    });

    test('counts 非空 Map 并集', () {
      const base = CollectionMergeModel(counts: {'a': 1, 'b': 2});
      const other = CollectionMergeModel(counts: {'b': 9});
      final merged = base.merge(other);
      expect(merged.counts, {'a': 1, 'b': 9});
    });

    test('plain 未标 useMerge:整体替换(对照)', () {
      const base = CollectionMergeModel(plain: {'a': 1, 'b': 2});
      const other = CollectionMergeModel(plain: {'c': 3});
      final merged = base.merge(other);
      expect(merged.plain, {'c': 3});
    });
  });

  group('copyWith / Map 集合合并', () {
    test('非 null 值并集合并(与嵌套可 merge 字段口径一致)', () {
      const base = CollectionMergeModel(vars: {'--a': 1, '--b': 2});
      final copy = base.copyWith(vars: {'--b': 9});
      expect(copy.vars, {'--a': 1, '--b': 9});
    });

    test('显式 null 置空', () {
      const base = CollectionMergeModel(vars: {'--a': 1}, plain: {'x': 1});
      final cleared = base.copyWith(vars: null, plain: null);
      expect(cleared.vars, isNull);
      expect(cleared.plain, isNull);
    });

    test('不传参保留原值', () {
      const base = CollectionMergeModel(vars: {'--a': 1});
      final copy = base.copyWith(plain: {'x': 1});
      expect(identical(copy.vars, base.vars), isTrue);
    });

    test('本侧为 null 时直取传入值', () {
      const base = CollectionMergeModel();
      final copy = base.copyWith(vars: {'--a': 1});
      expect(copy.vars, {'--a': 1});
    });

    test('styles 深合并', () {
      const base = CollectionMergeModel(styles: {'k': AnimalModel(name: '旺财')});
      final copy = base.copyWith(styles: {'k': const AnimalModel(type: '小狗')});
      expect(copy.styles!['k']!.name, '旺财');
      expect(copy.styles!['k']!.type, '小狗');
    });
  });
}
