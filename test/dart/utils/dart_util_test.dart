import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_base/dart.dart';
import 'package:flutter_base/flutter_base.dart' as public_api;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('空值与类型转换', () {
    test('isEmpty: null / 空白字符串 / Iterable / Map', () {
      expect(ElDartUtil.isEmpty(null), true);
      expect(ElDartUtil.isEmpty('   '), true);
      expect(ElDartUtil.isEmpty([]), true);
      expect(ElDartUtil.isEmpty(<int>{}), true);
      expect(ElDartUtil.isEmpty({}), true);
    });

    test("isEmpty: 'null' 仅在 checkString=true 时为空", () {
      expect(ElDartUtil.isEmpty('null'), false);
      expect(ElDartUtil.isEmpty(' null ', checkString: true), true);
      expect(ElDartUtil.isEmpty('NULL', checkString: true), true);
    });

    test('safeString: 空值返回默认值', () {
      expect(ElDartUtil.safeString(null, 'x'), 'x');
      expect(ElDartUtil.safeString('  ', 'x'), 'x');
    });

    test('safeInt: double 不抛异常，字符串支持 trim', () {
      expect(ElDartUtil.safeInt(1.2), 1);
      expect(ElDartUtil.safeInt(' 12 '), 12);
      expect(ElDartUtil.safeInt('1.2', 9), 9);
    });

    test('safeDouble: int 转 double，字符串支持 trim', () {
      expect(ElDartUtil.safeDouble(2), 2.0);
      expect(ElDartUtil.safeDouble(' 1.25 '), 1.25);
      expect(ElDartUtil.safeDouble('x', 9.5), 9.5);
    });

    test('safeBool: 解析失败返回默认值，并支持 0/1', () {
      expect(ElDartUtil.safeBool('TRUE'), true);
      expect(ElDartUtil.safeBool('no', true), true);
      expect(ElDartUtil.safeBool('1'), true);
      expect(ElDartUtil.safeBool('0'), false);
      expect(ElDartUtil.safeBool(1), true);
      expect(ElDartUtil.safeBool(0), false);
    });

    test('泛型转换保留基础元素与键值类型', () {
      expect(
        ElDartUtil.dynamicToList<List<String>>(['a']),
        isA<List<String>>(),
      );
      expect(ElDartUtil.dynamicToSet<Set<int>>({1}), isA<Set<int>>());
      expect(
        ElDartUtil.dynamicToMap<Map<String, Object>>({'a': 1}),
        isA<Map<String, Object>>(),
      );
      expect(
        ElDartUtil.dynamicToMap<Map<int, String>>({1: 'a'}),
        isA<Map<int, String>>(),
      );
      expect(
        ElDartUtil.dynamicToMap<Map<bool, double>>({true: 1.5}),
        isA<Map<bool, double>>(),
      );
      expect(
        () => ElDartUtil.dynamicToList<List<int>>(['a']),
        throwsA(isA<TypeError>()),
      );
    });

    test('空值选项分别控制数值零和 null 文本', () {
      expect(ElDartUtil.isEmpty(0), isTrue);
      expect(ElDartUtil.isEmpty(0, checkNum: false), isFalse);
      expect(ElDartUtil.isEmpty(-1), isFalse);
      expect(ElDartUtil.isEmpty(false), isFalse);
      expect(ElDartUtil.isEmpty(Object()), isFalse);
      expect(ElDartUtil.isNotEmpty('null'), isFalse);
      expect(ElDartUtil.isNotEmpty('null', checkString: false), isTrue);
      expect(ElDartUtil.isNotEmpty(0, checkNum: false), isTrue);
      expect(ElDartUtil.isNotEmpty([1]), isTrue);
      expect(ElDartUtil.isNotEmpty({'a': 1}), isTrue);
    });

    test('字符串转换沿用空值默认策略，比较支持异类型输入', () {
      expect(ElDartUtil.safeString(0, 'fallback'), 'fallback');
      expect(ElDartUtil.safeString(false), 'false');
      expect(ElDartUtil.safeString(42), '42');
      expect(ElDartUtil.compareString(42, '42'), isTrue);
      expect(ElDartUtil.compareString(null, '  '), isTrue);
      expect(ElDartUtil.compareString('a', 'b'), isFalse);
    });

    test('数值容错处理 NaN、非法文本及不支持的输入类型', () {
      expect(ElDartUtil.safeInt(double.nan, 7), 7);
      expect(ElDartUtil.safeInt(-2.9), -2);
      expect(ElDartUtil.safeInt(true, 7), 7);
      expect(ElDartUtil.safeInt(null, 7), 7);
      expect(ElDartUtil.safeDouble(double.nan, 7.5), 7.5);
      expect(ElDartUtil.safeDouble(null, 7.5), 7.5);
      expect(ElDartUtil.safeDouble(false, 7.5), 7.5);
      expect(ElDartUtil.safeDouble('1e2'), 100);
      expect(ElDartUtil.safeBool(false, true), isFalse);
      expect(ElDartUtil.safeBool(-1), isTrue);
      expect(ElDartUtil.safeBool(null, true), isTrue);
      expect(ElDartUtil.safeBool(' 1 '), isTrue);
      expect(ElDartUtil.safeBool(' 0 '), isFalse);
    });

    test('基础类型检测不把集合和空值当成基础值', () {
      for (final value in <Object>['text', 1, 1.5, true]) {
        expect(ElDartUtil.isBaseType(value), isTrue);
      }
      for (final value in <Object?>[null, [], {}, DateTime(2026)]) {
        expect(ElDartUtil.isBaseType(value), isFalse);
      }
      for (final name in ['String', 'int', 'double', 'num', 'bool']) {
        expect(ElDartUtil.isBaseTypeString(name), isTrue);
      }
      expect(ElDartUtil.isBaseTypeString('List<int>'), isFalse);
      expect(ElDartUtil.isBaseTypeString('DateTime'), isFalse);
    });

    test('动态基础类型转换区分解析成功、原值和严格模式', () {
      expect(ElDartUtil.dynamicToBaseType('42'), 42);
      expect(ElDartUtil.dynamicToBaseType('1.5'), 1.5);
      expect(ElDartUtil.dynamicToBaseType('true'), isTrue);
      expect(ElDartUtil.dynamicToBaseType('false'), isFalse);
      expect(ElDartUtil.dynamicToBaseType('text', true), 'text');
      expect(ElDartUtil.dynamicToBaseType(42, true), 42);
      expect(ElDartUtil.dynamicToBaseType(1.5, true), 1.5);
      expect(ElDartUtil.dynamicToBaseType(true, true), isTrue);
      final source = {'value': 42};
      expect(ElDartUtil.dynamicToBaseType(source), same(source));
      expect(ElDartUtil.dynamicToBaseType(source, true), isNull);
      expect(ElDartUtil.dynamicToBaseType(null), isNull);
    });

    test('safeList 使用类型检查视图，非列表返回指定默认值', () {
      final fallback = <int>[7];
      expect(ElDartUtil.safeList<int>(null, fallback), same(fallback));
      expect(ElDartUtil.safeList<int>('not a list'), isEmpty);
      final source = <dynamic>[1, 2];
      final view = ElDartUtil.safeList<int>(source);
      expect(view, [1, 2]);
      source.add(3);
      expect(view, [1, 2, 3]);
      final invalid = ElDartUtil.safeList<int>(<dynamic>['wrong']);
      expect(() => invalid.first, throwsA(isA<TypeError>()));
    });

    test('从 JSON 动态列表转换后保留元素类型并复制容器', () {
      final raw = jsonDecode('[1,2,3]');
      final typed = ElDartUtil.dynamicToList<List<int>>(raw);
      expect(typed, isA<List<int>>());
      typed.add(4);
      expect(raw, [1, 2, 3]);
      expect(ElDartUtil.dynamicToList<List<dynamic>>([null, 1]), [null, 1]);
      expect(ElDartUtil.dynamicToList<List<Object>>([1, 'a']), [1, 'a']);
      expect(ElDartUtil.dynamicToList<List<double>>([1.5]), [1.5]);
      expect(ElDartUtil.dynamicToList<List<num>>([1, 1.5]), [1, 1.5]);
      expect(ElDartUtil.dynamicToList<List<bool>>([true]), [true]);
      expect(ElDartUtil.dynamicToList<List<int>>([]), isEmpty);
    });

    test('Set 转换保留基本类型和容器独立性', () {
      final raw = <dynamic>{'a', 'b'};
      final typed = ElDartUtil.dynamicToSet<Set<String>>(raw);
      typed.add('c');
      expect(raw, {'a', 'b'});
      expect(ElDartUtil.dynamicToSet<Set<dynamic>>({null, 1}), {null, 1});
      expect(ElDartUtil.dynamicToSet<Set<Object>>({1, 'a'}), {1, 'a'});
      expect(ElDartUtil.dynamicToSet<Set<double>>({1.5}), {1.5});
      expect(ElDartUtil.dynamicToSet<Set<num>>({1, 1.5}), {1, 1.5});
      expect(ElDartUtil.dynamicToSet<Set<bool>>({true}), {true});
      expect(ElDartUtil.dynamicToSet<Set<int>>(<dynamic>{}), isEmpty);
      expect(
        () => ElDartUtil.dynamicToSet<Set<int>>({'wrong'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('Map 转换支持 JSON 键值类型并拒绝不匹配的数据', () {
      final raw = jsonDecode('{"value":42}');
      final typed =
          ElDartUtil.dynamicToMap<Map<String, int>>(raw) as Map<String, int>;
      expect(typed, {'value': 42});
      typed['new'] = 7;
      expect(raw, {'value': 42});
      expect(
        ElDartUtil.dynamicToMap<Map<double, bool>>({1.5: true}),
        isA<Map<double, bool>>(),
      );
      expect(
        ElDartUtil.dynamicToMap<Map<num, num>>({1: 1.5, 2.5: 3}),
        isA<Map<num, num>>(),
      );
      expect(ElDartUtil.dynamicToMap<Map<dynamic, String>>({1: 'a'}), {1: 'a'});
      expect(ElDartUtil.dynamicToMap<Map<String, dynamic>>({'a': null}), {
        'a': null,
      });
      expect(
        () => ElDartUtil.dynamicToMap<Map<String, int>>({'a': 'wrong'}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => ElDartUtil.dynamicToMap<Map<String, int>>({1: 42}),
        throwsA(isA<TypeError>()),
      );
    });

    test('集合转换对错误的源容器类型报错', () {
      expect(
        () => ElDartUtil.dynamicToList<List<int>>({1}),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ElDartUtil.dynamicToSet<Set<int>>([1]),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ElDartUtil.dynamicToMap<Map<String, int>>([1]),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('版本比较', () {
    // 正常业务场景
    test('1.0.0-test < 1.1.0 → 需要更新', () {
      expect(ElDartUtil.compareVersion('1.0.0-test', '1.1.0'), true);
    });

    // 前缀 v / V
    test('v1.0.0 == 1.0.0 → 不更新', () {
      expect(ElDartUtil.compareVersion('v1.0.0', '1.0.0'), false);
    });

    test('V2.1.3 < 2.2.0 → 需要更新', () {
      expect(ElDartUtil.compareVersion('V2.1.3', '2.2.0'), true);
    });

    // 各种后缀
    test('1.0.0+1 == 1.0.0 → 不更新', () {
      expect(ElDartUtil.compareVersion('1.0.0+1', '1.0.0'), false);
    });

    test('1.0.0-beta+hotfix.2 < 1.0.1 → 需要更新', () {
      expect(ElDartUtil.compareVersion('1.0.0-beta+hotfix.2', '1.0.1'), true);
    });

    test('1.0.0-release < 1.0.0 → 不更新', () {
      expect(ElDartUtil.compareVersion('1.0.0-release', '1.0.0'), false);
    });

    // 版本段数不一致
    test('1 < 1.0.0 → 不更新', () {
      expect(ElDartUtil.compareVersion('1', '1.0.0'), false);
    });

    test('1.0 < 1.0.1 → 需要更新', () {
      expect(ElDartUtil.compareVersion('1.0', '1.0.1'), true);
    });

    test('1.0.0.0 < 1.0.0.1 → 需要更新', () {
      expect(ElDartUtil.compareVersion('1.0.0.0', '1.0.0.1'), true);
    });

    test('1.0.0.0.0 == 1 → 不更新', () {
      expect(ElDartUtil.compareVersion('1.0.0.0.0', '1'), false);
    });

    // 跨段大小比较
    test('1.9.9 < 2.0.0 → 需要更新', () {
      expect(ElDartUtil.compareVersion('1.9.9', '2.0.0'), true);
    });

    test('2.0.0 > 1.99.99 → 不更新', () {
      expect(ElDartUtil.compareVersion('2.0.0', '1.99.99'), false);
    });

    test('1.0.10 < 1.0.11 → 需要更新', () {
      expect(ElDartUtil.compareVersion('1.0.10', '1.0.11'), true);
    });

    test('1.0.99 < 1.0.100 → 需要更新', () {
      expect(ElDartUtil.compareVersion('1.0.99', '1.0.100'), true);
    });

    // 异常格式（容错）
    test('空字符串本地 < 1.0.0 → 需要更新', () {
      expect(ElDartUtil.compareVersion('', '1.0.0'), true);
    });

    test('1.0.0 > 空服务端 → 不更新', () {
      expect(ElDartUtil.compareVersion('1.0.0', ''), false);
    });

    test('null 字符串视为 0 → 需要更新', () {
      expect(ElDartUtil.compareVersion('null', '1.0.0'), true);
    });

    test('null 值视为 0 → 需要更新', () {
      expect(ElDartUtil.compareVersion(null, '1.0.0'), true);
    });

    test('服务端 null 值视为 0 → 不更新', () {
      expect(ElDartUtil.compareVersion('1.0.0', null), false);
    });

    test('带空白的 v 前缀版本 == 纯版本 → 不更新', () {
      expect(ElDartUtil.compareVersion('  v1.2.3  ', '  1.2.3 '), false);
    });

    test('数字类型 1 == 1.0.0 → 不更新', () {
      expect(ElDartUtil.compareVersion(1, '1.0.0'), false);
    });

    test('数字类型 1.0 < 1.0.1 → 需要更新', () {
      expect(ElDartUtil.compareVersion(1.0, '1.0.1'), true);
    });

    test('非字符串对象视为 0 → 需要更新', () {
      expect(ElDartUtil.compareVersion({'v': '1.0.0'}, '1.0.0'), true);
    });

    test('版本含字母乱码 < 1.0.0 → 需要更新', () {
      expect(ElDartUtil.compareVersion('a.b.c', '1.0.0'), true);
    });

    test('1.x.3 < 1.2.3 → 需要更新', () {
      expect(ElDartUtil.compareVersion('1.x.3', '1.2.3'), true);
    });

    // 前后都带 v 和后缀
    test('v1.2.3-beta == 1.2.3+1 → 不更新', () {
      expect(ElDartUtil.compareVersion('v1.2.3-beta', '1.2.3+1'), false);
    });

    test('V3.10.9-release < 3.11.0 → 需要更新', () {
      expect(ElDartUtil.compareVersion('V3.10.9-release', '3.11.0'), true);
    });

    // 超大版本号
    test('999.999.999 < 1000.0.0 → 需要更新', () {
      expect(ElDartUtil.compareVersion('999.999.999', '1000.0.0'), true);
    });
  });

  test('数值比较覆盖全部条件与字符串转换', () {
    for (final condition in ElCompareType.values) {
      expect(
        ElDartUtil.compareNum('2', 3, condition),
        elCompareMatch(condition, -1),
      );
      expect(
        ElDartUtil.compareNum('3', 3, condition),
        elCompareMatch(condition, 0),
      );
      expect(
        ElDartUtil.compareNum('4', 3, condition),
        elCompareMatch(condition, 1),
      );
    }
  });

  group('路径与格式判断', () {
    test('百分比、文件名与常见格式判断保留原行为', () {
      expect(ElDartUtil.parseRatio('80%'), 0.8);
      expect(ElDartUtil.formatSize(1024), '1.00KB');
      expect(ElDartUtil.getUrlFileName('https://example.com/a.png'), 'a.png');
      expect(
        ElDartUtil.getUrlFileNameNoExtension('https://example.com/a.png'),
        'a',
      );
      expect(ElDartUtil.getFileSuffix('a.png', keepDot: true), '.png');
      expect(ElDartUtil.isImage('a.png'), isTrue);
      expect(ElDartUtil.isEmail('hello@example.com'), isTrue);
      expect(ElDartUtil.hasMatch(null, '.'), isFalse);
      expect(ElDartUtil.joinParentPath('/a/', '/root'), '/root/a');
    });

    test('文件后缀支持缺失后缀和自定义类型列表', () {
      expect(ElDartUtil.getFileSuffix('README'), isNull);
      expect(ElDartUtil.getFileSuffix('a.tar.gz'), 'gz');
      expect(ElDartUtil.isImage('a.webp', ['webp']), isTrue);
      expect(ElDartUtil.isImage('a.txt'), isFalse);
      expect(ElDartUtil.isStaticImage('a.jpg'), isTrue);
      expect(ElDartUtil.isStaticImage('a.gif'), isFalse);
      expect(ElDartUtil.isStaticImage('a.webp', ['webp']), isTrue);
      expect(ElDartUtil.isVideo('a.mp4'), isTrue);
      expect(ElDartUtil.isVideo('a.custom', ['custom']), isTrue);
      expect(ElDartUtil.isVideo('a.txt'), isFalse);
      expect(ElDartUtil.isAudio('a.mp3'), isTrue);
      expect(ElDartUtil.isAudio('a.custom', ['custom']), isTrue);
      expect(ElDartUtil.isAudio('a.txt'), isFalse);
      expect(ElDartUtil.isPPT('a.pptx'), isTrue);
      expect(ElDartUtil.isPPT('a.txt'), isFalse);
      expect(ElDartUtil.isWord('a.docx'), isTrue);
      expect(ElDartUtil.isWord('a.txt'), isFalse);
      expect(ElDartUtil.isExcel('a.xlsx'), isTrue);
      expect(ElDartUtil.isExcel('a.txt'), isFalse);
    });

    test('邮箱、手机号和正则包含有效与无效输入', () {
      expect(ElDartUtil.isEmail('not-an-email'), isFalse);
      expect(ElDartUtil.isPhoneNumber('13800138000'), isTrue);
      expect(ElDartUtil.isPhoneNumber('123'), isFalse);
      expect(ElDartUtil.isPhoneNumber('12345678901234567'), isFalse);
      expect(ElDartUtil.isPhoneNumber('138abcdefgh'), isFalse);
      expect(ElDartUtil.hasMatch('abc123', r'\d+'), isTrue);
      expect(ElDartUtil.hasMatch('abc', r'\d+'), isFalse);
    });

    test('HTTP 前缀判断与端口移除覆盖普通地址和空地址', () {
      expect(ElDartUtil.isHttp('https://example.com'), isTrue);
      expect(ElDartUtil.isHttp('http://example.com'), isTrue);
      expect(ElDartUtil.isHttp('ftp://example.com'), isFalse);
      expect(
        ElDartUtil.removePortFromUrl('https://example.com:8443/path?q=yes'),
        'https://example.com/path?q=yes',
      );
      expect(
        ElDartUtil.removePortFromUrl('https://example.com/path'),
        'https://example.com/path',
      );
      expect(ElDartUtil.removePortFromUrl(''), '');
    });

    test('路径拼接只在提供父路径时移除末尾斜杠', () {
      expect(ElDartUtil.joinParentPath('/child/'), '/child/');
      expect(ElDartUtil.joinParentPath('/child', '/root'), '/root/child');
      expect(ElDartUtil.joinParentPath('/child/', '/root'), '/root/child');
    });

    test('大小显示包含零值、字节和跨单位边界', () {
      expect(ElDartUtil.formatSize(null), '0KB');
      expect(ElDartUtil.formatSize(''), '0KB');
      expect(ElDartUtil.formatSize(0), '0KB');
      expect(ElDartUtil.formatSize(1), '1.00B');
      expect(ElDartUtil.formatSize(1023), '1023.00B');
      expect(ElDartUtil.formatSize('1048576'), '1.00MB');
    });

    test('百分比解析包含零、负值和无效输入', () {
      expect(ElDartUtil.parseRatio('0%'), 0);
      expect(ElDartUtil.parseRatio('-25%'), -0.25);
      expect(ElDartUtil.parseRatio('12.5%'), 0.125);
      expect(() => ElDartUtil.parseRatio('invalid%'), throwsFormatException);
      expect(() => ElDartUtil.parseRatio('80'), throwsA(isA<AssertionError>()));
    });
  });

  group('日期', () {
    test('日期转换、比较和格式化保留原行为', () {
      final date = DateTime(2026, 10, 12, 14, 5, 6);
      final next = date.add(Duration(days: 2));
      expect(ElDartUtil.safeDate('bad', date), date);
      expect(ElDartUtil.safeDate(date.millisecondsSinceEpoch), date);
      expect(ElDartUtil.formatDate(date), '2026-10-12 14:05:06');
      expect(ElDartUtil.compareDate(date, next, ElCompareType.less), isTrue);
      expect(ElDartUtil.diffDay(next, date), 2);
      expect(ElDartUtil.millisecondToCountDown(61000), '01分01秒');
    });

    test('日期转换支持 DateTime、ISO 文本和时间戳', () {
      final date = DateTime.utc(2026, 10, 12, 1, 2, 3);
      expect(ElDartUtil.safeDate(date), same(date));
      expect(ElDartUtil.safeDate(date.toIso8601String()), date);
      expect(
        ElDartUtil.safeDate(date.millisecondsSinceEpoch).isAtSameMomentAs(date),
        isTrue,
      );
    });

    test('无法解析的日期可回退到日期对象或日期文本', () {
      final fallback = DateTime(2026, 10, 12);
      expect(ElDartUtil.safeDate(null, fallback), fallback);
      expect(
        ElDartUtil.safeDate('wrong', fallback.toIso8601String()),
        fallback,
      );
      expect(ElDartUtil.safeDate(Object(), fallback), fallback);
      final before = DateTime.now();
      final dates = [
        ElDartUtil.safeDate(null),
        ElDartUtil.safeDate('wrong', 'also wrong'),
        ElDartUtil.safeDate(Object(), Object()),
      ];
      final after = DateTime.now();
      for (final date in dates) {
        expect(date.isBefore(before), isFalse);
        expect(date.isAfter(after), isFalse);
      }
    });

    test('当前时间 getter 落在调用前后时间范围内', () {
      final before = DateTime.now();
      final milliseconds = ElDartUtil.currentMilliseconds;
      final microseconds = ElDartUtil.currentMicroseconds;
      final after = DateTime.now();
      expect(
        milliseconds,
        inInclusiveRange(
          before.millisecondsSinceEpoch,
          after.millisecondsSinceEpoch,
        ),
      );
      expect(
        microseconds,
        inInclusiveRange(
          before.microsecondsSinceEpoch,
          after.microsecondsSinceEpoch,
        ),
      );
    });

    test('日期比较区分相等、先后和缺失值', () {
      final first = DateTime(2026, 10, 12);
      final second = DateTime(2026, 10, 13);
      expect(ElDartUtil.compareDate(first.toIso8601String(), first), isTrue);
      expect(ElDartUtil.compareDate(second, first, ElCompareType.than), isTrue);
      expect(ElDartUtil.compareDate(null, first, ElCompareType.less), isTrue);
      expect(ElDartUtil.compareDate(first, null, ElCompareType.than), isTrue);
      expect(ElDartUtil.compareDate(null, null), isTrue);
      expect(
        ElDartUtil.compareDate('wrong', first, ElCompareType.less),
        isTrue,
      );
      expect(
        ElDartUtil.compareDate(first, 'wrong', ElCompareType.than),
        isTrue,
      );
      expect(ElDartUtil.compareDate('wrong', 'invalid'), isTrue);
      expect(() => ElDartUtil.compareDate(42, first), throwsException);
      expect(() => ElDartUtil.compareDate(first, 42), throwsException);
    });

    test('按比较条件选择原日期对象，差值保留正负方向', () {
      final first = DateTime.utc(2026, 10, 12);
      final second = first.add(Duration(hours: 36));
      expect(
        ElDartUtil.getCompareDate(first, second, ElCompareType.less),
        same(first),
      );
      expect(
        ElDartUtil.getCompareDate(first, second, ElCompareType.than),
        same(second),
      );
      expect(ElDartUtil.diffDate(second, first), 129600000);
      expect(ElDartUtil.diffDate(first, second), -129600000);
      expect(ElDartUtil.diffDay(second, first), 1);
      expect(ElDartUtil.diffDay(first, second), -1);
    });

    test('倒计时覆盖秒、分、时、天四种显示范围', () {
      expect(ElDartUtil.millisecondToCountDown(1000), '01秒');
      expect(ElDartUtil.millisecondToCountDown(60000), '01分00秒');
      expect(ElDartUtil.millisecondToCountDown(3600000), '01时00分00秒');
      expect(ElDartUtil.millisecondToCountDown(90061000), '1天01时01分01秒');
      expect(
        () => ElDartUtil.millisecondToCountDown(0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('日期模板支持短年份、单字符字段和三位毫秒', () {
      final date = DateTime(2026, 1, 2, 3, 4, 5, 123);
      expect(ElDartUtil.formatDate(date, 'yy-M-d H:m:s S'), '26-1-2 3:4:5 123');
      expect(
        ElDartUtil.formatDate(date, 'yyyy-MM-dd HH:mm:ss.SSS'),
        '2026-01-02 03:04:05.123',
      );
      expect(ElDartUtil.formatDate(date, '---'), '---');
    });
  });

  group('异步调度', () {
    test('防抖共享指定 key 并保留最后一次调用', () {
      fakeAsync((time) {
        final calls = <String>[];
        final key = Object();
        final first = ElDartUtil.debounce(
          () => calls.add('first'),
          20,
          key: key,
        );
        final second = ElDartUtil.debounce(
          () => calls.add('second'),
          20,
          key: key,
        );
        first();
        time.elapse(Duration(milliseconds: 10));
        second();
        time.elapse(Duration(milliseconds: 19));
        expect(calls, isEmpty);
        time.elapse(Duration(milliseconds: 1));
        expect(calls, ['second']);
      });
    });

    test('节流立即执行首次调用并支持最后一次补发', () {
      fakeAsync((time) {
        var calls = 0;
        final action = ElDartUtil.throttle(
          () => calls++,
          20,
          key: Object(),
          trailing: true,
        );
        action();
        action();
        expect(calls, 1);
        time.elapse(Duration(milliseconds: 20));
        expect(calls, 2);
        action();
        expect(calls, 3);
        time.elapse(Duration(milliseconds: 20));
      });
    });

    test('共享任务合并并发调用，完成后允许重新执行', () async {
      final key = Object();
      final gate = Completer<int>();
      var calls = 0;
      Future<int> task() {
        calls++;
        return gate.future;
      }

      final first = ElDartUtil.runShareTask(key, task);
      final second = ElDartUtil.runShareTask(key, task);
      expect(identical(first, second), isTrue);
      expect(calls, 1);
      gate.complete(42);
      expect(await first, 42);
      expect(await second, 42);
      await Future<void>.delayed(Duration.zero);
      expect(await ElDartUtil.runShareTask(key, () async => 43), 43);
    });

    test('共享任务异步失败传播给所有等待方并释放 key', () async {
      final key = Object();
      final gate = Completer<int>();
      final first = ElDartUtil.runShareTask(key, () => gate.future);
      final second = ElDartUtil.runShareTask(key, () async => 0);
      final firstFailure = expectLater(first, throwsStateError);
      final secondFailure = expectLater(second, throwsStateError);
      gate.completeError(StateError('shared'));
      await Future.wait([firstFailure, secondFailure]);
      await Future<void>.delayed(Duration.zero);
      expect(await ElDartUtil.runShareTask(key, () async => 42), 42);
    });

    test('防抖不同 key 独立，默认 key 按函数共享', () {
      fakeAsync((time) {
        var calls = 0;
        void callback() => calls++;
        final first = ElDartUtil.debounce(callback, 10);
        final second = ElDartUtil.debounce(callback, 10);
        first();
        second();
        time.elapse(Duration(milliseconds: 10));
        expect(calls, 1);
        ElDartUtil.debounce(callback, 10, key: Object())();
        ElDartUtil.debounce(callback, 10, key: Object())();
        time.elapse(Duration(milliseconds: 10));
        expect(calls, 3);
      });
    });

    test('节流默认不补发，窗口结束后可以重新执行', () {
      fakeAsync((time) {
        var calls = 0;
        void callback() => calls++;
        final first = ElDartUtil.throttle(callback, 10);
        final second = ElDartUtil.throttle(callback, 10);
        first();
        second();
        expect(calls, 1);
        time.elapse(Duration(milliseconds: 10));
        expect(calls, 1);
        second();
        expect(calls, 2);
        time.elapse(Duration(milliseconds: 10));
      });
    });

    test('节流不同 key 相互独立并合并尾部重复触发', () {
      fakeAsync((time) {
        final calls = <String>[];
        final first = ElDartUtil.throttle(
          () => calls.add('first'),
          20,
          key: Object(),
          trailing: true,
        );
        final second = ElDartUtil.throttle(
          () => calls.add('second'),
          20,
          key: Object(),
        );
        first();
        second();
        first();
        time.elapse(Duration(milliseconds: 5));
        first();
        time.elapse(Duration(milliseconds: 19));
        expect(calls, ['first', 'second']);
        time.elapse(Duration(milliseconds: 1));
        expect(calls, ['first', 'second', 'first']);
      });
    });

    test('防抖和节流拒绝非正等待时间', () {
      expect(
        () => ElDartUtil.debounce(() {}, 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ElDartUtil.debounce(() {}, -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ElDartUtil.throttle(() {}, 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ElDartUtil.throttle(() {}, -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('共享任务不同 key 并行执行，先完成者不阻塞另一项', () async {
      final firstGate = Completer<int>();
      final secondGate = Completer<int>();
      final first = ElDartUtil.runShareTask(Object(), () => firstGate.future);
      final second = ElDartUtil.runShareTask(Object(), () => secondGate.future);
      secondGate.complete(2);
      expect(await second, 2);
      firstGate.complete(1);
      expect(await first, 1);
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('编码', () {
    test('编码与压缩支持中文并保持往返一致', () {
      final text = '你好 Flutter Base 😀';
      expect(ElDartUtil.formBase64(ElDartUtil.toBase64(text)), text);
      expect(ElDartUtil.decodeString(ElDartUtil.encodeString(text)), text);
      expect(ElDartUtil.toMd5('hello'), '5d41402abc4b2a76b9719d911017c592');
      expect(ElDartUtil.uuidStr, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('Base64 和 GZip 包含空字符串及无效输入', () {
      expect(ElDartUtil.toBase64(''), '');
      expect(ElDartUtil.formBase64(''), '');
      expect(ElDartUtil.decodeString(ElDartUtil.encodeString('')), '');
      expect(() => ElDartUtil.formBase64('!invalid!'), throwsFormatException);
      expect(() => ElDartUtil.decodeString('!invalid!'), throwsFormatException);
    });

    test('MD5 盐值按约定追加到字符串末尾，UUID 去除分隔符', () {
      expect(
        ElDartUtil.toMd5('hel', salt: 'lo'),
        '5d41402abc4b2a76b9719d911017c592',
      );
      expect(ElDartUtil.toMd5(''), 'd41d8cd98f00b204e9800998ecf8427e');
      expect(
        ElDartUtil.uuid.v4(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(
        ElDartUtil.uuidStr,
        matches(RegExp(r'^[0-9a-f]{12}4[0-9a-f]{3}[89ab][0-9a-f]{15}$')),
      );
    });
  });

  test('默认入口导出独立的工具与日志 API', () {
    expect(public_api.ElDartUtil.safeInt('12'), 12);
    expect(public_api.ElLog.i, isA<public_api.ElLogFunction>());
    expect(public_api.ElLogConfig.info, 2000);
  });
}
