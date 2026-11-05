import 'package:flutter_base/src/flutter/views/editable/render/bidi/long_line_bidi_index.dart';
import 'package:flutter_base/src/flutter/views/editable/render/bidi/long_line_bidi_pipeline.dart';
import 'package:flutter_base/src/flutter/views/editable/render/editable_line_layout.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LongLineBidiPipeline hydration', () {
    test('5Mi UTF-16 后台解析复用同一 future/result，且 1Mi 外部预算可驱动', () async {
      const chunkLength = LongLineBidiPipeline.maxChunkCodeUnits;
      const chunkCount = 80;
      const lineLength = chunkLength * chunkCount;
      final chunk = List<String>.filled(chunkLength, 'a').join();
      final pipeline = _pipeline(lineLength, averageAdvance: 1);

      for (var index = 0; index < chunkCount; index++) {
        pipeline.appendChunk(index * chunkLength, chunk);
      }
      expect(pipeline.debugLoadedCodeUnits, lineLength);
      expect(pipeline.debugChunkCount, chunkCount);
      expect(pipeline.debugRetainedUtf16Bytes, lineLength * 2);
      expect(pipeline.debugRetainedBytes, lineLength * 2 + 24 + chunkCount * (24 + 8));
      expect(pipeline.debugEstimatedBackgroundWorkingSetBytes, 64 * 1024 + lineLength * 192);
      expect(pipeline.debugInFlightWorkingSetBytes, 0);
      expect(pipeline.debugGlobalBackgroundActiveTasks, 0);
      expect(pipeline.debugReady, isTrue);
      expect(pipeline.debugResolving, isFalse);
      expect(pipeline.debugResolved, isFalse);
      expect(pipeline.resolvedResultOrNull, isNull);

      final firstFuture = pipeline.resolveInBackground();
      final secondFuture = pipeline.resolveInBackground();
      expect(identical(firstFuture, secondFuture), isTrue);
      expect(pipeline.debugResolving, isTrue);
      expect(pipeline.debugGlobalBackgroundActiveTasks, 1, reason: '原生诊断必须反映真实可终止 isolate');
      expect(pipeline.debugInFlightWorkingSetBytes, pipeline.debugEstimatedBackgroundWorkingSetBytes);
      expect(pipeline.debugChunkCount, chunkCount, reason: 'Future 返回前主 isolate 不得同步合并 5Mi String');
      expect(pipeline.resolvedResultOrNull, isNull, reason: '只读探针不得偷跑同步 resolve');
      expect(pipeline.resolve, throwsStateError, reason: 'in-flight 期间不得再重复跑同步 UAX');
      final first = await firstFuture;
      final second = await secondFuture;
      expect(identical(first, second), isTrue);
      expect(identical(pipeline.resolveInBackground(), firstFuture), isTrue);
      expect(identical(pipeline.resolve(), first), isTrue);
      expect(identical(first.bidiIndex, second.bidiIndex), isTrue);
      expect(identical(first.visualIndex, second.visualIndex), isTrue);
      expect(first.bidiIndex.utf16Length, lineLength);
      expect(pipeline.debugResolving, isFalse);
      expect(pipeline.debugGlobalBackgroundActiveTasks, 0);
      expect(pipeline.debugInFlightWorkingSetBytes, 0);
      expect(pipeline.debugResolved, isTrue);
      expect(identical(pipeline.resolvedResultOrNull, first), isTrue);
      expect(pipeline.debugChunkCount, 0, reason: '解析后必须释放零散 chunk 引用');
      expect(pipeline.debugRetainedUtf16Bytes, lineLength * 2);
      expect(pipeline.debugRetainedBytes, greaterThan(lineLength * 2));
      expect(pipeline.debugTileCount, 1280);

      final window = pipeline.buildWindow(
        viewportStart: lineLength / 3,
        viewportEnd: lineLength / 3 + 1024 * 1024,
        guard: 0,
        maxParagraphCodeUnits: 1024 * 1024,
        logicalTabPrefixForOffset: (offset) => offset.toDouble(),
      );
      expect(window, isNotNull);
      expect(
        window!.totalParagraphCodeUnits,
        lessThanOrEqualTo(LongLineBidiPipeline.maxParagraphCodeUnits),
        reason: '外部 1Mi 预算不能突破内部 64Ki synthetic Paragraph 硬上限',
      );
      expect(window.totalParagraphCodeUnits, window.totalContentCodeUnits + 2 + window.visualFragments.length * 4);
      expect(window.estimatedTextWidth, lineLength);
      pipeline.dispose();
    });

    test('合法 surrogate pair 可以跨 appendChunk 边界', () {
      final pipeline = _pipeline(4);
      pipeline.appendChunk(0, 'a${String.fromCharCode(0xd83d)}');
      pipeline.appendChunk(2, '${String.fromCharCode(0xde00)}b');

      final result = pipeline.resolve();
      expect(result.bidiIndex.atomCount, 3);
      expect(result.bidiIndex.logicalToVisual, orderedEquals(<int>[0, 1, 2, 3]));
      final window = _fullWindow(pipeline, 4)!;
      expect(window.visualFragments.map((fragment) => fragment.text).join(), 'a😀b');
      expect(window.totalContentCodeUnits, 4);
    });

    test('交替 level/X9 行的 chunks、retained 与 in-flight 工作集预算保持保守', () {
      final text = List<String>.filled(4000, 'a\u202e\u202cא').join();
      final pipeline = _pipeline(text.length, averageAdvance: 1)..appendChunk(0, text);

      expect(pipeline.debugRetainedBytes, text.length * 2 + 24 + 24 + 8);
      expect(pipeline.debugEstimatedBackgroundWorkingSetBytes, 64 * 1024 + text.length * 192);
      expect(pipeline.debugEstimatedBackgroundWorkingSetBytes, greaterThan(pipeline.debugRetainedBytes * 20));
      final result = pipeline.resolve();
      expect(result.bidiIndex.logicalRuns.length, greaterThan(4000));
      expect(result.visualIndex.tiles.length, greaterThan(4000));
      expect(pipeline.debugRetainedBytes, greaterThan(text.length * 10));
      pipeline.dispose();
    });

    test('空逻辑行无需 append 即 ready，解析与窗口均合法', () {
      final pipeline = _pipeline(0);

      expect(pipeline.debugReady, isTrue);
      final result = pipeline.resolve();
      expect(result.bidiIndex.utf16Length, 0);
      expect(result.visualIndex.tiles, isEmpty);
      expect(_fullWindow(pipeline, 0), isNull);
    });

    test('后台解析期间 invalidate 使 future 明确 stale 且绝不安装', () async {
      final text = List<String>.filled(1024 * 1024, 'a').join();
      final pipeline = _pipeline(text.length)..appendChunk(0, text.substring(0, 64 * 1024));
      for (var offset = 64 * 1024; offset < text.length; offset += 64 * 1024) {
        pipeline.appendChunk(offset, text.substring(offset, offset + 64 * 1024));
      }
      final future = pipeline.resolveInBackground();
      final stale = expectLater(future, throwsA(isA<LongLineBidiPipelineStaleException>()));
      expect(pipeline.debugResolving, isTrue);
      expect(pipeline.debugGlobalBackgroundActiveTasks, 1);

      final cancelLatency = Stopwatch()..start();
      pipeline.invalidate();
      await stale.timeout(const Duration(seconds: 2));
      cancelLatency.stop();
      expect(
        cancelLatency.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason: '取消必须 kill isolate，不得等待 1MiB UAX 自然结束',
      );
      expect(pipeline.debugResolving, isFalse);
      expect(pipeline.debugGlobalBackgroundActiveTasks, 0);
      expect(pipeline.debugResolved, isFalse);
      expect(pipeline.resolvedResultOrNull, isNull);
      expect(pipeline.debugRetainedBytes, 0);
      pipeline.dispose();
    });

    test('后台解析期间 dispose 同样拒绝安装晚到结果', () async {
      final text = List<String>.filled(256 * 1024, 'א').join();
      final pipeline = _pipeline(text.length, baseDirection: LongLineBidiBaseDirection.rtl);
      for (var offset = 0; offset < text.length; offset += 64 * 1024) {
        pipeline.appendChunk(offset, text.substring(offset, offset + 64 * 1024));
      }
      final future = pipeline.resolveInBackground();
      final stale = expectLater(future, throwsA(isA<LongLineBidiPipelineStaleException>()));

      pipeline.dispose();
      await stale;
      expect(pipeline.debugResolving, isFalse);
      expect(pipeline.debugResolved, isFalse);
      expect(pipeline.resolvedResultOrNull, isNull);
      expect(pipeline.debugRetainedBytes, 0);
    });

    test(
      '原生全局门四请求最多两个 isolate，queued 取消立即摘队且 active kill 后放行下一项',
      () async {
        const chunkCount = 80;
        final chunk = 'aא' * (LongLineBidiPipeline.maxChunkCodeUnits ~/ 2);
        final lineLength = chunk.length * chunkCount;
        final pipelines = <LongLineBidiPipeline>[
          for (var index = 0; index < 4; index++) _pipeline(lineLength, averageAdvance: 1),
        ];
        for (final pipeline in pipelines) {
          for (var index = 0; index < chunkCount; index++) {
            pipeline.appendChunk(index * chunk.length, chunk);
          }
        }

        final futures = <Future<LongLineBidiPipelineResult>>[
          for (final pipeline in pipelines) pipeline.resolveInBackground(),
        ];
        expect(pipelines.first.debugGlobalBackgroundActiveTasks, 2);
        expect(pipelines.first.debugGlobalBackgroundQueuedTasks, 2);
        expect(pipelines.first.debugGlobalBackgroundActiveBytes, greaterThan(0));
        expect(pipelines.first.debugGlobalBackgroundQueuedBytes, greaterThan(0));

        final queuedStale = expectLater(futures[2], throwsA(isA<LongLineBidiPipelineStaleException>()));
        pipelines[2].dispose();
        await queuedStale.timeout(const Duration(seconds: 2));
        expect(pipelines.first.debugGlobalBackgroundActiveTasks, 2);
        expect(pipelines.first.debugGlobalBackgroundQueuedTasks, 1, reason: 'queued token cancel 必须同步摘队且绝不 spawn');

        final firstStale = expectLater(futures[0], throwsA(isA<LongLineBidiPipelineStaleException>()));
        pipelines[0].dispose();
        await firstStale.timeout(const Duration(seconds: 2));
        for (var turn = 0; turn < 40 && pipelines.first.debugGlobalBackgroundQueuedTasks != 0; turn++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(pipelines.first.debugGlobalBackgroundQueuedTasks, 0, reason: 'active onExit 后必须按 FIFO 放行第四项');
        expect(pipelines.first.debugGlobalBackgroundActiveTasks, lessThanOrEqualTo(2));

        final secondStale = expectLater(futures[1], throwsA(isA<LongLineBidiPipelineStaleException>()));
        final fourthStale = expectLater(futures[3], throwsA(isA<LongLineBidiPipelineStaleException>()));
        pipelines[1].dispose();
        pipelines[3].dispose();
        await Future.wait<void>(<Future<void>>[secondStale, fourthStale]).timeout(const Duration(seconds: 2));
        expect(pipelines.first.debugGlobalBackgroundActiveTasks, 0);
        expect(pipelines.first.debugGlobalBackgroundQueuedTasks, 0);
        expect(pipelines.first.debugGlobalBackgroundActiveBytes, 0);
        expect(pipelines.first.debugGlobalBackgroundQueuedBytes, 0);
      },
      timeout: const Timeout(Duration(seconds: 15)),
      skip: kIsWeb,
    );
  });

  group('LongLineBidiPipeline visual window', () {
    test('超长 RTL run 的反向视觉 tiles 合并为单一 shaping fragment', () {
      final text = List<String>.filled(5000, 'א').join();
      final pipeline = _hydrated(text, baseDirection: LongLineBidiBaseDirection.rtl);
      final requestedPrefixes = <int>[];
      final window = pipeline.buildWindow(
        viewportStart: 0,
        viewportEnd: text.length * pipeline.averageAdvance,
        guard: 0,
        maxParagraphCodeUnits: LongLineBidiPipeline.maxParagraphCodeUnits,
        logicalTabPrefixForOffset: (offset) {
          requestedPrefixes.add(offset);
          return offset * pipeline.averageAdvance;
        },
      )!;

      expect(window.visualFragments, hasLength(1));
      expect((window.visualFragments.single.lineStart, window.visualFragments.single.lineEnd), (0, 5000));
      expect(window.visualFragments.single.resolvedLevel, 1);
      expect(window.visualFragments.single.text, text);
      expect(window.originX, 0);
      expect(window.estimatedTextWidth, 50000);
      expect(requestedPrefixes, <int>[0]);
    });

    test('Arabic joining 与 Latin ligature 不会在 4096 tile seam 被拆成多个 fragment', () {
      final arabic = List<String>.filled(5000, 'ب').join();
      final arabicWindow = _fullWindow(_hydrated(arabic, baseDirection: LongLineBidiBaseDirection.rtl), arabic.length)!;
      expect(arabicWindow.visualFragments, hasLength(1));
      expect(arabicWindow.visualFragments.single.text, arabic);

      final latin = '${List<String>.filled(4095, 'a').join()}ffi${List<String>.filled(1000, 'b').join()}';
      final latinWindow = _fullWindow(_hydrated(latin), latin.length)!;
      expect(latinWindow.visualFragments, hasLength(1));
      expect(latinWindow.visualFragments.single.text, latin);
      expect(latinWindow.visualFragments.single.lineStart, 0);
      expect(latinWindow.visualFragments.single.lineEnd, latin.length);
    });

    test('显式方向格式 gap 不进入 fragment，tab prefix 按每个原文起点求值', () {
      const text = 'a\u202Ab\u202Cc';
      final pipeline = _hydrated(text);
      final requestedOffsets = <int>[];
      final window = pipeline.buildWindow(
        viewportStart: 0,
        viewportEnd: 100,
        guard: 0,
        maxParagraphCodeUnits: 1024,
        logicalTabPrefixForOffset: (offset) {
          requestedOffsets.add(offset);
          return offset * 3.0;
        },
      )!;

      expect(window.visualFragments.map((fragment) => (fragment.lineStart, fragment.lineEnd)), <(int, int)>[
        (0, 1),
        (2, 3),
        (4, 5),
      ]);
      expect(window.visualFragments.map((fragment) => fragment.text), <String>['a', 'b', 'c']);
      expect(window.visualFragments.map((fragment) => fragment.logicalTabPrefix), <double>[0, 6, 12]);
      expect(requestedOffsets, <int>[0, 2, 4]);
      expect(window.totalContentCodeUnits, 3);
      expect(window.totalParagraphCodeUnits, 17);
    });

    test('emoji ZWJ 与 Arabic ZWNJ/ZWJ 原样保留在单一 shaping fragment', () {
      const emoji = 'x👩‍👩‍👧‍👦y';
      final emojiWindow = _fullWindow(_hydrated(emoji), emoji.length)!;
      expect(emojiWindow.visualFragments, hasLength(1));
      expect(emojiWindow.visualFragments.single.text, emoji);
      expect(emojiWindow.visualFragments.single.text.codeUnits.where((unit) => unit == 0x200d), hasLength(3));

      for (final joiner in <String>['\u200c', '\u200d']) {
        final arabic = 'ا$joinerب';
        final arabicWindow = _fullWindow(_hydrated(arabic), arabic.length)!;
        expect(arabicWindow.visualFragments, hasLength(1));
        expect(arabicWindow.visualFragments.single.text, arabic);
      }
    });

    test('跨 resolved level 的 Prepend grapheme 仍生成单一 shaping fragment', () {
      const text = '\u0600A';
      final window = _fullWindow(_hydrated(text), text.length)!;

      expect(window.visualFragments, hasLength(1));
      expect(window.visualFragments.single.text, text);
      expect((window.visualFragments.single.lineStart, window.visualFragments.single.lineEnd), (0, 2));
    });

    test('RI 与 Indic clusters 水合后仍保持单一 shaping fragment', () {
      for (final text in <String>['🇺🇸', 'क्‍ष']) {
        final window = _fullWindow(_hydrated(text), text.length)!;

        expect(window.visualFragments, hasLength(1));
        expect(window.visualFragments.single.text, text);
      }
    });

    test('未闭合/跨片段 isolate 与 RLO/PDF 不泄漏进 synthetic fragments', () {
      final fixtures = <(String, Set<int>)>[
        ('a\u2066b', <int>{0x2066}),
        ('a\u2067b', <int>{0x2067}),
        ('a\u2068b', <int>{0x2068}),
        ('a\u2069b', <int>{0x2069}),
        ('a\u2066b\u2069c', <int>{0x2066, 0x2069}),
        ('a\u202eb\u202cc', <int>{0x202e, 0x202c}),
      ];
      for (final (text, forbidden) in fixtures) {
        final window = _fullWindow(_hydrated(text), text.length)!;
        final fragmentUnits = <int>[for (final fragment in window.visualFragments) ...fragment.text.codeUnits];
        for (final control in forbidden) {
          expect(fragmentUnits, isNot(contains(control)), reason: 'U+${control.toRadixString(16)} 不得进入正文 fragment');
        }
        expect(window.totalContentCodeUnits, text.length - forbidden.length);
      }
    });

    test('单 tile 或 controls 无法放入硬预算时返回 null', () {
      final pipeline = _hydrated(List<String>.filled(4096, 'a').join());

      expect(
        pipeline.buildWindow(
          viewportStart: 0,
          viewportEnd: 10,
          guard: 0,
          maxParagraphCodeUnits: 100,
          logicalTabPrefixForOffset: (_) => 0,
        ),
        isNull,
      );
      expect(
        pipeline.buildWindow(
          viewportStart: 0,
          viewportEnd: 10,
          guard: 0,
          maxParagraphCodeUnits: 6,
          logicalTabPrefixForOffset: (_) => 0,
        ),
        isNull,
      );

      final formattingOnly = _hydrated('\u202e\u202c\u2066\u2069');
      expect(_fullWindow(formattingOnly, 4), isNull, reason: '仅含方向格式控制符的逻辑行没有可绘制 fragment');
    });

    test('大量短 bidi fragments 仍逐片扣除 controls 并保持连续硬预算', () {
      final text = List<String>.filled(1000, 'aא').join();
      final pipeline = _hydrated(text, averageAdvance: 1);
      final window = pipeline.buildWindow(
        viewportStart: 0,
        viewportEnd: text.length.toDouble(),
        guard: 0,
        maxParagraphCodeUnits: 100,
        logicalTabPrefixForOffset: (offset) => offset.toDouble(),
      )!;

      expect(window.visualFragments.length, greaterThan(1));
      expect(window.totalParagraphCodeUnits, lessThanOrEqualTo(100));
      expect(window.totalParagraphCodeUnits, window.totalContentCodeUnits + 2 + window.visualFragments.length * 4);
      final tiles = pipeline.resolve().visualIndex.tiles;
      final firstTile = tiles.indexWhere(
        (tile) =>
            tile.start == window.visualFragments.first.lineStart && tile.end == window.visualFragments.first.lineEnd,
      );
      expect(firstTile, greaterThanOrEqualTo(0));
      for (var index = 0; index < window.visualFragments.length; index++) {
        expect(
          (window.visualFragments[index].lineStart, window.visualFragments[index].lineEnd),
          (tiles[firstTile + index].start, tiles[firstTile + index].end),
          reason: '窗口必须保持 visual tile 的连续子序列',
        );
      }
    });

    test('实测宽度同时更新后继窗口 originX 与全行 extent', () {
      final pipeline = _hydrated(List<String>.filled(9000, 'a').join(), averageAdvance: 1);
      final before = pipeline.buildWindow(
        viewportStart: 5001,
        viewportEnd: 5002,
        guard: 0,
        maxParagraphCodeUnits: 4200,
        logicalTabPrefixForOffset: (offset) => offset.toDouble(),
      )!;
      expect(before.visualFragments.single.lineStart, 4096);
      expect(before.originX, 4096);
      expect(before.estimatedTextWidth, 9000);

      pipeline.reportMeasuredWidth(0, 5000);
      final after = pipeline.buildWindow(
        viewportStart: 5001,
        viewportEnd: 5002,
        guard: 0,
        maxParagraphCodeUnits: 4200,
        logicalTabPrefixForOffset: (offset) => offset.toDouble(),
      )!;
      expect(after.visualFragments.single.lineStart, 4096);
      expect(after.originX, 5000);
      expect(after.estimatedTextWidth, 9904);

      pipeline.reportMeasuredWidths(<int, double>{0: 4500, 2: 1000});
      final result = pipeline.resolve();
      expect(result.visualIndex.totalExtent, 9596);
    });

    test('窗口直接携带精确 tile 区间，零宽首 tile 后不依赖 originX 反推', () {
      final text = '${List<String>.filled(4096, 'a').join()}\u2060${List<String>.filled(4096, 'אב').join()}';
      final pipeline = _hydrated(text, averageAdvance: 1);
      final window = pipeline.buildWindow(
        viewportStart: 0,
        viewportEnd: 64,
        guard: 0,
        maxParagraphCodeUnits: 8192,
        logicalTabPrefixForOffset: (offset) => offset.toDouble(),
      )!;
      final visual = pipeline.resolvedResultOrNull!.visualIndex;

      expect(window.visualFirstTile, 0);
      expect(window.visualEndTile, greaterThan(window.visualFirstTile));
      expect(window.visualTileCount, visual.tiles.length);
      pipeline.reportMeasuredWidth(window.visualFirstTile, 0);

      expect(visual.locateX(window.originX)!.tileIndex, isNot(window.visualFirstTile));
      expect(window.visualFirstTile, 0, reason: '窗口必须保留选择时的真实 tile，不可再用零宽后的 x 反推');
    });

    test('管线转发非均匀与平均估值，但绝不覆盖已测 tile', () {
      final pipeline = _hydrated(List<String>.filled(9000, 'a').join(), averageAdvance: 1);
      pipeline.reportMeasuredWidth(0, 5000);

      pipeline.updateUnmeasuredWidths(<int, double>{0: 999, 1: 7000, 2: 1000});
      var visual = pipeline.resolve().visualIndex;
      expect(<double>[for (var tile = 0; tile < 3; tile++) visual.widthOf(tile)], <double>[5000, 7000, 1000]);
      expect(visual.totalExtent, 13000);
      expect(visual.isMeasured(0), isTrue);
      expect(visual.isMeasured(1), isFalse);

      pipeline.updateUnmeasuredAverageAdvance(2);
      visual = pipeline.resolve().visualIndex;
      expect(pipeline.averageAdvance, 2);
      expect(visual.averageAdvance, 2);
      expect(<double>[for (var tile = 0; tile < 3; tile++) visual.widthOf(tile)], <double>[5000, 8192, 1616]);
      expect(visual.totalExtent, 14808);
      final window = pipeline.buildWindow(
        viewportStart: 5001,
        viewportEnd: 5002,
        guard: 0,
        maxParagraphCodeUnits: 4200,
        logicalTabPrefixForOffset: (offset) => offset * pipeline.averageAdvance,
      )!;
      expect(window.originX, 5000);
      expect(window.estimatedTextWidth, 14808);
      expect(window.averageAdvance, 2);
    });

    test('tab prefix 非有限非负时在构造 fragment 前严格拒绝', () {
      final pipeline = _hydrated('abc');

      expect(
        () => pipeline.buildWindow(
          viewportStart: 0,
          viewportEnd: 10,
          guard: 0,
          maxParagraphCodeUnits: 100,
          logicalTabPrefixForOffset: (_) => double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => pipeline.buildWindow(
          viewportStart: 0,
          viewportEnd: 10,
          guard: 0,
          maxParagraphCodeUnits: 100,
          logicalTabPrefixForOffset: (_) => -1,
        ),
        throwsArgumentError,
      );
    });

    test('即使空行也先严格校验 viewport、guard 与 paragraph 预算', () {
      final pipeline = _hydrated('');

      expect(
        () => pipeline.buildWindow(
          viewportStart: double.nan,
          viewportEnd: 0,
          guard: 0,
          maxParagraphCodeUnits: 10,
          logicalTabPrefixForOffset: (_) => 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => pipeline.buildWindow(
          viewportStart: 1,
          viewportEnd: 0,
          guard: 0,
          maxParagraphCodeUnits: 10,
          logicalTabPrefixForOffset: (_) => 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => pipeline.buildWindow(
          viewportStart: 0,
          viewportEnd: 0,
          guard: -1,
          maxParagraphCodeUnits: 10,
          logicalTabPrefixForOffset: (_) => 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => pipeline.buildWindow(
          viewportStart: 0,
          viewportEnd: 0,
          guard: 0,
          maxParagraphCodeUnits: 0,
          logicalTabPrefixForOffset: (_) => 0,
        ),
        throwsRangeError,
      );
    });
  });

  group('LongLineBidiPipeline strict state', () {
    test('构造、乱序、重复、空块、64Ki 与总长边界均严格校验', () {
      expect(() => _pipeline(-1), throwsRangeError);
      expect(() => _pipeline(1, averageAdvance: 0), throwsArgumentError);
      expect(() => _pipeline(1, averageAdvance: double.nan), throwsArgumentError);

      final pipeline = _pipeline(3);
      expect(() => pipeline.appendChunk(1, 'a'), throwsStateError);
      expect(() => pipeline.appendChunk(0, ''), throwsArgumentError);
      expect(
        () => pipeline.appendChunk(0, List<String>.filled(LongLineBidiPipeline.maxChunkCodeUnits + 1, 'a').join()),
        throwsRangeError,
      );
      expect(() => pipeline.appendChunk(0, 'abcd'), throwsRangeError);

      pipeline.appendChunk(0, 'a');
      expect(() => pipeline.appendChunk(0, 'b'), throwsStateError, reason: '同一 start 的重复块必须拒绝');
      pipeline.appendChunk(1, 'bc');
      expect(() => pipeline.appendChunk(3, 'd'), throwsRangeError);
      pipeline.resolve();
      expect(() => pipeline.appendChunk(3, 'd'), throwsStateError);
    });

    test('未完整或未 resolve 时拒绝解析依赖操作', () {
      final incomplete = _pipeline(2)..appendChunk(0, 'a');
      expect(incomplete.debugReady, isFalse);
      expect(incomplete.resolve, throwsStateError);

      final complete = _pipeline(1)..appendChunk(0, 'a');
      expect(
        () => complete.buildWindow(
          viewportStart: 0,
          viewportEnd: 1,
          guard: 0,
          maxParagraphCodeUnits: 100,
          logicalTabPrefixForOffset: (_) => 0,
        ),
        throwsStateError,
      );
      expect(() => complete.reportMeasuredWidth(0, 1), throwsStateError);
      expect(() => complete.reportMeasuredWidths(<int, double>{0: 1}), throwsStateError);
      expect(() => complete.updateUnmeasuredAverageAdvance(2), throwsStateError);
      expect(() => complete.updateUnmeasuredWidths(<int, double>{0: 1}), throwsStateError);
    });

    test('孤立 high/low surrogate 跨普通 chunk 时按单原子保留 UTF-16 offset', () {
      final high = _pipeline(3)
        ..appendChunk(0, 'a${String.fromCharCode(0xd83d)}')
        ..appendChunk(2, 'b');
      final highResult = high.resolve();
      expect(highResult.bidiIndex.atomCount, 3);
      expect(highResult.bidiIndex.logicalToVisual, orderedEquals(<int>[0, 1, 2]));
      expect(highResult.visualIndex.tiles.single.length, 3);
      expect(_fullWindow(high, 3)!.visualFragments.single.text.codeUnits, <int>[0x61, 0xd83d, 0x62]);

      final low = _pipeline(3)
        ..appendChunk(0, 'a')
        ..appendChunk(1, '${String.fromCharCode(0xde00)}b');
      final lowResult = low.resolve();
      expect(lowResult.bidiIndex.atomCount, 3);
      expect(lowResult.bidiIndex.logicalToVisual, orderedEquals(<int>[0, 1, 2]));
      expect(lowResult.visualIndex.tiles.single.length, 3);
      expect(_fullWindow(low, 3)!.visualFragments.single.text.codeUnits, <int>[0x61, 0xde00, 0x62]);
    });

    test('invalidate 释放所有载荷，后续所有操作严格拒绝', () {
      final pipeline = _hydrated('abcdef');
      pipeline.invalidate();

      expect(pipeline.debugLoadedCodeUnits, 0);
      expect(pipeline.debugRetainedUtf16Bytes, 0);
      expect(pipeline.debugTileCount, 0);
      expect(pipeline.debugReady, isFalse);
      expect(() => pipeline.appendChunk(0, 'a'), throwsStateError);
      expect(pipeline.resolve, throwsStateError);
      expect(pipeline.resolveInBackground, throwsStateError);
      expect(() => pipeline.reportMeasuredWidth(0, 1), throwsStateError);
      expect(() => pipeline.updateUnmeasuredAverageAdvance(2), throwsStateError);
      expect(pipeline.invalidate, throwsStateError);
      pipeline.dispose();
    });

    test('dispose 可重复，但释放后的业务入口全部拒绝', () {
      final pipeline = _pipeline(1)..appendChunk(0, 'a');
      pipeline.dispose();
      pipeline.dispose();

      expect(pipeline.debugLoadedCodeUnits, 0);
      expect(pipeline.debugRetainedUtf16Bytes, 0);
      expect(() => pipeline.appendChunk(0, 'a'), throwsStateError);
      expect(pipeline.resolve, throwsStateError);
      expect(pipeline.resolveInBackground, throwsStateError);
      expect(() => pipeline.reportMeasuredWidths(const <int, double>{}), throwsStateError);
      expect(() => pipeline.updateUnmeasuredWidths(const <int, double>{}), throwsStateError);
    });
  });
}

LongLineBidiPipeline _pipeline(
  int lineLength, {
  LongLineBidiBaseDirection baseDirection = LongLineBidiBaseDirection.ltr,
  double averageAdvance = 10,
}) => LongLineBidiPipeline(lineLength: lineLength, baseDirection: baseDirection, averageAdvance: averageAdvance);

LongLineBidiPipeline _hydrated(
  String text, {
  LongLineBidiBaseDirection baseDirection = LongLineBidiBaseDirection.ltr,
  double averageAdvance = 10,
}) {
  final pipeline = _pipeline(text.length, baseDirection: baseDirection, averageAdvance: averageAdvance);
  if (text.isNotEmpty) pipeline.appendChunk(0, text);
  pipeline.resolve();
  return pipeline;
}

EditableLineLayoutWindow? _fullWindow(LongLineBidiPipeline pipeline, int lineLength) => pipeline.buildWindow(
  viewportStart: 0,
  viewportEnd: lineLength * pipeline.averageAdvance,
  guard: 0,
  maxParagraphCodeUnits: LongLineBidiPipeline.maxParagraphCodeUnits,
  logicalTabPrefixForOffset: (offset) => offset * pipeline.averageAdvance,
);
