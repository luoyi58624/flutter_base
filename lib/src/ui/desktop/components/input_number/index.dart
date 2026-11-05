import 'package:flutter/widgets.dart';

import '../../internal.dart';

/// Element Plus 数字输入框。
///
/// 值通道三选一（口径同 [ElInput]）：`value` 普通值 / `modelValue` 双向 /
/// `prop` + 祖先 ElForm 表单直连；空值用 `null` 表达（官方 `valueOnClear`）。
///
/// 文本编辑复用 [ElInput]，本组件只管步进按钮、边界钳制与精度——不重造编辑器内核。
///
/// Element 数字输入框主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class InputNumber extends ElInputNumModelValue {
  InputNumber(this.component, {super.key})
    : super(
        value: component.value,
        modelValue: component.modelValue,
        onChanged: component.onChanged,
      );

  final ElInputNumber component;
  static final _fieldControlKey = UniqueKey();
  num get step => component.step;
  bool get stepStrictly => component.stepStrictly;
  num? get min => component.min;
  num? get max => component.max;
  int? get precision => component.precision;
  bool get controls => component.controls;
  ElInputNumberControls get controlsPosition => component.controlsPosition;
  bool get disabled => component.disabled;
  bool get readOnly => component.readOnly;
  String? get placeholder => component.placeholder;
  double? get width => component.width;
  ElStyle? get style => component.style;
  String? get semanticLabel => component.semanticLabel;
  Iterable<String>? get autofillHints => component.autofillHints;

  @override
  Widget build(BuildContext context) {
    final fieldControl = $set(
      _fieldControlKey,
      useMemoized(ElInputController.new),
    );
    useEffect(() => fieldControl.dispose, [fieldControl]);
    return super.build(context);
  }

  @override
  Widget obsBuilder(BuildContext context) {
    final compact = context.elComponentCompact(style);
    final current = $obs.value;

    // 触顶后对应方向的钮锁成禁用（官方口径），而非静默吞掉点击
    final upDisabled =
        disabled ||
        readOnly ||
        (max != null && _clamp(_shift(current, 1)) == current);
    final downDisabled =
        disabled ||
        readOnly ||
        (min != null && _clamp(_shift(current, -1)) == current);

    return ElView(
      event: disabled ? ElEvent(disabled: true) : null,
      style: _rootStyle(compact).merge(style),
      child: Row(
        mainAxisSize: .min,
        crossAxisAlignment: .center,
        children: [
          if (_sideControls)
            _button(compact, up: false, disabled: downDisabled),
          _field(compact),
          if (_sideControls)
            _button(compact, up: true, disabled: upDisabled),
          if (controls && controlsPosition == ElInputNumberControls.right)
            _stackedButtons(
              compact,
              upDisabled: upDisabled,
              downDisabled: downDisabled,
            ),
        ],
      ),
    );
  }

  bool get _sideControls =>
      controls && controlsPosition == ElInputNumberControls.sides;

  /// 文本框吃掉按钮占位后的剩余宽度；提交时统一过钳制与精度，
  /// 所以手输 999 也会被 max 拉回来
  Widget _field(bool compact) {
    final buttonWidth = controls ? _height(compact) : 0.0;
    final taken = _sideControls ? buttonWidth * 2 : buttonWidth;
    final fieldWidth = (width ?? _defaultWidth(compact)) - taken;
    final fieldControl = $get<ElInputController>(_fieldControlKey);

    return _NumberField(
      key: const ValueKey<String>('el-input-number-field'),
      value: toTextEditing($obs.value),
      control: fieldControl,
      disabled: disabled,
      readOnly: readOnly,
      placeholder: placeholder,
      semanticLabel: semanticLabel,
      autofillHints: autofillHints,
      keyboardType: TextInputType.numberWithOptions(
        decimal: precision != 0,
        signed: (min ?? -1) < 0,
      ),
      // ElInput 的密度跟随数字框；宽度与居中仍由 style 覆写。
      style: ElStyle(
        width: fieldWidth <= 0 ? null : fieldWidth,
        height: _height(compact),
        fontSize: style?.fontSize,
        iconSize: style?.iconSize,
        textAlign: .center,
        borderRadius: _sideControls ? BorderRadius.zero : null,
      ),
      onChanged: (text) => $obs.value = _clamp(_normalize(_parse(text))),
      onBlur: () => _scheduleDraftCommit(fieldControl),
    );
  }

  /// blur 发生在 FocusNode 通知栈内；延到微任务可让 ElEditableView 先提交 IME
  /// composing，再以同一个 controller 原子收口 draft，且不抢回下一焦点。
  void _scheduleDraftCommit(ElInputController fieldControl) {
    if (disabled || readOnly) return;
    final controller = fieldControl.controller;
    if (controller == null) return;
    Future<void>.microtask(() {
      if (!identical(fieldControl.controller, controller) ||
          fieldControl.hasFocus) {
        return;
      }
      final normalized = _clamp(_normalize(_parse(controller.text)));
      final canonical = toTextEditing(normalized);
      if ($obs.value != normalized) $obs.value = normalized;
      if (controller.text != canonical) {
        controller.replaceRange(
          0,
          controller.length,
          canonical,
          selection: TextSelection.collapsed(offset: canonical.length),
        );
      }
    });
  }

  Widget _button(
    bool compact, {
    required bool up,
    required bool disabled,
  }) => _InputNumberButton(
    key: ValueKey<String>(
      up ? 'el-input-number-increment' : 'el-input-number-decrement',
    ),
    icon: up ? ElIcons.plus : ElIcons.minus,
    semanticLabel: up ? '增加' : '减少',
    width: _height(compact),
    height: _height(compact),
    iconSize: _sideGlyphSize(compact),
    disabled: disabled,
    onPressed: () => $obs.value = _clamp(_shift($obs.value, up ? 1 : -1)),
  );

  /// 右侧竖排：两钮各占内容高的一半（官方 `(input-height - 2) / 2`）
  Widget _stackedButtons(
    bool compact, {
    required bool upDisabled,
    required bool downDisabled,
  }) {
    final half = (_height(compact) - 2) / 2;
    return Column(
      mainAxisSize: .min,
      children: [
        _InputNumberButton(
          key: const ValueKey<String>('el-input-number-right-increment'),
          icon: ElIcons.arrowUp,
          semanticLabel: '增加',
          width: _height(compact),
          height: half,
          iconSize: _stackedGlyphSize(compact),
          disabled: upDisabled,
          onPressed: () => $obs.value = _clamp(_shift($obs.value, 1)),
        ),
        _InputNumberButton(
          key: const ValueKey<String>('el-input-number-right-decrement'),
          icon: ElIcons.arrowDown,
          semanticLabel: '减少',
          width: _height(compact),
          height: half,
          iconSize: _stackedGlyphSize(compact),
          disabled: downDisabled,
          onPressed: () => $obs.value = _clamp(_shift($obs.value, -1)),
        ),
      ],
    );
  }

  /// 空值起步按 min（没有 min 就按 0），对齐官方「空态点 + 得到最小可用值」
  num _shift(num? current, int direction) {
    if (current == null) return _normalize(min ?? 0) ?? 0;
    return _normalize(current + step * direction) ?? current;
  }

  /// 精度 + step 严格倍数：两者都是「显示与写回同一口径」，故合在一处
  num? _normalize(num? value) {
    if (value == null) return null;
    var v = value;
    if (stepStrictly) v = (v / step).round() * step;
    if (precision != null) v = num.parse(v.toStringAsFixed(precision!));
    return v;
  }

  num? _clamp(num? value) {
    if (value == null) return null;
    if (min != null && value < min!) return min;
    if (max != null && value > max!) return max;
    return value;
  }

  /// 手输途中允许出现 '-' / '1.' 这类残缺文本，解析不出来时保留当前值不跳
  num? _parse(String text) {
    if (text.trim().isEmpty) return null;
    final parsed = num.tryParse(text);
    return parsed != null && parsed.isFinite ? parsed : $obs.value;
  }

  ElStyle _rootStyle(bool compact) => ElStyle(
    width: width ?? _defaultWidth(compact),
    height: _height(compact),
    alignment: .center,
    onDisabled: const ElStyle(cursor: SystemMouseCursors.forbidden),
  );

  static double _defaultWidth(bool compact) => compact ? 120 : 150;

  static double _height(bool compact) => compact ? 24 : 32;

  /// 左右整高按钮留出至少 4px 纵向呼吸区。
  static double _sideGlyphSize(bool compact) => compact ? 11 : 12;

  /// 右侧半高按钮的 glyph 必须装进普通和紧凑模式的内容盒。
  static double _stackedGlyphSize(bool compact) => compact ? 8 : 10;
}

/// 步进钮：`fill-color-light` 底 + 边框，hover 变主色，禁用不响应
class _InputNumberButton extends StatefulWidget {
  const _InputNumberButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.width,
    required this.height,
    required this.iconSize,
    required this.disabled,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final double width;
  final double height;
  final double iconSize;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  State<_InputNumberButton> createState() => _InputNumberButtonState();
}

class _InputNumberButtonState extends State<_InputNumberButton> {
  /// 步进钮不进 Tab 序（只由指针/方向键请求焦点），节点随组件持有与销毁。
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'ElInputNumberButton(${widget.semanticLabel})',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElButtonView(
      disabled: widget.disabled,
      focusNode: _focusNode,
      onPressed: widget.onPressed,
      semanticLabel: widget.semanticLabel,
      style: ElStyle(
        width: widget.width,
        height: widget.height,
        alignment: .center,
        // 步进钮底从 $bgColor 派生加深 1 级
        backgroundColor: context.elTheme.bgColor.elLight1(
          context,
          reverse: !context.elTheme.bgColor.isDark,
        ),
        border: ElBorder.all(
          borderWidth: 1,
          borderColor: context.elTheme.borderColor,
        ),
        color: context.elTheme.textRegular,
        fontSize: 13,
        cursor: SystemMouseCursors.click,
        userSelect: .none,
        onHover: ElStyle(
          color: context.elTheme.primary,
          iconColor: context.elTheme.primary,
        ),
        onDisabled: ElStyle(
          color: context.elTheme.textPlaceholder,
          cursor: SystemMouseCursors.forbidden,
          iconColor: context.elTheme.textPlaceholder,
        ),
        // 密度切换时按钮和输入必须同帧换尺寸，避免旧按钮宽度挤出新壳。
        transition: const [
          ElTransition.fields({
            ElTransitionField.color,
            ElTransitionField.iconColor,
            ElTransitionField.backgroundColor,
            ElTransitionField.border,
          }),
        ],
        iconColor: context.elTheme.textRegular,
      ),
      // 跟随本包既有惯例（alert/tag/steps 同）：图标用 Flutter Icon，
      // 颜色取 currentColor，好让按钮的 hover / disabled 变色传下来
      child: ElIcon(widget.icon, size: widget.iconSize),
    );
  }
}

/// 数字框的内层编辑器：**显式不参与表单绑定**。
///
/// [ElInput] 继承的基类会隐式继承 [ElFormItem.prop]，若不关掉，内层会与外层
/// [ElInputNumber] 抢同一字段——外层写回 6，内层随后写回 '6'，formData 里就
/// 成了字符串。值只经外层数字通道流转。
class _NumberField extends ElInput {
  const _NumberField({
    super.key,
    super.value,
    super.onChanged,
    super.control,
    super.onBlur,
    super.disabled,
    super.readOnly,
    super.placeholder,
    super.semanticLabel,
    super.autofillHints,
    super.keyboardType,
    super.style,
  });

  @override
  bool get formBindable => false;
}
