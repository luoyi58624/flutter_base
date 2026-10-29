import 'dart:collection';

import 'edit_transaction.dart';
import 'editable_selection.dart';

/// 历史条目的连续合并语义；编辑来源仍独立用于诊断与跨来源隔离。
enum EditHistoryMergeKind {
  /// 兼容通用事务：按替换形态与坐标自动判断，删除沿用左删语义。
  automatic,

  /// 连续文本输入；允许首次覆盖选区后继续在结果末尾插入。
  typing,

  /// 向光标左侧连续删除，后续区间必须紧邻当前累计区间左边。
  deleteLeft,

  /// 向光标右侧连续删除，后续区间必须保持相同结果起点。
  deleteRight,

  /// 离散命令，永不与前后条目自动合并。
  none,
}

/// 历史中的一笔文本替换，坐标始终属于事务执行前的文档。
class EditHistoryChange {
  /// 创建一笔可逆文本替换。
  EditHistoryChange({required this.start, required this.removed, required this.inserted});

  /// 替换起点（事务执行前的 doc offset）。
  int start;

  /// 被替换的原文。
  String removed;

  /// 替换后的新文。
  String inserted;

  /// 文本长度净变化。
  int get delta => inserted.length - removed.length;
}

/// 一条可撤销的原子编辑事务，包含全部替换与编辑前后的多选区快照。
class EditHistoryEntry {
  /// 创建历史事务；[changes] 必须按原文坐标升序且互不重叠。
  EditHistoryEntry({
    required Iterable<EditHistoryChange> changes,
    required this.selectionsBefore,
    required this.selectionsAfter,
    required this.source,
    this.mergeKind = EditHistoryMergeKind.automatic,
  }) : changes = List<EditHistoryChange>.of(changes);

  /// 事务内的全部替换（原文坐标升序）。
  final List<EditHistoryChange> changes;

  /// 编辑前的完整选区集合。
  final EditableSelectionSet selectionsBefore;

  /// 编辑后的完整选区集合；连续输入合并时会更新。
  EditableSelectionSet selectionsAfter;

  /// 编辑前的正文替代版本号，undo 时恢复。

  /// 编辑后的正文替代版本号，redo 与连续输入合并时更新。

  /// 产生本历史条目的编辑来源；不同来源永不自动合并。
  final EditableEditSource source;

  /// 本条目的连续合并语义；不同语义永不自动合并。
  final EditHistoryMergeKind mergeKind;

  /// 只读的替换视图，供诊断与测试使用。
  UnmodifiableListView<EditHistoryChange> get readOnlyChanges => UnmodifiableListView(changes);

  /// 本条目直接持有的文本 code unit 数（移除原文 + 插入新文）。
  int get retainedCodeUnits =>
      changes.fold<int>(0, (total, change) => total + change.removed.length + change.inserted.length);
}

/// undo/redo 栈，支持原子批量事务与连续单光标输入合并。
///
/// 批量事务永远作为一个撤销单元；连续正向输入和退格在两端拥有同构替换数时
/// 可逐光标合并，坐标换算以事务前后累计 delta 为准。
class EditHistory {
  /// 创建历史栈。
  EditHistory({this.capacity = 1000, this.maxCodeUnits = 16 * 1024 * 1024, this.maxMergeCodeUnits = 4096})
    : assert(capacity >= 0, 'capacity 必须非负'),
      assert(maxCodeUnits >= 0, 'maxCodeUnits 必须非负'),
      assert(maxMergeCodeUnits > 0, 'maxMergeCodeUnits 必须大于 0');

  /// undo 栈最大深度，超出丢弃最旧条目。
  final int capacity;

  /// undo + redo 直接持有的文本预算；单笔事务本身超过预算时仍保留最新一笔，
  /// 避免一次大编辑在完成后立刻变成不可撤销。
  final int maxCodeUnits;

  /// 单个连续输入合并段中，每个 caret 最多累计的文本长度。
  ///
  /// 达到上限后自动新开历史条目，把字符串反复拼接的成本限制为常数窗口，
  /// 避免超长连续输入/退格出现 O(n²) 拷贝。
  final int maxMergeCodeUnits;

  final List<EditHistoryEntry> _undo = [];
  final List<EditHistoryEntry> _redo = [];
  bool _runOpen = false;
  int _retainedCodeUnits = 0;

  /// 当前是否可以撤销。
  bool get canUndo => _undo.isNotEmpty;

  /// 当前是否可以重做。
  bool get canRedo => _redo.isNotEmpty;

  /// 当前 undo 条目数（诊断与预算 UI 使用）。
  int get undoDepth => _undo.length;

  /// 当前 redo 条目数（诊断与预算 UI 使用）。
  int get redoDepth => _redo.length;

  /// undo + redo 当前直接持有的文本 code unit 数。
  int get retainedCodeUnits => _retainedCodeUnits;

  /// 结束当前输入合并段：下一条编辑必然新开条目。
  void closeRun() => _runOpen = false;

  /// 清空全部历史（如外部整体 setText 时）。
  void clear() {
    _undo.clear();
    _redo.clear();
    _runOpen = false;
    _retainedCodeUnits = 0;
  }

  /// 记录一条事务；任何新事务都会使 redo 栈失效。
  void push(EditHistoryEntry entry) {
    if (entry.changes.isEmpty) return;
    _discardRedo();
    final last = _undo.isEmpty ? null : _undo.last;
    if (_runOpen && last != null) {
      final before = last.retainedCodeUnits;
      if (_tryMerge(last, entry, maxMergeCodeUnits: maxMergeCodeUnits)) {
        _retainedCodeUnits += last.retainedCodeUnits - before;
        _enforceLimits();
        return;
      }
    }
    _undo.add(entry);
    _retainedCodeUnits += entry.retainedCodeUnits;
    _enforceLimits();
    _runOpen = _undo.isNotEmpty && identical(_undo.last, entry) && _mergeable(entry);
  }

  void _discardRedo() {
    for (final entry in _redo) {
      _retainedCodeUnits -= entry.retainedCodeUnits;
    }
    _redo.clear();
  }

  void _enforceLimits() {
    while (_undo.length > capacity) {
      _retainedCodeUnits -= _undo.removeAt(0).retainedCodeUnits;
    }
    if (maxCodeUnits == 0) {
      while (_undo.isNotEmpty) {
        _retainedCodeUnits -= _undo.removeAt(0).retainedCodeUnits;
      }
      _runOpen = false;
      return;
    }
    while (_retainedCodeUnits > maxCodeUnits && _undo.length > 1) {
      _retainedCodeUnits -= _undo.removeAt(0).retainedCodeUnits;
    }
    if (_undo.isEmpty) _runOpen = false;
  }

  /// 弹出待撤销事务并移入 redo 栈。
  EditHistoryEntry? undo() {
    if (_undo.isEmpty) return null;
    _runOpen = false;
    final entry = _undo.removeLast();
    _redo.add(entry);
    return entry;
  }

  /// 弹出待重做事务并移回 undo 栈。
  EditHistoryEntry? redo() {
    if (_redo.isEmpty) return null;
    final entry = _redo.removeLast();
    _undo.add(entry);
    return entry;
  }

  static bool _mergeable(EditHistoryEntry entry) {
    if (entry.changes.isEmpty || entry.selectionsBefore.length != entry.selectionsAfter.length) return false;
    return switch (entry.mergeKind) {
      EditHistoryMergeKind.none => false,
      EditHistoryMergeKind.typing => entry.changes.every((change) {
        final kind = _runKind(change);
        return kind == _EditRunKind.insertion || kind == _EditRunKind.replacement;
      }),
      EditHistoryMergeKind.deleteLeft ||
      EditHistoryMergeKind.deleteRight => entry.changes.every((change) => _runKind(change) == _EditRunKind.deletion),
      EditHistoryMergeKind.automatic => entry.changes.every((change) => _runKind(change) != null),
    };
  }

  static bool _tryMerge(EditHistoryEntry last, EditHistoryEntry next, {required int maxMergeCodeUnits}) {
    if (!_mergeable(last) ||
        !_mergeable(next) ||
        last.changes.length != next.changes.length ||
        last.source != next.source ||
        last.mergeKind != next.mergeKind) {
      return false;
    }

    var delta = 0;
    final kinds = <_EditRunKind>[];
    final mappedDeleteStarts = <int?>[];
    for (var i = 0; i < last.changes.length; i++) {
      final previous = last.changes[i];
      final following = next.changes[i];
      final kind = _runKind(previous);
      final followingKind = _runKind(following);
      if (kind == null || followingKind == null) return false;
      if (previous.inserted.length + following.inserted.length > maxMergeCodeUnits ||
          previous.removed.length + following.removed.length > maxMergeCodeUnits) {
        return false;
      }
      final previousResultStart = previous.start + delta;
      switch (last.mergeKind) {
        case EditHistoryMergeKind.none:
          return false;
        case EditHistoryMergeKind.typing:
          final previousTyping = kind == _EditRunKind.insertion || kind == _EditRunKind.replacement;
          final followingTyping = followingKind == _EditRunKind.insertion || followingKind == _EditRunKind.replacement;
          if (!previousTyping || !followingTyping) return false;
          if (following.start != previousResultStart + previous.inserted.length) return false;
          mappedDeleteStarts.add(null);
        case EditHistoryMergeKind.deleteLeft:
          if (kind != _EditRunKind.deletion || followingKind != _EditRunKind.deletion) return false;
          if (following.start + following.removed.length != previousResultStart) return false;
          mappedDeleteStarts.add(following.start - delta);
        case EditHistoryMergeKind.deleteRight:
          if (kind != _EditRunKind.deletion || followingKind != _EditRunKind.deletion) return false;
          if (following.start != previousResultStart) return false;
          mappedDeleteStarts.add(null);
        case EditHistoryMergeKind.automatic:
          if (kind != followingKind) return false;
          switch (kind) {
            case _EditRunKind.insertion || _EditRunKind.replacement:
              if (following.start != previousResultStart + previous.inserted.length) return false;
              mappedDeleteStarts.add(null);
            case _EditRunKind.deletion:
              if (following.start + following.removed.length != previousResultStart) return false;
              mappedDeleteStarts.add(following.start - delta);
          }
      }
      kinds.add(kind);
      delta += previous.delta;
    }

    for (var i = 0; i < last.changes.length; i++) {
      final previous = last.changes[i];
      final following = next.changes[i];
      switch (last.mergeKind) {
        case EditHistoryMergeKind.none:
          return false;
        case EditHistoryMergeKind.typing:
          previous
            ..removed += following.removed
            ..inserted += following.inserted;
        case EditHistoryMergeKind.deleteLeft:
          previous
            ..start = mappedDeleteStarts[i]!
            ..removed = following.removed + previous.removed;
        case EditHistoryMergeKind.deleteRight:
          previous.removed += following.removed;
        case EditHistoryMergeKind.automatic:
          switch (kinds[i]) {
            case _EditRunKind.insertion:
              previous.inserted += following.inserted;
            case _EditRunKind.deletion:
              previous
                ..start = mappedDeleteStarts[i]!
                ..removed = following.removed + previous.removed;
            case _EditRunKind.replacement:
              previous
                ..removed += following.removed
                ..inserted += following.inserted;
          }
      }
    }
    last.selectionsAfter = next.selectionsAfter;
    return true;
  }

  static _EditRunKind? _runKind(EditHistoryChange change) {
    if (change.removed.contains('\n') || change.inserted.contains('\n')) return null;
    if (change.removed.isEmpty && change.inserted.isNotEmpty) return _EditRunKind.insertion;
    if (change.inserted.isEmpty && change.removed.isNotEmpty) return _EditRunKind.deletion;
    if (change.removed.isNotEmpty && change.inserted.isNotEmpty) return _EditRunKind.replacement;
    return null;
  }
}

enum _EditRunKind { insertion, deletion, replacement }
