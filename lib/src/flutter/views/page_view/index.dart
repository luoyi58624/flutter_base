import 'package:flutter/widgets.dart';

/// 使用官方手势、控制器和分页物理的分页视图。
///
/// 同轴 ElScroll 仅在起手已贴边时让本视图接管，途中撞边界不换层。
/// 页面状态保留沿用官方 AutomaticKeepAliveClientMixin 与 PageStorage。
class ElPageView extends PageView {
  /// 创建使用官方 PageController 的分页视图。
  ElPageView({
    super.key,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.physics,
    super.pageSnapping,
    super.onPageChanged,
    super.children,
    super.dragStartBehavior,
    super.allowImplicitScrolling,
    super.restorationId,
    super.clipBehavior,
    super.scrollBehavior,
    super.padEnds,
    super.hitTestBehavior,
  });

  /// 按需构建页面，构建与回收规则沿用官方 PageView.builder。
  ElPageView.builder({
    super.key,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.physics,
    super.pageSnapping,
    super.onPageChanged,
    required super.itemBuilder,
    super.findChildIndexCallback,
    super.itemCount,
    super.dragStartBehavior,
    super.allowImplicitScrolling,
    super.restorationId,
    super.clipBehavior,
    super.scrollBehavior,
    super.padEnds,
    super.hitTestBehavior,
  }) : super.builder();
}
