import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final styleOrigin in [true, false]) {
      for (final composited in [true, false]) {
        testWidgets('方向原点：$direction，styleOrigin=$styleOrigin，composited=$composited', (tester) async {
          final boundaryKey = GlobalKey();
          final viewKey = GlobalKey();
          const red = Color(0xffff0000), blue = Color(0xff0000ff);
          const origin = AlignmentDirectional.topStart;
          await tester.pumpWidget(
            Directionality(
              textDirection: direction,
              child: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: ColoredBox(
                      color: blue,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ElView(
                          key: viewKey,
                          style: ElStyle(
                            width: 4,
                            height: 4,
                            bgColor: red,
                            textDirection: direction,
                            transform: styleOrigin
                                ? const ElTransform.scale(0.5)
                                : const ElTransform.scale(0.5).alignment(origin),
                            transformAlignment: styleOrigin ? origin : null,
                            filter: composited ? const ElFilter() : null,
                          ),
                          child: const SizedBox(width: 4, height: 4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final render = tester.renderObject<ElRenderView>(find.byKey(viewKey));
          final rtl = direction == TextDirection.rtl;
          expect(render.hitTest(BoxHitTestResult(), position: const Offset(1, 1)), !rtl);
          expect(render.hitTest(BoxHitTestResult(), position: const Offset(3, 1)), rtl);
          final boundaryOrigin = tester.getTopLeft(find.byKey(boundaryKey));
          expect(render.firstChild!.localToGlobal(Offset.zero), boundaryOrigin + Offset(rtl ? 4 : 2, 2));
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
              Color pixel(int x) {
                final index = (3 * image.width + x) * 4;
                return Color.fromARGB(
                  bytes.getUint8(index + 3),
                  bytes.getUint8(index),
                  bytes.getUint8(index + 1),
                  bytes.getUint8(index + 2),
                );
              }

              expect(pixel(3), rtl ? blue : red);
              expect(pixel(5), rtl ? red : blue);
            } finally {
              image.dispose();
            }
          });
        });
      }
    }
  }
}
