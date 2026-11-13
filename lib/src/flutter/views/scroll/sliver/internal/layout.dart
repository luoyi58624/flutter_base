import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// 布局规格值对象：相等时沿用已有布局与实测，不等时由渲染器重建布局。
@immutable
abstract class SliverLayoutSpec {
  const SliverLayoutSpec();

  SliverLayout createLayout();
}

/// 自然尺寸布局算法：只管几何，不认识 Widget 与 Element。
///
/// 渲染器按序号升序逐个 [measure]，网格依赖这一顺序在行尾提交行高。
abstract class SliverLayout {
  int _count = -1;
  Axis? _axis;
  double? _crossExtent;
  List<Object?> _types = const [];

  int get count => _count;

  /// 条目数、轴向、交叉轴尺寸或类型序列变化时重建索引，返回是否重建。
  ///
  /// [types] 为 null 表示类型序列与上次一致；空列表表示全部同类型。
  bool sync(int count, List<Object?>? types, SliverConstraints constraints, {bool force = false}) {
    final changed =
        force ||
        _count != count ||
        _axis != constraints.axis ||
        _crossExtent != constraints.crossAxisExtent ||
        (types != null && !listEquals(_types, types));
    if (types != null) _types = types;
    if (!changed) return false;
    _count = count;
    _axis = constraints.axis;
    _crossExtent = constraints.crossAxisExtent;
    rebuild(count, _types, constraints);
    return true;
  }

  @protected
  void rebuild(int count, List<Object?> types, SliverConstraints constraints);

  /// 位置是否依赖实测；固定格尺寸的布局无需先测量再定窗口。
  bool get usesEstimates => true;

  /// 单元按索引连续排列，实测只改变后续位置而不会重排单元，可用游标推进窗口。
  bool get orderedPositions => false;

  BoxConstraints childConstraints(SliverConstraints constraints);

  double get total;

  double startOf(int index);

  /// 条目在交叉轴上的物理偏移。
  double crossOf(int index, Size childSize, SliverConstraints constraints);

  /// 与主轴区间 [start, end) 相交的条目，升序；网格按整行返回。
  List<int> indicesIn(double start, double end);

  /// 必须一起测量的最小条目区间 [first, end)，网格为整行。
  (int, int) unitOf(int index) => (index, index + 1);

  /// 写入实测主轴尺寸，返回已有位置是否改变，供渲染器修正锚点。
  bool measure(int index, double extent);

  /// 没有真实可见条目时按估值推算锚点；返回 null 表示保持输入像素。
  int? anchorAt(double pixels) => null;

  /// 开始记录本轮可见条目，布局可据此保存下一轮补测的逐列参考位置。
  void beginRetain() {}

  /// 本轮实际绘制的条目，布局据此记录下轮补测的参考位置。
  void retain(int index) {}
}

/// 交叉轴轨道声明：固定数量，或由目标尺寸按可用空间推算。
@immutable
class SliverTracks {
  const SliverTracks({this.count, this.itemExtent, this.minExtent, this.maxExtent, this.spacing = 0})
    : assert(count == null || count > 0),
      assert(itemExtent == null || itemExtent > 0 && itemExtent < double.infinity),
      assert(minExtent == null || minExtent > 0 && minExtent < double.infinity),
      assert(maxExtent == null || maxExtent > 0 && maxExtent < double.infinity),
      assert(spacing >= 0 && spacing < double.infinity),
      assert(
        (count == null ? 0 : 1) +
                (itemExtent == null ? 0 : 1) +
                (minExtent == null ? 0 : 1) +
                (maxExtent == null ? 0 : 1) ==
            1,
        'crossAxisCount、itemWidth、minCrossAxisExtent、maxCrossAxisExtent 必须且只能指定一个。',
      );

  final int? count;
  final double? itemExtent;
  final double? minExtent;
  final double? maxExtent;
  final double spacing;

  /// 轨道数；[itemExtent] 覆盖声明值，供横向网格按宽高比换算后的目标使用。
  int resolve(double crossExtent, {double? itemExtent}) {
    if (count case final count?) return count;
    final cross = math.max(0.0, crossExtent);
    // 预估尺寸只决定轨道数，间距在数量确定后扣除。
    if (itemExtent ?? this.itemExtent case final target?) return math.max(1, (cross / target).floor());
    if (minExtent case final min?) return math.max(1, ((cross + spacing) / (min + spacing)).floor());
    return math.max(1, ((cross + spacing) / (maxExtent! + spacing)).ceil());
  }

  /// 扣除间距后均分的单轨尺寸。
  double extentOf(double crossExtent, int tracks) => math.max(0.0, (crossExtent - (tracks - 1) * spacing) / tracks);

  /// 第 [track] 条轨道的物理交叉轴偏移。
  double offsetOf(int track, double extent, SliverConstraints constraints) {
    final cross = track * (extent + spacing);
    return axisDirectionIsReversed(constraints.crossAxisDirection)
        ? constraints.crossAxisExtent - cross - extent
        : cross;
  }

  @override
  bool operator ==(Object other) =>
      other is SliverTracks &&
      count == other.count &&
      itemExtent == other.itemExtent &&
      minExtent == other.minExtent &&
      maxExtent == other.maxExtent &&
      spacing == other.spacing;

  @override
  int get hashCode => Object.hash(count, itemExtent, minExtent, maxExtent, spacing);
}
