import 'package:flutter_base/src/ui/utils/internal/bit_mask.dart';
import 'package:flutter_test/flutter_test.dart';

/// 双段字段位图回归，覆盖旧 53 位边界与新增高位字段。
void main() {
  const indexes = <int>[0, 1, 25, 29, 30, 31, 32, 40, 51, 52, 53, 54, 59];

  FieldMask maskOf(Iterable<int> values) {
    var mask = FieldMask.empty;
    for (final value in values) {
      mask = maskSetBit(mask, value);
    }
    return mask;
  }

  List<int> indexesOf(FieldMask mask) {
    final result = <int>[];
    var remaining = mask;
    while (remaining.isNotEmpty) {
      final index = maskLowestIndex(remaining);
      result.add(index);
      remaining = maskClearBit(remaining, index);
    }
    return result;
  }

  test('maskBit 覆盖两个 30 位分段', () {
    for (final index in indexes) {
      final mask = maskBit(index);
      expect(maskHas(mask, index), isTrue, reason: 'bit $index');
      expect(maskLowestIndex(mask), index, reason: 'bit $index');
      expect(maskClearBit(mask, index), FieldMask.empty, reason: 'bit $index');
    }
  });

  test('or / and / andNot 跨分段保持集合语义', () {
    final a = maskOf(<int>[0, 29, 30, 52, 54]);
    final b = maskOf(<int>[1, 29, 51, 52, 59]);

    expect(indexesOf(maskOr(a, b)), <int>[0, 1, 29, 30, 51, 52, 54, 59]);
    expect(indexesOf(maskAnd(a, b)), <int>[29, 52]);
    expect(indexesOf(maskAndNot(a, b)), <int>[0, 30, 54]);
  });

  test('55 个 transition 字段可同时置位并按序迭代', () {
    final mask = maskOf(List<int>.generate(55, (index) => index));
    expect(indexesOf(mask), List<int>.generate(55, (index) => index));
    expect(mask.low, lessThan(1 << 30));
    expect(mask.high, lessThan(1 << 30));
  });
}
