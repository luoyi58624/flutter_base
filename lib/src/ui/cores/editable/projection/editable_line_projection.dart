import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextAffinity, TextPosition, TextRange;

import '../editable_controller.dart';
import 'editable_hidden_areas_model.dart';

/// 隐藏位置向可见边界投影时使用的方向偏好。
@internal
enum EditablePositionProjectionBias {
  /// 优先投影到前一可见逻辑行的行尾。
  backward,

  /// 优先投影到后一可见逻辑行的行首。
  forward,

  /// 选择 UTF-16 距离更近的边界，距离相同时选择前一边界。
  nearest,
}

/// Editable 内部唯一的模型行、可见行与隐藏位置投影门面。
///
/// 该门面只读取 [controller] 与 [hiddenAreas]，绝不修改正文、选区或历史。
@internal
final class EditableLineProjection extends ChangeNotifier {
  /// 创建行投影，并同步监听文档与可选隐藏区域模型。
  EditableLineProjection({required this.controller, this.hiddenAreas})
    : _seenDocumentRevision = controller.docRevision,
      _lastHiddenAreas = List<EditableHiddenArea>.unmodifiable(hiddenAreas?.hiddenAreas ?? const []) {
    final hidden = hiddenAreas;
    if (hidden != null && !identical(hidden.controller, controller)) {
      throw FlutterError('EditableLineProjection 的 controller 与 EditableLineMask.controller 必须是同一实例。');
    }
    hidden?.addListener(_handleHiddenChange);
    controller.docChanges.addListener(_handleDocumentChange);
  }

  /// 投影绑定的编辑控制器。
  final EditableController controller;

  /// 可选的整行隐藏模型；null 表示恒等投影。
  final EditableLineMask? hiddenAreas;

  int _seenDocumentRevision;
  int _revision = 0;
  int _mappingRevision = 0;
  List<EditableHiddenArea> _lastHiddenAreas;
  int _debugLastLookupProbeCount = 0;
  bool _disposed = false;

  /// 投影语义每次实际失效时递增的修订号。
  int get revision => _revision;

  /// 合并后的可见行映射每次真正变化时递增；普通正文几何修订不会递增。
  int get mappingRevision => _mappingRevision;

  /// 最近一次门面自有隐藏区间查询执行的二分比较与候选检查次数。
  ///
  /// 双向行映射直接委托给 [EditableLineMask]，该快路不重复计数。
  @visibleForTesting
  int get debugLastLookupProbeCount => _debugLastLookupProbeCount;

  bool get _identity => hiddenAreas == null || hiddenAreas!.isEmpty;

  /// 当前可见逻辑行总数，始终至少为一。
  int get visibleLineCount {
    _checkAlive();
    return _identity ? controller.document.lineCount : hiddenAreas!.visibleLineCount;
  }

  /// 把可见视图行映射为原文模型行。
  int modelLineForViewRow(int viewRow) {
    _checkAlive();
    final count = visibleLineCount;
    if (viewRow < 0 || viewRow >= count) {
      throw RangeError.range(viewRow, 0, count - 1, 'viewRow');
    }
    if (_identity) {
      _debugLastLookupProbeCount = 0;
      return viewRow;
    }
    final hidden = hiddenAreas!;
    final result = hidden.modelLineForViewRow(viewRow);
    _debugLastLookupProbeCount = 0;
    return result;
  }

  /// 把原文模型行映射为可见视图行；隐藏行返回 null。
  int? viewRowForModelLine(int modelLine) {
    _checkAlive();
    _checkModelLine(modelLine);
    if (_identity) {
      _debugLastLookupProbeCount = 0;
      return modelLine;
    }
    final hidden = hiddenAreas!;
    final result = hidden.viewRowForModelLine(modelLine);
    _debugLastLookupProbeCount = 0;
    return result;
  }

  /// 判断有效 [modelLine] 当前是否参与视图投影。
  bool isVisibleModelLine(int modelLine) => viewRowForModelLine(modelLine) != null;

  /// 返回第一条可见模型行。
  int get firstVisibleModelLine => modelLineForViewRow(0);

  /// 返回最后一条可见模型行。
  int get lastVisibleModelLine => modelLineForViewRow(visibleLineCount - 1);

  /// 返回 [modelLine] 前方或后方严格相邻的可见模型行，无可见邻居时返回 null。
  ///
  /// [forward] 为 true 时向文档尾查找，否则向文档首查找；隐藏输入会直接越过
  /// 所属合并隐藏区间，整体复杂度保持 O(log H)。
  int? adjacentVisibleModelLine(int modelLine, {required bool forward}) {
    _checkAlive();
    _checkModelLine(modelLine);
    final lineCount = controller.document.lineCount;
    if (_identity) {
      _debugLastLookupProbeCount = 0;
      final result = modelLine + (forward ? 1 : -1);
      return result < 0 || result >= lineCount ? null : result;
    }

    final area = _hiddenAreaContaining(modelLine);
    final probes = _debugLastLookupProbeCount;
    if (area != null) {
      final result = forward ? area.endLine + 1 : area.startLine - 1;
      _debugLastLookupProbeCount = probes;
      return result < 0 || result >= lineCount ? null : result;
    }

    final hidden = hiddenAreas!;
    final viewRow = hidden.viewRowForModelLine(modelLine)!;
    final adjacentRow = viewRow + (forward ? 1 : -1);
    if (adjacentRow < 0 || adjacentRow >= hidden.visibleLineCount) {
      _debugLastLookupProbeCount = probes;
      return null;
    }
    final result = hidden.modelLineForViewRow(adjacentRow);
    _debugLastLookupProbeCount = probes;
    return result;
  }

  /// 把隐藏位置投影到可见边界；可见位置原样返回。
  ///
  /// 前一边界使用 upstream affinity 锁定前一行行尾，后一边界使用 downstream
  /// affinity 锁定后一行行首。[bias] 为 nearest 时按 UTF-16 距离选择并在平局时
  /// 选择前一边界。
  TextPosition projectCollapsedPosition(TextPosition position, {EditablePositionProjectionBias bias = .nearest}) {
    _checkAlive();
    _checkOffset(position.offset, 'position.offset');
    if (_identity) {
      _debugLastLookupProbeCount = 0;
      return position;
    }
    final line = controller.document.lineIndexOf(position.offset);
    final area = _hiddenAreaContaining(line);
    if (area == null) return position;

    final document = controller.document;
    final hasBackward = area.startLine > 0;
    final hasForward = area.endLine < document.lineCount - 1;
    if (!hasBackward) return _forwardBoundary(area);
    if (!hasForward) return _backwardBoundary(area);
    switch (bias) {
      case .backward:
        return _backwardBoundary(area);
      case .forward:
        return _forwardBoundary(area);
      case .nearest:
        final backward = _backwardBoundary(area);
        final forward = _forwardBoundary(area);
        final backwardDistance = position.offset - backward.offset;
        final forwardDistance = forward.offset - position.offset;
        return backwardDistance <= forwardDistance ? backward : forward;
    }
  }

  /// 按选区端点相对 [oppositeEndpoint] 的方向投影几何位置。
  ///
  /// 逻辑选区保持不变：较早端点向前一边界投影，较晚端点向后一边界投影，
  /// 折叠端点使用 nearest 规则。
  TextPosition projectSelectionEndpointForGeometry(TextPosition endpoint, {required TextPosition oppositeEndpoint}) {
    _checkAlive();
    _checkOffset(endpoint.offset, 'endpoint.offset');
    _checkOffset(oppositeEndpoint.offset, 'oppositeEndpoint.offset');
    final bias = endpoint.offset < oppositeEndpoint.offset
        ? EditablePositionProjectionBias.backward
        : endpoint.offset > oppositeEndpoint.offset
        ? EditablePositionProjectionBias.forward
        : EditablePositionProjectionBias.nearest;
    return projectCollapsedPosition(endpoint, bias: bias);
  }

  /// 把 upstream 的隐藏间隙后可见行首统一归一到前一可见行尾。
  ///
  /// 普通相邻逻辑行不改写，只有两条可见行之间确实隔着隐藏区时才归一。
  TextPosition canonicalizeVisibleCaretPosition(TextPosition position) {
    _checkAlive();
    _checkOffset(position.offset, 'position.offset');
    final document = controller.document;
    final line = document.lineIndexOf(position.offset);
    if (position.affinity != TextAffinity.upstream || line <= 0 || position.offset != document.lineStart(line)) {
      return position;
    }
    final previous = adjacentVisibleModelLine(line, forward: false);
    return previous == null || previous == line - 1
        ? position
        : TextPosition(offset: document.lineEnd(previous), affinity: TextAffinity.upstream);
  }

  /// 判断半开 [range] 是否至少覆盖一个属于可见逻辑行的 UTF-16 code unit。
  bool rangeHasVisibleContent(TextRange range) {
    _checkAlive();
    _checkRange(range);
    if (range.isCollapsed) {
      _debugLastLookupProbeCount = 0;
      return false;
    }
    if (_identity) {
      _debugLastLookupProbeCount = 0;
      return true;
    }

    final document = controller.document;
    final firstTouchedLine = document.lineIndexOf(range.start);
    final lastTouchedLine = document.lineIndexOf(range.end - 1);
    final area = _hiddenAreaContaining(firstTouchedLine);
    if (area == null) return true;
    return area.endLine + 1 <= lastTouchedLine;
  }

  /// 判断半开 [range] 是否至少覆盖一个属于隐藏逻辑行的 UTF-16 code unit。
  bool rangeIntersectsHiddenContent(TextRange range) {
    _checkAlive();
    _checkRange(range);
    if (range.isCollapsed || _identity) {
      _debugLastLookupProbeCount = 0;
      return false;
    }
    final document = controller.document;
    final firstTouchedLine = document.lineIndexOf(range.start);
    final lastTouchedLine = document.lineIndexOf(range.end - 1);
    final areas = hiddenAreas!.hiddenAreas;
    var probes = 0;
    var low = 0;
    var high = areas.length;
    while (low < high) {
      probes++;
      final middle = low + ((high - low) >> 1);
      if (areas[middle].endLine < firstTouchedLine) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    _debugLastLookupProbeCount = probes + (low < areas.length ? 1 : 0);
    return low < areas.length && areas[low].startLine <= lastTouchedLine;
  }

  /// 生成只覆盖可见正文及两侧有限上下文的有序扫描窗。
  ///
  /// [contextCodeUnits] 用于保留跨隐藏边界、但至少含一个可见 code unit 的
  /// 匹配；相交扩展窗会合并，窗口数量保持 O(H)。
  Iterable<TextRange> visibleDocumentScanRanges({required int contextCodeUnits}) sync* {
    _checkAlive();
    if (contextCodeUnits < 0) throw ArgumentError.value(contextCodeUnits, 'contextCodeUnits', '必须非负');
    final document = controller.document;
    if (_identity) {
      if (document.length > 0) yield TextRange(start: 0, end: document.length);
      return;
    }

    TextRange? pending;
    for (final visible in _visibleDocumentRanges()) {
      final expanded = TextRange(
        start: math.max(0, visible.start - contextCodeUnits),
        end: math.min(document.length, visible.end + contextCodeUnits),
      );
      final current = pending;
      if (current == null) {
        pending = expanded;
      } else if (expanded.start <= current.end) {
        pending = TextRange(start: current.start, end: math.max(current.end, expanded.end));
      } else {
        yield current;
        pending = expanded;
      }
    }
    final tail = pending;
    if (tail != null) yield tail;
  }

  Iterable<TextRange> _visibleDocumentRanges() sync* {
    final document = controller.document;
    var visibleStart = 0;
    for (final area in hiddenAreas!.hiddenAreas) {
      final hiddenStart = document.lineStart(area.startLine);
      final hiddenEnd = area.endLine == document.lineCount - 1 ? document.length : document.lineStart(area.endLine + 1);
      if (visibleStart < hiddenStart) yield TextRange(start: visibleStart, end: hiddenStart);
      visibleStart = hiddenEnd;
    }
    if (visibleStart < document.length) yield TextRange(start: visibleStart, end: document.length);
  }

  TextPosition _backwardBoundary(EditableHiddenArea area) =>
      TextPosition(offset: controller.document.lineEnd(area.startLine - 1), affinity: TextAffinity.upstream);

  TextPosition _forwardBoundary(EditableHiddenArea area) =>
      TextPosition(offset: controller.document.lineStart(area.endLine + 1), affinity: TextAffinity.downstream);

  EditableHiddenArea? _hiddenAreaContaining(int modelLine) {
    final areas = hiddenAreas!.hiddenAreas;
    var probes = 0;
    var low = 0;
    var high = areas.length;
    while (low < high) {
      probes++;
      final middle = low + ((high - low) >> 1);
      if (areas[middle].startLine <= modelLine) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final previous = low - 1;
    if (previous < 0) {
      _debugLastLookupProbeCount = probes;
      return null;
    }
    probes++;
    final area = areas[previous];
    _debugLastLookupProbeCount = probes;
    return modelLine <= area.endLine ? area : null;
  }

  void _handleHiddenChange() {
    if (_disposed) return;
    final current = hiddenAreas?.hiddenAreas ?? const <EditableHiddenArea>[];
    if (!listEquals(_lastHiddenAreas, current)) {
      _lastHiddenAreas = List<EditableHiddenArea>.unmodifiable(current);
      _mappingRevision++;
    }
    _seenDocumentRevision = controller.docRevision;
    _revision++;
    notifyListeners();
  }

  void _handleDocumentChange() {
    if (_disposed || _seenDocumentRevision == controller.docRevision) return;
    _seenDocumentRevision = controller.docRevision;
    _revision++;
    notifyListeners();
  }

  void _checkModelLine(int modelLine) {
    final count = controller.document.lineCount;
    if (modelLine < 0 || modelLine >= count) {
      throw RangeError.range(modelLine, 0, count - 1, 'modelLine');
    }
  }

  void _checkOffset(int offset, String name) {
    final length = controller.document.length;
    if (offset < 0 || offset > length) throw RangeError.range(offset, 0, length, name);
  }

  void _checkRange(TextRange range) {
    if (!range.isValid || range.start > range.end) {
      throw ArgumentError.value(range, 'range', '必须是有效的正向半开文本范围');
    }
    _checkOffset(range.start, 'range.start');
    _checkOffset(range.end, 'range.end');
  }

  void _checkAlive() {
    if (_disposed) throw StateError('EditableLineProjection 已释放');
  }

  /// 停止监听文档与隐藏区域变化；重复调用安全。
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    hiddenAreas?.removeListener(_handleHiddenChange);
    controller.docChanges.removeListener(_handleDocumentChange);
    super.dispose();
  }
}
