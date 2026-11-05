import 'package:flutter/services.dart' show TextRange;

import 'edit_operation.dart';
import 'edit_transaction.dart';
import 'editable_selection.dart';
import 'text_document.dart';

/// 同步检查或改写一整笔编辑事务的回调。
///
/// 回调执行期间控制器处于只读阶段，不能同步发起另一笔编辑；需要联动编辑时应把
/// 后续操作排到微任务或下一帧。
typedef EditableEditInterceptor = EditableEditInterception Function(EditableEditContext context);

/// 拦截器执行时可见的不可变事务快照。
final class EditableEditContext {
  /// 创建事务拦截上下文；通常只由可编辑控制器内部构造。
  const EditableEditContext({
    required this.document,
    required this.revision,
    required this.selections,
    required this.composing,
    required this.transaction,
    required this.composingAfter,
  });

  /// 事务执行前的只读文档门面。
  final TextDocument document;

  /// 事务执行前的文档修订号。
  final int revision;

  /// 事务执行前的完整选区集合。
  final EditableSelectionSet selections;

  /// 事务执行前的输入法组合区间。
  final TextRange composing;

  /// 当前管线阶段准备执行的完整事务；前序拦截器的改写会反映在这里。
  final EditTransaction transaction;

  /// 本次事务希望写入的输入法组合区间。
  final TextRange composingAfter;

  /// 当前事务的输入来源。
  EditableEditSource get source => transaction.source;

  /// 当前事务的整组原文坐标 raw 操作；内建单行与长度策略尚未改写文本。
  List<EditOperation> get operations => transaction.operations;

  /// 当前事务希望落地的选区；null 表示交给控制器按最终编辑结果推导。
  EditableSelectionSet? get selectionsAfter => transaction.selectionsAfter;
}

/// 一次事务拦截的明确裁决：放行、整笔改写或整笔拒绝。
sealed class EditableEditInterception {
  const EditableEditInterception();

  /// 不改写当前事务并交给下一个拦截器。
  const factory EditableEditInterception.allow() = EditableEditAllowed;

  /// 用 [transaction] 的操作与目标选区改写当前事务，再交给下一个拦截器。
  ///
  /// 基线修订、来源及 undo 分组边界必须与当前事务一致，避免 formatter 伪造
  /// undo/redo 或偷偷改变历史语义；[composingAfter] 为 null 时保留当前目标组合区间，
  /// 非 null 时可调整区间，但不能借此开始或结束一个组合会话。改写使文本长度
  /// 变化时必须同时修正 [EditTransaction.selectionsAfter]，null 仍表示由引擎推导。
  const factory EditableEditInterception.rewrite(EditTransaction transaction, {TextRange? composingAfter}) =
      EditableEditRewritten;

  /// 拒绝整笔事务；API 来源会抛 [EditableEditRejectedException]，框架输入来源安静拒绝。
  const factory EditableEditInterception.reject([Object? reason]) = EditableEditRejected;
}

/// 放行当前事务的拦截结果。
final class EditableEditAllowed extends EditableEditInterception {
  /// 创建放行结果。
  const EditableEditAllowed();
}

/// 整笔改写当前事务的拦截结果。
final class EditableEditRewritten extends EditableEditInterception {
  /// 创建改写结果。
  const EditableEditRewritten(this.transaction, {this.composingAfter});

  /// 替代当前管线事务的新事务。
  final EditTransaction transaction;

  /// 替代当前目标组合区间；null 表示沿用当前管线值。
  final TextRange? composingAfter;
}

/// 整笔拒绝当前事务的拦截结果。
final class EditableEditRejected extends EditableEditInterception {
  /// 创建拒绝结果，并可携带业务侧诊断原因。
  const EditableEditRejected([this.reason]);

  /// 业务侧提供的可选拒绝原因。
  final Object? reason;
}

/// 编辑事务被同步拦截器明确拒绝时抛出的异常。
final class EditableEditRejectedException implements Exception {
  /// 创建拒绝异常。
  const EditableEditRejectedException({required this.source, this.reason});

  /// 被拒绝事务的输入来源。
  final EditableEditSource source;

  /// 拦截器提供的可选拒绝原因。
  final Object? reason;

  /// 返回适合日志与测试诊断的错误描述。
  @override
  String toString() => reason == null
      ? 'EditableEditRejectedException: $source 事务被输入拦截器拒绝。'
      : 'EditableEditRejectedException: $source 事务被输入拦截器拒绝：$reason';
}
