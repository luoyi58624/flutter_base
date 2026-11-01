import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'geometry/axis_geometry.dart';
import 'geometry/grid_geometry.dart';
import 'geometry/list_geometry.dart';

/// 普通布局从最近滚动宿主继承轴；该作用域不随滚动位置更新。
final class LayoutScrollScope extends InheritedWidget {
  /// 创建只承载方向的作用域。
  const LayoutScrollScope({super.key, required this.axis, required this.reverse, required super.child});

  /// 布局轴。
  final Axis axis;

  /// 宿主的主轴反转规则。
  final bool reverse;

  /// 读取当前布局方向。
  static LayoutScrollScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LayoutScrollScope>();
  @override
  bool updateShouldNotify(LayoutScrollScope oldWidget) => axis != oldWidget.axis || reverse != oldWidget.reverse;
}

/// 段宿主与视口之间的挂载协议，不暴露滚动 State。
abstract interface class LayoutViewBinding {
  /// 段实际布局轴。
  Axis get axis;

  /// 段内继承的滚动反向规则。
  bool get reverse;

  /// 当前布局 View 的 Element。
  LayoutViewElement? get element;

  /// View 接入内容槽。
  void attach(LayoutViewElement element);

  /// View 离开内容槽。
  void detach(LayoutViewElement element);

  /// 将条目 RenderBox 接入统一视口。
  void insertChild(RenderBox child, Object? slot);

  /// 在统一视口移动条目。
  void moveChild(RenderBox child, Object? oldSlot, Object? newSlot);

  /// 从统一视口移除条目。
  void removeChild(RenderBox child, Object? slot);

  /// View 转移宿主前仅撤销挂载映射，保留后代 Element。
  void releaseChildren(LayoutViewElement view);

  /// GlobalKey 转移后恢复本段映射和 RenderBox，保持业务 State。
  void restoreChildren(LayoutViewElement view, LayoutViewBinding previous);

  /// View 的 inherited 依赖更新后重建已挂载条目。
  void dependenciesChanged();

  /// GlobalKey 接管条目时同步清理视口映射。
  void forgetChild(Element child);
}

/// 只有滚动容器的直接内容槽才能提供的接入凭据。
abstract interface class LayoutViewSlot {
  /// 当前段的生命周期绑定。
  LayoutViewBinding get binding;
}

/// List/Grid 共用的内部 Widget 协议；公开面只导出具体 View。
abstract class LayoutView extends RenderObjectWidget {
  /// 创建布局 View。
  const LayoutView({super.key});

  /// 全量构造的条目；builder 模式为 null。
  List<Widget>? get layoutChildren;

  /// builder 模式的业务条目数量。
  int get layoutItemCount;

  /// builder 模式的条目构建器。
  IndexedWidgetBuilder? get layoutItemBuilder;

  /// 可选的业务 key 回查。
  ChildIndexGetter? get layoutFindChildIndex;

  /// builder 已挂载条目离开缓存窗口后是否保留。
  bool get layoutKeepAlive => false;

  /// 列表分隔项构建器。
  IndexedWidgetBuilder? get layoutSeparatorBuilder => null;

  /// 网格几何声明；列表为 null。
  GridLayoutGeometry? get gridGeometry => null;

  /// 列表几何声明；网格为 null。
  ListLayoutGeometry? get listGeometry => null;

  /// 是否需要滚动容器提供虚拟窗口。
  bool get isBuilder => layoutChildren == null;

  @override
  LayoutViewElement createElement() => LayoutViewElement(this);

  /// 同步段宿主几何，方向继承不订阅滚动位置。
  void configureRenderObject(BuildContext context, RenderLayoutView renderObject) {
    final element = context as LayoutViewElement;
    final scope = LayoutScrollScope.maybeOf(context);
    renderObject.configure(
      axis: element.binding?.axis ?? scope?.axis ?? Axis.vertical,
      reverse: false,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      grid: gridGeometry,
      list: listGeometry,
      hosted: element.binding != null,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLayoutView renderObject) =>
      configureRenderObject(context, renderObject);
}

/// 保留布局 View 的 Element 和 context，融合态条目仍由统一视口管理。
final class LayoutViewElement extends RenderObjectElement {
  /// 创建段 Element。
  LayoutViewElement(LayoutView super.widget);
  @override
  LayoutView get widget => super.widget as LayoutView;
  @override
  RenderLayoutView get renderObject => super.renderObject as RenderLayoutView;

  /// 当前滚动接入；独立全量布局时为 null。
  LayoutViewBinding? binding;
  bool _parentUpdating = false;
  List<Element> _children = [];
  final Set<Element> _hostedChildren = {};
  final Set<Element> _forgotten = {};

  void _checkHost() {
    final valid = !widget.isBuilder || binding != null;
    assert(valid, '${widget.runtimeType}.builder 必须直接放入 ElScrollView.children，不能隔着布局 Widget 或独立使用。');
    if (!valid) throw FlutterError('${widget.runtimeType}.builder 缺少 ElScrollView 直接内容槽。');
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    binding = newSlot is LayoutViewSlot ? newSlot.binding : null;
    _checkHost();
    _parentUpdating = true;
    super.mount(parent, newSlot);
    _parentUpdating = false;
    binding?.attach(this);
    if (binding == null) _rebuildChildren();
  }

  @override
  void detachRenderObject() {
    if (binding != null) {
      for (final child in _hostedChildren) {
        child.detachRenderObject();
      }
      binding!.releaseChildren(this);
    }
    super.detachRenderObject();
  }

  @override
  void attachRenderObject(Object? newSlot) {
    final previous = binding;
    final next = newSlot is LayoutViewSlot ? newSlot.binding : null;
    if (previous == null && next != null && _children.isNotEmpty) {
      // 接入滚动会增加条目作用域，先正常卸下原槽，GlobalKey 后代可由新槽接回。
      for (final child in _children) {
        if (!_forgotten.contains(child)) updateChild(child, null, null);
      }
      _children = [];
      _forgotten.clear();
    } else if (previous != null && next == null) {
      for (final child in _hostedChildren.toList()) {
        updateHostedChild(child, null, null);
      }
    }
    binding = next;
    _checkHost();
    super.attachRenderObject(newSlot);
    binding?.attach(this);
    if (previous != null && binding != null && !identical(previous, binding) && _hostedChildren.isNotEmpty) {
      binding!.restoreChildren(this, previous);
    }
    if (!identical(previous, binding)) {
      previous?.detach(this);
      widget.configureRenderObject(this, renderObject);
      if (binding == null) _rebuildChildren();
    }
  }

  @override
  void update(covariant LayoutView newWidget) {
    assert(!newWidget.isBuilder || binding != null, '${newWidget.runtimeType}.builder 必须直接放入 ElScrollView.children。');
    _parentUpdating = true;
    super.update(newWidget);
    _parentUpdating = false;
    _checkHost();
    if (binding == null) _rebuildChildren();
  }

  @override
  void performRebuild() {
    super.performRebuild();
    if (!_parentUpdating) binding?.dependenciesChanged();
  }

  void _rebuildChildren() {
    _children = updateChildren(_children, widget.layoutChildren!, forgottenChildren: _forgotten);
    _forgotten.clear();
  }

  /// 由滚动挂载器更新本段的一个条目，业务 context 和祖先链保持属于 View。
  Element? updateHostedChild(Element? child, Widget? next, Object? slot) {
    if (child != null) _hostedChildren.remove(child);
    final result = updateChild(child, next, slot);
    if (result != null) _hostedChildren.add(result);
    return result;
  }

  /// 更新融合态条目的槽，保持更新由真实父 Element 发起。
  void updateHostedSlot(Element child, Object slot) => updateSlotForChild(child, slot);

  @override
  void visitChildren(ElementVisitor visitor) {
    if (binding != null) {
      for (final child in _hostedChildren.toList(growable: false)) {
        visitor(child);
      }
    } else {
      for (final child in _children) {
        if (!_forgotten.contains(child)) visitor(child);
      }
    }
  }

  @override
  void forgetChild(Element child) {
    if (binding != null) {
      _hostedChildren.remove(child);
      binding!.forgetChild(child);
    } else {
      _forgotten.add(child);
    }
    super.forgetChild(child);
  }

  @override
  void unmount() {
    binding?.detach(this);
    super.unmount();
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    if (binding != null) {
      binding!.insertChild(child as RenderBox, slot);
      return;
    }
    final previous = (slot as IndexedSlot<Element?>).value?.renderObject as RenderBox?;
    renderObject.insert(child as RenderBox, after: previous);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    if (binding != null) {
      binding!.moveChild(child as RenderBox, oldSlot, newSlot);
      return;
    }
    final previous = (newSlot as IndexedSlot<Element?>).value?.renderObject as RenderBox?;
    renderObject.move(child as RenderBox, after: previous);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    if (binding != null) {
      binding!.removeChild(child as RenderBox, slot);
      return;
    }
    renderObject.remove(child as RenderBox);
  }
}

/// 独立布局条目的主轴顺序和物理偏移。
class LayoutParentData extends ContainerBoxParentData<RenderBox> {}

/// List/Grid 的段级 Render 宿主；融合时仅承载整体几何，不重复布局条目。
abstract class RenderLayoutView extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, LayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, LayoutParentData> {
  AxisGeometry _axis = const AxisGeometry(Axis.vertical);
  GridLayoutGeometry? _grid;
  ListLayoutGeometry? _list;
  bool _hosted = false;
  Float64List _listStarts = Float64List(0);

  /// 当前是否由 ScrollView 管理条目布局。
  bool get hosted => _hosted;

  /// 应用 View 的共享声明和方向。
  void configure({
    required Axis axis,
    required TextDirection textDirection,
    required bool reverse,
    required GridLayoutGeometry? grid,
    required ListLayoutGeometry? list,
    required bool hosted,
  }) {
    final changed =
        _axis.axis != axis ||
        _axis.textDirection != textDirection ||
        _axis.reverse != reverse ||
        _grid != grid ||
        _list != list ||
        _hosted != hosted;
    _axis = AxisGeometry(axis, textDirection: textDirection, reverse: reverse);
    _grid = grid;
    _list = list;
    _hosted = hosted;
    if (changed) markNeedsLayout();
  }

  /// 具体布局类型提供自己的 ParentData。
  LayoutParentData createParentData();
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! LayoutParentData) child.parentData = createParentData();
  }

  double _crossLimit(BoxConstraints value) => _axis.axis == Axis.vertical ? value.maxWidth : value.maxHeight;

  @override
  void performLayout() {
    if (_hosted) {
      size = constraints.biggest;
      return;
    }
    if (_grid != null) {
      _layoutGrid();
    } else {
      _layoutList();
    }
  }

  void _layoutGrid() {
    final grid = _grid!.resolve(axis: _axis.axis, crossExtent: _crossLimit(constraints), itemCount: childCount);
    final cell = grid.cellSize;
    final childConstraints = BoxConstraints.tight(cell);
    var child = firstChild;
    var index = 0;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final data = child.parentData! as LayoutParentData;
      data.offset = _axis.offset(
        grid.mainStart(index),
        grid.crossStart(index),
        mainExtent: grid.mainExtent,
        crossExtent: grid.crossExtent,
        childSize: cell,
      );
      child = data.nextSibling;
      index++;
    }
    size = constraints.constrain(grid.size);
  }

  void _layoutList() {
    final list = _list!;
    final crossLimit = _crossLimit(constraints);
    final stretch = list.crossAxisAlignment == CrossAxisAlignment.stretch && crossLimit.isFinite;
    final natural = _axis.axis == Axis.vertical
        ? BoxConstraints(minWidth: stretch ? crossLimit : 0, maxWidth: crossLimit)
        : BoxConstraints(minHeight: stretch ? crossLimit : 0, maxHeight: crossLimit);
    if (!list.fixedSize && _listStarts.length != childCount) _listStarts = Float64List(childCount);
    if (list.fixedSize && _listStarts.isNotEmpty) _listStarts = Float64List(0);
    var main = 0.0;
    var cross = 0.0;
    double? fixed;
    var child = firstChild;
    var index = 0;
    while (child != null) {
      var value = natural;
      if (fixed != null) {
        value = _axis.axis == Axis.vertical
            ? natural.copyWith(minHeight: fixed, maxHeight: fixed)
            : natural.copyWith(minWidth: fixed, maxWidth: fixed);
      }
      child.layout(value, parentUsesSize: true);
      final extent = _axis.mainOf(child.size);
      if (list.fixedSize) fixed ??= extent;
      if (!list.fixedSize) _listStarts[index] = main;
      main += extent + (index + 1 < childCount ? list.gap : 0);
      cross = math.max(cross, _axis.crossOf(child.size));
      child = (child.parentData! as LayoutParentData).nextSibling;
      index++;
    }
    final fixedLayout = list.fixedSize ? FixedListGeometry(childCount, fixed ?? 0) : null;
    if (fixedLayout != null) main = fixedLayout.extentWithGap(list.gap);
    if (crossLimit.isFinite) cross = crossLimit;
    size = constraints.constrain(_axis.size(main, cross));
    child = firstChild;
    index = 0;
    while (child != null) {
      final data = child.parentData! as LayoutParentData;
      final start = fixedLayout != null ? fixedLayout.offsetOf(index) + index * list.gap : _listStarts[index];
      data.offset = _axis.offset(
        start,
        list.crossStart(cross, _axis.crossOf(child.size)),
        mainExtent: main,
        crossExtent: cross,
        childSize: child.size,
      );
      child = data.nextSibling;
      index++;
    }
  }

  double _intrinsic(bool width, bool minimum, double extent) {
    if (_hosted) return 0;
    final mainAxis = width == (_axis.axis == Axis.horizontal);
    if (_grid != null) {
      if (mainAxis) return _grid!.resolve(axis: _axis.axis, crossExtent: extent, itemCount: childCount).mainExtent;
      final grid = _grid!;
      final count = grid.crossAxisCount ?? 1;
      final gap = _axis.axis == Axis.vertical ? grid.columnGap : grid.rowGap;
      final double cell;
      if (grid.itemWidth != null) {
        cell = _axis.axis == Axis.vertical ? grid.itemWidth! : grid.itemWidth! / grid.aspectRatio;
      } else if (grid.mainAxisExtent != null) {
        cell = _axis.axis == Axis.vertical
            ? grid.mainAxisExtent! * grid.aspectRatio
            : grid.mainAxisExtent! / grid.aspectRatio;
      } else {
        cell = grid.minCrossAxisExtent ?? grid.maxCrossAxisExtent ?? 0;
      }
      return count * cell + math.max(0, count - 1) * gap;
    }
    double result = 0;
    var child = firstChild;
    while (child != null) {
      final value = width
          ? minimum
                ? child.getMinIntrinsicWidth(extent)
                : child.getMaxIntrinsicWidth(extent)
          : minimum
          ? child.getMinIntrinsicHeight(extent)
          : child.getMaxIntrinsicHeight(extent);
      if (mainAxis && _list!.fixedSize) return ListLayoutGeometry.fixedExtent(childCount, value, _list!.gap);
      result = mainAxis ? result + value : math.max(result, value);
      child = (child.parentData! as LayoutParentData).nextSibling;
    }
    return result + (mainAxis ? math.max(0, childCount - 1) * _list!.gap : 0);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsic(true, true, height);
  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsic(true, false, height);
  @override
  double computeMinIntrinsicHeight(double width) => _intrinsic(false, true, width);
  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsic(false, false, width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_hosted) return constraints.biggest;
    if (_grid != null) {
      return constraints.constrain(
        _grid!.resolve(axis: _axis.axis, crossExtent: _crossLimit(constraints), itemCount: childCount).size,
      );
    }
    final list = _list!;
    final crossLimit = _crossLimit(constraints);
    final stretch = crossLimit.isFinite && list.crossAxisAlignment == CrossAxisAlignment.stretch;
    final childConstraints = _axis.axis == Axis.vertical
        ? BoxConstraints(minWidth: stretch ? crossLimit : 0, maxWidth: crossLimit)
        : BoxConstraints(minHeight: stretch ? crossLimit : 0, maxHeight: crossLimit);
    if (list.fixedSize && crossLimit.isFinite) {
      final extent = firstChild == null ? 0.0 : _axis.mainOf(firstChild!.getDryLayout(childConstraints));
      return constraints.constrain(
        _axis.size(ListLayoutGeometry.fixedExtent(childCount, extent, list.gap), crossLimit),
      );
    }
    var main = 0.0;
    var cross = 0.0;
    var count = 0;
    double? fixed;
    var child = firstChild;
    while (child != null) {
      final childSize = child.getDryLayout(childConstraints);
      fixed ??= _axis.mainOf(childSize);
      main += list.fixedSize ? fixed : _axis.mainOf(childSize);
      cross = math.max(cross, _axis.crossOf(childSize));
      count++;
      child = (child.parentData! as LayoutParentData).nextSibling;
    }
    return constraints.constrain(
      _axis.size(main + math.max(0, count - 1) * list.gap, crossLimit.isFinite ? crossLimit : cross),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      !_hosted && defaultHitTestChildren(result, position: position);
  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hosted) defaultPaint(context, offset);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as LayoutParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}
