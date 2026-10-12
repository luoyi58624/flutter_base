import 'package:flutter_base/flutter_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Obs notify() 边缘行为', () {
    test('回调执行期间自移除不应抛异常', () {
      final obs = Obs(0);

      late VoidCallback cb;
      cb = () {
        // 模拟回调执行期间解绑自己（例如触发卸载/清理）
        obs.obsBuilders.remove(cb);
      };

      obs.obsBuilders.add(cb);
      obs.notify();

      expect(obs.obsBuilders.length, 0);
    });

    test('回调执行期间新增回调不应影响本轮遍历且不抛异常', () {
      final obs = Obs(0);
      final calls = <String>[];

      late VoidCallback cb1;
      late VoidCallback cb2;

      cb2 = () => calls.add('cb2');
      cb1 = () {
        calls.add('cb1');
        obs.obsBuilders.add(cb2);
      };

      obs.obsBuilders.add(cb1);
      obs.notify();
      expect(calls, ['cb1']); // 本轮快照不会执行新增的 cb2

      calls.clear();
      obs.notify();
      expect(calls.toSet(), {'cb1', 'cb2'});
    });
  });

  group('Obs keepAliveTime setter', () {
    test('setter 应该反映到 getter', () {
      final obs = Obs(0);

      obs.keepAliveTime = null;
      expect(obs.keepAliveTime, null);
    });
  });

  group('ObsBuilder 依赖收集/解绑（复杂场景）', () {
    testWidgets('动态依赖切换应解绑旧 Obs，避免越绑越多', (tester) async {
      final a = Obs(0);
      final b = Obs(0);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              // 用一个普通状态控制依赖切换
              final useA = ValueNotifier<bool>(true);

              return Column(
                children: [
                  ValueListenableBuilder(
                    valueListenable: useA,
                    builder: (context, value, _) {
                      return ObsBuilder(
                        builder: (context) =>
                            Text(value ? 'A:${a.value}' : 'B:${b.value}'),
                      );
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => useA.value = !useA.value,
                    child: const Text('toggle'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      // 首次构建只依赖 a
      expect(a.obsBuilders.length, 1);
      expect(b.obsBuilders.length, 0);

      await tester.tap(find.text('toggle'));
      await tester.pump();

      // 切换后应解绑 a，绑定 b
      expect(a.obsBuilders.length, 0);
      expect(b.obsBuilders.length, 1);
    });

    testWidgets('嵌套 ObsBuilder：内层重建不应污染外层依赖集合', (tester) async {
      final outer = Obs(0);
      final inner = Obs(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ObsBuilder(
            builder: (context) {
              // 外层只依赖 outer
              final o = outer.value;
              return Column(
                children: [
                  Text('outer:$o'),
                  ObsBuilder(
                    builder: (context) {
                      final i = inner.value;
                      return Text('inner:$i');
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );

      expect(outer.obsBuilders.length, 1);
      expect(inner.obsBuilders.length, 1);

      // 更新 inner 只应导致 inner 的依赖触发，不应导致 outer 多绑一个回调
      inner.value++;
      await tester.pump();
      expect(find.text('inner:1'), findsOneWidget);
      expect(find.text('outer:0'), findsOneWidget);
      expect(outer.obsBuilders.length, 1);
      expect(inner.obsBuilders.length, 1);
    });

    testWidgets('同一 ObsBuilder 内依赖列表变化（for/列表）应正确解绑', (tester) async {
      final items = List.generate(3, (i) => Obs(i));
      final count = ValueNotifier<int>(3);

      Widget build() {
        return MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: count,
            builder: (context, c, _) {
              return ObsBuilder(
                builder: (context) {
                  // 动态依赖：取前 c 个
                  final values = <int>[];
                  for (var i = 0; i < c; i++) {
                    values.add(items[i].value);
                  }
                  return Text(values.join(','));
                },
              );
            },
          ),
        );
      }

      await tester.pumpWidget(build());
      expect(items[0].obsBuilders.length, 1);
      expect(items[1].obsBuilders.length, 1);
      expect(items[2].obsBuilders.length, 1);

      count.value = 1;
      await tester.pump();

      // 只依赖第 0 个，其余应解绑
      expect(items[0].obsBuilders.length, 1);
      expect(items[1].obsBuilders.length, 0);
      expect(items[2].obsBuilders.length, 0);
    });

    testWidgets('ignoreObs=true 时读取 Obs.value 不应建立依赖', (tester) async {
      final obs = Obs(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ObsBuilder(
            ignoreObs: true,
            builder: (context) => Text('v:${obs.value}'),
          ),
        ),
      );

      expect(obs.obsBuilders.length, 0);
    });

    testWidgets('listenables 绑定/解绑应随列表变化生效', (tester) async {
      final obs = Obs(0);
      final flag = ValueNotifier<bool>(false);
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: flag,
            builder: (context, on, _) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () => flag.value = !flag.value,
                    child: const Text('toggle'),
                  ),
                  ObsBuilder(
                    ignoreObs: true,
                    listenables: [if (on) obs],
                    builder: (context) {
                      buildCount++;
                      return Text('buildCount:$buildCount');
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );

      final before = buildCount;
      obs.value++;
      await tester.pump();
      expect(buildCount, before); // 未监听

      await tester.tap(find.text('toggle'));
      await tester.pump();

      final before2 = buildCount;
      obs.value++;
      await tester.pump();
      expect(buildCount, before2 + 1); // 开始监听后应重建
    });
  });

  group('ObsBuilder update/异常边缘行为', () {
    testWidgets('builder 抛异常必须弹出收集栈，部分依赖不泄漏', (tester) async {
      final count = Obs(0);
      final shouldThrow = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: shouldThrow,
            builder: (context, v, _) {
              return ObsBuilder(
                builder: (context) {
                  final c = count.value; // 抛异常前已收集的部分依赖
                  if (v) throw StateError('builder error');
                  return Text('count:$c');
                },
              );
            },
          ),
        ),
      );
      expect(tester.takeException(), isA<StateError>());

      // 异常前收集到的部分依赖应并入 element 的依赖集合，而不是变成孤儿绑定
      expect(count.obsBuilders.length, 1);

      // 收集栈必须已弹出：build 之外访问 Obs 不应建立任何依赖
      final probe = Obs(0);
      expect(probe.value, 0);
      expect(probe.obsBuilders.length, 0);

      // 恢复正常构建后，增量解绑接管部分依赖，UI 正常响应
      shouldThrow.value = false;
      await tester.pump();
      expect(find.text('count:0'), findsOneWidget);
      expect(count.obsBuilders.length, 1);

      count.value++;
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);
    });

    testWidgets('builder 为方法 tear-off 时，父级重建必须触发重建', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Material(child: _TearOffPage())),
      );
      expect(find.text('label:0 count:0'), findsOneWidget);

      // tear-off 前后相等，但 update 契约要求无条件重建，label 必须刷新
      await tester.tap(find.text('inc'));
      await tester.pump();
      expect(find.text('label:1 count:0'), findsOneWidget);

      // 强制重建后 Obs 依赖保持正常
      final state = tester.state<_TearOffPageState>(find.byType(_TearOffPage));
      state.count.value++;
      await tester.pump();
      expect(find.text('label:1 count:1'), findsOneWidget);
    });
  });
}

class _TearOffPage extends StatefulWidget {
  const _TearOffPage();

  @override
  State<_TearOffPage> createState() => _TearOffPageState();
}

class _TearOffPageState extends State<_TearOffPage> {
  final count = Obs(0);
  int label = 0;

  Widget _buildContent(BuildContext context) =>
      Text('label:$label count:${count.value}');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => setState(() => label++),
          child: const Text('inc'),
        ),
        ObsBuilder(builder: _buildContent),
      ],
    );
  }
}
