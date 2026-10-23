import 'dart:typed_data';

import 'package:flutter_base/dart.dart';
import 'package:test/test.dart';

enum _Color { red, green, blue }

void main() {
  group('ElEnumSerialize', () {
    const s = ElEnumSerialize(_Color.values);

    test('按 name 编解码', () {
      expect(s.serialize(_Color.green), 'green');
      expect(s.deserialize('blue'), _Color.blue);
    });

    test('null 与未知值返回 null', () {
      expect(s.serialize(null), null);
      expect(s.deserialize(null), null);
      expect(s.deserialize('yellow'), null);
    });
  });

  group('ElDateTimeIso8601Serialize', () {
    const s = ElDateTimeIso8601Serialize();

    test('ISO8601 往返', () {
      final dt = DateTime(2026, 7, 10, 12, 30, 45, 123);
      expect(s.deserialize(s.serialize(dt)), dt);
    });

    test('兼容任意 DateTime.parse 支持的格式', () {
      expect(s.deserialize('2026-07-10'), DateTime(2026, 7, 10));
    });

    test('null 与坏数据返回 null', () {
      expect(s.serialize(null), null);
      expect(s.deserialize(null), null);
      expect(s.deserialize('not a date'), null);
    });
  });

  group('ElUriSerialize', () {
    const s = ElUriSerialize();

    test('往返', () {
      final uri = Uri.parse('https://example.com/path?a=1#frag');
      expect(s.deserialize(s.serialize(uri)), uri);
    });

    test('null 处理', () {
      expect(s.serialize(null), null);
      expect(s.deserialize(null), null);
    });
  });

  group('ElBigIntSerialize', () {
    const s = ElBigIntSerialize();

    test('超出 int64 范围的往返', () {
      final big = BigInt.parse('123456789012345678901234567890');
      expect(s.deserialize(s.serialize(big)), big);
    });

    test('null 与坏数据返回 null', () {
      expect(s.serialize(null), null);
      expect(s.deserialize(null), null);
      expect(s.deserialize('abc'), null);
    });
  });

  group('ElUint8ListSerialize', () {
    const s = ElUint8ListSerialize();

    test('base64 往返', () {
      final bytes = Uint8List.fromList([0, 1, 2, 255, 128, 64]);
      expect(s.deserialize(s.serialize(bytes)), bytes);
    });

    test('null 与坏数据返回 null', () {
      expect(s.serialize(null), null);
      expect(s.deserialize(null), null);
      expect(s.deserialize('!!!not base64!!!'), null);
    });
  });

  group(r'$ElJsonUtil 集合元素级自定义序列化', () {
    test(r'$listCustom 逐个还原元素，坏元素跳过', () {
      final d1 = DateTime(2026, 1, 1);
      final json = {
        'dates': [d1.millisecondsSinceEpoch.toString(), 'bad', null],
      };
      final result = $ElJsonUtil.$listCustom<DateTime>(
        json,
        'dates',
        const ElDateTimeSerialize(),
      );
      expect(result, [d1]);
    });

    test(r'$setCustom / $mapCustom', () {
      final d1 = DateTime(2026, 2, 2);
      final ms = d1.millisecondsSinceEpoch.toString();
      expect(
        $ElJsonUtil.$setCustom<DateTime>(
          {
            's': [ms],
          },
          's',
          const ElDateTimeSerialize(),
        ),
        {d1},
      );
      expect(
        $ElJsonUtil.$mapCustom<DateTime>(
          {
            'm': {'k': ms},
          },
          'm',
          const ElDateTimeSerialize(),
        ),
        {'k': d1},
      );
    });

    test('编译期下划线 key 直传', () {
      final json = {'user_name': 'a'};
      expect($ElJsonUtil.$string(json, 'userName', 'user_name'), 'a');
      // key 与下划线 key 相同时只查一次
      expect($ElJsonUtil.$string(json, 'missing', 'missing'), null);
    });
  });

  group(r'$string 收窄', () {
    test('标量隐式转换保留', () {
      final json = {'n': 42, 'b': true};
      expect($ElJsonUtil.$string(json, 'n'), '42');
      expect($ElJsonUtil.$string(json, 'b'), 'true');
    });

    test('复合类型不再静默 toString', () {
      final json = {
        'm': {'a': 1},
        'l': [1, 2],
      };
      expect($ElJsonUtil.$string(json, 'm'), null);
      expect($ElJsonUtil.$string(json, 'l'), null);
    });
  });
}
