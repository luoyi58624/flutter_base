import 'dart:async';

import 'package:flutter_base/dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('直接创建的串行队列承接同步异常并继续后续任务', () async {
    final queue = ElSerialTaskQueue();
    final first = queue.run<int>(() => throw StateError('sync'));
    final failure = expectLater(first, throwsStateError);
    final second = queue.run(() => 42);
    await failure;
    expect(await second, 42);
  });
}
