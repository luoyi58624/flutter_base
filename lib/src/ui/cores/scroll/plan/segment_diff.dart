import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../spec/segment_spec.dart';
import 'segment_plan.dart';

/// 段级 diff 与度量保留（计划 §5）：新旧段序列对齐 → 逐段内容
/// diff → 折算成行/item 空间的 splice 序列，供 Fenwick 与锚点/注册表 remap
/// 消费。目标：未变段的实测行高**原位保留**——无限流分页（itemCount +N）、
/// 中部段增删都不再全量重置度量模型。
///
/// 纯数据层：不触碰渲染，可脱离 Flutter 环境单测（Widget 仅作 identity 载体）。

/// 单段的内容变化。
sealed class SegmentContentChange {
  const SegmentContentChange();
}

/// 结构不变（per-item widget 实例更新照常流出，不在本层表达）。
final class SegmentUnchanged extends SegmentContentChange {
  /// 单例语义的常量构造。
  const SegmentUnchanged();
}

/// 段内 item 区间替换：`[localStart, localStart+deleteCount)` 删除、原位插入
/// [insertCount] 个。[oldLocalForNewLocal] 非 null 时为 keyed 重排映射
/// （newLocal → oldLocal，度量按身份迁移；null 时按 splice 平移语义保留）。
final class SegmentItemsSpliced extends SegmentContentChange {
  /// 创建段内 splice。
  const SegmentItemsSpliced({
    required this.localStart,
    required this.deleteCount,
    required this.insertCount,
    this.oldLocalForNewLocal,
  }) : assert(localStart >= 0),
       assert(deleteCount >= 0),
       assert(insertCount >= 0),
       assert(deleteCount > 0 || insertCount > 0);

  /// 变化区间起点（段内局部 item 序）。
  final int localStart;

  /// 删除 item 数。
  final int deleteCount;

  /// 插入 item 数。
  final int insertCount;

  /// keyed 重排映射（newLocal → oldLocal）；仅改动窗口两侧全 keyed 且严格
  /// 双射时产出（承旧 keyed remap 口径），否则 null。
  final Map<int, int>? oldLocalForNewLocal;
}

/// 段行结构不可保：整段行替换（度量丢弃；grid 行高固定可算，重建零损失）。
final class SegmentRebuilt extends SegmentContentChange {
  /// 单例语义的常量构造。
  const SegmentRebuilt();
}

/// 一对新旧段的配对关系。[oldIndex] 为 null = 新增段；[newIndex] 为 null =
/// 移除段；两者皆非 null 时 [change] 描述段内内容变化。
final class SegmentPairing {
  /// 创建配对。
  const SegmentPairing({this.oldIndex, this.newIndex, this.change})
    : assert(oldIndex != null || newIndex != null),
      assert((oldIndex == null || newIndex == null) == (change == null));

  /// 旧段序号。
  final int? oldIndex;

  /// 新段序号。
  final int? newIndex;

  /// 段内内容变化（仅配对段有）。
  final SegmentContentChange? change;
}

/// 新旧段序列的完整 diff。
final class SegmentListDiff {
  const SegmentListDiff._(this.pairings, this.anyChange);

  /// 按（old 序为主的）顺序排列的配对序列。
  final List<SegmentPairing> pairings;

  /// 是否存在任何结构变化（全 [SegmentUnchanged] 时 false）。
  final bool anyChange;

  /// 计算新旧段序列 diff：alignmentKey 前后缀收缩配对；中段长度相等且类型
  /// 逐位相同 → 顺序配对，否则整体删增（段级增删本就少见，P0 保守）。
  static SegmentListDiff compute(List<SegmentSpec> oldSegments, List<SegmentSpec> newSegments) {
    final oldLength = oldSegments.length;
    final newLength = newSegments.length;
    final minLength = oldLength < newLength ? oldLength : newLength;

    var prefix = 0;
    while (prefix < minLength && _alignable(oldSegments[prefix], newSegments[prefix])) {
      prefix++;
    }
    var oldSuffix = oldLength;
    var newSuffix = newLength;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        _alignable(oldSegments[oldSuffix - 1], newSegments[newSuffix - 1])) {
      oldSuffix--;
      newSuffix--;
    }

    final pairings = <SegmentPairing>[];
    var anyChange = false;
    void pair(int oldIndex, int newIndex) {
      final change = _contentChangeOf(oldSegments[oldIndex], newSegments[newIndex]);
      if (change is! SegmentUnchanged) anyChange = true;
      pairings.add(SegmentPairing(oldIndex: oldIndex, newIndex: newIndex, change: change));
    }

    for (var i = 0; i < prefix; i++) {
      pair(i, i);
    }
    final oldMiddle = oldSuffix - prefix;
    final newMiddle = newSuffix - prefix;
    if (oldMiddle == newMiddle && _middleTypesMatch(oldSegments, newSegments, prefix, oldMiddle)) {
      for (var i = 0; i < oldMiddle; i++) {
        pair(prefix + i, prefix + i);
      }
    } else {
      for (var i = prefix; i < oldSuffix; i++) {
        anyChange = true;
        pairings.add(SegmentPairing(oldIndex: i));
      }
      for (var i = prefix; i < newSuffix; i++) {
        anyChange = true;
        pairings.add(SegmentPairing(newIndex: i));
      }
    }
    for (var i = 0; i < oldLength - oldSuffix; i++) {
      pair(oldSuffix + i, newSuffix + i);
    }
    return SegmentListDiff._(pairings, anyChange);
  }

  static bool _alignable(SegmentSpec a, SegmentSpec b) => listEquals(a.alignmentKey, b.alignmentKey);

  static bool _middleTypesMatch(List<SegmentSpec> oldSegments, List<SegmentSpec> newSegments, int start, int count) {
    for (var i = 0; i < count; i++) {
      if (oldSegments[start + i].runtimeType != newSegments[start + i].runtimeType) return false;
    }
    return true;
  }

  static SegmentContentChange _contentChangeOf(SegmentSpec oldSegment, SegmentSpec newSegment) {
    switch ((oldSegment, newSegment)) {
      case (StaticSegment(:final child), StaticSegment(child: final newChild)):
        return _sameChildIdentity(child, newChild) ? const SegmentUnchanged() : const SegmentRebuilt();
      case (final LinearSegment old, final LinearSegment next):
        if (old.key != next.key || old.geometry != next.geometry || old.fixed?.itemStride != next.fixed?.itemStride) {
          return const SegmentRebuilt();
        }
        return _sourceChange(old.source, next.source) ?? const SegmentUnchanged();
      case (final GridSegment old, final GridSegment next):
        if (!listEquals(old.alignmentKey, next.alignmentKey)) return const SegmentRebuilt();
        final change = _sourceChange(old.source, next.source);
        if (change == null) return const SegmentUnchanged();
        // grid 只接受尾部 splice（中部 splice 平移列相位、行结构整体变）：
        // 变化触到旧尾即尾部；keyed 重排对 grid 无意义（列相位），丢弃 map。
        if (change is SegmentItemsSpliced &&
            change.oldLocalForNewLocal == null &&
            change.localStart + change.deleteCount == old.itemCount) {
          return change;
        }
        return const SegmentRebuilt();
      default:
        // 类型不同的配对只可能来自防御路径：按重建处理。
        return const SegmentRebuilt();
    }
  }

  /// 计算 item 来源的变化；null = 无结构变化。
  static SegmentContentChange? _sourceChange(SegmentItemSource oldSource, SegmentItemSource newSource) {
    if (oldSource is MaterializedItemSource && newSource is MaterializedItemSource) {
      return _materializedChange(oldSource.children, newSource.children);
    }
    // builder 参与的一切形态（builder×builder / 物化↔builder 切换）走
    // index-is-identity：count 变化按尾部 splice，count 相等视为无结构变化
    // （行 remount 自愈内容差异）。绝不扫描 builder 内容——扫描即全量物化。
    final oldCount = oldSource.itemCount;
    final newCount = newSource.itemCount;
    if (oldCount == newCount) return null;
    final shared = oldCount < newCount ? oldCount : newCount;
    return SegmentItemsSpliced(localStart: shared, deleteCount: oldCount - shared, insertCount: newCount - shared);
  }

  static SegmentContentChange? _materializedChange(List<Widget> oldChildren, List<Widget> newChildren) {
    if (identical(oldChildren, newChildren)) return null;
    var prefix = 0;
    final minLength = oldChildren.length < newChildren.length ? oldChildren.length : newChildren.length;
    while (prefix < minLength && _sameChildIdentity(oldChildren[prefix], newChildren[prefix])) {
      prefix++;
    }
    var oldSuffix = oldChildren.length;
    var newSuffix = newChildren.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        _sameChildIdentity(oldChildren[oldSuffix - 1], newChildren[newSuffix - 1])) {
      oldSuffix--;
      newSuffix--;
    }
    if (prefix == oldChildren.length && prefix == newChildren.length) return null;
    return SegmentItemsSpliced(
      localStart: prefix,
      deleteCount: oldSuffix - prefix,
      insertCount: newSuffix - prefix,
      oldLocalForNewLocal: _keyedRemap(oldChildren, newChildren, prefix, oldSuffix, newSuffix),
    );
  }

  /// keyed 重排映射（承旧 keyed remap 口径）：改动窗口两侧全 keyed、key 唯一
  /// 且严格双射（旧窗口每个 key 都被新窗口引用、runtimeType 一致）才产出；
  /// 任何一条不满足返回 null 走普通 splice。
  static Map<int, int>? _keyedRemap(
    List<Widget> oldChildren,
    List<Widget> newChildren,
    int start,
    int oldEnd,
    int newEnd,
  ) {
    if (oldEnd <= start || newEnd <= start) return null;
    final oldLocalByKey = <Key, int>{};
    for (var i = start; i < oldEnd; i++) {
      final key = oldChildren[i].key;
      if (key == null || oldLocalByKey.containsKey(key)) return null;
      oldLocalByKey[key] = i;
    }
    final oldLocalForNewLocal = <int, int>{};
    for (var i = start; i < newEnd; i++) {
      final key = newChildren[i].key;
      if (key == null) return null;
      final oldLocal = oldLocalByKey.remove(key);
      if (oldLocal == null || oldChildren[oldLocal].runtimeType != newChildren[i].runtimeType) return null;
      oldLocalForNewLocal[i] = oldLocal;
    }
    if (oldLocalByKey.isNotEmpty) return null;
    return oldLocalForNewLocal;
  }

  static bool _sameChildIdentity(Widget oldChild, Widget newChild) {
    if (identical(oldChild, newChild)) return true;
    return oldChild.key == newChild.key && oldChild.runtimeType == newChild.runtimeType;
  }
}

/// 行空间 splice（old 全局行坐标）：删 [deleteRows] 行、插 [insertRows] 行。
/// [oldRowForNewRow] 非 null 时为 keyed 度量迁移映射（new 全局行 → old 全局
/// 行），消费方按映射搬实测值而非平移。
final class RowSplice {
  /// 创建行 splice。
  const RowSplice({required this.rowStart, required this.deleteRows, required this.insertRows, this.oldRowForNewRow});

  /// 起点（old 全局行号）。
  final int rowStart;

  /// 删除行数。
  final int deleteRows;

  /// 插入行数。
  final int insertRows;

  /// keyed 度量迁移映射（new 全局行 → old 全局行）。
  final Map<int, int>? oldRowForNewRow;
}

/// item 空间 splice（old 全局 item 坐标）：供锚点/选区/sticky/keepAlive
/// 注册表 remap 消费。
final class ItemSplice {
  /// 创建 item splice。
  const ItemSplice({required this.itemStart, required this.deleteItems, required this.insertItems});

  /// 起点（old 全局 item index）。
  final int itemStart;

  /// 删除 item 数。
  final int deleteItems;

  /// 插入 item 数。
  final int insertItems;
}

/// 段计划过渡：把 [SegmentListDiff] 折算成行/item 空间的 splice 序列。
/// 序列按 old 坐标升序；应用到 Fenwick / 注册表时**从后往前**，避免前面的
/// splice 平移后面的坐标。
final class SegmentPlanTransition {
  const SegmentPlanTransition._(this.rowSplices, this.itemSplices);

  /// 行空间 splice 序列（升序）。
  final List<RowSplice> rowSplices;

  /// item 空间 splice 序列（升序）。
  final List<ItemSplice> itemSplices;

  /// 无任何结构变化。
  bool get isEmpty => rowSplices.isEmpty && itemSplices.isEmpty;

  /// 由新旧计划与 diff 折算过渡。
  static SegmentPlanTransition compute({
    required SegmentPlan oldPlan,
    required SegmentPlan newPlan,
    required SegmentListDiff diff,
  }) {
    final rowSplices = <RowSplice>[];
    final itemSplices = <ItemSplice>[];
    // 新增段的插入点 = 前一个存在于 old 的段的行/item 终点。
    var lastOldRowEnd = 0;
    var lastOldItemEnd = 0;
    for (final pairing in diff.pairings) {
      final oldIndex = pairing.oldIndex;
      final newIndex = pairing.newIndex;
      if (oldIndex == null) {
        // 新增段：old 坐标系原位插入。
        final rows = newPlan.rowCountOf(newIndex!);
        final items = newPlan.segments[newIndex].itemCount;
        if (rows > 0) rowSplices.add(RowSplice(rowStart: lastOldRowEnd, deleteRows: 0, insertRows: rows));
        if (items > 0) itemSplices.add(ItemSplice(itemStart: lastOldItemEnd, deleteItems: 0, insertItems: items));
        continue;
      }
      final oldRowStart = oldPlan.rowStartOf(oldIndex);
      final oldRows = oldPlan.rowCountOf(oldIndex);
      final oldItemStart = oldPlan.itemStartOf(oldIndex);
      final oldItems = oldPlan.segments[oldIndex].itemCount;
      lastOldRowEnd = oldRowStart + oldRows;
      lastOldItemEnd = oldItemStart + oldItems;
      if (newIndex == null) {
        // 移除段。
        if (oldRows > 0) rowSplices.add(RowSplice(rowStart: oldRowStart, deleteRows: oldRows, insertRows: 0));
        if (oldItems > 0) itemSplices.add(ItemSplice(itemStart: oldItemStart, deleteItems: oldItems, insertItems: 0));
        continue;
      }
      switch (pairing.change!) {
        case SegmentUnchanged():
          break;
        case SegmentRebuilt():
          final newRows = newPlan.rowCountOf(newIndex);
          final newItems = newPlan.segments[newIndex].itemCount;
          if (oldRows > 0 || newRows > 0) {
            rowSplices.add(RowSplice(rowStart: oldRowStart, deleteRows: oldRows, insertRows: newRows));
          }
          if (oldItems > 0 || newItems > 0) {
            itemSplices.add(ItemSplice(itemStart: oldItemStart, deleteItems: oldItems, insertItems: newItems));
          }
        case SegmentItemsSpliced(:final localStart, :final deleteCount, :final insertCount, :final oldLocalForNewLocal):
          itemSplices.add(
            ItemSplice(itemStart: oldItemStart + localStart, deleteItems: deleteCount, insertItems: insertCount),
          );
          final oldSegment = oldPlan.segments[oldIndex];
          if (oldSegment is GridSegment) {
            // grid 已保证尾部变化：首个受影响行起整段行替换（行高固定，
            // 重建零测量损失；部分行的 item 集变化也被覆盖）。
            final columns = oldPlan.columnsOf(oldIndex);
            final firstChangedRow = localStart ~/ columns;
            final newRows = newPlan.rowCountOf(newIndex);
            rowSplices.add(
              RowSplice(
                rowStart: oldRowStart + firstChangedRow,
                deleteRows: oldRows - firstChangedRow,
                insertRows: newRows - firstChangedRow,
              ),
            );
          } else {
            // linear：行 == item，splice 直接平移；keyed 映射平移到全局行号。
            Map<int, int>? oldRowForNewRow;
            final localMap = oldLocalForNewLocal;
            if (localMap != null) {
              final newRowStart = newPlan.rowStartOf(newIndex);
              oldRowForNewRow = <int, int>{
                for (final MapEntry(key: newLocal, value: oldLocal) in localMap.entries)
                  newRowStart + newLocal: oldRowStart + oldLocal,
              };
            }
            rowSplices.add(
              RowSplice(
                rowStart: oldRowStart + localStart,
                deleteRows: deleteCount,
                insertRows: insertCount,
                oldRowForNewRow: oldRowForNewRow,
              ),
            );
          }
      }
    }
    return SegmentPlanTransition._(rowSplices, itemSplices);
  }
}
