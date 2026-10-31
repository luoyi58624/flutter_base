import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 头像的几何形状。
enum ElAvatarShape {
  /// 圆形头像。
  circle,

  /// 方形头像。
  square,
}

/// 头像公共声明。
class ElAvatar extends StatelessWidget {
  /// 创建头像公共声明。
  const ElAvatar({
    super.key,
    this.child,
    this.icon,
    this.src,
    this.alt,
    this.size,
    this.shape,
    this.fit = BoxFit.cover,
    this.onTap,
    this.disabled = false,
    this.style,
    this.semanticLabel,
  }) : assert(size == null || size >= 0, 'size 不能为负');

  /// 图片与图标之外的头像内容。
  final Object? child;

  /// 头像图标，接受 IconData 或 Widget。
  final Object? icon;

  /// 头像图片地址。
  final String? src;

  /// 图片替代文字。
  final String? alt;

  /// 显式头像边长，未指定时由品牌实现决定。
  final double? size;

  /// 头像形状，未指定时可由头像组提供。
  final ElAvatarShape? shape;

  /// 图片填充方式。
  final BoxFit fit;

  /// 头像激活回调。
  final VoidCallback? onTap;

  /// 禁止头像交互。
  final bool disabled;

  /// 组件根样式。
  final ElStyle? style;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).avatarBuilder!(context, this);
}

/// 头像组公共声明。
class ElAvatarGroup extends StatelessWidget {
  /// 创建头像组公共声明。
  const ElAvatarGroup({
    super.key,
    required this.children,
    this.size,
    this.shape,
    this.max,
    this.gap = -8,
    this.style,
    this.collapseStyle,
    this.semanticLabel,
  }) : assert(size == null || size >= 0, 'size 不能为负'),
       assert(max == null || max >= 0, 'max 不能为负');

  /// 头像成员列表。
  final List<Widget> children;

  /// 成员未显式指定时采用的头像边长。
  final double? size;

  /// 成员未显式指定时采用的头像形状。
  final ElAvatarShape? shape;

  /// 最多显示的头像数量，null 表示全部。
  final int? max;

  /// 相邻头像的逻辑间距，负值表示叠放。
  final double gap;

  /// 组件根样式。
  final ElStyle? style;

  /// 折叠数量提示的样式。
  final ElStyle? collapseStyle;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).avatarGroupBuilder!(context, this);
}
