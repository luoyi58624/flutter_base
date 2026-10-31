part of 'index.dart';

/// 组的排布层：线性布局 + 接缝绘制。
///
/// 私有——它只服务按钮组，不是通用基元。子项自身不画内侧缝边
/// （[ButtonGroup] 的 `_positionBorder` 只保留外侧边），接缝完全归这里裁决。
class _ButtonGroupLayout extends MultiChildRenderObjectWidget {
  const _ButtonGroupLayout({
    required this.axis,
    required this.block,
    required this.flexes,
    required super.children,
  });

  final Axis axis;
  final bool block;
  final List<int> flexes;
  @override
  _RenderButtonGroup createRenderObject(BuildContext context) {
    return _RenderButtonGroup(
      axis: axis,
      block: block,
      flexes: flexes,
      devicePixelRatio:
          MediaQuery.maybeDevicePixelRatioOf(context) ??
          View.of(context).devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderButtonGroup renderObject,
  ) {
    renderObject
      ..axis = axis
      ..block = block
      ..flexes = flexes
      ..devicePixelRatio =
          MediaQuery.maybeDevicePixelRatioOf(context) ??
          View.of(context).devicePixelRatio
      // 业务选中值经子项语义传入；组件重建时重新裁决接缝。
      ..markNeedsPaint();
  }
}

class _ButtonGroupParentData extends ContainerBoxParentData<RenderBox> {
  // 释放后仍沿上次激活项的边框过渡，避免立刻跳回另一侧的常态色。
  ElRenderView? seamOwner;
}

class _RenderButtonGroup extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ButtonGroupParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ButtonGroupParentData> {
  _RenderButtonGroup({
    required this._axis,
    required this._block,
    required this._flexes,
    required this._devicePixelRatio,
  });

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    // DPI 变化可能只更新根图层，组件需重新记录已按物理像素对齐的接缝。
    markNeedsPaint();
  }

  Axis _axis;
  Axis get axis => _axis;
  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsLayout();
  }

  bool _block;
  bool get block => _block;
  set block(bool value) {
    if (_block == value) return;
    _block = value;
    markNeedsLayout();
  }

  List<int> _flexes;
  List<int> get flexes => _flexes;
  set flexes(List<int> value) {
    if (listEquals(_flexes, value)) return;
    _flexes = value;
    markNeedsLayout();
  }

  bool get _horizontal => axis == Axis.horizontal;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ButtonGroupParentData) {
      child.parentData = _ButtonGroupParentData();
    }
  }

  // --- 子状态订阅：hover / 按压 / 选中 / 键盘聚焦翻转时重绘接缝 --------------
  //
  // 这些位由 ElRenderView 在 render 层内部维护，不经过 widget 层（正是它快的
  // 原因）。订阅还有个副作用是必需的：ElRenderView 只在"有状态 listener"时
  // 才注册鼠标跟踪，不订阅的话 hover 位恒为 false。

  final List<ElRenderView> _subscribed = <ElRenderView>[];

  void _onChildStateChanged() => markNeedsPaint();

  void _subscribeChildren() {
    var child = firstChild;
    while (child != null) {
      if (child is ElRenderView) {
        child.stateSource.addListener(
          _onChildStateChanged,
          states: const {.hover, .tap, .focusVisible, .disabled},
        );
        _subscribed.add(child);
      }
      child = (child.parentData! as _ButtonGroupParentData).nextSibling;
    }
  }

  void _unsubscribeChildren() {
    for (final view in _subscribed) {
      view.stateSource.removeListener(_onChildStateChanged);
    }
    _subscribed.clear();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _subscribeChildren();
  }

  @override
  void detach() {
    _unsubscribeChildren();
    super.detach();
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    super.insert(child, after: after);
    if (attached) _resubscribe();
  }

  @override
  void remove(RenderBox child) {
    super.remove(child);
    if (attached) _resubscribe();
  }

  void _resubscribe() {
    _unsubscribeChildren();
    _subscribeChildren();
  }

  // --- 布局 ------------------------------------------------------------------

  @override
  void performLayout() {
    final count = childCount;
    if (count == 0) {
      size = constraints.smallest;
      return;
    }
    size = _layoutChildren(constraints, dry: false);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (childCount == 0) return constraints.smallest;
    return _layoutChildren(constraints, dry: true);
  }

  /// 线性排布，**无重叠**（接缝是组画的线，不需要像旧实现那样靠 1px 重叠
  /// 抵消两条相邻边框）。
  ///
  /// 两遍布局：先以宽松交叉约束量出各项 hug 尺寸、取最大交叉长；再以
  /// **tight 交叉约束**重布局全部子项——按钮带 `alignment: .center`（引擎语义
  /// 下有界约束撑满），tight 约束下各项等高、内容垂直居中、上下边框对齐。
  ///
  /// `dry` 时只测量不写 offset（`getDryLayout` 不得改子状态）。
  Size _layoutChildren(BoxConstraints constraints, {required bool dry}) {
    // 第一遍的量测必须给**无界交叉约束**：按钮带 `alignment: .center`，引擎
    // 语义下有界约束撑满 max——任何有界交叉约束都会把按钮拉成组高。
    final crossHug = _horizontal
        ? BoxConstraints(maxHeight: double.infinity)
        : BoxConstraints(maxWidth: double.infinity);

    // block：主轴按 flex 份额均分（总长恰好填满）
    final totalFlex = _flexes.fold<int>(0, (a, b) => a + b);
    final mainAvailable = _horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final useBlock = block && mainAvailable.isFinite && totalFlex > 0;

    Size mainSizeOf(RenderBox child, BoxConstraints cc) => dry
        ? child.getDryLayout(cc)
        : (child..layout(cc, parentUsesSize: true)).size;

    // 第一遍：交叉轴 hug，量最大交叉长
    var crossExtent = 0.0;
    var index = 0;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _ButtonGroupParentData;
      final BoxConstraints cc;
      if (useBlock) {
        final flex = index < _flexes.length ? _flexes[index] : 1;
        final share = mainAvailable * flex / totalFlex;
        cc = _horizontal
            ? BoxConstraints(minWidth: share, maxWidth: share).enforce(crossHug)
            : BoxConstraints(
                minHeight: share,
                maxHeight: share,
              ).enforce(crossHug);
      } else {
        cc = crossHug;
      }
      final childSize = mainSizeOf(child, cc);
      crossExtent = math.max(
        crossExtent,
        _horizontal ? childSize.height : childSize.width,
      );
      index += 1;
      child = pd.nextSibling;
    }

    // 第二遍：交叉轴 tight 拉伸（等高），写 offset
    final tightCross = _horizontal
        ? BoxConstraints(minHeight: crossExtent, maxHeight: crossExtent)
        : BoxConstraints(minWidth: crossExtent, maxWidth: crossExtent);
    var mainOffset = 0.0;
    index = 0;
    child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _ButtonGroupParentData;
      final BoxConstraints cc;
      if (useBlock) {
        final flex = index < _flexes.length ? _flexes[index] : 1;
        final share = mainAvailable * flex / totalFlex;
        cc = _horizontal
            ? BoxConstraints(
                minWidth: share,
                maxWidth: share,
                minHeight: crossExtent,
                maxHeight: crossExtent,
              )
            : BoxConstraints(
                minHeight: share,
                maxHeight: share,
                minWidth: crossExtent,
                maxWidth: crossExtent,
              );
      } else {
        cc = tightCross;
      }
      final childSize = mainSizeOf(child, cc);
      if (!dry) {
        pd.offset = _horizontal ? Offset(mainOffset, 0) : Offset(0, mainOffset);
      }
      mainOffset += _horizontal ? childSize.width : childSize.height;
      index += 1;
      child = pd.nextSibling;
    }
    return constraints.constrain(
      _horizontal
          ? Size(mainOffset, crossExtent)
          : Size(crossExtent, mainOffset),
    );
  }

  // --- 绘制 ------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    _paintSeams(context, offset);
  }

  /// 单侧实心沿用外边框色；两侧均实心时，对比接缝随填充过渡淡入。
  void _paintSeams(PaintingContext context, Offset offset) {
    if (childCount < 2) return;
    final pixelTransform = _seamPixelTransform();
    final canvas = context.canvas;
    if (pixelTransform != null) {
      canvas.save();
      // 只硬化内部直边，接缝端点仍服从组外轮廓的抗锯齿覆盖。
      canvas.clipRect(offset & size);
    }
    var child = firstChild;
    while (child != null) {
      final next = (child.parentData! as _ButtonGroupParentData).nextSibling;
      if (next == null) break;
      if (child is ElRenderView && next is ElRenderView) {
        final source = _seamSource(child, next);
        final leftBorder = child.committedResolvedStyle.box.border;
        final rightBorder = next.committedResolvedStyle.box.border;
        final border = source == child ? leftBorder : rightBorder;
        final side = _horizontal ? border?.borderTop : border?.borderLeft;
        final color = side?.borderColor;
        final leftSeam =
            (_horizontal ? leftBorder?.borderRight : leftBorder?.borderBottom)?.borderColor;
        final rightSeam =
            (_horizontal ? rightBorder?.borderLeft : rightBorder?.borderTop)?.borderColor;
        if (side != null &&
            side.borderStyle != ElBorderStyle.none &&
            color is Color &&
            leftSeam is Color &&
            rightSeam is Color) {
          final contrast = source == child ? leftSeam : rightSeam;
          final seamColor = Color.lerp(
            color,
            contrast.withValues(alpha: color.a),
            math.min(leftSeam.a, rightSeam.a),
          )!;
          final width = side.resolveWidth();
          final nextOffset =
              (next.parentData! as _ButtonGroupParentData).offset;
          final rect = _horizontal
              ? Rect.fromLTWH(nextOffset.dx, 0, width, size.height)
              : Rect.fromLTWH(0, nextOffset.dy, size.width, width);
          if (width > 0) {
            canvas.drawRect(
              (pixelTransform == null ? rect : _snapSeam(rect, pixelTransform))
                  .shift(offset),
              Paint()
                ..color = seamColor
                ..isAntiAlias = pixelTransform == null,
            );
          }
        }
      }
      child = next;
    }
    if (pixelTransform != null) canvas.restore();
  }

  /// 合并窗口缩放与祖先变换；旋转、倾斜和透视继续使用原有抗锯齿绘制。
  Matrix4? _seamPixelTransform() {
    final transform = Matrix4.diagonal3Values(
      _devicePixelRatio,
      _devicePixelRatio,
      1,
    );
    transform.multiply(getTransformTo(null));
    final m = transform.storage;
    if (m.any((value) => !value.isFinite) ||
        m[0] <= 0 ||
        m[5] <= 0 ||
        m[1] != 0 ||
        m[4] != 0 ||
        m[3] != 0 ||
        m[7] != 0 ||
        m[15] != 1) {
      return null;
    }
    return transform;
  }

  /// 起点覆盖交界像素整列，宽度取最接近标称值的整像素，避免随落点忽粗忽细。
  Rect _snapSeam(Rect rect, Matrix4 transform) {
    final m = transform.storage;
    final scale = _horizontal ? m[0] : m[5];
    final origin = _horizontal ? m[12] : m[13];
    final start = (_horizontal ? rect.left : rect.top) * scale + origin;
    final width = (_horizontal ? rect.width : rect.height) * scale;
    // 矩阵连乘会把整数像素算成 n - ε，避免 floor 意外多扩一列。
    final snappedStart = ((start + 1e-7).floorToDouble() - origin) / scale;
    final snappedWidth = math.max(1, width.round()) / scale;
    return _horizontal
        ? Rect.fromLTWH(snappedStart, rect.top, snappedWidth, rect.height)
        : Rect.fromLTWH(rect.left, snappedStart, rect.width, snappedWidth);
  }

  ElRenderView _seamSource(ElRenderView left, ElRenderView right) {
    final data = right.parentData! as _ButtonGroupParentData;
    final leftRank = _rankOf(left);
    final rightRank = _rankOf(right);
    if (leftRank > rightRank) {
      data.seamOwner = left;
    } else if (rightRank > leftRank) {
      data.seamOwner = right;
    } else if (data.seamOwner != left && data.seamOwner != right) {
      data.seamOwner = left;
    }
    return data.seamOwner!;
  }

  /// 选中边优先；两侧均选中时，仅按压／聚焦项接管接缝。
  int _rankOf(ElRenderView child) {
    if (child.internalStateHas(.disabled)) return 0;
    final selected = child.semantics?.properties.selected == true ? 4 : 0;
    final interaction =
        child.internalStateHas(.tap) || child.internalStateHas(.focusVisible)
        ? 2
        : selected == 0 && child.internalStateHas(.hover)
        ? 1
        : 0;
    return selected + interaction;
  }

  /// 命中正序：项互不重叠，缝线落在后一项领地，无需反序。
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as _ButtonGroupParentData;
      final hit = result.addWithPaintOffset(
        offset: pd.offset,
        position: position,
        hitTest: (result, transformed) =>
            child!.hitTest(result, position: transformed),
      );
      if (hit) return true;
      child = pd.nextSibling;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final pd = child.parentData! as _ButtonGroupParentData;
    transform.translateByDouble(pd.offset.dx, pd.offset.dy, 0.0, 1.0);
  }

  // --- 固有尺寸 --------------------------------------------------------------

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicMain(height, min: true, width: true);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicMain(height, min: false, width: true);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicMain(width, min: true, width: false);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicMain(width, min: false, width: false);

  /// 主轴累加、交叉轴取最大——min / max 共用一份实现防漂移。
  double _intrinsicMain(
    double extent, {
    required bool min,
    required bool width,
  }) {
    final alongMain = width == _horizontal;
    var total = 0.0;
    var maxCross = 0.0;
    var child = firstChild;
    while (child != null) {
      final double value;
      if (width) {
        value = min
            ? child.getMinIntrinsicWidth(extent)
            : child.getMaxIntrinsicWidth(extent);
      } else {
        value = min
            ? child.getMinIntrinsicHeight(extent)
            : child.getMaxIntrinsicHeight(extent);
      }
      if (alongMain) {
        total += value;
      } else {
        maxCross = math.max(maxCross, value);
      }
      child = (child.parentData! as _ButtonGroupParentData).nextSibling;
    }
    return alongMain ? total : maxCross;
  }
}
