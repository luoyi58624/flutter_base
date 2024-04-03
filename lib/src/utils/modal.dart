part of flutter_base;

class ModalUtils {
  ModalUtils._();

  static Future<LabelModel?> showActionModal(BuildContext context, List<LabelModel> models) async {
    var result = await showCupertinoModalPopup<LabelModel>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
          actions: models
              .map((e) => CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(context, e);
                    },
                    child: Text(e.label),
                  ))
              .toList()),
    );
    return result;
  }

  /// 显示取消、确认提示框
  static Future<bool> showConfitmModal({
    String title = '提示',
    String? content,
    bool preventBack = false, // 是否阻止用户返回，若为true，barrierDismissible属性将无效
    bool barrierDismissible = false, // 是否允许用户点击遮罩关闭弹窗
    Widget? contentWidget, // 自定义内容widget
    Widget? cancelWidget, // 取消widget
    Widget? confirmWidget, // 确认widget
    bool titleCenter = false, // 标题是否居中
    bool showCancel = true,
    bool showConfirm = true,
    String cancelText = '取消',
    String confirmText = '确认',
    Color? cancelColor,
    Color? confirmColor,
    Function? onCancel,
    Function? onConfirm,
  }) async {
    bool? result = await showDialog<bool>(
      context: router.globalContext,
      barrierDismissible: barrierDismissible,
      builder: (context) => WillPopScope(
        onWillPop: preventBack ? () async => false : null,
        child: AlertDialog(
          title: Text(
            title,
            textAlign: titleCenter ? TextAlign.center : TextAlign.start,
          ),
          content: contentWidget ??
              Text(
                content ?? "",
                style: const TextStyle(
                  height: 1.5,
                  fontSize: 16,
                ),
              ),
          actions: <Widget>[
            if (showCancel)
              cancelWidget ??
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      if (onCancel != null) {
                        onCancel();
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: cancelColor ?? Colors.grey,
                    ),
                    child: Text(cancelText),
                  ),
            if (showConfirm)
              confirmWidget ??
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      if (onConfirm != null) {
                        onConfirm();
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: confirmColor ?? appTheme.primaryColor,
                    ),
                    child: Text(confirmText),
                  ),
          ],
        ),
      ),
    );

    return result == true;
  }

  /// 显示输入框提示框
  static Future<void> showInputModal({
    String title = '提示',
    String cancelText = '取消',
    String confirmText = '确认',
    Function(String value)? onConfirm,
  }) async {
    await showDialog(
        context: router.globalContext,
        builder: (context) => InputDialogWidget(
              title: title,
              cancelText: cancelText,
              confirmText: confirmText,
              onConfirm: onConfirm,
            ));
  }
}

class InputDialogWidget extends StatefulWidget {
  const InputDialogWidget({
    super.key,
    this.title = '提示',
    this.cancelText = '取消',
    this.confirmText = '确认',
    this.onConfirm,
  });

  final String title;
  final String cancelText;
  final String confirmText;
  final Function(String value)? onConfirm;

  @override
  State<InputDialogWidget> createState() => _InputDialogWidgetState();
}

class _InputDialogWidgetState extends State<InputDialogWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: _buildForm(),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(widget.cancelText),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate() == true) {
              Navigator.of(context).pop();
              if (widget.onConfirm != null) {
                widget.onConfirm!(_controller.text);
              }
            }
          },
          child: Text(widget.confirmText),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '必填';
          }
          return null;
        },
      ),
    );
  }
}
