import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_bidi_index.dart';
import 'package:flutter_base/src/ui/cores/editable/render/bidi/unicode_bidi_data.g.dart';
import 'package:flutter_test/flutter_test.dart';

const _classNames = <String>[
  'L',
  'R',
  'AL',
  'EN',
  'ES',
  'ET',
  'AN',
  'CS',
  'NSM',
  'BN',
  'B',
  'S',
  'WS',
  'ON',
  'LRE',
  'LRO',
  'RLE',
  'RLO',
  'PDF',
  'LRI',
  'RLI',
  'FSI',
  'PDI',
];

final Map<String, int> _classIds = <String, int>{
  for (var index = 0; index < _classNames.length; index++) _classNames[index]: index,
};

void main() {
  test('Unicode 17 BidiTest：全部 class 序列的 levels 与 L2 order 零偏差', () {
    final lines = const LineSplitter().convert(_readFixture('BidiTest.txt.gz'));
    var expectedLevels = const <String>[];
    var expectedOrder = const <int>[];
    var cases = 0;
    final failures = <String>[];

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex].trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('@Levels:')) {
        final body = line.substring('@Levels:'.length).trim();
        expectedLevels = body.isEmpty ? const <String>[] : body.split(RegExp(r'\s+'));
        continue;
      }
      if (line.startsWith('@Reorder:')) {
        final body = line.substring('@Reorder:'.length).trim();
        expectedOrder = body.isEmpty ? const <int>[] : body.split(RegExp(r'\s+')).map(int.parse).toList();
        continue;
      }
      if (line.startsWith('@')) continue;

      final separator = line.indexOf(';');
      if (separator < 0) continue;
      final tokens = line.substring(0, separator).trim().split(RegExp(r'\s+'));
      final classes = Uint8List(tokens.length);
      for (var index = 0; index < tokens.length; index++) {
        final classId = _classIds[tokens[index]];
        if (classId == null) throw FormatException('BidiTest L${lineIndex + 1} 未知 class：${tokens[index]}');
        classes[index] = classId;
      }
      final bitset = int.parse(line.substring(separator + 1).trim());
      for (final (bit, explicitLevel) in const [(1, -1), (2, 0), (4, 1)]) {
        if (bitset & bit == 0) continue;
        cases++;
        final paragraphLevel = explicitLevel < 0 ? baseLevelForTypesForTesting(classes) : explicitLevel;
        final result = resolveLongLineBidiTypesForTesting(classes, paragraphLevel: paragraphLevel);
        final levelsMatch = _levelsMatch(expectedLevels, result.levels, result.removed);
        final orderMatch = _intsMatch(expectedOrder, result.visualOrder);
        if (levelsMatch && orderMatch) continue;
        if (failures.length < 20) {
          failures.add(
            'L${lineIndex + 1} dir=$bit input=${tokens.join(' ')}\n'
            '  levels expected=${expectedLevels.join(' ')} actual=${_formatLevels(result.levels, result.removed)}\n'
            '  order  expected=${expectedOrder.join(' ')} actual=${result.visualOrder.join(' ')}',
          );
        }
      }
    }

    expect(cases, greaterThan(700000));
    if (failures.isNotEmpty) fail('${failures.length} sampled BidiTest failures:\n${failures.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('Unicode 17 BidiCharacterTest：全部真实 code point 的段落 level、levels 与视觉顺序零偏差', () {
    final lines = const LineSplitter().convert(_readFixture('BidiCharacterTest.txt.gz'));
    var cases = 0;
    final failures = <String>[];

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex].trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final fields = line.split(';');
      if (fields.length < 5) continue;
      final codePoints = fields[0].trim().split(RegExp(r'\s+')).map((value) => int.parse(value, radix: 16)).toList();
      final direction = int.parse(fields[1].trim());
      final expectedParagraphLevel = int.parse(fields[2].trim());
      final expectedLevels = fields[3].trim().split(RegExp(r'\s+'));
      final orderBody = fields[4].trim();
      final expectedOrder = orderBody.isEmpty ? const <int>[] : orderBody.split(RegExp(r'\s+')).map(int.parse).toList();
      final classes = Uint8List.fromList([for (final codePoint in codePoints) unicodeBidiClassOf(codePoint).index]);
      final paragraphLevel = switch (direction) {
        0 => 0,
        1 => 1,
        2 => baseLevelForTypesForTesting(classes),
        _ => throw FormatException('BidiCharacterTest L${lineIndex + 1} 非法 paragraph direction：$direction'),
      };
      final text = String.fromCharCodes(codePoints);
      final result = LongLineBidiIndex.resolve(
        text,
        baseDirection: paragraphLevel == 0 ? LongLineBidiBaseDirection.ltr : LongLineBidiBaseDirection.rtl,
      );
      final atomStarts = Int32List(codePoints.length);
      final startToAtom = Int32List(text.length)..fillRange(0, text.length, -1);
      var offset = 0;
      for (var atom = 0; atom < codePoints.length; atom++) {
        atomStarts[atom] = offset;
        startToAtom[offset] = atom;
        offset += codePoints[atom] > 0xffff ? 2 : 1;
      }
      final actualOrder = <int>[];
      for (var visual = 0; visual < result.visualCodeUnitLength; visual++) {
        final logical = result.visualToLogical[visual];
        final atom = startToAtom[logical];
        if (atom >= 0) actualOrder.add(atom);
      }

      cases++;
      final levelsMatch = _atomLevelsMatch(expectedLevels, atomStarts, result.levels, result.x9Removed);
      final orderMatch = _intsMatch(expectedOrder, actualOrder);
      if (paragraphLevel == expectedParagraphLevel && levelsMatch && orderMatch) continue;
      if (failures.length < 20) {
        failures.add(
          'L${lineIndex + 1} input=${fields[0].trim()}\n'
          '  para  expected=$expectedParagraphLevel actual=$paragraphLevel\n'
          '  levels expected=${expectedLevels.join(' ')} actual=${_formatAtomLevels(atomStarts, result.levels, result.x9Removed)}\n'
          '  order  expected=${expectedOrder.join(' ')} actual=${actualOrder.join(' ')}',
        );
      }
    }

    expect(cases, greaterThan(90000));
    if (failures.isNotEmpty) fail('${failures.length} sampled BidiCharacterTest failures:\n${failures.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

String _readFixture(String name) {
  final relative = 'fixtures${Platform.pathSeparator}unicode_bidi_17${Platform.pathSeparator}$name';
  final candidates = <File>[
    File.fromUri(Platform.script.resolve(relative.replaceAll(Platform.pathSeparator, '/'))),
    File(
      'test${Platform.pathSeparator}ui${Platform.pathSeparator}cores${Platform.pathSeparator}editable${Platform.pathSeparator}$relative',
    ),
  ];
  final file = candidates.firstWhere((candidate) => candidate.existsSync(), orElse: () => candidates.first);
  return utf8.decode(gzip.decode(file.readAsBytesSync()), allowMalformed: false);
}

bool _levelsMatch(List<String> expected, Uint8List levels, Uint8List removed) {
  if (expected.length != levels.length || removed.length != levels.length) return false;
  for (var index = 0; index < levels.length; index++) {
    final value = expected[index];
    if (value == 'x') {
      if (removed[index] == 0) return false;
    } else if (removed[index] != 0 || int.parse(value) != levels[index]) {
      return false;
    }
  }
  return true;
}

bool _atomLevelsMatch(List<String> expected, Int32List starts, Uint8List levels, Uint8List removed) {
  if (expected.length != starts.length) return false;
  for (var atom = 0; atom < starts.length; atom++) {
    final offset = starts[atom];
    final value = expected[atom];
    if (value == 'x') {
      if (removed[offset] == 0) return false;
    } else if (removed[offset] != 0 || int.parse(value) != levels[offset]) {
      return false;
    }
  }
  return true;
}

bool _intsMatch(List<int> expected, Iterable<int> actual) {
  final values = actual is List<int> ? actual : actual.toList(growable: false);
  if (expected.length != values.length) return false;
  for (var index = 0; index < expected.length; index++) {
    if (expected[index] != values[index]) return false;
  }
  return true;
}

String _formatLevels(Uint8List levels, Uint8List removed) =>
    <String>[for (var index = 0; index < levels.length; index++) removed[index] == 0 ? '${levels[index]}' : 'x']
        .join(' ');

String _formatAtomLevels(Int32List starts, Uint8List levels, Uint8List removed) =>
    <String>[for (final offset in starts) removed[offset] == 0 ? '${levels[offset]}' : 'x'].join(' ');
