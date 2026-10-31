import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({int width, ByteData bytes})> _rasterize(WidgetTester tester, GlobalKey key) async {
  late final ({int width, ByteData bytes}) result;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      result = (width: image.width, bytes: (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!);
    } finally {
      image.dispose();
    }
  });
  return result;
}

Color _pixel(({int width, ByteData bytes}) raster, int x, int y) {
  final offset = (y * raster.width + x) * 4;
  return Color.fromARGB(
    raster.bytes.getUint8(offset + 3),
    raster.bytes.getUint8(offset),
    raster.bytes.getUint8(offset + 1),
    raster.bytes.getUint8(offset + 2),
  );
}

void main() {
  final foreground = Color(0xffff0000);
  final background = Color(0xff0000ff);
  final cases = <(double?, int)>[
    (null, 255),
    (0, 0),
    (-0.2, 0),
    (double.negativeInfinity, 0),
    (0.0001, 0),
    (0.5, 128),
    (0.9999, 255),
    (double.nan, 255),
    (double.infinity, 255),
  ];

  for (final filter in <ElFilter?>[null, ElFilter()]) {
    for (final (opacity, alpha) in cases) {
      testWidgets('opacity=$opacity，filter=${filter != null}：位移后的像素与最终 alpha 一致', (tester) async {
        final boundaryKey = GlobalKey();
        final viewKey = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: ColoredBox(
                    color: background,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ElView(
                        key: viewKey,
                        style: ElStyle(
                          width: 4,
                          height: 4,
                          backgroundColor: foreground,
                          opacity: opacity,
                          filter: filter,
                          transform: ElTransform.translateX(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byKey(viewKey));
        final partial = alpha > 0 && alpha < 255;
        expect(render.alwaysNeedsCompositing, filter != null || partial);
        expect(render.isRepaintBoundary, filter == null && partial);

        final raster = await _rasterize(tester, boundaryKey);
        final expected = Color.alphaBlend(foreground.withAlpha(alpha), background);
        final inside = _pixel(raster, 3, 1);
        expect(inside.r, closeTo(expected.r, 1 / 255));
        expect(inside.g, closeTo(expected.g, 1 / 255));
        expect(inside.b, closeTo(expected.b, 1 / 255));
        expect(inside.a, 1);
        expect(_pixel(raster, 0, 1), background, reason: '位移后左侧仍是底色');
      });
    }
  }

  testWidgets('量化为不透明的普通声明不创建绘制控制器', (tester) async {
    final key = GlobalKey();
    for (final opacity in <double?>[null, 1, 0.9999, double.nan, double.infinity]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ElView(
              key: key,
              style: ElStyle(opacity: opacity),
              child: SizedBox(width: 4, height: 4),
            ),
          ),
        ),
      );
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(render.paintControllerForTest, isNull, reason: 'opacity=$opacity');
      expect(render.isRepaintBoundary, isFalse);
    }
  });
}
