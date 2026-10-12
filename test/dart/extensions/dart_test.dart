import 'package:fake_async/fake_async.dart';
import 'package:flutter_base/dart.dart';
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
        contains('dart_test.dart'),
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
