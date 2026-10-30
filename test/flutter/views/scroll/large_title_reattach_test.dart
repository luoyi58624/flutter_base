import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Navbar extends StatefulWidget {
  const _Navbar({super.key});
  @override
  State<_Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<_Navbar> with ElScrollMixin<_Navbar>, ElLargeTitleNavbarMixin<_Navbar> {
  double get range => largeTitleNavbarRange;
  @override
  bool get largeTitleNavbarScale => false;
  @override
  bool get largeTitleNavbarFade => true;
  @override
  Widget build(BuildContext context) => buildLargeTitleNavbar(
    context,
    largeTitle: ElView(style: ElStyle(fontSize: 34), child: '聊天'),
    compactTitle: ElView(style: ElStyle(fontSize: 18), child: '聊天'),
    actions: [ElView(style: ElStyle(width: 0, height: 56))],
  );
}

void main() {
  for (final collapsed in [false, true]) {
    testWidgets('相同约束重挂后恢复大标题实测行程 collapsed=$collapsed', (tester) async {
      final relocation = ValueNotifier(false);
      final controller = ElScrollController();
      final header = GlobalKey<_NavbarState>();
      addTearDown(() async {
        await tester.pumpWidget(ElView());
        controller.dispose();
        relocation.dispose();
      });
      final viewport = ElScrollView(
        key: GlobalKey(),
        controller: controller,
        physics: ElClampingScrollPhysics(),
        scrollbar: ElNoScrollBar(),
        children: [
          _Navbar(key: header),
          for (var i = 0; i < 40; i++) ElView(style: ElStyle(height: 70), child: '联系人 $i'),
        ],
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: MediaQuery(
            data: MediaQueryData(size: Size(400, 650)),
            child: ValueListenableBuilder<bool>(
              valueListenable: relocation,
              child: viewport,
              builder: (context, value, child) => KeyedSubtree(key: ValueKey(value), child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = header.currentState!;
      final range = state.range;
      expect(range, greaterThan(0));
      if (collapsed) {
        controller.jumpTo(200);
        await tester.pumpAndSettle();
        expect(state.largeTitleNavbarProgress, 1);
      }
      for (var cycle = 0; cycle < 3; cycle++) {
        relocation.value = !relocation.value;
        await tester.pumpAndSettle();
        expect(header.currentState, same(state));
        expect(state.range, range, reason: '尺寸没变也必须重新向重绑后的 Mixin 上报行程');
        expect(state.scrollEffectTracks.single.pixelsPerUnit, range);
      }
      final gesture = await tester.startGesture(Offset(300, 250));
      await gesture.moveBy(Offset(0, 25));
      await tester.pump(Duration(milliseconds: 16));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(0, 15));
        await tester.pump(Duration(milliseconds: 16));
      }
      await tester.pump(Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(0, .01));
      expect(state.largeTitleNavbarProgress, 0);
      final up = await tester.startGesture(Offset(300, 450));
      await up.moveBy(Offset(0, -25));
      await tester.pump(Duration(milliseconds: 16));
      for (var i = 0; i < 12; i++) {
        await up.moveBy(Offset(0, -15));
        await tester.pump(Duration(milliseconds: 16));
      }
      await tester.pump(Duration(milliseconds: 200));
      await up.up();
      await tester.pumpAndSettle();
      expect(state.largeTitleNavbarProgress, 1);
      expect(controller.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }
}
