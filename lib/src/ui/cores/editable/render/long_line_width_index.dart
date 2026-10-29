import 'dart:math' as math;

/// 超长行的有界分段宽度索引，未测区间插值，已测区间保留实际宽度。
final class LongLineWidthIndex {
  /// 用固定的初始字宽建立懒索引，不按全文长度分配存储。
  LongLineWidthIndex(this.advance);

  /// 单行最多保留的坐标节点数。
  static const capacity = 512;

  /// 未访问尾部的初始字宽，局部测量不得放大全部未测正文。
  final double advance;
  final List<int> _offsets = [0];
  final List<double> _positions = [0];
  int _cachedSegment = 0;

  /// 当前保留的坐标节点数。
  int get length => _offsets.length;

  int _lowerBound(int offset) {
    var low = 0;
    var high = _offsets.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_offsets[mid] < offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// O(log 节点数) 查询 UTF-16 位置的横坐标。
  double xForOffset(int offset) {
    if (offset <= 0) return 0;
    final end = _lowerBound(offset);
    if (end == _offsets.length) return _positions.last + (offset - _offsets.last) * advance;
    if (_offsets[end] == offset) return _positions[end];
    final start = end - 1;
    return _positions[start] +
        (offset - _offsets[start]) * (_positions[end] - _positions[start]) / (_offsets[end] - _offsets[start]);
  }

  /// 直接二分横坐标后反插值，避免逐字符二分时反复扫描前缀。
  int offsetForX(double x, int lineLength) {
    if (x <= 0) return 0;
    var low = 0;
    var high = _positions.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_positions[mid] < x) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == _positions.length) {
      return (_offsets.last + ((x - _positions.last) / advance).ceil()).clamp(0, lineLength);
    }
    if (low == 0) return 0;
    final start = low - 1;
    final width = _positions[low] - _positions[start];
    if (width <= 0) return _offsets[start].clamp(0, lineLength);
    return (_offsets[start] + ((x - _positions[start]) * (_offsets[low] - _offsets[start]) / width).ceil()).clamp(
      0,
      lineLength,
    );
  }

  /// 顺序扫描复用当前分段，密集 Tab 的每字符查询保持 O(1)。
  double advanceAt(int offset) {
    var start = _cachedSegment;
    if (offset < _offsets[start] || (start + 1 < length && offset >= _offsets[start + 1])) {
      start = math.max(0, _lowerBound(offset + 1) - 1);
      _cachedSegment = start;
    }
    if (start + 1 == length) return advance;
    return (_positions[start + 1] - _positions[start]) / (_offsets[start + 1] - _offsets[start]);
  }

  /// 在重叠窗口的塑形核心中复用已有坐标，切窗时固定同一个文本锚点。
  int? anchorIn(int start, int end, int target) {
    final first = _lowerBound(start);
    final after = _lowerBound(end + 1);
    if (first == after) return null;
    return _offsets[_lowerBound(target).clamp(first, after - 1)];
  }

  /// 写入一个窗口的真实坐标，后续前缀只平移宽度差，淘汰细节时保留端点与总宽。
  void record(List<int> offsets, List<double> positions) {
    assert(offsets.length == positions.length && offsets.length >= 2);
    final start = offsets.first;
    final end = offsets.last;
    var first = _lowerBound(start);
    final after = _lowerBound(end + 1);
    final delta = positions.last - xForOffset(end);
    // 窄窗修正可能越过邻近的旧插值节点，合并该近似段以保持坐标单调。
    while (first > 0 && positions.first < _positions[first - 1]) {
      first--;
    }
    for (var i = after; i < _positions.length; i++) {
      _positions[i] += delta;
    }
    _offsets.replaceRange(first, after, offsets);
    _positions.replaceRange(first, after, positions);
    // 合并离当前窗口最远的细分节点；保留插值两端，绝不丢掉累计宽度。
    while (_offsets.length > capacity) {
      final leftDistance = start - _offsets[1];
      final rightDistance = _offsets[_offsets.length - 2] - end;
      final remove = leftDistance >= rightDistance ? 1 : _offsets.length - 2;
      _offsets.removeAt(remove);
      _positions.removeAt(remove);
    }
    _cachedSegment = 0;
  }
}
