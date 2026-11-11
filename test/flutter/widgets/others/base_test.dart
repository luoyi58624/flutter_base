import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final selection in ['scalar', 'record', 'nullable']) {
    testWidgets('$selection 等值通知跳过监听器 Element，变化通知显示最终值', (tester) async {
      final model = _Model();
      addTearDown(model.dispose);
      final log = _observeBuilds();
      var builds = 0;
      await tester.pumpWidget(
        _scene(
          ElListenableBuilder<_Model, Object?>(
            listenable: model,
            select: (value) => switch (selection) {
              'record' => (value.count, 'fixed'),
              'nullable' => value.count == 0 ? null : value.count,
              _ => value.count,
            },
            builder: (_, _) {
              builds++;
              return Text('${model.count}');
            },
          ),
        ),
      );
      log.builds = 0;
      model.refresh();
      model.other++;
      model.refresh();
      await tester.pump();
      expect(log.builds, 0, reason: '等值通知应跳过 Element，而不只是返回缓存子树。');
      expect(builds, 1);
      model.count = 1;
      model.refresh();
      model.count = 2;
      model.refresh();
      await tester.pump();
      expect(builds, 2);
      expect(find.text('2'), findsOneWidget);
      await tester.pumpWidget(SizedBox.shrink());
      expect(model.listeners, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('同帧变化后回到原值不重建业务子树', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    final log = _observeBuilds();
    var builds = 0;
    await tester.pumpWidget(
      _scene(
        ElListenableBuilder<_Model, int>(
          listenable: model,
          select: (value) => value.count,
          builder: (_, _) {
            builds++;
            return Text('${model.count}');
          },
        ),
      ),
    );
    log.builds = 0;
    model.count = 1;
    model.refresh();
    model.count = 0;
    model.refresh();
    await tester.pump();
    expect(builds, 1);
    expect(log.builds, lessThanOrEqualTo(1));
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('自定义谓词保留等值构建和上一次观察值', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    final comparisons = <(int, int)>[];
    var builds = 0;
    await tester.pumpWidget(
      _scene(
        ElListenableBuilder<_Model, int>(
          listenable: model,
          select: (value) => value.count,
          shouldRebuild: (next, previous) {
            comparisons.add((next, previous));
            return next == 0 || next == 2;
          },
          builder: (_, _) {
            builds++;
            return Text('${model.count}');
          },
        ),
      ),
    );
    model.refresh();
    await tester.pump();
    expect(builds, 2);
    model.count = 1;
    model.refresh();
    await tester.pump();
    expect(builds, 2);
    model.count = 2;
    model.refresh();
    await tester.pump();
    expect(comparisons, [(0, 0), (1, 0), (2, 1)], reason: '旧值包含上次被谓词挡住的观察结果。');
    expect(find.text('2'), findsOneWidget);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('父配置更新 builder 和 child，即使选择值相同', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    Widget scene(String label) => _scene(
      ElListenableBuilder<_Model, int>(
        listenable: model,
        select: (value) => value.count,
        builder: (_, child) => Column(children: [Text('builder:$label'), child!]),
        child: Text('child:$label'),
      ),
    );
    await tester.pumpWidget(scene('before'));
    await tester.pumpWidget(scene('after'));
    expect(find.text('builder:after'), findsOneWidget);
    expect(find.text('child:after'), findsOneWidget);
    expect(find.text('builder:before'), findsNothing);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('继承配置变化使 builder 读取新环境', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    final child = ElListenableBuilder<_Model, int>(
      listenable: model,
      select: (value) => value.count,
      builder: (context, _) => Text(_LabelScope.of(context)),
    );
    Widget scene(String label) => _scene(_LabelScope(label: label, child: child));
    await tester.pumpWidget(scene('before'));
    await tester.pumpWidget(scene('after'));
    expect(find.text('after'), findsOneWidget);
    expect(find.text('before'), findsNothing);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('切换选择器和同值来源刷新缓存并转移监听', (tester) async {
    final first = _Model()..count = 1;
    final second = _Model()..count = 1;
    first.other = 1;
    second.other = 1;
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final log = _observeBuilds();
    Widget scene(_Model source, bool selectOther, String name) => _scene(
      ElListenableBuilder<_Model, int>(
        listenable: source,
        select: (value) => selectOther ? value.other : value.count,
        builder: (_, _) => Text('$name:${selectOther ? source.other : source.count}'),
      ),
    );
    await tester.pumpWidget(scene(first, false, 'count'));
    await tester.pumpWidget(scene(first, true, 'other'));
    expect(find.text('other:1'), findsOneWidget);
    await tester.pumpWidget(scene(second, true, 'second'));
    expect(find.text('second:1'), findsOneWidget);
    expect(first.listeners, 0);
    expect(second.listeners, 1);
    log.builds = 0;
    first.refresh();
    await tester.pump();
    expect(log.builds, 0);
    second.other = 3;
    second.refresh();
    await tester.pump();
    expect(find.text('second:3'), findsOneWidget);
    await tester.pumpWidget(SizedBox.shrink());
    expect(second.listeners, 0);
  });

  for (final dependsOnScope in [false, true]) {
    testWidgets('GlobalKey 换父刷新当前数据，继承依赖=$dependsOnScope', (tester) async {
      final model = _Model();
      addTearDown(model.dispose);
      final key = GlobalKey();
      final child = ElListenableBuilder<_Model, int>(
        key: key,
        listenable: model,
        select: (value) => value.count,
        builder: (context, _) => Text('${dependsOnScope ? _LabelScope.of(context) : 'fixed'}:${model.count}'),
      );
      Widget scene(bool right) => _scene(
        Row(
          children: [
            Expanded(
              child: _LabelScope(label: 'left', child: right ? SizedBox.shrink() : child),
            ),
            Expanded(
              child: _LabelScope(label: 'right', child: right ? child : SizedBox.shrink()),
            ),
          ],
        ),
      );
      await tester.pumpWidget(scene(false));
      final element = key.currentContext;
      model.count = 7;
      await tester.pumpWidget(scene(true));
      expect(key.currentContext, same(element));
      expect(find.text('${dependsOnScope ? 'right' : 'fixed'}:7'), findsOneWidget);
      expect(model.listeners, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
    });
  }

  for (final failure in ['selector', 'builder']) {
    testWidgets('$failure 抛错后合法同值通知可恢复', (tester) async {
      final model = _Model();
      addTearDown(model.dispose);
      var fail = false;
      await tester.pumpWidget(
        _scene(
          ElListenableBuilder<_Model, int>(
            listenable: model,
            select: (value) {
              if (fail && failure == 'selector') throw StateError('selector failure');
              return value.count;
            },
            builder: (_, _) {
              if (fail && failure == 'builder') throw StateError('builder failure');
              return Text('${model.count}');
            },
          ),
        ),
      );
      model.count = 1;
      fail = true;
      model.refresh();
      expect(tester.takeException(), isNull, reason: '试算失败回到构建阶段报告，不在通知期间重复报告。');
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      expect(find.byType(ErrorWidget), findsOneWidget);
      fail = false;
      // 覆盖回到上次有效值及停留失败值两种恢复路径。
      if (failure == 'selector') model.count = 0;
      model.refresh();
      await tester.pump();
      expect(find.text('${model.count}'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
    });
  }

  testWidgets('选择过程中重入通知只安排构建并显示最终数据', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    var notifyInsideSelection = false;
    var depth = 0;
    var maxDepth = 0;
    await tester.pumpWidget(
      _scene(
        ElListenableBuilder<_Model, int>(
          listenable: model,
          select: (value) {
            depth++;
            if (depth > maxDepth) maxDepth = depth;
            try {
              if (notifyInsideSelection) {
                notifyInsideSelection = false;
                value.count = 2;
                value.refresh();
              }
              return value.count;
            } finally {
              depth--;
            }
          },
          builder: (_, _) => Text('${model.count}'),
        ),
      ),
    );
    model.count = 1;
    notifyInsideSelection = true;
    model.refresh();
    await tester.pump();
    expect(maxDepth, 1);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('无 select 和无监听源保持普通构建行为', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    var builds = 0;
    Widget scene(_Model? source, String label) => _scene(
      ElListenableBuilder<_Model, int>(
        listenable: source,
        builder: (_, _) {
          builds++;
          return Text(label);
        },
      ),
    );
    await tester.pumpWidget(scene(model, 'listening'));
    model.refresh();
    await tester.pump();
    expect(builds, 2);
    await tester.pumpWidget(scene(null, 'detached'));
    expect(find.text('detached'), findsOneWidget);
    expect(model.listeners, 0);
    await tester.pumpWidget(scene(null, 'new configuration'));
    expect(find.text('new configuration'), findsOneWidget);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('reassemble 清除选择缓存并重新执行 builder', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    var label = 'before';
    await tester.pumpWidget(
      _scene(
        ElListenableBuilder<_Model, int>(
          listenable: model,
          select: (value) => value.count,
          builder: (_, _) => Text(label),
        ),
      ),
    );
    label = 'after';
    // 只验证本组件的缓存失效，避免全局热重载等待假时钟中的 endOfFrame。
    tester.element(find.byWidgetPredicate((widget) => widget is ElListenableBuilder)).reassemble();
    await tester.pump();
    expect(find.text('after'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });
}

class _Model extends ChangeNotifier {
  int count = 0;
  int other = 0;
  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    listeners++;
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    listeners--;
  }

  void refresh() => notifyListeners();
}

class _BuildLog {
  int builds = 0;
}

_BuildLog _observeBuilds() {
  final log = _BuildLog();
  final previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    previous?.call(element, builtOnce);
    if (element.widget is ElListenableBuilder) log.builds++;
  };
  addTearDown(() => debugOnRebuildDirtyWidget = previous);
  return log;
}

Widget _scene(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

class _LabelScope extends InheritedWidget {
  const _LabelScope({required this.label, required super.child});

  final String label;

  static String of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_LabelScope>()!.label;

  @override
  bool updateShouldNotify(_LabelScope oldWidget) => label != oldWidget.label;
}
