import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('useObs 保留实例并在卸载时释放', (tester) async {
    late Obs<int> current;
    var builds = 0;
    Widget scene() => HookBuilder(
      builder: (_) {
        builds++;
        current = useObs(1);
        return ObsBuilder(
          builder: (_) =>
              Text('${current.value}', textDirection: TextDirection.ltr),
        );
      },
    );
    await tester.pumpWidget(scene());
    final original = current;
    current.value = 2;
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(builds, 1);
    await tester.pumpWidget(scene());
    expect(current, same(original));
    await tester.pumpWidget(SizedBox());
    expect(() => original.addListener(() {}), throwsFlutterError);
  });

  testWidgets('useMounted 只执行一次，更新 effect 按 keys 清理', (tester) async {
    final events = <String>[];
    Widget scene(int key) => HookBuilder(
      builder: (_) {
        useMounted(() => events.add('mounted'));
        useUpdateEffect(() {
          events.add('effect$key');
          return () => events.add('cleanup$key');
        }, [key]);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(1));
    expect(events, ['mounted']);
    await tester.pumpWidget(scene(2));
    await tester.pumpWidget(scene(3));
    await tester.pumpWidget(SizedBox());
    expect(
      events,
      containsAll(['mounted', 'effect2', 'cleanup2', 'effect3', 'cleanup3']),
    );
    expect(events.where((event) => event == 'mounted').length, 1);
    expect(events.where((event) => event == 'cleanup2').length, 1);
    expect(events.where((event) => event == 'cleanup3').length, 1);
  });

  testWidgets('useInterval 卸载时取消定时器', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      HookBuilder(
        builder: (_) {
          useInterval(() => calls++, 10);
          return SizedBox();
        },
      ),
    );
    await tester.pump(Duration(milliseconds: 35));
    expect(calls, 3);
    await tester.pumpWidget(SizedBox());
    await tester.pump(Duration(milliseconds: 30));
    expect(calls, 3);
  });
}
