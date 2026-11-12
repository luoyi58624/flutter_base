import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, SliverPaintOrder, ViewportOffset;
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../dart/gen/index.dart' show $absent;
import '../../slivers/sliver.dart' show ElSliverList;
import 'smooth/smooth_scroll.dart' show ElSmoothScroll, resolveDefaultSmoothScroll;
import 'scroll_position.dart' show ScrollHostPhysics, ScrollHostPosition;
import 'viewport.dart' show ElShrinkWrappingViewport, ElViewport, ScrollTransparentSelectionRegistrar;

/// 基于官方 [Scrollable] 与 [Viewport] 的滚动容器。
///
/// 默认构造直接接收 children，全部挂载并按自然尺寸排列，只绘制可见部分；
/// [ElScrollView.sliver] 接收 Sliver，用于回收列表、固定头部等组合。
///
/// 同轴嵌套时自动接力：一次拖动只属于一层，起手时本层在拖动方向已经贴边，
/// 就交给最近的可滚动同轴祖先；本层一旦开始消费，途中撞到边界也不换层，
/// 释放后的惯性同样留在本层。整条链都贴边时由最外层按自身物理处理。
/// 鼠标滚轮连续输入时保留接收者，停顿满 500ms 才重新命中；移出接收区域立即交接。
/// 需要折叠头这类先于正文消费位移的效果时，用 ElNestedScroll 包住本组件。
/// 下拉刷新通过放进 [ElScrollView.sliver] 的 ElSliverRefresh 接入。
class ElScrollView extends HookWidget {
  /// 创建直接排列 [children] 的滚动容器。
  const ElScrollView({
    super.key,
    required List<Widget> this.children,
    this.controller,
    this.physics,
    this.smoothScroll = $absent,
    this.scrollDirection = .vertical,
    this.reverse = false,
    this.padding = .zero,
    this.spacing = 0,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.shrinkWrap = false,
    this.scrollCacheExtent = const ScrollCacheExtent.pixels(250),
    this.clipBehavior = .hardEdge,
    this.primary,
    this.scrollBehavior,
    this.dragStartBehavior = .start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.semanticChildCount,
    this.hitTestBehavior = .opaque,
    this.anchor = 0,
    this.paintOrder = .firstIsTop,
  }) : slivers = null,
       center = null,
       assert(controller == null || primary != true),
       assert(anchor >= 0 && anchor <= 1),
       assert(semanticChildCount == null || semanticChildCount >= 0),
       assert(spacing >= 0 && spacing < double.infinity);

  /// 创建承载 [slivers] 的滚动容器，内边距与间距由各 Sliver 自己声明。
  const ElScrollView.sliver({
    super.key,
    required List<Widget> this.slivers,
    this.center,
    this.controller,
    this.physics,
    this.smoothScroll = $absent,
    this.scrollDirection = .vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.scrollCacheExtent = const ScrollCacheExtent.pixels(250),
    this.clipBehavior = .hardEdge,
    this.primary,
    this.scrollBehavior,
    this.dragStartBehavior = .start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.semanticChildCount,
    this.hitTestBehavior = .opaque,
    this.anchor = 0,
    this.paintOrder = .firstIsTop,
  }) : children = null,
       padding = .zero,
       spacing = 0,
       addRepaintBoundaries = true,
       addSemanticIndexes = true,
       assert(controller == null || primary != true),
       assert(!shrinkWrap || center == null),
       assert(anchor >= 0 && anchor <= 1),
       assert(semanticChildCount == null || semanticChildCount >= 0);

  /// 按顺序排列的普通子项，在交叉轴上撑满视口；状态常驻，适合数量有限的内容。
  final List<Widget>? children;

  /// 按滚动顺序排列的 Sliver。
  final List<Widget>? slivers;

  /// 观察与驱动滚动位置的控制器。
  ///
  /// 外部控制器经内部适配器共享同一个真实位置，保留初始偏移、滚动命令及位置保存配置。
  final ScrollController? controller;

  /// 滚动物理，默认读取环境 [ScrollConfiguration]。
  final ScrollPhysics? physics;

  /// 鼠标滚轮平滑算法；缺省按平台自动启用，显式 null 关闭。
  final Object? smoothScroll;

  /// 滚动主轴。
  final Axis scrollDirection;

  /// 是否反转滚动方向。
  final bool reverse;

  /// [children] 四周的内边距。
  final EdgeInsetsGeometry padding;

  /// 相邻 [children] 之间的主轴间距。
  final double spacing;

  /// 是否为每个 children 子项隔离重绘，默认 true；sliver 构造由各 Sliver 自己声明。
  final bool addRepaintBoundaries;

  /// 是否为 children 添加业务语义索引，默认 true；sliver 构造由各 Sliver 自己声明。
  final bool addSemanticIndexes;

  /// 是否按内容尺寸收缩主轴；适用于父布局在滚动方向没有给出有限尺寸的嵌套场景。
  final bool shrinkWrap;

  /// 视口前后预先布局的范围，默认各 250 逻辑像素；仅影响按需构建与复用的缓存窗口。
  final ScrollCacheExtent? scrollCacheExtent;

  /// 视口裁剪行为。
  final Clip clipBehavior;

  /// 是否继承 PrimaryScrollController，缺省遵循官方平台与方向规则。
  final bool? primary;

  /// 当前滚动容器的输入设备、物理与越界表现配置。
  final ScrollBehavior? scrollBehavior;

  /// 拖动起点的取值方式。
  final DragStartBehavior dragStartBehavior;

  /// 拖动时是否收起软键盘，缺省读取滚动配置。
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  /// 用于恢复滚动位置的标识。
  final String? restorationId;

  /// 参与滚动语义的业务子项数量。
  final int? semanticChildCount;

  /// 空白区域的命中行为。
  final HitTestBehavior hitTestBehavior;

  /// 零滚动偏移在视口主轴上的相对位置。
  final double anchor;

  /// Sliver 之间的绘制与命中顺序。
  final SliverPaintOrder paintOrder;

  /// 零滚动偏移对应的 Sliver Key，仅 sliver 构造提供。
  final Key? center;

  @override
  Widget build(BuildContext context) {
    final host = useMemoized(_HostController.new);
    final pointers = useMemoized(_RawPointers.new);
    final activeController = host;
    final effectivePrimary =
        primary ?? (controller == null && PrimaryScrollController.shouldInherit(context, scrollDirection));
    final userController = effectivePrimary ? PrimaryScrollController.maybeOf(context) : controller;
    final configuredSmooth = identical(smoothScroll, $absent)
        ? resolveDefaultSmoothScroll()
        : smoothScroll as ElSmoothScroll?;
    useEffect(() {
      host.bind(userController);
      return host.dispose;
    }, const []);
    useValueChanged<ScrollController?, void>(userController, (_, _) {
      // useEffect(keys) 会在新 effect 挂载之后才 dispose 旧 effect，
      // 若旧清理执行 bind(null)，会把刚换上的 controller 再摘掉。
      host.bind(userController);
    });

    final slivers =
        this.slivers ??
        [
          SliverPadding(
            padding: padding,
            sliver: ElSliverList(
              spacing: spacing,
              stretch: true,
              addRepaintBoundaries: addRepaintBoundaries,
              addSemanticIndexes: addSemanticIndexes,
              children: children!,
            ),
          ),
        ];
    final selection = switch (SelectionContainer.maybeOf(context)) {
      final ScrollTransparentSelectionRegistrar registrar => registrar,
      _ => null,
    };
    Widget scrollable = _HostScrollView(
      controller: activeController,
      physics: ScrollHostPhysics(
        parent:
            physics ??
            ((primary ?? false) || (primary == null && controller == null && scrollDirection == Axis.vertical)
                ? const AlwaysScrollableScrollPhysics()
                : null),
      ),
      scrollDirection: scrollDirection,
      reverse: reverse,
      shrinkWrap: shrinkWrap,
      scrollCacheExtent: scrollCacheExtent,
      clipBehavior: clipBehavior,
      scrollBehavior: scrollBehavior,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      semanticChildCount: semanticChildCount ?? children?.length,
      hitTestBehavior: hitTestBehavior,
      anchor: anchor,
      center: center,
      paintOrder: paintOrder,
      slivers: slivers,
      smooth: configuredSmooth,
      selection: selection,
    );
    if (effectivePrimary && userController != null) scrollable = PrimaryScrollController.none(child: scrollable);
    // 自管选区的注册器不需要官方 Scrollable 的选区处理层，视口内容直接登记到它。
    if (selection != null) scrollable = SelectionContainer.disabled(child: scrollable);
    return Listener(
      onPointerDown: (event) => pointers.down(event.pointer, event.position, activeController),
      onPointerUp: (event) => pointers.up(event.pointer, activeController),
      onPointerCancel: (event) => pointers.cancel(event.pointer, activeController),
      onPointerPanZoomStart: (event) => pointers.down(event.pointer, event.position, activeController),
      onPointerPanZoomEnd: (event) => pointers.up(event.pointer, activeController),
      child: scrollable,
    );
  }
}

// 让官方 ScrollView 负责键盘、恢复、语义和滚动配置，只替换视口与位置接入。
class _HostScrollView extends CustomScrollView {
  const _HostScrollView({
    required super.controller,
    required super.physics,
    required super.scrollDirection,
    required super.reverse,
    required super.shrinkWrap,
    required super.scrollCacheExtent,
    required super.clipBehavior,
    required super.scrollBehavior,
    required super.dragStartBehavior,
    required super.keyboardDismissBehavior,
    required super.restorationId,
    required super.semanticChildCount,
    required super.hitTestBehavior,
    required super.anchor,
    required super.center,
    required super.paintOrder,
    required super.slivers,
    required this.smooth,
    required this.selection,
  }) : super(primary: false);
  final ElSmoothScroll? smooth;
  final ScrollTransparentSelectionRegistrar? selection;

  @override
  Widget buildViewport(BuildContext context, ViewportOffset offset, AxisDirection axisDirection, List<Widget> slivers) {
    final position = offset as ScrollHostPosition;
    position.configureSmooth(smooth);
    final devices = (scrollBehavior ?? ScrollConfiguration.of(context)).dragDevices;
    final viewport = shrinkWrap
        ? ElShrinkWrappingViewport(
            axisDirection: axisDirection,
            offset: offset,
            slivers: slivers,
            scrollCacheExtent: scrollCacheExtent,
            clipBehavior: clipBehavior,
            paintOrder: paintOrder,
            dragDevices: devices,
            hitTestBehavior: hitTestBehavior,
          )
        : ElViewport(
            axisDirection: axisDirection,
            offset: offset,
            slivers: slivers,
            scrollCacheExtent: scrollCacheExtent,
            clipBehavior: clipBehavior,
            center: center,
            anchor: anchor,
            paintOrder: paintOrder,
            dragDevices: devices,
            hitTestBehavior: hitTestBehavior,
          );
    final content = Listener(behavior: hitTestBehavior, onPointerSignal: position.handlePointerSignal, child: viewport);
    return selection == null ? content : SelectionRegistrarScope(registrar: selection!, child: content);
  }
}

/// 跟踪一次触摸序列，保证 PointerCancel 不会被误当成下拉刷新松手。
final class _RawPointers {
  final _pointers = <int>{};

  void down(int pointer, Offset position, ScrollController controller) {
    if (_pointers.isEmpty) {
      for (final host in controller.positions) {
        if (host is ScrollHostPosition) {
          host.resetRawPointerCancellation();
          host.setRawPointerOrigin(position);
        }
      }
    }
    _pointers.add(pointer);
  }

  void up(int pointer, ScrollController controller) {
    _pointers.remove(pointer);
    if (_pointers.isNotEmpty) return;
    for (final host in controller.positions) {
      if (host is ScrollHostPosition) host.setRawPointerOrigin(null);
    }
  }

  void cancel(int pointer, ScrollController controller) {
    up(pointer, controller);
    if (_pointers.isNotEmpty) return;
    for (final position in controller.positions) {
      if (position is ScrollHostPosition) position.markRawPointerCanceled();
    }
  }
}

/// 将外部 ScrollController 连接到官方 Scrollable 的同一个真实位置。
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
