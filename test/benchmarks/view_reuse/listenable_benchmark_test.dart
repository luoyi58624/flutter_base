import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _leafCount = 24;
typedef _Data = ({int selected, int unrelated});

enum _Listener { value, noSelect, scalar, record, listIdentity, listValue }

enum _Change { equal, selected, unrelated, roundTrip }

void main() {
  for (var pass = 0; pass < benchmarkPasses; pass++) {
    final listeners = pass.isEven ? _Listener.values : _Listener.values.reversed;
    for (final listener in listeners) {
      for (final change in _Change.values) {
        testWidgets('监听复用 $pass ${listener.name}/${change.name}', (tester) async {
          await _measure(tester, listener, change, pass: pass);
        });
      }
    }
    // 与主矩阵的稳定 child 对照：让固定内容也进入 builder，单独量化这部分工作。
    for (final listener in [_Listener.value, _Listener.scalar]) {
      testWidgets('监听复用 $pass ${listener.name}/selected/inlineStatic', (tester) async {
        await _measure(tester, listener, _Change.selected, pass: pass, stableChild: false);
      });
    }
  }

  testWidgets('监听器谓词在等值时仍可要求构建，并保留上次观察值语义', (tester) async {
    final source = BenchValue(0);
    addTearDown(source.dispose);
    final seen = <(int, int)>[];
    var builds = 0;
    await tester.pumpWidget(
      benchScene(
        ElListenableBuilder<BenchValue<int>, int>(
          listenable: source,
          select: (value) => value.value,
          shouldRebuild: (next, previous) {
            seen.add((next, previous));
            return next == 0 || next == 2;
          },
          builder: (_, _) {
            builds++;
            return Text('${source.value}');
          },
        ),
      ),
    );
    source.emit(0);
    await tester.pump();
    expect(builds, 2, reason: '自定义谓词可以允许等值通知重建，默认相等判断不能提前拦截。');
    source.emit(1);
    await tester.pump();
    expect(builds, 2);
    source.emit(2);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(seen, [(0, 0), (1, 0), (2, 1)], reason: 'previous 是上次实际观察值，包含上次被谓词挡住的值。');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('监听器语义观察：选择值相同时父 builder 和 child 配置更新', (tester) async {
    final source = BenchValue(0);
    addTearDown(source.dispose);
    final counts = BenchCounts()..observeRebuilds();
    Widget scene(String label) => benchScene(
      ElListenableBuilder<BenchValue<int>, int>(
        listenable: source,
        select: (value) => value.value,
        child: Text('child=$label'),
        builder: (_, child) {
          counts.add('business_builder');
          return Column(children: [Text('builder=$label'), child!]);
        },
      ),
    );
    await tester.pumpWidget(scene('before'));
    expect(find.text('builder=before'), findsOneWidget);
    counts.clear();
    await tester.pumpWidget(scene('after'));
    _reportObservation(tester, 'parent_builder_and_child', ['builder=after', 'child=after'], counts);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('监听器语义观察：选择值相同时继承配置更新', (tester) async {
    final source = BenchValue(0);
    addTearDown(source.dispose);
    final counts = BenchCounts()..observeRebuilds();
    final child = ElListenableBuilder<BenchValue<int>, int>(
      listenable: source,
      select: (value) => value.value,
      builder: (context, _) {
        counts.add('business_builder');
        return Text('inherited=${_LabelScope.of(context)}');
      },
    );
    Widget scene(String label) => benchScene(_LabelScope(label: label, child: child));
    await tester.pumpWidget(scene('before'));
    expect(find.text('inherited=before'), findsOneWidget);
    counts.clear();
    await tester.pumpWidget(scene('after'));
    _reportObservation(tester, 'inherited_configuration', ['inherited=after'], counts);
    await tester.pumpWidget(SizedBox.shrink());
  });
}

Future<void> _measure(
  WidgetTester tester,
  _Listener listener,
  _Change change, {
  required int pass,
  bool stableChild = true,
}) async {
  final counts = BenchCounts()..observeRebuilds();
  final source = BenchValue<_Data>((selected: 0, unrelated: 0));
  addTearDown(source.dispose);
  final keys = List.generate(_leafCount, (index) => ValueKey('dynamic-$index'));
  final staticKeys = List.generate(_leafCount, (index) => ValueKey('static-$index'));
  final children = List.generate(_leafCount, (index) {
    final fixedChild = stableChild ? _StaticContent(counts: counts, key: staticKeys[index]) : null;
    Widget builder(BuildContext context, Widget? child) {
      counts.add('business_builder');
      return Row(
        children: [
          Expanded(
            child: BenchView(
              counts: counts,
              key: keys[index],
              style: ElStyle(fontSize: 12),
              child: 'value=${source.value.selected}',
            ),
          ),
          child ?? _StaticContent(counts: counts, key: staticKeys[index]),
        ],
      );
    }

    Object select(BenchValue<_Data> value) {
      counts.add('select_calls');
      return switch (listener) {
        .record => (value.value.selected, 'fixed'),
        .listIdentity || .listValue => [value.value.selected, 7],
        _ => value.value.selected,
      };
    }

    final listeningChild = listener == .value
        ? ValueListenableBuilder<_Data>(
            valueListenable: source,
            child: fixedChild,
            builder: (context, _, child) => builder(context, child),
          )
        : ElListenableBuilder<BenchValue<_Data>, Object>(
            listenable: source,
            select: listener == .noSelect ? null : select,
            shouldRebuild: listener == .listValue
                ? (next, previous) {
                    counts.add('predicate_calls');
                    final a = next as List<int>;
                    final b = previous as List<int>;
                    return a[0] != b[0] || a[1] != b[1];
                  }
                : null,
            builder: builder,
            child: fixedChild,
          );
    return SizedBox(height: 22, child: listeningChild);
  });
  await tester.pumpWidget(benchScene(Column(children: children)));
  final before = [for (final key in keys) tester.element(find.byKey(key))];
  final renders = [for (final key in keys) tester.renderObject<ElRenderView>(find.byKey(key))];
  final staticWidgets = [for (final key in staticKeys) tester.widget(find.byKey(key))];
  final result = await measureBench(
    tester,
    suite: 'listenable',
    name: '${listener.name}/${change.name}/${stableChild ? 'stableChild' : 'inlineStatic'}',
    pass: pass,
    counts: counts,
    action: (_) async {
      final old = source.value;
      switch (change) {
        case .equal:
          source.emit(old);
        case .selected:
          source.emit((selected: old.selected + 1, unrelated: old.unrelated));
        case .unrelated:
          source.emit((selected: old.selected, unrelated: old.unrelated + 1));
        case .roundTrip:
          source.emit((selected: old.selected + 1, unrelated: old.unrelated));
          source.emit(old);
      }
      counts.add('source_notifications', change == .roundTrip ? 2 : 1);
      await tester.pump();
    },
  );

  for (var i = 0; i < _leafCount; i++) {
    expect(tester.element(find.byKey(keys[i])), same(before[i]));
    expect(tester.renderObject(find.byKey(keys[i])), same(renders[i]));
    expect(renders[i].content?.payload, 'value=${source.value.selected}');
    if (stableChild) expect(tester.widget(find.byKey(staticKeys[i])), same(staticWidgets[i]));
  }
  expect(result.total('view_mount'), 0);
  expect(result.total('view_render_create'), 0);
  final valueSelection = listener == .scalar || listener == .record || listener == .listValue;
  if (valueSelection && change != .selected) {
    expect(result.total('business_builder'), 0, reason: '被选字段最终相同，应复用缓存的业务子树。');
    expect(result.total('view_render_update'), 0);
    expect(result.total('view_layout'), 0);
  } else {
    expect(result.total('business_builder'), greaterThan(0));
  }
  if (stableChild) {
    expect(result.total('static_build'), 0, reason: '稳定 child 不随监听器业务构建更新。');
  } else {
    expect(result.total('static_build'), greaterThan(0));
  }
  if (change == .selected) expect(result.total('view_layout'), greaterThan(0));
  // Element 层的实际次数仅报告，不锁死当前多余重建，为后续优化保留空间。
  await tester.pumpWidget(SizedBox.shrink());
}

class _StaticContent extends StatelessWidget {
  _StaticContent({required this.counts, super.key}) {
    counts.add('static_widget_create');
  }

  final BenchCounts counts;

  @override
  Widget build(BuildContext context) {
    counts.add('static_build');
    return Text('固定内容', style: TextStyle(fontSize: 12));
  }
}

class _LabelScope extends InheritedWidget {
  const _LabelScope({required this.label, required super.child});

  final String label;

  static String of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_LabelScope>()!.label;

  @override
  bool updateShouldNotify(_LabelScope oldWidget) => label != oldWidget.label;
}

void _reportObservation(WidgetTester tester, String name, List<String> expected, BenchCounts counts) {
  final actual = tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data).toList();
  final matchesExpected = listEquals(actual, expected);
  // 这里表征现状，刻意不把陈旧输出写成应当保留的正确性断言。
  debugPrintSynchronously(
    'VIEW_REUSE_OBSERVATION ${jsonEncode({'suite': 'listenable_semantics', 'name': name, 'expected_from_new_configuration': expected, 'actual': actual, 'matches_new_configuration': matchesExpected, 'semantic_gap': !matchesExpected, 'counts': counts.snapshot()})}',
  );
  expect(tester.takeException(), isNull);
}
