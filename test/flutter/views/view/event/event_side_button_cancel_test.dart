import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 侧键（forward/back）按下被 PointerCancel 打断后，`_forwardDownPosition` /
/// `_backDownPosition` 必须随 cancel 清空，否则下一次**无关**主键 PointerUp 会
/// 命中 `_handleForwardBackUp` 的 `fwd != null` 分支误 fire forwardTap/backTap。
void main() {
  testWidgets('侧键 down 被 cancel 打断后，主键 tap 不误触发 forwardTap', (tester) async {
    final phases = <ElEventPhase>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ElView(
            style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF00FF00)),
            event: ElEvent(
              onTap: (e) => phases.add(e.phase),
              onForwardTap: (e) => phases.add(e.phase),
              onForwardTapUp: (e) => phases.add(e.phase),
            ),
          ),
        ),
      ),
    );

    // 侧键按下后被 cancel 打断（未抬起）
    final fwd = TestPointer(7, PointerDeviceKind.mouse, 0, kForwardMouseButton);
    await tester.sendEventToBinding(fwd.down(const Offset(20, 20)));
    await tester.sendEventToBinding(fwd.cancel());

    // 随后一次正常主键 tap（同一位置）
    final primary = TestPointer(8, PointerDeviceKind.mouse, 0, kPrimaryMouseButton);
    await tester.sendEventToBinding(primary.down(const Offset(20, 20)));
    await tester.sendEventToBinding(primary.up());
    await tester.pump();

    expect(
      phases,
      isNot(contains(ElEventPhase.forwardTap)),
      reason: '修复前：cancel 未清 _forwardDownPosition → 主键 up 误 fire forwardTap',
    );
    expect(phases, isNot(contains(ElEventPhase.forwardTapUp)));
    expect(phases, contains(ElEventPhase.tap), reason: '主键 tap 应正常触发');
  });
}
