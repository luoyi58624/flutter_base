import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'scroll.dart' show ElScroll;
import 'scroll_behavior.dart' show buildElScrollbar;

/// 双轴滚动：外层横向 ElScroll 承载按内容宽度展开的纵向 Sliver，两条滚动条都钉在视口边缘。
///
/// 纵向内容位于横向滚动内部，它自己的滚动条会落在内容最右端；所以内部关闭自动滚动条，
/// 由本组件在外层视口统一安装，纵向条监听第 1 层的滚动通知。
class DualAxisScroll extends StatelessWidget {
  /// 创建双轴滚动。
  const DualAxisScroll({
    super.key,
    required this.horizontalController,
    required this.verticalController,
    required this.contentWidth,
    required this.slivers,
    this.physics,
    this.scrollCacheExtent,
  });

  /// 横向滚动位置。
  final ScrollController horizontalController;

  /// 纵向滚动位置。
  final ScrollController verticalController;

  /// 布局期按视口宽度给出内容宽度；结果小于视口时按视口宽度铺满。
  ///
  /// 在布局期求值，列宽等由同帧前序布局得出的几何可以直接读取。
  final double Function(double viewportWidth) contentWidth;

  /// 纵向滚动的 Sliver。
  final List<Widget> slivers;

  /// 两个方向共用的滚动物理，缺省读取环境 ScrollConfiguration。
  final ScrollPhysics? physics;

  /// 两个方向视口的预布局范围，含义同 [ElScroll.scrollCacheExtent]。
  final ScrollCacheExtent? scrollCacheExtent;

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    final platform = behavior.getPlatform(context);
    final scroll = ScrollConfiguration(
      behavior: behavior.copyWith(scrollbars: false),
      child: LayoutBuilder(
        builder: (context, constraints) => ElScroll(
          axis: .horizontal,
          controller: horizontalController,
          physics: physics,
          scrollCacheExtent: scrollCacheExtent,
          children: [
            SizedBox(
              width: math.max(contentWidth(constraints.maxWidth), constraints.maxWidth),
              child: ElScroll.sliver(
                controller: verticalController,
                physics: physics,
                scrollCacheExtent: scrollCacheExtent,
                slivers: slivers,
              ),
            ),
          ],
        ),
      ),
    );
    final vertical = buildElScrollbar(
      context,
      scroll,
      ScrollableDetails.vertical(controller: verticalController),
      platform: platform,
      depth: 1,
    );
    return buildElScrollbar(
      context,
      vertical,
      ScrollableDetails.horizontal(controller: horizontalController),
      platform: platform,
    );
  }
}
