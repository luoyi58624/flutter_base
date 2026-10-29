part of 'selection_core.dart';

/// 依赖祖先视觉几何的选区根协议。
@internal
abstract interface class SelectionVisualGeometryDependency {
  /// 祖先 paint-only transform / clip 变化时同步刷新端点几何。
  @internal
  void descendantSelectionVisualGeometryChanged(RenderObject source);
}

/// 为 selection 树下降提供与 paint/hitTest 一致的子节点访问序。
@internal
abstract interface class SelectionPaintOrderChildren {
  /// 按从底到顶的视觉绘制顺序访问 selection 逻辑子节点。
  @internal
  void visitSelectionChildrenInPaintOrder(RenderObjectVisitor visitor);
}

/// 选区端点在参与者本地坐标系中的 caret 几何。用于移动端 handles / magnifier 定位。
@immutable
class SelectionCaretGeometry {
  /// 创建。
  const SelectionCaretGeometry({required this.position, required this.lineHeight});

  /// caret 顶部位置（参与者本地坐标）。
  final Offset position;

  /// 该 offset 所在行的高度。<= 0 表示无法测量。
  final double lineHeight;
}

/// 选区端点所在**行**的几何（参与者本地坐标），用于移动端 magnifier 的
/// AOSP 行锁定 / 行内钳制 / 40dp dismiss / 大字禁用逻辑。
///
/// `lineTop` + `lineHeight` 定位垂直带、`lineLeft` / `lineRight` 定位水平范围。
/// 精确来源：文本参与者的 [TextPainter.computeLineMetrics] / IFC line metrics；
/// box 原子参与者退化为"整盒即一行"。null = 暂不可用（painter 未就绪 / atomic
/// 且未提供）。
@immutable
class SelectionLineGeometry {
  /// 创建。
  const SelectionLineGeometry({
    required this.lineTop,
    required this.lineHeight,
    required this.lineLeft,
    required this.lineRight,
  });

  /// 该 offset 所在行的顶端（本地系）。
  final double lineTop;

  /// 该行高度。
  final double lineHeight;

  /// 该行内容左边界（本地系）。
  final double lineLeft;

  /// 该行内容右边界（本地系）。
  final double lineRight;
}

/// 沿当前渲染父链查找禁止文字选择的硬边界。
bool selectionTextIsBlocked(RenderObject source) {
  for (RenderObject? node = source; node != null; node = node.parent) {
    if (node is SelectionTextBlockBoundary) return true;
  }
  return false;
}

/// 当前渲染文档提供的外观和手势状态；内容注册只使用官方 SelectionRegistrar。
abstract interface class SelectionAppearance {
  /// 是否启用。
  bool get selectionEnabled;

  /// 当前是否正在拖选。
  bool get isSelectionDragging;

  /// 当前选中背景色。
  Color get selectionColor;

  /// 当前选中文本色。null 表示保持原文本颜色。
  Color? get selectionTextColor;
}

/// 内容原地变化的通知通道，避免官方几何去重吞掉等宽文字或图片替代文本更新。
abstract interface class SelectionContentObserver {
  /// 已选内容变化时合并刷新当前文档，不重建正文。
  void selectionContentChanged();
}

/// 按当前子树访问参与者，排除测量与滚动装饰节点。
void visitSelectionChildren(RenderObject node, RenderObjectVisitor visitor) {
  if (node is SelectionPaintOrderChildren) {
    (node as SelectionPaintOrderChildren).visitSelectionChildrenInPaintOrder(visitor);
  } else {
    node.visitChildren(visitor);
  }
}

/// 把 [node] 的视觉坐标映射到任意同一 PipelineOwner 下的 [target]。
///
/// 同一 PipelineOwner 即共享 visual tree，直接使用 Flutter 的共同祖先变换算法。
Matrix4? selectionVisualTransformTo(RenderObject node, RenderObject target) {
  if (identical(node, target)) return Matrix4.identity();
  if (!node.attached || !target.attached || !identical(node.owner, target.owner)) return null;
  return node.getTransformTo(target);
}

/// 节点上显式声明的 userSelect（参与者宿主 / 纯容器 [ElRenderView]）。
ElUserSelect? _declaredUserSelectOf(RenderObject node) {
  final participant = selectionParticipantOf(node);
  if (participant != null) return participant.selectionStyle?.userSelect;
  if (node is ElRenderView) return node.style?.userSelect;
  return null;
}

/// 按实际命中路径解析选区手势是否允许从 [source] 起手。
///
/// `userSelect` 不进级联：自下而上遇到的最近显式值决胜，`none`
/// 拒绝武装选区，`text/all` 允许局部抵消外层 `none`。
@internal
bool selectionGestureCanStartFrom(RenderObject source, {required RenderObject boundary}) {
  if (selectionTextIsBlocked(source)) return false;
  RenderObject? node = source;
  while (node != null && !identical(node, boundary)) {
    switch (_declaredUserSelectOf(node)) {
      case ElUserSelect.none:
        return false;
      case ElUserSelect.text:
      case ElUserSelect.all:
        return true;
      case ElUserSelect.auto:
      case null:
        break;
    }
    node = node.parent;
  }
  return true;
}

/// 选区内容适配：长度 / offset / 词边界 / 拷贝 / 几何 / 绘制。
///
/// [SelectionParticipant] 只引用本对象，不必在每个 Render 子类上重写一排方法。
/// 文本走实现本接口的引擎（如 [TextEngine]）；图片 走 [AtomicSelectionContent]。
abstract class SelectionContent {
  /// 内容类型。
  SelectionContentKind get selectionContentKind => SelectionContentKind.text;

  /// 可选择逻辑长度。
  int get selectionTextLength;

  /// 本地坐标 → 逻辑 offset。[fallbackHalfWidth] 在 painter 未就绪时作半宽分界。
  int selectionOffsetForLocalPosition(Offset localPosition, {required double fallbackHalfWidth});

  /// 词边界。
  TextRange selectionWordBoundaryAt(int offset);

  /// 选区纯文本。
  String selectionTextForRange(TextRange range);

  /// caret 几何；null = 暂不可用。
  SelectionCaretGeometry? selectionCaretGeometryAt(int offset) => null;

  /// 行几何；默认由 caret 退化。
  SelectionLineGeometry? selectionLineGeometryAt(int offset, {required double fallbackWidth}) {
    final caret = selectionCaretGeometryAt(offset);
    if (caret == null) return null;
    return SelectionLineGeometry(
      lineTop: caret.position.dy,
      lineHeight: caret.lineHeight,
      lineLeft: 0,
      lineRight: fallbackWidth,
    );
  }

  /// 选区背景矩形。
  List<Rect> selectionPaintRectsForRange(TextRange range) => const <Rect>[];

  /// 节点内修正后的选区矩形（如 clamp 到 nodeSize）。
  List<Rect> adjustedSelectionPaintRectsForRange(TextRange range, {required Size nodeSize}) {
    return selectionPaintRectsForRange(range);
  }

  /// 绘制选区色块。
  void paintSelectionRange(Canvas canvas, Offset offset, TextRange range, Color color, {required Size nodeSize});

  /// 命中粗边界；null 表示由参与者用整盒兜底。
  Rect? get selectionHitTestBounds => null;

  /// 是否命中可选内容。
  bool selectionContainsLocalPosition(Offset localPosition) {
    final bounds = selectionHitTestBounds;
    if (bounds == null) return true;
    return bounds.contains(localPosition);
  }
}

/// 整盒原子选区（图片 等）：逻辑长度通常为 1，选中即整盒。
final class AtomicSelectionContent extends SelectionContent {
  /// 创建。
  AtomicSelectionContent({
    required this.selectionContentKind,
    required this.sizeOf,
    required this.plainTextOf,
    this.lengthOf,
    this.onPaint,
  });

  @override
  final SelectionContentKind selectionContentKind;

  /// 当前盒尺寸。
  final Size Function() sizeOf;

  /// 复制用纯文本。
  final String Function() plainTextOf;

  /// 逻辑长度；默认 1。
  final int Function()? lengthOf;

  /// 自定义绘制；null 则整盒铺色。
  final void Function(Canvas canvas, Offset offset, TextRange range, Color color, Size size)? onPaint;

  @override
  int get selectionTextLength => lengthOf?.call() ?? 1;

  @override
  Rect? get selectionHitTestBounds {
    final s = sizeOf();
    if (s.isEmpty) return Rect.zero;
    return Offset.zero & s;
  }

  @override
  bool selectionContainsLocalPosition(Offset localPosition) {
    return selectionHitTestBounds?.contains(localPosition) ?? false;
  }

  @override
  int selectionOffsetForLocalPosition(Offset localPosition, {required double fallbackHalfWidth}) {
    if (selectionTextLength == 0) return 0;
    final width = math.max(sizeOf().width, 1.0);
    return localPosition.dx < width / 2 ? 0 : 1;
  }

  @override
  TextRange selectionWordBoundaryAt(int offset) {
    return selectionTextLength == 0 ? TextRange.empty : const TextRange(start: 0, end: 1);
  }

  @override
  String selectionTextForRange(TextRange range) {
    if (_isCollapsed(range)) return '';
    return plainTextOf();
  }

  @override
  SelectionLineGeometry? selectionLineGeometryAt(int offset, {required double fallbackWidth}) {
    if (selectionTextLength == 0) return null;
    final s = sizeOf();
    if (s.isEmpty) return null;
    return SelectionLineGeometry(lineTop: 0, lineHeight: s.height, lineLeft: 0, lineRight: s.width);
  }

  @override
  List<Rect> selectionPaintRectsForRange(TextRange range) {
    if (_isCollapsed(range)) return const <Rect>[];
    final s = sizeOf();
    if (s.isEmpty) return const <Rect>[];
    return <Rect>[Offset.zero & s];
  }

  @override
  void paintSelectionRange(Canvas canvas, Offset offset, TextRange range, Color color, {required Size nodeSize}) {
    if (_isCollapsed(range)) return;
    final s = sizeOf();
    if (s.isEmpty) return;
    final paint = onPaint;
    if (paint != null) {
      paint(canvas, offset, range, color, s);
      return;
    }
    canvas.drawRect(offset & s, Paint()..color = color);
  }

  bool _isCollapsed(TextRange range) {
    return selectionTextLength == 0 || range.isCollapsed || range.end <= 0 || range.start >= 1;
  }
}

/// RenderObject 上可选的选区参与者挂点（容器可不实现 / 返回 null）。
abstract interface class SelectionParticipantHost {
  /// 当前节点绑定的选区参与者；null = 不参与选中。
  SelectionParticipant? get selectionParticipant;
}

/// 从 render 节点取选区参与者。
SelectionParticipant? selectionParticipantOf(RenderObject node) {
  if (node is SelectionParticipantHost) {
    return (node as SelectionParticipantHost).selectionParticipant;
  }
  return null;
}

/// 从一批 RenderObject 收集非空选区参与者（测试 / 调试用）。
Iterable<SelectionParticipant> selectionParticipantsOf(Iterable<RenderObject> nodes) sync* {
  for (final node in nodes) {
    final participant = selectionParticipantOf(node);
    if (participant != null) yield participant;
  }
}

/// 在 userSelect 或 enabled 变化后重绑当前作用域，独立文档根自行负责其内容。
void reattachSelectionParticipantsInSubtree(RenderObject root) {
  void visit(RenderObject node) {
    if (!identical(node, root) && node is SelectionAppearance) return;
    selectionParticipantOf(node)?.reattachSelectionRoot();
    visitSelectionChildren(node, visit);
  }

  visit(root);
}

/// 可参与 [SelectionAppearance] 的选区叶子（**不是** RenderBox mixin）。
///
/// 几何 / 变换走 [box]；内容走 [selectionContent]。
abstract class SelectionParticipant extends ChangeNotifier with Selectable, SelectionRegistrant {
  /// 绑定的渲染盒（变换、尺寸、markNeedsPaint）。
  RenderBox get box;

  /// 内容适配；null = 无选择内容（长度 0）。
  SelectionContent? get selectionContent;

  SelectionAppearance? _selectionRoot;
  RenderObject? _userSelectAllScopeRoot;
  SelectionRegistrar? _scopeRegistrar;
  int? _selectionStart;
  int? _selectionEnd;
  LayerLink? _startHandleLayer;
  LayerLink? _endHandleLayer;
  SelectionGeometry _geometry = const SelectionGeometry(status: SelectionStatus.none, hasContent: false);
  bool _notificationScheduled = false;
  bool _disposed = false;

  void _notifySelectionChanged() {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    // 范围与绘制几何立即生效；通知等布局完成，避免 SDK 跨布局边界读取祖先尺寸。
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 绑定 Widget 作用域提供的官方注册中心，同一参与者只走一个注册入口。
  void bindSelectionRegistrar(SelectionRegistrar? value) {
    if (identical(_scopeRegistrar, value)) return;
    _setProtocolSelection(null, null);
    _scopeRegistrar = value;
    reattachSelectionRoot();
  }

  /// 布局完成后更新官方几何，不额外布局正文或创建渲染节点。
  void updateSelectionGeometry() {
    final hasContent = participatesInSelection && selectionTextLength > 0 && !selectionTextIsBlocked(box);
    _selectionStart = hasContent ? _selectionStart?.clamp(0, contentLength) : null;
    _selectionEnd = hasContent ? _selectionEnd?.clamp(0, contentLength) : null;
    SelectionPoint? point(int? offset, TextSelectionHandleType type) {
      if (offset == null || !hasSize) return null;
      final caret = selectionCaretGeometryAt(offset);
      final bounds = selectionHitTestBounds ?? (Offset.zero & size);
      return SelectionPoint(
        localPosition: caret == null
            ? Offset(offset == 0 ? bounds.left : bounds.right, bounds.bottom)
            : caret.position + Offset(0, caret.lineHeight),
        lineHeight: caret?.lineHeight ?? bounds.height,
        handleType: type,
      );
    }

    final selected = hasContent && _selectionStart != null && _selectionEnd != null;
    final collapsed = _selectionStart == _selectionEnd;
    final reversed = (_selectionStart ?? 0) > (_selectionEnd ?? 0);
    final flipped = reversed != (selectionTextDirection == TextDirection.rtl);
    final next = SelectionGeometry(
      status: !selected
          ? SelectionStatus.none
          : collapsed
          ? SelectionStatus.collapsed
          : SelectionStatus.uncollapsed,
      hasContent: hasContent,
      startSelectionPoint: selected
          ? point(
              _selectionStart,
              collapsed
                  ? TextSelectionHandleType.collapsed
                  : flipped
                  ? TextSelectionHandleType.right
                  : TextSelectionHandleType.left,
            )
          : null,
      endSelectionPoint: selected
          ? point(
              _selectionEnd,
              collapsed
                  ? TextSelectionHandleType.collapsed
                  : flipped
                  ? TextSelectionHandleType.left
                  : TextSelectionHandleType.right,
            )
          : null,
      selectionRects: selected && !collapsed && hasSize
          ? selectionPaintRectsForRange(currentSelectionRange!)
          : const [],
    );
    if (_geometry == next) return;
    _geometry = next;
    _notifySelectionChanged();
  }

  @override
  SelectionGeometry get value => _geometry;

  /// 内容原地更新单独通知文档，等宽文本不一定改变官方选区几何。
  void notifySelectionContentChanged() {
    if (currentSelectionRange?.isCollapsed != false) return;
    _notifySelectionChanged();
    final observer = _selectionRoot;
    if (observer is SelectionContentObserver) (observer as SelectionContentObserver).selectionContentChanged();
  }

  @override
  int get contentLength => selectionTextLength;

  @override
  List<Rect> get boundingBoxes => hasSize ? [selectionHitTestBounds ?? (Offset.zero & size)] : const [Rect.zero];

  @override
  SelectedContentRange? getSelection() => _selectionStart == null || _selectionEnd == null
      ? null
      : SelectedContentRange(startOffset: _selectionStart!, endOffset: _selectionEnd!);

  @override
  SelectedContent? getSelectedContent() {
    final range = currentSelectionRange;
    return range == null || range.isCollapsed ? null : SelectedContent(plainText: selectionTextForRange(range));
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    if (identical(_startHandleLayer, startHandle) && identical(_endHandleLayer, endHandle)) return;
    _startHandleLayer = startHandle;
    _endHandleLayer = endHandle;
    box.markNeedsCompositingBitsUpdate();
    box.markNeedsPaint();
  }

  /// 官方选区 UI 请求 leader 时才需要额外合成。
  bool get hasSelectionHandleLayers => _startHandleLayer != null || _endHandleLayer != null;

  /// 在现有内容绘制之后发布官方手柄锚点。
  void paintSelectionHandleLayers(PaintingContext context, Offset offset) {
    void paint(LayerLink? link, SelectionPoint? point) {
      if (link == null || point == null) return;
      context.pushLayer(LeaderLayer(link: link, offset: offset + point.localPosition), (_, _) {}, Offset.zero);
    }

    paint(_startHandleLayer, value.startSelectionPoint);
    paint(_endHandleLayer, value.endSelectionPoint);
  }

  void _setProtocolSelection(int? start, int? end) {
    start = start?.clamp(0, contentLength);
    end = end?.clamp(0, contentLength);
    if (_selectionStart == start && _selectionEnd == end) return;
    _selectionStart = start;
    _selectionEnd = end;
    if (attached) markNeedsPaint();
    updateSelectionGeometry();
  }

  SelectionResult _updateProtocolEdge(
    Offset global, {
    required bool isEnd,
    TextGranularity granularity = TextGranularity.character,
  }) {
    if (!hasSize || !attached) return SelectionResult.none;
    final local = box.globalToLocal(global);
    final bounds = selectionHitTestBounds ?? (Offset.zero & size);
    final result = SelectionUtils.getResultBasedOnRect(bounds, local);
    final adjusted = SelectionUtils.adjustDragOffset(bounds, local, direction: selectionTextDirection);
    var offset = selectionOffsetForLocalPosition(adjusted).clamp(0, contentLength);
    if (granularity == TextGranularity.word && result == SelectionResult.end) {
      final word = selectionWordBoundaryAt(offset);
      final other = isEnd ? _selectionStart : _selectionEnd;
      offset = other != null && offset < other ? word.start : word.end;
    }
    _setProtocolSelection(isEnd ? (_selectionStart ?? offset) : offset, isEnd ? offset : (_selectionEnd ?? offset));
    return result;
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    switch (event.type) {
      case SelectionEventType.clear:
        _setProtocolSelection(null, null);
      case SelectionEventType.selectAll:
        _setProtocolSelection(0, contentLength);
      case SelectionEventType.selectWord:
        if (!hasSize || !attached) return SelectionResult.none;
        final local = box.globalToLocal((event as SelectWordSelectionEvent).globalPosition);
        if (!selectionContainsLocalPosition(local)) return SelectionResult.none;
        final word = selectionWordBoundaryAt(selectionOffsetForLocalPosition(local));
        _setProtocolSelection(word.start, word.end);
      case SelectionEventType.selectParagraph:
        if (!hasSize || !attached) return SelectionResult.none;
        final local = box.globalToLocal((event as SelectParagraphSelectionEvent).globalPosition);
        if (!selectionContainsLocalPosition(local)) return SelectionResult.none;
        _setProtocolSelection(0, contentLength);
      case SelectionEventType.startEdgeUpdate:
      case SelectionEventType.endEdgeUpdate:
        final edge = event as SelectionEdgeUpdateEvent;
        return _updateProtocolEdge(
          edge.globalPosition,
          isEnd: event.type == SelectionEventType.endEdgeUpdate,
          granularity: edge.granularity,
        );
      case SelectionEventType.granularlyExtendSelection:
        final extend = event as GranularlyExtendSelectionEvent;
        final current = (extend.isEnd ? _selectionEnd : _selectionStart) ?? (extend.forward ? 0 : contentLength);
        final text = selectionTextForRange(TextRange(start: 0, end: contentLength));
        var next = extend.forward ? contentLength : 0;
        if (extend.granularity == TextGranularity.character) {
          final boundary = CharacterBoundary(text);
          next = extend.forward
              ? boundary.getTrailingTextBoundaryAt(current) ?? contentLength
              : boundary.getLeadingTextBoundaryAt(current - 1) ?? 0;
        } else if (extend.granularity == TextGranularity.word) {
          final word = selectionWordBoundaryAt(extend.forward ? current : math.max(0, current - 1));
          next = extend.forward ? word.end : word.start;
        }
        _setProtocolSelection(
          extend.isEnd ? (_selectionStart ?? current) : next,
          extend.isEnd ? next : (_selectionEnd ?? current),
        );
        return next == 0
            ? SelectionResult.previous
            : next == contentLength
            ? SelectionResult.next
            : SelectionResult.end;
      case SelectionEventType.directionallyExtendSelection:
        final extend = event as DirectionallyExtendSelectionEvent;
        final current = (extend.isEnd ? _selectionEnd : _selectionStart) ?? 0;
        final caret = selectionCaretGeometryAt(current);
        if (caret == null) return SelectionResult.none;
        final dy = switch (extend.direction) {
          SelectionExtendDirection.previousLine => -.5,
          SelectionExtendDirection.nextLine => 1.5,
          _ => .5,
        };
        final global = box.localToGlobal(caret.position + Offset(0, caret.lineHeight * dy));
        return _updateProtocolEdge(Offset(extend.dx, global.dy), isEnd: extend.isEnd);
    }
    return SelectionResult.none;
  }

  /// **ElUserSelect.all** 作用域根；null = 不在 all 作用域内。
  RenderObject? get userSelectAllScopeRoot => _userSelectAllScopeRoot;

  /// 官方事件维护的唯一内容范围。
  TextRange? get currentSelectionRange => _selectionStart == null || _selectionEnd == null
      ? null
      : TextRange(start: math.min(_selectionStart!, _selectionEnd!), end: math.max(_selectionStart!, _selectionEnd!));

  /// 是否已挂到启用中的选区 root。
  bool get hasEnabledSelectionRoot => registrar != null;

  /// 当前文档的外观与手势宿主；内容注册使用官方 registrar。
  SelectionAppearance? get selectionAppearance => _selectionRoot;

  /// 本参与者是否注册在 [root] 下。
  bool isAttachedToSelectionRoot(SelectionAppearance root) => identical(_selectionRoot, root);

  /// 最近一次 hitTest 是否命中可选文本字形（I-beam）。
  bool get lastHitShowsSelectableTextCursor => false;

  /// 是否作为一个独立选区参与者注册。
  bool get participatesInSelection => true;

  /// 父级选区是否正在拖选。
  bool get isParentSelectionDragging => _selectionRoot?.isSelectionDragging ?? false;

  /// 当前选中背景色（root 兜底通道：root 推、参与者读）。
  Color get selectionColor => _selectionRoot?.selectionColor ?? const Color(0x553B82F6);

  /// 当前选中文本色（root 兜底通道）。
  Color? get selectionTextColor => _selectionRoot?.selectionTextColor;

  /// 宿主 `onSelection` 伪类的提取结果；null = 宿主未接入（等价 empty）。
  OnSelectionPaint? get selectionPaint => null;

  /// 本参与者的**有效**选中背景色：宿主 onSelection 声明优先，未声明整对
  /// 回退 root 兜底（[selectionColor]）。paint / handle 消费本 getter。
  Color get effectiveSelectionBgColor {
    final paint = selectionPaint;
    if (paint != null && !paint.isEmpty) return paint.bgColor ?? selectionColor;
    return selectionColor;
  }

  /// 本参与者的**有效**选中文字色。
  ///
  /// 宿主声明了 onSelection（任一槽）即整对脱离 root 兜底：`color` 未声明 =
  /// null = 保留原文字色（**不**继承平台白字——与「任一来源给 bgColor 即
  /// 白字不再跟随」口径一致）；完全未声明才回退 root 的 [selectionTextColor]。
  Color? get effectiveSelectionTextColor {
    final paint = selectionPaint;
    if (paint != null && !paint.isEmpty) return paint.color;
    return selectionTextColor;
  }

  /// 文本方向。
  TextDirection get selectionTextDirection => TextDirection.ltr;

  /// 当前节点样式。
  ElStyle? get selectionStyle => null;

  /// 对应的 widget 节点。
  Object? get selectionNode => null;

  // --- box 转发（选区 root 大量按 RenderBox 语义调用）------------------------

  bool get attached => box.attached;
  bool get hasSize => box.hasSize;
  @override
  Size get size => box.size;
  bool get debugNeedsPaint => box.debugNeedsPaint;
  RenderObject? get parent => box.parent;

  void markNeedsPaint() => box.markNeedsPaint();

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) => box.getTransformTo(ancestor);

  Offset localToGlobal(Offset point, {RenderObject? ancestor}) => box.localToGlobal(point, ancestor: ancestor);

  SelectionContentKind get selectionContentKind => selectionContent?.selectionContentKind ?? SelectionContentKind.text;

  Rect? get selectionHitTestBounds => selectionContent?.selectionHitTestBounds;

  bool selectionContainsLocalPosition(Offset localPosition) {
    final content = selectionContent;
    if (content != null) {
      final bounds = content.selectionHitTestBounds;
      if (bounds != null) return content.selectionContainsLocalPosition(localPosition);
    }
    return (Offset.zero & size).contains(localPosition);
  }

  /// offset / 行几何用的兜底宽度（文本宿主可用内容盒宽）。
  double get selectionFallbackWidth => size.width;

  int get selectionTextLength => selectionContent?.selectionTextLength ?? 0;

  int selectionOffsetForLocalPosition(Offset localPosition) {
    return selectionContent?.selectionOffsetForLocalPosition(
          localPosition,
          fallbackHalfWidth: selectionFallbackWidth,
        ) ??
        0;
  }

  SelectionCaretGeometry? selectionCaretGeometryAt(int offset) {
    return selectionContent?.selectionCaretGeometryAt(offset);
  }

  SelectionLineGeometry? selectionLineGeometryAt(int offset) {
    final content = selectionContent;
    if (content != null) {
      return content.selectionLineGeometryAt(offset, fallbackWidth: selectionFallbackWidth);
    }
    final caret = selectionCaretGeometryAt(offset);
    if (caret == null) return null;
    return SelectionLineGeometry(
      lineTop: caret.position.dy,
      lineHeight: caret.lineHeight,
      lineLeft: 0,
      lineRight: selectionFallbackWidth,
    );
  }

  TextRange selectionWordBoundaryAt(int offset) {
    return selectionContent?.selectionWordBoundaryAt(offset) ?? TextRange.collapsed(offset);
  }

  String selectionTextForRange(TextRange range) {
    return selectionContent?.selectionTextForRange(range) ?? '';
  }

  void paintSelectionRange(Canvas canvas, Offset offset, TextRange range, Color color) {
    selectionContent?.paintSelectionRange(canvas, offset, range, color, nodeSize: size);
  }

  List<Rect> selectionPaintRectsForRange(TextRange range) {
    return selectionContent?.selectionPaintRectsForRange(range) ?? const <Rect>[];
  }

  List<Rect> adjustedSelectionPaintRectsForRange(TextRange range) {
    final content = selectionContent;
    return content != null
        ? content.adjustedSelectionPaintRectsForRange(range, nodeSize: size)
        : selectionPaintRectsForRange(range);
  }

  void cancelSelectionGesture(PointerEvent event) {}

  /// 更新本地外观归属，并通过官方注册中心参与当前文档。
  void reattachSelectionRoot() {
    if (!box.attached) return;
    _selectionRoot = _findSelectionRoot();
    final root = _selectionRoot;
    final eligible =
        participatesInSelection &&
        !selectionTextIsBlocked(box) &&
        selectionGestureCanStartFrom(box, boundary: root is RenderObject ? root as RenderObject : box.owner!.rootNode!);
    if (!eligible || _scopeRegistrar == null) _setProtocolSelection(null, null);
    updateSelectionGeometry();
    registrar = eligible ? _scopeRegistrar : null;
  }

  /// 注销当前挂载；同一实例临时重挂保留本地范围，换文档时由绑定入口清空。
  void detachFromSelectionRoot() {
    registrar = null;
    final appearance = _selectionRoot;
    // 整个文档同帧重挂时保留活体范围；单个内容退出文档时立即清空。
    if (appearance is! RenderObject || (appearance as RenderObject).attached) _setProtocolSelection(null, null);
    _selectionRoot = null;
    _userSelectAllScopeRoot = null;
  }

  SelectionAppearance? _findSelectionRoot() {
    _userSelectAllScopeRoot = null;
    if (!participatesInSelection || selectionTextIsBlocked(box)) return null;
    var resolved = false;
    switch (selectionStyle?.userSelect) {
      case ElUserSelect.none:
        return null;
      case ElUserSelect.text:
        resolved = true;
      case ElUserSelect.all:
        resolved = true;
        _userSelectAllScopeRoot = box;
      case ElUserSelect.auto:
      case null:
        break;
    }
    RenderObject? node = box.parent;
    while (node != null) {
      if (node is SelectionBoundary) return null;
      if (node is SelectionAppearance) {
        final appearance = node as SelectionAppearance;
        return appearance.selectionEnabled ? appearance : null;
      }
      if (!resolved) {
        switch (_declaredUserSelectOf(node)) {
          case ElUserSelect.none:
            return null;
          case ElUserSelect.text:
            resolved = true;
          case ElUserSelect.all:
            resolved = true;
            _userSelectAllScopeRoot = node;
          case ElUserSelect.auto:
          case null:
            break;
        }
      }
      node = node.parent;
    }
    return null;
  }
}

/// 通用绑定：宿主提供 box、内容和可选开关。
final class BoundSelectionParticipant extends SelectionParticipant {
  /// 创建。
  BoundSelectionParticipant({
    required this.box,
    required this.contentOf,
    this.styleOf,
    this.nodeOf,
    this.participatesOf,
    this.lastHitCursorOf,
    this.textDirectionOf,
    this.fallbackWidthOf,
    this.selectionPaintOf,
  });

  @override
  final RenderBox box;

  /// 动态读取内容（文本 painter / atomic）。
  final SelectionContent? Function() contentOf;

  final ElStyle? Function()? styleOf;
  final Object? Function()? nodeOf;
  final bool Function()? participatesOf;
  final bool Function()? lastHitCursorOf;
  final TextDirection Function()? textDirectionOf;
  final double Function()? fallbackWidthOf;

  /// 宿主 onSelection 提取回调（宿主自带 memo）；null = 宿主未接入。
  final OnSelectionPaint? Function()? selectionPaintOf;

  @override
  SelectionContent? get selectionContent => contentOf();

  @override
  ElStyle? get selectionStyle => styleOf?.call();

  @override
  OnSelectionPaint? get selectionPaint => selectionPaintOf?.call();

  @override
  Object? get selectionNode => nodeOf?.call();

  @override
  bool get participatesInSelection => participatesOf?.call() ?? true;

  @override
  bool get lastHitShowsSelectableTextCursor => lastHitCursorOf?.call() ?? false;

  @override
  TextDirection get selectionTextDirection => textDirectionOf?.call() ?? TextDirection.ltr;

  @override
  double get selectionFallbackWidth => fallbackWidthOf?.call() ?? size.width;
}

/// `onSelection` 伪类的选区 overlay paint 槽提取结果。
///
/// 只承载选区背景和文字色；onSelection
/// 里声明的其余字段（含全部 layout 字段）按硬规则静默忽略，零 assert。
class OnSelectionPaint {
  /// 创建提取结果。
  const OnSelectionPaint({this.bgColor, this.color});

  /// 未声明 onSelection 时的共享空结果。
  static const OnSelectionPaint empty = OnSelectionPaint();

  /// 选区背景色；null = 未声明（消费点回退选区根兜底色）。
  final Color? bgColor;

  /// 选中文字色（仅文本宿主消费）；null = 未声明（保留原文字色或回退兜底）。
  final Color? color;

  /// 两槽均未声明。
  bool get isEmpty => bgColor == null && color == null;
}

/// 从宿主 style 提取 onSelection 的 paint 槽。
///
/// 层叠语义（对齐 cascade emit 的「后写覆前」）：`base.onSelection` 先合并，
/// 再按 [selfVariantEntries] 表序对 [stateBits] 命中的变体链 AND 下钻（嵌套
/// 判定与 `activeSelfVariantContribution` 同构），高优先级变体内的声明覆盖
/// 低优先级；合并走 [ElStyleExt.merge]（字段级，非整体替换）。
///
/// - [stateBits]：宿主当前状态位（`ElRenderView.internalStateBits`）；无状态
///   机的宿主（图片）传 0 → 只认顶层 `base.onSelection`。
///
/// **不进 cascade**：本函数只在选区 paint 期由宿主经 [OnSelectionPaintMemo]
/// 调用，range 变化不触发任何 reresolve。
OnSelectionPaint extractOnSelectionPaint(ElStyle? style, {int stateBits = 0}) {
  if (style == null) return OnSelectionPaint.empty;
  ElStyle? merged;
  void visit(ElStyle v) {
    final sel = v.onSelection;
    if (sel != null) merged = merged == null ? sel : merged!.merge(sel);
    if (stateBits == 0) return;
    for (final entry in selfVariantEntries) {
      if ((stateBits >> entry.$2.index) & 1 == 0) continue;
      final sub = entry.$1(v);
      if (sub != null) visit(sub);
    }
  }

  visit(style);
  final m = merged;
  if (m == null) return OnSelectionPaint.empty;
  final bg = m.bgColor;
  final fg = m.color;
  if (bg == null && fg == null) return OnSelectionPaint.empty;
  return OnSelectionPaint(bgColor: bg, color: fg);
}

/// [extractOnSelectionPaint] 的宿主侧 memo：输入 identity / 值不变时零重算。
///
/// 样式对象或状态位变化才重新提取；拖选重绘复用缓存。
final class OnSelectionPaintMemo {
  ElStyle? _style;
  int _stateBits = 0;
  OnSelectionPaint? _result;

  /// 取（必要时重算并缓存）提取结果。
  OnSelectionPaint resolve(ElStyle? style, {int stateBits = 0}) {
    final cached = _result;
    if (cached != null && identical(style, _style) && stateBits == _stateBits) {
      return cached;
    }
    final result = extractOnSelectionPaint(style, stateBits: stateBits);
    _style = style;
    _stateBits = stateBits;
    _result = result;
    return result;
  }
}

/// 当前已挂载参与者上的文本端点。
class SelectionEndpoint {
  /// 创建当前宿主中的偏移，不保存卸载后的身份。
  const SelectionEndpoint.fromParticipant(this.participant, this.offset);

  /// 当前范围中仍挂载的宿主。
  final SelectionParticipant participant;

  /// 宿主内的字符偏移。
  final int offset;
}

/// 已挂载参与者之间的连续范围。
class SelectionSpan {
  /// 保存当前成员索引和首尾偏移。
  const SelectionSpan({
    required this.startIndex,
    required this.endIndex,
    required this.startOffset,
    required this.endOffset,
  });

  /// 首个参与者索引。
  final int startIndex;

  /// 最后一个参与者索引。
  final int endIndex;

  /// 首参与者中的起始偏移。
  final int startOffset;

  /// 尾参与者中的结束偏移。
  final int endOffset;
}

/// participant 在 selection root 坐标系下的可视 bounds + 逆变换。
///
/// hit-test / auto-scroll / marquee 命中判定都基于此结构；缓存在
/// `_participantGeometryCache` 中避免每次拖动重新算变换矩阵。
class SelectionParticipantGeometry {
  /// 创建。
  const SelectionParticipantGeometry({
    required this.participant,
    required this.bounds,
    required this.rootToParticipantTransform,
  });

  /// 目标 participant。
  final SelectionParticipant participant;

  /// 在 selection root 坐标系下的可视矩形（已裁剪掉 clipping ancestor）。
  final Rect bounds;

  /// root→participant 逆变换矩阵。命中一个 root 上的 point 后用它换算 local。
  final Matrix4 rootToParticipantTransform;
}

/// 选区端点。
enum SelectionHandleSide {
  /// 选区逻辑起点（range.start）。
  start,

  /// 选区逻辑终点（range.end）。
  end,
}

/// 单个端点的全局几何，用于定位 handle / magnifier。
@immutable
class SelectionHandleEndpoint {
  const SelectionHandleEndpoint({
    required this.side,
    required this.globalPosition,
    required this.lineHeight,
    required this.visible,
    required this.textDirection,
    this.handleColor,
  });

  final SelectionHandleSide side;
  final Offset globalPosition;
  final double lineHeight;
  final bool visible;
  final TextDirection textDirection;

  /// 端点所在 participant 的 handle 色（`onSelection` 有效背景色的不透明版，
  /// 端点各用各色）；null = 回退选区根级 handle 色。参与值相等：色变即
  /// endpoints 通道自然通知 chrome 重绘。
  final Color? handleColor;

  Offset get globalBottom => Offset(globalPosition.dx, globalPosition.dy + lineHeight);

  @override
  bool operator ==(Object other) {
    return other is SelectionHandleEndpoint &&
        other.side == side &&
        other.globalPosition == globalPosition &&
        other.lineHeight == lineHeight &&
        other.visible == visible &&
        other.textDirection == textDirection &&
        other.handleColor == handleColor;
  }

  @override
  int get hashCode => Object.hash(side, globalPosition, lineHeight, visible, textDirection, handleColor);
}

/// 当前正被拖动的端点信息。
@immutable
class SelectionDragInfo {
  const SelectionDragInfo({required this.kind, required this.side, required this.globalPosition});

  final SelectionDragKind kind;
  final SelectionHandleSide? side;
  final Offset globalPosition;

  @override
  bool operator ==(Object other) {
    return other is SelectionDragInfo &&
        other.kind == kind &&
        other.side == side &&
        other.globalPosition == globalPosition;
  }

  @override
  int get hashCode => Object.hash(kind, side, globalPosition);
}

/// 当前选区的拖动来源。
enum SelectionDragKind { longPress, handle }

/// 移动端选区的端点几何快照。null = 无选区。
@immutable
class SelectionEndpointsInfo {
  const SelectionEndpointsInfo({required this.start, required this.end, required this.devicePixelRatio});

  final SelectionHandleEndpoint start;
  final SelectionHandleEndpoint end;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    return other is SelectionEndpointsInfo &&
        other.start == start &&
        other.end == end &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(start, end, devicePixelRatio);
}
