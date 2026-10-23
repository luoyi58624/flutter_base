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
      if (raw != null) _values[field.index] = field.parse(raw, _direction);
    }
    _targets.setAll(0, _values);
  }

  /// 消费结果需要重新布局。
  static const layout = 1;

  /// 消费结果只需要重新绘制。
  static const paint = 2;

  /// 消费结果改变后代的近似语义裁剪边界。
  static const semantics = 4;

  /// 宿主执行已经裁决的框架失效，不参与字段解析。
  final void Function(int damage) invalidate;

  ElStyle _style;
  TextDirection _direction;
  final _values = List<Object?>.filled(StyleField.values.length, null);
  final _targets = List<Object?>.filled(StyleField.values.length, null);
  List<_StyleTrack>? _tracks;
  Ticker? _ticker;
  int _damage = 0, _externalVersion = 0;
  bool _hasLayout = false, _externalLayout = false;
  Size _lastBoxSize = Size.zero;
  BoxConstraints? _lastConstraints;
  bool _widthResolved = true, _heightResolved = true;
  Object? _measurementKey;
  Size? _measurementSize;

  /// 已完成颜色解析和本帧插值的背景色。
  Color? get backgroundColor =>
      _values[StyleField.backgroundColor.index] as Color?;

  /// 已解析方向和本帧过渡的物理边框；完全不可见时不启动绘制执行器。
  Border? get border {
    final value = _values[StyleField.border.index] as Border?;
    return value != null &&
            (_paintsBorderSide(value.top) ||
                _paintsBorderSide(value.right) ||
                _paintsBorderSide(value.bottom) ||
                _paintsBorderSide(value.left))
        ? value
        : null;
  }

  /// 已完成数值与动画求值的轮廓；零宽或完全透明时不交给绘制器。
  OutlineStyle? get outline {
    final value = _values[StyleField.outline.index] as OutlineStyle?;
    if (value == null || value.width <= 0) return null;
    if (!(value.color.a > 0 ||
        (value.gradientOpacity > 0 &&
            (value.gradient?.colors.any((color) => color.a > 0) ?? false)))) {
      return null;
    }
    // 环境方向立即生效，包括目标已变为纯色、但当前渐变仍在退出的阶段。
    return value.gradient == null || value.direction == _direction
        ? value
        : (
            width: value.width,
            offset: value.offset,
            color: value.color,
            gradient: value.gradient,
            gradientOpacity: value.gradientOpacity,
            direction: _direction,
          );
  }

  /// 已解析方向、规范零值并完成本帧插值的物理圆角。
  BorderRadius? get borderRadius {
    final value = _values[StyleField.borderRadius.index] as BorderRadius?;
    return value == null || _isRectRadius(value) ? null : value;
  }

  /// 立即生效的裁剪模式，不占用动画轨道。
  Clip get clipBehavior =>
      _values[StyleField.clipBehavior.index] as Clip? ?? Clip.none;

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
    final selection = field.transitionField;
    if (selection == null) return null;
    if (transitions != null) {
      for (var i = transitions.length - 1; i >= 0; i--) {
        final item = transitions[i];
        if (item.field == null || item.field == selection) {
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
    // 仅刷新可见渐变的 shader，不因方向变化重启宽度、颜色或偏移动画。
    if (directionChanged && outline?.gradient != null) _damage |= paint;
    for (final field in StyleField.values) {
      final raw = field.declaration(style);
      final changed =
          field.declaration(before) != raw ||
          (directionChanged && field.dependsOnDirection(raw));
      final old = _track(field);
      if (!changed && (!transitionsChanged || old == null)) continue;
      final to = changed
          ? (raw == null ? null : field.parse(raw, _direction))
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
      if (field.isLength &&
          (to == null || _unresolvedLast(field, from as StyleLength?))) {
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

  double _lengthBasis(
    Axis axis,
    BoxConstraints constraints,
    BoxLayout box, {
    required bool dry,
  }) {
    final horizontal = axis == Axis.horizontal;
    final margin = _margin;
    var bound = horizontal ? constraints.maxWidth : constraints.maxHeight;
    if (margin != null) {
      bound = math.max(
        0.0,
        bound - (horizontal ? margin.horizontal : margin.vertical),
      );
    }
    if (!bound.isFinite) {
      bound = box.reference(axis, dry: dry) ?? double.infinity;
    }
    return bound;
  }

  LayoutStyle _resolve(
    BoxConstraints constraints,
    BoxLayout box, {
    StyleLength? width,
    StyleLength? height,
    bool dry = false,
  }) {
    final padding = _padding, margin = _margin;
    final widthFactor = _values[StyleField.widthFactor.index] as double?;
    final heightFactor = _values[StyleField.heightFactor.index] as double?;
    final minWidth = _values[StyleField.minWidth.index] as StyleLength?;
    final maxWidth = _values[StyleField.maxWidth.index] as StyleLength?;
    final minHeight = _values[StyleField.minHeight.index] as StyleLength?;
    final maxHeight = _values[StyleField.maxHeight.index] as StyleLength?;
    if (width == null &&
        height == null &&
        padding == null &&
        margin == null &&
        widthFactor == null &&
        heightFactor == null &&
        minWidth == null &&
        maxWidth == null &&
        minHeight == null &&
        maxHeight == null) {
      return LayoutStyle.empty;
    }
    // 同轴尺寸与上下限共用一次百分比参照；没有相对值就不查约束或祖先。
    final widthBasis =
        (width?.relative ?? false) ||
            (minWidth?.relative ?? false) ||
            (maxWidth?.relative ?? false)
        ? _lengthBasis(Axis.horizontal, constraints, box, dry: dry)
        : 0.0;
    final heightBasis =
        (height?.relative ?? false) ||
            (minHeight?.relative ?? false) ||
            (maxHeight?.relative ?? false)
        ? _lengthBasis(Axis.vertical, constraints, box, dry: dry)
        : 0.0;
    final usedWidth = width?.resolve(widthBasis);
    final usedHeight = height?.resolve(heightBasis);
    final usedMinWidth = minWidth?.resolve(widthBasis);
    final usedMinHeight = minHeight?.resolve(heightBasis);
    return LayoutStyle(
      width: usedWidth,
      height: usedHeight,
      minWidth: usedMinWidth == 0 ? null : usedMinWidth,
      maxWidth: maxWidth?.resolve(widthBasis),
      minHeight: usedMinHeight == 0 ? null : usedMinHeight,
      maxHeight: maxHeight?.resolve(heightBasis),
      padding: padding,
      margin: margin,
      widthFactor: usedWidth == null ? widthFactor : null,
      heightFactor: usedHeight == null ? heightFactor : null,
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
    return _resolve(
      constraints,
      box,
      width: _values[StyleField.width.index] as StyleLength?,
      height: _values[StyleField.height.index] as StyleLength?,
    );
  }

  void _prepareLength(
    _StyleTrack track,
    BoxConstraints constraints,
    BoxLayout box,
  ) {
    final axis = track.field == StyleField.width
        ? Axis.horizontal
        : Axis.vertical;
    var current = _values[track.field.index] as StyleLength?;
    final target = track.target as StyleLength?;
    final relative =
        (current?.relative ?? false) || (target?.relative ?? false);
    final bound = relative
        ? _lengthBasis(axis, constraints, box, dry: false)
        : double.infinity;
    final lostReference = (current?.relative ?? false) && !bound.isFinite;
    if (lostReference) {
      current = styleLength(_usedLength(track.field));
      _values[track.field.index] = current;
      // 等待 delay 时也必须冻结起点，后续采样不能恢复已失去参照的百分比。
      track.rebase(current);
    }
    final resolved = target?.resolve(bound);
    if (resolved != null) {
      track.setEnd(target!, current, rebase: track.measured);
      track.measured = false;
      return;
    }

    if (SchedulerBinding.instance.currentFrameTimeStamp <
        track.start + track.delay) {
      // 无参照目标保持待测量，延迟后的首次采样应使用原进度而非重新冻结起点。
      track.end = null;
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
      request.widthFactor,
      request.heightFactor,
      request.minWidth,
      request.maxWidth,
      request.minHeight,
      request.maxHeight,
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
    track.setEnd(end, current, rebase: !lostReference && external);
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
  void didLayout(Size boxSize, LayoutStyle values) {
    if (BoxLayout.isMeasuring) return;
    _hasLayout = true;
    _lastBoxSize = boxSize;
    _widthResolved = values.width != null;
    _heightResolved = values.height != null;
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

  void setEnd(Object value, Object? current, {required bool rebase}) {
    if (end == value) return;
    if (end != null && rebase) this.rebase(current);
    end = value;
  }

  // 接续当前画面时保留剩余等待时间与原截止时间。
  void rebase(Object? current) {
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final waiting = math.max(0, (start + delay - now).inMicroseconds);
    duration = Duration(
      microseconds: math.max(0, (deadline - now).inMicroseconds - waiting),
    );
    delay = Duration(microseconds: waiting);
    start = now;
    from = current;
  }
}
