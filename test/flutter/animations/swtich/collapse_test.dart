import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  for (final axis in Axis.values) {
    testWidgets('$axis 只收缩对应布局轴且迅速让出空间', (tester) async {
      Widget scene(bool value) => animationScene(
        ElCollapseAnimation(
          value,
          axis: axis,
          child: SizedBox(width: 80, height: 40),
        ),
      );
      await tester.pumpWidget(scene(true));
      expect(tester.getSize(find.byType(ElCollapseAnimation)), Size(80, 40));
      await tester.pumpWidget(scene(false));
      await tester.pump();
      await tester.pump(Duration(milliseconds: 100));
      final factor = tester
          .widget<SizeTransition>(find.byType(SizeTransition))
          .sizeFactor
          .value;
      expect(factor, inExclusiveRange(0.1, 0.5));
      final size = tester.getSize(find.byType(ElCollapseAnimation));
      expect(
        size.width,
        closeTo(axis == Axis.horizontal ? 80 * factor : 80, 0.001),
      );
      expect(
        size.height,
        closeTo(axis == Axis.vertical ? 40 * factor : 40, 0.001),
      );
      await tester.pumpAndSettle(Duration(milliseconds: 16));
      expect(
        tester.getSize(find.byType(ElCollapseAnimation)),
        axis == Axis.horizontal ? Size(0, 40) : Size(80, 0),
      );
    });
  }

  testWidgets('保留状态模式在完整折叠后复用子组件', (tester) async {
    Widget scene(bool value) =>
        animationScene(ElCollapseAnimation(value, child: _StateProbe()));
    await tester.pumpWidget(scene(true));
    final state = tester.state(find.byType(_StateProbe));
    await tester.pumpWidget(scene(false));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_StateProbe)), same(state));
    await tester.pumpWidget(scene(true));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_StateProbe)), same(state));
  });

  testWidgets('关闭完成后销毁内容，中途展开仍保留状态', (tester) async {
    Widget scene(bool value) => animationScene(
      ElCollapseAnimation(value, keepState: false, child: _StateProbe()),
    );
    await tester.pumpWidget(scene(false));
    expect(find.byType(_StateProbe), findsNothing);
    await tester.pumpWidget(scene(true));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(_StateProbe));
    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 50));
    expect(tester.state(find.byType(_StateProbe)), same(state));
    await tester.pumpWidget(scene(true));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_StateProbe)), same(state));
    await tester.pumpWidget(scene(false));
    await tester.pumpAndSettle();
    expect(find.byType(_StateProbe), findsNothing);
    await tester.pumpWidget(scene(true));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_StateProbe)), isNot(same(state)));
  });
}

class _StateProbe extends StatefulWidget {
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  Widget build(BuildContext context) => SizedBox(width: 80, height: 40);
}
