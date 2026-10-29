part of '../virtual/virtual_pipeline.dart';

final class _NestedScrollScope extends InheritedWidget {
  const _NestedScrollScope({required this.owner, required super.child});
  final ElNestedScrollMixin<StatefulWidget> owner;

  static NestedScrollNode? maybeNodeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NestedScrollScope>()?._currentNode;

  NestedScrollNode? get _currentNode => owner._nestedNode ?? owner._outerNestedNode;

  static List<_NestedRegionParent> declarationsOf(BuildContext context) {
    List<_NestedRegionParent>? result;
    var element = context.getElementForInheritedWidgetOfExactType<_NestedScrollScope>();
    while (element != null) {
      context.dependOnInheritedElement(element);
      final scope = element.widget as _NestedScrollScope;
      (result ??= []).add(scope.owner._nestedParent);
      element = scope.owner.context.getElementForInheritedWidgetOfExactType<_NestedScrollScope>();
    }
    return result ?? const [];
  }

  @override
  bool updateShouldNotify(_NestedScrollScope oldWidget) => true;
}

/// 在真实滚动后代 State 中向更内层的滚动视图提供嵌套协商区域。
///
/// 使用 [buildNestedScrollRegion] 包住内层滚动子树，轴沿用 [requestedScrollAxis]
/// 的绑定结果；节点由外层 [ElScrollViewState] 管理，不通过 controller 查找宿主。
/// pre/post 钩子返回剩余量，符号与 [ElScrollInputDetails] 一致。
mixin ElNestedScrollMixin<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  late final _NestedRegionParent _nestedParent = _NestedRegionParent(this);
  ElScrollViewState? _nestedOwner;
  NestedScrollNode? _nestedNode;
  NestedScrollNode? _outerNestedNode;
  final Set<int> _nestedInputSessions = {};

  /// 是否向当前区域内的滚动视图提供嵌套协商。
  @protected
  bool get participatesInNestedScroll => true;

  @override
  void updateScrollBinding() {
    super.updateScrollBinding();
    _syncNestedRegion();
  }

  void _syncNestedRegion() {
    if (!mountedForScrollCallbacks) {
      _releaseNestedRegion();
      return;
    }
    final router = scrollView?._inputRouter;
    if (router != null && (router._transaction != null || router._dispatchDepth != 0)) {
      router.deferUpdate(this);
      return;
    }
    _outerNestedNode = _NestedScrollScope.maybeNodeOf(context);
    final host = scrollView;
    final axis = _resolvedScrollAxis;
    if (!participatesInNestedScroll || host == null || axis == null) {
      _releaseNestedRegion();
      return;
    }
    if (scrollInputSlot == null) throw FlutterError('参与嵌套输入的 State 必须声明 scrollInputSlot，并使用宿主 inputOrder 排序。');
    final previous = _nestedNode;
    if (identical(_nestedOwner, host) &&
        previous != null &&
        previous.axis == axis &&
        identical(previous.outer, _outerNestedNode)) {
      return;
    }
    _releaseNestedRegion();
    _nestedOwner = host;
    _nestedNode = host._registerNestedRegion(_nestedParent, axis, _outerNestedNode);
  }

  void _releaseNestedRegion() {
    final host = _nestedOwner;
    if (host == null) return;
    host._unregisterNestedRegion(_nestedParent);
    _nestedOwner = null;
    _nestedNode = null;
    final sessions = _nestedInputSessions.toList(growable: false);
    _nestedInputSessions.clear();
    for (final _ in sessions) {
      onNestedScrollEnd();
    }
  }

  @override
  void onScrollViewDetached(ElScrollViewState scrollView) {
    _releaseNestedRegion();
    super.onScrollViewDetached(scrollView);
  }

  /// 构建私有嵌套区域；当前 State 必须位于外层滚动视图的真实子树中。
  Widget buildNestedScrollRegion({required Widget child}) {
    requireScrollView;
    _syncNestedRegion();
    return _NestedScrollScope(owner: this, child: child);
  }

  ElScrollInputDetails? _nestedInputDetails(double delta, ElScrollDeltaSource source) {
    final host = _nestedOwner;
    final axis = _nestedNode?.axis;
    if (!mountedForScrollCallbacks || !participatesInNestedScroll || host == null || axis == null) return null;
    final position = host.positionFor(axis);
    if (position == null) return null;
    final transaction = ScrollInputTransaction.current!;
    final snapshot = host._readMixinSnapshotFor(axis);
    return ElScrollInputDetails(
      scrollView: host,
      sourceScrollView: transaction.origin is ElScrollViewState ? transaction.origin! as ElScrollViewState : host,
      axis: axis,
      axisDirection: position.axisDirection,
      source: transaction.source,
      sessionId: transaction.sessionId,
      transactionId: transaction.id,
      sampleId: host._takeMixinSampleId(axis),
      timeStamp: transaction.timeStamp,
      rawEvent: transaction.rawEvent,
      rawDelta: delta,
      requestedDelta: delta * _ScrollInputRouter._inputScale(source, position.axisDirection),
      snapshot: snapshot,
    );
  }

  bool _acceptsNestedInput(ElScrollViewState source, Axis axis, int? sessionId) =>
      !identical(source, scrollView) &&
      _nestedNode != null &&
      source._ancestorRouteFor(axis)?.containsRegion(_nestedNode!, sessionId) == true;

  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    return _acceptsNestedInput(input.sourceScrollView, input.axis, input.sessionId)
        ? onNestedPreScroll(input, rest)
        : rest;
  }

  @override
  double onPostScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPostScroll(input, remaining);
    return _acceptsNestedInput(input.sourceScrollView, input.axis, input.sessionId)
        ? onNestedPostScroll(input, rest)
        : rest;
  }

  @override
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    final rest = super.onPreFling(details, remainingVelocity);
    return _acceptsNestedInput(details.sourceScrollView, details.axis, details.sessionId)
        ? onNestedPreFling(details, rest)
        : rest;
  }

  void _nestedStart(int session, ElScrollInputDetails details) {
    if (_nestedInputSessions.add(session)) onNestedScrollStart(details);
  }

  void _nestedEnd(int session) {
    if (_nestedInputSessions.remove(session)) onNestedScrollEnd();
  }

  /// 内层实际输入会话开始；详情中的 delta 为零。
  @protected
  @mustCallSuper
  void onNestedScrollStart(ElScrollInputDetails details) {}

  /// 内层消费前接收输入，并返回交给内层的剩余量。
  @protected
  @mustCallSuper
  double onNestedPreScroll(ElScrollInputDetails input, double remaining) => remaining;

  /// 内层到达边界后接收余量，并返回继续上交的剩余量。
  @protected
  @mustCallSuper
  double onNestedPostScroll(ElScrollInputDetails input, double remaining) => remaining;

  /// 内层松手时接收速度并返回剩余速度；零速度也会派发。
  @protected
  @mustCallSuper
  double onNestedPreFling(ElScrollReleaseDetails details, double remainingVelocity) => remainingVelocity;

  /// 内层会话结束；停用或解绑时也会补齐已经开始的会话。
  @protected
  @mustCallSuper
  void onNestedScrollEnd() {}
}

final class _NestedRegionParent extends ElNestedScrollParent {
  _NestedRegionParent(this.owner);

  final ElNestedScrollMixin<StatefulWidget> owner;
}
