import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/widgets/image/sized_image.dart';
import 'package:flutter_test/flutter_test.dart';

SizedImage _sized({int w = 0, int h = 0, BoxFit fit = BoxFit.cover}) =>
    SizedImage(MemoryImage(Uint8List(0)), boxWidth: w, boxHeight: h, fit: fit);

void main() {
  group('SizedImage.bucketOf', () {
    test('按 32 物理像素向上取桶，无限或非正数为 0', () {
      expect(SizedImage.bucketOf(50, 1), 64);
      expect(SizedImage.bucketOf(64, 1), 64);
      expect(SizedImage.bucketOf(65, 1), 96);
      expect(SizedImage.bucketOf(100, 2), 224);
      expect(SizedImage.bucketOf(double.infinity, 2), 0);
      expect(SizedImage.bucketOf(0, 2), 0);
    });
  });

  group('SizedImage.targetFor', () {
    test('cover 取大比例保证铺满，不被降采样压糊', () {
      final t = _sized(w: 100, h: 100).targetFor(1000, 500);
      expect((t.width, t.height), (200, 100));
    });

    test('contain / scaleDown 取小比例保证放得下', () {
      final t = _sized(w: 100, h: 100, fit: BoxFit.contain).targetFor(1000, 500);
      expect((t.width, t.height), (100, 50));
    });

    test('fitWidth / fitHeight 只看对应轴', () {
      final w = _sized(w: 100, h: 10, fit: BoxFit.fitWidth).targetFor(1000, 500);
      expect((w.width, w.height), (100, 50));
      final h = _sized(w: 10, h: 100, fit: BoxFit.fitHeight).targetFor(1000, 500);
      expect((h.width, h.height), (200, 100));
    });

    test('单轴受限时只由该轴决定', () {
      final t = _sized(w: 250).targetFor(1000, 500);
      expect((t.width, t.height), (250, 125));
    });

    test('不放大：布局框大于原图、none、无约束都保持原尺寸', () {
      for (final s in [_sized(w: 2000, h: 2000), _sized(w: 100, h: 100, fit: BoxFit.none), _sized()]) {
        final t = s.targetFor(1000, 500);
        expect((t.width, t.height), (null, null));
      }
    });

    test('fill 两轴各自限制，且不放大', () {
      final t = _sized(w: 100, h: 800, fit: BoxFit.fill).targetFor(1000, 500);
      expect((t.width, t.height), (100, null));
    });
  });
}
