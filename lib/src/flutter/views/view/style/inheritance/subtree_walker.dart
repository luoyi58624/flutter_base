import 'inheritable_node.dart';

/// 后代子树遍历器。提供两个范式：
class SubtreeWalker {
  const SubtreeWalker._();

  /// 走 [root] 的所有 [InheritableNode] 后代。
  static void walk(InheritableNode root, bool Function(InheritableNode child) visit) =>
      walkWithState(root, true, (child, _) => visit(child) ? true : null);

  /// 每层接收并更新路径状态，返回 null 时截断后代遍历。
  static void walkWithState<T extends Object>(
    InheritableNode root,
    T state,
    T? Function(InheritableNode child, T state) visit,
  ) {
    var current = state;
    void step(InheritableNode child) {
      final previous = current;
      final next = visit(child, previous);
      if (next == null) return;
      // 每次调用独立持有路径值，子树结束后恢复兄弟节点的输入。
      current = next;
      child.visitInheritableChildren(step);
      current = previous;
    }

    root.visitInheritableChildren(step);
  }
}
