/*
 * This file is adapted from bidi-shaper's UAX #9 implementation:
 * https://github.com/cc1a2b/bidi-shaper/tree/main/src/bidi
 *
 * MIT License
 * Copyright (c) 2026 bidi-shaper contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * The Dart port follows Unicode 17.0.0 UAX #9 revision 51. In particular,
 * BD16 overflow returns an empty pair list for the whole isolating run sequence.
 */

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

import 'long_line_cooperative_scheduler.dart';
import 'unicode_bidi_data.g.dart';

part 'long_line_bidi_index_cooperative.dart';

/// 长行双向算法使用的显式段落基方向。
enum LongLineBidiBaseDirection { ltr, rtl }

/// 一段逻辑连续、最终 level 与 X9 移除状态均相同的 UTF-16 范围。
@immutable
final class LongLineBidiRun {
  /// 创建一个半开 UTF-16 逻辑范围。
  const LongLineBidiRun({required this.start, required this.end, required this.level, required this.removed});

  /// 起始 UTF-16 code-unit offset，包含。
  final int start;

  /// 结束 UTF-16 code-unit offset，不包含。
  final int end;

  /// UAX #9 L1 后 embedding level。
  final int level;

  /// 该范围是否由 X9 虚拟移除。
  final bool removed;

  /// 范围长度。
  int get length => end - start;

  /// level 是否对应 RTL 视觉方向。
  bool get isRtl => level.isOdd;

  @override
  String toString() => 'LongLineBidiRun([$start, $end), level: $level, removed: $removed)';
}

/// 用 typed arrays 保存的只读逻辑 run 列表；按需读取时才创建单个 run 对象。
final class LongLineBidiRuns extends ListBase<LongLineBidiRun> {
  LongLineBidiRuns._(this._starts, this._ends, this._levels, this._removed);

  final Int32List _starts;
  final Int32List _ends;
  final Uint8List _levels;
  final Uint8List _removed;

  @override
  int get length => _starts.length;

  @override
  set length(int value) => throw UnsupportedError('LongLineBidiRuns 是只读列表');

  @override
  LongLineBidiRun operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return LongLineBidiRun(
      start: _starts[index],
      end: _ends[index],
      level: _levels[index],
      removed: _removed[index] != 0,
    );
  }

  @override
  void operator []=(int index, LongLineBidiRun value) => throw UnsupportedError('LongLineBidiRuns 是只读列表');
}

/// Unicode 17 UAX #9 在一条长逻辑行上的完整解析结果。
///
/// [levels]、[x9Removed]、[visualToLogical] 与 [logicalToVisual] 都以原始
/// UTF-16 code unit 为单位且长度等于输入字符串长度。X9 被移除的位置在
/// [logicalToVisual] 中为 -1；[visualToLogical] 的有效前缀长度由
/// [visualCodeUnitLength] 给出，其余槽为 -1。
@immutable
final class LongLineBidiIndex {
  const LongLineBidiIndex._({
    required this.paragraphLevel,
    required this.atomCount,
    required this.visualCodeUnitLength,
    required this.levels,
    required this.x9Removed,
    required this.logicalRuns,
    required this.visualRunOrder,
    required this.visualToLogical,
    required this.logicalToVisual,
  });

  /// 解析 [text]；输入视为编辑器的一条逻辑行，显式 B 会独立结束段落。
  factory LongLineBidiIndex.resolve(String text, {required LongLineBidiBaseDirection baseDirection}) =>
      _LongLineBidiResolver(text, baseDirection).resolve();

  /// 在当前 isolate 内按确定性预算协作式解析 [text]。
  ///
  /// Web 应使用此入口，避免 Flutter `compute` 在浏览器主线程同步执行整个
  /// callback。原生平台仍应优先把同步 [LongLineBidiIndex.resolve] 放入独立
  /// isolate。传入 [scheduler] 时由调用方在完整 bidi + visual 管线结束后调用
  /// `finish()`；省略时本方法自行创建并收尾。
  static Future<LongLineBidiIndex> resolveCooperatively(
    String text, {
    required LongLineBidiBaseDirection baseDirection,
    LongLineCooperativeScheduler? scheduler,
  }) async {
    final ownsScheduler = scheduler == null;
    final actualScheduler = scheduler ?? LongLineCooperativeScheduler();
    try {
      return await _LongLineBidiCooperativeResolver(text, baseDirection, actualScheduler).resolve();
    } finally {
      if (ownsScheduler) actualScheduler.finish();
    }
  }

  /// 显式段落基 level：LTR 为 0，RTL 为 1。
  final int paragraphLevel;

  /// 解码后的 Unicode scalar 原子数；合法 surrogate pair 只计一个原子。
  final int atomCount;

  /// 排除 X9 字符后的有效视觉 UTF-16 code-unit 数。
  final int visualCodeUnitLength;

  /// 每个逻辑 UTF-16 code unit 的 L1 后 level。
  final Uint8List levels;

  /// 每个逻辑 UTF-16 code unit 的 X9 移除标记，值为 0 或 1。
  final Uint8List x9Removed;

  /// 按逻辑 offset 排列的最终 level runs，包含 removed runs。
  final LongLineBidiRuns logicalRuns;

  /// L2 后非 removed runs 的视觉顺序；值是 [logicalRuns] 的索引。
  final Int32List visualRunOrder;

  /// 视觉 UTF-16 code-unit 槽到逻辑 code-unit offset；无效尾槽为 -1。
  ///
  /// surrogate pair 即使处于 RTL run 也始终以 high→low 两个相邻槽出现。
  final Int32List visualToLogical;

  /// 逻辑 UTF-16 code-unit offset 到视觉槽；X9 removed 位置为 -1。
  final Int32List logicalToVisual;

  /// 输入 UTF-16 code-unit 长度。
  int get utf16Length => levels.length;
}

/// 直接按 Bidi_Class id 运行 UAX #9，供 Unicode 官方 BidiTest fixture 使用。
@visibleForTesting
LongLineBidiTypesResult resolveLongLineBidiTypesForTesting(Uint8List classIds, {required int paragraphLevel}) {
  if (paragraphLevel != 0 && paragraphLevel != 1) {
    throw ArgumentError.value(paragraphLevel, 'paragraphLevel', '必须为 0 或 1');
  }
  _validateClassIds(classIds);
  final original = Uint8List.fromList(classIds);
  final core = _BidiCore(original, null);
  core.resolveParagraph(0, original.length, paragraphLevel);
  return LongLineBidiTypesResult._(
    levels: core.levels.asUnmodifiableView(),
    removed: core.removed.asUnmodifiableView(),
    visualOrder: Int32List.fromList(core.visualAtomOrder.take(core.visualAtomLength).toList()).asUnmodifiableView(),
  );
}

/// 按 Bidi_Class id 执行 P2/P3，供 Unicode 官方 BidiTest fixture 使用。
@visibleForTesting
int baseLevelForTypesForTesting(Uint8List classIds) {
  _validateClassIds(classIds);
  return _baseLevelForTypes(classIds, 0, classIds.length);
}

/// types-only conformance 入口的解析结果。
@immutable
final class LongLineBidiTypesResult {
  const LongLineBidiTypesResult._({required this.levels, required this.removed, required this.visualOrder});

  /// 每个输入 class id 的 L1 后 level。
  final Uint8List levels;

  /// 每个输入 class id 的 X9 removed 标记。
  final Uint8List removed;

  /// L2 后非 removed 输入索引。
  final Int32List visualOrder;
}

void _validateClassIds(Uint8List values) {
  for (var i = 0; i < values.length; i++) {
    if (values[i] > _BC.pdi) throw RangeError.range(values[i], 0, _BC.pdi, 'classIds[$i]');
  }
}

final class _BC {
  static const int l = 0;
  static const int r = 1;
  static const int al = 2;
  static const int en = 3;
  static const int es = 4;
  static const int et = 5;
  static const int an = 6;
  static const int cs = 7;
  static const int nsm = 8;
  static const int bn = 9;
  static const int b = 10;
  static const int s = 11;
  static const int ws = 12;
  static const int on = 13;
  static const int lre = 14;
  static const int lro = 15;
  static const int rle = 16;
  static const int rlo = 17;
  static const int pdf = 18;
  static const int lri = 19;
  static const int rli = 20;
  static const int fsi = 21;
  static const int pdi = 22;
}

const int _maxExplicitDepth = 125;
const int _neutralOverride = -1;
const int _noDirection = -1;

bool _isIsolateInitiator(int type) => type == _BC.lri || type == _BC.rli || type == _BC.fsi;

bool _isStrongType(int type) => type == _BC.l || type == _BC.r || type == _BC.al;

int _directionOf(int type) {
  if (type == _BC.l) return _BC.l;
  if (type == _BC.r || type == _BC.en || type == _BC.an) return _BC.r;
  return _noDirection;
}

bool _isNeutralOrIsolate(int type) =>
    type == _BC.b ||
    type == _BC.s ||
    type == _BC.ws ||
    type == _BC.on ||
    type == _BC.fsi ||
    type == _BC.lri ||
    type == _BC.rli ||
    type == _BC.pdi;

int _leastGreaterOdd(int level) => level.isEven ? level + 1 : level + 2;

int _leastGreaterEven(int level) => level.isEven ? level + 2 : level + 1;

int _baseLevelForTypes(Uint8List types, int start, int end) {
  var isolateDepth = 0;
  for (var i = start; i < end; i++) {
    final type = types[i];
    if (_isIsolateInitiator(type)) {
      isolateDepth++;
    } else if (type == _BC.pdi) {
      if (isolateDepth > 0) isolateDepth--;
    } else if (isolateDepth == 0) {
      if (type == _BC.l) return 0;
      if (type == _BC.r || type == _BC.al) return 1;
    }
  }
  return 0;
}

final class _DecodedText {
  _DecodedText(this.codePoints, this.utf16Starts, this.length);

  final Uint32List codePoints;
  final Uint32List utf16Starts;
  final int length;

  static _DecodedText decode(String text) {
    var count = 0;
    for (var offset = 0; offset < text.length;) {
      final first = text.codeUnitAt(offset);
      if (_isHighSurrogate(first) && offset + 1 < text.length && _isLowSurrogate(text.codeUnitAt(offset + 1))) {
        offset += 2;
      } else {
        offset++;
      }
      count++;
    }

    final codePoints = Uint32List(count);
    final starts = Uint32List(count);
    var atom = 0;
    for (var offset = 0; offset < text.length;) {
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
      // Dart String 可携带孤立 surrogate；算法把它作为单宽 U+FFFD 原子处理，
      // 既不向生成数据传非法 scalar，也不改变原 UTF-16 offset。
      codePoints[atom] = _isSurrogate(first) ? 0xfffd : first;
      offset++;
      atom++;
    }
    return _DecodedText(codePoints, starts, text.length);
  }
}

bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;

bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

bool _isSurrogate(int value) => value >= 0xd800 && value <= 0xdfff;

final class _LongLineBidiResolver {
  _LongLineBidiResolver(this.text, this.baseDirection);

  final String text;
  final LongLineBidiBaseDirection baseDirection;

  LongLineBidiIndex resolve() {
    assert(UnicodeBidiClass.pdi.index == _BC.pdi, '生成的 Bidi_Class 顺序必须与算法常量一致');
    final decoded = _DecodedText.decode(text);
    final count = decoded.codePoints.length;
    final originalTypes = Uint8List(count);
    for (var i = 0; i < count; i++) {
      originalTypes[i] = unicodeBidiClassOf(decoded.codePoints[i]).index;
    }
    final paragraphLevel = baseDirection == LongLineBidiBaseDirection.rtl ? 1 : 0;
    final core = _BidiCore(originalTypes, decoded.codePoints);

    var paragraphStart = 0;
    for (var i = 0; i < count; i++) {
      if (originalTypes[i] != _BC.b) continue;
      if (paragraphStart < i) core.resolveParagraph(paragraphStart, i, paragraphLevel);
      core.levels[i] = paragraphLevel;
      core.visualAtomOrder[core.visualAtomLength++] = i;
      paragraphStart = i + 1;
    }
    if (paragraphStart < count) core.resolveParagraph(paragraphStart, count, paragraphLevel);

    return _buildResult(decoded, core, paragraphLevel);
  }
}

LongLineBidiIndex _buildResult(_DecodedText decoded, _BidiCore core, int paragraphLevel) {
  final utf16Length = decoded.length;
  final atomCount = decoded.codePoints.length;
  final utf16Levels = Uint8List(utf16Length);
  final utf16Removed = Uint8List(utf16Length);
  final runAtAtom = Int32List(atomCount);

  var runCount = 0;
  var previousLevel = -1;
  var previousRemoved = -1;
  for (var atom = 0; atom < atomCount; atom++) {
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

  final runStarts = Int32List(runCount);
  final runEnds = Int32List(runCount);
  final runLevels = Uint8List(runCount);
  final runRemoved = Uint8List(runCount);
  var run = -1;
  previousLevel = -1;
  previousRemoved = -1;
  for (var atom = 0; atom < atomCount; atom++) {
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

  final visualToLogical = Int32List(utf16Length)..fillRange(0, utf16Length, -1);
  final logicalToVisual = Int32List(utf16Length)..fillRange(0, utf16Length, -1);
  var visualLength = 0;
  for (var visualAtom = 0; visualAtom < core.visualAtomLength; visualAtom++) {
    final atom = core.visualAtomOrder[visualAtom];
    final logicalStart = decoded.utf16Starts[atom];
    final width = decoded.codePoints[atom] > 0xffff ? 2 : 1;
    for (var unit = 0; unit < width; unit++) {
      visualToLogical[visualLength + unit] = logicalStart + unit;
      logicalToVisual[logicalStart + unit] = visualLength + unit;
    }
    visualLength += width;
  }

  var visualRunCount = 0;
  var previousRun = -1;
  for (var visualAtom = 0; visualAtom < core.visualAtomLength; visualAtom++) {
    final currentRun = runAtAtom[core.visualAtomOrder[visualAtom]];
    if (currentRun != previousRun) {
      visualRunCount++;
      previousRun = currentRun;
    }
  }
  final visualRunOrder = Int32List(visualRunCount);
  var visualRun = 0;
  previousRun = -1;
  for (var visualAtom = 0; visualAtom < core.visualAtomLength; visualAtom++) {
    final currentRun = runAtAtom[core.visualAtomOrder[visualAtom]];
    if (currentRun == previousRun) continue;
    visualRunOrder[visualRun++] = currentRun;
    previousRun = currentRun;
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

final class _BidiCore {
  _BidiCore(this.originalTypes, this.codePoints)
    : types = Uint8List.fromList(originalTypes),
      levels = Uint8List(originalTypes.length),
      embeddingLevels = Uint8List(originalTypes.length),
      removed = Uint8List(originalTypes.length),
      matchPdi = Int32List(originalTypes.length)..fillRange(0, originalTypes.length, -1),
      matchInitiator = Int32List(originalTypes.length)..fillRange(0, originalTypes.length, -1),
      fsiResolved = Uint8List(originalTypes.length),
      fsiRtl = Uint8List(originalTypes.length),
      sequenceNext = Int32List(originalTypes.length)..fillRange(0, originalTypes.length, -1),
      visualAtomOrder = Int32List(originalTypes.length),
      _structuralStack = Int32List(originalTypes.length);

  _BidiCore.cooperative(
    this.originalTypes,
    this.codePoints, {
    required this.types,
    required this.levels,
    required this.embeddingLevels,
    required this.removed,
    required this.matchPdi,
    required this.matchInitiator,
    required this.fsiResolved,
    required this.fsiRtl,
    required this.sequenceNext,
    required this.visualAtomOrder,
    required Int32List structuralStack,
  }) : // 对外仅限 part 内私有构造，参数保持可读名称。
       // ignore: prefer_initializing_formals
       _structuralStack = structuralStack;

  final Uint8List originalTypes;
  final Uint32List? codePoints;
  final Uint8List types;
  final Uint8List levels;
  final Uint8List embeddingLevels;
  final Uint8List removed;
  final Int32List matchPdi;
  final Int32List matchInitiator;
  final Uint8List fsiResolved;
  final Uint8List fsiRtl;
  final Int32List sequenceNext;
  final Int32List visualAtomOrder;
  final Int32List _structuralStack;
  final _IntBuffer _sequence = _IntBuffer();
  final _IntBuffer _pairOpen = _IntBuffer();
  final _IntBuffer _pairClose = _IntBuffer();
  final _DirectionTree _directionTree = _DirectionTree();
  int visualAtomLength = 0;

  void resolveParagraph(int start, int end, int paragraphLevel) {
    if (start >= end) return;
    _computeStructuralMatching(start, end);
    _resolveExplicit(start, end, paragraphLevel);
    embeddingLevels.setRange(start, end, levels, start);
    _buildSequenceLinks(start, end);
    _resolveAllSequences(start, end, paragraphLevel);
    _applyL1(start, end, paragraphLevel);
    _appendL2Order(start, end);
  }

  void _computeStructuralMatching(int start, int end) {
    var depth = 0;
    for (var i = start; i < end; i++) {
      final type = originalTypes[i];
      if (_isIsolateInitiator(type)) {
        _structuralStack[depth++] = i;
      } else if (type == _BC.pdi) {
        if (depth == 0) continue;
        final initiator = _structuralStack[--depth];
        matchPdi[initiator] = i;
        matchInitiator[i] = initiator;
      } else if (_isStrongType(type) && depth > 0) {
        final initiator = _structuralStack[depth - 1];
        if (originalTypes[initiator] == _BC.fsi && fsiResolved[initiator] == 0) {
          fsiResolved[initiator] = 1;
          fsiRtl[initiator] = type == _BC.r || type == _BC.al ? 1 : 0;
        }
      }
    }
  }

  void _resolveExplicit(int start, int end, int paragraphLevel) {
    final statusLevel = Uint8List(_maxExplicitDepth + 2);
    final statusOverride = Int8List(_maxExplicitDepth + 2);
    final statusIsolate = Uint8List(_maxExplicitDepth + 2);
    var statusDepth = 1;
    statusLevel[0] = paragraphLevel;
    statusOverride[0] = _neutralOverride;
    var overflowIsolate = 0;
    var overflowEmbedding = 0;
    var validIsolate = 0;

    for (var i = start; i < end; i++) {
      final original = originalTypes[i];
      final top = statusDepth - 1;
      switch (original) {
        case _BC.rle || _BC.lre || _BC.rlo || _BC.lro:
          levels[i] = statusLevel[top];
          removed[i] = 1;
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
          levels[i] = statusLevel[top];
          if (statusOverride[top] != _neutralOverride) types[i] = statusOverride[top];
          final rtl = original == _BC.rli || (original == _BC.fsi && fsiRtl[i] != 0);
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
          levels[i] = statusLevel[statusDepth - 1];
          if (statusOverride[statusDepth - 1] != _neutralOverride) {
            types[i] = statusOverride[statusDepth - 1];
          }
        case _BC.pdf:
          removed[i] = 1;
          if (overflowIsolate > 0) {
            // X7：overflow isolate 内的 PDF 完全忽略。
          } else if (overflowEmbedding > 0) {
            overflowEmbedding--;
          } else if (statusIsolate[statusDepth - 1] == 0 && statusDepth >= 2) {
            statusDepth--;
          }
          levels[i] = statusLevel[statusDepth - 1];
        case _BC.b:
          levels[i] = paragraphLevel;
        case _BC.bn:
          levels[i] = statusLevel[top];
          removed[i] = 1;
        default:
          levels[i] = statusLevel[top];
          if (statusOverride[top] != _neutralOverride) types[i] = statusOverride[top];
      }
    }
  }

  void _buildSequenceLinks(int start, int end) {
    var previous = -1;
    for (var i = start; i < end; i++) {
      if (removed[i] != 0) continue;
      if (previous >= 0) {
        if (levels[i] == levels[previous]) {
          sequenceNext[previous] = i;
        } else if (_isIsolateInitiator(originalTypes[previous]) && matchPdi[previous] >= 0) {
          sequenceNext[previous] = matchPdi[previous];
        }
      }
      previous = i;
    }
  }

  void _resolveAllSequences(int start, int end, int paragraphLevel) {
    var previous = -1;
    for (var i = start; i < end; i++) {
      if (removed[i] != 0) continue;
      final startsRun = previous < 0 || embeddingLevels[i] != embeddingLevels[previous];
      if (startsRun && !(originalTypes[i] == _BC.pdi && matchInitiator[i] >= 0)) {
        _sequence.reset();
        var current = i;
        while (current >= 0) {
          _sequence.add(current);
          current = sequenceNext[current];
        }
        _resolveSequence(start, end, paragraphLevel);
      }
      previous = i;
    }
  }

  void _resolveSequence(int paragraphStart, int paragraphEnd, int paragraphLevel) {
    final length = _sequence.length;
    if (length == 0) return;
    final first = _sequence[0];
    final last = _sequence[length - 1];
    final sequenceLevel = embeddingLevels[first];
    final embeddingDirection = sequenceLevel.isOdd ? _BC.r : _BC.l;
    final oppositeDirection = embeddingDirection == _BC.l ? _BC.r : _BC.l;

    var precedingLevel = paragraphLevel;
    for (var i = first - 1; i >= paragraphStart; i--) {
      if (removed[i] == 0) {
        precedingLevel = embeddingLevels[i];
        break;
      }
    }
    final sos = math.max(sequenceLevel, precedingLevel).isOdd ? _BC.r : _BC.l;

    int eos;
    if (_isIsolateInitiator(originalTypes[last]) && matchPdi[last] < 0) {
      eos = math.max(sequenceLevel, paragraphLevel).isOdd ? _BC.r : _BC.l;
    } else {
      var followingLevel = paragraphLevel;
      for (var i = last + 1; i < paragraphEnd; i++) {
        if (removed[i] == 0) {
          followingLevel = embeddingLevels[i];
          break;
        }
      }
      eos = math.max(sequenceLevel, followingLevel).isOdd ? _BC.r : _BC.l;
    }

    // W1
    var previousType = sos;
    for (var k = 0; k < length; k++) {
      final index = _sequence[k];
      final type = types[index];
      if (type == _BC.nsm) {
        final resolved = _isIsolateInitiator(previousType) || previousType == _BC.pdi ? _BC.on : previousType;
        types[index] = resolved;
        previousType = resolved;
      } else {
        previousType = type;
      }
    }

    // W2
    var strong = sos;
    for (var k = 0; k < length; k++) {
      final index = _sequence[k];
      final type = types[index];
      if (type == _BC.en && strong == _BC.al) types[index] = _BC.an;
      if (type == _BC.l || type == _BC.r || type == _BC.al) strong = type;
    }

    // W3
    for (var k = 0; k < length; k++) {
      final index = _sequence[k];
      if (types[index] == _BC.al) types[index] = _BC.r;
    }

    // W4：prev/current/next 均读取本规则开始时的快照值。
    if (length >= 3) {
      var previousSnapshot = types[_sequence[0]];
      for (var k = 1; k < length - 1; k++) {
        final index = _sequence[k];
        final currentSnapshot = types[index];
        final nextSnapshot = types[_sequence[k + 1]];
        if (currentSnapshot == _BC.es && previousSnapshot == _BC.en && nextSnapshot == _BC.en) {
          types[index] = _BC.en;
        } else if (currentSnapshot == _BC.cs && previousSnapshot == _BC.en && nextSnapshot == _BC.en) {
          types[index] = _BC.en;
        } else if (currentSnapshot == _BC.cs && previousSnapshot == _BC.an && nextSnapshot == _BC.an) {
          types[index] = _BC.an;
        }
        previousSnapshot = currentSnapshot;
      }
    }

    // W5
    for (var k = 0; k < length;) {
      if (types[_sequence[k]] != _BC.et) {
        k++;
        continue;
      }
      var end = k + 1;
      while (end < length && types[_sequence[end]] == _BC.et) {
        end++;
      }
      final before = k > 0 ? types[_sequence[k - 1]] : sos;
      final after = end < length ? types[_sequence[end]] : eos;
      if (before == _BC.en || after == _BC.en) {
        for (var position = k; position < end; position++) {
          types[_sequence[position]] = _BC.en;
        }
      }
      k = end;
    }

    // W6
    for (var k = 0; k < length; k++) {
      final index = _sequence[k];
      final type = types[index];
      if (type == _BC.es || type == _BC.et || type == _BC.cs) types[index] = _BC.on;
    }

    // W7
    strong = sos;
    for (var k = 0; k < length; k++) {
      final index = _sequence[k];
      final type = types[index];
      if (type == _BC.en && strong == _BC.l) types[index] = _BC.l;
      final current = types[index];
      if (current == _BC.l || current == _BC.r) strong = current;
    }

    if (codePoints != null) {
      _resolveBrackets(embeddingDirection, oppositeDirection, sos);
    }

    // N1
    for (var k = 0; k < length;) {
      if (!_isNeutralOrIsolate(types[_sequence[k]])) {
        k++;
        continue;
      }
      var end = k + 1;
      while (end < length && _isNeutralOrIsolate(types[_sequence[end]])) {
        end++;
      }
      final before = k > 0 ? _directionOf(types[_sequence[k - 1]]) : sos;
      final after = end < length ? _directionOf(types[_sequence[end]]) : eos;
      if (before == after && (before == _BC.l || before == _BC.r)) {
        for (var position = k; position < end; position++) {
          types[_sequence[position]] = before;
        }
      }
      k = end;
    }

    // N2
    for (var k = 0; k < length; k++) {
      final index = _sequence[k];
      if (_isNeutralOrIsolate(types[index])) types[index] = embeddingDirection;
    }

    // I1 / I2
    for (var k = 0; k < length; k++) {
      final index = _sequence[k];
      final level = embeddingLevels[index];
      final type = types[index];
      if (level.isEven) {
        if (type == _BC.r) {
          levels[index] = level + 1;
        } else if (type == _BC.an || type == _BC.en) {
          levels[index] = level + 2;
        }
      } else if (type == _BC.l || type == _BC.en || type == _BC.an) {
        levels[index] = level + 1;
      }
    }
  }

  void _resolveBrackets(int embeddingDirection, int oppositeDirection, int sos) {
    _pairOpen.reset();
    _pairClose.reset();
    final openCanonical = Int32List(63);
    final openPosition = Int32List(63);
    var openDepth = 0;

    for (var k = 0; k < _sequence.length; k++) {
      final index = _sequence[k];
      if (types[index] != _BC.on) continue;
      final bracket = unicodeBidiBracketOf(codePoints![index]);
      if (bracket == null) continue;
      if (bracket.type == UnicodeBidiBracketType.open) {
        // Unicode 17 rev51 BD16：第 64 个 opening 使本序列整份 pair list
        // 失效；不能保留 overflow 前已经找到的 pair。
        if (openDepth == 63) return;
        openCanonical[openDepth] = bracket.canonicalOpen;
        openPosition[openDepth] = k;
        openDepth++;
        continue;
      }

      for (var stack = openDepth - 1; stack >= 0; stack--) {
        if (openCanonical[stack] != bracket.canonicalOpen) continue;
        _pairOpen.add(openPosition[stack]);
        _pairClose.add(k);
        openDepth = stack;
        break;
      }
    }
    if (_pairOpen.length == 0) return;
    _sortBracketPairs(_pairOpen, _pairClose);

    _directionTree.build(_sequence, types);
    var contextPosition = 0;
    var contextDirection = sos;
    for (var pair = 0; pair < _pairOpen.length; pair++) {
      final open = _pairOpen[pair];
      final close = _pairClose[pair];
      while (contextPosition < open) {
        final direction = _directionOf(types[_sequence[contextPosition]]);
        if (direction != _noDirection) contextDirection = direction;
        contextPosition++;
      }

      final enclosed = _directionTree.maskInRange(open + 1, close);
      final embeddingBit = embeddingDirection == _BC.l ? _DirectionTree.ltrBit : _DirectionTree.rtlBit;
      final oppositeBit = oppositeDirection == _BC.l ? _DirectionTree.ltrBit : _DirectionTree.rtlBit;
      var direction = _noDirection;
      if ((enclosed & embeddingBit) != 0) {
        direction = embeddingDirection;
      } else if ((enclosed & oppositeBit) != 0) {
        direction = contextDirection == oppositeDirection ? oppositeDirection : embeddingDirection;
      }
      if (direction == _noDirection) continue;

      _setBracketDirection(open, direction);
      _setBracketDirection(close, direction);
      for (final bracketPosition in <int>[open, close]) {
        for (var nsm = bracketPosition + 1; nsm < _sequence.length && originalTypes[_sequence[nsm]] == _BC.nsm; nsm++) {
          final index = _sequence[nsm];
          types[index] = direction;
          _directionTree.setDirection(nsm, direction);
        }
      }
    }
  }

  void _setBracketDirection(int sequencePosition, int direction) {
    final index = _sequence[sequencePosition];
    types[index] = direction;
    _directionTree.setDirection(sequencePosition, direction);
  }

  void _applyL1(int start, int end, int paragraphLevel) {
    var i = end - 1;
    while (i >= start && _isL1Resettable(i)) {
      levels[i--] = paragraphLevel;
    }
    for (var separator = start; separator < end; separator++) {
      final type = originalTypes[separator];
      if (type != _BC.b && type != _BC.s) continue;
      levels[separator] = paragraphLevel;
      var before = separator - 1;
      while (before >= start && _isL1Resettable(before)) {
        levels[before--] = paragraphLevel;
      }
    }
  }

  bool _isL1Resettable(int index) {
    if (removed[index] != 0) return true;
    final type = originalTypes[index];
    return type == _BC.ws || _isIsolateInitiator(type) || type == _BC.pdi;
  }

  void _appendL2Order(int start, int end) {
    final visualStart = visualAtomLength;
    var maxLevel = 0;
    var minOdd = 0x7fffffff;
    for (var i = start; i < end; i++) {
      if (removed[i] != 0) continue;
      visualAtomOrder[visualAtomLength++] = i;
      final level = levels[i];
      if (level > maxLevel) maxLevel = level;
      if (level.isOdd && level < minOdd) minOdd = level;
    }
    if (minOdd == 0x7fffffff) return;

    for (var level = maxLevel; level >= minOdd; level--) {
      var cursor = visualStart;
      while (cursor < visualAtomLength) {
        if (levels[visualAtomOrder[cursor]] < level) {
          cursor++;
          continue;
        }
        var endCursor = cursor + 1;
        while (endCursor < visualAtomLength && levels[visualAtomOrder[endCursor]] >= level) {
          endCursor++;
        }
        _reverseRange(visualAtomOrder, cursor, endCursor - 1);
        cursor = endCursor;
      }
    }
  }
}

void _reverseRange(Int32List values, int start, int end) {
  while (start < end) {
    final value = values[start];
    values[start++] = values[end];
    values[end--] = value;
  }
}

final class _IntBuffer {
  Int32List _values = Int32List(16);
  int length = 0;

  int operator [](int index) {
    assert(index >= 0 && index < length);
    return _values[index];
  }

  void operator []=(int index, int value) {
    assert(index >= 0 && index < length);
    _values[index] = value;
  }

  void reset() => length = 0;

  void add(int value) {
    if (length == _values.length) {
      final grown = Int32List(_values.length * 2)..setRange(0, length, _values);
      _values = grown;
    }
    _values[length++] = value;
  }

  void swap(int left, int right) {
    final value = _values[left];
    _values[left] = _values[right];
    _values[right] = value;
  }
}

void _sortBracketPairs(_IntBuffer opens, _IntBuffer closes) {
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

  for (var root = length ~/ 2 - 1; root >= 0; root--) {
    siftDown(root, length);
  }
  for (var end = length - 1; end > 0; end--) {
    opens.swap(0, end);
    closes.swap(0, end);
    siftDown(0, end);
  }
}

final class _DirectionTree {
  static const int ltrBit = 1;
  static const int rtlBit = 2;

  Uint8List _tree = Uint8List(2);
  int _base = 1;

  void build(_IntBuffer sequence, Uint8List types) {
    var requiredBase = 1;
    while (requiredBase < sequence.length) {
      requiredBase <<= 1;
    }
    _base = requiredBase;
    final requiredLength = _base * 2;
    if (_tree.length < requiredLength) _tree = Uint8List(requiredLength);
    _tree.fillRange(0, requiredLength, 0);
    for (var position = 0; position < sequence.length; position++) {
      final direction = _directionOf(types[sequence[position]]);
      _tree[_base + position] = direction == _BC.l
          ? ltrBit
          : direction == _BC.r
          ? rtlBit
          : 0;
    }
    for (var node = _base - 1; node > 0; node--) {
      _tree[node] = _tree[node * 2] | _tree[node * 2 + 1];
    }
  }

  int maskInRange(int start, int end) {
    if (start >= end) return 0;
    var left = start + _base;
    var right = end + _base;
    var mask = 0;
    while (left < right) {
      if (left.isOdd) mask |= _tree[left++];
      if (right.isOdd) mask |= _tree[--right];
      left >>= 1;
      right >>= 1;
    }
    return mask;
  }

  void setDirection(int position, int direction) {
    var node = _base + position;
    _tree[node] = direction == _BC.l ? ltrBit : rtlBit;
    node >>= 1;
    while (node > 0) {
      final next = _tree[node * 2] | _tree[node * 2 + 1];
      if (_tree[node] == next) break;
      _tree[node] = next;
      node >>= 1;
    }
  }
}
