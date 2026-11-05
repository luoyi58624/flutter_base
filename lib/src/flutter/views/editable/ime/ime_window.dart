import 'dart:math' as math;

import 'package:flutter/services.dart' show TextEditingValue, TextRange, TextSelection;

import '../model/grapheme_boundary.dart';
import '../model/text_document.dart';

/// IME 编辑窗口：doc 上一段 `[start, end)` 区间与平台 IME 的编辑值互相映射。
///
/// 大文档不能整篇塞给平台通道（每次击键全量序列化），因此只把**覆盖 caret /
/// composing 邻域的整行区间**（行数受 [maxCoverLines] 钳制）作为 IME 眼中的
/// "全文"。窗口内 offset 与 doc offset 只差一个 [start] 平移，映射是纯算术，
/// 可独立单测。
class ImeWindow {
  const ImeWindow({required this.start, required this.end});

  /// 窗口在 doc 中的起点（整行边界）。
  final int start;

  /// 窗口在 doc 中的终点（整行边界，不含下一行换行符）。
  final int end;

  int get length => end - start;

  /// 窗口覆盖行数上限：大选区（拖选 / 全选）不整段物化推平台——引擎组合只
  /// 需要 caret / composing 邻域上下文，通道负载必须与文档规模、选区规模都
  /// 无关。越窗的选区端点由 [valueOf] 钳到窗口边界，越窗替换由 IME client
  /// 扩回整个 doc 选区兑现。
  static const int maxCoverLines = 32;

  /// 普通窗口的 UTF-16 code unit 上限；超长单行会围绕 caret / composing
  /// 截取局部上下文，避免 minified 文件每次击键都把整行送入平台通道。
  /// 活跃 composing 或单个不可分割字素超过本值时以完整区间优先，不能截断
  /// 平台状态或 Unicode 字素。
  static const int maxCoverCodeUnits = 16 * 1024;

  /// 计算覆盖 [selection] 与 [composing] 的整行窗口。
  ///
  /// 常态（光标 / 行内选区）窗口就是 caret 所在逻辑行；跨行选区扩到覆盖行，
  /// 但覆盖行数超过 [maxCoverLines] 时收缩到 caret / composing 邻域。
  factory ImeWindow.cover(TextDocument doc, TextSelection selection, TextRange composing) {
    var lo = selection.isValid ? selection.start : 0;
    var hi = selection.isValid ? selection.end : 0;
    final composingActive = composing.isValid && !composing.isCollapsed;
    if (composingActive) {
      lo = math.min(lo, composing.start);
      hi = math.max(hi, composing.end);
    }
    var startLine = doc.lineIndexOf(math.max(0, lo));
    var endLine = doc.lineIndexOf(math.max(0, hi));
    if (endLine - startLine + 1 > maxCoverLines) {
      // 必含区间 = caret 行 ∪ composing 覆盖行（组合映射不许截断），
      // 两侧各留余量后仍不越出原覆盖区间。
      var mustLo = doc.lineIndexOf(math.max(0, selection.isValid ? selection.extentOffset : 0));
      var mustHi = mustLo;
      if (composingActive) {
        mustLo = math.min(mustLo, doc.lineIndexOf(math.max(0, composing.start)));
        mustHi = math.max(mustHi, doc.lineIndexOf(math.max(0, composing.end)));
      }
      final pad = math.max(0, (maxCoverLines - (mustHi - mustLo + 1)) ~/ 2);
      startLine = math.max(startLine, mustLo - pad);
      endLine = math.min(endLine, mustHi + pad);
    }
    final lineWindowStart = doc.lineStart(startLine);
    final lineWindowEnd = doc.lineEnd(endLine);
    if (lineWindowEnd - lineWindowStart <= maxCoverCodeUnits) {
      return ImeWindow(start: lineWindowStart, end: lineWindowEnd);
    }

    var mustStart = (selection.isValid ? selection.extentOffset : 0).clamp(lineWindowStart, lineWindowEnd);
    var mustEnd = mustStart;
    if (composingActive) {
      mustStart = math.min(mustStart, composing.start.clamp(lineWindowStart, lineWindowEnd));
      mustEnd = math.max(mustEnd, composing.end.clamp(lineWindowStart, lineWindowEnd));
    }
    final mustLength = mustEnd - mustStart;
    if (mustLength >= maxCoverCodeUnits) {
      return ImeWindow(
        start: textGraphemeBoundaryBeforeOrAt(doc, mustStart, lowerBound: lineWindowStart, upperBound: lineWindowEnd),
        end: textGraphemeBoundaryAfterOrAt(doc, mustEnd, lowerBound: lineWindowStart, upperBound: lineWindowEnd),
      );
    }

    final contextBudget = maxCoverCodeUnits - mustLength;
    var windowStart = math.max(lineWindowStart, mustStart - contextBudget ~/ 2);
    var windowEnd = math.min(lineWindowEnd, mustEnd + (contextBudget - (mustStart - windowStart)));
    if (windowEnd - windowStart < maxCoverCodeUnits) {
      windowStart = math.max(lineWindowStart, windowEnd - maxCoverCodeUnits);
    }

    // 先向外扩到完整 UAX #29 字素边界，再按整个字素从上下文更宽的一侧收回；
    // 必含区间与单个超长字素都不会被硬上限切开。
    windowStart = textGraphemeBoundaryBeforeOrAt(
      doc,
      windowStart,
      lowerBound: lineWindowStart,
      upperBound: lineWindowEnd,
    );
    windowEnd = textGraphemeBoundaryAfterOrAt(doc, windowEnd, lowerBound: lineWindowStart, upperBound: lineWindowEnd);
    while (windowEnd - windowStart > maxCoverCodeUnits) {
      final before = mustStart - windowStart;
      final after = windowEnd - mustEnd;
      var trimmed = false;
      if (before >= after && before > 0) {
        final next = nextTextGraphemeBoundary(doc, windowStart, lowerBound: lineWindowStart, upperBound: lineWindowEnd);
        if (next <= mustStart) {
          windowStart = next;
          trimmed = true;
        }
      }
      if (!trimmed && after > 0) {
        final previous = previousTextGraphemeBoundary(
          doc,
          windowEnd,
          lowerBound: lineWindowStart,
          upperBound: lineWindowEnd,
        );
        if (previous >= mustEnd) {
          windowEnd = previous;
          trimmed = true;
        }
      }
      if (!trimmed && before > 0) {
        final next = nextTextGraphemeBoundary(doc, windowStart, lowerBound: lineWindowStart, upperBound: lineWindowEnd);
        if (next <= mustStart) {
          windowStart = next;
          trimmed = true;
        }
      }
      if (!trimmed) break;
    }
    return ImeWindow(start: windowStart, end: windowEnd);
  }

  /// 读取文档窗口并组装推给平台的编辑值（窗口局部坐标）。
  TextEditingValue valueOf(TextDocument doc, TextSelection selection, TextRange composing) =>
      valueWithText(doc.getText(start, end), selection, composing);

  /// 复用调用方已经读取的窗口 [text] 组装平台编辑值。
  ///
  /// [text] 必须精确对应 `[start, end)`；IME client 用它避免选区独立变化时
  /// 重复复制同一窗口正文。
  TextEditingValue valueWithText(String text, TextSelection selection, TextRange composing) {
    assert(text.length == length, 'IME 窗口文本长度必须与窗口范围一致');
    return TextEditingValue(
      text: text,
      selection: selection.isValid ? selectionToLocal(selection) : const TextSelection.collapsed(offset: 0),
      composing: composing.isValid && !composing.isCollapsed
          ? TextRange(start: _toLocal(composing.start), end: _toLocal(composing.end))
          : TextRange.empty,
    );
  }

  int _toLocal(int docOffset) => (docOffset - start).clamp(0, length);

  /// doc 选区 → 窗口局部选区（越窗端点钳到窗口边界）。
  TextSelection selectionToLocal(TextSelection docSelection) {
    return TextSelection(
      baseOffset: _toLocal(docSelection.baseOffset),
      extentOffset: _toLocal(docSelection.extentOffset),
      affinity: docSelection.affinity,
    );
  }

  /// 窗口局部 offset → doc offset。
  int toDoc(int localOffset) => start + localOffset.clamp(0, length);

  /// 窗口局部选区 → doc 选区。
  TextSelection selectionToDoc(TextSelection local) {
    return TextSelection(
      baseOffset: toDoc(local.baseOffset),
      extentOffset: toDoc(local.extentOffset),
      affinity: local.affinity,
    );
  }

  /// 窗口局部 composing → doc composing。
  TextRange composingToDoc(TextRange local) {
    if (!local.isValid || local.isCollapsed) return TextRange.empty;
    return TextRange(start: toDoc(local.start), end: toDoc(local.end));
  }
}

/// 新旧文本的最小差异区间（公共前后缀裁剪）。
class TextDiff {
  const TextDiff({required this.start, required this.end, required this.inserted});

  /// 旧文本中被替换的区间 `[start, end)`。
  final int start;
  final int end;

  /// 替换成的新文本。
  final String inserted;

  bool get isNoop => start == end && inserted.isEmpty;

  /// 计算 [oldText] → [newText] 的最小替换。返回 null 表示完全相同。
  static TextDiff? diff(String oldText, String newText) {
    if (oldText == newText) return null;
    final oldLen = oldText.length;
    final newLen = newText.length;
    var prefix = 0;
    final maxPrefix = math.min(oldLen, newLen);
    while (prefix < maxPrefix && oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    final maxSuffix = math.min(oldLen, newLen) - prefix;
    while (suffix < maxSuffix && oldText.codeUnitAt(oldLen - 1 - suffix) == newText.codeUnitAt(newLen - 1 - suffix)) {
      suffix++;
    }
    return TextDiff(start: prefix, end: oldLen - suffix, inserted: newText.substring(prefix, newLen - suffix));
  }
}
