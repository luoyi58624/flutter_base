/// 跨平台安全的 transition 字段位图。
///
/// dart2js / DDC 的原生 int 位运算只有 32 位，JS number 又只能精确表示
/// 53 位整数。这里把位图拆为两个 30 位分段，让每次位运算都留在 JS 的有符号
/// 32 位安全区间，并把字段容量扩到 60。
/// transition 字段位图，按 30 位拆成两个跨平台安全分段。
final class FieldMask {
  const FieldMask._(this.low, this.high);

  /// 空位图。
  static const FieldMask empty = FieldMask._(0, 0);

  /// bit 0..29。
  final int low;

  /// bit 30..59。
  final int high;

  /// 是否没有任何置位。
  bool get isEmpty => low == 0 && high == 0;

  /// 是否至少有一位置位。
  bool get isNotEmpty => !isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FieldMask && low == other.low && high == other.high;

  @override
  int get hashCode => Object.hash(low, high);
}

/// 每段位宽；bit 0..29 不触及 JS 有符号 32 位的符号位。
const int _segmentBits = 30;

/// 单 bit 位图，[index] 允许 0..59。
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
FieldMask maskBit(int index) {
  assert(index >= 0 && index < _segmentBits * 2, 'mask bit index 越界: $index');
  if (index < _segmentBits) return FieldMask._(1 << index, 0);
  return FieldMask._(0, 1 << (index - _segmentBits));
}

/// 在现有位图中置位一个 bit，避免先构造单 bit 位图。
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
FieldMask maskSetBit(FieldMask mask, int index) {
  assert(index >= 0 && index < _segmentBits * 2, 'mask bit index 越界: $index');
  if (index < _segmentBits) return FieldMask._(mask.low | (1 << index), mask.high);
  return FieldMask._(mask.low, mask.high | (1 << (index - _segmentBits)));
}

/// 位或。
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
FieldMask maskOr(FieldMask a, FieldMask b) => FieldMask._(a.low | b.low, a.high | b.high);

/// 位与。
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
FieldMask maskAnd(FieldMask a, FieldMask b) => FieldMask._(a.low & b.low, a.high & b.high);

/// 差集（a & ~b）。
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
FieldMask maskAndNot(FieldMask a, FieldMask b) => FieldMask._(a.low & ~b.low, a.high & ~b.high);

/// 某 bit 是否置位。
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
bool maskHas(FieldMask mask, int index) {
  assert(index >= 0 && index < _segmentBits * 2, 'mask bit index 越界: $index');
  if (index < _segmentBits) return (mask.low >> index) & 1 != 0;
  return (mask.high >> (index - _segmentBits)) & 1 != 0;
}

/// 最低置位的字段 index。
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
int maskLowestIndex(FieldMask mask) {
  assert(mask.isNotEmpty, 'maskLowestIndex 要求非空 mask');
  if (mask.low != 0) return (mask.low & -mask.low).bitLength - 1;
  return _segmentBits + (mask.high & -mask.high).bitLength - 1;
}

/// 清除一个已置位的 bit。
@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
FieldMask maskClearBit(FieldMask mask, int index) {
  assert(maskHas(mask, index), 'maskClearBit 要求该位已置 1: bit $index');
  if (index < _segmentBits) return FieldMask._(mask.low & ~(1 << index), mask.high);
  return FieldMask._(mask.low, mask.high & ~(1 << (index - _segmentBits)));
}
