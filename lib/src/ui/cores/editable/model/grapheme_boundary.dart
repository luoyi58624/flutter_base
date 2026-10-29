import 'package:characters/characters.dart';
import 'package:meta/meta.dart' show internal;

import 'text_document.dart';

/// 文档中包含指定 UTF-16 offset 的完整 Unicode 字素范围。
typedef TextGraphemeRange = ({int start, int end});

/// 返回包含 [offset] 的完整字素；offset 已在边界上时返回折叠范围。
///
/// 只按固定块读取 piece tree。普通文本最多读取边界两侧各一块；病态超长组合
/// 字素、RI 序列或 Indic conjunct 才继续扩张到可证明的 UAX #29 边界。
@internal
TextGraphemeRange textGraphemeRangeAt(
  TextDocument document,
  int offset, {
  required int lowerBound,
  required int upperBound,
}) {
  final lower = lowerBound.clamp(0, document.length);
  final upper = upperBound.clamp(lower, document.length);
  final effective = offset.clamp(lower, upper);
  if (effective == lower || effective == upper || lower == upper) {
    return (start: effective, end: effective);
  }

  var windowStart = effective;
  final before = <String>[];
  while (windowStart > lower) {
    final chunk = _readBackwardChunk(document, windowStart, lower);
    before.add(chunk.text);
    windowStart = chunk.start;
    if (windowStart == lower || !_boundaryMayDependOnPrefix(document, windowStart, lower, upper)) break;
  }

  var windowEnd = effective;
  final after = <String>[];
  while (windowEnd < upper) {
    final chunk = _readForwardChunk(document, windowEnd, upper);
    after.add(chunk.text);
    windowEnd = chunk.end;
    if (windowEnd == upper || !_boundaryMayDependOnPrefix(document, windowEnd, lower, upper)) break;
  }

  final text = '${before.reversed.join()}${after.join()}';
  final local = effective - windowStart;
  final range = CharacterRange.at(text, local);
  return (start: windowStart + range.stringBeforeLength, end: windowEnd - range.stringAfterLength);
}

/// 返回不晚于 [offset] 的最近字素边界。
@internal
int textGraphemeBoundaryBeforeOrAt(
  TextDocument document,
  int offset, {
  required int lowerBound,
  required int upperBound,
}) => textGraphemeRangeAt(document, offset, lowerBound: lowerBound, upperBound: upperBound).start;

/// 返回不早于 [offset] 的最近字素边界。
@internal
int textGraphemeBoundaryAfterOrAt(
  TextDocument document,
  int offset, {
  required int lowerBound,
  required int upperBound,
}) => textGraphemeRangeAt(document, offset, lowerBound: lowerBound, upperBound: upperBound).end;

/// 返回 [offset] 之前的严格字素边界。
@internal
int previousTextGraphemeBoundary(
  TextDocument document,
  int offset, {
  required int lowerBound,
  required int upperBound,
}) {
  final lower = lowerBound.clamp(0, document.length);
  final upper = upperBound.clamp(lower, document.length);
  final effective = offset.clamp(lower, upper);
  if (effective <= lower) return lower;
  return textGraphemeRangeAt(document, effective - 1, lowerBound: lower, upperBound: upper).start;
}

/// 返回 [offset] 之后的严格字素边界。
@internal
int nextTextGraphemeBoundary(TextDocument document, int offset, {required int lowerBound, required int upperBound}) {
  final lower = lowerBound.clamp(0, document.length);
  final upper = upperBound.clamp(lower, document.length);
  final effective = offset.clamp(lower, upper);
  if (effective >= upper) return upper;
  return textGraphemeRangeAt(document, effective + 1, lowerBound: lower, upperBound: upper).end;
}

const int _scanChunkCodeUnits = 256;

typedef _TextChunk = ({int start, int end, String text});
typedef _RuneSpan = ({int rune, int start, int end});

_TextChunk _readBackwardChunk(TextDocument document, int end, int lowerBound) {
  var start = (end - _scanChunkCodeUnits).clamp(lowerBound, end);
  var text = document.getText(start, end);
  if (start > lowerBound && text.isNotEmpty && _isLowSurrogate(text.codeUnitAt(0))) {
    final prefix = document.getText(start - 1, start);
    if (prefix.isNotEmpty && _isHighSurrogate(prefix.codeUnitAt(0))) {
      start--;
      text = '$prefix$text';
    }
  }
  return (start: start, end: end, text: text);
}

_TextChunk _readForwardChunk(TextDocument document, int start, int upperBound) {
  var end = (start + _scanChunkCodeUnits).clamp(start, upperBound);
  var text = document.getText(start, end);
  if (end < upperBound && text.isNotEmpty && _isHighSurrogate(text.codeUnitAt(text.length - 1))) {
    final suffix = document.getText(end, end + 1);
    if (suffix.isNotEmpty && _isLowSurrogate(suffix.codeUnitAt(0))) {
      end++;
      text = '$text$suffix';
    }
  }
  return (start: start, end: end, text: text);
}

bool _boundaryMayDependOnPrefix(TextDocument document, int boundary, int lowerBound, int upperBound) {
  if (boundary <= lowerBound || boundary >= upperBound) return false;
  if (_splitsSurrogatePair(document, boundary)) return true;
  final before = _runeBefore(document, boundary, lowerBound);
  final after = _runeAt(document, boundary, upperBound);
  if (before == null || after == null) return false;
  final previous = before.rune;
  final next = after.rune;
  if (previous == 0x0d && next == 0x0a) return true;
  if (_isGraphemeExtendLike(next) || _isGraphemePrepend(previous)) return true;
  if (previous == 0x200d || _unicodeMark.hasMatch(String.fromCharCode(previous))) return true;
  if (_isRegionalIndicator(previous) && _isRegionalIndicator(next)) return true;
  return _hangulPairDoesNotBreak(previous, next);
}

bool _splitsSurrogatePair(TextDocument document, int offset) {
  if (offset <= 0 || offset >= document.length) return false;
  final pair = document.getText(offset - 1, offset + 1);
  return pair.length == 2 && _isHighSurrogate(pair.codeUnitAt(0)) && _isLowSurrogate(pair.codeUnitAt(1));
}

_RuneSpan? _runeBefore(TextDocument document, int offset, int lowerBound) {
  if (offset <= lowerBound) return null;
  var start = offset - 1;
  var text = document.getText(start, offset);
  if (text.isEmpty) return null;
  final last = text.codeUnitAt(0);
  if (_isLowSurrogate(last) && start > lowerBound) {
    final prefix = document.getText(start - 1, start);
    if (prefix.isNotEmpty && _isHighSurrogate(prefix.codeUnitAt(0))) {
      start--;
      text = '$prefix$text';
    }
  }
  return (rune: text.runes.single, start: start, end: offset);
}

_RuneSpan? _runeAt(TextDocument document, int offset, int upperBound) {
  if (offset >= upperBound) return null;
  var end = offset + 1;
  var text = document.getText(offset, end);
  if (text.isEmpty) return null;
  final first = text.codeUnitAt(0);
  if (_isHighSurrogate(first) && end < upperBound) {
    final suffix = document.getText(end, end + 1);
    if (suffix.isNotEmpty && _isLowSurrogate(suffix.codeUnitAt(0))) {
      end++;
      text = '$text$suffix';
    }
  }
  return (rune: text.runes.single, start: offset, end: end);
}

bool _isGraphemeExtendLike(int rune) {
  if (rune == 0x200c || rune == 0x200d) return true;
  if (rune >= 0x1f3fb && rune <= 0x1f3ff) return true;
  if (rune >= 0xe0020 && rune <= 0xe007f) return true;
  return _unicodeMark.hasMatch(String.fromCharCode(rune));
}

bool _isGraphemePrepend(int rune) =>
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

bool _isRegionalIndicator(int rune) => rune >= 0x1f1e6 && rune <= 0x1f1ff;

bool _hangulPairDoesNotBreak(int previous, int next) {
  final previousKind = _hangulKind(previous);
  final nextKind = _hangulKind(next);
  return switch (previousKind) {
    _HangulKind.l =>
      nextKind == _HangulKind.l ||
          nextKind == _HangulKind.v ||
          nextKind == _HangulKind.lv ||
          nextKind == _HangulKind.lvt,
    _HangulKind.lv || _HangulKind.v => nextKind == _HangulKind.v || nextKind == _HangulKind.t,
    _HangulKind.lvt || _HangulKind.t => nextKind == _HangulKind.t,
    _HangulKind.other => false,
  };
}

_HangulKind _hangulKind(int rune) {
  if ((rune >= 0x1100 && rune <= 0x115f) || (rune >= 0xa960 && rune <= 0xa97c)) return _HangulKind.l;
  if ((rune >= 0x1160 && rune <= 0x11a7) || (rune >= 0xd7b0 && rune <= 0xd7c6)) return _HangulKind.v;
  if ((rune >= 0x11a8 && rune <= 0x11ff) || (rune >= 0xd7cb && rune <= 0xd7fb)) return _HangulKind.t;
  if (rune >= 0xac00 && rune <= 0xd7a3) {
    return (rune - 0xac00) % 28 == 0 ? _HangulKind.lv : _HangulKind.lvt;
  }
  return _HangulKind.other;
}

bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;
bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

enum _HangulKind { l, v, t, lv, lvt, other }

final RegExp _unicodeMark = RegExp(r'^\p{M}$', unicode: true);
