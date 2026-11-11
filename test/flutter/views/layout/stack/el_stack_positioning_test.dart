import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return Directionality(
    textDirection: .ltr,
    child: Align(alignment: .topLeft, child: child),
  );
}

Widget _target(String tag, List<String> log) {
  return ElView(
    key: ValueKey(tag),
    style: const ElStyle(width: 40, height: 40),
    event: ElEvent(onTap: (_) => log.add(tag)),
  );
}

class _LayoutProbe extends LeafRenderObjectWidget {
  const _LayoutProbe({super.key});

  @override
  _RenderLayoutProbe createRenderObject(BuildContext context) => _RenderLayoutProbe();
}

class _RenderLayoutProbe extends RenderBox {
  int layoutCount = 0;

  @override
  void performLayout() {
    layoutCount++;
    size = constraints.constrain(const Size.square(40));
  }
}

class _ZFixture extends StatefulWidget {
  const _ZFixture({super.key});

  @override
  State<_ZFixture> createState() => _ZFixtureState();
}

class _ZFixtureState extends State<_ZFixture> {
  int relativeZ = 0;
  int absoluteZ = 0;

  void updateZ({required int relative, required int absolute}) {
    setState(() {
      relativeZ = relative;
      absoluteZ = absolute;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElStack(
      children: [
        ElStackItem(
          zIndex: relativeZ,
          child: const _LayoutProbe(key: ValueKey('relative')),
        ),
        ElPositioned(
          left: 0,
          top: 0,
          zIndex: absoluteZ,
          child: const _LayoutProbe(key: ValueKey('absolute')),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('relative item 保留自然槽位，offset 只改变最终几何', (tester) async {
    await tester.pumpWidget(
      _app(
        const ElStack(
          children: [ElStackItem(offset: Offset(50, 12), child: SizedBox(width: 30, height: 20))],
        ),
      ),
    );

    final stack = tester.renderObject<RenderStackView>(find.byType(ElStack));
    final child = tester.renderObject<RenderBox>(find.byType(SizedBox));
    expect(stack.size, const Size(30, 20), reason: 'relative offset 不得扩大自然槽位或改变 Stack 定尺');
    expect((child.parentData! as ElStackParentData).offset, const Offset(50, 12));
  });

  testWidgets('relative overflow visible 可命中，hardEdge 精确封口', (tester) async {
    Future<List<String>> tap(Clip clipBehavior) async {
      final log = <String>[];
      await tester.pumpWidget(
        _app(
          ElStack(
            clipBehavior: clipBehavior,
            children: [ElStackItem(offset: const Offset(30, 0), child: _target('relative', log))],
          ),
        ),
      );
      await tester.tapAt(const Offset(50, 10));
      return log;
    }

    expect(await tap(Clip.none), ['relative']);
    expect(await tap(Clip.hardEdge), isEmpty);
  });

  testWidgets('relative 与 absolute 的动态 zIndex 都不触发 child layout', (tester) async {
    final key = GlobalKey<_ZFixtureState>();
    await tester.pumpWidget(_app(_ZFixture(key: key)));
    final relative = tester.renderObject<_RenderLayoutProbe>(find.byKey(const ValueKey('relative')));
    final absolute = tester.renderObject<_RenderLayoutProbe>(find.byKey(const ValueKey('absolute')));
    final relativeLayouts = relative.layoutCount;
    final absoluteLayouts = absolute.layoutCount;

    key.currentState!.updateZ(relative: 5, absolute: -2);
    await tester.pump();

    expect(relative.layoutCount, relativeLayouts);
    expect(absolute.layoutCount, absoluteLayouts);
  });

  testWidgets('nested Stack 是独立 stacking context，内层高 z 不逃出外层', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _app(
        ElStack(
          children: [
            ElStackItem(
              child: ElStack(children: [ElStackItem(zIndex: 1000, child: _target('inner-high', log))]),
            ),
            ElStackItem(zIndex: 1, child: _target('outer-top', log)),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(20, 20));
    expect(log, ['outer-top']);
  });

  testWidgets('relative zIndex 与 plain/absolute child 共用同一 paint order', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _app(
        ElStack(
          children: [
            ElStackItem(zIndex: 3, child: _target('relative', log)),
            _target('plain', log),
            ElPositioned(left: 0, top: 0, zIndex: 2, child: _target('absolute', log)),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(20, 20));
    expect(log, ['relative']);
  });
}
