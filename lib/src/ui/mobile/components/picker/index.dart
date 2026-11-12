import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../flutter.dart';
import '../../internal/common.dart';

/// 滚轮沿用原生固定项滚动，业务值始终对应可用选项。
Widget pickerBuilder<T>(BuildContext context, ElPicker<T> c, Obs<List<T>> model) => _Picker(c, model);

class _Picker<T> extends StatelessWidget {
  const _Picker(this.c, this.model);
  final ElPicker<T> c;
  final Obs<List<T>> model;

  List<List<ElMenuOption<T>>> columns(List<T> values) {
    if (c.columns != null) return c.columns!;
    final result = <List<ElMenuOption<T>>>[];
    var options = c.options!;
    while (options.isNotEmpty) {
      final index = result.length;
      result.add(options);
      final available = options.where((option) => !option.disabled);
      if (available.isEmpty) break;
      final selected = available.where((option) => index < values.length && option.value == values[index]);
      options = (selected.firstOrNull ?? available.first).children;
    }
    return result;
  }

  List<T> normalize(List<T> values) {
    final result = <T>[];
    for (final options in columns(values)) {
      final available = options.where((option) => !option.disabled);
      if (available.isEmpty) break;
      result.add(
        (available.where((o) => result.length < values.length && o.value == values[result.length]).firstOrNull ??
                available.first)
            .value,
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final values = normalize(model.value);
    final lists = columns(values);
    return ElView(
      style: c.style,
      event: c.event,
      semantics: ElSemantics(container: true, label: c.semanticLabel),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          for (var i = 0; i < lists.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: .min,
                children: [
                  if (i < c.columnLabels.length)
                    ElView(
                      style: ElStyle(
                        height: 28,
                        alignment: .center,
                        fontSize: 12,
                        color: context.elTheme.textSecondary,
                      ),
                      child: c.columnLabels[i],
                    ),
                  _Wheel<T>(
                    options: lists[i],
                    value: i < values.length ? values[i] : null,
                    disabled: c.disabled,
                    label: i < c.columnLabels.length ? c.columnLabels[i] : null,
                    onChanged: (value) {
                      final next = [...values];
                      next[i] = value;
                      model.value = normalize(next);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Wheel<T> extends HookWidget {
  const _Wheel({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.disabled,
    this.label,
  });
  final List<ElMenuOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool disabled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final index = math.max(0, options.indexWhere((o) => o.value == value));
    final controller = useFixedExtentScrollController(initialItem: index);
    final programmatic = useRef(false);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !controller.hasClients || controller.selectedItem == index) return;
        programmatic.value = true;
        controller.jumpToItem(index);
        programmatic.value = false;
      });
      return null;
    }, [index, options.length]);
    final t = context.elTheme;
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: .center,
        children: [
          Positioned(
            left: 3,
            right: 3,
            child: ElView(
              style: ElStyle(height: 44, borderRadius: .circular(10), backgroundColor: t.fill),
            ),
          ),
          Semantics(
            label: label,
            enabled: !disabled,
            child: IgnorePointer(
              ignoring: disabled,
              child: ShaderMask(
                blendMode: .dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: .topCenter,
                  end: .bottomCenter,
                  colors: [Color(0x00ffffff), Color(0xffffffff), Color(0xffffffff), Color(0x00ffffff)],
                  stops: [0, .36, .64, 1],
                ).createShader(rect),
                child: ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 44,
                  diameterRatio: 100,
                  perspective: .0001,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (selected) {
                    if (programmatic.value || disabled || selected >= options.length) return;
                    if (options[selected].disabled) {
                      final direction = selected >= index ? 1 : -1;
                      var target = selected;
                      while (target >= 0 && target < options.length && options[target].disabled) {
                        target += direction;
                      }
                      if (target < 0 || target >= options.length) target = index;
                      if (options[target].value != value) onChanged(options[target].value);
                      controller.animateToItem(
                        target,
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                      );
                      return;
                    }
                    if (options[selected].value != value) onChanged(options[selected].value);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: options.length,
                    builder: (context, i) => Center(
                      child: ElView(
                        style: ElStyle(
                          fontSize: 16,
                          fontWeight: i == index ? .w700 : .w400,
                          color: disabled || options[i].disabled
                              ? t.textDisabled
                              : i == index
                              ? t.primary
                              : t.textSecondary,
                        ),
                        child: buildContent(options[i].label),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 日期各列按有效年月天数及范围联动。
Widget datePickerBuilder(BuildContext context, ElDatePicker c, Obs<DateTime> model) {
  final min = c.min ?? DateTime(1900), max = c.max ?? DateTime(2100, 12, 31);
  DateTime clamp(DateTime value) => value.isBefore(min)
      ? min
      : value.isAfter(max)
      ? max
      : value;
  final date = clamp(model.value);
  List<ElMenuOption<int>> options(int from, int to, String suffix) => [
    for (var value = from; value <= to; value++) ElMenuOption('$value$suffix', value),
  ];
  return ElPicker<int>(
    value: [date.year, date.month, date.day],
    columnLabels: const ['年', '月', '日'],
    disabled: c.disabled,
    style: c.style,
    event: c.event,
    semanticLabel: c.semanticLabel,
    columns: [
      options(min.year, max.year, '年'),
      options(date.year == min.year ? min.month : 1, date.year == max.year ? max.month : 12, '月'),
      options(
        date.year == min.year && date.month == min.month ? min.day : 1,
        date.year == max.year && date.month == max.month ? max.day : DateTime(date.year, date.month + 1, 0).day,
        '日',
      ),
    ],
    onChanged: (values) => model.value = clamp(
      DateTime(values[0], values[1], math.min(values[2], DateTime(values[0], values[1] + 1, 0).day)),
    ),
  );
}

/// 时间范围逐列收敛，避免小时变更后保留越界的分钟或秒。
Widget timePickerBuilder(BuildContext context, ElTimePicker c, Obs<Duration> model) {
  bool allowed(int h, int m, int s) {
    final value = Duration(hours: h, minutes: m, seconds: s);
    return value >= c.min && value <= c.max;
  }

  List<int> seconds(int h, int m) => [
    for (var s = 0; s < 60; s += c.showSeconds ? c.secondStep : 60)
      if (allowed(h, m, s)) s,
  ];
  List<int> minutes(int h) => [
    for (var m = 0; m < 60; m += c.minuteStep)
      if (seconds(h, m).isNotEmpty) m,
  ];
  final hours = [
    for (var h = 0; h < 24; h++)
      if (minutes(h).isNotEmpty) h,
  ];
  if (hours.isEmpty) return const SizedBox.shrink();
  int closest(List<int> values, int value) => values.reduce((a, b) => (a - value).abs() <= (b - value).abs() ? a : b);
  final hour = closest(hours, model.value.inHours);
  final minute = closest(minutes(hour), model.value.inMinutes % 60);
  final second = closest(seconds(hour, minute), model.value.inSeconds % 60);
  List<ElMenuOption<int>> options(List<int> values) => [for (final v in values) ElMenuOption('$v'.padLeft(2, '0'), v)];
  return ElPicker<int>(
    value: [hour, minute, if (c.showSeconds) second],
    columnLabels: ['时', '分', if (c.showSeconds) '秒'],
    disabled: c.disabled,
    style: c.style,
    event: c.event,
    semanticLabel: c.semanticLabel,
    columns: [options(hours), options(minutes(hour)), if (c.showSeconds) options(seconds(hour, minute))],
    onChanged: (values) {
      final m = closest(minutes(values[0]), values[1]);
      final s = closest(seconds(values[0], m), c.showSeconds ? values[2] : 0);
      model.value = Duration(hours: values[0], minutes: m, seconds: s);
    },
  );
}
