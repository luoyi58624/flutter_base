import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerCancelEvent, PointerDownEvent, PointerMoveEvent, PointerUpEvent, kPrimaryButton;
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        TextInputFormatter,
        TextInputConfiguration,
        TextInputAction,
        TextInputType,
        AutofillConfiguration;
import 'package:flutter/widgets.dart';

import '../../internal.dart';

String _normalizeOtpText(String text) => text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\n', '');

String _truncateOtpText(String text, int limit) => _normalizeOtpText(text).characters.take(limit).join();

int _otpOffsetAtGraphemeIndex(String text, int index) {
  var offset = 0;
  var current = 0;
  for (final grapheme in text.characters) {
    if (current >= index) break;
    offset += grapheme.length;
    current++;
  }
  return offset;
}

TextSelection _clampOtpSelection(TextSelection selection, int length) => selection.copyWith(
  baseOffset: selection.baseOffset.clamp(0, length),
  extentOffset: selection.extentOffset.clamp(0, length),
);

/// 格子数按 Unicode 字素计算，组合输入结束后才执行截断。
final class _OtpGraphemeLimitPolicy extends TextInputFormatter {
  _OtpGraphemeLimitPolicy(this.limit);
  int limit;
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final limited = _truncateOtpText(newValue.text, limit);
    if (limited == newValue.text) return newValue;
    return newValue.copyWith(
      text: limited,
      selection: _clampOtpSelection(newValue.selection, limited.length),
      composing: TextRange.empty,
    );
  }
}

int _graphemeIndexAtOffset(String text, int offset) {
  var codeUnits = 0;
  var index = 0;
  for (final grapheme in text.characters) {
    if (offset <= codeUnits) return index;
    codeUnits += grapheme.length;
    index++;
    if (offset < codeUnits) return index;
  }
  return index;
}

/// 把透明 editable 的真实 Paragraph 排成 OTP 固定格距，所有业务仍留在上层。
final class _OtpGeometryComposer {
  _OtpGeometryComposer({
    required this.controller,
    required this.capacity,
    required this.pitch,
    required this.lineHeight,
    required this.textScaler,
  });

  final ElEditableController controller;
  final int capacity;
  final double pitch;
  final double lineHeight;
  final TextScaler textScaler;

  InlineSpan compose({
    required int line,
    required String text,
    required TextStyle style,
    required int start,
    required int lineLength,
  }) {
    if (text.isEmpty) return TextSpan(text: text, style: style);
    final sourceGraphemes = controller.text.characters.toList(growable: false);
    if (sourceGraphemes.isEmpty || sourceGraphemes.fold<int>(0, (sum, value) => sum + value.length) != text.length) {
      return TextSpan(text: text, style: style);
    }
    final full = sourceGraphemes.length >= capacity;
    final children = <InlineSpan>[];
    var offset = 0;
    for (var index = 0; index < sourceGraphemes.length; index++) {
      final end = offset + sourceGraphemes[index].length;
      final segment = text.substring(offset, end);
      final targetAdvance = full && index == capacity - 1 ? 0.0 : pitch;
      children.add(TextSpan(text: segment, style: _styleForAdvance(style, targetAdvance)));
      offset = end;
    }
    return TextSpan(style: style, children: children);
  }

  TextStyle _styleForAdvance(TextStyle base, double targetAdvance) {
    const fontSize = 0.001;
    return base.copyWith(
      fontSize: fontSize,
      height: lineHeight / textScaler.scale(fontSize),
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: targetAdvance,
    );
  }
}

/// Element Plus 验证码输入框。
///
/// 值是已输入的字符串（长度 ≤ [length]）：`value` 自持 / `modelValue` 双向 /
/// `prop` + 祖先 ElForm 表单直连。
///
/// 只有一个真实焦点：整个组件是一个隐形的单行编辑区，分格只是把这串字符
/// 逐个画出来——这样退格、粘贴、输入法都不用逐格转发。
///
/// 桌面预设使用的 Element 一次性验证码输入框实现。
class InputOtp extends ElFormModelValue<String> {
  InputOtp(this.component, {super.key})
    : super(value: component.value, modelValue: component.modelValue, onChanged: component.onChanged);

  final ElInputOtp component;

  int get length => component.length;
  ElInputOtpType get type => component.type;
  bool get mask => component.mask;
  String get maskCharacter => component.maskCharacter;
  bool get disabled => component.disabled;
  bool get autofocus => component.autofocus;
  TextInputType get keyboardType => component.keyboardType;
  Iterable<String>? get autofillHints => component.autofillHints;
  ValueChanged<String>? get onComplete => component.onComplete;
  ElStyle? get style => component.style;
  ElStyle? get cellStyle => component.cellStyle;
  String? get semanticLabel => component.semanticLabel;

  // ---- 组件 token ----

  /// 解析紧凑模式：优先读取当前样式，再查找祖先变量。
  bool _compact(BuildContext context) => context.elComponentCompact(style);

  @override
  Widget obsBuilder(BuildContext context) => _ElInputOtpBody(
    config: this,
    compact: _compact(context),
    value: $obs.value,
    // 输入只改 $obs：基类负责镜像到 modelValue / onChanged / 表单 Map
    onInput: (next) => $obs.value = next,
  );
}

/// 视觉层：一个 editable 实例承接整串输入，分格只负责呈现。
class _ElInputOtpBody extends StatefulWidget {
  const _ElInputOtpBody({required this.config, required this.compact, required this.value, required this.onInput});

  final InputOtp config;

  /// 父级解析后的紧凑模式。
  final bool compact;
  final String value;
  final ValueChanged<String> onInput;

  @override
  State<_ElInputOtpBody> createState() => _ElInputOtpBodyState();
}

class _ElInputOtpBodyState extends State<_ElInputOtpBody> {
  late ElEditableController _controller;
  late final _OtpGraphemeLimitPolicy _lengthPolicy;
  late final _focusNode = FocusNode(debugLabel: 'ElInputOtp');
  bool _focused = false;
  bool _syncingIn = false;
  bool _pendingFlush = false;
  bool _normalizationScheduled = false;
  bool _settlementScheduled = false;
  bool _convergingLength = false;
  bool _lengthConvergencePending = false;
  String? _pendingExternalValue;
  int? _selectionPointer;
  int? _selectionAnchor;
  Offset _geometryCorrection = Offset.zero;
  late String _lastOutput;

  @override
  void initState() {
    super.initState();
    _lengthPolicy = _OtpGraphemeLimitPolicy(widget.config.length);
    _controller = _createController(widget.value);
    _lastOutput = _controller.text;
    _attachController();
    _focusNode.addListener(_onFocusChanged);
    if (_controller.text != widget.value) _scheduleNormalization();
  }

  @override
  void didUpdateWidget(_ElInputOtpBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lengthChanged = oldWidget.config.length != widget.config.length;
    if (!oldWidget.config.disabled && widget.config.disabled) {
      _focusNode.unfocus();
    }
    if (_isComposing) {
      // 组合中的 widget.value 仍可能是上一笔已提交值；只有真正的外部变更才排队。
      if (oldWidget.value != widget.value) _pendingExternalValue = widget.value;
      if (lengthChanged) _lengthConvergencePending = true;
      return;
    }
    if (lengthChanged) _controller.closeHistoryRun();
    _lengthPolicy.limit = widget.config.length;
    _syncFromWidget(widget.value);
    if (lengthChanged && _exceedsConfiguredLength) {
      _lengthConvergencePending = true;
      _pendingFlush = true;
      _scheduleSettlement();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _detachController();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focused == _focusNode.hasFocus) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  ElEditableController _createController(String text) {
    final controller = ElEditableController(
      text: _truncateOtpText(text, _lengthPolicy.limit),
      singleLine: true,
      inputFormatters: [_lengthPolicy],
    );
    controller.collapseTo(controller.text.length);
    return controller;
  }

  void _attachController() {
    _controller.textChanges.addListener(_onDocumentChanged);
    _controller.addListener(_onVisualChanged);
  }

  void _detachController() {
    _controller.textChanges.removeListener(_onDocumentChanged);
    _controller.removeListener(_onVisualChanged);
  }

  bool get _isComposing {
    final composing = _controller.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  void _onDocumentChanged() {
    if (_syncingIn) return;
    if (_isComposing) {
      _pendingFlush = true;
      return;
    }
    if (_convergingLength) {
      _pendingFlush = true;
      return;
    }
    if (_needsSettlement) {
      _pendingFlush = true;
      _scheduleSettlement();
      return;
    }
    _pendingFlush = false;
    _flushUserEdit();
  }

  void _onVisualChanged() {
    if (_syncingIn) return;
    if (mounted) setState(() {});
    if (_isComposing) return;
    if (_convergingLength) return;
    if (_needsSettlement) {
      _scheduleSettlement();
      return;
    }
    if (!_pendingFlush) return;
    _pendingFlush = false;
    _flushUserEdit();
  }

  bool get _exceedsConfiguredLength => _controller.text.characters.length > widget.config.length;

  bool get _needsSettlement =>
      _pendingExternalValue != null || _lengthPolicy.limit != widget.config.length || _lengthConvergencePending;

  /// 组合结束后先切换新上限，再把配置收敛压成一笔独立、可撤销的后缀删除。
  void _scheduleSettlement() {
    if (_settlementScheduled || _isComposing) return;
    _settlementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settlementScheduled = false;
      if (!mounted || _isComposing) return;
      if (_lengthConvergencePending) _controller.closeHistoryRun();
      _lengthPolicy.limit = widget.config.length;
      final external = _pendingExternalValue;
      _pendingExternalValue = null;
      if (external != null) _syncFromWidget(external);
      if (_lengthConvergencePending && _exceedsConfiguredLength) {
        _convergeConfiguredLength();
      }
      _lengthConvergencePending = false;
      if (_pendingFlush) {
        _pendingFlush = false;
        _flushUserEdit();
      }
    });
  }

  void _convergeConfiguredLength() {
    final end = _controller.text.length;
    final start = _otpOffsetAtGraphemeIndex(_controller.text, widget.config.length);
    if (start >= end) return;
    final selection = _clampOtpSelection(_controller.selection, start);
    _convergingLength = true;
    try {
      _controller.replaceRange(start, end, '', selection: selection);
    } finally {
      _convergingLength = false;
    }
  }

  void _flushUserEdit() {
    final text = _controller.text;
    if (text == _lastOutput) return;
    final onComplete = text.characters.length == widget.config.length ? widget.config.onComplete : null;
    _lastOutput = text;
    widget.onInput(text);
    onComplete?.call(text);
  }

  /// 外部值用公共前后缀差量回灌，选区两端分别映射，避免每次都跳到末尾。
  void _syncFromWidget(String next) {
    if (next == _controller.text) {
      _lastOutput = next;
      return;
    }
    _syncingIn = true;
    try {
      _minimalReplace(_controller, next);
      _pendingFlush = false;
    } finally {
      _syncingIn = false;
    }
    _lastOutput = _controller.text;
    if (_controller.text != next) _scheduleNormalization();
  }

  /// 外部超长值按 Unicode 字素上限收敛后只回写一次。
  void _scheduleNormalization() {
    if (_normalizationScheduled) return;
    _normalizationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _normalizationScheduled = false;
      if (!mounted || widget.value == _controller.text) return;
      _lastOutput = _controller.text;
      widget.onInput(_controller.text);
    });
  }

  static void _minimalReplace(ElEditableController controller, String next) {
    final prev = controller.text;
    var start = 0;
    final minLength = math.min(prev.length, next.length);
    while (start < minLength && prev.codeUnitAt(start) == next.codeUnitAt(start)) {
      start++;
    }
    var endPrev = prev.length;
    var endNext = next.length;
    while (endPrev > start && endNext > start && prev.codeUnitAt(endPrev - 1) == next.codeUnitAt(endNext - 1)) {
      endPrev--;
      endNext--;
    }
    final selection = controller.selection;
    controller.replaceRange(
      start,
      endPrev,
      next.substring(start, endNext),
      selection: TextSelection(
        baseOffset: _mapOffset(selection.baseOffset, start, endPrev, endNext).clamp(0, next.length),
        extentOffset: _mapOffset(selection.extentOffset, start, endPrev, endNext).clamp(0, next.length),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
    );
  }

  static int _mapOffset(int offset, int start, int endPrev, int endNext) {
    if (offset <= start) return offset;
    if (offset >= endPrev) return offset + (endNext - endPrev);
    return endNext;
  }

  int _offsetAtCellX(double x) {
    final side = _ElInputOtpCell._side(widget.compact);
    final pitch = side + _gap(widget.compact);
    final index = ((x - side / 2) / pitch).round().clamp(0, widget.config.length - 1);
    return _otpOffsetAtGraphemeIndex(_controller.text, index);
  }

  void _handleSelectionPointerDown(ElEventDetails event) {
    final original = event.originalEvent;
    if (original is! PointerDownEvent || (original.buttons & kPrimaryButton) == 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    final offset = _offsetAtCellX(event.localX);
    final anchor = HardwareKeyboard.instance.isShiftPressed ? _controller.selection.baseOffset : offset;
    _selectionPointer = original.pointer;
    _selectionAnchor = anchor;
    _controller.setSelection(TextSelection(baseOffset: anchor, extentOffset: offset));
  }

  void _handleSelectionPointerMove(ElEventDetails event) {
    final original = event.originalEvent;
    if (original is! PointerMoveEvent ||
        original.pointer != _selectionPointer ||
        (original.buttons & kPrimaryButton) == 0) {
      return;
    }
    final anchor = _selectionAnchor;
    if (anchor == null) return;
    _controller.setSelection(TextSelection(baseOffset: anchor, extentOffset: _offsetAtCellX(event.localX)));
  }

  void _handleSelectionPointerTerminal(ElEventDetails event) {
    final original = event.originalEvent;
    final pointer = switch (original) {
      PointerUpEvent(:final pointer) => pointer,
      PointerCancelEvent(:final pointer) => pointer,
      _ => null,
    };
    if (pointer == null || pointer != _selectionPointer) return;
    _selectionPointer = null;
    _selectionAnchor = null;
  }

  /// 光标所在格：未满时可落到下一待输入位，满了钳在末格。
  int get _activeIndex =>
      _graphemeIndexAtOffset(_controller.text, _controller.selection.extentOffset).clamp(0, widget.config.length - 1);

  void _scheduleGeometryCorrection(double side, double pitch) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rect = _controller.rectAtOffset(_controller.selection.extentOffset);
      if (rect == null) return;
      final target = Offset(side / 2 + _activeIndex * pitch, side / 2);
      final next = target - rect.center;
      if ((next - _geometryCorrection).distance <= 0.001) return;
      setState(() => _geometryCorrection = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final text = _controller.text;
    final graphemes = text.characters.toList(growable: false);
    final side = _ElInputOtpCell._side(widget.compact);
    final pitch = side + _gap(widget.compact);
    const caretWidth = 1.0;
    final textScaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final semanticValue = config.mask ? config.maskCharacter * graphemes.length : text;
    final declaredColor = config.style?.color;
    final hiddenTextColor = (declaredColor is Color ? declaredColor : context.elTheme.textRegular).withValues(alpha: 0);
    const geometryFontSize = 0.001;
    final baseTextStyle = ElStyle(
      fontSize: geometryFontSize,
      lineHeight: side / textScaler.scale(geometryFontSize),
      textOptions: const ElTextOptions(leadingDistribution: .even),
      color: hiddenTextColor,
      iconColor: hiddenTextColor,
    );
    final geometryComposer = _OtpGeometryComposer(
      controller: _controller,
      capacity: config.length,
      pitch: pitch,
      lineHeight: side,
      textScaler: textScaler,
    );
    _scheduleGeometryCorrection(side, pitch);
    return ElView(
      event: config.disabled ? ElEvent(disabled: true) : null,
      // 可编辑态的完整文本框语义由 ElEditableView 独占；再挂外层 value 会让
      // 读屏重复播报，密码态还会把原文从第二个节点泄漏出去。
      semantics: config.disabled
          ? ElSemantics(
              container: true,
              properties: SemanticsProperties(
                textField: true,
                readOnly: true,
                enabled: false,
                obscured: config.mask,
                multiline: false,
                label: config.semanticLabel,
                value: semanticValue,
                maxValueLength: config.length,
                currentValueLength: graphemes.length,
              ),
            )
          : null,
      style: const ElStyle().merge(config.style),
      child: ElStackView(
        children: [
          Row(
            mainAxisSize: .min,
            spacing: _gap(widget.compact),
            children: [
              for (var i = 0; i < config.length; i++)
                _ElInputOtpCell(
                  character: i < graphemes.length ? _display(graphemes[i]) : null,
                  active: _focused && i == _activeIndex,
                  compact: widget.compact,
                  config: config,
                ),
            ],
          ),
          if (!config.disabled)
            // 真正接输入的透明编辑区：铺满整排，分格只是同一文档的视觉投影。
            ElPositioned.fill(
              child: ElView(
                event: ElEvent(
                  onPointerDown: _handleSelectionPointerDown,
                  onPointerMove: _handleSelectionPointerMove,
                  onPointerUp: _handleSelectionPointerTerminal,
                  onPointerCancel: _handleSelectionPointerTerminal,
                ),
                child: ElView(
                  // rectAtOffset 是最终 Paragraph 的权威几何；上层逐帧读取当前
                  // caret 后只平移透明输入层，不复制 OTP 业务进 core。
                  style: ElStyle(transform: ElTransform.translate(_geometryCorrection.dx, _geometryCorrection.dy)),
                  child: ElEditableView(
                    controller: _controller,
                    focusNode: _focusNode,
                    textSpanBuilder: geometryComposer.compose,
                    style: ElEditableStyle(
                      view: baseTextStyle,
                      fixedLineHeight: true,
                      softWrap: false,
                      caretWidth: caretWidth,
                      contentPadding: EdgeInsets.only(left: side / 2 - caretWidth / 2),
                      caretColor: const Color(0x00000000),
                      selectionColor: const Color(0x00000000),
                      selectionTextColor: hiddenTextColor,
                      composingUnderline: false,
                      autofocus: config.autofocus,
                      obscureText: config.mask,
                      obscuringCharacter: config.maskCharacter,
                      semanticLabel: config.semanticLabel,
                      inputConfiguration: TextInputConfiguration(
                        inputType: config.keyboardType,
                        inputAction: TextInputAction.done,
                        autofillConfiguration: config.autofillHints == null
                            ? AutofillConfiguration.disabled
                            : AutofillConfiguration(
                                uniqueIdentifier: _controller.hashCode.toString(),
                                autofillHints: config.autofillHints!.toList(),
                                currentEditingValue: TextEditingValue(
                                  text: _controller.text,
                                  selection: _controller.selection,
                                ),
                                hintText: config.semanticLabel,
                              ),
                      ),
                      enableInteractiveSelection: false,
                      scrollbars: false,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _display(String raw) => widget.config.mask ? widget.config.maskCharacter : raw;

  static double _gap(bool compact) => compact ? 6 : 8;
}

/// 单格：三种外观 + 激活态描主色
class _ElInputOtpCell extends StatelessWidget {
  const _ElInputOtpCell({required this.character, required this.active, required this.compact, required this.config});

  final String? character;
  final bool active;
  final bool compact;
  final InputOtp config;

  @override
  Widget build(BuildContext context) {
    final side = _side(compact);
    return ElView(
      event: config.disabled ? ElEvent(disabled: true) : null,

      // 分格只是同一 editable 文档的视觉投影，不应拆成逐字符读屏节点。
      semantics: ElSemantics(exclude: true),
      style: _cellStyle(context, side).merge(config.cellStyle),
      child: character,
    );
  }

  ElStyle _cellStyle(BuildContext context, double side) {
    final activeColor = context.elTheme.primary;
    final fontSize = config.style?.fontSize ?? _fontSize(compact);
    final textOptions = config.style?.textOptions;
    final textColor = config.style?.color ?? context.elTheme.textRegular;
    final bgColor = context.elTheme.bgColor;
    final borderColor = context.elTheme.borderColor;
    return switch (config.type) {
      ElInputOtpType.outlined => ElStyle(
        width: side,
        height: side,
        alignment: .center,
        fontSize: fontSize,
        textOptions: textOptions,
        color: textColor,
        backgroundColor: bgColor,
        border: ElBorder.all(borderWidth: 1, borderColor: borderColor),
        borderRadius: BorderRadius.circular(context.elTheme.radiusSm),

        onDisabled: ElStyle(
          backgroundColor: context.isDark ? const Color(0xff262727) : const Color(0xfff5f7fa),
          color: context.elTheme.textPlaceholder,
          iconColor: context.elTheme.textPlaceholder,
        ),
        transition: const [ElTransition.all(Duration(milliseconds: 150))],
        iconColor: textColor,
      ).merge((active) ? (ElStyle(border: ElBorder.all(borderWidth: 1, borderColor: activeColor))) : null),
      ElInputOtpType.filled => ElStyle(
        width: side,
        height: side,
        alignment: .center,
        fontSize: fontSize,
        textOptions: textOptions,
        color: textColor,
        // filled 填充底从 $bgColor 派生加深 1 级
        backgroundColor: context.elTheme.bgColor.elLight1(context, reverse: !context.elTheme.bgColor.isDark),
        borderRadius: BorderRadius.circular(context.elTheme.radiusSm),

        onDisabled: ElStyle(
          backgroundColor: context.isDark ? const Color(0xff262727) : const Color(0xfff5f7fa),
          color: context.elTheme.textPlaceholder,
          iconColor: context.elTheme.textPlaceholder,
        ),
        transition: const [ElTransition.all(Duration(milliseconds: 150))],
        iconColor: textColor,
      ).merge((active) ? (ElStyle(border: ElBorder.all(borderWidth: 1, borderColor: activeColor))) : null),
      ElInputOtpType.underlined =>
        ElStyle(
          width: side,
          height: side,
          alignment: .center,
          fontSize: fontSize,
          textOptions: textOptions,
          color: textColor,
          border: ElBorder.only(borderBottom: ElBorderSide(borderWidth: 1, borderColor: borderColor)),

          onDisabled: ElStyle(color: context.elTheme.textPlaceholder, iconColor: context.elTheme.textPlaceholder),
          transition: const [ElTransition.all(Duration(milliseconds: 150))],
          iconColor: textColor,
        ).merge(
          (active)
              ? (ElStyle(
                  border: ElBorder.only(borderBottom: ElBorderSide(borderWidth: 2, borderColor: activeColor)),
                ))
              : null,
        ),
    };
  }

  static double _side(bool compact) => compact ? 24 : 32;

  static double _fontSize(bool compact) => compact ? 12 : 14;
}
