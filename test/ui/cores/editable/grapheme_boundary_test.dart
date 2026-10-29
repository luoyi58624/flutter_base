import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:characters/characters.dart';
import 'package:flutter_base/src/ui/cores/editable/model/grapheme_boundary.dart';
import 'package:flutter_base/src/ui/cores/editable/model/text_document.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectMatchesCharacters(String text) {
  final document = TextDocument(text);
  for (var offset = 0; offset <= text.length; offset++) {
    final expected = CharacterRange.at(text, offset);
    final actual = textGraphemeRangeAt(document, offset, lowerBound: 0, upperBound: document.length);
    expect(actual.start, expected.stringBeforeLength, reason: 'start offset=$offset text=$text');
    expect(actual.end, text.length - expected.stringAfterLength, reason: 'end offset=$offset text=$text');
  }
}

void main() {
  test('分块文档边界与 characters UAX #29 结果逐 offset 一致', () {
    final regionalIndicators = List.generate(140, (index) => String.fromCharCode(0x1f1e6 + index % 26)).join();
    final cases = <String>[
      'ascii text',
      '😀e\u0301👨‍👩‍👧‍👦',
      '\u0600A\u1100\u1161\u11a8क्‍ष',
      '${'a' * 253}e\u0301${'b' * 260}',
      '${'a' * 253}$regionalIndicators${'b' * 260}',
      'x${'\u0301' * 600}y',
    ];
    for (final text in cases) {
      _expectMatchesCharacters(text);
    }
  });

  test('严格前后边界沿完整字素移动', () {
    const text = 'a😀e\u0301👨‍👩‍👧‍👦z';
    final document = TextDocument(text);
    final boundaries = <int>[0];
    var offset = 0;
    for (final grapheme in text.characters) {
      offset += grapheme.length;
      boundaries.add(offset);
    }

    for (var i = 0; i < boundaries.length; i++) {
      final current = boundaries[i];
      expect(
        previousTextGraphemeBoundary(document, current, lowerBound: 0, upperBound: document.length),
        i == 0 ? 0 : boundaries[i - 1],
      );
      expect(
        nextTextGraphemeBoundary(document, current, lowerBound: 0, upperBound: document.length),
        i == boundaries.length - 1 ? document.length : boundaries[i + 1],
      );
    }
  });

  test('普通长行只按固定块读取，不物化 caret 前缀', () {
    final document = TextDocument('x' * 1_000_000);
    TextDocument.debugMaxGetTextSpan = 0;

    final range = textGraphemeRangeAt(document, 900000, lowerBound: 0, upperBound: document.length);

    expect(range, (start: 900000, end: 900000));
    expect(TextDocument.debugMaxGetTextSpan, lessThanOrEqualTo(256));
  });
}
