import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 单格外观，对齐官方 `type`。
enum ElInputOtpType {
  /// 四边描边（默认）
  outlined,

  /// 填充底、无边
  filled,

  /// 只有底部一条线
  underlined,
}

/// 公共 InputOtp 声明，由全局组件主题提供具体实现。
class ElInputOtp extends StatelessWidget {
  /// 创建 InputOtp 公共声明。
  const ElInputOtp({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.length = 6,
    this.type = ElInputOtpType.outlined,
    this.mask = false,
    this.maskCharacter = '•',
    this.disabled = false,
    this.autofocus = false,
    this.keyboardType = TextInputType.number,
    this.autofillHints = const [AutofillHints.oneTimeCode],
    this.onComplete,
    this.style,
    this.cellStyle,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(length > 0, 'length 必须大于 0'),
       assert(maskCharacter.length == 1, 'maskCharacter 必须是单个 UTF-16 code unit');

  /// 格子数（官方 length）
  final int length;

  /// 验证码格子的外观形态。
  final ElInputOtpType type;

  /// 掩码显示（官方 mask）
  final bool mask;

  /// 掩码使用的单个 UTF-16 字符。
  final String maskCharacter;

  /// 是否禁用输入和交互。
  final bool disabled;

  /// 首次挂载后自动请求焦点。
  final bool autofocus;

  /// 平台键盘输入类型。
  final TextInputType keyboardType;

  /// 平台自动填充提示；默认接收短信/系统一次性验证码，null 可显式禁用。
  final Iterable<String>? autofillHints;

  /// 填满时回调一次
  final ValueChanged<String>? onComplete;

  /// 合并在品牌默认外观之后的样式。
  final ElStyle? style;

  /// 验证码格子的样式。
  final ElStyle? cellStyle;

  /// 辅助技术读取的名称。
  final String? semanticLabel;

  /// 当前值；也可由品牌实现接入祖先表单字段。
  final String? value;

  /// 外部双向绑定，生命周期由调用方管理。
  final ValueNotifier<String>? modelValue;

  /// 用户修改已确认值后的通知。
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.inputOtp)(context, this);
}
