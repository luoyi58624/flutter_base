import 'package:flutter/foundation.dart' show listEquals;

import 'document_version.dart';
import 'edit_operation.dart';
import 'editable_selection.dart';

/// 编辑事务的来源，用于撤销分组、回调与诊断。
enum EditableEditSource {
  /// 由公开编程接口发起。
  api,

  /// 由普通键盘文本输入发起。
  keyboard,

  /// 由输入法组合或提交发起。
  ime,

  /// 由平台自动填充服务发起。
  autofill,

  /// 由辅助技术的标准文本写入动作发起。
  accessibility,

  /// 由粘贴动作发起。
  paste,

  /// 由剪切动作发起。
  cut,

  /// 由编辑器内部选中文本拖放发起。
  dragDrop,

  /// 由编辑器命令发起。
  command,

  /// 由撤销动作发起。
  undo,

  /// 由重做动作发起。
  redo,
}

/// 基于指定文档基线提交的一组不可变编辑请求。
final class EditTransaction {
  /// 创建编辑事务，并防御性复制 [operations]。
  ///
  /// [baseRevision] 保留给同一控制器内同步构造并立即提交的兼容路径；异步结果或
  /// 可能跨控制器流转的事务应同时传入 [baseVersion]，由模型身份与修订共同校验。
  factory EditTransaction({
    required int baseRevision,
    DocumentVersion? baseVersion,
    required Iterable<EditOperation> operations,
    EditableEditSource source = EditableEditSource.api,
    EditableSelectionSet? selectionsAfter,
    bool undoStopBefore = true,
    bool undoStopAfter = true,
  }) {
    if (baseRevision < 0) {
      throw ArgumentError.value(baseRevision, 'baseRevision', '必须是非负修订号');
    }
    final copiedOperations = List<EditOperation>.unmodifiable(operations);
    for (var i = 0; i < copiedOperations.length; i++) {
      final operation = copiedOperations[i];
      if (operation.start < 0 || operation.end < 0) {
        throw ArgumentError.value(operation, 'operations[$i]', 'start 与 end 必须是非负 UTF-16 offset');
      }
    }
    return EditTransaction._(
      baseRevision: baseRevision,
      baseVersion: baseVersion,
      operations: copiedOperations,
      source: source,
      selectionsAfter: selectionsAfter,
      undoStopBefore: undoStopBefore,
      undoStopAfter: undoStopAfter,
    );
  }

  const EditTransaction._({
    required this.baseRevision,
    required this.baseVersion,
    required this.operations,
    required this.source,
    required this.selectionsAfter,
    required this.undoStopBefore,
    required this.undoStopAfter,
  });

  /// 操作所基于的文档修订号，仅用于同控制器同步兼容与诊断。
  ///
  /// 单独的整数无法区分两个同修订号模型；异步事务应同时提供 [baseVersion]。
  final int baseRevision;

  /// 可选的模型绑定强基线；非 null 时跨控制器或过期事务会在写入前失败。
  final DocumentVersion? baseVersion;

  /// 以事务原文坐标描述的只读操作列表。
  final List<EditOperation> operations;

  /// 本事务的输入来源。
  final EditableEditSource source;

  /// 应用完成后希望设置的选区；null 表示由引擎推导。
  final EditableSelectionSet? selectionsAfter;

  /// 是否在本事务之前建立撤销停止点。
  final bool undoStopBefore;

  /// 是否在本事务之后建立撤销停止点。
  final bool undoStopAfter;

  /// 按全部请求字段判断两个事务是否相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditTransaction &&
          baseRevision == other.baseRevision &&
          baseVersion == other.baseVersion &&
          listEquals(operations, other.operations) &&
          source == other.source &&
          selectionsAfter == other.selectionsAfter &&
          undoStopBefore == other.undoStopBefore &&
          undoStopAfter == other.undoStopAfter;

  /// 返回与值相等语义一致的哈希值。
  @override
  int get hashCode => Object.hash(
    baseRevision,
    baseVersion,
    Object.hashAll(operations),
    source,
    selectionsAfter,
    undoStopBefore,
    undoStopAfter,
  );
}
