import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show HitTestEntry, HitTestTarget;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show IconData, Widget, WidgetSpan;

import '../../../utils/internal/benchmark_probe.dart';
import '../../selection/common/selection_core.dart';
import '../style/style.dart';
import '../style/resolved/resolved_style.dart';
import '../render/content_sizes.dart';
import '../render/render_view.dart' show ElRenderView;
import '../view.dart' show ElView;
import 'text_style_adapter.dart';
export 'text_style_adapter.dart';

/// 内联子项的位置、缩放和省略状态，供宿主绘制变换共用。
class ElTextParentData extends ContainerBoxParentData<RenderBox> {
  /// WidgetSpan 按所在文本字号缩放。
  double scale = 1;

  /// 被省略的占位子项不绘制、不命中。
  bool visible = true;
}

/// 宿主提供已提交样式和本次布局环境。
typedef TextPaintInput = ({
  ResolvedStyle style,
  TextScaler textScaler,
  ui.Locale? locale,
  Offset contentOrigin,
  bool boldText,
});

extension on TextPaintInput {
  TextDirection get textDirection => style.inheritedBox.direction ?? TextDirection.ltr;
}

/// 宽容输入直接归一为 span；Widget 始终是真实占位子项。
class TextContent {
  TextContent._(this.span, this.spans);
  final InlineSpan span;
  final List<WidgetSpan> spans;

  /// 挂载与排版共用占位顺序，只在内容变化时转换。
  factory TextContent.parse(Object? value) {
    if (value is String) return TextContent._(TextSpan(text: value), const []);
    InlineSpan convert(Object? item) => switch (item) {
      InlineSpan span => span,
      // 内联文本按真实基线对齐，bottom 会把子行盒再叠加一次父行 descent。
      Widget widget => WidgetSpan(
        alignment: widget is ElView ? PlaceholderAlignment.baseline : PlaceholderAlignment.bottom,
        baseline: widget is ElView ? TextBaseline.alphabetic : null,
        child: widget,
      ),
      IconData icon => WidgetSpan(child: ElView(child: icon)),
      Iterable items => TextSpan(children: items.where((item) => item != null).map(convert).toList()),
      _ => TextSpan(text: item?.toString() ?? ''),
    };
    final span = value is IconData ? TextSpan(text: String.fromCharCode(value.codePoint)) : convert(value);
    final spans = <WidgetSpan>[];
    span.visitChildren((child) {
      if (child is WidgetSpan) spans.add(child);
      return true;
    });
    return TextContent._(span, spans);
  }
}

typedef _TextLine = ({ui.LineMetrics line, double top, double bottom});

/// 自持 TextPainter 的文本内核，仅扩展样式继承与现有选区协议。
class TextEngine extends SelectionContent {
  final _painter = TextPainter();
  TextPainter? _overlay;
  TextContent? _content;
  Object? rawChild;
  ElRenderView? _host;
  List<RenderBox> _children() => _content!.spans.isEmpty ? const [] : _host!.getChildrenAsList();
  BoundSelectionParticipant? _participant;
  TextPaintInput? _input;
  Object? _configuredFor;
  String _plain = '';
  Size _size = Size.zero;
  Offset _alignment = Offset.zero;
  BoxConstraints? _constraints;
  List<PlaceholderDimensions> _dimensions = [];
  List<_TextLine>? _bands;
  ({TextRange range, Offset origin, Size size, List<Rect> rects})? _rects;
  Color? _overlayColor;
  ui.Shader? overflowShader;
  double _minWidth = 0;
  int debugSelectionUnclippedOverlayCount = 0;
  int debugSelectionClipRectOverlayCount = 0;
  bool get _icon => rawChild is IconData;
  double _iconExtent(TextPaintInput input) => input.textScaler.scale(input.style.inheritedBox.iconSize ?? 24);
  TextContent get structure => _content!;
  SelectionParticipant? get selectionParticipant => _participant;
  int get stringPainterLayoutCountForTest => _host!.debugLayoutCount;
  TextPainter get painterForTest => _painter;
  Offset get textPaintOrigin {
    final center = _icon
        ? Offset((_size.width - _painter.width) / 2, (_size.height - _painter.height) / 2)
        : Offset.zero;
    return (_input?.contentOrigin ?? Offset.zero) + _alignment + center;
  }

  String? get semanticsTextLabel => _icon ? null : _content!.span.toPlainText().replaceAll('\ufffc', '');
  TextOverflow get _overflow =>
      _icon ? TextOverflow.visible : _input!.style.inheritedText.textOverflow ?? TextOverflow.visible;
  bool get textOverflows =>
      _constraints != null &&
      (_painter.didExceedMaxLines || _painter.width > _size.width || _painter.height > _size.height);
  bool get overflowNeedsClipping => _overflow != TextOverflow.visible && textOverflows;

  /// 绑定原有选区参与者，文本内核不维护另一套注册系统。
  void bindHost({required ElRenderView host, Object? Function()? nodeOf, bool Function()? lastHitCursorOf}) {
    _host = host;
    _participant = BoundSelectionParticipant(
      box: host,
      contentOf: () => this,
      styleOf: () => host.style,
      nodeOf: nodeOf,
      participatesOf: () => rawChild != null && host.style?.userSelect != ElUserSelect.none,
      lastHitCursorOf: lastHitCursorOf,
      textDirectionOf: () => host.committedResolvedStyle.inheritedBox.direction ?? TextDirection.ltr,
      fallbackWidthOf: () => host.boxSize.width,
      selectionPaintOf: () => host.inheritedSelectionPaint,
    );
    _participant!.bindSelectionRegistrar(host.selectionRegistrar);
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  void _fontsChanged() {
    invalidateLayout();
    if (_host?.attached ?? false) _host!.markNeedsLayout();
  }

  /// 挂载、卸载和 userSelect 变化复用现有注册协议。
  void syncSelectionParticipation() =>
      (_host?.attached ?? false) ? _participant?.reattachSelectionRoot() : _participant?.detachFromSelectionRoot();

  /// 等价内容保留缓存；非空换字沿用已解析样式和旧配置键，下一次布局仍校验新环境。
  void setPayload(Object? value, {TextContent? content, bool contentEquivalent = false}) {
    final sameOwner = rawChild is String && (rawChild as String).isNotEmpty && value is String && value.isNotEmpty;
    final configured = sameOwner ? _configuredFor : null;
    rawChild = value;
    if (contentEquivalent) return;
    _content = content ?? TextContent.parse(value);
    _plain = value is String ? value : _content!.span.toPlainText(includeSemanticsLabels: false);
    invalidateLayout();
    if (configured != null) _painter.text = TextSpan(text: _plain, style: _painter.text!.style);
    _configuredFor = configured;
    sameOwner ? _participant?.updateSelectionGeometry() : syncSelectionParticipation();
    _participant?.notifySelectionContentChanged();
  }

  void _clearPaintCache() {
    _overlay?.dispose();
    _overlay = null;
    _bands = null;
    _rects = null;
  }

  /// 作废主 painter 的独立配置键，它不随绘制原点的 input 提前更新。
  void invalidatePaint() {
    _configuredFor = null;
    _clearPaintCache();
  }

  /// 字体或几何变化使当前排版失效。
  void invalidateLayout() {
    _constraints = null;
    invalidatePaint();
    _painter.markNeedsLayout();
  }

  bool invalidateForBoldText() {
    if (!_icon) invalidateLayout();
    return !_icon;
  }

  TextStyle _baseStyle(TextPaintInput input) {
    if (!_icon) return inheritedTextToTextStyle(input.style.inheritedText);
    final icon = rawChild as IconData;
    return TextStyle(
      inherit: false,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      fontFamilyFallback: icon.fontFamilyFallback,
      fontSize: input.style.inheritedBox.iconSize ?? 24,
      color: input.style.inheritedBox.iconColor,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: input.style.inheritedText.fontWeight,
      fontVariations: input.style.inheritedText.fontVariationSettings,
      shadows: input.style.inheritedText.textShadow,
    );
  }

  Object _keyFor(TextPaintInput i) => (i.style.inheritedText, i.style.inheritedBox, i.textScaler, i.locale, i.boldText);

  TextPainter _configure(TextPainter painter, TextPaintInput input) {
    assert(!identical(painter, _painter) || ++BenchmarkProbe.textPainterConfigureCount > 0);
    final style = _baseStyle(input);
    if (identical(painter, _painter)) _configuredFor = _keyFor(input);
    return painter
      ..text = _icon
          ? TextSpan(text: String.fromCharCode((rawChild as IconData).codePoint), style: style)
          : resolveTextSpan(_content!.span, style, bold: input.boldText)
      ..textAlign = _icon ? TextAlign.center : input.style.inheritedText.textAlign ?? TextAlign.start
      ..textDirection = input.textDirection
      ..textScaler = input.textScaler
      ..locale = input.locale
      ..maxLines = _icon ? 1 : input.style.inheritedText.maxLines
      ..ellipsis = input.style.inheritedText.textOverflow == TextOverflow.ellipsis ? '…' : null;
  }

  double _maxWidth(TextPaintInput input, double width) {
    final text = input.style.inheritedText;
    return !_icon && (text.softWrap != false || text.textOverflow == TextOverflow.ellipsis) ? width : double.infinity;
  }

  List<PlaceholderDimensions> _placeholders(TextPainter painter, BoxConstraints available, {required bool dry}) {
    if (_content!.spans.isEmpty) return const [];
    final children = _children();
    final fonts = <double>[];
    painter.text!.visitChildren((span) {
      if (span is WidgetSpan) fonts.add(span.style?.fontSize ?? 14);
      return true;
    });
    final out = <PlaceholderDimensions>[];
    for (var i = 0; i < _content!.spans.length; i++) {
      final span = _content!.spans[i];
      final child = children[i];
      final scale = fonts[i] == 0 ? 0.0 : painter.textScaler.scale(fonts[i]) / fonts[i];
      final constraints = available.loosen() / (scale == 0 ? 1 : scale);
      final size = dry ? child.getDryLayout(constraints) : (child..layout(constraints, parentUsesSize: true)).size;
      if (!dry) (child.parentData! as ElTextParentData).scale = scale;
      final baseline = span.alignment == PlaceholderAlignment.baseline
          ? (dry ? child.getDryBaseline(constraints, span.baseline!) : child.getDistanceToBaseline(span.baseline!)) ??
                size.height
          : null;
      out.add(
        PlaceholderDimensions(
          size: size * scale,
          alignment: span.alignment,
          baseline: span.baseline,
          baselineOffset: baseline == null ? null : baseline * scale,
        ),
      );
    }
    return out;
  }

  /// 普通文本和富文本使用同一条真实布局路径。
  Size layoutContent(BoxConstraints constraints, TextPaintInput input, {bool fillWidth = false}) {
    if (_configuredFor != _keyFor(input)) _configure(_painter, input);
    _dimensions = _placeholders(_painter, constraints, dry: false);
    _painter.setPlaceholderDimensions(_dimensions);
    _minWidth = fillWidth && input.style.box.alignment == null && constraints.hasBoundedWidth
        ? constraints.maxWidth
        : 0;
    _painter.layout(minWidth: _minWidth, maxWidth: _maxWidth(input, constraints.maxWidth));
    _constraints = constraints;
    _input = input;
    _size = constraints.loosen().constrain(_icon ? Size.square(_iconExtent(input)) : _painter.size);
    _clearPaintCache();
    final boxes = _painter.inlinePlaceholderBoxes ?? const <TextBox>[];
    final children = _children();
    for (var i = 0; i < children.length; i++) {
      final data = children[i].parentData! as ElTextParentData;
      data.visible = i < boxes.length;
      data.offset = data.visible ? Offset(boxes[i].left, boxes[i].top) : Offset.zero;
    }
    _updateFade(input);
    return _size;
  }

  /// dry/intrinsic 使用短生命周期 painter，不改主排版及子项位置。
  TextPainter _probe(TextPaintInput input, BoxConstraints constraints, {bool fillWidth = false}) {
    final painter = _configure(TextPainter(), input);
    painter.setPlaceholderDimensions(_placeholders(painter, constraints, dry: true));
    final tight = fillWidth && input.style.box.alignment == null && constraints.hasBoundedWidth;
    return painter
      ..layout(minWidth: tight ? constraints.maxWidth : 0, maxWidth: _maxWidth(input, constraints.maxWidth));
  }

  /// dry 尺寸和基线共用一次独立排版，不改正式 painter 和子项位置。
  ({Size size, double baseline}) computeDryMetrics(
    BoxConstraints constraints,
    TextPaintInput input, {
    bool fillWidth = false,
    TextBaseline baseline = TextBaseline.alphabetic,
  }) {
    final painter = _probe(input, constraints, fillWidth: fillWidth);
    final size = constraints.loosen().constrain(_icon ? Size.square(_iconExtent(input)) : painter.size);
    final distance =
        painter.computeDistanceToActualBaseline(baseline) + (_icon ? (size.height - painter.height) / 2 : 0);
    painter.dispose();
    return (size: size, baseline: distance);
  }

  ContentSizes computeIntrinsicSizes(double width, TextPaintInput input) {
    if (_icon) return ContentSizes(_iconExtent(input), _iconExtent(input));
    final painter = _probe(input, const BoxConstraints());
    final sizes = ContentSizes(painter.minIntrinsicWidth, painter.maxIntrinsicWidth);
    painter.dispose();
    return sizes;
  }

  double intrinsicHeight(TextPaintInput input, double width) =>
      computeDryMetrics(BoxConstraints(maxWidth: width), input).size.height;

  /// 最终盒尺寸确定后统一更新文本原点。
  void repositionAlignedText(TextPaintInput input, {required double contentW, required double contentH}) {
    _input = input;
    _alignment =
        input.style.box.alignment
            ?.resolve(input.textDirection)
            .alongOffset(Offset(contentW - _size.width, contentH - _size.height)) ??
        Offset.zero;
  }

  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      textPaintOrigin.dy + _painter.computeDistanceToActualBaseline(baseline);
  void _refresh(TextPaintInput input) {
    if (_constraints == null) return;
    _input = input;
    if (_configuredFor == _keyFor(input)) return;
    _configure(_painter, input).layout(minWidth: _minWidth, maxWidth: _maxWidth(input, _constraints!.maxWidth));
    _clearPaintCache();
  }

  void _updateFade(TextPaintInput input) {
    overflowShader = null;
    if (_overflow != TextOverflow.fade || !textOverflows) return;
    final probe = TextPainter(
      text: TextSpan(text: '…', style: _baseStyle(input)),
      textDirection: input.textDirection,
      textScaler: input.textScaler,
      locale: input.locale,
    )..layout();
    final horizontal = _painter.width > _size.width;
    final start = horizontal
        ? Offset(input.textDirection == TextDirection.rtl ? probe.width : _size.width - probe.width, 0)
        : Offset(0, _size.height - probe.height / 2);
    final end = horizontal
        ? Offset(input.textDirection == TextDirection.rtl ? 0 : _size.width, 0)
        : Offset(0, _size.height);
    overflowShader = ui.Gradient.linear(start, end, const [Color(0xffffffff), Color(0x00ffffff)]);
    probe.dispose();
  }

  void _paintText(Canvas canvas, Offset origin, TextPaintInput input, TextPainter painter, {bool selected = false}) {
    final gradient = selected ? null : input.style.inheritedText.textGradient;
    if (gradient == null) {
      painter.paint(canvas, origin);
      return;
    }
    final bounds = origin & painter.size;
    var reach = 0.0;
    for (final shadow in input.style.inheritedText.textShadow ?? <Shadow>[]) {
      reach = math.max(reach, shadow.blurRadius * 2 + math.max(shadow.offset.dx.abs(), shadow.offset.dy.abs()));
    }
    canvas.saveLayer(bounds.inflate(reach), Paint());
    painter.paint(canvas, origin);
    canvas.drawRect(
      bounds.inflate(reach),
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = gradient.createShader(bounds, textDirection: input.textDirection),
    );
    canvas.restore();
  }

  /// 选中字形只绘制一次；占位 Widget 在所有文字层之外绘制。
  void paintContent(
    PaintingContext context,
    Offset offset,
    TextPaintInput input, {
    TextRange? selection,
    Color? selectionColor,
    Color? selectionTextColor,
  }) {
    _refresh(input);
    final canvas = context.canvas;
    final origin = offset + textPaintOrigin;
    if (overflowNeedsClipping) {
      if (overflowShader == null) {
        canvas.save();
      } else {
        canvas.saveLayer(origin & _size, Paint());
      }
      canvas.clipRect(origin & _size);
    }
    if (selection != null &&
        selectionColor != null &&
        selectionTextColor == null &&
        _painter.text!.visitChildren((s) => s.style?.background == null && s.style?.backgroundColor == null)) {
      _paintBackground(canvas, offset, _paintRects(selection), selectionColor);
      selection = null;
    }
    final rects = selection == null ? const <Rect>[] : _paintRects(selection);
    final full = selection?.start == 0 && selection?.end == _plain.length;
    final mirror = _icon && (rawChild as IconData).matchTextDirection && input.textDirection == TextDirection.rtl;
    if (mirror) {
      canvas.save();
      canvas.translate(origin.dx * 2 + _painter.width, 0);
      canvas.scale(-1, 1);
    }
    if (!full) {
      if (rects.isNotEmpty) {
        canvas.save();
        for (final rect in rects) {
          canvas.clipRect(rect.shift(offset), clipOp: ui.ClipOp.difference, doAntiAlias: false);
        }
      }
      _paintText(canvas, origin, input, _painter);
      if (rects.isNotEmpty) canvas.restore();
    }
    if (rects.isNotEmpty) {
      if (selectionColor != null) _paintBackground(canvas, offset, rects, selectionColor);
      if (_overlay == null || _overlayColor != selectionTextColor) {
        _overlay?.dispose();
        _overlayColor = selectionTextColor;
        _overlay = _configure(TextPainter(), input)
          ..text = buildSelectionOverlaySpan(_painter.text!, textColor: selectionTextColor)
          ..setPlaceholderDimensions(_dimensions)
          ..layout(minWidth: _minWidth, maxWidth: _maxWidth(input, _constraints!.maxWidth));
        assert(++BenchmarkProbe.selectionOverlayLayoutCount > 0);
      }
      if (!full) {
        final path = Path();
        for (final rect in rects) {
          path.addRect(rect.shift(offset));
        }
        canvas.save();
        canvas.clipPath(path, doAntiAlias: false);
      }
      _paintText(canvas, origin, input, _overlay!, selected: selectionTextColor != null);
      if (!full) canvas.restore();
      full ? debugSelectionUnclippedOverlayCount++ : debugSelectionClipRectOverlayCount++;
    }
    if (mirror) canvas.restore();
    for (final child in _children()) {
      final data = child.parentData! as ElTextParentData;
      if (!data.visible || data.scale == 0) continue;
      context.pushTransform(
        _host!.needsCompositing,
        origin + data.offset,
        Matrix4.diagonal3Values(data.scale, data.scale, 1),
        (inner, off) => inner.paintChild(child, off),
      );
    }
    if (overflowNeedsClipping) {
      if (overflowShader != null) {
        canvas.save();
        canvas.translate(origin.dx, origin.dy);
        canvas.drawRect(
          Offset.zero & _size,
          Paint()
            ..blendMode = BlendMode.modulate
            ..shader = overflowShader,
        );
        canvas.restore();
      }
      canvas.restore();
    }
  }

  /// 按官方 span 字符位置交给框架派发事件，先命中真实占位子项。
  bool hitTestContent(BoxHitTestResult result, Offset position) {
    if (_constraints == null) return false;
    final local = position - textPaintOrigin;
    for (final child in _children().reversed) {
      final data = child.parentData! as ElTextParentData;
      if (!data.visible || data.scale == 0) continue;
      if (result.addWithPaintTransform(
        transform: Matrix4.translationValues(
          textPaintOrigin.dx + data.offset.dx,
          textPaintOrigin.dy + data.offset.dy,
          0,
        )..scaleByDouble(data.scale, data.scale, 1, 1),
        position: position,
        hitTest: (r, p) => child.hitTest(r, position: p),
      )) {
        return true;
      }
    }
    final glyph = _painter.getClosestGlyphForOffset(local);
    if (glyph == null) return false;
    final boxes = _painter.getBoxesForSelection(
      TextSelection(
        baseOffset: glyph.graphemeClusterCodeUnitRange.start,
        extentOffset: glyph.graphemeClusterCodeUnitRange.end,
      ),
    );
    if (!boxes.any((box) => _accepts(box.toRect(), local))) return false;
    final span = _content!.span.getSpanForPosition(TextPosition(offset: glyph.graphemeClusterCodeUnitRange.start));
    // 占位子项没有命中时，不能把它原来的布局盒当作可点击文字挡住后方内容。
    if (span is WidgetSpan) return false;
    if (span is HitTestTarget) result.add(HitTestEntry(span as HitTestTarget));
    return true;
  }

  bool _accepts(Rect box, Offset point) {
    final line = _nearestLine(box.center.dy);
    return box.contains(point) ||
        (line != null &&
            point.dx >= box.left &&
            point.dx <= box.right &&
            point.dy >= line.top &&
            point.dy <= line.bottom);
  }

  @override
  Rect? get selectionHitTestBounds => _lineBands()
      .map((b) => Rect.fromLTRB(b.line.left, b.top, b.line.left + b.line.width, b.bottom))
      .fold<Rect?>(null, (a, b) => a?.expandToInclude(b) ?? b)
      ?.shift(textPaintOrigin);
  @override
  bool selectionContainsLocalPosition(Offset localPosition) => hitTestContent(BoxHitTestResult(), localPosition);
  @override
  int get selectionTextLength => _plain.length;
  @override
  int selectionOffsetForLocalPosition(Offset position, {required double fallbackHalfWidth}) => _constraints == null
      ? (position.dx <= fallbackHalfWidth / 2 ? 0 : _plain.length)
      : _painter.getPositionForOffset(position - textPaintOrigin).offset.clamp(0, _plain.length);
  @override
  String selectionTextForRange(TextRange range) {
    final safe = _range(range);
    return _plain.substring(safe.start, safe.end).replaceAll(RegExp('[\u200b\u2060\ufffc]'), '');
  }

  TextRange _range(TextRange range) =>
      TextRange(start: range.start.clamp(0, _plain.length), end: range.end.clamp(0, _plain.length));
  @override
  TextRange selectionWordBoundaryAt(int offset) {
    final probe = offset.clamp(0, math.max(0, _plain.length - 1)).toInt();
    for (final match in _cjkRun.allMatches(_plain)) {
      if (match.start <= probe && probe < match.end) return TextRange(start: match.start, end: match.end);
    }
    return _constraints == null
        ? TextRange.collapsed(probe)
        : _painter.getWordBoundary(TextPosition(offset: offset.clamp(0, _plain.length)));
  }

  @override
  SelectionCaretGeometry? selectionCaretGeometryAt(int offset) {
    if (_constraints == null || _plain.isEmpty) return null;
    final position = TextPosition(offset: offset.clamp(0, _plain.length));
    return SelectionCaretGeometry(
      position: textPaintOrigin + _painter.getOffsetForCaret(position, Rect.zero),
      lineHeight: _painter.getFullHeightForCaret(position, Rect.zero),
    );
  }

  @override
  SelectionLineGeometry? selectionLineGeometryAt(int offset, {required double fallbackWidth}) {
    final caret = selectionCaretGeometryAt(offset);
    if (caret == null) return null;
    final line = _nearestLine(caret.position.dy - textPaintOrigin.dy + caret.lineHeight / 2)?.line;
    if (line == null) return null;
    return SelectionLineGeometry(
      lineTop: textPaintOrigin.dy + line.baseline - line.ascent,
      lineHeight: line.height,
      lineLeft: textPaintOrigin.dx + line.left,
      lineRight: textPaintOrigin.dx + line.left + line.width,
    );
  }

  _TextLine? _nearestLine(double y) {
    final bands = _lineBands();
    if (bands.isEmpty) return null;
    double distance(_TextLine band) => (band.line.baseline - band.line.ascent + band.line.height / 2 - y).abs();
    return bands.reduce((a, b) => distance(a) <= distance(b) ? a : b);
  }

  List<_TextLine> _lineBands() {
    if (_constraints == null) return const [];
    if (_bands != null) return _bands!;
    final metrics = _painter.computeLineMetrics();
    final boxes = getBoxesForSelectionForTest(0, _plain.length);
    final bands = <_TextLine>[];
    var boxIndex = 0;
    for (var i = 0; i < metrics.length; i++) {
      final line = metrics[i];
      final rawTop = line.baseline - line.ascent;
      final rawBottom = rawTop + line.height;
      var top = rawTop;
      var bottom = rawBottom;
      while (boxIndex < boxes.length && boxes[boxIndex].toRect().center.dy <= rawBottom + .5) {
        final box = boxes[boxIndex++];
        if (box.toRect().center.dy < rawTop - .5) continue;
        top = math.min(top, box.top);
        bottom = math.max(bottom, box.bottom);
      }
      top = top.floorToDouble();
      bottom = bottom.ceilToDouble();
      if (i == 0) top = math.max(top, math.min(0, boxes.isEmpty ? 0 : boxes.first.top.floorToDouble()));
      if (i == metrics.length - 1) {
        bottom = math.min(bottom, math.max(_painter.height, boxes.isEmpty ? 0 : boxes.last.bottom.ceilToDouble()));
      }
      if (bands.isNotEmpty && bottom == bands.last.bottom) {
        top = bands.last.top;
      } else if (bands.isNotEmpty && top > bands.last.top + .5 && top < bands.last.bottom) {
        top = bands.last.bottom;
      }
      bands.add((line: line, top: top, bottom: bottom));
    }
    return _bands = bands;
  }

  List<TextBox> getBoxesForSelectionForTest(int start, int end) => _constraints == null
      ? const []
      : _painter.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end));
  @override
  List<Rect> selectionPaintRectsForRange(TextRange range) {
    final safe = _range(range);
    final result = <Rect>[];
    final bands = _lineBands();
    var index = 0;
    for (final box in getBoxesForSelectionForTest(safe.start, safe.end)) {
      if (box.toRect().isEmpty) continue;
      // 子参与者已有实际选区时由它绘制；独立几何查询仍返回完整占位盒。
      final placeholderIndex = (_painter.inlinePlaceholderBoxes ?? const <TextBox>[]).indexWhere(
        (placeholder) => placeholder.toRect() == box.toRect(),
      );
      if (placeholderIndex >= 0 &&
          selectionParticipantOf(_children()[placeholderIndex])?.currentSelectionRange?.isCollapsed == false) {
        continue;
      }
      while (index < bands.length - 1 &&
          box.toRect().center.dy > bands[index].line.baseline + bands[index].line.descent + .5) {
        index++;
      }
      final line = bands.isEmpty ? null : bands[index];
      result.add(
        Rect.fromLTRB(box.left, line?.top ?? box.top, box.right, line?.bottom ?? box.bottom).shift(textPaintOrigin),
      );
    }
    return result;
  }

  @override
  List<Rect> adjustedSelectionPaintRectsForRange(TextRange range, {required Size nodeSize}) {
    final bands = _lineBands();
    final bounds = Rect.fromLTRB(
      0,
      math.min(0, bands.isEmpty ? 0 : bands.first.top + textPaintOrigin.dy),
      nodeSize.width,
      math.max(nodeSize.height, bands.isEmpty ? nodeSize.height : bands.last.bottom + textPaintOrigin.dy),
    );
    return [
      for (final rect in selectionPaintRectsForRange(range))
        if (!rect.intersect(bounds).isEmpty) rect.intersect(bounds),
    ];
  }

  List<Rect> _paintRects(TextRange range) {
    final origin = textPaintOrigin;
    final size = _host!.size;
    final cache = _rects;
    if (cache != null && cache.range == range && cache.origin == origin && cache.size == size) return cache.rects;
    final rects = _participant!.adjustedSelectionPaintRectsForRange(range);
    _rects = (range: range, origin: origin, size: size, rects: rects);
    return rects;
  }

  void _paintBackground(Canvas canvas, Offset offset, List<Rect> rects, Color color) {
    final paint = Paint()..color = color;
    paint.isAntiAlias = false;
    for (final rect in rects) {
      canvas.drawRect(rect.shift(offset), paint);
    }
  }

  @override
  void paintSelectionRange(Canvas canvas, Offset offset, TextRange range, Color color, {required Size nodeSize}) =>
      _paintBackground(canvas, offset, adjustedSelectionPaintRectsForRange(range, nodeSize: nodeSize), color);

  /// 卸载时归还选区、字体监听和两个 painter。
  void dispose() {
    _participant?.detachFromSelectionRoot();
    _participant?.dispose();
    _participant = null;
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _painter.dispose();
    _overlay?.dispose();
    _host = null;
  }
}

final _cjkRun = RegExp(
  r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u3040-\u30ff\u31f0-\u31ff\uac00-\ud7af\u{20000}-\u{2fa1f}]+',
  unicode: true,
);

/// 供选区根判断双击范围是否为完整 CJK 连跑。
bool elRangeIsCjkRun(String text, TextRange range) =>
    range.isValid &&
    !range.isCollapsed &&
    range.end <= text.length &&
    _cjkRun.matchAsPrefix(text, range.start)?.end == range.end;
