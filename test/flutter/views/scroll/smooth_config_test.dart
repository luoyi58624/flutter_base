import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _windowsTest('平滑环境省略或占位符继承，builder 为 null 与返回 null 均明确关闭', (tester) async {
    final inherited = _FixedStepSmooth(110);
    final local = _FixedStepSmooth(170);
    final values = <String, ElSmoothScroll?>{};
    Widget probe(String name) => Builder(
      builder: (context) {
        values[name] = ElViewProvider.smoothScrollOf(context);
        return SizedBox();
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Column(
          children: [
            probe('platform'),
            ElViewProvider(
              smoothScrollBuilder: (_) => inherited,
              child: Column(
                children: [
                  ElViewProvider(child: probe('omitted')),
                  ElViewProvider(smoothScrollBuilder: (_) => $absent, child: probe('adaptive')),
                  ElViewProvider(smoothScrollBuilder: null, child: probe('null-builder')),
                  ElViewProvider(smoothScrollBuilder: (_) => null, child: probe('null-result')),
                  ElViewProvider(smoothScrollBuilder: (_) => local, child: probe('custom')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    expect(values['platform'], isA<ElWindowsSmoothScroll>());
    expect(values['omitted'], same(inherited));
    expect(values['adaptive'], same(inherited));
    expect(values['null-builder'], isNull);
    expect(values['null-result'], isNull);
    expect(values['custom'], same(local));
  });

  _windowsTest('父环境明确关闭后，内层省略或占位符不会重新启用平台默认', (tester) async {
    final local = _FixedStepSmooth(170);
    final values = <String, ElSmoothScroll?>{};
    Widget probe(String name) => Builder(
      builder: (context) {
        values[name] = ElViewProvider.smoothScrollOf(context);
        return SizedBox();
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElViewProvider(
          smoothScrollBuilder: (_) => null,
          child: Column(
            children: [
              probe('disabled'),
              ElViewProvider(child: probe('omitted')),
              ElViewProvider(smoothScrollBuilder: (_) => $absent, child: probe('adaptive')),
              ElViewProvider(smoothScrollBuilder: (_) => local, child: probe('custom')),
            ],
          ),
        ),
      ),
    );
    expect(values['disabled'], isNull);
    expect(values['omitted'], isNull);
    expect(values['adaptive'], isNull);
    expect(values['custom'], same(local));
  });

  _windowsTest('运行时切换算法、null 与占位符只通知平滑消费者且保持子树 State', (tester) async {
    final inherited = _FixedStepSmooth(110);
    final local = _FixedStepSmooth(170);
    final selected = ValueNotifier<Object?>(local);
    addTearDown(selected.dispose);
    var smoothBuilds = 0;
    var refresherBuilds = 0;
    ElSmoothScroll? value;
    final smoothProbe = _SmoothProbe((algorithm) {
      smoothBuilds++;
      value = algorithm;
    });
    final content = Column(children: [smoothProbe, _RefresherProbe(() => refresherBuilds++)]);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElViewProvider(
          smoothScrollBuilder: (_) => inherited,
          child: ValueListenableBuilder<Object?>(
            valueListenable: selected,
            child: content,
            builder: (context, value, child) => ElViewProvider(smoothScrollBuilder: (_) => value, child: child!),
          ),
        ),
      ),
    );
    final state = tester.state(find.byWidget(smoothProbe));
    expect(value, same(local));
    expect(smoothBuilds, 1);
    expect(refresherBuilds, 1);

    selected.value = null;
    await tester.pump();
    expect(value, isNull);
    expect(smoothBuilds, 2);
    expect(refresherBuilds, 1);
    expect(tester.state(find.byWidget(smoothProbe)), same(state));

    selected.value = $absent;
    await tester.pump();
    expect(value, same(inherited));
    expect(smoothBuilds, 3);
    expect(refresherBuilds, 1);
    expect(tester.state(find.byWidget(smoothProbe)), same(state));
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['omitted', 'adaptive', 'disabled', 'custom']) {
    _windowsTest('ElScrollView 在自定义父环境下的 $mode 配置真正决定滚轮执行', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final inherited = _FixedStepSmooth(110);
      final custom = _FixedStepSmooth(170);
      await _openScroll(tester, controller, mode: mode, parent: inherited, local: custom);
      final expected = mode == 'disabled'
          ? 80.0
          : mode == 'custom'
          ? 170.0
          : 110.0;
      await _expectWheel(tester, controller, expected: expected, animated: mode != 'disabled');
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in ['omitted', 'adaptive']) {
    _windowsTest('ElScrollView $mode 继承父环境关闭且不会回退 Windows 平滑', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _openScroll(tester, controller, mode: mode, parent: null);
      await _expectWheel(tester, controller, expected: 80, animated: false);
      expect(tester.takeException(), isNull);
    });
  }

  _windowsTest('ElScrollView 占位符在无父环境时自适应 Windows 平滑', (tester) async {
    final controller = ElScrollController();
    addTearDown(controller.dispose);
    await _openScroll(tester, controller, mode: 'adaptive');
    await _expectWheel(tester, controller, expected: 80, animated: true);
    expect(tester.takeException(), isNull);
  });
}

void _windowsTest(String description, WidgetTesterCallback callback) =>
    testWidgets(description, callback, variant: TargetPlatformVariant.only(TargetPlatform.windows));

Future<void> _openScroll(
  WidgetTester tester,
  ElScrollController controller, {
  required String mode,
  Object? parent = $absent,
  ElSmoothScroll? local,
}) async {
  final children = [
    ElListView.builder(
      fixedSize: true,
      keepAlive: false,
      itemCount: 100,
      itemBuilder: (context, index) => SizedBox(height: 48, child: Text('数据 $index')),
    ),
  ];
  final scroll = mode == 'omitted'
      ? ElScrollView(controller: controller, scrollbar: ElNoScrollBar(), children: children)
      : ElScrollView(
          controller: controller,
          scrollbar: ElNoScrollBar(),
          smoothScroll: switch (mode) {
            'adaptive' => $absent,
            'disabled' => null,
            _ => local,
          },
          children: children,
        );
  await tester.pumpWidget(
    ElViewProvider(
      smoothScrollBuilder: (_) => parent,
      child: MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: SizedBox(width: 320, height: 240, child: scroll),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectWheel(
  WidgetTester tester,
  ElScrollController controller, {
  required double expected,
  required bool animated,
}) async {
  expect(controller.dispatchPointerScroll(PointerScrollEvent(kind: .mouse, scrollDelta: Offset(0, 80))), isTrue);
  if (animated) {
    expect(controller.offset, 0, reason: '自适应或指定算法必须进入真实平滑活动');
    await tester.pump();
    await tester.pump(Duration(milliseconds: 16));
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThan(expected));
  } else {
    expect(controller.offset, closeTo(expected, .01), reason: 'null 必须当场直滚，不能先继承父算法');
  }
  await tester.pumpAndSettle(Duration(milliseconds: 16));
  expect(controller.offset, closeTo(expected, .01));
}

class _FixedStepSmooth extends ElSmoothScroll {
  _FixedStepSmooth(this.step);
  final double step;
  @override
  double stepForEvent(double rawDelta, int burstTicks) => step * rawDelta.sign;
  @override
  Duration segmentDuration(double delta, double velocity) => Duration(milliseconds: 100);
  @override
  Curve curveFor(double initialSlope) => Curves.linear;
}

class _SmoothProbe extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _SmoothProbe(this.onBuild);
  final ValueChanged<ElSmoothScroll?> onBuild;
  @override
  State<_SmoothProbe> createState() => _SmoothProbeState();
}

class _SmoothProbeState extends State<_SmoothProbe> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild(ElViewProvider.smoothScrollOf(context));
    return SizedBox();
  }
}

class _RefresherProbe extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _RefresherProbe(this.onBuild);
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) {
    ElViewProvider.refresherOf(context);
    onBuild();
    return SizedBox();
  }
}
