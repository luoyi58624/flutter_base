import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

List<BoxShadow> _resolve({
  ElLevelType level = ElLevelType.md,
  Brightness brightness = Brightness.light,
  Color surface = Colors.white,
  Color background = Colors.white,
  Size size = const Size(180, 120),
  BorderRadius radius = BorderRadius.zero,
  double strength = 1,
  double softness = 1,
}) => ElShadow.resolve(
  level: level,
  brightness: brightness,
  surfaceColor: surface,
  backgroundColor: background,
  size: size,
  borderRadius: radius,
  strength: strength,
  softness: softness,
);

void main() {
  test('五档层级逐渐增加悬浮距离，xs 单层，其余双层，结果只读', () {
    var previousOffset = 0.0;
    var previousBlur = 0.0;
    for (final level in ElLevelType.types) {
      final shadows = _resolve(level: level);
      expect(shadows.length, level == ElLevelType.xs ? 1 : 2);
      expect(shadows.last.offset.dy, greaterThan(previousOffset));
      expect(shadows.last.blurRadius, greaterThan(previousBlur));
      expect(() => shadows.clear(), throwsUnsupportedError);
      previousOffset = shadows.last.offset.dy;
      previousBlur = shadows.last.blurRadius;
    }
  });

  test('实际背景亮度决定主要补偿，同色表面保留更强的近层支撑', () {
    final white = _resolve();
    final dark = _resolve(surface: Color(0xff252931), background: Color(0xff252931));
    final contrast = _resolve(surface: Colors.black);
    expect(dark.first.color.a, greaterThan(white.first.color.a));
    expect(white.first.color.a, greaterThan(contrast.first.color.a));
    expect(_resolve(brightness: Brightness.dark).first.color.a, lessThan(dark.first.color.a));
  });

  test('透明表面按承托背景合成，不使用原始透明颜色的亮度', () {
    final surface = Color(0x80ffffff), background = Color(0xff252931);
    expect(
      _resolve(surface: surface, background: background),
      _resolve(surface: Color.alphaBlend(surface, background), background: background),
    );
  });

  test('超限圆角先归一化，圆角连续变化时投影平稳变化', () {
    expect(
      _resolve(size: Size(100, 100), radius: BorderRadius.circular(500)),
      _resolve(size: Size(100, 100), radius: BorderRadius.circular(50)),
    );
    var previous = _resolve();
    for (var radius = 1.0; radius <= 60; radius++) {
      final current = _resolve(radius: BorderRadius.circular(radius));
      expect((current.last.blurRadius - previous.last.blurRadius).abs(), lessThan(.1));
      expect((current.first.color.a - previous.first.color.a).abs(), lessThan(.005));
      previous = current;
    }
  });

  test('极小组件限制扩散和收缩，强度与柔和调节不产生非法投影', () {
    for (final size in [Size(8, 8), Size(48, 240), Size(320, 180)]) {
      for (final level in ElLevelType.types) {
        final shadows = _resolve(level: level, size: size, strength: 3, softness: 8);
        for (final shadow in shadows) {
          expect(shadow.blurRadius.isFinite, isTrue);
          expect(shadow.blurRadius, inInclusiveRange(0, size.shortestSide * .45));
          expect(shadow.spreadRadius, greaterThan(-size.shortestSide / 2));
          expect(shadow.color.a, inInclusiveRange(0, .55));
        }
      }
    }
  });

  test('零强度、透明表面和空尺寸不投影，非法参数明确拒绝', () {
    expect(_resolve(strength: 0), isEmpty);
    expect(_resolve(surface: Colors.transparent), isEmpty);
    expect(_resolve(size: Size.zero), isEmpty);
    expect(() => _resolve(softness: 0), throwsArgumentError);
    expect(() => _resolve(strength: double.nan), throwsArgumentError);
    expect(() => _resolve(size: Size(double.infinity, 100)), throwsArgumentError);
    expect(() => _resolve(radius: BorderRadius.circular(-1)), throwsArgumentError);
    expect(() => _resolve(background: Colors.transparent), throwsArgumentError);
  });
}
