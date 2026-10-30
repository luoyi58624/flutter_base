import 'dart:math' as math;

import 'package:flutter_base/src/flutter/views/layout/stack/stack_view.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 使用外部 source order，模拟虚拟窗口而不是普通 Stack 的自动编号。
class _Host extends RenderStackingBox<ElStackParentData> {
  _Host({this.externalSourceOrder = true});

  final bool externalSourceOrder;
  int paintRequests = 0;
  int semanticsRequests = 0;
  int layoutRequests = 0;
  int comparisons = 0;

  @override
  bool get stackSourceOrderIsExternal => externalSourceOrder;

  @override
  bool get hasCustomStackOrder => true;

  @override
  int compareStackChildren(RenderBox a, RenderBox b) {
    comparisons++;
    return super.compareStackChildren(a, b);
  }

  @override
  void markNeedsPaint() {
    paintRequests++;
    super.markNeedsPaint();
  }

  @override
  void markNeedsSemanticsUpdate() {
    semanticsRequests++;
    super.markNeedsSemanticsUpdate();
  }

  @override
  void markNeedsLayout() {
    layoutRequests++;
    super.markNeedsLayout();
  }

  @override
  void performLayout() => size = constraints.biggest;

  @override
  Rect get selfHitRect => Offset.zero & size;

  @override
  bool get clipsHitBounds => true;

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {}
}

class _Box extends RenderBox {
  _Box(this.tag);
  final int tag;

  @override
  void performLayout() => size = constraints.constrain(const Size.square(20));
}

ElStackParentData _data(RenderBox child) => child.parentData! as ElStackParentData;

int _comparePaintOrder(ElStackParentData a, ElStackParentData b) {
  var result = a.zIndex.compareTo(b.zIndex);
  if (result != 0) return result;
  result = a.activationOrder.compareTo(b.activationOrder);
  if (result != 0) return result;
  return a.mountOrder.compareTo(b.mountOrder);
}

void _setZ(_Host host, RenderBox child, int value) {
  final old = _data(child).zIndex;
  _data(child).zIndex = value;
  host.markChildStackOrderChanged(child, oldZIndex: old);
}

void main() {
  late _Host host;
  late List<_Box> allocated;

  _Box add(int source, {int z = 0, RenderBox? after}) {
    final box = _Box(allocated.length);
    allocated.add(box);
    host.setupParentData(box);
    _data(box)
      ..mountOrder = source
      ..zIndex = z;
    host.insert(box, after: after);
    return box;
  }

  setUp(() {
    host = _Host();
    allocated = <_Box>[];
  });

  tearDown(() {
    host.removeAll();
    for (final child in allocated) {
      child.dispose();
    }
    host.dispose();
  });

  test('批量清空不残留排序快照、负层计数或旧 child', () {
    final a = add(0, z: 20);
    final b = add(1, z: -1, after: a);
    final c = add(2, z: 10, after: b);
    expect(host.debugChildrenInPaintOrder, [c, a]);
    expect(host.hasHiddenStackChildren, isTrue);
    host.removeAll();
    expect(host.debugChildrenInPaintOrder, isEmpty);
    expect(host.hasHiddenStackChildren, isFalse);
    expect(host.debugUsesDefaultLayerOrder, isTrue);
    final next = add(0);
    expect(host.debugChildrenInPaintOrder, [next]);
  });

  test('source order 跨序更新同步刷新呈现但不触发布局', () {
    final a = add(0);
    final b = add(1, after: a);
    expect(host.debugChildrenInPaintOrder, [a, b]);
    final paints = host.paintRequests;
    final semantics = host.semanticsRequests;
    final layouts = host.layoutRequests;
    host.setChildStackSourceOrder(a, 2);
    expect(host.paintRequests, paints + 1);
    expect(host.semanticsRequests, semantics + 1);
    expect(host.layoutRequests, layouts);
    expect(host.debugChildrenInPaintOrder, [b, a]);
  });

  test('强制元数据刷新同时重算隐藏计数，不能误走默认命中快路径', () {
    final a = add(0);
    expect(host.hasHiddenStackChildren, isFalse);
    _data(a).zIndex = -1;
    host.markNeedsPaintOrder();
    expect(host.hasHiddenStackChildren, isTrue);
    expect(host.debugChildrenInPaintOrder, isEmpty);
    _data(a).zIndex = 0;
    host.markNeedsPaintOrder();
    expect(host.hasHiddenStackChildren, isFalse);
    expect(host.debugChildrenInPaintOrder, [a]);
  });

  test('已有显式排序时未跨序的 zIndex 更新保持同一缓存及零重绘', () {
    final a = add(0, z: 20);
    final b = add(1, after: a);
    final c = add(2, z: 10, after: b);
    final order = host.explicitStackPaintOrder;
    expect(order, [b, c, a]);
    final resolves = host.debugLayerOrderRebuildCount;
    final paints = host.paintRequests;
    final semantics = host.semanticsRequests;
    final layouts = host.layoutRequests;
    for (var i = 21; i < 141; i++) {
      _setZ(host, a, i);
      expect(host.explicitStackPaintOrder, same(order));
    }
    expect(host.debugLayerOrderRebuildCount, resolves);
    expect(host.paintRequests, paints);
    expect(host.semanticsRequests, semantics);
    expect(host.layoutRequests, layouts);
    _setZ(host, a, 5);
    expect(host.debugChildrenInPaintOrder, [b, a, c]);
    expect(host.paintRequests, paints + 1);
    expect(host.layoutRequests, layouts);
  });

  test('隐藏状态变化即使未换序也刷新呈现，同值则完全无工作', () {
    final a = add(0);
    final b = add(1, z: 10, after: a);
    expect(host.debugChildrenInPaintOrder, [a, b]);
    final before = host.paintRequests;
    _setZ(host, a, 0);
    host.setChildStackSourceOrder(a, 0);
    expect(host.paintRequests, before);
    _setZ(host, a, -1);
    expect(host.paintRequests, before + 1);
    expect(host.hasHiddenStackChildren, isTrue);
    expect(host.debugChildrenInPaintOrder, [b]);
    _setZ(host, a, 0);
    expect(host.paintRequests, before + 2);
    expect(host.hasHiddenStackChildren, isFalse);
    expect(host.debugChildrenInPaintOrder, [a, b]);
  });

  test('1000 次整组失效在首次读取前不比较，隐藏资格读取只扫描一次', () {
    for (var i = 0; i < 128; i++) {
      add(i, after: host.lastChild);
    }
    host.debugChildrenInPaintOrder;
    final comparisons = host.comparisons;
    final paints = host.paintRequests;
    final layouts = host.layoutRequests;
    for (var i = 0; i < 1000; i++) {
      _data(allocated.first).zIndex = -i - 1;
      host.markNeedsPaintOrder();
    }
    expect(host.comparisons, comparisons);
    expect(host.paintRequests, paints + 1);
    expect(host.layoutRequests, layouts);
    expect(host.hasHiddenStackChildren, isTrue);
    expect(host.comparisons - comparisons, 127);
    expect(host.debugChildrenInPaintOrder, allocated.skip(1));
    expect(host.comparisons - comparisons, 127);
  });

  test('普通 Stack 的批量挂载只在读取时统一编号', () {
    host.dispose();
    host = _Host(externalSourceOrder: false);
    for (var i = 0; i < 128; i++) {
      add(0, after: host.lastChild);
    }
    expect(host.comparisons, 0);
    expect(host.debugChildrenInPaintOrder, allocated);
    expect(host.comparisons, 127);
    expect(allocated.map((child) => _data(child).mountOrder), List<int>.generate(128, (i) => i));
  });

  test('128 层的单成员换位逐次读取只做局部比较并保持完整次序', () {
    for (var i = 0; i < 128; i++) {
      add(i, z: 128 - i, after: host.lastChild);
    }
    host.debugChildrenInPaintOrder;
    final target = allocated.first;
    final layouts = host.layoutRequests;
    for (var i = 0; i < 100; i++) {
      final comparisons = host.comparisons;
      _setZ(host, target, i.isEven ? 0 : 129);
      final actual = host.debugChildrenInPaintOrder;
      final expected = List<_Box>.of(allocated)..sort((a, b) => _comparePaintOrder(_data(a), _data(b)));
      expect(actual, expected);
      expect(host.comparisons - comparisons, lessThanOrEqualTo(20));
    }
    expect(host.layoutRequests, layouts);
  });

  for (final external in <bool>[true, false]) {
    test('批量换层混合强制失效、结构变更与隐藏读取保持完整次序，external=$external', () {
      host.dispose();
      host = _Host(externalSourceOrder: external);
      final random = math.Random(8183);
      final mounted = <_Box>[];
      var serial = 0;
      for (var round = 0; round < 150; round++) {
        for (var step = 0; step < 12; step++) {
          final operation = mounted.isEmpty ? 0 : random.nextInt(7);
          switch (operation) {
            case 0:
              final index = random.nextInt(mounted.length + 1);
              final child = add(serial++, z: random.nextInt(12) - 3, after: index == 0 ? null : mounted[index - 1]);
              mounted.insert(index, child);
            case 1:
              host.remove(mounted.removeAt(random.nextInt(mounted.length)));
            case 2:
              final child = mounted.removeAt(random.nextInt(mounted.length));
              final index = random.nextInt(mounted.length + 1);
              host.move(child, after: index == 0 ? null : mounted[index - 1]);
              mounted.insert(index, child);
            case 3:
              _setZ(host, mounted[random.nextInt(mounted.length)], random.nextInt(12) - 3);
            case 4:
              _data(mounted[random.nextInt(mounted.length)]).zIndex = random.nextInt(12) - 3;
              host.markNeedsPaintOrder();
            case 5:
              host.setChildStackActivationOrder(mounted[random.nextInt(mounted.length)], serial++);
            case 6:
              if (external) host.setChildStackSourceOrder(mounted[random.nextInt(mounted.length)], serial++);
              expect(host.hasHiddenStackChildren, mounted.any((child) => _data(child).zIndex < 0));
          }
        }
        final actual = host.debugChildrenInPaintOrder;
        final expected = List<_Box>.of(mounted)..sort((a, b) => _comparePaintOrder(_data(a), _data(b)));
        expect(actual, expected.where((child) => _data(child).zIndex >= 0), reason: '第 $round 批');
        if (!external) {
          expect(mounted.map((child) => _data(child).mountOrder), List<int>.generate(mounted.length, (i) => i));
        }
        expect(host.hasHiddenStackChildren, mounted.any((child) => _data(child).zIndex < 0));
      }
    });
  }

  test('外部源序的挂载、移动、删除与换层始终等价于完整比较器', () {
    final random = math.Random(7101);
    final mounted = <_Box>[];
    var sourceSerial = 0;
    for (var step = 0; step < 600; step++) {
      final operation = mounted.isEmpty ? 0 : random.nextInt(5);
      switch (operation) {
        case 0:
          final index = random.nextInt(mounted.length + 1);
          final child = add(sourceSerial++, z: random.nextInt(8) - 2, after: index == 0 ? null : mounted[index - 1]);
          mounted.insert(index, child);
        case 1:
          final child = mounted.removeAt(random.nextInt(mounted.length));
          host.remove(child);
        case 2:
          final child = mounted.removeAt(random.nextInt(mounted.length));
          final index = random.nextInt(mounted.length + 1);
          host.move(child, after: index == 0 ? null : mounted[index - 1]);
          mounted.insert(index, child);
        case 3:
          _setZ(host, mounted[random.nextInt(mounted.length)], random.nextInt(8) - 2);
        case 4:
          host.setChildStackSourceOrder(mounted[random.nextInt(mounted.length)], sourceSerial++);
      }
      final expected = List<_Box>.of(mounted)..sort((a, b) => _comparePaintOrder(_data(a), _data(b)));
      expect(
        host.debugChildrenInPaintOrder,
        expected.where((child) => _data(child).zIndex >= 0),
        reason: '第 $step 步，操作 $operation',
      );
      expect(host.hasHiddenStackChildren, mounted.any((child) => _data(child).zIndex < 0));
      var ordered = true;
      for (var i = 1; i < mounted.length; i++) {
        if (_comparePaintOrder(_data(mounted[i - 1]), _data(mounted[i])) > 0) ordered = false;
      }
      expect(host.debugUsesDefaultLayerOrder, ordered, reason: '第 $step 步的相邻关系记账');
    }
  });
}
