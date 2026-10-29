import 'package:flutter/services.dart';
import 'model/edit_interceptor.dart';
import 'model/edit_transaction.dart';
import 'model/edit_operation.dart';
import 'model/editable_selection.dart';

EditableEditInterception applyTextInputFormatters(EditableEditContext context, List<TextInputFormatter> formatters) {
  if (context.source == EditableEditSource.api) return const EditableEditInterception.allow();
  // TextInputFormatter 只处理平台已经确认的文本；活动 preedit 必须原样交给
  // IME 呈现，否则 digitsOnly 等过滤器会把拼音候选提前删除。compositionend
  // 的终态事务会再次经过本管线，并在那一刻统一格式化后再向数据源 flush。
  if (context.composingAfter.isValid && !context.composingAfter.isCollapsed) {
    return const EditableEditInterception.allow();
  }
  final oldText = context.document.text;
  final operations = [...context.operations]..sort((a, b) => a.normalizedStart.compareTo(b.normalizedStart));
  for (var i = 1; i < operations.length; i++) {
    if (operations[i].normalizedStart < operations[i - 1].normalizedEnd) {
      return const EditableEditInterception.allow();
    }
  }
  var proposed = oldText;
  for (final operation in operations.reversed) {
    final start = operation.normalizedStart.clamp(0, proposed.length);
    final end = operation.normalizedEnd.clamp(start, proposed.length);
    proposed = proposed.replaceRange(start, end, operation.text);
  }

  TextSelection clampSelection(TextSelection selection, int length) {
    if (!selection.isValid) return TextSelection.collapsed(offset: length);
    return TextSelection(
      baseOffset: selection.baseOffset.clamp(0, length),
      extentOffset: selection.extentOffset.clamp(0, length),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  TextRange clampComposing(TextRange range, int length) {
    if (!range.isValid || range.isCollapsed) return TextRange.empty;
    final start = range.start.clamp(0, length);
    final end = range.end.clamp(0, length);
    return start < end ? TextRange(start: start, end: end) : TextRange.empty;
  }

  int mapOffset(int offset) {
    var delta = 0;
    for (final operation in operations) {
      final start = operation.normalizedStart;
      final end = operation.normalizedEnd;
      if (offset < start) return offset + delta;
      if (offset <= end) return start + delta + operation.text.length;
      delta += operation.text.length - (end - start);
    }
    return offset + delta;
  }

  final previousSelection = context.selections.primaryTextSelection;
  final requestedSelection =
      context.selectionsAfter?.primaryTextSelection ??
      TextSelection(
        baseOffset: mapOffset(previousSelection.baseOffset),
        extentOffset: mapOffset(previousSelection.extentOffset),
        affinity: previousSelection.affinity,
        isDirectional: previousSelection.isDirectional,
      );

  final oldValue = TextEditingValue(
    text: oldText,
    selection: context.selections.primaryTextSelection,
    composing: context.composing,
  );
  var formatted = TextEditingValue(
    text: proposed,
    selection: clampSelection(requestedSelection, proposed.length),
    composing: clampComposing(context.composingAfter, proposed.length),
  );
  for (final formatter in formatters) {
    formatted = formatter.formatEditUpdate(oldValue, formatted);
  }
  if (formatted == oldValue) return const EditableEditInterception.reject('TextInputFormatter rejected input');
  final targetComposing = clampComposing(formatted.composing, formatted.text.length);
  final wasComposing = context.composingAfter.isValid && !context.composingAfter.isCollapsed;
  final staysComposing = targetComposing.isValid && !targetComposing.isCollapsed;
  if (wasComposing != staysComposing) {
    return const EditableEditInterception.reject('TextInputFormatter changed composing lifecycle');
  }
  final targetSelection = clampSelection(formatted.selection, formatted.text.length);
  if (formatted.text == proposed &&
      targetSelection == clampSelection(requestedSelection, proposed.length) &&
      targetComposing == clampComposing(context.composingAfter, proposed.length)) {
    return const EditableEditInterception.allow();
  }
  return EditableEditInterception.rewrite(
    EditTransaction(
      baseRevision: context.transaction.baseRevision,
      operations: [EditOperation.replace(0, oldText.length, formatted.text)],
      source: context.source,
      selectionsAfter: EditableSelectionSet.single(EditableSelection.fromTextSelection(targetSelection)),
      undoStopBefore: context.transaction.undoStopBefore,
      undoStopAfter: context.transaction.undoStopAfter,
    ),
    composingAfter: targetComposing,
  );
}
