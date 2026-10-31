import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 骨架块的语义形态。
enum ElSkeletonVariant {
  /// 普通文本占位。
  text,

  /// 正文行占位。
  p,

  /// 一级标题占位。
  h1,

  /// 三级标题占位。
  h3,

  /// 五级标题占位。
  h5,

  /// 辅助说明占位。
  caption,

  /// 按钮占位。
  button,

  /// 图片占位。
  image,

  /// 圆形占位。
  circle,

  /// 矩形占位。
  rect,
}

/// 加载骨架的公共声明。
class ElSkeleton extends StatelessWidget {
  /// 创建默认或自定义模板的骨架声明。
  const ElSkeleton({
    super.key,
    this.loading = true,
    this.rows = 3,
    this.animated = false,
    this.avatar = false,
    this.child,
    this.template,
    this.style,
    this.semanticLabel,
  });

  /// 当前是否展示加载骨架。
  final bool loading;

  /// 默认模板的正文行数，具体归一化规则由品牌实现处理。
  final num rows;

  /// 启用品牌骨架动画。
  final bool animated;

  /// 默认模板中包含头像占位。
  final bool avatar;

  /// 加载完成后的正文内容。
  final Widget? child;

  /// 自定义骨架模板，通常组合 ElSkeletonItem。
  final Widget? template;

  /// 骨架根样式。
  final ElStyle? style;

  /// 辅助技术读取的加载说明。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).skeletonBuilder!(context, this);
}

/// 单个骨架块的公共声明。
class ElSkeletonItem extends StatelessWidget {
  /// 创建指定语义形态的骨架块。
  const ElSkeletonItem({
    super.key,
    this.variant = ElSkeletonVariant.text,
    this.width,
    this.height,
    this.style,
  });

  /// 骨架块的语义形态。
  final ElSkeletonVariant variant;

  /// 显式宽度，接受逻辑像素或百分比字符串。
  final Object? width;

  /// 显式高度，接受逻辑像素或百分比字符串。
  final Object? height;

  /// 单个骨架块的样式。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).skeletonItemBuilder!(context, this);
}
