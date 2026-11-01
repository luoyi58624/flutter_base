part of 'index.dart';

/// 菜单树中的业务选项，只有没有 children 的叶子项提交选择。
class ElMenuOption<T> extends ElLabelModel<T> {
  /// 创建菜单项，value 在同一棵菜单树中保持唯一。
  ElMenuOption(
    String super.label,
    T super.value, {
    this.children = const [],
    this.disabled = false,
    this.description,
    this.leading,
  });

  /// 子菜单，非空时当前项负责展开并显示后代选中状态。
  final List<ElMenuOption<T>> children;

  /// 禁止选择或展开当前项。
  final bool disabled;

  /// 标题下的可选说明。
  final Object? description;

  /// 起边图标或自定义内容。
  final Object? leading;

  @override
  T get value => super.value as T;

  @override
  List<Object?> get props => [...super.props, children, disabled, description, leading];
}

bool _validMenuOptions<T>(List<ElLabelModel<T>> options) {
  final values = <Object?>{};
  bool visit(List<ElLabelModel<T>> items) => items.every(
    (item) => item.value is T && values.add(item.value) && (item is! ElMenuOption<T> || visit(item.children)),
  );
  return visit(options);
}
