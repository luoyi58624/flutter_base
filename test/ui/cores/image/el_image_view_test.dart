import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/image/render/render_image.dart';
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

/// 驱动加载走完全程：layout 发起解析 → 解码(真实异步) → post-frame 相位上报 → setState 重建。
/// 多轮推进兜住全部时序。
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

    // 换源（新字节实例 = 新 provider）：外壳相位回
    // loading，新图解码完成后必须再次上报 ready——否则占位层永久盖住新图。
    await tester.pumpWidget(build(Uint8List.fromList(_validPng)));
    await _settleImage(tester);
    expect(loads, hasLength(2), reason: '换 src 后 ready 相位必须重新上报');
    expect(find.byKey(const ValueKey('ph')), findsNothing, reason: '占位层不得永久盖住已加载的新图');
  });

  testWidgets('无占位/回调配置走零开销直挂路径（不额外订阅相位）', (tester) async {
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
  testWidgets('解码尺寸随布局约束与 cover 比例自适应，只升不降', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await tester.runAsync(() => _createPng(512, 256));
    expect(bytes, isNotNull);

    Widget build(double extent) => Directionality(
      textDirection: TextDirection.ltr,
      child: ElView(
        style: ElStyle(alignment: .center),
        child: ElImageView.memory(bytes!, width: extent, height: extent, fit: .cover),
      ),
    );

    ElRenderImage render() => tester.renderObject<ElRenderImage>(find.byType(ElImageView));

    await tester.pumpWidget(build(50));
    await _settleImage(tester);
    expect(render().image, isNotNull);
    expect(render().debugBox, (w: 64, h: 64), reason: '50 逻辑像素按 32px 桶取 64');
    expect(render().image!.width, 128, reason: '512×256 cover 64×64 需要高 64，即 128×64');
    expect(render().image!.height, 64);

    await tester.pumpWidget(build(120));
    await _settleImage(tester);
    expect(render().image!.width, 256, reason: '布局放大后必须重新按约束解码');

    await tester.pumpWidget(build(50));
    await _settleImage(tester);
    expect(render().image!.width, 256, reason: '布局变小不重复解码，沿用已有更清晰的位图');
  });

  testWidgets('onLoad 上报原图尺寸而不是降采样后的尺寸', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await tester.runAsync(() => _createPng(512, 256));
    ImageLoadInfo? loaded;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElView(
          style: ElStyle(alignment: .center),
          child: ElImageView.memory(bytes!, width: 50, height: 50, fit: .cover, onLoad: (info) => loaded = info),
        ),
      ),
    );
    await _settleImage(tester);
    expect(loaded?.width, 512);
    expect(loaded?.height, 256);
  });

  testWidgets('没有确定布局框时按原尺寸解码', (tester) async {
    final bytes = await tester.runAsync(() => _createPng(300, 200));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UnconstrainedBox(child: ElImageView.memory(bytes!)),
      ),
    );
    await _settleImage(tester);
    final render = tester.renderObject<ElRenderImage>(find.byType(ElImageView));
    expect(render.debugBox, (w: 0, h: 0));
    expect(render.image!.width, 300);
  });
}
