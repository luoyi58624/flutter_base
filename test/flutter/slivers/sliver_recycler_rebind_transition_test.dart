import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _row(int index) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.identifier == 'row-$index');
Finder _inside(Finder row, Type type) => find.descendant(of: row, matching: find.byType(type));

Iterable<ElRenderView> _renders(Finder row) =>
    _inside(row, ElView).evaluate().map((element) => element.renderObject).whereType<ElRenderView>();

Future<ScrollController> _open(
  WidgetTester tester,
  ValueNotifier<Set<int>> changes, {
  bool entering = false,
  bool loop = false,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: ElComponentProvider(
        components: el.mobileComponents,
        child: Center(
          child: SizedBox(
            width: 320,
            height: 360,
            child: CustomScrollView(
              controller: controller,
              scrollCacheExtent: ScrollCacheExtent.pixels(0),
              slivers: [
                ElSliverList.recycler(
                  itemCount: 100,
                  itemBuilder: (context, index) => HookBuilder(
                    builder: (context) {
                      final position = useValueListenable(index);
                      final changed = useValueListenable(changes);
                      final selected = (position ~/ 2).isOdd != changed.contains(position);
                      return Semantics(
                        identifier: 'row-$position',
                        child: SizedBox(
                          height: 180,
                          child: Column(
                            children: [
                              ElSwitch(value: selected, semanticLabel: '条目开关'),
                              ElProgress(value: selected ? 90 : 10),
                              if (loop) ElProgress(),
                              if (loop) ElLoadingIndicator(),
                              if (entering && selected)
                                ElView(
                                  key: ValueKey('entering'),
                                  style: ElStyle(
                                    width: 20,
                                    height: 20,
                                    opacity: 1,
                                    starting: ElStyle(opacity: 0),
                                    transition: [ElTransition.all(Duration(milliseconds: 200))],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (loop) {
    await tester.pump(Duration(seconds: 1));
  } else {
    await tester.pumpAndSettle();
  }
  return controller;
}

void main() {
  testWidgets('跨记录换绑直接提交开关与进度，同记录更新仍播放过渡', (tester) async {
    final changes = ValueNotifier(<int>{});
    addTearDown(changes.dispose);
    final controller = await _open(tester, changes);
    final originals = [_row(0).evaluate().single, _row(1).evaluate().single];
    controller.jumpTo(360);
    await tester.pump();
    final row = _row(2);
    expect(originals, contains(row.evaluate().single));
    expect(_renders(row).any((render) => render.hasActiveAnimationsForTest), isFalse);
    expect(tester.widget<AnimatedAlign>(_inside(row, AnimatedAlign)).alignment, Alignment.centerRight);
    expect(tester.widget<AnimatedAlign>(_inside(row, AnimatedAlign)).duration, Duration.zero);
    expect(tester.binding.transientCallbackCount, 0);
    changes.value = {2};
    await tester.pump();
    expect(_renders(row).any((render) => render.hasActiveAnimationsForTest), isTrue);
    expect(tester.widget<AnimatedAlign>(_inside(row, AnimatedAlign)).duration, greaterThan(Duration.zero));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('换绑产生的 starting 节点不播放旧记录入场，同记录入场继续过渡', (tester) async {
    final changes = ValueNotifier(<int>{});
    addTearDown(changes.dispose);
    final controller = await _open(tester, changes, entering: true);
    controller.jumpTo(360);
    await tester.pump();
    Finder entry() => find.descendant(of: _row(2), matching: find.byKey(ValueKey('entering')));
    expect(tester.renderObject<ElRenderView>(entry()).committedResolvedStyle.box.opacity, 1);
    expect(tester.renderObject<ElRenderView>(entry()).hasActiveAnimationsForTest, isFalse);
    changes.value = {2};
    await tester.pumpAndSettle();
    expect(entry(), findsNothing);
    changes.value = {};
    await tester.pump();
    expect(tester.renderObject<ElRenderView>(entry()).committedResolvedStyle.box.opacity, 0);
    expect(tester.renderObject<ElRenderView>(entry()).hasActiveAnimationsForTest, isTrue);
    await tester.pumpAndSettle();
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('换绑作用域不关闭可见条目的持续动画，卸载后清理活动', (tester) async {
    final changes = ValueNotifier(<int>{});
    addTearDown(changes.dispose);
    final controller = await _open(tester, changes, loop: true);
    controller.jumpTo(360);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });
}
