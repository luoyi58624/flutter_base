import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 在测试时钟中推进热重载帧，避免先等待重组完成而阻塞下一帧。
Future<void> reassembleSemantics(WidgetTester tester) async {
  final reassemble = tester.binding.reassembleApplication();
  await tester.pump();
  await tester.pumpAndSettle();
  await reassemble;
}

/// 语义窗口不得在 UTF-16 代理对中间截断。
void expectWellFormedSemanticsText(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      expectSync(index + 1, lessThan(value.length), reason: '语义值末尾不得留下高位代理');
      expectSync(value.codeUnitAt(++index), inInclusiveRange(0xdc00, 0xdfff));
    } else {
      expectSync(unit, isNot(inInclusiveRange(0xdc00, 0xdfff)), reason: '语义值不得出现孤立低位代理');
    }
  }
}

/// 引擎实际收到的节点字段，矩形与变换保留原值供几何断言使用。
typedef ElSemanticsRecord = ({
  int id,
  String label,
  Rect rect,
  Matrix4 transform,
  Matrix4 hitTransform,
  List<int> children,
  List<int> hitChildren,
  int actions,
});

/// 对每批增量更新检查根可达性，避免只检查 Dart 节点而漏掉原生坏数据。
class ElSemanticsTestBinding extends AutomatedTestWidgetsFlutterBinding {
  /// 重放增量包后的节点表；离树旧记录保留，但不参与可见树查询。
  final nodes = <int, ElSemanticsRecord>{};

  /// 已提交的非空更新批次数。
  int batches = 0;

  /// 清空上一用例的记录。
  void resetSemanticsRecords() {
    nodes.clear();
    batches = 0;
  }

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _UpdateRecorder(this);

  List<int> get _roots => [
    for (final view in renderViews)
      if (view.debugSemantics case final node?)
        if (nodes.containsKey(node.id)) node.id,
  ];

  Map<int, int?> _parents({bool hitTest = false}) {
    final parents = <int, int?>{};
    void visit(int id, int? parent) {
      expectSync(parents.containsKey(id), isFalse, reason: '语义树出现环或重复父节点：$id');
      parents[id] = parent;
      final node = nodes[id];
      expectSync(node, isNotNull, reason: '语义父节点引用了不存在的子节点：$id');
      for (final child in hitTest ? node!.hitChildren : node!.children) {
        visit(child, id);
      }
    }

    for (final root in _roots) {
      visit(root, null);
    }
    return parents;
  }

  void _record(List<ElSemanticsRecord> updates) {
    if (updates.isEmpty) return;
    batches++;
    for (final update in updates) {
      nodes[update.id] = update;
      expectSync(update.rect.isFinite, isTrue, reason: '语义矩形必须有限：${update.id}');
      expectSync(update.transform.storage.every((value) => value.isFinite), isTrue);
      expectSync(update.hitTransform.storage.every((value) => value.isFinite), isTrue);
    }
    final parents = _parents();
    expectSync(_parents(hitTest: true).keys.every(parents.containsKey), isTrue, reason: '语义命中不能引用无法遍历的节点');
    expectSync(
      updates.where((node) => !parents.containsKey(node.id)).toList(),
      isEmpty,
      reason: '引擎不能接收脱离根树的孤儿更新（批次 $batches）',
    );
  }

  /// 当前仍能从各 View 根节点到达的提交记录。
  Iterable<ElSemanticsRecord> get reachableNodes => _parents().keys.map((id) => nodes[id]!);

  /// 沿提交树组合矩阵，得到相对于所属 View 的物理像素矩形。
  Rect submittedRect(int id) {
    return _submittedRect(id, _parents());
  }

  /// Windows AXTree 还会逐层叠加 offset container 的矩形起点。
  Rect submittedWindowsRect(int id) => _submittedWindowsRect(id, _parents());

  Rect _submittedWindowsRect(int id, Map<int, int?> parents) {
    expectSync(parents.containsKey(id), isTrue);
    var rect = nodes[id]!.rect;
    for (int? current = id; current != null; current = parents[current]) {
      rect = MatrixUtils.transformRect(nodes[current]!.transform, rect);
      final parent = parents[current];
      if (parent != null) rect = rect.shift(nodes[parent]!.rect.topLeft);
    }
    return rect;
  }

  Rect _submittedRect(int id, Map<int, int?> parents, {bool hitTest = false}) {
    expectSync(parents.containsKey(id), isTrue, reason: '目标节点不在提交树中：$id');
    final chain = <ElSemanticsRecord>[];
    for (int? current = id; current != null; current = parents[current]) {
      chain.add(nodes[current]!);
    }
    final transform = Matrix4.identity();
    for (final node in chain.reversed) {
      transform.multiply(hitTest ? node.hitTransform : node.transform);
    }
    return MatrixUtils.transformRect(transform, nodes[id]!.rect);
  }

  /// 按已提交的命中顺序检查指定物理坐标，不借用 RenderObject 的命中结果。
  ElSemanticsRecord? hitTestSemantics(Offset point) {
    return _hitTest(point, hitTest: true);
  }

  /// 当前 Windows MSAA 桥按 AXTree 遍历顺序先到先得，需单独检查重叠区域。
  ElSemanticsRecord? hitTestWindowsSemantics(Offset point) => _hitTest(point, hitTest: false);

  ElSemanticsRecord? _hitTest(Offset point, {required bool hitTest}) {
    final reachable = _parents(hitTest: hitTest);
    ElSemanticsRecord? hit(int id) {
      if (!reachable.containsKey(id)) return null;
      final rect = hitTest ? _submittedRect(id, reachable, hitTest: true) : _submittedWindowsRect(id, reachable);
      if (!rect.contains(point)) return null;
      final node = nodes[id]!;
      for (final child in hitTest ? node.hitChildren : node.children) {
        final result = hit(child);
        if (result != null) return result;
      }
      return node;
    }

    for (final root in _roots.reversed) {
      final result = hit(root);
      if (result != null) return result;
    }
    return null;
  }

  /// 比较最终提交矩形与独立取得的绘制矩形。
  void expectGeometry(WidgetTester tester, Finder finder, {Rect? logicalRect}) {
    final node = tester.getSemantics(finder);
    final expected = physicalSemanticsRect(tester, logicalRect ?? tester.getRect(finder));
    expectSemanticsRect(submittedRect(node.id), expected);
    expectSemanticsRect(submittedWindowsRect(node.id), expected);
  }

  /// 在容器留白处验证原生命中身份与完整内容盒尺寸，防止边界合入祖先。
  void expectContainerHit(WidgetTester tester, Finder finder, {Offset inset = const Offset(4, 4), Rect? logicalRect}) {
    final rect = logicalRect ?? tester.getRect(finder);
    final point = (rect.topLeft + inset) * tester.view.devicePixelRatio;
    final node = tester.getSemantics(finder);
    expectSync(hitTestWindowsSemantics(point)?.id, node.id, reason: '容器留白必须命中自己的语义边界');
    expectSync(hitTestSemantics(point)?.id, node.id);
    expectGeometry(tester, finder, logicalRect: rect);
  }
}

class _UpdateRecorder implements ui.SemanticsUpdateBuilder {
  _UpdateRecorder(this.binding);

  final ElSemanticsTestBinding binding;
  final _delegate = ui.SemanticsUpdateBuilder();
  final _updates = <ElSemanticsRecord>[];

  // 转发完整参数，避免 SDK 新增语义字段后测试替身静默丢弃它们。
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final fields = invocation.namedArguments;
    if (invocation.memberName == #updateNode) {
      _updates.add((
        id: fields[#id] as int,
        label: fields[#label] as String,
        rect: fields[#rect] as Rect,
        transform: Matrix4.fromList(List<double>.from(fields[#transform] as Iterable)),
        hitTransform: Matrix4.fromList(List<double>.from(fields[#hitTestTransform] as Iterable)),
        children: List<int>.from(fields[#childrenInTraversalOrder] as Iterable),
        hitChildren: List<int>.from(fields[#childrenInHitTestOrder] as Iterable),
        actions: fields[#actions] as int,
      ));
      return Function.apply(_delegate.updateNode, invocation.positionalArguments, fields);
    }
    if (invocation.memberName == #updateCustomAction) {
      return Function.apply(_delegate.updateCustomAction, invocation.positionalArguments, fields);
    }
    return super.noSuchMethod(invocation);
  }

  @override
  ui.SemanticsUpdate build() {
    binding._record(_updates);
    return _delegate.build();
  }
}

/// 读取 Dart 语义节点的完整变换，供提交树和本地树交叉验证。
Rect globalSemanticsRect(SemanticsNode node) {
  var transform = node.transform?.clone() ?? Matrix4.identity();
  for (SemanticsNode? parent = node.parent; parent != null; parent = parent.parent) {
    if (parent.transform case final parentTransform?) transform = parentTransform.multiplied(transform);
  }
  return MatrixUtils.transformRect(transform, node.rect);
}

/// 将逻辑绘制矩形换算为所属测试 View 的物理像素矩形。
Rect physicalSemanticsRect(WidgetTester tester, Rect logicalRect) {
  final ratio = tester.view.devicePixelRatio;
  return Rect.fromLTRB(
    logicalRect.left * ratio,
    logicalRect.top * ratio,
    logicalRect.right * ratio,
    logicalRect.bottom * ratio,
  );
}

/// 比较几何边界，仅容忍浮点矩阵计算误差。
void expectSemanticsRect(Rect actual, Rect expected) {
  expectSync(actual.left, closeTo(expected.left, 0.01));
  expectSync(actual.top, closeTo(expected.top, 0.01));
  expectSync(actual.right, closeTo(expected.right, 0.01));
  expectSync(actual.bottom, closeTo(expected.bottom, 0.01));
}
