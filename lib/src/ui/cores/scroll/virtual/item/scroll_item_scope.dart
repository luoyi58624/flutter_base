part of '../virtual_pipeline.dart';

/// 每个已挂载滚动成员上方的无 RenderObject item scope。
///
/// scope 只携带真实宿主、扁平 index 与稳定 slot identity；未使用 Mixin/Hook
/// 的成员不会登记 client，也不会创建额外 State 或 listener。
final class _ScrollItemScope extends InheritedWidget {
  const _ScrollItemScope({required this.owner, required this.index, required this.identity, required super.child});

  final ElScrollViewState owner;
  final int index;
  final Object identity;

  static _ScrollItemScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ScrollItemScope>();
  }

  @override
  bool updateShouldNotify(_ScrollItemScope oldWidget) {
    return !identical(owner, oldWidget.owner) || index != oldWidget.index || identity != oldWidget.identity;
  }
}
