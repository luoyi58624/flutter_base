import 'package:flutter_base/src/ui/cores/editable/render/bidi/unicode_bidi_data.g.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_unicode_bidi_data.dart' as generator;

void main() {
  test('Unicode 17 Bidi_Class API 固定完整 23 类并覆盖各规范类别', () {
    expect(UnicodeBidiClass.values, const [
      UnicodeBidiClass.l,
      UnicodeBidiClass.r,
      UnicodeBidiClass.al,
      UnicodeBidiClass.en,
      UnicodeBidiClass.es,
      UnicodeBidiClass.et,
      UnicodeBidiClass.an,
      UnicodeBidiClass.cs,
      UnicodeBidiClass.nsm,
      UnicodeBidiClass.bn,
      UnicodeBidiClass.b,
      UnicodeBidiClass.s,
      UnicodeBidiClass.ws,
      UnicodeBidiClass.on,
      UnicodeBidiClass.lre,
      UnicodeBidiClass.lro,
      UnicodeBidiClass.rle,
      UnicodeBidiClass.rlo,
      UnicodeBidiClass.pdf,
      UnicodeBidiClass.lri,
      UnicodeBidiClass.rli,
      UnicodeBidiClass.fsi,
      UnicodeBidiClass.pdi,
    ]);

    const samples = <int, UnicodeBidiClass>{
      0x0041: UnicodeBidiClass.l,
      0x05d0: UnicodeBidiClass.r,
      0x0627: UnicodeBidiClass.al,
      0x0030: UnicodeBidiClass.en,
      0x002b: UnicodeBidiClass.es,
      0x0024: UnicodeBidiClass.et,
      0x0660: UnicodeBidiClass.an,
      0x002c: UnicodeBidiClass.cs,
      0x0300: UnicodeBidiClass.nsm,
      0x0000: UnicodeBidiClass.bn,
      0x000a: UnicodeBidiClass.b,
      0x0009: UnicodeBidiClass.s,
      0x0020: UnicodeBidiClass.ws,
      0x0021: UnicodeBidiClass.on,
      0x202a: UnicodeBidiClass.lre,
      0x202d: UnicodeBidiClass.lro,
      0x202b: UnicodeBidiClass.rle,
      0x202e: UnicodeBidiClass.rlo,
      0x202c: UnicodeBidiClass.pdf,
      0x2066: UnicodeBidiClass.lri,
      0x2067: UnicodeBidiClass.rli,
      0x2068: UnicodeBidiClass.fsi,
      0x2069: UnicodeBidiClass.pdi,
    };
    for (final MapEntry(key: rune, value: bidiClass) in samples.entries) {
      expect(unicodeBidiClassOf(rune), bidiClass, reason: 'U+${rune.toRadixString(16).toUpperCase()}');
    }
  });

  test('@missing 优先级、supplementary 与 Unicode 上边界均按官方数据解析', () {
    expect(unicodeBidiClassOf(0x0378), UnicodeBidiClass.l, reason: '全局 @missing 默认 L');
    expect(unicodeBidiClassOf(0x0590), UnicodeBidiClass.r, reason: 'Hebrew 未分配码点的特定 @missing');
    expect(unicodeBidiClassOf(0x10806), UnicodeBidiClass.r, reason: 'supplementary RTL @missing');
    expect(unicodeBidiClassOf(0x10d3a), UnicodeBidiClass.al, reason: 'supplementary Arabic @missing');
    expect(unicodeBidiClassOf(0x20c2), UnicodeBidiClass.et, reason: 'Currency Symbols @missing');
    expect(unicodeBidiClassOf(0x1e950), UnicodeBidiClass.r, reason: 'supplementary 显式 Adlam 数字');
    expect(unicodeBidiClassOf(0x1ee00), UnicodeBidiClass.al, reason: 'supplementary Arabic math letter');
    expect(unicodeBidiClassOf(0x1f600), UnicodeBidiClass.on);
    expect(unicodeBidiClassOf(0x10ffff), UnicodeBidiClass.bn);
  });

  test('paired bracket 双向对称并保留 BD16 canonical opening identity', () {
    expect(
      unicodeBidiBracketOf(0x28),
      isA<UnicodeBidiBracket>()
          .having((value) => value.pair, 'pair', 0x29)
          .having((value) => value.canonicalOpen, 'canonicalOpen', 0x28)
          .having((value) => value.type, 'type', UnicodeBidiBracketType.open),
    );
    expect(
      unicodeBidiBracketOf(0x29),
      isA<UnicodeBidiBracket>()
          .having((value) => value.pair, 'pair', 0x28)
          .having((value) => value.canonicalOpen, 'canonicalOpen', 0x28)
          .having((value) => value.type, 'type', UnicodeBidiBracketType.close),
    );
    expect(
      unicodeBidiBracketOf(0x2329),
      isA<UnicodeBidiBracket>()
          .having((value) => value.pair, 'pair', 0x232a)
          .having((value) => value.canonicalOpen, 'canonicalOpen', 0x3008)
          .having((value) => value.type, 'type', UnicodeBidiBracketType.open),
    );
    expect(
      unicodeBidiBracketOf(0x232a),
      isA<UnicodeBidiBracket>()
          .having((value) => value.pair, 'pair', 0x2329)
          .having((value) => value.canonicalOpen, 'canonicalOpen', 0x3008)
          .having((value) => value.type, 'type', UnicodeBidiBracketType.close),
    );
    expect(unicodeBidiBracketOf(0x41), isNull);
  });

  test('官方 128 条 paired bracket 全部双向闭合且共享 canonical open', () {
    var count = 0;
    for (var rune = 0; rune <= 0x10ffff; rune++) {
      if (rune >= 0xd800 && rune <= 0xdfff) continue;
      final bracket = unicodeBidiBracketOf(rune);
      if (bracket == null) continue;
      count++;
      final pair = unicodeBidiBracketOf(bracket.pair);
      expect(pair, isNotNull, reason: 'U+${rune.toRadixString(16)} pair 缺失');
      expect(pair!.pair, rune);
      expect(pair.type, isNot(bracket.type));
      expect(pair.canonicalOpen, bracket.canonicalOpen);
      final canonicalOpen = unicodeBidiBracketOf(bracket.canonicalOpen);
      expect(canonicalOpen?.type, UnicodeBidiBracketType.open);
      expect(canonicalOpen?.canonicalOpen, bracket.canonicalOpen);
    }
    expect(count, 128);
  });

  test('公开查表严格拒绝非 Unicode scalar', () {
    for (final invalid in const [-1, 0xd800, 0xdfff, 0x110000]) {
      expect(() => unicodeBidiClassOf(invalid), throwsRangeError);
      expect(() => unicodeBidiBracketOf(invalid), throwsRangeError);
    }
  });

  test('生成器严格拒绝版本漂移、未知类别、重叠区间与不对称 bracket', () {
    expect(
      () => generator.generateUnicodeBidiDataSource(
        derivedBidiClass: _derivedFixture.replaceFirst('17.0.0', '16.0.0'),
        bidiBrackets: _bracketFixture,
        unicodeData: _unicodeDataFixture,
      ),
      throwsFormatException,
    );
    expect(
      () => generator.generateUnicodeBidiDataSource(
        derivedBidiClass: '$_derivedFixture\n0020; UNKNOWN',
        bidiBrackets: _bracketFixture,
        unicodeData: _unicodeDataFixture,
      ),
      throwsFormatException,
    );
    expect(
      () => generator.generateUnicodeBidiDataSource(
        derivedBidiClass: '$_derivedFixture\n0000; L',
        bidiBrackets: _bracketFixture,
        unicodeData: _unicodeDataFixture,
      ),
      throwsFormatException,
    );
    expect(
      () => generator.generateUnicodeBidiDataSource(
        derivedBidiClass: _derivedFixture,
        bidiBrackets: _bracketFixture.replaceFirst('0029; 0028; c', '0029; 005B; c'),
        unicodeData: _unicodeDataFixture,
      ),
      throwsFormatException,
    );
  });

  test('生成器拒绝缺失全局 @missing、残缺 UnicodeData 与 surrogate bracket', () {
    expect(
      () => generator.generateUnicodeBidiDataSource(
        derivedBidiClass: _derivedFixture.replaceFirst('# @missing: 0000..10FFFF; Left_To_Right\n', ''),
        bidiBrackets: _bracketFixture,
        unicodeData: _unicodeDataFixture,
      ),
      throwsFormatException,
    );
    expect(
      () => generator.generateUnicodeBidiDataSource(
        derivedBidiClass: _derivedFixture,
        bidiBrackets: _bracketFixture,
        unicodeData: '0041;TEST;Lu;0;L;;;;;N;;;;;',
      ),
      throwsFormatException,
    );
    expect(
      () => generator.generateUnicodeBidiDataSource(
        derivedBidiClass: _derivedFixture,
        bidiBrackets: '$_bracketFixture\nD800; D801; o\nD801; D800; c',
        unicodeData: _unicodeDataFixture,
      ),
      throwsFormatException,
    );
  });
}

const _derivedFixture = '''# DerivedBidiClass-17.0.0.txt
# @missing: 0000..10FFFF; Left_To_Right
0000; L
0001; R
0002; AL
0003; EN
0004; ES
0005; ET
0006; AN
0007; CS
0008; NSM
0009; BN
000A; B
000B; S
000C; WS
000D; ON
000E; LRE
000F; LRO
0010; RLE
0011; RLO
0012; PDF
0013; LRI
0014; RLI
0015; FSI
0016; PDI
''';

const _bracketFixture = '''# BidiBrackets-17.0.0.txt
0028; 0029; o
0029; 0028; c
''';

final String _unicodeDataFixture = List<String>.generate(10000, (index) {
  final fields = <String>[
    index.toRadixString(16).toUpperCase().padLeft(4, '0'),
    'TEST',
    'Cn',
    '0',
    'L',
    '',
    '',
    '',
    '',
    'N',
    '',
    '',
    '',
    '',
    '',
  ];
  return fields.join(';');
}).join('\n');
