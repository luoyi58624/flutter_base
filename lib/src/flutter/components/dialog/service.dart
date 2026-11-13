part of 'index.dart';

/// 对话框服务。
extension ElDialogExt on El {
  static final _service = ElDialogService._();

  /// 打开对话框、确认框、提示框、输入框和底部面板。
  ElDialogService get dialog => _service;
}

/// 在根导航器打开 ElDialog；遮罩点击、返回键、Esc 和拖动关闭得到 null。
final class ElDialogService {
  ElDialogService._();

  /// 打开自定义对话框，内容里用 `Navigator.pop(context, value)` 返回结果；placement 为 bottom 时即底部面板。
  Future<T?> show<T>(
    BuildContext context, {
    required Object child,
    Object? title,
    Object? footer,
    ElPopupPlacement placement = .center,
    bool showClose = false,
    bool dismissible = true,
    ElStyle? style,
    String? semanticLabel,
  }) => showModal<T>(
    context,
    dismissible: dismissible,
    label: semanticLabel ?? _label(title),
    builder: (close) => ElDialog(
      title: title,
      footer: footer,
      placement: placement,
      showClose: showClose,
      dismissible: dismissible,
      style: style,
      semanticLabel: semanticLabel,
      onClose: close,
      child: child,
    ),
  );

  /// 确认框：确认得到 true，取消或关闭得到 false；危险操作把 type 设为 error。
  Future<bool> confirm(
    BuildContext context, {
    required Object content,
    Object? title,
    Object confirmText = '确定',
    Object cancelText = '取消',
    ElThemeType type = .primary,
    ElPopupPlacement placement = .center,
    bool dismissible = true,
  }) async =>
      await showModal<bool>(
        context,
        dismissible: dismissible,
        label: _label(title),
        builder: (close) => ElDialog(
          title: title,
          placement: placement,
          dismissible: dismissible,
          confirmText: confirmText,
          cancelText: cancelText,
          type: type,
          onConfirm: () => close(true),
          onCancel: () => close(false),
          onClose: close,
          child: content,
        ),
      ) ??
      false;

  /// 提示框：只有确认按钮，关闭后完成。
  Future<void> alert(
    BuildContext context, {
    required Object content,
    Object? title,
    Object confirmText = '确定',
    ElThemeType type = .primary,
    ElPopupPlacement placement = .center,
    bool dismissible = true,
  }) => showModal<void>(
    context,
    dismissible: dismissible,
    label: _label(title),
    builder: (close) => ElDialog(
      title: title,
      placement: placement,
      dismissible: dismissible,
      confirmText: confirmText,
      type: type,
      onConfirm: close,
      onClose: close,
      child: content,
    ),
  );

  /// 输入框：确认或回车时先校验，validator 返回错误文字时留在面板内提示；确认得到输入值，取消或关闭得到 null。
  Future<String?> prompt(
    BuildContext context, {
    Object? title,
    Object? content,
    String value = '',
    String? placeholder,
    String? Function(String value)? validator,
    Object confirmText = '确定',
    Object cancelText = '取消',
    ElPopupPlacement placement = .center,
    bool dismissible = true,
  }) {
    final input = _PromptInput(value);
    return showModal<String>(
      context,
      dismissible: dismissible,
      label: _label(title),
      builder: (close) {
        void submit() {
          final error = validator?.call(input.text);
          input.showError?.call(error);
          if (error == null) close(input.text);
        }

        return ElDialog(
          title: title,
          placement: placement,
          dismissible: dismissible,
          confirmText: confirmText,
          cancelText: cancelText,
          onConfirm: submit,
          onCancel: close,
          onClose: close,
          child: _Prompt(input: input, content: content, placeholder: placeholder, onSubmitted: submit),
        );
      },
    );
  }

  static String? _label(Object? title) => title is String ? title : null;
}

// 输入框的当前文本与错误提示入口，生命周期随一次 prompt。
final class _PromptInput {
  _PromptInput(this.text);

  String text;
  ValueChanged<String?>? showError;
}

class _Prompt extends HookWidget {
  const _Prompt({required this.input, required this.content, required this.placeholder, required this.onSubmitted});

  final _PromptInput input;
  final Object? content;
  final String? placeholder;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final error = useState<String?>(null);
    final focus = useFocusNode();
    input.showError = (message) {
      error.value = message;
      // 回车提交按标准语义会先失焦，桌面点击确认也会取走焦点；校验失败时把焦点还给输入框继续修改。
      if (message != null) WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
    };
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        if (content case final content?) ElView(child: content),
        ElInput(
          value: input.text,
          placeholder: placeholder,
          autofocus: true,
          focusNode: focus,
          onChanged: (value) {
            input.text = value;
            error.value = null;
          },
          onSubmitted: (_) => onSubmitted(),
        ),
        if (error.value case final message?)
          ElView(
            style: ElStyle(fontSize: 12, lineHeight: 1.5, color: context.elTheme.error),
            child: message,
          ),
      ],
    );
  }
}
