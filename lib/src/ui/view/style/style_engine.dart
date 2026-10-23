part of 'index.dart';

/// 每个宿主唯一的样式运行状态，统一处理解析、求值、动画与精确失效。
class StyleEngine {
  /// 创建并解析初始声明；首次布局前不建立动画。
  StyleEngine(
    ElStyle style,
    TextDirection direction, {
    required this.invalidate,
  }) : _style = style,
       _direction = direction {
    for (final field in StyleField.values) {
      final raw = field.declaration(style);
      if (raw != null) _values[field.index] = _parse(field, raw);
    }
    _targets.setAll(0, _values);
  }

  /// 消费结果需要重新布局。
  static const layout = 1;

  /// 消费结果只需要重新绘制。
  static const paint = 2;

  /// 宿主执行已经裁决的框架失效，不参与字段解析。
  final void Function(int damage) invalidate;

  ElStyle _style;
  TextDirection _direction;
  final _values = List<Object?>.filled(StyleField.values.length, null);
  final _targets = List<Object?>.filled(StyleField.values.length, null);
  List<_StyleTrack>? _tracks;
  Ticker? _ticker;
  int _damage = 0, _externalVersion = 0, _parseCount = 0;
  bool _hasLayout = false, _externalLayout = false;
  Size _lastBoxSize = Size.zero;
  BoxConstraints? _lastConstraints;
  bool _widthResolved = true, _heightResolved = true;
  LayoutStyle _layoutValues = LayoutStyle.empty;
  Object? _measurementKey;
  Size? _measurementSize;

  /// 已完成颜色解析和本帧插值的背景色。
  Color? get backgroundColor =>
      _values[StyleField.backgroundColor.index] as Color?;

  /// 测试观察实际进入字段解析的次数，空属性不计入。
  @visibleForTesting
  int get debugParseCount => _parseCount;

  /// 测试观察是否曾为实际过渡创建时钟。
  @visibleForTesting
  bool get debugTickerCreated => _ticker != null;

  Object? _parse(StyleField field, Object value) {
    assert(() {
      _parseCount++;
      return true;
    }());
    return field.parse(value, _direction);
  }

  void _write(StyleField field, Object? value) {
    if (_values[field.index] == value) return;
    _values[field.index] = value;
    _damage |= field.damage;
  }

  void _flush() {
    final damage = _damage;
    _damage = 0;
    if (damage != 0) invalidate(damage);
  }

  _StyleTrack? _track(StyleField field) {
    final tracks = _tracks;
    if (tracks != null) {
      for (final track in tracks) {
        if (track.field == field) return track;
      }
    }
    return null;
  }

  ElTransition? _transition(StyleField field, List<ElTransition>? transitions) {
    if (transitions != null) {
      for (var i = transitions.length - 1; i >= 0; i--) {
        final item = transitions[i];
        if (item.field == null || item.field == field.transitionField) {
          return item;
        }
      }
    }
    return null;
  }

  /// 只解析声明或相关方向发生变化的字段，不改写无关属性的轨道。
  void update(ElStyle style, TextDirection direction) {
    if (identical(_style, style) && _direction == direction) return;
    final before = _style;
    final directionChanged = _direction != direction;
    final transitionsChanged = !identical(
      before.transitions,
      style.transitions,
    );
    _style = style;
    _direction = direction;
    for (final field in StyleField.values) {
      final raw = field.declaration(style);
      final changed =
          field.declaration(before) != raw ||
          (directionChanged && raw is EdgeInsetsGeometry && raw is! EdgeInsets);
      final old = _track(field);
      if (!changed && (!transitionsChanged || old == null)) continue;
      final to = changed
          ? (raw == null ? null : _parse(field, raw))
          : _targets[field.index];
      final transition = _hasLayout
          ? _transition(field, style.transitions)
          : null;
      assert(
        transition == null ||
            (!transition.duration.isNegative && !transition.delay.isNegative),
      );
      final immediate =
          transition == null ||
          transition.duration + transition.delay == Duration.zero;
      if (!immediate && _targets[field.index] == to) continue;
      if (field.damage == layout && _targets[field.index] != to) {
        _externalLayout = true;
        _externalVersion++;
      }
      if (old != null) _tracks!.remove(old);
      _targets[field.index] = to;
      var from = _values[field.index];
      if (immediate || from == to) {
        _write(field, to);
        continue;
      }
      if (field.isLength && _unresolvedLast(field, from as StyleLength?)) {
        from = styleLength(_usedLength(field));
      }
      (_tracks ??= []).add(_StyleTrack(field, from, to, transition));
      _write(field, from);
      // auto 起点可能恰好等于当前值，仍需进入布局获取更新后的 child 端点。
      if (field.isLength) _damage |= layout;
    }
    if (_tracks?.isNotEmpty ?? false) {
      _ticker ??= Ticker(_tick);
      if (!_ticker!.isActive) _ticker!.start();
    } else {
      _ticker?.stop();
    }
    _flush();
  }

  bool _unresolvedLast(StyleField field, StyleLength? value) =>
      value == null ||
      (value.relative &&
          !(field == StyleField.width ? _widthResolved : _heightResolved));

  double _usedLength(StyleField field) =>
      field == StyleField.width ? _lastBoxSize.width : _lastBoxSize.height;

  void _tick(Duration elapsed) {
    final tracks = _tracks!;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    for (var i = tracks.length - 1; i >= 0; i--) {
      final track = tracks[i];
      if (now >= track.deadline) {
        _write(track.field, track.target);
        tracks.removeAt(i);
      } else {
        _write(track.field, track.sample(now));
        // 活动 auto 需要观察 tight 子树的独立内容更新；等待 delay 时仍不探测。
        if (track.field.isLength &&
            (track.end == null || track.measured) &&
            now >= track.start + track.delay) {
          _damage |= layout;
        }
      }
    }
    _flush();
    if (tracks.isEmpty) _ticker!.stop();
  }

  /// child、约束或引用导致的外部布局变化，仅使有关端点下次重新测量。
  void invalidateLayout() {
    if (BoxLayout.isMeasuring) return;
    _externalLayout = true;
    _externalVersion++;
  }

  EdgeInsets? get _padding => _values[StyleField.padding.index] as EdgeInsets?;
  EdgeInsets? get _margin => _values[StyleField.margin.index] as EdgeInsets?;

  double? _length(
    StyleLength? value,
    Axis axis,
    BoxConstraints available,
    BoxLayout box, {
    required bool dry,
  }) {
    if (value == null) return null;
    var bound = axis == Axis.horizontal
        ? available.maxWidth
        : available.maxHeight;
    if (value.relative && !bound.isFinite) {
      bound = box.reference(axis, dry: dry) ?? double.infinity;
    }
    return value.resolve(bound);
  }

  LayoutStyle _resolve(
    BoxConstraints constraints,
    BoxLayout box, {
    StyleLength? width,
    StyleLength? height,
    bool dry = false,
  }) {
    final padding = _padding, margin = _margin;
    if (width == null && height == null && padding == null && margin == null) {
      return LayoutStyle.empty;
    }
    final available = BoxLayout.availableConstraints(constraints, margin);
    return LayoutStyle(
      width: _length(width, Axis.horizontal, available, box, dry: dry),
      height: _length(height, Axis.vertical, available, box, dry: dry),
      padding: padding,
      margin: margin,
    );
  }

  /// 在真实布局阶段完成按需端点测量，输出可直接交给盒执行器的属性。
  LayoutStyle prepareLayout(BoxConstraints constraints, BoxLayout box) {
    if (!BoxLayout.isMeasuring) {
      final width = _track(StyleField.width),
          height = _track(StyleField.height);
      // 较晚结束的 auto 轴以已结束的另一轴目标测量，较早轴依赖其当前采样，避免循环重测。
      if (width != null && height != null && width.deadline < height.deadline) {
        _prepareLength(height, constraints, box);
        _prepareLength(width, constraints, box);
      } else {
        if (width != null) _prepareLength(width, constraints, box);
        if (height != null) _prepareLength(height, constraints, box);
      }
      _externalLayout = false;
      _lastConstraints = constraints;
    }
    final result = _resolve(
      constraints,
      box,
      width: _values[StyleField.width.index] as StyleLength?,
      height: _values[StyleField.height.index] as StyleLength?,
    );
    if (!BoxLayout.isMeasuring) _layoutValues = result;
    return result;
  }

  void _prepareLength(
    _StyleTrack track,
    BoxConstraints constraints,
    BoxLayout box,
  ) {
    final axis = track.field == StyleField.width
        ? Axis.horizontal
        : Axis.vertical;
    final available = BoxLayout.availableConstraints(constraints, _margin);
    var bound = axis == Axis.horizontal
        ? available.maxWidth
        : available.maxHeight;
    if (!bound.isFinite) {
      final current = _values[track.field.index] as StyleLength?;
      final target = track.target as StyleLength?;
      if ((current?.relative ?? false) || (target?.relative ?? false)) {
        bound = box.reference(axis) ?? double.infinity;
      }
    }
    var current = _values[track.field.index];
    final lostReference =
        current != null && (current as StyleLength).relative && !bound.isFinite;
    if (lostReference) {
      current = styleLength(_usedLength(track.field));
      _values[track.field.index] = current;
    }
    final target = track.target as StyleLength?;
    final resolved = target?.resolve(bound);
    if (resolved != null) {
      track.setEnd(
        target!,
        current,
        rebase: lostReference || track.measured,
        force: lostReference,
      );
      track.measured = false;
      return;
    }

    if (SchedulerBinding.instance.currentFrameTimeStamp <
        track.start + track.delay) {
      return;
    }

    var width = _values[StyleField.width.index] as StyleLength?;
    var height = _values[StyleField.height.index] as StyleLength?;
    final other = _track(
      track.field == StyleField.width ? StyleField.height : StyleField.width,
    );
    if (track.field == StyleField.width) {
      width = target;
      if (other != null &&
          other.target == null &&
          other.deadline <= track.deadline) {
        height = other.target as StyleLength?;
      }
    } else {
      height = target;
      if (other != null &&
          other.target == null &&
          other.deadline <= track.deadline) {
        width = other.target as StyleLength?;
      }
    }
    final request = _resolve(constraints, box, width: width, height: height);
    // 任意 child 可能在 tight 约束下独立更新，不能把父级 dirty 当成跨帧内容版本。
    // 只合并同帧、同约束的测量；活动 auto 在下一帧重新获取真实端点。
    final key = (
      SchedulerBinding.instance.currentFrameTimeStamp,
      constraints,
      request.width,
      request.height,
      request.padding,
      request.margin,
      _externalVersion,
    );
    if (_measurementKey != key || lostReference) {
      _measurementSize = box.measure(constraints, request);
      _measurementKey = key;
    }
    final size = _measurementSize!;
    final end = styleLength(axis == Axis.horizontal ? size.width : size.height);
    final external =
        _externalLayout ||
        (_lastConstraints != null && _lastConstraints != constraints);
    track.setEnd(
      end,
      current,
      rebase: lostReference || (external && track.end != null),
      force: lostReference,
    );
    track.measured = true;
    // 连续几何动画更新端点后在本帧重新采样，避免截止帧才切换成真实自然尺寸。
    _values[track.field.index] = track.sample(
      SchedulerBinding.instance.currentFrameTimeStamp,
    );
  }

  /// dry/intrinsic 只读求值，不修改轨道、时钟、参照订阅或正式布局缓存。
  LayoutStyle readLayout(BoxConstraints constraints, BoxLayout box) => _resolve(
    constraints,
    box,
    width: _values[StyleField.width.index] as StyleLength?,
    height: _values[StyleField.height.index] as StyleLength?,
    dry: true,
  );

  /// 正式布局结束后记录实际几何，用于 auto 和失去参照时的动画接续。
  void didLayout(Size boxSize) {
    if (BoxLayout.isMeasuring) return;
    _hasLayout = true;
    _lastBoxSize = boxSize;
    _widthResolved = _layoutValues.width != null;
    _heightResolved = _layoutValues.height != null;
  }

  /// 释放按需创建的动画时钟。
  void dispose() => _ticker?.dispose();
}

/// 私有属性轨道，声明目标与实际测量端点分别保存。
class _StyleTrack {
  _StyleTrack(this.field, this.from, this.target, ElTransition transition)
    : end = target,
      duration = transition.duration,
      delay = transition.delay,
      curve = transition.curve,
      start = SchedulerBinding.instance.currentFrameTimeStamp;

  final StyleField field;
  final Object? target;
  final Curve curve;
  Object? from, end;
  Duration start, duration, delay;
  bool measured = false;

  Duration get deadline => start + delay + duration;

  Object? sample(Duration now) {
    final after = now - start - delay;
    if (after <= Duration.zero || (field.isLength && end == null)) return from;
    if (after >= duration) return target;
    final t = curve.transform(
      (after.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0),
    );
    return field.interpolate(from, end, t);
  }

  void setEnd(
    Object value,
    Object? current, {
    required bool rebase,
    bool force = false,
  }) {
    // 无关布局请求不能改变曲线；只有失去参照才需要同端点强制接续。
    if (end == value && !force) return;
    if (end != null && rebase) {
      final now = SchedulerBinding.instance.currentFrameTimeStamp;
      final waiting = start + delay - now;
      duration = Duration(
        microseconds: math.max(
          0,
          (deadline - now).inMicroseconds - math.max(0, waiting.inMicroseconds),
        ),
      );
      delay = Duration(microseconds: math.max(0, waiting.inMicroseconds));
      start = now;
      from = current;
    }
    end = value;
  }
}
