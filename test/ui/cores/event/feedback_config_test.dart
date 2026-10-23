import 'package:flutter_base/src/ui/cores/event/index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('触摸反馈恢复默认值，零值可显式关闭等待和保留', () {
    const defaults = ElEventConfig();
    expect(defaults.delayTouchDown, Duration.zero);
    expect(defaults.delayTouchUp, const Duration(milliseconds: 100));
    const immediate = ElEventConfig(
      delayTouchDown: Duration.zero,
      delayTouchUp: Duration.zero,
    );
    expect(immediate.delayTouchDown, Duration.zero);
    expect(immediate.delayTouchUp, Duration.zero);
    expect(immediate.withFallback(defaults).delayTouchUp, Duration.zero);
  });

  test('反馈时长参与值比较与散列，但不改变 Tap 识别配置', () {
    const first = ElEventConfig(
      delayTouchDown: Duration(milliseconds: 20),
      delayTouchUp: Duration(milliseconds: 80),
    );
    final same = first.copyWith();
    final changed = first.copyWith(
      delayTouchUp: const Duration(milliseconds: 120),
    );
    expect(same, first);
    expect(same.hashCode, first.hashCode);
    expect(changed, isNot(first));
    expect(first.hasSameTapConfiguration(changed), isTrue);
    expect(
      first.hasSameTapConfiguration(
        first.copyWith(longPressDelay: const Duration(milliseconds: 200)),
      ),
      isFalse,
    );
    expect(const ElEventConfig().hasSameTapConfiguration(first), isTrue);
    expect(first.hasSameTapConfiguration(null), isTrue);
  });

  test('反馈时长逐字段合并，copyWith 保留未覆盖的字段', () {
    const base = ElEventConfig(
      delayTouchDown: Duration(milliseconds: 30),
      delayTouchUp: Duration(milliseconds: 120),
      tapCancelDistance: 14,
    );
    final merged = const ElEventConfig(delayTouchUp: Duration(milliseconds: 60))
        .withFallback(base);
    expect(merged.delayTouchDown, base.delayTouchDown);
    expect(merged.delayTouchUp, const Duration(milliseconds: 60));
    expect(merged.tapCancelDistance, 14);
    final copied = merged.copyWith(delayTouchDown: Duration.zero);
    expect(copied.delayTouchDown, Duration.zero);
    expect(copied.delayTouchUp, merged.delayTouchUp);
    expect(copied.tapCancelDistance, merged.tapCancelDistance);
  });

  test('负的反馈时长在读取配置时被拒绝', () {
    expect(
      () =>
          const ElEventConfig(delayTouchDown: Duration(milliseconds: -1))
              .delayTouchDown,
      throwsAssertionError,
    );
    expect(
      () =>
          const ElEventConfig(delayTouchUp: Duration(milliseconds: -1))
              .delayTouchUp,
      throwsAssertionError,
    );
  });
}
