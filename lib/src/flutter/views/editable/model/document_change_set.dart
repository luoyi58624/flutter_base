import 'edit_transaction.dart';
import 'editable_selection.dart';
import 'text_document.dart';

/// 一次编辑事务应用后的不可变文档与选区变更结果。
final class DocumentChangeSet {
  /// 创建变更结果；[edits] 必须按原文坐标升序排列且替换区间互不重叠。
  factory DocumentChangeSet({
    required int baseRevision,
    required int revision,
    required EditableEditSource source,
    required Iterable<DocumentEdit> edits,
    required EditableSelectionSet selectionsBefore,
    required EditableSelectionSet selectionsAfter,
    bool establishesExternalBaseline = false,
  }) {
    if (baseRevision < 0) {
      throw ArgumentError.value(baseRevision, 'baseRevision', '必须是非负修订号');
    }
    if (revision < baseRevision) {
      throw ArgumentError.value(revision, 'revision', '不能小于 baseRevision');
    }
    final copiedEdits = List<DocumentEdit>.unmodifiable(edits);
    final resultStarts = <int>[];
    var delta = 0;
    var previousStart = -1;
    var previousEnd = -1;
    for (var i = 0; i < copiedEdits.length; i++) {
      final edit = copiedEdits[i];
      if (edit.start < 0) {
        throw ArgumentError.value(edit.start, 'edits[$i].start', '必须是非负 UTF-16 offset');
      }
      if (edit.firstDirtyLine < 0 || edit.removedLineCount < 1 || edit.insertedLineCount < 1) {
        throw ArgumentError.value(edit, 'edits[$i]', '行信息必须非负，且移除与插入行数必须至少为 1');
      }
      if (i > 0 && edit.start < previousStart) {
        throw ArgumentError.value(edit, 'edits[$i]', 'edits 必须按原文 start 升序排列');
      }
      if (i > 0 && edit.start < previousEnd) {
        throw ArgumentError.value(edit, 'edits[$i]', '编辑区间不能与前一项重叠');
      }
      resultStarts.add(edit.start + delta);
      delta += edit.inserted.length - edit.removed.length;
      previousStart = edit.start;
      previousEnd = edit.start + edit.removed.length;
    }
    return DocumentChangeSet._(
      baseRevision: baseRevision,
      revision: revision,
      source: source,
      edits: copiedEdits,
      selectionsBefore: selectionsBefore,
      selectionsAfter: selectionsAfter,
      establishesExternalBaseline: establishesExternalBaseline,
      resultStarts: List<int>.unmodifiable(resultStarts),
    );
  }

  const DocumentChangeSet._({
    required this.baseRevision,
    required this.revision,
    required this.source,
    required this.edits,
    required this.selectionsBefore,
    required this.selectionsAfter,
    required this.establishesExternalBaseline,
    required this._resultStarts,
  });

  /// 应用事务前的文档修订号。
  final int baseRevision;

  /// 应用事务后的文档修订号。
  final int revision;

  /// 产生本次变更的编辑来源。
  final EditableEditSource source;

  /// 按原文坐标升序排列的只读实际编辑列表。
  final List<DocumentEdit> edits;

  /// 应用事务前的选区集合。
  final EditableSelectionSet selectionsBefore;

  /// 应用事务后的选区集合。
  final EditableSelectionSet selectionsAfter;

  /// 本事务是否由 `EditableController.text=` 整体换代外部文本模型。
  ///
  /// 依附旧正文的投影、诊断等派生模型应在收到该信号时清空状态，
  /// 即使同步文本与当前正文相同。局部 `replaceRange(addToHistory: false)`
  /// 仍为 false，因为它不代表整个外部文本模型被替换。
  final bool establishesExternalBaseline;

  final List<int> _resultStarts;

  /// 是否实际包含文档内容编辑。
  bool get documentChanged => edits.isNotEmpty;

  /// 应用前后的选区是否发生变化。
  bool get selectionChanged => selectionsBefore != selectionsAfter;

  /// 返回第 [index] 项编辑在最终文档中的起点。
  int resultStartFor(int index) {
    RangeError.checkValidIndex(index, edits, 'index');
    return _resultStarts[index];
  }

  /// 按修订号、来源、实际编辑与选区判断变更结果是否相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentChangeSet &&
          baseRevision == other.baseRevision &&
          revision == other.revision &&
          source == other.source &&
          _documentEditsEqual(edits, other.edits) &&
          selectionsBefore == other.selectionsBefore &&
          selectionsAfter == other.selectionsAfter &&
          establishesExternalBaseline == other.establishesExternalBaseline;

  /// 返回与值相等语义一致的哈希值。
  @override
  int get hashCode => Object.hash(
    baseRevision,
    revision,
    source,
    Object.hashAll(edits.map(_documentEditHash)),
    selectionsBefore,
    selectionsAfter,
    establishesExternalBaseline,
  );
}

bool _documentEditsEqual(List<DocumentEdit> a, List<DocumentEdit> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final left = a[i];
    final right = b[i];
    if (left.start != right.start ||
        left.removed != right.removed ||
        left.inserted != right.inserted ||
        left.firstDirtyLine != right.firstDirtyLine ||
        left.removedLineCount != right.removedLineCount ||
        left.insertedLineCount != right.insertedLineCount) {
      return false;
    }
  }
  return true;
}

int _documentEditHash(DocumentEdit edit) => Object.hash(
  edit.start,
  edit.removed,
  edit.inserted,
  edit.firstDirtyLine,
  edit.removedLineCount,
  edit.insertedLineCount,
);
