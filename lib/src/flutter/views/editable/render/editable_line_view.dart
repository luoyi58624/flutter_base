// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../scroll/viewport.dart' show ScrollViewport;
import '../../selection/common/selection_core.dart';
import '../../view/text/text_style_adapter.dart';
import '../composer.dart';
import '../model/grapheme_boundary.dart';
import 'editable_line_layout.dart';
import 'editable_render_scope.dart';
import 'inline_text_painter.dart';

const double _geometryTolerance = 1e-6;

bool _inlineSpanHasPaintedBackground(InlineSpan span) {
  final style = span.style;
  if (style?.backgroundColor != null || style?.background != null) return true;
  if (span is! TextSpan) return false;
  final children = span.children;
  if (children == null) return false;
  for (final child in children) {
    if (_inlineSpanHasPaintedBackground(child)) return true;
  }
  return false;
}

@immutable
final class _EditableSelectionPaintGeometry {
  const _EditableSelectionPaintGeometry({required this.bands, required this.exactRects, required this.supplements});

  final List<Rect> bands;
  final List<Rect> exactRects;
  final List<Rect> supplements;
}

/// 编辑器按逻辑行虚拟挂载，内嵌组件再按行内可见区域挂载。
class EditableLineView extends RenderObjectWidget {
  /// 创建一条虚拟编辑行；[identity] 缺省回落到当前 index 兼容独立测试宿主。
  const EditableLineView({super.key, required this.scope, required this.index, Object? identity})
    : identity = identity ?? index;

  /// 行渲染共享协调器。
  final EditableRenderScope scope;

  /// 当前文档行号。
  final int index;

  /// 跨文档 splice 保持稳定的逻辑行身份。
  final Object identity;

  @override
  RenderObjectElement createElement() => _EditableLineElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) {
    final render = RenderEditableLine(scope: scope, index: index, identity: identity)
      ..active = TickerMode.valuesOf(context).enabled;
    render.selectionParticipant?.bindSelectionRegistrar(SelectionContainer.maybeOf(context));
    return render;
  }

  @override
  void updateRenderObject(BuildContext context, RenderEditableLine renderObject) {
    renderObject
      ..scope = scope
      ..index = index
      ..identity = identity
      ..active = TickerMode.valuesOf(context).enabled;
    renderObject.selectionParticipant?.bindSelectionRegistrar(SelectionContainer.maybeOf(context));
  }
}

class _InlineParentData extends ContainerBoxParentData<RenderBox> {
  Object? identity;
}

/// 仅挂载当前可见占位符，普通文字行不分配子节点表。
class _EditableLineElement extends RenderObjectElement {
  _EditableLineElement(EditableLineView super.widget);
  Map<Object, Element>? _children;

  @override
  RenderEditableLine get renderObject => super.renderObject as RenderEditableLine;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject._reconcileInline = _reconcile;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    renderObject.selectionParticipant?.bindSelectionRegistrar(SelectionContainer.maybeOf(this));
  }

  void _reconcile(InlineTextProjection? projection, List<int> visible) {
    if (_children == null && visible.isEmpty) return;
    owner!.buildScope(this, () {
      final previous = _children ?? <Object, Element>{};
      final next = <Object, Element>{};
      for (final index in visible) {
        final identity = projection!.identityAt(index);
        next[identity] = updateChild(previous.remove(identity), projection.widgetAt(index), identity)!;
      }
      for (final child in previous.values) {
        updateChild(child, null, null);
      }
      _children = next.isEmpty ? null : next;
    });
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    _children?.values.forEach(visitor);
  }

  @override
  void forgetChild(Element child) {
    _children?.removeWhere((key, value) => identical(value, child));
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) {
    renderObject.insert(child);
    (child.parentData! as _InlineParentData).identity = slot;
  }

  @override
  void moveRenderObjectChild(RenderBox child, Object? oldSlot, Object? newSlot) {
    (child.parentData! as _InlineParentData).identity = newSlot;
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object? slot) {
    renderObject.remove(child);
  }

  @override
  void unmount() {
    renderObject._reconcileInline = null;
    super.unmount();
  }
}

// 专用适配避免每条可见行都为通用 participant 分配两组闭包。
final class _EditableLineSelectionParticipant extends SelectionParticipant {
  _EditableLineSelectionParticipant(this.line);

  final RenderEditableLine line;

  @override
  RenderBox get box => line;

  @override
  bool get participatesInSelection => line._active;

  @override
  SelectionContent get selectionContent => line._selectionContent;

  @override
  TextDirection get selectionTextDirection => line._config.textDirection;

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    line.scope.repaintSelectionLayer?.call();
  }
}

/// 单行正文与精确字形几何，编辑状态由视口选区层绘制。
///
/// 失效策略：只订阅 [EditableRenderScope] 的合并通知，自行 diff——
/// 行文本或配置变了才 relayout；独立行宿主自行绘制编辑状态，其余正文保持缓存。
/// 高度即内容高，由虚拟滚动测量驱动整体布局。
///
/// **外层选区参与者**（选区岛的"外可进岛"半边）：行同时实现
/// [SelectionParticipant]，外层 [ElSelectionView] 从岛外扫进来时按行高亮、
/// 复制按参与者 join('\n') 天然逐行正确；虚拟化身份复用 ElScrollView
/// 的 identity scope。岛内起手的手势由 SelectionIsland 让外层弃权，
/// 两者互不冲突。
class RenderEditableLine extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _InlineParentData>
    implements SelectionParticipantHost {
  /// 创建单行正文与内嵌组件渲染。
  RenderEditableLine({required EditableRenderScope scope, required int index, required Object identity})
    : _scope = scope,
      _index = index,
      _identity = identity {
    assert(() {
      debugCreatedCount++;
      return true;
    }());
    _selectionParticipant = _EditableLineSelectionParticipant(this);
  }

  EditableRenderScope _scope;
  int _index;
  Object _identity;

  TextPainter _painter = TextPainter();
  InlineTextProjection? _inline;
  Object? _inlineTable;
  TextRange _inlineComposing = TextRange.empty;
  List<PlaceholderDimensions>? _inlineDimensions;
  List<ui.TextBox>? _inlineBoxes;
  void Function(InlineTextProjection?, List<int>)? _reconcileInline;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _InlineParentData) child.parentData = _InlineParentData();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as _InlineParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy + _textPaintOffsetY, 0, 1);
  }

  // 输入和无障碍由整个编辑器统一处理，内嵌组件只负责视觉内容。
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}

  /// 滚动时只让含内嵌内容的行更新局部挂载窗口。
  void refreshInlineViewport() {
    if (_inline?.slots.isNotEmpty ?? false) markNeedsLayout();
  }

  TextPainter? _selectionTextPainter;
  LayerHandle<OffsetLayer>? _editingForegroundLayer;
  List<EditableLineSelectionPaint>? _foregroundSelections;
  (int, int, Size)? _foregroundGeometry;
  InlineSpan? _selectionTextSource;
  Color? _selectionTextColor;
  InlineSpan? _selectionBackgroundSource;
  bool _selectionSourceHasBackground = false;
  int _selectionTextConfigRevision = -1;
  int _selectionTextSystemFontsRevision = -1;
  double _selectionTextMinWidth = -1;
  double _selectionTextMaxWidth = -1;
  String _text = '';
  EditableLineLayoutWindow? _window;
  bool _contentLoaded = false;
  int _docRevision = -1;
  int _longLineWindowRevision = -1;
  int _configRevision = -1;
  EditableRenderConfig? _lastConfig;
  double _lastViewportWidth = -1;
  int _systemFontsRevision = -1;
  int _presentationRevision = -1;
  EditableLinePaint _paintState = const EditableLinePaint.empty();
  double? _selectionPaintExtent;
  _EditableSelectionPaintGeometry? _selectionPaintGeometry;
  EditableLinePaint? _selectionPaintGeometryState;
  bool _selectionPaintGeometrySlowPath = false;
  int _selectionPaintGeometryLayoutGeneration = -1;
  Size? _selectionPaintGeometrySize;
  int _layoutGeneration = 0;
  bool _textDirty = true;
  double _layoutedMinWidth = -1;
  double _layoutedWidth = -1;
  bool _blockCaretLayout = false;

  /// 性能探针（仅 debug 递增）：真实文本重排次数。
  static int debugLayoutCount = 0;

  /// 性能探针（仅 debug 递增）：单行整体绘制次数。
  static int debugPaintCount = 0;

  /// 性能探针（仅 debug 递增）：选区背景的实际绘制调用次数（矩形或合并路径）。
  static int debugSelectionPaintCount = 0;

  /// 性能探针（仅 debug 递增）：内部选区 paint 几何重建次数。
  @visibleForTesting
  static int debugSelectionGeometryBuildCount = 0;

  /// 性能探针（仅 debug 递增）：内部选区 paint 路径实际查询 Paragraph 盒的次数。
  @visibleForTesting
  static int debugSelectionPaintBoxQueryCount = 0;

  /// 性能探针（仅 debug 递增）：选中文字 overlay painter 创建次数。
  @visibleForTesting
  static int debugSelectionOverlayPainterCreateCount = 0;

  /// 性能探针（仅 debug 递增）：选中文字 overlay 绘制次数。
  @visibleForTesting
  static int debugSelectionOverlayPaintCount = 0;

  /// 性能探针（仅 debug 递增）：内部 caret 矩形绘制次数。
  static int debugCaretPaintCount = 0;

  /// 性能探针（仅 debug 递增）：单行渲染实例创建次数。
  static int debugCreatedCount = 0;

  /// 性能探针（仅 debug 递增）：渲染层从超长行读取的累计 UTF-16 数。
  static int debugRenderReadCodeUnits = 0;

  /// 性能探针：当前渲染帧累计读取的 UTF-16 数。
  static int debugCurrentFrameRenderReadCodeUnits = 0;

  /// 性能探针：复位后任一渲染帧的最大累计读取 UTF-16 数。
  static int debugMaxFrameRenderReadCodeUnits = 0;

  /// 性能探针（仅 debug 更新）：任何行 Paragraph 收到的最大 UTF-16 数。
  static int debugMaxParagraphCodeUnits = 0;

  /// 性能探针（仅 debug 递增）：超长行窗口真实重排次数。
  static int debugWindowLayoutCount = 0;

  /// 诊断探针（仅 debug 递增）：旧 composer 因不支持 slice 合同而降级纯文本的次数。
  static int debugLongLineComposerFallbackCount = 0;

  /// 诊断探针（仅 debug 递增）：替代 glyph 已进入真实 paint 路径的次数。
  static int debugPlaceholderPaintCount = 0;

  /// 复位全部性能探针。
  static void debugResetCounters() {
    debugLayoutCount = 0;
    debugPaintCount = 0;
    debugSelectionPaintCount = 0;
    debugSelectionGeometryBuildCount = 0;
    debugSelectionPaintBoxQueryCount = 0;
    debugSelectionOverlayPainterCreateCount = 0;
    debugSelectionOverlayPaintCount = 0;
    debugCaretPaintCount = 0;
    debugCreatedCount = 0;
    debugRenderReadCodeUnits = 0;
    debugCurrentFrameRenderReadCodeUnits = 0;
    debugMaxFrameRenderReadCodeUnits = 0;
    debugMaxParagraphCodeUnits = 0;
    debugWindowLayoutCount = 0;
    debugLongLineComposerFallbackCount = 0;
    debugPlaceholderPaintCount = 0;
  }

  /// 记录一次超长行窗口正文读取，供渲染预算测试使用。
  static void debugRecordRenderRead(int codeUnits) {
    assert(() {
      debugRenderReadCodeUnits += codeUnits;
      debugCurrentFrameRenderReadCodeUnits += codeUnits;
      debugMaxFrameRenderReadCodeUnits = math.max(
        debugMaxFrameRenderReadCodeUnits,
        debugCurrentFrameRenderReadCodeUnits,
      );
      return true;
    }());
  }

  /// 开始新的渲染读取预算帧，保留历史峰值并清零当前帧。
  static void debugBeginRenderReadFrame() {
    assert(() {
      debugMaxFrameRenderReadCodeUnits = math.max(
        debugMaxFrameRenderReadCodeUnits,
        debugCurrentFrameRenderReadCodeUnits,
      );
      debugCurrentFrameRenderReadCodeUnits = 0;
      return true;
    }());
  }

  /// 记录一次送入 Paragraph 的 UTF-16 长度，覆盖共享与临时测量路径。
  static void debugRecordParagraph(int codeUnits) {
    assert(() {
      debugMaxParagraphCodeUnits = math.max(debugMaxParagraphCodeUnits, codeUnits);
      return true;
    }());
  }

  /// 每条虚拟行独立保留显示列表：caret 闪烁、选区拖动与单行编辑只重绘
  /// 命中的行，不把祖先 sliver 的整段可见窗口一并重新 paint。挂载行数由
  /// ElScrollView 的 viewport + cacheExtent 严格约束，因此 layer 数不会随全文增长。
  @override
  bool get isRepaintBoundary => true;

  EditableRenderScope get scope => _scope;
  set scope(EditableRenderScope value) {
    if (identical(_scope, value)) return;
    if (attached) {
      _scope.unregisterLine(_index, this);
      _scope.removeListener(_onScopeChanged);
      if (_active) value.registerLine(_index, this);
      value.addListener(_onScopeChanged);
    }
    _scope = value;
    _inline = null;
    // 修订号只在各自 scope 内有效，换宿主必须丢弃旧配置快照。
    _configRevision = -1;
    _lastConfig = null;
    _lastViewportWidth = -1;
    _contentLoaded = false;
    _refresh();
  }

  int get index => _index;
  set index(int value) {
    if (_index == value) return;
    if (attached) _scope.unregisterLine(_index, this);
    _index = value;
    if (attached && _active) _scope.registerLine(_index, this);
    _contentLoaded = false;
    _refresh();
  }

  bool _active = true;

  /// 是否处于显示中的槽位。回收列表关闭空闲槽位的 TickerMode，停放的行退出挂载表与文档选区，
  /// 避免编辑器几何、光标定位和选区把不再绘制的旧行当成当前行。
  bool get active => _active;
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    if (!attached) return;
    if (value) {
      _scope.registerLine(_index, this);
      _selectionParticipant.reattachSelectionRoot();
      _refresh();
    } else {
      _selectionParticipant.detachFromSelectionRoot();
      _scope.unregisterLine(_index, this);
    }
  }

  /// 当前逻辑行稳定身份。
  Object get identity => _identity;
  set identity(Object value) {
    if (identical(_identity, value)) return;
    final previous = _identity;
    _identity = value;
    if (_inline != null) _textDirty = true;
    _inline = null;
    if (attached) _scope.lineIdentityChanged(previous);
    _contentLoaded = false;
    _refresh();
    // painter 可复用，但新 identity 必须重新执行 performLayout 上报宽度/coverage。
    markNeedsLayout();
  }

  /// 布局干净时暴露已排版 painter 给 scope 的几何查询借用；脏则返回 null，
  /// 由 scope 落到共享测量 painter。
  TextPainter? get layoutedPainter {
    if (_window != null || _textDirty || !hasSize) return null;
    return _painter;
  }

  /// 超长行当前窗口的真实 painter；offset 属于 [layoutWindow]，绝非完整行。
  TextPainter? get windowPainter {
    if (_window == null || _window!.placeholder || _textDirty || !hasSize) return null;
    return _painter;
  }

  /// 超长行当前有界布局窗口；短行返回 null。
  EditableLineLayoutWindow? get layoutWindow => _window;

  /// 当前是否使用超长行窗口排版，仅供白盒测试读取。
  @visibleForTesting
  bool get windowedForTest => _window != null;

  /// 当前超长行窗口 Paragraph 的 UTF-16 长度，仅供白盒测试读取。
  @visibleForTesting
  int get windowTextLengthForTest =>
      _window?.isVisual == true ? _window!.totalParagraphCodeUnits : _window?.text.length ?? _text.length;

  /// 当前窗口真实正文的 UTF-16 长度，不含 visual synthetic controls。
  @visibleForTesting
  int get windowContentLengthForTest => _window?.totalContentCodeUnits ?? _text.length;

  /// 当前超长行是否只能绘制不进入模型的有界占位符。
  @visibleForTesting
  bool get windowPlaceholderForTest => _window?.placeholder ?? false;

  /// 当前有界正文在逻辑行中的起点，仅供字素边界测试。
  @visibleForTesting
  int get windowStartForTest => _window?.textStart ?? 0;

  /// 当前有界正文在逻辑行中的终点，仅供字素边界测试。
  @visibleForTesting
  int get windowEndForTest => _window?.textEnd ?? _text.length;

  /// 当前 Paragraph 的实际纯文本，仅供验证占位不混入模型。
  @visibleForTesting
  String get paragraphTextForTest => _text;

  /// 当前逻辑行的真实 UTF-16 长度。
  int get lineTextLength => _window?.lineLength ?? _text.length;

  /// 当前行 Paragraph 的首选行高。
  double get preferredLineHeight => _scope.usesFixedLineHeight ? _scope.fixedLineHeight : _painter.preferredLineHeight;

  /// 下一帧预算恢复后重试当前超长行占位窗口。
  void retryLongLineWindowHydration() {
    if (_window == null) return;
    _contentLoaded = false;
    _refresh();
  }

  /// 当前绘制快照；仅供渲染状态白盒测试读取。
  @visibleForTesting
  EditableLinePaint get paintStateForTest => _paintState;

  /// 当前内部选区的连续背景行带，仅供绘制几何白盒测试。
  @visibleForTesting
  List<Rect> get selectionBandRectsForTest {
    if (!_paintState.hasSelection || !hasSize || _textDirty) return const <Rect>[];
    if (paintsEditingInLayer && selectionFillsLine) return <Rect>[Offset.zero & size];
    return _selectionPaintGeometryFor(_paintState, slowPath: _selectionUsesOverlay).bands;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scope.addListener(_onScopeChanged);
    if (_active) {
      _scope.registerLine(_index, this);
      _selectionParticipant.reattachSelectionRoot();
    }
    _refresh();
  }

  @override
  void detach() {
    _selectionParticipant.detachFromSelectionRoot();
    _scope.unregisterLine(_index, this);
    _scope.removeListener(_onScopeChanged);
    super.detach();
  }

  @override
  void dispose() {
    _selectionParticipant.dispose();
    _editingForegroundLayer?.layer = null;
    _selectionTextPainter?.dispose();
    _selectionTextPainter = null;
    _painter.dispose();
    super.dispose();
  }

  void _onScopeChanged() => _refresh();

  /// 与 scope 状态对齐：diff 出最小失效。
  void _refresh() {
    final docRevision = _scope.controller.docRevision;
    final configRev = _scope.configRevision;
    final systemFontsRev = _scope.systemFontsRevision;
    final presentationRev = _scope.controller.presentationRevision;
    final windowRevision = _scope.longLineWindowRevision;
    final systemFontsChanged = systemFontsRev != _systemFontsRevision;
    final configChanged = configRev != _configRevision;
    final layoutConfigChanged =
        configChanged &&
        (_lastConfig == null || _lastViewportWidth != _scope.viewportWidth || !_config.hasSameLayout(_lastConfig!));
    final presentationChanged = presentationRev != _presentationRevision;
    final documentChanged = docRevision != _docRevision;
    final usesWindow = _scope.usesWindowedLineLayout(_index);
    final windowKindChanged = usesWindow != (_window != null);
    final windowChanged = usesWindow && windowRevision != _longLineWindowRevision;
    final windowCacheLost = usesWindow && _window != null && !_scope.retainsLongLineWindow(_identity);
    final documentNeedsRead =
        documentChanged && (!usesWindow || _window == null || !_scope.retainsLongLineWindow(_identity));
    final reloadContent =
        !_contentLoaded ||
        documentNeedsRead ||
        layoutConfigChanged ||
        windowKindChanged ||
        windowChanged ||
        windowCacheLost;
    var contentChanged = false;
    if (reloadContent) {
      if (usesWindow) {
        final previousWindow = _window;
        final nextWindow = _scope.longLineWindowFor(_index, _identity);
        contentChanged = !_sameWindow(previousWindow, nextWindow);
        if (!contentChanged && previousWindow != null) {
          _scope.acknowledgeEquivalentLongLineWindow(_identity, previousWindow, nextWindow);
        }
        _window = nextWindow;
        _text = nextWindow.paragraphText;
      } else {
        final nextText = _scope.lineTextOf(_index);
        contentChanged = _window != null || nextText != _text;
        _window = null;
        _text = nextText;
      }
      _contentLoaded = true;
      _longLineWindowRevision = windowRevision;
    }
    _docRevision = docRevision;
    final inlineComposing = _scope.controller.inlineContent.isEmpty ? TextRange.empty : _scope.controller.composing;
    final inlineComposingChanged = inlineComposing != _inlineComposing;
    _inlineComposing = inlineComposing;
    if (contentChanged || layoutConfigChanged || systemFontsChanged || presentationChanged || inlineComposingChanged) {
      _textDirty = true;
      markNeedsLayout();
    } else if (configChanged && !_textDirty) {
      // TextPainter 对纯绘制 span 复用既有几何，颜色变化不能重新读取或排版正文。
      _configurePainter();
      markNeedsPaint();
    }
    if (reloadContent || configChanged || systemFontsChanged || presentationChanged) {
      _configRevision = configRev;
      _lastConfig = _config;
      _lastViewportWidth = _scope.viewportWidth;
      _systemFontsRevision = systemFontsRev;
      _presentationRevision = presentationRev;
      if (systemFontsChanged) _painter.markNeedsLayout();
    }
    // composing 期间视觉 caret 临时恢复细线，但横向尾余量仍跟持久 overwrite
    // mode，避免每次候选组合开始/结束都让已知宽度索引抖动。
    final blockCaretLayout = _scope.controller.overwriteMode;
    if (blockCaretLayout != _blockCaretLayout) {
      _blockCaretLayout = blockCaretLayout;
      markNeedsLayout();
    }
    final paintState = _scope.paintStateOf(_index);
    if (paintState != _paintState) {
      final selectionGeometryChanged = !_paintState.selectionsEqual(paintState);
      _paintState = paintState;
      if (selectionGeometryChanged) _invalidateSelectionPaintGeometry();
      if (!paintsEditingInLayer) markNeedsPaint();
    }
  }

  static bool _sameWindow(EditableLineLayoutWindow? previous, EditableLineLayoutWindow next) =>
      previous != null &&
      previous.lineLength == next.lineLength &&
      previous.textStart == next.textStart &&
      previous.text == next.text &&
      previous.shapingCoreStart == next.shapingCoreStart &&
      previous.shapingCoreEnd == next.shapingCoreEnd &&
      previous.paragraphText == next.paragraphText &&
      previous.placeholder == next.placeholder &&
      (previous.originX - next.originX).abs() <= _geometryTolerance &&
      (previous.estimatedTextWidth - next.estimatedTextWidth).abs() <= _geometryTolerance &&
      previous.textDirection == next.textDirection &&
      previous.totalContentCodeUnits == next.totalContentCodeUnits &&
      previous.totalParagraphCodeUnits == next.totalParagraphCodeUnits &&
      previous.visualGeneration == next.visualGeneration &&
      previous.visualMetricRevision == next.visualMetricRevision &&
      previous.visualFirstTile == next.visualFirstTile &&
      previous.visualEndTile == next.visualEndTile &&
      previous.visualTileCount == next.visualTileCount &&
      listEquals(previous.zeroWidthLogicalRanges, next.zeroWidthLogicalRanges) &&
      _sameVisualFragments(previous, next);

  static bool _sameVisualFragments(EditableLineLayoutWindow previous, EditableLineLayoutWindow next) {
    final previousFragments = previous.visualFragments;
    final nextFragments = next.visualFragments;
    final previousRanges = previous.fragmentContentRanges;
    final nextRanges = next.fragmentContentRanges;
    if (previousFragments.length != nextFragments.length || previousRanges.length != nextRanges.length) return false;
    for (var index = 0; index < previousFragments.length; index++) {
      final left = previousFragments[index];
      final right = nextFragments[index];
      if (left.lineStart != right.lineStart ||
          left.lineEnd != right.lineEnd ||
          left.text != right.text ||
          left.resolvedLevel != right.resolvedLevel ||
          (left.logicalTabPrefix - right.logicalTabPrefix).abs() > _geometryTolerance ||
          previousRanges[index] != nextRanges[index]) {
        return false;
      }
    }
    return true;
  }

  EditableRenderConfig get _config => _scope.config;

  void _configurePainter() {
    final window = _window;
    final InlineSpan span;
    if (window?.placeholder ?? false) {
      span = TextSpan(text: _text, style: _config.textStyle);
    } else if (window?.isVisual ?? false) {
      span = _scope.spanForVisualWindow(_index, window!);
    } else {
      span = _scope.spanForText(
        _index,
        _text,
        tabInitialAdvance: window?.logicalPrefixAdvance ?? 0.0,
        completeLine: window == null,
        textStart: window?.textStart ?? 0,
        lineLength: window?.lineLength,
      );
    }
    final model = _config.obscureText || (window?.placeholder ?? false) ? null : _scope.controller.inlineContentModel;
    if (model != null) {
      final lineStart = _scope.controller.document.lineStart(_index);
      final composing = _inlineComposing;
      // 纯光标移动和绘制样式变化复用匹配结果。
      if (_inline == null ||
          _inline!.source != _text ||
          !identical(_inlineTable, model) ||
          _projectionComposing != composing) {
        final start = (composing.start - lineStart).clamp(0, lineTextLength);
        final end = (composing.end - lineStart).clamp(0, lineTextLength);
        final excluded = !composing.isValid || start >= end
            ? const <TextRange>[]
            : window?.paragraphRangesForPainting(start, end) ?? [TextRange(start: start, end: end)];
        _inline = InlineTextProjection(_text, model, excluded: excluded, previous: _inline);
        _inlineTable = model;
        _projectionComposing = composing;
      }
      if (_inline!.slots.isEmpty) {
        if (_painter is InlineTextPainter) {
          _painter.dispose();
          _painter = TextPainter();
        }
      } else if (_painter is! InlineTextPainter) {
        _painter.dispose();
        _painter = InlineTextPainter(_inline!);
      } else {
        (_painter as InlineTextPainter).projection = _inline!;
      }
    } else {
      _inline = null;
      _inlineTable = null;
      if (_painter is InlineTextPainter) {
        _painter.dispose();
        _painter = TextPainter();
      }
    }
    _painter
      ..text = _inline?.slots.isNotEmpty == true ? _inline!.buildSpan(span) : span
      ..textDirection = window?.textDirection ?? _config.textDirection
      ..textAlign = window?.isVisual == true ? TextAlign.left : _config.textAlign
      ..textScaler = _config.textScaler
      ..strutStyle = _scope.strutStyleFor(span);
    _updateInlineDimensions();
  }

  TextRange _projectionComposing = TextRange.empty;

  void _updateInlineDimensions() {
    final projection = _inline;
    if (projection == null || projection.slots.isEmpty) {
      _inlineDimensions = null;
      _painter.setPlaceholderDimensions(null);
      return;
    }
    Size slotSize(InlineContentSlot slot) {
      final size = slot.measuredSize ?? _scope.inlineEstimatedSize(slot.match.token);
      return Size(size.width, math.min(size.height, _scope.fixedLineHeight));
    }

    _inlineDimensions = [
      for (final slot in projection.slots)
        PlaceholderDimensions(
          size: slotSize(slot),
          alignment: .baseline,
          baseline: .alphabetic,
          baselineOffset: _scope.fixedBaseline - (_scope.fixedLineHeight - slotSize(slot).height) / 2,
        ),
    ];
    _painter.setPlaceholderDimensions(_inlineDimensions);
  }

  void _ensureTextLaidOut(double maxWidth, {double minWidth = 0.0}) {
    if (!_textDirty && _layoutedMinWidth == minWidth && _layoutedWidth == maxWidth) return;
    _configurePainter();
    _painter.layout(minWidth: minWidth, maxWidth: maxWidth);
    _inlineBoxes = _inline == null ? null : _painter.inlinePlaceholderBoxes;
    _layoutGeneration++;
    _invalidateSelectionPaintGeometry();
    assert(() {
      debugLayoutCount++;
      debugRecordParagraph(_text.length);
      if (_window != null) debugWindowLayoutCount++;
      return true;
    }());
    _textDirty = false;
    _layoutedMinWidth = minWidth;
    _layoutedWidth = maxWidth;
  }

  double get _caretTrailingExtent =>
      (_blockCaretLayout ? _scope.blockCaretFallbackWidth(_painter) : _config.caretWidth) + 2.0;

  double get _wrapWidth {
    if (!_config.softWrap) return double.infinity;
    return constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
  }

  double _resolveTextMinWidth(double maxWidth, {required double constraintMinWidth}) {
    if (_config.softWrap) return maxWidth.isFinite ? maxWidth : 0.0;
    // 双轴滚动给行的是无界约束，不能从 constraints 猜视口；scope 由外层
    // render 宿主推入真实内容宽，并按 Flutter RenderEditable 预留 caret 尾距。
    final viewportWidth = math.max(_scope.viewportWidth, constraintMinWidth);
    if (_blockCaretLayout && _textDirty) _configurePainter();
    return math.max(0.0, viewportWidth - _caretTrailingExtent);
  }

  double _laidOutTextHeight() {
    if (!_scope.usesFixedLineHeight) {
      return _text.isEmpty ? _painter.preferredLineHeight : _painter.height;
    }
    if (!_config.softWrap || _window != null) return _scope.fixedLineHeight;
    final visualLineCount = math.max(1, _painter.computeLineMetrics().length);
    return visualLineCount * _scope.fixedLineHeight;
  }

  double _textPaintOffsetY = 0;

  /// 字形在固定行带内的实际垂直绘制偏移，供像素对齐测试读取。
  @visibleForTesting
  double get textPaintOffsetYForTest => _textPaintOffsetY;

  @override
  void performLayout() {
    _layoutLine();
    _selectionParticipant.updateSelectionGeometry();
  }

  void _layoutLine() {
    final previousSize = hasSize ? size : null;
    final window = _window;
    final wrapWidth = window == null ? _wrapWidth : double.infinity;
    final minWidth = window == null ? _resolveTextMinWidth(wrapWidth, constraintMinWidth: constraints.minWidth) : 0.0;
    _ensureTextLaidOut(wrapWidth, minWidth: minWidth);
    _layoutInlineChildren(wrapWidth, minWidth);
    _scope.reportLayoutWidth(wrapWidth, minWidth: minWidth);
    final height = _laidOutTextHeight();
    // nowrap（双轴）下宽度 = 文本宽 + caret 停在行尾的余量；wrap 下撑满可用宽，
    // 行尾点击 / 行内空白命中都落在本行盒内。
    final intrinsicWidth = window?.estimatedTextWidth ?? _painter.width;
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : intrinsicWidth + _caretTrailingExtent;
    size = constraints.constrain(Size(width, height));
    // 行带与 caret 保持固定几何，字形补偿引擎基线取整及视口的物理像素占位取整。
    _textPaintOffsetY = _scope.usesFixedLineHeight ? _scope.fixedTextPaintOffset(size.height, height) : 0;
    if (size != previousSize) _invalidateSelectionPaintGeometry();
    if (!_config.softWrap) {
      if (window == null) {
        _scope.reportLineWidth(
          _identity,
          textWidth: _painter.maxIntrinsicWidth,
          insertTrailingExtent: _config.caretWidth + 2.0,
          overwriteTrailingExtent: _scope.blockCaretFallbackWidth(_painter) + 2.0,
        );
      } else {
        if (window.isVisual) {
          _scope.reportLongLineVisualTileWidths(_identity, window, _painter, line: _index);
        }
        _window = _scope.reportLongLineWindow(
          _identity,
          window,
          paragraphWidth: _painter.maxIntrinsicWidth,
          paragraphPainter: _painter,
          insertTrailingExtent: _config.caretWidth + 2.0,
          overwriteTrailingExtent: _scope.blockCaretFallbackWidth(_painter) + 2.0,
        );
        final resolvedWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _window!.estimatedTextWidth + _caretTrailingExtent;
        size = constraints.constrain(Size(resolvedWidth, height));
        _invalidateSelectionPaintGeometry();
      }
    }
  }

  Rect _inlineVisibleRect() {
    // 最近的滚动裁剪区即本行的纵向窗口；首次布局退回有限视口估计。
    // 不换行时纵向视口铺满整段内容宽，横向可见区取 scope 记录的横向偏移与视口宽：
    // 布局期间外层横向视口尚未定尺寸，不能沿父链求变换。
    Rect? visible;
    RenderObject child = this;
    RenderObject? ancestor = parent;
    while (ancestor != null) {
      final clip = ancestor is ScrollViewport
          ? (ancestor.hasSize ? ancestor.contentViewportRect : Offset.zero & ancestor.constraints.biggest)
          : ancestor.describeApproximatePaintClip(child);
      if (clip != null) {
        final transform = getTransformTo(ancestor);
        if (transform.invert() != 0) {
          visible = MatrixUtils.transformRect(transform, clip);
          break;
        }
      }
      child = ancestor;
      ancestor = ancestor.parent;
    }
    final horizontal = Rect.fromLTWH(_scope.horizontalPixels, 0, math.max(1, _scope.viewportWidth), 600);
    if (visible == null) return horizontal.inflate(100);
    if (_config.softWrap) return visible.inflate(100);
    return Rect.fromLTRB(
      math.max(visible.left, horizontal.left),
      visible.top,
      math.max(math.max(visible.left, horizontal.left), math.min(visible.right, horizontal.right)),
      visible.bottom,
    ).inflate(100);
  }

  List<int> _visibleInlineIndices(Rect visible) {
    final boxes = _inlineBoxes;
    if (boxes == null || boxes.isEmpty) return const [];
    final shift = Offset(_window?.originX ?? 0, 0);
    final rect = visible.shift(-shift);
    final height = _scope.fixedLineHeight;
    double bandTop(ui.TextBox box) => ((box.top + box.bottom) / (2 * height)).floor() * height;
    var lo = 0;
    var hi = boxes.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (bandTop(boxes[mid]) + height < rect.top) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final result = <int>[];
    for (var i = lo; i < boxes.length && bandTop(boxes[i]) <= rect.bottom; i++) {
      if (boxes[i].right >= rect.left && boxes[i].left <= rect.right) result.add(i);
    }
    return result;
  }

  void _layoutInlineChildren(double maxWidth, double minWidth) {
    if ((_inline == null || _inline!.slots.isEmpty) && firstChild == null) return;
    final visible = _inlineVisibleRect();
    var changed = false;
    for (var pass = 0; pass < 4; pass++) {
      final indices = _visibleInlineIndices(visible);
      invokeLayoutCallback<BoxConstraints>((_) => _reconcileInline?.call(_inline, indices));
      final slots = <Object, int>{for (final i in indices) _inline!.identityAt(i): i};
      var sizesChanged = false;
      var child = firstChild;
      while (child != null) {
        final data = child.parentData! as _InlineParentData;
        final index = slots[data.identity]!;
        child.layout(BoxConstraints(maxWidth: maxWidth, maxHeight: _scope.fixedLineHeight), parentUsesSize: true);
        final slot = _inline!.slots[index];
        if (slot.measuredSize != child.size) {
          slot.measuredSize = child.size;
          _scope.rememberInlineSize(slot.match.token, child.size);
          sizesChanged = true;
        }
        child = data.nextSibling;
      }
      if (!sizesChanged) break;
      changed = true;
      _updateInlineDimensions();
      _painter.layout(minWidth: minWidth, maxWidth: maxWidth);
      _inlineBoxes = _painter.inlinePlaceholderBoxes;
      _layoutGeneration++;
      _selectionTextSource = null;
      _invalidateSelectionPaintGeometry();
    }
    final projection = _inline;
    if (projection != null) {
      final indices = _visibleInlineIndices(visible);
      // 最后一轮修正可能推出旧节点，下一帧收敛新增的可见节点。
      final positions = <Object, int>{for (final i in indices) projection.identityAt(i): i};
      var child = firstChild;
      while (child != null) {
        final data = child.parentData! as _InlineParentData;
        final index = positions[data.identity];
        data.offset = index == null
            ? const Offset(-1e8, -1e8)
            : _inlineBoxes![index].toRect().topLeft + Offset(_window?.originX ?? 0, 0);
        child = data.nextSibling;
      }
    }
    if (changed) _scope.onInlineLayoutChanged?.call();
  }

  void _invalidateSelectionPaintGeometry() {
    _selectionPaintGeometry = null;
    _selectionPaintGeometryState = null;
    _selectionPaintGeometrySize = null;
  }

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    _ensureTextLaidOut(_window == null && _config.softWrap && width.isFinite ? width : double.infinity);
    return _laidOutTextHeight();
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) {
    _ensureTextLaidOut(double.infinity);
    return (_window?.estimatedTextWidth ?? _painter.width) + _caretTrailingExtent;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final maxWidth = _window == null && _config.softWrap && constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : double.infinity;
    final minWidth = _window == null ? _resolveTextMinWidth(maxWidth, constraintMinWidth: constraints.minWidth) : 0.0;
    _ensureTextLaidOut(maxWidth, minWidth: minWidth);
    final height = _laidOutTextHeight();
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : (_window?.estimatedTextWidth ?? _painter.width) + _caretTrailingExtent;
    return constraints.constrain(Size(width, height));
  }

  @override
  bool hitTestSelf(Offset position) => true;

  // ===========================================================================
  // 几何查询（视图层指针命中用；行内坐标）
  // ===========================================================================

  /// 行内坐标 → 行内文本位置。
  TextPosition positionForOffset(Offset local) {
    final window = _window;
    if (window == null) return _painter.getPositionForOffset(local);
    if (window.placeholder) return _scope.estimatedLongLinePositionForX(_index, local.dx);
    final paragraphX = local.dx - window.originX;
    final knownLeft = !window.isVisual && window.textStart == 0 && window.textDirection == TextDirection.ltr;
    final knownRight =
        !window.isVisual && window.textEnd == window.lineLength && window.textDirection == TextDirection.ltr;
    if ((paragraphX >= -_geometryTolerance || knownLeft) &&
        (paragraphX <= _painter.width + _geometryTolerance || knownRight)) {
      final mapped = window.toLinePosition(_painter.getPositionForOffset(Offset(paragraphX, local.dy)));
      if (window.isVisual) {
        final indexed = _scope.estimatedLongLinePositionForX(_index, local.dx);
        if (indexed.offset == mapped.offset) {
          return TextPosition(offset: mapped.offset, affinity: indexed.affinity);
        }
      }
      return mapped;
    }
    return _scope.estimatedLongLinePositionForX(_index, local.dx);
  }

  /// caret 几何（行内坐标，整行高）。
  Rect caretRectFor(TextPosition localPosition, {int overwriteEnd = -1}) {
    final window = _window;
    if (window == null) {
      return _scope.caretRectForPainter(
        _painter,
        localPosition,
        overwriteEnd: overwriteEnd,
        availableWidth: hasSize ? size.width : null,
      );
    }
    if (!window.placeholder && window.containsPosition(localPosition)) {
      final paragraphPosition = window.toParagraphPosition(localPosition);
      if (window.isVisual) {
        return _visualCaretRectFor(
          window,
          localPosition,
          paragraphPosition,
          overwriteEnd: overwriteEnd,
        ).shift(Offset(window.originX, 0));
      }
      final paragraphOverwriteEnd = overwriteEnd < 0
          ? -1
          : overwriteEnd > window.textEnd
          ? -1
          : (overwriteEnd - window.textStart).clamp(paragraphPosition.offset, window.text.length);
      return _scope
          .caretRectForPainter(_painter, paragraphPosition, overwriteEnd: paragraphOverwriteEnd, availableWidth: null)
          .shift(Offset(window.originX, 0));
    }
    final x = _scope.estimatedLongLineXForOffset(_index, localPosition.offset, affinity: localPosition.affinity);
    final width = overwriteEnd >= localPosition.offset ? _scope.blockCaretFallbackWidth(_painter) : _config.caretWidth;
    final left = _scope.longLineRunIsRtl(_index, localPosition.offset, affinity: localPosition.affinity)
        ? x - width
        : x;
    return Rect.fromLTWH(left, 0, width, preferredLineHeight);
  }

  /// collapsed 前景原语的字符单元矩形，统一处理字体 fallback、bidi 与长行窗口。
  Rect collapsedCharacterCellRectFor(TextPosition localPosition, {double widthInCharacters = 1}) {
    if (localPosition.offset < 0 || localPosition.offset > lineTextLength) {
      throw RangeError.range(localPosition.offset, 0, lineTextLength, 'localPosition.offset');
    }
    if (!widthInCharacters.isFinite || widthInCharacters < 0.1 || widthInCharacters > 64) {
      throw ArgumentError.value(widthInCharacters, 'widthInCharacters', '必须位于 0.1 到 64 之间');
    }
    final caret = caretRectFor(localPosition);
    final width = _scope.blockCaretFallbackWidth(_painter) * widthInCharacters;
    final isRtl = _collapsedCharacterCellIsRtl(localPosition, caret);
    return Rect.fromLTWH(isRtl ? caret.right - width : caret.left, caret.top, width, caret.height);
  }

  bool _collapsedCharacterCellIsRtl(TextPosition localPosition, Rect caret) {
    if (_window != null) {
      return _scope.longLineRunIsRtl(_index, localPosition.offset, affinity: localPosition.affinity);
    }
    final lineLength = lineTextLength;
    if (lineLength == 0) {
      return _painter.textDirection == TextDirection.rtl;
    }
    final document = _scope.controller.document;
    final lineStart = document.lineStart(_index);
    final lineEnd = lineStart + lineLength;
    final readsPrevious = localPosition.affinity == TextAffinity.upstream || localPosition.offset == lineLength;
    final start = readsPrevious
        ? previousTextGraphemeBoundary(
            document,
            lineStart + localPosition.offset,
            lowerBound: lineStart,
            upperBound: lineEnd,
          )
        : lineStart + localPosition.offset;
    final end = readsPrevious
        ? lineStart + localPosition.offset
        : nextTextGraphemeBoundary(
            document,
            lineStart + localPosition.offset,
            lowerBound: lineStart,
            upperBound: lineEnd,
          );
    final boxes = selectionBoxesForLineRange(start - lineStart, end - lineStart);
    ui.TextBox? closest;
    var closestDistance = double.infinity;
    for (final box in boxes) {
      final rect = box.toRect();
      if (rect.bottom <= caret.top + _geometryTolerance || rect.top >= caret.bottom - _geometryTolerance) {
        continue;
      }
      final distance = math.min((rect.left - caret.left).abs(), (rect.right - caret.right).abs());
      if (distance < closestDistance) {
        closest = box;
        closestDistance = distance;
      }
    }
    return (closest?.direction ?? _painter.textDirection) == TextDirection.rtl;
  }

  Rect _visualCaretRectFor(
    EditableLineLayoutWindow window,
    TextPosition linePosition,
    TextPosition paragraphPosition, {
    required int overwriteEnd,
  }) {
    if (window.visualFragments.isEmpty) {
      final overwrite = overwriteEnd >= linePosition.offset;
      final width = overwrite ? _scope.blockCaretFallbackWidth(_painter) : _config.caretWidth;
      final left = _config.textDirection == TextDirection.rtl ? -width : 0.0;
      return Rect.fromLTWH(left, 0, width, preferredLineHeight);
    }
    final thin = _scope.caretRectForPainter(_painter, paragraphPosition, overwriteEnd: -1, availableWidth: null);
    if (overwriteEnd < linePosition.offset) return thin;
    if (overwriteEnd > linePosition.offset) {
      final overwriteRange = window.paragraphRangeForContainedLogicalRange(linePosition.offset, overwriteEnd);
      final zeroWidthCovered =
          overwriteRange == null &&
          _containsZeroWidthLogicalRange(window.zeroWidthLogicalRanges, linePosition.offset, overwriteEnd);
      if (overwriteRange == null && !zeroWidthCovered) return thin;
      Rect? glyph;
      if (overwriteRange != null) {
        for (final box in _painter.getBoxesForSelection(
          TextSelection(baseOffset: overwriteRange.start, extentOffset: overwriteRange.end),
          boxHeightStyle: ui.BoxHeightStyle.max,
        )) {
          final rect = box.toRect();
          if (rect.bottom <= thin.top + _geometryTolerance || rect.top >= thin.bottom - _geometryTolerance) {
            continue;
          }
          glyph = glyph == null ? rect : glyph.expandToInclude(rect);
        }
      }
      if (glyph != null && glyph.width.isFinite && glyph.width > _geometryTolerance) {
        return Rect.fromLTWH(glyph.left, thin.top, math.max(glyph.width, _config.caretWidth), thin.height);
      }
    }

    final width = _scope.blockCaretFallbackWidth(_painter);
    final left = _scope.longLineRunIsRtl(_index, linePosition.offset, affinity: linePosition.affinity)
        ? thin.right - width
        : thin.left;
    return Rect.fromLTWH(left, thin.top, width, thin.height);
  }

  static bool _containsZeroWidthLogicalRange(List<TextRange> ranges, int start, int end) {
    var low = 0;
    var high = ranges.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (ranges[middle].end < end) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low < ranges.length && ranges[low].start <= start;
  }

  /// 逻辑行选区裁到当前有界 Paragraph 后的行内绘制盒。
  List<ui.TextBox> selectionBoxesForLineRange(int start, int end) =>
      _selectionBoxesForLineRange(start, end, boxHeightStyle: _scope.selectionBoxHeightStyle, recordPaintQuery: false);

  List<ui.TextBox> _selectionBoxesForLineRange(
    int start,
    int end, {
    required ui.BoxHeightStyle boxHeightStyle,
    required bool recordPaintQuery,
  }) {
    final window = _window;
    if (window == null) {
      if (end <= start) return const <ui.TextBox>[];
      return _selectionBoxesFromPainter(
        TextSelection(baseOffset: start, extentOffset: end),
        boxHeightStyle: boxHeightStyle,
        recordPaintQuery: recordPaintQuery,
      );
    }
    final ranges = window.paragraphRangesForPainting(start, end);
    if (ranges.isEmpty) return const <ui.TextBox>[];
    final boxes = <ui.TextBox>[
      for (final range in ranges)
        ..._selectionBoxesFromPainter(
          TextSelection(baseOffset: range.start, extentOffset: range.end),
          boxHeightStyle: boxHeightStyle,
          recordPaintQuery: recordPaintQuery,
        ),
    ];
    return <ui.TextBox>[
      for (final box in boxes)
        ui.TextBox.fromLTRBD(box.left + window.originX, box.top, box.right + window.originX, box.bottom, box.direction),
    ];
  }

  List<ui.TextBox> _selectionBoxesFromPainter(
    TextSelection selection, {
    required ui.BoxHeightStyle boxHeightStyle,
    required bool recordPaintQuery,
  }) {
    if (recordPaintQuery) {
      assert(() {
        debugSelectionPaintBoxQueryCount++;
        return true;
      }());
    }
    return _painter.getBoxesForSelection(selection, boxHeightStyle: boxHeightStyle);
  }

  // ===========================================================================
  // 外层选区参与者：委托 [_EditableLineSelectionContent]
  // ===========================================================================

  late final SelectionContent _selectionContent = _EditableLineSelectionContent(this);
  late final _EditableLineSelectionParticipant _selectionParticipant;

  @override
  SelectionParticipant? get selectionParticipant => _selectionParticipant;

  // ===========================================================================
  // 绘制
  // ===========================================================================

  /// 外层文档选区仍按原行内顺序绘制，避免两种选区同时存在时底色次序倒置。
  bool get paintsEditingInLayer {
    if (_scope.repaintSelectionLayer == null) return false;
    final outerRange = _selectionParticipant.currentSelectionRange;
    return outerRange == null || outerRange.isCollapsed;
  }

  /// 固定视觉行高的完整逻辑行含换行时直接填充行盒，折行也不查询字形。
  bool get selectionFillsLine => _selectionCoversLineBox && !_selectionUsesOverlay;

  bool get _selectionCoversLineBox =>
      _scope.usesFixedLineHeight &&
      _paintState.selections.length == 1 &&
      _paintState.selectionStart == 0 &&
      _paintState.selectionEnd == lineTextLength &&
      _paintState.selectsNewline;

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintLine(context, offset);
    _selectionParticipant.paintSelectionHandleLayers(context, offset);
  }

  @override
  bool get alwaysNeedsCompositing => hasSize && _selectionParticipant.hasSelectionHandleLayers;

  void _paintLine(PaintingContext context, Offset offset) {
    assert(() {
      debugPaintCount++;
      return true;
    }());
    final canvas = context.canvas;

    // 外层选区（岛外扫进来的）画在最底层，编辑器内部选区/文本盖其上
    final outerRange = _selectionParticipant.currentSelectionRange;
    if (outerRange != null && !outerRange.isCollapsed) {
      _selectionParticipant.paintSelectionRange(canvas, offset, outerRange, _selectionParticipant.selectionColor);
    }

    if (!paintsEditingInLayer) paintEditingBackground(canvas, offset);
    _painter.paint(canvas, offset + Offset(_window?.originX ?? 0.0, _textPaintOffsetY));
    var inlineChild = firstChild;
    while (inlineChild != null) {
      final data = inlineChild.parentData! as _InlineParentData;
      final child = inlineChild;
      final childOffset = offset + data.offset + Offset(0, _textPaintOffsetY);
      context.pushClipRect(
        needsCompositing,
        childOffset,
        Offset.zero & child.size,
        (context, offset) => context.paintChild(child, offset),
      );
      inlineChild = data.nextSibling;
    }
    if (_window?.placeholder ?? false) {
      assert(() {
        debugPlaceholderPaintCount++;
        return true;
      }());
    }
    if (!paintsEditingInLayer) {
      _paintSelectionForeground(canvas, offset);
      paintEditingIndicators(canvas, offset);
    }
  }

  /// 正文前绘制底色与覆写光标；完整行带由视口合并时跳过底色。
  void paintEditingBackground(Canvas canvas, Offset offset, {bool skipSelection = false, double? lineExtent}) {
    _selectionPaintExtent = lineExtent;
    final state = _paintState;
    final selectionUsesOverlay = state.hasSelection && _selectionUsesOverlay;
    if (state.hasSelection && !skipSelection) {
      final selectionGeometry = _selectionPaintGeometryFor(state, slowPath: selectionUsesOverlay);
      _paintSelectionRects(
        canvas,
        offset,
        selectionUsesOverlay ? selectionGeometry.supplements : selectionGeometry.bands,
      );
      if (selectionUsesOverlay && firstChild != null) {
        // 图片在正文层绘制，精确选区底色先画在其下方。
        final path = Path();
        var child = firstChild;
        while (child != null) {
          final data = child.parentData! as _InlineParentData;
          path.addRect((data.offset + offset + Offset(0, _textPaintOffsetY)) & child.size);
          child = data.nextSibling;
        }
        canvas.save();
        canvas.clipPath(path);
        _paintSelectionRects(canvas, offset, selectionGeometry.exactRects);
        canvas.restore();
      }
    }

    // block caret 是字形背板：先画底色、再让正文覆到其上，避免不透明
    // caretColor 把被覆写字形整块盖死。普通细 caret 仍最后绘制。
    _paintCarets(canvas, offset, state, overwrite: true);
  }

  /// 未变化行的选中字色与诊断保留合成层，光标变化不重新录制文字覆盖。
  void paintRetainedEditingForeground(PaintingContext context, Offset offset) {
    if (!(_paintState.hasSelection && _selectionUsesOverlay) && _config.composer is! EditableCanvasComposer) {
      _editingForegroundLayer?.layer = null;
      return;
    }
    // 背景核心与补带共用视口坐标，避免逐行缓存图层的独立像素取整造成拼接缝。
    if (_paintState.hasSelection && _selectionUsesOverlay) {
      _paintSelectionRects(
        context.canvas,
        offset,
        _selectionPaintGeometryFor(_paintState, slowPath: true).exactRects,
        excludeInline: true,
      );
    }
    final handle = _editingForegroundLayer ??= LayerHandle<OffsetLayer>();
    final geometry = (_index, _layoutGeneration, size);
    final repaint =
        handle.layer == null ||
        _foregroundGeometry != geometry ||
        !listEquals(_foregroundSelections, _paintState.selections);
    final layer = handle.layer ??= OffsetLayer();
    layer.offset = offset;
    if (repaint) {
      context.pushLayer(
        layer,
        (context, offset) => _paintSelectionForeground(context.canvas, offset, paintBackground: false),
        Offset.zero,
        childPaintBounds: Offset.zero & size,
      );
      _foregroundGeometry = geometry;
      _foregroundSelections = _paintState.selections;
    } else {
      context.addLayer(layer);
    }
  }

  void _paintSelectionForeground(Canvas canvas, Offset offset, {bool paintBackground = true}) {
    final state = _paintState;
    final selectionUsesOverlay = state.hasSelection && _selectionUsesOverlay;
    if (selectionUsesOverlay) {
      final selectionGeometry = _selectionPaintGeometryFor(state, slowPath: true);
      // 精确核心压住 composer/decoration 背景，再用同排版 overlay 恢复字形；
      // 连续行带扩高出的补带已在正文前绘制，不会染到未选字形。
      if (paintBackground) _paintSelectionRects(canvas, offset, selectionGeometry.exactRects, excludeInline: true);
      _paintSelectionTextOverlay(canvas, offset, selectionGeometry.exactRects);
    }

    final foregroundComposer = _config.composer;
    if (foregroundComposer is EditableCanvasComposer) {
      final foreground = foregroundComposer as EditableCanvasComposer;
      final window = _window;
      foreground.paintForeground(
        canvas,
        offset,
        line: _index,
        lineLength: lineTextLength,
        visibleRange: TextRange(start: window?.textStart ?? 0, end: window?.textEnd ?? lineTextLength),
        style: _config.textStyle,
        textDirection: window?.textDirection ?? _config.textDirection,
        lineHeight: preferredLineHeight,
        originX: window?.originX ?? 0,
        size: size,
        rects: (range) =>
            selectionBoxesForLineRange(range.start, range.end).map((box) => box.toRect()).toList(growable: false),
        characterCell: collapsedCharacterCellRectFor,
      );
    }
  }

  /// 组字与普通光标始终在保留的选区字色、诊断之上绘制。
  void paintEditingIndicators(Canvas canvas, Offset offset) {
    final state = _paintState;
    if (state.hasComposing && _config.composingUnderline) {
      final boxes = selectionBoxesForLineRange(state.composingStart, state.composingEnd);
      final color = _config.textStyle.color ?? _config.caretColor;
      final paint = Paint()..color = color;
      for (final box in boxes) {
        final rect = box.toRect().shift(offset);
        canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - 1.2, rect.width, 1.2), paint);
      }
    }

    _paintCarets(canvas, offset, state, overwrite: false);
  }

  bool get _selectionUsesOverlay => _config.selectionTextColor != null || _selectionTextSourceHasPaintedBackground();

  _EditableSelectionPaintGeometry _selectionPaintGeometryFor(EditableLinePaint state, {required bool slowPath}) {
    final cached = _selectionPaintGeometry;
    // 光标相位与位置不影响选区背景；选区、布局和尺寸不变即可复用几何。
    if (cached != null &&
        _selectionPaintGeometryState != null &&
        _selectionPaintGeometryState!.hasSelection == state.hasSelection &&
        _selectionPaintGeometryState!.selectionsEqual(state) &&
        _selectionPaintGeometrySlowPath == slowPath &&
        _selectionPaintGeometryLayoutGeneration == _layoutGeneration &&
        _selectionPaintGeometrySize == size) {
      return cached;
    }

    assert(() {
      debugSelectionGeometryBuildCount++;
      return true;
    }());
    final bandCandidates = <Rect>[];
    final exactCandidates = <Rect>[];
    final topBoundaryBands = <Rect>[];
    final bottomBoundaryBands = <Rect>[];
    final fullLineBand = _selectionCoversLineBox;
    if (fullLineBand) bandCandidates.add(Offset.zero & size);
    for (final selection in state.selections) {
      final firstBand = bandCandidates.length;
      if (selection.end > selection.start) {
        if (!fullLineBand) {
          for (final box in _selectionBoxesForLineRange(
            selection.start,
            selection.end,
            boxHeightStyle: _scope.selectionPaintBoxHeightStyle,
            recordPaintQuery: true,
          )) {
            final rect = _validSelectionRect(box.toRect());
            if (rect != null) bandCandidates.add(rect);
          }
          _snapSelectionBoundaryBands(
            bandCandidates,
            firstBand,
            topBoundaryBands: selection.start == 0 ? topBoundaryBands : null,
            bottomBoundaryBands: selection.end == lineTextLength ? bottomBoundaryBands : null,
          );
        }
        if (slowPath) {
          for (final box in _selectionBoxesForLineRange(
            selection.start,
            selection.end,
            boxHeightStyle: _scope.selectionBoxHeightStyle,
            recordPaintQuery: true,
          )) {
            final rect = _validSelectionRect(box.toRect());
            if (rect != null) exactCandidates.add(rect);
          }
        }
      }
      if (selection.selectsNewline && !fullLineBand) {
        final endRect = caretRectFor(TextPosition(offset: lineTextLength, affinity: TextAffinity.upstream));
        final lastBand = _lastVisualBand(bandCandidates, firstBand);
        final top = (lastBand?.top ?? endRect.top).clamp(0.0, size.height).toDouble();
        final bottom = size.height;
        if (bottom > top + _geometryTolerance) {
          final width = _scope.usesFixedLineHeight
              ? math.max(0.0, size.width - endRect.left)
              : preferredLineHeight * 0.35;
          bandCandidates.add(Rect.fromLTWH(endRect.left, top, width, bottom - top));
        }
      }
    }
    _propagateSelectionBoundaryBands(bandCandidates, topBoundaryBands, bottomBoundaryBands);

    final bands = _mergeVisualBandRects(bandCandidates);
    final exactRects = slowPath ? _mergeVisualBandRects(exactCandidates) : const <Rect>[];
    final supplements = slowPath ? _subtractSelectionRects(bands, exactRects) : const <Rect>[];
    final next = _EditableSelectionPaintGeometry(
      bands: List<Rect>.unmodifiable(bands),
      exactRects: List<Rect>.unmodifiable(exactRects),
      supplements: List<Rect>.unmodifiable(supplements),
    );
    _selectionPaintGeometry = next;
    _selectionPaintGeometryState = state;
    _selectionPaintGeometrySlowPath = slowPath;
    _selectionPaintGeometryLayoutGeneration = _layoutGeneration;
    _selectionPaintGeometrySize = size;
    return next;
  }

  Rect? _validSelectionRect(Rect rect) {
    if (!rect.left.isFinite || !rect.top.isFinite || !rect.right.isFinite || !rect.bottom.isFinite) return null;
    final top = rect.top.clamp(0.0, size.height).toDouble();
    final bottom = rect.bottom.clamp(0.0, size.height).toDouble();
    if (rect.right <= rect.left + _geometryTolerance || bottom <= top + _geometryTolerance) return null;
    return Rect.fromLTRB(rect.left, top, rect.right, bottom);
  }

  void _snapSelectionBoundaryBands(
    List<Rect> rects,
    int start, {
    required List<Rect>? topBoundaryBands,
    required List<Rect>? bottomBoundaryBands,
  }) {
    if (start >= rects.length || (topBoundaryBands == null && bottomBoundaryBands == null)) return;
    var firstTop = rects[start].top;
    var lastBottom = rects[start].bottom;
    for (var index = start + 1; index < rects.length; index++) {
      firstTop = math.min(firstTop, rects[index].top);
      lastBottom = math.max(lastBottom, rects[index].bottom);
    }
    for (var index = start; index < rects.length; index++) {
      final rect = rects[index];
      final touchesTop = topBoundaryBands != null && (rect.top - firstTop).abs() <= _geometryTolerance;
      final touchesBottom = bottomBoundaryBands != null && (rect.bottom - lastBottom).abs() <= _geometryTolerance;
      // 记录原始盒供尾部补带复用，再扩展背景边界；共用一次首末行扫描。
      if (touchesTop) topBoundaryBands.add(rect);
      if (touchesBottom) bottomBoundaryBands.add(rect);
      rects[index] = Rect.fromLTRB(
        rect.left,
        touchesTop ? 0.0 : rect.top,
        rect.right,
        touchesBottom ? size.height : rect.bottom,
      );
    }
  }

  void _propagateSelectionBoundaryBands(List<Rect> rects, List<Rect> topBoundaryBands, List<Rect> bottomBoundaryBands) {
    if (topBoundaryBands.isEmpty && bottomBoundaryBands.isEmpty) return;
    for (var index = 0; index < rects.length; index++) {
      final rect = rects[index];
      final touchesTop = topBoundaryBands.any(
        (band) =>
            (rect.bottom - band.bottom).abs() <= _geometryTolerance &&
            ((rect.top - band.top).abs() <= _geometryTolerance || rect.top == 0.0),
      );
      final touchesBottom = bottomBoundaryBands.any(
        (band) =>
            (rect.top - band.top).abs() <= _geometryTolerance &&
            ((rect.bottom - band.bottom).abs() <= _geometryTolerance || rect.bottom == size.height),
      );
      if (touchesTop || touchesBottom) {
        rects[index] = Rect.fromLTRB(
          rect.left,
          touchesTop ? 0.0 : rect.top,
          rect.right,
          touchesBottom ? size.height : rect.bottom,
        );
      }
    }
  }

  static Rect? _lastVisualBand(List<Rect> rects, int start) {
    if (start >= rects.length) return null;
    var last = rects[start];
    for (var index = start + 1; index < rects.length; index++) {
      final candidate = rects[index];
      if (candidate.bottom > last.bottom + _geometryTolerance ||
          ((candidate.bottom - last.bottom).abs() <= _geometryTolerance && candidate.top > last.top)) {
        last = candidate;
      }
    }
    return last;
  }

  static List<Rect> _mergeVisualBandRects(List<Rect> source) {
    if (source.length < 2) return List<Rect>.of(source);
    final sorted = List<Rect>.of(source)
      ..sort((left, right) {
        final top = left.top.compareTo(right.top);
        if (top != 0) return top;
        final bottom = left.bottom.compareTo(right.bottom);
        if (bottom != 0) return bottom;
        return left.left.compareTo(right.left);
      });
    final result = <Rect>[];
    var current = sorted.first;
    for (var index = 1; index < sorted.length; index++) {
      final next = sorted[index];
      final sameBand =
          (current.top - next.top).abs() <= _geometryTolerance &&
          (current.bottom - next.bottom).abs() <= _geometryTolerance;
      if (sameBand && next.left <= current.right + _geometryTolerance) {
        current = Rect.fromLTRB(
          math.min(current.left, next.left),
          math.min(current.top, next.top),
          math.max(current.right, next.right),
          math.max(current.bottom, next.bottom),
        );
      } else {
        result.add(current);
        current = next;
      }
    }
    result.add(current);
    return result;
  }

  static List<Rect> _subtractSelectionRects(List<Rect> source, List<Rect> cutters) {
    if (source.isEmpty || cutters.isEmpty) return List<Rect>.of(source);
    var fragments = List<Rect>.of(source);
    for (final cutter in cutters) {
      final next = <Rect>[];
      for (final fragment in fragments) {
        next.addAll(_subtractSelectionRect(fragment, cutter));
      }
      fragments = next;
      if (fragments.isEmpty) break;
    }
    return fragments;
  }

  static List<Rect> _subtractSelectionRect(Rect source, Rect cutter) {
    if (!source.overlaps(cutter)) return <Rect>[source];
    final overlap = source.intersect(cutter);
    final result = <Rect>[];
    void add(double left, double top, double right, double bottom) {
      if (right > left + _geometryTolerance && bottom > top + _geometryTolerance) {
        result.add(Rect.fromLTRB(left, top, right, bottom));
      }
    }

    add(source.left, source.top, source.right, overlap.top);
    add(source.left, overlap.bottom, source.right, source.bottom);
    add(source.left, overlap.top, overlap.left, overlap.bottom);
    add(overlap.right, overlap.top, source.right, overlap.bottom);
    return result;
  }

  void _paintSelectionRects(Canvas canvas, Offset offset, List<Rect> rects, {bool excludeInline = false}) {
    if (rects.isEmpty) return;
    final clipInline = excludeInline && firstChild != null;
    if (clipInline) {
      canvas.save();
      var child = firstChild;
      while (child != null) {
        final data = child.parentData! as _InlineParentData;
        canvas.clipRect((data.offset + offset + Offset(0, _textPaintOffsetY)) & child.size, clipOp: .difference);
        child = data.nextSibling;
      }
    }
    // 字形盒保留自然高度；背景底边覆盖滚动槽的实际高度，消除物理像素取整余量。
    Rect shifted(Rect rect) => rect.bottom == size.height && _selectionPaintExtent != null
        ? Rect.fromLTRB(rect.left, rect.top, rect.right, _selectionPaintExtent!).shift(offset)
        : rect.shift(offset);
    final paint = Paint()
      ..color = _config.selectionColor
      ..isAntiAlias = false;
    if (rects.length == 1) {
      canvas.drawRect(shifted(rects.single), paint);
    } else {
      // 同一选区的字形盒可能重叠，统一填充避免半透明背景重复混色。
      final path = Path();
      for (final rect in rects) {
        path.addRect(shifted(rect));
      }
      canvas.drawPath(path, paint);
    }
    if (clipInline) canvas.restore();
    assert(() {
      debugSelectionPaintCount++;
      return true;
    }());
  }

  bool _selectionTextSourceHasPaintedBackground() {
    final source = _painter.text;
    if (source == null) return false;
    if (identical(source, _selectionBackgroundSource)) return _selectionSourceHasBackground;
    _selectionBackgroundSource = source;
    _selectionSourceHasBackground = _inlineSpanHasPaintedBackground(source);
    return _selectionSourceHasBackground;
  }

  void _paintSelectionTextOverlay(Canvas canvas, Offset offset, List<Rect> selectionTextRects) {
    final color = _config.selectionTextColor;
    if (selectionTextRects.isEmpty) return;
    final path = ui.Path();
    var rectCount = 0;
    for (final rect in selectionTextRects) {
      if (rect.isEmpty) continue;
      path.addRect(rect.shift(offset));
      rectCount++;
    }
    if (rectCount == 0) return;
    final painter = _selectionTextPainterFor(color);
    if (painter == null) return;
    assert(() {
      debugSelectionOverlayPaintCount++;
      return true;
    }());
    canvas.save();
    canvas.clipPath(path, doAntiAlias: false);
    painter.paint(canvas, offset + Offset(_window?.originX ?? 0.0, _textPaintOffsetY));
    canvas.restore();
  }

  TextPainter? _selectionTextPainterFor(Color? color) {
    final source = _painter.text;
    if (source == null || _layoutedMinWidth < 0 || _layoutedWidth < 0) return null;
    final cached = _selectionTextPainter;
    if (cached != null &&
        identical(_selectionTextSource, source) &&
        _selectionTextColor == color &&
        _selectionTextConfigRevision == _configRevision &&
        _selectionTextSystemFontsRevision == _systemFontsRevision &&
        _selectionTextMinWidth == _layoutedMinWidth &&
        _selectionTextMaxWidth == _layoutedWidth) {
      return cached;
    }
    cached?.dispose();
    final next =
        TextPainter(
            text: buildSelectionOverlaySpan(source, textColor: color),
            textDirection: _window?.textDirection ?? _config.textDirection,
            textAlign: _window?.isVisual == true ? TextAlign.left : _config.textAlign,
            textScaler: _config.textScaler,
            strutStyle: _scope.strutStyleFor(source),
          )
          ..setPlaceholderDimensions(_inlineDimensions)
          ..layout(minWidth: _layoutedMinWidth, maxWidth: _layoutedWidth);
    assert(() {
      debugSelectionOverlayPainterCreateCount++;
      return true;
    }());
    _selectionTextPainter = next;
    _selectionTextSource = source;
    _selectionTextColor = color;
    _selectionTextConfigRevision = _configRevision;
    _selectionTextSystemFontsRevision = _systemFontsRevision;
    _selectionTextMinWidth = _layoutedMinWidth;
    _selectionTextMaxWidth = _layoutedWidth;
    return next;
  }

  void _paintCarets(Canvas canvas, Offset offset, EditableLinePaint state, {required bool overwrite}) {
    if (!state.hasCaret || !state.caretVisible) return;
    final color = overwrite
        ? _config.caretColor.withValues(alpha: math.min(_config.caretColor.a, 0.35))
        : _config.caretColor;
    final paint = Paint()..color = color;
    for (var index = 0; index < state.carets.length; index++) {
      if (!overwrite && state.primaryCaretSuppressed && index == 0) continue;
      final caret = state.carets[index];
      if (caret.overwrite != overwrite) continue;
      final rect = caretRectFor(
        TextPosition(offset: caret.offset, affinity: caret.upstream ? TextAffinity.upstream : TextAffinity.downstream),
        overwriteEnd: caret.overwriteEnd,
      );
      final width = math.min(rect.width, size.width);
      final maxLeft = math.max(size.width - width, 0.0);
      final clamped = Rect.fromLTWH(rect.left.clamp(0.0, maxLeft), rect.top, width, rect.height);
      canvas.drawRect(clamped.shift(offset), paint);
      assert(() {
        debugCaretPaintCount++;
        return true;
      }());
    }
  }
}

/// 编辑器单行的选区内容适配。
final class _EditableLineSelectionContent extends SelectionContent {
  _EditableLineSelectionContent(this._line);

  final RenderEditableLine _line;

  @override
  int get selectionTextLength => _line.lineTextLength;

  @override
  int selectionOffsetForLocalPosition(Offset localPosition, {required double fallbackHalfWidth}) {
    if (_line._textDirty || !_line.hasSize) return 0;
    return _line.positionForOffset(localPosition).offset.clamp(0, _line.lineTextLength);
  }

  @override
  TextRange selectionWordBoundaryAt(int offset) {
    final clamped = offset.clamp(0, _line.lineTextLength);
    if (_line._textDirty || !_line.hasSize) return TextRange.collapsed(clamped);
    final lineStart = _line._scope.controller.document.lineStart(_line._index);
    final range = _line._scope.wordBoundary(TextPosition(offset: lineStart + clamped));
    return TextRange(start: range.start - lineStart, end: range.end - lineStart);
  }

  @override
  String selectionTextForRange(TextRange range) {
    final start = range.start.clamp(0, _line.lineTextLength);
    final end = range.end.clamp(start, _line.lineTextLength);
    if (_line._config.obscureText) {
      return _line._config.obscuringCharacter * (end - start);
    }
    final document = _line._scope.controller.document;
    final lineStart = document.lineStart(_line._index);
    return document.getText(lineStart + start, lineStart + end);
  }

  @override
  SelectionCaretGeometry? selectionCaretGeometryAt(int offset) {
    if (_line._textDirty || !_line.hasSize) return null;
    final rect = _line.caretRectFor(TextPosition(offset: offset.clamp(0, _line.lineTextLength)));
    return SelectionCaretGeometry(position: rect.topLeft, lineHeight: rect.height);
  }

  @override
  List<Rect> selectionPaintRectsForRange(TextRange range) {
    if (_line._textDirty || !_line.hasSize || range.isCollapsed) return const <Rect>[];
    final start = range.start.clamp(0, _line.lineTextLength);
    final end = range.end.clamp(start, _line.lineTextLength);
    if (start == end) return const <Rect>[];
    final boxes = _line.selectionBoxesForLineRange(start, end);
    return [for (final box in boxes) box.toRect()];
  }

  @override
  void paintSelectionRange(Canvas canvas, Offset offset, TextRange range, Color color, {required Size nodeSize}) {
    final paint = Paint()..color = color;
    for (final rect in _line._selectionParticipant.adjustedSelectionPaintRectsForRange(range)) {
      canvas.drawRect(rect.shift(offset), paint);
    }
  }
}
