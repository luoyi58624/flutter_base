import 'dart:ui' as ui;

import 'package:example/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('最新 Demo 的主题时间线同步，但透明背景叠加产生截图中的色差', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: DemoTestApp()));
    await tester.pumpAndSettle();

    final boxes = find.byWidgetPredicate((widget) => widget is ElView && widget.style?.onDark?.backgroundColor != null);
    expect(boxes, findsNWidgets(2));
    final samples = <String>[];
    final lightBackground = el.desktopComponents.style!.vars![ElTokens.$bgColor] as Color;
    final darkBackground = el.desktopComponents.style!.onDark!.vars![ElTokens.$bgColor] as Color;

    void expectColorNear(Color actual, Color expected, String reason) {
      for (final channel in [
        (actual.a, expected.a),
        (actual.r, expected.r),
        (actual.g, expected.g),
        (actual.b, expected.b),
      ]) {
        expect(channel.$1, closeTo(channel.$2, 2 / 255), reason: reason);
      }
    }

    Future<void> sample(String label, {bool expectDifferent = false, double? darkProgress}) async {
      final scaffold = find.byType(Scaffold);
      final material = tester.widget<Material>(find.descendant(of: scaffold, matching: find.byType(Material)).first);
      final background = material.color!;
      final colors = [
        for (var i = 0; i < 2; i++)
          tester.renderObject<ElRenderView>(boxes.at(i)).committedResolvedStyle.box.backgroundColor,
      ];
      // 读取无窗口渲染的真实像素，不能仅凭字段插值相等判断视觉同步。
      final pixels = (await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          Color pixel(Offset point) {
            final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
            return Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          }

          return [pixel(Offset(400, 400)), pixel(tester.getCenter(boxes.at(0))), pixel(tester.getCenter(boxes.at(1)))];
        } finally {
          image.dispose();
        }
      }))!;

      String hex(Color color) => color.toARGB32().toRadixString(16);
      samples.add(
        '$label Material=${hex(background)} ElView=${colors.map((c) => c == null ? "null" : hex(c)).join("/")} 像素=${pixels.map(hex).join("/")}',
      );
      expectColorNear(pixels.first, background, '$label Scaffold 实际背景');
      expect(colors[0], colors[1], reason: '$label 不同局部时长应服从相同主题时间线');
      expect(pixels[1], pixels[2], reason: '$label 两块方块的实际像素应一致');
      if (darkProgress != null) {
        expect((colors.first ?? Colors.transparent).a, closeTo(darkProgress, 1 / 255), reason: '$label 方块透明度进度');
        expectColorNear(background, Color.lerp(lightBackground, darkBackground, darkProgress)!, '$label Material 颜色进度');
      }
      expectColorNear(
        pixels[1],
        Color.alphaBlend(colors.first ?? Colors.transparent, pixels.first),
        '$label 方块像素应等于自身颜色叠加在当前 Scaffold 上的结果',
      );
      if (expectDifferent) {
        expect(pixels[1], isNot(pixels.first), reason: '$label 复现截图：方块与 Scaffold 存在可见色差');
      } else {
        expect(pixels[1], pixels.first, reason: '$label 稳态应与 Scaffold 一致');
      }
    }

    await sample('初始亮色');
    for (final dark in [true, false]) {
      tester.widget<Switch>(find.byType(Switch)).onChanged!(dark);
      await tester.pump();
      var elapsed = 0;
      for (final delta in [16, 34, 50, 50, 50]) {
        elapsed += delta;
        await tester.pump(Duration(milliseconds: delta));
        final progress = elapsed / 200;
        await sample(
          '$dark ${elapsed}ms',
          expectDifferent: elapsed < 200,
          darkProgress: dark ? progress : 1 - progress,
        );
      }
      await tester.pumpAndSettle();
      await sample('$dark 完成');
    }
    debugPrint(samples.join('\n'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
