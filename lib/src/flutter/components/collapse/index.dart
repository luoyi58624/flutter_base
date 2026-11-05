import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 折叠面板组声明，D 是可空单值或业务值 List 的完整模型类型。
class ElCollapse<D> extends ElModelValue<D> {
  /// 创建单项展开组，D 必须可空，以 null 表示全部收起。
  ElCollapse.single({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    required this.children,
    this.disabled = false,
    this.style,
    this.semanticLabel,
  }) : assert(null is D, '单项折叠模型必须可空，以 null 表示全部收起'),
       assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       mode = .single;

  /// 创建多项展开组，D 是完整 List 类型，须提供初始列表或模型。
  ElCollapse.multi({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    required this.children,
    this.disabled = false,
    this.style,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert((modelValue?.value ?? value) is List, '多项折叠须提供 List 初始值或模型'),
       mode = .multi;

  /// 单项或多项展开方式，复用公共模型模式。
  final ElModelValueType mode;

  /// 挂载后由公共模型持有的完整展开值。
  D get currentValue => $obs.value;

  /// 写入同一模型并沿用公共通知规则。
  set currentValue(D value) => $obs.value = value;

  /// 直接组合的面板成员，其 value 是业务身份。
  final List<ElCollapseItem> children;

  /// 禁止标题交互，不主动改变当前展开值。
  final bool disabled;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 辅助技术读取的分组名称。
  final String? semanticLabel;

  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.collapseBuilder)<D>(context, this);
}

/// 折叠面板的业务身份、标题和正文声明。
class ElCollapseItem<T> extends StatelessWidget {
  /// 创建面板成员，业务值不限字符串。
  const ElCollapseItem({super.key, required this.value, this.title, this.disabled = false, this.style, this.child});

  /// 所属分组内唯一的业务身份。
  final T value;

  /// 标题内容，接受文字或 Widget。
  final Object? title;

  /// 禁止此标题交互，不主动收起正文。
  final bool disabled;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 折叠或展开的正文内容。
  final Object? child;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.collapseItemBuilder)<T>(context, this);
}
