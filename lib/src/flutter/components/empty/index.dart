import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 空状态公共声明。
class ElEmpty extends StatelessWidget {
  /// 创建空状态公共声明。
  const ElEmpty({
    super.key,
    this.description,
    this.image,
    this.imageSize,
    this.child,
    this.style,
    this.imageStyle,
    this.descriptionStyle,
    this.semanticLabel,
  });

  /// 空状态说明内容。
  final Object? description;

  /// 自定义插画地址或 Widget。
  final Object? image;

  /// 插画的显式逻辑边长。
  final double? imageSize;

  /// 底部操作区域内容。
  final Object? child;

  /// 组件根样式。
  final ElStyle? style;

  /// 插画样式。
  final ElStyle? imageStyle;

  /// 说明内容样式。
  final ElStyle? descriptionStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).emptyBuilder!(context, this);
}
