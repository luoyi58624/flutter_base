import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:characters/characters.dart';
// Breaks.step 暴露 Unicode grapheme 状态机的单原子步进，Web 才能在病态长
// cluster 中途让出事件循环；Characters.moveNext 无法提供这个边界。
// ignore: implementation_imports
import 'package:characters/src/grapheme_clusters/breaks.dart' show Breaks;
// ignore: implementation_imports
import 'package:characters/src/grapheme_clusters/constants.dart' show flagNoBreak, maskFlags, stateSoTNoBreak;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show TextAffinity;

import 'long_line_bidi_index.dart';
import 'long_line_cooperative_scheduler.dart';
import 'unicode_bidi_data.g.dart';

part 'long_line_visual_index_cooperative.dart';

/// 长行 paint-retained run 内切分出的单个 grapheme-safe 视觉 tile。
@immutable
final class LongLineVisualTile {
  const LongLineVisualTile._({
    required this.visualIndex,
    required this.paintRunIndex,
    required this.start,
    required this.end,
    required this.level,
  });

  /// tile 在最终从左到右视觉序列中的索引。
  final int visualIndex;

  /// tile 所属内部 paint-retained run 的逻辑索引。
  final int paintRunIndex;

  /// 原文 UTF-16 起点，包含。
  final int start;

  /// 原文 UTF-16 终点，不包含。
  final int end;

  /// 所属 resolved bidi level。
  final int level;

  /// tile 的 UTF-16 code-unit 长度。
  int get length => end - start;

  /// tile 是否按 RTL 方向塑形与命中。
  bool get isRtl => level.isOdd;

  @override
  String toString() =>
      'LongLineVisualTile(visual: $visualIndex, paintRun: $paintRunIndex, '
      '[$start, $end), level: $level)';
}

/// logical offset 定位到视觉 tile 后的估算几何。
@immutable
final class LongLineVisualCaret {
  const LongLineVisualCaret._({
    required this.tileIndex,
    required this.requestedOffset,
    required this.offset,
    required this.localX,
    required this.visualX,
  });

  /// 候选 tile 的视觉索引。
  final int tileIndex;

  /// 调用方请求的原文 UTF-16 offset。
  final int requestedOffset;

  /// 实际落入候选 tile 的 UTF-16 offset；方向格式 gap 会投到相邻边界。
  final int offset;

  /// tile 内的估算横坐标。
  final double localX;

  /// 全行视觉坐标中的估算横坐标。
  final double visualX;
}

/// 视觉 x 命中某个 tile 后得到的估算逻辑位置。
@immutable
final class LongLineVisualHit {
  const LongLineVisualHit._({
    required this.tileIndex,
    required this.localX,
    required this.visualX,
    required this.estimatedOffset,
  });

  /// 命中的视觉 tile 索引。
  final int tileIndex;

  /// tile 内被钳制后的横坐标。
  final double localX;

  /// 全行内被钳制后的横坐标。
  final double visualX;

  /// 按 tile 总宽等比分配并吸附到 grapheme 边界的 UTF-16 offset。
  final int estimatedOffset;
}

/// 一段连续的视觉 tile 窗口。
@immutable
final class LongLineVisualWindow {
  const LongLineVisualWindow._({
    required this.firstTile,
    required this.endTile,
    required this.startX,
    required this.endX,
    required this.codeUnits,
  });

  const LongLineVisualWindow._empty() : firstTile = 0, endTile = 0, startX = 0, endX = 0, codeUnits = 0;

  /// 第一个视觉 tile 索引，包含。
  final int firstTile;

  /// 最后一个视觉 tile 之后的索引，不包含。
  final int endTile;

  /// 窗口覆盖的视觉起点。
  final double startX;

  /// 窗口覆盖的视觉终点。
  final double endX;

  /// 全部 tile core range 的 UTF-16 code-unit 总量。
  final int codeUnits;

  /// 窗口是否没有任何 tile。
  bool get isEmpty => firstTile == endTile;

  /// 窗口包含的 tile 数量。
  int get tileCount => endTile - firstTile;
}

/// 长行 visual tile、双向 offset 映射与宽度前缀的纯模型。
///
/// 模型不做 shaping。初始宽度按 [averageAdvance] 估算；调用方完成小段
/// paragraph layout 后用 [reportMeasuredWidth] 或 [reportMeasuredWidths]
/// 回填真实宽度，全部前缀与 [totalExtent] 会以 O(log T) 更新。
final class LongLineVisualIndex {
  /// 从完整逻辑行 [text] 与同一文本的 [bidiIndex] 构建视觉 tile。
  factory LongLineVisualIndex({
    required String text,
    required LongLineBidiIndex bidiIndex,
    required double averageAdvance,
    int targetTileCodeUnits = defaultTargetTileCodeUnits,
  }) {
    _requirePositiveFinite(averageAdvance, 'averageAdvance');
    if (targetTileCodeUnits <= 0) {
      throw RangeError.value(targetTileCodeUnits, 'targetTileCodeUnits', '必须大于零');
    }
    _validateBidiIndex(text, bidiIndex);
    final build = _buildTiles(text, bidiIndex, targetTileCodeUnits);
    return LongLineVisualIndex._(
      text: text,
      bidiIndex: bidiIndex,
      averageAdvance: averageAdvance,
      targetTileCodeUnits: targetTileCodeUnits,
      tiles: build.tiles,
      paintRetained: build.paintRetained,
    );
  }

  /// 在当前 isolate 内按确定性预算协作式构建 visual tile 与宽度索引。
  ///
  /// Web 长行管线应与 [LongLineBidiIndex.resolveCooperatively] 复用同一个
  /// [scheduler]，使 decode、UAX #9、grapheme 与 tile 全阶段共享连续工作
  /// 上限。省略调度器时本方法自行创建并收尾。
  static Future<LongLineVisualIndex> createCooperatively({
    required String text,
    required LongLineBidiIndex bidiIndex,
    required double averageAdvance,
    int targetTileCodeUnits = defaultTargetTileCodeUnits,
    LongLineCooperativeScheduler? scheduler,
  }) async {
    final ownsScheduler = scheduler == null;
    final actualScheduler = scheduler ?? LongLineCooperativeScheduler();
    try {
      return await _buildVisualIndexCooperatively(
        text: text,
        bidiIndex: bidiIndex,
        averageAdvance: averageAdvance,
        targetTileCodeUnits: targetTileCodeUnits,
        scheduler: actualScheduler,
      );
    } finally {
      if (ownsScheduler) actualScheduler.finish();
    }
  }

  LongLineVisualIndex._({
    required this.text,
    required this.bidiIndex,
    required double averageAdvance,
    required this.targetTileCodeUnits,
    required List<LongLineVisualTile> tiles,
    required this._paintRetained,
  }) : tiles = List<LongLineVisualTile>.unmodifiable(tiles),
       _averageAdvance = averageAdvance,
       _widths = Float64List(tiles.length),
       _measured = Uint8List(tiles.length),
       _widthTree = _FenwickWidths(tiles.length),
       _logicalTileIndices = _logicalOrder(tiles) {
    for (var index = 0; index < tiles.length; index++) {
      final width = tiles[index].length * averageAdvance;
      _widths[index] = width;
      _widthTree.add(index, width);
    }
  }

  LongLineVisualIndex._cooperative(
    this.text,
    this.bidiIndex,
    this.targetTileCodeUnits,
    List<LongLineVisualTile> tiles,
    this._paintRetained,
    this._averageAdvance,
    this._widths,
    this._measured,
    this._widthTree,
    this._logicalTileIndices,
  ) : tiles = UnmodifiableListView<LongLineVisualTile>(tiles),
      assert(_averageAdvance > 0);

  /// 默认 tile core 上限目标；病态超长单字素允许超过此目标但绝不拆分。
  static const int defaultTargetTileCodeUnits = 4096;

  /// 被索引的完整逻辑行文本。
  final String text;

  /// 与 [text] 绑定的完整 bidi 解析结果。
  final LongLineBidiIndex bidiIndex;

  /// 未实测 tile 每个 UTF-16 code unit 使用的宽度估值。
  double get averageAdvance => _averageAdvance;

  /// 构建时请求的 tile UTF-16 目标长度。
  final int targetTileCodeUnits;

  /// 按全行从左到右视觉顺序排列的只读 tiles。
  final List<LongLineVisualTile> tiles;

  double _averageAdvance;
  final Float64List _widths;
  final Uint8List _measured;
  final _FenwickWidths _widthTree;
  final Int32List _logicalTileIndices;
  final Uint8List _paintRetained;

  /// 当前估算与实测宽度合成后的全行视觉 extent。
  double get totalExtent => _widthTree.total;

  /// Fenwick 全树重建次数，仅供复杂度白盒测试。
  int get debugWidthTreeRebuildCount => _widthTree.debugRebuildCount;

  /// Fenwick 单点增量次数，仅供复杂度白盒测试。
  int get debugWidthTreeAddCount => _widthTree.debugAddCount;

  /// 返回视觉 tile [tileIndex] 当前使用的宽度。
  double widthOf(int tileIndex) {
    RangeError.checkValidIndex(tileIndex, tiles, 'tileIndex');
    return _widths[tileIndex];
  }

  /// 返回视觉 tile [tileIndex] 的视觉起点。
  double startXOf(int tileIndex) {
    RangeError.checkValidIndex(tileIndex, tiles, 'tileIndex');
    return _widthTree.prefix(tileIndex);
  }

  /// 返回视觉 tile [tileIndex] 的视觉终点。
  double endXOf(int tileIndex) {
    RangeError.checkValidIndex(tileIndex, tiles, 'tileIndex');
    return _widthTree.prefix(tileIndex + 1);
  }

  /// 判断视觉 tile [tileIndex] 是否已收到真实测量宽度。
  bool isMeasured(int tileIndex) {
    RangeError.checkValidIndex(tileIndex, tiles, 'tileIndex');
    return _measured[tileIndex] != 0;
  }

  /// 判断逻辑区间内是否存在至少一个会进入 shaping 的正文 code unit。
  bool hasPaintRetainedInRange(int start, int end) {
    RangeError.checkValueInInterval(start, 0, text.length, 'start');
    RangeError.checkValueInInterval(end, start, text.length, 'end');
    if (start == end || _logicalTileIndices.isEmpty) return false;
    var low = 0;
    var high = _logicalTileIndices.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (tiles[_logicalTileIndices[middle]].end <= start) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low >= _logicalTileIndices.length) return false;
    return tiles[_logicalTileIndices[low]].start < end;
  }

  /// 以 O(log T) 回填一个视觉 tile 的真实 [width]。
  void reportMeasuredWidth(int tileIndex, double width) => reportMeasuredWidths({tileIndex: width});

  /// 原子校验后批量回填视觉 tile 真实宽度，每项以 O(log T) 更新前缀树。
  void reportMeasuredWidths(Map<int, double> widths) {
    for (final MapEntry(key: tileIndex, value: width) in widths.entries) {
      RangeError.checkValidIndex(tileIndex, tiles, 'tileIndex');
      _requireNonNegativeFinite(width, 'widths[$tileIndex]');
    }
    for (final MapEntry(key: tileIndex, value: width) in widths.entries) {
      final previous = _widths[tileIndex];
      _widths[tileIndex] = width;
      _measured[tileIndex] = 1;
      _widthTree.add(tileIndex, width - previous);
    }
  }

  /// 以 O(T) 用新的 [averageAdvance] 重估全部尚未实测的 tile。
  ///
  /// 已经通过 [reportMeasuredWidth] 或 [reportMeasuredWidths] 回填的宽度保持
  /// 不变；Fenwick 前缀与 [totalExtent] 在方法返回前同步重建。
  void updateUnmeasuredAverageAdvance(double averageAdvance) {
    _requirePositiveFinite(averageAdvance, 'averageAdvance');
    if (averageAdvance == _averageAdvance) return;
    var changed = false;
    for (var index = 0; index < tiles.length; index++) {
      if (_measured[index] != 0) continue;
      final width = tiles[index].length * averageAdvance;
      if (_widths[index] == width) continue;
      _widths[index] = width;
      changed = true;
    }
    if (changed) _widthTree.rebuild(_widths);
    _averageAdvance = averageAdvance;
  }

  /// 原子更新任意尚未实测 tile 的估算宽度，每项以 O(log T) 增量更新前缀树。
  ///
  /// [widths] 中已实测 tile 会被忽略且不会丢失 measured 身份；未实测 tile
  /// 仍保持未实测，可继续随字体平均值或 tab 宽度模型校准。
  void updateUnmeasuredWidths(Map<int, double> widths) {
    for (final MapEntry(key: tileIndex, value: width) in widths.entries) {
      RangeError.checkValidIndex(tileIndex, tiles, 'tileIndex');
      _requireNonNegativeFinite(width, 'widths[$tileIndex]');
    }
    for (final MapEntry(key: tileIndex, value: width) in widths.entries) {
      if (_measured[tileIndex] != 0 || _widths[tileIndex] == width) continue;
      final previous = _widths[tileIndex];
      _widths[tileIndex] = width;
      _widthTree.add(tileIndex, width - previous);
    }
  }

  /// 把原文 UTF-16 [offset] 与 [affinity] 映射到稳定候选 tile 和估算视觉 x。
  ///
  /// run/tile seam 上 downstream 选择逻辑后侧 tile，upstream 选择逻辑前侧
  /// tile，因此同一个 offset 可以稳定得到两处 bidi caret。方向格式 gap 内部
  /// 按同一规则投到下一或上一 paint-retained tile 边界。没有 tile 时返回 null。
  LongLineVisualCaret? locateOffset(int offset, {required TextAffinity affinity}) {
    RangeError.checkValueInInterval(offset, 0, text.length, 'offset');
    final tileIndex = _logicalTileForOffset(offset, affinity);
    if (tileIndex == null) return null;
    final tile = tiles[tileIndex];
    final resolved = offset.clamp(tile.start, tile.end);
    final width = _widths[tileIndex];
    final logicalUnits = tile.isRtl ? tile.end - resolved : resolved - tile.start;
    final localX = tile.length == 0 ? 0.0 : width * logicalUnits / tile.length;
    return LongLineVisualCaret._(
      tileIndex: tileIndex,
      requestedOffset: offset,
      offset: resolved,
      localX: localX,
      visualX: _widthTree.prefix(tileIndex) + localX,
    );
  }

  /// 把全行视觉 [x] 命中到 tile，并估算一个 grapheme-safe UTF-16 offset。
  ///
  /// 视觉 tile seam 上 downstream 取右侧 tile，upstream 取左侧 tile。
  /// 超出全行的有限坐标会钳制到首尾；没有 tile 时返回 null。
  LongLineVisualHit? locateX(double x, {TextAffinity affinity = TextAffinity.downstream}) {
    _requireFinite(x, 'x');
    if (tiles.isEmpty) return null;
    final visualX = x.clamp(0.0, totalExtent);
    final tileIndex = _tileAtX(visualX, affinity);
    final tile = tiles[tileIndex];
    final startX = _widthTree.prefix(tileIndex);
    final width = _widths[tileIndex];
    final localX = (visualX - startX).clamp(0.0, width);
    final ratio = width <= 0 ? (affinity == TextAffinity.upstream ? 0.0 : 1.0) : localX / width;
    final raw = tile.isRtl ? tile.end - ratio * tile.length : tile.start + ratio * tile.length;
    final offset = _nearestGraphemeBoundary(text, raw.round().clamp(tile.start, tile.end), tile, affinity);
    return LongLineVisualHit._(tileIndex: tileIndex, localX: localX, visualX: visualX, estimatedOffset: offset);
  }

  /// 选择覆盖 viewport 与 [guard] 的连续视觉 tile 窗口。
  ///
  /// [maxCodeUnits] 是硬预算；若锚点 tile 自身已超过预算，返回空窗口，绝不
  /// 为满足可见性突破预算。预算不足覆盖全部 guard 时从 viewport 中心向两侧
  /// 按视觉距离扩张，结果始终是连续的 `[firstTile, endTile)`。
  LongLineVisualWindow selectViewport({
    required double viewportStart,
    required double viewportEnd,
    required double guard,
    required int maxCodeUnits,
  }) {
    _requireFinite(viewportStart, 'viewportStart');
    _requireFinite(viewportEnd, 'viewportEnd');
    _requireNonNegativeFinite(guard, 'guard');
    if (viewportEnd < viewportStart) {
      throw ArgumentError.value((viewportStart, viewportEnd), 'viewport', 'end 必须不小于 start');
    }
    if (maxCodeUnits <= 0) throw RangeError.value(maxCodeUnits, 'maxCodeUnits', '必须大于零');
    if (tiles.isEmpty || viewportEnd + guard < 0 || viewportStart - guard > totalExtent) {
      return const LongLineVisualWindow._empty();
    }

    final targetStart = (viewportStart - guard).clamp(0.0, totalExtent);
    final targetEnd = (viewportEnd + guard).clamp(0.0, totalExtent);
    var desiredFirst = _tileAtX(targetStart, TextAffinity.downstream);
    var desiredLast = _tileAtX(targetEnd, TextAffinity.upstream);
    // 零宽目标恰好落在 seam 时，两种 affinity 会指向 seam 两侧。窗口必须
    // 仍有单一连续锚点，统一取视觉右侧，避免形成反向区间。
    if (desiredFirst > desiredLast) desiredLast = desiredFirst;
    final center = ((viewportStart + viewportEnd) / 2).clamp(targetStart, targetEnd);
    final anchor = _tileAtX(center, TextAffinity.downstream).clamp(desiredFirst, desiredLast);
    final anchorUnits = tiles[anchor].length;
    if (anchorUnits > maxCodeUnits) return const LongLineVisualWindow._empty();

    var first = anchor;
    var last = anchor;
    var codeUnits = anchorUnits;
    var leftBlocked = false;
    var rightBlocked = false;
    while ((!leftBlocked && first > desiredFirst) || (!rightBlocked && last < desiredLast)) {
      final left = first > desiredFirst && !leftBlocked ? first - 1 : null;
      final right = last < desiredLast && !rightBlocked ? last + 1 : null;
      final chooseLeft = switch ((left, right)) {
        (null, null) => false,
        (final int _, null) => true,
        (null, final int _) => false,
        (final int left, final int right) =>
          (center - _tileCenterX(left)).abs() <= (_tileCenterX(right) - center).abs(),
      };
      final candidate = chooseLeft ? left! : right!;
      final nextUnits = codeUnits + tiles[candidate].length;
      if (nextUnits > maxCodeUnits) {
        if (chooseLeft) {
          leftBlocked = true;
        } else {
          rightBlocked = true;
        }
        continue;
      }
      codeUnits = nextUnits;
      if (chooseLeft) {
        first = candidate;
      } else {
        last = candidate;
      }
    }
    return LongLineVisualWindow._(
      firstTile: first,
      endTile: last + 1,
      startX: _widthTree.prefix(first),
      endX: _widthTree.prefix(last + 1),
      codeUnits: codeUnits,
    );
  }

  double _tileCenterX(int tileIndex) => (_widthTree.prefix(tileIndex) + _widthTree.prefix(tileIndex + 1)) / 2;

  int _tileAtX(double x, TextAffinity affinity) {
    if (x >= totalExtent) return tiles.length - 1;
    var index = _widthTree.indexAt(x);
    if (affinity == TextAffinity.upstream && index > 0 && x == _widthTree.prefix(index)) index--;
    return index;
  }

  int? _logicalTileForOffset(int offset, TextAffinity affinity) {
    if (_logicalTileIndices.isEmpty) return null;
    var low = 0;
    var high = _logicalTileIndices.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (tiles[_logicalTileIndices[middle]].start < offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final afterPosition = low;
    final beforePosition = low - 1;
    if (beforePosition >= 0) {
      final before = tiles[_logicalTileIndices[beforePosition]];
      if (offset > before.start && offset < before.end) return before.visualIndex;
    }

    final touchesFormattingGap =
        (offset < _paintRetained.length && _paintRetained[offset] == 0) ||
        (offset > 0 && _paintRetained[offset - 1] == 0);
    if (touchesFormattingGap) {
      if (affinity == TextAffinity.downstream) {
        if (afterPosition < _logicalTileIndices.length) return _logicalTileIndices[afterPosition];
        return _logicalTileIndices.last;
      }
      if (beforePosition >= 0) return _logicalTileIndices[beforePosition];
      return _logicalTileIndices.first;
    }

    int? startsAt;
    if (afterPosition < _logicalTileIndices.length) {
      final candidate = tiles[_logicalTileIndices[afterPosition]];
      if (candidate.start == offset) startsAt = candidate.visualIndex;
    }
    int? endsAt;
    if (beforePosition >= 0) {
      final candidate = tiles[_logicalTileIndices[beforePosition]];
      if (candidate.end == offset) endsAt = candidate.visualIndex;
    }
    if (affinity == TextAffinity.downstream) {
      if (startsAt != null) return startsAt;
      if (endsAt != null) return endsAt;
      if (afterPosition < _logicalTileIndices.length) return _logicalTileIndices[afterPosition];
      return _logicalTileIndices.last;
    }
    if (endsAt != null) return endsAt;
    if (startsAt != null) return startsAt;
    if (beforePosition >= 0) return _logicalTileIndices[beforePosition];
    return _logicalTileIndices.first;
  }
}

_VisualTileBuild _buildTiles(String text, LongLineBidiIndex bidiIndex, int targetTileCodeUnits) {
  final paintRetained = Uint8List(text.length);
  if (text.isEmpty) return _VisualTileBuild(tiles: const <LongLineVisualTile>[], paintRetained: paintRetained);
  final paintRuns = _buildPaintRuns(text, bidiIndex, paintRetained);
  final byRun = <int, List<_TileCore>>{};
  for (var runIndex = 0; runIndex < paintRuns.length; runIndex++) {
    final run = paintRuns[runIndex];
    if (!run.retained) continue;
    final cores = <_TileCore>[];
    var start = run.start;
    while (start < run.end) {
      final rawEnd = math.min(run.end, start + targetTileCodeUnits);
      final end = rawEnd == run.end ? run.end : _graphemeBoundaryAfter(text, rawEnd, start, run.end);
      if (end <= start || end > run.end) {
        throw StateError('无法在 run [$start, ${run.end}) 内建立有效 grapheme-safe tile');
      }
      cores.add(_TileCore(start: start, end: end));
      start = end;
    }
    byRun[runIndex] = cores;
  }

  final result = <LongLineVisualTile>[];
  for (final runIndex in _paintVisualRunOrder(paintRuns)) {
    final run = paintRuns[runIndex];
    final cores = byRun[runIndex]!;
    final iterable = run.isRtl ? cores.reversed : cores;
    for (final core in iterable) {
      result.add(
        LongLineVisualTile._(
          visualIndex: result.length,
          paintRunIndex: runIndex,
          start: core.start,
          end: core.end,
          level: run.level,
        ),
      );
    }
  }
  return _VisualTileBuild(tiles: result, paintRetained: paintRetained);
}

List<_PaintRun> _buildPaintRuns(String text, LongLineBidiIndex bidiIndex, Uint8List paintRetained) {
  final bidiClasses = Uint8List(text.length);
  for (var offset = 0; offset < text.length;) {
    final first = text.codeUnitAt(offset);
    var rune = first;
    var width = 1;
    if (_isHighSurrogate(first) && offset + 1 < text.length) {
      final second = text.codeUnitAt(offset + 1);
      if (_isLowSurrogate(second)) {
        rune = 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00;
        width = 2;
      }
    }
    if (_isSurrogate(rune)) rune = 0xfffd;
    final bidiClass = unicodeBidiClassOf(rune);
    final retained = !_isFormattingControl(bidiClass);
    for (var unit = 0; unit < width; unit++) {
      paintRetained[offset + unit] = retained ? 1 : 0;
      bidiClasses[offset + unit] = bidiClass.index;
    }
    offset += width;
  }

  // BN 在 UAX #9 中于隐式 level 前被 X9 移除，原始 levels 因而不适合直接
  // 送 shaping。绘制层保留 BN，并继承前一真实正文 level；行首回退后一正文，
  // 才能让 Arabic 字母与内部 ZWNJ/ZWJ 落在同一可塑形片段。
  final nextContentLevels = Uint8List(text.length)..fillRange(0, text.length, 0xff);
  var nextContentLevel = -1;
  for (var offset = text.length - 1; offset >= 0; offset--) {
    if (paintRetained[offset] != 0 && bidiClasses[offset] != UnicodeBidiClass.bn.index) {
      nextContentLevel = bidiIndex.levels[offset];
    }
    if (nextContentLevel >= 0) nextContentLevels[offset] = nextContentLevel;
  }

  var previousContentLevel = -1;
  for (var offset = 0; offset < text.length; offset++) {
    final retained = paintRetained[offset] != 0;
    var level = bidiIndex.levels[offset];
    if (retained && bidiClasses[offset] == UnicodeBidiClass.bn.index) {
      level = previousContentLevel >= 0
          ? previousContentLevel
          : nextContentLevels[offset] != 0xff
          ? nextContentLevels[offset]
          : bidiIndex.paragraphLevel;
    } else if (retained) {
      previousContentLevel = level;
    }
    nextContentLevels[offset] = level;
  }

  final graphemeRange = CharacterRange(text);
  graphemeRange.moveNext();
  var graphemeEnd = text.length - graphemeRange.stringAfterLength;
  final result = <_PaintRun>[];
  var runStart = 0;
  // Paragraph shaping 不能在 extended grapheme 内切 run。cluster 内即使 UAX
  // resolved level 变化，也统一继承首个 code unit 的 shaping level；原始方向
  // 格式控制仍优先成为 gap，避免泄漏进 synthetic wrapper。
  var runLevel = nextContentLevels[0];
  var runRetained = paintRetained[0] != 0;
  for (var offset = 1; offset < text.length; offset++) {
    final atGraphemeBoundary = offset == graphemeEnd;
    if (atGraphemeBoundary) {
      graphemeRange.moveNext();
      graphemeEnd = text.length - graphemeRange.stringAfterLength;
    }
    final retained = paintRetained[offset] != 0;
    final level = nextContentLevels[offset];
    final mustSplit = retained != runRetained || (level != runLevel && atGraphemeBoundary);
    if (mustSplit) {
      result.add(_PaintRun(start: runStart, end: offset, level: runLevel, retained: runRetained));
      runStart = offset;
      runLevel = level;
      runRetained = retained;
    }
  }
  result.add(_PaintRun(start: runStart, end: text.length, level: runLevel, retained: runRetained));
  return result;
}

Int32List _paintVisualRunOrder(List<_PaintRun> runs) {
  final retained = <int>[
    for (var index = 0; index < runs.length; index++)
      if (runs[index].retained) index,
  ];
  if (retained.isEmpty) return Int32List(0);
  var maximumLevel = 0;
  var minimumOddLevel = 0x7fffffff;
  for (final runIndex in retained) {
    final level = runs[runIndex].level;
    maximumLevel = math.max(maximumLevel, level);
    if (level.isOdd) minimumOddLevel = math.min(minimumOddLevel, level);
  }
  if (minimumOddLevel == 0x7fffffff) return Int32List.fromList(retained);
  for (var level = maximumLevel; level >= minimumOddLevel; level--) {
    var start = 0;
    while (start < retained.length) {
      if (runs[retained[start]].level < level) {
        start++;
        continue;
      }
      var end = start + 1;
      while (end < retained.length && runs[retained[end]].level >= level) {
        end++;
      }
      _reverseIntRange(retained, start, end - 1);
      start = end;
    }
  }
  return Int32List.fromList(retained);
}

void _reverseIntRange(List<int> values, int start, int end) {
  while (start < end) {
    final value = values[start];
    values[start++] = values[end];
    values[end--] = value;
  }
}

bool _isFormattingControl(UnicodeBidiClass value) => switch (value) {
  UnicodeBidiClass.lre ||
  UnicodeBidiClass.lro ||
  UnicodeBidiClass.rle ||
  UnicodeBidiClass.rlo ||
  UnicodeBidiClass.pdf ||
  UnicodeBidiClass.lri ||
  UnicodeBidiClass.rli ||
  UnicodeBidiClass.fsi ||
  UnicodeBidiClass.pdi => true,
  _ => false,
};

int _graphemeBoundaryAfter(String text, int offset, int lowerBound, int upperBound) {
  final range = CharacterRange.at(text, offset);
  if (range.isEmpty) return offset;
  final after = text.length - range.stringAfterLength;
  if (after <= upperBound) return after;
  final before = range.stringBeforeLength;
  if (before > lowerBound) return before;
  return upperBound;
}

int _nearestGraphemeBoundary(String text, int offset, LongLineVisualTile tile, TextAffinity affinity) {
  if (offset <= tile.start) return tile.start;
  if (offset >= tile.end) return tile.end;
  final range = CharacterRange.at(text, offset);
  if (range.isEmpty) return offset;
  final before = range.stringBeforeLength.clamp(tile.start, tile.end);
  final after = (text.length - range.stringAfterLength).clamp(tile.start, tile.end);
  final beforeDistance = offset - before;
  final afterDistance = after - offset;
  if (beforeDistance == afterDistance) return affinity == TextAffinity.upstream ? before : after;
  return beforeDistance < afterDistance ? before : after;
}

Int32List _logicalOrder(List<LongLineVisualTile> tiles) {
  final indices = List<int>.generate(tiles.length, (index) => index)
    ..sort((left, right) {
      final start = tiles[left].start.compareTo(tiles[right].start);
      return start != 0 ? start : tiles[left].end.compareTo(tiles[right].end);
    });
  return Int32List.fromList(indices);
}

void _validateBidiIndex(String text, LongLineBidiIndex bidiIndex) {
  if (bidiIndex.utf16Length != text.length ||
      bidiIndex.x9Removed.length != text.length ||
      bidiIndex.logicalToVisual.length != text.length ||
      bidiIndex.visualToLogical.length != text.length) {
    throw ArgumentError.value(bidiIndex, 'bidiIndex', '必须由完全相同的 UTF-16 文本解析');
  }
  var expectedStart = 0;
  for (var index = 0; index < bidiIndex.logicalRuns.length; index++) {
    final run = bidiIndex.logicalRuns[index];
    if (run.start != expectedStart || run.end <= run.start || run.end > text.length) {
      throw ArgumentError.value(bidiIndex, 'bidiIndex', 'logicalRuns 必须无缝分割完整文本');
    }
    expectedStart = run.end;
  }
  if (expectedStart != text.length) {
    throw ArgumentError.value(bidiIndex, 'bidiIndex', 'logicalRuns 没有覆盖完整文本');
  }

  final seen = Uint8List(bidiIndex.logicalRuns.length);
  for (final runIndex in bidiIndex.visualRunOrder) {
    if (runIndex < 0 || runIndex >= bidiIndex.logicalRuns.length) {
      throw ArgumentError.value(bidiIndex, 'bidiIndex', 'visualRunOrder 含越界索引 $runIndex');
    }
    if (bidiIndex.logicalRuns[runIndex].removed || seen[runIndex] != 0) {
      throw ArgumentError.value(bidiIndex, 'bidiIndex', 'visualRunOrder 必须恰好包含每个非 removed run');
    }
    seen[runIndex] = 1;
  }
  for (var index = 0; index < bidiIndex.logicalRuns.length; index++) {
    if (!bidiIndex.logicalRuns[index].removed && seen[index] == 0) {
      throw ArgumentError.value(bidiIndex, 'bidiIndex', 'visualRunOrder 缺少非 removed run $index');
    }
  }
}

void _requireFinite(double value, String name) {
  if (!value.isFinite) throw ArgumentError.value(value, name, '必须是有限数值');
}

void _requirePositiveFinite(double value, String name) {
  if (!value.isFinite || value <= 0) throw ArgumentError.value(value, name, '必须是有限正数');
}

void _requireNonNegativeFinite(double value, String name) {
  if (!value.isFinite || value < 0) throw ArgumentError.value(value, name, '必须是有限非负数');
}

final class _TileCore {
  const _TileCore({required this.start, required this.end});

  final int start;
  final int end;
}

final class _VisualTileBuild {
  const _VisualTileBuild({required this.tiles, required this.paintRetained});

  final List<LongLineVisualTile> tiles;
  final Uint8List paintRetained;
}

final class _PaintRun {
  const _PaintRun({required this.start, required this.end, required this.level, required this.retained});

  final int start;
  final int end;
  final int level;
  final bool retained;

  bool get isRtl => level.isOdd;
}

bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;

bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

bool _isSurrogate(int value) => value >= 0xd800 && value <= 0xdfff;

final class _FenwickWidths {
  _FenwickWidths(int length) : _tree = Float64List(length + 1);

  final Float64List _tree;
  int debugAddCount = 0;
  int debugRebuildCount = 0;

  int get length => _tree.length - 1;

  double get total => prefix(length);

  void add(int index, double delta) {
    debugAddCount++;
    for (var node = index + 1; node < _tree.length; node += node & -node) {
      _tree[node] += delta;
    }
  }

  void rebuild(Float64List widths) {
    debugRebuildCount++;
    assert(widths.length == length);
    _tree.fillRange(0, _tree.length, 0.0);
    for (var node = 1; node < _tree.length; node++) {
      _tree[node] += widths[node - 1];
      final parent = node + (node & -node);
      if (parent < _tree.length) _tree[parent] += _tree[node];
    }
  }

  double prefix(int end) {
    var result = 0.0;
    for (var node = end; node > 0; node -= node & -node) {
      result += _tree[node];
    }
    return result;
  }

  int indexAt(double x) {
    assert(length > 0);
    var index = 0;
    var sum = 0.0;
    var bit = 1;
    while ((bit << 1) <= length) {
      bit <<= 1;
    }
    while (bit != 0) {
      final next = index + bit;
      if (next <= length && sum + _tree[next] <= x) {
        index = next;
        sum += _tree[next];
      }
      bit >>= 1;
    }
    return index.clamp(0, length - 1);
  }
}
