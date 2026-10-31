import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 脚手架控制命令的接口，运行状态与通知由未来实现持有。
abstract interface class ElScaffoldController implements Listenable {
  /// 起始侧抽屉是否展开。
  bool get drawerOpen;

  /// 设置起始侧抽屉的目标开合状态。
  set drawerOpen(bool value);

  /// 结束侧抽屉是否展开。
  bool get endDrawerOpen;

  /// 设置结束侧抽屉的目标开合状态。
  set endDrawerOpen(bool value);

  /// 桌面侧栏是否折叠。
  bool get collapsed;

  /// 设置桌面侧栏的目标折叠状态。
  set collapsed(bool value);

  /// 已挂载页面的滚动控制器。
  ScrollController? get scrollController;

  /// 请求打开起始侧抽屉。
  void openDrawer();

  /// 请求关闭起始侧抽屉。
  void closeDrawer();

  /// 请求切换起始侧抽屉。
  void toggleDrawer();

  /// 请求打开结束侧抽屉。
  void openEndDrawer();

  /// 请求关闭结束侧抽屉。
  void closeEndDrawer();

  /// 请求切换结束侧抽屉。
  void toggleEndDrawer();

  /// 请求切换桌面侧栏折叠状态。
  void toggleCollapsed();

  /// 释放控制器持有的资源。
  void dispose();
}

/// 已挂载页面的查询与命令契约，不提供 State 或上下文实现。
abstract interface class ElScaffoldState {
  /// 当前正文的滚动控制器。
  ScrollController get scrollController;

  /// 当前页面的控制器命令接口。
  ElScaffoldController get controller;

  /// 是否声明起始侧导航。
  bool get hasDrawer;

  /// 是否声明结束侧导航。
  bool get hasEndDrawer;

  /// 起始侧当前是否为常驻侧栏。
  bool get drawerIsSidebar;

  /// 结束侧当前是否为常驻侧栏。
  bool get endDrawerIsSidebar;

  /// 起始侧模态抽屉是否展开。
  bool get isDrawerOpen;

  /// 结束侧模态抽屉是否展开。
  bool get isEndDrawerOpen;

  /// 请求打开起始侧抽屉。
  void openDrawer();

  /// 请求关闭起始侧抽屉。
  void closeDrawer();

  /// 请求切换起始侧抽屉。
  void toggleDrawer();

  /// 请求打开结束侧抽屉。
  void openEndDrawer();

  /// 请求关闭结束侧抽屉。
  void closeEndDrawer();

  /// 请求切换结束侧抽屉。
  void toggleEndDrawer();

  /// 请求切换桌面侧栏折叠状态。
  void toggleCollapsed();
}

/// 页面导航、正文、滚动与侧栏配置的公共声明。
class ElScaffold extends StatelessWidget {
  /// 创建页面骨架配置，不建立滚动或抽屉宿主。
  const ElScaffold({
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.body = const [],
    this.viewport,
    this.scrollController,
    this.controller,
    this.onRefresh,
    this.refresher,
    this.physics,
    this.scrollbar,
    this.smoothScroll,
    this.drawer,
    this.endDrawer,
    this.drawerEdgeDragWidth = 20,
    this.endDrawerEdgeDragWidth = 20,
    this.mobile,
  });

  /// 页面顶部导航配置。
  final ElAppBar? appBar;

  /// 固定底部导航或自定义组件。
  final Widget? bottomNavigationBar;

  /// 由骨架组织滚动的正文成员。
  final List<Widget> body;

  /// 自行管理滚动或嵌套导航的固定视口正文。
  final Widget? viewport;

  /// 正文滚动控制器，生命周期由调用方管理。
  final ScrollController? scrollController;

  /// 页面抽屉与侧栏命令接口。
  final ElScaffoldController? controller;

  /// 下拉刷新通知。
  final Future<void> Function()? onRefresh;

  /// 刷新外观配置。
  final ElRefresher? refresher;

  /// 正文滚动物理配置。
  final ScrollPhysics? physics;

  /// 页面滚动条配置。
  final ElScrollbar? scrollbar;

  /// 页面平滑滚动配置。
  final ElSmoothScroll? smoothScroll;

  /// 起始侧导航内容。
  final Widget? drawer;

  /// 结束侧导航内容。
  final Widget? endDrawer;

  /// 起始侧边缘唤出宽度，0..1 表示页面宽度比例。
  final double drawerEdgeDragWidth;

  /// 结束侧边缘唤出宽度，0..1 表示页面宽度比例。
  final double endDrawerEdgeDragWidth;

  /// 显式选择移动或桌面布局，null 交由实现判断。
  final bool? mobile;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).scaffoldBuilder!(context, this);
}
