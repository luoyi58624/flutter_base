// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import '../composer.dart';
import '../editable_controller.dart';
import '../editing/editable_layout_query.dart';
import '../editing/editable_word_navigator.dart';
import '../line_height.dart';
import '../model/editable_selection.dart';
import '../model/grapheme_boundary.dart';
import '../model/text_document.dart';
import '../projection/editable_line_projection.dart';
import 'bidi/long_line_bidi_index.dart';
import 'bidi/long_line_bidi_pipeline.dart';
import 'bidi/long_line_visual_index.dart';
import 'bidi/unicode_bidi_data.g.dart';
import 'editable_line_layout.dart';
import 'editable_line_view.dart';
import 'editable_tab_stops.dart';
import 'inline_text_painter.dart';
import 'long_line_width_index.dart';

/// 单个内部选区在一行中的绘制范围。
@immutable
final class EditableLineSelectionPaint {
  /// 创建本行局部坐标中的选区绘制范围。
  const EditableLineSelectionPaint({required this.start, required this.end, required this.selectsNewline})
    : assert(start >= 0),
      assert(end >= start);

  /// 选区在本行的局部起点。
  final int start;

  /// 选区在本行的局部终点。
  final int end;

  /// 是否绘制换行尾块；三击非空整行只画文字，真实选区仍保留换行。
  final bool selectsNewline;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditableLineSelectionPaint &&
          other.start == start &&
          other.end == end &&
          other.selectsNewline == selectsNewline;

  @override
  int get hashCode => Object.hash(start, end, selectsNewline);
}

/// 单个 selection 活动端光标在一行中的绘制位置。
@immutable
final class EditableLineCaretPaint {
  /// 创建本行局部坐标中的光标绘制位置。
  const EditableLineCaretPaint({required this.offset, required this.upstream, this.overwriteEnd = -1})
    : assert(offset >= 0),
      assert(overwriteEnd == -1 || overwriteEnd >= offset);

  /// 光标的行内偏移。
  final int offset;

  /// 折行亲和是否靠上一视觉行行尾。
  final bool upstream;

  /// 覆写块光标覆盖的完整字素终点；-1 表示普通细光标，等于 [offset] 表示
  /// 行末没有可覆盖字素但仍显示一个空白单元块。
  final int overwriteEnd;

  /// 当前是否绘制覆写块光标。
  bool get overwrite => overwriteEnd >= offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditableLineCaretPaint &&
          other.offset == offset &&
          other.upstream == upstream &&
          other.overwriteEnd == overwriteEnd;

  @override
  int get hashCode => Object.hash(offset, upstream, overwriteEnd);
}

/// 单行的绘制状态快照（行内坐标）。值相等 = 无需重绘。
@immutable
final class EditableLinePaint {
  /// 创建防御性冻结了选区与光标列表的绘制快照。
  factory EditableLinePaint({
    Iterable<EditableLineSelectionPaint> selections = const <EditableLineSelectionPaint>[],
    Iterable<EditableLineCaretPaint> carets = const <EditableLineCaretPaint>[],
    int composingStart = -1,
    int composingEnd = -1,
    bool caretVisible = false,
    bool primaryCaretSuppressed = false,
  }) {
    final frozenSelections = selections.isEmpty
        ? const <EditableLineSelectionPaint>[]
        : List<EditableLineSelectionPaint>.unmodifiable(selections);
    final frozenCarets = carets.isEmpty
        ? const <EditableLineCaretPaint>[]
        : List<EditableLineCaretPaint>.unmodifiable(carets);
    if (frozenSelections.isEmpty &&
        frozenCarets.isEmpty &&
        composingStart < 0 &&
        composingEnd < 0 &&
        !caretVisible &&
        !primaryCaretSuppressed) {
      return const EditableLinePaint.empty();
    }
    return EditableLinePaint._(
      selections: frozenSelections,
      carets: frozenCarets,
      composingStart: composingStart,
      composingEnd: composingEnd,
      caretVisible: caretVisible,
      primaryCaretSuppressed: primaryCaretSuppressed,
    );
  }

  /// 创建没有内部选区、光标与 composing 的空快照。
  const EditableLinePaint.empty()
    : selections = const <EditableLineSelectionPaint>[],
      carets = const <EditableLineCaretPaint>[],
      composingStart = -1,
      composingEnd = -1,
      caretVisible = false,
      primaryCaretSuppressed = false;

  const EditableLinePaint._({
    required this.selections,
    required this.carets,
    required this.composingStart,
    required this.composingEnd,
    required this.caretVisible,
    required this.primaryCaretSuppressed,
  });

  /// 当前行中全部非折叠内部选区的只读绘制范围。
  final List<EditableLineSelectionPaint> selections;

  /// 当前行中全部 selection 活动端光标的只读绘制位置。
  final List<EditableLineCaretPaint> carets;

  /// composing 在本行的局部区间；无为 -1。
  final int composingStart;

  /// composing 在本行的局部终点；无为 -1。
  final int composingEnd;

  /// 当前行的光标是否允许绘制。
  final bool caretVisible;

  /// 主光标是否正由编辑器级动画层绘制；为 true 时它恒为 [carets] 首项。
  final bool primaryCaretSuppressed;

  /// 是否至少有一个内部选区需要绘制。
  bool get hasSelection => selections.isNotEmpty;

  /// 是否有 composing 下划线需要绘制。
  bool get hasComposing => composingEnd > composingStart;

  /// 是否至少有一个内部光标需要绘制。
  bool get hasCaret => carets.isNotEmpty;

  /// 首个选区的局部起点；兼容旧单选区读取，无选区为 -1。
  int get selectionStart => selections.isEmpty ? -1 : selections.first.start;

  /// 首个选区的局部终点；兼容旧单选区读取，无选区为 -1。
  int get selectionEnd => selections.isEmpty ? -1 : selections.first.end;

  /// 首个选区是否绘制换行尾块；兼容旧单选区读取。
  bool get selectsNewline => selections.isNotEmpty && selections.first.selectsNewline;

  /// 首个光标的行内偏移；兼容旧单光标读取，不在本行为 -1。
  int get caretOffset => carets.isEmpty ? -1 : carets.first.offset;

  /// 首个光标是否靠上一视觉行行尾；兼容旧单光标读取。
  bool get caretUpstream => carets.isNotEmpty && carets.first.upstream;

  /// 优化：检查选区范围是否相等（不比较光标可见性）。
  /// 用于缓存选区几何，光标闪烁时几何无需重建。
  bool selectionsEqual(EditableLinePaint other) {
    return listEquals(other.selections, selections) &&
        other.composingStart == composingStart &&
        other.composingEnd == composingEnd;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EditableLinePaint &&
            listEquals(other.selections, selections) &&
            listEquals(other.carets, carets) &&
            other.composingStart == composingStart &&
            other.composingEnd == composingEnd &&
            other.caretVisible == caretVisible &&
            other.primaryCaretSuppressed == primaryCaretSuppressed;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(selections),
    Object.hashAll(carets),
    composingStart,
    composingEnd,
    caretVisible,
    primaryCaretSuppressed,
  );
}

/// 行渲染的共享绘制配置。变化即整体 relayout（低频）。
@immutable
class EditableRenderConfig {
  const EditableRenderConfig({
    required this.textStyle,
    required this.textDirection,
    this.textAlign = TextAlign.start,
    required this.textScaler,
    required this.softWrap,
    required this.caretColor,
    required this.caretWidth,
    required this.selectionColor,
    this.selectionTextColor,
    required this.composingUnderline,
    this.tabSize = 4,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.composer = EditableComposer.plain,
    this.wordSeparators = EditableWordNavigator.defaultWordSeparators,
    this.lineHeightMode = EditableLineHeightMode.content,
  }) : assert(tabSize > 0),
       assert(obscuringCharacter.length == 1);

  final TextStyle textStyle;
  final TextDirection textDirection;

  /// 文本在每条视觉行可用宽度内的水平对齐方式。
  final TextAlign textAlign;

  final TextScaler textScaler;
  final bool softWrap;
  final Color caretColor;
  final double caretWidth;
  final Color selectionColor;

  /// 内部选区中的文字前景覆盖色；null 保留 composer 原始前景。
  final Color? selectionTextColor;

  final bool composingUnderline;

  /// tab stop 的列宽；`\t` 仍只占一个 UTF-16 offset。
  final int tabSize;

  /// 掩码模式（密码框）：显示层逐 **code unit** 替换为 [obscuringCharacter]，
  /// 文档 / 选区 / IME 全部保持真实文本，坐标零漂移（Flutter 官方同款权衡：
  /// 代理对字符显示为两个掩码点）。
  final bool obscureText;

  /// 掩码字符，必须单 code unit。
  final String obscuringCharacter;

  /// 行装配器（富文本 / 高亮扩展点）。按实例身份比较：换实例即整体重排，
  /// 属性级失效走 [EditableController.invalidatePresentation]。
  final EditableComposer composer;

  /// 普通行、长行与编辑命令共用的词分隔符口径。
  final String wordSeparators;

  /// 视觉行采用固定根样式度量，或允许内容 run 撑高。
  final EditableLineHeightMode lineHeightMode;

  /// 仅绘制字段变化时保留行宽、固定行高与长行索引。
  bool hasSameLayout(EditableRenderConfig other) =>
      textStyle.compareTo(other.textStyle).index <= RenderComparison.paint.index &&
      textDirection == other.textDirection &&
      textAlign == other.textAlign &&
      textScaler == other.textScaler &&
      softWrap == other.softWrap &&
      caretWidth == other.caretWidth &&
      tabSize == other.tabSize &&
      obscureText == other.obscureText &&
      obscuringCharacter == other.obscuringCharacter &&
      identical(composer, other.composer) &&
      wordSeparators == other.wordSeparators &&
      lineHeightMode == other.lineHeightMode;

  @override
  bool operator ==(Object other) {
    return other is EditableRenderConfig &&
        other.textStyle == textStyle &&
        other.textDirection == textDirection &&
        other.textAlign == textAlign &&
        other.textScaler == textScaler &&
        other.softWrap == softWrap &&
        other.caretColor == caretColor &&
        other.caretWidth == caretWidth &&
        other.selectionColor == selectionColor &&
        other.selectionTextColor == selectionTextColor &&
        other.composingUnderline == composingUnderline &&
        other.tabSize == tabSize &&
        other.obscureText == obscureText &&
        other.obscuringCharacter == obscuringCharacter &&
        identical(other.composer, composer) &&
        other.wordSeparators == wordSeparators &&
        other.lineHeightMode == lineHeightMode;
  }

  @override
  int get hashCode => Object.hash(
    textStyle,
    textDirection,
    textAlign,
    textScaler,
    softWrap,
    caretColor,
    caretWidth,
    selectionColor,
    selectionTextColor,
    composingUnderline,
    tabSize,
    obscureText,
    obscuringCharacter,
    identityHashCode(composer),
    wordSeparators,
    lineHeightMode,
  );
}

@immutable
final class _EditableKnownLineWidth {
  const _EditableKnownLineWidth({
    required this.textWidth,
    required this.insertTrailingExtent,
    required this.overwriteTrailingExtent,
    required this.alignToViewport,
  });

  final double textWidth;
  final double insertTrailingExtent;
  final double overwriteTrailingExtent;
  final bool alignToViewport;
}

@immutable
final class _EditableLongLineCoverage {
  const _EditableLongLineCoverage({
    required this.left,
    required this.right,
    required this.atContentLeft,
    required this.atContentRight,
  });

  final double left;
  final double right;
  final bool atContentLeft;
  final bool atContentRight;

  bool containsViewport(double pixels, double width) {
    final guard = math.max(width, 1.0);
    final viewportRight = pixels + width;
    final safeLeft = atContentLeft ? 0.0 : left + guard;
    final safeRight = atContentRight ? double.infinity : right - guard;
    return pixels >= safeLeft - precisionErrorTolerance && viewportRight <= safeRight + precisionErrorTolerance;
  }
}

final class _EditableLongLineTabPrefix {
  _EditableLongLineTabPrefix(this.averageAdvance, this.widthRevision) {
    _recordBlockCheckpoint(0, 0.0);
  }

  static const int checkpointStride = _EditableLongLineWidthModel.chunkSize;
  static const int _checkpointPageEntries = 256;
  static const int _queryCacheCapacity = 64;

  double averageAdvance;
  int widthRevision;
  int scannedUntil = 0;
  double tabExtra = 0.0;
  double retainedExtent = 0.0;
  bool sawTab = false;
  bool sawBidiControl = false;
  bool bidiOverflow = false;
  bool lastStrongRtl = false;
  bool sawStrongRtl = false;
  int? pendingHighSurrogate;
  final List<bool> bidiStack = <bool>[];
  final List<Float64List> _checkpointPages = <Float64List>[];
  final Map<int, double> _queryCache = <int, double>{};
  int _checkpointCount = 0;

  bool get hasUnsafeBidiPrefix => bidiOverflow || bidiStack.isNotEmpty || sawBidiControl || sawStrongRtl;

  bool get hasUnsafeBidiTail => bidiOverflow || bidiStack.isNotEmpty || sawBidiControl || lastStrongRtl;

  int get checkpointCount => _checkpointCount;

  int get retainedBytes =>
      _checkpointPages.length * _checkpointPageEntries * 8 + _queryCache.length * 24 + bidiStack.length;

  void reset() {
    scannedUntil = 0;
    tabExtra = 0.0;
    sawTab = false;
    sawBidiControl = false;
    bidiOverflow = false;
    lastStrongRtl = false;
    sawStrongRtl = false;
    pendingHighSurrogate = null;
    bidiStack.clear();
    _checkpointPages.clear();
    _queryCache.clear();
    _checkpointCount = 0;
    _recordBlockCheckpoint(0, 0.0);
  }

  void recordCheckpointAt(int offset, double extra) {
    if (offset % checkpointStride != 0) return;
    _recordBlockCheckpoint(offset, extra);
  }

  ({int offset, double extra}) checkpointForOffset(int offset) {
    final index = math.min(offset ~/ checkpointStride, _checkpointCount - 1);
    return (offset: index * checkpointStride, extra: _checkpointAt(index));
  }

  double? cachedExtraForOffset(int offset) => _queryCache[offset];

  void cacheExtraForOffset(int offset, double extra) {
    _queryCache.remove(offset);
    _queryCache[offset] = extra;
    while (_queryCache.length > _queryCacheCapacity) {
      _queryCache.remove(_queryCache.keys.first);
    }
  }

  void _recordBlockCheckpoint(int offset, double extra) {
    final index = offset ~/ checkpointStride;
    if (index > _checkpointCount) {
      throw StateError('tab 前缀检查点必须按 UTF-16 块顺序追加');
    }
    if (index == _checkpointCount) {
      if (index % _checkpointPageEntries == 0) {
        _checkpointPages.add(Float64List(_checkpointPageEntries));
      }
      _checkpointCount++;
    }
    _checkpointPages[index ~/ _checkpointPageEntries][index % _checkpointPageEntries] = extra;
  }

  double _checkpointAt(int index) => _checkpointPages[index ~/ _checkpointPageEntries][index % _checkpointPageEntries];
}

final class _EditableLongLineEstimateProgress {
  _EditableLongLineEstimateProgress({
    required this.revision,
    required this.tileCount,
    required this.priorityFirstTile,
    required this.priorityEndTile,
  }) : priorityNextTile = priorityFirstTile;

  final int revision;
  final int tileCount;
  int globalNextTile = 0;
  int priorityFirstTile;
  int priorityEndTile;
  int priorityNextTile;

  void prioritize(int firstTile, int endTile) {
    if (priorityFirstTile == firstTile && priorityEndTile == endTile) return;
    priorityFirstTile = firstTile;
    priorityEndTile = endTile;
    priorityNextTile = firstTile;
  }

  bool get complete => globalNextTile >= tileCount;
}

final class _EditableLongLineTabBatchProgress {
  _EditableLongLineTabBatchProgress({
    required this.revision,
    required this.offsets,
    required this.scanOffset,
    required this.extra,
  });

  final int revision;
  final List<int> offsets;
  final Map<int, double> values = <int, double>{};
  int nextIndex = 0;
  int scanOffset;
  double extra;

  bool matches(int candidateRevision, List<int> candidateOffsets) =>
      revision == candidateRevision && listEquals(offsets, candidateOffsets);

  bool get complete => nextIndex >= offsets.length;
}

@immutable
final class _EditableTabStyleRun {
  const _EditableTabStyleRun({required this.start, required this.end, required this.stopExtent});

  final int start;
  final int end;
  final double stopExtent;
}

final class _EditableLongLineWidthModel {
  _EditableLongLineWidthModel(double advance) : index = LongLineWidthIndex(advance);

  static const int chunkSize = 1024;
  final LongLineWidthIndex index;
  int revision = 0;

  double xForOffset(int offset, int lineLength) {
    return index.xForOffset(offset.clamp(0, lineLength));
  }

  double advanceAt(int offset) => index.advanceAt(offset);

  int offsetForX(double x, int lineLength) {
    return index.offsetForX(x, lineLength);
  }

  void reportWindow(int start, int end, double average, int lineLength) {
    if (end <= start) return;
    final origin = xForOffset(start, lineLength);
    final offsets = <int>[start];
    for (var offset = (start ~/ chunkSize + 1) * chunkSize; offset < end; offset += chunkSize) {
      offsets.add(offset);
    }
    offsets.add(end);
    index.record(offsets, [for (final offset in offsets) origin + (offset - start) * average]);
    revision++;
  }

  double extentFor(int lineLength, double viewportWidth) => math.max(viewportWidth, xForOffset(lineLength, lineLength));
}

final class _SelectionCaretPaintEntry {
  const _SelectionCaretPaintEntry({required this.selection, required this.position, required this.primary});

  final EditableSelection selection;
  final TextPosition position;
  final bool primary;
}

final class _SelectionPaintIndex {
  _SelectionPaintIndex(EditableSelectionSet selections, {EditableLineProjection? projection, TextDocument? document})
    : primary = selections.primary,
      secondary = selections.secondary,
      hasNonCollapsedSelections =
          !selections.primary.isCollapsed || selections.secondary.any((selection) => !selection.isCollapsed) {
    TextPosition projectCaret(EditableSelection selection) {
      final raw = TextPosition(offset: selection.active, affinity: selection.affinity);
      final base = projection == null || projection.hiddenAreas?.isEmpty != false
          ? raw
          : projection.canonicalizeVisibleCaretPosition(
              selection.isCollapsed
                  ? projection.projectCollapsedPosition(raw, bias: EditablePositionProjectionBias.backward)
                  : projection.projectSelectionEndpointForGeometry(
                      raw,
                      oppositeEndpoint: TextPosition(offset: selection.anchor),
                    ),
            );
      // 行首 + upstream：光标几何在换行符左侧，归一化到上一行行尾（本行不画）。
      // 三击选行（含行尾换行）的 active 端即此形态；投影后的可见位置若已
      // 落在行内（非行首）则保持原样。
      if (base.affinity == TextAffinity.upstream && base.offset > 0) {
        final doc = document;
        if (doc != null) {
          final line = doc.lineIndexOf(base.offset);
          if (line > 0 && doc.lineStart(line) == base.offset) {
            return TextPosition(offset: base.offset - 1, affinity: base.affinity);
          }
        }
      }
      return base;
    }

    primaryCaret = _SelectionCaretPaintEntry(
      selection: selections.primary,
      position: projectCaret(selections.primary),
      primary: true,
    );
    final projected =
        <_SelectionCaretPaintEntry>[
          for (final selection in selections.secondary)
            _SelectionCaretPaintEntry(selection: selection, position: projectCaret(selection), primary: false),
        ]..sort((left, right) {
          final offset = left.position.offset.compareTo(right.position.offset);
          if (offset != 0) return offset;
          return left.position.affinity.index.compareTo(right.position.affinity.index);
        });
    final unique = <_SelectionCaretPaintEntry>[];
    for (final entry in projected) {
      if (_sameCaret(entry, primaryCaret) || (unique.isNotEmpty && _sameCaret(entry, unique.last))) continue;
      unique.add(entry);
    }
    secondaryCarets = List<_SelectionCaretPaintEntry>.unmodifiable(unique);
  }

  final EditableSelection primary;
  final List<EditableSelection> secondary;
  final bool hasNonCollapsedSelections;
  late final _SelectionCaretPaintEntry primaryCaret;
  late final List<_SelectionCaretPaintEntry> secondaryCarets;

  int visitSelections(int lineStart, int lineEnd, void Function(EditableSelection selection) visitor) {
    var probes = 1;
    if (_mayPaint(primary, lineStart, lineEnd)) visitor(primary);

    var lower = 0;
    var upper = secondary.length;
    while (lower < upper) {
      probes++;
      final middle = lower + ((upper - lower) >> 1);
      if (secondary[middle].end < lineStart) {
        lower = middle + 1;
      } else {
        upper = middle;
      }
    }
    for (var index = lower; index < secondary.length; index++) {
      probes++;
      final selection = secondary[index];
      if (selection.start > lineEnd) break;
      if (_mayPaint(selection, lineStart, lineEnd)) visitor(selection);
    }
    return probes;
  }

  int visitCarets(int lineStart, int lineEnd, void Function(_SelectionCaretPaintEntry entry) visitor) {
    var probes = 1;
    if (_mayPaintCaret(primaryCaret, lineStart, lineEnd)) visitor(primaryCaret);

    var lower = 0;
    var upper = secondaryCarets.length;
    while (lower < upper) {
      probes++;
      final middle = lower + ((upper - lower) >> 1);
      if (secondaryCarets[middle].position.offset < lineStart) {
        lower = middle + 1;
      } else {
        upper = middle;
      }
    }
    for (var index = lower; index < secondaryCarets.length; index++) {
      probes++;
      final entry = secondaryCarets[index];
      if (entry.position.offset > lineEnd) break;
      visitor(entry);
    }
    return probes;
  }

  static bool _sameCaret(_SelectionCaretPaintEntry left, _SelectionCaretPaintEntry right) =>
      left.position.offset == right.position.offset && left.position.affinity == right.position.affinity;

  static bool _mayPaintCaret(_SelectionCaretPaintEntry entry, int lineStart, int lineEnd) =>
      entry.position.offset >= lineStart && entry.position.offset <= lineEnd;

  static bool _mayPaint(EditableSelection selection, int lineStart, int lineEnd) =>
      selection.start <= lineEnd && (selection.isCollapsed ? selection.end >= lineStart : selection.end > lineStart);
}

/// 仅在超长行路径首次命中时分配的窗口、Bidi 与 Tab 渲染缓存。
///
/// 空文本与普通短 soft-wrap 输入只需要核心行表和测量器，不应为从未使用的
/// Bidi、Tab 与长行窗口预建二十余个 Map/Set；短 nowrap 行另付一个宽度表。
final class _EditableLongLineRenderState {
  final Set<Object> longLineViewportRefreshPending = <Object>{};
  final Map<Object, EditableLineLayoutWindow?> longLineVisualRefreshPending = <Object, EditableLineLayoutWindow?>{};
  final Map<Object, int> longLineBidiHydrationChunksThisFrame = <Object, int>{};
  final Set<Object> deferredLongLineHydration = <Object>{};
  final Map<Object, _EditableLongLineCoverage> longLineCoverages = <Object, _EditableLongLineCoverage>{};
  final Map<Object, double> longLineAverageAdvances = <Object, double>{};
  final Map<Object, _EditableLongLineWidthModel> longLineWidthModels = <Object, _EditableLongLineWidthModel>{};
  final Map<Object, _EditableLongLineTabPrefix> longLineTabPrefixes = <Object, _EditableLongLineTabPrefix>{};
  final Map<Object, _EditableLongLineTabBatchProgress> longLineTabBatchPrefixes =
      <Object, _EditableLongLineTabBatchProgress>{};
  final Map<Object, LongLineBidiPipeline> longLineBidiPipelines = <Object, LongLineBidiPipeline>{};
  final Map<Object, _EditableLongLineEstimateProgress> longLineBidiEstimateRevisions =
      <Object, _EditableLongLineEstimateProgress>{};
  final Map<Object, int> longLineBidiGenerations = <Object, int>{};
  final Map<Object, int> longLineVisualMetricRevisions = <Object, int>{};
  final Map<Object, ({double insert, double overwrite})> longLineVisualTrailingExtents =
      <Object, ({double insert, double overwrite})>{};
  final Set<Object> pendingLongLineBidiResolves = <Object>{};
  final Set<LongLineBidiPipeline> activeLongLineBidiResolves = <LongLineBidiPipeline>{};
  final Set<LongLineBidiPipeline> executorLongLineBidiResolves = <LongLineBidiPipeline>{};
  final Map<Object, int> longLineBidiFailureAttempts = <Object, int>{};
  final Map<Object, Object> longLineBidiTerminalErrors = <Object, Object>{};
  final Set<Object> longLineBidiRetryScheduled = <Object>{};
  final Set<Object> longLineBidiSafePrefixIdentities = <Object>{};
  final Map<TextStyle, double> longLineStyledSpaceAdvances = <TextStyle, double>{};
}

/// 渲染协调器：controller 状态 → 行渲染的唯一读取门面 + 布局查询实现。
///
/// 职责边界：
/// - 对 [RenderEditableLine]：提供行文本 / 行绘制快照 / 共享配置，并作为统一的
///   变化通知源（controller visual 通道、caret 接管、配置变更都折叠成一次
///   [notifyListeners]，行侧自行 diff 决定 relayout / repaint / 不动）。
/// - 对编辑操作层：实现 [EditableLayoutQuery]（doc offset ↔ 行内几何），mounted
///   行直接借用其已排版 painter，未 mounted 行用共享测量 painter 现排。
/// - 维护 mounted 行注册表，供视图层做指针命中与 caret 可见性判定。
///
/// 本类不持有 widget / element，也不订阅 controller——由 [ElEditableView] State
/// 负责把外部变化泵入（[pump]）并管理生命周期。
class EditableRenderScope extends ChangeNotifier implements EditableLayoutQuery {
  /// 单个超长行 Paragraph 的 UTF-16 硬上限。
  static const int longLineParagraphCodeUnitLimit = 64 * 1024;

  /// 同一渲染帧全部超长行正文窗口的累计读取硬上限。
  static const int longLineViewportReadCodeUnitLimit = 1024 * 1024;

  /// 同一渲染帧视觉 tile 估值允许执行的保守基础操作数，仅供白盒预算断言。
  @visibleForTesting
  static const int longLineVisualEstimateFrameWorkLimit = 64 * 1024;

  /// 同一渲染帧视觉 tile 估值允许分配的 Map 条目数，仅供白盒预算断言。
  @visibleForTesting
  static const int longLineVisualEstimateFrameAllocationLimit = 128;

  static const int _shortLineBatchMaxLines = 64;
  static const int _shortLineBatchCodeUnitLimit = longLineParagraphCodeUnitLimit;
  static const int _longLineWindowCodeUnits = 8 * 1024;
  static const int _longLineBoundaryGuardCodeUnits = 128;
  static const int _longLineShapingHaloCodeUnits = _longLineBoundaryGuardCodeUnits;
  static const int _defaultLongLineBidiPipelineMaxEntries = 64;
  static const int _defaultLongLineBidiPipelineMaxRetainedBytes = 192 * 1024 * 1024;
  static const int _longLineBidiMaxConcurrentResolves = 2;
  static const int _longLineBidiMaxBackgroundAttempts = 3;

  /// 创建只持有编辑模型与渲染缓存、不接管 widget 生命周期的行协调器。
  EditableRenderScope({
    required this.controller,
    required EditableRenderConfig config,
    this.lineProjection,
    this.onInlineLayoutChanged,
    int longLineBidiPipelineMaxEntries = _defaultLongLineBidiPipelineMaxEntries,
    int longLineBidiPipelineMaxRetainedBytes = _defaultLongLineBidiPipelineMaxRetainedBytes,

    /// 白盒测试可替换后台解析入口以验证失败与重试状态机。
    @visibleForTesting
    Future<LongLineBidiPipelineResult> Function(LongLineBidiPipeline pipeline)? longLineBidiResolverForTesting,

    /// 白盒测试可缩小逐帧正文读取预算以稳定覆盖 blocked 重试。
    @visibleForTesting int longLineViewportReadCodeUnitLimitForTesting = longLineViewportReadCodeUnitLimit,
  }) : assert(longLineBidiPipelineMaxEntries > 0),
       assert(longLineBidiPipelineMaxRetainedBytes > 0),
       assert(longLineViewportReadCodeUnitLimitForTesting >= _longLineWindowCodeUnits),
       _longLineBidiPipelineMaxEntries = longLineBidiPipelineMaxEntries,
       _longLineBidiPipelineMaxRetainedBytes = longLineBidiPipelineMaxRetainedBytes,
       _longLineBidiResolverForTesting = longLineBidiResolverForTesting,
       _longLineViewportReadCodeUnitLimit = longLineViewportReadCodeUnitLimitForTesting,
       _config = config,
       _knownWidthPresentationRevision = controller.presentationRevision,
       _knownWidthOverwriteMode = controller.overwriteMode {
    _systemFontsListenable = _systemFontsIfInitialized();
    _systemFontsListenable?.addListener(_scheduleSystemFontsUpdate);
  }

  final EditableController controller;

  /// 当前导航查询使用的可见行投影；只借用，可热换且不接管生命周期。
  EditableLineProjection? lineProjection;

  EditableRenderConfig _config;
  final int _longLineBidiPipelineMaxEntries;
  final int _longLineBidiPipelineMaxRetainedBytes;
  final Future<LongLineBidiPipelineResult> Function(LongLineBidiPipeline pipeline)? _longLineBidiResolverForTesting;
  final int _longLineViewportReadCodeUnitLimit;
  int _configRevision = 0;
  int _systemFontsRevision = 0;
  bool _systemFontsUpdateScheduled = false;
  bool _disposed = false;
  Listenable? _systemFontsListenable;

  bool _focused = false;
  bool _regularCaretVisible = true;
  bool _primaryCaretMotionActive = false;
  bool _paintEditingState = true;
  bool _selectionVisible = true;

  /// 全文档选区时光标是否保持画在全选前的位置（selectAllRevealsCaret=false）
  bool _keepCaretAtPreSelectAllPosition = false;
  Object? _dragDropCaretOwner;
  TextPosition? _dragDropCaret;

  /// 行排版可用宽度（wrap 上界）。由行渲染在 layout 时回写，测量 painter 与
  /// mounted painter 用同一宽度保证几何一致。
  double _layoutWidth = double.infinity;
  double _layoutMinWidth = 0.0;
  double _viewportWidth = 0.0;
  double _horizontalPixels = 0.0;
  int _longLineWindowRevision = 0;
  bool _longLineVisualRefreshScheduled = false;
  bool _longLineReadBudgetFrameActive = false;
  bool _longLineIdleReadBudgetEpochActive = false;
  int _longLineReadBudgetRemaining = 0;
  int _longLineHydrationRotation = 0;
  bool _deferredLongLineHydrationScheduled = false;
  int _nextLongLineBidiGeneration = 0;
  TextPainter? _longLinePrototypePainter;
  int _longLinePrototypeConfigRevision = -1;
  int _longLinePrototypeSystemFontsRevision = -1;
  double? _longLineSpaceAdvance;

  /// nowrap 下已测行宽的有界候选集；正文宽与 insert/overwrite 尾距分开保留，
  /// 模式热切换只换尾距，不会把已滚离的最长正文整行忘掉。
  static const int _knownLineWidthCapacity = 512;
  _EditableLongLineRenderState? _longLineState;
  Map<Object, _EditableKnownLineWidth>? _knownLineWidthsState;

  _EditableLongLineRenderState get _longLineStateForWrite => _longLineState ??= _EditableLongLineRenderState();

  Set<Object> get _longLineViewportRefreshPending => _longLineStateForWrite.longLineViewportRefreshPending;
  Map<Object, EditableLineLayoutWindow?> get _longLineVisualRefreshPending =>
      _longLineStateForWrite.longLineVisualRefreshPending;
  Map<Object, int> get _longLineBidiHydrationChunksThisFrame =>
      _longLineStateForWrite.longLineBidiHydrationChunksThisFrame;
  Set<Object> get _deferredLongLineHydration => _longLineStateForWrite.deferredLongLineHydration;
  Map<Object, _EditableLongLineCoverage> get _longLineCoverages => _longLineStateForWrite.longLineCoverages;
  Map<Object, double> get _longLineAverageAdvances => _longLineStateForWrite.longLineAverageAdvances;
  Map<Object, _EditableLongLineWidthModel> get _longLineWidthModels => _longLineStateForWrite.longLineWidthModels;
  Map<Object, _EditableLongLineTabPrefix> get _longLineTabPrefixes => _longLineStateForWrite.longLineTabPrefixes;
  Map<Object, _EditableLongLineTabBatchProgress> get _longLineTabBatchPrefixes =>
      _longLineStateForWrite.longLineTabBatchPrefixes;
  Map<Object, LongLineBidiPipeline> get _longLineBidiPipelines => _longLineStateForWrite.longLineBidiPipelines;
  Map<Object, _EditableLongLineEstimateProgress> get _longLineBidiEstimateRevisions =>
      _longLineStateForWrite.longLineBidiEstimateRevisions;
  Map<Object, int> get _longLineBidiGenerations => _longLineStateForWrite.longLineBidiGenerations;
  Map<Object, int> get _longLineVisualMetricRevisions => _longLineStateForWrite.longLineVisualMetricRevisions;
  Map<Object, ({double insert, double overwrite})> get _longLineVisualTrailingExtents =>
      _longLineStateForWrite.longLineVisualTrailingExtents;
  Set<Object> get _pendingLongLineBidiResolves => _longLineStateForWrite.pendingLongLineBidiResolves;
  Set<LongLineBidiPipeline> get _activeLongLineBidiResolves => _longLineStateForWrite.activeLongLineBidiResolves;
  Set<LongLineBidiPipeline> get _executorLongLineBidiResolves => _longLineStateForWrite.executorLongLineBidiResolves;
  Map<Object, int> get _longLineBidiFailureAttempts => _longLineStateForWrite.longLineBidiFailureAttempts;
  Map<Object, Object> get _longLineBidiTerminalErrors => _longLineStateForWrite.longLineBidiTerminalErrors;
  Set<Object> get _longLineBidiRetryScheduled => _longLineStateForWrite.longLineBidiRetryScheduled;
  Set<Object> get _longLineBidiSafePrefixIdentities => _longLineStateForWrite.longLineBidiSafePrefixIdentities;
  Map<TextStyle, double> get _longLineStyledSpaceAdvances => _longLineStateForWrite.longLineStyledSpaceAdvances;
  Map<Object, _EditableKnownLineWidth> get _knownLineWidths =>
      _knownLineWidthsState ??= <Object, _EditableKnownLineWidth>{};

  /// nowrap 虚拟内容消费的持久交叉轴尺寸下限。
  ValueNotifier<double> get minimumCrossAxisExtent {
    if (_disposed && _minimumCrossAxisExtent == null) {
      throw StateError('EditableRenderScope 已释放，不能再创建 minimumCrossAxisExtent。');
    }
    return _minimumCrossAxisExtent ??= ValueNotifier<double>(0.0);
  }

  ValueNotifier<double>? _minimumCrossAxisExtent;
  int _knownWidthPresentationRevision;
  bool _knownWidthOverwriteMode;

  final Map<int, RenderEditableLine> _mounted = {};
  int _lineTextBatchDocRevision = -1;
  int _lineTextBatchStart = -1;
  List<String> _lineTextBatch = const <String>[];
  int _debugLineTextBatchBuildCount = 0;
  int _debugLineTextBatchReuseCount = 0;

  EditableSelectionSet? _selectionPaintIndexSource;
  _SelectionPaintIndex? _selectionPaintIndex;
  EditableLineProjection? _selectionPaintIndexProjection;
  int _selectionPaintIndexDocRevision = -1;
  int _selectionPaintIndexProjectionRevision = -1;
  int _debugLastSelectionQueryProbeCount = 0;
  int _debugLastSelectionIndexBuildProbeCount = 0;
  int _debugLastLongLineCoverageProbeCount = 0;
  int _debugLastLongLineTabPrefixProbeCount = 0;
  int _debugMaxLongLineTabPrefixProbeCount = 0;
  int _debugLastLongLineTabLookupProbeCount = 0;
  int _debugMaxLongLineTabLookupProbeCount = 0;
  int _debugLongLineTabLookupBlockedCount = 0;
  int _longLineVisualEstimateWorkRemaining = longLineVisualEstimateFrameWorkLimit;
  int _longLineVisualEstimateAllocationRemaining = longLineVisualEstimateFrameAllocationLimit;
  int _debugCurrentFrameLongLineVisualEstimateWork = 0;
  int _debugMaxFrameLongLineVisualEstimateWork = 0;
  int _debugCurrentFrameLongLineVisualEstimateAllocations = 0;
  int _debugMaxFrameLongLineVisualEstimateAllocations = 0;
  int _debugLongLineVisualHaloMeasurementCount = 0;

  TextPainter? _measurePainter;
  int _measureLine = -1;
  int _measureDocRevision = -1;
  int _measurePresentationRevision = -1;
  int _measureConfigRevision = -1;
  TextRange _measureComposing = TextRange.empty;
  int _measureInlineRevision = -1;
  int _inlineSizeRevision = 0;
  double _measureMinWidth = 0.0;
  double _measureWidth = double.infinity;
  EditableLineMetrics? _resolvedFixedLineMetrics;
  int _resolvedFixedLineMetricsConfigRevision = -1;
  int _resolvedFixedLineMetricsSystemFontsRevision = -1;
  StrutStyle? _contentBaseStrutStyle;

  /// 共享配置。
  EditableRenderConfig get config => _config;

  /// 当前是否采用不受正文 run 影响的固定视觉行度量。
  bool get usesFixedLineHeight =>
      _config.lineHeightMode == EditableLineHeightMode.fixed || controller.inlineContent.isNotEmpty;

  /// 内嵌组件尺寸改变后同步光标和平台输入法几何。
  final VoidCallback? onInlineLayoutChanged;
  Map<String, Size>? _inlineSizeEstimates;

  /// 未挂载占位符使用同 token 的最近实测值，首次退回一行高的方形估计。
  Size inlineEstimatedSize(String token) {
    return _inlineSizeEstimates?[token] ?? Size.square(fixedLineHeight);
  }

  /// 尺寸只是视口外估计；各出现位置仍保留自己的实测宽度。
  void rememberInlineSize(String token, Size size) {
    if (_inlineSizeEstimates?[token] == size) return;
    (_inlineSizeEstimates ??= {})[token] = size;
    _inlineSizeRevision++;
  }

  /// 滚动只刷新已挂载的内嵌内容行。
  void refreshInlineViewport() {
    if (controller.inlineContent.isEmpty || _disposed) return;
    for (final line in _mounted.values) {
      line.refreshInlineViewport();
    }
  }

  /// 固定模式下由基础文本样式一次解析出的统一视觉行高。
  double get fixedLineHeight => _resolveFixedLineMetrics().height;

  /// 固定模式下由基础文本样式一次解析出的统一行顶到基线距离。
  double get fixedBaseline => _resolveFixedLineMetrics().baseline;

  /// 复用固定行度量，补偿正文实际行盒的基线与物理像素取整。
  double fixedTextPaintOffset(double layoutHeight, double textHeight) =>
      _resolveFixedLineMetrics().textPaintOffset(layoutHeight, textHeight: textHeight);

  /// TextPainter 使用的行 strut；固定模式忽略 composer 根 run 的纵向样式。
  StrutStyle strutStyleFor(InlineSpan span) {
    if (usesFixedLineHeight) return _resolveFixedLineMetrics().strutStyle;
    final style = span.style ?? _config.textStyle;
    if (style == _config.textStyle) {
      return _contentBaseStrutStyle ??= StrutStyle.fromTextStyle(_config.textStyle);
    }
    return StrutStyle.fromTextStyle(style);
  }

  /// 选区盒的纵向口径；固定模式严格落在 strut 行带内。
  ui.BoxHeightStyle get selectionBoxHeightStyle =>
      usesFixedLineHeight ? ui.BoxHeightStyle.strut : ui.BoxHeightStyle.max;

  /// 内部选区背景的连续行带口径，不改变交互几何的精确盒。
  ui.BoxHeightStyle get selectionPaintBoxHeightStyle =>
      usesFixedLineHeight ? ui.BoxHeightStyle.strut : ui.BoxHeightStyle.includeLineSpacingMiddle;

  EditableLineMetrics _resolveFixedLineMetrics() {
    final cached = _resolvedFixedLineMetrics;
    if (cached != null &&
        _resolvedFixedLineMetricsConfigRevision == _configRevision &&
        _resolvedFixedLineMetricsSystemFontsRevision == _systemFontsRevision) {
      return cached;
    }

    final resolved = EditableLineMetrics.resolve(
      _config.textStyle,
      textDirection: _config.textDirection,
      textScaler: _config.textScaler,
    );
    _resolvedFixedLineMetrics = resolved;
    _resolvedFixedLineMetricsConfigRevision = _configRevision;
    _resolvedFixedLineMetricsSystemFontsRevision = _systemFontsRevision;
    return resolved;
  }

  /// 配置修订号，行渲染据此判断是否需要整体 relayout。
  int get configRevision => _configRevision;

  /// 系统字体表修订号，行渲染据此丢弃已经 shape 的 Paragraph。
  int get systemFontsRevision => _systemFontsRevision;

  /// 编辑器是否持有焦点；只决定 caret，失焦选区背景继续保留。
  bool get focused => _focused;

  /// 普通行内 caret 是否可见；浮动光标会暂时接管并关闭它。
  bool get regularCaretVisible => _regularCaretVisible;

  /// 主细线 caret 是否正由编辑器级位置动画层接管。
  bool get primaryCaretMotionActive => _primaryCaretMotionActive;

  /// 当前是否绘制编辑器内部选区、光标、组合文本与拖放落点。
  bool get paintEditingState => _paintEditingState;

  /// 当前文本拖放的唯一临时落点；null 表示不绘制落点 caret。
  TextPosition? get dragDropCaret => _dragDropCaret;

  /// 当前临时落点的所有者 identity；旧会话只能清理自己创建的 caret。
  Object? get dragDropCaretOwner => _dragDropCaretOwner;

  /// 编辑器扣除内容 padding 后的可见宽度，供 nowrap 短行撑开对齐。
  double get viewportWidth => _viewportWidth;

  /// nowrap 横向视口在完整内容盒中的起点。
  double get horizontalPixels => _horizontalPixels;

  /// 超长行窗口修订号；只在视口离开既有有界窗口时递增。
  int get longLineWindowRevision => _longLineWindowRevision;

  /// 当前 scope 累计创建的长行缓存数；惰性 capsule 使其只能为 0 或 1。
  @visibleForTesting
  int get debugLongLineStateCreationCount => _longLineState == null ? 0 : 1;

  /// 当前 scope 累计创建的 nowrap 宽度索引数；惰性缓存使其只能为 0 或 1。
  @visibleForTesting
  int get debugKnownLineWidthsCreationCount => _knownLineWidthsState == null ? 0 : 1;

  /// 当前 scope 累计创建的 nowrap 交叉轴通知器数；惰性缓存使其只能为 0 或 1。
  @visibleForTesting
  int get debugMinimumCrossAxisExtentCreationCount => _minimumCrossAxisExtent == null ? 0 : 1;

  /// 连续短行缓存从 piece tree 建立批次的次数。
  @visibleForTesting
  int get debugLineTextBatchBuildCount => _debugLineTextBatchBuildCount;

  /// 连续短行缓存命中已有字符串的次数。
  @visibleForTesting
  int get debugLineTextBatchReuseCount => _debugLineTextBatchReuseCount;

  /// 当前连续短行缓存保留的行数。
  @visibleForTesting
  int get debugLineTextBatchCachedLineCount => _lineTextBatch.length;

  /// 指定 mounted 长行是否仍等待 visual width 触发的新窗口完成布局上报。
  bool longLineVisualRefreshPendingFor(int line) {
    final identity = _mounted[line]?.identity;
    return identity != null && (_longLineState?.longLineVisualRefreshPending.containsKey(identity) ?? false);
  }

  /// 指定长行是否仍在占位、水合、后台解析或 visual 测宽换代阶段。
  bool longLineGeometryPendingFor(int line) {
    final render = _mounted[line];
    final identity = render?.identity;
    if (identity == null || !usesWindowedLineLayout(line)) return false;
    if (_longLineBidiTerminalErrors.containsKey(identity)) return false;
    if (render?.layoutWindow?.placeholder ?? false) return true;
    if (render?.windowPainter == null) return true;
    if (_deferredLongLineHydration.contains(identity) ||
        _pendingLongLineBidiResolves.contains(identity) ||
        _longLineViewportRefreshPending.contains(identity) ||
        _longLineVisualRefreshPending.containsKey(identity)) {
      return true;
    }
    final pipeline = _longLineBidiPipelines[identity];
    if (pipeline == null || !pipeline.debugResolved) return pipeline != null;
    if (pipeline.debugTileCount == 0) return false;
    return _longLineBidiEstimateRevisions[identity]?.complete != true;
  }

  /// 指定 caret 的全局横坐标是否仍依赖尚未校准的长行视觉前缀。
  ///
  /// 与 [longLineGeometryPendingFor] 的整行口径不同，本查询只等待当前真实窗口
  /// 原点之前的连续 tile；左起对齐下，窗口之后的离屏后缀不会再改变 caret x。
  bool longLineCaretGeometryPendingFor(int line, TextPosition documentPosition) {
    final render = _mounted[line];
    final identity = render?.identity;
    if (render == null || identity == null || !usesWindowedLineLayout(line)) return false;
    if (_longLineBidiTerminalErrors.containsKey(identity)) return false;
    final window = render.layoutWindow;
    if (window == null || window.placeholder) return true;
    if (_longLineViewportRefreshPending.contains(identity)) return true;

    final lineStart = controller.document.lineStart(line);
    final lineLength = controller.document.lineLength(line);
    final localPosition = TextPosition(
      offset: (documentPosition.offset - lineStart).clamp(0, lineLength),
      affinity: documentPosition.affinity,
    );
    if (!window.containsPosition(localPosition)) return true;

    final pipeline = _longLineBidiPipelines[identity];
    if (pipeline == null) return false;
    final result = pipeline.resolvedResultOrNull;
    if (result == null) return true;
    if (result.visualIndex.tiles.isEmpty) return false;
    if (!window.isVisual ||
        window.visualGeneration != _longLineBidiGenerations[identity] ||
        window.visualMetricRevision != (_longLineVisualMetricRevisions[identity] ?? 0)) {
      return true;
    }
    final progress = _longLineBidiEstimateRevisions[identity];
    if (progress == null) return true;
    final alignmentNeedsTotal = switch (_config.textAlign) {
      TextAlign.left => false,
      TextAlign.right || TextAlign.center => true,
      TextAlign.start || TextAlign.justify => _config.textDirection == TextDirection.rtl,
      TextAlign.end => _config.textDirection == TextDirection.ltr,
    };
    if (alignmentNeedsTotal && !progress.complete) return true;
    return progress.globalNextTile < window.visualFirstTile;
  }

  /// 长行 caret 几何等待的进展令牌；仅连续相同令牌才可计作停滞。
  Object? longLineCaretGeometryProgressTokenFor(int line) {
    final render = _mounted[line];
    final identity = render?.identity;
    if (render == null || identity == null || !usesWindowedLineLayout(line)) return null;
    final pipeline = _longLineBidiPipelines[identity];
    final progress = _longLineBidiEstimateRevisions[identity];
    final window = render.layoutWindow;
    return (
      identity: identity,
      generation: _longLineBidiGenerations[identity],
      pipelineReady: pipeline?.debugReady,
      pipelineResolved: pipeline?.debugResolved,
      globalNextTile: progress?.globalNextTile,
      tileCount: progress?.tileCount,
      visualMetricRevision: _longLineVisualMetricRevisions[identity],
      windowGeneration: window?.visualGeneration,
      windowMetricRevision: window?.visualMetricRevision,
      windowFirstTile: window?.visualFirstTile,
      windowEndTile: window?.visualEndTile,
      placeholder: window?.placeholder,
      hasPainter: render.windowPainter != null,
      viewportPending: _longLineViewportRefreshPending.contains(identity),
      terminal: _longLineBidiTerminalErrors.containsKey(identity),
    );
  }

  /// 最近一次 [paintStateOf] 行查询检查的索引节点数，供复杂度回归测试。
  @visibleForTesting
  int get debugLastSelectionQueryProbeCount => _debugLastSelectionQueryProbeCount;

  /// 最近一次 [paintStateOf] 为新选区 identity 建立索引时执行的常量工作量。
  @visibleForTesting
  int get debugLastSelectionIndexBuildProbeCount => _debugLastSelectionIndexBuildProbeCount;

  /// 当前仅为 mounted 超长行保留的横向 coverage 数。
  @visibleForTesting
  int get debugLongLineCoverageCount => _longLineState?.longLineCoverages.length ?? 0;

  /// 与有界宽度历史同寿命的超长行分块宽度模型数。
  @visibleForTesting
  int get debugLongLineWidthModelCount => _longLineState?.longLineWidthModels.length ?? 0;

  /// 某长行宽度模型当前保留的分块数。
  @visibleForTesting
  int debugLongLineWidthChunkCount(Object identity) => _longLineState?.longLineWidthModels[identity]?.index.length ?? 0;

  /// 某长行 tab/bidi 增量索引已证明的逻辑前缀终点。
  @visibleForTesting
  int debugLongLinePrefixScannedUntil(Object identity) =>
      _longLineState?.longLineTabPrefixes[identity]?.scannedUntil ?? 0;

  /// 当前 bidi 管线数量、估算保留字节与后台解析并发。
  @visibleForTesting
  ({int pipelines, int retainedBytes, int resolving, int executorInFlight}) get debugLongLineBidiCacheState {
    final state = _longLineState;
    final pipelines = state?.longLineBidiPipelines;
    return (
      pipelines: pipelines?.length ?? 0,
      retainedBytes: pipelines == null
          ? 0
          : pipelines.values.fold<int>(0, (total, pipeline) => total + pipeline.debugRetainedBytes),
      resolving: state?.activeLongLineBidiResolves.length ?? 0,
      executorInFlight: state?.executorLongLineBidiResolves.length ?? 0,
    );
  }

  /// 尚未开始的长行 bidi 解析数量；卸载行必须立即从该队列移除。
  @visibleForTesting
  int get debugPendingLongLineBidiResolveCount => _longLineState?.pendingLongLineBidiResolves.length ?? 0;

  /// 某长行 bidi 管线的水合/后台解析状态。
  @visibleForTesting
  ({int loaded, bool ready, bool resolving, bool resolved, int retainedBytes, double extent}) debugLongLineBidiState(
    Object identity,
  ) {
    final pipeline = _longLineState?.longLineBidiPipelines[identity];
    return (
      loaded: pipeline?.debugLoadedCodeUnits ?? 0,
      ready: pipeline?.debugReady ?? false,
      resolving: pipeline?.debugResolving ?? false,
      resolved: pipeline?.debugResolved ?? false,
      retainedBytes: pipeline?.debugRetainedBytes ?? 0,
      extent: pipeline?.resolvedResultOrNull?.visualIndex.totalExtent ?? 0.0,
    );
  }

  /// 某原文 offset 的视觉 tile/caret 定位，仅供严格几何测试。
  @visibleForTesting
  ({double x, int tile, int start, int end, bool rtl})? debugLongLineBidiCaret(
    Object identity,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    final visual = _longLineState?.longLineBidiPipelines[identity]?.resolvedResultOrNull?.visualIndex;
    final caret = visual?.locateOffset(offset, affinity: affinity);
    if (visual == null || caret == null) return null;
    final tile = visual.tiles[caret.tileIndex];
    return (
      x: caret.visualX + _longLineVisualAlignmentShift(visual.totalExtent, identity),
      tile: caret.tileIndex,
      start: tile.start,
      end: tile.end,
      rtl: tile.isRtl,
    );
  }

  /// 某 identity 当前 bidi pipeline 内容代际；未保留时为零。
  @visibleForTesting
  int debugLongLineBidiGeneration(Object identity) => _longLineState?.longLineBidiGenerations[identity] ?? 0;

  /// 某 identity 当前 visual tile 数；未解析或未保留时为零。
  @visibleForTesting
  int debugLongLineBidiTileCount(Object identity) =>
      _longLineState?.longLineBidiPipelines[identity]?.debugTileCount ?? 0;

  /// 某 visual tile 是否已经收到拥有完整窗口上下文的 Paragraph 实测宽度。
  @visibleForTesting
  bool debugLongLineBidiTileMeasured(Object identity, int tileIndex) {
    final visual = _longLineState?.longLineBidiPipelines[identity]?.resolvedResultOrNull?.visualIndex;
    if (visual == null || tileIndex < 0 || tileIndex >= visual.tiles.length) return false;
    return visual.isMeasured(tileIndex);
  }

  /// 最近一次横向视口更新检查的 coverage 数。
  @visibleForTesting
  int get debugLastLongLineCoverageProbeCount => _debugLastLongLineCoverageProbeCount;

  /// 最近一次长行 tab 前缀扫描访问的 UTF-16 数，供线性复杂度回归。
  @visibleForTesting
  int get debugLastLongLineTabPrefixProbeCount => _debugLastLongLineTabPrefixProbeCount;

  /// scope 生命周期内任一次长行 tab 前缀扫描的最大线性探针数。
  @visibleForTesting
  int get debugMaxLongLineTabPrefixProbeCount => _debugMaxLongLineTabPrefixProbeCount;

  /// 某长行分页 tab 前缀索引的检查点数量与确定性保留字节。
  @visibleForTesting
  ({int checkpoints, int retainedBytes}) debugLongLineTabPrefixState(Object identity) {
    final state = _longLineState?.longLineTabPrefixes[identity];
    return (checkpoints: state?.checkpointCount ?? 0, retainedBytes: state?.retainedBytes ?? 0);
  }

  /// 最近一次随机 tab 前缀查询顺序检查的 UTF-16 数。
  @visibleForTesting
  int get debugLastLongLineTabLookupProbeCount => _debugLastLongLineTabLookupProbeCount;

  /// scope 生命周期内单次随机 tab 前缀查询的最大 UTF-16 探针数。
  @visibleForTesting
  int get debugMaxLongLineTabLookupProbeCount => _debugMaxLongLineTabLookupProbeCount;

  /// scope 生命周期内因逐帧读取预算不足而阻塞的 tab 随机查询次数。
  @visibleForTesting
  int get debugLongLineTabLookupBlockedCount => _debugLongLineTabLookupBlockedCount;

  /// 某 visual 索引的全局估值游标与当前窗口优先游标。
  @visibleForTesting
  ({int calibrated, int total, int priorityNext, bool complete}) debugLongLineVisualEstimateState(Object identity) {
    final progress = _longLineState?.longLineBidiEstimateRevisions[identity];
    return (
      calibrated: progress?.globalNextTile ?? 0,
      total: progress?.tileCount ?? 0,
      priorityNext: progress?.priorityNextTile ?? 0,
      complete: progress?.complete ?? false,
    );
  }

  /// 返回逻辑前缀的精确值与预算状态，供全局 visual extent 白盒校验。
  @visibleForTesting
  ({double x, bool exact}) debugLongLineLogicalX(Object identity, int line, int offset) {
    final state = _longLineState;
    final widthModel = state?.longLineWidthModels[identity];
    if (widthModel == null) return (x: 0.0, exact: false);
    final lineLength = controller.document.lineLength(line);
    final tabState = _validLongLineTabPrefix(
      identity,
      widthModel,
      state!.longLineAverageAdvances[identity] ?? _prototypeCodeUnitAdvance(),
    );
    return _longLineLogicalXLookup(identity, line, widthModel, tabState, offset.clamp(0, lineLength), lineLength);
  }

  /// 任一渲染帧 visual tile 估值执行的最大保守基础操作数。
  @visibleForTesting
  int get debugMaxFrameLongLineVisualEstimateWork => _debugMaxFrameLongLineVisualEstimateWork;

  /// 任一渲染帧 visual tile 估值分配的最大 Map 条目数。
  @visibleForTesting
  int get debugMaxFrameLongLineVisualEstimateAllocations => _debugMaxFrameLongLineVisualEstimateAllocations;

  /// scope 生命周期内为窗口边缘 tile 建立 measurement-only shaping halo 的次数。
  @visibleForTesting
  int get debugLongLineVisualHaloMeasurementCount => _debugLongLineVisualHaloMeasurementCount;

  /// 某长行后台解析的连续失败、重试与终止状态。
  @visibleForTesting
  ({int attempts, bool retryScheduled, bool terminal}) debugLongLineBidiFailureState(Object identity) {
    final state = _longLineState;
    return (
      attempts: state?.longLineBidiFailureAttempts[identity] ?? 0,
      retryScheduled: state?.longLineBidiRetryScheduled.contains(identity) ?? false,
      terminal: state?.longLineBidiTerminalErrors.containsKey(identity) ?? false,
    );
  }

  /// 在祖先 layout 尚未布局行节点前种入首帧宽度，不同步通知后代。
  ///
  /// RenderObject 在 `performLayout` 中通知 scope 会让已挂载行调用
  /// `markNeedsLayout`，违反 Flutter 的祖先布局期变异约束。这里只允许从零
  /// 初始化；布局后的真实 scroll viewport 会在帧尾经 [setViewportWidth]
  /// 校正，有差异才发布通知，热 resize 也统一走帧尾通知。
  void seedInitialViewportWidth(double value) {
    if (_viewportWidth > precisionErrorTolerance) return;
    final next = value.isFinite ? math.max(0.0, value) : 0.0;
    if (next <= precisionErrorTolerance) return;
    _viewportWidth = next;
  }

  /// 更新编辑器可见宽度；真实变化会让 mounted/shared painter 使用同一布局宽。
  void setViewportWidth(double value) {
    setHorizontalViewport(pixels: _horizontalPixels, width: value);
  }

  /// 原子更新 nowrap 横向视口；短行滚动不会触发行正文重排。
  void setHorizontalViewport({required double pixels, required double width}) {
    final nextPixels = pixels.isFinite ? math.max(0.0, pixels) : 0.0;
    final nextWidth = width.isFinite ? math.max(0.0, width) : 0.0;
    final widthChanged = (_viewportWidth - nextWidth).abs() > precisionErrorTolerance;
    final pixelsChanged = (_horizontalPixels - nextPixels).abs() > precisionErrorTolerance;
    if (!widthChanged && !pixelsChanged) return;

    _horizontalPixels = nextPixels;
    _viewportWidth = nextWidth;
    var windowChanged = false;
    _debugLastLongLineCoverageProbeCount = 0;
    final state = _longLineState;
    if (state != null &&
        pixelsChanged &&
        state.longLineViewportRefreshPending.isEmpty &&
        state.longLineCoverages.isNotEmpty) {
      for (final coverage in state.longLineCoverages.values) {
        _debugLastLongLineCoverageProbeCount++;
        if (coverage.containsViewport(nextPixels, nextWidth)) continue;
        windowChanged = true;
        break;
      }
    }
    if (widthChanged) _configRevision++;
    if (widthChanged) _publishKnownLineWidthMaximum();
    if (windowChanged) {
      state!.longLineViewportRefreshPending.addAll(state.longLineCoverages.keys);
      _longLineWindowRevision++;
    }
    if (widthChanged || windowChanged) notifyListeners();
  }

  /// 以 [owner] identity 更新唯一文本拖放落点，不修改控制器真实选区。
  void setDragDropCaret({required Object owner, required TextPosition value}) {
    final next = TextPosition(offset: value.offset.clamp(0, controller.document.length), affinity: value.affinity);
    if (identical(_dragDropCaretOwner, owner) && _dragDropCaret == next) return;
    _dragDropCaretOwner = owner;
    _dragDropCaret = next;
    notifyListeners();
  }

  /// 仅当 [owner] 仍拥有临时落点时清除，避免迟到终态误删新会话 caret。
  void clearDragDropCaret(Object owner) {
    if (!identical(_dragDropCaretOwner, owner)) return;
    _dragDropCaretOwner = null;
    _dragDropCaret = null;
    notifyListeners();
  }

  /// 由 State 泵入变化：配置、焦点、caret 接管或内部编辑状态绘制门
  /// 任一真实变化才通知；每帧 build 里重算 config 传入是安全的（无变化零通知）。
  void pump({
    EditableRenderConfig? config,
    bool? focused,
    bool? regularCaretVisible,
    bool? primaryCaretMotionActive,
    bool? paintEditingState,
    bool? selectionVisible,
    bool? keepCaretAtPreSelectAllPosition,
  }) {
    var changed = false;
    if (config != null && config != _config) {
      final layoutChanged = !config.hasSameLayout(_config);
      _config = config;
      _configRevision++;
      if (layoutChanged) {
        _contentBaseStrutStyle = null;
        _clearResolvedFixedLineMetrics();
        _clearKnownLineWidths();
        _disposeLongLinePrototypePainter();
      } else if (_resolvedFixedLineMetrics != null) {
        _resolvedFixedLineMetricsConfigRevision = _configRevision;
      }
      changed = true;
    }
    if (focused != null && focused != _focused) {
      _focused = focused;
      changed = true;
    }
    if (regularCaretVisible != null && regularCaretVisible != _regularCaretVisible) {
      _regularCaretVisible = regularCaretVisible;
      changed = true;
    }
    if (primaryCaretMotionActive != null && primaryCaretMotionActive != _primaryCaretMotionActive) {
      _primaryCaretMotionActive = primaryCaretMotionActive;
      changed = true;
    }
    if (paintEditingState != null && paintEditingState != _paintEditingState) {
      _paintEditingState = paintEditingState;
      changed = true;
    }
    if (selectionVisible != null && selectionVisible != _selectionVisible) {
      _selectionVisible = selectionVisible;
      changed = true;
    }
    if (keepCaretAtPreSelectAllPosition != null &&
        keepCaretAtPreSelectAllPosition != _keepCaretAtPreSelectAllPosition) {
      _keepCaretAtPreSelectAllPosition = keepCaretAtPreSelectAllPosition;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// controller 通知转发入口（State 中订阅 visualChanges 后调用）。
  void pumpFromController({bool beforePaint = false}) {
    if (_appliedVisualRevision == controller.visualRevision) return;
    _appliedVisualRevision = controller.visualRevision;
    if (_lineTextBatchDocRevision != controller.docRevision) _clearLineTextBatch();
    if (!identical(_selectionPaintIndexSource, controller.selections)) {
      _selectionPaintIndexSource = null;
      _selectionPaintIndex = null;
    }
    final presentationRevision = controller.presentationRevision;
    final overwriteMode = controller.overwriteMode;
    if (presentationRevision != _knownWidthPresentationRevision) {
      _inlineSizeEstimates = null;
      _inlineSizeRevision++;
      _knownWidthPresentationRevision = presentationRevision;
      _knownWidthOverwriteMode = overwriteMode;
      _clearKnownLineWidths();
    } else if (overwriteMode != _knownWidthOverwriteMode) {
      _knownWidthOverwriteMode = overwriteMode;
      final state = _longLineState;
      if (state != null) {
        state.longLineViewportRefreshPending.addAll(state.longLineCoverages.keys);
      }
      _longLineWindowRevision++;
      _publishKnownLineWidthMaximum();
    }
    if (!beforePaint) {
      notifyListeners();
    } else if (!_paintNotificationPending) {
      _paintNotificationPending = true;
      // 绘制当前帧时只同步几何，标脏通知等本轮绘制结束后发布。
      scheduleMicrotask(() {
        _paintNotificationPending = false;
        if (!_disposed) notifyListeners();
      });
    }
  }

  int _appliedVisualRevision = -1;
  bool _paintNotificationPending = false;

  void _scheduleSystemFontsUpdate() {
    if (_disposed || _systemFontsUpdateScheduled) return;
    _systemFontsUpdateScheduled = true;
    // Web 回退字体可能在 midFrameMicrotasks 完成；跟 Flutter 官方
    // RelayoutWhenSystemFontsChangeMixin 一样延到下一帧 transientCallbacks，
    // 避免在布局/绘制阶段同步标脏 RenderObject。
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _systemFontsUpdateScheduled = false;
      if (_disposed) return;
      _measurePainter?.markNeedsLayout();
      _measureLine = -1;
      _measureDocRevision = -1;
      _measurePresentationRevision = -1;
      _measureConfigRevision = -1;
      _clearResolvedFixedLineMetrics();
      _clearKnownLineWidths();
      _disposeLongLinePrototypePainter();
      _systemFontsRevision++;
      notifyListeners();
    });
  }

  static Listenable? _systemFontsIfInitialized() {
    try {
      return PaintingBinding.instance.systemFonts;
    } catch (_) {
      // 纯模型/Render 白盒测试允许在 Flutter binding 初始化前构造 scope；
      // 这种 headless 路径没有系统字体事件，跳过监听即可。
      return null;
    }
  }

  void _clearResolvedFixedLineMetrics() {
    _inlineSizeEstimates = null;
    _resolvedFixedLineMetrics = null;
    _resolvedFixedLineMetricsConfigRevision = -1;
    _resolvedFixedLineMetricsSystemFontsRevision = -1;
  }

  // ===========================================================================
  // 行数据门面（RenderEditableLine 消费）
  // ===========================================================================

  /// 短行完整文本；重建窗口期 index 越界返回空串，超长 nowrap 行直接拒绝。
  /// 掩码模式逐 code unit 替换，长度恒等且编辑坐标不漂移。
  String lineTextOf(int index) {
    final doc = controller.document;
    if (index < 0 || index >= doc.lineCount) return '';
    final bounded = _boundedLineTextOf(index);
    if (bounded == null && !_config.softWrap) {
      throw StateError('超长 nowrap 行禁止通过 lineTextOf 物化整行，请读取 longLineWindowFor 的有界窗口。');
    }
    final text = bounded ?? doc.lineAt(index);
    if (_config.obscureText && text.isNotEmpty) {
      return _config.obscuringCharacter * text.length;
    }
    return text;
  }

  String? _boundedLineTextOf(int index) {
    final revision = controller.docRevision;
    if (_lineTextBatchDocRevision == revision) {
      final local = index - _lineTextBatchStart;
      if (local >= 0 && local < _lineTextBatch.length) {
        _debugLineTextBatchReuseCount++;
        return _lineTextBatch[local];
      }
      if (_lineTextBatch.isEmpty && index == _lineTextBatchStart) {
        _debugLineTextBatchReuseCount++;
        return null;
      }
    }

    final lines = controller.document.readLines(
      index,
      maxLines: _shortLineBatchMaxLines,
      maxCodeUnits: _shortLineBatchCodeUnitLimit,
    );
    _lineTextBatchDocRevision = revision;
    _lineTextBatchStart = index;
    _lineTextBatch = lines;
    _debugLineTextBatchBuildCount++;
    return lines.isEmpty ? null : lines.first;
  }

  void _clearLineTextBatch() {
    _lineTextBatchDocRevision = -1;
    _lineTextBatchStart = -1;
    _lineTextBatch = const <String>[];
  }

  /// 当前行是否必须走 nowrap 有界 Paragraph 窗口。
  bool usesWindowedLineLayout(int index) {
    final doc = controller.document;
    return !_config.softWrap && index >= 0 && index < doc.lineCount && _boundedLineTextOf(index) == null;
  }

  /// 为超长 nowrap 行读取并构造当前横向视口附近的有界排版窗口。
  EditableLineLayoutWindow longLineWindowFor(int index, Object identity) {
    final doc = controller.document;
    final lineLength = doc.lineLength(index);
    assert(!_config.softWrap && lineLength > longLineParagraphCodeUnitLimit);
    final lineStart = doc.lineStart(index);
    _longLineBidiGenerations.putIfAbsent(identity, () => ++_nextLongLineBidiGeneration);
    final averageAdvance = _longLineAverageAdvances[identity] ?? _prototypeCodeUnitAdvance();
    final widthModel = _longLineWidthModels.putIfAbsent(identity, () => _EditableLongLineWidthModel(averageAdvance));
    var tabState = _validLongLineTabPrefix(identity, widthModel, averageAdvance);
    var estimatedTextWidth = _longLineEstimatedExtent(widthModel, tabState, lineLength);
    final viewportCenter = (_horizontalPixels + _viewportWidth / 2.0).clamp(0.0, estimatedTextWidth);
    final target = switch (_config.textDirection) {
      TextDirection.ltr => _longLineOffsetForLogicalX(
        identity,
        index,
        widthModel,
        tabState,
        viewportCenter,
        lineLength,
      ),
      TextDirection.rtl => _longLineOffsetForLogicalX(
        identity,
        index,
        widthModel,
        tabState,
        estimatedTextWidth - viewportCenter,
        lineLength,
      ),
    }.clamp(0, lineLength);

    final prefixRequiresBidi =
        !_config.obscureText &&
        _config.textDirection == TextDirection.ltr &&
        !_longLineBidiPipelines.containsKey(identity) &&
        _longLinePrefixRequiresBidiPipeline(identity, doc, lineStart: lineStart, lineLength: lineLength);
    if (!_config.obscureText &&
        (_config.textDirection == TextDirection.rtl ||
            prefixRequiresBidi ||
            _longLineBidiPipelines.containsKey(identity))) {
      final visual = _longLineVisualWindowFor(
        index,
        identity,
        lineStart: lineStart,
        lineLength: lineLength,
        averageAdvance: averageAdvance,
        widthModel: widthModel,
      );
      if (visual != null) return visual;
      tabState = _validLongLineTabPrefix(identity, widthModel, averageAdvance);
      estimatedTextWidth = _longLineEstimatedExtent(widthModel, tabState, lineLength);
      final logicalAdvance = _longLineLogicalX(identity, index, widthModel, tabState, target, lineLength);
      return EditableLineLayoutWindow(
        lineLength: lineLength,
        textStart: target,
        text: '',
        originX: math.max(0.0, estimatedTextWidth - logicalAdvance),
        estimatedTextWidth: estimatedTextWidth,
        averageAdvance: averageAdvance,
        textDirection: _config.textDirection,
        tabInitialAdvance: logicalAdvance,
        placeholder: true,
        visualGeneration: _longLineBidiGenerations[identity]!,
      );
    }

    _debugLastLongLineTabPrefixProbeCount = 0;
    var textStart = target;
    var textEnd = target;
    var shapingCoreStart = target;
    var shapingCoreEnd = target;
    if (_takeLongLineFrameReadBudget(identity)) {
      const boundaryBudget = _longLineBoundaryGuardCodeUnits * 2 + 2;
      const mainTextBudget = _longLineWindowCodeUnits - boundaryBudget * 2 - _longLineBoundaryGuardCodeUnits;
      final desiredCoreStart = (target - mainTextBudget ~/ 2).clamp(0, lineLength - mainTextBudget);
      final desiredCoreEnd = math.min(lineLength, desiredCoreStart + mainTextBudget);
      final alignedCoreStart = _boundedGraphemeBoundaryBeforeOrAt(
        doc,
        lineStart + desiredCoreStart,
        lowerBound: lineStart,
        upperBound: lineStart + lineLength,
      );
      final alignedCoreEnd = _boundedGraphemeBoundaryBeforeOrAt(
        doc,
        lineStart + desiredCoreEnd,
        lowerBound: lineStart,
        upperBound: lineStart + lineLength,
      );
      if (alignedCoreStart != null && alignedCoreEnd != null && alignedCoreEnd > alignedCoreStart) {
        shapingCoreStart = alignedCoreStart - lineStart;
        shapingCoreEnd = alignedCoreEnd - lineStart;
        final desiredShapingStart = math.max(0, shapingCoreStart - _longLineShapingHaloCodeUnits);
        final desiredShapingEnd = math.min(lineLength, shapingCoreEnd + _longLineShapingHaloCodeUnits);
        final alignedShapingStart = _boundedGraphemeBoundaryBeforeOrAt(
          doc,
          lineStart + desiredShapingStart,
          lowerBound: lineStart,
          upperBound: lineStart + lineLength,
        );
        final alignedShapingEnd = _boundedGraphemeBoundaryBeforeOrAt(
          doc,
          lineStart + desiredShapingEnd,
          lowerBound: lineStart,
          upperBound: lineStart + lineLength,
        );
        if (alignedShapingStart != null &&
            alignedShapingEnd != null &&
            alignedShapingEnd > alignedShapingStart &&
            alignedShapingStart <= alignedCoreStart &&
            alignedShapingEnd >= alignedCoreEnd &&
            alignedShapingEnd - alignedShapingStart <= _longLineWindowCodeUnits) {
          textStart = alignedShapingStart - lineStart;
          textEnd = alignedShapingEnd - lineStart;
        } else {
          textStart = shapingCoreStart;
          textEnd = shapingCoreEnd;
        }
      }
    }
    var text = _config.obscureText
        ? _config.obscuringCharacter * (textEnd - textStart)
        : doc.getText(lineStart + textStart, lineStart + textEnd);
    RenderEditableLine.debugRecordRenderRead(text.length);
    var placeholder = textEnd <= textStart;
    var tabInitialAdvance = widthModel.xForOffset(textStart, lineLength);
    var logicalEndAdvance = widthModel.xForOffset(textEnd, lineLength);
    if (!placeholder && !_config.obscureText) {
      final resolved = _resolveLongLineTabPrefix(
        identity,
        doc,
        line: index,
        lineStart: lineStart,
        target: textStart,
        averageAdvance: averageAdvance,
        widthModel: widthModel,
        lineLength: lineLength,
      );
      if (resolved == null) {
        text = '';
        textEnd = textStart;
        shapingCoreStart = textStart;
        shapingCoreEnd = textStart;
        placeholder = true;
      } else {
        tabInitialAdvance = resolved;
        tabState = _longLineTabPrefixes[identity]!;
        if (_config.textDirection == TextDirection.rtl || tabState.hasUnsafeBidiPrefix) {
          final visual = _longLineVisualWindowFor(
            index,
            identity,
            lineStart: lineStart,
            lineLength: lineLength,
            averageAdvance: averageAdvance,
            widthModel: widthModel,
          );
          if (visual != null) return visual;
          logicalEndAdvance = widthModel.xForOffset(textEnd, lineLength) + tabState.tabExtra;
          text = '';
          textEnd = textStart;
          shapingCoreStart = textStart;
          shapingCoreEnd = textStart;
          placeholder = true;
        } else if (tabState.scannedUntil == textStart) {
          _accumulateLongLineTabPrefix(
            tabState,
            text,
            widthModel,
            lineLength,
            styleRuns: _tabStyleRunsForWindow(index, text, textStart: textStart, lineLength: lineLength),
          );
          if ((_config.textDirection == TextDirection.rtl || tabState.hasUnsafeBidiTail) && textEnd < lineLength) {
            final visual = _longLineVisualWindowFor(
              index,
              identity,
              lineStart: lineStart,
              lineLength: lineLength,
              averageAdvance: averageAdvance,
              widthModel: widthModel,
            );
            if (visual != null) return visual;
            text = '';
            textEnd = textStart;
            shapingCoreStart = textStart;
            shapingCoreEnd = textStart;
            placeholder = true;
          } else {
            logicalEndAdvance = widthModel.xForOffset(textEnd, lineLength) + tabState.tabExtra;
          }
        } else {
          // 已扫描前缀覆盖本窗时从分页检查点随机查询；只在窗口尾越过
          // scannedUntil 时顺序补扫未覆盖部分，绝不重放已扫描的密集 tab。
          if (tabState.scannedUntil < textEnd) {
            final localStart = math.max(0, tabState.scannedUntil - textStart);
            final tail = text.substring(localStart);
            _accumulateLongLineTabPrefix(
              tabState,
              tail,
              widthModel,
              lineLength,
              styleRuns: _tabStyleRunsForWindow(index, tail, textStart: tabState.scannedUntil, lineLength: lineLength),
            );
          }
          logicalEndAdvance = _longLineLogicalX(identity, index, widthModel, tabState, textEnd, lineLength);
        }
      }
    }
    tabState = _validLongLineTabPrefix(identity, widthModel, averageAdvance);
    estimatedTextWidth = _longLineEstimatedExtent(widthModel, tabState, lineLength);
    final originX = switch (_config.textDirection) {
      TextDirection.ltr => tabInitialAdvance,
      TextDirection.rtl => estimatedTextWidth - logicalEndAdvance,
    };
    return EditableLineLayoutWindow(
      lineLength: lineLength,
      textStart: textStart,
      text: text,
      originX: math.max(0.0, originX),
      estimatedTextWidth: estimatedTextWidth,
      averageAdvance: averageAdvance,
      textDirection: _config.textDirection,
      tabInitialAdvance: tabInitialAdvance,
      shapingCoreStart: shapingCoreStart,
      shapingCoreEnd: shapingCoreEnd,
      placeholder: placeholder,
      visualGeneration: _longLineBidiGenerations[identity]!,
    );
  }

  bool _longLinePrefixRequiresBidiPipeline(
    Object identity,
    TextDocument document, {
    required int lineStart,
    required int lineLength,
  }) {
    if (_longLineBidiSafePrefixIdentities.contains(identity)) return false;
    final requested = math.min(256, lineLength);
    final granted = _takeAdditionalLongLineReadBudget(requested);
    if (granted < requested) return false;
    final text = document.getText(lineStart, lineStart + granted);
    RenderEditableLine.debugRecordRenderRead(text.length);
    for (final rune in text.runes) {
      if (_requiresGlobalBidiClass(unicodeBidiClassOf(rune))) return true;
    }
    _longLineBidiSafePrefixIdentities.add(identity);
    return false;
  }

  static bool _requiresGlobalBidiClass(UnicodeBidiClass bidiClass) =>
      bidiClass == UnicodeBidiClass.r ||
      bidiClass == UnicodeBidiClass.al ||
      bidiClass == UnicodeBidiClass.an ||
      bidiClass == UnicodeBidiClass.lre ||
      bidiClass == UnicodeBidiClass.rle ||
      bidiClass == UnicodeBidiClass.lro ||
      bidiClass == UnicodeBidiClass.rlo ||
      bidiClass == UnicodeBidiClass.pdf ||
      bidiClass == UnicodeBidiClass.lri ||
      bidiClass == UnicodeBidiClass.rli ||
      bidiClass == UnicodeBidiClass.fsi ||
      bidiClass == UnicodeBidiClass.pdi;

  EditableLineLayoutWindow? _longLineVisualWindowFor(
    int line,
    Object identity, {
    required int lineStart,
    required int lineLength,
    required double averageAdvance,
    required _EditableLongLineWidthModel widthModel,
  }) {
    final baseDirection = _config.textDirection == TextDirection.rtl
        ? LongLineBidiBaseDirection.rtl
        : LongLineBidiBaseDirection.ltr;
    var pipeline = _longLineBidiPipelines[identity];
    if (pipeline != null && (pipeline.lineLength != lineLength || pipeline.baseDirection != baseDirection)) {
      _disposeLongLineBidiPipeline(identity);
      _clearLongLineBidiFailure(identity);
      pipeline = null;
    }
    if (pipeline == null) {
      pipeline = LongLineBidiPipeline(
        lineLength: lineLength,
        baseDirection: baseDirection,
        averageAdvance: averageAdvance,
      );
      _clearLongLineBidiFailure(identity);
      _longLineBidiGenerations[identity] = ++_nextLongLineBidiGeneration;
    }
    _longLineBidiGenerations.putIfAbsent(identity, () => ++_nextLongLineBidiGeneration);
    _longLineBidiPipelines.remove(identity);
    _longLineBidiPipelines[identity] = pipeline;
    _trimLongLineBidiPipelines(preserveIdentity: identity);

    var tabState = _validLongLineTabPrefix(identity, widthModel, averageAdvance);
    if (tabState == null) {
      tabState = _EditableLongLineTabPrefix(averageAdvance, widthModel.revision);
      _longLineTabPrefixes[identity] = tabState;
      _longLineTabBatchPrefixes.remove(identity);
    }
    final document = controller.document;
    _beginLongLineReadBudgetFrame(resetIdleQuery: true);
    while (pipeline.debugLoadedCodeUnits < lineLength && (_longLineBidiHydrationChunksThisFrame[identity] ?? 0) < 1) {
      final start = pipeline.debugLoadedCodeUnits;
      final inline = _config.obscureText ? null : controller.inlineContentModel;
      final halo = inline == null ? 0 : inline.matcher.maxLength - 1;
      // halo 与正文一起计入本帧读取预算，且共享同一次 piece-tree 读取。
      final requested = math.min(LongLineBidiPipeline.maxChunkCodeUnits, lineLength - start) + halo * 2;
      final granted = _takeAdditionalLongLineReadBudget(requested) - halo * 2;
      if (granted <= 0) break;
      final a = math.max(0, start - halo);
      final b = math.min(lineLength, start + granted + halo);
      final extended = document.getText(lineStart + a, lineStart + b);
      RenderEditableLine.debugRecordRenderRead(extended.length);
      final text = halo == 0 ? extended : extended.substring(start - a, start - a + granted);
      if (text.isEmpty) break;
      pipeline.appendChunk(
        start,
        inline == null ? text : inline.matcher.neutralize(extended, start: start - a, end: start - a + text.length),
      );
      _longLineBidiHydrationChunksThisFrame[identity] = (_longLineBidiHydrationChunksThisFrame[identity] ?? 0) + 1;
      _advanceLongLineTabPrefixFromSharedChunk(
        tabState,
        text,
        chunkStart: start,
        line: line,
        widthModel: widthModel,
        lineLength: lineLength,
      );
      if (text.length < granted) break;
    }
    _trimLongLineBidiPipelines(preserveIdentity: identity);

    final loaded = pipeline.debugLoadedCodeUnits;
    if (tabState.scannedUntil < loaded) {
      _hydrateLongLineTabPrefixTo(
        tabState,
        document,
        identity: identity,
        target: loaded,
        line: line,
        lineStart: lineStart,
        widthModel: widthModel,
        lineLength: lineLength,
      );
    }
    if (!pipeline.debugReady || tabState.scannedUntil < lineLength) {
      _deferredLongLineHydration.add(identity);
      _scheduleDeferredLongLineHydration();
      return null;
    }

    final result = pipeline.resolvedResultOrNull;
    if (result == null) {
      _requestLongLineBidiResolve(identity, pipeline);
      return null;
    }
    if (result.visualIndex.tiles.isEmpty) {
      _deferredLongLineHydration.remove(identity);
      return EditableLineLayoutWindow.visualEmpty(
        lineLength: lineLength,
        averageAdvance: averageAdvance,
        visualGeneration: _longLineBidiGenerations[identity]!,
        visualMetricRevision: _longLineVisualMetricRevisions[identity] ?? 0,
        originX: _longLineVisualAlignmentShift(0.0, identity),
        estimatedTextWidth: _longLineVisualAlignedExtent(0.0, identity),
      );
    }
    var extent = result.visualIndex.totalExtent;
    final viewportWidth = math.max(_viewportWidth, 1.0);
    var alignmentShift = _longLineVisualAlignmentShift(extent, identity);
    var alignedExtent = _longLineVisualAlignedExtent(extent, identity);
    var viewportStart = (_horizontalPixels - alignmentShift)
        .clamp(0.0, math.max(0.0, extent - viewportWidth))
        .toDouble();
    var viewportEnd = math.min(extent, viewportStart + viewportWidth);
    var paragraphBudget = _longLineWindowCodeUnits;
    for (final x in <double>[viewportStart, viewportEnd]) {
      final hit = result.visualIndex.locateX(x);
      if (hit != null && result.visualIndex.tiles[hit.tileIndex].length + 6 > paragraphBudget) {
        paragraphBudget = longLineParagraphCodeUnitLimit;
        break;
      }
    }
    var visualBuildBlocked = false;
    EditableLineLayoutWindow? buildVisualWindow(int budget) {
      var blocked = false;
      final built = pipeline!.buildWindow(
        viewportStart: viewportStart,
        viewportEnd: viewportEnd,
        guard: viewportWidth,
        maxParagraphCodeUnits: budget,
        sourceText: controller.inlineContent.isEmpty || _config.obscureText
            ? null
            : (start, end) {
                RenderEditableLine.debugRecordRenderRead(end - start);
                return document.getText(lineStart + start, lineStart + end);
              },
        logicalTabPrefixesForOffsets: (offsets) {
          final values = _longLineLogicalXsForOffsets(identity, line, widthModel, tabState!, offsets, lineLength);
          if (values == null) blocked = true;
          return values;
        },
      );
      if (!blocked) return built;
      visualBuildBlocked = true;
      _deferredLongLineHydration.add(identity);
      _scheduleDeferredLongLineHydration();
      return null;
    }

    EditableLineLayoutWindow? visual = buildVisualWindow(paragraphBudget);
    if (visual == null && !visualBuildBlocked && paragraphBudget < longLineParagraphCodeUnitLimit) {
      paragraphBudget = longLineParagraphCodeUnitLimit;
      visual = buildVisualWindow(paragraphBudget);
    }
    if (visual == null) {
      if (!visualBuildBlocked) _deferredLongLineHydration.remove(identity);
      return null;
    }
    if (visual.visualFirstTile < 0 ||
        visual.visualEndTile <= visual.visualFirstTile ||
        visual.visualTileCount != result.visualIndex.tiles.length) {
      return null;
    }
    final estimatesChanged = _updateLongLineBidiUnmeasuredWidths(
      identity,
      line,
      pipeline,
      result,
      window: visual,
      widthModel: widthModel,
      tabState: tabState,
      lineLength: lineLength,
    );
    if (estimatesChanged) {
      extent = result.visualIndex.totalExtent;
      alignmentShift = _longLineVisualAlignmentShift(extent, identity);
      alignedExtent = _longLineVisualAlignedExtent(extent, identity);
      viewportStart = (_horizontalPixels - alignmentShift).clamp(0.0, math.max(0.0, extent - viewportWidth)).toDouble();
      viewportEnd = math.min(extent, viewportStart + viewportWidth);
      visual = buildVisualWindow(paragraphBudget);
      if (visual == null) return null;
    }
    _deferredLongLineHydration.remove(identity);
    return EditableLineLayoutWindow.visual(
      lineLength: visual.lineLength,
      fragments: visual.visualFragments,
      paragraphCodeUnitLimit: visual.totalParagraphCodeUnits,
      originX: visual.originX + alignmentShift,
      estimatedTextWidth: alignedExtent,
      averageAdvance: visual.averageAdvance,
      visualGeneration: _longLineBidiGenerations[identity]!,
      visualMetricRevision: _longLineVisualMetricRevisions[identity] ?? 0,
      visualFirstTile: visual.visualFirstTile,
      visualEndTile: visual.visualEndTile,
      visualTileCount: visual.visualTileCount,
      zeroWidthLogicalRanges: visual.zeroWidthLogicalRanges,
    );
  }

  void _requestLongLineBidiResolve(Object identity, LongLineBidiPipeline pipeline) {
    if (pipeline.debugResolved ||
        pipeline.debugResolving ||
        _activeLongLineBidiResolves.contains(pipeline) ||
        _executorLongLineBidiResolves.contains(pipeline) ||
        _longLineBidiTerminalErrors.containsKey(identity) ||
        _longLineBidiRetryScheduled.contains(identity)) {
      return;
    }
    _pendingLongLineBidiResolves.add(identity);
    _drainLongLineBidiResolveQueue();
  }

  void _drainLongLineBidiResolveQueue() {
    while (!_disposed &&
        _executorLongLineBidiResolves.length < _longLineBidiMaxConcurrentResolves &&
        _pendingLongLineBidiResolves.isNotEmpty) {
      final identity = _nextLongLineBidiResolveIdentity();
      _pendingLongLineBidiResolves.remove(identity);
      final pipeline = _longLineBidiPipelines[identity];
      if (pipeline == null || !pipeline.debugReady || pipeline.debugResolved || pipeline.debugResolving) continue;
      if (!_activeLongLineBidiResolves.add(pipeline)) continue;
      _executorLongLineBidiResolves.add(pipeline);
      _startLongLineBidiResolve(identity, pipeline);
    }
  }

  Object _nextLongLineBidiResolveIdentity() {
    for (final line in _mounted.values) {
      if (_pendingLongLineBidiResolves.contains(line.identity)) return line.identity;
    }
    return _pendingLongLineBidiResolves.first;
  }

  void _startLongLineBidiResolve(Object identity, LongLineBidiPipeline pipeline) {
    Future<LongLineBidiPipelineResult> future;
    try {
      future = _longLineBidiResolverForTesting?.call(pipeline) ?? pipeline.resolveInBackground();
    } catch (error, stackTrace) {
      future = Future<LongLineBidiPipelineResult>.error(error, stackTrace);
    }
    unawaited(
      future.then<void>(
        (_) {
          _activeLongLineBidiResolves.remove(pipeline);
          _executorLongLineBidiResolves.remove(pipeline);
          _longLineBidiFailureAttempts.remove(identity);
          _longLineBidiTerminalErrors.remove(identity);
          _longLineBidiRetryScheduled.remove(identity);
          if (!_disposed && identical(_longLineBidiPipelines[identity], pipeline)) {
            final mounted = _mounted.values.any((line) => identical(line.identity, identity));
            _trimLongLineBidiPipelines(preserveIdentity: mounted ? identity : Object());
            if (mounted) {
              _deferredLongLineHydration.add(identity);
              _scheduleDeferredLongLineHydration();
            }
          }
          _drainLongLineBidiResolveQueue();
        },
        onError: (Object error, StackTrace stackTrace) {
          _activeLongLineBidiResolves.remove(pipeline);
          _executorLongLineBidiResolves.remove(pipeline);
          _drainLongLineBidiResolveQueue();
          if (error is LongLineBidiPipelineStaleException) return;
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'el_ui editable',
              context: ErrorDescription('后台解析超长双向文本'),
            ),
          );
          _handleLongLineBidiBackgroundFailure(identity, pipeline, error);
        },
      ),
    );
  }

  void _handleLongLineBidiBackgroundFailure(Object identity, LongLineBidiPipeline pipeline, Object error) {
    if (_disposed || !identical(_longLineBidiPipelines[identity], pipeline)) return;
    final attempts = (_longLineBidiFailureAttempts[identity] ?? 0) + 1;
    _longLineBidiFailureAttempts[identity] = attempts;
    if (attempts >= _longLineBidiMaxBackgroundAttempts) {
      _longLineBidiRetryScheduled.remove(identity);
      _longLineBidiTerminalErrors[identity] = error;
      _deferredLongLineHydration.remove(identity);
      _scheduleLongLineVisualRefresh(identity);
      return;
    }
    if (!_mounted.values.any((line) => identical(line.identity, identity))) return;
    if (!_longLineBidiRetryScheduled.add(identity)) return;

    void retry() {
      _longLineBidiRetryScheduled.remove(identity);
      if (_disposed ||
          !identical(_longLineBidiPipelines[identity], pipeline) ||
          pipeline.debugResolved ||
          pipeline.debugResolving ||
          !_mounted.values.any((line) => identical(line.identity, identity)) ||
          _longLineBidiTerminalErrors.containsKey(identity)) {
        return;
      }
      _pendingLongLineBidiResolves.add(identity);
      _drainLongLineBidiResolveQueue();
    }

    try {
      SchedulerBinding.instance.scheduleFrameCallback((_) => retry());
      SchedulerBinding.instance.ensureVisualUpdate();
    } catch (_) {
      scheduleMicrotask(retry);
    }
  }

  bool _disposeLongLineBidiPipeline(Object identity, {bool drainQueue = true}) {
    final state = _longLineState;
    if (state == null) return false;
    final pipeline = state.longLineBidiPipelines.remove(identity);
    if (pipeline == null) return false;
    final releasedLogicalSlot = state.activeLongLineBidiResolves.remove(pipeline);
    pipeline.dispose();
    // 原生 compute 无法中止；executor 槽必须等真实 Future settle 后才能释放，
    // 否则连续卸载会无界叠加 isolate 与峰值内存。Web 取消会很快 settle。
    if (releasedLogicalSlot && drainQueue && !_disposed) _drainLongLineBidiResolveQueue();
    return releasedLogicalSlot;
  }

  void _clearLongLineBidiFailure(Object identity) {
    final state = _longLineState;
    if (state == null) return;
    state.longLineBidiFailureAttempts.remove(identity);
    state.longLineBidiTerminalErrors.remove(identity);
    state.longLineBidiRetryScheduled.remove(identity);
  }

  void _trimLongLineBidiPipelines({required Object preserveIdentity}) {
    if (_longLineState == null) return;
    int retainedBytes() =>
        _longLineBidiPipelines.values.fold(0, (total, pipeline) => total + pipeline.debugRetainedBytes);

    var bytes = retainedBytes();
    while (_longLineBidiPipelines.length > _longLineBidiPipelineMaxEntries ||
        bytes > _longLineBidiPipelineMaxRetainedBytes) {
      Object? unmountedCandidate;
      for (final identity in _longLineBidiPipelines.keys) {
        if (identical(identity, preserveIdentity)) continue;
        final mounted = _mounted.values.any((line) => identical(line.identity, identity));
        if (!mounted) {
          unmountedCandidate = identity;
          break;
        }
      }
      final candidate = unmountedCandidate;
      if (candidate == null) break;
      _disposeLongLineBidiPipeline(candidate, drainQueue: false);
      _longLineBidiEstimateRevisions.remove(candidate);
      _longLineBidiGenerations.remove(candidate);
      _longLineVisualMetricRevisions.remove(candidate);
      _pendingLongLineBidiResolves.remove(candidate);
      _clearLongLineBidiFailure(candidate);
      _forgetLongLineCoverage(candidate);
      bytes = retainedBytes();
    }
    _drainLongLineBidiResolveQueue();
  }

  void _scheduleLongLineVisualRefresh(Object identity, {EditableLineLayoutWindow? triggerWindow}) {
    if (_disposed) return;
    _longLineVisualRefreshPending[identity] = triggerWindow;
    if (_longLineVisualRefreshScheduled) return;
    _longLineVisualRefreshScheduled = true;
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _longLineVisualRefreshScheduled = false;
        if (_disposed) return;
        _longLineWindowRevision++;
        notifyListeners();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    } catch (_) {
      _longLineVisualRefreshScheduled = false;
      _longLineWindowRevision++;
      notifyListeners();
    }
  }

  /// 新旧窗口几何完全等价时确认 revision，无需重排也必须结清 pending 状态。
  void acknowledgeEquivalentLongLineWindow(
    Object identity,
    EditableLineLayoutWindow previous,
    EditableLineLayoutWindow _,
  ) {
    _longLineViewportRefreshPending.remove(identity);
    final visualPending = _longLineVisualRefreshPending[identity];
    if (_longLineVisualRefreshPending.containsKey(identity) &&
        (visualPending == null || identical(visualPending, previous))) {
      _longLineVisualRefreshPending.remove(identity);
    }
  }

  bool _updateLongLineBidiUnmeasuredWidths(
    Object identity,
    int line,
    LongLineBidiPipeline pipeline,
    LongLineBidiPipelineResult result, {
    required EditableLineLayoutWindow window,
    required _EditableLongLineWidthModel widthModel,
    required _EditableLongLineTabPrefix tabState,
    required int lineLength,
  }) {
    final revision = Object.hash(
      widthModel.revision,
      tabState.scannedUntil,
      tabState.checkpointCount,
      tabState.tabExtra,
      pipeline.averageAdvance,
    );
    final visualIndex = result.visualIndex;
    var progress = _longLineBidiEstimateRevisions[identity];
    if (progress == null || progress.revision != revision || progress.tileCount != visualIndex.tiles.length) {
      progress = _EditableLongLineEstimateProgress(
        revision: revision,
        tileCount: visualIndex.tiles.length,
        priorityFirstTile: window.visualFirstTile,
        priorityEndTile: window.visualEndTile,
      );
      _longLineBidiEstimateRevisions[identity] = progress;
    } else {
      progress.prioritize(window.visualFirstTile, window.visualEndTile);
    }
    if (progress.complete) return false;

    final widths = <int, double>{};
    final workPerTile = 2 * (10 + _EditableLongLineTabPrefix.checkpointStride + 1);
    var blocked = false;
    while (!progress.complete &&
        _longLineVisualEstimateAllocationRemaining > 0 &&
        _longLineVisualEstimateWorkRemaining >= workPerTile) {
      final prioritizesWindow = progress.priorityNextTile < progress.priorityEndTile;
      final index = prioritizesWindow ? progress.priorityNextTile : progress.globalNextTile;
      final tile = visualIndex.tiles[index];
      final start = _longLineLogicalXLookup(identity, line, widthModel, tabState, tile.start, lineLength);
      if (!start.exact) {
        blocked = true;
        break;
      }
      final end = _longLineLogicalXLookup(identity, line, widthModel, tabState, tile.end, lineLength);
      if (!end.exact) {
        blocked = true;
        break;
      }

      _longLineVisualEstimateWorkRemaining -= workPerTile;
      _debugCurrentFrameLongLineVisualEstimateWork += workPerTile;
      _debugMaxFrameLongLineVisualEstimateWork = math.max(
        _debugMaxFrameLongLineVisualEstimateWork,
        _debugCurrentFrameLongLineVisualEstimateWork,
      );
      if (!visualIndex.isMeasured(index)) {
        final width = math.max(0.0, end.x - start.x);
        if ((visualIndex.widthOf(index) - width).abs() > precisionErrorTolerance) {
          widths[index] = width;
          _longLineVisualEstimateAllocationRemaining--;
          _debugCurrentFrameLongLineVisualEstimateAllocations++;
          _debugMaxFrameLongLineVisualEstimateAllocations = math.max(
            _debugMaxFrameLongLineVisualEstimateAllocations,
            _debugCurrentFrameLongLineVisualEstimateAllocations,
          );
        }
      }

      if (prioritizesWindow) {
        progress.priorityNextTile++;
        if (index == progress.globalNextTile) progress.globalNextTile++;
      } else {
        progress.globalNextTile++;
      }
      if (progress.priorityNextTile >= progress.priorityEndTile &&
          progress.globalNextTile >= progress.priorityFirstTile &&
          progress.globalNextTile < progress.priorityEndTile) {
        progress.globalNextTile = progress.priorityEndTile;
      }
    }
    if (widths.isNotEmpty) pipeline.updateUnmeasuredWidths(widths);
    if (!progress.complete || blocked) _scheduleLongLineVisualRefresh(identity);
    return widths.isNotEmpty;
  }

  void _advanceLongLineTabPrefixFromSharedChunk(
    _EditableLongLineTabPrefix state,
    String text, {
    required int chunkStart,
    required int line,
    required _EditableLongLineWidthModel widthModel,
    required int lineLength,
  }) {
    final chunkEnd = chunkStart + text.length;
    if (state.scannedUntil < chunkStart || state.scannedUntil >= chunkEnd) return;
    final localStart = state.scannedUntil - chunkStart;
    final tail = text.substring(localStart);
    _accumulateLongLineTabPrefix(
      state,
      tail,
      widthModel,
      lineLength,
      styleRuns: _tabStyleRunsForWindow(line, tail, textStart: state.scannedUntil, lineLength: lineLength),
    );
  }

  void _hydrateLongLineTabPrefixTo(
    _EditableLongLineTabPrefix state,
    TextDocument document, {
    required Object identity,
    required int target,
    required int line,
    required int lineStart,
    required _EditableLongLineWidthModel widthModel,
    required int lineLength,
  }) {
    while (state.scannedUntil < target && (_longLineBidiHydrationChunksThisFrame[identity] ?? 0) < 1) {
      final requested = math.min(LongLineBidiPipeline.maxChunkCodeUnits, target - state.scannedUntil);
      final granted = _takeAdditionalLongLineReadBudget(requested);
      if (granted <= 0) return;
      final text = document.getText(lineStart + state.scannedUntil, lineStart + state.scannedUntil + granted);
      RenderEditableLine.debugRecordRenderRead(text.length);
      if (text.isEmpty) return;
      _longLineBidiHydrationChunksThisFrame[identity] = (_longLineBidiHydrationChunksThisFrame[identity] ?? 0) + 1;
      _accumulateLongLineTabPrefix(
        state,
        text,
        widthModel,
        lineLength,
        styleRuns: _tabStyleRunsForWindow(line, text, textStart: state.scannedUntil, lineLength: lineLength),
      );
      if (text.length < granted) return;
    }
  }

  double? _resolveLongLineTabPrefix(
    Object identity,
    TextDocument document, {
    required int line,
    required int lineStart,
    required int target,
    required double averageAdvance,
    required _EditableLongLineWidthModel widthModel,
    required int lineLength,
  }) {
    var state = _validLongLineTabPrefix(identity, widthModel, averageAdvance);
    if (state == null) {
      state = _EditableLongLineTabPrefix(averageAdvance, widthModel.revision);
      _longLineTabPrefixes[identity] = state;
      _longLineTabBatchPrefixes.remove(identity);
    } else if (target < state.scannedUntil && !state.sawTab && !state.sawBidiControl && !state.sawStrongRtl) {
      return widthModel.xForOffset(target, lineLength);
    } else if (target < state.scannedUntil) {
      final lookup = _longLineLogicalXLookup(identity, line, widthModel, state, target, lineLength);
      return lookup.exact ? lookup.x : null;
    }
    const maxStep = 64 * 1024;
    while (state.scannedUntil < target) {
      final requested = math.min(maxStep, target - state.scannedUntil);
      final granted = _takeAdditionalLongLineReadBudget(requested);
      if (granted <= 0) {
        _deferredLongLineHydration.add(identity);
        _scheduleDeferredLongLineHydration();
        return null;
      }
      final text = document.getText(lineStart + state.scannedUntil, lineStart + state.scannedUntil + granted);
      RenderEditableLine.debugRecordRenderRead(text.length);
      _accumulateLongLineTabPrefix(
        state,
        text,
        widthModel,
        lineLength,
        styleRuns: _tabStyleRunsForWindow(line, text, textStart: state.scannedUntil, lineLength: lineLength),
      );
      if (text.length < granted) break;
    }
    if (state.scannedUntil < target) {
      _deferredLongLineHydration.add(identity);
      _scheduleDeferredLongLineHydration();
      return null;
    }
    return widthModel.xForOffset(target, lineLength) + state.tabExtra;
  }

  void _accumulateLongLineTabPrefix(
    _EditableLongLineTabPrefix state,
    String text,
    _EditableLongLineWidthModel widthModel,
    int lineLength, {
    required List<_EditableTabStyleRun> styleRuns,
  }) {
    final defaultStopExtent = _prototypeSpaceAdvance() * _config.tabSize;
    var baseAdvance = widthModel.xForOffset(state.scannedUntil, lineLength);
    var styleRunIndex = 0;
    for (var index = 0; index < text.length; index++) {
      final offset = state.scannedUntil + index;
      _debugLastLongLineTabPrefixProbeCount++;
      _debugMaxLongLineTabPrefixProbeCount = math.max(
        _debugMaxLongLineTabPrefixProbeCount,
        _debugLastLongLineTabPrefixProbeCount,
      );
      final codeUnit = text.codeUnitAt(index);
      final pendingHigh = state.pendingHighSurrogate;
      if (pendingHigh != null) {
        state.pendingHighSurrogate = null;
        if (_isLowSurrogate(codeUnit)) {
          _updateLongLineBidiState(state, 0x10000 + ((pendingHigh - 0xd800) << 10) + codeUnit - 0xdc00);
        } else {
          _updateLongLineBidiCodeUnit(state, text, index, codeUnit);
        }
      } else {
        _updateLongLineBidiCodeUnit(state, text, index, codeUnit);
      }
      if (codeUnit == 0x09) {
        state.sawTab = true;
        while (styleRunIndex < styleRuns.length && styleRuns[styleRunIndex].end <= index) {
          styleRunIndex++;
        }
        final stopExtent =
            styleRunIndex < styleRuns.length &&
                styleRuns[styleRunIndex].start <= index &&
                index < styleRuns[styleRunIndex].end
            ? styleRuns[styleRunIndex].stopExtent
            : defaultStopExtent;
        final current = baseAdvance + state.tabExtra;
        final target = stopExtent <= precisionErrorTolerance
            ? current + state.averageAdvance
            : ((current + stopExtent * 1e-6) / stopExtent).floor() * stopExtent + stopExtent;
        state.tabExtra = target - (baseAdvance + widthModel.advanceAt(offset));
      }
      baseAdvance += widthModel.advanceAt(offset);
      if ((offset + 1) % _EditableLongLineWidthModel.chunkSize == 0) {
        state.recordCheckpointAt(offset + 1, state.tabExtra);
      }
    }
    state.scannedUntil += text.length;
    state.recordCheckpointAt(state.scannedUntil, state.tabExtra);
    state.retainedExtent = math.max(
      state.retainedExtent,
      widthModel.extentFor(lineLength, _viewportWidth) + state.tabExtra,
    );
  }

  void _updateLongLineBidiCodeUnit(_EditableLongLineTabPrefix state, String text, int index, int codeUnit) {
    if (_isHighSurrogate(codeUnit)) {
      if (index + 1 < text.length && _isLowSurrogate(text.codeUnitAt(index + 1))) {
        final low = text.codeUnitAt(index + 1);
        _updateLongLineBidiState(state, 0x10000 + ((codeUnit - 0xd800) << 10) + low - 0xdc00);
      } else {
        state.pendingHighSurrogate = codeUnit;
      }
    } else if (!_isLowSurrogate(codeUnit)) {
      _updateLongLineBidiState(state, codeUnit);
    }
  }

  void _updateLongLineBidiState(_EditableLongLineTabPrefix state, int codeUnit) {
    final bidiClass = unicodeBidiClassOf(codeUnit);
    final isolate =
        bidiClass == UnicodeBidiClass.lri || bidiClass == UnicodeBidiClass.rli || bidiClass == UnicodeBidiClass.fsi;
    final embedding =
        bidiClass == UnicodeBidiClass.lre ||
        bidiClass == UnicodeBidiClass.rle ||
        bidiClass == UnicodeBidiClass.lro ||
        bidiClass == UnicodeBidiClass.rlo;
    if (isolate || embedding) {
      state.sawBidiControl = true;
      if (state.bidiStack.length >= 125) {
        state.bidiOverflow = true;
      } else {
        state.bidiStack.add(isolate);
      }
      return;
    }
    if (bidiClass == UnicodeBidiClass.pdf) {
      state.sawBidiControl = true;
      if (state.bidiStack.isNotEmpty && !state.bidiStack.last) state.bidiStack.removeLast();
      return;
    }
    if (bidiClass == UnicodeBidiClass.pdi) {
      state.sawBidiControl = true;
      for (var index = state.bidiStack.length - 1; index >= 0; index--) {
        if (!state.bidiStack[index]) continue;
        state.bidiStack.removeRange(index, state.bidiStack.length);
        break;
      }
      return;
    }
    if (bidiClass == UnicodeBidiClass.r || bidiClass == UnicodeBidiClass.al) {
      state.sawStrongRtl = true;
      state.lastStrongRtl = true;
    } else if (bidiClass == UnicodeBidiClass.an) {
      state.sawBidiControl = true;
    } else if (bidiClass == UnicodeBidiClass.l) {
      state.lastStrongRtl = false;
    }
  }

  _EditableLongLineTabPrefix? _validLongLineTabPrefix(
    Object identity,
    _EditableLongLineWidthModel widthModel,
    double averageAdvance,
  ) {
    final state = _longLineTabPrefixes[identity];
    if (state == null) return null;
    if (!state.sawTab) {
      // 已扫描范围内没有 tab 时摘要与字宽模型无关，宽字窗上报
      // 导致 revision 变化也不应让 5MiB 纯文本从头扫描。
      state
        ..averageAdvance = averageAdvance
        ..widthRevision = widthModel.revision;
      return state;
    }
    if (state.widthRevision != widthModel.revision ||
        (state.averageAdvance - averageAdvance).abs() > precisionErrorTolerance) {
      return null;
    }
    return state;
  }

  double _longLineLogicalX(
    Object identity,
    int line,
    _EditableLongLineWidthModel widthModel,
    _EditableLongLineTabPrefix? tabState,
    int offset,
    int lineLength,
  ) => _longLineLogicalXLookup(identity, line, widthModel, tabState, offset, lineLength).x;

  ({double x, bool exact}) _longLineLogicalXLookup(
    Object identity,
    int line,
    _EditableLongLineWidthModel widthModel,
    _EditableLongLineTabPrefix? tabState,
    int offset,
    int lineLength,
  ) {
    final logical = widthModel.xForOffset(offset, lineLength);
    if (tabState == null) return (x: logical, exact: true);
    final tab = _longLineTabExtraForOffset(identity, line, tabState, widthModel, offset, lineLength);
    return (x: logical + tab.extra, exact: tab.exact);
  }

  ({double extra, bool exact}) _longLineTabExtraForOffset(
    Object identity,
    int line,
    _EditableLongLineTabPrefix state,
    _EditableLongLineWidthModel widthModel,
    int offset,
    int lineLength,
  ) {
    _debugLastLongLineTabLookupProbeCount = 0;
    final clamped = offset.clamp(0, state.scannedUntil);
    if (!state.sawTab) return (extra: 0.0, exact: true);
    if (clamped == state.scannedUntil) return (extra: state.tabExtra, exact: true);
    final cached = state.cachedExtraForOffset(clamped);
    if (cached != null) return (extra: cached, exact: true);
    final checkpoint = state.checkpointForOffset(clamped);
    if (checkpoint.offset == clamped) return (extra: checkpoint.extra, exact: true);

    final requested = clamped - checkpoint.offset;
    _beginLongLineReadBudgetFrame(resetIdleQuery: true);
    if (_longLineReadBudgetRemaining < requested) {
      _debugLongLineTabLookupBlockedCount++;
      _deferredLongLineHydration.add(identity);
      _scheduleDeferredLongLineHydration();
      return (extra: checkpoint.extra, exact: false);
    }
    _longLineReadBudgetRemaining -= requested;
    final extra = _scanLongLineTabExtraRange(
      line,
      state,
      widthModel,
      start: checkpoint.offset,
      end: clamped,
      initialExtra: checkpoint.extra,
      lineLength: lineLength,
    );
    state.cacheExtraForOffset(clamped, extra);
    return (extra: extra, exact: true);
  }

  Map<int, double>? _longLineLogicalXsForOffsets(
    Object identity,
    int line,
    _EditableLongLineWidthModel widthModel,
    _EditableLongLineTabPrefix state,
    List<int> sortedOffsets,
    int lineLength,
  ) {
    _debugLastLongLineTabLookupProbeCount = 0;
    if (sortedOffsets.isEmpty) return const <int, double>{};
    if (!state.sawTab) {
      return <int, double>{for (final offset in sortedOffsets) offset: widthModel.xForOffset(offset, lineLength)};
    }
    final revision = Object.hash(
      widthModel.revision,
      state.scannedUntil,
      state.checkpointCount,
      state.tabExtra,
      state.averageAdvance,
    );
    var progress = _longLineTabBatchPrefixes[identity];
    if (progress == null || !progress.matches(revision, sortedOffsets)) {
      final checkpoint = state.checkpointForOffset(sortedOffsets.first);
      progress = _EditableLongLineTabBatchProgress(
        revision: revision,
        offsets: List<int>.unmodifiable(sortedOffsets),
        scanOffset: checkpoint.offset,
        extra: checkpoint.extra,
      );
      _longLineTabBatchPrefixes[identity] = progress;
    }
    if (progress.complete) return progress.values;

    _beginLongLineReadBudgetFrame(resetIdleQuery: true);
    while (!progress.complete) {
      final target = progress.offsets[progress.nextIndex];
      if (target < progress.scanOffset) throw StateError('批量 tab prefix offset 必须升序');
      if (target == progress.scanOffset) {
        progress.values[target] = widthModel.xForOffset(target, lineLength) + progress.extra;
        progress.nextIndex++;
        continue;
      }
      if (_longLineReadBudgetRemaining <= 0) {
        _debugLongLineTabLookupBlockedCount++;
        _deferredLongLineHydration.add(identity);
        _scheduleDeferredLongLineHydration();
        return null;
      }
      final step = math.min(
        target - progress.scanOffset,
        math.min(LongLineBidiPipeline.maxChunkCodeUnits, _longLineReadBudgetRemaining),
      );
      final end = progress.scanOffset + step;
      progress.extra = _scanLongLineTabExtraRange(
        line,
        state,
        widthModel,
        start: progress.scanOffset,
        end: end,
        initialExtra: progress.extra,
        lineLength: lineLength,
      );
      progress.scanOffset = end;
      _longLineReadBudgetRemaining -= step;
    }
    return progress.values;
  }

  double _scanLongLineTabExtraRange(
    int line,
    _EditableLongLineTabPrefix state,
    _EditableLongLineWidthModel widthModel, {
    required int start,
    required int end,
    required double initialExtra,
    required int lineLength,
  }) {
    final lineStart = controller.document.lineStart(line);
    final text = controller.document.getText(lineStart + start, lineStart + end);
    RenderEditableLine.debugRecordRenderRead(text.length);
    final styleRuns = _tabStyleRunsForWindow(line, text, textStart: start, lineLength: lineLength);
    final defaultStopExtent = _prototypeSpaceAdvance() * _config.tabSize;
    var baseAdvance = widthModel.xForOffset(start, lineLength);
    var extra = initialExtra;
    var styleRunIndex = 0;
    for (var index = 0; index < text.length; index++) {
      _debugLastLongLineTabLookupProbeCount++;
      final logicalOffset = start + index;
      if (text.codeUnitAt(index) == 0x09) {
        while (styleRunIndex < styleRuns.length && styleRuns[styleRunIndex].end <= index) {
          styleRunIndex++;
        }
        final stopExtent =
            styleRunIndex < styleRuns.length &&
                styleRuns[styleRunIndex].start <= index &&
                index < styleRuns[styleRunIndex].end
            ? styleRuns[styleRunIndex].stopExtent
            : defaultStopExtent;
        final current = baseAdvance + extra;
        final target = stopExtent <= precisionErrorTolerance
            ? current + state.averageAdvance
            : ((current + stopExtent * 1e-6) / stopExtent).floor() * stopExtent + stopExtent;
        extra = target - (baseAdvance + widthModel.advanceAt(logicalOffset));
      }
      baseAdvance += widthModel.advanceAt(logicalOffset);
    }
    _debugMaxLongLineTabLookupProbeCount = math.max(
      _debugMaxLongLineTabLookupProbeCount,
      _debugLastLongLineTabLookupProbeCount,
    );
    return extra;
  }

  double _longLineEstimatedExtent(
    _EditableLongLineWidthModel widthModel,
    _EditableLongLineTabPrefix? tabState,
    int lineLength,
  ) => math.max(
    widthModel.extentFor(lineLength, _viewportWidth),
    tabState?.sawTab == true ? tabState!.retainedExtent : 0.0,
  );

  double _longLineVisualAlignedExtent(double contentExtent, [Object? identity]) =>
      math.max(contentExtent, _longLineVisualAlignmentContentWidth(identity));

  double _longLineVisualAlignmentShift(double contentExtent, [Object? identity]) {
    final slack = _longLineVisualAlignmentContentWidth(identity) - contentExtent;
    if (slack <= precisionErrorTolerance) return 0.0;
    final factor = switch (_config.textAlign) {
      TextAlign.left => 0.0,
      TextAlign.right => 1.0,
      TextAlign.center => 0.5,
      TextAlign.start || TextAlign.justify => _config.textDirection == TextDirection.rtl ? 1.0 : 0.0,
      TextAlign.end => _config.textDirection == TextDirection.rtl ? 0.0 : 1.0,
    };
    return slack * factor;
  }

  double _longLineVisualAlignmentContentWidth([Object? identity]) {
    final visualTrailing = identity == null ? null : _longLineVisualTrailingExtents[identity];
    final known = identity == null ? null : _knownLineWidths[identity];
    final trailing = visualTrailing != null
        ? _knownWidthOverwriteMode
              ? visualTrailing.overwrite
              : visualTrailing.insert
        : known == null
        ? _knownWidthOverwriteMode
              ? math.max(_config.caretWidth, _prototypePreferredLineHeight() * 0.5) + 2.0
              : _config.caretWidth + 2.0
        : _knownWidthOverwriteMode
        ? known.overwriteTrailingExtent
        : known.insertTrailingExtent;
    return math.max(0.0, _viewportWidth - trailing);
  }

  int _longLineOffsetForLogicalX(
    Object identity,
    int line,
    _EditableLongLineWidthModel widthModel,
    _EditableLongLineTabPrefix? tabState,
    double x,
    int lineLength,
  ) {
    if (tabState == null || !tabState.sawTab) return widthModel.offsetForX(x, lineLength);
    var lower = 0;
    var upper = lineLength;
    while (lower < upper) {
      final middle = lower + ((upper - lower) >> 1);
      if (_longLineLogicalX(identity, line, widthModel, tabState, middle, lineLength) < x) {
        lower = middle + 1;
      } else {
        upper = middle;
      }
    }
    return lower.clamp(0, lineLength);
  }

  List<_EditableTabStyleRun> _tabStyleRunsForWindow(
    int line,
    String text, {
    required int textStart,
    required int lineLength,
  }) {
    if (!text.contains('\t') || _config.composer is! EditableWindowedComposer) {
      return const <_EditableTabStyleRun>[];
    }
    final span = _config.composer.compose(
      EditableLineContext.windowed(
        line: line,
        text: text,
        baseStyle: _config.textStyle,
        textStart: textStart,
        lineLength: lineLength,
      ),
    );
    assert(
      span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false) == text,
      'EditableComposer 合约被破坏：第 $line 行窗口装配输出的纯文本与行文本不一致。',
    );
    final runs = <_EditableTabStyleRun>[];
    var cursor = 0;
    void visit(InlineSpan current, TextStyle? inheritedStyle) {
      if (current is! TextSpan) {
        cursor += current.toPlainText(includeSemanticsLabels: false, includePlaceholders: false).length;
        return;
      }
      final effectiveStyle = inheritedStyle == null ? current.style : inheritedStyle.merge(current.style);
      final ownText = current.text;
      if (ownText != null && ownText.isNotEmpty) {
        final start = cursor;
        cursor += ownText.length;
        if (ownText.contains('\t')) {
          runs.add(
            _EditableTabStyleRun(
              start: start,
              end: cursor,
              stopExtent: _spaceAdvanceForStyle(effectiveStyle) * _config.tabSize,
            ),
          );
        }
      }
      final children = current.children;
      if (children == null) return;
      for (final child in children) {
        visit(child, effectiveStyle);
      }
    }

    visit(span, null);
    return runs;
  }

  double _spaceAdvanceForStyle(TextStyle? style) {
    final effectiveStyle = style ?? _config.textStyle;
    if (effectiveStyle == _config.textStyle) return _prototypeSpaceAdvance();
    final cached = _longLineStyledSpaceAdvances[effectiveStyle];
    if (cached != null) return cached;
    // 病态 composer 若每个 tab 都产生唯一样式，只精确测量有界数量；
    // 超出后回到基础网格，避免一帧构造无界 Paragraph。
    if (_longLineStyledSpaceAdvances.length >= 64) return _prototypeSpaceAdvance();
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: effectiveStyle),
      textDirection: _config.textDirection,
      textScaler: _config.textScaler,
    )..layout();
    RenderEditableLine.debugRecordParagraph(1);
    final measured = painter.width;
    painter.dispose();
    final advance = measured.isFinite && measured > precisionErrorTolerance ? measured : _prototypeSpaceAdvance();
    _longLineStyledSpaceAdvances[effectiveStyle] = advance;
    return advance;
  }

  bool _takeLongLineFrameReadBudget(Object identity) {
    _beginLongLineReadBudgetFrame(resetIdleQuery: true);
    if (_longLineReadBudgetRemaining < _longLineWindowCodeUnits) {
      _deferredLongLineHydration.add(identity);
      _scheduleDeferredLongLineHydration();
      return false;
    }
    _longLineReadBudgetRemaining -= _longLineWindowCodeUnits;
    _deferredLongLineHydration.remove(identity);
    return true;
  }

  void _beginLongLineReadBudgetFrame({bool resetIdleQuery = false}) {
    try {
      // 白盒几何查询可在帧外直接调用 scope；它们不属于上一个
      // render frame，不能因为没有新 timestamp 而永久消耗同一份预算。
      if (resetIdleQuery &&
          SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle &&
          !_longLineIdleReadBudgetEpochActive) {
        _longLineIdleReadBudgetEpochActive = true;
        _longLineReadBudgetFrameActive = false;
        scheduleMicrotask(() {
          _longLineIdleReadBudgetEpochActive = false;
        });
      }
    } catch (_) {
      // headless 路径继续把 scope 生命周期视作同一预算周期。
    }
    if (_longLineReadBudgetFrameActive) return;
    _longLineReadBudgetFrameActive = true;
    _longLineReadBudgetRemaining = _longLineViewportReadCodeUnitLimit;
    _longLineBidiHydrationChunksThisFrame.clear();
    _longLineVisualEstimateWorkRemaining = longLineVisualEstimateFrameWorkLimit;
    _longLineVisualEstimateAllocationRemaining = longLineVisualEstimateFrameAllocationLimit;
    _debugCurrentFrameLongLineVisualEstimateWork = 0;
    _debugCurrentFrameLongLineVisualEstimateAllocations = 0;
    RenderEditableLine.debugBeginRenderReadFrame();
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _longLineReadBudgetFrameActive = false;
      });
    } catch (_) {
      // headless 白盒没有帧时把一次 scope 生命周期视作同一预算周期。
    }
  }

  int _takeAdditionalLongLineReadBudget(int requested) {
    _beginLongLineReadBudgetFrame();
    final granted = math.min(requested, _longLineReadBudgetRemaining);
    _longLineReadBudgetRemaining -= granted;
    return granted;
  }

  void _scheduleDeferredLongLineHydration() {
    if (_disposed || _deferredLongLineHydrationScheduled) return;
    _deferredLongLineHydrationScheduled = true;
    try {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        _deferredLongLineHydrationScheduled = false;
        if (_disposed) return;
        final pending = List<Object>.of(_deferredLongLineHydration);
        _deferredLongLineHydration.clear();
        final mountedByIdentity = <Object, RenderEditableLine>{
          for (final line in _mounted.values)
            if (pending.contains(line.identity)) line.identity: line,
        };
        final identities = <Object>[
          for (final identity in pending)
            if (mountedByIdentity.containsKey(identity)) identity,
        ];
        if (identities.isEmpty) return;
        final start = _longLineHydrationRotation % identities.length;
        final chunkCapacity = math.max(1, _longLineViewportReadCodeUnitLimit ~/ LongLineBidiPipeline.maxChunkCodeUnits);
        _longLineHydrationRotation = (start + math.max(1, chunkCapacity).toInt()) % identities.length;
        for (var index = 0; index < identities.length; index++) {
          final identity = identities[(start + index) % identities.length];
          mountedByIdentity[identity]!.retryLongLineWindowHydration();
        }
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    } catch (_) {
      _deferredLongLineHydrationScheduled = false;
      // headless scope 没有帧调度器，只保留有界占位，不强制初始化 binding。
    }
  }

  int? _boundedGraphemeBoundaryBeforeOrAt(
    TextDocument document,
    int offset, {
    required int lowerBound,
    required int upperBound,
  }) {
    final effective = offset.clamp(lowerBound, upperBound);
    if (effective == lowerBound || effective == upperBound) return effective;
    var readStart = math.max(lowerBound, effective - _longLineBoundaryGuardCodeUnits);
    var readEnd = math.min(upperBound, effective + _longLineBoundaryGuardCodeUnits);
    var text = document.getText(readStart, readEnd);
    RenderEditableLine.debugRecordRenderRead(text.length);
    if (text.isEmpty) return effective;
    if (_isLowSurrogate(text.codeUnitAt(0))) {
      text = text.substring(1);
      readStart++;
    }
    if (text.isNotEmpty && _isHighSurrogate(text.codeUnitAt(text.length - 1))) {
      text = text.substring(0, text.length - 1);
      readEnd--;
    }
    if (readStart > lowerBound && text.isNotEmpty && _boundedBoundaryMayDependOnPrefix(document, readStart, text)) {
      return null;
    }
    final local = effective - readStart;
    if (local < 0 || local > text.length) return null;
    var cursor = 0;
    for (final grapheme in text.characters) {
      if (local == cursor) return effective;
      final next = cursor + grapheme.length;
      if (local < next) {
        if ((cursor == 0 && readStart > lowerBound) || (next == text.length && readEnd < upperBound)) {
          return null;
        }
        return readStart + cursor;
      }
      cursor = next;
    }
    return local == cursor ? effective : null;
  }

  static bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdbff;

  static bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xdc00 && codeUnit <= 0xdfff;

  bool _boundedBoundaryMayDependOnPrefix(TextDocument document, int boundary, String suffix) {
    final prefixStart = math.max(0, boundary - 2);
    final prefix = document.getText(prefixStart, boundary);
    RenderEditableLine.debugRecordRenderRead(prefix.length);
    if (prefix.isEmpty || suffix.isEmpty) return false;
    final previous = prefix.runes.last;
    final next = suffix.runes.first;
    if (previous == 0x0d && next == 0x0a) return true;
    if (_isGraphemeExtendLike(next) || _isGraphemePrepend(previous)) return true;
    if (previous == 0x200d || _isUnicodeMark(previous)) return true;
    if (_isRegionalIndicator(previous) && _isRegionalIndicator(next)) return true;
    return _hangulPairDoesNotBreak(previous, next);
  }

  static bool _isGraphemeExtendLike(int rune) =>
      rune == 0x200c ||
      rune == 0x200d ||
      (rune >= 0x1f3fb && rune <= 0x1f3ff) ||
      (rune >= 0xe0020 && rune <= 0xe007f) ||
      _isUnicodeMark(rune);

  static bool _isUnicodeMark(int rune) => RegExp(r'\p{M}', unicode: true).hasMatch(String.fromCharCode(rune));

  static bool _isGraphemePrepend(int rune) =>
      (rune >= 0x0600 && rune <= 0x0605) ||
      rune == 0x06dd ||
      rune == 0x070f ||
      (rune >= 0x0890 && rune <= 0x0891) ||
      rune == 0x08e2 ||
      rune == 0x0d4e ||
      rune == 0x110bd ||
      rune == 0x110cd ||
      (rune >= 0x111c2 && rune <= 0x111c3) ||
      rune == 0x1193f ||
      rune == 0x11941 ||
      rune == 0x11a3a ||
      (rune >= 0x11a84 && rune <= 0x11a89) ||
      rune == 0x11d46 ||
      rune == 0x11f02 ||
      (rune >= 0x13430 && rune <= 0x1343f);

  static bool _isRegionalIndicator(int rune) => rune >= 0x1f1e6 && rune <= 0x1f1ff;

  static bool _hangulPairDoesNotBreak(int previous, int next) {
    const sBase = 0xac00;
    const sCount = 11172;
    const tCount = 28;
    final previousIsL = previous >= 0x1100 && previous <= 0x115f || previous >= 0xa960 && previous <= 0xa97c;
    final previousIsV = previous >= 0x1160 && previous <= 0x11a7 || previous >= 0xd7b0 && previous <= 0xd7c6;
    final previousIsT = previous >= 0x11a8 && previous <= 0x11ff || previous >= 0xd7cb && previous <= 0xd7fb;
    final previousSyllable = previous >= sBase && previous < sBase + sCount ? (previous - sBase) % tCount : -1;
    final previousIsLv = previousSyllable == 0;
    final previousIsLvt = previousSyllable > 0;
    final nextIsL = next >= 0x1100 && next <= 0x115f || next >= 0xa960 && next <= 0xa97c;
    final nextIsV = next >= 0x1160 && next <= 0x11a7 || next >= 0xd7b0 && next <= 0xd7c6;
    final nextIsT = next >= 0x11a8 && next <= 0x11ff || next >= 0xd7cb && next <= 0xd7fb;
    final nextSyllable = next >= sBase && next < sBase + sCount ? (next - sBase) % tCount : -1;
    final nextIsLv = nextSyllable == 0;
    final nextIsLvt = nextSyllable > 0;
    if (previousIsL && (nextIsL || nextIsV || nextIsLv || nextIsLvt)) return true;
    if ((previousIsLv || previousIsV) && (nextIsV || nextIsT)) return true;
    return (previousIsLvt || previousIsT) && nextIsT;
  }

  /// 行装配：经 [EditableRenderConfig.composer] 产出排版 span。
  ///
  /// debug 断言装配合约——输出纯文本必须与行文本一致（编辑坐标以纯文本
  /// offset 为准，装配只准换样式不准换内容）。
  InlineSpan spanFor(int index) {
    final text = lineTextOf(index);
    return spanForText(index, text);
  }

  /// 装配已读取文本；[completeLine] 为 false 时旧 composer 明确降级纯文本。
  InlineSpan spanForText(
    int index,
    String text, {
    double tabInitialAdvance = 0.0,
    bool completeLine = true,
    int textStart = 0,
    int? lineLength,
    TextDirection? textDirection,
  }) {
    if (identical(_config.composer, EditableComposer.plain)) {
      final span = TextSpan(text: text, style: _config.textStyle);
      if (!text.contains('\t')) return span;
      return applyEditableTabStops(
        span,
        tabSize: _config.tabSize,
        textDirection: textDirection ?? _config.textDirection,
        textScaler: _config.textScaler,
        initialAdvance: tabInitialAdvance,
      );
    }
    final acceptsLegacyComposer = completeLine || _config.composer is EditableWindowedComposer;
    final context = completeLine
        ? EditableLineContext(line: index, text: text, baseStyle: _config.textStyle)
        : EditableLineContext.windowed(
            line: index,
            text: text,
            baseStyle: _config.textStyle,
            textStart: textStart,
            lineLength: lineLength ?? textStart + text.length,
          );
    final span = acceptsLegacyComposer
        ? _config.composer.compose(context)
        : TextSpan(text: text, style: _config.textStyle);
    if (!acceptsLegacyComposer) {
      assert(() {
        RenderEditableLine.debugLongLineComposerFallbackCount++;
        return true;
      }());
    }
    if (_containsPlaceholderSpan(span)) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('EditableComposer 不支持 PlaceholderSpan / WidgetSpan。'),
        ErrorDescription('第 $index 行的 composer 输出包含 inline placeholder；editable 行只支持与文档 UTF-16 坐标一一对应的文本 span。'),
        ErrorHint('请改用 EditableDecoration 或基于公开几何门面的 overlay 呈现非文本内容。'),
      ]);
    }
    assert(
      span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false) == text,
      'EditableComposer 合约被破坏：第 $index 行装配输出的纯文本与行文本不一致。',
    );
    if (!text.contains('\t')) return span;
    return applyEditableTabStops(
      span,
      tabSize: _config.tabSize,
      textDirection: textDirection ?? _config.textDirection,
      textScaler: _config.textScaler,
      initialAdvance: tabInitialAdvance,
    );
  }

  static bool _containsPlaceholderSpan(InlineSpan span) {
    if (span is PlaceholderSpan) return true;
    if (span is! TextSpan) return false;
    final children = span.children;
    if (children == null) return false;
    for (final child in children) {
      if (_containsPlaceholderSpan(child)) return true;
    }
    return false;
  }

  /// 为已经按最终左到右顺序排列的 visual window 装配 synthetic Paragraph。
  ///
  /// synthetic 方向控制符只使用基础样式；每段真实正文仍分别获得正确的原文
  /// [EditableLineContext.windowed]、composer 样式与逻辑 tab 网格。最终纯文本
  /// 必须与 [EditableLineLayoutWindow.paragraphText] 逐 UTF-16 code unit 一致。
  InlineSpan spanForVisualWindow(int index, EditableLineLayoutWindow window) {
    if (!window.isVisual) throw ArgumentError.value(window, 'window', '必须是 visual window');
    final paragraph = window.paragraphText;
    final children = <InlineSpan>[];
    var cursor = 0;
    for (var fragmentIndex = 0; fragmentIndex < window.visualFragments.length; fragmentIndex++) {
      final fragment = window.visualFragments[fragmentIndex];
      final content = window.fragmentContentRanges[fragmentIndex];
      if (cursor < content.start) {
        children.add(TextSpan(text: paragraph.substring(cursor, content.start), style: _config.textStyle));
      }
      children.add(
        spanForText(
          index,
          fragment.text,
          tabInitialAdvance: fragment.logicalTabPrefix,
          completeLine: false,
          textStart: fragment.lineStart,
          lineLength: window.lineLength,
          textDirection: fragment.isRtl ? TextDirection.rtl : TextDirection.ltr,
        ),
      );
      cursor = content.end;
    }
    if (cursor < paragraph.length) {
      children.add(TextSpan(text: paragraph.substring(cursor), style: _config.textStyle));
    }
    final span = TextSpan(children: List<InlineSpan>.unmodifiable(children));
    assert(
      span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false) == paragraph,
      'visual window 装配输出必须与 synthetic Paragraph 完全一致。',
    );
    return span;
  }

  /// 计算行绘制快照。
  EditableLinePaint paintStateOf(int index) {
    final doc = controller.document;
    if (index < 0 || index >= doc.lineCount) return const EditableLinePaint.empty();
    if (!_paintEditingState) {
      _debugLastSelectionQueryProbeCount = 0;
      _debugLastSelectionIndexBuildProbeCount = 0;
      return const EditableLinePaint.empty();
    }
    final lineStart = doc.lineStart(index);
    final lineLen = doc.lineLength(index);
    final lineEnd = lineStart + lineLen;

    List<EditableLineSelectionPaint>? selections;
    List<EditableLineCaretPaint>? carets;
    var paintsDragDropCaret = false;
    var primaryThinCaretOnLine = false;
    _debugLastSelectionQueryProbeCount = 0;
    _debugLastSelectionIndexBuildProbeCount = 0;
    final dragDropCaret = _dragDropCaret;
    final selectionIndex = _selectionIndexFor(controller.selections);
    _debugLastSelectionQueryProbeCount = _debugLastSelectionIndexBuildProbeCount;
    if (_selectionVisible && selectionIndex.hasNonCollapsedSelections) {
      _debugLastSelectionQueryProbeCount += selectionIndex.visitSelections(lineStart, lineEnd, (selection) {
        if (selection.isCollapsed || selection.start > lineEnd || selection.end <= lineStart) return;
        (selections ??= <EditableLineSelectionPaint>[]).add(
          EditableLineSelectionPaint(
            start: (selection.start - lineStart).clamp(0, lineLen),
            end: (selection.end - lineStart).clamp(0, lineLen),
            selectsNewline:
                selection.end > lineEnd &&
                index < doc.lineCount - 1 &&
                (lineLen == 0 || selection.start != lineStart || selection.end != lineEnd + 1),
          ),
        );
      });
    }
    // 临时 drop caret 存在时隐藏全部真实 caret，非折叠选区背景仍保留。
    if (_focused && dragDropCaret == null) {
      final paintsOverwriteCaret = controller.overwriteMode && !controller.hasActiveImeComposition;
      final keepSelectAllCaret = _keepCaretAtPreSelectAllPosition && controller.selectAllCaretDisplayOffset != null;
      _debugLastSelectionQueryProbeCount += selectionIndex.visitCarets(lineStart, lineEnd, (entry) {
        final position = entry.position;
        final active = position.offset;
        if (doc.lineIndexOf(active) != index) return;
        // 全文档选区且开关关闭：primary caret 不画在选区末尾端，改画在全选前位置
        if (keepSelectAllCaret &&
            entry.primary &&
            entry.selection.anchor == 0 &&
            entry.selection.active >= doc.length) {
          return;
        }
        final overwriteEnd = paintsOverwriteCaret && entry.selection.isCollapsed
            ? _overwriteEndInLine(active, lineStart, lineEnd) - lineStart
            : -1;
        (carets ??= <EditableLineCaretPaint>[]).add(
          EditableLineCaretPaint(
            offset: active - lineStart,
            upstream: position.affinity == TextAffinity.upstream,
            overwriteEnd: overwriteEnd,
          ),
        );
        if (entry.primary && overwriteEnd < active - lineStart) primaryThinCaretOnLine = true;
      });
      // 全文档选区保留原光标：在全选前光标所在行补画 primary caret
      if (keepSelectAllCaret) {
        final anchor = controller.selectAllCaretDisplayOffset!;
        if (doc.lineIndexOf(anchor) == index) {
          final anchorLineStart = doc.lineStart(doc.lineIndexOf(anchor));
          (carets ??= <EditableLineCaretPaint>[]).add(
            EditableLineCaretPaint(offset: anchor - anchorLineStart, upstream: false),
          );
        }
      }
    }
    // 外部平台拖入 hover 不应抢焦点；未聚焦编辑器也必须显示唯一落点。
    if (dragDropCaret != null) {
      final active = dragDropCaret.offset;
      if (active >= lineStart && active <= lineEnd && doc.lineIndexOf(active) == index) {
        (carets ??= <EditableLineCaretPaint>[]).add(
          EditableLineCaretPaint(offset: active - lineStart, upstream: dragDropCaret.affinity == TextAffinity.upstream),
        );
        paintsDragDropCaret = true;
      }
    }

    var composingStart = -1;
    var composingEnd = -1;
    final composing = controller.composing;
    if (composing.isValid && !composing.isCollapsed && composing.start < lineEnd && composing.end > lineStart) {
      composingStart = (composing.start - lineStart).clamp(0, lineLen);
      composingEnd = (composing.end - lineStart).clamp(0, lineLen);
    }

    return EditableLinePaint(
      selections: selections ?? const <EditableLineSelectionPaint>[],
      carets: carets ?? const <EditableLineCaretPaint>[],
      composingStart: composingStart,
      composingEnd: composingEnd,
      caretVisible: carets != null && (_regularCaretVisible || paintsDragDropCaret),
      primaryCaretSuppressed: _primaryCaretMotionActive && primaryThinCaretOnLine,
    );
  }

  _SelectionPaintIndex _selectionIndexFor(EditableSelectionSet selections) {
    final projectionRevision = lineProjection?.mappingRevision ?? 0;
    if (!identical(_selectionPaintIndexSource, selections) ||
        _selectionPaintIndex == null ||
        !identical(_selectionPaintIndexProjection, lineProjection) ||
        _selectionPaintIndexDocRevision != controller.docRevision ||
        _selectionPaintIndexProjectionRevision != projectionRevision) {
      _selectionPaintIndexSource = selections;
      _selectionPaintIndexProjection = lineProjection;
      _selectionPaintIndexDocRevision = controller.docRevision;
      _selectionPaintIndexProjectionRevision = projectionRevision;
      _selectionPaintIndex = _SelectionPaintIndex(
        selections,
        projection: lineProjection,
        document: controller.document,
      );
      _debugLastSelectionIndexBuildProbeCount = 1;
    }
    return _selectionPaintIndex!;
  }

  int _overwriteEndInLine(int offset, int lineStart, int lineEnd) =>
      nextTextGraphemeBoundary(controller.document, offset, lowerBound: lineStart, upperBound: lineEnd);

  // ===========================================================================
  // mounted 行注册表
  // ===========================================================================

  void registerLine(int index, RenderEditableLine line) {
    _mounted[index] = line;
  }

  void unregisterLine(int index, RenderEditableLine line) {
    if (!identical(_mounted[index], line)) return;
    _mounted.remove(index);
    _longLineState?.pendingLongLineBidiResolves.remove(line.identity);
    _cancelUnobservedActiveLongLineBidiResolve(line.identity);
    _forgetLongLineCoverage(line.identity);
    _releaseLongLineAverageIfUnretained(line.identity);
    _trimLongLineBidiPipelines(preserveIdentity: Object());
  }

  /// mounted render 热换身份时清除旧身份的瞬态窗口，保留有界宽度历史。
  void lineIdentityChanged(Object previousIdentity) {
    _longLineState?.pendingLongLineBidiResolves.remove(previousIdentity);
    _cancelUnobservedActiveLongLineBidiResolve(previousIdentity);
    _forgetLongLineCoverage(previousIdentity);
    _releaseLongLineAverageIfUnretained(previousIdentity);
  }

  void _cancelUnobservedActiveLongLineBidiResolve(Object identity) {
    if (_mounted.values.any((line) => identical(line.identity, identity))) return;
    final state = _longLineState;
    if (state == null) return;
    final pipeline = state.longLineBidiPipelines[identity];
    if (pipeline == null || !state.activeLongLineBidiResolves.contains(pipeline)) return;
    _disposeLongLineBidiPipeline(identity);
    state.longLineBidiEstimateRevisions.remove(identity);
    state.longLineBidiGenerations.remove(identity);
    state.longLineVisualMetricRevisions.remove(identity);
    _clearLongLineBidiFailure(identity);
  }

  /// mounted 行只读视图（视图层做命中 / 可见性用）。
  Map<int, RenderEditableLine> get mountedLines => _mounted;

  /// 视口选区层的重绘入口；空值表示独立行宿主仍自行绘制编辑状态。
  VoidCallback? repaintSelectionLayer;

  RenderEditableLine? mountedLineAt(int index) => _mounted[index];

  /// 行渲染 layout 时回写本轮排版上下界，供未挂载行共享相同几何。
  void reportLayoutWidth(double width, {double minWidth = 0.0}) {
    _layoutWidth = width;
    _layoutMinWidth = minWidth;
  }

  /// 当前行排版宽度（无 mounted 行时为最近一次值，初始无穷 = nowrap 语义）。
  double get layoutWidth => _layoutWidth;

  /// 上报一个已排版 nowrap 行的正文宽度与两种 caret 尾距。
  void reportLineWidth(
    Object identity, {
    required double textWidth,
    required double insertTrailingExtent,
    required double overwriteTrailingExtent,
    bool alignToViewport = false,
  }) {
    if (_config.softWrap ||
        !textWidth.isFinite ||
        textWidth < 0.0 ||
        !insertTrailingExtent.isFinite ||
        insertTrailingExtent < 0.0 ||
        !overwriteTrailingExtent.isFinite ||
        overwriteTrailingExtent < 0.0) {
      return;
    }
    final width = _EditableKnownLineWidth(
      textWidth: textWidth,
      insertTrailingExtent: insertTrailingExtent,
      overwriteTrailingExtent: overwriteTrailingExtent,
      alignToViewport: alignToViewport,
    );
    final previous = _knownLineWidths[identity];
    if (previous != null &&
        (previous.textWidth - width.textWidth).abs() <= precisionErrorTolerance &&
        (previous.insertTrailingExtent - width.insertTrailingExtent).abs() <= precisionErrorTolerance &&
        (previous.overwriteTrailingExtent - width.overwriteTrailingExtent).abs() <= precisionErrorTolerance &&
        previous.alignToViewport == width.alignToViewport) {
      return;
    }
    _knownLineWidths[identity] = width;
    if (_knownLineWidths.length > _knownLineWidthCapacity) {
      Object? narrowest;
      var narrowestWidth = double.infinity;
      for (final entry in _knownLineWidths.entries) {
        final effective = _effectiveKnownLineWidth(entry.value);
        if (effective >= narrowestWidth) continue;
        narrowest = entry.key;
        narrowestWidth = effective;
      }
      if (narrowest != null && !identical(narrowest, identity)) {
        _knownLineWidths.remove(narrowest);
        _releaseLongLineAverageIfUnretained(narrowest);
      } else if (narrowest != null && previous == null) {
        _knownLineWidths.remove(narrowest);
        _releaseLongLineAverageIfUnretained(narrowest);
      }
    }
    _publishKnownLineWidthMaximum();
  }

  static bool _longLineTilesShareShapingRun(LongLineVisualTile left, LongLineVisualTile right) =>
      left.paintRunIndex == right.paintRunIndex &&
      left.level == right.level &&
      (left.end == right.start || right.end == left.start);

  double? _measureLongLineVisualTileWithHalo(
    Object identity,
    int line,
    EditableLineLayoutWindow window,
    LongLineVisualIndex visualIndex,
    int tileIndex,
  ) {
    final tile = visualIndex.tiles[tileIndex];
    var contextStart = tile.start;
    var contextEnd = tile.end;
    if (tileIndex > 0 && _longLineTilesShareShapingRun(visualIndex.tiles[tileIndex - 1], tile)) {
      contextStart = math.min(contextStart, visualIndex.tiles[tileIndex - 1].start);
      contextEnd = math.max(contextEnd, visualIndex.tiles[tileIndex - 1].end);
    }
    if (tileIndex + 1 < visualIndex.tiles.length &&
        _longLineTilesShareShapingRun(tile, visualIndex.tiles[tileIndex + 1])) {
      contextStart = math.min(contextStart, visualIndex.tiles[tileIndex + 1].start);
      contextEnd = math.max(contextEnd, visualIndex.tiles[tileIndex + 1].end);
    }
    if (contextEnd - contextStart > EditableLineLayoutWindow.defaultVisualParagraphCodeUnitLimit) return null;
    final text = visualIndex.text.substring(contextStart, contextEnd);
    var tabInitialAdvance = 0.0;
    if (text.contains('\t')) {
      final widthModel = _longLineWidthModels[identity];
      if (widthModel == null) return null;
      final tabState = _validLongLineTabPrefix(
        identity,
        widthModel,
        _longLineAverageAdvances[identity] ?? window.averageAdvance,
      );
      final prefix = _longLineLogicalXLookup(identity, line, widthModel, tabState, contextStart, window.lineLength);
      if (!prefix.exact) return null;
      tabInitialAdvance = prefix.x;
    }
    final span = spanForText(
      line,
      text,
      tabInitialAdvance: tabInitialAdvance,
      completeLine: false,
      textStart: contextStart,
      lineLength: window.lineLength,
      textDirection: tile.isRtl ? TextDirection.rtl : TextDirection.ltr,
    );
    final painter = TextPainter(
      text: span,
      textDirection: tile.isRtl ? TextDirection.rtl : TextDirection.ltr,
      textScaler: _config.textScaler,
      strutStyle: strutStyleFor(span),
    )..layout();
    RenderEditableLine.debugRecordParagraph(text.length);
    try {
      final localStart = tile.start - contextStart;
      final localEnd = tile.end - contextStart;
      final start = painter.getOffsetForCaret(TextPosition(offset: localStart), Rect.zero).dx;
      final end = painter
          .getOffsetForCaret(TextPosition(offset: localEnd, affinity: TextAffinity.upstream), Rect.zero)
          .dx;
      final width = (end - start).abs();
      _debugLongLineVisualHaloMeasurementCount++;
      return width.isFinite && width >= 0.0 ? width : null;
    } finally {
      painter.dispose();
    }
  }

  /// 把 visual Paragraph 内每个稳定 tile 的 shape 宽度回填到全行视觉前缀树。
  void reportLongLineVisualTileWidths(
    Object identity,
    EditableLineLayoutWindow window,
    TextPainter painter, {
    int? line,
  }) {
    if (!window.isVisual ||
        _longLineBidiGenerations[identity] != window.visualGeneration ||
        window.visualFirstTile < 0 ||
        window.visualEndTile <= window.visualFirstTile) {
      return;
    }
    final pipeline = _longLineBidiPipelines[identity];
    final result = pipeline?.resolvedResultOrNull;
    if (result == null) return;
    final visualIndex = result.visualIndex;
    if (window.visualTileCount != visualIndex.tiles.length || window.visualEndTile > visualIndex.tiles.length) return;
    var effectiveLine = line;
    if (effectiveLine == null) {
      for (final entry in _mounted.entries) {
        if (!identical(entry.value.identity, identity)) continue;
        effectiveLine = entry.key;
        break;
      }
    }
    final measured = <int, double>{};
    var metricsChanged = false;
    for (var tileIndex = window.visualFirstTile; tileIndex < window.visualEndTile; tileIndex++) {
      if (visualIndex.isMeasured(tileIndex)) continue;
      final tile = visualIndex.tiles[tileIndex];
      final range = window.paragraphRangeForContainedLogicalRange(tile.start, tile.end);
      if (range == null) return;
      final missesLeadingContext =
          tileIndex == window.visualFirstTile &&
          tileIndex > 0 &&
          _longLineTilesShareShapingRun(visualIndex.tiles[tileIndex - 1], tile);
      final missesTrailingContext =
          tileIndex == window.visualEndTile - 1 &&
          tileIndex + 1 < visualIndex.tiles.length &&
          _longLineTilesShareShapingRun(tile, visualIndex.tiles[tileIndex + 1]);
      // selection box 会在 ligature 横跨 tile seam 时把同一 glyph 重复分给两侧；
      // caret advance 差则对 seam 做唯一分摊，全部 tile 宽度仍严格可加。
      final width = missesLeadingContext || missesTrailingContext
          ? effectiveLine == null
                ? null
                : _measureLongLineVisualTileWithHalo(identity, effectiveLine, window, visualIndex, tileIndex)
          : () {
              final start = painter.getOffsetForCaret(TextPosition(offset: range.start), Rect.zero).dx;
              final end = painter
                  .getOffsetForCaret(TextPosition(offset: range.end, affinity: TextAffinity.upstream), Rect.zero)
                  .dx;
              return (end - start).abs();
            }();
      if (width == null) continue;
      if (!width.isFinite || width < 0.0) return;
      measured[tileIndex] = width;
      if ((visualIndex.widthOf(tileIndex) - width).abs() > precisionErrorTolerance) metricsChanged = true;
    }
    pipeline!.reportMeasuredWidths(measured);
    if (metricsChanged) {
      _longLineVisualMetricRevisions[identity] = (_longLineVisualMetricRevisions[identity] ?? 0) + 1;
      _scheduleLongLineVisualRefresh(identity, triggerWindow: window);
    }
  }

  /// 上报真实宽度并返回 paint、hit 与滚动范围共同使用的窗口几何。
  EditableLineLayoutWindow reportLongLineWindow(
    Object identity,
    EditableLineLayoutWindow window, {
    required double paragraphWidth,
    TextPainter? paragraphPainter,
    required double insertTrailingExtent,
    required double overwriteTrailingExtent,
  }) {
    if (_config.softWrap || !paragraphWidth.isFinite || paragraphWidth < 0.0) return window;
    if (_longLineBidiGenerations[identity] != window.visualGeneration) return window;
    final previousAlignmentContentWidth = window.isVisual ? _longLineVisualAlignmentContentWidth(identity) : 0.0;
    if (_longLineVisualRefreshPending.containsKey(identity) &&
        !identical(_longLineVisualRefreshPending[identity], window)) {
      _longLineVisualRefreshPending.remove(identity);
    }
    _longLineViewportRefreshPending.remove(identity);
    // 初始估值只作用于未测区间；局部比例字体测量不能改写整行字宽。
    final average = _longLineAverageAdvances[identity] ?? window.averageAdvance;
    _longLineAverageAdvances[identity] = average;
    final widthModel = _longLineWidthModels.putIfAbsent(identity, () => _EditableLongLineWidthModel(average));
    var originX = window.originX;
    if (window.isVisual) {
      // visual 前缀由 LongLineVisualIndex 的 Fenwick 树维护；把非连续片段按
      // textStart/textEnd 上报给逻辑宽度模型会污染 X9 gap 与反向 run。
    } else if (!window.placeholder && window.text.isNotEmpty && !window.text.contains('\t')) {
      if (paragraphPainter != null && _longLineTabPrefixes[identity]?.sawTab != true) {
        originX = _measureLogicalLongLineWindow(widthModel, window, paragraphPainter);
      } else if (paragraphPainter == null) {
        // 纯模型白盒可显式上报已经自行保证上下文的宽度；生产渲染恒传 painter。
        final measured = paragraphWidth / window.text.length;
        widthModel.reportWindow(window.textStart, window.textEnd, measured, window.lineLength);
      }
    }
    final pipelineExtent = window.isVisual
        ? _longLineBidiPipelines[identity]?.resolvedResultOrNull?.visualIndex.totalExtent ?? 0.0
        : 0.0;
    var estimatedTextWidth = window.isVisual
        ? pipelineExtent
        : _longLineEstimatedExtent(
            widthModel,
            _validLongLineTabPrefix(identity, widthModel, average),
            window.lineLength,
          );
    if (!window.isVisual && !window.placeholder) {
      // 已排版的行尾是当前坐标系的硬边界，不能继续保留估值制造可滚入的空白。
      if (window.textEnd == window.lineLength && window.textDirection == TextDirection.ltr) {
        estimatedTextWidth = originX + paragraphWidth;
      }
      window = window.withLogicalGeometry(originX: originX, textWidth: estimatedTextWidth);
    }
    // scope、RenderBox、paint 和 hit 必须使用同一份校正后的窗口几何。
    final left = window.originX;
    final right = math.max(left, left + paragraphWidth);
    _longLineCoverages[identity] = _EditableLongLineCoverage(
      left: left,
      right: right,
      atContentLeft: window.isVisual
          ? window.visualFirstTile == 0
          : _config.textDirection == TextDirection.ltr
          ? window.textStart == 0
          : window.textEnd == window.lineLength,
      atContentRight: window.isVisual
          ? window.visualEndTile == window.visualTileCount
          : _config.textDirection == TextDirection.ltr
          ? window.textEnd == window.lineLength
          : window.textStart == 0,
    );
    if (window.isVisual) {
      _longLineVisualTrailingExtents[identity] = (insert: insertTrailingExtent, overwrite: overwriteTrailingExtent);
    }
    reportLineWidth(
      identity,
      textWidth: estimatedTextWidth,
      insertTrailingExtent: insertTrailingExtent,
      overwriteTrailingExtent: overwriteTrailingExtent,
      alignToViewport: window.isVisual,
    );
    if (window.isVisual &&
        (_longLineVisualAlignmentContentWidth(identity) - previousAlignmentContentWidth).abs() >
            precisionErrorTolerance) {
      _scheduleLongLineVisualRefresh(identity, triggerWindow: window);
    }
    return window;
  }

  double _measureLogicalLongLineWindow(
    _EditableLongLineWidthModel model,
    EditableLineLayoutWindow window,
    TextPainter painter,
  ) {
    final index = model.index;
    final target = model.offsetForX(_horizontalPixels + _viewportWidth / 2, window.lineLength);
    final anchor = window.textStart == 0
        ? 0
        : index.anchorIn(window.shapingCoreStart, window.shapingCoreEnd, target) ?? window.textStart;
    double localX(int offset) => painter
        .getOffsetForCaret(TextPosition(offset: offset - window.textStart, affinity: TextAffinity.upstream), Rect.zero)
        .dx;
    final origin = math.max(0.0, index.xForOffset(anchor) - localX(anchor));
    final offsets = <int>[window.textStart];
    const step = _EditableLongLineWidthModel.chunkSize;
    for (var offset = (window.textStart ~/ step + 1) * step; offset < window.textEnd; offset += step) {
      offsets.add(offset);
    }
    if (anchor > window.textStart && anchor < window.textEnd && anchor % step != 0) {
      offsets.add(anchor);
      offsets.sort();
    }
    offsets.add(window.textEnd);
    final positions = <double>[];
    for (final offset in offsets) {
      final x = origin + (offset == window.textEnd ? painter.width : localX(offset));
      positions.add(math.max(positions.lastOrNull ?? origin, x));
    }
    index.record(offsets, positions);
    model.revision++;
    return origin;
  }

  /// 文档事务让这些行内容失效；最长行被改短/删除时立即回落到第二已知宽度。
  void invalidateLineWidths(Iterable<Object> identities) {
    if (_knownLineWidthsState == null && _longLineState == null) return;
    var changed = false;
    for (final identity in identities) {
      final preservedNoTabState = _preservedNoTabStateAfterLatestEdit(identity);
      changed = (_knownLineWidthsState?.remove(identity) != null) || changed;
      _forgetLongLineIdentity(identity);
      if (preservedNoTabState != null) _longLineState!.longLineTabPrefixes[identity] = preservedNoTabState;
    }
    if (changed) _publishKnownLineWidthMaximum();
  }

  _EditableLongLineTabPrefix? _preservedNoTabStateAfterLatestEdit(Object identity) {
    final state = _longLineState?.longLineTabPrefixes[identity];
    final changeSet = controller.lastChangeSet;
    if (state == null ||
        state.sawTab ||
        state.sawBidiControl ||
        state.sawStrongRtl ||
        changeSet == null ||
        changeSet.edits.length != 1) {
      return null;
    }
    int? line;
    for (final entry in _mounted.entries) {
      if (identical(entry.value.identity, identity)) {
        line = entry.key;
        break;
      }
    }
    if (line == null || line < 0 || line >= controller.document.lineCount) return null;
    final edit = changeSet.edits.single;
    if (edit.firstDirtyLine != line ||
        edit.removed.contains('\n') ||
        edit.inserted.contains('\n') ||
        edit.removed.contains('\t') ||
        edit.inserted.contains('\t') ||
        !_isSafePreservedLongLineAscii(edit.removed) ||
        !_isSafePreservedLongLineAscii(edit.inserted)) {
      return null;
    }
    final newLength = controller.document.lineLength(line);
    final oldLength = newLength - (edit.inserted.length - edit.removed.length);
    if (state.scannedUntil != oldLength) return null;
    final preserved = _EditableLongLineTabPrefix(state.averageAdvance, 0)..scannedUntil = newLength;
    return preserved;
  }

  static bool _isSafePreservedLongLineAscii(String text) {
    for (final codeUnit in text.codeUnits) {
      if (codeUnit < 0x20 || codeUnit > 0x7e) return false;
    }
    return true;
  }

  /// 某行身份是否仍由有界宽度索引保留。
  bool retainsLineWidth(Object identity) => _knownLineWidthsState?.containsKey(identity) ?? false;

  /// 某个超长行身份的正文窗口是否仍有效。
  bool retainsLongLineWindow(Object identity) => _longLineState?.longLineCoverages.containsKey(identity) ?? false;

  void _forgetLongLineIdentity(Object identity) {
    final state = _longLineState;
    if (state == null) return;
    _forgetLongLineCoverage(identity);
    state.longLineAverageAdvances.remove(identity);
    state.longLineWidthModels.remove(identity);
    state.longLineTabPrefixes.remove(identity);
    state.longLineTabBatchPrefixes.remove(identity);
    _disposeLongLineBidiPipeline(identity);
    state.longLineBidiEstimateRevisions.remove(identity);
    state.longLineBidiGenerations.remove(identity);
    state.longLineVisualMetricRevisions.remove(identity);
    state.pendingLongLineBidiResolves.remove(identity);
    _clearLongLineBidiFailure(identity);
    state.longLineBidiSafePrefixIdentities.remove(identity);
  }

  void _forgetLongLineCoverage(Object identity) {
    final state = _longLineState;
    if (state == null) return;
    state.longLineCoverages.remove(identity);
    state.longLineTabBatchPrefixes.remove(identity);
    state.longLineVisualTrailingExtents.remove(identity);
    state.longLineViewportRefreshPending.remove(identity);
    state.longLineVisualRefreshPending.remove(identity);
    state.deferredLongLineHydration.remove(identity);
  }

  void _releaseLongLineAverageIfUnretained(Object identity) {
    if (_knownLineWidthsState?.containsKey(identity) ?? false) return;
    if (_mounted.values.any((line) => identical(line.identity, identity))) return;
    final state = _longLineState;
    if (state == null) return;
    state.longLineAverageAdvances.remove(identity);
    state.longLineWidthModels.remove(identity);
    state.longLineTabPrefixes.remove(identity);
    state.longLineTabBatchPrefixes.remove(identity);
    _disposeLongLineBidiPipeline(identity);
    state.longLineBidiEstimateRevisions.remove(identity);
    state.longLineBidiGenerations.remove(identity);
    state.longLineVisualMetricRevisions.remove(identity);
    state.pendingLongLineBidiResolves.remove(identity);
    _clearLongLineBidiFailure(identity);
    state.longLineBidiSafePrefixIdentities.remove(identity);
  }

  void _clearKnownLineWidths() {
    final state = _longLineState;
    if (state != null) {
      state.longLineCoverages.clear();
      state.longLineAverageAdvances.clear();
      state.longLineWidthModels.clear();
      state.longLineTabPrefixes.clear();
      state.longLineTabBatchPrefixes.clear();
      for (final pipeline in state.longLineBidiPipelines.values) {
        pipeline.dispose();
      }
      state.longLineBidiPipelines.clear();
      state.activeLongLineBidiResolves.clear();
      state.longLineBidiEstimateRevisions.clear();
      state.longLineBidiGenerations.clear();
      state.longLineVisualMetricRevisions.clear();
      state.longLineVisualTrailingExtents.clear();
      state.pendingLongLineBidiResolves.clear();
      state.longLineBidiFailureAttempts.clear();
      state.longLineBidiTerminalErrors.clear();
      state.longLineBidiRetryScheduled.clear();
      state.longLineBidiSafePrefixIdentities.clear();
      state.longLineVisualRefreshPending.clear();
      state.deferredLongLineHydration.clear();
      state.longLineViewportRefreshPending.clear();
    }
    _longLineWindowRevision++;
    final widths = _knownLineWidthsState;
    final minimumExtent = _minimumCrossAxisExtent;
    if ((widths == null || widths.isEmpty) && (minimumExtent?.value ?? 0.0) == 0.0) return;
    widths?.clear();
    if (minimumExtent != null) minimumExtent.value = 0.0;
  }

  void _publishKnownLineWidthMaximum() {
    var maximum = 0.0;
    final widths = _knownLineWidthsState;
    if (widths != null) {
      for (final width in widths.values) {
        maximum = math.max(maximum, _effectiveKnownLineWidth(width));
      }
    }
    final current = _minimumCrossAxisExtent?.value ?? 0.0;
    if ((current - maximum).abs() > precisionErrorTolerance) {
      minimumCrossAxisExtent.value = maximum;
    }
  }

  double _effectiveKnownLineWidth(_EditableKnownLineWidth width) {
    final trailing = _knownWidthOverwriteMode ? width.overwriteTrailingExtent : width.insertTrailingExtent;
    final textWidth = width.alignToViewport ? math.max(width.textWidth, _viewportWidth - trailing) : width.textWidth;
    return math.max(0.0, textWidth) + trailing;
  }

  double _prototypeCodeUnitAdvance() {
    if (_longLinePrototypePainter != null &&
        _longLinePrototypeConfigRevision == _configRevision &&
        _longLinePrototypeSystemFontsRevision == _systemFontsRevision) {
      return math.max(_longLinePrototypePainter!.width / 64.0, precisionErrorTolerance);
    }
    _disposeLongLinePrototypePainter();
    final span = TextSpan(text: 'x' * 64, style: _config.textStyle);
    final painter = _longLinePrototypePainter = TextPainter(
      text: span,
      textDirection: _config.textDirection,
      textAlign: _config.textAlign,
      textScaler: _config.textScaler,
      strutStyle: strutStyleFor(span),
    );
    RenderEditableLine.debugRecordParagraph(64);
    painter.layout();
    _longLinePrototypeConfigRevision = _configRevision;
    _longLinePrototypeSystemFontsRevision = _systemFontsRevision;
    final fallback = math.max((_config.textStyle.fontSize ?? 14.0) * 0.5, 1.0);
    return painter.width.isFinite && painter.width > precisionErrorTolerance ? painter.width / 64.0 : fallback;
  }

  double _prototypePreferredLineHeight() {
    if (usesFixedLineHeight) return fixedLineHeight;
    _prototypeCodeUnitAdvance();
    return _longLinePrototypePainter!.preferredLineHeight;
  }

  double _prototypeSpaceAdvance() {
    final cached = _longLineSpaceAdvance;
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: _config.textStyle),
      textDirection: _config.textDirection,
      textScaler: _config.textScaler,
    )..layout();
    RenderEditableLine.debugRecordParagraph(1);
    final measured = painter.width;
    painter.dispose();
    final value = measured.isFinite && measured > precisionErrorTolerance ? measured : _prototypeCodeUnitAdvance();
    _longLineSpaceAdvance = value;
    return value;
  }

  /// 用有界分块宽度索引估算超长行 offset 的完整行横坐标。
  double estimatedLongLineXForOffset(int line, int offset, {TextAffinity affinity = TextAffinity.downstream}) {
    final length = controller.document.lineLength(line);
    final clamped = offset.clamp(0, length);
    final identity = _mounted[line]?.identity;
    final pipeline = identity == null ? null : _longLineBidiPipelines[identity];
    final result = pipeline?.resolvedResultOrNull;
    if (result != null) {
      final visual = result.visualIndex;
      final shift = _longLineVisualAlignmentShift(visual.totalExtent, identity);
      if (visual.tiles.isEmpty) return shift;
      final caret = visual.locateOffset(clamped, affinity: affinity);
      if (caret != null) return caret.visualX + shift;
    }
    final model = identity == null ? null : _longLineWidthModels[identity];
    final prototype = _prototypeCodeUnitAdvance();
    final tabState = identity == null || model == null
        ? null
        : _validLongLineTabPrefix(identity, model, _longLineAverageAdvances[identity] ?? prototype);
    final prefix = model == null
        ? prototype * clamped
        : _longLineLogicalX(identity!, line, model, tabState, clamped, length);
    final extent = model == null ? prototype * length : _longLineEstimatedExtent(model, tabState, length);
    return _config.textDirection == TextDirection.ltr ? prefix : extent - prefix;
  }

  /// 用视觉索引把完整行横坐标映射为保留 bidi seam affinity 的行内位置。
  TextPosition estimatedLongLinePositionForX(int line, double x, {TextAffinity affinity = TextAffinity.downstream}) {
    final length = controller.document.lineLength(line);
    final identity = _mounted[line]?.identity;
    final pipeline = identity == null ? null : _longLineBidiPipelines[identity];
    final result = pipeline?.resolvedResultOrNull;
    if (result != null) {
      final visual = result.visualIndex;
      if (visual.tiles.isEmpty) {
        return TextPosition(offset: affinity == TextAffinity.upstream ? length : 0, affinity: affinity);
      }
      final hit = visual.locateX(x - _longLineVisualAlignmentShift(visual.totalExtent, identity), affinity: affinity);
      if (hit != null) {
        var resolvedAffinity = affinity;
        final mapped = visual.locateOffset(hit.estimatedOffset, affinity: resolvedAffinity);
        if (mapped?.tileIndex != hit.tileIndex) {
          resolvedAffinity = affinity == TextAffinity.downstream ? TextAffinity.upstream : TextAffinity.downstream;
        }
        return TextPosition(offset: hit.estimatedOffset, affinity: resolvedAffinity);
      }
    }
    final model = identity == null ? null : _longLineWidthModels[identity];
    if (model == null) {
      final advance = _prototypeCodeUnitAdvance();
      final logical = _config.textDirection == TextDirection.ltr ? x / advance : length - x / advance;
      return TextPosition(offset: logical.round().clamp(0, length), affinity: affinity);
    }
    final tabState = _validLongLineTabPrefix(
      identity!,
      model,
      _longLineAverageAdvances[identity] ?? _prototypeCodeUnitAdvance(),
    );
    final logicalX = _config.textDirection == TextDirection.ltr
        ? x
        : _longLineEstimatedExtent(model, tabState, length) - x;
    return TextPosition(
      offset: _longLineOffsetForLogicalX(identity, line, model, tabState, logicalX, length),
      affinity: affinity,
    );
  }

  /// 兼容只需要 offset 的旧调用方。
  int estimatedLongLineOffsetForX(int line, double x) => estimatedLongLinePositionForX(line, x).offset;

  /// 返回超长行指定 caret 所属的 resolved visual run 方向。
  bool longLineRunIsRtl(int line, int offset, {TextAffinity affinity = TextAffinity.downstream}) {
    final identity = _mounted[line]?.identity;
    final result = identity == null ? null : _longLineBidiPipelines[identity]?.resolvedResultOrNull;
    final visual = result?.visualIndex;
    if (visual != null) {
      final caret = visual.locateOffset(offset.clamp(0, controller.document.lineLength(line)), affinity: affinity);
      if (caret != null) return visual.tiles[caret.tileIndex].isRtl;
    }
    return _config.textDirection == TextDirection.rtl;
  }

  void _disposeLongLinePrototypePainter() {
    _longLinePrototypePainter?.dispose();
    _longLinePrototypePainter = null;
    _longLinePrototypeConfigRevision = -1;
    _longLinePrototypeSystemFontsRevision = -1;
    _longLineSpaceAdvance = null;
    _longLineState?.longLineStyledSpaceAdvances.clear();
  }

  // ===========================================================================
  // 几何查询（doc offset ↔ 行内坐标）
  // ===========================================================================

  /// 取第 [line] 行的已排版 painter：mounted 且布局干净时借用行渲染的，
  /// 否则用共享测量 painter 按同配置同宽度现排。返回值只在当次调用内有效。
  TextPainter painterFor(int line) {
    final mounted = _mounted[line];
    final borrowed = mounted?.layoutedPainter;
    if (borrowed != null) return borrowed;
    if (usesWindowedLineLayout(line)) {
      throw StateError('超长 nowrap 行没有可伪装为完整逻辑行的 TextPainter，请使用 EditableRenderScope 几何门面。');
    }

    final minWidth = _layoutMinWidth;
    final width = _config.softWrap ? _layoutWidth : double.infinity;
    if (_measureLine == line &&
        _measureDocRevision == controller.docRevision &&
        _measurePresentationRevision == controller.presentationRevision &&
        _measureConfigRevision == _configRevision &&
        (controller.inlineContent.isEmpty ||
            (_measureComposing == controller.composing && _measureInlineRevision == _inlineSizeRevision)) &&
        _measureMinWidth == minWidth &&
        _measureWidth == width &&
        _measurePainter != null) {
      return _measurePainter!;
    }
    final span = spanFor(line);
    final model = _config.obscureText ? null : controller.inlineContentModel;
    final projection = model == null
        ? null
        : InlineTextProjection(
            lineTextOf(line),
            model,
            composing: controller.composing.isValid
                ? TextRange(
                    start: (controller.composing.start - controller.document.lineStart(line)).clamp(
                      0,
                      controller.document.lineLength(line),
                    ),
                    end: (controller.composing.end - controller.document.lineStart(line)).clamp(
                      0,
                      controller.document.lineLength(line),
                    ),
                  )
                : TextRange.empty,
          );
    if ((_measurePainter is InlineTextPainter) != (projection != null)) {
      _measurePainter?.dispose();
      _measurePainter = null;
    }
    final painter = _measurePainter ??= projection == null ? TextPainter() : InlineTextPainter(projection);
    if (painter is InlineTextPainter) painter.projection = projection!;
    painter.text = projection?.buildSpan(span) ?? span;
    painter.setPlaceholderDimensions(
      projection == null
          ? null
          : [
              for (final slot in projection.slots)
                PlaceholderDimensions(
                  size: inlineEstimatedSize(slot.match.token),
                  alignment: .baseline,
                  baseline: .alphabetic,
                  baselineOffset: fixedBaseline - (fixedLineHeight - inlineEstimatedSize(slot.match.token).height) / 2,
                ),
            ],
    );
    RenderEditableLine.debugRecordParagraph(controller.document.lineLength(line));
    painter
      ..textDirection = _config.textDirection
      ..textAlign = _config.textAlign
      ..textScaler = _config.textScaler
      ..strutStyle = strutStyleFor(span)
      ..layout(minWidth: minWidth, maxWidth: width.isFinite ? width : double.infinity);
    assert(() {
      debugMeasureLayoutCount++;
      return true;
    }());
    _measureLine = line;
    _measureDocRevision = controller.docRevision;
    _measurePresentationRevision = controller.presentationRevision;
    _measureConfigRevision = _configRevision;
    _measureComposing = controller.composing;
    _measureInlineRevision = _inlineSizeRevision;
    _measureMinWidth = minWidth;
    _measureWidth = width;
    return painter;
  }

  /// 测量 painter 真实排版次数（缓存命中不计）。仅 debug 递增，性能测试用。
  static int debugMeasureLayoutCount = 0;

  /// 行内点击坐标 → doc 位置。
  TextPosition docPositionInLine(int line, Offset localInLine) {
    final mounted = _mounted[line];
    final windowed = usesWindowedLineLayout(line);
    if (mounted != null && mounted.attached && mounted.hasSize && (!windowed || mounted.windowPainter != null)) {
      final local = mounted.positionForOffset(localInLine);
      return TextPosition(offset: controller.document.lineStart(line) + local.offset, affinity: local.affinity);
    }
    if (windowed) {
      final local = estimatedLongLinePositionForX(line, localInLine.dx);
      return TextPosition(offset: controller.document.lineStart(line) + local.offset, affinity: local.affinity);
    }
    final painter = painterFor(line);
    final local = painter.getPositionForOffset(localInLine);
    return TextPosition(offset: controller.document.lineStart(line) + local.offset, affinity: local.affinity);
  }

  /// caret 几何（行内坐标，含整行高）。[overwrite] 为 true 时覆盖下一完整
  /// 字素；行末或当前 affinity 所在视觉行没有该字素时显示空白单元块。
  Rect caretRectInLine(int line, TextPosition docPosition, {bool overwrite = false}) {
    final document = controller.document;
    final lineStart = document.lineStart(line);
    final lineEnd = document.lineEnd(line);
    final overwriteEnd = overwrite ? _overwriteEndInLine(docPosition.offset, lineStart, lineEnd) - lineStart : -1;
    final mounted = _mounted[line];
    if (mounted != null &&
        mounted.attached &&
        mounted.hasSize &&
        mounted.windowPainter != null &&
        usesWindowedLineLayout(line)) {
      return mounted.caretRectFor(
        TextPosition(
          offset: (docPosition.offset - lineStart).clamp(0, lineEnd - lineStart),
          affinity: docPosition.affinity,
        ),
        overwriteEnd: overwriteEnd,
      );
    }
    if (usesWindowedLineLayout(line)) {
      final x = estimatedLongLineXForOffset(line, docPosition.offset - lineStart, affinity: docPosition.affinity);
      final height = _prototypePreferredLineHeight();
      final width = overwrite ? math.max(_config.caretWidth, height * 0.5) : _config.caretWidth;
      final left = longLineRunIsRtl(line, docPosition.offset - lineStart, affinity: docPosition.affinity)
          ? x - width
          : x;
      return Rect.fromLTWH(left, 0, width, height);
    }
    final painter = painterFor(line);
    final localPos = _toLocal(line, docPosition);
    final availableWidth = mounted != null && mounted.hasSize
        ? mounted.size.width
        : _config.softWrap && _layoutWidth.isFinite
        ? _layoutWidth
        : painter.width + (overwrite ? blockCaretFallbackWidth(painter) : _config.caretWidth) + 2.0;
    return caretRectForPainter(painter, localPos, overwriteEnd: overwriteEnd, availableWidth: availableWidth);
  }

  /// 已排版 painter 中的 caret 几何；供 mounted 行绘制与公开几何查询共用，
  /// 避免 block 宽度、bidi 方向和 wrap affinity 出现两套口径。
  Rect caretRectForPainter(
    TextPainter painter,
    TextPosition localPosition, {
    int overwriteEnd = -1,
    double? availableWidth,
  }) {
    final preferredLineHeight = usesFixedLineHeight ? fixedLineHeight : painter.preferredLineHeight;
    final prototype = Rect.fromLTWH(0, 0, _config.caretWidth, preferredLineHeight);
    final offset = painter.getOffsetForCaret(localPosition, prototype);
    final height = usesFixedLineHeight ? preferredLineHeight : painter.getFullHeightForCaret(localPosition, prototype);
    final thin = Rect.fromLTWH(offset.dx, offset.dy, _config.caretWidth, height);
    if (overwriteEnd < localPosition.offset) return thin;

    if (overwriteEnd > localPosition.offset) {
      Rect? glyph;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: localPosition.offset, extentOffset: overwriteEnd, affinity: localPosition.affinity),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      for (final box in boxes) {
        final rect = box.toRect();
        // wrap 接缝同 offset 有上下两份视觉 caret；只覆盖 affinity 所属视觉行
        // 的字素，不能让 upstream 行末块跳到下一视觉行。
        if (rect.bottom <= thin.top + precisionErrorTolerance || rect.top >= thin.bottom - precisionErrorTolerance) {
          continue;
        }
        glyph = glyph == null ? rect : glyph.expandToInclude(rect);
      }
      if (glyph != null && glyph.width.isFinite && glyph.width > precisionErrorTolerance) {
        return _clampBlockCaret(
          Rect.fromLTWH(glyph.left, thin.top, math.max(glyph.width, _config.caretWidth), thin.height),
          availableWidth,
        );
      }
    }

    final width = blockCaretFallbackWidth(painter);
    final left = painter.textDirection == TextDirection.rtl ? thin.right - width : thin.left;
    return _clampBlockCaret(Rect.fromLTWH(left, thin.top, width, thin.height), availableWidth);
  }

  Rect _clampBlockCaret(Rect rect, double? availableWidth) {
    if (availableWidth == null || !availableWidth.isFinite || availableWidth <= 0.0) return rect;
    final width = math.min(rect.width, availableWidth);
    final maxLeft = math.max(availableWidth - width, 0.0);
    return Rect.fromLTWH(rect.left.clamp(0.0, maxLeft), rect.top, width, rect.height);
  }

  /// 行末覆写块的空白单元宽度；取半个行高并保证不窄于普通 caret。
  double blockCaretFallbackWidth(TextPainter painter) =>
      math.max(_config.caretWidth, (usesFixedLineHeight ? fixedLineHeight : painter.preferredLineHeight) * 0.5);

  /// 当前逻辑行的首选行高；超长行从小型原型 Paragraph 获取。
  double preferredLineHeightFor(int line) {
    if (usesFixedLineHeight) return fixedLineHeight;
    return usesWindowedLineLayout(line)
        ? (_mounted[line]?.preferredLineHeight ?? _prototypePreferredLineHeight())
        : painterFor(line).preferredLineHeight;
  }

  TextPosition _toLocal(int line, TextPosition docPosition) {
    final start = controller.document.lineStart(line);
    final len = controller.document.lineLength(line);
    return TextPosition(offset: (docPosition.offset - start).clamp(0, len), affinity: docPosition.affinity);
  }

  // ===========================================================================
  // EditableLayoutQuery 实现
  // ===========================================================================

  static const double _horizontalProbe = 0.5;
  static const double _horizontalTolerance = 0.01;

  @override
  TextPosition? horizontalSelectionEdge(TextRange range, {required bool left}) {
    if (!range.isValid || range.isCollapsed) return null;
    final doc = controller.document;
    final startLine = doc.lineIndexOf(range.start);
    if (doc.lineIndexOf(range.end) != startLine) return null;
    final render = _mounted[startLine];
    final window = render?.layoutWindow;
    final windowPainter = render?.windowPainter;
    final lineStart = doc.lineStart(startLine);
    if (window != null && windowPainter != null) {
      if (window.isVisual) {
        final localStart = range.start - lineStart;
        final localEnd = range.end - lineStart;
        if (window.containsPosition(TextPosition(offset: localStart)) &&
            window.containsPosition(TextPosition(offset: localEnd, affinity: TextAffinity.upstream))) {
          return _horizontalSelectionEdgeInVisualWindow(
            range,
            left: left,
            painter: windowPainter,
            window: window,
            lineStart: lineStart,
          );
        }
      }
      final paragraphStart = lineStart + window.textStart;
      final paragraphEnd = lineStart + window.textEnd;
      if (!window.isVisual && range.start >= paragraphStart && range.end <= paragraphEnd) {
        return _horizontalSelectionEdgeInPainter(
          range,
          left: left,
          painter: windowPainter,
          paragraphStart: paragraphStart,
          paragraphLength: window.text.length,
        );
      }
    }
    if (usesWindowedLineLayout(startLine)) {
      final indexed = _horizontalSelectionEdgeInLongLineVisualIndex(
        range,
        left: left,
        line: startLine,
        lineStart: lineStart,
      );
      if (indexed != null) return indexed;
    }
    final painter = render?.layoutedPainter;
    if (painter == null) return null;
    final lineLength = doc.lineLength(startLine);
    return _horizontalSelectionEdgeInPainter(
      range,
      left: left,
      painter: painter,
      paragraphStart: lineStart,
      paragraphLength: lineLength,
    );
  }

  TextPosition? _horizontalSelectionEdgeInVisualWindow(
    TextRange range, {
    required bool left,
    required TextPainter painter,
    required EditableLineLayoutWindow window,
    required int lineStart,
  }) {
    final start = window.toParagraphPosition(TextPosition(offset: range.start - lineStart));
    final end = window.toParagraphPosition(
      TextPosition(offset: range.end - lineStart, affinity: TextAffinity.upstream),
    );
    if (painter.getLineBoundary(start) != painter.getLineBoundary(end)) return null;
    final startCaret = painter.getOffsetForCaret(start, Rect.zero);
    final endCaret = painter.getOffsetForCaret(end, Rect.zero);
    if ((startCaret.dy - endCaret.dy).abs() > _horizontalTolerance ||
        (startCaret.dx - endCaret.dx).abs() <= _horizontalTolerance) {
      return null;
    }
    final target = left == (startCaret.dx < endCaret.dx) ? start : end;
    final canonical = _canonicalizeCaretAffinity(painter, target);
    final linePosition = window.toLinePosition(canonical);
    return TextPosition(offset: lineStart + linePosition.offset, affinity: linePosition.affinity);
  }

  TextPosition? _horizontalSelectionEdgeInLongLineVisualIndex(
    TextRange range, {
    required bool left,
    required int line,
    required int lineStart,
  }) {
    final identity = _mounted[line]?.identity;
    final pipeline = identity == null ? null : _longLineBidiPipelines[identity];
    final result = pipeline?.resolvedResultOrNull;
    if (result == null) return null;
    final visual = result.visualIndex;
    final start = visual.locateOffset(range.start - lineStart, affinity: TextAffinity.downstream);
    final end = visual.locateOffset(range.end - lineStart, affinity: TextAffinity.upstream);
    if (start == null || end == null || (start.visualX - end.visualX).abs() <= _horizontalTolerance) return null;
    final choosesStart = left == (start.visualX < end.visualX);
    return TextPosition(
      offset: choosesStart ? range.start : range.end,
      affinity: choosesStart ? TextAffinity.downstream : TextAffinity.upstream,
    );
  }

  TextPosition? _horizontalSelectionEdgeInPainter(
    TextRange range, {
    required bool left,
    required TextPainter painter,
    required int paragraphStart,
    required int paragraphLength,
  }) {
    final start = TextPosition(offset: (range.start - paragraphStart).clamp(0, paragraphLength));
    final end = TextPosition(
      offset: (range.end - paragraphStart).clamp(0, paragraphLength),
      affinity: TextAffinity.upstream,
    );
    if (painter.getLineBoundary(start) != painter.getLineBoundary(end)) return null;
    final startCaret = painter.getOffsetForCaret(start, Rect.zero);
    final endCaret = painter.getOffsetForCaret(end, Rect.zero);
    if ((startCaret.dy - endCaret.dy).abs() > _horizontalTolerance ||
        (startCaret.dx - endCaret.dx).abs() <= _horizontalTolerance) {
      return null;
    }
    final target = left == (startCaret.dx < endCaret.dx) ? start : end;
    final canonical = _canonicalizeCaretAffinity(painter, target);
    return TextPosition(offset: paragraphStart + canonical.offset, affinity: canonical.affinity);
  }

  @override
  TextPosition? moveHorizontal(TextPosition position, {required bool left}) {
    final movesForward = left == (_config.textDirection == TextDirection.rtl);
    final projected = lineProjection?.projectCollapsedPosition(
      position,
      bias: movesForward ? EditablePositionProjectionBias.forward : EditablePositionProjectionBias.backward,
    );
    if (projected != null && projected != position) return projected;
    final resolved = lineProjection?.canonicalizeVisibleCaretPosition(projected ?? position) ?? position;
    final doc = controller.document;
    final line = doc.lineIndexOf(resolved.offset);
    final lineStart = doc.lineStart(line);
    final lineEnd = doc.lineEnd(line);
    final render = _mounted[line];
    final window = render?.layoutWindow;
    final windowPainter = render?.windowPainter;
    if (window != null && windowPainter != null) {
      final lineOffset = resolved.offset - lineStart;
      if (window.containsPosition(TextPosition(offset: lineOffset, affinity: resolved.affinity))) {
        if (window.isVisual) {
          return _moveHorizontalInVisualWindow(
            resolved,
            left: left,
            movesForward: movesForward,
            line: line,
            lineStart: lineStart,
            lineEnd: lineEnd,
            painter: windowPainter,
            window: window,
          );
        }
        return _moveHorizontalInPainter(
          resolved,
          left: left,
          movesForward: movesForward,
          line: line,
          paragraphStart: lineStart + window.textStart,
          paragraphEnd: lineStart + window.textEnd,
          painter: windowPainter,
          local: window.toParagraphPosition(TextPosition(offset: lineOffset, affinity: resolved.affinity)),
          windowed: true,
        );
      }
    }
    if (usesWindowedLineLayout(line)) {
      final indexed = _moveHorizontalInLongLineVisualIndex(
        resolved,
        left: left,
        movesForward: movesForward,
        line: line,
        lineStart: lineStart,
        lineEnd: lineEnd,
      );
      if (indexed != null) return indexed;
    }
    // 未 mounted / 尚未完成 layout 的行没有可观察的视觉几何；按段落基向走
    // 固定块字素 fallback，也避免方向键为了测量而物化屏外超长整行。
    if (_mounted[line]?.layoutedPainter == null) {
      return _moveHorizontalWithoutLayout(
        resolved,
        line: line,
        lineStart: lineStart,
        lineEnd: lineEnd,
        movesForward: movesForward,
      );
    }
    final painter = painterFor(line);
    final local = _toLocal(line, resolved);
    return _moveHorizontalInPainter(
      resolved,
      left: left,
      movesForward: movesForward,
      line: line,
      paragraphStart: lineStart,
      paragraphEnd: lineEnd,
      painter: painter,
      local: local,
      windowed: false,
    );
  }

  TextPosition? _moveHorizontalInVisualWindow(
    TextPosition position, {
    required bool left,
    required bool movesForward,
    required int line,
    required int lineStart,
    required int lineEnd,
    required TextPainter painter,
    required EditableLineLayoutWindow window,
  }) {
    final invisibleStep = _zeroWidthLongLineStepForPosition(
      position,
      line: line,
      lineStart: lineStart,
      lineEnd: lineEnd,
      movesForward: movesForward,
    );
    if (invisibleStep != null) return invisibleStep;
    final local = window.toParagraphPosition(
      TextPosition(offset: position.offset - lineStart, affinity: position.affinity),
    );
    final caret = painter.getOffsetForCaret(local, Rect.zero);
    final caretHeight = painter.getFullHeightForCaret(local, Rect.zero);
    final centerY = caret.dy + caretHeight / 2;
    // synthetic controls 都是零宽；探针只接受真正占据目标视觉侧的 glyph，
    // 再通过 window 映射跳回原文，绝不把控制符 offset 发布给 controller。
    for (var distance = _horizontalProbe; distance <= _horizontalProbe * 8; distance += _horizontalProbe) {
      final probe = Offset(caret.dx + (left ? -distance : distance), centerY);
      final glyph = painter.getClosestGlyphForOffset(probe);
      if (glyph == null || !_glyphOccupiesVisualSide(glyph, caret: caret, centerY: centerY, left: left)) continue;
      final target = _canonicalizeCaretAffinity(
        painter,
        _positionAtGlyphVisualEdge(glyph, range: glyph.graphemeClusterCodeUnitRange, leftEdge: left),
      );
      final targetCaret = painter.getOffsetForCaret(target, Rect.zero);
      final advances = left
          ? targetCaret.dx < caret.dx - _horizontalTolerance
          : targetCaret.dx > caret.dx + _horizontalTolerance;
      if (!advances || painter.getLineBoundary(target) != painter.getLineBoundary(local)) continue;
      final linePosition = window.toLinePosition(target);
      final documentPosition = TextPosition(offset: lineStart + linePosition.offset, affinity: linePosition.affinity);
      if (documentPosition != position) return documentPosition;
    }
    final indexed = _moveHorizontalInLongLineVisualIndex(
      position,
      left: left,
      movesForward: movesForward,
      line: line,
      lineStart: lineStart,
      lineEnd: lineEnd,
    );
    if (indexed != null) return indexed;
    return _moveHorizontalWithoutLayout(
      position,
      line: line,
      lineStart: lineStart,
      lineEnd: lineEnd,
      movesForward: movesForward,
    );
  }

  TextPosition? _moveHorizontalInLongLineVisualIndex(
    TextPosition position, {
    required bool left,
    required bool movesForward,
    required int line,
    required int lineStart,
    required int lineEnd,
  }) {
    final identity = _mounted[line]?.identity;
    final pipeline = identity == null ? null : _longLineBidiPipelines[identity];
    final result = pipeline?.resolvedResultOrNull;
    if (result == null) return null;
    final visual = result.visualIndex;
    final localOffset = (position.offset - lineStart).clamp(0, lineEnd - lineStart);
    final invisibleStep = _zeroWidthLongLineLogicalGraphemeStep(
      visual,
      localOffset,
      lineStart: lineStart,
      lineEnd: lineEnd,
      movesForward: movesForward,
    );
    if (invisibleStep != null) return invisibleStep;
    final caret = visual.locateOffset(localOffset, affinity: position.affinity);
    if (caret == null) return null;
    final tile = visual.tiles[caret.tileIndex];
    final movesLogicalForward = left ? tile.isRtl : !tile.isRtl;
    int? target;
    if (movesLogicalForward && caret.offset < tile.end) {
      target =
          nextTextGraphemeBoundary(
            controller.document,
            lineStart + caret.offset,
            lowerBound: lineStart + tile.start,
            upperBound: lineStart + tile.end,
          ) -
          lineStart;
    } else if (!movesLogicalForward && caret.offset > tile.start) {
      target =
          previousTextGraphemeBoundary(
            controller.document,
            lineStart + caret.offset,
            lowerBound: lineStart + tile.start,
            upperBound: lineStart + tile.end,
          ) -
          lineStart;
    }
    var targetTileIndex = caret.tileIndex;
    if (target == null || target == caret.offset) {
      targetTileIndex = caret.tileIndex + (left ? -1 : 1);
      if (targetTileIndex < 0 || targetTileIndex >= visual.tiles.length) return null;
      final targetTile = visual.tiles[targetTileIndex];
      target = left
          ? targetTile.isRtl
                ? targetTile.start
                : targetTile.end
          : targetTile.isRtl
          ? targetTile.end
          : targetTile.start;
      if (targetTile.paintRunIndex == tile.paintRunIndex) {
        final targetMovesLogicalForward = left ? targetTile.isRtl : !targetTile.isRtl;
        if (targetMovesLogicalForward && target < targetTile.end) {
          target =
              nextTextGraphemeBoundary(
                controller.document,
                lineStart + target,
                lowerBound: lineStart + targetTile.start,
                upperBound: lineStart + targetTile.end,
              ) -
              lineStart;
        } else if (!targetMovesLogicalForward && target > targetTile.start) {
          target =
              previousTextGraphemeBoundary(
                controller.document,
                lineStart + target,
                lowerBound: lineStart + targetTile.start,
                upperBound: lineStart + targetTile.end,
              ) -
              lineStart;
        }
      }
    }
    var affinity = TextAffinity.downstream;
    final downstream = visual.locateOffset(target, affinity: affinity);
    if (downstream?.tileIndex != targetTileIndex) affinity = TextAffinity.upstream;
    return TextPosition(offset: lineStart + target, affinity: affinity);
  }

  TextPosition? _zeroWidthLongLineStepForPosition(
    TextPosition position, {
    required int line,
    required int lineStart,
    required int lineEnd,
    required bool movesForward,
  }) {
    final identity = _mounted[line]?.identity;
    final visual = identity == null ? null : _longLineBidiPipelines[identity]?.resolvedResultOrNull?.visualIndex;
    if (visual == null) return null;
    return _zeroWidthLongLineLogicalGraphemeStep(
      visual,
      (position.offset - lineStart).clamp(0, lineEnd - lineStart),
      lineStart: lineStart,
      lineEnd: lineEnd,
      movesForward: movesForward,
    );
  }

  TextPosition? _zeroWidthLongLineLogicalGraphemeStep(
    LongLineVisualIndex visual,
    int localOffset, {
    required int lineStart,
    required int lineEnd,
    required bool movesForward,
  }) {
    final documentOffset = lineStart + localOffset;
    final target = movesForward
        ? nextTextGraphemeBoundary(controller.document, documentOffset, lowerBound: lineStart, upperBound: lineEnd)
        : previousTextGraphemeBoundary(controller.document, documentOffset, lowerBound: lineStart, upperBound: lineEnd);
    if (target == documentOffset) return null;
    final from = math.min(documentOffset, target) - lineStart;
    final to = math.max(documentOffset, target) - lineStart;
    if (visual.hasPaintRetainedInRange(from, to)) {
      final removed = visual.bidiIndex.x9Removed;
      for (var offset = from; offset < to; offset++) {
        // 独立 BN（SHY/ZWSP/WJ）虽为 shaping-retained，但仍是零宽逻辑簇；
        // 可见正文与 ZWJ/ZWNJ 共簇时至少有一个未移除单元，必须保持原子。
        if (removed[offset] == 0) return null;
      }
    }
    return TextPosition(offset: target);
  }

  TextPosition? _moveHorizontalInPainter(
    TextPosition position, {
    required bool left,
    required bool movesForward,
    required int line,
    required int paragraphStart,
    required int paragraphEnd,
    required TextPainter painter,
    required TextPosition local,
    required bool windowed,
  }) {
    // wrap 接缝的两个 caret 共用 offset；先只换 affinity，下一键才跨字素。
    final upstream = TextPosition(offset: local.offset, affinity: TextAffinity.upstream);
    final downstream = TextPosition(offset: local.offset);
    if (painter.getLineBoundary(upstream) != painter.getLineBoundary(downstream)) {
      if (movesForward && local.affinity == TextAffinity.upstream) {
        return TextPosition(offset: position.offset);
      }
      if (!movesForward && local.affinity == TextAffinity.downstream) {
        return TextPosition(offset: position.offset, affinity: TextAffinity.upstream);
      }
    }

    final invisibleStep = _zeroWidthLogicalGraphemeStep(
      painter,
      local,
      lineStart: paragraphStart,
      lineEnd: paragraphEnd,
      movesForward: movesForward,
    );
    if (invisibleStep != null) return invisibleStep;

    final currentLine = painter.getLineBoundary(local);
    final caret = painter.getOffsetForCaret(local, Rect.zero);
    final caretHeight = painter.getFullHeightForCaret(local, Rect.zero);
    final probe = Offset(caret.dx + (left ? -_horizontalProbe : _horizontalProbe), caret.dy + caretHeight / 2);
    final glyph = painter.getClosestGlyphForOffset(probe);
    if (glyph != null && _glyphOccupiesVisualSide(glyph, caret: caret, centerY: probe.dy, left: left)) {
      final target = _canonicalizeCaretAffinity(
        painter,
        _positionAtGlyphVisualEdge(
          glyph,
          range: _expandedGlyphGraphemeRange(glyph, lineStart: paragraphStart, lineEnd: paragraphEnd),
          leftEdge: left,
        ),
      );
      final targetCaret = painter.getOffsetForCaret(target, Rect.zero);
      final advances = left
          ? targetCaret.dx < caret.dx - _horizontalTolerance
          : targetCaret.dx > caret.dx + _horizontalTolerance;
      if (advances && painter.getLineBoundary(target) == currentLine) {
        return TextPosition(offset: paragraphStart + target.offset, affinity: target.affinity);
      }
    }

    if (windowed) {
      return _moveHorizontalWithoutLayout(
        position,
        line: line,
        lineStart: controller.document.lineStart(line),
        lineEnd: controller.document.lineEnd(line),
        movesForward: movesForward,
      );
    }
    return _moveAcrossVisualLine(
      line: line,
      painter: painter,
      caret: caret,
      caretHeight: caretHeight,
      movesForward: movesForward,
    );
  }

  TextPosition? _zeroWidthLogicalGraphemeStep(
    TextPainter painter,
    TextPosition local, {
    required int lineStart,
    required int lineEnd,
    required bool movesForward,
  }) {
    final doc = controller.document;
    final documentOffset = lineStart + local.offset;
    final target = movesForward
        ? nextTextGraphemeBoundary(doc, documentOffset, lowerBound: lineStart, upperBound: lineEnd)
        : previousTextGraphemeBoundary(doc, documentOffset, lowerBound: lineStart, upperBound: lineEnd);
    if (target == documentOffset) return null;
    final from = math.min(documentOffset, target) - lineStart;
    final to = math.max(documentOffset, target) - lineStart;
    final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: from, extentOffset: to));
    if (boxes.isEmpty || boxes.any((box) => box.right - box.left > _horizontalTolerance)) return null;
    return TextPosition(offset: target);
  }

  TextPosition? _moveHorizontalWithoutLayout(
    TextPosition position, {
    required int line,
    required int lineStart,
    required int lineEnd,
    required bool movesForward,
  }) {
    final doc = controller.document;
    if (movesForward) {
      if (position.offset < lineEnd) {
        return TextPosition(
          offset: nextTextGraphemeBoundary(doc, position.offset, lowerBound: lineStart, upperBound: lineEnd),
        );
      }
      final targetLine = _adjacentVisibleModelLine(line, forward: true);
      return targetLine == null ? null : TextPosition(offset: doc.lineStart(targetLine));
    }
    if (position.offset > lineStart) {
      return TextPosition(
        offset: previousTextGraphemeBoundary(doc, position.offset, lowerBound: lineStart, upperBound: lineEnd),
      );
    }
    final targetLine = _adjacentVisibleModelLine(line, forward: false);
    return targetLine == null ? null : TextPosition(offset: doc.lineEnd(targetLine));
  }

  int? _adjacentVisibleModelLine(int line, {required bool forward}) {
    final projection = lineProjection;
    if (projection != null) return projection.adjacentVisibleModelLine(line, forward: forward);
    final target = line + (forward ? 1 : -1);
    return target < 0 || target >= controller.document.lineCount ? null : target;
  }

  bool _glyphOccupiesVisualSide(
    ui.GlyphInfo glyph, {
    required Offset caret,
    required double centerY,
    required bool left,
  }) {
    final bounds = glyph.graphemeClusterLayoutBounds;
    final onCurrentLine =
        centerY >= bounds.top - _horizontalTolerance && centerY <= bounds.bottom + _horizontalTolerance;
    if (!onCurrentLine) return false;
    return left ? bounds.left < caret.dx - _horizontalTolerance : bounds.right > caret.dx + _horizontalTolerance;
  }

  TextRange _expandedGlyphGraphemeRange(ui.GlyphInfo glyph, {required int lineStart, required int lineEnd}) {
    final raw = glyph.graphemeClusterCodeUnitRange;
    var start = lineStart + raw.start;
    var end = lineStart + raw.end;
    // 只探 glyph 覆盖的 code unit，不能拿 raw.end（它是下一字素边界）去查，
    // 否则普通组合字素后紧邻的字符会被误并入。
    for (final probe in <int>{start, math.max(start, end - 1)}) {
      final expanded = textGraphemeRangeAt(controller.document, probe, lowerBound: lineStart, upperBound: lineEnd);
      if (expanded.start == expanded.end) continue;
      start = math.min(start, expanded.start);
      end = math.max(end, expanded.end);
    }
    return TextRange(start: start - lineStart, end: end - lineStart);
  }

  TextPosition _positionAtGlyphVisualEdge(ui.GlyphInfo glyph, {required TextRange range, required bool leftEdge}) {
    return switch ((leftEdge, glyph.writingDirection)) {
      (true, TextDirection.ltr) => TextPosition(offset: range.start),
      (true, TextDirection.rtl) => TextPosition(offset: range.end, affinity: TextAffinity.upstream),
      (false, TextDirection.ltr) => TextPosition(offset: range.end, affinity: TextAffinity.upstream),
      (false, TextDirection.rtl) => TextPosition(offset: range.start),
    };
  }

  TextPosition _canonicalizeCaretAffinity(TextPainter painter, TextPosition position) {
    if (position.affinity == TextAffinity.downstream) return position;
    final downstream = TextPosition(offset: position.offset);
    final upstreamCaret = painter.getOffsetForCaret(position, Rect.zero);
    final downstreamCaret = painter.getOffsetForCaret(downstream, Rect.zero);
    return (upstreamCaret - downstreamCaret).distance <= _horizontalTolerance ? downstream : position;
  }

  TextPosition? _moveAcrossVisualLine({
    required int line,
    required TextPainter painter,
    required Offset caret,
    required double caretHeight,
    required bool movesForward,
  }) {
    final targetY = movesForward ? caret.dy + caretHeight + _horizontalProbe : caret.dy - _horizontalProbe;
    if (targetY >= 0.0 && targetY < painter.height) {
      final target = _positionAtVisualLineEdge(
        painter,
        y: targetY,
        leftEdge: movesForward == (_config.textDirection == TextDirection.ltr),
      );
      return _toDocumentPosition(line, target);
    }

    final doc = controller.document;
    final targetLine = _adjacentVisibleModelLine(line, forward: movesForward);
    if (targetLine == null) return null;
    if (_mounted[targetLine]?.layoutedPainter == null) {
      return TextPosition(offset: movesForward ? doc.lineStart(targetLine) : doc.lineEnd(targetLine));
    }
    final targetPainter = painterFor(targetLine);
    final target = _positionAtVisualLineEdge(
      targetPainter,
      y: movesForward ? _horizontalProbe : math.max(targetPainter.height - _horizontalProbe, 0.0),
      leftEdge: movesForward == (_config.textDirection == TextDirection.ltr),
    );
    return _toDocumentPosition(targetLine, target);
  }

  TextPosition _positionAtVisualLineEdge(TextPainter painter, {required double y, required bool leftEdge}) =>
      painter.getPositionForOffset(Offset(leftEdge ? -double.maxFinite : double.maxFinite, y));

  TextPosition _toDocumentPosition(int line, TextPosition local) =>
      TextPosition(offset: controller.document.lineStart(line) + local.offset, affinity: local.affinity);

  @override
  double caretXFor(TextPosition position) {
    final projected =
        lineProjection?.projectCollapsedPosition(position, bias: EditablePositionProjectionBias.backward) ?? position;
    final resolved = lineProjection?.canonicalizeVisibleCaretPosition(projected) ?? projected;
    final line = controller.document.lineIndexOf(resolved.offset);
    return caretRectInLine(line, resolved).left;
  }

  @override
  TextPosition? moveVertical(TextPosition position, {required bool down, required double xGoal}) {
    final doc = controller.document;
    final projected = lineProjection?.projectCollapsedPosition(
      position,
      bias: down ? EditablePositionProjectionBias.forward : EditablePositionProjectionBias.backward,
    );
    if (projected != null && projected != position) {
      final targetLine = doc.lineIndexOf(projected.offset);
      if (usesWindowedLineLayout(targetLine)) {
        return docPositionInLine(targetLine, Offset(xGoal, _prototypePreferredLineHeight() / 2.0));
      }
      final targetPainter = painterFor(targetLine);
      final y = down ? 2.0 : math.max(targetPainter.height - 2.0, 0.0);
      final local = targetPainter.getPositionForOffset(Offset(xGoal, y));
      return TextPosition(offset: doc.lineStart(targetLine) + local.offset, affinity: local.affinity);
    }
    final resolved = lineProjection?.canonicalizeVisibleCaretPosition(projected ?? position) ?? position;
    final line = doc.lineIndexOf(resolved.offset);
    final caret = caretRectInLine(line, resolved);
    if (usesWindowedLineLayout(line)) {
      final targetLine = _adjacentVisibleModelLine(line, forward: down);
      if (targetLine == null) return null;
      return docPositionInLine(targetLine, Offset(xGoal, _prototypePreferredLineHeight() / 2.0));
    }
    final painter = painterFor(line);
    // 行内跨视觉行：目标 y 落在本行 painter 高度内则直接命中。
    final targetY = down ? caret.bottom + 2.0 : caret.top - 2.0;
    if (targetY >= 0 && targetY <= painter.height) {
      final local = painter.getPositionForOffset(Offset(xGoal, targetY));
      return TextPosition(offset: doc.lineStart(line) + local.offset, affinity: local.affinity);
    }
    // 跨逻辑行。
    final targetLine = _adjacentVisibleModelLine(line, forward: down);
    if (targetLine == null) return null;
    if (usesWindowedLineLayout(targetLine)) {
      return docPositionInLine(targetLine, Offset(xGoal, _prototypePreferredLineHeight() / 2.0));
    }
    final targetPainter = painterFor(targetLine);
    final y = down ? 2.0 : math.max(targetPainter.height - 2.0, 0.0);
    final local = targetPainter.getPositionForOffset(Offset(xGoal, y));
    return TextPosition(offset: doc.lineStart(targetLine) + local.offset, affinity: local.affinity);
  }

  @override
  TextPosition pageMove(
    TextPosition position, {
    required bool down,
    required double xGoal,
    required double pageExtent,
  }) {
    // 逐视觉行步进直到耗尽一页高度。painterFor 有单行缓存 + mounted 借用，
    // 一页几十行的量级开销可控。
    final projection = lineProjection;
    var current = projection == null
        ? position
        : projection.canonicalizeVisibleCaretPosition(
            projection.projectCollapsedPosition(
              position,
              bias: down ? EditablePositionProjectionBias.forward : EditablePositionProjectionBias.backward,
            ),
          );
    var budget = pageExtent;
    while (budget > 0) {
      final line = controller.document.lineIndexOf(current.offset);
      final step = preferredLineHeightFor(line);
      final next = moveVertical(current, down: down, xGoal: xGoal);
      if (next == null) break;
      current = next;
      budget -= step;
    }
    return current;
  }

  @override
  TextPosition visualLineEdge(TextPosition position, {required bool end}) {
    final doc = controller.document;
    final line = doc.lineIndexOf(position.offset);
    if (usesWindowedLineLayout(line)) {
      return TextPosition(
        offset: end ? doc.lineEnd(line) : doc.lineStart(line),
        affinity: end ? TextAffinity.upstream : TextAffinity.downstream,
      );
    }
    final painter = painterFor(line);
    final boundary = painter.getLineBoundary(_toLocal(line, position));
    final start = doc.lineStart(line);
    if (end) {
      // 视觉行尾停在折行点左侧（upstream），最后一段视觉行即行尾。
      return TextPosition(offset: start + boundary.end, affinity: TextAffinity.upstream);
    }
    return TextPosition(offset: start + boundary.start);
  }

  @override
  TextRange wordBoundary(TextPosition position) =>
      EditableWordNavigator(controller.document, wordSeparators: _config.wordSeparators).boundaryAt(position.offset);

  /// 选区绘制盒查询由行渲染直接走自身 painter，这里补充给测试 / 视图层的
  /// 便捷入口：本行选区盒（行内坐标）。
  List<ui.TextBox> selectionBoxesInLine(int line, TextSelection docSelection) {
    final doc = controller.document;
    final start = doc.lineStart(line);
    final len = doc.lineLength(line);
    final s = (docSelection.start - start).clamp(0, len);
    final e = (docSelection.end - start).clamp(0, len);
    if (s >= e) return const [];
    final mounted = _mounted[line];
    if (usesWindowedLineLayout(line)) {
      if (mounted == null || !mounted.attached || !mounted.hasSize || mounted.windowPainter == null) {
        return const <ui.TextBox>[];
      }
      return mounted.selectionBoxesForLineRange(s, e);
    }
    return painterFor(line).getBoxesForSelection(
      TextSelection(baseOffset: s, extentOffset: e),
      boxHeightStyle: selectionBoxHeightStyle,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final state = _longLineState;
    if (state != null) {
      state.deferredLongLineHydration.clear();
      state.longLineViewportRefreshPending.clear();
      state.longLineVisualRefreshPending.clear();
      state.longLineBidiHydrationChunksThisFrame.clear();
      state.longLineCoverages.clear();
      state.longLineAverageAdvances.clear();
      state.longLineWidthModels.clear();
      state.longLineTabPrefixes.clear();
      state.longLineTabBatchPrefixes.clear();
      for (final pipeline in state.longLineBidiPipelines.values) {
        pipeline.dispose();
      }
      state.longLineBidiPipelines.clear();
      state.activeLongLineBidiResolves.clear();
      state.longLineBidiEstimateRevisions.clear();
      state.longLineBidiGenerations.clear();
      state.longLineVisualMetricRevisions.clear();
      state.longLineVisualTrailingExtents.clear();
      state.pendingLongLineBidiResolves.clear();
      state.longLineBidiFailureAttempts.clear();
      state.longLineBidiTerminalErrors.clear();
      state.longLineBidiRetryScheduled.clear();
      state.longLineBidiSafePrefixIdentities.clear();
    }
    _knownLineWidthsState?.clear();
    _mounted.clear();
    _clearLineTextBatch();
    _systemFontsListenable?.removeListener(_scheduleSystemFontsUpdate);
    _systemFontsListenable = null;
    _selectionPaintIndexSource = null;
    _selectionPaintIndex = null;
    _measurePainter?.dispose();
    _measurePainter = null;
    _clearResolvedFixedLineMetrics();
    _disposeLongLinePrototypePainter();
    _minimumCrossAxisExtent?.dispose();
    super.dispose();
  }
}
