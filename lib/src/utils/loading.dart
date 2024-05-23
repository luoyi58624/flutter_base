part of '../../flutter_base.dart';

/// loading加载框
class LoadingUtil {
  LoadingUtil._();

  /// 判断当前页面是否已经打开loading，如果有，则下次打开新的loading需要移除上一个loading
  static bool _isShowLoading = false;

  /// 创建loading的时间
  static int _createLoadingStartTime = 0;

  /// loading延迟关闭时间
  static int _delayCloseTime = 0;

  /// 是否显示请求关闭loading提示框
  static bool _isShowConfirm = false;

  /// 显示 Loading 弹窗，如果之前打开了一个，将关闭之前的弹窗。
  ///
  /// 请注意：如果你在 initState 生命周期中使用它（例如在 initState 中执行网络请求），
  /// 请在 WidgetsBinding.instance.addPostFrameCallback 回调函数中调用，它会在UI构建完成后执行一次回调。
  ///
  /// 示例：
  /// ```dart
  ///  @override
  ///  void initState() {
  ///     super.initState();
  ///     WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
  ///       loading.show('请求数据中');
  ///       await Future.delayed(const Duration(seconds: 2));
  ///       loading.close();
  ///     });
  ///  }
  /// ```
  static void show(
    String text, {
    // 延迟关闭loading，它可以防止异步逻辑执行过快造成视觉闪烁，例如异步逻辑执行了50毫秒，
    // 那么loading会在50毫秒后关闭，页面会突然闪出一个弹窗然后瞬间关闭，此时用户体验非常不好；

    // 注意：如果你执行完异步逻辑后需要返回上一页，执行LoadingUtil.close时需要添加await，
    // 因为延迟关闭loading是不会阻塞后面代码的执行，关闭弹窗实际上只是执行弹出路由：router.back()，
    // 所以，如果你执行完异步逻辑后需要返回上一页，你必须等待loading关闭后再执行 router.back() 进行返回操作，
    // 否则你只是直接关闭了loading。
    int delayClose = 0,
    // 取消请求提示文字
    String cancelText = '你要关闭 Loading 吗?',
    // 当loading被手动关闭时的回调函数
    void Function()? onCancel,
  }) async {
    close(true);
    _isShowLoading = true;
    _delayCloseTime = math.max(delayClose, 0);
    _createLoadingStartTime = DartUtil.currentMilliseconds;
    if (rootContext.mounted) {
      showDialog(
        context: rootContext,
        barrierColor: Colors.black26,
        builder: (context) {
          return _LoadingWidget(
            title: text,
            cancelText: cancelText,
            onCancel: onCancel,
          );
        },
      );
    }
  }

  /// 如果页面上存在loading弹窗，则关闭。
  ///
  /// immedClose - 是否立即关闭弹窗
  static Future<void> close([bool? immedClose]) async {
    if (_isShowLoading) {
      if (immedClose == true) {
        _pop();
      } else {
        var delayCloseLoadingTime = math.max<int>(
            (_delayCloseTime - math.min(DartUtil.currentMilliseconds - _createLoadingStartTime, 1000)), 0);
        if (delayCloseLoadingTime <= 0) {
          _pop();
        } else {
          await (delayCloseLoadingTime / 1000).delay();
          if (_isShowLoading) _pop();
        }
      }
    }
  }

  static void _pop() {
    // 如果有提示窗，则先关闭提示窗
    if (_isShowConfirm) Navigator.of(rootContext).pop();
    _isShowConfirm = false;
    _delayCloseTime = 0;
    _isShowLoading = false;
    if (rootContext.mounted) Navigator.of(rootContext).pop();
  }
}

/// 构建loading组件
class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget({required this.title, required this.cancelText, this.onCancel});

  final String title;
  final String cancelText;
  final void Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        LoadingUtil._isShowConfirm = true;
        // await context.showConfirmModal(
        //   title: cancelText,
        //   onConfirm: () {
        //     LoadingUtil._isShowLoading = false;
        //     if (onCancel != null) onCancel!();
        //     Navigator.of(context).pop();
        //   },
        // );
        LoadingUtil._isShowConfirm = false;
      },
      child: Material(
        type: MaterialType.transparency,
        elevation: context.appTheme.modalElevation,
        child: Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade700.withOpacity(0.85)
                  : Colors.grey.shade900.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 24),
                Container(
                  constraints: const BoxConstraints(minWidth: 120, maxWidth: 150),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
