import 'package:flutter_base/src/ui/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/ui/utils/internal/bit_mask.dart';
import '../resolved/resolved_style.dart';
import 'inheritable_node.dart';
import 'subtree_walker.dart';

/// 继承字段传播器。
class InheritancePropagator {
  const InheritancePropagator._();

  /// 当前活跃 walk 对"本 reresolve 所在子树"仍将投递的字段 mask
  /// （动态作用域，单线程栈式覆盖恢复；仅在 visitor 调用
  /// `child.reresolveFromInheritance` 的窗口内非 0）。
  static FieldMask _activeWalkMask = FieldMask.empty;

  /// 向后代投递变化位图，在显式声明与嵌套传播处截断。
  static void propagate(InheritableNode root, FieldMask changedMask, {FieldMask themeAnimationMask = FieldMask.empty}) {
    assert(() {
      BenchmarkProbe.propagateCount++;
      return true;
    }());
    final rootMask = maskAndNot(changedMask, _activeWalkMask);
    if (rootMask.isEmpty) return;
    final _InheritanceState rootState = (
      parentResolved: root.committedResolvedStyle,
      changedMask: rootMask,
      themeAnimationMask: maskAnd(themeAnimationMask, rootMask),
    );
    SubtreeWalker.walkWithState<_InheritanceState>(root, rootState, (child, state) {
      final effectiveMask = maskAndNot(state.changedMask, child.explicitlySetMask);
      if (effectiveMask.isEmpty) return null;
      final incomingThemeMask = maskAnd(state.themeAnimationMask, effectiveMask);
      // reresolve 调用窗口内叠加本层覆盖 mask：其内部 route 再 propagate 时，
      // 已由本 walk（含外层嵌套 walk）接手的字段被剥离，见 [_activeWalkMask]。
      final prevActiveMask = _activeWalkMask;
      _activeWalkMask = maskOr(prevActiveMask, effectiveMask);
      final FieldMask continuedThemeMask;
      try {
        continuedThemeMask = maskAnd(
          child.reresolveFromInheritance(
            state.parentResolved,
            effectiveMask,
            inheritedThemeAnimationMask: incomingThemeMask,
          ),
          incomingThemeMask,
        );
      } finally {
        _activeWalkMask = prevActiveMask;
      }
      // 活跃变体拦下的 theme 字段不能再以“普通继承变化”送到孙节点；否则孙层
      // 仍会按自己的 transition 重启。child 已更新 parent 快照，变体解除时会
      // 从真实 committed diff 重新传播，不会丢最终值。
      final blockedThemeMask = maskAndNot(incomingThemeMask, continuedThemeMask);
      final nextChangedMask = maskAndNot(effectiveMask, blockedThemeMask);
      if (nextChangedMask.isEmpty) return null;
      return (
        parentResolved: child.committedResolvedStyle,
        changedMask: nextChangedMask,
        themeAnimationMask: maskAnd(continuedThemeMask, nextChangedMask),
      );
    });
  }
}

// 每层只携带父样式和仍待传播的字段位图。
typedef _InheritanceState = ({ResolvedStyle? parentResolved, FieldMask changedMask, FieldMask themeAnimationMask});
