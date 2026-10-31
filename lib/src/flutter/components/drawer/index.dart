import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 同一份导航内容的侧栏及模态抽屉布局声明。
class ElDrawer extends StatelessWidget {
  /// 创建导航面板配置，与反馈 DrawerService 无关。
  const ElDrawer({
    super.key,
    required this.child,
    this.width = 280,
    this.height,
    this.sidebar = true,
    this.fillHeight = true,
    this.alignBottom = false,
    this.expandTop = false,
    this.keepAlive = true,
    this.dismissible = true,
    this.showCloseButton = true,
    this.enableDrag = true,
    this.style,
  });

  /// 导航内容。
  final Widget child;

  /// 面板的逻辑宽度。
  final double width;

  /// 桌面面板的显式高度。
  final double? height;

  /// 是否允许桌面常驻侧栏形态。
  final bool sidebar;

  /// 桌面面板是否撑满可用高度。
  final bool fillHeight;

  /// 自然高度或指定高度的桌面面板是否贴底。
  final bool alignBottom;

  /// 桌面侧栏是否延伸到页面顶部。
  final bool expandTop;

  /// 隐藏后是否保留内容状态。
  final bool keepAlive;

  /// 是否允许点击遮罩关闭。
  final bool dismissible;

  /// 模态抽屉是否显示关闭入口。
  final bool showCloseButton;

  /// 是否允许横向拖动关闭。
  final bool enableDrag;

  /// 面板样式。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).drawerBuilder!(context, this);
}
