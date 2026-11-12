part of '../sliver.dart';

// Sliver 内部的实测尺寸、类型估值与前缀和索引。
class _ExtentIndex {
  _ExtentIndex.groups(List<int> types) {
    _sizes = List<double?>.filled(types.length, null, growable: true);
    _types = types;
    _uniform = types.isEmpty || types.every((type) => type == types.first);
    if (_uniform) {
      _tree = List.filled(types.length + 1, 0.0);
      _known = List.filled(types.length + 1, 0);
    } else {
      _values = List.filled(types.length, 100.0);
      _rebuildTree();
    }
  }

  void invalidateGroups(int start, int count) {
    final end = math.min(length, start + count);
    for (var index = start; index < end; index++) {
      if (_uniform) {
        final size = _sizes[index];
        if (size != null) _measureUniform(index, -size, -1);
        _sizes[index] = null;
        continue;
      }
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
  late final bool _uniform;
  List<int> _known = [];
  double _uniformEstimate = 100;

  // 同一类型的未知高度用一个基值表示；首次实测无需扫描全部未知条目或重建索引。
  void _measureUniform(int index, double delta, int knownDelta) {
    for (var i = index + 1; i < _tree.length; i += i & -i) {
      _tree[i] += delta;
      _known[i] += knownDelta;
    }
  }

  int get length => _sizes.length;
  double get total => prefix(length);
  int typeAt(int index) {
    return _types[index];
  }

  double extentAt(int index) {
    return _uniform ? _sizes[index] ?? _uniformEstimate : _values[index];
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
    var known = 0;
    for (var i = end; i > 0; i -= i & -i) {
      sum += _tree[i];
      if (_uniform) known += _known[i];
    }
    return _uniform ? sum + (end - known) * _uniformEstimate : sum;
  }

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

  bool measure(int index, double extent) {
    if (!extent.isFinite || extent < 0) throw StateError('条目布局尺寸必须是有限的非负数。');
    if (_sizes[index] == extent) return false;
    final type = _types[index];
    // 零尺寸只属于当前条目，不能让同类型的未知条目也被估成零。
    final firstOfType = extent > 0 && !_estimates.containsKey(type);
    if (firstOfType) _estimates[type] = extent;
    if (_uniform) {
      final previous = _sizes[index];
      final changed = extentAt(index) != extent;
      if (firstOfType) _uniformEstimate = extent;
      _sizes[index] = extent;
      _measureUniform(index, extent - (previous ?? 0), previous == null ? 1 : 0);
      return changed;
    }
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
