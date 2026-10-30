import '../../../ui/support/overlay.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class DemoStage extends StatefulWidget {
  const DemoStage({super.key, required this.builder});
  final Widget Function() builder;
  @override
  State<DemoStage> createState() => DemoStageState();
}

class DemoStageState extends State<DemoStage> {
  final stage = GlobalKey();
  int generation = 0;
  void move() => setState(() => generation++);
  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey(generation),
    child: RepaintBoundary(key: stage, child: widget.builder()),
  );
}

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 300, height: 220, child: child)),
  ),
);

void main() {
  testWidgets('demo 预览滑动：同一手势跨重挂继续', (tester) async {
    final stageKey = GlobalKey<DemoStageState>();
    final ctrl = ElPreviewController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(_host(
      ElTestOverlay(
        child: DemoStage(
          key: stageKey,
          builder: () => ElPreviewView(
            controller: ctrl,
            panInertia: false,
            scaleInertia: false,
            children: const [
              SizedBox.expand(key: ValueKey('page-a')),
              SizedBox.expand(key: ValueKey('page-b')),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final baseX = tester.getTopLeft(find.byKey(const ValueKey('page-b'))).dx;
    double progress() => baseX - tester.getTopLeft(find.byKey(const ValueKey('page-b'))).dx;

    final g = await tester.startGesture(const Offset(150, 100), kind: PointerDeviceKind.touch);
    addTearDown(g.removePointer);
    await g.moveBy(const Offset(-30, 0));
    await tester.pump();
    await g.moveBy(const Offset(-70, 0));
    await tester.pump();
    final before = progress();

    stageKey.currentState!.move();
    await tester.pump();
    await tester.pump();
    await g.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(progress(), greaterThan(before + 30), reason: '重挂后同一手势必须继续推进');

    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(-60, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(ctrl.index, 1, reason: '接着拖必须能切页');
  });
}
