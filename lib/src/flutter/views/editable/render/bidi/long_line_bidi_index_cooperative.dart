part of 'long_line_bidi_index.dart';

const int _cooperativeStride = 8 * 1024;

int _cooperativeBatch(LongLineCooperativeScheduler scheduler, int remaining) =>
    math.min(remaining, math.min(_cooperativeStride, scheduler.maxWorkUnitsBeforeYield));

Future<void> _reserveCooperative(LongLineCooperativeScheduler scheduler, int workUnits, String phase) async {
  final pending = scheduler.reserve(workUnits, phase: phase);
  if (pending != null) await pending;
}

Future<Uint8List> _allocateBidiUint8(LongLineCooperativeScheduler scheduler, int length, String phase) =>
    scheduler.runUninterruptible<Uint8List>(
      codeUnits: length,
      bytes: length,
      phase: phase,
      materialization: false,
      operation: () => Uint8List(length),
    );

Future<Uint32List> _allocateBidiUint32(LongLineCooperativeScheduler scheduler, int length, String phase) =>
    scheduler.runUninterruptible<Uint32List>(
      codeUnits: length,
      bytes: length * 4,
      phase: phase,
      materialization: false,
      operation: () => Uint32List(length),
    );

Future<Int32List> _allocateBidiInt32(LongLineCooperativeScheduler scheduler, int length, String phase) =>
    scheduler.runUninterruptible<Int32List>(
      codeUnits: length,
      bytes: length * 4,
      phase: phase,
      materialization: false,
      operation: () => Int32List(length),
    );

final class _LongLineBidiCooperativeResolver {
  _LongLineBidiCooperativeResolver(this.text, this.baseDirection, this.scheduler);

  final String text;
  final LongLineBidiBaseDirection baseDirection;
  final LongLineCooperativeScheduler scheduler;

  Future<LongLineBidiIndex> resolve() async {
    assert(UnicodeBidiClass.pdi.index == _BC.pdi, '生成的 Bidi_Class 顺序必须与算法常量一致');
    final decoded = await _decodeTextCooperatively(text, scheduler);
    final count = decoded.codePoints.length;
    final originalTypes = await _allocateBidiUint8(scheduler, count, 'bidi.allocate.original-types');
    for (var start = 0; start < count;) {
      final batch = _cooperativeBatch(scheduler, count - start);
      await _reserveCooperative(scheduler, batch, 'bidi.types');
      final end = start + batch;
      for (var index = start; index < end; index++) {
        originalTypes[index] = unicodeBidiClassOf(decoded.codePoints[index]).index;
      }
      start = end;
    }
    final paragraphLevel = baseDirection == LongLineBidiBaseDirection.rtl ? 1 : 0;
    final core = await _createBidiCoreCooperatively(originalTypes, decoded.codePoints, scheduler);

    var paragraphStart = 0;
    var paragraphIndex = 0;
    while (paragraphIndex < count) {
      final batch = _cooperativeBatch(scheduler, count - paragraphIndex);
      await _reserveCooperative(scheduler, batch, 'bidi.paragraphs');
      final batchEpoch = scheduler.reservationEpoch;
      final end = paragraphIndex + batch;
      while (paragraphIndex < end) {
        if (originalTypes[paragraphIndex] == _BC.b) {
          if (paragraphStart < paragraphIndex) {
            await _resolveParagraphCooperatively(core, paragraphStart, paragraphIndex, paragraphLevel, scheduler);
          }
          if (scheduler.discardReservationIfStale(batchEpoch, 0)) {
            await _reserveCooperative(scheduler, 1, 'bidi.paragraph-resume');
          }
          core.levels[paragraphIndex] = paragraphLevel;
          core.visualAtomOrder[core.visualAtomLength++] = paragraphIndex;
          paragraphStart = paragraphIndex + 1;
        }
        paragraphIndex++;
        if (scheduler.discardReservationIfStale(batchEpoch, end - paragraphIndex)) break;
      }
    }
    if (paragraphStart < count) {
      await _resolveParagraphCooperatively(core, paragraphStart, count, paragraphLevel, scheduler);
    }
    return _buildResultCooperatively(decoded, core, paragraphLevel, scheduler);
  }
}

Future<_DecodedText> _decodeTextCooperatively(String text, LongLineCooperativeScheduler scheduler) async {
  var count = 0;
  var offset = 0;
  while (offset < text.length) {
    final batch = _cooperativeBatch(scheduler, text.length - offset);
    await _reserveCooperative(scheduler, batch, 'bidi.decode.count');
    var processed = 0;
    while (offset < text.length && processed < batch) {
      final first = text.codeUnitAt(offset);
      if (_isHighSurrogate(first) && offset + 1 < text.length && _isLowSurrogate(text.codeUnitAt(offset + 1))) {
        offset += 2;
      } else {
        offset++;
      }
      count++;
      processed++;
    }
  }

  final codePoints = await _allocateBidiUint32(scheduler, count, 'bidi.allocate.decoded-code-points');
  final starts = await _allocateBidiUint32(scheduler, count, 'bidi.allocate.decoded-starts');
  var atom = 0;
  offset = 0;
  while (offset < text.length) {
    final batch = _cooperativeBatch(scheduler, count - atom);
    await _reserveCooperative(scheduler, batch, 'bidi.decode.write');
    final endAtom = atom + batch;
    while (atom < endAtom) {
      final first = text.codeUnitAt(offset);
      starts[atom] = offset;
      if (_isHighSurrogate(first) && offset + 1 < text.length) {
        final second = text.codeUnitAt(offset + 1);
        if (_isLowSurrogate(second)) {
          codePoints[atom] = 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00;
          offset += 2;
          atom++;
          continue;
        }
      }
      codePoints[atom] = _isSurrogate(first) ? 0xfffd : first;
      offset++;
      atom++;
    }
  }
  return _DecodedText(codePoints, starts, text.length);
}

Future<_BidiCore> _createBidiCoreCooperatively(
  Uint8List originalTypes,
  Uint32List? codePoints,
  LongLineCooperativeScheduler scheduler,
) async {
  final length = originalTypes.length;
  final core = _BidiCore.cooperative(
    originalTypes,
    codePoints,
    types: await _allocateBidiUint8(scheduler, length, 'bidi.allocate.core-types'),
    levels: await _allocateBidiUint8(scheduler, length, 'bidi.allocate.core-levels'),
    embeddingLevels: await _allocateBidiUint8(scheduler, length, 'bidi.allocate.core-embedding-levels'),
    removed: await _allocateBidiUint8(scheduler, length, 'bidi.allocate.core-removed'),
    matchPdi: await _allocateBidiInt32(scheduler, length, 'bidi.allocate.core-match-pdi'),
    matchInitiator: await _allocateBidiInt32(scheduler, length, 'bidi.allocate.core-match-initiator'),
    fsiResolved: await _allocateBidiUint8(scheduler, length, 'bidi.allocate.core-fsi-resolved'),
    fsiRtl: await _allocateBidiUint8(scheduler, length, 'bidi.allocate.core-fsi-rtl'),
    sequenceNext: await _allocateBidiInt32(scheduler, length, 'bidi.allocate.core-sequence-next'),
    visualAtomOrder: await _allocateBidiInt32(scheduler, length, 'bidi.allocate.core-visual-order'),
    structuralStack: await _allocateBidiInt32(scheduler, length, 'bidi.allocate.core-structural-stack'),
  );
  for (var start = 0; start < originalTypes.length;) {
    final batch = _cooperativeBatch(scheduler, originalTypes.length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.core.initialize');
    final end = start + batch;
    core.types.setRange(start, end, originalTypes, start);
    core.matchPdi.fillRange(start, end, -1);
    core.matchInitiator.fillRange(start, end, -1);
    core.sequenceNext.fillRange(start, end, -1);
    start = end;
  }
  return core;
}

Future<LongLineBidiIndex> _buildResultCooperatively(
  _DecodedText decoded,
  _BidiCore core,
  int paragraphLevel,
  LongLineCooperativeScheduler scheduler,
) async {
  final utf16Length = decoded.length;
  final atomCount = decoded.codePoints.length;
  final utf16Levels = await _allocateBidiUint8(scheduler, utf16Length, 'bidi.allocate.result-levels');
  final utf16Removed = await _allocateBidiUint8(scheduler, utf16Length, 'bidi.allocate.result-removed');
  final runAtAtom = await _allocateBidiInt32(scheduler, atomCount, 'bidi.allocate.result-run-at-atom');

  var runCount = 0;
  var previousLevel = -1;
  var previousRemoved = -1;
  for (var startAtom = 0; startAtom < atomCount;) {
    final batch = _cooperativeBatch(scheduler, atomCount - startAtom);
    await _reserveCooperative(scheduler, batch, 'bidi.result.runs');
    final endAtom = startAtom + batch;
    for (var atom = startAtom; atom < endAtom; atom++) {
      final start = decoded.utf16Starts[atom];
      final width = decoded.codePoints[atom] > 0xffff ? 2 : 1;
      final level = core.levels[atom];
      final removed = core.removed[atom];
      utf16Levels.fillRange(start, start + width, level);
      utf16Removed.fillRange(start, start + width, removed);
      if (atom == 0 || level != previousLevel || removed != previousRemoved) runCount++;
      runAtAtom[atom] = runCount - 1;
      previousLevel = level;
      previousRemoved = removed;
    }
    startAtom = endAtom;
  }

  final runStarts = await _allocateBidiInt32(scheduler, runCount, 'bidi.allocate.result-run-starts');
  final runEnds = await _allocateBidiInt32(scheduler, runCount, 'bidi.allocate.result-run-ends');
  final runLevels = await _allocateBidiUint8(scheduler, runCount, 'bidi.allocate.result-run-levels');
  final runRemoved = await _allocateBidiUint8(scheduler, runCount, 'bidi.allocate.result-run-removed');
  var run = -1;
  previousLevel = -1;
  previousRemoved = -1;
  for (var startAtom = 0; startAtom < atomCount;) {
    final batch = _cooperativeBatch(scheduler, atomCount - startAtom);
    await _reserveCooperative(scheduler, batch, 'bidi.result.run-bounds');
    final endAtom = startAtom + batch;
    for (var atom = startAtom; atom < endAtom; atom++) {
      final level = core.levels[atom];
      final removed = core.removed[atom];
      final start = decoded.utf16Starts[atom];
      final end = start + (decoded.codePoints[atom] > 0xffff ? 2 : 1);
      if (atom == 0 || level != previousLevel || removed != previousRemoved) {
        run++;
        runStarts[run] = start;
        runLevels[run] = level;
        runRemoved[run] = removed;
      }
      runEnds[run] = end;
      previousLevel = level;
      previousRemoved = removed;
    }
    startAtom = endAtom;
  }

  final visualToLogical = await _allocateBidiInt32(scheduler, utf16Length, 'bidi.allocate.result-visual-to-logical');
  final logicalToVisual = await _allocateBidiInt32(scheduler, utf16Length, 'bidi.allocate.result-logical-to-visual');
  for (var start = 0; start < utf16Length;) {
    final batch = _cooperativeBatch(scheduler, utf16Length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.result.initialize-maps');
    final end = start + batch;
    visualToLogical.fillRange(start, end, -1);
    logicalToVisual.fillRange(start, end, -1);
    start = end;
  }

  var visualLength = 0;
  for (var startVisualAtom = 0; startVisualAtom < core.visualAtomLength;) {
    final batch = _cooperativeBatch(scheduler, core.visualAtomLength - startVisualAtom);
    await _reserveCooperative(scheduler, batch, 'bidi.result.offset-maps');
    final endVisualAtom = startVisualAtom + batch;
    for (var visualAtom = startVisualAtom; visualAtom < endVisualAtom; visualAtom++) {
      final atom = core.visualAtomOrder[visualAtom];
      final logicalStart = decoded.utf16Starts[atom];
      final width = decoded.codePoints[atom] > 0xffff ? 2 : 1;
      for (var unit = 0; unit < width; unit++) {
        visualToLogical[visualLength + unit] = logicalStart + unit;
        logicalToVisual[logicalStart + unit] = visualLength + unit;
      }
      visualLength += width;
    }
    startVisualAtom = endVisualAtom;
  }

  var visualRunCount = 0;
  var previousRun = -1;
  for (var startVisualAtom = 0; startVisualAtom < core.visualAtomLength;) {
    final batch = _cooperativeBatch(scheduler, core.visualAtomLength - startVisualAtom);
    await _reserveCooperative(scheduler, batch, 'bidi.result.visual-runs-count');
    final endVisualAtom = startVisualAtom + batch;
    for (var visualAtom = startVisualAtom; visualAtom < endVisualAtom; visualAtom++) {
      final currentRun = runAtAtom[core.visualAtomOrder[visualAtom]];
      if (currentRun != previousRun) {
        visualRunCount++;
        previousRun = currentRun;
      }
    }
    startVisualAtom = endVisualAtom;
  }
  final visualRunOrder = await _allocateBidiInt32(scheduler, visualRunCount, 'bidi.allocate.result-visual-runs');
  var visualRun = 0;
  previousRun = -1;
  for (var startVisualAtom = 0; startVisualAtom < core.visualAtomLength;) {
    final batch = _cooperativeBatch(scheduler, core.visualAtomLength - startVisualAtom);
    await _reserveCooperative(scheduler, batch, 'bidi.result.visual-runs-write');
    final endVisualAtom = startVisualAtom + batch;
    for (var visualAtom = startVisualAtom; visualAtom < endVisualAtom; visualAtom++) {
      final currentRun = runAtAtom[core.visualAtomOrder[visualAtom]];
      if (currentRun == previousRun) continue;
      visualRunOrder[visualRun++] = currentRun;
      previousRun = currentRun;
    }
    startVisualAtom = endVisualAtom;
  }

  return LongLineBidiIndex._(
    paragraphLevel: paragraphLevel,
    atomCount: atomCount,
    visualCodeUnitLength: visualLength,
    levels: utf16Levels.asUnmodifiableView(),
    x9Removed: utf16Removed.asUnmodifiableView(),
    logicalRuns: LongLineBidiRuns._(
      runStarts.asUnmodifiableView(),
      runEnds.asUnmodifiableView(),
      runLevels.asUnmodifiableView(),
      runRemoved.asUnmodifiableView(),
    ),
    visualRunOrder: visualRunOrder.asUnmodifiableView(),
    visualToLogical: visualToLogical.asUnmodifiableView(),
    logicalToVisual: logicalToVisual.asUnmodifiableView(),
  );
}

Future<void> _resolveParagraphCooperatively(
  _BidiCore core,
  int start,
  int end,
  int paragraphLevel,
  LongLineCooperativeScheduler scheduler,
) async {
  if (start >= end) return;
  await _computeStructuralMatchingCooperatively(core, start, end, scheduler);
  await _resolveExplicitCooperatively(core, start, end, paragraphLevel, scheduler);
  for (var rangeStart = start; rangeStart < end;) {
    final batch = _cooperativeBatch(scheduler, end - rangeStart);
    await _reserveCooperative(scheduler, batch, 'bidi.embedding-levels');
    final rangeEnd = rangeStart + batch;
    core.embeddingLevels.setRange(rangeStart, rangeEnd, core.levels, rangeStart);
    rangeStart = rangeEnd;
  }
  await _buildSequenceLinksCooperatively(core, start, end, scheduler);
  await _resolveAllSequencesCooperatively(core, start, end, paragraphLevel, scheduler);
  await _applyL1Cooperatively(core, start, end, paragraphLevel, scheduler);
  await _appendL2OrderCooperatively(core, start, end, scheduler);
}

Future<void> _computeStructuralMatchingCooperatively(
  _BidiCore core,
  int start,
  int end,
  LongLineCooperativeScheduler scheduler,
) async {
  var depth = 0;
  for (var rangeStart = start; rangeStart < end;) {
    final batch = _cooperativeBatch(scheduler, end - rangeStart);
    await _reserveCooperative(scheduler, batch, 'bidi.structural');
    final rangeEnd = rangeStart + batch;
    for (var index = rangeStart; index < rangeEnd; index++) {
      final type = core.originalTypes[index];
      if (_isIsolateInitiator(type)) {
        core._structuralStack[depth++] = index;
      } else if (type == _BC.pdi) {
        if (depth == 0) continue;
        final initiator = core._structuralStack[--depth];
        core.matchPdi[initiator] = index;
        core.matchInitiator[index] = initiator;
      } else if (_isStrongType(type) && depth > 0) {
        final initiator = core._structuralStack[depth - 1];
        if (core.originalTypes[initiator] == _BC.fsi && core.fsiResolved[initiator] == 0) {
          core.fsiResolved[initiator] = 1;
          core.fsiRtl[initiator] = type == _BC.r || type == _BC.al ? 1 : 0;
        }
      }
    }
    rangeStart = rangeEnd;
  }
}

Future<void> _resolveExplicitCooperatively(
  _BidiCore core,
  int start,
  int end,
  int paragraphLevel,
  LongLineCooperativeScheduler scheduler,
) async {
  final statusLevel = Uint8List(_maxExplicitDepth + 2);
  final statusOverride = Int8List(_maxExplicitDepth + 2);
  final statusIsolate = Uint8List(_maxExplicitDepth + 2);
  var statusDepth = 1;
  statusLevel[0] = paragraphLevel;
  statusOverride[0] = _neutralOverride;
  var overflowIsolate = 0;
  var overflowEmbedding = 0;
  var validIsolate = 0;

  for (var rangeStart = start; rangeStart < end;) {
    final batch = _cooperativeBatch(scheduler, end - rangeStart);
    await _reserveCooperative(scheduler, batch, 'bidi.explicit');
    final rangeEnd = rangeStart + batch;
    for (var index = rangeStart; index < rangeEnd; index++) {
      final original = core.originalTypes[index];
      final top = statusDepth - 1;
      switch (original) {
        case _BC.rle || _BC.lre || _BC.rlo || _BC.lro:
          core.levels[index] = statusLevel[top];
          core.removed[index] = 1;
          final rtl = original == _BC.rle || original == _BC.rlo;
          final nextLevel = rtl ? _leastGreaterOdd(statusLevel[top]) : _leastGreaterEven(statusLevel[top]);
          final override = original == _BC.rlo
              ? _BC.r
              : original == _BC.lro
              ? _BC.l
              : _neutralOverride;
          if (nextLevel <= _maxExplicitDepth && overflowIsolate == 0 && overflowEmbedding == 0) {
            statusLevel[statusDepth] = nextLevel;
            statusOverride[statusDepth] = override;
            statusIsolate[statusDepth] = 0;
            statusDepth++;
          } else if (overflowIsolate == 0) {
            overflowEmbedding++;
          }
        case _BC.rli || _BC.lri || _BC.fsi:
          core.levels[index] = statusLevel[top];
          if (statusOverride[top] != _neutralOverride) core.types[index] = statusOverride[top];
          final rtl = original == _BC.rli || (original == _BC.fsi && core.fsiRtl[index] != 0);
          final nextLevel = rtl ? _leastGreaterOdd(statusLevel[top]) : _leastGreaterEven(statusLevel[top]);
          if (nextLevel <= _maxExplicitDepth && overflowIsolate == 0 && overflowEmbedding == 0) {
            validIsolate++;
            statusLevel[statusDepth] = nextLevel;
            statusOverride[statusDepth] = _neutralOverride;
            statusIsolate[statusDepth] = 1;
            statusDepth++;
          } else {
            overflowIsolate++;
          }
        case _BC.pdi:
          if (overflowIsolate > 0) {
            overflowIsolate--;
          } else if (validIsolate > 0) {
            overflowEmbedding = 0;
            while (statusIsolate[statusDepth - 1] == 0) {
              statusDepth--;
            }
            statusDepth--;
            validIsolate--;
          }
          core.levels[index] = statusLevel[statusDepth - 1];
          if (statusOverride[statusDepth - 1] != _neutralOverride) {
            core.types[index] = statusOverride[statusDepth - 1];
          }
        case _BC.pdf:
          core.removed[index] = 1;
          if (overflowIsolate > 0) {
            // X7：overflow isolate 内的 PDF 完全忽略。
          } else if (overflowEmbedding > 0) {
            overflowEmbedding--;
          } else if (statusIsolate[statusDepth - 1] == 0 && statusDepth >= 2) {
            statusDepth--;
          }
          core.levels[index] = statusLevel[statusDepth - 1];
        case _BC.b:
          core.levels[index] = paragraphLevel;
        case _BC.bn:
          core.levels[index] = statusLevel[top];
          core.removed[index] = 1;
        default:
          core.levels[index] = statusLevel[top];
          if (statusOverride[top] != _neutralOverride) core.types[index] = statusOverride[top];
      }
    }
    rangeStart = rangeEnd;
  }
}

Future<void> _buildSequenceLinksCooperatively(
  _BidiCore core,
  int start,
  int end,
  LongLineCooperativeScheduler scheduler,
) async {
  var previous = -1;
  for (var rangeStart = start; rangeStart < end;) {
    final batch = _cooperativeBatch(scheduler, end - rangeStart);
    await _reserveCooperative(scheduler, batch, 'bidi.sequence-links');
    final rangeEnd = rangeStart + batch;
    for (var index = rangeStart; index < rangeEnd; index++) {
      if (core.removed[index] != 0) continue;
      if (previous >= 0) {
        if (core.levels[index] == core.levels[previous]) {
          core.sequenceNext[previous] = index;
        } else if (_isIsolateInitiator(core.originalTypes[previous]) && core.matchPdi[previous] >= 0) {
          core.sequenceNext[previous] = core.matchPdi[previous];
        }
      }
      previous = index;
    }
    rangeStart = rangeEnd;
  }
}

Future<void> _resolveAllSequencesCooperatively(
  _BidiCore core,
  int start,
  int end,
  int paragraphLevel,
  LongLineCooperativeScheduler scheduler,
) async {
  if (core._sequence._values.length < end - start) {
    core._sequence._values = await _allocateBidiInt32(scheduler, end - start, 'bidi.allocate.sequence-buffer');
  }
  var previous = -1;
  for (var index = start; index < end;) {
    final batch = _cooperativeBatch(scheduler, end - index);
    await _reserveCooperative(scheduler, batch, 'bidi.sequence-scan');
    final batchEpoch = scheduler.reservationEpoch;
    final batchEnd = index + batch;
    while (index < batchEnd) {
      if (core.removed[index] == 0) {
        final startsRun = previous < 0 || core.embeddingLevels[index] != core.embeddingLevels[previous];
        if (startsRun && !(core.originalTypes[index] == _BC.pdi && core.matchInitiator[index] >= 0)) {
          core._sequence.reset();
          var current = index;
          while (current >= 0) {
            final reserve = _cooperativeBatch(scheduler, end - start);
            await _reserveCooperative(scheduler, reserve, 'bidi.sequence-build');
            var consumed = 0;
            while (current >= 0 && consumed < reserve) {
              core._sequence._values[core._sequence.length++] = current;
              current = core.sequenceNext[current];
              consumed++;
            }
          }
          await _resolveSequenceCooperatively(core, start, end, paragraphLevel, scheduler);
        }
        previous = index;
      }
      index++;
      if (scheduler.discardReservationIfStale(batchEpoch, batchEnd - index)) break;
    }
  }
}

Future<void> _resolveSequenceCooperatively(
  _BidiCore core,
  int paragraphStart,
  int paragraphEnd,
  int paragraphLevel,
  LongLineCooperativeScheduler scheduler,
) async {
  final length = core._sequence.length;
  if (length == 0) return;
  final first = core._sequence[0];
  final last = core._sequence[length - 1];
  final sequenceLevel = core.embeddingLevels[first];
  final embeddingDirection = sequenceLevel.isOdd ? _BC.r : _BC.l;
  final oppositeDirection = embeddingDirection == _BC.l ? _BC.r : _BC.l;

  var precedingLevel = paragraphLevel;
  var preceding = first - 1;
  while (preceding >= paragraphStart) {
    final batch = _cooperativeBatch(scheduler, preceding - paragraphStart + 1);
    await _reserveCooperative(scheduler, batch, 'bidi.sequence-context');
    final stop = preceding - batch;
    while (preceding > stop) {
      if (core.removed[preceding] == 0) {
        precedingLevel = core.embeddingLevels[preceding];
        preceding = paragraphStart - 1;
        break;
      }
      preceding--;
    }
  }
  final sos = math.max(sequenceLevel, precedingLevel).isOdd ? _BC.r : _BC.l;

  int eos;
  if (_isIsolateInitiator(core.originalTypes[last]) && core.matchPdi[last] < 0) {
    eos = math.max(sequenceLevel, paragraphLevel).isOdd ? _BC.r : _BC.l;
  } else {
    var followingLevel = paragraphLevel;
    var following = last + 1;
    while (following < paragraphEnd) {
      final batch = _cooperativeBatch(scheduler, paragraphEnd - following);
      await _reserveCooperative(scheduler, batch, 'bidi.sequence-context');
      final stop = following + batch;
      while (following < stop) {
        if (core.removed[following] == 0) {
          followingLevel = core.embeddingLevels[following];
          following = paragraphEnd;
          break;
        }
        following++;
      }
    }
    eos = math.max(sequenceLevel, followingLevel).isOdd ? _BC.r : _BC.l;
  }

  // W1
  var previousType = sos;
  for (var start = 0; start < length;) {
    final batch = _cooperativeBatch(scheduler, length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.w1');
    final end = start + batch;
    for (var position = start; position < end; position++) {
      final index = core._sequence[position];
      final type = core.types[index];
      if (type == _BC.nsm) {
        final resolved = _isIsolateInitiator(previousType) || previousType == _BC.pdi ? _BC.on : previousType;
        core.types[index] = resolved;
        previousType = resolved;
      } else {
        previousType = type;
      }
    }
    start = end;
  }

  // W2
  var strong = sos;
  for (var start = 0; start < length;) {
    final batch = _cooperativeBatch(scheduler, length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.w2');
    final end = start + batch;
    for (var position = start; position < end; position++) {
      final index = core._sequence[position];
      final type = core.types[index];
      if (type == _BC.en && strong == _BC.al) core.types[index] = _BC.an;
      if (type == _BC.l || type == _BC.r || type == _BC.al) strong = type;
    }
    start = end;
  }

  // W3
  for (var start = 0; start < length;) {
    final batch = _cooperativeBatch(scheduler, length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.w3');
    final end = start + batch;
    for (var position = start; position < end; position++) {
      final index = core._sequence[position];
      if (core.types[index] == _BC.al) core.types[index] = _BC.r;
    }
    start = end;
  }

  // W4
  if (length >= 3) {
    var previousSnapshot = core.types[core._sequence[0]];
    var position = 1;
    while (position < length - 1) {
      final batch = _cooperativeBatch(scheduler, length - 1 - position);
      await _reserveCooperative(scheduler, batch, 'bidi.w4');
      final end = position + batch;
      while (position < end) {
        final index = core._sequence[position];
        final currentSnapshot = core.types[index];
        final nextSnapshot = core.types[core._sequence[position + 1]];
        if (currentSnapshot == _BC.es && previousSnapshot == _BC.en && nextSnapshot == _BC.en) {
          core.types[index] = _BC.en;
        } else if (currentSnapshot == _BC.cs && previousSnapshot == _BC.en && nextSnapshot == _BC.en) {
          core.types[index] = _BC.en;
        } else if (currentSnapshot == _BC.cs && previousSnapshot == _BC.an && nextSnapshot == _BC.an) {
          core.types[index] = _BC.an;
        }
        previousSnapshot = currentSnapshot;
        position++;
      }
    }
  }

  // W5
  var position = 0;
  var scanCredit = 0;
  var scanEpoch = scheduler.reservationEpoch;
  while (position < length) {
    if (scanCredit == 0) {
      scanCredit = _cooperativeBatch(scheduler, length - position);
      await _reserveCooperative(scheduler, scanCredit, 'bidi.w5.scan');
      scanEpoch = scheduler.reservationEpoch;
    }
    scanCredit--;
    if (core.types[core._sequence[position]] != _BC.et) {
      position++;
      continue;
    }
    final runStart = position;
    var runEnd = position + 1;
    while (runEnd < length && core.types[core._sequence[runEnd]] == _BC.et) {
      final batch = _cooperativeBatch(scheduler, length - runEnd);
      await _reserveCooperative(scheduler, batch, 'bidi.w5.scan');
      final stop = math.min(length, runEnd + batch);
      while (runEnd < stop && core.types[core._sequence[runEnd]] == _BC.et) {
        runEnd++;
      }
    }
    final before = runStart > 0 ? core.types[core._sequence[runStart - 1]] : sos;
    final after = runEnd < length ? core.types[core._sequence[runEnd]] : eos;
    if (before == _BC.en || after == _BC.en) {
      var write = runStart;
      while (write < runEnd) {
        final batch = _cooperativeBatch(scheduler, runEnd - write);
        await _reserveCooperative(scheduler, batch, 'bidi.w5.write');
        final stop = write + batch;
        while (write < stop) {
          core.types[core._sequence[write++]] = _BC.en;
        }
      }
    }
    position = runEnd;
    if (scheduler.discardReservationIfStale(scanEpoch, scanCredit)) scanCredit = 0;
  }

  // W6
  for (var start = 0; start < length;) {
    final batch = _cooperativeBatch(scheduler, length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.w6');
    final end = start + batch;
    for (var current = start; current < end; current++) {
      final index = core._sequence[current];
      final type = core.types[index];
      if (type == _BC.es || type == _BC.et || type == _BC.cs) core.types[index] = _BC.on;
    }
    start = end;
  }

  // W7
  strong = sos;
  for (var start = 0; start < length;) {
    final batch = _cooperativeBatch(scheduler, length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.w7');
    final end = start + batch;
    for (var current = start; current < end; current++) {
      final index = core._sequence[current];
      final type = core.types[index];
      if (type == _BC.en && strong == _BC.l) core.types[index] = _BC.l;
      final resolved = core.types[index];
      if (resolved == _BC.l || resolved == _BC.r) strong = resolved;
    }
    start = end;
  }

  if (core.codePoints != null) {
    await _resolveBracketsCooperatively(core, embeddingDirection, oppositeDirection, sos, scheduler);
  }

  // N1
  position = 0;
  scanCredit = 0;
  scanEpoch = scheduler.reservationEpoch;
  while (position < length) {
    if (scanCredit == 0) {
      scanCredit = _cooperativeBatch(scheduler, length - position);
      await _reserveCooperative(scheduler, scanCredit, 'bidi.n1.scan');
      scanEpoch = scheduler.reservationEpoch;
    }
    scanCredit--;
    if (!_isNeutralOrIsolate(core.types[core._sequence[position]])) {
      position++;
      continue;
    }
    final runStart = position;
    var runEnd = position + 1;
    while (runEnd < length && _isNeutralOrIsolate(core.types[core._sequence[runEnd]])) {
      final batch = _cooperativeBatch(scheduler, length - runEnd);
      await _reserveCooperative(scheduler, batch, 'bidi.n1.scan');
      final stop = math.min(length, runEnd + batch);
      while (runEnd < stop && _isNeutralOrIsolate(core.types[core._sequence[runEnd]])) {
        runEnd++;
      }
    }
    final before = runStart > 0 ? _directionOf(core.types[core._sequence[runStart - 1]]) : sos;
    final after = runEnd < length ? _directionOf(core.types[core._sequence[runEnd]]) : eos;
    if (before == after && (before == _BC.l || before == _BC.r)) {
      var write = runStart;
      while (write < runEnd) {
        final batch = _cooperativeBatch(scheduler, runEnd - write);
        await _reserveCooperative(scheduler, batch, 'bidi.n1.write');
        final stop = write + batch;
        while (write < stop) {
          core.types[core._sequence[write++]] = before;
        }
      }
    }
    position = runEnd;
    if (scheduler.discardReservationIfStale(scanEpoch, scanCredit)) scanCredit = 0;
  }

  // N2
  for (var start = 0; start < length;) {
    final batch = _cooperativeBatch(scheduler, length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.n2');
    final end = start + batch;
    for (var current = start; current < end; current++) {
      final index = core._sequence[current];
      if (_isNeutralOrIsolate(core.types[index])) core.types[index] = embeddingDirection;
    }
    start = end;
  }

  // I1 / I2
  for (var start = 0; start < length;) {
    final batch = _cooperativeBatch(scheduler, length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.implicit');
    final end = start + batch;
    for (var current = start; current < end; current++) {
      final index = core._sequence[current];
      final level = core.embeddingLevels[index];
      final type = core.types[index];
      if (level.isEven) {
        if (type == _BC.r) {
          core.levels[index] = level + 1;
        } else if (type == _BC.an || type == _BC.en) {
          core.levels[index] = level + 2;
        }
      } else if (type == _BC.l || type == _BC.en || type == _BC.an) {
        core.levels[index] = level + 1;
      }
    }
    start = end;
  }
}

Future<void> _resolveBracketsCooperatively(
  _BidiCore core,
  int embeddingDirection,
  int oppositeDirection,
  int sos,
  LongLineCooperativeScheduler scheduler,
) async {
  core._pairOpen.reset();
  core._pairClose.reset();
  if (core._pairOpen._values.length < core._sequence.length) {
    core._pairOpen._values = await _allocateBidiInt32(scheduler, core._sequence.length, 'bidi.allocate.bracket-opens');
    core._pairClose._values = await _allocateBidiInt32(
      scheduler,
      core._sequence.length,
      'bidi.allocate.bracket-closes',
    );
  }
  final openCanonical = Int32List(63);
  final openPosition = Int32List(63);
  var openDepth = 0;
  var matchCredit = 0;
  var matchEpoch = scheduler.reservationEpoch;

  var position = 0;
  var scanCredit = 0;
  var scanEpoch = scheduler.reservationEpoch;
  while (position < core._sequence.length) {
    if (scanCredit == 0) {
      scanCredit = _cooperativeBatch(scheduler, core._sequence.length - position);
      await _reserveCooperative(scheduler, scanCredit, 'bidi.brackets.scan');
      scanEpoch = scheduler.reservationEpoch;
    }
    scanCredit--;
    final index = core._sequence[position];
    if (core.types[index] == _BC.on) {
      final bracket = unicodeBidiBracketOf(core.codePoints![index]);
      if (bracket != null) {
        if (bracket.type == UnicodeBidiBracketType.open) {
          if (openDepth == 63) return;
          openCanonical[openDepth] = bracket.canonicalOpen;
          openPosition[openDepth] = position;
          openDepth++;
        } else {
          if (scheduler.discardReservationIfStale(matchEpoch, matchCredit * 63)) matchCredit = 0;
          if (matchCredit == 0) {
            matchCredit = math.max(1, scheduler.maxWorkUnitsBeforeYield ~/ 63);
            await _reserveCooperative(scheduler, matchCredit * 63, 'bidi.brackets.match');
            matchEpoch = scheduler.reservationEpoch;
          }
          matchCredit--;
          for (var stack = openDepth - 1; stack >= 0; stack--) {
            if (openCanonical[stack] != bracket.canonicalOpen) continue;
            core._pairOpen._values[core._pairOpen.length++] = openPosition[stack];
            core._pairClose._values[core._pairClose.length++] = position;
            openDepth = stack;
            break;
          }
        }
      }
    }
    position++;
    if (scheduler.discardReservationIfStale(scanEpoch, scanCredit)) scanCredit = 0;
  }
  if (core._pairOpen.length == 0) return;
  await _sortBracketPairsCooperatively(core._pairOpen, core._pairClose, scheduler);
  await _buildDirectionTreeCooperatively(core._directionTree, core._sequence, core.types, scheduler);

  var contextPosition = 0;
  var contextDirection = sos;
  var pairCredit = 0;
  var pairEpoch = scheduler.reservationEpoch;
  for (var pair = 0; pair < core._pairOpen.length; pair++) {
    if (scheduler.discardReservationIfStale(pairEpoch, pairCredit * 64)) pairCredit = 0;
    if (pairCredit == 0) {
      pairCredit = math.min(core._pairOpen.length - pair, math.max(1, scheduler.maxWorkUnitsBeforeYield ~/ 64));
      await _reserveCooperative(scheduler, pairCredit * 64, 'bidi.brackets.resolve');
      pairEpoch = scheduler.reservationEpoch;
    }
    pairCredit--;
    final open = core._pairOpen[pair];
    final close = core._pairClose[pair];
    while (contextPosition < open) {
      final batch = _cooperativeBatch(scheduler, open - contextPosition);
      await _reserveCooperative(scheduler, batch, 'bidi.brackets.context');
      final stop = contextPosition + batch;
      while (contextPosition < stop) {
        final direction = _directionOf(core.types[core._sequence[contextPosition]]);
        if (direction != _noDirection) contextDirection = direction;
        contextPosition++;
      }
    }
    if (scheduler.discardReservationIfStale(pairEpoch, pairCredit * 64)) {
      pairCredit = 0;
      await _reserveCooperative(scheduler, 64, 'bidi.brackets.resolve-resume');
      pairEpoch = scheduler.reservationEpoch;
    }

    final enclosed = core._directionTree.maskInRange(open + 1, close);
    final embeddingBit = embeddingDirection == _BC.l ? _DirectionTree.ltrBit : _DirectionTree.rtlBit;
    final oppositeBit = oppositeDirection == _BC.l ? _DirectionTree.ltrBit : _DirectionTree.rtlBit;
    var direction = _noDirection;
    if ((enclosed & embeddingBit) != 0) {
      direction = embeddingDirection;
    } else if ((enclosed & oppositeBit) != 0) {
      direction = contextDirection == oppositeDirection ? oppositeDirection : embeddingDirection;
    }
    if (direction == _noDirection) {
      if (scheduler.discardReservationIfStale(pairEpoch, pairCredit * 64)) pairCredit = 0;
      continue;
    }

    core._setBracketDirection(open, direction);
    core._setBracketDirection(close, direction);
    for (final bracketPosition in <int>[open, close]) {
      var nsm = bracketPosition + 1;
      while (nsm < core._sequence.length && core.originalTypes[core._sequence[nsm]] == _BC.nsm) {
        final batch = math.min(core._sequence.length - nsm, math.max(1, scheduler.maxWorkUnitsBeforeYield ~/ 32));
        await _reserveCooperative(scheduler, batch * 32, 'bidi.brackets.nsm');
        final stop = math.min(core._sequence.length, nsm + batch);
        while (nsm < stop && core.originalTypes[core._sequence[nsm]] == _BC.nsm) {
          final index = core._sequence[nsm];
          core.types[index] = direction;
          core._directionTree.setDirection(nsm, direction);
          nsm++;
        }
      }
    }
    if (scheduler.discardReservationIfStale(pairEpoch, pairCredit * 64)) pairCredit = 0;
  }
}

Future<void> _sortBracketPairsCooperatively(
  _IntBuffer opens,
  _IntBuffer closes,
  LongLineCooperativeScheduler scheduler,
) async {
  final length = opens.length;
  if (length < 2) return;

  void siftDown(int root, int size) {
    while (true) {
      final left = root * 2 + 1;
      if (left >= size) return;
      var larger = left;
      final right = left + 1;
      if (right < size && opens[right] > opens[left]) larger = right;
      if (opens[root] >= opens[larger]) return;
      opens.swap(root, larger);
      closes.swap(root, larger);
      root = larger;
    }
  }

  var root = length ~/ 2 - 1;
  while (root >= 0) {
    final batch = math.min(root + 1, math.max(1, scheduler.maxWorkUnitsBeforeYield ~/ 32));
    await _reserveCooperative(scheduler, batch * 32, 'bidi.brackets.sort');
    final stop = root - batch;
    while (root > stop) {
      siftDown(root, length);
      root--;
    }
  }
  var end = length - 1;
  while (end > 0) {
    final batch = math.min(end, math.max(1, scheduler.maxWorkUnitsBeforeYield ~/ 32));
    await _reserveCooperative(scheduler, batch * 32, 'bidi.brackets.sort');
    final stop = end - batch;
    while (end > stop) {
      opens.swap(0, end);
      closes.swap(0, end);
      siftDown(0, end);
      end--;
    }
  }
}

Future<void> _buildDirectionTreeCooperatively(
  _DirectionTree tree,
  _IntBuffer sequence,
  Uint8List types,
  LongLineCooperativeScheduler scheduler,
) async {
  var requiredBase = 1;
  while (requiredBase < sequence.length) {
    requiredBase <<= 1;
  }
  tree._base = requiredBase;
  final requiredLength = tree._base * 2;
  if (tree._tree.length < requiredLength) {
    tree._tree = await _allocateBidiUint8(scheduler, requiredLength, 'bidi.allocate.bracket-tree');
  }
  for (var start = 0; start < requiredLength;) {
    final batch = _cooperativeBatch(scheduler, requiredLength - start);
    await _reserveCooperative(scheduler, batch, 'bidi.brackets.tree-clear');
    final end = start + batch;
    tree._tree.fillRange(start, end, 0);
    start = end;
  }
  for (var start = 0; start < sequence.length;) {
    final batch = _cooperativeBatch(scheduler, sequence.length - start);
    await _reserveCooperative(scheduler, batch, 'bidi.brackets.tree-leaves');
    final end = start + batch;
    for (var position = start; position < end; position++) {
      final direction = _directionOf(types[sequence[position]]);
      tree._tree[tree._base + position] = direction == _BC.l
          ? _DirectionTree.ltrBit
          : direction == _BC.r
          ? _DirectionTree.rtlBit
          : 0;
    }
    start = end;
  }
  var node = tree._base - 1;
  while (node > 0) {
    final batch = _cooperativeBatch(scheduler, node);
    await _reserveCooperative(scheduler, batch, 'bidi.brackets.tree-nodes');
    final stop = node - batch;
    while (node > stop) {
      tree._tree[node] = tree._tree[node * 2] | tree._tree[node * 2 + 1];
      node--;
    }
  }
}

Future<void> _applyL1Cooperatively(
  _BidiCore core,
  int start,
  int end,
  int paragraphLevel,
  LongLineCooperativeScheduler scheduler,
) async {
  var index = end - 1;
  while (index >= start && core._isL1Resettable(index)) {
    final batch = _cooperativeBatch(scheduler, index - start + 1);
    await _reserveCooperative(scheduler, batch, 'bidi.l1.trailing');
    final stop = index - batch;
    while (index > stop && index >= start && core._isL1Resettable(index)) {
      core.levels[index--] = paragraphLevel;
    }
  }
  var separator = start;
  var separatorCredit = 0;
  var separatorEpoch = scheduler.reservationEpoch;
  while (separator < end) {
    if (separatorCredit == 0) {
      separatorCredit = _cooperativeBatch(scheduler, end - separator);
      await _reserveCooperative(scheduler, separatorCredit, 'bidi.l1.separators');
      separatorEpoch = scheduler.reservationEpoch;
    }
    separatorCredit--;
    final type = core.originalTypes[separator];
    if (type == _BC.b || type == _BC.s) {
      core.levels[separator] = paragraphLevel;
      var before = separator - 1;
      while (before >= start && core._isL1Resettable(before)) {
        final resetBatch = _cooperativeBatch(scheduler, before - start + 1);
        await _reserveCooperative(scheduler, resetBatch, 'bidi.l1.before-separator');
        final resetStop = before - resetBatch;
        while (before > resetStop && before >= start && core._isL1Resettable(before)) {
          core.levels[before--] = paragraphLevel;
        }
      }
    }
    separator++;
    if (scheduler.discardReservationIfStale(separatorEpoch, separatorCredit)) separatorCredit = 0;
  }
}

Future<void> _appendL2OrderCooperatively(
  _BidiCore core,
  int start,
  int end,
  LongLineCooperativeScheduler scheduler,
) async {
  final visualStart = core.visualAtomLength;
  var maxLevel = 0;
  var minOdd = 0x7fffffff;
  for (var rangeStart = start; rangeStart < end;) {
    final batch = _cooperativeBatch(scheduler, end - rangeStart);
    await _reserveCooperative(scheduler, batch, 'bidi.l2.collect');
    final rangeEnd = rangeStart + batch;
    for (var index = rangeStart; index < rangeEnd; index++) {
      if (core.removed[index] != 0) continue;
      core.visualAtomOrder[core.visualAtomLength++] = index;
      final level = core.levels[index];
      if (level > maxLevel) maxLevel = level;
      if (level.isOdd && level < minOdd) minOdd = level;
    }
    rangeStart = rangeEnd;
  }
  if (minOdd == 0x7fffffff) return;

  for (var level = maxLevel; level >= minOdd; level--) {
    var cursor = visualStart;
    var scanCredit = 0;
    var scanEpoch = scheduler.reservationEpoch;
    while (cursor < core.visualAtomLength) {
      if (scanCredit == 0) {
        scanCredit = _cooperativeBatch(scheduler, core.visualAtomLength - cursor);
        await _reserveCooperative(scheduler, scanCredit, 'bidi.l2.scan');
        scanEpoch = scheduler.reservationEpoch;
      }
      scanCredit--;
      if (core.levels[core.visualAtomOrder[cursor]] < level) {
        cursor++;
        continue;
      }
      var endCursor = cursor + 1;
      while (endCursor < core.visualAtomLength && core.levels[core.visualAtomOrder[endCursor]] >= level) {
        final batch = _cooperativeBatch(scheduler, core.visualAtomLength - endCursor);
        await _reserveCooperative(scheduler, batch, 'bidi.l2.scan');
        final stop = math.min(core.visualAtomLength, endCursor + batch);
        while (endCursor < stop && core.levels[core.visualAtomOrder[endCursor]] >= level) {
          endCursor++;
        }
      }
      var left = cursor;
      var right = endCursor - 1;
      while (left < right) {
        final swaps = _cooperativeBatch(scheduler, right - left);
        await _reserveCooperative(scheduler, swaps, 'bidi.l2.reverse');
        final stop = left + swaps;
        while (left < right && left < stop) {
          final value = core.visualAtomOrder[left];
          core.visualAtomOrder[left++] = core.visualAtomOrder[right];
          core.visualAtomOrder[right--] = value;
        }
      }
      cursor = endCursor;
      if (scheduler.discardReservationIfStale(scanEpoch, scanCredit)) scanCredit = 0;
    }
  }
}
