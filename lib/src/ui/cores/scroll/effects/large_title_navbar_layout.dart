part of '../virtual/virtual_pipeline.dart';

class _LargeTitleNavbarLayout extends MultiChildRenderObjectWidget {
  const _LargeTitleNavbarLayout({
    required this.progress,
    required this.scale,
    required this.fade,
    required this.center,
    required this.stretch,
    required this.safeTop,
    required this.direction,
    required this.bottomPadding,
    required this.bottomBorder,
    required this.onRangeChanged,
    required this.onBottomExtentChanged,
    required this.onLayoutCollapseChanged,
    required super.children,
  });
  final double progress;
  final bool scale;
  final bool fade;
  final bool center;
  final double stretch;
  final double safeTop;
  final TextDirection direction;
  final EdgeInsets bottomPadding;
  final BorderSide? bottomBorder;
  final ValueChanged<double> onRangeChanged;
  final ValueChanged<double> onBottomExtentChanged;
  final ValueChanged<double> onLayoutCollapseChanged;
  @override
  _RenderLargeTitleNavbar createRenderObject(BuildContext context) => _RenderLargeTitleNavbar(this);
  @override
  void updateRenderObject(BuildContext context, _RenderLargeTitleNavbar renderObject) => renderObject.update(this);
}

class _RenderLargeTitleNavbar extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  _RenderLargeTitleNavbar(this._configuration);
  _LargeTitleNavbarLayout _configuration;
  Matrix4 _largeTransform = Matrix4.identity();
  Matrix4 _bottomTransform = Matrix4.identity();
  double _compactBottom = 0;
  double? _reportedRange;
  double? _reportedBottomExtent;
  Rect _bottomClip = Rect.zero;
  Rect? _bottomBorderRect;
  int _generation = 0;
  final LayerHandle<TransformLayer> _titleLayer = LayerHandle<TransformLayer>();
  final LayerHandle<TransformLayer> _bottomLayer = LayerHandle<TransformLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  void update(_LargeTitleNavbarLayout value) {
    final previous = _configuration;
    // 回调接收者始终更新；相同视觉配置不打断子项自己的布局失效传播。
    _configuration = value;
    if (previous.progress == value.progress &&
        previous.scale == value.scale &&
        previous.fade == value.fade &&
        previous.center == value.center &&
        previous.stretch == value.stretch &&
        previous.safeTop == value.safeTop &&
        previous.bottomPadding == value.bottomPadding &&
        previous.bottomBorder == value.bottomBorder &&
        previous.direction == value.direction) {
      return;
    }
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CollapseParentData) child.parentData = _CollapseParentData();
  }

  @override
  void performLayout() {
    final config = _configuration;
    final width = constraints.maxWidth;
    if (!width.isFinite) throw FlutterError('大标题导航头需要有界宽度。');
    final large = firstChild!;
    final compact = childAfter(large)!;
    final leading = childAfter(compact)!;
    final actions = childAfter(leading)!;
    final bottom = childAfter(actions);
    final loose = BoxConstraints(maxWidth: width);
    leading.layout(loose, parentUsesSize: true);
    actions.layout(loose, parentUsesSize: true);
    compact.layout(
      BoxConstraints(maxWidth: math.max(0, width - leading.size.width - actions.size.width - 32)),
      parentUsesSize: true,
    );
    large.layout(BoxConstraints(maxWidth: math.max(0, width - 32)), parentUsesSize: true);
    bottom?.layout(
      BoxConstraints.tightFor(width: math.max(0, width - config.bottomPadding.horizontal)),
      parentUsesSize: true,
    );
    final compactHeight = math.max(compact.size.height + 16, math.max(leading.size.height, actions.size.height));
    final rtl = config.direction == .rtl;
    final left = (rtl ? actions.size.width : leading.size.width) + 16;
    final right = width - (rtl ? leading.size.width : actions.size.width) - 16;
    final compactX =
        (config.center
                ? (width - compact.size.width) / 2
                : rtl
                ? right - compact.size.width
                : left)
            .clamp(left, math.max(left, right - compact.size.width));
    final compactPoint = Offset(compactX.toDouble(), config.safeTop + (compactHeight - compact.size.height) / 2);
    (compact.parentData! as BoxParentData).offset = compactPoint;
    (leading.parentData! as BoxParentData).offset = Offset(
      rtl ? width - leading.size.width : 0,
      config.safeTop + (compactHeight - leading.size.height) / 2,
    );
    (actions.parentData! as BoxParentData).offset = Offset(
      rtl ? 0 : width - actions.size.width,
      config.safeTop + (compactHeight - actions.size.height) / 2,
    );
    _compactBottom = config.safeTop + compactHeight;
    final titleRange = large.size.height + 16;
    final bottomExtent = bottom == null ? 0.0 : bottom.size.height + config.bottomPadding.vertical;
    final range = titleRange + bottomExtent;
    // 搜索区与标题共享行程：先以平移为主，再渐渐缩小标题，不等待搜索区消失。
    final titleProgress = config.progress;
    final bottomPhase = _navbarBottomPhase(config.progress, range, bottomExtent);
    size = constraints.constrain(Size(width, _compactBottom + range * (1 - config.progress)));
    final bottomEnd = size.height - config.bottomPadding.bottom * (1 - bottomPhase.tail);
    final border = config.bottomBorder;
    final borderWidth = border == null || border.style == BorderStyle.none ? 0.0 : border.width;
    final hasBorder = bottom != null && borderWidth > 0;
    final naturalHeight = bottom?.size.height ?? 0.0;
    final remainingHeight = naturalHeight * (1 - bottomPhase.collapse);
    // 最后一帧搜索背景保留一条细线，与后续边框在同一位置交接，避免先消失再闪出。
    final paintedHeight = hasBorder && bottomPhase.collapse < 1
        ? math.max(borderWidth, remainingHeight)
        : remainingHeight;
    final bottomTop = bottomEnd - paintedHeight;
    _bottomClip = Rect.fromLTRB(config.bottomPadding.left, bottomTop, width - config.bottomPadding.right, bottomEnd);
    _bottomBorderRect = hasBorder && bottomPhase.collapse >= 1
        ? Rect.fromLTRB(
            config.bottomPadding.left * (1 - bottomPhase.tail),
            bottomEnd - borderWidth,
            width - config.bottomPadding.right * (1 - bottomPhase.tail),
            bottomEnd,
          )
        : null;
    if (bottom != null) {
      _bottomTransform = Matrix4.diagonal3Values(1, naturalHeight > 0 ? paintedHeight / naturalHeight : 0, 1)
        ..setTranslationRaw(config.bottomPadding.left, bottomTop, 0);
    }
    // 只记录已布局的折叠量，供拖柄还原同一帧的范围；不在布局期间触发构建或改登记。
    config.onLayoutCollapseChanged(range * config.progress);
    final start = Offset(rtl ? width - 16 - large.size.width : 16, _compactBottom + 8);
    final ratio = large.size.isEmpty
        ? 1.0
        : math.min(compact.size.width / large.size.width, compact.size.height / large.size.height).clamp(0.0, 1.0);
    final target =
        compactPoint +
        Offset(
          (compact.size.width - large.size.width * ratio) / 2,
          (compact.size.height - large.size.height * ratio) / 2,
        );
    final scaleProgress = bottomExtent > 0 ? Curves.easeIn.transform(titleProgress) : titleProgress;
    final scale = (config.scale ? 1 + (ratio - 1) * scaleProgress : 1.0) * (1 + config.stretch);
    final point =
        (config.scale ? Offset.lerp(start, target, titleProgress)! : start - Offset(0, titleRange * titleProgress)) -
        Offset(0, large.size.height * config.stretch);
    _largeTransform = Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(point.dx, point.dy, 0);
    if (_reportedRange != range || _reportedBottomExtent != bottomExtent) {
      _reportedRange = range;
      _reportedBottomExtent = bottomExtent;
      final generation = ++_generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (attached && generation == _generation) {
          _configuration.onBottomExtentChanged(bottomExtent);
          _configuration.onRangeChanged(range);
        }
      });
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (inner, origin) {
      void paintLarge(PaintingContext ctx, Offset point) => _titleLayer.layer = ctx.pushTransform(
        true,
        point,
        _largeTransform,
        (transformed, at) => transformed.paintChild(firstChild!, at),
        oldLayer: _titleLayer.layer,
      );
      if (_configuration.scale) {
        paintLarge(inner, origin);
      } else {
        inner.pushClipRect(
          needsCompositing,
          origin,
          Rect.fromLTRB(0, _compactBottom, size.width, size.height),
          paintLarge,
        );
      }
      var child = childAfter(firstChild!);
      while (child != null) {
        final current = child;
        if (childCount > 4 && identical(current, lastChild)) {
          if (!_bottomClip.isEmpty) {
            _bottomLayer.layer = inner.pushTransform(
              true,
              origin,
              _bottomTransform,
              (ctx, at) => ctx.paintChild(current, at),
              oldLayer: _bottomLayer.layer,
            );
          } else {
            _bottomLayer.layer = null;
          }
        } else {
          inner.paintChild(current, origin + (current.parentData! as BoxParentData).offset);
        }
        child = childAfter(child);
      }
      if (_bottomBorderRect case final rect?) {
        inner.canvas.drawRect(rect.shift(origin), Paint()..color = _configuration.bottomBorder!.color);
      }
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final current = child;
      final isBottom = childCount > 4 && identical(current, lastChild);
      if (isBottom) {
        if (!_bottomClip.contains(position)) {
          child = childBefore(current);
          continue;
        }
      }
      if (identical(current, firstChild) && !_configuration.scale && position.dy < _compactBottom) return false;
      final hit = identical(current, firstChild) || isBottom
          ? result.addWithPaintTransform(
              transform: isBottom ? _bottomTransform : _largeTransform,
              position: position,
              hitTest: (result, point) => current.hitTest(result, position: point),
            )
          : result.addWithPaintOffset(
              offset: (current.parentData! as BoxParentData).offset,
              position: position,
              hitTest: (result, point) => current.hitTest(result, position: point),
            );
      if (hit) return true;
      child = childBefore(current);
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (identical(child, firstChild)) {
      transform.multiply(_largeTransform);
    } else if (childCount > 4 && identical(child, lastChild)) {
      transform.multiply(_bottomTransform);
    } else {
      final point = (child.parentData! as BoxParentData).offset;
      transform.translateByDouble(point.dx, point.dy, 0, 1);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final compact = childAfter(firstChild!)!;
    final handoff = _configuration.fade ? .5 : 1.0;
    visitor(_configuration.progress >= handoff ? compact : firstChild!);
    final leading = childAfter(compact)!;
    final actions = childAfter(leading)!;
    visitor(leading);
    visitor(actions);
    if (childAfter(actions) case final bottom?) {
      if (!_bottomClip.isEmpty) visitor(bottom);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    if (childCount > 4 && identical(child, lastChild)) return _bottomClip;
    return identical(child, firstChild) && !_configuration.scale
        ? Rect.fromLTRB(0, _compactBottom, size.width, size.height)
        : Offset.zero & size;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // 重挂时 Mixin 已重新绑定；即使约束没变，也必须重新上报被清空的折叠行程。
    markNeedsLayout();
  }

  @override
  void detach() {
    _generation++;
    _reportedRange = null;
    _reportedBottomExtent = null;
    super.detach();
  }

  @override
  void dispose() {
    _titleLayer.layer = null;
    _bottomLayer.layer = null;
    super.dispose();
  }
}
