import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// Element Plus 结果页组件。
class ElResult extends StatelessWidget {
  /// 创建组件参数声明。
  const ElResult({
    super.key,
    this.title,
    this.subTitle,
    this.icon,
    this.status = ElThemeType.info,
    this.child,
    this.style,
    this.iconStyle,
    this.titleStyle,
    this.subTitleStyle,
    this.semanticLabel,
  });

  /// 标题内容。
  final Object? title;

  /// 标题下的补充说明。
  final Object? subTitle;

  /// 自定义图标，宽容输入（IconData / Widget）；缺省按 [status] 取官方图标
  final Object? icon;

  /// 结果状态，决定缺省图标与图标颜色
  final ElThemeType status;

  /// 底部操作区（官方 extra 插槽）
  final Object? child;

  /// style 层的样式覆写。
  final ElStyle? style;

  /// iconStyle 层的样式覆写。
  final ElStyle? iconStyle;

  /// titleStyle 层的样式覆写。
  final ElStyle? titleStyle;

  /// subTitleStyle 层的样式覆写。
  final ElStyle? subTitleStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).resultBuilder!(context, this);
}
