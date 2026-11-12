import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../dart.dart' show $absent;
import '../../../ui.dart';

part 'forms.dart';
part 'data.dart';
part 'layout.dart';
part 'pickers.dart';

/// 为尚无品牌实现的已有接口提供基础 Material 替代，不覆盖品牌已有实现。
ElComponents materialComponents({bool mobile = false}) {
  Widget control(Widget child) => mobile ? ExcludeFocus(child: child) : child;
  return ElComponents(
    checkbox: (context, c, state) => _checkbox(c, state),
    radio: <T>(context, c, state) => _radio(c, state),
    input: (context, c) => _MaterialInput(c),
    select: <T>(context, c) => _MaterialSelect<T>(c),
    autocomplete: <T>(context, c) => _MaterialAutocomplete<T>(c),
    card: (context, c) => control(_card(c)),
    loadingIndicator: (context, c) => _loading(c),
    listTile: <T>(context, c) => control(_listTile<T>(c)),
    listTileGroup: <D>(context, c) => control(_listGroup<D>(c)),
    progress: (context, c) => _progress(c),
    slider: <D>(context, c) => control(_slider<D>(c)),
    avatar: (context, c) => _avatar(c),
    calendar: <D>(context, c) => control(_calendar<D>(c)),
    collapse: <D>(context, c) => control(_collapse<D>(c)),
    collapseItem: <T>(context, c) => control(
      _frame(
        c.style,
        null,
        ExpansionTile(title: _content(c.title), enabled: !c.disabled, children: [_content(c.child)]),
      ),
    ),
    segmented: <T>(context, c) => control(_segmented<T>(c)),
    steps: (context, c) => control(_steps(c)),
    step: (context, c) => _frame(
      c.style,
      null,
      ListTile(
        leading: c.icon == null ? null : _content(c.icon),
        title: _content(c.title),
        subtitle: c.description == null ? null : _content(c.description),
        enabled: !c.disabled,
      ),
    ),
    tabs: <T>(context, c) => control(_MaterialTabs<T>(c)),
    tabBar: (context, c) => control(_MaterialTabBar(c)),
    alert: (context, c) => control(_alert(c)),
    picker: <T>(context, c, model) => _picker(c, model),
    datePicker: (context, c, model) => _frame(
      c.style,
      c.semanticLabel,
      CalendarDatePicker(
        initialDate: model.value,
        firstDate: c.min ?? DateTime(1900),
        lastDate: c.max ?? DateTime(2100, 12, 31),
        onDateChanged: (value) {
          if (!c.disabled) model.value = value;
        },
      ),
    ),
    timePicker: (context, c, model) => _timePicker(c, model),
    upload: (context, c) => _upload(c),
    appBar: (context, c) => ElView(
      style: c.style,
      event: c.event,
      child: AppBar(
        title: _content(c.title),
        centerTitle: c.centerTitle,
        leading: c.leading ?? (c.back ? BackButton(onPressed: c.onBack) : null),
        automaticallyImplyLeading: c.back,
        actions: c.actions,
      ),
    ),
    tooltip: (context, c) => TooltipVisibility(
      visible: !c.disabled,
      child: ElView(
        event: c.event,
        child: Tooltip(
          message: c.content is String ? c.content as String : null,
          richMessage: c.content is String ? null : WidgetSpan(child: _content(c.content)),
          waitDuration: c.waitDuration,
          showDuration: c.showDuration,
          enableTapToDismiss: true,
          ignorePointer: false,
          child: c.child,
        ),
      ),
    ),
    popup: (context, c) => _popup(c),
    dialog: (context, c) => _popup(c),
    drawer: (context, c) => _popup(c),
    toast: (context, c) => _frame(
      c.style,
      c.semanticLabel,
      Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: .min,
            children: [
              if (c.icon != null) _content(c.icon),
              Flexible(child: _content(c.child)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _content(Object? value) => switch (value) {
  Widget() => value,
  IconData() => Icon(value),
  InlineSpan() => Text.rich(value),
  Iterable() => ElView(child: value),
  _ => Text(value?.toString() ?? ''),
};

Widget _frame(ElStyle? style, String? label, Widget child) => ElView(
  style: style,
  semantics: label == null ? null : ElSemantics(container: true, label: label),
  child: child,
);
