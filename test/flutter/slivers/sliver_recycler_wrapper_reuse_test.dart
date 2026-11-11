import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/src/flutter/utils/internal/reuse_animation.dart';
import 'package:flutter_test/flutter_test.dart';

class _LabelScope extends InheritedWidget {
  // ignore: prefer_const_constructors_in_immutables
  _LabelScope({required this.label, required super.child});

  final String label;

  static String of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_LabelScope>()!.label;

  @override
  bool updateShouldNotify(_LabelScope oldWidget) => label != oldWidget.label;
}

ScrollController _setup(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(320, 240);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final controller = ScrollController(keepScrollOffset: false);
  addTearDown(controller.dispose);
  return controller;
}

Widget _scroll(ScrollController controller, Widget sliver) =>
    CustomScrollView(controller: controller, scrollCacheExtent: ScrollCacheExtent.pixels(0), slivers: [sliver]);

Map<Element, Widget> _stateWrappers(Element item) {
  final result = <Element, Widget>{};
  item.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is ElSliverRecyclerList) return false;
    if (widget is TickerMode || widget is HeroMode || widget is Focus || widget is ReuseAnimationScope) {
      result[element] = widget;
    }
    return true;
  });
  return result;
}

List<int> _semanticIndices(WidgetTester tester) {
  final result = <int>[];
  void visit(SemanticsNode node) {
    if (node.indexInParent case final index?) result.add(index);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(CustomScrollView)));
  return result;
}

void main() {
  testWidgets('活跃槽换绑只更新索引语义，静态业务及状态包装保持身份', (tester) async {
    final controller = _setup(tester);
    final semantics = tester.ensureSemantics();
    final previous = debugOnRebuildDirtyWidget;
    try {
      final keys = <Key>[];
      final bindings = <ValueListenable<int>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: _scroll(
            controller,
            ElSliverRecyclerList(
              itemCount: 20,
              maxRecycledItems: 0,
              itemBuilder: (_, index) {
                bindings.add(index);
                final key = UniqueKey();
                keys.add(key);
                return SizedBox(
                  key: key,
                  height: 240,
                  child: Center(child: Text('展示数据相同')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(keys, hasLength(1));
      final finder = find.byKey(keys.single);
      final element = tester.element(finder);
      final widget = element.widget;
      final render = tester.renderObject(finder);
      final wrappers = _stateWrappers(element);
      expect(wrappers, hasLength(4));
      expect(_semanticIndices(tester), [0]);

      final rebuilt = <Element>{};
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        rebuilt.add(element);
      };

      for (final index in [1, 2, 3]) {
        rebuilt.clear();
        controller.jumpTo(index * 240);
        await tester.pump();
        expect(controller.offset, index * 240);
        expect(bindings.single.value, index);
        expect(keys, hasLength(1));
        expect(tester.element(finder), same(element));
        expect(tester.widget(finder), same(widget));
        expect(tester.renderObject(finder), same(render));
        final after = _stateWrappers(element);
        expect(after.keys, unorderedEquals(wrappers.keys));
        for (final entry in wrappers.entries) {
          expect(after[entry.key], same(entry.value));
        }
        expect(rebuilt.where(wrappers.containsKey), isEmpty);
        expect(rebuilt, isNot(contains(element)));
        expect(_semanticIndices(tester), [index], reason: '保留外层状态包装后，无障碍序号仍须立即换绑。');
        expect(find.text('展示数据相同').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(SizedBox.shrink());
    } finally {
      debugOnRebuildDirtyWidget = previous;
      semantics.dispose();
    }
  });

  testWidgets('稳定父配置下 itemBuilder 继承依赖变化仍更新，同槽保留节点', (tester) async {
    final controller = _setup(tester);
    final label = ValueNotifier('旧环境');
    addTearDown(label.dispose);
    var factoryCalls = 0;
    final itemKey = UniqueKey();
    final sliver = ElSliverRecyclerList(
      itemCount: 20,
      itemBuilder: (context, _) {
        factoryCalls++;
        return SizedBox(key: itemKey, height: 240, child: Text(_LabelScope.of(context)));
      },
    );
    final scroll = _scroll(controller, sliver);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<String>(
          valueListenable: label,
          child: scroll,
          builder: (_, value, child) => _LabelScope(label: value, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(factoryCalls, 1);
    expect(find.text('旧环境'), findsOneWidget);
    final element = tester.element(find.byKey(itemKey));
    final render = tester.renderObject(find.byKey(itemKey));

    label.value = '新环境';
    await tester.pump();
    expect(tester.widget(find.byType(CustomScrollView)), same(scroll));
    expect(tester.widget(find.byType(ElSliverRecyclerList)), same(sliver));
    expect(factoryCalls, 2);
    expect(find.text('旧环境'), findsNothing);
    expect(find.text('新环境'), findsOneWidget);
    expect(tester.element(find.byKey(itemKey)), same(element));
    expect(tester.renderObject(find.byKey(itemKey)), same(render));
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });
}
