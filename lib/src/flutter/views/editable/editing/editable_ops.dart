import 'dart:math' as math;

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';

import '../editable_controller.dart';
import '../model/edit_operation.dart';
import '../model/edit_transaction.dart';
import '../model/editable_selection.dart';
import '../model/grapheme_boundary.dart';
import '../projection/editable_line_projection.dart';
import 'editable_layout_query.dart';
import 'editable_word_navigator.dart';

/// caret 移动语义。
enum CaretMotion {
  charLeft,
  charRight,
  wordLeft,
  wordRight,
  lineStart,
  lineEnd,
  docStart,
  docEnd,
  up,
  down,
  pageUp,
  pageDown,
}

/// 普通文本的光标移动、删除、选中与剪贴板操作。
class EditableOps {
  EditableOps({
    required this.controller,
    required this.layout,
    required this.pageExtent,
    this.lineProjection,
    this.canCommitCut,
    this.canCommitPaste,
    this.wordBoundary,
  });

  final TextRange Function(TextPosition)? wordBoundary;
  final EditableController controller;
  final EditableLayoutQuery layout;

  /// 可选的可见行投影；只借用，不接管生命周期。
  final EditableLineProjection? lineProjection;

  /// 缩进与词边界使用的编辑器行为选项。

  EditableWordNavigator? _wordNavigatorInstance;

  EditableWordNavigator get _wordNavigator => _wordNavigatorInstance ??= EditableWordNavigator(
    controller.document,
    wordSeparators: EditableWordNavigator.defaultWordSeparators,
  );

  /// 当前实例累计创建的词导航器数；惰性缓存使其只能为 0 或 1。
  @visibleForTesting
  int get debugWordNavigatorCreationCount => _wordNavigatorInstance == null ? 0 : 1;

  /// 视口主轴高度（PageUp / PageDown 用），由视图层提供。
  final double Function() pageExtent;

  /// 异步剪贴板写入完成后、真正删除文档前的最后守卫。
  final bool Function()? canCommitCut;

  /// 异步剪贴板读取完成后、真正粘贴文本前的最后守卫。
  final bool Function()? canCommitPaste;

  /// 同时移动全部 caret，或扩展全部选区。
  void move(CaretMotion motion, {bool extend = false}) {
    final vertical = switch (motion) {
      CaretMotion.up || CaretMotion.down || CaretMotion.pageUp || CaretMotion.pageDown => true,
      _ => false,
    };
    final current = controller.selections;
    EditableSelection moveOne(EditableSelection selection) {
      // 非扩展左右移动先把各自非折叠选区收到对应边，不额外跨字符。
      if (!extend && !selection.isCollapsed) {
        if (motion == CaretMotion.charLeft) {
          final visual = layout.horizontalSelectionEdge(
            TextRange(start: selection.start, end: selection.end),
            left: true,
          );
          final edge = visual ?? TextPosition(offset: selection.start);
          final visible = _projectPositionForMotion(edge, forward: edge.offset >= selection.end);
          return EditableSelection.collapsed(offset: visible.offset, affinity: visible.affinity);
        }
        if (motion == CaretMotion.charRight) {
          final visual = layout.horizontalSelectionEdge(
            TextRange(start: selection.start, end: selection.end),
            left: false,
          );
          final edge = visual ?? TextPosition(offset: selection.end);
          final visible = _projectPositionForMotion(edge, forward: edge.offset > selection.start);
          return EditableSelection.collapsed(offset: visible.offset, affinity: visible.affinity);
        }
      }
      final position = TextPosition(offset: selection.active, affinity: selection.affinity);
      final preferredX = vertical ? selection.preferredX ?? layout.caretXFor(position) : null;
      final target = _resolveMotion(motion, position, preferredX: preferredX);
      if (target == null) {
        return vertical ? selection.copyWith(preferredX: preferredX) : selection.copyWith(clearPreferredX: true);
      }
      if (vertical) {
        return selection.copyWith(
          anchor: extend ? selection.anchor : target.offset,
          active: target.offset,
          affinity: target.affinity,
          isDirectional: extend ? selection.isDirectional : false,
          preferredX: preferredX,
        );
      }
      return selection.copyWith(
        anchor: extend ? selection.anchor : target.offset,
        active: target.offset,
        affinity: target.affinity,
        isDirectional: extend ? selection.isDirectional : false,
        clearPreferredX: true,
      );
    }

    controller.setSelections(
      EditableSelectionSet(primary: moveOne(current.primary), secondary: current.secondary.map(moveOne)),
    );
  }

  /// 按辅助技术的逻辑前后方向移动光标。
  ///
  /// [byWord] 为 false 时按完整 Unicode 字素移动；为 true 时跳到相邻非空白
  /// 词段的起点。该语义刻意不复用左右方向键：双向文本中的“前进/后退”按
  /// 文档 offset 递增/递减，而 Left/Right 是视觉方向。
  ///
  /// 默认只更新主光标并清除次光标，契合无障碍平台语义；[preserveSecondary]
  /// 为 true 时会对全部光标应用同一逻辑移动，供 macOS selector 这类编辑器
  /// 内部命令保留多光标结构。
  void moveSemanticsCursor({
    required bool forward,
    required bool byWord,
    required bool extend,
    bool preserveSecondary = false,
    bool obscureText = false,
  }) {
    EditableSelection moveOne(EditableSelection selection) {
      final active = selection.active;
      // 键盘 / selector 的多光标路径继续沿用平台常规的“先折叠选区”；
      // 辅助技术动作则必须从它报告的 active/extent 真正再移动一步。
      final rawTarget = preserveSecondary && !extend && !selection.isCollapsed
          ? (forward ? selection.end : selection.start)
          : _semanticsCursorTarget(active, forward: forward, byWord: byWord, obscureText: obscureText) ?? active;
      final target = _projectPositionForMotion(TextPosition(offset: rawTarget), forward: forward);
      return selection.copyWith(
        anchor: extend ? selection.anchor : target.offset,
        active: target.offset,
        affinity: target.affinity,
        isDirectional: extend ? selection.isDirectional : false,
        clearPreferredX: true,
      );
    }

    if (preserveSecondary) {
      final current = controller.selections;
      controller.setSelections(
        EditableSelectionSet(primary: moveOne(current.primary), secondary: current.secondary.map(moveOne)),
      );
    } else {
      final moved = moveOne(controller.selections.primary);
      controller.setSelection(
        TextSelection(
          baseOffset: moved.anchor,
          extentOffset: moved.active,
          affinity: moved.affinity,
          isDirectional: moved.isDirectional,
        ),
      );
    }
  }

  /// 移动到当前视觉行首/行尾；密码形态退化为文档首/尾，避免泄露行结构。
  void moveLineBreak({required bool forward, required bool extend, bool obscureText = false}) {
    final current = controller.selections;
    EditableSelection moveOne(EditableSelection selection) {
      final target = _lineBreakPosition(
        selection.active,
        selection.affinity,
        forward: forward,
        obscureText: obscureText,
      );
      return selection.copyWith(
        anchor: extend ? selection.anchor : target.offset,
        active: target.offset,
        affinity: target.affinity,
        isDirectional: extend ? selection.isDirectional : false,
        clearPreferredX: true,
      );
    }

    controller.setSelections(
      EditableSelectionSet(primary: moveOne(current.primary), secondary: current.secondary.map(moveOne)),
    );
  }

  /// 扩展选区到当前视觉行首/行尾，且不会把已有选区向内收缩。
  ///
  /// 密码形态退化为文档首/尾，避免通过行边界暴露原文结构。
  void expandSelectionToLineBreak({required bool forward, bool obscureText = false}) {
    final current = controller.selections;
    EditableSelection expandOne(EditableSelection selection) {
      final textSelection = selection.textSelection;
      final origin = _expandBoundaryOrigin(textSelection, forward: forward);
      final target = _lineBreakPosition(origin.offset, origin.affinity, forward: forward, obscureText: obscureText);
      return _expandSelectionToPosition(selection, target, extentAtIndex: false);
    }

    controller.setSelections(
      EditableSelectionSet(primary: expandOne(current.primary), secondary: current.secondary.map(expandOne)),
    );
  }

  /// 扩展选区到文档首/尾，且不会把已有选区向内收缩。
  void expandSelectionToDocumentBoundary({required bool forward}) {
    final current = controller.selections;
    EditableSelection expandOne(EditableSelection selection) =>
        _expandSelectionToPosition(selection, _visibleDocumentBoundary(forward: forward), extentAtIndex: true);

    controller.setSelections(
      EditableSelectionSet(primary: expandOne(current.primary), secondary: current.secondary.map(expandOne)),
    );
  }

  /// 扩展到相邻词边界；跨过原 anchor 时折叠回 anchor，匹配 macOS Option+Shift 语义。
  ///
  /// 密码形态退化为文档首/尾，避免通过词边界暴露原文结构。
  void moveWordBoundaryOrCaretLocation({required bool forward, bool obscureText = false}) {
    _moveBoundaryOrCaretLocation(
      forward: forward,
      boundary: (selection) => obscureText
          ? _visibleDocumentBoundary(forward: forward).offset
          : _projectPositionForMotion(
              TextPosition(offset: forward ? _nextWord(selection.active) : _prevWord(selection.active)),
              forward: forward,
            ).offset,
    );
  }

  /// 扩展到相邻段落边界；跨过原 anchor 时折叠回 anchor。
  void moveParagraphBoundaryOrCaretLocation({required bool forward}) {
    _moveBoundaryOrCaretLocation(
      forward: forward,
      boundary: (selection) => _paragraphBoundary(selection.active, forward: forward),
    );
  }

  TextPosition? _resolveMotion(CaretMotion motion, TextPosition position, {required double? preferredX}) {
    switch (motion) {
      case CaretMotion.charLeft:
        return layout.moveHorizontal(position, left: true);
      case CaretMotion.charRight:
        return layout.moveHorizontal(position, left: false);
      case CaretMotion.wordLeft:
        final origin = _projectPositionForMotion(position, forward: false);
        if (origin != position) return origin;
        return _projectPositionForMotion(TextPosition(offset: _prevWord(position.offset)), forward: false);
      case CaretMotion.wordRight:
        final origin = _projectPositionForMotion(position, forward: true);
        if (origin != position) return origin;
        return _projectPositionForMotion(TextPosition(offset: _nextWord(position.offset)), forward: true);
      case CaretMotion.lineStart:
        final origin = _projectPositionForMotion(position, forward: false);
        return origin != position ? origin : _smartLineStart(position);
      case CaretMotion.lineEnd:
        final origin = _projectPositionForMotion(position, forward: true);
        return origin != position ? origin : layout.visualLineEdge(position, end: true);
      case CaretMotion.docStart:
        return _visibleDocumentBoundary(forward: false);
      case CaretMotion.docEnd:
        return _visibleDocumentBoundary(forward: true);
      case CaretMotion.up:
      case CaretMotion.down:
        final down = motion == CaretMotion.down;
        final target = layout.moveVertical(position, down: down, xGoal: preferredX!);
        // 顶 / 底行的垂直移动落到文档首 / 尾（主流编辑器惯例）。
        return target ?? _visibleDocumentBoundary(forward: down);
      case CaretMotion.pageUp:
      case CaretMotion.pageDown:
        final down = motion == CaretMotion.pageDown;
        final target = layout.pageMove(position, down: down, xGoal: preferredX!, pageExtent: pageExtent());
        return target == position ? _visibleDocumentBoundary(forward: down) : target;
    }
  }

  TextPosition _projectPositionForMotion(TextPosition position, {required bool forward}) {
    final projection = lineProjection;
    if (projection == null) return position;
    return projection.canonicalizeVisibleCaretPosition(
      projection.projectCollapsedPosition(
        position,
        bias: forward ? EditablePositionProjectionBias.forward : EditablePositionProjectionBias.backward,
      ),
    );
  }

  TextPosition _visibleDocumentBoundary({required bool forward}) {
    final document = controller.document;
    final projection = lineProjection;
    final line = projection == null
        ? (forward ? document.lineCount - 1 : 0)
        : (forward ? projection.lastVisibleModelLine : projection.firstVisibleModelLine);
    return TextPosition(
      offset: forward ? document.lineEnd(line) : document.lineStart(line),
      affinity: forward ? TextAffinity.upstream : TextAffinity.downstream,
    );
  }

  /// VS Code 风格 Home：逻辑行首段在首个非空白与物理行首之间切换；折行续段
  /// 只回当前视觉行首，避免跨越上一段内容。
  TextPosition _smartLineStart(TextPosition position) => layout.visualLineEdge(position, end: false);

  int? _semanticsCursorTarget(int offset, {required bool forward, required bool byWord, required bool obscureText}) {
    final origin = _projectPositionForMotion(TextPosition(offset: offset), forward: forward);
    if (origin.offset != offset) return origin.offset;
    if (obscureText && byWord) return _visibleDocumentBoundary(forward: forward).offset;
    final target = byWord
        ? (forward ? _nextSemanticsWordStart(offset) : _previousSemanticsWordStart(offset))
        : forward
        ? (offset < controller.document.length
              ? (obscureText ? _nextCodePointBoundary(offset) : nextGraphemeBoundary(offset))
              : null)
        : (offset > 0 ? (obscureText ? _previousCodePointBoundary(offset) : previousGraphemeBoundary(offset)) : null);
    return target == null ? null : _projectPositionForMotion(TextPosition(offset: target), forward: forward).offset;
  }

  TextPosition _lineBreakPosition(
    int offset,
    TextAffinity affinity, {
    required bool forward,
    required bool obscureText,
  }) {
    final doc = controller.document;
    if (obscureText) {
      return _visibleDocumentBoundary(forward: forward);
    }
    final origin = _projectPositionForMotion(
      TextPosition(offset: math.min(doc.length, math.max(0, offset)), affinity: affinity),
      forward: forward,
    );
    if (origin.offset != offset || origin.affinity != affinity) return origin;
    return layout.visualLineEdge(
      TextPosition(offset: math.min(doc.length, math.max(0, offset)), affinity: affinity),
      end: forward,
    );
  }

  TextPosition _expandBoundaryOrigin(TextSelection selection, {required bool forward}) {
    final shouldTargetBase = forward
        ? selection.baseOffset > selection.extentOffset
        : selection.baseOffset < selection.extentOffset;
    return shouldTargetBase ? selection.base : selection.extent;
  }

  EditableSelection _expandSelectionToPosition(
    EditableSelection selection,
    TextPosition target, {
    required bool extentAtIndex,
  }) {
    final expanded = selection.textSelection.expandTo(target, extentAtIndex || selection.isCollapsed);
    return EditableSelection.fromTextSelection(expanded);
  }

  void _moveBoundaryOrCaretLocation({
    required bool forward,
    required int Function(EditableSelection selection) boundary,
  }) {
    final current = controller.selections;
    final length = controller.document.length;
    TextAffinity anchorAffinity(EditableSelection selection) {
      if (selection.anchor == selection.active) return selection.affinity;
      return selection.anchor < selection.active ? TextAffinity.downstream : TextAffinity.upstream;
    }

    EditableSelection moveOne(EditableSelection selection) {
      final target = math.min(length, math.max(0, boundary(selection)));
      final crossesAnchor = forward
          ? selection.active < selection.anchor && target >= selection.anchor
          : selection.active > selection.anchor && target <= selection.anchor;
      final active = crossesAnchor ? selection.anchor : target;
      return EditableSelection(
        anchor: selection.anchor,
        active: active,
        affinity: crossesAnchor ? anchorAffinity(selection) : TextAffinity.downstream,
        isDirectional: !crossesAnchor && selection.isDirectional,
      );
    }

    controller.setSelections(
      EditableSelectionSet(primary: moveOne(current.primary), secondary: current.secondary.map(moveOne)),
    );
  }

  int _paragraphBoundary(int offset, {required bool forward}) {
    final doc = controller.document;
    final origin = _projectPositionForMotion(TextPosition(offset: offset.clamp(0, doc.length)), forward: forward);
    if (origin.offset != offset) return origin.offset;
    if (forward) {
      final end = _visibleDocumentBoundary(forward: true).offset;
      if (offset >= end) return end;
      final line = doc.lineIndexOf(offset);
      final targetLine =
          lineProjection?.adjacentVisibleModelLine(line, forward: true) ?? (line < doc.lineCount - 1 ? line + 1 : null);
      return targetLine == null ? end : doc.lineStart(targetLine);
    }
    final start = _visibleDocumentBoundary(forward: false).offset;
    if (offset <= start) return start;
    final line = doc.lineIndexOf(offset - 1);
    if (lineProjection == null || lineProjection!.isVisibleModelLine(line)) return doc.lineStart(line);
    final targetLine = lineProjection!.adjacentVisibleModelLine(line, forward: false);
    return targetLine == null ? start : doc.lineStart(targetLine);
  }

  // ===========================================================================
  // 删除 / 插入
  // ===========================================================================

  /// 同时对全部选区执行退格；[word] 为 true 时按词删除。
  ///
  /// [obscureText] 为 true 时按 Unicode code point 而非 grapheme 删除，匹配
  /// Flutter 密码框的掩码边界，同时避免 caret 落在 surrogate 中间时删半个字符。
  void deleteBackward({bool word = false, bool obscureText = false}) {
    final operations = <EditOperation>[];
    for (final selection in controller.selections.all) {
      if (!selection.isCollapsed) {
        operations.add(_atomicSelectionDeletion(selection, obscureText: obscureText));
        continue;
      }
      final offset = selection.active;
      if (offset == 0) continue;
      if (obscureText && !word) {
        operations.add(_codePointDeletion(offset, forward: false));
      } else {
        operations.add(EditOperation.delete(word ? _prevWord(offset) : previousGraphemeBoundary(offset), offset));
      }
    }
    _applyDeletions(operations, source: EditableEditSource.keyboard, forward: false);
  }

  /// 同时对全部选区执行前向删除；[word] 为 true 时按词删除。
  ///
  /// [obscureText] 为 true 时按 Unicode code point 而非 grapheme 删除，匹配
  /// Flutter 密码框的掩码边界，同时避免 caret 落在 surrogate 中间时删半个字符。
  void deleteForward({bool word = false, bool obscureText = false}) {
    final operations = <EditOperation>[];
    final length = controller.document.length;
    for (final selection in controller.selections.all) {
      if (!selection.isCollapsed) {
        operations.add(_atomicSelectionDeletion(selection, obscureText: obscureText));
        continue;
      }
      final offset = selection.active;
      if (offset >= length) continue;
      if (obscureText && !word) {
        operations.add(_codePointDeletion(offset, forward: true));
      } else {
        operations.add(EditOperation.delete(offset, word ? _nextWord(offset) : nextGraphemeBoundary(offset)));
      }
    }
    _applyDeletions(operations, source: EditableEditSource.keyboard, forward: true);
  }

  /// 删除到当前视觉行首/行尾；密码形态删除到文档首/尾。
  void deleteToLineBreak({required bool forward, bool obscureText = false}) {
    final operations = <EditOperation>[];
    for (final selection in controller.selections.all) {
      if (!selection.isCollapsed) {
        operations.add(EditOperation.delete(selection.start, selection.end));
        continue;
      }
      final offset = selection.active;
      final target = _lineBreakPosition(offset, selection.affinity, forward: forward, obscureText: obscureText).offset;
      if (target == offset) continue;
      operations.add(EditOperation.delete(math.min(offset, target), math.max(offset, target)));
    }
    _applyDeletions(operations, source: EditableEditSource.keyboard, forward: forward);
  }

  /// 删除到文档首/尾。
  void deleteToDocumentBoundary({required bool forward}) {
    final operations = <EditOperation>[];
    final boundary = forward ? controller.document.length : 0;
    for (final selection in controller.selections.all) {
      if (!selection.isCollapsed) {
        operations.add(EditOperation.delete(selection.start, selection.end));
        continue;
      }
      final offset = selection.active;
      if (offset == boundary) continue;
      operations.add(EditOperation.delete(math.min(offset, boundary), math.max(offset, boundary)));
    }
    _applyDeletions(operations, source: EditableEditSource.keyboard, forward: forward);
  }

  /// 交换每个折叠 caret 两侧的相邻 Unicode 字素，文末交换最后两个字素。
  void transposeCharacters() {
    final doc = controller.document;
    if (doc.length <= 1) return;
    final selections = controller.selections.all;
    final candidates = <({int index, int start, int middle, int end, String replacement})>[];
    for (var i = 0; i < selections.length; i++) {
      final selection = selections[i];
      if (!selection.isCollapsed || selection.active == 0) continue;
      final offset = selection.active;
      late final int start;
      late final int middle;
      late final int end;
      if (offset >= doc.length) {
        end = doc.length;
        middle = previousGraphemeBoundary(end);
        start = previousGraphemeBoundary(middle);
      } else {
        start = previousGraphemeBoundary(offset);
        middle = offset;
        end = nextGraphemeBoundary(offset);
      }
      if (start == middle || middle == end) continue;
      final left = doc.getText(start, middle);
      final right = doc.getText(middle, end);
      if (left.isEmpty || right.isEmpty) continue;
      candidates.add((index: i, start: start, middle: middle, end: end, replacement: '$right$left'));
    }
    if (candidates.isEmpty) return;

    candidates.sort((left, right) {
      final byStart = left.start.compareTo(right.start);
      return byStart != 0 ? byStart : left.end.compareTo(right.end);
    });
    final operations = <EditOperation>[];
    final movedSelections = <int, EditableSelection>{};
    var occupiedEnd = -1;
    for (final candidate in candidates) {
      if (candidate.start < occupiedEnd) continue;
      occupiedEnd = candidate.end;
      operations.add(EditOperation.replace(candidate.start, candidate.end, candidate.replacement));
      movedSelections[candidate.index] = EditableSelection.collapsed(offset: candidate.end);
    }
    if (operations.isEmpty) return;

    final nextSelections = <EditableSelection>[
      for (var i = 0; i < selections.length; i++) movedSelections[i] ?? selections[i].copyWith(clearPreferredX: true),
    ];
    controller.applyEdits(
      operations,
      source: EditableEditSource.keyboard,
      selectionsAfter: EditableSelectionSet(primary: nextSelections.first, secondary: nextSelections.skip(1)),
      undoStopBefore: true,
      undoStopAfter: true,
    );
  }

  void _applyDeletions(List<EditOperation> operations, {required EditableEditSource source, bool? forward}) {
    if (operations.isEmpty) return;
    operations.sort((a, b) => a.normalizedStart.compareTo(b.normalizedStart));
    final merged = <EditOperation>[];
    for (final operation in operations) {
      final start = operation.normalizedStart;
      final end = operation.normalizedEnd;
      if (merged.isEmpty || start > merged.last.end) {
        merged.add(EditOperation.delete(start, end));
      } else if (end > merged.last.end) {
        final previous = merged.removeLast();
        merged.add(EditOperation.delete(previous.start, end));
      }
    }
    if (source == EditableEditSource.keyboard && forward != null) {
      controller.applyKeyboardDeletionEdits(merged, forward: forward);
      return;
    }
    controller.applyEdits(merged, source: source, undoStopBefore: false, undoStopAfter: false);
  }

  // ===========================================================================
  // 选区
  // ===========================================================================

  void selectAll() => controller.selectAll();

  /// 双击选词。
  void selectWordAt(TextPosition position) {
    final range = _wordBoundary(position);
    controller.setSelection(TextSelection(baseOffset: range.start, extentOffset: range.end));
  }

  /// 三击选整逻辑行（含行尾换行符，模拟整行选中）。
  ///
  /// active 端落在下一行行首并带 upstream 亲和，光标几何停留在换行符左侧
  /// （本行行尾），选区范围仍含换行符供整行复制。
  void selectLineAt(TextPosition position) {
    final doc = controller.document;
    final line = doc.lineIndexOf(position.offset);
    final end = line < doc.lineCount - 1 ? doc.lineStart(line + 1) : doc.lineEnd(line);
    controller.setSelection(
      TextSelection(baseOffset: doc.lineStart(line), extentOffset: end, affinity: TextAffinity.upstream),
    );
  }

  /// 拖选 / shift+click：保持 base 扩展到 [position]。
  void extendTo(TextPosition position) {
    controller.setSelection(
      TextSelection(
        baseOffset: controller.selection.baseOffset,
        extentOffset: position.offset,
        affinity: position.affinity,
      ),
    );
  }

  /// 拖选的词级扩展（双击后拖动）：以 [anchor] 词为基，扩到 [position] 词界。
  void extendWordTo(TextPosition position, {required TextPosition anchor}) {
    final anchorRange = _wordBoundary(anchor);
    final targetRange = _wordBoundary(position);
    if (position.offset >= anchorRange.start) {
      controller.setSelection(TextSelection(baseOffset: anchorRange.start, extentOffset: targetRange.end));
    } else {
      controller.setSelection(TextSelection(baseOffset: anchorRange.end, extentOffset: targetRange.start));
    }
  }

  // ===========================================================================
  // 剪贴板
  // ===========================================================================

  /// 复制当前选中的正文。
  Future<void> copy() async {
    final range = controller.selection;
    if (range.isCollapsed) return;
    final document = controller.document;
    await Clipboard.setData(
      ClipboardData(text: document.preferredEol.serialize(document.getText(range.start, range.end))),
    );
  }

  /// 剪贴板完成后再次验证正文和选区，避免异步剪切作用于新内容。
  Future<void> cut() async {
    final range = controller.selection;
    if (range.isCollapsed) return;
    final revision = controller.docRevision;
    await copy();
    if (canCommitCut?.call() == false || controller.docRevision != revision || controller.selection != range) return;
    controller.insertText('', range: range);
  }

  /// 将剪贴板文字输入到当前选区。
  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || canCommitPaste?.call() == false) return;
    controller.insertText(data!.text!, range: controller.selection);
  }

  void undo() => controller.undoEdit();

  void redo() => controller.redoEdit();

  // ===========================================================================
  // 边界计算
  // ===========================================================================

  /// 上一个 grapheme 边界；行首回退跨过换行符到上一行行尾。
  int previousGraphemeBoundary(int offset) {
    if (offset <= 0) return 0;
    final doc = controller.document;
    final pos = doc.positionOf(offset);
    if (pos.column == 0) return offset - 1;
    final lineStart = doc.lineStart(pos.line);
    return previousTextGraphemeBoundary(doc, offset, lowerBound: lineStart, upperBound: doc.lineEnd(pos.line));
  }

  /// 下一个 grapheme 边界；行尾前进跨过换行符到下一行行首。
  int nextGraphemeBoundary(int offset) {
    final doc = controller.document;
    if (offset >= doc.length) return doc.length;
    final pos = doc.positionOf(offset);
    final lineEnd = doc.lineEnd(pos.line);
    if (offset >= lineEnd) return offset + 1;
    return nextTextGraphemeBoundary(doc, offset, lowerBound: doc.lineStart(pos.line), upperBound: lineEnd);
  }

  EditOperation _atomicSelectionDeletion(EditableSelection selection, {required bool obscureText}) {
    if (!obscureText) return EditOperation.delete(selection.start, selection.end);
    final start = _leadingCodePointBoundaryAt(selection.start) ?? selection.start;
    final end = _trailingCodePointBoundaryAt(selection.end - 1) ?? selection.end;
    return EditOperation.delete(math.min(start, end), math.max(start, end));
  }

  EditOperation _codePointDeletion(int offset, {required bool forward}) {
    final start = forward
        ? (_leadingCodePointBoundaryAt(offset) ?? offset)
        : (_leadingCodePointBoundaryAt(offset - 1) ?? 0);
    final end = forward
        ? (_trailingCodePointBoundaryAt(offset) ?? controller.document.length)
        : (_trailingCodePointBoundaryAt(offset - 1) ?? offset);
    return EditOperation.delete(math.min(start, end), math.max(start, end));
  }

  int _previousCodePointBoundary(int offset) => _leadingCodePointBoundaryAt(offset - 1) ?? 0;

  int _nextCodePointBoundary(int offset) => _trailingCodePointBoundaryAt(offset) ?? controller.document.length;

  int? _leadingCodePointBoundaryAt(int position) {
    final doc = controller.document;
    final length = doc.length;
    if (length == 0 || position < 0) return null;
    if (position == 0) return 0;
    if (position >= length) return length;
    return _breaksSurrogatePair(position) ? position - 1 : position;
  }

  int? _trailingCodePointBoundaryAt(int position) {
    final doc = controller.document;
    final length = doc.length;
    if (length == 0 || position >= length) return null;
    if (position < 0) return 0;
    if (position == length - 1) return length;
    return _breaksSurrogatePair(position + 1) ? position + 2 : position + 1;
  }

  bool _breaksSurrogatePair(int position) {
    final doc = controller.document;
    final length = doc.length;
    if (position <= 0 || position >= length || length <= 1) return false;
    final before = doc.getText(position - 1, position).codeUnitAt(0);
    final current = doc.getText(position, position + 1).codeUnitAt(0);
    return _isHighSurrogate(before) && _isLowSurrogate(current);
  }

  bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdbff;

  bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xdc00 && codeUnit <= 0xdfff;

  /// 上一个词边界：跳过左侧空白后取词首；行首跨到上一行行尾。
  int _prevWord(int offset) => _wordNavigator.previousBoundary(offset);

  /// 下一个词边界：跳过右侧空白后取词尾；行尾跨到下一行行首。
  int _nextWord(int offset) => _wordNavigator.nextBoundary(offset);

  int? _previousSemanticsWordStart(int offset) {
    if (offset <= 0) return null;
    final doc = controller.document;
    var cursor = _wordBoundary(TextPosition(offset: offset)).start;
    while (cursor > 0) {
      final position = doc.positionOf(cursor);
      final projection = lineProjection;
      if (projection != null && !projection.isVisibleModelLine(position.line)) {
        final previous = projection.adjacentVisibleModelLine(position.line, forward: false);
        if (previous == null) return null;
        cursor = doc.lineEnd(previous);
        continue;
      }
      if (position.column == 0) {
        cursor--;
        continue;
      }
      final start = _wordNavigator.previousWordStartInLine(cursor);
      if (start != null) return start;
      cursor = doc.lineStart(position.line);
    }
    return null;
  }

  int? _nextSemanticsWordStart(int offset) {
    final doc = controller.document;
    if (offset >= doc.length) return null;
    var cursor = _wordBoundary(TextPosition(offset: offset)).end;
    while (cursor < doc.length) {
      final position = doc.positionOf(cursor);
      final projection = lineProjection;
      if (projection != null && !projection.isVisibleModelLine(position.line)) {
        final next = projection.adjacentVisibleModelLine(position.line, forward: true);
        if (next == null) return null;
        cursor = doc.lineStart(next);
        continue;
      }
      if (cursor >= doc.lineEnd(position.line)) {
        cursor++;
        continue;
      }
      final start = _wordNavigator.nextWordStartInLine(cursor);
      if (start != null) return start;
      cursor = doc.lineEnd(position.line);
    }
    return null;
  }

  TextRange _wordBoundary(TextPosition position) =>
      wordBoundary?.call(position) ?? _wordNavigator.boundaryAt(position.offset);
}
