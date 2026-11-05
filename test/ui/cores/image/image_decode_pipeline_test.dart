import 'dart:ui' as ui;

import 'package:flutter_base/src/flutter/views/image/image_byte_source.dart';
import 'package:flutter_base/src/flutter/views/image/image_decode_pipeline.dart';
import 'package:flutter_base/src/flutter/views/image/image_platform_bridge.dart';
import 'package:flutter_base/src/flutter/views/image/image_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 1x1 透明 png（同 selection_test 常量）。
final Uint8List _png = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  final pipeline = ImageDecodePipeline.instance;

  setUp(pipeline.debugClear);

  test('bucketForTargetWidth：32px 粒度、下限 64', () {
    expect(ImageDecodePipeline.bucketForTargetWidth(1), 64);
    expect(ImageDecodePipeline.bucketForTargetWidth(64), 64);
    expect(ImageDecodePipeline.bucketForTargetWidth(65), 96);
    expect(ImageDecodePipeline.bucketForTargetWidth(420), 448);
    expect(ImageDecodePipeline.bucketForTargetWidth(512.4), 544);
  });

  test('自适应缓存预算：低内存守住保底，常规设备受内存与屏幕像素双重约束', () {
    const lowRam = ImageDeviceProfile(
      memoryClassMb: 128,
      largeMemoryClassMb: 512,
      lowRam: true,
      screenWidthPx: 720,
      screenHeightPx: 1280,
    );
    const normal = ImageDeviceProfile(
      memoryClassMb: 256,
      largeMemoryClassMb: 512,
      lowRam: false,
      screenWidthPx: 1256,
      screenHeightPx: 2760,
    );
    expect(ImageDecodePipeline.cacheBudgetForProfile(lowRam), 128 << 20);
    final normalBudget = ImageDecodePipeline.cacheBudgetForProfile(normal);
    expect(normalBudget, greaterThan(128 << 20));
    expect(normalBudget, lessThanOrEqualTo((256 * (1 << 20) * 0.60).floor()));
    expect(normalBudget, lessThanOrEqualTo(1256 * 2760 * 4 * 12));
  });

  testWidgets('MediaStore 快速路径：按布局桶解码且不读取原始文件', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    pipeline.debugResetPlatformTuning();
    Map<Object?, Object?>? thumbnailArguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.el.ui/image'),
      (call) async {
        if (call.method == 'loadMediaThumbnail') {
          thumbnailArguments = call.arguments as Map<Object?, Object?>;
          return <String, Object>{
            'pixels': Uint8List(9 * 9 * 4)..setAll(0, <int>[0xe1, 0x27, 0x58, 0xff]),
            'originalWidth': 512,
            'originalHeight': 256,
            'thumbnailWidth': 9,
            'thumbnailHeight': 9,
            'rowBytes': 36,
            'modifiedSeconds': 1,
          };
        }
        return switch (call.method) {
          'deviceProfile' => <String, Object>{
            'memoryClassMb': 256,
            'largeMemoryClassMb': 512,
            'lowRam': false,
            'screenWidthPx': 1256,
            'screenHeightPx': 2760,
          },
          'listMediaImages' => <String>[r'D:\image\new.jpg', r'D:\image\old.jpg'],
          _ => null,
        };
      },
    );

    try {
      await tester.runAsync(() async {
        expect(await ElImageView.systemImagePaths(refresh: true), <String>[r'D:\image\new.jpg', r'D:\image\old.jpg']);
        final source = _LocalCountingSource(_png, r'D:\image\sample.jpg');
        final hit = await pipeline.decodeMediaThumbnail(source, const Size.square(50), 1, BoxFit.cover);
        expect(hit, isNotNull);
        expect(hit!.bucketWidth, 128, reason: '512×256 cover 50×50 需要约 100px 原图宽，进 128 桶');
        expect(hit.originalWidth, 512);
        expect(hit.originalHeight, 256);
        expect(source.loadCount, 0, reason: '系统缩略图路径不得读取 MB 级原始文件');
        expect(pipeline.debugMediaThumbnailHits, 1);
        expect(pipeline.debugMediaThumbnailMisses, 0);
        expect(pipeline.debugBitmapLimitBytes, greaterThan(128 << 20));
        expect(pipeline.debugBitmapCount, 1, reason: '只缓存布局所需清晰桶，不额外生成低清 fallback');
        expect(pipeline.debugBitmapBytes, greaterThan(0));
        expect(pipeline.debugFallbackBitmapCount, 0);
        expect(pipeline.debugFallbackBitmapBytes, 0);
        final cached = pipeline.findCached(source);
        expect(cached, isNotNull);
        expect(cached!.bucketWidth, 128);
        expect(thumbnailArguments?['engine'], 'glide');
        expect(thumbnailArguments?['fit'], 'cover');
        final rgba = await hit.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        expect(rgba!.buffer.asUint8List(rgba.offsetInBytes, 4), <int>[
          0xe1,
          0x27,
          0x58,
          0xff,
        ], reason: 'Android copyPixelsToBuffer 的 RGBA 通道不得被错当 BGRA 交换红蓝');
      });
    } finally {
      debugDefaultTargetPlatformOverride = null;
      pipeline.debugResetPlatformTuning();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.el.ui/image'),
        null,
      );
    }
  });

  testWidgets('descriptor 与 decode 的并发去重：同 key 合并为一次加载', (tester) async {
    await tester.runAsync(() async {
      final source = _CountingSource(_png);
      final results = await Future.wait([
        pipeline.descriptorFor(source),
        pipeline.descriptorFor(source),
        pipeline.descriptorFor(source),
      ]);
      expect(source.loadCount, 1, reason: 'in-flight 去重：三次并发只读一次字节');
      expect(results.every((r) => r.width == 1 && r.height == 1), isTrue);

      final images = await Future.wait([pipeline.decode(source, 64), pipeline.decode(source, 64)]);
      expect(identical(images[0], images[1]), isTrue, reason: '同桶并发解码合并');
      expect(pipeline.debugBitmapCount, 1);
    });
  });

  testWidgets('桶单调复用：小桶请求直接复用已有大桶位图，不重解', (tester) async {
    await tester.runAsync(() async {
      final source = _CountingSource(_png);
      final big = await pipeline.decode(source, 256);
      expect(pipeline.debugBitmapCount, 1);
      final hit = pipeline.findCached(source);
      expect(hit, isNotNull);
      expect(identical(hit!.image, big), isTrue, reason: '重挂同步命中同一缓存位图');
      expect(hit.bucketWidth, 1, reason: '原图小于请求桶时记录真实解码宽');
      expect(hit.originalWidth, 1);
      expect(hit.originalHeight, 1);
      final small = await pipeline.decode(source, 64);
      expect(identical(big, small), isTrue, reason: '>=目标桶的位图直接复用');
      expect(pipeline.debugBitmapCount, 1, reason: '未产生新解码条目');
    });
  });

  testWidgets('驱逐竞态回归：极小上限下 descriptor 被逐出，在途/后续解码仍全部成功', (tester) async {
    ImageDecodePipeline.debugMaxDescriptorBytesOverride = 1;
    addTearDown(() => ImageDecodePipeline.debugMaxDescriptorBytesOverride = null);
    await tester.runAsync(() async {
      final sources = [for (var i = 0; i < 6; i++) _CountingSource(_png)];
      final images = await Future.wait([
        for (final s in sources)
          pipeline.decode(s, 64).catchError((Object e, StackTrace st) {
            debugPrint('DECODE64 FAIL: $e');
            debugPrint('$st');
            throw e;
          }),
        for (final s in sources)
          pipeline.decode(s, 128).catchError((Object e, StackTrace st) {
            debugPrint('DECODE128 FAIL: $e');
            debugPrint('$st');
            throw e;
          }),
      ]);
      expect(images.every((img) => img != null && img.width == 1), isTrue);
      expect(pipeline.debugDescriptorCount, lessThanOrEqualTo(1), reason: '上限 1 下驱逐持续发生');
    });
  });

  testWidgets('取消：排队中的请求抛 ImageDecodeCanceled，不产出位图', (tester) async {
    await tester.runAsync(() async {
      final source = _CountingSource(_png);
      var canceled = true;
      Object? failure;
      try {
        await pipeline.decode(source, 64, isCanceled: () => canceled);
      } catch (e) {
        failure = e;
      }
      expect(failure, isA<ImageDecodeCanceled>());
      expect(pipeline.debugBitmapCount, 0, reason: '取消的请求不解码不进缓存');
      // 取消标志清除后重试成功（render 回退桶水位后的重试路径）。
      canceled = false;
      final image = await pipeline.decode(source, 64);
      expect(image, isNotNull);
    });
  });

  testWidgets('取消不传染：首个调用方取消后，共享 in-flight 的存活调用方仍解码成功', (tester) async {
    await tester.runAsync(() async {
      final source = _CountingSource(_png);
      // 首个调用方（滚出屏的 cell）已取消；第二个调用方（滚回的可见 cell）
      // 合并进同一 in-flight future——取消不得传染，存活方必须拿到位图。
      final f1 = pipeline.decode(source, 64, isCanceled: () => true);
      final f2 = pipeline.decode(source, 64, isCanceled: () => false);
      await expectLater(f1, throwsA(isA<ImageDecodeCanceled>()));
      final image = await f2;
      expect(image, isNotNull, reason: '存活调用方以自己的取消回调重试，不被首个调用方的取消拖死');
      expect(pipeline.debugBitmapCount, 1);
    });
  });

  testWidgets('descriptor 取消不传染：共享 in-flight 的存活调用方仍拿到原始尺寸', (tester) async {
    await tester.runAsync(() async {
      final source = _CountingSource(_png);
      final f1 = pipeline.descriptorFor(source, isCanceled: () => true);
      final f2 = pipeline.descriptorFor(source, isCanceled: () => false);
      await expectLater(f1, throwsA(isA<ImageDecodeCanceled>()));
      final info = await f2;
      expect(info.width, 1);
      expect(info.height, 1);
    });
  });

  testWidgets('慢源调度复现：可见优先 + 取消让急停恢复只付可见区成本', (tester) async {
    // 模拟真机量级：每次「读文件」10ms。40 个源全部入队（预挂载语义），
    // 随后 8 个源提升为可见——断言这 8 个先完成，且被取消的 20 个源一分
    // IO 都没付（loadCount == 0）。
    await tester.runAsync(() async {
      final visible = <String>{};
      var canceledFlag = false;
      final sources = [for (var i = 0; i < 40; i++) _SlowSource(_png, 'slow$i', const Duration(milliseconds: 10))];
      final done = <String>[];
      final futures = <Future<void>>[];
      for (final s in sources) {
        futures.add(
          pipeline
              .decode(
                s,
                64,
                isCanceled: () => canceledFlag && !visible.contains(s.key),
                isVisible: () => visible.contains(s.key),
              )
              .then((_) => done.add(s.key))
              .catchError((Object e) {
                if (e is! ImageDecodeCanceled) throw e;
              }),
        );
      }
      // 提升最后 8 个为「可见」，其余全部取消（模拟急停：可见区定格）。
      for (var i = 32; i < 40; i++) {
        visible.add(sources[i].key);
      }
      canceledFlag = true;
      await Future.wait(futures);
      // 可见的 8 个全部完成。
      expect(done.where(visible.contains).length, 8, reason: '可见源全部解码完成');
      // 被取消的源大多数一分 IO 未付（闸门排队中撤销；已开工的少数付了）。
      final canceledSources = sources.where((s) => !visible.contains(s.key));
      final neverLoaded = canceledSources.where((s) => s.loadCount == 0).length;
      expect(neverLoaded, greaterThan(15), reason: '排队中的废请求被撤销，未发生文件读取');
    });
  });

  testWidgets('目标桶不超原图：1px 图请求 512 桶按原尺寸解码', (tester) async {
    await tester.runAsync(() async {
      final source = _CountingSource(_png);
      final image = await pipeline.decode(source, 512);
      expect(image, isNotNull);
      expect(image!.width, 1);
    });
  });

  testWidgets('位图驱逐及时释放缓存 handle，不影响 Render 持有的 clone', (tester) async {
    ImageDecodePipeline.debugMaxBitmapBytesOverride = 1;
    addTearDown(() => ImageDecodePipeline.debugMaxBitmapBytesOverride = null);
    await tester.runAsync(() async {
      final first = await pipeline.decode(_CountingSource(_png), 64);
      final renderClone = first!.clone();
      await pipeline.decode(_CountingSource(_png), 64);
      expect(pipeline.debugBitmapCount, 1);
      expect(renderClone.width, 1, reason: '缓存原 handle 驱逐后，Render clone 必须继续有效');
      renderClone.dispose();
    });
  });
}

class _CountingSource extends ImageByteSource {
  _CountingSource(this.bytes);

  final Uint8List bytes;
  int loadCount = 0;

  @override
  String get key => 'test:counting:${identityHashCode(this)}';

  @override
  Future<Uint8List> load() async {
    loadCount++;
    return bytes;
  }
}

class _LocalCountingSource extends _CountingSource {
  _LocalCountingSource(super.bytes, this.path);

  final String path;

  @override
  String get localPath => path;
}

/// 慢速字节源：模拟真机 UFS 的文件读取延迟。
class _SlowSource extends ImageByteSource {
  _SlowSource(this.bytes, this.name, this.delay);

  final Uint8List bytes;
  final String name;
  final Duration delay;
  int loadCount = 0;

  @override
  String get key => 'slow:$name';

  @override
  Future<Uint8List> load() async {
    loadCount++;
    await Future<void>.delayed(delay);
    return bytes;
  }
}
