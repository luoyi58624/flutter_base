/// 参照 my-ui/packages/core/my-ui.js Slider：连续视觉位置与离散业务值分离，触屏抬起提交。
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import 'value.dart';

/// 移动端滑块直接使用公共模型，拖动状态只保存尚未提交的预览。
Widget sliderBuilder<D>(BuildContext context, ElSlider<D> component) => _Slider<D>(component);

class _Slider<D> extends StatefulWidget {
  const _Slider(this.component);
  final ElSlider<D> component;
  @override
  State<_Slider<D>> createState() => _SliderState<D>();
}

class _SliderState<D> extends State<_Slider<D>> with WidgetsBindingObserver {
  final _control = GlobalKey();
  final _secondaryFocus = FocusNode();
  final _ownFocus = FocusNode();
  _Drag? _drag;
  int? _focused, _dismissed, _ignoredPointer;
  bool _watchingPointers = false;
  late SliderScale _scale;
  ElSlider<D> get c => widget.component;
  SliderScale get scale => _scale;
  List<double> get values {
    final value = c.currentValue;
    final source = value is List<double>
        ? [value.firstOrNull ?? c.min, value.elementAtOrNull(1) ?? c.min]
        : [value as double];
    return source.map(scale.normalize).toList()..sort();
  }

  FocusNode _focus(int index) => index == 0 ? c.focusNode ?? _ownFocus : _secondaryFocus;
  bool get disabled => c.disabled || c.event?.disabled == true || scale.disabled;

  @override
  void initState() {
    super.initState();
    _scale = SliderScale(c.min, c.max, c.step, c.marks);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _Slider<D> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.component;
    final changed = old.min != c.min || old.max != c.max || old.step != c.step || !_sameMarks(old.marks, c.marks);
    // 与 Web 一样只在配置变化时生成刻度，连续拖动不重复分配刻度表。
    if (changed) _scale = SliderScale(c.min, c.max, c.step, c.marks);
    if (disabled || changed || old.isRange != c.isRange) {
      _clear();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }

  void _observePointer(PointerEvent event) {
    if (_drag != null &&
        event is PointerDownEvent &&
        event.kind == PointerDeviceKind.touch &&
        event.pointer != _drag!.pointer) {
      _ignoredPointer = event.pointer;
      _cancel();
    }
  }

  void _clear() {
    _drag = null;
    if (_watchingPointers) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_observePointer);
      _watchingPointers = false;
    }
  }

  void _cancel() {
    if (!mounted || _drag == null) return;
    setState(_clear);
  }

  RenderBox get _box => _control.currentContext!.findRenderObject() as RenderBox;
  double get _extent => math.max(1, _box.size.width - 20);
  double _point(Offset position) =>
      scale.min + ((_box.globalToLocal(position).dx - 10) / _extent) * (scale.max - scale.min);
  int _nearest(double raw, List<double> values) => values.length == 1
      ? 0
      : (raw - values[0]).abs() < (raw - values[1]).abs()
      ? 0
      : (raw - values[0]).abs() > (raw - values[1]).abs()
      ? 1
      : raw < values[0]
      ? 0
      : 1;

  void _down(PointerDownEvent event) {
    if (disabled || _drag != null || event.pointer == _ignoredPointer || event.buttons != kPrimaryButton) return;
    final source = values;
    final index = _nearest(_point(event.position), source);
    final center = 10 + scale.ratio(source[index]) * _extent;
    final delta = _box.globalToLocal(event.position).dx - center;
    _drag = _Drag(
      event.pointer,
      event.kind == PointerDeviceKind.touch,
      index,
      source,
      delta.abs() <= 10 ? delta : 0,
      event.position,
    );
    GestureBinding.instance.pointerRouter.addGlobalRoute(_observePointer);
    _watchingPointers = true;
    _dismissed = null;
    _focused = null;
    if (!_drag!.deferred) {
      _focus(index).requestFocus();
      _move(event.position);
    }
    setState(() {});
  }

  void _commit(List<double> next) {
    if (listEquals(next, values)) return;
    c.currentValue = (c.isRange ? List<double>.of(next) : next.first) as D;
  }

  void _move(Offset position) {
    final drag = _drag;
    if (drag == null || disabled) return;
    final current = List<double>.of(drag.preview);
    final raw = scale.clamp(_point(position) - drag.offset / _extent * (scale.max - scale.min));
    final previousIndex = drag.index;
    current[previousIndex] = scale.normalize(raw);
    if (current.length > 1 && (previousIndex == 0 ? raw > drag.preview[1] : raw < drag.preview[0])) {
      drag.index = 1 - previousIndex;
      _focus(drag.index).requestFocus();
    }
    current.sort();
    drag.raw = raw;
    drag.preview = current;
    if (!drag.deferred) {
      drag.source = List.of(current);
      _commit(current);
    }
    setState(() {});
  }

  void _up(PointerUpEvent event) {
    final drag = _drag;
    if (drag == null || drag.pointer != event.pointer) return;
    final local = _box.globalToLocal(event.position);
    if (drag.deferred &&
        !drag.moved &&
        (!(Offset.zero & _box.size).contains(local) || (event.position - drag.start).distance > 8)) {
      _cancel();
      return;
    }
    _move(event.position);
    final next = List<double>.of(drag.preview);
    _clear();
    if (drag.deferred) {
      _focus(drag.index).requestFocus();
      _commit(next);
    }
    if (mounted) setState(() {});
  }

  void _adjust(int index, double next) {
    if (disabled) return;
    final current = values;
    current[index] = scale.normalize(next);
    final target = current.length > 1 && (index == 0 ? current[0] > current[1] : current[1] < current[0])
        ? 1 - index
        : index;
    current.sort();
    _commit(current);
    _focus(target).requestFocus();
    setState(() {
      _focused = target;
      _dismissed = null;
    });
  }

  KeyEventResult _key(int index, KeyEvent event) {
    if (disabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _dismissed = index);
      return KeyEventResult.handled;
    }
    final value = values[index];
    double? next;
    if ([LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowUp].contains(key)) next = scale.adjacent(value, true);
    if ([LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowDown].contains(key)) next = scale.adjacent(value, false);
    if (key == LogicalKeyboardKey.home) next = scale.normalize(scale.min);
    if (key == LogicalKeyboardKey.end) next = scale.normalize(scale.max);
    if (key == LogicalKeyboardKey.pageUp) {
      next = c.step == null ? scale.adjacent(value, true) : value + (scale.max - scale.min) / 10;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      next = c.step == null ? scale.adjacent(value, false) : value - (scale.max - scale.min) / 10;
    }
    if (next == null) return KeyEventResult.ignored;
    _adjust(index, next);
    return KeyEventResult.handled;
  }

  String _format(double value, int index) =>
      c.valueLabelFormat?.call(value, index) ?? '${value.toString().replaceFirst(RegExp(r'\.0(?=$|e)'), '')}${c.unit}';

  @override
  Widget build(BuildContext context) {
    final model = values;
    if (_drag != null && (!listEquals(model, _drag!.source) || disabled || !TickerMode.valuesOf(context).enabled)) {
      _clear();
    }
    final display = _drag?.preview ?? model;
    final visual = List<double>.of(display);
    if (_drag != null) visual[_drag!.index] = _drag!.raw;
    final theme = context.elTheme;
    final duration = reducedMotion(context) || _drag != null ? Duration.zero : const Duration(milliseconds: 120);
    return MediaQuery(
      data: (MediaQuery.maybeOf(context) ?? const MediaQueryData()).copyWith(
        gestureSettings: const DeviceGestureSettings(touchSlop: 8),
      ),
      child: ElView(
        style: c.style,
        event: c.event,
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const .symmetric(vertical: 6),
              child: Row(
                children: [
                  if (c.label != null)
                    Expanded(
                      child: Text(c.label!, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                    ),
                  Text(
                    [for (var i = 0; i < model.length; i++) _format(model[i], i)].join(' – '),
                    style: TextStyle(color: theme.primary, fontSize: 13),
                  ),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final extent = math.max(1.0, constraints.maxWidth - 20);
                final low = c.isRange ? scale.ratio(visual.first) : 0.0;
                final high = scale.ratio(visual.last);
                final buffer = c.buffer?.isFinite == true ? scale.ratio(c.buffer!).clamp(high, 1.0) : high;
                return Listener(
                  onPointerDown: _down,
                  onPointerMove: (e) {
                    if (_drag?.pointer != e.pointer) return;
                    if (_drag?.deferred == false) {
                      _move(e.position);
                    } else if (_drag?.moved == false) {
                      final delta = e.position - _drag!.start;
                      if (delta.dy.abs() > 8 && delta.dy.abs() > delta.dx.abs()) _cancel();
                    }
                  },
                  onPointerUp: _up,
                  onPointerCancel: (_) => _cancel(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onHorizontalDragStart: (_) {
                      if (_drag != null) {
                        _drag!.moved = true;
                        _focus(_drag!.index).requestFocus();
                      }
                    },
                    onHorizontalDragUpdate: (e) {
                      if (_drag?.deferred == true) _move(e.globalPosition);
                    },
                    onHorizontalDragEnd: (_) {},
                    onHorizontalDragCancel: () {
                      if (_drag?.moved == true) _cancel();
                    },
                    child: SizedBox(
                      key: _control,
                      height: 44,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 10,
                            right: 10,
                            top: 19,
                            height: 6,
                            child: ElView(
                              style: ElStyle(backgroundColor: theme.fill, borderRadius: .circular(3)),
                            ),
                          ),
                          if (c.buffer != null)
                            Positioned(
                              left: 10 + low * extent,
                              width: math.max(0, (buffer - low) * extent),
                              top: 19,
                              height: 6,
                              child: ElView(
                                style: ElStyle(
                                  backgroundColor: theme.primary.withValues(alpha: .25),
                                  borderRadius: .circular(3),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 10 + low * extent,
                            width: math.max(0, (high - low) * extent),
                            top: 19,
                            height: 6,
                            child: ElView(
                              style: ElStyle(
                                backgroundColor: disabled ? theme.gray : theme.primary,
                                borderRadius: .circular(3),
                              ),
                            ),
                          ),
                          for (final mark in scale.points)
                            Positioned(
                              left: 9 + scale.ratio(mark.value) * extent,
                              top: 21,
                              width: 2,
                              height: 2,
                              child: ElView(
                                style: ElStyle(
                                  backgroundColor:
                                      mark.value >= (c.isRange ? visual.first : scale.min) && mark.value <= visual.last
                                      ? theme.cardColor
                                      : theme.primary,
                                  borderRadius: .circular(1),
                                ),
                              ),
                            ),
                          for (var i = 0; i < display.length; i++)
                            AnimatedPositioned(
                              key: ValueKey('slider-thumb-$i'),
                              duration: duration,
                              curve: Curves.easeOut,
                              left: scale.ratio(visual[i]) * extent,
                              top: 12,
                              width: 20,
                              height: 20,
                              child: Semantics(
                                slider: true,
                                enabled: !disabled,
                                label:
                                    '${c.label ?? '滑块'}${c.isRange
                                        ? i == 0
                                              ? ' · 起始值'
                                              : ' · 结束值'
                                        : ''}',
                                value: c.semanticValueFormat?.call(display[i], i) ?? _format(display[i], i),
                                increasedValue:
                                    c.semanticValueFormat?.call(scale.adjacent(model[i], true), i) ??
                                    _format(scale.adjacent(model[i], true), i),
                                decreasedValue:
                                    c.semanticValueFormat?.call(scale.adjacent(model[i], false), i) ??
                                    _format(scale.adjacent(model[i], false), i),
                                onIncrease: disabled ? null : () => _adjust(i, scale.adjacent(model[i], true)),
                                onDecrease: disabled ? null : () => _adjust(i, scale.adjacent(model[i], false)),
                                child: Focus(
                                  focusNode: _focus(i),
                                  canRequestFocus: !disabled,
                                  onKeyEvent: (_, e) => _key(i, e),
                                  onFocusChange: (focused) {
                                    if (!focused && _drag?.index == i && _drag?.moved == true) _cancel();
                                    if (mounted) {
                                      setState(() {
                                        if (focused &&
                                            _drag == null &&
                                            FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
                                          _focused = i;
                                          _dismissed = null;
                                        } else if (_focused == i) {
                                          _focused = null;
                                        }
                                      });
                                    }
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: -15,
                                        top: -15,
                                        width: 50,
                                        height: 50,
                                        child: ElView(
                                          style: ElStyle(
                                            backgroundColor: theme.primary.withValues(alpha: .14),
                                            borderRadius: .circular(25),
                                            opacity: _drag?.index == i && !disabled ? 1 : 0,
                                            transform: ElTransform.scale(_drag?.index == i && !disabled ? 1 : .4),
                                            transition: reducedMotion(context)
                                                ? const []
                                                : const [ElTransition.all(Duration(milliseconds: 150), Curves.ease)],
                                          ),
                                        ),
                                      ),
                                      ElView(
                                        style: ElStyle(
                                          width: 20,
                                          height: 20,
                                          backgroundColor: disabled ? theme.gray : theme.primary,
                                          borderRadius: .circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xff000000).withValues(alpha: .22),
                                              offset: const Offset(0, 2),
                                              blurRadius: 5,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!disabled &&
                                          c.valueLabelDisplay != ElSliderValueLabelDisplay.off &&
                                          _dismissed != i &&
                                          (c.valueLabelDisplay == ElSliderValueLabelDisplay.on ||
                                              (_drag?.index ?? _focused) == i))
                                        Positioned(
                                          top: -36,
                                          left: 10,
                                          child: FractionalTranslation(
                                            translation: const Offset(-.5, 0),
                                            child: ElView(
                                              style: ElStyle(
                                                backgroundColor: theme.textColor.withValues(alpha: .9),
                                                color: theme.cardColor,
                                                padding: const .symmetric(horizontal: 8, vertical: 4),
                                                borderRadius: .circular(4),
                                              ),
                                              child: _format(display[i], i),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (scale.points.any((p) => p.label != null))
              SizedBox(
                height: 24,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      for (final p in scale.points.where((p) => p.label != null))
                        Positioned(
                          left: 10 + scale.ratio(p.value) * math.max(1, constraints.maxWidth - 20),
                          child: FractionalTranslation(
                            translation: Offset(
                              p.value == scale.min
                                  ? 0
                                  : p.value == scale.max
                                  ? -1
                                  : -.5,
                              0,
                            ),
                            child: buildContent(p.label),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else if (c.startLabel != null || c.endLabel != null)
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(c.startLabel ?? '', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                  Text(c.endLabel ?? '', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clear();
    WidgetsBinding.instance.removeObserver(this);
    _secondaryFocus.dispose();
    _ownFocus.dispose();
    super.dispose();
  }
}

bool _sameMarks(Object a, Object b) {
  if (identical(a, b)) return true;
  if (a is! List<ElSliderMark> || b is! List<ElSliderMark> || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].value != b[i].value || a[i].label != b[i].label) return false;
  }
  return true;
}

class _Drag {
  _Drag(this.pointer, this.deferred, this.index, List<double> source, this.offset, this.start)
    : source = List.of(source),
      preview = List.of(source),
      raw = source[index];
  final int pointer;
  final bool deferred;
  int index;
  List<double> source, preview;
  double raw;
  final double offset;
  final Offset start;
  bool moved = false;
}
