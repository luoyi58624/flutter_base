part of flutter_base;

class ExitInterceptWidget extends StatefulWidget {
  /// 拦截用户退出应用
  const ExitInterceptWidget({
    super.key,
    required this.child,
    this.message = '请再按一次退出应用',
  });

  final Widget child;

  final String message;

  @override
  State<ExitInterceptWidget> createState() => _ExitInterceptWidgetState();
}

class _ExitInterceptWidgetState extends State<ExitInterceptWidget> {
  bool allowQuit = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        if (allowQuit) {
          // context.pop();
          router.pop(context);
        } else {
          allowQuit = true;
          ToastUtil.showToast(widget.message);
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              allowQuit = false;
            }
          });
        }
        // if (widget.navigatorKey.currentState?.canPop() == true) {
        //   widget.navigatorKey.currentState?.pop();
        //   return false;
        // } else {
        //   if (!allowQuit) {
        //     allowQuit = true;
        //     ToastUtil.showToast(widget.message);
        //     Timer(const Duration(seconds: 2), () {
        //       allowQuit = false;
        //     });
        //     return false;
        //   } else {
        //     return true;
        //   }
        // }
      },
      child: widget.child,
    );
  }
}
