//
// 页面滚动到底部后展开示例卡代码区（ElCodeExample 的 ElCollapseAnimation 口径）：
// 默认（pinToEnd: false）与 web/CSS 一致——保留 scrollTop，可见内容原地不动，
// 展开发生在视口下方、可继续下滚；页面中段展开同口径（位置保留、下方内容被推下去）。
// 贴底跟随（钉回新 max）是 ElScroll.pinToEnd 显式 opt-in（2026-08-09 用户裁决，
// 引擎回归见 el_ui/test/scroll/el_scroll_pin_to_end_test.dart）。
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _codeHeight = 200.0;

/// 示例卡：演示区 + 折叠条 + 可折叠代码区（ElCodeExample 结构）。
class _CodeExampleCard extends StatefulWidget {
  const _CodeExampleCard();

  @override
  State<_CodeExampleCard> createState() => _CodeExampleCardState();
}

class _CodeExampleCardState extends State<_CodeExampleCard> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return ElView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElView(
            key: const ValueKey('demo'),
            style: const ElStyle(height: 120, backgroundColor: Color(0xfff0f0f0)),
            child: '演示区',
          ),
          ElButtonView(key: const ValueKey('bar'), onPressed: _toggle, child: '展开代码'),
          ElCollapseAnimation(
            _expanded,
            keepState: false,
            child: ElView(
              key: const ValueKey('code'),
              style: ElStyle(height: _codeHeight, backgroundColor: const Color(0xff222222)),
              child: '代码区',
            ),
          ),
        ],
      ),
    );
  }
}

/// 10 行 × 100 + 卡（演示区 120 + 折叠条）+ 页脚 100：600 视口下内容高度
/// 超出视口，可滚到底；展开代码 → 内容总高 +200。
Widget _host(ScrollController controller) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ElScroll(
      controller: controller,
      children: [
        for (var i = 0; i < 10; i++)
          ElView(key: ValueKey('row-$i'), style: const ElStyle(height: 100), child: '行 $i'),
        const _CodeExampleCard(),
        ElView(key: const ValueKey('footer'), style: const ElStyle(height: 100), child: '页脚'),
      ],
    ),
  );
}

void main() {
  testWidgets('滚到底展开代码：web 语义——位置保留，可见内容不动，展开在视口下方', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    // 前置：滚到底，pixels 必须贴住 max。
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final maxBefore = controller.position.maxScrollExtent;
    final pixelsBefore = controller.position.pixels;
    expect(pixelsBefore, maxBefore, reason: '前置：已滚动到底部');

    final demoBefore = tester.getRect(find.byKey(const ValueKey('demo')));
    final footerTopBefore = tester.getRect(find.byKey(const ValueKey('footer'))).top;

    // 展开代码区。动画中途（250ms 动画抽 125ms 帧）位置不许漂移。
    await tester.tap(find.byKey(const ValueKey('bar')), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 125));
    expect(controller.position.pixels, pixelsBefore, reason: '动画中途滚动区保持原位');

    await tester.pumpAndSettle();
    // web 语义：scrollTop 保留，可见内容原地不动，展开量全部落在视口下方。
    expect(controller.position.maxScrollExtent, moreOrLessEquals(maxBefore + _codeHeight, epsilon: 0.01),
        reason: '内容总高 +200');
    expect(controller.position.pixels, moreOrLessEquals(pixelsBefore, epsilon: 0.01),
        reason: '展开不驱动滚动，位置保留（贴底跟随需显式 pinToEnd）');
    expect(controller.position.pixels, lessThan(controller.position.maxScrollExtent),
        reason: '下方还有展开量可滚');
    expect(tester.getRect(find.byKey(const ValueKey('demo'))), demoBefore,
        reason: '演示区（可见内容）原地不动');
    expect(tester.getRect(find.byKey(const ValueKey('code'))).bottom, greaterThan(600.0),
        reason: '代码区在视口外向下展开');
    expect(tester.getRect(find.byKey(const ValueKey('footer'))).top, footerTopBefore + _codeHeight,
        reason: '页脚被展开量推下去');

    // 收起：位置仍保留（收起后恰好回到贴底）。
    await tester.tap(find.byKey(const ValueKey('bar')), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(controller.position.pixels, moreOrLessEquals(pixelsBefore, epsilon: 0.01),
        reason: '收起后位置保留');
    expect(controller.position.maxScrollExtent, moreOrLessEquals(maxBefore, epsilon: 0.01),
        reason: '收起后滚动范围复原');
    expect(find.byKey(const ValueKey('code')), findsNothing, reason: 'keepState: false 折叠即销毁');
  });

  testWidgets('中段展开（非贴底）：位置保留、可见内容不动，只把下方内容推下去', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    // 滚到折叠条整条可见、页脚顶部刚露出视口底（折叠条 content y 1120..1160、
    // 页脚 1160..1260 → pixels 620 时折叠条在屏幕 500..540、页脚 540..640）。
    controller.jumpTo(620);
    await tester.pump();
    final pixelsBefore = controller.position.pixels;
    final footerTopBefore = tester.getRect(find.byKey(const ValueKey('footer'))).top;
    final demoBefore = tester.getRect(find.byKey(const ValueKey('demo')));

    await tester.tap(find.byKey(const ValueKey('bar')), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(controller.position.pixels, pixelsBefore, reason: '非贴底：展开不驱动滚动，位置保留');
    expect(tester.getRect(find.byKey(const ValueKey('demo'))), demoBefore, reason: '卡上方内容不动');
    expect(tester.getRect(find.byKey(const ValueKey('footer'))).top, footerTopBefore + _codeHeight,
        reason: '展开把卡下方内容推下去 _codeHeight（与 web 一致）');
  });
}
