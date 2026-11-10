import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show FloatingHeaderSnapConfiguration;

import '../scroll/nested/nested_scroll_chain.dart' show ElNestedScrollParent;
import '../scroll/nested/scroll_delta_source.dart' show ElScrollDeltaSource;
import '../scroll/scroll_position.dart' show ScrollHostPosition;

/// 根据滚动进度构建折叠头。0 为展开，1 为收起。
typedef ElSliverCollapseBuilder = Widget Function(BuildContext context, double progress);

/// Sliver 导航折叠入口；三种命名构造分别使用不同的实现，不共享复杂状态机。
///
/// [ElSliverCollapse.scroll] 将折叠距离交给官方 PersistentHeader；
/// [ElSliverCollapse.floating] 直接使用官方 FloatingHeader；
/// [ElSliverCollapse.bibi] 则在任意正文位置先消费拖拽位移，再由官方 Header 布局。
abstract class ElSliverCollapse extends StatelessWidget {
  /// 仅作为三个独立实现的公共 Sliver 类型。
  const ElSliverCollapse({super.key});

  /// 正常随滚动位置收缩；可以固定、浮动，也可以使用官方 floating snap。
  const factory ElSliverCollapse.scroll({
    Key? key,
    required double minExtent,
    required double maxExtent,
    required ElSliverCollapseBuilder builder,
    bool pinned,
    bool floating,
    bool snap,
  }) = _ScrollCollapse;

  /// 在正文任意位置反向滚动时显示导航，交给官方 FloatingHeader。
  const factory ElSliverCollapse.floating({Key? key, required Widget child, FloatingHeaderSnapMode snapMode}) =
      _FloatingCollapse;

  /// Bibi 型：白底导航固定，内容淡出，页头优先消费拖拽，松手或按住时以 50% 吸附。
  ///
  /// [compactExtent] 和 [contentExtent] 分别对应固定导航与可折叠内容的自然占位；
  /// 不要求正文为固定高度。此形态放入 ElScroll.sliver，不能挂入任意 CustomScrollView。
  const factory ElSliverCollapse.bibi({
    Key? key,
    required Widget compact,
    required Widget content,
    double compactExtent,
    double contentExtent,
    Color backgroundColor,
    Duration holdSnapDelay,
    Duration snapDuration,
    ValueChanged<double>? onProgressChanged,
  }) = _BibiCollapse;
}

class _ScrollCollapse extends ElSliverCollapse {
  const _ScrollCollapse({
    super.key,
    required this.minExtent,
    required this.maxExtent,
    required this.builder,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
  }) : assert(minExtent >= 0),
       assert(maxExtent >= minExtent);

  final double minExtent;
  final double maxExtent;
  final ElSliverCollapseBuilder builder;
  final bool pinned;
  final bool floating;
  final bool snap;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: pinned,
    floating: floating,
    delegate: _ProgressHeader(minExtent, maxExtent, builder, snap && floating),
  );
}

class _ProgressHeader extends SliverPersistentHeaderDelegate {
  _ProgressHeader(this.minExtent, this.maxExtent, this.builder, this.snap);

  @override
  final double minExtent;
  @override
  final double maxExtent;
  final ElSliverCollapseBuilder builder;
  final bool snap;

  @override
  FloatingHeaderSnapConfiguration? get snapConfiguration =>
      snap ? FloatingHeaderSnapConfiguration(duration: Duration(milliseconds: 200), curve: Curves.easeOutCubic) : null;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final progress = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0).toDouble();
    // PersistentHeader 的 child 必须占满自身给出的 extent；业务不需要手动 SizedBox.expand。
    return SizedBox.expand(child: builder(context, progress));
  }

  @override
  bool shouldRebuild(covariant _ProgressHeader old) =>
      minExtent != old.minExtent || maxExtent != old.maxExtent || builder != old.builder || snap != old.snap;
}

class _FloatingCollapse extends ElSliverCollapse {
  const _FloatingCollapse({super.key, required this.child, this.snapMode = FloatingHeaderSnapMode.overlay});

  final Widget child;
  final FloatingHeaderSnapMode snapMode;

  @override
  Widget build(BuildContext context) => SliverFloatingHeader(snapMode: snapMode, child: child);
}

class _BibiCollapse extends ElSliverCollapse {
  const _BibiCollapse({
    super.key,
    required this.compact,
    required this.content,
    this.compactExtent = 56,
    this.contentExtent = 58,
    this.backgroundColor = Colors.white,
    this.holdSnapDelay = const Duration(milliseconds: 160),
    this.snapDuration = const Duration(milliseconds: 180),
    this.onProgressChanged,
  }) : assert(compactExtent > 0),
       assert(contentExtent > 0);

  final Widget compact;
  final Widget content;
  final double compactExtent;
  final double contentExtent;
  final Color backgroundColor;
  final Duration holdSnapDelay;
  final Duration snapDuration;
  final ValueChanged<double>? onProgressChanged;

  @override
  Widget build(BuildContext context) => _ActiveCollapseHeader(config: this);
}

class _ActiveCollapseHeader extends StatefulWidget {
  const _ActiveCollapseHeader({required this.config});

  final _BibiCollapse config;

  @override
  State<_ActiveCollapseHeader> createState() => _ActiveCollapseHeaderState();
}

class _ActiveCollapseHeaderState extends State<_ActiveCollapseHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController.unbounded(vsync: this);
  late final _CollapseMotion _motion = _CollapseMotion(_progress);
  ScrollHostPosition? _position;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_changed);
    _configure();
  }

  void _configure() {
    _motion
      ..contentExtent = widget.config.contentExtent
      ..holdSnapDelay = widget.config.holdSnapDelay
      ..snapDuration = widget.config.snapDuration;
  }

  void _changed() {
    if (!mounted) return;
    widget.config.onProgressChanged?.call(_progress.value.clamp(0.0, 1.0).toDouble());
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    assert(position is ScrollHostPosition, 'ElSliverCollapse.bibi 必须放在 ElScroll.sliver 中');
    if (identical(position, _position)) return;
    _position?.removeEdgeParticipant(_motion);
    _position?.isScrollingNotifier.removeListener(_motion.onScrollingChanged);
    _position = position is ScrollHostPosition ? position : null;
    _motion.position = _position;
    _position?.addEdgeParticipant(_motion);
    _position?.isScrollingNotifier.addListener(_motion.onScrollingChanged);
  }

  @override
  void didUpdateWidget(covariant _ActiveCollapseHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.contentExtent != widget.config.contentExtent) {
      // 尺寸变化保留折叠比例，不保留过期的像素距离。
      _motion.cancelPendingSnap();
    }
    _configure();
  }

  @override
  void dispose() {
    _position?.removeEdgeParticipant(_motion);
    _position?.isScrollingNotifier.removeListener(_motion.onScrollingChanged);
    _motion.dispose();
    _progress
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final value = _progress.value.clamp(0.0, 1.0).toDouble();
    final visible = config.contentExtent * (1 - value);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _ActiveHeader(
        extent: config.compactExtent + visible,
        compactExtent: config.compactExtent,
        contentExtent: config.contentExtent,
        compact: config.compact,
        content: config.content,
        backgroundColor: config.backgroundColor,
        progress: value,
      ),
    );
  }
}

class _CollapseMotion extends ElNestedScrollParent {
  _CollapseMotion(this.controller);

  final AnimationController controller;
  ScrollHostPosition? position;
  double contentExtent = 58;
  Duration holdSnapDelay = Duration(milliseconds: 160);
  Duration snapDuration = Duration(milliseconds: 180);

  Timer? _idleTimer;
  bool _disposed = false;

  @override
  Axis? get nestedScrollAxis => Axis.vertical;

  @override
  void onNestedScrollStart(Axis axis, ElScrollDeltaSource source) {
    cancelPendingSnap();
    controller.stop();
  }

  @override
  bool canConsumeNestedPreScroll(double delta, ElScrollDeltaSource source) {
    if (source != ElScrollDeltaSource.pointerScroll || contentExtent <= 0 || _disposed) return false;
    final value = controller.value;
    return delta > 0 ? value < 1 : value > 0;
  }

  @override
  double onNestedPreScroll(double delta, ElScrollDeltaSource source) {
    if (_disposed || delta == 0 || contentExtent <= 0) return 0;
    // touchDrag/fling 使用手指方向：上推为负（收起），下拉为正（展开）。
    final signed = source == ElScrollDeltaSource.pointerScroll ? -delta : delta;
    final current = controller.value.clamp(0.0, 1.0).toDouble();
    final next = (current - signed / contentExtent).clamp(0.0, 1.0).toDouble();
    final consumed = (current - next) * contentExtent;
    if (consumed == 0) return 0;
    cancelPendingSnap();
    controller.stop();
    controller.value = next;
    if (source == ElScrollDeltaSource.touchDrag || source == ElScrollDeltaSource.pointerScroll) {
      // 手指不离屏或滚轮停止输入，超过该间隔也自动吸附。
      _scheduleSnap(holdSnapDelay);
    }
    return source == ElScrollDeltaSource.pointerScroll ? -consumed : consumed;
  }

  @override
  double onNestedPreFling(double velocity) {
    // 不吞掉真实惯性：每帧先折叠，剩余位移继续交给正文。
    return velocity;
  }

  @override
  void onNestedScrollEnd() {
    if (position?.isScrollingNotifier.value == false) _scheduleSnap(Duration.zero);
  }

  @override
  void onNestedScrollCancel() => _scheduleSnap(Duration.zero);

  void onScrollingChanged() {
    if (!_disposed && position?.isScrollingNotifier.value == false) _scheduleSnap(Duration.zero);
  }

  void cancelPendingSnap() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _scheduleSnap(Duration delay) {
    cancelPendingSnap();
    final value = controller.value;
    if (value <= 0 || value >= 1 || _disposed) return;
    _idleTimer = Timer(delay, () {
      _idleTimer = null;
      if (_disposed) return;
      final target = controller.value >= .5 ? 1.0 : 0.0;
      controller.animateTo(target, duration: snapDuration, curve: Curves.easeInOutSine);
    });
  }

  void dispose() {
    _disposed = true;
    cancelPendingSnap();
  }
}

/// 在任意正文位置都固定到起点；真实布局范围与可见内容一起收缩。
class _ActiveHeader extends SliverPersistentHeaderDelegate {
  _ActiveHeader({
    required this.extent,
    required this.compactExtent,
    required this.contentExtent,
    required this.compact,
    required this.content,
    required this.backgroundColor,
    required this.progress,
  });

  final double extent;
  final double compactExtent;
  final double contentExtent;
  final Widget compact;
  final Widget content;
  final Color backgroundColor;
  final double progress;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(
    color: backgroundColor,
    child: Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        // Bibi 的搜索区在频道栏上方：折叠时搜索区向上离场，频道栏同步上移并吸顶。
        Positioned(
          top: -contentExtent * progress,
          left: 0,
          right: 0,
          height: contentExtent,
          child: Opacity(opacity: 1 - progress, child: content),
        ),
        Positioned(top: contentExtent * (1 - progress), left: 0, right: 0, height: compactExtent, child: compact),
      ],
    ),
  );

  @override
  bool shouldRebuild(covariant _ActiveHeader old) =>
      extent != old.extent ||
      compactExtent != old.compactExtent ||
      contentExtent != old.contentExtent ||
      compact != old.compact ||
      content != old.content ||
      backgroundColor != old.backgroundColor ||
      progress != old.progress;
}
