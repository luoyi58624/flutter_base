import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../selection/common/selection_core.dart' show SelectionPaintOrderChildren;
import '../../view/render/hit_bounds.dart';
import '../../view/style/dimension.dart';

part 'layer_order.dart';
part 'stacking_box.dart';

/// 层叠布局。相比官方 `Stack` 多两件事：
///
/// 1. **[ElPositioned.zIndex]/[ElStackItem.zIndex]** —— 绘制/命中顺序与
///    [children] 数组顺序解耦。
///    官方 Stack 改层级只能挪数组位置，一挪就动 Element 复用（无 key 丢 State）；
///    zIndex 让数组顺序保持稳定，只排绘制顺序。
/// 2. **溢出命中**（[ElOverflowHitBounds]）—— `clipBehavior: .none` 时溢出本盒的
///    子仍然点得到（CSS `overflow: visible` 语义）。官方 Stack 按 `size.contains`
///    剪枝且不外传子溢出，是溢出命中协议的链断点。
///
/// 定位子可用自带的 [ElPositioned]，也可直接用官方 `Positioned` /
/// `Positioned.fill` / `PositionedDirectional`——[ElStackParentData] 继承
/// `StackParentData`，官方 `ParentDataWidget` 的类型校验（`parentData is T`）
/// 天然通过。想要 zIndex 才需要换成 [ElPositioned]，两者可在同一个
/// [ElStackView] 里混用。
///
/// 反向不成立：[ElPositioned] 放进官方 `Stack` 会断言失败（`StackParentData`
/// 不是 [ElStackParentData]），这是刻意的——那里的 zIndex 不会被消费。
class ElStackView extends MultiChildRenderObjectWidget {
  /// 创建层叠布局。
  const ElStackView({
    super.key,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.none,
    super.children,
  });

  /// 非定位子的对齐方式，同时作为定位子单轴缺边（如只写 left 没写 right）时的
  /// 该轴对齐基准。
  final AlignmentGeometry alignment;

  /// 文本方向；null 时取最近 `Directionality`。
  final TextDirection? textDirection;

  /// 非定位子的约束口径（loose / expand / passthrough），同官方 `StackFit`。
  final StackFit fit;

  /// 裁剪行为。**默认 [Clip.none]**（对齐 CSS `overflow: visible`，也与
  /// ElView 一致；官方 Stack 默认 hardEdge）。裁剪即封口：非 none 时子的溢出
  /// 既画不出来，也不外传命中边界。
  final Clip clipBehavior;

  @override
  RenderStackView createRenderObject(BuildContext context) {
    return RenderStackView(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderStackView renderObject) {
    renderObject
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..fit = fit
      ..clipBehavior = clipBehavior;
  }
}

/// [ElStackView] 中保留自然槽位的 relative layer item。
///
/// child 仍按普通非定位子参与 Stack 定尺和 [ElStackView.alignment]，最后再把
/// [offset] 加到 paint/hit/semantics 共用几何上；因此偏移不会改变兄弟布局。
/// 只需要 zIndex 而不需要偏移时也应使用本类。
class ElStackItem extends ParentDataWidget<ElStackParentData> {
  /// 创建保留自然槽位的 relative layer item。
  const ElStackItem({super.key, this.offset = Offset.zero, this.zIndex = 0, required super.child});

  /// 相对自然落点的物理像素偏移。
  final Offset offset;

  /// 当前 Stack stacking context 内的层级；负值保留布局但隐藏呈现与语义。
  final int zIndex;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is ElStackParentData);
    final parentData = renderObject.parentData! as ElStackParentData;
    final oldZIndex = parentData.zIndex;
    var needsLayout = parentData._clearAbsolutePositioning();
    var needsPaintOrder = false;
    if (parentData.relativeOffset != offset) {
      parentData.relativeOffset = offset;
      needsLayout = true;
    }
    if (parentData.zIndex != zIndex) {
      parentData.zIndex = zIndex;
      needsPaintOrder = true;
    }

    final parent = renderObject.parent;
    if (needsLayout) {
      parent?.markNeedsLayout();
    }
    if (needsPaintOrder && parent is RenderStackingBox && renderObject is RenderBox) {
      parent.markChildStackOrderChanged(renderObject, oldZIndex: oldZIndex);
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => ElStackView;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('offset', offset, defaultValue: Offset.zero));
    properties.add(IntProperty('zIndex', zIndex, defaultValue: 0));
  }
}

/// [ElStackView] 与滚动视口的原生定位成员，支持百分比尺寸和 [zIndex]。
///
/// 六个定位参数全部可选：只写 [zIndex] 也合法（子按 [ElStackView.alignment]
/// 摆放，仅调层级），省得为"只想调层级"再造第二个 widget。
///
/// 定位值走 [ElDimension]，接 `num` / 百分比字符串：
///
/// ```dart
/// ElPositioned(top: '100%', child: menu)      // 贴在宿主正下方（下拉菜单）
/// ElPositioned(left: '50%', top: 8, child: badge)
/// ```
///
/// 百分比参考轴同 CSS：[left]/[right]/[width] 对宿主宽度，
/// [top]/[bottom]/[height] 对宿主高度。折算发生在宿主尺寸定下来之后，
/// 故百分比恒有有限参考值。
/// 在 `ElScroll` 中参考的是整个视口盒，定位不贡献正文行高；只写
/// [zIndex] 则仍在滚动流内。滚动条与业务成员共享层序，默认层级为 10。
class ElPositioned extends ParentDataWidget<ElStackParentData> {
  /// 创建定位子。水平三值（[left]/[right]/[width]）与垂直三值
  /// （[top]/[bottom]/[height]）各自最多写两个。
  const ElPositioned({
    super.key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    this.zIndex = 0,
    required super.child,
  }) : assert(left == null || right == null || width == null),
       assert(top == null || bottom == null || height == null);

  /// 填满父盒（四边贴 0）。
  const ElPositioned.fill({
    super.key,
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
    this.zIndex = 0,
    required super.child,
  }) : width = null,
       height = null;

  /// 左边距。承载 `num | '50%' | ElDimension`。
  final Object? left;

  /// 上边距。承载 `num | '50%' | ElDimension`。
  final Object? top;

  /// 右边距。承载 `num | '50%' | ElDimension`。
  final Object? right;

  /// 下边距。承载 `num | '50%' | ElDimension`。
  final Object? bottom;

  /// 宽度。承载 `num | '50%' | ElDimension`；[left] 与 [right] 同时非 null 时忽略。
  final Object? width;

  /// 高度。承载 `num | '50%' | ElDimension`；[top] 与 [bottom] 同时非 null 时忽略。
  final Object? height;

  /// 层级。大者后绘制（盖在上面），命中按绘制逆序优先；负值保留布局与
  /// Element/RenderObject identity，但不绘制、不命中、不进入语义。
  ///
  /// 同值子保持 [ElStackView.children] 的数组顺序（排序按 `(zIndex, 下标)`
  /// 二元组，全序，与 `List.sort` 是否稳定无关）。
  final int zIndex;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is ElStackParentData);
    final parentData = renderObject.parentData! as ElStackParentData;
    final oldZIndex = parentData.zIndex;
    var needsLayout = false;
    var needsPaintOrder = false;

    // 六个方向统一归一化为 ElDimension 存进 parentData，真正折算成像素推迟到
    // performLayout（那时宿主尺寸已定，百分比才有参考值）。此处只 parse 一次，
    // 不在布局热路径反复解析字符串。
    parentData.dimOwned = true;
    if (parentData.relativeOffset != Offset.zero) {
      parentData.relativeOffset = Offset.zero;
      needsLayout = true;
    }
    final leftDim = ElDimension.parse(left);
    final topDim = ElDimension.parse(top);
    final rightDim = ElDimension.parse(right);
    final bottomDim = ElDimension.parse(bottom);
    final widthDim = ElDimension.parse(width);
    final heightDim = ElDimension.parse(height);

    if (parentData.leftDim != leftDim) {
      parentData.leftDim = leftDim;
      needsLayout = true;
    }
    if (parentData.topDim != topDim) {
      parentData.topDim = topDim;
      needsLayout = true;
    }
    if (parentData.rightDim != rightDim) {
      parentData.rightDim = rightDim;
      needsLayout = true;
    }
    if (parentData.bottomDim != bottomDim) {
      parentData.bottomDim = bottomDim;
      needsLayout = true;
    }
    if (parentData.widthDim != widthDim) {
      parentData.widthDim = widthDim;
      needsLayout = true;
    }
    if (parentData.heightDim != heightDim) {
      parentData.heightDim = heightDim;
      needsLayout = true;
    }
    // zIndex 不影响布局：只重排绘制/命中顺序 + 重绘。
    if (parentData.zIndex != zIndex) {
      parentData.zIndex = zIndex;
      needsPaintOrder = true;
    }

    final parent = renderObject.parent;
    if (needsLayout) {
      parent?.markNeedsLayout();
    }
    if (needsPaintOrder && parent is RenderStackingBox && renderObject is RenderBox) {
      parent.markChildStackOrderChanged(renderObject, oldZIndex: oldZIndex);
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => ElStackView;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('left', left, defaultValue: null));
    properties.add(DiagnosticsProperty<Object>('top', top, defaultValue: null));
    properties.add(DiagnosticsProperty<Object>('right', right, defaultValue: null));
    properties.add(DiagnosticsProperty<Object>('bottom', bottom, defaultValue: null));
    properties.add(DiagnosticsProperty<Object>('width', width, defaultValue: null));
    properties.add(DiagnosticsProperty<Object>('height', height, defaultValue: null));
    properties.add(IntProperty('zIndex', zIndex, defaultValue: 0));
  }
}

/// [ElStackView] 的子 parentData。
///
/// **继承 `StackParentData` 是兼容官方 `Positioned` 的全部机制**：
/// `ParentDataWidget.debugIsValidRenderObject` 只做 `parentData is T` 判定，
/// 子类实例天然满足 `is StackParentData`，官方 `applyParentData` 写六个定位
/// 字段即可正常工作（[zIndex] 保持默认 0、[dimOwned] 保持 false）。
///
/// 两套定位字段的分工：
/// - 继承来的 `left/top/right/bottom/width/height`（`double?`）是**像素结果**，
///   官方 `Positioned` 直接写它，`ElPositioned` 则由 `performLayout` 折算后写入；
///   `RenderStack.layoutPositionedChild` 只读这一套。
/// - `*Dim`（[ElDimension]）是 `ElPositioned` 的**声明值**，可含百分比。
class ElStackParentData extends StackParentData {
  /// 同一 stacking context 内的显式层级。负值保留布局，但退出绘制、命中和语义。
  int zIndex = 0;

  /// 同一层级内的激活顺序。滚动吸顶交接用它抬高当前项。
  int activationOrder = 0;

  /// 同一层级、同一激活序下的稳定挂载顺序。
  int mountOrder = 0;

  /// relative item 相对自然槽位的最终偏移。
  Offset relativeOffset = Offset.zero;

  /// 本子的定位是否由 [ElPositioned] 托管（走 `*Dim` 声明值折算）。
  /// 官方 `Positioned` 恒 false，直接用继承来的像素字段。
  bool dimOwned = false;

  /// 左边距声明值。
  ElDimension? leftDim;

  /// 上边距声明值。
  ElDimension? topDim;

  /// 右边距声明值。
  ElDimension? rightDim;

  /// 下边距声明值。
  ElDimension? bottomDim;

  /// 宽度声明值。
  ElDimension? widthDim;

  /// 高度声明值。
  ElDimension? heightDim;

  /// 是否为定位子。
  ///
  /// [dimOwned] 时必须看**声明值**而非像素字段：像素字段要等
  /// `performLayout` 折算才写，而定位判定发生在折算之前（定尺第一遍）。
  bool get isPositionedForLayout {
    if (!dimOwned) return isPositioned;
    return leftDim != null ||
        topDim != null ||
        rightDim != null ||
        bottomDim != null ||
        widthDim != null ||
        heightDim != null;
  }

  /// 把声明值按宿主尺寸折算进像素字段。仅 [dimOwned] 的子需要。
  ///
  /// 参考轴同 CSS：水平三值对宽度，垂直三值对高度。
  void resolveDimensions(Size hostSize) {
    if (!dimOwned) return;
    left = leftDim?.resolve(hostSize.width);
    top = topDim?.resolve(hostSize.height);
    right = rightDim?.resolve(hostSize.width);
    bottom = bottomDim?.resolve(hostSize.height);
    width = widthDim?.resolve(hostSize.width);
    height = heightDim?.resolve(hostSize.height);
  }

  bool _clearAbsolutePositioning() {
    final changed =
        dimOwned ||
        leftDim != null ||
        topDim != null ||
        rightDim != null ||
        bottomDim != null ||
        widthDim != null ||
        heightDim != null ||
        left != null ||
        top != null ||
        right != null ||
        bottom != null ||
        width != null ||
        height != null;
    dimOwned = false;
    leftDim = null;
    topDim = null;
    rightDim = null;
    bottomDim = null;
    widthDim = null;
    heightDim = null;
    left = null;
    top = null;
    right = null;
    bottom = null;
    width = null;
    height = null;
    return changed;
  }

  @override
  String toString() => zIndex == 0 ? super.toString() : 'zIndex=$zIndex; ${super.toString()}';
}

/// [ElStackView] 的 render。
///
/// 布局算法与官方 `RenderStack` 一致（复用 `RenderStack.layoutPositionedChild`
/// 与 `StackParentData.positionedChildConstraints`），差异只在三处：
/// zIndex 绘制序、溢出命中协议、clip 默认 none。
class RenderStackView extends RenderStackingBox<ElStackParentData> implements SelectionPaintOrderChildren {
  /// 创建 render。
  RenderStackView({
    AlignmentGeometry alignment = AlignmentDirectional.topStart,
    TextDirection? textDirection,
    StackFit fit = StackFit.loose,
    Clip clipBehavior = Clip.none,
  }) : this._(alignment, textDirection, fit, clipBehavior);

  RenderStackView._(this._alignment, this._textDirection, this._fit, this._clipBehavior);

  /// 非定位子对齐 + 定位子缺边轴的对齐基准。
  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    if (_alignment == value) return;
    _alignment = value;
    _resolvedAlignment = null;
    markNeedsLayout();
  }

  /// 文本方向。
  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _resolvedAlignment = null;
    markNeedsLayout();
  }

  /// 非定位子约束口径。
  StackFit get fit => _fit;
  StackFit _fit;
  set fit(StackFit value) {
    if (_fit == value) return;
    _fit = value;
    markNeedsLayout();
  }

  /// 裁剪行为。裁剪即封口——变化要重算命中边界。
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    if (_clipBehavior == value) return;
    _clipBehavior = value;
    markNeedsPaint();
    markHitBoundsDirty();
    markNeedsSemanticsUpdate();
  }

  Alignment? _resolvedAlignment;
  Alignment get _alignmentValue => _resolvedAlignment ??= alignment.resolve(textDirection);

  /// 是否有子越出本盒（paint 期是否需要真裁剪）。
  bool _hasVisualOverflow = false;

  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void performLayout() {
    _hasVisualOverflow = false;
    markHitBoundsDirty();

    final constraints = this.constraints;
    if (childCount == 0) {
      size = constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;
      return;
    }

    var hasNonPositionedChildren = false;
    var width = constraints.minWidth;
    var height = constraints.minHeight;

    final nonPositionedConstraints = switch (fit) {
      StackFit.loose => constraints.loosen(),
      StackFit.expand => BoxConstraints.tight(constraints.biggest),
      StackFit.passthrough => constraints,
    };

    // 第一遍：非定位子决定本盒尺寸。定位判定走 isPositionedForLayout——百分比
    // 声明此刻还没折算成像素，不能看像素字段。
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as ElStackParentData;
      if (!pd.isPositionedForLayout) {
        hasNonPositionedChildren = true;
        child.layout(nonPositionedConstraints, parentUsesSize: true);
        final childSize = child.size;
        width = width < childSize.width ? childSize.width : width;
        height = height < childSize.height ? childSize.height : height;
      }
      child = pd.nextSibling;
    }

    size = hasNonPositionedChildren
        ? constraints.constrain(Size(width, height))
        : (constraints.biggest.isFinite ? constraints.biggest : constraints.smallest);

    // 第二遍：非定位子按 alignment 落位；定位子先把百分比按已定尺寸折算成像素，
    // 再交给官方算法（它只读像素字段）。
    child = firstChild;
    while (child != null) {
      final pd = child.parentData! as ElStackParentData;
      if (!pd.isPositionedForLayout) {
        pd.offset = _alignmentValue.alongOffset(size - child.size as Offset) + pd.relativeOffset;
        if (pd.zIndex >= 0) {
          final childRect = pd.offset & child.size;
          _hasVisualOverflow =
              childRect.left < 0 ||
              childRect.top < 0 ||
              childRect.right > size.width ||
              childRect.bottom > size.height ||
              _hasVisualOverflow;
        }
      } else {
        pd.resolveDimensions(size);
        final overflows = RenderStack.layoutPositionedChild(child, pd, size, _alignmentValue);
        if (pd.zIndex >= 0) _hasVisualOverflow = overflows || _hasVisualOverflow;
      }
      child = pd.nextSibling;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (childCount == 0) {
      return constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;
    }
    final nonPositionedConstraints = switch (fit) {
      StackFit.loose => constraints.loosen(),
      StackFit.expand => BoxConstraints.tight(constraints.biggest),
      StackFit.passthrough => constraints,
    };
    var hasNonPositionedChildren = false;
    var width = constraints.minWidth;
    var height = constraints.minHeight;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as ElStackParentData;
      if (!pd.isPositionedForLayout) {
        hasNonPositionedChildren = true;
        final childSize = child.getDryLayout(nonPositionedConstraints);
        width = width < childSize.width ? childSize.width : width;
        height = height < childSize.height ? childSize.height : height;
      }
      child = pd.nextSibling;
    }
    if (!hasNonPositionedChildren) {
      return constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;
    }
    return constraints.constrain(Size(width, height));
  }

  // --- 溢出命中边界协议（ElOverflowHitBounds） --------------------------------

  @override
  Rect get selfHitRect => Offset.zero & size;

  /// 裁剪即封口：与 [paint] 是否真裁剪同源，避免"画不出却点得到"。
  @override
  bool get clipsHitBounds => clipBehavior != Clip.none && _hasVisualOverflow;

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as ElStackParentData;
      if (pd.zIndex >= 0) visitor(child, pd.offset);
      child = pd.nextSibling;
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_containsForHitTest(position)) {
      // CSS overflow: visible —— 画得出即点得到。不在自身盒内但在子溢出聚合
      // 边界内时，只可能命中溢出的子（本节点自身不 hitTestSelf）。裁剪节点
      // 边界已封口，此分支恒 miss。
      if (!hitBoundsContains(position)) return false;
      return hitTestChildren(result, position: position);
    }
    final hitChild = hitTestChildren(result, position: position);
    if (hitChild || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return hitChild;
  }

  bool _containsForHitTest(Offset position) => (Offset.zero & size).contains(position);

  /// 命中顺序 = 绘制逆序（上层优先），与 zIndex 一致。
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final ordered = _explicitPaintOrder;
    if (ordered == null && !hasHiddenStackChildren && !_overflowHitProxies.hasCandidates) {
      return defaultHitTestChildren(result, position: position);
    }

    var orderedIndex = ordered == null ? -1 : ordered.length - 1;
    var child = ordered == null ? lastChild : ordered[orderedIndex];
    while (child != null) {
      final currentChild = child;
      final pd = currentChild.parentData! as ElStackParentData;
      if (pd.zIndex < 0) {
        if (ordered == null) {
          child = pd.previousSibling;
        } else if (orderedIndex == 0) {
          child = null;
        } else {
          child = ordered[--orderedIndex];
        }
        continue;
      }
      final hit = result.addWithPaintOffset(
        offset: pd.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return currentChild.hitTest(result, position: transformed);
        },
      );
      if (hit) return true;
      if (_overflowHitProxies.hitTestForChild(result, position: position, directChild: currentChild)) return true;
      if (ordered == null) {
        child = pd.previousSibling;
      } else if (orderedIndex == 0) {
        child = null;
      } else {
        child = ordered[--orderedIndex];
      }
    }
    return false;
  }

  /// 按 Flutter 要求的绘制序提交语义子节点，保留平台遮挡与命中关系。
  /// 阅读遍历由语义 sortKey 和框架几何规则决定，不能把本遍历当作阅读序。
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) => visitSelectionChildrenInPaintOrder(visitor);

  /// 空白选区命中与绘制共用层序，避免先挂载的高层导航被后挂载的正文覆盖。
  @override
  void visitSelectionChildrenInPaintOrder(RenderObjectVisitor visitor) {
    final ordered = _explicitPaintOrder;
    if (ordered == null) {
      var child = firstChild;
      while (child != null) {
        final pd = child.parentData! as ElStackParentData;
        if (pd.zIndex >= 0) visitor(child);
        child = pd.nextSibling;
      }
    } else {
      for (final child in ordered) {
        if (isStackChildVisible(child)) visitor(child);
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_overflowHitProxies.syncForPaint()) markHitBoundsDirty();
    if (clipBehavior != Clip.none && _hasVisualOverflow) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintChildren,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      _paintChildren(context, offset);
    }
  }

  void _paintChildren(PaintingContext context, Offset offset) {
    final ordered = _explicitPaintOrder;
    if (ordered == null) {
      var child = firstChild;
      while (child != null) {
        final pd = child.parentData! as ElStackParentData;
        if (pd.zIndex >= 0) context.paintChild(child, pd.offset + offset);
        child = pd.nextSibling;
      }
      return;
    }
    for (final child in ordered) {
      final pd = child.parentData! as ElStackParentData;
      if (pd.zIndex < 0) continue;
      context.paintChild(child, pd.offset + offset);
    }
  }

  @override
  bool paintsChild(RenderBox child) {
    assert(identical(child.parent, this));
    return isStackChildVisible(child);
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final pd = child.parentData! as ElStackParentData;
    transform.translateByDouble(pd.offset.dx, pd.offset.dy, 0.0, 1.0);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    switch (clipBehavior) {
      case Clip.none:
        return null;
      case Clip.hardEdge:
      case Clip.antiAlias:
      case Clip.antiAliasWithSaveLayer:
        return _hasVisualOverflow ? Offset.zero & size : null;
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _computeIntrinsic((child) => child.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) => _computeIntrinsic((child) => child.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) => _computeIntrinsic((child) => child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _computeIntrinsic((child) => child.getMaxIntrinsicHeight(width));

  /// 内在尺寸只由非定位子决定（定位子相对本盒摆放，不参与定尺）。
  double _computeIntrinsic(double Function(RenderBox child) measure) {
    var extent = 0.0;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as ElStackParentData;
      if (!pd.isPositionedForLayout) {
        final value = measure(child);
        extent = extent < value ? value : extent;
      }
      child = pd.nextSibling;
    }
    return extent;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    properties.add(EnumProperty<StackFit>('fit', fit));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior, defaultValue: Clip.none));
  }
}
