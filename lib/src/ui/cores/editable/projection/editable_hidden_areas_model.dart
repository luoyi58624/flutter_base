import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextRange;
import '../editable_controller.dart';

/// 以零基逻辑行号描述一个整行隐藏区间，起止行均包含在内。
@immutable
final class EditableHiddenArea {
  /// 创建一个整逻辑行隐藏区间；范围在写入模型时统一严格校验。
  const EditableHiddenArea({required this.startLine, required this.endLine});

  /// 第一个隐藏逻辑行，包含该行。
  final int startLine;

  /// 最后一个隐藏逻辑行，包含该行。
  final int endLine;

  /// 区间包含的逻辑行数；非法反向区间会返回非正数并在写入模型时被拒绝。
  int get lineCount => endLine - startLine + 1;

  /// 按两个逻辑行端点判断值是否相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EditableHiddenArea && startLine == other.startLine && endLine == other.endLine;

  /// 返回与值相等语义一致的哈希值。
  @override
  int get hashCode => Object.hash(startLine, endLine);

  /// 返回便于诊断的闭逻辑行区间。
  @override
  String toString() => 'EditableHiddenArea([$startLine, $endLine])';
}

/// 只投影上层已经计算好的隐藏行，不维护折叠来源、标记或撤销。
final class EditableLineMask extends ChangeNotifier {
  EditableLineMask(this.controller) {
    controller.docChanges.addListener(_refresh);
  }
  final EditableController controller;
  List<TextRange> _ranges = const [];
  List<EditableHiddenArea> _hiddenAreas = const [];
  List<_ProjectionEntry> _projection = const [];
  int _hiddenLineCount = 0;
  int _debugLastProjectionProbeCount = 0;
  List<EditableHiddenArea> get hiddenAreas => _hiddenAreas;
  int get hiddenLineCount => _hiddenLineCount;
  int get visibleLineCount => controller.document.lineCount - _hiddenLineCount;
  bool get isEmpty => _hiddenAreas.isEmpty;
  int get debugLastProjectionProbeCount => _debugLastProjectionProbeCount;

  void update(List<TextRange> ranges) {
    for (final range in ranges) {
      if (!range.isValid || range.end <= range.start) throw ArgumentError.value(range, 'hiddenLines');
    }
    _ranges = List.unmodifiable(ranges);
    _refresh();
  }

  void _refresh() {
    final lineCount = controller.document.lineCount;
    final sorted = <EditableHiddenArea>[
      for (final range in _ranges)
        if (range.start < lineCount)
          EditableHiddenArea(startLine: range.start, endLine: math.min(range.end, lineCount) - 1),
    ]..sort((a, b) => a.startLine.compareTo(b.startLine));
    final merged = <EditableHiddenArea>[];
    for (final area in sorted) {
      if (merged.isNotEmpty && area.startLine <= merged.last.endLine + 1) {
        merged[merged.length - 1] = EditableHiddenArea(
          startLine: merged.last.startLine,
          endLine: math.max(area.endLine, merged.last.endLine),
        );
      } else {
        merged.add(area);
      }
    }
    // 上层映射正在更新时保持至少一行，避免短暂的全隐藏破坏输入布局。
    if (merged.fold<int>(0, (count, area) => count + area.lineCount) == lineCount) merged.clear();
    if (listEquals(merged, _hiddenAreas)) return;
    _rebuildProjection(merged);
    notifyListeners();
  }

  /// 把可见视图行 [viewRow] 以对数复杂度映射为原文逻辑行。
  int modelLineForViewRow(int viewRow) {
    if (viewRow < 0 || viewRow >= visibleLineCount) {
      throw RangeError.range(viewRow, 0, visibleLineCount - 1, 'viewRow');
    }
    var probes = 0;
    var low = 0;
    var high = _projection.length;
    while (low < high) {
      probes++;
      final middle = low + ((high - low) >> 1);
      if (_projection[middle].viewBoundary <= viewRow) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final previous = low - 1;
    _debugLastProjectionProbeCount = probes;
    return viewRow + (previous < 0 ? 0 : _projection[previous].cumulativeHiddenCount);
  }

  /// 把原文逻辑行 [modelLine] 以对数复杂度映射为可见视图行。
  ///
  /// [modelLine] 位于任一隐藏区间时返回 null。
  int? viewRowForModelLine(int modelLine) {
    final lineCount = controller.document.lineCount;
    if (modelLine < 0 || modelLine >= lineCount) {
      throw RangeError.range(modelLine, 0, lineCount - 1, 'modelLine');
    }
    var probes = 0;
    var low = 0;
    var high = _projection.length;
    while (low < high) {
      probes++;
      final middle = low + ((high - low) >> 1);
      if (_projection[middle].area.startLine <= modelLine) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final previous = low - 1;
    if (previous < 0) {
      _debugLastProjectionProbeCount = probes;
      return modelLine;
    }
    probes++;
    final entry = _projection[previous];
    _debugLastProjectionProbeCount = probes;
    if (modelLine <= entry.area.endLine) return null;
    return modelLine - entry.cumulativeHiddenCount;
  }

  void _rebuildProjection(List<EditableHiddenArea> areas) {
    var cumulative = 0;
    final entries = <_ProjectionEntry>[];
    for (final area in areas) {
      final hiddenBefore = cumulative;
      cumulative += area.lineCount;
      entries.add(
        _ProjectionEntry(area: area, cumulativeHiddenCount: cumulative, viewBoundary: area.startLine - hiddenBefore),
      );
    }
    _hiddenAreas = List<EditableHiddenArea>.unmodifiable(areas);
    _projection = List<_ProjectionEntry>.unmodifiable(entries);
    _hiddenLineCount = cumulative;
  }

  @override
  void dispose() {
    controller.docChanges.removeListener(_refresh);
    super.dispose();
  }
}

final class _ProjectionEntry {
  const _ProjectionEntry({required this.area, required this.cumulativeHiddenCount, required this.viewBoundary});

  final EditableHiddenArea area;
  final int cumulativeHiddenCount;
  final int viewBoundary;
}
