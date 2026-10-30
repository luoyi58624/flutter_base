part of '../virtual/virtual_pipeline.dart';

/// 为真实滚动 item State 提供 sticky 布局声明与 pinned 状态。
///
/// sticky 由宿主直接执行布局、绘制、命中与保活；默认构建方法不增加包装。
mixin ElStickyMixin<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  /// item 钉在主轴视觉首边时保留的距离；null 表示当前不参与 sticky。
  @protected
  double? get stickyOffset => 0.0;

  /// 是否启用 sticky 布局所有权。
  @protected
  bool get stickyEnabled => true;

  /// 是否持续订阅 item 几何；false 时只在 pinned 状态翻转时重建。
  @protected
  bool get stickyListenProgress => false;

  @override
  double? get scrollItemStickyOffset => stickyEnabled ? stickyOffset : null;

  @override
  bool get listenScrollItem => stickyListenProgress || super.listenScrollItem;

  /// 当前 item 是否正被钉住。
  bool get isStickyPinned => scrollItemSnapshot.isPinned;

  /// sticky 默认不需要视觉包装；高级效果可覆写并读取 [isStickyPinned]。
  Widget buildSticky(BuildContext context, {required Widget child}) => child;

  @override
  void onScrollItemUpdate(ElScrollItemUpdateDetails details) {
    final pinnedChanged = details.previousSnapshot.isPinned != details.snapshot.isPinned;
    super.onScrollItemUpdate(details);
    if (pinnedChanged && !listenScrollItem) _scheduleScrollMixinRebuild();
  }
}
