import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 更换外围父节点，保留完全相同的子树，避免重建顺便触发布局掩盖重挂问题。
class ReparentHarness extends StatefulWidget {
  const ReparentHarness({super.key, required this.child, this.wrap});
  final Widget child;
  final Widget Function(int generation, Widget child)? wrap;

  @override
  State<ReparentHarness> createState() => ReparentHarnessState();
}

class ReparentHarnessState extends State<ReparentHarness> {
  final probe = GlobalKey<_ProbeState>();
  int generation = 0;

  void move() => setState(() => generation++);

  @override
  Widget build(BuildContext context) {
    final child = _Probe(key: probe, child: widget.child);
    return KeyedSubtree(
      key: ValueKey(generation),
      child: widget.wrap?.call(generation, child) ?? child,
    );
  }
}

class _Probe extends StatefulWidget {
  const _Probe({super.key, required this.child});
  final Widget child;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int deactivations = 0;
  int activations = 0;
  @override
  void deactivate() {
    deactivations++;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    activations++;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 同时断言真的发生搬迁，以及 State、Element、RenderObject 没有被替换。
Future<void> reparent(WidgetTester tester, GlobalKey<ReparentHarnessState> key, {bool settle = true}) async {
  final harness = key.currentState!;
  final probe = harness.probe.currentState!;
  final element = harness.probe.currentContext!;
  final render = element.findRenderObject()!;
  final previous = probe.deactivations;
  harness.move();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  expect(harness.probe.currentState, same(probe));
  expect(harness.probe.currentContext, same(element));
  expect(harness.probe.currentContext!.findRenderObject(), same(render));
  expect(probe.deactivations, previous + 1);
  expect(probe.activations, probe.deactivations);
  expect(render.attached, isTrue);
  expect(tester.takeException(), isNull);
}

Widget lifecycleHost(Widget child) => Directionality(
  textDirection: .ltr,
  child: MediaQuery(data: MediaQueryData(size: Size(800, 600)), child: child),
);
