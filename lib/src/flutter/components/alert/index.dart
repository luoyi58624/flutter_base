import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 对应 Web Notice 的通知声明，公共 bool 模型控制显示状态。
class ElAlert extends ElModelValue<bool> {
  /// 创建默认显示的通知，不在接口层执行关闭或退场动画。
  ElAlert({
    super.key,
    bool? value,
    super.modelValue,
    super.onChanged,
    this.type = .info,
    this.title,
    this.description,
    this.closable = false,
    this.icon = ElEmptyWidget.instance,
    this.style,
    this.semanticLabel,
    this.onClose,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       super(value: value ?? true);

  /// 挂载后由公共模型持有的显示状态。
  bool get currentValue => $obs.value;

  /// 写入同一模型并沿用公共通知规则。
  set currentValue(bool value) => $obs.value = value;

  /// 通知的语义配色。
  final ElThemeType type;

  /// 可选短标题。
  final Object? title;

  /// 通知正文，接受文字或 Widget。
  final Object? description;

  /// 显示关闭入口，默认不显示。
  final bool closable;

  /// 占位符使用对应状态的默认图标，null 隐藏，其余内容替换默认图标。
  final Object? icon;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 辅助技术读取的通知名称。
  final String? semanticLabel;

  /// 用户关闭时通知，品牌先写入 false，再触发本回调。
  final VoidCallback? onClose;

  @override
  Widget obsBuilder(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.alert)(context, this);
}
