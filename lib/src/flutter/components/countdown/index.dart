import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 倒计时公共声明。
class ElCountdown extends StatelessWidget {
  /// 创建倒计时公共声明。
  const ElCountdown({
    super.key,
    required this.value,
    this.title,
    this.format = 'HH:mm:ss',
    this.prefix,
    this.suffix,
    this.interval = const Duration(seconds: 1),
    this.onFinish,
    this.onChange,
    this.style,
    this.titleStyle,
    this.valueStyle,
    this.semanticLabel,
  });

  /// 倒计时的目标时刻。
  final DateTime value;

  /// 倒计时标题。
  final Object? title;

  /// 显示格式，支持 DD、HH、mm、ss、SSS 占位。
  final String format;

  /// 读数前置内容。
  final Object? prefix;

  /// 读数后置内容。
  final Object? suffix;

  /// 剩余时长刷新间隔。
  final Duration interval;

  /// 到达目标时刻后的通知。
  final VoidCallback? onFinish;

  /// 剩余时长更新通知。
  final ValueChanged<Duration>? onChange;

  /// 组件根样式。
  final ElStyle? style;

  /// 标题样式。
  final ElStyle? titleStyle;

  /// 倒计时读数样式。
  final ElStyle? valueStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).countdownBuilder!(context, this);
}
