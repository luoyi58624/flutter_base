import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('边缘深度保持感应带边界、末端矩形和坐标平移合同', () {
    final expected = <double, double>{80: -40, 100: -20, 119: -1, 120: 0, 200: 0, 280: 0, 281: 2, 300: 21, 380: 101};
    for (final entry in expected.entries) {
      expect(SelectionAutoScrollMath.edgeDepth(entry.key, 100, 300, 20), entry.value);
      expect(SelectionAutoScrollMath.edgeDepth(entry.key - 100, 0, 200, 20), entry.value);
    }
    expect(SelectionAutoScrollMath.edgeDepth(100, 100, 100, 20), 0);
    expect(SelectionAutoScrollMath.edgeDepth(400, 100, 300, 0), 0);
    expect(SelectionAutoScrollMath.edgeDepth(105, 100, 110, 100), 0);
  });

  test('桌面与触摸共享加速曲线，方向、起步、封顶与宿主容差保持独立', () {
    final mouse = SelectionAutoScrollConfig.mouse;
    expect(SelectionAutoScrollMath.frameDelta(0, mouse), 0);
    expect(SelectionAutoScrollMath.frameDelta(10, mouse), closeTo(14.95, 1e-9));
    expect(SelectionAutoScrollMath.frameDelta(-10, mouse), closeTo(-14.95, 1e-9));
    expect(SelectionAutoScrollMath.frameDelta(1000, mouse), 1000);
    expect(SelectionAutoScrollMath.frameDelta(.1, mouse, epsilon: .1), 0);
    expect(SelectionAutoScrollMath.frameDelta(.1, mouse), greaterThan(5));
    expect(SelectionAutoScrollMath.frameDelta(75, SelectionAutoScrollConfig.touch), 36);
    expect(SelectionAutoScrollMath.frameDelta(-150, SelectionAutoScrollConfig.touch), -132);
  });
}
