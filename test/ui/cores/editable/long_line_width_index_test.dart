import 'package:flutter_base/src/flutter/views/editable/render/long_line_width_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('局部实测只修正该区间，宽窄变化都进入尾部范围', () {
    final index = LongLineWidthIndex(10);
    index.record([100, 150, 200], [1000, 1250, 1400]);
    expect(index.xForOffset(50), 500);
    expect(index.xForOffset(125), 1125);
    expect(index.xForOffset(175), 1325);
    expect(index.xForOffset(300), 2400);
    expect(index.offsetForX(1125, 300), 125);
    expect(index.offsetForX(2400, 300), 300);
    index.record([100, 200], [1000, 2200]);
    expect(index.xForOffset(300), 3200);
    expect(index.offsetForX(4000, 300), 300);
  });

  test('重叠区间保留锚点且顺序字宽查询与前缀差一致', () {
    final index = LongLineWidthIndex(10);
    index.record([100, 150, 200], [1000, 1250, 1500]);
    expect(index.anchorIn(140, 190, 165), 150);
    index.record([125, 150, 175], [1125, 1250, 1400]);
    expect(index.xForOffset(150), 1250);
    expect(index.xForOffset(200), 1525);
    for (var offset = 0; offset < 260; offset++) {
      expect(index.advanceAt(offset), closeTo(index.xForOffset(offset + 1) - index.xForOffset(offset), 1e-9));
    }
  });

  test('超过缓存容量只合并内部细节，已测行尾和总宽不回退成初始估算', () {
    final index = LongLineWidthIndex(10);
    var total = 0.0;
    for (var i = 0; i < 2048; i++) {
      final next = total + (i.isEven ? 3000 : 7000);
      index.record([i * 1024, (i + 1) * 1024], [total, next]);
      total = next;
      expect(index.length, lessThanOrEqualTo(LongLineWidthIndex.capacity));
      expect(index.xForOffset((i + 1) * 1024), total);
      expect(index.offsetForX(total, 2048 * 1024), (i + 1) * 1024);
    }
    expect(index.xForOffset(2048 * 1024 + 100), total + 1000);
    expect(index.xForOffset(0), 0);
  });

  test('零宽区间与极长未测尾部的反查保持有限且单调', () {
    final index = LongLineWidthIndex(8);
    index.record([0, 10, 20, 30], [0, 80, 80, 160]);
    expect(index.offsetForX(80, 1000000000), 10);
    expect(index.offsetForX(81, 1000000000), 21);
    expect(index.offsetForX(-10, 1000000000), 0);
    expect(index.offsetForX(index.xForOffset(1000000000), 1000000000), 1000000000);
    expect(index.length, 4);
  });

  test('切窗校正越过旧插值节点时合并近似段，反查仍单调', () {
    final index = LongLineWidthIndex(10);
    index.record([100, 200], [1000, 2000]);
    index.record([125, 150, 175], [900, 1500, 1800]);
    expect(index.xForOffset(0), 0);
    expect(index.xForOffset(150), 1500);
    expect(index.xForOffset(200), 2050);
    for (var offset = 1; offset < 240; offset++) {
      expect(index.xForOffset(offset), greaterThanOrEqualTo(index.xForOffset(offset - 1)));
    }
  });
}
