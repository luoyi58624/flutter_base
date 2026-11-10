import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../list/sliver_list.dart' show ElSliverList;
import 'scroll_position.dart' show ScrollHostPosition;

/// 基于官方 [Scrollable] 与 [Viewport] 的滚动容器。
///
/// 默认构造直接接收 children，全部挂载并按自然尺寸排列，只绘制可见部分；
/// [ElScroll.sliver] 接收 Sliver，用于回收列表、固定头部等组合。
///
/// 同轴嵌套时自动接力：一次拖动只属于一层，起手时本层在拖动方向已经贴边，
/// 就交给最近的可滚动同轴祖先；本层一旦开始消费，途中撞到边界也不换层，
/// 释放后的惯性同样留在本层。整条链都贴边时由最外层按自身物理处理。
/// 需要折叠头这类先于正文消费位移的效果时，用 ElNestedScroll 包住本组件。
class ElScroll extends HookWidget {
  /// 创建直接排列 [children] 的滚动容器。
  const ElScroll({
    super.key,
    required List<Widget> this.children,
    this.controller,
    this.physics,
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
    useEffect(() => host.dispose, const []);
    useEffect(() {
      host.bind(controller);
      return () => host.bind(null);
    }, [controller]);

    final direction = getAxisDirectionFromAxisReverseAndDirectionality(context, axis, reverse);
    final slivers =
        this.slivers ??
        [
          SliverPadding(
            padding: padding,
            sliver: ElSliverList(spacing: gap, stretch: true, children: children!),
          ),
        ];
    return Scrollable(
      controller: host,
      physics: physics,
      axisDirection: direction,
      clipBehavior: clipBehavior,
      viewportBuilder: (context, offset) =>
          Viewport(axisDirection: direction, offset: offset, clipBehavior: clipBehavior, slivers: slivers),
    );
  }
}

/// 始终交给 [Scrollable] 的内部控制器，保证位置类型不受调用方控制器影响。
final class _HostController extends ScrollController {
  ScrollController? _user;

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
  }

  @override
  void detach(ScrollPosition position) {
    _user?.detach(position);
    super.detach(position);
  }
}
