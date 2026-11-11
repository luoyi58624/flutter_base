import 'dart:async' show Completer, Timer, scheduleMicrotask, unawaited;
import 'dart:math' as math;
import 'dart:ui' show SemanticsInputType, ViewFocusEvent, ViewFocusState;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/foundation.dart'
    show
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        Listenable,
        TargetPlatform,
        ValueListenable,
        ValueNotifier,
        defaultTargetPlatform,
        kIsWeb,
        listEquals,
        visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../utils/internal/focus.dart';
import '../../widgets/popup/context_menu.dart' show ElContextMenuHandle;
import '../../utils/internal/pixel_grid.dart';
import '../../widgets/scroll/dual_axis_scroll.dart' show DualAxisScroll;
import '../../widgets/scroll/scroll.dart' show ElScroll;
import '../../widgets/scroll/viewport.dart' show ScrollViewport;
import '../../slivers/recycler/sliver_recycler.dart' show ElSliverRecyclerController, ElSliverRecyclerList;
import '../selection/common/selection_core.dart';
import '../view/event/event.dart';
import '../view/render/render_view.dart' show ElRenderView, CascadeBridgeChanges, ViewStateRenderAccess;
import '../view/semantics/semantics.dart';
import '../view/style/style.dart';
import '../view/view.dart';
import 'composer.dart';
import 'controller.dart' show EditableViewport;
import 'editable_controller.dart';
import 'editable_style.dart';
import 'editing/editable_ops.dart';
import 'editing/editable_word_navigator.dart';
import 'ime/editable_floating_cursor_overlay.dart';
import 'ime/editable_floating_cursor_state.dart';
import 'ime/editable_ime_client.dart';
import 'inherited_text.dart';
import 'input_events.dart';
import 'keyboard/editable_key_handler.dart';
import 'keyboard/input_action.dart';
import 'line_height.dart';
import 'model/document_change_set.dart';
import 'model/document_version.dart';
import 'model/edit_transaction.dart';
import 'model/editable_selection.dart';
import 'model/text_document.dart';
import 'projection/editable_hidden_areas_model.dart';
import 'projection/editable_line_projection.dart';
import 'render/box_selection_geometry.dart';
import 'render/caret_blink_driver.dart';
import 'render/editable_caret_motion_overlay.dart';
import 'render/editable_line_view.dart';
import 'render/editable_render_scope.dart';
import 'render/editable_selection_layer.dart';

void _runClipboardOperation(Future<void> operation, String action) {
  unawaited(
    operation.catchError((Object error, StackTrace stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'el_ui editable',
          context: ErrorDescription('while performing editable clipboard $action'),
        ),
      );
    }),
  );
}

bool _editableImeConfigChanged(EditableConfiguration current, EditableConfiguration previous) {
  return current.keyboardType != previous.keyboardType ||
      current.textInputAction != previous.textInputAction ||
      current.actionLabel != previous.actionLabel ||
      current.keyboardAppearance != previous.keyboardAppearance ||
      current.textCapitalization != previous.textCapitalization ||
      current.smartDashesType != previous.smartDashesType ||
      current.smartQuotesType != previous.smartQuotesType ||
      current.autocorrect != previous.autocorrect ||
      current.enableSuggestions != previous.enableSuggestions ||
      current.enableInteractiveSelection != previous.enableInteractiveSelection ||
      current.enableIMEPersonalizedLearning != previous.enableIMEPersonalizedLearning ||
      !listEquals(current.allowedMimeTypes, previous.allowedMimeTypes) ||
      !listEquals(current.hintLocales, previous.hintLocales) ||
      (current.onUnhandledContent == null) != (previous.onUnhandledContent == null) ||
      current.enableInlinePrediction != previous.enableInlinePrediction ||
      !listEquals(current.autofillHints?.toList(growable: false), previous.autofillHints?.toList(growable: false)) ||
      current.autofillHintText != previous.autofillHintText;
}

/// 可编辑视图基元：所有文本输入类组件的底层核心。
///
/// 从零构建，不依赖官方 EditableText / RenderEditable。分层对齐 vscode 编辑器
/// 内核（model / viewModel / cursor / view / tokens）：
/// - **model**：[TextDocument] 行存储 + 懒重建行首索引 + 编辑历史；
/// - **viewModel**：渲染协调器承担坐标转换（doc offset ↔ 视觉几何，wrap 投影
///   经 TextPainter），mounted 行注册表做指针命中；
/// - **cursor / commands**：编辑操作层把键盘 / 指针意图翻译成编辑原语；
/// - **view**：一行一个 [RenderEditableLine]，行列表由 [ElScroll] 中的回收列表
///   （ElSliverRecyclerList）虚拟化，文档规模不影响帧成本；
/// - **tokens / decorations**：[EditableComposer] 行装配器——上层凭它做语法
///   高亮与富文本呈现，内核只认纯文本坐标。
///
/// 其余关键设计：
/// - **windowed IME**：平台通道只同步覆盖选区的整行窗口，大文档击键零全量
///   序列化；
/// - **headless**：不带任何边框 / 背景 / 装饰，也不声明字号或行高；外观由
///   调用方包一层 [ElView] 声明；文字、方向和选区沿祖先样式通道直接更新到
///   渲染层，Flutter TextStyle 只承载内核解析后的排版数据。
///
/// 上层构建方式：
/// - 单行输入框：`EditableController(singleLine: true)` +
///   `style: EditableConfiguration(softWrap: false)`
///   + 外层 ElView 定高包装；
/// - 多行输入框：默认形态 + 外层装饰；
/// - 富文本 / 代码编辑器：自定义 [EditableConfiguration.composer] 呈现 + 属性模型监听
///   [EditableController.docChanges] 做坐标同步，属性变化后
///   [EditableController.invalidatePresentation]。
///
/// 状态唯一入口是 [EditableController]（文本 / 选区 / composing / undo）；
/// 几何查询（弹层定位等）走 `GlobalKey<_EditableViewState>` 的公开门面。
/// 布局合约：外层需给出有界高度（编辑器 = 滚动视口）；
/// [EditableConfiguration.softWrap] 为 false 时进入双轴滚动。
class EditableView extends StatefulWidget {
  /// 创建可编辑视图；未传控制器或焦点节点时由组件内部创建并管理。
  ///
  /// 默认采用普通输入样式；代码编辑行为可从 [EditableConfiguration.editor] 开始配置，
  /// 或直接使用上层 `ElEditor`。
  const EditableView({
    super.key,
    this.controller,
    this.hiddenAreas,
    this.focusNode,
    this.event,
    this.selectorHandler,
    this.wordBoundary,
    @internal this.selectionActions,
    this.style = const EditableConfiguration(),
    this.scrollController,
    this.horizontalScrollController,
    this.onStateChanged,
    this.onInsertNewline,
    this.tabSize = 4,
    this.inheritTextAlign = false,
  });

  final ElEvent? event;
  final bool Function(String)? selectorHandler;

  /// 上层提供的词边界，用于点选和拖选。
  final TextRange Function(TextPosition)? wordBoundary;
  @internal
  final SelectionActions Function()? selectionActions;
  final VoidCallback? onInsertNewline;
  final int tabSize;
  final bool inheritTextAlign;

  /// 状态控制器；null 时内部自建自管。
  final EditableController? controller;

  /// 可选的整行隐藏区域模型；仅投影视图，不改写正文、选区或撤销历史。
  ///
  /// 模型必须绑定到与 [controller] 完全相同的实例，生命周期仍由调用方管理。
  /// null 表示所有原文逻辑行都参与视图投影。
  final EditableLineMask? hiddenAreas;

  /// 焦点节点；null 时内部自建自管。外借节点已有 `onKeyEvent` 会保留在
  /// [EditableConfiguration.onKeyEvent] 之后、编辑器默认命令之前，并在卸载时安全恢复。
  final FocusNode? focusNode;

  /// 除控制器与焦点所有权之外的全部外观和行为声明。
  final EditableConfiguration style;

  /// 垂直滚动控制器；null 时内部自建（index 定位能力编辑器自身依赖）。
  final ScrollController? scrollController;

  /// 双轴（[EditableConfiguration.softWrap] false）下的水平滚动控制器。
  final ScrollController? horizontalScrollController;

  /// 编辑器 State 挂载/卸载通知；用于上层控制门面读取几何 API。
  final ValueChanged<EditableViewport?>? onStateChanged;

  @override
  State<EditableView> createState() => _EditableViewState();
}

enum _EditableAutoScrollKind { mouse, longPress, handle }

enum _EditableDragSelectionGranularity { character, word, line }

enum _MacOSSelectorAction {
  deleteBackward,
  deleteWordBackward,
  deleteToBeginningOfLine,
  deleteForward,
  deleteWordForward,
  deleteToEndOfLine,
  moveLeft,
  moveRight,
  moveForward,
  moveBackward,
  moveUp,
  moveDown,
  moveLeftAndModifySelection,
  moveRightAndModifySelection,
  moveUpAndModifySelection,
  moveDownAndModifySelection,
  moveWordLeft,
  moveWordRight,
  moveToBeginningOfParagraph,
  moveToEndOfParagraph,
  moveWordLeftAndModifySelection,
  moveWordRightAndModifySelection,
  moveParagraphBackwardAndModifySelection,
  moveParagraphForwardAndModifySelection,
  moveToLeftEndOfLine,
  moveToRightEndOfLine,
  moveToBeginningOfDocument,
  moveToEndOfDocument,
  moveToLeftEndOfLineAndModifySelection,
  moveToRightEndOfLineAndModifySelection,
  moveToBeginningOfDocumentAndModifySelection,
  moveToEndOfDocumentAndModifySelection,
  transpose,
  scrollToBeginningOfDocument,
  scrollToEndOfDocument,
  scrollPageUp,
  scrollPageDown,
  pageUpAndModifySelection,
  pageDownAndModifySelection,
  cancelOperation,
  insertTab,
  insertBacktab,
}

final class _EditablePointerSelectionCandidate {
  const _EditablePointerSelectionCandidate({
    required this.pointer,
    required this.buttons,
    required this.controller,
    required this.docRevision,
    required this.visualRevision,
    required this.presentationRevision,
    required this.selections,
    required this.lineProjection,
    required this.projectionRevision,
    required this.readOnly,
    required this.obscureText,
  });

  final int pointer;
  final int buttons;
  final EditableController controller;
  final int docRevision;
  final int visualRevision;
  final int presentationRevision;
  final EditableSelectionSet selections;
  final EditableLineProjection lineProjection;
  final int projectionRevision;
  final bool readOnly;
  final bool obscureText;
}

/// [EditableView] 的 State，同时是编辑器实例的**公开几何门面**
/// （对齐 vscode 的 editor 实例 API）：上层用 `GlobalKey<_EditableViewState>`
/// 拿到它，为补全弹层 / 悬浮工具条等做 caret 定位与命中查询。
class _EditableViewState extends State<EditableView>
    with TickerProviderStateMixin<EditableView>, UndoManagerClient, WidgetsBindingObserver
    implements EditableViewport {
  EditableController? _ownController;
  FocusNode? _ownFocusNode;
  ScrollController? _ownScrollController;
  ScrollController? _ownHorizontalController;

  /// style.autofocus 的首帧聚焦是否已排程。
  bool _autofocusScheduled = false;

  @override
  double? textXAtGlobal(Offset point) => _textXAtGlobal(point);

  @override
  List<TextSelection> selectionsForBox(
    TextPosition anchor,
    TextPosition active, {
    required double startX,
    required double endX,
    int limit = 10000,
  }) {
    if (limit < 1 || limit > 100000) throw RangeError.range(limit, 1, 100000, 'limit');
    final previousX = _boxQueryAnchorX;
    _boxQueryAnchorX = startX;
    try {
      final rows = _boundedColumnSelectionRows(
        anchorRow: _visualRowAt(anchor),
        activeRow: _visualRowAt(active),
        activeX: endX,
        limit: limit,
      );
      TextSelection convert(EditableBoxSelectionRow row) => TextSelection(
        baseOffset: row.anchor.offset,
        extentOffset: row.active.offset,
        affinity: row.active.affinity,
        isDirectional: true,
      );
      return [convert(rows.last), ...rows.take(rows.length - 1).map(convert)];
    } finally {
      _boxQueryAnchorX = previousX;
    }
  }

  /// 测试探针：按视图行号跳转行列表，完成定位的那一帧后返回 true。
  @visibleForTesting
  Future<bool> debugJumpToRow(int row, {double alignment = 0}) => _rowJump.jumpToIndex(row, alignment: alignment);

  /// 白盒几何查询直接指定视觉行，不创建或修改光标。
  @visibleForTesting
  List<TextSelection> debugBoxSelections({
    required int anchorLine,
    required int activeLine,
    int anchorVisualLine = 0,
    int activeVisualLine = 0,
    double anchorX = 0,
    double activeX = 0,
    required int limit,
  }) {
    final previousX = _boxQueryAnchorX;
    _boxQueryAnchorX = anchorX;
    try {
      final rows = _boundedColumnSelectionRows(
        anchorRow: (line: anchorLine, visualLine: anchorVisualLine),
        activeRow: (line: activeLine, visualLine: activeVisualLine),
        activeX: activeX,
        limit: limit,
      );
      TextSelection convert(EditableBoxSelectionRow row) => TextSelection(
        baseOffset: row.anchor.offset,
        extentOffset: row.active.offset,
        affinity: row.active.affinity,
        isDirectional: true,
      );
      return [convert(rows.last), ...rows.take(rows.length - 1).map(convert)];
    } finally {
      _boxQueryAnchorX = previousX;
    }
  }

  @override
  TextPosition? moveHorizontal(TextPosition position, {required bool left}) =>
      _scope.moveHorizontal(position, left: left);

  @override
  TextPosition? horizontalSelectionEdge(TextRange range, {required bool left}) =>
      _scope.horizontalSelectionEdge(range, left: left);

  @override
  double caretXFor(TextPosition position) => _scope.caretXFor(position);

  @override
  TextPosition? moveVertical(TextPosition position, {required bool down, required double xGoal}) =>
      _scope.moveVertical(position, down: down, xGoal: xGoal);

  @override
  TextPosition pageMove(
    TextPosition position, {
    required bool down,
    required double xGoal,
    required double pageExtent,
  }) => _scope.pageMove(position, down: down, xGoal: xGoal, pageExtent: pageExtent);

  @override
  TextPosition visualLineEdge(TextPosition position, {required bool end}) => _scope.visualLineEdge(position, end: end);

  @override
  TextRange wordBoundary(TextPosition position) => widget.wordBoundary?.call(position) ?? _scope.wordBoundary(position);

  /// 当前编辑器的文本、选区、组合区与历史控制器。
  EditableController get controller => _controller;

  /// 当前整行隐藏区域模型；null 表示恒等行投影。
  EditableLineMask? get hiddenAreas => _lineProjection.hiddenAreas;

  /// 当前编辑器的焦点节点。
  FocusNode get focusNode => _focusNode;

  /// 当前主光标的全局 paint 矩形；只读模式仍保留几何查询，但不会绘制光标。
  @override
  ValueListenable<Rect?> get caretGeometry {
    final existing = _caretGeometryNotifier;
    if (existing != null) return existing;
    if (_caretGeometryDisposed) {
      throw StateError('_EditableViewState 已释放，不能再创建 caretGeometry。');
    }
    final notifier = ValueNotifier<Rect?>(
      mounted && _elementActive && !_tearingDownPipeline ? caretRectGlobal() : null,
    );
    _caretGeometryNotifier = notifier;
    _scheduleCaretGeometryUpdate();
    return notifier;
  }

  /// 隐藏映射结构真正变化后执行的虚拟列表全量失效次数。
  @visibleForTesting
  int get debugLineProjectionStructureResetCount => _debugLineProjectionStructureResetCount;

  /// 测试探针：首挂后是否已经按需创建编辑命令操作层。
  @visibleForTesting
  bool get debugOpsInitialized => _opsInstance != null;

  /// 测试探针：首挂后是否已经按需创建指针多选区操作层。
  @visibleForTesting
  /// 测试探针：首挂后是否已经按需创建键盘命令分发层。
  @visibleForTesting
  bool get debugKeyHandlerInitialized => _keyHandlerInstance != null;

  /// 测试探针：首挂后是否已经按需创建平台输入法客户端。
  @visibleForTesting
  bool get debugImeInitialized => _imeInstance != null;

  /// 测试探针：首挂后是否已经按需创建自动填充客户端。
  @visibleForTesting
  bool get debugAutofillClientInitialized => _autofillClientInstance != null;

  /// 测试探针：自动填充客户端当前是否注册到所在 AutofillGroup。
  @visibleForTesting
  bool get debugAutofillClientRegistered => _autofillClientRegistered;

  /// 测试探针：首挂后是否已经按需创建移动选区拖柄控制器。
  @visibleForTesting
  bool get debugSelectionHandleControllerInitialized => _selectionHandleControllerInstance != null;

  /// 测试探针：首挂后是否已经按需创建移动选区工具条通道。
  @visibleForTesting
  bool get debugSelectionToolbarActionsInitialized => _selectionToolbarActionsInstance != null;

  /// 测试探针：当前是否存在恒等投影不需要的选区修复任务。
  @visibleForTesting
  bool get debugLineProjectionSelectionRepairScheduled => _lineProjectionRepairScheduled;

  /// 测试探针：当前是否为 soft-wrap 输入额外持有内部横向滚动控制器。
  @visibleForTesting
  bool get debugOwnHorizontalControllerInitialized => _ownHorizontalController != null;

  EditableController get _controller => widget.controller ?? (_ownController ??= EditableController());

  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'EditableView'));

  /// style.autofocus：首帧后请求焦点，每个 State 生命周期只排程一次。
  ///
  /// 焦点节点可能由调用方提供（普通 [FocusNode] 不携带 autofocus 开关），自动
  /// 聚焦属于编辑器语义，由状态自己排程，不依赖节点上的声明。只在首次挂载
  /// （initState）调用；GlobalKey 重挂、didUpdateWidget 重建管线、热重载都不会
  /// 重复排程，避免反复抢焦点。
  void _scheduleAutofocus() {
    if (_autofocusScheduled) return;
    _autofocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.style.readOnly) return;
      final node = _focusNode;
      if (!node.canRequestFocus) return;
      FocusUtil.markReason(node, ElFocusReason.lifecycle);
      node.requestFocus();
    });
  }

  ScrollController get _scrollController => widget.scrollController ?? (_ownScrollController ??= ScrollController());

  ScrollController get _horizontalController =>
      widget.horizontalScrollController ?? (_ownHorizontalController ??= ScrollController());

  ScrollController? get _horizontalControllerForCurrentMode =>
      widget.style.softWrap ? null : widget.horizontalScrollController ?? _horizontalController;

  late EditableRenderScope _scope;
  late EditableLineProjection _lineProjection;
  EditableOps? _opsInstance;
  EditableKeyHandler? _keyHandlerInstance;
  EditableImeClient? _imeInstance;
  late final CaretBlinkDriver _caretBlink;
  _EditableAutofillClient? _autofillClientInstance;
  AutofillGroupState? _currentAutofillScope;
  bool _autofillClientRegistered = false;

  EditableOps get _ops => _opsInstance ??= _createOps();

  EditableKeyHandler get _keys => _keyHandlerInstance ??= _createKeyHandler();

  EditableImeClient get _ime => _imeInstance ??= _createImeClient();

  _EditableAutofillClient get _autofillClient => _autofillClientInstance ??= _EditableAutofillClient(this);

  FocusNode? _installedFocusNode;
  FocusOnKeyEventCallback? _previousFocusKeyHandler;
  FocusOnKeyEventCallback? _installedFocusKeyHandler;
  int _focusRebindGeneration = 0;
  int? _pendingFocusRebindGeneration;
  ScrollController? _listenedScrollController;
  ScrollController? _listenedHorizontalController;

  bool _focused = false;
  bool _selectionTextBlocked = false;
  ({bool canUndo, bool canRedo})? _lastSystemUndoState;
  bool _systemUndoStateScheduled = false;
  int? _configuredViewId;
  int _visibleLineCount = 1;
  int _lineProjectionDocRevision = -1;
  int _lineProjectionMappingRevision = -1;
  int _debugLineProjectionStructureResetCount = 0;
  int _lineProjectionAnchorEpoch = 0;
  ScrollController? _lineProjectionAnchorScrollController;
  bool _pendingDocumentProjectionStructureChange = false;
  bool _updatingLineProjectionBinding = false;
  int _lineProjectionRepairEpoch = 0;
  int _lineProjectionRepairTaskGeneration = 0;
  bool _lineProjectionRepairScheduled = false;
  _LineProjectionRepairRequest? _pendingLineProjectionRepair;

  // 已物化逻辑行的稳定身份：文档 splice 后按 offset 迁移，让虚拟滚动现成的
  // keyed anchor / extent remap 能保住可视正文，而不是把 index 误当身份。
  static const int _recentLineIdentityCapacity = 512;
  static const int _retainedLineIdentityCapacity = _recentLineIdentityCapacity * 2;
  final Object _lineIdentityOwner = Object();
  final Map<int, _EditableLineIdentity> _lineIdentitiesByIndex = <int, _EditableLineIdentity>{};
  final Map<_EditableLineKey, _EditableLineIdentity> _lineIdentitiesByKey = <_EditableLineKey, _EditableLineIdentity>{};
  int _lineIdentityUseTick = 0;
  // 按序号跳转行列表：定位远处行时由回收列表先实测目标行，再修正一次偏移。
  final _rowJump = ElSliverRecyclerController();
  EditableRenderConfig? _appliedRenderConfig;
  double? _fixedLogicalLineExtent;
  bool _fixedLogicalLineExtentRebuildScheduled = false;
  ({TextStyle style, TextDirection direction, TextAlign align})? _lastImeStyle;
  int _controllerConfigurationRevision = -1;
  bool _controllerSingleLine = false;
  bool _imeConfigurationUpdateScheduled = false;
  int _imeConfigurationUpdateGeneration = 0;

  // 拖选会话。
  bool _dragSelecting = false;
  _EditableDragSelectionGranularity _dragSelectionGranularity = _EditableDragSelectionGranularity.character;
  TextRange? _dragAnchorLineRange;
  bool _multiClickSelectionAppliedOnDown = false;
  double _boxQueryAnchorX = 0.0;
  bool _draggingSelectionHandle = false;
  int _selectionGestureWriteDepth = 0;
  _EditableAutoScrollKind _dragAutoScrollKind = _EditableAutoScrollKind.mouse;
  bool _dragAutoScrollActivated = false;
  Offset _dragAutoScrollOrigin = Offset.zero;
  TextPosition _dragAnchor = const TextPosition(offset: 0);
  Offset _dragGlobal = Offset.zero;
  _EditablePointerSelectionCandidate? _pointerSelectionCandidate;

  // 主选区内部文本拖放：candidate 阶段不改选区，首个 dragStart 才进入会话。

  // 移动选区 Chrome 值通道与拖动适配。
  final ValueNotifier<SelectionEndpointsInfo?> _selectionEndpoints = ValueNotifier(null);
  final ValueNotifier<SelectionDragInfo?> _selectionDragInfo = ValueNotifier(null);
  final ValueNotifier<bool> _selectionScrollActivity = ValueNotifier(false);
  final ValueNotifier<bool> _selectionChromeVisibility = ValueNotifier(false);
  ValueNotifier<SelectionActions>? _selectionToolbarActionsInstance;
  _EditableSelectionChromeAdapter? _selectionChromeAdapterInstance;
  SelectionMagnifierHandleController? _selectionHandleControllerInstance;
  SelectionControls _selectionControls = const DesktopSelectionControls();
  bool _selectionControlsResolved = false;
  bool _showSelectionHandles = false;
  bool _showSelectionMagnifier = false;
  bool _showSelectionToolbar = false;
  bool _selectionChromeVisible = false;
  bool _selectionUsesMobileChrome = false;
  bool _selectionGeometryScheduled = false;
  int _selectionGeometryDocRevision = -1;
  int _selectionGeometryPresentationRevision = -1;
  Matrix4? _selectionChromeGlobalToLocalTransform;
  int _endpointDirectionCacheRevision = -1;
  int _endpointDirectionCacheConfigRevision = -1;
  int _endpointDirectionCacheProjectionRevision = -1;
  final Map<({int offset, bool preferUpstream, int line}), TextDirection> _endpointDirectionCache = {};
  static const int _endpointDirectionCacheCapacity = 8;
  ValueNotifier<Rect?>? _caretGeometryNotifier;
  bool _caretGeometryScheduled = false;
  bool _caretGeometryDisposed = false;
  bool _caretGeometryDisposeAfterNull = false;
  int _debugCaretGeometryPublishCount = 0;

  // 主 caret 位置动画只接管绘制，逻辑几何始终立即指向最新 selection active。
  final ValueNotifier<Rect?> _caretMotionRect = ValueNotifier<Rect?>(null);
  AnimationController? _caretMotionController;
  Rect? _caretMotionFrom;
  Rect? _caretMotionTarget;
  TextPosition? _caretMotionPosition;
  ({TextPosition position, Rect from})? _pendingCaretMotion;
  bool _caretAnimationsEnabled = true;
  bool _caretBlinkTickerModeEnabled = true;
  bool _caretBlinkViewActive = true;
  // 窗口失活、热重载或页面重建期间可能丢失修饰键 up；在确认当前
  // HardwareKeyboard 状态可信之前，不允许它创建多光标。

  /// 3. 当前代数内收到事件后观察到全部修饰键均已释放。
  /// null 表示不得采信 HardwareKeyboard 的 pressed 状态。

  // iOS 浮动光标只在真实平台回调期间活跃；正文选区始终由 controller 独占。
  final EditableFloatingCursorState _floatingCursorState = EditableFloatingCursorState();
  final ValueNotifier<EditableFloatingCursorFrame?> _floatingCursorFrame = ValueNotifier(null);
  AnimationController? _floatingCursorResetController;
  VoidCallback? _floatingCursorResetListener;
  EditableRenderConfig? _floatingCursorRenderConfig;
  EdgeInsets? _floatingCursorPadding;
  int? _floatingCursorSystemFontsRevision;
  int _floatingCursorEpoch = 0;
  bool _floatingCursorReprojectScheduled = false;

  // 长按拖选直接走 pointer route，不与祖先滚动的 Drag recognizer 竞争。
  int? _longPressPointer;
  PointerRoute? _longPressPointerRoute;
  bool _longPressFloatingCursor = false;
  Offset _longPressFloatingOrigin = Offset.zero;

  // handle 拖动始终以一端为固定锚，另一端跨越后只切换逻辑 side。
  int? _handleFixedOffset;
  int? _handleMovingOffset;
  SelectionHandleSide? _handleMovingSide;
  TextAffinity _handleMovingAffinity = TextAffinity.downstream;
  final Map<int, TextAffinity> _handleAffinityHistory = <int, TextAffinity>{};
  int? _handleInitialOffset;
  Offset? _handleDragStartGlobal;

  Timer? _selectionScrollIdleTimer;
  ElContextMenuHandle? _selectionMenuEntry;
  Offset? _secondaryTapGlobal;
  int _clipboardOperationEpoch = 0;
  int _debugSelectionGeometryUpdateCount = 0;
  int _debugLastColumnSelectionPainterQueryCount = 0;

  _EditableSelectionChromeAdapter get _selectionChromeAdapter =>
      _selectionChromeAdapterInstance ??= _EditableSelectionChromeAdapter(this);

  SelectionMagnifierHandleController get _selectionHandleController =>
      _selectionHandleControllerInstance ??= SelectionMagnifierHandleController(_selectionChromeAdapter);

  ValueNotifier<SelectionActions> get _selectionToolbarActions =>
      _selectionToolbarActionsInstance ??= ValueNotifier(_selectionActions());

  // 拖选边缘自动滚动 ticker。
  Ticker? _dragScrollTicker;
  Duration _dragScrollLastTick = Duration.zero;

  // post-frame 合并调度。
  bool _framePending = false;
  int _stateCallbackEpoch = 0;
  ValueChanged<EditableViewport?>? _notifiedStateCallback;
  ValueChanged<EditableViewport?>? _pendingStateDetachCallback;
  int _debugStateCallbackPublishCount = 0;
  _AutomaticCaretRevealIntent? _automaticCaretRevealIntent;
  bool _suppressNextAutomaticCaretReveal = false;
  bool _elementActive = true;
  bool _tearingDownPipeline = false;
  int _caretRevealEpoch = 0;
  _CaretRevealRequest? _activeCaretReveal;
  static const int _caretRevealMaxStartAttempts = 8;
  static const int _caretRevealMaxRefinements = 32;
  static const int _caretRevealMaxPendingGeometryStallFrames = 1024;
  static const double _caretRevealTolerance = 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _caretBlink = CaretBlinkDriver(onPhase: _handleCaretBlinkPhase);
    _initPipeline();
    if (widget.style.readOnly) _enterReadOnlyMode();
    if (widget.style.autofocus && !widget.style.readOnly) _scheduleAutofocus();
    _scheduleLineProjectionSelectionRepair();
    _scheduleStateAttached();
  }

  @override
  void reassemble() {
    super.reassemble();
    // 热重载（如 IDE 的 Ctrl+Alt+R）期间按键事件流中断，Alt 的 KeyUp 可能
    // 丢失导致 HardwareKeyboard 残留按下状态；作废全部修饰键信任，防止
    // 热重载后普通点击被误判为多光标操作。重新按下 Alt 后恢复。
    _multiClickSelectionAppliedOnDown = false;
  }

  @override
  void activate() {
    super.activate();
    _elementActive = true;
    if (_focusNode.hasFocus && !widget.style.readOnly) _claimSystemUndoManager();
    _restoreCaretBlinkFromFocus();
    _scheduleStateAttached();
    _scheduleCaretGeometryUpdate();
  }

  @override
  void deactivate() {
    _elementActive = false;
    _unbindInheritedPaint();
    _stopCaretBlink(regularCaretVisible: false);
    _cancelCaretMotion(resetAnchor: true);
    _cancelFloatingCursor(restoreRegularCaret: false);
    _releaseSystemUndoManager();
    _scheduleStateDetached(widget.onStateChanged);
    _cancelCaretReveal();
    _scheduleCaretGeometryUpdate();
    super.deactivate();
  }

  void _initPipeline({bool attachFocus = true}) {
    _lineProjection = EditableLineProjection(controller: _controller, hiddenAreas: widget.hiddenAreas);
    _lineProjectionDocRevision = _controller.docRevision;
    _pendingDocumentProjectionStructureChange = false;
    _lineProjectionMappingRevision = _lineProjection.mappingRevision;
    _lineProjection.addListener(_handleLineProjectionChanged);
    // initState 不允许读 InheritedWidget，先用无 context 配置，build 会立即修正。
    _scope = EditableRenderScope(
      controller: _controller,
      config: _buildConfig(useContext: false),
      lineProjection: _lineProjection,
      onInlineLayoutChanged: _handleInlineLayoutChanged,
    );
    _scope.addListener(_handleEditableRenderScopeChanged);
    _scope.pump(
      regularCaretVisible: !widget.style.readOnly,
      paintEditingState: !widget.style.readOnly,
      selectionVisible: !_selectionTextBlocked && (_focused || widget.style.retainSelectionOnBlur),
    );
    _selectionGeometryDocRevision = _controller.docRevision;
    _selectionGeometryPresentationRevision = _controller.presentationRevision;
    _opsInstance = null;
    _keyHandlerInstance = null;
    _imeInstance = null;
    _controllerConfigurationRevision = _controller.configurationRevision;
    _controllerSingleLine = _controller.singleLine;
    _visibleLineCount = _lineProjection.visibleLineCount;
    _controller.docChanges.addListener(_handleDocChanged);
    _controller.transactionChanges.addListener(_handleTransactionChanged);
    _controller.visualChanges.addListener(_handleVisualChanged);
    _controller.configurationChanges.addListener(_handleControllerConfigurationChanged);
    if (attachFocus) _attachFocusNode(_focusNode);
    _syncScrollListeners();
  }

  EditableImeClient _createImeClient() => EditableImeClient(
    controller: _controller,
    onAction: _handleImeAction,
    onNewline: _handleImeNewline,
    onConnectionClosed: _handleImeConnectionClosed,
    onPlatformFocusReceived: _requestKeyboard,
    onGeometryRequested: _scheduleFrameSync,
    onPrivateCommand: (action, data) => widget.style.onPrivateCommand?.call(action, data),
    onFloatingCursor: _handleImeFloatingCursor,
    onAutocorrectionPromptRect: (range) => widget.style.onAutocorrectionPromptRect?.call(range),
    onShowToolbar: () => widget.style.onShowToolbar?.call(),
    onTextPlaceholderChanged: (size) => widget.style.onTextPlaceholderChanged?.call(size),
    onSelector: _handleImeSelector,
    onUnhandledContent: (content) => widget.style.onUnhandledContent?.call(content),
    onInputControlChanged: (oldControl, newControl) => widget.style.onInputControlChanged?.call(oldControl, newControl),
    autofillScope: () => _currentAutofillScope,
  );

  EditableKeyHandler _createKeyHandler() => EditableKeyHandler(
    controller: _controller,
    ops: _ops,
    readOnly: () => widget.style.readOnly,
    undo: undo,
    redo: redo,
    allowClipboard: () => !widget.style.obscureText && !_selectionTextBlocked,
    allowTextSelection: () => !_selectionTextBlocked,
    obscureText: () => widget.style.obscureText,
  );

  EditableOps _createOps() {
    final boundController = _controller;
    final boundEpoch = _clipboardOperationEpoch;
    bool stillBound() => mounted && identical(_controller, boundController) && _clipboardOperationEpoch == boundEpoch;
    return EditableOps(
      controller: boundController,
      layout: _scope,
      lineProjection: _lineProjection,
      pageExtent: _pageExtent,
      wordBoundary: wordBoundary,
      canCommitCut: () => stillBound() && !widget.style.readOnly && !widget.style.obscureText,
      canCommitPaste: () => stillBound() && !widget.style.readOnly,
    );
  }

  void _syncScrollListeners() {
    final vertical = _scrollController;
    if (!identical(vertical, _listenedScrollController)) {
      _listenedScrollController?.removeListener(_handleScrolled);
      vertical.addListener(_handleScrolled);
      _listenedScrollController = vertical;
    }
    final horizontal = _horizontalControllerForCurrentMode;
    if (!identical(horizontal, _listenedHorizontalController)) {
      _listenedHorizontalController?.removeListener(_handleScrolled);
      horizontal?.addListener(_handleScrolled);
      _listenedHorizontalController = horizontal;
    }
  }

  void _detachScrollListeners() {
    _listenedScrollController?.removeListener(_handleScrolled);
    _listenedHorizontalController?.removeListener(_handleScrolled);
    _listenedScrollController = null;
    _listenedHorizontalController = null;
  }

  void _attachFocusNode(FocusNode focusNode) {
    KeyEventResult installed(FocusNode node, KeyEvent event) => _handleKeyEvent(node, event);
    _installedFocusNode = focusNode;
    _previousFocusKeyHandler = focusNode.onKeyEvent;
    _installedFocusKeyHandler = installed;
    focusNode
      ..onKeyEvent = installed
      ..addListener(_handleFocusChanged);
  }

  void _detachFocusNode(FocusNode focusNode) {
    focusNode.removeListener(_handleFocusChanged);
    if (identical(focusNode, _installedFocusNode)) {
      final installed = _installedFocusKeyHandler;
      final previous = _previousFocusKeyHandler;
      if (installed != null && identical(focusNode.onKeyEvent, installed)) {
        focusNode.onKeyEvent = previous;
      } else if (installed != null) {
        // ElView 的焦点宿主还会在本轮子树更新稍后拆掉自己的外层 wrapper；
        // 等它还原出本 wrapper 后再精确恢复调用方 handler，identity 不符说明
        // 调用方已运行期替换，必须保留新值。
        scheduleMicrotask(() {
          if (identical(focusNode.onKeyEvent, installed)) focusNode.onKeyEvent = previous;
        });
      }
    }
    if (identical(focusNode, _installedFocusNode)) {
      _installedFocusNode = null;
      _previousFocusKeyHandler = null;
      _installedFocusKeyHandler = null;
    }
  }

  void _rebindFocusNode(FocusNode previous, FocusNode next) {
    if (identical(previous, next)) return;
    final generation = ++_focusRebindGeneration;
    _pendingFocusRebindGeneration = generation;
    _detachFocusNode(previous);
    _attachFocusNode(next);
    // Focus widget 会在本 State 的 didUpdateWidget 之后才把新节点接进树；此处
    // 保留旧的逻辑 focused 状态，等本帧焦点迁移完成再判断是否真的出现失焦。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_elementActive || generation != _focusRebindGeneration) return;
      if (!identical(_focusNode, next)) return;
      // 新 Focus widget 在 build 中发出的 requestFocus 默认等下一微任务才生效；
      // post-frame 已离开树锁，可在判断真实失焦前确定性结清这批焦点请求。
      FocusManager.instance.applyFocusChangesIfNeeded();
      if (!mounted || generation != _focusRebindGeneration || !identical(_focusNode, next)) return;
      _pendingFocusRebindGeneration = null;
      _handleFocusChanged();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _releaseOwnedFocusNodeToExternal(FocusNode effectiveFocusNode) {
    if (widget.focusNode == null) return;
    final owned = _ownFocusNode;
    _ownFocusNode = null;
    if (owned != null && !identical(owned, effectiveFocusNode)) {
      // 子树本轮稍后才从旧节点解绑，不能在 didUpdateWidget 中同步 dispose。
      _disposeAfterFrame(owned);
    }
  }

  void _teardownPipeline({
    required EditableController controller,
    required FocusNode focusNode,
    bool detachFocus = true,
  }) {
    _focusRebindGeneration++;
    _pendingFocusRebindGeneration = null;
    final retiredScope = _scope;
    final retiredLineProjection = _lineProjection;
    _tearingDownPipeline = true;
    _stopCaretBlink(regularCaretVisible: false);
    _cancelLineProjectionAnchorRestore();
    _cancelLineProjectionSelectionRepair();
    try {
      _cancelFloatingCursor(restoreRegularCaret: false);
      controller.docChanges.removeListener(_handleDocChanged);
      controller.transactionChanges.removeListener(_handleTransactionChanged);
      controller.visualChanges.removeListener(_handleVisualChanged);
      controller.configurationChanges.removeListener(_handleControllerConfigurationChanged);
      _cancelScheduledImeConfigurationUpdate();
      if (detachFocus) _detachFocusNode(focusNode);
      _detachScrollListeners();
      _finishImeAndClose(fallbackController: controller);
      _opsInstance = null;
      _keyHandlerInstance = null;
      _imeInstance = null;
      _cancelCaretMotion(resetAnchor: true);
      retiredScope.removeListener(_handleEditableRenderScopeChanged);
      retiredLineProjection.removeListener(_handleLineProjectionChanged);
    } finally {
      _disposeRetiredPipelineAfterTreeUpdate(retiredScope, retiredLineProjection);
      // finishComposing 会同步发布 visualChanges；取消必须放在 teardown 最后，
      // 并配合 _tearingDownPipeline 拒绝外部 listener 重入创建新请求。
      _cancelCaretReveal();
      _tearingDownPipeline = false;
    }
  }

  static void _disposeRetiredPipelineAfterTreeUpdate(EditableRenderScope scope, EditableLineProjection lineProjection) {
    // didUpdateWidget / State.dispose 返回前，旧 RenderObject 仍可能因 GlobalKey
    // 重父化短暂 attach；跨过同步树更新相位后再释放精确捕获的旧代对象。
    scheduleMicrotask(() {
      scope.dispose();
      lineProjection.dispose();
    });
  }

  void _rebindLineProjection() {
    _clipboardOperationEpoch++;
    _cancelSelectionChromeInteractions();
    _cancelFloatingCursor();
    _cancelCaretReveal();
    _cancelLineProjectionAnchorRestore();
    _cancelLineProjectionSelectionRepair();
    final hadKeyHandler = _keyHandlerInstance != null;
    final hadOps = _opsInstance != null;

    final previous = _lineProjection;
    final previousAreas = previous.hiddenAreas?.hiddenAreas ?? const <EditableHiddenArea>[];
    previous.removeListener(_handleLineProjectionChanged);
    _lineProjection = EditableLineProjection(controller: _controller, hiddenAreas: widget.hiddenAreas)
      ..addListener(_handleLineProjectionChanged);
    final nextAreas = _lineProjection.hiddenAreas?.hiddenAreas ?? const <EditableHiddenArea>[];
    _lineProjectionMappingRevision = listEquals(previousAreas, nextAreas)
        ? _lineProjection.mappingRevision
        : _lineProjection.mappingRevision - 1;
    _scope.lineProjection = _lineProjection;
    _opsInstance = hadOps ? _createOps() : null;
    _keyHandlerInstance = hadKeyHandler ? _createKeyHandler() : null;
    previous.dispose();
    _updatingLineProjectionBinding = true;
    try {
      _handleLineProjectionChanged();
    } finally {
      _updatingLineProjectionBinding = false;
    }
    _refreshSelectionActions();
  }

  void _finishImeAndClose({bool commitUnconfirmedAsPlainText = false, EditableController? fallbackController}) {
    _cancelFloatingCursor(restoreRegularCaret: false);
    final ime = _imeInstance;
    if (ime == null) {
      final controller = fallbackController ?? _controller;
      if (controller.hasActiveImeComposition) {
        controller.finishImeComposition(commit: true, commitUnconfirmedAsPlainText: commitUnconfirmedAsPlainText);
      }
      _lastImeStyle = null;
      return;
    }
    try {
      ime.finishComposing(commit: true, commitUnconfirmedAsPlainText: commitUnconfirmedAsPlainText);
    } finally {
      // formatter 的编程异常可以继续上报，但失焦/平台断连绝不能留下 attached
      // connection；否则下一次点击会进入 focused-but-detached 的输入死状态。
      ime.close();
      _lastImeStyle = null;
    }
  }

  /// 热切只读时同步结束全部编辑会话，但保留 controller 中已有选区数据。
  void _enterReadOnlyMode() {
    _stopCaretBlink(regularCaretVisible: false);
    _cancelSelectionChromeInteractions();
    _cancelFloatingCursor(restoreRegularCaret: false);
    _cancelCaretMotion(resetAnchor: true);
    _cancelCaretReveal();
    _cancelScheduledImeConfigurationUpdate();
    _finishImeAndClose(commitUnconfirmedAsPlainText: true);
    _releaseSystemUndoManager();
    _scope.pump(focused: false, regularCaretVisible: false, primaryCaretMotionActive: false, paintEditingState: false);
    if (_focusNode.hasFocus) _focusNode.unfocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectionBlocked = SelectionTextBoundary.blocks(context);
    if (_selectionTextBlocked != selectionBlocked) {
      _selectionTextBlocked = selectionBlocked;
      if (selectionBlocked) _cancelSelectionChromeInteractions();
      _scheduleImeConfigurationUpdate();
    }
    final tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    final viewActive = _caretBlinkViewActive;
    final animationsEnabled = tickerModeEnabled && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (animationsEnabled != _caretAnimationsEnabled) {
      _caretAnimationsEnabled = animationsEnabled;
      if (!animationsEnabled) _cancelCaretMotion(resetAnchor: true);
    }
    if (tickerModeEnabled != _caretBlinkTickerModeEnabled) {
      _caretBlinkTickerModeEnabled = tickerModeEnabled;
      if (tickerModeEnabled) {
        _restartCaretBlink();
      } else {
        // TickerMode 关闭代表整棵视觉子树静默：停表但保留静态可见 caret。
        // MediaQuery.disableAnimations 只关闭位置过渡，不影响闪烁。
        _stopCaretBlink(regularCaretVisible: viewActive && !widget.style.readOnly && !_floatingCursorState.isActive);
      }
    }
    _syncViewFocusActive(viewActive);
    _cancelFloatingCursorIfLayoutSignatureChanged();
    final nextAutofillScope = AutofillGroup.maybeOf(context);
    final autofillScopeChanged = !identical(_currentAutofillScope, nextAutofillScope);
    if (autofillScopeChanged) {
      if (_autofillClientRegistered) {
        _currentAutofillScope?.unregister(_autofillClientInstance!.autofillId);
        _autofillClientRegistered = false;
      }
      _currentAutofillScope = nextAutofillScope;
    }
    _syncAutofillRegistration();
    final viewId = View.maybeOf(context)?.viewId;
    final viewChanged = _configuredViewId != viewId;
    _configuredViewId = viewId;
    if (_focused && !widget.style.readOnly && (viewChanged || autofillScopeChanged)) {
      final autofillEnabled = widget.style.autofillHints != null;
      final ime = _imeInstance;
      if (autofillScopeChanged && autofillEnabled && ime?.attached == true) {
        // 纯树重挂载只重建平台 fields；不得把活动候选误当用户完成输入提交。
        _cancelFloatingCursor();
        ime!.close();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focused && !widget.style.readOnly && _imeInstance?.attached != true) _openIme();
        });
        return;
      }
      _scheduleImeConfigurationUpdate();
    }
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    final view = View.maybeOf(context);
    if (view == null || view.viewId != event.viewId) return;
    if (event.state != ViewFocusState.focused) {
      _multiClickSelectionAppliedOnDown = false;
    }
    _syncViewFocusActive(event.state == ViewFocusState.focused);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Windows 桌面失焦走 flutter/lifecycle 通道；ViewFocus 事件在真实环境
    // 可能竞态丢失，必须双通道作废残留修饰键。
    if (state != AppLifecycleState.resumed) {
      _multiClickSelectionAppliedOnDown = false;
    }
  }

  void _syncViewFocusActive(bool active) {
    if (!active) {
      _multiClickSelectionAppliedOnDown = false;
    }
    if (active == _caretBlinkViewActive) return;
    _caretBlinkViewActive = active;
    if (active) {
      _restartCaretBlink();
    } else {
      _stopCaretBlink(regularCaretVisible: false);
    }
  }

  @override
  void didUpdateWidget(EditableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style.caretWidth != oldWidget.style.caretWidth ||
        widget.style.caretColor != oldWidget.style.caretColor ||
        widget.style.caretAnimationDuration != oldWidget.style.caretAnimationDuration) {
      _cancelCaretMotion(resetAnchor: true);
    }
    _cancelFloatingCursorIfLayoutSignatureChanged();
    if (oldWidget.onStateChanged != widget.onStateChanged) {
      _scheduleStateDetached(oldWidget.onStateChanged);
      _scheduleStateAttached();
    }
    final scrollControllerChanged =
        widget.scrollController != oldWidget.scrollController ||
        widget.horizontalScrollController != oldWidget.horizontalScrollController;
    if (scrollControllerChanged) {
      _cancelCaretMotion(resetAnchor: true);
      _cancelCaretReveal();
      _cancelLineProjectionAnchorRestore();
    }
    if (scrollControllerChanged && (_selectionHandleControllerInstance?.isHandleDragInProgress ?? false)) {
      final preserveMobileIntent = _selectionUsesMobileChrome;
      _cancelSelectionChromeInteractions(clearMobileIntent: false);
      _selectionUsesMobileChrome = preserveMobileIntent;
      _scheduleSelectionChromeGeometry();
    }
    if (scrollControllerChanged) {
      _scheduleCaretGeometryUpdate();
      // 新 host 可能带完全不同的 offset，attach 本身又不保证触发 listener；
      // 与其让旧 placeholder 停在旧行，不如终止这次极短的手势会话。
      _cancelFloatingCursor();
    }
    final mobileChromeConfigChanged =
        widget.style.selectionControls != oldWidget.style.selectionControls ||
        widget.style.enabledSelectionHandles != oldWidget.style.enabledSelectionHandles ||
        widget.style.enabledMagnifier != oldWidget.style.enabledMagnifier ||
        widget.style.enabledSelectionToolbar != oldWidget.style.enabledSelectionToolbar;
    if (mobileChromeConfigChanged) {
      final preserveMobileIntent = _selectionUsesMobileChrome;
      _cancelSelectionChromeInteractions(clearMobileIntent: false);
      _selectionUsesMobileChrome = preserveMobileIntent;
      _scheduleSelectionChromeGeometry();
    }
    if (!widget.style.enableInteractiveSelection && oldWidget.style.enableInteractiveSelection) {
      _cancelSelectionChromeInteractions();
    }
    if (!widget.style.enabledContextMenu && oldWidget.style.enabledContextMenu) {
      _selectionMenuEntry?.close();
      _selectionMenuEntry = null;
    }
    // 滚动控制器换实例：监听随迁——旧实例上的 _handleScrolled 不摘除会经闭包
    // 强引用整个 State（泄漏 + 幽灵回调），新实例缺监听则滚动不再驱动 IME
    // 几何 / caret 同步。必须先于 pipeline 重建处理：teardown 经 getter 只摸得到新实例。
    if (widget.scrollController != oldWidget.scrollController && widget.scrollController != null) {
      final retired = _ownScrollController;
      _ownScrollController = null;
      if (retired != null) _disposeAfterFrame(retired);
    }
    final horizontalPolicyChanged = widget.style.softWrap != oldWidget.style.softWrap;
    if ((widget.horizontalScrollController != oldWidget.horizontalScrollController &&
            widget.horizontalScrollController != null) ||
        (horizontalPolicyChanged && widget.style.softWrap && widget.horizontalScrollController == null)) {
      final retired = _ownHorizontalController;
      _ownHorizontalController = null;
      if (retired != null) _disposeAfterFrame(retired);
    }
    if (widget.scrollController != oldWidget.scrollController ||
        widget.horizontalScrollController != oldWidget.horizontalScrollController ||
        horizontalPolicyChanged) {
      _syncScrollListeners();
    }
    final controllerChanged =
        widget.controller != oldWidget.controller && !(widget.controller == null && oldWidget.controller == null);
    final focusBindingChanged =
        widget.focusNode != oldWidget.focusNode && !(widget.focusNode == null && oldWidget.focusNode == null);
    final previousFocusNode = oldWidget.focusNode ?? _ownFocusNode!;
    final nextFocusNode = widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'EditableView'));
    final hiddenAreasChanged = !identical(widget.hiddenAreas, oldWidget.hiddenAreas);
    if ((controllerChanged || hiddenAreasChanged) &&
        widget.hiddenAreas != null &&
        !identical(widget.hiddenAreas!.controller, _controller)) {
      throw FlutterError('EditableView 的 hiddenAreas 与 controller 必须绑定到同一个 EditableController 实例。');
    }
    final focusOnlyRebind = focusBindingChanged && !controllerChanged && !hiddenAreasChanged;
    if (focusOnlyRebind) {
      _rebindFocusNode(previousFocusNode, nextFocusNode);
      _releaseOwnedFocusNodeToExternal(nextFocusNode);
    }
    if (hiddenAreasChanged && !controllerChanged && !focusBindingChanged) {
      _rebindLineProjection();
    }
    if (controllerChanged || (focusBindingChanged && !focusOnlyRebind)) {
      final preserveFocusBinding = identical(previousFocusNode, nextFocusNode);
      _clipboardOperationEpoch++;
      _cancelSelectionChromeInteractions();
      _scheduleCaretGeometryUpdate();
      _releaseSystemUndoManager();
      _cancelFloatingCursor(restoreRegularCaret: false);
      _teardownPipeline(
        controller: oldWidget.controller ?? _ownController!,
        focusNode: previousFocusNode,
        detachFocus: !preserveFocusBinding,
      );
      // 外部实例接管后释放内部自建实例。
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _releaseOwnedFocusNodeToExternal(nextFocusNode);
      _focused = false;
      _lineIdentitiesByIndex.clear();
      _lineIdentitiesByKey.clear();
      _initPipeline(attachFocus: !preserveFocusBinding);
      _appliedRenderConfig = null;
      _refreshSelectionActions();
      _handleFocusChanged();
      _scheduleLineProjectionSelectionRepair();
      _scheduleCaretGeometryUpdate();
      _syncAutofillRegistration();
      return;
    }
    final readOnlyChanged = widget.style.readOnly != oldWidget.style.readOnly;
    final obscureTextChanged = widget.style.obscureText != oldWidget.style.obscureText;
    final autofillHintsChanged = !listEquals(
      widget.style.autofillHints?.toList(growable: false),
      oldWidget.style.autofillHints?.toList(growable: false),
    );
    if (readOnlyChanged || autofillHintsChanged) _syncAutofillRegistration();
    final clipboardPolicyChanged = readOnlyChanged || obscureTextChanged;
    final imeConfigurationChanged = obscureTextChanged || _editableImeConfigChanged(widget.style, oldWidget.style);

    if (clipboardPolicyChanged) {
      _clipboardOperationEpoch++;
    }
    if (clipboardPolicyChanged) {
      _selectionMenuEntry?.close();
      _selectionMenuEntry = null;
    }
    if ((clipboardPolicyChanged) && _opsInstance != null) {
      _opsInstance = _createOps();
    }

    if (readOnlyChanged) {
      if (widget.style.readOnly) {
        _enterReadOnlyMode();
      } else {
        _scope.pump(
          focused: _focusNode.hasFocus,
          regularCaretVisible: true,
          primaryCaretMotionActive: false,
          paintEditingState: true,
        );
        _handleFocusChanged();
        if (_focused && _focusNode.hasFocus) _restartCaretBlink();
        if (_focused) _openIme();
      }
    } else if (imeConfigurationChanged && _focused && !widget.style.readOnly) {
      // 密码显隐只改变绘制、剪贴板策略与平台配置；重连会错误提交活动候选，
      // 还会让同一次点击短暂丢失 caret/selection。
      _scheduleImeConfigurationUpdate();
    }
    if (clipboardPolicyChanged) {
      final hadKeyHandler = _keyHandlerInstance != null;
      _keyHandlerInstance = hadKeyHandler ? _createKeyHandler() : null;
    }
    if (widget.style.readOnly != oldWidget.style.readOnly) _updateSystemUndoState();
    _refreshSelectionActions();
  }

  /// 滚动视图在本轮 build 才 detach 旧 controller，立即 dispose 会踩到仍
  /// 挂着的 position——推迟到帧末释放。
  static void _disposeAfterFrame(ChangeNotifier notifier) {
    SchedulerBinding.instance.addPostFrameCallback((_) => notifier.dispose());
  }

  @override
  void dispose() {
    _unbindInheritedPaint();
    WidgetsBinding.instance.removeObserver(this);
    _clipboardOperationEpoch++;
    _cancelSelectionChromeInteractions();
    _releaseSystemUndoManager();
    if (_autofillClientRegistered) {
      _currentAutofillScope?.unregister(_autofillClientInstance!.autofillId);
      _autofillClientRegistered = false;
    }
    _currentAutofillScope = null;
    _scheduleStateDetached(widget.onStateChanged);
    _cancelFloatingCursor(restoreRegularCaret: false);
    _floatingCursorResetController?.dispose();
    _floatingCursorResetController = null;
    _teardownPipeline(controller: _controller, focusNode: _focusNode);
    _caretBlink.dispose();
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    _ownScrollController?.dispose();
    _ownHorizontalController?.dispose();
    _selectionEndpoints.dispose();
    _selectionDragInfo.dispose();
    _selectionScrollActivity.dispose();
    _selectionChromeVisibility.dispose();
    _selectionToolbarActionsInstance?.dispose();
    _caretMotionController?.dispose();
    _caretMotionController = null;
    _caretMotionRect.dispose();
    _floatingCursorFrame.dispose();
    _scheduleCaretGeometryDispose();
    super.dispose();
  }

  // ===========================================================================
  // 配置
  // ===========================================================================

  // 与 ElView 的 CSS half-leading 初值保持一致：行高多余空间均分到
  // 字形上下；调用方显式声明 proportional 时仍会在 merge 中覆盖。
  static const TextStyle _initialTextStyle = TextStyle(leadingDistribution: .even);
  static const Color _defaultCaretColor = Color(0xff000000);
  static const Color _defaultSelectionColor = Color(0x553B82F6);

  ElRenderView? _paintStyleSource;
  final _inheritedPaintBindings = <({ElRenderView source, CascadeBridgeChanges changes, OnSelectionPaintMemo memo})>[];

  void _unbindInheritedPaint() {
    for (final binding in _inheritedPaintBindings) {
      binding.changes.removeListener(_updateInheritedPaint);
    }
    _inheritedPaintBindings.clear();
    _paintStyleSource = null;
  }

  /// 文字与选区直接送入渲染；选区伪类不进入普通级联，单独保留祖先来源。
  void _bindInheritedPaint() {
    final source = context.findAncestorRenderObjectOfType<ElRenderView>();
    final sources = <ElRenderView>[];
    for (RenderObject? node = source; node != null; node = node.parent) {
      if (node is ElRenderView) sources.add(node);
    }
    if (sources.length == _inheritedPaintBindings.length &&
        Iterable<int>.generate(sources.length).every((i) => identical(sources[i], _inheritedPaintBindings[i].source))) {
      return;
    }
    _unbindInheritedPaint();
    _paintStyleSource = source;
    for (final ancestor in sources) {
      final changes = ancestor.ensureCascadeBridgeChanges();
      changes.addListener(_updateInheritedPaint);
      _inheritedPaintBindings.add((source: ancestor, changes: changes, memo: OnSelectionPaintMemo()));
    }
  }

  void _updateInheritedPaint() {
    if (!mounted || !_elementActive) return;
    final config = _buildConfig();
    if (_appliedRenderConfig == config) return;
    _appliedRenderConfig = config;
    _scope.pump(config: config);
  }

  EditableRenderConfig _buildConfig({bool useContext = true}) {
    final inheritedColor = useContext ? _paintStyleSource?.currentColorForBuild : null;
    Color? inheritedSelectionColor;
    Color? inheritedSelectionTextColor;
    if (useContext) {
      for (final binding in _inheritedPaintBindings) {
        final paint = binding.memo.resolve(binding.source.style, stateBits: binding.source.internalStateBits);
        inheritedSelectionColor ??= paint.bgColor;
        inheritedSelectionTextColor ??= paint.color;
        if (inheritedSelectionColor != null && inheritedSelectionTextColor != null) break;
      }
    }
    final inherited = useContext ? _paintStyleSource?.committedResolvedStyle : null;
    var style = _initialTextStyle
        .merge(inherited == null ? null : editableInheritedTextStyle(inherited, inheritedColor))
        .merge(widget.style.textStyle);
    // inherit:false 约束 TextStyle 合并；未声明前景时仍遵守 ElView 的颜色级联。
    if (style.color == null && style.foreground == null && inheritedColor != null) {
      style = style.copyWith(color: inheritedColor);
    }
    final textColor = style.color ?? style.foreground?.color;
    return EditableRenderConfig(
      textStyle: style,
      textDirection:
          inherited?.inheritedBox.direction ??
          (useContext ? (Directionality.maybeOf(context) ?? TextDirection.ltr) : TextDirection.ltr),
      textAlign: widget.inheritTextAlign
          ? inherited?.inheritedText.textAlign ?? widget.style.textAlign
          : widget.style.textAlign,
      textScaler: useContext ? (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling) : TextScaler.noScaling,
      softWrap: widget.style.softWrap,
      caretColor: widget.style.caretColor ?? textColor ?? _defaultCaretColor,
      caretWidth: widget.style.caretWidth,
      selectionColor: widget.style.selectionColor ?? inheritedSelectionColor ?? _defaultSelectionColor,
      selectionTextColor: widget.style.selectionTextColor ?? inheritedSelectionTextColor,
      composingUnderline: widget.style.composingUnderline,
      tabSize: widget.tabSize,
      obscureText: widget.style.obscureText,
      obscuringCharacter: widget.style.obscuringCharacter,
      composer: widget.style.composer,
      lineHeightMode: widget.style.lineHeightMode,
      wordSeparators: EditableWordNavigator.defaultWordSeparators,
    );
  }

  TextInputConfiguration _imeConfiguration() {
    final singleLine = _controller.singleLine;
    final allowedMimeTypes = _resolvedAllowedMimeTypes();
    return TextInputConfiguration(
      // 多视图架构下引擎强校验目标视图：缺 viewId 时桌面端 setClient 直接抛
      // "view ID is null."（对齐官方 EditableText 口径）
      viewId: View.maybeOf(context)?.viewId,
      inputType: widget.style.keyboardType ?? (singleLine ? TextInputType.text : TextInputType.multiline),
      inputAction: widget.style.textInputAction ?? (singleLine ? TextInputAction.done : TextInputAction.newline),
      actionLabel: widget.style.actionLabel,
      keyboardAppearance: widget.style.keyboardAppearance,
      textCapitalization: widget.style.textCapitalization,
      smartDashesType: widget.style.obscureText ? SmartDashesType.disabled : widget.style.smartDashesType,
      smartQuotesType: widget.style.obscureText ? SmartQuotesType.disabled : widget.style.smartQuotesType,
      obscureText: widget.style.obscureText,
      autocorrect: widget.style.autocorrect && !widget.style.obscureText,
      enableSuggestions: widget.style.enableSuggestions && !widget.style.obscureText,
      enableInteractiveSelection: _interactiveSelectionEnabled,
      enableIMEPersonalizedLearning: widget.style.enableIMEPersonalizedLearning && !widget.style.obscureText,
      allowedMimeTypes: allowedMimeTypes,
      autofillConfiguration: _autofillConfiguration(),
      hintLocales: widget.style.hintLocales,
      enableInlinePrediction: widget.style.obscureText ? false : widget.style.enableInlinePrediction,
      // Flutter Web 的 delta 推导依赖 beforeinput；部分浏览器自动化、语音或
      // 辅助输入只触发 input/change，会把已变化正文误报成 selection-only
      // delta，甚至在框架解码前生成越界选区。Web 使用同一有界 IME 窗口的
      // 整值通道，原生平台继续保留精确 delta。
      enableDeltaModel: !kIsWeb,
      readOnly: widget.style.readOnly,
    );
  }

  void _handleControllerConfigurationChanged() {
    final revision = _controller.configurationRevision;
    if (revision == _controllerConfigurationRevision) return;
    final singleLineChanged = _controllerSingleLine != _controller.singleLine;
    _controllerConfigurationRevision = revision;
    _controllerSingleLine = _controller.singleLine;
    if (singleLineChanged && _focused && !widget.style.readOnly) {
      _scheduleImeConfigurationUpdate();
    }
    _refreshSelectionActions();
  }

  /// 同一帧的 controller 与 widget 配置变化只向现有平台连接更新一次。
  void _scheduleImeConfigurationUpdate() {
    if (_imeConfigurationUpdateScheduled) return;
    _imeConfigurationUpdateScheduled = true;
    final generation = ++_imeConfigurationUpdateGeneration;
    SchedulerBinding.instance.ensureVisualUpdate();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (generation != _imeConfigurationUpdateGeneration) return;
      _imeConfigurationUpdateScheduled = false;
      final ime = _imeInstance;
      if (!mounted || !_focused || widget.style.readOnly || ime?.attached != true) return;
      ime!.updateConfiguration(_imeConfiguration());
      _scheduleFrameSync();
    });
  }

  void _cancelScheduledImeConfigurationUpdate() {
    _imeConfigurationUpdateGeneration++;
    _imeConfigurationUpdateScheduled = false;
  }

  void _syncAutofillRegistration() {
    final scope = _currentAutofillScope;
    final shouldRegister = scope != null && widget.style.autofillHints != null && !widget.style.readOnly;
    if (shouldRegister == _autofillClientRegistered) return;
    if (_autofillClientRegistered) {
      scope?.unregister(_autofillClientInstance!.autofillId);
      _autofillClientRegistered = false;
    }
    if (shouldRegister) {
      scope.register(_autofillClient);
      _autofillClientRegistered = true;
    }
  }

  AutofillConfiguration _autofillConfiguration() {
    final hints = widget.style.autofillHints?.toList(growable: false);
    if (hints == null || widget.style.readOnly) return AutofillConfiguration.disabled;
    return AutofillConfiguration(
      uniqueIdentifier: _autofillClient.autofillId,
      autofillHints: hints,
      currentEditingValue: TextEditingValue(
        text: _controller.text,
        selection: _controller.selection,
        composing: _controller.composing,
      ),
      hintText: widget.style.autofillHintText,
    );
  }

  void _handleAutofill(TextEditingValue value) {
    if (widget.style.readOnly) return;
    _ime.applyAutofill(value, () => _controller.applyAutofillValue(value));
  }

  List<String> _resolvedAllowedMimeTypes() {
    if (widget.style.onUnhandledContent != null) return widget.style.allowedMimeTypes;
    final plainTextOnly = <String>[
      for (final mimeType in widget.style.allowedMimeTypes)
        if (mimeType.split(';').first.trim().toLowerCase() == 'text/plain') mimeType,
    ];
    assert(
      plainTextOnly.length == widget.style.allowedMimeTypes.length,
      'allowedMimeTypes 包含非 text/plain 时必须提供 onUnhandledContent。',
    );
    return plainTextOnly;
  }

  RenderBox? get _editorBox {
    if (!_elementActive) return null;
    final render = context.findRenderObject();
    return render is RenderBox && render.hasSize ? render : null;
  }

  double _pageExtent() => _editorBox?.size.height ?? 400.0;

  void _handleViewportWidthChanged(double width) {
    final before = _scope.viewportWidth;
    _scope.seedInitialViewportWidth(width);
    if (_scope.viewportWidth != before) {
      _scheduleCaretGeometryUpdate();
      _scheduleFloatingCursorReproject();
    }
  }

  void _syncTextViewportWidth() {
    final before = _scope.viewportWidth;
    final beforeWindowRevision = _scope.longLineWindowRevision;
    double? width;
    var horizontalPixels = 0.0;
    if (!widget.style.softWrap &&
        _horizontalController.hasClients &&
        _horizontalController.position.hasViewportDimension) {
      final position = _horizontalController.position;
      horizontalPixels = position.pixels;
      final candidate = position.viewportDimension - widget.style.contentPadding.horizontal;
      if (candidate.isFinite) width = math.max(0.0, candidate);
    } else {
      for (final line in _scope.mountedLines.values) {
        if (!line.attached || !line.hasSize) continue;
        final viewport = RenderAbstractViewport.maybeOf(line);
        if (viewport is! RenderBox) continue;
        final viewportBox = viewport as RenderBox;
        if (!viewportBox.attached || !viewportBox.hasSize) continue;
        final viewportWidth = viewport is ScrollViewport
            ? (viewport as ScrollViewport).contentViewportRect.width
            : viewportBox.size.width;
        final candidate = viewportWidth - widget.style.contentPadding.horizontal;
        if (candidate.isFinite) {
          width = math.max(0.0, candidate);
          break;
        }
      }
    }
    final editor = _editorBox;
    width ??= editor == null ? 0.0 : math.max(0.0, editor.size.width - widget.style.contentPadding.horizontal);
    _scope.setHorizontalViewport(pixels: horizontalPixels, width: width);
    if (_scope.viewportWidth != before || _scope.longLineWindowRevision != beforeWindowRevision) {
      _scheduleCaretGeometryUpdate();
      _scheduleFloatingCursorReproject();
    }
  }

  // ===========================================================================
  // controller / 焦点 / 滚动监听
  // ===========================================================================

  void _handleLineProjectionChanged() {
    if (_tearingDownPipeline) return;
    final documentChanged = _lineProjectionDocRevision != _controller.docRevision;
    final mappingChanged = _lineProjectionMappingRevision != _lineProjection.mappingRevision;
    _lineProjectionDocRevision = _controller.docRevision;
    _lineProjectionMappingRevision = _lineProjection.mappingRevision;
    if (documentChanged || mappingChanged) _cancelLineProjectionAnchorRestore();
    // 隐藏投影会让旧 mounted 行与 editor 本地坐标立即失效；动画层不能等到
    // 下一帧几何同步才撤销，否则折叠瞬间会多画一帧指向已隐藏正文的 caret。
    if (mappingChanged) _cancelCaretMotion(resetAnchor: true);
    _scheduleLineProjectionSelectionRepair();
    if (documentChanged) {
      if (mappingChanged) _pendingDocumentProjectionStructureChange = true;
      return;
    }
    if (!mappingChanged) return;
    final scrollAnchor = _captureLineProjectionScrollAnchor();
    _debugLineProjectionStructureResetCount++;
    _cancelCaretReveal();
    _cancelFloatingCursor();
    if (_dragSelecting || (_selectionHandleControllerInstance?.isHandleDragInProgress ?? false)) {
      final preserveMobileIntent = _selectionUsesMobileChrome;
      _cancelSelectionChromeInteractions(clearMobileIntent: false);
      _selectionUsesMobileChrome = preserveMobileIntent;
    }
    _endpointDirectionCache.clear();
    _invalidateHiddenLineWidths();
    if (mounted && !_updatingLineProjectionBinding) {
      setState(() => _visibleLineCount = _lineProjection.visibleLineCount);
    } else {
      _visibleLineCount = _lineProjection.visibleLineCount;
    }
    if (scrollAnchor != null) _restoreLineProjectionScrollAnchor(scrollAnchor);
    _scheduleSelectionChromeGeometry();
    _scheduleCaretGeometryUpdate();
  }

  void _invalidateHiddenLineWidths() {
    _scope.invalidateLineWidths(<Object>[
      for (final identity in _lineIdentitiesByIndex.values)
        if (!_lineProjection.isVisibleModelLine(identity.index)) identity.key,
    ]);
  }

  void _scheduleLineProjectionSelectionRepair() {
    if (_tearingDownPipeline) return;
    if (_lineProjection.hiddenAreas?.isEmpty != false) {
      _cancelLineProjectionSelectionRepair();
      return;
    }
    final projection = _lineProjection;
    final controller = _controller;
    _pendingLineProjectionRepair = _LineProjectionRepairRequest(
      epoch: ++_lineProjectionRepairEpoch,
      projection: projection,
      projectionRevision: projection.mappingRevision,
      controller: controller,
      documentVersion: controller.documentVersion,
      selections: controller.selections,
    );
    if (_lineProjectionRepairScheduled) return;
    _lineProjectionRepairScheduled = true;
    final taskGeneration = _lineProjectionRepairTaskGeneration;
    scheduleMicrotask(() => _flushLineProjectionSelectionRepair(taskGeneration));
  }

  void _cancelLineProjectionSelectionRepair() {
    _lineProjectionRepairEpoch++;
    _lineProjectionRepairTaskGeneration++;
    _lineProjectionRepairScheduled = false;
    _pendingLineProjectionRepair = null;
  }

  void _flushLineProjectionSelectionRepair(int taskGeneration) {
    if (taskGeneration != _lineProjectionRepairTaskGeneration) return;
    _lineProjectionRepairScheduled = false;
    final request = _pendingLineProjectionRepair;
    _pendingLineProjectionRepair = null;
    if (request == null || !_lineProjectionRepairIsCurrent(request)) return;

    final controller = request.controller;
    final projection = request.projection;
    final composing = controller.composing;
    if (controller.hasActiveImeComposition &&
        composing.isValid &&
        !composing.isCollapsed &&
        projection.rangeIntersectsHiddenContent(composing)) {
      final ime = _imeInstance;
      final finished = ime?.finishComposing(commit: true) ?? controller.finishImeComposition(commit: true);
      if (finished) {
        _scheduleLineProjectionSelectionRepair();
        return;
      }
    }

    final current = controller.selections;
    if (current != request.selections) {
      _scheduleLineProjectionSelectionRepair();
      return;
    }
    EditableSelection project(EditableSelection selection) {
      if (!selection.isCollapsed) return selection;
      final position = projection.projectCollapsedPosition(
        TextPosition(offset: selection.active, affinity: selection.affinity),
        bias: EditablePositionProjectionBias.backward,
      );
      if (position.offset == selection.active && position.affinity == selection.affinity) return selection;
      return selection.copyWith(
        anchor: position.offset,
        active: position.offset,
        affinity: position.affinity,
        clearPreferredX: true,
      );
    }

    final primary = project(current.primary);
    final secondary = <EditableSelection>[for (final selection in current.secondary) project(selection)];
    final repaired = EditableSelectionSet(primary: primary, secondary: secondary);
    if (repaired == current || !_lineProjectionRepairIsCurrent(request)) return;
    controller.setSelections(repaired);
  }

  bool _lineProjectionRepairIsCurrent(_LineProjectionRepairRequest request) =>
      mounted &&
      _elementActive &&
      !_tearingDownPipeline &&
      request.epoch == _lineProjectionRepairEpoch &&
      identical(request.projection, _lineProjection) &&
      request.projection.mappingRevision == request.projectionRevision &&
      identical(request.controller, _controller) &&
      request.controller.documentVersion == request.documentVersion;

  ({int modelLine, double top})? _captureLineProjectionScrollAnchor() {
    final editor = _editorBox;
    if (editor == null || !_scrollController.hasClients) return null;
    final candidates = <({int modelLine, double top, double bottom})>[];
    for (final entry in _scope.mountedLines.entries) {
      final line = entry.value;
      if (!_lineProjection.isVisibleModelLine(entry.key) || !line.attached || !line.hasSize) continue;
      try {
        final top = line.localToGlobal(Offset.zero, ancestor: editor).dy;
        candidates.add((modelLine: entry.key, top: top, bottom: top + line.size.height));
      } catch (_) {
        // 投影换代与虚拟行卸载同帧交错时跳过正在脱离 render tree 的行。
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) => left.top.compareTo(right.top));
    const viewportTop = 0.0;
    final viewportBottom = editor.size.height;
    final visible = candidates.where((candidate) => candidate.bottom > viewportTop && candidate.top < viewportBottom);
    final anchor = visible.isEmpty ? candidates.first : visible.first;
    return (modelLine: anchor.modelLine, top: anchor.top);
  }

  void _cancelLineProjectionAnchorRestore() {
    _lineProjectionAnchorEpoch++;
    final controller = _lineProjectionAnchorScrollController;
    _lineProjectionAnchorScrollController = null;
    if (controller == null) return;
    _rowJump.cancel();
  }

  void _restoreLineProjectionScrollAnchor(({int modelLine, double top}) anchor) {
    _cancelLineProjectionAnchorRestore();
    final projection = _lineProjection;
    final projectionRevision = projection.mappingRevision;
    final controller = _controller;
    final documentVersion = controller.documentVersion;
    final scrollController = _scrollController;
    _lineProjectionAnchorScrollController = scrollController;
    final epoch = _lineProjectionAnchorEpoch;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_lineProjectionAnchorIsCurrent(
        epoch: epoch,
        projection: projection,
        projectionRevision: projectionRevision,
        controller: controller,
        documentVersion: documentVersion,
        scrollController: scrollController,
      )) {
        _completeLineProjectionAnchorRestore(scrollController, epoch);
        return;
      }
      final viewRow = projection.viewRowForModelLine(anchor.modelLine);
      if (viewRow == null || !scrollController.hasClients) {
        _completeLineProjectionAnchorRestore(scrollController, epoch);
        return;
      }
      late final Future<bool> positioning;
      try {
        positioning = _rowJump.jumpToIndex(viewRow, alignment: 0);
      } catch (_) {
        _completeLineProjectionAnchorRestore(scrollController, epoch);
        return;
      }
      unawaited(
        positioning.then<void>(
          (completed) {
            if (!completed ||
                !_lineProjectionAnchorIsCurrent(
                  epoch: epoch,
                  projection: projection,
                  projectionRevision: projectionRevision,
                  controller: controller,
                  documentVersion: documentVersion,
                  scrollController: scrollController,
                )) {
              _completeLineProjectionAnchorRestore(scrollController, epoch);
              return;
            }
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (!_lineProjectionAnchorIsCurrent(
                epoch: epoch,
                projection: projection,
                projectionRevision: projectionRevision,
                controller: controller,
                documentVersion: documentVersion,
                scrollController: scrollController,
              )) {
                _completeLineProjectionAnchorRestore(scrollController, epoch);
                return;
              }
              final editor = _editorBox;
              final render = _scope.mountedLineAt(anchor.modelLine);
              if (editor == null || render == null || !render.attached || !render.hasSize) {
                _completeLineProjectionAnchorRestore(scrollController, epoch);
                return;
              }
              try {
                final currentTop = render.localToGlobal(Offset.zero, ancestor: editor).dy;
                _scrollPositionByDelta(scrollController.position, currentTop - anchor.top);
              } catch (_) {
                // 目标在 refinement 前再次卸载时，本次锚定自然作废。
              } finally {
                _completeLineProjectionAnchorRestore(scrollController, epoch);
              }
            });
            SchedulerBinding.instance.ensureVisualUpdate();
          },
          onError: (Object _, StackTrace _) {
            _completeLineProjectionAnchorRestore(scrollController, epoch);
          },
        ),
      );
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _completeLineProjectionAnchorRestore(ScrollController controller, int epoch) {
    if (epoch == _lineProjectionAnchorEpoch && identical(_lineProjectionAnchorScrollController, controller)) {
      _lineProjectionAnchorScrollController = null;
    }
  }

  bool _lineProjectionAnchorIsCurrent({
    required int epoch,
    required EditableLineProjection projection,
    required int projectionRevision,
    required EditableController controller,
    required DocumentVersion documentVersion,
    required ScrollController scrollController,
  }) =>
      mounted &&
      _elementActive &&
      !_tearingDownPipeline &&
      epoch == _lineProjectionAnchorEpoch &&
      identical(projection, _lineProjection) &&
      projection.mappingRevision == projectionRevision &&
      identical(controller, _controller) &&
      controller.documentVersion == documentVersion &&
      identical(scrollController, _scrollController) &&
      identical(scrollController, _lineProjectionAnchorScrollController);

  void _handleDocChanged() {
    _cancelFloatingCursor();
    final activeReveal = _activeCaretReveal;
    if (activeReveal != null && !_caretRevealTargetMatchesCurrent(activeReveal)) {
      _cancelCaretReveal();
    } else {
      final automatic = _automaticCaretRevealIntent;
      if (automatic != null && !_automaticCaretRevealMatchesCurrent(automatic)) {
        _automaticCaretRevealIntent = null;
      }
    }
    _endpointDirectionCache.clear();
    if (_dragSelecting ||
        _longPressPointer != null ||
        (_selectionHandleControllerInstance?.isHandleDragInProgress ?? false)) {
      final preserveMobileIntent = _selectionUsesMobileChrome;
      _cancelSelectionChromeInteractions(clearMobileIntent: false);
      _selectionUsesMobileChrome = preserveMobileIntent;
    }
    final changeSet = _controller.lastChangeSet;
    if (changeSet != null && changeSet.documentChanged) {
      _remapLineIdentities(changeSet);
      _notifyRowShifts(changeSet);
      _suppressNextAutomaticCaretReveal = changeSet.source == EditableEditSource.api;
    }
    if (_pendingDocumentProjectionStructureChange) {
      _pendingDocumentProjectionStructureChange = false;
      _debugLineProjectionStructureResetCount++;
      _invalidateHiddenLineWidths();
    }
    final visibleLineCount = _lineProjection.visibleLineCount;
    if (mounted) setState(() => _visibleLineCount = visibleLineCount);
    _scheduleCaretGeometryUpdate();
  }

  // 视口上方增删行时保住正在看的正文：把行号变化告诉回收列表，由它平移可见首行锚点。
  // 折叠投影下视图行与模型行不一一对应，交给投影自己的锚点恢复。
  void _notifyRowShifts(DocumentChangeSet changeSet) {
    if (!(_lineProjection.hiddenAreas?.isEmpty ?? true)) return;
    // 编辑按原文坐标给出，从后往前通知，前面的行号不受后面编辑影响。
    for (final edit in changeSet.edits.reversed) {
      final after = edit.firstDirtyLine + 1;
      _rowJump.notifyItemsRemoved(after, edit.removedLineCount - 1);
      _rowJump.notifyItemsInserted(after, edit.insertedLineCount - 1);
    }
  }

  Set<int> _remapLineIdentities(DocumentChangeSet changeSet) {
    if (_lineIdentitiesByIndex.isEmpty) return <int>{};
    final originalOffsetsByIndex = <int, int>{
      for (final entry in _lineIdentitiesByIndex.entries) entry.key: entry.value.offset,
    };
    final originalOffsetsByKey = <Object, int>{
      for (final identity in _lineIdentitiesByIndex.values) identity.key: identity.offset,
    };
    final invalidated = <Object>{};
    for (final identity in _lineIdentitiesByIndex.values) {
      for (final edit in changeSet.edits) {
        final removedEnd = edit.start + edit.removed.length;
        final firstDirtyLine = identity.index == edit.firstDirtyLine;
        final startsInsideRemovedText = identity.offset > edit.start && identity.offset < removedEnd;
        if (firstDirtyLine || startsInsideRemovedText) {
          invalidated.add(identity.key);
          break;
        }
      }
    }
    _scope.invalidateLineWidths(invalidated);

    final candidates = <({int index, bool deleted, _EditableLineIdentity identity})>[];
    final document = _controller.document;
    for (final identity in _lineIdentitiesByIndex.values) {
      final transformed = _transformLineIdentityOffset(changeSet, identity.offset);
      final index = document.lineIndexOf(transformed.offset);
      candidates.add((index: index, deleted: transformed.deleted, identity: identity));
    }
    // 删除窗中的身份只作为幸存者缺失时的 fallback；同一结果行若还有从删除窗
    // 后方平移来的真实身份，优先保留真实幸存者。
    candidates.sort((left, right) {
      final byIndex = left.index.compareTo(right.index);
      if (byIndex != 0) return byIndex;
      if (left.deleted != right.deleted) return left.deleted ? 1 : -1;
      return right.identity.lastUsed.compareTo(left.identity.lastUsed);
    });
    final remapped = <int, _EditableLineIdentity>{};
    final discarded = <Object>{};
    final collisionSurvivors = <Object>{};
    for (final candidate in candidates) {
      final survivor = remapped[candidate.index];
      if (survivor != null) {
        // 合并/跨行替换可让 removedEnd 边界后的未删除身份赢得碰撞；它的
        // offset 虽然幸存，正文已变，必须连同被丢弃身份一起清空宽度/Bidi 缓存。
        // 唯一例外是从某行原始起点完整删到 survivor 起点且不插入正文：这只
        // 让 survivor 平移，正文与已测宽度都没有变化。
        final survivorOriginalOffset = originalOffsetsByKey[survivor.key];
        final preservesSurvivor =
            candidate.deleted &&
            survivorOriginalOffset != null &&
            changeSet.edits.any((edit) {
              final dirtyLineStart = originalOffsetsByIndex[edit.firstDirtyLine];
              return edit.inserted.isEmpty &&
                  dirtyLineStart == edit.start &&
                  edit.start + edit.removed.length == survivorOriginalOffset;
            });
        if (!preservesSurvivor) collisionSurvivors.add(survivor.key);
        discarded.add(candidate.identity.key);
        _lineIdentitiesByKey.remove(candidate.identity.key);
        continue;
      }
      final identity = candidate.identity
        ..index = candidate.index
        ..offset = document.lineStart(candidate.index);
      remapped[candidate.index] = identity;
    }
    if (discarded.isNotEmpty || collisionSurvivors.isNotEmpty) {
      _scope.invalidateLineWidths(<Object>{...discarded, ...collisionSurvivors});
      invalidated.addAll(collisionSurvivors);
    }
    _lineIdentitiesByIndex
      ..clear()
      ..addAll(remapped);
    _pruneLineIdentities();
    return <int>{
      for (final identity in _lineIdentitiesByKey.values)
        if (invalidated.contains(identity.key)) identity.index,
    };
  }

  ({int offset, bool deleted}) _transformLineIdentityOffset(DocumentChangeSet changeSet, int oldOffset) {
    var delta = 0;
    for (var i = 0; i < changeSet.edits.length; i++) {
      final edit = changeSet.edits[i];
      final oldEnd = edit.start + edit.removed.length;
      if (oldOffset < edit.start) break;
      if (oldOffset >= oldEnd) {
        delta += edit.inserted.length - edit.removed.length;
        continue;
      }
      return (offset: changeSet.resultStartFor(i) + edit.inserted.length, deleted: edit.removed.isNotEmpty);
    }
    return (offset: oldOffset + delta, deleted: false);
  }

  _EditableLineKey _lineKeyFor(int index) {
    final existing = _lineIdentitiesByIndex[index];
    if (existing != null) {
      existing.lastUsed = ++_lineIdentityUseTick;
      return existing.key;
    }
    final key = _EditableLineKey(owner: _lineIdentityOwner);
    final identity = _EditableLineIdentity(
      key: key,
      index: index,
      offset: _controller.document.lineStart(index),
      lastUsed: ++_lineIdentityUseTick,
    );
    _lineIdentitiesByIndex[index] = identity;
    _lineIdentitiesByKey[key] = identity;
    _pruneLineIdentities();
    return key;
  }

  void _pruneLineIdentities() {
    while (_lineIdentitiesByIndex.length > _retainedLineIdentityCapacity) {
      _EditableLineIdentity? oldest;
      for (final identity in _lineIdentitiesByIndex.values) {
        if (_scope.retainsLineWidth(identity.key) || _scope.mountedLineAt(identity.index) != null) continue;
        if (oldest == null || identity.lastUsed < oldest.lastUsed) oldest = identity;
      }
      if (oldest == null) return;
      _lineIdentitiesByIndex.remove(oldest.index);
      _lineIdentitiesByKey.remove(oldest.key);
    }
  }

  void _handleVisualChanged() {
    // 文本、选区与纯呈现变化都从完整可见周期重新开始；位置动画随后只
    // 接管绘制坐标，不拥有另一套闪烁相位。
    _restartCaretBlink();
    _scheduleLineProjectionSelectionRepair();
    final activeReveal = _activeCaretReveal;
    if (activeReveal != null && !_caretRevealTargetMatchesCurrent(activeReveal)) {
      _cancelCaretReveal();
    }
    if (_dragSelecting && _selectionGestureWriteDepth == 0) {
      final preserveMobileIntent = _selectionUsesMobileChrome;
      _cancelSelectionChromeInteractions(clearMobileIntent: false);
      _selectionUsesMobileChrome = preserveMobileIntent;
    }
    final presentationChanged = _selectionGeometryPresentationRevision != _controller.presentationRevision;
    final layoutChanged = _selectionGeometryDocRevision != _controller.docRevision || presentationChanged;
    if (presentationChanged) {
      // 同一 composer identity 也能在 invalidatePresentation 后换字号/行高；
      // 旧 floating prototype 无法靠 config identity 发现，必须结束本次会话。
      _cancelFloatingCursor();
    }
    _selectionGeometryDocRevision = _controller.docRevision;
    _selectionGeometryPresentationRevision = _controller.presentationRevision;
    if (widget.style.readOnly) {
      _cancelCaretMotion(resetAnchor: true);
    } else {
      _requestCaretMotionFromVisualChange(geometryReady: !layoutChanged, documentChanged: layoutChanged);
    }
    _scope.pumpFromController();
    _scope.pump(
      paintEditingState: !widget.style.readOnly,
      keepCaretAtPreSelectAllPosition: !widget.style.selectAllRevealsCaret && !widget.style.readOnly,
    );
    if (!widget.style.readOnly) _imeInstance?.syncFromController();
    // 全文选区（Ctrl+A / Cmd+A）且 style 关闭全选 reveal：抑制本次自动
    // reveal，视口与光标停留在原地（once 语义，随后续变化自然失效）。
    if (!widget.style.selectAllRevealsCaret && !widget.style.readOnly) {
      final primary = _controller.selections.primary;
      if (!primary.isCollapsed && primary.anchor == 0 && primary.active >= _controller.document.length) {
        _suppressNextAutomaticCaretReveal = true;
      }
    }
    final ensureVisible =
        !widget.style.readOnly && !_suppressNextAutomaticCaretReveal && !_floatingCursorState.isActive;
    _suppressNextAutomaticCaretReveal = false;
    _scheduleFrameSync(ensureVisible: ensureVisible);
    if (!widget.style.readOnly &&
        !layoutChanged &&
        mounted &&
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _updateSelectionChromeGeometry();
    } else if (!widget.style.readOnly) {
      _scheduleSelectionChromeGeometry();
    }
    _scheduleCaretGeometryUpdate();
    _refreshSelectionActions();
    // IME 最后一笔正文通知早于组合历史入栈，微任务读取才能拿到最终 canUndo/canRedo。
    _scheduleSystemUndoStateUpdate();
  }

  void _handleTransactionChanged() {
    // resetHistory 即使正文、选区和 dirty 都没变也会发布事务；同时 IME 最后一笔
    // 事务通知仍早于组合历史入栈，因此两条路径统一延到微任务读取最终历史。
    _scheduleSystemUndoStateUpdate();
  }

  void _handleFocusChanged() {
    if (_pendingFocusRebindGeneration != null) return;
    if (widget.style.readOnly && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    final focused = _focusNode.hasFocus && !widget.style.readOnly;
    if (focused == _focused) return;
    _focused = focused;
    _scope.pump(
      focused: focused,
      paintEditingState: !widget.style.readOnly,
      selectionVisible: !_selectionTextBlocked && (focused || widget.style.retainSelectionOnBlur),
    );
    if (focused) {
      _cancelCaretMotion(resetAnchor: true);
      _restoreCaretBlinkFromFocus();
      _claimSystemUndoManager();
      _openIme();
      _scheduleFrameSync();
      _scheduleSelectionChromeGeometry();
      _scheduleCaretGeometryUpdate();
    } else {
      _cancelCaretMotion(resetAnchor: true);
      _cancelFloatingCursor(restoreRegularCaret: false);
      _stopCaretBlink(regularCaretVisible: false);
      _releaseSystemUndoManager();
      _cancelCaretReveal();
      _finishImeAndClose(commitUnconfirmedAsPlainText: true);
      final menuOwnsFocus = _selectionMenuEntry?.isOpen ?? false;
      _cancelSelectionChromeInteractions(closeMenu: !menuOwnsFocus, clearMobileIntent: !menuOwnsFocus);
      _publishSelectionEndpoints(null);
      _scheduleCaretGeometryUpdate();
    }
  }

  bool get _caretBlinkCanRun =>
      mounted &&
      _elementActive &&
      !_tearingDownPipeline &&
      _caretBlinkTickerModeEnabled &&
      _caretBlinkViewActive &&
      !widget.style.readOnly &&
      _focused &&
      _focusNode.hasFocus &&
      !_floatingCursorState.isActive;

  void _handleCaretBlinkPhase(bool visible) {
    if (!_caretBlinkCanRun) return;
    if (!visible) {
      // 位置动画层自己绘制 primary caret。自定义时长若越过首个隐藏相位，
      // 必须先交还给行渲染再关门，否则 overlay 会绕过 blink gate 常亮。
      _cancelCaretMotion();
    }
    _scope.pump(regularCaretVisible: visible);
  }

  void _restartCaretBlink() {
    if (!_caretBlinkCanRun) return;
    // restart 在本来已可见时只重置 Timer；显式泵入保证 floating 等临时
    // 接管刚结束时也能在同一同步调用内恢复普通 caret。
    _scope.pump(regularCaretVisible: true);
    _caretBlink.restart();
  }

  void _stopCaretBlink({required bool regularCaretVisible}) {
    _caretBlink.stop();
    _scope.pump(regularCaretVisible: regularCaretVisible);
  }

  void _restoreCaretBlinkFromFocus() {
    if (_caretBlinkCanRun) {
      _restartCaretBlink();
    } else {
      final staticVisible =
          mounted &&
          _elementActive &&
          !_tearingDownPipeline &&
          _caretBlinkViewActive &&
          !widget.style.readOnly &&
          _focused &&
          _focusNode.hasFocus &&
          !_floatingCursorState.isActive;
      _stopCaretBlink(regularCaretVisible: staticVisible);
    }
  }

  // ===========================================================================
  // 系统撤销管理器
  // ===========================================================================

  void _claimSystemUndoManager() {
    if (!mounted || !_elementActive || widget.style.readOnly || !_focusNode.hasFocus) return;
    final changedOwner = !identical(UndoManager.client, this);
    UndoManager.client = this;
    if (changedOwner) _lastSystemUndoState = null;
    _updateSystemUndoState(force: changedOwner);
  }

  void _releaseSystemUndoManager() {
    if (!identical(UndoManager.client, this)) return;
    UndoManager.client = null;
    _lastSystemUndoState = null;
  }

  void _scheduleSystemUndoStateUpdate() {
    if (_systemUndoStateScheduled) return;
    _systemUndoStateScheduled = true;
    scheduleMicrotask(() {
      _systemUndoStateScheduled = false;
      if (!mounted) return;
      _updateSystemUndoState();
    });
  }

  void _updateSystemUndoState({bool force = false}) {
    if (!identical(UndoManager.client, this)) return;
    final next = (canUndo: canUndo, canRedo: canRedo);
    if (!force && _lastSystemUndoState == next) return;
    _lastSystemUndoState = next;
    // Flutter 引擎目前仅在 iOS 实现系统 UndoManager 插件；其他平台仍保留
    // client 所有权，以便未来引擎支持时无需改变编辑器焦点合同。
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      UndoManager.setUndoState(canUndo: next.canUndo, canRedo: next.canRedo);
    }
  }

  /// 当前焦点编辑器是否有可由系统撤销的历史。
  @override
  bool get canUndo => mounted && !widget.style.readOnly && (_controller.canUndo || _controller.hasActiveImeComposition);

  /// 当前焦点编辑器是否有可由系统重做的历史。
  @override
  bool get canRedo => mounted && !widget.style.readOnly && !_controller.hasActiveImeComposition && _controller.canRedo;

  /// 按现有组合会话规则提交候选后撤销一笔原子历史事务。
  @override
  void undo() {
    if (!mounted || !_elementActive || widget.style.readOnly) return;
    _imeInstance?.finishComposing(commit: true) ?? _controller.finishImeComposition(commit: true);
    _controller.undoEdit();
    _updateSystemUndoState();
  }

  /// 按现有组合会话规则提交候选后重做一笔原子历史事务。
  @override
  void redo() {
    if (!mounted || !_elementActive || widget.style.readOnly) return;
    _imeInstance?.finishComposing(commit: true) ?? _controller.finishImeComposition(commit: true);
    _controller.redoEdit();
    _updateSystemUndoState();
  }

  /// 只接受发给当前焦点 owner 的平台撤销或重做动作。
  @override
  void handlePlatformUndo(UndoDirection direction) {
    if (!identical(UndoManager.client, this) || !_focusNode.hasFocus) return;
    switch (direction) {
      case UndoDirection.undo:
        undo();
      case UndoDirection.redo:
        redo();
    }
  }

  void _handleScrolled() {
    if (_controller.inlineContent.isNotEmpty) _scheduleInlineViewportRefresh();
    if (_dragSelecting && !_draggingSelectionHandle) {
      _dragSelectionNeedsPaintSync = true;
    }
    _cancelCaretMotion();
    _caretMotionTarget = null;
    _syncTextViewportWidth();
    _scheduleFrameSync();
    _scheduleCaretGeometryUpdate();
    _scheduleFloatingCursorReproject();
    if (_selectionHandleControllerInstance?.isHandleDragInProgress ?? false) {
      _selectionHandleControllerInstance!.syncEndpointToLastDragPosition(_dragGlobal);
    }
    if (mounted && SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _updateSelectionChromeGeometry();
    } else {
      _scheduleSelectionChromeGeometry();
    }
    if (_selectionDragInfo.value == null) _markSelectionScrollActive();
  }

  bool _inlineViewportRefreshPending = false;

  void _scheduleInlineViewportRefresh() {
    if (_inlineViewportRefreshPending) return;
    _inlineViewportRefreshPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inlineViewportRefreshPending = false;
      if (mounted) _scope.refreshInlineViewport();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _handleInlineLayoutChanged() {
    _scheduleInlineViewportRefresh();
    _scheduleFrameSync();
    _scheduleCaretGeometryUpdate();
  }

  void _openIme() {
    _ime.open(_imeConfiguration());
    _syncImeStyle(force: true);
    _pushImeGeometry();
    _scheduleFrameSync();
  }

  void _handleImeFloatingCursor(RawFloatingCursorPoint point) {
    try {
      switch (point.state) {
        case FloatingCursorDragState.Start:
          _startFloatingCursor(point);
        case FloatingCursorDragState.Update:
          _updateFloatingCursor(point);
        case FloatingCursorDragState.End:
          _endFloatingCursor();
      }
    } finally {
      // 这是观察通道而非第二套实现：内部状态必须先完成，同一个平台事件再恰好
      // 透传一次，业务回调不得负责补画或改选区。
      widget.style.onFloatingCursor?.call(point);
    }
  }

  void _startFloatingCursor(RawFloatingCursorPoint point) {
    _cancelFloatingCursor();
    if (!mounted || !_elementActive || !_focused || widget.style.readOnly || _imeInstance?.attached != true) return;
    final primary = _controller.selections.primary;
    final startLocation = point.startLocation;
    // 对齐 Flutter EditableText：无 startLocation 的键盘浮动从 base/anchor
    // 起步，不能在反向非折叠选区里误用 active/extent 另一端。
    final position = _canonicalizeVisibleCaretPosition(
      startLocation == null
          ? _lineProjection.projectSelectionEndpointForGeometry(
              TextPosition(offset: primary.anchor, affinity: primary.affinity),
              oppositeEndpoint: TextPosition(offset: primary.active),
            )
          : _lineProjection.projectCollapsedPosition(startLocation.$2),
    );
    final caret = _floatingCaretRect(position);
    final editor = _editorBox;
    if (caret == null || editor == null || !editor.attached) return;
    final lineHeight = _floatingPreferredLineHeight(position);
    final bounds = _floatingAnchorBounds(position, lineHeight);
    if (bounds == null) return;
    final started = _floatingCursorState.start(
      pointOrigin: point.offset ?? Offset.zero,
      caretRect: caret,
      caretPosition: position,
      preferredLineHeight: lineHeight,
      anchorBounds: bounds,
      controllerToken: _controller,
      documentRevision: _controller.docRevision,
      startCaretCenter: startLocation?.$1,
      resetRelativeOrigin: startLocation == null,
    );
    if (!started) return;
    _floatingCursorRenderConfig = _scope.config;
    _floatingCursorPadding = widget.style.contentPadding;
    _floatingCursorSystemFontsRevision = _scope.systemFontsRevision;
    _floatingCursorEpoch++;
    _cancelCaretMotion();
    _stopCaretBlink(regularCaretVisible: false);
    _publishFloatingCursorFrame(_floatingCursorState.frame);
  }

  void _updateFloatingCursor(RawFloatingCursorPoint point) {
    final current = _floatingCursorState.frame;
    final rawPoint = point.offset;
    if (current == null || rawPoint == null || !_floatingCursorState.isDragging) return;
    final lineHeight = _floatingPreferredLineHeight(current.snappedPosition);
    final bounds = _floatingAnchorBounds(current.snappedPosition, lineHeight);
    final editor = _editorBox;
    if (bounds == null || editor == null) {
      _cancelFloatingCursor();
      return;
    }
    var geometryValid = true;
    Rect caretFor(TextPosition position) {
      final rect = _floatingCaretRect(position);
      if (rect != null) return rect;
      geometryValid = false;
      return current.placeholderRect;
    }

    final updated = _floatingCursorState.update(
      point: rawPoint,
      anchorBounds: bounds,
      hitTest: (local) => positionAtGlobal(editor.localToGlobal(local)),
      caretRectForPosition: caretFor,
      controllerToken: _controller,
      documentRevision: _controller.docRevision,
    );
    if (!updated || !geometryValid) {
      if (!geometryValid || !_floatingCursorState.isActive) _cancelFloatingCursor();
      return;
    }
    _publishFloatingCursorFrame(_floatingCursorState.frame);
  }

  void _endFloatingCursor() {
    if (!_floatingCursorState.end(controllerToken: _controller, documentRevision: _controller.docRevision)) return;
    _publishFloatingCursorFrame(_floatingCursorState.frame);
    final reset = _floatingCursorResetController ??= AnimationController(
      vsync: this,
      duration: EditableFloatingCursorState.resetDuration,
    );
    final previousListener = _floatingCursorResetListener;
    if (previousListener != null) reset.removeListener(previousListener);
    reset.stop();
    final epoch = ++_floatingCursorEpoch;
    void listener() => _tickFloatingCursorReset(epoch, reset.value);
    _floatingCursorResetListener = listener;
    reset
      ..addListener(listener)
      ..forward(from: 0);
  }

  void _tickFloatingCursorReset(int epoch, double value) {
    if (epoch != _floatingCursorEpoch || !_floatingCursorState.isSettling) return;
    final current = _floatingCursorState.frame;
    if (current == null) return;
    final target = _floatingCaretRect(current.snappedPosition);
    if (target == null) {
      _cancelFloatingCursor();
      return;
    }
    final duration = EditableFloatingCursorState.resetDuration;
    final elapsed = Duration(microseconds: (duration.inMicroseconds * value).round());
    final frame = _floatingCursorState.settle(
      elapsed: elapsed,
      selectionCollapsed: _controller.selections.primary.isCollapsed,
      caretRectForPosition: (_) => target,
      controllerToken: _controller,
      documentRevision: _controller.docRevision,
    );
    if (frame == null) {
      _cancelFloatingCursor();
      return;
    }
    if (!frame.isComplete) {
      _publishFloatingCursorFrame(frame);
      return;
    }

    final reset = _floatingCursorResetController;
    final listener = _floatingCursorResetListener;
    if (reset != null && listener != null) reset.removeListener(listener);
    _floatingCursorResetListener = null;
    _floatingCursorEpoch++;
    _floatingCursorRenderConfig = null;
    _floatingCursorPadding = null;
    _floatingCursorSystemFontsRevision = null;
    _publishFloatingCursorFrame(null);
    if (frame.shouldCollapseSelection) {
      _controller.setSelection(
        TextSelection.collapsed(offset: frame.snappedPosition.offset, affinity: frame.snappedPosition.affinity),
      );
    }
    _restoreCaretBlinkFromFocus();
  }

  Rect? _floatingCaretRect(TextPosition position) =>
      _rectAtOffset(position.offset, affinity: position.affinity, overwrite: false);

  double _floatingPreferredLineHeight(TextPosition position) {
    final line = _controller.document.lineIndexOf(math.max(0, position.offset));
    final height = _scope.preferredLineHeightFor(line);
    if (height.isFinite && height > 0) return height;
    final style = _scope.config.textStyle;
    return math.max(1, (style.fontSize ?? 14) * (style.height ?? 1));
  }

  Rect? _floatingAnchorBounds(TextPosition position, double preferredLineHeight) {
    final editor = _editorBox;
    if (editor == null || !editor.attached || !editor.hasSize) return null;
    final viewport = _scrollViewportRectInEditorForOffset(editor, position.offset) ?? (Offset.zero & editor.size);
    if (!viewport.isFinite || viewport.isEmpty) return null;
    const leftMargin = 4.0;
    const topMargin = 4.0;
    const rightMargin = 4.0;
    const bottomMargin = 5.0;
    final top = viewport.top - topMargin;
    return Rect.fromLTRB(
      viewport.left - leftMargin,
      top,
      viewport.right + rightMargin,
      math.max(top, viewport.bottom - preferredLineHeight + bottomMargin),
    );
  }

  void _publishFloatingCursorFrame(EditableFloatingCursorFrame? frame) {
    if (_floatingCursorFrame.value != frame) _floatingCursorFrame.value = frame;
  }

  void _scheduleFloatingCursorReproject() {
    if (!_floatingCursorState.isDragging || _floatingCursorReprojectScheduled) return;
    _floatingCursorReprojectScheduled = true;
    final epoch = _floatingCursorEpoch;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _floatingCursorReprojectScheduled = false;
      if (!mounted || !_elementActive || epoch != _floatingCursorEpoch) return;
      _reprojectFloatingCursor();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _reprojectFloatingCursor() {
    final current = _floatingCursorState.frame;
    final editor = _editorBox;
    if (current == null || editor == null || !_floatingCursorState.isDragging) return;
    final lineHeight = _floatingPreferredLineHeight(current.snappedPosition);
    final bounds = _floatingAnchorBounds(current.snappedPosition, lineHeight);
    if (bounds == null) {
      _cancelFloatingCursor();
      return;
    }
    var geometryValid = true;
    Rect caretFor(TextPosition position) {
      final rect = _floatingCaretRect(position);
      if (rect != null) return rect;
      geometryValid = false;
      return current.placeholderRect;
    }

    final reprojected = _floatingCursorState.reproject(
      anchorBounds: bounds,
      hitTest: (local) => positionAtGlobal(editor.localToGlobal(local)),
      caretRectForPosition: caretFor,
      controllerToken: _controller,
      documentRevision: _controller.docRevision,
    );
    if (!reprojected || !geometryValid) {
      if (!geometryValid || !_floatingCursorState.isActive) _cancelFloatingCursor();
      return;
    }
    _publishFloatingCursorFrame(_floatingCursorState.frame);
  }

  void _cancelFloatingCursor({bool restoreRegularCaret = true}) {
    final hadSession = _floatingCursorState.isActive || _floatingCursorFrame.value != null;
    if (_longPressFloatingCursor) {
      _longPressFloatingCursor = false;
      _longPressFloatingOrigin = Offset.zero;
      _stopLongPressPointerRoute();
    }
    _floatingCursorEpoch++;
    _floatingCursorReprojectScheduled = false;
    final reset = _floatingCursorResetController;
    final listener = _floatingCursorResetListener;
    if (reset != null && listener != null) reset.removeListener(listener);
    _floatingCursorResetListener = null;
    reset?.stop();
    _floatingCursorState.cancel();
    _floatingCursorRenderConfig = null;
    _floatingCursorPadding = null;
    _floatingCursorSystemFontsRevision = null;
    _publishFloatingCursorFrame(null);
    if (!hadSession) return;
    if (restoreRegularCaret) {
      _restoreCaretBlinkFromFocus();
    } else {
      _stopCaretBlink(regularCaretVisible: false);
    }
    if (restoreRegularCaret && mounted && _elementActive && _focused) {
      _scheduleCaretGeometryUpdate();
    }
  }

  void _cancelFloatingCursorIfLayoutSignatureChanged() {
    if (!_floatingCursorState.isActive) return;
    final next = _buildConfig();
    if (_floatingCursorRenderConfig?.hasSameLayout(next) == true &&
        _floatingCursorPadding == widget.style.contentPadding) {
      _floatingCursorRenderConfig = next;
      return;
    }
    // prototype/半行高一旦来自旧字体、缩放、方向或 wrap 配置，继续 reproject
    // 会把平台 delta 套进错误几何；排版签名变化必须直接结束本次会话。
    _cancelFloatingCursor();
  }

  void _handleEditableRenderScopeChanged() {
    if (widget.style.lineHeightMode == EditableLineHeightMode.fixed && !widget.style.softWrap) {
      final next = _scope.fixedLineHeight;
      final previous = _fixedLogicalLineExtent;
      _fixedLogicalLineExtent = next;
      if (previous != null && (previous - next).abs() > 1e-6) {
        _scheduleFixedLogicalLineExtentRebuild();
      }
    } else {
      _fixedLogicalLineExtent = null;
    }
    if (!_floatingCursorState.isActive) return;
    if (_floatingCursorSystemFontsRevision == _scope.systemFontsRevision) return;
    // Web 字体回退下载完成后 Paragraph 会换代；旧 prototype 的宽高已失效，
    // 即使 widget 配置没变也必须结束本次手势。
    _cancelFloatingCursor();
  }

  void _scheduleFixedLogicalLineExtentRebuild() {
    if (_fixedLogicalLineExtentRebuildScheduled || !mounted) return;
    _fixedLogicalLineExtentRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fixedLogicalLineExtentRebuildScheduled = false;
      if (!mounted || widget.style.lineHeightMode != EditableLineHeightMode.fixed || widget.style.softWrap) return;
      setState(() {});
    });
  }

  void _syncImeStyle({bool force = false}) {
    final ime = _imeInstance;
    if (ime?.attached != true) {
      _lastImeStyle = null;
      return;
    }
    final config = _scope.config;
    final next = (style: config.textStyle, direction: config.textDirection, align: config.textAlign);
    if (!force && next == _lastImeStyle) return;
    _lastImeStyle = next;
    ime!.updateStyle(next.style, next.direction, next.align);
  }

  void _handleImeConnectionClosed() {
    if (!mounted || _tearingDownPipeline) return;
    _cancelFloatingCursor(restoreRegularCaret: false);
    try {
      _finishImeAndClose(commitUnconfirmedAsPlainText: true);
    } finally {
      // 平台已先断开 connection；即使终态 formatter 抛编程异常，也必须让
      // FocusNode 落到 unfocused，否则下一击会误走“已有焦点”分支而无法重连。
      if (_focusNode.hasFocus) _focusNode.unfocus();
      // unfocus 经 FocusManager 微任务落地；业务若要同步重新 requestFocus，必须
      // 等内置失焦先结算，否则会抵消 pending unfocus 并留下 focused-but-detached。
      scheduleMicrotask(() {
        if (mounted && !_tearingDownPipeline) {
          widget.style.onConnectionClosed?.call();
        }
      });
    }
  }

  bool _requestKeyboard() {
    if (!mounted || !_elementActive || _tearingDownPipeline || widget.style.readOnly || !_focusNode.canRequestFocus) {
      return false;
    }
    if (_focusNode.hasFocus) {
      if (_imeInstance?.attached == true) {
        _openIme();
      } else {
        // connectionClosed 的 unfocus 可能仍在 FocusManager 队列中。等它先
        // 落地；若最终仍有焦点则直接补连接，否则重新请求焦点走标准路径。
        scheduleMicrotask(() {
          if (!mounted || !_elementActive || _tearingDownPipeline || widget.style.readOnly) {
            return;
          }
          if (_focusNode.hasFocus) {
            _openIme();
          } else if (_focusNode.canRequestFocus) {
            _focusNode.requestFocus();
          }
        });
      }
    } else {
      _focusNode.requestFocus();
    }
    return true;
  }

  void _handleImeAction(TextInputAction action) {
    // 非 newline 动作先结清 composing，再按 EditableText 的标准焦点语义
    // 处理；业务回调永远观察到一个完整、可撤销的输入事务。
    if (action != TextInputAction.newline || _controller.singleLine) {
      _imeInstance?.finishComposing(commit: true) ?? _controller.finishImeComposition(commit: true);
    }
    switch (action) {
      case TextInputAction.next:
        _focusNode.nextFocus();
      case TextInputAction.previous:
        _focusNode.previousFocus();
      case TextInputAction.done || TextInputAction.go || TextInputAction.search || TextInputAction.send:
        _focusNode.unfocus();
      case TextInputAction.none ||
          TextInputAction.unspecified ||
          TextInputAction.continueAction ||
          TextInputAction.join ||
          TextInputAction.route ||
          TextInputAction.emergencyCall:
        break;
      case TextInputAction.newline:
        if (_controller.singleLine) _focusNode.unfocus();
    }
    widget.style.onAction?.call(action);
  }

  void _handleImeNewline() {
    if (widget.style.readOnly || _controller.singleLine) return;
    if (widget.onInsertNewline != null) {
      widget.onInsertNewline!();
      return;
    }
    final selection = _controller.selection;
    _controller.imeReplace(
      selection.start,
      selection.end,
      '\n',
      selection: TextSelection.collapsed(offset: selection.start + 1),
      composing: TextRange.empty,
    );
  }

  void _handleImeSelector(String selector) {
    final action = _macOSSelectorAction(selector);
    try {
      if (action == null || !mounted || !_elementActive || _tearingDownPipeline || widget.style.readOnly) return;
      _cancelCaretReveal();
      _cancelSelectionChromeInteractions();
      if (widget.selectorHandler?.call(selector) != true) _executeMacOSSelector(action);
      if (_macOSSelectorRevealsCaret(action)) {
        _scheduleFrameSync(ensureVisible: true);
        _scheduleSelectionChromeGeometry();
      }
    } finally {
      // 观察者只能旁观：已知 selector 必须先由内核执行一次，回调抛错也不能
      // 反过来阻断标准 macOS 编辑动作。
      widget.style.onSelector?.call(selector);
    }
  }

  static _MacOSSelectorAction? _macOSSelectorAction(String selector) {
    final canonical = selector.endsWith(':') ? selector : '$selector:';
    return switch (canonical) {
      'deleteBackward:' => _MacOSSelectorAction.deleteBackward,
      'deleteWordBackward:' => _MacOSSelectorAction.deleteWordBackward,
      'deleteToBeginningOfLine:' => _MacOSSelectorAction.deleteToBeginningOfLine,
      'deleteForward:' => _MacOSSelectorAction.deleteForward,
      'deleteWordForward:' => _MacOSSelectorAction.deleteWordForward,
      'deleteToEndOfLine:' => _MacOSSelectorAction.deleteToEndOfLine,
      'moveLeft:' => _MacOSSelectorAction.moveLeft,
      'moveRight:' => _MacOSSelectorAction.moveRight,
      'moveForward:' => _MacOSSelectorAction.moveForward,
      'moveBackward:' => _MacOSSelectorAction.moveBackward,
      'moveUp:' => _MacOSSelectorAction.moveUp,
      'moveDown:' => _MacOSSelectorAction.moveDown,
      'moveLeftAndModifySelection:' => _MacOSSelectorAction.moveLeftAndModifySelection,
      'moveRightAndModifySelection:' => _MacOSSelectorAction.moveRightAndModifySelection,
      'moveUpAndModifySelection:' => _MacOSSelectorAction.moveUpAndModifySelection,
      'moveDownAndModifySelection:' => _MacOSSelectorAction.moveDownAndModifySelection,
      'moveWordLeft:' => _MacOSSelectorAction.moveWordLeft,
      'moveWordRight:' => _MacOSSelectorAction.moveWordRight,
      'moveToBeginningOfParagraph:' => _MacOSSelectorAction.moveToBeginningOfParagraph,
      'moveToEndOfParagraph:' => _MacOSSelectorAction.moveToEndOfParagraph,
      'moveWordLeftAndModifySelection:' => _MacOSSelectorAction.moveWordLeftAndModifySelection,
      'moveWordRightAndModifySelection:' => _MacOSSelectorAction.moveWordRightAndModifySelection,
      'moveParagraphBackwardAndModifySelection:' => _MacOSSelectorAction.moveParagraphBackwardAndModifySelection,
      'moveParagraphForwardAndModifySelection:' => _MacOSSelectorAction.moveParagraphForwardAndModifySelection,
      'moveToLeftEndOfLine:' => _MacOSSelectorAction.moveToLeftEndOfLine,
      'moveToRightEndOfLine:' => _MacOSSelectorAction.moveToRightEndOfLine,
      'moveToBeginningOfDocument:' => _MacOSSelectorAction.moveToBeginningOfDocument,
      'moveToEndOfDocument:' => _MacOSSelectorAction.moveToEndOfDocument,
      'moveToLeftEndOfLineAndModifySelection:' => _MacOSSelectorAction.moveToLeftEndOfLineAndModifySelection,
      'moveToRightEndOfLineAndModifySelection:' => _MacOSSelectorAction.moveToRightEndOfLineAndModifySelection,
      'moveToBeginningOfDocumentAndModifySelection:' =>
        _MacOSSelectorAction.moveToBeginningOfDocumentAndModifySelection,
      'moveToEndOfDocumentAndModifySelection:' => _MacOSSelectorAction.moveToEndOfDocumentAndModifySelection,
      'transpose:' => _MacOSSelectorAction.transpose,
      'scrollToBeginningOfDocument:' => _MacOSSelectorAction.scrollToBeginningOfDocument,
      'scrollToEndOfDocument:' => _MacOSSelectorAction.scrollToEndOfDocument,
      'scrollPageUp:' => _MacOSSelectorAction.scrollPageUp,
      'scrollPageDown:' => _MacOSSelectorAction.scrollPageDown,
      'pageUpAndModifySelection:' => _MacOSSelectorAction.pageUpAndModifySelection,
      'pageDownAndModifySelection:' => _MacOSSelectorAction.pageDownAndModifySelection,
      'cancelOperation:' => _MacOSSelectorAction.cancelOperation,
      'insertTab:' => _MacOSSelectorAction.insertTab,
      'insertBacktab:' => _MacOSSelectorAction.insertBacktab,
      _ => null,
    };
  }

  void _executeMacOSSelector(_MacOSSelectorAction action) {
    switch (action) {
      case _MacOSSelectorAction.deleteBackward:
        if (widget.style.readOnly) return;
        if (widget.style.obscureText) {
          _ops.deleteBackward(obscureText: true);
        } else {
          _executeAction(InputAction.deleteLeft);
        }
      case _MacOSSelectorAction.deleteWordBackward:
        if (widget.style.readOnly) return;
        if (widget.style.obscureText) {
          _ops.deleteToDocumentBoundary(forward: false);
        } else {
          _executeAction(InputAction.deleteWordLeft);
        }
      case _MacOSSelectorAction.deleteToBeginningOfLine:
        if (!widget.style.readOnly) _ops.deleteToLineBreak(forward: false, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.deleteForward:
        if (widget.style.readOnly) return;
        if (widget.style.obscureText) {
          _ops.deleteForward(obscureText: true);
        } else {
          _executeAction(InputAction.deleteRight);
        }
      case _MacOSSelectorAction.deleteWordForward:
        if (widget.style.readOnly) return;
        if (widget.style.obscureText) {
          _ops.deleteToDocumentBoundary(forward: true);
        } else {
          _executeAction(InputAction.deleteWordRight);
        }
      case _MacOSSelectorAction.deleteToEndOfLine:
        if (!widget.style.readOnly) _ops.deleteToLineBreak(forward: true, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveLeft:
        if (widget.style.obscureText) {
          _ops.moveSemanticsCursor(
            forward: false,
            byWord: false,
            extend: false,
            preserveSecondary: true,
            obscureText: true,
          );
        } else {
          _executeAction(InputAction.cursorLeft);
        }
      case _MacOSSelectorAction.moveRight:
        if (widget.style.obscureText) {
          _ops.moveSemanticsCursor(
            forward: true,
            byWord: false,
            extend: false,
            preserveSecondary: true,
            obscureText: true,
          );
        } else {
          _executeAction(InputAction.cursorRight);
        }
      case _MacOSSelectorAction.moveForward:
        _ops.moveSemanticsCursor(
          forward: true,
          byWord: false,
          extend: false,
          preserveSecondary: true,
          obscureText: widget.style.obscureText,
        );
      case _MacOSSelectorAction.moveBackward:
        _ops.moveSemanticsCursor(
          forward: false,
          byWord: false,
          extend: false,
          preserveSecondary: true,
          obscureText: widget.style.obscureText,
        );
      case _MacOSSelectorAction.moveUp:
        _executeAction(InputAction.cursorUp);
      case _MacOSSelectorAction.moveDown:
        _executeAction(InputAction.cursorDown);
      case _MacOSSelectorAction.moveLeftAndModifySelection:
        if (widget.style.obscureText) {
          _ops.moveSemanticsCursor(
            forward: false,
            byWord: false,
            extend: true,
            preserveSecondary: true,
            obscureText: true,
          );
        } else {
          _executeAction(InputAction.cursorLeftSelect);
        }
      case _MacOSSelectorAction.moveRightAndModifySelection:
        if (widget.style.obscureText) {
          _ops.moveSemanticsCursor(
            forward: true,
            byWord: false,
            extend: true,
            preserveSecondary: true,
            obscureText: true,
          );
        } else {
          _executeAction(InputAction.cursorRightSelect);
        }
      case _MacOSSelectorAction.moveUpAndModifySelection:
        _executeAction(InputAction.cursorUpSelect);
      case _MacOSSelectorAction.moveDownAndModifySelection:
        _executeAction(InputAction.cursorDownSelect);
      case _MacOSSelectorAction.moveWordLeft:
        if (widget.style.obscureText) {
          _ops.move(CaretMotion.docStart);
        } else {
          _executeAction(InputAction.cursorWordLeft);
        }
      case _MacOSSelectorAction.moveWordRight:
        if (widget.style.obscureText) {
          _ops.move(CaretMotion.docEnd);
        } else {
          _executeAction(InputAction.cursorWordRight);
        }
      case _MacOSSelectorAction.moveToBeginningOfParagraph:
        _ops.moveLineBreak(forward: false, extend: false, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveToEndOfParagraph:
        _ops.moveLineBreak(forward: true, extend: false, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveWordLeftAndModifySelection:
        _ops.moveWordBoundaryOrCaretLocation(forward: false, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveWordRightAndModifySelection:
        _ops.moveWordBoundaryOrCaretLocation(forward: true, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveParagraphBackwardAndModifySelection:
        if (widget.style.obscureText) {
          _ops.moveWordBoundaryOrCaretLocation(forward: false, obscureText: true);
        } else {
          _ops.moveParagraphBoundaryOrCaretLocation(forward: false);
        }
      case _MacOSSelectorAction.moveParagraphForwardAndModifySelection:
        if (widget.style.obscureText) {
          _ops.moveWordBoundaryOrCaretLocation(forward: true, obscureText: true);
        } else {
          _ops.moveParagraphBoundaryOrCaretLocation(forward: true);
        }
      case _MacOSSelectorAction.moveToLeftEndOfLine:
        _ops.moveLineBreak(forward: false, extend: false, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveToRightEndOfLine:
        _ops.moveLineBreak(forward: true, extend: false, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveToBeginningOfDocument:
        _executeAction(InputAction.cursorDocumentStart);
      case _MacOSSelectorAction.moveToEndOfDocument:
        _executeAction(InputAction.cursorDocumentEnd);
      case _MacOSSelectorAction.moveToLeftEndOfLineAndModifySelection:
        _ops.expandSelectionToLineBreak(forward: false, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveToRightEndOfLineAndModifySelection:
        _ops.expandSelectionToLineBreak(forward: true, obscureText: widget.style.obscureText);
      case _MacOSSelectorAction.moveToBeginningOfDocumentAndModifySelection:
        _ops.expandSelectionToDocumentBoundary(forward: false);
      case _MacOSSelectorAction.moveToEndOfDocumentAndModifySelection:
        _ops.expandSelectionToDocumentBoundary(forward: true);
      case _MacOSSelectorAction.transpose:
        if (!widget.style.readOnly) _ops.transposeCharacters();
      case _MacOSSelectorAction.scrollToBeginningOfDocument:
        _scrollToDocumentBoundary(forward: false);
      case _MacOSSelectorAction.scrollToEndOfDocument:
        _scrollToDocumentBoundary(forward: true);
      case _MacOSSelectorAction.scrollPageUp:
        _scrollPage(down: false);
      case _MacOSSelectorAction.scrollPageDown:
        _scrollPage(down: true);
      case _MacOSSelectorAction.pageUpAndModifySelection:
        _executeAction(InputAction.cursorPageUpSelect);
      case _MacOSSelectorAction.pageDownAndModifySelection:
        _executeAction(InputAction.cursorPageDownSelect);
      case _MacOSSelectorAction.cancelOperation:
        _executeAction(InputAction.escape);
      case _MacOSSelectorAction.insertTab:
        _focusNode.nextFocus();
      case _MacOSSelectorAction.insertBacktab:
        _focusNode.previousFocus();
    }
  }

  static bool _macOSSelectorRevealsCaret(_MacOSSelectorAction action) => switch (action) {
    _MacOSSelectorAction.scrollToBeginningOfDocument ||
    _MacOSSelectorAction.scrollToEndOfDocument ||
    _MacOSSelectorAction.scrollPageUp ||
    _MacOSSelectorAction.scrollPageDown ||
    _MacOSSelectorAction.insertTab ||
    _MacOSSelectorAction.insertBacktab => false,
    _ => true,
  };

  void _scrollToDocumentBoundary({required bool forward}) {
    _scheduleFrameSync();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_elementActive || _tearingDownPipeline) return;
      final controller = _controller;
      final docRevision = controller.docRevision;
      final projection = _lineProjection;
      final projectionRevision = projection.mappingRevision;
      final targetLine = forward ? projection.lastVisibleModelLine : projection.firstVisibleModelLine;
      final targetOffset = forward
          ? controller.document.lineEnd(targetLine)
          : controller.document.lineStart(targetLine);
      final targetAffinity = forward ? TextAffinity.upstream : TextAffinity.downstream;
      final targetViewRow = projection.viewRowForModelLine(targetLine)!;
      if (_scrollController.hasClients) {
        _scrollPositionToBoundary(_scrollController.position, forward: forward);
      }
      _scheduleDocumentOffsetReveal(
        controller: controller,
        docRevision: docRevision,
        projection: projection,
        projectionRevision: projectionRevision,
        offset: targetOffset,
        affinity: targetAffinity,
        forward: forward,
      );
      final positioning = _scrollController.hasClients
          ? _rowJump.jumpToIndex(targetViewRow, alignment: forward ? 1.0 : 0.0)
          : Future<bool>.value(false);
      unawaited(
        positioning.then<void>((_) {
          _scheduleDocumentOffsetReveal(
            controller: controller,
            docRevision: docRevision,
            projection: projection,
            projectionRevision: projectionRevision,
            offset: targetOffset,
            affinity: targetAffinity,
            forward: forward,
          );
        }),
      );
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _scrollPage({required bool down}) {
    _scheduleFrameSync();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_elementActive || _tearingDownPipeline) return;
      final verticalMoved = _scrollController.hasClients
          ? _scrollPositionByPage(_scrollController.position, forward: down, fallbackExtent: _pageExtent())
          : false;
      final verticalScrollable =
          _scrollController.hasClients &&
          (_scrollController.position.maxScrollExtent - _scrollController.position.minScrollExtent).abs() >
              _caretRevealTolerance;
      if (!widget.style.softWrap && !verticalScrollable && !verticalMoved && _horizontalController.hasClients) {
        _scrollPositionByPage(
          _horizontalController.position,
          forward: down,
          fallbackExtent: _editorBox?.size.width ?? _pageExtent(),
        );
      }
      _scheduleFrameSync();
      if (_selectionDragInfo.value == null) _markSelectionScrollActive();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool _scrollPositionByPage(ScrollPosition position, {required bool forward, required double fallbackExtent}) {
    final viewport = position.hasViewportDimension ? position.viewportDimension : fallbackExtent;
    final delta = viewport.isFinite && viewport > 0 ? viewport : fallbackExtent;
    if (!delta.isFinite || delta <= 0) return false;
    final signed = forward ? delta : -delta;
    final target = (position.pixels + signed).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    if ((target - position.pixels).abs() <= _caretRevealTolerance) return false;
    position.jumpTo(target);
    return true;
  }

  bool _scrollPositionToBoundary(ScrollPosition position, {required bool forward}) {
    final target = forward ? position.maxScrollExtent : position.minScrollExtent;
    if (!target.isFinite || (target - position.pixels).abs() <= _caretRevealTolerance) return false;
    position.jumpTo(target);
    return true;
  }

  void _scheduleDocumentOffsetReveal({
    required EditableController controller,
    required int docRevision,
    required EditableLineProjection projection,
    required int projectionRevision,
    required int offset,
    required TextAffinity affinity,
    required bool forward,
    int remainingAttempts = 6,
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_elementActive ||
          _tearingDownPipeline ||
          !identical(controller, _controller) ||
          controller.docRevision != docRevision ||
          !identical(projection, _lineProjection) ||
          projection.mappingRevision != projectionRevision) {
        return;
      }
      if (_scrollController.hasClients) {
        _scrollPositionToBoundary(_scrollController.position, forward: forward);
      }
      final resolved = _revealDocumentOffsetInViewport(offset, affinity: affinity);
      _scheduleFrameSync();
      if (_selectionDragInfo.value == null) _markSelectionScrollActive();
      if (!resolved && remainingAttempts > 0) {
        _scheduleDocumentOffsetReveal(
          controller: controller,
          docRevision: docRevision,
          projection: projection,
          projectionRevision: projectionRevision,
          offset: offset,
          affinity: affinity,
          forward: forward,
          remainingAttempts: remainingAttempts - 1,
        );
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool _revealDocumentOffsetInViewport(int offset, {required TextAffinity affinity}) {
    final editor = _editorBox;
    if (editor == null) return false;
    final rect = _rectAtOffset(offset, affinity: affinity, overwrite: false);
    final viewport = _scrollViewportRectInEditorForOffset(editor, offset);
    if (rect == null || viewport == null) return false;
    final revealViewport = _caretRevealViewport(viewport, rect);
    if (_scrollController.hasClients) {
      final verticalDelta = rect.top < revealViewport.top
          ? rect.top - revealViewport.top
          : rect.bottom > revealViewport.bottom
          ? rect.bottom - revealViewport.bottom
          : 0.0;
      _scrollPositionByDelta(_scrollController.position, verticalDelta);
    }
    if (!widget.style.softWrap && _horizontalController.hasClients) {
      final horizontalDelta = rect.left < revealViewport.left
          ? rect.left - revealViewport.left
          : rect.right > revealViewport.right
          ? rect.right - revealViewport.right
          : 0.0;
      _scrollPositionByDelta(_horizontalController.position, horizontalDelta);
    }
    return true;
  }

  /// 把物理 viewport 内缩为 caret 自动 reveal 的内容可见区。
  ///
  /// padding 大于剩余空间时按比例收缩，至少给当前 caret 留出可容纳范围，
  /// 避免退化为反向 Rect 后在两侧来回滚动。
  Rect _caretRevealViewport(Rect viewport, Rect caret) {
    final padding = widget.style.contentPadding;
    final horizontalBudget = math.max(0.0, viewport.width - math.min(viewport.width, caret.width));
    final verticalBudget = math.max(0.0, viewport.height - math.min(viewport.height, caret.height));
    final horizontalScale = padding.horizontal <= horizontalBudget || padding.horizontal == 0
        ? 1.0
        : horizontalBudget / padding.horizontal;
    final verticalScale = padding.vertical <= verticalBudget || padding.vertical == 0
        ? 1.0
        : verticalBudget / padding.vertical;
    return Rect.fromLTRB(
      viewport.left + padding.left * horizontalScale,
      viewport.top + padding.top * verticalScale,
      viewport.right - padding.right * horizontalScale,
      viewport.bottom - padding.bottom * verticalScale,
    );
  }

  bool _scrollPositionByDelta(ScrollPosition position, double delta) {
    if (delta.abs() <= _caretRevealTolerance) return false;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    if ((target - position.pixels).abs() <= _caretRevealTolerance) return false;
    position.jumpTo(target);
    return true;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.style.readOnly) {
      final result = widget.style.onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
      if (result != KeyEventResult.ignored) return result;
      final previous = _previousFocusKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
      if (previous != KeyEventResult.ignored) return previous;
      return KeyEventResult.ignored;
    }

    final advancesChord = event is KeyDownEvent || event is KeyRepeatEvent;
    if (advancesChord) {
      _selectionUsesMobileChrome = false;
      _scheduleSelectionChromeGeometry();
    }
    final result = widget.style.onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
    if (result != KeyEventResult.ignored) {
      return result;
    }
    final previous = _previousFocusKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
    if (previous != KeyEventResult.ignored) {
      return previous;
    }
    final keyResult = _keys.handle(node, event);
    if (keyResult != KeyEventResult.ignored) return keyResult;
    // 输入键必须在编辑器焦点边界内终止 Flutter 快捷键冒泡，
    // 同时保留给平台 TextInput/IME；handled 会把 Web 默认输入一并截断。
    if (_isPlatformTextKey(event.logicalKey)) return KeyEventResult.skipRemainingHandlers;
    return KeyEventResult.ignored;
  }

  static bool _isPlatformTextKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;

  // ===========================================================================
  // 指针 → 选区
  // ===========================================================================

  static bool _selectableKind(ElEventDetails e) {
    final original = e.originalEvent;
    if (original is! PointerEvent) return true;
    return original.kind == PointerDeviceKind.mouse || original.kind == PointerDeviceKind.stylus;
  }

  static bool _mobileSelectionKind(ElEventDetails e) {
    final original = e.originalEvent;
    return original is PointerEvent && original.kind != PointerDeviceKind.mouse;
  }

  void _handlePointerDownFocus(ElEventDetails e) {
    if (widget.style.readOnly) return;
    // 空文档没有字形命中目标；在原始 down 阶段直接取焦，不能依赖行节点
    // 或等待鼠标 Tap 手势与滚动容器竞争完再决定是否聚焦。触摸/手写笔必须
    // 继续交给指针焦点仲裁（PointerFocusArbiter）的 pending-tap 判定，拖动被
    // 滚动接收时不得弹键盘。
    final original = e.originalEvent;
    if (_focusNode.hasFocus) _restartCaretBlink();
    if (original is PointerEvent && original.kind != PointerDeviceKind.mouse) {
      return;
    }
    if (_focusNode.hasFocus) {
      // ElView 的全局 pointer-down 仲裁可能在本回调后才结算默认 blur；点击
      // 已聚焦正文（尤其带 Alt/Ctrl 修饰键）不能因此把 caret 弄丢。
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _elementActive && !_focusNode.hasFocus && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });
      return;
    }
    if (!_focusNode.hasFocus && _focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
  }

  void _handleTapDown(ElEventDetails e) {
    if (_selectionTextBlocked && !widget.style.readOnly) {
      final position = positionAtGlobal(e.globalPosition);
      _controller.setSelection(TextSelection.collapsed(offset: position.offset, affinity: position.affinity));
      return;
    }
    if (!_interactiveSelectionEnabled) return;
    if (_focused) _restartCaretBlink();
    _multiClickSelectionAppliedOnDown = false;
    _selectionMenuEntry?.close();
    _selectionUsesMobileChrome = false;
    final position = positionAtGlobal(e.globalPosition);
    _dragAnchor = position;
    _resetDragSelectionGranularity();
    if (HardwareKeyboard.instance.isShiftPressed) {
      _ops.extendTo(position);
    } else {
      _controller.setSelection(TextSelection.collapsed(offset: position.offset, affinity: position.affinity));
    }
    _capturePointerSelectionCandidate(e);
  }

  void _handleTapUp(ElEventDetails e) {
    _pointerSelectionCandidate = null;
  }

  void _handleTapCancel(ElEventDetails e) {
    // 点击超出距离会先于 dragStart 取消，但同一鼠标或手写笔仍可继续拖选。
    if (_dragSelecting || _longPressPointer != null) return;
    final original = e.originalEvent;
    final candidate = _pointerSelectionCandidate;
    // 自身手势认领只取消最终点击；dragStart 仍需用原候选复核文档和选词粒度。
    if (e.cancelReason == ElEventCancelReason.selfGestureAccepted &&
        original is PointerEvent &&
        candidate?.pointer == original.pointer) {
      return;
    }
    if (e.cancelReason == ElEventCancelReason.tapRejected &&
        original is PointerMoveEvent &&
        _selectableKind(e) &&
        candidate != null &&
        original.pointer == candidate.pointer &&
        original.buttons == candidate.buttons) {
      return;
    }
    _resetDragSelectionGranularity();
  }

  void _handlePointerSelectionEnd(ElEventDetails e) {
    final original = e.originalEvent;
    final candidate = _pointerSelectionCandidate;
    if (candidate == null || original is! PointerEvent || original.pointer != candidate.pointer) return;
    if (e.phase == ElEventPhase.pointerCancel) {
      _resetDragSelectionGranularity();
    } else {
      // 等本次 Up 内的短快划救援及双/三击收尾完成，再清理没有被消费的候选。
      scheduleMicrotask(() {
        if (identical(_pointerSelectionCandidate, candidate)) _resetDragSelectionGranularity();
      });
    }
  }

  static bool _isPrimaryMouseDown(ElEventDetails e) {
    final original = e.originalEvent;
    return original is PointerDownEvent &&
        original.kind == PointerDeviceKind.mouse &&
        (original.buttons & kPrimaryMouseButton) != 0;
  }

  static bool _isMousePointerEvent(ElEventDetails e) {
    final original = e.originalEvent;
    return original is PointerEvent && original.kind == PointerDeviceKind.mouse;
  }

  TextRange _obscuredCodePointRangeAt(TextPosition position) {
    final document = _controller.document;
    final length = document.length;
    if (length == 0) return const TextRange.collapsed(0);
    var start = position.offset.clamp(0, length);
    if (start == length) start--;
    var unit = document.getText(start, start + 1).codeUnitAt(0);
    if (unit >= 0xdc00 && unit <= 0xdfff && start > 0) {
      final previous = document.getText(start - 1, start).codeUnitAt(0);
      if (previous >= 0xd800 && previous <= 0xdbff) {
        start--;
        unit = previous;
      }
    }
    var end = start + 1;
    if (unit >= 0xd800 && unit <= 0xdbff && end < length) {
      final next = document.getText(end, end + 1).codeUnitAt(0);
      if (next >= 0xdc00 && next <= 0xdfff) end++;
    }
    return TextRange(start: start, end: end);
  }

  TextRange _multiClickRangeAt(TextPosition position, _EditableDragSelectionGranularity granularity) {
    if (widget.style.obscureText) return _obscuredCodePointRangeAt(position);
    return switch (granularity) {
      _EditableDragSelectionGranularity.character => TextRange.collapsed(position.offset),
      _EditableDragSelectionGranularity.word => wordBoundary(position),
      _EditableDragSelectionGranularity.line => _logicalLineRangeAt(position),
    };
  }

  void _applyMultiClickSelection(ElEventDetails e, _EditableDragSelectionGranularity granularity) {
    _selectionUsesMobileChrome = _mobileSelectionKind(e);
    final position = positionAtGlobal(e.globalPosition);
    _dragAnchor = position;
    final effectiveGranularity = widget.style.obscureText ? _EditableDragSelectionGranularity.character : granularity;
    _dragSelectionGranularity = effectiveGranularity;
    final extendFromAnchor = HardwareKeyboard.instance.isShiftPressed;
    final previousAnchor = _controller.selection.baseOffset;
    final range = _multiClickRangeAt(position, granularity);
    if (extendFromAnchor) {
      final extent = position.offset >= previousAnchor ? range.end : range.start;
      _controller.setSelection(TextSelection(baseOffset: previousAnchor, extentOffset: extent));
    } else if (widget.style.obscureText) {
      _controller.setSelection(TextSelection(baseOffset: range.start, extentOffset: range.end));
    } else {
      switch (granularity) {
        case _EditableDragSelectionGranularity.character:
          _controller.setSelection(TextSelection.collapsed(offset: position.offset, affinity: position.affinity));
        case _EditableDragSelectionGranularity.word:
          _ops.selectWordAt(position);
        case _EditableDragSelectionGranularity.line:
          _controller.setSelection(
            TextSelection(baseOffset: range.start, extentOffset: range.end, affinity: TextAffinity.upstream),
          );
      }
    }
    switch (effectiveGranularity) {
      case _EditableDragSelectionGranularity.character:
        _dragAnchorLineRange = null;
      case _EditableDragSelectionGranularity.word:
        // 锚点在第二次 down 冻结；拖动期间文档外部变化会取消会话，词界不会漂移。
        _dragAnchorLineRange = null;
      case _EditableDragSelectionGranularity.line:
        _dragAnchorLineRange = range;
    }
    if (_selectionUsesMobileChrome) _scheduleSelectionChromeGeometry();
  }

  void _handleDoubleTapDown(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (!_isPrimaryMouseDown(e)) return;
    _applyMultiClickSelection(e, _EditableDragSelectionGranularity.word);
    _capturePointerSelectionCandidate(e);
    _multiClickSelectionAppliedOnDown = true;
  }

  void _handleTripleTapDown(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (!_isPrimaryMouseDown(e)) return;
    _applyMultiClickSelection(e, _EditableDragSelectionGranularity.line);
    _capturePointerSelectionCandidate(e);
    _multiClickSelectionAppliedOnDown = true;
  }

  void _handleDoubleTap(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (_isMousePointerEvent(e) && _multiClickSelectionAppliedOnDown) {
      _multiClickSelectionAppliedOnDown = false;
      return;
    }
    _applyMultiClickSelection(e, _EditableDragSelectionGranularity.word);
    _multiClickSelectionAppliedOnDown = false;
  }

  void _handleTripleTap(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (_isMousePointerEvent(e) && _multiClickSelectionAppliedOnDown) {
      _multiClickSelectionAppliedOnDown = false;
      return;
    }
    _applyMultiClickSelection(e, _EditableDragSelectionGranularity.line);
    _multiClickSelectionAppliedOnDown = false;
  }

  void _handleLongPress(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) {
      e.preventDefault();
      return;
    }
    final original = e.originalEvent;
    if (original is! PointerDownEvent || original.kind == PointerDeviceKind.mouse) {
      // ElEvent 的 longPress 回调默认会自动认领手势；鼠标拒绝长按时
      // 必须阻止该默认行为，否则会偷走选区内已建立的文本 DnD candidate。
      e.preventDefault();
      return;
    }
    // 触摸长按建立选区后直接走 pointer route：同一根指头后续
    // move/up 不再依赖祖先滚动的 Drag recognizer 是否还在场。
    e.eagerGesture(cancelSelfTap: true);
    e.stopPropagation();
    final hadFocus = _focusNode.hasFocus;
    _focusNode.requestFocus();
    final position = positionAtGlobal(e.globalPosition);
    final usesFloatingLongPress =
        (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) &&
        hadFocus &&
        !widget.style.readOnly;
    if (usesFloatingLongPress) {
      _controller.setSelection(TextSelection.collapsed(offset: position.offset, affinity: position.affinity));
      final editor = _editorBox;
      if (editor != null) {
        final local = editor.globalToLocal(e.globalPosition);
        _handleImeFloatingCursor(
          RawFloatingCursorPoint(
            state: FloatingCursorDragState.Start,
            offset: Offset.zero,
            startLocation: (local, position),
          ),
        );
        if (_floatingCursorState.isActive) {
          _selectionUsesMobileChrome = false;
          _dragSelecting = false;
          _draggingSelectionHandle = false;
          _dragAutoScrollActivated = false;
          _stopDragAutoScroll();
          _dragGlobal = original.position;
          _longPressFloatingCursor = true;
          _longPressFloatingOrigin = local;
          _selectionControls.onLongPressStart(original.kind);
          if (_selectionControls.resolveLongPressHaptics(context)) {
            unawaited(HapticFeedback.vibrate());
          }
          _startLongPressPointerRoute(original);
          return;
        }
      }
    }
    _dragAnchor = position;
    final selectionMode = _selectionControls.resolveLongPressSelection(context);
    _selectionUsesMobileChrome = true;
    _dragSelectionGranularity = widget.style.obscureText
        ? _EditableDragSelectionGranularity.character
        : selectionMode == LongPressSelection.word
        ? _EditableDragSelectionGranularity.word
        : _EditableDragSelectionGranularity.line;
    if (widget.style.obscureText) {
      _dragAnchorLineRange = null;
      final range = _obscuredCodePointRangeAt(position);
      _controller.setSelection(TextSelection(baseOffset: range.start, extentOffset: range.end));
    } else if (_dragSelectionGranularity == _EditableDragSelectionGranularity.word) {
      _dragAnchorLineRange = null;
      _ops.selectWordAt(position);
    } else {
      final range = _logicalLineRangeAt(position);
      _dragAnchorLineRange = range;
      _controller.setSelection(TextSelection(baseOffset: range.start, extentOffset: range.end));
    }
    _dragSelecting = true;
    _draggingSelectionHandle = false;
    _dragAutoScrollKind = _EditableAutoScrollKind.longPress;
    _dragAutoScrollOrigin = original.position;
    _dragAutoScrollActivated = false;
    _dragGlobal = original.position;
    _selectionControls.onLongPressStart(original.kind);
    if (_selectionControls.resolveLongPressHaptics(context)) {
      unawaited(HapticFeedback.vibrate());
    }
    _selectionDragInfo.value = SelectionDragInfo(
      kind: SelectionDragKind.longPress,
      side: null,
      globalPosition: original.position,
    );
    _startLongPressPointerRoute(original);
    _updateDragAutoScroll();
    _scheduleSelectionChromeGeometry();
  }

  void _startLongPressPointerRoute(PointerDownEvent event) {
    _stopLongPressPointerRoute();
    _longPressPointer = event.pointer;
    _longPressPointerRoute = (PointerEvent routed) {
      if (routed.pointer != _longPressPointer) return;
      if (_longPressFloatingCursor) {
        if (routed is PointerMoveEvent) {
          _dragGlobal = routed.position;
          final editor = _editorBox;
          if (editor == null) {
            _cancelFloatingCursor();
            return;
          }
          _handleImeFloatingCursor(
            RawFloatingCursorPoint(
              state: FloatingCursorDragState.Update,
              offset: editor.globalToLocal(routed.position) - _longPressFloatingOrigin,
            ),
          );
          return;
        }
        if (routed is PointerUpEvent || routed is PointerCancelEvent || routed is PointerRemovedEvent) {
          _handleImeFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.End));
          _finishLongPressDrag();
        }
        return;
      }
      if (routed is PointerMoveEvent) {
        _dragGlobal = routed.position;
        if ((routed.position - _dragAutoScrollOrigin).distance >=
            _selectionControls.resolveLongPressAutoScrollThreshold(context)) {
          _dragAutoScrollActivated = true;
        }
        _extendDragSelection();
        _selectionDragInfo.value = SelectionDragInfo(
          kind: SelectionDragKind.longPress,
          side: null,
          globalPosition: routed.position,
        );
        _updateDragAutoScroll();
        return;
      }
      if (routed is PointerUpEvent || routed is PointerCancelEvent || routed is PointerRemovedEvent) {
        if (routed is PointerUpEvent) {
          _dragGlobal = routed.position;
          _extendDragSelection();
        }
        _finishLongPressDrag();
      }
    };
    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _longPressPointerRoute!);
  }

  void _finishLongPressDrag() {
    final wasFloating = _longPressFloatingCursor;
    _longPressFloatingCursor = false;
    _longPressFloatingOrigin = Offset.zero;
    _stopLongPressPointerRoute();
    _dragSelecting = false;
    _resetDragSelectionGranularity();
    _dragAutoScrollActivated = false;
    _stopDragAutoScroll();
    if (!wasFloating && _selectionDragInfo.value?.kind == SelectionDragKind.longPress) {
      _selectionDragInfo.value = null;
    }
    _scheduleSelectionChromeGeometry();
  }

  void _stopLongPressPointerRoute() {
    final pointer = _longPressPointer;
    final route = _longPressPointerRoute;
    _longPressPointer = null;
    _longPressPointerRoute = null;
    if (pointer != null && route != null) {
      GestureBinding.instance.pointerRouter.removeRoute(pointer, route);
    }
  }

  void _handleSecondaryTapDown(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (!widget.style.enabledContextMenu || _selectionControls is! DesktopSelectionControls) return;
    _focusNode.requestFocus();
    final position = positionAtGlobal(e.globalPosition);
    final inside = _controller.selections.all.any(
      (selection) => !selection.isCollapsed && position.offset >= selection.start && position.offset < selection.end,
    );
    if (!inside) {
      _controller.setSelection(TextSelection.collapsed(offset: position.offset, affinity: position.affinity));
    }
    _secondaryTapGlobal = e.globalPosition;
  }

  void _handleSecondaryTapUp(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    final controls = _selectionControls;
    final position = _secondaryTapGlobal ?? e.globalPosition;
    _secondaryTapGlobal = null;
    if (!widget.style.enabledContextMenu || controls is! DesktopSelectionControls || !mounted) return;
    _selectionMenuEntry?.close();
    final entry = controls.showContextMenu(context, position: position, actions: _selectionActions());
    _selectionMenuEntry = entry;
    entry?.closed.then((_) {
      if (identical(_selectionMenuEntry, entry)) _selectionMenuEntry = null;
    });
  }

  void _handleDragStart(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (_longPressPointer != null) return;
    if (!_selectableKind(e)) return;
    final original = e.originalEvent;
    final selectionCandidate = _pointerSelectionCandidate;
    if (selectionCandidate == null ||
        original is! PointerEvent ||
        original.pointer != selectionCandidate.pointer ||
        !_pointerSelectionCandidateIsCurrent(selectionCandidate)) {
      _resetDragSelectionGranularity();
      return;
    }
    e.eagerGesture(cancelSelfTap: true);
    e.stopPropagation();
    // eager 会同步结清祖先手势，祖先回调可能改写文档或选区；认领后必须
    // 再验一次，绝不能把 down 时的词、行或列选锚点套到外部新状态上。
    if (!mounted || !_pointerSelectionCandidateIsCurrent(selectionCandidate)) {
      _resetDragSelectionGranularity();
      return;
    }
    _pointerSelectionCandidate = null;
    _dragSelecting = true;
    _draggingSelectionHandle = false;
    _selectionUsesMobileChrome = false;
    _dragAutoScrollKind = _EditableAutoScrollKind.mouse;
    _dragAutoScrollOrigin = e.globalPosition;
    _dragAutoScrollActivated = true;
    // 起手即记录/扩选/评估边缘滚动：大位移单跳可能只有 dragStart 没有后续
    // update（重采样/合并），起点已越界时 ticker 必须从这里就启动
    _dragGlobal = e.globalPosition;
    _extendDragSelection();
    _scheduleSelectionChromeGeometry();
    _updateDragAutoScroll();
  }

  void _handleDragUpdate(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (_longPressPointer != null) return;
    if (!_dragSelecting) return;
    _dragGlobal = e.globalPosition;
    if (_draggingSelectionHandle) {
      _selectionHandleControllerInstance!.syncEndpointToLastDragPosition(_dragGlobal);
    } else {
      _extendDragSelection();
      final drag = _selectionDragInfo.value;
      if (drag?.kind == SelectionDragKind.longPress) {
        _selectionDragInfo.value = SelectionDragInfo(
          kind: SelectionDragKind.longPress,
          side: null,
          globalPosition: _dragGlobal,
        );
      }
    }
    _scheduleSelectionChromeGeometry();
    _updateDragAutoScroll();
  }

  void _handleDragEnd(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (_longPressPointer != null) return;

    _dragSelecting = false;
    _resetDragSelectionGranularity();
    _dragAutoScrollActivated = false;
    _stopDragAutoScroll();
    _scheduleSelectionChromeGeometry();
  }

  void _handleDragCancel(ElEventDetails e) {
    if (!_interactiveSelectionEnabled) return;
    if (_longPressPointer != null) return;

    _dragSelecting = false;
    _resetDragSelectionGranularity();
    _dragAutoScrollActivated = false;
    _stopDragAutoScroll();
    _scheduleSelectionChromeGeometry();
  }

  void _extendDragSelection() {
    final position = positionAtGlobal(_dragGlobal);
    _runSelectionGestureWrite(() {
      switch (_dragSelectionGranularity) {
        case _EditableDragSelectionGranularity.character:
          _ops.extendTo(position);
        case _EditableDragSelectionGranularity.word:
          _ops.extendWordTo(position, anchor: _dragAnchor);
        case _EditableDragSelectionGranularity.line:
          _extendLineSelection(position);
      }
    });
  }

  TextRange _logicalLineRangeAt(TextPosition position) {
    final document = _controller.document;
    final line = document.lineIndexOf(position.offset);
    return TextRange(
      start: document.lineStart(line),
      end: line < document.lineCount - 1 ? document.lineStart(line + 1) : document.lineEnd(line),
    );
  }

  void _extendLineSelection(TextPosition position) {
    final anchor = _dragAnchorLineRange;
    if (anchor == null) return;
    final target = _logicalLineRangeAt(position);
    final forward = target.start >= anchor.start;
    _controller.setSelection(
      TextSelection(
        baseOffset: forward ? anchor.start : anchor.end,
        extentOffset: forward ? target.end : target.start,
        affinity: TextAffinity.upstream,
      ),
    );
  }

  void _resetDragSelectionGranularity() {
    _pointerSelectionCandidate = null;
    _dragSelectionGranularity = _EditableDragSelectionGranularity.character;
    _dragAnchorLineRange = null;
    _multiClickSelectionAppliedOnDown = false;
  }

  void _capturePointerSelectionCandidate(ElEventDetails e) {
    final original = e.originalEvent;
    if (original is! PointerEvent) return;
    final controller = _controller;
    final lineProjection = _lineProjection;
    _pointerSelectionCandidate = _EditablePointerSelectionCandidate(
      pointer: original.pointer,
      buttons: original.buttons,
      controller: controller,
      docRevision: controller.docRevision,
      visualRevision: controller.visualRevision,
      presentationRevision: controller.presentationRevision,
      selections: controller.selections,
      lineProjection: lineProjection,
      projectionRevision: lineProjection.mappingRevision,
      readOnly: widget.style.readOnly,
      obscureText: widget.style.obscureText,
    );
  }

  bool _pointerSelectionCandidateIsCurrent(_EditablePointerSelectionCandidate candidate) =>
      mounted &&
      _elementActive &&
      identical(candidate.controller, _controller) &&
      candidate.docRevision == _controller.docRevision &&
      candidate.visualRevision == _controller.visualRevision &&
      candidate.presentationRevision == _controller.presentationRevision &&
      candidate.selections == _controller.selections &&
      identical(candidate.lineProjection, _lineProjection) &&
      candidate.projectionRevision == _lineProjection.mappingRevision &&
      candidate.readOnly == widget.style.readOnly &&
      candidate.obscureText == widget.style.obscureText;

  List<EditableBoxSelectionRow> _boundedColumnSelectionRows({
    required ({int line, int visualLine}) anchorRow,
    required ({int line, int visualLine}) activeRow,
    required double activeX,
    int? limit,
  }) {
    _debugLastColumnSelectionPainterQueryCount = 0;
    final secondaryLimit = (limit ?? 10000) - 1;
    final rows = <EditableBoxSelectionRow>[];
    final activeMeasured = _columnSelectionRowAt(activeRow, activeX: activeX, isActiveRow: true);
    final normalizedActive = (line: activeRow.line, visualLine: activeMeasured.visualLine);
    var current = anchorRow;
    bool? forward;
    while (rows.length < secondaryLimit) {
      final measured = _columnSelectionRowAt(current, activeX: activeX);
      final normalizedCurrent = (line: current.line, visualLine: measured.visualLine);
      final direction = _compareVisualRows(normalizedCurrent, normalizedActive);
      if (direction == 0) break;
      final movesForward = direction < 0;
      if (forward != null && forward != movesForward) break;
      forward ??= movesForward;
      rows.add(measured.row);
      if (rows.length >= secondaryLimit) break;
      if (forward) {
        if (normalizedCurrent.visualLine < measured.maxVisualLine) {
          current = (line: normalizedCurrent.line, visualLine: normalizedCurrent.visualLine + 1);
        } else {
          final nextLine = _lineProjection.adjacentVisibleModelLine(normalizedCurrent.line, forward: true);
          if (nextLine == null) break;
          current = (line: nextLine, visualLine: 0);
        }
      } else if (normalizedCurrent.visualLine > 0) {
        current = (line: normalizedCurrent.line, visualLine: normalizedCurrent.visualLine - 1);
      } else {
        final previousLine = _lineProjection.adjacentVisibleModelLine(normalizedCurrent.line, forward: false);
        if (previousLine == null) break;
        current = (line: previousLine, visualLine: widget.style.softWrap ? _maxVisualLineFor(previousLine) : 0);
      }
    }
    rows.add(activeMeasured.row);
    return rows;
  }

  ({EditableBoxSelectionRow row, int visualLine, int maxVisualLine}) _columnSelectionRowAt(
    ({int line, int visualLine}) position, {
    required double activeX,
    bool isActiveRow = false,
  }) {
    _debugLastColumnSelectionPainterQueryCount++;
    if (_scope.usesWindowedLineLayout(position.line)) {
      final anchor = _scope.docPositionInLine(position.line, Offset(_boxQueryAnchorX, 0));
      final active = _scope.docPositionInLine(position.line, Offset(activeX, 0));
      return (
        row: EditableBoxSelectionRow(anchor: anchor, active: active, isActiveRow: isActiveRow),
        visualLine: 0,
        maxVisualLine: 0,
      );
    }
    final painter = _scope.painterFor(position.line);
    final metrics = painter.computeLineMetrics();
    final maxVisualLine = metrics.isEmpty ? 0 : metrics.length - 1;
    final visualLine = position.visualLine.clamp(0, maxVisualLine);
    final y = metrics.isEmpty
        ? painter.preferredLineHeight / 2.0
        : metrics[visualLine].baseline - metrics[visualLine].ascent + metrics[visualLine].height / 2.0;
    final anchor = painter.getPositionForOffset(Offset(_boxQueryAnchorX, y));
    final active = painter.getPositionForOffset(Offset(activeX, y));
    final lineStart = _controller.document.lineStart(position.line);
    return (
      row: EditableBoxSelectionRow(
        anchor: TextPosition(offset: lineStart + anchor.offset, affinity: anchor.affinity),
        active: TextPosition(offset: lineStart + active.offset, affinity: active.affinity),
        isActiveRow: isActiveRow,
      ),
      visualLine: visualLine,
      maxVisualLine: maxVisualLine,
    );
  }

  int _maxVisualLineFor(int line) {
    if (_scope.usesWindowedLineLayout(line)) return 0;
    _debugLastColumnSelectionPainterQueryCount++;
    final metrics = _scope.painterFor(line).computeLineMetrics();
    return metrics.isEmpty ? 0 : metrics.length - 1;
  }

  ({int line, int visualLine}) _visualRowAt(TextPosition position) {
    final document = _controller.document;
    final line = document.lineIndexOf(position.offset);
    if (_scope.usesWindowedLineLayout(line)) return (line: line, visualLine: 0);
    final painter = _scope.painterFor(line);
    final metrics = painter.computeLineMetrics();
    if (metrics.length <= 1) return (line: line, visualLine: 0);
    final caret = _scope.caretRectInLine(line, position);
    final y = caret.center.dy;
    for (var visualLine = 0; visualLine < metrics.length; visualLine++) {
      final metric = metrics[visualLine];
      final top = metric.baseline - metric.ascent;
      if (y < top + metric.height || visualLine == metrics.length - 1) {
        return (line: line, visualLine: visualLine);
      }
    }
    return (line: line, visualLine: metrics.length - 1);
  }

  double? _textXAtGlobal(Offset global) {
    for (final line in _scope.mountedLines.values) {
      if (!line.attached || !line.hasSize) continue;
      try {
        return line.globalToLocal(global).dx;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static int _compareVisualRows(({int line, int visualLine}) left, ({int line, int visualLine}) right) {
    final line = left.line.compareTo(right.line);
    return line != 0 ? line : left.visualLine.compareTo(right.visualLine);
  }

  void _runSelectionGestureWrite(VoidCallback action) {
    _selectionGestureWriteDepth++;
    try {
      action();
    } finally {
      _selectionGestureWriteDepth--;
    }
  }

  // ===========================================================================
  // 拖选边缘自动滚动：指针越出编辑器边缘后**停住不动也持续滚动**并扩选
  // （ticker 驱动；速度∝越界深度²、封顶，对齐 selection 模块曲线法则）
  // ===========================================================================

  void _updateDragAutoScroll() {
    if (!_dragSelecting || _dragOvershoot() == Offset.zero) {
      _stopDragAutoScroll();
      return;
    }
    if (_dragScrollTicker == null) {
      _dragScrollLastTick = Duration.zero;
      _dragScrollTicker = Ticker(_onDragAutoScrollTick)..start();
    }
  }

  void _stopDragAutoScroll() {
    _dragScrollTicker?.dispose();
    _dragScrollTicker = null;
  }

  /// 指针相对编辑器边缘感应带的深度向量。
  Offset _dragOvershoot() {
    final editor = _editorBox;
    if (editor == null || !_dragAutoScrollActivated) return Offset.zero;
    final Offset pointer;
    try {
      pointer = editor.globalToLocal(_dragGlobal);
    } catch (_) {
      return Offset.zero;
    }
    final rect = Offset.zero & editor.size;
    final config = _activeAutoScrollConfig();
    return Offset(
      SelectionAutoScrollMath.edgeDepth(pointer.dx, rect.left, rect.right, config.beltExtent),
      // 单行输入的鼠标拖选与移动句柄都只能驱动水平滚动。
      _controller.singleLine
          ? 0.0
          : SelectionAutoScrollMath.edgeDepth(pointer.dy, rect.top, rect.bottom, config.beltExtent),
    );
  }

  void _onDragAutoScrollTick(Duration elapsed) {
    final overshoot = _dragOvershoot();
    if (!_dragSelecting || overshoot == Offset.zero) {
      _stopDragAutoScroll();
      return;
    }
    final dt = _dragScrollLastTick == Duration.zero
        ? 1 / 60.0
        : ((elapsed - _dragScrollLastTick).inMicroseconds / 1e6).clamp(0.0, 1 / 20.0);
    _dragScrollLastTick = elapsed;

    var scrolled = false;
    if (overshoot.dy != 0 && _scrollController.hasClients) {
      scrolled = _autoScrollAxis(_scrollController.position, overshoot.dy, dt) || scrolled;
    }
    // 双轴（nowrap）下水平边缘同样持续滚动
    if (overshoot.dx != 0 && !widget.style.softWrap && _horizontalController.hasClients) {
      scrolled = _autoScrollAxis(_horizontalController.position, overshoot.dx, dt) || scrolled;
    }
    if (_draggingSelectionHandle) {
      _selectionHandleControllerInstance!.syncEndpointToLastDragPosition(_dragGlobal);
    } else if (!_dragSelectionNeedsPaintSync) {
      _extendDragSelection();
    }
    _scheduleSelectionChromeGeometry();
    if (!scrolled) _stopDragAutoScroll();
  }

  bool _dragSelectionNeedsPaintSync = false;

  void _syncDragSelectionBeforePaint() {
    if (!_dragSelectionNeedsPaintSync) return;
    _dragSelectionNeedsPaintSync = false;
    if (!_dragSelecting || _draggingSelectionHandle || _controller.hasActiveImeComposition) {
      return;
    }
    if (_controller.updateSelectionBeforePaint(_extendDragSelection, _runSelectionGestureWrite)) {
      _scope.pumpFromController(beforePaint: true);
    }
  }

  bool _autoScrollAxis(ScrollPosition position, double overshoot, double dt, {SelectionAutoScrollConfig? config}) {
    final delta =
        SelectionAutoScrollMath.frameDelta(overshoot, config ?? _activeAutoScrollConfig()) *
        dt *
        SelectionAutoScrollMath.frameRate;
    final next = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (next == position.pixels) return false;
    position.jumpTo(next);
    return true;
  }

  SelectionAutoScrollConfig _activeAutoScrollConfig() {
    return _dragAutoScrollKind == _EditableAutoScrollKind.mouse
        ? _selectionControls.resolveMouseAutoScroll(context)
        : _selectionControls.resolveTouchAutoScroll(context);
  }

  /// 全局坐标 → 文档位置：固定行高直接投影目标行，其余布局二分命中已挂载行。
  ///
  /// 固定行距仅需一次行坐标变换；其余行高按挂载行做二分，避免逐行变换。
  @override
  TextPosition positionAtGlobal(Offset global) {
    final editor = _editorBox;
    final lines = _scope.mountedLines;
    final doc = _controller.document;
    TextPosition firstVisiblePosition() => TextPosition(offset: doc.lineStart(_lineProjection.firstVisibleModelLine));
    if (editor == null || lines.isEmpty) return firstVisiblePosition();
    final local = editor.globalToLocal(global);

    final mountedEntries = lines.entries.where(
      (entry) =>
          entry.key >= 0 &&
          entry.key < doc.lineCount &&
          _lineProjection.isVisibleModelLine(entry.key) &&
          entry.value.attached &&
          entry.value.hasSize,
    );
    if (mountedEntries.isEmpty) return firstVisiblePosition();

    Offset topLeftOf(RenderEditableLine line) => line.localToGlobal(Offset.zero, ancestor: editor);

    final fixedExtent = _fixedLogicalLineExtent;
    if (fixedExtent != null) {
      // 自动滚动先更新 offset、后挂载新行；用任一旧行的实时变换还原目标行，
      // 避免选区被上一帧的挂载窗口截断。行距须与虚拟列表的物理像素吸附一致。
      final reference = mountedEntries.first;
      final topLeft = topLeftOf(reference.value);
      final height = snapVirtualItemExtentToPixelGrid(
        fixedExtent,
        MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio,
      );
      final referenceRow = _lineProjection.viewRowForModelLine(reference.key)!;
      final row = (referenceRow + ((local.dy - topLeft.dy) / height).floor()).clamp(
        0,
        _lineProjection.visibleLineCount - 1,
      );
      final top = topLeft.dy + (row - referenceRow) * height;
      return _scope.docPositionInLine(
        _lineProjection.modelLineForViewRow(row),
        Offset(local.dx - topLeft.dx, (local.dy - top).clamp(0.0, math.max(height - 0.1, 0.0))),
      );
    }

    final entries = mountedEntries.toList()..sort((a, b) => a.key.compareTo(b.key));
    // 二分找第一条 bottom > local.dy 的行；命中带即它，落在带外（上方 / 行间
    // 缝）时它与上一条行必有一条最近。
    var lo = 0;
    var hi = entries.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final line = entries[mid].value;
      if (topLeftOf(line).dy + line.size.height <= local.dy) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    var bestIndex = entries[lo].key;
    var best = entries[lo].value;
    var bestTopLeft = topLeftOf(best);
    if (local.dy < bestTopLeft.dy && lo > 0) {
      final prev = entries[lo - 1].value;
      final prevTopLeft = topLeftOf(prev);
      if (local.dy - (prevTopLeft.dy + prev.size.height) < bestTopLeft.dy - local.dy) {
        bestIndex = entries[lo - 1].key;
        best = prev;
        bestTopLeft = prevTopLeft;
      }
    }

    // 字符拖选越出挂载窗口须包含边界行；不能把屏外 y 压回该行再按 x 截断。
    final characterDrag = _dragSelecting && _dragSelectionGranularity == .character;
    if (characterDrag && (local.dy < 0 || local.dy > editor.size.height)) {
      if (local.dy < bestTopLeft.dy) return TextPosition(offset: doc.lineStart(bestIndex));
      if (local.dy >= bestTopLeft.dy + best.size.height) {
        return TextPosition(offset: math.min(doc.length, doc.lineEnd(bestIndex) + 1));
      }
    }
    final inLine = Offset(
      local.dx - bestTopLeft.dx,
      (local.dy - bestTopLeft.dy).clamp(0.0, math.max(best.size.height - 0.1, 0.0)),
    );
    final localPos = best.positionForOffset(inLine);
    if (bestIndex >= doc.lineCount) return TextPosition(offset: doc.length);
    return TextPosition(offset: doc.lineStart(bestIndex) + localPos.offset, affinity: localPos.affinity);
  }

  bool _executeAction(InputAction action) => _keys.executeAction(action);

  // ===========================================================================
  // 选区 Chrome：controller 是唯一选区真源，这里只投影几何与动作。
  // ===========================================================================

  bool get _interactiveSelectionEnabled =>
      !_selectionTextBlocked && !widget.style.readOnly && widget.style.enableInteractiveSelection;

  SelectionControls _resolveSelectionControls() => widget.style.selectionControls ?? SelectionControlsScope.of(context);

  SelectionActions _selectionActions() {
    final selections = _controller.selections;
    final hasSelection = selections.all.any((selection) => !selection.isCollapsed);
    final custom = widget.selectionActions?.call();
    final hasClipboardContent = hasSelection;
    final documentLength = _controller.document.length;
    final interactive = _interactiveSelectionEnabled;
    return SelectionActions(
      cut: custom?.cut ?? _cutSelection,
      copy: custom?.copy ?? _copySelection,
      paste: custom?.paste ?? _pasteSelection,
      selectAll: custom?.selectAll ?? _selectAllSelection,
      canCut:
          interactive && (custom?.canCut ?? hasClipboardContent) && !widget.style.readOnly && !widget.style.obscureText,
      canCopy: interactive && (custom?.canCopy ?? hasClipboardContent) && !widget.style.obscureText,
      canPaste: interactive && (custom?.canPaste ?? true) && !widget.style.readOnly,
      canSelectAll:
          interactive &&
          (custom?.canSelectAll ??
              (!selections.single || selections.primary.start > 0 || selections.primary.end < documentLength)),
    );
  }

  void _refreshSelectionActions() {
    if (!mounted) return;
    final actions = _selectionToolbarActionsInstance;
    if (actions != null) actions.value = _selectionActions();
  }

  void _copySelection() {
    if (_interactiveSelectionEnabled && !widget.style.obscureText) {
      _runClipboardOperation(_ops.copy(), 'copy');
    }
  }

  void _cutSelection() {
    if (_interactiveSelectionEnabled && !widget.style.obscureText) {
      _runClipboardOperation(_ops.cut(), 'cut');
    }
  }

  void _pasteSelection() {
    if (_interactiveSelectionEnabled) {
      _runClipboardOperation(_ops.paste(), 'paste');
    }
  }

  void _selectAllSelection() {
    if (_interactiveSelectionEnabled) _ops.selectAll();
  }

  void _beginSelectionHandleDrag(
    SelectionHandleSide side,
    Offset globalPosition, {
    int? pointer,
    PointerDeviceKind? kind,
  }) {
    if (!_interactiveSelectionEnabled) return;
    final selection = _controller.selection;
    if (selection.isCollapsed) return;
    _selectionMenuEntry?.close();
    _handleFixedOffset = side == SelectionHandleSide.start ? selection.end : selection.start;
    _handleMovingOffset = side == SelectionHandleSide.start ? selection.start : selection.end;
    _handleMovingSide = side;
    _handleMovingAffinity = selection.extentOffset == _handleMovingOffset
        ? selection.affinity
        : (side == SelectionHandleSide.end ? TextAffinity.upstream : TextAffinity.downstream);
    _handleAffinityHistory
      ..clear()
      ..[_handleMovingOffset!] = _handleMovingAffinity;
    _handleInitialOffset = _handleMovingOffset;
    _handleDragStartGlobal = globalPosition;
    _dragAutoScrollKind = _EditableAutoScrollKind.handle;
    _dragAutoScrollOrigin = globalPosition;
    _dragAutoScrollActivated = false;
    _dragSelecting = true;
    _draggingSelectionHandle = true;
    _dragGlobal = globalPosition;
    final type = _selectionHandleType(side);
    _selectionControls.onHandleDragStart(type, kind ?? PointerDeviceKind.touch);
    _selectionHandleController.begin(side, globalPosition, pointer: pointer);
  }

  void _endSelectionHandleDrag() => _selectionHandleControllerInstance?.end();

  bool _setSelectionHandleEndpoint(SelectionHandleSide side, Offset globalPosition) {
    if (!_interactiveSelectionEnabled) return false;
    final fixed = _handleFixedOffset;
    final moving = _handleMovingOffset;
    if (fixed == null || moving == null) return false;
    final hit = positionAtGlobal(globalPosition);
    var next = hit.offset.clamp(0, _controller.document.length);
    var affinity = hit.affinity;
    if (next == fixed) {
      next = moving < fixed ? _ops.previousGraphemeBoundary(fixed) : _ops.nextGraphemeBoundary(fixed);
      affinity = next < fixed ? TextAffinity.downstream : TextAffinity.upstream;
    }
    if (next == fixed || (next == moving && affinity == _handleMovingAffinity)) return false;
    _handleMovingOffset = next;
    _handleMovingSide = next < fixed ? SelectionHandleSide.start : SelectionHandleSide.end;
    _handleMovingAffinity = affinity;
    _rememberHandleAffinity(next, affinity);
    _runSelectionGestureWrite(
      () => _controller.setSelection(TextSelection(baseOffset: fixed, extentOffset: next, affinity: affinity)),
    );
    _selectionControls.onHandleSelectionChanged(_selectionHandleType(_handleMovingSide!));
    return true;
  }

  void _setSelectionHandleOffset(SelectionHandleSide side, int offset) {
    if (!_interactiveSelectionEnabled) return;
    final fixed = _handleFixedOffset;
    final moving = _handleMovingOffset;
    if (fixed == null || moving == null) return;
    var next = offset.clamp(0, _controller.document.length);
    if (next == fixed) {
      next = moving < fixed ? _ops.previousGraphemeBoundary(fixed) : _ops.nextGraphemeBoundary(fixed);
    }
    if (next == fixed) return;
    _handleMovingOffset = next;
    _handleMovingSide = next < fixed ? SelectionHandleSide.start : SelectionHandleSide.end;
    _handleMovingAffinity = _handleAffinityHistory[next] ?? _handleMovingAffinity;
    _runSelectionGestureWrite(
      () => _controller.setSelection(
        TextSelection(baseOffset: fixed, extentOffset: next, affinity: _handleMovingAffinity),
      ),
    );
  }

  int? _selectionHandleOffset(SelectionHandleSide side) => _handleMovingOffset;

  TextSelectionHandleType _selectionHandleType(SelectionHandleSide side) {
    final endpoint = side == SelectionHandleSide.start
        ? _selectionEndpoints.value?.start
        : _selectionEndpoints.value?.end;
    final direction = endpoint?.textDirection ?? _scope.config.textDirection;
    final pointsLeft = direction == TextDirection.rtl
        ? side != SelectionHandleSide.start
        : side == SelectionHandleSide.start;
    return pointsLeft ? TextSelectionHandleType.left : TextSelectionHandleType.right;
  }

  ({Offset globalBottom, double lineHeight, double idealVerticalOffset, double touchOffsetY})? _selectionHandleAnchor(
    SelectionHandleSide side,
  ) {
    final logicalSide = _handleMovingSide ?? side;
    final endpoint = logicalSide == SelectionHandleSide.start
        ? _selectionEndpoints.value?.start
        : _selectionEndpoints.value?.end;
    if (endpoint == null || !endpoint.visible) return null;
    final type = _selectionHandleType(logicalSide);
    return (
      globalBottom: endpoint.globalBottom,
      lineHeight: endpoint.lineHeight,
      idealVerticalOffset: _selectionControls.resolveHandleIdealVerticalOffset(type, endpoint.lineHeight),
      touchOffsetY: _selectionControls.resolveHandleTouchOffsetY(type, endpoint.lineHeight),
    );
  }

  void _handleSelectionDragInfoChanged() {
    final raw = _selectionHandleControllerInstance?.dragInfo;
    if (raw == null) {
      if (_draggingSelectionHandle) {
        final side = _handleMovingSide;
        if (side != null) _selectionControls.onHandleDragEnd(_selectionHandleType(side));
      }
      _dragSelecting = false;
      _resetDragSelectionGranularity();
      _draggingSelectionHandle = false;
      _handleFixedOffset = null;
      _handleMovingOffset = null;
      _handleMovingSide = null;
      _handleAffinityHistory.clear();
      _handleInitialOffset = null;
      _handleDragStartGlobal = null;
      _dragAutoScrollActivated = false;
      _stopDragAutoScroll();
      _selectionDragInfo.value = null;
      _scheduleSelectionChromeGeometry();
      return;
    }
    _selectionDragInfo.value = SelectionDragInfo(
      kind: raw.kind,
      side: _handleMovingSide ?? raw.side,
      globalPosition: raw.globalPosition,
    );
    _scheduleSelectionChromeGeometry();
  }

  void _rememberHandleAffinity(int offset, TextAffinity affinity) {
    _handleAffinityHistory.remove(offset);
    _handleAffinityHistory[offset] = affinity;
    while (_handleAffinityHistory.length > 16) {
      final oldest = _handleAffinityHistory.keys.firstWhere(
        (candidate) => candidate != _handleInitialOffset,
        orElse: () => _handleAffinityHistory.keys.first,
      );
      _handleAffinityHistory.remove(oldest);
    }
  }

  void _updateHandleAutoScroll(Offset globalPosition) {
    if (!_interactiveSelectionEnabled) return;
    _dragGlobal = globalPosition;
    _dragSelecting = true;
    _draggingSelectionHandle = true;
    final start = _handleDragStartGlobal;
    if (start != null && (globalPosition - start).distance > 1.0) {
      _dragAutoScrollActivated = true;
    }
    _updateDragAutoScroll();
  }

  void _stopHandleAutoScroll() {
    _dragSelecting = false;
    _resetDragSelectionGranularity();
    _stopDragAutoScroll();
  }

  void _markSelectionScrollActive() {
    _selectionScrollIdleTimer?.cancel();
    if (!_selectionScrollActivity.value) _selectionScrollActivity.value = true;
    _selectionScrollIdleTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _selectionScrollActivity.value) _selectionScrollActivity.value = false;
    });
  }

  void _scheduleSelectionChromeGeometry() {
    if (_selectionGeometryScheduled) return;
    _selectionGeometryScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _selectionGeometryScheduled = false;
      if (mounted) _updateSelectionChromeGeometry();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _handlePaintGeometryChanged() {
    if (!mounted) return;
    _scheduleFloatingCursorReproject();
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      if (_caretMotionNeedsGeometry) _syncCaretMotionGeometry();
      // 宿主布局/变换可独立于文本变化完成，候选窗不能等下一次输入才更新全局锚点。
      _pushImeGeometry();
      _publishCurrentCaretGeometry();
    } else {
      _scheduleFrameSync();
      _scheduleCaretGeometryUpdate();
    }
    if (!_selectionUsesMobileChrome) return;
    _updateSelectionChromeGeometry();
  }

  void _updateSelectionChromeGeometry() {
    assert(() {
      _debugSelectionGeometryUpdateCount++;
      return true;
    }());
    if (!_interactiveSelectionEnabled) {
      _publishSelectionEndpoints(null);
      return;
    }
    final editor = _editorBox;
    final selection = _controller.selection;
    final fullyHidden =
        !selection.isCollapsed &&
        _lineProjection.hiddenAreas?.isEmpty == false &&
        !_lineProjection.rangeHasVisibleContent(TextRange(start: selection.start, end: selection.end));
    if (!_focused || !_selectionUsesMobileChrome || editor == null || selection.isCollapsed || fullyHidden) {
      _publishSelectionEndpoints(null);
      return;
    }
    try {
      final transform = editor.getTransformTo(null);
      if (transform.invert() != 0.0) _selectionChromeGlobalToLocalTransform = transform;
    } catch (_) {
      // 转场帧保留上一份与端点同源的逆矩阵。
    }
    final visibleRect = _editorVisibleGlobalRect(editor);
    final fallbackLineHeight = (_scope.config.textStyle.fontSize ?? 14) * (_scope.config.textStyle.height ?? 1.0);
    final start = _selectionEndpoint(
      side: SelectionHandleSide.start,
      offset: selection.start,
      oppositeOffset: selection.end,
      preferUpstream: false,
      visibleRect: visibleRect,
      fallbackLineHeight: fallbackLineHeight,
    );
    final end = _selectionEndpoint(
      side: SelectionHandleSide.end,
      offset: selection.end,
      oppositeOffset: selection.start,
      preferUpstream: true,
      visibleRect: visibleRect,
      fallbackLineHeight: fallbackLineHeight,
    );
    _publishSelectionEndpoints(
      SelectionEndpointsInfo(start: start, end: end, devicePixelRatio: View.maybeOf(context)?.devicePixelRatio ?? 1.0),
    );
  }

  SelectionHandleEndpoint _selectionEndpoint({
    required SelectionHandleSide side,
    required int offset,
    required int oppositeOffset,
    required bool preferUpstream,
    required Rect visibleRect,
    required double fallbackLineHeight,
  }) {
    final position = _selectionEndpointGeometryPosition(
      offset: offset,
      oppositeOffset: oppositeOffset,
      preferUpstream: preferUpstream,
    );
    final geometry = _caretGeometryForSelection(position);
    if (geometry == null) {
      final editor = _editorBox!;
      final editorRect = MatrixUtils.transformRect(editor.getTransformTo(null), Offset.zero & editor.size);
      final position = side == SelectionHandleSide.start ? editorRect.topLeft : editorRect.bottomRight;
      return SelectionHandleEndpoint(
        side: side,
        globalPosition: position,
        lineHeight: fallbackLineHeight,
        visible: false,
        textDirection: _scope.config.textDirection,
      );
    }
    final globalRect = geometry.globalRect;
    return SelectionHandleEndpoint(
      side: side,
      globalPosition: globalRect.topLeft,
      lineHeight: geometry.localRect.height,
      visible: visibleRect.overlaps(globalRect.inflate(0.5)),
      textDirection: _selectionEndpointTextDirection(
        geometry,
        side: side,
        offset: position.offset,
        preferUpstream: position.affinity == TextAffinity.upstream,
      ),
    );
  }

  TextPosition _selectionEndpointGeometryPosition({
    required int offset,
    required int oppositeOffset,
    required bool preferUpstream,
  }) {
    final raw = TextPosition(
      offset: offset,
      affinity: preferUpstream ? TextAffinity.upstream : TextAffinity.downstream,
    );
    return _canonicalizeVisibleCaretPosition(
      _lineProjection.projectSelectionEndpointForGeometry(raw, oppositeEndpoint: TextPosition(offset: oppositeOffset)),
    );
  }

  ({RenderEditableLine render, int line, Rect localRect, Rect globalRect})? _caretGeometryForSelection(
    TextPosition position,
  ) {
    final document = _controller.document;
    var line = document.lineIndexOf(math.max(0, position.offset));
    if (position.affinity == TextAffinity.upstream && line > 0 && position.offset == document.lineStart(line)) {
      line = _lineProjection.adjacentVisibleModelLine(line, forward: false) ?? line;
      position = TextPosition(offset: document.lineEnd(line), affinity: TextAffinity.upstream);
    }
    final render = _scope.mountedLineAt(line);
    if (render == null || !render.attached || !render.hasSize) return null;
    final localRect = _scope.caretRectInLine(line, position);
    final globalRect = MatrixUtils.transformRect(render.getTransformTo(null), localRect);
    return (render: render, line: line, localRect: localRect, globalRect: globalRect);
  }

  TextDirection _selectionEndpointTextDirection(
    ({RenderEditableLine render, int line, Rect localRect, Rect globalRect}) geometry, {
    required SelectionHandleSide side,
    required int offset,
    required bool preferUpstream,
  }) {
    final painter = geometry.render.layoutedPainter;
    final windowed = _scope.usesWindowedLineLayout(geometry.line);
    if (painter == null && !windowed) return _scope.config.textDirection;
    final document = _controller.document;
    final revision = _controller.docRevision;
    final configRevision = _scope.configRevision;
    final projectionRevision = _lineProjection.mappingRevision;
    if (_endpointDirectionCacheRevision != revision ||
        _endpointDirectionCacheConfigRevision != configRevision ||
        _endpointDirectionCacheProjectionRevision != projectionRevision) {
      _endpointDirectionCacheRevision = revision;
      _endpointDirectionCacheConfigRevision = configRevision;
      _endpointDirectionCacheProjectionRevision = projectionRevision;
      _endpointDirectionCache.clear();
    }
    final lineStart = document.lineStart(geometry.line);
    final lineEnd = document.lineEnd(geometry.line);
    final localOffset = (offset - lineStart).clamp(0, lineEnd - lineStart);
    // 普通 bidi 接缝按选区内侧取相邻 TextBox（start 向后、end 向前）；
    // soft-wrap 同 offset 对应两条视觉行，只有这种接缝才由 endpoint affinity
    // 决定采样哪一侧。
    var directionPrefersUpstream = side == SelectionHandleSide.end;
    if (painter != null) {
      final upstreamLine = painter.getLineBoundary(TextPosition(offset: localOffset, affinity: TextAffinity.upstream));
      final downstreamLine = painter.getLineBoundary(
        TextPosition(offset: localOffset, affinity: TextAffinity.downstream),
      );
      if (upstreamLine != downstreamLine) directionPrefersUpstream = preferUpstream;
    }
    final key = (offset: offset, preferUpstream: directionPrefersUpstream, line: geometry.line);
    final cached = _endpointDirectionCache[key];
    if (cached != null) {
      _endpointDirectionCache
        ..remove(key)
        ..[key] = cached;
      return cached;
    }
    final edge = offset.clamp(lineStart, lineEnd);
    var fromDocument = directionPrefersUpstream ? _ops.previousGraphemeBoundary(edge) : edge;
    var toDocument = directionPrefersUpstream ? edge : _ops.nextGraphemeBoundary(edge);
    var from = (fromDocument - lineStart).clamp(0, lineEnd - lineStart);
    var to = (toDocument - lineStart).clamp(0, lineEnd - lineStart);
    // EOF/BOF 或空视觉侧：先选侧无字符时对称回退到 caret 另一侧，避免
    // RTL run 在文档边界错误退回段落基向。
    if (from == to && directionPrefersUpstream && edge < lineEnd) {
      fromDocument = edge;
      toDocument = _ops.nextGraphemeBoundary(edge);
      from = (fromDocument - lineStart).clamp(0, lineEnd - lineStart);
      to = (toDocument - lineStart).clamp(0, lineEnd - lineStart);
    } else if (from == to && !directionPrefersUpstream && edge > lineStart) {
      toDocument = edge;
      fromDocument = _ops.previousGraphemeBoundary(edge);
      from = (fromDocument - lineStart).clamp(0, lineEnd - lineStart);
      to = (toDocument - lineStart).clamp(0, lineEnd - lineStart);
    }
    if (from == to) {
      return _cacheEndpointDirection(key, _scope.config.textDirection);
    }
    if (from > to) {
      final swap = from;
      from = to;
      to = swap;
    }
    final boxes = painter != null
        ? painter.getBoxesForSelection(TextSelection(baseOffset: from, extentOffset: to))
        : geometry.render.selectionBoxesForLineRange(from, to);
    if (boxes.isEmpty) {
      return _cacheEndpointDirection(key, _scope.config.textDirection);
    }
    final caret = geometry.localRect;
    var best = boxes.first;
    var bestDistance = double.infinity;
    for (final box in boxes) {
      final rect = box.toRect();
      final verticalDistance = caret.center.dy < rect.top
          ? rect.top - caret.center.dy
          : (caret.center.dy > rect.bottom ? caret.center.dy - rect.bottom : 0.0);
      final horizontalDistance = math.min((rect.left - caret.center.dx).abs(), (rect.right - caret.center.dx).abs());
      final distance = verticalDistance * 10000 + horizontalDistance;
      if (distance < bestDistance) {
        best = box;
        bestDistance = distance;
      }
    }
    return _cacheEndpointDirection(key, best.direction);
  }

  TextDirection _cacheEndpointDirection(({int offset, bool preferUpstream, int line}) key, TextDirection direction) {
    _endpointDirectionCache
      ..remove(key)
      ..[key] = direction;
    while (_endpointDirectionCache.length > _endpointDirectionCacheCapacity) {
      _endpointDirectionCache.remove(_endpointDirectionCache.keys.first);
    }
    return direction;
  }

  Rect _editorVisibleGlobalRect(RenderBox editor) {
    var visible = MatrixUtils.transformRect(editor.getTransformTo(null), Offset.zero & editor.size);
    RenderObject child = editor;
    RenderObject? parent = editor.parent;
    while (parent != null) {
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        try {
          visible = visible.intersect(MatrixUtils.transformRect(parent.getTransformTo(null), clip));
        } catch (_) {
          return visible;
        }
        if (visible.isEmpty) return Rect.zero;
      }
      child = parent;
      parent = parent.parent;
    }
    return visible;
  }

  SelectionMagnifierFocus? _selectionMagnifierLineGeometry() {
    final selection = _controller.selection;
    final movingSide = _handleMovingSide;
    final offset = _handleMovingOffset ?? selection.extentOffset;
    final preferUpstream = movingSide != null
        ? movingSide == SelectionHandleSide.end
        : selection.extentOffset > selection.baseOffset;
    final oppositeOffset = _handleFixedOffset ?? selection.baseOffset;
    final position = _selectionEndpointGeometryPosition(
      offset: offset,
      oppositeOffset: oppositeOffset,
      preferUpstream: preferUpstream,
    );
    final geometry = _caretGeometryForSelection(position);
    if (geometry == null) return null;
    final painter = geometry.render.layoutedPainter;
    var visualLineRect = _scope.usesWindowedLineLayout(geometry.line)
        ? Rect.fromLTWH(
            _scope.horizontalPixels,
            geometry.localRect.top,
            _scope.viewportWidth,
            geometry.localRect.height,
          )
        : Rect.fromLTWH(0, geometry.localRect.top, geometry.render.size.width, geometry.localRect.height);
    if (painter != null) {
      for (final metric in painter.computeLineMetrics()) {
        final top = metric.baseline - metric.ascent;
        final rect = Rect.fromLTWH(metric.left, top, math.max(metric.width, 1.0), metric.height);
        if (geometry.localRect.center.dy >= rect.top && geometry.localRect.center.dy <= rect.bottom) {
          visualLineRect = rect;
          break;
        }
      }
    }
    final globalLine = MatrixUtils.transformRect(geometry.render.getTransformTo(null), visualLineRect);
    return (
      caretX: geometry.globalRect.center.dx,
      line: SelectionLineGeometry(
        lineTop: globalLine.top,
        lineHeight: globalLine.height,
        lineLeft: globalLine.left,
        lineRight: globalLine.right,
      ),
    );
  }

  void _publishSelectionEndpoints(SelectionEndpointsInfo? value) {
    if (_selectionEndpoints.value != value) _selectionEndpoints.value = value;
    final visible = value != null && (_showSelectionHandles || _showSelectionMagnifier || _showSelectionToolbar);
    if (_selectionChromeVisible == visible) return;
    _selectionChromeVisible = visible;
    if (_selectionChromeVisibility.value != visible) _selectionChromeVisibility.value = visible;
  }

  Offset _selectionChromeGlobalToLocal(Offset global) {
    const pad = Offset(selectionChromeOverflowPad, selectionChromeOverflowPad);
    final transform = _selectionChromeGlobalToLocalTransform;
    return (transform == null ? global : MatrixUtils.transformPoint(transform, global)) + pad;
  }

  void _cancelSelectionChromeInteractions({bool closeMenu = true, bool clearMobileIntent = true}) {
    if (closeMenu) {
      _selectionMenuEntry?.close();
      _selectionMenuEntry = null;
    }
    _secondaryTapGlobal = null;
    if (_longPressFloatingCursor) _cancelFloatingCursor();
    _stopLongPressPointerRoute();
    _longPressFloatingCursor = false;
    _longPressFloatingOrigin = Offset.zero;
    if (_draggingSelectionHandle) {
      final side = _handleMovingSide;
      if (side != null) _selectionControls.onHandleDragEnd(_selectionHandleType(side));
    }
    _selectionHandleControllerInstance?.detach();
    _handleFixedOffset = null;
    _handleMovingOffset = null;
    _handleMovingSide = null;
    _handleAffinityHistory.clear();
    _handleInitialOffset = null;
    _handleDragStartGlobal = null;
    _dragSelecting = false;
    _resetDragSelectionGranularity();
    _draggingSelectionHandle = false;
    _dragAutoScrollActivated = false;
    _stopDragAutoScroll();
    _selectionScrollIdleTimer?.cancel();
    _selectionScrollIdleTimer = null;
    _selectionChromeGlobalToLocalTransform = null;
    _endpointDirectionCache.clear();
    if (_selectionDragInfo.value != null) _selectionDragInfo.value = null;
    if (_selectionScrollActivity.value) _selectionScrollActivity.value = false;
    if (_selectionEndpoints.value != null) _selectionEndpoints.value = null;
    _selectionChromeVisible = false;
    if (clearMobileIntent) _selectionUsesMobileChrome = false;
    if (_selectionChromeVisibility.value) _selectionChromeVisibility.value = false;
  }

  /// 测试探针：端点 bidi 方向的有界 LRU 当前条目数。
  @visibleForTesting
  int get debugSelectionEndpointDirectionCacheLength => _endpointDirectionCache.length;

  /// 测试探针：handle affinity 回滚小环当前条目数。
  @visibleForTesting
  int get debugSelectionHandleAffinityHistoryLength => _handleAffinityHistory.length;

  /// 测试探针：最近一次列选生成阶段查询排版器的次数。
  @visibleForTesting
  int get debugLastColumnSelectionPainterQueryCount => _debugLastColumnSelectionPainterQueryCount;

  /// 测试探针：当前可绘制的移动端 selection handle 数量。
  @visibleForTesting
  int get debugVisibleSelectionHandleCount {
    final endpoints = _selectionEndpoints.value;
    if (endpoints == null) return 0;
    return (endpoints.start.visible ? 1 : 0) + (endpoints.end.visible ? 1 : 0);
  }

  /// 测试探针：逻辑 start/end endpoint 的全局 caret 顶点。
  @visibleForTesting
  List<Offset> get debugSelectionEndpointGlobalPositions {
    final endpoints = _selectionEndpoints.value;
    return endpoints == null
        ? const <Offset>[]
        : <Offset>[endpoints.start.globalPosition, endpoints.end.globalPosition];
  }

  /// 测试探针：selection chrome 几何发布路径累计执行次数。
  @visibleForTesting
  int get debugSelectionGeometryUpdateCount => _debugSelectionGeometryUpdateCount;

  /// 测试探针：caretGeometry 真实发布次数（相同 Rect 不计）。
  @visibleForTesting
  int get debugCaretGeometryPublishCount => _debugCaretGeometryPublishCount;

  /// 测试探针：onStateChanged 真实发布次数（失效 pending 不计）。
  @visibleForTesting
  int get debugStateCallbackPublishCount => _debugStateCallbackPublishCount;

  /// 测试探针：编辑器正文当前全局 paint 矩形。
  @visibleForTesting
  Rect? get debugSelectionEditorGlobalRect {
    final editor = _editorBox;
    return editor == null ? null : MatrixUtils.transformRect(editor.getTransformTo(null), Offset.zero & editor.size);
  }

  /// 测试探针：编辑器正文与全部祖先 clip 求交后的全局可见矩形。
  @visibleForTesting
  Rect? get debugSelectionEditorVisibleGlobalRect {
    final editor = _editorBox;
    return editor == null ? null : _editorVisibleGlobalRect(editor);
  }

  /// 测试探针：正文祖先链声明的全局近似 clip 矩形。
  @visibleForTesting
  List<Rect> get debugSelectionAncestorGlobalClips {
    final editor = _editorBox;
    if (editor == null) return const <Rect>[];
    final result = <Rect>[];
    RenderObject child = editor;
    RenderObject? parent = editor.parent;
    while (parent != null) {
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) result.add(MatrixUtils.transformRect(parent.getTransformTo(null), clip));
      child = parent;
      parent = parent.parent;
    }
    return result;
  }

  /// 测试探针：当前 caret 所属真实滚动 viewport 在 editor 本地坐标中的矩形。
  @visibleForTesting
  Rect? get debugCaretScrollViewportRectInEditor {
    final editor = _editorBox;
    return editor == null ? null : _caretScrollViewportRectInEditor(editor);
  }

  // ===========================================================================
  // caret 可见性 / IME 几何（post-frame 合并）
  // ===========================================================================

  void _scheduleFrameSync({bool ensureVisible = false}) {
    // 拖选由边缘 ticker 控制滚动；帧末再追赶屏外选区端点会越过刚布局的窗口。
    if (ensureVisible && !_dragSelecting && _focused && !widget.style.readOnly && !_tearingDownPipeline) {
      _automaticCaretRevealIntent = _captureAutomaticCaretRevealIntent();
    }
    if (_framePending) return;
    _framePending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _framePending = false;
      if (!mounted) return;
      final automatic = _automaticCaretRevealIntent;
      _automaticCaretRevealIntent = null;
      if (automatic != null &&
          !_dragSelecting &&
          _focused &&
          !widget.style.readOnly &&
          _automaticCaretRevealMatchesCurrent(automatic)) {
        ensureCaretVisible();
      }
      _syncTextViewportWidth();
      _syncImeStyle();
      _pushImeGeometry();
      _publishCurrentCaretGeometry();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _scheduleStateAttached() {
    final callback = widget.onStateChanged;
    final epoch = ++_stateCallbackEpoch;
    if (callback == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_elementActive || epoch != _stateCallbackEpoch) return;
      if (!identical(widget.onStateChanged, callback)) return;
      if (identical(_notifiedStateCallback, callback)) return;
      _notifiedStateCallback = callback;
      assert(() {
        _debugStateCallbackPublishCount++;
        return true;
      }());
      callback(this);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _scheduleStateDetached(ValueChanged<EditableViewport?>? callback) {
    _stateCallbackEpoch++;
    if (callback == null || !identical(_notifiedStateCallback, callback)) return;
    if (identical(_pendingStateDetachCallback, callback)) return;
    _pendingStateDetachCallback = callback;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!identical(_pendingStateDetachCallback, callback)) return;
      _pendingStateDetachCallback = null;
      if (!identical(_notifiedStateCallback, callback)) return;
      _notifiedStateCallback = null;
      assert(() {
        _debugStateCallbackPublishCount++;
        return true;
      }());
      callback(null);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _requestCaretMotionFromVisualChange({required bool geometryReady, bool documentChanged = false}) {
    if (widget.style.readOnly) {
      _cancelCaretMotion(resetAnchor: true);
      return;
    }
    final primary = _controller.selections.primary;
    final position = _selectionActivePositionForGeometry(primary);
    final previous = _caretMotionPosition;
    if (previous == null) {
      _caretMotionPosition = position;
      return;
    }
    if (previous == position) return;
    // 文档内容/结构变化（输入、删除、撤销、粘贴、样式重排）时光标立即落位，
    // 不启动位置动画；动画只服务于纯导航与指针移动，避免持续删除时
    // 每个字符都触发一次 80ms 缓动造成光标拖尾延迟。
    if (documentChanged) {
      _cancelCaretMotion();
      _caretMotionPosition = position;
      _caretMotionTarget = null;
      return;
    }

    final from = _caretMotionRect.value ?? _caretMotionTarget;
    _caretMotionPosition = position;
    if (!_canAnimateCaretMotion(from, primary)) {
      _cancelCaretMotion();
      _caretMotionPosition = position;
      _caretMotionTarget = null;
      return;
    }

    _caretMotionController?.stop();
    _caretMotionFrom = from;
    _caretMotionTarget = null;
    _pendingCaretMotion = (position: position, from: from!);
    _scope.pump(primaryCaretMotionActive: true);
    if (_caretMotionRect.value != from) _caretMotionRect.value = from;
    if (geometryReady) {
      final target = caretRectInEditor();
      if (target != null && target.isFinite && !target.isEmpty) {
        _startCaretMotion(from, target, position);
      }
    }
  }

  bool _canAnimateCaretMotion(Rect? from, EditableSelection primary) {
    return from != null &&
        from.isFinite &&
        !from.isEmpty &&
        widget.style.caretAnimationDuration.inMicroseconds > 0 &&
        _caretAnimationsEnabled &&
        _elementActive &&
        !widget.style.readOnly &&
        _focused &&
        !_floatingCursorState.isActive &&
        _scope.dragDropCaret == null &&
        !_dragSelecting &&
        !_draggingSelectionHandle &&
        _selectionGestureWriteDepth == 0 &&
        _longPressPointer == null &&
        !_controller.hasActiveImeComposition &&
        !(primary.isCollapsed && _controller.overwriteMode);
  }

  void _syncCaretMotionGeometry() {
    final primary = _controller.selections.primary;
    final position = _selectionActivePositionForGeometry(primary);
    final target = caretRectInEditor();
    if (widget.style.readOnly || !_focused || target == null || !target.isFinite || target.isEmpty) {
      _cancelCaretMotion();
      _caretMotionPosition = position;
      _caretMotionTarget = null;
      return;
    }

    final pending = _pendingCaretMotion;
    if (pending != null) {
      if (pending.position == position && _canAnimateCaretMotion(pending.from, primary)) {
        _startCaretMotion(pending.from, target, position);
        return;
      }
      _cancelCaretMotion();
    } else if (_caretMotionController?.isAnimating ?? false) {
      if (_caretMotionPosition == position) {
        _caretMotionTarget = target;
        return;
      }
      _cancelCaretMotion();
    }

    _caretMotionPosition = position;
    _caretMotionTarget = target;
  }

  void _startCaretMotion(Rect from, Rect target, TextPosition position) {
    _pendingCaretMotion = null;
    _caretMotionPosition = position;
    _caretMotionTarget = target;
    if (_sameCaretMotionRect(from, target)) {
      _finishCaretMotion();
      return;
    }

    final controller = _caretMotionController ??=
        AnimationController(vsync: this, duration: widget.style.caretAnimationDuration)
          ..addListener(_tickCaretMotion)
          ..addStatusListener(_handleCaretMotionStatus);
    controller
      ..duration = widget.style.caretAnimationDuration
      ..stop();
    _caretMotionFrom = from;
    _scope.pump(primaryCaretMotionActive: true);
    if (_caretMotionRect.value != from) _caretMotionRect.value = from;
    controller.forward(from: 0);
  }

  void _tickCaretMotion() {
    final controller = _caretMotionController;
    final from = _caretMotionFrom;
    final target = _caretMotionTarget;
    if (controller == null || from == null || target == null) return;
    final progress = Curves.ease.transform(controller.value);
    final rect = Rect.lerp(from, target, progress)!;
    if (_caretMotionRect.value != rect) _caretMotionRect.value = rect;
  }

  void _handleCaretMotionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finishCaretMotion();
  }

  void _finishCaretMotion() {
    _pendingCaretMotion = null;
    _caretMotionFrom = null;
    _scope.pump(primaryCaretMotionActive: false);
    if (_caretMotionRect.value != null) _caretMotionRect.value = null;
  }

  void _cancelCaretMotion({bool resetAnchor = false}) {
    _caretMotionController?.stop();
    _pendingCaretMotion = null;
    _caretMotionFrom = null;
    if (_scope.primaryCaretMotionActive) _scope.pump(primaryCaretMotionActive: false);
    if (_caretMotionRect.value != null) _caretMotionRect.value = null;
    if (resetAnchor) {
      _caretMotionPosition = null;
      _caretMotionTarget = null;
    }
  }

  static bool _sameCaretMotionRect(Rect left, Rect right) =>
      (left.left - right.left).abs() <= 1e-6 &&
      (left.top - right.top).abs() <= 1e-6 &&
      (left.width - right.width).abs() <= 1e-6 &&
      (left.height - right.height).abs() <= 1e-6;

  void _scheduleCaretGeometryUpdate() {
    if (_caretGeometryNotifier == null && !_caretMotionNeedsGeometry) return;
    if (_caretGeometryScheduled) return;
    _caretGeometryScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _caretGeometryScheduled = false;
      if (_caretGeometryDisposed) return;
      if (!mounted || !_elementActive || _tearingDownPipeline) {
        _publishCaretGeometry(null);
        _disposeCaretGeometryIfRequested();
        return;
      }
      if (_caretMotionNeedsGeometry) _syncCaretMotionGeometry();
      _publishCurrentCaretGeometry();
      _disposeCaretGeometryIfRequested();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _scheduleCaretGeometryDispose() {
    if (_caretGeometryDisposed) return;
    if (_caretGeometryNotifier == null) {
      _caretGeometryDisposed = true;
      return;
    }
    _caretGeometryDisposeAfterNull = true;
    _scheduleCaretGeometryUpdate();
  }

  void _disposeCaretGeometryIfRequested() {
    if (!_caretGeometryDisposeAfterNull || _caretGeometryDisposed) return;
    _caretGeometryDisposeAfterNull = false;
    _caretGeometryDisposed = true;
    _caretGeometryNotifier?.dispose();
  }

  void _publishCaretGeometry(Rect? value) {
    final notifier = _caretGeometryNotifier;
    if (_caretGeometryDisposed || notifier == null || notifier.value == value) return;
    assert(() {
      _debugCaretGeometryPublishCount++;
      return true;
    }());
    notifier.value = value;
  }

  bool get _caretMotionNeedsGeometry => _elementActive && !widget.style.readOnly && _focused;

  void _publishCurrentCaretGeometry() {
    if (_caretGeometryNotifier == null) return;
    _publishCaretGeometry(caretRectGlobal());
  }

  /// caret 矩形（编辑器本地坐标）；caret 行未 mounted 返回 null。覆写模式的
  /// 折叠主光标返回下一完整字素的 block 几何，IME composing 期间恢复细光标。
  @override
  Rect? caretRectInEditor() {
    final selection = _controller.selections.primary;
    final keepAnchor = _selectAllCaretDisplayAnchor(selection);
    if (keepAnchor != null) return _rectAtOffset(keepAnchor, affinity: .downstream, overwrite: false);
    final position = _selectionActivePositionForGeometry(selection);
    return _rectAtOffset(
      position.offset,
      affinity: position.affinity,
      overwrite: selection.isCollapsed && _controller.overwriteMode && !_controller.hasActiveImeComposition,
    );
  }

  /// `selectAllRevealsCaret=false` 且 primary 为全文档选区时返回全选前的
  /// 光标位置（显示锚点）；否则返回 null，caret 走常规 active 端渲染。
  int? _selectAllCaretDisplayAnchor(EditableSelection selection) {
    if (widget.style.selectAllRevealsCaret || widget.style.readOnly) return null;
    final anchor = _controller.selectAllCaretDisplayOffset;
    if (anchor == null) return null;
    if (!selection.isCollapsed && selection.anchor == 0 && selection.active >= _controller.document.length) {
      return anchor;
    }
    return null;
  }

  TextPosition _selectionActivePositionForGeometry(EditableSelection selection) {
    final active = TextPosition(offset: selection.active, affinity: selection.affinity);
    if (selection.isCollapsed) {
      return _canonicalizeVisibleCaretPosition(
        _lineProjection.projectCollapsedPosition(active, bias: EditablePositionProjectionBias.backward),
      );
    }
    final position = _canonicalizeVisibleCaretPosition(
      _lineProjection.projectSelectionEndpointForGeometry(
        active,
        oppositeEndpoint: TextPosition(offset: selection.anchor),
      ),
    );
    // 含换行的选区以 upstream 停在上一行尾；动画、IME 与 reveal 必须和静态 caret 使用同一落点。
    if (position.affinity == TextAffinity.upstream && position.offset > 0) {
      final document = _controller.document;
      final line = document.lineIndexOf(position.offset);
      if (line > 0 && document.lineStart(line) == position.offset) {
        return TextPosition(offset: position.offset - 1, affinity: position.affinity);
      }
    }
    return position;
  }

  TextPosition _canonicalizeVisibleCaretPosition(TextPosition position) {
    return _lineProjection.canonicalizeVisibleCaretPosition(position);
  }

  /// caret 矩形（全局 paint 坐标）；补全弹层 / 悬浮工具条定位用。
  ///
  /// caret 行未物化、视图未挂载，或祖先 paint 变换不可逆 / 非有限时返回 null。
  @override
  Rect? caretRectGlobal() {
    if (!mounted) return null;
    final editor = _editorBox;
    final rect = caretRectInEditor();
    if (editor == null || !editor.attached || rect == null) return null;
    try {
      final transform = editor.getTransformTo(null);
      for (final value in transform.storage) {
        if (!value.isFinite) return null;
      }
      if (Matrix4.tryInvert(transform) == null) return null;
      final global = MatrixUtils.transformRect(transform, rect);
      return global.isFinite ? global : null;
    } catch (_) {
      // RenderObject 正在换绑 / 卸载时，公开几何门面只报告暂不可用。
      return null;
    }
  }

  /// 任意 doc offset 的 caret 矩形（编辑器本地坐标）；所在行未 mounted 返回
  /// null（先等待 [revealCaret] 或按 index 定位再查）。
  @override
  Rect? rectAtOffset(int offset, {TextAffinity affinity = TextAffinity.downstream}) =>
      _rectAtOffset(offset, affinity: affinity, overwrite: false);

  /// 返回文档 UTF-16 [range] 当前已挂载可见片段的编辑器本地矩形。
  ///
  /// soft-wrap、双向文本、Tab 与长行窗口均复用真实行 painter；未挂载或被
  /// [EditableLineMask] 隐藏的行不会返回估算几何。collapsed 范围默认
  /// 返回细 caret；[collapsedAsCharacterCell] 为 true 时返回与 collapsed 行前景
  /// 原语完全一致的最小字符单元，便于上层精确命中诊断悬浮内容。
  @override
  List<Rect> rectsForRangeInEditor(TextRange range, {bool collapsedAsCharacterCell = false}) {
    if (!mounted) return const <Rect>[];
    final document = _controller.document;
    if (!range.isValid || range.start > range.end || range.end > document.length) {
      throw ArgumentError.value(range, 'range', '必须满足 0 <= start <= end <= document.length');
    }
    if (range.isCollapsed) {
      if (collapsedAsCharacterCell) {
        final editor = _editorBox;
        if (editor == null || !editor.attached) return const <Rect>[];
        final line = document.lineIndexOf(range.start);
        final render = _scope.mountedLineAt(line);
        if (render == null || !render.attached || !render.hasSize) {
          return const <Rect>[];
        }
        final lineStart = document.lineStart(line);
        final localRect = render.collapsedCharacterCellRectFor(TextPosition(offset: range.start - lineStart));
        Matrix4 transform;
        try {
          transform = render.getTransformTo(editor);
        } catch (_) {
          return const <Rect>[];
        }
        if (transform.storage.any((value) => !value.isFinite) || Matrix4.tryInvert(transform) == null) {
          return const <Rect>[];
        }
        final rect = MatrixUtils.transformRect(transform, localRect);
        return rect.isFinite && !rect.isEmpty ? List<Rect>.unmodifiable(<Rect>[rect]) : const <Rect>[];
      }
      final rect = _rectAtOffset(range.start, affinity: TextAffinity.downstream, overwrite: false);
      return rect == null ? const <Rect>[] : <Rect>[rect];
    }
    final editor = _editorBox;
    if (editor == null || !editor.attached) return const <Rect>[];
    final firstLine = document.lineIndexOf(range.start);
    final lastLine = document.lineIndexOf(range.end - 1);
    final mountedEntries =
        _scope.mountedLines.entries
            .where(
              (entry) => entry.key >= firstLine && entry.key <= lastLine && entry.value.attached && entry.value.hasSize,
            )
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));
    final result = <Rect>[];
    for (final entry in mountedEntries) {
      final line = entry.key;
      final render = entry.value;
      final lineStart = document.lineStart(line);
      final lineLength = document.lineLength(line);
      final start = (range.start - lineStart).clamp(0, lineLength);
      final end = (range.end - lineStart).clamp(0, lineLength);
      if (start >= end) continue;
      Matrix4 transform;
      try {
        transform = render.getTransformTo(editor);
      } catch (_) {
        continue;
      }
      if (transform.storage.any((value) => !value.isFinite) || Matrix4.tryInvert(transform) == null) {
        continue;
      }
      for (final box in render.selectionBoxesForLineRange(start, end)) {
        final rect = MatrixUtils.transformRect(transform, box.toRect());
        if (rect.isFinite && !rect.isEmpty) result.add(rect);
      }
    }
    return List<Rect>.unmodifiable(result);
  }

  /// 返回文档 UTF-16 [range] 当前已挂载可见片段的全局 paint 矩形。
  ///
  /// [collapsedAsCharacterCell] 与 [rectsForRangeInEditor] 保持相同口径。
  @override
  List<Rect> rectsForRangeGlobal(TextRange range, {bool collapsedAsCharacterCell = false}) {
    if (!mounted) return const <Rect>[];
    final editor = _editorBox;
    if (editor == null || !editor.attached) return const <Rect>[];
    final local = rectsForRangeInEditor(range, collapsedAsCharacterCell: collapsedAsCharacterCell);
    if (local.isEmpty) return const <Rect>[];
    Matrix4 transform;
    try {
      transform = editor.getTransformTo(null);
    } catch (_) {
      return const <Rect>[];
    }
    if (transform.storage.any((value) => !value.isFinite) || Matrix4.tryInvert(transform) == null) {
      return const <Rect>[];
    }
    final result = <Rect>[];
    for (final rect in local) {
      final transformed = MatrixUtils.transformRect(transform, rect);
      if (transformed.isFinite) result.add(transformed);
    }
    return List<Rect>.unmodifiable(result);
  }

  Rect? _rectAtOffset(int offset, {required TextAffinity affinity, required bool overwrite}) {
    final editor = _editorBox;
    if (editor == null) return null;
    final doc = _controller.document;
    // 不用 `offset.clamp(0, doc.length)`：doc.length 强制全量重建行首索引
    // （大文档每键 O(尾部行数)）；lineIndexOf 自身增量补索引且越界 offset
    // 落到末行，钳制语义等价。
    final line = doc.lineIndexOf(math.max(0, offset));
    final render = _scope.mountedLineAt(line);
    if (render == null || !render.attached || !render.hasSize) return null;
    final rect = _scope.caretRectInLine(
      line,
      TextPosition(offset: offset, affinity: affinity),
      overwrite: overwrite,
    );
    return rect.shift(render.localToGlobal(Offset.zero, ancestor: editor));
  }

  /// 滚动使 caret 进入视口；远行先按 index 粗定位，再用真实 caret 几何双轴精调。
  ///
  /// 这是保留给既有调用方的 fire-and-forget 门面；需要确认收敛或取消时等待
  /// [revealCaret]。
  void ensureCaretVisible() => unawaited(revealCaret());

  /// 滚动使当前 caret 进入视口，并等待虚拟远跳与真实几何精调结束。
  ///
  /// 返回 true 表示当前请求的 caret 已在双轴视口内收敛；返回 false 表示请求被
  /// 更新的 caret、controller / 滚动控制器换绑、文档结构变化、失焦、卸载或
  /// 有限帧内无法收敛所取消。同一目标的自动 reveal 会复用本 Future，不会反向
  /// 取消显式等待者。
  @override
  Future<bool> revealCaret() {
    if (!mounted || !_elementActive || _tearingDownPipeline) {
      return Future<bool>.value(false);
    }
    final primary = _controller.selections.primary;
    if (primary.isCollapsed) {
      final projected = _selectionActivePositionForGeometry(primary);
      if (projected.offset != primary.active || projected.affinity != primary.affinity) {
        _scheduleLineProjectionSelectionRepair();
        return _revealCaretAfterProjectionRepair(
          controller: _controller,
          projection: _lineProjection,
          projectionRevision: _lineProjection.mappingRevision,
          documentVersion: _controller.documentVersion,
        );
      }
    }
    _cancelLineProjectionAnchorRestore();
    // 显式请求覆盖同目标的待发自动意图；显式调用允许在失焦时工作。
    _automaticCaretRevealIntent = null;
    final active = _activeCaretReveal;
    if (active != null && _caretRevealTargetMatchesCurrent(active)) {
      return active.completion.future;
    }
    _cancelCaretReveal();
    final request = _CaretRevealRequest(
      epoch: _caretRevealEpoch,
      projection: _lineProjection,
      projectionRevision: _lineProjection.mappingRevision,
      controller: _controller,
      scrollController: _scrollController,
      horizontalController: _horizontalControllerForCurrentMode,
      docRevision: _controller.docRevision,
      selections: _controller.selections,
      softWrap: widget.style.softWrap,
      completion: Completer<bool>(),
    );
    _activeCaretReveal = request;
    final future = request.completion.future;
    try {
      _startCaretReveal(request);
    } catch (_) {
      _completeCaretReveal(request, completed: false);
    }
    return future;
  }

  Future<bool> _revealCaretAfterProjectionRepair({
    required EditableController controller,
    required EditableLineProjection projection,
    required int projectionRevision,
    required DocumentVersion documentVersion,
  }) {
    final completion = Completer<bool>();

    void attempt(int remaining) {
      scheduleMicrotask(() {
        if (completion.isCompleted) return;
        if (!mounted ||
            !_elementActive ||
            _tearingDownPipeline ||
            !identical(controller, _controller) ||
            !identical(projection, _lineProjection) ||
            projection.mappingRevision != projectionRevision ||
            controller.documentVersion != documentVersion) {
          completion.complete(false);
          return;
        }
        final primary = controller.selections.primary;
        final projected = _selectionActivePositionForGeometry(primary);
        if (primary.isCollapsed && (projected.offset != primary.active || projected.affinity != primary.affinity)) {
          if (remaining <= 0) {
            completion.complete(false);
            return;
          }
          _scheduleLineProjectionSelectionRepair();
          attempt(remaining - 1);
          return;
        }
        unawaited(
          revealCaret().then<void>(
            (completed) {
              if (!completion.isCompleted) completion.complete(completed);
            },
            onError: (Object _, StackTrace _) {
              if (!completion.isCompleted) completion.complete(false);
            },
          ),
        );
      });
    }

    attempt(4);
    return completion.future;
  }

  void _startCaretReveal(_CaretRevealRequest request) {
    if (!_isCaretRevealCurrent(request)) {
      _completeCaretReveal(request, completed: false);
      return;
    }
    final geometryPosition = _selectionActivePositionForGeometry(request.controller.selections.primary);
    final line = request.controller.document.lineIndexOf(geometryPosition.offset);
    final viewRow = _lineProjection.viewRowForModelLine(line);
    if (viewRow == null) {
      _completeCaretReveal(request, completed: false);
      return;
    }
    final requiredClientsReady =
        request.scrollController.hasClients && (request.softWrap || request.horizontalController?.hasClients == true);
    final viewModelReady = _selectionGeometryDocRevision == request.docRevision && viewRow < _visibleLineCount;
    if (_editorBox == null || !requiredClientsReady || !viewModelReady) {
      _scheduleCaretRevealStart(request);
      return;
    }
    if (caretRectInEditor() != null) {
      // 即使当前几何看似可见，也至少跨一帧确认；祖先本帧可能正待 layout。
      _scheduleCaretRevealRefinement(request, 0);
      return;
    }
    if (request.coarsePositioning) return;
    if (request.coarseAttempts >= _caretRevealMaxStartAttempts) {
      _completeCaretReveal(request, completed: false);
      return;
    }
    request.coarseAttempts++;
    request.coarsePositioning = true;
    late final Future<bool> positioning;
    try {
      positioning = _rowJump.jumpToIndex(viewRow, alignment: 0.5);
    } catch (_) {
      request.coarsePositioning = false;
      _completeCaretReveal(request, completed: false);
      return;
    }
    unawaited(
      positioning.then<void>(
        (completed) {
          request.coarsePositioning = false;
          if (!_isCaretRevealCurrent(request)) {
            _completeCaretReveal(request, completed: false);
          } else if (!completed) {
            // mapping change 同帧创建的新请求可能先撞上旧 Sliver 快照；这不是
            // 目标无效，下一帧用同一 projection token 重新进入 coarse 阶段。
            _scheduleCaretRevealStart(request);
          } else {
            _scheduleCaretRevealRefinement(request, 0);
          }
        },
        onError: (Object _, StackTrace _) {
          request.coarsePositioning = false;
          _completeCaretReveal(request, completed: false);
        },
      ),
    );
  }

  void _scheduleCaretRevealStart(_CaretRevealRequest request) {
    if (!_isCaretRevealCurrent(request) || request.startAttempts >= _caretRevealMaxStartAttempts) {
      _completeCaretReveal(request, completed: false);
      return;
    }
    request.startAttempts++;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_isCaretRevealCurrent(request)) {
        _completeCaretReveal(request, completed: false);
        return;
      }
      try {
        _startCaretReveal(request);
      } catch (_) {
        _completeCaretReveal(request, completed: false);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool _caretRevealTargetMatchesCurrent(_CaretRevealRequest request) {
    return mounted &&
        _elementActive &&
        identical(request.projection, _lineProjection) &&
        request.projection.mappingRevision == request.projectionRevision &&
        identical(request.controller, _controller) &&
        identical(request.scrollController, _scrollController) &&
        identical(request.horizontalController, _horizontalControllerForCurrentMode) &&
        request.docRevision == _controller.docRevision &&
        request.selections == _controller.selections &&
        request.softWrap == widget.style.softWrap;
  }

  _AutomaticCaretRevealIntent _captureAutomaticCaretRevealIntent() => _AutomaticCaretRevealIntent(
    epoch: _caretRevealEpoch,
    controller: _controller,
    scrollController: _scrollController,
    horizontalController: _horizontalControllerForCurrentMode,
    docRevision: _controller.docRevision,
    selections: _controller.selections,
    softWrap: widget.style.softWrap,
  );

  bool _automaticCaretRevealMatchesCurrent(_AutomaticCaretRevealIntent intent) =>
      mounted &&
      _elementActive &&
      !_tearingDownPipeline &&
      intent.epoch == _caretRevealEpoch &&
      identical(intent.controller, _controller) &&
      identical(intent.scrollController, _scrollController) &&
      identical(intent.horizontalController, _horizontalControllerForCurrentMode) &&
      intent.docRevision == _controller.docRevision &&
      intent.selections == _controller.selections &&
      intent.softWrap == widget.style.softWrap;

  bool _isCaretRevealCurrent(_CaretRevealRequest request) =>
      identical(_activeCaretReveal, request) &&
      request.epoch == _caretRevealEpoch &&
      _caretRevealTargetMatchesCurrent(request);

  void _cancelCaretReveal() {
    _caretRevealEpoch++;
    _automaticCaretRevealIntent = null;
    final active = _activeCaretReveal;
    _activeCaretReveal = null;
    if (active == null) return;
    if (active.coarsePositioning) {
      active.coarsePositioning = false;
      _rowJump.cancel();
    }
    if (!active.completion.isCompleted) active.completion.complete(false);
  }

  void _completeCaretReveal(_CaretRevealRequest request, {required bool completed}) {
    if (identical(_activeCaretReveal, request)) _activeCaretReveal = null;
    if (!request.completion.isCompleted) request.completion.complete(completed);
  }

  void _scheduleCaretRevealRefinement(_CaretRevealRequest request, int refinement) {
    if (!_isCaretRevealCurrent(request) || refinement >= _caretRevealMaxRefinements) {
      _completeCaretReveal(request, completed: false);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_isCaretRevealCurrent(request)) {
        _refineCaretReveal(request, refinement);
      } else {
        _completeCaretReveal(request, completed: false);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _refineCaretReveal(_CaretRevealRequest request, int refinement) {
    if (!_isCaretRevealCurrent(request)) {
      _completeCaretReveal(request, completed: false);
      return;
    }
    final activePosition = _selectionActivePositionForGeometry(_controller.selections.primary);
    final activeLine = _controller.document.lineIndexOf(activePosition.offset);
    final longLineGeometryPending = _scope.longLineCaretGeometryPendingFor(activeLine, activePosition);
    final editor = _editorBox;
    final rect = caretRectInEditor();
    final requiredClientsReady =
        request.scrollController.hasClients && (request.softWrap || request.horizontalController?.hasClients == true);
    if (editor == null || !requiredClientsReady) {
      request.stableGeometry = null;
      _scheduleCaretRevealRefinement(request, refinement + 1);
      return;
    }
    if (rect == null) {
      request.stableGeometry = null;
      // resize / 虚拟窗口换代可能让原本 mounted 的 caret 在 refinement 中途
      // 离窗；必须重返 coarse 阶段，不能只空等剩余帧。
      _startCaretReveal(request);
      return;
    }
    final viewport = _caretScrollViewportRectInEditor(editor);
    if (viewport == null) {
      request.stableGeometry = null;
      _scheduleCaretRevealRefinement(request, refinement + 1);
      return;
    }
    final revealViewport = _caretRevealViewport(viewport, rect);

    var needsAnotherFrame = false;
    final verticalPosition = request.scrollController.position;
    if (request.controller.singleLine) {
      // 单行输入没有纵向文档可显隐。fallback 字体或非整数 DPR 产生的剩余
      // extent 只能留在起点，否则一次选区/IME 更新就会永久吃掉顶部 padding。
      final target = verticalPosition.minScrollExtent;
      if ((target - verticalPosition.pixels).abs() > _caretRevealTolerance) {
        verticalPosition.jumpTo(target);
        needsAnotherFrame = true;
      }
    } else {
      final verticalDelta = rect.top < revealViewport.top
          ? rect.top - revealViewport.top
          : rect.bottom > revealViewport.bottom
          ? rect.bottom - revealViewport.bottom
          : 0.0;
      if (verticalDelta.abs() > _caretRevealTolerance) {
        final target = (verticalPosition.pixels + verticalDelta)
            .clamp(verticalPosition.minScrollExtent, verticalPosition.maxScrollExtent)
            .toDouble();
        if ((target - verticalPosition.pixels).abs() > _caretRevealTolerance) verticalPosition.jumpTo(target);
        needsAnotherFrame = true;
      }
    }
    ScrollPosition? horizontalPosition;
    if (!request.softWrap) {
      horizontalPosition = request.horizontalController!.position;
      final delta = rect.left < revealViewport.left
          ? rect.left - revealViewport.left
          : rect.right > revealViewport.right
          ? rect.right - revealViewport.right
          : 0.0;
      if (delta.abs() > _caretRevealTolerance) {
        final target = (horizontalPosition.pixels + delta)
            .clamp(horizontalPosition.minScrollExtent, horizontalPosition.maxScrollExtent)
            .toDouble();
        if ((target - horizontalPosition.pixels).abs() > _caretRevealTolerance) {
          horizontalPosition.jumpTo(target);
        }
        // 横向 content extent 可能在本次行 layout 后才经 listenable 进入滚动
        // snapshot；即便当前被旧 max 钳住，也要给下一帧一次收敛机会。
        needsAnotherFrame = true;
      }
    }
    _pushImeGeometry();
    if (longLineGeometryPending) {
      request.stableGeometry = null;
      final progressToken = _scope.longLineCaretGeometryProgressTokenFor(activeLine);
      if (request.pendingGeometryProgressToken == progressToken) {
        request.pendingGeometryStallFrames++;
      } else {
        request.pendingGeometryProgressToken = progressToken;
        request.pendingGeometryStallFrames = 0;
      }
      if (request.pendingGeometryStallFrames >= _caretRevealMaxPendingGeometryStallFrames) {
        _completeCaretReveal(request, completed: false);
        return;
      }
      // 后台 Bidi / 全局测宽尚未完成并不是滚动几何不收敛；先按当前估值把
      // 目标窗口滚进来，再独立等待精确全局坐标，不能卡在旧视口空等，也不能
      // 消耗普通 refinement 配额。只有连续无任何流水线进展才累计 watchdog。
      _scheduleCaretRevealRefinement(request, refinement);
      return;
    }
    if (needsAnotherFrame) {
      request.stableGeometry = null;
      _scheduleCaretRevealRefinement(request, refinement + 1);
    } else {
      final geometry = (
        caret: rect,
        viewport: viewport,
        verticalPixels: verticalPosition.pixels,
        horizontalPixels: horizontalPosition?.pixels ?? 0.0,
      );
      final previous = request.stableGeometry;
      if (previous != null && _caretRevealGeometryStable(previous, geometry)) {
        _completeCaretReveal(request, completed: true);
      } else {
        request.stableGeometry = geometry;
        _scheduleCaretRevealRefinement(request, refinement + 1);
      }
    }
  }

  Rect? _caretScrollViewportRectInEditor(RenderBox editor) {
    final position = _selectionActivePositionForGeometry(_controller.selections.primary);
    return _scrollViewportRectInEditorForOffset(editor, position.offset);
  }

  Rect? _scrollViewportRectInEditorForOffset(RenderBox editor, int offset) {
    final document = _controller.document;
    final line = document.lineIndexOf(math.max(0, offset));
    final render = _scope.mountedLineAt(line);
    if (render == null || !render.attached || !render.hasSize) return null;
    // 不换行时纵向视口铺满整段内容宽度，可见区是编辑器内各层滚动视口的交集。
    Rect? visible;
    try {
      for (RenderObject? node = render.parent; node != null && !identical(node, editor); node = node.parent) {
        if (node is! RenderAbstractViewport || node is! RenderBox) continue;
        final box = node as RenderBox;
        if (!box.attached || !box.hasSize) return null;
        final bounds = box is ScrollViewport ? box.contentViewportRect : Offset.zero & box.size;
        final rect = MatrixUtils.transformRect(box.getTransformTo(editor), bounds);
        visible = visible == null ? rect : visible.intersect(rect);
      }
    } catch (_) {
      return null;
    }
    return visible != null && visible.isFinite && !visible.isEmpty ? visible : null;
  }

  bool _caretRevealGeometryStable(
    ({Rect caret, Rect viewport, double verticalPixels, double horizontalPixels}) previous,
    ({Rect caret, Rect viewport, double verticalPixels, double horizontalPixels}) current,
  ) =>
      _rectNear(previous.caret, current.caret) &&
      _rectNear(previous.viewport, current.viewport) &&
      (previous.verticalPixels - current.verticalPixels).abs() <= _caretRevealTolerance &&
      (previous.horizontalPixels - current.horizontalPixels).abs() <= _caretRevealTolerance;

  bool _rectNear(Rect left, Rect right) =>
      (left.left - right.left).abs() <= _caretRevealTolerance &&
      (left.top - right.top).abs() <= _caretRevealTolerance &&
      (left.right - right.right).abs() <= _caretRevealTolerance &&
      (left.bottom - right.bottom).abs() <= _caretRevealTolerance;

  void _pushImeGeometry() {
    final ime = _imeInstance;
    if (ime?.attached != true) return;
    final editor = _editorBox;
    if (editor == null) return;
    final composing = _controller.composing;
    final caretRect = _imeCaretRectInEditor();
    final windows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    // 空闲期 composing rect 兜底锚到 caret（官方恒有兜底矩形的口径）：组合
    // 永远从光标开始，预先摆对引擎缓存锚点，候选窗首显不跳旧位（Windows
    // 候选窗定位锚点是 composing rect 而非 caret rect）
    ime!.updateGeometry(
      size: editor.size,
      transform: editor.getTransformTo(null),
      caretRect: caretRect,
      composingRect: windows ? caretRect : _imeComposingRectInEditor(composing) ?? caretRect,
      composingAnchorRect: windows && composing.isValid
          ? _imeRectInViewport(
              _rectAtOffset(composing.start, affinity: TextAffinity.downstream, overwrite: false),
              composing.start,
            )
          : null,
      composingEndRect: windows && composing.isValid
          ? _imeRectInViewport(
              _rectAtOffset(composing.end, affinity: TextAffinity.upstream, overwrite: false),
              composing.end,
            )
          : null,
      layoutVersion: windows
          ? (
              _scope.configRevision,
              _scope.systemFontsRevision,
              _scope.longLineWindowRevision,
              _scope.viewportWidth,
              _lineProjection.mappingRevision,
            )
          : null,
      resolveComposingPosition: windows ? _imeComposingPositionRect : null,
    );
  }

  Rect? _imeComposingPositionRect(int offset) {
    final range = _controller.composing;
    final editor = _editorBox;
    if (editor == null || !range.isValid || offset <= 0 || offset >= range.end - range.start) return null;
    final document = _controller.document;
    final position = range.start + offset;
    final line = document.lineIndexOf(position);
    final render = _scope.mountedLineAt(line);
    if (render == null || !render.attached || !render.hasSize) return null;
    final local = TextPosition(offset: position - document.lineStart(line), affinity: .downstream);
    final window = render.layoutWindow;
    // 查询仅借用已显示的 Paragraph；禁止为 IME 中间位置触发共享测量或远端长行估算。
    if (window == null) {
      if (render.layoutedPainter == null) return null;
    } else if (render.windowPainter == null || !window.containsPosition(local)) {
      return null;
    }
    return _imeRectInViewport(
      MatrixUtils.transformRect(render.getTransformTo(editor), render.caretRectFor(local)),
      position,
    );
  }

  Rect? _imeRectInViewport(Rect? rect, int offset) {
    final editor = _editorBox;
    if (rect == null || editor == null) return null;
    final viewport = _scrollViewportRectInEditorForOffset(editor, offset) ?? _caretScrollViewportRectInEditor(editor);
    if (viewport == null) return rect;
    final visible = _caretRevealViewport(viewport.intersect(Offset.zero & editor.size), rect);
    if (visible.isEmpty) return null;
    // 全选保留横滚位置时，替换起点可远在屏外；IME 只能锚到可见正文边界。
    final left = rect.left.clamp(visible.left, math.max(visible.left, visible.right - rect.width));
    final top = rect.top.clamp(visible.top, math.max(visible.top, visible.bottom - rect.height));
    return rect.shift(Offset(left - rect.left, top - rect.top));
  }

  Rect? _imeCaretRectInEditor() {
    final selection = _controller.selection;
    // 对齐 Flutter EditableText：无论选区创建方向如何，下一次文本输入都会替换
    // selection.start，候选窗也必须锚到这一端而不是 active/extent。
    final rect = _rectAtOffset(selection.start, affinity: TextAffinity.downstream, overwrite: false);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _imeRectInViewport(rect ?? (selection.isCollapsed ? null : caretRectInEditor()), selection.start);
    }
    return rect;
  }

  Rect? _imeComposingRectInEditor(TextRange range) {
    if (!range.isValid || range.isCollapsed) return null;
    final editor = _editorBox;
    if (editor == null) return null;
    final document = _controller.document;
    final start = range.start.clamp(0, document.length);
    final end = range.end.clamp(start, document.length);
    if (start >= end) return null;
    final firstLine = document.lineIndexOf(start);
    final lastLine = document.lineIndexOf(math.max(start, end - 1));
    final selection = TextSelection(baseOffset: start, extentOffset: end);
    Rect? result;
    for (final entry in _scope.mountedLines.entries) {
      if (entry.key < firstLine || entry.key > lastLine) continue;
      final render = entry.value;
      if (!render.attached || !render.hasSize) continue;
      Matrix4 transform;
      try {
        transform = render.getTransformTo(editor);
      } catch (_) {
        continue;
      }
      for (final box in _scope.selectionBoxesInLine(entry.key, selection)) {
        final rect = MatrixUtils.transformRect(transform, box.toRect());
        if (!rect.isFinite || rect.isEmpty) continue;
        result = result?.expandToInclude(rect) ?? rect;
      }
    }
    // 未挂载、纯换行或窗口暂不可用时跟官方一样回退到 composing 起点。
    return result ?? _rectAtOffset(start, affinity: TextAffinity.downstream, overwrite: false);
  }

  // ===========================================================================
  // build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.style.readOnly;
    // 只读态不允许编辑区请求焦点；节点可能由调用方持有，按只读状态同步可请求位。
    _focusNode.canRequestFocus = !readOnly;
    final interactiveSelectionEnabled = _interactiveSelectionEnabled;
    _bindInheritedPaint();
    final renderConfig = _buildConfig();
    final renderConfigChanged = _appliedRenderConfig != null && _appliedRenderConfig != renderConfig;
    _appliedRenderConfig = renderConfig;
    _scope.pump(
      config: renderConfig,
      focused: _focused && !readOnly,
      selectionVisible: !_selectionTextBlocked && (_focused || widget.style.retainSelectionOnBlur),
      // 只通过这里同步会话级 caret 可见性开关（floating cursor / DnD 等会话
      // 已各自在别的开关临时接管，这里只负责关闭编辑态总闸后重新下发）。
      regularCaretVisible: readOnly ? false : null,
      primaryCaretMotionActive: readOnly ? false : null,
      paintEditingState: !readOnly,
      keepCaretAtPreSelectAllPosition: !widget.style.selectAllRevealsCaret && !readOnly,
    );
    final fixedLogicalLineExtent =
        renderConfig.lineHeightMode == EditableLineHeightMode.fixed && !renderConfig.softWrap;
    final fixedLineHeight = fixedLogicalLineExtent ? _scope.fixedLineHeight : null;
    _fixedLogicalLineExtent = fixedLineHeight;
    final lines = SliverPadding(
      padding: widget.style.contentPadding,
      sliver: ElSliverRecyclerList(
        controller: _rowJump,
        itemCount: _visibleLineCount,
        itemBuilder: (context, row) {
          final line = ValueListenableBuilder<int>(
            valueListenable: row,
            builder: (context, viewRow, _) => _buildLine(context, viewRow),
          );
          // 不换行时 Sliver 按整段内容宽度紧约束行；行需要不受限宽度，才能按自身文本宽度开窗和对齐视口。
          return widget.style.softWrap
              ? line
              : OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  fit: OverflowBoxFit.deferToChild,
                  child: line,
                );
        },
      ),
    );
    if (renderConfigChanged && _imeInstance?.attached == true) _scheduleFrameSync();
    _scheduleCaretGeometryUpdate();
    if (readOnly) {
      _showSelectionHandles = false;
      _showSelectionMagnifier = false;
      _showSelectionToolbar = false;
    } else {
      final resolvedControls = _resolveSelectionControls();
      if (_selectionControlsResolved && !identical(resolvedControls, _selectionControls)) {
        final preserveMobileIntent = _selectionUsesMobileChrome;
        _cancelSelectionChromeInteractions(clearMobileIntent: false);
        _selectionUsesMobileChrome = preserveMobileIntent;
        _scheduleSelectionChromeGeometry();
      }
      _selectionControls = resolvedControls;
      _selectionControlsResolved = true;
      _showSelectionHandles =
          interactiveSelectionEnabled &&
          !kIsWeb &&
          widget.style.enabledSelectionHandles &&
          _selectionControls.resolveShowHandles(context);
      _showSelectionMagnifier =
          interactiveSelectionEnabled &&
          !kIsWeb &&
          widget.style.enabledMagnifier &&
          _selectionControls.resolveShowMagnifier(context);
      _showSelectionToolbar =
          interactiveSelectionEnabled &&
          !kIsWeb &&
          widget.style.enabledSelectionToolbar &&
          _selectionControls.resolveShowToolbar(context);
      if (_selectionUsesMobileChrome) _scheduleSelectionChromeGeometry();
    }
    final dualAxis = !widget.style.softWrap;
    // 编辑态自带选区，岛内起手由编辑器接管；只读态关闭岛，让外层文档选区
    // 从任意方向正常穿过正文。
    final content = Builder(
      builder: (context) => EditableCaretMotionOverlay(
        rect: _caretMotionRect,
        caretColor: renderConfig.caretColor,
        scope: _scope,
        child: EditableFloatingCursorOverlay(
          frame: _floatingCursorFrame,
          caretColor: renderConfig.caretColor,
          scope: _scope,
          child: SelectionChromePortal(
            visible: _selectionChromeVisible,
            visibilityListenable: _selectionChromeVisibility,
            fallbackGlobalToLocal: _selectionChromeGlobalToLocal,
            chromeBuilder: _buildSelectionChrome,
            content: _EditableSelectionPaintGeometryObserver(
              onGeometryChanged: _handlePaintGeometryChanged,
              onViewportWidthChanged: _handleViewportWidthChanged,
              onViewportMetricsChanged: _syncTextViewportWidth,
              viewportPadding: widget.style.contentPadding,
              child: SelectionIsland(
                enabled: !readOnly,
                child: _EditableSemanticsHost(
                  controller: _controller,
                  lineProjection: _lineProjection,
                  opsProvider: () => _ops,
                  selectionActions: _selectionActions,
                  focusNode: _focusNode,
                  readOnly: readOnly,
                  interactiveSelectionEnabled: interactiveSelectionEnabled,
                  obscureText: widget.style.obscureText,
                  obscuringCharacter: widget.style.obscuringCharacter,
                  semanticLabel: widget.style.semanticLabel,
                  keyboardType: widget.style.keyboardType,
                  // 透明命中面保证空行没有字形 RenderBox 时，整块编辑区域仍可点击。
                  style: const ElStyle(backgroundColor: Color(0x00000000), cursor: SystemMouseCursors.text),
                  event: combineEditableEvents(
                    readOnly
                        ? const ElEvent()
                        : ElEvent(
                            longPressDelay: _selectionControls.resolveLongPressDelay(context),
                            tapCancelDistance: 10,
                            onPointerDown: _handlePointerDownFocus,
                            onPointerUp: interactiveSelectionEnabled ? _handlePointerSelectionEnd : null,
                            onPointerCancel: interactiveSelectionEnabled ? _handlePointerSelectionEnd : null,
                            // 收起软键盘可能保留焦点与连接；只在点击成立后重新 show，避免滑动误弹。
                            onTap: (_) => _requestKeyboard(),
                            onTapDown: interactiveSelectionEnabled || _selectionTextBlocked ? _handleTapDown : null,
                            onTapUp: interactiveSelectionEnabled ? _handleTapUp : null,
                            onTapCancel: interactiveSelectionEnabled ? _handleTapCancel : null,
                            onSecondaryTapDown: interactiveSelectionEnabled ? _handleSecondaryTapDown : null,
                            onSecondaryTapUp: interactiveSelectionEnabled ? _handleSecondaryTapUp : null,
                            onDoubleTapDown: interactiveSelectionEnabled ? _handleDoubleTapDown : null,
                            onDoubleTap: interactiveSelectionEnabled ? _handleDoubleTap : null,
                            onTripleTapDown: interactiveSelectionEnabled ? _handleTripleTapDown : null,
                            onTripleTap: interactiveSelectionEnabled ? _handleTripleTap : null,
                            onLongPress: interactiveSelectionEnabled ? _handleLongPress : null,
                            onDragStart: interactiveSelectionEnabled ? _handleDragStart : null,
                            onDragUpdate: interactiveSelectionEnabled ? _handleDragUpdate : null,
                            onDragEnd: interactiveSelectionEnabled ? _handleDragEnd : null,
                            onDragCancel: interactiveSelectionEnabled ? _handleDragCancel : null,
                          ),
                    widget.event,
                  ),
                  child: Directionality(
                    // 编辑器的完整行几何恒使用左起视觉坐标；段落/run 的 RTL 由
                    // TextPainter 与 UAX#9 自己处理，不能再让滚动轴把 x=0 镜像。
                    textDirection: TextDirection.ltr,
                    child: EditableSelectionLayer(
                      scope: _scope,
                      beforePaint: _syncDragSelectionBeforePaint,
                      child: _buildScroll(lines, dualAxis: dualAxis),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 复用外部页面/弹层宿主，句柄不随编辑器的裁剪和缩放。
    return SelectionChromeSlot.maybeOf(context) == null ? SelectionChromeSlotHost(child: content) : content;
  }

  // 回收列表按可见首行保位：行高变化不推动正文。不换行时外层横向滚动按最长行展开内容宽度。
  Widget _buildScroll(Widget lines, {required bool dualAxis}) {
    final cache = ScrollCacheExtent.pixels(widget.style.cacheExtent);
    final Widget scroll;
    if (dualAxis) {
      final padding = widget.style.contentPadding.horizontal;
      scroll = DualAxisScroll(
        horizontalController: _horizontalController,
        verticalController: _scrollController,
        // 最长行宽在行布局后写入，横向内容宽度在外层布局时读取最新值。
        contentWidth: (_) => _scope.minimumCrossAxisExtent.value + padding,
        widthListenable: _scope.minimumCrossAxisExtent,
        physics: widget.style.scrollPhysics,
        scrollCacheExtent: cache,
        scrollbars: widget.style.scrollbars,
        slivers: [lines],
      );
    } else {
      scroll = ElScroll.sliver(
        controller: _scrollController,
        physics: widget.style.scrollPhysics,
        scrollCacheExtent: cache,
        slivers: [lines],
      );
    }
    // 笔与鼠标一样在正文上拖选文字，不拖动滚动；触摸仍按平台拖动滚动。
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        scrollbars: widget.style.scrollbars ? null : false,
        dragDevices: behavior.dragDevices.difference(const {
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        }),
      ),
      child: scroll,
    );
  }

  Widget _buildSelectionChrome(BuildContext context, Offset Function(Offset global) globalToLocal) {
    final toolbarActions = _selectionToolbarActions;
    return SelectionOverlayChrome(
      endpointsListenable: _selectionEndpoints,
      dragInfoListenable: _selectionDragInfo,
      scrollActivityListenable: _selectionScrollActivity,
      lineGeometryProvider: _selectionMagnifierLineGeometry,
      globalToLocal: globalToLocal,
      controls: _selectionControls,
      handleColor: _scope.config.selectionColor.withAlpha(255),
      showHandles: _showSelectionHandles,
      showMagnifier: _showSelectionMagnifier,
      showToolbar: _showSelectionToolbar,
      toolbarActions: toolbarActions.value,
      toolbarActionsListenable: toolbarActions,
      onHandleDragBegin: _beginSelectionHandleDrag,
      onHandleDragEnd: _endSelectionHandleDrag,
    );
  }

  Widget _buildLine(BuildContext context, int viewRow) {
    final modelLine = _lineProjection.modelLineForViewRow(viewRow);
    final key = _lineKeyFor(modelLine);
    // 不以身份作 Widget key：回收槽位换绑到另一行时原地更新序号与身份，不重建行节点。
    return EditableLineView(scope: _scope, index: modelLine, identity: key);
  }
}

final class _EditableAutofillClient implements AutofillClient {
  _EditableAutofillClient(_EditableViewState state) : _state = state, autofillId = 'EditableView-${_nextId++}';

  static int _nextId = 0;

  final _EditableViewState _state;

  @override
  final String autofillId;

  @override
  TextInputConfiguration get textInputConfiguration => _state._imeConfiguration();

  @override
  void autofill(TextEditingValue newEditingValue) => _state._handleAutofill(newEditingValue);
}

final class _EditableLineKey extends LocalKey {
  const _EditableLineKey({required this.owner});

  final Object owner;
}

final class _EditableLineIdentity {
  _EditableLineIdentity({required this.key, required this.index, required this.offset, required this.lastUsed});

  final _EditableLineKey key;
  int index;
  int offset;
  int lastUsed;
}

final class _LineProjectionRepairRequest {
  const _LineProjectionRepairRequest({
    required this.epoch,
    required this.projection,
    required this.projectionRevision,
    required this.controller,
    required this.documentVersion,
    required this.selections,
  });

  final int epoch;
  final EditableLineProjection projection;
  final int projectionRevision;
  final EditableController controller;
  final DocumentVersion documentVersion;
  final EditableSelectionSet selections;
}

final class _CaretRevealRequest {
  _CaretRevealRequest({
    required this.epoch,
    required this.projection,
    required this.projectionRevision,
    required this.controller,
    required this.scrollController,
    required this.horizontalController,
    required this.docRevision,
    required this.selections,
    required this.softWrap,
    required this.completion,
  });

  final int epoch;
  final EditableLineProjection projection;
  final int projectionRevision;
  final EditableController controller;
  final ScrollController scrollController;
  final ScrollController? horizontalController;
  final int docRevision;
  final Object selections;
  final bool softWrap;
  final Completer<bool> completion;
  int startAttempts = 0;
  int coarseAttempts = 0;
  Object? pendingGeometryProgressToken;
  int pendingGeometryStallFrames = 0;
  bool coarsePositioning = false;
  ({Rect caret, Rect viewport, double verticalPixels, double horizontalPixels})? stableGeometry;
}

final class _AutomaticCaretRevealIntent {
  const _AutomaticCaretRevealIntent({
    required this.epoch,
    required this.controller,
    required this.scrollController,
    required this.horizontalController,
    required this.docRevision,
    required this.selections,
    required this.softWrap,
  });

  final int epoch;
  final EditableController controller;
  final ScrollController scrollController;
  final ScrollController? horizontalController;
  final int docRevision;
  final Object selections;
  final bool softWrap;
}

// 同步根内容的 viewport 宽与 paint transform：首轮 layout 先给 nowrap
// 短文有限宽，paint 后再以真实滚动 viewport 校准端点和滚动条占位。
class _EditableSelectionPaintGeometryObserver extends SingleChildRenderObjectWidget {
  const _EditableSelectionPaintGeometryObserver({
    required this.onGeometryChanged,
    required this.onViewportWidthChanged,
    required this.onViewportMetricsChanged,
    required this.viewportPadding,
    required super.child,
  });

  final VoidCallback onGeometryChanged;
  final ValueChanged<double> onViewportWidthChanged;
  final VoidCallback onViewportMetricsChanged;
  final EdgeInsets viewportPadding;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEditableSelectionPaintGeometryObserver(
    onGeometryChanged,
    onViewportWidthChanged,
    onViewportMetricsChanged,
    viewportPadding,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderEditableSelectionPaintGeometryObserver renderObject) {
    renderObject
      ..onGeometryChanged = onGeometryChanged
      ..onViewportWidthChanged = onViewportWidthChanged
      ..onViewportMetricsChanged = onViewportMetricsChanged
      ..viewportPadding = viewportPadding;
  }
}

class _RenderEditableSelectionPaintGeometryObserver extends RenderProxyBox
    implements SelectionVisualGeometryDependency {
  _RenderEditableSelectionPaintGeometryObserver(
    this._onGeometryChanged,
    this._onViewportWidthChanged,
    this._onViewportMetricsChanged,
    this._viewportPadding,
  );

  VoidCallback _onGeometryChanged;
  ValueChanged<double> _onViewportWidthChanged;
  VoidCallback _onViewportMetricsChanged;
  EdgeInsets _viewportPadding;
  Matrix4? _lastGlobalTransform;
  Rect? _lastGlobalClip;
  List<Listenable> _ancestorVisualListenables = const <Listenable>[];
  bool _callbackScheduled = false;
  bool _viewportCallbackScheduled = false;

  set onGeometryChanged(VoidCallback value) => _onGeometryChanged = value;

  set onViewportWidthChanged(ValueChanged<double> value) => _onViewportWidthChanged = value;

  set onViewportMetricsChanged(VoidCallback value) => _onViewportMetricsChanged = value;

  set viewportPadding(EdgeInsets value) {
    if (_viewportPadding == value) return;
    _viewportPadding = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (constraints.maxWidth.isFinite) {
      _onViewportWidthChanged(math.max(0.0, constraints.maxWidth - _viewportPadding.horizontal));
    }
    super.performLayout();
    _syncAncestorVisualListenables();
    if (_viewportCallbackScheduled) return;
    _viewportCallbackScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _viewportCallbackScheduled = false;
      if (attached) _onViewportMetricsChanged();
    });
  }

  @override
  void descendantSelectionVisualGeometryChanged(RenderObject source) {
    if (attached) _scheduleGeometryChanged();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncAncestorVisualListenables();
  }

  @override
  void detach() {
    _replaceAncestorVisualListenables(const <Listenable>[]);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _syncAncestorVisualListenables();
    Matrix4 next;
    try {
      next = getTransformTo(null);
    } catch (_) {
      return;
    }
    final previous = _lastGlobalTransform;
    final nextClip = _visibleGlobalRect();
    if (previous != null && _matrixValuesEqual(previous, next) && _lastGlobalClip == nextClip) return;
    _lastGlobalTransform = next.clone();
    _lastGlobalClip = nextClip;
    _scheduleGeometryChanged();
  }

  void _scheduleGeometryChanged() {
    if (_callbackScheduled) return;
    _callbackScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _callbackScheduled = false;
      if (attached) _onGeometryChanged();
    });
  }

  void _syncAncestorVisualListenables() {
    if (!attached) return;
    final next = <Listenable>[];
    RenderObject? ancestor = parent;
    while (ancestor != null) {
      final Listenable? visualListenable = switch (ancestor) {
        ScrollViewport viewport => viewport.scrollOffsetListenable,
        RenderViewportBase viewport => viewport.offset,
        ElRenderView view => view.ensureCascadeBridgeChanges(),
        _ => null,
      };
      if (visualListenable != null && !next.any((candidate) => identical(candidate, visualListenable))) {
        next.add(visualListenable);
      }
      ancestor = ancestor.parent;
    }
    if (_sameVisualListenables(_ancestorVisualListenables, next)) return;
    _replaceAncestorVisualListenables(next);
  }

  void _replaceAncestorVisualListenables(List<Listenable> next) {
    for (final visualListenable in _ancestorVisualListenables) {
      visualListenable.removeListener(_handleAncestorVisualChanged);
    }
    _ancestorVisualListenables = List<Listenable>.unmodifiable(next);
    for (final visualListenable in _ancestorVisualListenables) {
      visualListenable.addListener(_handleAncestorVisualChanged);
    }
  }

  void _handleAncestorVisualChanged() {
    if (attached) _scheduleGeometryChanged();
  }

  static bool _sameVisualListenables(List<Listenable> left, List<Listenable> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!identical(left[i], right[i])) return false;
    }
    return true;
  }

  static bool _matrixValuesEqual(Matrix4 a, Matrix4 b) {
    final av = a.storage;
    final bv = b.storage;
    for (var i = 0; i < 16; i++) {
      if (av[i] != bv[i]) return false;
    }
    return true;
  }

  Rect? _visibleGlobalRect() {
    if (!hasSize) return null;
    var visible = MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
    RenderObject child = this;
    RenderObject? parent = this.parent;
    while (parent != null) {
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        try {
          visible = visible.intersect(MatrixUtils.transformRect(parent.getTransformTo(null), clip));
        } catch (_) {
          return visible;
        }
        if (visible.isEmpty) return Rect.zero;
      }
      child = parent;
      parent = parent.parent;
    }
    return visible;
  }
}

// 选区模块的 handle controller 只认窄 host 协议；用私有适配器隔离
// internal side/drag 类型，不污染 _EditableViewState 的公开几何门面。
class _EditableSelectionChromeAdapter implements SelectionMagnifierHost {
  _EditableSelectionChromeAdapter(this.state);

  final _EditableViewState state;

  @override
  bool setSelectionHandleEndpoint(SelectionHandleSide side, Offset globalPosition) =>
      state._setSelectionHandleEndpoint(side, globalPosition);

  @override
  void onDragInfoChanged() => state._handleSelectionDragInfoChanged();

  @override
  void syncDragScrollViewportsForHandleDrag() {}

  @override
  void updateAutoScrollForHandleDrag(Offset globalPosition) => state._updateHandleAutoScroll(globalPosition);

  @override
  void stopAutoScrollAndClearViewports() => state._stopHandleAutoScroll();

  @override
  void flushDeferredSelectionInfo() {}

  @override
  void startGlobalPointerRoute() {}

  @override
  void stopGlobalPointerRoute() {}

  @override
  ({Offset globalBottom, double lineHeight, double idealVerticalOffset, double touchOffsetY})? handleAnchorFor(
    SelectionHandleSide side,
  ) => state._selectionHandleAnchor(side);

  @override
  int? handleEndpointOffsetFor(SelectionHandleSide side) => state._selectionHandleOffset(side);

  @override
  bool get handleHapticsEnabled => state.mounted && state._selectionControls.resolveHandleHaptics(state.context);

  @override
  void setHandleEndpointOffset(SelectionHandleSide side, int offset) => state._setSelectionHandleOffset(side, offset);
}

// 语义桥接只重建文本框外壳，不让每次选区 / 文本变化都重建虚拟行子树。
class _EditableSemanticsHost extends StatefulWidget {
  const _EditableSemanticsHost({
    required this.controller,
    required this.lineProjection,
    required this.opsProvider,
    required this.selectionActions,
    required this.focusNode,
    required this.readOnly,
    required this.interactiveSelectionEnabled,
    required this.obscureText,
    required this.obscuringCharacter,
    required this.semanticLabel,
    required this.keyboardType,
    required this.style,
    required this.event,
    required this.child,
  });

  final EditableController controller;
  final EditableLineProjection lineProjection;
  final EditableOps Function() opsProvider;
  final SelectionActions Function() selectionActions;
  final FocusNode focusNode;
  final bool readOnly;
  final bool interactiveSelectionEnabled;
  final bool obscureText;
  final String obscuringCharacter;
  final String? semanticLabel;
  final TextInputType? keyboardType;
  final ElStyle style;
  final ElEvent event;
  final Widget child;

  @override
  State<_EditableSemanticsHost> createState() => _EditableSemanticsHostState();
}

class _EditableSemanticsHostState extends State<_EditableSemanticsHost> {
  _EditableSemanticWindow _window = const _EditableSemanticWindow.disabled();
  int _windowRevision = -1;
  int _windowProjectionRevision = -1;
  late bool _semanticsEnabled;
  bool _valueListenersAttached = false;

  @override
  void initState() {
    super.initState();
    _semanticsEnabled = SemanticsBinding.instance.semanticsEnabled;
    SemanticsBinding.instance.addSemanticsEnabledListener(_handleSemanticsEnabledChanged);
    if (_semanticsEnabled) _attachValueListeners(widget);
  }

  @override
  void didUpdateWidget(_EditableSemanticsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bindingChanged =
        widget.controller != oldWidget.controller ||
        !identical(widget.lineProjection, oldWidget.lineProjection) ||
        widget.focusNode != oldWidget.focusNode;
    if (_semanticsEnabled && bindingChanged) {
      _detachValueListeners(oldWidget);
      _attachValueListeners(widget);
    }
    if (widget.controller != oldWidget.controller) {
      _windowRevision = -1;
    } else if (widget.obscureText != oldWidget.obscureText ||
        widget.obscuringCharacter != oldWidget.obscuringCharacter) {
      _windowRevision = -1;
    }
    if (!identical(widget.lineProjection, oldWidget.lineProjection)) {
      _windowProjectionRevision = -1;
    }
  }

  @override
  void dispose() {
    SemanticsBinding.instance.removeSemanticsEnabledListener(_handleSemanticsEnabledChanged);
    _detachValueListeners(widget);
    super.dispose();
  }

  void _attachValueListeners(_EditableSemanticsHost source) {
    if (_valueListenersAttached) return;
    source.controller.visualChanges.addListener(_handleVisualChanged);
    source.controller.configurationChanges.addListener(_handleConfigurationChanged);
    source.lineProjection.addListener(_handleProjectionChanged);
    source.focusNode.addListener(_handleFocusChanged);
    _valueListenersAttached = true;
  }

  void _detachValueListeners(_EditableSemanticsHost source) {
    if (!_valueListenersAttached) return;
    source.controller.visualChanges.removeListener(_handleVisualChanged);
    source.controller.configurationChanges.removeListener(_handleConfigurationChanged);
    source.lineProjection.removeListener(_handleProjectionChanged);
    source.focusNode.removeListener(_handleFocusChanged);
    _valueListenersAttached = false;
  }

  void _handleSemanticsEnabledChanged() {
    final enabled = SemanticsBinding.instance.semanticsEnabled;
    if (enabled == _semanticsEnabled || !mounted) return;
    if (enabled) {
      _attachValueListeners(widget);
    } else {
      _detachValueListeners(widget);
    }
    setState(() {
      _semanticsEnabled = enabled;
      _windowRevision = -1;
      if (!enabled) _window = const _EditableSemanticWindow.disabled();
    });
  }

  void _handleVisualChanged() {
    if (mounted && _semanticsEnabled) setState(() {});
  }

  void _handleConfigurationChanged() {
    if (mounted && _semanticsEnabled) setState(() {});
  }

  void _handleProjectionChanged() {
    if (!mounted || !_semanticsEnabled || _windowProjectionRevision == widget.lineProjection.mappingRevision) {
      return;
    }
    setState(() {
      _windowRevision = -1;
      _windowProjectionRevision = -1;
    });
  }

  void _handleFocusChanged() {
    if (mounted && _semanticsEnabled) setState(() {});
  }

  void _requestSemanticsFocus() {
    if (widget.readOnly) return;
    final focusNode = widget.focusNode;
    if (!focusNode.hasFocus && focusNode.canRequestFocus) focusNode.requestFocus();
  }

  bool _isActionSnapshotCurrent(_EditableSemanticsActionSnapshot snapshot, {bool requireWholeDocument = false}) {
    if (!mounted ||
        !identical(widget.controller, snapshot.controller) ||
        widget.controller.docRevision != snapshot.documentRevision ||
        !identical(widget.lineProjection, snapshot.lineProjection) ||
        widget.lineProjection.mappingRevision != snapshot.projectionRevision) {
      return false;
    }
    final wholeDocumentEligible =
        widget.lineProjection.hiddenAreas?.isEmpty != false &&
        widget.controller.document.length <= _semanticTextWindowLimit;
    if (wholeDocumentEligible != snapshot.wholeDocumentEligible) return false;
    return !requireWholeDocument || snapshot.wholeDocumentEligible;
  }

  void _setText(_EditableSemanticsActionSnapshot snapshot, String text) {
    if (!widget.focusNode.hasFocus ||
        widget.readOnly ||
        !_isActionSnapshotCurrent(snapshot, requireWholeDocument: true)) {
      return;
    }
    widget.controller.applyAccessibilityValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  void _setSelection(_EditableSemanticsActionSnapshot snapshot, TextSelection selection) {
    if (widget.readOnly ||
        !widget.focusNode.hasFocus ||
        !widget.interactiveSelectionEnabled ||
        !_isActionSnapshotCurrent(snapshot)) {
      return;
    }
    widget.controller.setSelection(snapshot.window.toDocumentSelection(selection));
  }

  void _copy() {
    if (!widget.readOnly &&
        widget.focusNode.hasFocus &&
        widget.interactiveSelectionEnabled &&
        !widget.obscureText &&
        !widget.controller.selection.isCollapsed &&
        !_selectionCrossesHidden()) {
      widget.selectionActions().copy();
    }
  }

  void _cut() {
    if (widget.focusNode.hasFocus &&
        widget.interactiveSelectionEnabled &&
        !widget.readOnly &&
        !widget.obscureText &&
        !widget.controller.selection.isCollapsed &&
        !_selectionCrossesHidden()) {
      widget.selectionActions().cut?.call();
    }
  }

  bool _selectionCrossesHidden() {
    final selection = widget.controller.selection;
    return !selection.isCollapsed &&
        widget.lineProjection.hiddenAreas?.isEmpty == false &&
        widget.lineProjection.rangeIntersectsHiddenContent(TextRange(start: selection.start, end: selection.end));
  }

  void _paste() {
    if (widget.focusNode.hasFocus && widget.interactiveSelectionEnabled && !widget.readOnly) {
      widget.selectionActions().paste?.call();
    }
  }

  void _moveCursor({required bool forward, required bool byWord, required bool extend}) {
    if (widget.readOnly || !widget.interactiveSelectionEnabled) return;
    if (widget.obscureText) {
      // 密码语义 value 是逐 UTF-16 code unit 的等长统一掩码。字符移动必须
      // 同样逐格，词移动则无可公开的相邻词；读取真实 grapheme/词边界都会
      // 侧漏 emoji、空白或标点结构。
      if (byWord) return;
      final selection = widget.controller.selections.primary;
      final rawTarget = (selection.active + (forward ? 1 : -1)).clamp(0, widget.controller.document.length);
      final target = widget.lineProjection.projectCollapsedPosition(
        TextPosition(offset: rawTarget),
        bias: forward ? EditablePositionProjectionBias.forward : EditablePositionProjectionBias.backward,
      );
      if (target.offset == selection.active) return;
      widget.controller.setSelection(
        TextSelection(
          baseOffset: extend ? selection.anchor : target.offset,
          extentOffset: target.offset,
          affinity: target.affinity,
        ),
      );
      return;
    }
    widget.opsProvider().moveSemanticsCursor(forward: forward, byWord: byWord, extend: extend);
  }

  void _syncWindow() {
    final controller = widget.controller;
    if (!_semanticsEnabled) {
      _window = const _EditableSemanticWindow.disabled();
      _windowRevision = controller.docRevision;
      _windowProjectionRevision = widget.lineProjection.mappingRevision;
      return;
    }

    final revision = controller.docRevision;
    final projectionRevision = widget.lineProjection.mappingRevision;
    if (widget.lineProjection.hiddenAreas?.isEmpty == false) {
      if (_windowRevision == revision && _windowProjectionRevision == projectionRevision) {
        final selected = _window.withProjectedSelection(controller.selection, widget.lineProjection);
        if (selected != null) {
          _window = selected;
          return;
        }
      }
      _window = _EditableSemanticWindow.fromProjectedController(
        controller,
        widget.lineProjection,
        obscureText: widget.obscureText,
        obscuringCharacter: widget.obscuringCharacter,
      );
      _windowRevision = revision;
      _windowProjectionRevision = projectionRevision;
      return;
    }
    if (_windowRevision == revision && _windowProjectionRevision == projectionRevision) {
      final selected = _window.withSelection(controller.selection);
      if (selected != null) {
        _window = selected;
        return;
      }
    } else {
      final changeSet = controller.lastChangeSet;
      if (changeSet != null && changeSet.baseRevision == _windowRevision && changeSet.revision == revision) {
        final changed = _window.applyChangeSet(
          changeSet,
          document: controller.document,
          selection: controller.selection,
          obscureText: widget.obscureText,
          obscuringCharacter: widget.obscuringCharacter,
        );
        if (changed != null) {
          _window = changed;
          _windowRevision = revision;
          _windowProjectionRevision = projectionRevision;
          return;
        }
      }
    }

    _window = _EditableSemanticWindow.fromController(
      controller,
      obscureText: widget.obscureText,
      obscuringCharacter: widget.obscuringCharacter,
    );
    _windowRevision = revision;
    _windowProjectionRevision = projectionRevision;
  }

  @override
  Widget build(BuildContext context) {
    if (!_semanticsEnabled) {
      return ElView(style: widget.style, event: widget.event, focusNode: widget.focusNode, child: widget.child);
    }
    _syncWindow();
    final selection = widget.controller.selection;
    final focused = !widget.readOnly && widget.focusNode.hasFocus;
    final selectionCrossesHidden = _selectionCrossesHidden();
    final canCopy =
        focused &&
        widget.interactiveSelectionEnabled &&
        !widget.obscureText &&
        !selection.isCollapsed &&
        !selectionCrossesHidden;
    final canCut = canCopy && !widget.readOnly;
    final canMoveBackward = widget.interactiveSelectionEnabled && selection.extentOffset > 0;
    final canMoveForward =
        widget.interactiveSelectionEnabled && selection.extentOffset < widget.controller.document.length;
    final actionSnapshot = _EditableSemanticsActionSnapshot(
      controller: widget.controller,
      documentRevision: widget.controller.docRevision,
      lineProjection: widget.lineProjection,
      projectionRevision: widget.lineProjection.mappingRevision,
      wholeDocumentEligible: _window.isWholeDocument,
      window: _window,
    );
    return ElView(
      style: widget.style,
      event: widget.event,
      focusNode: widget.focusNode,
      semantics: ElSemantics(
        properties: SemanticsProperties(
          enabled: true,
          textField: true,
          focused: focused,
          multiline: !widget.controller.singleLine,
          readOnly: widget.readOnly,
          obscured: widget.obscureText,
          label: widget.semanticLabel,
          value: _window.value,
          inputType: _semanticInputType(widget.keyboardType),
          maxValueLength: _window.isWholeDocument ? widget.controller.maxLength : null,
          currentValueLength: _window.isWholeDocument && widget.controller.maxLength != null
              ? widget.controller.committedTextLength
              : null,
          onTap: widget.readOnly ? null : _requestSemanticsFocus,
          onFocus: widget.readOnly || defaultTargetPlatform == TargetPlatform.iOS ? null : _requestSemanticsFocus,
          onSetText: focused && !widget.readOnly && _window.isWholeDocument
              ? (text) => _setText(actionSnapshot, text)
              : null,
          onSetSelection: focused && widget.interactiveSelectionEnabled
              ? (selection) => _setSelection(actionSnapshot, selection)
              : null,
          onCopy: canCopy ? _copy : null,
          onCut: canCut ? _cut : null,
          onPaste: !focused || widget.readOnly || !widget.interactiveSelectionEnabled ? null : _paste,
          onMoveCursorForwardByCharacter: canMoveForward
              ? (extend) => _moveCursor(forward: true, byWord: false, extend: extend)
              : null,
          onMoveCursorBackwardByCharacter: canMoveBackward
              ? (extend) => _moveCursor(forward: false, byWord: false, extend: extend)
              : null,
          onMoveCursorForwardByWord: canMoveForward
              ? (extend) => _moveCursor(forward: true, byWord: true, extend: extend)
              : null,
          onMoveCursorBackwardByWord: canMoveBackward
              ? (extend) => _moveCursor(forward: false, byWord: true, extend: extend)
              : null,
        ),
      ),
      child: _EditableTextSelectionSemantics(
        selection: widget.interactiveSelectionEnabled ? _window.selection : null,
        child: widget.child,
      ),
    );
  }
}

SemanticsInputType _semanticInputType(TextInputType? type) {
  if (type == TextInputType.phone) return SemanticsInputType.phone;
  if (type == TextInputType.url) return SemanticsInputType.url;
  if (type == TextInputType.emailAddress) return SemanticsInputType.email;
  return SemanticsInputType.text;
}

final class _EditableSemanticsActionSnapshot {
  const _EditableSemanticsActionSnapshot({
    required this.controller,
    required this.documentRevision,
    required this.lineProjection,
    required this.projectionRevision,
    required this.wholeDocumentEligible,
    required this.window,
  });

  final EditableController controller;
  final int documentRevision;
  final EditableLineProjection lineProjection;
  final int projectionRevision;
  final bool wholeDocumentEligible;
  final _EditableSemanticWindow window;
}

// 辅助技术的文本值有平台通道上限；固定有界窗口也避免大文档每次击键 O(n) 整篇物化。
const int _semanticTextWindowLimit = 16 * 1024;
const int _semanticMaxSegments = 256;

enum _SemanticSliceBias { active, before, after }

final class _EditableSemanticWindow {
  const _EditableSemanticWindow({
    required this.documentStart,
    required this.documentEnd,
    required this.value,
    required this.selection,
    required this.isWholeDocument,
    this.segments = const <_EditableSemanticSegment>[],
  });

  const _EditableSemanticWindow.disabled()
    : documentStart = 0,
      documentEnd = 0,
      value = '',
      selection = const TextSelection.collapsed(offset: 0),
      isWholeDocument = false,
      segments = const <_EditableSemanticSegment>[];

  factory _EditableSemanticWindow.fromController(
    EditableController controller, {
    required bool obscureText,
    required String obscuringCharacter,
  }) {
    final document = controller.document;
    final selection = controller.selection;
    final selectedLength = selection.end - selection.start;

    int start;
    int requestedEnd;
    if (selectedLength <= _semanticTextWindowLimit) {
      final before = (_semanticTextWindowLimit - selectedLength) ~/ 2;
      start = math.max(0, selection.start - before);
      requestedEnd = selection.end + (_semanticTextWindowLimit - (selection.end - start));
    } else {
      // 超大选区无法在有界 value 中同时容纳两端；优先保留 active 端附近上下文。
      start = math.max(0, selection.extentOffset - _semanticTextWindowLimit ~/ 2);
      requestedEnd = start + _semanticTextWindowLimit;
    }

    final endProbe = _probeDocumentOffset(document, requestedEnd);
    var end = endProbe.offset;
    if (endProbe.atEnd && end - start < _semanticTextWindowLimit) {
      start = math.max(0, end - _semanticTextWindowLimit);
    }
    final safeRange = _semanticSurrogateSafeRange(document, start, end);
    start = safeRange.start;
    end = safeRange.end;
    final value = obscureText ? obscuringCharacter * (end - start) : document.getText(start, end);
    final valueLength = value.length;
    int localOffset(int offset) => (offset - start).clamp(0, valueLength);

    return _EditableSemanticWindow(
      documentStart: start,
      documentEnd: end,
      value: value,
      selection: TextSelection(
        baseOffset: localOffset(selection.baseOffset),
        extentOffset: localOffset(selection.extentOffset),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
      isWholeDocument: start == 0 && end == document.length,
    );
  }

  factory _EditableSemanticWindow.fromProjectedController(
    EditableController controller,
    EditableLineProjection projection, {
    required bool obscureText,
    required String obscuringCharacter,
  }) {
    final document = controller.document;
    final selection = controller.selection;
    final base = projection.projectSelectionEndpointForGeometry(
      TextPosition(offset: selection.baseOffset),
      oppositeEndpoint: TextPosition(offset: selection.extentOffset, affinity: selection.affinity),
    );
    final extent = projection.projectSelectionEndpointForGeometry(
      TextPosition(offset: selection.extentOffset, affinity: selection.affinity),
      oppositeEndpoint: TextPosition(offset: selection.baseOffset),
    );
    final blocks = projection.visibleDocumentScanRanges(contextCodeUnits: 0).toList(growable: true);
    final terminalLine = projection.lastVisibleModelLine;
    if (terminalLine == document.lineCount - 1 &&
        document.lineLength(terminalLine) == 0 &&
        !blocks.any((block) => document.length >= block.start && document.length <= block.end)) {
      blocks.add(TextRange.collapsed(document.length));
    }
    final activeLine = document.lineIndexOf(extent.offset);
    if (document.lineLength(activeLine) == 0 &&
        !blocks.any((block) => extent.offset >= block.start && extent.offset <= block.end)) {
      blocks.add(TextRange.collapsed(document.lineStart(activeLine)));
    }
    blocks.sort((left, right) => left.start.compareTo(right.start));
    final activeBlock = _semanticBlockIndexForOffset(blocks, extent.offset);
    int contentEnd(TextRange block) =>
        block.end < document.length &&
            block.end > block.start &&
            document.getText(block.end - 1, block.end).codeUnitAt(0) == 0x0a
        ? block.end - 1
        : block.end;
    TextRange slice(int index, int budget, {required _SemanticSliceBias bias}) {
      final block = blocks[index];
      final end = contentEnd(block);
      final length = end - block.start;
      final candidate = length <= budget
          ? TextRange(start: block.start, end: end)
          : switch (bias) {
              _SemanticSliceBias.active => () {
                final center = extent.offset.clamp(block.start, end).toInt();
                final start = (center - budget ~/ 2).clamp(block.start, end - budget).toInt();
                return TextRange(start: start, end: start + budget);
              }(),
              _SemanticSliceBias.before => TextRange(start: end - budget, end: end),
              _SemanticSliceBias.after => TextRange(start: block.start, end: block.start + budget),
            };
      return _semanticSurrogateSafeRange(document, candidate.start, candidate.end);
    }

    final selected = <int, TextRange>{};
    final activeBudget = blocks.length == 1 ? _semanticTextWindowLimit : _semanticTextWindowLimit ~/ 2;
    final activeSlice = slice(activeBlock, activeBudget, bias: _SemanticSliceBias.active);
    selected[activeBlock] = activeSlice;
    var remaining = _semanticTextWindowLimit - (activeSlice.end - activeSlice.start);
    for (
      var distance = 1;
      remaining > 1 &&
          selected.length < _semanticMaxSegments &&
          (activeBlock - distance >= 0 || activeBlock + distance < blocks.length);
      distance++
    ) {
      final before = activeBlock - distance;
      if (before >= 0 && remaining > 1 && selected.length < _semanticMaxSegments) {
        final value = slice(before, remaining - 1, bias: _SemanticSliceBias.before);
        selected[before] = value;
        remaining -= value.end - value.start + 1;
      }
      final after = activeBlock + distance;
      if (after < blocks.length && remaining > 1 && selected.length < _semanticMaxSegments) {
        final value = slice(after, remaining - 1, bias: _SemanticSliceBias.after);
        selected[after] = value;
        remaining -= value.end - value.start + 1;
      }
    }

    final buffer = StringBuffer();
    final segments = <_EditableSemanticSegment>[];
    final ordered = selected.entries.toList()..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in ordered) {
      if (segments.isNotEmpty) {
        buffer.write('\n');
      }
      final source = entry.value;
      final localStart = buffer.length;
      final sliceLength = source.end - source.start;
      buffer.write(obscureText ? obscuringCharacter * sliceLength : document.getText(source.start, source.end));
      final localEnd = buffer.length;
      segments.add(
        _EditableSemanticSegment(
          documentStart: source.start,
          documentEnd: source.end,
          localStart: localStart,
          localEnd: localEnd,
        ),
      );
    }
    final value = buffer.toString();
    final localBase = _semanticLocalOffsetForDocument(segments, base.offset, value.length);
    final localExtent = _semanticLocalOffsetForDocument(segments, extent.offset, value.length);
    return _EditableSemanticWindow(
      documentStart: segments.first.documentStart,
      documentEnd: segments.last.documentEnd,
      value: value,
      selection: TextSelection(
        baseOffset: localBase,
        extentOffset: localExtent,
        affinity: extent.affinity,
        isDirectional: selection.isDirectional,
      ),
      isWholeDocument: false,
      segments: List<_EditableSemanticSegment>.unmodifiable(segments),
    );
  }

  final int documentStart;
  final int documentEnd;
  final String value;
  final TextSelection selection;
  final bool isWholeDocument;
  final List<_EditableSemanticSegment> segments;

  _EditableSemanticWindow? withSelection(TextSelection nextSelection) {
    if (segments.isNotEmpty) return null;
    if (!_contains(nextSelection.baseOffset) || !_contains(nextSelection.extentOffset)) return null;
    return _EditableSemanticWindow(
      documentStart: documentStart,
      documentEnd: documentEnd,
      value: value,
      selection: _localSelection(nextSelection, documentStart, value.length),
      isWholeDocument: isWholeDocument,
    );
  }

  _EditableSemanticWindow? withProjectedSelection(TextSelection nextSelection, EditableLineProjection projection) {
    if (segments.isEmpty) return null;
    final base = projection.projectSelectionEndpointForGeometry(
      TextPosition(offset: nextSelection.baseOffset),
      oppositeEndpoint: TextPosition(offset: nextSelection.extentOffset, affinity: nextSelection.affinity),
    );
    final extent = projection.projectSelectionEndpointForGeometry(
      TextPosition(offset: nextSelection.extentOffset, affinity: nextSelection.affinity),
      oppositeEndpoint: TextPosition(offset: nextSelection.baseOffset),
    );
    bool contains(int offset) =>
        segments.any((segment) => offset >= segment.documentStart && offset <= segment.documentEnd);
    if (!contains(base.offset) || !contains(extent.offset)) return null;
    return _EditableSemanticWindow(
      documentStart: documentStart,
      documentEnd: documentEnd,
      value: value,
      selection: TextSelection(
        baseOffset: _semanticLocalOffsetForDocument(segments, base.offset, value.length),
        extentOffset: _semanticLocalOffsetForDocument(segments, extent.offset, value.length),
        affinity: extent.affinity,
        isDirectional: nextSelection.isDirectional,
      ),
      isWholeDocument: false,
      segments: segments,
    );
  }

  _EditableSemanticWindow? applyChangeSet(
    DocumentChangeSet changeSet, {
    required TextDocument document,
    required TextSelection selection,
    required bool obscureText,
    required String obscuringCharacter,
  }) {
    if (segments.isNotEmpty) return null;
    var nextValue = value;
    var shiftBefore = 0;
    for (final edit in changeSet.edits.reversed) {
      final removedEnd = edit.start + edit.removed.length;
      final delta = edit.inserted.length - edit.removed.length;
      final insertionAtStart = edit.start == documentStart && edit.removed.isEmpty;
      if (removedEnd <= documentStart && !insertionAtStart) {
        shiftBefore += delta;
        continue;
      }
      final insertionAtWholeEnd = isWholeDocument && edit.start == documentEnd && edit.removed.isEmpty;
      if (edit.start >= documentEnd && !insertionAtWholeEnd) continue;
      if (edit.start < documentStart || removedEnd > documentEnd) return null;

      final localStart = edit.start - documentStart;
      final localEnd = removedEnd - documentStart;
      final inserted = obscureText ? obscuringCharacter * edit.inserted.length : edit.inserted;
      nextValue = nextValue.replaceRange(localStart, localEnd, inserted);
    }

    final nextStart = documentStart + shiftBefore;
    var localEnd = math.min<int>(nextValue.length, _semanticTextWindowLimit);
    if (_semanticStringOffsetSplitsSurrogate(nextValue, localEnd)) localEnd--;
    nextValue = nextValue.substring(0, localEnd);
    final nextEnd = nextStart + nextValue.length;
    if (selection.baseOffset < nextStart ||
        selection.baseOffset > nextEnd ||
        selection.extentOffset < nextStart ||
        selection.extentOffset > nextEnd) {
      return null;
    }
    final nextIsWhole =
        isWholeDocument && nextStart == 0 && nextEnd == document.length && nextValue.length <= _semanticTextWindowLimit;
    return _EditableSemanticWindow(
      documentStart: nextStart,
      documentEnd: nextEnd,
      value: nextValue,
      selection: _localSelection(selection, nextStart, nextValue.length),
      isWholeDocument: nextIsWhole,
    );
  }

  bool _contains(int offset) => offset >= documentStart && offset <= documentEnd;

  TextSelection toDocumentSelection(TextSelection local) {
    if (segments.isNotEmpty) {
      return TextSelection(
        baseOffset: _semanticDocumentOffsetForLocal(segments, local.baseOffset, value.length),
        extentOffset: _semanticDocumentOffsetForLocal(segments, local.extentOffset, value.length),
        affinity: local.affinity,
        isDirectional: local.isDirectional,
      );
    }
    final valueLength = value.length;
    int documentOffset(int offset) => documentStart + offset.clamp(0, valueLength);
    return TextSelection(
      baseOffset: documentOffset(local.baseOffset),
      extentOffset: documentOffset(local.extentOffset),
      affinity: local.affinity,
      isDirectional: local.isDirectional,
    );
  }
}

final class _EditableSemanticSegment {
  const _EditableSemanticSegment({
    required this.documentStart,
    required this.documentEnd,
    required this.localStart,
    required this.localEnd,
  });

  final int documentStart;
  final int documentEnd;
  final int localStart;
  final int localEnd;
}

int _semanticBlockIndexForOffset(List<TextRange> blocks, int offset) {
  var low = 0;
  var high = blocks.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (blocks[middle].end < offset) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  if (low >= blocks.length) return blocks.length - 1;
  if (offset < blocks[low].start && low > 0) return low - 1;
  return low;
}

int _semanticLocalOffsetForDocument(List<_EditableSemanticSegment> segments, int offset, int valueLength) {
  for (final segment in segments) {
    if (offset < segment.documentStart) return segment.localStart;
    if (offset <= segment.documentEnd) {
      return (segment.localStart + offset - segment.documentStart).clamp(segment.localStart, segment.localEnd);
    }
  }
  return valueLength;
}

int _semanticDocumentOffsetForLocal(List<_EditableSemanticSegment> segments, int offset, int valueLength) {
  final local = offset.clamp(0, valueLength);
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    if (local < segment.localStart) return index == 0 ? segment.documentStart : segments[index - 1].documentEnd;
    if (local <= segment.localEnd) {
      return (segment.documentStart + local - segment.localStart).clamp(segment.documentStart, segment.documentEnd);
    }
  }
  return segments.last.documentEnd;
}

TextSelection _localSelection(TextSelection selection, int documentStart, int valueLength) {
  int localOffset(int offset) => (offset - documentStart).clamp(0, valueLength);
  return TextSelection(
    baseOffset: localOffset(selection.baseOffset),
    extentOffset: localOffset(selection.extentOffset),
    affinity: selection.affinity,
    isDirectional: selection.isDirectional,
  );
}

TextRange _semanticSurrogateSafeRange(TextDocument document, int rawStart, int rawEnd) {
  var start = rawStart.clamp(0, document.length);
  var end = rawEnd.clamp(start, document.length);
  if (start == end) return TextRange.collapsed(start);
  final startSplitsPair = _semanticOffsetSplitsSurrogate(document, start);
  final endSplitsPair = _semanticOffsetSplitsSurrogate(document, end);
  if (startSplitsPair) start++;
  if (endSplitsPair) end--;
  if (start > end) end = start;
  return TextRange(start: start, end: end);
}

bool _semanticOffsetSplitsSurrogate(TextDocument document, int offset) {
  if (offset <= 0 || offset >= document.length) return false;
  final pair = document.getText(offset - 1, offset + 1).codeUnits;
  return pair.length == 2 && pair.first >= 0xd800 && pair.first <= 0xdbff && pair.last >= 0xdc00 && pair.last <= 0xdfff;
}

bool _semanticStringOffsetSplitsSurrogate(String value, int offset) {
  if (offset <= 0 || offset >= value.length) return false;
  final leading = value.codeUnitAt(offset - 1);
  final trailing = value.codeUnitAt(offset);
  return leading >= 0xd800 && leading <= 0xdbff && trailing >= 0xdc00 && trailing <= 0xdfff;
}

({int offset, bool atEnd}) _probeDocumentOffset(TextDocument document, int requested) {
  final position = document.positionOf(requested);
  final offset = document.offsetOf(position.line, position.column);
  final lastLine = document.lineCount - 1;
  return (offset: offset, atEnd: position.line == lastLine && position.column == document.lineLength(lastLine));
}

// SemanticsProperties 当前没有 textSelection 字段，用无边界轻量 render 注解合并到外层文本框节点。
class _EditableTextSelectionSemantics extends SingleChildRenderObjectWidget {
  const _EditableTextSelectionSemantics({required this.selection, required super.child});

  final TextSelection? selection;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEditableTextSelectionSemantics(selection);

  @override
  void updateRenderObject(BuildContext context, _RenderEditableTextSelectionSemantics renderObject) {
    renderObject.selection = selection;
  }
}

class _RenderEditableTextSelectionSemantics extends RenderProxyBox {
  _RenderEditableTextSelectionSemantics(this._selection);

  TextSelection? _selection;

  set selection(TextSelection? value) {
    if (value == _selection) return;
    _selection = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final selection = _selection;
    if (selection != null) config.textSelection = selection;
  }
}

/// 仅供白盒测试命名私有 State，不从公共入口导出。
typedef EditableViewTestState = _EditableViewState;
