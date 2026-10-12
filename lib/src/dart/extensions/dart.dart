part of 'index.dart';

/// 对可能为 null 元素进行扩展
extension ElDartOptionalExt<T> on T? {
  /// 非空回调，如果变量不为 null，则执行传递的回调函数
  R? notBlankCallback<R>(R? Function(T v) callback) {
    if (this != null) return callback(this as T);

    return null;
  }
}

/// 提供时长延迟与整数倍时长计算。
extension ElDartDurationExt on Duration {
  /// 延迟当前时长并返回可选回调的执行结果。
  Future delay([FutureOr Function()? callback]) async =>
      Future.delayed(this, callback);

  /// 按毫秒精度计算当前时长的整数倍。
  Duration operator *(int num) {
    return Duration(milliseconds: inMilliseconds * num);
  }
}

/// 将整数转换为常用时长，并支持按毫秒延迟执行。
extension ElDartIntExt on int {
  /// 返回时间对象: 毫秒
  Duration get ms => Duration(milliseconds: this);

  /// 返回时间对象: 秒
  Duration get ss => Duration(seconds: this);

  /// 返回时间对象: 分钟
  Duration get mm => Duration(minutes: this);

  /// 返回时间对象: 小时
  Duration get hh => Duration(hours: this);

  /// 返回时间对象: 天
  Duration get dd => Duration(days: this);

  /// 延迟多少毫秒再执行回调函数
  Future delay([FutureOr Function()? callback]) async => ms.delay(callback);
}

/// 提供浮点数到颜色通道整数的转换。
extension ElDartDoubleExt on double {
  /// 将浮点数转成 0 ~ 255 的整数（用于颜色处理）
  int get floatToInt8 => (this * 255.0).round().clamp(0, 255);
}

/// 提供函数执行耗时统计与日志输出。
extension ElDartFuntionExt on Function {
  /// 统计函数的执行时间
  void time({
    String? debugLabel,
    String logPrefix = '',
    bool enabled = true,
    Duration? filterTime,
    ElLogFunction? log,
  }) {
    if (const bool.fromEnvironment('dart.vm.product')) {
      // coverage:ignore-line
      this(); // coverage:ignore-line
    } else {
      if (!enabled) {
        this();
      } else {
        final stopwatch = Stopwatch()..start();
        this();
        stopwatch.stop();
        final end = stopwatch.elapsedMicroseconds;
        if (filterTime != null && filterTime.inMilliseconds > end / 1000) {
          return;
        }
        // 首帧为 time 自身，日志输出堆栈时跳过，直接指向 time 的调用方
        final stackTrace = StackTrace.current;
        if (end >= 1000) {
          // coverage:ignore-line
          (log ?? ElLog.d)(
            '$logPrefix耗时 ${(end / 1000).toStringAsFixed(2)} 毫秒',
            title: debugLabel,
            stackTrace: stackTrace,
          ); // coverage:ignore-line
        } else {
          (log ?? ElLog.d)(
            '$logPrefix耗时 $end 微秒',
            title: debugLabel,
            stackTrace: stackTrace,
          );
        }
      }
    }
  }
}
