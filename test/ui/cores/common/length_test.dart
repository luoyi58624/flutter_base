import 'package:flutter_base/src/ui/cores/view/style/dimension.dart';
import 'package:flutter_test/flutter_test.dart';

/// `ElDimension` 值类型单测：parse / resolve / lerp / 比较。
void main() {
  group('ElDimension.parse', () {
    test('null → null（"未声明"统一用 null 表达，不再转 auto sentinel）', () {
      expect(ElDimension.parse(null), isNull);
    });

    test('num → pixels', () {
      expect(ElDimension.parse(80), const ElDimension.pixels(80));
      expect(ElDimension.parse(80.5), const ElDimension.pixels(80.5));
      expect(ElDimension.parse(0), const ElDimension.pixels(0));
    });

    test("'N%' → percent", () {
      expect(ElDimension.parse('80%'), const ElDimension.percent(80));
      expect(ElDimension.parse('100%'), const ElDimension.percent(100));
      expect(ElDimension.parse('  50% '), const ElDimension.percent(50));
      expect(ElDimension.parse('33.5%'), const ElDimension.percent(33.5));
    });

    test("'N'（无 %） → pixels", () {
      expect(ElDimension.parse('80'), const ElDimension.pixels(80));
      expect(ElDimension.parse('80.5'), const ElDimension.pixels(80.5));
    });

    test('不支持的字符串 → null（容错，等价"未声明"）', () {
      expect(ElDimension.parse('auto'), isNull);
      expect(ElDimension.parse('calc(100% - 8px)'), isNull);
      expect(ElDimension.parse('bad'), isNull);
      expect(ElDimension.parse('%'), isNull);
      expect(ElDimension.parse(''), isNull);
    });

    test('passthrough：传非 auto ElDimension 直接返回', () {
      const v = ElDimension.percent(50);
      expect(identical(ElDimension.parse(v), v), isTrue);
    });

    test('passthrough：显式 ElDimension.auto → null（auto 也归一化）', () {
      expect(ElDimension.parse(ElDimension.auto), isNull);
    });
  });

  group('ElDimension.resolve', () {
    test('auto → null', () {
      expect(ElDimension.auto.resolve(200), isNull);
    });

    test('pixels → 原值（不受 available 影响）', () {
      expect(const ElDimension.pixels(120).resolve(200), 120);
      expect(const ElDimension.pixels(120).resolve(double.infinity), 120);
    });

    test('percent → available × ratio / 100', () {
      expect(const ElDimension.percent(80).resolve(200), 160);
      expect(const ElDimension.percent(50).resolve(240), 120);
      expect(const ElDimension.percent(100).resolve(100), 100);
      expect(const ElDimension.percent(25).resolve(160), 40);
    });

    test('percent + 无限 available → null（无参考，退化为未声明）', () {
      expect(const ElDimension.percent(50).resolve(double.infinity), isNull);
    });
  });

  group('ElDimension.lerp', () {
    test('同 pixels 数值插值', () {
      expect(
        ElDimension.lerp(const ElDimension.pixels(0), const ElDimension.pixels(100), 0.5),
        const ElDimension.pixels(50),
      );
      expect(
        ElDimension.lerp(const ElDimension.pixels(100), const ElDimension.pixels(200), 0.25),
        const ElDimension.pixels(125),
      );
    });

    test('同 percent 数值插值', () {
      expect(
        ElDimension.lerp(const ElDimension.percent(0), const ElDimension.percent(80), 0.5),
        const ElDimension.percent(40),
      );
    });

    test('跨 kind 走 calc 形态（CSS length-percentage lazy 插值）', () {
      const px = ElDimension.pixels(100);
      const pct = ElDimension.percent(80);
      // t=0: calc(100, 0) —— 全 px 分量；resolve(any) = 100
      final r0 = ElDimension.lerp(px, pct, 0.0);
      expect(r0.kind, ElLengthKind.calc);
      expect(r0.pxPart, closeTo(100, 1e-9));
      expect(r0.percentPart, closeTo(0, 1e-9));
      expect(r0.resolve(400), closeTo(100, 1e-9));

      // t=0.5: calc(50, 40)；resolve(400) = 50 + 160 = 210
      final r5 = ElDimension.lerp(px, pct, 0.5);
      expect(r5.pxPart, closeTo(50, 1e-9));
      expect(r5.percentPart, closeTo(40, 1e-9));
      expect(r5.resolve(400), closeTo(210, 1e-9));

      // t=1: calc(0, 80) —— 全 percent 分量；resolve(400) = 320
      final r1 = ElDimension.lerp(px, pct, 1.0);
      expect(r1.pxPart, closeTo(0, 1e-9));
      expect(r1.percentPart, closeTo(80, 1e-9));
      expect(r1.resolve(400), closeTo(320, 1e-9));
    });

    test('auto 与 pixels 跨 auto 仍 snap（auto 无法 calc）', () {
      expect(ElDimension.lerp(ElDimension.auto, const ElDimension.pixels(200), 0.3), ElDimension.auto);
      expect(ElDimension.lerp(ElDimension.auto, const ElDimension.pixels(200), 0.7), const ElDimension.pixels(200));
    });

    test('calc 的 resolve 行为', () {
      const c = ElDimension.calc(50, 40);
      // 50 + 400 * 40 / 100 = 50 + 160 = 210
      expect(c.resolve(400), 210);
      // 50 + 100 * 40 / 100 = 90
      expect(c.resolve(100), 90);
      // 无限父约束 → null（含 percent 分量必须有参考）
      expect(c.resolve(double.infinity), isNull);
    });

    test('calc 与 percent 之间插值（calc 已含 percent，仍走 calc 同 kind 插值）', () {
      const c = ElDimension.calc(20, 30);
      const pct = ElDimension.percent(80);
      // calc(20, 30) → percent(80) 跨 kind 又走 calc 包装：
      // calc(20*(1-t) + 0*t, 30*(1-t) + 80*t)
      // t=0.5 → calc(10, 55)
      final r = ElDimension.lerp(c, pct, 0.5);
      expect(r.kind, ElLengthKind.calc);
      expect(r.pxPart, closeTo(10, 1e-9));
      expect(r.percentPart, closeTo(55, 1e-9));
    });

    test('identical 短路', () {
      const a = ElDimension.pixels(50);
      expect(identical(ElDimension.lerp(a, a, 0.7), a), isTrue);
    });
  });

  group('ElDimension helpers', () {
    test('isAuto', () {
      expect(ElDimension.auto.isAuto, isTrue);
      expect(const ElDimension.pixels(80).isAuto, isFalse);
      expect(const ElDimension.percent(50).isAuto, isFalse);
    });

    test('isNegative', () {
      expect(const ElDimension.pixels(-10).isNegative, isTrue);
      expect(const ElDimension.pixels(0).isNegative, isFalse);
      expect(const ElDimension.pixels(10).isNegative, isFalse);
      expect(const ElDimension.percent(-5).isNegative, isTrue);
      expect(ElDimension.auto.isNegative, isFalse, reason: 'auto 没有数值意义，不视为负');
    });

    test('== / hashCode', () {
      expect(const ElDimension.pixels(80), const ElDimension.pixels(80));
      expect(const ElDimension.pixels(80).hashCode, const ElDimension.pixels(80).hashCode);
      expect(const ElDimension.pixels(80) == const ElDimension.percent(80), isFalse, reason: 'kind 不同即使 value 同也不等');
    });
  });
}
