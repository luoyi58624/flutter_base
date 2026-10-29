part of 'index.dart';

/// 表单项：label（必填星号 / 后缀）+ 内容区 + 校验错误文本。
///
/// 布局对齐官方 el-form-item：label 与控件同高垂直居中（right/left 位）、
/// top 位块级 + 底距 8；错误区常驻预留一行高度，单行错误显隐不跳版，
/// 多行错误按内容自然增高。
class ElFormItem extends StatelessWidget {
  /// 创建表单项，可在无品牌主题时使用通用布局。
  const ElFormItem({
    super.key,
    this.prop,
    this.label,
    this.labelWidth,
    this.labelPosition,
    this.required,
    this.rules,
    this.error,
    this.style,
    this.labelStyle,
    this.errorStyle,
    required this.child,
  });

  /// 绑定 [ElForm] model 的数据 key；字段双向绑定与校验的必要标识。
  final String? prop;

  /// 字段标签文本。
  final String? label;

  /// 覆盖表单级 labelWidth。
  final double? labelWidth;

  /// 覆盖表单级 labelPosition。
  final ElFormLabelPosition? labelPosition;

  /// 是否必填（只影响星号显示）；null 时按合并规则里是否含
  /// [ElRequiredFormRule] 自动推导。
  final bool? required;

  /// item 级规则，与表单级 rules 合并（表单级在前）。
  final List<ElFormRule>? rules;

  /// 外部直设错误文本：非 null 时立即显示（优先于校验错误）。
  final String? error;

  /// 表单项根样式。
  final ElStyle? style;

  /// 标签样式。
  final ElStyle? labelStyle;

  /// 错误提示与必填星号样式。
  final ElStyle? errorStyle;

  /// 字段内容。
  final Widget child;

  /// 子树内取所在表单项的绑定 prop（无 ElFormItem 祖先返回 null）。
  /// 表单字段组件经它完成 prop 双向绑定；表单数据经 [ElForm.maybeOf] 获取。
  static String? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_FormItemScope>()?.prop;
  }

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.maybeOf(context)?.formItemBuilder?.call(context, this) ?? ElFormItemView(component: this);
}

/// 表单项通用布局与字段注册宿主，供品牌 Builder 配置外观。
class ElFormItemView extends StatefulWidget {
  /// 创建表单项宿主，编辑字段和规则始终来自公共声明。
  const ElFormItemView({super.key, required this.component, this.labelStyle, this.errorStyle});

  /// 原始表单项声明。
  final ElFormItem component;

  /// 品牌标签默认样式，公共声明的 labelStyle 优先。
  final ElStyle? labelStyle;

  /// 品牌错误和必填标记样式，公共声明的 errorStyle 优先。
  final ElStyle? errorStyle;

  @override
  State<ElFormItemView> createState() => _FormItemState();
}

class _FormItemState extends State<ElFormItemView> {
  ElStyle? get _errorStyle => (widget.errorStyle ?? const ElStyle()).merge(widget.component.errorStyle);
  ElFormState? _form;
  String? _boundProp;
  _FormFieldRegistration? _registration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebind(ElForm.maybeOf(context));
  }

  @override
  void didUpdateWidget(ElFormItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.component.prop != oldWidget.component.prop ||
        !identical(widget.component.rules, oldWidget.component.rules)) {
      _rebind(_form);
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  void _rebind(ElFormState? form) {
    _unbind();
    _form = form;
    final prop = widget.component.prop;
    if (form != null && prop != null) {
      _registration = _FormFieldRegistration(rules: widget.component.rules);
      form._register(prop, _registration!);
      _boundProp = prop;
    }
  }

  void _unbind() {
    final prop = _boundProp;
    if (prop != null && _form != null && _registration != null) {
      _form!._unregister(prop, _registration!);
    }
    _boundProp = null;
    _registration = null;
  }

  bool _isRequired(_FormScope? scope) {
    final explicit = widget.component.required;
    if (explicit != null) return explicit;
    final prop = widget.component.prop;
    final form = scope?.state;
    if (prop == null) return widget.component.rules?.any((r) => r is ElRequiredFormRule) ?? false;
    if (form == null) return widget.component.rules?.any((r) => r is ElRequiredFormRule) ?? false;
    return form._rulesFor(prop).any((r) => r is ElRequiredFormRule);
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FormScope>();
    final form = scope?.state;
    final isDesktop = ElPlatform.isDesktop;
    final boxSize = isDesktop ? 32.0 : 40.0;
    final itemGap = isDesktop ? 4.0 : 6.0;
    final labelPosition = widget.component.labelPosition ?? scope?.labelPosition ?? ElFormLabelPosition.right;
    final top = labelPosition == ElFormLabelPosition.top;

    Widget field = Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        widget.component.child,
        _FormItemError(form: form, prop: widget.component.prop, error: widget.component.error, style: _errorStyle),
      ],
    );
    if (!top) field = Expanded(child: field);

    Widget content = field;
    if (form != null) {
      content = _FormItemScope(form: form, prop: widget.component.prop, child: content);
    }

    return ElView(
      style: ElStyle(margin: EdgeInsets.only(bottom: itemGap)).merge(widget.component.style),
      child: Flex(
        direction: top ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: top ? .stretch : .start,
        children: [if (widget.component.label != null) _buildLabel(scope, labelPosition, top, boxSize), content],
      ),
    );
  }

  Widget _buildLabel(_FormScope? scope, ElFormLabelPosition labelPosition, bool top, double boxSize) {
    final asterisk = _isRequired(scope);
    final alignEnd = !top && labelPosition == ElFormLabelPosition.right;
    return ElView(
      style: ElStyle(
        width: top ? null : (widget.component.labelWidth ?? scope?.labelWidth),
        height: top ? null : boxSize,
        padding: top ? null : const EdgeInsets.only(right: 12),
        margin: top ? const EdgeInsets.only(bottom: 8) : null,
        fontSize: 15,
        alignment: alignEnd ? .centerRight : .centerLeft,
      ).merge(widget.labelStyle).merge(widget.component.labelStyle),
      child: Row(
        mainAxisSize: .min,
        mainAxisAlignment: alignEnd ? .end : .start,
        crossAxisAlignment: .center,
        children: [
          if (asterisk) _FormAsterisk(style: _errorStyle),
          if (asterisk) const ElView(style: ElStyle(width: 4)),
          Flexible(
            child: ElView(
              style: const ElStyle(softWrap: false, overflow: TextOverflow.ellipsis),
              child: '${widget.component.label}${scope?.labelSuffix ?? ''}',
            ),
          ),
        ],
      ),
    );
  }
}

/// 必填星号（官方 `*`，danger 色，与 label 间距 4 由父 flex spacing 承担）。
class _FormAsterisk extends StatelessWidget {
  const _FormAsterisk({this.style});

  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElView(style: style, child: '*');
  }
}

/// 错误槽：始终预留一行错误文本空间；超过一行时按文本实际高度自然增高。
/// ObsBuilder 收集 errorMessages 依赖自动显隐。
class _FormItemError extends StatelessWidget {
  const _FormItemError({required this.form, required this.prop, required this.error, this.style});

  final ElFormState? form;
  final String? prop;
  final String? error;
  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    return ObsBuilder(
      builder: (context) {
        final msg = error ?? (form != null && prop != null ? form!.errorMessages[prop!] : null);
        return _FormItemErrorText(msg, style: style);
      },
    );
  }
}

/// 错误文本显隐动画：对齐 element-plus `el-zoom-in-top`——opacity + scaleY(0↔1)、
/// 原点 center top、0.3s cubic-bezier(0.23,1,0.32,1)（fast-bezier）。
/// Vue transition 的进出场语义手工补齐：进场首帧以隐藏态挂载、下帧翻可见
/// 触发过渡；退场保留旧文本动完再真卸载。
class _FormItemErrorText extends StatefulWidget {
  const _FormItemErrorText(this.msg, {this.style});

  final ElStyle? style;

  final String? msg;

  @override
  State<_FormItemErrorText> createState() => _FormItemErrorTextState();
}

class _FormItemErrorTextState extends State<_FormItemErrorText> {
  static const _duration = Duration(milliseconds: 300);
  static const _curve = Cubic(0.23, 1, 0.32, 1);

  /// 呈现文本（退场期保留旧值供动画显示）。
  String? _text;

  /// 动画目标态。
  bool _shown = false;

  Timer? _unmountTimer;

  @override
  void initState() {
    super.initState();
    if (widget.msg != null) {
      _text = widget.msg;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void didUpdateWidget(_FormItemErrorText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final msg = widget.msg;
    if (msg != null) {
      _unmountTimer?.cancel();
      _unmountTimer = null;
      // 节点未挂载的全新进场必须走 enter-from 两帧流程（先隐藏态挂载、下帧
      // 翻可见）——同步置 shown 会让节点首帧即终态、进场瞬现（事故根因：
      // 本组件常驻树中，进场走的是 didUpdateWidget 而非 initState）。
      // 退场中回弹/换文本时节点已在，直接动向可见
      final fresh = _text == null;
      _text = msg;
      if (fresh) {
        _shown = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _shown = true);
        });
      } else {
        _shown = true;
      }
    } else if (_text != null && _shown) {
      _shown = false;
      _unmountTimer = Timer(_duration, () {
        if (mounted) setState(() => _text = null);
      });
    }
  }

  @override
  void dispose() {
    _unmountTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    final isDesktop = ElPlatform.isDesktop;
    return ElView(
      style: ElStyle(
        minHeight: isDesktop ? 14 : 16,
        padding: EdgeInsets.only(top: isDesktop ? 2 : 4),
        fontSize: 12,
        lineHeight: 1.0,
        opacity: _shown ? 1.0 : 0.0,
        transform: .scaleY(_shown ? 1.0 : 0.0),
        transformAlignment: .topCenter,
        transitions: const [.all(_duration, _curve)],
      ).merge(widget.style),
      child: text ?? '',
    );
  }
}
