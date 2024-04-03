part of flutter_base;

class FormItemInheritedWidget extends InheritedWidget {
  const FormItemInheritedWidget({
    super.key,
    required super.child,
    this.required,
  });

  final String? required;

  static FormItemInheritedWidget? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FormItemInheritedWidget>();
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
}

/// 表单项封装
class FormItemWidget extends StatefulWidget {
  /// 默认表单项，label外置
  const FormItemWidget(
    this.label, {
    super.key,
    required this.child,
    this.labelWidget,
    this.labelPosition,
    this.labelStyle,
    this.labelAlign,
    this.required,
  })  : separator = false,
        baseType = false,
        immersionType = false;

  /// flutter默认的基本表单
  const FormItemWidget.base({
    super.key,
    required this.child,
    this.required,
  })  : immersionType = false,
        baseType = true,
        separator = false,
        label = null,
        labelStyle = null,
        labelWidget = null,
        labelAlign = null,
        labelPosition = null;

  /// 扁平化表单项
  const FormItemWidget.flat({
    super.key,
    required this.child,
    this.required,
  })  : immersionType = false,
        baseType = false,
        separator = false,
        label = null,
        labelStyle = null,
        labelWidget = null,
        labelAlign = null,
        labelPosition = null;

  /// 沉浸式表单项
  const FormItemWidget.immersion(
    this.label, {
    super.key,
    required this.child,
    this.separator = true,
    this.labelWidget,
    this.labelStyle,
    this.required,
  })  : immersionType = true,
        baseType = false,
        labelAlign = LabelAlign.start,
        labelPosition = LabelPosition.left;

  /// 表单Widget
  final Widget child;

  /// 表单项标签名字，如果为null，则不显示标签
  final String? label;

  /// flutter原生默认表单
  final bool baseType;

  /// 沉浸式表单
  final bool immersionType;

  /// 开启分割线
  final bool separator;

  /// 标签宽度
  final double? labelWidget;

  /// 标签位置
  final LabelPosition? labelPosition;

  /// 标签对齐方式
  final LabelAlign? labelAlign;

  /// 自定义表单label样式，注意：它会覆盖 size、_labelBold 等属性
  final TextStyle? labelStyle;

  /// 表单是否必填，接收一个字符串，表示错误文本，若为空字符，则默认为必填，
  /// 同时label前面将携带一个 * 标识符，默认验证只是简单判空，如果你需要复杂表单验证，
  /// 你可以在表单组件 onValidator 验证函数中自行处理。
  final String? required;

  @override
  State<FormItemWidget> createState() => _FormItemWidgetState();
}

class _FormItemWidgetState extends State<FormItemWidget> with FlutterThemeMixin {
  /// 获取上下文的表单排版，左右布局或上下布局
  LabelPosition get _labelPosition =>
      widget.labelPosition ?? FormInheritedWidget.of(context)?.labelPosition ?? LabelPosition.left;

  /// 表单标签和表单组件的排版组件
  Widget get _formItemWidget {
    if (_labelPosition == LabelPosition.left) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: buildFormItem(context, false),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: buildFormItem(context, true),
      );
    }
  }

  /// 表单项包装，根据不同的类型添加下划线或者间距
  List<Widget> get _formItemWrapperWidget {
    if (widget.immersionType) {
      // 沉浸式表单追加下划线
      return [
        Expanded(child: _formItemWidget),
        if (widget.separator) const Divider(height: 1.0),
      ];
    } else {
      // 其他表单类型则添加默认的间距
      return [
        _formItemWidget,
        if (!widget.baseType) const SizedBox(height: 10),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormItemInheritedWidget(
      required: widget.required,
      child: SizedBox(
        width: double.infinity,
        height: widget.immersionType ? 44 : null, // 如果是沉浸式表单，我们需要现在它的高度
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: _formItemWrapperWidget,
        ),
      ),
    );
  }

  List<Widget> buildFormItem(BuildContext context, bool isColumn) {
    TextStyle $labelStyle = widget.labelStyle ??
        FormInheritedWidget.of(context)?.labelStyle ??
        TextStyle(
            fontSize: labelFontSize[FormInheritedWidget.of(context)?.size],
            fontWeight: FormInheritedWidget.of(context)?.labelBold ?? false ? FontWeight.bold : $defaultFontWeight);
    AlignmentGeometry labelAlignment = Alignment.centerLeft;
    if (!isColumn) {
      LabelAlign $labelAlign = widget.labelAlign ?? FormInheritedWidget.of(context)?.labelAlign ?? LabelAlign.start;
      switch ($labelAlign) {
        case LabelAlign.start:
          labelAlignment = Alignment.centerLeft;
          break;
        case LabelAlign.center:
          labelAlignment = Alignment.center;
          break;
        case LabelAlign.end:
          labelAlignment = Alignment.centerRight;
          break;
      }
    }

    double labelVerticalPadding =
        (inputPadding[FormInheritedWidget.of(context)?.size] ?? labelFontSize[FormSize.medium]!);

    return [
      if (widget.label != null)
        SizedBox(
          width: widget.labelWidget ?? FormInheritedWidget.of(context)?.labelWidth,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _labelPosition == LabelPosition.left ? 0 : 0,
              widget.separator ? 0 : labelVerticalPadding,
              0,
              widget.separator ? 0 : labelVerticalPadding,
            ),
            child: Align(
              alignment: labelAlignment,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    widget.label!,
                    style: $labelStyle,
                  ),
                  if (widget.required != null)
                    const Positioned(
                      left: -8,
                      top: 3,
                      child: Text(
                        '*',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
        ),
      isColumn ? widget.child : Expanded(child: widget.child),
    ];
  }
}
