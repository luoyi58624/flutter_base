import 'dart:async';

import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_bidi_executor_web.dart';
import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_cooperative_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('巨型 Web 解析严格串行，diagnostics 同时报告 active/queued 字节', () async {
    final firstStarted = Completer<void>();
    final firstRelease = Completer<void>();
    final secondStarted = Completer<void>();
    final secondRelease = Completer<void>();
    var concurrent = 0;
    var maximumConcurrent = 0;

    Future<void> held(Completer<void> started, Completer<void> release) async {
      concurrent++;
      maximumConcurrent = concurrent > maximumConcurrent ? concurrent : maximumConcurrent;
      started.complete();
      await release.future;
      concurrent--;
    }

    final first = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: longLineBidiWebExclusiveTaskBytes,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () => held(firstStarted, firstRelease),
    );
    await firstStarted.future;
    final second = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: longLineBidiWebExclusiveTaskBytes + 1,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () => held(secondStarted, secondRelease),
    );
    await Future<void>.delayed(Duration.zero);

    expect(longLineBidiExecutorDiagnostics(), (
      activeTasks: 1,
      activeBytes: longLineBidiWebExclusiveTaskBytes,
      queuedTasks: 1,
      queuedBytes: longLineBidiWebExclusiveTaskBytes + 1,
    ));
    expect(secondStarted.isCompleted, isFalse);
    firstRelease.complete();
    await first;
    await secondStarted.future;
    secondRelease.complete();
    await second;

    expect(maximumConcurrent, 1);
    expect(longLineBidiExecutorDiagnostics(), (activeTasks: 0, activeBytes: 0, queuedTasks: 0, queuedBytes: 0));
  });

  test('预算内小任务可并发，排队取消不会阻塞后继新代际', () async {
    final firstStarted = Completer<void>();
    final firstRelease = Completer<void>();
    final secondStarted = Completer<void>();
    final secondRelease = Completer<void>();
    const smallBytes = 32 * 1024 * 1024;

    final first = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: smallBytes,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () async {
        firstStarted.complete();
        await firstRelease.future;
      },
    );
    final second = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: smallBytes,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () async {
        secondStarted.complete();
        await secondRelease.future;
      },
    );
    await Future.wait(<Future<void>>[firstStarted.future, secondStarted.future]);
    expect(longLineBidiExecutorDiagnostics().activeTasks, 2);
    expect(longLineBidiExecutorDiagnostics().activeBytes, smallBytes * 2);
    firstRelease.complete();
    secondRelease.complete();
    await Future.wait(<Future<void>>[first, second]);

    final giantStarted = Completer<void>();
    final giantRelease = Completer<void>();
    final giant = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: longLineBidiWebExclusiveTaskBytes,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () async {
        giantStarted.complete();
        await giantRelease.future;
      },
    );
    await giantStarted.future;
    final staleToken = LongLineCooperativeCancellationToken();
    final stale = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: longLineBidiWebExclusiveTaskBytes,
      cancellationToken: staleToken,
      action: () async => fail('取消的排队任务不得执行'),
    );
    final staleExpectation = expectLater(stale, throwsA(isA<LongLineCooperativeCancelledException>()));
    final replacementStarted = Completer<void>();
    final replacement = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: smallBytes,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () async => replacementStarted.complete(),
    );
    staleToken.cancel();
    giantRelease.complete();
    await giant;
    await staleExpectation;
    await replacementStarted.future;
    await replacement;
    expect(longLineBidiExecutorDiagnostics(), (activeTasks: 0, activeBytes: 0, queuedTasks: 0, queuedBytes: 0));
  });

  test('单任务估算超过并发软预算时仍独占放行，后继必须排队', () async {
    final oversizedStarted = Completer<void>();
    final oversizedRelease = Completer<void>();
    final followerStarted = Completer<void>();
    final oversizedBytes = longLineBidiWebWorkingSetBudgetBytes + 1;
    final oversized = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: oversizedBytes,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () async {
        oversizedStarted.complete();
        await oversizedRelease.future;
      },
    );
    await oversizedStarted.future;
    final follower = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: 1,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () async => followerStarted.complete(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(longLineBidiExecutorDiagnostics(), (
      activeTasks: 1,
      activeBytes: oversizedBytes,
      queuedTasks: 1,
      queuedBytes: 1,
    ));
    expect(followerStarted.isCompleted, isFalse);

    oversizedRelease.complete();
    await oversized;
    await followerStarted.future;
    await follower;
    expect(longLineBidiExecutorDiagnostics(), (activeTasks: 0, activeBytes: 0, queuedTasks: 0, queuedBytes: 0));
  });

  test('exclusive blocker 不释放时，queued cancel 仍主动摘队并短界限完成', () async {
    final blockerStarted = Completer<void>();
    final blockerRelease = Completer<void>();
    final blocker = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: longLineBidiWebExclusiveTaskBytes,
      cancellationToken: LongLineCooperativeCancellationToken(),
      action: () async {
        blockerStarted.complete();
        await blockerRelease.future;
      },
    );
    await blockerStarted.future;

    final queuedToken = LongLineCooperativeCancellationToken();
    final queued = runWithLongLineBidiWebGateForTesting<void>(
      estimatedBytes: longLineBidiWebExclusiveTaskBytes,
      cancellationToken: queuedToken,
      action: () async => fail('已取消的 queued action 不得执行'),
    );
    final stale = expectLater(queued, throwsA(isA<LongLineCooperativeCancelledException>()));
    expect(longLineBidiExecutorDiagnostics().queuedTasks, 1);

    queuedToken.cancel();
    await stale.timeout(const Duration(milliseconds: 100));
    expect(longLineBidiExecutorDiagnostics(), (
      activeTasks: 1,
      activeBytes: longLineBidiWebExclusiveTaskBytes,
      queuedTasks: 0,
      queuedBytes: 0,
    ));

    blockerRelease.complete();
    await blocker;
    expect(longLineBidiExecutorDiagnostics(), (activeTasks: 0, activeBytes: 0, queuedTasks: 0, queuedBytes: 0));
  });

  test('工作集估算覆盖 chunk/list、交替 runs 与视觉对象峰值', () {
    expect(estimateLongLineBidiWorkingSetBytes(0), 64 * 1024);
    expect(estimateLongLineBidiWorkingSetBytes(5 * 1024 * 1024), 64 * 1024 + 5 * 1024 * 1024 * 192);
    expect(() => estimateLongLineBidiWorkingSetBytes(-1), throwsRangeError);
  });
}
