part of 'stack_view.dart';

/// 按 zIndex、激活顺序、挂载顺序依次比较两个层序节点。
int _compareLayerOrderNodes(ElStackParentData a, ElStackParentData b) {
  var result = a.zIndex.compareTo(b.zIndex);
  if (result != 0) return result;
  result = a.activationOrder.compareTo(b.activationOrder);
  if (result != 0) return result;
  return a.mountOrder.compareTo(b.mountOrder);
}

/// 缓存同一 stacking context 内 child 的统一绘制顺序。
final class _LayerOrderCache<T extends Object> {
  /// 创建排序缓存，host 负责提供 sibling 链和层级元数据。
  _LayerOrderCache({required this.nextSiblingOf, required this.nodeOf, this.compare});

  /// 可选的宿主比较策略；省略时按单层 zIndex、激活序和挂载序比较。
  final int Function(T a, T b)? compare;

  int _compare(T a, T b) => compare?.call(a, b) ?? _compareLayerOrderNodes(nodeOf(a), nodeOf(b));

  /// 返回给定 child 的下一个结构 sibling。
  final T? Function(T child) nextSiblingOf;

  /// 返回给定 child 的层级元数据。
  final ElStackParentData Function(T child) nodeOf;

  List<T>? _orderedChildren;
  Map<T, int>? _orderedIndices;
  bool _resolved = false;
  bool _usesDefaultOrder = true;
  int _debugRebuildCount = 0;
  T? _dirtyChild;
  bool _multipleDirtyChildren = false;
  T? _recentChild;
  int? _recentIndex;

  /// 当前是否可直接使用 host 的结构挂载顺序。
  bool get usesDefaultOrder => _usesDefaultOrder;

  /// 测试读取排序缓存实际重算次数。
  int get debugRebuildCount => _debugRebuildCount;

  /// 标记结构或层级元数据已经变化。
  void invalidate() {
    _resolved = false;
    _orderedChildren = null;
    _orderedIndices = null;
    _dirtyChild = null;
    _multipleDirtyChildren = false;
    _recentChild = null;
    _recentIndex = null;
  }

  /// 仅一个成员的元数据变化时保留列表，首次读取再重插或合批排序。
  void invalidateChild(T child) {
    if (_orderedChildren == null) {
      invalidate();
      return;
    }
    if (_resolved) {
      _dirtyChild = child;
      _multipleDirtyChildren = false;
    } else if (!identical(_dirtyChild, child)) {
      _multipleDirtyChildren = true;
    }
    _resolved = false;
  }

  void _repairChild(List<T> ordered, T child) {
    final index = _indexOf(ordered, child);
    assert(index != null, '单成员修复不能与结构增删混用');
    ordered.removeAt(index!);
    var low = 0;
    var high = ordered.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_compare(ordered[middle], child) <= 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    ordered.insert(low, child);
    _orderedIndices = null;
    _recentChild = child;
    _recentIndex = low;
  }

  int? _indexOf(List<T> ordered, T child) {
    if (identical(_recentChild, child)) return _recentIndex;
    // 连续调整同一成员不必每次分配整张索引表；切换目标后再按需建立。
    if (_recentChild == null && _orderedIndices == null) {
      final index = ordered.indexWhere((candidate) => identical(candidate, child));
      if (index < 0) return null;
      _recentChild = child;
      return _recentIndex = index;
    }
    final indices = _orderedIndices ??= Map<T, int>.identity();
    if (indices.isEmpty) {
      for (var index = 0; index < ordered.length; index++) {
        indices[ordered[index]] = index;
      }
    }
    _recentChild = child;
    return _recentIndex = indices[child];
  }

  /// 单项元数据更新后，其相邻排序关系是否仍满足当前显式快照。
  ///
  /// 连续更新同一成员复用最近位置，切换目标才惰性建立 identity → index 表；
  /// 普通有序宿主不调用此方法，不分配索引表。
  bool canRetainOrderFor(T child) {
    final ordered = _orderedChildren;
    if (!_resolved || ordered == null) return false;
    final index = _indexOf(ordered, child);
    if (index == null) return false;
    return (index == 0 || _compare(ordered[index - 1], child) <= 0) &&
        (index + 1 == ordered.length || _compare(child, ordered[index + 1]) <= 0);
  }

  /// 解析并返回显式排序列表；返回 null 表示直接走结构挂载序快路径。
  List<T>? resolve(T? firstChild, {bool? structurallyOrdered}) {
    if (_resolved) return _orderedChildren;
    _resolved = true;
    _debugRebuildCount++;

    final retained = _orderedChildren;
    if (retained != null) {
      final dirtyChild = _dirtyChild;
      if (!_multipleDirtyChildren && dirtyChild != null) {
        _repairChild(retained, dirtyChild);
      } else {
        retained.sort(_compare);
        _orderedIndices = null;
        _recentChild = null;
        _recentIndex = null;
      }
      _dirtyChild = null;
      _multipleDirtyChildren = false;
      return retained;
    }

    var child = firstChild;
    var needsExplicitOrder = structurallyOrdered == false;
    // 宿主已增量维护相邻关系时不再扫描；否则只检查单调性。
    // 非零 zIndex 并不意味着需要排序，例如末尾的默认 scrollbar z=10。
    if (structurallyOrdered == null) {
      T? previous;
      while (child != null) {
        if (previous != null && _compare(previous, child) > 0) {
          needsExplicitOrder = true;
          break;
        }
        previous = child;
        child = nextSiblingOf(child);
      }
    }

    if (!needsExplicitOrder) {
      _usesDefaultOrder = true;
      return _orderedChildren = null;
    }

    final ordered = <T>[];
    child = firstChild;
    while (child != null) {
      ordered.add(child);
      child = nextSiblingOf(child);
    }
    ordered.sort(_compare);
    _usesDefaultOrder = false;
    return _orderedChildren = ordered;
  }
}
