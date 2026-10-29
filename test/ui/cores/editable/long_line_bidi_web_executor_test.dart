import 'dart:async';

import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_bidi_index.dart';
import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_bidi_executor_web.dart';
import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_bidi_pipeline.dart';
import 'package:flutter_base/src/ui/cores/editable/render/bidi/long_line_cooperative_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web background resolve 在长行解析期间持续归还浏览器事件循环', () async {
    const unit = 'abc אבג (١٢) العربية 👩‍👩‍👧‍👦 ';
    final text = List<String>.filled((32 * 1024) ~/ unit.length + 1, unit).join();
    final pipeline = LongLineBidiPipeline(
      lineLength: text.length,
      baseDirection: LongLineBidiBaseDirection.ltr,
      averageAdvance: 8,
    );
    for (var start = 0; start < text.length; start += LongLineBidiPipeline.maxChunkCodeUnits) {
      final end = (start + LongLineBidiPipeline.maxChunkCodeUnits).clamp(0, text.length);
      pipeline.appendChunk(start, text.substring(start, end));
    }

    var eventLoopTicks = 0;
    final timer = Timer.periodic(Duration.zero, (_) => eventLoopTicks++);
    final result = await pipeline.resolveInBackground();
    timer.cancel();

    expect(result.bidiIndex.utf16Length, text.length);
    expect(result.visualIndex.text, text);
    expect(eventLoopTicks, greaterThan(2), reason: 'Web 解析不能用一个同步 callback 冻结整条事件循环');
    pipeline.dispose();
  }, skip: !kIsWeb);

  test('Web mid-resolve invalidate 立即停止旧代际，并允许新管线完成', () async {
    const unit = 'abc אבג العربية ١٢ ';
    final oldText = List<String>.filled((128 * 1024) ~/ unit.length + 1, unit).join();
    final oldPipeline = _pipelineFor(oldText);
    final stopwatch = Stopwatch()..start();

    final staleFuture = oldPipeline.resolveInBackground();
    unawaited(Future<void>.delayed(Duration.zero, oldPipeline.invalidate));
    await expectLater(staleFuture, throwsA(isA<LongLineBidiPipelineStaleException>()));
    final elapsedAtStale = stopwatch.elapsed;

    final newText = List<String>.filled((8 * 1024) ~/ unit.length + 1, unit).join();
    final newPipeline = _pipelineFor(newText);
    final result = await newPipeline.resolveInBackground();

    expect(elapsedAtStale, lessThan(const Duration(seconds: 2)));
    expect(result.bidiIndex.utf16Length, newText.length);
    expect(result.visualIndex.text, newText);
    newPipeline.dispose();
  }, skip: !kIsWeb);

  test('Web exclusive blocker 不释放时，queued pipeline invalidate 仍立即 stale 并释放 chunks', () async {
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

    final text = List<String>.filled(32 * 1024, 'א').join();
    final pipeline = _pipelineFor(text);
    final staleFuture = pipeline.resolveInBackground();
    final stale = expectLater(staleFuture, throwsA(isA<LongLineBidiPipelineStaleException>()));
    expect(pipeline.debugGlobalBackgroundQueuedTasks, 1);
    expect(pipeline.debugChunkCount, 1);

    pipeline.invalidate();
    await stale.timeout(const Duration(milliseconds: 100));
    expect(pipeline.debugChunkCount, 0);
    expect(pipeline.debugRetainedBytes, 0);
    expect(longLineBidiExecutorDiagnostics().queuedTasks, 0);
    expect(longLineBidiExecutorDiagnostics().queuedBytes, 0);

    blockerRelease.complete();
    await blocker;
    pipeline.dispose();
  }, skip: !kIsWeb);
}

LongLineBidiPipeline _pipelineFor(String text) {
  final pipeline = LongLineBidiPipeline(
    lineLength: text.length,
    baseDirection: LongLineBidiBaseDirection.ltr,
    averageAdvance: 8,
  );
  for (var start = 0; start < text.length; start += LongLineBidiPipeline.maxChunkCodeUnits) {
    final end = (start + LongLineBidiPipeline.maxChunkCodeUnits).clamp(0, text.length);
    pipeline.appendChunk(start, text.substring(start, end));
  }
  return pipeline;
}
