import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'touch_resampling.dart';

/// 在官方手势分发之前启用 Android 触摸重采样的可选应用绑定。
///
/// 在任何插件初始化或 `runApp` 之前调用 [ensureInitialized]；未使用此绑定的
/// 应用保持官方输入行为，非 Android 平台及非 touch 输入直接交给 Flutter。
class ElWidgetsFlutterBinding extends WidgetsFlutterBinding
    with TouchResamplingBinding {
  ElWidgetsFlutterBinding._();

  /// 初始化或复用当前绑定；已有其他绑定时明确报错，避免采样静默失效。
  static ElWidgetsFlutterBinding ensureInitialized() {
    WidgetsBinding? binding;
    // Flutter 未提供可空实例 getter，未初始化时 Debug 和 Release 分别抛这两种异常。
    try {
      binding = WidgetsBinding.instance;
    } on FlutterError {
      binding = null;
    } on TypeError {
      binding = null;
    }
    if (binding is ElWidgetsFlutterBinding) return binding;
    if (binding != null) {
      throw StateError(
        '请在 WidgetsFlutterBinding.ensureInitialized、插件初始化和 runApp 之前'
        '调用 ElWidgetsFlutterBinding.ensureInitialized()。',
      );
    }
    return ElWidgetsFlutterBinding._();
  }
}

/// 将可选采样接入 Flutter 输入入口，内部独立于业务事件模块。
@internal
mixin TouchResamplingBinding on GestureBinding, SchedulerBinding {
  late final TouchEventResampler _touchResampler = TouchEventResampler(
    dispatch: super.handlePointerEvent,
    canDispatch: () => !locked,
    isEnabled: () =>
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !resamplingEnabled,
  );

  /// 仅在 Android 触摸输入进入命中测试及手势竞技场之前采样。
  @override
  void handlePointerEvent(PointerEvent event) {
    assert(!locked);
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        resamplingEnabled) {
      _touchResampler.stop();
      super.handlePointerEvent(event);
      return;
    }
    _touchResampler.handleEvent(event);
  }

  /// 先恢复 Flutter 排队的输入，再恢复因锁定而暂停的采样。
  @override
  void unlocked() {
    super.unlocked();
    _touchResampler.resume();
  }

  /// 清理绑定时同时取消采样帧，避免终止后继续派发移动。
  @override
  void resetGestureBinding() {
    _touchResampler.clear();
    super.resetGestureBinding();
  }
}
