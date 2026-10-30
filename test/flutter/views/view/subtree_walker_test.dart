import 'package:flutter_base/src/flutter/views/view/style/inheritance/inheritable_node.dart';
import 'package:flutter_base/src/flutter/views/view/style/inheritance/subtree_walker.dart';
import 'package:flutter_test/flutter_test.dart';

class _Node implements InheritableNode {
  _Node(this.name, [this.children = const []]);

  final String name;
  final List<_Node> children;

  @override
  void visitInheritableChildren(void Function(InheritableNode child) visitor) => children.forEach(visitor);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final tree = _Node('root', [
    _Node('a', [_Node('a1'), _Node('a2')]),
    _Node('b', [_Node('b1')]),
    _Node('c'),
  ]);

  test('路径状态按深度传递，剪枝不影响兄弟节点', () {
    final visited = <(String, String)>[];
    SubtreeWalker.walkWithState(tree, 'root', (node, path) {
      final name = (node as _Node).name;
      visited.add((name, path));
      return name == 'b' ? null : '$path/$name';
    });
    expect(visited, [('a', 'root'), ('a1', 'root/a'), ('a2', 'root/a'), ('b', 'root'), ('c', 'root')]);
  });

  test('遍历中再次遍历同一棵树时，各自保留路径状态', () {
    final outer = <(String, int)>[];
    final inner = <(String, int)>[];
    SubtreeWalker.walkWithState(tree, 0, (node, depth) {
      final name = (node as _Node).name;
      outer.add((name, depth));
      if (name == 'a') {
        SubtreeWalker.walkWithState(tree, 10, (nested, nestedDepth) {
          inner.add(((nested as _Node).name, nestedDepth));
          return nestedDepth + 1;
        });
      }
      return depth + 1;
    });
    expect(outer, [('a', 0), ('a1', 1), ('a2', 1), ('b', 0), ('b1', 1), ('c', 0)]);
    expect(inner, [('a', 10), ('a1', 11), ('a2', 11), ('b', 10), ('b1', 11), ('c', 10)]);
  });

  test('无状态入口同样在返回 false 时剪枝', () {
    final visited = <String>[];
    SubtreeWalker.walk(tree, (node) {
      final name = (node as _Node).name;
      visited.add(name);
      return name != 'a';
    });
    expect(visited, ['a', 'b', 'b1', 'c']);
  });
}
