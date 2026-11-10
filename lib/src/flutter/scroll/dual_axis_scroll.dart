import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

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
    this.widthListenable,
    this.physics,
    this.scrollCacheExtent,
    this.scrollbars = true,
  });

  /// 横向滚动位置。
  final ScrollController horizontalController;

  /// 纵向滚动位置。
  final ScrollController verticalController;

  /// 布局期按视口宽度给出内容宽度；结果小于视口时按视口宽度铺满。
  ///
  /// 在布局期求值，列宽等由同帧前序布局得出的几何可以直接读取。
  final double Function(double viewportWidth) contentWidth;

  /// [contentWidth] 依赖的值变化时通知重新求宽，例如编辑器在行布局后更新最长行宽。
  ///
  /// 帧内的通知推迟到帧尾重新布局，不在布局期间改动祖先。
  final Listenable? widthListenable;

  /// 纵向滚动的 Sliver。
  final List<Widget> slivers;

  /// 两个方向共用的滚动物理，缺省读取环境 ScrollConfiguration。
  final ScrollPhysics? physics;

  /// 两个方向视口的预布局范围，含义同 [ElScroll.scrollCacheExtent]。
  final ScrollCacheExtent? scrollCacheExtent;

  /// 是否在视口边缘安装两条平台滚动条。
  final bool scrollbars;

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
            _ContentWidth(
              viewportWidth: constraints.maxWidth,
              contentWidth: contentWidth,
              listenable: widthListenable,
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
    if (!scrollbars) return scroll;
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

class _ContentWidth extends SingleChildRenderObjectWidget {
  const _ContentWidth({required this.viewportWidth, required this.contentWidth, this.listenable, super.child});

  final double viewportWidth;
  final double Function(double viewportWidth) contentWidth;
  final Listenable? listenable;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderContentWidth(viewportWidth, contentWidth, listenable);

  @override
  void updateRenderObject(BuildContext context, _RenderContentWidth renderObject) {
    renderObject
      ..viewportWidth = viewportWidth
      ..contentWidth = contentWidth
      ..listenable = listenable;
  }
}

/// 布局时求内容宽度；子树布局中得出的新宽度本轮复核，其余帧内通知推迟到帧尾布局。
class _RenderContentWidth extends RenderProxyBox {
  _RenderContentWidth(this._viewportWidth, this._contentWidth, this._listenable);

  double _viewportWidth;
  set viewportWidth(double value) {
    if (value == _viewportWidth) return;
    _viewportWidth = value;
    markNeedsLayout();
  }

  double Function(double viewportWidth) _contentWidth;
  set contentWidth(double Function(double viewportWidth) value) {
    if (identical(value, _contentWidth)) return;
    _contentWidth = value;
    markNeedsLayout();
  }

  Listenable? _listenable;
  set listenable(Listenable? value) {
    if (identical(value, _listenable)) return;
    if (attached) _listenable?.removeListener(_widthChanged);
    _listenable = value;
    if (attached) value?.addListener(_widthChanged);
    markNeedsLayout();
  }

  bool _relayoutScheduled = false;
  bool _layingOut = false;

  void _widthChanged() {
    // 子树布局中得出的新宽度由本轮 performLayout 复核，不需要另排布局。
    if (_layingOut) return;
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      markNeedsLayout();
      return;
    }
    if (_relayoutScheduled) return;
    _relayoutScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _relayoutScheduled = false;
      if (attached) markNeedsLayout();
    });
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenable?.addListener(_widthChanged);
  }

  @override
  void detach() {
    _listenable?.removeListener(_widthChanged);
    super.detach();
  }

  double _resolveWidth() => math.max(_contentWidth(_viewportWidth), _viewportWidth);

  @override
  void performLayout() {
    final child = this.child!;
    _layingOut = true;
    try {
      // 内容宽度可能在子树布局中才测出（例如编辑器的最长行），同一轮按新宽度再排，最多补两次。
      var width = _resolveWidth();
      for (var pass = 0; pass < 3; pass++) {
        child.layout(constraints.tighten(width: width), parentUsesSize: true);
        final next = _resolveWidth();
        if ((next - width).abs() <= precisionErrorTolerance) break;
        width = next;
      }
    } finally {
      _layingOut = false;
    }
    size = constraints.constrain(child.size);
  }
}
