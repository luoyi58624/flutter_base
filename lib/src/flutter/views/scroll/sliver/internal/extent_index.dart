import 'dart:math' as math;

/// 把条目类型映射为从零开始的分组编号；[types] 为空表示全部同组。
List<int> extentGroups(int count, List<Object?> types) {
  if (types.isEmpty) return List<int>.filled(count, 0);
  final groups = <Object?, int>{};
  return [for (final type in types) groups.putIfAbsent(type, () => groups.length)];
}

/// 实测尺寸、分组估值与前缀和索引：未测条目按同组首个实测值估算。
///
/// 单一分组时未知尺寸只用一个基值表示，首次实测不扫描也不重建；
/// 多分组时用树状数组保存每项当前取值。
class ExtentIndex {
  ExtentIndex(List<int> groups) : _groups = groups, _sizes = List<double?>.filled(groups.length, null) {
    _uniform = groups.isEmpty || groups.every((group) => group == groups.first);
    if (_uniform) {
      _tree = List.filled(length + 1, 0.0);
      _known = List.filled(length + 1, 0);
    } else {
      _values = List.filled(length, _fallback);
      _rebuildTree();
    }
  }

  static const double _fallback = 100;

  final List<int> _groups;
  final List<double?> _sizes;
  final Map<int, double> _estimates = {};
  late final bool _uniform;
  List<double> _values = const [];
  List<double> _tree = const [];
  List<int> _known = const [];
  double _uniformEstimate = _fallback;

  int get length => _sizes.length;

  double get total => prefix(length);

  /// 条目当前取值：已测为实测尺寸，未测为所在分组的估值。
  double extentAt(int index) => _uniform ? _sizes[index] ?? _uniformEstimate : _values[index];

  void _rebuildTree() {
    _tree = List.filled(length + 1, 0.0);
    // 每个节点只向父节点累加一次，整体建树保持 O(n)。
    for (var i = 1; i <= length; i++) {
      _tree[i] += _values[i - 1];
      final parent = i + (i & -i);
      if (parent <= length) _tree[parent] += _tree[i];
    }
  }

  void _add(int index, double delta, [int knownDelta = 0]) {
    for (var i = index + 1; i < _tree.length; i += i & -i) {
      _tree[i] += delta;
      if (knownDelta != 0) _known[i] += knownDelta;
    }
  }

  /// 前 [end] 项的尺寸和，不含间距。
  double prefix(int end) {
    var sum = 0.0;
    if (!_uniform) {
      for (var i = end; i > 0; i -= i & -i) {
        sum += _tree[i];
      }
      return sum;
    }
    var known = 0;
    for (var i = end; i > 0; i -= i & -i) {
      sum += _tree[i];
      known += _known[i];
    }
    return sum + (end - known) * _uniformEstimate;
  }

  /// 主轴坐标 [offset] 所在条目，条目后的 [spacing] 归它所有。
  ///
  /// 多个零尺寸条目共用同一起点时默认取最后一个；[preferFirst] 取最早的一个，
  /// 使窗口起点上的零尺寸条目仍被布局，内容更新后能够展开。
  int indexAt(double offset, {double spacing = 0, bool preferFirst = false}) {
    if (length == 0) return 0;
    var index = 0;
    var sum = 0.0;
    var known = 0;
    var bit = 1;
    while (bit * 2 <= length) {
      bit *= 2;
    }
    while (bit != 0) {
      final next = index + bit;
      if (next <= length) {
        final nextKnown = _uniform ? known + _known[next] : 0;
        final position = sum + _tree[next] + next * spacing + (_uniform ? (next - nextKnown) * _uniformEstimate : 0);
        if (preferFirst ? position < offset : position <= offset) {
          index = next;
          sum += _tree[next];
          known = nextKnown;
        }
      }
      bit ~/= 2;
    }
    if (preferFirst && index + 1 < length && prefix(index + 1) + (index + 1) * spacing == offset) index++;
    return math.min(index, length - 1);
  }

  /// 写入实测尺寸，返回任一条目的取值是否因此改变。
  bool measure(int index, double extent) {
    if (!extent.isFinite || extent < 0) throw StateError('条目布局尺寸必须是有限的非负数。');
    final previous = _sizes[index];
    if (previous == extent) return false;
    final group = _groups[index];
    // 零尺寸只属于当前条目，不能让同组的未知条目也被估成零。
    final firstOfGroup = extent > 0 && !_estimates.containsKey(group);
    if (firstOfGroup) _estimates[group] = extent;
    _sizes[index] = extent;
    if (_uniform) {
      final changed = (previous ?? _uniformEstimate) != extent;
      if (firstOfGroup) _uniformEstimate = extent;
      _add(index, extent - (previous ?? 0), previous == null ? 1 : 0);
      return changed;
    }
    if (firstOfGroup) {
      var changed = _values[index] != extent;
      _values[index] = extent;
      for (var i = 0; i < length; i++) {
        if (_sizes[i] == null && _groups[i] == group && _values[i] != extent) {
          changed = true;
          _values[i] = extent;
        }
      }
      if (changed) _rebuildTree();
      return changed;
    }
    if (_values[index] == extent) return false;
    _add(index, extent - _values[index]);
    _values[index] = extent;
    return true;
  }
}
