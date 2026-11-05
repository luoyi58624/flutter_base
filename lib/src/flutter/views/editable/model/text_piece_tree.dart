part of 'text_document.dart';

const int _priorityMask = 0xffffffff;

// 隐式 treap 的中序顺序就是文档顺序，固定种子优先级让结构可复现且保持期望对数高度。
class _TextPieceTree {
  _TextPieceTree(String text) {
    if (text.isEmpty) return;
    final buffer = _ImmutableTextBuffer(text);
    _root = _newNode(_TextPiece(buffer, 0, text.length));
  }

  _TextPieceNode? _root;
  _AppendTextBuffer? _addBuffer;
  int _priorityState = 0x9e3779b9;
  int _serial = 0;

  int debugNodeVisitCount = 0;
  int debugNodeRelinkCount = 0;

  int get length => _root?.textLength ?? 0;
  int get lineBreakCount => _root?.lineBreakCount ?? 0;
  int get pieceCount => _root?.nodeCount ?? 0;
  int get height => _root?.height ?? 0;
  int get debugAddBufferPageCount => _addBuffer?.pageCount ?? 0;
  int get debugAddBufferCodeUnits => _addBuffer?.length ?? 0;
  int get debugAddBufferAllocatedCodeUnits => _addBuffer?.allocatedCodeUnits ?? 0;

  bool get isCompact {
    if (_addBuffer != null) return false;
    final root = _root;
    if (root == null) return true;
    if (root.left != null || root.right != null) return false;
    final buffer = root.piece.buffer;
    return buffer is _ImmutableTextBuffer && root.piece.start == 0 && root.piece.length == buffer.length;
  }

  _TextPieceTreeStorageUsage get debugStorageUsage {
    final originalBuffers = <_ImmutableTextBuffer>{};
    var liveOriginalCodeUnits = 0;
    var liveAddCodeUnits = 0;
    final stack = <_TextPieceNode>[];
    var node = _root;
    while (node != null || stack.isNotEmpty) {
      while (node != null) {
        stack.add(node);
        node = node.left;
      }
      final current = stack.removeLast();
      final piece = current.piece;
      final buffer = piece.buffer;
      if (buffer is _AppendTextBuffer) {
        liveAddCodeUnits += piece.length;
      } else if (buffer is _ImmutableTextBuffer) {
        originalBuffers.add(buffer);
        liveOriginalCodeUnits += piece.length;
      }
      node = current.right;
    }
    var originalCodeUnits = 0;
    for (final buffer in originalBuffers) {
      originalCodeUnits += buffer.length;
    }
    final addBufferCodeUnits = _addBuffer?.length ?? 0;
    return _TextPieceTreeStorageUsage(
      originalCodeUnits: originalCodeUnits,
      addBufferCodeUnits: addBufferCodeUnits,
      addBufferAllocatedCodeUnits: _addBuffer?.allocatedCodeUnits ?? 0,
      liveOriginalCodeUnits: liveOriginalCodeUnits,
      liveAddCodeUnits: liveAddCodeUnits,
      deadOriginalCodeUnits: math.max(0, originalCodeUnits - liveOriginalCodeUnits),
      deadAddCodeUnits: math.max(0, addBufferCodeUnits - liveAddCodeUnits),
    );
  }

  void debugResetCounters() {
    debugNodeVisitCount = 0;
    debugNodeRelinkCount = 0;
  }

  int offsetOfLineBreak(int index) {
    assert(index >= 0 && index < lineBreakCount);
    var node = _root!;
    var remaining = index;
    var offset = 0;
    while (true) {
      _visit(node);
      final leftBreaks = node.left?.lineBreakCount ?? 0;
      if (remaining < leftBreaks) {
        node = node.left!;
        continue;
      }
      final leftLength = node.left?.textLength ?? 0;
      offset += leftLength;
      remaining -= leftBreaks;
      if (remaining < node.piece.lineBreakCount) {
        return offset + node.piece.offsetOfLineBreak(remaining);
      }
      remaining -= node.piece.lineBreakCount;
      offset += node.piece.length;
      node = node.right!;
    }
  }

  int lineBreaksBefore(int offset) {
    if (offset <= 0 || _root == null) return 0;
    if (offset >= length) return lineBreakCount;
    var node = _root;
    var remaining = offset;
    var result = 0;
    while (node != null) {
      _visit(node);
      final leftLength = node.left?.textLength ?? 0;
      final leftBreaks = node.left?.lineBreakCount ?? 0;
      if (remaining < leftLength) {
        node = node.left;
        continue;
      }
      if (remaining == leftLength) return result + leftBreaks;
      result += leftBreaks;
      final pieceOffset = remaining - leftLength;
      if (pieceOffset <= node.piece.length) {
        return result + node.piece.lineBreaksBefore(pieceOffset);
      }
      result += node.piece.lineBreakCount;
      remaining = pieceOffset - node.piece.length;
      node = node.right;
    }
    return result;
  }

  String getText(int start, int end) {
    assert(start >= 0 && start <= end && end <= length);
    if (start == end) return '';
    final buffer = StringBuffer();
    _writeRange(_root, start, end, buffer);
    return buffer.toString();
  }

  _TextPieceLineBatch readLinesFromOffset(int startOffset, {required int maxLines, required int maxCodeUnits}) {
    assert(startOffset >= 0 && startOffset <= length);
    assert(maxLines > 0);
    assert(maxCodeUnits > 0);
    final root = _root;
    if (root == null) return const _TextPieceLineBatch(<String>[''], copiedCodeUnits: 0);
    final rootBuffer = root.piece.buffer;
    if (root.left == null && root.right == null && rootBuffer is _ImmutableTextBuffer) {
      _visit(root);
      return _readImmutableLines(root.piece, rootBuffer, startOffset, maxLines: maxLines, maxCodeUnits: maxCodeUnits);
    }
    final collector = _TextPieceLineCollector(maxLines: maxLines, maxCodeUnits: maxCodeUnits);
    _collectLinesFromOffset(root, startOffset, collector);
    return collector.finish();
  }

  _TextPieceLineBatch _readImmutableLines(
    _TextPiece piece,
    _ImmutableTextBuffer buffer,
    int localStart, {
    required int maxLines,
    required int maxCodeUnits,
  }) {
    final lines = <String>[];
    var copiedCodeUnits = 0;
    var cursor = piece.start + localStart;
    final pieceEnd = piece.start + piece.length;
    var breakIndex = _lowerBound(buffer.lineBreakOffsets, cursor, piece.firstLineBreak, piece.endLineBreak);
    while (lines.length < maxLines) {
      final hasBreak = breakIndex < piece.endLineBreak;
      final end = hasBreak ? buffer.lineBreakOffsets[breakIndex] : pieceEnd;
      final lineLength = end - cursor;
      if (copiedCodeUnits + lineLength > maxCodeUnits) break;
      lines.add(buffer.text.substring(cursor, end));
      copiedCodeUnits += lineLength;
      if (!hasBreak) break;
      cursor = end + 1;
      breakIndex++;
    }
    return _TextPieceLineBatch(List<String>.unmodifiable(lines), copiedCodeUnits: copiedCodeUnits);
  }

  void _collectLinesFromOffset(_TextPieceNode? node, int startOffset, _TextPieceLineCollector collector) {
    if (node == null || collector.isDone) return;
    _visit(node);
    final leftLength = node.left?.textLength ?? 0;
    if (startOffset < leftLength) {
      _collectLinesFromOffset(node.left, startOffset, collector);
      if (collector.isDone) return;
    }

    final localStart = (startOffset - leftLength).clamp(0, node.piece.length);
    if (localStart < node.piece.length) {
      collector.addPiece(node.piece, localStart);
      if (collector.isDone) return;
    }

    final pieceEnd = leftLength + node.piece.length;
    if (startOffset < node.textLength) {
      _collectLinesFromOffset(node.right, math.max(0, startOffset - pieceEnd), collector);
    }
  }

  TextDocumentSnapshotContent captureSnapshotContent() {
    final slices = <_TextPieceSnapshot>[];
    final stack = <_TextPieceNode>[];
    var node = _root;
    var textStart = 0;
    var lineBreakStart = 0;
    while (node != null || stack.isNotEmpty) {
      while (node != null) {
        stack.add(node);
        node = node.left;
      }
      final current = stack.removeLast();
      final slice = _TextPieceSnapshot.fromPiece(current.piece, textStart: textStart, lineBreakStart: lineBreakStart);
      slices.add(slice);
      textStart += slice.length;
      lineBreakStart += slice.lineBreakCount;
      node = current.right;
    }
    return TextDocumentSnapshotContent._(
      List<_TextPieceSnapshot>.unmodifiable(slices),
      length: textStart,
      lineBreakCount: lineBreakStart,
    );
  }

  int replace(int start, int end, String text) {
    assert(start >= 0 && start <= end && end <= length);
    final (before, suffixWithRemoved) = _split(_root, start);
    final (_, after) = _split(suffixWithRemoved, end - start);
    _TextPieceNode? inserted;
    var insertedLineBreakCount = 0;
    if (text.isNotEmpty) {
      final buffer = _addBuffer ??= _AppendTextBuffer();
      final bufferStart = buffer.append(text);
      insertedLineBreakCount =
          _lowerBound(buffer.lineBreakOffsets, bufferStart + text.length) -
          _lowerBound(buffer.lineBreakOffsets, bufferStart);
      inserted = _newNode(_TextPiece(buffer, bufferStart, text.length));
    }
    _root = _merge(_merge(before, inserted), after);
    return insertedLineBreakCount;
  }

  (_TextPieceNode?, _TextPieceNode?) _split(_TextPieceNode? root, int offset) {
    if (root == null) return (null, null);
    assert(offset >= 0 && offset <= root.textLength);
    if (offset == 0) return (null, root);
    if (offset == root.textLength) return (root, null);
    _visit(root);
    final leftLength = root.left?.textLength ?? 0;
    if (offset < leftLength) {
      final (before, remainder) = _split(root.left, offset);
      _setLeft(root, remainder);
      _refresh(root);
      return (before, root);
    }
    if (offset > leftLength + root.piece.length) {
      final (remainder, after) = _split(root.right, offset - leftLength - root.piece.length);
      _setRight(root, remainder);
      _refresh(root);
      return (root, after);
    }
    if (offset == leftLength) {
      final before = root.left;
      _setLeft(root, null);
      _refresh(root);
      return (before, root);
    }
    if (offset == leftLength + root.piece.length) {
      final after = root.right;
      _setRight(root, null);
      _refresh(root);
      return (root, after);
    }

    final pieceOffset = offset - leftLength;
    final leftPiece = _newNode(root.piece.slice(0, pieceOffset));
    final rightPiece = _newNode(root.piece.slice(pieceOffset, root.piece.length - pieceOffset));
    return (_merge(root.left, leftPiece), _merge(rightPiece, root.right));
  }

  _TextPieceNode? _merge(_TextPieceNode? before, _TextPieceNode? after) {
    if (before == null) return after;
    if (after == null) return before;
    final beforeEdge = _rightmostPiece(before);
    final afterEdge = _leftmostPiece(after);
    if (beforeEdge.canAppend(afterEdge)) {
      final (remainingBefore, removedBefore) = _removeRightmost(before);
      final (remainingAfter, removedAfter) = _removeLeftmost(after);
      final joined = _newNode(removedBefore.append(removedAfter));
      final withBefore = remainingBefore == null ? joined : _mergeTreap(remainingBefore, joined);
      return remainingAfter == null ? withBefore : _mergeTreap(withBefore, remainingAfter);
    }
    return _mergeTreap(before, after);
  }

  // 只沿两棵树的相邻边界探测，避免 replace 为归并 piece 扫描整棵树。
  _TextPiece _rightmostPiece(_TextPieceNode root) {
    var node = root;
    while (true) {
      _visit(node);
      final right = node.right;
      if (right == null) return node.piece;
      node = right;
    }
  }

  _TextPiece _leftmostPiece(_TextPieceNode root) {
    var node = root;
    while (true) {
      _visit(node);
      final left = node.left;
      if (left == null) return node.piece;
      node = left;
    }
  }

  (_TextPieceNode?, _TextPiece) _removeRightmost(_TextPieceNode root) {
    _visit(root);
    final right = root.right;
    if (right == null) return (root.left, root.piece);
    final (remaining, piece) = _removeRightmost(right);
    _setRight(root, remaining);
    _refresh(root);
    return (root, piece);
  }

  (_TextPieceNode?, _TextPiece) _removeLeftmost(_TextPieceNode root) {
    _visit(root);
    final left = root.left;
    if (left == null) return (root.right, root.piece);
    final (remaining, piece) = _removeLeftmost(left);
    _setLeft(root, remaining);
    _refresh(root);
    return (root, piece);
  }

  _TextPieceNode _mergeTreap(_TextPieceNode before, _TextPieceNode after) {
    if (_comesFirst(before, after)) {
      _visit(before);
      final right = before.right;
      _setRight(before, right == null ? after : _mergeTreap(right, after));
      _refresh(before);
      return before;
    }
    _visit(after);
    final left = after.left;
    _setLeft(after, left == null ? before : _mergeTreap(before, left));
    _refresh(after);
    return after;
  }

  void _writeRange(_TextPieceNode? node, int start, int end, StringBuffer output) {
    if (node == null || start >= end) return;
    _visit(node);
    final leftLength = node.left?.textLength ?? 0;
    if (start < leftLength) {
      _writeRange(node.left, start, math.min(end, leftLength), output);
    }
    final pieceEnd = leftLength + node.piece.length;
    final localStart = math.max(0, start - leftLength);
    final localEnd = math.min(node.piece.length, end - leftLength);
    if (localStart < localEnd) node.piece.writeTo(output, localStart, localEnd);
    if (end > pieceEnd) {
      _writeRange(node.right, math.max(0, start - pieceEnd), end - pieceEnd, output);
    }
  }

  _TextPieceNode _newNode(_TextPiece piece) {
    return _TextPieceNode(piece, _nextPriority(), _serial++);
  }

  int _nextPriority() {
    var value = _priorityState;
    value ^= (value << 13) & _priorityMask;
    value ^= value >> 17;
    value ^= (value << 5) & _priorityMask;
    _priorityState = value & _priorityMask;
    return _priorityState;
  }

  bool _comesFirst(_TextPieceNode a, _TextPieceNode b) {
    if (a.priority != b.priority) return a.priority < b.priority;
    return a.serial < b.serial;
  }

  void _visit(_TextPieceNode node) {
    assert(() {
      debugNodeVisitCount++;
      return true;
    }());
  }

  void _setLeft(_TextPieceNode node, _TextPieceNode? child) {
    if (identical(node.left, child)) return;
    node.left = child;
    _countRelink();
  }

  void _setRight(_TextPieceNode node, _TextPieceNode? child) {
    if (identical(node.right, child)) return;
    node.right = child;
    _countRelink();
  }

  void _countRelink() {
    assert(() {
      debugNodeRelinkCount++;
      return true;
    }());
  }

  void _refresh(_TextPieceNode node) {
    final left = node.left;
    final right = node.right;
    node
      ..textLength = (left?.textLength ?? 0) + node.piece.length + (right?.textLength ?? 0)
      ..lineBreakCount = (left?.lineBreakCount ?? 0) + node.piece.lineBreakCount + (right?.lineBreakCount ?? 0)
      ..nodeCount = (left?.nodeCount ?? 0) + 1 + (right?.nodeCount ?? 0)
      ..height = math.max(left?.height ?? 0, right?.height ?? 0) + 1;
  }
}

class _TextPieceLineBatch {
  const _TextPieceLineBatch(this.lines, {required this.copiedCodeUnits});

  final List<String> lines;
  final int copiedCodeUnits;
}

class _TextPieceLineCollector {
  _TextPieceLineCollector({required this.maxLines, required this.maxCodeUnits});

  final int maxLines;
  final int maxCodeUnits;
  final List<String> _lines = <String>[];
  StringBuffer _currentLine = StringBuffer();
  int _copiedCodeUnits = 0;
  bool _budgetExhausted = false;
  bool _done = false;

  bool get isDone => _done;

  void addPiece(_TextPiece piece, int localStart) {
    assert(localStart >= 0 && localStart < piece.length);
    var cursor = localStart;
    final absoluteStart = piece.start + localStart;
    var breakIndex = _lowerBound(
      piece.buffer.lineBreakOffsets,
      absoluteStart,
      piece.firstLineBreak,
      piece.endLineBreak,
    );
    while (!_done && breakIndex < piece.endLineBreak) {
      final localBreak = piece.buffer.lineBreakOffsets[breakIndex] - piece.start;
      if (localBreak >= piece.length) break;
      if (!_append(piece, cursor, localBreak)) return;
      _completeLine();
      cursor = localBreak + 1;
      breakIndex++;
    }
    if (!_done && cursor < piece.length) _append(piece, cursor, piece.length);
  }

  bool _append(_TextPiece piece, int start, int end) {
    if (start >= end) return true;
    final length = end - start;
    if (_copiedCodeUnits + length > maxCodeUnits) {
      _budgetExhausted = true;
      _done = true;
      return false;
    }
    piece.writeTo(_currentLine, start, end);
    _copiedCodeUnits += length;
    return true;
  }

  void _completeLine() {
    _lines.add(_currentLine.toString());
    _currentLine = StringBuffer();
    if (_lines.length >= maxLines) _done = true;
  }

  _TextPieceLineBatch finish() {
    if (!_done && !_budgetExhausted && _lines.length < maxLines) _completeLine();
    return _TextPieceLineBatch(List<String>.unmodifiable(_lines), copiedCodeUnits: _copiedCodeUnits);
  }
}

class _TextPieceTreeStorageUsage {
  const _TextPieceTreeStorageUsage({
    required this.originalCodeUnits,
    required this.addBufferCodeUnits,
    required this.addBufferAllocatedCodeUnits,
    required this.liveOriginalCodeUnits,
    required this.liveAddCodeUnits,
    required this.deadOriginalCodeUnits,
    required this.deadAddCodeUnits,
  });

  final int originalCodeUnits;
  final int addBufferCodeUnits;
  final int addBufferAllocatedCodeUnits;
  final int liveOriginalCodeUnits;
  final int liveAddCodeUnits;
  final int deadOriginalCodeUnits;
  final int deadAddCodeUnits;
}

class _TextPieceNode {
  _TextPieceNode(this.piece, this.priority, this.serial)
    : textLength = piece.length,
      lineBreakCount = piece.lineBreakCount;

  final _TextPiece piece;
  final int priority;
  final int serial;
  _TextPieceNode? left;
  _TextPieceNode? right;
  int textLength;
  int lineBreakCount;
  int nodeCount = 1;
  int height = 1;
}

class _TextPiece {
  _TextPiece(this.buffer, this.start, this.length)
    : assert(start >= 0 && length > 0 && start + length <= buffer.length),
      firstLineBreak = _lowerBound(buffer.lineBreakOffsets, start),
      endLineBreak = _lowerBound(buffer.lineBreakOffsets, start + length);

  final _TextBuffer buffer;
  final int start;
  final int length;
  final int firstLineBreak;
  final int endLineBreak;

  int get lineBreakCount => endLineBreak - firstLineBreak;

  bool canAppend(_TextPiece other) => identical(buffer, other.buffer) && start + length == other.start;

  _TextPiece append(_TextPiece other) {
    assert(canAppend(other));
    // 只扩大同一不可变 buffer 的引用区间，正文和换行索引均不复制。
    return _TextPiece(buffer, start, length + other.length);
  }

  _TextPiece slice(int offset, int sliceLength) {
    assert(offset >= 0 && sliceLength > 0 && offset + sliceLength <= length);
    // 分裂只改引用区间，不复制原文或换行表。
    return _TextPiece(buffer, start + offset, sliceLength);
  }

  int offsetOfLineBreak(int index) {
    assert(index >= 0 && index < lineBreakCount);
    return buffer.lineBreakOffsets[firstLineBreak + index] - start;
  }

  int lineBreaksBefore(int offset) {
    assert(offset >= 0 && offset <= length);
    return _lowerBound(buffer.lineBreakOffsets, start + offset, firstLineBreak, endLineBreak) - firstLineBreak;
  }

  void writeTo(StringSink output, int localStart, int localEnd) {
    assert(localStart >= 0 && localStart < localEnd && localEnd <= length);
    buffer.writeTo(output, start + localStart, start + localEnd);
  }
}

/// 捕获时冻结的 piece slice 集合；仅供公开快照与稳定流式读取使用。
@internal
final class TextDocumentSnapshotContent {
  TextDocumentSnapshotContent._(this._slices, {required this.length, required this.lineBreakCount});

  final List<_TextPieceSnapshot> _slices;

  /// debug 模式下观测到的最大内部临时字符串或缓冲长度。
  static int debugMaxTemporaryCodeUnits = 0;

  /// 清零内部临时字符串与缓冲峰值探针。
  static void debugResetTemporaryCounters() => debugMaxTemporaryCodeUnits = 0;

  /// 捕获正文的 UTF-16 长度。
  final int length;

  /// 捕获正文中的 LF 数量。
  final int lineBreakCount;

  /// 捕获时保留的 piece slice 数量。
  int get sliceCount => _slices.length;

  /// 行映射保留的聚合索引项数量；其规模只与 piece 数量有关。
  int get lineIndexEntryCount => _slices.length;

  /// 返回第 [index] 个 LF 在全文中的 UTF-16 offset。
  int offsetOfLineBreak(int index) {
    assert(index >= 0 && index < lineBreakCount);
    var low = 0;
    var high = _slices.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_slices[middle].lineBreakEnd <= index) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final slice = _slices[low];
    return slice.textStart + slice.offsetOfLineBreak(index - slice.lineBreakStart);
  }

  /// 统计 `[0, offset)` 中的 LF 数量。
  int lineBreaksBefore(int offset) {
    if (offset <= 0 || _slices.isEmpty) return 0;
    if (offset >= length) return lineBreakCount;
    final slice = _slices[_sliceIndexAt(offset)];
    return slice.lineBreakStart + slice.lineBreaksBefore(offset - slice.textStart);
  }

  /// 返回指定 UTF-16 [offset] 的 code unit。
  int codeUnitAt(int offset) {
    assert(offset >= 0 && offset < length);
    final slice = _slices[_sliceIndexAt(offset)];
    return slice.codeUnitAt(offset - slice.textStart);
  }

  /// 读取捕获正文的 `[start, end)` 区间。
  String getText(int start, int end) {
    assert(start >= 0 && start <= end && end <= length);
    if (start == end) return '';
    final output = StringBuffer();
    _writeRangeTo(output, start, end);
    return output.toString();
  }

  /// 以有界字符串块读取捕获正文。
  Iterable<String> chunks({required int chunkSize, required TextDocumentEol eol}) {
    _validateChunkSize(chunkSize);
    return _serializedChunks(chunkSize: chunkSize, eol: eol);
  }

  /// 以有界字符串块把捕获正文写入 [output]。
  void writeTo(StringSink output, {required TextDocumentEol eol, required int chunkSize}) {
    for (final chunk in chunks(chunkSize: chunkSize, eol: eol)) {
      output.write(chunk);
    }
  }

  Iterable<String> _serializedChunks({required int chunkSize, required TextDocumentEol eol}) sync* {
    if (eol == TextDocumentEol.lf) {
      yield* _lfChunks(chunkSize);
      return;
    }
    yield* _crlfChunks(chunkSize);
  }

  Iterable<String> _lfChunks(int chunkSize) sync* {
    var start = 0;
    while (start < length) {
      var end = math.min(start + chunkSize, length);
      if (end < length && _isHighSurrogate(codeUnitAt(end - 1)) && _isLowSurrogate(codeUnitAt(end))) {
        end--;
      }
      final chunk = getText(start, end);
      _recordTemporaryLength(chunk.length);
      yield chunk;
      start = end;
    }
  }

  Iterable<String> _crlfChunks(int chunkSize) sync* {
    var output = StringBuffer();
    var outputLength = 0;
    for (final source in _lfChunks(chunkSize)) {
      var sourceStart = 0;
      while (sourceStart < source.length) {
        if (source.codeUnitAt(sourceStart) == 0x0a) {
          if (outputLength + 2 > chunkSize) {
            final chunk = output.toString();
            _recordTemporaryLength(chunk.length);
            yield chunk;
            output = StringBuffer();
            outputLength = 0;
          }
          output.write('\r\n');
          outputLength += 2;
          _recordTemporaryLength(outputLength);
          sourceStart++;
          continue;
        }

        if (outputLength == chunkSize) {
          final chunk = output.toString();
          _recordTemporaryLength(chunk.length);
          yield chunk;
          output = StringBuffer();
          outputLength = 0;
        }
        final newline = source.indexOf('\n', sourceStart);
        final runEnd = newline < 0 ? source.length : newline;
        var sourceEnd = math.min(runEnd, sourceStart + chunkSize - outputLength);
        if (sourceEnd < runEnd &&
            _isHighSurrogate(source.codeUnitAt(sourceEnd - 1)) &&
            _isLowSurrogate(source.codeUnitAt(sourceEnd))) {
          sourceEnd--;
        }
        if (sourceEnd == sourceStart) {
          final chunk = output.toString();
          _recordTemporaryLength(chunk.length);
          yield chunk;
          output = StringBuffer();
          outputLength = 0;
          continue;
        }
        final segment = source.substring(sourceStart, sourceEnd);
        _recordTemporaryLength(segment.length);
        output.write(segment);
        outputLength += segment.length;
        _recordTemporaryLength(outputLength);
        sourceStart = sourceEnd;
      }
    }
    if (outputLength > 0) {
      final chunk = output.toString();
      _recordTemporaryLength(chunk.length);
      yield chunk;
    }
  }

  void _writeRangeTo(StringSink output, int start, int end) {
    var sliceIndex = _sliceIndexAt(start);
    var cursor = start;
    while (cursor < end) {
      final slice = _slices[sliceIndex];
      final localStart = cursor - slice.textStart;
      final localEnd = math.min(slice.length, end - slice.textStart);
      slice.writeTo(output, localStart, localEnd);
      cursor = slice.textStart + localEnd;
      sliceIndex++;
    }
  }

  int _sliceIndexAt(int offset) {
    var low = 0;
    var high = _slices.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_slices[middle].textEnd <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  static void _recordTemporaryLength(int length) {
    assert(() {
      debugMaxTemporaryCodeUnits = math.max(debugMaxTemporaryCodeUnits, length);
      return true;
    }());
  }
}

class _TextPieceSnapshot {
  _TextPieceSnapshot.fromPiece(_TextPiece piece, {required this.textStart, required this.lineBreakStart})
    : buffer = piece.buffer,
      start = piece.start,
      length = piece.length,
      firstLineBreak = piece.firstLineBreak,
      endLineBreak = piece.endLineBreak;

  final _TextBuffer buffer;
  final int start;
  final int length;
  final int firstLineBreak;
  final int endLineBreak;
  final int textStart;
  final int lineBreakStart;

  int get textEnd => textStart + length;
  int get lineBreakCount => endLineBreak - firstLineBreak;
  int get lineBreakEnd => lineBreakStart + lineBreakCount;

  int offsetOfLineBreak(int index) {
    assert(index >= 0 && index < lineBreakCount);
    return buffer.lineBreakOffsets[firstLineBreak + index] - start;
  }

  int lineBreaksBefore(int offset) {
    assert(offset >= 0 && offset <= length);
    return _lowerBound(buffer.lineBreakOffsets, start + offset, firstLineBreak, endLineBreak) - firstLineBreak;
  }

  int codeUnitAt(int offset) {
    assert(offset >= 0 && offset < length);
    return buffer.codeUnitAt(start + offset);
  }

  void writeTo(StringSink output, int localStart, int localEnd) {
    assert(localStart >= 0 && localStart < localEnd && localEnd <= length);
    buffer.writeTo(output, start + localStart, start + localEnd);
  }
}

abstract class _TextBuffer {
  int get length;

  List<int> get lineBreakOffsets;

  int codeUnitAt(int index);

  void writeTo(StringSink output, int start, int end);
}

class _ImmutableTextBuffer implements _TextBuffer {
  _ImmutableTextBuffer(this.text) : lineBreakOffsets = _collectLineBreaks(text);

  final String text;
  @override
  int get length => text.length;

  @override
  final List<int> lineBreakOffsets;

  @override
  int codeUnitAt(int index) => text.codeUnitAt(index);

  @override
  void writeTo(StringSink output, int start, int end) => output.write(text.substring(start, end));
}

/// Piece table 的共享追加缓冲：固定 UTF-16 页让逐字符 append 总复制量保持 O(n)。
///
/// piece 继续只保存 `(buffer, start, length)`；连续键入时追加区间与文档位置均
/// 相邻，treap 边界合并后整段输入只占一个 piece。删除/undo 不回收旧页，这是
/// piece table 的预期持久语义，历史引用和 redo 不需要复制原文。
class _AppendTextBuffer implements _TextBuffer {
  static const int _pageSize = 4096;

  final List<Uint16List> _pages = [];
  @override
  final List<int> lineBreakOffsets = [];
  int _length = 0;

  @override
  int get length => _length;

  int get pageCount => _pages.length;

  int get allocatedCodeUnits => _pages.length * _pageSize;

  @override
  int codeUnitAt(int index) {
    assert(index >= 0 && index < _length);
    return _pages[index ~/ _pageSize][index % _pageSize];
  }

  /// 追加 [text] 并返回其在共享缓冲中的起始 offset。
  int append(String text) {
    assert(text.isNotEmpty);
    final start = _length;
    for (var source = 0; source < text.length;) {
      final pageIndex = _length ~/ _pageSize;
      final pageOffset = _length % _pageSize;
      if (pageIndex == _pages.length) _pages.add(Uint16List(_pageSize));
      final page = _pages[pageIndex];
      final count = math.min(_pageSize - pageOffset, text.length - source);
      for (var i = 0; i < count; i++) {
        final codeUnit = text.codeUnitAt(source + i);
        page[pageOffset + i] = codeUnit;
        if (codeUnit == 0x0a) lineBreakOffsets.add(_length + i);
      }
      source += count;
      _length += count;
    }
    return start;
  }

  @override
  void writeTo(StringSink output, int start, int end) {
    assert(start >= 0 && start < end && end <= _length);
    var cursor = start;
    while (cursor < end) {
      final pageIndex = cursor ~/ _pageSize;
      final pageOffset = cursor % _pageSize;
      final count = math.min(_pageSize - pageOffset, end - cursor);
      output.write(String.fromCharCodes(_pages[pageIndex], pageOffset, pageOffset + count));
      cursor += count;
    }
  }
}

void _validateChunkSize(int chunkSize) {
  if (chunkSize < 2) {
    throw RangeError.range(chunkSize, 2, null, 'chunkSize', '块长至少为 2，避免拆开 UTF-16 代理对或 CRLF');
  }
}

bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;

bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

List<int> _collectLineBreaks(String text) {
  final result = <int>[];
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0a) result.add(i);
  }
  return result;
}

int _lowerBound(List<int> values, int target, [int start = 0, int? end]) {
  var low = start;
  var high = end ?? values.length;
  while (low < high) {
    final middle = (low + high) >> 1;
    if (values[middle] < target) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}
