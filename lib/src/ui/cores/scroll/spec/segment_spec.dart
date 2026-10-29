import 'package:flutter/widgets.dart';

import '../../layout/stack/stack_view.dart';
import '../../layout/layout_view.dart';
import '../../layout/geometry/grid_geometry.dart';
import '../../layout/geometry/list_geometry.dart';

/// 段协议（计划 §3.4）：把 `ElScrollView.children` 解构成的**纯数据**
/// 段描述，供段计划（坐标换算）、diff（度量保留）与唯一滚动管线消费。
/// 本层不做任何渲染，也不 import 滚动实现——保持纯数据可单测。
///
/// 段与真实布局 View 的对应关系见 `segment_resolver.dart`。

/// 段的 item 来源：物化列表或懒 builder。
sealed class SegmentItemSource {
  const SegmentItemSource();

  /// item 总数。
  int get itemCount;

  /// 取第 [index]（段内局部序）个 item widget。
  Widget itemAt(BuildContext context, int index);
}

/// 物化来源：全量布局的 children 列表实例齐备。
/// 段内 diff 走 identity / keyed 对比，度量按身份保留。
final class MaterializedItemSource extends SegmentItemSource {
  /// 创建物化来源。壳 children 浅拷贝定格：调用方原地改同一 List 实例的
  /// 形态（builder 页常见）下，diff 基线快照必须留住旧序列，否则新旧两侧
  /// 看到同一份已改内容、结构变化不可见（锚点/Fenwick 不 remap 即漂移）。
  MaterializedItemSource(List<Widget> children) : children = List<Widget>.of(children, growable: false);

  /// 源 children（构造期定格的副本）。
  final List<Widget> children;

  @override
  int get itemCount => children.length;

  @override
  Widget itemAt(BuildContext context, int index) => children[index];
}

/// 懒 builder 来源：index 即身份，itemCount
/// 变化按尾部 splice 处理；[findChildIndex] 是官方 keyed 通道（M5 接入）。
final class BuilderItemSource extends SegmentItemSource {
  /// 创建 builder 来源。
  const BuilderItemSource({required this.itemCount, required this.builder, this.findChildIndex});

  @override
  final int itemCount;

  /// 按业务索引构建条目，结果必须是非空 Widget。
  final IndexedWidgetBuilder builder;

  /// 官方 `findChildIndexCallback`：key → 新 index，供已挂载行跨 splice
  /// 迁移度量（M5 消费；M1 仅承载）。
  final ChildIndexGetter? findChildIndex;

  @override
  Widget itemAt(BuildContext context, int index) => builder(context, index);
}

/// 固定尺寸样本，只保存真实首条的常数规模测量状态。
final class FixedSizeSample {
  /// 首测前为空。
  double? extent;

  /// 测量使用的约束。
  BoxConstraints? measuredConstraints;

  /// 测量对应的环境代际。
  int? measuredGeneration;

  /// 像素对齐对应的设备比例。
  double? measuredDevicePixelRatio;
}

/// 固定尺寸列表只测首条正文及首个分隔项，之后直接求最终范围。
final class FixedSizeSpec {
  /// 创建固定尺寸声明；有分隔项时步长为 2。
  FixedSizeSpec({this.itemStride = 1});

  /// 相邻正文在扁平索引中的步长。
  final int itemStride;

  /// 首条正文的真实测量。
  final FixedSizeSample item = FixedSizeSample();

  /// 首个分隔项的真实测量。
  final FixedSizeSample separator = FixedSizeSample();

  /// 首条正文尺寸。
  double? get extent => item.extent;
  set extent(double? value) => item.extent = value;

  /// 首个分隔项尺寸。
  double? get separatorExtent => separator.extent;
  set separatorExtent(double? value) => separator.extent = value;

  /// 指定扁平条目的固定尺寸。
  double? extentAt(int index) => itemStride == 2 && index.isOdd ? separator.extent : item.extent;
}

/// 一段连续同类内容的纯数据描述。
sealed class SegmentSpec {
  const SegmentSpec();

  /// 真实布局 View；普通散成员为空。
  LayoutView? get view => null;

  /// 是否全量常驻。
  bool get resident => this is StaticSegment;

  /// 本段展开后的扁平 item 数。
  int get itemCount;

  /// 取段内第 [localIndex] 个 item。
  Widget itemAt(BuildContext context, int localIndex);

  /// 段对齐键：跨 build 判定"新旧段序列如何配对"（前后缀收缩用）。
  /// 只含**结构语义键**——static 段是成员 identity（runtimeType+key），
  /// grid 段是行几何；itemCount 与 builder 闭包身份**不入键**（内容变化由
  /// 段内 diff 处理，禁按实例身份比较——自激环红线）。
  List<Object?> get alignmentKey;
}

/// 普通 box 成员的常驻段；不拆解内部布局，也不因滚动卸载。
final class StaticSegment extends SegmentSpec {
  /// 创建散 child 段。
  StaticSegment(this.child);

  /// 原成员 widget（原样挂载，保 key 与语义）。
  final Widget child;

  bool? _mountedPositioned;

  /// 真实 ParentData 已挂载时以其定位角色为准，初次挂载前仅识别直接声明。
  bool get isFixedDeclaration =>
      _mountedPositioned ??
      switch (child) {
        ElPositioned(:final left, :final top, :final right, :final bottom, :final width, :final height) =>
          left != null || top != null || right != null || bottom != null || width != null || height != null,
        Positioned() =>
          (child as Positioned).left != null ||
              (child as Positioned).top != null ||
              (child as Positioned).right != null ||
              (child as Positioned).bottom != null ||
              (child as Positioned).width != null ||
              (child as Positioned).height != null,
        _ => false,
      };

  /// 由滚动布局回报直接成员的真实角色；返回角色是否变化。
  bool updateMountedPositioned(bool value) {
    final changed = isFixedDeclaration != value;
    _mountedPositioned = value;
    return changed;
  }

  @override
  int get itemCount => 1;

  @override
  Widget itemAt(BuildContext context, int localIndex) {
    assert(localIndex == 0);
    return child;
  }

  @override
  List<Object?> get alignmentKey => <Object?>[StaticSegment, child.runtimeType, child.key];
}

/// 沿主轴排列的列表段，普通与 builder 只改变挂载策略。
final class LinearSegment extends SegmentSpec {
  /// 创建列表段。
  const LinearSegment({
    required this.source,
    this.fixed,
    this.key,
    this.view,
    this.resident = false,
    this.geometry = const ListLayoutGeometry(),
  });

  /// 条目来源。
  final SegmentItemSource source;

  /// 按真实首条测量的固定尺寸声明。
  final FixedSizeSpec? fixed;

  /// 段身份。
  final Key? key;

  /// 共用列表排列声明。
  final ListLayoutGeometry geometry;
  @override
  final LayoutView? view;
  @override
  final bool resident;

  /// 首条正文的固定主轴尺寸。
  double? get resolvedFixedExtent => fixed?.extent;

  /// 指定扁平条目的固定尺寸。
  double? fixedExtentAt(int localIndex) => fixed?.extentAt(localIndex);
  @override
  int get itemCount => source.itemCount;
  @override
  Widget itemAt(BuildContext context, int localIndex) => source.itemAt(context, localIndex);
  @override
  List<Object?> get alignmentKey => <Object?>[LinearSegment, key, geometry, fixed?.itemStride];
}

/// 使用共享几何内核的网格段。
final class GridSegment extends SegmentSpec {
  /// 创建网格段。
  const GridSegment({
    required this.source,
    required this.geometry,
    this.axis = Axis.vertical,
    this.view,
    this.resident = false,
  });

  /// 条目来源。
  final SegmentItemSource source;

  /// 共享网格几何声明。
  final GridLayoutGeometry geometry;

  /// 实际布局轴。
  final Axis axis;
  @override
  final LayoutView? view;
  @override
  final bool resident;
  @override
  int get itemCount => source.itemCount;
  @override
  Widget itemAt(BuildContext context, int localIndex) => source.itemAt(context, localIndex);

  /// 在有限交叉轴上一次解析最终几何。
  ResolvedGridGeometry resolve(double crossExtent) =>
      geometry.resolve(axis: axis, crossExtent: crossExtent, itemCount: itemCount);

  /// 主轴间距。
  double get mainAxisSpacing => axis == Axis.vertical ? geometry.rowGap : geometry.columnGap;

  /// 交叉轴间距。
  double get crossAxisSpacing => axis == Axis.vertical ? geometry.columnGap : geometry.rowGap;
  @override
  List<Object?> get alignmentKey => <Object?>[GridSegment, view?.key, geometry, axis];
}
