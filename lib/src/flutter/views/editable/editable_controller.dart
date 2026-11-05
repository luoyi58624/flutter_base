import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show TextEditingValue, TextRange, TextSelection, TextInputFormatter;
import 'package:flutter/widgets.dart' show WidgetBuilder;

import 'controller.dart';
import 'inline_content.dart';
import 'input_formatters.dart';
import 'model/document_change_set.dart';
import 'model/document_version.dart';
import 'model/edit_history.dart';
import 'model/edit_interceptor.dart';
import 'model/edit_operation.dart';
import 'model/edit_transaction.dart';
import 'model/editable_selection.dart';
import 'model/text_document.dart';

/// 可编辑内核的单一事实源：文档、主/次选区、composing 与事务历史。
///
/// 通知分四道，订阅方按需监听：
/// - [docChanges]：兼容旧调用方的无载荷文本变化通知；
/// - [transactionChanges]：携带完整 [DocumentChangeSet] 的事务通知；
/// - [visualChanges]：选区、composing、文本或呈现任一变化。
/// - [configurationChanges]：单行、长度或事务拦截策略变化。
///
/// [ChangeNotifier] 本体在任一可见状态或配置变化时也会通知，适合业务值绑定。
class EditableController extends ElEditableController {
  /// 创建编辑控制器。
  EditableController({
    String text = '',
    List<TextInputFormatter> inputFormatters = const [],
    Map<String, WidgetBuilder> inlineContent = const {},
    TextDocumentEol? eol,
    bool singleLine = false,
    int? maxLength,
    this.historyCapacity = 1000,
    this.historyMaxCodeUnits = 16 * 1024 * 1024,
    this.historyMaxMergeCodeUnits = 4096,
  }) : // 公开参数不能暴露私有字段名。
       // ignore: prefer_initializing_formals
       _singleLine = singleLine,
       _inputFormatters = List.unmodifiable(inputFormatters),
       // ignore: prefer_initializing_formals
       _maxLength = maxLength,
       _history = EditHistory(
         capacity: historyCapacity,
         maxCodeUnits: historyMaxCodeUnits,
         maxMergeCodeUnits: historyMaxMergeCodeUnits,
       ),
       assert(maxLength == null || maxLength > 0),
       assert(historyCapacity >= 0),
       assert(historyMaxCodeUnits >= 0),
       // 公开参数不能暴露私有字段名。
       // ignore: prefer_initializing_formals
       assert(historyMaxMergeCodeUnits > 0),
       super.base() {
    _document = TextDocument.withEol(
      _applyPolicies(text, available: maxLength ?? _noLimit),
      eol: eol ?? TextDocument.detectPreferredEol(text),
    );
    _documentView = _ReadOnlyTextDocument(_document);
    _selections = EditableSelectionSet(primary: const EditableSelection.collapsed(offset: 0));
    if (inlineContent.isNotEmpty) this.inlineContent = inlineContent;
  }

  InlineContent? _inlineModel;

  /// 仅在启用行内内容后创建匹配表，普通输入不分配匹配状态。
  InlineContent? get inlineContentModel {
    final content = inlineContent;
    if (content.isEmpty) return _inlineModel = null;
    if (!identical(_inlineModel?.builders, content)) {
      _inlineModel = InlineContent.of(content, previous: _inlineModel);
    }
    return _inlineModel;
  }

  @override
  set inlineContent(Map<String, WidgetBuilder> value) {
    _checkMutationAllowed();
    super.inlineContent = value;
  }

  @override
  List<TextInputFormatter> get inputFormatters => _inputFormatters;
  List<TextInputFormatter> _inputFormatters;

  @override
  int get length => document.length;

  @override
  String getText(int start, int end) => document.getText(start, end);

  @override
  String lineText(int line) => document.lineAt(line);
  @override
  List<String> readTextLines(int startLine, {int maxLines = 64, int maxCodeUnits = 65536}) =>
      document.readLines(startLine, maxLines: maxLines, maxCodeUnits: maxCodeUnits);
  @override
  int get lineCount => document.lineCount;

  @override
  TextRange lineRange(int line) => TextRange(start: document.lineStart(line), end: document.lineEnd(line));

  @override
  int lineAtOffset(int offset) => document.lineIndexOf(offset);

  @override
  int get renderRevision => visualRevision;

  @override
  Listenable get textChanges => docChanges;

  @override
  void configure({
    required bool singleLine,
    required int? maxLength,
    List<TextInputFormatter> inputFormatters = const [],
  }) {
    final formattersChanged = !listEquals(_inputFormatters, inputFormatters);
    final policyChanged = this.singleLine != singleLine || this.maxLength != maxLength;
    if (!formattersChanged && !policyChanged) return;
    _checkMutationAllowed();
    if (maxLength != null && maxLength <= 0) throw ArgumentError.value(maxLength, 'maxLength');
    _inputFormatters = List.unmodifiable(inputFormatters);
    _singleLine = singleLine;
    _maxLength = maxLength;
    _publishConfigurationChange();
  }

  @override
  Iterable<({int start, String removed, String inserted, int firstLine, int removedLines, int insertedLines})>
  get renderEdits =>
      lastChangeSet?.edits.map(
        (edit) => (
          start: edit.start,
          removed: edit.removed,
          inserted: edit.inserted,
          firstLine: edit.firstDirtyLine,
          removedLines: edit.removedLineCount,
          insertedLines: edit.insertedLineCount,
        ),
      ) ??
      const [];

  @override
  void updateComposingText(
    Iterable<({int start, int end, String text})> edits, {
    required TextSelection selection,
    required TextRange composing,
  }) {
    final values = edits.toList(growable: false);
    if (values.length == 1) {
      final edit = values.single;
      imeReplace(edit.start, edit.end, edit.text, selection: selection, composing: composing);
    } else {
      imeApplyEdits(
        values.map((edit) => EditOperation.replace(edit.start, edit.end, edit.text)),
        selection: selection,
        composing: composing,
      );
    }
  }

  @override
  bool get revealOnTextChange => lastChangeSet?.source != EditableEditSource.api;

  @override
  bool updateSelectionBeforePaint(VoidCallback update, void Function(VoidCallback) publish) =>
      applyPaintSelection(update, publish);

  @override
  void applyTextEdits(
    Iterable<({int start, int end, String text})> edits, {
    TextSelection? selection,
    bool? forwardDeletion,
  }) {
    final operations = edits.map((edit) => EditOperation.replace(edit.start, edit.end, edit.text));
    if (forwardDeletion != null) {
      applyKeyboardDeletionEdits(operations, forward: forwardDeletion);
    } else {
      applyEdits(
        operations,
        source: EditableEditSource.command,
        selectionsAfter: selection == null ? null : EditableSelectionSet.fromTextSelections([selection]),
      );
    }
  }

  /// 单行策略：一切写入路径的换行符被剔除。
  @override
  bool get singleLine => _singleLine;
  bool _singleLine;

  /// 最大长度（UTF-16 code unit 计）；截断会回退到完整 Unicode 字素边界。
  @override
  int? get maxLength => _maxLength;
  int? _maxLength;

  bool get _hasEditInterceptors => _inputFormatters.isNotEmpty;
  Iterable<EditableEditInterceptor> get _effectiveInterceptors sync* {
    if (_inputFormatters.isNotEmpty) yield (context) => applyTextInputFormatters(context, _inputFormatters);
  }

  /// undo 栈允许保留的最大条目数。
  final int historyCapacity;

  /// undo 与 redo 允许直接持有的文本 code unit 总预算。
  final int historyMaxCodeUnits;

  /// 每个连续输入合并段、每个 caret 允许累计的最大文本长度。
  final int historyMaxMergeCodeUnits;

  /// 无上限哨兵；Web JS 的位运算只有 32 位，不能写成 `1 << 50`。
  static const int _noLimit = 0x4000000000000;

  late TextDocument _document;
  late TextDocument _documentView;
  late EditableSelectionSet _selections;
  TextRange _composing = TextRange.empty;
  final EditHistory _history;
  final DocumentVersionIssuer _versionIssuer = DocumentVersionIssuer();

  final _DocNotifier _docChanges = _DocNotifier();
  final _DocNotifier _visualChanges = _DocNotifier();
  final _DocNotifier _configurationChanges = _DocNotifier();
  final _TransactionNotifier _transactionChanges = _TransactionNotifier();

  int _docRevision = 0;
  int _visualRevision = 0;
  int _presentationRevision = 0;
  int _configurationRevision = 0;
  DocumentChangeSet? _lastChangeSet;
  bool _publishingTransaction = false;
  bool _publishingConfiguration = false;
  bool _interceptingTransaction = false;
  bool _disposed = false;

  /// 独立光标历史的最大深度，与 VS Code 的有界 cursor undo 栈一致。

  /// 文档只读门面；调用 [TextDocument.replace] 会抛错，写入必须走控制器事务。
  TextDocument get document => _documentView;

  /// 兼容旧调用方的文本内容变化通知。
  Listenable get docChanges => _docChanges;

  /// 带完整事务载荷的文档变化通知。
  ValueListenable<DocumentChangeSet?> get transactionChanges => _transactionChanges;

  /// 视觉状态变化通知（选区、composing、文本或呈现变化）。
  Listenable get visualChanges => _visualChanges;

  /// 编辑策略变化通知；配置已原子生效，正文与视觉通知不会被伪触发。
  Listenable get configurationChanges => _configurationChanges;

  /// 文本修订号；每个发生文本变化的原子事务只递增一次。
  @override
  int get docRevision => _docRevision;

  /// 当前模型身份与文本修订共同绑定的强版本令牌。
  DocumentVersion get documentVersion => _versionIssuer.issue(_docRevision);

  /// 视觉修订号；每次可见状态变化递增一次。
  int get visualRevision => _visualRevision;

  /// 呈现修订号；高亮、装饰等非文本呈现失效时递增。
  @override
  int get presentationRevision => _presentationRevision;

  /// 编辑策略修订号；每次真正改变单行、长度或拦截器管线时递增一次。
  int get configurationRevision => _configurationRevision;

  void _publishConfigurationChange() {
    _history.closeRun();
    _configurationRevision++;
    _publishingConfiguration = true;
    try {
      _configurationChanges.notify();
      notifyListeners();
    } finally {
      _publishingConfiguration = false;
    }
  }

  /// 最近一次已应用事务；无文本变化的选区事务也会记录。
  DocumentChangeSet? get lastChangeSet => _lastChangeSet;

  /// 最近一次单笔文档编辑；批量事务返回 null，请改读 [lastChangeSet]。
  DocumentEdit? get lastEdit {
    final edits = _lastChangeSet?.edits;
    return edits != null && edits.length == 1 ? edits.single : null;
  }

  /// 当前完整选区集合；[primary] 是平台 IME 与兼容 API 使用的主选区。
  EditableSelectionSet get selections => _selections;

  /// 当前是否启用覆写输入模式；开启后折叠光标输入会替换同行下一完整字素。
  bool get overwriteMode => false;

  /// 当前主选区兼容门面。
  @override
  TextSelection get selection => _selections.primary.textSelection;

  /// 当前 IME composing 区间；无组合态为 [TextRange.empty]。
  @override
  TextRange get composing => _composing;

  /// 当前是否存在尚未结清的 IME 组合范围或组合历史会话。
  @override
  bool get hasActiveImeComposition => _imeSession != null || (_composing.isValid && !_composing.isCollapsed);

  /// 全文文本；大文档下会物化整篇字符串，热路径应读取 [document] 的区间。
  @override
  String get text => _document.text;

  /// 已确认文本的 UTF-16 长度；活动 composing 候选区不计入结果。
  @override
  int get committedTextLength {
    final composing = _composing;
    if (!composing.isValid || composing.isCollapsed) return _document.length;
    return _document.length - (composing.end - composing.start);
  }

  /// 保存时默认使用的换行形态；内核正文与全部 offset 仍统一按 LF 计算。
  TextDocumentEol get preferredEol => _document.preferredEol;

  /// 按 [eol] 序列化全文；null 时沿用载入或显式设置的 [preferredEol]。
  String serialize({TextDocumentEol? eol}) => _document.serialize(eol: eol);

  /// 以不超过 [chunkSize] 个 UTF-16 code unit 的块读取当前正文。
  ///
  /// 调用时即冻结当前 piece slice，默认输出内核 LF；迭代期间后续编辑不会改变
  /// 本次内容；[chunkSize] 必须至少为 2。
  Iterable<String> chunks({int chunkSize = TextDocument.defaultChunkSize, TextDocumentEol eol = TextDocumentEol.lf}) =>
      _document.chunks(chunkSize: chunkSize, eol: eol);

  /// 把当前正文按块写入 [output]，不会物化完整中间字符串。
  ///
  /// [eol] 为 null 时沿用 [preferredEol]；[chunkSize] 必须至少为 2。
  void writeTo(StringSink output, {TextDocumentEol? eol, int chunkSize = TextDocument.defaultChunkSize}) =>
      _document.writeTo(output, eol: eol, chunkSize: chunkSize);

  /// 整体替换文本：建立已保存的外部新基线，清空历史与 composing，并把主光标移到文末。
  @override
  set text(String value) {
    _checkMutationAllowed();
    final start = 0;
    final end = _document.length;
    final policyLength = _policyTextForRange(start, end, value).length;
    final caret = EditableSelectionSet(primary: EditableSelection.collapsed(offset: policyLength));
    _applyTransaction(
      EditTransaction(
        baseRevision: _docRevision,
        operations: [EditOperation.replace(start, end, value)],
        selectionsAfter: caret,
        undoStopBefore: true,
        undoStopAfter: true,
      ),
      addToHistory: false,
      closeImeSession: false,
      resetHistory: true,
      establishesExternalBaseline: true,
      beforePublish: (_) => _document.compact(),
    );
    _releaseLastChangePayload();
  }

  /// 主选区文本（跨行含换行符）。
  @override
  String get selectedText => selection.isCollapsed ? '' : _document.getText(selection.start, selection.end);

  /// 所有选区文本，顺序与 [selections] 一致；折叠光标对应空串。
  List<String> get selectedTexts => List<String>.unmodifiable(
    _selections.all.map((item) => item.isCollapsed ? '' : _document.getText(item.start, item.end)),
  );

  /// 当前是否可以撤销。
  @override
  bool get canUndo => _history.canUndo;

  /// 当前是否可以重做。
  @override
  bool get canRedo => _history.canRedo;

  /// 当前 undo 条目数。
  int get undoDepth => _history.undoDepth;

  /// 当前 redo 条目数。
  int get redoDepth => _history.redoDepth;

  /// undo 与 redo 当前直接持有的文本 code unit 数。
  int get historyRetainedCodeUnits => _history.retainedCodeUnits;

  /// 文本未变但高亮、装饰等呈现属性变化时使全部已挂载行失效。
  @override
  void invalidatePresentation() {
    if (_interceptingTransaction) {
      throw StateError('编辑事务拦截器执行期间不能同步修改 EditableController；请把后续编辑排到微任务或下一帧。');
    }
    _presentationRevision++;
    _bumpVisual();
  }

  // ===========================================================================
  // 事务与编辑原语
  // ===========================================================================

  /// 以当前模型强版本创建原子事务，适合保存后延迟提交。
  EditTransaction createTransaction(
    Iterable<EditOperation> operations, {
    EditableEditSource source = EditableEditSource.api,
    EditableSelectionSet? selectionsAfter,
    bool undoStopBefore = true,
    bool undoStopAfter = true,
  }) => EditTransaction(
    baseRevision: _docRevision,
    baseVersion: documentVersion,
    operations: operations,
    source: source,
    selectionsAfter: selectionsAfter,
    undoStopBefore: undoStopBefore,
    undoStopAfter: undoStopAfter,
  );

  /// 原子应用 [transaction]；基线修订不匹配或替换区间重叠时抛出错误。
  ///
  /// 所有 operation 的坐标都属于事务执行前的同一份文档；内核按坐标降序写入，
  /// 对外的 [DocumentChangeSet.edits] 始终按原文坐标升序返回。
  /// API 来源被拦截器拒绝时抛出 [EditableEditRejectedException]；键盘、IME、粘贴、
  /// 剪切与命令来源会安静返回未变化结果，避免正常 formatter 拒绝冒泡到框架。
  /// 两种拒绝都不会发布事务通知或改变控制器状态。
  DocumentChangeSet applyTransaction(EditTransaction transaction) {
    try {
      return _applyTransaction(transaction);
    } on EditableEditRejectedException {
      if (transaction.source == EditableEditSource.api) rethrow;
      return _unchangedResult(transaction.source);
    }
  }

  /// 以当前修订号原子应用多笔 [operations]。
  ///
  /// [overwriteCollapsedInput] 为 true 时，覆写模式会在拦截器读取 raw operation
  /// 之后，把命中折叠光标的单行插入扩成等量字素替换；多行文本保持普通替换。
  DocumentChangeSet applyEdits(
    Iterable<EditOperation> operations, {
    EditableEditSource source = EditableEditSource.api,
    EditableSelectionSet? selectionsAfter,
    bool undoStopBefore = false,
    bool undoStopAfter = false,
  }) {
    final transaction = createTransaction(
      operations,
      source: source,
      selectionsAfter: selectionsAfter,
      undoStopBefore: undoStopBefore,
      undoStopAfter: undoStopAfter,
    );
    return applyTransaction(transaction);
  }

  /// 键盘删除专用入口：保留左右方向，使同向删除可合并、切换方向必断开。
  @internal
  DocumentChangeSet applyKeyboardDeletionEdits(Iterable<EditOperation> operations, {required bool forward}) {
    final transaction = createTransaction(
      operations,
      source: EditableEditSource.keyboard,
      undoStopBefore: false,
      undoStopAfter: false,
    );
    try {
      return _applyTransaction(
        transaction,
        historyMergeKind: forward ? EditHistoryMergeKind.deleteRight : EditHistoryMergeKind.deleteLeft,
      );
    } on EditableEditRejectedException {
      return _unchangedResult(EditableEditSource.keyboard);
    }
  }

  /// 用 [text] 替换 `[start, end)`，并把选区置于 [selection]；缺省折叠到新文末尾。
  ///
  /// [addToHistory] 为 false 时把本次写入视为外部同步新基线：不写 undo，
  /// 清空全部旧历史并使 [isDirty] 变为 false，避免旧条目的坐标继续作用在新文本上；
  /// 同步通知完成后还会释放本次完整变更 payload，避免大文档镜像长期被
  /// [lastChangeSet] 持有。
  @override
  void replaceRange(
    int start,
    int end,
    String text, {
    TextSelection? selection,
    TextRange composing = TextRange.empty,
    bool addToHistory = true,
  }) {
    _checkMutationAllowed();
    final s = _clampOffset(math.min(start, end));
    final e = _clampOffset(math.max(start, end));
    final nextSelection = selection ?? TextSelection.collapsed(offset: s + _policyTextForRange(s, e, text).length);
    _applyTransaction(
      EditTransaction(
        baseRevision: _docRevision,
        operations: [EditOperation.replace(s, e, text)],
        selectionsAfter: _selectionSetOf(nextSelection),
        undoStopBefore: false,
        undoStopAfter: false,
      ),
      composing: composing,
      addToHistory: addToHistory,
      resetHistory: !addToHistory,
    );
    if (!addToHistory) _releaseLastChangePayload();
  }

  /// 在选区或指定范围输入文字，并应用当前格式化规则。
  @override
  void insertText(String text, {TextRange? range, TextSelection? selection}) {
    try {
      _applyTransaction(
        EditTransaction(
          baseRevision: _docRevision,
          operations: range == null
              ? _rawInputOperations(_selections.all, text)
              : [EditOperation.replace(range.start, range.end, text)],
          selectionsAfter: selection == null ? null : _selectionSetOf(selection),
          source: EditableEditSource.keyboard,
          undoStopBefore: range != null,
          undoStopAfter: range != null,
        ),
        historyMergeKind: EditHistoryMergeKind.typing,
      );
    } on EditableEditRejectedException {
      return;
    }
  }

  /// 把平台自动填充的全文值作为独立撤销单元写入，并清除 composing。
  ///
  /// 文本仍依次经过换行、单行、长度与格式化规则；平台给出的选区 offset
  /// 会按内建文本策略映射，非法选区折叠到最终文本末尾。
  void applyAutofillValue(TextEditingValue value) => _applyExternalTextValue(value, EditableEditSource.autofill);

  /// 把辅助技术写入的全文值作为用户输入提交，确保 formatter 与撤销合同生效。
  void applyAccessibilityValue(TextEditingValue value) =>
      _applyExternalTextValue(value, EditableEditSource.accessibility);

  void _applyExternalTextValue(TextEditingValue value, EditableEditSource source) {
    final available = _availablePolicyLength(_document.length);
    int mappedOffset(int offset) {
      if (offset < 0) return _applyPolicies(value.text, available: available).length;
      final bounded = offset.clamp(0, value.text.length);
      return _applyPolicies(value.text.substring(0, bounded), available: available).length;
    }

    final selection = value.selection.isValid
        ? TextSelection(
            baseOffset: mappedOffset(value.selection.baseOffset),
            extentOffset: mappedOffset(value.selection.extentOffset),
            affinity: value.selection.affinity,
            isDirectional: value.selection.isDirectional,
          )
        : TextSelection.collapsed(offset: mappedOffset(value.text.length));
    try {
      _applyTransaction(
        EditTransaction(
          baseRevision: _docRevision,
          operations: [EditOperation.replace(0, _document.length, value.text)],
          source: source,
          selectionsAfter: _selectionSetOf(selection),
          undoStopBefore: true,
          undoStopAfter: true,
        ),
        composing: TextRange.empty,
      );
    } on EditableEditRejectedException {
      return;
    }
  }

  static List<EditOperation> _rawInputOperations(Iterable<EditableSelection> selections, String text) =>
      <EditOperation>[for (final selection in selections) EditOperation.replace(selection.start, selection.end, text)];

  /// 删除 `[start, end)` 区间。
  @override
  void deleteRange(int start, int end) {
    if (start == end) return;
    replaceRange(start, end, '');
  }

  /// 更新完整选区集合；默认同时清空 composing 并断开连续输入段。
  ///
  /// [adjacencyPolicy] 默认保持历史行为并合并共享边界的范围；查找全部匹配等
  /// 明确需要相邻范围分别成为光标的场景，可传
  /// 边界时仍会合并，避免同一编辑点产生歧义。
  void setSelections(EditableSelectionSet selections, {bool keepComposing = false}) {
    _checkMutationAllowed();
    final nextComposing = keepComposing ? _composing : TextRange.empty;
    final next = _normalizeSelections(selections, composing: nextComposing);
    if (next == _selections && nextComposing == _composing) return;

    final session = keepComposing ? null : _imeSession;
    if (session != null) {
      final plan = _planImeFinalization(session);
      if (plan.needsDocumentEdit || _hasEditInterceptors) {
        try {
          final staged = _stageImeFinalization(session, plan, selectionsAfter: next, composingAfter: TextRange.empty);
          _applyStagedImeFinalization(staged);
          _history.closeRun();
        } on EditableEditRejectedException {
          // 纯选区动作不能在终态 formatter 拒绝时先写入新 selection；保留完整
          // composing 状态，等待平台后续消息或显式取消。
        }
        return;
      }
    }

    if (next != _selections) {
      // 任何非 selectAll 的选区写入都宣告上一次全选的光标显示锚点失效
      _selectAllCaretDisplayOffset = null;
    }
    _selections = next;
    _composing = nextComposing;
    if (session != null) _commitImeSession(session);
    _history.closeRun();
    _bumpVisual();
  }

  /// 更新主选区并清除全部次选区。
  @override
  void setSelection(TextSelection selection, {bool keepComposing = false}) {
    setSelections(_selectionSetOf(selection), keepComposing: keepComposing);
  }

  /// 折叠主选区到 [offset] 并清除次选区。
  @override
  void collapseTo(int offset) => setSelection(TextSelection.collapsed(offset: offset));

  /// 全选并清除次选区。
  @override
  int? get selectAllCaretDisplayOffset => _selectAllCaretDisplayOffset;
  int? _selectAllCaretDisplayOffset;

  /// 全选并进入全文档选区；同时记录全选前的光标位置供显示锚点使用。
  @override
  void selectAll() {
    final caretBefore = _selections.primary.active;
    setSelection(TextSelection(baseOffset: 0, extentOffset: _document.length));
    _selectAllCaretDisplayOffset = caretBefore;
  }

  // ===========================================================================
  // IME
  // ===========================================================================

  /// IME 专用：一次性提交文本替换、主选区与 composing。
  ///
  /// 平台文本协议只有一个选区；组合开始时次选区会被明确清除，undo 仍恢复组合
  /// 开始前的完整选区集合。组合中间态最终压成一个撤销单元。
  /// 活动会话的后续替换或 composing 跳过未编辑正文时，旧候选会先独立提交，
  /// 新候选再作为下一段会话写入，避免跨段 undo 吞掉中间正文。
  /// formatter 拒绝会安静保留旧状态，IME client 随后的结构校准会把旧值回推平台。
  void imeReplace(int start, int end, String text, {required TextSelection selection, required TextRange composing}) {
    try {
      _imeReplace(start, end, text, selection: selection, composing: composing);
    } on EditableEditRejectedException {
      return;
    }
  }

  void _imeReplace(int start, int end, String text, {required TextSelection selection, required TextRange composing}) {
    _checkMutationAllowed();
    final willCompose = composing.isValid && !composing.isCollapsed;
    if (_imeSession == null && !willCompose) {
      final primary = _selections.primary;
      final normalizedStart = math.min(start, end);
      final normalizedEnd = math.max(start, end);
      if (!_selections.single && normalizedStart == primary.start && normalizedEnd == primary.end) {
        _applyTransaction(
          EditTransaction(
            baseRevision: _docRevision,
            operations: _rawInputOperations(_selections.all, text),
            source: EditableEditSource.ime,
            undoStopBefore: false,
            undoStopAfter: false,
          ),
          composing: composing,
          historyMergeKind: EditHistoryMergeKind.typing,
        );
        return;
      }
      _applyTransaction(
        EditTransaction(
          baseRevision: _docRevision,
          operations: <EditOperation>[EditOperation.replace(start, end, text)],
          source: EditableEditSource.ime,
          selectionsAfter: _selectionSetOf(selection),
          undoStopBefore: false,
          undoStopAfter: false,
        ),
        composing: composing,
        remapImePolicyCoordinates: true,
        historyMergeKind: EditHistoryMergeKind.typing,
      );
      return;
    }

    _imeApplyEdits([EditOperation.replace(start, end, text)], selection: selection, composing: composing);
  }

  /// IME 专用：把同一平台消息内的多笔原文坐标编辑作为一个原子事务应用。
  ///
  /// [operations] 的坐标属于调用前的同一份文档，正文修订、事务通知、装饰映射、
  /// 拦截器与 undo 都只观察到一批。活动组合会话只允许一笔连续替换；原始批次或
  /// formatter 把它扩成多笔时会在正文写入前整批拒绝；单笔编辑或 composing
  /// 跳到不相交区间则先结清旧会话，再作为独立的新 IME 会话应用。
  /// 拒绝会安静保留旧状态，供 IME client 随后把本地结构回推平台。
  void imeApplyEdits(
    Iterable<EditOperation> operations, {
    required TextSelection selection,
    required TextRange composing,
  }) {
    try {
      _imeApplyEdits(List<EditOperation>.of(operations), selection: selection, composing: composing);
    } on EditableEditRejectedException {
      return;
    }
  }

  void _imeApplyEdits(
    List<EditOperation> operations, {
    required TextSelection selection,
    required TextRange composing,
  }) {
    _checkMutationAllowed();
    if (operations.isEmpty) {
      imeUpdateSelection(selection, composing);
      return;
    }
    final willCompose = composing.isValid && !composing.isCollapsed;
    if (_imeSession == null && !willCompose) {
      _applyTransaction(
        EditTransaction(
          baseRevision: _docRevision,
          operations: operations,
          source: EditableEditSource.ime,
          selectionsAfter: _selectionSetOf(selection),
          undoStopBefore: false,
          undoStopAfter: false,
        ),
        composing: composing,
        remapImePolicyCoordinates: true,
        historyMergeKind: EditHistoryMergeKind.typing,
      );
      return;
    }

    var transaction = EditTransaction(
      baseRevision: _docRevision,
      operations: operations,
      source: EditableEditSource.ime,
      selectionsAfter: _selectionSetOf(selection),
      undoStopBefore: false,
      undoStopAfter: false,
    );
    var effectiveComposing = composing;
    var continuationSession = _imeSession;
    var interceptorsAlreadyApplied = false;
    var finalizingCurrentSession = false;
    if (continuationSession != null) {
      var rawCrossesIntoNewComposition = false;
      if (willCompose && transaction.operations.length == 1) {
        final rawPrepared = _prepareOperations(
          transaction.operations,
          strictRange: transaction.baseVersion != null,
          deferMaxLength: true,
        );
        final rawOperation = rawPrepared.single;
        final rawMappedComposing = _remapRangeAfterPolicies(effectiveComposing, rawPrepared);
        final rawProjected = continuationSession.project(rawOperation);
        final rawComposingContinues =
            !rawMappedComposing.isValid ||
            rawMappedComposing.isCollapsed ||
            rawProjected.touches(rawMappedComposing.start, rawMappedComposing.end);
        rawCrossesIntoNewComposition =
            !continuationSession.touches(rawOperation.start, rawOperation.end) || !rawComposingContinues;
      }

      if (rawCrossesIntoNewComposition) {
        // formatter 必须按“旧段空终态 → 新段活动态”的顺序观察生命周期；
        // 先结清旧段再把已经 rebase 的新段交给 formatter，避免绑定层停在假终态。
        final plan = _planImeFinalization(continuationSession);
        if (plan.needsDocumentEdit || _hasEditInterceptors) {
          final finalization = _applyImeFinalization(
            continuationSession,
            plan,
            selectionsAfter: _selections,
            composingAfter: TextRange.empty,
          );
          if (finalization.edits.isNotEmpty) {
            transaction = _rebaseTransactionAfterEdits(transaction, finalization.edits);
            effectiveComposing = _transformRangeAfterEdits(effectiveComposing, finalization.edits);
          }
        } else {
          _commitImeSession(continuationSession);
        }
        continuationSession = null;

        final intercepted = _interceptTransaction(transaction, effectiveComposing);
        transaction = intercepted.transaction;
        effectiveComposing = intercepted.composingAfter;
        interceptorsAlreadyApplied = true;
      } else {
        // 连续消息先完成 formatter 与内建策略的只读预检：reject 时旧会话原样保留。
        final intercepted = _interceptTransaction(transaction, effectiveComposing);
        transaction = intercepted.transaction;
        effectiveComposing = intercepted.composingAfter;
        interceptorsAlreadyApplied = true;
        final prepared = _prepareOperations(
          transaction.operations,
          strictRange: transaction.baseVersion != null,
          deferMaxLength: true,
        );
        if (prepared.length != 1) {
          throw EditableEditRejectedException(source: transaction.source, reason: '活动组合会话只接受一笔连续替换。');
        }
        final operation = prepared.single;
        final mappedComposing = _remapRangeAfterPolicies(effectiveComposing, prepared);
        final projected = continuationSession.project(operation);
        final composingContinues =
            !mappedComposing.isValid ||
            mappedComposing.isCollapsed ||
            projected.touches(mappedComposing.start, mappedComposing.end);
        if (!continuationSession.touches(operation.start, operation.end) || !composingContinues) {
          if (willCompose) {
            throw EditableEditRejectedException(
              source: transaction.source,
              reason: '活动 composing 的 formatter 不能把连续更新改写到另一个候选区。',
            );
          }
          final plan = _planImeFinalization(continuationSession);
          if (plan.needsDocumentEdit) {
            final finalization = _applyImeFinalization(
              continuationSession,
              plan,
              selectionsAfter: _selections,
              composingAfter: TextRange.empty,
              // incoming 已以空 composing 经过 formatter，旧段不得重复调用。
              bypassInterceptors: true,
            );
            if (finalization.edits.isNotEmpty) {
              transaction = _rebaseTransactionAfterEdits(transaction, finalization.edits);
              effectiveComposing = _transformRangeAfterEdits(effectiveComposing, finalization.edits);
            }
          } else {
            _commitImeSession(continuationSession);
          }
          continuationSession = null;
        } else if (!willCompose) {
          transaction = _synthesizeImeFinalTransaction(transaction, continuationSession, operation);
          finalizingCurrentSession = true;
        }
      }
    }

    final opening = continuationSession == null;
    final session =
        continuationSession ?? _ImeSession(selectionsBefore: _selections, documentLengthBefore: _document.length);
    _applyTransaction(
      transaction,
      composing: effectiveComposing,
      addToHistory: false,
      closeImeSession: false,
      bypassInterceptors: interceptorsAlreadyApplied,
      requireSingleOperation: true,
      remapImePolicyCoordinates: true,
      deferMaxLength: willCompose,
      maxLengthDocumentBaseline: finalizingCurrentSession ? session.documentLengthBefore : null,
      imeContinuationSession: opening ? null : session,
      beforePublish: (changeSet) {
        if (opening) _imeSession = session;
        if (opening) {
          if (changeSet.edits.isNotEmpty) {
            final edit = changeSet.edits.single;
            session
              ..start = edit.start
              ..end = edit.start + edit.inserted.length
              ..removed = edit.removed;
          } else {
            session.seedFromCurrentRange(_composing, _document, fallbackOffset: selection.extentOffset);
          }
        } else if (changeSet.edits.isNotEmpty) {
          session.absorb(changeSet.edits.single);
        }
        final stillComposing = _composing.isValid && !_composing.isCollapsed;
        if (!stillComposing) _commitImeSession(session);
      },
    );
  }

  EditTransaction _synthesizeImeFinalTransaction(
    EditTransaction transaction,
    _ImeSession session,
    _PreparedOperation operation,
  ) {
    final start = math.min(session.start, operation.start);
    final end = math.max(session.end, operation.end);
    final candidate =
        _document.getText(start, operation.start) + operation.rawText + _document.getText(operation.end, end);
    return EditTransaction(
      baseRevision: transaction.baseRevision,
      baseVersion: transaction.baseVersion,
      operations: [EditOperation.replace(start, end, candidate)],
      source: transaction.source,
      selectionsAfter: transaction.selectionsAfter,
      undoStopBefore: transaction.undoStopBefore,
      undoStopAfter: transaction.undoStopAfter,
    );
  }

  /// IME 专用：仅更新主选区与 composing；跳区会先提交旧会话再切换新候选。
  void imeUpdateSelection(TextSelection selection, TextRange composing) {
    _checkMutationAllowed();
    final next = _normalizeSelections(_selectionSetOf(selection), composing: composing);
    final nextComposing = _clampRange(composing);
    final session = _imeSession;
    final jumpsSession =
        session != null &&
        nextComposing.isValid &&
        !nextComposing.isCollapsed &&
        !session.touches(nextComposing.start, nextComposing.end);
    final endsSession = session != null && (!nextComposing.isValid || nextComposing.isCollapsed);
    if (session != null && (jumpsSession || endsSession)) {
      final plan = _planImeFinalization(session);
      if (plan.needsDocumentEdit || _hasEditInterceptors) {
        late final DocumentChangeSet finalization;
        try {
          final staged = _stageImeFinalization(
            session,
            plan,
            selectionsAfter: endsSession ? next : _selections,
            composingAfter: TextRange.empty,
          );
          finalization = _applyStagedImeFinalization(staged);
        } on EditableEditRejectedException {
          return;
        }
        var effectiveNext = next;
        var effectiveNextComposing = nextComposing;
        if (finalization.edits.isNotEmpty) {
          effectiveNext = _transformSelections(next, finalization.edits);
          effectiveNextComposing = _transformRangeAfterEdits(nextComposing, finalization.edits);
        }
        if (effectiveNext != _selections || effectiveNextComposing != _composing) {
          _selections = effectiveNext;
          _composing = effectiveNextComposing;
          _bumpVisual();
        }
        _history.closeRun();
        return;
      }
    }
    if (jumpsSession) {
      // selection-only 消息可以隐式结束旧候选并宣告新候选；先提交再一次性
      // 切换 selection/composing，避免中间视觉态与额外通知。
      _commitImeSession(session);
    }
    if (next == _selections && nextComposing == _composing) return;
    _selections = next;
    _composing = nextComposing;
    if (!nextComposing.isValid || nextComposing.isCollapsed) _closeImeSession();
    _history.closeRun();
    _bumpVisual();
  }

  /// 明确结束当前 IME 组合生命周期。
  ///
  /// [commit] 为 true 时保留已落地候选文本、清空 composing，并把全部组合中间态
  /// 压成一个 undo 单元；[commitUnconfirmedAsPlainText] 仅在候选仍活动且只含 ASCII
  /// 字母与 U+0027 分隔符时删除分隔符后提交；为 false 时无历史地恢复组合开始前
  /// 的文本与完整选区。
  /// 返回是否实际结清了组合范围或历史会话。
  @override
  bool finishImeComposition({bool commit = true, bool commitUnconfirmedAsPlainText = false}) {
    _checkMutationAllowed();
    final session = _imeSession;
    final hadComposing = _composing.isValid && !_composing.isCollapsed;
    if (session == null && !hadComposing) return false;

    if (commit) {
      if (session != null) {
        final plan = _planImeFinalization(
          session,
          commitUnconfirmedAsPlainText: commitUnconfirmedAsPlainText && hadComposing,
        );
        if (plan.needsDocumentEdit || _hasEditInterceptors) {
          late final _StagedImeFinalization staged;
          try {
            staged = _stageImeFinalization(
              session,
              plan,
              selectionsAfter: _selections,
              composingAfter: TextRange.empty,
            );
          } on EditableEditRejectedException {
            // 被动失焦/动作键之后平台连接会立即关闭，不能留下一个再也收不到
            // compositionend 的悬空会话；终态被策略拒绝时按取消语义恢复基线。
            return _cancelImeComposition(session, hadComposing: hadComposing);
          } catch (error, stackTrace) {
            // formatter 的编程错误仍应向上暴露，但断连路径不能遗留半开会话；
            // stage 尚未写入任何状态，因此可先无拦截恢复组合前基线再原样重抛。
            _cancelImeComposition(session, hadComposing: hadComposing);
            Error.throwWithStackTrace(error, stackTrace);
          }
          _applyStagedImeFinalization(staged);
          return true;
        }
      }
      _composing = TextRange.empty;
      if (session != null) {
        _commitImeSession(session);
      } else {
        _history.closeRun();
      }
      if (hadComposing) _bumpVisual();
      return true;
    }

    return _cancelImeComposition(session, hadComposing: hadComposing);
  }

  bool _cancelImeComposition(_ImeSession? session, {required bool hadComposing}) {
    _imeSession = null;
    _history.closeRun();
    if (session == null) {
      _composing = TextRange.empty;
      if (hadComposing) _bumpVisual();
      return true;
    }
    _applyTransaction(
      EditTransaction(
        baseRevision: _docRevision,
        operations: [EditOperation.replace(session.start, session.end, session.removed)],
        source: EditableEditSource.ime,
        selectionsAfter: session.selectionsBefore,
        undoStopBefore: true,
        undoStopAfter: true,
      ),
      addToHistory: false,
      closeImeSession: false,
      bypassInterceptors: true,
      bypassPolicies: true,
    );
    _history.closeRun();
    return true;
  }

  /// 提交组合会话并压成单条 undo 事务。
  void _commitImeSession(_ImeSession session) {
    _imeSession = null;
    final inserted = _document.getText(session.start, session.end);
    _history.closeRun();
    if (session.removed == inserted) {
      return;
    }
    _history.push(
      EditHistoryEntry(
        changes: [EditHistoryChange(start: session.start, removed: session.removed, inserted: inserted)],
        selectionsBefore: session.selectionsBefore,
        selectionsAfter: _selections,
        source: EditableEditSource.ime,
        mergeKind: EditHistoryMergeKind.none,
      ),
    );
    _history.closeRun();
  }

  _ImeFinalizationPlan _planImeFinalization(_ImeSession session, {bool commitUnconfirmedAsPlainText = false}) {
    final sourceText = _document.getText(session.start, session.end);
    var replacementText = sourceText;
    var removedApostrophes = false;
    if (commitUnconfirmedAsPlainText) {
      final plainText = _unconfirmedAsciiCandidate(sourceText);
      if (plainText != null) {
        replacementText = plainText;
        removedApostrophes = replacementText.length != sourceText.length;
      }
    }
    final finalText = _applyPolicies(replacementText, available: _imeFinalPolicyLength(session));
    return _ImeFinalizationPlan(
      sourceText: sourceText,
      replacementText: replacementText,
      finalText: finalText,
      removedApostrophes: removedApostrophes,
    );
  }

  int _imeFinalPolicyLength(_ImeSession session) {
    final limit = maxLength;
    if (limit == null) return _noLimit;
    final effectiveLimit = math.max(limit, session.documentLengthBefore);
    final outsideLength = _document.length - (session.end - session.start);
    return math.max(0, effectiveLimit - outsideLength);
  }

  static String? _unconfirmedAsciiCandidate(String text) {
    if (text.isEmpty) return null;
    final output = StringBuffer();
    var hasLetter = false;
    for (var index = 0; index < text.length; index++) {
      final codeUnit = text.codeUnitAt(index);
      if (_isAsciiLetter(codeUnit)) {
        hasLetter = true;
        output.writeCharCode(codeUnit);
        continue;
      }
      if (codeUnit != 0x27) return null;
    }
    return hasLetter ? output.toString() : null;
  }

  static bool _isAsciiLetter(int codeUnit) =>
      (codeUnit >= 0x41 && codeUnit <= 0x5a) || (codeUnit >= 0x61 && codeUnit <= 0x7a);

  DocumentChangeSet _applyImeFinalization(
    _ImeSession session,
    _ImeFinalizationPlan plan, {
    required EditableSelectionSet selectionsAfter,
    required TextRange composingAfter,
    bool bypassInterceptors = false,
  }) => _applyStagedImeFinalization(
    _stageImeFinalization(
      session,
      plan,
      selectionsAfter: selectionsAfter,
      composingAfter: composingAfter,
      bypassInterceptors: bypassInterceptors,
    ),
  );

  _StagedImeFinalization _stageImeFinalization(
    _ImeSession session,
    _ImeFinalizationPlan plan, {
    required EditableSelectionSet selectionsAfter,
    required TextRange composingAfter,
    bool bypassInterceptors = false,
  }) {
    var requestedSelections = selectionsAfter;
    var requestedComposing = composingAfter;
    if (plan.removedApostrophes) {
      requestedSelections = _remapSelectionsAfterApostropheRemoval(requestedSelections, session, plan.sourceText);
      requestedComposing = _remapRangeAfterApostropheRemoval(requestedComposing, session, plan.sourceText);
    }
    var transaction = EditTransaction(
      baseRevision: _docRevision,
      operations: [EditOperation.replace(session.start, session.end, plan.replacementText)],
      source: EditableEditSource.ime,
      selectionsAfter: requestedSelections,
      undoStopBefore: false,
      undoStopAfter: false,
    );
    if (!bypassInterceptors) {
      final intercepted = _interceptTransaction(transaction, requestedComposing);
      transaction = intercepted.transaction;
      requestedComposing = intercepted.composingAfter;
    }
    final prepared = _prepareOperations(
      transaction.operations,
      strictRange: transaction.baseVersion != null,
      maxLengthDocumentBaseline: session.documentLengthBefore,
    );
    if (prepared.length != 1) {
      throw EditableEditRejectedException(source: transaction.source, reason: '活动组合会话只接受一笔连续替换。');
    }
    final operation = prepared.single;
    final projected = session.project(operation);
    final mappedComposing = _remapRangeAfterPolicies(requestedComposing, prepared);
    final composingContinues =
        !mappedComposing.isValid ||
        mappedComposing.isCollapsed ||
        projected.touches(mappedComposing.start, mappedComposing.end);
    if (!session.touches(operation.start, operation.end) || !composingContinues) {
      throw EditableEditRejectedException(source: transaction.source, reason: '组合替换与当前候选区不连续，已在正文写入前拒绝。');
    }
    return _StagedImeFinalization(
      session: session,
      transaction: transaction,
      composingAfter: requestedComposing,
      prepared: prepared,
      removedText: _document.getText(operation.start, operation.end),
    );
  }

  DocumentChangeSet _applyStagedImeFinalization(_StagedImeFinalization staged) => _applyTransaction(
    staged.transaction,
    composing: staged.composingAfter,
    addToHistory: false,
    closeImeSession: false,
    bypassInterceptors: true,
    requireSingleOperation: true,
    remapImePolicyCoordinates: true,
    maxLengthDocumentBaseline: staged.session.documentLengthBefore,
    imeContinuationSession: staged.session,
    preparedOperations: staged.prepared,
    beforePublish: (changeSet) {
      if (changeSet.edits.isNotEmpty) staged.session.absorb(changeSet.edits.single);
      _commitImeSession(staged.session);
    },
  );

  EditableSelectionSet _remapSelectionsAfterApostropheRemoval(
    EditableSelectionSet selections,
    _ImeSession session,
    String sourceText,
  ) {
    EditableSelection remap(EditableSelection selection) => selection.copyWith(
      anchor: _remapOffsetAfterApostropheRemoval(selection.anchor, session, sourceText),
      active: _remapOffsetAfterApostropheRemoval(selection.active, session, sourceText),
      clearPreferredX: true,
    );
    return EditableSelectionSet(primary: remap(selections.primary), secondary: selections.secondary.map(remap));
  }

  TextRange _remapRangeAfterApostropheRemoval(TextRange range, _ImeSession session, String sourceText) {
    if (!range.isValid) return range;
    final start = _remapOffsetAfterApostropheRemoval(range.start, session, sourceText);
    final end = _remapOffsetAfterApostropheRemoval(range.end, session, sourceText);
    return TextRange(start: math.min(start, end), end: math.max(start, end));
  }

  static int _remapOffsetAfterApostropheRemoval(int offset, _ImeSession session, String sourceText) {
    if (offset < session.start) return offset;
    if (offset > session.end) return offset - (sourceText.length - sourceText.replaceAll("'", '').length);
    final relative = (offset - session.start).clamp(0, sourceText.length);
    return session.start + sourceText.substring(0, relative).replaceAll("'", '').length;
  }

  /// 外因中断组合时先执行最终长度策略，再把已经落地的候选写入历史。
  DocumentChangeSet? _closeImeSession() {
    final session = _imeSession;
    if (session == null) return null;
    final plan = _planImeFinalization(session);
    if (plan.needsDocumentEdit || _hasEditInterceptors) {
      return _applyImeFinalization(session, plan, selectionsAfter: _selections, composingAfter: TextRange.empty);
    }
    _commitImeSession(session);
    return null;
  }

  _ImeSession? _imeSession;

  // ===========================================================================
  // undo / redo
  // ===========================================================================

  /// 撤销一个原子事务并恢复其完整编辑前选区。
  @override
  bool undoEdit() {
    _checkMutationAllowed();
    _closeImeSession();
    final entry = _history.undo();
    if (entry == null) return false;
    var delta = 0;
    final inverse = <EditOperation>[];
    for (final change in entry.changes) {
      final resultStart = change.start + delta;
      inverse.add(EditOperation.replace(resultStart, resultStart + change.inserted.length, change.removed));
      delta += change.delta;
    }
    _applyTransaction(
      EditTransaction(
        baseRevision: _docRevision,
        operations: inverse,
        source: EditableEditSource.undo,
        selectionsAfter: entry.selectionsBefore,
        undoStopBefore: true,
        undoStopAfter: true,
      ),
      addToHistory: false,
      closeImeSession: false,
      bypassPolicies: true,
    );
    return true;
  }

  /// 重做一个原子事务并恢复其完整编辑后选区。
  @override
  bool redoEdit() {
    _checkMutationAllowed();
    _closeImeSession();
    final entry = _history.redo();
    if (entry == null) return false;
    final operations = [
      for (final change in entry.changes)
        EditOperation.replace(change.start, change.start + change.removed.length, change.inserted),
    ];
    _applyTransaction(
      EditTransaction(
        baseRevision: _docRevision,
        operations: operations,
        source: EditableEditSource.redo,
        selectionsAfter: entry.selectionsAfter,
        undoStopBefore: true,
        undoStopAfter: true,
      ),
      addToHistory: false,
      closeImeSession: false,
      bypassPolicies: true,
    );
    return true;
  }

  /// 断开连续输入合并段。
  @override
  void closeHistoryRun() {
    _checkMutationAllowed();
    _history.closeRun();
  }

  // ===========================================================================
  // 事务实现
  // ===========================================================================

  DocumentChangeSet _applyTransaction(
    EditTransaction transaction, {
    TextRange composing = TextRange.empty,
    bool addToHistory = true,
    bool closeImeSession = true,
    bool resetHistory = false,
    bool bypassInterceptors = false,
    bool bypassPolicies = false,
    bool requireSingleOperation = false,
    bool establishesExternalBaseline = false,
    bool remapImePolicyCoordinates = false,
    bool deferMaxLength = false,
    int? maxLengthDocumentBaseline,
    _ImeSession? imeContinuationSession,
    List<_PreparedOperation>? preparedOperations,
    EditHistoryMergeKind historyMergeKind = EditHistoryMergeKind.automatic,
    void Function(DocumentChangeSet changeSet)? beforePublish,
  }) {
    _checkMutationAllowed();
    final baseVersion = transaction.baseVersion;
    if (baseVersion != null && !_versionIssuer.matches(baseVersion, _docRevision)) {
      throw StateError('编辑事务强基线不属于当前模型或已过期：事务为 $baseVersion，当前为 $documentVersion。');
    }
    if (transaction.baseRevision != _docRevision) {
      throw StateError('编辑事务基线已过期：期望 revision ${transaction.baseRevision}，当前为 $_docRevision。');
    }
    if (!bypassPolicies &&
        preparedOperations == null &&
        (!composing.isValid || composing.isCollapsed) &&
        transaction.source != EditableEditSource.undo &&
        transaction.source != EditableEditSource.redo) {
      transaction = _normalizeInlineTransaction(transaction);
    }
    var interceptorRewritten = false;
    if (!bypassInterceptors) {
      final intercepted = _interceptTransaction(transaction, composing);
      transaction = intercepted.transaction;
      composing = intercepted.composingAfter;
      interceptorRewritten = intercepted.rewritten;
    }
    assert(preparedOperations == null || bypassInterceptors, '预验证 operation 只允许在不再执行 interceptor/覆写展开的内部路径复用。');
    var prepared =
        preparedOperations ??
        _prepareOperations(
          transaction.operations,
          strictRange: transaction.baseVersion != null,
          bypassPolicies: bypassPolicies,
          deferMaxLength: deferMaxLength,
          maxLengthDocumentBaseline: maxLengthDocumentBaseline,
        );
    if (requireSingleOperation && prepared.length > 1) {
      throw EditableEditRejectedException(source: transaction.source, reason: '组合会话只接受单笔连续替换；多笔改写已在正文写入前整批拒绝。');
    }

    if (imeContinuationSession != null) {
      if (prepared.length != 1) {
        throw EditableEditRejectedException(source: transaction.source, reason: '活动组合会话只接受一笔连续替换。');
      }
      final operation = prepared.single;
      final projected = imeContinuationSession.project(operation);
      final preparedComposing = remapImePolicyCoordinates || interceptorRewritten
          ? _remapRangeAfterPolicies(composing, prepared)
          : composing;
      final composingContinues =
          !preparedComposing.isValid ||
          preparedComposing.isCollapsed ||
          projected.touches(preparedComposing.start, preparedComposing.end);
      if (!imeContinuationSession.touches(operation.start, operation.end) || !composingContinues) {
        throw EditableEditRejectedException(source: transaction.source, reason: '组合替换与当前候选区不连续，已在正文写入前拒绝。');
      }
    }

    _StagedImeFinalization? stagedImeFinalization;
    List<_PreparedOperation>? preparedAfterImeFinalization;
    final activeImeSession = _imeSession;
    if (closeImeSession && addToHistory && activeImeSession != null) {
      final session = activeImeSession;
      final plan = _planImeFinalization(session);
      if (plan.needsDocumentEdit || _hasEditInterceptors) {
        stagedImeFinalization = _stageImeFinalization(
          session,
          plan,
          selectionsAfter: _selections,
          composingAfter: TextRange.empty,
        );
        if (stagedImeFinalization.changesDocument) {
          final projectedTransaction = _projectTransactionAfterPreparedOperations(
            transaction,
            stagedImeFinalization.prepared,
          );
          preparedAfterImeFinalization = _prepareOperations(
            projectedTransaction.operations,
            strictRange: projectedTransaction.baseVersion != null,
            bypassPolicies: bypassPolicies,
            deferMaxLength: deferMaxLength,
            maxLengthDocumentBaseline: maxLengthDocumentBaseline,
            documentLengthOverride: stagedImeFinalization.projectedDocumentLength(_document.length),
          );
          if (requireSingleOperation && preparedAfterImeFinalization.length > 1) {
            throw EditableEditRejectedException(source: transaction.source, reason: '组合会话只接受单笔连续替换；多笔改写已在正文写入前整批拒绝。');
          }
        }
      }
    }

    if (resetHistory) {
      _imeSession = null;
      _history.clear();
    }
    if (closeImeSession && addToHistory) {
      final finalization = stagedImeFinalization == null
          ? _closeImeSession()
          : _applyStagedImeFinalization(stagedImeFinalization);
      if (finalization != null && finalization.edits.isNotEmpty) {
        transaction = _rebaseTransactionAfterEdits(transaction, finalization.edits);
        composing = _transformRangeAfterEdits(composing, finalization.edits);
        prepared = preparedAfterImeFinalization!;
      }
    }
    var requestedSelectionsAfter = transaction.selectionsAfter;
    if (remapImePolicyCoordinates || interceptorRewritten) {
      if (requestedSelectionsAfter != null) {
        requestedSelectionsAfter = _remapSelectionsAfterPolicies(requestedSelectionsAfter, prepared);
      }
      composing = _remapRangeAfterPolicies(composing, prepared);
    }
    if (transaction.undoStopBefore) _history.closeRun();

    final baseRevision = _docRevision;
    final selectionsBefore = _selections;
    final editsDescending = <DocumentEdit>[];
    final adoptsExternalBaseline = establishesExternalBaseline && prepared.length == 1;
    for (final operation in prepared.reversed) {
      final removed = _document.getText(operation.start, operation.end);
      if (removed == operation.text) continue;
      editsDescending.add(
        _document.replacePrepared(
          operation.start,
          operation.end,
          operation.text,
          removed: removed,
          preferImmutableBuffer: adoptsExternalBaseline && operation.start == 0 && operation.end == _document.length,
        ),
      );
    }
    final edits = editsDescending.reversed.toList(growable: false);

    final requestedSelections = requestedSelectionsAfter ?? _transformSelections(selectionsBefore, edits);
    final selectionsAfter = _normalizeSelections(requestedSelections, composing: composing);
    final nextComposing = _clampRange(composing);
    final documentChanged = edits.isNotEmpty;
    final visualChanged = documentChanged || selectionsAfter != _selections || nextComposing != _composing;

    _selections = selectionsAfter;
    _composing = nextComposing;
    if (documentChanged) {
      _docRevision++;
    }
    if (documentChanged && addToHistory) {
      _history.push(
        EditHistoryEntry(
          changes: [
            for (final edit in edits)
              EditHistoryChange(start: edit.start, removed: edit.removed, inserted: edit.inserted),
          ],
          selectionsBefore: selectionsBefore,
          selectionsAfter: selectionsAfter,
          source: transaction.source,
          mergeKind: historyMergeKind,
        ),
      );
    }
    if (transaction.undoStopAfter) _history.closeRun();
    if (visualChanged) _visualRevision++;

    final changeSet = DocumentChangeSet(
      baseRevision: baseRevision,
      revision: _docRevision,
      source: transaction.source,
      edits: edits,
      selectionsBefore: selectionsBefore,
      selectionsAfter: selectionsAfter,
      establishesExternalBaseline: establishesExternalBaseline,
    );
    beforePublish?.call(changeSet);
    _lastChangeSet = changeSet;
    _publishingTransaction = true;
    try {
      _transactionChanges.publish(changeSet);
    } finally {
      _publishingTransaction = false;
    }
    if (documentChanged) _docChanges.notify();
    if (visualChanged) {
      _visualChanges.notify();
      notifyListeners();
    }
    return changeSet;
  }

  void _checkMutationAllowed() {
    if (_interceptingTransaction) {
      throw StateError('编辑事务拦截器执行期间不能同步修改 EditableController；请把后续编辑排到微任务或下一帧。');
    }
    if (_publishingTransaction) {
      throw StateError('transactionChanges 通知期间不能同步修改 EditableController；请把后续编辑排到微任务或下一帧。');
    }
    if (_publishingConfiguration) {
      throw StateError('configurationChanges 通知期间不能同步修改 EditableController；请把后续编辑排到微任务或下一帧。');
    }
  }

  _InterceptedTransaction _interceptTransaction(EditTransaction transaction, TextRange composingAfter) {
    if (!_hasEditInterceptors ||
        transaction.source == EditableEditSource.undo ||
        transaction.source == EditableEditSource.redo) {
      return _InterceptedTransaction(transaction: transaction, composingAfter: composingAfter, rewritten: false);
    }
    _interceptingTransaction = true;
    try {
      var current = transaction;
      var currentComposingAfter = composingAfter;
      var rewritten = false;
      for (final interceptor in _effectiveInterceptors) {
        final decision = interceptor(
          EditableEditContext(
            document: _documentView,
            revision: _docRevision,
            selections: _selections,
            composing: _composing,
            transaction: current,
            composingAfter: currentComposingAfter,
          ),
        );
        switch (decision) {
          case EditableEditAllowed():
            break;
          case EditableEditRejected(:final reason):
            throw EditableEditRejectedException(source: current.source, reason: reason);
          case EditableEditRewritten(:final transaction, :final composingAfter):
            _validateRewrittenTransaction(current, transaction);
            current = _inheritBaseVersion(current, transaction);
            rewritten = true;
            if (composingAfter != null) {
              _validateRewrittenComposing(currentComposingAfter, composingAfter);
              currentComposingAfter = composingAfter;
            }
        }
      }
      return _InterceptedTransaction(transaction: current, composingAfter: currentComposingAfter, rewritten: rewritten);
    } finally {
      _interceptingTransaction = false;
    }
  }

  static void _validateRewrittenTransaction(EditTransaction current, EditTransaction rewritten) {
    if (rewritten.baseRevision != current.baseRevision ||
        (rewritten.baseVersion != null && rewritten.baseVersion != current.baseVersion) ||
        rewritten.source != current.source ||
        rewritten.undoStopBefore != current.undoStopBefore ||
        rewritten.undoStopAfter != current.undoStopAfter) {
      throw ArgumentError.value(rewritten, 'transaction', '拦截器只能改写 operations 与 selectionsAfter，不能改变基线、来源或 undo 分组边界。');
    }
  }

  static EditTransaction _inheritBaseVersion(EditTransaction current, EditTransaction rewritten) {
    final version = current.baseVersion;
    if (version == null || rewritten.baseVersion != null) return rewritten;
    return EditTransaction(
      baseRevision: rewritten.baseRevision,
      baseVersion: version,
      operations: rewritten.operations,
      source: rewritten.source,
      selectionsAfter: rewritten.selectionsAfter,
      undoStopBefore: rewritten.undoStopBefore,
      undoStopAfter: rewritten.undoStopAfter,
    );
  }

  static void _validateRewrittenComposing(TextRange current, TextRange rewritten) {
    final currentlyComposing = current.isValid && !current.isCollapsed;
    final rewrittenComposing = rewritten.isValid && !rewritten.isCollapsed;
    if (currentlyComposing != rewrittenComposing) {
      throw ArgumentError.value(rewritten, 'composingAfter', '拦截器可以调整组合区间，但不能开始或结束组合会话。');
    }
  }

  void _releaseLastChangePayload() {
    _lastChangeSet = null;
    _transactionChanges.clearRetainedValue();
  }

  DocumentChangeSet _unchangedResult(EditableEditSource source) => DocumentChangeSet(
    baseRevision: _docRevision,
    revision: _docRevision,
    source: source,
    edits: const [],
    selectionsBefore: _selections,
    selectionsAfter: _selections,
  );

  List<_PreparedOperation> _prepareOperations(
    Iterable<EditOperation> operations, {
    required bool strictRange,
    bool bypassPolicies = false,
    bool deferMaxLength = false,
    int? maxLengthDocumentBaseline,
    int? documentLengthOverride,
  }) {
    final documentLength = documentLengthOverride ?? _document.length;
    final prepared = <_PreparedOperation>[];
    for (final operation in operations) {
      final rawStart = math.min(operation.start, operation.end);
      final rawEnd = math.max(operation.start, operation.end);
      if (strictRange && (rawStart < 0 || rawEnd > documentLength)) {
        throw RangeError.range(
          rawStart < 0 ? rawStart : rawEnd,
          0,
          documentLength,
          'operation',
          '强版本事务区间 [$rawStart, $rawEnd) 超出当前文档范围',
        );
      }
      final start = documentLengthOverride == null ? _clampOffset(rawStart) : rawStart.clamp(0, documentLength);
      final end = documentLengthOverride == null ? _clampOffset(rawEnd) : rawEnd.clamp(0, documentLength);
      prepared.add(
        _PreparedOperation(
          start: start,
          end: end,
          text: operation.text,
          rawText: operation.text,
          policyAvailable: _noLimit,
        ),
      );
    }
    prepared.sort((a, b) {
      final start = a.start.compareTo(b.start);
      return start != 0 ? start : a.end.compareTo(b.end);
    });
    for (var i = 1; i < prepared.length; i++) {
      final previous = prepared[i - 1];
      final current = prepared[i];
      final duplicateInsertion =
          previous.start == previous.end && current.start == current.end && previous.start == current.start;
      if (current.start < previous.end || duplicateInsertion) {
        throw ArgumentError.value(operations, 'operations', '同一事务的编辑区间必须互不重叠，且同一点只能有一笔插入。');
      }
    }

    // undo/redo 与 IME cancel 回放的文本已经来自文档历史，必须忠实恢复；
    // 热更新后的单行或长度策略不得二次改写旧历史。
    if (bypassPolicies) return prepared;

    var available = _noLimit;
    if (maxLength != null && !deferMaxLength) {
      final removedLength = prepared.fold<int>(0, (sum, item) => sum + item.end - item.start);
      final baseline = maxLengthDocumentBaseline;
      available = baseline == null
          ? math.max(maxLength!, documentLength) - (documentLength - removedLength)
          : math.max(maxLength!, baseline) - (documentLength - removedLength);
    }
    final result = <_PreparedOperation>[];
    for (final operation in prepared) {
      final operationAvailable = available;
      final text = _applyPolicies(operation.text, available: available);
      if (maxLength != null && !deferMaxLength) available = math.max(0, available - text.length);
      result.add(
        _PreparedOperation(
          start: operation.start,
          end: operation.end,
          text: text,
          rawText: operation.rawText,
          policyAvailable: operationAvailable,
        ),
      );
    }
    return result;
  }

  EditableSelectionSet _remapSelectionsAfterPolicies(
    EditableSelectionSet selections,
    List<_PreparedOperation> operations,
  ) {
    EditableSelection remap(EditableSelection selection) => selection.copyWith(
      anchor: _remapOffsetAfterPolicies(selection.anchor, operations),
      active: _remapOffsetAfterPolicies(selection.active, operations),
      clearPreferredX: true,
    );
    return EditableSelectionSet(primary: remap(selections.primary), secondary: selections.secondary.map(remap));
  }

  TextRange _remapRangeAfterPolicies(TextRange range, List<_PreparedOperation> operations) {
    if (!range.isValid) return range;
    final start = _remapOffsetAfterPolicies(range.start, operations);
    final end = _remapOffsetAfterPolicies(range.end, operations);
    return TextRange(start: math.min(start, end), end: math.max(start, end));
  }

  /// 平台端点属于策略执行前的事务结果；按每笔实际 prepared 文本长度投影回本地结果。
  int _remapOffsetAfterPolicies(int offset, List<_PreparedOperation> operations) {
    var rawDelta = 0;
    var preparedDelta = 0;
    for (final operation in operations) {
      final removedLength = operation.end - operation.start;
      final rawStart = operation.start + rawDelta;
      final rawEnd = rawStart + operation.rawText.length;
      final preparedStart = operation.start + preparedDelta;
      if (offset < rawStart) return offset + preparedDelta - rawDelta;
      if (offset <= rawEnd) {
        final relative = offset - rawStart;
        final preparedPrefixLength = relative == operation.rawText.length
            ? operation.text.length
            : _applyPolicies(operation.rawText.substring(0, relative), available: operation.policyAvailable).length;
        return preparedStart + preparedPrefixLength;
      }
      rawDelta += operation.rawText.length - removedLength;
      preparedDelta += operation.text.length - removedLength;
    }
    return offset + preparedDelta - rawDelta;
  }

  EditableSelectionSet _transformSelections(EditableSelectionSet selections, List<DocumentEdit> edits) {
    if (edits.isEmpty) return selections;
    final exactReplacementEnds = <({int start, int end}), int>{};
    var delta = 0;
    for (final edit in edits) {
      exactReplacementEnds[(start: edit.start, end: edit.end)] = edit.start + delta + edit.inserted.length;
      delta += edit.inserted.length - edit.removed.length;
    }
    EditableSelection transform(EditableSelection selection) {
      final exactEnd = exactReplacementEnds[(start: selection.start, end: selection.end)];
      if (exactEnd != null) {
        return selection.copyWith(anchor: exactEnd, active: exactEnd, clearPreferredX: true);
      }
      return selection.copyWith(
        anchor: _transformOffset(selection.anchor, edits),
        active: _transformOffset(selection.active, edits),
        clearPreferredX: true,
      );
    }

    return EditableSelectionSet(primary: transform(selections.primary), secondary: selections.secondary.map(transform));
  }

  EditTransaction _rebaseTransactionAfterEdits(EditTransaction transaction, List<DocumentEdit> edits) =>
      EditTransaction(
        baseRevision: _docRevision,
        baseVersion: transaction.baseVersion == null ? null : documentVersion,
        operations: [
          for (final operation in transaction.operations)
            EditOperation.replace(
              _transformOffset(operation.start, edits),
              _transformOffset(operation.end, edits),
              operation.text,
            ),
        ],
        source: transaction.source,
        selectionsAfter: transaction.selectionsAfter == null
            ? null
            : _transformSelections(transaction.selectionsAfter!, edits),
        undoStopBefore: transaction.undoStopBefore,
        undoStopAfter: transaction.undoStopAfter,
      );

  EditTransaction _projectTransactionAfterPreparedOperations(
    EditTransaction transaction,
    List<_PreparedOperation> operations,
  ) => EditTransaction(
    baseRevision: transaction.baseRevision,
    baseVersion: transaction.baseVersion,
    operations: [
      for (final operation in transaction.operations)
        EditOperation.replace(
          _transformOffsetWithPreparedOperations(operation.start, operations),
          _transformOffsetWithPreparedOperations(operation.end, operations),
          operation.text,
        ),
    ],
    source: transaction.source,
    selectionsAfter: transaction.selectionsAfter == null
        ? null
        : _transformSelectionsWithPreparedOperations(transaction.selectionsAfter!, operations),
    undoStopBefore: transaction.undoStopBefore,
    undoStopAfter: transaction.undoStopAfter,
  );

  TextRange _transformRangeAfterEdits(TextRange range, List<DocumentEdit> edits) {
    if (!range.isValid) return range;
    final start = _transformOffset(range.start, edits);
    final end = _transformOffset(range.end, edits);
    return TextRange(start: math.min(start, end), end: math.max(start, end));
  }

  EditableSelectionSet _transformSelectionsWithPreparedOperations(
    EditableSelectionSet selections,
    List<_PreparedOperation> operations,
  ) {
    final exactReplacementEnds = <({int start, int end}), int>{};
    var delta = 0;
    for (final operation in operations) {
      exactReplacementEnds[(start: operation.start, end: operation.end)] =
          operation.start + delta + operation.text.length;
      delta += operation.text.length - (operation.end - operation.start);
    }
    EditableSelection transform(EditableSelection selection) {
      final exactEnd = exactReplacementEnds[(start: selection.start, end: selection.end)];
      if (exactEnd != null) {
        return selection.copyWith(anchor: exactEnd, active: exactEnd, clearPreferredX: true);
      }
      return selection.copyWith(
        anchor: _transformOffsetWithPreparedOperations(selection.anchor, operations),
        active: _transformOffsetWithPreparedOperations(selection.active, operations),
        clearPreferredX: true,
      );
    }

    return EditableSelectionSet(primary: transform(selections.primary), secondary: selections.secondary.map(transform));
  }

  static int _transformOffsetWithPreparedOperations(int offset, List<_PreparedOperation> operations) {
    var delta = 0;
    for (final operation in operations) {
      if (offset < operation.start) return offset + delta;
      if (offset <= operation.end) return operation.start + delta + operation.text.length;
      delta += operation.text.length - (operation.end - operation.start);
    }
    return offset + delta;
  }

  static int _transformOffset(int offset, List<DocumentEdit> edits) {
    var delta = 0;
    for (final edit in edits) {
      final start = edit.start;
      final end = edit.start + edit.removed.length;
      if (offset < start) return offset + delta;
      if (offset <= end) return start + delta + edit.inserted.length;
      delta += edit.inserted.length - edit.removed.length;
    }
    return offset + delta;
  }

  // ===========================================================================
  // 策略、选区与通知
  // ===========================================================================

  String _policyTextForRange(int start, int end, String text) {
    var available = _noLimit;
    if (maxLength != null) {
      final s = _clampOffset(math.min(start, end));
      final e = _clampOffset(math.max(start, end));
      available = _availablePolicyLength(e - s);
    }
    return _applyPolicies(text, available: available);
  }

  /// 热降上限不改写既有正文；超限期间只禁止净增长，并允许等长替换与删除。
  int _availablePolicyLength(int removedLength) {
    final limit = maxLength;
    if (limit == null) return _noLimit;
    final effectiveLimit = math.max(limit, _document.length);
    return effectiveLimit - (_document.length - removedLength);
  }

  /// 写入策略：换行归一化 → 单行剔除换行 → 超限截断。
  String _applyPolicies(String text, {required int available}) {
    var result = TextDocument.normalizeNewlines(text);
    if (singleLine) result = result.replaceAll('\n', '');
    if (result.length > available) result = _truncateNoSplit(result, math.max(available, 0));
    return result;
  }

  static String _truncateNoSplit(String text, int limit) {
    if (limit <= 0) return '';
    if (text.length <= limit) return text;
    var cut = 0;
    for (final grapheme in text.characters) {
      final next = cut + grapheme.length;
      if (next > limit) break;
      cut = next;
    }
    return text.substring(0, cut);
  }

  /// 增量钳制；不会像读取 document.length 一样强制补全全部行首索引。
  int _clampOffset(int offset) {
    if (offset <= 0) return 0;
    final position = _document.positionOf(offset);
    return _document.lineStart(position.line) + position.column;
  }

  EditableSelection _clampEditableSelection(EditableSelection selection) {
    final anchor = _clampOffset(selection.anchor);
    final active = _clampOffset(selection.active);
    if (anchor == selection.anchor && active == selection.active) return selection;
    return selection.copyWith(anchor: anchor, active: active);
  }

  EditableSelectionSet _normalizeSelections(EditableSelectionSet selections, {TextRange? composing}) {
    var value = _clampEditableSelection(selections.primary);
    final inline = inlineContentModel;
    if (inline != null) {
      if (value.isCollapsed) {
        final match = inline.containing(this, value.active, composing: composing);
        if (match != null) {
          final backward = value.active < _selections.primary.active;
          final offset = backward ? match.start : match.end;
          value = value.copyWith(anchor: offset, active: offset);
        }
      } else {
        final start = inline.containing(this, value.start, composing: composing)?.start ?? value.start;
        final end = inline.containing(this, value.end, composing: composing)?.end ?? value.end;
        value = value.copyWith(
          anchor: value.anchor <= value.active ? start : end,
          active: value.anchor <= value.active ? end : start,
        );
      }
    }
    return EditableSelectionSet.single(value);
  }

  /// 用户编辑覆盖到对象内部时扩成整段；IME 组合中的文字由匹配表暂时排除。
  EditTransaction _normalizeInlineTransaction(EditTransaction transaction) {
    final inline = inlineContentModel;
    if (inline == null || transaction.operations.isEmpty) return transaction;
    final pairs = <({EditOperation raw, EditOperation value})>[];
    var changed = false;
    for (final raw in transaction.operations) {
      final operation = raw.normalized;
      final start = inline.containing(this, operation.start)?.start ?? operation.start;
      final end = inline.containing(this, operation.end)?.end ?? operation.end;
      final value = start == operation.start && end == operation.end
          ? operation
          : EditOperation.replace(start, end, operation.text);
      changed |= !identical(value, operation);
      pairs.add((raw: operation, value: value));
    }
    if (!changed) return transaction;
    pairs.sort((a, b) => a.raw.start.compareTo(b.raw.start));
    int offsetAfter(int offset) {
      var rawDelta = 0;
      var nextDelta = 0;
      for (final pair in pairs) {
        final raw = pair.raw;
        final value = pair.value;
        final before = value.start + rawDelta;
        final inserted = raw.start + rawDelta;
        final after = value.end + rawDelta + raw.text.length - (raw.end - raw.start);
        if (offset < before) break;
        if (offset <= inserted) return value.start + nextDelta;
        if (offset <= inserted + raw.text.length) return value.start + nextDelta + offset - inserted;
        if (offset < after) return value.start + nextDelta + value.text.length;
        rawDelta += raw.text.length - (raw.end - raw.start);
        nextDelta += value.text.length - (value.end - value.start);
      }
      return offset + nextDelta - rawDelta;
    }

    final requested = transaction.selectionsAfter;
    EditableSelection remap(EditableSelection value) =>
        value.copyWith(anchor: offsetAfter(value.anchor), active: offsetAfter(value.active));
    return EditTransaction(
      baseRevision: transaction.baseRevision,
      baseVersion: transaction.baseVersion,
      operations: pairs.map((pair) => pair.value),
      selectionsAfter: requested == null
          ? null
          : EditableSelectionSet(primary: remap(requested.primary), secondary: requested.secondary.map(remap)),
      source: transaction.source,
      undoStopBefore: transaction.undoStopBefore,
      undoStopAfter: transaction.undoStopAfter,
    );
  }

  EditableSelectionSet _selectionSetOf(TextSelection selection) => EditableSelectionSet(
    primary: EditableSelection(
      anchor: math.max(0, selection.baseOffset),
      active: math.max(0, selection.extentOffset),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    ),
  );

  TextRange _clampRange(TextRange range) {
    if (!range.isValid || range.isCollapsed) return TextRange.empty;
    final start = _clampOffset(range.start);
    final end = _clampOffset(range.end);
    if (start >= end) return TextRange.empty;
    if (start == range.start && end == range.end) return range;
    return TextRange(start: start, end: end);
  }

  void _bumpVisual() {
    if (inlineContent.isNotEmpty) _selections = _normalizeSelections(_selections, composing: _composing);
    _visualRevision++;
    if (_paintSelectionWrite) return;
    _publishVisual();
  }

  void _publishVisual() {
    _visualChanges.notify();
    notifyListeners();
  }

  bool _paintSelectionWrite = false;

  @override
  void dispose() {
    _disposed = true;
    _docChanges.dispose();
    _visualChanges.dispose();
    _configurationChanges.dispose();
    _transactionChanges.dispose();
    super.dispose();
  }
}

/// 绘制前更新真实选区，业务监听留在本帧安全阶段；不导出到用户 API。
extension EditablePaintSelection on EditableController {
  /// 仅承接既有拖选的纯选区写入，不在绘制期执行文本事务。
  bool applyPaintSelection(VoidCallback update, void Function(VoidCallback) publish) {
    assert(!_paintSelectionWrite && !hasActiveImeComposition);
    final revision = _visualRevision;
    _paintSelectionWrite = true;
    try {
      update();
    } finally {
      _paintSelectionWrite = false;
    }
    if (_visualRevision == revision) return false;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) publish(_publishVisual);
    });
    return true;
  }
}

/// 暴露 notify 的内部通知器。
class _DocNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _TransactionNotifier extends ChangeNotifier implements ValueListenable<DocumentChangeSet?> {
  DocumentChangeSet? _value;

  @override
  DocumentChangeSet? get value => _value;

  void publish(DocumentChangeSet value) {
    _value = value;
    notifyListeners();
  }

  void clearRetainedValue() => _value = null;
}

class _ReadOnlyTextDocument extends TextDocument {
  _ReadOnlyTextDocument(this._source);

  final TextDocument _source;

  @override
  int get lineCount => _source.lineCount;

  @override
  int get length => _source.length;

  @override
  bool get isEmpty => _source.isEmpty;

  @override
  TextDocumentEol get preferredEol => _source.preferredEol;

  @override
  String serialize({TextDocumentEol? eol}) => _source.serialize(eol: eol);

  @override
  Iterable<String> chunks({int chunkSize = TextDocument.defaultChunkSize, TextDocumentEol eol = TextDocumentEol.lf}) =>
      _source.chunks(chunkSize: chunkSize, eol: eol);

  @override
  void writeTo(StringSink output, {TextDocumentEol? eol, int chunkSize = TextDocument.defaultChunkSize}) =>
      _source.writeTo(output, eol: eol, chunkSize: chunkSize);

  @override
  void setPreferredEol(TextDocumentEol value) {
    throw UnsupportedError('EditableController.document 是只读门面；请使用 EditableController.setPreferredEol。');
  }

  @override
  String lineAt(int line) => _source.lineAt(line);

  @override
  List<String> readLines(int startLine, {int maxLines = 64, int maxCodeUnits = TextDocument.defaultChunkSize}) =>
      _source.readLines(startLine, maxLines: maxLines, maxCodeUnits: maxCodeUnits);

  @override
  int lineLength(int line) => _source.lineLength(line);

  @override
  int lineStart(int line) => _source.lineStart(line);

  @override
  int lineEnd(int line) => _source.lineEnd(line);

  @override
  int lineIndexOf(int offset) => _source.lineIndexOf(offset);

  @override
  LinePosition positionOf(int offset) => _source.positionOf(offset);

  @override
  int offsetOf(int line, int column) => _source.offsetOf(line, column);

  @override
  int get debugValidStartCount => _source.debugValidStartCount;

  @override
  int get debugTreeHeight => _source.debugTreeHeight;

  @override
  int get debugAddBufferPageCount => _source.debugAddBufferPageCount;

  @override
  int get debugPieceCount => _source.debugPieceCount;

  @override
  int get debugOriginalCodeUnits => _source.debugOriginalCodeUnits;

  @override
  int get debugAddBufferCodeUnits => _source.debugAddBufferCodeUnits;

  @override
  int get debugAddBufferAllocatedCodeUnits => _source.debugAddBufferAllocatedCodeUnits;

  @override
  int get debugLiveOriginalCodeUnits => _source.debugLiveOriginalCodeUnits;

  @override
  int get debugLiveAddCodeUnits => _source.debugLiveAddCodeUnits;

  @override
  int get debugDeadOriginalCodeUnits => _source.debugDeadOriginalCodeUnits;

  @override
  int get debugDeadAddCodeUnits => _source.debugDeadAddCodeUnits;

  @override
  int get debugNodeVisitCount => _source.debugNodeVisitCount;

  @override
  int get debugNodeRelinkCount => _source.debugNodeRelinkCount;

  @override
  void debugResetTreeCounters() => _source.debugResetTreeCounters();

  @override
  String getText(int start, int end) => _source.getText(start, end);

  @override
  String get text => _source.text;

  @override
  bool compact() {
    throw UnsupportedError('EditableController.document 是只读门面；请使用 EditableController.compactDocument。');
  }

  @override
  DocumentEdit replace(int start, int end, String text) {
    throw UnsupportedError('EditableController.document 是只读门面；请使用 applyTransaction、applyEdits 或 replaceRange。');
  }

  @override
  DocumentEdit replacePrepared(
    int start,
    int end,
    String text, {
    required String removed,
    bool preferImmutableBuffer = false,
  }) {
    throw UnsupportedError('EditableController.document 是只读门面；请使用 applyTransaction、applyEdits 或 replaceRange。');
  }
}

class _PreparedOperation {
  const _PreparedOperation({
    required this.start,
    required this.end,
    required this.text,
    required this.rawText,
    required this.policyAvailable,
  });

  final int start;
  final int end;
  final String text;
  final String rawText;
  final int policyAvailable;
}

class _InterceptedTransaction {
  const _InterceptedTransaction({required this.transaction, required this.composingAfter, required this.rewritten});

  final EditTransaction transaction;
  final TextRange composingAfter;
  final bool rewritten;
}

class _ImeFinalizationPlan {
  const _ImeFinalizationPlan({
    required this.sourceText,
    required this.replacementText,
    required this.finalText,
    required this.removedApostrophes,
  });

  final String sourceText;
  final String replacementText;
  final String finalText;
  final bool removedApostrophes;

  bool get needsDocumentEdit => finalText != sourceText;
}

class _StagedImeFinalization {
  const _StagedImeFinalization({
    required this.session,
    required this.transaction,
    required this.composingAfter,
    required this.prepared,
    required this.removedText,
  });

  final _ImeSession session;
  final EditTransaction transaction;
  final TextRange composingAfter;
  final List<_PreparedOperation> prepared;
  final String removedText;

  _PreparedOperation get operation => prepared.single;

  bool get changesDocument => operation.text != removedText;

  int projectedDocumentLength(int currentLength) =>
      currentLength - (operation.end - operation.start) + operation.text.length;
}

/// IME 组合会话：聚合 composing 中间态，提交时压成单条 undo。
class _ImeSession {
  _ImeSession({required this.selectionsBefore, required this.documentLengthBefore});

  final EditableSelectionSet selectionsBefore;
  final int documentLengthBefore;

  int start = 0;
  int end = 0;
  String removed = '';

  bool touches(int rangeStart, int rangeEnd) => rangeStart <= end && rangeEnd >= start;

  _ImeSessionRange project(_PreparedOperation operation) {
    final projectedStart = math.min(start, operation.start);
    final projectedEnd = math.max(end, operation.end) + operation.text.length - (operation.end - operation.start);
    return _ImeSessionRange(projectedStart, math.max(projectedStart, projectedEnd));
  }

  void absorb(DocumentEdit edit) {
    assert(touches(edit.start, edit.start + edit.removed.length), 'IME 会话只能聚合连续或相交的正文编辑。');
    final removedEnd = edit.start + edit.removed.length;
    if (edit.start < start) {
      final prefixLength = start - edit.start;
      removed = edit.removed.substring(0, prefixLength.clamp(0, edit.removed.length)) + removed;
      start = edit.start;
    }
    if (removedEnd > end) {
      final suffixLength = removedEnd - end;
      removed += edit.removed.substring((edit.removed.length - suffixLength).clamp(0, edit.removed.length));
    }
    end = math.max(end, removedEnd) + (edit.inserted.length - edit.removed.length);
  }

  /// 无正文变化但平台已开启 composing 时记录可取消的当前范围。
  void seedFromCurrentRange(TextRange range, TextDocument document, {required int fallbackOffset}) {
    final valid = range.isValid && !range.isCollapsed;
    start = valid ? range.start : fallbackOffset.clamp(0, document.length);
    end = valid ? range.end : start;
    removed = valid ? document.getText(start, end) : '';
  }
}

class _ImeSessionRange {
  const _ImeSessionRange(this.start, this.end);

  final int start;
  final int end;

  bool touches(int rangeStart, int rangeEnd) => rangeStart <= end && rangeEnd >= start;
}
