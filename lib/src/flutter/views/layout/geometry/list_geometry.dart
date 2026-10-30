import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart';

/// 列表共用的间距、固定尺寸与交叉轴对齐声明。
final class ListLayoutGeometry {
  /// 创建列表几何规则。
  const ListLayoutGeometry({this.gap = 0, this.fixedSize = false, this.crossAxisAlignment = CrossAxisAlignment.stretch})
    : assert(gap >= 0 && gap < double.infinity),
      assert(crossAxisAlignment != CrossAxisAlignment.baseline);

  /// 相邻条目的主轴间距。
  final double gap;

  /// 是否按真实首条固定主轴尺寸。
  final bool fixedSize;

  /// 条目的交叉轴对齐方式。
  final CrossAxisAlignment crossAxisAlignment;

  /// 固定尺寸列表的完整主轴范围，不创建逐项位置数组。
  static double fixedExtent(int count, double itemExtent, double gap) =>
      FixedListGeometry(count, itemExtent).extentWithGap(gap);

  /// 条目在交叉轴的起点；start/end 的 RTL 转换由 AxisGeometry 统一处理。
  double crossStart(double available, double childExtent) => switch (crossAxisAlignment) {
    CrossAxisAlignment.center => (available - childExtent) / 2,
    CrossAxisAlignment.end => available - childExtent,
    _ => 0,
  };

  @override
  bool operator ==(Object other) =>
      other is ListLayoutGeometry &&
      gap == other.gap &&
      fixedSize == other.fixedSize &&
      crossAxisAlignment == other.crossAxisAlignment;
  @override
  int get hashCode => Object.hash(gap, fixedSize, crossAxisAlignment);
}

/// 固定列表的算术位置索引，独立布局与滚动布局使用同一个常数存储模型。
final class FixedListGeometry {
  /// count 是包含分隔项的槽数；没有分隔项时 stride 为 1。
  const FixedListGeometry(this.count, this.itemExtent, {this.separatorExtent = 0, this.stride = 1})
    : assert(count >= 0),
      assert(stride == 1 || stride == 2);

  /// 包含分隔项的条目数。
  final int count;

  /// 正文主轴尺寸。
  final double itemExtent;

  /// 分隔项主轴尺寸。
  final double separatorExtent;

  /// 相邻正文之间的槽步长。
  final int stride;

  /// 正文的数量。
  int get itemCount => stride == 1 ? count : (count + 1) ~/ 2;

  /// 分隔项的数量。
  int get separatorCount => stride == 1 ? 0 : count ~/ 2;

  /// 全部条目的纯尺寸总和，不含间距。
  double get totalExtent => itemCount * itemExtent + separatorCount * separatorExtent;

  /// 加上间距后的完整主轴尺寸。
  double extentWithGap(double gap) => count == 0 ? 0 : totalExtent + (count - 1) * gap;

  /// 指定槽的固定主轴尺寸。
  double extentOf(int index) => stride == 2 && index.isOdd ? separatorExtent : itemExtent;

  /// 指定槽之前的纯尺寸前缀。
  double offsetOf(int index) {
    final end = index.clamp(0, count);
    return stride == 1 ? end * itemExtent : ((end + 1) ~/ 2) * itemExtent + (end ~/ 2) * separatorExtent;
  }

  /// 首个末端越过指定位置的槽，间距归属后一个槽。
  int indexAt(double position, double gap) {
    if (position < 0 || count == 0) return 0;
    if (position >= totalExtent + (count - 1) * gap) return count;
    if (stride == 1) {
      final step = itemExtent + gap;
      if (step <= 0) return count;
      var index = ((position + precisionErrorTolerance) / step).floor();
      if (position - index * step >= itemExtent - precisionErrorTolerance) index++;
      return index.clamp(0, count);
    }
    final step = itemExtent + separatorExtent + gap * 2;
    if (step <= 0) return count;
    final pair = (position / step).floor();
    final local = position + precisionErrorTolerance - pair * step;
    return (pair * 2 +
            (local < itemExtent
                ? 0
                : local < itemExtent + gap + separatorExtent
                ? 1
                : 2))
        .clamp(0, count);
  }

  /// 首个起点不早于指定位置的槽，保留零尺寸条目的边界身份。
  int firstStartAt(double position, double gap) {
    if (position <= 0 || count == 0) return 0;
    if (stride == 1) {
      final step = itemExtent + gap;
      return step <= 0 ? count : ((position - precisionErrorTolerance) / step).ceil().clamp(0, count);
    }
    final step = itemExtent + separatorExtent + gap * 2;
    if (step <= 0) return count;
    final pair = ((position - precisionErrorTolerance) / step).floor();
    final start = pair * step;
    return (pair * 2 +
            (position <= start + precisionErrorTolerance
                ? 0
                : position <= start + itemExtent + gap + precisionErrorTolerance
                ? 1
                : 2))
        .clamp(0, count);
  }
}
