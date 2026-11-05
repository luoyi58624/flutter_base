import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, kind, interval) in [
    ('touch-tap', PointerDeviceKind.touch, 0),
    ('touch-repeat', PointerDeviceKind.touch, 130),
    ('touch-burst', PointerDeviceKind.touch, 65),
    ('mouse-tap', PointerDeviceKind.mouse, 0),
    ('mouse-repeat', PointerDeviceKind.mouse, 65),
  ]) {
    testWidgets('首页卡片缩放轨迹 $name', (tester) async {
      var activations = 0;
      final key = GlobalKey();
      final background = Colors.white;
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Center(
            child: ElButtonView(
              key: key,
              onPressed: () => activations++,
              style: ElStyle(
                width: 200,
                height: 120,
                backgroundColor: background,
                transition: [.field(.backgroundColor, Duration(milliseconds: 100), Curves.easeOut)],
                onTap: .new(backgroundColor: background.deepen(10)),
              ).withTapScale(0.9),
            ),
          ),
        ),
      );
      final card = tester.renderObject<ElRenderView>(find.byKey(key));
      final point = card.localToGlobal(card.size.center(Offset.zero));
      final downs = interval == 0 ? [0] : List.generate(5, (index) => index * interval);
      final ups = downs.map((time) => time + 30).toList();
      final frames = <({int ms, double scale, int shade})>[];
      TestGesture? gesture;
      for (var ms = 0; ms <= downs.last + 240; ms += 5) {
        if (ms != 0) await tester.pump(Duration(milliseconds: 5));
        // 缩放由卡片自身绘制，直接读取这一帧提交的样式。
        final box = card.committedResolvedStyle.box;
        final scale = box.transform?.toMatrix4().entry(0, 0) ?? 1.0;
        final shade = box.backgroundColor!.toARGB32() & 0xff;
        frames.add((ms: ms, scale: scale, shade: shade));
        if (downs.contains(ms)) gesture = await tester.startGesture(point, kind: kind);
        if (ups.contains(ms)) await gesture!.up();
      }

      expect(activations, downs.length);
      expect(frames.every((frame) => frame.scale >= .8999 && frame.scale <= 1.0001), isTrue);
      final minimum = frames.reduce((a, b) => a.scale <= b.scale ? a : b);
      expect(minimum.scale, lessThan(kind == .touch ? .905 : .97));
      expect(
        frames.any((frame) => frame.ms > minimum.ms && frame.scale > minimum.scale + .002 && frame.scale < .999),
        isTrue,
      );
      expect(frames.last.scale, closeTo(1, .0001));
      expect(frames.any((frame) => frame.shade < 255), isTrue);
      expect(frames.last.shade, 255);
      if (name == 'mouse-tap') {
        expect(minimum.ms, ups.single);
        expect(frames.firstWhere((frame) => frame.ms > minimum.ms && frame.scale == 1).ms, minimum.ms + 100);
      }
      if (name == 'touch-burst') {
        // 下一次落指早于保持时间结束时，缩放应一直保持，五次激活仍分别执行。
        final held = frames.where((frame) => frame.ms >= 110 && frame.ms < downs.last + 100);
        expect(held.every((frame) => (frame.scale - .9).abs() < .0001), isTrue);
      }
      if (name == 'touch-repeat' || name == 'mouse-repeat') {
        for (final down in downs.skip(1)) {
          final index = down ~/ 5;
          final nextPress = frames.skip(index + 1).take(6);
          expect(frames[index].scale, lessThan(.998));
          expect(nextPress.any((frame) => frame.scale < frames[index].scale - .002), isTrue);
        }
      }
      debugPrintSynchronously(
        'SCALE_TRACE ${jsonEncode({
          'name': name,
          'downs': downs,
          'ups': ups,
          'activations': activations,
          'frames': [
            for (final frame in frames) [frame.ms, double.parse(frame.scale.toStringAsFixed(5)), frame.shade],
          ],
        })}',
      );
    });
  }
}
