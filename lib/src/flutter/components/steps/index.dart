import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 当前步骤允许声明的状态，前后步骤状态由品牌根据当前下标推导。
enum ElStepStatus {
  /// 当前处理中。
  process,

  /// 当前步骤失败。
  error,
}

/// 以索引绑定当前步骤的公共声明。
class ElSteps extends ElModelValue<int> {
  /// 创建步骤条，默认仅展示进度。
  ElSteps({
    super.key,
    int? value,
    super.modelValue,
    super.onChanged,
    required this.children,
    this.status = .process,
    this.vertical = false,
    this.interactive = false,
    this.disabled = false,
    this.style,
    this.semanticLabel = '步骤',
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       super(value: value ?? 0);

  /// 挂载后由公共模型持有的当前步骤下标。
  int get currentValue => $obs.value;

  /// 写入同一模型并沿用公共通知规则。
  set currentValue(int value) => $obs.value = value;

  /// 直接组合的步骤内容。
  final List<ElStep> children;

  /// 当前步骤的进行或错误状态。
  final ElStepStatus status;

  /// 使用纵向布局。
  final bool vertical;

  /// 允许点击或键盘改变当前步骤。
  final bool interactive;

  /// 禁止交互模式下的所有步骤操作。
  final bool disabled;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 辅助技术读取的步骤列表名称。
  final String? semanticLabel;

  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.stepsBuilder)(context, this);
}

/// 单个步骤的文字、说明、图标和禁用状态。
class ElStep extends StatelessWidget {
  /// 创建步骤内容，不单独绑定或覆盖派生状态。
  const ElStep({super.key, this.title, this.description, this.icon, this.disabled = false, this.style});

  /// 步骤标题。
  final Object? title;

  /// 补充说明。
  final Object? description;

  /// 自定义图标或内容。
  final Object? icon;

  /// 交互模式下禁止选择此步骤。
  final bool disabled;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.stepBuilder)(context, this);
}
