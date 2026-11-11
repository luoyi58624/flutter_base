import 'package:flutter/widgets.dart';

import '../../views/view/event/event.dart';
import '../../views/view/style/style.dart';
import '../index.dart';

/// 模态内容相对视口的停靠位置。
enum ElPopupPlacement {
  /// 居中展示。
  center,

  /// 贴近底部。
  bottom,

  /// 贴近顶部。
  top,

  /// 从左边进入。
  left,

  /// 从右边进入。
  right,
}

/// 模态弹层的内容基座，路由打开及结果返回由 el.popup 承担。
class ElPopup extends StatelessWidget {
  /// 标题和页脚接受业务 Widget，关闭时可用 Navigator.pop 返回业务值。
  const ElPopup({
    super.key,
    required this.child,
    this.title,
    this.footer,
    this.showClose = true,
    this.style,
    this.event,
    this.semanticLabel,
  });

  /// 主体内容，保留原 Widget 实例。
  final Widget child;

  /// 可选标题。
  final Object? title;

  /// 主体下方的操作内容。
  final Object? footer;

  /// 显示关闭入口。
  final bool showClose;

  /// 在品牌默认样式后合并。
  final ElStyle? style;

  /// 内容根节点事件。
  final ElEvent? event;

  /// 辅助技术读取的弹层名称。
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.popup)(context, this);
}

/// 用于说明与确认的对话框内容，操作由 footer 提供。
class ElDialog extends ElPopup {
  /// 默认通过 el.dialog 居中打开，也可停靠底部。
  const ElDialog({
    super.key,
    required super.child,
    super.title,
    super.footer,
    super.showClose = false,
    super.style,
    super.event,
    super.semanticLabel,
  });
  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.dialog)(context, this);
}

/// 停靠屏幕边缘的抽屉内容。
class ElDrawer extends ElPopup {
  /// 抽屉打开方向由 el.drawer 的 placement 决定。
  const ElDrawer({
    super.key,
    required super.child,
    super.title,
    super.footer,
    super.showClose,
    super.style,
    super.event,
    super.semanticLabel,
  });
  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.drawer)(context, this);
}

/// 非阻塞的短提示内容，持续时间由 el.toast 管理。
class ElToast extends StatelessWidget {
  /// 提示可单独嵌入页面，或交给 el.toast 显示在浮层。
  const ElToast({super.key, required this.child, this.icon, this.style, this.semanticLabel});

  /// 提示内容。
  final Object child;

  /// 可选前置图标。
  final Object? icon;

  /// 在品牌默认样式后合并。
  final ElStyle? style;

  /// 辅助名称，文字内容默认可被读出。
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.toast)(context, this);
}
