// onSelection 伪类提取器单测：层叠语义 / var 解析 / currentColor / memo /
// layout 字段静默忽略（零 assert 硬规则）。

import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';
import 'package:flutter_base/src/flutter/views/view/style/state/view_state.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

int _bit(ViewState s) => 1 << s.index;

void main() {
  group('extractOnSelectionPaint', () {
    test('未声明 → empty 共享实例', () {
      expect(extractOnSelectionPaint(null), same(OnSelectionPaint.empty));
      expect(extractOnSelectionPaint(const ElStyle(backgroundColor: Color(0xFF112233))), same(OnSelectionPaint.empty));
    });

    test('base.onSelection 两槽直取', () {
      final result = extractOnSelectionPaint(
        const ElStyle(
          onSelection: ElStyle(backgroundColor: Color(0xFF0078D7), color: Color(0xFFFFFFFF)),
        ),
      );
      expect(result.bgColor, const Color(0xFF0078D7));
      expect(result.color, const Color(0xFFFFFFFF));
    });

    test('onDark 嵌套：dark 位命中才激活，且按字段覆盖 base', () {
      const style = ElStyle(
        onSelection: ElStyle(backgroundColor: Color(0xFF111111), color: Color(0xFF222222)),
        onDark: ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF333333))),
      );
      final light = extractOnSelectionPaint(style);
      expect(light.bgColor, const Color(0xFF111111));

      final dark = extractOnSelectionPaint(style, stateBits: _bit(ViewState.dark));
      expect(dark.bgColor, const Color(0xFF333333), reason: 'dark 变体覆盖 base 的 bgColor');
      expect(dark.color, const Color(0xFF222222), reason: '变体未声明的槽保留 base 值（字段级合并）');
    });

    test('变体优先级：表序后者覆盖前者（onDark 压 onHover）', () {
      const style = ElStyle(
        onHover: ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF444444))),
        onDark: ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF555555))),
      );
      final result = extractOnSelectionPaint(style, stateBits: _bit(ViewState.hover) | _bit(ViewState.dark));
      expect(result.bgColor, const Color(0xFF555555));
    });

    test('stateBits=0 时嵌套声明不激活（无状态机宿主口径）', () {
      const style = ElStyle(
        onDark: ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF666666))),
      );
      expect(extractOnSelectionPaint(style), same(OnSelectionPaint.empty));
    });

    test('layout / 未消费 paint 字段静默忽略，零 assert', () {
      final result = extractOnSelectionPaint(
        ElStyle(
          onSelection: ElStyle(
            backgroundColor: const Color(0xFF0078D7),
            padding: .all(16),
            width: 200,
            border: .all(borderColor: const Color(0xFF000000)),
            opacity: 0.5,
          ),
        ),
      );
      expect(result.bgColor, const Color(0xFF0078D7));
      expect(result.color, isNull);
    });
  });

  group('OnSelectionPaintMemo', () {
    test('输入不变复用同一结果实例；stateBits 变化重算', () {
      const style = ElStyle(
        onSelection: ElStyle(backgroundColor: Color(0xFF111111)),
        onDark: ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF222222))),
      );
      final memo = OnSelectionPaintMemo();
      final a = memo.resolve(style);
      expect(memo.resolve(style), same(a));

      final dark = memo.resolve(style, stateBits: _bit(ViewState.dark));
      expect(dark.bgColor, const Color(0xFF222222));
      expect(memo.resolve(style, stateBits: _bit(ViewState.dark)), same(dark));
    });

    test('style identity 变化重算（值等不共享）', () {
      final memo = OnSelectionPaintMemo();
      // 非 const 构造保证两实例 identity 不同。
      final s1 = ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF111111 + 0)));
      final s2 = ElStyle(onSelection: ElStyle(backgroundColor: Color(0xFF111111 + 0)));
      final a = memo.resolve(s1);
      final b = memo.resolve(s2);
      expect(a.bgColor, b.bgColor);
      expect(identical(a, b), isFalse);
    });
  });
}
