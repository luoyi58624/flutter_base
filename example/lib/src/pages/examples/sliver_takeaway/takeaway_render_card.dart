part of 'index.dart';

class _TakeawayRenderCard extends LeafRenderObjectWidget {
  const _TakeawayRenderCard({super.key, required this.store, required this.atlas, required this.onAdd});

  final ValueListenable<_Store?> store;
  final _FoodAtlas atlas;
  final ValueChanged<_Dish> onAdd;

  _TakeawayInk _ink(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return (
      text: DefaultTextStyle.of(context).style,
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      boldText: MediaQuery.boldTextOf(context),
      foreground: colors.onSurface,
      muted: colors.onSurfaceVariant,
      background: context.elTheme.cardColor,
      border: context.elTheme.borderColor,
    );
  }

  @override
  _ElRenderTakeawayCard createRenderObject(BuildContext context) => _ElRenderTakeawayCard(
    store,
    atlas,
    onAdd,
    _ink(context),
    TickerMode.valuesOf(context).enabled,
    MediaQuery.maybeGestureSettingsOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, _ElRenderTakeawayCard renderObject) => renderObject.configure(
    store,
    atlas,
    onAdd,
    _ink(context),
    TickerMode.valuesOf(context).enabled,
    MediaQuery.maybeGestureSettingsOf(context),
  );
}

class _ElRenderTakeawayCard extends RenderBox with _TakeawayMenuInteraction {
  _ElRenderTakeawayCard(
    this._store,
    this._atlas,
    this.menuOnAdd,
    this._ink,
    this.menuInteractionEnabled,
    this.menuGestureSettings,
  ) : _record = _store.value;

  final _canvas = _TakeawayCanvas();
  ValueListenable<_Store?> _store;
  _FoodAtlas _atlas;
  _TakeawayInk _ink;
  _Store? _record;

  @override
  ValueChanged<_Dish> menuOnAdd;

  @override
  bool menuInteractionEnabled;

  @override
  DeviceGestureSettings? menuGestureSettings;

  @override
  _Store? get menuStore => _record;

  @override
  TextDirection get menuTextDirection => _ink.direction;

  @override
  Rect get menuBounds => _record == null ? Rect.zero : _canvas.menuBounds;

  @override
  double get menuItemExtent => _canvas.menuItemExtent;

  @override
  Rect menuButtonRect(int index, double offset) => _canvas.menuButtonRect(index, offset);

  void configure(
    ValueListenable<_Store?> store,
    _FoodAtlas atlas,
    ValueChanged<_Dish> onAdd,
    _TakeawayInk ink,
    bool enabled,
    DeviceGestureSettings? gestureSettings,
  ) {
    if (!identical(_store, store)) {
      if (attached) _store.removeListener(_updateRecord);
      _store = store;
      if (attached) _store.addListener(_updateRecord);
      _updateRecord();
    }
    if (!identical(_atlas, atlas)) {
      if (attached) _atlas.removeListener(markNeedsPaint);
      _atlas = atlas;
      if (attached) _atlas.addListener(markNeedsPaint);
      markNeedsPaint();
    }
    menuOnAdd = onAdd;
    if (menuGestureSettings != gestureSettings) {
      resetMenuInteraction();
      menuGestureSettings = gestureSettings;
    }
    if (menuInteractionEnabled != enabled) {
      menuInteractionEnabled = enabled;
      if (!enabled) resetMenuInteraction();
      markNeedsSemanticsUpdate();
    }
    if (_ink != ink) {
      resetMenuInteraction();
      _ink = ink;
      markNeedsLayout();
      markNeedsSemanticsUpdate();
    }
  }

  void _updateRecord() {
    final record = _store.value;
    if (identical(record, _record)) return;
    resetMenuInteraction();
    _record = record;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _store.addListener(_updateRecord);
    _atlas.addListener(markNeedsPaint);
    _updateRecord();
    markNeedsPaint();
  }

  @override
  void detach() {
    _store.removeListener(_updateRecord);
    _atlas.removeListener(markNeedsPaint);
    super.detach();
  }

  double _width(BoxConstraints constraints) =>
      constraints.constrainWidth(constraints.hasBoundedWidth ? constraints.maxWidth : 856);

  @override
  void performLayout() {
    final width = _width(constraints);
    final record = _record;
    final previousMenu = menuBounds;
    final previousExtent = menuItemExtent;
    final height = record == null ? 0.0 : _canvas.layout(width: width, store: record, ink: _ink);
    if (menuBounds != previousMenu || menuItemExtent != previousExtent) resetMenuInteraction();
    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = _width(constraints);
    final record = _record;
    if (record == null) return constraints.constrain(Size(width, 0));
    // 干布局可以传不同宽度，不能覆盖当前屏幕上的命中区域。
    final probe = _TakeawayCanvas();
    try {
      return constraints.constrain(Size(width, probe.layout(width: width, store: record, ink: _ink)));
    } finally {
      probe.dispose();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_record == null || size.isEmpty) return;
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _canvas.paint(canvas, _atlas, menuOffset);
    canvas.restore();
  }

  @override
  void dispose() {
    _canvas.dispose();
    super.dispose();
  }
}
