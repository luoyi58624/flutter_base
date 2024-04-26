part of flutter_base;

/// 通用文本框组件
class FormTextFieldWidget extends StatefulWidget {
  /// 组件默认的文本框，四周有带有边框
  const FormTextFieldWidget({
    super.key,
    this.initValue,
    this.label,
    this.placeholder,
    this.textInputType = FormTextInputType.text,
    this.textInputAction,
    this.textarea = false,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.onlyRead = false,
    this.showClearIcon = true,
    this.showPasswordIcon = false,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.onTap,
    this.onClean,
    this.onChanged,
    this.onValidator,
    this.onSuffixIcon,
  })  : // 边框文本框大小必须由FormWidget统一控制，否则FormItemWidget的label无法左右对齐
        size = null,
        baseType = false,
        flatType = false,
        immersionType = false;

  /// flutter原生默认文本框，仅底部带有一条线
  const FormTextFieldWidget.base({
    super.key,
    this.initValue,
    this.label,
    this.placeholder,
    this.textInputType = FormTextInputType.text,
    this.textInputAction,
    this.textarea = false,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.size,
    this.onlyRead = false,
    this.showClearIcon = true,
    this.showPasswordIcon = false,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.onTap,
    this.onClean,
    this.onChanged,
    this.onValidator,
    this.onSuffixIcon,
  })  : baseType = true,
        flatType = false,
        immersionType = false;

  /// 圆角扁平、填充背景色的文本框
  const FormTextFieldWidget.flat({
    super.key,
    this.initValue,
    this.placeholder,
    this.textInputType = FormTextInputType.text,
    this.textInputAction,
    this.textarea = false,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.size,
    this.onlyRead = false,
    this.showClearIcon = true,
    this.showPasswordIcon = false,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.onTap,
    this.onClean,
    this.onChanged,
    this.onValidator,
    this.onSuffixIcon,
  })  : label = null,
        baseType = false,
        flatType = true,
        immersionType = false;

  /// 沉浸式、背景色透明、无边框的文本框，通常配合FormItemWidget
  const FormTextFieldWidget.immersion({
    super.key,
    this.initValue,
    this.placeholder,
    this.textInputType = FormTextInputType.text,
    this.textInputAction,
    this.textarea = false,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.size,
    this.onlyRead = false,
    this.showClearIcon = true,
    this.showPasswordIcon = false,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.onTap,
    this.onClean,
    this.onChanged,
    this.onValidator,
    this.onSuffixIcon,
  })  : label = null,
        baseType = false,
        flatType = false,
        immersionType = true;

  /// 表单初始值，该值只会初始化一次。
  ///
  /// 若你想通过修改绑定的数据直接同步到表单，例如vue一样的双向绑定，很遗憾，在flutter中没法实现或很难实现；
  /// 你若直接使用flutter的TextField组件你就会发现，你只能通过TextEditingController构造器去修改文本框的值，
  /// 我目前没办法通过监听外部值的变化来为你响应这一操作，在flutter中，新增副作用往往会造成意想不到的后果，
  /// 例如在build()构建期间执行setState()的异常，你最好、也只能手动去修改文本框的值。
  ///
  /// 示例：
  /// ```dart
  ///  var textFormKey = GlobalKey<FormTextFieldWidgetState>(); // 创建一个GlobalKey
  ///  FormTextFieldWidget(
  ///     key: textFormKey,   // 绑定key
  ///     initValue: 'hello', // 初始值
  ///  )
  ///
  ///  // 通过textFormKey访问内部的表单控制器controller去修改它的值
  ///  textFormKey.currentState?.controller.text = 'hello,world';
  /// ```
  final String? initValue;

  /// 标签
  final String? label;

  /// 提示文本
  final String? placeholder;

  /// 文本框输入类型
  final FormTextInputType textInputType;

  final TextInputAction? textInputAction;

  /// 多行文本框
  final bool textarea;

  /// 最大行数，默认为null，表示无限
  final int? maxLines;

  /// 最小行数，默认为1
  final int? minLines;

  /// 允许输入的最大长度
  final int? maxLength;

  ///  flutter原生默认表单
  final bool baseType;

  /// 圆角扁平化类型文本框
  final bool flatType;

  /// 沉浸式、背景色透明、无边框文本框
  final bool immersionType;

  /// 只读文本框
  final bool onlyRead;

  /// 是否显示清除图标
  final bool showClearIcon;

  /// 是否显示查看密码图标，默认false
  final bool showPasswordIcon;

  /// 前缀图标
  final IconData? prefixIcon;

  /// 表单尾缀图标，注意：如果表单只读：onlyRead=true，则默认追加右箭头尾缀图标
  final IconData? suffixIcon;

  /// 文本框大小
  final FormSize? size;

  final List<TextInputFormatter>? inputFormatters;

  /// 点击回调
  final GestureTapCallback? onTap;

  /// 点击清除回调
  final GestureTapCallback? onClean;

  /// 文本框内容发生更改回调
  final ValueChanged<String>? onChanged;

  /// 表单校验回调
  final FormFieldValidator<String>? onValidator;

  /// 点击自定义尾缀图标回调
  final GestureTapCallback? onSuffixIcon;

  @override
  State<FormTextFieldWidget> createState() => FormTextFieldWidgetState();
}

class FormTextFieldWidgetState extends State<FormTextFieldWidget> with FlutterThemeMixin {
  late TextEditingController controller;
  late bool showClearIcon = !DartUtil.isEmpty(widget.initValue); // 控制清除图标显示隐藏
  late TextInputType textInputType;
  late List<TextInputFormatter> inputFormatters;
  late bool hideText; // 隐藏文本框，当inputType==password
  late double prefixIconSize;
  late double suffixIconSize;
  FormFieldValidator<String>? onValidator;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initValue ?? '');
    controller.addListener(() {
      // 监听值的变化控制清除图标显示隐藏，做这么多判断是避免无意义的setState
      if (widget.showClearIcon) {
        if (controller.text == '') {
          if (showClearIcon == true) {
            setState(() {
              showClearIcon = false;
            });
          }
        } else {
          if (showClearIcon == false) {
            setState(() {
              showClearIcon = true;
            });
          }
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    hideText = false;
    prefixIconSize = widget.size != null
        ? formIconSize[widget.size]!
        : formIconSize[FormInheritedWidget.of(context)?.size] ?? formIconSize[FormSize.medium]!;
    suffixIconSize = prefixIconSize - 2;
    if (widget.textarea) {
      textInputType = TextInputType.multiline;
      inputFormatters = [];
    } else {
      switch (widget.textInputType) {
        case FormTextInputType.text:
          textInputType = TextInputType.text;
          inputFormatters = [];
          break;
        case FormTextInputType.number:
          textInputType = TextInputType.number;
          inputFormatters = [FilteringTextInputFormatter.digitsOnly];
          break;
        case FormTextInputType.password:
          textInputType = TextInputType.text;
          inputFormatters = [];
          hideText = true;
          break;
      }
    }
    if (widget.maxLength != null) {
      inputFormatters.add(LengthLimitingTextInputFormatter(math.max(widget.maxLength!, 0)));
    }
    if (widget.inputFormatters != null) {
      inputFormatters.addAll(widget.inputFormatters!);
    }
    if (FormItemInheritedWidget.of(context)?.required != null) {
      onValidator = (value) {
        if (DartUtil.isEmpty(value)) {
          return DartUtil.safeString(FormItemInheritedWidget.of(context)?.required, defaultValue: '必填');
        } else {
          return null;
        }
      };
    } else {
      onValidator = (value) {
        return null;
      };
    }
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  /// 表单垂直padding
  double get verticalPadding => widget.size != null
      ? inputPadding[widget.size]!
      : inputPadding[FormInheritedWidget.of(context)?.size] ?? inputPadding[FormSize.medium]!;

  /// flat扁平化表单垂直padding
  double get flatVerticalPadding => verticalPadding - 2;

  /// flat扁平化表单水平padding
  double get flatHorizontalPadding => flatVerticalPadding * 2 - 4;

  TextStyle get labelStyle => TextStyle(
        fontSize: widget.size != null
            ? labelFontSize[widget.size]
            : labelFontSize[FormInheritedWidget.of(context)?.size] ?? labelFontSize[FormSize.medium]!,
        fontWeight: GetxUtil.find<AppController>()?.config.defaultFontWeight,
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      validator: widget.onValidator ?? onValidator,
      maxLines: widget.textarea ? widget.maxLines : 1,
      minLines: widget.textarea ? widget.minLines : 1,
      readOnly: widget.onlyRead,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: labelStyle,
      keyboardType: textInputType,
      inputFormatters: inputFormatters,
      textInputAction: widget.textInputAction,
      obscureText: hideText,
      // 文字垂直对齐方式，在Material2中，就视觉效果而言，感觉只有设置为bottom文字才像居中
      textAlignVertical: Theme.of(context).useMaterial3 ? TextAlignVertical.center : TextAlignVertical.bottom,
      strutStyle: const StrutStyle(
        forceStrutHeight: true,
      ),
      // 禁用放大镜
      magnifierConfiguration: TextMagnifierConfiguration.disabled,
      decoration: InputDecoration(
        filled: widget.flatType,
        // isDense、contentPadding两个属性用于清除文本框默认内边距
        isDense: true,
        labelText: widget.label,
        labelStyle: labelStyle,
        contentPadding: widget.baseType
            ? EdgeInsets.only(
                top: verticalPadding - 2,
                bottom: 4,
              )
            : widget.flatType
                ? EdgeInsets.symmetric(
                    vertical: flatVerticalPadding,
                    horizontal: flatHorizontalPadding,
                  )
                : widget.immersionType
                    ? EdgeInsets.symmetric(
                        vertical: verticalPadding,
                      )
                    : EdgeInsets.symmetric(
                        vertical: verticalPadding,
                        horizontal: 12,
                      ),
        border: widget.baseType
            ? null
            : widget.flatType
                ? const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  )
                : widget.immersionType
                    ? const OutlineInputBorder(borderSide: BorderSide.none)
                    : OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        hintText: widget.placeholder,
        hintStyle: TextStyle(
          fontSize: widget.size != null
              ? hintFontSize[widget.size]
              : hintFontSize[FormInheritedWidget.of(context)?.size] ?? hintFontSize[FormSize.medium]!,
          fontWeight: $defaultFontWeight,
          color: Colors.grey,
        ),
        errorMaxLines: 3,
        errorStyle: TextStyle(
          color: $errorColor,
          fontSize: (widget.size != null
                  ? hintFontSize[widget.size]
                  : hintFontSize[FormInheritedWidget.of(context)?.size] ?? hintFontSize[FormSize.medium]!)! -
              2,
          fontWeight: $defaultFontWeight,
        ),
        prefixIcon: widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                size: prefixIconSize,
              )
            : null,
        prefixIconConstraints: BoxConstraints(
          minWidth: prefixIconSize * 2,
        ),
        suffixIcon: buildSuffixIcon(),
        suffixIconConstraints: BoxConstraints(
          minWidth: prefixIconSize * 2,
        ),
        suffixIconColor: Colors.grey,
      ),
    );
  }

  Widget? buildSuffixIcon() {
    if (widget.showClearIcon && showClearIcon && widget.textInputType != FormTextInputType.password) {
      return TapScaleWidget(
        onTap: () {
          controller.clear();
          setState(() {});
          if (widget.onChanged != null) widget.onChanged!('');
          if (widget.onClean != null) widget.onClean!();
        },
        child: Icon(
          Icons.clear,
          size: suffixIconSize,
        ),
      );
    } else if (widget.showPasswordIcon) {
      return TapScaleWidget(
        onTap: () {
          setState(() {
            hideText = !hideText;
          });
        },
        child: Icon(
          hideText ? Icons.visibility_off : Icons.visibility,
          size: suffixIconSize,
          color: hideText ? Colors.grey : Theme.of(context).primaryColor,
        ),
      );
    } else if (widget.suffixIcon != null) {
      return GestureDetector(
        onTap: widget.onSuffixIcon != null
            ? () {
                widget.onSuffixIcon!();
              }
            : null,
        child: Icon(
          widget.suffixIcon,
          size: suffixIconSize,
        ),
      );
    } else if (widget.onlyRead) {
      if (widget.immersionType) {
        return Icon(
          Icons.keyboard_arrow_right,
          size: suffixIconSize + 4,
        );
      } else {
        return Icon(
          Icons.arrow_forward_outlined,
          size: suffixIconSize,
        );
      }
    } else {
      return null;
    }
  }
}
