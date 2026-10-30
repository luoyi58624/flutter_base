import 'package:collection/collection.dart' show IdentityEquality, ListEquality;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';

final Expando<OverflowHitTestHost> _overflowProxyHosts = Expando<OverflowHitTestHost>();

void _setOverflowProxyHost(RenderBox candidate, OverflowHitTestHost? host) {
  final previous = _overflowProxyHosts[candidate];
  if (identical(previous, host)) {
    host?.markOverflowHitTestProxyDirty(candidate);
    return;
  }
  previous?.unregisterOverflowHitTestProxy(candidate);
  _overflowProxyHosts[candidate] = host;
  host?.registerOverflowHitTestProxy(candidate);
}

/// 被官方 RenderBox 夹层打断时接管深层溢出命中的 host 协议。
abstract interface class OverflowHitTestHost {
  /// 注册跨越官方 RenderBox 夹层的最近 El 命中子树。
  void registerOverflowHitTestProxy(RenderBox candidate);

  /// 注销已经离开当前 host 的命中子树。
  void unregisterOverflowHitTestProxy(RenderBox candidate);

  /// 标记已注册子树的几何或命中策略发生变化。
  void markOverflowHitTestProxyDirty(RenderBox candidate);

  /// 遍历当前可见代理在 host 坐标系中的保守边界。
  void visitOverflowHitTestProxyBounds(void Function(Rect bounds) visitor);
}

/// 维护深层溢出节点的几何快照并重建完整 RenderBox 命中路径。
final class OverflowHitProxyRegistry {
  /// 创建绑定到指定 layer host 的代理表。
  OverflowHitProxyRegistry(this.host);

  /// 代理最终参与命中的 layer host。
  final RenderBox host;

  final Set<RenderBox> _candidates = Set<RenderBox>.identity();
  final Set<RenderBox> _geometryDirtyCandidates = Set<RenderBox>.identity();
  List<_OverflowHitProxySnapshot> _snapshots = const <_OverflowHitProxySnapshot>[];
  Map<RenderObject, Map<RenderObject, int>> _paintOrderProbes = const {};
  bool _dirty = true;
  bool _lazyValidationPending = false;
  int _geometryVersion = 0;

  /// 当前注册的候选数量。
  int get candidateCount => _candidates.length;

  /// 是否存在需要代理的候选。
  bool get hasCandidates => _candidates.isNotEmpty;

  /// 最近一次有效几何快照的单调版本号。
  int get geometryVersion => _geometryVersion;

  /// 注册候选并使几何快照失效。
  void register(RenderBox candidate) {
    if (_candidates.add(candidate)) _dirty = true;
  }

  /// 注销候选并使几何快照失效。
  void unregister(RenderBox candidate) {
    if (_candidates.remove(candidate)) {
      _geometryDirtyCandidates.remove(candidate);
      _dirty = true;
    }
  }

  /// 标记候选几何已经变化。
  void markDirty(RenderBox candidate) {
    if (_candidates.contains(candidate)) {
      _geometryDirtyCandidates.add(candidate);
    }
  }

  /// 在 host paint 前同步主动标脏的代理几何。
  bool syncForPaint({bool deferGeometry = false}) {
    if (deferGeometry) {
      if (_candidates.isEmpty && _snapshots.isEmpty) return false;
      // 裁剪视口的绘制不消费命中几何；保留脏标记，实际查询时再重建路径与变换。
      _lazyValidationPending = true;
      return true;
    }
    if (_dirty) return _sync();
    if (_snapshots.isEmpty) return false;
    if (_geometryDirtyCandidates.isNotEmpty) {
      _refreshGeometry(refreshAll: false);
    }
    _lazyValidationPending = true;
    // host 需要把自身及祖先的 bounds cache 标脏；这里只做 O(1) 延迟标记，
    // 不在 paint 热路读取任何深层几何。
    return true;
  }

  bool _validateLazyGeometry() {
    if (!_lazyValidationPending) return false;
    _lazyValidationPending = false;
    for (final probe in _paintOrderProbes.entries) {
      if (_matchesPaintOrder(probe.key, probe.value)) continue;
      _dirty = true;
      return _sync();
    }
    return _refreshGeometry(refreshAll: true);
  }

  bool _refreshGeometry({required bool refreshAll}) {
    if (_snapshots.isEmpty) {
      _geometryDirtyCandidates.clear();
      return false;
    }
    List<_OverflowHitProxySnapshot>? next;
    final transforms = _OverflowHitProxyTransformCache(host);
    for (var index = 0; index < _snapshots.length; index++) {
      final previous = _snapshots[index];
      if (!refreshAll && !_geometryDirtyCandidates.contains(previous.candidate)) {
        continue;
      }
      final refreshed = previous.refreshPaintGeometry(transforms);
      if (refreshed == null) {
        // 脱挂/重父化等结构变化仍走完整快照，保留 route 与
        // paint order 正确性；稳态官方 Transform 只刷新 bounds。
        _dirty = true;
        return _sync();
      }
      if (identical(refreshed, previous)) continue;
      next ??= List<_OverflowHitProxySnapshot>.of(_snapshots);
      next[index] = refreshed;
    }
    _geometryDirtyCandidates.clear();
    if (next == null) return false;
    _snapshots = next;
    _geometryVersion++;
    return true;
  }

  /// 遍历代理边界，供 host 合并进自身 overflow hit bounds。
  void visitBounds(void Function(Rect bounds) visitor) {
    _sync();
    if (!_validateLazyGeometry()) {
      _refreshGeometry(refreshAll: false);
    }
    for (final snapshot in _snapshots) {
      visitor(snapshot.bounds);
    }
  }

  /// 在指定直接 child 内按视觉逆序尝试深层代理命中。
  bool hitTestForChild(BoxHitTestResult result, {required Offset position, required RenderBox directChild}) {
    _sync();
    if (!_validateLazyGeometry()) {
      _refreshGeometry(refreshAll: false);
    }
    final transforms = _OverflowHitProxyTransformCache(host);
    for (var i = _snapshots.length - 1; i >= 0; i--) {
      final snapshot = _snapshots[i];
      if (!identical(snapshot.directChild, directChild) || !snapshot.bounds.contains(position)) continue;
      final candidateTransform = transforms.resolve(snapshot.route, snapshot.candidate);
      if (candidateTransform == null || !snapshot.allowsHit(position, transforms)) continue;
      final hit = result.addWithPaintTransform(
        transform: candidateTransform,
        position: position,
        hitTest: (result, transformed) => snapshot.candidate.hitTest(result, position: transformed),
      );
      if (!hit) continue;

      for (final ancestor in snapshot.route) {
        final transform = transforms.cached(ancestor);
        if (transform == null) continue;
        result.addWithPaintTransform(
          transform: transform,
          position: position,
          hitTest: (result, transformed) {
            result.add(BoxHitTestEntry(ancestor, transformed));
            return true;
          },
        );
      }
      return true;
    }
    return false;
  }

  bool _sync() {
    if (!_dirty) return false;
    _dirty = false;
    _lazyValidationPending = false;
    _geometryDirtyCandidates.clear();
    final previous = _snapshots;
    final next = <_OverflowHitProxySnapshot>[];
    final stale = <RenderBox>[];
    final paintOrderIndices = _OverflowHitProxyPaintOrderIndices();
    final transforms = _OverflowHitProxyTransformCache(host);
    for (final candidate in _candidates) {
      final snapshot = _OverflowHitProxySnapshot.create(host, candidate, paintOrderIndices, transforms);
      if (snapshot == null) {
        stale.add(candidate);
      } else {
        next.add(snapshot);
      }
    }
    for (final candidate in stale) {
      _candidates.remove(candidate);
      if (identical(_overflowProxyHosts[candidate], host)) {
        _overflowProxyHosts[candidate] = null;
      }
    }
    next.sort(_OverflowHitProxySnapshot.comparePaintOrder);
    _snapshots = next;
    _paintOrderProbes = paintOrderIndices.expected;
    var changed = previous.length != next.length;
    if (!changed) {
      for (var i = 0; i < next.length; i++) {
        if (previous[i].sameGeometry(next[i])) continue;
        changed = true;
        break;
      }
    }
    if (changed) _geometryVersion++;
    return changed;
  }
}

/// 单次代理同步内复用共享祖先的 child→host paint transform。
///
/// `RenderObject.getTransformTo` 会为每个候选重新走完整祖先链；文档根 Stack
/// 的代理路径高度重合，逐候选计算会把同一深链重复十几次。这里按 child identity
/// 缓存每条边累积后的矩阵，使每条共享边每次同步最多计算一次。
final class _OverflowHitProxyTransformCache {
  _OverflowHitProxyTransformCache(this.host) {
    _toHost[host] = Matrix4.identity();
  }

  final RenderBox host;
  final Map<RenderObject, Matrix4> _toHost = Map<RenderObject, Matrix4>.identity();

  Matrix4? cached(RenderObject node) => _toHost[node];

  Matrix4? resolve(List<RenderBox> route, RenderBox candidate) {
    RenderObject parent = host;
    for (var index = route.length - 1; index >= 0; index--) {
      final child = route[index];
      if (_advance(parent, child) == null) return null;
      parent = child;
    }
    return _advance(parent, candidate);
  }

  Matrix4? _advance(RenderObject parent, RenderObject child) {
    final cached = _toHost[child];
    if (cached != null) return cached;
    if (!identical(child.parent, parent)) return null;
    final parentTransform = _toHost[parent];
    if (parentTransform == null) return null;
    final transform = Matrix4.copy(parentTransform);
    try {
      parent.applyPaintTransform(child, transform);
    } on FlutterError {
      return null;
    }
    _toHost[child] = transform;
    return transform;
  }
}

/// 一次完整快照内按 parent 复用 child paint index，避免 N 个代理各自
/// `visitChildren` 扫同一份长列表。
final class _OverflowHitProxyPaintOrderIndices {
  final _byParent = Map<RenderObject, Map<RenderObject, int>>.identity();
  final expected = Map<RenderObject, Map<RenderObject, int>>.identity();

  int? indexOf(RenderObject parent, RenderObject child) {
    final indices = _byParent.putIfAbsent(parent, () {
      final values = Map<RenderObject, int>.identity();
      parent.visitChildren((node) => values[node] = values.length);
      return values;
    });
    final index = indices[child];
    if (index != null) (expected[parent] ??= Map<RenderObject, int>.identity())[child] = index;
    return index;
  }
}

/// 命中查询前每个共享 parent 只验证一次顺序，移动直接子时重建代理路径。
bool _matchesPaintOrder(RenderObject parent, Map<RenderObject, int> expected) {
  if (!parent.attached) return false;
  var index = 0, found = 0;
  var matches = true;
  parent.visitChildren((child) {
    final previous = expected[child];
    if (previous != null) {
      found++;
      if (previous != index) matches = false;
    }
    index++;
  });
  return matches && found == expected.length;
}

final class _OverflowHitProxySnapshot {
  _OverflowHitProxySnapshot({
    required this.candidate,
    required this.route,
    required this.paintPath,
    required this.bounds,
  });

  final RenderBox candidate;
  RenderBox get directChild => route.last;
  final List<RenderBox> route;
  final List<int> paintPath;
  final Rect bounds;

  /// 仅刷新 paint-only 官方 Transform 引起的边界；route 一旦变化
  /// 返回 null，由注册表回退到完整结构快照。
  _OverflowHitProxySnapshot? refreshPaintGeometry(_OverflowHitProxyTransformCache transforms) {
    if (!candidate.attached || !transforms.host.attached) return null;
    final transform = transforms.resolve(route, candidate);
    if (transform == null) return null;
    final currentCandidate = candidate;
    final localBounds = currentCandidate is ElOverflowHitBounds
        ? currentCandidate.hitTestBounds
        : (Offset.zero & currentCandidate.size);
    final nextBounds = MatrixUtils.transformRect(transform, localBounds);
    if (!nextBounds.isFinite || nextBounds.isEmpty) return null;
    if (nextBounds == bounds) return this;
    return _OverflowHitProxySnapshot(candidate: candidate, route: route, paintPath: paintPath, bounds: nextBounds);
  }

  static _OverflowHitProxySnapshot? create(
    RenderBox host,
    RenderBox candidate,
    _OverflowHitProxyPaintOrderIndices paintOrderIndices,
    _OverflowHitProxyTransformCache transforms,
  ) {
    if (!candidate.attached || !host.attached || identical(candidate, host)) return null;
    final route = <RenderBox>[];
    RenderObject? node = candidate.parent;
    while (node != null && !identical(node, host)) {
      if (node is! RenderBox) return null;
      route.add(node);
      node = node.parent;
    }
    if (!identical(node, host) || route.isEmpty) return null;

    final transform = transforms.resolve(route, candidate);
    if (transform == null) return null;
    final localBounds = candidate is ElOverflowHitBounds ? candidate.hitTestBounds : (Offset.zero & candidate.size);
    final bounds = MatrixUtils.transformRect(transform, localBounds);
    if (!bounds.isFinite || bounds.isEmpty) return null;

    final paintPath = <int>[];
    RenderObject parent = host;
    for (final child in <RenderObject>[...route.reversed, candidate]) {
      final index = paintOrderIndices.indexOf(parent, child);
      if (index == null) return null;
      paintPath.add(index);
      parent = child;
    }

    return _OverflowHitProxySnapshot(candidate: candidate, route: route, paintPath: paintPath, bounds: bounds);
  }

  static int comparePaintOrder(_OverflowHitProxySnapshot a, _OverflowHitProxySnapshot b) {
    final length = a.paintPath.length < b.paintPath.length ? a.paintPath.length : b.paintPath.length;
    for (var i = 0; i < length; i++) {
      final result = a.paintPath[i].compareTo(b.paintPath[i]);
      if (result != 0) return result;
    }
    return a.paintPath.length.compareTo(b.paintPath.length);
  }

  bool sameGeometry(_OverflowHitProxySnapshot other) =>
      identical(candidate, other.candidate) &&
      identical(directChild, other.directChild) &&
      bounds == other.bounds &&
      const ListEquality<RenderBox>(IdentityEquality()).equals(route, other.route) &&
      listEquals(paintPath, other.paintPath);

  bool allowsHit(Offset hostPosition, _OverflowHitProxyTransformCache transforms) {
    for (final ancestor in route) {
      final local = _localPosition(ancestor, hostPosition, transforms);
      if (local == null) return false;
      if (ancestor is RenderOffstage && ancestor.offstage) return false;
      if (ancestor is RenderIgnorePointer && ancestor.ignoring) return false;
      if (ancestor is RenderAbsorbPointer && ancestor.absorbing) return false;
      if (!_insideClip(ancestor, local)) return false;
      if (ancestor is ElOverflowHitBounds && ancestor.clipsHitBounds && !ancestor.selfHitRect.contains(local)) {
        return false;
      }
    }
    return true;
  }

  Offset? _localPosition(RenderBox target, Offset hostPosition, _OverflowHitProxyTransformCache transforms) {
    final transform = transforms.cached(target);
    if (transform == null) return null;
    final inverse = Matrix4.copy(transform);
    final determinant = inverse.invert();
    if (determinant == 0 || !determinant.isFinite) return null;
    return MatrixUtils.transformPoint(inverse, hostPosition);
  }

  bool _insideClip(RenderBox target, Offset position) {
    if (target is RenderClipRect && target.clipBehavior != Clip.none) {
      return (target.clipper?.getClip(target.size) ?? (Offset.zero & target.size)).contains(position);
    }
    if (target is RenderClipRRect && target.clipBehavior != Clip.none) {
      final clip =
          target.clipper?.getClip(target.size) ??
          target.borderRadius.resolve(target.textDirection).toRRect(Offset.zero & target.size);
      return clip.contains(position);
    }
    if (target is RenderClipPath && target.clipBehavior != Clip.none) {
      final clip = target.clipper?.getClip(target.size) ?? (Path()..addRect(Offset.zero & target.size));
      return clip.contains(position);
    }
    if (target is RenderClipOval && target.clipBehavior != Clip.none) {
      final clip = target.clipper?.getClip(target.size) ?? (Offset.zero & target.size);
      return (Path()..addOval(clip)).contains(position);
    }
    return true;
  }
}

/// 溢出命中边界协议（`.claude/plan/temp/hit-test-overflow-bounds.md`）。
mixin ElOverflowHitBounds on RenderBox {
  Rect? _hitBoundsPreCache;
  bool _hitBoundsDirty = true;

  /// 自身命中矩形（pre-transform 本地系），通常为 box rect。
  Rect get selfHitRect;

  /// 是否对内容裁剪（clipBehavior / clipper / 滚动视口）——裁剪即封口：
  /// 子溢出画不出来，也不外传命中边界。
  bool get clipsHitBounds;

  /// 自身 paint transform（与 paint / hitTest / applyPaintTransform 同源）；
  /// null = identity。
  Matrix4? get hitBoundsTransform => null;

  /// 遍历参与聚合的直接子及其在本地系的落位偏移。
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor);

  /// pre-transform 本地系聚合命中边界（剪枝口径）。懒计算 + 缓存；无溢出时
  /// 缓存存 null 并直接返回 [selfHitRect]（常规树零额外分配）。
  Rect get hitBoundsPre {
    if (!_hitBoundsDirty) return _hitBoundsPreCache ?? selfHitRect;
    _hitBoundsDirty = false;
    final self = selfHitRect;
    if (clipsHitBounds) {
      _hitBoundsPreCache = null;
      return self;
    }
    var bounds = self;
    void include(Rect rect) {
      if (rect.left < bounds.left ||
          rect.top < bounds.top ||
          rect.right > bounds.right ||
          rect.bottom > bounds.bottom) {
        bounds = bounds.expandToInclude(rect);
      }
    }

    visitHitBoundsChildren((child, offset) {
      if (!child.hasSize) return;
      final rect = child is ElOverflowHitBounds ? child.hitTestBounds : (Offset.zero & child.size);
      include(rect.shift(offset));
    });
    if (this case final OverflowHitTestHost host) host.visitOverflowHitTestProxyBounds(include);
    _hitBoundsPreCache = bounds == self ? null : bounds;
    return bounds;
  }

  /// 暴露给父级聚合的命中边界（父寻址空间）。矩阵不可逆时贡献退化为
  /// pre 边界原样（与 paint 画不出来一致，宁大勿漏由 AABB 保证）。
  Rect get hitTestBounds {
    final pre = hitBoundsPre;
    final t = hitBoundsTransform;
    if (t == null) return pre;
    return MatrixUtils.transformRect(t, pre);
  }

  /// 剪枝辅助：位置是否落在聚合边界内（含自身盒）。
  bool hitBoundsContains(Offset position) => hitBoundsPre.contains(position);

  /// 是否存在溢出（聚合边界 ⊋ 自身盒）。测试探针 / 快路径判定用。
  bool get hasHitBoundsOverflow {
    final _ = hitBoundsPre; // 确保已计算
    return _hitBoundsPreCache != null;
  }

  /// 标脏并向父链上溯（早停于已脏节点）。布局入口与 paint-only transform
  /// 写入路径调用；非协议中间节点（官方 render）穿透继续上溯。
  void markHitBoundsDirty() {
    _hitBoundsDirty = true;
    RenderBox proxyCandidate = this;
    var crossedOfficialNode = false;
    OverflowHitTestHost? proxyHost;
    RenderObject? node = parent;
    while (node != null) {
      if (node is ElOverflowHitBounds) {
        node._hitBoundsDirty = true;
        if (crossedOfficialNode && node is OverflowHitTestHost) {
          proxyHost = node as OverflowHitTestHost;
          break;
        }
        if (!crossedOfficialNode) proxyCandidate = node;
      } else {
        crossedOfficialNode = true;
      }
      node = node.parent;
    }
    _setOverflowProxyHost(proxyCandidate, proxyHost);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    markHitBoundsDirty();
  }

  @override
  void detach() {
    _setOverflowProxyHost(this, null);
    super.detach();
  }
}
