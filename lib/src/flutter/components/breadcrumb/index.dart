import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 面包屑路径与分隔内容的公共声明。
class ElBreadcrumb extends StatelessWidget {
  /// 创建面包屑配置，不生成条目上下文。
  const ElBreadcrumb({
    super.key,
    required this.children,
    this.separator = '/',
    this.style,
    this.separatorStyle,
    this.semanticLabel,
  });

  /// 路径条目，通常为 ElBreadcrumbItem。
  final List<Widget> children;

  /// 分隔内容，接受文字、图标或 Widget。
  final Object separator;

  /// 路径容器样式。
  final ElStyle? style;

  /// 分隔内容样式。
  final ElStyle? separatorStyle;

  /// 路径区域的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).breadcrumbBuilder!(context, this);
}

/// 面包屑条目内容与动作的公共声明。
class ElBreadcrumbItem extends StatelessWidget {
  /// 创建路径条目配置。
  const ElBreadcrumbItem({
    super.key,
    this.child,
    this.onTap,
    this.style,
    this.semanticLabel,
  });

  /// 条目内容。
  final Object? child;

  /// 可选的条目激活动作。
  final VoidCallback? onTap;

  /// 条目样式。
  final ElStyle? style;

  /// 条目的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).breadcrumbItemBuilder!(context, this);
}
