part of 'index.dart';

/// 延迟指定时间执行函数，单位：毫秒
Timer setTimeout(void Function() fun, int wait) {
  return Timer(Duration(milliseconds: wait), fun);
}

/// 每隔一段时间执行函数，单位：毫秒
Timer setInterval(void Function() fun, int wait) {
  return Timer.periodic(Duration(milliseconds: wait), (e) {
    fun();
  });
}
