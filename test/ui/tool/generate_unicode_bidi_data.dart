import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _unicodeVersion = '17.0.0';
const _derivedBidiClassName = 'DerivedBidiClass.txt';
const _bidiBracketsName = 'BidiBrackets.txt';
const _unicodeDataName = 'UnicodeData.txt';
const _derivedBidiClassUrl = 'https://www.unicode.org/Public/$_unicodeVersion/ucd/extracted/$_derivedBidiClassName';
const _bidiBracketsUrl = 'https://www.unicode.org/Public/$_unicodeVersion/ucd/$_bidiBracketsName';
const _unicodeDataUrl = 'https://www.unicode.org/Public/$_unicodeVersion/ucd/$_unicodeDataName';
const _unicodeScalarLimit = 0x110000;

const _classNames = <String>[
  'l',
  'r',
  'al',
  'en',
  'es',
  'et',
  'an',
  'cs',
  'nsm',
  'bn',
  'b',
  's',
  'ws',
  'on',
  'lre',
  'lro',
  'rle',
  'rlo',
  'pdf',
  'lri',
  'rli',
  'fsi',
  'pdi',
];

const _classDocs = <String>[
  'Left_To_Right (L)',
  'Right_To_Left (R)',
  'Arabic_Letter (AL)',
  'European_Number (EN)',
  'European_Separator (ES)',
  'European_Terminator (ET)',
  'Arabic_Number (AN)',
  'Common_Separator (CS)',
  'Nonspacing_Mark (NSM)',
  'Boundary_Neutral (BN)',
  'Paragraph_Separator (B)',
  'Segment_Separator (S)',
  'White_Space (WS)',
  'Other_Neutral (ON)',
  'Left_To_Right_Embedding (LRE)',
  'Left_To_Right_Override (LRO)',
  'Right_To_Left_Embedding (RLE)',
  'Right_To_Left_Override (RLO)',
  'Pop_Directional_Format (PDF)',
  'Left_To_Right_Isolate (LRI)',
  'Right_To_Left_Isolate (RLI)',
  'First_Strong_Isolate (FSI)',
  'Pop_Directional_Isolate (PDI)',
];

const _classAliases = <String, int>{
  'L': 0,
  'Left_To_Right': 0,
  'R': 1,
  'Right_To_Left': 1,
  'AL': 2,
  'Arabic_Letter': 2,
  'EN': 3,
  'European_Number': 3,
  'ES': 4,
  'European_Separator': 4,
  'ET': 5,
  'European_Terminator': 5,
  'AN': 6,
  'Arabic_Number': 6,
  'CS': 7,
  'Common_Separator': 7,
  'NSM': 8,
  'Nonspacing_Mark': 8,
  'BN': 9,
  'Boundary_Neutral': 9,
  'B': 10,
  'Paragraph_Separator': 10,
  'S': 11,
  'Segment_Separator': 11,
  'WS': 12,
  'White_Space': 12,
  'ON': 13,
  'Other_Neutral': 13,
  'LRE': 14,
  'Left_To_Right_Embedding': 14,
  'LRO': 15,
  'Left_To_Right_Override': 15,
  'RLE': 16,
  'Right_To_Left_Embedding': 16,
  'RLO': 17,
  'Right_To_Left_Override': 17,
  'PDF': 18,
  'Pop_Directional_Format': 18,
  'LRI': 19,
  'Left_To_Right_Isolate': 19,
  'RLI': 20,
  'Right_To_Left_Isolate': 20,
  'FSI': 21,
  'First_Strong_Isolate': 21,
  'PDI': 22,
  'Pop_Directional_Isolate': 22,
};

final _missingPattern = RegExp(r'^#\s*@missing:\s*([0-9A-Fa-f]+)(?:\.\.([0-9A-Fa-f]+))?\s*;\s*([A-Za-z_]+)\s*$');
final _classRecordPattern = RegExp(r'^([0-9A-Fa-f]+)(?:\.\.([0-9A-Fa-f]+))?\s*;\s*([A-Za-z_]+)\s*$');
final _bracketRecordPattern = RegExp(r'^([0-9A-Fa-f]+)\s*;\s*([0-9A-Fa-f]+|<none>)\s*;\s*([ocn])\s*$');

Future<void> main(List<String> arguments) async {
  final options = _GeneratorOptions.parse(arguments);
  if (options.help) {
    stdout.write(
      '生成 Unicode $_unicodeVersion bidi 数据。\n'
      '  dart run tool/generate_unicode_bidi_data.dart [--ucd-dir DIR] [--output FILE] [--check]\n',
    );
    return;
  }

  final sources = options.ucdDirectory == null ? await _downloadSources() : await _readSources(options.ucdDirectory!);
  final generated = generateUnicodeBidiDataSource(
    derivedBidiClass: sources.derivedBidiClass,
    bidiBrackets: sources.bidiBrackets,
    unicodeData: sources.unicodeData,
  );
  final output = options.output ?? _defaultOutputFile();
  if (options.check) {
    if (!await output.exists() || await output.readAsString() != generated) {
      throw StateError('${output.path} 不是当前 Unicode $_unicodeVersion 数据的确定性生成结果。');
    }
    stdout.writeln('Unicode bidi 数据已是最新确定性结果：${output.path}');
    return;
  }
  await output.parent.create(recursive: true);
  await output.writeAsString(generated);
  stdout.writeln('已生成 ${output.path}');
}

/// 从三份官方 UCD 文本生成 el_ui 内部 Unicode bidi 查表源码。
///
/// 解析是严格的：未知类别、重叠显式区间、非法 bracket pair、版本不一致或
/// 缺失全局 `@missing` 都会抛出 [FormatException]，不会生成部分结果。
String generateUnicodeBidiDataSource({
  required String derivedBidiClass,
  required String bidiBrackets,
  required String unicodeData,
}) {
  _requireVersionHeader(derivedBidiClass, 'DerivedBidiClass-$_unicodeVersion.txt', _derivedBidiClassName);
  _requireVersionHeader(bidiBrackets, 'BidiBrackets-$_unicodeVersion.txt', _bidiBracketsName);
  final classData = _parseBidiClasses(derivedBidiClass);
  final brackets = _parseBrackets(bidiBrackets);
  final canonical = _parseCanonicalDecompositions(unicodeData);
  final resolvedBrackets = _resolveBrackets(brackets, canonical);
  return _emitSource(classData, resolvedBrackets);
}

_BidiClassData _parseBidiClasses(String source) {
  final missing = <_ClassRange>[];
  final explicit = <_ClassRange>[];
  final seenClasses = <int>{};
  var hasGlobalMissing = false;
  final lines = const LineSplitter().convert(source);
  for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
    final original = lines[lineNumber].trim();
    if (original.isEmpty) continue;
    final missingMatch = _missingPattern.firstMatch(original);
    if (missingMatch != null) {
      final range = _classRangeFromMatch(missingMatch, lineNumber + 1, _derivedBidiClassName);
      missing.add(range);
      seenClasses.add(range.classId);
      if (range.start == 0 && range.end == _unicodeScalarLimit - 1 && range.classId == 0) {
        hasGlobalMissing = true;
      }
      continue;
    }
    if (original.startsWith('#')) continue;
    final content = original.split('#').first.trim();
    final recordMatch = _classRecordPattern.firstMatch(content);
    if (recordMatch == null) {
      throw FormatException('$_derivedBidiClassName:${lineNumber + 1} 无法解析：$original');
    }
    final range = _classRangeFromMatch(recordMatch, lineNumber + 1, _derivedBidiClassName);
    explicit.add(range);
    seenClasses.add(range.classId);
  }
  if (!hasGlobalMissing) {
    throw const FormatException('DerivedBidiClass.txt 缺少 0000..10FFFF 的 Left_To_Right @missing。');
  }
  if (seenClasses.length != _classNames.length) {
    final absent = <String>[
      for (var index = 0; index < _classNames.length; index++)
        if (!seenClasses.contains(index)) _classNames[index],
    ];
    throw FormatException('DerivedBidiClass.txt 未覆盖完整 23 类：${absent.join(', ')}');
  }

  final classes = Uint8List(_unicodeScalarLimit);
  for (final range in missing) {
    classes.fillRange(range.start, range.end + 1, range.classId);
  }
  final assigned = Uint8List(_unicodeScalarLimit);
  for (final range in explicit) {
    for (var rune = range.start; rune <= range.end; rune++) {
      if (assigned[rune] != 0) {
        throw FormatException('DerivedBidiClass.txt 显式区间重叠于 U+${_hex(rune, width: 4)}。');
      }
      assigned[rune] = 1;
    }
    classes.fillRange(range.start, range.end + 1, range.classId);
  }

  final encodedRanges = <int>[];
  var previous = -1;
  for (var rune = 0; rune < classes.length; rune++) {
    final classId = classes[rune];
    if (classId == previous) continue;
    encodedRanges.add((rune << 5) | classId);
    previous = classId;
  }
  return _BidiClassData(encodedRanges);
}

_ClassRange _classRangeFromMatch(RegExpMatch match, int lineNumber, String sourceName) {
  final start = _parseHex(match.group(1)!, sourceName, lineNumber);
  final end = match.group(2) == null ? start : _parseHex(match.group(2)!, sourceName, lineNumber);
  if (start > end || end >= _unicodeScalarLimit) {
    throw FormatException('$sourceName:$lineNumber 非法区间 U+${_hex(start)}..U+${_hex(end)}。');
  }
  final alias = match.group(3)!;
  final classId = _classAliases[alias];
  if (classId == null) throw FormatException('$sourceName:$lineNumber 未知 Bidi_Class：$alias');
  return _ClassRange(start: start, end: end, classId: classId);
}

Map<int, _RawBracket> _parseBrackets(String source) {
  final result = <int, _RawBracket>{};
  final lines = const LineSplitter().convert(source);
  for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
    final original = lines[lineNumber].trim();
    if (original.isEmpty || original.startsWith('#')) continue;
    final content = original.split('#').first.trim();
    final match = _bracketRecordPattern.firstMatch(content);
    if (match == null) throw FormatException('$_bidiBracketsName:${lineNumber + 1} 无法解析：$original');
    final rune = _parseHex(match.group(1)!, _bidiBracketsName, lineNumber + 1);
    if (rune >= _unicodeScalarLimit || _isSurrogate(rune)) {
      throw FormatException('$_bidiBracketsName:${lineNumber + 1} 非法 bracket rune U+${_hex(rune)}。');
    }
    final marker = match.group(3)!;
    if (marker == 'n') {
      if (match.group(2) != '<none>') {
        throw FormatException('$_bidiBracketsName:${lineNumber + 1} n 类型必须使用 <none> pair。');
      }
      continue;
    }
    if (match.group(2) == '<none>') {
      throw FormatException('$_bidiBracketsName:${lineNumber + 1} open/close 缺少 pair。');
    }
    final pair = _parseHex(match.group(2)!, _bidiBracketsName, lineNumber + 1);
    if (pair >= _unicodeScalarLimit || _isSurrogate(pair)) {
      throw FormatException('$_bidiBracketsName:${lineNumber + 1} 非法 pair U+${_hex(pair)}。');
    }
    if (result.containsKey(rune)) {
      throw FormatException('$_bidiBracketsName:${lineNumber + 1} 重复 bracket U+${_hex(rune)}。');
    }
    result[rune] = _RawBracket(rune: rune, pair: pair, open: marker == 'o');
  }
  if (result.isEmpty) throw const FormatException('BidiBrackets.txt 没有 open/close 记录。');
  for (final bracket in result.values) {
    final pair = result[bracket.pair];
    if (pair == null || pair.pair != bracket.rune || pair.open == bracket.open) {
      throw FormatException('BidiBrackets.txt pair 非对称：U+${_hex(bracket.rune)} ↔ U+${_hex(bracket.pair)}。');
    }
  }
  return result;
}

Map<int, int> _parseCanonicalDecompositions(String source) {
  final result = <int, int>{};
  final lines = const LineSplitter().convert(source);
  var records = 0;
  for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
    final line = lines[lineNumber];
    if (line.isEmpty) continue;
    final fields = line.split(';');
    if (fields.length != 15) {
      throw FormatException('$_unicodeDataName:${lineNumber + 1} 应有 15 个字段，实际 ${fields.length}。');
    }
    records++;
    final rune = _parseHex(fields[0], _unicodeDataName, lineNumber + 1);
    if (rune >= _unicodeScalarLimit) {
      throw FormatException('$_unicodeDataName:${lineNumber + 1} 非法 rune U+${_hex(rune)}。');
    }
    final decomposition = fields[5].trim();
    if (decomposition.isEmpty || decomposition.startsWith('<')) continue;
    final values = decomposition.split(RegExp(r'\s+'));
    if (values.length == 1) {
      result[rune] = _parseHex(values.single, _unicodeDataName, lineNumber + 1);
    }
  }
  if (records < 10000) throw const FormatException('UnicodeData.txt 记录数异常，拒绝生成不完整数据。');
  return result;
}

List<_ResolvedBracket> _resolveBrackets(Map<int, _RawBracket> brackets, Map<int, int> canonical) {
  int canonicalRune(int rune) {
    final visited = <int>{};
    var current = rune;
    while (true) {
      final next = canonical[current];
      if (next == null) break;
      if (!visited.add(current)) throw FormatException('UnicodeData.txt canonical decomposition 出现环：U+${_hex(rune)}。');
      current = next;
    }
    return current;
  }

  final result = <_ResolvedBracket>[];
  for (final bracket in brackets.values) {
    final canonicalSelf = canonicalRune(bracket.rune);
    if (!brackets.containsKey(canonicalSelf) || brackets[canonicalSelf]!.open != bracket.open) {
      throw FormatException('bracket U+${_hex(bracket.rune)} 的 canonical U+${_hex(canonicalSelf)} 类型不一致。');
    }
    final openRune = bracket.open ? bracket.rune : bracket.pair;
    final canonicalOpen = canonicalRune(openRune);
    final canonicalOpenRecord = brackets[canonicalOpen];
    if (canonicalOpenRecord == null || !canonicalOpenRecord.open) {
      throw FormatException('bracket U+${_hex(bracket.rune)} 无法解析 canonical open。');
    }
    result.add(
      _ResolvedBracket(rune: bracket.rune, pair: bracket.pair, canonicalOpen: canonicalOpen, open: bracket.open),
    );
  }
  result.sort((left, right) => left.rune.compareTo(right.rune));
  return result;
}

String _emitSource(_BidiClassData classData, List<_ResolvedBracket> brackets) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Unicode $_unicodeVersion / UAX #9 revision 51 bidirectional data.')
    ..writeln('// Sources:')
    ..writeln('// - $_derivedBidiClassUrl')
    ..writeln('// - $_bidiBracketsUrl')
    ..writeln('// - $_unicodeDataUrl (canonical bracket equivalence only)')
    ..writeln('//')
    ..writeln('// Unicode data is distributed under the Unicode License v3:')
    ..writeln('// https://www.unicode.org/license.txt')
    ..writeln('// Copyright © 1991-2025 Unicode, Inc. All rights reserved.')
    ..writeln()
    ..writeln('/// Unicode 17 `Bidi_Class` 的完整 23 个规范值。')
    ..writeln('enum UnicodeBidiClass {');
  for (var index = 0; index < _classNames.length; index++) {
    out
      ..writeln('  /// ${_classDocs[index]}.')
      ..writeln('  ${_classNames[index]},');
    if (index + 1 < _classNames.length) out.writeln();
  }
  out
    ..writeln('}')
    ..writeln()
    ..writeln('/// Unicode `Bidi_Paired_Bracket_Type` 的非空取值。')
    ..writeln('enum UnicodeBidiBracketType {')
    ..writeln('  /// Opening bracket (o).')
    ..writeln('  open,')
    ..writeln()
    ..writeln('  /// Closing bracket (c).')
    ..writeln('  close,')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Unicode 双向配对括号及 BD16 canonical opening identity。')
    ..writeln('final class UnicodeBidiBracket {')
    ..writeln('  /// 创建一条不可变的生成数据记录。')
    ..writeln('  const UnicodeBidiBracket({required this.pair, required this.canonicalOpen, required this.type});')
    ..writeln()
    ..writeln('  /// `Bidi_Paired_Bracket` 指向的另一端 code point。')
    ..writeln('  final int pair;')
    ..writeln()
    ..writeln('  /// 按 canonical decomposition 归一后的 opening code point。')
    ..writeln('  final int canonicalOpen;')
    ..writeln()
    ..writeln('  /// 当前 code point 是 opening 还是 closing bracket。')
    ..writeln('  final UnicodeBidiBracketType type;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// 返回 Unicode scalar [rune] 的规范 `Bidi_Class`。')
    ..writeln('///')
    ..writeln('/// 非 Unicode scalar（负数、超出 U+10FFFF 或 surrogate）严格抛出 [RangeError]。')
    ..writeln('UnicodeBidiClass unicodeBidiClassOf(int rune) {')
    ..writeln('  _checkUnicodeBidiRune(rune);')
    ..writeln('  var low = 0;')
    ..writeln('  var high = _unicodeBidiRanges.length;')
    ..writeln('  while (low < high) {')
    ..writeln('    final middle = low + ((high - low) >> 1);')
    ..writeln('    if ((_unicodeBidiRanges[middle] >> 5) <= rune) {')
    ..writeln('      low = middle + 1;')
    ..writeln('    } else {')
    ..writeln('      high = middle;')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('  return UnicodeBidiClass.values[_unicodeBidiRanges[low - 1] & 0x1f];')
    ..writeln('}')
    ..writeln()
    ..writeln('/// 返回 Unicode scalar [rune] 的 paired-bracket 数据；非括号返回 null。')
    ..writeln('///')
    ..writeln('/// 非 Unicode scalar（负数、超出 U+10FFFF 或 surrogate）严格抛出 [RangeError]。')
    ..writeln('UnicodeBidiBracket? unicodeBidiBracketOf(int rune) {')
    ..writeln('  _checkUnicodeBidiRune(rune);')
    ..writeln('  var low = 0;')
    ..writeln('  var high = _unicodeBidiBracketRunes.length;')
    ..writeln('  while (low < high) {')
    ..writeln('    final middle = low + ((high - low) >> 1);')
    ..writeln('    final candidate = _unicodeBidiBracketRunes[middle];')
    ..writeln('    if (candidate < rune) {')
    ..writeln('      low = middle + 1;')
    ..writeln('    } else {')
    ..writeln('      high = middle;')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('  return low < _unicodeBidiBracketRunes.length && _unicodeBidiBracketRunes[low] == rune')
    ..writeln('      ? _unicodeBidiBrackets[low]')
    ..writeln('      : null;')
    ..writeln('}')
    ..writeln()
    ..writeln('void _checkUnicodeBidiRune(int rune) {')
    ..writeln('  if (rune < 0 || rune > 0x10ffff || (rune >= 0xd800 && rune <= 0xdfff)) {')
    ..writeln("    throw RangeError.value(rune, 'rune', '必须是 Unicode scalar value');")
    ..writeln('  }')
    ..writeln('}')
    ..writeln()
    ..writeln('// 每项编码为 `(rangeStart << 5) | UnicodeBidiClass.index`。')
    ..writeln('const List<int> _unicodeBidiRanges = <int>[');
  _writeValues(out, classData.encodedRanges, (value) => '0x${value.toRadixString(16)}');
  out
    ..writeln('];')
    ..writeln()
    ..writeln('const List<int> _unicodeBidiBracketRunes = <int>[');
  _writeValues(out, [for (final bracket in brackets) bracket.rune], (value) => '0x${value.toRadixString(16)}');
  out
    ..writeln('];')
    ..writeln()
    ..writeln('const List<UnicodeBidiBracket> _unicodeBidiBrackets = <UnicodeBidiBracket>[');
  for (final bracket in brackets) {
    out.writeln(
      '  UnicodeBidiBracket(pair: 0x${bracket.pair.toRadixString(16)}, '
      'canonicalOpen: 0x${bracket.canonicalOpen.toRadixString(16)}, '
      'type: UnicodeBidiBracketType.${bracket.open ? 'open' : 'close'}),',
    );
  }
  out.writeln('];');
  return out.toString();
}

void _writeValues(StringBuffer out, List<int> values, String Function(int value) format) {
  for (final value in values) {
    out.writeln('  ${format(value)},');
  }
}

void _requireVersionHeader(String source, String expected, String sourceName) {
  if (!source.startsWith('# $expected\n') && !source.startsWith('# $expected\r\n')) {
    throw FormatException('$sourceName 不是固定的 Unicode $_unicodeVersion 数据。');
  }
}

int _parseHex(String value, String sourceName, int lineNumber) {
  final parsed = int.tryParse(value.trim(), radix: 16);
  if (parsed == null) throw FormatException('$sourceName:$lineNumber 非法十六进制：$value');
  return parsed;
}

bool _isSurrogate(int rune) => rune >= 0xd800 && rune <= 0xdfff;

String _hex(int value, {int width = 0}) => value.toRadixString(16).toUpperCase().padLeft(width, '0');

Future<_SourceBundle> _downloadSources() async {
  final client = HttpClient();
  try {
    final values = await Future.wait([
      _download(client, _derivedBidiClassUrl),
      _download(client, _bidiBracketsUrl),
      _download(client, _unicodeDataUrl),
    ]);
    return _SourceBundle(derivedBidiClass: values[0], bidiBrackets: values[1], unicodeData: values[2]);
  } finally {
    client.close(force: true);
  }
}

Future<String> _download(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  request.headers.set(HttpHeaders.userAgentHeader, 'el_ui Unicode bidi data generator');
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('下载失败：HTTP ${response.statusCode}', uri: Uri.parse(url));
  }
  return response.transform(utf8.decoder).join();
}

Future<_SourceBundle> _readSources(Directory directory) async {
  Future<String> read(String relative) async {
    final file = File('${directory.path}${Platform.pathSeparator}$relative');
    if (!await file.exists()) throw ArgumentError.value(directory.path, '--ucd-dir', '缺少 $relative');
    return file.readAsString();
  }

  Future<String> readDerivedBidiClass() async {
    final extracted = File(
      '${directory.path}${Platform.pathSeparator}extracted${Platform.pathSeparator}$_derivedBidiClassName',
    );
    if (await extracted.exists()) return extracted.readAsString();
    return read(_derivedBidiClassName);
  }

  return _SourceBundle(
    derivedBidiClass: await readDerivedBidiClass(),
    bidiBrackets: await read(_bidiBracketsName),
    unicodeData: await read(_unicodeDataName),
  );
}

File _defaultOutputFile() {
  final packageRoot = File.fromUri(Platform.script).parent.parent;
  return File(
    '${packageRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}cores'
    '${Platform.pathSeparator}editable${Platform.pathSeparator}render${Platform.pathSeparator}bidi'
    '${Platform.pathSeparator}unicode_bidi_data.g.dart',
  );
}

final class _GeneratorOptions {
  const _GeneratorOptions({this.ucdDirectory, this.output, required this.check, required this.help});

  factory _GeneratorOptions.parse(List<String> arguments) {
    Directory? ucdDirectory;
    File? output;
    var check = false;
    var help = false;
    for (var index = 0; index < arguments.length; index++) {
      switch (arguments[index]) {
        case '--ucd-dir':
          if (++index >= arguments.length) throw const FormatException('--ucd-dir 缺少目录参数。');
          ucdDirectory = Directory(arguments[index]);
        case '--output':
          if (++index >= arguments.length) throw const FormatException('--output 缺少文件参数。');
          output = File(arguments[index]);
        case '--check':
          check = true;
        case '--help' || '-h':
          help = true;
        default:
          throw FormatException('未知参数：${arguments[index]}');
      }
    }
    return _GeneratorOptions(ucdDirectory: ucdDirectory, output: output, check: check, help: help);
  }

  final Directory? ucdDirectory;
  final File? output;
  final bool check;
  final bool help;
}

final class _SourceBundle {
  const _SourceBundle({required this.derivedBidiClass, required this.bidiBrackets, required this.unicodeData});

  final String derivedBidiClass;
  final String bidiBrackets;
  final String unicodeData;
}

final class _ClassRange {
  const _ClassRange({required this.start, required this.end, required this.classId});

  final int start;
  final int end;
  final int classId;
}

final class _BidiClassData {
  const _BidiClassData(this.encodedRanges);

  final List<int> encodedRanges;
}

final class _RawBracket {
  const _RawBracket({required this.rune, required this.pair, required this.open});

  final int rune;
  final int pair;
  final bool open;
}

final class _ResolvedBracket {
  const _ResolvedBracket({required this.rune, required this.pair, required this.canonicalOpen, required this.open});

  final int rune;
  final int pair;
  final int canonicalOpen;
  final bool open;
}
