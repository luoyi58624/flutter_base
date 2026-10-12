import 'package:fake_async/fake_async.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('基础类型扩展与公开导出', () {
    test('可空对象只在有值时执行回调并返回结果', () {
      int? value;
      var calls = 0;
      expect(value.notBlankCallback((item) => calls++), isNull);
      expect(calls, 0);
      value = 3;
      expect(value.notBlankCallback((item) => item * 2), 6);
      expect(0.notBlankCallback((item) => item + 1), 1);
    });

    test('整数时长与扩展乘法可以通过主入口使用', () {
      expect(2.ms, Duration(milliseconds: 2));
      expect(2.ss, Duration(seconds: 2));
      expect(2.mm, Duration(minutes: 2));
      expect(2.hh, Duration(hours: 2));
      expect(2.dd, Duration(days: 2));
      // Duration 自身也有乘法，显式调用扩展以验证这次导出的 API。
      expect(ElDartDurationExt(Duration(milliseconds: 5)) * 3, 15.ms);
    });

    test('时长延迟在指定时间执行并传回异步回调结果', () {
      fakeAsync((time) {
        var called = false;
        int? result;
        10.ms
            .delay(() async {
              called = true;
              return 42;
            })
            .then((value) => result = value as int);
        time.elapse(9.ms);
        expect(called, isFalse);
        time.elapse(1.ms);
        time.flushMicrotasks();
        expect(called, isTrue);
        expect(result, 42);
      });
    });

    test('整数延迟支持省略回调，回调异常传给返回的 Future', () {
      fakeAsync((time) {
        var finished = false;
        Object? failure;
        5.delay().then((_) => finished = true);
        5
            .delay(() => throw StateError('delay'))
            .then<void>(
              (_) {},
              onError: (Object error) {
                failure = error;
              },
            );
        time.elapse(5.ms);
        time.flushMicrotasks();
        expect(finished, isTrue);
        expect(failure, isA<StateError>());
      });
    });

    test('颜色通道转换会四舍五入并限制到字节范围', () {
      expect((-1.0).floatToInt8, 0);
      expect(0.0.floatToInt8, 0);
      expect(0.5.floatToInt8, 128);
      expect(1.0.floatToInt8, 255);
      expect(2.0.floatToInt8, 255);
    });
  });

  group('列表、集合和可迭代对象扩展', () {
    test('列表比较保留顺序，集合比较不依赖顺序', () {
      expect([1, 2].eq([1, 2]), isTrue);
      expect([1, 2].neq([2, 1]), isTrue);
      expect([1, 2].eq([1]), isFalse);
      expect({1, 2}.eq({2, 1}), isTrue);
      expect({1, 2}.neq({1}), isTrue);
    });

    test('列表重复和元素间插入均不修改原始内容', () {
      final source = [1, 2];
      expect(source * 3, [1, 2, 1, 2, 1, 2]);
      expect(source * 0, isEmpty);
      expect(source.insertBetween(0), [1, 0, 2]);
      expect(source, [1, 2]);
      expect(<int>[].insertBetween(0), isEmpty);
      expect([1].insertBetween(0), [1]);
    });

    test('列表移动支持两个方向和指定替代元素', () {
      final items = [1, 2, 3];
      expect(items.move(0, 2), isTrue);
      expect(items, [2, 3, 1]);
      expect(items.move(2, 0), isTrue);
      expect(items, [1, 2, 3]);
      expect(items.move(0, 2, 9), isTrue);
      expect(items, [2, 3, 9]);
    });

    test('列表移动拒绝相同位置和越界索引，并保留原列表', () {
      final items = [1, 2, 3];
      expect(items.move(1, 1), isFalse);
      expect(items.move(-1, 0), isFalse);
      expect(items.move(0, -1), isFalse);
      expect(items.move(3, 0), isFalse);
      expect(items.move(0, 3), isFalse);
      expect(items, [1, 2, 3]);
    });

    test('循环取值支持越过列表长度并保持非正索引约定', () {
      final items = ['a', 'b', 'c'];
      expect(items.loopGetContent(-1), 'a');
      expect(items.loopGetContent(0), 'a');
      expect(items.loopGetContent(2), 'c');
      expect(items.loopGetContent(3), 'a');
      expect(items.loopGetContent(7), 'b');
      expect(() => <int>[].loopGetContent(0), throwsRangeError);
    });

    test('onlyOne 在一般 Iterable 上只统计非 null 元素', () {
      final values = <int?>[null, 1, null].where((_) => true);
      expect(values.onlyOne(), isTrue);
      expect(<int?>[1, 2, null].onlyOne(), isFalse);
      expect(<int?>[null, null].onlyOne(), isFalse);
      expect(<int?>[null, null].onlyOne(allowAllNull: true), isTrue);
      expect(<int?>[].onlyOne(allowAllNull: true), isTrue);
    });
  });

  group('映射扩展', () {
    test('Map 比较不依赖插入顺序，但区分键和对应的值', () {
      final source = {'a': 1, 'b': 2};
      expect(source.eq({'b': 2, 'a': 1}), isTrue);
      expect(source.neq({'a': 1, 'b': 3}), isTrue);
      expect(source.eq({'a': 1}), isFalse);
    });

    test('Map 过滤按条件与指定键创建新容器', () {
      final source = {'a': 1, 'b': 2, 'c': 3};
      final filtered = source.filter((key, value) => key != 'a' && value.isOdd);
      expect(filtered, {'c': 3});
      expect(source.filterFromKeys(['c', 'a']), {'c': 3, 'a': 1});
      expect(source.filterFromKeys([]), isEmpty);
      filtered['c'] = 9;
      expect(source['c'], 3);
    });

    test('Map 按值查询返回首次匹配键，无匹配返回 null', () {
      final source = {'first': 1, 'second': 1, 'third': 2};
      expect(source.getKeyByValue(1), 'first');
      expect(source.getKeyByValue(7), isNull);
    });

    test('Map 转 List 保持遍历顺序，转 Set 去除重复结果', () {
      final source = {'a': 1, 'b': 2, 'c': 2};
      expect(source.mapToList((key, value) => '$key=$value'), [
        'a=1',
        'b=2',
        'c=2',
      ]);
      expect(source.mapToSet((key, value) => value), {1, 2});
      expect(<String, int>{}.mapToList((key, value) => key), isEmpty);
      expect(<String, int>{}.mapToSet((key, value) => value), isEmpty);
    });
  });

  group('字符串扩展', () {
    test('首字母大小写与首尾字符删除保持其余字符', () {
      expect('hello'.firstUpperCase, 'Hello');
      expect('Hello'.firstLowerCase, 'hello');
      expect('A'.firstLowerCase, 'a');
      expect('abc'.removeFirstChar(), 'bc');
      expect('abc'.removeLastChar(), 'ab');
      expect('a'.removeFirstChar(), '');
      expect('a'.removeLastChar(), '');
      expect(''.removeFirstChar(), '');
      expect(''.removeLastChar(), '');
    });

    test('驼峰转换和首尾空白清理保持内部内容', () {
      expect('userName'.toUnderline, 'user_name');
      expect('userID'.toUnderline, 'user_id');
      expect('\t\n a  b \r\n'.clearFrontBackBlank, 'a  b');
      expect('\u00a0value\u00a0'.clearFrontBackBlank, 'value');
      expect(''.clearFrontBackBlank, '');
    });

    test('类型名称扩展保留简单泛型结构并识别无泛型名称', () {
      expect('List<int>?'.excludeGeneric, 'List');
      expect('UserModel<T>?'.excludeGeneric, 'UserModel');
      expect('List<List<int>>'.getGenericType, 'List<int>');
      expect('int'.getGenericType, isNull);
      expect('Map<String, int>'.getMapGenericType, (
        key: 'String',
        value: 'int',
      ));
      expect('Map<String>'.getMapGenericType, isNull);
      expect('Map'.getMapGenericType, isNull);
    });

    test('中文识别和插空格按 Unicode 码点处理代理对', () {
      expect('你好'.isTwoChineseCharacters, isTrue);
      expect('𠀀好'.isTwoChineseCharacters, isTrue);
      expect('你a'.isTwoChineseCharacters, isFalse);
      expect('你好呀'.isTwoChineseCharacters, isFalse);
      expect(''.isTwoChineseCharacters, isFalse);
      expect('𠀀好'.autoInsertSpace, '𠀀 好');
      expect('abc'.autoInsertSpace, 'abc');
      expect('A😀B'.insertSpaceBetweenChars, 'A 😀 B');
      expect(''.insertSpaceBetweenChars, '');
    });
  });

  group('函数耗时扩展', () {
    test('关闭统计仍执行函数但不输出日志', () {
      var calls = 0;
      var logs = 0;
      (() => calls++).time(
        enabled: false,
        log: (message, {title, config, stackTrace}) => logs++,
      );
      expect(calls, 1);
      expect(logs, 0);
    });

    test('计时日志携带前缀、标题和调用方堆栈', () {
      dynamic message;
      dynamic capturedTitle;
      StackTrace? trace;
      (() {}).time(
        debugLabel: 'extension',
        logPrefix: 'TEST ',
        log: (value, {title, config, stackTrace}) {
          message = value;
          capturedTitle = title;
          trace = stackTrace;
        },
      );
      expect(message, startsWith('TEST 耗时 '));
      expect(capturedTitle, 'extension');
      expect(trace, isNotNull);
      expect(
        ElLogConfig(methodCount: 1).formatStackTrace(trace),
        contains('extensions_test.dart'),
      );
    });

    test('阈值过滤只过滤日志，函数本身仍执行', () {
      var calls = 0;
      var logs = 0;
      (() => calls++).time(
        filterTime: Duration(days: 1),
        log: (message, {title, config, stackTrace}) => logs++,
      );
      expect(calls, 1);
      expect(logs, 0);
    });

    test('未提供日志函数时使用迁移后的 ElLog', () {
      final savedFilter = ElLogConfig.filterFun;
      var logs = 0;
      ElLogConfig.filterFun = (level) {
        expect(level, ElLogConfig.debug);
        logs++;
        return false;
      };
      try {
        (() {}).time();
        expect(logs, 1);
      } finally {
        ElLogConfig.filterFun = savedFilter;
      }
    });
  });
}
