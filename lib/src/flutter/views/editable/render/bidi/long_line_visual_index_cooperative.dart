part of 'long_line_visual_index.dart';

int _visualBatch(LongLineCooperativeScheduler scheduler, int remaining) =>
    math.min(remaining, math.min(8 * 1024, scheduler.maxWorkUnitsBeforeYield));

Future<void> _reserveVisual(LongLineCooperativeScheduler scheduler, int workUnits, String phase) async {
  final pending = scheduler.reserve(workUnits, phase: phase);
  if (pending != null) await pending;
}

Future<Uint8List> _allocateVisualUint8(LongLineCooperativeScheduler scheduler, int length, String phase) =>
    scheduler.runUninterruptible<Uint8List>(
      codeUnits: length,
      bytes: length,
      phase: phase,
      materialization: false,
      operation: () => Uint8List(length),
    );

Future<Int32List> _allocateVisualInt32(LongLineCooperativeScheduler scheduler, int length, String phase) =>
    scheduler.runUninterruptible<Int32List>(
      codeUnits: length,
      bytes: length * 4,
      phase: phase,
      materialization: false,
      operation: () => Int32List(length),
    );

Future<Float64List> _allocateVisualFloat64(LongLineCooperativeScheduler scheduler, int length, String phase) =>
    scheduler.runUninterruptible<Float64List>(
      codeUnits: length,
      bytes: length * 8,
      phase: phase,
      materialization: false,
      operation: () => Float64List(length),
    );

Future<LongLineVisualIndex> _buildVisualIndexCooperatively({
  required String text,
  required LongLineBidiIndex bidiIndex,
  required double averageAdvance,
  required int targetTileCodeUnits,
  required LongLineCooperativeScheduler scheduler,
}) async {
  _requirePositiveFinite(averageAdvance, 'averageAdvance');
  if (targetTileCodeUnits <= 0) {
    throw RangeError.value(targetTileCodeUnits, 'targetTileCodeUnits', '必须大于零');
  }
  await _validateBidiIndexCooperatively(text, bidiIndex, scheduler);
  final build = await _buildTilesCooperatively(text, bidiIndex, targetTileCodeUnits, scheduler);
  final tileCount = build.tiles.length;
  final widths = await _allocateVisualFloat64(scheduler, tileCount, 'visual.allocate.widths');
  final measured = await _allocateVisualUint8(scheduler, tileCount, 'visual.allocate.measured');
  final widthTree = await scheduler.runUninterruptible<_FenwickWidths>(
    codeUnits: tileCount + 1,
    bytes: (tileCount + 1) * 8,
    phase: 'visual.allocate.width-tree',
    materialization: false,
    operation: () => _FenwickWidths(tileCount),
  );
  var index = 0;
  while (index < build.tiles.length) {
    final batch = math.min(build.tiles.length - index, math.max(1, scheduler.maxWorkUnitsBeforeYield ~/ 32));
    await _reserveVisual(scheduler, batch * 32, 'visual.width-index');
    final end = index + batch;
    while (index < end) {
      final width = build.tiles[index].length * averageAdvance;
      widths[index] = width;
      widthTree.add(index, width);
      index++;
    }
  }
  return LongLineVisualIndex._cooperative(
    text,
    bidiIndex,
    targetTileCodeUnits,
    build.tiles,
    build.paintRetained,
    averageAdvance,
    widths,
    measured,
    widthTree,
    build.logicalTileIndices,
  );
}

Future<void> _validateBidiIndexCooperatively(
  String text,
  LongLineBidiIndex bidiIndex,
  LongLineCooperativeScheduler scheduler,
) async {
  if (bidiIndex.utf16Length != text.length ||
      bidiIndex.x9Removed.length != text.length ||
      bidiIndex.logicalToVisual.length != text.length ||
      bidiIndex.visualToLogical.length != text.length) {
    throw ArgumentError.value(bidiIndex, 'bidiIndex', '必须由完全相同的 UTF-16 文本解析');
  }
  var expectedStart = 0;
  for (var start = 0; start < bidiIndex.logicalRuns.length;) {
    final batch = _visualBatch(scheduler, bidiIndex.logicalRuns.length - start);
    await _reserveVisual(scheduler, batch, 'visual.validate-runs');
    final end = start + batch;
    for (var index = start; index < end; index++) {
      final run = bidiIndex.logicalRuns[index];
      if (run.start != expectedStart || run.end <= run.start || run.end > text.length) {
        throw ArgumentError.value(bidiIndex, 'bidiIndex', 'logicalRuns 必须无缝分割完整文本');
      }
      expectedStart = run.end;
    }
    start = end;
  }
  if (expectedStart != text.length) {
    throw ArgumentError.value(bidiIndex, 'bidiIndex', 'logicalRuns 没有覆盖完整文本');
  }

  final seen = await _allocateVisualUint8(scheduler, bidiIndex.logicalRuns.length, 'visual.allocate.validation');
  for (var start = 0; start < bidiIndex.visualRunOrder.length;) {
    final batch = _visualBatch(scheduler, bidiIndex.visualRunOrder.length - start);
    await _reserveVisual(scheduler, batch, 'visual.validate-order');
    final end = start + batch;
    for (var index = start; index < end; index++) {
      final runIndex = bidiIndex.visualRunOrder[index];
      if (runIndex < 0 || runIndex >= bidiIndex.logicalRuns.length) {
        throw ArgumentError.value(bidiIndex, 'bidiIndex', 'visualRunOrder 含越界索引 $runIndex');
      }
      if (bidiIndex.logicalRuns[runIndex].removed || seen[runIndex] != 0) {
        throw ArgumentError.value(bidiIndex, 'bidiIndex', 'visualRunOrder 必须恰好包含每个非 removed run');
      }
      seen[runIndex] = 1;
    }
    start = end;
  }
  for (var start = 0; start < bidiIndex.logicalRuns.length;) {
    final batch = _visualBatch(scheduler, bidiIndex.logicalRuns.length - start);
    await _reserveVisual(scheduler, batch, 'visual.validate-coverage');
    final end = start + batch;
    for (var index = start; index < end; index++) {
      if (!bidiIndex.logicalRuns[index].removed && seen[index] == 0) {
        throw ArgumentError.value(bidiIndex, 'bidiIndex', 'visualRunOrder 缺少非 removed run $index');
      }
    }
    start = end;
  }
}

Future<_CooperativeVisualTileBuild> _buildTilesCooperatively(
  String text,
  LongLineBidiIndex bidiIndex,
  int targetTileCodeUnits,
  LongLineCooperativeScheduler scheduler,
) async {
  final paintRetained = await _allocateVisualUint8(scheduler, text.length, 'visual.allocate.paint-mask');
  if (text.isEmpty) {
    return _CooperativeVisualTileBuild(
      tiles: const <LongLineVisualTile>[],
      paintRetained: paintRetained,
      logicalTileIndices: Int32List(0),
    );
  }
  final paintBuild = await _buildPaintRunsCooperatively(text, bidiIndex, paintRetained, scheduler);
  final paintRuns = paintBuild.runs;
  final graphemeBoundaries = paintBuild.graphemeBoundaries;
  final runTileCounts = await _allocateVisualInt32(scheduler, paintRuns.length, 'visual.allocate.run-tile-counts');
  final runTileStarts = await _allocateVisualInt32(scheduler, paintRuns.length + 1, 'visual.allocate.run-tile-starts');
  var totalTileCount = 0;
  var runCredit = 0;
  var runEpoch = scheduler.reservationEpoch;
  for (var runIndex = 0; runIndex < paintRuns.length; runIndex++) {
    if (runCredit == 0) {
      runCredit = _visualBatch(scheduler, paintRuns.length - runIndex);
      await _reserveVisual(scheduler, runCredit, 'visual.tiles.runs');
      runEpoch = scheduler.reservationEpoch;
    }
    runCredit--;
    runTileStarts[runIndex] = totalTileCount;
    final run = paintRuns[runIndex];
    if (run.retained) {
      var start = run.start;
      var count = 0;
      var countCredit = 0;
      var countEpoch = scheduler.reservationEpoch;
      while (start < run.end) {
        final rawEnd = math.min(run.end, start + targetTileCodeUnits);
        final end = rawEnd == run.end
            ? run.end
            : await _graphemeBoundaryAfterCooperatively(graphemeBoundaries, rawEnd, start, run.end, scheduler);
        if (end <= start || end > run.end) {
          throw StateError('无法在 run [$start, ${run.end}) 内建立有效 grapheme-safe tile');
        }
        if (scheduler.discardReservationIfStale(countEpoch, countCredit)) countCredit = 0;
        if (countCredit == 0) {
          final remainingUpperBound = ((run.end - start) + targetTileCodeUnits - 1) ~/ targetTileCodeUnits;
          countCredit = _visualBatch(scheduler, remainingUpperBound);
          await _reserveVisual(scheduler, countCredit, 'visual.tiles.count');
          countEpoch = scheduler.reservationEpoch;
        }
        countCredit--;
        count++;
        start = end;
      }
      runTileCounts[runIndex] = count;
      totalTileCount += count;
    }
    if (scheduler.discardReservationIfStale(runEpoch, runCredit)) runCredit = 0;
  }
  runTileStarts[paintRuns.length] = totalTileCount;

  final coreStarts = await _allocateVisualInt32(scheduler, totalTileCount, 'visual.allocate.tile-core-starts');
  final coreEnds = await _allocateVisualInt32(scheduler, totalTileCount, 'visual.allocate.tile-core-ends');
  final coreVisualIndices = await _allocateVisualInt32(
    scheduler,
    totalTileCount,
    'visual.allocate.tile-core-visual-indices',
  );
  for (var runIndex = 0; runIndex < paintRuns.length; runIndex++) {
    final run = paintRuns[runIndex];
    if (!run.retained) continue;
    var coreIndex = runTileStarts[runIndex];
    var start = run.start;
    while (start < run.end) {
      final rawEnd = math.min(run.end, start + targetTileCodeUnits);
      final end = rawEnd == run.end
          ? run.end
          : await _graphemeBoundaryAfterCooperatively(graphemeBoundaries, rawEnd, start, run.end, scheduler);
      if (end <= start || end > run.end) {
        throw StateError('无法在 run [$start, ${run.end}) 内建立有效 grapheme-safe tile');
      }
      final tileYield = scheduler.reserve(1, phase: 'visual.tiles.cores-fill');
      if (tileYield != null) await tileYield;
      coreStarts[coreIndex] = start;
      coreEnds[coreIndex] = end;
      coreIndex++;
      start = end;
    }
    assert(coreIndex == runTileStarts[runIndex] + runTileCounts[runIndex]);
  }

  final visualRunOrder = await _paintVisualRunOrderCooperatively(paintRuns, scheduler);
  final result = await scheduler.runUninterruptible<List<LongLineVisualTile>>(
    codeUnits: totalTileCount,
    bytes: 24 + totalTileCount * 8,
    phase: 'visual.allocate.tile-result-list',
    materialization: false,
    operation: () => List<LongLineVisualTile>.filled(
      totalTileCount,
      const LongLineVisualTile._(visualIndex: -1, paintRunIndex: -1, start: 0, end: 0, level: 0),
    ),
  );
  var visualIndex = 0;
  var tileCredit = 0;
  for (final runIndex in visualRunOrder) {
    final run = paintRuns[runIndex];
    final coreStart = runTileStarts[runIndex];
    final coreEnd = coreStart + runTileCounts[runIndex];
    var coreIndex = run.isRtl ? coreEnd - 1 : coreStart;
    while (run.isRtl ? coreIndex >= coreStart : coreIndex < coreEnd) {
      if (tileCredit == 0) {
        tileCredit = _visualBatch(scheduler, math.max(1, totalTileCount - visualIndex));
        await _reserveVisual(scheduler, tileCredit, 'visual.tiles.objects');
      }
      tileCredit--;
      coreVisualIndices[coreIndex] = visualIndex;
      result[visualIndex] = LongLineVisualTile._(
        visualIndex: visualIndex,
        paintRunIndex: runIndex,
        start: coreStarts[coreIndex],
        end: coreEnds[coreIndex],
        level: run.level,
      );
      visualIndex++;
      coreIndex += run.isRtl ? -1 : 1;
    }
  }
  assert(visualIndex == totalTileCount);

  final logicalTileIndices = await _allocateVisualInt32(scheduler, totalTileCount, 'visual.allocate.logical-order');
  for (var start = 0; start < totalTileCount;) {
    final batch = _visualBatch(scheduler, totalTileCount - start);
    await _reserveVisual(scheduler, batch, 'visual.tiles.logical-order');
    final end = start + batch;
    for (var index = start; index < end; index++) {
      logicalTileIndices[index] = coreVisualIndices[index];
    }
    start = end;
  }
  return _CooperativeVisualTileBuild(
    tiles: result,
    paintRetained: paintRetained,
    logicalTileIndices: logicalTileIndices,
  );
}

Future<_CooperativePaintRunBuild> _buildPaintRunsCooperatively(
  String text,
  LongLineBidiIndex bidiIndex,
  Uint8List paintRetained,
  LongLineCooperativeScheduler scheduler,
) async {
  final bidiClasses = await _allocateVisualUint8(scheduler, text.length, 'visual.allocate.bidi-classes');
  var offset = 0;
  while (offset < text.length) {
    final batch = _visualBatch(scheduler, text.length - offset);
    await _reserveVisual(scheduler, batch, 'visual.paint.decode');
    var processed = 0;
    while (offset < text.length && processed < batch) {
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
      processed++;
    }
  }

  final nextContentLevels = await _allocateVisualUint8(scheduler, text.length, 'visual.allocate.content-levels');
  for (var start = 0; start < text.length;) {
    final batch = _visualBatch(scheduler, text.length - start);
    await _reserveVisual(scheduler, batch, 'visual.paint.initialize-levels');
    final end = start + batch;
    nextContentLevels.fillRange(start, end, 0xff);
    start = end;
  }
  var nextContentLevel = -1;
  offset = text.length - 1;
  while (offset >= 0) {
    final batch = _visualBatch(scheduler, offset + 1);
    await _reserveVisual(scheduler, batch, 'visual.paint.next-level');
    final stop = offset - batch;
    while (offset > stop) {
      if (paintRetained[offset] != 0 && bidiClasses[offset] != UnicodeBidiClass.bn.index) {
        nextContentLevel = bidiIndex.levels[offset];
      }
      if (nextContentLevel >= 0) nextContentLevels[offset] = nextContentLevel;
      offset--;
    }
  }

  var previousContentLevel = -1;
  for (var start = 0; start < text.length;) {
    final batch = _visualBatch(scheduler, text.length - start);
    await _reserveVisual(scheduler, batch, 'visual.paint.resolve-level');
    final end = start + batch;
    for (offset = start; offset < end; offset++) {
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
    start = end;
  }

  final boundaries = await _graphemeBoundariesCooperatively(text, scheduler);
  var runLevel = nextContentLevels[0];
  var runRetained = paintRetained[0] != 0;
  var runCount = 1;
  for (var start = 1; start < text.length;) {
    final batch = _visualBatch(scheduler, text.length - start);
    await _reserveVisual(scheduler, batch, 'visual.paint.runs-count');
    final end = start + batch;
    for (offset = start; offset < end; offset++) {
      final retained = paintRetained[offset] != 0;
      final level = nextContentLevels[offset];
      final mustSplit = retained != runRetained || (level != runLevel && boundaries[offset] != 0);
      if (mustSplit) {
        runCount++;
        runLevel = level;
        runRetained = retained;
      }
    }
    start = end;
  }

  final result = await scheduler.runUninterruptible<List<_PaintRun>>(
    codeUnits: runCount,
    bytes: 24 + runCount * 8,
    phase: 'visual.allocate.paint-runs',
    materialization: false,
    operation: () => List<_PaintRun>.filled(runCount, const _PaintRun(start: 0, end: 0, level: 0, retained: false)),
  );
  var runStart = 0;
  runLevel = nextContentLevels[0];
  runRetained = paintRetained[0] != 0;
  var runIndex = 0;
  for (var start = 1; start < text.length;) {
    final batch = _visualBatch(scheduler, text.length - start);
    await _reserveVisual(scheduler, batch, 'visual.paint.runs-fill');
    final end = start + batch;
    for (offset = start; offset < end; offset++) {
      final retained = paintRetained[offset] != 0;
      final level = nextContentLevels[offset];
      final mustSplit = retained != runRetained || (level != runLevel && boundaries[offset] != 0);
      if (mustSplit) {
        result[runIndex++] = _PaintRun(start: runStart, end: offset, level: runLevel, retained: runRetained);
        runStart = offset;
        runLevel = level;
        runRetained = retained;
      }
    }
    start = end;
  }
  result[runIndex] = _PaintRun(start: runStart, end: text.length, level: runLevel, retained: runRetained);
  assert(runIndex + 1 == runCount);
  return _CooperativePaintRunBuild(runs: result, graphemeBoundaries: boundaries);
}

Future<Uint8List> _graphemeBoundariesCooperatively(String text, LongLineCooperativeScheduler scheduler) async {
  final boundaries = await _allocateVisualUint8(scheduler, text.length + 1, 'visual.allocate.grapheme-boundaries');
  boundaries[0] = 1;
  if (text.isEmpty) return boundaries;
  final breaks = Breaks(text, 0, text.length, stateSoTNoBreak);
  var credit = 0;
  while (breaks.cursor < breaks.end) {
    if (credit == 0) {
      credit = _visualBatch(scheduler, breaks.end - breaks.cursor);
      await _reserveVisual(scheduler, credit, 'visual.grapheme');
    }
    credit--;
    final breakAt = breaks.cursor;
    breaks.step();
    if (breaks.state & maskFlags != flagNoBreak) boundaries[breakAt] = 1;
  }
  boundaries[text.length] = 1;
  return boundaries;
}

Future<int> _graphemeBoundaryAfterCooperatively(
  Uint8List boundaries,
  int offset,
  int lowerBound,
  int upperBound,
  LongLineCooperativeScheduler scheduler,
) async {
  var after = offset;
  while (after <= upperBound && boundaries[after] == 0) {
    final batch = _visualBatch(scheduler, upperBound - after + 1);
    await _reserveVisual(scheduler, batch, 'visual.tiles.grapheme-forward');
    final stop = math.min(upperBound + 1, after + batch);
    while (after < stop && boundaries[after] == 0) {
      after++;
    }
  }
  if (after <= upperBound && boundaries[after] != 0) return after;

  var before = offset;
  while (before > lowerBound && boundaries[before] == 0) {
    final batch = _visualBatch(scheduler, before - lowerBound);
    await _reserveVisual(scheduler, batch, 'visual.tiles.grapheme-backward');
    final stop = math.max(lowerBound, before - batch);
    while (before > stop && boundaries[before] == 0) {
      before--;
    }
  }
  if (before > lowerBound && boundaries[before] != 0) return before;
  return upperBound;
}

Future<Int32List> _paintVisualRunOrderCooperatively(
  List<_PaintRun> runs,
  LongLineCooperativeScheduler scheduler,
) async {
  var retainedCount = 0;
  var maximumLevel = 0;
  var minimumOddLevel = 0x7fffffff;
  for (var start = 0; start < runs.length;) {
    final batch = _visualBatch(scheduler, runs.length - start);
    await _reserveVisual(scheduler, batch, 'visual.order.count');
    final end = start + batch;
    for (var index = start; index < end; index++) {
      final run = runs[index];
      if (!run.retained) continue;
      retainedCount++;
      maximumLevel = math.max(maximumLevel, run.level);
      if (run.level.isOdd) minimumOddLevel = math.min(minimumOddLevel, run.level);
    }
    start = end;
  }
  final retained = await _allocateVisualInt32(scheduler, retainedCount, 'visual.allocate.paint-order');
  var retainedIndex = 0;
  for (var start = 0; start < runs.length;) {
    final batch = _visualBatch(scheduler, runs.length - start);
    await _reserveVisual(scheduler, batch, 'visual.order.write');
    final end = start + batch;
    for (var index = start; index < end; index++) {
      if (runs[index].retained) retained[retainedIndex++] = index;
    }
    start = end;
  }
  if (minimumOddLevel == 0x7fffffff) return retained;
  for (var level = maximumLevel; level >= minimumOddLevel; level--) {
    var cursor = 0;
    var scanCredit = 0;
    var scanEpoch = scheduler.reservationEpoch;
    while (cursor < retained.length) {
      if (scanCredit == 0) {
        scanCredit = _visualBatch(scheduler, retained.length - cursor);
        await _reserveVisual(scheduler, scanCredit, 'visual.order.l2-scan');
        scanEpoch = scheduler.reservationEpoch;
      }
      scanCredit--;
      if (runs[retained[cursor]].level < level) {
        cursor++;
        continue;
      }
      var end = cursor + 1;
      while (end < retained.length && runs[retained[end]].level >= level) {
        final batch = _visualBatch(scheduler, retained.length - end);
        await _reserveVisual(scheduler, batch, 'visual.order.l2-scan');
        final stop = math.min(retained.length, end + batch);
        while (end < stop && runs[retained[end]].level >= level) {
          end++;
        }
      }
      var left = cursor;
      var right = end - 1;
      while (left < right) {
        final batch = _visualBatch(scheduler, right - left);
        await _reserveVisual(scheduler, batch, 'visual.order.l2-reverse');
        final stop = left + batch;
        while (left < right && left < stop) {
          final value = retained[left];
          retained[left++] = retained[right];
          retained[right--] = value;
        }
      }
      cursor = end;
      if (scheduler.discardReservationIfStale(scanEpoch, scanCredit)) scanCredit = 0;
    }
  }
  return retained;
}

final class _CooperativeVisualTileBuild {
  const _CooperativeVisualTileBuild({
    required this.tiles,
    required this.paintRetained,
    required this.logicalTileIndices,
  });

  final List<LongLineVisualTile> tiles;
  final Uint8List paintRetained;
  final Int32List logicalTileIndices;
}

final class _CooperativePaintRunBuild {
  const _CooperativePaintRunBuild({required this.runs, required this.graphemeBoundaries});

  final List<_PaintRun> runs;
  final Uint8List graphemeBoundaries;
}
