part of 'takeaway.dart';

mixin _TakeawayMenuInteraction on RenderBox {
  _Store? get menuStore;
  Rect get menuBounds;
  double get menuItemExtent;
  Rect menuButtonRect(int index, double offset);
  ValueChanged<_Dish> get menuOnAdd;
  DeviceGestureSettings? get menuGestureSettings;
  TextDirection get menuTextDirection;
  bool get menuInteractionEnabled;

  HorizontalDragGestureRecognizer? _menuDrag;
  TapGestureRecognizer? _menuTap;
  Ticker? _menuTicker;
  ClampingScrollSimulation? _menuSimulation;
  _Store? _menuSemanticsStore;
  SemanticsNode? _menuNode;
  final _menuButtons = <int, SemanticsNode>{};

  double get _menuMaxOffset {
    final bounds = menuBounds;
    if (bounds.isEmpty) return 0;
    return math.max(0.0, (menuStore?.dishes.length ?? 0) * menuItemExtent - bounds.width);
  }

  double get menuOffset => (menuStore?.menuOffset ?? 0).clamp(0.0, _menuMaxOffset);

  bool get _canInteractWithMenu => attached && menuInteractionEnabled && menuStore != null;
  bool get _menuRunsRightToLeft => menuTextDirection == .rtl;

  void _setMenuOffset(double offset) {
    if (!_canInteractWithMenu) return;
    final record = menuStore!;
    final next = offset.clamp(0.0, _menuMaxOffset);
    if (record.menuOffset == next) return;
    record.menuOffset = next;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _stopMenuFling() {
    _menuTicker?.stop();
    _menuSimulation = null;
  }

  void _startMenuFling(DragEndDetails details) {
    final dragVelocity = details.primaryVelocity ?? 0.0;
    final velocity = _menuRunsRightToLeft ? dragVelocity : -dragVelocity;
    if (!_canInteractWithMenu || velocity == 0 || _menuMaxOffset == 0) return;
    _menuSimulation = ClampingScrollSimulation(position: menuOffset, velocity: velocity);
    (_menuTicker ??= Ticker(_tickMenuFling)).start();
  }

  void _tickMenuFling(Duration elapsed) {
    final simulation = _menuSimulation!;
    final time = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final next = simulation.x(time);
    _setMenuOffset(next);
    final reachedEdge = simulation.velocity < 0 ? next <= 0 : next >= _menuMaxOffset;
    if (!_canInteractWithMenu || reachedEdge || simulation.isDone(time)) _stopMenuFling();
  }

  void resetMenuInteraction() {
    // 池里的卡片仍然挂载，换绑时先让旧手势退出竞技场并停止旧惯性。
    _stopMenuFling();
    _menuDrag?.dispose();
    _menuTap?.dispose();
    _menuDrag = null;
    _menuTap = null;
  }

  void _disposeMenuInteraction() {
    resetMenuInteraction();
    _menuTicker?.dispose();
    _menuTicker = null;
  }

  @override
  void detach() {
    _disposeMenuInteraction();
    super.detach();
  }

  @override
  void dispose() {
    _disposeMenuInteraction();
    super.dispose();
  }

  @override
  bool hitTestSelf(Offset position) => _canInteractWithMenu && menuBounds.contains(position);

  HorizontalDragGestureRecognizer get _dragRecognizer => _menuDrag ??= HorizontalDragGestureRecognizer(debugOwner: this)
    ..gestureSettings = menuGestureSettings
    ..onUpdate = (details) {
      final delta = details.primaryDelta!;
      _setMenuOffset(menuOffset + (_menuRunsRightToLeft ? delta : -delta));
    }
    ..onEnd = _startMenuFling;

  int? _menuButtonAt(Offset position) {
    final bounds = menuBounds;
    final extent = menuItemExtent;
    if (!bounds.contains(position) || extent <= 0) return null;
    final offset = menuOffset;
    final leading = _menuRunsRightToLeft ? bounds.right - position.dx : position.dx - bounds.left;
    final index = ((leading + offset) / extent).floor();
    if (index < 0 || index >= menuStore!.dishes.length) return null;
    return menuButtonRect(index, offset).contains(position) ? index : null;
  }

  TapGestureRecognizer get _tapRecognizer => _menuTap ??= TapGestureRecognizer(debugOwner: this)
    ..gestureSettings = menuGestureSettings
    ..onTapUp = (details) {
      if (!_canInteractWithMenu) return;
      final index = _menuButtonAt(details.localPosition);
      if (index != null) menuOnAdd(menuStore!.dishes[index]);
    };

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (!_canInteractWithMenu) return;
    switch (event) {
      case PointerDownEvent():
        _stopMenuFling();
        if (_menuMaxOffset > 0) _dragRecognizer.addPointer(event);
        if (_menuButtonAt(event.localPosition) != null) _tapRecognizer.addPointer(event);
      case PointerPanZoomStartEvent():
        _stopMenuFling();
        if (_menuMaxOffset > 0) _dragRecognizer.addPointerPanZoom(event);
      case PointerScrollEvent(:final scrollDelta) when scrollDelta.dx.abs() > scrollDelta.dy.abs():
        final offset = menuOffset;
        final delta = _menuRunsRightToLeft ? -scrollDelta.dx : scrollDelta.dx;
        final target = (offset + delta).clamp(0.0, _menuMaxOffset);
        if (target == offset) return;
        final record = menuStore;
        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
          if (!identical(record, menuStore)) return;
          _stopMenuFling();
          _setMenuOffset(target);
        });
      default:
        break;
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final record = menuStore;
    if (record == null) return;
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true
      ..identifier = 'takeaway-store-${record.id}'
      ..textDirection = menuTextDirection
      ..label = [
        record.name,
        '${record.rating} 分，月售 ${record.sales}，起送 ¥${record.minimum}',
        '预计 ${record.minutes} 分钟，距离 ${record.distance} 公里',
        '满减 ¥${record.coupon}',
        record.description,
        record.review,
        record.address,
        ...record.tags,
      ].join('。');
  }

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    final record = menuStore;
    final bounds = menuBounds;
    final visibleBounds = bounds.intersect(node.parentPaintClipRect ?? bounds);
    final extent = menuItemExtent;
    if (!_canInteractWithMenu || record == null || visibleBounds.isEmpty || extent <= 0) {
      super.assembleSemanticsNode(node, config, children);
      return;
    }
    if (!identical(_menuSemanticsStore, record)) {
      _menuSemanticsStore = record;
      _menuNode = null;
      _menuButtons.clear();
    }

    final offset = menuOffset;
    final maxOffset = _menuMaxOffset;
    final count = record.dishes.length;
    final first = (offset / extent).floor();
    final end = math.min(count, ((offset + bounds.width) / extent).ceil());
    final buttons = <SemanticsNode>[];
    int? firstVisibleButton;
    for (var index = end - 1; index >= first; index--) {
      final rect = menuButtonRect(index, offset).intersect(visibleBounds);
      if (rect.isEmpty) continue;
      firstVisibleButton = index;
      final dish = record.dishes[index];
      final button = _menuButtons.putIfAbsent(index, SemanticsNode.new);
      button
        ..rect = rect.shift(-bounds.topLeft)
        ..updateWith(
          config: SemanticsConfiguration()
            ..identifier = 'takeaway-add-${record.id}-$index'
            ..indexInParent = index
            ..isButton = true
            ..isEnabled = true
            ..textDirection = menuTextDirection
            ..label = '加购 ${dish.name}，¥${_money(dish.cents)}'
            ..onTap = () {
              if (_canInteractWithMenu &&
                  identical(menuStore, record) &&
                  menuButtonRect(index, menuOffset).overlaps(menuBounds)) {
                menuOnAdd(dish);
              }
            },
        );
      buttons.add(button);
    }

    void scroll(double delta) {
      if (!_canInteractWithMenu || !identical(menuStore, record)) return;
      _stopMenuFling();
      _setMenuOffset(menuOffset + delta);
    }

    final forward = offset < maxOffset ? () => scroll(bounds.width * .8) : null;
    final backward = offset > 0 ? () => scroll(-bounds.width * .8) : null;
    final left = _menuRunsRightToLeft ? backward : forward;
    final right = _menuRunsRightToLeft ? forward : backward;
    final menuConfig = SemanticsConfiguration()
      ..identifier = 'takeaway-menu-${record.id}'
      ..textDirection = menuTextDirection
      ..label = '店内菜单'
      ..scrollPosition = offset
      ..scrollExtentMin = 0
      ..scrollExtentMax = maxOffset
      ..scrollChildCount = count
      ..scrollIndex = firstVisibleButton;
    if (left != null) menuConfig.onScrollLeft = left;
    if (right != null) menuConfig.onScrollRight = right;
    final menu = _menuNode ??= SemanticsNode();
    menu
      ..rect = visibleBounds.shift(-bounds.topLeft)
      ..transform = Matrix4.translationValues(bounds.left, bounds.top, 0)
      ..updateWith(config: menuConfig, childrenInInversePaintOrder: buttons);
    node.updateWith(config: config, childrenInInversePaintOrder: [menu, ...children]);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _menuSemanticsStore = null;
    _menuNode = null;
    _menuButtons.clear();
  }
}
