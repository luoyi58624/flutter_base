import 'dart:math' as math;

/// 一次基于事务原文 UTF-16 坐标的不可变替换操作。
final class EditOperation {
  /// 创建用 [text] 替换 `[start, end)` 的操作，反向端点可由 [normalized] 归一化。
  const EditOperation({required this.start, required this.end, required this.text})
    : assert(start >= 0, 'start 必须是非负 UTF-16 offset'),
      assert(end >= 0, 'end 必须是非负 UTF-16 offset');

  /// 创建在 [offset] 插入 [text] 的操作。
  const EditOperation.insert(int offset, this.text)
    : start = offset,
      end = offset,
      assert(offset >= 0, 'offset 必须是非负 UTF-16 offset');

  /// 创建删除 `[start, end)` 的操作。
  const EditOperation.delete(int start, int end)
    : start = start,
      end = end,
      text = '',
      assert(start >= 0, 'start 必须是非负 UTF-16 offset'),
      assert(end >= 0, 'end 必须是非负 UTF-16 offset');

  /// 创建用 [text] 替换 `[start, end)` 的操作。
  const EditOperation.replace(int start, int end, this.text)
    : start = start,
      end = end,
      assert(start >= 0, 'start 必须是非负 UTF-16 offset'),
      assert(end >= 0, 'end 必须是非负 UTF-16 offset');

  /// 调用方给出的第一个 UTF-16 offset。
  final int start;

  /// 调用方给出的第二个 UTF-16 offset。
  final int end;

  /// 替换区间后写入的文本。
  final String text;

  /// 不考虑端点顺序的替换起点。
  int get normalizedStart => math.min(start, end);

  /// 不考虑端点顺序的替换终点。
  int get normalizedEnd => math.max(start, end);

  /// 返回端点已按升序排列的等价操作。
  EditOperation get normalized => start <= end ? this : EditOperation(start: end, end: start, text: text);

  /// 按起点、终点与替换文本判断值是否相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditOperation && start == other.start && end == other.end && text == other.text;

  /// 返回与值相等语义一致的哈希值。
  @override
  int get hashCode => Object.hash(start, end, text);
}
