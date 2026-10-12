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

  testWidgets('useHookState 按 keys 重建并释放旧状态', (tester) async {
    final events = <String>[];
    late _LocalState current;
    Widget scene(int key) => HookBuilder(
      builder: (_) {
        current = useHookState(() => _LocalState(events), keys: [key]);
        return Text('${current.count}', textDirection: TextDirection.ltr);
      },
    );
    await tester.pumpWidget(scene(1));
    final first = current;
    current.count = 2;
    current.notify();
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await tester.pumpWidget(scene(1));
    expect(current, same(first));
    await tester.pumpWidget(scene(2));
    expect(current, isNot(same(first)));
    expect(events.where((event) => event == 'init').length, 2);
    expect(events.where((event) => event == 'dispose').length, 1);
    await tester.pumpWidget(SizedBox());
    expect(events.where((event) => event == 'dispose').length, 2);
  });

  testWidgets('useWatch 切换观察对象后以新对象当前值作为旧值', (tester) async {
    final first = ValueNotifier(1);
    final second = ValueNotifier(10);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final changes = <(int, int)>[];
    Widget scene(ValueNotifier<int> model) => HookBuilder(
      builder: (_) {
        useWatch(model, (value, old) {
          changes.add((value, old));
          return null;
        });
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(first));
    first.value = 2;
    expect(changes, [(2, 1)]);
    await tester.pumpWidget(scene(second));
    first.value = 3;
    second.value = 11;
    expect(changes, [(2, 1), (11, 10)]);
    await tester.pumpWidget(SizedBox());
    second.value = 12;
    expect(changes.length, 2);
  });

  testWidgets('useAddListener 同一对象切换回调并在卸载时解绑', (tester) async {
    final model = ValueNotifier(0);
    addTearDown(model.dispose);
    final calls = <String>[];
    void first() => calls.add('first');
    void second() => calls.add('second');
    Widget scene(VoidCallback callback) => HookBuilder(
      builder: (_) {
        useAddListener(model, callback);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(first));
    model.value = 1;
    await tester.pumpWidget(scene(second));
    model.value = 2;
    expect(calls, ['first', 'second']);
    await tester.pumpWidget(SizedBox());
    model.value = 3;
    expect(calls, ['first', 'second']);
  });

  testWidgets('动画状态监听支持同一控制器更换回调', (tester) async {
    final controller = AnimationController(vsync: tester);
    addTearDown(controller.dispose);
    final calls = <String>[];
    void first(AnimationStatus status) => calls.add('first');
    void second(AnimationStatus status) => calls.add('second');
    Widget scene(AnimationStatusListener callback) => HookBuilder(
      builder: (_) {
        useAnimationStatusListener(controller, callback);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(first));
    controller.value = 1;
    await tester.pumpWidget(scene(second));
    controller.value = 0;
    expect(calls, ['first', 'second']);
    await tester.pumpWidget(SizedBox());
    controller.value = 1;
    expect(calls.length, 2);
  });

  testWidgets('useDidUpdate 首次更新传递初始 widget', (tester) async {
    final updates = <Widget>[];
    final first = SizedBox(width: 1);
    final second = SizedBox(width: 2);
    Widget scene(Widget widget) => HookBuilder(
      builder: (_) {
        useDidUpdate(updates.add, widget);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(first));
    expect(updates, isEmpty);
    await tester.pumpWidget(scene(second));
    expect(updates, [first]);
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

  testWidgets('曲线 hook 保留实例并响应曲线变化', (tester) async {
    final controller = AnimationController(vsync: tester)..value = 0.5;
    addTearDown(controller.dispose);
    late CurvedAnimation current;
    Widget scene(Curve curve) => HookBuilder(
      builder: (_) {
        current = useCurvedAnimation(parent: controller, curve: curve);
        return SizedBox();
      },
    );
    await tester.pumpWidget(scene(Curves.linear));
    final first = current;
    expect(current.value, 0.5);
    await tester.pumpWidget(scene(Curves.easeIn));
    expect(current, same(first));
    expect(current.value, closeTo(Curves.easeIn.transform(0.5), 0.0001));
    await tester.pumpWidget(SizedBox());
  });
}

class _LocalState extends ElHookState {
  _LocalState(this.events);
  final List<String> events;
  int count = 0;
  @override
  void initState() => events.add('init');
  @override
  void dispose() {
    events.add('dispose');
    super.dispose();
  }
}
