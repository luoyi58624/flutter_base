import 'dart:math' as math;

import 'package:flutter/painting.dart' show TextRange;
import 'package:meta/meta.dart' show internal;

import '../model/grapheme_boundary.dart';
import '../model/text_document.dart';

/// 在 [TextDocument] 上按统一分隔符口径执行有界词界导航。
///
/// 普通行、窗口长行、编辑命令与平台 selector 必须复用本类，避免渲染层的
/// Unicode 词法和命令层的 `wordSeparators` 产生两套结果。扫描按固定 UTF-16
/// 块读取；超长词只线性跨块，不会调用 `lineAt` 或物化整条逻辑行。
@internal
final class EditableWordNavigator {
  static const String defaultWordSeparators = r'''`~!@#$%^&*()-=+[{]}\|;:'",.<>/?''';

  /// 创建绑定文档与词分隔字符的导航器。
  EditableWordNavigator(this.document, {required String wordSeparators})
    : _separatorRunes = Set<int>.unmodifiable(wordSeparators.runes);

  /// 只读文本模型；导航器不接管其生命周期。
  final TextDocument document;

  final Set<int> _separatorRunes;

  /// 返回 [offset] 处的完整词段，范围不跨逻辑行。
  ///
  /// 空白、配置分隔符和其余正文分别形成连续分段；offset 位于字素内部时会
  /// 先吸附到该字素起点，最终两端也不会落入代理对或扩展字素内部。
  TextRange boundaryAt(int offset) {
    final line = document.lineIndexOf(offset.clamp(0, document.length));
    final lineStart = document.lineStart(line);
    final lineEnd = document.lineEnd(line);
    final clamped = offset.clamp(lineStart, lineEnd);
    if (clamped >= lineEnd) return TextRange.collapsed(lineEnd);

    final safeOffset = _graphemeStart(clamped, lineStart, lineEnd);
    final first = _ForwardRuneScanner(document, safeOffset, lineEnd).next();
    if (first == null) return TextRange.collapsed(safeOffset);
    final kind = _kind(first.rune);
    var start = first.start;
    var end = first.end;

    final backward = _BackwardRuneScanner(document, start, lineStart);
    while (true) {
      final previous = backward.next();
      if (previous == null || _kind(previous.rune) != kind) break;
      start = previous.start;
    }

    final forward = _ForwardRuneScanner(document, end, lineEnd);
    while (true) {
      final next = forward.next();
      if (next == null || _kind(next.rune) != kind) break;
      end = next.end;
    }

    return TextRange(start: _graphemeStart(start, lineStart, lineEnd), end: _graphemeEnd(end, lineStart, lineEnd));
  }

  /// 返回向左移动一个词段后的边界；行首先跨过真实换行符。
  int previousBoundary(int offset) {
    final clamped = offset.clamp(0, document.length);
    if (clamped <= 0) return 0;
    final line = document.lineIndexOf(clamped);
    final lineStart = document.lineStart(line);
    if (clamped == lineStart) return clamped - 1;
    final cursor = _graphemeStart(clamped, lineStart, document.lineEnd(line));
    return _previousNonWhitespaceSegmentStart(cursor, lineStart) ?? lineStart;
  }

  /// 返回向右移动一个词段后的边界；行尾先跨过真实换行符。
  int nextBoundary(int offset) {
    final clamped = offset.clamp(0, document.length);
    if (clamped >= document.length) return document.length;
    final line = document.lineIndexOf(clamped);
    final lineStart = document.lineStart(line);
    final lineEnd = document.lineEnd(line);
    if (clamped >= lineEnd) return math.min(clamped + 1, document.length);
    final cursor = _graphemeStart(clamped, lineStart, lineEnd);
    return _nextNonWhitespaceSegmentEnd(cursor, lineStart, lineEnd) ?? lineEnd;
  }

  /// 返回当前逻辑行内 [offset] 左侧最近非空白词段的起点；不存在时返回 null。
  int? previousWordStartInLine(int offset) {
    final clamped = offset.clamp(0, document.length);
    final line = document.lineIndexOf(clamped);
    final lineStart = document.lineStart(line);
    if (clamped <= lineStart) return null;
    final cursor = _graphemeStart(clamped, lineStart, document.lineEnd(line));
    return _previousNonWhitespaceSegmentStart(cursor, lineStart);
  }

  /// 返回当前逻辑行内从 [offset] 起首个非空白词段的起点；不存在时返回 null。
  int? nextWordStartInLine(int offset) {
    final clamped = offset.clamp(0, document.length);
    final line = document.lineIndexOf(clamped);
    final lineStart = document.lineStart(line);
    final lineEnd = document.lineEnd(line);
    if (clamped >= lineEnd) return null;
    final cursor = _graphemeStart(clamped, lineStart, lineEnd);
    final scanner = _ForwardRuneScanner(document, cursor, lineEnd);
    var current = scanner.next();
    while (current != null && _kind(current.rune) == _WordSegmentKind.whitespace) {
      current = scanner.next();
    }
    if (current == null) return null;
    return _graphemeStart(current.start, lineStart, lineEnd);
  }

  int? _previousNonWhitespaceSegmentStart(int cursor, int lineStart) {
    final scanner = _BackwardRuneScanner(document, cursor, lineStart);
    var current = scanner.next();
    while (current != null && _kind(current.rune) == _WordSegmentKind.whitespace) {
      current = scanner.next();
    }
    if (current == null) return null;
    final kind = _kind(current.rune);
    var result = current.start;
    while (true) {
      final previous = scanner.next();
      if (previous == null || _kind(previous.rune) != kind) break;
      result = previous.start;
    }
    return _graphemeStart(result, lineStart, document.lineEnd(document.lineIndexOf(cursor)));
  }

  int? _nextNonWhitespaceSegmentEnd(int cursor, int lineStart, int lineEnd) {
    final scanner = _ForwardRuneScanner(document, cursor, lineEnd);
    var current = scanner.next();
    while (current != null && _kind(current.rune) == _WordSegmentKind.whitespace) {
      current = scanner.next();
    }
    if (current == null) return null;
    final kind = _kind(current.rune);
    var result = current.end;
    while (true) {
      final next = scanner.next();
      if (next == null || _kind(next.rune) != kind) break;
      result = next.end;
    }
    return _graphemeEnd(result, lineStart, lineEnd);
  }

  int _graphemeStart(int offset, int lineStart, int lineEnd) =>
      textGraphemeBoundaryBeforeOrAt(document, offset, lowerBound: lineStart, upperBound: lineEnd);

  int _graphemeEnd(int offset, int lineStart, int lineEnd) =>
      textGraphemeBoundaryAfterOrAt(document, offset, lowerBound: lineStart, upperBound: lineEnd);

  _WordSegmentKind _kind(int rune) {
    if (rune <= 0x7f) {
      if (rune == 0x20 || (rune >= 0x09 && rune <= 0x0d)) return _WordSegmentKind.whitespace;
    } else if (_unicodeWhitespace.hasMatch(String.fromCharCode(rune))) {
      return _WordSegmentKind.whitespace;
    }
    return _separatorRunes.contains(rune) ? _WordSegmentKind.punctuation : _WordSegmentKind.word;
  }
}

// 单次 piece-tree 读取的硬上限；词长只决定块数，不决定单次读取跨度。
const int _wordScanChunkCodeUnits = 256;

typedef _TextChunk = ({int start, int end, String text});
typedef _RuneSpan = ({int rune, int start, int end});

enum _WordSegmentKind { whitespace, word, punctuation }

final RegExp _unicodeWhitespace = RegExp(r'^\s$', unicode: true);

final class _BackwardRuneScanner {
  _BackwardRuneScanner(this.document, this._cursor, this.lowerBound);

  final TextDocument document;
  final int lowerBound;
  int _cursor;
  int _chunkStart = 0;
  String _chunk = '';
  int _index = 0;

  _RuneSpan? next() {
    if (_cursor <= lowerBound) return null;
    if (_index == 0) _load();
    final localEnd = _index;
    var localStart = --_index;
    var rune = _chunk.codeUnitAt(localStart);
    if (_isLowSurrogate(rune) && _index > 0) {
      final high = _chunk.codeUnitAt(_index - 1);
      if (_isHighSurrogate(high)) {
        localStart = --_index;
        rune = _combineSurrogates(high, rune);
      }
    }
    final start = _chunkStart + localStart;
    _cursor = start;
    return (rune: rune, start: start, end: _chunkStart + localEnd);
  }

  void _load() {
    final chunk = _readBackwardChunk(document, _cursor, lowerBound);
    _chunkStart = chunk.start;
    _chunk = chunk.text;
    _index = _chunk.length;
  }
}

final class _ForwardRuneScanner {
  _ForwardRuneScanner(this.document, this._cursor, this.upperBound);

  final TextDocument document;
  final int upperBound;
  int _cursor;
  int _chunkStart = 0;
  String _chunk = '';
  int _index = 0;

  _RuneSpan? next() {
    if (_cursor >= upperBound) return null;
    if (_index >= _chunk.length) _load();
    final localStart = _index;
    var rune = _chunk.codeUnitAt(_index++);
    if (_isHighSurrogate(rune) && _index < _chunk.length) {
      final low = _chunk.codeUnitAt(_index);
      if (_isLowSurrogate(low)) {
        _index++;
        rune = _combineSurrogates(rune, low);
      }
    }
    final end = _chunkStart + _index;
    _cursor = end;
    return (rune: rune, start: _chunkStart + localStart, end: end);
  }

  void _load() {
    final chunk = _readForwardChunk(document, _cursor, upperBound);
    _chunkStart = chunk.start;
    _chunk = chunk.text;
    _index = 0;
  }
}

_TextChunk _readBackwardChunk(TextDocument document, int end, int lowerBound) {
  var start = math.max(lowerBound, end - _wordScanChunkCodeUnits);
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
  var end = math.min(upperBound, start + _wordScanChunkCodeUnits);
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

bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;

bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

int _combineSurrogates(int high, int low) => 0x10000 + ((high - 0xd800) << 10) + low - 0xdc00;
