import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show CustomClipper;
import 'package:flutter/services.dart' show MouseCursor;

import '../../../../utils/internal/benchmark_probe.dart';
import '../dimension.dart';
import '../style.dart';
import 'inherited_vars.dart';
import 'resolved_style.dart';

/// 可变的 ResolvedStyle 构造器。cascade 主算法内部使用。
class ResolvedStyleBuilder {
  /// 从父节点创建：默认借父引用，box 取 initial。
  ResolvedStyleBuilder.fromParent(ResolvedStyle? parent)
    : _inheritedText = InheritedText.fromInheritedParent(parent?.inheritedText),
      _inheritedBox = parent?.inheritedBox ?? InheritedBox.initial,
      _box = Box.initial,
      _inheritedVars = parent?.inheritedVars ?? InheritedVars.empty;

  /// 创建空白根。
  ResolvedStyleBuilder.empty() : this.fromParent(null);

  /// 从已有 [ResolvedStyle] 创建（用于 cascade tick 单字段覆写）。
  ///
  /// 三组都按 existing 的引用初始化，**不**借父；这是个"差量更新"入口。
  ResolvedStyleBuilder.fromExisting(ResolvedStyle existing)
    : _inheritedText = existing.inheritedText,
      _inheritedBox = existing.inheritedBox,
      _box = existing.box,
      _inheritedVars = existing.inheritedVars;

  final InheritedText _inheritedText;
  final InheritedBox _inheritedBox;
  final Box _box;

  InheritedVars _inheritedVars;

  /// 按级联顺序合并当前层变量，无声明时共享已有表。
  void mergeVars(Map<Object, Object>? local) {
    _inheritedVars = _inheritedVars.merge(local);
  }

  /// 同值合并结果复用旧实例，避免无效向后代传播。
  void stabilizeVars(InheritedVars previous) {
    _inheritedVars = _inheritedVars.stabilize(previous);
  }

  // 每组只在首次写入时创建缓冲，build 时一次性合并覆盖。
  BoxStyleBuffer? _boxBufferLazy;
  InheritedTextStyleBuffer? _inheritedTextBufferLazy;
  InheritedBoxStyleBuffer? _inheritedBoxBufferLazy;

  BoxStyleBuffer get _boxBuffer => _boxBufferLazy ??= BoxStyleBuffer();
  InheritedTextStyleBuffer get _inheritedTextBuffer => _inheritedTextBufferLazy ??= InheritedTextStyleBuffer();
  InheritedBoxStyleBuffer get _inheritedBoxBuffer => _inheritedBoxBufferLazy ??= InheritedBoxStyleBuffer();

  /// 产出不可变快照。
  ResolvedStyle build() {
    assert(() {
      BenchmarkProbe.builderBuildCount++;
      return true;
    }());
    // 常态路径每组 flush 一次，dirty=false 直接返回 base 零分配；
    // 未建 buffer（该组零写入）直接取 base，连 flush 都省。
    var box = _boxBufferLazy?.flush(_box) ?? _box;
    var text = _inheritedTextBufferLazy?.flush(_inheritedText) ?? _inheritedText;
    final inheritedBox = _inheritedBoxBufferLazy?.flush(_inheritedBox) ?? _inheritedBox;
    final w = box.width;
    if (w is ElDimension && w.isNegative) {
      writeWidth(null);
      box = _boxBuffer.flush(_box);
    }
    final h = box.height;
    if (h is ElDimension && h.isNegative) {
      writeHeight(null);
      box = _boxBuffer.flush(_box);
    }
    final lh = text.lineHeight;
    if (lh != null && lh < 0) {
      writeLineHeight(null);
      text = _inheritedTextBuffer.flush(_inheritedText);
    }
    final m = text.maxLines;
    if (m != null && m <= 0) {
      writeMaxLines(null);
      text = _inheritedTextBuffer.flush(_inheritedText);
    }
    return ResolvedStyle(inheritedText: text, inheritedBox: inheritedBox, box: box, inheritedVars: _inheritedVars);
  }

  /// 写入 color 的样式值。
  void writeColor(Color? v) => _inheritedTextBuffer.writeColor(v);

  /// 写入 fontSize 的样式值。
  void writeFontSize(double? v) => _inheritedTextBuffer.writeFontSize(v);

  /// 写入 fontWeight 的样式值。
  void writeFontWeight(FontWeight? v) => _inheritedTextBuffer.writeFontWeight(v);

  /// 写入 fontStyle 的样式值。
  void writeFontStyle(FontStyle? v) => _inheritedTextBuffer.writeFontStyle(v);

  /// 写入 fontFamily 的样式值。
  void writeFontFamily(String? v) => _inheritedTextBuffer.writeFontFamily(v);

  /// 写入 fontFamilyFallback 的样式值。
  void writeFontFamilyFallback(List<String>? v) => _inheritedTextBuffer.writeFontFamilyFallback(v);

  /// 写入 lineHeight 的样式值。
  void writeLineHeight(double? v) => _inheritedTextBuffer.writeLineHeight(v);

  /// 写入 letterSpacing 的样式值。
  void writeLetterSpacing(double? v) => _inheritedTextBuffer.writeLetterSpacing(v);

  /// 写入 wordSpacing 的样式值。
  void writeWordSpacing(double? v) => _inheritedTextBuffer.writeWordSpacing(v);

  /// 写入 fontFeatureSettings 的样式值。
  void writeFontFeatureSettings(List<FontFeature>? v) => _inheritedTextBuffer.writeFontFeatureSettings(v);

  /// 写入 fontVariationSettings 的样式值。
  void writeFontVariationSettings(List<FontVariation>? v) => _inheritedTextBuffer.writeFontVariationSettings(v);

  /// 写入 textAlign 的样式值。
  void writeTextAlign(TextAlign? v) => _inheritedTextBuffer.writeTextAlign(v);

  /// 写入 textBaseline 的样式值。
  void writeTextBaseline(TextBaseline? v) => _inheritedTextBuffer.writeTextBaseline(v);

  /// 写入 leadingDistribution 的样式值。
  void writeLeadingDistribution(TextLeadingDistribution? v) => _inheritedTextBuffer.writeLeadingDistribution(v);

  /// 写入 textShadow 的样式值。
  void writeTextShadow(List<Shadow>? v) => _inheritedTextBuffer.writeTextShadow(v);

  /// 写入 textGradient 的样式值。
  void writeTextGradient(Gradient? v) => _inheritedTextBuffer.writeTextGradient(v);

  /// 写入 textDecorationLine 的样式值。
  void writeTextDecorationLine(TextDecoration? v) => _inheritedTextBuffer.writeTextDecorationLine(v);

  /// 写入 textDecorationColor 的样式值。
  void writeTextDecorationColor(Color? v) => _inheritedTextBuffer.writeTextDecorationColor(v);

  /// 写入 textDecorationStyle 的样式值。
  void writeTextDecorationStyle(TextDecorationStyle? v) => _inheritedTextBuffer.writeTextDecorationStyle(v);

  /// 写入 textDecorationThickness 的样式值。
  void writeTextDecorationThickness(double? v) => _inheritedTextBuffer.writeTextDecorationThickness(v);

  /// 写入 textBackgroundColor 的样式值。
  void writeTextBackgroundColor(Color? v) => _inheritedTextBuffer.writeTextBackgroundColor(v);

  /// 写入 softWrap 的样式值。
  void writeSoftWrap(bool? v) => _inheritedTextBuffer.writeSoftWrap(v);

  /// 写入 textOverflow 的样式值。
  void writeTextOverflow(TextOverflow? v) => _inheritedTextBuffer.writeTextOverflow(v);

  /// 写入 maxLines 的样式值。
  void writeMaxLines(int? v) => _inheritedTextBuffer.writeMaxLines(v);

  /// 写入 direction 的样式值。
  void writeDirection(TextDirection? v) => _inheritedBoxBuffer.writeDirection(v);

  /// 写入 cursor 的样式值。
  void writeCursor(MouseCursor? v) => _inheritedBoxBuffer.writeCursor(v);

  /// 写入 pointerEvents 的样式值。
  void writePointerEvents(ElPointerEvents? v) => _inheritedBoxBuffer.writePointerEvents(v);

  /// 写入 iconSize 的样式值。
  void writeIconSize(double? v) => _inheritedBoxBuffer.writeIconSize(v);

  /// 写入 iconColor 的样式值。
  void writeIconColor(Color? v) => _inheritedBoxBuffer.writeIconColor(v);

  /// 写入 width 的样式值。
  void writeWidth(ElDimension? v) => _boxBuffer.writeWidth(v);

  /// 写入 height 的样式值。
  void writeHeight(ElDimension? v) => _boxBuffer.writeHeight(v);

  /// 写入 widthFactor 的样式值。
  void writeWidthFactor(double? v) => _boxBuffer.writeWidthFactor(v);

  /// 写入 heightFactor 的样式值。
  void writeHeightFactor(double? v) => _boxBuffer.writeHeightFactor(v);

  /// 写入 backgroundColor 的样式值。
  void writeBackgroundColor(Color? v) => _boxBuffer.writeBackgroundColor(v);

  /// 写入 padding 的样式值。
  void writePadding(EdgeInsetsGeometry? v) => _boxBuffer.writePadding(v);

  /// 写入 margin 的样式值。
  void writeMargin(EdgeInsetsGeometry? v) => _boxBuffer.writeMargin(v);

  /// 写入 alignment 的样式值。
  void writeAlignment(AlignmentGeometry? v) => _boxBuffer.writeAlignment(v);

  /// 写入 border 的样式值。
  void writeBorder(ElBorder? v) => _boxBuffer.writeBorder(v);

  /// 写入 borderRadius 的样式值。
  void writeBorderRadius(BorderRadiusGeometry? v) => _boxBuffer.writeBorderRadius(v);

  /// 写入 clipPath 的样式值。
  void writeClipPath(CustomClipper<Path>? v) => _boxBuffer.writeClipPath(v);

  /// 写入 boxShadow 的样式值。
  void writeBoxShadow(List<BoxShadow>? v) => _boxBuffer.writeBoxShadow(v);

  /// 写入 minWidth 的样式值。
  void writeMinWidth(ElDimension? v) => _boxBuffer.writeMinWidth(v);

  /// 写入 maxWidth 的样式值。
  void writeMaxWidth(ElDimension? v) => _boxBuffer.writeMaxWidth(v);

  /// 写入 minHeight 的样式值。
  void writeMinHeight(ElDimension? v) => _boxBuffer.writeMinHeight(v);

  /// 写入 maxHeight 的样式值。
  void writeMaxHeight(ElDimension? v) => _boxBuffer.writeMaxHeight(v);

  /// 写入 opacity 的样式值。
  void writeOpacity(double? v) => _boxBuffer.writeOpacity(v);

  /// 写入 transform 的样式值。
  void writeTransform(ElTransform? v) => _boxBuffer.writeTransform(v);

  /// 写入 transformOrigin 的样式值。
  void writeTransformOrigin(AlignmentGeometry? v) => _boxBuffer.writeTransformOrigin(v);

  /// 写入 clipBehavior 的样式值。
  void writeClipBehavior(Clip? v) => _boxBuffer.writeClipBehavior(v);

  /// 写入 gradient 的样式值。
  void writeGradient(Gradient? v) => _boxBuffer.writeGradient(v);

  /// 写入 backgroundImage 的样式值。
  void writeBackgroundImage(DecorationImage? v) => _boxBuffer.writeBackgroundImage(v);

  /// 写入 outline 的样式值。
  void writeOutline(ElOutline? v) => _boxBuffer.writeOutline(v);

  /// 写入 aspectRatio 的样式值。
  void writeAspectRatio(double? v) => _boxBuffer.writeAspectRatio(v);

  /// 写入 filter 的样式值。
  void writeFilter(ElFilter? v) => _boxBuffer.writeFilter(v);

  /// 写入 backdropFilter 的样式值。
  void writeBackdropFilter(ElFilter? v) => _boxBuffer.writeBackdropFilter(v);
}

/// InheritedText 的延迟写缓冲，一次构建合并本轮全部覆盖。
class InheritedTextStyleBuffer {
  static const Object _unset = Object();

  Object? _color = _unset;
  Object? _fontSize = _unset;
  Object? _fontWeight = _unset;
  Object? _fontStyle = _unset;
  Object? _fontFamily = _unset;
  Object? _fontFamilyFallback = _unset;
  Object? _lineHeight = _unset;
  Object? _letterSpacing = _unset;
  Object? _wordSpacing = _unset;
  Object? _fontFeatureSettings = _unset;
  Object? _fontVariationSettings = _unset;
  Object? _textAlign = _unset;
  Object? _textBaseline = _unset;
  Object? _leadingDistribution = _unset;
  Object? _textShadow = _unset;
  Object? _textGradient = _unset;
  Object? _textDecorationLine = _unset;
  Object? _textDecorationColor = _unset;
  Object? _textDecorationStyle = _unset;
  Object? _textDecorationThickness = _unset;
  Object? _textBackgroundColor = _unset;
  Object? _softWrap = _unset;
  Object? _textOverflow = _unset;
  Object? _maxLines = _unset;

  /// 是否接收过字段写入。
  bool isDirty = false;

  /// 暂存 color 的覆盖值。
  void writeColor(Object? v) {
    _color = v as Color?;
    isDirty = true;
  }

  /// 暂存 fontSize 的覆盖值。
  void writeFontSize(Object? v) {
    _fontSize = v as double?;
    isDirty = true;
  }

  /// 暂存 fontWeight 的覆盖值。
  void writeFontWeight(Object? v) {
    _fontWeight = v as FontWeight?;
    isDirty = true;
  }

  /// 暂存 fontStyle 的覆盖值。
  void writeFontStyle(Object? v) {
    _fontStyle = v as FontStyle?;
    isDirty = true;
  }

  /// 暂存 fontFamily 的覆盖值。
  void writeFontFamily(Object? v) {
    _fontFamily = v as String?;
    isDirty = true;
  }

  /// 暂存 fontFamilyFallback 的覆盖值。
  void writeFontFamilyFallback(Object? v) {
    _fontFamilyFallback = v as List<String>?;
    isDirty = true;
  }

  /// 暂存 lineHeight 的覆盖值。
  void writeLineHeight(Object? v) {
    _lineHeight = v as double?;
    isDirty = true;
  }

  /// 暂存 letterSpacing 的覆盖值。
  void writeLetterSpacing(Object? v) {
    _letterSpacing = v as double?;
    isDirty = true;
  }

  /// 暂存 wordSpacing 的覆盖值。
  void writeWordSpacing(Object? v) {
    _wordSpacing = v as double?;
    isDirty = true;
  }

  /// 暂存 fontFeatureSettings 的覆盖值。
  void writeFontFeatureSettings(Object? v) {
    _fontFeatureSettings = v as List<FontFeature>?;
    isDirty = true;
  }

  /// 暂存 fontVariationSettings 的覆盖值。
  void writeFontVariationSettings(Object? v) {
    _fontVariationSettings = v as List<FontVariation>?;
    isDirty = true;
  }

  /// 暂存 textAlign 的覆盖值。
  void writeTextAlign(Object? v) {
    _textAlign = v as TextAlign?;
    isDirty = true;
  }

  /// 暂存 textBaseline 的覆盖值。
  void writeTextBaseline(Object? v) {
    _textBaseline = v as TextBaseline?;
    isDirty = true;
  }

  /// 暂存 leadingDistribution 的覆盖值。
  void writeLeadingDistribution(Object? v) {
    _leadingDistribution = v as TextLeadingDistribution?;
    isDirty = true;
  }

  /// 暂存 textShadow 的覆盖值。
  void writeTextShadow(Object? v) {
    _textShadow = v as List<Shadow>?;
    isDirty = true;
  }

  /// 暂存 textGradient 的覆盖值。
  void writeTextGradient(Object? v) {
    _textGradient = v as Gradient?;
    isDirty = true;
  }

  /// 暂存 textDecorationLine 的覆盖值。
  void writeTextDecorationLine(Object? v) {
    _textDecorationLine = v as TextDecoration?;
    isDirty = true;
  }

  /// 暂存 textDecorationColor 的覆盖值。
  void writeTextDecorationColor(Object? v) {
    _textDecorationColor = v as Color?;
    isDirty = true;
  }

  /// 暂存 textDecorationStyle 的覆盖值。
  void writeTextDecorationStyle(Object? v) {
    _textDecorationStyle = v as TextDecorationStyle?;
    isDirty = true;
  }

  /// 暂存 textDecorationThickness 的覆盖值。
  void writeTextDecorationThickness(Object? v) {
    _textDecorationThickness = v as double?;
    isDirty = true;
  }

  /// 暂存 textBackgroundColor 的覆盖值。
  void writeTextBackgroundColor(Object? v) {
    _textBackgroundColor = v as Color?;
    isDirty = true;
  }

  /// 暂存 softWrap 的覆盖值。
  void writeSoftWrap(Object? v) {
    _softWrap = v as bool?;
    isDirty = true;
  }

  /// 暂存 textOverflow 的覆盖值。
  void writeTextOverflow(Object? v) {
    _textOverflow = v as TextOverflow?;
    isDirty = true;
  }

  /// 暂存 maxLines 的覆盖值。
  void writeMaxLines(Object? v) {
    _maxLines = v as int?;
    isDirty = true;
  }

  /// 字段实际改变时才构建快照，等值时共享原引用。
  InheritedText flush(InheritedText base) {
    if (!isDirty) return base;
    // 保留等值引用共享，避免无效的级联和继承传播。
    if ((identical(_color, _unset) || _color == base.color) &&
        (identical(_fontSize, _unset) || _fontSize == base.fontSize) &&
        (identical(_fontWeight, _unset) || _fontWeight == base.fontWeight) &&
        (identical(_fontStyle, _unset) || _fontStyle == base.fontStyle) &&
        (identical(_fontFamily, _unset) || _fontFamily == base.fontFamily) &&
        (identical(_fontFamilyFallback, _unset) || _fontFamilyFallback == base.fontFamilyFallback) &&
        (identical(_lineHeight, _unset) || _lineHeight == base.lineHeight) &&
        (identical(_letterSpacing, _unset) || _letterSpacing == base.letterSpacing) &&
        (identical(_wordSpacing, _unset) || _wordSpacing == base.wordSpacing) &&
        (identical(_fontFeatureSettings, _unset) || _fontFeatureSettings == base.fontFeatureSettings) &&
        (identical(_fontVariationSettings, _unset) || _fontVariationSettings == base.fontVariationSettings) &&
        (identical(_textAlign, _unset) || _textAlign == base.textAlign) &&
        (identical(_textBaseline, _unset) || _textBaseline == base.textBaseline) &&
        (identical(_leadingDistribution, _unset) || _leadingDistribution == base.leadingDistribution) &&
        (identical(_textShadow, _unset) || _textShadow == base.textShadow) &&
        (identical(_textGradient, _unset) || _textGradient == base.textGradient) &&
        (identical(_textDecorationLine, _unset) || _textDecorationLine == base.textDecorationLine) &&
        (identical(_textDecorationColor, _unset) || _textDecorationColor == base.textDecorationColor) &&
        (identical(_textDecorationStyle, _unset) || _textDecorationStyle == base.textDecorationStyle) &&
        (identical(_textDecorationThickness, _unset) || _textDecorationThickness == base.textDecorationThickness) &&
        (identical(_textBackgroundColor, _unset) || _textBackgroundColor == base.textBackgroundColor) &&
        (identical(_softWrap, _unset) || _softWrap == base.softWrap) &&
        (identical(_textOverflow, _unset) || _textOverflow == base.textOverflow) &&
        (identical(_maxLines, _unset) || _maxLines == base.maxLines)) {
      return base;
    }
    return InheritedText(
      color: identical(_color, _unset) ? base.color : _color as Color?,
      fontSize: identical(_fontSize, _unset) ? base.fontSize : _fontSize as double?,
      fontWeight: identical(_fontWeight, _unset) ? base.fontWeight : _fontWeight as FontWeight?,
      fontStyle: identical(_fontStyle, _unset) ? base.fontStyle : _fontStyle as FontStyle?,
      fontFamily: identical(_fontFamily, _unset) ? base.fontFamily : _fontFamily as String?,
      fontFamilyFallback: identical(_fontFamilyFallback, _unset)
          ? base.fontFamilyFallback
          : _fontFamilyFallback as List<String>?,
      lineHeight: identical(_lineHeight, _unset) ? base.lineHeight : _lineHeight as double?,
      letterSpacing: identical(_letterSpacing, _unset) ? base.letterSpacing : _letterSpacing as double?,
      wordSpacing: identical(_wordSpacing, _unset) ? base.wordSpacing : _wordSpacing as double?,
      fontFeatureSettings: identical(_fontFeatureSettings, _unset)
          ? base.fontFeatureSettings
          : _fontFeatureSettings as List<FontFeature>?,
      fontVariationSettings: identical(_fontVariationSettings, _unset)
          ? base.fontVariationSettings
          : _fontVariationSettings as List<FontVariation>?,
      textAlign: identical(_textAlign, _unset) ? base.textAlign : _textAlign as TextAlign?,
      textBaseline: identical(_textBaseline, _unset) ? base.textBaseline : _textBaseline as TextBaseline?,
      leadingDistribution: identical(_leadingDistribution, _unset)
          ? base.leadingDistribution
          : _leadingDistribution as TextLeadingDistribution?,
      textShadow: identical(_textShadow, _unset) ? base.textShadow : _textShadow as List<Shadow>?,
      textGradient: identical(_textGradient, _unset) ? base.textGradient : _textGradient as Gradient?,
      textDecorationLine: identical(_textDecorationLine, _unset)
          ? base.textDecorationLine
          : _textDecorationLine as TextDecoration?,
      textDecorationColor: identical(_textDecorationColor, _unset)
          ? base.textDecorationColor
          : _textDecorationColor as Color?,
      textDecorationStyle: identical(_textDecorationStyle, _unset)
          ? base.textDecorationStyle
          : _textDecorationStyle as TextDecorationStyle?,
      textDecorationThickness: identical(_textDecorationThickness, _unset)
          ? base.textDecorationThickness
          : _textDecorationThickness as double?,
      textBackgroundColor: identical(_textBackgroundColor, _unset)
          ? base.textBackgroundColor
          : _textBackgroundColor as Color?,
      softWrap: identical(_softWrap, _unset) ? base.softWrap : _softWrap as bool?,
      textOverflow: identical(_textOverflow, _unset) ? base.textOverflow : _textOverflow as TextOverflow?,
      maxLines: identical(_maxLines, _unset) ? base.maxLines : _maxLines as int?,
    );
  }
}

/// InheritedBox 的延迟写缓冲，一次构建合并本轮全部覆盖。
class InheritedBoxStyleBuffer {
  static const Object _unset = Object();

  Object? _direction = _unset;
  Object? _cursor = _unset;
  Object? _pointerEvents = _unset;
  Object? _iconSize = _unset;
  Object? _iconColor = _unset;

  /// 是否接收过字段写入。
  bool isDirty = false;

  /// 暂存 direction 的覆盖值。
  void writeDirection(Object? v) {
    _direction = v as TextDirection?;
    isDirty = true;
  }

  /// 暂存 cursor 的覆盖值。
  void writeCursor(Object? v) {
    _cursor = v as MouseCursor?;
    isDirty = true;
  }

  /// 暂存 pointerEvents 的覆盖值。
  void writePointerEvents(Object? v) {
    _pointerEvents = v as ElPointerEvents?;
    isDirty = true;
  }

  /// 暂存 iconSize 的覆盖值。
  void writeIconSize(Object? v) {
    _iconSize = v as double?;
    isDirty = true;
  }

  /// 暂存 iconColor 的覆盖值。
  void writeIconColor(Object? v) {
    _iconColor = v as Color?;
    isDirty = true;
  }

  /// 字段实际改变时才构建快照，等值时共享原引用。
  InheritedBox flush(InheritedBox base) {
    if (!isDirty) return base;
    // 保留等值引用共享，避免无效的级联和继承传播。
    if ((identical(_direction, _unset) || _direction == base.direction) &&
        (identical(_cursor, _unset) || _cursor == base.cursor) &&
        (identical(_pointerEvents, _unset) || _pointerEvents == base.pointerEvents) &&
        (identical(_iconSize, _unset) || _iconSize == base.iconSize) &&
        (identical(_iconColor, _unset) || _iconColor == base.iconColor)) {
      return base;
    }
    return InheritedBox(
      direction: identical(_direction, _unset) ? base.direction : _direction as TextDirection?,
      cursor: identical(_cursor, _unset) ? base.cursor : _cursor as MouseCursor?,
      pointerEvents: identical(_pointerEvents, _unset) ? base.pointerEvents : _pointerEvents as ElPointerEvents?,
      iconSize: identical(_iconSize, _unset) ? base.iconSize : _iconSize as double?,
      iconColor: identical(_iconColor, _unset) ? base.iconColor : _iconColor as Color?,
    );
  }
}

/// Box 的延迟写缓冲，一次构建合并本轮全部覆盖。
class BoxStyleBuffer {
  static const Object _unset = Object();

  Object? _width = _unset;
  Object? _height = _unset;
  Object? _widthFactor = _unset;
  Object? _heightFactor = _unset;
  Object? _backgroundColor = _unset;
  Object? _padding = _unset;
  Object? _margin = _unset;
  Object? _alignment = _unset;
  Object? _border = _unset;
  Object? _borderRadius = _unset;
  Object? _clipPath = _unset;
  Object? _boxShadow = _unset;
  Object? _minWidth = _unset;
  Object? _maxWidth = _unset;
  Object? _minHeight = _unset;
  Object? _maxHeight = _unset;
  Object? _opacity = _unset;
  Object? _transform = _unset;
  Object? _transformOrigin = _unset;
  Object? _clipBehavior = _unset;
  Object? _gradient = _unset;
  Object? _backgroundImage = _unset;
  Object? _outline = _unset;
  Object? _aspectRatio = _unset;
  Object? _filter = _unset;
  Object? _backdropFilter = _unset;

  /// 是否接收过字段写入。
  bool isDirty = false;

  /// 暂存 width 的覆盖值。
  void writeWidth(Object? v) {
    _width = v as ElDimension?;
    isDirty = true;
  }

  /// 暂存 height 的覆盖值。
  void writeHeight(Object? v) {
    _height = v as ElDimension?;
    isDirty = true;
  }

  /// 暂存 widthFactor 的覆盖值。
  void writeWidthFactor(Object? v) {
    _widthFactor = v as double?;
    isDirty = true;
  }

  /// 暂存 heightFactor 的覆盖值。
  void writeHeightFactor(Object? v) {
    _heightFactor = v as double?;
    isDirty = true;
  }

  /// 暂存 backgroundColor 的覆盖值。
  void writeBackgroundColor(Object? v) {
    _backgroundColor = v as Color?;
    isDirty = true;
  }

  /// 暂存 padding 的覆盖值。
  void writePadding(Object? v) {
    _padding = v as EdgeInsetsGeometry?;
    isDirty = true;
  }

  /// 暂存 margin 的覆盖值。
  void writeMargin(Object? v) {
    _margin = v as EdgeInsetsGeometry?;
    isDirty = true;
  }

  /// 暂存 alignment 的覆盖值。
  void writeAlignment(Object? v) {
    _alignment = v as AlignmentGeometry?;
    isDirty = true;
  }

  /// 暂存 border 的覆盖值。
  void writeBorder(Object? v) {
    _border = v as ElBorder?;
    isDirty = true;
  }

  /// 暂存 borderRadius 的覆盖值。
  void writeBorderRadius(Object? v) {
    _borderRadius = v as BorderRadiusGeometry?;
    isDirty = true;
  }

  /// 暂存 clipPath 的覆盖值。
  void writeClipPath(Object? v) {
    _clipPath = v as CustomClipper<Path>?;
    isDirty = true;
  }

  /// 暂存 boxShadow 的覆盖值。
  void writeBoxShadow(Object? v) {
    _boxShadow = v as List<BoxShadow>?;
    isDirty = true;
  }

  /// 暂存 minWidth 的覆盖值。
  void writeMinWidth(Object? v) {
    _minWidth = v as ElDimension?;
    isDirty = true;
  }

  /// 暂存 maxWidth 的覆盖值。
  void writeMaxWidth(Object? v) {
    _maxWidth = v as ElDimension?;
    isDirty = true;
  }

  /// 暂存 minHeight 的覆盖值。
  void writeMinHeight(Object? v) {
    _minHeight = v as ElDimension?;
    isDirty = true;
  }

  /// 暂存 maxHeight 的覆盖值。
  void writeMaxHeight(Object? v) {
    _maxHeight = v as ElDimension?;
    isDirty = true;
  }

  /// 暂存 opacity 的覆盖值。
  void writeOpacity(Object? v) {
    _opacity = v as double?;
    isDirty = true;
  }

  /// 暂存 transform 的覆盖值。
  void writeTransform(Object? v) {
    _transform = v as ElTransform?;
    isDirty = true;
  }

  /// 暂存 transformOrigin 的覆盖值。
  void writeTransformOrigin(Object? v) {
    _transformOrigin = v as AlignmentGeometry?;
    isDirty = true;
  }

  /// 暂存 clipBehavior 的覆盖值。
  void writeClipBehavior(Object? v) {
    _clipBehavior = v as Clip?;
    isDirty = true;
  }

  /// 暂存 gradient 的覆盖值。
  void writeGradient(Object? v) {
    _gradient = v as Gradient?;
    isDirty = true;
  }

  /// 暂存 backgroundImage 的覆盖值。
  void writeBackgroundImage(Object? v) {
    _backgroundImage = v as DecorationImage?;
    isDirty = true;
  }

  /// 暂存 outline 的覆盖值。
  void writeOutline(Object? v) {
    _outline = v as ElOutline?;
    isDirty = true;
  }

  /// 暂存 aspectRatio 的覆盖值。
  void writeAspectRatio(Object? v) {
    _aspectRatio = v as double?;
    isDirty = true;
  }

  /// 暂存 filter 的覆盖值。
  void writeFilter(Object? v) {
    _filter = v as ElFilter?;
    isDirty = true;
  }

  /// 暂存 backdropFilter 的覆盖值。
  void writeBackdropFilter(Object? v) {
    _backdropFilter = v as ElFilter?;
    isDirty = true;
  }

  /// 字段实际改变时才构建快照，等值时共享原引用。
  Box flush(Box base) {
    if (!isDirty) return base;
    // 保留等值引用共享，避免无效的级联和继承传播。
    if ((identical(_width, _unset) || _width == base.width) &&
        (identical(_height, _unset) || _height == base.height) &&
        (identical(_widthFactor, _unset) || _widthFactor == base.widthFactor) &&
        (identical(_heightFactor, _unset) || _heightFactor == base.heightFactor) &&
        (identical(_backgroundColor, _unset) || _backgroundColor == base.backgroundColor) &&
        (identical(_padding, _unset) || _padding == base.padding) &&
        (identical(_margin, _unset) || _margin == base.margin) &&
        (identical(_alignment, _unset) || _alignment == base.alignment) &&
        (identical(_border, _unset) || _border == base.border) &&
        (identical(_borderRadius, _unset) || _borderRadius == base.borderRadius) &&
        (identical(_clipPath, _unset) || _clipPath == base.clipPath) &&
        (identical(_boxShadow, _unset) || _boxShadow == base.boxShadow) &&
        (identical(_minWidth, _unset) || _minWidth == base.minWidth) &&
        (identical(_maxWidth, _unset) || _maxWidth == base.maxWidth) &&
        (identical(_minHeight, _unset) || _minHeight == base.minHeight) &&
        (identical(_maxHeight, _unset) || _maxHeight == base.maxHeight) &&
        (identical(_opacity, _unset) || _opacity == base.opacity) &&
        (identical(_transform, _unset) || _transform == base.transform) &&
        (identical(_transformOrigin, _unset) || _transformOrigin == base.transformOrigin) &&
        (identical(_clipBehavior, _unset) || _clipBehavior == base.clipBehavior) &&
        (identical(_gradient, _unset) || _gradient == base.gradient) &&
        (identical(_backgroundImage, _unset) || _backgroundImage == base.backgroundImage) &&
        (identical(_outline, _unset) || _outline == base.outline) &&
        (identical(_aspectRatio, _unset) || _aspectRatio == base.aspectRatio) &&
        (identical(_filter, _unset) || _filter == base.filter) &&
        (identical(_backdropFilter, _unset) || _backdropFilter == base.backdropFilter)) {
      return base;
    }
    return Box(
      width: identical(_width, _unset) ? base.width : _width as ElDimension?,
      height: identical(_height, _unset) ? base.height : _height as ElDimension?,
      widthFactor: identical(_widthFactor, _unset) ? base.widthFactor : _widthFactor as double?,
      heightFactor: identical(_heightFactor, _unset) ? base.heightFactor : _heightFactor as double?,
      backgroundColor: identical(_backgroundColor, _unset) ? base.backgroundColor : _backgroundColor as Color?,
      padding: identical(_padding, _unset) ? base.padding : _padding as EdgeInsetsGeometry?,
      margin: identical(_margin, _unset) ? base.margin : _margin as EdgeInsetsGeometry?,
      alignment: identical(_alignment, _unset) ? base.alignment : _alignment as AlignmentGeometry?,
      border: identical(_border, _unset) ? base.border : _border as ElBorder?,
      borderRadius: identical(_borderRadius, _unset) ? base.borderRadius : _borderRadius as BorderRadiusGeometry?,
      clipPath: identical(_clipPath, _unset) ? base.clipPath : _clipPath as CustomClipper<Path>?,
      boxShadow: identical(_boxShadow, _unset) ? base.boxShadow : _boxShadow as List<BoxShadow>?,
      minWidth: identical(_minWidth, _unset) ? base.minWidth : _minWidth as ElDimension?,
      maxWidth: identical(_maxWidth, _unset) ? base.maxWidth : _maxWidth as ElDimension?,
      minHeight: identical(_minHeight, _unset) ? base.minHeight : _minHeight as ElDimension?,
      maxHeight: identical(_maxHeight, _unset) ? base.maxHeight : _maxHeight as ElDimension?,
      opacity: identical(_opacity, _unset) ? base.opacity : _opacity as double?,
      transform: identical(_transform, _unset) ? base.transform : _transform as ElTransform?,
      transformOrigin: identical(_transformOrigin, _unset)
          ? base.transformOrigin
          : _transformOrigin as AlignmentGeometry?,
      clipBehavior: identical(_clipBehavior, _unset) ? base.clipBehavior : _clipBehavior as Clip?,
      gradient: identical(_gradient, _unset) ? base.gradient : _gradient as Gradient?,
      backgroundImage: identical(_backgroundImage, _unset)
          ? base.backgroundImage
          : _backgroundImage as DecorationImage?,
      outline: identical(_outline, _unset) ? base.outline : _outline as ElOutline?,
      aspectRatio: identical(_aspectRatio, _unset) ? base.aspectRatio : _aspectRatio as double?,
      filter: identical(_filter, _unset) ? base.filter : _filter as ElFilter?,
      backdropFilter: identical(_backdropFilter, _unset) ? base.backdropFilter : _backdropFilter as ElFilter?,
    );
  }
}
