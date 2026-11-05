import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/image/image_byte_source.dart';
import 'package:flutter_base/src/flutter/views/image/image_decode_pipeline.dart';
import 'package:flutter_base/src/flutter/views/image/render/render_image_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// ElImageView P2：占位层 / 错误态 / onLoad / onError。
/// widget 测试里图片解码在 fake-async 下不推进，须 tester.runAsync 驱动。
final Uint8List _validPng = Uint8List.fromList(<int>[
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

final Uint8List _garbageBytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

Future<Uint8List> _createPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), ui.Paint());
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// 驱动两段式管线走完全程：descriptor(真实异步) → 一帧 layout 发起 decode →
/// decode(真实异步) → post-frame 相位上报 → setState 重建。多轮推进兜住全部时序。
Future<void> _settleImage(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  testWidgets('placeholder 在解码完成前显示，完成后替换为图片并回调 onLoad', (tester) async {
    ImageLoadInfo? loaded;
    final view = ElImageView.memory(
      _validPng,
      width: 40,
      height: 40,
      placeholder: const ElView(key: ValueKey('ph'), child: 'loading'),
      onLoad: (info) => loaded = info,
    );
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: view));
    // 解码未完成：占位可见（随显式宽高占位）。
    expect(find.byKey(const ValueKey('ph')), findsOneWidget);
    expect(loaded, isNull);
    await _settleImage(tester);
    expect(find.byKey(const ValueKey('ph')), findsNothing);
    expect(loaded, isNotNull);
    expect(loaded!.width, 1);
    expect(loaded!.height, 1);
  });

  testWidgets('解码失败显示 error 并回调 onError', (tester) async {
    Object? failure;
    final view = ElImageView.memory(
      _garbageBytes,
      width: 40,
      height: 40,
      error: const ElView(key: ValueKey('err'), child: 'broken'),
      onError: (e) => failure = e,
    );
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: view));
    await _settleImage(tester);
    expect(find.byKey(const ValueKey('err')), findsOneWidget);
    expect(failure, isNotNull);
  });

  testWidgets('换 src 后新图重新上报 ready：占位层再次揭开、onLoad 再次回调', (tester) async {
    final loads = <ImageLoadInfo>[];
    Widget build(Uint8List bytes) => Directionality(
      textDirection: TextDirection.ltr,
      child: ElImageView.memory(
        bytes,
        width: 40,
        height: 40,
        placeholder: const ElView(key: ValueKey('ph'), child: 'loading'),
        onLoad: loads.add,
      ),
    );
    await tester.pumpWidget(build(_validPng));
    await _settleImage(tester);
    expect(loads, hasLength(1));
    expect(find.byKey(const ValueKey('ph')), findsNothing);

    // 换源（新字节实例 = 新 provider + 新 byteSource key）：外壳相位回
    // loading，新图解码完成后必须再次上报 ready——否则占位层永久盖住新图。
    await tester.pumpWidget(build(Uint8List.fromList(_validPng)));
    await _settleImage(tester);
    expect(loads, hasLength(2), reason: '换 src 后 ready 相位必须重新上报');
    expect(find.byKey(const ValueKey('ph')), findsNothing, reason: '占位层不得永久盖住已加载的新图');
  });

  testWidgets('无占位/回调配置走零开销直挂路径（不监听流，行为同旧版）', (tester) async {
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: ElImageView.memory(_validPng, width: 40, height: 40)),
    );
    expect(find.byType(ElImageView), findsOneWidget);
    await _settleImage(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event 直接由图片 render 响应点击，无需外包 ElView', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElImageView.memory(_validPng, width: 80, height: 80, event: ElEvent(onTap: (_) => taps++)),
      ),
    );
    await tester.tap(find.byType(ElImageView));
    expect(taps, 1);
  });

  testWidgets('解码尺寸随布局约束与 cover 比例自适应，不使用固定预览尺寸', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await tester.runAsync(() => _createPng(512, 256));
    expect(bytes, isNotNull);

    Widget build(double extent) => Directionality(
      textDirection: TextDirection.ltr,
      child: ElView(
        style: const ElStyle(alignment: .center),
        child: ElImageView.memory(bytes!, width: extent, height: extent, fit: .cover),
      ),
    );

    await tester.pumpWidget(build(50));
    await _settleImage(tester);
    var render = tester.renderObject<RenderImageView>(find.byType(ElImageView));
    expect(render.image, isNotNull);
    expect(render.debugDecodedBucket, 128, reason: '512×256 cover 50×50 需要约 100px 宽，按 32px 桶取 128');

    await tester.pumpWidget(build(120));
    await _settleImage(tester);
    render = tester.renderObject<RenderImageView>(find.byType(ElImageView));
    expect(render.debugDecodedBucket, 256, reason: '布局放大后必须重新按约束解码，不能复用固定尺寸预览');
  });

  testWidgets('多图窗口放大时完成桶只跟随实际位图，排队请求不能冒充高清结果', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final encoded = await tester.runAsync(() => _createPng(4096, 2048));
    expect(encoded, isNotNull);
    final sources = [for (var i = 0; i < 10; i++) Uint8List.fromList(encoded!)];
    late StateSetter resize;
    var hostWidth = 508.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: StatefulBuilder(
            builder: (context, setState) {
              resize = setState;
              const columns = 5;
              const gap = 2.0;
              final extent = (hostWidth - (columns - 1) * gap) / columns;
              return SizedBox(
                width: hostWidth,
                height: extent * 2 + gap,
                child: ElGridView(
                  crossAxisCount: columns,
                  gap: gap,
                  children: [
                    for (var i = 0; i < sources.length; i++)
                      ElImageView.memory(
                        sources[i],
                        key: ValueKey('queued-resize-image-$i'),
                        width: extent,
                        height: extent,
                        fit: .cover,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
      final ready = [
        for (var j = 0; j < sources.length; j++)
          tester.renderObject<RenderImageView>(find.byKey(ValueKey('queued-resize-image-$j'))).image != null,
      ];
      if (ready.every((value) => value)) break;
    }
    final smallBuckets = <int>[];
    final smallImageWidths = <int>[];
    for (var i = 0; i < sources.length; i++) {
      final render = tester.renderObject<RenderImageView>(find.byKey(ValueKey('queued-resize-image-$i')));
      expect(render.image, isNotNull);
      smallBuckets.add(render.debugDecodedBucket);
      smallImageWidths.add(render.image!.width);
    }

    resize(() => hostWidth = 1508);
    await tester.pump();

    var queuedCount = 0;
    for (var i = 0; i < sources.length; i++) {
      final render = tester.renderObject<RenderImageView>(find.byKey(ValueKey('queued-resize-image-$i')));
      if (render.image!.width != smallImageWidths[i]) continue;
      queuedCount++;
      expect(render.debugDecodedBucket, smallBuckets[i], reason: '高清结果尚未替换旧位图时，完成桶不得提前冒充新的布局目标');
    }
    expect(queuedCount, greaterThan(0), reason: '10 张独立图片应覆盖至少一张仍在高清解码队列中的节点');

    for (var i = 0; i < 160; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
      final upgraded = [
        for (var j = 0; j < sources.length; j++)
          tester.renderObject<RenderImageView>(find.byKey(ValueKey('queued-resize-image-$j'))).image!.width >
              smallImageWidths[j],
      ];
      if (upgraded.every((value) => value)) break;
    }
    for (var i = 0; i < sources.length; i++) {
      final render = tester.renderObject<RenderImageView>(find.byKey(ValueKey('queued-resize-image-$i')));
      expect(render.image!.width, greaterThan(smallImageWidths[i]), reason: '窗口放大后每张可见图片都必须真正换成高清位图');
      expect(render.debugDecodedBucket, greaterThan(smallBuckets[i]));
    }
  });

  testWidgets('虚拟网格随桌面窗口放大时升级已挂载图片的清晰解码桶', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1800, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final bytes = await tester.runAsync(() => _createPng(2048, 1024));
    expect(bytes, isNotNull);
    late StateSetter resize;
    var hostWidth = 258.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: StatefulBuilder(
            builder: (context, setState) {
              resize = setState;
              const columns = 5;
              const gap = 2.0;
              final extent = (hostWidth - (columns - 1) * gap) / columns;
              return SizedBox(
                width: hostWidth,
                height: 300,
                child: ElScrollView(
                  children: [
                    ElGridView.builder(
                      crossAxisCount: columns,
                      mainAxisExtent: extent,
                      rowGap: gap,
                      columnGap: gap,
                      itemCount: 20,
                      itemBuilder: (_, index) => ElImageView.memory(
                        bytes!,
                        key: ValueKey('resize-image-$index'),
                        width: extent,
                        height: extent,
                        fit: .cover,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await _settleImage(tester);
    var render = tester.renderObject<RenderImageView>(find.byKey(const ValueKey('resize-image-0')));
    final smallBucket = render.debugDecodedBucket;
    final smallImageWidth = render.image!.width;

    resize(() => hostWidth = 1508);
    await tester.pump();
    await _settleImage(tester);
    render = tester.renderObject<RenderImageView>(find.byKey(const ValueKey('resize-image-0')));

    expect(render.size.width, greaterThan(100));
    expect(render.debugDecodedBucket, greaterThan(smallBucket), reason: '窗口放大后必须按新网格约束请求更大的解码桶');
    expect(render.image!.width, greaterThan(smallImageWidth), reason: '绘制位图必须真正替换为更高分辨率，不能只放大旧缓存');
  });

  testWidgets('窗口 resize 后滚出视口但仍预挂载的图片不再占用可见解码优先级', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final bytes = await tester.runAsync(() => _createPng(512, 256));
    expect(bytes, isNotNull);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late StateSetter resize;
    var hostWidth = 408.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: StatefulBuilder(
            builder: (context, setState) {
              resize = setState;
              const columns = 5;
              const gap = 2.0;
              final extent = (hostWidth - (columns - 1) * gap) / columns;
              return SizedBox(
                width: hostWidth,
                height: 180,
                child: ElScrollView(
                  controller: controller,
                  cacheExtent: 300,
                  children: [
                    ElGridView.builder(
                      crossAxisCount: columns,
                      mainAxisExtent: extent,
                      rowGap: gap,
                      columnGap: gap,
                      itemCount: 30,
                      itemBuilder: (_, index) => ElImageView.memory(
                        bytes!,
                        key: ValueKey('priority-resize-image-$index'),
                        width: extent,
                        height: extent,
                        fit: .cover,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await _settleImage(tester);
    final firstFinder = find.byKey(const ValueKey('priority-resize-image-0'), skipOffstage: false);
    expect(tester.renderObject<RenderImageView>(firstFinder).debugDecodeIsVisible, isTrue);

    controller.jumpTo(260);
    await tester.pump();
    expect(firstFinder, findsOneWidget, reason: '首项应留在 cacheExtent 内，才能复现陈旧可见优先级');
    expect(tester.getBottomLeft(firstFinder).dy, lessThanOrEqualTo(0));
    expect(tester.renderObject<RenderImageView>(firstFinder).debugDecodePriority, 0);
    expect(tester.renderObject<RenderImageView>(firstFinder).debugDecodeIsVisible, isFalse);

    resize(() => hostWidth = 608);
    await tester.pump();

    final viewportRect = Rect.fromLTWH(0, 0, hostWidth, 180);
    final offscreen = <RenderImageView>[
      for (final element in find.byType(ElImageView).evaluate())
        if (element.renderObject case final RenderImageView render)
          if (!(render.localToGlobal(Offset.zero) & render.size).overlaps(viewportRect)) render,
    ];
    expect(offscreen, isNotEmpty, reason: 'resize 后必须保留 cacheExtent 图片才能覆盖优先级回归');
    expect(
      offscreen.every((render) => !render.debugDecodeIsVisible),
      isTrue,
      reason: 'resize 后未绘制的缓存项不能继续和当前可见图片争抢清晰桶解码槽',
    );
  });

  testWidgets('缓存驱逐后重挂重新解码清晰桶，不显示低清保底图', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final pipeline = ImageDecodePipeline.instance..debugClear();
    ImageDecodePipeline.debugMaxBitmapBytesOverride = 180 << 10;
    try {
      final first = await tester.runAsync(() => _createPng(512, 256));
      final second = await tester.runAsync(() => _createPng(512, 256));
      expect(first, isNotNull);
      expect(second, isNotNull);
      await tester.runAsync(() async {
        await pipeline.decode(MemoryByteSource(first!), 256);
        await pipeline.decode(MemoryByteSource(second!), 256);
      });
      expect(pipeline.debugBitmapCount, 1, reason: '极小缓存预算下第一张清晰图会被驱逐');
      expect(pipeline.debugFallbackBitmapCount, 0);
      expect(pipeline.debugFallbackBitmapBytes, 0);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ElView(
            style: const ElStyle(alignment: .center),
            child: ElImageView.memory(first!, width: 120, height: 120, fit: .cover),
          ),
        ),
      );
      await tester.pump();
      var render = tester.renderObject<RenderImageView>(find.byType(ElImageView));
      expect(render.image, isNull, reason: '清晰缓存被驱逐后不得同步显示低清保底图');

      await _settleImage(tester);
      render = tester.renderObject<RenderImageView>(find.byType(ElImageView));
      expect(render.debugDecodedBucket, 256);
      expect(render.image!.width, 256, reason: '重挂后必须重新解码到布局所需清晰桶');
    } finally {
      ImageDecodePipeline.debugMaxBitmapBytesOverride = null;
      pipeline.debugClear();
    }
  });
}
