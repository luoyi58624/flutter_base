part of 'index.dart';

Widget _card(ElCard c) => ElButtonView(
  style: c.style,
  event: c.event,
  onPressed: c.onTap,
  disabled: c.loading,
  child: Card(
    // 显式内边距已由 ElButtonView 承接，不再叠加官方 Card 的默认留白。
    margin: c.style?.padding == null ? null : EdgeInsets.zero,
    child: Padding(
      padding: c.style?.padding == null ? const EdgeInsets.all(16) : EdgeInsets.zero,
      child: Stack(
        alignment: .center,
        children: [
          IgnorePointer(
            ignoring: c.loading,
            child: Opacity(opacity: c.loading ? .4 : 1, child: c.child ?? const SizedBox.shrink()),
          ),
          if (c.loading) const CircularProgressIndicator(),
        ],
      ),
    ),
  ),
);

Widget _loading(ElLoadingIndicator c) => _frame(
  c.style,
  c.semanticLabel,
  Row(
    mainAxisSize: .min,
    spacing: 12,
    children: [
      SizedBox.square(dimension: c.size ?? 24, child: const CircularProgressIndicator()),
      if (c.child != null) _content(c.child),
    ],
  ),
);

Widget _avatar(ElAvatar c) {
  final fallback = _content(c.child ?? (c.alt.isEmpty ? Icons.person : c.alt));
  final image = c.src == null
      ? fallback
      : ElImage(
          c.src!,
          alt: c.alt,
          width: c.size,
          height: c.size,
          fit: .cover,
          onLoad: c.onLoad,
          onError: c.onError,
          placeholder: fallback,
          error: fallback,
        );
  return _frame(
    c.style,
    c.semanticLabel ?? c.alt,
    SizedBox.square(
      dimension: c.size,
      child: c.shape == .circle
          ? CircleAvatar(
              radius: c.size / 2,
              child: ClipOval(child: image),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: const Color(0xffe0e5ed),
                child: Center(child: image),
              ),
            ),
    ),
  );
}

Widget _progress(ElProgress c) {
  final max = c.max.isFinite && c.max > 0 ? c.max : 100.0;
  final value = c.value != null && c.value!.isFinite ? c.value!.clamp(0, max).toDouble() : null;
  final state = ElProgressValue(value: value, max: max, percentage: value == null ? 0 : value / max * 100);
  final color = switch (c.status) {
    .success => Colors.green,
    .warning => Colors.orange,
    .error => Colors.red,
    _ => null,
  };
  final line = LinearProgressIndicator(
    value: value == null ? null : value / max,
    backgroundColor: c.buffer == null ? null : Colors.transparent,
    color: color,
    semanticsLabel: c.semanticLabel,
  );
  final meter = c.shape == .circle
      ? SizedBox.square(
          dimension: 48,
          child: CircularProgressIndicator(
            value: value == null ? null : value / max,
            color: color,
            semanticsLabel: c.semanticLabel,
          ),
        )
      : c.buffer == null || !c.buffer!.isFinite
      ? line
      : Stack(
          children: [
            LinearProgressIndicator(value: c.buffer!.clamp(value ?? 0, max) / max, color: Colors.blueGrey.shade200),
            line,
          ],
        );
  return _frame(
    c.style,
    null,
    c.shape == .circle
        ? Column(
            mainAxisSize: .min,
            spacing: 8,
            children: [
              meter,
              if (c.showText)
                Builder(
                  builder: (context) =>
                      c.textBuilder?.call(context, state) ??
                      Text(value == null ? '加载中' : '${state.percentage.round()}%'),
                ),
            ],
          )
        : Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            spacing: 8,
            children: [
              meter,
              if (c.showText)
                Builder(
                  builder: (context) =>
                      c.textBuilder?.call(context, state) ??
                      Text(value == null ? '加载中' : '${state.percentage.round()}%'),
                ),
            ],
          ),
  );
}

Widget _slider<D>(ElSlider<D> c) {
  final divisions = c.step == null || c.max == c.min ? null : math.max(1, ((c.max - c.min) / c.step!).round());
  final native = c.isRange
      ? RangeSlider(
          values: RangeValues(
            (c.currentValue as List<double>).first.clamp(c.min, c.max),
            (c.currentValue as List<double>).last.clamp(c.min, c.max),
          ),
          min: c.min,
          max: c.max,
          divisions: divisions,
          onChanged: c.disabled || c.event?.disabled == true
              ? null
              : (values) => c.currentValue = <double>[values.start, values.end] as D,
        )
      : Slider(
          value: (c.currentValue as double).clamp(c.min, c.max),
          min: c.min,
          max: c.max,
          divisions: divisions,
          focusNode: c.focusNode,
          label: c.valueLabelFormat?.call(c.currentValue as double, 0),
          semanticFormatterCallback: c.semanticValueFormat == null ? null : (value) => c.semanticValueFormat!(value, 0),
          onChanged: c.disabled || c.event?.disabled == true ? null : (value) => c.currentValue = value as D,
        );
  return ElView(
    style: c.style,
    event: c.event,
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [if (c.label != null) Text(c.label!), native],
    ),
  );
}

Widget _segmented<T>(ElSegmented<T> c) => _frame(
  c.style,
  c.semanticLabel,
  SegmentedButton<int>(
    segments: [
      for (var i = 0; i < c.options.length; i++)
        ButtonSegment(
          value: i,
          label: _content(c.options[i].label ?? c.options[i].value),
          enabled: !c.options[i].disabled,
        ),
    ],
    selected: {
      for (var i = 0; i < c.options.length; i++)
        if (c.options[i].value == c.currentValue) i,
    },
    emptySelectionAllowed: true,
    showSelectedIcon: false,
    onSelectionChanged: c.disabled
        ? null
        : (indices) {
            if (indices.isNotEmpty) c.currentValue = c.options[indices.first].value;
          },
  ),
);

Widget _calendar<D>(ElCalendar<D> c) => Builder(
  builder: (context) {
    final first = DateUtils.dateOnly(c.min ?? DateTime(1900));
    final last = DateUtils.dateOnly(c.max ?? DateTime(2100, 12, 31));
    bool enabled(DateTime day) => !(c.disabledDate?.call(day) ?? false);
    if (c.isRange) {
      final values = c.currentValue as List<DateTime>;
      return _frame(
        c.style,
        c.semanticLabel,
        OutlinedButton(
          onPressed: c.disabled
              ? null
              : () async {
                  final result = await showDateRangePicker(
                    context: context,
                    firstDate: first,
                    lastDate: last,
                    initialDateRange: values.length == 2 ? DateTimeRange(start: values.first, end: values.last) : null,
                    selectableDayPredicate: (day, start, end) => enabled(day),
                  );
                  if (result == null || !context.mounted) return;
                  c.currentValue = <DateTime>[result.start, result.end] as D;
                  c.onSelect?.call(c.currentValue);
                },
          child: Text(
            values.length == 2
                ? '${DateUtils.dateOnly(values.first).toString().split(' ').first} 至 ${DateUtils.dateOnly(values.last).toString().split(' ').first}'
                : '选择日期范围',
          ),
        ),
      );
    }
    final raw = c.currentValue as DateTime? ?? c.month ?? DateTime.now();
    final date = DateUtils.dateOnly(
      raw.isBefore(first)
          ? first
          : raw.isAfter(last)
          ? last
          : raw,
    );
    return _frame(
      c.style,
      c.semanticLabel,
      IgnorePointer(
        ignoring: c.disabled,
        child: CalendarDatePicker(
          key: ValueKey((date, first, last)),
          initialDate: enabled(date) ? date : null,
          firstDate: first,
          lastDate: last,
          selectableDayPredicate: enabled,
          onDisplayedMonthChanged: c.onMonthChanged,
          onDateChanged: (value) {
            c.currentValue = value as D;
            c.onSelect?.call(c.currentValue);
          },
        ),
      ),
    );
  },
);

Widget _listTile<T>(ElListTile<T> c) {
  final blocked = c.disabled || c.loading;
  final trailing = identical(c.trailing, $absent)
      ? const Icon(Icons.chevron_right)
      : c.trailing == null
      ? null
      : _content(c.trailing);
  final row = ListTile(
    enabled: !c.disabled,
    leading: c.leading == null ? null : _content(c.leading),
    title: _content(c.title),
    subtitle: c.subtitle == null ? null : _content(c.subtitle),
    trailing: c.type == .switcher
        ? c.loading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator())
              : IgnorePointer(
                  child: Switch(value: c.currentValue as bool, onChanged: c.disabled ? null : (_) {}),
                )
        : c.trailingText == null
        ? trailing
        : _content(c.trailingText),
  );
  if (c.type == .popup) {
    List<PopupMenuEntry<T>> options(List<ElLabelModel<T>> items, {bool disabled = false}) => [
      for (final option in items)
        if (option is ElMenuOption<T> && option.children.isNotEmpty)
          ...options(option.children, disabled: disabled || option.disabled)
        else
          PopupMenuItem<T>(
            value: option.value as T,
            enabled: !disabled && (option is! ElMenuOption<T> || !option.disabled),
            child: Text(option.label ?? '${option.value}'),
          ),
    ];
    return _frame(
      c.style,
      c.semanticLabel,
      PopupMenuButton<T>(
        enabled: !blocked,
        tooltip: c.popupLabel ?? '选择',
        onSelected: (value) => c.currentValue = value,
        itemBuilder: (_) => options(c.options),
        child: row,
      ),
    );
  }
  return ElButtonView(
    style: c.style,
    event: c.event,
    focusNode: c.focusNode,
    semanticLabel: c.semanticLabel,
    disabled: blocked,
    onPressed: c.type == .switcher ? () => c.currentValue = (!(c.currentValue as bool)) as T : c.onTap,
    child: row,
  );
}

Widget _listGroup<D>(ElListGroup<D> c) => Column(
  mainAxisSize: .min,
  crossAxisAlignment: .stretch,
  children: [
    if (c.title != null) Padding(padding: const EdgeInsets.all(12), child: _content(c.title)),
    if (c.mode == null)
      ...c.children
    else
      for (final item in c.children)
        Builder(
          builder: (context) {
            final selected = c.mode == .single
                ? c.currentValue == item.value
                : (c.currentValue as List).contains(item.value);
            final mark = IgnorePointer(
              child: c.mode == .single
                  ? RadioGroup<bool>(
                      groupValue: selected,
                      onChanged: (_) {},
                      child: Radio<bool>(value: true, enabled: !item.disabled),
                    )
                  : Checkbox(value: selected, onChanged: item.disabled ? null : (_) {}),
            );
            return ElButtonView(
              style: item.style,
              event: item.event,
              disabled: item.disabled,
              selected: selected,
              onPressed: () {
                if (c.mode == .single) {
                  c.currentValue = item.value as D;
                } else {
                  final dynamic next = (c.currentValue as List).toList();
                  selected ? next.remove(item.value) : next.add(item.value);
                  c.currentValue = next as D;
                }
                item.onTap?.call();
              },
              child: ListTile(
                title: _content(item.title),
                subtitle: item.subtitle == null ? null : _content(item.subtitle),
                leading: c.leading ? mark : null,
                trailing: c.leading ? null : mark,
                selected: selected,
                enabled: !item.disabled,
              ),
            );
          },
        ),
  ],
);
