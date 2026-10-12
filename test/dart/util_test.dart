import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safe 方法测试', () {
    _safeTest();
  });

  group('版本对比测试', () {
    _compareVersionTest();
  });

  test('泛型转换保留基础元素与键值类型', () {
    expect(ElDartUtil.dynamicToList<List<String>>(['a']), isA<List<String>>());
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

  test('编码与压缩支持中文并保持往返一致', () {
    final text = '你好 Flutter Base 😀';
    expect(ElDartUtil.formBase64(ElDartUtil.toBase64(text)), text);
    expect(ElDartUtil.decodeString(ElDartUtil.encodeString(text)), text);
    expect(ElDartUtil.toMd5('hello'), '5d41402abc4b2a76b9719d911017c592');
    expect(ElDartUtil.uuidStr, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('定时器可取消且周期调用按时间推进', () {
    fakeAsync((time) {
      var calls = 0;
      setTimeout(() => calls++, 10).cancel();
      final interval = setInterval(() => calls++, 10);
      time.elapse(Duration(milliseconds: 35));
      expect(calls, 3);
      interval.cancel();
      time.elapse(Duration(milliseconds: 20));
      expect(calls, 3);
    });
  });

  test('防抖共享指定 key 并保留最后一次调用', () {
    fakeAsync((time) {
      final calls = <String>[];
      final key = Object();
      final first = ElDartUtil.debounce(() => calls.add('first'), 20, key: key);
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

  test('串行队列等待前项，前项失败后仍可继续', () async {
    final queue = ElDartUtil.serialQueue();
    final gate = Completer<void>();
    final calls = <int>[];
    final first = queue.run(() async {
      calls.add(1);
      await gate.future;
      throw StateError('first');
    });
    final failure = expectLater(first, throwsStateError);
    final second = queue.run(() {
      calls.add(2);
      return 42;
    });
    await Future<void>.delayed(Duration.zero);
    expect(calls, [1]);
    gate.complete();
    await failure;
    expect(await second, 42);
    expect(calls, [1, 2]);
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
}

void _safeTest() {
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
}

void _compareVersionTest() {
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
}
