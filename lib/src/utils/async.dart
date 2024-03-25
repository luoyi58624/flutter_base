part of flutter_base;

/// 封装一些异步操作工具类
class AsyncUtil {
  AsyncUtil._();

  /// 创建一个节流函数，在一定时间内忽略多次点击事件
  /// * callback 回调函数
  /// * wait 节流时间(毫秒)
  ///
  /// example:
  /// ```dart
  /// GestureTapCallback throttleFun = AsyncUtil.throttle(() => print('hello'), 500);
  ///
  /// ElevatedButton(
  ///   onPressed: throttleFun,
  ///   child: Text('count: $count'),
  /// )
  /// // 或者
  /// ElevatedButton(
  ///   onPressed: (){
  ///     throttleFun();
  ///   },
  ///   child: Text('count: $count'),
  /// )
  ///
  /// ```
  static T throttle<T extends Function>(Function fun, [int? wait]) {
    Timer? timer;
    void throttleFun() {
      if (timer != null) return;
      timer = Timer(Duration(milliseconds: wait ?? 0), () => timer = null);
      fun();
    }

    return throttleFun as T;
  }

  /// 创建一个防抖函数，延迟指定时间执行逻辑，再次执行将重置延迟时间
  /// * callback 回调函数
  /// * wait 节流时间(毫秒)
  /// * immediate 触发事件后是否立即执行首次
  ///
  /// example:
  /// ```dart
  /// GestureTapCallback debounceFun = AsyncUtil.debounce(() => print('hello'), 500);
  ///
  /// ElevatedButton(
  ///   onPressed: debounceFun,
  ///   child: Text('count: $count'),
  /// )
  /// // 或者
  /// ElevatedButton(
  ///   onPressed: (){
  ///     debounceFun();
  ///   },
  ///   child: Text('count: $count'),
  /// )
  ///
  /// ```
  static T debounce<T extends Function>(Function fun, [int? wait, bool? immediate]) {
    Timer? timer;

    createTimer([Function? fun]) => timer = Timer(Duration(milliseconds: wait ?? 0), () {
          timer = null;
          if (fun != null) fun();
        });

    void throttleFun() {
      if (timer == null) {
        if (immediate == true) {
          fun();
          createTimer();
        } else {
          createTimer(fun);
        }
      } else {
        timer!.cancel();
        createTimer(fun);
      }
    }

    return throttleFun as T;
  }

  /// 延迟指定毫秒时间执行函数
  ///
  /// @return [Timer] 手动执行cancel方法可以取消延迟任务
  static Timer delayed(void Function() fun, [int? wait]) {
    return Timer(Duration(milliseconds: wait ?? 0), fun);
  }
}
