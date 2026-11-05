// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetBuilder;

import 'controller.dart';
import 'editable_controller.dart';
import 'model/document_change_set.dart';
import 'model/document_version.dart';
import 'model/edit_operation.dart';
import 'model/edit_transaction.dart';
import 'model/editable_selection.dart';
import 'model/text_document.dart';

/// 仅适配文本读取和输入，不复制上层模型的正文或历史。
final class EditableControllerAdapter extends EditableController {
  EditableControllerAdapter(this.source) {
    _document = _ExternalDocument(source);
    _revision = source.docRevision;
    _lastSelections = selections;
    _singleLine = source.singleLine;
    _maxLength = source.maxLength;
    _formatters = List.of(source.inputFormatters);
    source.textChanges.addListener(_textChanged);
    source.addListener(_changed);
  }

  final ElEditableController source;
  @override
  Map<String, WidgetBuilder> get inlineContent => source.inlineContent;
  @override
  set inlineContent(Map<String, WidgetBuilder> value) => source.inlineContent = value;
  late final TextDocument _document;
  final _Signal _textSignal = _Signal();
  final _Signal _visualSignal = _Signal();
  final _Signal _configurationSignal = _Signal();
  final ValueNotifier<DocumentChangeSet?> _transactionSignal = ValueNotifier(null);
  final DocumentVersionIssuer _versions = DocumentVersionIssuer();
  int _revision = 0;
  bool _pendingTextChange = false;
  int _configurationRevision = 0;
  late EditableSelectionSet _lastSelections;
  late bool _singleLine;
  int? _maxLength;
  late List<TextInputFormatter> _formatters;

  void _textChanged() {
    _pendingTextChange = true;
    final before = _revision;
    _revision = source.docRevision;
    final change = DocumentChangeSet(
      baseRevision: before,
      revision: _revision,
      source: source.revealOnTextChange ? EditableEditSource.keyboard : EditableEditSource.api,
      edits: source.renderEdits.map(
        (edit) => DocumentEdit(
          start: edit.start,
          removed: edit.removed,
          inserted: edit.inserted,
          firstDirtyLine: edit.firstLine,
          removedLineCount: edit.removedLines,
          insertedLineCount: edit.insertedLines,
        ),
      ),
      selectionsBefore: _lastSelections,
      selectionsAfter: selections,
    );
    _transactionSignal.value = change;
    _textSignal.fire();
  }

  void _changed() {
    if (_singleLine != source.singleLine ||
        _maxLength != source.maxLength ||
        !listEquals(_formatters, source.inputFormatters)) {
      _singleLine = source.singleLine;
      _maxLength = source.maxLength;
      _formatters = List.of(source.inputFormatters);
      _configurationRevision++;
      _configurationSignal.fire();
    }
    if (!_pendingTextChange) {
      _transactionSignal.value = DocumentChangeSet(
        baseRevision: _revision,
        revision: _revision,
        source: EditableEditSource.api,
        edits: const [],
        selectionsBefore: _lastSelections,
        selectionsAfter: selections,
      );
    }
    _pendingTextChange = false;
    _lastSelections = selections;
    _visualSignal.fire();
    notifyListeners();
  }

  @override
  int get configurationRevision => _configurationRevision;
  @override
  List<TextInputFormatter> get inputFormatters => source.inputFormatters;
  @override
  void configure({
    required bool singleLine,
    required int? maxLength,
    List<TextInputFormatter> inputFormatters = const [],
  }) => source.configure(singleLine: singleLine, maxLength: maxLength, inputFormatters: inputFormatters);
  @override
  TextDocument get document => _document;
  @override
  String get text => source.text;
  @override
  set text(String value) => source.text = value;
  @override
  TextSelection get selection => source.selection;
  @override
  TextRange get composing => source.composing;
  @override
  bool get singleLine => source.singleLine;
  @override
  int? get maxLength => source.maxLength;
  @override
  int get docRevision => source.docRevision;
  @override
  int get visualRevision => source.renderRevision;
  @override
  int get presentationRevision => source.presentationRevision;
  @override
  DocumentVersion get documentVersion => _versions.issue(source.docRevision);
  @override
  Listenable get docChanges => _textSignal;
  @override
  Listenable get visualChanges => _visualSignal;
  @override
  Listenable get configurationChanges => _configurationSignal;
  @override
  ValueListenable<DocumentChangeSet?> get transactionChanges => _transactionSignal;
  @override
  DocumentChangeSet? get lastChangeSet => _transactionSignal.value;
  @override
  EditableSelectionSet get selections => EditableSelectionSet.fromTextSelections(source.renderSelections);
  @override
  bool get overwriteMode => source.overwriteCaret;
  @override
  bool get hasActiveImeComposition => source.hasActiveImeComposition;
  @override
  int? get selectAllCaretDisplayOffset => source.selectAllCaretDisplayOffset;
  @override
  int get committedTextLength => source.committedTextLength;
  @override
  bool get canUndo => source.canUndo;
  @override
  bool get canRedo => source.canRedo;
  @override
  void closeHistoryRun() => source.closeHistoryRun();
  @override
  bool undoEdit() => source.undoEdit();
  @override
  bool redoEdit() => source.redoEdit();
  @override
  void insertText(String text, {TextRange? range, TextSelection? selection}) =>
      source.insertText(text, range: range, selection: selection);
  @override
  void replaceRange(
    int start,
    int end,
    String text, {
    TextSelection? selection,
    TextRange composing = TextRange.empty,
    bool addToHistory = true,
  }) => source.replaceRange(start, end, text, selection: selection, composing: composing, addToHistory: addToHistory);
  @override
  void setSelection(TextSelection selection, {bool keepComposing = false}) =>
      source.setSelection(selection, keepComposing: keepComposing);
  @override
  void setSelections(EditableSelectionSet selections, {bool keepComposing = false}) =>
      source.updateRenderSelections(selections.all.map((item) => item.textSelection), keepComposing: keepComposing);
  @override
  void selectAll() => source.selectAll();

  @override
  void invalidatePresentation() => source.invalidatePresentation();
  @override
  void imeReplace(int start, int end, String text, {required TextSelection selection, required TextRange composing}) =>
      source.updateComposingText([(start: start, end: end, text: text)], selection: selection, composing: composing);
  @override
  void imeApplyEdits(
    Iterable<EditOperation> operations, {
    required TextSelection selection,
    required TextRange composing,
  }) => source.updateComposingText(
    operations.map((edit) => (start: edit.start, end: edit.end, text: edit.text)),
    selection: selection,
    composing: composing,
  );
  @override
  void imeUpdateSelection(TextSelection selection, TextRange composing) =>
      source.updateComposingText(const [], selection: selection, composing: composing);
  @override
  bool finishImeComposition({bool commit = true, bool commitUnconfirmedAsPlainText = false}) =>
      source.finishImeComposition(commit: commit, commitUnconfirmedAsPlainText: commitUnconfirmedAsPlainText);
  @override
  void applyAutofillValue(TextEditingValue value) => source.applyPlatformValue(value, autofill: true);
  @override
  void applyAccessibilityValue(TextEditingValue value) => source.applyPlatformValue(value, autofill: false);

  @override
  bool updateSelectionBeforePaint(VoidCallback update, void Function(VoidCallback) publish) =>
      source.updateSelectionBeforePaint(update, publish);

  @override
  DocumentChangeSet applyEdits(
    Iterable<EditOperation> operations, {
    EditableEditSource source = EditableEditSource.api,
    EditableSelectionSet? selectionsAfter,
    bool undoStopBefore = false,
    bool undoStopAfter = false,
  }) {
    final before = docRevision;
    final selectionBefore = selections;
    if (undoStopBefore) this.source.closeHistoryRun();
    this.source.applyTextEdits(
      operations.map((edit) => (start: edit.start, end: edit.end, text: edit.text)),
      selection: selectionsAfter?.primaryTextSelection,
    );
    if (undoStopAfter) this.source.closeHistoryRun();
    return docRevision != before && lastChangeSet != null
        ? lastChangeSet!
        : DocumentChangeSet(
            baseRevision: before,
            revision: docRevision,
            source: source,
            edits: const [],
            selectionsBefore: selectionBefore,
            selectionsAfter: selections,
          );
  }

  @override
  DocumentChangeSet applyKeyboardDeletionEdits(Iterable<EditOperation> operations, {required bool forward}) {
    final before = docRevision;
    final selectionBefore = selections;
    source.applyTextEdits(
      operations.map((edit) => (start: edit.start, end: edit.end, text: edit.text)),
      forwardDeletion: forward,
    );
    return docRevision != before && lastChangeSet != null
        ? lastChangeSet!
        : DocumentChangeSet(
            baseRevision: before,
            revision: docRevision,
            source: EditableEditSource.keyboard,
            edits: const [],
            selectionsBefore: selectionBefore,
            selectionsAfter: selections,
          );
  }

  @override
  void dispose() {
    source.textChanges.removeListener(_textChanged);
    source.removeListener(_changed);
    _textSignal.dispose();
    _visualSignal.dispose();
    _configurationSignal.dispose();
    _transactionSignal.dispose();
    super.dispose();
  }
}

final class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// 直接读取上层模型，保留窗口化排版与 IME 的局部读取。
final class _ExternalDocument extends TextDocument {
  _ExternalDocument(this.source);
  final ElEditableController source;
  @override
  int get length => source.length;
  @override
  int get lineCount => source.lineCount;
  @override
  bool get isEmpty => length == 0;
  @override
  String get text => source.text;
  @override
  String getText(int start, int end) => source.getText(start, end);
  @override
  int lineStart(int line) => source.lineRange(line).start;
  @override
  int lineEnd(int line) => source.lineRange(line).end;
  @override
  int lineLength(int line) => lineEnd(line) - lineStart(line);
  @override
  int lineIndexOf(int offset) => source.lineAtOffset(offset);
  @override
  String lineAt(int line) => source.lineText(line);
  @override
  List<String> readLines(int startLine, {int maxLines = 64, int maxCodeUnits = TextDocument.defaultChunkSize}) {
    return source.readTextLines(startLine, maxLines: maxLines, maxCodeUnits: maxCodeUnits);
  }
}
