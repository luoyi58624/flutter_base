import 'dart:async';

import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ElLogConfig savedConfig;

  late bool Function(int) savedFilter;

  setUp(() {
    savedConfig = ElLogConfig.defaultConfig;
    savedFilter = ElLogConfig.filterFun;
    ElLogConfig.defaultConfig = ElLogConfig(
      methodCount: 0,
      lineLength: 0,
      printTitle: true,
      autoWrap: false,
      color: AnsiColor.none(),
    );
    ElLogConfig.filterFun = (_) => true;
  });

  tearDown(() {
    ElLogConfig.defaultConfig = savedConfig;
    ElLogConfig.filterFun = savedFilter;
  });

  test('各日志入口独立输出并保留消息和标题', () {
    final levels = <int>[];
    ElLogConfig.filterFun = (level) {
      levels.add(level);
      return true;
    };
    final lines = _capture(() {
      ElLog.d('debug');
      ElLog.i({'answer': 42}, title: 'title');
      ElLog.s('success');
      ElLog.w('warning');
      ElLog.e('error');
    });
    expect(levels, [1000, 2000, 2001, 3000, 4000]);
    expect(lines, [
      'debug',
      'title',
      '{"answer":42}',
      'success',
      'warning',
      'error',
    ]);
  });

  test('被过滤的日志不执行惰性消息函数', () {
    var evaluated = false;
    ElLogConfig.filterFun = (level) => level >= ElLogConfig.warning;
    final lines = _capture(() {
      ElLog.i(() {
        evaluated = true;
        return 'hidden';
      });
      ElLog.w('visible');
    });
    expect(evaluated, isFalse);
    expect(lines, ['visible']);
  });

  test('日志首帧定位到调用方并允许隐藏包装层', () {
    ElLogConfig.defaultConfig = ElLogConfig.defaultConfig.copyWith(
      methodCount: 1,
    );
    final direct = _capture(_directLog).join('\n');
    expect(direct, contains('_directLog'));
    expect(direct, isNot(contains('ElLog.i')));
    final wrapped = _capture(_wrappedCaller).join('\n');
    expect(wrapped, contains('_wrappedCaller'));
    expect(wrapped, isNot(contains('_logWrapper')));
  });

  test('不可编码的对象可以通过字符串回退输出', () {
    final config = ElLogConfig(autoWrap: false);
    expect(
      config.stringifyMessage({'value': _Message()}),
      '{"value":"custom"}',
    );
  });
}

List<String> _capture(void Function() action) {
  final lines = <String>[];
  runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) => lines.add(line),
    ),
  );
  return lines;
}

void _directLog() => ElLog.i('message');

void _logWrapper() => ElLog.i('message', stackTrace: StackTrace.current);

void _wrappedCaller() => _logWrapper();

class _Message {
  @override
  String toString() => 'custom';
}
