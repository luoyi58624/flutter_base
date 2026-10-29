import 'package:flutter/painting.dart';
import 'package:characters/characters.dart';

/// 让文本中的 `\t` 按 [tabSize] 列 tab stop 排版，同时保持每个 tab 仍只占一个
/// UTF-16 offset。
///
/// 实现只给 tab 自身追加字距，不替换或扩写正文，因此 caret、选区、IME 与装饰
/// 坐标无需建立第二套映射。列宽以各 tab 生效样式下的空格 advance 为单位；
/// 网格原点是 TextPainter 的 offset-0 caret；带 letterSpacing 时该点可能不等于
/// 段落盒 left，所有 tab 与编辑器 caret 因而仍处于同一坐标系。
/// [initialAdvance] 让超长行片段延续逻辑行 offset-0 的同一 tab 网格。
InlineSpan applyEditableTabStops(
  InlineSpan span, {
  required int tabSize,
  required TextDirection textDirection,
  required TextScaler textScaler,
  double initialAdvance = 0.0,
}) {
  assert(tabSize > 0);
  assert(initialAdvance.isFinite && initialAdvance >= 0.0);
  if (!span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false).contains('\t')) return span;
  final builder = _TabStopSpanBuilder(
    tabSize: tabSize,
    textDirection: textDirection,
    textScaler: textScaler,
    initialAdvance: initialAdvance,
  );
  return builder.build(span);
}

final class _TabStopSpanBuilder {
  _TabStopSpanBuilder({
    required this.tabSize,
    required this.textDirection,
    required this.textScaler,
    required double initialAdvance,
  }) : _committedAdvance = initialAdvance;

  final int tabSize;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Map<TextStyle?, double> _spaceAdvances = <TextStyle?, double>{};
  final List<InlineSpan> _output = <InlineSpan>[];
  final List<InlineSpan> _segmentParts = <InlineSpan>[];
  final Map<
    ({TextStyle? style, Locale? locale, String? lookahead, TextStyle? lookaheadStyle, Locale? lookaheadLocale}),
    double
  >
  _emptySegmentTabSpacings = {};
  int _segmentLength = 0;
  double _committedAdvance;
  _PendingTab? _pendingTab;

  InlineSpan build(InlineSpan span) {
    _add(span, inheritedStyle: null);
    _resolvePendingTab();
    return TextSpan(children: List<InlineSpan>.unmodifiable(_output));
  }

  void _add(InlineSpan span, {required TextStyle? inheritedStyle}) {
    if (span is! TextSpan) {
      _resolvePendingTab();
      _output.add(span);
      return;
    }
    final effectiveStyle = inheritedStyle == null ? span.style : inheritedStyle.merge(span.style);
    final text = span.text;
    var semanticsIdentifier = span.semanticsIdentifier;
    final suppressTextSemantics = span.semanticsLabel != null;
    if (suppressTextSemantics || ((text == null || text.isEmpty) && semanticsIdentifier != null)) {
      _output.add(
        TextSpan(
          text: '',
          style: effectiveStyle,
          semanticsLabel: span.semanticsLabel,
          semanticsIdentifier: semanticsIdentifier,
          locale: span.locale,
          spellOut: span.spellOut,
        ),
      );
      semanticsIdentifier = null;
    }
    if (text != null && text.isNotEmpty) {
      _addText(
        text,
        owner: span,
        effectiveStyle: effectiveStyle,
        suppressTextSemantics: suppressTextSemantics,
        semanticsIdentifier: semanticsIdentifier,
      );
    }
    final children = span.children;
    if (children == null) return;
    for (final child in children) {
      _add(child, inheritedStyle: effectiveStyle);
    }
  }

  void _addText(
    String text, {
    required TextSpan owner,
    required TextStyle? effectiveStyle,
    required bool suppressTextSemantics,
    required String? semanticsIdentifier,
  }) {
    var segmentStart = 0;
    var pendingIdentifier = semanticsIdentifier;
    for (var index = 0; index < text.length; index++) {
      if (text.codeUnitAt(index) != 0x09) continue;
      if (index > segmentStart) {
        final segment = text.substring(segmentStart, index);
        _appendNormalTextPart(
          segment,
          owner: owner,
          style: effectiveStyle,
          semanticsLabel: suppressTextSemantics ? '' : null,
          semanticsIdentifier: pendingIdentifier,
        );
        pendingIdentifier = null;
      }
      _resolvePendingTab(lookahead: '\t', lookaheadStyle: effectiveStyle, lookaheadLocale: owner.locale);
      final currentAdvance = _committedAdvance + _measureSegmentAdvance();
      final stopExtent = _spaceAdvance(effectiveStyle) * tabSize;
      final targetAdvance = stopExtent <= 0.0
          ? currentAdvance + _measureAdvance('\t', effectiveStyle)
          : ((currentAdvance + stopExtent * 1e-6) / stopExtent).floor() * stopExtent + stopExtent;
      final outputIndex = _output.length;
      _appendTextPart(
        '\t',
        owner: owner,
        style: effectiveStyle,
        semanticsLabel: suppressTextSemantics ? '' : null,
        semanticsIdentifier: pendingIdentifier,
        trackForTabStops: false,
      );
      _pendingTab = _PendingTab(
        outputIndex: outputIndex,
        owner: owner,
        style: effectiveStyle,
        semanticsLabel: suppressTextSemantics ? '' : null,
        semanticsIdentifier: pendingIdentifier,
        targetAdvance: targetAdvance,
        emptySegment: _segmentLength == 0,
      );
      pendingIdentifier = null;
      segmentStart = index + 1;
    }
    if (segmentStart < text.length) {
      final tail = text.substring(segmentStart);
      _appendNormalTextPart(
        tail,
        owner: owner,
        style: effectiveStyle,
        semanticsLabel: suppressTextSemantics ? '' : null,
        semanticsIdentifier: pendingIdentifier,
      );
    }
  }

  void _appendTextPart(
    String text, {
    required TextSpan owner,
    required TextStyle? style,
    required String? semanticsLabel,
    required String? semanticsIdentifier,
    bool trackForTabStops = true,
  }) {
    _output.add(
      _textPart(
        text,
        owner: owner,
        style: style,
        semanticsLabel: semanticsLabel,
        semanticsIdentifier: semanticsIdentifier,
      ),
    );
    if (trackForTabStops) {
      _segmentParts.add(TextSpan(text: text, style: style, locale: owner.locale));
      _segmentLength += text.length;
    }
  }

  void _appendNormalTextPart(
    String text, {
    required TextSpan owner,
    required TextStyle? style,
    required String? semanticsLabel,
    required String? semanticsIdentifier,
  }) {
    _resolvePendingTab(lookahead: text.characters.first, lookaheadStyle: style, lookaheadLocale: owner.locale);
    _appendTextPart(
      text,
      owner: owner,
      style: style,
      semanticsLabel: semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
    );
  }

  TextSpan _textPart(
    String text, {
    required TextSpan owner,
    required TextStyle? style,
    required String? semanticsLabel,
    required String? semanticsIdentifier,
  }) {
    return TextSpan(
      text: text,
      style: style,
      recognizer: owner.recognizer,
      mouseCursor: owner.mouseCursor,
      onEnter: owner.onEnter,
      onExit: owner.onExit,
      semanticsLabel: semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
      locale: owner.locale,
      spellOut: owner.spellOut,
    );
  }

  double _spaceAdvance(TextStyle? style) {
    return _spaceAdvances.putIfAbsent(style, () => _measureAdvance(' ', style));
  }

  void _resolvePendingTab({String? lookahead, TextStyle? lookaheadStyle, Locale? lookaheadLocale}) {
    final pending = _pendingTab;
    if (pending == null) return;
    final cacheKey = (
      style: pending.style,
      locale: pending.owner.locale,
      lookahead: lookahead,
      lookaheadStyle: lookaheadStyle,
      lookaheadLocale: lookaheadLocale,
    );
    var resolvedLetterSpacing = pending.emptySegment ? _emptySegmentTabSpacings[cacheKey] : null;
    if (resolvedLetterSpacing == null) {
      final desiredSegmentAdvance = pending.targetAdvance - _committedAdvance;
      var candidateLetterSpacing = pending.style?.letterSpacing ?? 0.0;
      for (var iteration = 0; iteration < 6; iteration++) {
        final actual = _measureCandidateTab(
          pending.style,
          pending.owner.locale,
          candidateLetterSpacing,
          lookahead: lookahead,
          lookaheadStyle: lookaheadStyle,
          lookaheadLocale: lookaheadLocale,
        );
        final error = desiredSegmentAdvance - actual;
        if (error.abs() <= 0.001) break;
        final unit = _measureCandidateTab(
          pending.style,
          pending.owner.locale,
          candidateLetterSpacing + 1.0,
          lookahead: lookahead,
          lookaheadStyle: lookaheadStyle,
          lookaheadLocale: lookaheadLocale,
        );
        final slope = unit - actual;
        if (slope.abs() < 1e-6) break;
        candidateLetterSpacing += error / slope;
      }
      resolvedLetterSpacing = candidateLetterSpacing;
      if (pending.emptySegment) _emptySegmentTabSpacings[cacheKey] = candidateLetterSpacing;
    }
    final tabStyle = (pending.style ?? const TextStyle()).copyWith(letterSpacing: resolvedLetterSpacing);
    _output[pending.outputIndex] = _textPart(
      '\t',
      owner: pending.owner,
      style: tabStyle,
      semanticsLabel: pending.semanticsLabel,
      semanticsIdentifier: pending.semanticsIdentifier,
    );
    _committedAdvance = pending.targetAdvance;
    _segmentParts.clear();
    _segmentLength = 0;
    _pendingTab = null;
  }

  double _measureCandidateTab(
    TextStyle? style,
    Locale? locale,
    double letterSpacing, {
    required String? lookahead,
    required TextStyle? lookaheadStyle,
    required Locale? lookaheadLocale,
  }) {
    final effective = (style ?? const TextStyle()).copyWith(letterSpacing: letterSpacing);
    final tabEnd = _segmentLength + 1;
    _segmentParts.add(TextSpan(text: '\t', style: effective, locale: locale));
    _segmentLength++;
    if (lookahead != null) {
      _segmentParts.add(TextSpan(text: lookahead, style: lookaheadStyle, locale: lookaheadLocale));
      _segmentLength += lookahead.length;
    }
    final painter = TextPainter(
      text: TextSpan(children: _segmentParts),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final start = painter.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dx;
    final end = painter.getOffsetForCaret(TextPosition(offset: tabEnd), Rect.zero).dx;
    final advance = (end - start).abs();
    painter.dispose();
    if (lookahead != null) {
      _segmentLength -= lookahead.length;
      _segmentParts.removeLast();
    }
    _segmentLength--;
    _segmentParts.removeLast();
    return advance;
  }

  double _measureSegmentAdvance() {
    if (_segmentLength == 0) return 0.0;
    final painter = TextPainter(
      text: TextSpan(children: _segmentParts),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final start = painter.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dx;
    final end = painter.getOffsetForCaret(TextPosition(offset: _segmentLength), Rect.zero).dx;
    final width = (end - start).abs();
    painter.dispose();
    return width;
  }

  double _measureAdvance(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final start = painter.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dx;
    final end = painter.getOffsetForCaret(TextPosition(offset: text.length), Rect.zero).dx;
    final width = (end - start).abs();
    painter.dispose();
    return width;
  }
}

final class _PendingTab {
  const _PendingTab({
    required this.outputIndex,
    required this.owner,
    required this.style,
    required this.semanticsLabel,
    required this.semanticsIdentifier,
    required this.targetAdvance,
    required this.emptySegment,
  });

  final int outputIndex;
  final TextSpan owner;
  final TextStyle? style;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final double targetAdvance;
  final bool emptySegment;
}
