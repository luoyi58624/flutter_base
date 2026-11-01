import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/ui/mobile/components/slider/value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web 步长从 min 起算，小数、负数及不能整除的上界保持合法', () {
    final scale = SliderScale(-.3, .9, .2, true);
    expect(scale.normalize(.3), .3);
    expect(scale.normalize(10), .9);
    expect(scale.normalize(-10), -.3);
    expect(scale.points.map((p) => p.value), [-.3, -.1, .1, .3, .5, .7, .9]);
    expect(SliderScale(3, 55, 7, true).normalize(55), 52);
  });

  test('Web 显式刻度排序去重，最后标签优先，过滤非法值且不改变原数组', () {
    final points = [
      ElSliderMark(value: 100),
      ElSliderMark(value: 20, label: '旧'),
      ElSliderMark(value: 37),
      ElSliderMark(value: -1),
      ElSliderMark(value: double.nan),
      ElSliderMark(value: 20, label: '20°C'),
      ElSliderMark(value: 0),
    ];
    final before = List.of(points);
    final scale = SliderScale(0, 100, null, points);
    expect(scale.points.map((p) => p.value), [0, 20, 37, 100]);
    expect(scale.points[1].label, '20°C');
    expect(scale.normalize(35), 37);
    expect(points, before);
  });

  test('Web 自定义刻度不覆盖 step，空限制集与退化区间禁用', () {
    expect(SliderScale(0, 100, 10, [ElSliderMark(value: 37)]).normalize(37), 40);
    expect(SliderScale(0, 100, null, []).disabled, isTrue);
    expect(SliderScale(20, -10, 1, true).disabled, isTrue);
    expect(SliderScale(0, 100, -1, false).normalize(37.4), 37);
  });

  test('Web 中点对称切换，恰好中点选择后一档', () {
    final scale = SliderScale(0, 100, null, [
      for (final v in [0.0, 20.0, 37.0, 100.0]) ElSliderMark(value: v),
    ]);
    for (final (raw, expected) in [(9.99, 0), (10.0, 20), (28.49, 20), (28.5, 37), (68.49, 37), (68.5, 100)]) {
      expect(scale.normalize(raw), expected);
    }
    expect(SliderScale(0, 100, 10, true).normalize(25), 30);
  });

  test('Web 极小步长抽稀展示点，不改变数值精度', () {
    final scale = SliderScale(0, 100, .00000001, true);
    expect(scale.points.length, lessThanOrEqualTo(1002));
    expect(scale.normalize(12.34567891), 12.34567891);
    expect(SliderScale(0, 100, 1e-320, true).normalize(36), 36);
    expect(SliderScale(-1e308, 1e308, 1, true).disabled, isTrue);
  });
}
