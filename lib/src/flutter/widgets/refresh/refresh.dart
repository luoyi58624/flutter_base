import 'package:flutter/widgets.dart';

import '../../scroll/nested/nested_scroll_chain.dart' show ElNestedScrollParent;
import '../../scroll/nested/scroll_delta_source.dart' show ElScrollDeltaSource;
import 'refresh_host.dart' show RefreshHost, RefreshScrollLink;
import 'refresher.dart' show ElRefreshEdge, ElRefresher;
import 'default_refresher.dart' show resolveDefaultRefresher;
import '../../scroll/nested/nested_scroll.dart' show ElNestedScroll;

/// 在标准 Scrollable 外添加刷新状态和指示器，不更换子树的 Sliver 与拖拽识别器。
///
/// 内容拖拽由最近的 [ElScroll] 接管；本组件通过其位置账本先回收已有拉距，
/// 正文到边界后才分配新的拉距。无须让业务传入固定行高或内部控制器。
class ElRefresh extends StatefulWidget {
  /// 创建与滚动视图联动的刷新器。
  const ElRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.refresher,
    this.edge = ElRefreshEdge.leading,
    this.axisDirection = AxisDirection.down,
  });

  /// 刷新回调，只在真实松手且仍达到触发阈值时执行。
  final Future<void> Function() onRefresh;

  /// 需要刷新的 ElScroll 子树。
  final Widget child;

  /// 刷新器的外观与物理策略；null 使用平台默认实现。
  final ElRefresher? refresher;

  /// 绑定的刷新边缘。
  final ElRefreshEdge edge;

  /// 内容的实际滚动轴方向，反向列表须传入对应方向。
  final AxisDirection axisDirection;

  @override
  State<ElRefresh> createState() => _RefreshState();
}

class _RefreshState extends State<ElRefresh> {
  late final _link = RefreshScrollLink();
  late final _participant = _RefreshParticipant(_link);

  @override
  Widget build(BuildContext context) {
    final refresher = widget.refresher ?? resolveDefaultRefresher();
    _participant.axisDirection = widget.axisDirection;
    return RefreshHost(
      refresher: refresher,
      physics: ScrollConfiguration.of(context).getScrollPhysics(context),
      onRefresh: widget.onRefresh,
      axisDirection: widget.axisDirection,
      edge: widget.edge,
      link: _link,
      child: ElRefreshScope(
        link: _link,
        child: ElNestedScroll(parent: _participant, child: widget.child),
      ),
    );
  }
}

class _RefreshParticipant extends ElNestedScrollParent {
  _RefreshParticipant(this.link);

  final RefreshScrollLink link;
  AxisDirection axisDirection = AxisDirection.down;

  // position.applyUserOffset 的输入已按 reverse 翻过轴，旧刷新状态机使用的则是手指方向。
  double get _orientation => axisDirectionIsReversed(axisDirection) ? -1.0 : 1.0;

  @override
  double onNestedPreScroll(double delta, ElScrollDeltaSource source) =>
      link.consumeActive(delta * _orientation, source) * _orientation;

  @override
  double onNestedPostScroll(double unconsumed, ElScrollDeltaSource source) =>
      link.consumeBoundaryPull(unconsumed * _orientation, source) * _orientation;

  @override
  double onNestedPreFling(double velocity) => link.releaseInput(velocity * _orientation) * _orientation;

  @override
  void onNestedScrollCancel() => link.cancelInput();
}

/// 向 ElScroll 提供最近一层刷新输入接线；null 会遮断更外层刷新作用域。
///
/// 此类型仅供滚动实现内部连接，不经包的公共入口导出。
class ElRefreshScope extends InheritedWidget {
  /// 创建内部刷新作用域。
  const ElRefreshScope({super.key, required this.link, required super.child});

  /// 这一层绑定的刷新输入。
  final RefreshScrollLink? link;

  /// 返回当前视口对应的刷新输入。
  static RefreshScrollLink? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ElRefreshScope>()?.link;

  @override
  bool updateShouldNotify(ElRefreshScope oldWidget) => !identical(link, oldWidget.link);
}
