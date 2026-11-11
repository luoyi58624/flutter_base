import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/flutter/views/view/element/view_element.dart';
import 'package:flutter_test/flutter_test.dart';

/// 显式开启计时采样；默认仅执行短小的工作量与正确性检查。
const benchmarkTiming = bool.fromEnvironment('VIEW_REUSE_TIMING');

/// 每个场景的测量次数，可用 dart-define 调整，默认限制机器占用。
const benchmarkSamples = int.fromEnvironment('VIEW_REUSE_SAMPLES', defaultValue: benchmarkTiming ? 12 : 3);

/// 计时模式正反顺序各测一轮，以观察顺序和 JIT 热身影响。
const benchmarkPasses = benchmarkTiming ? 2 : 1;

/// 测试侧工作计数，不修改生产代码或替代被测组件实现。
class BenchCounts {
  final _values = <String, int>{};

  /// 记录一次实际发生的工作。
  void add(String name, [int amount = 1]) => _values.update(name, (value) => value + amount, ifAbsent: () => amount);

  /// 读取当前累计值。
  int operator [](String name) => _values[name] ?? 0;

  /// 清空一个采样区间。
  void clear() => _values.clear();

  /// 复制采样结果。
  Map<String, int> snapshot() => Map.of(_values);

  /// 观察 Flutter 实际执行的 Element 重建，包括私有监听器和文本环境。
  void observeRebuilds() {
    final previous = debugOnRebuildDirtyWidget;
    final seen = Expando<bool>();
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      // 当前 SDK 只有开启逐条打印才维护 builtOnce，自己按 Element 身份记录，避免误报首次构建。
      add(seen[element] == true ? 'element_rebuild' : 'element_first_build');
      seen[element] = true;
      final widget = element.widget;
      if (widget is ElListenableBuilder) add('selector_element_build');
      if (widget is ValueListenableBuilder) add('value_element_build');
      if (widget.runtimeType.toString() == '_TextEnvironment') add('text_environment_build');
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
  }
}

/// 可以显式发送等值通知，避免 ValueNotifier 的赋值去重遮住被测行为。
class BenchValue<T> extends ChangeNotifier implements ValueListenable<T> {
  /// 创建带当前值的可控通知源。
  BenchValue(this.value);

  @override
  T value;

  /// 写入并通知，即使新旧值相等也发送。
  void emit(T next) {
    value = next;
    notifyListeners();
  }
}

/// 保留 ElView 全部真实行为，只在测试侧记录创建与配置更新。
class BenchView extends ElView {
  /// 创建观测视图，参数与 ElView 对应。
  BenchView({
    required this.counts,
    super.key,
    super.style,
    super.event,
    super.focusNode,
    super.semantics,
    super.child,
  }) {
    counts.add('view_widget_create');
  }

  /// 当前场景计数器。
  final BenchCounts counts;

  @override
  RenderObjectElement createElement() => _BenchViewElement(this);

  @override
  ElRenderView createRenderObject(BuildContext context) {
    counts.add('view_render_create');
    return super.createRenderObject(context);
  }

  @override
  void updateRenderObject(BuildContext context, ElRenderView renderObject) {
    counts.add('view_render_update');
    super.updateRenderObject(context, renderObject);
  }
}

class _BenchViewElement extends ViewElement {
  _BenchViewElement(BenchView super.widget);

  BenchCounts get counts => (widget as BenchView).counts;

  @override
  void mount(Element? parent, Object? newSlot) {
    counts.add('view_mount');
    super.mount(parent, newSlot);
  }

  @override
  void update(covariant BenchView newWidget) {
    counts.add('view_element_update');
    super.update(newWidget);
  }

  @override
  void performRebuild() {
    counts.add('view_perform_rebuild');
    super.performRebuild();
  }

  @override
  Element? updateContentChild(Element? child, Widget? widget, Object? slot) {
    if (widget?.runtimeType.toString() == '_TextEnvironment') counts.add('text_environment_update');
    return super.updateContentChild(child, widget, slot);
  }

  @override
  void unmount() {
    counts.add('view_unmount');
    super.unmount();
  }
}

/// 一个场景的原始样本及累计工作量，时间只表示带探针的无头 debug 墙钟。
class BenchResult {
  /// 保存场景数据。
  BenchResult(this.suite, this.name, this.pass, this.samples);

  /// 基准组。
  final String suite;

  /// 场景名称。
  final String name;

  /// 执行轮次。
  final int pass;

  /// 每次操作的时间和工作量。
  final List<({int micros, Map<String, int> counts})> samples;

  /// 求某项工作的总次数。
  int total(String name) => samples.fold(0, (sum, sample) => sum + (sample.counts[name] ?? 0));

  /// 输出可提取为 JSON 的结构化结果。
  void report() {
    final times = samples.map((sample) => sample.micros).toList()..sort();
    final keys = samples.expand((sample) => sample.counts.keys).toSet().toList()..sort();
    debugPrintSynchronously(
      'VIEW_REUSE_RESULT ${jsonEncode({
        'suite': suite,
        'name': name,
        'pass': pass,
        'samples': samples.length,
        'timing_enabled': benchmarkTiming,
        if (benchmarkTiming) 'median_us': times[(times.length - 1) ~/ 2],
        if (benchmarkTiming) 'p95_us': times[(times.length * .95).ceil() - 1],
        if (benchmarkTiming) 'raw_us': samples.map((sample) => sample.micros).toList(),
        'totals': {for (final key in keys) key: total(key)},
        'work_samples': samples.map((sample) => sample.counts).toList(),
      })}',
    );
  }
}

/// 热身后测量一次动作加一次或多次 pump，断言和报告不计入时间。
Future<BenchResult> measureBench(
  WidgetTester tester, {
  required String suite,
  required String name,
  required BenchCounts counts,
  required Future<void> Function(int iteration) action,
  int pass = 0,
  int warmup = 2,
  int samples = benchmarkSamples,
}) async {
  assert(samples > 0);
  for (var i = 0; i < warmup; i++) {
    await action(i);
  }
  final measured = <({int micros, Map<String, int> counts})>[];
  for (var i = 0; i < samples; i++) {
    counts.clear();
    BenchmarkProbe.reset();
    final watch = Stopwatch()..start();
    await action(i + warmup);
    watch.stop();
    final work = counts.snapshot();
    // 仅使用当前实现中仍实际递增的探针，避免旧字段的恒零值误导分析。
    work.addAll({
      'view_layout': BenchmarkProbe.performLayoutCount,
      'cascade': BenchmarkProbe.cascadeTickCount,
      'style_resolve': BenchmarkProbe.builderBuildCount,
      'text_engine_create': BenchmarkProbe.textLayerInstantiateCount,
      'event_dispatcher_create': BenchmarkProbe.eventDispatcherInstantiateCount,
    });
    measured.add((micros: watch.elapsedMicroseconds, counts: work));
    expect(tester.takeException(), isNull);
  }
  final result = BenchResult(suite, name, pass, measured);
  result.report();
  return result;
}

/// 提供固定方向、媒体参数与尺寸，避免 MaterialApp 路由等无关工作。
Widget benchScene(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(size: Size(800, 600)),
    child: child,
  ),
);
