import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show TextRange;

import '../editable_line_layout.dart';
import 'long_line_bidi_executor_native.dart'
    if (dart.library.js_interop) 'long_line_bidi_executor_web.dart'
    as bidi_executor;
import 'long_line_bidi_index.dart';
import 'long_line_cooperative_scheduler.dart';
import 'long_line_visual_index.dart';

/// 一条完整长逻辑行完成 UAX #9 与视觉宽度索引后的缓存结果。
@immutable
final class LongLineBidiPipelineResult {
  const LongLineBidiPipelineResult._({required this.bidiIndex, required this.visualIndex});

  /// 完整逻辑行的 Unicode bidi 解析结果。
  final LongLineBidiIndex bidiIndex;

  /// 基于 [bidiIndex] 的视觉 tile 与宽度前缀索引。
  final LongLineVisualIndex visualIndex;
}

/// 后台解析完成时所属管线已经失效或释放。
final class LongLineBidiPipelineStaleException implements Exception {
  /// 创建一个可识别的后台陈旧结果异常。
  const LongLineBidiPipelineStaleException();

  @override
  String toString() => 'LongLineBidiPipelineStaleException: 后台解析结果已经陈旧';
}

/// 长逻辑行从有界文本分块水合到 visual Paragraph 窗口的纯模型管线。
///
/// 文本只能按 UTF-16 offset 连续追加；单块边界允许落在代理对中间，孤立
/// surrogate 由 bidi 算法按 U+FFFD 原子解析但保持原 offset。解析结果只创建
/// 一次，[resolve] 的重复调用返回同一对象。
final class LongLineBidiPipeline {
  /// 创建一条尚未水合的长逻辑行管线。
  LongLineBidiPipeline({required this.lineLength, required this.baseDirection, required double averageAdvance})
    : _averageAdvance = averageAdvance {
    if (lineLength < 0) throw RangeError.range(lineLength, 0, null, 'lineLength');
    if (!averageAdvance.isFinite || averageAdvance <= 0.0) {
      throw ArgumentError.value(averageAdvance, 'averageAdvance', '必须是有限正数');
    }
  }

  /// 单个水合分块允许保留的最大 UTF-16 code-unit 数。
  static const int maxChunkCodeUnits = 64 * 1024;

  /// 单个 synthetic Paragraph 的绝对 UTF-16 硬上限。
  static const int maxParagraphCodeUnits = EditableLineLayoutWindow.defaultVisualParagraphCodeUnitLimit;

  /// 完整逻辑行的 UTF-16 code-unit 长度。
  final int lineLength;

  /// UAX #9 使用的显式段落基方向。
  final LongLineBidiBaseDirection baseDirection;

  /// 未实测视觉 tile 每个 UTF-16 code unit 的 advance 估值。
  double get averageAdvance => _averageAdvance;

  final List<String> _chunks = <String>[];
  double _averageAdvance;
  int _loadedCodeUnits = 0;
  String? _text;
  LongLineBidiPipelineResult? _result;
  Future<LongLineBidiPipelineResult>? _backgroundFuture;
  LongLineCooperativeCancellationToken? _backgroundCancellationToken;
  int _generation = 0;
  bool _invalidated = false;
  bool _disposed = false;

  /// 当前已经连续水合的 UTF-16 code-unit 数，仅供诊断。
  int get debugLoadedCodeUnits => _loadedCodeUnits;

  /// 当前保留的输入分块数量；解析后分块会合并并释放，仅供诊断。
  int get debugChunkCount => _chunks.length;

  /// 当前保留正文按 UTF-16 计的确定性字节数，仅供诊断。
  int get debugRetainedUtf16Bytes => (_text?.length ?? _loadedCodeUnits) * 2;

  /// 当前正文、主要 typed arrays、tiles 与 Fenwick 的保留字节估值。
  int get debugRetainedBytes {
    if (_loadedCodeUnits == 0 && _text == null && _chunks.isEmpty && _result == null) return 0;
    var bytes = debugRetainedUtf16Bytes + 24 + _chunks.length * (24 + 8);
    if (_text != null) bytes += 24;
    final result = _result;
    if (result == null) return bytes;
    final bidi = result.bidiIndex;
    bytes += bidi.levels.length;
    bytes += bidi.x9Removed.length;
    bytes += bidi.visualRunOrder.length * 4;
    bytes += bidi.visualToLogical.length * 4;
    bytes += bidi.logicalToVisual.length * 4;
    bytes += bidi.logicalRuns.length * 10;
    final tileCount = result.visualIndex.tiles.length;
    bytes += lineLength; // paint-retained mask
    bytes += tileCount * (8 + 1 + 4); // widths + measured + logical-order index
    bytes += (tileCount + 1) * 8; // Fenwick
    bytes += tileCount * (48 + 8); // tile 对象与只读列表引用的保守估值
    return bytes;
  }

  /// 当前是否已经完整水合且仍可解析，仅供诊断。
  bool get debugReady => !_invalidated && !_disposed && _loadedCodeUnits == lineLength;

  /// 当前是否已经缓存解析结果，仅供诊断。
  bool get debugResolved => !_invalidated && !_disposed && _result != null;

  /// 当前是否有尚未完成的后台解析，仅供诊断。
  bool get debugResolving => !_invalidated && !_disposed && _backgroundFuture != null && _result == null;

  /// 当前行进入平台后台解析器时的保守峰值工作集估算。
  int get debugEstimatedBackgroundWorkingSetBytes => bidi_executor.estimateLongLineBidiWorkingSetBytes(lineLength);

  /// 当前管线确实在后台解析时计入的保守工作集；未解析时为零。
  int get debugInFlightWorkingSetBytes => debugResolving ? debugEstimatedBackgroundWorkingSetBytes : 0;

  /// 平台全局解析门当前已经放行的任务数。
  int get debugGlobalBackgroundActiveTasks => bidi_executor.longLineBidiExecutorDiagnostics().activeTasks;

  /// 平台全局解析门当前已经放行的保守工作集字节数。
  int get debugGlobalBackgroundActiveBytes => bidi_executor.longLineBidiExecutorDiagnostics().activeBytes;

  /// 平台全局解析门当前等待的任务数。
  int get debugGlobalBackgroundQueuedTasks => bidi_executor.longLineBidiExecutorDiagnostics().queuedTasks;

  /// 平台全局解析门当前等待的保守工作集字节数。
  int get debugGlobalBackgroundQueuedBytes => bidi_executor.longLineBidiExecutorDiagnostics().queuedBytes;

  /// 返回已经缓存的结果；未解析或已失效时为 null，绝不触发同步解析。
  LongLineBidiPipelineResult? get resolvedResultOrNull => _invalidated || _disposed ? null : _result;

  /// 当前缓存的视觉 tile 数；尚未解析或已释放时为零，仅供诊断。
  int get debugTileCount => _result?.visualIndex.tiles.length ?? 0;

  /// 在 [start] 连续追加一个不超过 64Ki UTF-16 的正文分块。
  ///
  /// [start] 必须恰好等于当前已加载长度；空块、重复、乱序、越界和解析后
  /// 继续追加都会严格拒绝。高代理项可以位于本块末尾并由下一块补齐。
  void appendChunk(int start, String text) {
    _ensureActive();
    if (_result != null || _text != null) throw StateError('长行已经解析，不能继续追加分块');
    if (text.isEmpty) throw ArgumentError.value(text, 'text', '水合分块不得为空');
    if (text.length > maxChunkCodeUnits) {
      throw RangeError.range(text.length, 1, maxChunkCodeUnits, 'text.length', '单块不得超过 64Ki UTF-16');
    }
    if (start != _loadedCodeUnits) {
      throw StateError('分块必须连续追加：期望 start=$_loadedCodeUnits，实际为 $start');
    }
    if (text.length > lineLength - _loadedCodeUnits) {
      throw RangeError.range(_loadedCodeUnits + text.length, 0, lineLength, 'text', '分块使总长度越界');
    }
    _chunks.add(text);
    _loadedCodeUnits += text.length;
  }

  /// 在完整水合后一次性构建并缓存 bidi 与视觉宽度索引。
  LongLineBidiPipelineResult resolve() {
    _ensureActive();
    final cached = _result;
    if (cached != null) return cached;
    if (_backgroundFuture != null) throw StateError('后台解析仍在进行，不能重复同步 resolve');
    final result = _resolvePipelineText(_materializeText(), baseDirection, averageAdvance);
    _result = result;
    return result;
  }

  /// 在后台完成 UAX #9 与视觉索引构建，并复用同一 in-flight future。
  ///
  /// 原生平台使用独立 isolate；Web 使用有硬工作预算的协作式解析，使浏览器
  /// 可以持续处理绘制与输入。结果若遇 [invalidate]、[dispose] 或 generation
  /// 变化，会以 [LongLineBidiPipelineStaleException] 结束且绝不安装。
  Future<LongLineBidiPipelineResult> resolveInBackground() {
    _ensureActive();
    final existing = _backgroundFuture;
    if (existing != null) return existing;
    final cached = _result;
    if (cached != null) {
      final future = Future<LongLineBidiPipelineResult>.value(cached);
      _backgroundFuture = future;
      return future;
    }

    _ensureHydrated();
    final chunks = List<String>.of(_chunks, growable: false);
    final expectedLength = lineLength;
    final generation = _generation;
    final direction = baseDirection;
    final advance = averageAdvance;
    final cancellationToken = LongLineCooperativeCancellationToken();
    _backgroundCancellationToken = cancellationToken;
    late final Future<LongLineBidiPipelineResult> future;
    future = () async {
      try {
        final indexes = await bidi_executor.resolveLongLineBidiIndexes(
          chunks: chunks,
          lineLength: expectedLength,
          direction: direction,
          averageAdvance: advance,
          cancellationToken: cancellationToken,
        );
        final result = LongLineBidiPipelineResult._(bidiIndex: indexes.bidiIndex, visualIndex: indexes.visualIndex);
        if (_disposed || _invalidated || generation != _generation) {
          throw const LongLineBidiPipelineStaleException();
        }
        _text = result.visualIndex.text;
        _chunks.clear();
        _result = result;
        if (identical(_backgroundCancellationToken, cancellationToken)) _backgroundCancellationToken = null;
        return result;
      } on LongLineCooperativeCancelledException {
        if (identical(_backgroundCancellationToken, cancellationToken)) _backgroundCancellationToken = null;
        if (identical(_backgroundFuture, future)) _backgroundFuture = null;
        throw const LongLineBidiPipelineStaleException();
      } catch (_) {
        if (identical(_backgroundCancellationToken, cancellationToken)) _backgroundCancellationToken = null;
        if (identical(_backgroundFuture, future)) _backgroundFuture = null;
        rethrow;
      }
    }();
    _backgroundFuture = future;
    return future;
  }

  /// 为给定横向 viewport 构建一个有界 synthetic visual Paragraph 窗口。
  ///
  /// [maxParagraphCodeUnits] 是调用方剩余预算，但实际窗口仍钳在 64Ki UTF-16。
  /// 预算会先扣掉外层两个控制符，再为每个真实片段扣掉四个控制符；任何
  /// 单 tile 无法放入时返回 null。逻辑 tab 前缀必须在单点与批量解析器中
  /// 二选一；批量解析器返回 null 表示本帧预算不足，窗口保持占位等待续算。
  /// 必须先成功调用 [resolve]。
  EditableLineLayoutWindow? buildWindow({
    required double viewportStart,
    required double viewportEnd,
    required double guard,
    required int maxParagraphCodeUnits,
    double Function(int offset)? logicalTabPrefixForOffset,
    Map<int, double>? Function(List<int> sortedOffsets)? logicalTabPrefixesForOffsets,

    /// 内嵌对象可使用等长中性分析文本，实际绘制仍从原文读取有界片段。
    String Function(int start, int end)? sourceText,
  }) {
    _ensureActive();
    final result = _requireResolved();
    if (!viewportStart.isFinite) {
      throw ArgumentError.value(viewportStart, 'viewportStart', '必须是有限数值');
    }
    if (!viewportEnd.isFinite) {
      throw ArgumentError.value(viewportEnd, 'viewportEnd', '必须是有限数值');
    }
    if (viewportEnd < viewportStart) {
      throw ArgumentError.value((viewportStart, viewportEnd), 'viewport', 'end 必须不小于 start');
    }
    if (!guard.isFinite || guard < 0.0) {
      throw ArgumentError.value(guard, 'guard', '必须是有限非负数');
    }
    if (maxParagraphCodeUnits <= 0) {
      throw RangeError.range(maxParagraphCodeUnits, 1, null, 'maxParagraphCodeUnits');
    }
    if ((logicalTabPrefixForOffset == null) == (logicalTabPrefixesForOffsets == null)) {
      throw ArgumentError('必须且只能提供单点或批量 logical tab prefix 解析器之一');
    }
    final budget = math.min(maxParagraphCodeUnits, LongLineBidiPipeline.maxParagraphCodeUnits);
    const outerControls = 2;
    const controlsPerFragment = 4;
    final oneFragmentContentBudget = budget - outerControls - controlsPerFragment;
    if (oneFragmentContentBudget <= 0 || result.visualIndex.tiles.isEmpty) return null;

    final selected = result.visualIndex.selectViewport(
      viewportStart: viewportStart,
      viewportEnd: viewportEnd,
      guard: guard,
      maxCodeUnits: oneFragmentContentBudget,
    );
    if (selected.isEmpty) return null;

    final tiles = result.visualIndex.tiles;
    var firstTile = selected.firstTile;
    var endTile = selected.endTile;
    var fragmentCount = _shapingFragmentCount(tiles, firstTile, endTile);
    var paragraphUnits = selected.codeUnits + outerControls + fragmentCount * controlsPerFragment;
    final center = viewportStart / 2 + viewportEnd / 2;
    while (paragraphUnits > budget && endTile - firstTile > 1) {
      final leftDistance = (_tileCenterX(result.visualIndex, firstTile) - center).abs();
      final rightDistance = (_tileCenterX(result.visualIndex, endTile - 1) - center).abs();
      if (leftDistance >= rightDistance) {
        paragraphUnits -= tiles[firstTile].length;
        if (!_tilesShapeTogether(tiles[firstTile], tiles[firstTile + 1])) {
          paragraphUnits -= controlsPerFragment;
          fragmentCount--;
        }
        firstTile++;
      } else {
        final removedTile = endTile - 1;
        paragraphUnits -= tiles[removedTile].length;
        if (!_tilesShapeTogether(tiles[removedTile - 1], tiles[removedTile])) {
          paragraphUnits -= controlsPerFragment;
          fragmentCount--;
        }
        endTile--;
      }
    }
    if (firstTile == endTile || paragraphUnits > budget) return null;

    final text = _text!;
    final shapingFragments = _mergeShapingFragments(tiles, firstTile, endTile);
    assert(shapingFragments.length == fragmentCount);
    final logicalStarts = <int>[for (final fragment in shapingFragments) fragment.start]..sort();
    final Map<int, double>? tabPrefixes;
    if (logicalTabPrefixesForOffsets != null) {
      tabPrefixes = logicalTabPrefixesForOffsets(logicalStarts);
    } else {
      tabPrefixes = <int, double>{for (final offset in logicalStarts) offset: logicalTabPrefixForOffset!(offset)};
    }
    if (tabPrefixes == null) return null;
    for (final offset in logicalStarts) {
      final tabPrefix = tabPrefixes[offset];
      if (tabPrefix == null) {
        throw ArgumentError.value(tabPrefixes, 'logicalTabPrefixesForOffsets', '缺少 offset=$offset 的结果');
      }
      if (!tabPrefix.isFinite || tabPrefix < 0.0) {
        throw ArgumentError.value(tabPrefix, 'logicalTabPrefix($offset)', '必须返回有限非负数');
      }
    }
    final fragments = <EditableLineVisualFragment>[];
    for (final fragment in shapingFragments) {
      fragments.add(
        EditableLineVisualFragment(
          lineStart: fragment.start,
          lineEnd: fragment.end,
          text: sourceText?.call(fragment.start, fragment.end) ?? text.substring(fragment.start, fragment.end),
          resolvedLevel: fragment.level,
          logicalTabPrefix: tabPrefixes[fragment.start]!,
        ),
      );
    }
    final logicalFragments = fragments.toList(growable: false)
      ..sort((left, right) => left.lineStart.compareTo(right.lineStart));
    final zeroWidthRanges = <TextRange>[];
    for (var index = 1; index < logicalFragments.length; index++) {
      final start = logicalFragments[index - 1].lineEnd;
      final end = logicalFragments[index].lineStart;
      if (start < end && !result.visualIndex.hasPaintRetainedInRange(start, end)) {
        zeroWidthRanges.add(TextRange(start: start, end: end));
      }
    }
    return EditableLineLayoutWindow.visual(
      lineLength: lineLength,
      fragments: fragments,
      paragraphCodeUnitLimit: budget,
      originX: result.visualIndex.startXOf(firstTile),
      estimatedTextWidth: result.visualIndex.totalExtent,
      averageAdvance: averageAdvance,
      visualFirstTile: firstTile,
      visualEndTile: endTile,
      visualTileCount: result.visualIndex.tiles.length,
      zeroWidthLogicalRanges: zeroWidthRanges,
    );
  }

  /// 回填一个视觉 tile 的真实测量宽度；必须已经解析。
  void reportMeasuredWidth(int tileIndex, double width) {
    _ensureActive();
    _requireResolved().visualIndex.reportMeasuredWidth(tileIndex, width);
  }

  /// 原子校验后批量回填视觉 tile 的真实测量宽度；必须已经解析。
  void reportMeasuredWidths(Map<int, double> widths) {
    _ensureActive();
    _requireResolved().visualIndex.reportMeasuredWidths(widths);
  }

  /// 转发字体平均 advance，O(T) 更新全部尚未实测 tile 的宽度估值。
  void updateUnmeasuredAverageAdvance(double averageAdvance) {
    _ensureActive();
    final visualIndex = _requireResolved().visualIndex;
    visualIndex.updateUnmeasuredAverageAdvance(averageAdvance);
    _averageAdvance = averageAdvance;
  }

  /// 原子转发 tab/逻辑宽度模型对任意尚未实测 tile 的非均匀估值。
  void updateUnmeasuredWidths(Map<int, double> widths) {
    _ensureActive();
    _requireResolved().visualIndex.updateUnmeasuredWidths(widths);
  }

  /// 使当前异步水合结果永久失效并立即释放正文与索引。
  void invalidate() {
    _ensureActive();
    _generation++;
    _invalidated = true;
    _release();
  }

  /// 永久释放当前管线；重复释放安全无副作用。
  void dispose() {
    if (_disposed) return;
    _generation++;
    _disposed = true;
    _release();
  }

  LongLineBidiPipelineResult _requireResolved() {
    final result = _result;
    if (result == null) throw StateError('必须先完整水合并调用 resolve');
    return result;
  }

  String _materializeText() {
    _ensureHydrated();
    final cached = _text;
    if (cached != null) return cached;
    final text = lineLength == 0 ? '' : (StringBuffer()..writeAll(_chunks)).toString();
    if (text.length != lineLength) throw StateError('水合结果长度与声明的 lineLength 不一致');
    _text = text;
    _chunks.clear();
    return text;
  }

  void _ensureHydrated() {
    if (_loadedCodeUnits != lineLength) {
      throw StateError('长行尚未完整水合：$_loadedCodeUnits / $lineLength UTF-16');
    }
  }

  void _ensureActive() {
    if (_disposed) throw StateError('LongLineBidiPipeline 已释放');
    if (_invalidated) throw StateError('LongLineBidiPipeline 已失效');
  }

  void _release() {
    _backgroundCancellationToken?.cancel();
    _backgroundCancellationToken = null;
    _chunks.clear();
    _loadedCodeUnits = 0;
    _text = null;
    _result = null;
    _backgroundFuture = null;
  }
}

LongLineBidiPipelineResult _resolvePipelineText(
  String text,
  LongLineBidiBaseDirection baseDirection,
  double averageAdvance,
) {
  final bidiIndex = LongLineBidiIndex.resolve(text, baseDirection: baseDirection);
  final visualIndex = LongLineVisualIndex(text: text, bidiIndex: bidiIndex, averageAdvance: averageAdvance);
  return LongLineBidiPipelineResult._(bidiIndex: bidiIndex, visualIndex: visualIndex);
}

double _tileCenterX(LongLineVisualIndex visualIndex, int tileIndex) =>
    (visualIndex.startXOf(tileIndex) + visualIndex.endXOf(tileIndex)) / 2;

int _shapingFragmentCount(List<LongLineVisualTile> tiles, int firstTile, int endTile) {
  var count = 1;
  for (var index = firstTile + 1; index < endTile; index++) {
    if (!_tilesShapeTogether(tiles[index - 1], tiles[index])) count++;
  }
  return count;
}

bool _tilesShapeTogether(LongLineVisualTile previous, LongLineVisualTile current) =>
    previous.paintRunIndex == current.paintRunIndex &&
    previous.level == current.level &&
    (previous.end == current.start || current.end == previous.start);

List<_ShapingFragment> _mergeShapingFragments(List<LongLineVisualTile> tiles, int firstTile, int endTile) {
  final result = <_ShapingFragment>[];
  var first = tiles[firstTile];
  var start = first.start;
  var end = first.end;
  for (var index = firstTile + 1; index < endTile; index++) {
    final current = tiles[index];
    if (_tilesShapeTogether(first, current)) {
      start = math.min(start, current.start);
      end = math.max(end, current.end);
    } else {
      result.add(_ShapingFragment(start: start, end: end, level: first.level));
      start = current.start;
      end = current.end;
    }
    first = current;
  }
  result.add(_ShapingFragment(start: start, end: end, level: first.level));
  return result;
}

final class _ShapingFragment {
  const _ShapingFragment({required this.start, required this.end, required this.level});

  final int start;
  final int end;
  final int level;
}
