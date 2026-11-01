part of 'index.dart';

class MyListGroup extends StatelessWidget {
  const MyListGroup({super.key, required this.children, this.title});

  final Widget? title;
  final List<MyListTile> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ElView(
        style: .new(backgroundColor: Colors.white, borderRadius: .circular(16), clipBehavior: .hardEdge),
        child: Column(
          children: children.mapIndexed((i, e) => ElChildIndex(index: i, end: children.length - 1, child: e)).toList(),
        ),
      ),
    );
  }
}

/// 列表组的选择方式，普通组没有选择方式。
enum ElListTileGroupMode {
  /// 单选，模型为一个业务值。
  single,

  /// 多选，模型为业务值列表。
  multi,
}

/// 列表组选项，业务值可为枚举、数字、字符串或具有值相等语义的对象。
class ElListTileGroupItem {
  /// 创建选择项，前后缀占位符继承组的默认配置。
  const ElListTileGroupItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.leading = ElEmptyWidget.instance,
    this.trailing = ElEmptyWidget.instance,
    this.disabled = false,
    this.semanticLabel,
  });

  /// 选项业务值，须符合单选模型类型或多选列表的元素类型。
  final Object? value;

  /// 选项标题，接受文本或 Widget。
  final Object title;

  /// 选项说明，接受文本或 Widget。
  final Object? subtitle;

  /// 起边内容，占位符继承组配置，null 移除此侧及间距，其他内容直接替换。
  final Object? leading;

  /// 末边内容，占位符继承组配置，null 移除此侧及间距，其他内容直接替换。
  final Object? trailing;

  /// 禁止选择该项，与组的 disabled 合并生效。
  final bool disabled;

  /// 辅助技术读取的选项名称。
  final String? semanticLabel;
}

/// 列表组声明，D 表示完整模型：单选为业务值类型，多选为 List<业务值类型>。
class ElListTileGroup<D> extends ElModelValue<D> {
  /// 创建自由组合的普通组，不接管子项选择。
  ElListTileGroup({super.key, this.title, this.description, required this.children, this.style, this.semanticLabel})
    : assert(null is D, '普通组不绑定值，请省略泛型或使用可空类型'),
      mode = null,
      options = const [],
      disabled = false,
      leading = null,
      trailing = null,
      controlAffinity = .leading,
      itemStyle = null,
      itemBuilder = null,
      onSelect = null;

  /// 创建单选组，再次选择同值保持选中，未选择时使用可空模型。
  ElListTileGroup.single({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.title,
    this.description,
    required this.options,
    this.disabled = false,
    this.leading = ElEmptyWidget.instance,
    this.trailing = ElEmptyWidget.instance,
    this.controlAffinity = .leading,
    this.style,
    this.itemStyle,
    this.itemBuilder,
    this.onSelect,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert(value != null || modelValue != null || null is D, '非空 D 必须提供 value 或 modelValue，未选择时使用可空类型'),
       assert(options.every((item) => item.value is D), '选项 value 必须符合单选模型类型 D'),
       assert(options.map((item) => item.value).toSet().length == options.length, '选项 value 必须唯一'),
       mode = .single,
       children = const [];

  /// 创建多选组，D 为完整 List 类型，须提供初始列表或外部模型。
  ElListTileGroup.multi({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.title,
    this.description,
    required this.options,
    this.disabled = false,
    this.leading = ElEmptyWidget.instance,
    this.trailing = ElEmptyWidget.instance,
    this.controlAffinity = .leading,
    this.style,
    this.itemStyle,
    this.itemBuilder,
    this.onSelect,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert(
         _listTileGroupMultiValuesFit(options, modelValue?.value ?? value),
         '多选须提供 List 初始值或模型，选项 value 须符合列表元素类型',
       ),
       assert(options.map((item) => item.value).toSet().length == options.length, '选项 value 必须唯一'),
       mode = .multi,
       children = const [];

  /// 当前选择方式，普通组为 null。
  final ElListTileGroupMode? mode;

  /// 挂载后的完整模型值，供品牌构建与事件读取。
  D get currentValue => $obs.value;

  /// 写入同一模型并沿用基类通知，品牌实现无需另建绑定。
  set currentValue(D value) {
    assert(mode != .multi || _listTileGroupMultiValuesFit(options, value), '多选模型必须为兼容选项值的 List');
    $obs.value = value;
  }

  /// 分组标题，接受文本或 Widget。
  final Object? title;

  /// 分组说明，接受文本或 Widget。
  final Object? description;

  /// 普通组的自由内容，允许列表行与自定义 Widget 混排。
  final List<Widget> children;

  /// 选择组的数据选项，值须唯一，普通组为空。
  final List<ElListTileGroupItem> options;

  /// 禁止整组选择，外部模型同步不受影响。
  final bool disabled;

  /// 选择行的起边默认内容，占位符按 controlAffinity 生成标记，null 移除此侧。
  final Object? leading;

  /// 选择行的末边默认内容，占位符按 controlAffinity 生成标记，null 移除此侧。
  final Object? trailing;

  /// 默认选择标记的位置，单选为 radio、多选为 checkbox，platform 由品牌决定位置。
  final ListTileControlAffinity controlAffinity;

  /// 分组容器样式。
  final ElStyle? style;

  /// 品牌默认选项行的样式。
  final ElStyle? itemStyle;

  /// 覆盖整行绘制，禁用时 onSelect 为 null，省略时使用带默认选择标记的品牌行。
  final Widget Function(BuildContext context, ElListTileGroupItem item, bool selected, VoidCallback? onSelect)?
  itemBuilder;

  /// 用户激活可用项后通知，先更新模型，再通知；重复选择当前单选项仍可通知。
  final ValueChanged<ElListTileGroupItem>? onSelect;

  /// 没有可见标题时提供分组的辅助名称。
  final String? semanticLabel;

  @override
  Widget obsBuilder(BuildContext context) => ElComponentProvider.of(context).listTileGroupBuilder!<D>(context, this);
}

// 在副本上利用 List 的运行时元素类型验证选项，避免污染调用方的初始选择。
bool _listTileGroupMultiValuesFit(List<ElListTileGroupItem> options, Object? value) {
  if (value is! List) return false;
  final dynamic copy = value.toList();
  try {
    for (final item in options) {
      copy.add(item.value);
    }
  } on TypeError {
    return false;
  }
  return true;
}
