import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('受控值在当前构建生效且不重复构建自身', (tester) async {
    final probe = _Probe();
    Widget scene(int value) => Directionality(
      textDirection: TextDirection.ltr,
      child: _TestModel(value: value, probe: probe),
    );
    await tester.pumpWidget(scene(0));
    final initialBuilds = probe.rendered.length;
    await tester.pumpWidget(scene(1));
    final firstPumpValue = tester.widget<Text>(find.byType(Text)).data;
    final buildsAfterFirstPump = probe.rendered.length - initialBuilds;
    await tester.pump();
    final buildsAfterSecondPump = probe.rendered.length - initialBuilds;
    // 两个版本使用完全相同的操作，记录确定的工作量而非主机耗时。
    debugPrint(
      'MODEL_VALUE_PERF ${jsonEncode({'first_pump_value': firstPumpValue, 'first_pump_builds': buildsAfterFirstPump, 'total_builds': buildsAfterSecondPump, 'scheduled_frame': tester.binding.hasScheduledFrame})}',
    );
    expect(firstPumpValue, '1');
    expect(buildsAfterFirstPump, 1);
    expect(buildsAfterSecondPump, 1);
    expect(probe.commands, isEmpty);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('受控回传同值不补发通知或业务命令', (tester) async {
    final probe = _Probe();
    Widget scene(int value) => Directionality(
      textDirection: TextDirection.ltr,
      child: _TestModel(value: value, probe: probe),
    );
    await tester.pumpWidget(scene(0));
    var notifications = 0;
    probe.obs.addListener(() => notifications++);
    probe.obs.value = 1;
    await tester.pump();
    expect(notifications, 1);
    expect(probe.commands, [1]);
    await tester.pumpWidget(scene(1));
    expect(notifications, 1);
    expect(probe.commands, [1]);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('回放监听者同步修正新值仍刷新自身并通知业务', (tester) async {
    final probe = _Probe();
    Widget scene(int value) => Directionality(
      textDirection: TextDirection.ltr,
      child: _TestModel(value: value, probe: probe),
    );
    await tester.pumpWidget(scene(0));
    probe.obs.addListener(() {
      if (probe.obs.rawValue == 1) probe.obs.value = 2;
    });
    await tester.pumpWidget(scene(1));
    expect(probe.obs.rawValue, 2);
    expect(probe.commands, [2]);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('回放监听者改值后改回原值也不能吞掉新通知', (tester) async {
    final probe = _Probe();
    Widget scene(int value) => Directionality(
      textDirection: TextDirection.ltr,
      child: _TestModel(value: value, probe: probe),
    );
    await tester.pumpWidget(scene(0));
    var normalized = false;
    probe.obs.addListener(() {
      if (normalized) return;
      normalized = true;
      probe.obs.value = 2;
      probe.obs.value = 1;
    });
    await tester.pumpWidget(scene(1));
    expect(probe.commands, [2, 1]);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('回放前的新通知覆盖旧输入且不重复发布', (tester) async {
    final probe = _Probe();
    Widget scene(int value) => Directionality(
      textDirection: TextDirection.ltr,
      child: _TestModel(value: value, probe: probe),
    );
    await tester.pumpWidget(scene(0));
    final notifications = <int>[];
    probe.obs.addListener(() => notifications.add(probe.obs.rawValue));
    // 先登记帧后更新，使其先于本次构建登记的输入回放执行。
    tester.binding.addPostFrameCallback((_) => probe.obs.value = 2);
    await tester.pumpWidget(scene(1));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(notifications, [2]);
    expect(probe.commands, [2]);
  });

  testWidgets('同帧连续回灌合并为一次外部通知', (tester) async {
    final probe = _Probe();
    final key = GlobalKey();
    await tester.pumpWidget(_batchScene(probe, key));
    final notifications = <int>[];
    probe.obs.addListener(() => notifications.add(probe.obs.rawValue));
    await tester.pumpWidget(_batchScene(probe, key, inputs: [1, 2]));
    expect(find.text('2'), findsOneWidget);
    expect(notifications, [2]);
    expect(probe.commands, isEmpty);
    final builds = probe.rendered.length;
    await tester.pump();
    expect(probe.rendered.length, builds);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('登记回放后在同帧卸载不再通知已释放模型', (tester) async {
    final probe = _Probe();
    final key = GlobalKey();
    await tester.pumpWidget(_batchScene(probe, key));
    var notifications = 0;
    probe.obs.addListener(() => notifications++);
    await tester.pumpWidget(_batchScene(probe, key, inputs: [1], remove: true));
    expect(key.currentContext, isNull);
    expect(notifications, 0);
    expect(probe.commands, isEmpty);
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('同帧回灌最终回到原值不补发无效通知', (tester) async {
    final probe = _Probe();
    final key = GlobalKey();
    await tester.pumpWidget(_batchScene(probe, key));
    var notifications = 0;
    probe.obs.addListener(() => notifications++);
    await tester.pumpWidget(_batchScene(probe, key, inputs: [1, 0]));
    expect(find.text('0'), findsOneWidget);
    expect(notifications, 0);
    expect(probe.commands, isEmpty);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('同帧替换模型后改为同值普通输入不发业务命令', (tester) async {
    final probe = _Probe();
    final key = GlobalKey();
    final model = ValueNotifier(1);
    addTearDown(model.dispose);
    await tester.pumpWidget(_batchScene(probe, key));
    await tester.pumpWidget(_batchScene(probe, key, inputs: [0, 1], sources: [model, null]));
    expect(find.text('1'), findsOneWidget);
    expect(probe.commands, isEmpty, reason: '最终通道是普通 value，不能沿用中间模型替换的命令标记');
    model.value = 2;
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(probe.commands, isEmpty);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('同帧普通输入后替换为同值模型保留模型变更通知', (tester) async {
    final probe = _Probe();
    final key = GlobalKey();
    final model = ValueNotifier(1);
    addTearDown(model.dispose);
    await tester.pumpWidget(_batchScene(probe, key));
    await tester.pumpWidget(_batchScene(probe, key, inputs: [1, 1], sources: [null, model]));
    expect(find.text('1'), findsOneWidget);
    expect(probe.commands, [1], reason: '最终通道是新模型，不能沿用中间普通输入的抑制标记');
    await tester.pump();
    expect(probe.commands, [1]);
    model.value = 2;
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(probe.commands, [1, 2]);
  });

  testWidgets('替换 modelValue 同帧生效且监听器转移到新对象', (tester) async {
    final first = ValueNotifier(0);
    final second = ValueNotifier(1);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final probe = _Probe();
    Widget scene(ValueNotifier<int> model) => Directionality(
      textDirection: TextDirection.ltr,
      child: _TestModel(modelValue: model, probe: probe),
    );
    await tester.pumpWidget(scene(first));
    final before = probe.rendered.length;
    await tester.pumpWidget(scene(second));
    expect(find.text('1'), findsOneWidget);
    expect(probe.commands, [1]);
    await tester.pump();
    expect(probe.rendered.length - before, 1);
    first.value = 3;
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    second.value = 2;
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(probe.commands, [1, 2]);
    await tester.pumpWidget(SizedBox());
    second.value = 4;
    expect(probe.commands, [1, 2]);
  });

  testWidgets('内部写回 modelValue 被同步规范化后不发送外层陈旧命令', (tester) async {
    final model = ValueNotifier(0);
    addTearDown(model.dispose);
    model.addListener(() {
      if (model.value == 1) model.value = 2;
    });
    final probe = _Probe();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _TestModel(modelValue: model, probe: probe),
      ),
    );
    probe.obs.value = 1;
    expect(model.value, 2);
    expect(probe.obs.rawValue, 2);
    expect(probe.commands, [2], reason: '新版本已经通知业务，不能再跟着发送被规范化掉的旧值 1');
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('modelValue 规范化改值再改回也按新通知版本去除外层回声', (tester) async {
    final model = ValueNotifier(0);
    addTearDown(model.dispose);
    var normalized = false;
    model.addListener(() {
      if (normalized || model.value != 1) return;
      normalized = true;
      model.value = 2;
      model.value = 1;
    });
    final probe = _Probe();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _TestModel(modelValue: model, probe: probe),
      ),
    );
    probe.obs.value = 1;
    expect(model.value, 1);
    expect(probe.obs.rawValue, 1);
    expect(probe.commands, [2, 1], reason: '两个新通知各处理一次，外层旧通知不能仅凭最终值相等再发一次 1');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('外部 modelValue 先规范化再传播时最终新值仍恰好通知一次', (tester) async {
    final model = ValueNotifier(0);
    addTearDown(model.dispose);
    model.addListener(() {
      if (model.value == 1) model.value = 2;
    });
    final probe = _Probe();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _TestModel(modelValue: model, probe: probe),
      ),
    );
    model.value = 1;
    expect(probe.commands, [2]);
    expect(probe.obs.rawValue, 2);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('移除 modelValue 后采用普通 value 且不发命令', (tester) async {
    final model = ValueNotifier(7);
    addTearDown(model.dispose);
    final probe = _Probe();
    Widget scene(ValueNotifier<int>? source) => Directionality(
      textDirection: TextDirection.ltr,
      child: _TestModel(value: 3, modelValue: source, probe: probe),
    );
    await tester.pumpWidget(scene(model));
    expect(find.text('7'), findsOneWidget);
    await tester.pumpWidget(scene(null));
    expect(find.text('3'), findsOneWidget);
    expect(probe.commands, isEmpty);
    model.value = 9;
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('子树外观察者在帧后收到更新避免构建期越界标脏', (tester) async {
    final probe = _Probe();
    final external = ValueNotifier(0);
    addTearDown(external.dispose);
    Widget scene(int value) => Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          ValueListenableBuilder(valueListenable: external, builder: (context, value, _) => Text('external:$value')),
          _TestModel(value: value, probe: probe),
        ],
      ),
    );
    await tester.pumpWidget(scene(0));
    probe.obs.addListener(() => external.value = probe.obs.rawValue);
    await tester.pumpWidget(scene(1));
    expect(tester.takeException(), isNull);
    expect(find.text('1'), findsOneWidget);
    expect(external.value, 1);
    await tester.pump();
    expect(find.text('external:1'), findsOneWidget);
    expect(probe.commands, isEmpty);
  });
}

class _Probe {
  late Obs<int> obs;
  final rendered = <int>[];
  final commands = <int>[];
}

class _TestModel extends ElModelValue<int> {
  _TestModel({super.key, super.value = 0, super.modelValue, required this.probe})
    : super(onChanged: probe.commands.add);

  final _Probe probe;

  @override
  Widget obsBuilder(BuildContext context) {
    probe.obs = $obs;
    probe.rendered.add($obs.rawValue);
    return Text('${$obs.value}');
  }
}

// 模拟 RecyclerView 布局中的多次绑定，覆盖普通 pump 无法分开的帧后回放窗口。
Widget _batchScene(
  _Probe probe,
  GlobalKey key, {
  List<int> inputs = const [],
  List<ValueNotifier<int>?>? sources,
  bool remove = false,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: LayoutBuilder(
    builder: (context, constraints) {
      Widget result = _TestModel(key: key, value: 0, probe: probe);
      final target = key.currentContext as Element?;
      if (target != null) {
        for (var index = 0; index < inputs.length; index++) {
          result = _TestModel(key: key, value: inputs[index], modelValue: sources?[index], probe: probe);
          target.update(result);
        }
      }
      return remove ? SizedBox() : result;
    },
  ),
);
