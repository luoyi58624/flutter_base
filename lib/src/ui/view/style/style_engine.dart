part of 'index.dart';

/// 包内字段协议：读取、插值与失效类型集中维护，新增字段由穷尽检查兜底。
extension StyleField on ElTransitionField {
  (_Lerp, int, bool) get _spec => switch (this) {
    ElTransitionField.width ||
    ElTransitionField.height => const (_lengthLerp, StyleEngine.layout, true),
    ElTransitionField.backgroundColor => const (
      _colorLerp,
      StyleEngine.paint,
      false,
    ),
    ElTransitionField.padding ||
    ElTransitionField.margin => const (_insetsLerp, StyleEngine.layout, false),
  };
  int get damage => _spec.$2;
  bool get isLength => _spec.$3;
  Object? read(ElStyle style, TextDirection direction) => switch (this) {
    ElTransitionField.width => _parseLength(style.width),
    ElTransitionField.height => _parseLength(style.height),
    ElTransitionField.backgroundColor => style.backgroundColor,
    ElTransitionField.padding => _resolveInsets(style.padding, direction),
    ElTransitionField.margin => _resolveInsets(style.margin, direction),
  };
}

/// 包内动画引擎；只处理属性和时间，通过两个回调与渲染层协作。
class StyleEngine {
  StyleEngine(
    this._values, {
    required this.captureFrom,
    required this.invalidate,
  }) : targets = List.of(_values);
  static const layout = 1, paint = 2, measure = 4;
  final List<Object?> _values;
  final StyleLength Function(ElTransitionField, StyleLength?) captureFrom;
  final void Function(int damage) invalidate;
  List<Object?> targets;
  final active = <StyleTrack>[];
  final _slots = List<StyleTrack?>.filled(
    ElTransitionField.values.length,
    null,
  );
  Ticker? _ticker;
  int _damage = 0;

  void _write(ElTransitionField field, Object? value) {
    if (_values[field.index] == value) return;
    _values[field.index] = value;
    _damage |= field.damage;
  }

  void _flush() {
    if (_damage != 0) invalidate(_damage);
    _damage = 0;
  }

  void update(
    List<Object?> next,
    List<ElTransition> transitions,
    bool animate,
  ) {
    for (final field in ElTransitionField.values) {
      final to = next[field.index];
      ElTransition? transition;
      for (var i = transitions.length - 1; i >= 0; i--) {
        if (transitions[i].field == null || transitions[i].field == field) {
          transition = transitions[i];
          break;
        }
      }
      assert(
        transition == null ||
            (!transition.duration.isNegative && !transition.delay.isNegative),
      );
      final immediate =
          !animate ||
          transition == null ||
          transition.duration + transition.delay == Duration.zero;
      if (!immediate && targets[field.index] == to) continue;
      final old = _slots[field.index];
      if (old != null) active.remove(old);
      _slots[field.index] = null;
      var from = _values[field.index];
      if (immediate || from == to) {
        _write(field, to);
      } else {
        if (field.isLength) from = captureFrom(field, from as StyleLength?);
        final track = StyleTrack(field, from, to, transition);
        _slots[field.index] = track;
        active.add(track);
        _write(field, from);
        if (field.isLength) _damage |= measure;
      }
    }
    targets = next;
    if (active.isEmpty) {
      _ticker?.stop();
    } else {
      _ticker ??= Ticker(_tick);
      if (!_ticker!.isActive) _ticker!.start();
    }
    _flush();
  }

  void _tick(Duration elapsed) {
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    for (var i = active.length - 1; i >= 0; i--) {
      final track = active[i];
      final after = now - track.start - track.delay;
      final done = after >= track.duration;
      final t = after <= Duration.zero
          ? 0.0
          : track.curve.transform(
              (after.inMicroseconds / track.duration.inMicroseconds).clamp(
                0.0,
                1.0,
              ),
            );
      final pending = track.field.isLength && track.end == null;
      _write(
        track.field,
        done
            ? track.target
            : pending || t == 0
            ? track.from
            : track.field._spec.$1(track.from, track.end, t),
      );
      if (done) {
        _slots[track.field.index] = null;
        active[i] = active.last;
        active.removeLast();
      }
    }
    _flush();
    if (active.isEmpty) _ticker!.stop();
  }

  void dispose() => _ticker?.dispose();
}

/// 包内单属性轨道；渲染层只提交几何快照，不操作时间插值。
class StyleTrack {
  StyleTrack(this.field, this.from, this.target, ElTransition transition)
    : end = target,
      duration = transition.duration,
      delay = transition.delay,
      curve = transition.curve,
      start = SchedulerBinding.instance.currentFrameTimeStamp;
  final ElTransitionField field;
  final Object? target;
  Object? from, end;
  Duration start, duration, delay;
  final Curve curve;

  // 自动尺寸只在真实布局中测量；外部布局变化时保留原截止时间。
  void snapshot(StyleLength value, Object? current, {bool force = false}) {
    if (end == value && !force) return;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (end != null) {
      final waiting = start + delay - now;
      duration = Duration(
        microseconds: math.max(
          0,
          (start + delay + duration - now).inMicroseconds -
              math.max(0, waiting.inMicroseconds),
        ),
      );
      delay = Duration(microseconds: math.max(0, waiting.inMicroseconds));
      start = now;
      from = current;
    }
    end = value;
  }
}
