part of flutter_base;

/// label所在的位置
enum LabelPosition {
  left, // label在左，formItem在右 （同一行）
  top, // label在上，formItem在下 （换行）
}

/// label对齐方式，注意：使用 LabelPosition.top 只能左对齐（为了更好看）
enum LabelAlign {
  start, // 左对齐
  center, // 居中对齐
  end, // 右对齐
}

/// 表单尺寸
enum FormSize {
  mini, // 极小
  small, // 小
  medium, // 中
  large, // 大
  xLarge, // 超大
}

/// 文本框输入类型
enum FormTextInputType {
  text, // 允许所有文字
  number, // 只允许输入数字
  password, // 密码，注意：若文本框为密码类型，则不会显示清除图标
}

/// 标签文字大小
const Map<FormSize, double> labelFontSize = {
  FormSize.mini: 13.0,
  FormSize.small: 14.0,
  FormSize.medium: 15.0,
  FormSize.large: 16.0,
  FormSize.xLarge: 17.0,
};

/// 提示文字大小
const Map<FormSize, double> hintFontSize = {
  FormSize.mini: 12.0,
  FormSize.small: 13.0,
  FormSize.medium: 14.0,
  FormSize.large: 15.0,
  FormSize.xLarge: 16.0,
};

/// 前缀图标大小
const Map<FormSize, double> formIconSize = {
  FormSize.mini: 16.0,
  FormSize.small: 18.0,
  FormSize.medium: 20.0,
  FormSize.large: 22.0,
  FormSize.xLarge: 24.0,
};

/// 文本框上下内边距
const Map<FormSize, double> inputPadding = {
  FormSize.mini: 10.0,
  FormSize.small: 11.0,
  FormSize.medium: 12.0,
  FormSize.large: 14.0,
  FormSize.xLarge: 16.0,
};

/// 用于向子组件共享的表单数据
class FormInheritedWidget extends InheritedWidget {
  const FormInheritedWidget({
    super.key,
    required super.child,
    this.labelWidth,
    this.labelStyle,
    required this.labelBold,
    required this.labelPosition,
    required this.labelAlign,
    required this.size,
  });

  final FormSize size;
  final LabelPosition labelPosition;
  final double? labelWidth;
  final bool labelBold;
  final TextStyle? labelStyle;
  final LabelAlign labelAlign;

  /// 子孙组件通过of获取的数据，当父组件发生更改时将会自动重建，
  /// dependOnInheritedWidgetOfExactType表示通知依赖它的组件重新构建
  static FormInheritedWidget? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FormInheritedWidget>();
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
}

/// 对Flutter的Form组件进行包装，方便用户传递一些属性控制整个表单的默认样式
class FormWidget extends StatefulWidget {
  const FormWidget({
    super.key,
    required this.child,
    this.labelWidth,
    this.labelPosition = LabelPosition.left,
    this.labelAlign = LabelAlign.start,
    this.size = FormSize.medium,
    this.labelStyle,
    this.labelBold = false,
  });

  final Widget child;

  /// FormItemWidget label的默认宽度
  final double? labelWidth;

  /// FormItemWidget label的默认位置
  final LabelPosition labelPosition;

  /// FormItemWidget label的默认对齐方式
  final LabelAlign labelAlign;

  /// 表单整体大小
  final FormSize size;

  /// 使用粗体label
  final bool? labelBold;

  /// 自定义表单label样式，注意：它会覆盖 size、_labelBold 等属性
  final TextStyle? labelStyle;

  @override
  State<FormWidget> createState() => FormWidgetState();
}

class FormWidgetState extends State<FormWidget> {
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    // 使用_FormDataWidget注入数据，方便后代子孙组件获取公共数据
    return FormInheritedWidget(
      labelWidth: widget.labelWidth,
      labelPosition: widget.labelPosition,
      labelAlign: widget.labelAlign,
      size: widget.size,
      labelStyle: widget.labelStyle,
      labelBold: widget.labelBold == true ? true : false,
      child: Form(
        key: formKey,
        child: widget.child,
      ),
    );
  }

  bool validate() {
    FlutterUtil.unfocus();
    return formKey.currentState?.validate() ?? false;
  }

  void reset() {
    FlutterUtil.unfocus();
    formKey.currentState?.reset();
  }
}
