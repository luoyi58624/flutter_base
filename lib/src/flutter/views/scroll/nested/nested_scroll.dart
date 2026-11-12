import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'nested_scroll_chain.dart' show ElNestedScrollParent, NestedScrollNode;

/// 让 [parent] 参与子树内 ElScrollView 的拖动与惯性分配，用于折叠头、联动页头等效果。
///
/// 每段位移先交给 [ElNestedScrollParent.onNestedPreScroll]，正文走不完的余量再交给
/// onNestedPostScroll，松手速度交给 onNestedPreFling。多层嵌套时 pre 由外到内、post 由内到外。
/// 只有真正持有本次拖动的 ElScrollView 会驱动它上方的协作方；内层贴边把手势交给外层后，
/// 包在内外层之间的协作方不参与。
class ElNestedScroll extends HookWidget {
  /// 为 [child] 子树注册一个协作方。
  const ElNestedScroll({super.key, required this.parent, required this.child});

  /// 接收位移与速度的协作方，可在重建时更换。
  final ElNestedScrollParent parent;

  /// 包含 ElScrollView 的子树。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final node = useMemoized(() => NestedScrollNode(parent: parent));
    useEffect(() {
      // 进行中的手势可能仍持有这条链，卸载后标记失效，避免回调已销毁的协作方。
      return () => node.detached = true;
    }, const []);
    node
      ..parent = parent
      ..outer = context.dependOnInheritedWidgetOfExactType<_NestedScrollScope>()?.node;
    return _NestedScrollScope(node: node, child: child);
  }
}

class _NestedScrollScope extends InheritedWidget {
  const _NestedScrollScope({required this.node, required super.child});

  final NestedScrollNode node;

  @override
  bool updateShouldNotify(_NestedScrollScope oldWidget) => !identical(node, oldWidget.node);
}

/// 读取 [context] 上方最近的协作节点，不建立依赖；滚动位置在拖动开始时调用。
NestedScrollNode? nestedScrollNodeOf(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_NestedScrollScope>()?.node;
