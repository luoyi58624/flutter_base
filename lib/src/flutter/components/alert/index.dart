import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 提示外观，对齐官方 `effect`。
enum ElAlertEffect {
  /// 浅底（默认）：light-9 底 + 本色字
  light,

  /// 实心：本色底 + 白字
  dark,
}

/// Element Plus 提示组件。
///
/// **受控**：点击关闭只触发 [onClose]，是否把自己从树上摘掉由父级决定
/// （官方组件内部自持 visible，本库统一按叶子受控口径，见项目 CLAUDE.md）。
class ElAlert extends StatelessWidget {
  /// 创建组件参数声明。
  const ElAlert({
    super.key,
    this.title,
    this.description,
    this.type = ElThemeType.info,
    this.effect = ElAlertEffect.light,
    this.closable = true,
    this.closeText,
    this.showIcon = false,
    this.center = false,
    this.onClose,
    this.style,
    this.titleStyle,
    this.descriptionStyle,
    this.closeStyle,
    this.semanticLabel,
    this.closeSemanticLabel,
  });

  /// 标题内容。
  final Object? title;

  /// 辅助描述；一旦存在，标题字号升到 16、图标切大号（对齐官方 with-description / is-big）
  final Object? description;

  /// 语义配色。
  final ElThemeType type;

  /// 填充外观。
  final ElAlertEffect effect;

  /// 是否显示关闭入口。
  final bool closable;

  /// 文字关闭按钮（官方 close-text）；非空时顶替图标按钮
  final Object? closeText;

  /// 是否显示状态图标。
  final bool showIcon;

  /// 内容整体居中（官方 is-center）
  final bool center;

  /// 关闭请求通知，由调用方移除组件。
  final VoidCallback? onClose;

  /// style 层的样式覆写。
  final ElStyle? style;

  /// titleStyle 层的样式覆写。
  final ElStyle? titleStyle;

  /// descriptionStyle 层的样式覆写。
  final ElStyle? descriptionStyle;

  /// closeStyle 层的样式覆写。
  final ElStyle? closeStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  /// 关闭入口的辅助名称。
  final String? closeSemanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).alertBuilder!(context, this);
}
