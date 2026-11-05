import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 开关声明；放在 ElFormItem 内时与表单字段双向同步。
class ElSwitch extends ElFormModelValue<bool> {
  /// 创建开关，未提供值且不在表单内时从 false 开始。
  ElSwitch({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.disabled = false,
    this.loading = false,
    this.style,
    this.event,
    this.focusNode,
    this.semanticLabel,
  });

  /// 禁止切换与焦点请求。
  final bool disabled;

  /// 显示加载指示并阻止切换。
  final bool loading;

  /// 在品牌默认样式之后合并。
  final ElStyle? style;

  /// 追加事件，与切换动作组合执行，preventDefault 可阻止默认切换。
  final ElEvent? event;

  /// 外部焦点节点，由调用方持有并释放。
  final FocusNode? focusNode;

  /// 辅助名称。
  final String? semanticLabel;

  @override
  bool? get value => super.value ?? false;

  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.switcher)(context, this, $obs);
}
