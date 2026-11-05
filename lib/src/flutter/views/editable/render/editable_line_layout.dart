import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

const int _visualOuterLro = 0x202d;
const int _visualFragmentLro = 0x202d;
const int _visualFragmentRlo = 0x202e;
const int _visualPdf = 0x202c;
const int _visualLri = 0x2066;
const int _visualPdi = 0x2069;

/// 一段已经解析方向、等待拼入最终视觉窗口的真实行正文。
///
/// [lineStart] / [lineEnd] 是原文逻辑行内的 UTF-16 半开区间；[text]
/// 必须与该区间等长；合法代理对不得被调用方拆到不同片段，原文中既有的
/// 孤立 surrogate 则按单个 UTF-16 offset 原样保留。[resolvedLevel] 只取最终
/// 奇偶方向，更高层级的全局重排必须在构造 visual window 前完成。
@immutable
final class EditableLineVisualFragment {
  /// 创建一段最终视觉顺序中的真实正文描述。
  const EditableLineVisualFragment({
    required this.lineStart,
    required this.lineEnd,
    required this.text,
    required this.resolvedLevel,
    required this.logicalTabPrefix,
  });

  /// 片段在原文逻辑行内的 UTF-16 起点。
  final int lineStart;

  /// 片段在原文逻辑行内的 UTF-16 终点，不包含该位置。
  final int lineEnd;

  /// 片段真实正文，不含任何合成方向控制符。
  final String text;

  /// UAX #9 解析后的 embedding level；奇数 RTL，偶数 LTR。
  final int resolvedLevel;

  /// 原文 offset 0 到片段起点的逻辑 tab advance。
  final double logicalTabPrefix;

  /// 片段真实正文的 UTF-16 长度。
  int get length => lineEnd - lineStart;

  /// 片段最终方向是否为 RTL。
  bool get isRtl => resolvedLevel.isOdd;
}

/// 超长逻辑行的一段有界排版窗口。
///
/// [textStart] / [textEnd] 与所有公开 offset 都属于逻辑行坐标；只有送进
/// [TextPainter] 时才通过本对象换算成窗口 Paragraph 的局部坐标。
final class EditableLineLayoutWindow {
  /// visual synthetic Paragraph 的默认 UTF-16 硬上限。
  static const int defaultVisualParagraphCodeUnitLimit = 64 * 1024;

  /// 创建一段不超过渲染预算的逻辑行窗口。
  EditableLineLayoutWindow({
    required this.lineLength,
    required this.textStart,
    required this.text,
    required this.originX,
    required this.estimatedTextWidth,
    required this.averageAdvance,
    required this.textDirection,
    double? tabInitialAdvance,
    int? shapingCoreStart,
    int? shapingCoreEnd,
    this.placeholder = false,
    this.visualGeneration = 0,
  }) : visualFragments = const <EditableLineVisualFragment>[],
       fragmentContentRanges = const <TextRange>[],
       totalContentCodeUnits = text.length,
       totalParagraphCodeUnits = placeholder ? 1 : text.length,
       visualMetricRevision = 0,
       visualFirstTile = -1,
       visualEndTile = -1,
       visualTileCount = 0,
       zeroWidthLogicalRanges = const <TextRange>[],
       _visualMappings = const <_EditableLineVisualMapping>[],
       _logicalMappings = const <_EditableLineVisualMapping>[],
       _visualParagraphText = null,
       _visualTextEnd = null,
       shapingCoreStart = shapingCoreStart ?? textStart,
       shapingCoreEnd = shapingCoreEnd ?? textStart + text.length,
       assert(lineLength >= 0),
       assert(textStart >= 0),
       assert(textStart + text.length <= lineLength),
       assert((shapingCoreStart ?? textStart) >= textStart),
       assert((shapingCoreEnd ?? textStart + text.length) >= (shapingCoreStart ?? textStart)),
       assert((shapingCoreEnd ?? textStart + text.length) <= textStart + text.length),
       assert(originX >= 0),
       assert(estimatedTextWidth >= 0),
       assert(averageAdvance > 0),
       assert(visualGeneration >= 0),
       assert(!placeholder || text.isEmpty),
       tabInitialAdvance = tabInitialAdvance ?? averageAdvance * textStart;

  EditableLineLayoutWindow._visual({
    required this.lineLength,
    required this.textStart,
    required this.text,
    required this.originX,
    required this.estimatedTextWidth,
    required this.averageAdvance,
    required this.tabInitialAdvance,
    required this.visualFragments,
    required this.fragmentContentRanges,
    required this.totalContentCodeUnits,
    required this.totalParagraphCodeUnits,
    required this.visualGeneration,
    required this.visualMetricRevision,
    required this.visualFirstTile,
    required this.visualEndTile,
    required this.visualTileCount,
    required this.zeroWidthLogicalRanges,
    required this._visualMappings,
    required this._logicalMappings,
    required this._visualParagraphText,
    required this._visualTextEnd,
    required this.shapingCoreStart,
    required this.shapingCoreEnd,
  }) : textDirection = TextDirection.ltr,
       placeholder = false;

  /// 把已经按最终左到右顺序排列的真实片段组装成一个有界 Paragraph。
  ///
  /// 外层 LRO 固定片段容器顺序；每个片段再用 LRI 与 LRO/RLO 隔离并强制
  /// resolved level 的奇偶方向。全部控制符只存在于 [paragraphText]，正文、
  /// composer、选区与 document offset 始终通过片段映射访问。
  factory EditableLineLayoutWindow.visual({
    required int lineLength,
    required Iterable<EditableLineVisualFragment> fragments,
    int paragraphCodeUnitLimit = defaultVisualParagraphCodeUnitLimit,
    double originX = 0.0,
    double? estimatedTextWidth,
    double averageAdvance = 1.0,
    int visualGeneration = 0,
    int visualMetricRevision = 0,
    int visualFirstTile = -1,
    int visualEndTile = -1,
    int visualTileCount = 0,
    Iterable<TextRange> zeroWidthLogicalRanges = const <TextRange>[],
  }) {
    if (lineLength < 0) throw RangeError.range(lineLength, 0, null, 'lineLength');
    if (paragraphCodeUnitLimit <= 0) {
      throw RangeError.range(paragraphCodeUnitLimit, 1, null, 'paragraphCodeUnitLimit');
    }
    if (!originX.isFinite || originX < 0.0) {
      throw ArgumentError.value(originX, 'originX', '必须是有限非负数');
    }
    if (!averageAdvance.isFinite || averageAdvance <= 0.0) {
      throw ArgumentError.value(averageAdvance, 'averageAdvance', '必须是有限正数');
    }
    if (visualGeneration < 0) throw RangeError.range(visualGeneration, 0, null, 'visualGeneration');
    if (visualMetricRevision < 0) {
      throw RangeError.range(visualMetricRevision, 0, null, 'visualMetricRevision');
    }
    final hasTileMetadata = visualFirstTile >= 0 || visualEndTile >= 0 || visualTileCount > 0;
    if (hasTileMetadata &&
        (visualFirstTile < 0 || visualEndTile <= visualFirstTile || visualTileCount < visualEndTile)) {
      throw RangeError(
        'visual tile 元数据必须满足 0 <= first < end <= count：'
        '$visualFirstTile / $visualEndTile / $visualTileCount',
      );
    }

    final copied = List<EditableLineVisualFragment>.unmodifiable(fragments);
    if (copied.isEmpty) throw ArgumentError.value(fragments, 'fragments', 'visual window 至少需要一个真实正文片段');
    var contentLength = 0;
    for (final fragment in copied) {
      _validateVisualFragment(fragment, lineLength);
      contentLength += fragment.text.length;
    }
    final logicalOrder = copied.toList(growable: false)
      ..sort((left, right) {
        final byStart = left.lineStart.compareTo(right.lineStart);
        return byStart != 0 ? byStart : left.lineEnd.compareTo(right.lineEnd);
      });
    for (var index = 1; index < logicalOrder.length; index++) {
      final previous = logicalOrder[index - 1];
      final current = logicalOrder[index];
      if (current.lineStart < previous.lineEnd) {
        throw ArgumentError.value(
          copied,
          'fragments',
          '原文区间不得重叠：[${previous.lineStart}, ${previous.lineEnd}) 与 '
              '[${current.lineStart}, ${current.lineEnd})',
        );
      }
      if (current.lineStart == previous.lineEnd &&
          _isHighSurrogate(previous.text.codeUnitAt(previous.text.length - 1)) &&
          _isLowSurrogate(current.text.codeUnitAt(0))) {
        throw ArgumentError.value(copied, 'fragments', '合法 UTF-16 代理对不得拆到两个视觉片段');
      }
    }
    final copiedZeroWidthRanges = List<TextRange>.unmodifiable(zeroWidthLogicalRanges);
    var previousZeroWidthEnd = -1;
    for (final range in copiedZeroWidthRanges) {
      if (!range.isValid || range.isCollapsed || range.start < previousZeroWidthEnd || range.end > lineLength) {
        throw ArgumentError.value(copiedZeroWidthRanges, 'zeroWidthLogicalRanges', '必须是按逻辑顺序排列、互不重叠且位于完整行内的非空区间');
      }
      previousZeroWidthEnd = range.end;
    }

    const outerControlLength = 2;
    const controlsPerFragment = 4;
    final paragraphLength = contentLength + outerControlLength + copied.length * controlsPerFragment;
    if (paragraphLength > paragraphCodeUnitLimit) {
      throw RangeError.range(
        paragraphLength,
        0,
        paragraphCodeUnitLimit,
        'fragments',
        'synthetic Paragraph 超过 UTF-16 硬上限',
      );
    }

    final paragraph = StringBuffer()..writeCharCode(_visualOuterLro);
    final realText = StringBuffer();
    final mappings = <_EditableLineVisualMapping>[];
    for (final fragment in copied) {
      paragraph
        ..writeCharCode(_visualLri)
        ..writeCharCode(fragment.isRtl ? _visualFragmentRlo : _visualFragmentLro);
      final contentStart = paragraph.length;
      paragraph.write(fragment.text);
      final contentEnd = paragraph.length;
      paragraph
        ..writeCharCode(_visualPdf)
        ..writeCharCode(_visualPdi);
      realText.write(fragment.text);
      mappings.add(
        _EditableLineVisualMapping(
          fragment: fragment,
          contentRange: TextRange(start: contentStart, end: contentEnd),
        ),
      );
    }
    paragraph.writeCharCode(_visualPdf);
    final paragraphText = paragraph.toString();
    assert(paragraphText.length == paragraphLength);
    final immutableMappings = List<_EditableLineVisualMapping>.unmodifiable(mappings);
    final mappingsByLogical = immutableMappings.toList(growable: false)
      ..sort((left, right) => left.fragment.lineStart.compareTo(right.fragment.lineStart));
    final resolvedEstimatedWidth = estimatedTextWidth ?? averageAdvance * lineLength;
    if (!resolvedEstimatedWidth.isFinite || resolvedEstimatedWidth < 0.0) {
      throw ArgumentError.value(estimatedTextWidth, 'estimatedTextWidth', '必须解析为有限非负数');
    }
    return EditableLineLayoutWindow._visual(
      lineLength: lineLength,
      textStart: logicalOrder.first.lineStart,
      text: realText.toString(),
      originX: originX,
      estimatedTextWidth: resolvedEstimatedWidth,
      averageAdvance: averageAdvance,
      tabInitialAdvance: copied.first.logicalTabPrefix,
      visualFragments: copied,
      fragmentContentRanges: List<TextRange>.unmodifiable([
        for (final mapping in immutableMappings) mapping.contentRange,
      ]),
      totalContentCodeUnits: contentLength,
      totalParagraphCodeUnits: paragraphLength,
      visualGeneration: visualGeneration,
      visualMetricRevision: visualMetricRevision,
      visualFirstTile: visualFirstTile,
      visualEndTile: visualEndTile,
      visualTileCount: visualTileCount,
      zeroWidthLogicalRanges: copiedZeroWidthRanges,
      visualMappings: immutableMappings,
      logicalMappings: List<_EditableLineVisualMapping>.unmodifiable(mappingsByLogical),
      visualParagraphText: paragraphText,
      visualTextEnd: logicalOrder.last.lineEnd,
      shapingCoreStart: logicalOrder.first.lineStart,
      shapingCoreEnd: logicalOrder.last.lineEnd,
    );
  }

  /// 为只含方向格式控制符、没有任何可塑形正文的逻辑行创建零宽 visual window。
  factory EditableLineLayoutWindow.visualEmpty({
    required int lineLength,
    required double averageAdvance,
    required int visualGeneration,
    int visualMetricRevision = 0,
    double originX = 0.0,
    double? estimatedTextWidth,
  }) {
    if (lineLength < 0) throw RangeError.range(lineLength, 0, null, 'lineLength');
    if (!averageAdvance.isFinite || averageAdvance <= 0.0) {
      throw ArgumentError.value(averageAdvance, 'averageAdvance', '必须是有限正数');
    }
    if (visualGeneration < 0) throw RangeError.range(visualGeneration, 0, null, 'visualGeneration');
    if (visualMetricRevision < 0) {
      throw RangeError.range(visualMetricRevision, 0, null, 'visualMetricRevision');
    }
    if (!originX.isFinite || originX < 0.0) {
      throw ArgumentError.value(originX, 'originX', '必须是有限非负数');
    }
    final resolvedEstimatedWidth = estimatedTextWidth ?? originX;
    if (!resolvedEstimatedWidth.isFinite || resolvedEstimatedWidth < originX) {
      throw ArgumentError.value(estimatedTextWidth, 'estimatedTextWidth', '必须有限且不小于 originX');
    }
    return EditableLineLayoutWindow._visual(
      lineLength: lineLength,
      textStart: 0,
      text: '',
      originX: originX,
      estimatedTextWidth: resolvedEstimatedWidth,
      averageAdvance: averageAdvance,
      tabInitialAdvance: 0.0,
      visualFragments: const <EditableLineVisualFragment>[],
      fragmentContentRanges: const <TextRange>[],
      totalContentCodeUnits: 0,
      totalParagraphCodeUnits: 0,
      visualGeneration: visualGeneration,
      visualMetricRevision: visualMetricRevision,
      visualFirstTile: 0,
      visualEndTile: 0,
      visualTileCount: 0,
      zeroWidthLogicalRanges: lineLength == 0 ? const <TextRange>[] : <TextRange>[TextRange(start: 0, end: lineLength)],
      visualMappings: const <_EditableLineVisualMapping>[],
      logicalMappings: const <_EditableLineVisualMapping>[],
      visualParagraphText: '',
      visualTextEnd: lineLength,
      shapingCoreStart: 0,
      shapingCoreEnd: lineLength,
    );
  }

  /// 完整逻辑行的 UTF-16 长度。
  final int lineLength;

  /// 当前 Paragraph 在逻辑行中的 UTF-16 起点。
  final int textStart;

  /// 当前 Paragraph 的有界正文。
  final String text;

  /// 逻辑窗口中拥有双侧塑形上下文、允许回写全局宽度模型的正文起点。
  ///
  /// 该坐标属于完整逻辑行；[textStart] 到此前的正文只是左侧 shaping halo。
  /// visual window 的宽度按 tile 单独判定，因此此字段覆盖其逻辑包围区间。
  final int shapingCoreStart;

  /// 逻辑窗口中拥有双侧塑形上下文、允许回写全局宽度模型的正文终点。
  ///
  /// 该坐标属于完整逻辑行；此后到 [textEnd] 的正文只是右侧 shaping halo。
  final int shapingCoreEnd;

  /// 当前 Paragraph 左边缘在完整逻辑行盒中的横坐标。
  final double originX;

  /// 完整逻辑行正文宽度的有界估计值。
  final double estimatedTextWidth;

  /// 排版后原子替换逻辑窗口的横向几何，正文与映射继续共享。
  EditableLineLayoutWindow withLogicalGeometry({required double originX, required double textWidth}) {
    assert(!isVisual);
    return EditableLineLayoutWindow(
      lineLength: lineLength,
      textStart: textStart,
      text: text,
      originX: originX,
      estimatedTextWidth: textWidth,
      averageAdvance: averageAdvance,
      textDirection: textDirection,
      tabInitialAdvance: tabInitialAdvance,
      shapingCoreStart: shapingCoreStart,
      shapingCoreEnd: shapingCoreEnd,
      placeholder: placeholder,
      visualGeneration: visualGeneration,
    );
  }

  /// 未测区间用于坐标投影的平均 UTF-16 advance。
  final double averageAdvance;

  /// 段落基向，用于镜像 RTL 的未测区间投影。
  final TextDirection textDirection;

  /// 当前无法在硬预算内证明字素边界，Paragraph 只画替代占位且不映射正文。
  final bool placeholder;

  /// 当前窗口起点从完整逻辑行 offset-0 累计而来的 tab 网格 advance。
  final double tabInitialAdvance;

  /// visual 模式下按最终左到右顺序排列的真实正文片段；旧单窗口为空。
  final List<EditableLineVisualFragment> visualFragments;

  /// 每个 [visualFragments] 正文在 synthetic Paragraph 中的半开区间。
  final List<TextRange> fragmentContentRanges;

  /// 当前窗口全部真实正文的 UTF-16 总长度，不含合成控制符。
  final int totalContentCodeUnits;

  /// 实际 synthetic Paragraph 的 UTF-16 总长度，包含合成控制符。
  final int totalParagraphCodeUnits;

  /// 长行窗口内容代际；visual 与临时逻辑/placeholder 窗口共用，用于拒绝迟到上报。
  final int visualGeneration;

  /// visual tile 宽度前缀的测量代际；变化时即使总宽抵消也必须确认一次布局。
  final int visualMetricRevision;

  /// 当前 visual window 覆盖的第一个全行视觉 tile；未知时为 -1。
  final int visualFirstTile;

  /// 当前 visual window 最后一个视觉 tile 之后的位置；未知时为 -1。
  final int visualEndTile;

  /// 构造窗口时完整 visual index 的 tile 总数。
  final int visualTileCount;

  /// 当前窗口明确证明为零宽格式控制符的原文区间。
  final List<TextRange> zeroWidthLogicalRanges;

  final List<_EditableLineVisualMapping> _visualMappings;
  final List<_EditableLineVisualMapping> _logicalMappings;
  final String? _visualParagraphText;
  final int? _visualTextEnd;
  int _debugLastContainedRangeProbeCount = 0;

  /// 最近一次 visual 逻辑范围起点定位的二分探针数。
  @visibleForTesting
  int get debugLastContainedRangeProbeCount => _debugLastContainedRangeProbeCount;

  /// 当前是否为已经按全局视觉顺序拼接的多片段窗口。
  bool get isVisual => _visualParagraphText != null;

  /// 当前 Paragraph 在逻辑行中的 UTF-16 终点。
  int get textEnd => _visualTextEnd ?? textStart + text.length;

  /// 实际送入 Paragraph 的文字；占位符永远不进入文档或 composer。
  String get paragraphText => _visualParagraphText ?? (placeholder ? '\uFFFD' : text);

  /// 从逻辑行 offset 0 到当前窗口起点的估算 advance，供 tab stop 延续网格。
  double get logicalPrefixAdvance => tabInitialAdvance;

  /// 当前窗口是否包含给定逻辑行 offset；窗口终点 caret 也算包含。
  bool containsOffset(int offset) {
    if (!isVisual) return offset >= textStart && offset <= textEnd;
    return containsPosition(TextPosition(offset: offset)) ||
        containsPosition(TextPosition(offset: offset, affinity: TextAffinity.upstream));
  }

  /// 当前窗口是否包含指定 affinity 所选择的 bidi caret 侧。
  bool containsPosition(TextPosition position) {
    final offset = position.offset;
    if (!isVisual) return offset >= textStart && offset <= textEnd;
    if (offset < 0 || offset > lineLength) return false;
    if (_logicalMappings.isEmpty) return true;
    final insertion = _logicalInsertionIndex(offset);
    final before = insertion == 0 ? null : _logicalMappings[insertion - 1].fragment;
    final after = insertion >= _logicalMappings.length ? null : _logicalMappings[insertion].fragment;
    if (before != null && offset > before.lineStart && offset < before.lineEnd) return true;
    if (_containsZeroWidthOffset(offset)) return true;
    if (position.affinity == TextAffinity.downstream) {
      return after != null && offset == after.lineStart;
    }
    return before != null && offset == before.lineEnd;
  }

  bool _containsZeroWidthOffset(int offset) {
    var low = 0;
    var high = zeroWidthLogicalRanges.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (zeroWidthLogicalRanges[middle].end < offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low >= zeroWidthLogicalRanges.length) return false;
    final range = zeroWidthLogicalRanges[low];
    return offset >= range.start && offset <= range.end;
  }

  /// 把逻辑行位置换算成 Paragraph 局部位置，并钳在窗口内。
  TextPosition toParagraphPosition(TextPosition position) {
    if (!isVisual) {
      return TextPosition(offset: (position.offset - textStart).clamp(0, text.length), affinity: position.affinity);
    }
    if (_logicalMappings.isEmpty) return TextPosition(offset: 0, affinity: position.affinity);
    final offset = position.offset.clamp(0, lineLength);
    final mapping = _mappingForLineOffset(offset, position.affinity);
    final local = _normalizeSurrogateBoundary(
      mapping.fragment.text,
      (offset - mapping.fragment.lineStart).clamp(0, mapping.fragment.text.length),
      position.affinity,
    );
    return TextPosition(offset: mapping.contentRange.start + local, affinity: position.affinity);
  }

  /// 把 Paragraph 局部位置换回逻辑行位置。
  TextPosition toLinePosition(TextPosition position) {
    if (!isVisual) {
      return TextPosition(offset: (textStart + position.offset).clamp(0, lineLength), affinity: position.affinity);
    }
    if (_visualMappings.isEmpty) {
      return TextPosition(
        offset: position.affinity == TextAffinity.upstream ? lineLength : 0,
        affinity: position.affinity,
      );
    }
    final offset = position.offset.clamp(0, totalParagraphCodeUnits);
    var low = 0;
    var high = _visualMappings.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_visualMappings[middle].contentRange.start <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final previousIndex = low - 1;
    if (previousIndex >= 0) {
      final mapping = _visualMappings[previousIndex];
      final range = mapping.contentRange;
      if (offset <= range.end) {
        final local = _normalizeSurrogateBoundary(mapping.fragment.text, offset - range.start, position.affinity);
        return TextPosition(offset: mapping.fragment.lineStart + local, affinity: position.affinity);
      }
    }

    final previous = previousIndex < 0 ? null : _visualMappings[previousIndex];
    final next = low >= _visualMappings.length ? null : _visualMappings[low];
    final selected = position.affinity == TextAffinity.upstream ? previous ?? next! : next ?? previous!;
    final lineOffset = identical(selected, previous) ? selected.fragment.lineEnd : selected.fragment.lineStart;
    return TextPosition(offset: lineOffset, affinity: position.affinity);
  }

  /// 把正向逻辑选区拆成零到多个纯正文 Paragraph 区间。
  ///
  /// 返回顺序与 [visualFragments] 相同；X9 gap 与所有 synthetic controls 都不
  /// 进入结果。visual 模式严格拒绝越界、反向区间与拆开代理对的端点。
  List<TextRange> paragraphRanges(int start, int end) {
    if (!isVisual) {
      final range = paragraphRange(start, end);
      return range.isCollapsed ? const <TextRange>[] : <TextRange>[range];
    }
    if (start < 0 || end < start || end > lineLength) {
      throw RangeError('selection 必须满足 0 <= start <= end <= lineLength');
    }
    if (start == end) return const <TextRange>[];
    if (_visualMappings.isEmpty) return const <TextRange>[];
    _rejectSplitSurrogateBoundary(start, 'start');
    _rejectSplitSurrogateBoundary(end, 'end');
    return List<TextRange>.unmodifiable([
      for (final mapping in _overlappingMappingsInVisualOrder(start, end))
        TextRange(
          start:
              mapping.contentRange.start +
              math.max(start, mapping.fragment.lineStart).toInt() -
              mapping.fragment.lineStart,
          end:
              mapping.contentRange.start + math.min(end, mapping.fragment.lineEnd).toInt() - mapping.fragment.lineStart,
        ),
    ]);
  }

  /// 把绘制区间拆成 Paragraph 正文范围，并把非法代理对端点向外扩到完整 scalar。
  ///
  /// 公开模型映射 [paragraphRanges] 继续严格拒绝坏端点；本入口只用于防御宿主
  /// 注入的 selection/composing，避免错误 UTF-16 位置在 paint 阶段击穿编辑器。
  List<TextRange> paragraphRangesForPainting(int start, int end) {
    if (!isVisual) {
      final range = paragraphRange(start, end);
      return range.isCollapsed ? const <TextRange>[] : <TextRange>[range];
    }
    if (start < 0 || end < start || end > lineLength) {
      throw RangeError('selection 必须满足 0 <= start <= end <= lineLength');
    }
    if (start == end || _visualMappings.isEmpty) return const <TextRange>[];
    final result = <TextRange>[];
    for (final mapping in _overlappingMappingsInVisualOrder(start, end)) {
      final fragment = mapping.fragment;
      final clippedStart = math.max(start, fragment.lineStart).toInt();
      final clippedEnd = math.min(end, fragment.lineEnd).toInt();
      if (clippedStart >= clippedEnd) continue;
      final localStart = _normalizeSurrogateBoundary(
        fragment.text,
        clippedStart - fragment.lineStart,
        TextAffinity.upstream,
      );
      final localEnd = _normalizeSurrogateBoundary(
        fragment.text,
        clippedEnd - fragment.lineStart,
        TextAffinity.downstream,
      );
      if (localStart >= localEnd) continue;
      result.add(TextRange(start: mapping.contentRange.start + localStart, end: mapping.contentRange.start + localEnd));
    }
    return List<TextRange>.unmodifiable(result);
  }

  List<_EditableLineVisualMapping> _overlappingMappingsInVisualOrder(int start, int end) {
    _debugLastContainedRangeProbeCount = 0;
    var low = 0;
    var high = _logicalMappings.length;
    while (low < high) {
      _debugLastContainedRangeProbeCount++;
      final middle = low + ((high - low) >> 1);
      if (_logicalMappings[middle].fragment.lineEnd <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low >= _logicalMappings.length) return const <_EditableLineVisualMapping>[];
    final result = <_EditableLineVisualMapping>[];
    for (var index = low; index < _logicalMappings.length; index++) {
      final mapping = _logicalMappings[index];
      if (mapping.fragment.lineStart >= end) break;
      result.add(mapping);
    }
    if (result.length > 1) {
      result.sort((left, right) => left.contentRange.start.compareTo(right.contentRange.start));
    }
    return result;
  }

  /// 把确认完全位于单个 visual fragment 的逻辑范围以 O(log F) 映到 Paragraph。
  ///
  /// 视觉 tile 测宽使用本入口，避免为每个 tile 扫描全部 fragment。跨 fragment
  /// 或非法范围返回 null；调用方不得把它当通用 selection 映射。
  TextRange? paragraphRangeForContainedLogicalRange(int start, int end) {
    _debugLastContainedRangeProbeCount = 0;
    if (start < 0 || end <= start || end > lineLength) return null;
    if (!isVisual) {
      if (start < textStart || end > textEnd) return null;
      return TextRange(start: start - textStart, end: end - textStart);
    }
    var low = 0;
    var high = _logicalMappings.length;
    while (low < high) {
      _debugLastContainedRangeProbeCount++;
      final middle = low + ((high - low) >> 1);
      if (_logicalMappings[middle].fragment.lineEnd <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low >= _logicalMappings.length) return null;
    final mapping = _logicalMappings[low];
    final fragment = mapping.fragment;
    if (start < fragment.lineStart || end > fragment.lineEnd) return null;
    return TextRange(
      start: mapping.contentRange.start + start - fragment.lineStart,
      end: mapping.contentRange.start + end - fragment.lineStart,
    );
  }

  /// 把逻辑行区间裁到当前 Paragraph，并返回 Paragraph 局部区间。
  TextRange paragraphRange(int start, int end) {
    final clippedStart = math.max(start, textStart);
    final clippedEnd = math.min(end, textEnd);
    if (isVisual) {
      if (clippedEnd <= clippedStart) {
        final offset = clippedStart.clamp(0, lineLength);
        return TextRange.collapsed(toParagraphPosition(TextPosition(offset: offset)).offset);
      }
      final ranges = paragraphRanges(clippedStart.clamp(0, lineLength), clippedEnd.clamp(0, lineLength));
      if (ranges.isEmpty) return TextRange.collapsed(toParagraphPosition(TextPosition(offset: clippedStart)).offset);
      if (ranges.length == 1) return ranges.single;
      throw StateError('visual window 的选区跨越多个片段，请使用 paragraphRanges');
    }
    if (clippedEnd <= clippedStart) return TextRange.collapsed((clippedStart - textStart).clamp(0, text.length));
    return TextRange(start: clippedStart - textStart, end: clippedEnd - textStart);
  }

  _EditableLineVisualMapping _mappingForLineOffset(int offset, TextAffinity affinity) {
    final insertion = _logicalInsertionIndex(offset);
    final before = insertion == 0 ? null : _logicalMappings[insertion - 1];
    final after = insertion >= _logicalMappings.length ? null : _logicalMappings[insertion];
    if (before != null && offset > before.fragment.lineStart && offset < before.fragment.lineEnd) {
      return before;
    }
    return affinity == TextAffinity.upstream ? before ?? after! : after ?? before!;
  }

  int _logicalInsertionIndex(int offset) {
    var low = 0;
    var high = _logicalMappings.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_logicalMappings[middle].fragment.lineStart < offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  void _rejectSplitSurrogateBoundary(int offset, String name) {
    for (final mapping in _logicalMappings) {
      final fragment = mapping.fragment;
      if (offset <= fragment.lineStart || offset >= fragment.lineEnd) continue;
      final local = offset - fragment.lineStart;
      if (_isHighSurrogate(fragment.text.codeUnitAt(local - 1)) && _isLowSurrogate(fragment.text.codeUnitAt(local))) {
        throw ArgumentError.value(offset, name, '不得拆开 UTF-16 代理对');
      }
      return;
    }
  }
}

@immutable
final class _EditableLineVisualMapping {
  const _EditableLineVisualMapping({required this.fragment, required this.contentRange});

  final EditableLineVisualFragment fragment;
  final TextRange contentRange;
}

void _validateVisualFragment(EditableLineVisualFragment fragment, int lineLength) {
  if (fragment.lineStart < 0 || fragment.lineEnd <= fragment.lineStart || fragment.lineEnd > lineLength) {
    throw RangeError(
      '片段必须满足 0 <= lineStart < lineEnd <= lineLength：'
      '[${fragment.lineStart}, ${fragment.lineEnd}) / $lineLength',
    );
  }
  if (fragment.text.length != fragment.length) {
    throw ArgumentError.value(fragment.text, 'fragment.text', '必须与原文 UTF-16 区间等长');
  }
  if (fragment.resolvedLevel < 0 || fragment.resolvedLevel > 126) {
    throw RangeError.range(fragment.resolvedLevel, 0, 126, 'fragment.resolvedLevel');
  }
  if (!fragment.logicalTabPrefix.isFinite || fragment.logicalTabPrefix < 0.0) {
    throw ArgumentError.value(fragment.logicalTabPrefix, 'fragment.logicalTabPrefix', '必须是有限非负数');
  }
}

int _normalizeSurrogateBoundary(String text, int offset, TextAffinity affinity) {
  if (offset <= 0 || offset >= text.length) return offset;
  if (!_isHighSurrogate(text.codeUnitAt(offset - 1)) || !_isLowSurrogate(text.codeUnitAt(offset))) return offset;
  return affinity == TextAffinity.upstream ? offset - 1 : offset + 1;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdbff;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xdc00 && codeUnit <= 0xdfff;
