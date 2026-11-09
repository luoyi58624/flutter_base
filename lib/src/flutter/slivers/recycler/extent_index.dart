part of 'sliver_recycler.dart';

// Sliver 内部的实测尺寸、类型估值与前缀和索引。
class _ExtentIndex {
  _ExtentIndex.groups(List<int> types) {
    _sizes = List<double?>.filled(types.length, null, growable: true);
    _types = types;
    _values = List.filled(types.length, 100.0);
    _rebuildTree();
  }

  void invalidateGroups(int start, int count) {
    final end = math.min(length, start + count);
    for (var index = start; index < end; index++) {
      _sizes[index] = null;
      final estimate = _estimates[_types[index]] ?? 100.0;
      _add(index, estimate - _values[index]);
      _values[index] = estimate;
    }
  }

  late List<double?> _sizes;
  List<int> _types = [];
  List<double> _values = [];
  List<double> _tree = [];
  final Map<int, double> _estimates = {};

  int get length => _sizes.length;
  double get total => prefix(length);
  int typeAt(int index) {
    return _types[index];
  }

  double extentAt(int index) {
    return _values[index];
  }

  bool hasTypeEstimate(int type) => _estimates.containsKey(type);

  void _rebuildTree() {
    _tree = List.filled(length + 1, 0.0);
    // 每个节点只向父节点累加一次，整体建树保持 O(n)。
    for (var i = 1; i <= length; i++) {
      _tree[i] += _values[i - 1];
      final parent = i + (i & -i);
      if (parent <= length) _tree[parent] += _tree[i];
    }
  }

  void _add(int index, double delta) {
    if (delta == 0) return;
    for (var i = index + 1; i < _tree.length; i += i & -i) {
      _tree[i] += delta;
    }
  }

  double prefix(int end) {
    var sum = 0.0;
    for (var i = end; i > 0; i -= i & -i) {
      sum += _tree[i];
    }
    return sum;
  }

  int indexAt(double offset) {
    if (length == 0) return 0;
    var index = 0;
    var sum = 0.0;
    var bit = 1;
    while (bit * 2 <= length) {
      bit *= 2;
    }
    while (bit != 0) {
      final next = index + bit;
      if (next <= length && sum + _tree[next] <= offset) {
        index = next;
        sum += _tree[next];
      }
      bit ~/= 2;
    }
    return math.min(index, length - 1);
  }

  bool measure(int index, double extent) {
    if (!extent.isFinite || extent < 0) throw StateError('条目布局尺寸必须是有限的非负数。');
    if (_sizes[index] == extent) return false;
    final type = _types[index];
    // 零尺寸只属于当前条目，不能让同类型的未知条目也被估成零。
    final firstOfType = extent > 0 && !_estimates.containsKey(type);
    if (firstOfType) _estimates[type] = extent;
    _sizes[index] = extent;
    if (firstOfType) {
      var changed = _values[index] != extent;
      _values[index] = extent;
      for (var i = 0; i < length; i++) {
        if (_sizes[i] == null && _types[i] == type) {
          changed |= _values[i] != extent;
          _values[i] = extent;
        }
      }
      if (changed) _rebuildTree();
      return changed;
    } else if (_values[index] != extent) {
      _add(index, extent - _values[index]);
      _values[index] = extent;
      return true;
    }
    return false;
  }
}
