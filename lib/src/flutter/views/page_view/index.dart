import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart' show SemanticsAction;

/// 使用官方手势、控制器和分页物理的分页视图。
///
/// 同轴 ElScrollView 仅在起手已贴边时让本视图接管，途中撞边界不换层。
/// 页面状态保留沿用官方 AutomaticKeepAliveClientMixin 与 PageStorage。
/// 翻页过程中不屏蔽页面内容的指针输入，允许直接操作页内滚动。
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

  @override
  State<PageView> createState() => _PageState();
}

class _PageState extends State<PageView> {
  late final _controller = _PageController()..bind(widget.controller);

  @override
  void didUpdateWidget(PageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.bind(widget.controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.custom(
    controller: _controller,
    childrenDelegate: widget.childrenDelegate,
    scrollDirection: widget.scrollDirection,
    reverse: widget.reverse,
    physics: widget.physics,
    pageSnapping: widget.pageSnapping,
    onPageChanged: widget.onPageChanged,
    dragStartBehavior: widget.dragStartBehavior,
    allowImplicitScrolling: widget.allowImplicitScrolling,
    scrollCacheExtent: widget.scrollCacheExtent,
    restorationId: widget.restorationId,
    clipBehavior: widget.clipBehavior,
    scrollBehavior: widget.scrollBehavior,
    padEnds: widget.padEnds,
    hitTestBehavior: widget.hitTestBehavior,
  );
}

// 与调用方共享官方分页位置，只代理位置创建时的上下文。
class _PageController extends PageController {
  PageController? _user;

  @override
  int get initialPage => _user?.initialPage ?? super.initialPage;
  @override
  bool get keepPage => _user?.keepPage ?? super.keepPage;
  @override
  double get viewportFraction => _user?.viewportFraction ?? super.viewportFraction;

  void bind(PageController? next) {
    if (identical(_user, next)) return;
    final previous = _user;
    _user = next;
    for (final position in positions.toList()) {
      previous?.detach(position);
      // 重新应用官方 viewportFraction，移除外部控制器时也恢复默认整页宽度。
      super.detach(position);
      super.attach(position);
      next?.attach(position);
    }
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    final input = _PointerContext(context);
    return _user?.createScrollPosition(physics, input, oldPosition) ??
        super.createScrollPosition(physics, input, oldPosition);
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

// 官方活动仍管理拖动与惯性，仅阻止它们把页面内容从命中测试中移除。
class _PointerContext implements ScrollContext {
  _PointerContext(this.delegate);
  final ScrollContext delegate;

  @override
  void setIgnorePointer(bool value) => delegate.setIgnorePointer(false);
  @override
  BuildContext? get notificationContext => delegate.notificationContext;
  @override
  BuildContext get storageContext => delegate.storageContext;
  @override
  TickerProvider get vsync => delegate.vsync;
  @override
  AxisDirection get axisDirection => delegate.axisDirection;
  @override
  double get devicePixelRatio => delegate.devicePixelRatio;
  @override
  void setCanDrag(bool value) => delegate.setCanDrag(value);
  @override
  void setSemanticsActions(Set<SemanticsAction> actions) => delegate.setSemanticsActions(actions);
  @override
  void saveOffset(double offset) => delegate.saveOffset(offset);
}
