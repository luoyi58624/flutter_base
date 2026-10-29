import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'editable_controller.dart';

/// 管理文本、光标和选区，并查询已挂载视图的几何。
abstract class ElEditableController extends ChangeNotifier {
  /// 创建普通文本控制器。
  factory ElEditableController({
    String text = '',
    bool singleLine = false,
    int? maxLength,
    List<TextInputFormatter> inputFormatters = const [],
    Map<String, WidgetBuilder> inlineContent = const {},
  }) => EditableController(
    text: text,
    singleLine: singleLine,
    maxLength: maxLength,
    inputFormatters: inputFormatters,
    inlineContent: inlineContent,
  );

  /// 为同一文本创建独立视口门面；释放它不会释放原控制器。
  factory ElEditableController.view(ElEditableController source) = _ViewportController;

  /// 供上层编辑器实现自己的文本模型，视图仍使用同一套输入和排版能力。
  @protected
  ElEditableController.base();

  /// 将原文 token 显示为行内组件；原文、选区、复制与保存仍使用原始 UTF-16 坐标。
  ///
  /// 构建器按可见范围调用；组件受固定行高约束，宽度由布局测得。
  /// 同一起点取最长 token，未知文字照常显示。返回表不可修改，更新时重新赋值。
  Map<String, WidgetBuilder> get inlineContent => _inlineContent;
  Map<String, WidgetBuilder> _inlineContent = const {};
  set inlineContent(Map<String, WidgetBuilder> value) {
    if (mapEquals(_inlineContent, value)) return;
    for (final token in value.keys) {
      if (token.isEmpty || token.contains('\n') || token.contains('\r')) {
        throw ArgumentError.value(token, 'inlineContent', 'token 必须为非空单行文字');
      }
    }
    _inlineContent = value.isEmpty ? const {} : Map.unmodifiable(value);
    setSelection(selection, keepComposing: true);
    invalidatePresentation();
  }

  /// 当前全文；大文本按需使用 [getText] 读取片段。
  String get text;
  set text(String value);

  /// 正文的 UTF-16 长度。
  int get length;

  /// 当前主选区，折叠选区就是光标。
  TextSelection get selection;

  /// 当前输入法组合范围。
  TextRange get composing;

  /// 输入法是否仍有尚未结束的组合会话。
  bool get hasActiveImeComposition;

  /// 已确认的文本长度，不包含当前组合候选。
  int get committedTextLength;

  /// 是否限制为单行输入。
  bool get singleLine;

  /// 后续输入允许的最大长度。
  int? get maxLength;

  /// 输入格式化规则。
  List<TextInputFormatter> get inputFormatters;

  /// 原地更新后续输入规则，保留正文和选区。
  void configure({
    required bool singleLine,
    required int? maxLength,
    List<TextInputFormatter> inputFormatters = const [],
  });

  /// 只读取指定范围的正文。
  String getText(int start, int end);

  /// 逻辑行数，空文本也保留一行。
  int get lineCount;

  /// 读取一行正文，不包含行尾换行符。
  String lineText(int line) {
    final range = lineRange(line);
    return getText(range.start, range.end);
  }

  /// 批量读取可见行，模型可优化为连续存储读取。
  @protected
  List<String> readTextLines(int startLine, {int maxLines = 64, int maxCodeUnits = 65536}) {
    final result = <String>[];
    var remaining = maxCodeUnits;
    for (var line = startLine; line < lineCount && result.length < maxLines; line++) {
      final range = lineRange(line);
      if (range.end - range.start > remaining) break;
      result.add(lineText(line));
      remaining -= range.end - range.start;
    }
    return result;
  }

  /// 返回逻辑行的正文范围，不含换行符。
  TextRange lineRange(int line);

  /// 返回指定偏移所在的逻辑行。
  int lineAtOffset(int offset);

  /// 只在文本改变时通知。
  Listenable get textChanges;

  /// 文本修订号，用于丢弃过期的排版和定位结果。
  int get docRevision;

  /// 请求重新绘制文字，正文和历史保持不变。
  void invalidatePresentation();

  /// 上层文本模型向视图提供本次替换的坐标与行变化。
  @protected
  Iterable<({int start, String removed, String inserted, int firstLine, int removedLines, int insertedLines})>
  get renderEdits;

  /// 上层绘制的选区，首项为主选区；基础输入始终只有一项。
  @protected
  Iterable<TextSelection> get renderSelections => [selection];

  /// 接收视图修正后的选区；上层模型自行决定如何保存附加选区。
  @protected
  void updateRenderSelections(Iterable<TextSelection> selections, {bool keepComposing = false}) =>
      setSelection(selections.first, keepComposing: keepComposing);

  /// 文本、选区或组合范围的即时绘制修订，通知可以延后发布。
  @protected
  int get renderRevision;

  /// 呈现修订号，正文未变化时仍可使行样式失效。
  @protected
  int get presentationRevision;

  /// 是否以字符单元绘制光标。
  @protected
  bool get overwriteCaret => false;

  /// 全选期间保留的光标显示位置。
  @protected
  int? get selectAllCaretDisplayOffset => null;

  /// 平台输入的一批局部替换，坐标基于同一份旧文本。
  @protected
  void updateComposingText(
    Iterable<({int start, int end, String text})> edits, {
    required TextSelection selection,
    required TextRange composing,
  });

  /// 文本输入后是否自动滚动到光标。
  @protected
  bool get revealOnTextChange => true;

  /// 接收自动填充或无障碍输入，并执行当前输入约束。
  @protected
  void applyPlatformValue(TextEditingValue value, {required bool autofill}) => insertText(
    value.text,
    range: TextRange(start: 0, end: length),
    selection: value.selection,
  );

  /// 上层模型原子应用基础输入动作产生的局部替换。
  @protected
  void applyTextEdits(
    Iterable<({int start, int end, String text})> edits, {
    TextSelection? selection,
    bool? forwardDeletion,
  });

  /// 绘制阶段只更新选区，业务通知延后到安全阶段。
  @protected
  bool updateSelectionBeforePaint(VoidCallback update, void Function(VoidCallback) publish);

  /// 替换指定范围，缺省把光标移到插入内容之后。
  void replaceRange(
    int start,
    int end,
    String text, {
    TextSelection? selection,
    TextRange composing = TextRange.empty,
    bool addToHistory = true,
  });

  /// 在当前选区输入文字。
  void insertText(String text, {TextRange? range, TextSelection? selection});

  /// 更新主选区，默认结束当前组合输入。
  void setSelection(TextSelection selection, {bool keepComposing = false});

  /// 选中全部正文。
  void selectAll();

  /// 结束连续输入的撤销分组。
  void closeHistoryRun();

  /// 是否可以撤销。
  bool get canUndo;

  /// 是否可以重做。
  bool get canRedo;

  /// 撤销最近一次编辑。
  bool undoEdit();

  /// 重做最近一次撤销。
  bool redoEdit();

  /// 结束当前输入法组合；取消时恢复组合前的文本。
  bool finishImeComposition({bool commit = true, bool commitUnconfirmedAsPlainText = false});

  /// 当前选中的正文。
  String get selectedText => getText(selection.start, selection.end);

  /// 删除指定范围。
  void deleteRange(int start, int end) => replaceRange(start, end, '');

  /// 把光标移到指定偏移。
  void collapseTo(int offset) => setSelection(TextSelection.collapsed(offset: offset));

  /// 沿视觉方向移动一个字素。
  TextPosition? moveHorizontal(TextPosition position, {required bool left}) =>
      _viewport?.moveHorizontal(position, left: left);

  /// 查询选区的视觉左右端点。
  TextPosition? horizontalSelectionEdge(TextRange range, {required bool left}) =>
      _viewport?.horizontalSelectionEdge(range, left: left);

  /// 查询光标在逻辑行中的横坐标。
  double caretXFor(TextPosition position) => _viewport?.caretXFor(position) ?? 0;

  /// 保留横坐标移动到相邻视觉行。
  TextPosition? moveVertical(TextPosition position, {required bool down, required double xGoal}) =>
      _viewport?.moveVertical(position, down: down, xGoal: xGoal);

  /// 按视口高度移动光标。
  TextPosition pageMove(
    TextPosition position, {
    required bool down,
    required double xGoal,
    required double pageExtent,
  }) => _viewport?.pageMove(position, down: down, xGoal: xGoal, pageExtent: pageExtent) ?? position;

  /// 查询当前视觉行的行首或行尾。
  TextPosition visualLineEdge(TextPosition position, {required bool end}) =>
      _viewport?.visualLineEdge(position, end: end) ?? position;

  /// 查询当前位置的词边界。
  TextRange wordBoundary(TextPosition position) =>
      _viewport?.wordBoundary(position) ?? TextRange.collapsed(position.offset);

  /// 查询全局点在文字行中的横坐标。
  double? textXAtGlobal(Offset point) => _viewport?.textXAtGlobal(point);

  /// 查询矩形选区经过的视觉行，首项对应活动端；不修改选区。
  List<TextSelection> selectionsForBox(
    TextPosition anchor,
    TextPosition active, {
    required double startX,
    required double endX,
    int limit = 10000,
  }) => _viewport?.selectionsForBox(anchor, active, startX: startX, endX: endX, limit: limit) ?? const [];

  EditableViewport? _viewport;
  final ValueNotifier<Rect?> _caretGeometry = ValueNotifier(null);
  bool _viewportDisposed = false;
  bool _geometryPublishScheduled = false;

  /// 是否已有视图挂载。
  bool get hasView => _viewport != null;

  /// 主光标的全局矩形变化，尚未排版时为 null。
  ValueListenable<Rect?> get caretGeometry => _caretGeometry;

  /// 由全局坐标命中文本位置。
  TextPosition positionAtGlobal(Offset position) =>
      _viewport?.positionAtGlobal(position) ?? TextPosition(offset: selection.extentOffset);

  /// 查询指定偏移的视图内光标矩形。
  Rect? rectAtOffset(int offset, {TextAffinity affinity = TextAffinity.downstream}) =>
      _viewport?.rectAtOffset(offset, affinity: affinity);

  /// 查询主光标在视图中的矩形。
  Rect? caretRectInEditor() => _viewport?.caretRectInEditor();

  /// 查询主光标的全局矩形。
  Rect? caretRectGlobal() => _viewport?.caretRectGlobal();

  /// 查询范围内已经排版的文字矩形。
  List<Rect> rectsForRangeInEditor(TextRange range, {bool collapsedAsCharacterCell = false}) =>
      _viewport?.rectsForRangeInEditor(range, collapsedAsCharacterCell: collapsedAsCharacterCell) ?? const [];

  /// 查询范围内已经排版的文字全局矩形。
  List<Rect> rectsForRangeGlobal(TextRange range, {bool collapsedAsCharacterCell = false}) =>
      _viewport?.rectsForRangeGlobal(range, collapsedAsCharacterCell: collapsedAsCharacterCell) ?? const [];

  /// 滚动到主光标，返回是否完成定位。
  Future<bool> revealCaret() => _viewport?.revealCaret() ?? Future.value(false);

  /// 滚动到主光标。
  void ensureCaretVisible() {
    revealCaret();
  }

  @override
  void dispose() {
    _viewportDisposed = true;
    _viewport?.caretGeometry.removeListener(_updateCaretGeometry);
    _viewport = null;
    _caretGeometry.dispose();
    super.dispose();
  }

  void _updateCaretGeometry() {
    if (_viewportDisposed) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_geometryPublishScheduled) return;
      _geometryPublishScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _geometryPublishScheduled = false;
        if (!_viewportDisposed) _caretGeometry.value = _viewport?.caretGeometry.value;
      });
    } else {
      _caretGeometry.value = _viewport?.caretGeometry.value;
    }
  }
}

final class _ViewportController extends ElEditableController {
  _ViewportController(this.source) : super.base() {
    source.addListener(notifyListeners);
  }
  final ElEditableController source;
  @override
  Map<String, WidgetBuilder> get inlineContent => source.inlineContent;
  @override
  set inlineContent(Map<String, WidgetBuilder> value) => source.inlineContent = value;
  @override
  String get text => source.text;
  @override
  set text(String value) => source.text = value;
  @override
  int get length => source.length;
  @override
  TextSelection get selection => source.selection;
  @override
  TextRange get composing => source.composing;
  @override
  bool get singleLine => source.singleLine;
  @override
  int? get maxLength => source.maxLength;
  @override
  List<TextInputFormatter> get inputFormatters => source.inputFormatters;
  @override
  bool get hasActiveImeComposition => source.hasActiveImeComposition;
  @override
  int get committedTextLength => source.committedTextLength;
  @override
  void configure({
    required bool singleLine,
    required int? maxLength,
    List<TextInputFormatter> inputFormatters = const [],
  }) => source.configure(singleLine: singleLine, maxLength: maxLength, inputFormatters: inputFormatters);
  @override
  String getText(int start, int end) => source.getText(start, end);
  @override
  String lineText(int line) => source.lineText(line);
  @override
  List<String> readTextLines(int startLine, {int maxLines = 64, int maxCodeUnits = 65536}) =>
      source.readTextLines(startLine, maxLines: maxLines, maxCodeUnits: maxCodeUnits);
  @override
  int get lineCount => source.lineCount;
  @override
  TextRange lineRange(int line) => source.lineRange(line);
  @override
  int lineAtOffset(int offset) => source.lineAtOffset(offset);
  @override
  Listenable get textChanges => source.textChanges;
  @override
  int get docRevision => source.docRevision;
  @override
  int get renderRevision => source.renderRevision;
  @override
  int get presentationRevision => source.presentationRevision;
  @override
  void updateRenderSelections(Iterable<TextSelection> selections, {bool keepComposing = false}) =>
      source.updateRenderSelections(selections, keepComposing: keepComposing);
  @override
  bool get overwriteCaret => source.overwriteCaret;
  @override
  int? get selectAllCaretDisplayOffset => source.selectAllCaretDisplayOffset;
  @override
  bool get revealOnTextChange => source.revealOnTextChange;
  @override
  Iterable<TextSelection> get renderSelections => source.renderSelections;
  @override
  Iterable<({int start, String removed, String inserted, int firstLine, int removedLines, int insertedLines})>
  get renderEdits => source.renderEdits;
  @override
  void invalidatePresentation() => source.invalidatePresentation();
  @override
  void updateComposingText(
    Iterable<({int start, int end, String text})> edits, {
    required TextSelection selection,
    required TextRange composing,
  }) => source.updateComposingText(edits, selection: selection, composing: composing);
  @override
  void applyPlatformValue(TextEditingValue value, {required bool autofill}) =>
      source.applyPlatformValue(value, autofill: autofill);
  @override
  void applyTextEdits(
    Iterable<({int start, int end, String text})> edits, {
    TextSelection? selection,
    bool? forwardDeletion,
  }) => source.applyTextEdits(edits, selection: selection, forwardDeletion: forwardDeletion);
  @override
  bool updateSelectionBeforePaint(VoidCallback update, void Function(VoidCallback) publish) =>
      source.updateSelectionBeforePaint(update, publish);
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
  void insertText(String text, {TextRange? range, TextSelection? selection}) =>
      source.insertText(text, range: range, selection: selection);
  @override
  void setSelection(TextSelection selection, {bool keepComposing = false}) =>
      source.setSelection(selection, keepComposing: keepComposing);
  @override
  void selectAll() => source.selectAll();
  @override
  void closeHistoryRun() => source.closeHistoryRun();
  @override
  bool get canUndo => source.canUndo;
  @override
  bool get canRedo => source.canRedo;
  @override
  bool undoEdit() => source.undoEdit();
  @override
  bool redoEdit() => source.redoEdit();
  @override
  bool finishImeComposition({bool commit = true, bool commitUnconfirmedAsPlainText = false}) =>
      source.finishImeComposition(commit: commit, commitUnconfirmedAsPlainText: commitUnconfirmedAsPlainText);
  @override
  void dispose() {
    source.removeListener(notifyListeners);
    super.dispose();
  }
}

/// 仅供内核连接控制器与 State，不属于公开入口。
abstract interface class EditableViewport {
  TextPosition? moveHorizontal(TextPosition position, {required bool left});
  TextPosition? horizontalSelectionEdge(TextRange range, {required bool left});
  double caretXFor(TextPosition position);
  TextPosition? moveVertical(TextPosition position, {required bool down, required double xGoal});
  TextPosition pageMove(TextPosition position, {required bool down, required double xGoal, required double pageExtent});
  TextPosition visualLineEdge(TextPosition position, {required bool end});
  TextRange wordBoundary(TextPosition position);
  double? textXAtGlobal(Offset point);
  List<TextSelection> selectionsForBox(
    TextPosition anchor,
    TextPosition active, {
    required double startX,
    required double endX,
    int limit = 10000,
  });
  ValueListenable<Rect?> get caretGeometry;
  TextPosition positionAtGlobal(Offset position);
  Rect? rectAtOffset(int offset, {TextAffinity affinity = TextAffinity.downstream});
  Rect? caretRectInEditor();
  Rect? caretRectGlobal();
  List<Rect> rectsForRangeInEditor(TextRange range, {bool collapsedAsCharacterCell = false});
  List<Rect> rectsForRangeGlobal(TextRange range, {bool collapsedAsCharacterCell = false});
  Future<bool> revealCaret();
}

/// 内核挂载入口，禁止从公共 barrel 导出。
extension EditableControllerBinding on ElEditableController {
  void bindEditableViewport(EditableViewport? viewport) {
    if (identical(_viewport, viewport)) return;
    if (_viewport != null && viewport != null) {
      throw StateError('同一 ElEditableController 只能同时挂载一个 ElEditableView。');
    }
    _viewport?.caretGeometry.removeListener(_updateCaretGeometry);
    _viewport = viewport;
    _viewport?.caretGeometry.addListener(_updateCaretGeometry);
    _updateCaretGeometry();
  }
}
