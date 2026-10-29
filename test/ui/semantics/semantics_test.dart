import 'package:flutter_base/ui.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('配置等值', _registerEqualityTests);
}

void _noop() {}

/// ElSemantics 等值口径：便利构造逐字段结构比较（挡住 build 内联新实例击穿
/// render 侧 `set semantics` 等值门），显式 properties 维持 identity 比较。
void _registerEqualityTests() {
  group('便利构造：结构等值', () {
    test('同参数两实例 == 且 hashCode 相等', () {
      final a = ElSemantics(label: 'ok', button: true);
      final b = ElSemantics(label: 'ok', button: true);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('参数不同则 !=', () {
      expect(ElSemantics(label: 'a'), isNot(equals(ElSemantics(label: 'b'))));
      expect(ElSemantics(button: true), isNot(equals(ElSemantics(link: true))));
    });

    test('回调按函数 == 比较：同一 tearoff 相等，内联新闭包不等', () {
      final a = ElSemantics(label: 'x', onTap: _noop);
      final b = ElSemantics(label: 'x', onTap: _noop);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      final c = ElSemantics(label: 'x', onTap: () {});
      final d = ElSemantics(label: 'x', onTap: () {});
      expect(c, isNot(equals(d)));
    });

    test('语义树策略字段仍参与比较', () {
      expect(ElSemantics(label: 'x', container: true), isNot(equals(ElSemantics(label: 'x'))));
    });
  });

  group('显式 properties：identity 语义保留', () {
    test('同一 properties 实例 ==', () {
      const props = SemanticsProperties(label: 'p');
      final a = ElSemantics(properties: props);
      final b = ElSemantics(properties: props);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('内容相同的两个显式实例仍 !=（不做全字段结构比较）', () {
      final a = ElSemantics(properties: const SemanticsProperties(label: 'p'));
      // ignore: prefer_const_constructors
      final b = ElSemantics(properties: SemanticsProperties(label: 'p'));
      expect(a, isNot(equals(b)));
    });

    test('便利构造与显式构造（非同一实例）!=', () {
      final a = ElSemantics(label: 'p');
      // ignore: prefer_const_constructors
      final b = ElSemantics(properties: SemanticsProperties(label: 'p'));
      expect(a, isNot(equals(b)));
    });
  });
}
