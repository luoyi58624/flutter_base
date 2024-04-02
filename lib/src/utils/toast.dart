part of flutter_base;

FToast toast = FToast();

/// 轻提示工具类
class ToastUtil {
  ToastUtil._();

  /// 显示通用风格的轻提示，它会自动适配黑暗模式
  static void showToast(dynamic title, {int duration = 3}) {
    toast.removeCustomToast();
    toast.showToast(
      child: _DefaultToastWidget(title: title),
      toastDuration: Duration(seconds: duration),
      gravity: ToastGravity.CENTER,
    );
  }

  /// primary颜色的轻提示
  static void showPrimaryToast(dynamic title, {int duration = 3}) {
    _buildToast(
      _OtherToastWidget(
        title: title,
        backgroundColor: appTheme.primaryColor,
      ),
      duration,
    );
  }

  /// success颜色的轻提示
  static void showSuccessToast(dynamic title, {int duration = 3}) {
    _buildToast(
      _OtherToastWidget(
        title: title,
        backgroundColor: appTheme.successColor,
      ),
      duration,
    );
  }

  /// warning颜色的轻提示
  static void showWarningToast(dynamic title, {int duration = 3}) {
    _buildToast(
      _OtherToastWidget(
        title: title,
        backgroundColor: appTheme.warningColor,
      ),
      duration,
    );
  }

  /// error颜色的轻提示
  static void showErrorToast(dynamic title, {int duration = 3}) {
    _buildToast(
      _OtherToastWidget(
        title: title,
        backgroundColor: appTheme.errorColor,
      ),
      duration,
    );
  }

  /// info颜色的轻提示
  static void showInfoToast(dynamic title, {int duration = 3}) {
    _buildToast(
      _OtherToastWidget(
        title: title,
        backgroundColor: appTheme.infoColor,
      ),
      duration,
    );
  }

  /// 构建一个自定义widget的toast，如果当前页面已经有一个toast，则会关闭它重新显示新的toast
  static void _buildToast(Widget toastWidget, int duration) {
    toast.removeCustomToast();
    toast.showToast(
      child: toastWidget,
      toastDuration: Duration(seconds: duration),
      positionedToastBuilder: (context, child) {
        return Positioned(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 80,
          child: child,
        );
      },
    );
  }
}

/// 默认风格Toast组件
class _DefaultToastWidget extends StatelessWidget {
  const _DefaultToastWidget({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        toast.removeCustomToast();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// 更多风格样式的Toast组件
class _OtherToastWidget extends StatelessWidget {
  const _OtherToastWidget({
    required this.title,
    required this.backgroundColor,
  });

  final String title;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        toast.removeCustomToast();
      },
      child: Material(
        elevation: 2,
        // shape: BoxShape.circle,
        borderRadius: BorderRadius.circular(200.0),
        clipBehavior: Clip.antiAlias,
        child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            decoration: BoxDecoration(color: backgroundColor),
            child: Text(
              title,
              style: const TextStyle(
                height: 1.5,
                color: Colors.white,
              ),
            )),
      ),
    );
  }
}
