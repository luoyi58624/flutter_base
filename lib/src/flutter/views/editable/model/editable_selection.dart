import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart' show TextAffinity, TextSelection;

/// 可编辑文档中的不可变选区，偏移量统一使用 UTF-16 code unit 坐标。
final class EditableSelection {
  /// 创建锚点为 [anchor]、活动端为 [active] 的选区。
  const EditableSelection({
    required this.anchor,
    required this.active,
    this.affinity = TextAffinity.downstream,
    this.isDirectional = false,
    this.preferredX,
  }) : assert(anchor >= 0, 'anchor 必须是非负 UTF-16 offset'),
       assert(active >= 0, 'active 必须是非负 UTF-16 offset'),
       assert(
         preferredX == null || preferredX >= -double.maxFinite && preferredX <= double.maxFinite,
         'preferredX 必须是有限数值',
       );

  /// 创建折叠在 [offset] 的光标选区。
  const EditableSelection.collapsed({
    required int offset,
    this.affinity = TextAffinity.downstream,
    this.isDirectional = false,
    this.preferredX,
  }) : anchor = offset,
       active = offset,
       assert(offset >= 0, 'offset 必须是非负 UTF-16 offset'),
       assert(
         preferredX == null || preferredX >= -double.maxFinite && preferredX <= double.maxFinite,
         'preferredX 必须是有限数值',
       );

  /// 从 Flutter [TextSelection] 创建选区，并可附带垂直移动使用的 [preferredX]。
  factory EditableSelection.fromTextSelection(TextSelection selection, {double? preferredX}) {
    if (selection.baseOffset < 0 || selection.extentOffset < 0) {
      throw ArgumentError.value(selection, 'selection', 'TextSelection 的 baseOffset 与 extentOffset 必须非负');
    }
    if (preferredX != null && !preferredX.isFinite) {
      throw ArgumentError.value(preferredX, 'preferredX', '必须是有限数值');
    }
    return EditableSelection(
      anchor: selection.baseOffset,
      active: selection.extentOffset,
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
      preferredX: preferredX,
    );
  }

  /// 选区锚点的 UTF-16 offset。
  final int anchor;

  /// 光标活动端的 UTF-16 offset。
  final int active;

  /// 活动端落在换行等歧义位置时的视觉亲和方向。
  final TextAffinity affinity;

  /// 是否保留由用户明确建立的选区方向。
  final bool isDirectional;

  /// 垂直移动时希望保持的横向坐标，尚未建立目标时为 null。
  final double? preferredX;

  /// 不考虑拖选方向的选区起点。
  int get start => math.min(anchor, active);

  /// 不考虑拖选方向的选区终点。
  int get end => math.max(anchor, active);

  /// 选区是否折叠为单个光标。
  bool get isCollapsed => anchor == active;

  /// 转换为 Flutter 文本输入协议使用的选区。
  TextSelection get textSelection =>
      TextSelection(baseOffset: anchor, extentOffset: active, affinity: affinity, isDirectional: isDirectional);

  /// 复制选区；[clearPreferredX] 为 true 时清除横向目标坐标。
  EditableSelection copyWith({
    int? anchor,
    int? active,
    TextAffinity? affinity,
    bool? isDirectional,
    double? preferredX,
    bool clearPreferredX = false,
  }) {
    if (clearPreferredX && preferredX != null) {
      throw ArgumentError.value(preferredX, 'preferredX', 'clearPreferredX 为 true 时不能同时提供 preferredX');
    }
    return EditableSelection(
      anchor: anchor ?? this.anchor,
      active: active ?? this.active,
      affinity: affinity ?? this.affinity,
      isDirectional: isDirectional ?? this.isDirectional,
      preferredX: clearPreferredX ? null : preferredX ?? this.preferredX,
    );
  }

  /// 按全部值字段判断两个选区是否相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditableSelection &&
          anchor == other.anchor &&
          active == other.active &&
          affinity == other.affinity &&
          isDirectional == other.isDirectional &&
          preferredX == other.preferredX;

  /// 返回与值相等语义一致的哈希值。
  @override
  int get hashCode => Object.hash(anchor, active, affinity, isDirectional, preferredX);
}

/// 一个主选区与零到多个次选区组成的不可变集合。
final class EditableSelectionSet {
  /// 创建选区集合；本构造只做防御性复制，不改写选区顺序或范围。
  factory EditableSelectionSet({
    required EditableSelection primary,
    Iterable<EditableSelection> secondary = const [],
  }) => EditableSelectionSet._(primary, List<EditableSelection>.unmodifiable(secondary));

  EditableSelectionSet._(this.primary, this.secondary);

  /// 创建只含一个 [selection] 的选区集合。
  factory EditableSelectionSet.single(EditableSelection selection) => EditableSelectionSet(primary: selection);

  /// 从 Flutter 选区序列创建集合，并用 [primaryIndex] 指定主选区。
  factory EditableSelectionSet.fromTextSelections(Iterable<TextSelection> selections, {int primaryIndex = 0}) {
    final values = List<TextSelection>.of(selections, growable: false);
    if (values.isEmpty) {
      throw ArgumentError.value(selections, 'selections', '选区序列不能为空');
    }
    if (primaryIndex < 0 || primaryIndex >= values.length) {
      throw RangeError.range(primaryIndex, 0, values.length - 1, 'primaryIndex');
    }
    final converted = values.map(EditableSelection.fromTextSelection).toList(growable: false);
    return EditableSelectionSet(
      primary: converted[primaryIndex],
      secondary: [
        for (var i = 0; i < converted.length; i++)
          if (i != primaryIndex) converted[i],
      ],
    );
  }

  /// 首要光标或拖选范围。
  final EditableSelection primary;

  /// 不含主选区的只读次选区列表。
  final List<EditableSelection> secondary;

  /// 以主选区在前的只读完整选区列表。
  List<EditableSelection> get all => List<EditableSelection>.unmodifiable([primary, ...secondary]);

  /// 集合中的选区总数。
  int get length => secondary.length + 1;

  /// 是否只包含主选区。
  bool get single => secondary.isEmpty;

  /// 主选区对应的 Flutter 文本选区。
  TextSelection get primaryTextSelection => primary.textSelection;

  /// 以主选区在前的只读 Flutter 文本选区列表。
  List<TextSelection> get textSelections =>
      List<TextSelection>.unmodifiable(all.map((selection) => selection.textSelection));

  /// 按主选区和次选区顺序逐项判断值是否相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditableSelectionSet && primary == other.primary && listEquals(secondary, other.secondary);

  /// 返回与值相等语义一致的哈希值。
  @override
  int get hashCode => Object.hash(primary, Object.hashAll(secondary));
}
