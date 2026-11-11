part of 'index.dart';

class _RippleTapState extends State<ElRippleTap> with TickerProviderStateMixin {
  final _surfaceKey = GlobalKey();
  final _ripples = <_Ripple>[];
  _Ripple? _pointerRipple;
  _Ripple? _returnRipple;
  _Ripple? _keyboardRipple;
  bool _hovered = false;
  bool _disableAnimations = false;

  _RippleRender? get _surface => _surfaceKey.currentContext?.findRenderObject() as _RippleRender?;

  void _repaint() => _surface?.markNeedsPaint();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_disableAnimations) _clear();
  }

  @override
  void didUpdateWidget(ElRippleTap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disabled) {
      _hovered = false;
      _clear();
    }
  }

  _Ripple? _start([Offset? globalPosition]) {
    if (widget.disabled || _disableAnimations) return null;
    final surface = _surface;
    if (surface == null || !surface.hasSize) return null;
    final bounds = surface.buttonBounds;
    final ripple = _Ripple(
      vsync: this,
      // 绘制层与事件宿主的原点不同，按绘制层换算才能覆盖 padding、alignment 和 transform。
      position: globalPosition == null
          ? bounds.size.center(Offset.zero)
          : surface.globalToLocal(globalPosition) - bounds.topLeft,
      size: bounds.size,
      repaint: _repaint,
      onRemoved: _remove,
    );
    _ripples.add(ripple);
    _repaint();
    return ripple;
  }

  void _remove(_Ripple ripple) {
    _ripples.remove(ripple);
    if (identical(_pointerRipple, ripple)) _pointerRipple = null;
    if (identical(_returnRipple, ripple)) _returnRipple = null;
    if (identical(_keyboardRipple, ripple)) _keyboardRipple = null;
    ripple.dispose();
    _repaint();
  }

  void _clear() {
    for (final ripple in _ripples) {
      ripple.dispose();
    }
    _ripples.clear();
    _pointerRipple = _returnRipple = _keyboardRipple = null;
    _repaint();
  }

  void _releaseKeyboardRipple() {
    // Space keyup 先清按压态再激活；等激活回调确认后，仅取消仍未被消费的会话。
    final ripple = _keyboardRipple;
    Future<void>.microtask(() {
      if (ripple == null || !identical(_keyboardRipple, ripple)) return;
      _keyboardRipple = null;
      ripple.cancel();
    });
  }

  void _tapDown(ElEventDetails event) {
    if (event.originalEvent is KeyEvent) {
      _keyboardRipple?.cancel();
      _keyboardRipple = _start();
      return;
    }
    // 移回时的 TapDown 来自 PointerMove，同一次按压只恢复最终态。
    final returning = event.originalEvent is PointerMoveEvent;
    _pointerRipple?.cancel();
    _pointerRipple = returning ? _returnRipple ?? _start(event.globalPosition) : _start(event.globalPosition);
    _returnRipple = null;
    if (returning) _pointerRipple?.showPressed();
  }

  void _tapUp(ElEventDetails event) {
    if (event.originalEvent is KeyEvent) {
      _releaseKeyboardRipple();
      return;
    }
    _returnRipple = null;
    _pointerRipple?.confirm();
    _pointerRipple = null;
  }

  void _tapCancel(ElEventDetails event) {
    if (event.originalEvent is KeyEvent) {
      _keyboardRipple?.cancel();
      _keyboardRipple = null;
      return;
    }
    final ripple = _pointerRipple;
    _pointerRipple = null;
    _returnRipple = event.originalEvent is PointerMoveEvent ? ripple : null;
    ripple?.cancel();
  }

  void _activate(ElEventDetails event) {
    if (event.originalEvent is PointerEvent) return;
    final ripple = event.originalEvent is KeyEvent
        ? _keyboardRipple ?? (event.logicalKey == LogicalKeyboardKey.space ? null : _start())
        : _start();
    ripple?.confirm();
    if (identical(_keyboardRipple, ripple)) _keyboardRipple = null;
  }

  void _hover(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    _repaint();
  }

  @override
  Widget build(BuildContext context) => ElButtonView(
    onPressed: widget.onPressed,
    disabled: widget.disabled,
    semanticLabel: widget.semanticLabel,
    style: widget.style,
    focusNode: widget.focusNode,
    event: ElEvent(
      onPointerEnter: (_) => _hover(true),
      onPointerExit: (_) => _hover(false),
      onTapDown: _tapDown,
      onTapUp: _tapUp,
      onTapCancel: _tapCancel,
      onTap: _activate,
    ),
    child: _RippleSurface(
      key: _surfaceKey,
      state: this,
      child: widget.child is Widget ? widget.child as Widget : ElView(child: widget.child),
    ),
  );

  @override
  void deactivate() {
    _clear();
    _hovered = false;
    super.deactivate();
  }
}

class _RippleSurface extends SingleChildRenderObjectWidget {
  const _RippleSurface({super.key, required this.state, required super.child});

  final _RippleTapState state;

  @override
  RenderObject createRenderObject(BuildContext context) => _RippleRender(state);

  @override
  void updateRenderObject(BuildContext context, _RippleRender renderObject) => renderObject.markNeedsPaint();
}

class _RippleRender extends RenderProxyBox {
  _RippleRender(this.state);

  final _RippleTapState state;

  ElRenderView get button => parent! as ElRenderView;

  Rect get buttonBounds => (button.boxOrigin - (parentData! as BoxParentData).offset) & button.boxSize;

  @override
  Rect get paintBounds =>
      parent is ElRenderView && button.hasSize ? super.paintBounds.expandToInclude(buttonBounds) : super.paintBounds;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (state.widget.disabled || (!state._hovered && state._ripples.isEmpty)) return;
    final resolved = button.committedResolvedStyle;
    // 纯 Widget 宿主可能保留颜色 token，复用 currentColor 的完整解析路径。
    final color = button.currentColorForBuild ?? const Color(0xff000000);
    final bounds = Offset.zero & button.boxSize;
    final radius = resolved.box.borderRadius;
    final clipper = resolved.box.clipPath;
    final canvas = context.canvas;
    final origin = offset + buttonBounds.topLeft;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    if (clipper != null) {
      canvas.clipPath(clipper.getClip(bounds.size));
    } else if (radius != null) {
      canvas.clipRRect(radius.resolve(resolved.inheritedBox.direction ?? TextDirection.ltr).toRRect(bounds));
    } else {
      canvas.clipRect(bounds);
    }
    _clipSurfaceChild(canvas);
    // 跟随 Flutter M2 按钮当前 overlayColor：hover 8%、pressed 10%，替换前景色 alpha。
    if (state._hovered) canvas.drawRect(bounds, Paint()..color = color.withValues(alpha: 0.08));
    for (final ripple in state._ripples) {
      ripple.paint(canvas, color.withValues(alpha: 0.10), bounds.size);
    }
    canvas.restore();
  }

  /// 叠加直接子 ElView 的裁剪，避免波纹越过子元素自己的圆角或路径。
  void _clipSurfaceChild(Canvas canvas) {
    final surfaceChild = child;
    if (surfaceChild is! ElRenderView) return;
    final parentData = surfaceChild.parentData;

    // buttonBounds.topLeft 是按钮盒在本渲染对象坐标中的起点；减去它后，
    // 子节点的盒坐标与前面已平移到按钮盒的 canvas 保持一致。
    // RenderProxyBox 的直接 child 使用普通 ParentData，位置由代理盒本身承担；
    // 只有嵌套布局代理才会在这里留下 BoxParentData 偏移。
    final childOffset = parentData is BoxParentData ? parentData.offset - buttonBounds.topLeft : -buttonBounds.topLeft;
    final childBounds = (surfaceChild.boxOrigin & surfaceChild.boxSize).shift(childOffset);
    final resolved = surfaceChild.committedResolvedStyle;
    final clipper = resolved.box.clipPath;
    if (clipper != null) {
      canvas.clipPath(clipper.getClip(surfaceChild.boxSize).shift(childBounds.topLeft));
      return;
    }

    final radius = resolved.box.borderRadius;
    if (radius == null) return;
    canvas.clipRRect(radius.resolve(resolved.inheritedBox.direction ?? TextDirection.ltr).toRRect(childBounds));
  }
}
