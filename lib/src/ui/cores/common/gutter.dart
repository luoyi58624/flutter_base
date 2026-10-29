// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 单个可见序号的几何输入。
typedef ElOrdinalGutterEntry = ({
  int viewIndex,
  int ordinal,
  int referenceOrdinal,
  bool active,
  bool isLast,
  double top,
  double height,
  double? baseline,
});

/// 按当前 gutter 尺寸提供需要绘制的可见序号。
typedef ElOrdinalGutterEntriesBuilder = Iterable<ElOrdinalGutterEntry> Function(Size size);

/// 最近一帧实际绘制的序号快照。
typedef ElOrdinalGutterPaintEntry = ({int viewIndex, int ordinal, String label, bool active, Rect? textBounds});

/// 数字序号 gutter 的统一测量与绘制内核。
///
/// 本类型不参与文本选择和自身命中；宿主只负责提供可见序号及其行几何。
final class ElRenderOrdinalGutter extends RenderBox {
  /// 创建共享序号渲染器，数字区整体居中、区内数字默认右对齐。
  ElRenderOrdinalGutter({
    required int totalRows,
    required int firstNumber,
    required int minChars,
    required List<TextStyle> styles,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required EdgeInsets padding,
    required int mode,
    required ElOrdinalGutterEntriesBuilder entriesBuilder,
    TextAlign textAlign = TextAlign.right,
    AlignmentGeometry alignment = Alignment.center,
    Locale? locale,
    Listenable? repaint,
    ValueChanged<List<ElOrdinalGutterPaintEntry>>? onPaint,
  }) : _totalRows = totalRows,
       _firstNumber = firstNumber,
       _minChars = minChars,
       _styles = styles,
       _textDirection = textDirection,
       _textScaler = textScaler,
       _padding = padding,
       _mode = mode,
       _textAlign = textAlign,
       _alignment = alignment,
       _entriesBuilder = entriesBuilder,
       _locale = locale,
       _repaint = repaint,
       _onPaint = onPaint;

  /// 创建只绘制一个绝对序号的表格行渲染器。
  ElRenderOrdinalGutter.single({
    required int totalRows,
    required int firstNumber,
    required int rowIndex,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
    TextAlign textAlign = TextAlign.right,
    AlignmentGeometry alignment = Alignment.center,
    Locale? locale,
  }) : this(
         totalRows: totalRows,
         firstNumber: firstNumber,
         minChars: 1,
         styles: <TextStyle>[style],
         textDirection: textDirection,
         textScaler: textScaler,
         padding: EdgeInsets.zero,
         textAlign: textAlign,
         alignment: alignment,
         mode: absolute,
         entriesBuilder: _singleEntryBuilder(totalRows: totalRows, firstNumber: firstNumber, rowIndex: rowIndex),
         locale: locale,
       );

  /// 每行显示绝对序号。
  static const int absolute = 0;

  /// 活动行显示绝对序号，其余行显示距离。
  static const int relative = 1;

  /// 只显示活动行、末行和十行间隔。
  static const int interval = 2;

  /// 把零基展示行转换为序号。
  static int ordinalAt(int rowIndex, {int firstNumber = 1}) => firstNumber + rowIndex;

  int _totalRows;
  int _firstNumber;
  int _minChars;
  List<TextStyle> _styles;
  TextDirection _textDirection;
  TextScaler _textScaler;
  EdgeInsets _padding;
  int _mode;
  TextAlign _textAlign;
  AlignmentGeometry _alignment;
  ElOrdinalGutterEntriesBuilder _entriesBuilder;
  Locale? _locale;
  Listenable? _repaint;
  ValueChanged<List<ElOrdinalGutterPaintEntry>>? _onPaint;

  double? _preferredWidth;
  double? _numberWidth;
  final TextPainter _painter = TextPainter(maxLines: 1, textAlign: TextAlign.right);
  List<ElOrdinalGutterPaintEntry> _debugPaintEntries = const [];

  /// 最近一帧实际绘制的标签，仅供白盒测试验证统一渲染路径。
  List<ElOrdinalGutterPaintEntry> get debugPaintEntries => _debugPaintEntries;

  /// 按完整序号范围的文本宽度、最少字符占位和内边距解析总宽度。
  static double measureWidth({
    required int totalRows,
    int firstNumber = 1,
    int minChars = 1,
    required Iterable<TextStyle> styles,
    required TextDirection textDirection,
    required TextScaler textScaler,
    EdgeInsets padding = EdgeInsets.zero,
    Locale? locale,
  }) {
    assert(totalRows >= 0);
    assert(minChars > 0);
    final styleList = styles.toList(growable: false);
    assert(styleList.isNotEmpty);
    final lastNumber = firstNumber + (totalRows > 0 ? totalRows - 1 : 0);
    var width = 0.0;
    final painter = TextPainter(textDirection: textDirection, textScaler: textScaler, locale: locale, maxLines: 1);
    for (final style in styleList) {
      var widestDigit = '0';
      var digitWidth = 0.0;
      for (var digit = 0; digit <= 9; digit++) {
        painter.text = TextSpan(text: '$digit', style: style);
        painter.layout();
        if (painter.width > digitWidth) {
          digitWidth = painter.width;
          widestDigit = '$digit';
        }
      }
      // 最少字符只保留外层占位；内容宽不能虚构范围外的 99999 等五位序号。
      final candidates = <String>{widestDigit * minChars};
      if (lastNumber >= 0) {
        candidates.addAll(_rangeWidthCandidates(math.max(0, firstNumber), lastNumber, widestDigit));
      }
      if (firstNumber < 0) {
        candidates.addAll(
          _rangeWidthCandidates(math.max(1, -lastNumber), -firstNumber, widestDigit).map((label) => '-$label'),
        );
      }
      for (final label in candidates) {
        painter.text = TextSpan(text: label, style: style);
        painter.layout();
        width = math.max(width, painter.width);
      }
    }
    painter.dispose();
    return width + padding.horizontal;
  }

  // 固定前缀处脱离上下界后，剩余位置取最宽数字；候选数量只随位数增长。
  static Iterable<String> _rangeWidthCandidates(int first, int last, String widestDigit) sync* {
    yield '$first';
    yield '$last';
    bool inRange(String label) {
      if (label.length > 1 && label.startsWith('0')) return false;
      final number = int.tryParse(label);
      return number != null && number >= first && number <= last;
    }

    for (var length = '$first'.length; length <= '$last'.length; length++) {
      for (var leading = 1; leading <= 9; leading++) {
        final repeated = '$leading${widestDigit * (length - 1)}';
        if (inRange(repeated)) yield repeated;
      }
      for (final bound in ['$first', '$last']) {
        if (bound.length != length) continue;
        for (var index = 0; index < length; index++) {
          for (var digit = 0; digit <= 9; digit++) {
            final label = '${bound.substring(0, index)}$digit${widestDigit * (length - index - 1)}';
            if (inRange(label)) yield label;
          }
        }
      }
    }
  }

  /// 包含最少字符预留和内边距的自然宽度。
  double get preferredWidth => _preferredWidth ??= measureWidth(
    totalRows: _totalRows,
    firstNumber: _firstNumber,
    minChars: _minChars,
    styles: _styles,
    textDirection: _textDirection,
    textScaler: _textScaler,
    padding: _padding,
    locale: _locale,
  );

  /// 同步配置；对齐变化只重绘，不改变区域宽度。
  void configure({
    required int totalRows,
    required int firstNumber,
    required int minChars,
    required List<TextStyle> styles,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required EdgeInsets padding,
    required int mode,
    required ElOrdinalGutterEntriesBuilder entriesBuilder,
    TextAlign textAlign = TextAlign.right,
    AlignmentGeometry alignment = Alignment.center,
    Locale? locale,
    Listenable? repaint,
    ValueChanged<List<ElOrdinalGutterPaintEntry>>? onPaint,
  }) {
    final layoutChanged =
        _totalRows != totalRows ||
        _firstNumber != firstNumber ||
        _minChars != minChars ||
        !listEquals(_styles, styles) ||
        _textDirection != textDirection ||
        _textScaler != textScaler ||
        _padding != padding ||
        _locale != locale;
    final paintChanged =
        layoutChanged ||
        _textAlign != textAlign ||
        _alignment != alignment ||
        _mode != mode ||
        !identical(_entriesBuilder, entriesBuilder) ||
        !identical(_onPaint, onPaint);
    if (!identical(_repaint, repaint)) {
      if (attached) _repaint?.removeListener(markNeedsPaint);
      _repaint = repaint;
      if (attached) _repaint?.addListener(markNeedsPaint);
    }
    _totalRows = totalRows;
    _firstNumber = firstNumber;
    _minChars = minChars;
    _styles = styles;
    _textDirection = textDirection;
    _textScaler = textScaler;
    _padding = padding;
    _mode = mode;
    _textAlign = textAlign;
    _alignment = alignment;
    _entriesBuilder = entriesBuilder;
    _locale = locale;
    _onPaint = onPaint;
    if (layoutChanged) {
      _preferredWidth = null;
      _numberWidth = null;
      markNeedsLayout();
    } else if (paintChanged) {
      markNeedsPaint();
    }
  }

  /// 更新单个绝对序号，不在表格宿主重复装配绘制参数。
  void configureSingle({
    required int totalRows,
    required int firstNumber,
    required int rowIndex,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
    TextAlign textAlign = TextAlign.right,
    AlignmentGeometry alignment = Alignment.center,
    Locale? locale,
  }) {
    configure(
      totalRows: totalRows,
      firstNumber: firstNumber,
      minChars: 1,
      styles: <TextStyle>[style],
      textDirection: textDirection,
      textScaler: textScaler,
      padding: EdgeInsets.zero,
      textAlign: textAlign,
      alignment: alignment,
      mode: absolute,
      entriesBuilder: _singleEntryBuilder(totalRows: totalRows, firstNumber: firstNumber, rowIndex: rowIndex),
      locale: locale,
    );
  }

  static ElOrdinalGutterEntriesBuilder _singleEntryBuilder({
    required int totalRows,
    required int firstNumber,
    required int rowIndex,
  }) =>
      (size) => <ElOrdinalGutterEntry>[
        (
          viewIndex: rowIndex,
          ordinal: ordinalAt(rowIndex, firstNumber: firstNumber),
          referenceOrdinal: ordinalAt(rowIndex, firstNumber: firstNumber),
          active: false,
          isLast: rowIndex == totalRows - 1,
          top: 0,
          height: size.height,
          baseline: null,
        ),
      ];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
    PaintingBinding.instance.systemFonts.addListener(_handleFontsChanged);
  }

  @override
  void detach() {
    _repaint?.removeListener(markNeedsPaint);
    PaintingBinding.instance.systemFonts.removeListener(_handleFontsChanged);
    super.detach();
  }

  void _handleFontsChanged() {
    _preferredWidth = null;
    _numberWidth = null;
    _painter.markNeedsLayout();
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight;
    final width = constraints.hasTightWidth ? constraints.maxWidth : preferredWidth;
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  double computeMinIntrinsicWidth(double height) => preferredWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => preferredWidth;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      _debugPaintEntries = const [];
      _onPaint?.call(_debugPaintEntries);
      return;
    }
    final availableWidth = math.max(0.0, size.width - _padding.horizontal);
    // minChars 只保留外层占位；数字始终在实际序号所需的宽度内对齐。
    final numberWidth = _numberWidth ??= measureWidth(
      totalRows: _totalRows,
      firstNumber: _firstNumber,
      styles: _styles,
      textDirection: _textDirection,
      textScaler: _textScaler,
      locale: _locale,
    );
    final contentWidth = math.min(availableWidth, numberWidth);
    final dx =
        _padding.left + _alignment.resolve(_textDirection).alongOffset(Offset(availableWidth - contentWidth, 0)).dx;
    final snapshot = <ElOrdinalGutterPaintEntry>[];
    context.canvas.save();
    context.canvas.clipRect(offset & size);
    for (final entry in _entriesBuilder(size)) {
      final label = _labelFor(entry);
      if (label.isEmpty) {
        snapshot.add((
          viewIndex: entry.viewIndex,
          ordinal: entry.ordinal,
          label: label,
          active: entry.active,
          textBounds: null,
        ));
        continue;
      }
      final styleIndex = entry.active && _styles.length > 1 ? 1 : 0;
      _painter
        ..text = TextSpan(text: label, style: _styles[styleIndex])
        ..textAlign = _textAlign
        ..textDirection = _textDirection
        ..textScaler = _textScaler
        ..locale = _locale
        ..layout(minWidth: contentWidth, maxWidth: contentWidth);
      final lineMetrics = _painter.computeLineMetrics();
      final painterBaseline = lineMetrics.isEmpty ? _painter.height : lineMetrics.first.baseline;
      final dy = entry.baseline == null
          ? entry.top + (entry.height - _painter.height) / 2
          : entry.top + entry.baseline! - painterBaseline;
      final origin = Offset(dx, dy);
      final boxes = _painter.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: label.length));
      Rect? textBounds;
      for (final box in boxes) {
        final rect = box.toRect().shift(origin);
        textBounds = textBounds?.expandToInclude(rect) ?? rect;
      }
      snapshot.add((
        viewIndex: entry.viewIndex,
        ordinal: entry.ordinal,
        label: label,
        active: entry.active,
        textBounds: textBounds,
      ));
      _painter.paint(context.canvas, offset + origin);
    }
    context.canvas.restore();
    _debugPaintEntries = List<ElOrdinalGutterPaintEntry>.unmodifiable(snapshot);
    _onPaint?.call(_debugPaintEntries);
  }

  String _labelFor(ElOrdinalGutterEntry entry) => switch (_mode) {
    relative when !entry.active => '${(entry.ordinal - entry.referenceOrdinal).abs()}',
    interval when !entry.active && entry.ordinal % 10 != 0 && !entry.isLast => '',
    _ => '${entry.ordinal}',
  };

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}

/// [ElRenderOrdinalGutter] 的 Widget 挂载壳，供编辑器和表格等宿主复用。
class ElOrdinalGutterHost extends LeafRenderObjectWidget {
  /// 创建共享序号视图。
  const ElOrdinalGutterHost({
    super.key,
    required this.totalRows,
    this.firstNumber = 1,
    this.minChars = 1,
    required this.styles,
    required this.textDirection,
    required this.textScaler,
    this.padding = EdgeInsets.zero,
    this.mode = ElRenderOrdinalGutter.absolute,
    required this.entriesBuilder,
    this.textAlign = TextAlign.right,
    this.alignment = Alignment.center,
    this.locale,
    this.repaint,
    this.onPaint,
  });

  /// 创建只绘制一个绝对序号的表格单元格 gutter。
  ElOrdinalGutterHost.single({
    Key? key,
    required int totalRows,
    required int firstNumber,
    required int rowIndex,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
    TextAlign textAlign = TextAlign.right,
    AlignmentGeometry alignment = Alignment.center,
    Locale? locale,
  }) : this(
         key: key,
         totalRows: totalRows,
         firstNumber: firstNumber,
         styles: <TextStyle>[style],
         textDirection: textDirection,
         textScaler: textScaler,
         textAlign: textAlign,
         alignment: alignment,
         locale: locale,
         entriesBuilder: ElRenderOrdinalGutter._singleEntryBuilder(
           totalRows: totalRows,
           firstNumber: firstNumber,
           rowIndex: rowIndex,
         ),
       );

  /// 总行数，用于确定数字区宽度。
  final int totalRows;

  /// 首行序号。
  final int firstNumber;

  /// 外层至少预留的字符数，不扩大数字对齐区域。
  final int minChars;

  /// 普通和活动序号的样式，宽度取所有样式的最大值。
  final List<TextStyle> styles;

  /// 文字方向，也用于解析方向性对齐。
  final TextDirection textDirection;

  /// 测量和绘制共用的文字缩放。
  final TextScaler textScaler;

  /// 外层区域内边距。
  final EdgeInsets padding;

  /// 绝对、相对或间隔序号模式。
  final int mode;

  /// 当前可见序号及行几何。
  final ElOrdinalGutterEntriesBuilder entriesBuilder;

  /// 数字在测量宽度内的对齐方式，默认右对齐。
  final TextAlign textAlign;

  /// 数字区在外层可用宽度中的水平对齐，默认居中；垂直位置由行几何决定。
  final AlignmentGeometry alignment;

  /// 文本排版语言。
  final Locale? locale;

  /// 可见行或光标变化时触发重绘。
  final Listenable? repaint;

  /// 接收最近一帧的标签和实际文字布局盒。
  final ValueChanged<List<ElOrdinalGutterPaintEntry>>? onPaint;

  @override
  ElRenderOrdinalGutter createRenderObject(BuildContext context) => ElRenderOrdinalGutter(
    totalRows: totalRows,
    firstNumber: firstNumber,
    minChars: minChars,
    styles: styles,
    textDirection: textDirection,
    textScaler: textScaler,
    padding: padding,
    textAlign: textAlign,
    alignment: alignment,
    mode: mode,
    entriesBuilder: entriesBuilder,
    locale: locale,
    repaint: repaint,
    onPaint: onPaint,
  );

  @override
  void updateRenderObject(BuildContext context, ElRenderOrdinalGutter renderObject) {
    renderObject.configure(
      totalRows: totalRows,
      firstNumber: firstNumber,
      minChars: minChars,
      styles: styles,
      textDirection: textDirection,
      textScaler: textScaler,
      padding: padding,
      textAlign: textAlign,
      alignment: alignment,
      mode: mode,
      entriesBuilder: entriesBuilder,
      locale: locale,
      repaint: repaint,
      onPaint: onPaint,
    );
  }
}
