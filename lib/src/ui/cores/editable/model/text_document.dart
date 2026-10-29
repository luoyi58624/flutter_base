import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart' show internal;

part 'text_piece_tree.dart';

/// 文档中的一次替换编辑结果，供上层（undo、渲染失效、IME 回推）消费。
class DocumentEdit {
  /// 创建一次已经兑现到文档的替换描述。
  const DocumentEdit({
    required this.start,
    required this.removed,
    required this.inserted,
    required this.firstDirtyLine,
    required this.removedLineCount,
    required this.insertedLineCount,
  });

  /// 编辑起点（doc offset）。
  final int start;

  /// 被移除的原文（可空串）。
  final String removed;

  /// 插入的新文（可空串，已换行归一化）。
  final String inserted;

  /// 受影响的首个逻辑行 index（该行起所有行文本可能变化）。
  final int firstDirtyLine;

  /// 编辑跨越的原行数（含首行，≥1）。
  final int removedLineCount;

  /// 编辑后占据的行数（含首行，≥1）。
  final int insertedLineCount;

  /// 行数净变化（插入行数 − 移除行数）。
  int get lineDelta => insertedLineCount - removedLineCount;

  /// 编辑终点（doc offset，指向插入文本之后）。
  int get end => start + inserted.length;
}

/// 逻辑行内坐标：第 [line] 行第 [column] 列（均 0-based，column 不含换行符）。
typedef LinePosition = ({int line, int column});

/// 文档保存时使用的换行序列；内核坐标始终基于单个 `\n` code unit。
enum TextDocumentEol {
  /// Unix / macOS 换行。
  lf('\n'),

  /// Windows 换行。
  crlf('\r\n');

  const TextDocumentEol(this.sequence);

  /// 对外序列化时写入的字符序列。
  final String sequence;

  /// 把已经 LF 归一化的 [text] 序列化为当前换行形态。
  String serialize(String text) => this == lf || !text.contains('\n') ? text : text.replaceAll('\n', sequence);
}

/// 用平衡 piece tree 保存 UTF-16 文本的文档模型。
///
/// 每个 piece 只引用一段不可变原文，树节点聚合 UTF-16 长度与 `\n` 数量；替换、
/// offset/行坐标互转及单行读取均无需物化全文，也不会因顶部增删行而搬移全体行
/// 引用。空文档由空树表达，但逻辑上始终保留一个空行。
class TextDocument {
  /// 流式读取默认使用的最大块长（UTF-16 code unit）。
  static const int defaultChunkSize = 64 * 1024;

  /// 从 [text] 创建文档，写入前会统一归一化换行，并从原文检测首选 EOL。
  TextDocument([String text = ''])
    : _preferredEol = detectPreferredEol(text),
      _tree = _TextPieceTree(normalizeNewlines(text));

  /// 从 [text] 创建文档并显式指定保存时的首选 EOL。
  TextDocument.withEol(String text, {required TextDocumentEol eol})
    : _preferredEol = eol,
      _tree = _TextPieceTree(normalizeNewlines(text));

  _TextPieceTree _tree;
  TextDocumentEol _preferredEol;

  /// 把 `\r\n` / `\r` 归一化为 `\n`。
  static String normalizeNewlines(String text) {
    if (!text.contains('\r')) return text;
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// 从原文中的 LF / CRLF 数量检测首选 EOL；无换行或票数相同时使用 [fallback]。
  static TextDocumentEol detectPreferredEol(String text, {TextDocumentEol fallback = TextDocumentEol.lf}) {
    var lf = 0;
    var crlf = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) != 0x0a) continue;
      if (i > 0 && text.codeUnitAt(i - 1) == 0x0d) {
        crlf++;
      } else {
        lf++;
      }
    }
    if (lf == crlf) return fallback;
    return crlf > lf ? TextDocumentEol.crlf : TextDocumentEol.lf;
  }

  /// 保存时默认使用的换行形态；不参与 UTF-16 文档坐标。
  TextDocumentEol get preferredEol => _preferredEol;

  /// 更改后续默认序列化形态，不改正文、选区或文本修订。
  void setPreferredEol(TextDocumentEol value) => _preferredEol = value;

  /// 逻辑行数（恒 ≥ 1）。
  int get lineCount => _tree.lineBreakCount + 1;

  /// 全文 UTF-16 长度（含行间换行符）。
  int get length => _tree.length;

  /// 是否为单个空行的空文档。
  bool get isEmpty => _tree.length == 0;

  /// 第 [line] 行文本（不含换行符）。
  String lineAt(int line) {
    final start = lineStart(line);
    final text = _tree.getText(start, lineEnd(line));
    assert(() {
      _debugRecordTextRead(text.length);
      return true;
    }());
    return text;
  }

  /// 从 [startLine] 起顺序读取一批完整逻辑行，不包含行间换行符。
  ///
  /// 批次最多返回 [maxLines] 行，且实际从 piece buffer 复制的正文总量不超过
  /// [maxCodeUnits]。如果首行本身超过预算则返回空列表；调用方可据此切换到
  /// 长行窗口。每批只为首行做固定次数的树定位，随后连续扫描触及的 piece，
  /// 适合虚拟视口连续挂载短行。
  @internal
  List<String> readLines(int startLine, {int maxLines = 64, int maxCodeUnits = defaultChunkSize}) {
    if (startLine < 0 || startLine >= lineCount) {
      throw RangeError.range(startLine, 0, lineCount - 1, 'startLine');
    }
    if (maxLines <= 0) throw RangeError.range(maxLines, 1, null, 'maxLines');
    if (maxCodeUnits <= 0) throw RangeError.range(maxCodeUnits, 1, null, 'maxCodeUnits');
    final batch = _tree.readLinesFromOffset(lineStart(startLine), maxLines: maxLines, maxCodeUnits: maxCodeUnits);
    assert(() {
      debugLineBatchReadCount++;
      debugLineBatchCopiedCodeUnits += batch.copiedCodeUnits;
      debugMaxLineBatchCopiedCodeUnits = math.max(debugMaxLineBatchCopiedCodeUnits, batch.copiedCodeUnits);
      for (final line in batch.lines) {
        _debugRecordTextRead(line.length);
      }
      return true;
    }());
    return batch.lines;
  }

  /// 第 [line] 行 UTF-16 长度（不含换行符）。
  int lineLength(int line) => lineEnd(line) - lineStart(line);

  /// 第 [line] 行行首 doc offset。
  int lineStart(int line) {
    assert(line >= 0 && line < lineCount);
    if (line == 0) return 0;
    return _tree.offsetOfLineBreak(line - 1) + 1;
  }

  /// 第 [line] 行行尾 doc offset（不含换行符，即行内最后一个字符之后）。
  int lineEnd(int line) {
    assert(line >= 0 && line < lineCount);
    return line < _tree.lineBreakCount ? _tree.offsetOfLineBreak(line) : length;
  }

  /// [offset] 所在逻辑行 index；offset 落在换行符上归属左侧行。
  int lineIndexOf(int offset) {
    assert(offset >= 0);
    return _tree.lineBreaksBefore(offset.clamp(0, length));
  }

  /// doc offset → 行内坐标，越界 offset 钳到文档首尾。
  LinePosition positionOf(int offset) {
    final effectiveOffset = offset.clamp(0, length);
    final line = lineIndexOf(effectiveOffset);
    return (line: line, column: effectiveOffset - lineStart(line));
  }

  /// 行内坐标 → doc offset，line 与 column 越界时分别钳到有效行和行尾。
  int offsetOf(int line, int column) {
    final effectiveLine = line.clamp(0, lineCount - 1);
    return lineStart(effectiveLine) + column.clamp(0, lineLength(effectiveLine));
  }

  /// 测试探针：当前 piece 索引节点数；空文档按一个逻辑哨兵节点计数。
  int get debugValidStartCount => math.max(1, _tree.pieceCount);

  /// 测试探针：当前 piece tree 高度，用于识别结构退化。
  int get debugTreeHeight => _tree.height;

  /// 测试探针：共享追加缓冲当前分配的固定页数。
  int get debugAddBufferPageCount => _tree.debugAddBufferPageCount;

  /// 测试探针：当前真实 piece 数；空文档返回 0。
  int get debugPieceCount => _tree.pieceCount;

  /// 测试探针：live piece 仍引用的不可变原文 buffer 总长度。
  int get debugOriginalCodeUnits => _tree.debugStorageUsage.originalCodeUnits;

  /// 测试探针：追加缓冲已经写入的 UTF-16 code unit 数，包含已删除区间。
  int get debugAddBufferCodeUnits => _tree.debugAddBufferCodeUnits;

  /// 测试探针：追加缓冲固定页当前分配的 UTF-16 容量。
  int get debugAddBufferAllocatedCodeUnits => _tree.debugAddBufferAllocatedCodeUnits;

  /// 测试探针：当前正文仍引用的不可变原文 code unit 数。
  int get debugLiveOriginalCodeUnits => _tree.debugStorageUsage.liveOriginalCodeUnits;

  /// 测试探针：当前正文仍引用的追加缓冲 code unit 数。
  int get debugLiveAddCodeUnits => _tree.debugStorageUsage.liveAddCodeUnits;

  /// 测试探针：因切片仍被 live piece 引用而保留、但已不在正文中的原文长度。
  int get debugDeadOriginalCodeUnits => _tree.debugStorageUsage.deadOriginalCodeUnits;

  /// 测试探针：追加后已从正文删除、仍被共享追加缓冲保留的长度。
  int get debugDeadAddCodeUnits => _tree.debugStorageUsage.deadAddCodeUnits;

  /// 测试探针：最近一次重置后累计访问的树节点数。
  int get debugNodeVisitCount => _tree.debugNodeVisitCount;

  /// 测试探针：最近一次重置后累计重挂的既有树节点数。
  int get debugNodeRelinkCount => _tree.debugNodeRelinkCount;

  /// 测试探针：清零节点访问与重挂计数，不改变文档结构。
  void debugResetTreeCounters() => _tree.debugResetCounters();

  /// 测试探针：单次 [getText] 的最大跨度（仅 debug 记录；IME 通道负载与
  /// 全文物化监控用）。
  static int debugMaxGetTextSpan = 0;

  /// 测试探针：最近一次重置后执行的 [getText] 次数。
  static int debugGetTextCallCount = 0;

  /// 测试探针：最近一次重置后由 [getText] 请求物化的累计长度。
  static int debugGetTextCodeUnits = 0;

  /// 测试探针：任一 live 文本读取 API 单次返回字符串的最大 UTF-16 长度。
  ///
  /// 与只观察 [getText] 的 [debugMaxGetTextSpan] 不同，本探针也覆盖 [lineAt]
  /// 及 [readLines]，用于识别渲染热路径绕过区间读取探针的整行物化。
  static int debugMaxTextReadSpan = 0;

  /// 测试探针：最近一次重置后由 live 文本读取 API 返回的字符串数量。
  static int debugTextReadStringCount = 0;

  /// 测试探针：最近一次重置后由 live 文本读取 API 返回的累计 UTF-16 长度。
  static int debugTextReadCodeUnits = 0;

  /// 测试探针：最近一次重置后执行的连续行批读次数。
  static int debugLineBatchReadCount = 0;

  /// 测试探针：连续行批读从 piece buffer 实际复制的累计 UTF-16 长度。
  static int debugLineBatchCopiedCodeUnits = 0;

  /// 测试探针：单次连续行批读从 piece buffer 复制的最大 UTF-16 长度。
  static int debugMaxLineBatchCopiedCodeUnits = 0;

  /// 清零 [getText] 次数、累计长度与最大跨度，不改变文档。
  static void debugResetGetTextCounters() {
    debugMaxGetTextSpan = 0;
    debugGetTextCallCount = 0;
    debugGetTextCodeUnits = 0;
  }

  /// 清零 live 文本读取与连续行批读探针，不改变文档。
  static void debugResetTextReadCounters() {
    debugMaxTextReadSpan = 0;
    debugTextReadStringCount = 0;
    debugTextReadCodeUnits = 0;
    debugLineBatchReadCount = 0;
    debugLineBatchCopiedCodeUnits = 0;
    debugMaxLineBatchCopiedCodeUnits = 0;
  }

  static void _debugRecordTextRead(int length) {
    debugMaxTextReadSpan = math.max(debugMaxTextReadSpan, length);
    debugTextReadStringCount++;
    debugTextReadCodeUnits += length;
  }

  /// 取 `[start, end)` 区间文本（含跨行换行符），反向或越界区间会先归一化。
  String getText(int start, int end) {
    final rangeStart = math.min(start, end).clamp(0, length);
    final rangeEnd = math.max(start, end).clamp(0, length);
    assert(() {
      final span = rangeEnd - rangeStart;
      debugMaxGetTextSpan = math.max(debugMaxGetTextSpan, span);
      debugGetTextCallCount++;
      debugGetTextCodeUnits += span;
      _debugRecordTextRead(span);
      return true;
    }());
    return _tree.getText(rangeStart, rangeEnd);
  }

  /// 全文文本；大文档下是 O(n) 物化，热路径勿滥用。
  String get text => getText(0, length);

  /// 以不超过 [chunkSize] 个 UTF-16 code unit 的块读取当前正文。
  ///
  /// 调用时会先冻结当前 piece slice，因此迭代期间后续编辑不会改变本次内容；
  /// [eol] 默认输出内核使用的 LF，传 CRLF 时按块转换且不会拆开代理对或 CRLF。
  /// [chunkSize] 必须至少为 2。
  Iterable<String> chunks({int chunkSize = defaultChunkSize, TextDocumentEol eol = TextDocumentEol.lf}) {
    final content = _tree.captureSnapshotContent();
    return content.chunks(chunkSize: chunkSize, eol: eol);
  }

  /// 把当前正文按块写入 [output]，全程不物化完整中间字符串。
  ///
  /// [eol] 为 null 时沿用 [preferredEol]；单块最多 [chunkSize] 个 UTF-16
  /// code unit，适合直接连接文件或网络字符 sink；[chunkSize] 必须至少为 2。
  void writeTo(StringSink output, {TextDocumentEol? eol, int chunkSize = defaultChunkSize}) {
    final content = _tree.captureSnapshotContent();
    content.writeTo(output, eol: eol ?? preferredEol, chunkSize: chunkSize);
  }

  /// 按 [eol] 序列化全文；null 时沿用 [preferredEol]。
  ///
  /// 这是显式 O(n) 保存路径，编辑、布局与查询热路径应继续读取 LF 归一化正文。
  String serialize({TextDocumentEol? eol}) {
    final output = StringBuffer();
    writeTo(output, eol: eol);
    return output.toString();
  }

  /// 把当前正文重建为单个不可变原文 buffer，释放 live 文档持有的追加页与碎片。
  ///
  /// 返回是否实际重建。该操作不改变正文、EOL 或任何 offset，但会 O(n) 物化
  /// 全文并产生短暂峰值；已经交给调用方的快照继续保留旧 buffer，直至快照释放。
  bool compact() {
    if (_tree.isCompact) return false;
    final compactedText = getText(0, length);
    _tree = _TextPieceTree(compactedText);
    return true;
  }

  /// 用 [text] 替换 `[start, end)` 区间并返回编辑描述。
  ///
  /// 这是唯一的公开写入原语；插入 = `start == end`，删除 = [text] 为空。
  DocumentEdit replace(int start, int end, String text) {
    final inserted = normalizeNewlines(text);
    final rangeStart = math.min(start, end).clamp(0, length);
    final rangeEnd = math.max(start, end).clamp(0, length);
    final removed = getText(rangeStart, rangeEnd);
    return _replacePrepared(rangeStart, rangeEnd, inserted, removed);
  }

  /// 控制器事务已读取 [removed] 时复用该 payload，避免大块替换重复物化。
  ///
  /// [text] 必须已经完成换行归一化与编辑策略；[preferImmutableBuffer] 仅供
  /// 完整外部基线直接采用调用方字符串，避免先复制进 add buffer。仅供
  /// editable 内核调用。
  @internal
  DocumentEdit replacePrepared(
    int start,
    int end,
    String text, {
    required String removed,
    bool preferImmutableBuffer = false,
  }) {
    final rangeStart = math.min(start, end).clamp(0, length);
    final rangeEnd = math.max(start, end).clamp(0, length);
    assert(!text.contains('\r'), 'prepared 文本必须已经归一化为 LF');
    assert(removed.length == rangeEnd - rangeStart, 'removed payload 长度必须与替换区间一致');
    assert(!preferImmutableBuffer || (rangeStart == 0 && rangeEnd == length), '只有完整替换才能直接采用不可变正文 buffer');
    return _replacePrepared(rangeStart, rangeEnd, text, removed, preferImmutableBuffer: preferImmutableBuffer);
  }

  DocumentEdit _replacePrepared(
    int rangeStart,
    int rangeEnd,
    String inserted,
    String removed, {
    bool preferImmutableBuffer = false,
  }) {
    final firstDirtyLine = lineIndexOf(rangeStart);
    final removedLineCount = lineIndexOf(rangeEnd) - firstDirtyLine + 1;
    late final int insertedLineBreakCount;
    if (rangeStart == 0 && rangeEnd == length && (rangeEnd > 0 || preferImmutableBuffer)) {
      _tree = _TextPieceTree(inserted);
      insertedLineBreakCount = _tree.lineBreakCount;
    } else {
      insertedLineBreakCount = _tree.replace(rangeStart, rangeEnd, inserted);
    }

    return DocumentEdit(
      start: rangeStart,
      removed: removed,
      inserted: inserted,
      firstDirtyLine: firstDirtyLine,
      removedLineCount: removedLineCount,
      insertedLineCount: insertedLineBreakCount + 1,
    );
  }
}

/// 冻结 [source] 的当前 piece slice，供快照工厂跨库调用。
@internal
TextDocumentSnapshotContent captureTextDocumentContent(TextDocument source) => source._tree.captureSnapshotContent();
