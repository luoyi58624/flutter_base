import 'package:flutter/gestures.dart' show GestureBinding, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../dart/gen/index.dart' show $absent;
import '../list/sliver_list.dart' show ElSliverList;
import '../../views/scroll/smooth_scroll/smooth_pointer_scroll.dart' show SmoothPointerScrollController;
import '../../views/scroll/smooth_scroll/smooth_scroll.dart' show ElSmoothScroll;
import '../../views/view/provider.dart' show ElViewProvider;
import '../../views/scroll/refresh/refresh_host.dart' show RefreshDockPhysics, RefreshScrollLink;
import 'refresh.dart' show ElRefreshScope;
import 'scroll_position.dart' show ScrollHostPhysics, ScrollHostPosition;

/// 基于官方 [Scrollable] 与 [Viewport] 的滚动容器。
///
/// 默认构造直接接收 children，全部挂载并按自然尺寸排列，只绘制可见部分；
/// [ElScroll.sliver] 接收 Sliver，用于回收列表、固定头部等组合。
///
/// 同轴嵌套时自动接力：一次拖动只属于一层，起手时本层在拖动方向已经贴边，
/// 就交给最近的可滚动同轴祖先；本层一旦开始消费，途中撞到边界也不换层，
/// 释放后的惯性同样留在本层。整条链都贴边时由最外层按自身物理处理。
/// 需要折叠头这类先于正文消费位移的效果时，用 ElNestedScroll 包住本组件。
/// 下拉刷新有两个入口：ElRefresh 包住本组件，或把 ElSliverRefresh 放进 [ElScroll.sliver]。
class ElScroll extends HookWidget {
  /// 创建直接排列 [children] 的滚动容器。
  const ElScroll({
    super.key,
    required List<Widget> this.children,
    this.controller,
    this.physics,
    this.smoothScroll = $absent,
    this.axis = .vertical,
    this.reverse = false,
    this.padding = .zero,
    this.gap = 0,
    this.clipBehavior = .hardEdge,
  }) : slivers = null,
       assert(gap >= 0);

  /// 创建承载 [slivers] 的滚动容器，内边距与间距由各 Sliver 自己声明。
  const ElScroll.sliver({
    super.key,
    required List<Widget> this.slivers,
    this.controller,
    this.physics,
    this.smoothScroll = $absent,
    this.axis = .vertical,
    this.reverse = false,
    this.clipBehavior = .hardEdge,
  }) : children = null,
       padding = .zero,
       gap = 0;

  /// 按顺序排列的普通子项，在交叉轴上撑满视口；状态常驻，适合数量有限的内容。
  final List<Widget>? children;

  /// 按滚动顺序排列的 Sliver。
  final List<Widget>? slivers;

  /// 观察与驱动滚动位置的控制器。
  ///
  /// 位置由本组件创建，才能承担嵌套接力；控制器自定义的 createScrollPosition 不会被调用，
  /// 初始偏移与偏移保存配置仍然生效。
  final ScrollController? controller;

  /// 滚动物理，默认读取环境 [ScrollConfiguration]。
  final ScrollPhysics? physics;

  /// 鼠标滚轮平滑算法；缺省继承 ElViewProvider，显式 null 关闭。
  final Object? smoothScroll;

  /// 滚动主轴。
  final Axis axis;

  /// 是否反转滚动方向。
  final bool reverse;

  /// [children] 四周的内边距。
  final EdgeInsets padding;

  /// 相邻 [children] 之间的主轴间距。
  final double gap;

  /// 视口裁剪行为。
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final host = useMemoized(_HostController.new);
    final refreshLink = ElRefreshScope.maybeOf(context);
    final configuredSmooth = identical(smoothScroll, $absent)
        ? ElViewProvider.smoothScrollOf(context)
        : smoothScroll as ElSmoothScroll?;
    useEffect(() {
      host
        ..bind(controller)
        ..bindRefresh(refreshLink)
        ..configureSmooth(configuredSmooth);
      return host.dispose;
    }, const []);
    useValueChanged<ScrollController?, void>(controller, (_, _) {
      // useEffect(keys) 会在新 effect 挂载之后才 dispose 旧 effect，
      // 若旧清理执行 bind(null)，会把刚换上的 controller 再摘掉。
      host.bind(controller);
    });
    useValueChanged<RefreshScrollLink?, void>(refreshLink, (_, _) => host.bindRefresh(refreshLink));
    useValueChanged<ElSmoothScroll?, void>(configuredSmooth, (_, _) => host.configureSmooth(configuredSmooth));

    final direction = getAxisDirectionFromAxisReverseAndDirectionality(context, axis, reverse);
    final slivers =
        this.slivers ??
        [
          SliverPadding(
            padding: padding,
            sliver: ElSliverList(spacing: gap, stretch: true, children: children!),
          ),
        ];
    final effectivePhysics = refreshLink == null ? physics : AlwaysScrollableScrollPhysics(parent: physics);
    return Listener(
      onPointerDown: (event) => host.rawPointerDown(event.pointer),
      onPointerUp: (event) => host.rawPointerUp(event.pointer),
      onPointerCancel: (event) => host.rawPointerCancel(event.pointer),
      child: ElRefreshScope(
      link: null, // 内层 ElScroll 不能误占用外层绑定的刷新器。
      child: Scrollable(
      controller: host,
      physics: ScrollHostPhysics(
        parent: refreshLink?.movesContent == true
            ? RefreshDockPhysics(getLink: () => refreshLink, parent: effectivePhysics)
            : effectivePhysics,
      ),
      axisDirection: direction,
      clipBehavior: clipBehavior,
      viewportBuilder: (context, offset) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: (event) => host.handlePointerSignal(event, axisDirection: direction),
        child: Viewport(axisDirection: direction, offset: offset, clipBehavior: clipBehavior, slivers: slivers),
      ),
      ),
      ),
    );
  }
}

/// 始终交给 [Scrollable] 的内部控制器，保证位置类型不受调用方控制器影响。
final class _HostController extends ScrollController {
  ScrollController? _user;
  RefreshScrollLink? _refreshLink;
  ScrollPosition? _refreshPosition;
  final Set<int> _activePointers = <int>{};
  SmoothPointerScrollController? _smooth;

  void configureSmooth(ElSmoothScroll? algorithm) {
    (_smooth ??= SmoothPointerScrollController(
      position: () => position,
      targetOffsetForDelta: (delta, {from}) {
        final position = this.position;
        return ((from ?? position.pixels) + delta)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
      },
    )).algorithm = algorithm;
  }

  void handlePointerSignal(PointerSignalEvent event, {required AxisDirection axisDirection}) {
    if (event is! PointerScrollEvent || !hasClients) return;
    final position = this.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final delta = axisDirectionToAxis(axisDirection) == Axis.vertical ? event.scrollDelta.dy : event.scrollDelta.dx;
    final amount = axisDirectionIsReversed(axisDirection) ? -delta : delta;
    if (amount == 0.0 || !(_smooth?.canConsumeDelta(amount) ?? false)) return;
    // Viewport 内部监听器比官方 Scrollable 先收到信号，resolver 只执行一次处理。
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      if (signal is PointerScrollEvent && hasClients) _smooth?.applyPointerScroll(signal, amount);
    });
  }

  /// 原始终态先于识别器收到取消，标记后不再将合成 onEnd 当作真实松手。
  void rawPointerDown(int pointer) {
    if (_activePointers.isEmpty) {
      _smooth?.reset();
      for (final position in positions) {
        if (position is ScrollHostPosition) position.resetRawPointerCancellation();
      }
    }
    _activePointers.add(pointer);
  }

  void rawPointerUp(int pointer) => _activePointers.remove(pointer);

  void rawPointerCancel(int pointer) {
    _activePointers.remove(pointer);
    if (_activePointers.isNotEmpty) return;
    for (final position in positions) {
      if (position is ScrollHostPosition) position.markRawPointerCanceled();
    }
  }

  /// 把已创建的位置同步挂到调用方控制器，更换控制器不重建位置。
  void bind(ScrollController? next) {
    final previous = _user;
    if (identical(previous, next)) return;
    _user = next;
    for (final position in positions) {
      previous?.detach(position);
      next?.attach(position);
    }
  }

  /// 将实际滚动位置提供给刷新状态机；只保留当前活动的宿主位置。
  void bindRefresh(RefreshScrollLink? next) {
    if (identical(_refreshLink, next)) return;
    final previous = _refreshLink;
    if (previous != null) {
      previous.position = null;
      previous.directDragActive = null;
    }
    _refreshLink = next;
    if (next == null) return;
    for (final position in positions) {
      _bindRefreshPosition(position);
    }
  }

  void _bindRefreshPosition(ScrollPosition? position) {
    _refreshPosition = position;
    final link = _refreshLink;
    if (link == null) return;
    link.position = position == null ? null : () => position;
    link.directDragActive = position is ScrollHostPosition ? () => position.isDirectDrag : null;
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    final user = _user;
    return ScrollHostPosition(
      physics: physics,
      context: context,
      initialPixels: user?.initialScrollOffset ?? 0,
      keepScrollOffset: user?.keepScrollOffset ?? true,
      oldPosition: oldPosition,
      debugLabel: user?.debugLabel,
    );
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    _user?.attach(position);
    _bindRefreshPosition(position);
  }

  @override
  void detach(ScrollPosition position) {
    _smooth?.reset();
    if (identical(_refreshPosition, position)) _bindRefreshPosition(null);
    _user?.detach(position);
    super.detach(position);
  }

  @override
  void dispose() {
    bindRefresh(null);
    _smooth?.dispose();
    super.dispose();
  }
}
