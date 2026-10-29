// ignore_for_file: prefer_initializing_formals

part of 'selection_view.dart';

/// 单文档手势宿主；范围和成员只由官方 SelectionDocument 保存。
class RenderSelectionView extends RenderProxyBox
    implements
        SelectionAppearance,
        SelectionContentObserver,
        SelectionControllerDelegate,
        SelectionAutoScrollHost,
        SelectionMagnifierHost,
        MouseTrackerAnnotation,
        SelectionVisualGeometryDependency {
  RenderSelectionView({
    required this.document,
    required SelectionControls selectionControls,
    required Color selectionColor,
    required Color? selectionTextColor,
    required double dragThreshold,
    required Duration longPressDelay,
    required bool clearOnTapOutside,
    required bool clearOnEsc,
    LongPressSelection longPressSelection = LongPressSelection.word,
    double longPressAutoScrollThreshold = 100,
    bool longPressHaptics = true,
    bool handleHaptics = false,
    SelectionAutoScrollConfig? touchAutoScroll,
    SelectionAutoScrollConfig? mouseAutoScroll,
    bool enabled = true,
    ElSelectionController? controller,
    ValueChanged<String?>? onSelectionChanged,
    ValueChanged<Offset>? onContextMenuRequested,
    FocusNode? rootFocusNode,
    RenderBox? child,
  }) : _selectionControls = selectionControls,
       _selectionColor = selectionColor,
       _selectionTextColor = selectionTextColor,
       _dragThreshold = dragThreshold,
       _longPressDelay = longPressDelay,
       clearOnTapOutside = clearOnTapOutside,
       clearOnEsc = clearOnEsc,
       longPressSelection = longPressSelection,
       longPressAutoScrollThreshold = longPressAutoScrollThreshold,
       longPressHaptics = longPressHaptics,
       handleHaptics = handleHaptics,
       touchAutoScroll = touchAutoScroll ?? SelectionAutoScrollConfig.touch,
       mouseAutoScroll = mouseAutoScroll ?? SelectionAutoScrollConfig.mouse,
       _enabled = enabled,
       _controller = controller,
       onSelectionChanged = onSelectionChanged,
       onContextMenuRequested = onContextMenuRequested,
       rootFocusNode = rootFocusNode,
       super(child) {
    _dispatcher = EventDispatcher(this)..event = _events;
  }

  final SelectionDocument document;
  late final EventDispatcher _dispatcher;
  late final SelectionAutoScrollController _autoScroll = SelectionAutoScrollController(this);
  late final SelectionMagnifierHandleController _handles = SelectionMagnifierHandleController(this);
  final _endpoints = ValueNotifier<SelectionEndpointsInfo?>(null);
  final _dragInfo = ValueNotifier<SelectionDragInfo?>(null);
  final _scrollActivity = ValueNotifier(false);
  final Set<ScrollViewport> _scrollViewports = HashSet.identity();
  final Map<Selectable, RenderObject> _sources = HashMap.identity();
  Selectable? _scrollStart;
  Selectable? _scrollEnd;
  Timer? _scrollQuiet;
  bool _disposed = false;
  bool _syncScheduled = false;
  bool _dragInfoScheduled = false;
  bool _dispatching = false;
  bool _dragMounted = false;
  int _dragRevision = 0;
  int? _pointer;
  PointerDeviceKind? _pointerKind;
  PointerDeviceKind? _handleKind;
  Offset? _down;
  Offset? _lastDrag;
  RenderObject? _downSource;
  bool _mobileGesture = false;
  bool _dragging = false;
  bool _hitSelectableText = false;
  bool _wordSelected = false;
  final _mobileChrome = ValueNotifier(false);
  bool _bodyRoute = false;
  bool _resumeBodySelection = false;
  bool _globalRoute = false;
  bool _handleSession = false;
  TextSelectionHandleType? _activeHandleType;
  String? _text;
  Matrix4? _endpointInverse;

  SelectionControls _selectionControls;
  SelectionControls get selectionControls => _selectionControls;
  set selectionControls(SelectionControls value) {
    if (identical(value, _selectionControls)) return;
    _cancelGesture();
    _selectionControls = value;
  }

  bool _enabled;
  @override
  bool get selectionEnabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    if (!value) clearSelection();
    reattachSelectionParticipantsInSubtree(this);
  }

  Color _selectionColor;
  @override
  Color get selectionColor => _selectionColor;
  set selectionColor(Color value) {
    if (_selectionColor == value) return;
    _selectionColor = value;
    _repaintSelected();
    _scheduleSync();
  }

  Color? _selectionTextColor;
  @override
  Color? get selectionTextColor => _selectionTextColor;
  set selectionTextColor(Color? value) {
    if (_selectionTextColor == value) return;
    _selectionTextColor = value;
    _repaintSelected();
  }

  double _dragThreshold;
  double get dragThreshold => _dragThreshold;
  set dragThreshold(double value) {
    if (_dragThreshold == value) return;
    _dragThreshold = value;
    _dispatcher.event = _events;
  }

  Duration _longPressDelay;
  Duration get longPressDelay => _longPressDelay;
  set longPressDelay(Duration value) {
    if (_longPressDelay == value) return;
    _longPressDelay = value;
    _dispatcher.event = _events;
  }

  LongPressSelection longPressSelection;
  double longPressAutoScrollThreshold;
  bool longPressHaptics;
  bool handleHaptics;
  bool clearOnTapOutside;
  bool clearOnEsc;
  SelectionAutoScrollConfig touchAutoScroll;
  SelectionAutoScrollConfig mouseAutoScroll;
  FocusNode? rootFocusNode;
  ValueChanged<String?>? onSelectionChanged;
  ValueChanged<Offset>? onContextMenuRequested;
  bool contextMenuOpen = false;

  ElSelectionController? _controller;
  ElSelectionController? get controller => _controller;
  set controller(ElSelectionController? value) {
    if (identical(value, _controller)) return;
    _controller?._unbindDelegate(this);
    _controller = value;
    if (attached) value?._bindDelegate(this);
  }

  @override
  String? get selectionInfo => document.getSelectedContent()?.plainText;
  @override
  String? resolveSelectionInfo() {
    final text = document.getSelectedContent()?.plainText;
    if (_mustDeferNotifications) {
      _scheduleSync();
    } else {
      _publishText(text);
    }
    return text;
  }

  ValueListenable<SelectionEndpointsInfo?> get endpointsListenable => _endpoints;
  SelectionEndpointsInfo? get endpoints => _endpoints.value;
  ValueListenable<SelectionDragInfo?> get dragInfoListenable => _dragInfo;
  ValueListenable<bool> get scrollActivityListenable => _scrollActivity;
  bool get selectionUsesMobileChrome => _mobileChrome.value;
  ValueListenable<bool> get mobileChromeListenable => _mobileChrome;
  Matrix4? get endpointsGlobalToLocalTransform => _endpointInverse;
  @override
  bool get isSelectionDragging => _dragging;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _dispatcher.attach();
    document.addListener(_documentChanged);
    document.onMembersChanged = _membersChanged;
    _controller?._bindDelegate(this);
    _resumeBodySelection = _dragging;
    _scheduleSync();
  }

  @override
  void detach() {
    document.removeListener(_documentChanged);
    document.onMembersChanged = null;
    // 临时离树不结算指针和长按计时；重挂后同一手势继续，真正销毁由 dispose 收尾。
    _autoScroll.detach();
    _clearScrollListeners();
    if (_scrollActivity.value) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _scrollActivity.value = false;
      });
    }
    _dispatcher.detach(preserveEvent: true);
    _sources.clear();
    super.detach();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelGesture(notify: false);
    _clearScrollListeners();
    document.removeListener(_documentChanged);
    document.onMembersChanged = null;
    _controller?._unbindDelegate(this);
    _dispatcher.dispose();
    _autoScroll.dispose();
    _endpoints.dispose();
    _dragInfo.dispose();
    _scrollActivity.dispose();
    _mobileChrome.dispose();
    super.dispose();
  }

  @override
  void performLayout() {
    super.performLayout();
    _sources.clear();
    _scheduleSync();
  }

  @override
  void descendantSelectionVisualGeometryChanged(RenderObject source) => _scheduleSync();

  @override
  void selectionContentChanged() => _scheduleSync();

  @override
  bool hitTestSelf(Offset position) => _dispatcher.hitTestSelf(position);
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    _hitSelectableText = false;
    final hit = super.hitTest(result, position: position);
    if (!hit || !_enabled) return hit;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderParagraph && target.registrar != null) {
        _hitSelectableText = true;
        break;
      }
      if (target is RenderObject) {
        final participant = selectionParticipantOf(target);
        if (participant?.registrar != null && participant!.lastHitShowsSelectableTextCursor) {
          _hitSelectableText = true;
          break;
        }
      }
    }
    return hit;
  }

  @override
  PointerEnterEventListener? get onEnter => null;
  @override
  PointerExitEventListener? get onExit => null;
  @override
  bool get validForMouseTracker => attached && _enabled;
  @override
  MouseCursor get cursor =>
      _hitSelectableText && !ScrollCursorFreeze.contains(this) ? SystemMouseCursors.text : MouseCursor.defer;
  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) => _dispatcher.handleEvent(event, entry);

  ElEvent get _events => ElEvent(
    config: ElEventConfig(
      longPressDelay: _longPressDelay,
      longPressCancelDistance: kTouchSlop,
      dragStartDistance: _dragThreshold,
    ),
    onTapDown: _tapDown,
    onTapUp: _tapUp,
    onTapCancel: _tapCancel,
    onPointerCancel: _pointerCancel,
    onSecondaryTapDown: _secondaryDown,
    onSecondaryTapUp: _secondaryUp,
    onDoubleTapDown: (event) => _selectAt(event, paragraph: false),
    onTripleTapDown: (event) => _selectAt(event, paragraph: true),
    onLongPress: _longPress,
    onDragStart: _dragMounted ? _dragStart : null,
    onPointerSignal: (event) {
      final original = event.originalEvent;
      if ((_dragging || _handleSession) &&
          original is PointerSignalEvent &&
          _autoScroll.dispatchPointerSignalToDragViewport(original)) {
        event.stopPropagation();
      }
    },
    onKeyDown: _keyDown,
    onKeyRepeat: _keyDown,
  );

  void _setDragMounted(bool value, {bool deferred = false}) {
    final revision = ++_dragRevision;
    void apply() {
      if (_disposed || revision != _dragRevision || value == _dragMounted) return;
      _dragMounted = value;
      _dispatcher.event = _events;
    }

    if (deferred) {
      scheduleMicrotask(apply);
    } else {
      apply();
    }
  }

  RenderObject? _hitSource(Offset global) {
    if (!attached || !hasSize) return null;
    final result = BoxHitTestResult();
    hitTestChildren(result, position: globalToLocal(global));
    for (final entry in result.path) {
      if (entry.target is RenderObject) return entry.target as RenderObject;
    }
    return null;
  }

  bool _canStart(Offset global, RenderObject? source) {
    if (source is RenderParagraph && source.registrar == null) return false;
    if (source != null && !selectionGestureCanStartFrom(source, boundary: this)) return false;
    for (RenderObject? current = source; current != null && !identical(current, this); current = current.parent) {
      if (current is RenderSelectionIsland && current.enabled) return false;
      if (current is RenderSelectionView) return identical(current, this);
    }
    return true;
  }

  void _tapDown(ElEventDetails callback) {
    final event = callback.originalEvent;
    if (!attached || !_enabled || event is! PointerDownEvent || _pointer != null || !isPrimaryPointerDown(event)) {
      return;
    }
    if (ScrollCatchPointers.contains(event.pointer)) return;
    final source = _hitSource(event.position);
    if (!_canStart(event.position, source)) {
      for (RenderObject? node = source; node != null && !identical(node, this); node = node.parent) {
        if (node is RenderSelectionIsland && node.enabled) {
          clearSelection();
          break;
        }
      }
      return;
    }
    _claimFocus();
    _pointer = event.pointer;
    _pointerKind = event.kind;
    _down = event.position;
    _downSource = source;
    _wordSelected = false;
    _mobileGesture = scrollClaimsContentDrag(source, this, event.kind);
    if (!_mobileGesture) _installBodyRoute();
    _setDragMounted(!_mobileGesture, deferred: true);
  }

  void _tapUp(ElEventDetails callback) {
    final event = callback.originalEvent;
    if (event is! PointerUpEvent || event.pointer != _pointer || _dragging) return;
    final clear = clearOnTapOutside && !_wordSelected;
    _finishBody();
    if (clear) clearSelection();
  }

  void _tapCancel(ElEventDetails callback) {
    if (callback.cancelReason == ElEventCancelReason.selfGestureAccepted) return;
    // 小文档先离开点击边界、后跨过拖动阈值，不能把仍按住的桌面拖选结算掉。
    if (callback.cancelReason == ElEventCancelReason.tapRejected && (_dragging || !_mobileGesture)) return;
    _finishBody();
  }

  void _pointerCancel(ElEventDetails callback) {
    final original = callback.originalEvent;
    if (original is PointerCancelEvent && original.pointer == _pointer) _finishBody();
  }

  void _selectAt(ElEventDetails callback, {required bool paragraph}) {
    if (!attached || !_enabled || _mobileGesture || _pointer == null) return;
    final point = callback.globalPosition;
    _dispatch(
      paragraph
          ? SelectParagraphSelectionEvent(globalPosition: point)
          : SelectWordSelectionEvent(globalPosition: point),
    );
    _wordSelected = true;
    _mobileChrome.value = false;
    callback.stopPropagation();
  }

  void _longPress(ElEventDetails callback) {
    final down = _down;
    if (!attached ||
        !_enabled ||
        !_mobileGesture ||
        _pointer == null ||
        down == null ||
        document.selectableAt(down) == null) {
      // 拒绝选择也必须拒绝长按默认认领，让轻点或后续滚动继续竞争。
      callback.preventDefault();
      return;
    }
    callback.eagerGesture(cancelSelfTap: true);
    callback.stopPropagation();
    _mobileChrome.value = true;
    _dispatch(
      longPressSelection == LongPressSelection.paragraph
          ? SelectParagraphSelectionEvent(globalPosition: down)
          : SelectWordSelectionEvent(globalPosition: down),
    );
    if (document.value.status != SelectionStatus.uncollapsed) return;
    _dragging = true;
    _wordSelected = true;
    _lastDrag = down;
    _installBodyRoute();
    _handles.setDragInfo(SelectionDragInfo(kind: SelectionDragKind.longPress, side: null, globalPosition: down));
    _selectionControls.onLongPressStart(_pointerKind ?? PointerDeviceKind.touch);
    if (longPressHaptics) HapticFeedback.selectionClick();
  }

  void _dragStart(ElEventDetails callback) {
    final down = _down;
    if (!attached || !_enabled || _pointer == null || _mobileGesture || down == null) return;
    callback.eagerGesture(cancelSelfTap: true);
    callback.stopPropagation();
    _dragging = true;
    _mobileChrome.value = false;
    _dispatch(const ClearSelectionEvent());
    _dispatch(SelectionEdgeUpdateEvent.forStart(globalPosition: down));
    _dispatch(SelectionEdgeUpdateEvent.forEnd(globalPosition: callback.globalPosition));
    _installBodyRoute();
    _updateDrag(callback.globalPosition);
  }

  void _installBodyRoute() {
    if (_bodyRoute || _pointer == null) return;
    _bodyRoute = true;
    GestureBinding.instance.pointerRouter.addRoute(_pointer!, _bodyPointer);
    startGlobalPointerRoute();
  }

  void _bodyPointer(PointerEvent event) {
    if (_disposed || event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      _updateDrag(event.position);
    } else if (event is PointerUpEvent) {
      _updateDrag(event.position);
      final clear = !_dragging && clearOnTapOutside && !_wordSelected;
      _finishBody();
      if (clear) clearSelection();
    } else if (event is PointerCancelEvent || event is PointerRemovedEvent) {
      _finishBody();
    }
  }

  void _updateDrag(Offset global) {
    if (!_dragging || _handleSession) return;
    _lastDrag = global;
    if (!attached) return;
    if (!_mobileGesture || !_isMobileSelectionGap(global)) {
      _dispatch(
        SelectionEdgeUpdateEvent.forEnd(
          globalPosition: global,
          granularity: _mobileGesture ? TextGranularity.word : TextGranularity.character,
        ),
      );
    }
    if (_mobileGesture) {
      _handles.setDragInfo(SelectionDragInfo(kind: SelectionDragKind.longPress, side: null, globalPosition: global));
    }
    _autoScroll.updateForDrag(
      global,
      activateAutoScroll:
          !_mobileGesture || (_down != null && (global - _down!).distance >= longPressAutoScrollThreshold),
    );
  }

  /// 移动端跨过块间空白时保留已有端点，进入下一块的真实行带后才继续扩展。
  bool _isMobileSelectionGap(Offset global) {
    var above = false;
    var below = false;
    for (final member in document.members) {
      if (!member.value.hasContent) continue;
      final transform = member.getTransformTo(null);
      for (final bounds in member.boundingBoxes) {
        final rect = MatrixUtils.transformRect(transform, bounds);
        if (rect.isEmpty) continue;
        if (global.dy >= rect.top && global.dy <= rect.bottom) return false;
        above = above || rect.bottom < global.dy;
        below = below || rect.top > global.dy;
      }
    }
    // 文档外侧仍交给官方端点钳制与自动滚动，只有内容之间的空隙暂停扩展。
    return above && below;
  }

  void _finishBody({bool notify = true}) {
    if (_bodyRoute && _pointer != null) GestureBinding.instance.pointerRouter.removeRoute(_pointer!, _bodyPointer);
    _bodyRoute = false;
    if (!_handleSession) stopGlobalPointerRoute();
    _pointer = null;
    _pointerKind = null;
    _down = null;
    _dragging = false;
    _resumeBodySelection = false;
    _downSource = null;
    _lastDrag = null;
    _autoScroll.stop();
    _autoScroll.clearDragScrollViewports();
    _setDragMounted(false, deferred: true);
    if (notify && !_disposed) {
      if (!_handleSession) _handles.setDragInfo(null);
      _flushObservedText();
    }
  }

  void _cancelGesture({bool notify = true}) {
    _finishBody(notify: notify);
    _handleSession = false;
    _handleKind = null;
    _handles.detach();
    stopGlobalPointerRoute();
    final type = _activeHandleType;
    _activeHandleType = null;
    if (type != null) _selectionControls.onHandleDragEnd(type);
    _scrollQuiet?.cancel();
    _scrollQuiet = null;
    if (!_disposed && _scrollActivity.value) {
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) _scrollActivity.value = false;
        });
      } else {
        _scrollActivity.value = false;
      }
    }
  }

  void _claimFocus() {
    final node = rootFocusNode;
    if (node == null || !node.canRequestFocus) return;
    if (!_mustDeferNotifications) FocusManager.instance.applyFocusChangesIfNeeded();
    if (node.hasPrimaryFocus) return;
    // 保留后代输入控件的显式焦点；独立文档根之间则按本次点击切换。
    final primary = FocusManager.instance.primaryFocus;
    if (primary?.context != null &&
        primary!.ancestors.contains(node) &&
        primary.context!.findRenderObject() is! RenderSelectionView) {
      return;
    }
    node.requestFocus();
  }

  KeyEventResult handleRootKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    return _handleKey(event.logicalKey) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _keyDown(ElEventDetails event) {
    if (!_handleKey(event.logicalKey)) return;
    event.preventDefault();
    event.stopPropagation();
  }

  bool _handleKey(LogicalKeyboardKey? key) {
    if (!attached || !_enabled) return false;
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (key == LogicalKeyboardKey.escape && clearOnEsc && !contextMenuOpen) {
      clearSelection();
    } else if (command && key == LogicalKeyboardKey.keyA) {
      selectAllSelection();
    } else if (command && key == LogicalKeyboardKey.keyC && resolveSelectionInfo() != null) {
      unawaited(copySelection());
    } else {
      return false;
    }
    return true;
  }

  void _secondaryDown(ElEventDetails event) {
    if (_enabled) _claimFocus();
  }

  void _secondaryUp(ElEventDetails event) {
    if (!_enabled || resolveSelectionInfo() == null) return;
    if (hitTestSelection(event.globalPosition)) {
      onContextMenuRequested?.call(event.globalPosition);
      event.stopPropagation();
    } else {
      clearSelection();
    }
  }

  bool hitTestSelection(Offset global) {
    for (final member in document.members) {
      if (member.value.status != SelectionStatus.uncollapsed) continue;
      final transform = Matrix4.copy(member.getTransformTo(null));
      if (transform.invert() == 0) continue;
      final point = MatrixUtils.transformPoint(transform, global);
      if (member.value.selectionRects.any((rect) => rect.contains(point))) return true;
    }
    return false;
  }

  @override
  void selectAllSelection() {
    if (!_enabled) return;
    _claimFocus();
    _dispatch(const SelectAllSelectionEvent());
  }

  @override
  void clearSelection() {
    _mobileChrome.value = false;
    _cancelGesture();
    _dispatch(const ClearSelectionEvent());
  }

  @override
  Future<void> copySelection() async {
    final text = resolveSelectionInfo();
    if (text != null && text.isNotEmpty) await Clipboard.setData(ClipboardData(text: text));
  }

  void _dispatch(SelectionEvent event) {
    if (!attached || _disposed) return;
    _dispatching = true;
    try {
      document.dispatchSelectionEvent(event);
    } finally {
      _dispatching = false;
    }
    _syncDocument();
  }

  void _membersChanged() {
    _sources.clear();
    _scrollStart = _scrollEnd = null;
    _resumeBodySelection = _dragging;
    _scheduleSync();
  }

  void _documentChanged() {
    if (_dispatching) return;
    if (_mustDeferNotifications) {
      _scheduleSync();
    } else {
      _syncDocument();
    }
  }

  void _scheduleSync() {
    if (_disposed || _syncScheduled) return;
    _syncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (attached && !_disposed) _syncDocument();
    });
  }

  void _publishText(String? text) {
    if (_disposed) return;
    _controller?._updateSelection(text);
    if (text == _text) return;
    _text = text;
    onSelectionChanged?.call(text);
  }

  bool get _hasTextConsumers => onSelectionChanged != null || (_controller?._hasObservers ?? false);

  bool get _mustDeferNotifications => switch (SchedulerBinding.instance.schedulerPhase) {
    SchedulerPhase.persistentCallbacks ||
    SchedulerPhase.transientCallbacks ||
    SchedulerPhase.midFrameMicrotasks => true,
    _ => false,
  };

  void _flushObservedText() {
    if (_mustDeferNotifications) {
      _scheduleSync();
      return;
    }
    if (_hasTextConsumers) _publishText(document.getSelectedContent()?.plainText);
  }

  void _syncDocument() {
    if (!attached || _disposed || !hasSize) return;
    if (_mustDeferNotifications) {
      _scheduleSync();
      return;
    }
    if (_resumeBodySelection && _dragging && _lastDrag != null) {
      // 官方注册表重建按字符回放端点；在途长按继续使用原本的词粒度。
      _resumeBodySelection = false;
      _updateDrag(_lastDrag!);
      return;
    }
    _flushObservedText();
    onDragInfoChanged();
    final start = document.edge(end: false);
    final end = document.edge(end: true);
    if (!_enabled || document.value.status != SelectionStatus.uncollapsed || start == null || end == null) {
      _clearScrollListeners();
      if (_endpoints.value != null) _endpoints.value = null;
      return;
    }
    _syncScrollListeners(start, end);
    final next = SelectionEndpointsInfo(
      start: _endpoint(start, SelectionHandleSide.start),
      end: _endpoint(end, SelectionHandleSide.end),
      devicePixelRatio: _devicePixelRatio,
    );
    final inverse = getTransformTo(null);
    if (inverse.invert() != 0) _endpointInverse = inverse;
    if (_endpoints.value != next) _endpoints.value = next;
  }

  double get _devicePixelRatio {
    RenderObject? root = this;
    while (root != null) {
      if (root is RenderView) return root.flutterView.devicePixelRatio;
      root = root.parent;
    }
    return ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
  }

  RenderObject _sourceFor(SelectionDocumentEdge edge) {
    final member = edge.selectable;
    if (member is SelectionParticipant) return member.box;
    final cached = _sources[member];
    if (cached != null && cached.attached) return cached;
    final source = _hitSource(document.positionOf(edge)) ?? _downSource ?? this;
    _sources[member] = source;
    return source;
  }

  SelectionHandleEndpoint _endpoint(SelectionDocumentEdge edge, SelectionHandleSide side) {
    final member = edge.selectable;
    final point = edge.point;
    final global = MatrixUtils.transformPoint(
      member.getTransformTo(null),
      point.localPosition - Offset(0, point.lineHeight),
    );
    final local = globalToLocal(global);
    var rect = Rect.fromLTWH(local.dx - 1, local.dy, 2, point.lineHeight).intersect(Offset.zero & size);
    RenderObject? child = _sourceFor(edge);
    while (child != null && !identical(child, this)) {
      final parent = child.parent;
      if (parent == null || !parent.paintsChild(child)) {
        rect = Rect.zero;
        break;
      }
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) rect = rect.intersect(MatrixUtils.transformRect(parent.getTransformTo(this), clip));
      child = parent;
    }
    final participant = member is SelectionParticipant ? member : null;
    return SelectionHandleEndpoint(
      side: side,
      globalPosition: global,
      lineHeight: point.lineHeight,
      visible: !rect.isEmpty,
      textDirection:
          participant?.selectionTextDirection ??
          (point.handleType == TextSelectionHandleType.right
              ? (side == SelectionHandleSide.start ? TextDirection.rtl : TextDirection.ltr)
              : (side == SelectionHandleSide.start ? TextDirection.ltr : TextDirection.rtl)),
      handleColor: (participant?.effectiveSelectionBgColor ?? selectionColor).withAlpha(255),
    );
  }

  void _repaintSelected() {
    for (final member in document.members) {
      if (member is SelectionParticipant && member.value.hasSelection) member.markNeedsPaint();
    }
  }

  void _syncScrollListeners(SelectionDocumentEdge start, SelectionDocumentEdge end) {
    if (identical(_scrollStart, start.selectable) && identical(_scrollEnd, end.selectable)) return;
    _scrollStart = start.selectable;
    _scrollEnd = end.selectable;
    final next = <ScrollViewport>{
      ...SelectionAutoScrollController.scrollAncestorsOf(_sourceFor(start)),
      ...SelectionAutoScrollController.scrollAncestorsOf(_sourceFor(end)),
    };
    for (final viewport in _scrollViewports.toList()) {
      if (!next.contains(viewport)) {
        viewport.scrollOffsetListenable.removeListener(_scrollChanged);
        _scrollViewports.remove(viewport);
      }
    }
    for (final viewport in next) {
      if (_scrollViewports.add(viewport)) viewport.scrollOffsetListenable.addListener(_scrollChanged);
    }
  }

  void _clearScrollListeners() {
    for (final viewport in _scrollViewports) {
      viewport.scrollOffsetListenable.removeListener(_scrollChanged);
    }
    _scrollViewports.clear();
    _scrollStart = _scrollEnd = null;
    _scrollQuiet?.cancel();
    _scrollQuiet = null;
  }

  void _scrollChanged() {
    if (!_dragging && !_handleSession) {
      if (_pointer != null) _finishBody();
      if (!_scrollActivity.value) _scrollActivity.value = true;
      _scrollQuiet?.cancel();
      _scrollQuiet = Timer(const Duration(milliseconds: 300), () {
        _scrollQuiet = null;
        if (!_disposed) _scrollActivity.value = false;
      });
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks ||
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.transientCallbacks) {
      _scheduleSync();
    } else {
      _syncDocument();
    }
  }

  @override
  PointerDeviceKind? get activePointerKind => _handleKind ?? _pointerKind;
  @override
  bool get isPointerDragging => _dragging;
  @override
  bool get isHandleDragInProgress => _handleSession;
  @override
  RenderObject get autoScrollRoot => this;
  @override
  RenderObject? get referenceParticipantForAutoScroll {
    final end = document.edge(end: true, ordered: false);
    return end == null ? _downSource : _sourceFor(end);
  }

  @override
  RenderObject? get anchorParticipantForAutoScroll {
    final start = document.edge(end: false, ordered: false);
    return start == null ? _downSource : _sourceFor(start);
  }

  @override
  Ticker createAutoScrollTicker(TickerCallback onTick) => Ticker(onTick);
  @override
  bool get selectionUsesMobileAutoScroll => _mobileChrome.value || _handleSession;
  @override
  bool isTouchSelectionPointer(PointerDeviceKind kind) =>
      kind != PointerDeviceKind.mouse && kind != PointerDeviceKind.trackpad;
  @override
  SelectionAutoScrollConfig autoScrollConfigFor({required bool touch}) => touch ? touchAutoScroll : mouseAutoScroll;
  @override
  void invalidateParticipantGeometry() {
    _sources.clear();
    _scheduleSync();
  }

  @override
  void syncSelectionAfterScrollDelta() {
    if (_handleSession) {
      _handles.syncEndpointToLastDragPosition(_autoScroll.lastDragGlobalPosition);
    } else if (_lastDrag case final global?) {
      _updateDrag(global);
    }
  }

  TextSelectionHandleType _handleType(SelectionHandleSide side) {
    final endpoint = side == SelectionHandleSide.start ? endpoints?.start : endpoints?.end;
    final left = (side == SelectionHandleSide.start) != (endpoint?.textDirection == TextDirection.rtl);
    return left ? TextSelectionHandleType.left : TextSelectionHandleType.right;
  }

  void beginHandleDrag(SelectionHandleSide side, Offset global, {int? pointer, PointerDeviceKind? kind}) {
    if (!_enabled) return;
    _syncDocument();
    final start = document.edge(end: false);
    final end = document.edge(end: true);
    if (start == null || end == null) return;
    final fixed = side == SelectionHandleSide.start ? end : start;
    final moving = side == SelectionHandleSide.start ? start : end;
    final fixedPosition = document.positionOf(fixed);
    final movingPosition = document.positionOf(moving);
    _dispatch(const ClearSelectionEvent());
    _dispatch(SelectionEdgeUpdateEvent.forStart(globalPosition: fixedPosition));
    _dispatch(SelectionEdgeUpdateEvent.forEnd(globalPosition: movingPosition));
    _handleSession = true;
    _handleKind = kind ?? PointerDeviceKind.touch;
    _activeHandleType = _handleType(side);
    _selectionControls.onHandleDragStart(_activeHandleType!, _handleKind!);
    _handles.begin(side, global, pointer: pointer);
  }

  void updateHandleDrag(Offset global) => _handles.update(global);
  void endHandleDrag() {
    _handles.end();
    _handleSession = false;
    _handleKind = null;
    final type = _activeHandleType;
    _activeHandleType = null;
    if (type != null) _selectionControls.onHandleDragEnd(type);
  }

  @override
  bool setSelectionHandleEndpoint(SelectionHandleSide side, Offset global) {
    if (!attached || _isMobileSelectionGap(global)) return false;
    final before = document.edge(end: true, ordered: false);
    final fixed = document.edge(end: false, ordered: false);
    _dispatch(SelectionEdgeUpdateEvent.forEnd(globalPosition: global));
    final current = document.edge(end: true, ordered: false);
    if (fixed != null &&
        current != null &&
        before != null &&
        identical(fixed.selectable, current.selectable) &&
        fixed.offset == current.offset) {
      // 触摸句柄至少保留一个字符，拖到文档边缘不能把自身选区和 chrome 清掉。
      _dispatch(
        GranularlyExtendSelectionEvent(
          forward: before.offset > fixed.offset,
          isEnd: true,
          granularity: TextGranularity.character,
        ),
      );
    }
    final after = document.edge(end: true, ordered: false);
    final changed = !identical(before?.selectable, after?.selectable) || before?.offset != after?.offset;
    final type = _activeHandleType;
    if (changed && type != null) _selectionControls.onHandleSelectionChanged(type);
    return changed;
  }

  @override
  void onDragInfoChanged() {
    if (_disposed || !attached) return;
    if (_mustDeferNotifications) {
      if (_dragInfoScheduled) return;
      _dragInfoScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _dragInfoScheduled = false;
        if (!_disposed) onDragInfoChanged();
      });
      return;
    }
    if (_dragInfo.value != _handles.dragInfo) _dragInfo.value = _handles.dragInfo;
  }

  @override
  ({Offset globalBottom, double lineHeight, double idealVerticalOffset, double touchOffsetY})? handleAnchorFor(
    SelectionHandleSide side,
  ) {
    final endpoint = side == SelectionHandleSide.start ? endpoints?.start : endpoints?.end;
    if (endpoint == null) return null;
    final type = _handleType(side);
    return (
      globalBottom: endpoint.globalBottom,
      lineHeight: endpoint.lineHeight,
      idealVerticalOffset: _selectionControls.resolveHandleIdealVerticalOffset(type, endpoint.lineHeight),
      touchOffsetY: _selectionControls.resolveHandleTouchOffsetY(type, endpoint.lineHeight),
    );
  }

  @override
  int? handleEndpointOffsetFor(SelectionHandleSide side) => document.edge(end: true, ordered: false)?.offset;
  @override
  bool get handleHapticsEnabled => handleHaptics;
  @override
  void setHandleEndpointOffset(SelectionHandleSide side, int offset) {
    final edge = document.edge(end: true, ordered: false);
    if (edge == null) return;
    final target = offset.clamp(0, edge.selectable.contentLength);
    for (var left = (target - edge.offset).abs(); left > 0; left--) {
      _dispatch(
        GranularlyExtendSelectionEvent(
          forward: target > edge.offset,
          isEnd: true,
          granularity: TextGranularity.character,
        ),
      );
    }
  }

  @override
  void syncDragScrollViewportsForHandleDrag() => _autoScroll.syncDragScrollViewports();
  @override
  void updateAutoScrollForHandleDrag(Offset global) {
    if (attached) _autoScroll.updateForDrag(global);
  }

  @override
  void stopAutoScrollAndClearViewports() {
    _autoScroll.stop();
    _autoScroll.clearDragScrollViewports();
  }

  @override
  void flushDeferredSelectionInfo() => _flushObservedText();
  @override
  void startGlobalPointerRoute() {
    if (_globalRoute) return;
    _globalRoute = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_globalPointer);
  }

  @override
  void stopGlobalPointerRoute() {
    if (!_globalRoute) return;
    _globalRoute = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_globalPointer);
  }

  void _globalPointer(PointerEvent event) {
    if (_disposed) return;
    if (attached && event is PointerSignalEvent && (_dragging || _handleSession)) {
      _autoScroll.dispatchPointerSignalToDragViewport(event);
    } else if (event is PointerRemovedEvent) {
      if (event.pointer == _pointer) _finishBody();
      if (_handles.onRoutedPointerRemoved(event.pointer)) endHandleDrag();
    }
  }

  SelectionMagnifierFocus? magnifierLineGeometryForDrag() {
    if (!attached || _dragInfo.value == null) return null;
    final edge = document.edge(end: true, ordered: false);
    if (edge == null) return null;
    final member = edge.selectable;
    final point = edge.point;
    final bounds = member.boundingBoxes;
    final local = bounds
        .where((rect) => rect.top <= point.localPosition.dy && rect.bottom >= point.localPosition.dy - point.lineHeight)
        .firstOrNull;
    final box = local ?? (bounds.isEmpty ? Rect.zero : bounds.first);
    final transform = member.getTransformTo(null);
    final top = MatrixUtils.transformPoint(transform, point.localPosition - Offset(0, point.lineHeight));
    final left = MatrixUtils.transformPoint(transform, Offset(box.left, point.localPosition.dy - point.lineHeight));
    final right = MatrixUtils.transformPoint(transform, Offset(box.right, point.localPosition.dy - point.lineHeight));
    return (
      caretX: top.dx,
      line: SelectionLineGeometry(
        lineTop: top.dy,
        lineHeight: point.lineHeight,
        lineLeft: left.dx,
        lineRight: right.dx,
      ),
    );
  }
}
