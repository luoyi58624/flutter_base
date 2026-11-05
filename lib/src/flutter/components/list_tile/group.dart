part of 'index.dart';

/// 列表组声明，D 表示完整模型：单选为业务值类型，多选为 List<业务值类型>。
class ElListGroup<D> extends ElModelValue<D> {
  /// 创建普通列表组，不接管子项选择。
  ElListGroup({super.key, this.title, required this.children, this.leading = true})
    : assert(null is D, '普通组不绑定值，请省略泛型或使用可空类型'),
      mode = null;

  /// 创建单选组，再次选择同值保持选中，未选择时使用可空模型。
  ElListGroup.single({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.title,
    required this.children,
    this.leading = true,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert(value != null || modelValue != null || null is D, '非空 D 必须提供 value 或 modelValue，未选择时使用可空类型'),
       mode = .single;

  /// 创建多选组，D 为完整 List 类型，须提供初始列表或外部模型。
  ElListGroup.multi({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.title,
    required this.children,
    this.leading = true,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert((modelValue?.value ?? value) is List, '多选须提供 List 初始值或模型'),
       mode = .multi;

  /// 当前选择方式，普通组为 null。
  final ElModelValueType? mode;

  /// 挂载后的完整模型值，供品牌构建与事件读取。
  D get currentValue => $obs.value;

  /// 写入同一模型并沿用基类通知，品牌实现无需另建绑定。
  set currentValue(D value) => $obs.value = value;

  /// 分组标题，接受文本或 Widget。
  final Object? title;

  /// 列表子项，选择模式直接使用子项 value 作为业务值。
  final List<ElListTile> children;

  /// 单选或多选标记是否前置，false 时后置。
  final bool leading;

  @override
  Widget obsBuilder(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.listTileGroup)<D>(context, this);
}
